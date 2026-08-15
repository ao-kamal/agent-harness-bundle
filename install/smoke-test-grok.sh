#!/bin/bash
# smoke-test-grok.sh
# Verifies the Grok flavor of the harness on Windows (Git Bash).
# Flywheel / WSL checks are SKIP not FAIL when those stages were not installed.

WINUSER="${USERNAME:-$(powershell.exe -NoProfile -Command 'Write-Host -NoNewline $env:USERNAME' 2>/dev/null | tr -d '\r')}"

set +e
PASS=0; FAIL=0; SKIP=0
declare -a FAILED_TESTS

G='\033[0;32m'; R='\033[0;31m'; Y='\033[0;33m'; D='\033[2m'; B='\033[1m'; N='\033[0m'

pass() { echo -e "  ${G}OK${N} $1"; PASS=$((PASS+1)); }
fail() { echo -e "  ${R}FAIL${N} $1${2:+: ${D}$2${N}}"; FAILED_TESTS+=("$1"); FAIL=$((FAIL+1)); }
skip() { echo -e "  ${Y}SKIP${N} $1 ${D}($2)${N}"; SKIP=$((SKIP+1)); }
hdr()  { echo; echo -e "${B}=== $1 ===${N}"; }

WINHOME="C:/Users/$WINUSER"
GROK_HOME="$WINHOME/.grok"
GROK_BIN="$GROK_HOME/bin/grok.exe"

echo
echo -e "${B}Grok flavor smoke test${N}"
echo -e "${D}$(date -Iseconds)  user=$WINUSER${N}"

hdr "PHASE 1 — Grok CLI"
if test -f "$GROK_BIN"; then
  pass "grok.exe on disk"
  VER=$("$GROK_BIN" --version 2>&1 | head -1)
  echo "$VER" | grep -qi grok && pass "grok reports version ($VER)" || fail "grok reports version" "$VER"
else
  fail "grok.exe on disk" "not found at $GROK_BIN"
fi

hdr "PHASE 2 — Grok harness files"
for p in \
  "$GROK_HOME/hooks/harness.json" \
  "$GROK_HOME/hooks/trauma_guard.py" \
  "$GROK_HOME/hooks/post-compact-reminder.py" \
  "$GROK_HOME/agents/deep-researcher.md" \
  "$GROK_HOME/rules/grok-flavor.md" \
  "$GROK_HOME/rules/mcp-and-services.md"
do
  test -f "$p" && pass "$(basename "$p") present" || fail "$(basename "$p") present" "missing $p"
done

if test -d "$GROK_HOME/skills" && ls -d "$GROK_HOME/skills"/*/ >/dev/null 2>&1; then
  pass "~/.grok/skills has skill directories"
elif test -d "$WINHOME/.agents/skills" && ls -d "$WINHOME/.agents/skills"/*/ >/dev/null 2>&1; then
  pass "~/.agents/skills has skill directories (Grok scans this)"
else
  fail "skills payload" "no skill directories under ~/.grok/skills or ~/.agents/skills"
fi

test -f "$WINHOME/AGENTS.md" -o -f "$WINHOME/Agents.md" && pass "home AGENTS.md present" || fail "home AGENTS.md present"

hdr "PHASE 3 — grok inspect"
if test -f "$GROK_BIN"; then
  INSPECT=$("$GROK_BIN" inspect 2>&1)
  echo "$INSPECT" | grep -qi 'deep-researcher' && pass "inspect sees deep-researcher" || fail "inspect sees deep-researcher"
  echo "$INSPECT" | grep -qi 'trauma_guard\|harness.json\|Hooks' && pass "inspect mentions hooks" || skip "inspect mentions hooks" "wording may differ; check grok inspect by hand"
else
  skip "grok inspect" "no grok.exe"
fi

hdr "PHASE 4 — Flywheel CLIs"
assert_win_pe() {
  local path="$1" name="$2"
  if [ ! -f "$path" ]; then fail "Win: $name on disk" "not found at $path"; return; fi
  # MZ header — rejects a Linux br/cm that was renamed .exe
  python -c "import sys; b=open(sys.argv[1],'rb').read(2); sys.exit(0 if b==b'MZ' else 1)" "$path" \
    && pass "Win: $name is a Windows PE" \
    || fail "Win: $name is a Windows PE" "file exists but is not a PE (wrong release asset)"
}
assert_win_pe "$WINHOME/.local/bin/dcg.exe" "dcg.exe"
assert_win_pe "$WINHOME/.local/bin/cass.exe" "cass.exe"
assert_win_pe "$WINHOME/.local/bin/br.exe" "br.exe"
assert_win_pe "$WINHOME/.local/bin/cm.exe" "cm.exe"
if test -f "$WINHOME/scoop/shims/bv.exe"; then pass "Win: bv on disk"
else fail "Win: bv on disk" "scoop shim missing"; fi
if test -f "$WINHOME/scoop/shims/caam.exe"; then pass "Win: caam on disk"
else fail "Win: caam on disk" "scoop shim missing"; fi
if test -f "$WINHOME/scoop/shims/slb.exe"; then pass "Win: slb on disk"
else fail "Win: slb on disk" "scoop shim missing"; fi

hdr "PHASE 5 — Agent Mail (optional)"
HEALTH=$(curl.exe -s --max-time 5 http://127.0.0.1:8765/health 2>&1)
case "$HEALTH" in
  *'"status":"ready"'*) pass "Agent Mail healthy at 127.0.0.1:8765" ;;
  *) skip "Agent Mail healthy" "WSL boot hook not up or flavor installed without WSL stage" ;;
esac

hdr "PHASE 6 — MCP list"
if test -f "$GROK_BIN"; then
  MCPLIST=$("$GROK_BIN" mcp list 2>&1)
  echo "$MCPLIST" | grep -qi 'playwright' && pass "mcp list has playwright" || skip "mcp list has playwright" "run install/mcp-register-grok.ps1"
else
  skip "mcp list" "no grok.exe"
fi

echo
echo -e "${B}Result${N}  pass=$PASS  fail=$FAIL  skip=$SKIP"
if [ "$FAIL" -gt 0 ]; then
  echo -e "${R}Failed:${N}"
  for t in "${FAILED_TESTS[@]}"; do echo "  - $t"; done
  exit 1
fi
exit 0
