# Antigravity flavor installer (Windows orchestrator)
#
#   Get-ChildItem -Recurse | Unblock-File
#   powershell -ExecutionPolicy Bypass -File install\install-antigravity.ps1
#
# Resumable via %USERPROFILE%\.harness-bundle-antigravity-state.json
# Shared flywheel/WSL stages already completed by another flavor are skipped.
# ntm already has --agy. Gemini CLI --gmi is legacy. This installer does not
# invent an ntm agent type.
# Windows PowerShell 5.1 compatible (no &&, no ternary).

[CmdletBinding()]
param(
    [switch]$SkipWSL,
    [switch]$SkipVault,
    [switch]$SkipFlywheel,
    [switch]$Quiet,
    [switch]$Update
)

$ErrorActionPreference = 'Stop'
$script:BundleRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$script:StateFile = Join-Path $env:USERPROFILE '.harness-bundle-antigravity-state.json'
$script:ClaudeStateFile = Join-Path $env:USERPROFILE '.harness-bundle-state.json'
$script:WinUser = $env:USERNAME

function Write-Info { param($m) if (-not $Quiet) { Write-Host "-> $m" -ForegroundColor Cyan } }
function Write-Ok   { param($m) if (-not $Quiet) { Write-Host "OK $m" -ForegroundColor Green } }
function Write-Warn2 { param($m) Write-Host "WARN $m" -ForegroundColor Yellow }
function Write-Err2  { param($m) Write-Host "ERR $m" -ForegroundColor Red }

function Get-State {
    if (Test-Path $script:StateFile) { return (Get-Content $script:StateFile -Raw | ConvertFrom-Json) }
    return [pscustomobject]@{ completed = @(); vaultPath = '' }
}
function Save-State { param($s) $s | ConvertTo-Json -Depth 4 | Out-File $script:StateFile -Encoding utf8 }
function Test-StageDone { param($s, $name) return ($s.completed -contains $name) }
function Complete-Stage {
    param($s, $name)
    if (-not ($s.completed -contains $name)) { $s.completed = @($s.completed) + $name; Save-State $s }
    Write-Ok "stage complete: $name"
}
function Test-ClaudeStage {
    param($name)
    if (-not (Test-Path $script:ClaudeStateFile)) { return $false }
    $cs = Get-Content $script:ClaudeStateFile -Raw | ConvertFrom-Json
    return ($cs.completed -contains $name)
}

function Convert-Template {
    param($src, $dst)
    $text = (Get-Content $src -Raw) -replace '\{\{WIN_USER\}\}', $script:WinUser -replace '\{\{USER_FULL_NAME\}\}', $script:WinUser
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($dst, $text, $utf8)
}

function Get-AgyExe {
    $p = Join-Path $env:LOCALAPPDATA 'agy\bin\agy.exe'
    if (Test-Path $p) { return $p }
    $cmd = Get-Command agy -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Update-SessionPath {
    $localBin = Join-Path $env:USERPROFILE '.local\bin'
    $shims = Join-Path $env:USERPROFILE 'scoop\shims'
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User') + ';' + $shims + ';' + $localBin
}

function Test-PeExe {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $false }
    $fs = [System.IO.File]::OpenRead($Path)
    try {
        $b0 = $fs.ReadByte(); $b1 = $fs.ReadByte()
        return ($b0 -eq 0x4D -and $b1 -eq 0x5A)
    } finally { $fs.Close() }
}

function Ensure-Scoop {
    Update-SessionPath
    if (Get-Command scoop -ErrorAction SilentlyContinue) { return }
    Write-Info "Installing scoop"
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Invoke-RestMethod get.scoop.sh | Invoke-Expression
    Update-SessionPath
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) { throw "scoop install finished but scoop is not on PATH" }
}

function Ensure-ScoopBucket {
    param([string]$Name, [string]$Repo)
    $dir = Join-Path $env:USERPROFILE "scoop\buckets\$Name"
    if (Test-Path (Join-Path $dir '.git')) { return }
    Write-Info "scoop bucket $Name via gh clone $Repo (git protocol often dies mid-pack on this host)"
    if (Test-Path $dir) {
        scoop bucket rm $Name 2>$null
        if (Test-Path $dir) { Remove-Item $dir -Recurse -Force }
    }
    git config --global http.postBuffer 524288000 | Out-Null
    git config --global http.version HTTP/1.1 | Out-Null
    gh repo clone $Repo $dir -- --depth 1
    if ($Name -eq 'dicklesworthstone') {
        $bucketDir = Join-Path $dir 'bucket'
        New-Item -ItemType Directory -Force $bucketDir | Out-Null
        Copy-Item (Join-Path $dir '*.json') $bucketDir -Force
    }
}

function Install-GhWindowsBinary {
    param([string]$Repo, [string]$Pattern, [string]$DestName)
    $localBin = Join-Path $env:USERPROFILE '.local\bin'
    New-Item -ItemType Directory -Force $localBin | Out-Null
    $dest = Join-Path $localBin $DestName
    if ((Test-Path $dest) -and (Test-PeExe $dest)) {
        $probe = & $dest --version 2>&1
        if ($LASTEXITCODE -eq 0 -or "$probe" -match '\d+\.\d+') {
            Write-Ok "$DestName already a valid Win64 PE at $dest"
            return
        }
        Write-Warn2 "$DestName has an MZ header but will not run (likely a truncated download). Replacing."
        Remove-Item $dest -Force
    }
    $dir = Join-Path $env:TEMP ("hb-gh-" + $DestName)
    if (Test-Path $dir) { Remove-Item $dir -Recurse -Force }
    New-Item -ItemType Directory -Force $dir | Out-Null
    Write-Info "$DestName from $Repo ($Pattern)"
    gh release download --repo $Repo --pattern $Pattern --dir $dir --clobber
    $zip = Get-ChildItem $dir -File -Filter '*.zip' | Select-Object -First 1
    if ($zip) { Expand-Archive $zip.FullName -DestinationPath (Join-Path $dir 'x') -Force }
    $exe = Get-ChildItem $dir -Recurse -File -Filter '*.exe' |
        Where-Object { $_.Name -notmatch 'install' } |
        Sort-Object Length -Descending |
        Select-Object -First 1
    if (-not $exe) { throw "no .exe in $Repo release matching $Pattern" }
    Copy-Item $exe.FullName $dest -Force
    Unblock-File $dest
    if (-not (Test-PeExe $dest)) { throw "$DestName is not a Windows PE executable (wrong asset). Delete $dest and retry." }
    Write-Ok "$DestName -> $dest"
}

function Invoke-GitBash {
    param([string]$ScriptPath, [string]$BashArgs = '')
    $candidates = @(
        'C:\Program Files\Git\bin\bash.exe',
        (Join-Path $env:USERPROFILE 'scoop\apps\git\current\bin\bash.exe')
    )
    $gitBash = $null
    foreach ($c in $candidates) { if (Test-Path $c) { $gitBash = $c; break } }
    if (-not $gitBash) {
        $cmd = Get-Command bash -ErrorAction SilentlyContinue
        if ($cmd -and $cmd.Source -notmatch 'System32') { $gitBash = $cmd.Source }
    }
    if (-not $gitBash) { throw "Git Bash not found. Install Git for Windows." }
    # Send script stdout/stderr to the host so this function's only pipeline
    # output is the exit code. (Bare & bash would leak the smoke-test banner
    # into the caller's $code and make a green run look like a failure.)
    & $gitBash -lc ("bash '" + ($ScriptPath -replace '\\','/' -replace '^C:','/c') + "' " + $BashArgs) | Out-Host
    return $LASTEXITCODE
}

$state = Get-State

if ($Update) {
    Write-Host "-> Update mode: Antigravity config/skills will be re-deployed; flywheel installs stay untouched" -ForegroundColor Cyan
    $state.completed = @($state.completed | Where-Object { @('config-deploy', 'mcp', 'smoke') -notcontains $_ })
    Save-State $state
}

Write-Host ""
Write-Host "==============================================" -ForegroundColor Green
Write-Host " Antigravity harness installer" -ForegroundColor Green
Write-Host " Same flywheel, agy as the Gemini-line CLI. ntm --agy already exists." -ForegroundColor DarkGray
Write-Host "==============================================" -ForegroundColor Green
Write-Host ""

# =================== Stage 0: Preflight ===================
if (-not (Test-StageDone $state 'preflight')) {
    Write-Info "Stage 0: preflight"
    if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') {
        Write-Err2 "ARM64 is not supported (flywheel binaries are x86_64)."
        exit 1
    }
    $build = [System.Environment]::OSVersion.Version.Build
    if ($build -lt 19041) { Write-Err2 "Windows build $build is too old (need 19041+)."; exit 1 }
    $freeGB = [math]::Round((Get-PSDrive C).Free / 1GB, 1)
    if ($freeGB -lt 8) { Write-Warn2 "Only ${freeGB}GB free on C: - Antigravity config will still deploy; flywheel/WSL wants ~15GB." }
    if (-not (Get-AgyExe)) {
        Write-Err2 "agy not found. Install the official Antigravity CLI first, then re-run."
        Write-Host "  Official: irm https://antigravity.google/cli/install.ps1 | iex"
        Write-Host "  Docs: https://antigravity.google/docs/cli/install"
        exit 1
    }
    Write-Ok "preflight passed (agy present, disk ${freeGB}GB free)"
    Complete-Stage $state 'preflight'
}

# =================== Stages 1-2: Flywheel (shared, no Claude login) ===================
# Claude install.ps1 uses scoop + remote install.ps1/install.sh. On this host
# git clones die mid-pack and the dicklesworthstone cm scoop hash is stale.
# Shared flywheel: scoop buckets via `gh repo clone`, Windows PE via `gh release
# download` with exact asset names, MZ-header check before we keep a binary.
if ($SkipFlywheel) {
    Write-Warn2 "Stages 1-2 skipped by flag"
} elseif ((Test-StageDone $state 'cli-tools') -and (Get-Command dcg -ErrorAction SilentlyContinue) -and (Get-Command cass -ErrorAction SilentlyContinue)) {
    Write-Ok "Stages 1-2 already done"
} else {
    Write-Info "Stage 1-2: flywheel CLIs (scoop + gh releases)"
    Ensure-Scoop
    Ensure-ScoopBucket -Name 'main' -Repo 'ScoopInstaller/Main'
    Ensure-ScoopBucket -Name 'extras' -Repo 'ScoopInstaller/Extras'
    Ensure-ScoopBucket -Name 'dicklesworthstone' -Repo 'Dicklesworthstone/scoop-bucket'
    Update-SessionPath

    foreach ($pkg in @('jq', '7zip')) {
        if (-not (Get-Command ($pkg -replace '7zip','7z') -ErrorAction SilentlyContinue)) {
            scoop install $pkg
        }
    }
    $py = Get-Command python -ErrorAction SilentlyContinue
    if (-not $py -or $py.Source -match 'WindowsApps') { scoop install python }

    foreach ($pkg in @('bv', 'caam', 'dcg', 'slb')) {
        if (-not (Get-Command $pkg -ErrorAction SilentlyContinue)) {
            scoop install "dicklesworthstone/$pkg"
        }
    }
    # cm scoop hash is stale (published exe no longer matches the bucket).
    # cass/br official Windows installers exist; we take the release artifacts
    # so we never pipe a remote script.
    Install-GhWindowsBinary -Repo 'Dicklesworthstone/coding_agent_session_search' -Pattern 'cass-windows-amd64.zip' -DestName 'cass.exe'
    Install-GhWindowsBinary -Repo 'Dicklesworthstone/beads_rust' -Pattern 'br-*-windows_amd64.exe' -DestName 'br.exe'
    Install-GhWindowsBinary -Repo 'Dicklesworthstone/cass_memory_system' -Pattern 'cass-memory-windows-x64.exe' -DestName 'cm.exe'
    try { Install-GhWindowsBinary -Repo 'Dicklesworthstone/meta_skill' -Pattern 'ms-*-windows-x86_64.exe' -DestName 'ms.exe' } catch { Write-Warn2 "ms optional: $_" }
    try { Install-GhWindowsBinary -Repo 'Dicklesworthstone/franken_markdown' -Pattern 'fmd-*-x86_64-pc-windows-msvc.exe' -DestName 'fmd.exe' } catch { Write-Warn2 "fmd optional: $_" }
    try { scoop install ffmpeg } catch { Write-Warn2 "ffmpeg optional: $_" }

    $localBin = Join-Path $env:USERPROFILE '.local\bin'
    New-Item -ItemType Directory -Force $localBin | Out-Null
    # Hooks call ~/.local/bin/dcg.exe. Scoop leaves it in shims/apps.
    $dcgApp = Join-Path $env:USERPROFILE 'scoop\apps\dcg\current\dcg.exe'
    if (Test-Path $dcgApp) { Copy-Item $dcgApp (Join-Path $localBin 'dcg.exe') -Force }
    Copy-Item (Join-Path $script:BundleRoot 'payload\bin\branch-back') (Join-Path $localBin 'branch-back') -Force
    Copy-Item (Join-Path $script:BundleRoot 'payload\bin\branch-back.cmd') (Join-Path $localBin 'branch-back.cmd') -Force
    $userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
    if ($userPath -notlike "*$localBin*") {
        [Environment]::SetEnvironmentVariable('PATH', "$userPath;$localBin", 'User')
        Write-Ok "added $localBin to User PATH (new shells only)"
    }
    Update-SessionPath
    Complete-Stage $state 'cli-tools'
}

# =================== Stage 3: Antigravity login ===================
if (-not (Test-StageDone $state 'agy-login')) {
    Write-Info "Stage 3: Antigravity login"
    $agy = Get-AgyExe
    Write-Host ""
    Write-Host "MANUAL STEP: open a NEW terminal, run:  agy" -ForegroundColor Yellow
    Write-Host "Complete the browser / device-code login (or set GEMINI_API_KEY + modelProvider=gemini)." -ForegroundColor Yellow
    Read-Host "Press Enter once you have signed in once"
    Write-Ok "Antigravity CLI present ($agy)"
    Complete-Stage $state 'agy-login'
}

# =================== Stage 4: Config + skills deploy ===================
if (-not (Test-StageDone $state 'config-deploy')) {
    Write-Info "Stage 4: deploying Antigravity skills + config"
    $agyDir = Join-Path $env:USERPROFILE '.gemini\antigravity-cli'
    $pluginDir = Join-Path $agyDir 'plugins\harness-bundle'
    $agentsDir = Join-Path $env:USERPROFILE '.agents'
    New-Item -ItemType Directory -Force @(
        (Join-Path $agyDir 'skills'),
        (Join-Path $agyDir 'rules'),
        $pluginDir,
        (Join-Path $agentsDir 'skills'),
        (Join-Path $agentsDir 'rules')
    ) | Out-Null

    Write-Info "copying skills payload to ~/.gemini/antigravity-cli/skills and ~/.agents/skills"
    Copy-Item (Join-Path $script:BundleRoot 'skills\*') (Join-Path $agyDir 'skills') -Recurse -Force
    Copy-Item (Join-Path $script:BundleRoot 'skills\*') (Join-Path $agentsDir 'skills') -Recurse -Force

    Convert-Template (Join-Path $script:BundleRoot 'config\antigravity\AGENTS.md.template') (Join-Path $agyDir 'AGENTS.md')
    $dstAgentsMd = Join-Path $env:USERPROFILE 'AGENTS.md'
    if (-not (Test-Path $dstAgentsMd)) {
        Convert-Template (Join-Path $script:BundleRoot 'config\antigravity\AGENTS.md.template') $dstAgentsMd
    } else {
        Write-Ok "home AGENTS.md already present (not overwritten)"
    }

    Get-ChildItem (Join-Path $script:BundleRoot 'config\rules') -Filter '*.md' | ForEach-Object {
        Convert-Template $_.FullName (Join-Path $agyDir "rules\$($_.Name)")
        Convert-Template $_.FullName (Join-Path $agentsDir "rules\$($_.Name)")
    }
    Get-ChildItem (Join-Path $script:BundleRoot 'config\antigravity\rules') -Filter '*.md' | ForEach-Object {
        Convert-Template $_.FullName (Join-Path $agyDir "rules\$($_.Name)")
        Convert-Template $_.FullName (Join-Path $agentsDir "rules\$($_.Name)")
    }

    Copy-Item (Join-Path $script:BundleRoot 'config\antigravity\plugin\plugin.json') (Join-Path $pluginDir 'plugin.json') -Force
    Copy-Item (Join-Path $script:BundleRoot 'config\antigravity\plugin\trauma_guard.py') (Join-Path $pluginDir 'trauma_guard.py') -Force
    Copy-Item (Join-Path $script:BundleRoot 'config\antigravity\plugin\post-compact-reminder.py') (Join-Path $pluginDir 'post-compact-reminder.py') -Force
    Convert-Template (Join-Path $script:BundleRoot 'config\antigravity\plugin\hooks.json') (Join-Path $pluginDir 'hooks.json')

    $settings = Join-Path $agyDir 'settings.json'
    if (Test-Path $settings) {
        Copy-Item $settings "$settings.bak-harness-bundle"
        Write-Ok "left existing settings.json (backup next to it)"
    } else {
        Convert-Template (Join-Path $script:BundleRoot 'config\antigravity\settings.json.fragment') $settings
        Write-Ok "wrote settings.json"
    }

    $agyBin = Get-AgyExe
    if ($agyBin) {
        try { & $agyBin plugin install $pluginDir 2>$null | Out-Null } catch { Write-Warn2 "agy plugin install: $_ (plugin files are already on disk)" }
    }

    Complete-Stage $state 'config-deploy'
}

# =================== Stage 5: WSL (same script as Claude flavor; no Claude login) ===================
if ($SkipWSL) {
    Write-Warn2 "Stage 5 skipped by flag"
} elseif ((Test-StageDone $state 'wsl') -or (Test-ClaudeStage 'wsl')) {
    Write-Ok "Stage 5 WSL already done"
    if (-not (Test-StageDone $state 'wsl')) { Complete-Stage $state 'wsl' }
} else {
    Write-Info "Stage 5: WSL + Ubuntu + shared flywheel (ntm, Agent Mail)"
    $wslReady = $false
    try { wsl -l -v 2>$null | Out-Null; if ($LASTEXITCODE -eq 0) { $wslReady = $true } } catch {}
    if (-not $wslReady) {
        Write-Warn2 "WSL not ready. Enable it with: wsl --install -d Ubuntu"
        Write-Host "  Then re-run this installer. Antigravity config already deployed; this stage resumes."
    } else {
        # wsl.exe lists names as UTF-16. PowerShell then sees U\0b\0u\0n\0t\0u\0
        # and -match 'Ubuntu' fails even when Ubuntu is installed.
        $distros = ((wsl -l -q) | ForEach-Object { ($_ -replace "`0",'').Trim() }) -join ' '
        Write-Info "WSL distros: $distros"
        if ($distros -notmatch 'Ubuntu') {
            Write-Warn2 "Ubuntu distro not listed. Install it (wsl --install -d Ubuntu) and re-run."
        } else {
            $wslCfgSrc = Get-Content (Join-Path $script:BundleRoot 'config\wsl\wslconfig.template') -Raw
            $totalGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 0)
            $mem = [math]::Min(8, [math]::Max(4, [math]::Floor($totalGB / 2)))
            $swap = [math]::Max(2, [math]::Floor($mem / 2))
            $wslCfg = $wslCfgSrc -replace '\{\{WSL_MEMORY\}\}', "${mem}GB" -replace '\{\{WSL_SWAP\}\}', "${swap}GB"
            $utf8 = New-Object System.Text.UTF8Encoding $false
            [System.IO.File]::WriteAllText((Join-Path $env:USERPROFILE '.wslconfig'), $wslCfg, $utf8)

            $bundleWslPath = '/mnt/c' + ($script:BundleRoot.Substring(2) -replace '\\','/')
            # Quote BUNDLE_ROOT: this repo often lives under a path with spaces.
            $envText = "WIN_USER=$script:WinUser`nBUNDLE_ROOT=`"$bundleWslPath`"`nKIMI_ENABLED=1`n"
            $utf8 = New-Object System.Text.UTF8Encoding $false
            [System.IO.File]::WriteAllText((Join-Path $script:BundleRoot 'install\wsl-setup.env'), $envText, $utf8)

            Write-Info "Running WSL stage (long)"
            wsl -d Ubuntu -u root -- bash ($bundleWslPath + '/install/wsl-setup.sh')
            if ($LASTEXITCODE -eq 10) { Write-Warn2 "Some WSL tools failed - re-run later to retry them; continuing" }
            elseif ($LASTEXITCODE -ne 0) { Write-Err2 "WSL stage failed (exit $LASTEXITCODE). Fix and re-run."; exit 1 }

            Write-Info "Restarting WSL so the boot hook fires"
            wsl --shutdown
            Start-Sleep -Seconds 3
            wsl -d Ubuntu -u root -- bash -lc 'true'
            Start-Sleep -Seconds 12
            $health = & curl.exe -s --max-time 8 http://127.0.0.1:8765/health
            if ("$health" -match '"status"\s*:\s*"ready"') { Write-Ok "Agent Mail healthy at 127.0.0.1:8765" }
            else { Write-Warn2 "Agent Mail not reachable yet at 127.0.0.1:8765. NEVER probe localhost." }
            Complete-Stage $state 'wsl'
        }
    }
}

# =================== Stage 7: MCP ===================
# Always re-run: Agent Mail is registered only after the WSL stage mints the token.
Write-Info "Stage 7: Antigravity MCP registrations"
powershell -ExecutionPolicy Bypass -File (Join-Path $script:BundleRoot 'install\mcp-register-antigravity.ps1')
if (-not (Test-StageDone $state 'mcp')) { Complete-Stage $state 'mcp' }

# =================== Stage 8: Daemons (if VBS present) ===================
if (-not (Test-StageDone $state 'daemons')) {
    $vbs = Join-Path $env:USERPROFILE '.local\bin\cass-watch-hidden.vbs'
    $srcVbs = Join-Path $script:BundleRoot 'config\windows\cass-watch-hidden.vbs'
    if (Test-Path $srcVbs) {
        New-Item -ItemType Directory -Force (Join-Path $env:USERPROFILE '.local\bin') | Out-Null
        Copy-Item $srcVbs $vbs -Force
        try {
            $action = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument "`"$vbs`""
            $trigger = New-ScheduledTaskTrigger -AtLogOn -User $script:WinUser
            Register-ScheduledTask -TaskName 'Cass Watch Daemon' -Action $action -Trigger $trigger -Force | Out-Null
            Start-ScheduledTask -TaskName 'Cass Watch Daemon' -ErrorAction SilentlyContinue
            Write-Ok "Cass Watch Daemon registered"
        } catch {
            Write-Warn2 "Could not register Cass Watch Daemon ($_). Continue."
        }
    } else {
        Write-Warn2 "cass-watch-hidden.vbs not in bundle; daemon skipped"
    }
    Complete-Stage $state 'daemons'
}

# =================== Stage 10: Vault (optional) ===================
if ($SkipVault) { Write-Warn2 "Stage 10 skipped by flag" }
elseif (-not (Test-StageDone $state 'vault')) {
    Write-Info "Stage 10: Obsidian vault starter (optional)"
    $ans = 'N'
    if (-not $Quiet) { $ans = Read-Host "Set up the PKM vault starter? (y/N)" }
    if ($ans -match '^[Yy]') {
        $vaultDefault = Join-Path $env:USERPROFILE 'Vaults\MyVault'
        $vp = $vaultDefault
        if (-not $Quiet) {
            $typed = Read-Host "Vault path [$vaultDefault]"
            if (-not [string]::IsNullOrWhiteSpace($typed)) { $vp = $typed }
        }
        New-Item -ItemType Directory -Force $vp | Out-Null
        Copy-Item (Join-Path $script:BundleRoot 'vault-starter\*') $vp -Recurse -Force
        $state.vaultPath = $vp; Save-State $state
        Write-Ok "vault starter at $vp"
    }
    Complete-Stage $state 'vault'
}

# =================== Stage 11: Smoke test ===================
if (-not (Test-StageDone $state 'smoke')) {
    Write-Info "Stage 11: Antigravity smoke test"
    $code = Invoke-GitBash -ScriptPath (Join-Path $script:BundleRoot 'install\smoke-test-antigravity.sh')
    if ($code -eq 0) { Write-Ok "smoke test green"; Complete-Stage $state 'smoke' }
    else { Write-Warn2 "smoke test reported failures (exit $code). Fix and re-run install-antigravity.ps1 -Update" }
}

Write-Host ""
Write-Host "==============================================" -ForegroundColor Green
Write-Host " Antigravity install complete" -ForegroundColor Green
Write-Host "==============================================" -ForegroundColor Green
Write-Host " Completed stages: $($state.completed -join ', ')"
Write-Host ""
Write-Host " Next steps:"
Write-Host "   1. Open a NEW terminal"
Write-Host "   2. agy              (finish login if needed)"
Write-Host "   3. agy plugin list  (expect harness-bundle)"
Write-Host "   4. Read docs/field-guide/01-philosophy.md then 08-antigravity-flavor.md"
Write-Host "   5. Swarm panes: ntm spawn <project> --agy=N  (already in official ntm)"
Write-Host "   6. WSL: install official agy so ntm --agy can find it"
Write-Host ""
