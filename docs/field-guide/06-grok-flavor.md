# 06 — Grok as a front end

The first five chapters are harness-blind. This chapter is how Grok Build sits on the **same** brain as Claude Code.

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
- ntm 1.29+ has native `--grok=N[:model[:effort]]` with send/interrupt (ntm#251). Prefer that over Claude Code + CLIProxyAPI
- dcg 0.11.1 parses Grok `toolInput` / `run_terminal_command` natively (dcg#319). The thin `dcg-grok-bridge.py` remains as backup

## Where Grok looks

Grok scans Claude paths by default. Do **not** copy skills or rules into `~/.grok/`. If `compat.claude` is off, turn it back on.

| Thing | Canonical path | Grok-only extra |
|-------|----------------|-----------------|
| Skills | `~/.claude/skills/` | none |
| Rules | `~/.claude/rules/` + `CLAUDE.md` | none |
| Hooks | `~/.claude/settings.json` + `~/.claude/hooks/` | `compact.json` (PCR) and `dcg.json` (bridge) |
| Agents | `~/.claude/agents/` | none required |
| MCP | Claude registrations (`compat.claude.mcps`) | optional `grok mcp add` fallback |
| Auto-memory | `~/.claude/projects/*/memory/` | junction `~/.grok/memory/from-claude` |

Impeccable PostToolUse/Stop hooks must be `cmd.exe /c ...\impeccable-hook.cmd`, not bash `[ ! -f ... ]`. Grok runs hooks in PowerShell.

## Memory

Claude auto-memory is the shared writable store. Grok writes `user_` / `project_` / `reference_` / `feedback_` files there and keeps that project's `MEMORY.md` current. `~/.grok/memory/MEMORY.md` is a pointer. cass / `cm` stay the procedural and session-history layer.

## Swarms

```bash
ntm spawn <proj> --grok=N
ntm spawn <proj> --grok=N:grok-4.6
```

WSL needs `/usr/local/bin/grok` exec'ing the Windows `grok.exe` (same shape as the agy shim). `--cc=N:grok-4.6` via CLIProxyAPI is fallback only.

## Commands

| Claude | Grok |
|--------|------|
| `claude` | `grok` |
| (brain already in `~/.claude`) | `grok inspect` to confirm it loaded that brain |
| `/model` inside Claude | `/model` or `Ctrl+M` inside Grok |

Do not run `claude mcp add` **and** `grok mcp add` for the same server unless compat MCP is actually broken.

## Custom models & stream filter proxy (OpenCode Zen / Muse Spark)

Grok CLI parses OpenAI Responses API SSE streams with a strict Rust `serde` enum. Upstream providers like OpenCode Zen inject non-standard `event: ping` frames that cause deserialization errors (`unknown variant ping`). Additionally, multi-turn history containing prior `type: "reasoning"` output items is rejected by upstream providers with HTTP 400 (`Invalid reasoning item id format`).

The bundle deploys a lightweight local filter proxy at `127.0.0.1:5210` (`~/.grok/opencode-proxy.cjs`):
- Strips `event: ping` frames in real-time.
- Sanitizes prior `reasoning` items from multi-turn `input` payloads before forwarding.
- Injects `OPENCODE_API_KEY` fallback if Grok forwards an xAI session token.
- Maintained as a persistent background daemon via Windows Startup (`opencode-proxy.vbs`) and Grok's `SessionStart` hook.
