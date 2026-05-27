# Output Standards — Product Team

All agents must save outputs to **both** locations on every run.

---

## Save Locations

### Local — hidden (agent working directory)
```
.agents/product-team/[agent]/outputs/[filename].md
```

### Local — visible (for human review)
```
outputs/[PROJECT-ID]/product/[agent-folder]/[filename].md
```

| Agent | Visible Folder |
|---|---|
| 01 CPO | `outputs/[PROJECT-ID]/product/01-cpo/` |
| 02 Director of Product | `outputs/[PROJECT-ID]/product/02-director-product/` |
| 03 Product Ops Manager | `outputs/[PROJECT-ID]/product/03-product-ops/` |
| 04 PM | `outputs/[PROJECT-ID]/product/04-pm/` |
| 05 APM | `outputs/[PROJECT-ID]/product/05-apm/` |

**Substitute [PROJECT-ID] with your active project identifier.**

**All agents save to both locations on every run.**

### Optional: Cloud sync

If your team syncs outputs to a shared drive (Google Drive, OneDrive, etc.), add a third save location:
```
[CLOUD-SYNC-PATH]/[PROJECT-ID]/product/[Agent Folder]/[filename].md
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
| `TEAM-CODE` | `PRD` (always for product agents) | `PRD` |
| `AGENT-CODE` | `01-CPO`, `02-DIR`, `03-OPS`, `04-PM`, `05-APM` | `01-CPO` |
| `deliverable-type` | kebab-case descriptor | `vision-brief` |
| `YYYY-MM-DD` | date produced | `2026-05-26` |

**Full examples:**
- `ACME_PRD_01-CPO_vision-brief_2026-05-26.md`
- `ACME_PRD_02-DIR_prd-secure-ai-chat_2026-05-26.md`
- `ACME_PRD_04-PM_user-interview-synthesis_2026-05-26.md`
- `ACME_PRD_05-APM_fake-door-brief-legal_2026-05-26.md`

---

## Format Routing

| Content Type | Format | Notes |
|---|---|---|
| Briefs, strategy docs, daily logs, research | `.md` | Default for all internal docs |
| PRDs, specs, design docs | `.md` | Markdown always; convert to PDF on request |
| Investor/partner-facing docs, one-pagers | `.pdf` | Use `pdf` skill to render |
| Roadmaps, OKR trackers, backlog | `.md` | Keep as markdown |
| Survey instruments, interview guides | `.md` | Tagged for handoff |
| Launch plans, go-to-market docs | `.md` | Tagged for review |

---

## Context Files

Load project context from: `context/[PROJECT-ID]/`

| File | Contents |
|---|---|
| `context/[PROJECT-ID]/product-overview.md` | Product description, key features, pricing |
| `context/[PROJECT-ID]/icp.md` | Ideal customer profile |
| `context/[PROJECT-ID]/positioning.md` | Category, differentiation, messaging |
| `context/[PROJECT-ID]/competitors.md` | Competitors and differentiators |
| `context/[PROJECT-ID]/product-roadmap.md` | Current roadmap state |

Also read project strategy docs from: `projects/[PROJECT-ID]/`

---

## Cross-Team Reference Paths

Product agents may read marketing team outputs for alignment. Use these paths:

| What to read | Path |
|---|---|
| Marketing strategy and priorities | `outputs/[PROJECT-ID]/marketing/07-strategy/` |
| Competitive intelligence (marketing view) | `outputs/[PROJECT-ID]/marketing/06-sales-gtm/` |
| SEO and content signals | `outputs/[PROJECT-ID]/marketing/01-seo/` |
| Conversion and user behavior signals | `outputs/[PROJECT-ID]/marketing/02-cro/` |
| Positioning and messaging copy | `outputs/[PROJECT-ID]/marketing/03-content-copy/` |

**When to read cross-team outputs:**
- CPO (01): Read Marketing Strategy weekly brief before writing strategic brief — ensures product and marketing are aligned
- Director of Product (02): Read Sales & GTM competitive intel before roadmap prioritization
- PM (04): Read CRO and Content outputs for messaging validation signals

---

## Integration Hook Tags

| Tag | Meaning |
|---|---|
| `<!-- JIRA: create-ticket -->` | Ready to become a Jira task |
| `<!-- JIRA: update-ticket [TICKET-ID] -->` | Update an existing Jira ticket |
| `<!-- REVIEW: needs-human -->` | Escalation — requires owner decision before use |
| `<!-- PUBLISH: ready -->` | Approved for external use |
| `<!-- FAKE-DOOR: ready -->` | Validated copy ready for fake door test deployment |
| `<!-- PRD: ready-for-build -->` | PRD approved and ready for engineering handoff |

---

## Escalation Rule

Only surface to the human owner if:
- A strategic or budget decision is required
- An output is tagged `<!-- REVIEW: needs-human -->`
- A blocker prevents task completion for >24 hours

All other outputs go directly to both save locations without human approval.
