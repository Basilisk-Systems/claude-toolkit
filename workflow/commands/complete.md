---
description: Complete a task/ticket with proper CHANGELOG and README updates
argument-hint: [ticket-id or description of completed work]
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
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

### Step 3: Determine CHANGELOG Action

**Compare the current version to the latest CHANGELOG entry:**

- If `current_version == latest_changelog_version`:
  → **UPDATE** the existing entry (add to the appropriate section)
  
- If `current_version > latest_changelog_version`:
  → **CREATE** a new entry at the top

- If no CHANGELOG.md exists:
  → **CREATE** the file with proper format

### Step 4: Update CHANGELOG.md

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

### Step 5: Evaluate README Updates

Check if README.md needs updates for any of these:
- [ ] New features that users need to know about
- [ ] Changed API or CLI commands
- [ ] New dependencies or requirements
- [ ] Updated installation instructions
- [ ] New configuration options
- [ ] Changed environment variables

**Only update README if the changes are user-facing.**

### Step 6: Update STANDUP.md (if exists)

If `.claude-local/STANDUP.md` exists, add the completed task to the "Completed" section:

```bash
ls .claude-local/STANDUP.md 2>/dev/null
```

If found, add a line to the "## Completed" section:
```markdown
- [x] Complete: [ticket-id or task description]
```

Group intelligently with existing entries if they're related to the same ticket/feature.

### Step 7: Output Summary

```markdown
## Task Completed ✓

### Summary
[What was accomplished]

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

### Example 1: Bug Fix (Same Version)
```
Current version: 1.2.3
Latest CHANGELOG entry: ## [1.2.3] - 2026-01-05

Action: Add to existing ### Fixed section in 1.2.3 entry
```

### Example 2: New Feature (Version Bump)
```
Current version: 1.3.0
Latest CHANGELOG entry: ## [1.2.3] - 2026-01-05

Action: Create new ## [1.3.0] - 2026-01-06 entry at top
```

### Example 3: No CHANGELOG
```
Action: Create CHANGELOG.md with header and first entry
```
