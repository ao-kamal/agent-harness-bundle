# Thin Grok adapter. Does NOT copy the brain.
#
#   powershell -ExecutionPolicy Bypass -File install\install-grok.ps1
#
# Assumes install.ps1 already deployed ~/.claude (skills, rules, hooks, flywheel).
# This script only: pin compat.claude, enable memory, junction Claude auto-memory,
# register a compact hook that calls the shared PCR script.

[CmdletBinding()]
param(
    [switch]$Quiet,
    [switch]$Update
)

$ErrorActionPreference = 'Stop'
$script:WinUser = $env:USERNAME
$script:GrokHome = Join-Path $env:USERPROFILE '.grok'
$script:ClaudeHome = Join-Path $env:USERPROFILE '.claude'
$script:StateFile = Join-Path $env:USERPROFILE '.harness-bundle-grok-state.json'

function Write-Info { param($m) if (-not $Quiet) { Write-Host "-> $m" -ForegroundColor Cyan } }
function Write-Ok   { param($m) if (-not $Quiet) { Write-Host "OK $m" -ForegroundColor Green } }
function Write-Warn2 { param($m) Write-Host "WARN $m" -ForegroundColor Yellow }

function Get-State {
    if (Test-Path $script:StateFile) { return (Get-Content $script:StateFile -Raw | ConvertFrom-Json) }
    return [pscustomobject]@{ completed = @() }
}
function Save-State { param($s) $s | ConvertTo-Json -Depth 4 | Out-File $script:StateFile -Encoding utf8 }
function Complete-Stage {
    param($s, $name)
    if (-not ($s.completed -contains $name)) { $s.completed = @($s.completed) + $name; Save-State $s }
    Write-Ok "stage complete: $name"
}

if (-not (Test-Path (Join-Path $script:ClaudeHome 'CLAUDE.md'))) {
    throw "Shared brain missing at $($script:ClaudeHome)\CLAUDE.md. Run install\install.ps1 first."
}

$state = Get-State
New-Item -ItemType Directory -Force (Join-Path $script:GrokHome 'hooks') | Out-Null
New-Item -ItemType Directory -Force (Join-Path $script:GrokHome 'memory') | Out-Null

# --- compat + memory in config.toml (merge; do not clobber existing keys) ---
if ($Update -or -not ($state.completed -contains 'config')) {
    Write-Info "pinning compat.claude and enabling memory in config.toml"
    $cfgPath = Join-Path $script:GrokHome 'config.toml'
    $existing = ''
    if (Test-Path $cfgPath) { $existing = Get-Content $cfgPath -Raw }

    $block = @"

[memory]
enabled = true

[compat.claude]
skills = true
rules = true
agents = true
mcps = true
hooks = true
"@

    if ($existing -notmatch '(?m)^\[memory\]') {
        Add-Content -Path $cfgPath -Value $block -Encoding utf8
        Write-Ok "appended [memory] + [compat.claude]"
    } elseif ($existing -notmatch '(?m)^\[compat\.claude\]') {
        Add-Content -Path $cfgPath -Value @"

[compat.claude]
skills = true
rules = true
agents = true
mcps = true
hooks = true
"@ -Encoding utf8
        Write-Ok "appended [compat.claude]"
    } else {
        Write-Ok "config.toml already has memory/compat blocks (left untouched)"
    }
    Complete-Stage $state 'config'
}

# --- junction Claude auto-memory ---
if ($Update -or -not ($state.completed -contains 'memory-junction')) {
    $dest = Join-Path $script:GrokHome 'memory\from-claude'
    $src = Join-Path $script:ClaudeHome 'projects'
    New-Item -ItemType Directory -Force $src | Out-Null
    if (Test-Path $dest) {
        Write-Ok "memory junction already present"
    } else {
        New-Item -ItemType Junction -Path $dest -Target $src | Out-Null
        Write-Ok "junction $dest -> $src"
    }
    $pointer = Join-Path $script:GrokHome 'memory\MEMORY.md'
    if (-not (Test-Path $pointer)) {
        $utf8 = New-Object System.Text.UTF8Encoding $false
        $text = @"
# Memory Index

Claude project memory is canonical. This file is a pointer, not a second store.

Write durable memories to ``~/.claude/projects/<encoded-cwd>/memory/`` (or the junction ``from-claude/`` — same files). See ``~/.claude/rules/harness-shared.md``.

cass / ``cm`` remain the procedural and session-history layer.
"@
        [System.IO.File]::WriteAllText($pointer, $text, $utf8)
    }
    Complete-Stage $state 'memory-junction'
}

# --- compact hook calling the SHARED PCR script ---
if ($Update -or -not ($state.completed -contains 'compact-hook')) {
    $pcr = Join-Path $script:ClaudeHome 'hooks\post-compact-reminder.py'
    if (-not (Test-Path $pcr)) {
        Write-Warn2 ('shared PCR missing at ' + $pcr + ' - compact hook will still be written')
    }
    $pcrCmd = 'python "C:\Users\' + $script:WinUser + '\.claude\hooks\post-compact-reminder.py"'
    $hookObj = @{
        hooks = @{
            PreCompact  = @(@{ hooks = @(@{ type = 'command'; command = $pcrCmd; timeout = 10 }) })
            PostCompact = @(@{ hooks = @(@{ type = 'command'; command = $pcrCmd; timeout = 10 }) })
        }
    }
    $hookJson = $hookObj | ConvertTo-Json -Depth 8
    $hookPath = Join-Path $script:GrokHome 'hooks\compact.json'
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($hookPath, $hookJson, $utf8)
    Write-Ok ('wrote ' + $hookPath + ' (UTF-8 no BOM) -> shared PCR')
    Complete-Stage $state 'compact-hook'
}

Write-Ok 'Grok adapter done. Run: grok inspect   and   bash install/smoke-test-grok.sh'
Write-Info 'Do not copy skills or rules into ~/.grok. Edit ~/.claude.'
