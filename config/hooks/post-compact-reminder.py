"""Post-Compact Reminder - Windows port of Dicklesworthstone's post_compact_reminder.

SessionStart hook (matcher: "compact"). Reads the hook JSON from stdin; if the
session start was caused by context compaction, prints a reminder that Claude
Code injects into the fresh context. Plain ASCII by design (Windows console
codepages). Upstream bash original: github.com/Dicklesworthstone/post_compact_reminder
"""
import codecs
import json
import sys

sys.stdout.reconfigure(encoding="utf-8", errors="replace", line_buffering=True)

BOM = codecs.BOM_UTF8.decode("utf-8")

MESSAGE = """IMPORTANT: Context was just compacted. STOP. You MUST:
1. Re-read the global CLAUDE.md and the project CLAUDE.md (and AGENTS.md if the project has one) NOW
2. Confirm by briefly stating the key rules/conventions and the current task state you found

Do not proceed with any task until you have re-read them and confirmed what you learned."""


def main() -> int:
    try:
        raw = sys.stdin.read()
        payload = json.loads(raw.lstrip(BOM))
    except (json.JSONDecodeError, ValueError):
        return 0
    if payload.get("source") != "compact":
        return 0
    print()
    print(MESSAGE)
    print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
