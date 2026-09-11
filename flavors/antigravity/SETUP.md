# Antigravity CLI — thin adapter

Antigravity (`agy`) is the Gemini-line terminal CLI. ntm already launches it with `--agy`. This flavor does **not** copy the brain.

Consumer Gemini CLI stopped serving on 18 June 2026. Use `agy`, not `gemini`. ntm `--gmi` is legacy.

## What this installer does

```powershell
powershell -ExecutionPolicy Bypass -File install\install-antigravity.ps1
```

1. Requires `~/.claude/skills` (run `install\install.ps1` first).
2. Junctions `~/.gemini/antigravity-cli/skills` → `~/.claude/skills`.
3. Junctions `~/.gemini/antigravity-cli/rules` → `~/.claude/rules`.

It does **not** copy skills, write a second AGENTS.md tree, or invent an ntm agent type.

Official binary (if missing):

```powershell
irm https://antigravity.google/cli/install.ps1 | iex
```

Docs: https://antigravity.google/docs/cli/install

## Daily use

- Sit in `agy`.
- Edit rules and skills under `~/.claude/` only.
- Project contract is still the repo `AGENTS.md`.
- Swarms: `ntm spawn <project> --agy=N:<model-id>` (always pass the id; bare `--agy=N` pins Gemini 3.7 Flash High). List ids with `agy models`. Do not put agy behind CLIProxy.
- WSL: ntm needs `/usr/local/bin/agy` exec'ing the Windows `agy.exe` so Google OAuth stays on the Windows account.

## If a junction is blocked

If `~/.gemini/antigravity-cli/skills` already exists as a real folder, the installer will not overwrite it. Move that folder aside and re-run.
