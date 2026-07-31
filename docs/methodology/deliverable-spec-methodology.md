---
created: 2026-04-08
updated: 2026-04-10
categories:
- pipeline-construction
- deliverable-specs
- methodologies
type: reference
---

# Deliverable Output Spec Methodology

How to define what a prospect receives — section by section, quality gate by quality gate — before any pipeline architecture or agent decomposition begins. This covers Phases 0 and 1 of the [[pipeline-construction-methodology]].

The output spec is the contract with the prospect. The architecture spec (Phase 2 of the parent) is the contract with the pipeline. If they conflict, the architecture changes.

---

## When to Use This

Before building any multi-agent deliverable pipeline. Follow this methodology to produce the output spec, then the backward design. Only after both are complete does agent decomposition begin (Phase 2 of the parent methodology).

Do NOT skip to agent decomposition without a complete output spec and backward design. Every downstream decision — how many agents, what each does, what the mining layer must surface — flows from what the prospect receives.

---

## Prerequisite: Subject-Matter Vaults

The relevant vaults must EXIST before grounding can begin. If the deliverable type requires craft knowledge not covered by existing vaults, create the vault first using the [[vault-creation-methodology]] in a separate session.

---

## Phase 1: Vault Grounding

**Goal:** Understand the craft methodology that governs this deliverable type. Read the source material directly — not summaries, not agent reports.

1. **Identify relevant vaults.** PGA (`AgentVaults/pga/`) covers EEC craft. WriteWithAI (`AgentVaults/writewithai/`) covers writing craft. Check `schema.md` in each vault for the query workflow.

2. **Read the relevant MOCs IN FULL.** They tell you which raw files to read and in what priority order (signal 5 first, then 4, then 3).

3. **Read signal-5 and signal-4 raw files IN FULL.** No limit parameters. No skimming. The raw files are the source of truth. MOC summaries are navigation aids, not substitutes. This is the #1 failure mode — skipping vault reading.

4. **Read existing agents and co-writers** that touch this deliverable type. Understand what currently exists before designing what should exist.

5. **Read the skill-forge skill** (`/skill-forge`). Governs how skill files are written downstream — validation checklist, archetypes, brevity protocol.

**Anti-pattern:** Do NOT rely on agent summaries of vault content. Reading PGA source files directly revealed judgment layers the summaries missed — the nuance that distinguishes "good enough" from "devastating."

---

## Phase 2: External Research

**Goal:** Find high-signal sources on what makes this deliverable type LAND — not just what it should contain.

1. **Launch a vault research agent.** Reads MOCs and raw files systematically, synthesizes with FULL ATTRIBUTION (file path + verbatim content for every claim).

2. **Use vault findings to design external research agent prompts.** The vault identifies what the methodology covers and what it DOESN'T. Gaps become research questions. Give external agents enough context about the deliverable so they're not searching blind.

3. **Launch external research agents.** Target operators, practitioners, books, academic research, YouTube transcripts. NOT generic SEO blogs.

4. **Save research to `References/`** with proper frontmatter and Related sections. Research persists across sessions — later deliverable specs can leverage earlier findings.

**Anti-patterns:**

- Do NOT launch external agents before the vault agent returns. Vault findings give the grounded context needed for sharp external prompts.
- Do NOT start Phase 3 (strategic decisions) before all Phase 2 research agents return. Research findings change strategic decisions. The temptation to draft job statements while agents are running produces ungrounded positions that need to be reworked.
- External research agents should specify `References/` as the save location in their prompts. Agents default to the working directory, requiring manual file moves. Include the full save path in every external research agent prompt.

### Prompt Templates

**Vault research agent:**

```
You are a vault research agent. Read source material from the agent vaults
and synthesize what makes {deliverable type} compelling.

Read EVERY MOC listed below IN FULL, then every signal-5 and signal-4 raw
file referenced in those MOCs IN FULL.

MOCs to read:
- {list PGA MOCs}
- {list WriteWithAI MOCs}

For EVERY finding, include:
- **Source:** exact file path
- **Evidence:** verbatim quote or specific content from the file
- **Usability:** verbatim / needs adaptation / needs interpretation

Structure output as:
1. Universal Principles (apply to all segments)
2. Segment-Specific Considerations
3. Quality Criteria / Checklists
4. Craft Techniques for {deliverable context} Specifically
5. Gaps (what the vault material does NOT answer)

Read everything. Thoroughness over speed.
```

**External research agent:**

```
You are a deep research agent. Find HIGH-SIGNAL sources on: {specific
research question derived from vault gaps}.

Context: {2-3 paragraph description of what the deliverable is, who
receives it, what its job is — enough that the agent isn't searching blind}

NOT generic advice. We want:
- Operators who do this themselves, not people who teach theory
- Books from practitioners with documented results
- Academic research on relevant psychology
- YouTube transcripts from people who've done this work
- First principles over tactics — extract the WHY behind what works

For EVERY finding:
- **Source:** URL or book/author reference
- **Who:** Operator, researcher, or theorist?
- **Key insight:** What did they say/find?
- **Evidence:** Verbatim quote or specific detail
- **First principle:** The underlying timeless principle
- **Relevance:** How this applies to our deliverable specifically
```

---

## Phase 3: Strategic Decisions

**Goal:** Lock the deliverable's JOB before defining its STRUCTURE.

1. **Examine through the diagnosis vs. prescription lens.** Does this deliverable diagnose problems (enhances positioning) or prescribe solutions (risks positioning)? Where on the spectrum? Governed by Enns, Baker, Millington research.

2. **Determine delivery timing.** Where in the prospect outreach sequence? Day 0 carries the entire first impression. Day 5-7 follows an established frame. Pre-call primes. Post-signature accelerates.

3. **If non-obvious, deploy adversarial agents.** Give each the same research but a different brief. Synthesis of opposing arguments produces stronger decisions than any single perspective.

4. **Lock the job in writing.** "This document's primary job is [X]. It is sent [when/how]. The prospect's desired reaction is [Y]."

**Anti-pattern:** Do NOT define structure before locking the job. Structure follows function. The EEC Outline's structure changed fundamentally once its job was locked as "Day 0 diagnostic artifact sent alone."

### Prompt Template — Adversarial Strategic Decision

When the strategic decision is non-obvious, launch 3 agents with opposing briefs. Each gets the same research files but a different position to steelman:

```
You are a strategic advisor arguing a specific position.

Read these research files IN FULL:
- {research file 1}
- {research file 2}

Also investigate the system to see ground truth:
- {relevant pipeline/prospect files}

YOUR POSITION: {position to steelman}

Steelman this position using the strongest available evidence.
You are NOT splitting the difference to be diplomatic — if the evidence
supports this position, argue it. If it doesn't hold up, say so honestly.

Your output must include:
- The case for this position (grounded in research + observed reality)
- How this resolves the core tension
- Addressing the strongest counterarguments
- Honest vulnerabilities (where is this position genuinely weak?)
- Your verdict with specific recommendation
```

---

## Phase 4: Structure Definition

**Goal:** Define what the document contains, section by section.

1. **Generate 30 possible structures (idea-wizard).** For each: sections included, what it emphasizes, what it omits, quality bottleneck. Ground in vault techniques and research findings.

2. **Winnow to the best 5.** Evaluate against the locked job. The best 5 should represent genuinely DIFFERENT approaches, not variations on one theme.

3. **Expand to the next best 10.** Many will be ELEMENTS or PRINCIPLES that strengthen the top 5 — composable building blocks, not competing structures.

4. **Synthesize the best-of-all-worlds.** Analyze all 15. Blend into a single structure. Write the full output spec:
   - Document properties (length, tone, voice, delivery, scannability)
   - The prospect's emotional journey (what they feel at each position)
   - Each section defined (what it is, what it does, how to build it, what it omits, quality gates)
   - Segment calibration table
   - Quality bottlenecks ordered by impact
   - Quality gate classification (mechanical vs. human-judgment)
   - What the document deliberately omits and why
   - What success looks like (the prospect's internal monologue)
   - Open design decisions

**Anti-pattern:** Do NOT skip 30→5→15. The EEC Outline's final structure integrated elements from 10 of the 15 — ideas #6-15 contributed as much as #1-5.

**Anti-pattern (Session 3, 2026-04-10):** Do NOT pre-solve the synthesis inside the expansion step. Steps 2-3 (generate 30 → winnow to 5 → expand to next 10) and step 4 (synthesis) are separate for a reason. The synthesis prompt produces a fresh, open-minded reanalysis of all 15 ideas. Pre-solving the blend during expansion anchors the synthesis to the analyst's own summary instead of letting the prompt do its work — which defeats the purpose of the synthesis step. Present the 15 ideas cleanly, THEN run the synthesis prompt as its own distinct step.

**Anti-pattern (Session 6, 2026-04-14):** Do NOT hard-code personality generalizations as segment rules. "VCs are territorial about thesis topics," "SaaS founders think in metrics," "Tech CEOs — any framing is friction" are ungrounded generalizations that lock strategy selection to segment labels instead of prospect-level data. The system must be segment-agnostic. What legitimately varies by segment: vocabulary (how they talk) and observation sources (where they publish) — both are grounded in research. What must be prospect-level inputs from the mining layer: strategy selection, ego sensitivity, DM saturation, directness preference, brevity preference, gatekeeper risk. When the system is agnostic, new segments (wealth management, biotech, media) work without new specs — they only need new vocabulary tables and observation source mappings.

### Quality Architecture Design Rules (from Session 2)

These apply when writing the quality bottlenecks and gate classification:

1. **Voice is cross-cutting, not a separate bottleneck.** For deliverables with writeprint-scoped elements (headline, teasers), voice fidelity is a co-equal quality dimension WITHIN those bottlenecks — not ranked separately. Voice doesn't have its own page section.

2. **Quality gates are floors. Add at least one ceiling.** Section-level gates catch failure (no exclamation marks, no revealed mistakes). But a page can pass every floor and still be soulless. Add a document-level gate that tests for the presence of genuine insight — the Voss test: "does the page contain at least one moment where the prospect thinks 'they see something I haven't articulated myself'?" Without a ceiling gate, the spec protects against bad output but does not engineer devastating output.

3. **Derivative deliverables need upstream prerequisites.** When a deliverable reads from another deliverable's output (Landing Page derives from EEC Outline), define minimum upstream quality. A mediocre upstream fed through a rigorous spec produces output that passes mechanical gates and fails judgment gates.

4. **Dual-audience deliverables need both emotional journeys.** When two readers evaluate the same artifact (prospect + their audience), define parallel emotional journey tables and specify primary audience per element in the calibration. Without explicit guidance, the co-writer optimizes for one reader and neglects the other.

5. **Don't research meta-psychology when the answer is quality.** "What makes someone evaluate an artifact and think 'they can build this'?" is answered by the artifact being good. Don't create research questions for phenomena that are just "the thing working as intended."

### The Synthesis Prompt

Use this exact prompt (or close variant) for step 4 above AND for the full rewrite in Phase 5. Provenance: first used in EEC Outline session (2026-04-08), produced the best output every time — 4 times in that session, once in the skill-forge rewrite (2026-04-10), each time producing a significantly better document than what existed before. This is the single highest-ROI prompt in the methodology suite.

```
I want you to REALLY carefully analyze and reread the existing spec and
the full list of ideas with an open mind and be intellectually honest
about them. Then I want you to come up with the best possible structure
that artfully and skillfully blends the "best of all worlds" to create a
true, ultimate, much better, much more applicable, more coherent clearer
spec that best achieves our stated goals and will work the best in
real-world practice to solve the problems we are facing and our
overarching goals while ensuring the extreme success of the enterprise as
best as possible; you should provide me with a complete rewritten spec
that integrates the best of all worlds with every good idea and finding
from our session today integrated. (you dont need to mention where each
idea and finding came from in our final enhanced plan) ultrathink
```

### Prompt Template — Structure Definition (idea-wizard)

This is a different use of idea-wizard from agent decomposition. This generates DOCUMENT STRUCTURES, not agent architectures:

```
Based on the vault material we read ({list MOCs}), the existing co-writer
({filename}), and the research findings ({list research files}):

What are 30 possible ways to structure the client-facing {deliverable type}
— the document sent to prospects as {delivery context}?

This is NOT about agents. This is about the OUTPUT — what sections should
the document contain, how should it be structured, what signals should it
embed?

The document must be:
- {constraint 1 from the locked job}
- {constraint 2}
- {constraint 3}
- The prospect finishes thinking: "{desired reaction from Phase 3}"

For each of the 30 structures, note:
- What sections it includes
- What it emphasizes
- What it deliberately omits
- What the quality bottleneck would be
```

---

## Phase 5: Spec Review

**Goal:** Pressure-test through 4 lenses. Strictly serial — ALL passes REPORT ONLY. The main session does the rewrite.

**Pass 1 — Prospect Simulation (REPORT ONLY).** Read as the recipient. "Would this make me take the call?" Check for the proposal shape problem — does the aggregate structure resemble a consulting proposal?

**Pass 2 — Internal Consistency (REPORT ONLY).** Every claim against every other claim. Word budget math. Are quality gates testable or vibes? Does the segment calibration table match what the structure can deliver?

**Pass 3 — Producibility (REPORT ONLY).** Can this be produced reliably at scale for 5,000-10,000 curated prospects? Don't design for data-sparse fallbacks. Don't anchor to current pipeline state — the pipeline is malleable.

**Pass 4 — Adversarial (REPORT ONLY).** The most important pass. It found the session's single biggest insight. Frame as hostile, not confirmatory.

**Full rewrite.** Integrate ALL findings from ALL 4 passes into a clean, confident document. Positive and structural (what the document IS) not defensive (what it ISN'T). Distill warnings into design rules. Use the synthesis prompt.

**Anti-pattern:** ALL 4 passes REPORT only. Subagents lack strategic context for spec edits. Session 5 (2026-04-13) confirmed: Pass 1 and Pass 4 findings directly contradicted each other (strategic imperfection vs. tension reliability). If Pass 1 had edited, Pass 4 would have caught worse problems. The synthesis rewrite needs the ORIGINAL spec + ALL findings to integrate properly. A spec patched by early passes is harder to rewrite cleanly. This is different from code review where Passes 1-2 fixes are clear-cut. For specs, all fixes are strategic.

**Anti-pattern (Session 3, 2026-04-10):** Use `/repeatedly-apply-skill` for spec review passes — NOT ad-hoc subagents or code-reviewer agents. The methodology's tool table (Phase 5) explicitly maps this. `/repeatedly-apply-skill` runs serial passes with progressive deepening, which is exactly what the 4-pass spec review requires. Using a different agent type loses the serial discipline and the progressive context accumulation that makes each pass sharper than the last.

### Quality Gate Classification — Three Tiers

Every quality gate in the spec gets one of three classifications:

**Mechanical:** Automatable with rules — grep, word count, regex, structural checks. Run programmatically. Examples: "no exclamation marks," "CTA is 3-5 words," "zero duplicate words in headline."

**Agent-reviewable:** Requires judgment, but a SEPARATE review agent with the right context data and a focused evaluation prompt evaluates reliably. The co-writer does NOT self-evaluate these — a different agent loads the relevant context (prospect content, writeprint, audience analysis, upstream deliverables) and evaluates the output. This is how the Issue Zero pipeline's review passes work. For each agent-reviewable gate, the spec must define: (1) what context the review agent reads, (2) what specific question it answers.

**Human-review:** Reserved for calibration runs only. Once the pipeline is validated on 10-20 prospects with human review, agent-reviewable gates are trusted at scale. No gates require permanent human review at 5,000-10,000 scale.

The Landing Page session (2026-04-09) established this classification. The EEC Outline spec's "human-judgment" gates should be understood as "agent-reviewable" — the classification predates this distinction.

### Prompt Template — Pass 4 Adversarial Review

This prompt produced the highest-ROI findings in the EEC Outline session (12 findings, including the meta-insight that the spec optimized for avoiding failure modes rather than producing emotional reactions):

```
You are a hostile reviewer trying to BREAK this spec before it ships.
Three prior passes found and fixed issues. Your job is to find what
they missed. Assume there ARE remaining problems.

Read the spec at: {spec path}
Read the research it claims to implement: {research file paths}
Read one actual output example: {example path if available}

Context: {strategic context — delivery timing, prospect type, scale,
what decisions have been locked}

YOUR ADVERSARIAL ANGLES:

A. Real-world failure scenarios:
- What if all elements are decent but none are devastating?
- What if the prospect already knows everything in the document?
- What if the document is technically perfect but feels soulless?
- What if a competitor sent something similar last month?

B. Research implementation check:
- For each major research finding, check: is it IMPLEMENTED in the
  spec, or just acknowledged?
- {list specific findings to check against}

C. Three-pass edit audit:
- Did fixes from Passes 1-3 introduce NEW problems?
- Is guidance actually actionable, or just warnings?
- Are quality gates enforceable at 5,000-10,000 scale?

D. Transformation test (if an internal version exists):
- Read the internal version. Imagine the client-facing version
  produced by this spec. Is it genuinely DIFFERENT, or just reformatted?

DO NOT EDIT THE SPEC. Report findings only:
- **Finding:** what's wrong
- **Severity:** CRITICAL / HIGH / MEDIUM / LOW
- **Evidence:** why you believe this
- **Suggested fix:** what should change

End with:
- Overall assessment: ready for pipeline construction, or needs another round?
- The single biggest risk the spec doesn't adequately address
```

---

## Phase 6: Backward Design

**Goal:** Define what INPUTS the pipeline needs. Work backwards from quality bottlenecks. This corresponds to Phase 1 of the [[pipeline-construction-methodology]].

### 6a — Ideal Input Design

For each quality bottleneck (ordered by impact), define the IDEAL input — not what exists, what SHOULD exist. "What data would give the co-writer raw material to produce the DEVASTATING version, not just the passing version?"

Ground this in the vault methodology. Where PGA simplifies for mass teaching, specify the judgment layers it leaves to human intuition. For each judgment layer: what data would give an AI co-writer equivalent quality?

Specify candidate SOURCES for each input — prospect content, audience behavior, segment knowledge, competitive landscape, external research.

**Anti-pattern (Session 6, 2026-04-14):** Do NOT reference specific pipeline filenames (voice-analysis.json, hidden-interests.json, theme-mapping.json, etc.) DURING the Phase 6a ideal input definition step. Phase 6a defines what the pipeline NEEDS using general source descriptions ("voice analysis exemplars," "engagement behavior interpretation," "content pillar analysis"). Phase 6b maps those ideal inputs against the current pipeline's specific files and artifacts. If both phases are completed and results are integrated into a single document, that's fine — the document contains both the ideal requirement and the current-state mapping. The anti-pattern is about the PROCESS: don't let knowledge of what currently exists constrain what you define as ideal. Define the ideal first (6a), then check reality (6b).

### 6a-verify — Ideal Input Verification

Before moving to 6b, launch 2 parallel verification agents to catch missing inputs:

**Mission 1 — Research-to-inputs:** For each major research finding implemented in the spec, does it create a data requirement? Is that requirement captured in the ideal inputs? Go finding by finding through each research file. The most valuable thing to find is an input the main session MISSED.

**Mission 2 — Pipeline-to-inputs:** What does the existing co-writer expect that isn't in the ideal inputs? What does the actual prospect data contain that could feed this deliverable but isn't captured? Which backward design inputs from OTHER deliverables also serve this one but aren't listed?

The ideal inputs are the foundation of the mining layer. Missing one here means it won't get built. These verification agents catch blind spots the main session has from generating the list itself.

### 6b — Current State Mapping

Deploy agents grouped by pipeline file clusters. Each reads agent definitions + actual outputs and reports per input: EXISTS and sufficient, EXISTS but insufficient (what's missing), DOESN'T EXIST. Agents REPORT only.

### 6c — Pattern Identification

Across all gaps, identify structural patterns. These become the design problems the mining layer must solve.

**Anti-pattern:** Do NOT design the mining layer from one deliverable's needs. The mining layer serves ALL deliverables. Complete specs for ALL deliverables, then design the mining layer from the union set of all ideal inputs.

### Prompt Template — Backward Design Missions

Launch parallel agents, each examining a different cluster of pipeline files. Each mission answers a specific QUESTION about the pipeline — not just "what files exist?" but "does the pipeline understand X?"

```
You are mapping current pipeline outputs against ideal inputs for a
client-facing {deliverable type} pipeline. REPORT ONLY — no edits,
no design decisions.

Your mission: {mission name}

Question you're answering: {specific question — e.g., "Does the pipeline
understand HOW the prospect thinks and talks — or just WHAT they talk
about?"}

Read the ideal inputs document: {backward design doc path}

You are mapping against these ideal inputs:
- {input ID} — {input name}
- {input ID} — {input name}
...

Read these agent definitions + actual outputs IN FULL:
- {agent definition path}
- {actual output path for a well-analyzed prospect}

The pipeline is MALLEABLE. Report what information EXISTS in any form.
For each ideal input:
- **EXISTS and sufficient** — produced in usable form
- **EXISTS but insufficient** — partially there (what exists AND what's missing)
- **DOESN'T EXIST** — not produced anywhere

Be specific. Quote actual fields, keys, and values from the output files.
```

---

## Session Sequencing

| Session | Deliverable                  | Produces                                                                                                                                                                                                                            |
| ------- | ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1       | EEC Outline (client-facing)  | DONE (2026-04-08) — output spec + backward design + research. NOTE: backward design was done WITHOUT 6a-verify (verification missions added in Session 2). Run retroactive verification before Session 6 to complete the union set. |
| 2       | Landing Page                 | DONE (2026-04-09) — output spec + backward design + research (opt-in psychology, curiosity gaps, B2B landing pages). 25 ideal inputs, 5 structural patterns.                                                                        |
| 3       | Day 1 Email (pre-call asset) | DONE (2026-04-10) — output spec + backward design + research (AI writing frontier, ghostwriting voice fidelity, teaching voice register). Delivery: post-booking, pre-call — not cold outreach. Cross-cutting finding triggered Session 8 (editing pipeline overhaul).                                                                     |
| 4       | Outreach Email               | DONE (2026-04-12) — output spec + observation framework + sequence architecture + backward design + cold outreach vault (120 files, 6 MOCs). 32 ideal inputs, 6 structural patterns (3 new). Open observation type library decision. 19 anti-patterns, 5 calibration artifacts, S2 Architecture. |
| 5       | Issue Zero                   | DONE (2026-04-13) — output spec + backward design + research (voice reproduction/stylometry, credibility evaluation/persuasion, long-form ghostwriting craft). 32 ideal inputs, 6 structural patterns. Tension model as primary structure with archetype-driven fallback. "Recognition not revelation" crystallization standard. Quality ceilings not just floors. 4-pass spec review (49 findings). Key research: Koppel/Argamon function word stability, Noonan "never taller," ELM central-route processing, Green/Brock transportation, differential confidence as expertise signal, Kintsch situation model, serial position effect. Anti-pattern: all spec review passes should be REPORT ONLY for output specs (Passes 1-2 editing removed — strategic context required for all spec edits). |
| 6       | Outreach sequence touches    | Full methodology treatment for the downstream touches in [[outreach-sequence-architecture]]: Day 3 DM, Day 5 follow-up email, Day 7 video, Day 10 phone, Day 14 final touch, long-term drip content model, reply handling templates. Before mining layer — backward design inputs feed the union set. Session 4 identified 2 mining-layer-grade gaps: observation diversity pool (multiple diverse observations per prospect across formats) and follow-up domain angles (conversation-continuation inputs distinct from S1 hooks). |
| 7       | Mining layer design          | Two-layer architecture (Timeless + Per-prospect). Union set with priority tiering (P0-P3), observation generator as primary architecture, execution record schemas, engagement state aggregation schema, static/active monitoring split, feedback loop architecture, firm-level prospect grouping, first-send testing protocol. Multi-session scope. |
| 8       | Editing pipeline overhaul    | Research + architecture redesign + skill rewrite. Motivated by Session 3 research (2026-04-10): trait-isolated passes, large-to-small sequencing, reason-then-score, section-by-section generation with voice re-injection. Prerequisite: Session 7 mining layer architecture (specifically the writeprint schema). Research grounding: ai-writing-frontier-research, ghostwriting-voice-fidelity-research. |

**Every session does its own research on what it doesn't know.** No session skips Phase 2 because a prior session "already covered it." Prior research compounds — later sessions inherit earlier findings — but each session identifies its OWN gaps from its OWN vault grounding and runs targeted research to fill them. This applies to deliverable spec sessions (1-5), the mining layer design (7), and the editing pipeline overhaul (8) equally. The mining layer design (Session 7) in particular needs targeted research — the spec sessions define WHAT inputs the pipeline needs, but HOW to produce them (writeprint extraction, exemplar sourcing, candidate pool generation, cross-deliverable decomposition) are mining layer design problems that require their own research grounding. Research files persist in `References/` with proper frontmatter and backlinks.

**Session 3 cross-cutting finding (2026-04-10):** The Day 1 Email research surfaced findings that apply to ALL deliverable pipelines, not just the Day 1 Email. The editing pipeline needs a principled rebuild — trait-isolated evaluation, large-to-small pass sequencing, reason-then-score agent prompts, and section-by-section generation with voice re-injection at boundaries. This is Session 8, deferred until mining layer design is complete so the overhaul reflects the union set of all quality requirements and consumes the writeprint schema from Session 7.

**Cross-session context:** Each session starts by reading this methodology, the parent [[pipeline-construction-methodology]], output specs from ALL prior sessions, and the MEMORY.md file.

---

## Tools and Skills

| Phase | Tool/Skill                     | Purpose                                                |
| ----- | ------------------------------- | -------------------------------------------------------- |
| 1     | Direct file reading            | Vault grounding — no shortcuts                         |
| 2     | Agent tool (vault research)    | Systematic vault synthesis with attribution             |
| 2     | Agent tool (general-purpose)   | External research — operators, books, first principles |
| 3     | Agent tool (opposing briefs)   | Adversarial strategic decision-making                  |
| 4     | idea-wizard                    | 30→5→15 structure generation                            |
| 5     | repeatedly-apply-skill         | 4-pass spec review                                      |
| 6     | Agent tool (parallel missions) | Current state mapping against ideal inputs              |

---

## Methodology Health Check

Run after every update:

- [ ] All [[wiki links]] resolve
- [ ] Session sequencing table is current (no sessions missing)
- [ ] All prompt templates have their code blocks intact (no broken fences)
- [ ] Anti-patterns have dates and are consistent with [[pipeline-construction-methodology]]
- [ ] Quality Architecture Design Rules are numbered sequentially
- [ ] Phase numbers match [[pipeline-construction-methodology]] mapping (this doc's Phases 1-6 = parent's Phase 0-1)

---

## Related

- [[pipeline-construction-methodology]] — parent methodology (this covers Phases 0-1)
- [[vault-creation-methodology]] — prerequisite for Phase 1 when vaults don't exist
