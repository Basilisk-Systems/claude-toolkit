---
description: Estimate context usage for implementing a plan or task
---

Analyze the scope of a plan document or implementation task and project context usage estimates.

## Input Sources (in priority order)

1. **Active plan file** - Check `~/.claude/plans/` for recent plan documents
2. **Current task** - Analyze the implementation scope discussed in this session
3. **Explicit file** - If user provides a file path, analyze that document

## Analysis Factors

Consider these when estimating context consumption:

| Factor | Low Impact | Medium Impact | High Impact |
|--------|------------|---------------|-------------|
| Files to create | 1-3 | 4-8 | 9+ |
| Files to modify | 1-2 | 3-5 | 6+ |
| New dependencies | 0-1 | 2-3 | 4+ |
| Test files needed | 0-2 | 3-5 | 6+ |
| External reads (docs, existing code) | 2-5 | 6-15 | 16+ |
| Implementation phases | 1-2 | 3-5 | 6+ |
| Cross-cutting concerns | None | 1-2 (auth, state) | 3+ (auth, state, routing, API) |

## Estimation Formula

```
Base context per file operation:
- Read existing file: ~2-5k tokens
- Create new file: ~3-8k tokens (depending on complexity)
- Modify existing file: ~4-10k tokens (read + edit + verify)
- Run tests/build: ~2-4k tokens

Overhead:
- Tool calls and responses: ~30% of file operations
- Conversation and reasoning: ~20% of total
```

## Output Format

### Context Usage Projection

**Plan/Task**: [Name or summary]

**Scope Analysis**:
- Files to create: [count]
- Files to modify: [count]
- Test files: [count]
- Dependencies to install: [count]
- External file reads needed: [estimated count]

### Estimates

| Scenario | Est. Tokens | % of 200k | Assessment |
|----------|-------------|-----------|------------|
| **Low** (minimal iteration) | [X]k | [X]% | [Can complete in one session?] |
| **Medium** (normal iteration) | [X]k | [X]% | [Recommendation] |
| **High** (complex issues) | [X]k | [X]% | [Risk assessment] |

### Recommendations

**If Low estimate:**
- Proceed with implementation
- [Specific advice]

**If Medium estimate:**
- [Advice about checkpoints]
- Consider `/handoff` at [milestone]

**If High estimate:**
- Break into [N] sub-tasks
- Run `/handoff` after each phase
- [Phase breakdown suggestion]

### Current Context Available

- **Current usage**: ~[X]%
- **Remaining capacity**: ~[X]k tokens
- **Can complete in this session**: [Yes/No/Likely with handoff]
