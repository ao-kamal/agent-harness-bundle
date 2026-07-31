#!/usr/bin/env bash
# claude-harness-bundle — WSL stage
#
# Runs INSIDE a fresh WSL Ubuntu distro as root. Invoked BY PATH from install.ps1:
#   wsl -d Ubuntu -u root -- bash /mnt/c/<bundle>/install/wsl-setup.sh
# All parameters cross via the rendered env file next to this script (wsl-setup.env),
# never as command-line arguments (the MSYS2/wsl.exe arg boundary silently mangles them).
#
# Idempotent: safe to re-run; completed steps are skipped via the state file.
# After this script finishes, install.ps1 MUST run `wsl --shutdown`, restart the
# distro, and verify the boot hook fired — the daemons only start on VM cold boot.

set -euo pipefail
shopt -s lastpipe 2>/dev/null || true
umask 022

# ---------- output ----------
QUIET=0
info() { [ "$QUIET" -eq 1 ] && return 0; echo -e "\033[0;34m->\033[0m $*"; }
ok()   { [ "$QUIET" -eq 1 ] && return 0; echo -e "\033[0;32mOK\033[0m $*"; }
warn() { echo -e "\033[1;33mWARN\033[0m $*"; }
err()  { echo -e "\033[0;31mERR\033[0m $*" >&2; }

SUMMARY=()
note() { SUMMARY+=("$1"); }

# ---------- env file ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/wsl-setup.env"
[ -f "$ENV_FILE" ] || { err "wsl-setup.env not found next to this script — install.ps1 renders it first"; exit 2; }
# shellcheck disable=SC1090
source "$ENV_FILE"
: "${WIN_USER:?wsl-setup.env must set WIN_USER}"
: "${BUNDLE_ROOT:?wsl-setup.env must set BUNDLE_ROOT (as a /mnt/c path)}"
KIMI_ENABLED="${KIMI_ENABLED:-1}"
CFG="$BUNDLE_ROOT/config/wsl"
WINHOME="/mnt/c/Users/$WIN_USER"

# ---------- lock + state ----------
LOCK_DIR=/tmp/.harness-bundle-wsl.lock
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  err "Another wsl-setup run appears active ($LOCK_DIR). Remove it if stale."; exit 3
fi
cleanup() { rmdir "$LOCK_DIR" 2>/dev/null || true; }
trap cleanup EXIT

STATE=/root/.harness-bundle-wsl-state
touch "$STATE"
done_step() { grep -qx "$1" "$STATE"; }
mark_step() { echo "$1" >> "$STATE"; ok "step complete: $1"; }

# ---------- preflight ----------
info "Preflight"
[ "$(id -u)" -eq 0 ] || { err "Must run as root (wsl -u root)"; exit 2; }
mountpoint -q /mnt/c || { err "/mnt/c not mounted — drvfs unavailable"; exit 2; }
[ -d "$CFG" ] || { err "Bundle config dir not found at $CFG"; exit 2; }
[ -d "$WINHOME" ] || { err "Windows home $WINHOME not found — wrong WIN_USER?"; exit 2; }
AVAIL_KB=$(df -Pk /root | awk 'NR==2 {print $4}')
[ "$AVAIL_KB" -gt 2097152 ] || warn "Under 2GB free in WSL rootfs — installs may struggle"
if ! curl -fsS --connect-timeout 5 -o /dev/null https://api.github.com; then
  warn "GitHub unreachable right now — tool installs may fail; re-run this script later, it resumes"
fi
ok "preflight passed"

render() { # render <src> <dst> : substitute {{WIN_USER}}
  sed "s/{{WIN_USER}}/$WIN_USER/g" "$1" > "$2"
}

# ---------- step: apt basics ----------
if ! done_step apt-basics; then
  info "Installing apt basics (jq, xz, tmux, inotify-tools, unzip, python3)"
  apt-get update -o Acquire::Retries=5 -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    curl jq xz-utils tmux unzip inotify-tools python3 git ca-certificates fzf
  mark_step apt-basics
fi

# ---------- step: deploy config files ----------
if ! done_step deploy-config; then
  info "Deploying WSL config + scripts from bundle"
  [ -f /etc/wsl.conf ] && cp /etc/wsl.conf "/etc/wsl.conf.bak.$(date +%Y%m%d%H%M%S)"
  cp "$CFG/wsl.conf" /etc/wsl.conf
  install -m 755 "$CFG/mount-fast-data.sh" /usr/local/sbin/mount-fast-data.sh
  mkdir -p /root/.local/lib /root/.local/bin
  install -m 644 "$CFG/hot-data-enforce.sh" /root/.local/lib/hot-data-enforce.sh
  install -m 755 "$CFG/init-fast-data" /root/.local/bin/init-fast-data
  install -m 755 "$CFG/check-fast-data" /root/.local/bin/check-fast-data
  install -m 755 "$CFG/claude-wrapper.sh" /usr/local/bin/claude
  render "$CFG/claude-creds-symlink-watcher.sh" /root/.local/bin/claude-creds-symlink-watcher.sh
  chmod 755 /root/.local/bin/claude-creds-symlink-watcher.sh
  install -m 755 "$CFG/ensure-claude-creds-watcher.sh" /root/.local/bin/ensure-claude-creds-watcher.sh
  note "WSL config + boot hook + watchers deployed"
  mark_step deploy-config
fi

# ---------- step: shell config ----------
if ! done_step shell-config; then
  info "Installing shell configuration (markered blocks, idempotent)"
  for pair in "bashrc.template:/root/.bashrc" "profile.template:/root/.profile"; do
    src="$CFG/${pair%%:*}"; dst="${pair##*:}"
    if ! grep -q 'HARNESS-BUNDLE BEGIN' "$dst" 2>/dev/null; then
      [ -f "$dst" ] && cp "$dst" "$dst.bak.$(date +%Y%m%d%H%M%S)"
      { echo ""; echo "# ===== HARNESS-BUNDLE BEGIN ====="; } >> "$dst"
      render "$src" /tmp/.hb-shell-frag
      cat /tmp/.hb-shell-frag >> "$dst"
      echo "# ===== HARNESS-BUNDLE END =====" >> "$dst"
    fi
  done
  touch /root/.env.private && chmod 600 /root/.env.private
  grep -q 'GH_TOKEN' /root/.env.private || cat >> /root/.env.private <<'ENVEOF'
# Private tokens (never share, never commit). Add lines like:
# export GH_TOKEN=...
# export FIRECRAWL_API_KEY=...
ENVEOF
  note "Shell config installed; secrets scaffold at /root/.env.private"
  mark_step shell-config
fi

# ---------- step: symlinks ----------
# Deliberately NOT marked done while any target is missing, so a re-run retries
# just this step once the Windows side exists (e.g. caam's vault dir appears on
# first caam use).
if ! done_step symlinks; then
  info "Wiring Win<->WSL symlinks"
  mkdir -p /root/.claude /root/.local/share
  ANY_MISSING=0
  for pair in \
    ".claude/.credentials.json:/root/.claude/.credentials.json" \
    ".claude/projects:/root/.claude/projects" \
    ".claude/skills:/root/.claude/skills" \
    ".local/share/caam:/root/.local/share/caam"; do
    winrel="${pair%%:*}"; link="${pair##*:}"
    target="$WINHOME/$winrel"
    if [ -e "$target" ]; then
      [ -L "$link" ] || [ ! -e "$link" ] || mv "$link" "$link.pre-bundle.$(date +%s)"
      ln -sfn "$target" "$link"
    else
      warn "Windows target missing, symlink skipped for now: $target (re-run this script later; this step will retry)"
      ANY_MISSING=1
    fi
  done
  if [ "$ANY_MISSING" -eq 0 ]; then
    note "Cross-OS symlinks wired (all four)"
    mark_step symlinks
  else
    note "Symlinks: partial (missing Windows targets) - step stays pending, re-run retries it"
  fi
fi

# ---------- step: Claude Code in WSL ----------
if ! done_step claude-code; then
  if [ -x /root/.local/bin/claude ]; then
    ok "Claude Code already present in WSL"
  else
    info "Installing Claude Code in WSL"
    ( set -o pipefail; curl -fsSL https://claude.ai/install.sh | bash ) \
      || warn "Claude Code WSL install failed — re-run later; the trust wrapper at /usr/local/bin/claude needs the real binary at /root/.local/bin/claude"
  fi
  mark_step claude-code
fi

# ---------- step: flywheel tools ----------
# Each install is independent: failure warns and continues; re-run resumes.
inst() { # inst <name> <command...>
  local name="$1"; shift
  if done_step "tool-$name"; then return 0; fi
  info "Installing $name"
  if ( set -o pipefail; "$@" ); then
    mark_step "tool-$name"
  else
    warn "$name install failed — re-run wsl-setup.sh to retry"
    note "FAILED: $name (re-run to retry)"
  fi
}

cb() { date +%s; }
inst cass  bash -c 'curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/coding_agent_session_search/main/install.sh?$(date +%s)" | bash -s -- --easy-mode --verify'
inst cm    bash -c 'curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/cass_memory_system/main/install.sh?$(date +%s)" | bash -s -- --easy-mode --verify'
inst br    bash -c 'curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/beads_rust/main/install.sh?$(date +%s)" | bash'
inst ubs   bash -c 'curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/ultimate_bug_scanner/main/install.sh?$(date +%s)" | bash'
inst dcg   bash -c 'curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/destructive_command_guard/main/install.sh?$(date +%s)" | bash -s -- --easy-mode'
inst ntm   bash -c 'curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/ntm/main/install.sh?$(date +%s)" | bash -s -- --easy-mode'
inst agent-mail bash -c 'curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/mcp_agent_mail/main/scripts/install.sh?$(date +%s)" | bash -s -- --yes'

# bv: upstream install.sh has broken prebuilt detection (falls back to a slow
# Go source build) — use the release tarball directly, checksum-verified.
if ! done_step tool-bv; then
  info "Installing bv (direct tarball — upstream installer's prebuilt detection is broken)"
  BVTMP=$(mktemp -d /tmp/bv-XXXXXX)
  if curl -fsSL -o "$BVTMP/bv.tar.gz" "https://github.com/Dicklesworthstone/beads_viewer/releases/latest/download/bv_linux_amd64.tar.gz" \
     && curl -fsSL -o "$BVTMP/checksums.txt" "https://github.com/Dicklesworthstone/beads_viewer/releases/latest/download/checksums.txt"; then
    ( cd "$BVTMP" && grep 'bv_linux_amd64.tar.gz' checksums.txt | sed 's|bv_linux_amd64.tar.gz|bv.tar.gz|' | sha256sum -c - ) \
      && tar -xzf "$BVTMP/bv.tar.gz" -C "$BVTMP" \
      && install -m 755 "$(find "$BVTMP" -maxdepth 2 -type f -name bv | head -1)" /root/.local/bin/bv \
      && mark_step tool-bv || { warn "bv checksum/extract failed"; note "FAILED: bv"; }
  else
    warn "bv download failed — re-run to retry"; note "FAILED: bv"
  fi
fi

# caam: its installer HARD-requires cosign for release verification.
# cosign itself installs from sigstore's prebuilt release binary (no Go needed).
if ! done_step tool-cosign && ! command -v cosign >/dev/null 2>&1; then
  info "Installing cosign (prebuilt binary; required by caam's release verification)"
  CSTMP=$(mktemp -d /tmp/cosign-XXXXXX)
  if curl -fsSL -o "$CSTMP/cosign" "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64" \
     && curl -fsSL -o "$CSTMP/cosign.sha256" "https://github.com/sigstore/cosign/releases/latest/download/cosign_checksums.txt"; then
    if ( cd "$CSTMP" && grep 'cosign-linux-amd64$' cosign.sha256 | sed 's|cosign-linux-amd64|cosign|' | sha256sum -c - ); then
      install -m 755 "$CSTMP/cosign" /root/.local/bin/cosign
      mark_step tool-cosign
    else
      warn "cosign checksum failed - caam will be skipped this run"
    fi
  else
    warn "cosign download failed - caam will be skipped this run; re-run to retry"
  fi
fi
if ! done_step tool-caam; then
  if command -v cosign >/dev/null 2>&1; then
    inst caam bash -c 'curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/coding_agent_account_manager/main/install.sh?$(date +%s)" | bash'
  else
    warn "caam skipped: cosign not available yet (its installer refuses unverified releases). Re-run this script to retry."
    note "SKIPPED: caam (cosign missing)"
  fi
fi

# ---------- step: ntm config (+ Kimi routing) ----------
if ! done_step ntm-config; then
  if command -v ntm >/dev/null 2>&1 || [ -x /usr/local/bin/ntm ]; then
    info "Configuring ntm"
    mkdir -p /root/.config/ntm
    if [ "$KIMI_ENABLED" = "1" ] && [ -f "$BUNDLE_ROOT/config/kimi/cc-router" ]; then
      render "$BUNDLE_ROOT/config/kimi/cc-router" /root/.local/bin/cc-router
      chmod 755 /root/.local/bin/cc-router
      note "Kimi router installed (put your Kimi key at $WINHOME/.config/kimi/key)"
    fi
    # ntm safety wrappers + the temp-cleanup allow rule (installer temp dirs)
    ntm safety install >/dev/null 2>&1 || warn "ntm safety install failed (run manually later)"
    mkdir -p /root/.ntm
    if [ -f /root/.ntm/policy.yaml ] && ! grep -q 'tmp|var/tmp' /root/.ntm/policy.yaml; then
      warn "Add the temp-dir allow rule to /root/.ntm/policy.yaml if installers get blocked on cleanup (see docs/methodology/tooling-update-runbook-generic.md, the ntm-rm-wrapper gotcha)"
    fi
    mark_step ntm-config
  else
    warn "ntm not on PATH yet — re-run after its install succeeds"
  fi
fi

# ---------- step: Agent Mail server config ----------
if ! done_step agent-mail-config; then
  info "Generating Agent Mail config (fresh bearer token, both OS copies)"
  TOKEN=$( (openssl rand -hex 32 2>/dev/null) || (head -c32 /dev/urandom | od -An -tx1 | tr -d ' \n') )
  for d in /root/.config/mcp-agent-mail "$WINHOME/.config/mcp-agent-mail"; do
    mkdir -p "$d"
    if [ ! -f "$d/config.env" ]; then
      cat > "$d/config.env" <<CFGEOF
HTTP_HOST=0.0.0.0
HTTP_PORT=8765
HTTP_PATH=/mcp/
HTTP_BEARER_TOKEN=$TOKEN
TUI_ENABLED=false
LOG_LEVEL=info
CFGEOF
    fi
  done
  chmod 600 /root/.config/mcp-agent-mail/config.env
  note "Agent Mail config generated (token minted fresh; mcp-register.ps1 reads it from the Windows copy)"
  mark_step agent-mail-config
fi

# ---------- summary ----------
echo ""
echo -e "\033[1;32m==== WSL stage complete ====\033[0m"
for line in "${SUMMARY[@]}"; do echo "  - $line"; done
echo ""
echo "NEXT (install.ps1 does this automatically):"
echo "  1. wsl --shutdown   (from Windows)"
echo "  2. restart the distro and verify /root/.local/share/mount-fast-data.log shows a fresh 'boot hook start'"
echo "  3. verify Agent Mail: curl http://127.0.0.1:8765/health   (ALWAYS 127.0.0.1, never localhost)"
if grep -q FAILED <<< "${SUMMARY[*]:-}"; then
  warn "Some tools failed to install — re-run this script to retry just those (state is preserved)."
  exit 10
fi
exit 0
