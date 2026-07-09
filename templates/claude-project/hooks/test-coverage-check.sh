#!/bin/bash
# =============================================================================
# TEST COVERAGE CHECK HOOK
# =============================================================================
# PURPOSE: Runs tests and checks coverage after writing/editing test files
# TRIGGER: PostToolUse
# MATCHER: "Write|Edit" — the hook fires on every write and exits 0 early
#   unless the file looks like a test file for the configured STACK:
#   JS:     *.test.ts / *.test.tsx / *.test.js / *.test.jsx
#   Python: test_*.py / *_test.py
#
# FEEDBACK: PostToolUse stdout on exit 0 is NOT shown to Claude — failures
#   are reported on stderr with exit 2 so Claude can react.
#
# CONFIGURATION: Edit the variables below.
# =============================================================================

STACK="js"                  # "js" or "python"
COVERAGE_THRESHOLD=80       # Minimum coverage percentage

# =============================================================================

INPUT=$(cat)

# Extract the file path
if command -v jq &> /dev/null; then
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
else
    FILE_PATH=$(echo "$INPUT" | grep -oP '"file_path"\s*:\s*"\K[^"]+')
fi

# --- JavaScript/TypeScript stack ---
if [[ "$STACK" == "js" ]]; then
    # Early exit: only process JS/TS test files
    if [[ ! "$FILE_PATH" =~ \.test\.(ts|tsx|js|jsx)$ ]]; then
        exit 0
    fi

    TEST_FILE=$(basename "$FILE_PATH")

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "RUNNING TESTS & COVERAGE CHECK"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "File: $TEST_FILE"
    echo ""

    # Find the nearest package.json
    CHECK_DIR="$(dirname "$FILE_PATH")"
    while [[ ! -f "${CHECK_DIR}/package.json" && "$CHECK_DIR" != "/" ]]; do
        CHECK_DIR="$(dirname "$CHECK_DIR")"
    done

    if [[ ! -f "${CHECK_DIR}/package.json" ]]; then
        echo "Could not find package.json, skipping test run"
        exit 0
    fi

    cd "$CHECK_DIR"

    # Run the specific test file
    echo "Running test file..."
    TEST_OUTPUT=$(npm run test:run -- "$FILE_PATH" 2>&1)
    TEST_EXIT=$?

    if [ $TEST_EXIT -ne 0 ]; then
        {
            echo "TESTS FAILED: $TEST_FILE"
            echo ""
            echo "$TEST_OUTPUT" | tail -c 4000
            echo ""
            echo "Fix the failing tests before proceeding."
        } >&2
        exit 2
    fi

    echo "Tests passed"
    echo ""

    # Run coverage check (portable sed -E instead of GNU-only \| alternation)
    SOURCE_FILE=$(echo "$FILE_PATH" | sed -E 's/\.test\.(ts|tsx|js|jsx)$/.\1/' | sed 's/__tests__\///')

    if [[ -f "$SOURCE_FILE" ]]; then
        echo "Checking coverage for: $(basename "$SOURCE_FILE")"
        COVERAGE_OUTPUT=$(npm run test:coverage -- --reporter=text "$FILE_PATH" 2>&1)

        if echo "$COVERAGE_OUTPUT" | grep -qE "Coverage.*below.*threshold|ERROR.*Coverage"; then
            {
                echo "COVERAGE BELOW ${COVERAGE_THRESHOLD}% THRESHOLD"
                echo ""
                echo "$COVERAGE_OUTPUT" | grep -A5 -E "Coverage|File|%"
                echo ""
                echo "Add more tests to improve coverage."
            } >&2
            exit 2
        fi

        echo "Coverage meets threshold"
    fi

# --- Python stack ---
elif [[ "$STACK" == "python" ]]; then
    # Early exit: only process Python test files
    if [[ ! "$FILE_PATH" =~ (test_[^/]*\.py|[^/]*_test\.py)$ ]]; then
        exit 0
    fi

    TEST_FILE=$(basename "$FILE_PATH")

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "RUNNING TESTS & COVERAGE CHECK"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "File: $TEST_FILE"
    echo ""

    # Run the specific test file
    echo "Running test file..."
    TEST_OUTPUT=$(pytest "$FILE_PATH" -v 2>&1)
    TEST_EXIT=$?

    if [ $TEST_EXIT -ne 0 ]; then
        {
            echo "TESTS FAILED: $TEST_FILE"
            echo ""
            echo "$TEST_OUTPUT" | tail -c 4000
            echo ""
            echo "Fix the failing tests before proceeding."
        } >&2
        exit 2
    fi

    echo "Tests passed"
    echo ""

    # Run coverage check
    echo "Checking coverage..."
    COVERAGE_OUTPUT=$(pytest "$FILE_PATH" --cov --cov-fail-under="${COVERAGE_THRESHOLD}" 2>&1)
    COVERAGE_EXIT=$?

    if [ $COVERAGE_EXIT -ne 0 ]; then
        {
            echo "COVERAGE BELOW ${COVERAGE_THRESHOLD}% THRESHOLD"
            echo ""
            echo "$COVERAGE_OUTPUT" | tail -20
            echo ""
            echo "Add more tests to improve coverage."
        } >&2
        exit 2
    fi

    echo "Coverage meets threshold"
else
    echo "Unknown STACK value: $STACK (expected 'js' or 'python')"
    exit 0
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ALL CHECKS PASSED"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

exit 0
