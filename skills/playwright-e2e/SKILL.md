---
name: playwright-e2e
description: Playwright end-to-end test suites for Vite/React SPAs backed by an API - project layout, in-memory-token auth fixtures, translating a ticket's E2E/Smoke narrative into a spec, polling-aware assertions for async job status, tenant-isolation and RBAC checks, axe accessibility scans, download/presigned-link checks, locator discipline, and the CI job. TRIGGER when creating or editing files under web/e2e/ or playwright.config.ts, when a ticket's E2E section is being codified as an automated regression test, or when the user asks about e2e tests, Playwright specs, or automating a smoke test. Do NOT trigger for one-off visual verification of a UI change (screenshots, pixel sampling, geometry - use web-ui-verify), for vitest unit/component tests, or for API-only integration tests with no browser.
---

# Playwright End-to-End Tests

## Where this fits

The milestone smoke test is the source of truth for E2E: a numbered narrative
"executable by a person with a browser and `curl`", run via `/smoke-test`.
Only vitest and axe are mandated in CI; Playwright is a toolkit investment,
not an ADR decision.

Once a rung is stable, codify the ticket's **E2E / Smoke Test** section into
a spec so regressions are caught without re-running the narrative by hand.
The narrative stays authoritative; when the two disagree, fix the spec.
`web-ui-verify` proves one visual change rendered; this proves a workflow works.

---

## Project setup

```
web/e2e/fixtures/auth.ts        # role fixtures
web/e2e/fixtures/files/         # customer-shaped CSV/XLSX + poison file
web/e2e/pages/                  # thin page objects, one per screen
web/e2e/specs/ODIN-1xx-*.spec.ts
web/playwright.config.ts
```

```bash
cd web && npm i -D @playwright/test @axe-core/playwright
npx playwright install --with-deps chromium
```

```typescript
// web/playwright.config.ts
import { defineConfig, devices } from "@playwright/test";

const baseURL = process.env.E2E_BASE_URL ?? "http://localhost:5173";
const isLocal = baseURL.includes("localhost");
const isCI = !!process.env.CI;

if (/prod/.test(baseURL)) throw new Error("e2e never runs against production");

export default defineConfig({
  testDir: "./e2e/specs",
  fullyParallel: true,
  retries: isCI ? 2 : 0,
  workers: isCI ? 4 : undefined,
  reporter: [["html", { open: "never" }], ["list"]],
  use: {
    baseURL,
    trace: "on-first-retry",
    video: "on-first-retry",
    screenshot: "only-on-failure",
  },
  projects: [
    { name: "chromium", use: { ...devices["Desktop Chrome"] } },
    { name: "keyboard-reduced-motion", testMatch: /a11y|keyboard/,
      use: { ...devices["Desktop Chrome"], contextOptions: { reducedMotion: "reduce" } } },
  ],
  // Local only: CI targets the deployed odin-dev URL and needs no server.
  webServer: isLocal
    ? { command: "make dev", url: baseURL, reuseExistingServer: true, timeout: 120_000 }
    : undefined,
});
```

- `E2E_BASE_URL` is the deployed `odin-dev` origin in CI or the `make dev`
  stack locally. No AWS credentials: the suite hits the public dev URL.
- `fullyParallel` is safe only because every test owns its data: one case
  per test, no shared ids, no order dependence.

---

## Auth fixture

Tokens live **in memory** via the Descope SDK, never in `localStorage`, so
`storageState` captures nothing useful. Log in through the app's own login
route and reuse the authenticated context per worker.

```typescript
// web/e2e/fixtures/auth.ts
import { test as base, BrowserContext, Page } from "@playwright/test";

export type Role = "analyst" | "reviewer" | "admin" | "support" | "tenant-b-analyst";

function creds(role: Role) {
  const key = role.toUpperCase().replace(/-/g, "_");
  const email = process.env[`E2E_${key}_EMAIL`], password = process.env[`E2E_${key}_PASSWORD`];
  if (!email || !password) throw new Error(`missing E2E_${key}_EMAIL/_PASSWORD`);
  return { email, password };
}

// Descope embedded-component selectors are verify-current against the installed SDK.
async function login(page: Page, role: Role) {
  const { email, password } = creds(role);
  await page.goto("/login");
  await page.getByLabel(/email/i).fill(email);
  await page.getByRole("button", { name: /continue|next/i }).click();
  await page.getByLabel(/password/i).fill(password);
  await page.getByRole("button", { name: /sign in|continue/i }).click();
  await page.getByRole("navigation", { name: /main/i }).waitFor();
}

export const test = base.extend<
  { as: (role: Role) => Promise<Page> }, { contexts: Map<Role, BrowserContext> }>({
  contexts: [async ({}, use) => { const m = new Map(); await use(m);
    for (const c of m.values()) await c.close(); }, { scope: "worker" }],
  as: async ({ browser, contexts }, use) => {
    await use(async (role) => {
      if (!contexts.has(role)) {
        const ctx = await browser.newContext();
        await login(await ctx.newPage(), role);   // once per worker per role
        contexts.set(role, ctx);
      }
      return contexts.get(role)!.newPage();
    });
  },
});
// window.__e2eToken exists ONLY under an E2E build flag (same mechanism as the
// support build flag) and the CI bundle grep must prove it is absent from the
// customer bundle. Exposing a live session token on window in a shipped build
// is a defect. The compose stub broker is the alternative.
export const tokenFor = (p: Page) => p.evaluate(() => (window as any).__e2eToken as string);
export { expect } from "@playwright/test";
```

- One dedicated test user per role per tenant in the Descope dev tenant.
  Credentials come from env only (locally, export them from the entries kept
  per `~/.claude/TEST_CREDENTIALS.md`). Never commit them.
- Compose-only alternative: a stub broker minting JWTs plus a dev-only route
  that seeds the SDK session, behind a build flag that never ships.
- Both hooks are gated by an `E2E` build flag and covered by the same CI bundle
  grep that keeps support code out of the customer bundle.

---

## From ticket narrative to spec

One `test.describe` per ticket, one `test` per numbered step group, one
`test.step` per numbered step with the narrative text as its name, and the
ticket's mandatory failure-path step as its own test.

The spec below encodes a five-step rung-one narrative; step names quote it.

```typescript
// web/e2e/specs/ODIN-176-upload-and-range.spec.ts
import { test, expect, tokenFor } from "../fixtures/auth";
import { CasePage } from "../pages/case";

const JOB_TIMEOUT = 180_000; // async job budget; tune per class, never sleep

test.describe("ODIN-176 upload historical transactions -> range", () => {
  test("steps 1-4: create case, upload, confirm mapping, see range", async ({ as }) => {
    const page = await as("analyst");
    const casePage = new CasePage(page);
    await test.step("1. Create a case 'Widget refresh'", async () => {
      await casePage.create("Widget refresh");
    });
    await test.step("2. Upload customer-a.csv; confirm mapping", async () => {
      await casePage.upload("e2e/fixtures/files/customer-a.csv");
      await page.getByRole("button", { name: "Confirm mapping" }).click();
    });
    await test.step("3. Status rail: ingest, analysis reach succeeded", async () => {
      await expect(casePage.step("ingest")).toHaveText(/queued|running/);
      await expect(casePage.step("ingest")).toHaveText("succeeded", { timeout: JOB_TIMEOUT });
      await expect(casePage.step("analysis")).toHaveText("succeeded", { timeout: JOB_TIMEOUT });
    });
    await test.step("4. Range with math shown", async () => {
      await expect(page.getByRole("region", { name: "Price range" })).toBeVisible();
      await expect(page.getByTestId("range-math")).toContainText(/adjustment/i);
    });
  });

  test("step 5 (failure path): poison file is quarantined", async ({ as }) => {
    const page = await as("analyst");
    const casePage = new CasePage(page);
    await casePage.createAndUpload("Poison", "e2e/fixtures/files/poison.csv");
    await expect(casePage.step("ingest")).toHaveText("failed", { timeout: JOB_TIMEOUT });
    await expect(page.getByRole("status", { name: /quarantined/i })).toBeVisible();
  });
});
```

---

## Async and polling-aware assertions

The UI polls `GET /v1/cases/{id}` while a case is in a working state, backing
off toward a ceiling. Write assertions that wait, never `waitForTimeout`.

- Use `expect(locator).toHaveText(..., { timeout: JOB_TIMEOUT })`. One named
  constant per job class; sleeps are a review reject.
- Assert the rail vocabulary **exactly**: `queued` / `running` / `succeeded`
  / `failed`. "Couldn't reach X" is a **case flag** rendered in the evidence
  view, not a step status - assert it there, and assert it is absent from the rail.
- Assert the visible last-updated timestamp advances while a job runs.
- When the UI is ambiguous, ask the API: the job row is the source of truth
  under any transport.

  Use `expect.poll` over `request.get('/v1/cases/{id}')` with `tokenFor(page)`
  and read `job_steps[].status`.

---

## Tenant isolation and RBAC

UI gates, server enforces. Test both sides of every gate.

```typescript
test("tenant B cannot see tenant A's case", async ({ as }) => {
  const caseId = await new CasePage(await as("analyst")).create("Private to A");
  const b = await as("tenant-b-analyst");
  await b.goto(`/cases/${caseId}`);
  await expect(b.getByRole("heading", { name: /not found/i })).toBeVisible();
});

test("analyst cannot approve: hidden in UI, rejected by API", async ({ as, request }) => {
  const page = await as("analyst");
  const caseId = await new CasePage(page).create("Needs review");
  await expect(page.getByRole("button", { name: "Approve" })).toHaveCount(0);
  const res = await request.post(`/v1/cases/${caseId}/transition`,
    { headers: { Authorization: `Bearer ${await tokenFor(page)}` }, data: { to: "approved" } });
  expect(res.status()).toBe(403);
});
```

Also assert `/support/jobs` 404s on the customer origin; run the positive
support-route test only against `E2E_SUPPORT_BASE_URL`, its own path/origin.

---

## Accessibility

This is how "axe on every route" and the rung-one AA pass become automated.

```typescript
// web/e2e/specs/a11y-routes.spec.ts
import AxeBuilder from "@axe-core/playwright";
import { test, expect } from "../fixtures/auth";

const ROUTES = ["/", "/cases", "/cases/new"];

for (const route of ROUTES) {
  test(`axe AA: ${route}`, async ({ as }) => {
    const page = await as("analyst");
    await page.goto(route);
    const results = await new AxeBuilder({ page })
      .withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa"])
      .analyze();
    const blocking = results.violations.filter((v) =>
      ["serious", "critical"].includes(v.impact ?? ""));
    expect(blocking, JSON.stringify(blocking, null, 2)).toEqual([]);
  });
}

test("keyboard-only: create case", async ({ as }) => {
  const page = await as("analyst");
  await page.goto("/cases");
  await page.keyboard.press("Tab");
  await expect(page.getByRole("link", { name: "New case" })).toBeFocused();
  await page.keyboard.press("Enter");
  await expect(page.getByLabel("Case name")).toBeFocused(); // focus order into the form
});
```

Scan authenticated routes with `as(...)` and the login page separately.

---

## Downloads and presigned links

Links are minted on click, never stored, and expire in about five minutes.

```typescript
test("report download mints a short-lived link", async ({ as }) => {
  const page = await as("analyst");
  await new CasePage(page).openWithFinishedReport();
  const [download, response] = await Promise.all([
    page.waitForEvent("download"),
    page.waitForResponse((r) => r.url().includes("/artifacts/") && r.request().method() === "POST"),
    page.getByRole("button", { name: "Download report v1" }).click(),
  ]);
  expect(await download.failure()).toBeNull();
  const { url } = await response.json();
  expect(new URL(url).searchParams.get("X-Amz-Expires")).toBe("300");
});
```

For expiry, have a setup job capture a URL, wait past five minutes, and
assert `request.get(url)` returns 403.

---

## Locator discipline

- `getByRole` first, then `getByLabel`, then `getByTestId`. No CSS chains,
  no XPath, no text-only locators for anything but headings.
- `data-testid` names: `<screen>-<thing>-<qualifier>`, kebab-case, e.g.
  `case-rail-step-ingest`. Add them in the component, not the test.
- Page objects are thin: one file per screen, methods that do one user
  action and return ids, no assertions inside them.
- Fixtures are deterministic files checked in under `e2e/fixtures/files/`
  (the customer-shaped CSV/XLSX set plus the poison file). Never generate
  random data inside a spec.
- No test-order dependence, no shared mutable state, no `test.only` committed.


---

## CI

```yaml
  e2e:
    needs: deploy-dev
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    continue-on-error: true   # promote to blocking once the suite is stable
    defaults: { run: { working-directory: web } }
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
      - uses: actions/setup-node@49933ea5288caeca8642d1e84afbd3f7d6820020 # v4.4.0
        with: { node-version: 22, cache: npm, cache-dependency-path: web/package-lock.json }
      - run: npm ci && npx playwright install --with-deps chromium
      - run: npx playwright test
        env:
          CI: "true"
          E2E_BASE_URL: ${{ vars.ODIN_DEV_URL }}
          E2E_ANALYST_EMAIL: ${{ secrets.E2E_ANALYST_EMAIL }}
          E2E_ANALYST_PASSWORD: ${{ secrets.E2E_ANALYST_PASSWORD }}
      - uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02 # v4.6.2
        if: always()
        with: { name: playwright-report, path: web/playwright-report, retention-days: 14 }
```

- Path-filter on `web/**` and `api/**` if it also runs on PRs.
- Runs after the dev deploy and only reads the site: no `id-token`, no AWS
  role. The only secrets are Descope dev-tenant test-user passwords.
- SHA-pin actions like every other job; verify the SHAs above before copying.

---

## Flake policy

- A test that fails, then passes on retry, is a bug: open a ticket, tag
  `flaky`, and quarantine it with `test.fixme` within the day.
- Fix the cause: missing wait on a polled state, shared data, a locator that
  matched two elements. Raising a timeout is only valid for a real job-class
  budget change.
- Keep retries at 2 in CI and 0 locally so flakes surface on the laptop.

## Review checklist

- [ ] Spec name and `describe` carry the `ODIN-NNN` ticket id.
- [ ] Every numbered narrative step is a `test.step` with the narrative text.
- [ ] Failure-path step exists as its own test.
- [ ] No `waitForTimeout`; every async assertion has a named timeout.
- [ ] Rail vocabulary asserted exactly; case flags asserted in the evidence view.
- [ ] Tenant-isolation or RBAC assertion present when the ticket touches either.
- [ ] Locators are role/label/testid only; page objects hold no assertions.
- [ ] No credentials, tokens, or tenant ids committed.
- [ ] `E2E_BASE_URL` guard rejects production.
