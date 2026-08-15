# Grok Build — thin adapter

Grok Build already reads `~/.claude/` (skills, rules, CLAUDE.md, hooks, MCP). You do not install a second harness.

## On a machine that already has the shared brain

This is Kamal's case, and anyone who already ran `install\install.ps1`:

```powershell
powershell -ExecutionPolicy Bypass -File install\install-grok.ps1
grok inspect
bash install/smoke-test-grok.sh
```

What that does:

1. Pins `[compat.claude]` on and `[memory] enabled = true` in `~/.grok/config.toml` (merge, no clobber).
2. Junctions `~/.grok/memory/from-claude` → `~/.claude/projects` so Grok can search **and write** Claude auto-memory.
3. Writes a pointer `~/.grok/memory/MEMORY.md`.
4. Registers `~/.grok/hooks/compact.json` pointing at the **shared** `~/.claude/hooks/post-compact-reminder.py`.
5. Registers `~/.grok/hooks/dcg.json` pointing at `~/.claude/hooks/dcg-grok-bridge.py` (dcg 0.11 does not parse Grok `toolInput`; see dcg#319).

What it does **not** do: copy skills, copy rules, write a second AGENTS.md, re-register MCP that Claude already has, reinstall scoop/WSL.

## On a blank machine

1. Run `install\install.ps1` first (shared brain + flywheel). Claude login is optional if you will only sit in Grok — the files still land in `~/.claude` because that is the shared store.
2. Install / sign in to Grok Build yourself.
3. Run `install\install-grok.ps1`.

## Daily use

- Sit in `grok`.
- Edit rules and skills under `~/.claude/`.
- Write memories to `~/.claude/projects/<encoded-cwd>/memory/` (see `~/.claude/rules/harness-shared.md`).
- Swarms: operator in Grok; ntm panes stay `--cc`, Grok-sub via `--cc=N:grok-4.6` once CLIProxyAPI is listening on `127.0.0.1:8317`.

## Optional MCP fallback

If `grok inspect` shows Claude MCP servers but they fail to connect, `install\mcp-register-grok.ps1` can add the same servers natively. Prefer fixing `compat.claude.mcps` first so you do not maintain two registrations.
