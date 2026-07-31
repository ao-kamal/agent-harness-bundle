---
name: detect-forgotten-sessions-post-crash
description: Detect Codex and Claude sessions that were likely forgotten after a kernel panic, watchdog timeout, reboot, or crash. Use when the user wants to reconstruct interrupted work, group crash-time sessions by project, determine which sessions were resumed later, and identify likely-forgotten sessions from local transcript files and panic logs.
license: MIT
distribution: public
---

# Detect Forgotten Sessions Post Crash

Use this skill to answer one question reliably: after a crash, which sessions were interrupted and never picked back up?

## Workflow

1. Find crash windows from panic files first.
   Use `scripts/detect_forgotten_sessions.py` instead of guessing from timestamps by hand.
   The script reads:
   - `/Library/Logs/DiagnosticReports/`
   - `/Library/Logs/DiagnosticReports/Retired/`

2. Scan local transcript stores around each crash window.
   The script checks:
   - `~/.codex/sessions/**/*.jsonl`
   - `~/.claude/projects/**/*.jsonl`
   - `~/.codex/history.jsonl`
   - `~/.claude/history.jsonl`

3. Treat crash-window sessions as interrupted unless they end cleanly.
   Use these heuristics:
   - Codex:
     - `task_complete` means finished
     - `turn_aborted` means aborted
     - `session_meta.cwd`, command `cwd`, or a `You are in \`...\`` prompt can recover the project directory
     - no `task_complete` near the crash window means interrupted
   - Claude:
     - last meaningful record is assistant text means likely finished
     - last meaningful record is assistant `tool_use`, user `tool_result`, metadata trailer, or truncated tail means interrupted

4. Normalize projects before grouping.
   Claude project slugs like `-Users-example-workspace-sample-project` should be mapped back to real paths when possible so cross-tool continuations are visible.

5. Decide forgotten vs continued.
   Default rule:
   - only `continued_topic_match` counts as resumed work
   - a same-project follow-on with weak evidence is `ambiguous_same_project_follow_on`, not resumed
   - if no later same-project top-level session exists, treat the session as forgotten

6. Report uncertainty explicitly.
   Use `ambiguous_same_project_follow_on` when the project resumed later but prompt evidence is weak or incomplete.
   Use `continued_topic_match` when later prompt text overlaps strongly enough to count as resumed.
   Use `forgotten` when no credible continuation is found.

7. Resume only the relevant sessions.
   Default priority:
   - `forgotten`: resume first
   - `ambiguous_same_project_follow_on`: resume if the work still matters
   - `continued_topic_match`: usually do not resume unless the user wants the exact original thread

   Resume from inside the project working directory.
   The script prints exact commands for each session:
   - Codex: `cd /path/to/project && codex resume <session_id> '<resume prompt>'`
   - Claude: `cd /path/to/project && claude -r <session_id>`
   - Claude safe branch: `cd /path/to/project && claude -r <session_id> --fork-session`

   When resuming, first ask the agent to:
   - reconstruct the unfinished objective
   - identify the last completed step
   - identify the next concrete action
   - avoid repeating already completed work

## Recovery Triage

Not every interrupted session is worth resuming immediately. Use the detector's
priority metadata to decide what to recover first.

Prioritize in this order:
- `forgotten` before `ambiguous_same_project_follow_on`
- higher `recovery_priority` before lower
- sessions with larger `file_size_bytes`
- sessions with more subagents
- sessions that ended closest to the crash time

Manual checks that raise recovery priority:
- the session was editing code in a repo with uncommitted changes
- the session was working on a branch with local commits not pushed upstream
- the session stopped during a tool call, review pass, or multi-agent run

Useful follow-up checks from the project directory:

```bash
git status --short
git log --branches --not --remotes --oneline
```

## What Usually Survives a Crash

In most cases, these artifacts survive and are worth inspecting before resuming:
- the saved conversation transcript
- completed tool results already written into the transcript
- files already written to disk before the crash
- committed local git history

State that may need to be reconstructed:
- in-flight tool calls that never returned
- subagent work that had not yet been delivered back to the parent
- runtime-only context such as process state, open sockets, and temporary command output

## Commands

Run the default weekly report:

```bash
python3 scripts/detect_forgotten_sessions.py --days 7
```

Write machine-readable output:

```bash
python3 scripts/detect_forgotten_sessions.py --days 7 --format json
```

Tighten the crash window:

```bash
python3 scripts/detect_forgotten_sessions.py --days 7 --window-secs 900
```

Limit the analysis to one project:

```bash
python3 scripts/detect_forgotten_sessions.py --days 7 --project sample-project
```

Export a single crash bundle and zip:

```bash
python3 scripts/detect_forgotten_sessions.py \
  --days 7 \
  --crash 2026-04-16 \
  --project sample-project \
  --export-dir /tmp/detect-forgotten-sessions \
  --zip-path /tmp/detect-forgotten-sessions-2026-04-16.zip
```

Print only actionable resume commands for relevant sessions:

```bash
python3 scripts/detect_forgotten_sessions.py --days 7 --resume-only
```

## Interpretation Rules

- Prefer top-level sessions for the forgotten/not-forgotten decision.
- Treat subagents as attached to their parent top-level session unless the user explicitly wants subagent-by-subagent analysis.
- Do not claim a session was finished just because the same repo was active later if the later work is clearly unrelated.
- Same-project-only follow-ons do not count as resumed work unless the prompt evidence is strong enough for `continued_topic_match`.
- If panic files are missing, say so and fall back to approximate windows from session mtimes instead of pretending certainty.
- Prefer `cd` into the working directory before resuming so the restored session starts in the correct project context.
- Prefer `--resume-only` when the user wants an operator-facing recovery list instead of a full analytical report.

## Output Shape

Prefer this structure:

- crash window
- project
- interrupted sessions
- later continuation sessions
- classification: `continued_topic_match`, `ambiguous_same_project_follow_on`, or `forgotten`
- recovery priority: `high`, `medium`, or `low`
- confidence note for ambiguous cases

## Resources

### scripts/

- `scripts/detect_forgotten_sessions.py`
  Scan panic logs and local transcript stores, group interrupted sessions by crash and project, and classify likely-forgotten work.
