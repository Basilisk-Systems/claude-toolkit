#!/bin/bash
# =============================================================================
# COMMAND OUTPUT LOGGER HOOK
# =============================================================================
# PURPOSE: Capture output from significant Bash commands to a log file
# TRIGGER: PostToolUse:Bash
#
# HOW IT WORKS:
#   - After Claude runs a bash command, this hook captures the output
#   - Significant commands (tests, builds, deploys) are logged to files
#   - Claude can later read these logs without copy/paste
#
# LOG LOCATION: logs/claude-commands.log (in project directory)
# =============================================================================

INPUT=$(cat)

# Extract command and result
if command -v jq &> /dev/null; then
    COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
    RESULT=$(echo "$INPUT" | jq -r '.tool_response // empty' | head -c 5000)
    EXIT_CODE=$(echo "$INPUT" | jq -r '.tool_response.exit_code // .exit_code // empty')
else
    exit 0  # Can't process without jq
fi

# Skip if no command
if [ -z "$COMMAND" ]; then
    exit 0
fi

# =============================================================================
# DETERMINE IF COMMAND IS WORTH LOGGING
# =============================================================================

SHOULD_LOG=false
LOG_CATEGORY=""

# Test commands
if echo "$COMMAND" | grep -qE "(npm test|npm run test|vitest|jest|pytest|cargo test)"; then
    SHOULD_LOG=true
    LOG_CATEGORY="test"
fi

# Build commands
if echo "$COMMAND" | grep -qE "(npm run build|vite build|tsc|cargo build|go build)"; then
    SHOULD_LOG=true
    LOG_CATEGORY="build"
fi

# Deploy/CDK commands
if echo "$COMMAND" | grep -qE "(cdk deploy|cdk synth|sam deploy|terraform apply)"; then
    SHOULD_LOG=true
    LOG_CATEGORY="deploy"
fi

# Lint/format commands
if echo "$COMMAND" | grep -qE "(eslint|prettier|black|ruff|pylint)"; then
    SHOULD_LOG=true
    LOG_CATEGORY="lint"
fi

# Docker commands
if echo "$COMMAND" | grep -qE "(docker build|docker-compose up|docker run)"; then
    SHOULD_LOG=true
    LOG_CATEGORY="docker"
fi

# AWS commands that produce useful output
if echo "$COMMAND" | grep -qE "(aws .* describe|aws .* list|aws logs)"; then
    SHOULD_LOG=true
    LOG_CATEGORY="aws"
fi

# Skip if not worth logging
if [ "$SHOULD_LOG" != true ]; then
    exit 0
fi

# =============================================================================
# LOG THE COMMAND AND OUTPUT
# =============================================================================

# Create logs directory if in a project
if [ -d ".git" ] || [ -f "package.json" ] || [ -f "pyproject.toml" ]; then
    LOG_DIR="logs"
    mkdir -p "$LOG_DIR"
    
    LOG_FILE="$LOG_DIR/claude-commands.log"
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    
    {
        echo "════════════════════════════════════════════════════════════════"
        echo "[$TIMESTAMP] Category: $LOG_CATEGORY"
        echo "Command: $COMMAND"
        echo "Exit Code: ${EXIT_CODE:-unknown}"
        echo "────────────────────────────────────────────────────────────────"
        echo "$RESULT"
        echo ""
    } >> "$LOG_FILE"
    
    # Keep log file from growing too large (keep last 1000 lines)
    if [ -f "$LOG_FILE" ] && [ $(wc -l < "$LOG_FILE") -gt 2000 ]; then
        tail -1000 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
    fi
fi

exit 0
