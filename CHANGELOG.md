# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This repository is not versioned; entries are grouped by date under Unreleased.

## [Unreleased]

### Added
- 2026-08-04: `/smoke-test` workflow command — turns a ticket's E2E/smoke criteria
  (or pasted criteria / a description) into detailed step-by-step test instructions
  with expected output, runs them interactively, classifies criteria as
  AUTOMATED/MANUAL/BLOCKED, and records a PASS/FAIL/INCOMPLETE verdict in
  `.claude-local/SMOKE_TESTS.md`.

### Changed
- 2026-08-04: `/complete` Step 2 now gates ticket checkbox completion on a
  `/smoke-test` PASS record (or explicit user override) when the ticket has
  testing criteria, and annotates BLOCKED items instead of checking them.
- 2026-08-04: `config/CLAUDE.md` Task Completion workflow now includes running
  `/smoke-test` before `/complete`.
