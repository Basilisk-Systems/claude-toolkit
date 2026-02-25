---
description: Check current context window usage and get recommendations
---

Provide a context status report with actionable recommendations.

## Report Format

### 📊 Context Status
- **Current Usage**: [X]% of context window (approximately [X]k / 200k tokens)
- **Conversation Turns**: [count exchanges]
- **Files Currently in Context**: 
  - [List main files that have been read or modified]

### 🎯 Health Assessment

Based on current usage:

| Range | Status | Action |
|-------|--------|--------|
| 0-40% | ✅ Healthy | Continue working freely |
| 40-60% | 🟡 Good | Be mindful of large file reads |
| 60-75% | 🟠 Elevated | Consider running /handoff soon |
| 75-90% | 🔴 Critical | Run /handoff now, then /clear |
| 90%+ | ⛔ Danger | Quality degraded - /clear immediately |

### 📝 Current Session Summary
[Brief 2-3 sentence summary of what we've done so far]

### 💡 Recommendations
[Based on current usage, provide specific recommendations:
- If low: "You have plenty of room to continue"
- If medium: "Consider documenting major decisions before continuing"
- If high: "Run /handoff to preserve context, then start fresh"]

### 🔑 Key Context to Preserve
[List the most important things that should survive a /clear:
- Critical decisions made
- File paths we've been working with
- Current task progress]
