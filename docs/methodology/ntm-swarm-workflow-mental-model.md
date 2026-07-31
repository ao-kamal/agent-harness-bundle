---
title: NTM Swarm Workflow — Mental Model
created: 2026-04-26
tags: [ntm, swarm, workflow, infrastructure, agents]
type: reference
---

# NTM Swarm Workflow — Mental Model

> **Purpose:** Orient yourself fast on how multi-agent swarms (`ntm` + Agent Mail + Beads + BV) fit into a Claude-Code-driven workflow on a Win+WSL hybrid setup. Read this when you're about to dispatch a swarm and aren't sure who plays what role.

## The cast of characters (4 distinct actors)

```
YOU (at the keyboard)
  ↓ talks to
MAIN CC SESSION  (this is your conversation, on Windows)
  ↓ loads skill, dispatches via WSL
NTM  (tmux orchestration tool, lives in WSL)
  ↓ spawns
TMUX SESSION  (named container, holds panes)
  ↓ contains
AGENT PANES  (cc / cod / gmi — the actual swarm doing the work)
```

**Critical insight:** the swarm is designed to **self-organize**. Agents pick beads via `bv --robot-next`, reserve files via Agent Mail, coordinate among themselves. There is no mandatory central orchestrator continuously babysitting them. The marching-orders prompt does the heavy lifting at dispatch time.

So your main CC session is a **dispatcher + on-call operator**, not a continuous babysitter.

## The flow (ongoing bead work — `multi-agent-swarm-workflow` skill)

```
1. YOU (in main CC):  "Spawn a swarm of 3cc + 2cod to work on example-swarm beads."
2. MAIN CC:           Loads multi-agent-swarm-workflow skill.
                      Runs (via WSL):
                        ntm spawn example-swarm --cc=3 --cod=2
                        ntm send example-swarm --all "$(cat marching_orders.txt)"
                      Reports: "Swarm spawned, 5 agents dispatched."
3. SWARM:             Each agent reads AGENTS.md, registers w/ Agent Mail,
                      runs `bv --robot-next`, claims a bead, reserves files,
                      works, commits, picks next bead. Self-organizes.
4. YOU:               Open SEPARATE WSL terminal:
                        wsl -d Ubuntu -u root
                        ntm dashboard example-swarm
                      Live structured view of pane states + activity.
5. MAIN CC:           IDLE — waiting for you to redirect or ask questions.
                      You can use it for other work while swarm runs.
6. INTERVENTION:      If swarm goes off the rails (visible on dashboard),
                      come back to main CC: "nudge pane 3 to commit and move on."
                      Main CC runs: ntm --robot-send=example-swarm --panes=3 --msg="..."
7. CONVERGENCE:       Swarm runs until beads exhausted, then idles (per
                      vibing-with-ntm convergence detection). You shut down:
                        ntm kill example-swarm
```

## Where the dashboard fits

`ntm dashboard <session>` is **YOUR window**, not main CC's.

- Run it in a **separate WSL terminal** alongside (not inside) your main CC session.
- It's an interactive TUI — main CC shouldn't open it. The skill explicitly says TUIs are for humans.
- Main CC uses `--robot-snapshot` / `--robot-status` (structured JSON) when YOU ask "how's the swarm doing?" — it doesn't sit on the dashboard.

Typical setup:

| Window | Purpose |
|---|---|
| **Main CC (Windows)** | Your conversation; dispatches; on-call intervention point |
| **WSL terminal (separate)** | `ntm dashboard <session>` — your live view |

Two windows side by side. Main CC is for talking to. Dashboard is for watching.

## Three distinct skill flavors (don't conflate them)

| Skill | Use case | Lifetime | Operator role |
|---|---|---|---|
| **`multi-agent-swarm-workflow`** | Ongoing implementation — agents grind through beads continuously | Indefinite (until backlog converges) | Tend occasionally; nudge when needed |
| **`modes-of-reasoning-project-analysis`** | One-shot analysis swarm — agents do a fixed task, ship a report | Bounded (~30-90 min) | Watch progress; main CC synthesizes when done |
| **`vibing-with-ntm`** | Operator playbook — recipe library for tending swarms | The operator role itself | This is HOW to tend, not WHAT to dispatch |

`vibing-with-ntm` is the lens you put on top — it tells whoever is operating (you OR main CC OR a `ntm controller` pane) how to act tick-by-tick.

## Who plays the operator? (architecture choice)

**Default: you, intermittently.** You watch dashboard, intervene via main CC when needed. Zero infrastructure overhead.

**Alternative 1: main CC as continuous operator.** Main CC enters a tending loop using `ntm --robot-attention --wait-until=...` to wake on events, applies vibing-with-ntm operator cards. Costs main CC's full attention; break out by saying "stop tending."

**Alternative 2: controller agent inside NTM.** `ntm controller <session>` spawns a coordinator pane WITHIN the tmux session. Controller-pane runs the operator loop autonomously. You can detach entirely. Use this for unattended overnight runs.

**Decision rule:**
- Short / attended runs → you operate.
- Half-day unattended → main CC tends + you check in.
- Overnight / multi-day → spawn a controller agent.

## Practical mental model (memorize this)

1. **Main CC dispatches and is on-call.** Not a continuous operator.
2. **Swarm self-organizes** via beads + Agent Mail. No central brain needed.
3. **You watch via `ntm dashboard <session>` in a SEPARATE WSL terminal.** That's the follow-along.
4. **You intervene via main CC when something needs nudging.** Main CC translates your ask into the right `ntm --robot-*` call.
5. **Two modes of dispatch skill: ongoing (multi-agent-swarm-workflow) vs one-shot (modes-of-reasoning).** Pick by use case.
6. **`vibing-with-ntm` tells the operator HOW to tend.** Applies whether the operator is you, main CC, or a controller pane.

## Command cheat sheet

```bash
# DISPATCH (in main CC, calls WSL)
ntm spawn <session> --cc=3 --cod=2                    # spawn swarm
ntm send <session> --all "$(cat marching_orders.txt)" # initial dispatch
ntm --robot-send=<session> --panes=3 --msg="..."      # nudge specific pane (non-interactive)

# YOUR FOLLOW-ALONG (separate WSL terminal)
ntm dashboard <session>                               # primary live operator surface
ntm palette <session>                                 # command palette companion
ntm activity <session> --watch                        # raw activity feed
ntm view <session>                                    # retile tmux to grid
ntm zoom <session> N                                  # zoom one pane
ntm attach <session>                                  # raw tmux attach

# MAIN CC INTROSPECTION (structured, non-interactive)
ntm --robot-snapshot                                  # full state dump
ntm --robot-status                                    # sessions/panes/agent states
ntm --robot-is-working=<session>                      # AUTHORITATIVE liveness signal
ntm --robot-capabilities                              # complete machine-readable API schema (use FIRST)

# WAIT (event-driven, not polling)
ntm --robot-wait=<session> --wait-until=idle --timeout=10m
ntm --robot-wait=<session> --wait-until=attention --timeout=5m

# SHUTDOWN
ntm kill <session>
```

## Common gotchas (already in the harness rules but reiterating)

- **`ntm activity` lags reality** — use `--robot-is-working` for ground truth.
- **`ntm send` defaults to CASS dedup check** — use `--robot-send` (non-interactive) for swarm loops.
- **Per-pane interrupt is `--robot-interrupt=SESSION --panes=N`** — NOT `ntm interrupt --pane=N`.
- **`ntm copy` uses `session:pane` syntax**, not `--pane=N` (different from `send`).
- **For one-shot reasoning swarms, write your own dispatch script** — vibing-with-ntm's marching-orders template assumes ongoing implementation.

## Related skills (load before driving)

- `ntm` — full command reference
- `vibing-with-ntm` — operator playbook (cards + recipes + anti-patterns)
- `multi-agent-swarm-workflow` — dispatch flow for ongoing implementation
- `modes-of-reasoning-project-analysis` — dispatch flow for one-shot analysis
- `agent-mail` — coordination primitives
- `br` / `bv` — bead management + graph triage

## Related infrastructure

- `config/rules/wsl-patterns.md` in this bundle — Win+WSL hybrid architecture
- `config/rules/ntm-swarm.md` in this bundle — the full ntm gotcha catalog
- `install/smoke-test.sh` in this bundle — verifies the entire stack is working
