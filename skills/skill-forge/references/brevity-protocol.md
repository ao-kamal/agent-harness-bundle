# Brevity Protocol

Context window is a shared resource. Every unnecessary token in a skill competes with conversation history, user content, and other loaded skills. This protocol is a step-by-step process for removing waste.

## Contents

- [Core Heuristic](#core-heuristic)
- [Three Causes of Length](#three-causes-of-length)
- [The No-Op Test](#the-no-op-test)
- [The BAD/GOOD Test](#the-badgood-test)
- [Step-by-Step Protocol](#step-by-step-protocol) (Steps 1-6)
- [Token Cost Estimation](#token-cost-estimation)
- [Post-Editing Bloat Check](#post-editing-bloat-check)

## Core Heuristic

**Claude is already intelligent.** Only include what Claude doesn't know from training data.

Challenge each line: "Does Claude need this? Does this justify its token cost?"

## Three Causes of Length

Length has three distinct causes, each with a different cure. Diagnose before cutting:

| Cause | What it is | Cure |
|-------|-----------|------|
| **Sprawl** | Too long though every line is live and unique | Progressive disclosure — push reference behind pointers; split by branch or sequence |
| **Sediment** | Stale layers that accumulated because adding feels safe and removing feels risky | Check each line for relevance; delete what no longer bears on what the skill does |
| **Duplication** | The same meaning in more than one place | Keep one source of truth; delete the copies |

## The No-Op Test

A **no-op** is a line the model already obeys by default — you pay tokens to say nothing. The test: *does this line change behaviour versus the model's default?* If two people disagree over whether a line is a no-op, they disagree about the default — settle it by running the skill, not by debating.

Run the test sentence by sentence, not just line by line. When a sentence fails, delete the **whole sentence** — don't trim words from it. Be aggressive: most prose that fails should go, not be rewritten.

A weak leading word is itself a no-op — *be thorough* when the agent is already thorough-ish. The fix is a stronger word (*relentless*), not a different technique.

## The BAD/GOOD Test

The BAD/GOOD comparison:

```markdown
# BAD (~150 tokens) - explains obvious things
PDF (Portable Document Format) files are a common file format that contains
text, images, and other content. To extract text from a PDF, you'll need to
use a library. There are many libraries available...

# GOOD (~50 tokens) - assumes competence
## Extract PDF text
Use pdfplumber:
```python
import pdfplumber
with pdfplumber.open("file.pdf") as pdf:
    text = pdf.pages[0].extract_text()
```
```

The BAD version spends 150 tokens explaining what PDF means and that libraries exist. Claude knows this. The GOOD version spends 50 tokens giving the specific tool and code. That's a 3x reduction with zero information loss.

## Step-by-Step Protocol

Run this pass on any skill file (SKILL.md or reference) before finalizing.

### Step 1: Read each section

Go section by section. Don't skim the whole file — evaluate each block independently.

### Step 2: Cut what Claude already knows

For each section, ask: "Does Claude already know this from training?"

Cut patterns:
- Explaining what common formats are (PDF, JSON, CSV, etc.)
- Describing what well-known libraries do
- Restating language features or standard library behavior
- Preambles like "In order to accomplish this task, you will need to..."
- Definitions of industry-standard terms

### Step 3: Measure token cost against value

For each remaining section, ask: "Does this justify its token cost?"

Estimate tokens: ~4 characters per token, or ~0.75 tokens per word. A 10-line paragraph is roughly 75-100 tokens.

Keep patterns:
- Direct commands ("Use X, not Y")
- Code examples with project-specific conventions
- Domain knowledge Claude lacks (proprietary APIs, internal workflows)
- Constraints that prevent known failure modes
- Tool configurations with non-obvious parameters

### Step 4: Flag verbose patterns

Search for these specific bloat signals:
- **Verbose preambles** before actionable content — cut the preamble, keep the action
- **Redundant examples** — one clear example beats three mediocre ones
- **Hedge language** — "you might want to consider" becomes a direct instruction or gets cut
- **Restated instructions** — if a rule appears in two places, pick the better location and delete the other

### Step 5: Measure total line count

Targets:
- **SKILL.md**: < 500 lines. If exceeding, split into reference files.
- **Reference files**: > 100 lines must include a TOC at top.

Count lines before and after. Record both numbers.

### Step 6: Check reference files

Apply Steps 1-5 to every reference file the skill loads. A lean SKILL.md that loads a bloated reference still wastes tokens.

## Token Cost Estimation

Quick reference for estimating token cost:

| Content | Approximate tokens |
|---------|-------------------|
| 1 word | ~1.3 tokens |
| 1 line of prose | ~10-15 tokens |
| 1 line of code | ~8-12 tokens |
| 10-line paragraph | ~75-100 tokens |
| 100-line file | ~750-1000 tokens |
| 500-line SKILL.md | ~3750-5000 tokens |

When deciding whether a section justifies its cost, compare its token count against what it prevents. A 50-token rule that prevents a common 2000-token mistake is worth it. A 200-token explanation of something Claude handles correctly by default is pure waste.

## Post-Editing Bloat Check

**Learning from the newsletter pipeline:** Accumulated fixes across editing rounds create bloat. Each individual edit may be justified, but after multiple revision passes the file can grow past the 500-line target without anyone noticing.

The brevity pass must run AFTER all content edits are complete, not interleaved with them. After finishing all revisions:

1. Re-measure total line count
2. Compare against the pre-edit baseline
3. If the file grew, re-run Steps 2-4 on the new content
4. Additions from editing rounds are not exempt from the token cost question
