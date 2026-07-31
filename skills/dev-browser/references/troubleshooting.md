# dev-browser troubleshooting

## Error signature → cause → fix

| You see | Cause | Fix |
|---|---|---|
| `Script timed out after Ns and was terminated` | The **QuickJS script** clock (the `--timeout` one) | Raise `--timeout`; or the script is genuinely stuck (a `goto` on `networkidle`) — see next row |
| `Timeout 30000ms exceeded … navigating to …` (or on a click/screenshot) | The **Playwright per-action** clock — independent of `--timeout` | Pass `{ timeout: N }` on that call. If it's a `goto`, also switch to `waitUntil: "domcontentloaded"` |
| `Command timed out after 2m 0s` / `Exit code 143` | The **outer Bash tool** killed it — not a dev-browser clock | Shorten the script / split the batch; no dev-browser flag fixes this |
| `Execution context was destroyed, most likely because of a navigation` | Read page state mid-navigation (after a submit/redirect) | `await page.waitForTimeout(…)` or `waitForLoadState` before reading; treat as transient and retry-until-settled |
| `DOM node N is stale or missing — re-run getVisibleDom()` | A `domCua` node id predates the latest snapshot, or the doc changed | Re-run `getVisibleDom()` and use fresh ids; re-snapshot after every navigation |
| `document is not defined` | DOM used at the **script top level** | Wrap in `page.evaluate(() => { … document … })` |
| `ReferenceError: <var> is not defined` inside `evaluate` | Closure can't see outer-script vars | Pass as args: `page.evaluate((v) => …, myVar)` |
| `fs is not available in the QuickJS sandbox` | `setInputFiles(path)` / `addInitScript({path})` | Canvas-inject upload (see recipes.md); addInitScript is broken in 0.2.8 (workarounds-0.2.8.md) |
| `Native binary not found for linux-x64` | Running the npm shim from WSL | Call the Windows `.exe` directly — see below |
| `Target page, context or browser has been closed` (headless, from WSL) | Headless fails over the WSL→Windows interop hop | Run **headful** (omit `--headless`) |
| `browserContext.newPage: … Failed to open a new tab` | Daemon tab exhaustion — usually concurrent agents leaking pages | See daemon-wedge ladder below |
| `Daemon connection closed unexpectedly` | Genuine daemon crash (its logs are discarded in 0.2.8) | Restart: `dev-browser stop` then a fresh call; if wedged, ladder below |
| A blank / `about:blank` page when you expected content | `getPage("name")` with a **wrong/typo'd name** silently mints a blank page | Check the page name matches an earlier `getPage` exactly |
| `net::ERR_CERT_*` / `ERR_HTTP2_PROTOCOL_ERROR` / `ERR_CONNECTION_TIMED_OUT` | Unrecoverable client-side network failure | Don't retry — fall back to firecrawl or a mirror |
| A screenshot of a bot-walled site that looks blank/wrong | Cloudflare/bot interstitial — **and the settle-loop can return `ok:true` on an unresolved challenge, so a "captured" screenshot may be the interstitial, not the content** | Check `page.title()` for a challenge phrase (`just a moment`, `verifying you are human`, `attention required`) before concluding IP-block/VPN. Wait for the challenge to clear and retry; don't dismiss a suspicious shot as a "transient glitch" without an actual retry |

## WSL invocation

The linux npm shim doesn't work. Call the Windows binary via interop:

```
/mnt/c/Users/<you>/AppData/Roaming/npm/node_modules/dev-browser/bin/dev-browser-windows-x64.exe
```

- Run **headful** (headless fails over the interop hop).
- Pass `--timeout` for long scroll/extract scripts.
- Only pass `--connect` if a debugging Chrome is already running (`--remote-debugging-port=9222`).
- A first run can race the page load and return zero — a same-request retry often succeeds.

## Daemon-wedge recovery ladder

A wedged instance can report healthy at the process level while its CDP channel is dead. Walk this in order — **don't reflexively `dev-browser stop`** (global; kills every agent):

1. `dev-browser status` — daemon up? how long?
2. `dev-browser browsers` — how many instances, whose? (a `stop` would kill all of them)
3. Probe on a **fresh** throwaway instance: `dev-browser --browser diag --timeout 20 <<'EOF' … EOF`. Loads fine there but not on the working instance? → that named instance's CDP wedged.
4. `dev-browser stop` (only once you've confirmed no other live instance you care about), pause ~2s, relaunch.
5. Still wedged after stop+relaunch? The Chromium profile is corrupt (often disk-full). Free space; on Windows a hung `--connect` may need `taskkill /F /T` on the chrome process. (A proper `dev-browser doctor` is in the patch playbook.)

**Prevention beats recovery:** per-agent `--browser`, one call at a time, `newPage()` + close in `finally` for one-shot work. See [swarm-dispatch.md](swarm-dispatch.md).

## Windows: subprocess wrapper hangs on cold start

Wrapping `dev-browser.exe` in Python `subprocess.run(..., capture_output=True)` (or any captured-pipe call) **hangs forever on a cold daemon start** — `dev-browser.exe` exits after handing off to a node+chromium daemon whose grandchildren inherit the stdout pipe, so the pipe never reaches EOF and the parent blocks past its own timeout. Fix: redirect stdout/stderr to a **tempfile** (`subprocess.run(..., stdout=fh, stderr=fh)`) and read the file back after the process exits — an inherited file handle can't block the parent's read.
