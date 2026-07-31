"""Validate a skill directory against the skill-forge checklist.

Usage: python validate-skill.py /path/to/skill/
Exit codes: 0 = all checks pass, 1 = failures found
"""

import sys
import re
from pathlib import Path

def validate(skill_dir: Path) -> list[str]:
    failures = []
    skill_file = skill_dir / "SKILL.md"

    if not skill_file.exists():
        failures.append("SKILL.md not found in directory")
        return failures

    content = skill_file.read_text(encoding="utf-8")
    lines = content.splitlines()

    # --- Frontmatter checks ---
    if not content.startswith("---"):
        failures.append("Missing YAML frontmatter (must start with ---)")
    else:
        end = content.find("---", 3)
        if end == -1:
            failures.append("Frontmatter not closed (missing second ---)")
        else:
            fm = content[3:end].strip()

            # name check
            name_match = re.search(r"^name:\s*(.+)$", fm, re.MULTILINE)
            if not name_match:
                failures.append("Frontmatter missing 'name' field")
            else:
                name = name_match.group(1).strip().strip('"').strip("'")
                if len(name) > 64:
                    failures.append(f"name too long ({len(name)} chars, max 64)")
                if not re.match(r"^[a-z0-9-]+$", name):
                    failures.append(f"name '{name}' must be lowercase letters, numbers, hyphens only")
                for banned in ("anthropic", "claude"):
                    if banned in name:
                        failures.append(f"name '{name}' must not contain '{banned}'")

            # description check
            desc_match = re.search(r"^description:\s*>-\s*\n((?:\s+.+\n?)+)", fm, re.MULTILINE)
            if not desc_match:
                desc_match = re.search(r"^description:\s*(.+)$", fm, re.MULTILINE)
            if not desc_match:
                failures.append("Frontmatter missing 'description' field")
            else:
                desc = desc_match.group(1).strip().strip('"').strip("'")
                desc = re.sub(r"\s+", " ", desc)
                if len(desc) == 0:
                    failures.append("description is empty")
                if len(desc) > 1024:
                    failures.append(f"description too long ({len(desc)} chars, max 1024)")
                if "<" in desc and ">" in desc:
                    failures.append("description contains XML tags")

    # --- Body checks ---
    body_start = content.find("---", 3)
    if body_start != -1:
        body = content[body_start + 3:].strip()
        body_lines = body.splitlines()
    else:
        body_lines = lines

    if len(body_lines) > 500:
        failures.append(f"SKILL.md body too long ({len(body_lines)} lines, max 500)")

    # Windows backslash check
    for i, line in enumerate(lines, 1):
        if "\\" in line and not line.strip().startswith("#") and not line.strip().startswith("```"):
            if re.search(r"[A-Z]:\\|\\\\", line):
                failures.append(f"Line {i}: Windows backslash path (use forward slashes)")

    # --- Reference checks ---
    refs_dir = skill_dir / "references"
    if refs_dir.exists():
        for ref_file in refs_dir.iterdir():
            if ref_file.is_file() and ref_file.suffix == ".md":
                ref_content = ref_file.read_text(encoding="utf-8")
                ref_lines = ref_content.splitlines()

                # Check for chained references (refs pointing to other refs)
                for line in ref_lines:
                    if re.search(r"\[.*\]\(references/", line):
                        failures.append(f"{ref_file.name}: references another reference file (no chains allowed)")

                # TOC check for long files
                if len(ref_lines) > 100:
                    has_toc = any("##" in line and ("contents" in line.lower() or "toc" in line.lower())
                                 for line in ref_lines[:20])
                    if not has_toc:
                        failures.append(f"{ref_file.name}: >100 lines but no TOC in first 20 lines")

    # --- Extraneous files check ---
    for f in skill_dir.iterdir():
        if f.name.lower() in ("readme.md", "changelog.md", "installation_guide.md", "license", "license.md", "notice.md", "contributing.md"):
            failures.append(f"Extraneous file: {f.name} (skills are for AI agents, not humans)")

    # --- Terminology consistency (basic) ---
    # Check if the skill uses multiple terms for the same concept
    # This is a heuristic — flags potential issues for human review
    term_pairs = [
        ("file path", "filepath"),
        ("filename", "file name"),
        ("sub-agent", "subagent"),
    ]
    for term_a, term_b in term_pairs:
        has_a = term_a.lower() in content.lower()
        has_b = term_b.lower() in content.lower()
        if has_a and has_b:
            failures.append(f"Terminology inconsistency: both '{term_a}' and '{term_b}' used")

    return failures


def main():
    if len(sys.argv) < 2:
        print("Usage: python validate-skill.py /path/to/skill/")
        sys.exit(1)

    skill_dir = Path(sys.argv[1])
    if not skill_dir.is_dir():
        print(f"Error: {skill_dir} is not a directory")
        sys.exit(1)

    failures = validate(skill_dir)

    if failures:
        print(f"FAIL: {len(failures)} issue(s) found\n")
        for f in failures:
            print(f"  - {f}")
        sys.exit(1)
    else:
        print("PASS: All mechanical checks passed")
        sys.exit(0)


if __name__ == "__main__":
    main()
