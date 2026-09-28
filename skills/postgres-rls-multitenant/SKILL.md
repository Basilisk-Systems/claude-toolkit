---
name: postgres-rls-multitenant
description: Pooled multi-tenant Postgres patterns - tenant_id NOT NULL plus row-level security on every tenant-owned table, exactly two database roles (an RLS-bound app role and a BYPASSRLS worker role used for one sweep query), SET LOCAL tenant context per transaction from authorizer claims, a seeded two-tenant leak test in CI, and pgvector/full-text search with the access pre-filter applied before any index touch. TRIGGER when writing or editing CREATE POLICY / ENABLE ROW LEVEL SECURITY DDL, database role grants, a connection or transaction helper that sets app.tenant_id, any query over a tenant-owned table, a pgvector or tsvector search, a tenant-isolation test, or when the user asks about RLS, tenant leakage, BYPASSRLS, connection poolers and SET LOCAL, or filtered vector search. Do NOT trigger for the jobs/job_steps dispatch tables (use postgres-job-queue), for writing the Alembic migration files themselves (use alembic-migrations), for JWT/authorizer code that produces the tenant claim (use descope-auth), or for DynamoDB single-table tenancy (use aws-cdk-dynamodb).
allowed-tools: Read, Glob, Grep
---

# Postgres Row-Level Security for Pooled Multi-Tenancy

## Core Principle (CRITICAL)

**Every tenant-owned table carries `tenant_id NOT NULL` and a forced RLS policy; the
tenant is set per transaction with `SET LOCAL` from the authorizer's claim; only two
database roles exist.** App-layer filtering is the first line of defense. RLS is the
backstop that makes a forgotten `WHERE tenant_id = ...` a no-op instead of a breach.

The tenant id comes from exactly one place: the authorizer context injected upstream
(`{tenant_id, user_id, roles}`). A `tenant_id` read from a request body, a query
string, or a client-supplied header is a defect, not a convenience.

This skill is written against the ODIN v2 ADR-001/ADR-002/ADR-004/ADR-007 contracts,
which are the default for Basilisk projects. Adapt names only when a project's ADR
says so.

---

## Where this fits

| Concern | Owner |
|---|---|
| Tenant claim minted and verified; ambient context downstream | `descope-auth` |
| Policies, roles, extensions as versioned DDL objects | `alembic-migrations` |
| `jobs` / `job_steps` (platform tables, **no** RLS policy) and the sweep that reads them | `postgres-job-queue` |
| RLS policies, role split, per-transaction context, leak test, filtered search | **this skill** |

---

## Two Roles, One Bypass Query (CRITICAL)

| Role | Attributes | Who holds the credential | What it may do |
|---|---|---|---|
| `app` | `NOBYPASSRLS`, `NOSUPERUSER`, not table owner | Sync API (Lambda) and every job body | Everything, subject to RLS |
| `worker` | `BYPASSRLS`, `NOSUPERUSER`, not table owner | The worker process only, on every substrate | **Exactly one query**: the cross-tenant due-row sweep. Then `SET LOCAL ROLE app` |

```sql
-- migration: roles are migration objects, created once, idempotently
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app') THEN
    CREATE ROLE app LOGIN NOSUPERUSER NOBYPASSRLS NOCREATEDB NOCREATEROLE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'worker') THEN
    CREATE ROLE worker LOGIN NOSUPERUSER BYPASSRLS NOCREATEDB NOCREATEROLE;
  END IF;
END $$;

-- worker may become app inside a transaction; app can never become worker
GRANT app TO worker;
```

Rules that fall out of this table:

- **Table owner is neither role.** Owners bypass RLS unless `FORCE ROW LEVEL SECURITY`
  is set, and even then a `NOBYPASSRLS` owner is the only safe owner. Migrations run as
  a third, non-login-in-prod `migrator` role that owns every object; `app` and `worker`
  get `GRANT SELECT, INSERT, UPDATE, DELETE` per table.
- **The worker credential never reaches the API.** AWS: only the worker task role can
  read the worker secret. Two-services-from-one-image substrates: only the worker
  service is given the worker secret.
- **A second `BYPASSRLS` query is a design change**, not a shortcut. If a feature seems
  to need one (cross-tenant reporting, support tooling), it goes through the platform
  tenant or a reviewed read model, and the ADR gets a row.

---

## Policy Shape

`current_setting('app.tenant_id', true)` returns `NULL` (not an error) when unset,
and `NULL = anything` is not true, so an unset context reads **zero rows**. That is
the fail-closed property everything else depends on.

```sql
ALTER TABLE price_observations ENABLE ROW LEVEL SECURITY;
ALTER TABLE price_observations FORCE  ROW LEVEL SECURITY;   -- owner is not exempt

-- one policy per command keeps the write rule reviewable on its own
CREATE POLICY tenant_read ON price_observations FOR SELECT
  USING (tenant_id = current_setting('app.tenant_id', true)::uuid);

CREATE POLICY tenant_write ON price_observations FOR INSERT
  WITH CHECK (tenant_id = current_setting('app.tenant_id', true)::uuid);

CREATE POLICY tenant_update ON price_observations FOR UPDATE
  USING      (tenant_id = current_setting('app.tenant_id', true)::uuid)
  WITH CHECK (tenant_id = current_setting('app.tenant_id', true)::uuid);

CREATE POLICY tenant_delete ON price_observations FOR DELETE
  USING (tenant_id = current_setting('app.tenant_id', true)::uuid);
```

### Platform-scope rows (reserved platform tenant)

Shared reference data (public indices, platform-default sources) is served to every
tenant but ingested once. The mechanism is a **reserved, delete-protected platform
tenant UUID** created in migration one; `tenant_id NOT NULL` stands everywhere.

```sql
-- read: my rows OR platform rows
CREATE POLICY tenant_read ON adjustment_factors FOR SELECT
  USING (tenant_id = current_setting('app.tenant_id', true)::uuid
         OR tenant_id = '00000000-0000-0000-0000-000000000001'::uuid);

-- write: platform rows only when the connection tenant IS the platform tenant,
-- which only the worker's ingest path ever sets
CREATE POLICY tenant_write ON adjustment_factors FOR INSERT
  WITH CHECK (tenant_id = current_setting('app.tenant_id', true)::uuid);
```

Do not invent a nullable `tenant_id` carve-out or a separate platform schema; both
were considered and rejected because they create a third isolation model.

### Which tables get a policy

| Table kind | `tenant_id NOT NULL` | RLS policy |
|---|---|---|
| Tenant-owned evidence / domain rows (observations, cases, corpus chunks, audit events) | yes | yes, all four commands |
| Platform dispatch tables (`jobs`, `job_steps`) | yes | **no** — read by the sweep under `worker`; job bodies filter by the job's own `tenant_id` |
| Pure reference tables with no tenant dimension (taxonomies) | no | no; `SELECT` grant only |
| Tenants table itself | primary key | policy on `tenant_id = current_setting(...)` so a tenant sees only its own row |

`tenant_id` is never the sole primary key of an evidence row; the required composite
index for each store (`(tenant_id, item_ref, observation_date)` and the like) leads
with `tenant_id` so the policy predicate is index-assisted, not a seq scan.

---

## Per-Transaction Context: `SET LOCAL`, never `SET` (CRITICAL)

Behind a pooler (RDS Proxy, PgBouncer in transaction mode) a session-level `SET`
leaks to the next borrower of the connection. `SET LOCAL` is scoped to the current
transaction and dies with `COMMIT`/`ROLLBACK`, which is exactly the lifetime the
tenant context should have.

```python
# db/tenant.py — the only place that sets app.tenant_id
from __future__ import annotations

import contextlib
from collections.abc import Iterator
from uuid import UUID

import psycopg
from psycopg import sql


class MissingTenantContext(RuntimeError):
    """Raised before any SQL runs when the caller has no authorizer-supplied tenant."""


@contextlib.contextmanager
def tenant_transaction(
    conn: psycopg.Connection, *, tenant_id: UUID | None, become_app: bool = False
) -> Iterator[psycopg.Cursor]:
    """Open one transaction with the tenant context set for its whole lifetime.

    `tenant_id` is the authorizer claim (or, in a job body, the job row's own
    tenant_id). `become_app=True` is for the worker credential entering a job body:
    it drops to the RLS-bound role for the rest of the transaction.
    """
    if tenant_id is None:
        raise MissingTenantContext("tenant_id is required; refusing to run without RLS context")

    with conn.transaction():
        with conn.cursor() as cur:
            if become_app:
                cur.execute("SET LOCAL ROLE app")
            # set_config(name, value, is_local=true) == SET LOCAL, and it is parameterizable;
            # SET LOCAL app.tenant_id = %s is not (SET takes no bind parameters).
            cur.execute(
                "SELECT set_config('app.tenant_id', %s, true)", (str(tenant_id),)
            )
            yield cur
```

Usage in the API plane:

```python
def get_case(event, conn):
    ctx = event["requestContext"]["authorizer"]          # {tenant_id, user_id, roles}
    with tenant_transaction(conn, tenant_id=UUID(ctx["tenant_id"])) as cur:
        cur.execute("SELECT ... FROM cases WHERE case_id = %s", (case_id,))   # RLS narrows it
        return cur.fetchone()
```

Usage in a job body (worker credential, one job):

```python
def run_job(job, conn):
    with tenant_transaction(conn, tenant_id=job.tenant_id, become_app=True) as cur:
        handler(job, cur)      # handler never sees the worker role
```

SQLAlchemy equivalent: an `event.listens_for(Session, "after_begin")` hook that
executes the same `set_config` with the tenant pulled from `session.info["tenant_id"]`
and raises `MissingTenantContext` when the key is absent. Never a `connect`-time hook:
that is a session `SET` by another name.

| Do | Don't |
|---|---|
| `SELECT set_config('app.tenant_id', %s, true)` | `SET app.tenant_id = '...'` (session scope, leaks through the pool) |
| Set it first, inside `BEGIN` | Set it on connect, on checkout, or once per worker |
| Raise before any SQL when the tenant is missing | Fall back to a default tenant, an empty string, or "all" |
| `SET LOCAL ROLE app` from the worker credential before a job body | Run a job body as `worker` because "it filters by tenant_id anyway" |
| One helper module owns the string `'app.tenant_id'` | The setting name spelled in five files |

The `current_setting('app.tenant_id', true)` form (second argument `true` =
`missing_ok`) is what makes an unset context read zero rows instead of raising.
Do not "fix" the raise by removing `missing_ok`; fix the caller.

---

## The Seeded Two-Tenant Leak Test (CI backstop)

Runs against a real Postgres (compose or testcontainers) in CI on every PR. It
discovers tenant tables from the catalog so a new table cannot be forgotten.

```python
# tests/integration/test_rls_leak.py
import uuid
import pytest

TENANT_A, TENANT_B = uuid.uuid4(), uuid.uuid4()
PLATFORM = uuid.UUID("00000000-0000-0000-0000-000000000001")


def tenant_tables(cur) -> list[str]:
    """Every base table in `public` that has a tenant_id column, minus the platform
    dispatch tables that are exempt by ADR."""
    cur.execute("""
        SELECT c.table_name
        FROM information_schema.columns c
        JOIN information_schema.tables t USING (table_schema, table_name)
        WHERE c.table_schema = 'public' AND c.column_name = 'tenant_id'
          AND t.table_type = 'BASE TABLE'
          AND c.table_name NOT IN ('jobs', 'job_steps')
        ORDER BY 1
    """)
    return [r[0] for r in cur.fetchall()]


@pytest.mark.parametrize("table", tenant_tables_from_migrated_db())
def test_tenant_b_cannot_read_tenant_a(app_conn, seed_row, table):
    """Insert as A, read as B → zero rows. Kills a missing policy, a policy on the
    wrong column, ENABLE without FORCE, or a helper that sets context at session scope."""
    with tenant_transaction(app_conn, tenant_id=TENANT_A) as cur:
        seed_row(cur, table, TENANT_A)
    with tenant_transaction(app_conn, tenant_id=TENANT_B) as cur:
        cur.execute(f"SELECT count(*) FROM {table}")      # table name from the catalog, not user input
        assert cur.fetchone()[0] == 0
    with tenant_transaction(app_conn, tenant_id=TENANT_A) as cur:
        cur.execute(f"SELECT count(*) FROM {table}")
        assert cur.fetchone()[0] == 1


def test_unset_context_reads_nothing(app_conn, seeded_all_tables):
    """No SET LOCAL at all → every tenant table returns zero rows (fail closed)."""
    with app_conn.transaction(), app_conn.cursor() as cur:
        for table in tenant_tables(cur):
            cur.execute(f"SELECT count(*) FROM {table}")
            assert cur.fetchone()[0] == 0, table


def test_every_tenant_table_has_forced_rls_and_four_policies(migrator_conn):
    """Structural check: ENABLE + FORCE on each table, and a policy for each command."""
    with migrator_conn.cursor() as cur:
        for table in tenant_tables(cur):
            cur.execute(
                "SELECT relrowsecurity, relforcerowsecurity FROM pg_class WHERE relname = %s",
                (table,),
            )
            assert cur.fetchone() == (True, True), f"{table}: RLS not enabled+forced"
            cur.execute(
                "SELECT array_agg(cmd ORDER BY cmd) FROM pg_policies WHERE tablename = %s",
                (table,),
            )
            assert cur.fetchone()[0] == ["DELETE", "INSERT", "SELECT", "UPDATE"], table


def test_app_role_cannot_bypass(app_conn):
    with app_conn.cursor() as cur:
        cur.execute("SELECT rolbypassrls FROM pg_roles WHERE rolname = current_user")
        assert cur.fetchone()[0] is False


def test_platform_rows_visible_to_every_tenant_but_writable_only_as_platform(app_conn):
    with tenant_transaction(app_conn, tenant_id=TENANT_A) as cur:
        with pytest.raises(psycopg.errors.InsufficientPrivilege):   # RLS WITH CHECK violation
            cur.execute("INSERT INTO adjustment_factors (tenant_id, ...) VALUES (%s, ...)", (PLATFORM,))
```

What each test kills, so nobody prunes one as redundant:

| Test | Mutation it catches |
|---|---|
| B cannot read A (per table) | Policy missing, policy on the wrong column, `ENABLE` without `FORCE`, session-scope `SET` in the helper |
| Unset context reads nothing | `missing_ok` removed and swallowed, or a `COALESCE(..., '*')` default sneaking into a policy |
| Structural forced-RLS + four policies | A new table added with `tenant_id` but no migration policy; a `FOR ALL` policy replaced by `SELECT` only |
| App role cannot bypass | Someone granted `BYPASSRLS` to `app` "temporarily" |
| Platform rows write-gated | A read policy's `OR tenant_id = PLATFORM` copied into `WITH CHECK` |

Seed helpers build the minimum valid row per table (provenance base, `rights_basis`,
etc.); keep them in one fixture module so the leak test does not become the second
copy of every model's constructor.

---

## Filtered Search: Pre-filter Before Any Index Touch (CRITICAL)

The access pre-filter (tenant, rights, office approval, markings; the list is
extensible) is applied **before** vector or full-text ranking, never as a post-filter
on the top-k. Two failure modes of post-filtering:

- **Leak**: a post-filter that runs application-side has already pulled other
  tenants' rows into the process and, with a bug, into the response.
- **Starvation**: ANN returns the global top-k, then the filter drops most of them;
  a small tenant gets three results or none while the engine reports "nothing
  relevant" that actually exists.

Under RLS the tenant dimension is enforced by the policy regardless of the query
text, which is what makes "corpus rows are ordinary RLS rows" true. The remaining
dimensions are explicit predicates in the same `WHERE`.

### Chunk table shape

```sql
CREATE TABLE corpus_chunks (
    chunk_id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               uuid NOT NULL,
    source_id               uuid NOT NULL REFERENCES sources(source_id),
    document_id             uuid NOT NULL,
    char_start              int  NOT NULL,
    char_end                int  NOT NULL,
    embedding               vector(1024) NOT NULL,
    embedding_model_version text NOT NULL,          -- stamped on every chunk, never NULL
    chunking_strategy       text NOT NULL,
    tsv                     tsvector GENERATED ALWAYS AS (to_tsvector('english', text)) STORED,
    text                    text NOT NULL,
    markings                text[] NOT NULL DEFAULT '{}',
    rights_basis            text NOT NULL,
    created_at              timestamptz NOT NULL DEFAULT now()
);
-- pre-filter columns first, so a filtered scan is index-led
CREATE INDEX ON corpus_chunks (tenant_id, source_id, embedding_model_version);
CREATE INDEX ON corpus_chunks USING gin (tsv);
CREATE INDEX ON corpus_chunks USING hnsw (embedding vector_cosine_ops);
```

### Hybrid query (vector + FTS, pre-filtered)

```sql
WITH allowed AS (                      -- the pre-filter: cheap, index-led, RLS already applied
    SELECT chunk_id, embedding, tsv
    FROM corpus_chunks
    WHERE embedding_model_version = %(model_version)s          -- never mix vector spaces
      AND source_id = ANY(%(approved_source_ids)s)             -- rights + office approval
      AND markings <@ %(cleared_markings)s                     -- user's cleared set
),
vec AS (
    SELECT chunk_id, row_number() OVER (ORDER BY embedding <=> %(query_vec)s::vector) AS r
    FROM allowed ORDER BY embedding <=> %(query_vec)s::vector LIMIT 50
),
lex AS (
    SELECT chunk_id, row_number() OVER (ORDER BY ts_rank_cd(tsv, q) DESC) AS r
    FROM allowed, plainto_tsquery('english', %(query_text)s) q
    WHERE tsv @@ q LIMIT 50
)
SELECT c.chunk_id, c.document_id, c.text,
       COALESCE(1.0/(60+vec.r), 0) + COALESCE(1.0/(60+lex.r), 0) AS rrf
FROM allowed c
LEFT JOIN vec USING (chunk_id)
LEFT JOIN lex USING (chunk_id)
WHERE vec.r IS NOT NULL OR lex.r IS NOT NULL
ORDER BY rrf DESC
LIMIT %(k)s;
```

Every parameter is bound; `approved_source_ids` is computed server-side from the
authorizer context and the source registry, never accepted from the client.

### Index notes

| Topic | Guidance |
|---|---|
| HNSW vs ivfflat | HNSW default: no training step, better recall under filters. ivfflat only if build memory is the constraint |
| Filtered ANN recall | pgvector applies the index scan first and the `WHERE` after, up to `ef_search` candidates; a selective pre-filter can starve results. Set `hnsw.ef_search` higher for filtered queries (`SET LOCAL hnsw.ef_search = 200`), or on pgvector ≥ 0.8 enable iterative scans (`SET LOCAL hnsw.iterative_scan = relaxed_order`). Verify behavior on the managed engine version; it is a named open verification, not an assumption |
| Per-tenant partitioning | Not at MVP. A tenant whose chunk count approaches the envelope is a revisit trigger with a metric, not a day-one partition scheme |
| `embedding_model_version` | Always in the pre-filter. A re-embedding migration writes new rows under the new version and deletes the old under the same cascade; the retrieval audit event records which version answered |
| Lineage | `source → document → chunk → vector` must be queryable so a rights-expiry cascade deletes structurally, not by convention |

Log every retrieval as an audit event with the query, the filter set, the
`embedding_model_version`, and the candidate ids returned.

---

## Local Development

- Compose file runs `postgres` with the `pgvector` extension image; migrations create
  roles, extensions, and policies. The app connects as `app`, the worker as `worker`,
  never as the superuser, so local behaves like prod.
- A `make rls-test` (or the integration test job) target runs only the leak test
  module against the compose database.
- `psql` debugging: `SET ROLE app; BEGIN; SELECT set_config('app.tenant_id', '<uuid>', true); ... ROLLBACK;`

---

## Anti-patterns

| Anti-pattern | Why it fails | Instead |
|---|---|---|
| `tenant_id` taken from the request body or a query string | Any client can read any tenant | Authorizer context only; body `tenant_id` fields are rejected by the schema |
| Session `SET app.tenant_id` on connect or checkout | Leaks through the pooler to the next request | `SET LOCAL` / `set_config(..., true)` inside the transaction |
| `ENABLE ROW LEVEL SECURITY` without `FORCE` | Table owner bypasses silently | Always both; structural test asserts both flags |
| Application connects as the table owner or superuser | RLS is not applied at all | `app` role, non-owner, `NOBYPASSRLS` |
| A convenience "admin" connection that skips RLS for support tooling | Third isolation model; nobody audits it | Platform tenant or a reviewed read model through the app role |
| `WHERE tenant_id = %s` treated as sufficient, no policy | One forgotten predicate is a breach | App filter first line, RLS backstop, both |
| Post-filtering the ANN top-k by tenant/rights | Leaks rows into the process; starves small tenants | Pre-filter CTE before ranking; RLS covers tenant regardless |
| Mixing embedding model versions in one ANN query | Distances across spaces are meaningless | `embedding_model_version` in every pre-filter |
| Leak test enumerates tables by hand | New table is forgotten | Discover from `information_schema.columns` |
| Nullable `tenant_id` "for platform rows" | Policies get an `IS NULL` hole | Reserved platform tenant UUID; `NOT NULL` stands |

---

## Review Checklist

- [ ] Every new tenant-owned table: `tenant_id uuid NOT NULL`, `ENABLE` + `FORCE ROW LEVEL SECURITY`, four per-command policies, all in the migration
- [ ] Policy predicate is `current_setting('app.tenant_id', true)::uuid` (with `missing_ok`), plus the platform-tenant `OR` on read policies only where the store serves platform rows
- [ ] Composite indexes lead with `tenant_id`
- [ ] Exactly two runtime roles; `worker` is the only `BYPASSRLS` login and is held only by the worker process
- [ ] The sweep is the only query run as `worker`; every job body enters via `SET LOCAL ROLE app` + `set_config('app.tenant_id', ..., true)`
- [ ] One helper module sets the context; it raises before any SQL when the tenant is missing; no session-level `SET` anywhere (`grep -rn "SET app\.\|SET ROLE" --include=*.py` finds only the helper)
- [ ] No `tenant_id` field accepted from a request body; request schemas reject it
- [ ] Leak test discovers tables from the catalog, covers read-as-other-tenant, unset-context, structural flags, and role attributes; it runs in CI against real Postgres
- [ ] Vector / FTS queries pre-filter in a CTE on tenant-adjacent dimensions and `embedding_model_version`; no application-side post-filter of ranked results
- [ ] Retrieval writes an audit event carrying filters, `embedding_model_version`, and candidate ids
- [ ] Roles, extensions, policies exist only as migration objects (see `alembic-migrations`)

**Source:** ODIN v2 `ADR-001` §Decision item 5 (data-plane tenancy; amended 2026-09-03
B4: two roles) and §Architecture invariant 5; `ADR-002` inv 2/3 and §7-7 closure
(reserved platform tenant); `ADR-004` §Pre-filter invariant and the markings mechanism,
§Architecture invariants 1/3/4/6, §7-1 (pgvector filtered-scan verification);
`ADR-007` §Decision — Worker packaging & language (runtime tenancy) and
§Architecture invariant 10.
