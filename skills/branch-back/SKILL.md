---
name: branch-back
description: Fork a Claude Code session at an arbitrary past message in the JSONL transcript. Use when /branch can't reach far enough back (across compactions), when the user wants to "rewind" or "branch back to when I said X", or when forking by line / timestamp / grep. Wraps the `branch-back` CLI.
---

# branch-back

> **Core insight.** Built-in `/branch` only forks at the current cursor. The full JSONL transcript on disk is preserved across compactions — so anywhere you can locate, you can fork from. This skill teaches the inspect → cut → resume workflow that turns that fact into action.

## When to use

| User says... | First command |
|---|---|
| "branch back to when I said X" | `branch-back search --grep "X" --robot-json` |
| "fork session at line N" | `branch-back inspect --target N --robot-json` then `cut` |
| "rewind to ~3 hours ago" | `branch-back search --since <ISO> --until <ISO> --robot-json` |
| "we should redo this from when I picked Y" | search → inspect → cut |
| "cut here but I already know the line" | `branch-back cut --at-line N` |

## The canonical workflow (4 steps)

The user almost never knows the exact line — they discuss with you to narrow down. Lead them through:

```
1. DISCOVER  — branch-back search --grep "<term>" --robot-json
   • Iterate with the user, narrowing terms until ~3 candidates remain
   • For time-window queries: --since/--until ISO timestamps

2. INSPECT   — branch-back inspect --target <line> --robot-json
   • Returns clean cut boundaries near the target line
   • Look for "clean_cut": true rows
   • Pick the latest clean line ≤ the target

3. SYNTHESIZE TITLE  — read context, propose a memorable title
   • This step is YOUR job (the orchestrator), not the CLI's. Heuristic auto-titles
     are mediocre; you have the full surrounding context to do better.
   • See "Title synthesis" below for what to read and what a good title looks like.
   • Get user approval on the proposed title before running cut.

4. CUT       — branch-back cut --at-line <clean_line> --title "<approved>"
   • Always pass --title. The `[auto]` fallback exists only for non-Claude callers.
   • Prints `claude --resume <uuid>` AND lands the session in the picker.
```

## Title synthesis (the step Claude can't skip)

The user's bar: they should be able to find this branch in their `claude --resume` picker **3 months from now, with no recent context** (their phrasing: "drunk at 3am after 3 months"). Heuristic auto-titles fail this bar. Your job is to do the synthesis they can't get from raw fields.

**What to read before proposing a title:**

```
branch-back inspect --target <cut-line> --window 30 --robot-json
  # gives you 30 messages of surrounding context
```

Plus, from the JSONL directly via Read on `~/.claude/projects/<slug>/<session>.jsonl` if you need more depth — pull the 50 lines before the cut, look for: bead IDs (e.g., `20g0`, `4k38`), file paths being discussed, decisions being made, named features, the `--target` user prompt itself.

**Voice register (this is where agents get it wrong most):**

The title is a **museum-plaque-style label**, not a commit message and not a journal entry. It states what existed at that moment, factually, in plain language a non-coder colleague would understand. Three failure modes to actively avoid:

| Failure mode | Example (DON'T write like this) | Why it fails |
|---|---|---|
| **Commit-message voice** | `🔀 JSONL-truncate spike — post-cut at L6534, before /branch-back skill build` | Reads like a git log. Line numbers, abbreviations, internal vocab ("spike", "cut", "JSONL"). User's future self has to translate before recognizing the moment. |
| **First-person narrator voice** | `🔀 rewind hack just worked — before going down the skill-build rabbit hole` | Reads like a journal entry. Words like "just", "got X working", "hacky", "rabbit hole" are how you'd *tell someone the story*, not how you'd *label the moment*. |
| **Vague-vibes voice** | `🔀 before things got interesting` / `🔀 the inflection point` | Pretentious chapter-title energy. Names a feeling, not the artifact or event. |

**What works (state the context, like a label):**

| Good — names what existed + a pivot point |
|---|
| `🔀 conversation rewind script working — before skill build began` |
| `🔀 niche schemas drafted — before round 3 of GPT Pro revisions` |
| `🔀 firm_domain inference resolved — before planning-workflow began` |
| `🔀 reasoning-mode swarm complete — before Phase 5.5 verification` |

The pattern: **\<noun phrase describing what existed\> — \<before/after a named pivot\>**. Past tense or present-state. No first-person verbs ("got", "made"), no narrator adverbs ("just"), no internal abbreviations.

**Self-check before proposing the title to the user — answer all four:**

1. Does it contain `just`, `got`, `hack`, `worked` (as a verb), or other narrator words? → rewrite without.
2. Does it contain line numbers (`L6534`), abbreviations (`JSONL`, `cmd`), or function/file names? → replace with plain-language description.
3. Could a non-coder colleague guess what was happening from the title alone? → if no, rewrite.
4. Does it state **what existed** + **a pivot point**, both in plain English? → if no, restructure.

**Don't include the project name as a prefix.** The Claude Code resume picker is already scoped per-project; prefixing every title with `[<project>]` repeats the directory name with zero added signal.

**Constraint:** keep under 100 chars. The 🔀 prefix stays. After 🔀, no other forced format — em-dashes, parens, colons, whatever reads well.

**Always show the user your proposed title before running cut:**

```
Proposed title: 🔀 <your synthesis>
Cut command:    branch-back cut --at-line <N> --title "<title>"

OK to proceed, or want to tweak the title?
```

## THE EXACT PROMPT — running this for the user

When the user asks to branch back, paste this verbatim as your opening:

```
I'll help you locate the right branch point. Four steps:

1. SEARCH for candidate user prompts with a keyword (we iterate together until ~3 candidates).
2. INSPECT around the chosen line to find a clean cut boundary (cuts can't land mid-tool-cycle).
3. SYNTHESIZE TITLE — I read the surrounding context and propose a memorable name you can find in your `claude --resume` picker months from now.
4. CUT the session — writes a new JSONL under ~/.claude/projects/<slug>/ with the approved title.

What were you working on / talking about at the moment you want to branch back to? Even one keyword is enough to start.
```

## CLI surface (run `branch-back robot-docs guide` for the full handbook)

```
branch-back search    --grep TEXT [--since ISO] [--until ISO] [--kind prompt|assistant|both] [--limit N] [--robot-json]
branch-back inspect   --target LINE [--window N] [--robot-json]
branch-back cut       --at-line N [--title TEXT] [--dry-run] [--robot-json]
branch-back capabilities --json
branch-back robot-docs guide
branch-back doctor    [--robot-json]
```

All commands auto-detect: `--project` from cwd, `--session` from most-recent JSONL by mtime.

## After cut — what to tell the user

The cut subcommand prints `claude --resume <uuid>` AND echoes the title. The user's first message in the resumed session is theirs to write — they can override what was about to happen at the cut point with whatever they actually wanted. Suggest something concrete based on the cut context, e.g.:

```
> Skip the planning-workflow we were about to enter. The plan is already done at <path>.
> Read it and confirm understanding — we're past planning.
```

## Anti-patterns

| Don't | Do |
|---|---|
| Auto-pick a cut line without showing the user | Present 2-3 candidate clean boundaries from inspect and let them pick |
| Cut at an exact line returned by search | Search returns the user's *prompt* line; you usually want the line just before that prompt for "branch back to JUST before they said X". Always run `inspect --target <prompt_line>` to find the right clean boundary. |
| Run cut without inspect first when the user is unsure | Inspect is cheap (<1s). Skipping it leads to mid-turn refusals (exit code 2). |
| Skip title synthesis and let the `[auto]` fallback ship | The `[auto]` marker exists to scream "I didn't think." Always read context, propose an intelligent title, and pass `--title`. See "Title synthesis" above. |
| Strip the 🔀 prefix from a custom --title | The visual marker makes branched sessions findable in a long resume picker; users have explicitly asked for it. |
| Re-run cut at the same line and get confused by "idempotent_match: true" | Same kept content + same cut line = same UUID. Safe to re-run; nothing was clobbered. |

## Failure modes

- **`ERR-002` (exit 2): mid-turn refuse.** The chosen line is followed by a tool_result; cutting there would orphan a tool_use. The error prints up to 3 suggested clean lines further back. Pick one and re-run.
- **`ERR-101` / `ERR-102`: project not found.** Either pass `--project <slug>` explicitly, or `cd` into a project that has a Claude Code session at `~/.claude/projects/<auto-slug>/`.
- **`ERR-103`: session UUID not found.** List with `ls ~/.claude/projects/<slug>/*.jsonl`.
- **`claude --resume <uuid>` doesn't load.** Run `branch-back doctor --session <uuid>` to check parentUuid integrity + ai-title presence + project-dir writability.

## Verification (run this once after install)

```
branch-back capabilities --json     # contract check
branch-back doctor                  # env check
branch-back search --grep "test" --limit 3   # search-mode smoke test
```

## Companion file

CLI lives at `~/.local/bin/branch-back` (Python script) + `~/.local/bin/branch-back.cmd` (Windows shim). Stdlib only — no dependencies.
