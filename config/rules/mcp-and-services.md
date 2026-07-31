# MCP Servers & Local Services

## MCP scopes

- **Local scope**: private to current project (`--scope local`)
- **Project scope**: shared via committed `.mcp.json` (`--scope project`)
- **User scope**: available across all projects (`--scope user`) — **the default choice here**

## Registered MCP servers (recreation commands)

```bash
claude mcp add playwright "npx @playwright/mcp@latest" --scope user
claude mcp add mcp-youtube "npx -y @anaisbetts/mcp-youtube" --scope user
claude mcp add apify --transport http https://mcp.apify.com --scope user
# n8n (register when n8n work resumes; docker + local n8n instance required; mint the API key in n8n Settings → API):
claude mcp add-json --scope user n8n-mcp '{"command":"docker","args":["run","-i","--rm","--init","-e","MCP_MODE=stdio","-e","LOG_LEVEL=error","-e","DISABLE_CONSOLE_OUTPUT=true","-e","N8N_API_URL=http://host.docker.internal:5678","-e","N8N_API_KEY=your_api_key","-e","WEBHOOK_SECURITY_MODE=moderate","ghcr.io/czlonkowski/n8n-mcp:latest"]}'
# Agent Mail — server runs IN WSL; BOTH sides register against 127.0.0.1 (never localhost — IPv6 trap, see rules/windows-commands.md):
# Windows:
claude mcp add --scope user --transport http mcp-agent-mail "http://127.0.0.1:8765/mcp/" --header "Authorization: Bearer <token-from-config.env>"
# WSL (identical URL — the server is local to WSL):
claude mcp add --scope user --transport http mcp-agent-mail "http://127.0.0.1:8765/mcp/" --header "Authorization: Bearer <token-from-config.env>"
```

Do NOT declare MCP servers via a `mcpServers` block in `settings.json` — Claude Code silently ignores it there (upstream issue #97). `claude mcp add` is the only real registration path.

## Agent Mail (if you set it up)

Multi-agent coordination layer (file reservations, messaging, inboxes) used by ntm swarms.

- **Server runs in WSL**: `am serve-http --host 0.0.0.0 --port 8765`, started by the WSL `[boot] command` hook (`/usr/local/sbin/mount-fast-data.sh`) on every WSL cold boot — NOT systemd, NOT a Windows scheduled task. Logs: `/root/.config/mcp-agent-mail/serve.log`. Process name is `am serve-http` — find via `pgrep -af 'serve-http'`; stop with `pkill -f 'am serve-http'` (SIGTERM, NEVER -9 / taskkill — force-kill corrupts the SQLite WAL).
- **Do not run this as a Windows-native daemon.** A Windows-native build of the server hits NTFS durable-write failures under its write-back queue — run it in WSL against native ext4 storage instead.
- **Reachability**: mirrored networking + `127.0.0.1:8765` from both OSes. Health: `curl.exe http://127.0.0.1:8765/health` (allow 10-15s after server start before judging).
- **Config:** `C:\Users\{{WIN_USER}}\.config\mcp-agent-mail\config.env` — `HTTP_BEARER_TOKEN` lives here (the ONLY place it should exist; generate a fresh one, never reuse a token from anywhere else).
- **CLI operator:** `am` (same binary both sides). `am setup run` writes MCP config to `~/.claude/settings.json` which Claude Code ignores (issue #97) — use `claude mcp add` directly for Claude Code; `am setup` is fine for other clients (Codex, Gemini).

## Morph MCP tools

Server `morph-mcp` registration exposes `codebase_search` / `edit_file` (gated by `MORPH_API_KEY`). **Tool naming is ambiguous** — the config's `ENABLED_TOOLS` names don't always match what the deferred-tools catalog exposes (no `warpgrep_` prefix), and the tools intermittently disappear mid-session. **Verify the actual exposed name via ToolSearch before use** (`query="morph"`); if schemas don't load, fall back to native Grep/Read/Edit for that turn.

- Prefer `edit_file` over `str_replace` or full file writes (fuzzy matching, fewer errors).
- Prefer `warpgrep_codebase_search` for vague/semantic searches ("where is the code for X"); direct `rg` only for exact strings. When spawning Task agents for codebase exploration, append the tool-preference note to their prompt so they inherit it.

## n8n workflow automation

When the user mentions workflow automation or n8n: ask first "Would you like me to use n8n for this? I have the n8n-MCP server connected." If yes, `cd` into your n8n project and read its own nested `CLAUDE.md` in full before acting. Local instance at http://localhost:5678; manage via `docker start n8n` / `docker stop n8n` / `docker ps | grep n8n`.
