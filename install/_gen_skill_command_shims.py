#!/usr/bin/env python3
"""Generate OpenCode command shims for every skill in the canonical skills root.

Why this exists
---------------
OpenCode fills its slash-command menu from *commands*, not from skills. Its
config schema (https://opencode.ai/config.json) has two unrelated keys:
`command` ("Command configuration") and `skills` ("Additional skill folder
paths"). OpenCode does load ~/.claude/skills as skills, but it does not
auto-generate a command per skill, so the ~112 canonical skills are invocable
through the Skill tool yet invisible to slash-command autocomplete. The only
entry that appeared was `impeccable`, because `npx impeccable install` is the
only installer that happens to write a command shim.

This writes the missing shims. Each one is a thin pointer, not a copy:

    ---
    description: "<the skill's own frontmatter description>"
    agent: build
    subtask: true
    ---
    Call skill({ name: "<name>" }) and follow its `Setup` and `Commands` sections
    to handle $ARGUMENTS.

No skill content is duplicated, so the one-brain rule still holds: the brain
stays in ~/.claude/skills and these files only reference it by name.

Deliberately dependency-free. Windows Python in the field has no PyYAML, so the
frontmatter reader below handles the subset that Claude skills actually use:
scalars, quoted scalars, and block scalars (>-, >, |, |-). Anything it cannot
parse falls back to directory name plus a generic description rather than
aborting the run.

Existing shims are preserved by default so an official installer's curated file
(Impeccable's is written by npx) is never clobbered. Pass --force to overwrite.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path

TEMPLATE = """---
description: {description}
agent: build
subtask: true
---
Call skill({{ name: "{name}" }}) and follow its `Setup` and `Commands` sections to handle $ARGUMENTS.
"""


def read_frontmatter(text: str) -> dict:
    """Parse the leading `---` block of a SKILL.md. Minimal, not general YAML."""
    if not text.startswith("---"):
        return {}
    lines = text.splitlines()
    end = None
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            end = i
            break
    if end is None:
        return {}

    out: dict[str, str] = {}
    i = 1
    while i < end:
        line = lines[i]
        m = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", line)
        if not m:
            i += 1
            continue
        key, value = m.group(1), m.group(2)
        if value in (">", ">-", ">+", "|", "|-", "|+"):
            # Block scalar: consume every more-indented line that follows.
            block = []
            j = i + 1
            while j < end and (not lines[j].strip() or lines[j].startswith((" ", "\t"))):
                block.append(lines[j].strip())
                j += 1
            if value.startswith(">"):
                # Folded: join with spaces, drop blank-line paragraph breaks.
                folded = " ".join(x for x in block if x)
                out[key] = re.sub(r"\s+", " ", folded).strip()
            else:
                out[key] = "\n".join(block).strip()
            i = j
            continue
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in ("'", '"'):
            value = value[1:-1]
        out[key] = value
        i += 1
    return out


def one_line(text: str, limit: int = 1200) -> str:
    """Collapse to a single line and emit as a valid YAML double-quoted scalar."""
    flat = re.sub(r"\s+", " ", text or "").strip()
    if len(flat) > limit:
        flat = flat[: limit - 1].rstrip() + "…"
    return json.dumps(flat, ensure_ascii=False)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--skills", default=str(Path.home() / ".claude" / "skills"))
    ap.add_argument("--out", default=str(Path.home() / ".config" / "opencode" / "commands"))
    ap.add_argument("--force", action="store_true", help="overwrite existing shims")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    skills_dir = Path(args.skills)
    out_dir = Path(args.out)

    if not skills_dir.is_dir():
        print(f"ERROR: skills root not found: {skills_dir}", file=sys.stderr)
        return 1

    skill_dirs = sorted(d for d in skills_dir.iterdir() if d.is_dir() and (d / "SKILL.md").is_file())
    if not skill_dirs:
        print(f"ERROR: no skills with SKILL.md under {skills_dir}", file=sys.stderr)
        return 1

    if not args.dry_run:
        out_dir.mkdir(parents=True, exist_ok=True)

    written = skipped = failed = 0
    orphans: list[str] = []
    generated: dict[str, Path] = {}

    for d in skill_dirs:
        try:
            meta = read_frontmatter((d / "SKILL.md").read_text(encoding="utf-8", errors="replace"))
        except Exception as exc:  # noqa: BLE001
            print(f"  FAIL  {d.name}: {exc}", file=sys.stderr)
            failed += 1
            continue

        name = (meta.get("name") or d.name).strip()
        if not re.fullmatch(r"[A-Za-z0-9._-]+", name):
            print(f"  SKIP  {d.name}: unusable skill name {name!r}", file=sys.stderr)
            failed += 1
            continue

        desc = meta.get("description") or f"Invoke the {name} skill."
        target = out_dir / f"{name}.md"

        if target.exists() and not args.force:
            skipped += 1
            generated[name] = target
            continue

        body = TEMPLATE.format(description=one_line(desc), name=name)
        if args.dry_run:
            print(f"  would write {target.name}")
        else:
            target.write_text(body, encoding="utf-8", newline="\n")
        generated[name] = target
        written += 1

    # A shim with no matching skill is a leftover from a removed skill.
    if out_dir.is_dir():
        for md in sorted(out_dir.glob("*.md")):
            if md.stem not in generated:
                orphans.append(md.name)

    print(f"skills found      : {len(skill_dirs)}")
    print(f"shims written     : {written}")
    print(f"shims preserved   : {skipped}   (existing files left alone; use --force to overwrite)")
    print(f"failures          : {failed}")
    print(f"command files now : {len(list(out_dir.glob('*.md'))) if out_dir.is_dir() else 0}")
    if orphans:
        print(f"orphan shims      : {len(orphans)} -> {', '.join(orphans)}")
        print("  (no matching skill; delete them or they will 404 on invoke)")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
