
<!-- claude-toolkit:workflow -->
## Workflow Commands

Available slash commands for development workflow:

| Command | Purpose |
|---------|---------|
| `/design-spec` | Research and write a design spec, sync decisions to the ticket |
| `/blueprint` | Research codebase and write an implementation plan |
| `/implement` | Orchestrate sub-agents to execute plan phases |
| `/branch` | Create a semantic branch from a ticket description |
| `/handoff` | Generate session handoff for context continuity |
| `/commit` | Stage changes, verify docs, prepare commit |
| `/complete` | Complete a ticket with CHANGELOG/README updates |
| `/code-review` | Multi-agent code review |
| `/pre-merge` | Generate merge request title and description |
| `/estimate-context` | Estimate context usage for a plan |
| `/context-status` | Check current context window usage |
| `/clear-context [skip]` | Clear context and reload HANDOFF.md with an opening brief (`skip` = silent fresh context, e.g. before `/implement`) |
| `/standup` | View/start work session tracking |
| `/session-summary` | Show session telemetry (tokens, cost, agents) |
| `/help` | List all available commands and skills |
