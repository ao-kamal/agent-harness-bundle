---
name: dev-browser
description: Drive the dev-browser CLI to control a real browser from a script, right now — not to write test code the user runs elsewhere, and not for pure HTTP status/header/redirect checks (those are a plain fetch/curl job). Use when you need to see how a page renders (screenshots, layout, sizing, fonts, visual verification), act on a page (click, fill, navigate, log in), read JS-rendered/SPA/hydrated content that a plain fetch can't see, work inside the user's logged-in session, or scrape a site that blocked firecrawl/fetch. Trigger phrases include "go to [url]", "click", "fill out the form", "take a screenshot", "verify it looks right", "scrape", "log into", "test the site", or "check it in a real browser". Also reach for it when firecrawl/WebFetch/curl returns a 403, a block, or an empty JS shell.
---

# dev-browser

> **Core Insight:** dev-browser is a real browser one heredoc away. Most failures aren't the tool — they're not reaching for it, reaching past the direct primitive for a `page.evaluate()` hack, or tripping one of three timeout clocks. Reach for it, pick the direct verb, respect the clocks.

dev-browser runs sandboxed JavaScript against a real Chromium via a background daemon. Pages are full [Playwright Page objects](https://playwright.dev/docs/api/class-page). **This skill is the decision layer, not the API** — run `dev-browser --help` for the complete, authoritative API and read it (don't `head` it: the method ladder and examples live at the bottom).

## When to reach for dev-browser

The single most common failure is not reaching for it — handing the user manual steps, or accepting a `fetch`/firecrawl block, when a real browser was right there.

| The task involves… | Use |
|---|---|
| Seeing how a page renders — layout, sizes, fonts, spacing, "does it look right" | **dev-browser** screenshot → Read the PNG. NOT WebFetch (text only — can't confirm sizing/layout). |
| JS-rendered / SPA / hydrated content | **dev-browser** — a plain `fetch` sees the empty shell. |
| Anything in the user's logged-in session ("I'm logged into X") | **dev-browser** — drive it yourself; don't write the user an instruction list. |
| Clicking / filling / navigating a live page | **dev-browser** |
| A site that 403'd or blocked firecrawl/fetch | **dev-browser headful** — treat a block as *unverified, escalate*, not *rejected*. Headful Chromium passes what HTTP scraping can't. |
| Pure HTTP facts: status code, redirect `Location`, cache headers, RSC-vs-SSR payload diff | raw `fetch`/`curl` is correct — dev-browser can't isolate these. |

## The canonical script

Keep every script close to this shape. Small, focused, one job, ends by logging the state you need next.

```bash
dev-browser --timeout 60 <<'EOF'
const page = await browser.getPage("main");
await page.setViewportSize({ width: 1280, height: 660 });
await page.goto("https://example.com", { waitUntil: "domcontentloaded" });
// ... act ...
console.log(JSON.stringify({ url: page.url(), title: await page.title() }));
EOF
```

On Windows PowerShell use a here-string (`@" … "@ | dev-browser`); from WSL you must call the Windows `.exe` — see [references/troubleshooting.md](references/troubleshooting.md). Always pass `--timeout`; never rely on the 30s default for anything past one goto+screenshot.

## The method ladder — direct verb first

When you need to act on an element, go **down** this ladder only as each rung fails. The signature failure is skipping to the bottom: a `page.evaluate()` DOM scan to *find and click* something a locator would hit directly — it bypasses Playwright's actionability waits, silently clicks the wrong node, and needs guessed pixel math.

1. **Known page/selector → a Playwright locator, directly.** `getByRole`, `getByText`, `getByLabel`, `locator()`. `.click()` / `.fill()` / `.scrollIntoViewIfNeeded()`. This is the default for almost everything.
2. **Unknown page → `page.snapshotForAI()` once** to discover elements, then act on locators from what it returns.
3. **After ~2 failed locator attempts on the same target → `page.domCua`** (act by node id from `getVisibleDom()`).
4. **Visual-only structure (canvas, no stable DOM) → `page.cua`** (act by coordinates read off a screenshot).
5. **`page.evaluate()` → read-only introspection, last resort.** Computing a value, checking state, reading a JS variable with no structured equivalent. **Never to click, scroll, or find.**

```
| Don't                                              | Do                                          |
| page.evaluate(() => [...document.querySelectorAll  | page.getByRole("button", { name: "Import" })|
|   ("button")].find(b => b.innerText.includes(..))  |   .click()                                   |
|   .click())  →  silent wrong-element no-op         |                                              |
| page.evaluate(() => window.scrollTo(0, 1400))      | page.getByText("Pricing")                    |
|   →  guessed pixels                                |   .scrollIntoViewIfNeeded()                  |
| document.body.innerText  →  grabs the sidebar too  | page.snapshotForAI()  (structured, scoped)   |
```

**The loop:** snapshot (if needed) → act → *cheapest* verify. Don't take both a snapshot and a screenshot by default — pick the one that answers the question.

Dismiss a cookie/consent banner with the direct verb, wrapped so it's a safe no-op when absent:

```js
await page.getByRole("button", { name: /^(accept|accept all|allow all|reject|close|×)$/i })
  .first().click({ timeout: 2000 }).catch(() => {});
```

`snapshotForAI()` returns a structured accessibility *tree*, not prose — read it to find the element's role/name, then act with a locator. Don't abandon it for firecrawl because it "looks verbose."

### When the direct locator doesn't work

Before deciding an element is missing or a click is broken, rule out the three things that make a correct locator fail:

- **It's in an iframe.** `getByRole`/`getByText` search the top-level page only. Embedded admin/merchant panels (Google properties, Vuetify/Select2 widgets, payment forms) live in an iframe — check `page.frames()` and target the frame, don't conclude "not found" after 3 top-level attempts.
- **An overlay is intercepting the click.** A failure naming `"<el> intercepts pointer events"` (a stale dropdown mask, modal backdrop) means the click is landing on the overlay. Dismiss it (`page.keyboard.press("Escape")`, or hide it via `page.evaluate()`) and retry — don't re-fire the same blind click.
- **The label repeats.** `getByText("Manage")` on a page with ten "Manage" buttons hits the wrong one silently. Scope to the nearest disambiguating container: `page.getByRole("dialog").getByRole("combobox")`, or `page.locator("tr", { hasText: rowId }).getByRole("button", { name: /Manage/ })`.

Only after a `frames()`/snapshot scan confirms no addressable locator exists do coordinate clicks (`page.cua`) or `{ force: true }` become the answer.

## Timeouts — three clocks, three fixes

The costliest confusion in the field. `--timeout` does **not** raise Playwright's per-action timeout. Escalating `--timeout 30→60→90` while a `goto` keeps failing at "30000ms exceeded" is chasing the wrong clock.

| Clock | Default | Raise it with |
|---|---|---|
| **QuickJS script** — the whole script's budget | 30s | `--timeout N` |
| **Playwright per-action** — each `goto`/`click`/`screenshot`/`snapshotForAI` | 30s (independent) | `{ timeout: N }` **on the call** — `page.goto(url, { timeout: 45000, waitUntil: "domcontentloaded" })` |
| **Outer Bash tool** — the shell running dev-browser | ~2min | not fixable by any dev-browser flag; "Exit code 143" is this. Shorten the script. |

Rules that prevent most timeouts:
- **`waitUntil: "domcontentloaded"`, not `"networkidle"`.** `networkidle` hangs indefinitely on any site with analytics, trackers, or SPA polling.
- **Split batch loops over ~3+ pages** into separate invocations — a wall-kill then costs one item, not the whole tail.
- **`locator.count()` before `.click()`/`.fill()`** — a doomed locator otherwise burns the full per-action budget.
- **Poll for content stability** (innerText length unchanged N polls in a row) instead of a guessed `waitForTimeout(N)`. Full recipe in [references/recipes.md](references/recipes.md).
- Read printed stdout before assuming a timed-out run failed — the data may have already logged.

## State & concurrency

- **Named pages persist across invocations** in default (launched) mode: `getPage("checkout")` returns the same tab next script — reuse it, don't re-navigate or re-log-in. (A timeout-killed script can leave the page reset to `about:blank` — if a reused page is unexpectedly blank, re-`goto` before acting.)
- **`getPage("typo")` silently creates a blank page.** A blank/`about:blank` result is usually a wrong name, not a broken page. Name pages carefully and consistently. To simulate a *fresh visitor* (first-load popups, no cookies), use a new/random page name — not the shared persistent one.
- **`browser.newPage()` for one-shot/throwaway** work; close it in a `finally`. Give a long-lived stateful page (login, multi-step form) its own `--browser` instance, separate from one-shot fetches, so a wedge in one can't take the other down.
- **`setViewportSize()` must be the first call**, before `goto` — it silently doesn't take effect on an already-navigated persisted page. To change viewport mid-session, open a new named page.
- **`--connect` mode does NOT persist named pages across separate invocations.** Multi-step work through `--connect` must live in **one** script.
- **One shared daemon serves everything.** **Never fire two dev-browser calls in parallel** — they serialize on the daemon and, under load, wedge Chromium. Loop *inside* one script instead. Also don't run a dev-browser call in parallel with an unrelated Bash call in the same turn (one timing out can cascade-cancel the other), and never background a dev server with shell `&` inside a heredoc — it dies when the tool call's shell exits; use the Bash tool's own `run_in_background: true`.
- **Concurrent agents (swarm): give each its own `--browser <name>`, and NEVER run global `dev-browser stop`** (it kills every agent's browser). This is the difference between a clean 6-agent run and a 50-minute wedge. See [references/swarm-dispatch.md](references/swarm-dispatch.md).

## Sandbox — it's QuickJS, not Node

- No `require`/`import`/`process`/`fs`/`fetch`/`WebSocket` at the script's top level.
- **`document`/`window`/DOM globals exist only inside `page.evaluate(() => …)`** — never at the script's top level, even though `browser`/`page`/`console` are. `document is not defined` = you're at the top level.
- **`page.evaluate()` callbacks don't see outer-script variables** — pass them as args: `page.evaluate((x) => …, myVar)`.
- **File upload:** `setInputFiles` with a path fails (no fs). Inject via a canvas-generated `File` + `DataTransfer` — full recipe in [references/recipes.md](references/recipes.md).
- **`readFile()` is UTF-8 only** — it silently corrupts binary. Don't round-trip a screenshot/PNG through it.
- **Never leave a script's core action in an empty `catch(e){}`** — log the caught error. A swallowed sandbox `ReferenceError`/`ValidationError` looks identical to success.

## Sensitive actions & credentials

dev-browser drives the user's **real, already-authenticated** browser — a wrong click has real consequences, not sandboxed ones.

- **Before a consequential/irreversible action** (submit payment, delete, send, publish), confirm the target matches intent — snapshot or read the element's role/name first, don't fire a blind locator into a page you haven't verified.
- **Credentials:** there is no env-var/secret-injection primitive in the sandbox (a hallucinated `process.env`-style trick fails silently). If a login is unavoidable, inline the credential in the script body — and know it will appear in the script text and any logged output. Prefer reusing an existing logged-in session (persistent named page, or `--connect` to the user's browser) over typing a password at all.

## Verify like you mean it

- **Click looked like a no-op?** Attach `page.on("response", …)` anchored to the real API path and read what actually came back — don't blind-retry. A silent UI often hides a `400`/`409`.
- **Perf / CLS / "is this really SSR'd"?** Reach for CDP proof (`Emulation.setScriptExecutionDisabled`, `Network.setCacheDisabled`) plus numeric readouts (`performance.getEntriesByType`, `getBoundingClientRect`, `getComputedStyle`). Use the screenshot to confirm the numbers, not instead of them.
- **Scroll-reveal pages screenshot blank** (`opacity:0` until scrolled): set `scroll-behavior: auto`, `scrollIntoViewIfNeeded()` the target, settle, then capture. For long pages, screenshot the element, not `fullPage`.

## Anti-patterns

| Don't | Do |
|---|---|
| Hand the user manual steps for something dev-browser can do in their logged-in session | Drive it yourself |
| Accept a firecrawl/fetch 403 as final | Escalate to dev-browser headful — a block is *unverified*, not *rejected* |
| `page.evaluate()` to find/click/scroll | Locator (`getByRole`/`getByText`) — down the ladder only as each rung fails |
| Escalate `--timeout` when a `goto`/`click` keeps hitting "30000ms exceeded" | Pass `{ timeout }` on that action — it's a different clock |
| `waitUntil: "networkidle"` on a live site | `"domcontentloaded"` |
| Fire N dev-browser calls in parallel; run global `dev-browser stop` in a swarm | Loop in one script; per-agent `--browser <name>`; never global stop |
| Reinstall Playwright / reach for raw `fetch` before trying dev-browser | dev-browser is already installed and working — `--help`, then a script |

## Gotchas & workarounds

- **WSL:** the npm shim errors "Native binary not found for linux-x64" — call the Windows `.exe` directly; run **headful** (headless fails over the interop hop). See [references/troubleshooting.md](references/troubleshooting.md).
- **Exit code 1 absorbs every failure class** (timeout, sandbox, daemon, launch) — read the stderr *text*, not just the code.
- **Version-specific bugs** in the installed build (per-instance stop missing, no `--json`, `addInitScript` broken, stale `cua.click` nav docs) are catalogued in [references/workarounds-0.2.8.md](references/workarounds-0.2.8.md) — delete entries there as upstream fixes land.
- **PDFs** don't render reliably for screenshotting — use an external `pdftoppm`/`pymupdf` pipeline.

## Quick checklist

- [ ] Is this a rendering/visual/logged-in/JS task? → dev-browser, not fetch.
- [ ] `--timeout` set, and `{ timeout }` on any slow action?
- [ ] `waitUntil: "domcontentloaded"`?
- [ ] Direct locator before any `page.evaluate()`?
- [ ] One script (not parallel calls); named page reused; per-agent `--browser` if in a swarm?
- [ ] Verified the outcome (response listener / numbers / screenshot), not assumed it?

## References

| Topic | File |
|---|---|
| Full API | `dev-browser --help` (authoritative) |
| Dispatching subagents/swarms to use dev-browser | [references/swarm-dispatch.md](references/swarm-dispatch.md) |
| Copy-paste recipes (upload, settle-loop, batch capture, connect) | [references/recipes.md](references/recipes.md) |
| Error signature → cause → fix; WSL; daemon wedge ladder | [references/troubleshooting.md](references/troubleshooting.md) |
| Installed-version bugs to route around (delete as fixed) | [references/workarounds-0.2.8.md](references/workarounds-0.2.8.md) |
| Related: swarm orchestration | `browser-testing-with-ntm` skill |

*Built from 383 mined real-session incidents — the evidence base is a `References/dev-browser-taxonomy/` note collection (23 failure clusters) + `.firecrawl/dev-browser-research/leading-edge-practices.md`.*
