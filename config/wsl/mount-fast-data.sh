#!/usr/bin/env bash
# mount-fast-data.sh - WSL boot hook (wsl.conf [boot] command).
# WSL init processes /etc/fstab BEFORE /mnt/c drvfs is ready, so bind
# mounts targeting /mnt/c fail at boot (dmesg: ConfigMountFsTab failed).
# mountFsTab=false in wsl.conf hands fstab processing to this script,
# which waits for /mnt/c first. Also restarts the creds symlink watcher
# (it has no other autostart).
LOG=/root/.local/share/mount-fast-data.log
{
  echo "$(date -Is) boot hook start"
  for i in $(seq 1 30); do
    mountpoint -q /mnt/c && break
    sleep 1
  done
  if mountpoint -q /mnt/c; then
    if mount -a; then echo "$(date -Is) mount -a OK"; else echo "$(date -Is) mount -a FAILED rc=$?"; fi
  else
    echo "$(date -Is) /mnt/c never came up; skipped mount -a"
  fi
  if ! pgrep -f claude-creds-symlink-watcher >/dev/null 2>&1; then
    nohup /root/.local/bin/claude-creds-symlink-watcher.sh >/dev/null 2>&1 &
    echo "$(date -Is) creds watcher started"
  fi
  # Agent Mail server (no systemd -> no other autostart; reads its own config.env)
  # WSL-native am server is CANONICAL (a Windows-native daemon build hits
  # NTFS durable-write failures in its write-back queue). Bind 0.0.0.0 so
  # mirrored-mode clients on both sides can reach 127.0.0.1:8765.
  if ! pgrep -f "mcp_agent_mail.cli serve-http" >/dev/null 2>&1; then
    nohup /usr/local/bin/am serve-http --host 0.0.0.0 --port 8765 >> /root/.config/mcp-agent-mail/serve.log 2>&1 &
    echo "$(date -Is) agent-mail server started"
  fi
} >> "$LOG" 2>&1
