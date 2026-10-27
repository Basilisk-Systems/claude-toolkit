---
description: Archive a completed ticket from TICKETS.md to ARCHIVED_TICKETS.md
argument-hint: <ticket-id> (e.g., INFRA-4, ABC-123)
allowed-tools: Bash, Read, Edit, Write, Grep, AskUserQuestion
---

Archive the ticket: $ARGUMENTS

This is the last wrap-up step for a ticket, run after `/complete` has marked it COMPLETE
and before `/commit`. It moves the ticket's full spec out of the active backlog so the
record is kept but `TICKETS.md` stays lean. It edits files only; it never commits.

## Step 1: Validate Input

Check that `$ARGUMENTS` matches a ticket ID pattern (e.g., INFRA-4, ABC-123):

```bash
echo "$ARGUMENTS" | grep -qE '^[A-Z]+-[0-9]+$'
```

If no match, tell the user: "Please provide a ticket ID (e.g., INFRA-4)." Then stop.

## Step 2: Locate the Ticket in TICKETS.md

Projects nest ticket headings at different depths (`##`, `###` or `####`). Find the
heading and record its depth; the heading may carry a GitHub link like `([#4](url))`:

```bash
grep -nE "^#{2,4} $ARGUMENTS\b" docs/TICKETS.md
```

If not found, tell the user: "Ticket $ARGUMENTS not found in docs/TICKETS.md." Then stop.
If found more than once, stop and show the matches; do not guess.

## Step 3: Extract the GitHub Issue Number

Look in two places, heading first, then the ticket's status line
(a `**GitHub:** #108` line, which some projects use):

```bash
grep -E "^#{2,4} $ARGUMENTS\b" docs/TICKETS.md | grep -oP '\[#\K[0-9]+'
```

```bash
sed -n "${TICKET_START},${SECTION_END}p" docs/TICKETS.md | grep -oP '\*\*GitHub:\*\* #\K[0-9]+' | head -1
```

Store the number for Step 8. It may not exist (older tickets without GitHub links).

## Step 4: Confirm the Ticket is Complete

Read the ticket section (from its heading to the next `---` separator). It counts as
complete when the status line says `COMPLETE`/`COMPLETED`, or every checkbox in the
section is `[x]` (boxes annotated `BLOCKED` are allowed).

If it does NOT appear complete, ask the user:

> "Ticket $ARGUMENTS doesn't appear to be marked complete. Archive it anyway?"

Options:
- "Yes, archive it"
- "No, cancel"

If they say no, stop.

## Step 5: Extract the Ticket Section

The section spans from the heading line up to and including the `---` separator that
follows it:

```bash
TICKET_START=$(grep -nE "^#{2,4} $ARGUMENTS\b" docs/TICKETS.md | head -1 | cut -d: -f1)
SECTION_END=$(tail -n +$((TICKET_START + 1)) docs/TICKETS.md | grep -n "^---$" | head -1 | cut -d: -f1)
SECTION_END=$((TICKET_START + SECTION_END))
sed -n "${TICKET_START},${SECTION_END}p" docs/TICKETS.md
```

Check the extracted block: it must contain exactly one ticket heading. If a second
ticket heading appears before the `---`, the file has no separator after this ticket;
stop at the line before the next heading instead and leave that heading in place.

## Step 6: Append to ARCHIVED_TICKETS.md

If `docs/ARCHIVED_TICKETS.md` already exists, leave its header exactly as it is.

If it does not exist, create it. Take the project name from the repository
(`basename "$(git rev-parse --show-toplevel)"`, title-cased, or the name used in the
`TICKETS.md` H1 if that is clearer); never copy a header from another project:

```markdown
# <Project> — Archived Tickets

> Completed tickets moved from TICKETS.md to keep the active backlog lean.
> Use `/archive <ticket-id>` to move tickets here.

---

```

Then append the extracted section to the end of the file, with two changes only:
- Rewrite the ticket heading to `## ` depth (archived tickets are flat, one `##` each).
- Keep the trailing `---` separator so the next archive appends cleanly.

Everything else in the section is copied verbatim: status line, body, checkboxes,
"Fixed on" paragraphs, follow-ups. The archive is the record; do not summarise it.

## Step 7: Remove from TICKETS.md

Remove the ticket section from `docs/TICKETS.md`, heading through `---` inclusive,
without leaving a double blank line or two `---` in a row.

Then tidy the references that remain:

1. **Reference list.** If the file has a `## Completed Tickets (Reference)` section,
   add a one-liner under the best-matching category heading (or create one):
   `- **$ARGUMENTS**: <ticket title>`. Match the existing bullet format exactly.
2. **Status note.** If a note near the top of the file lists which tickets have been
   archived (e.g. "ABC-132, 139 and 147 as of 2026-10-06"), add this ticket
   and today's date (`date +%Y-%m-%d`).
3. **Dependency and ordering notes.** Where the ticket appears in a dependency tree,
   implementation order, "Depends On" of another ticket, or a milestone count, update
   the text so it no longer points at a section that is gone (e.g. "ABC-133 (archived)"
   or simply remove it). Do not rewrite unrelated prose.

## Step 8: GitHub Issue

If no issue number was found in Step 3, skip this step and say so in the report.

Otherwise check its state before touching it:

```bash
gh issue view <NUMBER> --json state,closedAt --jq '.state + " " + (.closedAt // "")'
```

- **CLOSED:** do nothing; report "already closed <date>".
- **OPEN** and an open PR from the current branch references `#<NUMBER>`
  (`gh pr list --head "$(git branch --show-current)" --json body,number`): leave it; the
  merge will close it. Report "left open; PR #<n> closes it on merge".
- **OPEN** with no such PR: ask the user before closing:
  > "Issue #<NUMBER> is still open and no PR references it. Close it now?"
  On yes: `gh issue close <NUMBER> --reason completed`.

## Step 9: Report

Display:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Archived: $ARGUMENTS — <ticket title>
   From: docs/TICKETS.md (<depth> heading, lines <start>-<end>)
   To:   docs/ARCHIVED_TICKETS.md
   Reference list: <added under "<category>" / section not present>
   GitHub: <#N already closed <date> | #N left open, PR #n closes it | #N closed now | no linked issue>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Include the counts: "TICKETS.md now has X active tickets. ARCHIVED_TICKETS.md has Y
archived tickets." Count headings with `grep -cE "^#{2,4} [A-Z]+-[0-9]+"` in each file.

Then remind: "Changes are unstaged. Run `/commit` to commit them with the ticket's
other wrap-up changes (`docs(<ticket-id>): Archive <ticket-id>` if committed alone)."
