#!/bin/bash
# =============================================================================
# PYTHON LINTING & FORMATTING HOOK
# =============================================================================
# PURPOSE: Run pre-commit checks on Python files after Write/Edit
# TRIGGER: PostToolUse:Write(*.py), PostToolUse:Edit(*.py)
#
# WHY POST-TOOL:
#   - Runs AFTER Claude writes the file
#   - Catches linting errors, type issues, and formatting problems immediately
#   - Failures are reported so Claude can fix them
#
# CHECKS RUN (via pre-commit):
#   - ruff: Linting and import sorting
#   - ruff-format: Code formatting
#   - mypy: Type checking
# =============================================================================

INPUT=$(cat)

# Extract file path from the tool result
if command -v jq &> /dev/null; then
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
else
    FILE_PATH=$(echo "$INPUT" | grep -oP '"file_path"\s*:\s*"\K[^"]+')
fi

# Skip if no file path
if [ -z "$FILE_PATH" ]; then
    exit 0
fi

# Skip if not a Python file (double-check)
if [[ ! "$FILE_PATH" =~ \.py$ ]]; then
    exit 0
fi

# Skip if file doesn't exist
if [ ! -f "$FILE_PATH" ]; then
    exit 0
fi

# =============================================================================
# RUN PRE-COMMIT OR FALLBACK TO BLACK
# =============================================================================

# Check if pre-commit config exists in the project
if [ -f ".pre-commit-config.yaml" ] && command -v pre-commit &> /dev/null; then
    # Run pre-commit on just this file
    # This runs ruff, ruff-format, and mypy
    OUTPUT=$(pre-commit run --files "$FILE_PATH" 2>&1)
    EXIT_CODE=$?

    if [ $EXIT_CODE -ne 0 ]; then
        # Report failures so Claude can fix them
        echo "Pre-commit checks failed for: $FILE_PATH"
        echo "$OUTPUT"
        exit 1
    fi
else
    # Fallback to just black if no pre-commit config
    if command -v black &> /dev/null; then
        FORMATTER="black"
    elif python3 -m black --version &> /dev/null 2>&1; then
        FORMATTER="python3 -m black"
    else
        echo "Warning: Neither pre-commit nor black available" >&2
        exit 0
    fi

    $FORMATTER --quiet "$FILE_PATH" 2>&1
fi

exit 0
