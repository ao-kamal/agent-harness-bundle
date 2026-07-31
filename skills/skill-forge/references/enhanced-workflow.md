# Enhanced Workflow

Tool-powered enhancements for every skill-forge phase. Each section states what tool it requires and what phase it augments. The standalone workflow in SKILL.md works without any of these — this file adds richer data, structured tracking, and lifecycle management.

## Contents

- [Detection](#detection)
- [CASS: Session Mining](#cass-session-mining)
- [cm: Procedural Memory](#cm-procedural-memory)
- [ms: Skill Lifecycle](#ms-skill-lifecycle)
  - [Phase 0 — Ground](#ms-phase-0--ground)
  - [Phase 2 — Write](#ms-phase-2--write)
  - [Phase 3 — Validate](#ms-phase-3--validate)
  - [Phase 4 — Ship](#ms-phase-4--ship)
  - [Phase 5 — Track](#ms-phase-5--track)
  - [Audit Mode](#ms-audit-mode)
  - [Deprecation Protocol](#deprecation-protocol)

---

## Detection

Run once at the start of any skill-forge session. Report what's available and recommend enhancements.

```bash
ms --version 2>/dev/null && echo "ms: available" || echo "ms: not found"
~/.local/bin/cass health 2>/dev/null && echo "cass: available" || echo "cass: not found"
~/.local/bin/cm doctor --json 2>/dev/null && echo "cm: available" || echo "cm: not found"
```

Tell the user what you found. Example: "ms, CASS, and cm are all installed. I'll use enhanced grounding, structured overlap checking, and effectiveness tracking throughout this session."

Tools layer — each adds capabilities (ms works independently for lifecycle management; anti-pattern mining requires CASS):
- **CASS alone:** Session mining for Phase 0 grounding
- **CASS + cm:** Session mining + procedural memory (anti-patterns, playbook rules)
- **CASS + cm + ms:** Full lifecycle — hybrid search, provenance, effectiveness tracking, graph analysis, deprecation

---

## CASS: Session Mining

**Requires:** `cass` (paths below assume `~/.local/bin/` -- adjust for your system)
**Augments:** Phase 0 (steps 0.2 and 0.4)

### Phase 0.2 — Search for prior work

Replace the user questions with structured session mining:

```bash
# Find sessions where the user did this task manually
~/.local/bin/cass search "<task description>" --robot --limit 5 --fields summary

# Find sessions where skills were written
~/.local/bin/cass search "skill writing SKILL.md" --robot --limit 5 --fields summary
```

Look for: repeated steps, decisions made, workarounds, failures, preferred archetypes, reference file patterns.

Still ask the user — CASS finds what's in session history, but the user knows things CASS doesn't (undocumented preferences, lessons from non-AI work).

### Grounding Report additions

Add to the Phase 0.5 Grounding Report:
```
- Session patterns: {CASS search results, with session refs}
- Skill-writing preferences: {patterns from skill-writing sessions}
```

---

## cm: Procedural Memory

**Requires:** `cm` (sits on top of CASS; paths below assume `~/.local/bin/` -- adjust for your system)
**Augments:** Phase 0 (step 0.4), Phase 2 (anti-pattern seeding)

### Phase 0.4 — Load domain context

```bash
~/.local/bin/cm context "<task description>" --json
```

Returns: relevant playbook rules, anti-patterns, history snippets. These are confidence-scored and decay over time — stale rules fade naturally.

### Phase 2 — Seed the Don't/Do table

When writing the Anti-Patterns table in Phase 2, check cm rules first:
```bash
~/.local/bin/cm playbook list --json
```

Filter to rules related to the skill's domain. Use them as seeds for the Don't/Do table — evidence-based anti-patterns instead of inventing from memory.

### Grounding Report additions

Add to the Phase 0.5 Grounding Report:
```
- CM rules applicable: {list with rule IDs and confidence scores}
```

---

## ms: Skill Lifecycle

**Requires:** `ms` (Meta Skill CLI)
**Augments:** All phases + adds lifecycle management

### ms Phase 0 — Ground

#### Overlap check (replaces `ls`)

```bash
ms search "<skill description>" -m
```

Hybrid search catches semantic overlaps — skills that DO the same thing even if named differently. For each close match:

```bash
ms show <candidate-id> --meta -m
```

This surfaces: feedback score, usage count, last updated, provenance links. If an overlapping skill has negative feedback, the recommendation might be "replace it" rather than "extend it."

#### Provenance on overlapping skills

```bash
ms evidence show <candidate-id> --excerpts -m
```

When deciding "extend vs. create new," provenance matters. A skill with documented source sessions is safer to extend than one with no history.

#### Anti-pattern mining

Two-step process — search CASS for relevant sessions, then pass them to ms:

```bash
# Step 1: Find relevant session IDs from CASS
~/.local/bin/cass search "<domain>" --robot --limit 10 --fields minimal
# Step 2: Pass session IDs to ms
ms antipatterns mine <session-id-1> <session-id-2> -m
```

Finds failure patterns from session history related to the skill's domain. These feed into the Grounding Report and later seed the Don't/Do table in Phase 2.

#### Grounding Report additions

```
- Overlapping skills: {ms search results with feedback scores and provenance}
- Mined anti-patterns: {ms antipatterns results for this domain}
- Bandit signal weights: {ms bandit stats — shows what the system has learned matters}
```

The bandit stats are informational — they tell you what the recommendation engine has learned. If feedback scores are heavily weighted, focus on making this skill produce good outcomes. If recency is weighted, skills that go stale are a bigger risk.

### ms Phase 2 — Write

#### Template application

After the user picks an archetype in Phase 1:

```bash
ms template list -m               # See available templates
ms template apply <archetype> \
  --id <skill-id> \
  --name "<Skill Name>" \
  --description "<description>" \
  --tag <tags>                    # Emit starting markdown
```

The archetype skeletons in [archetypes.md](archetypes.md) remain the authoritative design guide — they teach WHEN and WHY to pick each type. ms templates emit the starting markdown AND record which template was used, enabling effectiveness tracking per archetype over time.

#### Terminology consistency

When the new skill references other skills, load them to check for terminology drift:

```bash
ms show <referenced-skill> -m
```

If skill A calls something "prospect context" and skill B calls it "client brief," agents using both get confused. Check during writing, not after.

### ms Phase 3 — Validate

#### Formatting normalization

Before running the validation checklist:

```bash
ms fmt <skill-path>
```

Normalizes: heading levels, fence styles, frontmatter ordering. Makes formatting deterministic.

#### Token-aware brevity backstop

After the brevity pass:

```bash
ms load <skill-id> --pack 4000 -m
```

If ms can't fit the skill into 4000 tokens, the brevity pass didn't cut enough. This is a mechanical backstop for the judgment-based brevity protocol. It also reveals which sections ms ranks highest — sometimes the section you think is essential is ranked low by the packing algorithm.

#### Schema validation

```bash
ms validate <skill-id> -m
```

Complements `validate-skill.py` with ms-specific schema checks.

### ms Phase 4 — Ship

After the standalone Phase 4 steps (copy to skills dir, verify loading):

#### Index the skill

```bash
ms index <skill-path>
```

Makes the skill immediately searchable via `ms search` and available for suggestions via `ms suggest`.

#### Link provenance

```bash
ms evidence show <skill-id> -m        # Verify evidence exists
```

If the skill was built from CASS sessions, research files, or methodology docs, the evidence should be linked. This is how future sessions trace WHY a skill exists and what informed its design.

#### Graph analysis

```bash
ms graph insights -m
```

Check: is the new skill an orphan (nothing depends on it, it depends on nothing)? Does it create a cycle? Does it change which skills are keystones? Not blocking — informational. Skip for standalone skills.

#### Template tracking

Record which archetype produced this skill:

```bash
ms feedback add <skill-id> --positive --comment "archetype:<type>"
```

Over time, this creates data on which archetypes produce skills with better outcomes. If CLI Reference skills consistently get higher ratings than Methodology skills, the Methodology template needs work.

### ms Phase 5 — Track

Replace the standalone "revisit after 3+ uses" with structured tracking:

#### After each use

```bash
ms feedback add <skill-id> --positive --comment "saved hours on X"
ms feedback add <skill-id> --negative --comment "confused Sonnet on step 3"
ms feedback add <skill-id> --rating 4
```

#### After a production pipeline run

```bash
ms outcome <skill-id> --success
ms outcome <skill-id> --failure
```

#### Periodic review

```bash
ms feedback list --skill <skill-id> -m         # What's the feedback saying?
ms bandit stats -m                              # Has the system learned anything?
```

When feedback accumulates enough signal, update the skill. Phase 5 becomes an ongoing loop, not a one-time revisit.

#### Experiments (rare — only for real design questions)

```bash
ms experiment create <skill-id> --variant control --variant concise
ms experiment conclude <experiment-id> --winner control
```

### ms Audit Mode

Enrich the standalone audit (Phase 3 checks) with lifecycle data:

```bash
ms feedback list --skill <skill-id> -m          # What users said
ms evidence show <skill-id> -m                   # Where it came from
ms graph bottlenecks -m                           # Is it a bottleneck?
```

Report lifecycle findings alongside structural findings. The user decides what to act on.

### Deprecation Protocol

#### Identify candidates

```bash
ms prune analyze -m          # Skills with low feedback, no usage, or overlap
ms prune proposals -m        # Suggested actions: merge, deprecate, split
```

#### Evaluate

For each candidate:
- **Merge:** Two skills do the same thing → combine into one, redirect references
- **Deprecate:** Skill is superseded or consistently negative feedback → archive it
- **Split:** Skill does too many things → break into focused skills

#### Execute

```bash
ms prune apply merge:<skill-a>,<skill-b> --approve   # Merge two skills
ms prune apply deprecate:<skill-id> --approve          # Archive a skill
```

#### When to run

- After the skill library passes 50+ skills
- When `ms graph insights` shows growing cycle count or orphan percentage
- When `ms feedback list` shows multiple skills with negative trends
- Quarterly, as maintenance hygiene
