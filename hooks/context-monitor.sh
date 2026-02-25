#!/bin/bash
# =============================================================================
# CONTEXT MONITOR HOOK
# =============================================================================
# PURPOSE: Monitor context usage and alert when approaching limits
# TRIGGER: Stop (runs after Claude finishes responding)
#
# HOW IT WORKS:
#   - The Stop hook receives session information including token counts
#   - We calculate approximate context usage percentage
#   - Alert if above threshold
#
# NOTIFICATION METHODS:
#   - WSL2: Uses notify-send if available, falls back to terminal bell
#   - macOS: Uses osascript for native notifications
#   - Fallback: Terminal output and bell
#
# LIMITATIONS:
#   - Context percentage is approximate (based on available data)
#   - Some Claude Code versions may not expose token counts
# =============================================================================

INPUT=$(cat)

# =============================================================================
# EXTRACT CONTEXT INFO
# =============================================================================

# Try to extract context information from the Stop hook input
# Note: The exact structure depends on Claude Code version
if command -v jq &> /dev/null; then
    # Try different possible paths for context info
    CONTEXT_PERCENT=$(echo "$INPUT" | jq -r '.session.context_usage_percent // .context_percent // empty' 2>/dev/null)
    TOKENS_USED=$(echo "$INPUT" | jq -r '.session.tokens_used // .tokens_used // empty' 2>/dev/null)
    SESSION_ID=$(echo "$INPUT" | jq -r '.session.id // .session_id // empty' 2>/dev/null)
fi

# =============================================================================
# CALCULATE CONTEXT USAGE (if not directly provided)
# =============================================================================

# Opus 4.5 has 200K context window
MAX_TOKENS=200000

# If we have tokens_used but not percent, calculate it
if [ -z "$CONTEXT_PERCENT" ] && [ -n "$TOKENS_USED" ]; then
    CONTEXT_PERCENT=$(echo "scale=0; $TOKENS_USED * 100 / $MAX_TOKENS" | bc 2>/dev/null || echo "")
fi

# =============================================================================
# NOTIFICATION FUNCTIONS
# =============================================================================

send_notification() {
    local title="$1"
    local message="$2"
    local urgency="${3:-normal}"  # low, normal, critical
    
    # WSL2 / Linux
    if command -v notify-send &> /dev/null; then
        notify-send -u "$urgency" "$title" "$message"
        return 0
    fi
    
    # macOS
    if command -v osascript &> /dev/null; then
        osascript -e "display notification \"$message\" with title \"$title\"" 2>/dev/null
        return 0
    fi
    
    # Fallback: Terminal output + bell
    echo -e "\n🔔 $title: $message\n"
    echo -e "\a"  # Terminal bell
    return 0
}

# =============================================================================
# CHECK THRESHOLDS AND ALERT
# =============================================================================

# Define thresholds
WARNING_THRESHOLD=60
CRITICAL_THRESHOLD=75

if [ -n "$CONTEXT_PERCENT" ]; then
    # Convert to integer for comparison
    PERCENT_INT=${CONTEXT_PERCENT%.*}
    
    if [ "$PERCENT_INT" -ge "$CRITICAL_THRESHOLD" ]; then
        send_notification "⚠️ Claude Code Context Critical" \
            "Context usage at ${CONTEXT_PERCENT}%. Run /handoff NOW before quality degrades!" \
            "critical"
        
        # Also output to Claude's context so it sees this
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "⚠️  CONTEXT CRITICAL: ${CONTEXT_PERCENT}% used"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Recommendation: Run /handoff to save context, then /clear"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
    elif [ "$PERCENT_INT" -ge "$WARNING_THRESHOLD" ]; then
        send_notification "📊 Claude Code Context Warning" \
            "Context usage at ${CONTEXT_PERCENT}%. Consider running /handoff soon." \
            "normal"
        
        # Subtle inline notice
        echo ""
        echo "📊 Context: ${CONTEXT_PERCENT}% - Consider /handoff soon"
        echo ""
    fi
fi

# =============================================================================
# LOG SESSION (optional - uncomment to enable)
# =============================================================================

# LOG_DIR="$HOME/.claude/session-logs"
# mkdir -p "$LOG_DIR"
# TIMESTAMP=$(date +%Y-%m-%d_%H:%M:%S)
# LOG_FILE="$LOG_DIR/$(date +%Y-%m-%d).log"
# 
# echo "[$TIMESTAMP] Session: $SESSION_ID | Context: ${CONTEXT_PERCENT:-unknown}% | Tokens: ${TOKENS_USED:-unknown}" >> "$LOG_FILE"

exit 0
