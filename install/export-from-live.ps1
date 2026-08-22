# export-from-live.ps1 - THE sanctioned sync path: live ~/.claude -> bundle.
#
# Live ~/.claude is canonical. Manual copying into the bundle is forbidden;
# run this instead. It refuses to run on a dirty working tree, copies rules +
# hooks + skills from live into the bundle, and regenerates install/manifest.sha256
# (the same manifest format check-drift.ps1 and the installer's deployed-hashes use).
#
# Usage:
#   powershell -File install\export-from-live.ps1              # full export
#   powershell -File install\export-from-live.ps1 -ManifestOnly # just regenerate the manifest

param([switch]$ManifestOnly, [switch]$WhatIf)

$ErrorActionPreference = 'Stop'
$BundleRoot = Split-Path -Parent $PSScriptRoot
$ClaudeDir = Join-Path $env:USERPROFILE '.claude'

# Refuse on dirty tree (export commits should be reviewable units)
$gitStatus = & git -C $BundleRoot status --porcelain
if (-not $ManifestOnly -and $gitStatus) {
    Write-Host "Working tree is dirty - commit or stash first:" -ForegroundColor Red
    $gitStatus | Select-Object -First 10 | ForEach-Object { Write-Host "  $_" }
    exit 1
}

function Get-Sha256 { param($path) (Get-FileHash $path -Algorithm SHA256).Hash.ToLower() }

# 1. copy rules + hooks (templates rendered separately; raw config files copy verbatim)
if (-not $ManifestOnly) {
    foreach ($sub in @('rules', 'hooks')) {
        $src = Join-Path $ClaudeDir $sub
        if (-not (Test-Path $src)) { continue }
        New-Item -ItemType Directory -Force (Join-Path $BundleRoot "config\$sub") | Out-Null
        Get-ChildItem $src -Filter '*.md' | ForEach-Object {
            Copy-Item $_.FullName (Join-Path $BundleRoot "config\$sub\$($_.Name)") -Force
            Write-Host "  config/$sub/$($_.Name)"
        }
        if ($sub -eq 'hooks') {
            Get-ChildItem $src -Filter '*.py' | ForEach-Object {
                Copy-Item $_.FullName (Join-Path $BundleRoot "config\hooks\$($_.Name)") -Force
                Write-Host "  config/hooks/$($_.Name)"
            }
        }
    }

    # 2. skills: bundle-tracked dirs only (don't adopt one-off live experiments)
    $manifestPath = Join-Path $PSScriptRoot 'manifest.sha256'
    $trackedRoots = @()
    if (Test-Path $manifestPath) {
        foreach ($line in Get-Content $manifestPath) {
            if ($line -match '^[a-f0-9]{64}\s+\*?skills/([^/]+)/') { $trackedRoots += $Matches[1] }
        }
    }
    $trackedRoots = $trackedRoots | Sort-Object -Unique
    $liveSkills = Join-Path $ClaudeDir 'skills'
    foreach ($skill in $trackedRoots) {
        $src = Join-Path $liveSkills $skill
        $dst = Join-Path $BundleRoot "skills\$skill"
        if (-not (Test-Path $src)) { Write-Host "  (live missing: skills/$skill - skipped)" -ForegroundColor DarkGray; continue }
        if ($WhatIf) { Write-Host "  would sync skills/$skill"; continue }
        if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
        Copy-Item $src $dst -Recurse -Force
        Write-Host "  skills/$skill"
    }
}

# 3. regenerate the manifest over config/ + skills/
$manifestPath = Join-Path $PSScriptRoot 'manifest.sha256'
$lines = @()
$rootsToHash = @('config\rules', 'config\hooks', 'skills')
foreach ($root in $rootsToHash) {
    $full = Join-Path $BundleRoot $root
    if (-not (Test-Path $full)) { continue }
    Get-ChildItem $full -Recurse -File | Where-Object { $_.FullName -notmatch '\\_quarantined\\|\.bak' } | ForEach-Object {
        $rel = $_.FullName.Substring($BundleRoot.Length + 1) -replace '\\', '/'
        $lines += "$(Get-Sha256 $_.FullName)  $rel"
    }
}
$lines = $lines | Sort-Object
if ($WhatIf) { Write-Host "would write $($lines.Count) manifest entries" }
else {
    Set-Content -Path $manifestPath -Value $lines -Encoding ascii
    Write-Host "manifest regenerated: $($lines.Count) entries -> install/manifest.sha256" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next: commit the changed files (this export is a reviewable unit)." -ForegroundColor Cyan
}
