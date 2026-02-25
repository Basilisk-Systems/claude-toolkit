#!/usr/bin/env bash
set -euo pipefail

# Claude Toolkit Uninstaller
# Removes only symlinks that point back to this toolkit

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${HOME}/.claude"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

REMOVED=0

# Remove symlinks in a directory that point to our toolkit
remove_toolkit_symlinks() {
    local dir="$1"
    [[ -d "$dir" ]] || return 0

    for item in "$dir"/*; do
        [[ -L "$item" ]] || continue
        local target
        target="$(readlink -f "$item" 2>/dev/null || readlink "$item")"
        if [[ "$target" == "${SCRIPT_DIR}"* ]]; then
            echo -e "  ${RED}[remove]${NC} ${item} → ${target}"
            rm "$item"
            ((REMOVED++)) || true
        fi
    done
}

echo -e "${GREEN}Claude Toolkit Uninstaller${NC}"
echo "Toolkit: ${SCRIPT_DIR}"
echo "Scanning: ${CLAUDE_DIR}"
echo ""

# Commands
echo "Checking commands..."
remove_toolkit_symlinks "${CLAUDE_DIR}/commands"

# Skills (directory symlinks)
echo "Checking skills..."
remove_toolkit_symlinks "${CLAUDE_DIR}/skills"

# Hooks
echo "Checking hooks..."
remove_toolkit_symlinks "${CLAUDE_DIR}/hooks"

# Config (only symlinked files, not copied ones)
echo "Checking config..."
for config_file in "${CLAUDE_DIR}/CLAUDE.md" "${CLAUDE_DIR}/settings.json" "${CLAUDE_DIR}/CONTEXT_WEIGHTS.md"; do
    if [[ -L "$config_file" ]]; then
        local_target="$(readlink -f "$config_file" 2>/dev/null || readlink "$config_file")"
        if [[ "$local_target" == "${SCRIPT_DIR}"* ]]; then
            echo -e "  ${RED}[remove]${NC} ${config_file}"
            rm "$config_file"
            ((REMOVED++)) || true
        fi
    fi
done

echo ""
if [[ $REMOVED -gt 0 ]]; then
    echo -e "${GREEN}Removed ${REMOVED} symlink(s).${NC}"
else
    echo -e "${YELLOW}No toolkit symlinks found.${NC}"
fi
echo -e "Copied files (CLAUDE.md, settings.json) were ${YELLOW}not touched${NC}."
echo ""
echo "To reinstall: ./install.sh [options]"
