# Marketing Team — 7-Agent System

A coordinated team of 7 Claude agents that covers the full marketing function: strategy, SEO, paid media, content, CRO, growth, and sales enablement. Agents run on a shared context, hand off to each other via file-based inputs/outputs, and surface to the human owner only when a decision requires it.

---

## Architecture

```
07 · Strategy          ← runs first, daily; sets priorities for all other agents
├── 01 · SEO           ← parallel with 04 and 06
├── 04 · Paid          ← parallel with 01 and 06
├── 06 · Sales & GTM   ← parallel with 01 and 04
├── 03 · Content/Copy  ← sequential; reads briefs from 01 and 06
├── 02 · CRO           ← parallel with 05; reads from 03 and 04
└── 05 · Growth        ← parallel with 02; reads from 04 and 06
```

---

## Setup

### 1. Create the agent working directory in your project

```
.agents/
  marketing-team/
    ORCHESTRATOR.md          ← copy from teams/marketing/
    OUTPUT-STANDARDS.md      ← copy from teams/marketing/
    01-seo-content/
      INSTRUCTIONS.md        ← copy from teams/marketing/agents/01-seo-content/
      inputs/
      outputs/
    02-cro/
      INSTRUCTIONS.md
      inputs/
      outputs/
    03-content-copy/
      INSTRUCTIONS.md
      inputs/
      outputs/
    04-paid-measurement/
      INSTRUCTIONS.md
      inputs/
      outputs/
    05-growth-retention/
      INSTRUCTIONS.md
      inputs/
      outputs/
    06-sales-gtm/
      INSTRUCTIONS.md
      inputs/
      outputs/
    07-strategy/
      INSTRUCTIONS.md
      inputs/
      outputs/
```

### 2. Create project context

```
context/
  [your-project-id]/
    product-overview.md
    icp.md
    positioning.md
    messaging-hierarchy.md
    active-campaigns.md
    competitors.md
```

Fill these from the templates in `teams/marketing/context-template/`. Agents read these files at the start of every run to ground their output in current product context.

### 3. Create output folders

```
outputs/
  [your-project-id]/
    marketing/
      01-seo/
      02-cro/
      03-content-copy/
      04-paid-measurement/
      05-growth-retention/
      06-sales-gtm/
      07-strategy/
```

### 4. Add project-specific standing directives

Each INSTRUCTIONS.md has a `## Standing Directives` section. This is where you put decisions from leadership that override default agent behavior — CTA policy changes, positioning pivots, channel holds. Add these once and they persist across all future runs.

---

## Running the Team

### Full daily run

```
"Trigger the marketing team daily run for [DATE] on project [PROJECT-ID].
Follow the sequence in .agents/marketing-team/ORCHESTRATOR.md.
Begin with Agent 07 and proceed through the full daily trigger sequence."
```

### Single agent

```
"You are the [Agent Name]. Read your INSTRUCTIONS.md at
.agents/marketing-team/[agent-folder]/INSTRUCTIONS.md.
Also read .agents/marketing-team/OUTPUT-STANDARDS.md and context/[PROJECT-ID]/.
Active project: [PROJECT-ID]. Then complete the following task: [specific task]."
```

See [RUNBOOK.md](RUNBOOK.md) for the full trigger prompt library, weekly sequences, and review protocol.

---

## Output Naming Convention

```
[PROJECT-ID]_MKT_[AGENT-CODE]_[deliverable-type]_[YYYY-MM-DD].md
```

Examples:
- `ACME_MKT_07-STRAT_weekly-strategy-brief_2026-05-26.md`
- `ACME_MKT_03-COPY_cold-email-sequence_2026-05-26.md`

---

## Escalation Protocol

Agents surface to the human owner only when:
- A budget decision is required
- A strategic pivot is needed (ICP, pricing, core positioning)
- A platform or account issue requires owner action
- A legal or compliance review is needed

All other decisions are resolved autonomously between agents via the `inputs/` folder pattern.
