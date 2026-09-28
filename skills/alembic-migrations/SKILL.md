---
name: alembic-migrations
description: Alembic migration discipline for Postgres-backed services - DDL single-sourced from versioned migrations (never ORM create_all or hand-applied SQL), roles, grants, RLS policies and extensions as migration objects with real downgrades, stable naming conventions for autogenerate, one linear head, an up/down/up CI gate on a fresh database with an autogenerate no-op check, expand/contract deployment ordering, and a migration-runner role distinct from the app and worker roles. TRIGGER when creating or editing files under a migrations/ or alembic/ directory (env.py, alembic.ini, versions/*.py), when a schema, role, policy, or extension change is proposed, when a CI job runs alembic upgrade/downgrade, or when the user asks how DDL, backfills, or database roles are versioned and deployed. Do NOT trigger for RLS policy semantics and tenant-context handling (use postgres-rls-multitenant), job-table dispatch design (use postgres-job-queue), or DynamoDB/NoSQL schema work.
allowed-tools: Read, Glob, Grep
---

# Alembic Migrations

## Core Principle (CRITICAL)

**The migrations directory is the only source of DDL.** Every table, index, role,
grant, policy, and extension the database has was created by a numbered revision that
is in git, has a `downgrade()`, and has been applied and reversed on a fresh database
in CI. Nothing else creates schema: no `metadata.create_all()`, no `psql -f` at deploy
time, no console edits, no "temporary" manual index.

ORM models (if any) *mirror* the migrations. When autogenerate proposes an op, that is
a prompt to write a revision, not a permission to skip one. When a revision and a
model disagree, the revision is right and the model is fixed.

This skill is written against the ODIN v2 planning decisions (ADR-002 §Consequences,
ADR-001 inv 5, ADR-007 inv 10, ODIN-117) and is the default for Basilisk projects. A
project's migration-framework ADR pins the choices marked **ADR-pinned** below; until
it exists, use the defaults here and say so in the ticket.

---

## Where this fits

| Concern | Skill |
|---|---|
| What the migration *contains* for tenant isolation (policy text, `SET LOCAL` discipline, leak test) | `postgres-rls-multitenant` |
| What the `jobs` / `job_steps` tables look like and why they carry no policy | `postgres-job-queue` |
| How DDL, roles, policies, and extensions are **versioned, applied, reversed, gated, and deployed** | **this skill** |
| CDK wiring of the migration task, secrets, and the database itself | `aws-cdk-core` / `fargate-worker` |

---

## Package Layout

The migrations plane is its own package that depends on **no other plane**, including
the domain library. It imports SQLAlchemy Core and Alembic only. (ODIN: `migrations/`
→ `odin_migrations`, independence contract in the root `pyproject.toml`, ADR-008
§Decision — Dependency direction.)

```
migrations/
├── pyproject.toml            # package metadata only; tool config lives at the workspace root
├── alembic.ini               # script_location = src/odin_migrations/alembic; no URL here
└── src/odin_migrations/
    ├── __init__.py
    ├── alembic/
    │   ├── env.py            # URL from env / secret reference; naming convention; RLS-safe options
    │   ├── script.py.mako
    │   └── versions/
    │       ├── 0001_platform_tenant_roles_rls_helpers.py
    │       ├── 0002_price_observations.py
    │       └── ...
    ├── naming.py             # the single MetaData naming_convention (shared with models)
    └── helpers.py            # provenance-base mixin, RLS policy helpers (pure SQL strings)
```

**Rules:**

- `alembic.ini` never holds a URL. `env.py` reads `DATABASE_URL` (local) or resolves a
  **secret reference** (`DATABASE_SECRET_ARN` / `/tenants/...` path) at run time. The
  value is never logged; log the reference.
- Revision ids are **ADR-pinned**: sequential zero-padded numbers (`0001_`, `0002_`)
  are the default because they sort in `ls` and in code review. Configure
  `file_template = %%(rev)s_%%(slug)s` and generate with `--rev-id 0007`.
- `helpers.py` contains SQL-string builders only. A migration may call
  `rls_policies_for("price_observations")`; it may not import a domain model.

### `env.py` essentials

```python
import os
from alembic import context
from sqlalchemy import engine_from_config, pool
from odin_migrations.naming import NAMING_CONVENTION, metadata  # models' MetaData or an empty one

def _url() -> str:
    if url := os.environ.get("DATABASE_URL"):
        return url
    ref = os.environ["DATABASE_SECRET_ARN"]           # reference, never the value
    return resolve_secret_url(ref)                    # boto3 lives here, nowhere else in the package

def run_migrations_online() -> None:
    cfg = context.config.get_section(context.config.config_ini_section) or {}
    cfg["sqlalchemy.url"] = _url()
    connectable = engine_from_config(cfg, prefix="sqlalchemy.", poolclass=pool.NullPool)
    with connectable.connect() as conn:
        context.configure(
            connection=conn,
            target_metadata=metadata,
            compare_type=True,
            compare_server_default=True,
            include_schemas=False,
            transaction_per_migration=True,           # one DDL transaction per revision
            render_as_batch=False,                    # Postgres: never batch mode
        )
        with context.begin_transaction():
            context.run_migrations()
```

`transaction_per_migration=True` means a failed revision rolls back to the previous
head, not to `base`. `NullPool` because the runner is a one-shot task.

---

## Naming Conventions (autogenerate stability)

Unnamed constraints get database-generated names that differ between a fresh database
and one that has been upgraded through history, which makes `downgrade()` guess and
autogenerate emit phantom drops. Pin the convention once and import it everywhere:

```python
# naming.py
from sqlalchemy import MetaData

NAMING_CONVENTION = {
    "ix":  "ix_%(table_name)s_%(column_0_N_name)s",
    "uq":  "uq_%(table_name)s_%(column_0_N_name)s",
    "ck":  "ck_%(table_name)s_%(constraint_name)s",
    "fk":  "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk":  "pk_%(table_name)s",
}
metadata = MetaData(naming_convention=NAMING_CONVENTION)
```

Every `op.create_index` / `op.create_foreign_key` in a hand-written revision uses the
same pattern by hand. A `CHECK` constraint always passes an explicit `name=`.

---

## Migration Objects Beyond Tables (CRITICAL)

Roles, grants, policies, and extensions are **revisions**, not setup scripts. Each is
written as an idempotent `op.execute` block with a real `downgrade()`.

### Extensions

```python
def upgrade() -> None:
    op.execute("CREATE EXTENSION IF NOT EXISTS pgcrypto")   # gen_random_uuid()
    op.execute("CREATE EXTENSION IF NOT EXISTS vector")     # pgvector

def downgrade() -> None:
    op.execute("DROP EXTENSION IF EXISTS vector")
    op.execute("DROP EXTENSION IF EXISTS pgcrypto")
```

`CREATE EXTENSION` needs a privilege the app role must not have; the migration runner
role has it (see §Roles). On Aurora, `vector` and `pgcrypto` are on the allow-list;
verify availability on any other substrate before the ADR pins them (ADR-004 §7 verify
items).

### Roles and grants

Roles are cluster-wide, so `CREATE ROLE` is not transactional per-database and
`IF NOT EXISTS` does not exist. Use a `DO` block:

```python
ROLE_SQL = """
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app') THEN
    CREATE ROLE app NOLOGIN NOBYPASSRLS;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'worker') THEN
    CREATE ROLE worker NOLOGIN BYPASSRLS;
  END IF;
END $$;
"""

def upgrade() -> None:
    op.execute(ROLE_SQL)
    op.execute("GRANT USAGE ON SCHEMA public TO app, worker")
    op.execute("ALTER DEFAULT PRIVILEGES IN SCHEMA public "
               "GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app")
    op.execute("ALTER DEFAULT PRIVILEGES IN SCHEMA public "
               "GRANT SELECT, INSERT, UPDATE ON TABLES TO worker")

def downgrade() -> None:
    op.execute("REVOKE ALL ON ALL TABLES IN SCHEMA public FROM app, worker")
    op.execute("ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES FROM app, worker")
    op.execute("DROP ROLE IF EXISTS worker")
    op.execute("DROP ROLE IF EXISTS app")
```

Login users (`app_user`, `worker_user`) that `SET ROLE` into these are **not**
migration objects: they are created by infra with secrets-managed passwords and
granted membership (`GRANT app TO app_user`) by the same infra step. The migration
owns the *role*, infra owns the *credential*.

### RLS policies

Every tenant-owned table gets `ENABLE ROW LEVEL SECURITY`, `FORCE ROW LEVEL SECURITY`
(so the table owner is bound too), and its policies **in the same revision that
creates the table**. Use a helper so the policy text is written once:

```python
# helpers.py
PLATFORM = "00000000-0000-0000-0000-000000000001"   # reserved platform tenant UUID (ADR-002 §7-7 closure)

def enable_rls(table: str) -> list[str]:
    return [
        f"ALTER TABLE {table} ENABLE ROW LEVEL SECURITY",
        f"ALTER TABLE {table} FORCE ROW LEVEL SECURITY",
        f"CREATE POLICY {table}_tenant_read ON {table} FOR SELECT TO app USING ("
        f"  tenant_id = current_setting('app.tenant_id', true)::uuid"
        f"  OR tenant_id = '{PLATFORM}'::uuid)",
        f"CREATE POLICY {table}_tenant_write ON {table} FOR ALL TO app USING ("
        f"  tenant_id = current_setting('app.tenant_id', true)::uuid)"
        f" WITH CHECK (tenant_id = current_setting('app.tenant_id', true)::uuid)",
    ]

def disable_rls(table: str) -> list[str]:
    return [
        f"DROP POLICY IF EXISTS {table}_tenant_write ON {table}",
        f"DROP POLICY IF EXISTS {table}_tenant_read ON {table}",
        f"ALTER TABLE {table} NO FORCE ROW LEVEL SECURITY",
        f"ALTER TABLE {table} DISABLE ROW LEVEL SECURITY",
    ]
```

```python
# 0002_price_observations.py
def upgrade() -> None:
    op.create_table("price_observations", *provenance_base(), sa.Column("tenant_id", UUID, nullable=False), ...)
    for stmt in enable_rls("price_observations"):
        op.execute(stmt)

def downgrade() -> None:
    for stmt in disable_rls("price_observations"):
        op.execute(stmt)
    op.drop_table("price_observations")
```

`current_setting('app.tenant_id', true)` (missing-ok) returns NULL rather than raising
when no tenant is set, so an unset connection sees **no rows** instead of an error
that a caller might catch and retry without context. Platform tables (`jobs`,
`job_steps`, `tenants`) get no policy and are documented as such in the revision
docstring. Policy *semantics* — what the worker path sets, how the leak test proves
isolation — are `postgres-rls-multitenant`'s to define; this skill only insists they
are versioned here.

### Migration one (worked example)

The first revision of a tenant-isolated system creates, in order: extensions; the
two roles and default grants; the `tenants` table with the delete-protected platform
row (`INSERT ... ON CONFLICT DO NOTHING` plus a `BEFORE DELETE` trigger that raises
for the platform UUID); the RLS helper functions if any are SQL functions; and
nothing domain-specific. Its `downgrade()` reverses all of it. (ODIN-117.)

---

## Schema vs Data Migrations

| Kind | Rule |
|---|---|
| **Schema** (DDL) | One concern per revision. Transactional. Reversible by construction. |
| **Data backfill** | Separate revision from the DDL that made it possible. Batched (`UPDATE ... WHERE id IN (SELECT ... LIMIT 5000)` in a loop), idempotent (re-runnable after a crash), and `downgrade()` either reverses it or states in its docstring why it is one-way and what the operator does instead. |
| **Seed / reference data** | Only platform-level rows that the code cannot start without (the platform tenant). Everything else is application data and arrives through the application. |

A backfill on a table over a few hundred thousand rows runs in a dedicated task with
`transaction_per_migration` still on but the loop committing per batch via
`op.get_bind().execution_options(isolation_level="AUTOCOMMIT")`, so the table is never
locked for the full duration.

---

## Linear History (CRITICAL)

- **One head, always.** CI fails on `alembic heads` returning more than one line.
  Resolve by rebasing the branch's revision `down_revision` onto the new head, not by
  `alembic merge`, unless two long-lived branches genuinely landed independently.
- **Never edit a merged revision.** Once a revision is on `main`, its contents are
  frozen; a mistake gets a new revision that corrects it. Editing a merged file
  leaves every environment that already applied it silently diverged.
- **`downgrade()` is real.** `pass` is not a downgrade. If an operation is truly
  irreversible (a column dropped with its data), the docstring says so, the
  downgrade recreates the column empty, and the PR calls it out.
- **Every revision has a docstring** naming the ticket and the ADR section it
  implements, so `git blame` on the database is one `ls versions/` away.

---

## The CI Gate (CRITICAL)

Runs on every PR that touches `migrations/`, against a fresh Postgres with the
extensions available (Docker Compose `pgvector/pgvector:pg16` or the project's
compose service), as the migration-runner role:

```bash
alembic upgrade head                      # 1. forward from empty
alembic downgrade base                    # 2. all the way back; every downgrade() runs
alembic upgrade head                      # 3. forward again; proves downgrade left nothing behind
alembic heads | wc -l | grep -qx 1        # 4. exactly one head
alembic check                             # 5. autogenerate proposes NO ops (models mirror migrations)
pytest tests/db/test_rls_leak.py          # 6. seeded two-tenant leak test under role `app`
psql -c "SELECT relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace \
  WHERE n.nspname='public' AND c.relkind='r' AND NOT c.relrowsecurity \
  AND relname NOT IN ('alembic_version','jobs','job_steps','tenants')" | grep -q '(0 rows)'   # 7. no unprotected tenant table
```

Step 7 is the structural guard for "RLS on every evidence table": a new tenant-owned
table without policies fails CI before a reviewer has to notice. The allow-list of
platform tables is a file in the repo, not an inline string, so adding to it is a
reviewed change.

`alembic check` (Alembic ≥ 1.9) exits non-zero when autogenerate would emit
operations. It requires `target_metadata` to be the real models' metadata; on a
project with no ORM, skip step 5 and say so in the ADR.

---

## Deployment Ordering

1. **Migrations run first, as a one-off task**, from the same image tag the app and
   worker are about to roll to, under the migration-runner credential. The pipeline
   blocks on its exit code. Lambda/API and worker services never run `alembic` on
   start-up — two instances starting together would race.
2. **Expand / contract for zero-downtime.** A rename or type change is three
   deploys: add the new column (expand), ship code that writes both and reads new,
   backfill, then drop the old column (contract) in a later release. A migration that
   the *previous* app version cannot run against is a deploy-blocking finding.
3. **Long locks are named.** `ALTER TABLE ... ADD COLUMN ... DEFAULT <volatile>`,
   `CREATE INDEX` without `CONCURRENTLY`, and type changes take `ACCESS EXCLUSIVE`.
   `CREATE INDEX CONCURRENTLY` cannot run inside a transaction: mark that revision
   with `transactional_ddl = False` via `op.get_context().autocommit_block()`.
4. **Rollback is a forward fix.** Production never runs `downgrade`; the CI gate
   proves it *could*. A bad revision is followed by a correcting revision.

---

## Roles: who runs what

| Role | Attributes | Used by | Never |
|---|---|---|---|
| **migrator** (`odin_migrator` login) | owns the schema; `CREATE` on database; can `CREATE EXTENSION`, `CREATE ROLE`, `CREATE POLICY` | the migration task only | serves a request or a job |
| **app** | `NOBYPASSRLS`; DML via default privileges; RLS-bound | the sync API; every job body after `SET LOCAL ROLE app` | DDL; `BYPASSRLS` |
| **worker** | `BYPASSRLS`; DML on platform tables | the runner's claim / heartbeat / complete / sweep queries only | a tenant-scoped read; DDL |

The migrator role's credential exists only in the pipeline and the migration task
definition. It is not in the app or worker secret paths. Creating `migrator` itself is
infra's job (it must exist before the first migration runs); everything it creates
is a migration object.

---

## Anti-patterns

| Anti-pattern | Why it fails | Do instead |
|---|---|---|
| `Base.metadata.create_all()` in tests or a bootstrap script | Two sources of DDL drift within a sprint; tests pass on a schema production never has | Tests run `alembic upgrade head` against the compose database |
| A `setup.sql` with roles and extensions applied "once by hand" | Invisible to review, unreproducible on the next environment | Migration one |
| Policies added by a separate "security" revision weeks after the table | The table shipped unprotected; the CI structural check (step 7) would have caught it | Policies in the same revision as the table |
| `downgrade(): pass` | The up/down/up gate is a lie; nobody knows if the revision is reversible | Real reverse, or a documented one-way with the operator procedure |
| Editing a merged revision to fix a typo | Applied environments diverge silently | A new correcting revision |
| URL in `alembic.ini` or a committed `.env` | Credential in git | Env var locally; secret reference in CI and tasks |
| App container runs `alembic upgrade` on boot | Races between replicas; a failed migration takes the app down with it | One-off task, pipeline blocks on it |
| Autogenerate output committed unread | Phantom drops from naming drift; `server_default` churn | Read every op; run `alembic check` in CI |
| `CREATE INDEX` on a large table inside the transaction | `ACCESS EXCLUSIVE` for the build duration | `CONCURRENTLY` in an autocommit block, in its own revision |
| Domain model import in a revision | Migration breaks when the model changes; plane independence violated | SQLAlchemy Core and SQL strings only |

---

## Review Checklist

- [ ] Revision has a docstring naming the ticket and ADR section
- [ ] One concern per revision; DDL and backfill in separate revisions
- [ ] `downgrade()` is real, or documented one-way with an operator procedure
- [ ] Constraints and indexes are named per the shared naming convention
- [ ] New tenant-owned table: `tenant_id uuid NOT NULL`, provenance base, `ENABLE` + `FORCE` RLS, read and write policies, all in this revision
- [ ] New platform table: added to the allow-list file with a reason
- [ ] Roles / grants / extensions / policies use idempotent `op.execute` blocks with matching reverse statements
- [ ] No import from the domain library or any other plane
- [ ] No credential value in `alembic.ini`, `env.py`, or the revision
- [ ] `alembic heads` is one line after rebase
- [ ] CI gate ran: `upgrade head` → `downgrade base` → `upgrade head` → `check` → leak test → unprotected-table scan
- [ ] Lock impact stated for any `ALTER` on a populated table; `CONCURRENTLY` used for indexes
- [ ] Previous app version can run against the new schema (expand step), or the PR says why not

**Source:** ODIN v2 `ADR-002` §Consequences (:423-426), §7 item 5 (:463-465), §7-7
closure (:479-487); `ADR-001` §Architecture invariants inv 5 (:167-180); `ADR-007`
§Architecture invariants inv 10 (:590-595); `ADR-008` §Decision — Package tree,
§Decision — Dependency direction; `08_MILESTONES.md:96-97, :114-115`; ODIN-117.
Migration-framework ADR (Batch 3 i) pending — items marked **ADR-pinned** are defaults
until it lands.
