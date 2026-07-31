#!/usr/bin/env python3
"""li-harvest consumer — normalized JSON -> one markdown file per post (vault corpus style).

Writes <handle>-lipost-<slug>-<date>-<id6>.md per post, with frontmatter + full text.
Default: the profile owner's ORIGINAL posts. --include-reposts also writes reposts.

Usage: python ingest_posts.py --harvest harvest.json --out /vault/posts_dir/ --batch YYYY-MM-DD [--include-reposts]
"""
import argparse, json, io, sys, os, re

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")


def slugify(text, maxlen=55):
    s = re.sub(r"https?://\S+", "", (text or "").lower())
    s = re.sub(r"[^a-z0-9]+", "-", s).strip("-")
    return s[:maxlen].rstrip("-") or "untitled"


def esc(v):
    return "'" + str(v).replace("'", "''") + "'"


def fm(pairs):
    out = ["---"]
    for k, v in pairs:
        if v is None:
            out.append(f"{k}: null")
        elif isinstance(v, bool):
            out.append(f"{k}: {str(v).lower()}")
        elif isinstance(v, (int, float)):
            out.append(f"{k}: {v}")
        else:
            out.append(f"{k}: {esc(v)}")
    out.append("---")
    return "\n".join(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--harvest", required=True)
    ap.add_argument("--out", required=True, help="output directory for post files")
    ap.add_argument("--batch", required=True)
    ap.add_argument("--include-reposts", action="store_true")
    a = ap.parse_args()
    d = json.load(open(a.harvest, encoding="utf-8"))
    handle = d["handle"]
    owner = (d.get("profile") or {}).get("name")
    os.makedirs(a.out, exist_ok=True)

    written = 0
    for p in d.get("posts", []):
        if not p.get("is_own") and not a.include_reposts:
            continue
        aid = p.get("activity_id") or ""
        dt = (p.get("posted_at") or "")[:10]
        if not dt:
            continue
        date8 = dt.replace("-", "")
        kind = "lipost" if p.get("is_own") else "lirepost"
        name = f"{handle}-{kind}-{slugify(p['text'])}-{date8}-{aid[-6:]}.md"
        path = os.path.join(a.out, name)
        if os.path.exists(path):
            continue
        front = fm([
            ("operator", owner or handle), ("handle", handle), ("source", "linkedin"),
            ("source_url", p.get("url")), ("source_id", aid),
            ("date_posted", dt), ("date_ingested", a.batch),
            ("author", p.get("author")), ("is_own", bool(p.get("is_own"))),
            ("reactions", p.get("reactions")), ("comments", p.get("comments")),
            ("reposts", p.get("reposts")),
            ("type", "linkedin-post" if p.get("is_own") else "linkedin-repost"),
            ("refresh_batch", a.batch), ("triage", "pending"),
        ])
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(front + "\n\n" + p["text"] + "\n")
        written += 1

    print(f"wrote {written} post files to {a.out}")


if __name__ == "__main__":
    main()
