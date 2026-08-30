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
5. Registers `~/.grok/hooks/dcg.json` pointing at `~/.claude/hooks/dcg-grok-bridge.py` (belt-and-suspenders; dcg 0.11.1 parses Grok `toolInput` natively, dcg#319).
6. Ensures the pinned ergo `dev-browser` CLI is on PATH and runs `dev-browser install` for Chromium (x-harvest). Does **not** run `dev-browser install-skill`.
7. Copies `impeccable-hook.cmd` so Grok PostToolUse/Stop hooks do not run bash `[ ! -f ... ]` under PowerShell.
8. Deploys the OpenCode Zen (Muse Spark 1.2) stream filter proxy to `~/.grok/opencode-proxy.cjs`, registers its `SessionStart` hook, sets up silent Windows Startup persistence, and appends `[model.muse-spark-contributor]` to `~/.grok/config.toml`.

What it does **not** do: copy skills, copy rules, write a second AGENTS.md, re-register MCP that Claude already has, reinstall scoop/WSL.

## On a blank machine

1. Run `install\install.ps1` first (shared brain + flywheel). Claude login is optional if you will only sit in Grok — the files still land in `~/.claude` because that is the shared store.
2. Install / sign in to Grok Build yourself.
3. Run `install\install-grok.ps1`.

## Daily use

- Sit in `grok`.
- Edit rules and skills under `~/.claude/`.
- Write memories to `~/.claude/projects/<encoded-cwd>/memory/` (see `~/.claude/rules/harness-shared.md`).
- Swarms: `ntm spawn <project> --grok=N` (native). `--cc=N:grok-4.6` via CLIProxyAPI is fallback only. WSL needs `/usr/local/bin/grok` pointing at Windows `grok.exe`.

## Custom Models & Responses API Proxies (OpenCode Zen / Muse Spark 1.2)

Grok CLI supports custom models via `[model.<id>]` in `~/.grok/config.toml` with `api_backend = "responses"`. However, third-party providers using OpenAI Responses API format often have upstream quirks that break Grok's compiled Rust parser:

1. **Rust `serde` SSE Enum Deserialization (`unknown variant ping`):**
   OpenCode Zen sends non-standard `event: ping` keepalive/cost frames. Grok's parser strictly expects standard Responses events (`response.created`, `response.completed`, etc.) and panics.
2. **Cross-Turn Reasoning Rejection (`Invalid reasoning item id format`):**
   In multi-turn chats or across model switches, Grok replays previous `type: "reasoning"` items in `input`. Upstream providers reject mismatched reasoning IDs with HTTP 400.
3. **Session Rejection / 401 Loop:**
   If `api_key` is not explicitly declared on the model, Grok falls back to `~/.grok/auth.json` (the xAI JWT), causing continuous 401 OAuth refresh loops.

### The Fix: Local Filter Proxy
`install-grok.ps1` sets up a lightweight, zero-dependency Node proxy on `http://127.0.0.1:5210`:
- Discards non-standard `event: ping` frames before Grok parses them.
- Strips prior `reasoning` items from multi-turn `input` history.
- Injects `OPENCODE_API_KEY` if Grok attempts to send xAI bearer tokens.
- Runs automatically in the background via `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\opencode-proxy.vbs` and Grok `SessionStart` hook.

### Setup:
1. Set your OpenCode API key:
   ```powershell
   [System.Environment]::SetEnvironmentVariable('OPENCODE_API_KEY', 'sk-...', 'User')
   ```
2. In `~/.grok/config.toml`, ensure the model entry exists:
   ```toml
   [model.muse-spark-contributor]
   model = "muse-spark-1.2-contributor-free"
   base_url = "http://127.0.0.1:5210/v1"
   name = "Muse Spark 1.2 Contributor (OpenCode Zen)"
   api_backend = "responses"
   env_key = "OPENCODE_API_KEY"
   context_window = 1048576
   max_completion_tokens = 131072
   ```
   *(Tip: Adding `api_key = "sk-..."` directly under `[model.muse-spark-contributor]` gives it highest priority in Grok's credential resolution.)*
3. Use `/model` inside Grok or launch with `grok -m muse-spark-contributor`.

## Optional MCP fallback

If `grok inspect` shows Claude MCP servers but they fail to connect, `install\mcp-register-grok.ps1` can add the same servers natively. Prefer fixing `compat.claude.mcps` first so you do not maintain two registrations.
