# Front ends, not flavors

This bundle is one working environment. The flywheel and the brain (`~/.claude`) are shared. The agent CLI you sit in is a front end that **reads** that tree. It is not a second copy of the tree.

| Front end | How it sees the brain | Extra install |
|-----------|----------------------|---------------|
| **Claude Code** | Native. `install\install.ps1` deploys here. | None |
| **Grok Build** | Built-in `compat.claude` (skills, rules, hooks, MCP, CLAUDE.md). | Thin adapter: `install\install-grok.ps1` |

You can run both on one machine. You edit rules and skills in `~/.claude/` once.

Do **not** add a new front end by copying `config/` into `~/.codex` / `~/.gemini` / `~/.agents`. If a CLI cannot read `~/.claude`, add the smallest adapter that makes it do so (a junction, a compat flag, a single hook JSON). If it still cannot, that is a real gap — document it; do not fork the brain.

ntm worker panes are still Claude Code (`--cc`), including Grok-sub and Kimi via `cc-router`. See `config/rules/ntm-swarm.md` and `config/rules/harness-shared.md`.
