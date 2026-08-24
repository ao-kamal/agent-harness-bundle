# Thin Hermes Agent adapter. Does NOT copy the brain.
#
#   powershell -ExecutionPolicy Bypass -File install\install-hermes.ps1
#   powershell -ExecutionPolicy Bypass -File install\install-hermes.ps1 -Update
#   powershell -ExecutionPolicy Bypass -File install\install-hermes.ps1 -PruneBundledSkills
#
# Assumes install.ps1 already deployed ~/.claude (skills, rules).
#
# What this adapter does:
#   1. Points Hermes at the shared brain via its NATIVE external-dir mechanism
#      (skills.external_dirs in config.yaml) -- read-only, no copies, no junctions.
#   2. Sets bundle-preference config: no auto skill-minting (curator + nudge off),
#      unlimited clarify timeout.
#   3. Appends a marker-delimited Operating Rules block to SOUL.md.
#      QUIRK: Hermes (as of 2026-08) loads ONLY $HERMES_HOME/SOUL.md globally;
#      global AGENTS.md loading is PR NousResearch/hermes-agent#23331 (open).
#      When that PR merges and you update: move the block to HERMES_HOME/AGENTS.md
#      and trim SOUL.md back to identity only. The block carries this note itself.
#   4. Registers mcp-agent-mail from the WSL stage's generated token file.
#
# YAML merge is done with a small python script (same pattern as install.ps1's
# settings merge): backup first, idempotent, never clobber unrelated keys.

[CmdletBinding()]
param(
    [switch]$Quiet,
    [switch]$Update,
    # Delete Hermes' bundled builtin skills permanently (Kamal preference: curated
    # brain only). Off by default -- a fresh Hermes user may want builtins.
    [switch]$PruneBundledSkills
)

function Show-Usage {
    Write-Host @"
agent-harness-bundle Hermes Agent adapter

Usage:
  powershell -ExecutionPolicy Bypass -File install\install-hermes.ps1 [-Update] [-PruneBundledSkills] [-Quiet]

Flags:
  -Update              Re-apply config keys + refresh the SOUL.md rules block
  -PruneBundledSkills  Permanently remove Hermes' bundled builtin skills (interactive confirm)
  -Quiet               Suppress progress output

Requires: install\install.ps1 run first (~/.claude brain) and the hermes CLI.
"@
}
if ($args -contains '-?' -or $args -contains '-help' -or $args -contains '--help') { Show-Usage; exit 0 }


$ErrorActionPreference = 'Stop'
$script:WinUser = $env:USERNAME
$script:BundleRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$script:ClaudeHome = Join-Path $env:USERPROFILE '.claude'
$script:StateFile = Join-Path $env:USERPROFILE '.harness-bundle-hermes-state.json'

function Write-Info { param($m) if (-not $Quiet) { Write-Host "-> $m" -ForegroundColor Cyan } }
function Write-Ok   { param($m) Write-Host "OK $m" -ForegroundColor Green }
function Write-Warn2 { param($m) Write-Host "WARN $m" -ForegroundColor Yellow }

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

# --- Preflight ---------------------------------------------------------------
if (-not (Test-Path (Join-Path $script:ClaudeHome 'skills'))) {
    throw "Shared brain missing at $($script:ClaudeHome)\skills. Run install\install.ps1 first."
}
if (-not (Get-Command hermes -ErrorAction SilentlyContinue)) {
    Write-Warn2 "hermes CLI not found on PATH."
    Write-Host "  Install Hermes Agent first:"
    Write-Host "    curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash"
    Write-Host "  (run from Git Bash / WSL), or see https://hermes-agent.nousresearch.com/docs/getting-started/installation"
    throw "hermes CLI required"
}

# Resolve HERMES_HOME the way Hermes does: env var wins, else platform default.
$script:HermesHome = $env:HERMES_HOME
if ([string]::IsNullOrWhiteSpace($script:HermesHome)) {
    $script:HermesHome = Join-Path $env:LOCALAPPDATA 'hermes'
}
if (-not (Test-Path $script:HermesHome)) {
    throw "Hermes home not found at $($script:HermesHome). Run 'hermes' once to initialize it, then re-run."
}
$script:ConfigYaml = Join-Path $script:HermesHome 'config.yaml'
$script:SoulMd = Join-Path $script:HermesHome 'SOUL.md'

Write-Info "Hermes adapter: brain=$($script:ClaudeHome) home=$($script:HermesHome)"
$state = Get-State

# --- Stage H1: config.yaml fragment -------------------------------------------
if ($Update -or -not ($state.completed -contains 'config')) {
    Write-Info "merging bundle keys into config.yaml"

    $brainForward = ($script:ClaudeHome -replace '\\', '/')

    $mergePy = Join-Path $env:TEMP 'hb-merge-hermes-config.py'
    @'
import io, os, shutil, sys

# Minimal YAML edit for ONE known top-level shape: set/add scalar keys under a
# section, creating the section if absent. Deliberately not a general YAML
# parser -- config.yaml is machine-managed by `hermes config set` and has a
# flat, predictable layout. A regex-based targeted patch avoids reformatting
# the whole file (which would churn every hermes update).

def fail(msg):
    print("ERR " + msg); sys.exit(1)

path = sys.argv[1]
skills_dir = sys.argv[2]

with io.open(path, encoding="utf-8") as fh:
    lines = fh.read().splitlines()

def find_section(name):
    """Return index of 'name:' line at column 0, or -1."""
    for i, ln in enumerate(lines):
        if ln == name + ":":
            return i
        if ln.startswith(name + ":") and not ln[len(name)+1:].startswith((" ", "#")):
            return i
    return -1

def section_end(start):
    """First line after `start` that is top-level (col 0, non-empty, non-comment)."""
    for j in range(start + 1, len(lines)):
        ln = lines[j]
        if ln and not ln[0].isspace() and not ln.startswith("#"):
            return j
    return len(lines)

def key_in_section(start, end, key):
    for j in range(start + 1, end):
        stripped = lines[j].lstrip()
        if stripped.startswith(key + ":"):
            indent = len(lines[j]) - len(stripped)
            if indent == 2:  # direct child of the section
                return j
    return -1

def set_scalar(section, key, value):
    """Bundle-owned opinion: ENFORCE the value, log the old one if different.
    These keys are what the bundle stands for (no auto-minting, unlimited
    clarify); a stale local value silently defeating them is a bug, not a
    preference to preserve."""
    global lines
    s = find_section(section)
    if s < 0:
        lines.append("")
        lines.append(section + ":")
        s = len(lines) - 1
    e = section_end(s)
    k = key_in_section(s, e, key)
    line = "  " + key + ": " + value
    if k >= 0:
        cur = lines[k].split(":", 1)[1].strip()
        if cur != value:
            print("set " + section + "." + key + ": " + cur + " -> " + value)
            lines[k] = line
        else:
            print("already " + section + "." + key + " = " + value)
    else:
        lines.insert(e, line)

set_scalar("skills", "creation_nudge_interval", "0")
set_scalar("agent", "clarify_timeout", "0")
set_scalar("curator", "enabled", "false")

# skills.external_dirs is a list: append the brain if not already present.
s = find_section("skills")
e = section_end(s)
has_brain = any(("- " in l) and (skills_dir in l) for l in lines[s:e])
k = key_in_section(s, e, "external_dirs")
if k < 0:
    lines.insert(e, "  external_dirs:")
    lines.insert(e + 1, "    - " + skills_dir)
elif not has_brain:
    # insert under the existing key, before next same-indent line
    ins = k + 1
    while ins < e and (lines[ins].startswith("      ") or lines[ins].strip() == "" ):
        ins += 1
    lines.insert(ins, "    - " + skills_dir)

shutil.copy2(path, path + ".bak-harness-bundle")
with io.open(path, "w", encoding="utf-8") as fh:
    fh.write("\n".join(lines) + "\n")
print("OK config.yaml merged (backup at config.yaml.bak-harness-bundle)")
'@ | Out-File $mergePy -Encoding ascii

    python $mergePy $script:ConfigYaml $brainForward
    if ($LASTEXITCODE -ne 0) { throw "config.yaml merge failed" }

    Complete-Stage $state 'config'
}

# --- Stage H2: SOUL.md Operating Rules block ----------------------------------
$soulBegin = '<!-- BEGIN harness-bundle operating rules -->'
$soulEnd   = '<!-- END harness-bundle operating rules -->'

if ($Update -or -not ($state.completed -contains 'soul')) {
    Write-Info "installing SOUL.md Operating Rules block"

    if (-not (Test-Path $script:SoulMd)) {
        # Hermes seeds a default on first run; if the user wiped it, seed minimal identity.
        Set-Content -Path $script:SoulMd -Value "You are Hermes Agent, Kamal's assistant." -Encoding utf8
    }

    $rulesBlock = @"

$soulBegin
# Operating Rules (Kamal)

These apply to every session, every project, without exception. Full canonical rules live in ``C:/Users/$script:WinUser/.claude/CLAUDE.md`` and ``C:/Users/$script:WinUser/.claude/rules/*.md`` -- read_file them when working on a topic they cover.

1. **Never jump to execution without explicit confirmation.** Present the plan first; wait for approval before running code or making file changes.
2. **Ask questions first when collaborating.** Don't pre-solve. "Collaborate" means back-and-forth dialogue, not a finished deliverable.
3. **Use provided resources directly.** When given a URL/repo/path, use it -- don't search for alternatives.
4. **Download docs before installing tools.** Fetch the raw README/setup guide to disk and read it fully before configuring anything.
5. **Read before assuming.** Verify actual data (names, paths, formats) before processing it.
6. **This is a Windows machine.** Commands must be Windows-compatible (git-bash). See ``C:/Users/$script:WinUser/.claude/rules/windows-commands.md`` and ``wsl-patterns.md``.
7. **Never raise context-window concerns** or suggest deferring work because of context length.
8. **Load the tool's skill BEFORE using the tool** when that skill exists in the available-skills list -- skills carry canonical flags/gotchas that parsed help text misses. If the skill isn't listed, don't invent one.
9. **dcg blocks are checkpoints, not errors.** On any ``BLOCKED by dcg``: run ``dcg explain "<cmd>"``, check Safe Alternatives, take the safe path silently. Never improvise reworded retries; ``dcg allow-once`` is the human's call only.
10. **All design/frontend work goes through the ``impeccable`` skill first**, including "small" UI changes.
11. **No AI attribution in commits/PRs.** Commits are authored solely by Kamal.
12. **Obsidian vault ops: load ``obsidian-cli`` skill first.** Methodologies and research belong in the vault (``References/``), not in skill directories.
13. **Writing style:** plain direct English; no marketing-speak; match Kamal's voice when editing his material; simpler words beat clever ones.
14. **Enforcement-over-structure test:** before adding "must include X / never do Y", check whether an upstream structural fix makes the rule unnecessary. For runtime guardrails with no upstream layer, aggressive imperative wording IS the structure.

# Pending upstream: global AGENTS.md loading

When PR NousResearch/hermes-agent#23331 (load AGENTS.md from HERMES_HOME as global policy) merges: after ``hermes update``, move this "Operating Rules" section into ``HERMES_HOME/AGENTS.md`` instead of SOUL.md (SOUL keeps identity only), per the docs' identity-vs-policy separation. Until then SOUL.md is the only always-loaded global slot.
$soulEnd
"@

    $existing = Get-Content $script:SoulMd -Raw
    Copy-Item $script:SoulMd "$($script:SoulMd).bak-harness-bundle" -Force

    if ($existing.Contains($soulBegin) -and $existing.Contains($soulEnd)) {
        # Replace between markers (update path)
        $pre  = $existing.Substring(0, $existing.IndexOf($soulBegin))
        $post = $existing.Substring($existing.IndexOf($soulEnd) + $soulEnd.Length)
        [System.IO.File]::WriteAllText($script:SoulMd, ($pre + $rulesBlock.TrimStart() + "`n" + $post), (New-Object System.Text.UTF8Encoding $false))
        Write-Ok "SOUL.md rules block refreshed"
    } else {
        Add-Content -Path $script:SoulMd -Value $rulesBlock -Encoding utf8
        Write-Ok "SOUL.md rules block appended (backup at SOUL.md.bak-harness-bundle)"
    }

    Complete-Stage $state 'soul'
}

# --- Stage H3: bundled-skills prune (opt-in) -----------------------------------
if ($PruneBundledSkills -and -not ($state.completed -contains 'prune')) {
    Write-Info "pruning Hermes bundled builtin skills (permanent)"
    $ans = Read-Host "This runs 'hermes skills opt-out --remove --yes': deletes ALL unmodified bundled skills and stops future re-seeding. Continue? (y/N)"
    if ($ans -match '^[Yy]') {
        hermes skills opt-out --remove --yes
        Write-Ok "bundled skills removed; restore anytime with: hermes skills opt-in --sync"
        Complete-Stage $state 'prune'
    } else {
        Write-Warn2 "prune skipped by user"
    }
}

# --- Stage H4: MCP registration (agent-mail) -----------------------------------
$mcpChanged = $Update -or -not ($state.completed -contains 'mcp')
if ($mcpChanged) {
    Write-Info "registering mcp-agent-mail"

    $amCfg = Join-Path $env:USERPROFILE '.config\mcp-agent-mail\config.env'
    if (-not (Test-Path $amCfg)) {
        Write-Warn2 "Agent Mail token file not found at $amCfg - run install.ps1 Stage 5 (WSL) first, then re-run this script with -Update."
    } else {
        $tokenLine = (Select-String -Path $amCfg -Pattern '^HTTP_BEARER_TOKEN=' -ErrorAction SilentlyContinue).Line
        if (-not $tokenLine) {
            Write-Warn2 "HTTP_BEARER_TOKEN not found in $amCfg - skipping agent-mail registration."
        } else {
            $token = ($tokenLine -split '=', 2)[1].Trim()

            # Idempotent: remove then re-add with current token.
            hermes mcp remove mcp-agent-mail 2>$null | Out-Null

            # Write the mcp_servers entry directly (targeted patch) instead of
            # `hermes mcp add`: that command is interactive (auth Y/n + save y/N
            # prompts) and hangs non-interactively. Direct config write is what
            # the prompts would produce anyway, verified against a live add.
            $patchPy = Join-Path $env:TEMP 'hb-patch-hermes-mcp.py'
@'
import io, re, sys
path = sys.argv[1]; token = sys.argv[2]
with io.open(path, encoding="utf-8") as fh:
    text = fh.read()
new_block = (
    "  mcp-agent-mail:\n"
    "    url: http://127.0.0.1:8765/mcp/\n"
    "    enabled: true\n"
    "    headers:\n"
    '      Authorization: "Bearer ' + token + '"'
)
pattern = re.compile(r"( {2}mcp-agent-mail:\n(?: {4}.*\n?)*?)(?=\S|\Z)")
if "  mcp-agent-mail:" in text:
    text = pattern.sub(new_block + "\n\n", text, count=1)
else:
    text = text.rstrip("\n") + "\nmcp_servers:\n" + new_block + "\n"
with io.open(path, "w", encoding="utf-8") as fh:
    fh.write(text)
print("OK mcp-agent-mail patched (enabled + auth header)")
'@ | Out-File $patchPy -Encoding ascii
            python $patchPy $script:ConfigYaml $token
            if ($LASTEXITCODE -eq 0) {
                Write-Ok "mcp-agent-mail registered at 127.0.0.1:8765 (never localhost -- IPv6 blackhole)"
            } else {
                Write-Warn2 "config patch failed; register manually:"
                Write-Host "  hermes mcp add mcp-agent-mail --url http://127.0.0.1:8765/mcp/"
            }
        }
        Complete-Stage $state 'mcp'
    }
}

# --- Summary -------------------------------------------------------------------
Write-Host ""
Write-Host ("=" * 60)
Write-Host " Hermes adapter - install summary" -ForegroundColor Cyan
Write-Host ("=" * 60)
foreach ($stage in @('config', 'soul', 'prune', 'mcp')) {
    if ($state.completed -contains $stage) {
        Write-Ok "  $stage"
    } elseif ($stage -eq 'prune' -and -not $PruneBundledSkills) {
        Write-Host "  prune   (skipped: pass -PruneBundledSkills to enable)" -ForegroundColor DarkGray
    } else {
        Write-Warn2 "  $stage NOT completed - re-run with -Update to retry"
    }
}
Write-Host ""
Write-Host "  Brain: $($script:ClaudeHome)\skills -> skills.external_dirs (read-only)"
Write-Host "  Rules: SOUL.md operating-rules block (+ pending-upstream note inside)"
Write-Host "  Restart any running hermes session to pick up changes."
Write-Host ""
Write-Host "  Verify: bash install/smoke-test-hermes.sh"
Write-Host "  Revert: install\uninstall.ps1 (section 1b) or the .bak-harness-bundle files"

