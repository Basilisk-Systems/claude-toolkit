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

# Extract command and result.
# NOTE: tool_response has no exit_code field — derive status from the
# interrupted flag and stdout/stderr instead.
if command -v jq &> /dev/null; then
    COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
    STDOUT=$(echo "$INPUT" | jq -r '.tool_response.stdout // empty' | head -c 5000)
    STDERR=$(echo "$INPUT" | jq -r '.tool_response.stderr // empty' | head -c 2000)
    INTERRUPTED=$(echo "$INPUT" | jq -r '.tool_response.interrupted // false')
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

# Log into ./logs/ only if we're inside a git repo AND logs/ is gitignored
# (so we never pollute a repo with untracked log files). Otherwise write to
# ~/.claude/logs/<project-slug>/.
if git rev-parse --is-inside-work-tree > /dev/null 2>&1 && git check-ignore -q logs 2>/dev/null; then
    LOG_DIR="logs"
else
    PROJECT_SLUG=$(basename "$(pwd)")
    LOG_DIR="$HOME/.claude/logs/$PROJECT_SLUG"
fi
mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/claude-commands.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

{
    echo "════════════════════════════════════════════════════════════════"
    echo "[$TIMESTAMP] Category: $LOG_CATEGORY"
    echo "Command: $COMMAND"
    echo "Interrupted: $INTERRUPTED | stdout: ${#STDOUT} chars | stderr: ${#STDERR} chars"
    echo "────────────────────────────────────────────────────────────────"
    echo "$STDOUT"
    if [ -n "$STDERR" ]; then
        echo "--- stderr ---"
        echo "$STDERR"
    fi
    echo ""
} >> "$LOG_FILE"

# Keep log file from growing too large (keep last 1000 lines)
if [ -f "$LOG_FILE" ] && [ $(wc -l < "$LOG_FILE") -gt 2000 ]; then
    tail -1000 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
fi

exit 0
