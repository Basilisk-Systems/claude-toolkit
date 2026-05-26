# Marketing Team Orchestrator

This file defines the canonical run order, trigger sequences, parallelism rules, and DONE conditions for all 7 marketing agents. Any orchestration system, automation, or human coordinator running this team must follow this spec.

---

## Agent Registry

| # | Agent | Folder | Specialty |
|---|-------|--------|-----------|
| 07 | Strategy Specialist | `07-strategy/` | Priorities, positioning, cross-agent synthesis |
| 01 | SEO & Content Specialist | `01-seo-content/` | Organic search, content production |
| 04 | Paid Media & Measurement | `04-paid-measurement/` | Paid channels, analytics, attribution |
| 06 | Sales & GTM Specialist | `06-sales-gtm/` | RevOps, enablement, competitive intel |
| 03 | Content & Copy Specialist | `03-content-copy/` | Copywriting, email, social, ad copy |
| 02 | CRO Specialist | `02-cro/` | Conversion optimization, A/B testing |
| 05 | Growth & Retention | `05-growth-retention/` | Referral, free tools, churn prevention |

---

## Daily Trigger Sequence

```
STEP 1 — Sequential (gate for all others)
└── 07 · Strategy
    DONE when: daily-priority-brief-[TODAY].md exists in 07-strategy/outputs/

STEP 2 — Parallel (no dependencies between them)
├── 01 · SEO & Content
├── 04 · Paid & Measurement
└── 06 · Sales & GTM
    DONE when: all three have saved their daily-*-log-[TODAY].md to their outputs/

STEP 3 — Sequential (depends on Step 2)
└── 03 · Content & Copy
    Reads: inputs/ from 01 (briefs) and 06 (copy requests)
    DONE when: daily-copy-log-[TODAY].md saved, all inputs/ requests actioned or queued

STEP 4 — Parallel (no dependencies between them)
├── 02 · CRO
│   Reads: post-click data from 04 outputs
└── 05 · Growth & Retention
    Reads: CAC data from 04 outputs, ICP data from 06 outputs
    DONE when: both have saved their daily-*-log-[TODAY].md to their outputs/

STEP 5 — Frontend Design Pass (landing page outputs only)
└── frontend-design skill
    Trigger: Any run where Agent 02 or Agent 03 produces a landing page asset
    Input: Agent 03 copy + Agent 02 page structure/CRO spec
    Task: Build a production-grade HTML/CSS/JS implementation from the copy and structure spec
    DONE when: implementation file saved alongside the source copy/spec in the same outputs/ folder

STEP 6 — Design Plugin Review (final gate for all visual/copy outputs)
└── Design plugin
    Trigger: Every run — reviews all outputs from agents 02, 03, and the frontend-design pass
    Task: Final critique of copy quality, visual design, conversion alignment, and messaging effectiveness
    DONE when: design review notes appended to the relevant output file or saved as a companion review file
```

**Daily run complete when:** All 7 agents have a daily log file for today in their respective `/outputs/` folders. Any landing page outputs have passed the frontend-design skill and Design plugin review steps.

---

## Weekly Trigger Sequence

### Monday — Direction Setting

```
STEP 1 — Sequential
└── 07 · Strategy
    Task: Pull all prior week reports, write Weekly Strategy Brief
    DONE when: weekly-strategy-brief-[DATE].md saved to 07-strategy/outputs/

STEP 2 — Parallel
├── 01 · SEO & Content    (deep content audit + calendar update)
├── 04 · Paid & Measurement    (campaign structure review + creative brief)
└── 06 · Sales & GTM    (win/loss analysis + competitive digest)
    DONE when: all three weekly reports saved to their outputs/

STEP 3 — Sequential
└── 03 · Content & Copy
    Task: Social batch creation, email sequence audit, cold email writing
    Reads: briefs from 01, copy requests from 06
    DONE when: weekly-copy-report-[DATE].md saved, all assets routed to requesting agents

STEP 4 — Parallel
├── 02 · CRO
│   Task: ICE backlog reprioritization, page audit, test design
│   Reads: post-click data from 04, copy from 03
└── 05 · Growth & Retention
    Task: Churn cohort analysis, referral review, win-back campaign
    Reads: CAC from 04, ICP data from 06
    DONE when: both weekly reports saved to their outputs/
```

### Friday — Synthesis

```
STEP 5 — Sequential (after all agents complete their weekly tasks)
└── 07 · Strategy
    Task: Read all 6 agent weekly reports, produce cross-agent synthesis
    DONE when: weekly-synthesis-[DATE].md saved to 07-strategy/outputs/
```

**Weekly run complete when:** `weekly-synthesis-[DATE].md` exists in `07-strategy/outputs/`.

---

## Parallelism Rules

| Can run in parallel | Cannot run in parallel |
|---|---|
| 01, 04, 06 (Step 2) | 03 must wait for 01 and 06 |
| 02, 05 (Step 4) | 02 and 05 must wait for 04 |
| — | 07 always runs first; nothing starts without its priority brief |
| — | frontend-design pass must wait for both 03 (copy) and 02 (page structure) |
| — | Design plugin review runs last — after frontend-design pass if applicable |

**Rule:** An agent may not begin its primary tasks until its `Pre-Task Protocol` has been completed, including reading the Strategy agent's daily priority brief. If the brief does not exist, the agent must wait.

---

## DONE Conditions Per Agent

| Agent | Daily DONE Condition | Weekly DONE Condition |
|---|---|---|
| **07 Strategy** | `daily-priority-brief-[TODAY].md` saved in outputs/ | `weekly-strategy-brief-[DATE].md` (Mon) + `weekly-synthesis-[DATE].md` (Fri) |
| **01 SEO & Content** | `daily-seo-log-[TODAY].md` saved + `content-queue.md` updated | `weekly-seo-report-[DATE].md` saved + ≥2 briefs in Agent 03 inputs/ |
| **04 Paid & Measurement** | `daily-paid-log-[TODAY].md` saved + `campaign-tracker.md` updated | `weekly-paid-report-[DATE].md` saved + CAC data in Agent 05 inputs/ |
| **06 Sales & GTM** | `daily-gtm-log-[TODAY].md` saved + `competitive-log.md` updated | `weekly-sales-report-[DATE].md` + `competitive-digest-[DATE].md` saved |
| **03 Content & Copy** | `daily-copy-log-[TODAY].md` saved + all inputs/ requests actioned | `weekly-copy-report-[DATE].md` saved + all finished assets routed |
| **02 CRO** | `daily-cro-log-[TODAY].md` saved + `test-tracker.md` updated | `weekly-cro-report-[DATE].md` saved + ICE backlog updated |
| **05 Growth & Retention** | `daily-retention-log-[TODAY].md` saved + `at-risk-accounts.md` updated | `weekly-retention-report-[DATE].md` saved + briefs sent to Agent 03 |

---

## Escalation Routing

Agents escalate to the human owner only. Escalations are never routed to other agents.

**Escalation triggers (any agent):**
- Budget decision required
- Platform suspension or account issue
- Legal or compliance review required
- Strategic pivot needed (ICP, pricing, core positioning)
- Data unrecoverable for >24 hours

**Escalation format:** All agents append an `## ESCALATION REQUIRED` block to their current output file. The orchestrator surfaces any file containing this block to the human owner before proceeding.

**Non-escalation:** Agents resolve ambiguity between themselves by writing to the relevant agent's `inputs/` folder and flagging in their daily log. Human is not involved in agent-to-agent clarification.

---

## Cross-Team Reference Paths

Marketing agents may read product team outputs. If you're running a product team alongside the marketing team, product outputs live at:

```
outputs/[PROJECT-ID]/product/01-cpo/           ← CPO vision and strategic direction
outputs/[PROJECT-ID]/product/02-director/       ← Roadmap priorities and PRDs
outputs/[PROJECT-ID]/product/03-product-ops/    ← OKR and metrics context
outputs/[PROJECT-ID]/product/04-pm/             ← User research and PMF signals
outputs/[PROJECT-ID]/product/05-apm/            ← Validation research
```

**Cross-team read triggers:**
- Agent 07 (Strategy): Read CPO brief before writing weekly strategy brief
- Agent 06 (Sales & GTM): Read Director PRDs before writing sales enablement
- Agent 03 (Content & Copy): Read PM specs before writing feature copy

**Shared project context:** `context/[PROJECT-ID]/`

---

## Input/Output File Conventions

```
.agents/marketing-team/
├── [agent-folder]/
│   ├── INSTRUCTIONS.md       ← agent's autonomous operating instructions
│   ├── inputs/               ← receives requests from other agents
│   └── outputs/              ← agent working state files live here

outputs/[PROJECT-ID]/marketing/[agent-folder]/   ← visible human-review copies
```

**File naming:** `[PROJECT-ID]_MKT_[AGENT-CODE]_[deliverable-type]_[YYYY-MM-DD].md`

- **Never overwrite:** Logs are append-only or dated — create new files per day/week
- **Inputs are consumed:** Log processing in daily log; move processed files to `inputs/processed/`
