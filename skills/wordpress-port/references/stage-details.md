# Stage Details — input → output → completion per stage

## S0 — Scaffold local environment

- **Input:** Docker Desktop installed; Node ≥20; wp-env available globally.
- **Preflights (run ALL before scaffolding — see [environment.md](environment.md)):** `docker info` probe · DNS preload active for the wp-env process · container-DNS verified via alpine nslookup.
- **Output:** `.wp-env.json` (core = ZIP URL, pinned version), empty theme skeleton (`style.css` header, `functions.php` with Carbon Fields boot pre-staged, minimal `index/header/footer.php`).
- **Completion:** `wp theme activate <slug>` succeeds; site serves HTTP 200 at `127.0.0.1:8888`; a known proof-marker string in footer.php renders.
- Gotcha: use `127.0.0.1`, never `localhost` (Windows Docker IPv6 loopback flakiness). First request after idle ~15–20s cold-start.

## S1 — Project context

- **Input:** brand docs, voice guidelines, scope decisions on disk.
- **Output:** PRODUCT.md-equivalent context for design work (register, anti-references); confirmed page list + copy source-of-truth file.
- **Completion:** every page has locked copy in one canonical file; editors' banned-register list recorded.

## S2 — Token layer

- **Input:** the site's canonical tokens (DESIGN.md export, or an existing `:root` block promoted to `tokens.json`).
- **Output:** `assets/tokens.css` + `theme.json` — BOTH machine-generated from the single token source.
- **Completion:** every color/type/spacing/radius token exists as a custom property; editor palette matches. No hand-edited generated files, ever.

## S3 — Design source

Done BEFORE this skill runs (impeccable craft pass, or an existing built static/Astro site). This skill requires a FROZEN reference: tag the repo and commit built output. The parity gate compares against that tag forever, never against a live rebuild. Any post-freeze change to the source = full gate re-run + new tag before resuming.

## S4 — Section→block transform

- **Input:** frozen designed pages; theme exemplar block.
- **Rules:** see THE EXACT PROMPT in SKILL.md. Additional field-design judgments:
  - Mixed-media galleries = Complex field with NAMED GROUPS; discriminate on `_type` in render.
  - Schema/JSON-LD generated from the SAME fields that render visible content — drift structurally impossible. Entity-decode after strip_tags when emitting schema text.
  - Image fields store attachment IDs; render helper outputs width/height from meta, alt from post meta; hero images get `loading="eager" fetchpriority="high"`.
- **PILOT-FIRST:** build ONE representative polymorphic section end-to-end (media import + assembly + render check) before mass-producing blocks. The pilot validates the whole pipeline cheaply.
- **Completion:** census reported — block types × instances matches the designed sections EXHAUSTIVELY; php -l clean; registry eval lists all blocks; pilot renders byte-comparable to design.


### Correspondence map (impeccable concept → WordPress mechanism)

| impeccable/CSS concept | WordPress mechanism |
|---|---|
| DESIGN.md tokens | `:root` custom properties + theme.json editor palette — both generated from ONE token source |
| Designed section (self-contained HTML/CSS) | Carbon Fields block (`Block::make` fields + render callback) |
| "generated vs true source" guard (`is-generated.mjs` pattern) | rendered page vs block template — never edit rendered output, always the block source |
| Live-mode param knobs → CSS vars | optional style fields; mostly expose content, rarely style |
| PRODUCT.md register / anti-references | brand context docs + voice guidelines (banned-register list maps to anti-references) |
| register = brand ("design IS the product") | marketing/lead-gen sites use the bold, image-led brand register |

Calibration from the proven build: an 8-page marketing site decomposed into **21 distinct block types across 44 instances** (per-page 3–10 sections, media manifest 24 files). Derive exact counts for a new port from the frozen source during the census — never price the phase off precedent alone.

### Publishing prerequisite
Article publishing via WP REST (mcp-adapter pattern) needs an Application Password created on the live site. Set up at S6 alongside analytics.

## S5 — Scripted content assembly

Pipeline (all idempotent):
1. **Extractor** — reads the frozen design/content source into per-page field-data JSON. One function per block type mirroring its field schema; copy transfers byte-faithfully; media as `img:`/`file:` placeholders; emits media manifest.
2. **Media importer** (`tools/import-media.php`, `wp eval-file`) — sideload loop, idempotent via `_yodo_src_file` post meta; alt from source.
3. **Page assembler** (`tools/assemble-pages.php`, `wp eval-file`) — block grammar via core's `serialize_block_attributes()`; upserts pages by slug via `wp_slash(wp_insert_post)` — BOTH mandatory: wp_insert_post's internal wp_unslash silently eats backslashes, breaking any attr JSON containing quotes → blocks render EMPTY with defaults only. Sets front page/posts page; stores SEO title/desc as post meta. Reuses existing page IDs so URLs never flicker.
4. **Parity harness** (`verify-parity`) — text parity + structure parity vs the FROZEN reference. Loop: extract → assemble → verify → fix until ALL PAGES MATCH.
- **Completion:** ALL PAGES MATCH both axes; debug.log clean.

## S6 — Tech/SEO layer

- Hand-rolled JSON-LD in theme (Organization/LocalBusiness/BreadcrumbList; FAQPage from block fields; HowTo from step-block data). RankMath titles/descs wired from stored post meta; per-page schema OFF in RankMath (theme owns JSON-LD) + `rank_math/json_ld` emptied to prevent @graph duplication.
- RankMath headless gotcha: skip the wizard via option/constant; run its installer hook manually under WP-CLI.
- robots.txt: AI crawlers (GPTBot/ClaudeBot/PerplexityBot) explicitly ALLOWED — raw semantic H2/H3 is the AEO answer-boundary signal.
- Redirect map: build CSV of old→new URLs; Redirection plugin needs DB init before rules ("Invalid group" otherwise).
- Analytics: GTM container ID set via option; guard against double-tagging when Site Kit coexists.
- **Completion:** schema validates per page; redirects asserted; debug.log zero; sitemap live.

## S7 — Deploy + live QA

See [deploy-runbook.md](deploy-runbook.md). Sequence summary: backup first → ship theme tar-over-ssh → live WP-CLI sequence → purge + CacheLookup overwrite-flush → verify served asset versions → parity re-run ON LIVE → forms E2E via real browser → sitemap submitted to GSC.
