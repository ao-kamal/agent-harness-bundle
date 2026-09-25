# Shared harness contract

One brain. Any front end. Edit here, not in a per-CLI copy.

## Canonical locations

| Thing | Where | Who reads it |
|---|---|---|
| Global rules | `~/.claude/CLAUDE.md` | Claude Code, Grok Build (`compat.claude`) |
| Topic rules | `~/.claude/rules/*.md` | both |
| Skills | `~/.claude/skills/` | both |
| Hooks (dcg, shared PCR) | `~/.claude/settings.json` + `~/.claude/hooks/` | Claude uses settings.json dcg; Grok uses `~/.grok/hooks/dcg.json` -> `dcg-grok-bridge.py` (dcg#319) plus compact.json |
| Auto-memory | `~/.claude/projects/<encoded-cwd>/memory/` | both (Grok via junction + this rule) |
| Procedural / session memory | `cm` / `cass` | any harness (CLI) |
| Grok-only knobs | `~/.grok/config.toml` | Grok Build only |
| Antigravity-only knobs | `~/.gemini/antigravity-cli/settings.json` | `agy` only. Skills/rules are junctions, not copies |
| OpenCode-only knobs | `~/.config/opencode/opencode.jsonc` | OpenCode CLI. Skills/rules stay in `~/.claude` (official Claude Code fallback). Do not write `~/.config/opencode/AGENTS.md` or it replaces `CLAUDE.md`. |

Do **not** copy rules, skills, or CLAUDE.md into `~/.grok/`, `~/.agents/`, `~/.gemini/`, or `~/.config/opencode/skills`. Grok already scans `~/.claude/`. OpenCode already scans `~/.claude/skills` and `~/.claude/CLAUDE.md`. Antigravity gets junctions, not copies. A second tree means every edit has to be made twice.

Grok-native leftovers that stay Grok-only: `~/.grok/config.toml`, pager, auth, bundled skills. Claude-native leftovers that stay Claude-only: plugin marketplaces, TUI settings.

## Memory — Claude store is writable from every harness

Durable memories live in Claude Code's per-project store:

```
~/.claude/projects/<encoded-cwd>/memory/
  MEMORY.md                 <- index; rewrite lines, do not only append
  user_<topic>.md
  project_<topic>.md
  reference_<topic>.md
  feedback_<topic>.md
```

**Encoding:** take the absolute working directory, replace `\`, `/`, and `:` with `-`.
Example: `C:\Users\USER\Documents\ObsidianVault` → `C--Users-USER-Documents-ObsidianVault`.
A WSL twin may exist as `-mnt-c-Users-USER-Documents-ObsidianVault`. If both exist, use the one that already has a populated `MEMORY.md`. If none exists, create the Windows-encoded folder.

Grok indexes the same files through `~/.grok/memory/from-claude` (a junction onto `~/.claude/projects`). Writes must go to the Claude path (or through that junction — same bytes). Do not keep long-term facts only in `~/.grok/memory/MEMORY.md`.

When saving a memory:

1. Pick exactly one type: `user` / `project` / `reference` / `feedback`.
2. Reuse `{type}_{topic_slug}.md` if it exists. Update in place.
3. Keep `MEMORY.md` one-liners current.
4. `feedback` shape: what went wrong → why → how to apply next time.
5. Cross-link with `[[name-field]]` against the memory `name`, not the filename.

`cm context` / `cass search` stay the procedural and session-history layer. They do not replace these files.

## Daily driver vs swarms

- **Daily work:** Grok Build (`grok`), or OpenCode CLI (`opencode`) when you want native Zen/free Muse Spark.
- **Swarms:** ntm 1.29+ can `spawn --grok=N` and `--agy=N:<model-id>` with send/interrupt. Grok and Antigravity use their own CLIs and subscriptions. Do not put Antigravity behind CLIProxy. See `ntm-swarm.md`.

## Inspect

- Grok: `grok inspect` — confirm it lists `~/.claude/rules` and `~/.claude/skills`.
- If a Grok session is missing those, `compat.claude` was turned off. Turn it back on in `~/.grok/config.toml`.
