# MCP Servers & Local Services (Antigravity)

## MCP files

- **Global**: `~/.gemini/config/mcp_config.json`
- **Project**: `.agents/mcp_config.json`

Remote servers must use `serverUrl` (not `url` / `httpUrl`).

## Registered MCP servers

The installer writes playwright, mcp-youtube, and apify. Agent Mail is added only when `~/.config/mcp-agent-mail/config.env` exists:

```json
{
  "mcpServers": {
    "mcp-agent-mail": {
      "serverUrl": "http://127.0.0.1:8765/mcp/",
      "headers": {
        "Authorization": "Bearer <token-from-config.env>"
      }
    }
  }
}
```

Inspect with `/mcp` inside `agy`.

## Agent Mail

Same as the other flavors: server in WSL on `127.0.0.1:8765`. Config: `C:\Users\{{WIN_USER}}\.config\mcp-agent-mail\config.env`. Health: `curl.exe http://127.0.0.1:8765/health`.
