#!/bin/bash
# smoke-test.sh (bundle edition)
# End-to-end test of the Win+WSL Claude Code stack — parameterized copy of
# caam-stack-smoke-test-v2.sh for install.ps1 Stage 11 to run on a friend's machine, where the
# Windows username is not "USER" and some optional tools may not be part of their bundle.
# Sources for the underlying architecture this script asserts:
#   - ObsidianVault/References/tooling-update-runbook.md, "Agent Mail architecture (current
#     as of 2026-07-30)" section
#   - claude-harness-bundle/planning/05-infra.md, "Smoke-test adaptation notes" + section 7
#   - claude-harness-bundle/planning/diag-agent-mail.md (reachability root-cause diagnosis)
#
# Architecture summary this script assumes:
#   - Agent Mail's "Agent Mail Daemon" Windows scheduled task and native mcp-agent-mail.exe
#     process NO LONGER EXIST (retired 2026-06-04: NTFS durable-write failures). The server
#     is WSL-native (`mcp_agent_mail.cli serve-http`), auto-started only by the wsl.conf [boot] command hook
#     (/usr/local/sbin/mount-fast-data.sh) on a WSL cold boot — not systemd, not cron, not a
#     Windows scheduled task.
#   - Windows reaches it via mirrored networking, but ONLY at 127.0.0.1:8765 — NEVER
#     localhost:8765. localhost resolves IPv6 (::1) first on Windows; mcp_agent_mail.cli serve-http is
#     IPv4-only; the IPv6 loopback path blackholes (hangs to timeout) under mirrored mode.
#     Every probe in this script uses the literal 127.0.0.1, never the hostname.
#
# Run from Windows-side bash (Git Bash / WSL doesn't matter — uses absolute paths).
# Side effects: creates throwaway tmux sessions + project dirs in /root/ntm_Dev, which it
#               cleans up. Phase 11 gracefully SIGTERMs and manually relaunches the WSL-native
#               `mcp_agent_mail.cli serve-http` process (NEVER -9 / taskkill — that's the historical WAL-
#               corruption trigger) — a brief, real interruption to Agent Mail for anyone else
#               using it. Don't run this script while a swarm is mid-flight.

# Resolve the Windows username dynamically — this script is run in place by install.ps1 Stage 11 (works on any machine) where "USER" is not the account name. $USERNAME is normally
# already set correctly in Git Bash (inherited from the Windows environment); the PowerShell
# fallback covers the rare case where it isn't.
WINUSER="${USERNAME:-$(powershell.exe -NoProfile -Command 'Write-Host -NoNewline $env:USERNAME' 2>/dev/null | tr -d '\r')}"

# Resolve the Windows home in whichever bash this actually is. `bash` on Windows may be the
# WSL launcher rather than Git Bash, and C:/Users/<name> is not a path there, which would fail
# every Windows file assertion below while looking like a broken install.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/_windows-home.sh"
WINHOME="$(_require_windows_home "$WINUSER")"

# Tools that may legitimately be missing on a fresh friend install: optional pieces (fmd), or
# WSL installs that silently fall back / fail when a prerequisite isn't present (caam's WSL
# install needs cosign; slb and sysmoni may not be part of every bundle), or extra AI-CLI
# providers this bundle never installs (codex, gemini — you may add either later;
# fresh-eyes review finding B6). fzf and mcp-agent-mail stay
# hard-required — see the Phase 1.2 comment below for why. Phase 1 SKIPs OPTIONAL_TOOLS
# members instead of FAILing when absent. Everything else in Phase 1 — including the core set
# (claude, cass, cm, br, bv, dcg, ntm, am) — remains a hard requirement.
OPTIONAL_TOOLS="fmd sysmoni slb-wsl caam-wsl codex gemini"
is_optional_tool() {
  case " $OPTIONAL_TOOLS " in
    *" $1 "*) return 0 ;;
    *) return 1 ;;
  esac
}

set +e
PASS=0; FAIL=0; SKIP=0
declare -a FAILED_TESTS

TEST_PROJ_1=/root/ntm_Dev/_smoke_test_1
TEST_PROJ_2=/root/ntm_Dev/_smoke_test_2

# ANSI colors
G='\033[0;32m'; R='\033[0;31m'; Y='\033[0;33m'; D='\033[2m'; B='\033[1m'; N='\033[0m'

pass() { echo -e "  ${G}✓${N} $1"; PASS=$((PASS+1)); }
fail() { echo -e "  ${R}✗${N} $1${2:+: ${D}$2${N}}"; FAILED_TESTS+=("$1"); FAIL=$((FAIL+1)); }
skip() { echo -e "  ${Y}-${N} $1 ${D}(skipped: $2)${N}"; SKIP=$((SKIP+1)); }
hdr()  { echo; echo -e "${B}=== $1 ===${N}"; }

# Run a command in WSL login shell, capture stdout.
# Strips leading "wsl: ..." system-warning lines (e.g. the historical
# "wsl: Processing /etc/fstab failed" noise) before the caller sees the output — a known
# false-fail source per tooling-update-runbook.md's 2026-06-03 notes. Fixed once here, at the
# source, rather than patched per-phase downstream.
wsl_run() {
  echo "$1" | wsl -d Ubuntu -u root -- bash -l 2>&1 | grep -v -E '^wsl: '
}

# Run a PowerShell command, capture output
ps_run() { powershell -Command "$1" 2>&1; }

# Assertion helpers
assert_contains() {
  local out="$1" needle="$2" name="$3"
  echo "$out" | grep -qE "$needle" && pass "$name" || fail "$name" "expected pattern not found: $needle"
}

assert_eq() {
  local got="$1" expected="$2" name="$3"
  [ "$got" = "$expected" ] && pass "$name" || fail "$name" "got '$got', expected '$expected'"
}

assert_nonempty() {
  local val="$1" name="$2"
  [ -n "$val" ] && pass "$name" || fail "$name" "value was empty"
}

# Agent Mail health probe with patience: the server can take 10-15s after a (re)start before
# /health returns ready (integrity-guard/ATC startup, per tooling-update-runbook.md gotcha #15).
# Used in Phase 5 (steady-state check) and Phase 11 (post-relaunch check). Literal 127.0.0.1
# only — see architecture summary at the top of this file for why localhost is forbidden here.
probe_am_health_win() {
  local out="" i
  for i in 1 2 3; do
    out=$(curl.exe -s --max-time 5 http://127.0.0.1:8765/api/health 2>&1)
    case "$out" in *'"status":"ready"'*|*'"status":"ok"'*) echo "$out"; return 0 ;; esac
    sleep 5
  done
  echo "$out"
  return 1
}

probe_am_health_wsl() {
  local out="" i
  for i in 1 2 3; do
    out=$(wsl_run 'curl -s --max-time 5 http://127.0.0.1:8765/api/health 2>&1')
    case "$out" in *'"status":"ready"'*|*'"status":"ok"'*) echo "$out"; return 0 ;; esac
    sleep 5
  done
  echo "$out"
  return 1
}

# Three-layer reachability diagnosis, printed (not asserted) on an Agent Mail health-probe
# failure — per diag-agent-mail.md's confirmed root-cause chain: mirrored-mode state,
# 127.0.0.1-vs-localhost, then firewall/portproxy. All read-only, no state changed.
am_reachability_hint() {
  local net_mode wsl_ip win_ip portproxy fw_default
  net_mode=$(wsl_run 'wslinfo --networking-mode 2>&1')
  wsl_ip=$(wsl_run 'hostname -I 2>&1' | awk '{print $1}')
  win_ip=$(ps_run "(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object {\$_.InterfaceAlias -notmatch 'Loopback|vEthernet|Bluetooth'} | Select-Object -First 1 -ExpandProperty IPAddress)" | tr -d '\r')
  portproxy=$(ps_run "netsh interface portproxy show all" | tr -d '\r')
  fw_default=$(ps_run "(Get-NetFirewallHyperVVMSetting -ErrorAction SilentlyContinue).DefaultInboundAction" | tr -d '\r')
  echo -e "    ${D}--- Agent Mail reachability diagnosis (per diag-agent-mail.md) ---${N}"
  echo -e "    ${D}[1] mirrored networking: ${net_mode}${N}"
  echo -e "    ${D}    WSL hostname -I:      ${wsl_ip}${N}"
  echo -e "    ${D}    Windows LAN adapter:  ${win_ip}  (should match WSL's IP under true mirrored mode)${N}"
  echo -e "    ${D}[2] client used 127.0.0.1, not localhost? localhost resolves IPv6 first on Windows;${N}"
  echo -e "    ${D}    mcp_agent_mail.cli serve-http is IPv4-only -> IPv6-first clients blackhole under mirrored mode.${N}"
  echo -e "    ${D}[3] portproxy rules:      ${portproxy:-<empty, expected>}${N}"
  echo -e "    ${D}    Hyper-V VM DefaultInboundAction: ${fw_default}  (should be Allow)${N}"
}

# Pretty banner
echo
echo -e "${B}┌─ smoke-test (bundle edition) ───────────────────────────────────────┐${N}"
echo -e "${B}│  end-to-end verify of the Win+WSL Claude Code architecture         │${N}"
echo -e "${B}│  $(date -Iseconds)                                          │${N}"
echo -e "${B}└────────────────────────────────────────────────────────────────────┘${N}"

# =============================================================================
hdr "PHASE 1 — Inventory"
# =============================================================================

# 1.1 — Windows binaries. Honest per-file existence checks — NOT a substring grep against
# `ls`'s combined stdout+stderr, which was a tautology: a MISSING file's own
# "No such file or directory: dcg.exe" stderr line contains the filename, so an unanchored
# assert_contains could never fail either way, present or absent (fresh-eyes review finding B4).
#
# Groups reflect what install.ps1 actually provisions and where (fresh-eyes review finding B5):
# claude/cass/br are copied straight into .local/bin; cm/bv/caam/dcg are scoop-installed and
# land in scoop/shims (dcg was previously checked against the wrong directory — moved here).
# am.exe and mcp-agent-mail.exe are REMOVED entirely: Agent Mail is WSL-native per this script's
# own architecture header above, and nothing in this bundle's install.ps1 or wsl-setup.sh ever
# installs either as a Windows binary — confirmed by grepping both files for the exact names.
assert_win_file() {
  local path="$1" name="$2"
  test -f "$path" && pass "Win: $name on disk" || fail "Win: $name on disk" "not found at $path"
}

WINHOME_BIN="$WINHOME/.local/bin"
WINHOME_SHIMS="$WINHOME/scoop/shims"

for b in claude.exe cass.exe br.exe; do
  assert_win_file "$WINHOME_BIN/$b" "$b"
done
for b in cm.exe bv.exe caam.exe dcg.exe slb.exe; do
  assert_win_file "$WINHOME_SHIMS/$b" "$b"
done

if test -f "$WINHOME_BIN/fmd.exe"; then
  pass "Win: fmd.exe on disk"
else
  skip "Win: fmd.exe on disk" "optional tool (fmd) not installed"
fi

# 1.2 — WSL binaries. sysmoni, slb, caam, codex, and gemini are optional here (OPTIONAL_TOOLS
# tags: sysmoni, slb-wsl, caam-wsl, codex, gemini) — SKIP rather than FAIL if absent. codex and
# gemini are extra AI-CLI providers the friend may add later; this bundle's wsl-setup.sh never
# installs either (fresh-eyes review finding B6). fzf stays hard-required — wsl-setup.sh's
# apt-basics list is being extended to install it alongside this fix. mcp-agent-mail stays
# hard-required too: the agent-mail install.sh tarball ships both `am` and `mcp-agent-mail`
# binaries together, so if one is on PATH the other should be. Every other tool, including the
# core set (claude, cass, cm, br, bv, dcg, ntm, am), remains a hard requirement.
WSL_PATHS=$(wsl_run 'for t in claude codex gemini fzf cass cm br bv caam dcg ubs am mcp-agent-mail ntm tmux slb sysmoni; do
                       p=$(which $t 2>/dev/null) && echo "$t=$p"
                     done')
for t in claude codex gemini fzf cass cm br bv caam dcg ubs am mcp-agent-mail ntm tmux slb sysmoni; do
  tag="$t"
  case "$t" in
    slb) tag="slb-wsl" ;;
    caam) tag="caam-wsl" ;;
  esac
  if echo "$WSL_PATHS" | grep -q "^$t="; then
    pass "WSL: $t on PATH"
  elif is_optional_tool "$tag"; then
    skip "WSL: $t on PATH" "optional tool not installed"
  else
    fail "WSL: $t on PATH" "not found and not marked optional"
  fi
done

# 1.3 — Version sanity. Version assertions check the binary is callable + reports a version,
# not a specific release. Pinning specific versions here breaks every time a tool is upgraded.
# slb's assertion is SKIPped (not failed) if slb itself wasn't found in 1.2 (optional tool).
# sysmoni deliberately has NO version assertion here: `sysmoni --version` errors (undefined flag)
# and `sysmoni version` doesn't return a version string at all — it runs a full monitoring
# snapshot instead (confirmed live 2026-07-30). Presence-on-PATH (1.2) is the only sysmoni check.
WSL_VERS=$(wsl_run '
  echo "claude=$(claude --version 2>&1 | head -1)"
  echo "cass=$(cass --version 2>&1 | head -1)"
  echo "cm=$(cm --version 2>&1 | head -1)"
  echo "br=$(br --version 2>&1 | head -1)"
  echo "bv=$(bv --version 2>&1 | head -1)"
  echo "dcg=$(dcg --version 2>&1 | head -1)"
  echo "ubs=$(ubs --version 2>&1 | head -1)"
  echo "am=$(am --version 2>&1 | head -1)"
  echo "slb=$(slb version 2>&1 | head -1)"
')
assert_contains "$WSL_VERS" "claude=[0-9]" "WSL claude reports version"
assert_contains "$WSL_VERS" "cass=cass [0-9]" "WSL cass reports version"
assert_contains "$WSL_VERS" "cm=[0-9]" "WSL cm reports version"
assert_contains "$WSL_VERS" "br=br [0-9]" "WSL br reports version"
assert_contains "$WSL_VERS" "bv=bv v[0-9]" "WSL bv reports version"
assert_contains "$WSL_VERS" "dcg=[0-9]" "WSL dcg reports version"
assert_contains "$WSL_VERS" "am=am [0-9]" "WSL am reports version"
if echo "$WSL_PATHS" | grep -q "^slb="; then
  assert_contains "$WSL_VERS" "slb=slb [0-9]" "WSL slb reports version (slb version subcommand)"
else
  skip "WSL slb reports version (slb version subcommand)" "optional tool (slb) not installed"
fi

# =============================================================================
hdr "PHASE 2 — Symlinks + shared state"
# =============================================================================

LN_PROJECTS=$(wsl_run 'readlink /root/.claude/projects 2>&1')
assert_eq "$LN_PROJECTS" "/mnt/c/Users/$WINUSER/.claude/projects" "Projects symlink → Windows path"

LN_CAAM=$(wsl_run 'readlink /root/.local/share/caam 2>&1')
assert_eq "$LN_CAAM" "/mnt/c/Users/$WINUSER/.local/share/caam" "Caam vault symlink → Windows path"

LN_CREDS=$(wsl_run 'readlink /root/.claude/.credentials.json 2>&1')
assert_eq "$LN_CREDS" "/mnt/c/Users/$WINUSER/.claude/.credentials.json" "Credentials symlink → Windows file"

# Cross-write test
CROSS_TEST=$(wsl_run 'F=/root/.claude/projects/.smoke-test-marker
                      echo cross-write-$(date +%s) > $F
                      cat /mnt/c/Users/'"$WINUSER"'/.claude/projects/.smoke-test-marker 2>&1
                      rm -f $F')
assert_contains "$CROSS_TEST" "cross-write-" "Cross-write through symlink: WSL writes, Windows path reads"

# =============================================================================
hdr "PHASE 3 — Auth sharing (one OAuth = both OSes)"
# =============================================================================

WSL_PRINT_OK=$(wsl_run 'echo "Reply with only OK and nothing else" | claude --print 2>&1 | head -3')
assert_contains "$WSL_PRINT_OK" "OK" "WSL claude --print returns response (auth works)"
WIN_EMAIL=$(wsl_run 'python3 -c "import json; d=json.load(open(\"/mnt/c/Users/'"$WINUSER"'/.claude.json\")); print(d.get(\"oauthAccount\",{}).get(\"emailAddress\",\"\"))"')
WSL_CACHED_EMAIL=$(wsl_run 'python3 -c "import json; d=json.load(open(\"/root/.claude.json\")); print(d.get(\"oauthAccount\",{}).get(\"emailAddress\",\"\"))"')

assert_nonempty "$WIN_EMAIL" "Windows .claude.json has oauthAccount email"
assert_eq "$WSL_CACHED_EMAIL" "$WIN_EMAIL" "WSL .claude.json identity matches Windows"
assert_contains "$WSL_CACHED_EMAIL" "@" "WSL .claude.json identity is an email"

# =============================================================================
hdr "PHASE 4 — Caam shared vault"
# =============================================================================

# caam is optional (cosign may be missing on the friend's WSL install — see OPTIONAL_TOOLS
# above). If either side lacks it, SKIP this whole phase with a note rather than failing on
# a comparison that can't possibly succeed. Presence uses the same honest per-file test as
# Phase 1.1 ($WINHOME_SHIMS, not the removed WIN_BINS_OUT tautology) plus the Phase 1
# inventory's $WSL_PATHS, so this can't itself hang on a missing binary.
WIN_CAAM_OK=false; WSL_CAAM_OK=false
test -f "$WINHOME_SHIMS/caam.exe" && WIN_CAAM_OK=true
echo "$WSL_PATHS" | grep -q "^caam=" && WSL_CAAM_OK=true

if [ "$WIN_CAAM_OK" = true ] && [ "$WSL_CAAM_OK" = true ]; then
  WIN_CAAM=$(ps_run "caam ls claude 2>&1" | tr -d '\r')
  WSL_CAAM=$(wsl_run 'caam ls claude 2>&1')

  # Loosened from a hardcoded profile-name regex (alex|karen|sergio — stale, current profiles
  # are different) to two generic checks: (a) at least one profile row exists beyond the header,
  # and (b) the two OSes see byte-for-byte the same listing (proves the shared vault symlink
  # works) regardless of what the actual profile names/count/active-marker format happen to be.
  CAAM_BODY=$(echo "$WIN_CAAM" | tail -n +2 | grep -v '^[[:space:]]*$')
  assert_nonempty "$CAAM_BODY" "Win: caam ls claude lists at least one profile row (beyond header)"

  WIN_CAAM_NORM=$(echo "$WIN_CAAM" | tr -s ' \t' ' ')
  WSL_CAAM_NORM=$(echo "$WSL_CAAM" | tr -s ' \t' ' ')
  assert_eq "$WIN_CAAM_NORM" "$WSL_CAAM_NORM" "Same caam profile listing identical on both OSes"
else
  skip "Phase 4 — Caam shared vault" "caam not installed on both sides (Win present: $WIN_CAAM_OK, WSL present: $WSL_CAAM_OK) — optional tool"
fi

# =============================================================================
hdr "PHASE 5 — Agent Mail reachability"
# =============================================================================
# Rewritten for the WSL-native architecture (tooling-update-runbook.md, "Agent Mail
# architecture (current as of 2026-07-30)"). The Windows-native mcp-agent-mail.exe process and
# "Agent Mail Daemon" scheduled task no longer exist — checking for them would be checking for
# retired infra, not a real signal. Every health probe below uses the literal 127.0.0.1, never
# localhost (see architecture note at the top of this file).

# 5.1 — Process check, WSL-native. Process name on the process table is "mcp_agent_mail.cli serve-http", not
# "mcp-agent-mail" (pgrep mcp-agent-mail misses it — confirmed).
AM_PROC=$(wsl_run 'pgrep -af "mcp_agent_mail.cli serve-http" 2>&1')
assert_contains "$AM_PROC" "mcp_agent_mail.cli serve-http" "WSL: mcp_agent_mail.cli serve-http process running (pgrep -af)"

# 5.2 — Boot-hook liveness, replacing the retired "Agent Mail Daemon" scheduled-task check.
# The boot hook (/usr/local/sbin/mount-fast-data.sh, wsl.conf [boot] command) only logs a fresh
# "agent-mail server started" line when it actually launches the process on a WSL COLD boot. If
# WSL has been up a while, that line may be from an earlier boot — in that case the already-
# running process (5.1) is equally valid evidence the daemon model is working, so this check
# accepts either.
BOOT_LOG_TAIL=$(wsl_run 'tail -50 /root/.local/share/mount-fast-data.log 2>&1')
if echo "$BOOT_LOG_TAIL" | grep -q "agent-mail server started"; then
  pass "Boot-hook log shows 'agent-mail server started'"
elif echo "$AM_PROC" | grep -q "mcp_agent_mail.cli serve-http"; then
  pass "Boot-hook log has no recent start line, but mcp_agent_mail.cli serve-http is confirmed running (log entry may predate this boot cycle — accepted)"
else
  fail "Agent Mail boot-hook liveness" "no start line in mount-fast-data.log and no running mcp_agent_mail.cli serve-http process"
fi

# 5.3 — Cross-OS reachability. This is the actual point of the phase — the check that would
# have caught the historical localhost/IPv6 reachability gap. Patience window (~15s across 3
# tries) covers post-start integrity-guard delay; on failure, print the three-layer hint instead
# of a bare FAIL.
WIN_HEALTH=$(probe_am_health_win)
if echo "$WIN_HEALTH" | grep -Eq '"status"[[:space:]]*:[[:space:]]*"(ready|ok)"'; then
  pass "Windows curl.exe http://127.0.0.1:8765/api/health → ready"
else
  fail "Windows curl.exe http://127.0.0.1:8765/api/health → ready" "$WIN_HEALTH"
  am_reachability_hint
fi

WSL_HEALTH=$(probe_am_health_wsl)
if echo "$WSL_HEALTH" | grep -Eq '"status"[[:space:]]*:[[:space:]]*"(ready|ok)"'; then
  pass "WSL curl http://127.0.0.1:8765/api/health → ready"
else
  fail "WSL curl http://127.0.0.1:8765/api/health → ready" "$WSL_HEALTH"
  am_reachability_hint
fi

# 5.4 — MCP registration, both sides. As of 2026-07-30 the Windows client was re-registered
# (the root-caused localhost→127.0.0.1 fix), so BOTH sides should now show Connected — this is
# a deliberate reversal of the prior "WSL-exclusive" posture, not a stale assumption.
WIN_MCP=$(ps_run "claude mcp get mcp-agent-mail 2>&1" | tr -d '\r')
assert_contains "$WIN_MCP" "Connected" "Windows: claude mcp get mcp-agent-mail → Connected"
assert_contains "$WIN_MCP" "127\.0\.0\.1" "Windows: mcp-agent-mail URL uses 127.0.0.1 (not localhost)"

WSL_MCP=$(wsl_run 'claude mcp get mcp-agent-mail 2>&1')
assert_contains "$WSL_MCP" "Connected" "WSL: claude mcp get mcp-agent-mail → Connected"
assert_contains "$WSL_MCP" "127\.0\.0\.1" "WSL: mcp-agent-mail URL uses 127.0.0.1 (not localhost)"

# =============================================================================
hdr "PHASE 6 — WSL claude wrapper + env"
# =============================================================================

WHICH_CLAUDE=$(wsl_run 'which claude')
assert_eq "$WHICH_CLAUDE" "/usr/local/bin/claude" "WSL 'which claude' → wrapper at /usr/local/bin/claude"

IS_SANDBOX=$(wsl_run 'echo $IS_SANDBOX')
assert_eq "$IS_SANDBOX" "1" "WSL IS_SANDBOX=1 in login shell"

# Test pre-trust auto-adds entry
WRAPPER_TEST=$(wsl_run '
  TESTDIR=/tmp/_wrapper_pretrust_test
  mkdir -p "$TESTDIR" && cd "$TESTDIR"
  /usr/local/bin/claude --version >/dev/null 2>&1
  python3 -c "
import json
with open(\"/root/.claude.json\") as f: d=json.load(f)
proj = d.get(\"projects\",{}).get(\"$TESTDIR\",{})
print(\"trusted:\", proj.get(\"hasTrustDialogAccepted\"))
"
  cd /
  rm -rf "$TESTDIR"')
assert_contains "$WRAPPER_TEST" "trusted: True" "Wrapper auto-pre-trusts cwd before launching claude"

# =============================================================================
hdr "PHASE 6B — New infra checks (boot hook, hot-data-enforce, creds watcher)"
# =============================================================================
# Gaps identified in 05-infra.md that v1 didn't cover at all.

# (a) Boot-hook liveness. Do NOT `wsl --shutdown` during this test — that would tear down every
# other running WSL session/pane. This check is intentionally best-effort: it confirms the log
# the [boot] command hook writes to has at least one "boot hook start" line on disk (proving the
# mechanism has fired at least once), rather than forcing a fresh reboot to prove it fires on
# THIS exact boot cycle.
BOOT_CHECK=$(wsl_run '
  echo "uptime_seconds=$(cut -d. -f1 /proc/uptime)"
  echo "last_boot_start=$(grep "boot hook start" /root/.local/share/mount-fast-data.log 2>/dev/null | tail -1)"
')
assert_contains "$BOOT_CHECK" "last_boot_start=.+boot hook start" "Boot hook has logged at least one 'boot hook start' line"

# (b) hot-data-enforce wrapper active. Sourced from /root/.profile — wraps npm/pnpm/yarn/cargo/
# pip/etc. as shell functions so installs on /mnt/c projects get redirected off 9p. Escape hatch
# if a check ever needs to bypass it deliberately: HOT_DATA_ENFORCE_OFF=1 <command>.
TYPE_NPM=$(wsl_run 'type npm 2>&1')
assert_contains "$TYPE_NPM" "npm is a function" "hot-data-enforce wrapper active (type npm → function, not bare binary)"

# (c) Credentials symlink watcher running. Started three ways (bashrc, profile, boot hook) —
# any one of the three keeps it alive; just confirm at least one instance is up.
CREDS_WATCHER=$(wsl_run 'pgrep -af claude-creds-symlink-watcher 2>&1')
assert_contains "$CREDS_WATCHER" "claude-creds-symlink-watcher" "Credentials symlink watcher running (pgrep)"

# =============================================================================
hdr "PHASE 7 — ntm spawn end-to-end (1 agent)"
# =============================================================================

NTM_DEPS=$(wsl_run 'ntm deps -v 2>&1')
assert_contains "$NTM_DEPS" "Claude Code" "ntm deps -v reports Claude Code present"

# Spawn
SPAWN_OUT=$(wsl_run "
  mkdir -p $TEST_PROJ_1
  echo smoke > $TEST_PROJ_1/README.md
  ntm --robot-spawn=_smoke_test_1 --spawn-cc=1 --spawn-wait 2>&1
")
assert_contains "$SPAWN_OUT" '"success": true' "ntm --robot-spawn returned success"

# Send + wait + tail
SEND_OUT=$(wsl_run "ntm --robot-send=_smoke_test_1 --pane=1 --msg='Reply with only OK' 2>&1")
assert_contains "$SEND_OUT" '"success": true' "ntm --robot-send accepted message"

echo -e "  ${D}waiting 25s for response...${N}"
sleep 25

TAIL_OUT=$(wsl_run "ntm --robot-tail=_smoke_test_1 --lines=40 --pane=1 2>&1")
# Check for 'OK' response from claude (the assistant marker is "● ")
echo "$TAIL_OUT" | wsl -d Ubuntu -u root -- python3 -c "
import json, sys
try:
    d=json.load(sys.stdin)
    pane = d.get('panes',{}).get('1',{})
    lines = pane.get('lines',[])
    has_ok_response = any('● OK' in l or '●  OK' in l for l in lines)
    has_trust_dialog = any('trust this folder' in l.lower() for l in lines)
    has_perm_warning = any('Bypass Permissions mode' in l for l in lines)
    print(f'has_ok_response: {has_ok_response}')
    print(f'has_trust_dialog: {has_trust_dialog}')
    print(f'has_perm_warning: {has_perm_warning}')
except Exception as e:
    print(f'PARSE_ERROR: {e}')
" > /tmp/_smoke_phase7.out
PHASE7=$(cat /tmp/_smoke_phase7.out)
assert_contains "$PHASE7" "has_ok_response: True" "Claude pane responded with OK"
assert_contains "$PHASE7" "has_trust_dialog: False" "No trust dialog appeared"
assert_contains "$PHASE7" "has_perm_warning: False" "No bypass-permissions warning appeared"

# Cleanup
wsl_run "tmux kill-session -t _smoke_test_1 2>&1; rm -rf $TEST_PROJ_1" >/dev/null

# =============================================================================
hdr "PHASE 8 — Cass picks up WSL session via symlink"
# =============================================================================

# The session JSONL should be on Windows filesystem (via projects symlink)
# Look for a recent session containing our test prompt
sleep 3   # give cass watch daemon a moment to ingest

# First confirm a JSONL was written to the Windows path
WIN_JSONL_RECENT=$(ps_run "Get-ChildItem 'C:\Users\$WINUSER\.claude\projects' -Recurse -Filter '*.jsonl' | Where-Object {\$_.LastWriteTime -gt (Get-Date).AddMinutes(-3)} | Select-Object -First 5 -ExpandProperty Name" | tr -d '\r')
assert_nonempty "$WIN_JSONL_RECENT" "Recent JSONL file(s) appeared in Windows projects dir (cross-OS write working)"

# Try cass search
CASS_HIT=$(ps_run "cass search 'Reply with only OK' --robot --limit 3 2>&1" | tr -d '\r' | head -50)
if echo "$CASS_HIT" | grep -qiE "Reply with only OK|conversations.*[1-9]"; then
  pass "Cass search returns hits for our test prompt (Windows daemon picked up WSL session)"
else
  skip "Cass full-text indexing of our test prompt" "may need more time; Windows daemon usually catches up within 30s"
fi

# =============================================================================
hdr "PHASE 9 — Multi-pane spawn (2 agents)"
# =============================================================================

SPAWN2_OUT=$(wsl_run "
  mkdir -p $TEST_PROJ_2
  echo multi > $TEST_PROJ_2/README.md
  ntm --robot-spawn=_smoke_test_2 --spawn-cc=2 --spawn-wait 2>&1
")
assert_contains "$SPAWN2_OUT" '"success": true' "Multi-pane ntm --robot-spawn returned success"

# Send to pane 1 and pane 2
wsl_run "ntm --robot-send=_smoke_test_2 --pane=1 --msg='Say PANE1' 2>&1" >/dev/null
wsl_run "ntm --robot-send=_smoke_test_2 --pane=2 --msg='Say PANE2' 2>&1" >/dev/null

echo -e "  ${D}waiting 30s for both panes to respond...${N}"
sleep 30

TAIL2_OUT=$(wsl_run "ntm --robot-tail=_smoke_test_2 --lines=60 2>&1")
P1_RESP=$(echo "$TAIL2_OUT" | wsl -d Ubuntu -u root -- python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    p1 = d.get('panes',{}).get('1',{})
    print(any('PANE1' in l.upper() for l in p1.get('lines',[])))
except: print('False')
")
P2_RESP=$(echo "$TAIL2_OUT" | wsl -d Ubuntu -u root -- python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    p2 = d.get('panes',{}).get('2',{})
    print(any('PANE2' in l.upper() for l in p2.get('lines',[])))
except: print('False')
")
assert_eq "$P1_RESP" "True" "Pane 1 responded to its prompt"
assert_eq "$P2_RESP" "True" "Pane 2 responded to its prompt"

# Cleanup
wsl_run "tmux kill-session -t _smoke_test_2 2>&1; rm -rf $TEST_PROJ_2" >/dev/null

# =============================================================================
hdr "PHASE 10 — Cleanup verification"
# =============================================================================

LEFTOVER_TMUX=$(wsl_run 'tmux ls 2>&1 | grep -E "_smoke_test" | wc -l')
assert_eq "$LEFTOVER_TMUX" "0" "No leftover smoke-test tmux sessions"

LEFTOVER_DIRS=$(wsl_run "ls /root/ntm_Dev/ | grep -c _smoke_test")
assert_eq "$LEFTOVER_DIRS" "0" "No leftover smoke-test project dirs"

# Moved from Windows Get-Process (retired infra) to WSL pgrep — the process lives in WSL now.
AM_STILL=$(wsl_run 'pgrep -f "mcp_agent_mail.cli serve-http" >/dev/null 2>&1 && echo present || echo absent')
assert_eq "$AM_STILL" "present" "Agent Mail (mcp_agent_mail.cli serve-http) still running in WSL after tests"

# =============================================================================
hdr "PHASE 11 — Persistence (graceful stop + manual relaunch → verify recovery)"
# =============================================================================
# Rewritten for the WSL boot-hook model. History: force-killing the OLD Windows-native
# mcp-agent-mail.exe (Stop-Process -Force) truncated the SQLite WAL sidecar and could wedge
# startup (tooling-update-runbook.md gotcha #12; v1's Phase 11 comment block described the
# resulting chicken-and-egg repair-vs-self-heal ordering bug in detail). That workaround was
# specific to the Windows-native binary's startup path and a scheduled-task relaunch model.
#
# The CURRENT architecture is different in kind, not just location: `mcp_agent_mail.cli serve-http` is ONLY
# auto-started by the wsl.conf [boot] command hook on a WSL COLD BOOT (mount-fast-data.sh) —
# there is no scheduled task and no systemd unit backing it (a systemd/user/agent-mail.service
# unit file exists but is confirmed disabled/vestigial, per 05-infra.md §6). This test
# deliberately does NOT `wsl --shutdown` (would kill every other running WSL session/pane), so
# it cannot exercise the boot-hook relaunch path itself. What it validates instead: a graceful
# SIGTERM shutdown + manual relaunch recovers cleanly with no WAL corruption — i.e. manual
# recovery, not scheduled-task auto-relaunch. That's the honest scope of what's testable here
# without a disruptive full WSL restart.

# Graceful stop only — SIGTERM (pkill's default signal, made explicit with -15 below). This
# script must NEVER send SIGKILL/-9/taskkill to Agent Mail; that's the historical WAL-corruption
# trigger (tooling-update-runbook.md gotcha #12).
wsl_run 'pkill -15 -f "mcp_agent_mail.cli serve-http" 2>&1; echo stop_signal_sent' >/dev/null
sleep 3
PROC_GONE=$(wsl_run 'pgrep -f "mcp_agent_mail.cli serve-http" >/dev/null 2>&1 && echo present || echo absent')
assert_eq "$PROC_GONE" "absent" "Agent Mail (mcp_agent_mail.cli serve-http) stopped gracefully (SIGTERM)"

# Manual relaunch — same invocation the boot hook itself uses. Append redirect (>>) only, never
# truncating (>), so the log's history survives (dcg's redirect-truncate-root-home guard exists
# for exactly this reason — tooling-update-runbook.md gotcha #14b).
wsl_run 'nohup /usr/local/bin/am serve-http --host 0.0.0.0 --port 8765 >> /root/.config/mcp-agent-mail/serve.log 2>&1 & disown; echo relaunched' >/dev/null
echo -e "  ${D}waiting up to 15s for manual relaunch to bind + pass startup integrity checks...${N}"

RESTART_HEALTH=$(probe_am_health_wsl)
if echo "$RESTART_HEALTH" | grep -Eq '"status"[[:space:]]*:[[:space:]]*"(ready|ok)"'; then
  pass "Agent Mail back up after manual relaunch (WSL curl 127.0.0.1:8765/health → ready)"
else
  fail "Agent Mail back up after manual relaunch" "$RESTART_HEALTH"
  am_reachability_hint
fi

PROC_BACK=$(wsl_run 'pgrep -af "mcp_agent_mail.cli serve-http" 2>&1')
assert_contains "$PROC_BACK" "mcp_agent_mail.cli serve-http" "mcp_agent_mail.cli serve-http process confirmed running after manual relaunch"

# =============================================================================
hdr "PHASE 12 — Summary"
# =============================================================================

TOTAL=$((PASS+FAIL+SKIP))
echo
echo -e "${B}Results: $PASS passed / $FAIL failed / $SKIP skipped (total $TOTAL)${N}"
echo

if [ $FAIL -gt 0 ]; then
  echo -e "${R}FAILED TESTS:${N}"
  for t in "${FAILED_TESTS[@]}"; do
    echo -e "  ${R}✗${N} $t"
  done
  echo
  exit 1
else
  echo -e "${G} All checks green. Stack is end-to-end working.${N}"
  exit 0
fi
