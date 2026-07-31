#!/usr/bin/env bash
# hot-data-enforce.sh v2 — protect /mnt/c projects from 9p slowness
# Sourced from /root/.profile. Wraps package-management tools to refuse
# install operations when project hot-data dirs are on NTFS-over-9p instead
# of native ext4. Auto-initializes when the dir is absent (first install).
#
# v4: node_modules/.next/.turbo use a BIND-MOUNT to ext4 instead of a
#   symlink, because npm v11 DELETES a symlinked node_modules on install
#   ("Removing non-directory") and rebuilds it on 9p. A bind-mount is a
#   real dir npm cannot clobber. Acceptance check now passes for bind-mounts
#   too, and the mount self-heals after `wsl --shutdown` on the next install.
#
# Set HOT_DATA_ENFORCE_OFF=1 to bypass (one-off override).
#
# KNOWN LIMITATION — alias shadowing: In interactive shells, bash expands
# aliases BEFORE function lookup. If you have `alias pnpm=...` in your
# .bashrc (loaded BEFORE this file via .profile->.bashrc chain), your alias
# wins and these wrappers are bypassed. If wrappers don't seem to trigger,
# run `type pnpm` — if it says "aliased to ...", remove the alias or run
# `unalias pnpm npm yarn cargo pip pip3 uv poetry pipenv python python3`
# in your shell to re-enable the wrappers.

_HOT_DATA_DIRS=(
  # Node
  node_modules .next .turbo
  # Rust
  target
  # Python (project-local venvs and tool caches) — `env` removed (too
  # commonly used for non-venv DevOps config dirs)
  .venv venv
  .tox .pytest_cache .mypy_cache .ruff_cache
  # Generic
  .cache .parcel-cache .vite .swc
)

# Dirs whose owning tool DELETES a symlink on install (npm v11 reify; next/turbo
# build outputs). These get a BIND-MOUNT to ext4 instead of a symlink. Everything
# else in _HOT_DATA_DIRS stays a symlink (cargo/pip/etc. respect symlinked dirs).
_HOT_DATA_MOUNT_CLASS=(
  node_modules .next .turbo
)

_HOT_DATA_MARKERS=(
  package.json
  Cargo.toml
  pyproject.toml setup.py requirements.txt Pipfile
  go.mod
)

_HOT_DATA_AUTO_INIT=(
  node_modules
  .venv
  target
)

_hot_data_log() {
  printf '\033[33m[hot-data]\033[0m %s\n' "$1" >&2
}

# Is $1 (a relpath) in the bind-mount class?
_hot_data_is_mount_class() {
  local d="$1" m
  for m in "${_HOT_DATA_MOUNT_CLASS[@]}"; do [[ "$d" == "$m" ]] && return 0; done
  return 1
}

# Is $1 already redirected to ext4? Accepts EITHER a symlink->/root OR a
# bind-mount whose backing fs is not the 9p/drvfs of /mnt/c.
_hot_data_is_redirected() {
  local d="$1" t
  if [[ -L "$d" ]]; then
    t="$(readlink -f "$d" 2>/dev/null)"
    [[ "$t" == /root/* && -d "$t" ]] && return 0
    return 1
  fi
  if [[ -d "$d" ]] && mountpoint -q "$d" 2>/dev/null; then
    t="$(findmnt -no FSTYPE --target "$d" 2>/dev/null)"
    case "$t" in
      drvfs|9p|cifs|"") return 1 ;;   # still on the Windows/9p side
      *) return 0 ;;                  # ext4/wslfs/overlay/etc. = real redirect
    esac
  fi
  return 1
}

# Ensure a mount-class dir ($1, relpath) is a bind-mount to its ext4 data dir.
# Idempotent; self-heals (re-mounts after `wsl --shutdown`). Returns 0 on success.
_hot_data_ensure_mount() {
  local rel="$1"
  local proj="$PWD/$rel"
  local data="/root/projects-data/$(basename "$PWD")/$rel"
  mountpoint -q "$proj" 2>/dev/null && return 0    # already a live bind-mount
  mkdir -p "$data"
  if [[ -L "$proj" ]]; then
    rm -f "$proj"                                  # legacy symlink -> replace (data preserved in $data)
    mkdir -p "$proj"
  elif [[ -d "$proj" ]]; then
    # Real dir (likely 9p). Migrate its content to ext4 if ext4 is empty.
    if [[ -z "$(ls -A "$data" 2>/dev/null)" && -n "$(ls -A "$proj" 2>/dev/null)" ]]; then
      _hot_data_log "migrating existing $rel to ext4 (one-time copy)..."
      cp -a "$proj/." "$data/" 2>/dev/null || true
    fi
    if [[ -z "$(ls -A "$proj" 2>/dev/null)" ]]; then
      rmdir "$proj" 2>/dev/null || true            # empty (e.g. post-reboot mountpoint)
    else
      mv "$proj" "${proj}.9p.$(date +%s 2>/dev/null || echo bak)" 2>/dev/null || true
    fi
    mkdir -p "$proj"
  else
    mkdir -p "$proj"
  fi
  if ! mount --bind "$data" "$proj" 2>/dev/null; then
    _hot_data_log "bind-mount failed for $rel (need root?) — falling back to symlink"
    rmdir "$proj" 2>/dev/null && ln -s "$data" "$proj" 2>/dev/null
    return 1
  fi
  local manifest="/root/projects-data/.fastdata-mounts"
  grep -qF "$proj" "$manifest" 2>/dev/null || printf '%s\t%s\n' "$proj" "$data" >> "$manifest"
  if [[ -f "$PWD/.gitignore" ]] && ! grep -qxF "/$rel" "$PWD/.gitignore" 2>/dev/null && ! grep -qxF "$rel" "$PWD/.gitignore" 2>/dev/null; then
    echo "/$rel" >> "$PWD/.gitignore"
  fi
  return 0
}

# Find first non-flag positional arg in the wrapper command line.
# Skips known value-taking flags (--prefix /x, -F mypkg, etc.) and bare
# flag-form args (--verbose, -g). Imperfect: any unknown value-taking flag
# causes its value to be mis-detected as the verb. False-negatives are
# preferable to the silent bypass of the prior `${1:-}` check.
_hot_data_first_verb() {
  local arg
  while [ $# -gt 0 ]; do
    arg="$1"
    case "$arg" in
      # Combined --flag=value form — single arg
      --*=*) shift ;;
      # rustup/cargo toolchain selector (e.g. `cargo +nightly build`) — NOT a
      # verb; skip 1. (previously fell through to *) and was returned
      # as the verb, silently bypassing the check for `cargo +nightly <verb>`.)
      +*) shift ;;
      # Known value-taking flags — skip 2 args. Common across npm/pnpm/yarn/cargo/pip.
      # NB: -w and -r are intentionally NOT listed. They are BOOLEAN in pnpm
      # (--workspace-root / --recursive); and in the tools where they DO take a
      # value (npm -w <ws>, pip -r <file>) the subcommand verb precedes them, so
      # this scanner returns the verb before ever reaching them. Listing them as
      # value-taking made `pnpm -r install` / `pnpm -w add` shift PAST the verb,
      # yielding an empty/wrong verb -> silent bypass.
      --prefix|--filter|--dir|--cwd|--workspace|--cd|--target|--config|--registry|--use-yarn|--use-npm|-F|-C|--index-url|--extra-index-url) shift 2 || break ;;
      # Other flag-form args (likely boolean) — skip 1
      -*) shift ;;
      # First non-flag arg — return it
      *) echo "$arg"; return 0 ;;
    esac
  done
  return 1
}

_hot_data_check() {
  [[ -n "${HOT_DATA_ENFORCE_OFF:-}" ]] && return 0
  [[ "$PWD" == /mnt/c/* ]] || return 0

  local has_marker=0 marker
  for marker in "${_HOT_DATA_MARKERS[@]}"; do
    if [[ -e "$marker" ]]; then has_marker=1; break; fi
  done
  [[ $has_marker -eq 1 ]] || return 0

  # Mount-class dirs (node_modules/.next/.turbo): ensure a BIND-MOUNT to ext4.
  # Covers first-install (absent), legacy symlink (convert), and post-reboot
  # (re-mount) cases. A bind-mount survives `npm install` where a symlink dies.
  local mc
  for mc in "${_HOT_DATA_MOUNT_CLASS[@]}"; do
    [[ -f package.json ]] || continue   # only relevant to node projects
    if [[ "$mc" == node_modules || -e "$mc" ]]; then
      _hot_data_ensure_mount "$mc" || true
    fi
  done

  # Auto-init absent NON-mount-class dirs via init-fast-data (symlink is fine here)
  local auto_dir
  for auto_dir in "${_HOT_DATA_AUTO_INIT[@]}"; do
    _hot_data_is_mount_class "$auto_dir" && continue   # handled above
    if [[ ! -e "$auto_dir" ]]; then
      case "$auto_dir" in
        .venv) [[ -f pyproject.toml || -f setup.py || -f requirements.txt || -f Pipfile ]] || continue ;;
        target) [[ -f Cargo.toml ]] || continue ;;
      esac
      _hot_data_log "auto-initializing $auto_dir on ext4 (9p mitigation)..."
      if ! command init-fast-data "$auto_dir" >&2; then
        _hot_data_log "init-fast-data failed for $auto_dir — aborting"
        return 1
      fi
    fi
  done

  # Refuse if any hot dir is still on /mnt/c (neither symlink->ext4 nor bind-mount).
  local missing=() dir
  for dir in "${_HOT_DATA_DIRS[@]}"; do
    [[ -e "$dir" ]] || continue
    _hot_data_is_redirected "$dir" && continue
    missing+=("$dir")
  done

  if (( ${#missing[@]} > 0 )); then
    _hot_data_log "/mnt/c hot dirs (slow on 9p): ${missing[*]}"
    _hot_data_log "  Run: init-fast-data ${missing[*]}"
    _hot_data_log "  Or override one-off: HOT_DATA_ENFORCE_OFF=1 <command>"
    return 1
  fi
  return 0
}

# Node tooling — `create` dropped (scaffolds NEW dir, not cwd, so cwd check
# is the wrong target).
pnpm() { case "$(_hot_data_first_verb "$@")" in install|i|add|update|dlx) _hot_data_check || return 1 ;; esac; command pnpm "$@"; }
npm()  { case "$(_hot_data_first_verb "$@")" in install|i|ci|update|add)  _hot_data_check || return 1 ;; esac; command npm  "$@"; }
yarn() { local v; v="$(_hot_data_first_verb "$@")"; case "${v:-install}" in install|add|upgrade) _hot_data_check || return 1 ;; esac; command yarn "$@"; }

# Rust
cargo() { case "$(_hot_data_first_verb "$@")" in build|test|run|check|fetch|install|update|new|init) _hot_data_check || return 1 ;; esac; command cargo "$@"; }

# Python — pip: `download` dropped (downloads to --dest, not an install);
# uv: `run` dropped (just executes in venv, not an install).
pip()    { case "$(_hot_data_first_verb "$@")" in install|wheel)              _hot_data_check || return 1 ;; esac; command pip    "$@"; }
pip3()   { case "$(_hot_data_first_verb "$@")" in install|wheel)              _hot_data_check || return 1 ;; esac; command pip3   "$@"; }
uv()     { case "$(_hot_data_first_verb "$@")" in pip|add|sync|venv|tool|build) _hot_data_check || return 1 ;; esac; command uv "$@"; }
poetry() { case "$(_hot_data_first_verb "$@")" in install|add|update|lock|sync) _hot_data_check || return 1 ;; esac; command poetry "$@"; }
pipenv() { case "$(_hot_data_first_verb "$@")" in install|update|sync|lock)     _hot_data_check || return 1 ;; esac; command pipenv "$@"; }
python() {
  if [[ "${1:-}" == "-m" ]]; then
    case "${2:-}" in venv|pip) _hot_data_check || return 1 ;; esac
  fi
  command python "$@"
}
python3() {
  if [[ "${1:-}" == "-m" ]]; then
    case "${2:-}" in venv|pip) _hot_data_check || return 1 ;; esac
  fi
  command python3 "$@"
}
