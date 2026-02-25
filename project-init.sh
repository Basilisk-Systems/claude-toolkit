#!/usr/bin/env bash
set -euo pipefail

# Claude Toolkit — Project Init
# Sets up .claude-local/ directory with template files in any repo.
# Usage: ./project-init.sh [project-path]
#   project-path defaults to current directory

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="${SCRIPT_DIR}/templates/claude-local"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Resolve target directory
TARGET_DIR="${1:-.}"
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
LOCAL_DIR="${TARGET_DIR}/.claude-local"

# Check if already initialized
if [[ -d "$LOCAL_DIR" ]] && [[ "$(ls -A "$LOCAL_DIR" 2>/dev/null)" ]]; then
    echo -e "${YELLOW}.claude-local/ already exists in ${TARGET_DIR}${NC}"
    echo "Contents:"
    ls -1 "$LOCAL_DIR"
    exit 0
fi

# Create directory
mkdir -p "$LOCAL_DIR"

# Copy templates (skip existing)
CREATED=()
for template in "${TEMPLATES_DIR}"/*.md; do
    name="$(basename "$template")"
    target="${LOCAL_DIR}/${name}"
    if [[ ! -e "$target" ]]; then
        cp "$template" "$target"
        CREATED+=("$name")
    fi
done

# Update .gitignore
GITIGNORE="${TARGET_DIR}/.gitignore"
if [[ -f "$GITIGNORE" ]]; then
    if ! grep -q '\.claude-local' "$GITIGNORE" 2>/dev/null; then
        echo "" >> "$GITIGNORE"
        echo "# Claude Code local files (personal, not committed)" >> "$GITIGNORE"
        echo ".claude-local/" >> "$GITIGNORE"
    fi
else
    cat > "$GITIGNORE" <<'EOF'
# Claude Code local files (personal, not committed)
.claude-local/
EOF
fi

# Summary
echo -e "${GREEN}✅ .claude-local/ initialized in ${TARGET_DIR}${NC}"
echo ""
echo "Created:"
for f in "${CREATED[@]}"; do
    case "$f" in
        STANDUP.md)          echo "  - STANDUP.md          — Work tracking for standups" ;;
        NOTES.md)            echo "  - NOTES.md            — Personal debugging notes" ;;
        TODO.md)             echo "  - TODO.md             — Personal task ideas" ;;
        HANDOFF.md)          echo "  - HANDOFF.md          — Session context for continuity" ;;
        IMPLEMENT_STATE.md)  echo "  - IMPLEMENT_STATE.md  — Phase tracking for /implement" ;;
        *)                   echo "  - ${f}" ;;
    esac
done
echo ""
echo "Run /standup in Claude Code to start tracking your work session."
