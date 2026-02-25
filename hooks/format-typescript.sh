#!/bin/bash
# =============================================================================
# TYPESCRIPT/JAVASCRIPT FORMATTER HOOK
# =============================================================================
# PURPOSE: Auto-format TS/JS files with Prettier after Write/Edit
# TRIGGER: PostToolUse:Write(*.ts,*.tsx,*.js,*.jsx), PostToolUse:Edit(*.ts,*.tsx,*.js,*.jsx)
#
# REQUIREMENTS:
#   npm install -g prettier
#   OR have prettier in project devDependencies
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

# Skip if not a TS/JS file (double-check)
if [[ ! "$FILE_PATH" =~ \.(ts|tsx|js|jsx)$ ]]; then
    exit 0
fi

# Skip if file doesn't exist
if [ ! -f "$FILE_PATH" ]; then
    exit 0
fi

# =============================================================================
# RUN PRETTIER
# =============================================================================

# Try different prettier locations
if command -v prettier &> /dev/null; then
    FORMATTER="prettier"
elif [ -f "./node_modules/.bin/prettier" ]; then
    FORMATTER="./node_modules/.bin/prettier"
elif command -v npx &> /dev/null; then
    FORMATTER="npx prettier"
else
    echo "⚠️ Prettier not found. Run: npm install -g prettier" >&2
    exit 0
fi

# Run prettier with write mode
$FORMATTER --write "$FILE_PATH" 2>&1

if [ $? -eq 0 ]; then
    :  # Silent success
else
    echo "⚠️ Prettier formatting failed for: $FILE_PATH" >&2
fi

# =============================================================================
# OPTIONAL: Run TypeScript type check (uncomment to enable)
# =============================================================================
# if [[ "$FILE_PATH" =~ \.(ts|tsx)$ ]]; then
#     if [ -f "./node_modules/.bin/tsc" ]; then
#         ./node_modules/.bin/tsc --noEmit "$FILE_PATH" 2>&1 | head -20
#     fi
# fi

exit 0
