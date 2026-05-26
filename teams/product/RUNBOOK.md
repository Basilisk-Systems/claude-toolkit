# Product Team Runbook

How to operate the 5-agent product team — triggering the full team, running a single agent, and reviewing outputs.

---

## Setup Prerequisites

Before running any agent, ensure the following exist:

```
.agents/
  product-team/
    ORCHESTRATOR.md              ← run order and DONE conditions
    OUTPUT-STANDARDS.md          ← naming conventions and save paths
    01-cpo/INSTRUCTIONS.md
    02-director-product/INSTRUCTIONS.md
    03-product-ops/INSTRUCTIONS.md
    04-pm/INSTRUCTIONS.md
    05-apm/INSTRUCTIONS.md

context/[PROJECT-ID]/            ← product and positioning context
  product-overview.md
  icp.md
  positioning.md
  competitors.md
  product-roadmap.md

projects/[PROJECT-ID]/           ← strategy docs, architecture, market analysis
```

---

## How to Trigger the Full Team

### Daily Run

Trigger agents in this order. Step 2 runs in parallel; all others are sequential.

```
Step 1 (Sequential):   Run Agent 01 · CPO
Step 2 (Parallel):     Run Agents 02 · Director and 03 · Product Ops simultaneously
Step 3 (Sequential):   Run Agent 04 · PM
Step 4 (Sequential):   Run Agent 05 · APM
```

**Prompt to trigger each agent:**
> "You are [Agent Name]. Read your INSTRUCTIONS.md at `.agents/product-team/[agent-folder]/INSTRUCTIONS.md` and execute your daily task checklist for today, [DATE]. Follow all pre-task protocol steps before beginning. Active project: [PROJECT-ID]."

**Full team daily prompt:**
> "Trigger the product team daily run for [DATE] on project [PROJECT-ID]. Follow the sequence in `.agents/product-team/ORCHESTRATOR.md`. Begin with Agent 01 (CPO) and proceed through the full daily trigger sequence."

---

### Weekly Run

**Monday — Direction setting:**
> "Trigger the product team weekly run for the week of [DATE], project [PROJECT-ID]. Begin with Agent 01's weekly direction-setting task. Once the Weekly Strategic Brief is saved, run Agents 02 and 03 in parallel, followed by Agent 04, followed by Agent 05."

**Friday — Synthesis:**
> "Trigger Agent 01's weekly synthesis task for [DATE], project [PROJECT-ID]. Read all agent weekly reports and produce the Weekly Cross-Team Synthesis."

---

## How to Trigger a Single Agent

**Prompt template:**
> "You are the [Agent Name]. Read your INSTRUCTIONS.md at `.agents/product-team/[agent-folder]/INSTRUCTIONS.md`. Also read `.agents/product-team/OUTPUT-STANDARDS.md` and `context/[PROJECT-ID]/`. Active project: [PROJECT-ID]. Then complete the following task: [specific task]."

**Examples:**

Run Director for a PRD:
> "You are the Director of Product. Read `.agents/product-team/02-director-product/INSTRUCTIONS.md` and `context/[PROJECT-ID]/`. Active project: [PROJECT-ID]. Write a PRD for [feature name]."

Run PM for user interview synthesis:
> "You are the PM. Read `.agents/product-team/04-pm/INSTRUCTIONS.md` and `context/[PROJECT-ID]/`. Active project: [PROJECT-ID]. Synthesize the following customer interviews: [interview notes or file paths]."

Run APM for a fake door test brief:
> "You are the APM. Read `.agents/product-team/05-apm/INSTRUCTIONS.md` and `context/[PROJECT-ID]/`. Active project: [PROJECT-ID]. Write a fake door test brief for the [vertical] market."

---

## How to Review Outputs

### Daily Review (5 min)
1. Check `outputs/[PROJECT-ID]/product/01-cpo/` — confirm today's strategic brief exists
2. Scan each agent's daily log for any `## ESCALATION REQUIRED` blocks
3. If no escalations: team ran successfully, no action needed
4. If escalation found: add `## OWNER RESPONSE` below it with your decision

### Weekly Review (15–20 min)
1. Read `outputs/[PROJECT-ID]/product/01-cpo/[PROJECT-ID]_PRD_01-CPO_weekly-synthesis_[DATE].md`
2. Drill into any agent's weekly report if the synthesis flags a concern
3. Check any `## ESCALATION REQUIRED` blocks across all weekly reports

### Finding a Specific Deliverable

| What you're looking for | Where to find it |
|---|---|
| This week's strategic priorities | `outputs/[PROJECT-ID]/product/01-cpo/` |
| Roadmap state and PRD queue | `outputs/[PROJECT-ID]/product/02-director-product/` |
| OKR status and timeline health | `outputs/[PROJECT-ID]/product/03-product-ops/` |
| Customer research and PMF signals | `outputs/[PROJECT-ID]/product/04-pm/` |
| Fake door results and survey data | `outputs/[PROJECT-ID]/product/05-apm/` |

---

## Escalation Protocol

Agents surface to you only when:
- A strategic pivot is required that changes the product or business model
- A build/buy/partner decision is required
- A budget or commercial commitment needs approval
- A legal, compliance, or security review is needed

**When you see an escalation:**
1. Open the file containing `## ESCALATION REQUIRED`
2. Read the situation, recommendation, and options
3. Add `## OWNER RESPONSE` below it with your decision
4. The agent will read this on its next run and proceed
