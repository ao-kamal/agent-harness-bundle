#!/usr/bin/env python3
"""Validate SKILL.md frontmatter across every skill root the harness reads.

Both Claude Code and OpenCode load a skill only if its YAML frontmatter parses,
and a skill that fails to parse is dropped *silently*: the agent simply stops
seeing it, with no error in the harness's own output. One real instance of this
was found on a live install -- an unquoted `description` containing
`Triggers: "..."`. A colon-space inside a plain YAML scalar makes the parser
read it as a nested mapping, the whole file is rejected, and the skill vanishes
from the agent's skill list with nothing but a debug-level warning.

Per OpenCode's documented spec the recognised frontmatter fields are exactly:
`name` (required), `description` (required), `license`, `compatibility`, and
`metadata`. Unknown fields are ignored, so they are reported as informational
rather than as failures.

Usage:
    validate-skills.py [--root DIR]... [--quiet] [--strict]

Exit codes:
    0  every skill parses and declares the required fields
    1  at least one hard defect (missing fence, unparseable, missing field)
    2  bad invocation
"""
from __future__ import annotations

import argparse
import pathlib
import re
import sys

RECOGNISED = {"name", "description", "license", "compatibility", "metadata"}
REQUIRED = ("name", "description")

DEFAULT_ROOTS = (
    pathlib.Path.home() / ".claude" / "skills",
    pathlib.Path.home() / ".config" / "opencode" / "skills",
    pathlib.Path.home() / ".claude" / "plugins",
)

FENCE = "---"


def split_frontmatter(text: str):
    """Return (frontmatter, body). frontmatter is None when there is no fence."""
    lines = text.splitlines()
    if not lines or lines[0].strip() != FENCE:
        return None, text
    for i in range(1, len(lines)):
        if lines[i].strip() == FENCE:
            return "\n".join(lines[1:i]), "\n".join(lines[i + 1:])
    return None, text


def unquoted_colon_space(fm: str):
    """`key: value` lines whose unquoted value contains ': '.

    That is the defect that breaks parsing, and it is invisible to a reader
    because the fences and the field names both look correct.
    """
    hits = []
    for lineno, line in enumerate(fm.splitlines(), start=2):
        m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*):\s(.*)$", line)
        if not m:
            continue
        key, val = m.group(1), m.group(2)
        if not val or val[0] in "\"'":
            continue
        if ": " in val:
            hits.append((lineno, key, val))
    return hits


def structural_fields(fm: str):
    """Parse `key: value` pairs without a YAML library.

    This is the primary path, not a fallback. Requiring PyYAML would mean the
    validator silently skips the required-field check on any machine that does
    not have it -- which is the same silent-pass failure this tool exists to
    catch. PyYAML, when present, is used as an *additional* parse check on top.
    """
    fields = {}
    for line in fm.splitlines():
        m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*):\s?(.*)$", line)
        if m:
            fields[m.group(1)] = m.group(2).strip()
    return fields


def scalar_is_empty(value: str) -> bool:
    s = value.strip()
    if len(s) >= 2 and s[0] in "\"'" and s[-1] == s[0]:
        s = s[1:-1]
    return not s.strip()


def check_required_and_known(fm: str):
    """Return (hard_defects, soft_notes) from a library-free parse.

    Severity follows what the harnesses actually do. Frontmatter that does not
    parse makes the skill vanish with no user-visible error -- that is a hard
    defect. Frontmatter that parses but leaves a required field empty still
    loads; the skill is merely listed with no description, which is degraded
    rather than dropped, so it is a note. A missing `name` is the exception:
    the skill cannot be addressed at all, so that stays hard.
    """
    fields = structural_fields(fm)
    hard, notes = [], []
    if "name" not in fields or scalar_is_empty(fields.get("name", "")):
        hard.append("missing or empty required frontmatter field: name "
                    "(the skill cannot be addressed without it)")
    if "description" not in fields:
        notes.append("no `description` field: the skill loads but is listed with no description")
    elif scalar_is_empty(fields["description"]):
        notes.append("`description` is present but empty: the skill loads but is listed "
                     "with no description")
    extra = sorted(set(fields) - RECOGNISED)
    if extra:
        notes.append("unrecognised frontmatter field(s): " + ", ".join(extra))
    return hard, notes


def yaml_parse_check(fm: str):
    """(status, detail). status is True/False/None (None = PyYAML unavailable)."""
    try:
        import yaml  # noqa: PLC0415
    except ImportError:
        return None, "PyYAML not installed; used structural checks only"
    try:
        data = yaml.safe_load(fm)
    except Exception as exc:  # noqa: BLE001
        return False, f"{type(exc).__name__}: {exc}"
    if not isinstance(data, dict):
        return False, f"frontmatter parsed as {type(data).__name__}, not a mapping"
    return True, "parsed"


def check_file(path: pathlib.Path):
    """Return (hard_defects, soft_notes)."""
    hard, soft = [], []
    raw = path.read_bytes()
    if raw[:3] == b"\xef\xbb\xbf":
        soft.append("file starts with a UTF-8 BOM")
        raw = raw[3:]
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        return [f"not valid UTF-8: {exc}"], soft

    fm, _ = split_frontmatter(text)
    if fm is None:
        return ["no opening/closing '---' frontmatter fence"], soft

    for lineno, key, _val in unquoted_colon_space(fm):
        hard.append(
            f"line {lineno}: unquoted `{key}` value contains ': ', which YAML reads as a "
            f"nested mapping; single-quote the scalar to fix"
        )

    req_hard, req_notes = check_required_and_known(fm)
    hard.extend(req_hard)
    soft.extend(req_notes)

    parsed, detail = yaml_parse_check(fm)
    if parsed is False:
        hard.append(f"frontmatter does not parse: {detail}")
    elif parsed is None:
        soft.append(detail)
    return hard, soft


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", action="append", dest="roots", type=pathlib.Path,
                    help="skill root to scan; repeatable (default: the standard roots)")
    ap.add_argument("--quiet", action="store_true", help="print only defects and the summary")
    ap.add_argument("--strict", action="store_true", help="treat soft notes as failures")
    args = ap.parse_args(argv)

    roots = args.roots or [r for r in DEFAULT_ROOTS if r.is_dir()]
    if not roots:
        print("validate-skills: no skill roots exist; nothing to check")
        return 0

    files, broken, notes = 0, [], []
    env_notes = set()
    for root in roots:
        if not root.is_dir():
            continue
        for path in sorted(root.rglob("SKILL.md")):
            files += 1
            hard, soft = check_file(path)
            rel = path.relative_to(root.parent) if root.parent in path.parents else path
            for h in hard:
                broken.append((rel, h))
            for s in soft:
                # Environment-level conditions repeat for every file; say them once.
                if s.startswith("PyYAML"):
                    env_notes.add(s)
                else:
                    notes.append((rel, s))

    print(f"validate-skills: scanned {files} SKILL.md under "
          f"{', '.join(str(r) for r in roots)}")
    for n in sorted(env_notes):
        print(f"  note: {n}")
    if notes:
        # Unrecognised fields are per-skill authoring metadata that OpenCode
        # documents as ignored. Aggregate them so the report stays readable.
        fieldset = set()
        for _rel, s in notes:
            if s.startswith("unrecognised frontmatter field(s): "):
                fieldset.update(s.split(": ", 1)[1].split(", "))
        affected = [r for r, s in notes if s.startswith("unrecognised frontmatter")]
        if fieldset:
            print(f"  note: {len(affected)} skill(s) carry fields outside the documented "
                  f"set (OpenCode ignores these): {', '.join(sorted(fieldset))}")

    if broken:
        print(f"  DEFECTS: {len(broken)}")
        for rel, h in broken:
            print(f"    - {rel}: {h}")
        return 1

    print(f"  OK: {files} skills, 0 defects"
          + (f" ({len(notes) + len(env_notes)} note(s))" if (notes or env_notes) else ""))
    return 1 if (args.strict and (notes or env_notes)) else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
