# OpenCode CLI — thin adapter

OpenCode already reads the shared brain. Do not copy skills or rules into `~/.config/opencode/`.

Official docs this adapter follows:

- Install: https://github.com/anomalyco/opencode README (npm / scoop)
- Skills: https://opencode.ai/docs/skills — loads `~/.claude/skills/*/SKILL.md`
- Rules: https://opencode.ai/docs/rules — `~/.claude/CLAUDE.md` if no `~/.config/opencode/AGENTS.md`; extra files via `instructions`
- MCP: https://opencode.ai/docs/mcp-servers
- Zen: https://opencode.ai/docs/zen — `/connect` then `/models`
- Auth: `opencode auth login` stores keys in `~/.local/share/opencode/auth.json`

## On a machine that already has the shared brain

```powershell
npm i -g opencode-ai@latest
powershell -ExecutionPolicy Bypass -File install\install-opencode.ps1
opencode auth login --provider opencode
opencode --version
```

What `install-opencode.ps1` does:

1. Refuses to run until `~/.claude/skills` exists (run `install\install.ps1` first).
2. Writes `~/.config/opencode/opencode.jsonc` from `config/opencode/opencode.jsonc.fragment` (merge, no clobber of unrelated keys).
3. Points `instructions` at `~/.claude/rules/*.md`. Does **not** write `AGENTS.md`, so OpenCode keeps using `~/.claude/CLAUDE.md` (official Claude Code fallback).
4. Registers the same MCP servers as the bundle (playwright, youtube, apify, agent-mail at `127.0.0.1:8765`).
5. Deletes leftover free-tier bridge plugin if present.
6. Default model: `opencode/muse-spark-1.3-contributor-free` (native Zen, not the Grok/Claude proxy).

What it does **not** do: copy skills, copy rules, invent a second brain, keep the Grok/Claude free-tier `opencode run` passthrough.

## Daily use

- Sit in `opencode` (TUI) or `opencode run`.
- Pick Zen models with `/models`. Free Muse Spark works here because this **is** OpenCode.
- Edit rules and skills under `~/.claude/` once. OpenCode picks them up.

## Auth

If `opencode auth list` already shows OpenCode Zen, skip login. Otherwise:

```
opencode auth login --provider opencode
```

Paste the key from https://opencode.ai/zen (or the `OPENCODE_API_KEY` you already use).

## Grok / Claude Code

Those front ends keep their own adapters. Free Zen is no longer routed through them. Paid OpenCode Go through the Grok filter proxy is unchanged.
