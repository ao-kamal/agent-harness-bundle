# claude-harness-bundle - best-effort uninstall / rollback
# Honest scope: this removes what the installer added and restores the backups it made.
# It does NOT try to perfectly rewind your machine. Every destructive step asks first.

$ErrorActionPreference = 'Continue'
function Write-Info { param($m) Write-Host "-> $m" -ForegroundColor Cyan }
function Write-Ok   { param($m) Write-Host "OK $m" -ForegroundColor Green }
function Write-Warn2 { param($m) Write-Host "WARN $m" -ForegroundColor Yellow }
function Confirm-Step { param($q) return ((Read-Host "$q (y/N)") -match '^[Yy]') }

Write-Host "agent-harness-bundle uninstall (best-effort)" -ForegroundColor Yellow
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

# 1b. Hermes adapter rollback
$hermesHomeDir = $env:HERMES_HOME
if ([string]::IsNullOrWhiteSpace($hermesHomeDir)) { $hermesHomeDir = Join-Path $env:LOCALAPPDATA 'hermes' }
$hermesConfig = Join-Path $hermesHomeDir 'config.yaml'
if ((Get-Command hermes -ErrorAction SilentlyContinue) -and (Test-Path $hermesConfig)) {
    if (Confirm-Step "Remove the harness-bundle keys from Hermes config.yaml (skills.external_dirs, nudge/curator/clarify)?") {
        $bak = "$hermesConfig.bak-harness-bundle"
        if (Test-Path $bak) {
            Copy-Item $bak $hermesConfig -Force
            Write-Ok "restored config.yaml from backup"
        } else {
            Write-Warn2 "no backup found at $bak - remove these keys manually: skills.external_dirs, skills.creation_nudge_interval, curator.enabled, agent.clarify_timeout, mcp_servers.mcp-agent-mail"
        }
    }
    $soul = Join-Path $hermesHomeDir 'SOUL.md'
    if ((Test-Path $soul) -and (Select-String -Path $soul -Pattern 'BEGIN harness-bundle operating rules' -Quiet)) {
        if (Confirm-Step "Strip the operating-rules block from Hermes SOUL.md?") {
            $text = Get-Content $soul -Raw
            $cleaned = $text -replace '(?s)\r?\n<!-- BEGIN harness-bundle operating rules -->.*?<!-- END harness-bundle operating rules -->\r?\n?', "`n"
            Set-Content -Path $soul -Value $cleaned -Encoding utf8
            Write-Ok "SOUL.md block removed"
        }
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
    foreach ($r in @('windows-commands.md','wsl-patterns.md','ntm-swarm.md','tools-reference.md','mcp-and-services.md','developer-index.md','harness-shared.md')) {
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

# 9. State files, RunOnce resume entry, Grok/Antigravity adapter state
Remove-Item (Join-Path $env:USERPROFILE '.harness-bundle-state.json') -Force -ErrorAction SilentlyContinue
if (Confirm-Step "Remove the RunOnce auto-resume entry (HarnessBundleResume)?") {
    Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce' -Name 'HarnessBundleResume' -ErrorAction SilentlyContinue
    Write-Ok "RunOnce entry removed"
}
if (Test-Path (Join-Path $env:USERPROFILE '.grok\memory\from-claude')) {
    if (Confirm-Step "Remove the Grok memory junction (~\.grok\memory\from-claude)?") {
        # junctions must be removed with cmd/rmdir, not Remove-Item -Recurse (which follows the link)
        cmd /c rmdir (Join-Path $env:USERPROFILE '.grok\memory\from-claude') 2>$null
        Write-Ok "Grok memory junction removed"
    }
}
$vbs = Join-Path ([System.Environment]::GetFolderPath('Startup')) 'opencode-proxy.vbs'
if (Test-Path $vbs) {
    if (Confirm-Step "Remove OpenCode Zen proxy from Startup and stop background proxy?") {
        Remove-Item $vbs -Force -ErrorAction SilentlyContinue
        Get-NetTCPConnection -LocalPort 5210 -ErrorAction SilentlyContinue | ForEach-Object {
            Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue
        }
        Write-Ok "OpenCode Zen proxy startup launcher removed and process stopped"
    }
}
foreach ($stateFile in @('.grok-state', 'antigravity-state')) { }  # flavor installers keep their own markers; see flavors/*/SETUP.md
Write-Host ""
Write-Ok "uninstall pass complete. Backups with .bak-harness-bundle / .bak.<timestamp> suffixes were left in place deliberately."
