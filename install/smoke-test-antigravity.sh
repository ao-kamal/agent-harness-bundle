#!/bin/bash
# Verifies the thin Antigravity adapter. Fail if skills were copied instead of junctioned.

WINUSER="${USERNAME:-$(powershell.exe -NoProfile -Command 'Write-Host -NoNewline $env:USERNAME' 2>/dev/null | tr -d '\r')}"
set +e
PASS=0; FAIL=0; SKIP=0
G='\033[0;32m'; R='\033[0;31m'; Y='\033[0;33m'; B='\033[1m'; N='\033[0m'
pass() { echo -e "  ${G}OK${N} $1"; PASS=$((PASS+1)); }
fail() { echo -e "  ${R}FAIL${N} $1"; FAIL=$((FAIL+1)); }
skip() { echo -e "  ${Y}SKIP${N} $1"; SKIP=$((SKIP+1)); }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/_windows-home.sh"

WINHOME="$(_require_windows_home "$WINUSER")"
CLAUDE="$WINHOME/.claude"
AGY="$WINHOME/.gemini/antigravity-cli"

echo -e "${B}Antigravity thin-adapter smoke test${N}"

test -d "$CLAUDE/skills" && pass "~/.claude/skills exists" || fail "~/.claude/skills missing (run install.ps1)"
test -d "$AGY/skills" && pass "antigravity-cli/skills exists" || fail "antigravity-cli/skills missing (run install-antigravity.ps1)"

# A junction on Windows looks like a symlink from Git Bash
if [ -L "$AGY/skills" ] || cmd.exe /c "fsutil reparsepoint query %USERPROFILE%\\.gemini\\antigravity-cli\\skills" >/dev/null 2>&1; then
  pass "skills path is a junction/reparse (not a copy)"
else
  fail "skills path is a real directory - that is a second brain. Junction it."
fi

if [ -d "$CLAUDE/rules" ]; then
  if [ -L "$AGY/rules" ] || cmd.exe /c "fsutil reparsepoint query %USERPROFILE%\\.gemini\\antigravity-cli\\rules" >/dev/null 2>&1; then
    pass "rules path is a junction/reparse (not a copy)"
  else
    fail "rules path is a real directory - that is a second brain. Junction it."
  fi
else
  skip "rules junction (no ~/.claude/rules yet)"
fi

# Match install-antigravity.ps1's Get-AgyExe. The official installer drops the
# binary in %LOCALAPPDATA%\agy\bin and only afterwards appends that directory
# to the User PATH, so a shell opened before that registry edit cannot see it
# even though the CLI is installed. Probing `command -v` alone therefore
# reports a false SKIP on a correctly provisioned host.
AGY_CANON=""
if [ -n "${LOCALAPPDATA:-}" ] && command -v cygpath >/dev/null 2>&1; then
  AGY_CANON="$(cygpath -u "$LOCALAPPDATA")/agy/bin/agy.exe"
else
  AGY_CANON="$WINHOME/AppData/Local/agy/bin/agy.exe"
fi

if command -v agy >/dev/null 2>&1; then
  pass "agy installed and on PATH ($(command -v agy))"
elif [ -x "$AGY_CANON" ]; then
  pass "agy installed ($AGY_CANON)"
  skip "agy on PATH in this shell (restart the terminal to pick up the new User PATH)"
else
  skip "agy installed (install official CLI: irm https://antigravity.google/cli/install.ps1 | iex)"
fi

echo "pass=$PASS fail=$FAIL skip=$SKIP"
[ "$FAIL" -eq 0 ]
