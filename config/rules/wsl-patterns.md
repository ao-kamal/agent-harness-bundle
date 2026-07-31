# WSL Invocation Discipline + Win+WSL Hybrid Architecture

## WSL Command Patterns

**Always invoke WSL with `-u root` for tooling.** Plain `wsl` defaults to user `user` (uid 1000) whose home is `/home/user/`, but every tool we install lives under `/root/`.

**Default shape: single-quoted heredoc into `bash -l`.** This is the canonical form for any WSL invocation that has shell content beyond a single trivial command:

```bash
wsl -d Ubuntu -u root -- bash -l <<'BASHEOF'
cd /mnt/c/path
for P in 0 1 2 3; do
  tmux capture-pane -t session:0.$P -p
done
BASHEOF
```

The `-l` (login shell) is required to load `/root/.bashrc` and `/root/.profile`. Without it, PATH is incomplete and most installed tools won't resolve.

**Default tool for any shell call with variables, captured content, loops, or chaining: Python `subprocess.run([cmd, *args], cwd=..., env=...)`** — Python's argv-list form passes args via the OS exec interface, zero shell layers, zero parsing. When you would otherwise build a `wsl ... bash -lc '...'` invocation that takes input from a variable, captured output, or a file body — write a 30-line Python wrapper instead.

**Degenerate inline form (`bash -lc 'simple-cmd'`)** — allowed only for single commands with no `$`, no backticks, no `$(...)`, no `&&`/`||`/`;` chaining, no captured content, no loops/conditionals, no multiline. Examples: `wsl -d Ubuntu -u root -- bash -lc 'tmux ls'`, `wsl -d Ubuntu -u root -- bash -lc 'ntm --robot-snapshot'`. Anything more complex → heredoc or Python subprocess.

**`curl ... | bash` masks failures unless `pipefail` is set.** If curl fails (DNS, network, 404), it returns non-zero, but the pipe still feeds bash an empty stdin, bash exits 0, and the pipeline reports success. Always wrap in `set -o pipefail` (or check `${PIPESTATUS[0]}`) when you care about the install actually happening.

**HEREDOC IS THE DEFAULT for `wsl ... bash` invocations. Inline `bash -lc '<script>'` is FORBIDDEN when the script contains ANY of the following tokens. The check is mechanical, not judgment-based — if any token in the prohibited list is present, STOP and rewrite as heredoc. No "this case is simple," no "single quotes will protect it," no "I'll just escape the dollar sign," no exceptions.**

**Prohibited tokens in inline `bash -lc '...'` script body:**

- `$` of any kind: `$VAR`, `${VAR}`, `$(...)`, `$1`/`$@`/`$*`
- `` ` `` backticks (in any position — literal or as command sub)
- `for`, `while`, `if`, `case`, `select` keywords
- `&&`, `||`, `;` chaining of more than 2 simple commands
- multi-line strings (any actual newline inside the script, not just `\n`)
- `[...]` or `[[...]]` test brackets
- captured-content interpolation (`"$(cat file)"`, `$(<file)`, `$(...command...)`)
- arrays (`ARR=(...)`, `${ARR[@]}`)

**If ANY of those are present, use a single-quoted heredoc:**

```bash
wsl -d Ubuntu -u root -- bash -l <<'BASHEOF'
cd /mnt/c/Users/{{WIN_USER}}/Documents/AgentVaults/example-swarm
for P in 0 1 2 3 4 5; do
  echo "===== pane $P ====="
  tmux capture-pane -t example-swarm:0.$P -p -S -15
done
BASHEOF
```

The `<<'BASHEOF'` (terminator wrapped in **single quotes**) is non-negotiable — without the quotes, Git-Bash on Windows expands `$P` BEFORE the heredoc reaches WSL, defeating the purpose. The terminator MUST be at column 0 (no leading whitespace) on its own line — indented terminators are a parse error.

**Why this rule is strict (don't try to argue around it):**
The script string traverses MSYS2 arg-conversion → `wsl.exe` Windows-arg-parser → WSL bash before being parsed. Each handoff can mangle differently. Single quotes that POSIX guarantees as literal **are NOT honored across the MSYS2 boundary in many cases** — variables empty out silently, captured-content backticks fire as command substitution at one of the layers, the bash inside WSL never sees what you wrote. Failure is silent: the loop runs but with `$P=""` six times, every captured pane is the same one, you don't notice until 3 ticks in. Heredoc bypasses the entire arg-mangle stack because the script reaches WSL bash via stdin, not args — there's nothing for MSYS2 or `wsl.exe` to re-tokenize.

**For content that needs to be a process argument WITHOUT any shell interpretation** (file bodies that may contain backticks, captured marching orders, bead descriptions, anything from `cat file` that you want to pass as `--description "<body>"`): **use Python `subprocess.run([cmd, *args], cwd=..., env=...)` directly.** Python's argv-list form passes args via the OS exec interface — zero shell layers, zero re-parsing, zero mangling. When the alternative is "spend 15 minutes finding which shell layer ate the backticks," write the 30-line Python wrapper.

**Rationalizations that have failed in practice — do not reuse them:**

- "It's just one variable, single quotes will protect it" — No. POSIX guarantees ≠ MSYS2 behavior. Heredoc.
- "The script is too short to bother heredocing" — typing-time savings: 8 seconds. Lost to silent failure when it goes wrong: 15+ minutes. Heredoc.
- "I'll pre-substitute the variable in the outer Bash" — works for that one variable, doesn't help with backticks, captured content, or the next maintainer. Heredoc.
- "I'll escape the `$` with `\$`" — escaping is inconsistent across the layer stack; one layer eats the backslash, the next doesn't. Heredoc.
- "It worked in the last invocation, so this similar one will work" — each invocation traverses the same fragile stack and the failure is silent. Heredoc.
- "I just need to capture-pane on 6 panes really quick" — exactly the case that has burned full sessions of orchestration time: `for i in 0 1 2 3 4 5; do tmux capture-pane -t SESSION:0.$i -p; done` run inline via `bash -lc` captured the SAME pane six times because the loop variable never expanded. Heredoc.

**Self-check before submitting any `wsl ... bash` Bash tool call:** scan the script string. Find any prohibited token? Rewrite as heredoc. No further deliberation.

## Win+WSL Hybrid Architecture

This is a hybrid environment: Windows is the primary OS for daily Claude Code work, WSL Ubuntu hosts ntm/tmux orchestration plus a parallel set of CLI tools. Tools and state are deliberately shared via symlinks so it feels like one system.

### Mental model

- You are running on Windows. WSL is a co-equal compute layer; invoke via `wsl -d Ubuntu -u root` (patterns above).
- Most flywheel tools (cass, cm, br, bv, caam, dcg, ubs, slb) are installed on BOTH sides — `/root/.local/bin/<tool>` (WSL) and `C:\Users\{{WIN_USER}}\.local\bin\<tool>.exe` or scoop shims (Windows). Same commands work on both sides. (ntm and ubs are WSL-only.)
- **WSL networking is mirrored mode** (`.wslconfig` `networkingMode=mirrored`) — WSL-hosted services are reachable from Windows at `127.0.0.1:<port>`, NEVER `localhost` (IPv6-first resolution trap; see rules/windows-commands.md → WSL networking).
- **This WSL runs without systemd.** Boot-time services are launched by the `/etc/wsl.conf` `[boot] command` hook, not systemd units (see Boot hook below). Tools that need systemd (SRPS's ananicy service, `systemd-run`-based `limited*` aliases) are degraded or skipped by design.

### Cross-OS symlinks (one source of truth)

| WSL path                          | → Windows file                                | What it shares                                                       |
| --------------------------------- | --------------------------------------------- | -------------------------------------------------------------------- |
| `/root/.claude/.credentials.json` | `/mnt/c/Users/{{WIN_USER}}/.claude/.credentials.json` | OAuth tokens (one OAuth = both OSes authed)                          |
| `/root/.claude/projects`          | `/mnt/c/Users/{{WIN_USER}}/.claude/projects`          | Claude Code session JSONL files (Windows cass picks up WSL sessions) |
| `/root/.claude/skills`            | `/mnt/c/Users/{{WIN_USER}}/.claude/skills`            | One skills directory read by both sides                              |
| `/root/.local/share/caam`         | `/mnt/c/Users/{{WIN_USER}}/.local/share/caam`         | caam vault — profiles visible from both sides                        |

### Boot hook (the actual WSL daemon launcher — no systemd)

`/etc/wsl.conf` sets `mountFsTab = false` and `[boot] command = /usr/local/sbin/mount-fast-data.sh`. On every WSL **cold boot** (not per-shell, not per-login) that script: waits up to 30s for `/mnt/c`, runs `mount -a` (fast-data bind mounts), idempotently starts the credentials-symlink watcher, and idempotently starts the Agent Mail server (`am serve-http --host 0.0.0.0 --port 8765`, if Agent Mail is part of your setup). Log: `/root/.local/share/mount-fast-data.log`. `mountFsTab=false` exists because WSL processes `/etc/fstab` before `/mnt/c` is mounted — fstab bind-mounts targeting `/mnt/c` would fail at native boot. A vestigial disabled systemd unit for agent-mail can exist from earlier attempts; the boot hook is the real mechanism.

### Credentials symlink self-healing (creds watcher)

`/root/.local/bin/claude-creds-symlink-watcher.sh` (inotify-based, respawn-wrapped, started belt-and-suspenders from `.bashrc`, `.profile`, and the boot hook via `ensure-claude-creds-watcher.sh`) defends against a specific corruption bug: Claude Code refreshes OAuth tokens via tmp-file + `rename(2)`, which DESTROYS the WSL-side symlink and leaves the Windows file stale — the next Windows-side refresh then gets rejected (token already rotated) and clears the field, corrupting both sides. The watcher detects the symlink being replaced, propagates the fresh tokens to the Windows file atomically, restores the symlink, and re-verifies after 2s to catch the reverse race.

### Hot vs cold filesystem rule (WSL2 SQLite anti-pattern)

**Default heuristic:** anything that does sustained `fsync()` or `fcntl(F_SETLK)` belongs on native ext4 (`/root/...`), NOT on `/mnt/c/...`. WSL2's 9p protocol over Windows NTFS makes those operations 10-100× slower than native ext4 — fine for read-mostly source code, pathological for SQLite DBs, lock files, and build caches under concurrent access.

| Type                                    | Lives on                  | Examples                                                                                                                             |
| --------------------------------------- | ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| **Hot** (writes, fsync, locks)          | native ext4 (`/root/...`) | SQLite DBs (`.beads/beads.db`, browser profiles), `.write.lock` files, `target/`, `node_modules/`, `.next/`, `.cache/`, build caches |
| **Cold** (read-mostly, source-of-truth) | `/mnt/c/...`              | Source code, markdown, configs, JSONL exports git-tracks                                                                             |

The bridge is **symlinks** (and, for `node_modules`/`.next`/`.turbo`, **bind-mounts** — see hot-data enforcement below).

**Concrete failure mode this prevents:** a multi-pane swarm hammering `br update` / `br close` against `/mnt/c/.../.beads/beads.db` produces multi-second SQLite write-lock timeouts; the identical swarm against a native-ext4-hosted DB resolves writes in under 100ms. 9p's POSIX-lock emulation queues every concurrent writer behind the prior fsync still draining through WSL→NTFS.

**Set up via the `init-fast-data` script** (`/root/.local/bin/init-fast-data`, in PATH on WSL) BEFORE running `br init` / `cargo new` / `npm init` / similar. Run from the project root on /mnt/c/:

```bash
init-fast-data .beads                    # before br init
init-fast-data target                    # before cargo new (Rust)
init-fast-data node_modules .next        # before npm init (Next.js)
```

The script is idempotent — safe to re-run; existing symlinks (whose target is under `/root/`) are skipped. `.gitignore` entry auto-added. First-run cost on existing dirs: cross-filesystem copy — a 5GB `target/` or `node_modules/` can take 30-90 seconds. Safety guards: refuses to migrate if open handles are detected in the target dir, and refuses on a basename collision between two same-named projects.

**Automatic enforcement layer:** `/root/.local/lib/hot-data-enforce.sh` (sourced from `.profile`) wraps `pnpm`/`npm`/`yarn`/`cargo`/`pip`/`uv`/`poetry`/`pipenv`/`python` as shell functions that refuse install-type subcommands on a `/mnt/c/*` project until its hot-data dirs are redirected off 9p; it auto-runs `init-fast-data` when the project marker file is present. For `node_modules`/`.next`/`.turbo` it uses **bind-mounts** (npm v11 deletes a symlinked `node_modules` and rebuilds it on 9p, silently defeating the symlink trick); bind-mounts are tracked in `/root/projects-data/.fastdata-mounts` and self-heal after `wsl --shutdown` via the boot hook's `mount -a`. Escape hatch: `HOT_DATA_ENFORCE_OFF=1 <command>`. Known limitation (in its own header): a pre-existing alias (e.g. `alias pnpm=...`) silently shadows the wrapper — check with `type pnpm`, fix with `unalias`. Run `check-fast-data` in a project root any time to verify its hot dirs are still ext4-backed (catches an install regressing a bind-mount back onto 9p).

For systematic project bootstrapping (full README + multi-dir setup + validation), see the `bootstrap-wsl-project` skill.

### Auth vs identity (Claude Code's secret split)

- **`.credentials.json`** = OAuth bearer/refresh tokens. OS-agnostic. Shared via symlink (and defended by the creds watcher above).
- **`.claude.json`** = settings + cached identity (`oauthAccount.emailAddress`, `userID`, `s1mAccessCache`, feature gates). Per-OS. **Drifts on every account switch** — Windows updates its `.claude.json` via caam activate, WSL doesn't get the update. The shared credentials.json means WSL Claude IS using the new account's tokens (auth works), but `.claude.json`'s cached email/feature-flags lag until manually synced.

Manual sync (Python, run after each Windows account switch — copies identity slice, leaves OS-specific fields like `mcpServers` and `projects` untouched):

```python
import json
WIN, WSL = "/mnt/c/Users/{{WIN_USER}}/.claude.json", "/root/.claude.json"
with open(WIN) as f: w = json.load(f)
with open(WSL) as f: l = json.load(f)
for k in ["oauthAccount","userID","s1mAccessCache","passesEligibilityCache",
          "anonymousId","claudeCodeFirstTokenDate","hasShownOpus47Notice",
          "hasShownOpus46Notice","cachedExtraUsageDisabledReason"]:
    if k in w: l[k] = w[k]
with open(WSL, "w") as f: json.dump(l, f, indent=2)
```

A wrapper that automates this entire flow (identity sync + the corruption-avoidance sequence below) is worth building for yourself once you're comfortable with the architecture — think of it as a `caam-safe` companion script.

### Mid-session caam corruption avoidance

Documented in caam README FAQ: switching profiles while Claude Code is running corrupts both the old AND new account's session. Best practice: kill all Claude windows → `caam activate <profile>` → relaunch. A wrapper script (see above) can automate this entire flow including identity sync.

### WSL claude wrapper (`/usr/local/bin/claude`)

A bash wrapper at `/usr/local/bin/claude` that auto-adds the cwd to `~/.claude.json`'s `projects` dict with `hasTrustDialogAccepted: true` (plus CLAUDE.md external-include approvals), then `exec`s the real binary at `/root/.local/bin/claude`. PATH is reordered in `/root/.bashrc` and `/root/.profile` so `/usr/local/bin` comes BEFORE `/root/.local/bin`, making the wrapper the default `claude` from any shell.

**Why:** Claude Code's per-folder "trust this folder" dialog blocks ntm-spawned panes. The dialog appears even with `--dangerously-skip-permissions` (which only skips runtime permission checks, not startup-time trust gating). Pre-trusting cwd before launch is the only way to get clean unattended automation.

### IS_SANDBOX

Set to `1` in `/root/.bashrc` and `/root/.profile`. Bypasses Claude Code's "you can't use `--dangerously-skip-permissions` as root" check. Required for ntm-spawned panes (which run as root in WSL). Without it, every pane fails with `--dangerously-skip-permissions cannot be used with root/sudo privileges for security reasons`.

### Smoke test

Run `install/smoke-test.sh` (in this bundle) after any infrastructure change to verify nothing regressed — binaries on PATH, symlinks resolving, cross-OS auth, Agent Mail reachability (`127.0.0.1` convention, never `localhost`), ntm spawn, cass WSL-session pickup. Don't trust an infra change until the smoke test passes clean.
