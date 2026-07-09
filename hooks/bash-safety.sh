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
# 4. Output a PreToolUse permission decision (JSON) or exit 0 to allow
#
# OUTPUT (stdout must be ONLY valid JSON):
#   exit 0, no output → Allow command
#   {"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"..."}}
#   {"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"..."}}
# =============================================================================

INPUT=$(cat)

# jq is required to build valid JSON decisions (regex patterns in reasons
# contain backslashes that break hand-built JSON). Without jq, fail open but
# make the degradation visible on stderr.
if ! command -v jq &> /dev/null; then
    echo "bash-safety hook: jq not installed — safety checks skipped (fail open). Install with: sudo apt install jq" >&2
    exit 0
fi

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# If we couldn't extract a command, allow it (fail open for safety)
if [ -z "$COMMAND" ]; then
    exit 0
fi

# Emit a permission decision. JSON is built with jq --arg so reasons
# containing backslashes/quotes can never produce invalid JSON.
deny() {
    jq -n --arg r "$1" '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$r}}'
    exit 0
}

ask() {
    jq -n --arg r "$1" '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":$r}}'
    exit 0
}

# =============================================================================
# DANGEROUS PATTERNS - These are BLOCKED immediately
# =============================================================================
DANGEROUS_PATTERNS=(
    # Destructive file operations
    'rm -rf /'
    'rm -rf ~'
    'rm -rf \$HOME'
    'rm -rf \*'
    # "rm -rf ." only when bare (end of string or followed by whitespace);
    # does NOT match relative paths like "rm -rf ./build"
    'rm -rf \.([[:space:]]|$)'

    # System damage
    '> /dev/sd'
    'mkfs'
    # dd is only dangerous when writing to a block device
    'dd[[:space:]].*of=/dev/'
    ':\(\)\{:\|:&\};:'  # Fork bomb

    # Permission disasters
    'chmod -R 777 /'
    'chmod 777 /'
    'chown -R.*/'

    # Remote code execution (piping downloaded content to shell)
    'curl.*\|[[:space:]]*bash'
    'curl.*\|[[:space:]]*sh'
    'wget.*\|[[:space:]]*bash'
    'wget.*\|[[:space:]]*sh'

    # Git dangers (-f/--force must be a standalone flag, incl. end of string)
    'git push.*[[:space:]](--force|-f)([[:space:]]|$)'
    'git reset --hard origin'

    # Package publishing (accidental)
    'npm publish'
    'pip upload'
    'twine upload'

    # Environment variable leaks. KEY/SECRET/TOKEN/PASSWORD must appear as a
    # distinct underscore-delimited word in the variable name, so
    # "echo $monkey" does not match but "echo $API_KEY" does.
    'printenv.*\b(SECRET|KEY|TOKEN|PASSWORD)'
    'echo .*\$\{?([A-Za-z0-9]+_)*(SECRET|KEY|TOKEN|PASSWORD)(_[A-Za-z0-9]+)*\b'
)

for pattern in "${DANGEROUS_PATTERNS[@]}"; do
    if echo "$COMMAND" | grep -qiE "$pattern"; then
        deny "🚫 Blocked dangerous command pattern: $pattern"
    fi
done

# =============================================================================
# DANGEROUS SQL PATTERNS - checked against the command with quoted commit
# messages (-m "...") and heredoc bodies stripped, so mentioning DROP TABLE
# in a commit message or heredoc does not trigger a block.
# =============================================================================
SQL_PATTERNS=(
    '\bDROP[[:space:]]+TABLE\b'
    '\bDROP[[:space:]]+DATABASE\b'
    '\bDELETE[[:space:]]+FROM.*WHERE[[:space:]]+1'
    '\bTRUNCATE[[:space:]]+TABLE\b'
)

SQL_CHECK=$(printf '%s\n' "$COMMAND" \
    | sed -E 's/-m[[:space:]]+"[^"]*"//g' \
    | sed -E "s/-m[[:space:]]+'[^']*'//g" \
    | sed -E "/<<-?['\"]?[A-Za-z_]+/,\$d")

for pattern in "${SQL_PATTERNS[@]}"; do
    if [ -n "$SQL_CHECK" ] && echo "$SQL_CHECK" | grep -qiE "$pattern"; then
        deny "🚫 Blocked dangerous command pattern: $pattern"
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
    # Shell script EXECUTION only (prevents hook tampering). Matches a .sh
    # file at a command position: start of command or after && || ; |,
    # optionally via an interpreter (bash x.sh, sh x.sh, source x.sh, . x.sh,
    # ./x.sh). Merely mentioning a .sh path as an argument does not match.
    '(^|&&|\|\||;|\|)[[:space:]]*((bash|sh|source|\.)[[:space:]]+)?[^[:space:];&|]*\.sh([[:space:]]|;|\||&|$)'
)

for pattern in "${RESTRICTED_PATTERNS[@]}"; do
    if echo "$COMMAND" | grep -qiE "$pattern"; then
        # Block compound commands with restricted patterns - force single command approval
        if echo "$COMMAND" | grep -qE "(&&|\|\||;)"; then
            deny "🚫 Compound commands with restricted patterns not allowed.

Your command executes a shell script AND chains multiple commands.
Run each command separately for individual approval.

This ensures each action is reviewed independently."
        fi

        # Single command - require justification and approval
        ask "⚠️ RESTRICTED COMMAND DETECTED

This command executes a shell script, which could modify safety
configurations or hooks.

Before approving, Claude MUST have explained:

1. WHAT: Exactly what this command does
2. WHY: The reason this action is needed
3. EFFECTS: What changes will result

This approval is for THIS COMMAND ONLY.
Future attempts require new approval.

Allow this single command?"
    fi
done

# =============================================================================
# CAUTION PATTERNS - These require user confirmation
# =============================================================================
CAUTION_PATTERNS=(
    # Any rm with force or recursive
    'rm -[rf]'
    'rm .*-[rf]'

    # Git operations that modify history
    'git rebase'
    'git reset'
    'git checkout.*--'
    'git clean'

    # System service operations
    'systemctl'
    'service '

    # Network operations
    'curl -X (POST|PUT|DELETE)'
    'wget --post'

    # AWS destructive operations
    'aws.*delete'
    'aws.*destroy'
    'cdk destroy'

    # Docker cleanup
    'docker.*prune'
    'docker rm'
    'docker rmi'
)

for pattern in "${CAUTION_PATTERNS[@]}"; do
    if echo "$COMMAND" | grep -qiE "$pattern"; then
        ask "⚠️ This command may have significant effects: $pattern"
    fi
done

# =============================================================================
# ALLOW - Command passed all checks
# =============================================================================
exit 0
