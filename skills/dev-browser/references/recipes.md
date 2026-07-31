# dev-browser recipes

Copy-paste code shapes proven in the field. All run inside `dev-browser --timeout N <<'EOF' … EOF`.

## Table of contents
- [Batch capture — one call, many targets](#batch-capture)
- [Content-stability settle loop](#content-stability-settle-loop)
- [File upload via canvas-inject](#file-upload-via-canvas-inject)
- [Scroll-reveal pages that screenshot blank](#scroll-reveal)
- [--connect: one atomic script](#connect-one-atomic-script)
- [Verify a click actually landed](#verify-a-click)
- [Long page → element screenshot](#long-page-element-screenshot)

## Batch capture
One invocation, one page reused, N targets, per-item try/catch so one bad target doesn't kill the batch.

```js
const page = await browser.getPage("cap");
await page.setViewportSize({ width: 1280, height: 660 });
const targets = [["home", "https://site/"], ["pricing", "https://site/pricing"]];
for (const [name, url] of targets) {
  try {
    await page.goto(url, { waitUntil: "domcontentloaded", timeout: 45000 });
    console.log(name, await saveScreenshot(await page.screenshot(), name + ".png"));
  } catch (e) { console.log("ERR", name, "::", e.message); }
}
```
Split into multiple invocations once you're past ~3–4 targets so a wall-kill costs one item.

## Content-stability settle loop
Adapts to page speed instead of guessing a `waitForTimeout`. ~3× faster than a fixed wait and it defeats challenge/interstitial pages (their length keeps changing, so it doesn't false-settle).

```js
let last = -1, stable = 0;
for (let i = 0; i < 40 && stable < 3; i++) {
  await page.waitForTimeout(250);
  const len = (await page.evaluate(() => document.body.innerText.length));
  if (len === last) stable++; else { stable = 0; last = len; }
}
```

## File upload via canvas-inject
`setInputFiles` fails in the sandbox (no fs). Generate the file in the browser context and inject it — works even for a cross-origin widget iframe, because Playwright evaluates per-frame.

```js
const frame = page.frames().find(f => f.url().includes("upload-widget")) || page.mainFrame();
await frame.evaluate(async () => {
  const c = document.createElement("canvas"); c.width = 900; c.height = 600;
  c.getContext("2d").fillRect(0, 0, 900, 600);
  const blob = await new Promise(r => c.toBlob(r, "image/jpeg", 0.85));
  const file = new File([blob], "upload.jpg", { type: "image/jpeg" });
  const input = document.querySelector('input[type=file]');
  const dt = new DataTransfer(); dt.items.add(file);
  input.files = dt.files;
  input.dispatchEvent(new Event("change", { bubbles: true }));
});
```
For a real (not generated) file you need bytes into the sandbox — `readFile()` is UTF-8-only and corrupts binary, so this generate-in-context path is the reliable route. (A future dev-browser `uploadFile()` helper is in the patch playbook.)

## Scroll-reveal
Pages that animate content from `opacity:0` on scroll screenshot blank under `fullPage`. Kill the animation, walk the page, then capture.

```js
await page.evaluate(() => { document.documentElement.style.scrollBehavior = "auto"; });
await page.getByText("How It Works").scrollIntoViewIfNeeded();
await page.waitForTimeout(400); // settle
await saveScreenshot(await page.locator(".how-it-works").screenshot(), "hiw.png");
```

## --connect: one atomic script
`--connect` does NOT persist named pages across invocations. Do the whole multi-step flow in a single script; re-locate the tab each time via `listPages()`.

```bash
dev-browser --connect --timeout 90 <<'EOF'
const tabs = await browser.listPages();
const t = tabs.find(x => x.url.includes("app.example.com"));
const page = await browser.getPage(t.id);
await page.getByLabel("Name").fill("…");
await page.getByRole("button", { name: "Save" }).click();
console.log("done", page.url());
EOF
```

## Verify a click
Attach a response listener before the click instead of blind-retrying — a silent UI usually hides a non-2xx.

```js
page.on("response", r => { if (r.url().includes("/api/save")) console.log("save →", r.status()); });
await page.getByRole("button", { name: "Save" }).click();
await page.waitForTimeout(1500);
```

## Long page → element screenshot
A 26,000px `fullPage` screenshot is useless. Capture the element.

```js
await page.locator(".report-card").scrollIntoViewIfNeeded();
await saveScreenshot(await page.locator(".report-card").screenshot(), "card.png");
```
