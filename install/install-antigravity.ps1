# Thin Antigravity adapter. Does NOT copy the brain.
#
#   powershell -ExecutionPolicy Bypass -File install\install-antigravity.ps1
#
# Assumes install.ps1 already deployed ~/.claude (skills, rules, hooks).
# Antigravity CLI does not have Grok's compat.claude flag. The smallest
# adapter is a junction: ~/.gemini/antigravity-cli/skills -> ~/.claude/skills
# and ~/.gemini/antigravity-cli/rules -> ~/.claude/rules.
# ntm already launches panes with --agy. This script does not invent an ntm type.

[CmdletBinding()]
param(
    [switch]$Quiet,
    [switch]$Update
)

$ErrorActionPreference = 'Stop'
$script:ClaudeHome = Join-Path $env:USERPROFILE '.claude'
$script:AgyHome = Join-Path $env:USERPROFILE '.gemini\antigravity-cli'
$script:StateFile = Join-Path $env:USERPROFILE '.harness-bundle-antigravity-state.json'

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

function Get-AgyExe {
    $p = Join-Path $env:LOCALAPPDATA 'agy\bin\agy.exe'
    if (Test-Path $p) { return $p }
    $cmd = Get-Command agy -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Set-Junction {
    param([string]$Link, [string]$Target, [switch]$Optional)
    if (-not (Test-Path $Target)) {
        if ($Optional) {
            Write-Warn2 "skip junction $Link - target missing: $Target"
            return
        }
        throw "shared brain missing at $Target"
    }
    if (Test-Path $Link) {
        $item = Get-Item $Link -Force
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            Write-Ok "junction already present: $Link"
            return
        }
        Write-Warn2 "$Link exists and is not a junction. Not overwriting. Move it aside and re-run."
        return
    }
    $parent = Split-Path $Link
    New-Item -ItemType Directory -Force $parent | Out-Null
    New-Item -ItemType Junction -Path $Link -Target $Target | Out-Null
    Write-Ok "junction $Link -> $Target"
}

if (-not (Test-Path (Join-Path $script:ClaudeHome 'skills'))) {
    throw "Shared brain missing at $($script:ClaudeHome)\skills. Run install\install.ps1 first."
}

$agy = Get-AgyExe
if (-not $agy) {
    Write-Warn2 "agy not on PATH. Official install: irm https://antigravity.google/cli/install.ps1 | iex"
}

$state = Get-State
New-Item -ItemType Directory -Force $script:AgyHome | Out-Null

if ($Update -or -not ($state.completed -contains 'junctions')) {
    Write-Info "junction Antigravity skill/rule dirs onto ~/.claude (no copy)"
    Set-Junction -Link (Join-Path $script:AgyHome 'skills') -Target (Join-Path $script:ClaudeHome 'skills')
    Set-Junction -Link (Join-Path $script:AgyHome 'rules') -Target (Join-Path $script:ClaudeHome 'rules') -Optional
    Set-Junction -Link (Join-Path $script:AgyHome 'agents') -Target (Join-Path $script:ClaudeHome 'agents') -Optional
    Complete-Stage $state 'junctions'
}

Write-Ok "Antigravity adapter done. Sit in agy. Edit ~/.claude only."
Write-Info "ntm panes: ntm spawn <project> --agy=N  (already in official ntm)"
Write-Info "Do not copy skills into ~/.gemini. Re-run this script if a junction is missing."
