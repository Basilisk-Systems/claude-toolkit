---
name: postgres-job-queue
description: Postgres-as-job-queue patterns for async work dispatch - a jobs/job_steps table as the status source of truth, FOR UPDATE SKIP LOCKED claims with lease-based timeouts, transactional idempotent enqueue, a due-row sweep, and dead-vs-quarantined failure routing. TRIGGER when code defines or queries a jobs/job_steps table, implements enqueue/claim/heartbeat/complete, writes a worker poll loop, a refresh scheduler, or a status-rail endpoint, or when the user asks how async jobs are dispatched, retried, or made idempotent. Do NOT trigger for SQS/EventBridge/Step Functions designs (those are deferred alternatives, not this pattern), synchronous request handling, or general Postgres schema work unrelated to job dispatch (use postgres-rls-multitenant or alembic-migrations).
---

# Postgres Job Queue

## Core Principle

**One `jobs` table with child `job_steps` rows is the whole contract.** The job row
is the status source of truth under any transport, the enqueue is transactional with
the state change that caused it, and the worker plane is a poller. Nothing else
(a queue, a bus, a state machine) exists until a named trigger fires.

This skill is written against the ODIN v2 ADR-007 contract, which is the default
schema for Basilisk projects. Adapt column names only if a project's ADR says so.

---

## When this pattern is right — and what was rejected (CRITICAL)

Use a Postgres job table when the application already has a relational store that
holds the entities jobs act on (cases, sources, uploads) and portability across
substrates (commercial AWS, GovCloud, in-boundary container hosting) matters more
than raw queue throughput.

Do not re-open these decisions without the named trigger:

| Alternative | Status | Why / trigger |
|---|---|---|
| **DynamoDB as the job store** | Rejected | Breaks portability; loses the `jobs ↔ cases` join a relational store gives for free |
| **SQS per job class** | Deferred, behind the dispatch seam | Adopt per class only when: a consumer cannot poll Postgres (e.g. a Lambda-hosted job class), **or** enqueue→claim p99 > 5 s with idle workers, claim-query p99 > 250 ms, empty-poll ratio > 95 % at a worker count we won't shrink, or autovacuum falls behind on `jobs` |
| **EventBridge pub/sub + outbox** | Deferred | Adopt when a single event gains a second consumer that is not our own worker (customer webhook, external subscriber, another account) |
| **Step Functions** (even for machine-only pipelines) | Ruled out at MVP | "Adopting both means paying for the same guarantee twice" — multi-step jobs carry `current_step` and resume on retry |
| **RunTask-on-demand per job** | Rejected | Something still has to notice a job exists — the dispatch problem all over again |

If a session proposes one of these, cite the trigger and check the numbers first.

---

## The Dispatch Seam

Exactly one interface: **enqueue / claim / heartbeat / complete**. The Postgres
poller is its only MVP implementation. A second implementation (SQS for one class)
plugs in behind the same seam; the job row stays the status source of truth.

```python
from typing import Protocol
from uuid import UUID


class Dispatch(Protocol):
    def enqueue(self, cur, *, tenant_id: UUID, job_class: str, idempotency_key: str,
                case_id: UUID | None, origin_request_id: str, enqueued_by: UUID | None,
                trace_id: str | None, params: dict) -> UUID: ...
    def claim(self, cur, *, job_class: str, lease_seconds: int) -> "Job | None": ...
    def heartbeat(self, cur, *, job_id: UUID, lease_seconds: int) -> None: ...
    def complete(self, cur, *, job_id: UUID, outcome: "Outcome") -> None: ...
    def release(self, cur, *, job_id: UUID) -> None: ...   # running -> queued, attempt unchanged;
                                                            # graceful-shutdown path (fargate-worker)
```

**Rule:** job handlers never import the transport. A handler receives a `Job` and a
tenant-scoped cursor; it does not know whether a poller or a queue delivered it.
The enqueue call takes the caller's open cursor so it joins the caller's transaction.

---

## Schema (ADR-007 job-model contract)

```sql
CREATE TYPE job_status  AS ENUM ('queued','running','succeeded','failed','dead','quarantined');
CREATE TYPE step_status AS ENUM ('queued','running','succeeded','failed');

CREATE TABLE jobs (
    job_id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id          uuid NOT NULL,            -- no RLS policy on this table (see below)
    job_class          text NOT NULL,
    idempotency_key    text NOT NULL,
    case_id            uuid NULL,
    origin_request_id  text NOT NULL,
    enqueued_by        uuid NULL,                -- user id from authorizer context; NULL for sweep/system jobs
    status             job_status NOT NULL DEFAULT 'queued',
    current_step       text NULL,
    attempt            int  NOT NULL DEFAULT 0,
    max_attempts       int  NOT NULL DEFAULT 3,
    lease_expires_at   timestamptz NULL,
    next_run_at        timestamptz NOT NULL DEFAULT now(),
    retryable          boolean NULL,             -- set by the worker on failure
    trace_id           text NULL,                -- X-Ray trace id, stored at enqueue
    params             jsonb NOT NULL DEFAULT '{}'::jsonb,   -- PLACEHOLDER: ADR names no payload column
    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX jobs_claim_idx   ON jobs (status, next_run_at);      -- claim + sweep
CREATE INDEX jobs_case_idx    ON jobs (case_id);                  -- case endpoint
CREATE UNIQUE INDEX jobs_idem ON jobs (tenant_id, job_class, idempotency_key);

CREATE TABLE job_steps (
    job_id       uuid NOT NULL REFERENCES jobs (job_id),
    step_name    text NOT NULL,
    status       step_status NOT NULL DEFAULT 'queued',
    started_at   timestamptz NULL,
    finished_at  timestamptz NULL,
    detail       jsonb NOT NULL DEFAULT '{}'::jsonb,
    step_seq     int NOT NULL,                   -- PLACEHOLDER: ADR names no ordering column
    PRIMARY KEY (job_id, step_seq)               -- PLACEHOLDER: ADR names no PK
);
CREATE INDEX job_steps_job_idx ON job_steps (job_id);
```

**Decided:** every column above except the three marked PLACEHOLDER, both enums,
and the four indexes. The step status set is a strict subset of the job set; logs
distinguish them by field name — `job_status` vs `step_status`, never a shared
`status` key.

**Left unnamed by the ADR — flag in review, do not present as settled:**
- `job_steps` primary key and ordering column (placeholder: `(job_id, step_seq)`).
- A payload/params column on `jobs` (placeholder: `params jsonb`).
- The per-tenant concurrency-cap column on `tenants` (placeholder: `max_running_per_class int`).

**No RLS on `jobs` / `job_steps` (CRITICAL).** They are platform orchestration
metadata, not evidence: pinned to the pooled platform cluster, never routed per
tenant, no residency payload. The worker's `BYPASSRLS` credential reads them.
"Reachability failure" is **not** a step status — it is a flag on the case, set by
the runner; the connector name goes in `detail`.

---

## Enqueue (CRITICAL)

**"No event exists without its row."** The same transaction that flips a
triggering state (upload confirmed, review transition, refresh due) inserts the job.
Never enqueue after commit; never enqueue from a separate connection.

```python
def enqueue(cur, *, tenant_id, job_class, idempotency_key, case_id, origin_request_id,
            enqueued_by, trace_id, params) -> UUID:
    cur.execute(
        """
        INSERT INTO jobs (tenant_id, job_class, idempotency_key, case_id,
                          origin_request_id, enqueued_by, trace_id, params)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT (tenant_id, job_class, idempotency_key) DO NOTHING
        RETURNING job_id
        """,
        (tenant_id, job_class, idempotency_key, case_id,
         origin_request_id, enqueued_by, trace_id, Json(params)),
    )
    row = cur.fetchone()
    if row:
        return row[0]
    cur.execute(
        "SELECT job_id FROM jobs WHERE tenant_id=%s AND job_class=%s AND idempotency_key=%s",
        (tenant_id, job_class, idempotency_key),
    )
    return cur.fetchone()[0]          # duplicate enqueue is a no-op returning the existing id
```

**Every job class has an idempotency key.** Derivation is per class and lives next
to the handler, not in the caller:

| Job class | Idempotency key |
|---|---|
| ingest (`upload` / `api_pull` / `web_capture`) | content hash of the artifact |
| scheduled refresh | `source_id` + scheduled slot |
| report / spreadsheet generation | `case_id` + version |
| live_query | `case_id` + connector + request fingerprint + client-generated request id |

Written at enqueue, never later: `origin_request_id` (the sync API's request id),
`enqueued_by` (authorizer user id, `NULL` for system jobs), and `trace_id` (the
X-Ray trace the runner resumes as a subsegment).

---

## Claim

`FOR UPDATE SKIP LOCKED` gives claim exclusivity; `lease_expires_at` is the
visibility timeout. The ADR's illustrative shape (not the literal implementation):

```sql
-- illustrative claim query, not the literal implementation
SELECT job_id FROM jobs
WHERE status = 'queued' AND next_run_at <= now()
  AND tenant_id NOT IN (
    SELECT tenant_id FROM jobs
    WHERE status = 'running' AND job_class = $1
    GROUP BY tenant_id HAVING count(*) >= $2)
ORDER BY next_run_at
FOR UPDATE SKIP LOCKED LIMIT 1;
```

Production shape — select, flip status, bump attempt, and set the lease atomically:

```sql
UPDATE jobs
SET status = 'running',
    attempt = attempt + 1,
    lease_expires_at = now() + make_interval(secs => %(lease_seconds)s),
    updated_at = now()
WHERE job_id = (
    SELECT j.job_id
    FROM jobs j
    WHERE j.status = 'queued'
      AND j.job_class = %(job_class)s
      AND j.next_run_at <= now()
      AND (
        SELECT count(*) FROM jobs r
        WHERE r.status = 'running' AND r.job_class = j.job_class AND r.tenant_id = j.tenant_id
      ) < COALESCE(
        (SELECT t.max_running_per_class FROM tenants t WHERE t.tenant_id = j.tenant_id),
        %(default_cap)s)
    ORDER BY j.next_run_at
    FOR UPDATE SKIP LOCKED
    LIMIT 1
)
RETURNING *;
```

The per-tenant, per-class cap is enforced **in the claim query** — small default,
per-tenant override — so one tenant's ingest storm cannot starve another's.

```sql
-- heartbeat: extend the lease while the body runs
UPDATE jobs SET lease_expires_at = now() + make_interval(secs => %(lease_seconds)s)
WHERE job_id = %(job_id)s AND status = 'running';
```

**Unspecified — parameterize, the project sets them:** lease duration, heartbeat
interval, poll interval, per-class wall-time caps. Heartbeat must run on a separate
connection from the job body (the body's transaction may be long); confirm no
session-level state leaks across pooled connections.

---

## Job Body Execution (CRITICAL)

The worker credential is `BYPASSRLS` and is used for **claim, heartbeat, complete,
and the sweep only**. Every job body runs in its own transaction as the app role
with tenant context set locally; session-level `SET` is prohibited.

```python
def run_job(job: Job, handlers: dict[str, Handler], conn_factory) -> Outcome:
    logger.append_keys(job_id=str(job.job_id), case_id=str(job.case_id),
                       tenant_id=str(job.tenant_id), job_class=job.job_class)  # on claim
    with conn_factory() as conn, conn.cursor() as cur:
        cur.execute("SET LOCAL ROLE app")
        cur.execute("SET LOCAL app.tenant_id = %s", (str(job.tenant_id),))
        outcome = handlers[job.job_class](job, cur)     # handler sees an RLS-bound cursor
        conn.commit() if outcome.ok else conn.rollback()
    return outcome
```

Every step, connector invocation, and LLM call inherits those four Powertools keys;
one EMF record per LLM call carries `job_id`. Key names are identical across the
API and worker runtimes — a lint-enforced contract.

**Multi-step jobs** insert one `job_steps` row per step up front (`queued`), flip
each to `running` → `succeeded`/`failed` as it executes, and keep `jobs.current_step`
in sync. A retry resumes at the failed step; content-hash idempotency inside each
step makes re-execution of completed steps a no-op.

---

## Completion and Failure

**Retry policy:** default 3 attempts, exponential backoff with jitter between
1 and 15 minutes. The worker sets `retryable` on failure — a connector timeout is
retryable; a mapping failure is not and goes straight to `failed` on attempt 1.

```python
def backoff(attempt: int) -> timedelta:
    base = min(15 * 60, 60 * (2 ** (attempt - 1)))
    return timedelta(seconds=random.uniform(60, base))
```

```sql
-- failure, retryable, attempts remain
UPDATE jobs SET status='queued', retryable=true, next_run_at=now()+%(backoff)s,
                lease_expires_at=NULL, updated_at=now() WHERE job_id=%(job_id)s;
-- failure, terminal
UPDATE jobs SET status=%(terminal)s, lease_expires_at=NULL, updated_at=now() WHERE job_id=%(job_id)s;
```

**Timeout is the lease.** There is no separate timeout mechanism: an expired
lease on a `running` row is requeued by the sweep as a new attempt. Per-class
wall-time caps bound a single attempt by sizing the lease.

**Per-class overrides:**

| Class | max_attempts | Terminal state | Extra |
|---|---|---|---|
| `live_query` | 1 (connector does its own seconds-scale internal retry) | `quarantined` | Runner sets the case's "couldn't reach X" flag **in the same transaction** as the terminal state |
| everything else | 3 | `dead` (transient exhausted) or `failed` (non-retryable) | — |

**`dead` ≠ `quarantined` (CRITICAL):**
- `dead` — retries exhausted on a transient failure. **Ops owns it.**
- `quarantined` — extraction-failure path, partial output held, a human decides.
  **White-glove owns it.** A "white-glove ticket" *is* a quarantined row on the
  support route plus the alarm.

Emit them as **two separate EMF metrics** (this replaces any "DLQ depth"
placeholder). No separate ops UI: a `support`-role-gated route in the workbench
lists dead + quarantined jobs across tenants, shipped as a lazy-loaded support
chunk on its own path/origin.

**Pager alarms (exactly four, SNS → one email):** dead-job count > 0 in
production; sync API 5xx rate; runner task count at zero in production; budget
breach. **Morning dashboard, not pager:** queued count, enqueue-to-claim latency,
empty-poll ratio, quarantined count, per-plane spend.

---

## Due-Row Sweep

A loop inside the always-on runner; it needs no role or scheduler of its own.
**It is the sole `BYPASSRLS` query in the system.** Two duties:

```sql
-- 1. refresh: due registry rows → one refresh job + advance next_due_at, same transaction
WITH due AS (
    SELECT source_id, tenant_id, refresh_schedule
    FROM sources
    WHERE next_due_at <= now()
    FOR UPDATE SKIP LOCKED
), ins AS (
    INSERT INTO jobs (tenant_id, job_class, idempotency_key, origin_request_id, params)
    SELECT tenant_id, 'refresh',
           source_id::text || ':' || to_char(next_slot(refresh_schedule), 'YYYY-MM-DD"T"HH24:MI'),
           'sweep', jsonb_build_object('source_id', source_id)
    FROM due
    ON CONFLICT (tenant_id, job_class, idempotency_key) DO NOTHING
)
UPDATE sources s
SET next_due_at = next_slot(s.refresh_schedule) + jitter_interval()   -- cadence jittered at enqueue
FROM due WHERE s.source_id = due.source_id;

-- 2. expired leases → requeue as a new attempt, or terminal if exhausted
UPDATE jobs
SET status = CASE WHEN attempt >= max_attempts THEN 'dead'::job_status ELSE 'queued'::job_status END,
    next_run_at = now(), lease_expires_at = NULL, updated_at = now()
WHERE status = 'running' AND lease_expires_at < now();
```

Because insert and advance share one transaction, no row can double-enqueue; the
unique idempotency index is the backstop if two runners sweep at once.
Platform-default refresh runs under the reserved platform tenant and is capped
like any tenant. Scaling a destroyable environment to zero tasks must leave **no
orphaned leases** — verify this explicitly (kill mid-job, expect requeue).

---

## Frontend Contract

- **The job row is the status source of truth under any transport.** Polling is
  the MVP transport; WebSockets/SSE change the delivery, not the truth.
- The case endpoint (`GET /v1/cases/{id}`) returns the case row **and its
  `job_steps` in one indexed read** (`jobs(case_id)` → `job_steps(job_id)`).
- The status rail renders `job_steps.status` verbatim: `queued` / `running` /
  `succeeded` / `failed`. Every worker step a case waits on is a visible step — no
  silent long-running step.
- The client polls **only while the case is in a working state**, backing off toward
  a ceiling the longer a job runs. Interval and ceiling are project-set.
- Every live-query mutation carries a client-generated request id (part of its
  idempotency key); no optimistic transitions for workflow state.

---

## Tests

Run against a real Postgres (compose or testcontainers); `SKIP LOCKED` and lease
semantics do not exist in SQLite or mocks.

| Test | Asserts |
|---|---|
| Idempotent enqueue | Two enqueues with the same `(tenant_id, job_class, idempotency_key)` return the same `job_id`; one row exists |
| Transactional enqueue | Rolling back the caller's transaction leaves no job row |
| Claim exclusivity | Two concurrent claimers, one queued job → exactly one gets it, the other gets `None` |
| Lease expiry requeue | Claim, let the lease lapse, sweep → row is `queued` with `attempt` unchanged and `next_run_at <= now()`; after `max_attempts` → `dead` |
| Per-tenant cap | Tenant A has `cap` running jobs → claim returns tenant B's job, not A's next |
| Backoff window | Every computed delay lies in [1 min, 15 min] |
| Dead vs quarantined | Transient failure ×3 → `dead`; `live_query` failure → `quarantined` and the case flag set in the same transaction |
| Tenant context | Handler cursor runs as role `app` with `current_setting('app.tenant_id')` equal to the job's tenant |
| Step resume | Step 2 of 3 fails → retry starts at step 2; step 1 not re-executed |

**Milestone acceptance narrative (M2):** kill the task mid-job → lease expires →
sweep requeues → job completes on the next attempt, and the status rail shows it.

---

## Review Checklist

- [ ] Enqueue shares the caller's transaction; no post-commit or cross-connection enqueue
- [ ] Every job class has a documented idempotency-key derivation
- [ ] Claim is one atomic `UPDATE ... FOR UPDATE SKIP LOCKED ... RETURNING`
- [ ] Per-tenant, per-class cap is in the claim query, not in application code after the fact
- [ ] Job body runs under `SET LOCAL ROLE app` + `SET LOCAL app.tenant_id`; no session `SET`
- [ ] `BYPASSRLS` credential used only by claim / heartbeat / complete / sweep
- [ ] `job_status` and `step_status` never collapse into one log key
- [ ] `dead` and `quarantined` are distinct metrics with distinct owners
- [ ] Sweep insert + `next_due_at` advance are one transaction
- [ ] Placeholder columns (`params`, `step_seq`, `max_running_per_class`) flagged, not silently adopted
- [ ] No SQS / EventBridge / Step Functions proposed without citing its trigger

**Source:** ODIN v2 `ADR-007` §Decision — Dispatch & the seam; §Decision — Job-model
contract; §Decision — Scheduling; §Decision — Orchestration stance; §Decision —
Frontend transport; §Decision — Observability additions; §Architecture invariants.
`ADR-006` §Decision — Async UX contract. `05_POST_MVP_REGISTER.md` S9-01 / S9-02 /
S9-03.
