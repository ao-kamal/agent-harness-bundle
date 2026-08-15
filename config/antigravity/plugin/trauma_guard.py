#!/usr/bin/env python3
"""
Dynamic Trauma Guard.
Reads from ~/.cass-memory/traumas.jsonl and .cass/traumas.jsonl to enforce safety.

Accepts Claude (tool_input), Grok (toolInput), and Antigravity (toolCall) hook envelopes.
"""
import json
import sys
import re
import os
from pathlib import Path

GLOBAL_TRAUMA_FILE = Path.home() / ".cass-memory" / "traumas.jsonl"

def find_repo_root():
    """Find the root of the current git repository."""
    curr = Path.cwd()
    while curr != curr.parent:
        if (curr / ".git").exists():
            return curr
        curr = curr.parent
    return None

def load_traumas():
    """Load active traumas from global and project storage."""
    traumas = []

    if GLOBAL_TRAUMA_FILE.exists():
        try:
            with open(GLOBAL_TRAUMA_FILE, "r", encoding="utf-8") as f:
                for line in f:
                    if line.strip():
                        try:
                            t = json.loads(line)
                            if isinstance(t, dict) and t.get("status") == "active":
                                traumas.append(t)
                        except Exception:
                            pass
        except Exception:
            pass

    repo_root = find_repo_root()
    if repo_root:
        repo_file = repo_root / ".cass" / "traumas.jsonl"
        if repo_file.exists():
            try:
                with open(repo_file, "r", encoding="utf-8") as f:
                    for line in f:
                        if line.strip():
                            try:
                                t = json.loads(line)
                                if isinstance(t, dict) and t.get("status") == "active":
                                    traumas.append(t)
                            except Exception:
                                pass
            except Exception:
                pass

    return traumas

def check_command(command, traumas):
    """Check command against trauma patterns."""
    for trauma in traumas:
        if not isinstance(trauma, dict):
            continue

        pattern = trauma.get("pattern")
        if not isinstance(pattern, str) or not pattern:
            continue

        try:
            if re.search(pattern, command, re.IGNORECASE):
                return trauma
        except re.error:
            continue
    return None

def extract_command(input_data):
    """Pull the shell command out of Grok, Claude, or Antigravity hook JSON."""
    if not isinstance(input_data, dict):
        return None

    for key in ("toolInput", "tool_input"):
        tool_input = input_data.get(key)
        if isinstance(tool_input, dict):
            command = tool_input.get("command")
            if isinstance(command, str) and command:
                return command

    tool_call = input_data.get("toolCall")
    if isinstance(tool_call, dict):
        args = tool_call.get("args") or {}
        if isinstance(args, dict):
            command = args.get("CommandLine") or args.get("command")
            if isinstance(command, str) and command:
                return command

    return None

def main():
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)

    if not isinstance(input_data, dict):
        sys.exit(0)

    command = extract_command(input_data)
    if not isinstance(command, str) or not command:
        sys.exit(0)

    traumas = load_traumas()
    match = check_command(command, traumas)

    if match:
        trigger = match.get("trigger_event")
        if not isinstance(trigger, dict):
            trigger = {}
        msg = trigger.get("human_message") or "You previously caused a catastrophe with this command."
        ref = trigger.get("session_path") or "unknown"
        pattern = match.get("pattern") or "<unknown>"
        trauma_id = match.get("id") or "<unknown>"

        use_emoji = os.environ.get("CASS_MEMORY_NO_EMOJI") is None
        banner = (
            "\U0001F525 HOT STOVE: VISCERAL SAFETY INTERVENTION \U0001F525"
            if use_emoji
            else "[HOT STOVE] VISCERAL SAFETY INTERVENTION"
        )

        reason_str = (
            f"{banner}\n\n"
            f"BLOCKED: This pattern matches a registered TRAUMA.\n"
            f"Pattern: {pattern}\n"
            f"Reason: {msg}\n"
            f"Reference: {ref}\n\n"
            f"If you MUST run this, heal it first with: cm trauma heal {trauma_id}"
        )

        output = {
            "decision": "deny",
            "reason": reason_str,
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": reason_str
            }
        }
        print(json.dumps(output))
        sys.exit(0)

    sys.exit(0)

if __name__ == "__main__":
    main()
