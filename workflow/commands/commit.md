---
description: Stage changes, verify docs are updated, and prepare commit message
argument-hint: [optional: specific files to commit]
allowed-tools: Read, Edit, Bash, Glob, Grep
---

Prepare a commit for: $ARGUMENTS

## Process

### Step 1: Gather Git State

```bash
# Show current status (never use -uall flag)
git status

# Show staged and unstaged changes
git diff --stat
git diff --cached --stat

# Show recent commits for message style reference
git log --oneline -5
```

### Step 2: Check Documentation Requirements

**CRITICAL: Before drafting the commit message, verify documentation is updated.**

#### 2a. Check if VERSION changed
```bash
# Check if VERSION is in the diff
git diff --name-only HEAD~1 2>/dev/null | grep -E "^VERSION$" || git diff --cached --name-only | grep -E "^VERSION$" || echo "VERSION_NOT_CHANGED"
```

#### 2b. If VERSION changed, verify CHANGELOG was updated
```bash
# Check if CHANGELOG.md was modified
git diff --name-only | grep -E "CHANGELOG" || git diff --cached --name-only | grep -E "CHANGELOG" || echo "CHANGELOG_NOT_MODIFIED"
```

#### 2c. Compare versions
If VERSION changed but CHANGELOG wasn't updated:
1. Read the current VERSION file
2. Read the latest version entry in CHANGELOG.md
3. If they don't match: **STOP and run `/complete [task]` first**

### Step 3: Verify README if User-Facing Changes

Check if changes affect:
- [ ] New CLI commands or flags
- [ ] New environment variables
- [ ] Changed API endpoints
- [ ] New features users need to know about
- [ ] Installation or setup changes

If user-facing changes exist and README wasn't updated:
- **STOP and update README.md first**

### Step 4: Documentation Gate

**If either check fails, output:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🛑 DOCUMENTATION NOT UPDATED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

VERSION: X.Y.Z
CHANGELOG latest: [version from CHANGELOG]

Action required:
  Run: /complete [task-description]

This will update CHANGELOG.md and README.md as needed.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Do NOT proceed with commit message until documentation is updated.**

### Step 5: Run Pre-commit Hooks

**CRITICAL: Run pre-commit hooks to catch linting/formatting issues before drafting the commit message.**

```bash
git add -A && pre-commit run
```

If pre-commit fails:
1. Review the errors (ruff, mypy, detect-secrets, etc.)
2. Fix the issues (formatting is often auto-fixed)
3. Re-run `pre-commit run` until all checks pass
4. Only then proceed to draft the commit message

**Do NOT proceed with commit message until pre-commit passes.**

### Step 6: Draft Commit Message (only if docs are updated and pre-commit passes)

Follow the project's commit conventions:

```
<type>(DRNG-XX): <description>

[optional body]
```

**IMPORTANT: Do NOT include Co-Authored-By or author attribution lines.**

**Types:** feat, fix, docs, chore, refactor, test

**Rules:**
- Extract ticket ID from branch name or changes
- Keep first line under 72 characters
- Use imperative mood ("Add" not "Added")
- Reference what changed and why

### Step 7: Execute the Commit

#### 7a. Output the commit message first

Show the user what will be committed:

```
Commit message:

[commit message here]

---
Docs: ✓ CHANGELOG | ✓ README (or N/A)
Pre-commit: ✓ Passed
```

#### 7b. Stage and commit the changes

Run the commit:

```bash
git add -A && git commit -m "$(cat <<'EOF'
[commit message here]
EOF
)"
```

#### 7c. Verify success

After commit, run `git status` to confirm the commit succeeded.

### Step 8: Auto-Push (if GitHub CLI authenticated)

Check if `gh` CLI is authenticated:

```bash
gh auth status 2>&1
```

**If authenticated (exit code 0):**

Push the branch automatically:

```bash
git push -u origin $(git branch --show-current)
```

Output:
```
✅ Pushed to origin/[branch-name]
```

**If NOT authenticated (exit code non-zero):**

Output:
```
ℹ️  GitHub CLI not authenticated — commit is local only.
    Run `gh auth login` to enable auto-push on future commits.
```

Do NOT attempt to push. Proceed to Step 9.

### Step 9: Update STANDUP.md (if exists)

If `.claude-local/STANDUP.md` exists, append the commit to the "Completed" section:

```bash
ls .claude-local/STANDUP.md 2>/dev/null
```

If found, add a line to the "## Completed" section:
```markdown
- [x] <type>(DRNG-XX): <short description>
```

Group intelligently with existing entries if they're related to the same ticket/feature.

## Important Notes

- **NEVER skip the documentation check** - it exists to prevent incomplete commits
- If the user explicitly says "skip docs" or "docs not needed", you may proceed
- Check `.gitignore` before suggesting files to stage
- If commit fails due to pre-commit hooks, fix the issues and retry
