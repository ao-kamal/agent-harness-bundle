# Antigravity flavor notes

This machine is running the Antigravity flavor of the harness (Gemini-line). Shared flywheel rules still apply.

- Primary CLI is `agy`. Do not send the user to `gemini` unless they still have a paid/enterprise Gemini CLI that actually serves.
- Consumer Gemini CLI stopped on 2026-06-18. The replacement is Antigravity CLI.
- Skills live in `~/.gemini/antigravity-cli/skills/`. Hooks live in the `harness-bundle` plugin.
- MCP lives in `~/.gemini/config/mcp_config.json` (global) or `.agents/mcp_config.json` (project).
- After compaction, re-read `AGENTS.md` (global + project) before continuing.
- `ntm spawn --agy=N` is the official Antigravity worker. `--gmi` is legacy. Do not invent a new ntm type.
- Inspect: `agy plugin list`, `/mcp`, `/hooks`.
