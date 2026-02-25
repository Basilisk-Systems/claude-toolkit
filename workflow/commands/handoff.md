---
description: Generate a comprehensive session handoff summary for context continuity
allowed-tools: Read, Write, Glob, Grep
---

Generate a detailed handoff summary to preserve session context. This enables seamless continuation in a new session.

## Instructions

1. **Analyze the current session** - Review our conversation to identify:
   - Key decisions made and their rationale
   - Files that were created, modified, or discussed
   - Problems encountered and how they were resolved
   - Any workarounds or temporary solutions applied

2. **Create a structured summary** using this format:

```markdown
# Session Handoff - [DATE]

## Session Summary
[2-3 sentence overview of what was accomplished]

## Decisions Made
| Decision | Rationale | Files Affected |
|----------|-----------|----------------|
| [Decision 1] | [Why we chose this] | [file1.ts, file2.py] |

## Changes Implemented
- **[File path]**: [What changed and why]
- **[File path]**: [What changed and why]

## Current State
- **Working**: [What's functional]
- **In Progress**: [What's partially done]
- **Blocked**: [What's waiting on something]

## Blockers & Issues
| Issue | Status | Notes |
|-------|--------|-------|
| [Issue description] | [Open/Resolved/Workaround] | [Details] |

## Remaining Work
- [ ] [Task 1 - specific and actionable]
- [ ] [Task 2 - specific and actionable]
- [ ] [Task 3 - specific and actionable]

## Technical Notes
[Any important technical details the next session needs to know:
- Environment variables needed
- Commands to run
- Dependencies to install
- Gotchas or edge cases discovered]

## Files to Review First
1. `[most important file]` - [why]
2. `[second file]` - [why]

---
*Handoff created: [TIMESTAMP]*
```

3. **Save to `.claude-local/HANDOFF.md`** - Create the `.claude-local/` directory if it doesn't exist (run `/init-claude-local` if missing)

4. **Output the summary here** as well so I can see it

## Important Notes
- Be SPECIFIC with file paths (full relative paths from project root)
- Include actual code snippets or commands if they're non-obvious
- Note any environment-specific details (WSL paths, etc.)
- If there were failed approaches, document them to avoid repeating
