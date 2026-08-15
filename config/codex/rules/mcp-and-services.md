# MCP Servers & Local Services (Codex)

## MCP scopes

- **User scope**: `~/.codex/config.toml` (`codex mcp add`, default)
- **Project scope**: `.codex/config.toml` (trusted projects only)

## Registered MCP servers (Codex)

```bash
codex mcp add playwright -- npx @playwright/mcp@latest
codex mcp add mcp-youtube -- npx -y @anaisbetts/mcp-youtube
codex mcp add apify --url https://mcp.apify.com
# Agent Mail — server runs IN WSL; register against 127.0.0.1 (never localhost).
# HTTP bearer is added by install/mcp-register-codex.ps1 from config.env.
```

Verify with `codex mcp list` and `/mcp` inside the TUI.

## Agent Mail

Same as the other flavors: server in WSL on `127.0.0.1:8765`. Config: `C:\Users\{{WIN_USER}}\.config\mcp-agent-mail\config.env`. Health: `curl.exe http://127.0.0.1:8765/health`.
