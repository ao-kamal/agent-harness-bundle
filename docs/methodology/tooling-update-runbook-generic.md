---
created: 2026-06-03
categories: [tooling, workflows, claude-code, infrastructure]
type: reference
---

# Tooling Update Runbook

How to update the CLI toolchain this bundle installs (NOT skills — `jsm`/`ms` skills have their own update path; see `docs/maintenance.md`). Distilled from repeated update runs across a Windows + WSL hybrid setup — mostly ordinary maintenance, with a handful of gotchas that cost real time the first time each one was hit.

## The routine (phases in order)

| # | Phase | Method |
|---|-------|--------|
| 1 | **Audit first** (read-only) | Version-check every tool on both sides plus connectivity probes. Never skip — network conditions (VPN, throttling) decide how the rest of the run goes. |
| 2 | **WSL flywheel CLIs** | Per-tool `install.sh` (download-then-execute, see gotchas): cass, cm, br, bv, caam, dcg, ubs, ntm |
| 3 | **jsm CLI binary** | `jsm update` (binary only, not skills) |
| 4 | **WSL apt** | `apt-get update && apt-get upgrade -y` with `-o Acquire::Retries=5` |
| 5 | **Windows Scoop** | `scoop update <named tools>` — bv, cm, caam, and whichever others you installed via scoop (cass's scoop manifest is typically stale — use its own `install.ps1` instead) |
| 6 | **Windows cass** | Stop the `Cass Watch Daemon` task + kill `cass.exe` → `install.ps1 -EasyMode -Verify` → restart the task |
| 7 | **Windows `.local\bin`** | Release zips via BITS + GitHub `.sha256` verify: br, dcg; cm copied from the scoop install |
| 8 | **Agent Mail** | Release zip/tar via BITS + sha256 verify. Windows: swap the exes. WSL: swap the binaries, restart the server process |
| 9 | **npm globals (targeted)** | Per-package `npm install -g <pkg>@latest` — ctx7, firecrawl-cli, defuddle, dev-browser, `@playwright/mcp`, `@apify/actors-mcp-server` |
| 10 | **Smoke test** | `bash install/smoke-test.sh` (this bundle's own validator) |

## Tool → repo → update mechanism map

| Tool | Repo (Dicklesworthstone/...) | Windows | WSL |
|------|------------------------------|---------|-----|
| cass | coding_agent_session_search | install.ps1 (stop daemon first) | install.sh |
| cm | cass_memory_system | scoop (active) + copy to `.local/bin` shadow | install.sh |
| br | beads_rust | release zip → `.local/bin` | install.sh |
| bv | beads_viewer | scoop | install.sh |
| caam | coding_agent_account_manager | scoop | install.sh (**needs cosign** — see gotchas) |
| dcg | destructive_command_guard | release zip → `.local/bin` | install.sh |
| ubs | ultimate_bug_scanner | (not installed on Windows) | install.sh |
| ntm | ntm | (WSL-only) | install.sh → installs to `/usr/local/bin/ntm` |
| am / mcp-agent-mail | mcp_agent_mail_rust | release zip → `.local/bin` (2 exes) | release tar.gz → `/root/.local/bin` (2 bins); `am update` exists but can hang on a slow connection — see gotcha 11 |
| jsm | (jeffreys-skills.md) | — | `jsm update` |
| ms | (scoop dicklesworthstone bucket) | scoop | — |
| ctx7, firecrawl-cli, defuddle, dev-browser, `@playwright/mcp`, `@apify/actors-mcp-server` | — | npm -g | — |

## Gotchas (each one cost real time — do not rediscover)

1. **VPN chokes sustained transfers, passes small probes.** Single-request connectivity probes succeed while 50MB+ downloads die (npm ECONNRESET, curl stalls at 0 bytes, scoop hash mismatch from a corrupted download). Fixes that have worked:
   - npm: `npm config set fetch-retries 6 fetch-retry-maxtimeout 120000 fetch-timeout 300000` + **per-package** installs (one failure doesn't kill the batch)
   - Big binaries: **BITS** (`Start-BitsTransfer -RetryInterval 60 -RetryTimeout 600`), always verify against GitHub's published `.sha256`
   - WSL needs a Linux binary but WSL curl stalls: BITS-download it on Windows, hand it to WSL via `/mnt/c`
2. **Scoop hash mismatch ≠ stale manifest.** The manifest hash can be correct while the *download* was corrupt. Fix: `scoop cache rm <app>` → retry `scoop update <app>`. Only conclude stale-manifest after GitHub's own `.sha256` disagrees with the manifest.
3. **Scoop aborts the whole batch on one failure.** `scoop update a b c` stops at the first hash failure. Update named tools individually if one is flaky.
4. **`curl ... | bash` with `</dev/null` breaks the pipe** (curl exit 23). Use download-to-a-tempfile-then-`bash file` for install.sh loops.
5. **ntm's safety `rm` wrapper can block installer temp cleanup.** `/root/.ntm/bin/rm` (PATH-first) routes through `ntm safety check`; an overly broad `rm -rf <anything>` approval rule kills installers (`jsm update` fails, install.sh cleanup denied). Fix with an explicit allow rule in `/root/.ntm/policy.yaml` (precedence: allowed > blocked > approval) scoped to temp subpaths only (e.g. `rm\s+-rf\s+/(tmp|var/tmp)/\S`) — never widen it to `/ ~ * .`. If installs start failing with "NTM Safety: Command requires approval," check this rule survived.
6. **dcg's Windows hook fires on command *text*.** A Bash command merely *containing* a literal `rm -rf /tmp/...` string (e.g. as a test argument) gets blocked. Avoid literal rm-rf strings in command text; use Python or indirection instead.
7. **caam's install.sh requires cosign** for release verification; without it, it falls back to an unversioned source build. Install cosign in WSL via `go install github.com/sigstore/cosign/v2/cmd/cosign@latest` (binary lands at `/root/go/bin/cosign`, roughly 10 minutes to build). Don't use a skip-verification env var as a substitute — that defeats the point of the check.
8. **ntm and caam live in `/usr/local/bin`** (not `/root/.local/bin`) in WSL — run `which` before assuming. `ntm version` is a subcommand; caam's release builds answer `caam --version` but older dev builds didn't.
9. **cass major jumps trigger an index rebuild** on daemon restart — `cass health` reports "rebuild in progress" for a while. Normal; don't panic, don't reindex manually.
10. **After bulk updates, re-verify versions.** Install scripts can silently fail (exit code 0 with the old binary still active, PATH shadowing a stale copy). The audit loop at phase 1 doubles as the post-verify loop — run it again after the batch.
11. **`am update` (self-update) can hang indefinitely on a bad connection** — elapsed time in the hours, zero CPU, zero bytes moving. Verify with a process-time check (`ps -o pid,etime,time` — zero TIME means hung, not slow) before killing anything. A manual binary swap from a downloaded release is the reliable fallback path.
12. **NEVER force-kill the Agent Mail process.** A hard kill mid-write has corrupted its SQLite write-ahead log before, requiring a backup restore plus manual row surgery to recover. With the server *down*, binary swaps are safe; with it running, stop it gracefully (SIGTERM) first, never `-9` / `Stop-Process -Force`.
13. **cass's WSL `install.sh` (plain, no flags) can try to build from source against a broken hardcoded path** and fail outright. Pass `--easy-mode --verify` to force the prebuilt-binary path instead (fetches the platform tarball + its sha256). Windows uses the equivalent `install.ps1 -EasyMode -Verify` (already prebuilt by default).
14. **dcg can block scripted commands on command *text*, not resolved intent.** Concretely: `rm -rf "$tmp"` on a `mktemp`-created directory can get blocked because dcg can't resolve the variable's actual value — drop the manual cleanup (the OS reclaims `/tmp` anyway) or use a non-`rm -rf` delete. A redirect like `nohup ... > ~/.config/.../serve.log` can get blocked as a truncating-redirect pattern — use `>>` instead. A path-like regex passed to `Remove-Item` can trip a protected-path rule — use a glob (`-like '*.sha256'`) instead of a regex. Per this bundle's rules, invoke the `/dcg` skill on the first block, then use the safe alternative silently.
15. **Agent Mail's release assets are often `.tar.xz`**, not `.tar.gz` — check the actual extension before assuming your unpack command is right. The Linux tarball typically contains both binaries the tool ships; extract with an autodetecting `tar -xf` and install both. After restarting the server, its health endpoint can take 10-15 seconds to report ready (internal startup checks) — don't judge a probe taken a few seconds in as a failure.
16. **Don't background a full `apt upgrade` during heavy concurrent I/O.** Running it backgrounded while several other downloads hammered the disk has caused transient WSL virtual-disk I/O errors mid-unpack, leaving `apt` half-configured (not disk corruption — the filesystem itself stayed healthy). Recovery: `dpkg --configure -a` → `apt-get -f install -y` → retry the upgrade. Run `apt` serially, not backgrounded alongside other big transfers.
17. **A Windows scheduled task that should always be enabled can be found disabled** after an update (this bundle's cass-watch task is the concrete example). If `Start-ScheduledTask` errors with "the task is disabled," run `Enable-ScheduledTask '<task name>'` first, then start it. Fallback launch: the task's own hidden-window VBS launcher (e.g. `C:\Users\<you>\.local\bin\cass-watch-hidden.vbs`).
18. **A scoop-packaged tool's `--version` output can be cosmetically broken** in a specific release (an unexpanded template string printed literally instead of the real version) while the binary itself works fine. Don't mistake a cosmetic version-string bug for a broken install — check the tool actually functions before troubleshooting further.
19. **A Go-installed tool's bin directory (e.g. `/root/go/bin` for cosign) not being on WSL's PATH** can silently degrade a *different* tool's verification step — one tool hard-fails when it can't find the binary it depends on, another silently downgrades to a weaker checksum-only check instead of erroring. If a "verification tool required" error resurfaces after previously being fixed, check whether that PATH entry survived (a shell config edit that isn't sourced by every shell type is a common way to lose it again).
20. **A tool's own WSL `install.sh` can have broken prebuilt-binary detection** — claiming "no prebuilt binary available" for a platform it actually ships one for, then falling back to downloading and building an entire toolchain from source (which can blow well past a reasonable time budget for what should be a binary download). Until the upstream script is fixed: download the platform tarball manually, verify its checksum file, and install it yourself.
21. **An installer script can request the wrong file extension for your platform** (asking for `.tar.gz` when the actual published Windows asset is `.zip`, for instance) and 404 every time. On the platform it gets wrong, skip the script: download the correct asset directly, verify it against the published checksums file, and swap it into place by hand.
22. **A scoop hash mismatch can be a genuinely wrong manifest, not a corrupt download.** If clearing the cache and retrying reproduces the identical "wrong" hash every time, compare GitHub's own published `<asset>.sha256` against the manifest's `hash` field directly — if the manifest itself disagrees with GitHub, hand-correct the local manifest file and retry. Note that a subsequent bucket update can silently revert your local fix; re-apply if the mismatch recurs, and consider filing the discrepancy upstream.
23. **A Windows PreToolUse safety hook can intermittently exceed its own evaluation time budget** independent of what the command actually contains — this has shown up on both multi-line PowerShell blocks and bare single-line executable invocations, plausibly from antivirus scanning a freshly-written binary inside the hook's execution window. Confirm it's a timeout artifact (not a real rule match) by testing the exact command directly against the tool's own test/explain command and confirming it evaluates as allowed. Remedy: split multi-line PowerShell into single-purpose calls, or run the command through a different shell. Don't just retry the same call repeatedly.
24. **A tool can have no `--version` flag at all**, requiring a `version` subcommand instead on both platforms — `--version` erroring out with a full help dump is a distinct failure from "tool is broken," and worth checking before you assume something regressed.
