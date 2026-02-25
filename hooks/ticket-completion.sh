#!/bin/bash
# =============================================================================
# TICKET COMPLETION HOOK
# =============================================================================
# PURPOSE: Remind to run /complete when marking tickets done in V1_TICKETS.md
# TRIGGER: PostToolUse:Edit(*V1_TICKETS.md*)
#
# DETECTION:
#   - Looks for checkbox changes: "- [ ]" -> "- [x]" or adding checkmark emoji
#   - If ticket appears to be marked complete, reminds to run /complete
#
# WHY THIS MATTERS:
#   - Ensures CHANGELOG.md is updated
#   - Ensures README.md is updated if needed
#   - Maintains consistent documentation practices
# =============================================================================

INPUT=$(cat)

# Extract file path and the edit content
if command -v jq &> /dev/null; then
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
    NEW_STRING=$(echo "$INPUT" | jq -r '.tool_input.new_string // empty')
    OLD_STRING=$(echo "$INPUT" | jq -r '.tool_input.old_string // empty')
else
    exit 0
fi

# Only check V1_TICKETS.md
if [[ ! "$FILE_PATH" =~ V1_TICKETS\.md$ ]]; then
    exit 0
fi

# Check if this edit is marking checkboxes as complete
# Look for patterns like:
#   - Changing "- [ ]" to "- [x]"
#   - Adding checkmark emoji to title

MARKING_COMPLETE=false

# Check if new_string contains [x] where old_string had [ ]
if echo "$OLD_STRING" | grep -q '\- \[ \]' && echo "$NEW_STRING" | grep -q '\- \[x\]'; then
    MARKING_COMPLETE=true
fi

# Check if adding checkmark emoji to a ticket title
if echo "$NEW_STRING" | grep -qE '^#{1,4}.*DRNG-[0-9]+.*✅' && ! echo "$OLD_STRING" | grep -q '✅'; then
    MARKING_COMPLETE=true
fi

# If marking a ticket complete, remind about /complete
if [ "$MARKING_COMPLETE" = true ]; then
    # Extract ticket ID if possible
    TICKET_ID=$(echo "$NEW_STRING" | grep -oP 'DRNG-\d+' | head -1)

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 TICKET COMPLETION DETECTED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    if [ -n "$TICKET_ID" ]; then
        echo "You marked $TICKET_ID as complete."
        echo ""
        echo "🔴 ACTION REQUIRED: Run /complete $TICKET_ID"
    else
        echo "You marked a ticket as complete."
        echo ""
        echo "🔴 ACTION REQUIRED: Run /complete [ticket-id]"
    fi
    echo ""
    echo "This will:"
    echo "  • Update CHANGELOG.md with this change"
    echo "  • Update README.md if user-facing"
    echo "  • Use today's date (never assume)"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
fi

exit 0
