# Grok flavor notes

This machine is running the Grok flavor of the harness. Shared flywheel rules still apply.

- Primary CLI is `grok`. Do not send the user to `claude` unless they ask.
- Skills, hooks, agents, and MCP for this flavor live under `~/.grok/`.
- After compaction, re-read `AGENTS.md` (global + project) before continuing.
- Kimi is `/model kimi-for-coding`, not a Claude Terminal profile.
- `ntm` has no native Grok pane type. Operator sits in Grok. Worker panes stay `--cc` / `--cod` / `--gmi` / `--cc=N:kimi-for-coding`.
- Folder trust: project hooks and project MCP stay inert until `/hooks-trust` (or `grok --trust`).
- Inspect what actually loaded: `grok inspect`.
