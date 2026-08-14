# Grok-flavor MCP registrations (Windows + WSL)
# Registration is via `grok mcp add` into ~/.grok/config.toml.
# Idempotent: re-adding an existing name is a no-op/notice. Values never echoed.

$ErrorActionPreference = 'Stop'
function Write-Info { param($m) Write-Host "-> $m" -ForegroundColor Cyan }
function Write-Ok   { param($m) Write-Host "OK $m" -ForegroundColor Green }
function Write-Warn2 { param($m) Write-Host "WARN $m" -ForegroundColor Yellow }

$grok = $null
foreach ($c in @(
    (Join-Path $env:USERPROFILE '.grok\bin\grok.exe'),
    'grok'
)) {
    if ($c -eq 'grok') {
        $cmd = Get-Command grok -ErrorAction SilentlyContinue
        if ($cmd) { $grok = $cmd.Source; break }
    } elseif (Test-Path $c) { $grok = $c; break }
}
if (-not $grok) { throw "grok CLI not found - install Grok Build and re-run" }

function Invoke-GrokMcp {
    param([string[]]$McpArgs)
    $all = @('mcp') + $McpArgs
    & $grok $all 2>$null | Out-Null
}

Write-Info "Windows-side registrations (user scope)"
Invoke-GrokMcp @('add', 'playwright', '--', 'npx', '@playwright/mcp@latest')
Invoke-GrokMcp @('add', 'mcp-youtube', '--', 'npx', '-y', '@anaisbetts/mcp-youtube')
Invoke-GrokMcp @('add', '--transport', 'http', 'apify', 'https://mcp.apify.com')
Write-Ok "playwright / mcp-youtube / apify registered (apify authenticates on first connect)"

$amCfg = Join-Path $env:USERPROFILE '.config\mcp-agent-mail\config.env'
if (Test-Path $amCfg) {
    $line = (Select-String -Path $amCfg -Pattern '^HTTP_BEARER_TOKEN=').Line
    if ($line) {
        $token = ($line -split '=', 2)[1].Trim()
        Invoke-GrokMcp @(
            'add', '--transport', 'http', 'mcp-agent-mail',
            'http://127.0.0.1:8765/mcp/',
            '--header', "Authorization: Bearer $token"
        )
        Write-Ok "mcp-agent-mail registered (Windows) at 127.0.0.1:8765"
    }
} else {
    Write-Warn2 "Agent Mail config not found - run the WSL stage first, then re-run this script"
}

$wslReady = $false
try { wsl -l -q 2>$null | Out-Null; if ($LASTEXITCODE -eq 0) { $wslReady = $true } } catch {}
if ($wslReady) {
    Write-Info "WSL-side: Agent Mail is reached from Windows Grok at 127.0.0.1:8765 (no separate WSL grok mcp add required)"
}

Write-Info "n8n-mcp: not registered by default. When you run n8n locally, see flavors/grok/SETUP.md"
Write-Ok "MCP registration done - verify with: grok mcp list"
