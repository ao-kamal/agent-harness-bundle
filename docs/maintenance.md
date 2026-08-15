# Maintenance

This bundle isn't a one-time install. Three separate things get updated over its life, on three separate schedules: the bundle itself, the CLI tools it wraps, and (optionally) the skills library. This page covers all three, plus how to back out if you ever need to.

| What | How | How often |
|---|---|---|
| The bundle (config, field guide, installer) | `git pull` + re-run `install.ps1` (and `install-grok.ps1` if you sit in Grok) | Whenever Kamal pushes something and you feel like catching up |
| The CLI tools (cass, ntm, br, bv, caam, dcg, ...) | `docs/methodology/tooling-update-runbook-generic.md` | Every few weeks, or when something feels stale |
| Skills library | Default: bundle re-copy (above). Optional: `jsm` with a paid subscription | Same as the bundle, unless you subscribe |

## Getting updates to the bundle

Kamal keeps improving this repo after you've installed it — new lessons learned, fixed gotchas, better defaults. You don't need to redo the install to pick those up:

```powershell
cd agent-harness-bundle
git pull
powershell -ExecutionPolicy Bypass -File install\install.ps1 -Update
powershell -ExecutionPolicy Bypass -File install\install-grok.ps1 -Update
```

The `-Update` flag is what makes updates land: `install.ps1 -Update` re-copies the skills payload and re-renders the **shared** `~/.claude` templates. `install-grok.ps1 -Update` only refreshes the thin Grok adapter (memory junction, compat pin, compact hook). State files: `%USERPROFILE%\.harness-bundle-state.json` and `%USERPROFILE%\.harness-bundle-grok-state.json`. A plain re-run without `-Update` only resumes unfinished stages — it will NOT refresh already-deployed config. You will not lose your API keys, your `.env.private` secrets, or anything you've customized in your own project folders either way.

## Re-run the smoke test after ANY infrastructure change

This is the one habit worth making automatic, not just after installing: **run `bash install/smoke-test.sh` again any time you change anything about the underlying setup** — not only right after the installer finishes. That includes: updating WSL itself, changing `.wslconfig`, reinstalling a tool outside the bundle's own update path, changing networking mode, moving the bundle folder, or anything touching scheduled tasks or the WSL boot hook.

The reasoning is the same one behind most of chapter 03 in the field guide: this stack has several places where something can look fine on the surface while actually being broken underneath (a stale scheduled task, a boot hook that silently didn't fire, a symlink pointing at something that moved). The smoke test exists specifically to catch that class of problem before you find out the hard way, mid-task. Treat "did I run the smoke test after that change" as a real question, not a formality — a clean run is the only actual evidence that an infrastructure change didn't break something else.

## Updating the underlying tools

The CLI tools this bundle installs (cass, cm, br, bv, caam, dcg, ubs, ntm, Agent Mail, and the smaller npm-installed ones) have their own release cadence, independent of this bundle's own updates. Follow `docs/methodology/tooling-update-runbook-generic.md` for the update routine, the tool-to-repo map, and the gotcha list — it's written from real update runs across this exact Windows + WSL combination, and most of the entries in it are traps that cost real time the first time they were hit. Don't skip the audit-first step it describes; it's what tells you whether anything actually needs updating before you touch anything.

`dev-browser` is the exception: do not treat it as an npm `@latest` package. This repo vendors `0.2.8-ergo` under `payload/bin/`. `npm install -g dev-browser@latest` is how stock SawyerHood 0.2.9 replaced that binary on 2026-07-31. After any update, `dev-browser --version` must contain `ergo`.

## Updating skills

Most of the skills this bundle installs are file copies — plain markdown living under `~/.claude/skills/` only. Grok reads that directory. The default way they update is `git pull` plus `install.ps1 -Update`, which re-copies the skills payload from this repo into that one place.

There's a second, optional path: a subscription to Jeffrey's Skills.md (the marketplace these skills originate from) lets the `jsm` CLI sync new and updated skills directly from that marketplace, independent of this bundle's own release schedule. This bundle does **not** assume you have that subscription, and doesn't require it — without it, skills update purely through this repo, on whatever cadence Kamal pushes updates. If you decide later that you want faster, direct-from-source skill updates, `jsm sync --status` (no subscription needed just to check) shows you what's available, and `jsm sync --force` pulls it if you do subscribe. Treat this as a nice-to-have upgrade path, not something you're missing out on by skipping it.

## Uninstalling

`install\uninstall.ps1` is a best-effort rollback: it stops the bundle's scheduled tasks, removes MCP registrations it added, and restores config files it modified from the backups it made along the way. Every file the installer touched was backed up first with a `.bak-harness-bundle` suffix next to the original — the uninstaller restores from those, and deliberately leaves the backup files in place afterward rather than deleting them, in case you need to recover something the automated restore missed. Nothing about this is destructive by default: worst case, you end up with a few harmless `.bak-harness-bundle` files sitting next to your normal config.

It's called "best-effort" deliberately: some things this bundle sets up (WSL itself, packages installed via scoop or npm that other tools may also depend on) aren't things the uninstaller will touch, because removing them could affect software this bundle didn't install. Read what it prints as it runs — it tells you plainly what it did and didn't undo.
