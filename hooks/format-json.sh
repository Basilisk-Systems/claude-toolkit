#!/bin/bash
# =============================================================================
# JSON FORMATTER HOOK
# =============================================================================
# PURPOSE: Auto-format JSON files after Write/Edit
# TRIGGER: PostToolUse:Write(*.json), PostToolUse:Edit(*.json)
#
# SKIP LIST:
#   - package-lock.json (too large, auto-generated)
#   - node_modules/ (shouldn't be editing these anyway)
# =============================================================================

INPUT=$(cat)

# Extract file path
if command -v jq &> /dev/null; then
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
else
    FILE_PATH=$(echo "$INPUT" | grep -oP '"file_path"\s*:\s*"\K[^"]+')
fi

# Skip if no file path
if [ -z "$FILE_PATH" ]; then
    exit 0
fi

# Skip if not a JSON file (settings matcher is plain "Write|Edit",
# so this hook fires for every write — bail out early)
if [[ ! "$FILE_PATH" =~ \.json$ ]]; then
    exit 0
fi

# Skip if file doesn't exist
if [ ! -f "$FILE_PATH" ]; then
    exit 0
fi

# Skip lock files and node_modules
if [[ "$FILE_PATH" =~ package-lock\.json$ ]] || \
   [[ "$FILE_PATH" =~ node_modules/ ]] || \
   [[ "$FILE_PATH" =~ yarn\.lock$ ]] || \
   [[ "$FILE_PATH" =~ pnpm-lock\.yaml$ ]]; then
    exit 0
fi

# Skip known JSONC files (comments/trailing commas would be mangled or fail)
if [[ "$FILE_PATH" =~ tsconfig[^/]*\.json$ ]] || \
   [[ "$FILE_PATH" =~ \.vscode/ ]] || \
   [[ "$FILE_PATH" =~ devcontainer\.json$ ]]; then
    exit 0
fi

# =============================================================================
# RUN FORMATTER
# =============================================================================

# Try prettier first (handles JSON well), fall back to jq
if command -v prettier &> /dev/null; then
    prettier --write "$FILE_PATH" 2>&1
elif [ -f "./node_modules/.bin/prettier" ]; then
    ./node_modules/.bin/prettier --write "$FILE_PATH" 2>&1
elif command -v jq &> /dev/null; then
    # Use jq to format (creates temp file to avoid issues).
    # cp over the original (instead of mv) preserves the file's owner,
    # permissions, and inode — mktemp files are 0600.
    TEMP_FILE=$(mktemp)
    if jq '.' "$FILE_PATH" > "$TEMP_FILE" 2>/dev/null; then
        cp "$TEMP_FILE" "$FILE_PATH"
        rm -f "$TEMP_FILE"
    else
        rm -f "$TEMP_FILE"
        echo "⚠️ JSON formatting failed (invalid JSON?): $FILE_PATH" >&2
    fi
else
    # No formatter available, skip silently
    :
fi

exit 0
