---
description: Generate a merge request title and description summarizing branch commits
argument-hint: [base-branch (default: main)]
allowed-tools: Bash, Read, Grep, Glob
---

Generate a merge request title and description for the current branch.

## Process

### 1. Gather Branch Information

```bash
# Get current branch name
git branch --show-current

# Get base branch (use argument or default to main)
BASE_BRANCH="${ARGUMENTS:-main}"

# Get commit count on this branch
git rev-list --count $BASE_BRANCH..HEAD

# Get all commits on this branch (not on base)
git log $BASE_BRANCH..HEAD --oneline

# Get detailed commit messages
git log $BASE_BRANCH..HEAD --format="### %s%n%n%b"

# Get summary of files changed
git diff $BASE_BRANCH --stat

# Get the actual diff for context (summarize large diffs)
git diff $BASE_BRANCH --name-only
```

### 2. Analyze the Changes

- Identify the ticket ID from branch name (e.g., DRNG-XX)
- Group commits by type (feat, fix, refactor, etc.)
- Identify the main themes/areas of change
- Note any breaking changes or migrations

### 3. Detect Version Bump

Compare the VERSION file on the branch against the base branch:

```bash
BASE_VERSION=$(git show $BASE_BRANCH:VERSION 2>/dev/null || echo "")
BRANCH_VERSION=$(cat VERSION 2>/dev/null || echo "")
```

If both versions exist and differ, parse semver (`major.minor.patch`) and determine:
- **major** — first segment changed (breaking changes)
- **minor** — second segment changed (new features, backward-compatible)
- **patch** — third segment changed (bug fixes, small additions)
- **none** — versions are the same or VERSION file doesn't exist

**Validation heuristics** (warn, don't block):
- `feat` commits + patch bump → ⚠️ "New feature with only a patch bump — is this intentional?"
- Any commit message contains "BREAKING" or "breaking change" + non-major bump → ⚠️ "Breaking change detected but not a major bump"
- Only `fix`/`docs`/`chore`/`test`/`refactor` commits + minor/major bump → ⚠️ "No feature commits but minor/major bump — is this intentional?"

If a warning applies, include it in the PR description under `## Release` so the reviewer sees it.

### 4. Generate MR Title

Format: `<type>(DRNG-XX): <concise summary>`

Rules:
- Extract ticket ID from branch name if present
- Use the dominant commit type (feat if mixed features, fix if bug fixes)
- Summarize the overall change in under 72 characters
- Use imperative mood ("Add" not "Added")

### 5. Generate MR Description

Use this template:

```markdown
## Summary

[2-4 bullet points summarizing what this MR does]

## Release

`X.Y.Z` → `A.B.C` (patch|minor|major)

[If validation warning applies, add it here, e.g.:]
[⚠️ New feature commits detected with only a patch bump — is this intentional?]

[If VERSION didn't change, use:]
No version change

## Changes

### [Category 1]
- [Change description]
- [Change description]

### [Category 2]
- [Change description]

## Testing

- [ ] [Test that was performed or should be performed]
- [ ] [Additional test]

## Related

- Ticket: [DRNG-XX](link if known)
- Related MRs: (if any)
```

### 6. Check GitHub CLI Authentication

```bash
gh auth status 2>&1
```

### 7a. If Authenticated — Push and Create PR

Push the branch and create the PR automatically:

```bash
# Push the branch
git push -u origin $(git branch --show-current)

# Create the PR using gh CLI
BASE_BRANCH="${ARGUMENTS:-main}"
gh pr create --base "$BASE_BRANCH" --title "[title here]" --body "$(cat <<'EOF'
[description here]
EOF
)"
```

Output the PR URL returned by `gh pr create`:
```
✅ PR created: [URL]
```

### 7b. If NOT Authenticated — Output Copy-Paste Format

Present the title and description in a copy-paste ready format:

```
═══════════════════════════════════════════════════════════════
MERGE REQUEST TITLE
═══════════════════════════════════════════════════════════════

[title here]

═══════════════════════════════════════════════════════════════
MERGE REQUEST DESCRIPTION
═══════════════════════════════════════════════════════════════

[description here]

═══════════════════════════════════════════════════════════════
ℹ️  GitHub CLI not authenticated — PR not created automatically.
    Run `gh auth login` to enable auto-PR creation.
═══════════════════════════════════════════════════════════════
```

### 8. Update STANDUP.md (if exists)

If `.claude-local/STANDUP.md` exists, add the MR preparation to the "Completed" section:

```bash
ls .claude-local/STANDUP.md 2>/dev/null
```

If found, add a line to the "## Completed" section:
```markdown
- [x] MR prepared: [branch-name] → [base-branch]
```

## Notes

- If there's only one commit, base the MR title/description primarily on that commit
- For multi-commit branches, synthesize an overall narrative
- Highlight any commits that seem out of scope or potentially problematic
- If the branch appears to be a work-in-progress, note that
