# Pitfall Catalogue — symptom → root cause → fix → prevention

Read the entries for your current stage BEFORE starting it. All entries are from real builds.

1. **wp-env: "network is not available" though internet works** → Node c-ares + WireGuard-on-Windows defaults c-ares to dead 127.0.0.1; system DNS fixes fail → per-process `NODE_OPTIONS="--require ./wp-env-dns-fix.js"` on every wp-env call → preflight applies preload directly; never chase adapter/registry DNS.
2. **Core download dies mid-checkout ("could not fetch from promisor remote")** → default core is a two-phase git partial clone; phase-2 blob backfill breaks on flaky links → `"core": "<zip url>"` + git HTTP/1.1 robustness config → ZIP-source always.
3. **Config edits ignored after .wp-env.json change** → stale `~/.wp-env/wp-env-site-<hash>/` reuse → wipe dir (targeted Remove-Item + guard) → clear cache after any config change.
4. **Docker build dies at apt-get/apk "Could not resolve"** → build containers inherit broken host DNS (preload fixes host only) → daemon.json dns + restart + alpine nslookup verify → container-DNS probe in every preflight.
5. **Docker Desktop dead mid-pipeline** → engine crash under restart cycle / idle saver → relaunch, wp-env start, rerun idempotent step — nothing lost IF pipeline is idempotent → probe `docker info` before EVERY batch.
6. **Mobile accordion taps navigate instead of expanding** — three-pass trap: (a) FAB geometry over tap zones (plausible, wrong), (b) smooth-scroll glide landing taps mid-animation (real but secondary; fix = instant jumps <900px), (c) actual cause: hidden mobile nav sheet's submenu forced `visibility:visible`, escaping parent's `hidden` while opacity:0 hides compositely → invisible-but-tappable links under the header on every page. Fix: `visibility:inherit`. Prevention: ghost-tap hunts sweep elementFromPoint across the FULL viewport grid incl. under-header band; smooth-scroll makes scroll audits lie; test with real CDP touch events (`Input.dispatchTouchEvent`; note Emulation.setEmitTouchEventsForMouse deadlocks Playwright mouse.click).
7. **Sitewide font fallback after deploy** → deploy copied design CSS whose font paths (`../fonts/`) don't exist in theme context → sed path rewrite at sync time → deploy scripts rewrite relative paths per destination.
8. **Blocks render EMPTY with only default values visible** → wp_insert_post's internal wp_unslash eats backslashes from attr JSON containing quotes → always `wp_slash()` whole postarr + `serialize_block_attributes()` for grammar → baked into assembler; parity gate catches it.
9. **Raw HTML entities (&#8217;) in JSON-LD schema text** → entity handling on rich_text → decode after strip_tags when emitting schema → generate schema from same fields as visible content (drift structurally impossible).
10. **Stale pages after purge-all** → LiteSpeed tagless orphan cache (no x-litespeed-tag, 7-day TTL) → CacheLookup toggle overwrite-flush (see deploy-runbook) → flush routine baked into deploy script + served-version verification.
11. **wp_mail returns true but mail silently bounces** → no mailbox exists for From address → create mailbox via cPanel UAPI → deliverability E2E post-deploy.
12. **RankMath outputs nothing headless** → registration gate bails init_frontend under WP-CLI → skip wizard via option/constant; run installer hook manually via eval-file, idempotently.
13. **Redirection "Invalid group" on live** → plugin DB tables not initialized → init first, then create rules.
14. **Command guards block cleanup** (`rm -rf ~` shapes) → targeted PowerShell `Remove-Item -LiteralPath <abs-path> -Recurse -Force` with a valid-target guard (e.g. confirm a WP core marker file exists before deleting a core dir). Also: `wp-env destroy --force` refuses on never-initialized envs — delete the cache dir instead.

15. **wp_mail returns true but mail silently bounces** → no mailbox exists for the From address → create the mailbox via cPanel UAPI (`uapi Email add_pop email=<user> domain=<domain> quota=...`) → deliverability E2E post-deploy (check X-Failed-Recipients in maildir).
16. **RankMath outputs nothing headless** → registration gate bails `init_frontend()` under WP-CLI-only installs → skip the wizard via option/constant, run its installer hook manually via eval-file, idempotently; also empty its per-page schema output when the theme owns JSON-LD.


## Process lessons

- Diagnose from logs/source before fixing; write each fix down as a preflight so it never recurs.
- Don't assume heavy downloads/flaky networks without evidence — one build's failure was a 4MB shallow pack's phase-2 backfill, not bandwidth.
- Verify WHICH component is stale before re-running (config cache vs missing artifact were conflated once, wasting a cycle).
- Parity gates catch what eyeballs miss: the two worst bugs above (backslash-eating, entity leakage) were both caught by the harness, not by humans.
