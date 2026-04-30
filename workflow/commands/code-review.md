---
description: Perform comprehensive code review using parallel analysis agents (quality, style, impact, testing, security)
argument-hint: [base-branch (default: main)]
allowed-tools: Bash, Read, Grep, Glob, Agent
---

# Multi-Agent Code Review

Perform a comprehensive code review by spawning five parallel analysis agents. Each agent reviews independently, and results are aggregated into a unified report.

## Step 1: Gather Review Context

```bash
BASE_BRANCH="${ARGUMENTS:-main}"
CURRENT_BRANCH=$(git branch --show-current)

# Files changed on this branch
git diff $BASE_BRANCH --name-only

# Full diff
git diff $BASE_BRANCH

# Commit history
git log $BASE_BRANCH..HEAD --oneline

# Stats
git diff $BASE_BRANCH --stat

# Working directory
pwd
```

Collect and store:
- `CHANGED_FILES` — list of all changed files (full paths)
- `DIFF` — complete diff output
- `COMMITS` — commit messages for intent understanding
- `REPO_ROOT` — absolute path to repo root

## Step 2: Filter and Classify Changed Files

### Exclude non-application folders

Remove files matching these patterns from the changed files list **before** passing to agents:
- `.claude/` — Claude Code hooks and settings (tooling config, not application code)
- `docs/` — documentation files (not reviewable code)
- `*.md` in the repo root — project markdown (CLAUDE.md, README.md, CHANGELOG.md, etc.)

These folders are **never** passed to any review agent. Only application code, tests, infrastructure, and config files are reviewed.

### Classify remaining files

Group changed files for agent routing:
- **Python source**: `*.py` excluding `test_*.py`
- **Tests**: `test_*.py`, `*_test.py`, `conftest.py`
- **Infrastructure**: `*_stack.py`, `constructs/*.py`, `cdk.json`, `app.py`
- **Config**: `*.json`, `*.yaml`, `*.toml`, `*.cfg`
- **Frontend**: `*.ts`, `*.tsx`, `*.js`, `*.jsx`, `*.css`

If no files remain after filtering, output "Nothing to review" and stop.

## Step 3: Spawn Review Agents in Parallel

Launch ALL FIVE agents in a SINGLE message using five Agent tool calls. Use `model: "opus"` for all agents.

**CRITICAL**: All agents are read-only — they must NEVER modify files, commit, or make changes.

Each agent prompt must include:
1. The repo working directory path
2. The list of changed files relevant to that agent
3. The base branch name
4. Instruction to read `CLAUDE.md` first for project conventions
5. Instruction to read full files before analyzing (not just the diff)

---

### Agent 1: Quality Agent

```
You are a code quality reviewer. Analyze changes on branch [CURRENT_BRANCH] against [BASE_BRANCH].

Working directory: [REPO_ROOT]
Changed files: [CHANGED_FILES]

Read CLAUDE.md first for project conventions.

## Review Scope
1. **Dead code**: Unused imports, unreachable code, commented-out blocks
2. **Complexity**: Functions over 20 lines, deeply nested conditionals (>3 levels), high cyclomatic complexity
3. **Duplication**: Similar code blocks that should be extracted
4. **Naming**: Unclear variable/function names, inconsistent naming conventions
5. **Design**: God functions, missing abstractions, SOLID violations
6. **Error handling**: Bare except, swallowed exceptions, missing error handling on I/O

Read each changed file fully before analyzing. Check both the diff AND surrounding context.

## Output Format
For each finding:
- **Severity**: blocker | warning | suggestion
- **File**: path/to/file.py:line
- **Issue**: [concise description]
- **Fix**: [specific recommendation with code if helpful]

End with: "Summary: X blockers, Y warnings, Z suggestions"
If a category has no issues, say so explicitly.
Do NOT modify any files. This is a read-only review.
```

### Agent 2: Style Agent

```
You are a code style reviewer. Analyze changes on branch [CURRENT_BRANCH] against [BASE_BRANCH].

Working directory: [REPO_ROOT]
Changed files: [CHANGED_FILES]

Read CLAUDE.md first. Check pyproject.toml and .pre-commit-config.yaml for lint/format config.

## Review Scope
1. **Formatting**: Consistent with project style (ruff config, line length)
2. **Docstrings**: Public functions/classes MUST have docstrings. Check style consistency (Google/numpy).
3. **Comments**: Flag noise comments ("# increment counter"). Flag complex logic WITHOUT comments.
4. **Type hints**: New functions must be properly typed. Check consistency with existing code.
5. **Import organization**: stdlib > third-party > local, alphabetized within groups
6. **Magic numbers/strings**: Unnamed constants that should be extracted

## Output Format
- **Severity**: blocker | warning | suggestion
- **File**: path/to/file.py:line
- **Issue**: [description]
- **Fix**: [recommendation]

Docstring/type hint issues = "warning". Formatting issues = "warning" unless they break lint rules (then "blocker").
End with: "Summary: X blockers, Y warnings, Z suggestions"
Do NOT modify any files.
```

### Agent 3: Impact Agent

```
You are an impact analysis reviewer. Check for upstream/downstream breakage caused by changes on branch [CURRENT_BRANCH] against [BASE_BRANCH].

Working directory: [REPO_ROOT]
Changed files: [CHANGED_FILES]

## THIS IS THE MOST CRITICAL REVIEW — upstream breakage causes production bugs.

## Review Scope
1. **Signature changes**: Did any public function parameters change (added/removed/renamed, return type changed)? Find ALL callers using Grep and verify they still work.
2. **Removed exports**: Were any public functions/classes/constants removed or renamed? Search for all imports of those symbols.
3. **Changed return types**: Did any function change what it returns? Trace all consumers.
4. **Database/schema changes**: Any model changes that need migrations?
5. **Environment variables**: New env vars added but not set in deployment config?
6. **API contract changes**: REST endpoint changes that affect clients?
7. **Side effects**: Did behavior of existing functions change in ways callers might not expect?

For EACH changed function signature or removed symbol, search for callers:
- Use Grep to find all references across the codebase
- Read each caller to verify it still works with the change

## Output Format
- **Severity**: blocker (confirmed breakage) | warning (potential breakage, needs human check) | suggestion
- **File**: path/to/file.py:line
- **Issue**: [what changed and who might break]
- **Affected callers**: [list files that reference the changed symbol]
- **Fix**: [what callers need to do]

End with: "Summary: X confirmed breakages, Y potential breakages"
Do NOT modify any files.
```

### Agent 4: Test Coverage Agent

```
You are a test coverage reviewer. Analyze changes on branch [CURRENT_BRANCH] against [BASE_BRANCH].

Working directory: [REPO_ROOT]
Changed source files: [NON_TEST_CHANGED_FILES]
Changed test files: [TEST_CHANGED_FILES]

## Review Scope
1. **New code without tests**: For each new function/class/method, search for corresponding tests. Use Grep to search test directories.
2. **Modified code without updated tests**: If behavior changed, did tests update?
3. **Test quality**: Are new tests testing behavior or just "doesn't throw"? Look for meaningful assertions.
4. **Edge cases**: Are error paths tested? Boundary conditions? Empty inputs?
5. **Test isolation**: Tests depending on external services without mocking? Order dependencies?
6. **Missing test types**: API changes need integration tests. New utilities need unit tests.

For each new public function, search for tests:
- Grep for the function name in test directories
- Check that tests cover the happy path AND error paths

## Output Format
- **Severity**: blocker (missing tests for critical paths — auth, data mutation) | warning (missing tests for new public functions) | suggestion (edge cases, test quality)
- **File**: path/to/file.py:line
- **Issue**: [what lacks test coverage]
- **Fix**: [what test to write, with skeleton if helpful]

End with: "Summary: X functions lack tests, Y tests need updates"
Do NOT modify any files.
```

### Agent 5: Security Agent

```
You are a security engineer reviewing changes on branch [CURRENT_BRANCH] against [BASE_BRANCH].

Working directory: [REPO_ROOT]
Changed files: [CHANGED_FILES]

Read CLAUDE.md for project conventions.

## Review Scope (OWASP Top 10 + AWS)
1. **Injection** (A03): f-string SQL, command injection via subprocess, template injection
2. **Broken Auth** (A07): Missing auth on new endpoints, weak token handling
3. **Sensitive Data** (A02): Hardcoded secrets, PII in logs, unencrypted sensitive fields
4. **Access Control** (A01): Missing authorization, IDOR vulnerabilities
5. **Misconfiguration** (A05): Debug flags, CORS wildcards, verbose errors
6. **Vulnerable Deps** (A06): Changed requirements.txt/package.json — check for known issues
7. **SSRF** (A10): User-controlled URLs in HTTP requests
8. **AWS-specific**: Overly permissive IAM, public S3, missing encryption, open security groups

Use Grep to search for vulnerability patterns in changed files:
- `f"SELECT`, `os.system(`, `subprocess.call.*shell=True`
- `password\s*=\s*"`, `api_key\s*=\s*"`, `secret\s*=\s*"`
- `allow_origins.*\*`, `"*".*actions`, `"*".*resources`
- `verify=False`, `debug=True`, `DEBUG = True`

## Output Format
- **Severity**: critical | high | medium | low | info
- **File**: path/to/file.py:line
- **Category**: OWASP-A03 / CWE-89 / etc.
- **Issue**: [description]
- **Evidence**: [code snippet]
- **Fix**: [specific remediation with code]

End with: "Summary: X critical, Y high, Z medium, W low"
Do NOT modify any files.
```

## Step 4: Aggregate Results

After ALL five agents return, compile a unified report.

Parse each agent's findings and count by severity. Then output:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CODE REVIEW REPORT — [CURRENT_BRANCH] → [BASE_BRANCH]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Branch: [CURRENT_BRANCH]
Base: [BASE_BRANCH]
Files changed: [count]
Commits: [count]

## Summary
| Category   | Blockers | Warnings | Suggestions |
|------------|----------|----------|-------------|
| Quality    | X        | Y        | Z           |
| Style      | X        | Y        | Z           |
| Impact     | X        | Y        | Z           |
| Testing    | X        | Y        | Z           |
| Security   | X        | Y        | Z           |
| **Total**  | **X**    | **Y**    | **Z**       |

## Verdict
[PASS | PASS WITH WARNINGS | NEEDS FIXES]

## Blockers (must fix before merge)
[All blocker-severity findings from all agents, with file:line and fix]

## Warnings (should fix)
[All warnings, grouped by category]

## Suggestions (nice to have)
[All suggestions, grouped by category]

## Positive Observations
[Consolidate positive notes from all agents — good patterns, clean code, thorough tests]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Step 5: Verdict Logic

- **PASS**: 0 blockers AND 0 critical/high security findings
- **PASS WITH WARNINGS**: 0 blockers AND 0 critical/high security, but warnings present
- **NEEDS FIXES**: Any blockers OR any critical/high security findings

For security findings, map to the verdict:
- `critical` or `high` = blocker equivalent
- `medium` = warning equivalent
- `low` or `info` = suggestion equivalent

## Step 6: Update STANDUP.md (if exists)

```bash
ls .claude-local/STANDUP.md 2>/dev/null
```

If found, add to "## Completed":
```markdown
- [x] Code review completed: [CURRENT_BRANCH] → [BASE_BRANCH] — [verdict]
```

## Rules

1. **Always use Opus** for all review agents
2. **Parallel execution** — all five agents launch in a single message (they only read, no write conflicts)
3. **Read-only** — agents must NEVER modify files, commit, or make any changes
4. **Err toward flagging** — when in doubt, flag as warning with explanation. Missing a real issue is worse than a false positive.
5. **Read before judging** — agents must read full files for context, not just the diff lines
6. **Be specific** — every finding must have file:line and a concrete fix suggestion
7. **Positive observations mandatory** — the report must acknowledge good practices found
8. **No duplicate findings** — if two agents flag the same issue, deduplicate in the aggregate report
