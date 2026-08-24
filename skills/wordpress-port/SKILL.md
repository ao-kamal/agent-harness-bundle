---
name: wordpress-port
description: >-
  Ports a finished coded/static website into WordPress as a classic PHP theme
  with Carbon Fields section blocks — design locked, content light-editable —
  via a staged pipeline (wp-env local dev → section→block transform → scripted
  content assembly → parity gates → cPanel deploy). User-invoked.
disable-model-invocation: true
---

# WordPress Port

> **Core Insight:** impeccable/CSS frameworks and WordPress do NOT compose directly. The port IS the skill: design the site fully as code first, then transform each designed section into a locked Carbon Fields block and reassemble content by script — never by clicking wp-admin.

## When to Use

| Situation | Use this? |
|---|---|
| Client needs a coded site to become content-editable in WP | Yes |
| Blog/article publishing must happen natively in WP | Yes |
| Someone wants a page-BUILDER site (visual redesign freedom) | No — different job |
| Fresh WP site with no existing design source | No — design first (impeccable), then return here |

**The editability contract** (agree with the client before starting): text/images editable via block fields, articles published natively, sections reorderable at the code level. NOT visual redesign — "design locked, unbreakable." Editors = you (full code) + client team (guardrailed).

## Governing Principles

1. **Design-as-code-first.** The full site exists as framework-free HTML/CSS (`design/pages/*.html`) or an equivalent built static site BEFORE any WordPress work. WP wraps a finished design; never the reverse.
2. **Parity-gate everything.** Scripted text+structure comparison of every rendered page against the design source. ALL-MATCH locally before deploy; re-run ON LIVE after. A gate that can't fail is decoration — test it against a deliberately broken fixture.
3. **Diagnose, never guess.** Every failure gets a root cause from logs/source before a fix. Conjecture is bad for business.
4. **Idempotent, scripted migration.** Zero manual wp-admin entry. Every step re-runs safely (proven when Docker died mid-import and nothing was lost).
5. **Tokens generated, never hand-edited.** One canonical token source feeds CSS and theme.json emitters.

## Stage Flow

```
S0 scaffold → S1 context → S2 tokens → **S3 design source — must be FROZEN (tagged + committed build output) before any later stage starts** → S4 section→block
transform → S5 scripted assembly → S6 tech/SEO layer → S7 deploy + live QA
```

Each stage = input artifact → output artifact → completion criterion. Do not start a stage until the prior stage's completion criterion verifiably holds. Details per stage: [references/stage-details.md](references/stage-details.md). Environment preflights that MUST run first: [references/environment.md](references/environment.md). Deploy mechanics: [references/deploy-runbook.md](references/deploy-runbook.md). Known failure modes: [references/pitfalls.md](references/pitfalls.md) — read S0-relevant entries BEFORE scaffolding, not after failures.

## THE EXACT PROMPT — section→block transform (dispatch per batch)

```
You are porting designed HTML sections into Carbon Fields blocks for a classic PHP theme.

Read these files IN FULL:
- <skill>/references/stage-details.md (§ "Section→block transform" — the rules)
- The theme's inc/blocks/blocks.php registry + one existing block file (the exemplar pattern)
- The designed source pages, listed by the orchestrator as ABSOLUTE PATHS. Never proceed from an unspecified location ("the design from earlier" is a forbidden reference — artifacts are the interface).

For EACH designed section:
1. Split content vs structure. Editable = text, images, links, list items. Locked = tags,
   classes, layout, CSS. This split is judgment: bold-leads stay in templates (editors type
   plain text); grid variants derive from ITEM COUNT, not settings flags; internal links are
   select fields of real page slugs, never free-text URLs; global values (phone numbers etc.)
   come from ONE helper function — fields carry only optional overrides.
   BAD: three hard-coded card blocks for a 3-card row. GOOD: one block with a Complex field
   ("N of a thing" = one repeater-style field).
2. Write ONE PHP file per block type in inc/blocks/: Block::make(__('Theme: Name'))
   ->set_category('design')->set_mode('edit')->add_fields([...])->set_render_callback(fn)
   emitting the design markup VERBATIM with field echoes. Rich text ONLY where the audited
   copy has inline markup; everything else text/textarea.
3. Register in blocks.php. Names follow <theme>-<descriptive-slug>.
4. Verify: php -l clean on every file; wp eval loop over WP_Block_Type_Registry confirms all
   registered.

Completion criterion: every designed section has a registered block; every content slot is a
field; php -l zero errors; registry eval lists them all. Report the census (types × instances).
```

## THE EXACT PROMPT — parity gate verdict

```
Run the parity harness against the frozen reference. Report per page:
- TEXT PARITY: normalized visible body text vs reference (normalize NFC, unify quotes/dashes,
  decode entities, collapse whitespace)
- STRUCTURE PARITY: sequence of section classes/elements
- ASSET CHECKS: fonts.css paths resolve, woff2 files 200, no console errors, no 404s
Gate = ALL PAGES MATCH on every axis. Any failure: report page, axis, first divergent element.
Do NOT declare success while any axis is unchecked.
```

## Anti-Patterns

| Don't | Do |
|---|---|
| Log into wp-admin to build pages or set fields | Script everything via `wp eval-file`; admin is for editors only |
| Let editors touch markup via rich_text everywhere | rich_text ONLY where audited copy has inline markup; else text/textarea |
| Compare rendered output against a live rebuild | Freeze the reference (tag + committed dist); compare against the tag forever |
| Reuse a deploy script without path-context checks | Rewrite relative asset paths per destination (fonts.css `../fonts/` → `fonts/`) |
| Trust "capacity confirmed" for shared hosting | Measure real TTFB/LCP from target geographies before cutting DNS |
| Skip the backup because it's "just a staging push" | `wp db export` + tarball wp-content before EVERY host mutation |
| Test forms with curl | LiteSpeed bot-challenge intercepts non-browser POSTs — E2E via real browser only |
| Fix a failed stage by re-running blind | Root-cause from logs first; check the pitfall catalogue; idempotent rerun AFTER diagnosis |

## Output Contract

The skill produces, in the repo:
- `<theme>/` — complete classic PHP theme (style.css header, functions.php with Carbon Fields boot, inc/blocks/*.php one-per-type + registry, templates, assets/tokens.css generated from the token source)
- `tools/import-media.php`, `tools/assemble-pages.php`, `tools/setup-seo.php` (idempotent eval-file scripts)
- extractor script + per-page field-data JSON + media manifest
- verify-parity harness + parity report (ALL PAGES MATCH or explicit failures)
- redirect map CSV (old URL → new URL, imported at deploy)
- deploy log incl. purge/flush verification

## Quick Checklist

- [ ] Environment preflights green (Docker probe, DNS preload, container DNS check)
- [ ] Design source FROZEN (tagged + committed dist) — the gate's immutable reference
- [ ] Editability contract agreed with client in writing
- [ ] Pilot block proven end-to-end before mass build (one representative section, media included)
- [ ] Census reported: block types × instances matches the designed sections exhaustively
- [ ] Parity ALL PAGES MATCH locally — then again ON LIVE post-deploy
- [ ] Backup taken immediately before host mutation
- [ ] Redirect map live + asserted (301s verified)
- [ ] Forms E2E via real browser (stored submission → success state → analytics event)
- [ ] debug.log zero fatals/warnings/notices

## References

| Topic | File |
|---|---|
| Per-stage detail: input→output→completion, transform rules, assembly scripts | [stage-details.md](references/stage-details.md) |
| Windows/Docker/wp-env preflights, verbatim configs, gotchas | [environment.md](references/environment.md) |
| cPanel access chain, deploy sequence, cache flush, verification | [deploy-runbook.md](references/deploy-runbook.md) |
| Failure catalogue: symptom → root cause → fix → prevention | [pitfalls.md](references/pitfalls.md) |
