# Installed-version workarounds (dev-browser 0.2.8)

Bugs and gaps in the **installed 0.2.8 build** that force a workaround. Each has a fix queued in the agent-ergonomics patch playbook (`Documents/Projects/dev-browser/agent_ergonomics_audit/audit/playbook.md`). **Delete an entry here the moment its upstream fix lands** — this file should shrink to nothing over time.

| Gap in 0.2.8 | Workaround until fixed | Playbook item |
|---|---|---|
| `--timeout` does not raise Playwright's per-action timeout (they're independent clocks with identical error text) | Pass `{ timeout: N }` on each slow action; don't just raise `--timeout` | P0-1 |
| No per-instance stop — `dev-browser stop` is global and kills every browser | In a swarm, never call `stop`; give each agent its own `--browser <name>` and let idle instances be | P0-2 |
| `status` / `browsers` have no `--json` — ASCII tables only | Parse the table, or drive a script and log JSON yourself | P0-3 |
| No `capabilities`, no `--version`, no exit-code dictionary (exit 1 absorbs everything) | Read stderr *text* to classify failures; don't switch on the exit code | P0-4 |
| `page.addInitScript()` is broken in **all** forms (function/content/path) — throws an opaque `__transport_receive` / `ValidationError` | Don't use `addInitScript`. Inject via `page.evaluate()` after navigation instead | P2-3 |
| `readFile()` decodes UTF-8 only — silently corrupts binary (e.g. a screenshot read back) | Don't round-trip binary through `readFile`; generate files in the browser context (canvas-inject) | P2-1 |
| `setInputFiles(path)` fails (no sandbox fs), with no hint toward the workaround | Canvas-inject upload — see [recipes.md](recipes.md) | P2-1 |
| `browser.getPage("typo")` silently creates a blank page instead of erroring | Treat a blank/`about:blank` result as a probable wrong page name; keep names exact | P2-3 |
| `domCua` node ids are huge random integers, not the `node_id=1, 2` the help shows | Cosmetic — use whatever ids `getVisibleDom()` actually returns; don't assume small ints | P2-4 |
| WSL npm shim errors "Native binary not found for linux-x64" with no WSL hint | Call the Windows `.exe` directly (see [troubleshooting.md](troubleshooting.md)) | P3-5 |
| `install` can report success while Chromium is missing | After `install`, run a trivial `goto` to confirm the browser actually launches | P3-4 |
| `--connect run` silently swallows the subcommand (greedy optional value) | Don't combine `--connect` with a subcommand in one call | P3-2 |
| No `tmp`/profile GC — `~/.dev-browser/tmp/` and `browsers/` grow unbounded | Periodically clear old files manually (they're safe to delete when no run is active) | P3-6 |

## Help-vs-code mismatch (0.2.8)

- **`cua.click` / `domCua.click` navigation wait is contested — don't assume it waits.** The 0.2.8 `--help` prose says these "wait ~1s for a click-triggered navigation." A live test showed the opposite: the code default did **not** wait (page URL unchanged immediately after a default click). Treat the grace-wait as *not guaranteed*: if you need the post-click navigation to settle before you read state, pass `{ waitForNavigation: true }` explicitly (or add your own `waitForLoadState`). Repo HEAD reworded the prose; the safe move on any build is to not rely on an implicit wait.
- **`unsupported4`** — the opaque sandbox error string was replaced upstream with a named message. On 0.2.8 you may still see `unsupported4`; it means an unsupported sandbox API (usually `fs`).
