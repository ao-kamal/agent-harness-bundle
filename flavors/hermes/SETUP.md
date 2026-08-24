# Hermes Agent — thin adapter

Hermes (Nous Research) is the fourth front end. Like Antigravity, it cannot natively read `~/.claude` — but unlike the others it has a **native external-skills-dir mechanism**, so the adapter is config-only for skills: no junctions, no copies.

## What this installer does

```powershell
powershell -ExecutionPolicy Bypass -File install\install-hermes.ps1
```

1. Requires `~/.claude/skills` (run `install\install.ps1` first) and the `hermes` CLI.
2. Merges into `<HERMES_HOME>/config.yaml` (backup first, idempotent, never clobbers your keys):
   - `skills.external_dirs: [C:/Users/<you>/.claude/skills]` — the whole shared brain appears in Hermes read-only. New or edited skills show up next session with zero sync.
   - `skills.creation_nudge_interval: 0` + `curator.enabled: false` — the brain is curated by the bundle; don't let Hermes auto-mint parallel copies.
   - `agent.clarify_timeout: 0` — interactive prompts never time out.
3. Appends a marker-delimited **Operating Rules** block to `SOUL.md` (see the quirk below).
4. Registers `mcp-agent-mail` from the WSL stage's token file (`~\.config\mcp-agent-mail\config.env`) at `http://127.0.0.1:8765/mcp/` — always `127.0.0.1`, never `localhost` (same IPv6 blackhole as every other probe in this bundle).
5. Optional `-PruneBundledSkills`: permanently deletes Hermes' bundled builtin skills (`hermes skills opt-out --remove --yes`). Kamal-preference — off by default.

It does **not** copy skills, write a second rules tree, or touch Hermes' hooks/approval system.

## The SOUL.md quirk

Hermes has two global context slots and they are not equal:

- `SOUL.md` = agent **identity** (always loaded, slot #1)
- `AGENTS.md` = project/policy instructions (**working-directory discovery only** — there is no global AGENTS.md yet)

Global-AGENTS.md loading is upstream **PR NousResearch/hermes-agent#23331** (reviewed, production-tested, open as of 2026-08). Until it merges and you update, SOUL.md is the only always-loaded global slot — so the adapter puts a condensed rules block there, marker-delimited, with the migration note inside. When #23331 lands:

1. `git pull` + re-run installers
2. Move the Operating Rules block from `SOUL.md` to `$HERMES_HOME/AGENTS.md`
3. Trim `SOUL.md` back to identity only

The block carries this note itself, so you won't have to remember.

## Daily use

- Sit in `hermes` (or the desktop app / TUI / any messaging platform — same core everywhere).
- Edit rules and skills under `~/.claude/` only. Hermes sees changes on its next session start (external dirs are read per-scan, but running sessions hold a frozen prompt).
- Swarms stay on ntm (`--grok`/`--agy`); Hermes is a single-session front end, not an ntm pane type.
- Verify with `bash install/smoke-test-hermes.sh` after any infrastructure change.

## If config merge reports odd results

The merge script edits `config.yaml` textually (targeted section patch — no full-file YAML rewrite, so `hermes config set` output formatting survives). It backs up to `config.yaml.bak-harness-bundle` before touching anything; restore that if anything looks wrong, then file the diff as a bug.
