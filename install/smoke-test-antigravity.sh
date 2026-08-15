#!/bin/bash
# Verifies the thin Antigravity adapter. Fail if skills were copied instead of junctioned.

WINUSER="${USERNAME:-$(powershell.exe -NoProfile -Command 'Write-Host -NoNewline $env:USERNAME' 2>/dev/null | tr -d '\r')}"
set +e
PASS=0; FAIL=0; SKIP=0
G='\033[0;32m'; R='\033[0;31m'; Y='\033[0;33m'; B='\033[1m'; N='\033[0m'
pass() { echo -e "  ${G}OK${N} $1"; PASS=$((PASS+1)); }
fail() { echo -e "  ${R}FAIL${N} $1"; FAIL=$((FAIL+1)); }
skip() { echo -e "  ${Y}SKIP${N} $1"; SKIP=$((SKIP+1)); }

WINHOME="C:/Users/$WINUSER"
CLAUDE="$WINHOME/.claude"
AGY="$WINHOME/.gemini/antigravity-cli"

echo -e "${B}Antigravity thin-adapter smoke test${N}"

test -d "$CLAUDE/skills" && pass "~/.claude/skills exists" || fail "~/.claude/skills missing (run install.ps1)"
test -d "$AGY/skills" && pass "antigravity-cli/skills exists" || fail "antigravity-cli/skills missing (run install-antigravity.ps1)"

# A junction on Windows looks like a symlink from Git Bash
if [ -L "$AGY/skills" ] || cmd.exe /c "fsutil reparsepoint query %USERPROFILE%\\.gemini\\antigravity-cli\\skills" >/dev/null 2>&1; then
  pass "skills path is a junction/reparse (not a copy)"
else
  fail "skills path is a real directory — that is a second brain. Junction it."
fi

if command -v agy >/dev/null 2>&1; then
  pass "agy on PATH"
else
  skip "agy on PATH (install official CLI)"
fi

echo "pass=$PASS fail=$FAIL skip=$SKIP"
[ "$FAIL" -eq 0 ]
