# Marketing Team Runbook

How to operate the 7-agent marketing team — triggering the full team, running a single agent, and reviewing outputs.

---

## Setup Prerequisites

Before running any agent, ensure the following exist:

```
.agents/
  marketing-team/
    ORCHESTRATOR.md              ← run order and DONE conditions
    OUTPUT-STANDARDS.md          ← naming conventions and save paths
    07-strategy/INSTRUCTIONS.md
    01-seo-content/INSTRUCTIONS.md
    02-cro/INSTRUCTIONS.md
    03-content-copy/INSTRUCTIONS.md
    04-paid-measurement/INSTRUCTIONS.md
    05-growth-retention/INSTRUCTIONS.md
    06-sales-gtm/INSTRUCTIONS.md

context/[PROJECT-ID]/            ← product, ICP, and positioning context per project
  product-overview.md
  icp.md
  positioning.md
  messaging-hierarchy.md
  active-campaigns.md
  competitors.md
```

---

## How to Trigger the Full Team

### Daily Run

Trigger agents in this order. Steps 2 and 4 run in parallel; all others are sequential.

```
Step 1 (Sequential):   Run Agent 07 · Strategy
Step 2 (Parallel):     Run Agents 01 · SEO, 04 · Paid, 06 · GTM simultaneously
Step 3 (Sequential):   Run Agent 03 · Content & Copy
Step 4 (Parallel):     Run Agents 02 · CRO, 05 · Growth simultaneously
```

**Prompt to trigger each agent:**
> "You are [Agent Name]. Read your INSTRUCTIONS.md at `.agents/marketing-team/[agent-folder]/INSTRUCTIONS.md` and execute your daily task checklist for today, [DATE]. Follow all pre-task protocol steps before beginning. Active project: [PROJECT-ID]."

**Full team daily prompt:**
> "Trigger the marketing team daily run for [DATE] on project [PROJECT-ID]. Follow the sequence in `.agents/marketing-team/ORCHESTRATOR.md`. Begin with Agent 07 and proceed through the full daily trigger sequence."

---

### Weekly Run

**Monday — Direction setting:**
> "Trigger the marketing team weekly run for the week of [DATE], project [PROJECT-ID]. Begin with Agent 07's weekly direction-setting task. Once the Weekly Strategy Brief is saved, run Step 2 agents in parallel (01, 04, 06), followed by Agent 03, followed by parallel run of 02 and 05."

**Friday — Synthesis:**
> "Trigger Agent 07's weekly synthesis task for [DATE], project [PROJECT-ID]. Read all agent weekly reports and produce the Weekly Cross-Agent Synthesis Report."

---

## How to Trigger a Single Agent

**Prompt template:**
> "You are the [Agent Name]. Read your INSTRUCTIONS.md at `.agents/marketing-team/[agent-folder]/INSTRUCTIONS.md`. Also read `.agents/marketing-team/OUTPUT-STANDARDS.md` and `context/[PROJECT-ID]/`. Active project: [PROJECT-ID]. Then complete the following task: [specific task]."

**Examples:**

Run SEO agent for a content brief:
> "You are the SEO & Content Specialist. Read `.agents/marketing-team/01-seo-content/INSTRUCTIONS.md` and `context/[PROJECT-ID]/`. Active project: [PROJECT-ID]. Produce a content brief for the keyword [keyword] targeting [audience]."

Run CRO agent to audit a page:
> "You are the CRO Specialist. Read `.agents/marketing-team/02-cro/INSTRUCTIONS.md` and `context/[PROJECT-ID]/`. Active project: [PROJECT-ID]. Audit the [page name] page."

Run Content & Copy for a cold email sequence:
> "You are the Content & Copy Specialist. Read `.agents/marketing-team/03-content-copy/INSTRUCTIONS.md` and `context/[PROJECT-ID]/`. Active project: [PROJECT-ID]. Write a 5-email cold outbound sequence for [target role]."

---

## How to Review Outputs

### Daily Review (5 min)
1. Check `outputs/[PROJECT-ID]/marketing/07-strategy/` — confirm today's priority brief exists
2. Scan each agent's daily log for any `## ESCALATION REQUIRED` blocks
3. If no escalations: team ran successfully, no action needed
4. If escalation found: add `## OWNER RESPONSE` below it with your decision

### Weekly Review (15–20 min)
1. Read `outputs/[PROJECT-ID]/marketing/07-strategy/[PROJECT-ID]_MKT_07-STRAT_weekly-synthesis_[DATE].md`
2. Drill into any agent's weekly report if the synthesis flags a concern
3. Check any `## ESCALATION REQUIRED` blocks across all weekly reports

### Finding a Specific Deliverable

| What you're looking for | Where to find it |
|---|---|
| This week's strategic priorities | `outputs/[PROJECT-ID]/marketing/07-strategy/` |
| SEO performance | `outputs/[PROJECT-ID]/marketing/01-seo/` |
| Active A/B tests | `outputs/[PROJECT-ID]/marketing/02-cro/` |
| Finished copy or emails | `outputs/[PROJECT-ID]/marketing/03-content-copy/` |
| Paid spend and ROAS | `outputs/[PROJECT-ID]/marketing/04-paid-measurement/` |
| At-risk customers | `outputs/[PROJECT-ID]/marketing/05-growth-retention/` |
| Pipeline and win/loss | `outputs/[PROJECT-ID]/marketing/06-sales-gtm/` |

---

## Escalation Protocol

Agents surface to you only when:
- A budget decision is required
- A strategic pivot is needed (ICP, pricing, core positioning)
- A platform or account issue requires owner action
- A legal or compliance review is needed

**When you see an escalation:**
1. Open the file containing `## ESCALATION REQUIRED`
2. Read the situation, recommendation, and options
3. Add `## OWNER RESPONSE` below it with your decision
4. The agent will read this on its next run and proceed

---

## Adding a New Project

1. Create `context/[project-id]/` and populate all context files
2. Create output folders: `outputs/[project-id]/marketing/01-seo/` through `07-strategy/`
3. When triggering agents, specify `Active project: [PROJECT-ID]`
4. All outputs will be saved to `outputs/[project-id]/marketing/[agent]/`
