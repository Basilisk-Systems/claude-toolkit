#!/bin/bash
# =============================================================================
# SESSION START HOOK
# =============================================================================
# PURPOSE: Inject current date and useful context at session start
# TRIGGER: SessionStart
#
# WHY THIS EXISTS:
#   - LLMs can have outdated knowledge of "today's date"
#   - This hook provides the ACTUAL current date from the system
#   - Also provides other useful session context
#
# OUTPUT:
#   - JSON with additionalContext field that gets injected into the session
# =============================================================================

# Get actual current date/time from system
CURRENT_DATE=$(date +%Y-%m-%d)
CURRENT_TIME=$(date +%H:%M:%S)
CURRENT_DATETIME=$(date -Iseconds)
DAY_OF_WEEK=$(date +%A)

# Get timezone
TIMEZONE=$(date +%Z)

# Check if in a git repo
GIT_BRANCH=""
GIT_STATUS=""
if git rev-parse --git-dir > /dev/null 2>&1; then
    GIT_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
    # Check if there are uncommitted changes
    if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
        GIT_STATUS="uncommitted changes"
    else
        GIT_STATUS="clean"
    fi
fi

# Get project info if available
PROJECT_NAME=""
PROJECT_VERSION=""
if [ -f "package.json" ]; then
    PROJECT_NAME=$(grep -oP '"name"\s*:\s*"\K[^"]+' package.json 2>/dev/null | head -1)
    PROJECT_VERSION=$(grep -oP '"version"\s*:\s*"\K[^"]+' package.json 2>/dev/null | head -1)
elif [ -f "pyproject.toml" ]; then
    PROJECT_NAME=$(grep -oP 'name\s*=\s*"\K[^"]+' pyproject.toml 2>/dev/null | head -1)
    PROJECT_VERSION=$(grep -oP 'version\s*=\s*"\K[^"]+' pyproject.toml 2>/dev/null | head -1)
fi

# Check for HANDOFF.md and read if exists
HANDOFF_EXISTS="false"
HANDOFF_CONTENT=""
if [ -f "docs/HANDOFF.md" ]; then
    HANDOFF_EXISTS="true"
    # Read the handoff file content (limit to ~8000 chars to avoid massive context)
    HANDOFF_CONTENT=$(head -c 8000 docs/HANDOFF.md)
fi

# Detect project type and suggest relevant skills
SUGGESTED_SKILLS=""
if [ -f "cdk.json" ] || [ -d "infrastructure" ]; then
    SUGGESTED_SKILLS="aws-cdk-*"
fi
if [ -f "vite.config.ts" ] || [ -f "vite.config.js" ] || [ -d "src/components" ]; then
    SUGGESTED_SKILLS="${SUGGESTED_SKILLS:+$SUGGESTED_SKILLS, }react-*"
fi
if [ -d ".github/workflows" ]; then
    SUGGESTED_SKILLS="${SUGGESTED_SKILLS:+$SUGGESTED_SKILLS, }devops-cicd"
fi

# Build context message
CONTEXT="SYSTEM CONTEXT (from SessionStart hook):
- Current Date: ${CURRENT_DATE} (${DAY_OF_WEEK})
- Current Time: ${CURRENT_TIME} ${TIMEZONE}
- ISO DateTime: ${CURRENT_DATETIME}"

if [ -n "$PROJECT_NAME" ]; then
    CONTEXT="${CONTEXT}
- Project: ${PROJECT_NAME} v${PROJECT_VERSION}"
fi

if [ -n "$GIT_BRANCH" ]; then
    CONTEXT="${CONTEXT}
- Git Branch: ${GIT_BRANCH} (${GIT_STATUS})"
fi

if [ -n "$SUGGESTED_SKILLS" ]; then
    CONTEXT="${CONTEXT}
- Relevant Skills: ${SUGGESTED_SKILLS}"
fi

if [ "$HANDOFF_EXISTS" = "true" ]; then
    CONTEXT="${CONTEXT}

---
PREVIOUS SESSION HANDOFF (from docs/HANDOFF.md):
${HANDOFF_CONTENT}
---"
fi

CONTEXT="${CONTEXT}

IMPORTANT: When writing dates in CHANGELOG.md or other documentation, use ${CURRENT_DATE} as today's date."

# Output JSON for Claude Code to inject
# Using jq if available for proper escaping, otherwise manual
if command -v jq &> /dev/null; then
    echo "{\"additionalContext\": $(echo "$CONTEXT" | jq -Rs .)}"
else
    # Manual escaping (less reliable but works for simple cases)
    ESCAPED=$(echo "$CONTEXT" | sed 's/"/\\"/g' | tr '\n' ' ')
    echo "{\"additionalContext\": \"${ESCAPED}\"}"
fi
