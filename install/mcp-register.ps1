# claude-harness-bundle - MCP registrations (both OS sides)
# Registration only ever happens via `claude mcp add` (settings.json mcpServers blocks
# are silently ignored by Claude Code - do not hand-edit those).
# Idempotent: re-adding an existing name is a no-op/notice. Values never echoed.

$ErrorActionPreference = 'Stop'
function Write-Info { param($m) Write-Host "-> $m" -ForegroundColor Cyan }
function Write-Ok   { param($m) Write-Host "OK $m" -ForegroundColor Green }
function Write-Warn2 { param($m) Write-Host "WARN $m" -ForegroundColor Yellow }

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) { throw "claude CLI not found - run install.ps1 stages first" }

Write-Info "Windows-side registrations (user scope)"
claude mcp add playwright "npx @playwright/mcp@latest" --scope user 2>$null
claude mcp add mcp-youtube "npx -y @anaisbetts/mcp-youtube" --scope user 2>$null
claude mcp add apify --transport http https://mcp.apify.com --scope user 2>$null
Write-Ok "playwright / mcp-youtube / apify registered (apify authenticates on first connect)"

# Agent Mail: token comes from the config the WSL stage generated. ALWAYS 127.0.0.1, never localhost.
$amCfg = Join-Path $env:USERPROFILE '.config\mcp-agent-mail\config.env'
if (Test-Path $amCfg) {
    $line = (Select-String -Path $amCfg -Pattern '^HTTP_BEARER_TOKEN=').Line
    if ($line) {
        $token = ($line -split '=', 2)[1].Trim()
        claude mcp add --scope user --transport http mcp-agent-mail "http://127.0.0.1:8765/mcp/" --header "Authorization: Bearer $token" 2>$null | Out-Null
        Write-Ok "mcp-agent-mail registered (Windows) at 127.0.0.1:8765"
    }
} else {
    Write-Warn2 "Agent Mail config not found - run the WSL stage first, then re-run this script"
}

# WSL-side registration: same server, same 127.0.0.1 URL (it's local to WSL).
$wslReady = $false
try { wsl -l -q 2>$null | Out-Null; if ($LASTEXITCODE -eq 0) { $wslReady = $true } } catch {}
if ($wslReady) {
    Write-Info "WSL-side registration"
    $shFile = Join-Path $env:TEMP 'hb-mcp-wsl.sh'
    @'
#!/usr/bin/env bash
set -euo pipefail
command -v claude >/dev/null 2>&1 || { echo "WARN: claude not on WSL PATH yet - re-run after the WSL stage"; exit 0; }
CFG=/root/.config/mcp-agent-mail/config.env
[ -f "$CFG" ] || { echo "WARN: WSL agent-mail config missing"; exit 0; }
set -a; source "$CFG"; set +a
claude mcp add --scope user --transport http mcp-agent-mail "http://127.0.0.1:8765/mcp/" --header "Authorization: Bearer $HTTP_BEARER_TOKEN" 2>/dev/null || true
echo "OK WSL mcp-agent-mail registered"
'@ -replace "`r`n", "`n" | Out-File $shFile -Encoding ascii
    $wslPath = '/mnt/c' + ($shFile.Substring(2) -replace '\\','/')
    wsl -d Ubuntu -u root -- bash $wslPath
}

Write-Info "n8n-mcp: not registered by default. When you run n8n locally, see SETUP.md 'n8n' for the one-line add command."
Write-Ok "MCP registration done - verify with: claude mcp list"
