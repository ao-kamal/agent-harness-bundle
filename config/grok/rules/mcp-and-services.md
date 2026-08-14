# MCP Servers & Local Services

## MCP scopes

- **Project scope**: shared via committed `.grok/config.toml` (`grok mcp add --scope project`)
- **User scope**: `~/.grok/config.toml` (`grok mcp add`, default) — **the default choice here**

Claude Code scopes (`--scope local|project|user` on `claude mcp add`) still apply if that flavor is also installed.

## Registered MCP servers (Grok)

```bash
grok mcp add playwright -- npx @playwright/mcp@latest
grok mcp add mcp-youtube -- npx -y @anaisbetts/mcp-youtube
grok mcp add --transport http apify https://mcp.apify.com
# Agent Mail — server runs IN WSL; register against 127.0.0.1 (never localhost):
grok mcp add --transport http mcp-agent-mail "http://127.0.0.1:8765/mcp/" --header "Authorization: Bearer <token-from-config.env>"
```

Verify with `grok mcp list` and `grok inspect`.

## Registered MCP servers (Claude, if that flavor is also installed)

```bash
claude mcp add playwright "npx @playwright/mcp@latest" --scope user
claude mcp add mcp-youtube "npx -y @anaisbetts/mcp-youtube" --scope user
claude mcp add apify --transport http https://mcp.apify.com --scope user
claude mcp add --scope user --transport http mcp-agent-mail "http://127.0.0.1:8765/mcp/" --header "Authorization: Bearer <token-from-config.env>"
```

Do NOT declare MCP servers via a `mcpServers` block in Claude `settings.json` — Claude Code silently ignores it there (upstream issue #97). `claude mcp add` is the only real Claude registration path. Grok reads `[mcp_servers.*]` in `config.toml` and `grok mcp add` writes that.

## Agent Mail (if you set it up)

Multi-agent coordination layer (file reservations, messaging, inboxes) used by ntm swarms.

- **Server runs in WSL**: `am serve-http --host 0.0.0.0 --port 8765`, started by the WSL `[boot] command` hook (`/usr/local/sbin/mount-fast-data.sh`) on every WSL cold boot — NOT systemd, NOT a Windows scheduled task. Logs: `/root/.config/mcp-agent-mail/serve.log`. Process name is `am serve-http` — find via `pgrep -af 'serve-http'`; stop with `pkill -f 'am serve-http'` (SIGTERM, NEVER -9 / taskkill — force-kill corrupts the SQLite WAL).
- **Do not run this as a Windows-native daemon.** A Windows-native build of the server hits NTFS durable-write failures under its write-back queue — run it in WSL against native ext4 storage instead.
- **Reachability**: mirrored networking + `127.0.0.1:8765` from both OSes. Health: `curl.exe http://127.0.0.1:8765/health` (allow 10-15s after server start before judging).
- **Config:** `C:\Users\{{WIN_USER}}\.config\mcp-agent-mail\config.env` — `HTTP_BEARER_TOKEN` lives here (the ONLY place it should exist; generate a fresh one, never reuse a token from anywhere else).
- **CLI operator:** `am` (same binary both sides). For Grok, use `grok mcp add`. For Claude, use `claude mcp add` (`am setup run` writes Claude `settings.json`, which Claude ignores — issue #97).

## Morph MCP tools

Server `morph-mcp` registration exposes `codebase_search` / `edit_file` (gated by `MORPH_API_KEY`). **Tool naming is ambiguous** — the config's `ENABLED_TOOLS` names don't always match what the deferred-tools catalog exposes (no `warpgrep_` prefix), and the tools intermittently disappear mid-session. **Verify the actual exposed name via search_tool before use** (`query="morph"`); if schemas don't load, fall back to native Grep/Read/Edit for that turn.

- Prefer `edit_file` over `str_replace` or full file writes (fuzzy matching, fewer errors).
- Prefer `warpgrep_codebase_search` for vague/semantic searches ("where is the code for X"); direct `rg` only for exact strings. When spawning subagents for codebase exploration, append the tool-preference note to their prompt so they inherit it.

## n8n workflow automation

When the user mentions workflow automation or n8n: ask first "Would you like me to use n8n for this? I have the n8n-MCP server connected." If yes, `cd` into your n8n project and read its own nested `AGENTS.md` / `CLAUDE.md` in full before acting. Local instance at http://127.0.0.1:5678; manage via `docker start n8n` / `docker stop n8n` / `docker ps`.
