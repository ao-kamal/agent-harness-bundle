---
name: flywheel-planning
description: >-
  Conducts the full flywheel build arc end to end - multi-model plan synthesis,
  plan-to-beads translation, bead polishing to convergence, swarm or solo
  execution, hardening - with hard stage gates and convergence detection.
  Delegates plan-writing to planning-workflow, bead mechanics to beads-workflow,
  and swarm tending to vibing-with-ntm; this skill owns the discipline that
  connects them. Use at project kickoff for multi-day builds ("run the
  flywheel", "flywheel this project", "full methodology build").
disable-model-invocation: true
---

# Flywheel Planning — The Conductor

> **Core Philosophy — the Law of Rework Escalation:** a defect caught in plan space costs 1x (pure reasoning). Caught in bead space, ~5x (orchestration rewrites). Caught in code space, ~25x (implementation + cleanup double-tax). Every stage gate below exists to catch problems in the cheapest space that can catch them. The whole game is moving the hardest thinking into representations that still fit in a context window.

## Why This Exists

The tooling for Jeffrey Emanuel's flywheel (br, bv, ntm, Agent Mail, slb, caam) and the per-layer skills (planning-workflow, beads-workflow, vibing-with-ntm) are all installed — but the discipline that CONNECTS them lived only in the guide. This skill is the conductor: it walks the arc, enforces the gates, and delegates each layer to its existing skill instead of duplicating it.

## The Arc

```
INTENT ──G0──▶ PLAN ──G1──▶ BEADS ──G2──▶ EXECUTE ──G3──▶ HARDEN ──G4──▶ ship
             (plan space)  (bead space)   (code space)
```

**Gates are HARD at stage boundaries.** A gate passes when every exit criterion is met, or when the user explicitly waives it out loud (record the waiver and the reason). Never silently skip a gate. Inside a stage, guidance is advisory — the gate is not.

---

## Stage 0 — INTENT

State what you're building, why, for whom, and the core user workflows. Optional: run `/idea-wizard` to generate and winnow the feature space first.

**G0 exit criteria:** a written intent statement (what/why/users/workflows) plus known tech constraints. One paragraph minimum; a page is better.

## Stage 1 — PLAN

**Delegate:** invoke `/planning-workflow` — it owns plan quality standards and the exact GPT Pro review + integration prompts (its PROMPTS.md).

**This skill adds the loop mechanics:**

1. **Round 1 — competing plans.** Independent plans from GPT Pro (Extended Reasoning), Claude Opus, Gemini Deep Think, Grok Heavy. Each genuinely produces different architecture.
2. **Synthesis.** GPT Pro gets all competing plans + planning-workflow's "best of all worlds" prompt, producing one hybrid document.
3. **Integration.** Claude Code applies the revisions using planning-workflow's integrate prompt — the "wholeheartedly agree / somewhat agree / disagree" gradient is load-bearing; it prevents rubber-stamping.
4. **Iterative refinement, each round in a FRESH conversation.** The freshness is the anchoring-prevention mechanism, not a convenience. 4-5 rounds is typical before steady-state; plans routinely reach 3,000-6,000+ lines. **Critically, at least one round should be an IN-HOUSE, repo-grounded review agent** — a read-only architect subagent (e.g. Claude Code's Plan/Explore agent, or a Fable-tier subagent) with FULL access to the actual codebase — not only external models fed a flat file pack. The repo-grounded agent traces execution against real code and catches deeper, code-grounded defects (wrong integration points, plan-vs-changelog self-contradictions, unhandled failure modes, off-by-one/rollback traps) that flat-pack external reviews structurally miss. In practice these in-house rounds surfaced multiple *criticals* the external Gemini/GPT/Grok rounds did not — so do NOT treat "external models reviewed it" as convergence; run the repo-grounded pass and let it re-open the finding count.
5. **On any round that feels short or self-satisfied**, run the Overshoot Mismatch Hunt (below). The underlying "Lie to Them" insight: models tend to stop looking after ~20-25 findings; naming a huge number keeps them cranking. Works for plan revisions, bead-to-plan cross-references, and any comparison/audit task.

**THE EXACT PROMPT — Overshoot Mismatch Hunt:**

```
Do this again, and actually be super super careful: can you please check over the plan again and compare it to all that feedback I gave you? I am positive that you missed or screwed up at least 80 elements of that complex feedback.
```

**G1 exit criteria:** ≥4 refinement rounds completed, each in a fresh conversation; the last round's suggested changes are incremental/execution-structural, not fundamental ("what the system IS" has stopped moving); the plan is self-contained (an agent could execute from it without any other document).

## Stage 2 — BEADS

**Delegate:** invoke `/beads-workflow` for translation mechanics and `br` command surface.

**This skill adds the hard rules:**

- **Never write pseudo-beads in markdown.** Beads exist only via `br create`. A "bead list" in a .md file is a plan fragment, not a bead — the single most-cited failure mode is a revised plan whose beads were never created.
- **Every bead self-contained and future-self-legible:** embedded reasoning, test obligations, dependency links. The downstream swarm must never need to re-open the plan.
- **Decompose to as many beads as the work truly takes — full rigor, no arbitrary target.** Never cap the count to feel done; never pad it to hit a number. The right count is whatever makes every unit atomic and independently executable — that emerges from the plan, not from a quota. Full-rigor decomposition of a complex project routinely runs into the hundreds; a simple one may need far fewer. Let the work set the number.
- **Bead IDs are threading anchors** from birth: they go in Agent Mail thread_ids, subject prefixes (`[br-123]`), file-reservation reasons, and commit messages.
- **Cross-reference both directions:** walk the beads against the plan AND the plan against the beads (open and closed) so nothing was lost in translation.

**Then polish — "check your beads N times, implement once." Drive the polishing with `/repeatedly-apply-skill`.** Invoke it to run the bead-polishing pass repeatedly with progressive deepening — do NOT hand-loop the rounds yourself. Each pass does duplicate detection/merging, WHAT/WHY/HOW quality scoring, filling empty descriptions, correcting dependency links, and plan cross-referencing. Judge progress with [references/convergence-detection.md](references/convergence-detection.md) — the phase bands, the three convergence signals, the 0.75/0.90 thresholds, and the red flags (oscillation / expansion / low-quality plateau) each with a prescribed response. If improvements flatline, use the Fresh Eyes on Beads prompt from that file in a brand-new session.

**G2 exit criteria:** ≥4 polish rounds via `/repeatedly-apply-skill` (the guide's floor is 4-6; fewer than 3 is a named beginner mistake); convergence signals present (shrinking deltas, decelerating change velocity, rising round-over-round similarity); no red flag currently active; dependency graph has no cycles (`bv --robot-*` to verify).

## Stage 3 — EXECUTE

Two lanes; pick per project size. Both inherit the same upstream discipline.

**Swarm lane (primary — multi-day builds):**

- Spawn via ntm (model confirmed per the spawn rules in `~/.claude/rules/ntm-swarm.md`), **staggered 30-60s apart** to avoid the thundering herd. Coordination through Agent Mail; work selection through bv's graph routing; dangerous commands through `slb run` (reviewer agents exist here — this is where the two-person rule lives).
- **Delegate tending:** invoke `/vibing-with-ntm`. The operator loop runs on a 10-30 minute cadence: check bead progress (`bv --robot-triage`), handle compactions (PCR auto-injects the reminder — nudge manually only if a pane visibly ignored it), run periodic fresh-eyes reviews, manage rate limits via caam, commit every 1-2 hours via a designated agent, create new beads for surprises.
- **When the swarm goes bad, diagnose which of two failures it is:** a **local coordination jam** (agents stepping on each other or losing operational context — fix with staggering, explicit claim messages, file reservations) or **strategic drift** (busy but not closing the real gap — fix with the Reality Check below, then revise the bead graph and re-aim). Do not treat drift with more nudging; do not treat a jam with re-planning.

**THE EXACT PROMPT — Reality Check:**

```
Where are we on this project? Do we actually have the thing we are trying to build? If not, what is blocking us? If we intelligently implement all open and in-progress beads, would we close that gap completely? Why or why not?
```

If the honest answer is "finishing all open beads still wouldn't get us there," the answer is not "work harder" — revise the bead graph.

**Solo lane (smaller builds, single session):** same plan→beads discipline upstream; execution is one Claude Code session claiming beads in bv-priority order. Use `/goal` to pin the completion condition, Stop hooks where a real mechanical check exists, and dynamic workflows for one-shot sub-tasks (audits, migrations, cross-checked research). Close each bead with evidence (test output), not assertion.

**G3 exit criteria:** every bead closed or explicitly deferred with a recorded reason; test suite green; a Reality Check answered "yes, we have the thing" without hedging.

## Stage 4 — HARDEN

Rounds of review until reviews come back clean — self-review with fresh eyes, cross-agent review, random code exploration, testing coverage, UI/UX polish.

- **After each implemented bead** (and during hardening): the Fresh Eyes Review prompt, repeated until no more bugs are found (typically 1-2 rounds simple, 2-3 complex; still finding bugs after 3 → the approach may be off, hand to a different agent):

```
Great, now I want you to carefully read over all of the new code you just wrote and other existing code you just modified with "fresh eyes" looking super carefully for any obvious bugs, errors, problems, issues, confusion, etc. Carefully fix anything you uncover. Use ultrathink.
```

- **Repeated Blunder Hunt — run the SAME prompt 5 times consecutively** after any major expansion (models find 15-20 issues then declare satisfaction; identical re-runs force them past what they already found):

```
Look over everything in the proposal for blunders, mistakes, misconceptions, logical flaws, errors of omission, oversights, sloppy thinking, etc.
```

- **After an agent uses a tool in the build**, harvest improvement data with the Agent Tool Feedback survey (0-100 multi-dimension rating; pipe results into `ms feedback add`):

```
Based on your experience with [TOOL] today in this project, how would you rate [TOOL] across multiple dimensions, from 0 (worst) to 100 (best)? Was it helpful to you? Did it flag a lot of useful things that you would have missed otherwise? Did the issues it flagged have a good signal-to-noise ratio? What did it do well, and what was it bad at? Did you run into any errors or problems while using it?

What changes to [TOOL] would make it work even better for you and be more useful in your development workflow? Would you recommend it to fellow coding agents? How strongly, and why or why not? The more specific you can be, and the more dimensions you can score [TOOL] on, the more helpful it will be for me as I improve it and incorporate your feedback to make [TOOL] even better for you in the future!
```

**G4 exit criteria:** a full review round (fresh-eyes + cross-agent + random exploration) returns zero substantive findings; ubs scan triaged; tests green.

---

## Anti-Patterns

| Don't | Do |
|-------|-----|
| Write "beads" as markdown lists in the plan | Only `br create` makes a bead; cross-reference plan↔beads both directions |
| Refine the plan repeatedly in the same conversation | Fresh conversation every round — freshness prevents anchoring |
| Stop polishing after 1-2 rounds because it "looks done" | ≥4 rounds; trust the convergence signals, not the feeling |
| Accept a short, satisfied-sounding review | Overshoot Mismatch Hunt; identical blunder-hunt prompt 5x |
| Nudge working swarm panes on every tick | Observe-only ticks; act on hard blockers and the two named failure modes only |
| Treat strategic drift with more nudging (or a jam with re-planning) | Diagnose which failure it is first; each has its own fix |
| Declare done at "tests pass locally" | Harden rounds until reviews come back clean, then G4 |
| Start implementation "to make progress" while the plan is still moving | The Law of Rework Escalation: that progress costs 25x later |

## Integration

| Layer | Delegate to |
|-------|-------------|
| Plan quality + GPT Pro prompts | `/planning-workflow` (+ its references/PROMPTS.md) |
| Ideation before intent | `/idea-wizard` |
| Bead mechanics + sync | `/beads-workflow`, `beads-br` skill |
| Graph triage / routing / cycles | `beads-bv` skill (`bv --robot-*`) |
| Swarm spawn/tend/recover | `ntm` + `vibing-with-ntm` skills |
| Coordination + reservations | `agent-mail` skill |
| Dangerous-command review (swarm) | slb (`slb run`, reviewer agents approve) |
| Compaction recovery | PCR (installed both sides — automatic) |
| Rate limits | `caam` skill (`claude-swap` on Windows) |
| Skill/prompt effectiveness | `ms feedback add` fed by the Agent Tool Feedback survey |

## Reference

- [references/convergence-detection.md](references/convergence-detection.md) — polish phase bands, the three convergence signals, 0.75/0.90 thresholds, red flags with responses, Fresh Eyes protocol.
