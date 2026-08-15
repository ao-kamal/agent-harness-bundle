# agent-harness-bundle

A coding-agent working environment for a Windows + WSL machine: the tools, the skills, the configuration, and — more important than any of those — the working discipline that makes it all pay off.

The brain is shared. The CLI you sit in is a front end. Edit `~/.claude/` once; Claude Code and Grok Build both read it. Do not copy the tree per harness.

## What you get

- **One shared brain** in `~/.claude/`: global `CLAUDE.md`, topic rules, ~110 skills, dcg + post-compact hooks, Claude auto-memory.
- **Front ends that consume it**: Claude Code natively; Grok Build via `compat.claude`; Antigravity CLI (`agy`) via junctions onto `~/.claude` (not a second copy).
- **The flywheel CLI stack** (Jeffrey Emanuel's ecosystem): session search (cass), procedural memory (cm), bead task graphs (br + bv), multi-agent tmux orchestration (ntm), agent coordination (Agent Mail), account switching (caam), command guards (dcg + slb), and more.
- **A Windows + WSL hybrid architecture** that actually works: shared credentials, hot/cold filesystem discipline, self-healing symlinks, boot-time daemons.
- **The Kimi lane** and a **Grok-sub lane** for ntm worker panes (Claude Code CLI pointed at those providers). ntm has no native Grok Build pane type yet.
- **A field guide** that teaches the mental models, because copying config files does not transfer judgment.

## Quick start

Assumes you already have the bundle folder on disk — SETUP.md Step 1 covers getting it if not.

```powershell
Get-ChildItem -Recurse | Unblock-File
powershell -ExecutionPolicy Bypass -File install\install.ps1
```

That deploys the shared brain to `~/.claude` and the flywheel. Then, if the daily driver is Grok Build:

```powershell
powershell -ExecutionPolicy Bypass -File install\install-grok.ps1
```

That is a **thin adapter**. It does not copy skills or rules. It enables Grok memory, junctions Claude auto-memory so Grok can read and write it, pins `compat.claude` on, and registers a compact hook that calls the shared PCR script.

If the daily driver is Antigravity CLI (`agy`):

```powershell
powershell -ExecutionPolicy Bypass -File install\install-antigravity.ps1
```

That only junctions `~/.gemini/antigravity-cli/skills` and `rules` onto `~/.claude`. ntm already has `--agy`.

Follow **[SETUP.md](SETUP.md)**. Grok: **[flavors/grok/SETUP.md](flavors/grok/SETUP.md)**. Antigravity: **[flavors/antigravity/SETUP.md](flavors/antigravity/SETUP.md)**.

## Repo layout

| Path | What |
|------|------|
| `install/` | `install.ps1` (shared brain + flywheel), `install-grok.ps1`, `install-antigravity.ps1`, WSL stage, smoke tests, uninstall |
| `config/` | Shared templates: CLAUDE.md, rules (including `harness-shared.md`), hooks, WSL, Kimi/Grok-sub `cc-router` |
| `config/grok/` | Thin Grok-only adapters (memory/compat fragment + compact hook JSON). Not a second brain. |
| `skills/` | Skills payload → `~/.claude/skills` only |
| `docs/field-guide/` | Assimilation layer — chapter 01 first; chapter 06 is the Grok front-end map |
| `docs/methodology/` | Deeper methodology documents |
| `docs/maintenance.md` | Updates, re-checks, uninstall |
| `vault-starter/` | Optional Obsidian PKM starter |

## After installing

1. Open a **new** terminal (PATH changed).
2. Confirm the smoke test is green (`bash install/smoke-test.sh`). Grok users also run `bash install/smoke-test-grok.sh` and `grok inspect`.
3. Read `docs/field-guide/01-philosophy.md`.
4. Start your first real project with the `/flywheel-planning` skill.

## Updating

```powershell
git pull
powershell -ExecutionPolicy Bypass -File install\install.ps1 -Update
powershell -ExecutionPolicy Bypass -File install\install-grok.ps1 -Update
```

`-Update` re-deploys the shared brain (and the thin Grok adapter) and leaves completed installs alone. Details in [docs/maintenance.md](docs/maintenance.md).
