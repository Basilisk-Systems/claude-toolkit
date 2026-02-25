#!/bin/bash
# =============================================================================
# CHANGELOG VALIDATION HOOK
# =============================================================================
# PURPOSE: Validate CHANGELOG.md entries before writing
# TRIGGER: PreToolUse:Write(CHANGELOG.md), PreToolUse:Edit(CHANGELOG.md)
#
# CHECKS:
#   - Date format is correct (YYYY-MM-DD)
#   - Date is reasonable (not in the future, not too old)
#   - Warns if date doesn't match today
#
# OUTPUT:
#   - Allows write but adds context if date seems wrong
#   - Blocks if date format is invalid
# =============================================================================

INPUT=$(cat)

# Extract file path and content
if command -v jq &> /dev/null; then
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
    CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // .tool_input.new_string // empty')
else
    exit 0  # Can't validate without jq
fi

# Only check CHANGELOG files
if [[ ! "$FILE_PATH" =~ CHANGELOG\.md$ ]] && [[ ! "$FILE_PATH" =~ CHANGELOG$ ]]; then
    exit 0
fi

# Get current date
CURRENT_DATE=$(date +%Y-%m-%d)
CURRENT_YEAR=$(date +%Y)

# Extract dates from the content being written
# Looking for patterns like: ## [1.2.3] - 2026-01-06
DATES_IN_CONTENT=$(echo "$CONTENT" | grep -oP '\d{4}-\d{2}-\d{2}' | head -5)

if [ -z "$DATES_IN_CONTENT" ]; then
    # No dates found, probably just adding content to existing entry
    exit 0
fi

# Check each date found
WARNINGS=""
for DATE in $DATES_IN_CONTENT; do
    # Validate format (basic check - YYYY-MM-DD)
    if ! echo "$DATE" | grep -qP '^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$'; then
        echo "{\"decision\": \"block\", \"reason\": \"Invalid date format: $DATE. Use YYYY-MM-DD format.\"}"
        exit 0
    fi
    
    # Extract year
    YEAR=$(echo "$DATE" | cut -d'-' -f1)
    
    # Check if date is in the future
    if [[ "$DATE" > "$CURRENT_DATE" ]]; then
        WARNINGS="${WARNINGS}Date $DATE is in the future. Today is $CURRENT_DATE. "
    fi
    
    # Check if year is reasonable (not too old, not future)
    if [ "$YEAR" -lt 2020 ]; then
        WARNINGS="${WARNINGS}Date $DATE seems too old. "
    fi
    
    if [ "$YEAR" -gt "$CURRENT_YEAR" ]; then
        WARNINGS="${WARNINGS}Year $YEAR is in the future. Current year is $CURRENT_YEAR. "
    fi
    
    # Check if date is significantly in the past (more than 30 days)
    if command -v date &> /dev/null; then
        DAYS_AGO=$(( ($(date +%s) - $(date -d "$DATE" +%s 2>/dev/null || echo 0)) / 86400 ))
        if [ "$DAYS_AGO" -gt 30 ] 2>/dev/null; then
            WARNINGS="${WARNINGS}Date $DATE is $DAYS_AGO days ago. Did you mean $CURRENT_DATE? "
        fi
    fi
done

# If there are warnings, ask for confirmation
if [ -n "$WARNINGS" ]; then
    echo "{\"decision\": \"ask\", \"reason\": \"⚠️ CHANGELOG date check: ${WARNINGS}Confirm this is intentional, or update to use today's date ($CURRENT_DATE).\"}"
    exit 0
fi

# All checks passed
exit 0
