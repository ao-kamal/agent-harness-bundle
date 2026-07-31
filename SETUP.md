# SETUP — step by step

This walks you from a fresh Windows machine to the full working harness. Budget 1–2 hours, mostly waiting on downloads. You can stop at any point and re-run the installer later — it remembers what's done and continues.

## Before you start

**Machine requirements** (the installer checks all of these and stops with a clear message if one fails):

- Windows 10 build 19041+ or Windows 11, on a normal Intel/AMD processor (ARM laptops — Snapdragon etc. — are NOT supported; the toolchain ships x86-only binaries)
- 15 GB free on C:
- Permission to install software (admin approval may pop up once for WSL)

**Accounts** — have these ready:

| Account | Needed when | Where |
|---------|-------------|-------|
| Anthropic (Claude Pro or Max) | Stage 3, required | claude.ai |
| GitHub | recommended (rate limits) | github.com |
| Kimi Code subscription | for the Kimi lane (you said you want it) | kimi.com — get the Code plan, then create an API key |
| firecrawl | optional (web scraping skill) | firecrawl.dev |
| context7 | optional (docs lookups, higher limits) | context7.com |
| apify | optional (scraper actors) | apify.com |

**One Windows setting**: if the installer says it can't create symlinks, turn on Developer Mode — Settings → System → For developers → Developer Mode → On. (Or run `start ms-settings:developers`.) Then re-run.

## Step 1 — Get the bundle

If Kamal gave you a GitHub link: install [Git for Windows](https://git-scm.com/download/win) first if you don't have it (default options are fine), then in PowerShell:

```powershell
cd $env:USERPROFILE\Documents
git clone <the-repo-url> claude-harness-bundle
cd claude-harness-bundle
```

## Step 2 — First launch

Windows blocks downloaded scripts by default. These two commands handle it — run them in PowerShell, inside the bundle folder:

```powershell
Get-ChildItem -Recurse | Unblock-File
powershell -ExecutionPolicy Bypass -File install\install.ps1
```

What `-ExecutionPolicy Bypass` does: Windows' default policy refuses to run unsigned local scripts; this flag allows it for this one process only. It changes nothing permanently.

## Step 3 — Follow the installer

The installer runs 11 stages and tells you what it's doing. What to expect:

- **Stage 0 (preflight)** checks your machine and sizes things (like WSL memory) to your hardware.
- **Stages 1–2** install package managers and the CLI tools. If Windows shows a blue **"Windows protected your PC"** box for any tool: click **More info → Run anyway** (these are unsigned open-source binaries; the installer verifies their checksums against the publisher's own hashes before running them).
- **Stage 3a is a manual moment**: the installer asks you to open a new terminal, run `claude`, and log in through the browser. Do that, exit Claude Code, come back, press Enter. **Stage 3b** then runs on its own (plugin installs and the impeccable skill family) — no action from you.
- **Stage 4** deploys the skills and configuration — automatic.
- **Stage 5 (WSL) is the long one.** Three ways it can go on a fresh machine: (a) Windows needs a reboot to enable WSL — reboot; the installer resumes by itself after you log back in; (b) **no reboot was needed** — the installer still stops on purpose after enabling WSL and tells you to re-run it; do that, it continues where it left off; (c) WSL already exists — it proceeds straight through. If Ubuntu asks you to create a Linux username on first launch, pick anything; the harness runs as root regardless. Near the end you'll see WSL restart once — that's deliberate (background services only start on a cold boot).
- **Stage 6** asks for your API keys one at a time. Skip anything you don't have — you can re-run `install\secrets-setup.ps1` any time. Keys are stored in private files (`.env.private`), never in shared config.
- **Stages 7–9** register the MCP servers, set up the background daemons, and install WezTerm — automatic.
- **Stage 10** offers the optional Obsidian vault starter (y/N prompt).
- **Stage 11** runs the smoke test. Green = done. Failures print what's wrong and this file's Troubleshooting section covers the common ones.

## Step 4 — After the install

1. **Open a new terminal** (PATH changed; old windows don't see the new tools).
2. Run `bash install/smoke-test.sh` any time you want to re-verify the whole stack — and always after you change infrastructure.
3. **Read the field guide**, in order, starting with `docs/field-guide/01-philosophy.md`. This is the actual point of the bundle. The tools are replaceable; the judgment isn't.
4. Start your first project by typing `/flywheel-planning` in Claude Code and following it.

## The Kimi lane

You're set up for two model providers: Anthropic (main) and Kimi (cheap workhorse / fallback when Claude rate-limits).

1. Get the Kimi Code subscription at kimi.com, create an API key.
2. Put the key — just the key, one line — in `C:\Users\<you>\.config\kimi\key` (Stage 6 offers to do this for you).
3. **Windows**: Windows Terminal now has a "Claude (Kimi)" profile — open a tab with it and run `claude` there; that whole tab talks to Kimi.
4. **Swarms**: Kimi panes spawn with `ntm spawn <proj> --cc=N:kimi-for-coding` — never a bare `--cc=N`. Details live in the ntm rules file (`~/.claude/rules/ntm-swarm.md`).
5. Know the difference: Kimi is a flat quota (requests per 5h/week), not per-token. When Kimi hits its weekly wall, no account trick revives it — wait it out or use Claude.

## Optional opt-in: skipping the danger prompt

Kamal's own setup sets `skipDangerousModePermissionPrompt` so `claude --dangerously-skip-permissions` starts without a confirmation. The bundle does NOT set this for you. It's a real guardrail: that flag lets the agent run commands without asking. If, after a few weeks, you understand the guard stack (dcg blocks destructive commands mechanically; slb adds peer review in swarms) and want the smoother start, add to `~\.claude\settings.json`:

```json
{ "skipDangerousModePermissionPrompt": true }
```

## n8n (only if you use it)

If you ever run workflow automation with n8n locally (Docker), register its MCP server with the command in `~/.claude/rules/mcp-and-services.md` — you'll mint the API key inside your n8n instance's settings first.

## Troubleshooting

**"Running scripts is disabled on this system"** — you skipped the `-ExecutionPolicy Bypass` flag. Use the exact Step 2 command.

**Blue "Windows protected your PC" box** — More info → Run anyway. If there's no "More info" link, the file wasn't unblocked: re-run the `Unblock-File` command from Step 2.

**"Cannot create symlinks"** — Developer Mode (see Before you start), then re-run.

**WSL install loops or errors** — run `wsl --status` in PowerShell. If WSL is genuinely stuck, `wsl --update` then re-run the installer. If Ubuntu exists but the stage fails, the WSL stage is separately re-runnable: it resumes from its own checkpoint.

**"Agent Mail not reachable"** — three rules: it's always `127.0.0.1:8765`, never `localhost` (Windows resolves `localhost` to IPv6 first and the probe hangs — this one trap cost weeks of confusion, it's in the field guide); the server only starts on a WSL cold boot (`wsl --shutdown` in PowerShell, then open any WSL terminal, wait ~15s); check the boot log in WSL: `tail /root/.local/share/mount-fast-data.log`.

**GitHub rate-limit errors during installs** — run `gh auth login` (browser flow), then re-run the installer.

**A scoop tool fails hash verification repeatedly** — it may be a stale manifest, not a bad download. `docs/methodology/tooling-update-runbook-generic.md` gotcha list covers the diagnosis.

**A WSL tool failed to install** — re-run the installer; the WSL stage retries only what failed. `caam` specifically skips itself until `cosign` exists (its instructions print when that happens).

**Smoke test failures** — each failing phase prints what it checked. Phases marked SKIP for optional tools are fine. Anything else: fix per the message and re-run `bash install/smoke-test.sh`.

## Getting updates

Kamal improves this bundle over time. To update: `git pull`, then `powershell -ExecutionPolicy Bypass -File install\install.ps1 -Update` — the `-Update` flag re-copies skills and re-renders config on both sides while leaving completed installs alone. Full story: `docs/maintenance.md`.
