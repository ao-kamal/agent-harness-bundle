# Harness flavors

This bundle is one working environment with more than one coding-agent front end. The flywheel (skills, rules, beads, ntm, cass, dcg, Agent Mail, WSL) is shared. The agent CLI you sit in is a flavor.

| Flavor | Installer | Setup | Deploys to |
|--------|-----------|-------|------------|
| **Claude Code** (original) | `install\install.ps1` | [SETUP.md](../SETUP.md) | `~/.claude` |
| **Grok** (this addition) | `install\install-grok.ps1` | [flavors/grok/SETUP.md](grok/SETUP.md) | `~/.grok` + `~/.agents` |

Pick the flavor that matches the CLI you actually run. You can install both on one machine; they share the flywheel tools and the skills payload, and keep their own hooks, MCP registrations, and login.

New flavors (Codex, Gemini, …) should land the same way: a `flavors/<name>/` setup page, an `install/install-<name>.ps1`, and a `config/<name>/` template tree. Do not replace an existing flavor to add a new one.
