# 02 — The Planning Loop

Chapter 01 argued that catching problems in plan space is roughly 25 times cheaper than catching them in code. This chapter is about how you actually get a plan good enough that it's worth handing to a swarm — because "think about it for a while" isn't a method, and the method that works is more specific and more mechanical than it first sounds.

## Round 1: competing plans, not one plan

The loop starts by generating several independent plans for the same problem, from different models — for example, GPT Pro's extended reasoning mode, Claude Opus, Gemini's deep-think mode, and whatever else you have access to. This isn't redundancy for its own sake. Different models genuinely produce different architectures for the same problem, not cosmetic rewordings of the same idea. You want the disagreement — it's the raw material for the next step.

## Synthesis: one model, all the plans, a specific prompt

Once you have several competing plans, one model (GPT Pro's extended reasoning is the one this methodology was built around) reads all of them together and produces a single "best of all worlds" synthesis. The prompt that does this is specific and worth using close to verbatim — it explicitly asks the model to blend the strongest ideas from every plan into one coherent document, and explicitly tells it not to bother attributing which idea came from which source. That second part matters more than it looks: attribution invites the model to hedge between options instead of committing to the strongest synthesis.

## Integration: agree, partly agree, or push back — never rubber-stamp

The synthesized plan comes back to you (or to Claude Code, applying the revision). The response to each suggested change is never a flat "accepted" — it's framed as *wholeheartedly agree*, *somewhat agree* (with a modification), or *disagree* (with a reason). This gradient is the whole point: a system that can only accept or reject collapses into rubber-stamping everything, because rejecting outright feels adversarial and accepting everything is the path of least resistance. Forcing a middle option keeps every suggestion actually evaluated.

## Refinement rounds: always in a fresh conversation

Once integration happens, you run several more refinement rounds — 4 to 5 is typical before a plan reaches something stable, and real plans in this methodology routinely grow to 3,000-6,000+ lines by the time they're done. The one rule that's easy to skip and shouldn't be: **each round happens in a fresh conversation**, not a continuation of the last one. This isn't a formality. A model that has spent the last three exchanges defending its own plan will unconsciously anchor on its own prior reasoning — a fresh conversation has no ego invested in the existing document and will actually find what's wrong with it.

## When a round feels too short: the Overshoot Mismatch Hunt

Models tend to stop looking for problems after they've found 20-25 of them — not because the plan is actually clean, but because that's roughly where "I've found a satisfying number of things" kicks in. When a review round comes back short or self-satisfied, don't accept it. Ask again, and name a much bigger number than you actually expect:

> Do this again, and actually be super super careful: can you please check over the plan again and compare it to all that feedback I gave you? I am positive that you missed or screwed up at least 80 elements of that complex feedback.

Naming an implausibly large number keeps the model cranking past the point where it would otherwise declare victory. This works for plan revisions, for checking beads against the plan, and for basically any comparison or audit task where "look harder" alone doesn't produce a harder look.

**Exit criteria for the Plan stage:** at least 4 refinement rounds completed, each in a fresh conversation; the most recent round's changes are about execution details, not "what the system fundamentally is" (that question has stopped moving); and the plan is self-contained enough that an agent could execute it without ever needing to ask you something the plan should already answer.

## Plan into beads: the single most common failure

Once the plan is solid, it gets broken into "beads" — a dependency graph of discrete, executable tasks, tracked by a tool called `br` (and viewed/triaged with `bv`). The most commonly cited failure in this whole methodology is deceptively simple: **a plan gets revised, and the beads describing it never get created or updated to match.** The plan looks done. The graph is stale. Work proceeds against the stale graph.

The hard rule that prevents this: **beads only exist via `br create`.** A bulleted "task list" sitting inside a markdown plan is not a bead — it's a plan fragment that looks like one, and it will not show up anywhere the swarm actually looks for work. Every bead needs to be self-contained: embedded reasoning for why it exists, explicit test obligations, explicit dependencies — enough that an agent picking it up never needs to go re-read the original plan. For a genuinely complex project, expect 200-500 beads. That's normal scale, not a sign something's gone wrong.

## Polish rounds: check the beads N times, implement once

A freshly-created bead graph is never right on the first pass. The discipline here is the same shape as plan refinement — repeated rounds, judged against real convergence signals rather than a feeling of "looks done":

- Early rounds tend to be wild swings — fundamental changes to what a bead even is.
- Middle rounds refine interfaces and boundaries between beads.
- Later rounds are edge cases and small corrections.
- Steady state is polishing — you're not finding new problems, just smoothing them.

Watch for three signals that you're converging: the size of each round's changes is shrinking, the rate of change is decelerating, and successive rounds look more similar to each other. And watch for three red flags that mean something's actually wrong, each with its own fix — don't treat them all the same way:

- **Oscillation** (a bead flips back and forth between two versions across rounds) — the problem itself is framed wrong; reframe it, don't keep polishing.
- **Expansion** (each round makes the bead bigger and more complex) — an agent is solving a problem by adding scope; step back and cut, don't add another round.
- **Plateau at low quality** (rounds keep happening but nothing improves) — this approach isn't working; stop and try a different one, don't grind out a sixth identical round.

Run at least 4-6 rounds before calling it done — fewer than 3 is a commonly-cited beginner mistake, because most of the real problems in a bead graph don't surface until at least the second or third pass. If improvements flatten out before that floor, bring in a genuinely fresh session — one that re-reads the project's `AGENTS.md` and the plan from scratch, with none of the assumptions the original session accumulated — and have it review the beads with no prior context to protect.

## Where this lives in the bundle

You don't need to hold all of this in your head. The `/flywheel-planning` skill is the conductor for the whole arc from chapter 01 — it enforces the stage gates and knows when to hand off to the more specialized skills underneath it:

- `/planning-workflow` owns plan quality itself and carries the exact synthesis and integration prompts, ready to use.
- `/beads-workflow` owns the mechanics of turning a plan into beads and running polish rounds.
- `/idea-wizard` is useful even earlier, if you're still narrowing down what to build before you have a firm intent statement.

Start a real project by invoking `/flywheel-planning` and letting it walk you through the gates — don't try to run this loop from memory.
