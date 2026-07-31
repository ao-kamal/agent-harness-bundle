# Trigger Test Protocol

Test whether a skill's description triggers correctly before deployment.

> **Skip for user-invoked skills.** If the skill sets `disable-model-invocation: true`, its description is human-facing, not a trigger — there is nothing for the agent to match. Run this test only on model-invoked skills.

## Why This Matters

The description is **the** triggering mechanism. Claude uses it to select from 100+ skills. A skill with perfect instructions but a bad description will never activate.

---

## Protocol

### Step 1: Extract the Description

Read the skill's `description` field from its SKILL.md frontmatter. This is the string Claude's LLM sees when deciding which skill to invoke.

### Step 2: Generate 10 Mock User Messages

Write 10 realistic messages a user might send to Claude Code:

**5 SHOULD-TRIGGER messages:**
- 1 direct request using the skill's exact terminology
- 1 using a common synonym or alternate phrasing
- 1 indirect reference (describes the need without naming the skill)
- 1 minimal/terse request (fewest words that still imply this skill)
- 1 compound request where this skill is one part of a larger ask

**5 SHOULD-NOT-TRIGGER messages:**
- 1 adjacent task (same domain, different action)
- 1 vague request that could match many skills
- 1 request clearly meant for a different skill
- 1 that shares keywords but has different intent
- 1 that sounds related but is outside scope

### Step 3: Score Each Message

For each mock message, ask: given ONLY the description string, would Claude's reasoning match this message to this skill?

Score each message:
- **Correct** = should-trigger message matched, or should-not-trigger message rejected
- **Incorrect** = should-trigger message missed, or should-not-trigger message falsely matched

### Step 4: Evaluate

**Target: 9/10+ correct.**

If score < 9/10, identify which messages failed and categorize the failure:

| Failure Type | Cause | Fix |
|---|---|---|
| Missed trigger | Description lacks the term/phrase the user said | Add synonym or trigger phrase |
| False match | Description is too broad or uses generic terms | Narrow language, add specificity |
| Ambiguous | Description overlaps with another skill's domain | Add differentiating context |

### Step 5: Revise the Description

Edit the description to fix identified failures:
- Add missing trigger phrases or synonyms
- Remove or narrow misleading terms
- Add a "Use when" clause if absent

### Step 6: Re-run

Repeat Steps 2-4 with the revised description until 9/10+ passes. Keep the same 10 messages to measure improvement. If a revision fixes one failure but introduces another, the description needs structural rework, not more patches.

---

## Description Quality Rules

Description quality rules:

### Rule 1: Third Person Always

Start with a third-person verb. Never first person ("I can help you") or second person ("You can use this").

- YES: "Processes Excel files..."
- YES: "Generates commit messages..."
- NO: "I help with spreadsheets"
- NO: "Use this to analyze data"

### Rule 2: Specific + Trigger Phrases

Include what the skill does AND when to invoke it. The "Use when" clause is the bridge between the user's words and the skill's capabilities.

### Rule 3: Key Terms for Discovery

Include synonyms the user might say. Users don't read skill catalogs -- they describe what they need in their own words. The description must contain those words.

---

## Good vs. Bad Descriptions

### Good

```yaml
description: >-
  Analyze Excel spreadsheets, create pivot tables, generate charts.
  Use when analyzing Excel files, spreadsheets, tabular data, or .xlsx files.
```

Why it works: specific actions (analyze, create pivot tables, generate charts) + trigger contexts (when analyzing) + file type synonyms (Excel files, spreadsheets, tabular data, .xlsx).

```yaml
description: >-
  Generate descriptive commit messages by analyzing git diffs.
  Use when user asks for help writing commit messages or reviewing staged changes.
```

Why it works: action + method (generate by analyzing diffs) + user-facing trigger contexts (writing commit messages, reviewing staged changes).

### Bad

```yaml
description: Helps with documents
```

Why it fails: vague, no triggers, matches everything and nothing. What kind of documents? What kind of help? Every skill "helps with" something.

```yaml
description: Processes data
```

Why it fails: too generic, competes with dozens of other skills. No specificity about what data, what processing, or when to invoke.

```yaml
description: Does stuff with files
```

Why it fails: zero information content. Claude cannot distinguish this from any other file-related skill.

---

## Constraints

- Description must be <= 1024 characters
- No XML tags in the description
- One description per skill (no arrays or variants)

---

## Example Test Run

**Skill description under test:**
```
Analyze Excel spreadsheets, create pivot tables, generate charts.
Use when analyzing Excel files, spreadsheets, tabular data, or .xlsx files.
```

| # | Message | Expected | Result | Pass? |
|---|---------|----------|--------|-------|
| 1 | "Analyze this Excel file and make a chart" | TRIGGER | Matched | Yes |
| 2 | "I have a spreadsheet I need to summarize" | TRIGGER | Matched | Yes |
| 3 | "Can you look at the data in this .xlsx and find trends?" | TRIGGER | Matched | Yes |
| 4 | "pivot table" | TRIGGER | Matched | Yes |
| 5 | "I exported a CSV from our CRM, need to build a report with charts" | TRIGGER | Missed | No |
| 6 | "Write a Python script to read a CSV" | NO TRIGGER | Rejected | Yes |
| 7 | "Help me with this file" | NO TRIGGER | Rejected | Yes |
| 8 | "Create a PowerPoint presentation" | NO TRIGGER | Rejected | Yes |
| 9 | "Format this Word document" | NO TRIGGER | Rejected | Yes |
| 10 | "Calculate the average of these numbers" | NO TRIGGER | Rejected | Yes |

**Score: 9/10.** Message 5 failed because "CSV" and "report" are absent from the description.

**Revised description:**
```
Analyze Excel spreadsheets and CSV files, create pivot tables, generate
charts and reports. Use when analyzing Excel files, spreadsheets, CSVs,
tabular data, .xlsx files, or building data reports.
```

Re-test message 5: now matched. Score: 10/10. Ship it.
