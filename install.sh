#!/usr/bin/env bash
set -euo pipefail

# Claude Toolkit Installer
# Selectively installs commands, skills, hooks, and config into ~/.claude/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${HOME}/.claude"

# Flags
INSTALL_CORE=true
INSTALL_WORKFLOW=false
INSTALL_SKILLS=false
INSTALL_HOOKS=false
INSTALL_CONFIG=false
FORCE=false
DRY_RUN=false
UNINSTALL=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
  --force           Overwrite existing files (even non-symlinks)
  --dry-run         Show what would be done without doing it
  --uninstall       Remove toolkit symlinks (alias for uninstall.sh)
  --help            Show this help message
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

# Counters
INSTALLED=0
SKIPPED=0
OVERWRITTEN=0

# Symlink a single file: symlink_file <source> <target>
symlink_file() {
    local source="$1"
    local target="$2"
    local target_dir
    target_dir="$(dirname "$target")"

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "  ${BLUE}[dry-run]${NC} ${source} → ${target}"
        ((INSTALLED++)) || true
        return
    fi

    mkdir -p "$target_dir"

    if [[ -e "$target" || -L "$target" ]]; then
        if [[ -L "$target" ]]; then
            # Existing symlink — always replace
            rm "$target"
            ln -s "$source" "$target"
            ((OVERWRITTEN++)) || true
        elif [[ "$FORCE" == true ]]; then
            # Existing regular file or directory + --force
            rm -rf "$target"
            ln -s "$source" "$target"
            ((OVERWRITTEN++)) || true
        else
            echo -e "  ${YELLOW}[skip]${NC} ${target} (exists, use --force to overwrite)"
            ((SKIPPED++)) || true
            return
        fi
    else
        ln -s "$source" "$target"
        ((INSTALLED++)) || true
    fi
}

# Copy a file (for config that users personalize): copy_file <source> <target>
copy_file() {
    local source="$1"
    local target="$2"
    local target_dir
    target_dir="$(dirname "$target")"

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "  ${BLUE}[dry-run]${NC} copy ${source} → ${target}"
        ((INSTALLED++)) || true
        return
    fi

    mkdir -p "$target_dir"

    if [[ -e "$target" && ! -L "$target" && "$FORCE" != true ]]; then
        echo -e "  ${YELLOW}[skip]${NC} ${target} (exists, use --force to overwrite)"
        ((SKIPPED++)) || true
        return
    fi

    # Remove existing (symlink or regular file with --force)
    [[ -e "$target" || -L "$target" ]] && rm "$target"
    cp "$source" "$target"
    ((INSTALLED++)) || true
}

echo -e "${GREEN}Claude Toolkit Installer${NC}"
echo "Source: ${SCRIPT_DIR}"
echo "Target: ${CLAUDE_DIR}"
echo ""

# --- Core (always) ---
echo -e "${GREEN}[core]${NC} Commands: implement, init-claude-local"
for cmd in "${SCRIPT_DIR}"/core/commands/*.md; do
    name="$(basename "$cmd")"
    symlink_file "$cmd" "${CLAUDE_DIR}/commands/${name}"
done

# --- Workflow ---
if [[ "$INSTALL_WORKFLOW" == true ]]; then
    echo -e "${GREEN}[workflow]${NC} Commands: handoff, commit, complete, pre-merge, estimate-context, context-status, clear-context, standup, help"
    for cmd in "${SCRIPT_DIR}"/workflow/commands/*.md; do
        name="$(basename "$cmd")"
        symlink_file "$cmd" "${CLAUDE_DIR}/commands/${name}"
    done
fi

# --- Skills ---
if [[ "$INSTALL_SKILLS" == true ]]; then
    echo -e "${GREEN}[skills]${NC} Knowledge files: aws-cdk-*, react-*, security, devops-cicd"
    for skill_dir in "${SCRIPT_DIR}"/skills/*/; do
        name="$(basename "$skill_dir")"
        symlink_file "${skill_dir%/}" "${CLAUDE_DIR}/skills/${name}"
    done
fi

# --- Hooks ---
if [[ "$INSTALL_HOOKS" == true ]]; then
    echo -e "${GREEN}[hooks]${NC} Shell hooks"
    for hook in "${SCRIPT_DIR}"/hooks/*.sh; do
        name="$(basename "$hook")"
        chmod +x "$hook"
        symlink_file "$hook" "${CLAUDE_DIR}/hooks/${name}"
    done
fi

# --- Config ---
if [[ "$INSTALL_CONFIG" == true ]]; then
    echo -e "${GREEN}[config]${NC} CLAUDE.md (copy), settings.json (copy), CONTEXT_WEIGHTS.md (symlink)"
    copy_file "${SCRIPT_DIR}/config/CLAUDE.md" "${CLAUDE_DIR}/CLAUDE.md"
    copy_file "${SCRIPT_DIR}/config/settings.json" "${CLAUDE_DIR}/settings.json"
    symlink_file "${SCRIPT_DIR}/config/CONTEXT_WEIGHTS.md" "${CLAUDE_DIR}/CONTEXT_WEIGHTS.md"

    # Append conditional snippets to CLAUDE.md based on installed components
    if [[ "$DRY_RUN" != true && -f "${CLAUDE_DIR}/CLAUDE.md" ]]; then
        if [[ "$INSTALL_WORKFLOW" == true && -f "${SCRIPT_DIR}/config/snippets/workflow.md" ]]; then
            echo -e "  ${GREEN}[config]${NC} Appending workflow command reference to CLAUDE.md"
            cat "${SCRIPT_DIR}/config/snippets/workflow.md" >> "${CLAUDE_DIR}/CLAUDE.md"
        fi
        if [[ "$INSTALL_SKILLS" == true && -f "${SCRIPT_DIR}/config/snippets/skills.md" ]]; then
            echo -e "  ${GREEN}[config]${NC} Appending skills reference to CLAUDE.md"
            cat "${SCRIPT_DIR}/config/snippets/skills.md" >> "${CLAUDE_DIR}/CLAUDE.md"
        fi
    elif [[ "$DRY_RUN" == true ]]; then
        [[ "$INSTALL_WORKFLOW" == true ]] && echo -e "  ${BLUE}[dry-run]${NC} append workflow reference → ${CLAUDE_DIR}/CLAUDE.md" || true
        [[ "$INSTALL_SKILLS" == true ]] && echo -e "  ${BLUE}[dry-run]${NC} append skills reference → ${CLAUDE_DIR}/CLAUDE.md" || true
    fi
fi

# --- Summary ---
echo ""
echo -e "${GREEN}Done!${NC}"
[[ "$DRY_RUN" == true ]] && echo -e "  ${BLUE}(dry-run mode — no changes made)${NC}" || true
echo "  Installed: ${INSTALLED}"
[[ $OVERWRITTEN -gt 0 ]] && echo "  Overwritten: ${OVERWRITTEN}" || true
[[ $SKIPPED -gt 0 ]] && echo -e "  Skipped: ${SKIPPED} ${YELLOW}(use --force to overwrite)${NC}" || true
echo ""
echo "Run './project-init.sh' in any repo to set up .claude-local/ working files."
