#!/bin/bash
# =============================================================================
# SESSION HANDOFF HOOK
# =============================================================================
# PURPOSE: Automatically outputs HANDOFF.md contents on new sessions or after
#          /clear-context to ensure Claude has session context
# TRIGGER: UserPromptSubmit
# MATCHER: "" (all prompts)
#
# Auto-included by /init-claude-local — not optional.
# =============================================================================

MARKER_FILE=".claude-local/.session-marker"
HANDOFF_FILE=".claude-local/HANDOFF.md"

# Check if HANDOFF.md exists
if [[ ! -f "$HANDOFF_FILE" ]]; then
    exit 0
fi

# Use the Claude Code session_id from stdin JSON as the session marker.
# ($$-$PPID is new on every hook invocation, which would re-inject the
# handoff on every single prompt.)
INPUT=$(cat)
if command -v jq &> /dev/null; then
    SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
else
    SESSION_ID=$(echo "$INPUT" | grep -oP '"session_id"\s*:\s*"\K[^"]+' | head -1)
fi
CURRENT_SESSION="${SESSION_ID:-unknown}"

# Check if marker exists and matches current session
if [[ -f "$MARKER_FILE" ]]; then
    STORED_SESSION=$(cat "$MARKER_FILE" 2>/dev/null)
    if [[ "$STORED_SESSION" == "$CURRENT_SESSION" ]]; then
        # Same session, no need to output handoff
        exit 0
    fi
fi

# New session or marker was cleared - output HANDOFF.md
echo ""
echo "=============================================="
echo "SESSION CONTEXT (from HANDOFF.md)"
echo "=============================================="
cat "$HANDOFF_FILE"
echo ""
echo "=============================================="
echo "END SESSION CONTEXT"
echo "=============================================="
echo ""

# Update marker with current session
mkdir -p "$(dirname "$MARKER_FILE")"
echo "$CURRENT_SESSION" > "$MARKER_FILE"
