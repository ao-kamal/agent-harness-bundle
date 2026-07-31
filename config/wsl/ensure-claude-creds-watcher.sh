#!/usr/bin/env bash
# ensure-claude-creds-watcher.sh
# Idempotently start the credentials.json symlink watcher.
# Safe to call from .bashrc / .profile, including concurrently from
# multiple shells (e.g., NTM panes opening simultaneously).

PID_FILE=/tmp/claude-creds-watcher.pid
LOCK_FILE=/tmp/claude-creds-watcher.lock
SCRIPT=/root/.local/bin/claude-creds-symlink-watcher.sh
LOG=/tmp/claude-creds-watcher.log
LOG_MAX_BYTES=1048576   # 1 MiB

# Mutex: serialize concurrent invocations so we don't start duplicate watchers.
# Open fd 9 to the lock file; flock holds the lock until fd 9 closes (which
# happens when this script exits). -w 5 waits up to 5 seconds.
exec 9>"$LOCK_FILE"
if ! flock -w 5 9; then
    echo "ERROR: failed to acquire $LOCK_FILE within 5s" >&2
    exit 1
fi

# Cap log size. Truncate in place (`: > FILE` is open-with-O_TRUNC then close)
# so the watcher's open append fd keeps writing to the same inode — no need
# to signal the watcher. /tmp does NOT clear on WSL boot here, so without
# this the log grows unbounded across reboots.
if [ -f "$LOG" ] && [ "$(stat -c '%s' "$LOG" 2>/dev/null || echo 0)" -gt "$LOG_MAX_BYTES" ]; then
    : > "$LOG"
fi

# Already running? Verify via PID file + cmdline check (defends against PID reuse).
if [ -f "$PID_FILE" ]; then
    pid=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        if grep -q "claude-creds-symlink-watcher" "/proc/$pid/cmdline" 2>/dev/null; then
            exit 0
        fi
    fi
fi

[ -x "$SCRIPT" ] || { echo "ERROR: $SCRIPT not executable" >&2; exit 1; }

# 9>&- closes the lock fd in the spawned child so the watcher doesn't inherit
# (and thereby indefinitely hold) the flock. Without this, the watcher would
# keep the lock for its entire lifetime — every later ensure-watcher call
# would wait 5s for the lock and time out.
nohup "$SCRIPT" >> "$LOG" 2>&1 < /dev/null 9>&- &
echo $! > "$PID_FILE"
disown 2>/dev/null || true
