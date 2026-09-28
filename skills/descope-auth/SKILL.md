---
name: descope-auth
description: Identity-broker-behind-a-seam patterns for multi-tenant SaaS - Descope (or any OIDC broker) issuing our JWTs, a Lambda REQUEST authorizer for REST API Gateway, ambient tenant context, a role->permission RBAC module, and React role gating with in-memory sessions. TRIGGER when writing or editing a Lambda authorizer, JWT/JWKS verification code, an auth seam or broker adapter, role/permission checks, login routes, `useRoles`/route guards, RTK Query auth headers, or when user asks about Descope, SSO/SAML federation, tenant claims, RBAC, or session handling. Do NOT trigger for Cognito-only projects, mobile auth (use mobile-security), Postgres RLS policy code (use postgres-rls-multitenant), or general OWASP guidance (use security).
---

# Identity Broker, Authorizer, and Role Gating

## Core Principle (CRITICAL)

**The broker issues our tokens; the app never knows which broker.** One
seam module talks to the vendor. Authorizer, API, worker, and SPA consume
*our* OIDC JWT and *our* four roles. Swapping Descope for Okta-Gov, Ping,
or Keycloak is a one-module change and zero application code. A PR with
vendor SDK calls outside the seam is rejected.

Three invariants that never bend:

1. **Tenant context is ambient.** It comes from the verified token via the
   authorizer, never from a request body, path, or query string.
2. **UI gates, server enforces.** No authorization decision lives only in
   the bundle.
3. **Tokens live in memory.** Never `localStorage`, never a cookie we wrote.

---

## Architecture

Customer IdP (SAML/OIDC) → **broker** → our OIDC JWT → SPA sends Bearer →
REST API Gateway → **Lambda REQUEST authorizer** (JWKS verify, no DB) →
`context {tenant_id, user_id, roles}` → API Lambda → RBAC → RLS transaction.

- **Broker-first.** Descope commercial tier today; Descope FedRAMP-High,
  Okta-Gov/Ping, or Keycloak later behind the same seam. The vendor choice
  buys continuity across phases, not features.
- **Federation lives in the broker.** It is the SAML SP toward each
  customer IdP. Customer group → role mapping is **per-tenant broker
  configuration**, never app code. Login does email-domain home-realm
  discovery.
- **Our token, our claims.** Every JWT carries `tenant_id`, `roles[]`,
  `sub`, `email`. Claim names are broker token-customization settings.

### The seam module

```python
"""auth/seam.py — the ONLY module that knows the broker vendor."""
import os
from dataclasses import dataclass
from typing import Protocol


@dataclass(frozen=True)
class Claims:
    tenant_id: str
    user_id: str          # `sub`
    email: str
    roles: tuple[str, ...]


class IdentityBroker(Protocol):
    issuer: str
    audience: str
    jwks_url: str
    def verify(self, token: str) -> Claims: ...
    def login_config(self) -> dict[str, str]: ...   # what the SPA needs to render login


class DescopeBroker:
    def __init__(self, project_id: str, base_url: str) -> None:
        self.issuer = f"{base_url}/v1/apps/{project_id}"          # verify current in console
        self.audience = project_id
        self.jwks_url = f"{base_url}/{project_id}/.well-known/jwks.json"

    def verify(self, token: str) -> Claims:
        from auth.jwt import verify_jwt   # vendor-neutral PyJWT helper
        p = verify_jwt(token, self.jwks_url, self.issuer, self.audience)
        return Claims(p["tenant_id"], p["sub"], p.get("email", ""), tuple(p.get("roles", [])))

    def login_config(self) -> dict[str, str]:
        return {"provider": "descope", "projectId": self.audience, "flowId": "sign-in"}


def get_broker() -> IdentityBroker:
    return DescopeBroker(os.environ["AUTH_PROJECT_ID"], os.environ["AUTH_BASE_URL"])
```

Issuer/JWKS URL formats are broker settings — **verify current**, never
hardcode from memory. A swap adds one class and changes `get_broker()`.

---

## Roles (CRITICAL)

Exactly four. Typed thousands of times, so they are short.

| Role | Meaning |
|---|---|
| `analyst` | Does the work: cases, uploads, analysis, drafts |
| `reviewer` | Approves review-workflow transitions |
| `admin` | Tenant/office administrator (users, config, source approvals) |
| `support` | Maytaur platform role: read-only across tenants + break-glass audit trail |

- Renamed 2026-09-02 from `office_admin` → `admin`, `platform_support` →
  `support`. Name-only. `ops` was offered for `support` and not taken.
- **Cleared markings are an attribute, not a role.** A per-user
  `cleared_markings` claim filters evidence; it never enters the role table.
- **The tenant↔office hierarchy is not formalized in the ADRs.** Do not
  invent an `office_id` claim, table, or FK. `tenant_id` is the only
  isolation key until the configuration-strategy ADR lands.

---

## Lambda REQUEST Authorizer (Python)

REST API Gateway in GovCloud has **no native JWT authorizer**, so a Lambda
authorizer is mandatory. Rules: validate `iss`, `aud`, `exp`, signature
against the broker JWKS; JWKS client cached at module scope; API Gateway
caches the result on the token; reject tokens without a known `tenant_id`;
`context` values are **strings only** (roles comma-joined); **never touch
the database**; `GET /v1/health` stays open; API keys are usage-plan
metering, not auth; every decision is a structured audit event.

```python
"""authorizer/handler.py"""
import jwt                                  # PyJWT[crypto]
from jwt import PyJWKClient
from aws_lambda_powertools import Logger
from auth.seam import get_broker

logger = Logger(service="authorizer")
audit = Logger(service="audit")             # handler routed to the audit log group
broker = get_broker()
_jwks = PyJWKClient(broker.jwks_url, cache_keys=True, lifespan=600)


def _policy(effect: str, method_arn: str, ctx: dict[str, str] | None = None) -> dict:
    stage_arn = method_arn.split("/", 2)[0] + "/*"   # stage-wide so the cache reuses across routes
    return {
        "principalId": (ctx or {}).get("user_id", "anonymous"),
        "policyDocument": {"Version": "2012-10-17", "Statement": [
            {"Action": "execute-api:Invoke", "Effect": effect, "Resource": stage_arn}]},
        "context": ctx or {},
    }


@logger.inject_lambda_context
def handler(event: dict, context) -> dict:
    headers = {k.lower(): v for k, v in event.get("headers", {}).items()}
    auth = headers.get("authorization", "")
    if not auth.lower().startswith("bearer "):
        audit.info("authorizer_decision", extra={"outcome": "deny", "reason": "missing_bearer"})
        raise Exception("Unauthorized")                       # → 401
    token = auth.split(" ", 1)[1]
    try:
        key = _jwks.get_signing_key_from_jwt(token).key
        p = jwt.decode(token, key, algorithms=["RS256"], issuer=broker.issuer,
                       audience=broker.audience, options={"require": ["exp", "iss", "aud", "sub"]})
    except jwt.PyJWTError as exc:
        audit.info("authorizer_decision", extra={"outcome": "deny", "reason": type(exc).__name__})
        raise Exception("Unauthorized") from None             # log the type, never the token
    if not p.get("tenant_id"):
        audit.info("authorizer_decision", extra={"outcome": "deny", "reason": "no_tenant_id", "user_id": p["sub"]})
        return _policy("Deny", event["methodArn"])
    ctx = {"tenant_id": p["tenant_id"], "user_id": p["sub"],
           "roles": ",".join(p.get("roles", [])), "email": p.get("email", "")}
    audit.info("authorizer_decision", extra={"outcome": "allow", **ctx})
    return _policy("Allow", event["methodArn"], ctx)
```

### CDK wiring

```python
from aws_cdk import Duration, RemovalPolicy, aws_apigateway as apigw, aws_logs as logs

audit_group = logs.LogGroup(                      # named, 365 d on EVERY env, never DESTROY
    self, "AuthAuditLog", log_group_name=f"/{config.prefix}/audit/auth",
    retention=logs.RetentionDays.ONE_YEAR, removal_policy=RemovalPolicy.RETAIN,
)
audit_group.grant_write(authorizer_fn)             # exempt from LogRetentionAspect / teardown

authorizer = apigw.RequestAuthorizer(
    self, "JwtAuthorizer", handler=authorizer_fn,
    identity_sources=[apigw.IdentitySource.header("Authorization")],
    results_cache_ttl=Duration.minutes(5),         # must be < token lifetime − refresh skew
)
api = apigw.RestApi(self, "Api", default_method_options=apigw.MethodOptions(authorizer=authorizer))
health = api.root.add_resource("v1").add_resource("health")
health.add_method("GET", apigw.LambdaIntegration(health_fn),
                  authorizer=None, authorization_type=apigw.AuthorizationType.NONE)
```

---

## Ambient Tenant Context Downstream (CRITICAL)

Read the principal from `requestContext.authorizer`. **A handler that reads
`tenant_id` from JSON, path, or query is a defect** — even one that only
"validates it against" the claim.

```python
"""api/principal.py"""
from dataclasses import dataclass
from aws_lambda_powertools.event_handler import APIGatewayRestResolver
from aws_lambda_powertools.event_handler.middlewares import NextMiddleware


@dataclass(frozen=True)
class Principal:
    tenant_id: str
    user_id: str
    roles: frozenset[str]


def principal_from(event) -> Principal:
    ctx = event.request_context.authorizer or {}
    if not ctx.get("tenant_id"):
        raise PermissionError("no tenant context")   # authorizer misconfigured; fail closed
    return Principal(ctx["tenant_id"], ctx["user_id"],
                     frozenset(r for r in ctx.get("roles", "").split(",") if r))


def tenant_scope(app: APIGatewayRestResolver, next_middleware: NextMiddleware):
    from db import rls_transaction                   # see postgres-rls-multitenant
    principal = principal_from(app.current_event)
    app.append_context(principal=principal)
    with rls_transaction(tenant_id=principal.tenant_id):   # SET LOCAL app.tenant_id
        return next_middleware(app)
```

Register once: `app.use(middlewares=[tenant_scope])`. The `SET LOCAL`
mechanics, DB roles, and the two-tenant leak test live in
`postgres-rls-multitenant` — do not duplicate them here.

---

## RBAC Module

One module: a role → permission table **versioned in code**, a decorator
over it, an audit event on every denial. Nothing else decides.

```python
"""auth/rbac.py"""
from functools import wraps
from aws_lambda_powertools import Logger

audit = Logger(service="audit")
RBAC_VERSION = 3                                  # bump on any table change

PERMISSIONS: dict[str, frozenset[str]] = {
    "analyst":  frozenset({"case:read", "case:write", "upload:write", "analysis:run", "draft:write"}),
    "reviewer": frozenset({"case:read", "case:transition", "draft:read", "draft:finalize"}),
    "admin":    frozenset({"case:read", "user:manage", "config:write", "source:approve"}),
    "support":  frozenset({"case:read", "job:read_all", "tenant:read_all"}),   # read-only, never write
}


def allowed(roles: frozenset[str], perm: str) -> bool:
    return any(perm in PERMISSIONS.get(r, frozenset()) for r in roles)


def requires(perm: str):
    def deco(fn):
        @wraps(fn)
        def wrapper(*args, **kwargs):
            from api.app import app
            p = app.context["principal"]
            if not allowed(p.roles, perm):
                audit.warning("rbac_denied", extra={"tenant_id": p.tenant_id, "user_id": p.user_id,
                              "roles": sorted(p.roles), "permission": perm, "rbac_version": RBAC_VERSION})
                return {"error": "forbidden"}, 403
            return fn(*args, **kwargs)
        return wrapper
    return deco

# @app.post("/v1/cases/<case_id>/transition")
# @requires("case:transition")
# def transition(case_id: str): ...
```

- Review-workflow **state transitions are permission-gated per role**; the
  transition table sits beside the state machine and calls `allowed()`.
- **Amazon Verified Permissions is deferred, not rejected** — adopt when
  per-office custom roles arrive. **Step-up auth for approvals is deferred.**
- `support` breaks glass by *reading* across tenants; the audit event is
  the trail.

---

## Browser Side (React + Vite + RTK Query)

- **Embedded SDK components on our own branded login route**, no redirect
  round-trip; hosted pages stay a fallback behind the same seam.
- **Authorization Code + PKCE.**
- **Tokens in memory via the SDK's session management** — never
  `localStorage`, never our own cookie; silent refresh + rotation are the
  SDK's job. Permanent invariant.
- **ADR-006 §7-2 is an open verification:** confirm in-memory session and
  refresh-rotation on the commercial tier before alpha. Package names below
  are **verify current**.

```tsx
// web/src/auth/AuthProvider.tsx — SPA side of the seam
import { AuthProvider as DescopeAuthProvider } from "@descope/react-sdk"; // verify current

export const AuthProvider = ({ children }: { children: React.ReactNode }) => (
  <DescopeAuthProvider
    projectId={import.meta.env.VITE_AUTH_PROJECT_ID}
    baseUrl={import.meta.env.VITE_AUTH_BASE_URL}
    sessionTokenViaCookie={false}            // in-memory only
  >
    {children}
  </DescopeAuthProvider>
);
```

```tsx
// web/src/auth/useRoles.ts — the ONLY place the SPA reads claims
import { useSession } from "@descope/react-sdk"; // verify current
import { jwtDecode } from "jwt-decode";

export type Role = "analyst" | "reviewer" | "admin" | "support";
interface Claims { tenant_id: string; roles?: Role[]; sub: string }

export function useRoles() {
  const { sessionToken, isAuthenticated } = useSession();
  const claims = sessionToken ? jwtDecode<Claims>(sessionToken) : undefined;
  const roles = new Set<Role>(claims?.roles ?? []);
  return { isAuthenticated, tenantId: claims?.tenant_id, roles, has: (r: Role) => roles.has(r) };
}
```

```tsx
// web/src/auth/RequireRole.tsx — UX gate only; the API enforces
import { Navigate, Outlet } from "react-router-dom";
import { useRoles, type Role } from "./useRoles";

export function RequireRole({ role }: { role: Role }) {
  const { isAuthenticated, has } = useRoles();
  if (!isAuthenticated) return <Navigate to="/login" replace />;
  if (!has(role)) return <Navigate to="/" replace />;
  return <Outlet />;
}
```

```typescript
// web/src/api/baseApi.ts — RTK Query reads the in-memory token per request
import { createApi, fetchBaseQuery } from "@reduxjs/toolkit/query/react";
import { getSessionToken } from "@descope/react-sdk"; // verify current

export const baseApi = createApi({
  baseQuery: fetchBaseQuery({
    baseUrl: "/v1",
    prepareHeaders: (headers) => {
      const token = getSessionToken();                 // memory, never storage
      if (token) headers.set("Authorization", `Bearer ${token}`);
      return headers;
    },
  }),
  endpoints: () => ({}),
});
```

A 401 means refresh failed: route to `/login`, never retry with a stale
token. A 403 means RBAC said no: render the denial.

### Support bundle

Support-only routes ship as a **lazy-loaded chunk under a support build
flag**, deployed to **their own path/origin**. The customer bundle contains
no support code; CI greps it for support route strings and fails the build
if any appear. A role guard does not make the customer bundle safe — the
absence of the code does.

```tsx
const SupportJobs = import.meta.env.VITE_SUPPORT_BUILD === "true"
  ? lazy(() => import("./support/SupportJobs")) : null;
```

---

## Testing

- **Authorizer (unit).** RSA key pair fixture, fake JWKS via monkeypatched
  `PyJWKClient.get_signing_key_from_jwt`, tokens from `jwt.encode`. Cases:
  valid → Allow with four string context keys; expired, wrong `aud`, wrong
  `iss`, no bearer → `Unauthorized`; missing `tenant_id` → Deny. One audit
  record per case with the matching `outcome`.
- **RBAC (unit).** Table round-trips through `allowed()`; a denial returns
  403 **and** emits `rbac_denied` with `rbac_version`; a snapshot test fails
  when `PERMISSIONS` changes without a version bump.
- **Frontend (vitest).** `RequireRole` redirects to `/login` unauthenticated
  and `/` without the role; `prepareHeaders` sets Bearer only with a token;
  a grep test that `web/` never touches `localStorage` for tokens.
- **Smoke (deployed dev).** Tenant A's token on tenant B's case → 403/404
  and an audit record. This is the API face of the two-tenant RLS leak test.

---

## Local Development

Both behind `get_broker()`, selected by `AUTH_PROVIDER`:

1. **Descope dev tenant** with seeded users per role, recorded in
   `~/.claude/TEST_CREDENTIALS.md`, never in the repo.
2. **Stub broker** for compose runs: signs JWTs with a local RSA key and
   serves `/.well-known/jwks.json` from a tiny container. Same claims, same
   four roles; authorizer and RLS path run unchanged. The deploy role's
   config has no `stub` value, so it cannot reach a deployed environment.

---

## Review Checklist

- [ ] Vendor SDK imports only in the seam module (API) and `web/src/auth/`
- [ ] No handler reads `tenant_id` from body, path, or query
- [ ] Authorizer: JWKS cached, `iss`/`aud`/`exp` checked, no DB call,
      string context values, tokens never logged, cache TTL < token life
- [ ] Audit log group named, 365 days, `RETAIN`, on every environment
- [ ] Every RBAC denial emits an audit event with `rbac_version`
- [ ] Four roles only; markings are an attribute; no invented office model
- [ ] SPA: no `localStorage` token, PKCE, `useRoles()` is the sole claim
      reader, guards are UX only
- [ ] Support chunk behind the build flag; customer-bundle grep in CI
- [ ] `/v1/health` open; API key is metering only

**Source:** ODIN v2 ADR-001 §Decision, §Architecture invariants (inv 1–6),
§Amendment 2026-09-02, §7 Open verifications; ADR-006 §Decision — Browser
auth & role gating, §Architecture invariants (inv 1, 2, 4), §7-2; ADR-007
§Decision — Failure visibility (support route).
