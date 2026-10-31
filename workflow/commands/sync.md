---
description: Fetch and prune, fast-forward local main/dev to origin, delete local branches that are merged or whose remote is gone, optionally rebase the current feature branch
argument-hint: [--rebase] [--dry-run]
allowed-tools: Bash, Read
---

Sync local git state with the remote: $ARGUMENTS

Run this after a PR merges and before starting the next ticket (`/branch` runs it as its first
step). It touches only local refs: it never pushes, never force-pushes, and never deletes a branch
that holds work the remote does not have. Flags: `--rebase` also rebases the current feature
branch onto its refreshed base; `--dry-run` reports everything and changes nothing.

Ask nothing via dialogs. Where a decision is needed, report it in prose and stop that one item;
finish every other item.

## Step 1: Guard the working tree

```bash
git status --porcelain
```

If anything is listed (staged, unstaged or untracked-but-not-ignored), stop before changing any
ref: print the list and tell the user to commit or stash first. Do not stash for them.

Record the starting branch:

```bash
START=$(git branch --show-current)
```

## Step 2: Fetch and prune

```bash
git fetch --all --prune
```

Determine the base branches. Use every name from this list that exists on `origin`:
`main`, `master`, `dev`, `develop`.

```bash
for b in main master dev develop; do git show-ref --verify --quiet "refs/remotes/origin/$b" && echo "$b"; done
```

The project's `CLAUDE.md` may name the integration branch (for example a `dev`/`main` split);
it adds to this list, never replaces it.

## Step 3: Fast-forward the base branches

For each base branch `B` from Step 2:

- **Not present locally** → create it tracking origin: `git branch --track "$B" "origin/$B"`.
- **Present and checked out** → `git pull --ff-only origin "$B"`.
- **Present, not checked out** → fast-forward only when local is an ancestor of remote:

  ```bash
  if git merge-base --is-ancestor "$B" "origin/$B"; then
    git branch -f "$B" "origin/$B"
  else
    echo "DIVERGED: $B has local commits not on origin/$B"
  fi
  ```

Never rebase or reset a diverged base branch. Report it with
`git log --oneline origin/$B..$B` so the user sees what the local commits are, and move on.

With `--dry-run`, print the `git log --oneline B..origin/B` count instead of moving the ref.

## Step 4: Find stale local branches

Candidates are every local branch except the current one and the base branches. Classify each:

```bash
git for-each-ref --format='%(refname:short)|%(upstream:short)|%(upstream:track)' refs/heads/
```

| Class | Test | Action |
|---|---|---|
| `merged` | `git branch --merged origin/<B>` lists it for any base `B` | `git branch -d` |
| `gone` | upstream track is `[gone]` (remote branch deleted after merge; squash merges land here) | `git branch -D` only if the safety check below passes |
| `pr-merged` | remote still exists but `gh pr list --head <branch> --state merged --json number` is non-empty | `git branch -D` only if the safety check passes; note the remote branch is still there |
| `active` | none of the above | leave alone, list under "kept" |

**Safety check for `gone` and `pr-merged`:** the branch must have no commits that are absent from
every base branch *and* absent from the merged PR's merge commit. The cheap test that catches
squash merges:

```bash
# commits on the branch not reachable from any base
git log --oneline $(for b in <bases>; do printf -- "^origin/%s " "$b"; done) "<branch>"
```

If that list is non-empty, compare the branch's tree against the base instead:
`git diff --quiet "origin/<B>" "<branch>" -- .` succeeding for some base means the content landed
(squash merge). If neither test clears the branch, do not delete it; list it under "skipped:
unmerged commits" with the commit list.

Skip `gh` lookups when `gh auth status` fails; then only `merged` and `gone` classes apply.

The current branch is never deleted. If it is itself `gone`, `pr-merged` or `merged`, list it
under "Kept" with that class and a note that `/branch` (which checks out the base first) or a
re-run from the base branch will remove it.

With `--dry-run`, print the classification and planned action for each branch and delete nothing.

## Step 5: Rebase the current branch (only with `--rebase`)

Skip entirely unless `--rebase` was given and `$START` is not a base branch.

Pick the base: the branch named as integration branch in the project `CLAUDE.md` if there is
one, else `dev` if it exists on origin, else `main`.

```bash
git rebase "origin/<base>"
```

On conflict, run `git rebase --abort`, report the conflicting files, and leave the branch exactly
as it was. Never resolve conflicts here. Never push the rebased branch; tell the user it needs
`git push --force-with-lease` and let them decide.

## Step 6: Return and report

Check out `$START` again if any step moved off it (a branch that no longer exists cannot be
the start branch, since the current branch is never deleted).

Display:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔄 Sync with origin
   Fetched: origin (pruned N remote-tracking refs)
   main:  9a6700c → 1f2e3d4 (fast-forward, 3 commits)   | up to date | DIVERGED (2 local commits)
   dev:   created tracking origin/dev                    | not on origin
   Deleted:  feat/CODER-1-bootstrap-terraform-state (gone, PR #31 merged)
             chore/github-issues-for-tickets (merged)
   Kept:     feat/CODER-2-network (active)
   Skipped:  spike/foo (2 unmerged commits: abc1234, def5678)
   Rebase:   feat/CODER-2-network onto origin/main, clean | not requested | aborted: conflicts in x, y
   On branch: <START>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Omit lines that do not apply. With `--dry-run`, title the block `🔄 Sync (dry run, nothing
changed)` and show the planned action for every line.
