# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This repository is not versioned; entries are grouped by date under Unreleased.

## [Unreleased]

### Changed
- 2026-10-27: context estimation rescaled from a hardcoded 200k window to a
  configurable one. `CLAUDE_CONTEXT_WINDOW_TOKENS` in `settings.json` `env`
  (default `1000000`, the Claude 5 family window; `200000` for Haiku 4.5) is
  read by `session-start.sh`, which prints a `Context Window:` line with the
  tokens-per-1% figure into every session. `CONTEXT_WEIGHTS.md` now lists
  per-action costs in tokens with percentages at the 1M default (HANDOFF.md
  ~0.7%, large file read ~1%, ~2% baseline), and `/context-status`,
  `/estimate-context` and the CLAUDE.md context-reporting rule reference the
  configured window instead of `200k`.
- 2026-10-26: `mobile-design-guidelines` › Iduna "Open deviations": the IDNA-104
  (Log-tab delete alerts → immediate soft delete + inline Undo) and IDNA-105 (radar
  legend row) bullets move to the "Resolved by …" line now that both are merged; the
  only remaining entry is the accepted two-button pre-permission deviation.
- 2026-10-19: `/walkthrough` writes its explanation to one Markdown file,
  `~/.claude/walkthroughs/<repo>--<branch>.md` (a re-run of the same branch replaces
  it), and opens it the way `/blueprint` opens a plan; the terminal gets the concept
  map to steer on, then a one-line pointer, never the document. The batch-and-pause
  delivery is replaced by a follow-up prompt (question, go deeper, done) whose
  answers append to the file. New `clean [all]` mode lists and deletes the
  repository's (or every) walkthrough file after confirmation. `/complete` Step 9
  sweeps `~/.claude/walkthroughs/` by ticket id beside `~/.claude/plans/`, so a
  finished ticket's walkthrough is offered for deletion with its plan. The command
  gains `Write`/`Edit` for its own file only; the repository stays read-only.

### Added
- 2026-10-19: `/walkthrough [base-branch] [ticket-id|plan]` workflow command — an
  explanation of a branch's diff for the developer, concept by concept (4–8 themes
  ordered foundations → consumers), each tied to the acceptance criterion, plan
  phase or recorded decision it implements, with departures from the plan read
  from `IMPLEMENT_STATE.md`/`HANDOFF.md` and the tests that pin each theme.
  Delivered in batches with a pause for questions, closing with "decisions to
  confirm", "flagged for /code-review" and "not in this diff". Explicitly not a
  review: no verdicts or fix suggestions, read-only, hands off to `/code-review`
  and `/pre-merge`. Fills the gap between an `/implement` run and the developer's
  own review of a diff they did not type.
- 2026-10-16: `mobile-design-guidelines` skill — the platform rulebook distilled
  from Apple's Human Interface Guidelines (39 pages, iOS 26 / Liquid Glass era)
  and Material 3 / Android guidance where Android differs, written for React
  Native + Expo. 13 sections (layout, typography, colour and dark mode, button
  prominence, navigation chrome and back behaviour incl. predictive back, forms
  and pickers, modality, feedback, onboarding/accounts/permissions, lists and
  charts, accessibility, notifications), each rule cited to its source page,
  plus twelve `references/*.md` topic files and a project-mapping section with
  an "open deviations" audit pattern. Complements `mobile-ux-patterns` (flow
  patterns) rather than replacing it. Research note: both guideline sites are
  client-rendered; Apple's page text is reachable at
  `developer.apple.com/tutorials/data/design/human-interface-guidelines/<slug>.json`
  and Material's at the `material-components-android` docs and
  developer.android.com.
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
- 2026-09-29: Plan-file cleanup no longer depends on a clean `/implement`
  run. `/complete <ticket>` gained a sweep step: it finds plans in
  `~/.claude/plans/` whose title line names the ticket ID as a whole token
  (the directory is shared across projects, so never by age), lists each with
  its companion files (`<name>-*`, `<name>.md.tmp.*`), and deletes them on
  confirmation; plans whose title names other tickets default to Keep.
  `/implement` Step 8 now removes those companion files with the plan and,
  when a failed or skipped phase blocks cleanup, reports the plan as retained
  instead of leaving it silently. Previously any run with a manual or
  multi-session phase, and any plan executed without `/implement`, stayed in
  `~/.claude/plans/` forever.
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
