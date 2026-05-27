# Product Team — 5-Agent System

A coordinated team of 5 Claude agents covering the full product function: strategy (CPO), roadmap and PRDs (Director), operations and OKRs (Product Ops), user research and specs (PM), and validation research (APM). Agents run sequentially, with the CPO's daily brief gating all others.

---

## Architecture

```
01 · CPO                   ← runs first, daily; sets strategic direction for all others
├── 02 · Director          ← parallel with 03; roadmap, PRDs, competitive intel
├── 03 · Product Ops       ← parallel with 02; OKRs, timelines, metrics
├── 04 · PM                ← sequential after 02 and 03; user research, specs, PMF
└── 05 · APM               ← sequential after 04; surveys, fake doors, dogfooding
```

---

## Setup

### 1. Create the agent working directory in your project

```
.agents/
  product-team/
    ORCHESTRATOR.md          ← copy from teams/product/
    OUTPUT-STANDARDS.md      ← copy from teams/product/
    01-cpo/
      INSTRUCTIONS.md        ← copy from teams/product/agents/01-cpo/
      inputs/
      outputs/
    02-director-product/
      INSTRUCTIONS.md
      inputs/
      outputs/
    03-product-ops/
      INSTRUCTIONS.md
      inputs/
      outputs/
    04-pm/
      INSTRUCTIONS.md
      inputs/
      outputs/
    05-apm/
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
    competitors.md
    product-roadmap.md

projects/
  [your-project-id]/        ← strategy docs, architecture docs, market analysis
```

Fill `context/` from the templates in `teams/product/context-template/`. The `projects/` folder is for longer-form strategy and architecture documents agents reference for deep context.

### 3. Create output folders

```
outputs/
  [your-project-id]/
    product/
      01-cpo/
      02-director-product/
      03-product-ops/
      04-pm/
      05-apm/
```

### 4. Add project-specific standing directives

Each INSTRUCTIONS.md has a `## Standing Directives` section. Use this for decisions that override default agent behavior — product pivots, current stage (discovery vs. build vs. scale), active OKRs, current roadmap constraints. Add these once and they persist across all future runs.

---

## Running the Team

### Full daily run

```
"Trigger the product team daily run for [DATE] on project [PROJECT-ID].
Follow the sequence in .agents/product-team/ORCHESTRATOR.md.
Begin with Agent 01 (CPO) and proceed through the full daily trigger sequence."
```

### Single agent

```
"You are the [Agent Name]. Read your INSTRUCTIONS.md at
.agents/product-team/[agent-folder]/INSTRUCTIONS.md.
Also read .agents/product-team/OUTPUT-STANDARDS.md and context/[PROJECT-ID]/.
Active project: [PROJECT-ID]. Then complete the following task: [specific task]."
```

See [RUNBOOK.md](RUNBOOK.md) for the full trigger prompt library, weekly sequences, and review protocol.

---

## Output Naming Convention

```
[PROJECT-ID]_PRD_[AGENT-CODE]_[deliverable-type]_[YYYY-MM-DD].md
```

Examples:
- `ACME_PRD_01-CPO_weekly-strategic-brief_2026-05-26.md`
- `ACME_PRD_04-PM_interview-synthesis_2026-05-26.md`
- `ACME_PRD_05-APM_fake-door-brief-legal_2026-05-26.md`

---

## Escalation Protocol

Agents surface to the human owner only when:
- A strategic pivot is required that changes the product or business model
- A build/buy/partner decision is required
- A budget or commercial commitment needs approval
- A legal, compliance, or security review is needed

All other decisions are resolved autonomously between agents via the `inputs/` folder pattern.
