---
description: View work session status and optionally start new period
allowed-tools: Read, Write, Bash, Edit, AskUserQuestion
---

View current work session from `.claude-local/STANDUP.md` and optionally start a new work period.

## Arguments

- `/standup` - View status and optionally start new period
- `/standup summary` - Generate copy-paste ready standup summary
- `/standup help` - Show available commands

## Instructions

### 0. Check arguments

Check if `$ARGUMENTS` is provided:

- If `$ARGUMENTS` = "help" → Go to **Help Section**
- If `$ARGUMENTS` = "summary" → Go to **Summary Section**
- Otherwise → Continue with **Default Flow**

---

## Help Section

Output:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 /standup - Work Session Tracking
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Usage:
  /standup          View current status, optionally start new period
  /standup summary  Generate copy-paste ready standup summary
  /standup help     Show this help message

How it works:
  • STANDUP.md tracks your current work session
  • Items auto-populate via /commit, /complete, /pre-merge
  • After 24 hours, you'll be prompted to start a new period
  • Previous period is archived for reference

Setup:
  Run /init-claude-local to initialize .claude-local/ folder

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Then stop.

---

## Summary Section

### 1. Check if .claude-local/ exists

```bash
ls .claude-local/STANDUP.md 2>/dev/null
```

If not found, inform user:
> `.claude-local/` not initialized. Run `/init-claude-local` to set up.

Then stop.

### 2. Read STANDUP.md and extract data

```bash
cat .claude-local/STANDUP.md
```

Parse the file to extract:
- Completed items from "## Completed" section
- In Progress items from "## In Progress" section
- Blockers from "## Blockers" section
- Previous period completed items (if any)

### 3. Get current branch for context

```bash
git branch --show-current 2>/dev/null
```

### 4. Generate copy-paste summary

Format output for easy copying to Slack/Teams/Jira:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 STANDUP SUMMARY (ready to copy)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

**Yesterday:**
- [completed items from previous period, or current if same day]

**Today:**
- [in-progress items, or planned work based on branch]

**Blockers:**
- [blockers or "None"]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Rules for summary:
- "Yesterday" = Previous Period completed items, OR Current Period completed if started today
- "Today" = In Progress items. If empty, infer from branch name (e.g., "DRNG-44" → "Working on DRNG-44")
- "Blockers" = Blockers section, default to "None"
- Keep items concise - strip ticket prefixes like `feat(DRNG-XX):` to just the description
- Use bullet points for multiple items

### 5. Write summary to file

Write the generated summary (without the decorative borders) to `.claude-local/STANDUP_SUMMARY.md`:

```markdown
**Yesterday:**
- [items]

**Today:**
- [items]

**Blockers:**
- [blockers or "None"]
```

This file can be opened in the IDE for easy copy-paste.

Then stop.

---

## Default Flow

### 1. Check if .claude-local/ exists

```bash
ls .claude-local/STANDUP.md 2>/dev/null
```

If not found, inform user:
> `.claude-local/` not initialized. Run `/init-claude-local` to set up.

Then stop.

### 2. Read and display current STANDUP.md

```bash
cat .claude-local/STANDUP.md
```

Display the contents to the user with the file's last modified timestamp:
```bash
stat -c '%y' .claude-local/STANDUP.md 2>/dev/null || stat -f '%Sm' .claude-local/STANDUP.md
```

### 3. Check if new period should be prompted

Get current timestamp and compare to the "Started" timestamp in the file:
```bash
date +%s
```

Parse the "Started" line from STANDUP.md. If:
- "Started" is "Not yet initialized", OR
- More than 24 hours (86400 seconds) have passed since last period

Then prompt user using AskUserQuestion:
> "Start a new work period? This will archive the current period."

Options:
- "Yes, start new period"
- "No, continue current period"

### 4. If starting new period

a. **Ask about blockers** using AskUserQuestion:
> "Any blockers to note? (Select 'None' or describe)"

Options:
- "None"
- "Add blocker" (then ask for text input)

b. **Archive current period**:
- Move "Current Period" section to "Previous Period"
- Clear "In Progress" and "Completed" sections
- Update "Started" with current timestamp: `date '+%Y-%m-%d %H:%M %Z'`
- Add any blockers to the Blockers section

c. **Write updated STANDUP.md**

### 5. Also show quick git context

```bash
git branch --show-current 2>/dev/null
git status --short 2>/dev/null | head -5
git log --oneline -3 2>/dev/null
```

### 6. Format output

```markdown
## 📋 Work Session Status

**Current Period**: [Started timestamp]
**Last Updated**: [file modified time]

### In Progress
[from STANDUP.md]

### Completed This Period
[from STANDUP.md]

### Blockers
[from STANDUP.md]

---

### Git Status
- **Branch**: [branch name]
- **Changes**: [uncommitted file count or "clean"]
- **Recent commits**: [last 3 commits]
```

### 7. Suggest next steps

Based on context:
- If no completed items: "Ready to start working - items will be logged as you /commit or /complete"
- If has in-progress: "Continue with: [in-progress item]"
- If blockers exist: "Blockers noted - mention in standup"
