#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Claude Toolkit Installer
# =============================================================================
# Selectively installs commands, skills, hooks, and config into ~/.claude/
# Tracks installs via manifest, backs up config files before overwrite.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${HOME}/.claude"
MANIFEST="${CLAUDE_DIR}/.toolkit-manifest.json"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

# Flags
INSTALL_WORKFLOW=false
INSTALL_SKILLS=false
INSTALL_HOOKS=false
INSTALL_CONFIG=false
FORCE=false
DRY_RUN=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
DIM='\033[2m'
NC='\033[0m'

# Counters
INSTALLED=0
UPDATED=0
SKIPPED=0
BACKED_UP=0

# Tracking arrays for summary
declare -a ITEMS_INSTALLED=()
declare -a ITEMS_UPDATED=()
declare -a ITEMS_SKIPPED=()
declare -a ITEMS_BACKED_UP=()

# Manifest entries (file → json object)
declare -a MANIFEST_ENTRIES=()

usage() {
    cat <<'EOF'
Claude Toolkit Installer

Usage: ./install.sh [options]

Options:
  (no flags)        Install core only (implement + init-claude-local)
  --with-workflow   Also install workflow commands (handoff, commit, etc.)
  --with-skills     Also install knowledge skills
  --with-hooks      Also install global hooks
  --with-config     Also install CLAUDE.md/settings.json templates
  --all             Install everything
  --force           Overwrite existing files (backs up config first)
  --dry-run         Show what would be done without doing it
  --uninstall       Remove toolkit symlinks (alias for uninstall.sh)
  --help            Show this help message

Safety:
  - Existing non-toolkit files are NEVER overwritten without --force
  - Config files (CLAUDE.md, settings.json) are backed up before --force overwrite
  - A manifest at ~/.claude/.toolkit-manifest.json tracks what was installed
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --with-workflow) INSTALL_WORKFLOW=true ;;
        --with-skills)   INSTALL_SKILLS=true ;;
        --with-hooks)    INSTALL_HOOKS=true ;;
        --with-config)   INSTALL_CONFIG=true ;;
        --all)
            INSTALL_WORKFLOW=true
            INSTALL_SKILLS=true
            INSTALL_HOOKS=true
            INSTALL_CONFIG=true
            ;;
        --force)    FORCE=true ;;
        --dry-run)  DRY_RUN=true ;;
        --uninstall)
            exec "${SCRIPT_DIR}/uninstall.sh"
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            exit 1
            ;;
    esac
    shift
done

# =============================================================================
# Helper: shorten path for display
# =============================================================================
short_path() {
    local p="$1"
    echo "${p/#$HOME/~}"
}

# =============================================================================
# Symlink a single file or directory
# =============================================================================
symlink_file() {
    local source="$1"
    local target="$2"
    local group="$3"
    local target_dir
    target_dir="$(dirname "$target")"
    local display_target
    display_target="$(short_path "$target")"
    local display_name
    display_name="$(basename "$target")"

    if [[ "$DRY_RUN" == true ]]; then
        if [[ -L "$target" ]]; then
            echo -e "    ${BLUE}[update]${NC}  ${display_name} ${DIM}(refresh symlink)${NC}"
        elif [[ -e "$target" ]]; then
            if [[ "$FORCE" == true ]]; then
                echo -e "    ${YELLOW}[force]${NC}   ${display_name} ${DIM}(would replace existing file)${NC}"
            else
                echo -e "    ${YELLOW}[skip]${NC}    ${display_name} ${DIM}(exists, use --force)${NC}"
            fi
        else
            echo -e "    ${GREEN}[new]${NC}     ${display_name}"
        fi
        ((INSTALLED++)) || true
        return
    fi

    mkdir -p "$target_dir"

    if [[ -e "$target" || -L "$target" ]]; then
        if [[ -L "$target" ]]; then
            # Existing symlink — refresh it
            rm "$target"
            ln -s "$source" "$target"
            echo -e "    ${CYAN}[update]${NC}  ${display_name}"
            ((UPDATED++)) || true
            ITEMS_UPDATED+=("$display_target")
        elif [[ "$FORCE" == true ]]; then
            # Existing regular file/dir + --force — overwrite
            rm -rf "$target"
            ln -s "$source" "$target"
            echo -e "    ${YELLOW}[force]${NC}   ${display_name} ${DIM}(replaced existing)${NC}"
            ((UPDATED++)) || true
            ITEMS_UPDATED+=("$display_target")
        else
            echo -e "    ${YELLOW}[skip]${NC}    ${display_name} ${DIM}(exists, use --force)${NC}"
            ((SKIPPED++)) || true
            ITEMS_SKIPPED+=("$display_target")
            return
        fi
    else
        ln -s "$source" "$target"
        echo -e "    ${GREEN}[new]${NC}     ${display_name}"
        ((INSTALLED++)) || true
        ITEMS_INSTALLED+=("$display_target")
    fi

    # Record in manifest
    MANIFEST_ENTRIES+=("{\"target\":\"${target}\",\"source\":\"${source}\",\"type\":\"symlink\",\"group\":\"${group}\"}")
}

# =============================================================================
# Copy a config file (with backup support)
# =============================================================================
copy_config() {
    local source="$1"
    local target="$2"
    local group="$3"
    local target_dir
    target_dir="$(dirname "$target")"
    local display_target
    display_target="$(short_path "$target")"
    local display_name
    display_name="$(basename "$target")"

    if [[ "$DRY_RUN" == true ]]; then
        if [[ -e "$target" && ! -L "$target" ]]; then
            if [[ "$FORCE" == true ]]; then
                echo -e "    ${YELLOW}[backup]${NC}  ${display_name} → ${display_name}.bak.${TIMESTAMP}"
                echo -e "    ${YELLOW}[force]${NC}   ${display_name} ${DIM}(would replace with template)${NC}"
            else
                echo -e "    ${YELLOW}[skip]${NC}    ${display_name} ${DIM}(customized, use --force to replace)${NC}"
            fi
        elif [[ -L "$target" ]]; then
            echo -e "    ${CYAN}[update]${NC}  ${display_name} ${DIM}(replace symlink with copy)${NC}"
        else
            echo -e "    ${GREEN}[new]${NC}     ${display_name}"
        fi
        ((INSTALLED++)) || true
        return
    fi

    mkdir -p "$target_dir"

    if [[ -e "$target" && ! -L "$target" ]]; then
        if [[ "$FORCE" == true ]]; then
            # Back up existing config before overwriting
            local backup="${target}.bak.${TIMESTAMP}"
            cp "$target" "$backup"
            echo -e "    ${YELLOW}[backup]${NC}  ${display_name} → $(basename "$backup")"
            ((BACKED_UP++)) || true
            ITEMS_BACKED_UP+=("$display_target → $(short_path "$backup")")

            rm "$target"
            cp "$source" "$target"
            echo -e "    ${YELLOW}[force]${NC}   ${display_name} ${DIM}(replaced with template)${NC}"
            ((UPDATED++)) || true
            ITEMS_UPDATED+=("$display_target")
        else
            echo -e "    ${YELLOW}[skip]${NC}    ${display_name} ${DIM}(customized, use --force to replace)${NC}"
            ((SKIPPED++)) || true
            ITEMS_SKIPPED+=("$display_target")
            return
        fi
    elif [[ -L "$target" ]]; then
        # Replace symlink with a real copy
        rm "$target"
        cp "$source" "$target"
        echo -e "    ${CYAN}[update]${NC}  ${display_name} ${DIM}(symlink → copy)${NC}"
        ((UPDATED++)) || true
        ITEMS_UPDATED+=("$display_target")
    else
        cp "$source" "$target"
        echo -e "    ${GREEN}[new]${NC}     ${display_name}"
        ((INSTALLED++)) || true
        ITEMS_INSTALLED+=("$display_target")
    fi

    MANIFEST_ENTRIES+=("{\"target\":\"${target}\",\"source\":\"${source}\",\"type\":\"copy\",\"group\":\"${group}\"}")
}

# =============================================================================
# Header
# =============================================================================
echo ""
echo -e "${GREEN}Claude Toolkit Installer${NC}"
echo -e "  Source: ${DIM}${SCRIPT_DIR}${NC}"
echo -e "  Target: ${DIM}${CLAUDE_DIR}${NC}"
if [[ "$FORCE" == true ]]; then
    echo -e "  Mode:   ${YELLOW}--force${NC} (will overwrite, config files backed up)"
fi
if [[ "$DRY_RUN" == true ]]; then
    echo -e "  Mode:   ${BLUE}--dry-run${NC} (no changes will be made)"
fi
echo ""

# =============================================================================
# Core (always)
# =============================================================================
echo -e "${GREEN}[core]${NC} Commands"
for cmd in "${SCRIPT_DIR}"/core/commands/*.md; do
    name="$(basename "$cmd")"
    symlink_file "$cmd" "${CLAUDE_DIR}/commands/${name}" "core"
done

# =============================================================================
# Workflow
# =============================================================================
if [[ "$INSTALL_WORKFLOW" == true ]]; then
    echo -e "${GREEN}[workflow]${NC} Commands"
    for cmd in "${SCRIPT_DIR}"/workflow/commands/*.md; do
        name="$(basename "$cmd")"
        symlink_file "$cmd" "${CLAUDE_DIR}/commands/${name}" "workflow"
    done
fi

# =============================================================================
# Skills
# =============================================================================
if [[ "$INSTALL_SKILLS" == true ]]; then
    echo -e "${GREEN}[skills]${NC} Knowledge files"
    for skill_dir in "${SCRIPT_DIR}"/skills/*/; do
        name="$(basename "$skill_dir")"
        symlink_file "${skill_dir%/}" "${CLAUDE_DIR}/skills/${name}" "skills"
    done
fi

# =============================================================================
# Hooks
# =============================================================================
if [[ "$INSTALL_HOOKS" == true ]]; then
    echo -e "${GREEN}[hooks]${NC} Shell hooks"
    for hook in "${SCRIPT_DIR}"/hooks/*.sh; do
        name="$(basename "$hook")"
        chmod +x "$hook"
        symlink_file "$hook" "${CLAUDE_DIR}/hooks/${name}" "hooks"
    done
fi

# =============================================================================
# Bin (CLI tools — installed with workflow)
# =============================================================================
if [[ "$INSTALL_WORKFLOW" == true ]]; then
    echo -e "${GREEN}[bin]${NC} CLI tools"
    mkdir -p "${CLAUDE_DIR}/bin"
    for script in "${SCRIPT_DIR}"/bin/*; do
        name="$(basename "$script")"
        chmod +x "$script"
        symlink_file "$script" "${CLAUDE_DIR}/bin/${name}" "bin"
    done
fi

# =============================================================================
# Config
# =============================================================================
if [[ "$INSTALL_CONFIG" == true ]]; then
    echo -e "${GREEN}[config]${NC} Configuration files"
    copy_config "${SCRIPT_DIR}/config/CLAUDE.md" "${CLAUDE_DIR}/CLAUDE.md" "config"
    copy_config "${SCRIPT_DIR}/config/settings.json" "${CLAUDE_DIR}/settings.json" "config"
    symlink_file "${SCRIPT_DIR}/config/CONTEXT_WEIGHTS.md" "${CLAUDE_DIR}/CONTEXT_WEIGHTS.md" "config"

    # Append conditional snippets to CLAUDE.md based on installed components
    if [[ "$DRY_RUN" != true && -f "${CLAUDE_DIR}/CLAUDE.md" ]]; then
        if [[ "$INSTALL_WORKFLOW" == true && -f "${SCRIPT_DIR}/config/snippets/workflow.md" ]]; then
            cat "${SCRIPT_DIR}/config/snippets/workflow.md" >> "${CLAUDE_DIR}/CLAUDE.md"
            echo -e "    ${GREEN}[append]${NC}  CLAUDE.md ← workflow commands reference"
        fi
        if [[ "$INSTALL_SKILLS" == true && -f "${SCRIPT_DIR}/config/snippets/skills.md" ]]; then
            cat "${SCRIPT_DIR}/config/snippets/skills.md" >> "${CLAUDE_DIR}/CLAUDE.md"
            echo -e "    ${GREEN}[append]${NC}  CLAUDE.md ← skills reference"
        fi
    elif [[ "$DRY_RUN" == true ]]; then
        [[ "$INSTALL_WORKFLOW" == true ]] && echo -e "    ${BLUE}[append]${NC}  CLAUDE.md ← workflow commands reference" || true
        [[ "$INSTALL_SKILLS" == true ]] && echo -e "    ${BLUE}[append]${NC}  CLAUDE.md ← skills reference" || true
    fi
fi

# =============================================================================
# Write manifest
# =============================================================================
if [[ "$DRY_RUN" != true ]]; then
    # Build manifest using python for reliable JSON
    {
        echo "import json, sys"
        echo "manifest = {"
        echo "    'toolkit_path': '${SCRIPT_DIR}',"
        echo "    'installed_at': '$(date -Iseconds)',"
        echo "    'updated_at': '$(date -Iseconds)',"
        echo "    'groups': [],"
        echo "    'files': []"
        echo "}"
        # Groups
        echo "manifest['groups'].append('core')"
        [[ "$INSTALL_WORKFLOW" == true ]] && echo "manifest['groups'].extend(['workflow', 'bin'])" || true
        [[ "$INSTALL_SKILLS" == true ]] && echo "manifest['groups'].append('skills')" || true
        [[ "$INSTALL_HOOKS" == true ]] && echo "manifest['groups'].append('hooks')" || true
        [[ "$INSTALL_CONFIG" == true ]] && echo "manifest['groups'].append('config')" || true
        # Files
        for entry in "${MANIFEST_ENTRIES[@]}"; do
            echo "manifest['files'].append(${entry})"
        done
        echo "json.dump(manifest, open('${MANIFEST}', 'w'), indent=2)"
    } | python3
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [[ "$DRY_RUN" == true ]]; then
    echo -e "  ${BLUE}DRY RUN — no changes made${NC}"
    echo ""
    TOTAL=$INSTALLED
    echo "  Would install: ${TOTAL} items"
else
    TOTAL=$((INSTALLED + UPDATED))
    echo -e "  ${GREEN}Installation complete${NC}"
    echo ""

    if [[ $INSTALLED -gt 0 ]]; then
        echo -e "  ${GREEN}New${NC}       ${INSTALLED} item(s)"
        for item in "${ITEMS_INSTALLED[@]+"${ITEMS_INSTALLED[@]}"}"; do
            echo -e "             ${DIM}${item}${NC}"
        done
    fi

    if [[ $UPDATED -gt 0 ]]; then
        echo -e "  ${CYAN}Updated${NC}   ${UPDATED} item(s)"
        for item in "${ITEMS_UPDATED[@]+"${ITEMS_UPDATED[@]}"}"; do
            echo -e "             ${DIM}${item}${NC}"
        done
    fi

    if [[ $BACKED_UP -gt 0 ]]; then
        echo -e "  ${YELLOW}Backed up${NC} ${BACKED_UP} file(s)"
        for item in "${ITEMS_BACKED_UP[@]+"${ITEMS_BACKED_UP[@]}"}"; do
            echo -e "             ${DIM}${item}${NC}"
        done
    fi

    if [[ $SKIPPED -gt 0 ]]; then
        echo -e "  ${YELLOW}Skipped${NC}   ${SKIPPED} item(s) (use --force to overwrite)"
        for item in "${ITEMS_SKIPPED[@]+"${ITEMS_SKIPPED[@]}"}"; do
            echo -e "             ${DIM}${item}${NC}"
        done
    fi
fi

echo ""
if [[ "$DRY_RUN" != true ]]; then
    echo -e "  Manifest: ${DIM}$(short_path "$MANIFEST")${NC}"
fi
echo -e "  Project setup: ${DIM}./project-init.sh [path]${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
