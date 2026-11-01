# opencode-key-setup.ps1 - Stage 6 of install.ps1: the OpenCode Console key.
#
# One canonical copy of the key lives in %USERPROFILE%\.config\opencode\key,
# machine-local and outside the bundle (it is a public repo). This script is
# the writer of the whole chain: it verifies the key against the Console
# models endpoint first - a GET that spends no tokens, unlike an inference
# call - then patches exactly one field, env.ANTHROPIC_AUTH_TOKEN, in both
# settings lanes: Windows ~/.claude/settings.json and WSL
# /root/.claude/settings.json. Nothing else in either file is rewritten.
#
# Rotation flow: replace the single line in the canonical key file (or paste
# the key once when the file does not exist yet), then run:
#   powershell -ExecutionPolicy Bypass -File install\opencode-key-setup.ps1 -Sync
# The Windows lane is rewritten only when the field actually differs; the WSL
# lane is skipped with a reason when its settings file is absent rather than
# half-created there. A failed verification writes nothing at all. The key is
# never echoed and never passed on argv (the WSL patch receives it on stdin).
#
# The Go harness route needs a real key: the free-model placeholder that
# fragment v2 shipped stopped working when the route moved to
# https://opencode.ai/inference/go/anthropic (measured 400/401 on a real
# route). If Claude Code is signed in to a claude.ai account, run /logout in
# a session first so that login is never sent to the gateway.

param([switch]$Sync)

$ErrorActionPreference = 'Stop'

$SettingsPath = Join-Path $env:USERPROFILE '.claude\settings.json'
$CanonPath = Join-Path $env:USERPROFILE '.config\opencode\key'
$PlaceholderPattern = 'oc_sk_[A-Za-z0-9][A-Za-z0-9_-]{8,}'

# Writes without a UTF-8 BOM. Set-Content -Encoding utf8 on Windows PowerShell
# 5.1 emits a BOM, which hardens JSON parsers against; the settings deploy
# machinery therefore avoids Set-Content for JSON and this script follows it.
function Write-Utf8NoBom {
    param([string]$Path, [string]$Text)
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

function Write-ConsoleHint {
    Write-Host "1. Sign in at https://opencode.ai/console and open API keys." -ForegroundColor Cyan
    Write-Host "2. Create/copy a personal key (oc_sk_...). It lives only on this machine:"
    Write-Host "   stored once in the canonical key file, never in the bundle repo."
}

function Read-CanonicalKey {
    if (-not (Test-Path $CanonPath)) { return $null }
    $key = (Get-Content $CanonPath -Raw).Trim()
    if ($key -notmatch ('^' + $PlaceholderPattern + '$')) {
        Write-Host "$CanonPath exists but does not contain a well-formed oc_sk_ key. Fix or delete it, then re-run this script." -ForegroundColor Red
        exit 1
    }
    return $key
}

# Returns the model count the workspace exposes (>= 0 on success), -1 on
# failure with the message captured in $script:VerifyErr. Spends no tokens.
$script:VerifyErr = $null
function Test-ConsoleKey {
    param([string]$Key)
    $script:VerifyErr = $null
    try {
        $resp = Invoke-WebRequest -Uri 'https://opencode.ai/inference/v1/models' -Method GET `
            -Headers @{ Authorization = "Bearer $Key" } -UseBasicParsing -TimeoutSec 30
        return ($resp.Content | ConvertFrom-Json).data.Count
    } catch {
        $script:VerifyErr = $_.Exception.Message
        return -1
    }
}

function Write-WindowsToken {
    param([string]$Key)
    # JSON round-trip keeps every other key in the file intact.
    $o = Get-Content $SettingsPath -Raw -Encoding utf8 | ConvertFrom-Json
    $o.env.ANTHROPIC_AUTH_TOKEN = $Key
    Write-Utf8NoBom -Path $SettingsPath -Text ($o | ConvertTo-Json -Depth 20)
}

# --- WSL lane --------------------------------------------------------------
function Test-WslSettings {
    # Python code handed to wsl.exe must use single quotes only: Windows
    # PowerShell strips embedded double quotes while re-encoding argv onto
    # the wsl bridge (measured: arrived as os.path.exists(/root/...)). A
    # double-quoted PS string around single-quoted python survives transit.
    $code = "import os;print(os.path.exists(os.path.expanduser('~/.claude/settings.json')))"
    $out = wsl -u root -- python3 -c $code
    if ($LASTEXITCODE -ne 0 -or ($out -join '').Trim() -ne 'True') {
        return @{ present = $false; detail = 'wsl, python3, or /root/.claude/settings.json unavailable' }
    }
    return @{ present = $true; detail = '' }
}

function Read-WslToken {
    $code = "import json,os;print(json.load(open(os.path.expanduser('~/.claude/settings.json'),encoding='utf-8')).get('env',{}).get('ANTHROPIC_AUTH_TOKEN',''))"
    $out = wsl -u root -- python3 -c $code
    if ($LASTEXITCODE -ne 0) { return $null }
    return ($out | Select-Object -Last 1).Trim()
}

function Set-WslToken {
    param([string]$Key)
    # The key travels on stdin so it never sits on an argv line visible to
    # process listings. The patch is one mechanical statement: set one field,
    # dump the same JSON structure back.
    $code = "import sys,json,os;k=sys.stdin.readline().strip();p=os.path.expanduser('~/.claude/settings.json');d=json.load(open(p,encoding='utf-8'));d.setdefault('env',{})['ANTHROPIC_AUTH_TOKEN']=k;open(p,'w',encoding='utf-8').write(json.dumps(d,indent=2));print('wsl-token-patched')"
    $out = $Key | wsl -u root -- python3 -c $code
    if ($LASTEXITCODE -ne 0) { return @{ ok = $false; detail = ($out -join ' ').Trim() } }
    return @{ ok = $true; detail = '' }
}

# Consistent outcome for both entry paths: verify -> canonical file ->
# Windows lane -> WSL lane, each after the previous one succeeded.
function Invoke-Provision {
    param([string]$Key)

    Write-Host "Verifying against the Console (models list - zero-token request)..." -ForegroundColor Cyan
    $count = Test-ConsoleKey -Key $Key
    if ($count -lt 0) {
        Write-Host "Verification failed: $script:VerifyErr" -ForegroundColor Red
        Write-Host "Nothing was written: the canonical key file, Windows and WSL settings are all untouched." -ForegroundColor Yellow
        exit 1
    }
    Write-Host "Key verified: $count models reachable on the workspace." -ForegroundColor Green
    if ($count -eq 0) {
        Write-Host "Endpoint reachable but the model list came back empty - check the workspace." -ForegroundColor Yellow
        exit 1
    }

    $canonDir = Split-Path $CanonPath -Parent
    if (-not (Test-Path $canonDir)) { New-Item -ItemType Directory -Path $canonDir -Force | Out-Null }
    Write-Utf8NoBom -Path $CanonPath -Text "$Key`n"
    Write-Host "Canonical key stored at $CanonPath." -ForegroundColor Green

    $current = (Get-Content $SettingsPath -Raw -Encoding utf8 | ConvertFrom-Json).env.ANTHROPIC_AUTH_TOKEN
    if ($current -eq $Key) {
        Write-Host "Windows settings.json already in sync." -ForegroundColor Cyan
    } else {
        Write-WindowsToken -Key $Key
        Write-Host "Windows settings.json patched (env.ANTHROPIC_AUTH_TOKEN only)." -ForegroundColor Green
    }

    if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) {
        Write-Host "WSL not installed here - the Windows lane is the only one provisioned." -ForegroundColor Yellow
    } else {
        $present = Test-WslSettings
        if (-not $present.present) {
            Write-Host "WSL lane skipped: $($present.detail). The other lane still runs on its own settings." -ForegroundColor Yellow
        } else {
            $wslNow = Read-WslToken
            if ($wslNow -eq $Key) {
                Write-Host "WSL lane already in sync." -ForegroundColor Cyan
            } else {
                $set = Set-WslToken -Key $Key
                if ($set.ok) {
                    Write-Host "WSL lane patched (env.ANTHROPIC_AUTH_TOKEN only)." -ForegroundColor Green
                } else {
                    Write-Host "WSL patch failed: $($set.detail)" -ForegroundColor Yellow
                    Write-Host "Windows and the canonical file are correct; re-run -Sync after fixing WSL." -ForegroundColor Yellow
                }
            }
        }
    }

    $tail = $Key.Substring($Key.Length - 6)
    Write-Host ""
    Write-Host "Key oc_sk_...$tail is now the carried credential for this machine." -ForegroundColor Green
    Write-Host "Claude Code will confirm it live: run 'claude -p `"Reply with exactly: OK`"'." -ForegroundColor Cyan
}

if (-not (Test-Path $SettingsPath)) {
    Write-Host "No $SettingsPath found. Run install.ps1 first so the settings fragment deploys, then re-run this." -ForegroundColor Red
    exit 1
}

if ($Sync) {
    $key = Read-CanonicalKey
    if (-not $key) {
        Write-Host "No canonical key yet at $CanonPath." -ForegroundColor Cyan
        Write-ConsoleHint
        Write-Host ""
        $key = (Read-Host "Paste the oc_sk_ key").Trim()
        if ($key -notmatch ('^' + $PlaceholderPattern + '$')) {
            Write-Host "That does not look like an OpenCode Console key (expected oc_sk_...)." -ForegroundColor Red
            exit 1
        }
    }
    Invoke-Provision -Key $key
    exit 0
}

# Stage 6 default path (called by the installer, or a first provisioning).
$settings = Get-Content $SettingsPath -Raw -Encoding utf8 | ConvertFrom-Json
$current = $settings.env.ANTHROPIC_AUTH_TOKEN
$isPlaceholder = [string]::IsNullOrWhiteSpace($current) -or $current -notmatch $PlaceholderPattern

if (-not $isPlaceholder) {
    $tail = $current.Substring($current.Length - 6)
    Write-Host "A real key already appears present (oc_sk_...$tail). Re-provision?" -ForegroundColor Yellow
    $again = Read-Host "Provision a fresh key anyway? [y/N]"
    if ($again -notmatch '^[Yy]') {
        Write-Host "Keeping the existing key. To rotate later: edit $CanonPath and re-run this script with -Sync."
        exit 0
    }
}

Write-ConsoleHint
Write-Host ""
$key = (Read-Host "Paste the oc_sk_ key").Trim()

if ($key -notmatch ('^' + $PlaceholderPattern + '$')) {
    Write-Host "That does not look like an OpenCode Console key (expected oc_sk_...)." -ForegroundColor Red
    exit 1
}

Invoke-Provision -Key $key
exit 0
