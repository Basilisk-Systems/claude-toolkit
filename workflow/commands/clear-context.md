---
description: Clear context and reload HANDOFF.md - run this instead of /clear to preserve session continuity
argument-hint: [skip] — "skip" suppresses the HANDOFF.md reload (and the opening brief) in the fresh context
allowed-tools: Bash
---

# Clear Context with Handoff Reload

This command prepares for a context clear while ensuring HANDOFF.md will be automatically loaded in the fresh context.

## Modes

- **`/clear-context`** (default) — the first prompt after `/clear` gets HANDOFF.md injected, and Claude opens its reply with a short "Where we left off" brief.
- **`/clear-context skip`** — the first prompt after `/clear` gets **no** handoff and **no** brief. Use it right before a flow that reads its own state instead of HANDOFF.md (e.g. `/blueprint` → `/clear-context skip` → `/clear` → `/implement`, which reads the plan file and `IMPLEMENT_STATE.md`).

If `$ARGUMENTS` is anything other than empty or `skip`, tell the user the only recognised argument is `skip` and stop.

## Instructions

1. **Verify the session-handoff hook is configured** — the reload only works if the project has the hook installed:

```bash
grep -q "session-handoff.sh" .claude/settings.json 2>/dev/null && echo "HOOK_CONFIGURED" || echo "HOOK_MISSING"
```

If `HOOK_MISSING`, stop and tell the user:
```
⚠️  The session-handoff hook is not configured in .claude/settings.json,
    so HANDOFF.md will NOT auto-load after /clear.

    Run the toolkit's project-init.sh in this repo to set it up, then re-run /clear-context.
```
Do not proceed to the next steps.

2. **Delete the session marker** so the hook treats the next prompt as a fresh context:

```bash
rm -f .claude-local/.session-marker
```

3. **If `$ARGUMENTS` is `skip`, write the one-shot skip sentinel** — the hook consumes it on the next fresh context and stays silent:

```bash
touch .claude-local/.handoff-skip
```

If `$ARGUMENTS` is empty, make sure no stale sentinel is left over from an earlier `skip` run:

```bash
rm -f .claude-local/.handoff-skip
```

4. **Confirm to the user** that they should now run `/clear`:

Default mode — output this message:
```
✅ Session marker cleared.

Now run: /clear

Your HANDOFF.md will automatically load on your next message, and Claude
will open with a brief "Where we left off" summary.
```

Skip mode — output this message:
```
✅ Session marker cleared, handoff reload suppressed for the next context.

Now run: /clear

HANDOFF.md will NOT load on your next message (one-shot). The following
/clear-context without "skip" restores the normal reload.
```

## Important

- Do NOT attempt to run /clear programmatically - it's a built-in command
- The user must manually run /clear after this command
- The UserPromptSubmit hook will detect the missing marker and output HANDOFF.md (or consume the skip sentinel and stay silent)
- The skip sentinel is one-shot: it is deleted the first time the hook honours it
