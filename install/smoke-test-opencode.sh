#!/bin/bash
# smoke-test-opencode.sh
# Verifies the thin OpenCode adapter: config wiring, secret externalization,
# and that the shared brain is consumed rather than copied.
# Does NOT require a second copy of skills/rules under ~/.config/opencode.

WINUSER="${USERNAME:-$(powershell.exe -NoProfile -Command 'Write-Host -NoNewline $env:USERNAME' 2>/dev/null | tr -d '\r')}"

set +e
PASS=0; FAIL=0; SKIP=0
declare -a FAILED_TESTS

G='\033[0;32m'; R='\033[0;31m'; Y='\033[0;33m'; D='\033[2m'; B='\033[1m'; N='\033[0m'

pass() { echo -e "  ${G}OK${N} $1"; PASS=$((PASS+1)); }
fail() { echo -e "  ${R}FAIL${N} $1${2:+: ${D}$2${N}}"; FAILED_TESTS+=("$1"); FAIL=$((FAIL+1)); }
skip() { echo -e "  ${Y}SKIP${N} $1 ${D}($2)${N}"; SKIP=$((SKIP+1)); }
hdr()  { echo; echo -e "${B}=== $1 ===${N}"; }

# Resolve the Windows home in whichever bash this actually is, via the shared
# helper the other smoke tests use. `bash` on Windows may be Git Bash, where
# C:/Users/<name> is a valid path, or the WSL launcher, where only
# /mnt/c/Users/<name> is; a hardcoded form fails every file test under the other.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/_windows-home.sh"
WINHOME="$(_require_windows_home "$WINUSER")"
# uname is the reliable discriminator: Git Bash reports MINGW/MSYS, WSL reports
# Linux. WSLENV is not usable here because Git Bash inherits it from Windows.
case "$(uname -s 2>/dev/null)" in
  MINGW*|MSYS*|CYGWIN*) BASH_FLAVOR="git-bash" ;;
  Linux) BASH_FLAVOR="wsl" ;;
  *) BASH_FLAVOR="unknown" ;;
esac

CLAUDE_HOME="$WINHOME/.claude"
OC_HOME="$WINHOME/.config/opencode"
OC_CONFIG="$OC_HOME/opencode.jsonc"
BEARER="$WINHOME/.config/mcp-agent-mail/opencode-bearer"

echo
echo -e "${B}OpenCode adapter smoke test${N}"
echo -e "${D}$(date -Iseconds)  user=$WINUSER  bash=$BASH_FLAVOR  home=$WINHOME${N}"

hdr "PHASE 1 — OpenCode CLI"
if command -v opencode >/dev/null 2>&1 || test -f "$WINHOME/AppData/Roaming/npm/opencode.cmd"; then
  VER=$(opencode --version 2>/dev/null | head -1)
  echo "$VER" | grep -qiE '[0-9]+\.[0-9]+' && pass "opencode reports version ($VER)" || fail "opencode reports version" "got: $VER"
else
  fail "opencode on PATH" "run install-opencode.ps1 after installing the CLI"
fi

hdr "PHASE 2 — Shared brain (not an OpenCode copy)"
test -f "$CLAUDE_HOME/CLAUDE.md" && pass "shared CLAUDE.md" || fail "shared CLAUDE.md" "run install.ps1 first"
test -f "$CLAUDE_HOME/rules/harness-shared.md" && pass "harness-shared.md" || fail "harness-shared.md"
if test -d "$CLAUDE_HOME/skills" && ls -d "$CLAUDE_HOME/skills"/*/ >/dev/null 2>&1; then
  pass "~/.claude/skills has skill directories"
else
  fail "shared skills payload" "no skill directories under ~/.claude/skills"
fi
# A copied tree is a regression: OpenCode reads ~/.claude/skills natively.
if test -d "$OC_HOME/skills" && ls -d "$OC_HOME/skills"/*/ >/dev/null 2>&1; then
  fail "~/.config/opencode/skills should be empty" "second skills tree - delete it; OpenCode reads ~/.claude/skills"
else
  pass "no second skills tree under ~/.config/opencode"
fi
# This file replaces CLAUDE.md rather than adding to it.
if test -f "$OC_HOME/AGENTS.md"; then
  fail "~/.config/opencode/AGENTS.md present" "it replaces ~/.claude/CLAUDE.md - move it aside"
else
  pass "no AGENTS.md override in the OpenCode config dir"
fi

hdr "PHASE 3 — Config wiring"
if test -f "$OC_CONFIG"; then
  pass "opencode.jsonc present"
  grep -q 'opencode.ai/config.json' "$OC_CONFIG" && pass "config declares \$schema" || fail "config declares \$schema"
  grep -q 'rules/\*.md' "$OC_CONFIG" && pass "instructions glob reaches ~/.claude/rules" \
    || fail "instructions glob" "no rules/*.md entry; OpenCode would run with a silent instruction set"
  grep -q '"skill"' "$OC_CONFIG" && pass "skill permission declared" || skip "skill permission" "not declared"
else
  fail "opencode.jsonc present" "run install-opencode.ps1"
fi

hdr "PHASE 4 — Secret externalization"
# A bearer literal in the config is the regression this whole phase exists for.
if grep -qE 'Bearer[[:space:]]+[A-Za-z0-9._-]{20,}' "$OC_CONFIG" 2>/dev/null; then
  fail "no inline bearer in config" "a literal token is present; run install-opencode.ps1 -Update"
else
  pass "no inline bearer literal in config"
fi
if grep -q 'Bearer {file:' "$OC_CONFIG" 2>/dev/null; then
  pass "bearer referenced via {file:}"
  if test -f "$BEARER"; then
    pass "bearer file present"
    if od -An -c "$BEARER" 2>/dev/null | grep -q '\\r\|\\n'; then
      fail "bearer file has no CR/LF" "token must be usable verbatim"
    else
      pass "bearer file has no CR/LF"
    fi
  else
    skip "bearer file present" "no token provisioned; mcp-agent-mail is written disabled"
  fi
else
  skip "bearer referenced via {file:}" "no Agent Mail entry yet"
fi

hdr "PHASE 5 — MCP surface"
if command -v opencode >/dev/null 2>&1; then
  MCPLIST=$(opencode mcp list 2>&1)
  echo "$MCPLIST" | grep -q 'mcp-agent-mail' \
    && { echo "$MCPLIST" | grep -q 'connected' && pass "mcp-agent-mail connected" || skip "mcp-agent-mail connected" "server not running; WSL boot hook starts it"; } \
    || skip "mcp-agent-mail" "entry absent"
  # These were measured to time out on every connect and are not provisioned.
  for dead in playwright mcp-youtube; do
    echo "$MCPLIST" | grep -qi "$dead" && fail "$dead not provisioned" "known to time out on connect" || pass "$dead not provisioned"
  done
  echo "$MCPLIST" | grep -q 'apify' && { echo "$MCPLIST" | grep -qi 'apify.*disabled' && pass "apify disabled" || fail "apify disabled" "configured but not disabled"; } \
    || pass "apify not provisioned"
else
  skip "MCP surface" "opencode not on PATH"
fi

hdr "PHASE 6 — Agent Mail (optional)"
HEALTH=$(curl.exe -s --max-time 5 http://127.0.0.1:8765/health 2>&1)
case "$HEALTH" in
  *'"status":"ready"'*) pass "Agent Mail healthy at 127.0.0.1:8765" ;;
  *) skip "Agent Mail healthy" "WSL boot hook not up" ;;
esac

echo
echo -e "${B}Result${N}  pass=$PASS  fail=$FAIL  skip=$SKIP"
if [ "$FAIL" -gt 0 ]; then
  echo -e "${R}Failed:${N}"
  for t in "${FAILED_TESTS[@]}"; do echo "  - $t"; done
  exit 1
fi
exit 0
