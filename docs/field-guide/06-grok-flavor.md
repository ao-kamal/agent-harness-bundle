# 06 — Grok flavor

The first five chapters are flavor-blind. This chapter is the Grok-specific map: where files live, what Grok already does for you, and what is still Claude-shaped in the shared flywheel.

Read 01–05 first.

## What changes, what does not

Does **not** change:

- The planning loop (intent → plan → beads → execute → harden)
- Skills payload (~110 skills)
- Windows + WSL hybrid, 127.0.0.1, hot/cold disk rule
- dcg / slb / cass / cm / br / bv / ntm / Agent Mail

Does change:

- You run `grok`, not `claude`
- Config lives in `~/.grok` (and `~/.agents`), not `~/.claude`
- Hooks use Grok's JSON envelope (`toolInput`, camelCase) and Grok event names (`PreCompact` / `PostCompact`)
- MCP is registered with `grok mcp add`, written into `~/.grok/config.toml`
- Custom agents are markdown in `~/.grok/agents/`
- Kimi is a `[model.kimi-for-coding]` entry, not `ANTHROPIC_BASE_URL` in a Windows Terminal tab

## Where Grok looks

Grok already scans Claude and `.agents` paths. The Grok flavor still deploys to native Grok locations so the machine works if Claude compatibility is later turned off.

| Thing | Grok-native path | Also loaded |
|-------|------------------|-------------|
| Skills | `~/.grok/skills/` | `~/.agents/skills/`, `~/.claude/skills/` |
| Rules | `~/.grok/rules/` | `~/.agents/rules/`, `AGENTS.md` |
| Hooks | `~/.grok/hooks/*.json` | Claude `settings.json` if compat is on |
| Agents | `~/.grok/agents/` | project `.grok/agents/` |
| MCP | `~/.grok/config.toml` `[mcp_servers.*]` | — |
| Memory / sessions | `~/.grok/sessions/` | — |

Home instruction file is `AGENTS.md` (Grok's default). `CLAUDE.md` is still recognized if present.

## Hooks that must be native

Grok aliases Claude tool names in hook matchers (`Bash` → `run_terminal_command`). That is not enough for the two reminder/guard scripts:

- **dcg** — same binary, `PreToolUse` matcher `Bash|PowerShell|run_terminal_command`
- **trauma_guard.py** — must read `toolInput.command` (Grok) as well as `tool_input.command` (Claude)
- **post-compact-reminder.py** — Claude injects SessionStart/compact stdout. Grok compaction is `PreCompact` / `PostCompact`. The Grok script emits `additionalContext` on those events and still prints the old Claude stdout form if `source=compact`

`UserPromptSubmit` cannot block on Grok (observe-only). Do not port a Claude prompt-validation hook and expect it to gate.

## Kimi

Claude flavor: a Terminal profile exports Anthropic-compatible env vars and you run `claude` in that tab.

Grok flavor: `/model kimi-for-coding`. The model block talks to `https://api.kimi.com/coding` with `api_backend = "messages"`. Key file is still `~/.config/kimi/key`.

## Flywheel on the Grok flavor

The Grok installer installs the same flywheel binaries as the Claude flavor. It does **not** send you to `install.ps1`. Differences from the Claude installer, all learned on the first Grok deploy:

- Scoop `main` must be a git repo. A zip fallback leaves `fatal: not a git repository`. Fix: `gh repo clone ScoopInstaller/Main ~/scoop/buckets/main -- --depth 1`.
- The dicklesworthstone bucket lists 0 manifests unless `*.json` is copied into `bucket/`.
- `scoop install dicklesworthstone/cm` fails a hash check (published exe moved). Grok flavor downloads `cass-memory-windows-x64.exe` with `gh release download`.
- `br` must be `br-*-windows_amd64.exe`. A loose `*windows*` match can install a file named `.exe` that is not a PE; the installer refuses it.
- Hook JSON must be UTF-8 **without BOM** or Grok reports `Hooks (0)`.
- The dcg hook path is `~/.local/bin/dcg.exe`. After scoop install, the installer copies `scoop\apps\dcg\current\dcg.exe` there.

## Honest limit: ntm has no Grok pane type

As of this flavor, `ntm spawn` understands `--cc`, `--cod`, `--gmi`, and Kimi-as-cc-variant. There is no `--grok=N`. The operator sits in Grok; worker panes stay Claude/Codex/Gemini/Kimi until ntm grows a Grok agent. Project `AGENTS.md` is the shared contract across those pane types.

## Commands you will type instead

| Claude | Grok |
|--------|------|
| `claude` | `grok` |
| `claude mcp add …` | `grok mcp add …` |
| `claude mcp list` | `grok mcp list` |
| `claude plugin …` | `grok plugin …` |
| (no equivalent) | `grok inspect` |
| `/model` inside Claude | `/model` or `Ctrl+M` inside Grok |

## Trust

Project hooks and project MCP need folder trust: `/hooks-trust` or `grok --trust`. Global `~/.grok/hooks/` is always trusted.
