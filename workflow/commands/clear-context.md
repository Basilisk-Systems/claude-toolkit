---
description: Clear context and reload HANDOFF.md - run this instead of /clear to preserve session continuity
allowed-tools: Bash
---

# Clear Context with Handoff Reload

This command prepares for a context clear while ensuring HANDOFF.md will be automatically loaded in the fresh context.

## Instructions

1. **Delete the session marker** to trigger handoff reload:

```bash
rm -f .claude-local/.session-marker
```

2. **Confirm to the user** that they should now run `/clear`:

Output this message:
```
✅ Session marker cleared.

Now run: /clear

Your HANDOFF.md will automatically load on your next message.
```

## Important

- Do NOT attempt to run /clear programmatically - it's a built-in command
- The user must manually run /clear after this command
- The UserPromptSubmit hook will detect the missing marker and output HANDOFF.md
