# Thin OpenCode CLI adapter. Does NOT copy the brain.
#
#   powershell -ExecutionPolicy Bypass -File install\install-opencode.ps1
#   powershell -ExecutionPolicy Bypass -File install\install-opencode.ps1 -Update
#
# Official docs: README install, docs/skills (reads ~/.claude/skills),
# docs/rules (CLAUDE.md fallback + instructions glob), docs/mcp-servers, docs/zen.
# JSON is written from ASCII here-strings, not ConvertTo-Json.

[CmdletBinding()]
param(
    [switch]$Quiet,
    [switch]$Update
)

$ErrorActionPreference = 'Stop'
$script:BundleRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$script:ClaudeHome = Join-Path $env:USERPROFILE '.claude'
$script:OcHome = Join-Path $env:USERPROFILE '.config\opencode'
$script:StateFile = Join-Path $env:USERPROFILE '.harness-bundle-opencode-state.json'

function Write-Info { param($m) if (-not $Quiet) { Write-Host "-> $m" -ForegroundColor Cyan } }
function Write-Ok   { param($m) if (-not $Quiet) { Write-Host "OK $m" -ForegroundColor Green } }
function Write-Warn2 { param($m) Write-Host "WARN $m" -ForegroundColor Yellow }

function Write-Utf8NoBom {
    param([string]$Path, [string]$Text)
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Path, $Text, $utf8)
}

function Resolve-PythonExe {
    # The WindowsApps python.exe alias wins PATH order on some machines and only
    # prints the Store message, so prefer a real interpreter on disk.
    foreach ($command in @(Get-Command python.exe -All -ErrorAction SilentlyContinue)) {
        if ($command.Source -and ($command.Source -notmatch 'WindowsApps') -and (Test-Path -LiteralPath $command.Source -PathType Leaf)) {
            return $command.Source
        }
    }
    foreach ($root in @((Join-Path $env:LOCALAPPDATA 'Python'), (Join-Path $env:LOCALAPPDATA 'Programs\Python'))) {
        if (-not (Test-Path -LiteralPath $root -PathType Container)) { continue }
        $found = Get-ChildItem -LiteralPath $root -Filter 'python.exe' -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { return $found.FullName }
    }
    return $null
}
$script:PythonExe = Resolve-PythonExe

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

if (-not (Test-Path (Join-Path $script:ClaudeHome 'skills'))) {
    throw "Shared brain missing at $($script:ClaudeHome)\skills. Run install\install.ps1 first."
}
if (-not (Get-Command opencode -ErrorAction SilentlyContinue)) {
    Write-Warn2 "opencode CLI not found on PATH."
    Write-Host "  Official install (README): npm i -g opencode-ai@latest"
    Write-Host "  Windows alt: scoop install opencode"
    throw "opencode CLI required"
}

$state = Get-State
New-Item -ItemType Directory -Force $script:OcHome | Out-Null
New-Item -ItemType Directory -Force (Join-Path $script:OcHome 'plugins') | Out-Null

# --- config merge ---
if ($Update -or -not ($state.completed -contains 'config')) {
    Write-Info "merging OpenCode config from official schema fragment"
    $fragFile = Join-Path $script:BundleRoot 'config\opencode\opencode.jsonc.fragment'
    $dst = Join-Path $script:OcHome 'opencode.jsonc'
    # The merge rewrites the whole file. Back it up first so a bad run is a
    # one-file restore, matching the settings merge in install.ps1.
    if (Test-Path $dst) {
        $bak = "$dst.bak-" + (Get-Date -Format 'yyyyMMddTHHmmss')
        Copy-Item $dst $bak -Force
        Write-Ok "backed up existing config to $(Split-Path -Leaf $bak)"
    }
    $claudeFwd = ($script:ClaudeHome -replace '\\', '/')
    $mergePy = Join-Path $env:TEMP 'hb-merge-opencode-config.py'
    $mergePyContent = @'
import json, os, re, sys

frag_path, dst_path, claude_fwd = sys.argv[1], sys.argv[2], sys.argv[3]

def strip_jsonc(text):
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    out = []
    for line in text.splitlines():
        if "//" in line:
            in_str = False
            buf = []
            i = 0
            while i < len(line):
                ch = line[i]
                if ch == '"' and (i == 0 or line[i-1] != "\\"):
                    in_str = not in_str
                if not in_str and line[i:i+2] == "//":
                    break
                buf.append(ch)
                i += 1
            line = "".join(buf)
        out.append(line)
    return "\n".join(out)

with open(frag_path, encoding="utf-8") as f:
    frag = json.loads(strip_jsonc(f.read().replace("{{CLAUDE_HOME_FWD}}", claude_fwd)))

existing = {}
if os.path.exists(dst_path):
    with open(dst_path, encoding="utf-8") as f:
        raw = f.read().strip()
    if raw:
        existing = json.loads(strip_jsonc(raw))

# Do not keep a global AGENTS.md override: official rules doc says that
# file wins over ~/.claude/CLAUDE.md. We want the shared CLAUDE.md.

merged = dict(existing)
for key in ("$schema", "model", "autoupdate", "instructions", "permission"):
    if key in frag:
        merged[key] = frag[key]
mcp = dict(merged.get("mcp") or {})
mcp.update(frag.get("mcp") or {})
merged["mcp"] = mcp
agent = dict(merged.get("agent") or {})
agent.pop("grok-zen", None)
if agent:
    merged["agent"] = agent
else:
    merged.pop("agent", None)
plugins = merged.get("plugin")
if isinstance(plugins, list):
    merged["plugin"] = [p for p in plugins if "zen-grok-bridge" not in str(p)]
    if not merged["plugin"]:
        del merged["plugin"]

bearer_ref = os.environ.get("HB_AGENTMAIL_BEARER_REF", "").strip()
if bearer_ref:
    # Reference the token file; never write the secret into the config.
    mcp["mcp-agent-mail"] = {
        "type": "remote",
        "url": "http://127.0.0.1:8765/mcp/",
        "enabled": True,
        "headers": {"Authorization": "Bearer {file:" + bearer_ref + "}"},
    }
    merged["mcp"] = mcp
    print("OK agent-mail bearer referenced from", bearer_ref)
else:
    # Write the entry disabled rather than omitting it: a target with no
    # coordination layer must say so, not look configured.
    mcp["mcp-agent-mail"] = {
        "type": "remote",
        "url": "http://127.0.0.1:8765/mcp/",
        "enabled": False,
    }
    merged["mcp"] = mcp
    print("WARN no Agent Mail bearer provisioned; entry written disabled")

text = json.dumps(merged, indent=2)
text = text.replace("\r\n", "\n") + "\n"
with open(dst_path, "w", encoding="utf-8", newline="\n") as f:
    f.write(text)
print("OK wrote", dst_path)
'@
    Write-Utf8NoBom $mergePy $mergePyContent
    # Provision a token-only bearer file so the config can reference it instead
    # of holding the secret. No CR/LF bytes: the value is used verbatim.
    $amDir  = Join-Path $env:USERPROFILE '.config\mcp-agent-mail'
    $amCfg  = Join-Path $amDir 'config.env'
    $bearer = Join-Path $amDir 'opencode-bearer'
    $env:HB_AGENTMAIL_BEARER_REF = ''
    if (Test-Path $amCfg) {
        $line = (Select-String -Path $amCfg -Pattern '^HTTP_BEARER_TOKEN=').Line
        if ($line) {
            $secret = ($line -split '=', 2)[1].Trim()
            if ($secret) {
                $utf8NoBom = New-Object System.Text.UTF8Encoding $false
                [System.IO.File]::WriteAllText($bearer, $secret, $utf8NoBom)
                # User-only ACL: inheritance removed, then grant just this user.
                & icacls $bearer /inheritance:r /grant:r "$($env:USERNAME):(F)" | Out-Null
                # Relative to the config file, which is the documented-safe form.
                $env:HB_AGENTMAIL_BEARER_REF = '../mcp-agent-mail/opencode-bearer'
                Write-Ok "wrote token-only bearer (value not printed)"
            }
        }
    }
    if (-not $env:HB_AGENTMAIL_BEARER_REF) {
        Write-Warn2 "No Agent Mail bearer found at $amCfg"
        Write-Host "  The mcp-agent-mail entry will be written DISABLED so the gap is visible."
        Write-Host "  Provision the token, then re-run with -Update."
    }
    python $mergePy $fragFile $dst $claudeFwd
    Remove-Item Env:HB_AGENTMAIL_BEARER_REF -ErrorAction SilentlyContinue
    Complete-Stage $state 'config'
}

# --- leftover free-tier bridge ---
$bridge = Join-Path $script:OcHome 'plugins\zen-grok-bridge.js'
if (Test-Path $bridge) {
    Remove-Item $bridge -Force
    Write-Ok "removed leftover plugins/zen-grok-bridge.js"
}
$agentsMd = Join-Path $script:OcHome 'AGENTS.md'
if (Test-Path $agentsMd) {
    Write-Warn2 "AGENTS.md exists at $agentsMd - official rules say this replaces ~/.claude/CLAUDE.md. Leave it unless you want the shared CLAUDE.md."
}

Complete-Stage $state 'adapter'

# --- slash-command shims for the canonical skills ---
# OpenCode fills its slash menu from commands, not skills. Its config schema has
# `command` ("Command configuration") and `skills` ("Additional skill folder
# paths") as unrelated keys, and it does not derive one command per skill. So the
# ~112 skills in ~/.claude/skills load fine and are invocable through the Skill
# tool, yet none of them appear under "/". Impeccable was the sole visible entry
# only because `npx impeccable install` happens to write a command shim.
#
# These shims are pointers, not copies: each one just calls skill({name}). The
# brain stays in ~/.claude/skills, so the one-brain rule is preserved. The
# generator is dependency-free Python because field installs have no PyYAML.
$shimGen = Join-Path $PSScriptRoot '_gen_skill_command_shims.py'
if ($script:PythonExe -and (Test-Path $shimGen)) {
    $skillsRoot = Join-Path $script:ClaudeHome 'skills'
    if (Test-Path $skillsRoot) {
        $shimOut = & $script:PythonExe $shimGen --skills $skillsRoot --out (Join-Path $script:OcHome 'commands') 2>&1
        $shimExit = $LASTEXITCODE
        $shimOut | ForEach-Object { Write-Host "  $_" }
        if ($shimExit -eq 0) {
            Complete-Stage $state 'skill-shims'
        } else {
            Write-Warn2 "skill command shim generation reported problems (exit $shimExit) - see lines above"
        }
    } else {
        Write-Warn2 "no ~/.claude/skills yet; skipping command shims (run config-deploy first)"
    }
} else {
    Write-Warn2 "skipping skill command shims: no python interpreter or generator script found"
}

Write-Ok "OpenCode adapter done. Skills come from ~/.claude/skills (official). Rules from ~/.claude/CLAUDE.md plus instructions glob."
Write-Info "Skills are also exposed as slash commands; restart opencode to pick up new commands."
Write-Info "Auth: opencode auth list    then    opencode auth login --provider opencode   if Zen is missing"
Write-Info "TUI:  opencode"
