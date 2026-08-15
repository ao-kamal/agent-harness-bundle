# Codex-flavor MCP registrations (Windows)
# Stdio servers: `codex mcp add`. HTTP servers: ~/.codex/config.toml
# Idempotent. Values never echoed.

$ErrorActionPreference = 'Stop'
function Write-Info { param($m) Write-Host "-> $m" -ForegroundColor Cyan }
function Write-Ok   { param($m) Write-Host "OK $m" -ForegroundColor Green }
function Write-Warn2 { param($m) Write-Host "WARN $m" -ForegroundColor Yellow }

$codex = $null
$cmd = Get-Command codex -ErrorAction SilentlyContinue
if ($cmd) { $codex = $cmd.Source }
if (-not $codex) { throw "codex CLI not found - install official Codex CLI and re-run" }

function Invoke-CodexMcp {
    param([string[]]$McpArgs)
    $all = @('mcp') + $McpArgs
    & $codex $all 2>$null | Out-Null
}

Write-Info "Windows-side registrations (user scope)"
Invoke-CodexMcp @('add', 'playwright', '--', 'npx', '@playwright/mcp@latest')
Invoke-CodexMcp @('add', 'mcp-youtube', '--', 'npx', '-y', '@anaisbetts/mcp-youtube')
Write-Ok "playwright / mcp-youtube registered via codex mcp add"

$cfg = Join-Path $env:USERPROFILE '.codex\config.toml'
New-Item -ItemType Directory -Force (Split-Path $cfg) | Out-Null
if (-not (Test-Path $cfg)) { Set-Content -Path $cfg -Value '' -Encoding utf8 }

function Add-CodexHttpMcp {
    param([string]$Name, [string]$Url, [string]$AuthHeader)
    $raw = Get-Content $cfg -Raw
    if ($raw -match "\[mcp_servers\.$Name\]") {
        Write-Ok "config.toml already has [mcp_servers.$Name]"
        return
    }
    $block = @"

[mcp_servers.$Name]
url = "$Url"
"@
    if ($AuthHeader) {
        $block += "`nhttp_headers = { Authorization = `"$AuthHeader`" }`n"
    }
    Add-Content -Path $cfg -Value $block
    Write-Ok "appended [mcp_servers.$Name] to config.toml"
}

Add-CodexHttpMcp -Name 'apify' -Url 'https://mcp.apify.com' -AuthHeader $null

$amCfg = Join-Path $env:USERPROFILE '.config\mcp-agent-mail\config.env'
if (Test-Path $amCfg) {
    $line = (Select-String -Path $amCfg -Pattern '^HTTP_BEARER_TOKEN=').Line
    if ($line) {
        $token = ($line -split '=', 2)[1].Trim()
        Add-CodexHttpMcp -Name 'mcp-agent-mail' -Url 'http://127.0.0.1:8765/mcp/' -AuthHeader "Bearer $token"
    }
} else {
    Write-Warn2 "Agent Mail config not found - run the WSL stage first, then re-run this script"
}

Write-Ok "MCP registration done - verify with: codex mcp list"
