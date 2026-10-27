# Context Estimation Weights

Use these heuristics to estimate context usage more accurately.

## Context Window Size (configurable)

The window size lives in **one place**: the `CLAUDE_CONTEXT_WINDOW_TOKENS`
environment variable in `~/.claude/settings.json`:

```json
"env": {
  "CLAUDE_CONTEXT_WINDOW_TOKENS": "1000000"
}
```

The SessionStart hook reads it and prints a `Context Window:` line into every
session (default **1,000,000 tokens** when unset — the window for the Claude 5
family: Fable, Opus and Sonnet). Trust that line over anything in this file.

Change the value when running a smaller-window model — e.g. `200000` for
Haiku 4.5 — and every percentage below shifts automatically, because costs are
expressed in **tokens** and converted with:

```
usage % = tokens used / CLAUDE_CONTEXT_WINDOW_TOKENS × 100
```

At the 1M default, **1% ≈ 10k tokens**. At 200k, 1% ≈ 2k tokens (multiply
every percentage below by 5).

## Base Costs (per message cycle)

| Item | Tokens | % @ 1M |
|------|--------|--------|
| HANDOFF.md injection (via hook) | ~6-8k | ~0.7% |
| System CLAUDE.md files (loaded once) | ~4k | ~0.4% |
| User message + response | ~2k | ~0.2% |

## Tool Costs

| Action | Tokens | % @ 1M |
|--------|--------|--------|
| File read (per 500 lines) | ~4k | ~0.4% |
| Large file read (1000+ lines) | ~8-10k | ~1% |
| Grep/Glob results | ~1-2k | ~0.1-0.2% |
| Web fetch | ~2-4k | ~0.2-0.4% |
| Task agent spawn + results | ~4-6k | ~0.5% |

## Estimation Rules

1. Start at **~2% baseline** after first exchange (system prompt, CLAUDE.md,
   skills listing, hook output — roughly 20k tokens)
2. Add costs per above for each action
3. **Round up**, not down - better to overestimate
4. Add ~0.7% per message cycle for HANDOFF.md accumulation
5. When UI shows "X% until compact", true usage = **100 - X**

## Quick Reference

| UI Shows | True Usage | Status |
|----------|------------|--------|
| 60%+ until compact | <40% | Healthy |
| 40-60% until compact | 40-60% | Moderate |
| 20-40% until compact | 60-80% | Elevated - mention /handoff |
| <20% until compact | 80%+ | Critical - recommend /handoff |

## Notes

- These are estimates based on observed patterns
- The UI's "% until auto compact" is authoritative
- When in doubt, trust the UI over these heuristics
- Percentages in this file assume the 1M default; the `Context Window:` line
  in the SessionStart output is the value actually in effect
