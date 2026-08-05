---
description: Generate and run an interactive smoke test for a ticket before completing it
argument-hint: [ticket-id | pasted acceptance/testing criteria | description of what to test]
allowed-tools: Read, Write, Bash, Glob, Grep, AskUserQuestion
---

Run a smoke test for: $ARGUMENTS

## Purpose

Turn a ticket's acceptance / E2E / smoke-testing criteria into detailed, step-by-step
test instructions with expected output, walk the user through them interactively, and
record a verdict that `/complete` can rely on before checking the ticket off.

This command does NOT modify the ticket file. It produces a verdict and a results
record; `/complete` owns the checkbox updates.

## Step 0: Validate Input (REQUIRED)

This command needs SOME input. Accepted forms, in order of preference:

1. **Ticket ID** — `PREFIX-NUMBER` pattern (e.g., `DES-031`, `TICKET-98`) resolvable in a tickets file
2. **Pasted criteria** — acceptance criteria or testing criteria provided directly in the argument
3. **Description** — prose describing the feature/change to test

If `$ARGUMENTS` is empty, ask the user (AskUserQuestion) what to smoke test — offer
recently changed tickets as options if a tickets file exists — and STOP until they
answer. Never invent a test target.

Also get the current date for the results record:
```bash
date +%Y-%m-%d
```

## Step 1: Resolve Test Criteria

### If the input is a ticket ID

1. Locate the ticket tracking file:
   ```bash
   ls docs/*TICKET* docs/*ticket* 2>/dev/null
   ```
2. Extract the ticket's full section: title, description, acceptance criteria,
   unit testing criteria, and any **E2E / Integration Testing** (or smoke testing)
   section. Note any status markers (`BLOCKED`, `CUT`, `DEFERRED`, `MERGED`, `CLOSED`).
3. If the ticket is marked CUT, CLOSED, or MERGED: stop and tell the user — there is
   nothing to smoke test (for MERGED, point at the surviving ticket).
4. **Criteria source priority:** use the E2E/smoke section if present; fall back to
   acceptance criteria; if neither is testable, infer criteria from the ticket title,
   description, and the code it touches.

### If the input is pasted criteria

Use them as-is. Normalize into a numbered list if they arrived as prose.

### If the input is a description

Infer smoke test criteria by reading the relevant code (routes, components, configs
the description implies). **Show the inferred criteria list to the user and get
confirmation (AskUserQuestion) before building the test plan** — inferred criteria
must never be silently assumed.

## Step 2: Classify Each Criterion

Classify every criterion before writing the plan:

| Class | Meaning | Handling |
|-------|---------|----------|
| **AUTOMATED** | Already verifiable without a human: an existing test asserts it, CI/deploy history proves it, or a local command can check it right now | Verify directly and cite the evidence (test file + test name, CI run, command output) |
| **MANUAL** | Needs a human with a browser, device, or external tool (viewport checks, click flows, Lighthouse, validator sites) | Include in the interactive walkthrough |
| **BLOCKED** | Depends on something unavailable: DNS not cut over, external service not provisioned, client action pending, prod-only behavior | Do NOT test; annotate with the specific blocker |

Rules:
- **Blockers are a scoping smell, not a test failure.** Testing criteria should not
  depend on unavailable externals, but tickets scoped earlier may contain them.
  Flag each one with its concrete blocker and recommend re-homing it to a
  launch/QA ticket — never count it against the verdict.
- **Respect project hard rules.** If verification requires a command the project
  forbids you from running (e.g., cloud CLI), provide the exact command for the
  user to copy-paste and treat the criterion as MANUAL.
- When an AUTOMATED classification rests on an existing test, confirm the test
  actually exists and passes — name it; do not classify from memory.

## Step 3: Build the Smoke Test Plan

Present the full plan BEFORE executing anything.

**Automated section** — a table: criterion → evidence or verification command.

**Manual section** — numbered steps. Every step must have all three parts:

```markdown
### Step N: [Short name]
- **Setup:** [preconditions — dev server running (`npm run dev`), exact URL, viewport size, DevTools state, external tool]
- **Action:** [ONE exact action: "Click the 'Get Started' button in the header"]
- **Expected:** [concrete, observable result: "URL is `/contact`; page heading reads 'Contact Us'"]
```

Specificity requirements — the user should never have to interpret:
- Exact URLs/routes, not "the page"
- Exact viewport widths in px (e.g., 375px, 768px, 1280px), not "mobile"
- Exact visible text, element names, or network responses, not "it works"
- Exact commands with expected exit codes/output for anything terminal-based

Order steps to minimize context switching: group by page/viewport/tool so the user
isn't bouncing between browser sizes.

## Step 4: Execute Interactively

1. **Automated first.** Run the verification commands/tests yourself, record each
   result. A failing automated check is a FAIL result for that criterion.
2. **Manual walkthrough.** Present steps in small batches (3–5 related steps).
   After each batch, collect results via AskUserQuestion per step or per batch:
   - **Pass** — matched expected output
   - **Fail** — capture what ACTUALLY happened (verbatim, in the notes)
   - **Blocked** — hit an unforeseen blocker; capture it
   - **Skip** — user chose not to run it; capture why
3. **On a Fail, keep going** through the remaining steps unless the failure makes
   them untestable — a complete failure picture beats an early exit.

## Step 5: Verdict and Record

### Verdict rules

- **PASS** — every AUTOMATED and MANUAL criterion passed. BLOCKED items do not
  prevent a PASS; they ride along as annotations.
- **FAIL** — one or more criteria failed.
- **INCOMPLETE** — no failures, but skipped steps leave essential behavior
  unverified. State exactly what remains untested.

### Record the results

If `.claude-local/` exists, append an entry to `.claude-local/SMOKE_TESTS.md`
(create the file with a `# Smoke Test Results` header if missing):

```markdown
## [TICKET-ID or short slug] — YYYY-MM-DD — [PASS|FAIL|INCOMPLETE]

| # | Criterion | Class | Result | Notes |
|---|-----------|-------|--------|-------|
| 1 | ... | AUTOMATED | Pass | covered by `header.test.tsx` "renders all six navigation links" |
| 2 | ... | MANUAL | Pass | |
| 3 | ... | BLOCKED | — | DNS not cut over; re-home to launch QA ticket |
```

If `.claude-local/` does not exist, output the same table in the summary only.

## Step 6: Hand-off

**On PASS:**
- Tell the user the ticket is ready for `/complete <ticket-id>`, which will check
  off the whole ticket.
- List any BLOCKED items explicitly so `/complete` annotates them instead of
  checking them, and recommend where to re-home them.

**On FAIL:**
- Do NOT suggest `/complete`. Summarize each failure: step, expected, actual.
- Recommend a path: fix now (if isolated) or capture as a follow-up ticket.

**On INCOMPLETE:**
- List exactly which steps were skipped and what a follow-up session must cover.

### Output Summary

```markdown
## Smoke Test: [TICKET-ID / description] — [VERDICT]

### Coverage
- Automated: X passed / Y total
- Manual: X passed / Y total
- Blocked (annotated, not failures): Z

### Failures
- [Step, expected vs. actual — or "None"]

### Blocked Items
- [Criterion — blocker — recommended re-home — or "None"]

### Results Recorded
- [.claude-local/SMOKE_TESTS.md updated / output-only]

### Next Step
- [/complete TICKET-ID | fix failures first | schedule follow-up]
```

## Examples

### Example 1: Ticket ID with an E2E section
```
/smoke-test DES-031
→ Found DES-031 in docs/TICKETS.md; 5 E2E criteria
→ Classified: 3 AUTOMATED (home.test.tsx hrefs + h1), 2 MANUAL (375px overflow, Lighthouse)
→ Ran vitest for the 3 automated; walked user through the 2 manual
→ All passed → PASS recorded → "Ready for /complete DES-031"
```

### Example 2: Description only
```
/smoke-test "new footer social links open in a new tab"
→ No ticket; read Footer component; inferred 3 criteria; user confirmed them
→ 1 AUTOMATED (footer.test.tsx), 2 MANUAL (click-through, rel=noopener check)
→ 1 manual step failed (missing rel="noopener") → FAIL → fix recommended before /complete
```

### Example 3: Blocked criteria from earlier scoping
```
/smoke-test DES-008
→ 2 E2E criteria; both require client DNS records → both BLOCKED
→ Nothing testable now → INCOMPLETE with blockers annotated
→ Recommended: re-home both to the launch QA ticket; /complete may annotate but not check them
```

### Example 4: No input
```
/smoke-test
→ "This command needs a target." AskUserQuestion with recent in-progress tickets → wait
```
