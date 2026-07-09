#!/bin/bash
# =============================================================================
# CLOUD CLI BLOCKER HOOK
# =============================================================================
# PURPOSE: Prevents Claude from executing cloud/infrastructure CLI commands
# TRIGGER: PreToolUse
# MATCHER: Bash
#
# These commands should be provided to the user to copy-paste, not executed
# by Claude directly (Claude typically lacks credentials/permissions).
#
# NOTE: For a PreToolUse decision to apply, stdout must be ONLY the JSON
# decision object — no banners or extra text.
#
# CONFIGURATION: Edit the BLOCKED_COMMANDS variable below.
# Common options: aws, cdk, gcloud, az, terraform, pulumi, kubectl, helm
# =============================================================================

BLOCKED_COMMANDS="aws|cdk"

# =============================================================================

INPUT=$(cat)

# Extract the command being run
if command -v jq &> /dev/null; then
    COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
else
    COMMAND=$(echo "$INPUT" | grep -oP '"command"\s*:\s*"\K[^"]+')
fi

# Check if a blocked CLI appears at a command position (start of command or
# after && || ; |) — not just anywhere in the string.
if echo "$COMMAND" | grep -qE "(^|&&|\|\||;|\|)[[:space:]]*(${BLOCKED_COMMANDS})[[:space:]]"; then
    MATCHED=$(echo "$COMMAND" | grep -oE "(^|&&|\|\||;|\|)[[:space:]]*(${BLOCKED_COMMANDS})[[:space:]]" | head -1 | grep -oE "(${BLOCKED_COMMANDS})" | head -1)
    REASON="CLOUD CLI COMMAND BLOCKED

Command: $COMMAND
Blocked CLI: $MATCHED

Cloud CLI commands must be provided to the user to copy-paste, not executed directly. Format the command for the user."

    if command -v jq &> /dev/null; then
        jq -n --arg r "$REASON" '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$r}}'
        exit 0
    else
        # No jq: use the exit-2 deny path (reason on stderr)
        echo "$REASON" >&2
        exit 2
    fi
fi

# Allow the command
exit 0
