---
description: Research the codebase, write a design spec in the SPEC/ house style, and sync the decisions back to the ticket (GitHub issue or GitLab work item)
argument-hint: <ticket-ref> <freeform intent> [--slug NAME] [--repo owner/repo] [--platform github|gitlab] [--out DIR] [--no-sync] [--yes]
allowed-tools: Read, Write, Bash, Glob, Grep, Agent, AskUserQuestion, Skill
---

# Design Spec — Architecture-Altitude Specification

Research the codebase and produce a **design specification** — the *what* and *why*
of a feature, its architecture forks, API shape, and test plan — written in the
repository's `SPEC/` house style, then **sync the design decisions back to the
ticket** so the ticket and the spec never drift apart.

This is the design-altitude sibling to `/blueprint`:

| | `/design-spec` | `/blueprint` |
|---|---|---|
| Altitude | Design / architecture — *what & why*, the forks and their rationale | Implementation — *how*, phase-by-phase build steps |
| Output | `SPEC/<SLUG>.md`, committed with the repo | `~/.claude/plans/<name>.md`, private |
| Audience | The team — reviewed and signed off before code | You + `/implement` |
| Ticket link | **Syncs decisions to the GitHub issue / GitLab work item** | None |

Run `/design-spec` first (align on the design, get sign-off), then `/blueprint`
(plan the build), then `/implement`.

**CRITICAL:** Do NOT write production code, edit source files, or `git add`/commit.
This command only researches, writes the spec document, and posts the ticket note.
Leave staging the spec to the user (specs are often git-added at MR/PR time).

If the `spec-writing` skill is installed, load it via the Skill tool before Step 6 —
it carries the house style in full. The template below is the fallback.

Input: `$ARGUMENTS`

## Step 1: Parse Arguments

Split `$ARGUMENTS` into:

- **Ticket ref** — the first token **only if it looks like one**:
  - a bare number or `#number` (e.g. `598`, `#598`)
  - an issue / work-item URL (e.g. `https://github.com/acme/widgets/issues/598` or
    `https://gitlab.com/acme/widgets/-/work_items/598`). From a URL, extract the
    number **and** the project path (everything between the host and `/issues/` or
    `/-/`), and note the host — it decides the platform in Step 2.
  - a local ticket ID (e.g. `PROJ-11`) — looked up in `docs/TICKETS.md` (Step 3);
    no remote sync in that case.

  If the first token doesn't look like any of these, there is no ticket — treat the
  whole string as intent and skip Steps 2, 3, and 7 (the spec is still produced,
  just unlinked). Warn the user that no ticket will be synced.
- **Intent** — the remaining free text after stripping recognized flags. Raw *source
  material*: a problem statement, a discussion thread, a brain-dump, or a one-liner.
  Required — if empty, stop and ask the user what to spec.
- **Flags** (may appear anywhere):
  - `--slug <NAME>` — override the spec filename slug (see Step 6). Optional.
  - `--repo <owner/repo>` — target project. Default: derived (Step 2).
  - `--platform <github|gitlab>` — force the platform. Default: detected (Step 2).
  - `--out <DIR>` — output directory for the spec. Default: `SPEC/`.
  - `--no-sync` — write the spec but skip the ticket sync entirely.
  - `--yes` — skip confirmation gates (non-interactive).

## Step 2: Resolve Platform and Project

*(Skip if there is no remote ticket or `--no-sync` was passed.)*

**Project path** precedence: `--repo` flag → path parsed from a URL ticket ref → the
current repo's `origin` remote:

```bash
git remote get-url origin 2>/dev/null \
  | sed -E 's#^(https?://[^/]+/|git@[^:]+:)##; s#\.git$##'
```

**Platform** precedence: `--platform` flag → host from a URL ticket ref → host of
the `origin` remote (`github.com` → github; a host containing `gitlab` → gitlab).
If the platform can't be determined, ask the user.

Then verify the matching CLI is ready:

```bash
# github
command -v gh >/dev/null || { echo "gh not found — https://cli.github.com"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "gh not authenticated — run: gh auth login"; exit 1; }

# gitlab
command -v glab >/dev/null || { echo "glab not found — install with: brew install glab"; exit 1; }
glab auth status >/dev/null 2>&1 || { echo "glab not authenticated — run: glab auth login"; exit 1; }
```

If no project path can be resolved, tell the user to pass `--repo` (or `--no-sync`
to skip the sync).

## Step 3: Read the Ticket

*(Skip if there is no ticket or `--no-sync` was passed — except the local-ID case,
which reads but never syncs.)*

Fetch the ticket's title, description, and recent discussion — this is primary
source material. A ticket's body and thread usually carry the design discussion
that should shape the spec (constraints, prior decisions, who-said-what).

**GitHub:**

```bash
gh issue view <NUMBER> --repo <OWNER/REPO> \
  --json number,title,body,url,comments \
  --jq '{number, title, body, url, comments: [.comments[] | {author: .author.login, body}]}'
```

**GitLab** (work items — covers issues, tasks, and epics):

```bash
glab api graphql -f query='
query($path: ID!, $iid: String!) {
  project(fullPath: $path) {
    workItems(iids: [$iid]) {
      nodes {
        id iid title webUrl
        workItemType { name }
        widgets {
          ... on WorkItemWidgetDescription { description }
          ... on WorkItemWidgetHierarchy { parent { iid title webUrl } }
          ... on WorkItemWidgetNotes {
            discussions(first: 50) { nodes { notes { nodes { body author { username } } } } }
          }
        }
      }
    }
  }
}' -f path="<PROJECT_PATH>" -f iid="<TICKET_IID>"
```

Extract `nodes[0].id` (the `gid://gitlab/WorkItem/...` global ID) for Step 7. If
the result is empty (either platform), stop: the ticket doesn't exist or isn't
visible with this token.

**Local ticket ID** (e.g. `PROJ-11`): read `docs/TICKETS.md` and find the matching
`## <ID>:` heading — title, description, acceptance criteria. No remote sync
(Step 7 is skipped); the spec's title block cites the ticket ID instead of a URL.

Mine the description and discussion for: the problem statement, hard constraints,
prior decisions, and any explicit breakdown of scope into siblings. Do **not** copy
names of individuals into the spec — attribute ideas to the discussion, not to
people.

## Step 4: Research the Codebase

The strength of a spec is that it composes primitives that **already exist** rather
than inventing them. Research before deciding anything.

- **Find the primitives to compose.** Locate the exact existing services, types,
  methods, and schema the feature will build on. Read them — signatures, return
  types, side effects, partial-failure behavior.
- **Find precedents to mirror.** Search for an existing feature that solved a
  similar shape (e.g. a combined operation, a bulk-summary return type, a
  searchable field). Cite it; the spec should follow house patterns, not
  hypothetical best practice.
- **Find the touch points.** Identify the schema file, resolver/handler, service,
  and persistence layer the change lands in. Record file paths for the implementor.
- **Find the constraints.** Check `CLAUDE.md` hard rules, backward-compatibility
  rules, migration conventions — anything that forecloses an option. These often
  *are* the rationale for a design fork.

Use Grep/Glob for targeted lookups. Use `Agent` (Explore) for broad discovery
across many files. Stay focused on what this feature touches — do not map the
whole codebase.

Capture, for the spec's Background section, the exact primitives with file
references.

## Step 5: Make the Design Decisions

For every non-trivial fork, decide and justify. A decision without a rationale and
a rejected alternative is not yet a decision.

- **What** the choice is.
- **Why** — the deciding constraint or precedent (cite Step 4 findings).
- **Alternatives considered** and why they lost.

Then separate what you *cannot* decide yet into explicit **Open Questions** — each
with the concrete action that would close it (e.g. "audit `SearchFilter` fields").
A good spec is honest about its unknowns.

For genuinely load-bearing forks where the user's intent is ambiguous, use
`AskUserQuestion` to confirm before committing them to the document.

## Step 6: Write the Spec

Derive the **slug**: if `--slug` was given, use it; else synthesize a concise title
from the intent and render it in `SCREAMING-KEBAB-CASE` (e.g. "cancel & annotate /
replay API" → `CANCEL-AND-ANNOTATE-REPLAY-API`). Strip punctuation, join words with
hyphens, uppercase.

Resolve author and date (never assume the date):

```bash
git config user.name            # → author
date +%Y-%m-%d                  # → today's date
```

Write the spec to `<OUT_DIR>/<SLUG>.md` (default `SPEC/<SLUG>.md`). Match the house
style — a title block, then numbered sections. Include only the sections that apply
(not every spec has an "API"; some have a "Design" or "Data Model" instead), but
always cover: scope in/out, motivation, background with real file references, the
design with a decision table, semantics/edge cases, non-functional requirements,
open questions, and a test plan.

```markdown
# <Feature Title> — Specification

> Ticket: [<project>#<number>](<web-url>)
> — child of [#<parent-number>](<parent-url>) "<parent-title>"   ← omit if no parent
> Status: **Draft** · Author: <author> · <YYYY-MM-DD>

## 1. Overview

<2–4 sentences: what this is and the shape of the solution.>

### 1.1 Scope

**In scope (this ticket, #<number>):**

- <bulleted deliverables>

**Out of scope (siblings / follow-ups):**

- <what this explicitly does not cover, with pointers to sibling work>

### 1.2 Motivation

<Why now — the concrete pain, drawn from the ticket discussion and the research.>

## 2. Use Cases

<Working backward from operator/user workflows. Number them; tie each to a design element.>

## 3. Background: Relevant Existing Behavior

<The exact primitives this composes, WITH file references. This is what makes the spec
implementation-ready. One bullet per primitive: what it does, its return/failure shape,
and where it lives.>

## 4. Design

<The API / interface / data model. Show the concrete shape (schema, signatures, types).>

### 4.x Why this shape

| Decision | Choice | Rationale |
|---|---|---|
| <fork> | **<choice>** | <deciding constraint or precedent; why alternatives lost> |

## 5. Semantics & Edge Cases

<The precise algorithm, ordering guarantees, idempotency, error handling, permissions.>

## 6. Non-Functional Requirements

<Reliability, scale, performance, security — whatever is first-class for this feature.>

## 7. Scope & Siblings

<How this decomposes; what the sibling tickets are and where the boundary sits.>

## 8. Open Questions

<Numbered. Each with the action that would resolve it.>

## 9. Test Plan

<Unit / integration / compatibility coverage, mapped to the semantics above.>
```

Keep prose tight and specific. Prefer citing an exact type or file over
hand-waving.

## Step 7: Sync the Decisions to the Ticket

*(Skip if there is no remote ticket or `--no-sync` was passed.)*

Post a **comment** on the ticket — non-destructive, never overwrites the ticket
body. The comment is a compact digest of the design, not the whole spec: the
decisions table, scope in/out, open questions, and a link to the in-repo spec path
so a reader can find the full document.

**Confirmation gate.** Unless `--yes` was passed, echo the comment body and get the
user's OK first — posting to a ticket is outward-facing:

```
About to post a design-summary comment to #<number> — <ticket-title>:
──────────────────────────────────────────
<comment body preview>
──────────────────────────────────────────
```

Build the comment body (Markdown). Keep it to the essentials:

```markdown
## 🧭 Design summary — <Feature Title>

Full spec: `SPEC/<SLUG>.md` (on branch `<current-branch>`)

**Decisions**

| Decision | Choice | Rationale |
|---|---|---|
| … | **…** | … |

**Scope** — In: … · Out (siblings): …

**Open questions**
1. …
```

Post it. The body contains newlines and quotes — never string-interpolate it into
the command; write it to a temp file / pass it as a variable.

**GitHub:**

```bash
gh issue comment <NUMBER> --repo <OWNER/REPO> --body-file <TMPFILE>
```

**GitLab:**

```bash
glab api graphql -f query='
mutation($noteable: NoteableID!, $body: String!) {
  createNote(input: { noteableId: $noteable, body: $body }) {
    note { id url }
    errors
  }
}' \
  -f noteable="<WORK_ITEM_GID>" \
  -f body="<NOTE_BODY>"
```

Check the result — on GitLab a non-empty `errors` array means the note was **not**
posted; on GitHub a non-zero exit means the same. Surface the message and stop.

**Optional description refresh.** After the comment posts, ask (do not default to
yes) whether to also refresh the ticket *description* with the design summary. Only
if the user agrees, and warn that it replaces the current body:

```bash
# github
gh issue edit <NUMBER> --repo <OWNER/REPO> --body-file <TMPFILE>

# gitlab
glab api graphql -f query='
mutation($id: WorkItemID!, $desc: String!) {
  workItemUpdate(input: { id: $id, descriptionWidget: { description: $desc } }) {
    workItem { iid }
    errors
  }
}' \
  -f id="<WORK_ITEM_GID>" \
  -f desc="<SUMMARY_BODY>"
```

## Step 8: Report

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📐 DESIGN SPEC — <Feature Title>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Spec written: SPEC/<SLUG>.md
Ticket:       #<number> — <title>
              <web-url>
Comment:      <comment-url>          ← omit if --no-sync / no ticket
Open questions: <N>

Next:
  • Review the spec, circulate for sign-off
  • /blueprint once the design is agreed
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Remind the user the spec is **not** staged — they decide when to `git add` it
(specs are frequently added at MR/PR time).

## Notes

- **Spec vs. blueprint:** the spec is the durable, team-facing statement of *what
  we're building and why*. The blueprint is the private, throwaway build plan.
  Don't collapse them — a spec full of phase-by-phase code steps has lost its
  altitude.
- **Compose, don't invent:** the best specs read as "assemble these existing
  pieces." If Step 4 didn't find the primitives, the design isn't ready — research
  more.
- **Honest open questions** beat false confidence. List what you don't know with
  the action to resolve it.
- **No individual names in the spec or the ticket comment** — attribute ideas to
  "the discussion," not to people.
- **Living document:** re-run `/design-spec` (same `--slug`) to regenerate as the
  design evolves; the comment posts as a new one each time, preserving the decision
  history on the ticket.
