---
description: Create a semantic branch based on a provided ticket description
argument-hint: <ticket-id or description> (e.g., PL-025 or "add user login")
allowed-tools: Bash, Read, Grep
---

Create a semantic git branch from: $ARGUMENTS

## Step 1: Resolve the Branch Name

### 1a. Determine Input Type

Check if `$ARGUMENTS` matches a ticket ID pattern (e.g., `PL-025`, `CAR-11`):

```bash
echo "$ARGUMENTS" | grep -qE '^[A-Z]+-[0-9]+$'
```

- **Ticket ID match** → Go to Step 1b
- **No match** → Treat `$ARGUMENTS` as a freeform description, go to Step 1c

### 1b. Look Up Ticket

Read `docs/TICKETS.md` and find the heading matching the ticket ID:

```bash
grep -E "^## $ARGUMENTS:" docs/TICKETS.md
```

Extract:
- **Title** — the text after `## PL-XXX: ` on the heading line
- **Type** — the `**Type:**` field value (Feature, Bug Fix, Chore, etc.)
- **Status** — check for `**Status:** ✅ Complete` — if complete, warn the user and ask if they want to proceed

Map the ticket type to a branch prefix:
| Ticket Type | Branch Prefix |
|------------|---------------|
| Feature, Feature / Migration | `feature` |
| Bug, Bug Fix | `fix` |
| Chore, Maintenance | `chore` |
| Documentation, Docs | `docs` |
| Test, Testing | `test` |
| Refactor, Refactoring | `refactor` |
| CI, CI/CD, Pipeline | `ci` |
| *(anything else)* | `feature` |

Generate the branch name: `<prefix>/<ticket-id>-<kebab-title>`

- Convert title to lowercase kebab-case (a-z, 0-9, hyphens only)
- Truncate to keep total branch name under 60 characters
- Strip trailing hyphens

Example: `PL-019: Migrate Legal Page to React` → `feature/PL-019-migrate-legal-page-to-react`

### 1c. Freeform Description

When no ticket ID is provided, parse the description:

- Default prefix: `feature`
- If description starts with a type keyword (`fix:`, `chore:`, `docs:`, etc.), use that as the prefix and strip it from the slug
- Convert remaining text to lowercase kebab-case
- Truncate to keep total branch name under 60 characters

Example: `"fix: broken nav links"` → `fix/broken-nav-links`

## Step 2: Verify Branch Doesn't Exist

```bash
git branch --list "<branch-name>"
git branch -r --list "origin/<branch-name>"
```

If the branch already exists locally or on the remote, tell the user and ask if they want to check it out instead.

## Step 3: Create and Checkout

```bash
git checkout -b <branch-name>
```

## Step 4: Report

Display:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🌿 Branch created: <branch-name>
   From: <current-branch> @ <short-sha>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

If created from a ticket, also show:
```
   Ticket: <ticket-id> — <title>
```
