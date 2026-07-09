#!/bin/bash
# =============================================================================
# PRE-COMMIT CHECK HOOK
# =============================================================================
# PURPOSE: Runs pre-commit hooks before allowing git commit commands
# TRIGGER: PreToolUse
# MATCHER: Bash
#
# Ensures Claude-generated code passes all project quality gates before commit:
#   - Linting (ESLint, ruff, etc.)
#   - Formatting (Prettier, ruff format, etc.)
#   - Secret detection (detect-secrets, etc.)
#   - Type checking (mypy, tsc, etc.)
#
# NOTE: For a PreToolUse decision to apply, stdout must be ONLY the JSON
# decision object — no banners or progress output.
#
# Requires: pre-commit (https://pre-commit.com) — skips gracefully if not installed.
# =============================================================================

INPUT=$(cat)

# Extract the command being run
if command -v jq &> /dev/null; then
    COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
else
    COMMAND=$(echo "$INPUT" | grep -oP '"command"\s*:\s*"\K[^"]+')
fi

# Only check git commit commands (not amend, which is usually a fix-up)
if ! echo "$COMMAND" | grep -qE '^git\s+(commit|add.*&&.*commit)'; then
    exit 0
fi

# Skip if this is an amend (usually fixing a previous commit)
if echo "$COMMAND" | grep -qE '\-\-amend'; then
    exit 0
fi

# Check if pre-commit is available
if ! command -v pre-commit &> /dev/null; then
    exit 0
fi

# Run pre-commit on staged files
PRE_COMMIT_OUTPUT=$(pre-commit run 2>&1)
PRE_COMMIT_EXIT=$?

if [ $PRE_COMMIT_EXIT -ne 0 ]; then
    REASON="Pre-commit hooks failed. Fix the issues before committing.

$(echo "$PRE_COMMIT_OUTPUT" | tail -c 4000)"

    if command -v jq &> /dev/null; then
        jq -n --arg r "$REASON" '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$r}}'
        exit 0
    else
        # No jq: use the exit-2 deny path (reason on stderr)
        echo "$REASON" >&2
        exit 2
    fi
fi

# All pre-commit hooks passed — allow silently
exit 0
