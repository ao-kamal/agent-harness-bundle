# check-drift.ps1 - compare live ~/.claude against the bundle's committed SHA256 manifest.
#
# Live ~/.claude is the canonical source of truth; this repo (the bundle) is its
# export/sharing snapshot. This script makes drift VISIBLE so a human can decide:
#   live-ahead  -> run export-from-live.ps1 to update the bundle
#   bundle-ahead-> run install.ps1 -Update to deploy to live
#
# Usage: powershell -ExecutionPolicy Bypass -File install\check-drift.ps1 [-Quiet]
# Exit codes: 0 = no drift, 1 = drift found, 2 = manifest missing (run export-from-live.ps1 first)

param([switch]$Quiet)

$ErrorActionPreference = 'Stop'
$BundleRoot = Split-Path -Parent $PSScriptRoot
$ClaudeDir = Join-Path $env:USERPROFILE '.claude'
$ManifestPath = Join-Path $PSScriptRoot 'manifest.sha256'

function Get-RelSha256 { param($root, $rel)
    $p = Join-Path $root ($rel -replace '/', '\')
    if (-not (Test-Path $p)) { return $null }
    (Get-FileHash $p -Algorithm SHA256).Hash.ToLower()
}

if (-not (Test-Path $ManifestPath)) {
    Write-Host "No manifest at install/manifest.sha256." -ForegroundColor Yellow
    Write-Host "Generate one with: powershell -File install\export-from-live.ps1 -ManifestOnly" -ForegroundColor Yellow
    exit 2
}

# Load manifest: lines of "<sha256>  <relative/path>"
$entries = @{}
foreach ($line in Get-Content $ManifestPath) {
    if ($line -match '^([a-f0-9]{64})\s+\*?(.+)$') { $entries[$Matches[2] -replace '\\','/'] = $Matches[1] }
}

$liveAhead = @()   # live differs from manifest -> bundle is stale
$bundleAhead = @() # manifest file missing in live -> never deployed or deleted
$inLiveOnly = @()  # in live skills but not tracked by the manifest

foreach ($rel in $entries.Keys) {
    $liveHash = Get-RelSha256 $ClaudeDir $rel
    if ($null -eq $liveHash) { $bundleAhead += $rel }
    elseif ($liveHash -ne $entries[$rel]) { $liveAhead += $rel }
}
# untracked live files (skills only - rules/hooks are fully tracked)
$liveSkills = Join-Path $ClaudeDir 'skills'
if (Test-Path $liveSkills) {
    foreach ($dir in Get-ChildItem $liveSkills -Directory) {
        $tracked = $entries.Keys | Where-Object { $_ -like "skills/$($dir.Name)/*" }
        if (-not $tracked) { $inLiveOnly += "skills/$($dir.Name)/" }
    }
}

if (-not $Quiet) {
    if ($liveAhead.Count) {
        Write-Host ""
        Write-Host "LIVE IS AHEAD (live edits not yet exported to the bundle): $($liveAhead.Count)" -ForegroundColor Yellow
        $liveAhead | ForEach-Object { Write-Host "  $_" }
    }
    if ($bundleAhead.Count) {
        Write-Host ""
        Write-Host "BUNDLE IS AHEAD (deployed files missing/changed in live): $($bundleAhead.Count)" -ForegroundColor Cyan
        $bundleAhead | ForEach-Object { Write-Host "  $_" }
    }
    if ($inLiveOnly.Count) {
        Write-Host ""
        Write-Host "UNTRACKED LIVE SKILLS (installed outside the bundle, e.g. via npx): $($inLiveOnly.Count)" -ForegroundColor DarkGray
        $inLiveOnly | ForEach-Object { Write-Host "  $_" }
    }
}

$total = $liveAhead.Count + $bundleAhead.Count + $inLiveOnly.Count
Write-Host ""
if ($total -eq 0) { Write-Host "No drift. Bundle and live agree." -ForegroundColor Green; exit 0 }
Write-Host "Drift: $total item(s) ($($liveAhead.Count) live-ahead, $($bundleAhead.Count) bundle-ahead, $($inLiveOnly.Count) untracked)"
exit 1
