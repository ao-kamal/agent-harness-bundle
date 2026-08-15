"""Translate Grok Build PreToolUse JSON into the Claude envelope dcg 0.11 understands.

Grok sends toolName=run_terminal_command + toolInput.command.
dcg 0.11 only parses tool_name=Bash + tool_input.command, then fail-opens.
See Dicklesworthstone/destructive_command_guard#319.

Fail-open on parse/exec errors so a broken bridge cannot freeze the session.
"""
import codecs
import json
import os
import shutil
import subprocess
import sys

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
sys.stderr.reconfigure(encoding="utf-8", errors="replace")

BOM = codecs.BOM_UTF8.decode("utf-8")
SHELL_TOOLS = {
    "bash",
    "powershell",
    "shell",
    "run_terminal_command",
    "run_command",
}


def _find_dcg():
    env = os.environ.get("DCG_BIN")
    if env and os.path.isfile(env):
        return env
    home = os.path.expanduser("~")
    candidates = [
        os.path.join(home, ".local", "bin", "dcg.exe"),
        os.path.join(home, ".local", "bin", "dcg"),
    ]
    for path in candidates:
        if os.path.isfile(path):
            return path
    return shutil.which("dcg")


def _extract_command(payload):
    if not isinstance(payload, dict):
        return None
    for key in ("toolInput", "tool_input"):
        block = payload.get(key)
        if isinstance(block, dict):
            command = block.get("command")
            if isinstance(command, str) and command.strip():
                return command
    return None


def _tool_name(payload):
    raw = payload.get("toolName") or payload.get("tool_name") or ""
    return str(raw).strip()


def _to_claude_envelope(payload, command):
    cwd = payload.get("cwd") or payload.get("workspaceRoot") or os.getcwd()
    return {
        "hook_event_name": "PreToolUse",
        "tool_name": "Bash",
        "tool_input": {"command": command},
        "cwd": cwd,
    }


def _emit_deny(reason):
    print(json.dumps({"decision": "deny", "reason": reason}))


def main():
    raw = sys.stdin.read()
    if not raw:
        return 0
    try:
        payload = json.loads(raw.lstrip(BOM))
    except (json.JSONDecodeError, ValueError):
        return 0
    if not isinstance(payload, dict):
        return 0

    tool = _tool_name(payload)
    if tool and tool.lower() not in SHELL_TOOLS:
        return 0

    command = _extract_command(payload)
    if not command:
        return 0

    dcg = _find_dcg()
    if not dcg:
        return 0

    translated = _to_claude_envelope(payload, command)
    try:
        proc = subprocess.run(
            [dcg, "hook"],
            input=json.dumps(translated),
            text=True,
            capture_output=True,
            timeout=12,
        )
    except (OSError, subprocess.TimeoutExpired):
        return 0

    out = (proc.stdout or "").strip()
    decision = None
    if out:
        try:
            parsed = json.loads(out.splitlines()[0])
            if isinstance(parsed, dict):
                decision = parsed.get("decision")
                if decision == "deny":
                    rule = parsed.get("rule_id") or "dcg"
                    reason = (
                        "BLOCKED by dcg ("
                        + str(rule)
                        + "). Run: dcg explain "
                        + json.dumps(command)
                    )
                    _emit_deny(reason)
                    return 0
        except (json.JSONDecodeError, ValueError):
            pass

    if "permissionDecision" in out and "deny" in out:
        _emit_deny("BLOCKED by dcg. Run: dcg explain " + json.dumps(command))
        return 0

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception:
        raise SystemExit(0)
