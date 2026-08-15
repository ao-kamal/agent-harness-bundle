# SETUP — Antigravity flavor (Gemini-line)

This walks a Windows machine from a fresh disk (or from another flavor install) to a working Antigravity CLI harness. The flywheel tools are the same. Login, skills, hooks, plugins, and MCP land under `~/.gemini/antigravity-cli` and `~/.gemini/config`.

This is the Gemini-line flavor. Consumer Gemini CLI stopped serving on 18 June 2026. ntm already supports Antigravity as `--agy`. `--gmi` is the legacy Gemini CLI flag. This flavor does not invent a new ntm pane type.

## Before you start

Same machine requirements as the Claude flavor (see root [SETUP.md](../../SETUP.md)).

**Accounts**

| Account | Needed when | Where |
|---------|-------------|-------|
| Google (Antigravity) | Stage 3, required | first `agy` launch, or a Gemini API key |
| GitHub | recommended | github.com |

**Install the official Antigravity CLI first** (this installer will not invent an `agy` binary):

```powershell
# Official Windows installer
irm https://antigravity.google/cli/install.ps1 | iex
```

```bash
# Official macOS / Linux / WSL
curl -fsSL https://antigravity.google/cli/install.sh | bash
```

Docs: https://antigravity.google/docs/cli/install

The binary is `agy`. On Windows it lands at `%LOCALAPPDATA%\agy\bin\agy.exe`.

## Step 1 — Get the bundle

```powershell
Get-ChildItem -Recurse | Unblock-File
powershell -ExecutionPolicy Bypass -File install\install-antigravity.ps1
```

## Step 2 — What the installer does

Same shape as the Grok installer, Antigravity-targeted:

- **0–2** flywheel CLIs (skipped if another flavor already did them)
- **3** `agy` login (browser, or SSH/device code). Optional: `GEMINI_API_KEY` + `modelProvider=gemini` in settings
- **4** deploys skills to `~/.gemini/antigravity-cli/skills`, rules, the `harness-bundle` plugin (hooks), and `settings.json`
- **5** WSL (shared; skipped if already completed). On WSL, install official `agy` so `ntm spawn --agy` can find it
- **7** writes `~/.gemini/config/mcp_config.json` (playwright, youtube, apify, agent-mail)
- **8–10** Cass Watch daemon, optional vault
- **11** `install/smoke-test-antigravity.sh`

State: `%USERPROFILE%\.harness-bundle-antigravity-state.json`.

## Step 3 — After install

1. Open a **new** terminal.
2. `agy` once so login completes.
3. `agy plugin list` — expect `harness-bundle`.
4. `bash install/smoke-test-antigravity.sh`
5. Read `docs/field-guide/01-philosophy.md`, then `docs/field-guide/08-antigravity-flavor.md`.

## ntm swarms

```bash
ntm spawn myproject --agy=2
```

Unattended panes use the official flag `agy --dangerously-skip-permissions`. Antigravity CLI is a TUI built for SSH, tmux, and headless print mode (`agy -p`).

Do not spawn `--gmi` unless you still have a paid/enterprise Gemini CLI that actually serves.

## Updating

```powershell
git pull
powershell -ExecutionPolicy Bypass -File install\install-antigravity.ps1 -Update
```
