---
name: skill-forge
description: >-
  Designs, writes, validates, and deploys Claude Code skill files.
  Use when building skills from scratch, converting repeated behaviors
  into reusable skills, or auditing existing skills for quality.
---

# Skill Forge

> **Core Insight:** The best skills come from operationalizing what you already do. Ground in reality first, design collaboratively second, validate mechanically third, track what works fourth.

## When to Use

| Situation | Start at | Skip |
|-----------|----------|------|
| Creating a skill from scratch | Phase 0 | Nothing |
| Converting a repeated manual task to a skill | Phase 0 | Nothing |
| Auditing an existing skill | Phase 3 | Phases 0-2 |
| Extending an existing skill | Phase 0 | Nothing |
| Improving a skill after feedback | Phase 2 | Phases 0-1 (you already know what to fix) |
| Deprecating or merging skills | [enhanced-workflow.md § Deprecation](references/enhanced-workflow.md#deprecation-protocol) | Phases 0-4 (requires ms) |

---

## Phase 0 — Ground

Before designing anything, understand the landscape.

### 0.1 Detect available tools

```bash
ms --version 2>/dev/null && echo "ms: available" || echo "ms: not found"
~/.local/bin/cass health 2>/dev/null && echo "cass: available" || echo "cass: not found"
~/.local/bin/cm doctor --json 2>/dev/null && echo "cm: available" || echo "cm: not found"
```

If any tools are found, tell the user and recommend [enhanced-workflow.md](references/enhanced-workflow.md) for richer grounding, lifecycle tracking, and effectiveness data. Every step below works without tools — tools add data, not different steps.

### 0.2 Search for prior work

Ask the user:
- "Have you built something like this before? What worked? What failed?"
- "How have you done this task manually — what steps do you repeat?"

Look for: repeated steps, decisions made, workarounds, failures.

### 0.3 Check for overlapping skills

```bash
ls ~/.claude/skills/
```

Read frontmatter of any potentially overlapping skill. If >50% scope overlap, recommend extending instead of creating.

### 0.4 Load domain context

Ask the user:
- "Any known anti-patterns, rules of thumb, or hard-won lessons for this domain?"
- "Any preferences for how skills should be structured? Verbose or terse? Prompts or guidelines?"

### 0.5 Present the Grounding Report

```
GROUNDING REPORT: {skill name}
- Prior work: {summary from 0.2, with session refs if available}
- Skill-writing preferences: {from 0.4}
- Overlapping skills: {list from 0.3, or "none"}
- Domain context: {anti-patterns, rules from 0.4}
- Recommendation: proceed / adjust scope / extend existing
```

Wait for user confirmation before Phase 1.

---

## Phase 1 — Plan

Ask the user these questions. Do not assume answers.

1. **What does the skill do?** One sentence.
2. **Who triggers it?** What would a user say to invoke this skill?
3. **Model-invoked or user-invoked?** Does the agent need to fire this itself, or another skill reach it? Then model-invoked — keep a trigger-rich description, pay context load. Only ever fires when you type its name? Then user-invoked — set `disable-model-invocation: true`, pay zero context load. See [skill-physics.md § Invocation](references/skill-physics.md#invocation-the-two-loads). Decide before archetype; it changes how you write the description and whether the trigger test applies.
4. **What model runs it?** Opus (creative/strategic) or Sonnet (mechanical/evaluation)?
5. **What archetype fits?** See [archetypes.md](references/archetypes.md):
   - CLI Reference (LOW freedom) — wraps a tool
   - Methodology (MEDIUM freedom) — teaches a process
   - Safety Tool (LOW freedom) — guards against danger
   - Orchestration (MEDIUM freedom) — coordinates multi-step flows
   - Analysis/Evaluation (MEDIUM-HIGH freedom) — scores and judges
   - None of the above — use Methodology skeleton as starting point, note the deviation
6. **Override archetype freedom?** Each archetype has a default. Only specify if you need a different level, and explain why.
7. **What does it produce?** Files, reports, modifications? What format?

Present all answers back for confirmation. Do not write until confirmed.

### Plan the structure

Based on the archetype, determine:
- Which sections go in SKILL.md (core workflow, < 500 lines)
- Which sections go in references/ (one level deep, no chains)
- Whether scripts/ are needed (for deterministic operations)

Present the structure outline before writing.

---

## Phase 2 — Write

### The protocol: decisions before writing

```
For every structural decision:
1. State the decision and options
2. If non-obvious, think through implications
3. Get user input
4. Only then write
```

This is not optional. Jumping to a finished draft produces skill files that need rewriting.

### Write the SKILL.md

Use the archetype template from [archetypes.md](references/archetypes.md). Follow these principles:

**Conciseness:** Claude is already intelligent. Only include what Claude doesn't know. Challenge each line: "Does this justify its token cost?"

**Progressive disclosure:** Core in SKILL.md; details in references/. Inline what every use needs; disclose what only some uses reach. **Co-location:** once material is placed, keep a concept's definition, rules, and caveats under one heading — don't scatter it across the file. If a must-have reference fires unreliably behind a pointer, fix the pointer's *wording* first; inline it only if that fails.

**Degrees of freedom:** Exact commands for fragile steps. General direction for creative steps.

**Completion criteria (step-based skills):** End every step on a condition the agent can check (done vs. not-done) and that demands enough to be exhaustive where it matters ("every modified file accounted for", not "produce a list"). Vague bounds let the agent declare victory and rush ahead. See [skill-physics.md § Completion criteria](references/skill-physics.md#completion-criteria).

**Leading words:** Anchor recurring behaviour with a compact concept the model already holds from pretraining — *lesson*, *tracer bullets*, a *tight* loop, *relentless* — repeated as a token, never re-explained as a sentence. It recruits priors for free and fires more reliably when the same word lives in your prompts and docs. Reach for an existing word before coining one. See [skill-physics.md § Leading words](references/skill-physics.md#leading-words).

**Examples over explanations:** Show BAD/GOOD, don't explain the rule abstractly.

**THE EXACT PROMPT pattern:** For key operations, provide verbatim copy-paste prompts in code blocks — not descriptions of what to do, but the actual text to use.

**Core philosophy blockquote:** Open the skill with a `>` blockquote stating the one-sentence insight that makes this skill worth having.

**Anti-patterns as Don't/Do tables:** Every skill should have at least one `| Don't | Do |` table for its most common failure modes.

### Write reference files (if needed)

- One level deep from SKILL.md (no chains)
- If >100 lines, include a TOC at the top
- Forward slashes only in paths

### Write scripts (if needed)

Scripts must have explicit error handling, be tested before shipping, and resolve paths relative to the skill directory (not the working directory) for portability.

---

## Phase 3 — Validate

```
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│ Checklist│───▶│ Brevity  │───▶│  Sonnet  │───▶│ Triggers │
│ (19 items)│    │  Pass    │    │  Test    │    │  Test    │
└──────────┘    └──────────┘    └──────────┘    └──────────┘
     Fix             Cut          Fix ambiguity    Fix description
```

### 3.1 Validation checklist

Run [validation-checklist.md](references/validation-checklist.md) — all checks.

Also run the automated validator:
```bash
python ~/.claude/skills/skill-forge/scripts/validate-skill.py /path/to/skill/
```

Any mechanical failure = fix before shipping. If the script is not found, run [validation-checklist.md](references/validation-checklist.md) items manually.

### 3.2 Brevity pass

Run [brevity-protocol.md](references/brevity-protocol.md). For each section:
- Does Claude already know this? Cut.
- Explaining something obvious? Cut.
- Verbose version of a simpler instruction? Simplify.
- Run the **no-op test** on each sentence: does it change behaviour versus the model's default? If not, delete the whole sentence. Diagnose length by cause — sprawl, sediment, or duplication — each has a different cure (see brevity-protocol.md).

Target: SKILL.md < 500 lines. Reference files: keep lean, include TOC if > 100 lines.

### 3.3 Sonnet compatibility test

If the skill will be executed by Sonnet, run [sonnet-test.md](references/sonnet-test.md). Zero HIGH findings required.

### 3.4 Trigger test

Run [trigger-test.md](references/trigger-test.md) (model-invoked skills only). Generate 10 mock user messages (5 should trigger, 5 should not). Revise description until 9/10+.

---

## Phase 4 — Ship

Prerequisite: Phase 3 validation passed. Do not ship without passing the checklist and trigger test.

1. Copy the skill directory to `~/.claude/skills/<skill-name>/`
2. Verify the skill appears: ask Claude Code `/skills` or start a new conversation and check that the skill name shows in the available skills list
3. Test: invoke the skill with a realistic task and confirm it loads correctly
4. Note what archetype was used and what the skill was built from (source sessions, research, user request) — this is the provenance record, even if just a mental note

---

## Phase 5 — Track

Skills improve through feedback.

After using the skill 3+ times, revisit:
- What worked well? Keep it.
- What confused you or the model? Fix it.
- What's missing? Add it.
- What's unnecessary? Cut it.

Update the skill based on what you learned.

---

## Quick Checklist

Before shipping, verify:

- [ ] Core philosophy blockquote at top
- [ ] THE EXACT PROMPT blocks for key operations
- [ ] Anti-patterns Don't/Do table
- [ ] Invocation chosen deliberately (model- vs user-invoked); context load justified
- [ ] Leading words used for key behaviours (repeated as tokens, not re-explained)
- [ ] Steps end on checkable, exhaustive completion criteria (step-based skills)
- [ ] Key terms have a single source of truth — no synonym drift vs. related skills
- [ ] `python ~/.claude/skills/skill-forge/scripts/validate-skill.py` passes
- [ ] Brevity pass completed (< 500 lines)
- [ ] Sonnet test passed (if applicable)
- [ ] Trigger test 9/10+ (model-invoked skills only)
- [ ] No extraneous files (README, CHANGELOG)
- [ ] Examples are concrete, not abstract
- [ ] Skill deployed and loads correctly (Phase 4)
- [ ] Tracking plan noted — when to revisit after real use (Phase 5)

---

## Anti-Patterns

| Don't | Do |
|-------|-----|
| Jump to writing without planning | Present decisions, get confirmation, then write |
| Explain what Claude already knows | Only add domain-specific knowledge Claude lacks |
| Put everything in SKILL.md | Progressive disclosure — details in references/ |
| Describe what to do | Provide THE EXACT PROMPT to copy-paste |
| Test only on Opus | Run Sonnet compatibility test for Sonnet-executed skills |
| Skip grounding (Phase 0) | Always ground — ask the user if tools aren't available |
| Ship without running the validator | `python ~/.claude/skills/skill-forge/scripts/validate-skill.py` catches mechanical issues |
| Ship and forget | Track outcomes (Phase 5) — skills improve through feedback |
| Use different names for the same concept across skills | Fix one term per concept, keep an _Avoid_ list of synonyms; check against related skills before shipping |
| Give every skill a description by default | Choose invocation deliberately — user-invoked skills pay zero context load |
| Re-explain a concept in full sentences each time it recurs | Coin a leading word, then repeat it as a token |
| Pad against the agent rushing with "be thorough" | Sharpen the completion criterion first; split the sequence only if the rush persists |

---

## Audit Mode

If invoked with an EXISTING skill path instead of a new skill request, skip Phases 0-2 and run Phase 3 as an audit:
- Validation checklist + automated validator
- Brevity pass
- Sonnet test (if applicable)
- Trigger test

Report findings without modifying the skill. The user decides what to fix.

---

## References

| Topic | File |
|-------|------|
| Skill physics (invocation, leading words, completion, steering) | [skill-physics.md](references/skill-physics.md) |
| Archetype templates & guidance | [archetypes.md](references/archetypes.md) |
| Validation checklist | [validation-checklist.md](references/validation-checklist.md) |
| Brevity protocol | [brevity-protocol.md](references/brevity-protocol.md) |
| Sonnet test | [sonnet-test.md](references/sonnet-test.md) |
| Trigger test | [trigger-test.md](references/trigger-test.md) |
| Tool-enhanced workflow (ms, CASS, cm) | [enhanced-workflow.md](references/enhanced-workflow.md) |
