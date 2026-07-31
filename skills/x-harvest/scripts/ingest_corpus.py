#!/usr/bin/env python3
"""x-harvest Stage 4 (reference consumer) — normalized harvest JSON -> Obsidian corpus.

Reads the parse.py output and writes one markdown file per unit/article, with
frontmatter, the <operator>-{tw|thr|art}-slug-date-id.md filename convention,
thread concatenation, quoted/media sections, and known_ids incremental dedup.
Schema: references/corpus-schema.md. Other output formats = a different consumer
reading the SAME harvest JSON; do not re-scrape.

Usage:
  python ingest_corpus.py --harvest HANDLE-harvest-DATE.json --operator HANDLE
                          --corpus /path/to/vault/corpus/ --batch YYYY-MM-DD
                          [--known-ids known_ids.txt] [--dry-run]
"""
import argparse, io, json, os, re, sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace", line_buffering=True)


def slugify(text, maxlen=55):
    s = re.sub(r"https?://\S+", "", (text or "").lower())
    s = re.sub(r"[^a-z0-9]+", "-", s).strip("-")
    return s[:maxlen].rstrip("-") or "untitled"


def esc(v):
    return "'" + str(v).replace("'", "''") + "'"


def fm(pairs):
    lines = ["---"]
    for k, v in pairs:
        if v is None:
            lines.append(f"{k}: null")
        elif isinstance(v, bool):
            lines.append(f"{k}: {str(v).lower()}")
        elif isinstance(v, (int, float)):
            lines.append(f"{k}: {v}")
        elif isinstance(v, list):
            if not v:
                lines.append(f"{k}: []")
            else:
                lines.append(f"{k}:")
                lines.extend(f"- {esc(i)}" for i in v)
        else:
            lines.append(f"{k}: {esc(v)}")
    lines.append("---")
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--harvest", required=True, help="parse.py normalized JSON")
    ap.add_argument("--operator", required=True, help="account handle for frontmatter")
    ap.add_argument("--corpus", required=True, help="output corpus directory")
    ap.add_argument("--batch", required=True, help="ingest/refresh batch date YYYY-MM-DD")
    ap.add_argument("--known-ids", default=None, help="ids to skip + append newly written")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()

    data = json.load(open(a.harvest, encoding="utf-8"))
    op = a.operator.lower().lstrip("@")
    os.makedirs(a.corpus, exist_ok=True)
    known = set()
    if a.known_ids and os.path.exists(a.known_ids):
        known = set(open(a.known_ids, encoding="utf-8").read().split())

    written, skipped = [], 0

    def write(name, content, new_id):
        nonlocal skipped
        path = os.path.join(a.corpus, name)
        if os.path.exists(path) or new_id in known:
            skipped += 1
            return
        if a.dry_run:
            print("would write:", name)
        else:
            with open(path, "w", encoding="utf-8", newline="\n") as f:
                f.write(content)
        written.append(new_id)

    for u in data["units"]:
        rid, dt = u["root_id"], (u["dt"] or "")
        if not dt:
            continue
        kind = "thr" if u["kind"] == "thread" else "tw"
        typ = "thread" if kind == "thr" else "tweet"
        date8 = dt[:10].replace("-", "")
        media = u.get("media", [])
        # media-only single tweet
        if kind == "tw" and not (u["text"] or "").strip() and media:
            typ, kind = "tweet-media-only", "tw"
        name = f"{op}-{kind}-{slugify(u['text'])}-{date8}-{rid[-6:]}.md"
        front = fm([
            ("operator", op), ("source", "twitter"),
            ("source_url", f"https://x.com/{op}/status/{rid}"),
            ("source_id", rid), ("date_posted", dt[:10]), ("date_ingested", a.batch),
            ("is_reply", False), ("contains_image", bool(media)), ("images", media),
            ("thread_tweet_ids", u["tweet_ids"] if len(u["tweet_ids"]) > 1 else []),
            ("quoted_tweet_id", u["quoted"]["id"] if u.get("quoted") else None),
            ("language", "en"), ("type", typ),
            ("refresh_batch", a.batch), ("triage", "pending"),
        ])
        body = []
        for idx, c in enumerate(u["tweets"]):
            if idx > 0:
                body.append(f"\n---\n*(thread continuation {idx+1}/{len(u['tweets'])} — id {c['id']}, {c['dt']})*\n")
            body.append(c["text"])
        if not (u["text"] or "").strip() and typ == "tweet-media-only":
            body = ["*(no text — image post)*"]
        if u.get("quoted"):
            q = u["quoted"]
            body.append(f"\n\n## Quoted tweet (@{q['author']}, id {q['id']})\n\n{q['text']}")
        if media:
            body.append("\n\n## Media\n" + "\n".join(f"- {m}" for m in media))
        write(name, front + "\n\n" + "\n".join(body) + "\n", rid)

    for art in data.get("articles", []):
        aid, dt = art["id"], (art.get("dt") or "")
        if not dt:
            continue
        date8 = dt[:10].replace("-", "")
        title = art.get("title") or (art.get("listTxt", "")[:60])
        name = f"{op}-art-{slugify(title)}-{date8}-{aid[-6:]}.md"
        imgs = art.get("images", [])
        front = fm([
            ("operator", op), ("source", "twitter-article"),
            ("source_url", f"https://x.com/{op}/status/{aid}"),
            ("source_id", aid), ("date_posted", dt[:10]), ("date_ingested", a.batch),
            ("title", title[:120]), ("capture_note", "innerText of article view; images listed below"),
            ("images", imgs[:40]), ("language", "en"), ("type", "article"),
            ("refresh_batch", a.batch), ("triage", "pending"),
        ])
        body = (art.get("text") or "").strip()
        if imgs:
            body += "\n\n## Article images\n" + "\n".join(f"- {m}" for m in imgs[:40])
        write(name, front + "\n\n" + body + "\n", aid)

    # profile: current-state, so it OVERWRITES on refresh (unlike immutable posts)
    p = data.get("profile")
    if p and p.get("handle"):
        front = fm([
            ("operator", op), ("source", "twitter-profile"),
            ("source_url", f"https://x.com/{op}"), ("source_id", p.get("id")),
            ("date_ingested", a.batch), ("display_name", p.get("name")),
            ("followers", p.get("followers")), ("following", p.get("following")),
            ("tweet_count", p.get("tweets")), ("joined", (p.get("joined") or "")[:10] or None),
            ("location", p.get("location")), ("website", p.get("website")),
            ("verified", p.get("verified")),
            ("professional_type", p.get("professional_type")),
            ("professional_category", p.get("professional_category") or []),
            ("pinned_tweet_id", p.get("pinned_tweet_id")),
            ("language", "en"), ("type", "profile"),
            ("refresh_batch", a.batch), ("triage", "pending"),
        ])
        body = (p.get("bio") or "").strip() or "*(no bio)*"
        if p.get("bio_links"):
            body += "\n\n## Bio links\n" + "\n".join(f"- {u}" for u in p["bio_links"])
        name = f"{op}-profile.md"
        if a.dry_run:
            print("would write:", name)
        else:
            with open(os.path.join(a.corpus, name), "w", encoding="utf-8", newline="\n") as f:
                f.write(front + "\n\n" + body + "\n")
            print("wrote profile:", name)

    if a.known_ids and not a.dry_run and written:
        with open(a.known_ids, "a", encoding="utf-8") as f:
            f.write("\n".join(written) + "\n")

    print(f"INGESTED: wrote={len(written)} skipped_existing={skipped} "
          f"units={len(data['units'])} articles={len(data.get('articles', []))}"
          + (" (dry-run)" if a.dry_run else ""))


if __name__ == "__main__":
    main()
