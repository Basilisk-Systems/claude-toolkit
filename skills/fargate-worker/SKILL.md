---
name: fargate-worker
description: Generic always-on Python worker on ECS Fargate - one runner image built as a CDK DockerImageAsset (multi-stage, uv, non-root), a one-task floor with target-tracking autoscaling on a queue-depth EMF metric the runner emits, a task role vs execution role split with explicit least-privilege statements, SIGTERM-driven graceful shutdown that stops claiming and finishes or releases the in-flight lease, Powertools structured logging keyed by job_id/case_id/tenant_id, and scheduled scale-to-zero in destroyable environments. TRIGGER when writing or editing a worker Dockerfile or runner entrypoint, an ecs.FargateService / OdinWorkerService construct, task-definition IAM, autoscaling on a custom CloudWatch metric, or when the user asks how the worker plane is packaged, scaled, shut down, or given permissions. Do NOT trigger for the job table, claim query, or lease semantics themselves (use postgres-job-queue), for Lambda handlers (use aws-cdk-lambda), or for Kubernetes/EKS deployments.
allowed-tools: Read, Glob, Grep
---

# Fargate Worker Service

## Core Principle

**One generic runner image, always on, scaled by the work it can see.** The image
takes the job class as a parameter and dispatches into handlers that live in the pure
domain core; the service keeps one small task as a floor and adds tasks when the
runner's own queued-count metric says so. No RunTask-on-demand, no per-class images,
no CPU-based scaling — each of those was considered and has a named re-open trigger.

This skill is written against the ODIN v2 ADR-007 / ADR-003 contract
(`OdinWorkerService`), which is the default shape for Basilisk projects. It pairs with
`postgres-job-queue`, which owns the claim / heartbeat / complete contract the runner
calls; this skill owns everything around that loop: image, service, IAM, scaling,
shutdown, and telemetry.

---

## Where this fits

| Concern | Skill |
|---|---|
| `jobs` table, `SKIP LOCKED` claim, leases, dead vs quarantined | `postgres-job-queue` |
| Runner image, Fargate service, autoscaling, task IAM, SIGTERM, EMF | **this skill** |
| RLS roles the job body runs under (`SET LOCAL ROLE app`) | `postgres-rls-multitenant` |
| Sync API Lambdas, `OdinFunction` | `aws-cdk-lambda` |
| Paved-road construct library conventions, aspects, account naming | `aws-cdk-core` / `aws-cdk-patterns` |
| CI job that builds and pushes the image | `devops-cicd` |

---

## Decisions and rejected alternatives (CRITICAL)

| Alternative | Status | Why / re-open trigger |
|---|---|---|
| **RunTask-on-demand per job** | Rejected at MVP | Something still has to notice a job exists — the dispatch problem again — and a poller cannot scale RunTask to zero. Trigger: a class that runs hours apart leaving a large always-on task idle (S9-14) |
| **Task definition per job class** | Post-MVP | One generic task; trigger: a class needing a different CPU/memory/GPU profile (GPU embedding is the obvious one) — becomes a per-class profile on the construct (S9-13) |
| **CPU / memory target tracking** | Rejected | A poller idling at 2 % CPU with 500 queued jobs never scales; scale on the queue, not the host |
| **Scale to zero in production** | Rejected | Nothing would poll; the one-task floor is the accepted always-on cost. Dev and other destroyable environments scale to zero on a schedule |
| **Cron-style scheduled Fargate task for the sweep** | Rejected | Splits scheduling from the runner; the due-row sweep is a loop inside the always-on runner |
| **Runner reads SQS / EventBridge** | Deferred behind the dispatch seam | See `postgres-job-queue`; the runner never imports a transport |
| **Go runner image** | Struck 2026-09-03 | Everything is Python: one Powertools stack, one lint/test lane |

---

## Repo placement

```
worker/
├── Dockerfile                 # multi-stage; built by infra as a DockerImageAsset
├── pyproject.toml             # workspace member; depends on the core package only
└── src/<pkg>_worker/
    ├── __main__.py            # `python -m <pkg>_worker` — the container CMD
    ├── runner.py              # poll loop: claim → run → complete, SIGTERM aware
    ├── handlers.py            # job_class -> handler registry (handlers live in core)
    └── telemetry.py           # Powertools Logger/Metrics setup, EMF emitters
infra/
└── src/<pkg>_infra/constructs/worker_service.py   # OdinWorkerService
```

The runner entrypoint and Dockerfile live in the worker package; `infra/` builds the
image via a CDK Docker image asset. Dependency direction is one-way: the worker
imports the core; the core never imports the worker or `boto3`. Handlers receive a
`Job` and a tenant-scoped cursor and do not know what delivered them.

---

## Dockerfile

Multi-stage, `uv`-installed, non-root, no build tools in the final image.

```dockerfile
# syntax=docker/dockerfile:1.7
FROM python:3.12-slim AS builder
COPY --from=ghcr.io/astral-sh/uv:0.4 /uv /usr/local/bin/uv
WORKDIR /app
ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy UV_PYTHON_DOWNLOADS=never
# Lock + manifests first so the dependency layer caches across source edits
COPY pyproject.toml uv.lock .python-version ./
COPY core/pyproject.toml core/
COPY worker/pyproject.toml worker/
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev --no-install-workspace --package <pkg>-worker
COPY core/src core/src
COPY worker/src worker/src
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev --package <pkg>-worker

FROM python:3.12-slim AS runtime
RUN groupadd --system worker && useradd --system --gid worker --uid 10001 worker
WORKDIR /app
COPY --from=builder --chown=worker:worker /app/.venv /app/.venv
COPY --from=builder --chown=worker:worker /app/core/src /app/core/src
COPY --from=builder --chown=worker:worker /app/worker/src /app/worker/src
ENV PATH="/app/.venv/bin:$PATH" PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1
USER worker
# The runner exits non-zero on a failed startup probe; ECS restarts the task.
CMD ["python", "-m", "<pkg>_worker"]
```

Rules:

- **Build from the repo root** (`directory=repo_root` in the asset) so the workspace
  lock and the core package are in context; never `pip install` from a requirements
  file that drifts from `uv.lock`.
- **`--frozen`**, never `uv lock` inside the build. A lock change is a commit.
- **No secrets, no `.env`** baked in. Everything the runner needs at runtime arrives
  via task-definition `secrets` (ARN references) or `environment`.
- **`STOPSIGNAL`** stays the default `SIGTERM`; do not override it to `SIGKILL`.
- `.dockerignore` excludes `.venv`, `tests/`, `.git`, `mutants/`, `web/`.

---

## The service construct

The paved-road construct takes the image directory and a job-class list and mints
everything else. Bare `ecs.FargateService` in a stack is a review finding.

```python
from aws_cdk import Duration, Stack, aws_applicationautoscaling as appscaling
from aws_cdk import aws_cloudwatch as cw, aws_ec2 as ec2, aws_ecs as ecs
from aws_cdk import aws_ecr_assets as ecr_assets, aws_iam as iam, aws_logs as logs
from aws_cdk import aws_secretsmanager as secretsmanager
from constructs import Construct


class OdinWorkerService(Construct):
    """Generic always-on runner: DockerImageAsset, 1-task floor, EMF target tracking,
    least-privilege task + execution roles, scheduled scale-to-zero when destroyable."""

    def __init__(self, scope: Construct, id: str, *, cluster: ecs.ICluster,
                 image_dir: str, service_name: str, namespace: str,
                 db_secret_arn: str, artifact_bucket_arn: str, rds_proxy_resource_arn: str,
                 is_destroyable: bool, max_tasks: int = 4,
                 stop_timeout: Duration = Duration.seconds(120)) -> None:
        super().__init__(scope, id)
        stack = Stack.of(self)

        image = ecr_assets.DockerImageAsset(
            self, "Image", directory=image_dir, file="worker/Dockerfile",
            platform=ecr_assets.Platform.LINUX_AMD64,
            exclude=[".venv", "**/tests", ".git", "web", "mutants"])

        log_group = logs.LogGroup(self, "Logs", log_group_name=f"/{service_name}/worker",
                                  retention=logs.RetentionDays.THREE_MONTHS)  # LogRetentionAspect adjusts by env

        # Execution role: what ECS needs to *start* the task. Nothing the app uses.
        execution_role = iam.Role(self, "ExecRole", assumed_by=iam.ServicePrincipal("ecs-tasks.amazonaws.com"))
        execution_role.add_to_policy(iam.PolicyStatement(
            actions=["secretsmanager:GetSecretValue"], resources=[db_secret_arn]))  # injected as env at start
        execution_role.add_to_policy(iam.PolicyStatement(
            actions=["logs:CreateLogStream", "logs:PutLogEvents"], resources=[log_group.log_group_arn]))
        image.repository.grant_pull(execution_role)  # the one grant_* that is safe: same stack, no cycle

        # Task role: what the *runner process* may do. Explicit ARNs, no wildcards.
        task_role = iam.Role(self, "TaskRole", assumed_by=iam.ServicePrincipal("ecs-tasks.amazonaws.com"))
        task_role.add_to_policy(iam.PolicyStatement(
            actions=["rds-db:connect"], resources=[rds_proxy_resource_arn]))
        task_role.add_to_policy(iam.PolicyStatement(
            actions=["s3:GetObject", "s3:PutObject"],
            resources=[f"{artifact_bucket_arn}/*"]))
        task_role.add_to_policy(iam.PolicyStatement(
            actions=["s3:DeleteObject"],
            resources=[f"{artifact_bucket_arn}/unlocked/*"]))       # never the locked prefix (B2)
        task_role.add_to_policy(iam.PolicyStatement(
            actions=["cloudwatch:PutMetricData"], resources=["*"],   # EMF via logs needs nothing; this is for the rare direct put
            conditions={"StringEquals": {"cloudwatch:namespace": namespace}}))
        task_role.add_to_policy(iam.PolicyStatement(
            actions=["xray:PutTraceSegments", "xray:PutTelemetryRecords"], resources=["*"]))

        task_def = ecs.FargateTaskDefinition(
            self, "TaskDef", cpu=512, memory_limit_mib=1024,
            execution_role=execution_role, task_role=task_role,
            runtime_platform=ecs.RuntimePlatform(cpu_architecture=ecs.CpuArchitecture.X86_64))
        task_def.add_container(
            "runner",
            image=ecs.ContainerImage.from_docker_image_asset(image),
            logging=ecs.LogDrivers.aws_logs(stream_prefix="runner", log_group=log_group),
            stop_timeout=stop_timeout,
            environment={"POWERTOOLS_SERVICE_NAME": service_name,
                         "POWERTOOLS_METRICS_NAMESPACE": namespace,
                         "WORKER_LEASE_SECONDS": "300",
                         "WORKER_POLL_INTERVAL_SECONDS": "2"},
            secrets={"DB_SECRET": ecs.Secret.from_secrets_manager(
                secretsmanager.Secret.from_secret_complete_arn(self, "DbSecret", db_secret_arn))},
            health_check=ecs.HealthCheck(
                command=["CMD-SHELL", "test -f /tmp/healthy && test $(($(date +%s) - $(stat -c %Y /tmp/healthy))) -lt 60"],
                interval=Duration.seconds(30), timeout=Duration.seconds(5), retries=3,
                start_period=Duration.seconds(30)))

        self.service = ecs.FargateService(
            self, "Service", cluster=cluster, task_definition=task_def,
            service_name=service_name, desired_count=1,
            min_healthy_percent=100, max_healthy_percent=200,   # roll a new task in before the old one stops
            circuit_breaker=ecs.DeploymentCircuitBreaker(rollback=True),
            vpc_subnets=ec2.SubnetSelection(subnet_type=ec2.SubnetType.PRIVATE_WITH_EGRESS),
            enable_execute_command=False)

        self._autoscale(namespace, service_name, is_destroyable, max_tasks)
```

Two conventions the construct encodes as API shape, carried from ADR-003:

- **`add_to_role_policy` over `grant_*`** for anything in another stack — `grant_*`
  mutates the target resource's policy and creates reverse-dependency cycles, and adds
  wildcard suffixes. `grant_pull` on the asset's own ECR repository is the one
  exception (same stack, no cycle).
- **SSM parameter, not CloudFormation export**, for the proxy ARN, bucket ARN, and
  secret ARN the construct consumes from other stacks.

---

## Autoscaling on the runner's own metric

The runner emits, once per poll, the number of queued jobs it is eligible to claim and
the age of the oldest one. Target tracking on **queued jobs per task** grows the fleet
when work backs up and shrinks it back to the floor when it drains.

```python
    def _autoscale(self, namespace: str, service_name: str, is_destroyable: bool, max_tasks: int) -> None:
        scaling = self.service.auto_scale_task_count(min_capacity=1, max_capacity=max_tasks)

        queued = cw.Metric(namespace=namespace, metric_name="QueuedJobs",
                           dimensions_map={"service": service_name},
                           statistic="Maximum", period=Duration.minutes(1))
        running_tasks = cw.Metric(namespace="ECS/ContainerInsights", metric_name="RunningTaskCount",
                                  dimensions_map={"ServiceName": service_name,
                                                  "ClusterName": self.service.cluster.cluster_name},
                                  statistic="Average", period=Duration.minutes(1))
        backlog_per_task = cw.MathExpression(
            expression="FILL(queued, 0) / MAX([FILL(tasks, 1), 1])",
            using_metrics={"queued": queued, "tasks": running_tasks},
            period=Duration.minutes(1), label="queued jobs per task")

        scaling.scale_to_track_custom_metric(
            "BacklogPerTask", metric=backlog_per_task, target_value=5,
            scale_in_cooldown=Duration.minutes(10),    # long: leases must drain, and thrash at low depth is the ⚑ verify item
            scale_out_cooldown=Duration.minutes(1))

        if is_destroyable:
            # Teardown contract: destroyable environments scale to zero overnight; the floor
            # is restored on a schedule, never on a metric (a zero-task fleet emits nothing).
            scaling.scale_on_schedule("NightOff", schedule=appscaling.Schedule.cron(hour="1", minute="0"),
                                      min_capacity=0, max_capacity=0)
            scaling.scale_on_schedule("MorningOn", schedule=appscaling.Schedule.cron(hour="12", minute="0"),
                                      min_capacity=1, max_capacity=max_tasks)
```

| Setting | Value | Why |
|---|---|---|
| `min_capacity` | 1 (prod), 0 on schedule (destroyable) | The floor; nothing polls at zero |
| Metric | `QueuedJobs / RunningTaskCount` | Backlog the fleet can see, per task; CPU is meaningless for a poller |
| `target_value` | small (5) | Tune per class wall-time; start conservative |
| `scale_in_cooldown` | ≥ 2× the longest lease | A scaled-in task must finish or release its job first |
| `FILL(queued, 0)` | required | No data (idle runner) must read as zero, not as missing |
| `MAX([tasks, 1])` | required | Avoids divide-by-zero during the scheduled zero window |

**Open verification (ADR-007 §7-2):** confirm the one-task floor does not thrash at low
queue depth before trusting the target value. Scale-in that races a running lease is
the failure to look for; the SIGTERM handling below is what makes it safe.

The task-count-at-zero alarm in production is one of the four paging alarms; wire it
in the alarm pack, not here.

---

## Runner loop with graceful shutdown (CRITICAL)

ECS sends `SIGTERM`, waits `stop_timeout` (default 30 s, max 120 s on Fargate), then
`SIGKILL`s. The runner must, on `SIGTERM`: stop claiming, let the in-flight job finish
if it can within the budget, otherwise release the lease so the sweep requeues it,
and exit 0. A job killed mid-body without a release is not lost — the lease expires
and the sweep requeues it — but the release makes the requeue immediate instead of
one lease-duration late.

```python
import os, signal, threading, time
from pathlib import Path

from aws_lambda_powertools import Logger, Metrics
from aws_lambda_powertools.metrics import MetricUnit

logger = Logger(service=os.environ["POWERTOOLS_SERVICE_NAME"])
metrics = Metrics(namespace=os.environ["POWERTOOLS_METRICS_NAMESPACE"])
HEALTH_FILE = Path("/tmp/healthy")


class Runner:
    def __init__(self, dispatch, handlers, conn_factory, *, job_classes: list[str],
                 lease_seconds: int, poll_interval: float, drain_budget: float) -> None:
        self.dispatch, self.handlers, self.conn_factory = dispatch, handlers, conn_factory
        self.job_classes, self.lease_seconds = job_classes, lease_seconds
        self.poll_interval, self.drain_budget = poll_interval, drain_budget
        self._stopping = threading.Event()
        self._current_job_id = None
        signal.signal(signal.SIGTERM, self._on_term)
        signal.signal(signal.SIGINT, self._on_term)

    def _on_term(self, signum, _frame) -> None:
        logger.info("shutdown signal received", signal=signum, job_id=self._current_job_id)
        self._stopping.set()          # the loop checks this before every claim

    def run(self) -> int:
        while not self._stopping.is_set():
            HEALTH_FILE.touch()                                     # container health = "loop is alive"
            with self.conn_factory(role="worker") as conn, conn.cursor() as cur:
                self._emit_backlog(cur)                             # QueuedJobs / OldestQueuedAgeSeconds
                job = self.dispatch.claim(cur, job_class=self._next_class(), lease_seconds=self.lease_seconds)
                conn.commit()
            if job is None:
                self._stopping.wait(self.poll_interval)             # interruptible sleep
                continue
            self._run_one(job)
        logger.info("runner exiting cleanly")
        return 0

    def _run_one(self, job) -> None:
        self._current_job_id = str(job.job_id)
        logger.append_keys(job_id=str(job.job_id), case_id=str(job.case_id),
                           tenant_id=str(job.tenant_id), job_class=job.job_class)   # persistent on claim
        started = time.monotonic()
        stop_heartbeat = self._start_heartbeat(job)                 # separate connection, extends the lease
        try:
            outcome = run_job(job, self.handlers, self.conn_factory)  # SET LOCAL ROLE app inside; see postgres-job-queue
            with self.conn_factory(role="worker") as conn, conn.cursor() as cur:
                self.dispatch.complete(cur, job_id=job.job_id, outcome=outcome)
                conn.commit()
            metrics.add_metric(name="JobDurationSeconds", unit=MetricUnit.Seconds, value=time.monotonic() - started)
        except ShutdownInterrupted:
            # The body checked `stopping` at a step boundary and bailed: release, do not fail.
            with self.conn_factory(role="worker") as conn, conn.cursor() as cur:
                self.dispatch.release(cur, job_id=job.job_id)        # status back to queued, attempt unchanged
                conn.commit()
            logger.info("job released for requeue on shutdown")
        finally:
            stop_heartbeat()
            metrics.flush_metrics()
            logger.remove_keys(["job_id", "case_id", "tenant_id", "job_class"])
            self._current_job_id = None

    def _emit_backlog(self, cur) -> None:
        cur.execute("SELECT count(*), coalesce(extract(epoch FROM now() - min(next_run_at)), 0) "
                    "FROM jobs WHERE status = 'queued' AND next_run_at <= now()")
        queued, oldest_age = cur.fetchone()
        metrics.add_dimension(name="service", value=os.environ["POWERTOOLS_SERVICE_NAME"])
        metrics.add_metric(name="QueuedJobs", unit=MetricUnit.Count, value=queued)
        metrics.add_metric(name="OldestQueuedAgeSeconds", unit=MetricUnit.Seconds, value=oldest_age)
        metrics.flush_metrics()
```

Rules the loop encodes:

| Rule | Mechanism |
|---|---|
| **No new claims after the signal** | `_stopping` is checked before every claim; idle sleep is `Event.wait`, so a sleeping runner exits within one tick |
| **Finish if you can, release if you can't** | Handlers get a `should_stop()` callback and check it at step boundaries; a multi-step job releases at the boundary and resumes at `current_step` on the next attempt |
| **Drain budget < stop timeout** | `drain_budget` (e.g. 90 s) is less than the task's `stop_timeout` (120 s); a body that ignores the callback is cut off by `SIGKILL` and the lease expiry covers it |
| **Heartbeat on its own connection** | The body's transaction may be long; the heartbeat thread never shares its cursor and stops in `finally` |
| **Worker credential for claim / heartbeat / complete / release / sweep / backlog only** | Everything inside `run_job` is `SET LOCAL ROLE app` + `SET LOCAL app.tenant_id` |
| **Exit 0 on clean shutdown** | A non-zero exit on scale-in reads as a crash in the deployment circuit breaker |

`dispatch.release` is the one call this skill adds to the `postgres-job-queue` seam:
`UPDATE jobs SET status = 'queued', lease_expires_at = NULL WHERE job_id = %s AND
status = 'running'`, attempt unchanged, so a shutdown never burns a retry.

---

## Health, readiness, and startup

- **Startup probe in `__main__`:** open one DB connection as the worker role, run
  `SELECT 1`, load the handler registry, and exit 1 on any failure. ECS restarts the
  task and the circuit breaker rolls back a bad image after repeated failures.
- **Container health check** is "the loop touched `/tmp/healthy` within 60 s". A
  runner wedged inside a claim or a hung heartbeat goes unhealthy and is replaced.
  The health file is not a liveness proof of the DB; the startup probe is.
- **No HTTP port.** A poller has nothing to serve; do not add a Flask health endpoint
  and a load balancer to satisfy a checklist written for web services.

---

## Telemetry

| Signal | Where | Keys |
|---|---|---|
| Structured logs | Powertools `Logger`, JSON, one log group per service | `job_id`, `case_id`, `tenant_id`, `job_class` appended on claim, removed on completion; identical key names to the API plane (lint-enforced) |
| `QueuedJobs`, `OldestQueuedAgeSeconds` | EMF once per poll | dimension `service`; the autoscaling input |
| `JobDurationSeconds`, `DeadJobs`, `QuarantinedJobs` | EMF per job / per sweep | dead-count above zero is a paging alarm; quarantined is a morning-dashboard number |
| One EMF record per LLM call | inside the handler | model id, tokens, latency, `job_id` |
| X-Ray | trace id stored on the job row at enqueue, resumed as a subsegment on claim | one trace from the sync API through the last model call |
| `plane=worker` tag | `OdinTaggingAspect` on the service, task definition, log group | per-plane Cost Explorer view |

EMF goes out through the log driver; the task role needs no `cloudwatch:PutMetricData`
for it. Keep the statement only if something does a direct put, and condition it on
the namespace.

---

## Local development

`docker compose` runs Postgres and the runner from the same Dockerfile; the compose
service passes `DB_SECRET` as a literal JSON string with the same shape Secrets Manager
returns, so the runner's secret parsing is exercised locally. Fake adapters (Bedrock,
identity) are selected by environment, never by a code path that checks for AWS.

```bash
docker compose up -d postgres
docker compose run --rm worker python -m <pkg>_worker --once   # claim at most one job, then exit
docker compose kill -s SIGTERM worker                          # exercise the shutdown path by hand
```

`--once` exists for exactly this: a deterministic single pass for tests and smoke
checks. It is not a production mode.

---

## Tests

| Test | Type | Asserts |
|---|---|---|
| Image builds from the repo root and runs as UID 10001 | CI | `docker run --rm <image> id -u` prints `10001`; `pip` is absent from the runtime stage |
| Startup probe | Unit | Unreachable DB → exit 1 within the timeout, message names the host, no traceback |
| SIGTERM while idle | Unit (thread) | Runner exits 0 within one poll interval; `claim` not called after the signal |
| SIGTERM mid-job, cooperative handler | Integration (compose Postgres) | Job row back to `queued`, `attempt` unchanged, `lease_expires_at` NULL, exit 0 |
| SIGTERM mid-job, uncooperative handler | Integration | Runner exits when `drain_budget` lapses; lease expires; sweep requeues; attempt incremented once |
| Backlog metric | Unit | With 3 due + 1 future-dated queued rows, `QueuedJobs` = 3 |
| Heartbeat isolation | Integration | Heartbeat extends `lease_expires_at` while the body holds an open transaction on another connection |
| Task role policy | CDK assertions | No `Resource: "*"` except `xray:*`/`cloudwatch:PutMetricData` (the latter namespace-conditioned); `s3:DeleteObject` resource ends in `/unlocked/*`; the DB secret is on the task role, not any Lambda role |
| Scale-in cooldown | CDK assertions | `ScaleInCooldown >= 2 * WORKER_LEASE_SECONDS` |
| Destroyable schedule | CDK assertions | `is_destroyable=True` synthesizes two scheduled actions; `False` synthesizes none |

**Milestone narrative:** scale the service to 3, enqueue 20 jobs, scale to 1 while they
run → every job reaches `succeeded` exactly once, no job runs twice, and the status
rail never shows a job stuck in `running` past one lease duration.

---

## Anti-patterns

| Smell | Why it is wrong | Instead |
|---|---|---|
| `ecs.FargateService` written directly in a stack | Bypasses IAM, logging, scaling, and tagging conventions | `OdinWorkerService` |
| Scaling on `CPUUtilization` | A poller is idle at any backlog | Queued-per-task target tracking |
| `desired_count=0` in production | Nothing polls | One-task floor; schedule zero only where destroyable |
| `grant_read_write` on a bucket in another stack | Reverse-dependency cycle, wildcard resources | `add_to_role_policy` with explicit ARNs |
| DB secret on the execution role *and* the task role | The runner process should read it once from env; the task role only needs it if it rotates at runtime | Execution role reads at start; task role gets `rds-db:connect` |
| `signal.signal(SIGTERM, sys.exit)` | Leaves a `running` row with a live lease until it expires | Set the stop flag; release or finish |
| Heartbeat sharing the body's connection | The body's long transaction blocks the heartbeat; lease expires under a healthy job | Separate connection, own thread |
| Session-level `SET ROLE` on the pooled connection | Leaks across pinned connections through the proxy | `SET LOCAL` inside each job transaction |
| A Flask `/health` endpoint plus an ALB | Cost and surface for a service with no callers | File-touch container health check |
| Per-class images "for isolation" | Multiplies build, scan, and deploy surface with no isolation benefit | One image, job class as parameter; per-class task profile is the post-MVP seam |

---

## Review Checklist

- [ ] Image built as a `DockerImageAsset` from the repo root; multi-stage; `uv sync --frozen`; non-root `USER`; no secrets in layers
- [ ] Service is the paved-road construct, not a bare `ecs.FargateService`
- [ ] `desired_count` / `min_capacity` = 1 in production; scheduled zero only when `is_destroyable`
- [ ] Target tracking on `QueuedJobs / RunningTaskCount` with `FILL(...)` and a `MAX(..., 1)` guard; no CPU-based policy
- [ ] `scale_in_cooldown` ≥ 2× the longest lease
- [ ] Execution role: image pull, log write, secret read at start — nothing else
- [ ] Task role: explicit ARNs; `s3:DeleteObject` only on the unlocked prefix; `BYPASSRLS` secret reachable from this role and no Lambda role
- [ ] `add_to_role_policy` over `grant_*` for cross-stack resources; SSM over CFN export for consumed ARNs
- [ ] `stop_timeout` set; runner `drain_budget` < `stop_timeout`; `STOPSIGNAL` left as `SIGTERM`
- [ ] SIGTERM handler sets a flag; no claim after the flag; in-flight job finishes at a step boundary or is released with `attempt` unchanged
- [ ] Heartbeat runs on its own connection and stops in `finally`
- [ ] Worker credential used only for claim / heartbeat / complete / release / sweep / backlog; job body under `SET LOCAL ROLE app` + `SET LOCAL app.tenant_id`
- [ ] Logger keys `job_id`, `case_id`, `tenant_id`, `job_class` appended on claim and removed on completion; names identical to the API plane
- [ ] `QueuedJobs` and `OldestQueuedAgeSeconds` emitted once per poll; `DeadJobs` wired to the paging alarm pack
- [ ] `plane=worker` tag applied by the tagging aspect; log group retention governed by `LogRetentionAspect`
- [ ] Startup probe exits non-zero on a bad DB or handler registry; deployment circuit breaker with rollback on
- [ ] No SQS / EventBridge / RunTask / per-class image proposed without citing its trigger

**Source:** ODIN v2 `ADR-007` §Decision — Worker packaging & language; §Decision —
Runtime IAM & cross-account; §Decision — Observability additions; §Architecture
invariants; §7 Open verifications items 2, 6, 7. `ADR-003` §Construct contract
(`OdinWorkerService`, `OdinTaggingAspect`, `LogRetentionAspect`); §Teardown contract;
§Observability floor. `05_POST_MVP_REGISTER.md` S9-13 / S9-14 / S9-15.
