#!/bin/bash
# smoke-test-codex.sh
# Verifies the Codex flavor of the harness on Windows (Git Bash).

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
CODEX_HOME="$WINHOME/.codex"

echo
echo -e "${B}Codex flavor smoke test${N}"
echo -e "${D}$(date -Iseconds)  user=$WINUSER${N}"

hdr "PHASE 1 — Codex CLI"
if command -v codex >/dev/null 2>&1; then
  pass "codex on PATH"
  VER=$(codex --version 2>&1 | head -1)
  echo "$VER" | grep -qiE 'codex|[0-9]+\.[0-9]+' && pass "codex reports version ($VER)" || skip "codex reports version" "$VER"
else
  fail "codex on PATH" "install official CLI: npm install -g @openai/codex"
fi

hdr "PHASE 2 — Codex harness files"
for p in \
  "$CODEX_HOME/hooks.json" \
  "$CODEX_HOME/hooks/trauma_guard.py" \
  "$CODEX_HOME/hooks/post-compact-reminder.py" \
  "$CODEX_HOME/AGENTS.md" \
  "$CODEX_HOME/rules/codex-flavor.md" \
  "$CODEX_HOME/config.toml"
do
  test -f "$p" && pass "$(basename "$p") present" || fail "$(basename "$p") present" "missing $p"
done

if test -d "$CODEX_HOME/skills" && ls -d "$CODEX_HOME/skills"/*/ >/dev/null 2>&1; then
  pass "~/.codex/skills has skill directories"
elif test -d "$WINHOME/.agents/skills" && ls -d "$WINHOME/.agents/skills"/*/ >/dev/null 2>&1; then
  pass "~/.agents/skills has skill directories (Codex scans this)"
else
  fail "skills payload" "no skill directories under ~/.codex/skills or ~/.agents/skills"
fi

hdr "PHASE 3 — flywheel CLIs"
assert_win_pe() {
  local path="$1" name="$2"
  if [ ! -f "$path" ]; then fail "Win: $name on disk" "not found at $path"; return; fi
  python -c "import sys; b=open(sys.argv[1],'rb').read(2); sys.exit(0 if b==b'MZ' else 1)" "$path" \
    && pass "Win: $name is a Windows PE" \
    || fail "Win: $name is a Windows PE" "file exists but is not a PE (wrong release asset)"
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

hdr "PHASE 5 — MCP list"
if command -v codex >/dev/null 2>&1; then
  MCPLIST=$(codex mcp list 2>&1)
  echo "$MCPLIST" | grep -qi 'playwright' && pass "mcp list has playwright" || skip "mcp list has playwright" "run install/mcp-register-codex.ps1"
else
  skip "mcp list" "no codex"
fi

echo
echo -e "${B}Result${N}  pass=$PASS  fail=$FAIL  skip=$SKIP"
if [ "$FAIL" -gt 0 ]; then
  echo -e "${R}Failed:${N}"
  for t in "${FAILED_TESTS[@]}"; do echo "  - $t"; done
  exit 1
fi
exit 0
