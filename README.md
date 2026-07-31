# claude-harness-bundle

Kamal's Claude Code working environment, packaged for a fresh Windows machine: the tools, the skills, the configuration, and — more important than any of those — the working discipline that makes it all pay off.

## What you get

- **Claude Code, configured**: a global CLAUDE.md + topical rules files that encode months of hard-won lessons, ~110 skills, hooks that guard against destructive commands and post-compaction amnesia, and a memory-keeping convention.
- **The flywheel CLI stack** (Jeffrey Emanuel's ecosystem): session search (cass), procedural memory (cm), bead task graphs (br + bv), multi-agent tmux orchestration (ntm), agent coordination (Agent Mail), account switching (caam), command guards (dcg + slb), and more.
- **A Windows + WSL hybrid architecture** that actually works: shared credentials, hot/cold filesystem discipline, self-healing symlinks, boot-time daemons.
- **The Kimi lane**: a second model provider wired in as a first-class fallback/workhorse.
- **A field guide** that teaches the mental models, because copying config files does not transfer judgment.

## Quick start

Assumes you already have the bundle folder on disk — SETUP.md Step 1 covers getting it if not.

```powershell
# 1. In the cloned bundle folder, unblock the downloaded files:
Get-ChildItem -Recurse | Unblock-File
# 2. Run the installer (resumable — re-run any time, it continues where it left off):
powershell -ExecutionPolicy Bypass -File install\install.ps1
```

Then follow **[SETUP.md](SETUP.md)** — it walks every step, including the interactive moments (Claude login, Ubuntu first launch, API keys, the optional vault).

## Repo layout

| Path | What |
|------|------|
| `install/` | The installer: `install.ps1` (orchestrator), `wsl-setup.sh` (WSL stage), secrets + MCP helpers, `smoke-test.sh` (validator), `uninstall.ps1` |
| `config/` | Templated configuration: CLAUDE.md core, rules files, hooks, WSL scripts, terminal config, the Kimi module |
| `skills/` | The skills payload (copied to `~/.claude/skills`) |
| `docs/field-guide/` | The assimilation layer — read chapter 01 first |
| `docs/methodology/` | The deeper methodology documents |
| `docs/maintenance.md` | Updates, re-checks, uninstall |
| `vault-starter/` | Optional Obsidian PKM starter |

## After installing

1. Open a **new** terminal (PATH changed).
2. Confirm the smoke test was green (the installer runs it; re-run any time: `bash install/smoke-test.sh`).
3. Read `docs/field-guide/01-philosophy.md`. The rest of the guide in order after that.
4. Start your first real project with the `/flywheel-planning` skill.

## Updating

Kamal pushes improvements to this repo. You run `git pull` then `install\install.ps1 -Update` — the flag re-deploys skills and config while leaving completed installs alone. Details in [docs/maintenance.md](docs/maintenance.md).
