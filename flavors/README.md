# Harness flavors

This bundle is one working environment with more than one coding-agent front end. The flywheel (skills, rules, beads, ntm, cass, dcg, Agent Mail, WSL) is shared. The agent CLI you sit in is a flavor.

| Flavor | Installer | Setup | Deploys to |
|--------|-----------|-------|------------|
| **Claude Code** (original) | `install\install.ps1` | [SETUP.md](../SETUP.md) | `~/.claude` |
| **Grok** | `install\install-grok.ps1` | [flavors/grok/SETUP.md](grok/SETUP.md) | `~/.grok` + `~/.agents` |
| **Codex** | `install\install-codex.ps1` | [flavors/codex/SETUP.md](codex/SETUP.md) | `~/.codex` + `~/.agents` |
| **Antigravity** (Gemini-line) | `install\install-antigravity.ps1` | [flavors/antigravity/SETUP.md](antigravity/SETUP.md) | `~/.gemini/antigravity-cli` + `~/.gemini/config` |

Pick the flavor that matches the CLI you actually run. You can install more than one; they share flywheel tools and the skills payload, and keep their own login, hooks, and MCP.

Do not replace an existing flavor to add a new one.

## ntm workers (already in Jeffrey's ntm)

This bundle does **not** invent ntm agent types. Official ntm already launches these CLIs:

| Flag | CLI | Notes |
|------|-----|--------|
| `--cc` | Claude Code | Full send / interrupt / assign |
| `--cod` | Codex CLI | Full send / interrupt / assign |
| `--agy` | Antigravity CLI | Gemini-line replacement. Use this, not Gemini CLI |
| `--grok` | Grok Build | Phase one: launch and discovery. Automated send/assign/interrupt/restart are not claimed yet |
| `--gmi` | Gemini CLI | Legacy. Consumer Gemini CLI stopped serving on 2026-06-18 |
| `--cc=N:kimi-for-coding` | Claude binary + Kimi API | Existing cc-router. Not a new ntm type |

Example mixed swarm:

```bash
ntm spawn myproject --cod=2 --agy=1 --grok=1
```
