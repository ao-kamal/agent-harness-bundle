# Grok flavor installer (Windows orchestrator)
#
#   Get-ChildItem -Recurse | Unblock-File
#   powershell -ExecutionPolicy Bypass -File install\install-grok.ps1
#
# Resumable via %USERPROFILE%\.harness-bundle-grok-state.json
# Shared flywheel/WSL stages already completed by install.ps1 are skipped.
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
$script:StateFile = Join-Path $env:USERPROFILE '.harness-bundle-grok-state.json'
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

function Get-GrokExe {
    $p = Join-Path $env:USERPROFILE '.grok\bin\grok.exe'
    if (Test-Path $p) { return $p }
    $cmd = Get-Command grok -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
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
    Write-Host "-> Update mode: Grok config/skills will be re-deployed; flywheel installs stay untouched" -ForegroundColor Cyan
    $state.completed = @($state.completed | Where-Object { @('config-deploy', 'mcp', 'smoke') -notcontains $_ })
    Save-State $state
}

Write-Host ""
Write-Host "==============================================" -ForegroundColor Green
Write-Host " Grok harness installer" -ForegroundColor Green
Write-Host " Same flywheel, Grok as the agent CLI" -ForegroundColor DarkGray
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
    if ($freeGB -lt 8) { Write-Warn2 "Only ${freeGB}GB free on C: - Grok config will still deploy; flywheel/WSL wants ~15GB." }
    if (-not (Get-GrokExe)) {
        Write-Err2 "grok.exe not found. Install Grok Build first, then re-run."
        Write-Host "  Expected at: $env:USERPROFILE\.grok\bin\grok.exe"
        exit 1
    }
    Write-Ok "preflight passed (grok present, disk ${freeGB}GB free)"
    Complete-Stage $state 'preflight'
}

# =================== Stages 1-2: Flywheel (optional / already done) ===================
if ($SkipFlywheel) {
    Write-Warn2 "Stages 1-2 skipped by flag"
} elseif ((Test-StageDone $state 'cli-tools') -or (Test-ClaudeStage 'cli-tools')) {
    Write-Ok "Stages 1-2 already done (Grok or Claude installer state)"
    if (-not (Test-StageDone $state 'cli-tools')) { Complete-Stage $state 'cli-tools' }
} else {
    Write-Info "Stages 1-2: flywheel CLIs not installed yet"
    Write-Warn2 "This Grok installer deploys Grok config now. For cass/cm/br/bv/dcg/ntm/WSL, either:"
    Write-Host "  - re-run later after those tools are on PATH, or"
    Write-Host "  - run the shared Claude installer stages 0-2 only if you also want that flavor"
    Write-Host "  Grok hooks that call dcg.exe fail-open until dcg exists."
}

# =================== Stage 3: Grok login ===================
if (-not (Test-StageDone $state 'grok-login')) {
    Write-Info "Stage 3: Grok login"
    $auth = Join-Path $env:USERPROFILE '.grok\auth.json'
    $grok = Get-GrokExe
    if (-not (Test-Path $auth)) {
        Write-Host ""
        Write-Host "MANUAL STEP: open a NEW terminal, run:  grok login" -ForegroundColor Yellow
        Write-Host "Complete the browser login, then come back and press Enter." -ForegroundColor Yellow
        Read-Host "Press Enter once login is complete"
        if (-not (Test-Path $auth)) { Write-Err2 "Still no $auth - login did not complete. Re-run."; exit 1 }
    }
    Write-Ok "Grok authenticated ($grok)"
    Complete-Stage $state 'grok-login'
}

# =================== Stage 4: Config + skills deploy ===================
if (-not (Test-StageDone $state 'config-deploy')) {
    Write-Info "Stage 4: deploying Grok skills + config"
    $grokDir = Join-Path $env:USERPROFILE '.grok'
    $agentsDir = Join-Path $env:USERPROFILE '.agents'
    New-Item -ItemType Directory -Force @(
        (Join-Path $grokDir 'skills'),
        (Join-Path $grokDir 'rules'),
        (Join-Path $grokDir 'hooks'),
        (Join-Path $grokDir 'agents'),
        (Join-Path $agentsDir 'skills'),
        (Join-Path $agentsDir 'rules'),
        (Join-Path $agentsDir 'hooks'),
        (Join-Path $agentsDir 'agents')
    ) | Out-Null

    Write-Info "copying skills payload to ~/.grok/skills and ~/.agents/skills"
    Copy-Item (Join-Path $script:BundleRoot 'skills\*') (Join-Path $grokDir 'skills') -Recurse -Force
    Copy-Item (Join-Path $script:BundleRoot 'skills\*') (Join-Path $agentsDir 'skills') -Recurse -Force

    $dstAgentsMd = Join-Path $env:USERPROFILE 'AGENTS.md'
    if (Test-Path $dstAgentsMd) { Copy-Item $dstAgentsMd "$dstAgentsMd.bak-harness-bundle" }
    Convert-Template (Join-Path $script:BundleRoot 'config\grok\AGENTS.md.template') $dstAgentsMd

    Get-ChildItem (Join-Path $script:BundleRoot 'config\rules') -Filter '*.md' | ForEach-Object {
        Convert-Template $_.FullName (Join-Path $grokDir "rules\$($_.Name)")
        Convert-Template $_.FullName (Join-Path $agentsDir "rules\$($_.Name)")
    }
    Get-ChildItem (Join-Path $script:BundleRoot 'config\grok\rules') -Filter '*.md' | ForEach-Object {
        Convert-Template $_.FullName (Join-Path $grokDir "rules\$($_.Name)")
        Convert-Template $_.FullName (Join-Path $agentsDir "rules\$($_.Name)")
    }

    Copy-Item (Join-Path $script:BundleRoot 'config\grok\hooks\trauma_guard.py') (Join-Path $grokDir 'hooks\trauma_guard.py') -Force
    Copy-Item (Join-Path $script:BundleRoot 'config\grok\hooks\post-compact-reminder.py') (Join-Path $grokDir 'hooks\post-compact-reminder.py') -Force
    Copy-Item (Join-Path $script:BundleRoot 'config\grok\hooks\trauma_guard.py') (Join-Path $agentsDir 'hooks\trauma_guard.py') -Force
    Copy-Item (Join-Path $script:BundleRoot 'config\grok\hooks\post-compact-reminder.py') (Join-Path $agentsDir 'hooks\post-compact-reminder.py') -Force
    Convert-Template (Join-Path $script:BundleRoot 'config\grok\hooks.json') (Join-Path $grokDir 'hooks\harness.json')

    Copy-Item (Join-Path $script:BundleRoot 'config\grok\agents\deep-researcher.md') (Join-Path $grokDir 'agents\deep-researcher.md') -Force
    Copy-Item (Join-Path $script:BundleRoot 'config\grok\agents\deep-researcher.md') (Join-Path $agentsDir 'agents\deep-researcher.md') -Force

    $cfg = Join-Path $grokDir 'config.toml'
    $kimiBlock = @"

[model.kimi-for-coding]
model = "kimi-for-coding"
name = "Kimi for coding"
description = "Moonshot Kimi Code workhorse / fallback lane"
base_url = "https://api.kimi.com/coding"
api_backend = "messages"
env_key = ["KIMI_API_KEY", "ANTHROPIC_AUTH_TOKEN"]
context_window = 262144
"@
    if (Test-Path $cfg) {
        Copy-Item $cfg "$cfg.bak-harness-bundle"
        $existing = Get-Content $cfg -Raw
        if ($existing -notmatch '\[model\.kimi-for-coding\]') {
            Add-Content -Path $cfg -Value $kimiBlock
            Write-Ok "appended [model.kimi-for-coding] to config.toml"
        } else {
            Write-Ok "config.toml already has kimi-for-coding"
        }
    } else {
        Set-Content -Path $cfg -Value $kimiBlock.TrimStart() -Encoding utf8
        Write-Ok "wrote new config.toml with kimi-for-coding"
    }

    $kimiCfgDir = Join-Path $env:USERPROFILE '.config\kimi'
    New-Item -ItemType Directory -Force $kimiCfgDir | Out-Null
    if (-not (Test-Path (Join-Path $kimiCfgDir 'key'))) {
        Write-Warn2 "Kimi: put your Kimi Code API key in $kimiCfgDir\key (one line) then /model kimi-for-coding"
    }

    Complete-Stage $state 'config-deploy'
}

# =================== Stage 5: WSL (shared) ===================
if ($SkipWSL) {
    Write-Warn2 "Stage 5 skipped by flag"
} elseif ((Test-StageDone $state 'wsl') -or (Test-ClaudeStage 'wsl')) {
    Write-Ok "Stage 5 WSL already done"
    if (-not (Test-StageDone $state 'wsl')) { Complete-Stage $state 'wsl' }
} else {
    Write-Info "Stage 5: WSL not marked complete"
    Write-Warn2 "Grok flavor uses the same WSL stage as the Claude flavor (ntm, Agent Mail, flywheel)."
    Write-Host "  To install it: powershell -ExecutionPolicy Bypass -File install\install.ps1"
    Write-Host "  (Claude login is a separate later stage; stop after WSL if you only want the shared side.)"
    Write-Host "  Or re-run this installer after WSL is up; Agent Mail MCP will then register."
}

# =================== Stage 7: MCP ===================
if (-not (Test-StageDone $state 'mcp')) {
    Write-Info "Stage 7: Grok MCP registrations"
    powershell -ExecutionPolicy Bypass -File (Join-Path $script:BundleRoot 'install\mcp-register-grok.ps1')
    Complete-Stage $state 'mcp'
}

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
    Write-Info "Stage 11: Grok smoke test"
    $code = Invoke-GitBash -ScriptPath (Join-Path $script:BundleRoot 'install\smoke-test-grok.sh')
    if ($code -eq 0) { Write-Ok "smoke test green"; Complete-Stage $state 'smoke' }
    else { Write-Warn2 "smoke test reported failures (exit $code). Fix and re-run install-grok.ps1 -Update" }
}

Write-Host ""
Write-Host "==============================================" -ForegroundColor Green
Write-Host " Grok install complete" -ForegroundColor Green
Write-Host "==============================================" -ForegroundColor Green
Write-Host " Completed stages: $($state.completed -join ', ')"
Write-Host ""
Write-Host " Next steps:"
Write-Host "   1. Open a NEW terminal"
Write-Host "   2. grok inspect     (hooks, skills, deep-researcher)"
Write-Host "   3. Read docs/field-guide/01-philosophy.md then 06-grok-flavor.md"
Write-Host "   4. Optional: /model kimi-for-coding after dropping a key in ~\.config\kimi\key"
Write-Host ""
