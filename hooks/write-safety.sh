#!/bin/bash
# =============================================================================
# WRITE SAFETY HOOK
# =============================================================================
# PURPOSE: Protects sensitive files from modification
# TRIGGER: PreToolUse:Write, PreToolUse:Edit
#
# PROTECTED FILES:
#   - Environment files (.env, .env.*)
#   - Lock files (package-lock.json, yarn.lock, etc.)
#   - Credentials and keys (*.pem, *.key, *_rsa)
#   - Git internals (.git/)
#   - System directories (/etc, /usr, /bin)
#
# NOTE: file_path is usually absolute, so anchored patterns like ^\.env$ are
# tested against the path relative to cwd and the basename as well.
# =============================================================================

INPUT=$(cat)

# jq is required to build valid JSON decisions. Without it, fail open but
# make the degradation visible on stderr.
if ! command -v jq &> /dev/null; then
    echo "write-safety hook: jq not installed — safety checks skipped (fail open). Install with: sudo apt install jq" >&2
    exit 0
fi

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

# If no file path, allow (fail open)
if [ -z "$FILE_PATH" ]; then
    exit 0
fi

# Derive relative path (strip "$CWD/" prefix if present) and basename so
# anchored patterns (^\.env$, ^\.github/, ...) can match absolute paths.
REL_PATH="$FILE_PATH"
if [ -n "$CWD" ]; then
    REL_PATH="${FILE_PATH#"$CWD"/}"
fi
BASE_NAME=$(basename "$FILE_PATH")

# Test a pattern against full path, relative path, and basename
matches() {
    local pattern="$1" flags="$2"
    printf '%s\n%s\n%s\n' "$FILE_PATH" "$REL_PATH" "$BASE_NAME" | grep -q"$flags"E "$pattern"
}

deny() {
    jq -n --arg r "$1" '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$r}}'
    exit 0
}

ask() {
    jq -n --arg r "$1" '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":$r}}'
    exit 0
}

# =============================================================================
# BLOCKED - These files should NEVER be modified by Claude
# =============================================================================
BLOCKED_PATTERNS=(
    # System directories (absolute paths)
    "^/etc/"
    "^/usr/"
    "^/bin/"
    "^/sbin/"
    "^/boot/"
    "^/sys/"
    "^/proc/"

    # Git internals
    "\.git/"
    "\.git$"

    # SSH keys
    "id_rsa"
    "id_ed25519"
    "id_dsa"
    "\.ssh/"

    # GPG keys
    "\.gnupg/"
)

for pattern in "${BLOCKED_PATTERNS[@]}"; do
    if matches "$pattern" ""; then
        deny "🚫 Cannot modify protected system file: $FILE_PATH"
    fi
done

# =============================================================================
# ASK FIRST - These files need confirmation before modification
# =============================================================================
ASK_PATTERNS=(
    # Environment files (often contain secrets)
    "^\.env$"
    "^\.env\."
    "\.env\.local$"
    "\.env\.production$"

    # Credential files
    "\.pem$"
    "\.key$"
    "\.crt$"
    "\.p12$"
    "credentials"
    "secrets"

    # Lock files (shouldn't be manually edited)
    "package-lock\.json$"
    "yarn\.lock$"
    "pnpm-lock\.yaml$"
    "poetry\.lock$"
    "Pipfile\.lock$"
    "Cargo\.lock$"
    "composer\.lock$"

    # CI/CD configuration (can break pipelines)
    "^\.github/"
    "^\.gitlab-ci"
    "^\.circleci/"
    "buildspec\.yml$"
    "Jenkinsfile$"

    # Docker production configs
    "docker-compose\.prod"
    "Dockerfile\.prod"

    # CDK context (deployment state)
    "cdk\.context\.json$"

    # AWS configs
    "samconfig\.toml$"
    "template\.yaml$"
)

for pattern in "${ASK_PATTERNS[@]}"; do
    if matches "$pattern" "i"; then
        ask "⚠️ This is a sensitive file that may affect deployments or security: $FILE_PATH"
    fi
done

# =============================================================================
# ALLOW - File passed all checks
# =============================================================================
exit 0
