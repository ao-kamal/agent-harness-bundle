#!/bin/bash
# smoke-test-antigravity.sh
# Verifies the Antigravity flavor of the harness on Windows (Git Bash).

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
AGY_HOME="$WINHOME/.gemini/antigravity-cli"
AGY_WIN="$LOCALAPPDATA/agy/bin/agy.exe"
if [ -z "$LOCALAPPDATA" ]; then AGY_WIN="$WINHOME/AppData/Local/agy/bin/agy.exe"; fi

echo
echo -e "${B}Antigravity flavor smoke test${N}"
echo -e "${D}$(date -Iseconds)  user=$WINUSER${N}"

hdr "PHASE 1 — Antigravity CLI"
if command -v agy >/dev/null 2>&1; then
  pass "agy on PATH"
elif test -f "$AGY_WIN"; then
  pass "agy.exe on disk"
else
  fail "agy present" "install official CLI: irm https://antigravity.google/cli/install.ps1 | iex"
fi

hdr "PHASE 2 — Antigravity harness files"
for p in \
  "$AGY_HOME/plugins/harness-bundle/plugin.json" \
  "$AGY_HOME/plugins/harness-bundle/hooks.json" \
  "$AGY_HOME/plugins/harness-bundle/trauma_guard.py" \
  "$AGY_HOME/rules/antigravity-flavor.md" \
  "$AGY_HOME/settings.json"
do
  test -f "$p" && pass "$(basename "$(dirname "$p")")/$(basename "$p") present" || fail "$(basename "$p") present" "missing $p"
done

if test -d "$AGY_HOME/skills" && ls -d "$AGY_HOME/skills"/*/ >/dev/null 2>&1; then
  pass "~/.gemini/antigravity-cli/skills has skill directories"
elif test -d "$WINHOME/.agents/skills" && ls -d "$WINHOME/.agents/skills"/*/ >/dev/null 2>&1; then
  pass "~/.agents/skills has skill directories"
else
  fail "skills payload" "no skill directories under antigravity-cli/skills or ~/.agents/skills"
fi

test -f "$WINHOME/.gemini/config/mcp_config.json" && pass "mcp_config.json present" || skip "mcp_config.json present" "run install/mcp-register-antigravity.ps1"

hdr "PHASE 3 — flywheel CLIs"
assert_win_pe() {
  local path="$1" name="$2"
  if [ ! -f "$path" ]; then fail "Win: $name on disk" "not found at $path"; return; fi
  python -c "import sys; b=open(sys.argv[1],'rb').read(2); sys.exit(0 if b==b'MZ' else 1)" "$path" \
    && pass "Win: $name is a Windows PE" \
    || fail "Win: $name is a Windows PE" "file exists but is not a PE"
}
assert_win_pe "$WINHOME/.local/bin/dcg.exe" "dcg.exe"
assert_win_pe "$WINHOME/.local/bin/cass.exe" "cass.exe"
assert_win_pe "$WINHOME/.local/bin/br.exe" "br.exe"
assert_win_pe "$WINHOME/.local/bin/cm.exe" "cm.exe"

hdr "PHASE 4 — Agent Mail (optional)"
HEALTH=$(curl.exe -s --max-time 5 http://127.0.0.1:8765/health 2>&1)
case "$HEALTH" in
  *'"status":"ready"'*) pass "Agent Mail healthy at 127.0.0.1:8765" ;;
  *) skip "Agent Mail healthy" "WSL boot hook not up or flavor installed without WSL stage" ;;
esac

echo
echo -e "${B}Result${N}  pass=$PASS  fail=$FAIL  skip=$SKIP"
if [ "$FAIL" -gt 0 ]; then
  echo -e "${R}Failed:${N}"
  for t in "${FAILED_TESTS[@]}"; do echo "  - $t"; done
  exit 1
fi
exit 0
