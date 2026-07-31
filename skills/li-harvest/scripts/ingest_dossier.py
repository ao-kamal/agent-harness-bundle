#!/usr/bin/env python3
"""li-harvest Stage 4 (reference consumer) — normalized JSON -> vault markdown dossier.

Writes one <handle>-linkedin.md: profile + experience + education + skills + posts.
Other consumers (CSV, a prospect digest) read the same normalized JSON.

Usage: python ingest_dossier.py --harvest harvest.json --out /vault/dir/ --batch YYYY-MM-DD
"""
import argparse, json, io, sys, os

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")


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
    ap.add_argument("--out", required=True, help="output directory")
    ap.add_argument("--batch", required=True)
    a = ap.parse_args()
    d = json.load(open(a.harvest, encoding="utf-8"))
    p = d.get("profile", {})
    os.makedirs(a.out, exist_ok=True)

    b = [fm([
        ("handle", d["handle"]), ("source", "linkedin"),
        ("source_url", f"https://www.linkedin.com/in/{d['handle']}/"),
        ("name", p.get("name")), ("headline", p.get("headline")),
        ("location", p.get("location")), ("followers", p.get("followers")),
        ("connections", p.get("connections")), ("date_harvested", a.batch),
        ("type", "linkedin-dossier"), ("triage", "pending"),
    ])]
    b.append(f"\n# {p.get('name') or d['handle']}")
    if p.get("headline"):
        b.append(f"\n*{p['headline']}*")
    meta = " · ".join(x for x in [p.get("location"),
                                  f"{p['followers']} followers" if p.get("followers") else None,
                                  f"{p['connections']} connections" if p.get("connections") else None] if x)
    if meta:
        b.append(f"\n{meta}")
    if p.get("about"):
        b.append(f"\n## About\n\n{p['about']}")

    if d.get("experience"):
        b.append("\n## Experience")
        for e in d["experience"]:
            head = f"### {e['title']}"
            if e.get("org"):
                head += f" — {e['org']}"
            if e.get("employment_type"):
                head += f" ({e['employment_type']})"
            b.append("\n" + head)
            line = " · ".join(x for x in [e.get("date_range"), e.get("duration"),
                                          e.get("location"), e.get("work_mode")] if x)
            if line:
                b.append(line)
            if e.get("description"):
                b.append(f"\n{e['description']}")
            if e.get("skills"):
                b.append(f"\n*{e['skills']}*")

    if d.get("education"):
        b.append("\n## Education")
        for e in d["education"]:
            b.append(f"\n### {e['title']}")
            degree = e.get("degree_field") or e.get("org")
            line = " · ".join(x for x in [degree, e.get("date_range"), e.get("duration")] if x)
            if line:
                b.append(line)
            if e.get("description"):
                b.append(f"\n{e['description']}")

    if d.get("skills"):
        b.append("\n## Skills\n")
        b.extend(f"- {s}" for s in d["skills"])

    # Posts are written as individual files by ingest_posts.py; the dossier only summarizes.
    posts = d.get("posts", [])
    own = [x for x in posts if x.get("is_own")]
    reposts = [x for x in posts if not x.get("is_own")]
    if posts:
        dates = sorted(p["posted_at"][:10] for p in own if p.get("posted_at"))
        span = f"{dates[0]} → {dates[-1]}" if dates else "n/a"
        b.append("\n## Posts")
        b.append(f"\n**{len(own)} original posts** ({span}) and {len(reposts)} reposts. "
                 f"Each original post is its own file (`type: linkedin-post`) in the posts folder — "
                 f"this dossier stays a single readable profile.")

    name = f"{d['handle']}-linkedin.md"
    open(os.path.join(a.out, name), "w", encoding="utf-8", newline="\n").write("\n".join(b) + "\n")
    print(f"wrote {name} | exp={len(d.get('experience',[]))} edu={len(d.get('education',[]))} "
          f"skills={len(d.get('skills',[]))} own_posts={len(own)} reposts={len(reposts)}")


if __name__ == "__main__":
    main()
