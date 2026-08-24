# Environment — Windows-native dev preflights & verbatim configs

Run these checks IN ORDER before S0. Each exists because a real build died without it.

## 0. Probes (every session, every wp-env batch)

```bash
docker info                    # daemon up? Docker Desktop dies silently mid-pipeline
docker run --rm alpine nslookup deb.debian.org   # container DNS works?
```
Rule: probe `docker info` before EVERY wp-env batch, not just session start. Transient `apk` exit-6 right after engine boot → retry once before diagnosing.

## 1. c-ares / WireGuard DNS bug (wp-env "network is not available" though internet works)

Root cause: wp-env's online check uses Node c-ares `dns.resolve()`. With WireGuard-primary tunnels on Windows, c-ares hard-defaults to dead `127.0.0.1`. System-level adapter/registry DNS fixes DO NOT WORK — don't waste time. Per-process preload is the fix.

`wp-env-dns-fix.js` (entire file):
```js
require('dns').setServers(['8.8.8.8', '1.1.1.1']);
```
Invoke for EVERY wp-env subcommand that parses config (including `stop`):
```bash
NODE_OPTIONS="--require ./wp-env-dns-fix.js" wp-env start
```

Diagnostic triple if it ever recurs: `dns.resolve('host')` (fails) vs `dns.lookup('host')` (works) vs `require('dns').getServers()` (shows ["127.0.0.1"]).

## 2. Core source = ZIP, never git clone

Default wp-env core resolves to a two-phase git partial clone whose phase-2 blob backfill breaks on flaky links ("could not fetch from promisor remote"). Always pin:

```json
"core": "https://wordpress.org/wordpress-<VERSION>.zip"
```

Pin `<VERSION>` to the CURRENT stable WordPress at port time (check wordpress.org API) — the template's 7.0 is an example, not a recommendation.

## 3. `.wp-env.json` template

```json
{
  "$schema": "https://schemas.wp.org/trunk/wp-env.json",
  "core": "https://wordpress.org/wordpress-7.0.zip",
  "phpVersion": "8.2",
  "testsEnvironment": false,
  "themes": [ "./themes/<theme-slug>" ],
  "config": { "WP_DEBUG": true, "WP_DEBUG_LOG": true, "WP_DEBUG_DISPLAY": false },
  "mappings": { "design-src": "../design" }
}
```

## 4. Stale cache ignores config edits

wp-env regenerates compose files only when `~/.wp-env/wp-env-site-<hash>/` is absent. After ANY change to `.wp-env.json`: delete that dir (targeted PowerShell `Remove-Item -LiteralPath <path> -Recurse -Force` with a valid-target guard — bare `rm -rf ~` paths get blocked by command guards). Changing mappings invalidates the hash → expect a full ~8-min image rebuild.

## 5. Docker build containers inherit broken host DNS

Build step (`apt-get`/`apk`) fails with "Could not resolve" even after the NODE_OPTIONS preload fixes the host process. Fix: add `"dns": ["8.8.8.8", "1.1.1.1"]` to `~/.docker/daemon.json`, restart Docker Desktop, verify with the alpine nslookup probe.

## 6. Git robustness (belt-and-braces)

```bash
git config --global http.version HTTP/1.1
git config --global http.postBuffer 524288000
git config --global http.lowSpeedLimit 0
git config --global http.lowSpeedTime 999999
```

## 7. PHP + Composer on Windows hosts (scoop)

`scoop install php composer` — then FIX scoop's PHP: it ships NO php.ini. Copy `<scoop-prefix>/php/cli/php.ini` next to php.exe; uncomment `extension=openssl,curl,mbstring,zip,fileinfo`; set absolute `extension_dir`. Without openssl, Composer dies mid-download.

Carbon Fields: `composer require htmlburger/carbon-fields` inside the theme; COMMIT vendor/ + composer.lock so shared hosting needs no composer. Check .gitignore doesn't exclude vendor/ (inline comments after patterns don't match).

## 8. MSYS/Git-Bash path mangling

Container paths passed to `wp-env run` get rewritten to Windows paths. Prefix:
```bash
MSYS2_ARG_CONV_EXCL="*" wp-env run cli wp media import /var/www/html/...
```

## Misc

- Use `127.0.0.1`, never `localhost`.
- First request after idle ~15–20s (PHP cold-start), then instant.
- Env-var swaps don't propagate to running shells (Process scope beats User scope; shells cache at init) — restart shells/subagents after credential changes.
- Interactive CLIs may EXECUTE on `--help` (auto-default through prompts); scope-aware installers update whichever skills dir matches cwd — run from `$HOME` to hit the global copy.
