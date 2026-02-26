---
description: Complete a task/ticket with proper CHANGELOG and README updates
argument-hint: [ticket-id or description of completed work]
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion
---

Complete the task: $ARGUMENTS

## Process

### Step 1: Get Accurate Current Date
**CRITICAL**: Always get the current date from the system, never assume:
```bash
date +%Y-%m-%d
```
Use this date for all CHANGELOG entries.

### Step 2: Gather Context
1. Read the current version from `package.json` or `pyproject.toml`:
   ```bash
   # For Node.js
   cat package.json | grep '"version"' | head -1
   
   # For Python
   cat pyproject.toml | grep 'version' | head -1
   ```

2. Read the current CHANGELOG.md to understand the format and latest entry

3. Summarize what was accomplished in this task

### Step 3: Evaluate Version Bump

**Analyze commits since the last version tag to determine if a version bump is warranted.**

1. Find the latest version tag and list commits since then:
   ```bash
   # Get latest version tag
   git tag --sort=-v:refname | head -1

   # List commits since that tag
   git log $(git tag --sort=-v:refname | head -1)..HEAD --oneline
   ```

2. Classify the changes by examining commit prefixes:
   - `feat(...)` → **minor** bump (new functionality)
   - `fix(...)` → **patch** bump (bug fix)
   - `refactor(...)`, `test(...)`, `docs(...)`, `chore(...)` → **no bump** (internal-only changes)

3. Determine the suggested bump level:
   - If ANY `feat` commits exist → suggest **minor** (0.0.X → 0.0.X+1 in pre-1.0, or 0.X.0 → 0.X+1.0 post-1.0)
   - Else if ANY `fix` commits exist → suggest **patch**
   - Else (only chore/test/docs/refactor) → suggest **no bump** (append to current version entry)

4. **Ask the user to confirm** using AskUserQuestion with these options:
   - **"Bump to [suggested version]"** — Apply the suggested bump
   - **"Bump [alternative]"** — e.g., if suggesting minor, offer patch as alternative
   - **"No bump (append to current entry)"** — Skip version bump, add to existing CHANGELOG entry

   Include the commit summary in the question description so the user can make an informed decision.

5. If bumping:
   - Update the `VERSION` file (if it exists)
   - Update `pyproject.toml` version field (if it exists)
   - These version file changes will be committed by the user later (or by `/commit`)

### Step 4: Determine CHANGELOG Action

**Based on the version decision from Step 3:**

- If **version was bumped** (new version > latest CHANGELOG version):
  → **CREATE** a new entry at the top with the new version

- If **no bump** (current version == latest CHANGELOG version):
  → **UPDATE** the existing entry (add to the appropriate section)

- If no CHANGELOG.md exists:
  → **CREATE** the file with proper format

### Step 5: Update CHANGELOG.md

Use this format (Keep a Changelog style):

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [X.Y.Z] - YYYY-MM-DD

### Added
- New feature description

### Changed
- Change description

### Fixed
- Bug fix description

### Removed
- Removed feature description

### Security
- Security fix description

### Deprecated
- Deprecated feature description
```

**Rules:**
- Use the ACTUAL current date from `date +%Y-%m-%d`
- Only include sections that have entries (don't add empty sections)
- Each entry should be a complete, understandable sentence
- Reference ticket/issue IDs if provided
- Be specific about what changed and why

### Step 6: Evaluate README Updates

Check if README.md needs updates for any of these:
- [ ] New features that users need to know about
- [ ] Changed API or CLI commands
- [ ] New dependencies or requirements
- [ ] Updated installation instructions
- [ ] New configuration options
- [ ] Changed environment variables

**Only update README if the changes are user-facing.**

### Step 7: Update STANDUP.md (if exists)

If `.claude-local/STANDUP.md` exists, add the completed task to the "Completed" section:

```bash
ls .claude-local/STANDUP.md 2>/dev/null
```

If found, add a line to the "## Completed" section:
```markdown
- [x] Complete: [ticket-id or task description]
```

Group intelligently with existing entries if they're related to the same ticket/feature.

### Step 8: Output Summary

```markdown
## Task Completed ✓

### Summary
[What was accomplished]

### Version Bump
- Previous: [X.Y.Z]
- New: [X.Y.Z+1] (or "No bump — appended to existing entry")
- Files updated: [VERSION, pyproject.toml, etc.]

### CHANGELOG Updated
- Version: [X.Y.Z]
- Date: [YYYY-MM-DD]
- Sections modified: [Added/Changed/Fixed/etc.]

### README Updated
- [Yes/No]
- Changes: [What was updated, if any]

### STANDUP.md Updated
- [Yes/No - depending on if .claude-local exists]

### Files Changed
- [List of files modified during this task]

### Next Steps
- [Any follow-up tasks or considerations]
```

## Examples

### Example 1: Feature ticket (bump suggested)
```
Current version: 0.0.8
Latest CHANGELOG entry: ## [0.0.8] - 2026-02-26
Commits since v0.0.8 tag: feat(CAR-9): Add Lambda handler stubs...

Analysis: feat commits found → suggest bump to 0.0.9
User confirms → bump VERSION + pyproject.toml → create new ## [0.0.9] entry
```

### Example 2: Bug fix only (patch bump)
```
Current version: 1.2.3
Latest CHANGELOG entry: ## [1.2.3] - 2026-01-05
Commits since v1.2.3 tag: fix(BUG-42): Resolve auth timeout...

Analysis: fix commits only → suggest bump to 1.2.4
User confirms → bump → create new ## [1.2.4] entry
```

### Example 3: Internal-only changes (no bump)
```
Current version: 0.0.8
Latest CHANGELOG entry: ## [0.0.8] - 2026-02-26
Commits since v0.0.8 tag: test(CAR-9): Add tests, chore: Fix typo

Analysis: only test/chore commits → suggest no bump
User confirms → append to existing ## [0.0.8] entry
```

### Example 4: No CHANGELOG
```
Action: Create CHANGELOG.md with header and first entry
```
