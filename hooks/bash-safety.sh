#!/bin/bash
# =============================================================================
# BASH SAFETY HOOK
# =============================================================================
# PURPOSE: Intercepts Bash tool calls and blocks dangerous commands
# TRIGGER: PreToolUse:Bash
# 
# HOW IT WORKS:
# 1. Claude Code pipes tool input as JSON to stdin
# 2. We extract the command being run
# 3. We check against dangerous patterns
# 4. Output JSON to block/ask, or exit 0 to allow
#
# OUTPUT OPTIONS:
#   exit 0                                    → Allow command
#   exit 2                                    → Block command (simple)
#   echo '{"decision": "block", "reason": "..."}' → Block with message
#   echo '{"decision": "ask", "reason": "..."}'   → Ask user for confirmation
# =============================================================================

# Read the tool input from stdin
INPUT=$(cat)

# Extract the command using jq (install: sudo apt install jq)
# Fallback to grep if jq not available
if command -v jq &> /dev/null; then
    COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
else
    COMMAND=$(echo "$INPUT" | grep -oP '"command"\s*:\s*"\K[^"]+')
fi

# If we couldn't extract a command, allow it (fail open for safety)
if [ -z "$COMMAND" ]; then
    exit 0
fi

# =============================================================================
# DANGEROUS PATTERNS - These are BLOCKED immediately
# =============================================================================
DANGEROUS_PATTERNS=(
    # Destructive file operations
    "rm -rf /"
    "rm -rf ~"
    "rm -rf \$HOME"
    "rm -rf \*"
    "rm -rf \."

    # System damage
    "> /dev/sd"
    "mkfs"
    "dd if="
    ":(){:|:&};:"  # Fork bomb

    # Permission disasters
    "chmod -R 777 /"
    "chmod 777 /"
    "chown -R.*/"

    # Remote code execution (piping downloaded content to shell)
    "curl.*\| *bash"
    "curl.*\| *sh"
    "wget.*\| *bash"
    "wget.*\| *sh"
    "curl.*\|bash"
    "wget.*\|sh"

    # Git dangers
    "git push.*--force"
    "git push.*-f "
    "git reset --hard origin"

    # Database dangers
    "DROP TABLE"
    "DROP DATABASE"
    "DELETE FROM.*WHERE 1"
    "TRUNCATE TABLE"

    # Package publishing (accidental)
    "npm publish"
    "pip upload"
    "twine upload"

    # Environment variable leaks
    "printenv.*SECRET"
    "printenv.*KEY"
    "printenv.*PASSWORD"
    "echo \$.*SECRET"
    "echo \$.*KEY"
    "echo \$.*PASSWORD"
)

# Check each dangerous pattern
for pattern in "${DANGEROUS_PATTERNS[@]}"; do
    if echo "$COMMAND" | grep -qiE "$pattern"; then
        echo "{\"decision\": \"block\", \"reason\": \"🚫 Blocked dangerous command pattern: $pattern\"}"
        exit 0
    fi
done

# =============================================================================
# RESTRICTED PATTERNS - Require detailed justification and single-use approval
# =============================================================================
# These patterns are not inherently dangerous but could be misused to modify
# safety configurations or hook files.
#
# Claude must explain: WHAT, WHY, and EFFECTS before user can approve.
# Each approval is for ONE command only - no blanket permissions.
# Compound commands with these patterns are blocked entirely.

RESTRICTED_PATTERNS=(
    # Shell script operations (prevents hook tampering)
    "\.sh"
)

for pattern in "${RESTRICTED_PATTERNS[@]}"; do
    if echo "$COMMAND" | grep -qiE "$pattern"; then
        # Block compound commands with restricted patterns - force single command approval
        if echo "$COMMAND" | grep -qE "(&&|\|\||;)"; then
            echo "{\"decision\": \"block\", \"reason\": \"🚫 Compound commands with restricted patterns not allowed.\\n\\nYour command contains '$pattern' AND multiple chained commands.\\nRun each command separately for individual approval.\\n\\nThis ensures each action is reviewed independently.\"}"
            exit 0
        fi

        # Single command - require justification and approval
        echo "{\"decision\": \"ask\", \"reason\": \"⚠️ RESTRICTED COMMAND DETECTED\\n\\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\\nThis command involves shell script files which could\\nmodify safety configurations or hooks.\\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\\n\\nBefore approving, Claude MUST have explained:\\n\\n1. WHAT: Exactly what this command does\\n2. WHY: The reason this action is needed\\n3. EFFECTS: What changes will result\\n\\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\\nThis approval is for THIS COMMAND ONLY.\\nFuture attempts require new approval.\\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\\n\\nAllow this single command?\"}"
        exit 0
    fi
done

# =============================================================================
# CAUTION PATTERNS - These require user confirmation
# =============================================================================
CAUTION_PATTERNS=(
    # Any rm with force or recursive
    "rm -[rf]"
    "rm .*-[rf]"

    # Git operations that modify history
    "git rebase"
    "git reset"
    "git checkout.*--"
    "git clean"

    # System service operations  
    "systemctl"
    "service "

    # Network operations
    "curl -X (POST|PUT|DELETE)"
    "wget --post"

    # AWS destructive operations
    "aws.*delete"
    "aws.*destroy"
    "cdk destroy"

    # Docker cleanup
    "docker.*prune"
    "docker rm"
    "docker rmi"
)

for pattern in "${CAUTION_PATTERNS[@]}"; do
    if echo "$COMMAND" | grep -qiE "$pattern"; then
        echo "{\"decision\": \"ask\", \"reason\": \"⚠️ This command may have significant effects: $pattern\"}"
        exit 0
    fi
done

# =============================================================================
# ALLOW - Command passed all checks
# =============================================================================
exit 0
