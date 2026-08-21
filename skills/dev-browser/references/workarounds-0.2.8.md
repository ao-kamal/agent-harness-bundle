# Installed-version workarounds

Gaps that are **still live** on the installed exe. Delete a row when that fix is on PATH.

| Gap | Workaround |
|---|---|
| `page.addInitScript()` throws `__transport_receive` / `ValidationError` | Do not use it. Inject with `page.evaluate()` after navigation |
| `getPage("typo")` silently mints a blank page | Treat `about:blank` as a wrong page name |
| `cua.click` / `domCua.click` may not wait for navigation | Pass `{ waitForNavigation: true }` or `waitForLoadState` yourself |
| WSL npm shim: `Native binary not found for linux-x64` | Call the Windows `.exe` (see [troubleshooting.md](troubleshooting.md)) |
| `~/.dev-browser/tmp/` and `browsers/` grow unbounded | Delete old files when no run is active |

Landed in `0.2.9-ergo` (do not work around these): `--timeout` on actions, `stop --browser`, `--json`, `capabilities` / `--version`, `readFile(..., "base64")`, `uploadFile()`, `--channel chrome`.
