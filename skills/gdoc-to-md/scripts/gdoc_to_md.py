#!/usr/bin/env python3
"""
gdoc_to_md.py — Convert Google Docs to Markdown via /mobilebasic.

No browser, no Playwright. Pulls Google auth cookies straight from your
logged-in Chrome / Firefox / Edge (via browser_cookie3) or from a manual
cookies.txt fallback. Hits /mobilebasic to get the rendered HTML, parses
with BeautifulSoup, hoists images out of heading tags so markdownify
doesn't drop them, fetches each image with the same cookie session,
optionally lossless-compresses with oxipng, and emits one of:

    - auto mode (DEFAULT): per-doc, decide embed-vs-folder based on
      total compressed image bytes against --threshold-mb. The decision
      is printed for each doc.
    - --embed: force single self-contained .md per doc with images
      inlined as base64 data URIs.
    - --folder: force .md plus images/ subfolder per doc.

SETUP (one-time):
    pip install browser-cookie3 requests beautifulsoup4 markdownify pyoxipng

USAGE:
    python gdoc_to_md.py <id-or-url> [<id-or-url>...] [options]
    python gdoc_to_md.py --urls-file urls.txt [options]

EXAMPLES:
    # single doc, default auto mode
    python gdoc_to_md.py 1b6Tx6gpO2NX... --out ./gdocs

    # auto mode with a custom threshold (default 2.0 MB)
    python gdoc_to_md.py URL --out ./gdocs --threshold-mb 5

    # explicitly force folder mode for everything
    python gdoc_to_md.py URL1 URL2 --out ./gdocs --folder --no-compress

    # bulk from URL list, with a manually-exported cookies.txt
    python gdoc_to_md.py --urls-file urls.txt --out ./gdocs \\
        --cookies-file cookies.txt --embed

LIMITATIONS:
    - The doc must be viewable by the cookie-owning Google account. If the
      "disable downloading/printing/copying" setting is on, /mobilebasic
      still works but /export does not. (This script uses /mobilebasic.)
    - Chrome 127+ on Windows uses app-bound cookie encryption that can break
      browser_cookie3. Fallbacks: read Firefox cookies (--browser firefox),
      or export cookies to a file via a "Get cookies.txt" extension and
      pass --cookies-file.
"""

from __future__ import annotations

import argparse
import base64
import json
import re
import sys
import time
from http import cookiejar
from pathlib import Path

try:
    import requests
    from bs4 import BeautifulSoup
    from markdownify import markdownify
except ImportError as e:
    sys.exit(
        f"Missing dependency: {e.name}. "
        "Run: pip install browser-cookie3 requests beautifulsoup4 markdownify pyoxipng"
    )

DEFAULT_UA = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/130.0 Safari/537.36"
)
DOC_ID_RE = re.compile(r"/document/d/([a-zA-Z0-9_-]+)")
HEADING_TAGS = ("h1", "h2", "h3", "h4", "h5", "h6")
ACCESS_DENIED_MARKERS = (
    "You need access",
    "Request access",
    'class="docs-deniedaccess"',
)
SIGNIN_REDIRECT_MARKERS = (
    "accounts.google.com",
    "/ServiceLogin",
    "signin/identifier",
)
# Files we wrote ourselves into <slug>/images/. Used for stale-file cleanup
# without nuking anything the user dropped in there.
OUR_IMAGE_RE = re.compile(r"^img-\d+\.[a-zA-Z0-9]+$")


def extract_doc_id(s: str) -> str:
    s = s.strip()
    m = DOC_ID_RE.search(s)
    if m:
        return m.group(1)
    if re.fullmatch(r"[A-Za-z0-9_-]{10,}", s):
        return s
    raise ValueError(f"Could not extract doc ID from: {s!r}")


def slugify(text: str, maxlen: int = 60) -> str:
    text = text.lower()
    text = re.sub(r"[™®©]", "", text)  # tm, registered, copyright
    text = re.sub(r"[^a-z0-9]+", "-", text)
    text = re.sub(r"-+", "-", text).strip("-")
    if len(text) > maxlen:
        text = text[:maxlen].rstrip("-")
    return text or "untitled"


def ext_from_ct(ct: str) -> str:
    ct = (ct or "").lower().split(";")[0].strip()
    return {
        "image/png": "png",
        "image/jpeg": "jpg",
        "image/jpg": "jpg",
        "image/webp": "webp",
        "image/gif": "gif",
        "image/svg+xml": "svg",
    }.get(ct, "png")


def mime_from_ct(ct: str) -> str:
    """Normalize a server-sent Content-Type to a clean image/* MIME for data URIs.
    Falls back to image/png for anything that isn't an image/* response."""
    mime = (ct or "").split(";")[0].strip().lower()
    return mime if mime.startswith("image/") else "image/png"


def _escape_md_heading(s: str) -> str:
    """Escape markdown emphasis chars in heading text so a doc title containing
    e.g. '*important*' doesn't render as italic in the H1."""
    return re.sub(r"([*_`\[\]<>])", r"\\\1", s)


def _retryable_get(
    sess: requests.Session,
    url: str,
    *,
    retries: int = 3,
    what: str = "resource",
) -> requests.Response:
    """Shared retry-with-backoff for both doc and image fetches. Retries on
    transient network errors and 429/5xx. Raises immediately on other non-200s."""
    last_err: Exception | None = None
    for attempt in range(retries + 1):
        try:
            r = sess.get(url, timeout=30)
            if r.status_code == 200:
                return r
            if r.status_code in (429, 500, 502, 503, 504):
                last_err = RuntimeError(f"HTTP {r.status_code}")
            else:
                raise RuntimeError(f"{what}: HTTP {r.status_code}")
        except (requests.ConnectionError, requests.Timeout) as e:
            last_err = e
        if attempt < retries:
            time.sleep(0.5 * (2 ** attempt))  # 0.5s, 1s, 2s
    raise RuntimeError(f"{what}: failed after {retries + 1} attempts: {last_err}")


def build_session(ua: str, cookies_file: str | None, browser_pref: str | None) -> requests.Session:
    sess = requests.Session()
    sess.headers["User-Agent"] = ua

    if cookies_file:
        cj = cookiejar.MozillaCookieJar(cookies_file)
        try:
            cj.load(ignore_discard=True, ignore_expires=True)
        except Exception as e:
            sys.exit(f"Couldn't read cookies file {cookies_file}: {e}")
        sess.cookies = cj
        return sess

    try:
        import browser_cookie3
    except ImportError:
        sys.exit("browser_cookie3 not installed. Install it OR pass --cookies-file.")

    candidates = [browser_pref] if browser_pref else ["chrome", "firefox", "edge", "brave"]
    last_err: str | None = None
    for name in candidates:
        fn = getattr(browser_cookie3, name, None)
        if fn is None:
            continue
        try:
            cj = fn(domain_name=".google.com")
            count = sum(1 for _ in cj)
            if count > 0:
                print(f"[cookies] loaded {count} cookies from {name}", file=sys.stderr)
                sess.cookies = cj
                return sess
            last_err = f"{name}: jar has no Google cookies"
        except Exception as e:
            last_err = f"{name}: {e}"
            continue

    sys.exit(
        "Couldn't extract Google cookies from any browser. "
        f"Last error: {last_err}. "
        "Try --cookies-file with a manually-exported cookies.txt."
    )


def fetch_doc(sess: requests.Session, doc_id: str) -> tuple[str, str]:
    url = f"https://docs.google.com/document/d/{doc_id}/mobilebasic"
    r = _retryable_get(sess, url, what=f"doc {doc_id}")
    # If cookies are missing entirely, Google redirects to a sign-in page
    # that returns HTTP 200 with no .doc-content. Detect via final URL.
    if any(marker in r.url for marker in SIGNIN_REDIRECT_MARKERS):
        raise RuntimeError(
            f"{doc_id}: redirected to login at {r.url}. "
            "Cookies missing or expired — re-export cookies.txt and retry."
        )
    if any(marker in r.text for marker in ACCESS_DENIED_MARKERS):
        raise RuntimeError(
            f"{doc_id}: access denied. Cookies don't have view permission for this doc."
        )
    return r.text, url


def fetch_image(sess: requests.Session, url: str) -> tuple[bytes, str]:
    """Fetch an image with retry-on-transient-error. Google's CDN drops connections
    under rapid sequential fetches; the shared retry helper resolves it cleanly."""
    r = _retryable_get(sess, url, what="image")
    return r.content, r.headers.get("content-type", "image/png")


def hoist_images_from_headings(content_root, soup) -> None:
    """Hoist <img>s out of heading ancestors so markdownify doesn't drop them."""
    for img in list(content_root.find_all("img")):
        ancestor = None
        for a in img.parents:
            if getattr(a, "name", None) in HEADING_TAGS:
                ancestor = a
                break
            if a is content_root:
                break
        if ancestor is None:
            continue
        new_p = soup.new_tag("p")
        img.extract()
        new_p.append(img)
        ancestor.insert_before(new_p)
    for h in list(content_root.find_all(HEADING_TAGS)):
        if not h.get_text(strip=True) and not h.find("img"):
            h.decompose()


def maybe_oxipng(img_bytes: bytes, compress: bool) -> bytes:
    if not compress:
        return img_bytes
    try:
        import oxipng
    except ImportError:
        return img_bytes
    try:
        return oxipng.optimize_from_memory(
            img_bytes,
            level=6,
            strip=oxipng.StripChunks.safe(),
            interlace=oxipng.Interlacing.Off,
        )
    except Exception:
        return img_bytes


def convert_doc(
    sess: requests.Session,
    doc_id: str,
    out_root: Path,
    mode: str,           # "auto" | "embed" | "folder"
    compress: bool,
    threshold_mb: float = 2.0,
) -> dict:
    html, doc_url = fetch_doc(sess, doc_id)
    soup = BeautifulSoup(html, "html.parser")
    raw_title = soup.title.get_text() if soup.title else "untitled"
    title = raw_title.replace(" - Google Docs", "").strip() or "untitled"
    # Slug includes a doc-id hash suffix to prevent silent overwrite when two
    # docs share the same title (or slugify to the same string).
    slug = f"{slugify(title)}-{doc_id[:8]}"
    content = soup.select_one("div.doc-content")
    if content is None:
        raise RuntimeError(f"{doc_id}: no .doc-content found in HTML")

    out_dir = out_root / slug
    out_dir.mkdir(parents=True, exist_ok=True)

    # Pass 1 — fetch + compress all images, buffer in memory.
    # We don't know the embed-vs-folder decision yet (in auto mode); we need totals first.
    img_buffer: dict[str, tuple[bytes, str, str]] = {}  # src -> (data, ext, mime)
    failed_srcs: set[str] = set()                        # already-tried-and-failed srcs
    first_seen: dict[str, int] = {}                      # src -> first occurrence position (for filename)
    img_seq: list[tuple[object, str]] = []               # pass-2 work queue
    img_count = 0
    failed: list[tuple[int, str]] = []

    for img in content.find_all("img"):
        img_count += 1
        src = img.get("src", "")
        if not src or src.startswith("data:"):
            continue
        if src not in first_seen:
            first_seen[src] = img_count
        img_seq.append((img, src))
        if src in img_buffer or src in failed_srcs:
            continue  # already processed this URL once
        try:
            data, ct = fetch_image(sess, src)
        except Exception as e:
            failed.append((img_count, str(e)[:120]))
            failed_srcs.add(src)
            continue
        data = maybe_oxipng(data, compress=compress)
        img_buffer[src] = (data, ext_from_ct(ct), mime_from_ct(ct))

    fetched = len(img_buffer)
    attempts = fetched + len(failed_srcs)
    total_bytes = sum(len(d) for d, _, _ in img_buffer.values())

    # Decide mode if auto.
    auto_decision: str | None = None
    if mode == "auto":
        threshold_bytes = int(threshold_mb * 1024 * 1024)
        chosen_mode = "folder" if total_bytes >= threshold_bytes else "embed"
        size_label = "compressed" if compress else "uncompressed"
        auto_decision = (
            f"[auto] {fetched} imgs, {total_bytes / 1024 / 1024:.2f} MB {size_label} "
            f"(threshold {threshold_mb} MB) -> {chosen_mode}"
        )
    else:
        chosen_mode = mode

    # Stale-file cleanup. Remove only files we wrote in a prior run (matching
    # OUR_IMAGE_RE); leave anything the user dropped in there alone.
    img_dir = out_dir / "images"
    if img_dir.exists():
        for f in list(img_dir.iterdir()):
            if f.is_file() and OUR_IMAGE_RE.match(f.name):
                try:
                    f.unlink()
                except OSError:
                    pass
        try:
            img_dir.rmdir()  # only succeeds if now empty
        except OSError:
            pass
    if chosen_mode == "folder":
        img_dir.mkdir(parents=True, exist_ok=True)

    # Pass 2 — emit per chosen mode.
    seen_written: dict[str, str] = {}
    for img, src in img_seq:
        # Strip noisy attrs unconditionally so a failed-fetch broken-link <img>
        # doesn't carry srcset/width/height/style/class noise into the markdown.
        for attr in ("srcset", "width", "height", "style", "class"):
            if img.has_attr(attr):
                del img[attr]
        entry = img_buffer.get(src)
        if entry is None:
            continue  # fetch failed; leave original src so the user sees the broken link
        if src in seen_written:
            img["src"] = seen_written[src]
            continue
        data, ext, mime = entry
        if chosen_mode == "folder":
            idx = first_seen[src]
            fname = f"img-{idx:02d}.{ext}"
            (img_dir / fname).write_bytes(data)
            target = f"images/{fname}"
        else:
            b64 = base64.b64encode(data).decode("ascii")
            target = f"data:{mime};base64,{b64}"
        img["src"] = target
        seen_written[src] = target

    hoist_images_from_headings(content, soup)

    md_body = markdownify(
        str(content),
        heading_style="ATX",
        bullets="-",
        strip=["script", "style"],
    )
    md_body = re.sub(r"\n{3,}", "\n\n", md_body).strip()

    front = (
        "---\n"
        f"created: {time.strftime('%Y-%m-%d')}\n"
        "source: gdoc-to-md\n"
        "type: reference\n"
        f"gdoc_id: {doc_id}\n"
        f"gdoc_url: {doc_url}\n"
        "---\n\n"
        f"# {_escape_md_heading(title)}\n\n"
    )
    md_path = out_dir / "index.md"
    md_path.write_text(front + md_body + "\n", encoding="utf-8")

    return {
        "doc_id": doc_id,
        "title": title,
        "slug": slug,
        "out": str(md_path),
        "imgs_in_html": img_count,
        "imgs_attempts": attempts,
        "imgs_fetched": fetched,
        "imgs_failed": failed,
        "md_bytes": md_path.stat().st_size,
        "mode": chosen_mode,
        "auto_decision": auto_decision,
        "img_total_bytes": total_bytes,
    }


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    ap = argparse.ArgumentParser(
        prog="gdoc_to_md",
        description="Convert Google Docs to Markdown via /mobilebasic (no browser, no Playwright).",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""\
SETUP (one-time):
    pip install browser-cookie3 requests beautifulsoup4 markdownify pyoxipng

EXAMPLES:
    %(prog)s 1b6Tx6gpO2NX... --out ./gdocs            # auto (default)
    %(prog)s URL --out ./gdocs --threshold-mb 5       # auto with bigger threshold
    %(prog)s URL1 URL2 --out ./gdocs --folder         # force folder for all
    %(prog)s --urls-file urls.txt --out ./gdocs --cookies-file cookies.txt
""",
    )
    ap.add_argument("ids", nargs="*", help="Doc IDs or full Google Docs URLs")
    ap.add_argument("--urls-file", help="File with one doc URL or ID per line (# for comments)")
    ap.add_argument("--out", default="gdocs", help="Output root directory (default: ./gdocs)")
    g = ap.add_mutually_exclusive_group()
    g.add_argument(
        "--auto",
        action="store_const", dest="mode", const="auto",
        help="Decide embed vs folder per-doc based on total compressed image bytes vs --threshold-mb (default)",
    )
    g.add_argument(
        "--embed",
        action="store_const", dest="mode", const="embed",
        help="Force single self-contained .md per doc with images inlined as base64",
    )
    g.add_argument(
        "--folder",
        action="store_const", dest="mode", const="folder",
        help="Force .md plus images/ subfolder per doc",
    )
    ap.set_defaults(mode="auto")
    ap.add_argument(
        "--threshold-mb", type=float, default=2.0,
        help="Auto-mode threshold for embed-vs-folder, in MB of total compressed image bytes (default: 2.0)",
    )
    ap.add_argument("--no-compress", action="store_true", help="Skip lossless oxipng compression")
    ap.add_argument("--cookies-file", help="Path to cookies.txt (Mozilla format) — fallback when browser_cookie3 fails")
    ap.add_argument("--browser", choices=["chrome", "firefox", "edge", "brave"], help="Force browser_cookie3 to read this browser's cookies")
    ap.add_argument("--user-agent", default=DEFAULT_UA)
    return ap.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)

    ids = list(args.ids)
    if args.urls_file:
        with open(args.urls_file, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#"):
                    ids.append(line)
    if not ids:
        print("error: provide at least one doc ID/URL or --urls-file", file=sys.stderr)
        return 2
    try:
        ids = [extract_doc_id(s) for s in ids]
    except ValueError as e:
        print(f"error: {e}", file=sys.stderr)
        return 2

    sess = build_session(args.user_agent, args.cookies_file, args.browser)
    out_root = Path(args.out)
    out_root.mkdir(parents=True, exist_ok=True)

    results: list[dict] = []
    rc = 0
    for did in ids:
        print(f"[{did}] fetching...", flush=True)
        try:
            r = convert_doc(
                sess, did, out_root,
                mode=args.mode,
                compress=not args.no_compress,
                threshold_mb=args.threshold_mb,
            )
        except Exception as e:
            print(f"  ERROR: {e}", flush=True)
            results.append({"doc_id": did, "error": str(e)})
            rc = 1
            continue
        if r.get("auto_decision"):
            print(f"  {r['auto_decision']}", flush=True)
        kb = r["md_bytes"] // 1024
        attempts = r.get("imgs_attempts", r.get("imgs_in_html", 0))
        status = f"{r['imgs_fetched']}/{attempts} imgs"
        if r["imgs_failed"]:
            status += f", {len(r['imgs_failed'])} failed"
        print(f"  -> {r['out']} ({status}, {kb}K)", flush=True)
        if r["imgs_failed"]:
            print(f"     WARN failed: {r['imgs_failed']}", flush=True)
        results.append(r)

    print()
    print("=== SUMMARY (json) ===")
    print(json.dumps(results, indent=2, default=str))
    return rc


if __name__ == "__main__":
    sys.exit(main())
