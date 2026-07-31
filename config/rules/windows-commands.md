# Windows Command Discipline

## Following GitHub Setup Instructions

**When setting up tools/projects from GitHub repos, follow the README instructions EXACTLY.** Do not improvise or branch out on your own. Run the commands they specify, in the order they specify. If they have a setup wizard, run it. If they have specific steps, follow them step-by-step. Don't create config files manually if there's a setup command. Don't skip steps. Don't "optimize" the process.

**ALWAYS reference official Claude Code documentation** when implementing workflows, agents, commands, or configurations:

- Documentation map: https://docs.claude.com/en/docs/claude-code/claude_code_docs_map.md
- Sub-agents: https://docs.claude.com/en/docs/claude-code/sub-agents.md
- MCP: https://docs.claude.com/en/docs/claude-code/mcp.md

## Code Writing Guidelines

**NEVER use emojis in code, scripts, or automation files.** Emojis break code execution and cause encoding errors. This includes Python scripts, JavaScript/Node.js files, JSON configuration files, shell scripts, any executable code.

Emojis are acceptable ONLY in: Markdown documentation files, comments (with caution), user-facing text content.

## Process Management on Windows

**Never guess which processes to kill. Always inspect first.**

Before killing any process, run:

```python
import subprocess
r = subprocess.run(['wmic', 'process', 'where', 'name="python.exe"', 'get', 'processid,commandline'], capture_output=True, text=True)
print(r.stdout)
```

This shows the exact command line for each PID so you can identify:

- Which PIDs are Claude Code internals (MCP servers, etc.) — leave these alone
- Which PIDs are orphaned background tasks — kill these by PID
- Which PID is the active task — leave this alone

**Kill by specific PID only**, never `taskkill /IM python.exe` (kills everything including Claude Code itself):

```python
subprocess.run(['taskkill', '/F', '/PID', '12345'], capture_output=True)
```

**Background task hygiene:**

- Only one pipeline script should run at a time
- When restarting a failed task, confirm previous PIDs are dead before launching again
- Use `subprocess.run()` without `timeout=` in scripts that run as background tasks — the outer Claude Code timeout handles it

## Streamable-by-Design Output

**Any script that might be backgrounded, monitored, or tailed should stream its output by design — not rely on the caller to unbuffer it.** When stdout is redirected to a file or pipe (which is exactly what `run_in_background: true` does), most runtimes switch from line-buffered to block-buffered (4-8KB), so a script that prints short progress lines writes nothing observable for minutes. Treat progress output as part of the script's public interface: opt out of block buffering at the source, not at the call site.

**Python — bake it into every script you write:**

```python
# At the top, before any print():
sys.stdout.reconfigure(encoding="utf-8", errors="replace", line_buffering=True)
```

Add `flush=True` on the progress prints you care about (model loaded, N/M processed, wrote X). This makes the script stream correctly whether it's run interactively, in a pipe, or backgrounded — no caller configuration needed.

**Node.js:** each progress log should `process.stdout.write(line + "\n")` with an explicit newline. Avoid batching progress through `console.log` inside tight loops without a terminal flush.

**Shell pipelines** — each stage that filters progress must be unbuffered or the later stages see nothing:

```bash
tail -f run.log | grep --line-buffered "progress" | awk '{ print; fflush() }'
stdbuf -oL -eL <cmd>   # generic wrapper when a tool lacks a native flag
```

**Fallback at the call site** (when you can't modify the script): `py -u script.py`, `PYTHONUNBUFFERED=1`, `node --no-deprecation`, or `stdbuf -oL`. But treat these as cleanup for scripts you inherited — scripts you author should stream on their own.

**Design check before shipping a pipeline script:** if a caller runs this in the background and tails the output file, do the early progress lines show up within a few seconds? If the answer is "only after 4KB accumulates," the script is under-buffered and the failure mode is indistinguishable from a hang.

## Command Choice on Windows

**Use bash commands instead of Windows commands for file operations:**

- **Use**: `mv`, `ls`, `ls -la` (bash commands)
- **Avoid**: `cmd /c move`, `dir /b` (Windows commands fail silently in chained operations)
- **Best**: Python one-liners for batch file operations:
  ```bash
  python -c "import shutil, glob; [shutil.copy(f, 'destination/') for f in glob.glob('source/*.png')]"
  ```

**Why**: Windows commands (`cmd /c move`) fail silently when chained with `&&`, causing files not to move despite appearing successful. Bash commands (`mv`) work reliably across platforms and provide proper error feedback.

## Windows Command Gotchas

**`schtasks` and other `/flag` commands get mangled by Git Bash.** MSYS path conversion turns `/create` into `C:/Program Files/Git/create`. Never run `schtasks`, `reg`, or similar Windows commands with `/flag` syntax directly in bash.

- Use `subprocess.run(cmd, shell=True)` in Python with raw strings:
  ```python
  subprocess.run(r'schtasks /create /tn \"Task\" /tr \"C:\path\to\exe\" /sc minute /mo 30 /f', shell=True)
  ```
- PowerShell is also safe: `powershell -Command "..."` preserves flags.

**`chmod` has no effect on Windows files.** It runs without error but changes nothing. Windows file permissions use NTFS ACLs.

- Read-only flag: `attrib -R file` / `attrib +R file`
- ACL inspection: `icacls path`
- ACL modification: `icacls path /grant <username>:F`

**WSL cannot write to Windows paths via symlinks.** If a WSL path (e.g., `/root/.claude/skills/`) is symlinked to a Windows path, Rust/native binaries in WSL may fail with "Permission denied" when writing through the symlink. Use `/mnt/c/Users/{{WIN_USER}}/...` instead for cross-boundary writes.

**If you run WSL2 in mirrored networking mode** (`.wslconfig` `networkingMode=mirrored`) — WSL and Windows share interfaces, so a WSL-bound `0.0.0.0:<port>` IS reachable from Windows. **But always use `127.0.0.1`, never `localhost`, for any WSL-hosted service**: Windows resolves `localhost` to IPv6 `::1` first, most of these servers listen IPv4-only, and mirrored mode blackholes the IPv6 loopback path — the probe hangs to timeout instead of fast-refusing. (`curl.exe http://127.0.0.1:<port>/...` works instantly on the identical server that `Invoke-WebRequest http://localhost:<port>` false-hangs on. This exact trap can fake a "service is down" outage for weeks if you don't know to check it.)

Under NAT mode (the WSL2 default): `localhost` is NOT shared between Windows and WSL; a Windows-bound `0.0.0.0:8765` needs `host.docker.internal:8765` from WSL, and `127.0.0.1`-bound Windows ports are unreachable from WSL entirely. **`localhostForwarding` port-collision footgun** (named incident): WSL2 auto-mirrors any port a WSL process listens on onto Windows `127.0.0.1:<port>` via a `wslrelay` process — a WSL bridge listening on the same port as a Windows service hijacked that port, breaking the Windows service's own startup self-probe. Diagnostic: `Get-NetTCPConnection -LocalPort N -State Listen`, check if the owner is `wslrelay`.

**Large-file downloads on throttled/flaky networks: use BITS (`Start-BitsTransfer`), NOT `Invoke-WebRequest` or `curl.exe`.** `Invoke-WebRequest` times out (no resume), and `curl.exe` (even with `-C -`/`--retry`) frequently fails mid-transfer (exit 28 timeout, exit 92 HTTP/2 stream error) — repeatedly producing partial files that fail checksum. BITS is resumable, throttle-tolerant, and background-friendly:
```powershell
Import-Module BitsTransfer
Start-BitsTransfer -Source $url -Destination $dst -RetryInterval 60 -RetryTimeout 600
```
Always verify the SHA256 after (`Get-FileHash $dst -Algorithm SHA256`). If WSL needs a Linux binary but WSL's own `curl` is throttled, BITS-download it on the Windows side and hand it to WSL via `/mnt/c`. After downloading any executable, run `Unblock-File` on it — Mark-of-the-Web can silently block first execution.

**Windows PowerShell 5.1 pipes prepend a UTF-8 BOM when piping text to native programs** (`echo '...' | python script.py` delivers `\ufeff{...}`). Scripts that parse piped stdin (hook scripts, JSON consumers) must strip the BOM or they silently fail — and a hook that fails open makes this look like "the hook doesn't work" when tested from PowerShell.

## Python Commands on Windows

**Preferred commands:**

- `pip install package` - Direct pip (once your Python install is on PATH)
- `python script.py` - Direct python
- `py -3.13 script.py` (or whatever fallback version you keep installed) - Run under an older interpreter explicitly when a package lacks wheels for your primary Python version (torch, numba, frida, etc. are common offenders)

**Fallback if PATH issues occur:** `py -m pip install package`, `py script.py`, `py -c "code"`.

**WSL Python is bare AND only `python3` resolves** — `python3` is present but bare `python` is NOT (no `python-is-python3` package, no `/usr/bin/python` symlink). Heredocs that invoke Python from WSL must say `python3` explicitly or 404. The `python3` interpreter also ships without numpy, scipy, pandas, model2vec, yaml, and most third-party libraries — don't assume any non-stdlib modules.

**Default behavior on `ModuleNotFoundError` / "command not found": install, don't fall back.** When you hit a missing dependency anywhere in this environment (WSL or Windows), install the thing before reaching for a workaround. Only fall back to alternative implementations if installation _actually fails_ — and say so explicitly when you do.

```bash
# Missing Python module in WSL (default):
pip install --break-system-packages <pkg>          # works for everything; --break-system-packages required on Ubuntu 23.04+

# Missing Python module in WSL (preferred when available):
apt install -y python3-<pkg>                       # apt versions where they exist; lighter than pip

# Missing CLI tool in WSL:
apt install -y <pkg>                               # apt-cache search <thing> first if you don't know the package name

# Missing Python module in Windows:
pip install <pkg>                                  # or: py -m pip install <pkg>

# Missing npm package:
npm install -g <pkg>                               # use --silent in scripted contexts
```

This rule applies anywhere you hit a "thing isn't installed" error. Don't rebuild functionality (e.g., regex parsing instead of `pyyaml`); the install is almost always faster than the workaround.

## Secrets in Shell Configs

**Tokens never live directly in `.bashrc`/`.profile`.** Private tokens go in `~/.env.private` (Windows Git Bash) and `/root/.env.private` (WSL, chmod 600), sourced from the shell configs. This keeps shell configs shareable/template-able without a scrub pass. New secrets follow the same pattern: add the `export` line to the `.env.private` file, never to the rc files themselves.
