# Antigravity-flavor MCP registrations (Windows)
# Official file: ~/.gemini/config/mcp_config.json
# Remote servers use serverUrl. Idempotent. Values never echoed.

$ErrorActionPreference = 'Stop'
function Write-Info { param($m) Write-Host "-> $m" -ForegroundColor Cyan }
function Write-Ok   { param($m) Write-Host "OK $m" -ForegroundColor Green }
function Write-Warn2 { param($m) Write-Host "WARN $m" -ForegroundColor Yellow }

$cfgDir = Join-Path $env:USERPROFILE '.gemini\config'
$cfg = Join-Path $cfgDir 'mcp_config.json'
New-Item -ItemType Directory -Force $cfgDir | Out-Null

$doc = @{ mcpServers = @{} }
if (Test-Path $cfg) {
    try {
        $existing = Get-Content $cfg -Raw | ConvertFrom-Json
        if ($existing.mcpServers) {
            $existing.mcpServers.PSObject.Properties | ForEach-Object {
                $doc.mcpServers[$_.Name] = $_.Value
            }
        }
    } catch {
        Copy-Item $cfg "$cfg.bak-harness-bundle"
        Write-Warn2 "existing mcp_config.json was not valid JSON; backed up"
    }
}

if (-not $doc.mcpServers.ContainsKey('playwright')) {
    $doc.mcpServers['playwright'] = @{ command = 'npx'; args = @('@playwright/mcp@latest') }
}
if (-not $doc.mcpServers.ContainsKey('mcp-youtube')) {
    $doc.mcpServers['mcp-youtube'] = @{ command = 'npx'; args = @('-y', '@anaisbetts/mcp-youtube') }
}
if (-not $doc.mcpServers.ContainsKey('apify')) {
    $doc.mcpServers['apify'] = @{ serverUrl = 'https://mcp.apify.com' }
}

$amCfg = Join-Path $env:USERPROFILE '.config\mcp-agent-mail\config.env'
if (Test-Path $amCfg) {
    $line = (Select-String -Path $amCfg -Pattern '^HTTP_BEARER_TOKEN=').Line
    if ($line) {
        $token = ($line -split '=', 2)[1].Trim()
        $doc.mcpServers['mcp-agent-mail'] = @{
            serverUrl = 'http://127.0.0.1:8765/mcp/'
            headers = @{ Authorization = "Bearer $token" }
        }
        Write-Ok "mcp-agent-mail registered at 127.0.0.1:8765"
    }
} else {
    Write-Warn2 "Agent Mail config not found - run the WSL stage first, then re-run this script"
}

$json = $doc | ConvertTo-Json -Depth 8
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($cfg, $json, $utf8)
Write-Ok "wrote $cfg"
Write-Ok "MCP registration done - verify with /mcp inside agy"
