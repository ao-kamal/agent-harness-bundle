# claude-harness-bundle - best-effort uninstall / rollback
# Honest scope: this removes what the installer added and restores the backups it made.
# It does NOT try to perfectly rewind your machine. Every destructive step asks first.

$ErrorActionPreference = 'Continue'
function Write-Info { param($m) Write-Host "-> $m" -ForegroundColor Cyan }
function Write-Ok   { param($m) Write-Host "OK $m" -ForegroundColor Green }
function Write-Warn2 { param($m) Write-Host "WARN $m" -ForegroundColor Yellow }
function Confirm-Step { param($q) return ((Read-Host "$q (y/N)") -match '^[Yy]') }

Write-Host "claude-harness-bundle uninstall (best-effort)" -ForegroundColor Yellow
Write-Host ""

# 1. Scheduled task + cass daemon
if (Get-ScheduledTask -TaskName 'Cass Watch Daemon' -ErrorAction SilentlyContinue) {
    if (Confirm-Step "Remove the 'Cass Watch Daemon' scheduled task and stop cass?") {
        Stop-ScheduledTask -TaskName 'Cass Watch Daemon' -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName 'Cass Watch Daemon' -Confirm:$false
        $cass = Get-Process cass -ErrorAction SilentlyContinue
        if ($cass) { Stop-Process -Id $cass.Id }
        Write-Ok "task removed"
    }
}

# 2. Settings restore from installer backups
$claudeDir = Join-Path $env:USERPROFILE '.claude'
foreach ($f in @('settings.json', 'settings.local.json', 'CLAUDE.md')) {
    $bak = Join-Path $claudeDir "$f.bak-harness-bundle"
    if (Test-Path $bak) {
        if (Confirm-Step "Restore pre-install $f from backup?") {
            Copy-Item $bak (Join-Path $claudeDir $f) -Force
            Write-Ok "$f restored"
        }
    }
}

# 3. Skills payload
if (Confirm-Step "Remove the bundled skills from ~\.claude\skills? (your own additions are NOT distinguished - review first!)") {
    Write-Warn2 "Skipping automatic skill deletion by design - too easy to destroy your own work."
    Write-Host "  Delete skill folders by hand from $claudeDir\skills after reviewing them."
}

# 4. Rules files
if (Confirm-Step "Remove ~\.claude\rules\* installed by the bundle?") {
    foreach ($r in @('windows-commands.md','wsl-patterns.md','ntm-swarm.md','tools-reference.md','mcp-and-services.md','context7.md')) {
        Remove-Item (Join-Path $claudeDir "rules\$r") -Force -ErrorAction SilentlyContinue
    }
    Write-Ok "rules removed"
}

# 5. MCP registrations
if (Confirm-Step "Remove the MCP registrations (playwright, mcp-youtube, apify, mcp-agent-mail)?") {
    foreach ($s in @('playwright','mcp-youtube','apify','mcp-agent-mail')) { claude mcp remove $s 2>$null }
    Write-Ok "MCP registrations removed"
}

# 6. Scoop-installed tools
if (Confirm-Step "scoop uninstall the flywheel tools (bv, cm, caam, dcg, slb, wezterm)?") {
    foreach ($p in @('bv','cm','caam','dcg','slb','wezterm')) { scoop uninstall $p 2>$null }
    Write-Ok "scoop tools removed"
}

# 7. .local\bin drops
if (Confirm-Step "Remove the .local\bin binaries the installer placed (cass, br, ms, fmd, branch-back)?") {
    $lb = Join-Path $env:USERPROFILE '.local\bin'
    foreach ($b in @('cass.exe','br.exe','ms.exe','fmd.exe','branch-back','branch-back.cmd','cass-watch-hidden.vbs')) {
        Remove-Item (Join-Path $lb $b) -Force -ErrorAction SilentlyContinue
    }
    Write-Ok ".local\bin cleaned"
}

# 8. WSL - the nuclear option, spelled out
Write-Host ""
Write-Warn2 "WSL: 'wsl --unregister Ubuntu' DESTROYS the entire Linux environment and everything in it."
Write-Warn2 "Only do this if you never used WSL before this bundle and want it fully gone."
$ans = Read-Host "Type DELETE-WSL to unregister the Ubuntu distro (anything else skips)"
if ($ans -ceq 'DELETE-WSL') {
    wsl --unregister Ubuntu
    Write-Ok "Ubuntu distro unregistered"
} else { Write-Info "WSL left in place (individual WSL pieces: see docs/maintenance.md)" }

# 9. State file
Remove-Item (Join-Path $env:USERPROFILE '.harness-bundle-state.json') -Force -ErrorAction SilentlyContinue
Write-Host ""
Write-Ok "uninstall pass complete. Backups with .bak-harness-bundle / .bak.<timestamp> suffixes were left in place deliberately."
