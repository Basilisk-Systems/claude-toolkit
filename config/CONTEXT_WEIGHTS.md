# Context Estimation Weights

Use these heuristics to estimate context usage more accurately.

## Base Costs (per message cycle)

| Item | Cost |
|------|------|
| HANDOFF.md injection (via hook) | ~3-4% |
| System CLAUDE.md files | ~2% (loaded once) |
| User message + response | ~1% |

## Tool Costs

| Action | Cost |
|--------|------|
| File read (per 500 lines) | ~2% |
| Large file read (1000+ lines) | ~4-5% |
| Grep/Glob results | ~0.5-1% |
| Web fetch | ~1-2% |
| Task agent spawn + results | ~2-3% |

## Estimation Rules

1. Start at **10% baseline** after first exchange (accounts for system context)
2. Add costs per above for each action
3. **Round up**, not down - better to overestimate
4. Multiply message count by ~4% for HANDOFF.md accumulation
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
