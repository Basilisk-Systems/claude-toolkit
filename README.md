# Claude Toolkit

A shareable collection of Claude Code commands, skills, hooks, and configuration. Selective install — pick what you need.

## Quick Start

```bash
git clone git@github.com:Basilisk-Systems/claude-toolkit.git ~/claude-toolkit
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
| `/help` | List all available commands and skills |

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

### Hooks (`--with-hooks`)

Shell hooks for formatting, safety, and session management:

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
- **Config** (CLAUDE.md, settings.json): **Copied** on install so you can personalize them
- **Config** (CONTEXT_WEIGHTS.md): Symlinked (reference data)

Existing non-symlink files are never overwritten unless `--force` is used.

## Project Setup

Set up `.claude-local/` working files in any project:

```bash
# From terminal (no Claude Code session needed)
~/claude-toolkit/project-init.sh /path/to/project

# Or from within Claude Code
/init-claude-local
```

This creates:
- `STANDUP.md` — Work tracking for standups
- `NOTES.md` — Personal debugging notes
- `TODO.md` — Personal task ideas
- `HANDOFF.md` — Session context for continuity
- `IMPLEMENT_STATE.md` — Phase tracking for `/implement`

## Uninstall

```bash
./uninstall.sh
```

Removes only symlinks that point to this toolkit. Copied config files (CLAUDE.md, settings.json) are left untouched.

## Updating

Since commands, skills, and hooks are symlinked, just pull:

```bash
cd ~/claude-toolkit
git pull
```

Changes take effect immediately. For config files (CLAUDE.md, settings.json), re-run `./install.sh --with-config --force` to get the latest templates.
