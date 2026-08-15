# Front ends, not flavors

This bundle is one working environment. The flywheel and the brain (`~/.claude`) are shared. The agent CLI you sit in is a front end that **reads** that tree. It is not a second copy of the tree.

| Front end | How it sees the brain | Extra install |
|-----------|----------------------|---------------|
| **Claude Code** | Native. `install\install.ps1` deploys here. | None |
| **Grok Build** | Built-in `compat.claude` (skills, rules, hooks, MCP, CLAUDE.md). | Thin adapter: `install\install-grok.ps1` |
| **Antigravity CLI** (`agy`) | No compat flag. Junctions `~/.gemini/antigravity-cli/{skills,rules}` onto `~/.claude`. | Thin adapter: `install\install-antigravity.ps1` |

You can run all three on one machine. You edit rules and skills in `~/.claude/` once.

Do **not** add a new front end by copying `config/` into `~/.codex` / `~/.gemini` / `~/.agents`. If a CLI cannot read `~/.claude`, add the smallest adapter that makes it do so (a junction, a compat flag, a single hook JSON). If it still cannot, that is a real gap — document it; do not fork the brain.

ntm: `--agy` is first-class. `--grok=N` is phase-1 spawn only (send is fail-closed, ntm#251). Until then, automated Grok dispatch stays `--cc=N:grok-4.6`. See `config/rules/ntm-swarm.md` and `config/rules/harness-shared.md`.
