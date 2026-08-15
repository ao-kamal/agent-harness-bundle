# SETUP — Codex flavor

This walks a Windows machine from a fresh disk (or from a Claude/Grok flavor install) to a working Codex harness. The flywheel tools are the same. Login, hooks, MCP, and config land in `~/.codex`.

ntm already supports Codex as `--cod`. This flavor does not invent a new ntm pane type.

Budget 1–2 hours if you are starting from nothing. If another flavor already ran stages 0–2 and 5 (WSL), this installer skips them and only deploys the Codex side.

## Before you start

Same machine requirements as the Claude flavor (see root [SETUP.md](../../SETUP.md)): Windows 10 19041+ / Windows 11, x86_64, 15 GB free, Developer Mode for symlinks.

**Accounts**

| Account | Needed when | Where |
|---------|-------------|-------|
| ChatGPT / OpenAI (Codex) | Stage 3, required | chatgpt.com — `codex login` |
| GitHub | recommended (rate limits) | github.com |
| firecrawl / context7 / apify | optional | same as other flavors |

**Install the official Codex CLI first** (this installer will not invent a Codex binary):

```powershell
# Official Windows path (npm)
npm install -g @openai/codex

# Official macOS / Linux / WSL
# curl -fsSL https://chatgpt.com/codex/install.sh | sh
```

Docs: https://learn.chatgpt.com/codex/cli

## Step 1 — Get the bundle

Clone this repo, then from the bundle folder:

```powershell
Get-ChildItem -Recurse | Unblock-File
powershell -ExecutionPolicy Bypass -File install\install-codex.ps1
```

## Step 2 — What the Codex installer does

Same 11-stage shape as `install-grok.ps1`, Codex-targeted:

- **0–2** package managers + flywheel CLIs (skipped if another flavor already did them)
- **3** `codex login` (manual browser / device auth)
- **4** deploys skills, `~/.codex/AGENTS.md`, hooks, rules, and `config.toml` (`features.hooks = true`)
- **5** WSL (shared script; skipped if already completed)
- **7** `codex mcp add` for playwright, youtube, apify, agent-mail
- **8–10** Cass Watch daemon, optional vault
- **11** `install/smoke-test-codex.sh`

State is stored in `%USERPROFILE%\.harness-bundle-codex-state.json` so flavors do not clobber each other's checkpoints.

## Step 3 — After install

1. Open a **new** terminal.
2. `codex doctor`
3. Inside Codex, run `/hooks` and trust the harness hooks (Codex skips untrusted user hooks).
4. `bash install/smoke-test-codex.sh`
5. Read `docs/field-guide/01-philosophy.md`, then `docs/field-guide/07-codex-flavor.md`.

## ntm swarms

```bash
ntm spawn myproject --cod=2
ntm send myproject --cod "Take the next ready bead."
```

NTM launches Codex with `--dangerously-bypass-approvals-and-sandbox` (the existing `cod` alias). Do not invent a second Codex agent type.

On Windows, ntm itself still runs in WSL. The Codex binary used by swarm panes is the one on the Ubuntu PATH.

## Updating

```powershell
git pull
powershell -ExecutionPolicy Bypass -File install\install-codex.ps1 -Update
```
