# claude-harness-bundle

Kamal's coding-agent working environment, packaged for a fresh Windows machine: the tools, the skills, the configuration, and — more important than any of those — the working discipline that makes it all pay off.

The flywheel is shared. The agent CLI you sit in is a **flavor**. Claude Code is the original. Grok is a first-class second flavor. More LLM front ends should land the same way — see [flavors/README.md](flavors/README.md).

## What you get

- **A configured agent CLI** (pick a flavor):
  - **Claude Code** — global `CLAUDE.md`, hooks in `~/.claude`, MCP via `claude mcp add`
  - **Grok** — global `AGENTS.md`, hooks in `~/.grok`, MCP via `grok mcp add`, custom agent `deep-researcher`
- **The flywheel CLI stack** (Jeffrey Emanuel's ecosystem): session search (cass), procedural memory (cm), bead task graphs (br + bv), multi-agent tmux orchestration (ntm), agent coordination (Agent Mail), account switching (caam), command guards (dcg + slb), and more.
- **A Windows + WSL hybrid architecture** that actually works: shared credentials, hot/cold filesystem discipline, self-healing symlinks, boot-time daemons.
- **The Kimi lane**: a second model provider. Claude flavor = Terminal env wrapper. Grok flavor = `/model kimi-for-coding`.
- **A field guide** that teaches the mental models, because copying config files does not transfer judgment.

## Quick start

Assumes you already have the bundle folder on disk — the flavor SETUP covers getting it if not.

```powershell
Get-ChildItem -Recurse | Unblock-File

# Claude Code flavor (original)
powershell -ExecutionPolicy Bypass -File install\install.ps1

# Grok flavor
powershell -ExecutionPolicy Bypass -File install\install-grok.ps1
```

Then follow the matching setup page:

- Claude: **[SETUP.md](SETUP.md)**
- Grok: **[flavors/grok/SETUP.md](flavors/grok/SETUP.md)**

You can install both. They share flywheel tools and the skills payload. Each keeps its own login, hooks, and MCP.

## Repo layout

| Path | What |
|------|------|
| `install/` | `install.ps1` (Claude), `install-grok.ps1` (Grok), shared WSL stage, MCP helpers, smoke tests, uninstall |
| `config/` | Claude templates (CLAUDE.md, hooks, WSL, Kimi wrapper) |
| `config/grok/` | Grok templates (AGENTS.md, hooks, agents, rules overlays, Kimi model block) |
| `flavors/` | Flavor index and per-CLI setup |
| `skills/` | Skills payload (Claude → `~/.claude/skills`, Grok → `~/.grok/skills` + `~/.agents/skills`) |
| `docs/field-guide/` | Assimilation layer — chapter 01 first; chapter 06 is Grok-specific |
| `docs/methodology/` | Deeper methodology documents |
| `docs/maintenance.md` | Updates, re-checks, uninstall |
| `vault-starter/` | Optional Obsidian PKM starter |

## After installing

1. Open a **new** terminal (PATH changed).
2. Confirm the matching smoke test is green:
   - Claude: `bash install/smoke-test.sh`
   - Grok: `bash install/smoke-test-grok.sh` and `grok inspect`
3. Read `docs/field-guide/01-philosophy.md`. The rest of the guide in order after that. Grok users also read `docs/field-guide/06-grok-flavor.md`.
4. Start your first real project with the `/flywheel-planning` skill.

## Updating

```powershell
git pull
# Claude flavor
powershell -ExecutionPolicy Bypass -File install\install.ps1 -Update
# Grok flavor
powershell -ExecutionPolicy Bypass -File install\install-grok.ps1 -Update
```

The `-Update` flag re-deploys skills and config for that flavor and leaves completed installs alone. Details in [docs/maintenance.md](docs/maintenance.md).
