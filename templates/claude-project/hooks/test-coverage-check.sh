#!/bin/bash
# =============================================================================
# TEST COVERAGE CHECK HOOK
# =============================================================================
# PURPOSE: Runs tests and checks coverage after writing/editing test files
# TRIGGER: PostToolUse
# MATCHER: Depends on STACK setting (see below)
#   JS:     Write(*.test.ts)|Write(*.test.tsx)|Write(*.test.js)|Write(*.test.jsx)|Edit(*.test.ts)|Edit(*.test.tsx)|Edit(*.test.js)|Edit(*.test.jsx)
#   Python: Write(test_*.py)|Write(*_test.py)|Edit(test_*.py)|Edit(*_test.py)
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
    # Only process JS/TS test files
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
        echo "$TEST_OUTPUT"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "TESTS FAILED"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "Fix the failing tests before proceeding."
        exit 0
    fi

    echo "Tests passed"
    echo ""

    # Run coverage check
    SOURCE_FILE=$(echo "$FILE_PATH" | sed 's/\.test\.\(ts\|tsx\|js\|jsx\)$/.\1/' | sed 's/__tests__\///')

    if [[ -f "$SOURCE_FILE" ]]; then
        echo "Checking coverage for: $(basename "$SOURCE_FILE")"
        COVERAGE_OUTPUT=$(npm run test:coverage -- --reporter=text "$FILE_PATH" 2>&1)

        if echo "$COVERAGE_OUTPUT" | grep -qE "Coverage.*below.*threshold|ERROR.*Coverage"; then
            echo ""
            echo "$COVERAGE_OUTPUT" | grep -A5 -E "Coverage|File|%"
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "COVERAGE BELOW ${COVERAGE_THRESHOLD}% THRESHOLD"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            echo "Add more tests to improve coverage."
            exit 0
        fi

        echo "Coverage meets threshold"
    fi

# --- Python stack ---
elif [[ "$STACK" == "python" ]]; then
    # Only process Python test files
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
        echo "$TEST_OUTPUT"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "TESTS FAILED"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "Fix the failing tests before proceeding."
        exit 0
    fi

    echo "Tests passed"
    echo ""

    # Run coverage check
    echo "Checking coverage..."
    COVERAGE_OUTPUT=$(pytest "$FILE_PATH" --cov --cov-fail-under="${COVERAGE_THRESHOLD}" 2>&1)
    COVERAGE_EXIT=$?

    if [ $COVERAGE_EXIT -ne 0 ]; then
        echo "$COVERAGE_OUTPUT" | tail -20
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "COVERAGE BELOW ${COVERAGE_THRESHOLD}% THRESHOLD"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "Add more tests to improve coverage."
        exit 0
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
