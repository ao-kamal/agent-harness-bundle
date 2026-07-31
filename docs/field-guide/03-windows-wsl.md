# 03 — Windows + WSL: The Hybrid Mental Model

This bundle runs on Windows as the primary OS, with WSL (Windows Subsystem for Linux — a real Linux environment running alongside Windows) doing the heavy lifting for multi-agent orchestration. The exact commands and rules for this live in `config/rules/wsl-patterns.md` and `config/rules/windows-commands.md`, and Claude reads those every session. This chapter is about *why* those rules exist — the mental model, not the reference card. Once you have the model, the rules stop looking arbitrary.

## Two computers, one workflow

Think of Windows and WSL as two separate computers that happen to share a screen. Windows runs Claude Code day to day. WSL runs the tmux-based multi-agent orchestrator (`ntm`) and a parallel copy of most of the same CLI tools. They're bridged deliberately in a few places — shared credentials, shared session history, a shared skills folder — but everywhere else, they are genuinely separate filesystems, separate process spaces, separate networking stacks. Most of the "why doesn't this work" moments in this setup trace back to forgetting that second half.

## The hot/cold filesystem rule

WSL can read and write Windows files (anything under `/mnt/c/...`), and it's tempting to just work there so everything's in one place. For source code, markdown, and config files, that's fine — those are "cold": read far more than written, and not sensitive to write latency.

Databases, lock files, and build caches are a different story — they're "hot": they do sustained, small, frequent writes with real locking semantics (`fsync`, file locks). WSL reaches Windows files through a compatibility layer (called 9p) that emulates POSIX file locks over what is, underneath, a network-like protocol talking to NTFS. For cold files that's invisible. For hot files it can be 10 to 100 times slower than a native Linux filesystem — not a little slower, categorically slower.

This stopped being theoretical the first time several agents in a swarm were all updating the same task-tracking database (`.beads/beads.db`) while it lived on the Windows side. Writes that should take milliseconds started taking 30 seconds each, because every writer was queueing behind the same slow lock-emulation path. Moving that one database to a native Linux filesystem and leaving a symlink in its place made the exact same swarm resolve writes in under a tenth of a second. Nothing about the swarm changed — only where the file physically lived.

The rule this bundle installs: SQLite databases, lock files, and build caches (`node_modules`, `target`, `.cache`) live on native Linux storage inside WSL, never on the Windows-mounted path, bridged back with a symlink so everything still looks like it's in the project folder. A script (`init-fast-data`) sets this up automatically before you initialize anything that creates hot files. You generally won't need to think about this once it's set up — just don't fight it by moving a database back onto `/mnt/c/...` "to make it easier to find."

## Why heredocs, not inline commands

When Claude needs to run something in WSL from a Windows session, the command has to cross three separate parsers before it actually executes: the Windows-side shell converting arguments, `wsl.exe`'s own argument handling, and finally the bash shell inside WSL. Each handoff is a chance for something to get silently mangled — and "silently" is the operative word. A shell variable that would work perfectly well in a normal Linux terminal can arrive on the other side already empty, or a backtick meant as a literal character can fire as a command substitution at the wrong layer, and nothing raises an error when it happens. The command still runs. It just runs wrong.

This is exactly what happened with a loop meant to capture output from six different agent panes: `for i in 0 1 2 3 4 5; do tmux capture-pane -t session:0.$i -p; done`, sent as a single inline command. It ran six times. It looked fine. Every single one of those six captures was actually the same pane, because the loop variable never survived the trip across the parser boundary — it arrived empty every time, and an empty index happened to resolve to something that didn't error out. Whoever's watching doesn't find out until several ticks later, looking at data that seemed plausible right up until it clearly wasn't.

The fix isn't "be more careful with quoting" — quoting guarantees from one shell don't reliably survive being re-parsed by a different one. The fix is to stop sending the command as a string at all. A heredoc (a block of text piped into a command as if typed at a prompt, rather than passed as a command-line argument) reaches the destination shell through standard input, not through argument parsing — there's nothing left for the intermediate layers to re-tokenize. For a command with any variable, any backtick, any loop, or any real chaining, that's the rule: heredoc, not an inline string. `config/rules/wsl-patterns.md` has the exact mechanical trigger list for when this applies.

## Two or three gates that look like one flag

Claude Code's `--dangerously-skip-permissions` flag skips the per-action confirmation prompts at runtime. It's easy to assume that one flag is "the safety system" and that turning it off means automation runs unattended. It doesn't — there are at least two more independent gates it does nothing about:

- A **startup trust dialog** — the first time Claude Code runs in a folder, it asks whether to trust that folder. This fires before any runtime permission check exists to skip, so `--dangerously-skip-permissions` never even gets a chance to apply to it. This bundle handles it with a small wrapper that pre-trusts a folder before launching Claude inside it, specifically so unattended, script-spawned agents don't stall waiting for a dialog nobody's watching for.
- A **separate `.git/` sensitivity gate** — the first time an agent touches `.git/` in a given project, a distinct dialog fires regardless of the permissions flag. In a swarm where several agents commit around the same time, you can see several of these dialogs stacking up in the same few seconds, each one blocking its own pane until answered.

When automation "still gets blocked despite the bypass flag," the useful question is never "why didn't the flag work" — it worked exactly as documented. The useful question is *which* of the independent gates this is, because each one needs its own handling.

## `127.0.0.1`, never `localhost`

If a WSL-hosted service isn't reachable from Windows (or the reverse), the instinct is to assume the service crashed or never started. Before chasing that, check one specific and completely non-obvious trap: on Windows, the name `localhost` resolves to the IPv6 address `::1` before it tries the IPv4 address `127.0.0.1`. If the service you're trying to reach only listens on IPv4 — which most small local servers do by default — and the networking mode in play doesn't handle that IPv6 loopback path cleanly, the connection just hangs until it times out. It doesn't refuse the connection quickly the way a genuinely-down service would; it sits there, which reads exactly like "the service must be stuck," when the service was fine the whole time.

This exact trap produced a mystery that looked, for a long stretch, like a fundamentally broken networking setup — a coordination server that Windows simply couldn't reach, investigated and re-investigated, with the service itself never once at fault. The fix, once found, was one word: use `127.0.0.1` explicitly instead of `localhost` in every health check, every registration, every probe. This bundle's config and smoke tests already follow that convention everywhere a WSL-hosted service gets addressed from Windows — if you ever add a new one yourself, carry the same habit forward.

## Windows fails silently more often than you'd expect

A theme worth internalizing on its own: several very ordinary Windows operations fail in ways that don't look like failure. `cmd /c move`, chained with `&&`, can report success on the whole chain while the file never actually moved. `curl | bash` — piping a downloaded install script straight into a shell — reports success even when the `curl` half failed outright, because an empty download still counts as "something" being piped to bash, and bash exiting cleanly on empty input isn't an error. Neither of these raises anything you'd notice at the time; they just quietly do the wrong thing, or nothing, and you find out later when something downstream doesn't work.

The general habit worth building: prefer tools that fail loud (bash's own `mv`, `ls` over their `cmd` equivalents; `set -o pipefail` on anything piped into a shell) over tools that fail quiet. When you're not sure, ask "would I actually notice if this silently did nothing?" — if the honest answer is no, that's the thing to fix before you rely on it.

## Large downloads: BITS, not `curl` or `Invoke-WebRequest`

On a slow or unreliable connection, both of Windows' obvious download tools have the same weakness: neither resumes a broken transfer. `Invoke-WebRequest` just times out. `curl.exe` fails mid-transfer in a couple of different ways depending on exactly where the connection dropped. Both can fail identically, repeatedly, on the exact same file — which looks like "this file won't download," when the actual problem is that neither tool tolerates the network condition at all.

`Start-BitsTransfer` (part of Windows' built-in Background Intelligent Transfer Service) is resumable and tolerates a flaky connection by design — it's what Windows Update itself uses. For anything large (a release binary, an installer), this bundle's install steps use BITS specifically for that reason, and verify the download's checksum afterward regardless — a resumed-but-corrupted download is still a real failure mode, just a much rarer one.

## No systemd: the boot hook

A standard Linux install typically starts background services through `systemd`. The WSL environment this bundle sets up runs without it. Instead, a single script is registered as WSL's own `[boot] command` in `/etc/wsl.conf` — it runs once, automatically, on every *cold boot* of the WSL virtual machine (not on every new terminal, not on every login — specifically on the VM actually starting up, which happens less often than you'd think, since WSL stays running in the background across many terminal sessions). That one script waits for the Windows-side filesystem to be ready, sets up the hot/cold filesystem bind-mounts described above, and starts any background services this setup depends on.

The practical consequence: if you change something about those background services and it doesn't seem to take effect, check whether you actually triggered a cold boot. `wsl --shutdown` from PowerShell, followed by opening any WSL terminal again, forces one. Restarting a single terminal window does not.

## The credentials watcher

Claude Code refreshes its own login tokens periodically by writing a new file and atomically renaming it into place. That's a sound way to update a file safely — except when the file in question is one end of a symlink bridging Windows and WSL, in which case the rename operation destroys the symlink itself, not just the file's contents. The WSL side is left pointing at nothing, and depending on timing, the next refresh on the other side can get rejected because the token was already rotated, corrupting both sides at once.

The fix here is another small always-on background piece: a watcher process that notices the moment the symlink gets replaced, copies the fresh tokens across immediately, and restores the symlink — with a short second check afterward to catch the case where the timing raced the other direction. You won't interact with this directly; it's part of what the boot hook above starts automatically. It's worth knowing it exists, because "my WSL side suddenly can't log in" is the symptom, and the watcher (or its absence) is usually the actual story.
