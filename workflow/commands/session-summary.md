---
description: Show session telemetry summary (tokens, cost, agents, files, duration)
allowed-tools: Bash, Read
---

Generate a session summary showing telemetry for the current or recent sessions.

## Instructions

### Step 1: Determine what to summarize

Check if the user provided arguments:
- No args → summarize today's sessions with `--today`
- A session ID or path → summarize that specific transcript
- "all" or a project path → use `--project`

### Step 2: Run the summary script

```bash
python3 ~/basilisk_systems/claude-toolkit/bin/session-summary.py --today
```

Or for a specific transcript:
```bash
python3 ~/basilisk_systems/claude-toolkit/bin/session-summary.py <path> --log
```

### Step 3: Present results

Show the output directly. If `--today` was used and there are multiple sessions, highlight the aggregate totals at the bottom.

If the user asks to log the results, rerun with `--log` to append to `~/.claude/session-logs/`.
