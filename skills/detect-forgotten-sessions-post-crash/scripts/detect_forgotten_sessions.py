#!/usr/bin/env python3
"""
Detect Codex and Claude sessions interrupted by recent crashes and classify
whether they were likely resumed later or forgotten.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import tempfile
import zipfile
from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime, timedelta
from functools import lru_cache
from pathlib import Path
from typing import Iterable


UUID_RE = re.compile(r"([0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12})$")
WORD_RE = re.compile(r"[A-Za-z0-9_./:-]+")
PROMPT_CWD_RE = re.compile(r"You are in `([^`]+)`")
STOP_WORDS = {
    "the",
    "a",
    "an",
    "and",
    "or",
    "to",
    "of",
    "in",
    "for",
    "on",
    "with",
    "from",
    "by",
    "do",
    "did",
    "does",
    "this",
    "that",
    "it",
    "is",
    "are",
    "was",
    "were",
    "be",
    "been",
    "being",
    "as",
    "at",
    "into",
    "use",
    "using",
    "you",
    "your",
    "me",
    "my",
    "we",
    "our",
    "can",
    "could",
    "should",
    "would",
    "who",
    "what",
    "when",
    "where",
    "why",
    "how",
    "look",
    "inspect",
    "check",
    "read",
    "pull",
    "create",
    "make",
    "add",
    "update",
    "implement",
    "review",
    "trace",
    "fix",
    "all",
    "any",
    "remaining",
    "work",
    "code",
    "repo",
    "directory",
    "crash",
    "session",
    "sessions",
    "project",
    "after",
    "before",
    "post",
    "today",
    "yesterday",
    "root",
    "cause",
    "analysis",
    "report",
}


@dataclass
class Crash:
    path: Path
    timestamp: float
    label: str


@dataclass
class SessionRecord:
    kind: str
    path: Path
    session_id: str
    parent_session_id: str | None
    project_slug: str
    project_path: str
    is_subagent: bool
    mtime: float
    file_size_bytes: int
    prompt_text: str
    terminal_shape: str
    completed: bool
    interrupted: bool


@dataclass
class ContinuationResult:
    classification: str
    counts_as_resumed: bool
    later_session: SessionRecord | None
    token_overlap: int
    anchor_overlap: int
    jaccard: float
    reason: str


@dataclass
class AnalyzedSession:
    session: SessionRecord
    continuation: ContinuationResult
    subagents: list[SessionRecord]


@dataclass
class CrashAnalysis:
    crash: Crash
    projects: dict[str, list[AnalyzedSession]]


def load_jsonl_lines(path: Path) -> list[dict]:
    parsed: list[dict] = []
    try:
        lines = path.read_text(errors="replace").splitlines()
    except OSError:
        return parsed
    for line in lines:
        try:
            parsed.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return parsed


def discover_crashes(days: int) -> list[Crash]:
    cutoff = datetime.now().astimezone() - timedelta(days=days)
    roots = [
        Path("/Library/Logs/DiagnosticReports"),
        Path("/Library/Logs/DiagnosticReports/Retired"),
    ]
    patterns = ("panic-full-*.panic", "Kernel_*.panic", "panic-full-*.ips", "Kernel_*.ips")
    crashes: list[Crash] = []
    seen: set[Path] = set()
    for root in roots:
        if not root.exists():
            continue
        for pattern in patterns:
            for path in root.glob(pattern):
                if path in seen:
                    continue
                seen.add(path)
                try:
                    st = path.stat()
                except OSError:
                    continue
                dt = datetime.fromtimestamp(st.st_mtime).astimezone()
                if dt < cutoff:
                    continue
                crashes.append(Crash(path=path, timestamp=st.st_mtime, label=dt.strftime("%Y-%m-%d %H:%M:%S %Z")))
    crashes.sort(key=lambda item: item.timestamp)
    return crashes


def select_crashes(crashes: list[Crash], crash_filter: str | None) -> list[Crash]:
    if not crash_filter:
        return crashes
    needle = crash_filter.casefold()
    matched = [
        crash
        for crash in crashes
        if needle in crash.label.casefold()
        or needle in crash.path.name.casefold()
        or needle in str(crash.path).casefold()
    ]
    return matched


def extract_codex_uuid(path: Path) -> str:
    match = UUID_RE.search(path.stem)
    return match.group(1) if match else path.stem


def normalize_claude_project(slug: str) -> str:
    if not slug.startswith("-"):
        return slug
    resolved = resolve_slug_to_existing_path(slug)
    if resolved:
        return resolved
    parts = [segment for segment in slug.split("-") if segment]
    if not parts:
        return slug
    return "/" + "/".join(parts)


def encoded_segment_tokens(name: str) -> list[str]:
    encoded = name
    if encoded.startswith("."):
        encoded = "-" + encoded[1:]
    return encoded.split("-")


@lru_cache(maxsize=2048)
def list_dir_entries(path_str: str) -> tuple[str, ...]:
    try:
        return tuple(sorted(entry.name for entry in os.scandir(path_str)))
    except OSError:
        return ()


def resolve_slug_to_existing_path(slug: str) -> str | None:
    tokens = slug.lstrip("-").split("-")
    if not tokens:
        return None
    matches = match_slug_tokens(Path("/"), tokens, 0)
    return str(matches[0]) if matches else None


def match_slug_tokens(base: Path, tokens: list[str], index: int) -> list[Path]:
    if index == len(tokens):
        return [base]

    matches: list[Path] = []
    for name in list_dir_entries(str(base)):
        child_tokens = encoded_segment_tokens(name)
        width = len(child_tokens)
        if tokens[index : index + width] != child_tokens:
            continue
        child = base / name
        matches.extend(match_slug_tokens(child, tokens, index + width))
    return matches


def infer_codex_project(lines: list[dict]) -> str:
    for obj in lines[:40]:
        if obj.get("type") == "session_meta":
            cwd = obj.get("payload", {}).get("cwd")
            if cwd:
                return cwd
    for obj in lines[:120]:
        if obj.get("type") == "event_msg" and obj.get("payload", {}).get("type") == "exec_command_end":
            cwd = obj.get("payload", {}).get("cwd")
            if cwd:
                return cwd
    for obj in lines[:40]:
        if obj.get("type") != "response_item":
            continue
        payload = obj.get("payload", {})
        if payload.get("role") != "user":
            continue
        for item in payload.get("content", []):
            if not isinstance(item, dict) or item.get("type") != "input_text":
                continue
            text = item.get("text", "")
            match = PROMPT_CWD_RE.search(text)
            if match:
                return match.group(1)
    return "unknown-codex-project"


def index_codex_history() -> dict[str, list[str]]:
    history_path = Path.home() / ".codex/history.jsonl"
    prompts: dict[str, list[str]] = defaultdict(list)
    if not history_path.exists():
        return prompts
    for line in history_path.read_text(errors="replace").splitlines():
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        session_id = obj.get("session_id")
        text = obj.get("text")
        if session_id and isinstance(text, str) and text.strip():
            prompts[session_id].append(text.strip())
    return prompts


def index_claude_history() -> dict[str, list[str]]:
    history_path = Path.home() / ".claude/history.jsonl"
    prompts: dict[str, list[str]] = defaultdict(list)
    if not history_path.exists():
        return prompts
    for line in history_path.read_text(errors="replace").splitlines():
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        session_id = obj.get("sessionId")
        display = obj.get("display")
        if session_id and isinstance(display, str) and display.strip():
            prompts[session_id].append(display.strip())
    return prompts


def claude_terminal_shape(lines: list[dict]) -> tuple[str, bool, bool]:
    meaningful = []
    for obj in lines:
        typ = obj.get("type")
        if typ in {"last-prompt", "permission-mode", "system", "attachment"}:
            continue
        meaningful.append(obj)

    last = meaningful[-1] if meaningful else None
    if not last:
        return ("empty", False, True)

    if last.get("type") == "assistant":
        content = last.get("message", {}).get("content", [])
        item_types = {item.get("type") for item in content if isinstance(item, dict)}
        if "tool_use" in item_types:
            return ("assistant_tool_use", False, True)
        return ("assistant_final_text", True, False)

    if last.get("type") == "user":
        content = last.get("message", {}).get("content", [])
        for item in content:
            if isinstance(item, dict) and item.get("type") == "tool_result":
                return ("user_tool_result_pending", False, True)
        return ("user_prompt_pending", False, True)

    return (str(last.get("type", "unknown")), False, True)


def codex_terminal_shape(lines: list[dict]) -> tuple[str, bool, bool]:
    tail = lines[-20:]
    for obj in tail:
        if obj.get("type") == "event_msg" and obj.get("payload", {}).get("type") == "task_complete":
            return ("task_complete", True, False)
    for obj in tail:
        if obj.get("type") == "event_msg" and obj.get("payload", {}).get("type") == "turn_aborted":
            return ("turn_aborted", False, True)
    last = tail[-1] if tail else None
    if not last:
        return ("empty", False, True)
    if last.get("type") == "response_item" and last.get("payload", {}).get("type") == "function_call":
        return ("pending_function_call", False, True)
    return (f"open_{last.get('type', 'unknown')}", False, True)


def prompt_tokens(text: str) -> set[str]:
    return {
        token.lower()
        for token in WORD_RE.findall(text)
        if len(token) > 2 and token.lower() not in STOP_WORDS
    }


def anchor_tokens(text: str) -> set[str]:
    anchors = set()
    for token in prompt_tokens(text):
        if any(ch.isdigit() for ch in token) or "/" in token or "." in token or "-" in token or len(token) >= 8:
            anchors.add(token)
    return anchors


def prompt_preview(text: str, limit: int = 160) -> str:
    if not text:
        return ""
    line = text.splitlines()[0].strip()
    return line[:limit]


def shell_quote(value: str) -> str:
    return "'" + value.replace("'", "'\"'\"'") + "'"


def project_matches(session: SessionRecord, project_filter: str | None) -> bool:
    if not project_filter:
        return True
    needle = project_filter.casefold()
    return needle in session.project_path.casefold() or needle in session.project_slug.casefold()


def working_dir_for_session(session: SessionRecord) -> str | None:
    if session.project_path.startswith("/"):
        return session.project_path
    return None


def resume_prompt_for_session(item: AnalyzedSession) -> str:
    session = item.session
    preview = prompt_preview(session.prompt_text, 120)
    base = (
        "Resume the crash-interrupted work from this session. "
        "First reconstruct the unfinished objective, last completed step, and next concrete action from the transcript and repo state."
    )
    if preview:
        base += f" Original prompt: {preview}"
    if item.continuation.classification == "continued_topic_match":
        base += " A later session already resumed this topic, so only continue here if you need the exact original thread."
    elif item.continuation.classification == "ambiguous_same_project_follow_on":
        base += " The project was active later, but topic continuity is not proven; verify relevance before doing new work."
    else:
        base += " No credible later continuation was found, so treat this as likely forgotten work."
    return base


def resume_commands_for_session(item: AnalyzedSession) -> tuple[str | None, str | None]:
    session = item.session
    prompt = resume_prompt_for_session(item)
    cwd = working_dir_for_session(session)

    if session.kind == "codex":
        resume_core = f"codex resume {session.session_id} {shell_quote(prompt)}"
        resume = f"cd {shell_quote(cwd)} && {resume_core}" if cwd else resume_core
        return resume, None

    if session.kind == "claude":
        if cwd:
            resume = f"cd {shell_quote(cwd)} && claude -r {session.session_id}"
            fork = f"cd {shell_quote(cwd)} && claude -r {session.session_id} --fork-session"
        else:
            resume = f"claude -r {session.session_id}"
            fork = f"claude -r {session.session_id} --fork-session"
        return resume, fork

    return None, None


def discover_sessions(days: int) -> list[SessionRecord]:
    cutoff = datetime.now().astimezone() - timedelta(days=days)
    codex_history = index_codex_history()
    claude_history = index_claude_history()
    records: list[SessionRecord] = []

    for path in Path.home().joinpath(".codex/sessions").glob("**/*.jsonl"):
        try:
            st = path.stat()
        except OSError:
            continue
        dt = datetime.fromtimestamp(st.st_mtime).astimezone()
        if dt < cutoff:
            continue
        lines = load_jsonl_lines(path)
        session_id = extract_codex_uuid(path)
        prompt_text = "\n".join(codex_history.get(session_id, [])[:3]).strip()
        project = infer_codex_project(lines)
        terminal_shape, completed, interrupted = codex_terminal_shape(lines)
        records.append(
            SessionRecord(
                kind="codex",
                path=path,
                session_id=session_id,
                parent_session_id=None,
                project_slug=project,
                project_path=project,
                is_subagent=False,
                mtime=st.st_mtime,
                file_size_bytes=st.st_size,
                prompt_text=prompt_text,
                terminal_shape=terminal_shape,
                completed=completed,
                interrupted=interrupted,
            )
        )

    for path in Path.home().joinpath(".claude/projects").glob("**/*.jsonl"):
        try:
            st = path.stat()
        except OSError:
            continue
        dt = datetime.fromtimestamp(st.st_mtime).astimezone()
        if dt < cutoff:
            continue
        lines = load_jsonl_lines(path)
        parts = path.parts
        is_subagent = "subagents" in parts
        parent_session_id = None
        if is_subagent:
            idx = parts.index("subagents")
            parent_session_id = parts[idx - 1].replace(".jsonl", "")
        session_id = path.stem
        project_slug = path.parts[path.parts.index("projects") + 1] if "projects" in path.parts else "unknown-claude-project"
        prompt_key = parent_session_id if is_subagent and parent_session_id else session_id
        prompt_text = "\n".join(claude_history.get(prompt_key, [])[:3]).strip()
        terminal_shape, completed, interrupted = claude_terminal_shape(lines)
        records.append(
            SessionRecord(
                kind="claude",
                path=path,
                session_id=session_id,
                parent_session_id=parent_session_id,
                project_slug=project_slug,
                project_path=normalize_claude_project(project_slug),
                is_subagent=is_subagent,
                mtime=st.st_mtime,
                file_size_bytes=st.st_size,
                prompt_text=prompt_text,
                terminal_shape=terminal_shape,
                completed=completed,
                interrupted=interrupted,
            )
        )

    return records


def classify_continuation(session: SessionRecord, later_sessions: Iterable[SessionRecord]) -> ContinuationResult:
    source_tokens = prompt_tokens(session.prompt_text)
    source_anchors = anchor_tokens(session.prompt_text)
    best_candidate: SessionRecord | None = None
    best_token_overlap = 0
    best_anchor_overlap = 0
    best_jaccard = 0.0
    best_gap_seconds = 0.0

    for candidate in later_sessions:
        if candidate.is_subagent:
            continue
        if candidate.project_path != session.project_path:
            continue
        if candidate.mtime <= session.mtime:
            continue

        candidate_tokens = prompt_tokens(candidate.prompt_text)
        candidate_anchors = anchor_tokens(candidate.prompt_text)
        token_overlap = len(source_tokens & candidate_tokens)
        anchor_overlap = len(source_anchors & candidate_anchors)
        union = len(source_tokens | candidate_tokens)
        jaccard = (token_overlap / union) if union else 0.0

        if (
            anchor_overlap > best_anchor_overlap
            or (anchor_overlap == best_anchor_overlap and token_overlap > best_token_overlap)
            or (
                anchor_overlap == best_anchor_overlap
                and token_overlap == best_token_overlap
                and jaccard > best_jaccard
            )
        ):
            best_candidate = candidate
            best_token_overlap = token_overlap
            best_anchor_overlap = anchor_overlap
            best_jaccard = jaccard
            best_gap_seconds = candidate.mtime - session.mtime

    if not best_candidate:
        return ContinuationResult(
            classification="forgotten",
            counts_as_resumed=False,
            later_session=None,
            token_overlap=0,
            anchor_overlap=0,
            jaccard=0.0,
            reason="no later top-level session in the same project",
        )

    if best_anchor_overlap >= 1 and best_token_overlap >= 2:
        return ContinuationResult(
            classification="continued_topic_match",
            counts_as_resumed=True,
            later_session=best_candidate,
            token_overlap=best_token_overlap,
            anchor_overlap=best_anchor_overlap,
            jaccard=best_jaccard,
            reason="shared specific anchors and topic tokens",
        )

    if best_token_overlap >= 4 and best_jaccard >= 0.18:
        return ContinuationResult(
            classification="continued_topic_match",
            counts_as_resumed=True,
            later_session=best_candidate,
            token_overlap=best_token_overlap,
            anchor_overlap=best_anchor_overlap,
            jaccard=best_jaccard,
            reason="strong lexical overlap across prompts",
        )

    if session.prompt_text and best_candidate.prompt_text and best_anchor_overlap >= 1 and best_gap_seconds <= 6 * 60 * 60:
        return ContinuationResult(
            classification="ambiguous_same_project_follow_on",
            counts_as_resumed=False,
            later_session=best_candidate,
            token_overlap=best_token_overlap,
            anchor_overlap=best_anchor_overlap,
            jaccard=best_jaccard,
            reason="same project and one shared anchor, but topic match is weak",
        )

    if best_token_overlap >= 2 and best_gap_seconds <= 6 * 60 * 60:
        return ContinuationResult(
            classification="ambiguous_same_project_follow_on",
            counts_as_resumed=False,
            later_session=best_candidate,
            token_overlap=best_token_overlap,
            anchor_overlap=best_anchor_overlap,
            jaccard=best_jaccard,
            reason="same project follow-on exists soon after the crash, but overlap is too generic to count as resumed",
        )

    if not session.prompt_text or not best_candidate.prompt_text:
        return ContinuationResult(
            classification="ambiguous_same_project_follow_on",
            counts_as_resumed=False,
            later_session=best_candidate,
            token_overlap=best_token_overlap,
            anchor_overlap=best_anchor_overlap,
            jaccard=best_jaccard,
            reason="same project follow-on exists but prompt evidence is incomplete",
        )

    return ContinuationResult(
        classification="forgotten",
        counts_as_resumed=False,
        later_session=best_candidate,
        token_overlap=best_token_overlap,
        anchor_overlap=best_anchor_overlap,
        jaccard=best_jaccard,
        reason="same project resumed later, but the prompt overlap is too generic to treat as continuation",
    )


def analyze_crashes(
    crashes: list[Crash],
    sessions: list[SessionRecord],
    window_secs: int,
    project_filter: str | None,
) -> list[CrashAnalysis]:
    top_level = [item for item in sessions if not item.is_subagent]
    subagents_by_parent: dict[str, list[SessionRecord]] = defaultdict(list)
    for item in sessions:
        if item.is_subagent and item.parent_session_id:
            subagents_by_parent[item.parent_session_id].append(item)

    analyses: list[CrashAnalysis] = []
    for crash in crashes:
        candidates = [
            item
            for item in top_level
            if item.interrupted
            and abs(item.mtime - crash.timestamp) <= window_secs
            and project_matches(item, project_filter)
        ]
        if not candidates:
            continue

        future_top_level = [item for item in top_level if item.mtime > crash.timestamp]
        grouped: dict[str, list[AnalyzedSession]] = defaultdict(list)
        for item in sorted(candidates, key=lambda row: row.mtime):
            grouped[item.project_path].append(
                AnalyzedSession(
                    session=item,
                    continuation=classify_continuation(item, future_top_level),
                    subagents=subagents_by_parent.get(item.session_id, []),
                )
            )
        analyses.append(CrashAnalysis(crash=crash, projects=dict(sorted(grouped.items()))))
    return analyses


def analyzed_session_to_dict(item: AnalyzedSession) -> dict:
    later = item.continuation.later_session
    resume_command, fork_command = resume_commands_for_session(item)
    return {
        "kind": item.session.kind,
        "session_id": item.session.session_id,
        "path": str(item.session.path),
        "terminal_shape": item.session.terminal_shape,
        "file_size_bytes": item.session.file_size_bytes,
        "prompt_text": item.session.prompt_text,
        "classification": item.continuation.classification,
        "counts_as_resumed": item.continuation.counts_as_resumed,
        "reason": item.continuation.reason,
        "token_overlap": item.continuation.token_overlap,
        "anchor_overlap": item.continuation.anchor_overlap,
        "jaccard": round(item.continuation.jaccard, 3),
        "resume_command": resume_command,
        "fork_command": fork_command,
        "resume_prompt": resume_prompt_for_session(item),
        "later_session_id": later.session_id if later else None,
        "later_path": str(later.path) if later else None,
        "later_terminal_shape": later.terminal_shape if later else None,
        "later_prompt_text": later.prompt_text if later else None,
        "subagents": [
            {
                "kind": sub.kind,
                "session_id": sub.session_id,
                "path": str(sub.path),
                "terminal_shape": sub.terminal_shape,
            }
            for sub in item.subagents
        ],
    }


def compute_recovery_priority(item: AnalyzedSession, crash: Crash) -> tuple[int, str]:
    session = item.session
    classification = item.continuation.classification

    if classification == "forgotten":
        score = 100
    elif classification == "ambiguous_same_project_follow_on":
        score = 65
    else:
        score = 20

    gap_seconds = int(abs(crash.timestamp - session.mtime))
    if gap_seconds <= 120:
        score += 20
    elif gap_seconds <= 300:
        score += 12
    elif gap_seconds <= 600:
        score += 6

    if session.file_size_bytes >= 1_000_000:
        score += 20
    elif session.file_size_bytes >= 250_000:
        score += 12
    elif session.file_size_bytes >= 50_000:
        score += 6

    if len(item.subagents) >= 8:
        score += 10
    elif len(item.subagents) >= 3:
        score += 5

    if session.kind == "codex":
        score += 2

    if score >= 120:
        label = "high"
    elif score >= 80:
        label = "medium"
    else:
        label = "low"
    return score, label


def recovery_priority_fields(item: AnalyzedSession, crash: Crash) -> dict[str, int | str]:
    score, label = compute_recovery_priority(item, crash)
    return {
        "seconds_from_crash": int(abs(crash.timestamp - item.session.mtime)),
        "recovery_priority_score": score,
        "recovery_priority": label,
    }


def crash_analysis_to_dict(analysis: CrashAnalysis, window_secs: int) -> dict:
    return {
        "crash_label": analysis.crash.label,
        "crash_path": str(analysis.crash.path),
        "crash_window_start": datetime.fromtimestamp(analysis.crash.timestamp - window_secs).astimezone().isoformat(),
        "crash_window_end": datetime.fromtimestamp(analysis.crash.timestamp + window_secs).astimezone().isoformat(),
        "projects": {
            project: [
                {
                    **analyzed_session_to_dict(item),
                    **recovery_priority_fields(item, analysis.crash),
                }
                for item in items
            ]
            for project, items in analysis.projects.items()
        },
    }


def actionable_resume_sessions(analyses: list[CrashAnalysis]) -> list[tuple[Crash, str, AnalyzedSession]]:
    rows: list[tuple[Crash, str, AnalyzedSession]] = []
    for analysis in analyses:
        for project, items in analysis.projects.items():
            for item in items:
                if item.continuation.classification in {"forgotten", "ambiguous_same_project_follow_on"}:
                    rows.append((analysis.crash, project, item))
    rows.sort(
        key=lambda row: (
            recovery_priority_fields(row[2], row[0])["recovery_priority_score"],
            -recovery_priority_fields(row[2], row[0])["seconds_from_crash"],
            row[2].session.file_size_bytes,
        ),
        reverse=True,
    )
    return rows


def render_markdown(analyses: list[CrashAnalysis], window_secs: int) -> str:
    lines: list[str] = []
    for analysis in analyses:
        crash = analysis.crash
        window_start = datetime.fromtimestamp(crash.timestamp - window_secs).astimezone().strftime("%Y-%m-%d %H:%M:%S %Z")
        window_end = datetime.fromtimestamp(crash.timestamp + window_secs).astimezone().strftime("%Y-%m-%d %H:%M:%S %Z")
        lines.append(f"## Crash {crash.label}")
        lines.append(f"`{crash.path}`")
        lines.append(f"window: `{window_start}` -> `{window_end}`")
        for project, items in analysis.projects.items():
            lines.append(f"### Project `{project}`")
            for item in items:
                session = item.session
                continuation = item.continuation
                priority = recovery_priority_fields(item, crash)
                lines.append(
                    f"- `{session.kind}` `{session.session_id}` `{session.terminal_shape}` `{continuation.classification}` resumed={str(continuation.counts_as_resumed).lower()}"
                )
                preview = prompt_preview(session.prompt_text)
                if preview:
                    lines.append(f"  prompt: {preview}")
                if item.subagents:
                    lines.append(f"  subagents: {len(item.subagents)}")
                lines.append(
                    f"  priority: `{priority['recovery_priority']}` score={priority['recovery_priority_score']} size={session.file_size_bytes}B seconds_from_crash={priority['seconds_from_crash']}"
                )
                lines.append(
                    f"  reason: {continuation.reason} token_overlap={continuation.token_overlap} anchor_overlap={continuation.anchor_overlap} jaccard={continuation.jaccard:.3f}"
                )
                resume_command, fork_command = resume_commands_for_session(item)
                if resume_command:
                    lines.append(f"  resume: `{resume_command}`")
                if fork_command:
                    lines.append(f"  fork: `{fork_command}`")
                if continuation.later_session:
                    later = continuation.later_session
                    lines.append(
                        f"  later: `{later.kind}` `{later.session_id}` `{later.terminal_shape}`"
                    )
                    later_preview = prompt_preview(later.prompt_text)
                    if later_preview:
                        lines.append(f"  later prompt: {later_preview}")
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def render_json(analyses: list[CrashAnalysis], window_secs: int) -> str:
    return json.dumps([crash_analysis_to_dict(item, window_secs) for item in analyses], indent=2)


def render_resume_only(analyses: list[CrashAnalysis]) -> str:
    rows = actionable_resume_sessions(analyses)
    lines: list[str] = []
    for crash, project, item in rows:
        resume_command, fork_command = resume_commands_for_session(item)
        priority = recovery_priority_fields(item, crash)
        lines.append(f"## Crash {crash.label}")
        lines.append(f"project: `{project}`")
        lines.append(
            f"session: `{item.session.kind}` `{item.session.session_id}` `{item.continuation.classification}`"
        )
        lines.append(
            f"priority: `{priority['recovery_priority']}` score={priority['recovery_priority_score']} size={item.session.file_size_bytes}B seconds_from_crash={priority['seconds_from_crash']}"
        )
        lines.append(f"reason: {item.continuation.reason}")
        preview = prompt_preview(item.session.prompt_text)
        if preview:
            lines.append(f"prompt: {preview}")
        if resume_command:
            lines.append(f"resume: `{resume_command}`")
        if fork_command:
            lines.append(f"fork: `{fork_command}`")
        lines.append("")
    return "\n".join(lines).rstrip() + ("\n" if lines else "")


def sanitize_name(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9._-]+", "-", value).strip("-") or "export"


def resolve_output_dir(base_dir: Path, crash: Crash) -> Path:
    base_dir.mkdir(parents=True, exist_ok=True)
    export_dir = base_dir / f"crash-analysis-{sanitize_name(crash.path.stem)}"
    export_dir.mkdir(parents=True, exist_ok=True)
    return export_dir


def copy_unique_file(src: Path, dest_dir: Path, used: set[Path]) -> None:
    if src in used or not src.exists():
        return
    used.add(src)
    dest_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dest_dir / src.name)


def write_export_bundle(analysis: CrashAnalysis, window_secs: int, export_dir: Path) -> Path:
    used: set[Path] = set()
    bundle_dir = resolve_output_dir(export_dir, analysis.crash)

    crash_dir = bundle_dir / "crash"
    sessions_dir = bundle_dir / "sessions"
    copy_unique_file(analysis.crash.path, crash_dir, used)

    report_md = render_markdown([analysis], window_secs)
    report_json = render_json([analysis], window_secs)
    (bundle_dir / "report.md").write_text(report_md)
    (bundle_dir / "report.json").write_text(report_json)

    manifest = crash_analysis_to_dict(analysis, window_secs)
    (bundle_dir / "manifest.json").write_text(json.dumps(manifest, indent=2))

    for project, items in analysis.projects.items():
        project_name = sanitize_name(project)
        for item in items:
            copy_unique_file(item.session.path, sessions_dir / "interrupted" / project_name, used)
            for sub in item.subagents:
                copy_unique_file(sub.path, sessions_dir / "subagents" / project_name, used)
            if item.continuation.later_session:
                copy_unique_file(item.continuation.later_session.path, sessions_dir / "later" / project_name, used)

    return bundle_dir


def create_zip_from_dir(source_dir: Path, zip_path: Path) -> Path:
    zip_path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(source_dir.rglob("*")):
            if path.is_file():
                archive.write(path, arcname=str(path.relative_to(source_dir.parent)))
    return zip_path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--days", type=int, default=7, help="Look back this many days for crashes and sessions.")
    parser.add_argument(
        "--window-secs",
        type=int,
        default=20 * 60,
        help="Match sessions whose mtime is within this many seconds of a crash.",
    )
    parser.add_argument(
        "--format",
        choices=("markdown", "json"),
        default="markdown",
        help="Output format.",
    )
    parser.add_argument(
        "--resume-only",
        action="store_true",
        help="Print only actionable resume commands for forgotten and ambiguous sessions.",
    )
    parser.add_argument(
        "--project",
        help="Only include sessions whose normalized project path or slug contains this substring.",
    )
    parser.add_argument(
        "--crash",
        help="Only analyze crashes whose label or panic filename contains this substring.",
    )
    parser.add_argument(
        "--export-dir",
        type=Path,
        help="Write a single-crash bundle containing the report and copied evidence files into this directory.",
    )
    parser.add_argument(
        "--zip-path",
        type=Path,
        help="Write a single-crash zip bundle containing the report and copied evidence files.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    crashes = select_crashes(discover_crashes(args.days), args.crash)
    sessions = discover_sessions(args.days)
    analyses = analyze_crashes(crashes, sessions, args.window_secs, args.project)

    if args.resume_only:
        print(render_resume_only(analyses), end="")
    elif args.format == "json":
        print(render_json(analyses, args.window_secs))
    else:
        print(render_markdown(analyses, args.window_secs), end="")

    if args.export_dir or args.zip_path:
        if len(analyses) != 1:
            raise SystemExit("export requires exactly one analyzed crash; narrow with --crash and/or --project")

        if args.export_dir:
            bundle_dir = write_export_bundle(analyses[0], args.window_secs, args.export_dir)
        else:
            temp_root = Path(tempfile.mkdtemp(prefix="detect-forgotten-sessions-"))
            try:
                bundle_dir = write_export_bundle(analyses[0], args.window_secs, temp_root)
                create_zip_from_dir(bundle_dir, args.zip_path)
            finally:
                shutil.rmtree(temp_root, ignore_errors=True)
            return 0

        if args.zip_path:
            create_zip_from_dir(bundle_dir, args.zip_path)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
