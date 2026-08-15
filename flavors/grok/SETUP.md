# SETUP — Grok flavor

This walks a Windows machine from a fresh disk (or from a Claude-flavor install) to a working Grok harness. The flywheel tools are the same as the Claude flavor. Login, hooks, MCP, agents, and config land in `~/.grok` instead of `~/.claude`.

Budget 1–2 hours if you are starting from nothing. If Claude-flavor stages 0–2 and 5 (WSL) already ran, this installer skips them and only deploys the Grok side.

## Before you start

Same machine requirements as the Claude flavor (see root [SETUP.md](../../SETUP.md)): Windows 10 19041+ / Windows 11, x86_64, 15 GB free, Developer Mode for symlinks.

**Accounts**

| Account | Needed when | Where |
|---------|-------------|-------|
| xAI / Grok | Stage 3, required | grok.com / x.ai — `grok login` |
| GitHub | recommended (rate limits) | github.com |
| Kimi Code | optional workhorse model | kimi.com — put the key in `~\.config\kimi\key` |
| firecrawl / context7 / apify | optional | same as Claude flavor |

## Step 1 — Get the bundle

Same as the Claude flavor. Clone this repo, then from the bundle folder:

```powershell
Get-ChildItem -Recurse | Unblock-File
powershell -ExecutionPolicy Bypass -File install\install-grok.ps1
```

## Step 2 — What the Grok installer does

11 stages, same shape as `install.ps1`, Grok-targeted:

- **0–2** package managers + flywheel CLIs. This is a real install, not a pointer at the Claude installer. Scoop buckets are cloned with `gh` (git mid-pack clones die on this host). `cm` / `cass` / `br` come from exact GitHub release assets with an MZ-header check — the Claude-flavor scoop `cm` hash is stale, and a `*windows*` glob can grab a non-PE file.
- **3** `grok login` (manual browser moment) — not Claude login
- **3b** notes Grok bundled document skills (docx/pdf/pptx). Does not run `claude plugin`
- **4** deploys skills, `AGENTS.md`, rules, hooks, and the `deep-researcher` agent to `~/.grok`
- **5** WSL (shared with the Claude flavor; skipped if that stage already completed)
- **6** secrets into `~\.env.private` (never into shared config)
- **7** `grok mcp add` for playwright, youtube, apify, agent-mail
- **8–10** Cass Watch daemon, WezTerm, optional vault
- **11** `install/smoke-test-grok.sh`

State is stored in `%USERPROFILE%\.harness-bundle-grok-state.json` so a Claude-flavor install and a Grok-flavor install do not clobber each other's checkpoints.

## Step 3 — After install

1. Open a **new** terminal.
2. `grok inspect` — confirm hooks, rules, skills, and the `deep-researcher` agent loaded.
3. `bash install/smoke-test-grok.sh`
4. Read `docs/field-guide/01-philosophy.md`, then `docs/field-guide/06-grok-flavor.md`.
5. Start real work with `/flywheel-planning` inside Grok.

## Kimi on Grok

Kimi is a custom model in `~/.grok/config.toml`, not a Claude env-wrapper tab.

1. Put the key (one line) in `C:\Users\<you>\.config\kimi\key`.
2. The installer writes a `[model.kimi-for-coding]` block that reads that file via `KIMI_API_KEY` / `ANTHROPIC_AUTH_TOKEN`.
3. In Grok: `/model kimi-for-coding` or `Ctrl+M`.

Grok's native models stay the default. Kimi is the cheap/fallback lane.

## ntm swarms

`ntm` still knows Claude / Codex / Gemini pane types. It does not have a native Grok pane type yet. On a Grok-flavor machine:

- You sit in **Grok** as the operator.
- Swarm worker panes still spawn as `--cc` / `--cod` / `--gmi` / Kimi-routed `--cc=N:kimi-for-coding`.
- Project rules stay in `AGENTS.md` so every pane type reads the same file.

## Updating

```powershell
git pull
powershell -ExecutionPolicy Bypass -File install\install-grok.ps1 -Update
```

That re-deploys Grok config and skills and leaves completed flywheel/WSL stages alone. Details in [docs/maintenance.md](../../docs/maintenance.md).
