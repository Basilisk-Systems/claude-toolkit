#!/bin/bash
# =============================================================================
# SESSION HANDOFF HOOK
# =============================================================================
# PURPOSE: Automatically outputs HANDOFF.md contents on new sessions or after
#          /clear-context so Claude has session context, and asks Claude to
#          open its first reply with a short "where we left off" brief.
# TRIGGER: UserPromptSubmit
# MATCHER: "" (all prompts)
#
# SKIP:    `/clear-context skip` writes .claude-local/.handoff-skip. The next
#          fresh context consumes that sentinel and stays silent (no handoff,
#          no brief). Use it before flows that read their own state instead of
#          HANDOFF.md (e.g. /implement reads the plan + IMPLEMENT_STATE.md).
#
# Auto-included by /init-claude-local — not optional.
# =============================================================================

MARKER_FILE=".claude-local/.session-marker"
SKIP_FILE=".claude-local/.handoff-skip"
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
    PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty')
else
    SESSION_ID=$(echo "$INPUT" | grep -oP '"session_id"\s*:\s*"\K[^"]+' | head -1)
    PROMPT=$(echo "$INPUT" | grep -oP '"prompt"\s*:\s*"\K[^"]*' | head -1)
fi
CURRENT_SESSION="${SESSION_ID:-unknown}"

# The built-in /clear keystroke belongs to the context that is about to be
# discarded. It must never rewrite the marker or consume the skip sentinel,
# otherwise the first real prompt of the fresh context would misbehave.
if [[ "$PROMPT" =~ ^[[:space:]]*/clear[[:space:]]*$ ]]; then
    exit 0
fi

# Check if marker exists and matches current session
if [[ -f "$MARKER_FILE" ]]; then
    STORED_SESSION=$(cat "$MARKER_FILE" 2>/dev/null)
    if [[ "$STORED_SESSION" == "$CURRENT_SESSION" ]]; then
        # Same session, no need to output handoff
        exit 0
    fi
fi

# Fresh context from here on. Honour a one-shot skip request first.
mkdir -p "$(dirname "$MARKER_FILE")"
if [[ -f "$SKIP_FILE" ]]; then
    rm -f "$SKIP_FILE"
    echo "$CURRENT_SESSION" > "$MARKER_FILE"
    exit 0
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
echo "INSTRUCTION FOR THIS TURN: This is a fresh context. Open your reply with a"
echo "short 'Where we left off' brief of the handoff above — 4 to 6 bullets covering"
echo "branch/commit, what is verified working, open blockers, and the next 1-2"
echo "actions. Then address the user's message. Do not repeat the full handoff."
echo ""

# Update marker with current session
echo "$CURRENT_SESSION" > "$MARKER_FILE"
