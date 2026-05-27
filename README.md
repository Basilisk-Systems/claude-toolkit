# Claude Toolkit

A shareable collection of Claude Code commands, skills, hooks, and configuration. Selective install — pick what you need.

## Why this exists

Claude Code is powerful out of the box, but teams quickly accumulate their own slash commands, safety hooks, knowledge skills, and global config. Without a shared structure, these live in individual `~/.claude/` directories — hard to sync, easy to drift. This toolkit gives you a single repo to maintain that collection, with a symlink-based installer so updates propagate instantly and everyone on the team runs the same setup.

## Quick Start

```bash
git clone https://github.com/Basilisk-Systems/claude-toolkit.git ~/claude-toolkit
cd ~/claude-toolkit

# Core only (implement + init-claude-local commands)
./install.sh

# Everything
./install.sh --all

# Pick and choose
./install.sh --with-workflow --with-skills
```

## What's Included

### Core (always installed)

| Command | Description |
|---------|-------------|
| `/implement` | Orchestrates sub-agents to execute plan phases automatically |
| `/init-claude-local` | Sets up `.claude-local/` working files in any project |

### Workflow Commands (`--with-workflow`)

| Command | Description |
|---------|-------------|
| `/handoff` | Generate session handoff for context continuity |
| `/commit` | Stage changes, verify docs, prepare commit |
| `/complete` | Complete a ticket with CHANGELOG/README updates |
| `/pre-merge` | Generate merge request title and description |
| `/estimate-context` | Estimate context usage for a plan |
| `/context-status` | Check current context window usage |
| `/clear-context` | Clear context and reload HANDOFF.md |
| `/standup` | View/start work session tracking |
| `/session-summary` | Show session telemetry (tokens, cost, agents, files, duration) |
| `/help` | List all available commands and skills |

Also installs `bin/session-summary.py` — the CLI tool backing `/session-summary`.

### Skills (`--with-skills`)

Knowledge files that auto-load when relevant:

- `aws-cdk-core` — CDK app structure, stacks, deployment
- `aws-cdk-dynamodb` — DynamoDB single-table design, queries
- `aws-cdk-lambda` — Lambda handlers, Powertools, API Gateway
- `aws-cdk-patterns` — L3 constructs, modular patterns
- `devops-cicd` — GitHub Actions, deployment pipelines
- `react-core` — React, TypeScript, Vite, TailwindCSS, shadcn/ui
- `react-state` — Redux Toolkit, RTK Query
- `security` — OWASP/NIST security best practices

### Teams (`teams/`)

Multi-agent team systems — coordinated groups of specialized agents that run together on a shared project context. Unlike commands (which Claude runs directly) or skills (which auto-load as context), teams are **sets of INSTRUCTIONS.md files** that you deploy into your project's `.agents/` directory and trigger via prompts.

#### Marketing Team

A 7-agent marketing team covering the full marketing function:

| Agent | Specialty |
|---|---|
| 07 · Strategy | Sets daily priorities; synthesizes weekly cross-team report |
| 01 · SEO & Content | Organic search, content briefs, technical SEO |
| 04 · Paid & Measurement | Paid channels, analytics, attribution |
| 06 · Sales & GTM | RevOps, competitive intel, sales enablement |
| 03 · Content & Copy | Copywriting, cold email, social, ad copy |
| 02 · CRO | A/B testing, funnel optimization, page audits |
| 05 · Growth & Retention | Churn prevention, referral, win-back |

Agents run in a defined sequence, hand off to each other via `inputs/` folders, and surface to the human only on budget decisions or strategic pivots. See [teams/marketing/README.md](teams/marketing/README.md) for setup and trigger prompts.

#### Product Team

A 5-agent product team covering the full product function:

| Agent | Specialty |
|---|---|
| 01 · CPO | Sets daily strategic direction; synthesizes weekly cross-team report |
| 02 · Director of Product | Roadmap, PRDs, scoping, competitive analysis |
| 03 · Product Ops | OKRs, metrics, timelines, team rituals |
| 04 · PM | User research, specs, PMF signal tracking, problem definition |
| 05 · APM | Surveys, fake door tests, dogfooding, onboarding analysis |

Agents run sequentially with the CPO brief gating all others. Hand off via `inputs/` folders. Designed to work alongside the marketing team — cross-team output paths are pre-wired. See [teams/product/README.md](teams/product/README.md) for setup and trigger prompts.

**To deploy either team:**

1. Copy `teams/[team]/agents/*/INSTRUCTIONS.md` into your project's `.agents/[team]-team/[agent]/`
2. Copy `ORCHESTRATOR.md` and `OUTPUT-STANDARDS.md` into `.agents/[team]-team/`
3. Create `context/[PROJECT-ID]/` using the templates in `teams/[team]/context-template/`
4. Add project-specific standing directives to each agent's INSTRUCTIONS.md

### Hooks (`--with-hooks`)

**Global** shell hooks for formatting, safety, and session management (installed to `~/.claude/hooks/`):

- `bash-safety.sh` — Prevent dangerous shell commands
- `format-python.sh` / `format-typescript.sh` / `format-json.sh` — Auto-format on save
- `changelog-validator.sh` — Validate CHANGELOG entries
- `context-monitor.sh` — Track context window usage
- `log-commands.sh` — Log executed commands
- `post-commit-complete.sh` — Post-commit automation
- `session-start.sh` — Session initialization
- `ticket-completion.sh` — Ticket workflow automation
- `write-safety.sh` — File write safety checks

### Config (`--with-config`)

- `CLAUDE.md` — Global instructions template (copied, not symlinked — personalize it)
- `settings.json` — Claude Code settings template (copied)
- `CONTEXT_WEIGHTS.md` — Context estimation heuristics (symlinked)

When combined with `--with-workflow` or `--with-skills`, the installer appends relevant configuration snippets (from `config/snippets/`) to your `CLAUDE.md` so commands and skills are referenced in your global instructions.

## Install Options

```
Usage: ./install.sh [options]

Options:
  (no flags)        Install core only
  --with-workflow   Also install workflow commands
  --with-skills     Also install knowledge skills
  --with-hooks      Also install global hooks
  --with-config     Also install config templates
  --all             Install everything
  --force           Overwrite existing files
  --dry-run         Show what would be done
  --uninstall       Remove toolkit symlinks
  --help            Show help
```

### How it works

- **Commands and hooks**: Symlinked into `~/.claude/` — updates to the toolkit repo propagate automatically
- **Skills**: Directory-symlinked into `~/.claude/skills/`
- **Bin tools**: Symlinked into `~/.claude/bin/` (installed with `--with-workflow`)
- **Config** (CLAUDE.md, settings.json): **Copied** on install so you can personalize them
- **Config** (CONTEXT_WEIGHTS.md): Symlinked (reference data)
- **Config snippets**: Appended to CLAUDE.md when corresponding modules are installed

Existing non-symlink files are never overwritten unless `--force` is used.

## Project Setup

Initialize any project for Claude Code with working files and optional project-level hooks:

```bash
# From terminal (no Claude Code session needed)
~/claude-toolkit/project-init.sh /path/to/project

# Or from within Claude Code
/init-claude-local
```

### Options

```
Usage: ./project-init.sh [options] [project-path]

Options:
  -y, --yes                Accept all defaults without prompting
  --gitignore-local        Add .claude-local/ to .gitignore (default: prompt, Y)
  --no-gitignore-local     Don't add .claude-local/ to .gitignore
  --gitignore-claude       Add .claude/ to .gitignore
  --no-gitignore-claude    Don't add .claude/ to .gitignore (default: prompt, N)
```

### What it does

**Step 1: Create `.claude-local/`** (personal, gitignored working files):

- `STANDUP.md` — Work tracking for standups
- `NOTES.md` — Personal debugging notes
- `TODO.md` — Personal task ideas
- `HANDOFF.md` — Session context for continuity
- `IMPLEMENT_STATE.md` — Phase tracking for `/implement`

**Step 2: Project hooks setup** (interactive wizard, or accept defaults with `-y`):

Installs **per-project** hooks into `.claude/hooks/` with a matching `.claude/settings.json`:

| Hook | Description | Default |
|------|-------------|---------|
| `session-handoff.sh` | Auto-loads HANDOFF.md on new sessions | Always included |
| `block-cloud-cli.sh` | Blocks cloud CLI commands (aws, cdk, gcloud, etc.) | Prompted (Y) |
| `pre-commit-check.sh` | Runs pre-commit checks before git commits | Prompted (Y) |
| `test-coverage-check.sh` | Checks test coverage after writing test files | Prompted (Y) |

The wizard also:
- Lets you configure which CLIs to block (default: `aws|cdk`)
- Lets you set test stack (`js` or `python`) and coverage threshold (default: 80%)
- Generates a starter `CLAUDE.md` with hard rules matching your selected hooks
- Optionally adds `.claude/` to `.gitignore` (default: no — shared hooks are typically committed)

## Uninstall

```bash
./uninstall.sh
```

Removes only symlinks that point to this toolkit (commands, skills, hooks, and bin tools). Copied config files (CLAUDE.md, settings.json) are left untouched.

## Updating

Since commands, skills, hooks, and bin tools are symlinked, just pull:

```bash
cd ~/claude-toolkit
git pull
```

Changes take effect immediately. For config files (CLAUDE.md, settings.json), re-run `./install.sh --with-config --force` to get the latest templates.

## Extending the Toolkit

### Adding a Skill

Skills are knowledge files that Claude loads automatically when the topic is relevant. Each skill lives in its own directory under `skills/` and contains a single `SKILL.md` with YAML frontmatter.

1. Create a directory: `skills/<skill-name>/`
2. Add a `SKILL.md` with this structure:

```markdown
---
name: my-skill
description: One-line description. Claude uses this to decide when to load the skill.
allowed-tools: Read, Glob, Grep
---

# Skill Title

Content goes here — patterns, rules, examples, reference material.
Claude reads this as context whenever the skill triggers.
```

3. Add a row to the **Skills** table in this README.
4. If the skill should be referenced in `CLAUDE.md`, add a line to `config/snippets/skills.md`.
5. Run `./install.sh --with-skills` — the installer symlinks the entire directory into `~/.claude/skills/`.

**Tips:**
- The `description` field is what Claude matches on — make it specific about *when* to trigger (e.g., "Use when working with DynamoDB single-table design" not "DynamoDB stuff").
- `allowed-tools` controls what Claude can use while the skill is active. Most knowledge-only skills need just `Read, Glob, Grep`.
- Keep skills focused. A 200-line skill on one topic loads faster and triggers more reliably than a 2000-line omnibus.

### Adding a Hook

Hooks are shell scripts that Claude Code executes at specific lifecycle points. Global hooks live in `hooks/` and project-level hooks live in `templates/claude-project/hooks/`.

1. Create your script in `hooks/` (global) or `templates/claude-project/hooks/` (per-project):

```bash
#!/bin/bash
# =============================================================================
# HOOK NAME
# =============================================================================
# PURPOSE: What this hook does
# TRIGGER: PreToolUse:Bash, PostToolUse:Write, etc.
# =============================================================================

INPUT=$(cat)

# Extract tool input fields with jq (fallback to grep)
if command -v jq &> /dev/null; then
    VALUE=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
else
    VALUE=$(echo "$INPUT" | grep -oP '"command"\s*:\s*"\K[^"]+')
fi

# Your logic here...

# Exit codes:
#   exit 0                                     → Allow
#   exit 2                                     → Block (silent)
#   echo '{"decision": "block", "reason": "..."}' → Block with message
#   echo '{"decision": "ask", "reason": "..."}'   → Prompt user
```

2. Make it executable: `chmod +x hooks/my-hook.sh`
3. Add a row to the **Hooks** table in this README.
4. Register the hook in the appropriate `settings.json`. For global hooks, add an entry to `config/settings.json`; for project hooks, add it to `templates/claude-project/settings.json`.

**Available triggers:**
- `PreToolUse:<ToolName>` — runs before a tool call (can block it)
- `PostToolUse:<ToolName>` — runs after a tool call completes
- `Notification` — runs on Claude Code notifications
- `Stop` — runs when Claude finishes a response

**Tips:**
- Always read from stdin (`INPUT=$(cat)`) — Claude Code pipes the tool call as JSON.
- Prefer `jq` for parsing with a `grep` fallback so hooks work on minimal systems.
- Keep hooks fast. They run synchronously and block Claude Code while executing.

### Adding Agents (Commands with Sub-agents)

Commands that orchestrate sub-agents (like `/implement` and `/code-review`) live alongside regular commands as `.md` files. The difference is that they use the `Agent` tool to spawn focused workers.

1. Create a command file in `core/commands/` or `workflow/commands/`:

```markdown
---
description: What this command does
argument-hint: <optional-arg>
allowed-tools: Read, Bash, Glob, Grep, Agent, AskUserQuestion
---

# Command Title

## Step 1: Gather Context

Describe what the main agent should do first.

## Step 2: Spawn Workers

Use the Agent tool to delegate focused sub-tasks:

- **Agent 1 — Analysis**: Describe focus area. Report findings in under 200 words.
- **Agent 2 — Validation**: Describe what to check.

Run independent agents in parallel. Wait for results before proceeding.

## Step 3: Synthesize

Combine agent results and present to the user.
```

2. Add `Agent` to the `allowed-tools` frontmatter.
3. Add a row to the appropriate command table in this README.
4. If it belongs in the workflow module, update `config/snippets/workflow.md` so the command appears in `CLAUDE.md` after install.

**Tips:**
- Give each sub-agent a self-contained prompt — it has no context from the parent conversation.
- Specify what the agent should report back and set a word limit to keep results focused.
- Use `model: sonnet` in agent calls for routine work; default (Opus) for tasks requiring deeper reasoning.
- Commands in `core/commands/` are always installed; commands in `workflow/commands/` require `--with-workflow`.
