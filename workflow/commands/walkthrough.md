---
description: Explain a branch's diff to the developer, concept by concept, tied back to the plan — an orientation, not a review
argument-hint: [base-branch (default: main)] [ticket-id or plan file]
allowed-tools: Bash, Read, Grep, Glob, AskUserQuestion
---

Walk the developer through the changes on this branch: $ARGUMENTS

## Purpose

Give the developer an understanding of a diff they did not type by hand — because
`/implement` sub-agents wrote it, because a teammate did, or because it has been a
while. The output is an *explanation*: what each part does, why it exists, where it
lives, and how it is pinned by tests, tied back to the ticket, plan and recorded
decisions.

**This is not a code review.** `/code-review` judges; `/walkthrough` orients. The
developer leaves knowing the shape of the change well enough to review it, approve
it, or ask sharp questions about it. Nothing is changed on disk.

## Ground Rules (read before every walkthrough)

1. **Explain, never evaluate.** No verdicts, no "should", no "consider", no fix
   suggestions, no quality adjectives ("clean", "hacky", "fragile"). Describe what
   the code does and why the plan called for it.
2. **One exception, used sparingly.** If you notice something that looks like a
   defect while explaining, record it in one line under *Flagged for /code-review*
   at the end — file, line, what you saw — and keep explaining. Do not propose a
   fix, do not dwell, do not editorialise. Never more than a handful of lines.
3. **If the developer asks "is this right?"**, answer with facts (what it does, what
   test pins it, what the plan said) and point at `/code-review` for the judgment.
4. **Organise by concept, not by file.** A theme is a thing the change accomplishes
   ("the worker bypass policy", "the bundle build macro"), and may span many files.
5. **Cite the intent for every theme.** Each theme names the acceptance criterion,
   plan phase, decision-log row or handoff decision it implements. If no source
   exists, say so plainly: "no plan entry covers this; it appears to be incidental".
6. **Plain language.** Expand acronyms on first use. Explain terms the project's
   docs take for granted when they first appear.
7. **Read-only.** Never modify, stage or commit anything. Never run the project's
   forbidden commands (check the project `CLAUDE.md` hard rules); if a point can
   only be shown that way, say so.

## Step 0: Gather

Resolve the arguments. The first token that names a git ref is the base branch
(default `main`); anything else is a ticket id or plan path.

```bash
BASE_BRANCH="<resolved>"
git branch --show-current
git log $BASE_BRANCH..HEAD --oneline
git log $BASE_BRANCH..HEAD --format="### %s%n%n%b"
git diff $BASE_BRANCH --stat
git diff $BASE_BRANCH --name-status
git diff $BASE_BRANCH          # read in parts for a large diff; see Scale below
```

Then locate the intent sources, in this order, and read whichever exist:

| Source | Where to look | What it gives you |
|--------|---------------|-------------------|
| Ticket | id from `$ARGUMENTS` or the branch name (`TICKET-123` pattern); section in `docs/*TICKET*` | acceptance criteria, testing table, out-of-scope list |
| Plan | `$ARGUMENTS` path, else the newest `~/.claude/plans/*.md` naming the ticket | phases, intended file list, design decisions |
| Implement state | `.claude-local/IMPLEMENT_STATE.md` | per-phase notes and **departures from the plan** |
| Handoff | `.claude-local/HANDOFF.md` → *Decisions Made* table | decisions taken mid-flight and their rationale |
| Changelog | `CHANGELOG.md` unreleased section | the change as the project describes it to users |

If none of these exist, say so and build the walkthrough from the commits alone;
cite commit messages as the intent.

### Scale

- Under ~1,500 changed lines: read the whole diff.
- Larger: read `--stat` and `--name-status`, group files into themes first, then
  read each theme's diff (`git diff $BASE_BRANCH -- <paths>`) as you reach it.
- Generated or vendored files (lockfiles, `openapi.json`, codegen output, snapshots,
  gold fixtures): name them, say what regenerated them, do not read them line by
  line.

## Step 1: Build the Concept Map

Group every hunk into **4–8 themes**. Each file belongs to exactly one theme; a file
that serves two themes goes with the one that explains it best and is mentioned
from the other. Order themes **from foundations to consumers**:

1. data model / schema / contracts
2. domain logic
3. infrastructure and wiring
4. tooling and pipeline
5. tests (where they are not better told alongside their theme)
6. docs, changelog, housekeeping (always last, always brief)

Present the map **before explaining anything** and let the developer steer:

```markdown
## Walkthrough: <branch> → <base> (<N> commits, <M> files, +A/−D)

Ticket: <id — title>   Plan: <path or "none">   Departures recorded: <n>

| # | Theme | Files | Implements |
|---|-------|-------|------------|
| 1 | <concept> | 3 | AC 2, plan phase 1, decision D1 |
| 2 | ... | ... | ... |
| 6 | Docs and housekeeping | 5 | — |
```

AskUserQuestion: *Walk through all themes in this order* / *Start from a specific
theme* / *Skip the housekeeping theme* / *Only the themes with departures*. Honour
the answer.

## Step 2: Explain, Theme by Theme

For each theme, in this fixed shape:

```markdown
### Theme N: <concept>

**What it does.** Two to four sentences describing the behaviour the change
introduces or alters, in plain language.

**Why it is here.** The acceptance criterion, plan phase, or decision it serves,
quoted or paraphrased closely, with its source named.

**Where it lives.**
- `path/file.py:12-40` — one sentence on what this hunk contributes
- `path/other.py:88` — ...
(2–5 hunks that carry the idea. Quote at most a few lines of code when the words
alone would be vaguer than the code.)

**Departures from the plan.** What `IMPLEMENT_STATE.md` or the handoff records
as different from the plan, and the reason given there. Write "None recorded" when
there is none; never infer a departure the records do not state.

**How it is pinned.** The tests that assert this behaviour, named by file and test
function. If none, say "No test names this behaviour" — as a fact, not a finding.
```

Deliver themes in **batches of two or three**, then pause with AskUserQuestion:
*Continue* / *Go deeper on <theme>* / *I have a question* / *Stop here, give me the
summary*. On "go deeper", read the remaining hunks of that theme and explain them
at the same altitude; do not drift into evaluation.

Keep each theme under about 250 words unless the developer asks for depth.

## Step 3: Close

End with three short lists and a hand-off. Every list may be "None".

```markdown
## Summary

### Decisions to confirm
Judgment calls the author (human or agent) made that no test can settle and the
plan did not pre-decide — a naming choice, a pinned version, a reworded comment,
a threshold. One line each: what was chosen, where, and the stated reason if any.
These are for the developer to agree with or not; take no position.

### Flagged for /code-review
Anything that looked like a defect while explaining (Ground Rule 2). One line
each, file:line, what was seen. No fixes.

### Not in this diff
Items the ticket's out-of-scope list or the plan defers, so the developer does not
go looking for them.

### Next
- `/code-review <base>` for the judgment
- `/pre-merge <base>` for the pull request text
- `/smoke-test <ticket>` if the ticket has smoke criteria
```

## Examples

### Example 1: agent-written branch with a plan and state file
```
/walkthrough dev ODIN-117
→ 5 commits, 64 files; ticket in docs/TICKETS.md; plan in ~/.claude/plans/odin-117-*.md;
  IMPLEMENT_STATE.md records 2 departures
→ Concept map: 7 themes (schema and roles → tenancy helpers → runner → infra stack →
  build macro → CI wiring → docs). User: "all, in order"
→ Themes 1–3, pause; user asks what SET LOCAL means → explained, continue
→ Themes 4–7, summary: 3 decisions to confirm, 0 flagged, 4 not-in-diff items
```

### Example 2: no plan, teammate's branch
```
/walkthrough main
→ 12 commits, no ticket in branch name, no plan or state file
→ Intent cited from commit messages; 4 themes; "Departures" sections read
  "No plan to compare against"
→ One line under Flagged for /code-review; user runs /code-review next
```

### Example 3: developer asks for a verdict mid-walkthrough
```
User: "Is that policy actually safe?"
→ "It grants the worker role unconditional read and write on the table; the
   migrations test matrix exercises it as odin_worker in test_migrations_rls_helper.py.
   Whether that is the right grant is a review question — /code-review dev will
   take a position on it."
```
