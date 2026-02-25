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
# =============================================================================

INPUT=$(cat)

# Extract file path
if command -v jq &> /dev/null; then
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
else
    FILE_PATH=$(echo "$INPUT" | grep -oP '"file_path"\s*:\s*"\K[^"]+')
fi

# If no file path, allow (fail open)
if [ -z "$FILE_PATH" ]; then
    exit 0
fi

# =============================================================================
# BLOCKED - These files should NEVER be modified by Claude
# =============================================================================
BLOCKED_PATTERNS=(
    # System directories (absolute paths starting with //)
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
    if echo "$FILE_PATH" | grep -qE "$pattern"; then
        echo "{\"decision\": \"block\", \"reason\": \"🚫 Cannot modify protected system file: $FILE_PATH\"}"
        exit 0
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
    if echo "$FILE_PATH" | grep -qiE "$pattern"; then
        echo "{\"decision\": \"ask\", \"reason\": \"⚠️ This is a sensitive file that may affect deployments or security: $FILE_PATH\"}"
        exit 0
    fi
done

# =============================================================================
# ALLOW - File passed all checks
# =============================================================================
exit 0
