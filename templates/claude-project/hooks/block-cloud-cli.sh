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

# Check if command starts with any blocked CLI
if echo "$COMMAND" | grep -qE "^\s*(${BLOCKED_COMMANDS})\s"; then
    # Extract which CLI was matched for the message
    MATCHED=$(echo "$COMMAND" | grep -oE "^\s*(${BLOCKED_COMMANDS})" | xargs)
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "CLOUD CLI COMMAND BLOCKED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Command: $COMMAND"
    echo "Blocked CLI: $MATCHED"
    echo ""
    echo "Cloud CLI commands must be provided to the user to copy-paste,"
    echo "not executed directly. Format the command for the user."
    echo ""
    echo "{\"decision\": \"block\", \"reason\": \"Cloud CLI commands must be provided to user, not executed. Format the command for copy-paste.\"}"
    exit 0
fi

# Allow the command
exit 0
