# secrets-setup.ps1 - Stage 6 of install.ps1: the OpenCode Console key.
#
# The settings fragment ships a placeholder bearer in
# env.ANTHROPIC_AUTH_TOKEN because a real oc_sk_ key must never enter the
# bundle (it is a public repo). This script asks for it once, writes it into
# the live ~/.claude/settings.json, and proves it works against the Console
# models endpoint - a GET that spends no tokens, unlike an inference call.
#
# The Go harness route needs a real key: the free-model placeholder that
# fragment v2 shipped stopped working when the route moved to
# https://opencode.ai/inference/go/anthropic (measured 400/401 on a real
# route). If Claude Code is signed in to a claude.ai account, run /logout in
# a session first so that login is never sent to the gateway.

$ErrorActionPreference = 'Stop'

$SettingsPath = Join-Path $env:USERPROFILE '.claude\settings.json'
$PlaceholderPattern = 'oc_sk_[A-Za-z0-9][A-Za-z0-9_-]{8,}'

if (-not (Test-Path $SettingsPath)) {
    Write-Host "No $SettingsPath found. Run install.ps1 first so the settings fragment deploys, then re-run this." -ForegroundColor Red
    exit 1
}

$settings = Get-Content $SettingsPath -Raw -Encoding utf8 | ConvertFrom-Json
$current = $settings.env.ANTHROPIC_AUTH_TOKEN
$isPlaceholder = [string]::IsNullOrWhiteSpace($current) -or $current -notmatch $PlaceholderPattern

if (-not $isPlaceholder) {
    Write-Host "A real key already appears present (oc_sk_...$(($current -as [char[]] | Select-Object -Last 6) -join '')). Re-provision?" -ForegroundColor Yellow
    $again = Read-Host "Provision a fresh key anyway? [y/N]"
    if ($again -notmatch '^[Yy]') { Write-Host "Keeping the existing key."; exit 0 }
}

Write-Host ""
Write-Host "1. Sign in at https://opencode.ai/console and open API keys." -ForegroundColor Cyan
Write-Host "2. Create/copy a personal key (oc_sk_...). It lives only on this machine:"
Write-Host "   this script writes it to settings.json and nowhere in the bundle repo."
Write-Host ""
$key = (Read-Host "Paste the oc_sk_ key").Trim()

if ($key -notmatch ('^' + $PlaceholderPattern + '$')) {
    Write-Host "That does not look like an OpenCode Console key (expected oc_sk_...)." -ForegroundColor Red
    exit 1
}

# JSON round-trip keeps every other key in the file intact.
$settings.env.ANTHROPIC_AUTH_TOKEN = $key
$settings | ConvertTo-Json -Depth 20 | Set-Content -Path $SettingsPath -Encoding utf8
Write-Host "Key written to settings.json." -ForegroundColor Green

Write-Host "Verifying against the Console (models list - zero-token request)..." -ForegroundColor Cyan
try {
    $resp = Invoke-WebRequest -Uri 'https://opencode.ai/inference/v1/models' -Method GET `
        -Headers @{ Authorization = "Bearer $key" } -UseBasicParsing -TimeoutSec 30
    $count = ($resp.Content | ConvertFrom-Json).data.Count
    if ($count -gt 0) {
        Write-Host "Key verified: $count models reachable on the workspace." -ForegroundColor Green
        Write-Host "Claude Code will confirm it live: run 'claude -p `"Reply with exactly: OK`"'." -ForegroundColor Cyan
        exit 0
    }
    Write-Host "Endpoint reachable but the model list came back empty - check the workspace." -ForegroundColor Yellow
    exit 1
} catch {
    Write-Host "Verification failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "The key was written; fix the key (Registry of truth: settings.json) or re-run secrets-setup.ps1." -ForegroundColor Yellow
    exit 1
}
