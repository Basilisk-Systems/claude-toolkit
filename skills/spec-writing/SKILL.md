---
name: spec-writing
description: House style for design specifications - architecture-altitude documents in SPEC/ that state what is being built and why, with decision tables, file-referenced background, and honest open questions. TRIGGER when writing, editing, or reviewing a design spec, any file under a SPEC/ directory, or when /design-spec runs. Do NOT trigger for implementation plans or blueprints (phase-by-phase build steps), README/CHANGELOG edits, or code comments.
allowed-tools: Read, Glob, Grep
---

# Spec Writing Skill

A design spec is the durable, team-facing statement of **what we're building and
why**. It is reviewed and signed off before code is written, lives in the repo
under `SPEC/`, and outlives the branch that implements it. It is *not* a build
plan — that's a blueprint, and it's private and throwaway.

## The Altitude Rule

Everything in a spec answers *what* or *why*. Nothing answers *how to build it
step by step*.

| Belongs in a spec | Does not belong |
|---|---|
| API / schema / data-model shape (concrete signatures, types) | Phase-by-phase implementation steps |
| Design forks with rationale and rejected alternatives | Code diffs or full implementations |
| Semantics: ordering, idempotency, error handling, permissions | Task checklists, time estimates |
| The existing primitives the feature composes, with file refs | Tutorial-level explanations of the codebase |
| Open questions with the action that resolves each | Speculation without a resolving action |

If a spec has grown phase-by-phase code steps, it has lost its altitude — move
those to a blueprint.

## File Conventions

- **Location:** `SPEC/` at the repo root (override only when the project already
  uses another convention).
- **Filename:** `SCREAMING-KEBAB-CASE.md` synthesized from the feature title —
  "cancel & annotate / replay API" → `CANCEL-AND-ANNOTATE-REPLAY-API.md`. Strip
  punctuation, join words with hyphens, uppercase.
- **One spec per work item.** Siblings get their own spec; the Scope section
  points across.

## Title Block

Every spec opens with a quote-block header linking it to its ticket:

```markdown
# <Feature Title> — Specification

> Ticket: [<project>#<number>](<web-url>)
> — child of [#<parent>](<parent-url>) "<parent-title>"   ← omit if no parent
> Status: **Draft** · Author: <author> · <YYYY-MM-DD>
```

- Resolve the author from `git config user.name` and the date from
  `date +%Y-%m-%d` — never assume either.
- **Status lifecycle:** `Draft` → `In Review` → `Agreed`. Update the status line
  when the spec's standing changes; don't fork a new file.

## Section Structure

Numbered sections, in this order. Include only the ones that apply — not every
spec has an "API"; some have a "Design" or "Data Model" instead — but scope,
motivation, background, design decisions, semantics, open questions, and a test
plan are always covered.

1. **Overview** — 2–4 sentences: what this is and the shape of the solution.
   Subsections: **Scope** (explicit in/out bullets; out-of-scope points to
   sibling work) and **Motivation** (the concrete pain, drawn from the ticket
   discussion — why now).
2. **Use Cases** — numbered, working backward from operator/user workflows. Tie
   each to a design element so reviewers can check coverage.
3. **Background: Relevant Existing Behavior** — the exact primitives the feature
   composes, **with file references**. One bullet per primitive: what it does,
   its return/failure shape, where it lives. This section is what makes a spec
   implementation-ready.
4. **Design** — the concrete shape: schema, signatures, types. Ends with a
   decision table (below).
5. **Semantics & Edge Cases** — the precise algorithm, ordering guarantees,
   idempotency, error handling, permissions.
6. **Non-Functional Requirements** — reliability, scale, performance, security —
   whatever is first-class for this feature.
7. **Scope & Siblings** — how the work decomposes and where the boundaries sit.
8. **Open Questions** — numbered; each with the concrete action that would close
   it.
9. **Test Plan** — unit / integration / compatibility coverage, mapped to the
   semantics in section 5.

## Decision Tables

Every non-trivial fork gets a row. A decision without a rationale and a rejected
alternative is not yet a decision.

```markdown
| Decision | Choice | Rationale |
|---|---|---|
| Sync mechanism | **Ticket comment** | Non-destructive; preserves decision history. Editing the body loses prior state. |
```

- The rationale cites the deciding constraint or an in-repo precedent — not
  hypothetical best practice.
- What you *cannot* decide yet is not a table row; it's an Open Question.

## Compose, Don't Invent

The best specs read as "assemble these existing pieces." Before writing the
Design section, research the codebase:

- Locate the exact services, types, and schema the feature builds on — read
  their signatures, return types, and partial-failure behavior.
- Find a precedent feature with a similar shape and mirror its patterns.
- Record the touch points (schema file, handler, service, persistence layer) as
  file references in the Background section.
- Check `CLAUDE.md` hard rules and compatibility conventions — constraints that
  foreclose an option often *are* the rationale for a fork.

If the research didn't surface the primitives, the design isn't ready — research
more before deciding.

## Style Rules

- **Tight and specific.** Cite an exact type or file over hand-waving. Short
  sections beat padded ones.
- **No individual names.** Attribute ideas to "the discussion," never to people —
  specs outlive team rosters.
- **Honest open questions beat false confidence.** An unknown with a resolving
  action is a strength; a confident guess is a defect.
- **Living document.** Revise the spec in place as the design evolves; the ticket
  comment trail (via `/design-spec`) preserves the history.
