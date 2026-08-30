# Thin Grok adapter. Does NOT copy the brain.
#
#   powershell -ExecutionPolicy Bypass -File install\install-grok.ps1
#
# Assumes install.ps1 already deployed ~/.claude (skills, rules, hooks, flywheel).
# This script only: pin compat.claude, enable memory, junction Claude auto-memory,
# register compact + dcg hooks that call shared scripts under ~/.claude/hooks,
# and set up the OpenCode Zen stream filter proxy for Muse Spark 1.2.
#
# JSON is written from ASCII here-strings, not ConvertTo-Json.
# Windows PowerShell 5.1 unwraps single-element arrays in ConvertTo-Json,
# and UTF-8-no-BOM em dashes break the parser (gotcha 26). Keep this file ASCII.

[CmdletBinding()]
param(
    [switch]$Quiet,
    [switch]$Update
)

$ErrorActionPreference = 'Stop'
$script:WinUser = $env:USERNAME
$script:BundleRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$script:GrokHome = Join-Path $env:USERPROFILE '.grok'
$script:ClaudeHome = Join-Path $env:USERPROFILE '.claude'
$script:StateFile = Join-Path $env:USERPROFILE '.harness-bundle-grok-state.json'

function Write-Info { param($m) if (-not $Quiet) { Write-Host "-> $m" -ForegroundColor Cyan } }
function Write-Ok   { param($m) if (-not $Quiet) { Write-Host "OK $m" -ForegroundColor Green } }
function Write-Warn2 { param($m) Write-Host "WARN $m" -ForegroundColor Yellow }

function Write-Utf8NoBom {
    param([string]$Path, [string]$Text)
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Path, $Text, $utf8)
}

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

# --- compat + memory + custom models in config.toml (merge; do not clobber existing keys) ---
if ($Update -or -not ($state.completed -contains 'config')) {
    Write-Info "pinning compat.claude, enabling memory, and checking custom models in config.toml"
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
        $existing = Get-Content $cfgPath -Raw
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
        $existing = Get-Content $cfgPath -Raw
    } else {
        Write-Ok "config.toml already has memory/compat blocks (left untouched)"
    }

    if ($existing -notmatch '(?m)^\[model\.muse-spark-contributor\]') {
        $museBlock = @"

# OpenCode Zen (Muse Spark 1.2 Contributor) via local stream filter proxy (127.0.0.1:5210)
[model.muse-spark-contributor]
model = "muse-spark-1.2-contributor-free"
base_url = "http://127.0.0.1:5210/v1"
name = "Muse Spark 1.2 Contributor (OpenCode Zen)"
api_backend = "responses"
env_key = "OPENCODE_API_KEY"
context_window = 1048576
max_completion_tokens = 131072
"@
        Add-Content -Path $cfgPath -Value $museBlock -Encoding utf8
        Write-Ok "appended [model.muse-spark-contributor]"
    } else {
        Write-Ok "config.toml already has [model.muse-spark-contributor] (left untouched)"
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
        $text = @"
# Memory Index

Claude project memory is canonical. This file is a pointer, not a second store.

Write durable memories to ``~/.claude/projects/<encoded-cwd>/memory/`` (or the junction ``from-claude/`` -- same files). See ``~/.claude/rules/harness-shared.md``.

cass / ``cm`` remain the procedural and session-history layer.
"@
        Write-Utf8NoBom $pointer $text
    }
    Complete-Stage $state 'memory-junction'
}

# --- compact hook calling the SHARED PCR script ---
if ($Update -or -not ($state.completed -contains 'compact-hook')) {
    $pcr = Join-Path $script:ClaudeHome 'hooks\post-compact-reminder.py'
    if (-not (Test-Path $pcr)) {
        Write-Warn2 ('shared PCR missing at ' + $pcr + ' - compact hook will still be written')
    }
    $tpl = Join-Path $script:BundleRoot 'config\grok\hooks.json'
    $hookJson = (Get-Content $tpl -Raw) -replace '\{\{WIN_USER\}\}', $script:WinUser
    $hookPath = Join-Path $script:GrokHome 'hooks\compact.json'
    Write-Utf8NoBom $hookPath $hookJson
    Write-Ok ('wrote ' + $hookPath + ' (UTF-8 no BOM) -> shared PCR')
    Complete-Stage $state 'compact-hook'
}

# --- dcg PreToolUse bridge (dcg 0.11.1 parses Grok natively; bridge is backup, dcg#319) ---
if ($Update -or -not ($state.completed -contains 'dcg-hook')) {
    $bridgeSrc = Join-Path $script:BundleRoot 'config\hooks\dcg-grok-bridge.py'
    $bridgeDst = Join-Path $script:ClaudeHome 'hooks\dcg-grok-bridge.py'
    if (Test-Path $bridgeSrc) {
        Copy-Item $bridgeSrc $bridgeDst -Force
    } elseif (-not (Test-Path $bridgeDst)) {
        Write-Warn2 ('dcg-grok-bridge.py missing at ' + $bridgeSrc)
    }
    $impSrc = Join-Path $script:BundleRoot 'config\hooks\impeccable-hook.cmd'
    $impDst = Join-Path $script:ClaudeHome 'hooks\impeccable-hook.cmd'
    if (Test-Path $impSrc) { Copy-Item $impSrc $impDst -Force }
    $tpl = Join-Path $script:BundleRoot 'config\grok\dcg.json'
    $dcgJson = (Get-Content $tpl -Raw) -replace '\{\{WIN_USER\}\}', $script:WinUser
    $dcgPath = Join-Path $script:GrokHome 'hooks\dcg.json'
    Write-Utf8NoBom $dcgPath $dcgJson
    Write-Ok ('wrote ' + $dcgPath + ' -> shared dcg-grok-bridge.py')
    Complete-Stage $state 'dcg-hook'
}

# --- x-harvest needs the CLI, not just the skill (issue #5) ---
if ($Update -or -not ($state.completed -contains 'dev-browser')) {
    . (Join-Path $script:BundleRoot 'install\_dev-browser.ps1')
    Ensure-PinnedDevBrowser
    Complete-Stage $state 'dev-browser'
}

# --- OpenCode Zen (Muse Spark 1.2) stream filter proxy ---
if ($Update -or -not ($state.completed -contains 'opencode-proxy')) {
    Write-Info "deploying OpenCode Zen stream filter proxy and startup hooks"

    # 1. Copy proxy scripts
    $proxyFiles = @('opencode-proxy.cjs', 'start-proxy.ps1', 'run-proxy.cmd')
    foreach ($file in $proxyFiles) {
        $src = Join-Path $script:BundleRoot "config\grok\$file"
        $dst = Join-Path $script:GrokHome $file
        if (Test-Path $src) {
            Copy-Item $src $dst -Force
            Write-Ok "copied config\grok\$file -> $dst"
        }
    }

    # 2. Register SessionStart hook in ~/.grok/hooks/opencode-proxy.json
    $tpl = Join-Path $script:BundleRoot 'config\grok\opencode-proxy.json'
    if (Test-Path $tpl) {
        $hookJson = (Get-Content $tpl -Raw) -replace '\{\{WIN_USER\}\}', $script:WinUser
        $hookPath = Join-Path $script:GrokHome 'hooks\opencode-proxy.json'
        Write-Utf8NoBom $hookPath $hookJson
        Write-Ok "wrote $hookPath -> start-proxy.ps1"
    }

    # 3. Register silent Startup launcher for logon persistence
    $startupFolder = [System.Environment]::GetFolderPath('Startup')
    if (Test-Path $startupFolder) {
        $vbsPath = Join-Path $startupFolder 'opencode-proxy.vbs'
        $vbsText = @"
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "node """ & CreateObject("WScript.Shell").ExpandEnvironmentStrings("%USERPROFILE%") & "\.grok\opencode-proxy.cjs""", 0, False
"@
        Write-Utf8NoBom $vbsPath $vbsText
        Write-Ok "registered startup launcher -> $vbsPath"
    }

    # 4. Start proxy immediately if node is present and port 5210 is not active
    $port = 5210
    $conn = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
    if (-not $conn) {
        $node = Get-Command 'node' -ErrorAction SilentlyContinue
        if ($node) {
            $proxyScript = Join-Path $script:GrokHome 'opencode-proxy.cjs'
            if (Test-Path $proxyScript) {
                Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{
                    CommandLine = "node `"$proxyScript`""
                } | Out-Null
                Write-Ok "started opencode-proxy on port 5210"
            }
        } else {
            Write-Warn2 "node not found on PATH - opencode-proxy will start once node is installed"
        }
    } else {
        Write-Ok "opencode-proxy already running on port 5210"
    }

    Complete-Stage $state 'opencode-proxy'
}

Write-Ok 'Grok adapter done. Run: grok inspect   and   bash install/smoke-test-grok.sh'
Write-Info 'Do not copy skills or rules into ~/.grok. Edit ~/.claude.'
