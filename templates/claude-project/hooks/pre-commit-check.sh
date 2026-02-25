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

# Run pre-commit on staged files
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "RUNNING PRE-COMMIT HOOKS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if pre-commit is available
if ! command -v pre-commit &> /dev/null; then
    echo "pre-commit not found, skipping checks"
    exit 0
fi

# Run pre-commit on staged files only
PRE_COMMIT_OUTPUT=$(pre-commit run 2>&1)
PRE_COMMIT_EXIT=$?

if [ $PRE_COMMIT_EXIT -ne 0 ]; then
    echo "$PRE_COMMIT_OUTPUT"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "PRE-COMMIT HOOKS FAILED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Fix the issues above before committing."
    echo ""
    echo "{\"decision\": \"block\", \"reason\": \"Pre-commit hooks failed. Fix issues before committing.\"}"
    exit 0
fi

echo "All pre-commit hooks passed"
echo ""

exit 0
