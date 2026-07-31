# Skill Physics

The forces behind the judgment calls inside skill-forge's phases. Where the rest of skill-forge is procedure (do these steps), this is the vocabulary for *why* a skill behaves predictably — or doesn't. Concepts adapted from Matt Pocock's `writing-great-skills`.

> **Root virtue: Predictability.** A skill exists to wrangle determinism out of a stochastic system. The goal is the agent taking the same *process* every run — not the same *output* (a brainstorming skill should predictably diverge). Every lever below serves predictability.

Each term lists the synonyms to **avoid** — the discipline of fixing one name per concept, practised here on this file.

## Contents
- [Invocation: the two loads](#invocation-the-two-loads)
- [Router skills](#router-skills)
- [Leading words](#leading-words)
- [Completion criteria](#completion-criteria)
- [Legwork](#legwork)
- [Premature completion](#premature-completion)

## Invocation: the two loads

Every skill is reached one of two ways, and each spends a different budget:

| | Model-invoked | User-invoked |
|---|---|---|
| Mechanics | omit `disable-model-invocation`; write a trigger-rich description | `disable-model-invocation: true`; description becomes a human-facing one-liner |
| Who can reach it | the agent (autonomously), other skills, **and** the human | only the human, by typing its name |
| Cost | **context load** — the description sits in the window every turn | **cognitive load** — the human must remember it exists |

Pick model-invocation **only when the agent must reach the skill on its own, or another skill must.** If it only ever fires by hand, make it user-invoked and pay zero context load. There is no model-only state: a description always *adds* agent reach on top of the human's, never removes it. Decide this in Phase 1, before archetype.

_Avoid:_ ability, capability.

## Router skills

When user-invoked skills multiply past what you can remember, that piled-up cognitive load is cured by a **router skill**: one user-invoked skill that names the others and says when to reach for each. It can only point, never fire them — user-invoked skills have no description for it to invoke. Build one once a domain has roughly five or more user-invoked skills.

_Avoid:_ dispatcher, menu, registry.

## Leading words

A **leading word** is a compact concept already in the model's pretraining that the agent thinks with while running the skill — *lesson*, *fog of war*, *tracer bullets*, a *tight* loop, *relentless*. Repeated as a **token, never as a sentence**, it accumulates a distributed definition across the skill and anchors a whole region of behaviour in the fewest tokens, by recruiting priors the model already holds.

It pays off twice:
- **In the body** it anchors *execution* — the agent reaches for the same behaviour every time the word appears.
- **In the description** it anchors *invocation* — when the same word lives in your prompts, docs, and code, the agent links that shared language to the skill and fires it more reliably.

Use it well:
- Reach for an **existing** pretrained word first. Coining your own works only if you define it clearly — and a made-up word recruits no priors, so you pay in definition tokens what a real word gives free.
- Hunt restatements a leading word retires: "fast, deterministic, low-overhead" → a *tight* loop. Three sites of prose collapse into one token.
- A leading word too weak to beat the model's default is a no-op (*be thorough* when the agent is already thorough-ish). Fix it with a stronger word, not more sentences.

_Avoid:_ keyword, term, motif.

## Completion criteria

For any skill with **steps**, every step ends on a **completion criterion** — the condition that tells the agent the work is done. It is a lever on two axes:

- **Clarity** — can the agent tell done from not-done? A vague bound ("understanding reached") lets the agent declare victory and move on. A checkable bound holds it.
- **Demand** — how much it requires. "Every modified file accounted for" forces thorough work; "produce a change list" does not. Demand binds flat reference too: "every rule applied" gives a step-less skill an exhaustiveness bar.

The strongest criteria are both checkable and exhaustive. Write them into steps explicitly; don't leave "done" to the agent.

_Avoid:_ done condition, exit condition, stopping rule.

## Legwork

The digging an agent does *within* a step — reading files, exploring the codebase, making the change — rather than offloading to the user. It is never its own step; it lives in the wording, raised by a demanding completion criterion or a leading word (*comprehensive*, *exhaustive*). It goes thin when the demand is missing or when premature completion cuts the step short.

_Avoid:_ scope, effort, coverage.

## Premature completion

*Failure mode.* The agent ends a step before it is genuinely done, because its attention slips to *being done*. A between-steps failure: a step-less skill that quits early is thin legwork, not premature completion.

Two forces fight. Visible **post-completion steps** — the steps still ahead — pull the agent to rush the current one; the more it sees, the stronger the tug. The completion criterion's clarity resists; a sharp, checkable bar holds, a vague one gives way.

Defence, **in order**:
1. **Sharpen the criterion first** — cheap and local. A sharp bound resists the pull no matter how many later steps are visible.
2. Only if the criterion is irreducibly fuzzy *and* you observe the rush, **hide the later steps** by splitting the sequence. Hiding works only across a real context boundary — a user-invoked hand-off or a subagent dispatch. An inline model-invoked call leaves the later steps in context and clears nothing.

_Avoid:_ premature closure, rushing, shortcutting.
