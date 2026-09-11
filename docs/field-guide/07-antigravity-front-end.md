# 07 — Antigravity as a front end

Antigravity CLI (`agy`) is Google's terminal agent. It replaced consumer Gemini CLI on 18 June 2026. ntm already has `--agy`. This chapter is only how it sits on the **same** brain as Claude and Grok.

Read 01–05 and `config/rules/harness-shared.md` first.

## What changes, what does not

Does **not** change: planning loop, `~/.claude/` skills/rules, flywheel, WSL hybrid.

Does change:

- You run `agy`, not `gemini`
- Antigravity has no `compat.claude` flag. The adapter is junctions (skills + rules + agents) onto `~/.claude`
- ntm worker flag is `--agy=N:<model-id>`. Always pass the id. Bare `--agy=N` pins Gemini 3.7 Flash High. `--gmi` is leftover Gemini CLI
- Do **not** put agy behind CLIProxy (account-ban risk). The WSL shim `/usr/local/bin/agy` execs the Windows `agy.exe` so Google OAuth stays on the Windows account

## Where it looks

| Thing | Canonical | Adapter |
|-------|-----------|---------|
| Skills | `~/.claude/skills/` | junction `~/.gemini/antigravity-cli/skills` |
| Rules | `~/.claude/rules/` | junction `~/.gemini/antigravity-cli/rules` |
| Project contract | repo `AGENTS.md` | none |
| Auth / TUI | Antigravity keyring / first `agy` login | none |

Do not copy the skills tree. If you already have a real folder at `~/.gemini/antigravity-cli/skills`, move it aside and re-run `install\install-antigravity.ps1`.

## Commands

| Gemini CLI (legacy) | Antigravity |
|---------------------|-------------|
| `gemini` | `agy` |
| ntm `--gmi` | ntm `--agy=N:<model-id>` |
| `~/.gemini/settings.json` | `~/.gemini/antigravity-cli/settings.json` |

List live ids with `agy models` before spawn. Common ids: `gemini-3.7-flash-high`, `gemini-3.1-pro-high`, `claude-sonnet-4-6`, `claude-opus-4-6-thinking`, `gpt-oss-120b-medium`.
