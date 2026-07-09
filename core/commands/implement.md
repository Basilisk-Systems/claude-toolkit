---
description: Orchestrate automated implementation using sub-agents for each plan phase
argument-hint: [optional: plan file path or "resume"]
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent
---

# Automated Implementation Orchestrator

Execute an approved plan by delegating each phase to a sub-agent. The main conversation stays lean as an orchestrator while agents do the heavy implementation work.

## Step 1: Load the Plan

**If `$ARGUMENTS` is "resume":** Read `.claude-local/IMPLEMENT_STATE.md` and resume from the first incomplete phase. Skip to Step 4.

**If `$ARGUMENTS` is a file path:** Read that file as the plan.

**Otherwise:** Find the most recent plan:
```bash
ls -t ~/.claude/plans/*.md | head -1
```

Read the plan file contents.

## Step 2: Extract Ticket ID and Branch Context

```bash
git branch --show-current
```
Extract the ticket ID (e.g., `TICKET-123` from branch name, following the repo's ticket convention). Also capture:
```bash
pwd
git log --oneline -3
```

## Step 3: Parse and Validate Phases

Identify phases in the plan. Look for:
- `## Phase N:` or `### Phase N:` headings
- `## Step N:` headings
- Clearly separated implementation sections

For each phase, extract:
- **Title**: Short name (e.g., "Backend Infrastructure")
- **Description**: What this phase accomplishes
- **Files to create**: List with paths and descriptions
- **Files to modify**: List with paths and change descriptions
- **Tests to run**: Specific test commands
- **Acceptance criteria**: What defines "done"
- **Key context**: Patterns to follow, reference files, dependencies on prior phases

**If the plan lacks clear phases:** Restructure it by grouping related tasks:
1. Infrastructure/CDK changes
2. Backend (Lambda handlers, utilities)
3. Frontend (components, RTK Query, state)
4. Tests and documentation

Display the phase breakdown and ask for confirmation before proceeding.

## Step 4: Initialize State Tracking

Create `.claude-local/IMPLEMENT_STATE.md`:

```markdown
# Implementation State

- **Plan**: [plan file name]
- **Ticket**: [ticket ID]
- **Branch**: [branch name]
- **Started**: [timestamp from `date`]
- **Phases**: [total count]

## Phase Progress

| # | Title | Status | Commit | Notes |
|---|-------|--------|--------|-------|
| 1 | [title] | pending | — | — |
| 2 | [title] | pending | — | — |

## Phase Details

### Phase 1: [title]
- Status: pending
- Files changed: —
- Test results: —
- Notes: —
```

If resuming, read the existing state file and skip completed phases.

## Step 5: Execute Phases Sequentially

For each pending phase:

### 5a. Pre-flight
```bash
git status
git log --oneline -3
```
Confirm clean working tree. If dirty, stop and ask user.

### 5b. Construct Agent Prompt

Build a detailed prompt for the Agent tool. **This is the most critical step — the agent works autonomously from this prompt alone.**

Include ALL of the following in the agent prompt:

```
You are implementing Phase [N] of [total] for ticket [TICKET-ID].

## Project
Working directory: [absolute path to repo]
Read the repo's CLAUDE.md and README for project context, identity, and conventions.

## CRITICAL — Read These First
1. Read `CLAUDE.md` in the repo root for code patterns and conventions
2. Read each file you plan to modify BEFORE making changes
3. [Any specific reference files for this phase]

## Your Task — Phase [N]: [phase title]
[phase description from plan]

### Files to Create
[list with paths and descriptions]

### Files to Modify
[list with paths and change descriptions]

### Prior Phases Completed
[for each completed phase: title, commit hash, files changed summary, notes]

### Key Patterns & Context
[relevant patterns from plan, reference files to read]

### Acceptance Criteria
[specific criteria]

## Implementation Instructions

1. Read existing files BEFORE modifying them
2. Follow ALL conventions in CLAUDE.md
3. After implementation, run tests using the target repo's own test commands — discover them from CLAUDE.md, package.json scripts, Makefile, tox/pytest config, or CI config. Scope to the tests relevant to this phase.
4. Run lint/format checks using the target repo's own lint commands (same sources: CLAUDE.md, package.json scripts, Makefile, pre-commit config)
5. If tests or lint fail, fix the issues before committing
6. Stage ONLY the files you created or modified:
   git add [specific file paths]
7. Commit using HEREDOC format:
   git commit -m "$(cat <<'EOF'
   <type>([TICKET-ID]): <description>
   EOF
   )"
   Do NOT include Co-Authored-By lines.
8. After committing, run:
   git log --oneline -1
   git diff HEAD~1 --stat
   Report: commit hash, files changed, test pass/fail counts, any issues.
9. If you cannot fully complete the phase, say so explicitly in your final report: state exactly what was completed, what remains, and why you stopped.

Do NOT:
- Modify files outside your phase scope
- Skip running tests
- Leave uncommitted changes
- Use git add -A or git add . (stage specific files only)
- Add Co-Authored-By or author attribution to commits
```

### 5c. Spawn the Agent

Use the **Agent** tool:
- `subagent_type`: `"general-purpose"`
- `model`: `"sonnet"`

### 5d. Verify Agent Results

After the agent returns:

1. **Verify the commit independently** (don't rely solely on agent self-report):
```bash
git log --oneline -1
git diff HEAD~1 --stat
```

2. **If agent committed successfully:**
   - Update `.claude-local/IMPLEMENT_STATE.md` with: status=completed, commit hash, files changed, notes

3. **If agent failed to commit (escalate to Opus):**
   - Run `git status` and `git diff --stat` to assess partial work
   - If work is partially done with passing tests: stage and commit the partial work, note the gap
   - If tests failed: report to user, offer to spawn a fix-up agent (`model: "opus"`) — include the Sonnet agent's error output and failing test names in the prompt so Opus has full context
   - If the agent reported incomplete work (its final report says the phase wasn't finished): report progress, spawn a continuation agent (`model: "opus"`) for remaining work in this phase — include a summary of what was completed and what remains

4. **If the agent reported issues:**
   - Minor (warnings, style nits): log in state file, continue to next phase
   - Blocking (test failures, missing dependencies): stop and report to user

### 5e. Inter-Phase Progress Report

Between phases, output a brief status:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Phase [N]/[total]: [title]
   Commit: [short hash] [commit message]
   Files:  [count] changed ([insertions]+, [deletions]-)
   Tests:  [results summary]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Step 6: Final Verification

After all phases complete:

1. **Run the full test suite** for affected areas, using the target repo's own test commands (discover them from CLAUDE.md, package.json scripts, Makefile, or CI config).

2. **Run the full lint checks**, again using the repo's own lint commands (CLAUDE.md, package.json scripts, Makefile, pre-commit config).

3. **Review commit chain:**
```bash
git log --oneline $(git merge-base HEAD main)..HEAD
```

## Step 7: Completion Report

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🏁 IMPLEMENTATION COMPLETE — [TICKET-ID]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Phases completed: [N]/[N]
Commits:
  [hash1] [message1]
  [hash2] [message2]
  ...
Total files changed: [count]
Test results: [summary]

Next steps:
  1. Review: git diff $(git merge-base HEAD main)..HEAD
  2. Manual testing (if needed)
  3. /complete [ticket-id]  — update CHANGELOG/README
  4. /pre-merge            — generate MR description
  5. Push and create PR
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Update `.claude-local/IMPLEMENT_STATE.md` with final status.

## Step 8: Clean Up Plan File

Delete the plan file that was used for this implementation — its value is consumed, and the decisions are captured in git history, PR descriptions, and `/handoff`.

```bash
rm ~/.claude/plans/{plan-file-name}.md
```

Log it in the completion report:
```
Plan file cleaned up: ~/.claude/plans/{name}.md
```

**Do NOT delete the plan if any phase failed or was skipped.** Only clean up on full successful completion.

## Error Recovery

| Situation | Action |
|-----------|--------|
| Agent reports incomplete work | Spawn a continuation agent, or run `/implement resume` — picks up from last incomplete phase |
| Test failures after commit | Spawn fix-up agent targeting the failing tests |
| User interruption | State preserved in IMPLEMENT_STATE.md — resume anytime |
| Dirty working tree on resume | Show `git status`, ask user to resolve before continuing |
| Plan unclear or ambiguous | Ask user to clarify before spawning agents |

## Rules

1. **Sonnet-first, Opus on escalation** — use Sonnet for implementation agents; escalate to Opus for fix-up or continuation agents when Sonnet fails
2. **Sequential execution only** — never run phases in parallel (they share the working tree)
3. **Verify every commit** — run `git log` and `git diff` after each agent, don't trust self-reports alone
4. **Stop on blocking failures** — never silently continue past broken tests
5. **Keep orchestrator lean** — agents read files and do implementation; the orchestrator only tracks state and verifies
6. **Respect project hooks** — agents will trigger the same pre-commit hooks; don't instruct them to bypass
7. **No Co-Authored-By lines** — per project conventions
