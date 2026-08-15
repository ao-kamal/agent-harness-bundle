# agent-harness-bundle installer (Windows orchestrator)
#
# FIRST LAUNCH (Windows blocks unsigned local scripts by default):
#   1. Open PowerShell in the cloned bundle folder
#   2. Get-ChildItem -Recurse | Unblock-File
#   3. powershell -ExecutionPolicy Bypass -File install\install.ps1
#
# Resumable: completed stages are recorded in %USERPROFILE%\.harness-bundle-state.json
# and skipped on re-run. If Windows reboots mid-install (WSL enablement), the
# installer registers a RunOnce entry and continues automatically after logon.
#
# Windows PowerShell 5.1 compatible (no &&, no ternary).

[CmdletBinding()]
param(
    [switch]$SkipWSL,
    [switch]$SkipVault,
    [switch]$Quiet,
    [switch]$Update   # after git pull: re-deploys skills/config (Win + WSL) without redoing installs
)

$ErrorActionPreference = 'Stop'
$script:BundleRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$script:StateFile = Join-Path $env:USERPROFILE '.harness-bundle-state.json'
$script:WinUser = $env:USERNAME

# ---------- output ----------
function Write-Info { param($m) if (-not $Quiet) { Write-Host "-> $m" -ForegroundColor Cyan } }
function Write-Ok   { param($m) if (-not $Quiet) { Write-Host "OK $m" -ForegroundColor Green } }
function Write-Warn2 { param($m) Write-Host "WARN $m" -ForegroundColor Yellow }
function Write-Err2  { param($m) Write-Host "ERR $m" -ForegroundColor Red }

# ---------- state ----------
function Get-State {
    if (Test-Path $script:StateFile) { return (Get-Content $script:StateFile -Raw | ConvertFrom-Json) }
    return [pscustomobject]@{ completed = @(); wslMemoryGB = 0; wslSwapGB = 0; vaultPath = ''; oneDriveDocs = $false }
}
function Save-State { param($s) $s | ConvertTo-Json -Depth 4 | Out-File $script:StateFile -Encoding utf8 }
function Test-StageDone { param($s, $name) return ($s.completed -contains $name) }
function Complete-Stage {
    param($s, $name)
    if (-not ($s.completed -contains $name)) { $s.completed = @($s.completed) + $name; Save-State $s }
    Write-Ok "stage complete: $name"
}
$state = Get-State

function Update-SessionPath {
    # A child installer process cannot mutate this session's PATH; re-read it from the registry.
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
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
    if (-not $gitBash) { throw "Git Bash not found (checked Program Files, scoop, PATH). Install Git for Windows - see SETUP.md Step 1." }
    & $gitBash -lc ("bash '" + ($ScriptPath -replace '\\','/' -replace '^C:','/c') + "' " + $BashArgs)
    return $LASTEXITCODE
}

if ($Update) {
    Write-Host "-> Update mode: config/skills will be re-deployed (Win + WSL); installs stay untouched" -ForegroundColor Cyan
    $state.completed = @($state.completed | Where-Object { $_ -ne 'config-deploy' })
    Save-State $state
}

Write-Host ""
Write-Host "==============================================" -ForegroundColor Green
Write-Host " claude-harness-bundle installer" -ForegroundColor Green
Write-Host " A Claude Code harness, packaged" -ForegroundColor DarkGray
Write-Host "==============================================" -ForegroundColor Green
Write-Host ""

# =================== Stage 0: Preflight ===================
if (-not (Test-StageDone $state 'preflight')) {
    Write-Info "Stage 0: preflight"

    if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') {
        Write-Err2 "This machine is ARM64. The toolchain in this bundle ships x86_64-only binaries (cass, br, bv, dcg, caam, slb, fmd...). Install cannot proceed on ARM64 Windows."
        exit 1
    }
    $build = [System.Environment]::OSVersion.Version.Build
    if ($build -lt 19041) { Write-Err2 "Windows build $build is too old for WSL2 (need 19041+)."; exit 1 }

    $freeGB = [math]::Round((Get-PSDrive C).Free / 1GB, 1)
    if ($freeGB -lt 15) { Write-Err2 "Only ${freeGB}GB free on C: - need at least 15GB."; exit 1 }

    # Developer Mode / symlink privilege probe (npx impeccable scaffolds real symlinks)
    $probeLink = Join-Path $env:TEMP "hb-symlink-probe"
    $probeTarget = Join-Path $env:TEMP "hb-symlink-target.txt"
    "probe" | Out-File $probeTarget -Encoding ascii
    try {
        if (Test-Path $probeLink) { Remove-Item $probeLink -Force }
        New-Item -ItemType SymbolicLink -Path $probeLink -Target $probeTarget -ErrorAction Stop | Out-Null
        Remove-Item $probeLink -Force
        Write-Ok "symlink creation works"
    } catch {
        Write-Err2 "Cannot create symlinks. Enable Windows Developer Mode first:"
        Write-Host "  Settings > System > For developers > Developer Mode = On   (or run: start ms-settings:developers)"
        Write-Host "  Then re-run this installer. (Needed by the impeccable skill family.)"
        exit 1
    }

    # OneDrive Known Folder Move detection
    $docs = [Environment]::GetFolderPath('MyDocuments')
    if ($docs -match 'OneDrive') {
        $state.oneDriveDocs = $true
        Write-Warn2 "Your Documents folder is OneDrive-synced. Actively-written data (Obsidian vault, git repos) does not belong in a cloud-synced folder - the vault stage will default to C:\Users\$script:WinUser\Vaults instead."
    }

    # WSL memory sizing: half of RAM, capped at 8GB
    $totalGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 0)
    $state.wslMemoryGB = [math]::Min(8, [math]::Max(4, [math]::Floor($totalGB / 2)))
    $state.wslSwapGB = [math]::Max(2, [math]::Floor($state.wslMemoryGB / 2))
    Write-Ok "preflight passed (RAM ${totalGB}GB -> WSL $($state.wslMemoryGB)GB; disk ${freeGB}GB free)"
    Complete-Stage $state 'preflight'
}

# =================== Stage 1: Package managers ===================
if (-not (Test-StageDone $state 'package-managers')) {
    Write-Info "Stage 1: package managers (scoop, git, node, python, gh)"
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Info "Installing scoop"
        Invoke-RestMethod get.scoop.sh | Invoke-Expression
    }
    scoop bucket add main 2>$null | Out-Null
    scoop bucket add extras 2>$null | Out-Null
    scoop bucket add dicklesworthstone https://github.com/Dicklesworthstone/scoop-bucket 2>$null | Out-Null
    foreach ($pkg in @('git', 'gh', 'nodejs-lts', 'python', 'jq', '7zip')) {
        if (-not (Get-Command ($pkg -replace 'nodejs-lts','node') -ErrorAction SilentlyContinue)) {
            scoop install $pkg
        }
    }
    Write-Warn2 "Note: unauthenticated GitHub downloads are rate-limited (60/hr). If later stages hit rate limits, run: gh auth login"
    Complete-Stage $state 'package-managers'
}

# =================== Stage 2: CLI tools ===================
if (-not (Test-StageDone $state 'cli-tools')) {
    Write-Info "Stage 2: Windows CLI tools"
    $localBin = Join-Path $env:USERPROFILE '.local\bin'
    New-Item -ItemType Directory -Force $localBin | Out-Null

    foreach ($pkg in @('bv', 'cm', 'caam', 'dcg', 'slb')) {
        scoop install "dicklesworthstone/$pkg" 2>$null
    }
    scoop install ffmpeg 2>$null

    # cass: official install.ps1 (scoop manifest historically unreliable for cass)
    Write-Info "cass via official install.ps1"
    $cassPs1 = Join-Path $env:TEMP 'cass-install.ps1'
    Invoke-WebRequest 'https://raw.githubusercontent.com/Dicklesworthstone/coding_agent_session_search/main/install.ps1' -OutFile $cassPs1
    Unblock-File $cassPs1
    powershell -ExecutionPolicy Bypass -File $cassPs1 -EasyMode -Verify

    # br: its install.sh works natively on Windows via Git Bash
    Write-Info "br via install.sh (Git Bash)"
    $brSh = Join-Path $env:TEMP 'br-install.sh'
    Invoke-WebRequest 'https://raw.githubusercontent.com/Dicklesworthstone/beads_rust/main/install.sh' -OutFile $brSh
    Invoke-GitBash -ScriptPath $brSh | Out-Null

    # ms: release zip (upstream's own installers are broken for Windows)
    if (-not (Get-Command ms -ErrorAction SilentlyContinue)) {
        Write-Info "ms via release zip + SHA256SUMS"
        Import-Module BitsTransfer
        $msDir = Join-Path $env:TEMP 'ms-hb'
        New-Item -ItemType Directory -Force $msDir | Out-Null
        Start-BitsTransfer -Source 'https://github.com/Dicklesworthstone/meta_skill/releases/latest/download/SHA256SUMS' -Destination "$msDir\SHA256SUMS" -RetryInterval 60 -RetryTimeout 600
        $msAsset = (Get-Content "$msDir\SHA256SUMS" | Select-String 'x86_64-pc-windows-msvc.zip').Line
        $msName = ($msAsset -split '\s+')[1] -replace '^\*',''
        $msHash = ($msAsset -split '\s+')[0]
        Start-BitsTransfer -Source "https://github.com/Dicklesworthstone/meta_skill/releases/latest/download/$msName" -Destination "$msDir\ms.zip" -RetryInterval 60 -RetryTimeout 600
        $actual = (Get-FileHash "$msDir\ms.zip" -Algorithm SHA256).Hash.ToLower()
        if ($actual -ne $msHash.ToLower()) { throw "ms.zip hash mismatch - aborting this tool" }
        Expand-Archive "$msDir\ms.zip" -DestinationPath "$msDir\x" -Force
        $msExe = Get-ChildItem "$msDir\x" -Recurse -Filter ms.exe | Select-Object -First 1
        Copy-Item $msExe.FullName (Join-Path $localBin 'ms.exe') -Force
        Unblock-File (Join-Path $localBin 'ms.exe')
    }

    # fmd: release zip via BITS (official installer known-broken)
    if (-not (Get-Command fmd -ErrorAction SilentlyContinue)) {
        Write-Info "fmd via gh release + BITS"
        try {
            $tag = (Invoke-RestMethod 'https://api.github.com/repos/Dicklesworthstone/franken_markdown/releases/latest').tag_name
            gh release download $tag --repo Dicklesworthstone/franken_markdown --pattern 'fmd-v*-x86_64-pc-windows-msvc.zip*' --dir (Join-Path $env:TEMP 'fmd-hb') --clobber
            $fmdZip = Get-ChildItem (Join-Path $env:TEMP 'fmd-hb') -Filter '*.zip' | Select-Object -First 1
            $fmdSha = Get-ChildItem (Join-Path $env:TEMP 'fmd-hb') -Filter '*.sha256' | Select-Object -First 1
            $expected = ((Get-Content $fmdSha.FullName -Raw).Trim() -split '\s+')[0].ToLower()
            $actual = (Get-FileHash $fmdZip.FullName -Algorithm SHA256).Hash.ToLower()
            if ($actual -ne $expected) { throw "fmd hash mismatch" }
            Expand-Archive $fmdZip.FullName -DestinationPath (Join-Path $env:TEMP 'fmd-hb\x') -Force
            $fmdExe = Get-ChildItem (Join-Path $env:TEMP 'fmd-hb\x') -Recurse -Filter fmd.exe | Select-Object -First 1
            Copy-Item $fmdExe.FullName (Join-Path $localBin 'fmd.exe') -Force
            Unblock-File (Join-Path $localBin 'fmd.exe')
        } catch { Write-Warn2 "fmd install failed ($_) - optional tool, continue; retry later" }
    }

    # branch-back: bespoke script, ships in the bundle payload
    Copy-Item (Join-Path $script:BundleRoot 'payload\bin\branch-back') (Join-Path $localBin 'branch-back') -Force
    Copy-Item (Join-Path $script:BundleRoot 'payload\bin\branch-back.cmd') (Join-Path $localBin 'branch-back.cmd') -Force

    # npm globals + pip
    foreach ($npmPkg in @('ctx7', 'defuddle', 'dev-browser', 'firecrawl-cli')) { npm install -g $npmPkg --silent }
    pip install --quiet yt-dlp uv firecrawl-py

    # Ensure ~\.local\bin on User PATH
    $userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
    if ($userPath -notlike "*$localBin*") {
        [Environment]::SetEnvironmentVariable('PATH', "$userPath;$localBin", 'User')
        Write-Ok "added $localBin to User PATH (new shells only)"
    }
    Complete-Stage $state 'cli-tools'
}

# =================== Stage 3a: Claude Code + login (MANUAL GATE) ===================
if (-not (Test-StageDone $state 'claude-login')) {
    Write-Info "Stage 3a: Claude Code + login"
    if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
        Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression
        Update-SessionPath
        if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
            Write-Err2 "claude still not on PATH after install. Open a NEW terminal, verify 'claude --version' works, then re-run this installer (it resumes here)."
            exit 1
        }
    }
    $creds = Join-Path $env:USERPROFILE '.claude\.credentials.json'
    if (-not (Test-Path $creds)) {
        Write-Host ""
        Write-Host "MANUAL STEP: open a NEW terminal, run:  claude" -ForegroundColor Yellow
        Write-Host "Complete the browser login, then exit Claude Code and press Enter here." -ForegroundColor Yellow
        Read-Host "Press Enter once login is complete"
        if (-not (Test-Path $creds)) { Write-Err2 "Still no credentials file - login did not complete. Re-run the installer."; exit 1 }
    }
    Write-Ok "Claude Code authenticated"
    Complete-Stage $state 'claude-login'
}

# =================== Stage 3b: Plugins + canonical skills ===================
if (-not (Test-StageDone $state 'plugins')) {
    Write-Info "Stage 3b: plugins + canonical skill installs"
    Update-SessionPath
    claude plugin marketplace add anthropics/claude-code 2>$null
    claude plugin marketplace add anthropics/skills 2>$null
    claude plugin marketplace add anthropics/claude-plugins-official 2>$null
    claude plugin install frontend-design@claude-code-plugins 2>$null
    claude plugin install document-skills@anthropic-agent-skills 2>$null
    claude plugin install vercel@claude-plugins-official 2>$null

    Write-Info "impeccable skill family via npx (canonical)"
    npx --yes impeccable skills install -y --providers=claude 2>$null

    $exSkill = Join-Path $env:USERPROFILE '.claude\skills\excalidraw-diagram'
    if (-not (Test-Path $exSkill)) {
        git clone --depth 1 https://github.com/coleam00/excalidraw-diagram-skill.git $exSkill
    }
    Complete-Stage $state 'plugins'
}

# =================== Stage 4: Config + skills deploy ===================
# NOTE: this stage ALWAYS runs on -Update (the update path re-copies skills and
# re-renders templates); on a plain re-run it is skipped like any other stage.
if (-not (Test-StageDone $state 'config-deploy')) {
    Write-Info "Stage 4: deploying skills + config"
    $claudeDir = Join-Path $env:USERPROFILE '.claude'
    New-Item -ItemType Directory -Force (Join-Path $claudeDir 'skills'), (Join-Path $claudeDir 'rules'), (Join-Path $claudeDir 'hooks'), (Join-Path $claudeDir 'agents') | Out-Null

    Copy-Item (Join-Path $script:BundleRoot 'skills\*') (Join-Path $claudeDir 'skills') -Recurse -Force

    # Render CLAUDE.md + rules ({{WIN_USER}} substitution); never clobber an existing CLAUDE.md
    function Convert-Template { param($src, $dst)
        (Get-Content $src -Raw) -replace '\{\{WIN_USER\}\}', $script:WinUser -replace '\{\{USER_FULL_NAME\}\}', $script:WinUser | Out-File $dst -Encoding utf8
    }
    $dstClaudeMd = Join-Path $claudeDir 'CLAUDE.md'
    if (Test-Path $dstClaudeMd) { Copy-Item $dstClaudeMd "$dstClaudeMd.bak-harness-bundle" }
    Convert-Template (Join-Path $script:BundleRoot 'config\CLAUDE.md.template') $dstClaudeMd
    Get-ChildItem (Join-Path $script:BundleRoot 'config\rules') -Filter '*.md' | ForEach-Object {
        Convert-Template $_.FullName (Join-Path $claudeDir "rules\$($_.Name)")
    }
    Copy-Item (Join-Path $script:BundleRoot 'config\hooks\*') (Join-Path $claudeDir 'hooks') -Force
    Copy-Item (Join-Path $script:BundleRoot 'config\agents\*') (Join-Path $claudeDir 'agents') -Force

    # Merge settings fragments (backup + python JSON merge; never clobber)
    $mergePy = Join-Path $env:TEMP 'hb-merge-settings.py'
    @'
import json, os, shutil, sys
frag_path, dst_path = sys.argv[1], sys.argv[2]
with open(frag_path, encoding="utf-8") as fh:
    frag = json.load(fh)
data = {}
if os.path.exists(dst_path):
    shutil.copy2(dst_path, dst_path + ".bak-harness-bundle")
    with open(dst_path, encoding="utf-8") as fh:
        data = json.load(fh)
def merge(a, b):
    for k, v in b.items():
        if isinstance(v, dict) and isinstance(a.get(k), dict):
            merge(a[k], v)
        elif isinstance(v, list) and isinstance(a.get(k), list):
            a[k] = a[k] + [x for x in v if x not in a[k]]
        else:
            a.setdefault(k, v)
merge(data, frag)
with open(dst_path, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2)
print("merged", os.path.basename(dst_path))
'@ | Out-File $mergePy -Encoding utf8
    python $mergePy (Join-Path $script:BundleRoot 'config\settings\settings.fragment.json') (Join-Path $claudeDir 'settings.json')
    python $mergePy (Join-Path $script:BundleRoot 'config\settings\settings.local.fragment.json') (Join-Path $claudeDir 'settings.local.json')

    Copy-Item (Join-Path $script:BundleRoot 'config\windows\cass-watch-hidden.vbs') (Join-Path $env:USERPROFILE '.local\bin\cass-watch-hidden.vbs') -Force
    Complete-Stage $state 'config-deploy'
}

# ---- Update mode: re-deploy the WSL-side config too (without redoing installs) ----
if ($Update -and -not $SkipWSL -and (Test-StageDone $state 'wsl')) {
    Write-Info "Update mode: re-deploying WSL config (deploy-config + shell-config + symlinks steps)"
    $bundleWslPath = '/mnt/c' + ($script:BundleRoot.Substring(2) -replace '\\','/')
    @(
        "WIN_USER=$script:WinUser",
        "BUNDLE_ROOT=$bundleWslPath",
        "KIMI_ENABLED=1"
    ) -join "`n" | Out-File (Join-Path $script:BundleRoot 'install\wsl-setup.env') -Encoding ascii
    wsl -d Ubuntu -u root -- bash -lc 'sed -i -e /^deploy-config$/d -e /^shell-config$/d -e /^symlinks$/d /root/.harness-bundle-wsl-state'
    wsl -d Ubuntu -u root -- bash ($bundleWslPath + '/install/wsl-setup.sh')
}

# =================== Stage 5: WSL ===================
if ($SkipWSL) { Write-Warn2 "Stage 5 skipped by flag" }
elseif (-not (Test-StageDone $state 'wsl')) {
    Write-Info "Stage 5: WSL + Ubuntu + toolchain"
    $wslReady = $false
    try { wsl -l -v 2>$null | Out-Null; if ($LASTEXITCODE -eq 0) { $wslReady = $true } } catch {}
    if (-not $wslReady) {
        Write-Info "Enabling WSL (may require a reboot)"
        # RunOnce so the installer resumes automatically after reboot
        $runOnce = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce'
        Set-ItemProperty -Path $runOnce -Name 'HarnessBundleResume' -Value ("powershell -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`"")
        wsl --install -d Ubuntu
        Write-Host ""
        Write-Warn2 "If Windows asks to reboot: do it. The installer resumes automatically after logon."
        Write-Host "If no reboot was needed, just re-run the installer to continue."
        exit 0
    }
    $distros = (wsl -l -q) -join ' '
    if ($distros -notmatch 'Ubuntu') {
        wsl --install -d Ubuntu --no-launch
        Write-Warn2 "Ubuntu installed. Launch 'Ubuntu' once from the Start menu (any username is fine - the harness runs as root), then re-run this installer."
        exit 0
    }

    # .wslconfig (memory-sized, mirrored networking)
    $wslCfgSrc = Get-Content (Join-Path $script:BundleRoot 'config\wsl\wslconfig.template') -Raw
    $wslCfg = $wslCfgSrc -replace '\{\{WSL_MEMORY\}\}', "$($state.wslMemoryGB)GB" -replace '\{\{WSL_SWAP\}\}', "$($state.wslSwapGB)GB"
    $wslCfg | Out-File (Join-Path $env:USERPROFILE '.wslconfig') -Encoding ascii

    # Render the env file wsl-setup.sh reads (parameters never cross as args)
    $bundleWslPath = '/mnt/c' + ($script:BundleRoot.Substring(2) -replace '\\','/')
    @(
        "WIN_USER=$script:WinUser",
        "BUNDLE_ROOT=$bundleWslPath",
        "KIMI_ENABLED=1"
    ) -join "`n" | Out-File (Join-Path $script:BundleRoot 'install\wsl-setup.env') -Encoding ascii

    Write-Info "Running WSL stage (this is the long one)"
    wsl -d Ubuntu -u root -- bash ($bundleWslPath + '/install/wsl-setup.sh')
    if ($LASTEXITCODE -eq 10) { Write-Warn2 "Some WSL tools failed to install - re-run the installer later to retry them; continuing" }
    elseif ($LASTEXITCODE -ne 0) { Write-Err2 "WSL stage failed (exit $LASTEXITCODE). Fix and re-run."; exit 1 }

    # Cold-boot cycle: the [boot] hook only fires on VM start
    Write-Info "Restarting WSL so the boot hook fires (daemons start on cold boot only)"
    wsl --shutdown
    Start-Sleep -Seconds 3
    wsl -d Ubuntu -u root -- bash -lc 'true'
    Start-Sleep -Seconds 12
    $bootLog = wsl -d Ubuntu -u root -- bash -lc 'tail -5 /root/.local/share/mount-fast-data.log'
    if ("$bootLog" -match 'boot hook start') { Write-Ok "boot hook fired" } else { Write-Warn2 "boot hook log not found - check /root/.local/share/mount-fast-data.log" }
    $health = & curl.exe -s --max-time 8 http://127.0.0.1:8765/health
    if ("$health" -match '"status"\s*:\s*"ready"') { Write-Ok "Agent Mail healthy at 127.0.0.1:8765" }
    else { Write-Warn2 "Agent Mail not reachable yet (127.0.0.1:8765). It may still be starting; the smoke test re-checks. NEVER probe 'localhost' - IPv6 trap." }
    Complete-Stage $state 'wsl'
}

# =================== Stage 6: Secrets ===================
if (-not (Test-StageDone $state 'secrets')) {
    Write-Info "Stage 6: secrets setup (interactive)"
    powershell -ExecutionPolicy Bypass -File (Join-Path $script:BundleRoot 'install\secrets-setup.ps1')
    Complete-Stage $state 'secrets'
}

# =================== Stage 7: MCP registration ===================
if (-not (Test-StageDone $state 'mcp')) {
    Write-Info "Stage 7: MCP registrations"
    powershell -ExecutionPolicy Bypass -File (Join-Path $script:BundleRoot 'install\mcp-register.ps1')
    Complete-Stage $state 'mcp'
}

# =================== Stage 8: Daemons ===================
if (-not (Test-StageDone $state 'daemons')) {
    Write-Info "Stage 8: Cass Watch Daemon scheduled task"
    $vbs = Join-Path $env:USERPROFILE '.local\bin\cass-watch-hidden.vbs'
    $action = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument "`"$vbs`""
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $script:WinUser
    Register-ScheduledTask -TaskName 'Cass Watch Daemon' -Action $action -Trigger $trigger -Force | Out-Null
    Start-ScheduledTask -TaskName 'Cass Watch Daemon'
    Write-Ok "Cass Watch Daemon registered + started"
    Complete-Stage $state 'daemons'
}

# =================== Stage 9: Terminal (recommended) ===================
if (-not (Test-StageDone $state 'terminal')) {
    Write-Info "Stage 9: WezTerm (recommended terminal)"
    scoop install extras/wezterm 2>$null
    $wt = Join-Path $env:USERPROFILE '.wezterm.lua'
    if (-not (Test-Path $wt)) { Copy-Item (Join-Path $script:BundleRoot 'config\terminal\wezterm.lua') $wt }
    # Kimi module (first-class): Windows Terminal profile + env script
    $kimiCfgDir = Join-Path $env:USERPROFILE '.config\kimi'
    New-Item -ItemType Directory -Force $kimiCfgDir | Out-Null
    Copy-Item (Join-Path $script:BundleRoot 'config\kimi\kimi-env.ps1') (Join-Path $kimiCfgDir 'kimi-env.ps1') -Force
    $fragDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\Fragments\Kimi'
    New-Item -ItemType Directory -Force $fragDir | Out-Null
    (Get-Content (Join-Path $script:BundleRoot 'config\kimi\wt-fragment-kimi.json') -Raw) -replace '\{\{WIN_USER\}\}', $script:WinUser | Out-File (Join-Path $fragDir 'kimi.json') -Encoding utf8
    if (-not (Test-Path (Join-Path $kimiCfgDir 'key'))) {
        Write-Warn2 "Kimi: put your Kimi Code API key in $kimiCfgDir\key (one line). SETUP.md explains getting a subscription."
    }
    Complete-Stage $state 'terminal'
}

# =================== Stage 10: Vault starter (optional) ===================
if ($SkipVault) { Write-Warn2 "Stage 10 skipped by flag" }
elseif (-not (Test-StageDone $state 'vault')) {
    Write-Info "Stage 10: Obsidian vault starter (optional)"
    $ans = Read-Host "Set up the PKM vault starter? (y/N)"
    if ($ans -match '^[Yy]') {
        if ($state.oneDriveDocs) { $vaultDefault = "C:\Users\$script:WinUser\Vaults\MyVault" }
        else { $vaultDefault = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'MyVault' }
        $vp = Read-Host "Vault path [$vaultDefault]"
        if ([string]::IsNullOrWhiteSpace($vp)) { $vp = $vaultDefault }
        New-Item -ItemType Directory -Force $vp | Out-Null
        Copy-Item (Join-Path $script:BundleRoot 'vault-starter\*') $vp -Recurse -Force
        $state.vaultPath = $vp; Save-State $state
        Write-Ok "vault starter at $vp (install Obsidian from obsidian.md, then open this folder as a vault)"
    }
    Complete-Stage $state 'vault'
}

# =================== Stage 11: Smoke test ===================
if (-not (Test-StageDone $state 'smoke')) {
    Write-Info "Stage 11: smoke test"
    $code = Invoke-GitBash -ScriptPath (Join-Path $script:BundleRoot 'install\smoke-test.sh')
    if ($code -eq 0) { Write-Ok "smoke test green"; Complete-Stage $state 'smoke' }
    else { Write-Warn2 "smoke test reported failures (exit $code) - see output above and SETUP.md troubleshooting. Re-run this installer to retry after fixes." }
}

# =================== Summary ===================
Write-Host ""
Write-Host "==============================================" -ForegroundColor Green
Write-Host " Install complete" -ForegroundColor Green
Write-Host "==============================================" -ForegroundColor Green
Write-Host " Completed stages: $($state.completed -join ', ')"
Write-Host ""
Write-Host " Next steps:"
Write-Host "   1. Open a NEW terminal (PATH changes need it)"
Write-Host "   2. Read docs/field-guide/01-philosophy.md - the mental models matter more than the files"
Write-Host "   3. Optional opt-in (understand it first, see SETUP.md): skipDangerousModePermissionPrompt"
Write-Host "   4. Kimi: drop your key at ~\.config\kimi\key to activate the Kimi lane"
Write-Host ""
Write-Host " Uninstall: install\uninstall.ps1 (best-effort rollback; see docs/maintenance.md)"
