# 01 — Philosophy

This bundle gives you a lot of tools. Before any of them matter, you need the thinking that makes them worth having. That's what this chapter is. Read it before you install anything, and come back to it once things are running — it'll make more sense the second time.

The chapters in this field guide build on each other:

1. **Philosophy** (this one) — why any of this is worth the trouble.
2. **The planning loop** — how a plan actually gets built and turned into work, in detail.
3. **Windows + WSL** — the mental model for the hybrid setup this bundle installs.
4. **Meta-learnings** — fifteen specific, transferable lessons, each earned the hard way.
5. **Vault hygiene** — how to keep your own notes clean once you start writing things down.
6. **Grok flavor** — what changes when the agent CLI is Grok instead of Claude Code. Skip if you are on the Claude flavor.

Read them in order once. After that, they're reference — come back to whichever one is relevant.

## The core idea: spend tokens where they're cheap

Every hour you spend working with an AI coding agent, you're spending two different kinds of effort: thinking about what to build (planning), and actually building it (implementation). It's tempting to treat these as the same thing — just "work" — and rush from a rough idea straight into code. This setup is built around a specific, hard-nosed argument for why that's a mistake: **the same bug costs wildly different amounts depending on where you catch it.**

Catch a design flaw while you're still just reasoning about the plan in a markdown document, and fixing it costs you almost nothing — you rewrite a paragraph. Catch it after you've broken the plan down into a graph of discrete tasks (this bundle uses a tool called `br`/`bv`, "beads," for that — more on it in the next chapter), and fixing it costs you a rewrite of that whole graph: dependencies shift, some tasks become pointless, others need splitting. Catch it after code has actually been written, and now you're paying for the wasted implementation *and* the cleanup, on top of the fix itself.

Jeffrey Emanuel, whose "Agent Flywheel" methodology this bundle draws heavily from, calls this the **Law of Rework Escalation**: a defect caught in plan space costs roughly 1x. Caught in bead space, roughly 5x. Caught in code space, roughly 25x. The exact multipliers aren't the point — the shape is. Every gate and every "are you sure" in this setup exists to catch problems in the cheapest space that can catch them, because moving the hard thinking earlier is the single highest-leverage thing you can do with an AI agent's time and yours.

This is why a properly-run project with this bundle looks like it spends an uncomfortable amount of time just *talking* before any code exists. That's not overhead. That's the entire point.

## The arc: Intent → Plan → Beads → Execute → Harden

Concretely, a project moves through five stages, and the harness treats the boundary between each one as a real gate — not a suggestion, something you have to consciously pass or consciously decide to skip:

1. **Intent** — you state what you're building, why, for whom, and what the core workflows are. One paragraph minimum.
2. **Plan** — a written plan, refined through multiple rounds (chapter 02 covers exactly how). Exit only once the plan is self-contained enough that someone else could execute it without asking you anything.
3. **Beads** — the plan gets broken into a dependency graph of discrete, self-contained tasks. Exit only once the graph has been polished through several rounds and has stopped changing in fundamental ways.
4. **Execute** — the tasks actually get built, either by you working through them one at a time or by a swarm of agents working the graph in parallel.
5. **Harden** — review rounds until reviews come back clean. Not "tests pass once." Clean.

Skipping a gate is sometimes the right call — but it should be a decision you make out loud, not something that happens because nobody stopped to check. The whole arc exists so that the expensive stage (Execute) only ever touches work that's already been cheaply de-risked in the stages before it.

## Tend the swarm, not the code

Once you're running multiple agents in parallel (this bundle sets up a tool called `ntm` for exactly that), your job changes shape. You are not reading every line of code they write. You are not manually assigning every task. A well-built bead graph and a working coordination layer mean the agents pick their own next task, avoid stepping on each other's files, and report back through a shared channel.

Your actual job is the operator's job: check in every 10-30 minutes, not continuously. Notice when something's gone quiet or gone in circles. Tell the difference between two distinct failure modes, because they have opposite fixes:

- **A local coordination jam** — agents stepping on each other's files, or losing track of who's doing what. Fix: stagger how they start, make coordination explicit, check the file-reservation system is actually being used.
- **Strategic drift** — the swarm is busy, commits are landing, and none of it is closing the actual gap between what exists and what you're trying to build. Fix is never "nudge harder." Stop, ask the honest question — "if we finish every open task right now, do we actually have the thing?" — and if the answer is no, go back and revise the plan or the task graph.

Confusing these two costs you real time: nudging a strategic-drift swarm just makes it build the wrong thing faster and look more finished while doing it.

You're tending a system, not proofreading a document. The chapters ahead teach you the difference — chapter 2 covers the planning and task-graph side in depth; the operator loop itself lives in the `vibing-with-ntm` skill this bundle installs.

## Why "invoke the skill first" isn't paranoia

This bundle installs a lot of tools, and almost every one of them has a dedicated Claude Code skill — a reference document Claude is supposed to read before using the tool, every time, even for a tool it thinks it already knows well. That "even for tools it thinks it already knows" part is the important bit, and it's not a hedge — it's a rule earned by a specific failure.

One of the tools in this stack (`ntm`, the multi-agent orchestrator) has a flag called `--no-hooks`. Read from the tool's help text alone, it looks like it should disable Claude Code's permission-hook injection into spawned agent panes — a reasonable guess. It's wrong. `--no-hooks` actually controls something unrelated (the tool's own internal command-tracking), and the real way to make spawned agents safe is a completely different mechanism (`ntm safety install`, plus a PATH ordering trick). The only way to find that out is to read the skill and its reference docs — guessing from a flag name, however plausible, gets you a confidently wrong answer.

Tools evolve. Flags get repurposed. A README and the actual binary drift apart (one tool in this stack documents a `--robot` flag that doesn't exist — the real flag is `-m`). "I used this last week" is not the same claim as "I know how this behaves today." Reading the skill first is how you catch that drift before it costs you an hour of confidently wrong guessing.

One tool (`dcg`, a guard against destructive commands) gets this treatment even more aggressively: the moment it blocks something, you read its skill *before reacting at all* — no rewording the command, no working around it from memory. A block is a checkpoint asking you to look, not an error asking you to route around it.

## Why this setup feels strict

If you read through this bundle's configuration, you'll notice a lot of capitalized, absolute-sounding language: NEVER do X, ALWAYS do Y, no exceptions. That's a deliberate choice, not an accident of writing style, and it's worth understanding why — because the same bluntness would be a bad habit in most other writing.

Normally, if you find yourself writing "you MUST include X" to patch a system that isn't producing X on its own, that's a sign the system is broken and you should fix the system, not paper over it with a stronger command. That's a real anti-pattern, and it applies to almost everything — prompts, schemas, code. But there's one place it doesn't apply: rules that govern an agent's own runtime behavior, where there is no upstream layer left to fix. When a rule *is* the top of the stack — nothing else produces the behavior, the rule is the only thing that can — aggressive, absolute language is the correct engineering choice, not a symptom of weak design.

Nearly every strict rule in this bundle exists because something specific went wrong once, cost real time to diagnose, and got written down so it wouldn't happen twice. Chapter 04 walks through fifteen of these lessons directly. The strictness isn't decoration. It's a paid-for lesson, written down so you don't have to pay for it again.

## One more thing: this scales down, too

Everything above is written with a multi-agent swarm in mind, because that's where the stakes are highest and the lessons are sharpest. But the arc — Intent, Plan, Beads, Execute, Harden — applies just as much to a solo afternoon with a single Claude Code session fixing one feature. The scale changes what Execute looks like (one session claiming tasks in order, instead of several agents working a graph in parallel); it doesn't change whether planning first is worth it. Don't wait until you're running a swarm to start taking the earlier stages seriously — the habit is worth building on small work first.

Next: chapter 02, the planning loop itself.
