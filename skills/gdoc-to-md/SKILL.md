---
name: gdoc-to-md
description: >-
  Convert Google Docs to Markdown via the /mobilebasic endpoint — no browser,
  no Playwright. Works on docs where copy / download / print is disabled by
  the owner (the standard /export?format=html endpoint returns 403 in that
  case; /mobilebasic still serves rendered HTML). Pulls Google auth cookies
  from your logged-in browser via browser_cookie3, with a manual cookies.txt
  fallback. Hoists images out of heading tags (markdownify drops them),
  retries transient image-fetch failures, optional lossless oxipng
  compression. Auto-decides per doc whether to embed images as base64
  data URIs (light docs) or write to an images/ subfolder (heavy docs);
  threshold configurable, decision surfaced. --embed / --folder force
  either mode.

  Use this skill when the user asks to "convert google doc to markdown",
  "scrape google doc", "extract google doc text", "download google doc as
  markdown", "save google doc as md", "gdoc to markdown", or specifically
  mentions a Google Doc with copy / download / print disabled.
---

> **Core insight:** Google Docs that disable copy/download still serve their full rendered HTML at `/mobilebasic`. The path here is HTTP + cookies + a small parser, not browser automation.

# gdoc-to-md

Convert Google Doc URLs to Markdown via `/mobilebasic`. Single Python script, no Playwright, no Chromium, no Selenium. Handles copy-disabled docs because `/mobilebasic` doesn't gate on the "disable downloading/printing/copying" sharing setting (only `/export` does).

The script lives at `~/.claude/skills/gdoc-to-md/scripts/gdoc_to_md.py`. It is the contract — read it before customizing behavior.

---

## Quick start

```bash
# 1. Install deps under Python 3.13 (pyoxipng has no 3.14 prebuilt wheel)
py -3.13 -m pip install browser-cookie3 requests beautifulsoup4 markdownify pyoxipng

# 2. Run on one or more docs (URLs or raw IDs both accepted)
py -3.13 ~/.claude/skills/gdoc-to-md/scripts/gdoc_to_md.py \
  https://docs.google.com/document/d/1b6Tx6gpO2NX.../edit \
  --out ./gdocs
# default = auto: light docs embed inline, heavy docs go to images/ subfolder
# add --embed or --folder to force either, --threshold-mb N to tune the cutoff
```

If `browser_cookie3` can read your browser's cookies, you're done. If not — see the cookie bootstrap below.

---

## When this is the right tool

| Don't use this | Use this |
|---|---|
| Public doc that allows download — `curl /export?format=html` works without cookies | Doc requires auth OR has copy/download/print disabled |
| You need fully-faithful Google Docs comments / suggestions | Body text + images is enough |
| You need a docx round-trip | You want clean Markdown for indexing or LLM context |

---

## CLI surface

```
python gdoc_to_md.py <id-or-url> [<id-or-url>...] [options]
python gdoc_to_md.py --urls-file urls.txt [options]
```

Accepts raw doc IDs OR full URLs (with `?tab=...&heading=...` etc — the regex extracts the ID). Use `--urls-file` for bulk lists; `#` and blank lines are ignored.

| Flag | Default | Effect |
|---|---|---|
| `--out DIR` | `./gdocs` | Output root. Each doc gets `<slug>/index.md` under this. |
| `--auto` | (default) | Per-doc, decide embed-vs-folder by total compressed image bytes vs `--threshold-mb`. Decision printed: `[auto] N imgs, X.XX MB compressed (threshold Y.Y MB) -> {embed,folder}` |
| `--embed` | | Force single self-contained `.md` per doc; images inlined as base64 data URIs |
| `--folder` | | Force `.md` + `images/img-NN.<ext>` subfolder per doc; relative refs |
| `--threshold-mb FLOAT` | `2.0` | Auto-mode cutoff. ≥ threshold → folder, < threshold → embed. Tune for your editor / Obsidian preferences. |
| `--no-compress` | | Skip lossless oxipng compression (compressed by default, 20-30% smaller, pixel-identical) |
| `--cookies-file PATH` | | Path to a Mozilla-format cookies.txt — fallback when `browser_cookie3` can't read your browser |
| `--browser NAME` | (auto) | Force `chrome` / `firefox` / `edge` / `brave` — overrides auto-detect |
| `--user-agent UA` | desktop Chrome | UA header for both doc and image fetches |

Exit codes: `0` clean, `1` per-doc errors (others may have succeeded), `2` argparse / no-input.

---

## Cookie bootstrap (when `browser_cookie3` fails)

`browser_cookie3` reads cookies straight from your browser's local storage. It works on Firefox always, on Chrome/Edge/Brave on most platforms, but **fails on Chrome 127+ on Windows** which uses app-bound encryption that no pure-pip Python lib bypasses today (rookiepy attempts it but its install needs a working Rust toolchain — usually not worth the friction).

**Manual cookie export — the practical path on Windows + Chrome 127+:**

1. Install **Get cookies.txt LOCALLY** (open-source, runs entirely in-browser, no cloud transmission):
   `https://chromewebstore.google.com/detail/get-cookiestxt-locally/cclelndahbckbenkjhflpdbgdldlbecc`
2. While logged into the Google account that has view-access to the docs, click the extension icon on any `docs.google.com` page → **Export As → Mozilla cookies.txt** → save to e.g. `~/cookies.txt`
3. Pass it via `--cookies-file ~/cookies.txt`

The exported cookies (`SID`, `HSID`, `SSID`, `SAPISID`, `APISID`, plus `__Secure-*` variants) have **~2-year expiry** and stay valid as long as you don't log out, don't switch accounts, and Google doesn't force a re-auth. **Re-export only when you start seeing "access denied" or HTTP 401/403** — usually months between re-exports.

---

## How images are handled

1. **Fetched with the same auth cookie session** — cookie-protected `googleusercontent.com` URLs work
2. **Retry-with-backoff** (3 retries, 0.5s → 1s → 2s) — Google CDN drops connections under burst
3. **Lossless oxipng** at level 6 (`StripChunks.safe()`, no interlacing) — pixel-identical, ~20-30% smaller
4. **Hoisted out of heading tags** before markdownify runs — markdownify silently drops `<img>` inside `<h1>`-`<h6>`, which is exactly where Google Docs places section banners. Empty heading shells are dropped after
5. **Auto mode picks embed vs folder** based on total compressed image bytes vs `--threshold-mb` (default 2 MB) — light docs stay self-contained, heavy docs go to disk. Decision is surfaced per doc; explicit `--embed`/`--folder` overrides
6. **Embed** uses `data:image/png;base64,...` URIs (Obsidian renders these natively); **folder** uses `images/img-NN.png` with relative refs
7. **Deduplicated** — same image referenced multiple times in the doc is fetched once, all refs share the same target
8. **Stripped of noisy attrs** (`srcset`, `width`, `height`, `style`, `class`) for clean markdown

---

## THE EXACT PROMPT — typical run

After install + cookies bootstrapped:

```bash
py -3.13 ~/.claude/skills/gdoc-to-md/scripts/gdoc_to_md.py \
  "https://docs.google.com/document/d/<DOC_ID>/edit" \
  --out ./gdocs \
  --cookies-file ~/cookies.txt
```

Output: `./gdocs/<slug-of-title>/index.md`. Auto mode prints e.g. `[auto] 14 imgs, 2.30 MB compressed (threshold 2.0 MB) -> folder` then writes `index.md` + `images/`. For a light doc you'd see `... 0.18 MB ... -> embed` and a single self-contained `index.md`. Frontmatter includes `gdoc_id` and `gdoc_url` for provenance.

To force one mode regardless of doc weight, add `--embed` or `--folder`. To tune the auto cutoff, add `--threshold-mb 5` (or whatever).

Bulk run from a list:

```bash
# urls.txt — one URL or ID per line, # for comments
py -3.13 ~/.claude/skills/gdoc-to-md/scripts/gdoc_to_md.py \
  --urls-file urls.txt --out ./gdocs --cookies-file ~/cookies.txt
```

---

## Failure modes and what they mean

| Error | Cause | Fix |
|---|---|---|
| `HTTP 404` from `/mobilebasic` | Bad doc ID, or doc deleted | Verify URL |
| `redirected to login at ...` | Cookies missing or expired entirely | Re-export cookies.txt while logged into the account that has access |
| `access denied. Cookies don't have view permission for this doc.` | Cookies are valid but lack view-rights for this specific doc | Switch to an account that has access; re-export |
| `image: failed after 4 attempts` | Google rate-limited the IP, or the image URL went stale during the run | Re-run; first-pass dedupe + retries usually clear it |
| `no .doc-content found in HTML` | `/mobilebasic` returned a non-doc page (sign-in HTML wasn't caught) | Likely cookies missing — re-export and retry |
| `Could not extract doc ID from: ...` | Input wasn't a recognizable Google Docs URL or ID | Check input — IDs are 10+ chars `[A-Za-z0-9_-]` |
| `Unable to get key for cookie decryption` | Chrome 127+ Windows app-bound encryption | Use `--cookies-file` (see bootstrap above) |
| `Couldn't read cookies file ...` | Malformed or unreadable cookies.txt | Re-export the file; ensure Mozilla format |
| `Missing dependency: pyoxipng` | Wrong Python version | Use `py -3.13` not `py -3.14`; pyoxipng has no 3.14 wheel |

---

## Anti-patterns

| Don't | Do |
|---|---|
| Try Playwright / Selenium / dev-browser first | Try `/mobilebasic` + cookies first — 30 lines of HTTP beats a browser dependency |
| Use `/export?format=html` on copy-disabled docs | It returns 403. `/mobilebasic` doesn't. |
| Run under Python 3.14 expecting pyoxipng | Use `py -3.13`; 3.14 has no prebuilt wheel and source build needs Rust |
| Embed images without compression on huge docs | Compression is on by default; only pass `--no-compress` if oxipng isn't installed |
| Skip the heading-image hoist | You'll silently lose ~1 image per doc. Banner images live inside `<h2>`. |
| Fetch images without retries | Google CDN drops connections under burst — first fetch fails, retry succeeds |
| Commit cookies.txt to git | It's auth credentials. Add to `.gitignore` |

---

## Tested as of 2026-05-08

Unit and integration tests passed for: argparse, doc-ID extraction (URLs with anchors / raw IDs / bad input), cookies-file fallback, auto/embed/folder modes (15/15 images each, single 2.85 MB file or .md + images/), `--no-compress` (2.8 MB raw vs 2.2 MB compressed, label switches to "uncompressed" in auto-decision string), bad doc ID error path (404 captured, exit=1, summary still emitted), `--urls-file` parsing, slug-collision protection (slug suffixed with `-{doc_id[:8]}`), stale-file cleanup on re-run (orphan `img-NN.<ext>` files removed; folder→embed switch removes `images/` entirely), title escaping (`*` `_` `` ` `` `<` `>` `[` `]` properly escaped in H1), MIME from server content-type, sign-in redirect detection, body-content equivalence vs a Playwright-based reference run.
