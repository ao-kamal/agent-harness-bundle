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
    [switch]$Help,
    [switch]$SkipWSL,
    [switch]$SkipVault,
    [switch]$Quiet,
    [switch]$Update,   # after git pull: re-deploys skills/config (Win + WSL) without redoing installs
    [switch]$OpenCodeOnly # provision shared brain + WSL substrate, but leave Claude auth/plugins/secrets/MCP/full smoke pending
)

if ($Help) {
    Write-Host "agent-harness-bundle installer"
    Write-Host ""
    Write-Host "Usage: powershell -ExecutionPolicy Bypass -File install\install.ps1 [-Help] [-SkipWSL] [-SkipVault] [-Quiet] [-Update] [-OpenCodeOnly]"
    Write-Host ""
    Write-Host "  -Help      Show this help and exit"
    Write-Host "  -SkipWSL   Skip Stage 5 (WSL + Ubuntu toolchain)"
    Write-Host "  -SkipVault Skip Stage 10 (Obsidian vault starter)"
    Write-Host "  -Quiet     Suppress informational output (warnings/errors still print)"
    Write-Host "  -Update    Re-deploy config + skills (Win and WSL) and re-run the smoke test;"
    Write-Host "             does not redo package installs. Run after 'git pull'."
    Write-Host "  -OpenCodeOnly  Skip Claude auth/plugins, secrets, Claude MCP registration, and the Claude-dependent smoke test; still provisions WSL and shared skills"
    Write-Host ""
    Write-Host "  Claude auth is profile-driven, not login-driven. The settings fragments"
    Write-Host "  are merged BEFORE the profile is detected, so if settings.json carries"
    Write-Host "  ANTHROPIC_BASE_URL the installer verifies the gateway by asking the model"
    Write-Host "  to answer, and never prompts for a browser login. Otherwise it keeps the"
    Write-Host "  original behaviour and waits for ~/.claude/.credentials.json."
    exit 0
}

$ErrorActionPreference = 'Stop'
$script:BundleRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$script:StateFile = Join-Path $env:USERPROFILE '.harness-bundle-state.json'
$script:WinUser = $env:USERNAME

# ---------- atomic lock (mkdir-based; stale-PID detection) ----------
$script:LockDir = Join-Path $env:TEMP 'harness-bundle.lock'
if (Test-Path $script:LockDir) {
    $lockPid = (Get-Content (Join-Path $script:LockDir 'pid') -ErrorAction SilentlyContinue)
    $alive = $false
    if ($lockPid) { $alive = [bool](Get-Process -Id $lockPid -ErrorAction SilentlyContinue) }
    if ($alive -and $lockPid -ne $PID) {
        Write-Err2 "Another installer run is already active (PID $lockPid). Close it or wait, then re-run."
        exit 1
    }
    Remove-Item $script:LockDir -Recurse -Force  # stale lock from a dead process
}
New-Item -ItemType Directory -Path $script:LockDir -Force | Out-Null
Set-Content (Join-Path $script:LockDir 'pid') $PID


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
function Get-ScriptSha256 { param($path)
    if (-not (Test-Path $path)) { return 'missing' }
    (Get-FileHash $path -Algorithm SHA256).Hash.ToLower().Substring(0, 12)
}
# Content-hash keyed stages: a stage whose provisioning script changed re-runs even
# after being marked complete, so -Update propagates provisioning edits.
function Test-ProvisionScriptChanged { param($s, $stage, $scriptPath)
    $current = Get-ScriptSha256 $scriptPath
    $propName = "prov-$stage"
    $last = $s.PSObject.Properties[$propName].Value
    return ($last -ne $current)
}
function Complete-ProvisionedStage { param($s, $stage, $scriptPath)
    $current = Get-ScriptSha256 $scriptPath
    if (-not ($s.completed -contains $stage)) { $s.completed = @($s.completed) + $stage }
    $propName = "prov-$stage"
    if ($s.PSObject.Properties[$propName]) { $s.PSObject.Properties.Remove($propName) | Out-Null }
    $s | Add-Member -NotePropertyName $propName -NotePropertyValue $current -Force
    Save-State $s
    Write-Ok "stage complete: $stage (provision script hash recorded)"
}
$state = Get-State

function Update-SessionPath {
    # A child installer process cannot mutate this session's PATH; re-read it from the registry.
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}
function Add-UserPathEntry {
    param([string]$Directory)
    if ([string]::IsNullOrWhiteSpace($Directory)) { return }
    $Directory = $Directory.Trim()
    if (-not (Test-Path -LiteralPath $Directory -PathType Container)) { return }
    $userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
    $entries = @($userPath -split ';' | Where-Object { $_ -and $_.Trim() })
    $present = $false
    foreach ($entry in $entries) {
        if ($entry.Trim().TrimEnd('\\') -ieq $Directory.TrimEnd('\\')) { $present = $true; break }
    }
    if (-not $present) {
        [Environment]::SetEnvironmentVariable('PATH', (($entries + $Directory) -join ';'), 'User')
        Write-Ok "added $Directory to User PATH"
    }
    Update-SessionPath
}

function Resolve-PythonExe {
    # The WindowsApps python.exe alias wins PATH order on some machines and
    # only prints the Store message. Prefer a real interpreter on disk.
    $commands = @(Get-Command python.exe -All -ErrorAction SilentlyContinue)
    foreach ($command in $commands) {
        if ($command.Source -and ($command.Source -notmatch 'WindowsApps') -and (Test-Path -LiteralPath $command.Source -PathType Leaf)) {
            return $command.Source
        }
    }
    $roots = @(
        (Join-Path $env:LOCALAPPDATA 'Python'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Python')
    )
    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root -PathType Container)) { continue }
        $found = Get-ChildItem -LiteralPath $root -Filter 'python.exe' -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { return $found.FullName }
    }
    return $null
}

# Resolve the real interpreter here, not inside the cli-tools stage. Stages are
# individually skippable, but later stages consume $script:PythonExe
# unconditionally: once cli-tools is recorded complete its resolution block never
# runs, and Stage 4 dies on "& $null" with "The expression after '&' in a pipeline
# element produced an object that was not valid" — an error that names neither the
# variable nor the stage. Resolution depends on PATH, not on which tools are
# installed, so it belongs beside the PATH refresh and must run every time.
Update-SessionPath
$script:PythonExe = Resolve-PythonExe
if (-not $script:PythonExe) {
    Write-Warn2 "real Python interpreter not found (searched PATH and LocalAppData\Python); settings merge and JSON tooling will be skipped"
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

# Merge the settings fragments into the live settings files. Defined here, ahead of
# Stage 3a, because the auth probe must judge the configuration this installer is
# about to write -- not whatever was on disk beforehand.
function Sync-SettingsFragments {
    if (-not $script:PythonExe) {
        Write-Warn2 "settings fragments NOT merged: no real Python interpreter resolved (settings left untouched)"
        return
    }
    $mergePy = Join-Path $env:TEMP 'hb-merge-settings.py'
    @'
import json, os, shutil, sys
frag_path, dst_path = sys.argv[1], sys.argv[2]
win_user = sys.argv[3] if len(sys.argv) > 3 else ""
with open(frag_path, encoding="utf-8") as fh:
    frag_text = fh.read()
# install.ps1 substitutes {{WIN_USER}} for the CLAUDE.md and rules payloads before
# writing them. The settings fragments used to go straight into json.load, so every
# hook command shipped a literal "C:\Users\{{WIN_USER}}\..." path: the dcg
# PreToolUse guard, the compact SessionStart reminder, and both impeccable hooks
# all pointed at a directory that does not exist and silently did nothing.
# Substitute here too, and keep the placeholder set in step with the PS side.
for token in ("{{WIN_USER}}", "{{USER_FULL_NAME}}"):
    frag_text = frag_text.replace(token, win_user)
frag = json.loads(frag_text)
data = {}
if os.path.exists(dst_path):
    shutil.copy2(dst_path, dst_path + ".bak-harness-bundle")
    with open(dst_path, encoding="utf-8") as fh:
        data = json.load(fh)
# Control metadata, not configuration. Merging these into the user's settings.json
# shipped a top-level "overrideKeys" array into every live install, which is noise
# the user never wrote and must keep in sync by hand.
META = ("_hbFragmentVersion", "overrideKeys", "deleteKeys")
def merge(a, b):
    for k, v in b.items():
        if k in META:
            continue
        if isinstance(v, dict) and isinstance(a.get(k), dict):
            merge(a[k], v)
        elif isinstance(v, list) and isinstance(a.get(k), list):
            a[k] = a[k] + [x for x in v if x not in a[k]]
        else:
            a.setdefault(k, v)
def resolve_path(root, keys, create):
    cur = root
    for k in keys[:-1]:
        if not isinstance(cur.get(k), dict):
            if not create:
                return None
            cur[k] = {}
        cur = cur[k]
    return cur
def apply_overrides(a, b, overrides):
    # fragment-wins for keys explicitly listed in overrideKeys (dot paths)
    for path in overrides:
        keys = path.split('.')
        src = resolve_path(b, keys, create=False)
        if src is None or keys[-1] not in src:
            continue
        dst = resolve_path(a, keys, create=True)   # an override is a claim about
        dst[keys[-1]] = src[keys[-1]]               # the value, not the shape
def apply_deletions(a, paths):
    # A fragment can only ever set a key, never remove one, so a machine carrying
    # credentials from a previous routing scheme keeps them forever. OpenCode Zen
    # validates x-api-key and answers 401 to it (docs/field-guide/08), so a leftover
    # ANTHROPIC_API_KEY silently breaks the gateway the fragment is trying to set up.
    for path in paths:
        keys = path.split('.')
        parent = resolve_path(a, keys, create=False)
        if parent is not None:
            parent.pop(keys[-1], None)
# Read the previously-applied version BEFORE merging. merge() runs first and
# setdefault()s the fragment's own _hbFragmentVersion into data, so reading it
# afterwards always yielded the new value, fragVer > stored was never true, and
# apply_overrides below was unreachable. Every fragment-wins key in overrideKeys
# -- env.ANTHROPIC_BASE_URL, modelPicker -- was therefore silently ignored on any
# machine that already had a value, which is exactly the proxy-to-Zen migration
# this mechanism exists to perform.
stored = data.get('_hbFragmentVersion', 0)
fragVer = frag.get('_hbFragmentVersion', 1)
merge(data, frag)
if fragVer > stored:
    apply_overrides(data, frag, frag.get('overrideKeys', []))
    apply_deletions(data, frag.get('deleteKeys', []))
# Stamp unconditionally so a downgrade cannot make an old fragment re-apply forever.
data['_hbFragmentVersion'] = fragVer
data.pop('overrideKeys', None)
data.pop('deleteKeys', None)
with open(dst_path, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2)
print("merged", os.path.basename(dst_path))
'@ | Out-File $mergePy -Encoding utf8
    $claudeDir = Join-Path $env:USERPROFILE '.claude'
    & $script:PythonExe $mergePy (Join-Path $script:BundleRoot 'config\settings\settings.fragment.json') (Join-Path $claudeDir 'settings.json') $script:WinUser
    & $script:PythonExe $mergePy (Join-Path $script:BundleRoot 'config\settings\settings.local.fragment.json') (Join-Path $claudeDir 'settings.local.json') $script:WinUser
}

if ($Update) {
    Write-Host "-> Update mode: config/skills will be re-deployed (Win + WSL); installs stay untouched" -ForegroundColor Cyan
    $state.completed = @($state.completed | Where-Object { $_ -ne 'config-deploy' -and $_ -ne 'smoke' })
    Save-State $state
}

Write-Host ""
$script:BundleVersion = (Get-Content (Join-Path $script:BundleRoot 'VERSION') -Raw).Trim()
Write-Host "==============================================" -ForegroundColor Green
Write-Host " agent-harness-bundle installer v$script:BundleVersion" -ForegroundColor Green
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
    Update-SessionPath
}

# =================== Stage 2: CLI tools ===================
if (-not (Test-StageDone $state 'cli-tools')) {
    Write-Info "Stage 2: Windows CLI tools"
    $localBin = Join-Path $env:USERPROFILE '.local\bin'
    New-Item -ItemType Directory -Force $localBin | Out-Null
    Add-UserPathEntry $localBin
    Update-SessionPath

    # Resolve the real interpreter; the WindowsApps alias is not usable.
    $script:PythonExe = Resolve-PythonExe
    if (-not $script:PythonExe) {
        Write-Err2 "Python interpreter not found (searched PATH and LocalAppData\Python)"
        exit 1
    }
    try {
        $pythonScripts = (& $script:PythonExe -c "import sysconfig; print(sysconfig.get_path('scripts'))" 2>$null | Select-Object -First 1)
        if ($pythonScripts) { Add-UserPathEntry $pythonScripts.Trim() }
    } catch { }

    # npm's global bin is provider-dependent; put the measured prefix on PATH.
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        try {
            $npmPrefix = (& npm prefix -g 2>$null | Select-Object -First 1)
            if ($npmPrefix) { Add-UserPathEntry $npmPrefix.Trim() }
        } catch { }
    }
    Update-SessionPath

    # Per-tool truthfulness: native commands don't throw in PS 5.1, so every
    # install is checked via $LASTEXITCODE / command presence and marked
    # individually. The stage completes only when zero tools failed; failed
    # tools retry on the next run.
    function Test-ToolOnPath { param($name) [bool](Get-Command $name -ErrorAction SilentlyContinue) }
    function Invoke-Checked { param($name, $scriptblock)
        if (Test-ToolOnPath $name) { Write-Ok "$name already present"; return }
        & $scriptblock
        if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) {
            Write-Warn2 "$name install FAILED (exit $LASTEXITCODE) - will retry on re-run"
            $script:FailedTools += $name
        } elseif (-not (Test-ToolOnPath $name)) {
            Write-Warn2 "$name still not on PATH after install attempt"
            $script:FailedTools += $name
        } else {
            Write-Ok "$name installed"
        }
    }
    $script:FailedTools = @()

    foreach ($pkg in @('bv', 'cm', 'caam', 'dcg', 'slb')) {
        Invoke-Checked $pkg { scoop install "dicklesworthstone/$pkg" 2>$null }
    }
    Invoke-Checked 'ffmpeg' { scoop install ffmpeg 2>$null }

    # cass: pinned release zip + .sha256 (scoop manifest historically unreliable; the
    # pipe-the-install-script path had no checksum - both fixed here)
    Write-Info "cass via release zip + SHA256"
    if (Test-ToolOnPath 'cass') { Write-Ok 'cass already present' }
    else {
        $cassTag = 'v0.6.25'
        $cassDir = Join-Path $env:TEMP 'cass-hb'
        New-Item -ItemType Directory -Force $cassDir | Out-Null
        Invoke-WebRequest "https://github.com/Dicklesworthstone/coding_agent_session_search/releases/download/$cassTag/cass-windows-amd64.zip" -OutFile "$cassDir\cass.zip"
        Invoke-WebRequest "https://github.com/Dicklesworthstone/coding_agent_session_search/releases/download/$cassTag/cass-windows-amd64.zip.sha256" -OutFile "$cassDir\cass.zip.sha256"
        $expected = ((Get-Content "$cassDir\cass.zip.sha256" -Raw).Trim() -split '\s+')[0].ToLower()
        $actual = (Get-FileHash "$cassDir\cass.zip" -Algorithm SHA256).Hash.ToLower()
        if ($actual -ne $expected) { throw "cass zip hash mismatch - aborting this tool" }
        Expand-Archive "$cassDir\cass.zip" -DestinationPath "$cassDir\x" -Force
        $cassExe = Get-ChildItem "$cassDir\x" -Recurse -Filter cass.exe | Select-Object -First 1
        Copy-Item $cassExe.FullName (Join-Path $localBin 'cass.exe') -Force
        Unblock-File (Join-Path $localBin 'cass.exe')
        if ((Get-Command cass -ErrorAction SilentlyContinue)) { Write-Ok 'cass installed' }
        else { Write-Warn2 'cass installed to .local\bin but not on session PATH yet'; }
    }

    # br: pinned release tarball + .sha256 via Git Bash tar (same reason as cass)
    Write-Info "br via release tarball + SHA256"
    if (Test-ToolOnPath 'br') { Write-Ok 'br already present' }
    else {
        $brTag = 'v0.3.2'
        $brDir = Join-Path $env:TEMP 'br-hb'
        New-Item -ItemType Directory -Force $brDir | Out-Null
        Invoke-WebRequest "https://github.com/Dicklesworthstone/beads_rust/releases/download/$brTag/br-0.3.2-windows_amd64.zip" -OutFile "$brDir\br.zip"
        Invoke-WebRequest "https://github.com/Dicklesworthstone/beads_rust/releases/download/$brTag/br-0.3.2-windows_amd64.zip.sha256" -OutFile "$brDir\br.zip.sha256"
        $expectedBr = ((Get-Content "$brDir\br.zip.sha256" -Raw).Trim() -split '\s+')[0].ToLower()
        $actualBr = (Get-FileHash "$brDir\br.zip" -Algorithm SHA256).Hash.ToLower()
        if ($actualBr -ne $expectedBr) { throw "br zip hash mismatch - aborting this tool" }
        Expand-Archive "$brDir\br.zip" -DestinationPath "$brDir\x" -Force
        $brExe = Get-ChildItem "$brDir\x" -Recurse -Filter br.exe | Select-Object -First 1
        Copy-Item $brExe.FullName (Join-Path $localBin 'br.exe') -Force
        Unblock-File (Join-Path $localBin 'br.exe')
        if ((Get-Command br -ErrorAction SilentlyContinue)) { Write-Ok 'br installed' }
        else { Write-Warn2 'br installed to .local\bin but not on session PATH yet' }
    }
    # ms: release zip (upstream's own installers are broken for Windows)
    if (-not (Get-Command ms -ErrorAction SilentlyContinue)) {
        Write-Info "ms via release zip + SHA256SUMS"
        Import-Module BitsTransfer
        $msDir = Join-Path $env:TEMP 'ms-hb'
        New-Item -ItemType Directory -Force $msDir | Out-Null
        # The upstream latest release currently has no Windows ms asset, and its
        # checksum file is named SHA256SUMS.txt (not SHA256SUMS). Pin the last
        # release that publishes the Windows zip this installer expects.
        $msRelease = 'v0.2.0'
        $msBase = "https://github.com/Dicklesworthstone/meta_skill/releases/download/$msRelease"
        Start-BitsTransfer -Source "$msBase/SHA256SUMS.txt" -Destination "$msDir\SHA256SUMS" -RetryInterval 60 -RetryTimeout 600
        $msAsset = (Get-Content "$msDir\SHA256SUMS" | Select-String 'x86_64-pc-windows-msvc.zip').Line
        $msName = ($msAsset -split '\s+')[1] -replace '^\*',''
        $msHash = ($msAsset -split '\s+')[0]
        Start-BitsTransfer -Source "$msBase/$msName" -Destination "$msDir\ms.zip" -RetryInterval 60 -RetryTimeout 600
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
    # NEVER `npm install -g dev-browser@latest`. SawyerHood stock overwrote our
    # pinned ergo Windows exe on 2026-07-31 (harness-bundle Track A).
    foreach ($npmPkg in @('defuddle', 'firecrawl-cli')) {
        $npmCommand = if ($npmPkg -eq 'firecrawl-cli') { 'firecrawl' } else { $npmPkg }
        Invoke-Checked $npmCommand { npm install -g $npmPkg --silent }
    }
    Invoke-Checked 'yt-dlp' { & $script:PythonExe -m pip install --quiet yt-dlp }
    Invoke-Checked 'uv' { & $script:PythonExe -m pip install --quiet uv }

    . (Join-Path $script:BundleRoot 'install\_dev-browser.ps1')
    Ensure-PinnedDevBrowser

    # All PATH changes above are also applied to this session, so the checks
    # below and the remainder of this run see the same commands as a new shell.
    Update-SessionPath
    if ($script:FailedTools.Count -gt 0) {
        Write-Warn2 ("Stage 2 incomplete - failed tools: " + ($script:FailedTools -join ', ') + ". Re-run this installer to retry ONLY the failed tools.")
    } else {
        Complete-Stage $state 'cli-tools'
    }
}

# =================== Stage 3a: Claude Code + auth (MANUAL GATE) ===================
if ($OpenCodeOnly) {
    Write-Warn2 "Stage 3a skipped (-OpenCodeOnly): Claude Code auth remains pending"
} elseif (-not (Test-StageDone $state 'claude-login')) {
    Write-Info "Stage 3a: Claude Code + auth"
    Update-SessionPath
    if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
        Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression
        Update-SessionPath
        if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
            Write-Err2 "claude still not on PATH after install. Open a NEW terminal, verify 'claude --version' works, then re-run this installer (it resumes here)."
            exit 1
        }
    }

    # Two auth shapes are supported, and they are mutually exclusive:
    #
    #   claude.ai / Console -> a browser login writes ~/.claude/.credentials.json
    #   gateway routing     -> settings.json carries ANTHROPIC_BASE_URL plus a
    #                          credential variable, and no credentials file exists
    #
    # This stage used to probe for the credentials file FIRST and prompt for a
    # browser login when it was absent. That deadlocked every gateway install:
    # it demanded a login that could never complete, because a gateway never
    # writes that file. Detect the profile first, then verify the thing that
    # actually matters -- that the model answers.
    #
    # The profile must be detected from the settings this installer is about to
    # deploy, not from whatever happened to be on disk. Reading first created a
    # chicken-and-egg deadlock on exactly the machine this profile exists to
    # serve: a machine still carrying ANTHROPIC_BASE_URL=http://127.0.0.1:5210
    # from a local filter proxy. The probe ran against the dead proxy, failed,
    # and `exit 1` fired -- one stage BEFORE the config-deploy that would have
    # rewritten that URL to opencode.ai/zen. The migration could never run on the
    # machine that needed it. Deploy the fragments first, then judge.
    Sync-SettingsFragments
    $authMode = 'claude-login'
    $gwBase = $null
    $claudeSettings = Join-Path $env:USERPROFILE '.claude\settings.json'
    if (Test-Path $claudeSettings) {
        try {
            $sj = Get-Content $claudeSettings -Raw | ConvertFrom-Json
            if ($sj.env -and $sj.env.ANTHROPIC_BASE_URL) {
                $authMode = 'gateway'
                $gwBase = $sj.env.ANTHROPIC_BASE_URL
            }
        } catch { }
    }

    if ($authMode -eq 'gateway') {
        Write-Info "auth profile: gateway ($gwBase)"
        $probe = (& claude -p 'Reply with exactly: PONG' 2>&1 | Out-String)
        if ($probe -notmatch 'PONG') {
            Write-Err2 "gateway routing is configured but claude did not answer. Check ANTHROPIC_BASE_URL / ANTHROPIC_MODEL in $claudeSettings, then re-run."
            exit 1
        }
        Write-Ok "Claude Code answering through the gateway (no credentials file required)"
    } else {
        $creds = Join-Path $env:USERPROFILE '.claude\.credentials.json'
        if (-not (Test-Path $creds)) {
            Write-Host ""
            Write-Host "MANUAL STEP: open a NEW terminal, run:  claude" -ForegroundColor Yellow
            Write-Host "Complete the browser login, then exit Claude Code and press Enter here." -ForegroundColor Yellow
            Read-Host "Press Enter once login is complete"
            if (-not (Test-Path $creds)) { Write-Err2 "Still no credentials file - login did not complete. Re-run the installer."; exit 1 }
        }
        Write-Ok "Claude Code authenticated"
    }
    Complete-Stage $state 'claude-login'
}

# =================== Stage 3b: Plugins + canonical skills ===================
if ($OpenCodeOnly) {
    Write-Warn2 "Stage 3b skipped (-OpenCodeOnly): Claude plugins remain pending"
} elseif (-not (Test-StageDone $state 'plugins')) {
    Write-Info "Stage 3b: plugins + canonical skill installs"
    Update-SessionPath

    # See the note below: $ErrorActionPreference is 'Stop' script-wide, so every
    # third-party call in this stage is wrapped and judged by exit code. A
    # marketplace that 404s or a plugin that fails to build must not take the
    # mandatory config-deploy stage down with it.
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'

    foreach ($mkt in @('anthropics/claude-code', 'anthropics/skills', 'anthropics/claude-plugins-official')) {
        claude plugin marketplace add $mkt 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { Write-Warn2 "marketplace add failed: $mkt (continuing)" }
    }
    foreach ($pl in @('frontend-design@claude-code-plugins',
                      'document-skills@anthropic-agent-skills',
                      'vercel@claude-plugins-official')) {
        claude plugin install $pl 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { Write-Warn2 "plugin install failed: $pl (continuing)" }
    }

    # Optional third-party skill sources must never be able to abort the install.
    #
    # $ErrorActionPreference is 'Stop' for the whole script, and under it a
    # native command that writes to stderr and exits non-zero raises a
    # terminating NativeCommandError. So a single flaky upstream download took
    # the run down at exit 1 and the mandatory config-deploy stage after it never
    # executed -- an optional nicety blocking required work. That has now bitten
    # twice (Stage 9 previously, this one), so it is handled structurally: drop
    # to Continue around these calls and judge them by exit code.
    Write-Info "impeccable skill family via npx (optional)"
    # $ErrorActionPreference is already 'Continue' for this whole stage (see the
    # note at the top of it) and $prevEAP was captured once, before it was
    # lowered. Re-capturing it here would record 'Continue' and restore that
    # instead of 'Stop', quietly disarming every later stage.
    npx --yes impeccable skills install -y --providers=claude 2>&1 |
        Select-Object -Last 3 | ForEach-Object { Write-Host "    $_" }
    if ($LASTEXITCODE -ne 0) {
        Write-Warn2 "impeccable skill install failed (exit $LASTEXITCODE) - continuing."
        Write-Warn2 "This is an optional upstream skill family, not a prerequisite. Re-run later with:"
        Write-Warn2 "  npx --yes impeccable skills install -y --providers=claude"
        Write-Warn2 "Upstream tracker: https://github.com/pbakaus/impeccable/issues"
    }

    $exSkill = Join-Path $env:USERPROFILE '.claude\skills\excalidraw-diagram'
    if (-not (Test-Path $exSkill)) {
        git clone --depth 1 https://github.com/coleam00/excalidraw-diagram-skill.git $exSkill 2>&1 |
            Select-Object -Last 2 | ForEach-Object { Write-Host "    $_" }
        if ($LASTEXITCODE -ne 0) {
            Write-Warn2 "excalidraw-diagram skill clone failed (exit $LASTEXITCODE) - continuing."
            Remove-Item $exSkill -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    $ErrorActionPreference = $prevEAP
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

    # Render CLAUDE.md + rules ({{WIN_USER}} substitution).
    # Non-destructive deploy: live ~/.claude is canonical. If the live file differs from
    # what this bundle last deployed (tracked in .harness-deployed-hashes.json), refuse to
    # overwrite and drop the new content as <name>.incoming for the user to merge.
    function Convert-Template { param($src, $dst)
        (Get-Content $src -Raw) -replace '\{\{WIN_USER\}\}', $script:WinUser -replace '\{\{USER_FULL_NAME\}\}', $script:WinUser | Out-File $dst -Encoding utf8
    }
    function Get-FileSha256 { param($path)
        if (-not (Test-Path $path)) { return $null }
        (Get-FileHash $path -Algorithm SHA256).Hash.ToLower()
    }
    $deployedHashes = Join-Path $env:USERPROFILE '.harness-deployed-hashes.json'
    if (Test-Path $deployedHashes) { $depHash = Get-Content $deployedHashes -Raw | ConvertFrom-Json } else { $depHash = [pscustomobject]@{} }
    $script:DeployConflicts = @()
    function Deploy-ConfigFile { param($rendered, $livePath)
        # $rendered is the full text of the new file; decide vs. last-deployed hash.
        $rel = $livePath.Substring($claudeDir.Length + 1)
        $lastHash = $depHash.PSObject.Properties[$rel].Value
        # UTF-8 without BOM. Windows PowerShell 5.1 defaults to the system ANSI
        # codepage (cp1252) on Get-Content without -Encoding, which turns every
        # em dash into "a-circumflex-euro-quote" and every arrow into mojibake;
        # Set-Content -Encoding utf8 then adds a BOM on top. Both directions are
        # silent, so a deploy "succeeds" and ships a corrupted brain to every
        # harness. Read as UTF-8, write as UTF-8 with no BOM.
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        $newBytes = [System.Text.Encoding]::UTF8.GetBytes($rendered)
        $sha = [System.Security.Cryptography.SHA256]::Create()
        $newHash = ([BitConverter]::ToString($sha.ComputeHash($newBytes)) -replace '-','').ToLower()
        if ((Test-Path $livePath) -and $lastHash -and ($null -ne $lastHash)) {
            $liveHash = Get-FileSha256 $livePath
            if ($liveHash -ne $lastHash -and $liveHash -ne $newHash) {
                # live was modified since we deployed; never clobber user edits
                Copy-Item $livePath "$livePath.bak.$(Get-Date -Format yyyyMMddHHmmss)"
                [System.IO.File]::WriteAllText("$livePath.incoming", $rendered, $utf8NoBom)
                $script:DeployConflicts += $rel
                Write-Warn2 "LIVE EDIT preserved: $rel differs from last deploy -> wrote $rel.incoming (backup alongside); merge manually"
                return
            }
        }
        if (Test-Path $livePath) {
            Copy-Item $livePath "$livePath.bak.$(Get-Date -Format yyyyMMddHHmmss)"
        }
        [System.IO.File]::WriteAllText($livePath, $rendered, $utf8NoBom)
        if ($depHash.PSObject.Properties[$rel]) { $depHash.PSObject.Properties.Remove($rel) | Out-Null }
        $depHash | Add-Member -NotePropertyName $rel -NotePropertyValue $newHash -Force
    }
    $dstClaudeMd = Join-Path $claudeDir 'CLAUDE.md'
    Deploy-ConfigFile ((Get-Content (Join-Path $script:BundleRoot 'config\CLAUDE.md.template') -Raw -Encoding UTF8) -replace '\{\{WIN_USER\}\}', $script:WinUser -replace '\{\{USER_FULL_NAME\}\}', $script:WinUser) $dstClaudeMd
    Get-ChildItem (Join-Path $script:BundleRoot 'config\rules') -Filter '*.md' | ForEach-Object {
        Deploy-ConfigFile ((Get-Content $_.FullName -Raw -Encoding UTF8) -replace '\{\{WIN_USER\}\}', $script:WinUser -replace '\{\{USER_FULL_NAME\}\}', $script:WinUser) (Join-Path $claudeDir "rules\$($_.Name)")
    }
    $depHash | ConvertTo-Json -Depth 3 | Out-File $deployedHashes -Encoding utf8
    Copy-Item (Join-Path $script:BundleRoot 'config\hooks\*') (Join-Path $claudeDir 'hooks') -Force
    Copy-Item (Join-Path $script:BundleRoot 'config\agents\*') (Join-Path $claudeDir 'agents') -Force

    # Settings fragments are merged by Sync-SettingsFragments, which Stage 3a also
    # calls so the auth probe judges the config this installer deploys.
    Sync-SettingsFragments

    Copy-Item (Join-Path $script:BundleRoot 'config\windows\cass-watch-hidden.vbs') (Join-Path $env:USERPROFILE '.local\bin\cass-watch-hidden.vbs') -Force
    Complete-Stage $state 'config-deploy'
}

# ---- Update mode: re-deploy the WSL-side config too (without redoing installs) ----
if ($Update -and -not $SkipWSL -and (Test-StageDone $state 'wsl')) {
    Write-Info "Update mode: re-deploying WSL config (deploy-config + shell-config + symlinks steps)"
    $bundleWslPath = '/mnt/c' + ($script:BundleRoot.Substring(2) -replace '\\','/')
    $wslEnv = @(
        "WIN_USER=$script:WinUser",
        "BUNDLE_ROOT=$bundleWslPath",
        "KIMI_ENABLED=1"
    )
    if ($OpenCodeOnly) { $wslEnv += "SKIP_CLAUDE=1" }
    $wslEnv -join "`n" | Out-File (Join-Path $script:BundleRoot 'install\wsl-setup.env') -Encoding ascii
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
        Write-Info "Enabling WSL (BITS-verified Microsoft package; may require a reboot)"
        # RunOnce so the installer resumes automatically after reboot
        $runOnce = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce'
        $resumeCommand = "powershell -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
        if ($OpenCodeOnly) { $resumeCommand += ' -OpenCodeOnly' }
        if ($SkipVault) { $resumeCommand += ' -SkipVault' }
        if ($SkipWSL) { $resumeCommand += ' -SkipWSL' }
        Set-ItemProperty -Path $runOnce -Name 'HarnessBundleResume' -Value $resumeCommand
        $bitsScript = Join-Path $script:BundleRoot 'install\install-wsl-bits.ps1'
        powershell -ExecutionPolicy Bypass -File $bitsScript -Version '2.7.14' -InstallDistro
        if ($LASTEXITCODE -ne 0) {
            Write-Err2 "BITS WSL provisioning failed (exit $LASTEXITCODE). No workaround was applied."
            exit 1
        }
        Update-SessionPath
        try { wsl -l -v 2>$null | Out-Null; if ($LASTEXITCODE -eq 0) { $wslReady = $true } } catch {}
        if (-not $wslReady) {
            Write-Warn2 "WSL features/package require a Windows reboot. No reboot was forced; re-run after reboot."
            exit 0
        }
    }
    $distros = (wsl -l -q) -join ' '
    if ($distros -notmatch 'Ubuntu') {
        $bitsScript = Join-Path $script:BundleRoot 'install\install-wsl-bits.ps1'
        powershell -ExecutionPolicy Bypass -File $bitsScript -Version '2.7.14' -InstallDistro
        if ($LASTEXITCODE -ne 0) {
            Write-Err2 "BITS Ubuntu provisioning failed (exit $LASTEXITCODE)."
            exit 1
        }
        Write-Warn2 "Ubuntu install command completed. Launch 'Ubuntu' once from the Start menu (any username is fine - the harness runs as root), then re-run this installer."
        exit 0
    }

    # .wslconfig (memory-sized, mirrored networking)
    $wslCfgSrc = Get-Content (Join-Path $script:BundleRoot 'config\wsl\wslconfig.template') -Raw
    $wslCfg = $wslCfgSrc -replace '\{\{WSL_MEMORY\}\}', "$($state.wslMemoryGB)GB" -replace '\{\{WSL_SWAP\}\}', "$($state.wslSwapGB)GB"
    $wslCfg | Out-File (Join-Path $env:USERPROFILE '.wslconfig') -Encoding ascii

    # Render the env file wsl-setup.sh reads (parameters never cross as args)
    $bundleWslPath = '/mnt/c' + ($script:BundleRoot.Substring(2) -replace '\\','/')
    $wslEnv = @(
        "WIN_USER=$script:WinUser",
        "BUNDLE_ROOT=$bundleWslPath",
        "KIMI_ENABLED=1"
    )
    if ($OpenCodeOnly) { $wslEnv += "SKIP_CLAUDE=1" }
    $wslEnv -join "`n" | Out-File (Join-Path $script:BundleRoot 'install\wsl-setup.env') -Encoding ascii

    Write-Info "Running WSL stage (this is the long one)"
    wsl -d Ubuntu -u root -- bash ($bundleWslPath + '/install/wsl-setup.sh')
    if ($LASTEXITCODE -eq 10) {
        # Partial failure: wsl-setup.sh marks each tool's step done only on success,
        # so a re-run of THIS stage retries just the failed tools. Do NOT mark 'wsl'
        # complete here, or the retry path becomes unreachable.
        Write-Warn2 "Some WSL tools failed to install. Re-run this installer (plain re-run) to retry ONLY the failed tools; continuing for now"
    }
    elseif ($LASTEXITCODE -ne 0) { Write-Err2 "WSL stage failed (exit $LASTEXITCODE). Fix and re-run."; exit 1 }
    else { Complete-Stage $state 'wsl' }

    # Cold-boot cycle: the [boot] hook only fires on VM start
    Write-Info "Restarting WSL so the boot hook fires (daemons start on cold boot only)"
    wsl --shutdown
    Start-Sleep -Seconds 3
    wsl -d Ubuntu -u root -- bash -lc 'true'
    Start-Sleep -Seconds 12
    $bootLog = wsl -d Ubuntu -u root -- bash -lc 'tail -5 /root/.local/share/mount-fast-data.log'
    if ("$bootLog" -match 'boot hook start') { Write-Ok "boot hook fired" } else { Write-Warn2 "boot hook log not found - check /root/.local/share/mount-fast-data.log" }
    $health = & curl.exe -s --max-time 8 http://127.0.0.1:8765/api/health
    if ("$health" -match '"status"\s*:\s*"(ready|ok)"') { Write-Ok "Agent Mail healthy at 127.0.0.1:8765/api/health" }
    else { Write-Warn2 "Agent Mail not reachable yet (127.0.0.1:8765). It may still be starting; the smoke test re-checks. NEVER probe 'localhost' - IPv6 trap." }
}

# =================== Stage 6: Secrets ===================
if ($OpenCodeOnly) {
    Write-Warn2 "Stage 6 skipped (-OpenCodeOnly): interactive secrets setup remains pending"
} elseif (-not (Test-StageDone $state 'secrets')) {
    Write-Info "Stage 6: secrets setup (interactive)"
    powershell -ExecutionPolicy Bypass -File (Join-Path $script:BundleRoot 'install\secrets-setup.ps1')
    Complete-Stage $state 'secrets'
}

# =================== Stage 7: MCP registration ===================
$mcpScript = Join-Path $script:BundleRoot 'install\mcp-register.ps1'
if ($OpenCodeOnly) {
    Write-Warn2 "Stage 7 skipped (-OpenCodeOnly): Claude MCP registrations remain pending"
} elseif ((-not (Test-StageDone $state 'mcp')) -or (Test-ProvisionScriptChanged $state 'mcp' $mcpScript)) {
    Write-Info "Stage 7: MCP registrations"
    powershell -ExecutionPolicy Bypass -File $mcpScript
    Complete-ProvisionedStage $state 'mcp' $mcpScript
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
    # Only reach for Scoop when WezTerm is genuinely absent. `scoop install` on a
    # host that already has WezTerm still performs a bucket update, and that git
    # step writes "no tracking information for the current branch" to stderr. Under
    # $ErrorActionPreference='Stop' that killed Stage 9 on a machine that already
    # had WezTerm, leaving .wezterm.lua and the Kimi fragment unwritten.
    if (Get-Command wezterm -ErrorAction SilentlyContinue) {
        Write-Ok "WezTerm already on PATH; skipping scoop install"
    } else {
        scoop install extras/wezterm 2>$null
    }
    $wt = Join-Path $env:USERPROFILE '.wezterm.lua'
    if (-not (Test-Path $wt)) { Copy-Item (Join-Path $script:BundleRoot 'config\terminal\wezterm.lua') $wt }
    # Kimi module (first-class): Windows Terminal profile + env script
    $kimiCfgDir = Join-Path $env:USERPROFILE '.config\kimi'
    New-Item -ItemType Directory -Force $kimiCfgDir | Out-Null
    Copy-Item (Join-Path $script:BundleRoot 'config\kimi\kimi-env.ps1') (Join-Path $kimiCfgDir 'kimi-env.ps1') -Force
    $fragDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\Fragments\Kimi'
    New-Item -ItemType Directory -Force $fragDir | Out-Null
    # Windows Terminal parses this fragment as JSON, so it must not carry a BOM.
    # Out-File -Encoding utf8 in Windows PowerShell 5.1 prepends one.
    $kimiJson = (Get-Content (Join-Path $script:BundleRoot 'config\kimi\wt-fragment-kimi.json') -Raw -Encoding UTF8) -replace '\{\{WIN_USER\}\}', $script:WinUser
    [System.IO.File]::WriteAllText((Join-Path $fragDir 'kimi.json'), $kimiJson, (New-Object System.Text.UTF8Encoding($false)))
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
if ($OpenCodeOnly) {
    Write-Warn2 "Stage 11 skipped (-OpenCodeOnly): the full smoke test requires Claude on Windows and WSL"
} elseif (-not (Test-StageDone $state 'smoke')) {
    Write-Info "Stage 11: smoke test"
    $code = Invoke-GitBash -ScriptPath (Join-Path $script:BundleRoot 'install\smoke-test.sh')
    if ($code -eq 0) { Write-Ok "smoke test green"; Complete-Stage $state 'smoke' }
    else {
        Write-Err2 "smoke test reported failures (exit $code) - see output above and SETUP.md troubleshooting. Re-run this installer to retry after fixes."
        $script:SmokeFailed = $true
    }
}

if ($OpenCodeOnly) {
    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Green
    Write-Host " OpenCode-only provisioning complete" -ForegroundColor Green
    Write-Host "==============================================" -ForegroundColor Green
    Write-Host " Completed stages: $($state.completed -join ', ')"
    Write-Host " Claude login, Claude plugins, secrets, Claude MCP registration, and the full smoke test remain pending."
    Write-Host " Next: install/configure OpenCode, then run smoke-test-opencode.sh and the portability probe."
    Write-Host ""
    $lockDirNow = Join-Path $env:TEMP 'harness-bundle.lock'
    if (Test-Path (Join-Path $lockDirNow 'pid')) {
        $lockPidNow = Get-Content (Join-Path $lockDirNow 'pid') -ErrorAction SilentlyContinue
        if ($lockPidNow -eq $PID) { Remove-Item $lockDirNow -Recurse -Force }
    }
    exit 0
}

# =================== Summary ===================
# Honesty gate: a failed (or skipped) smoke run suppresses the success banner and exits non-zero.
$script:SmokeFailed = -not (Test-StageDone $state 'smoke')
if ($script:SmokeFailed) {
    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Red
    Write-Host " Install FINISHED WITH FAILURES" -ForegroundColor Red
    Write-Host "==============================================" -ForegroundColor Red
    Write-Host " The smoke test did NOT pass (skipped or failed). Do not treat this" -ForegroundColor Yellow
    Write-Host " machine as provisioned until a full green smoke run completes." -ForegroundColor Yellow
    Write-Host " Re-run this installer after fixing the failures above." -ForegroundColor Yellow
    Write-Host ""
    $lockDirNow = Join-Path $env:TEMP 'harness-bundle.lock'
    if (Test-Path (Join-Path $lockDirNow 'pid')) {
        $lockPidNow = Get-Content (Join-Path $lockDirNow 'pid') -ErrorAction SilentlyContinue
        if ($lockPidNow -eq $PID) { Remove-Item $lockDirNow -Recurse -Force }
    }
    exit 1
}
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

# ---------- lock release ----------
# Stale locks self-heal via PID detection at startup; this just releases cleanly on normal exit.
$lockDirNow = Join-Path $env:TEMP 'harness-bundle.lock'
if (Test-Path (Join-Path $lockDirNow 'pid')) {
    $lockPidNow = Get-Content (Join-Path $lockDirNow 'pid') -ErrorAction SilentlyContinue
    if ($lockPidNow -eq $PID) { Remove-Item $lockDirNow -Recurse -Force }
}
