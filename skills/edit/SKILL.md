---
name: edit
description: Run editing prompts on writing content. Sequential editing workflow with 10 specialized prompts covering developmental editing (arguments, structure, takeaways) and copy editing (redundancy, voice, parallelism, tenses, sentence structure, specificity, AI tells).
argument-hint: [list | prompt-number]
disable-model-invocation: true
---

# Editing Workflow

Run specialized editing prompts on user-provided writing content.

## Usage

- `/edit` or `/edit list` — Show the numbered prompt menu
- `/edit 1` through `/edit 10` — Load and run that specific editing prompt

## Prompt Menu

When the user runs `/edit` or `/edit list`, display this menu:

```
EDITING PROMPTS
===============

Developmental Editing:
  1. Amplify Your Arguments (Claim, Support, Takeaway)
  2. Structural Strategy (What, Why, How)
  3. Takeaway Bot

Copy Editing:
  4. Redundancy Bot
  5. Active Voice
  6. Parallelism
  7. Tenses
  8. Sentence Structure
  9. Specificity
  10. AI Tells Detector

Usage: /edit [number]
```

Then stop. Do not do anything else until the user picks a number.

## Prompt Files

Each prompt lives in its own file under `prompts/`:

- [01-amplify-arguments.md](prompts/01-amplify-arguments.md)
- [02-structural-strategy.md](prompts/02-structural-strategy.md)
- [03-takeaway.md](prompts/03-takeaway.md)
- [04-redundancy.md](prompts/04-redundancy.md)
- [05-active-voice.md](prompts/05-active-voice.md)
- [06-parallelism.md](prompts/06-parallelism.md)
- [07-tenses.md](prompts/07-tenses.md)
- [08-sentence-structure.md](prompts/08-sentence-structure.md)
- [09-specificity.md](prompts/09-specificity.md)
- [10-ai-tells.md](prompts/10-ai-tells.md)

## Running a Prompt

When the user runs `/edit [number]`:

1. Read the matching prompt file from the list above.
2. Tell the user which prompt is loaded (just the name, one line).
3. Ask the user to paste the content they want edited.
4. Once they paste content, apply the prompt instructions exactly as written — follow its REQUEST, Output Format, Edit Constraints, and Definitions precisely.
5. When done, tell the user which prompt numbers they haven't run yet in this session, so they know what's left.

## Rules

- Follow each prompt's output format EXACTLY. Do not add your own intro/conclusion text — the prompts explicitly disable that.
- Match the user's writing style as each prompt instructs.
- Do not combine or skip prompts unless the user asks.
- If the user gives a number outside 1-10, show the menu.
