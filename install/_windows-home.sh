#!/bin/bash
# _windows-home.sh
# Shared helper: resolve the Windows user profile in whichever bash is actually
# running this. `bash` on Windows may be Git Bash, where C:/Users/<name> is a
# valid path, or the WSL launcher (C:\WINDOWS\system32\bash.exe), where only
# /mnt/c/Users/<name> is. Hardcoding one form makes every file assertion fail
# under the other, which reads as a broken install rather than a broken path.
#
# Usage:  . "$(dirname "${BASH_SOURCE[0]}")/_windows-home.sh"
#         WINHOME="$(_resolve_windows_home "$WINUSER")"
#
# Windows .exe files can still be executed by either form (WSL interop handles
# /mnt/c paths), so the result is safe for both file tests and exe invocation.
# Only .cmd/.bat need a Windows-form path.

_resolve_windows_home() {
  local user="$1"
  if [ -n "$user" ] && [ -d "/mnt/c/Users/$user" ]; then
    printf '/mnt/c/Users/%s' "$user"
  elif [ -n "$user" ] && [ -d "C:/Users/$user" ]; then
    printf 'C:/Users/%s' "$user"
  elif [ -d "$HOME/.claude" ] || [ -d "$HOME/.config/opencode" ]; then
    printf '%s' "$HOME"
  else
    return 1
  fi
}

_require_windows_home() {
  local user="$1" resolved
  if ! resolved="$(_resolve_windows_home "$user")"; then
    echo -e "\033[0;31mCannot locate the Windows home for user '$user'.\033[0m" >&2
    echo "Tried /mnt/c/Users/$user, C:/Users/$user, and \$HOME." >&2
    echo "Set WINUSER to the Windows account name and re-run." >&2
    exit 2
  fi
  printf '%s' "$resolved"
}

# The Windows interpreter is `python`; WSL has only `python3`. Resolve once so a
# missing interpreter is never reported as a corrupt binary.
_resolve_python() {
  if command -v python >/dev/null 2>&1; then printf 'python'
  elif command -v python3 >/dev/null 2>&1; then printf 'python3'
  elif command -v py >/dev/null 2>&1; then printf 'py'
  else return 1
  fi
}

