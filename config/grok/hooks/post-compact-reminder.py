"""Post-compact reminder for Grok and Claude.

Grok fires PreCompact / PostCompact (trigger auto|manual). Those events are
observe-only on stdout, so this script also emits additionalContext.

Claude SessionStart with source=compact still gets the plain-text stdout form.
"""
import codecs
import json
import sys

sys.stdout.reconfigure(encoding="utf-8", errors="replace", line_buffering=True)

BOM = codecs.BOM_UTF8.decode("utf-8")

MESSAGE = """IMPORTANT: Context was just compacted. STOP. You MUST:
1. Re-read the global AGENTS.md (and the project AGENTS.md / CLAUDE.md if present) NOW
2. Confirm by briefly stating the key rules/conventions and the current task state you found

Do not proceed with any task until you have re-read them and confirmed what you learned."""


def main() -> int:
    try:
        raw = sys.stdin.read()
        payload = json.loads(raw.lstrip(BOM))
    except (json.JSONDecodeError, ValueError):
        return 0
    if not isinstance(payload, dict):
        return 0

    event = str(
        payload.get("hookEventName")
        or payload.get("hook_event_name")
        or ""
    ).lower().replace("-", "_")
    source = str(payload.get("source") or payload.get("trigger") or "").lower()

    grok_compact = event in ("pre_compact", "post_compact")
    claude_compact = source == "compact"
    if not grok_compact and not claude_compact:
        return 0

    if grok_compact:
        hook_name = "PostCompact" if "post" in event else "PreCompact"
        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": hook_name,
                "additionalContext": MESSAGE,
            }
        }))
        return 0

    print()
    print(MESSAGE)
    print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
