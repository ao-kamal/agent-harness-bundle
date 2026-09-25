#!/bin/bash
# smoke-test-grok.sh
# Verifies the thin Grok adapter: compat against ~/.claude, memory junction, compact hook.
# Does NOT require a second copy of skills/rules under ~/.grok.

WINUSER="${USERNAME:-$(powershell.exe -NoProfile -Command 'Write-Host -NoNewline $env:USERNAME' 2>/dev/null | tr -d '\r')}"

set +e
PASS=0; FAIL=0; SKIP=0
declare -a FAILED_TESTS

G='\033[0;32m'; R='\033[0;31m'; Y='\033[0;33m'; D='\033[2m'; B='\033[1m'; N='\033[0m'

pass() { echo -e "  ${G}OK${N} $1"; PASS=$((PASS+1)); }
fail() { echo -e "  ${R}FAIL${N} $1${2:+: ${D}$2${N}}"; FAILED_TESTS+=("$1"); FAIL=$((FAIL+1)); }
skip() { echo -e "  ${Y}SKIP${N} $1 ${D}($2)${N}"; SKIP=$((SKIP+1)); }
hdr()  { echo; echo -e "${B}=== $1 ===${N}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/_windows-home.sh"

WINHOME="$(_require_windows_home "$WINUSER")"
GROK_HOME="$WINHOME/.grok"
CLAUDE_HOME="$WINHOME/.claude"
GROK_BIN="$GROK_HOME/bin/grok.exe"

echo
echo -e "${B}Grok adapter smoke test${N}"
echo -e "${D}$(date -Iseconds)  user=$WINUSER  home=$WINHOME${N}"

hdr "PHASE 1 — Grok CLI"
if test -f "$GROK_BIN"; then
  pass "grok.exe on disk"
  VER=$("$GROK_BIN" --version 2>&1 | head -1)
  echo "$VER" | grep -qi grok && pass "grok reports version ($VER)" || fail "grok reports version" "$VER"
else
  fail "grok.exe on disk" "not found at $GROK_BIN"
fi

hdr "PHASE 2 — Shared brain (not a Grok copy)"
test -f "$CLAUDE_HOME/CLAUDE.md" && pass "shared CLAUDE.md" || fail "shared CLAUDE.md" "run install.ps1 first"
test -f "$CLAUDE_HOME/rules/harness-shared.md" && pass "harness-shared.md" || fail "harness-shared.md"
test -f "$CLAUDE_HOME/hooks/post-compact-reminder.py" && pass "shared PCR script" || fail "shared PCR script"
if test -d "$CLAUDE_HOME/skills" && ls -d "$CLAUDE_HOME/skills"/*/ >/dev/null 2>&1; then
  pass "~/.claude/skills has skill directories"
else
  fail "shared skills payload" "no skill directories under ~/.claude/skills"
fi
# The regression is a copied tree, not the mere presence of entries. A junction
# or symlink into another skills root is the sanctioned adapter pattern, and a
# skill that exists nowhere else is not a second brain. Only a real directory
# duplicating a canonical skill counts.
GROK_DUPES=0; GROK_LINKS=0; GROK_EXTRAS=""
if test -d "$GROK_HOME/skills"; then
  for entry in "$GROK_HOME/skills"/*/; do
    test -e "$entry" || continue
    name="$(basename "$entry")"
    if [ -L "${entry%/}" ]; then
      GROK_LINKS=$((GROK_LINKS+1))
    elif [ -d "$CLAUDE_HOME/skills/$name" ]; then
      GROK_DUPES=$((GROK_DUPES+1))
    else
      GROK_EXTRAS="$GROK_EXTRAS $name"
    fi
  done
fi
if [ "$GROK_DUPES" -gt 0 ]; then
  fail "~/.grok/skills has no copied skills" "$GROK_DUPES duplicate(s) of ~/.claude/skills — delete the copies"
else
  detail="no copies"
  [ "$GROK_LINKS" -gt 0 ] && detail="$detail, $GROK_LINKS link(s) ok"
  [ -n "$GROK_EXTRAS" ] && detail="$detail, non-canonical:$GROK_EXTRAS"
  pass "no copied skills under ~/.grok ($detail)"
fi

hdr "PHASE 3 — Thin adapter"
test -f "$GROK_HOME/hooks/compact.json" && pass "compact.json present" || fail "compact.json present"
test -f "$GROK_HOME/hooks/dcg.json" && pass "dcg.json present" || fail "dcg.json present"
test -f "$CLAUDE_HOME/hooks/dcg-grok-bridge.py" && pass "dcg-grok-bridge.py present" || fail "dcg-grok-bridge.py present"
if test -d "$GROK_HOME/memory/from-claude"; then
  pass "memory junction directory exists"
  if test -f "$GROK_HOME/memory/from-claude/C--Users-$WINUSER/memory/MEMORY.md" \
     || ls -d "$GROK_HOME/memory/from-claude"/*/memory >/dev/null 2>&1; then
    pass "junction reaches Claude project memory"
  else
    skip "junction reaches Claude project memory" "no project memory yet — first Claude/Grok session will create it"
  fi
else
  fail "memory junction" "missing ~/.grok/memory/from-claude"
fi
test -f "$GROK_HOME/memory/MEMORY.md" && pass "Grok MEMORY.md pointer" || fail "Grok MEMORY.md pointer"
if test -f "$GROK_HOME/config.toml"; then
  grep -q 'compat.claude' "$GROK_HOME/config.toml" && pass "config.toml pins compat.claude" || fail "config.toml pins compat.claude"
  grep -q 'enabled = true' "$GROK_HOME/config.toml" && pass "config.toml enables memory" || skip "config.toml enables memory" "enabled=true may live in another form"
else
  fail "config.toml present"
fi

hdr "PHASE 3b — dev-browser CLI (x-harvest)"
if command -v dev-browser >/dev/null 2>&1 || test -f "$WINHOME/AppData/Roaming/npm/dev-browser.cmd"; then
  DBVER=$(dev-browser --version 2>/dev/null || "$WINHOME/AppData/Roaming/npm/dev-browser.cmd" --version 2>/dev/null || true)
  echo "$DBVER" | grep -qi ergo && pass "dev-browser ergo CLI on PATH ($DBVER)" || fail "dev-browser ergo CLI" "got: $DBVER"
else
  fail "dev-browser on PATH" "skill is not enough; run install.ps1 or install-grok.ps1 (do not run install-skill)"
fi

hdr "PHASE 4 — grok inspect"
if test -f "$GROK_BIN"; then
  INSPECT=$("$GROK_BIN" inspect 2>&1)
  echo "$INSPECT" | grep -qi '\.claude' && pass "inspect mentions ~/.claude" || skip "inspect mentions ~/.claude" "wording may differ; check by hand"
  echo "$INSPECT" | grep -qi 'harness-shared\|Hooks\|hooks' && pass "inspect mentions hooks/rules" || skip "inspect mentions hooks/rules" "check grok inspect by hand"
else
  skip "grok inspect" "no grok.exe"
fi

hdr "PHASE 5 — Flywheel CLIs"
  # Resolve each CLI the way a harness would actually invoke it: by name on PATH.
  # install.ps1 provisions dcg/cm/bv/caam/slb through `scoop install`, which lands
  # them in scoop\shims, while cass/br/fmd come from installers that write
  # ~/.local/bin. Asserting one fixed directory reported four valid Windows
  # binaries as "not found". PATH first, then the legacy local bin path.
  assert_win_pe() {
    local name="$1" path py resolved
    path="$(command -v "$name" 2>/dev/null)"
    if [ -z "$path" ] && [ -f "$WINHOME/.local/bin/$name.exe" ]; then
      path="$WINHOME/.local/bin/$name.exe"
    fi
    if [ -z "$path" ] || [ ! -f "$path" ]; then
      fail "Win: $name on disk" "not on PATH and not in $WINHOME/.local/bin"
      return
    fi
    if ! py="$(_resolve_python)"; then
      fail "Win: $name is a Windows PE" "no python interpreter found (need python, python3, or py)"
      return
    fi
    "$py" -c "import sys; b=open(sys.argv[1],'rb').read(2); sys.exit(0 if b==b'MZ' else 1)" "$path" \
      && pass "Win: $name is a Windows PE ($path)" \
      || fail "Win: $name is a Windows PE" "resolved to $path but it does not start with MZ (wrong release asset?)"
  }
assert_win_pe "dcg.exe"
assert_win_pe "cass.exe"
assert_win_pe "br.exe"
assert_win_pe "cm.exe"

hdr "PHASE 6 — Agent Mail (optional)"
HEALTH=$(curl.exe -s --max-time 5 http://127.0.0.1:8765/api/health 2>&1)
case "$HEALTH" in
  *'"status":"ready"'*|*'"status":"ok"'*) pass "Agent Mail healthy at 127.0.0.1:8765/api/health" ;;
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
