---
name: legal-drafting
description: Draft legal documents (contracts, NDAs, SOWs, referral agreements, contractor agreements) for Basilisk Systems, LLC under Maryland law. TRIGGER when user asks to draft, write, or review a contract, agreement, NDA, SOW, referral agreement, finder's fee agreement, engagement letter, or any legal document. Do NOT trigger for code comments, commit messages, or non-legal prose.
allowed-tools: Read, Write, Edit, Bash, AskUserQuestion, WebSearch, WebFetch
---

# Legal Document Drafting Skill

Draft legal documents for **Basilisk Systems, LLC**, a Maryland limited liability company headquartered in Anne Arundel County, Maryland.

**This skill is not legal advice. Every document produced is a draft intended for attorney review before execution or reliance in any legal proceeding.**

---

## Document Output

All documents are output as `.docx` files using `python-docx` to the following directory structure:

```
~/basilisk_systems/legal/YYYY/MM/DD/<document_name>.docx
```

Where `YYYY/MM/DD` is the draft date and `<document_name>` follows the naming convention `[TYPE]-[counterparty-slug]-[YYYYMMDD]` (e.g., `NDA-acme-corp-20260602.docx`).

### DOCX Generation

Before generating any document, ensure `python-docx` is installed:

```bash
uv pip install python-docx
```

Then generate the `.docx` using a Python script. The script must:
1. Create the output directory: `~/basilisk_systems/legal/YYYY/MM/DD/`
2. Apply professional formatting:
   - Title: 16pt bold, centered
   - Section headers: 12pt bold, numbered hierarchically (1, 1.1, 1.1.1)
   - Body text: 11pt, justified, 1.15 line spacing
   - Defined terms: bold on first use
   - Page margins: 1 inch all sides
3. Include the disclaimer header on page 1
4. Include footer text on every page: `[Document ID] | DRAFT — NOT ATTORNEY REVIEWED`
5. Include signature blocks at the end
6. Prevent orphaned signature blocks — the signature area must never appear on a page by itself. Apply `keep_with_next` to all paragraphs in the final substantive section (header + body) and `keep_together` on the signature block so they are anchored to the same page. In `python-docx`, set these via:
   ```python
   paragraph.paragraph_format.keep_with_next = True   # final section paragraphs
   paragraph.paragraph_format.keep_together = True     # signature block paragraphs
   ```
   At minimum, the last section header and its body text must share a page with the signature block.

Write the Python generation script to a temporary file, execute it, then clean up.

---

## Mandatory Disclaimer Block

Every document MUST begin with this disclaimer before any substantive content:

```
DRAFT — PREPARED WITHOUT LEGAL COUNSEL

This document was drafted using AI assistance and has not been reviewed by a
licensed attorney. Basilisk Systems, LLC intends to have this document reviewed
by legal counsel before relying on it in any legal proceeding. This draft is
provided for internal planning purposes only.

Draft Date: [DATE]
Document ID: [TYPE]-[YYYYMMDD]-[SEQ]
```

---

## Company Information (Default "Company" Party)

Unless overridden by the user:

- **Legal Name:** Basilisk Systems, LLC
- **Entity Type:** Maryland Limited Liability Company
- **Principal Office:** Anne Arundel County, Maryland
- **State of Formation:** Maryland
- **Governing Law:** State of Maryland

---

## Governing Law and Jurisdiction Defaults

- **Governing Law:** Laws of the State of Maryland, without regard to conflict of law principles
- **Jurisdiction:** State and federal courts located in Anne Arundel County, Maryland
- **Dispute Resolution Default:** Good-faith negotiation (30 days), then mediation, then litigation in Anne Arundel County. User may override to include binding arbitration.

---

## Supported Document Types

### 1. Independent Contractor Agreement (ICA)

Required provisions:

- **Scope of Work** — as exhibit/schedule; reference a separate SOW if applicable
- **Compensation and Payment Terms** — rate type (hourly/fixed/milestone), invoicing schedule, net payment terms, late payment interest (default: 1.5% per month or maximum permitted by Maryland law, whichever is less; legal rate for judgments is 10% per annum per Md. Code, Cts. & Jud. Proc. Section 11-107)
- **Independent Contractor Status** — this is critical and must include:
  - Contractor controls manner, method, and means of performing work
  - Contractor sets own hours and work location
  - Contractor provides own tools and equipment
  - Contractor may engage subcontractors (with Company approval)
  - Contractor is free to perform services for other clients
  - Company will not provide employee benefits
  - Contractor responsible for all taxes including self-employment tax
  - Contractor maintains own business entity, insurance, and licenses
  - Form W-9 requirement before first payment
- **Term and Termination** — start date, end date or ongoing with renewal, termination for convenience (with notice period, typically 15-30 days), termination for cause (material breach with cure period, typically 10-15 days)
- **Intellectual Property Assignment** — CRITICAL: software created by independent contractors does NOT qualify as "work made for hire" under the Copyright Act (17 U.S.C. Section 101) because software is not among the nine enumerated categories. Every ICA must include BOTH:
  1. A work-for-hire clause (to cover any deliverable that might qualify under the nine categories)
  2. A present-tense irrevocable assignment: "Contractor hereby irrevocably assigns to Company all right, title, and interest in and to all Work Product..."
  3. A power of attorney clause authorizing Company to execute assignment documents if Contractor fails to cooperate
  4. Moral rights waiver to the extent permitted by law
- **Pre-Existing IP Reservation** — require Contractor to list all pre-existing IP on an exhibit at signing. Anything not listed is presumed created under the contract. Grant Company a perpetual, royalty-free, non-exclusive license to any pre-existing IP incorporated into deliverables.
- **Open Source Disclosure** — Contractor must disclose all open source components before incorporation. Copyleft licenses (GPL, AGPL, LGPL) require prior written approval. Permissive licenses (MIT, BSD, Apache 2.0) acceptable with notice. Contractor warrants compliance with all applicable open source licenses.
- **Confidentiality** — inline or by reference to a separate NDA. Must include the DTSA whistleblower notice (see Federal Requirements below).
- **Non-Solicitation** — of Company clients and employees, reasonable duration (12-24 months). Non-solicitation is explicitly excluded from Maryland's noncompete restrictions under Lab. & Empl. Section 3-716 and is generally enforceable.
- **Non-Compete** — include ONLY if the user explicitly requests it. Notes for the user:
  - Maryland Lab. & Empl. Section 3-716 restricts noncompetes for *employees* earning 150% or less of state minimum wage (currently ~$22.50/hr). The statute applies to "employment contracts" and "employees" only, not independent contractors.
  - For contractors, noncompete enforceability depends on common law reasonableness: limited in scope, duration (typically 6-12 months), and geography.
  - Non-solicitation clauses are safer and more enforceable. Recommend non-solicitation over non-compete unless there is a specific business reason.
- **Representations and Warranties** — authority to enter agreement, no conflicts with other obligations, compliance with applicable laws, work product will not infringe third-party IP
- **Indemnification** — mutual:
  - Contractor indemnifies Company for: IP infringement from pre-existing IP or open source violations, contractor negligence, breach of contractor status representations, tax liabilities
  - Company indemnifies Contractor for: claims arising from Company-provided materials/specifications, Company negligence
- **Limitation of Liability** — cap at total fees paid in prior 12 months. Carve-outs from the cap (unlimited liability): willful misconduct, gross negligence, IP indemnification, confidentiality breach involving PII, contractor misclassification tax liability. Exclude consequential, incidental, and punitive damages except for the carve-out items.
- **Insurance** — Contractor maintains: general liability ($1M per occurrence / $2M aggregate minimum), professional liability/E&O ($1M minimum if applicable), workers' compensation as required by law
- **Data Protection** — if Contractor will handle personal information of Maryland residents, include clauses required by the Maryland Personal Information Protection Act (Md. Code, Com. Law Section 14-3501 et seq.): implement and maintain reasonable security procedures, breach notification within 24-72 hours to Company, Company will handle statutory notification to MD Attorney General and consumers within 45 days

**ABC Test Warning:** Under Maryland's Workplace Fraud Act and unemployment insurance law, a worker is presumed to be an employee unless ALL three conditions of the ABC test are met: (A) free from control, (B) work is outside the company's usual course of business, (C) worker has an independently established trade or business. **Prong B is dangerous for software companies hiring software developers** — if Basilisk Systems' core business is software development, hiring contractors to do software development may fail prong B. Mitigation: engage contractors for specialized work (design, DevOps, security auditing, specific technology expertise outside core competency), ensure contractors have their own business entities and multiple clients, structure SOWs around deliverables rather than hours. Flag this risk to the user when drafting an ICA for software development work.

### 2. Non-Disclosure Agreement (NDA)

Required provisions:

- **Type** — mutual or unilateral (prompt the user if not specified)
- **Definition of Confidential Information** — broad definition aligned with MUTSA (Md. Code, Com. Law Section 11-1201 et seq.): information deriving economic value from secrecy, subject to reasonable efforts to maintain secrecy. Extend contractually to cover non-trade-secret business information. Standard exclusions: (a) publicly available through no fault of receiving party, (b) already known to receiving party without obligation of confidentiality, (c) independently developed without use of disclosing party's confidential information, (d) rightfully received from third party without restriction, (e) compelled by law or court order (with prompt notice to disclosing party)
- **Permitted Disclosures** — to employees, contractors, and advisors who need to know and are bound by substantially similar confidentiality obligations
- **Term of Confidentiality** — standard: 2-3 years after disclosure. Trade secrets: indefinite duration while information qualifies as a trade secret under MUTSA. Prompt user for preference.
- **Return/Destruction** — upon termination or written request, return or destroy all confidential information and certify in writing. Permitted to retain copies required by law or automatic backup systems, subject to continued confidentiality obligations.
- **Remedies** — acknowledge that breach may cause irreparable harm for which monetary damages are inadequate; right to seek injunctive relief without posting bond to the extent permitted by applicable law. MUTSA provides: injunctive relief (Section 11-1202), actual damages plus unjust enrichment (Section 11-1203), exemplary damages up to 2x for willful/malicious misappropriation, and attorney's fees (Section 11-1204).
- **Residuals Clause** — ask the user if they want one (permits use of residual knowledge retained in unaided memory). Common in mutual NDAs between technology companies. Omit by default for unilateral NDAs where Basilisk Systems is disclosing.
- **DTSA Whistleblower Notice** — REQUIRED (see Federal Requirements below)

### 3. Statement of Work (SOW)

Required provisions:

- **Master Agreement Reference** — identify the governing ICA or MSA; specify order of precedence (typically: SOW-specific terms > MSA/ICA general terms)
- **Project Description** — detailed scope narrative
- **Deliverables** — specific, measurable, with defined acceptance criteria for each
- **Timeline and Milestones** — dates or durations, dependencies
- **Compensation** — fixed fee, time-and-materials with cap, or milestone-based. Specify invoicing cadence and payment terms (or reference master agreement).
- **Acceptance Process** — review period (typically 10-15 business days), defect severity classification, number of correction cycles (typically 2-3), deemed acceptance if no response within review period, percentage withheld until acceptance (10-20% of final milestone)
- **Change Order Process** — changes require written change order signed by both parties, specify impact on timeline and cost
- **Project-Specific IP Terms** — if different from master agreement (e.g., client retains certain IP, license-back to Basilisk Systems)
- **Key Personnel** — if applicable, identify by name or role
- **Assumptions and Dependencies** — what the client must provide (access, credentials, documentation, decisions by certain dates)

### 4. Master Services Agreement (MSA)

Includes all ICA provisions above PLUS:

- **SOW Framework** — how SOWs are created, incorporated, and amended; order of precedence
- **Service Level Agreements** — if applicable (uptime, response times, resolution times)
- **Data Protection** — if handling PII, include Maryland PIPA requirements. If processing consumer data on behalf of clients, evaluate whether Maryland Online Data Privacy Act (MODPA, effective October 1, 2025, enforcement from April 1, 2026) requires Data Processing Agreement provisions: data processing purpose limitations, deletion/return upon termination, audit rights, subprocessor requirements.
- **Force Majeure** — excuses performance for events beyond reasonable control; does not excuse payment obligations
- **Assignment** — not assignable without prior written consent; Company may assign in connection with merger, acquisition, or sale of substantially all assets
- **Notices** — written notice to specified addresses, effective upon receipt (email acceptable with confirmation of receipt or read receipt)
- **Entire Agreement / Amendment** — this agreement together with all SOWs constitutes the entire agreement; amendments require written agreement signed by both parties
- **Severability** — if any provision is found unenforceable, remainder continues in full force
- **Waiver** — no waiver unless in writing signed by the waiving party; failure to enforce any provision is not a waiver of future enforcement
- **Counterparts / Electronic Signatures** — valid under Maryland UETA (Md. Code, Com. Law Section 21-101 et seq.) and federal E-SIGN Act (15 U.S.C. Section 7001). Note: for standard form contracts, agreement to electronic signature must be "conspicuously displayed and separately consented to" per UETA Section 21-104(b)(3).

### 5. Engagement Letter

Lighter-weight alternative for small engagements (under $10,000 or short duration):

- **Services Description** — brief scope
- **Fees and Payment** — rate, estimated total, payment terms
- **Term** — start and expected end
- **IP Assignment** — brief assignment clause with work-for-hire and present-tense assignment language
- **Confidentiality** — brief clause or reference to separate NDA; include DTSA notice
- **Termination** — either party with written notice (typically 7-15 days)
- **Governing Law** — Maryland

### 6. Subcontractor Agreement

Similar to ICA with these additions:

- **Flow-Down Provisions** — specific obligations from the prime contract that flow to subcontractor (do not use blanket "all terms flow down" without identifying specific provisions)
- **Back-to-Back Terms** — subcontractor bound by same delivery timelines, quality standards, and IP terms as Company has with its client
- **Client Approval** — if prime contract requires client approval of subcontractors
- **Direct Communication** — specify whether subcontractor may communicate directly with end client (default: no, all communication through Company)
- **Compliance** — subcontractor must comply with all applicable laws, including Maryland's worker classification requirements for their own workers

### 7. Referral Agreement / Finder's Fee Agreement

For consultants or individuals who refer business leads to the Company. The referrer is a "finder" — they introduce potential clients but do NOT participate in discovery, demos, negotiations, or closing. This is distinct from a sales commission agreement (referrer does not sell), an affiliate agreement (not automated/link-tracked), and a broker agreement (referrer does not negotiate deals).

**Finder vs. Broker Distinction:** This is legally significant. A finder merely introduces parties; a broker negotiates and facilitates transactions. Brokers often require licensing; finders generally do not. Maryland does not require any license or registration for a person who merely refers software/SaaS customers. Maryland's finder's fee statutes (Md. Code, Com. Law, Title 12, Subtitle 8, Sections 12-804 and 12-805) apply only to mortgage/lending transactions, not general business referrals. No SEC/broker-dealer registration is triggered because this is a commercial product referral, not a securities transaction.

**Critical guardrail to enforce:** The referrer must NOT negotiate deal terms, participate in demos or sales calls, advise on pricing, or handle customer funds. Any of these activities could reclassify them from finder to broker.

Required provisions:

- **Referrer's Role** — clearly define the referrer's sole activity: identifying and introducing potential clients to the Company. Explicitly state what the referrer may NOT do: negotiate, participate in sales process, make representations about Company's products/services, bind the Company, or handle customer funds.
- **Qualified Lead Definition** — minimum criteria for a referral to be eligible for compensation:
  - Named contact at an identifiable company
  - Confirmed potential need for Company's services
  - No pre-existing relationship between Company and the prospect (define lookback period, e.g., prospect was not already in Company's CRM or pipeline within 90 days prior to referral)
  - Referrer must provide: prospect name, title, company, contact information, and brief description of potential need
- **Lead Registration Process** — how referrals are submitted and tracked:
  - Written submission required (email to designated address or form)
  - Company acknowledges receipt within a defined period (e.g., 5 business days)
  - Company confirms whether lead is "Accepted" (new, eligible for fee) or "Rejected" (already known/in pipeline) within a defined period (e.g., 10 business days)
  - If Company does not respond within the confirmation period, lead is deemed Accepted
- **Compensation Structure** — prompt user for preferred model:
  - **Flat Fee:** fixed amount per closed deal, optionally tiered by deal size (e.g., $500 for deals under $10K, $1,000 for $10K-$50K, $2,500 for over $50K)
  - **Percentage:** percentage of the initial payment received from the referred customer (typical range: 5-15% of first year contract value)
  - **Hybrid:** flat fee for smaller deals, percentage for larger deals
  - Payment is triggered only upon Company's receipt of payment from the customer (not upon contract signing)
  - Payment due to Referrer within a defined period after Company receives customer payment (e.g., net 30)
- **Protection Period / Tail Period** — how long after a referral the referrer retains credit:
  - Standard: 6-12 months from the date of accepted referral
  - If the referred lead becomes a paying customer within this window, compensation is owed
  - After the window closes, the referral expires and no fee is owed
  - Post-termination tail: 90-180 days covering leads submitted before the agreement ends
- **Exclusivity** — default to non-exclusive. Company retains the right to pursue leads through any channel. Referrer may refer leads to other companies. Ask user if exclusive arrangement is desired (unusual for finder relationships).
- **Duplicate Referrals** — first-to-register wins. If Company already has the lead in its pipeline before the referral submission, no fee is owed. If two referrers submit the same lead, the first submission with a confirmed timestamp prevails.
- **Minimum Deal Size** — optional threshold below which no fee is owed (e.g., no fee on contracts under $1,000). Reduces administrative overhead on trivial deals.
- **No Recurring Commissions** — referral fee is a one-time payment for the initial transaction. No ongoing commissions on renewals, upsells, or expansions unless explicitly agreed. Ask user if recurring commission is desired.
- **Independent Contractor Status** — referrer is an independent contractor, not an employee, agent, or representative of Company. Include standard IC language.
- **Confidentiality** — referrer may learn about Company's products, pricing, and pipeline. Include confidentiality provisions and DTSA whistleblower notice.
- **Non-Solicitation** — referrer may not solicit Company's existing clients or employees (reasonable duration, 12 months)
- **Representations** — referrer will comply with all applicable laws; referrer will not make misleading representations about Company or its products; referrer has authority to enter the agreement
- **Term and Termination** — initial term (e.g., 1 year), auto-renewal, termination for convenience with notice (30 days), termination for cause. Survival: confidentiality, payment obligations for leads submitted during term, indemnification.
- **Tax Provisions:**
  - Form W-9 required before first payment
  - Company will issue Form 1099-NEC for payments of $600+ in a calendar year (threshold may increase to $2,000 per recent IRS changes — verify current threshold at time of drafting)
  - If referrer fails to provide valid TIN, Company must withhold 24% as backup withholding
  - Referrer is responsible for all taxes on referral fees, including self-employment tax
- **Limitation of Liability** — cap at total fees paid in prior 12 months. Exclude consequential damages.
- **Governing Law** — Maryland, consistent with all other Company agreements

---

## Federal Requirements (Apply to All Document Types)

### DTSA Whistleblower Immunity Notice (18 U.S.C. Section 1833(b))

**LEGALLY REQUIRED** in any contract containing confidentiality or trade secret provisions with employees, contractors, or consultants. The statute defines "employee" to include contractors and consultants (Section 1833(b)(4)). **Consequence of omission: Company forfeits the right to recover exemplary damages or attorney's fees under DTSA Section 1836(b)(3).**

Include the following notice verbatim or substantially similar in every NDA, ICA, MSA, engagement letter, referral agreement, and subcontractor agreement:

> **Notice of Immunity Under the Defend Trade Secrets Act.** Pursuant to the Defend Trade Secrets Act of 2016 (18 U.S.C. Section 1833(b)), an individual shall not be held criminally or civilly liable under any federal or state trade secret law for the disclosure of a trade secret that: (i) is made in confidence to a federal, state, or local government official, either directly or indirectly, or to an attorney, solely for the purpose of reporting or investigating a suspected violation of law; or (ii) is made in a complaint or other document filed under seal in a lawsuit or other proceeding. An individual who files a lawsuit for retaliation by an employer for reporting a suspected violation of law may disclose the employer's trade secrets to the attorney and use the trade secret information in the court proceeding if the individual files any document containing the trade secret under seal and does not disclose the trade secret, except pursuant to court order.

### IRS Independent Contractor Classification

The IRS uses a three-category test: (1) Behavioral Control (does the company control how, when, where work is done?), (2) Financial Control (does the worker have unreimbursed expenses, opportunity for profit/loss, multiple clients?), (3) Relationship Type (written contract terms, benefits, permanency, integration). Safe harbor under Section 530 of the Revenue Act of 1978 bars reclassification if the employer had a reasonable basis. Written contracts alone do not override actual working conditions.

When drafting contractor agreements, include language that reinforces contractor status across all three IRS factors. Flag to the user if the described engagement pattern looks more like employment.

### Copyright Act Work-for-Hire (17 U.S.C. Section 101)

Software does NOT qualify as work-for-hire when created by an independent contractor. The nine enumerated categories are: contribution to a collective work, part of a motion picture or other audiovisual work, translation, supplementary work, compilation, instructional text, test, answer material for a test, atlas. Software is none of these.

**Every contractor agreement must use the belt-and-suspenders approach:**
1. Work-for-hire clause (covers any deliverable that happens to qualify)
2. Present-tense irrevocable assignment ("hereby assigns")
3. Power of attorney for executing assignment documents
4. Moral rights waiver

---

## Maryland-Specific Legal Requirements Checklist

Apply these to every document:

1. **MUTSA Alignment** (Com. Law Section 11-1201 et seq.) — confidentiality provisions should be at least as broad as MUTSA's trade secret definition
2. **Noncompete Restrictions** (Lab. & Empl. Section 3-716) — if any noncompete is included, verify compliance; note it applies only to employees, not contractors, but flag the risk of misclassification
3. **Electronic Signatures** (Com. Law Section 21-101 et seq.) — valid; for standard form contracts, e-sign consent must be conspicuously displayed and separately consented to
4. **Choice of Law** — Maryland courts enforce choice-of-law provisions under the substantial relationship / no fundamental policy violation test; B2B contracts designating Maryland law are enforceable
5. **Attorney's Fees** — Maryland follows the American Rule (each party bears own fees) unless the contract specifies otherwise; include prevailing party clause only if user requests
6. **Late Payment Interest** — contractual interest rates are permitted for commercial transactions; Maryland's usury cap generally does not apply to B2B transactions
7. **Personal Information Protection Act** (Com. Law Section 14-3501 et seq.) — triggers when business owns, licenses, or maintains personal information of Maryland residents; requires security procedures in service provider contracts; breach notification to AG then consumers within 45 days
8. **Maryland Online Data Privacy Act** (MODPA, effective October 1, 2025) — applies to entities processing data of 35,000+ consumers annually or deriving 20%+ revenue from selling data of 10,000+ consumers; requires Data Processing Agreements with all processors; penalties up to $10,000/violation, $25,000 for repeat violations. Include DPA provisions if applicable.
9. **DTSA Whistleblower Notice** — required in all agreements with confidentiality provisions (federal, not Maryland-specific, but included here for completeness)
10. **ABC Test / Workplace Fraud Act** — worker presumed employee unless all three ABC prongs met; prong B is the primary risk for software companies hiring software contractors
11. **Finder vs. Broker** — Maryland does not require licensing for business finders who merely introduce parties. Md. Code, Com. Law, Sections 12-804/12-805 apply only to mortgage/lending finders. Ensure referral agreements clearly limit the referrer's role to introductions only.

---

## Drafting Process

### Step 1: Gather Requirements

Before drafting, ensure you have all necessary information. Prompt the user for anything missing:

**All documents:**
- Document type
- Counterparty name and entity type (individual, LLC, Corp, etc.)
- Counterparty state of formation / residence (if known)
- Effective date
- Any special provisions or concerns

**Contractor agreements (ICA, engagement letter, subcontractor):**
- Scope of work description
- Compensation type and amount (hourly rate, fixed fee, milestone-based)
- Payment terms (net 15, net 30, etc.)
- Contract duration (fixed term or ongoing)
- Whether contractor will handle PII or consumer data
- Whether noncompete is desired (recommend non-solicitation instead)
- Whether there is an existing NDA or if confidentiality should be inline

**NDAs:**
- Mutual or unilateral
- Purpose of disclosure
- Duration of confidentiality obligations
- Whether a residuals clause is desired

**SOWs:**
- Reference to master agreement
- Detailed deliverables and acceptance criteria
- Timeline and milestones
- Compensation structure for this SOW
- Key personnel requirements
- Client-provided dependencies

**Referral agreements:**
- Referrer name and entity type
- Compensation model: flat fee (with tiers), percentage of initial payment, or hybrid
- Specific fee amounts or percentage rates
- Protection period duration (6 or 12 months)
- Post-termination tail period (90 or 180 days)
- Minimum deal size threshold (if any)
- Whether recurring commissions on renewals are desired
- Whether exclusivity is desired
- Any industry or geographic limitations on referrals

### Step 2: Draft

- Start with the disclaimer header
- Use the appropriate template structure from this skill
- Include all legally required provisions (DTSA notice, IP assignment with belt-and-suspenders where applicable, contractor status language)
- Include all provisions listed for the document type above
- Flag provisions where the user should make a policy decision with inline comments: `[DECISION NEEDED: ...]`

### Step 3: Review and Flag

After drafting, provide a summary that calls out:
- Provisions where the user should consider alternatives
- Maryland-specific requirements that were included and why
- ABC test risks if drafting a contractor agreement for software work
- Finder vs. broker classification risks if drafting a referral agreement
- Areas that are particularly important for attorney review
- Any provisions where Maryland law may limit enforceability

### Step 4: Generate DOCX Output

1. Get the current date: `date +%Y-%m-%d`
2. Create the output directory: `mkdir -p ~/basilisk_systems/legal/YYYY/MM/DD/`
3. Ensure python-docx is installed: `uv pip install python-docx`
4. Write a Python script that uses `python-docx` to generate the formatted `.docx` file
5. Execute the script and confirm the output path to the user
6. Clean up the temporary Python script

---

## What This Skill Does NOT Do

- Provide legal advice or guarantee enforceability
- Replace attorney review
- Handle litigation documents, regulatory filings, or court pleadings
- Draft documents governed by laws outside Maryland (unless explicitly requested, in which case note the limitation prominently)
- Provide tax advice (recommend CPA for tax classification questions)
- Opine on whether a specific working arrangement satisfies the ABC test (recommend employment attorney for classification opinions)
- Determine broker licensing requirements for specific industries (recommend consulting the relevant Maryland regulatory body)
