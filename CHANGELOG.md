# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This repository is not versioned; entries are grouped by date under Unreleased.

## [Unreleased]

### Added
- 2026-09-11: `/clear-context skip` — one-shot suppression of the HANDOFF.md
  reload (and the opening brief) in the next fresh context, via a
  `.claude-local/.handoff-skip` sentinel consumed by `session-handoff.sh`.
  Use it before `/implement`, which reads the plan file and
  `IMPLEMENT_STATE.md` rather than the handoff.
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
