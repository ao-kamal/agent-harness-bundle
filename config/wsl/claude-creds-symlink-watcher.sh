#!/usr/bin/env bash
# claude-creds-symlink-watcher.sh
#
# Repairs the WSL-side credentials.json symlink after Claude Code's
# atomic-write (write tmp + rename) severs it.
#
# Mechanism: Claude Code refreshes its OAuth tokens by writing
# .credentials.json.tmp then rename(2)'ing it onto .credentials.json.
# rename(2) replaces the directory entry — if the destination was a
# symlink, the symlink is gone after the call and the WSL side now
# holds a fresh regular file with the new tokens, while the Windows
# file (the original symlink target) is left untouched and stale.
# At the next Windows-side refresh, Anthropic rejects the now-rotated
# refresh token; Windows Claude clears the field and writes
# refreshToken="" — the visible "corruption" pattern.
#
# This watcher monitors /root/.claude for create/moved_to events on
# .credentials.json. When fired, if the path is no longer a symlink,
# it propagates the fresh tokens to the Windows file (atomic write
# via tmp+rename so Windows Claude can't read a half-written file)
# then atomically swaps the regular file back to a symlink.
#
# At startup the direction of repair is ambiguous (we don't know
# which side has fresh tokens), so a "validity-then-mtime" heuristic
# is used: refreshToken length > 0 wins; if both are valid, newer
# mtime wins; if both are broken, the script logs a warning and
# leaves state alone (manual rehydrate needed).
#
# The inotifywait pipeline is wrapped in an outer respawn loop so
# kernel/inotify hiccups can't silently kill the watcher.

set -u

WSL=/root/.claude/.credentials.json
WIN=/mnt/c/Users/{{WIN_USER}}/.claude/.credentials.json
PARENT=/root/.claude
RESPAWN_DELAY=5

log() { printf '[%s] %s\n' "$(date -Iseconds)" "$*"; }

# On signal: kill our children (inotifywait + while-read subshell), then exit
# cleanly. pkill -P $$ targets processes whose PPID is the watcher's PID,
# i.e. the inotifywait subprocess and the while-read pipeline subshell.
trap 'log "received signal, exiting"; pkill -P $$ 2>/dev/null; exit 0' TERM INT HUP

# Returns the byte length of $.claudeAiOauth.refreshToken in the file at $1,
# or 0 if the file is missing/unreadable/not-JSON/missing-field/empty-string.
refresh_token_len() {
    jq -r '.claudeAiOauth.refreshToken // "" | length' "$1" 2>/dev/null || echo 0
}

# Atomically replace $WSL with a symlink to $WIN.
# Caller is responsible for ensuring $WIN holds the desired content first.
restore_symlink() {
    local tmp="${WSL}.symlink-tmp.$$"
    rm -f -- "$tmp"
    if ! ln -s -- "$WIN" "$tmp"; then
        log "ERROR: ln -s $WIN $tmp failed"
        return 1
    fi
    if ! mv -f -- "$tmp" "$WSL"; then
        log "ERROR: mv $tmp $WSL failed"
        rm -f -- "$tmp"
        return 1
    fi
    return 0
}

# Atomically copy WSL regular file -> WIN (via WIN.creds-tmp.$$ + rename),
# then restore the symlink. Returns 0 on full success.
#
# The two-step write means Windows Claude never sees a half-written file.
#
# A snapshot of WSL's content is kept on /tmp (ext4) until post-verification.
# This handles a rare race: 9p writes to /mnt/c are slow (~2s here), so during
# our cp/mv there's a window where Windows Claude could refresh, hit a 401
# (because Anthropic rotated the refresh token when WSL refreshed), and write
# refreshToken="" ON TOP of our good mv. We re-check WIN after a short delay;
# if Windows clobbered us, we re-propagate from the snapshot.
propagate_wsl_to_win() {
    local snapshot="/tmp/claude-creds-watcher.snapshot.$$"
    rm -f -- "$snapshot"
    if ! cp -- "$WSL" "$snapshot"; then
        log "ERROR: cp $WSL -> $snapshot (snapshot) failed"
        return 1
    fi

    local win_tmp="${WIN}.creds-tmp.$$"
    rm -f -- "$win_tmp"
    if ! cp -- "$snapshot" "$win_tmp"; then
        log "ERROR: cp snapshot -> $win_tmp failed"
        rm -f -- "$snapshot" "$win_tmp"
        return 1
    fi
    if ! mv -f -- "$win_tmp" "$WIN"; then
        log "ERROR: mv $win_tmp -> $WIN failed"
        rm -f -- "$snapshot" "$win_tmp"
        return 1
    fi
    if ! restore_symlink; then
        rm -f -- "$snapshot"
        return 1
    fi

    # Post-write verification — handles the rare reverse-race where Windows
    # writes refreshToken="" on top of our just-written good file. Sleep
    # gives Windows a chance to write if it's going to; then re-check.
    sleep 2
    local win_rt
    win_rt=$(refresh_token_len "$WIN")
    if [ "$win_rt" -eq 0 ]; then
        log "post-verify: WIN refreshToken=0 after our write — Windows clobbered; re-propagating from snapshot"
        local retry_tmp="${WIN}.creds-tmp.$$.retry"
        rm -f -- "$retry_tmp"
        if cp -- "$snapshot" "$retry_tmp" && mv -f -- "$retry_tmp" "$WIN"; then
            log "post-verify: re-propagation succeeded"
        else
            log "ERROR: post-verify re-propagation failed"
            rm -f -- "$retry_tmp"
        fi
    fi
    rm -f -- "$snapshot"
    return 0
}

# Event-driven repair: assumes WSL was just atomic-written by Claude Code,
# so its content is the freshest. Propagate to WIN, then restore symlink.
repair_event_driven() {
    [ -L "$WSL" ] && return 0
    [ -f "$WSL" ] || return 0
    if propagate_wsl_to_win; then
        log "repaired symlink (event-driven; WSL -> WIN propagated)"
    fi
}

# Startup-time repair: direction is ambiguous, so use refreshToken validity,
# then mtime as tiebreaker. This avoids overwriting a fresher Windows file
# with a stale WSL regular file when the watcher restarts after being off.
repair_startup() {
    [ -L "$WSL" ] && return 0  # symlink intact, nothing to do

    # WSL missing entirely: if WIN is good, just restore the symlink.
    if [ ! -e "$WSL" ]; then
        if [ -f "$WIN" ]; then
            log "startup: WSL missing — restoring symlink to existing WIN"
            restore_symlink && log "startup repair complete"
        else
            log "WARNING: startup found WSL and WIN both missing — manual login may be required"
        fi
        return
    fi

    [ -f "$WSL" ] || return 0  # WSL exists but isn't a regular file (dir? device?); bail

    local wsl_rt win_rt wsl_mtime win_mtime
    wsl_rt=$(refresh_token_len "$WSL")

    if [ ! -f "$WIN" ]; then
        log "startup: WIN missing, WSL is regular file (rt=$wsl_rt) — propagating WSL -> WIN"
        propagate_wsl_to_win && log "startup repair complete"
        return
    fi

    win_rt=$(refresh_token_len "$WIN")

    if [ "$wsl_rt" -gt 0 ] && [ "$win_rt" -eq 0 ]; then
        log "startup: WSL valid (rt=$wsl_rt), WIN broken (rt=0) — propagating WSL -> WIN"
        propagate_wsl_to_win && log "startup repair complete"
    elif [ "$wsl_rt" -eq 0 ] && [ "$win_rt" -gt 0 ]; then
        log "startup: WSL broken (rt=0), WIN valid (rt=$win_rt) — restoring symlink only (WIN content preserved)"
        restore_symlink && log "startup repair complete"
    elif [ "$wsl_rt" -eq 0 ] && [ "$win_rt" -eq 0 ]; then
        log "WARNING: startup found both WSL and WIN with empty/missing refreshToken — manual rehydrate may be needed; not auto-repairing"
        return 1
    else
        wsl_mtime=$(stat -c '%Y' "$WSL" 2>/dev/null || echo 0)
        win_mtime=$(stat -c '%Y' "$WIN" 2>/dev/null || echo 0)
        if [ "$wsl_mtime" -ge "$win_mtime" ]; then
            log "startup: both valid; WSL newer/equal (mtimes WSL=$wsl_mtime WIN=$win_mtime) — propagating WSL -> WIN"
            propagate_wsl_to_win && log "startup repair complete"
        else
            log "startup: both valid; WIN newer (mtimes WSL=$wsl_mtime WIN=$win_mtime) — restoring symlink only"
            restore_symlink && log "startup repair complete"
        fi
    fi
}

# Clean up any leftover tmp/snapshot files from a previous crashed run.
rm -f -- "${WIN}.creds-tmp."* "${WSL}.symlink-tmp."* /tmp/claude-creds-watcher.snapshot.* 2>/dev/null || true

log "starting (pid $$); WSL=$WSL  WIN=$WIN"
repair_startup

# Outer respawn loop: if inotifywait dies (kernel hiccup, ENOSPC on inotify
# watches, etc.), restart after a short delay so we don't silently lose
# protection.
while true; do
    inotifywait -m -q -e moved_to,create --format '%f' -- "$PARENT" \
    | while read -r fname; do
        if [ "$fname" = ".credentials.json" ]; then
            sleep 0.05  # let the kernel settle the rename
            repair_event_driven
        fi
    done
    log "WARNING: inotifywait pipeline exited; respawning in ${RESPAWN_DELAY}s"
    sleep "$RESPAWN_DELAY"
done
