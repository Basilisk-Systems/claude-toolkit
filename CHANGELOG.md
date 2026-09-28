# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This repository is not versioned; entries are grouped by date under Unreleased.

## [Unreleased]

### Added
- 2026-09-28: `block-test-credentials.sh` global PreToolUse hook (matcher `*`),
  plus `permissions.deny` Read/Edit rules on `~/.claude/TEST_CREDENTIALS.md*`
  in `config/settings.json`. Keyword greps had leaked live passwords from that
  file into context twice. The hook blocks any path/command naming the file,
  plus content reads that would reach it anyway: Grep over the `~/.claude` root
  or home, and Bash (checked per pipeline stage) readers given the root or a
  root glob, recursive readers over `~`, `find -exec`, `find | xargs`, and
  `cd ~/.claude` followed by a recursive read. Write/Edit content is not
  checked, so docs can still mention the file. Non-secret values move to
  `~/.claude/TEST_CONFIG.md`. 30-case pipe test in `hooks/tests/`.
- 2026-09-23: `test-writing` skill — purposeful, non-redundant tests. A
  fact-ledger-then-survey workflow, the "which mutation kills this test?" gate
  before a test is written, a twelve-row frivolous-test catalogue (did-not-raise,
  second literal pin, identical-path parametrize, echoing the mock, coverage
  bait, forced defensive branches with no contract, ...), a coverage-dynamic-
  contexts recipe for finding same-file duplicate tests, scoped mutation runs
  (mutmut / Stryker) with survivor triage, and a ten-item review checklist the
  `/code-review` Testing agent now cites. Registered in the README skill list
  and `config/snippets/skills.md`.
- 2026-09-11: `/clear-context skip` — one-shot suppression of the HANDOFF.md
  reload (and the opening brief) in the next fresh context, via a
  `.claude-local/.handoff-skip` sentinel consumed by `session-handoff.sh`.
  Use it before `/implement`, which reads the plan file and
  `IMPLEMENT_STATE.md` rather than the handoff.
- 2026-09-04: six skills for the Postgres + Fargate + Descope + Vite stack
  (the ODIN v2 build's named toolkit gaps): `postgres-rls-multitenant`
  (two-role RLS, `SET LOCAL` tenant context, two-tenant leak test, pgvector +
  FTS pre-filter), `alembic-migrations` (DDL single-sourced from migrations,
  roles/policies/extensions as migration objects, up/down CI gate),
  `postgres-job-queue` (`jobs`/`job_steps` dispatch contract with `SKIP
  LOCKED` claims, leases, idempotent enqueue, dead vs quarantined),
  `fargate-worker` (generic Python runner image, always-on floor, EMF
  autoscaling, least-privilege task roles, graceful shutdown), `descope-auth`
  (IdP broker behind a seam, Lambda REQUEST authorizer, role→permission RBAC,
  in-memory browser sessions), and `playwright-e2e` (codify a ticket's E2E
  narrative into a spec with auth fixtures, polling-aware assertions, axe,
  tenant/RBAC checks). Registered in the README skill list and
  `config/snippets/skills.md`.
- 2026-08-05: `web-ui-verify` skill — headless-browser visual verification for
  web UI changes: launch the dev server, drive Chromium via playwright-core
  (with browser-binary discovery), then prove claims with screenshots,
  `getBoundingClientRect` geometry, PIL pixel sampling, and
  `elementsFromPoint` stack inspection. Registered in the README skill list
  and `config/snippets/skills.md`.
- 2026-08-04: `/smoke-test` workflow command — turns a ticket's E2E/smoke criteria
  (or pasted criteria / a description) into detailed step-by-step test instructions
  with expected output, runs them interactively, classifies criteria as
  AUTOMATED/MANUAL/BLOCKED, and records a PASS/FAIL/INCOMPLETE verdict in
  `.claude-local/SMOKE_TESTS.md`.

### Changed
- 2026-09-28: `/blueprint` opens the written plan in VS Code (`code <plan>`)
  before asking for approval, falling back to printing the path when `code`
  is not on PATH, and re-opens it after each revision. The approval question
  itself names the plan path, since text printed just before an
  AskUserQuestion call can be hidden behind the dialog.
- 2026-09-16: `session-handoff.sh` prints the "Where we left off" instruction
  *before* the injected HANDOFF.md instead of after it. Claude Code caps inline
  hook output at ~10 KB and persists anything larger to a tool-results file,
  showing Claude only a ~2 KB preview, so a trailing instruction was silently
  lost once handoffs grew past the cap. When HANDOFF.md exceeds 8 KB the hook
  also emits a note telling Claude to Read the full file at its absolute path
  before writing the brief, and the section header now shows the file size.
- 2026-09-11: `session-handoff.sh` now appends an instruction after the
  injected HANDOFF.md asking Claude to open its first reply with a 4-6 bullet
  "Where we left off" brief (branch/commit, verified working, blockers, next
  actions). It also ignores the built-in `/clear` prompt so that keystroke can
  never rewrite the session marker or consume the skip sentinel.
- 2026-08-06: `/standup summary` "Yesterday" is now delta-based — it reports only
  items completed since the last summary run, then files them under a
  `## Reported` section in `STANDUP.md` so they never appear twice. Previously
  it sourced "Yesterday" from the Previous Period archive, which rolls on a 24h
  timer misaligned with standups and calendar days, so same-day work leaked
  into "Yesterday". Works with both Current and Previous Period, survives
  period rollovers, and needs no changes to `/commit`, `/complete`, or
  `/pre-merge`.
- 2026-08-04: `/complete` Step 2 now gates ticket checkbox completion on a
  `/smoke-test` PASS record (or explicit user override) when the ticket has
  testing criteria, and annotates BLOCKED items instead of checking them.
- 2026-08-04: `config/CLAUDE.md` Task Completion workflow now includes running
  `/smoke-test` before `/complete`.
