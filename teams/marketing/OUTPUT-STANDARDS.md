# Output Standards — Marketing Team

All agents must save outputs to **both** locations on every run.

---

## Save Locations

### Local — hidden (agent working directory)
```
.agents/marketing-team/[agent]/outputs/[filename].md
```

### Local — visible (for human review)
```
outputs/[PROJECT-ID]/marketing/[agent-folder]/[filename].md
```

| Agent | Visible Folder |
|---|---|
| 01 SEO & Content | `outputs/[PROJECT-ID]/marketing/01-seo/` |
| 02 CRO | `outputs/[PROJECT-ID]/marketing/02-cro/` |
| 03 Content & Copy | `outputs/[PROJECT-ID]/marketing/03-content-copy/` |
| 04 Paid & Measurement | `outputs/[PROJECT-ID]/marketing/04-paid-measurement/` |
| 05 Growth & Retention | `outputs/[PROJECT-ID]/marketing/05-growth-retention/` |
| 06 Sales & GTM | `outputs/[PROJECT-ID]/marketing/06-sales-gtm/` |
| 07 Strategy | `outputs/[PROJECT-ID]/marketing/07-strategy/` |

**Substitute [PROJECT-ID] with your active project identifier.**

**All agents save to both locations on every run.**

### Optional: Cloud sync

If your team syncs outputs to a shared drive (Google Drive, OneDrive, etc.), add a third save location:
```
[CLOUD-SYNC-PATH]/[PROJECT-ID]/marketing/[Agent Folder]/[filename].md
```

---

## File Naming Convention

All markdown output files must use the full naming convention:

```
[PROJECT-ID]_[TEAM-CODE]_[AGENT-CODE]_[deliverable-type]_[YYYY-MM-DD].md
```

| Part | Values | Example |
|------|--------|---------|
| `PROJECT-ID` | Your project identifier | `ACME` |
| `TEAM-CODE` | `MKT` (always for marketing agents) | `MKT` |
| `AGENT-CODE` | `01-SEO`, `02-CRO`, `03-COPY`, `04-PAID`, `05-GROWTH`, `06-GTM`, `07-STRAT` | `07-STRAT` |
| `deliverable-type` | kebab-case descriptor | `weekly-strategy-brief` |
| `YYYY-MM-DD` | date produced | `2026-05-26` |

**Full examples:**
- `ACME_MKT_07-STRAT_weekly-strategy-brief_2026-05-26.md`
- `ACME_MKT_06-GTM_outbound-sequence_2026-05-26.md`
- `ACME_MKT_03-COPY_landing-page-copy_2026-05-26.md`
- `ACME_MKT_02-CRO_homepage-audit_2026-05-26.md`

---

## Format Routing

| Content Type | Format | Notes |
|---|---|---|
| Research, briefs, plans, calendars, drafts | `.md` | Default for all internal docs |
| Keyword lists, audit reports, copy drafts | `.md` | Always markdown |
| Client-facing reports, one-pagers, proposals | `.pdf` | Use the `pdf` skill to render |
| Formal campaign performance reports | `.pdf` | Monthly cadence |
| Outreach sequences, email drafts | `.md` | Tagged for future platform handoff |
| Landing page copy + CRO structure | `.md` → frontend-design skill → Design plugin | See Frontend Implementation rule below |

## Frontend Implementation Rule

Any run that produces a landing page asset (copy from Agent 03 + page structure from Agent 02) **must** pass through two additional review steps before the output is considered complete:

**Step 1 — frontend-design skill**
- Triggered by: Agent 02 CRO page structure + Agent 03 landing page copy existing together
- Task: Build a production-grade HTML/CSS/JS implementation using the copy and structure as inputs
- Output: A working implementation file saved alongside the source copy in the same `outputs/` folder
- Naming: `[PROJECT-ID]_MKT_[AGENT-CODE]_landing-page-impl_[YYYY-MM-DD].html`
- The skill must commit to a bold, intentional aesthetic direction — no generic AI defaults

**Step 2 — Design plugin review**
- Triggered by: Completion of the frontend-design pass (or any visual/copy output, even without an implementation)
- Task: Final critique covering copy effectiveness, visual design quality, conversion alignment, and messaging clarity
- Output: Review notes appended to the relevant output file or saved as `[filename]-design-review.md`
- This is the final gate before any landing page is considered ready for deployment or human review

---

## Context Files

Load project context from: `context/[PROJECT-ID]/`

| File | Contents |
|---|---|
| `context/[PROJECT-ID]/product-overview.md` | Product description, key features, pricing |
| `context/[PROJECT-ID]/icp.md` | Ideal customer profile |
| `context/[PROJECT-ID]/positioning.md` | Category, differentiation, messaging |
| `context/[PROJECT-ID]/messaging-hierarchy.md` | Primary message, proof points, tone |
| `context/[PROJECT-ID]/active-campaigns.md` | Currently live campaigns |
| `context/[PROJECT-ID]/competitors.md` | Competitors and differentiators |

---

## Cross-Team Reference Paths

Marketing agents may read product team outputs for context. Use these paths:

| What to read | Path |
|---|---|
| CPO vision and strategic direction | `outputs/[PROJECT-ID]/product/01-cpo/` |
| Product roadmap and PRDs | `outputs/[PROJECT-ID]/product/02-director/` |
| OKR and metrics context | `outputs/[PROJECT-ID]/product/03-product-ops/` |
| User research and PMF signals | `outputs/[PROJECT-ID]/product/04-pm/` |
| Validation research | `outputs/[PROJECT-ID]/product/05-apm/` |

**When to read cross-team outputs:**
- Agent 07 (Strategy): Read CPO brief before writing weekly strategy brief — ensures marketing and product are aligned
- Agent 06 (Sales & GTM): Read Director PRDs before writing sales enablement materials
- Agent 03 (Content & Copy): Read PM specs before writing feature-specific copy

---

## Integration Hook Tags

| Tag | Meaning |
|---|---|
| `<!-- JIRA: create-ticket -->` | Ready to become a Jira task |
| `<!-- JIRA: update-ticket [TICKET-ID] -->` | Update an existing Jira ticket |
| `<!-- LINKEDIN: ready-to-post -->` | Approved for LinkedIn publishing |
| `<!-- EMAIL: outreach-sequence -->` | Ready for email platform handoff |
| `<!-- EMAIL: newsletter -->` | Ready for newsletter send |
| `<!-- REVIEW: needs-human -->` | Escalation — requires owner decision before use |

---

## Escalation Rule

Only surface to the human owner if:
- A blocker prevents task completion
- A decision requires budget approval
- An output is tagged `<!-- REVIEW: needs-human -->`

All other outputs go directly to both save locations above.
