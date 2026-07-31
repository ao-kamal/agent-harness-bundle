---
created: 2026-03-30
updated: 2026-04-10
categories:
- pipeline-construction
- multi-agent-systems
- methodologies
type: reference
---

# Multi-Agent Deliverable Pipeline Construction Methodology

Operational playbook for building specialized multi-agent writing pipelines. Derived from the newsletter (Issue Zero) pipeline — 11 agents, 5 review passes, 49 fixes. Refined through the EEC Outline spec session (2026-04-08) which established the output-first architecture and mining/production separation. Updated 2026-04-10 with ms lifecycle integration and structured effectiveness tracking.

## Two Specs, Not One

Every deliverable pipeline requires TWO specs written in sequence:

1. **The Output Spec** — what the prospect receives. Section by section, quality gates, emotional journey, segment calibration. Defined using the [[deliverable-spec-methodology]]. This comes FIRST.

2. **The Architecture Spec** — how the pipeline produces it. Agent inventory, dependency chain, shared layers, dispatch table, data flow. Defined in Phase 2 of this methodology. This comes SECOND and serves the output spec.

The output spec is the contract with the prospect. The architecture spec is the contract with the pipeline. If they conflict, the architecture spec changes — not the output spec.

---

## Architecture: Mining Layer + Production Pipelines

The pipeline has two layers with different jobs:

**Mining Layer** (shared across all deliverables):
- Extracts and structures data from prospect content, audience behavior, and competitive position
- Runs once per prospect, produces structured material that ALL production pipelines consume
- Surfaces extracted material, not pre-solved conclusions ("here are 15 vivid phrases" — not "the best name is X")
- Two knowledge layers: timeless (vault — researched once, applies to every prospect) and per-prospect (individual mined data extracted from each prospect's public content)

**Production Pipelines** (one per deliverable type):
- Reads structured material from the mining layer
- Makes all creative/strategic decisions (which mistakes to name, which evidence to use, which angle to take)
- Each pipeline is independent — EEC Outline, Landing Page, Day 1 Email, Outreach Email each have their own agents

The mining layer is designed from the UNION of all output specs' ideal inputs. Complete all output specs before designing the mining layer.

**Presentation Layer** (shared across all deliverables):
- Takes copy/content outputs from production pipelines and renders into final delivery format
- Formats include: hosted landing pages, PDFs, Google Docs, visual artifacts
- Design, typography, and visual treatment are craft decisions — not afterthoughts
- Designed after all deliverable specs are complete, alongside the mining layer
- May overlap with or feed into the outreach pipeline

---

## The Phases

```
Prerequisite: Subject-matter vaults exist (see vault-creation-methodology)
      |
Phase 0: Output Spec (per deliverable — see deliverable-spec-methodology)
      |
Phase 1: Backward Design (ideal inputs + gap analysis)
      |
Phase 2: Architecture Design (agent decomposition, shared layers, dispatch table)
      |
Phase 3: Implementation (write skill files collaboratively)
      |
Phase 4: Review Loop (5 serial passes including adversarial)
      |
Phase 5: Persist + Learn (effectiveness tracking, methodology updates, anti-pattern registration)
```

---

## Prerequisite: Subject-Matter Vaults

Before any pipeline work begins, the relevant vaults must exist. See [[vault-creation-methodology]].

Existing vaults: PGA (EEC craft — 127 files, 6 MOCs), WriteWithAI (writing craft — 396 files, 10 MOCs). Both at `AgentVaults/`.

---

## Phase 0: Output Spec

> **Flywheel:** Ground in reality → Generate 30 → Winnow to 5 → Best-of-all-worlds synthesis

Follow the [[deliverable-spec-methodology]] in full. This is a multi-session process per deliverable:

1. Vault grounding (read MOCs + signal-5 files IN FULL)
2. External research (vault agent → external research agents, high-signal sources)
3. Strategic decisions (diagnosis vs. prescription, delivery timing in the prospect outreach sequence)
4. Structure definition (idea-wizard: 30 → 5 → 15 → synthesis)
5. Spec review (4 passes: prospect simulation, internal consistency, producibility, adversarial)
6. Full rewrite integrating all findings

**Output:** The complete output spec — what the prospect receives, section by section.

---

## Phase 1: Backward Design

> **Flywheel:** Define ideal inputs → Map current state → Identify patterns

After the output spec is locked, work backwards from each quality bottleneck:

### 1.1 Define ideal inputs

For each quality bottleneck in the output spec (ordered by impact), define the IDEAL input — not what currently exists, but what SHOULD exist. Ask: "What data would give the co-writer raw material to produce the DEVASTATING version of this element, not just the passing version?"

Ground this in the vault methodology. Where the methodology (PGA, WriteWithAI) simplifies for mass teaching, specify the judgment layers it leaves to human intuition. For each judgment layer: what data would give an AI co-writer equivalent quality?

### 1.2 Map current pipeline against ideal inputs

Deploy agents grouped by pipeline file clusters. Each reads agent definitions + actual outputs and reports per input:
- EXISTS and sufficient
- EXISTS but insufficient (what's missing)
- DOESN'T EXIST

Agents REPORT only. The main session interprets against full strategic context.

### 1.3 Identify structural patterns

Across all gaps, identify patterns. The EEC Outline session found three:
- The pipeline produces final outputs, not selection pools
- Rich information exists in prose but not as structured inputs
- The pipeline understands the prospect's content but not the prospect as a person

These patterns become the design problems the mining layer and architecture must solve.

**Output:** Ideal inputs document + gap analysis + structural patterns.

---

## Phase 2: Architecture Design

> **Flywheel:** Write initial plan → Multi-model plans → Best-of-all-worlds synthesis → Iterative refinement
> **Skills:** `planning-workflow`, `multi-model-triangulation`, `repeatedly-apply-skill`

### 2.1 Agent decomposition (idea-wizard)

AFTER the output spec and backward design are complete, run idea-wizard for AGENT decomposition:

```
Based on the output spec ({spec name}), the ideal inputs ({inputs doc}),
and the mining layer outputs available:

What are 30 possible ways to decompose {deliverable type} production into
specialized agents? For each: agent count, what each agent does,
dependencies, and quality bottleneck.
```

Winnow to 5 architectures. User picks. This is a different use of idea-wizard from Phase 0 (which generated document STRUCTURES, not agent architectures).

### 2.2 Map reusable components

Mark what transfers from existing pipelines. The reusable unit is LAYERS, not just agents:

| Layer | What transfers | Actual result | Notes |
|-------|---------------|---------------|-------|
| Mining layer outputs | Shared across all pipelines | _fill after build_ | Same mined data, different creative use |
| writer-standards.md | Universal quality rules | _fill after build_ | Disallowed words, AI pattern avoidance |
| voice-matching.md | Universal voice matching | _fill after build_ | Writeprint-based calibration |
| Review loop methodology | Identical process every time | _fill after build_ | 5 serial passes, adversarial template |
| Orchestrator pattern | STRUCTURE only | _fill after build_ | Steps differ, flow pattern is the same |
| Editing pipeline | Shared downstream | _fill after build_ | 10 passes, judgment lens, changelogs |

This table is a TEMPLATE. Each build produces its own filled copy in the architecture spec or build log. Phase 5.3 fills the "Actual result" column in your build's copy — not this template. Over time, comparing across builds shows what reuse actually saves. Individual agents from the Issue Zero build are not listed — reuse operates at the layer level, not the agent level.

### 2.3 Write the architecture spec

The spec covers: agent inventory, dependency chain, shared layers, individual agent specifications, data flow, dispatch table, directory structure, status tracking, error handling, orchestration details, upstream input mapping (which mining layer outputs feed which agents).

Apply:
- Nested Systems: what are the subsystems? (3-7 per layer)
- Granularity Matches Skill: AI is a smart new hire — narrow tasks
- Theory of Constraints: find the quality bottleneck

### 2.4 Multi-model architecture review

> **Skills:** `multi-model-triangulation`

One-time manual step. Claude generates review prompts, you paste into GPT Pro and Gemini, paste reviews back, Claude synthesizes consensus/divergence/unique insights.

### 2.5 Iterative spec refinement

> **Skills:** `repeatedly-apply-skill`

Run 3-4 refinement passes on the architecture spec before implementation. Cheaper to fix the spec than to fix skill files.

### 2.6 Pre-write the dispatch table

The dispatch table IS the integration contract. Write it BEFORE any agent skill files. Forces every agent's inputs, outputs, and model assignment to be defined upfront.

### 2.7 Convert to implementation beads

> **Skills:** `beads-workflow`

Each skill file becomes a bead. Dependencies are explicit. Orchestrator depends on ALL agents. Use `bv --robot-plan` for optimal implementation order.

---

## Phase 3: Implementation Sessions

> **Flywheel:** Implement (work the graph)
> **Skills:** `beads-bv` (what's next), `beads-br` (claim/close), `cass-memory` (anti-patterns)

### Pre-session

```bash
~/.local/bin/cm context "building {deliverable} pipeline skill files" --json
ms antipatterns list -m   # if ms available — surface prior build failures
```

### Per-session workflow

1. **Check beads-bv** — which skill files are ready (dependencies met)?
2. **Read the architecture spec** — the FULL spec, not just this session's sections
3. **Read the output spec** — to stay grounded in what the prospect receives
4. **Read prior sessions' skill files** as pattern reference
5. **Read the vault** — re-read if needed for freshness
6. **Present design decisions** before writing. Ultrathink hard decisions.
7. **Record non-obvious decisions** — later sessions need the reasoning, not just the outcome. Write "Chose X over Y because Z" in the architecture spec or build log.
8. **Write skill files collaboratively** — main session, not delegated to subagents
9. **Brevity review** each file (`/skill-forge` Phase 3.2: "Does Claude need this? Does this justify its token cost?")
10. **Close the bead**

### Skill file standards

Per `/skill-forge` validation checklist:
- < 500 lines per SKILL.md
- Frontmatter: name, description (triggers, third person, ≤1024 chars)
- Progressive disclosure: core in SKILL.md, details in references/ (one level deep)
- Degrees of freedom: low for fragile processes, high for creative tasks
- Only include what Claude doesn't already know
- Examples over explanations

---

## Phase 4: Review Loop

> **Flywheel:** Bug bash (audit the output)
> **Skills:** `repeatedly-apply-skill`, `multi-pass-bug-hunting`

Strictly serial passes. Each pass: find → fix → verify → next.

### Pass 1: Four parallel review missions

Launch simultaneously (independent scopes):
1. **Spec conformance** — every spec requirement present in implementation?
2. **Interface contracts** — output formats match input expectations across the chain?
3. **Responsibility boundaries** — orchestrator vs agent scope correct?
4. **Edge cases** — 20 failure scenarios, each checked

### Pass 2: Semantic deep review

Single agent, deeper focus. Dead instructions, implicit format assumptions, cross-agent terminology consistency, orchestrator parse points vs agent output formats.

### Pass 3: Ambiguity audit (Sonnet-specific)

Auditing ONLY the Sonnet-model files. Ambiguous pronouns, undefined terms, missing decision criteria, temporal confusion, output format edge cases.

### Pass 4: Adversarial review

Frame as hostile, not confirmatory. "Assume there ARE remaining problems — the prior reviewers had blind spots."

```
You are a hostile reviewer trying to BREAK this pipeline before it ships.
{N} prior passes found {M} issues. Your job is to find what they missed.

FRESH ANGLES:
1. Read examples in output format sections — do they match the format specs?
2. Trace a complete hypothetical run
3. Check shared files for cross-agent contradictions
4. Look for fixes from prior passes that introduced NEW problems
5. Check line counts — any file bloated from accumulated patches?
```

### Pass 5: Vault ground truth

Two-phase: triage (mark each signal-5 technique as SKIP/CHECK/MISSING), then deep read for CHECK and MISSING. Convergence: 0 MISSING, 0 CONTRADICTED.

### Review pass effectiveness

After the review loop completes, record findings per pass:

| Pass | Findings | Fixed | Highest severity | ROI assessment |
|------|----------|-------|-----------------|----------------|
| 1 (parallel) | _count_ | _count_ | _severity_ | _fill_ |
| 2 (semantic) | _count_ | _count_ | _severity_ | _fill_ |
| 3 (Sonnet) | _count_ | _count_ | _severity_ | _fill_ |
| 4 (adversarial) | _count_ | _count_ | _severity_ | _fill_ |
| 5 (vault truth) | _count_ | _count_ | _severity_ | _fill_ |

Over time this shows which passes have the highest ROI. The adversarial pass "found 2x the findings of constructive reviews combined" in the Issue Zero build — track whether this holds.

---

## Phase 5: Persist + Learn

> **Flywheel:** Post-implementation learning
> **Skills:** `cass-memory`, `operationalizing-expertise`

### 5.1 Persist session learnings

```bash
~/.local/bin/cm reflect --days 1 --json
```

### 5.2 Rate this methodology's effectiveness

After the pipeline ships, answer:
- Which phases helped most? Which were skipped or felt like ceremony?
- What was missing — what did you need that the methodology didn't provide?
- What would you do differently next time?

This is the methodology's feedback signal. Without it, Phase 5.5 (methodology updates) operates blind — you'll know what happened but not what to change. Record these answers. If ms is available, use `ms feedback add <methodology-id> --comment "..."`.

### 5.3 Update the reusable components table

Fill in the "Actual result" column in Phase 2.2's table with what really happened: what transferred cleanly, what needed adaptation, what was built from scratch.

### 5.4 Register new anti-patterns

Any failure pattern discovered during this build gets added to the Anti-Patterns section below in structured format. If ms is available, register via `ms antipatterns`.

### 5.5 Update this methodology

If the review loop discovered better processes or this build revealed gaps, update THIS document. After editing, run the methodology health check below to catch inconsistencies.

---

## Anti-Patterns

Each was learned from a specific failure. This document's tables are the source of truth. ms registration (if available) is for discoverability across projects, not a second source.

**Vault & Reading:**

| # | Pattern | Source | Active |
|---|---------|--------|--------|
| 1 | NEVER skip vault MOC reading. Reading beads make this trackable. | Issue Zero build | Yes |
| 2 | Read raw files IN FULL. `limit: 80` is not reading. | Issue Zero build | Yes |
| 3 | The idea-wizard brainstorm must be grounded in vault material. Run AFTER reading beads are closed. | Issue Zero build | Yes |
| 4 | Read PGA/vault source files directly. Don't rely on agent summaries — summaries compress away the judgment layers. | EEC Outline spec (2026-04-08) | Yes |

**Design & Architecture:**

| # | Pattern | Source | Active |
|---|---------|--------|--------|
| 5 | Present design decisions BEFORE writing. Cheapest point to catch issues. | Issue Zero build | Yes |
| 6 | The output spec comes before agent decomposition. Define WHAT, then HOW. | EEC Outline spec (2026-04-08) | Yes |
| 7 | Mining/discovery is separate from ideation/creation. Same mined data serves multiple pipelines. | EEC Outline spec (2026-04-08) | Yes |
| 8 | The mining layer surfaces extracted material, not pre-solved conclusions. | EEC Outline spec (2026-04-08) | Yes |
| 9 | Pre-write the dispatch table before agent skill files. It's the integration contract. | Issue Zero build | Yes |
| 10 | The orchestrator is the hardest file — write it last. | Issue Zero build | Yes |

**Review & Quality:**

| # | Pattern | Source | Active |
|---|---------|--------|--------|
| 11 | NEVER bias review prompts toward expected outcomes. "Should find near-zero" = confirmation bias. | Issue Zero build | Yes |
| 12 | ALWAYS run the adversarial review. It found 2x the findings of constructive reviews combined. | Issue Zero build | Yes |
| 13 | ALWAYS check MEDIUM findings honestly. 10 of 34 MEDIUMs were real runtime bugs. | Issue Zero build | Yes |
| 14 | ALWAYS spot-check subagent claims of "already present." Grep for the specific text. | Issue Zero build | Yes |
| 15 | Don't let review agents edit specs directly. Passes 3-4 REPORT findings. Main session decides. | Issue Zero build | Yes |

**Pipeline & Scale:**

| # | Pattern | Source | Active |
|---|---------|--------|--------|
| 16 | Don't anchor to current pipeline state during backward design. Define ideal, then check reality. | EEC Outline spec (2026-04-08) | Yes |
| 17 | Shared files serve multiple agents — edit carefully. | Issue Zero build | Yes |
| 18 | Track ALL status.json fields from the start. Define schema in spec, implement in orchestrator. | Issue Zero build | Yes |
| 19 | Skill file creation must be collaborative in main session, not delegated to subagents. | Issue Zero build | Yes |

---

## Methodology Health Check

Run after every update to this document:

- [ ] All [[wiki links]] resolve to existing files
- [ ] Anti-patterns table has no empty Source or Active fields
- [ ] Session sequencing in [[deliverable-spec-methodology]] is current
- [ ] Reusable components table reflects latest build's actual results
- [ ] Prompt templates in both this doc and [[deliverable-spec-methodology]] are current
- [ ] Checklist items below are actionable (no vague items)
- [ ] Phase numbers are sequential and consistent with [[deliverable-spec-methodology]]

---

## Checklist for Next Deliverable

- [ ] Relevant vaults exist ([[vault-creation-methodology]] if not)
- [ ] Follow [[deliverable-spec-methodology]] for the output spec (Phase 0)
- [ ] Backward design: ideal inputs per quality bottleneck (Phase 1.1)
- [ ] Backward design: map current pipeline against ideal inputs (Phase 1.2)
- [ ] Backward design: identify structural patterns in gaps (Phase 1.3)
- [ ] Agent decomposition via idea-wizard (Phase 2.1)
- [ ] Map reusable components — layers, not just agents (Phase 2.2)
- [ ] Write architecture spec (Phase 2.3)
- [ ] Multi-model triangulation on architecture spec (Phase 2.4)
- [ ] Iterative spec refinement — 3-4 passes (Phase 2.5)
- [ ] Pre-write dispatch table (Phase 2.6)
- [ ] Convert to implementation beads with dependencies (Phase 2.7)
- [ ] Load anti-patterns before implementation (cm context + ms antipatterns)
- [ ] Implement — collaborative, per-session workflow (Phase 3)
- [ ] Review loop — 5 passes, adversarial prompt pre-written (Phase 4)
- [ ] Record review pass effectiveness data (Phase 4 table)
- [ ] Rate methodology effectiveness (Phase 5.2)
- [ ] Update reusable components with actual results (Phase 5.3)
- [ ] Register new anti-patterns (Phase 5.4)
- [ ] Update this methodology if new patterns discovered (Phase 5.5)
- [ ] Run methodology health check

---

## Skill Toolchain Summary

| Phase | Primary Skill | Purpose |
|-------|--------------|---------|
| 0-1 | [[deliverable-spec-methodology]] | Output spec + backward design (6 sub-phases, see sub-methodology for tools) |
| 1.2 | Agent tool (parallel missions) | Current state mapping against ideal inputs |
| 2.1 | `idea-wizard` | Agent decomposition brainstorm (30→5→15) |
| 2.4 | `multi-model-triangulation` | Cross-model architecture review |
| 2.5 | `repeatedly-apply-skill` | Iterative architecture spec refinement |
| 2.7 | `beads-workflow` | Convert spec into implementation task graph |
| 2.7 | `beads-bv` | Optimal implementation ordering |
| 3.0 | `cass-memory` | Load anti-patterns before each session |
| 3.0 | `ms antipatterns list` | Surface prior build failures (if ms available) |
| 3.9 | `beads-br` | Close completed skill file beads |
| 4.* | `repeatedly-apply-skill` | Review loop (5 serial passes) |
| 5.1 | `cass-memory` | Persist new anti-patterns as rules |
| 5.2 | `ms feedback` | Rate methodology effectiveness (if ms available) |
| 5.5 | `operationalizing-expertise` | Update methodology from learnings |

---

## Related

- [[deliverable-spec-methodology]] — sub-methodology for Phase 0 (output spec creation)
- [[vault-creation-methodology]] — prerequisite for vault creation
