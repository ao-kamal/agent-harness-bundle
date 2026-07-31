# Skill Archetypes

Five starting structures for new skills. Select one during Phase 1 based on what the skill does. Phase 2 uses the selected skeleton as the initial structure.

## Contents
- [Required Elements (all archetypes)](#required-elements-all-archetypes)
- [Degree of Freedom Reference](#degree-of-freedom-reference)
- [Archetype 1: CLI Reference](#archetype-1-cli-reference)
- [Archetype 2: Methodology](#archetype-2-methodology)
- [Archetype 3: Safety Tool](#archetype-3-safety-tool)
- [Archetype 4: Orchestration Tool](#archetype-4-orchestration-tool)
- [Archetype 5: Analysis / Evaluation](#archetype-5-analysis--evaluation)

## Required Elements (all archetypes)

Every skill, regardless of archetype, must include these 7 structural elements. They're derived from Jeff's Agent Flywheel skill patterns (idea-wizard, beads-workflow, planning-workflow, multi-pass-bug-hunting, repeatedly-apply-skill) — the best-performing skills in the installed collection.

1. **Core philosophy blockquote** — `> **Core Insight:** {one sentence}` immediately after the H1 title. The single most important sentence in the skill. If someone reads only this, they get the key idea.

2. **When to Use table** — `| Situation | Action |` table that maps user contexts to what the skill does. Prevents misfire and shows scope at a glance.

3. **THE EXACT PROMPT blocks** — For key operations, provide verbatim copy-paste prompts in fenced code blocks. Not descriptions of what to do — the actual text. This is the single biggest differentiator between skills that work and skills that don't.

4. **Anti-Patterns Don't/Do table** — `| Don't | Do |` table covering the 3-5 most common failure modes. Encodes hard-won lessons so they're visible, not buried in prose.

5. **Quick Checklist** — `- [ ]` checkbox list of pre-ship verification items. Users scan this before deploying. Complements the validation checklist (which is comprehensive); this is the quick gut-check.

6. **ASCII flow diagram** — For multi-step workflows, a visual showing the flow: `A → B → C → Done?`. One diagram communicates what 3 paragraphs of prose cannot.

7. **References table** — `| Topic | File |` table at the bottom linking to reference files, related skills, external docs. Navigation, not content.

When using any archetype skeleton below, add these 7 elements to the generated structure. The skeletons include some (Methodology has the blockquote, Safety Tool has the Don't/Do table), but verify ALL 7 are present before shipping.

## Degree of Freedom Reference

Match specificity to task fragility:

| Freedom | When | Example |
|---------|------|---------|
| **High** | Multiple valid approaches, context-dependent | Code review guidelines |
| **Medium** | Preferred pattern exists, some variation OK | Report templates with customizable sections |
| **Low** | Fragile/error-prone, consistency critical | DB migration scripts — exact command, no flags |

Narrow bridge with cliffs = low freedom (exact guardrails). Open field = high freedom (general direction).

---

## 1. CLI Reference

**When to use:** The skill wraps a command-line tool, API client, or external binary. The user needs exact commands, flags, and auth setup — not explanation of concepts.

**Degree of freedom:** LOW. Exact commands matter. Wrong flags break things.

**Examples:** github, gcloud, vercel, cass, br

### Skeleton

```markdown
# [Tool Name]

> **Core Insight:** [One-line: what tool does + when to invoke]

## Authentication

[Auth commands, token setup, environment variables]

## Core Operations

### [Function Group 1]

[Commands grouped by what they do]

### [Function Group 2]

[Commands grouped by what they do]

## Common Workflows

### [Workflow 1: Name]

[Multi-step recipe for a common task]

### [Workflow 2: Name]

[Multi-step recipe for a common task]

## Gotchas

[Flags that break things, common mistakes, version-specific behavior]
```

### Guidance

- Pure reference, minimal prose. Claude already knows CLI semantics.
- Token-efficient: commands and flags, not paragraphs explaining what `--verbose` does.
- Group commands by function (e.g., "Read Operations", "Write Operations"), not alphabetically.
- Include the exact flag forms that work — if `--json` is required for machine-readable output, say so once in a prominent place.
- Gotchas section prevents the most common mistakes; keep it short and specific.

---

## 2. Methodology

**When to use:** The skill encodes a process, technique, or way of working. The value is in the method itself — a specific sequence of steps or a prompt that produces better results than naive approaches.

**Degree of freedom:** MEDIUM. The process is fixed, but application varies by context.

**Examples:** planning-workflow, de-slopify, operationalizing-expertise

### Skeleton

```markdown
# [Methodology Name]

> **Core Insight:** [One-liner insight that captures why this works]

## Why This Matters

[Brief motivation: what goes wrong without this method. 2-4 sentences max.]

## The Method

[Step-by-step process OR copy-paste-ready prompt. This is the core of the skill.]

### Step 1: [Name]

[What to do and why]

### Step 2: [Name]

[What to do and why]

### Step 3: [Name]

[What to do and why]

## Why This Works

[Technical breakdown: what makes each step effective. Helps Claude adapt the method to edge cases.]

## Before/After Examples

### Before (without method)

[Concrete example of naive output]

### After (with method)

[Same input, better output using the method]
```

### Guidance

- The Core Philosophy one-liner is the most important sentence. It should be memorable and precise enough that someone who reads only that line still gets the key insight.
- "The Method" section must be concrete enough to execute without interpretation. If it is a prompt, make it copy-paste ready.
- Before/After examples are not optional — they are how Claude calibrates the quality bar.
- Keep "Why This Works" analytical, not promotional. Explain the mechanism, not why it is great.

---

## 3. Safety Tool

**When to use:** The skill enforces constraints, guardrails, or invariants. It exists to prevent specific failure modes — incorrect deployments, security violations, data loss, formatting violations.

**Degree of freedom:** LOW. Safety requires precision. Ambiguity in a safety tool defeats its purpose.

**Examples:** dcg, slb

### Skeleton

```markdown
# [Tool Name]

> **Core Insight:** [What it guards against + when to invoke]

## Why This Exists

[Threat model: what specific failure modes does this prevent? Be concrete.]

## Critical Design Principles

[Architecture decisions that make the safety guarantees work. Not aspirational — mechanical.]

### Principle 1: [Name]

[What it means and why it is non-negotiable]

### Principle 2: [Name]

[What it means and why it is non-negotiable]

## What It Blocks / What It Allows

### Blocked Patterns

| Pattern | Why Blocked | What To Do Instead |
|---------|-------------|-------------------|
| [example] | [risk] | [safe alternative] |

### Allowed Patterns

| Pattern | Conditions |
|---------|-----------|
| [example] | [when this is safe to do] |

## Modular System

[How to extend: add new rules, adjust thresholds, handle exceptions]

## Security Considerations

[Limitations, assumptions, what this does NOT protect against]
```

### Guidance

- The threat model in "Why This Exists" must be specific. "Prevents bad things" is not a threat model. "Prevents force-push to protected branches when pre-commit hooks are skipped" is.
- Tables for Blocks/Allows are faster to scan than prose. Use them.
- Always include "What To Do Instead" — a safety tool that only says "no" without alternatives creates workarounds.
- Security Considerations must be honest about limitations. A safety tool that claims to cover everything covers nothing.

---

## 4. Orchestration Tool

**When to use:** The skill coordinates multi-step workflows, multi-agent pipelines, or sequences of tool calls. The value is in the coordination logic — what runs when, what depends on what, how to resume after failure.

**Degree of freedom:** MEDIUM. The orchestration structure is fixed, but individual steps may have their own flexibility.

**Examples:** ntm, agent-mail, analyze (newsletter pipeline)

### Skeleton

```markdown
# [Tool Name]

> **Core Insight:** [What it orchestrates + when to invoke]

## Why This Exists

[Pain points: what goes wrong when these steps are done manually or ad-hoc]

## Quick Start

[Minimal viable usage: the one command that does the common case]

## Core Commands

### [Command Group 1]

[Commands with flags and expected output]

### [Command Group 2]

[Commands with flags and expected output]

## Workflow Stages

### Stage 1: [Name]

[What runs, what it depends on, what it produces]

### Stage 2: [Name]

[What runs, what it depends on, what it produces]

## Robot Mode

[Machine-readable output formats: --json flags, structured output, parseable responses for agent consumption]

## Integration with Ecosystem

[How this tool connects to other tools, MCP servers, or pipeline stages]

## Resumability

[How to resume after failure: what state is checkpointed, how to skip completed steps]
```

### Guidance

- Quick Start must be genuinely quick — one command, one result. If the common case requires 5 setup steps, the orchestration is not done yet.
- "Workflow Stages" should make dependencies explicit. If Stage 2 needs Stage 1 output, say so.
- Robot Mode is critical for agent consumption. If the tool has no structured output format, the skill should document how to parse its output.
- Resumability prevents wasted work. Document what is idempotent and what is not.

---

## 5. Analysis / Evaluation

**When to use:** The skill assesses, scores, or evaluates an artifact against defined criteria. The value is in the evaluation framework — consistent dimensions, explicit scoring, and actionable feedback rather than vague impressions.

**Degree of freedom:** MEDIUM-HIGH. Criteria and dimensions are fixed; weighting and severity thresholds may vary by context.

**Examples:** Draft Director and manager agents from the newsletter pipeline, code review checklists, editing lenses

### Skeleton

```markdown
# [Evaluator Name]

> **Core Insight:** [What it evaluates + when to invoke]

## What It Evaluates

[Artifact type, expected input format, scope of evaluation]

## Evaluation Criteria

### Dimension 1: [Name]

- **What it measures:** [precise definition]
- **Scoring:** [scale, rubric, or pass/fail]
- **Floor:** [minimum acceptable threshold, if any]

### Dimension 2: [Name]

- **What it measures:** [precise definition]
- **Scoring:** [scale, rubric, or pass/fail]
- **Floor:** [minimum acceptable threshold, if any]

### Dimension 3: [Name]

- **What it measures:** [precise definition]
- **Scoring:** [scale, rubric, or pass/fail]
- **Floor:** [minimum acceptable threshold, if any]

## Input Requirements

[What the evaluator needs to see: file formats, minimum context, supporting materials]

## Output Format

[Structured output: scores per dimension, overall assessment, specific citations from the artifact]

### Example Output

```
[Concrete example of what evaluation output looks like]
```

## Threshold Rules

[When to pass, flag, or fail. How dimensions interact — e.g., "any dimension below floor = overall fail regardless of other scores"]

## Calibration Notes

[How scoring was derived, what "good" looks like for each dimension, known edge cases where the criteria need human judgment]
```

### Guidance

- Every dimension must have a precise definition. "Quality" is not a dimension. "Sentence-level clarity: no clause requires re-reading to parse" is.
- Scoring must be explicit. If it is a 1-5 scale, define what each number means. If pass/fail, define the boundary.
- Floor rules prevent a strong score in one dimension from masking failure in another. Include them when any single dimension is critical.
- Output format must be structured enough for downstream consumption — another agent, a human reviewer, or an editing pipeline should be able to parse it without guessing.
- Calibration Notes are where you acknowledge subjectivity. Better to say "Dimension X requires judgment for satirical content" than to pretend the rubric covers every case.
