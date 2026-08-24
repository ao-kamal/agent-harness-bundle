#!/bin/bash
# smoke-test-hermes.sh -- Hermes adapter phase for the agent-harness-bundle.
#
# Run AFTER install-hermes.ps1. Complements smoke-test.sh (which tests the
# Claude/Grok stack). Safe to re-run any time; read-only except a throwaway
# `hermes config get` call. Never modifies state.
#
# Checks:
#   1. hermes CLI on PATH and runs
#   2. HERMES_HOME resolvable + config.yaml present
#   3. skills.external_dirs points at ~/.claude/skills
#   4. external brain actually visible: a known bundle skill resolves
#   5. bundle preference keys present (nudge=0, curator off, clarify unlimited)
#   6. SOUL.md carries the harness-bundle operating-rules block
#   7. mcp-agent-mail registered (enabled) -- WARN only, WSL boot may be cold

G='\033[0;32m'; R='\033[0;31m'; Y='\033[0;33m'; N='\033[0m'
PASS=0; FAIL=0; SKIP=0
ok()   { PASS=$((PASS+1)); printf "${G}PASS${N} %s\n" "$1"; }
bad()  { FAIL=$((FAIL+1)); printf "${R}FAIL${N} %s\n" "$1"; }
skip() { SKIP=$((SKIP+1)); printf "${Y}SKIP${N} %s\n" "$1"; }

WINUSER="${USERNAME:-$(powershell.exe -NoProfile -Command 'Write-Host -NoNewline $env:USERNAME' 2>/dev/null | tr -d '\r')}"
BRAIN="C:/Users/$WINUSER/.claude/skills"

echo "=== Hermes adapter smoke test ==="

# 1. CLI present
if command -v hermes >/dev/null 2>&1; then
  ok "hermes CLI on PATH ($(hermes --version 2>/dev/null | head -c 40))"
else
  bad "hermes CLI not on PATH - run install-hermes.ps1 prerequisite"
  echo "Summary: 0 ok, 1 fail"; exit 1
fi

# 2. HERMES_HOME + config.yaml (resolve like Hermes does: env wins)
HERMES_HOME_RESOLVED="${HERMES_HOME:-$LOCALAPPDATA/hermes}"
if [ -f "$HERMES_HOME_RESOLVED/config.yaml" ]; then
  ok "HERMES_HOME config found: $HERMES_HOME_RESOLVED/config.yaml"
else
  bad "config.yaml missing at $HERMES_HOME_RESOLVED"
fi

CFG="$HERMES_HOME_RESOLVED/config.yaml"

# helper: get scalar under [section] with 2-space indent
cfg_get() { # section key
  awk -v sec="$1:" -v key="$2" '
    $0 == sec || index($0, sec) == 1 { insec=1; next }
    /^[^ #]/ { insec=0 }
    insec && $0 ~ "^[ ]{2}"key":" {
      sub("^[ ]{2}"key":[ ]*", ""); gsub(/\r/,""); print; exit }
  ' "$CFG"
}

# 3. external_dirs contains the brain
extdirs=$(grep -A5 "^skills:" "$CFG" | grep "external_dirs" >/dev/null && \
          grep -A8 "external_dirs:" "$CFG" | grep -c "\.claude/skills" || echo 0)
if [ "$extdirs" -ge 1 ]; then
  ok "skills.external_dirs includes the shared brain ($BRAIN)"
else
  bad "skills.external_dirs missing or does not include $BRAIN"
fi

# 4. brain actually visible to hermes: pick a skill we know ships in the bundle
KNOWN_SKILL=$(ls "$HOME/.claude/skills" 2>/dev/null | grep -E '^(wizard|edit-pipeline|dev-browser|skill-forge)$' | head -1)
if [ -z "$KNOWN_SKILL" ]; then KNOWN_SKILL="flywheel-planning"; fi
if hermes skills list 2>/dev/null | grep -qE "[│ ]$KNOWN_SKILL[ │]"; then
  ok "external brain visible to hermes (found '$KNOWN_SKILL')"
else
  bad "known bundle skill '$KNOWN_SKILL' not in hermes skills list"
fi

# 5. bundle preference keys
nudge=$(cfg_get "skills" "creation_nudge_interval")
[ "$nudge" = "0" ] && ok "skills.creation_nudge_interval = 0" \
                   || bad "creation_nudge_interval expected 0, got '${nudge:-<missing>}'"

curator=$(awk '/^curator:/{insec=1;next} /^[^ #]/{insec=0} insec&&/enabled:/{print $2}' "$CFG" | tr -d '\r')
[ "$curator" = "false" ] && ok "curator.enabled = false" \
                         || bad "curator.enabled expected false, got '${curator:-<missing>}'"

clarify=$(cfg_get "agent" "clarify_timeout")
[ "$clarify" = "0" ] && ok "agent.clarify_timeout = 0 (unlimited)" \
                     || bad "clarify_timeout expected 0, got '${clarify:-<missing>}'"

# 6. SOUL.md rules block
SOUL="$HERMES_HOME_RESOLVED/SOUL.md"
if grep -q "BEGIN harness-bundle operating rules" "$SOUL" 2>/dev/null; then
  ok "SOUL.md carries the operating-rules block"
else
  bad "SOUL.md missing harness-bundle rules block - run install-hermes.ps1 -Update"
fi

# 7. mcp-agent-mail registered (WARN-only: WSL daemon may be cold-booted down)
if hermes mcp list 2>/dev/null | grep -q "mcp-agent-mail"; then
  if hermes mcp list 2>/dev/null | grep "mcp-agent-mail" | grep -q "enabled"; then
    ok "mcp-agent-mail registered + enabled"
  else
    skip "mcp-agent-mail registered but disabled - check auth headers / token"
  fi
else
  skip "mcp-agent-mail not registered (run install-hermes.ps1 -Update after WSL stage)"
fi

echo ""
printf "Hermes adapter summary: ${G}%d ok${N}, ${R}%d fail${N}, ${Y}%d skip${N}\n" "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
