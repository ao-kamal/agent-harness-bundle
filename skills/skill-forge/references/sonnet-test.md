# Sonnet Compatibility Test

## Contents
- [Degree of Freedom Context](#degree-of-freedom-context)
- [The 7 Ambiguity Categories](#the-7-ambiguity-categories)
- [Worked Examples (HIGH findings)](#worked-examples)
- [Severity Levels](#severity-levels)
- [Audit Protocol](#audit-protocol)
- [When to Run](#when-to-run)

Protocol for auditing skill files that will be executed by Sonnet-class models. Sonnet is less forgiving of ambiguous instructions than Opus — instructions that seem clear to Opus cause misinterpretation at Sonnet scale.

Derived from the newsletter pipeline's Phase 3 Pass 3 (Ambiguity Audit), where Sonnet agents misread instructions that had worked fine during Opus-authored design sessions.

---

## Why This Exists

Every instruction in a skill file is a degree of freedom. The question is how much freedom to grant:

| Freedom | When | Example |
|---------|------|---------|
| **High** | Multiple valid approaches, context-dependent | Code review guidelines |
| **Medium** | Preferred pattern exists, some variation OK | Report templates with customizable sections |
| **Low** | Fragile/error-prone, consistency critical | DB migration scripts — exact command, no flags |

Sonnet-executed skill files need LOW freedom on structural instructions (formats, inputs, outputs, identity) and can tolerate MEDIUM freedom on creative instructions (prose style, emphasis choices). The audit below flags where freedom is accidentally high due to ambiguity.

---

## Seven Ambiguity Categories

Scan every instruction line in the skill file for each category.

### 1. Ambiguous Pronouns

"it", "this", "that" without a clear antecedent within 2 sentences.

**Test:** For each pronoun, can you point to exactly one noun it refers to? If two candidates exist, flag it.

### 2. Implicit Format Assumptions

Instructions that assume output format without stating it. "List the results" — bullet list? Numbered? Table? Prose with commas?

**Test:** Does the instruction contain a verb of production (list, output, report, summarize, describe) without an explicit format? Flag it.

### 3. Undefined Terms

Domain terms used without definition or example. "High-stakes section" — by what criteria? "Key themes" — how many? What qualifies?

**Test:** Would a contractor unfamiliar with your project know exactly what this term means? If not, flag it.

### 4. Missing Decision Criteria

"Choose the best approach" without specifying what "best" means. "If it affects the arc" — how to measure?

**Test:** Does the instruction require a judgment call without providing the rubric? Flag it.

### 5. Scope Ambiguity

Unclear whether an instruction applies to a section, the whole document, or a single instance.

**Test:** Add "for each X" or "across the entire Y" — if both readings are plausible, the original is ambiguous. Flag it.

### 6. Output Format Gaps

No explicit format spec for what the skill produces. Missing: file type, structure, required sections, length constraints.

**Test:** Could two agents following this skill produce structurally different outputs? If yes, flag it.

### 7. Conditional Instruction Gaps

"If X then Y" without specifying what happens when X is false. Sonnet does not infer the else-branch — it either halts or improvises.

**Test:** For every conditional, check: is the alternative path stated? If not, flag it.

---

## Severity Levels

| Severity | Definition | Action |
|----------|-----------|--------|
| **HIGH** | Will cause wrong output or agent confusion at runtime | Rewrite before shipping |
| **MEDIUM** | May cause suboptimal output depending on context | Rewrite unless explicitly intended as flexible |
| **LOW** | Minor clarity improvement, unlikely to cause runtime error | Fix if convenient |

---

## Concrete Examples (Newsletter Pipeline)

These are real HIGH findings from the newsletter pipeline's Sonnet ambiguity audit.

### HIGH: Temporal Confusion

**Original instruction:** "Referencing your previous analysis, identify patterns in..."

**Problem:** The Voice Specialist agent had no "previous analysis." This instruction assumed conversational continuity — that the agent had been part of an earlier exchange. Subagents are dispatched fresh. They have no prior context. Sonnet interpreted "your previous analysis" as a reference to something it should have produced earlier in the same run and generated a hallucinated summary.

**Fix:** "Referencing the voice analysis file at `processed/[slug]-voice-analysis.json`, identify patterns in..."

**Rule:** Never use temporal references ("previous", "earlier", "above") to point to external data. Use explicit file paths.

### HIGH: Identity Confusion

**Original instruction:** "Compare the themes against your PRIOR report and flag contradictions."

**Problem:** Sonnet interpreted "your PRIOR report" as referring to its own output from an earlier step. The instruction actually meant another agent's output file (the theme-mapping report). Sonnet produced a self-referential comparison against its own in-progress work.

**Fix:** "Compare the themes against the Theme Mapping report at `processed/[slug]-theme-mapping.json` and flag contradictions."

**Rule:** Never use "your" to refer to another agent's output. Name the specific file and the agent that produced it.

---

## Audit Protocol

### Step 1: Read the skill file

Read the entire SKILL.md and every referenced file (references/, shared layers). Note which model executes this skill — this protocol only applies to Sonnet-assigned files.

### Step 2: Line-by-line category scan

For each instruction line, check all 7 categories. Record findings in this format:

```
LINE: [exact text of the instruction]
CATEGORY: [1-7, by name]
SEVERITY: HIGH | MEDIUM | LOW
PROBLEM: [what Sonnet would misinterpret and why]
FIX: [rewritten instruction]
```

### Step 3: Triage

- HIGH findings: rewrite the instruction immediately. Verify the rewrite resolves the ambiguity without introducing new ones.
- MEDIUM findings: rewrite unless the ambiguity is intentional (high-freedom creative instruction).
- LOW findings: fix in the same pass if possible, defer otherwise.

### Step 4 (optional): Live Sonnet dispatch

Dispatch a Sonnet subagent to execute the skill on a mock task. Provide realistic input files. After execution, review:

- Did the agent ask clarifying questions? (Each question = an ambiguity the audit missed.)
- Did the agent produce output that deviates from expectations? (Each deviation = a misinterpretation.)
- Did the agent hallucinate inputs or references? (Each hallucination = a temporal or identity confusion.)

Record every confusion point as a new finding and loop back to Step 2.

### Step 5: Verify zero HIGH findings

Re-scan the revised skill file. The file ships when HIGH count = 0. MEDIUM count should be 0 or explicitly justified. LOW findings are acceptable.

---

## When to Run This

- Before shipping any skill file assigned to Sonnet execution.
- After major edits to a Sonnet-assigned skill file.
- During Phase 3 of the pipeline construction methodology (Review Loop, Pass 3).
- When a Sonnet agent produces unexpected output — run the audit to find the root cause before patching behavior.
