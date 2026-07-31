# Dispatching subagents / swarms to use dev-browser

One shared daemon serves every agent on the machine. The single most expensive dev-browser incidents in the field were swarms wedging that shared daemon — 14 subagents each opening a page and never closing it (~50 min recovery), and one broken recipe baked into a dispatch template that all 8 subagents then reproduced with zero shared learning.

The fix is entirely in the dispatch prompt. Whatever the marching orders state, agents comply with; whatever they omit, agents improvise badly. So state it.

## Paste-in dispatch block

Include this **verbatim** in the marching orders of any subagent you send to use dev-browser:

```
BROWSER WORK — dev-browser rules (follow exactly):
- Run `dev-browser --help` first. Read it fully (don't `head` it — the method
  ladder and examples are at the bottom). The API is authoritative there.
- Use YOUR OWN browser instance: pass `--browser <your-unique-name>` on every
  call (e.g. `--browser agent-3`). This isolates you from other agents.
- NEVER run `dev-browser stop` — it is global and kills every agent's browser.
- ONE dev-browser call at a time. Never fire two in parallel; the daemon
  serializes them and wedges under load. Loop inside one script instead.
- Always pass `--timeout` (60+ for multi-step). Note: `--timeout` bounds the
  whole script; each Playwright action (goto/click/screenshot) has its OWN 30s
  default — pass `{ timeout: N, waitUntil: "domcontentloaded" }` on slow actions.
- Prefer locators (getByRole/getByText) over page.evaluate() DOM scans.
- Write results/screenshots to disk AS YOU GO (they persist in ~/.dev-browser/tmp),
  one file per item — so a mid-run stall loses one item, not the batch.
- Validate your script ONCE against a single real target before running it in a
  loop over many; retry a failed script AT MOST ONCE (a first run can race the page
  load and return zero; a second often succeeds) — then move on and flag it, don't
  retry-loop.
- If you cannot use dev-browser for ANY reason, SURFACE it — do NOT silently fall
  back to raw Playwright/firecrawl. Flag any text-sourced (non-browser-verified)
  data as such in your output; never present it as browser-verified.
```

## Why each line

| Line | Prevents (field cluster) |
|---|---|
| per-agent `--browser` | daemon-concurrency-wedge — the proven antidote; a 4-agent swarm with unique names had zero contention |
| never global `stop` | m11-23 — a reflexive `stop` killed two live production browsers |
| one call at a time | queue starvation — "parallel" calls serialized; one sat queued **3h44m** and killed the mission |
| `--timeout` + per-action `{timeout}` | timeout-layering — 15 identical 30s timeouts with zero adaptation across one swarm |
| write-to-disk incrementally | 600s watchdog stalls recovered as "finish from cache," not full re-run |
| surface, don't silently fall back | the fallback (firecrawl/raw Playwright) hit the same failures in a colder path and hid that browser verification never happened |

## Operator note

If you're driving the swarm and a pane wedges: **do not** reflexively `dev-browser stop`. Check `dev-browser browsers` first for other live instances. Diagnose with the daemon-wedge ladder in [troubleshooting.md](troubleshooting.md) before any kill.
