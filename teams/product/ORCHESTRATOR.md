# Product Team Orchestrator

Defines the canonical run order, trigger sequences, parallelism rules, and DONE conditions for all 5 product agents. Any orchestration system or human coordinator running this team must follow this spec.

---

## Agent Registry

| # | Agent | Folder | Specialty |
|---|-------|--------|-----------|
| 01 | CPO | `01-cpo/` | Vision, strategy, trade-offs, pricing |
| 02 | Director of Product | `02-director-product/` | Roadmap, PRDs, scoping, competitive intel |
| 03 | Product Operations Manager | `03-product-ops/` | OKRs, metrics, timelines, process |
| 04 | PM | `04-pm/` | Specs, user research, feature definition, PMF |
| 05 | APM | `05-apm/` | Surveys, onboarding, growth loops, launch support |

---

## Daily Trigger Sequence

```
STEP 1 — Sequential (gate for all others)
└── 01 · CPO
    DONE when: daily-strategic-brief-[TODAY].md exists in 01-cpo/outputs/

STEP 2 — Parallel (no dependencies between them)
├── 02 · Director of Product
│   Reads: strategic brief from CPO
└── 03 · Product Operations Manager
    Reads: strategic brief from CPO
    DONE when: both have saved their daily-*-log-[TODAY].md to their outputs/

STEP 3 — Sequential (depends on Step 2)
└── 04 · PM
    Reads: roadmap priorities and PRD queue from Director (02 outputs)
    Reads: OKR status and metrics flags from Product Ops (03 outputs)
    DONE when: daily-pm-log-[TODAY].md saved, inputs/ requests actioned or queued

STEP 4 — Sequential (depends on Step 3)
└── 05 · APM
    Reads: research needs and spec requests from PM (04 outputs + inputs/)
    Reads: priorities from Director (02 outputs)
    DONE when: daily-apm-log-[TODAY].md saved, all inputs/ requests actioned
```

**Daily run complete when:** All 5 agents have a daily log file for today in their respective `/outputs/` folders.

---

## Weekly Trigger Sequence

### Monday — Direction Setting

```
STEP 1 — Sequential
└── 01 · CPO
    Task: Review prior week synthesis, write Weekly Strategic Brief
    DONE when: weekly-strategic-brief-[DATE].md saved to 01-cpo/outputs/

STEP 2 — Parallel
├── 02 · Director of Product    (roadmap review + PRD queue update + competitive sweep)
└── 03 · Product Ops Manager    (OKR progress update + timeline audit + metrics review)
    DONE when: both weekly reports saved to their outputs/

STEP 3 — Sequential
└── 04 · PM
    Task: User research synthesis, spec backlog review, PMF signal check
    Reads: PRD priorities from Director, OKR status from Product Ops
    DONE when: weekly-pm-report-[DATE].md saved

STEP 4 — Sequential
└── 05 · APM
    Task: Survey analysis, onboarding review, growth loop audit, dogfooding log
    Reads: research needs from PM, launch priorities from Director
    DONE when: weekly-apm-report-[DATE].md saved
```

### Friday — Synthesis

```
STEP 5 — Sequential (after all agents complete their weekly tasks)
└── 01 · CPO
    Task: Read all 4 agent weekly reports, produce cross-team synthesis
    DONE when: weekly-synthesis-[DATE].md saved to 01-cpo/outputs/
```

**Weekly run complete when:** `weekly-synthesis-[DATE].md` exists in `01-cpo/outputs/`.

---

## Parallelism Rules

| Can run in parallel | Cannot run in parallel |
|---|---|
| 02 and 03 (Step 2) | 02 and 03 must wait for 01 (CPO brief) |
| — | 04 must wait for 02 and 03 |
| — | 05 must wait for 04 |
| — | 01 always runs first; nothing starts without its strategic brief |

**Rule:** No agent begins primary tasks until the CPO's `daily-strategic-brief` exists for today. If the brief does not exist, the agent must wait.

---

## DONE Conditions Per Agent

| Agent | Daily DONE Condition | Weekly DONE Condition |
|---|---|---|
| **01 CPO** | `daily-strategic-brief-[TODAY].md` saved in outputs/ | `weekly-strategic-brief-[DATE].md` (Mon) + `weekly-synthesis-[DATE].md` (Fri) |
| **02 Director of Product** | `daily-director-log-[TODAY].md` saved + `prd-queue.md` updated | `weekly-director-report-[DATE].md` saved + updated PRD queue in 04 inputs/ |
| **03 Product Ops** | `daily-ops-log-[TODAY].md` saved + `okr-tracker.md` updated | `weekly-ops-report-[DATE].md` saved + `timeline-tracker.md` updated |
| **04 PM** | `daily-pm-log-[TODAY].md` saved + inputs/ requests actioned | `weekly-pm-report-[DATE].md` saved + research briefs routed to 05 inputs/ |
| **05 APM** | `daily-apm-log-[TODAY].md` saved + inputs/ requests actioned | `weekly-apm-report-[DATE].md` saved + survey/dogfood findings routed to 04 inputs/ |

---

## Handoff Network

```
01 CPO
  → sends: daily-strategic-brief to all agents (02–05)
  → sends: weekly-strategic-brief to all agents
  ← receives: all weekly reports (02–05) for Friday synthesis

02 Director of Product
  → sends: PRD queue and roadmap priorities to 04 PM (via inputs/)
  → sends: competitive intel digests to 01 CPO (via inputs/)
  ← receives: strategic brief from 01 CPO
  ← receives: PMF signals and user research findings from 04 PM (via inputs/)

03 Product Operations Manager
  → sends: OKR status and metrics flags to 04 PM (via inputs/)
  → sends: timeline risks to 01 CPO (via inputs/)
  ← receives: strategic brief from 01 CPO

04 PM
  → sends: research briefs and spec requests to 05 APM (via inputs/)
  → sends: PMF signals and user research findings to 02 Director (via inputs/)
  ← receives: PRD queue from 02 Director (via inputs/)
  ← receives: OKR/metrics context from 03 Product Ops (via inputs/)
  ← receives: survey results and dogfood findings from 05 APM (via inputs/)

05 APM
  → sends: survey results, dogfood findings, onboarding issues to 04 PM (via inputs/)
  → sends: launch readiness status to 02 Director (via inputs/)
  ← receives: research briefs and spec requests from 04 PM (via inputs/)
  ← receives: roadmap priorities from 02 Director
```

---

## Escalation Routing

Agents escalate to the human owner only. Escalations are never routed to other agents.

**Escalation triggers (any agent):**
- Strategic pivot required (ICP, positioning, core product direction)
- Build/buy/partner decision required
- Budget decision required
- Legal, compliance, or security review needed
- Customer commitment or contractual decision required
- Data unrecoverable or blocker persists >24 hours

**Escalation format:** Append `## ESCALATION REQUIRED` block to current output file with: situation, decision needed, recommendation, options considered.

**Non-escalation:** Agents resolve ambiguity between themselves by writing to the relevant agent's `inputs/` folder and flagging in their daily log.

---

## Cross-Team Reference Paths

Product agents may read marketing team outputs. If you're running a marketing team alongside the product team, marketing outputs live at:

```
outputs/[PROJECT-ID]/marketing/07-strategy/     ← Marketing strategy and priorities
outputs/[PROJECT-ID]/marketing/06-sales-gtm/    ← Competitive intelligence (sales view)
outputs/[PROJECT-ID]/marketing/01-seo/          ← SEO and content signals
outputs/[PROJECT-ID]/marketing/02-cro/          ← Conversion and user behavior data
outputs/[PROJECT-ID]/marketing/03-content-copy/ ← Messaging and copy
```

**Cross-team read triggers:**
- CPO (01): Read Marketing Strategy weekly brief before writing strategic brief
- Director (02): Read Sales & GTM competitive intel before roadmap prioritization
- PM (04): Read CRO and Content outputs for messaging validation signals

**Shared project context:** `context/[PROJECT-ID]/`
**Project strategy docs:** `projects/[PROJECT-ID]/`

---

## Input/Output File Conventions

```
.agents/product-team/
├── [agent-folder]/
│   ├── INSTRUCTIONS.md       ← agent's autonomous operating instructions
│   ├── inputs/               ← receives requests from other agents
│   │   └── processed/        ← processed inputs moved here after actioning
│   └── outputs/              ← agent working state files live here

outputs/[PROJECT-ID]/product/[agent-folder]/   ← visible human-review copies
```

**File naming:** `[PROJECT-ID]_PRD_[AGENT-CODE]_[deliverable-type]_[YYYY-MM-DD].md`

- **Never overwrite:** Logs are append-only or dated — create new files per day/week
- **Inputs are consumed:** Log processing in daily log; move processed files to `inputs/processed/`
