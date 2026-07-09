---
description: List all custom commands and skills available
allowed-tools: Bash, Read
---

Show a helpful reference of available custom commands and skills. The installed files on disk are the **single source of truth** — do NOT use a hardcoded list.

## Instructions

1. **List custom commands and their descriptions** from each file's frontmatter:
```bash
for f in ~/.claude/commands/*.md; do
  [ -e "$f" ] || continue
  name=$(basename "$f" .md)
  desc=$(grep -m1 '^description:' "$f" | sed 's/^description:[[:space:]]*//')
  echo "/$name|$desc"
done | sort
```

2. **List available skills and their descriptions** from each skill's `SKILL.md` frontmatter:
```bash
for d in ~/.claude/skills/*/; do
  [ -e "$d/SKILL.md" ] || continue
  name=$(basename "$d")
  desc=$(grep -m1 '^description:' "$d/SKILL.md" | sed 's/^description:[[:space:]]*//')
  echo "$name|${desc%%.*}"
done | sort
```

3. **Format the output as two reference tables** — "Custom Commands" and "Available Skills" — one row per entry, with the command/skill name and a one-line description taken from the frontmatter (truncate long descriptions to the first sentence). Do not add, omit, or reword entries beyond truncation.

4. **Show any project-specific commands** if `.claude/commands/` exists in the current directory — list them the same way (name + frontmatter description) in a separate "Project Commands" table.
