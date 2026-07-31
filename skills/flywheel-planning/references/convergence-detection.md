# Convergence Detection — When to Stop Polishing

Source: Jeffrey Emanuel's Agent Flywheel complete guide ("Convergence Detection: When to Stop" + "Fresh Eyes Technique"), quoted/condensed faithfully. Applies to bead polishing (Stage 2 / gate G2) and, by analogy, to repeated critique passes anywhere.

## Phase bands

Bead polishing follows numerical-optimization convergence patterns:

| Rounds | Phase | Character |
|--------|-------|-----------|
| 1-3 | Major Fixes | Wild swings; fundamental changes land |
| 4-7 | Architecture | Interface/boundary refinements |
| 8-12 | Refinement | Edge cases |
| 13+ | Polishing | Converging to steady state |

The floor is **4-6 rounds**. "Not doing at least 3 rounds of polishing" is one of the guide's named beginner mistakes.

## The three convergence signals

1. **Output size shrinking** — agent responses getting shorter each round.
2. **Change velocity decelerating** — the rate of change slowing.
3. **Content similarity rising** — successive rounds looking more like each other.

When the weighted convergence score reaches **0.75+, you're ready to finalize. Above 0.90, you're hitting diminishing returns.**

## Early-termination red flags (each has a prescribed response — don't just keep polishing)

| Red flag | What it looks like | Response |
|----------|-------------------|----------|
| **Oscillation** | Alternating between two versions | Reframe the problem |
| **Expansion** | Output growing instead of shrinking | Step back — the agent is adding complexity |
| **Plateau at low quality** | Stable but bad | Kill the current approach and restart fresh |

## What a polishing round actually does

Duplicate detection and merging; quality scoring on WHAT/WHY/HOW criteria; filling empty bead descriptions; correcting dependency links; cross-referencing beads against the markdown plan (and the plan against the beads, both open and closed) to ensure nothing was lost. Choose duplicate survivors on richer testing specs, better dependency chains, higher priority.

## Fresh Eyes Technique

If improvements start to flatline, start a brand-new Claude Code session and run:

```
First read ALL of the AGENTS.md file and README.md file super carefully and understand ALL of both! Then use your code investigation agent mode to fully understand the code, and technical architecture and purpose of the project. Use ultrathink.
```

…then have that fresh session review the beads. The point is deliberately excluding the accumulated assumptions of the session that created them.
