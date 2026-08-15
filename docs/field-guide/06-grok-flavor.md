# 06 — Grok as a front end

The first five chapters are harness-blind. This chapter is only the map of how Grok Build sits on the **same** brain as Claude Code.

Read 01–05 first. Read `config/rules/harness-shared.md` — that is the contract.

## What changes, what does not

Does **not** change:

- The planning loop (intent → plan → beads → execute → harden)
- Skills, rules, CLAUDE.md (they stay in `~/.claude/`)
- Windows + WSL hybrid, 127.0.0.1, hot/cold disk rule
- dcg / slb / cass / cm / br / bv / ntm / Agent Mail
- Claude auto-memory files (Grok reads and writes them)

Does change:

- You run `grok` for daily work, not `claude`
- Grok-only knobs live in `~/.grok/config.toml` (memory on, `compat.claude` pinned)
- Compaction events are `PreCompact` / `PostCompact`; the shared PCR script understands both envelopes
- ntm still has no native Grok pane. Operator sits in Grok. Workers stay `--cc` (Grok-sub or Kimi via `cc-router`)

## Where Grok looks

Grok scans Claude paths by default. That is the whole design. The thin adapter does **not** deploy a second skills/rules tree so the machine still works if someone later turns compat off — if compat is off, turn it back on.

| Thing | Canonical path | Grok-only extra |
|-------|----------------|-----------------|
| Skills | `~/.claude/skills/` | none |
| Rules | `~/.claude/rules/` + `CLAUDE.md` | none |
| Hooks | `~/.claude/settings.json` + `~/.claude/hooks/` | `~/.grok/hooks/compact.json` calls the shared PCR |
| Agents | `~/.claude/agents/` | none required |
| MCP | Claude registrations (`compat.claude.mcps`) | optional `grok mcp add` fallback |
| Auto-memory | `~/.claude/projects/*/memory/` | junction `~/.grok/memory/from-claude` |

## Memory

Claude auto-memory is the shared writable store. Grok must write new `user_` / `project_` / `reference_` / `feedback_` files there and keep that project's `MEMORY.md` current. `~/.grok/memory/MEMORY.md` is a pointer, not a second brain. cass / `cm` stay the procedural and session-history layer.

## Honest limit: ntm has no Grok pane type

`ntm spawn` understands `--cc`, `--cod`, `--gmi` / `--agy`, and Kimi-as-cc-variant. There is no first-class `--grok=N` you should depend on. Grok-sub workers: `ntm spawn <proj> --cc=N:grok-4.6` after CLIProxyAPI is up on `127.0.0.1:8317`.

## Commands

| Claude | Grok |
|--------|------|
| `claude` | `grok` |
| (brain already in `~/.claude`) | `grok inspect` to confirm it loaded that brain |
| `/model` inside Claude | `/model` or `Ctrl+M` inside Grok |

Do not run `claude mcp add` **and** `grok mcp add` for the same server unless compat MCP is actually broken.
