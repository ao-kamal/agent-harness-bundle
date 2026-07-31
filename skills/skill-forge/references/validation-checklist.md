# Skill Validation Checklist

Comprehensive mechanical and judgment checklist for Claude Code skill files. Originally derived from Jeffrey Emanuel's skill writing guide, refined through newsletter pipeline construction (17 skills, 49 fixes).

Each item is tagged:
- **[auto]** — automatable by `validate-skill.py`
- **[judgment]** — requires human review, not in the script

This checklist is the authoritative master. `validate-skill.py` implements the [auto] subset. Update here first; the script implements from it.

---

## Frontmatter

- [ ] **[auto]** `name` uses lowercase and hyphens only (`[a-z0-9-]`), 64 chars or fewer, does not contain "anthropic" or "claude"

- [ ] **[auto]** `description` is non-empty and 1024 characters or fewer

- [ ] **[judgment]** Invocation chosen deliberately — `disable-model-invocation: true` for skills that only ever fire by hand; a model-facing `description` (which costs context load every turn) only when the agent or another skill must reach it autonomously

- [ ] **[auto]** No extraneous files in skill directory (README.md, CHANGELOG.md, LICENSE, etc.)

## Body

- [ ] **[auto]** SKILL.md body is under 500 lines

- [ ] **[auto]** Forward slashes only in all file paths (no Windows backslash paths)

- [ ] **[judgment]** No magic numbers — all thresholds and values are justified in context

- [ ] **[judgment]** Single source of truth per key concept — one term, one home, checked against related skills (not just within this one). Keep a short _Avoid_ list of the synonyms you won't use for each key concept

- [ ] **[judgment]** Completion criteria are checkable and exhaustive (step-based skills) — every step ends on a condition the agent can verify (done vs. not-done); no step leaves "done" to the agent's judgment

- [ ] **[judgment]** Examples are concrete, not abstract

- [ ] **[judgment]** Scripts have been tested and include explicit error handling

- [ ] **[judgment]** Tested with real usage scenarios

## References

- [ ] **[auto]** All references are one level deep from SKILL.md (no chains: SKILL.md -> a.md -> b.md)

- [ ] **[auto]** Long reference files (>100 lines) include a TOC at the top

## Description

- [ ] **[judgment]** Description starts with a verb in third person (e.g., "Creates", "Processes", "Analyzes"). Not yet automated in validate-skill.py.

- [ ] **[auto]** No XML tags in description

## Pipeline-Learned

- [ ] **[judgment]** Output contract defined — skill explicitly states what files or format it produces
  *Skills that omitted output specs caused downstream agent failures*

- [ ] **[judgment]** Parseable format specified — if skill produces structured output, the format (JSON, YAML, markdown with headers) is explicit
  *Ambiguous output formats caused parsing failures in multi-agent handoffs*

- [ ] **[judgment]** Shared file dedup check — if skill references files also used by other skills, it references the shared copy rather than duplicating
  *Duplicated reference files drifted out of sync across skills*

- [ ] **[judgment]** Model-awareness annotations — if skill will be run by Sonnet (not just Opus), instructions are sufficiently explicit per the sonnet-test protocol
  *Sonnet required more explicit instructions than Opus for identical tasks*

- [ ] **[judgment] [ms-enhanced]** Skill links back to source evidence via `ms evidence` — source sessions, research files, or methodology docs that informed its creation. Skip if ms is not installed.
  *Skills without provenance are harder to evaluate for deprecation or extension*
