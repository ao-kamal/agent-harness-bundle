# 07 — Antigravity as a front end

Antigravity CLI (`agy`) is Google's terminal agent. It replaced consumer Gemini CLI on 18 June 2026. ntm already has `--agy`. This chapter is only how it sits on the **same** brain as Claude and Grok.

Read 01–05 and `config/rules/harness-shared.md` first.

## What changes, what does not

Does **not** change: planning loop, `~/.claude/` skills/rules, flywheel, WSL hybrid.

Does change:

- You run `agy`, not `gemini`
- Antigravity has no `compat.claude` flag. The adapter is two junctions (skills + rules) onto `~/.claude`
- ntm worker flag is `--agy`. `--gmi` is leftover Gemini CLI

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
| ntm `--gmi` | ntm `--agy` |
| `~/.gemini/settings.json` | `~/.gemini/antigravity-cli/settings.json` |
