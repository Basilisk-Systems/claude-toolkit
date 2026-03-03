---
description: Research codebase and write an implementation plan for a ticket
argument-hint: <ticket-id> (e.g., CAR-11)
allowed-tools: Read, Bash, Glob, Grep, Agent, AskUserQuestion, Skill, WebSearch, WebFetch
---

# Blueprint — Implementation Planning

Research the codebase and produce a detailed implementation plan without writing any code.

**CRITICAL:** Do NOT use `EnterPlanMode` or `ExitPlanMode`. This command replaces plan mode entirely. Do NOT create or modify any project files — planning only.

## Step 1: Identify the Ticket

**If `$ARGUMENTS` is provided:** Use it as the ticket ID (e.g., `CAR-11`).

**Otherwise:** Ask the user which ticket or task to plan.

## Step 2: Gather Context

Read these files (skip any that don't exist):

1. `docs/TICKETS.md` — find the ticket spec, acceptance criteria, dependencies
2. `CLAUDE.md` — project conventions, patterns, structure
3. `docs/ARCHITECTURE.md` — component details
4. `docs/careerctl-claude-code-prompt.md` — full spec with models and patterns (if relevant)

Extract from the ticket:
- **Title** and description
- **Acceptance criteria** (every `[ ]` checkbox)
- **Dependencies** (which tickets must be done first — verify they are)
- **Files likely affected** (from AC references)

## Step 3: Explore the Codebase

Based on the ticket spec, explore relevant code:

- Read files that will be modified or extended
- Read related test files for patterns to follow
- Read adjacent modules for conventions (imports, error handling, patterns)
- Check for existing stubs, TODOs, or placeholders related to this ticket

Use Grep/Glob for targeted searches. Use Agent (Explore) for broader discovery only if needed.

**Stay focused:** Only explore what's relevant to this ticket. Don't map the entire codebase.

## Step 4: Make Design Decisions

For each non-trivial choice, document:
- **What** the decision is
- **Why** you chose it (alternatives considered)
- **Impact** on other components

Common decisions to address:
- File organization (new files vs extending existing)
- Error handling approach
- Test strategy (what to test, what to mock)
- Patterns to follow from existing code

## Step 5: Write the Plan

Generate a unique plan name:
```bash
cat /dev/urandom | tr -dc 'a-z' | fold -w 4 | head -3 | paste -sd '-'
```

Write the plan to `~/.claude/plans/{name}.md` with this structure:

```markdown
# [TICKET-ID]: [Title]

## Context
[2-3 sentences: what this ticket does and why]

## Dependencies
[List completed prerequisite tickets with commit/PR references]

## Files to Create/Modify

| File | Action | Description |
|------|--------|-------------|
| path/to/file.py | Create/Modify | What changes |

## Design Decisions

| Decision | Rationale | Alternatives Considered |
|----------|-----------|------------------------|
| ... | ... | ... |

## Implementation

### Phase 1: [Title]
[Detailed description of what to build]
[Code snippets for non-obvious patterns]
[Reference files to read first]

### Phase 2: [Title]
[...]

## Test Plan

| Test File | Tests | What's Covered |
|-----------|-------|----------------|
| tests/unit/test_xxx.py | ~N tests | [areas] |

## Acceptance Criteria Mapping

| AC | Implementation | Verified By |
|----|---------------|-------------|
| [criterion from ticket] | [how it's met] | [which test] |
```

### Phase Guidelines

- **1 phase** for tightly-coupled changes (< 8 files, single concern)
- **2-3 phases** for multi-concern tickets (e.g., infrastructure + handlers + tests)
- Each phase should produce a single commit with passing tests
- Phases execute sequentially — later phases can depend on earlier ones

## Step 6: Estimate Context

Run `/estimate-context` via the Skill tool to project implementation cost.

## Step 7: Present for Approval

Show the user:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📐 BLUEPRINT — [TICKET-ID]: [Title]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Plan saved to: ~/.claude/plans/[name].md

Phases: [N]
Files to create: [N]
Files to modify: [N]
Tests: ~[N] new tests

[Context estimate summary from Step 6]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Then ask the user with AskUserQuestion:

- **"Approve — ready to implement"** — Description: "Run /clear-context then /implement to begin"
- **"Run /handoff first"** — Description: "Save session handoff before clearing context"
- **"Revise the plan"** — Description: "Tell me what to change"

### Based on response:

- **Approve:** Say "Blueprint approved. Next steps:" and show:
  ```
  1. /clear-context
  2. /implement
  ```
  Do NOT start implementing. Do NOT call ExitPlanMode. Just stop.

- **Handoff:** Run `/handoff` via Skill tool, then show the same next steps.

- **Revise:** Ask what needs to change, update the plan file, re-present.

## Rules

1. **No code changes** — This command only reads and plans. Never Edit/Write project files.
2. **No EnterPlanMode/ExitPlanMode** — This replaces plan mode entirely.
3. **No implementation** — After approval, the user runs `/implement` separately.
4. **One plan file** — Write a single comprehensive plan (not separate orchestration + detail files).
5. **Respect existing patterns** — Base design decisions on what's already in the codebase, not hypothetical best practices.
6. **Map every AC** — Every acceptance criterion from the ticket must appear in the plan.
