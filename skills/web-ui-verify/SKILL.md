---
name: web-ui-verify
description: Headless-browser visual verification for web UI changes - launch the dev server, drive Chromium via playwright-core, screenshot, pixel-sample, and measure geometry to prove a UI change actually renders correctly. TRIGGER after implementing any visual/styling/layout change in a web app, when a user reports a visual artifact (misalignment, stray line, wrong spacing/color), or before declaring a UI fix complete. Do NOT trigger for logic-only changes with no visual surface, or for unit/component test work (jsdom cannot verify paint).
---

# Web UI Visual Verification

## Core Principle

**A UI change is not verified until it has rendered in a real browser.**
Class-string reasoning, code review, and jsdom-based component tests all
operate above the paint layer. They cannot catch:

- Cascade/preflight surprises (e.g., Tailwind v4 defaults border color to
  `currentColor`, so a bare `border-l` renders near-black, not theme gray)
- Stacking/z-index artifacts that only appear with real compositing
- Subpixel gaps, scrollbar shifts, and DPR rounding
- Anything about how the page *actually looks*

Verify with a screenshot plus measurements, in this order of rigor:

1. **Screenshot and look at it.** A blank frame means the app never rendered.
2. **Measure geometry** — `getBoundingClientRect()` for alignment claims
   ("the menu links line up with the logo" is a number, not an impression).
3. **Pixel-sample** for artifact claims ("no dark line at the left edge" is
   provable by reading pixels).

## Toolchain (in order of preference)

1. **`chromium-cli`** if installed — a headless-Chromium REPL; pipe commands
   to stdin (`nav`, `wait-for`, `click`, `screenshot`). Check with
   `which chromium-cli`.
2. **`playwright` / `playwright-core`** from the project's own
   `node_modules` — check `node_modules/.bin/playwright` or
   `node_modules/playwright-core`.
3. **Ad-hoc `playwright-core`** — install into a scratch directory (NOT the
   project; do not touch the project's package.json for tooling):

   ```bash
   cd <scratch-dir> && npm init -y && npm install playwright-core
   ```

   Then find a browser binary — playwright-core ships none:
   - Playwright cache: `ls ~/.cache/ms-playwright/` — a
     `chromium_headless_shell-*/chrome-headless-shell-linux64/chrome-headless-shell`
     or `chromium-*/chrome-linux/chrome` from any prior install works
   - System: `which chromium chromium-browser google-chrome`
   - Nothing found → `npx playwright install chromium` (needs network)

## Dev Server

Find the dev command (`package.json` scripts, Makefile, project CLAUDE.md).
Launch in the background and **poll the port** — never `sleep N`:

```bash
(npm run dev >/tmp/dev-server.log 2>&1 &)
timeout 45 bash -c 'until curl -sf http://localhost:5173 >/dev/null; do sleep 1; done'
```

Common ports: Vite 5173, CRA/Next 3000, Astro 4321. When done, free the
port by PID — `lsof -ti:5173 -sTCP:LISTEN | xargs -r kill`. Avoid broad
`pkill -f` patterns (they can match your own session).

## Driver Script Skeleton

```js
// verify.mjs — run with: node verify.mjs
import { chromium } from 'playwright-core';

const browser = await chromium.launch({
  executablePath: '<browser-binary-path>', // omit if using full playwright
  args: ['--no-sandbox'],
});
const page = await browser.newPage({ viewport: { width: 375, height: 667 } });
const errors = [];
page.on('console', (m) => m.type() === 'error' && errors.push(m.text()));
page.on('pageerror', (e) => errors.push(String(e)));

await page.goto('http://localhost:5173', { waitUntil: 'networkidle' });
// interact: click/fill/press to reach the state under test
await page.locator('header button').last().click();
await page.waitForSelector('[role="dialog"] nav', { state: 'visible' });
await page.waitForTimeout(600); // let CSS transitions/animations settle

await page.screenshot({ path: 'state.png' });
console.log('CONSOLE ERRORS:', errors.length ? errors : 'none');
await browser.close();
```

Read the screenshot file with the Read tool and actually look at it before
drawing any conclusion.

## Measurement Recipes

### Geometry — prove alignment with numbers

```js
const report = await page.evaluate(() => {
  const rect = (el) => el?.getBoundingClientRect();
  return {
    logoLeft: rect(document.querySelector('header a'))?.left,
    firstLinkLeft: rect(document.querySelector('[role="dialog"] nav a'))?.left,
  };
});
```

Compare before/after interaction states too — a fixed header that shifts
when a modal opens (scrollbar compensation) shows up as a changed
`left`/`paddingRight` between snapshots.

### Pixel sampling — prove an artifact exists or is gone

Screenshots are lossless PNGs; sample them with PIL:

```bash
python3 -c "
from PIL import Image
im = Image.open('state.png').convert('RGB')
for y in [80, 300, 620]:
    print(y, [im.getpixel((x, y)) for x in range(0, 6)])
"
```

This turns "I think there's a dark line" into `(0, 0, 0)` at `x=0` — and
"fixed" into the background color at the same coordinates. Sample the
user's own screenshot the same way to confirm you're chasing the same
pixels they see.

### Identify what paints a pixel

When a rogue pixel's source is unclear, interrogate the element stack at
that exact point:

```js
await page.evaluate(() => {
  return document.elementsFromPoint(0, 300).map((el) => {
    const s = getComputedStyle(el);
    return {
      tag: el.tagName,
      cls: String(el.className).slice(0, 80),
      bg: s.backgroundColor,
      borderLeft: s.borderLeft,   // computed color exposes currentColor
      boxShadow: s.boxShadow.slice(0, 80),
      outline: s.outline,
      zIndex: s.zIndex,
    };
  });
});
```

Computed styles show what the browser resolved, not what the class string
implied — this is how cascade bugs are actually found.

## Gotchas

- **Duplicate accessible names.** Responsive apps often render two navs
  (desktop + mobile) with the same `aria-label`; `waitForSelector` grabs
  the hidden one and times out. Scope selectors to the container:
  `[role="dialog"] nav`, not `nav[aria-label=...]`.
- **Animations.** Screenshot mid-slide-in and every measurement lies. Wait
  for the transition (`waitForTimeout` ≥ the CSS duration) after the state
  change, not just for the selector.
- **First paint is slow.** Vite/Next compile routes on demand; first `goto`
  can take 10s+. Use `waitUntil: 'networkidle'` or `waitForSelector`, not
  sleeps.
- **React controlled inputs.** Setting `el.value` via `evaluate` skips
  React's onChange. Use `fill`/`type`/`press`.
- **DPR ≠ 1 reproduction.** If the user sees an artifact you can't
  reproduce, retry with `deviceScaleFactor: 1.25` or `1.5` in `newPage()` —
  Windows displays commonly run fractional scaling.
- **Check console errors before declaring success.** A page can render its
  shell while every data fetch fails.
- **Match the user's viewport.** Verify at the breakpoints the change
  targets (e.g., 375px and the md boundary), not only the default 1280px.

## Reporting

State what was verified and how: viewport(s), the interaction path, and
the measurement that proves the claim ("link left edge 16px == logo left
edge 16px at 375px; left-edge pixels are rgb(248,250,252), no dark
column"). Attach or reference the screenshot. If setup required
project-specific discovery (ports, binary paths, selector scoping), record
the recipe in the project's notes/skills so the next verification starts
warm.
