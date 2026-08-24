# Deploy Runbook — shared cPanel hosting (Namecheap-class)

## Access chain (all headless via a driven browser)

1. cPanel login (`https://<server>/cpanel` → :2083). Gotcha: the login submit stays `disabled` until real key events — use per-character typing, not value-fill.
2. SSH usually OFF → enable via Manage Shell toggle.
3. Generate local ed25519 keypair; IMPORT public key via cPanel SSH Access UI; then a SEPARATE Authorize step is required (imported keys start unauthorized). The authorize form submit is an `input[value=Import]` — text-matching "Import" hits a nav button and silently no-ops.
4. Connect: `ssh -i ~/.ssh/<key> -p <port> <user>@<server>` (Namecheap port typically 21098). Match server PHP version to local wp-env PHP.

## Sequence

1. **BACKUP FIRST, every time:**
   ```bash
   wp db export ~/preflight-backup-$(date +%Y%m%d)/db.sql --add-drop-table
   tar czf ~/preflight-backup-$(date +%Y%m%d)/wp-content.tar.gz wp-content
   ```
2. **Ship theme** (tar-over-ssh; rsync unavailable in Git Bash):
   ```bash
   tar czf - <theme-dir> | ssh ... 'tar xzf - -C ~/public_html/wp-content/themes/'
   ```
   Design/media source goes OUTSIDE docroot (e.g. `~/design-src/`) for the importer's src-dir arg.
3. **WP-CLI on host:** curl phar → `~/bin/wp`.
4. **Live sequence:** theme activate → plugins install/activate → `wp eval-file import-media.php <src>` → `wp eval-file assemble-pages.php` (reuses page IDs so URLs never flicker) → `wp rewrite structure "/%postname%/"` → `wp eval-file setup-seo.php` → delete junk posts → deactivate old-stack plugins → purge.
5. **Redirects:** init Redirection DB tables before creating rules ("Invalid group" otherwise); assert every 301 with redirect-disabled curl.

## LiteSpeed cache — two layers

- **Purge is a mandatory deploy step** (`wp litespeed-purge all`) — stale pages serve otherwise.
- **Tagless orphans survive purge-all**: cached copies with no x-litespeed-tag, unreachable by any purge variant (7-day TTL). Overwrite-flush fix:
  ```bash
  # backup .htaccess first
  sed -i 's/^CacheLookup on$/CacheLookup off/' ~/public_html/.htaccess
  for p in "${PAGES[@]}"; do curl -s -A "Mozilla/5.0 (deploy-warm)" "https://<domain>/$p" -o /dev/null; done  # twice each
  sed -i 's/^CacheLookup off$/CacheLookup on/' ~/public_html/.htaccess
  # verify CacheLookup restored to exactly one "on"
  ```

## Self-verification (deploy script should do all of these)

- Served asset `?ver` equals shipped file mtime on server.
- fonts.css paths correct for destination context (design CSS uses `../fonts/`, theme needs `fonts/` — sed rewrite at sync time).
- Parity harness re-run ON LIVE: ALL PAGES MATCH.
- Forms E2E via REAL BROWSER ONLY — LiteSpeed bot-challenge intercepts non-browser POSTs to admin-post.php; curl tests fail while browsers pass. Verify: submission stored → success state → analytics event pushed.
- debug.log zero fatals/warnings/notices.
- http→https 301; sitemap live; robots.txt serving.

## Post-cut SEO continuity

- GSC property verified via DNS (not Vercel-specific methods) BEFORE cutover; new sitemap submitted after cut.
- Keep the old host/front-end alive through TTL propagation; monitor GSC Coverage ~14 days.
- Analytics: same GA4 property + GTM container ID carried over; check for double-tagging when plugin-based snippets coexist; key-event smoke test on live.
