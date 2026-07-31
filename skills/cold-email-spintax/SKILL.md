---
name: cold-email-spintax
description: Convert pre-written cold-email copy into Instantly-format spintax using the 8-rule spinning methodology. Use when spintaxing cold emails, follow-ups, or subject lines. Always runs after spam-guard clears the copy.
---

# Cold Email Spintax Skill

> Before writing any spintax, this skill must load and apply the spam guard from skills/spam-guard/SKILL.md. Every new word introduced through a spintax option must clear the spam guard banned word list before it is used. This is non-negotiable - the spam guard feeds into this skill.

## Purpose

Take pre-written cold email copy and produce a spintaxed version in
Instantly format. Applies to the initial email, all follow-up steps,
and subject lines. Always runs after the spam guard skill. Always
executes in two phases: write then audit.

## Spintax Format

{{RANDOM|option one|option two|option three}}
- RANDOM is always all caps
- No spaces between pipes and words
- Minimum two options per block
- Wraps the full set in {{ and }}

## The Eight Rules

Rule 1 - Every sentence's first word must be spintaxed.
Spam filters fingerprint sentence starts. No sentence starts with a
fixed unspun word. If the sentence starts with a custom variable like
{{firstName}}, leave the variable and spintax the first meaningful
word immediately after it.

Rule 2 - Spin every natural variation point, not just the first word.
After the first word, scan the rest of the sentence and spin every
verb, noun, modal, adjective, and short phrase that has a natural
synonym. Target: no consecutive run of more than 4-5 fixed words in
any sentence unless they are proper nouns or custom variables.

Rule 3 - Handle articles inside the block.
If options have mixed vowel and consonant starts and a fixed "a" or
"an" precedes them, pull the article inside the block.
Wrong: runs a {{RANDOM|hands-on|active}} process
Right: runs {{RANDOM|a hands-on|an active}} process

Rule 4 - Keep blocks short.
1-3 words per option. Never swap whole sentences.

Rule 5 - Minimum two variants per block.
Do not add weak options to inflate count. Quality beats quantity.

Rule 6 - Custom variables are untouchable.
Never wrap a custom variable inside a spintax block. Never include
one as an option. Spintax only the words around them.
Right: a {{RANDOM|hands-on|targeted}} process for {{custom_variable}}
Wrong: {{RANDOM|{{custom_variable}}|generic alternative}}

Rule 7 - Every new word introduced by spintax must clear the spam guard.
Load skills/spam-guard/SKILL.md and check every new word before
accepting it. Word variants are banned too - if the root is banned,
all inflected forms are banned.

Rule 8 - No em dashes.
Use commas, hyphens, or restructure. Never introduce em dashes.

## Priority Order

1. Grammatical correctness - every possible combination must be correct
2. Clarity - natural and unambiguous in every combination
3. Variation count - never sacrifice 1 or 2 to hit a number

## Combination Math

After spintaxing, compute:
total_combinations = product of (number of options in each block)
Target: roughly 3-4x your list size in total combinations.

## Two-Phase Execution

Phase 1 - Spintax Agent
Read the full copy holistically before writing a single block.
Understand the POV, register, tone, and pronouns. Then apply spintax
to every section following all eight rules.

Phase 2 - Audit Agent
Generate 50-100 random fully-parsed combinations. Read every one as
a complete email. Check each for:
- Grammatical correctness
- Article agreement (a vs an)
- Natural conversational flow - no formal or stilted alternatives
- Zero banned words in any combination (including word variants)
If any combination fails, fix the offending block and re-run.
Only output after all combinations pass cleanly.

## Output Report

After completing, report:
- Total {{RANDOM}} blocks applied
- Total possible combinations (the product)
- List size and combinations-to-list ratio
- Audit result: combinations tested, any that failed and how fixed
- 3-5 randomly parsed sample combinations for review

## What This Skill Does NOT Do

- Does not write new copy - only spintaxes existing copy
- Does not fill custom variables - that is a separate scraping step
- Does not modify the original copy sections - only adds spintax sections
- Does not import to the sending platform - that is a separate step
