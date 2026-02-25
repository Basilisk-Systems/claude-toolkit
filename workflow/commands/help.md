---
description: List all custom commands and skills available
allowed-tools: Bash, Read
---

Show a helpful reference of available custom commands and skills.

## Instructions

1. **List custom commands:**
```bash
ls ~/.claude/commands/*.md 2>/dev/null | xargs -I {} basename {} .md | sort
```

2. **List available skills:**
```bash
ls ~/.claude/skills/ 2>/dev/null | sort
```

3. **Format as a reference table** with brief descriptions:

### Custom Commands
| Command | Description |
|---------|-------------|
| `/help` | This command - list available commands and skills |
| `/handoff` | Save session context to docs/HANDOFF.md |
| `/complete [task]` | Complete a task with CHANGELOG/README updates |
| `/commit [files]` | Prepare commit message with doc verification |
| `/standup` | View work session, optionally start new period |
| `/init-claude-local` | Set up .claude-local/ for personal project files |
| `/test-gen [file]` | Generate tests for a file or component |
| `/review [files]` | Code review on specified files |
| `/pre-merge [base]` | Generate MR title and description from branch commits |
| `/security-review` | Security audit (OWASP/NIST compliance) |
| `/logs [source]` | Access logs from various sources |
| `/watch-logs` | Start background log monitoring |
| `/context-status` | Check current context window usage |
| `/estimate-context` | Project context usage for a plan/task |
| `/implement [plan]` | Auto-implement a plan using sub-agents per phase |

### Available Skills
| Skill | Purpose |
|-------|---------|
| `aws-cdk-core` | CDK app structure, config, deployment |
| `aws-cdk-patterns` | L3 constructs, refactoring, logical ID preservation |
| `aws-cdk-lambda` | Lambda handlers, Powertools |
| `aws-cdk-dynamodb` | Single table design, queries |
| `react-core` | Components, routing, TailwindCSS |
| `react-state` | Redux Toolkit, RTK Query |
| `devops-cicd` | GitHub Actions, CI/CD validation |
| `security` | OWASP/NIST security best practices |

4. **Show any project-specific commands** if `.claude/commands/` exists in current directory.
