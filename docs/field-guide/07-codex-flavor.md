# 07 — Codex flavor

The first five chapters are flavor-blind. This chapter is the Codex-specific map.

Read 01–05 first.

## What changes, what does not

Does **not** change:

- The planning loop (intent → plan → beads → execute → harden)
- Skills payload
- Windows + WSL hybrid
- dcg / slb / cass / cm / br / bv / ntm / Agent Mail

Does change:

- You run `codex`, not `claude` or `grok`
- Config lives in `~/.codex`
- Hooks live in `~/.codex/hooks.json` (official Codex lifecycle events: PreToolUse, PreCompact, PostCompact)
- MCP is `codex mcp add`, written into `~/.codex/config.toml`
- Instructions are `~/.codex/AGENTS.md` plus the project `AGENTS.md`

## ntm

Jeffrey's ntm already has a first-class Codex agent. Spawn with `--cod`. This flavor does not add a second Codex type.

```bash
ntm spawn myproject --cod=2
```

NTM launches Codex with `--dangerously-bypass-approvals-and-sandbox`. Codex TUI paste buffers still need the vibing-with-ntm flush (`C-u` then Enter). That is existing ntm operator knowledge, not a new agent.

`--grok` exists but is phase one (launch/discovery only). `--agy` is Antigravity. `--gmi` is leftover Gemini CLI.

## Hooks

Codex skips untrusted user hooks until you review them. After install, run `/hooks` and trust the harness entries. Automation can pass `--dangerously-bypass-hook-trust` (official flag). `features.hooks = true` is set in `config.toml`.

## Commands you will type instead

| Claude / Grok | Codex |
|---------------|--------|
| `claude` / `grok` | `codex` |
| `claude mcp add` / `grok mcp add` | `codex mcp add` |
| `grok inspect` | `codex doctor` |
| `/model` | `/model` |
| ntm `--cc` | ntm `--cod` |
