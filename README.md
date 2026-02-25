# Claude Toolkit

A shareable collection of Claude Code commands, skills, hooks, and configuration. Selective install — pick what you need.

## Quick Start

```bash
git clone https://github.com/Basilisk-Systems/claude-toolkit-code.git ~/claude-toolkit
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
