#!/usr/bin/env python3
"""li-harvest Stage 3 — assemble captured LinkedIn data into ONE normalized JSON.

LinkedIn's Voyager component-JSON is near-unparseable, but two sources are clean:
  - PROFILE SECTIONS (experience/education/skills/about): the rendered DOM innerText
    of each /details/ page, segmented by the date-range anchor line.
  - POSTS: the /voyager/api/…feed Update entities captured off the network.

Inputs (in --dir, produced by the capture stage):
  li_profile_dom.txt        profile main innerText (name, headline, location, followers, about)
  li_experience_dom.txt     /details/experience/ innerText
  li_education_dom.txt       /details/education/ innerText
  li_skills_dom.txt          /details/skills/ innerText   (optional)
  livoy_posts_*.json         recent-activity feed payloads (Update entities)

Usage: python parse.py --handle <publicId> --dir <capture_dir> --out out.json
"""
import argparse, json, io, sys, os, re, glob, datetime

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace", line_buffering=True)
D = chr(36)

DATE_RE = re.compile(r'^(?:[A-Z][a-z]{2} )?\d{4}\s*[-–]\s*(?:Present|(?:[A-Z][a-z]{2} )?\d{4})(?:\s*·\s*.+)?$')
MODE_RE = re.compile(r'·\s*(On-site|Remote|Hybrid)\s*$')
STOP = ("More profiles", "About\n", "Accessibility", "Talent Solutions",
        "LinkedIn Corporation", "People also viewed", "Show all")


# ---------- mojibake repair (emoji-safe: fixes latin-1 runs, passes high codepoints through) ----------
def _bad(s):
    return sum(1 for c in s if "\u0080" <= c <= "\u00ff")


def fix_mojibake(t):
    if not t or not any("\u0080" <= c <= "\u00ff" for c in t):
        return t
    out, buf = [], bytearray()

    def flush():
        if buf:
            try:
                out.append(buf.decode("utf-8"))
            except UnicodeDecodeError:
                out.append(buf.decode("latin-1"))
            del buf[:]

    for c in t:
        if c <= "\u00ff":
            buf.append(ord(c))
        else:
            flush()
            out.append(c)
    flush()
    fixed = "".join(out)
    return fixed if _bad(fixed) < _bad(t) else t


# ---------- section parser (experience / education / skills-style rows) ----------
def clean_lines(text):
    return [ln.strip() for ln in (text or "").split("\n") if ln.strip()]


def parse_entries(text, kind):
    lines = clean_lines(text)
    date_idx = [i for i, l in enumerate(lines) if DATE_RE.match(l)]
    out = []
    for n, di in enumerate(date_idx):
        if di < 2:
            continue
        title = lines[di - 2]
        org, _, extra = lines[di - 1].partition(" · ")
        date_range, _, duration = lines[di].partition(" · ")
        end = (date_idx[n + 1] - 2) if n + 1 < len(date_idx) else len(lines)
        location = work_mode = skills = None
        desc = []
        for e in lines[di + 1:end]:
            if at_boundary(e):
                break
            m = MODE_RE.search(e)
            if location is None and (m or (len(e) < 55 and ("," in e or "Nigeria" in e))):
                if m:
                    location, work_mode = e[:m.start()].rstrip(" ·"), m.group(1)
                else:
                    location = e
                continue
            if "skills" in e.lower() and ("+" in e or e.lower().rstrip().endswith("skills")):
                skills = e.strip()
                continue
            desc.append(fix_mojibake(e))
        row = {"title": fix_mojibake(title), "org": fix_mojibake(org),
               "date_range": date_range.strip(), "duration": duration.strip() or None,
               "location": location, "work_mode": work_mode,
               "description": " ".join(desc) or None, "skills": skills,
               ("employment_type" if kind == "experience" else "degree_field"): extra.strip() or None}
        out.append(row)
    return out


SKILL_CATS = {"Skills", "All", "Industry Knowledge", "Tools & Technologies",
              "Interpersonal Skills", "Show all", "Show more", "Languages", "Interests", "Other"}

# LinkedIn's global page footer — everything from here down is chrome, not content.
FOOTER = {"About", "Accessibility", "Talent Solutions", "Community Guidelines", "Careers",
          "Marketing Solutions", "Privacy & Terms", "Ad Choices", "Advertising",
          "Sales Solutions", "Mobile", "Small Business", "Safety Center", "Questions?",
          "Visit our Help Center.", "Manage your account and privacy", "Go to your Settings.",
          "Recommendation transparency", "Learn more about Recommended Content.",
          "Select language", "LinkedIn Corporation © 2026"}


def at_boundary(line):
    return line in FOOTER or any(line.startswith(s.rstrip("\n")) for s in STOP)


def parse_skills(text):
    lines = clean_lines(text)
    out = []
    for l in lines:
        if at_boundary(l):          # footer / recommendations reached — section is over
            break
        if l in SKILL_CATS:
            continue
        if " at " in l or re.match(r'^\d+\s+endorsement', l) or "·" in l or DATE_RE.match(l):
            continue
        # drop language-list rows like "Español (Spanish)" and non-latin script lines
        if re.match(r'^[^\x00-\x7f].*\(.+\)$', l) or re.match(r'^[A-Za-z]+ \([A-Za-z ]+\)$', l):
            continue
        if 2 < len(l) < 70:
            out.append(fix_mojibake(l))
    seen, uniq = set(), []
    for s in out:
        if s not in seen:
            seen.add(s)
            uniq.append(s)
    return uniq[:80]


SECTION_HEADS = ("Experience", "Education", "Featured", "Activity", "Skills",
                 "Licenses & certifications", "Interests", "Recommendations",
                 "Honors & awards", "Volunteering", "Publications", "Languages")


def parse_profile_dom(text):
    lines = clean_lines(text)
    prof = {"name": None, "headline": None, "location": None, "followers": None,
            "connections": None, "about": None}
    if not lines:
        return prof
    prof["name"] = fix_mojibake(lines[0])
    # headline: first substantive line after name — skip the "· Nth" degree, counts, org·school line
    for l in lines[1:6]:
        if l.startswith("·") or l in ("Contact info", "·") or " · " in l:
            continue
        if "connection" in l.lower() or "follower" in l.lower():
            continue
        prof["headline"] = fix_mojibake(l)
        break
    # location: the real line just before "Contact info"
    if "Contact info" in lines:
        ci = lines.index("Contact info")
        for j in range(ci - 1, max(ci - 4, -1), -1):
            if lines[j].strip() not in ("·", ""):
                prof["location"] = lines[j]
                break
    # followers / connections (either "3K\nfollowers" split lines or inline)
    for i, l in enumerate(lines[:16]):
        if l == "connections" and i:
            prof["connections"] = lines[i - 1]
        if l == "followers" and i:
            prof["followers"] = lines[i - 1]
        m = re.search(r'([\d,.]+K?)\s+followers', l)
        if m:
            prof["followers"] = m.group(1)
        m2 = re.search(r'([\d,.+]+)\s+connections', l)
        if m2:
            prof["connections"] = m2.group(1)
    # about: everything under the About header until the next section
    if "About" in lines:
        i = lines.index("About")
        blk = []
        for l in lines[i + 1:i + 40]:
            if l in SECTION_HEADS or l.startswith("More profiles"):
                break
            blk.append(l)
        prof["about"] = fix_mojibake("\n".join(blk)) or None
    return prof


# ---------- posts (feed Update entities) ----------
def _text_of(node):
    if isinstance(node, str):
        return node
    if isinstance(node, dict):
        t = node.get("text")
        return t.get("text") if isinstance(t, dict) else t
    return None


def activity_ts(urn):
    # LinkedIn activity IDs are snowflake-like: the high bits are Unix ms directly.
    m = re.search(r'activity:(\d{18,19})', urn or "")
    if not m:
        return None
    ms = int(m.group(1)) >> 22
    try:
        return datetime.datetime.fromtimestamp(ms / 1000, datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    except Exception:
        return None


def parse_posts(dir_, target_name):
    posts, seen = [], set()
    for f in sorted(glob.glob(os.path.join(dir_, "livoy_posts_*.json"))) + sorted(glob.glob(os.path.join(dir_, "livoy2_*.json"))):
        try:
            d = json.load(open(f, encoding="utf-8"))
        except Exception:
            continue
        inc = d.get("included", []) if isinstance(d, dict) else []
        counts = {}
        for x in inc:
            if isinstance(x, dict) and x.get(D + "type", "").endswith("SocialActivityCounts"):
                aid = re.search(r'activity:(\d+)', x.get("entityUrn", ""))
                if aid:
                    counts[aid.group(1)] = x
        for u in inc:
            if not (isinstance(u, dict) and u.get(D + "type", "").endswith("Update")):
                continue
            urn = u.get("entityUrn") or u.get(D) or ""
            aid = re.search(r'activity:(\d+)', urn)
            aid = aid.group(1) if aid else None
            if not aid or aid in seen:
                continue
            text = _text_of(u.get("commentary"))
            if not text:
                continue
            seen.add(aid)
            actor = u.get("actor", {}) if isinstance(u.get("actor"), dict) else {}
            aname = _text_of(actor.get("name"))
            c = counts.get(aid, {})
            reactions = c.get("numLikes") or c.get("reactionTypeCounts")
            if isinstance(reactions, list):
                reactions = sum(r.get("count", 0) for r in reactions)
            posts.append({
                "activity_id": aid,
                "url": f"https://www.linkedin.com/feed/update/urn:li:activity:{aid}/",
                "author": fix_mojibake(aname or ""),
                "is_own": bool(aname and target_name and aname.strip().lower() == target_name.strip().lower()),
                "posted_at": activity_ts(urn),
                "text": fix_mojibake(text),
                "reactions": reactions,
                "comments": c.get("numComments"),
                "reposts": c.get("numShares"),
            })
    posts.sort(key=lambda p: p["posted_at"] or "", reverse=True)
    return posts


def read(d, name):
    p = os.path.join(d, name)
    return open(p, encoding="utf-8").read() if os.path.exists(p) else ""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--handle", required=True)
    ap.add_argument("--dir", required=True, help="capture directory")
    ap.add_argument("--out", required=True)
    a = ap.parse_args()

    profile = parse_profile_dom(read(a.dir, "li_profile_dom.txt"))
    experience = parse_entries(read(a.dir, "li_experience_dom.txt"), "experience")
    education = parse_entries(read(a.dir, "li_education_dom.txt"), "education")
    skills = parse_skills(read(a.dir, "li_skills_dom.txt"))
    posts = parse_posts(a.dir, profile.get("name"))
    own = [p for p in posts if p["is_own"]]

    out = {
        "handle": a.handle,
        "profile": profile,
        "experience": experience,
        "education": education,
        "skills": skills,
        "posts": posts,
        "counts": {"experience": len(experience), "education": len(education),
                   "skills": len(skills), "posts": len(posts), "own_posts": len(own)},
    }
    os.makedirs(os.path.dirname(os.path.abspath(a.out)) or ".", exist_ok=True)
    json.dump(out, open(a.out, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    print(f"wrote {a.out} | exp={len(experience)} edu={len(education)} skills={len(skills)} "
          f"posts={len(posts)} (own={len(own)}) | name={profile.get('name')!r}")


if __name__ == "__main__":
    main()
