# Codex flavor notes

This machine is running the Codex flavor of the harness. Shared flywheel rules still apply.

- Primary CLI is `codex`. Do not send the user to `claude` or `grok` unless they ask.
- Skills, hooks, and MCP for this flavor live under `~/.codex/`. Codex also scans `~/.agents/skills`.
- After compaction, re-read `AGENTS.md` (global + project) before continuing.
- Trust harness hooks inside Codex with `/hooks`. Untrusted user hooks are skipped.
- `ntm spawn --cod=N` is the official Codex worker. Do not invent a new ntm type.
- Inspect: `codex doctor`. MCP: `codex mcp list`.
