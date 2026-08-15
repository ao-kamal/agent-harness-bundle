# 08 — Antigravity flavor (Gemini-line)

The first five chapters are flavor-blind. This chapter is the Antigravity-specific map.

Read 01–05 first.

## Gemini CLI is not the swarm CLI anymore

On 18 June 2026, consumer Gemini CLI (free / Google AI Pro / Ultra) stopped serving. Google replaced the terminal product with **Antigravity CLI** (`agy`). That CLI is a TUI, not only the Antigravity 2.0 IDE. Official docs say it is built for SSH, tmux, and headless print mode.

Enterprise Gemini CLI can still exist via paid/API keys. This flavor does not target that leftover. ntm `--gmi` is the legacy Gemini flag. The swarm flag is `--agy`.

This is Google's product, not Anthropic's.

## What changes, what does not

Does **not** change: planning loop, skills payload, flywheel, WSL hybrid.

Does change:

- You run `agy`
- Skills: `~/.gemini/antigravity-cli/skills/`
- Plugin + hooks: `~/.gemini/antigravity-cli/plugins/harness-bundle/`
- Settings: `~/.gemini/antigravity-cli/settings.json`
- MCP: `~/.gemini/config/mcp_config.json` (`serverUrl` for remote servers)

## ntm

Jeffrey's ntm already has Antigravity. Spawn with `--agy`. This flavor does not add a second Gemini-line type.

```bash
ntm spawn myproject --agy=2
```

Unattended: `agy --dangerously-skip-permissions`. Headless one-shot: `agy -p "..."`.

`--grok` is phase one. `--cod` is Codex. `--cc` is Claude.

## Auth

First `agy` uses the OS keyring and a browser. Over SSH it prints a URL + code. Optional headless: set `modelProvider` to `gemini` in settings **and** export `GEMINI_API_KEY`. The key alone does nothing.

## Commands you will type instead

| Gemini CLI (dead for consumers) | Antigravity |
|---------------------------------|-------------|
| `gemini` | `agy` |
| `~/.gemini/settings.json` | `~/.gemini/antigravity-cli/settings.json` |
| ntm `--gmi` | ntm `--agy` |
| extensions | `agy plugin` |
