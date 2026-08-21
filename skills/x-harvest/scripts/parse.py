#!/usr/bin/env python3
"""x-harvest Stage 3 — parse captured GraphQL payloads into ONE normalized JSON.

Reads ~/.dev-browser/tmp/tsnet_*.json (timeline payloads) + ts_article_*.json
(article full-text), walks the payloads structurally, extracts full-fidelity
tweets/threads/quotes/media, groups self-reply threads, and emits the normalized
artifact every consumer reads. Also reconciles against the DOM inventories and
reports any ids the DOM saw but the network capture missed (the completeness gate).

Usage:
  python parse.py --handle HANDLE --cutoff YYYY-MM-DD --out out.json
                  [--mode account|bookmarks]
                  [--tmp ~/.dev-browser/tmp] [--known-ids known_ids.txt]

The structural walk() survives most of X's re-nesting. If extraction yields far
fewer tweets than the DOM inventory, X reshaped the leaf fields — see
references/graphql-recovery.md § B.
"""
import argparse, glob, io, json, os, sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace", line_buffering=True)

MONTHS = {m: i + 1 for i, m in enumerate(
    ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"])}


def iso(created_at):
    # "Sat May 05 14:31:29 +0000 2026" -> "2026-05-05T14:31:29Z"
    try:
        p = created_at.split()
        return f"{p[5]}-{MONTHS[p[1]]:02d}-{int(p[2]):02d}T{p[3]}Z"
    except Exception:
        return None


def _bad(s):
    return sum(1 for c in s if "\u0080" <= c <= "\u00ff")


def fix_mojibake(t):
    """Repair UTF-8-decoded-as-Latin-1 double-encoding from the capture layer
    (smart quotes -> 'Ã¢...', em-dash, emoji). Round-trips latin-1<->utf-8, and
    accepts a pass ONLY if it strictly reduces high-Latin-1 chars, so genuine
    accented text (cafe with acute e) and already-clean strings are never mangled."""
    if not t:
        return t
    for _ in range(3):
        if not any("\u0080" <= c <= "\u00ff" for c in t):
            break
        try:
            cand = t.encode("latin-1").decode("utf-8")
        except (UnicodeEncodeError, UnicodeDecodeError):
            break
        if _bad(cand) < _bad(t):
            t = cand
        else:
            break
    return t


def walk(node, out):
    """Collect every tweet node (rest_id + legacy.created_at) anywhere in the tree."""
    if isinstance(node, dict):
        if ("rest_id" in node and isinstance(node.get("legacy"), dict)
                and "created_at" in node["legacy"]):
            out.append(node)
        for v in node.values():
            walk(v, out)
    elif isinstance(node, list):
        for v in node:
            walk(v, out)


def screen_name(core):
    return ((core.get("legacy", {}) or {}).get("screen_name")
            or (core.get("core", {}) or {}).get("screen_name") or "")


def extract(t):
    """Leaf field paths — the fragile part. See graphql-recovery.md § B if X reshapes these."""
    leg = t["legacy"]
    core = t.get("core", {}).get("user_results", {}).get("result", {})
    note = t.get("note_tweet", {}).get("note_tweet_results", {}).get("result", {}).get("text")
    art = t.get("article", {}).get("article_results", {}).get("result", {})
    quoted = t.get("quoted_status_result", {}).get("result", {})
    if quoted.get("__typename") == "TweetWithVisibilityResults":
        quoted = quoted.get("tweet", {})
    q = None
    if quoted.get("rest_id"):
        qleg = quoted.get("legacy", {})
        qnote = quoted.get("note_tweet", {}).get("note_tweet_results", {}).get("result", {}).get("text")
        qcore = quoted.get("core", {}).get("user_results", {}).get("result", {})
        q = {"id": quoted["rest_id"], "author": screen_name(qcore),
             "text": fix_mojibake(qnote or qleg.get("full_text", ""))}
    media = []
    for m in ((leg.get("extended_entities", {}) or {}).get("media", [])
              or (leg.get("entities", {}) or {}).get("media", []) or []):
        media.append({"type": m.get("type"), "url": m.get("media_url_https")})
    return {
        "id": t["rest_id"],
        "author": screen_name(core),
        "dt": iso(leg["created_at"]),
        "text": fix_mojibake(note or leg.get("full_text", "")),
        "is_note": bool(note),
        "is_article": bool(art),
        "article_title": art.get("title"),
        "reply_to_id": leg.get("in_reply_to_status_id_str"),
        "reply_to_user": leg.get("in_reply_to_screen_name"),
        "conversation_id": leg.get("conversation_id_str"),
        "quoted": q,
        "media": [m["url"] for m in media if m.get("url")],
        "retweeted": "retweeted_status_result" in t or leg.get("full_text", "").startswith("RT @"),
    }


def _first(*vals):
    for v in vals:
        if v not in (None, ""):
            return v
    return None


def walk_users(node, out):
    """Collect User result nodes (__typename == 'User' with a rest_id)."""
    if isinstance(node, dict):
        if node.get("__typename") == "User" and "rest_id" in node:
            out.append(node)
        for v in node.values():
            walk_users(v, out)
    elif isinstance(node, list):
        for v in node:
            walk_users(v, out)


def extract_profile(u):
    """Pull the profile from a UserByScreenName/UserByRestId node. Field homes have
    migrated between legacy/core/avatar/location/verification — check all. See
    graphql-recovery.md § B if these come back empty."""
    leg = u.get("legacy", {}) or {}
    core = u.get("core", {}) or {}
    av = u.get("avatar", {}) or {}
    loc = u.get("location", {}) or {}
    ver = u.get("verification", {}) or {}
    prof = u.get("professional", {}) or {}
    ent = leg.get("entities", {}) or {}
    bio_urls = [x.get("expanded_url") for x in (ent.get("description", {}) or {}).get("urls", []) if x.get("expanded_url")]
    site_urls = [x.get("expanded_url") for x in (ent.get("url", {}) or {}).get("urls", []) if x.get("expanded_url")]
    return {
        "id": u.get("rest_id"),
        "name": fix_mojibake(_first(core.get("name"), leg.get("name")) or ""),
        "handle": _first(core.get("screen_name"), leg.get("screen_name")),
        "bio": fix_mojibake(leg.get("description", "") or ""),
        "bio_links": bio_urls,
        "website": _first(site_urls[0] if site_urls else None, leg.get("url")),
        "location": _first((loc.get("location") if isinstance(loc, dict) else None), leg.get("location")),
        "followers": leg.get("followers_count"),
        "following": leg.get("friends_count"),
        "tweets": leg.get("statuses_count"),
        "likes": leg.get("favourites_count"),
        "joined": iso(_first(core.get("created_at"), leg.get("created_at")) or ""),
        "verified": bool(_first(u.get("is_blue_verified"), ver.get("verified"), leg.get("verified"))),
        "professional_type": prof.get("professional_type"),
        "professional_category": [c.get("name") for c in (prof.get("category") or []) if c.get("name")],
        "pinned_tweet_id": (leg.get("pinned_tweet_ids_str") or [None])[0],
        "avatar_url": _first((av.get("image_url") if isinstance(av, dict) else None), leg.get("profile_image_url_https")),
        "banner_url": leg.get("profile_banner_url"),
    }


def load_profile(tmp, handle):
    """First User node matching the handle, from any tsuser_*.json (else None)."""
    for f in sorted(glob.glob(os.path.join(tmp, "tsuser_*.json"))):
        try:
            d = json.load(open(f, encoding="utf-8"))
        except Exception as e:
            print(f"WARN user {os.path.basename(f)}: {e}")
            continue
        users = []
        walk_users(d, users)
        for u in users:
            p = extract_profile(u)
            if (p.get("handle") or "").lower() == handle:
                return p
        if users:  # fallback: first user node if none matched the handle exactly
            return extract_profile(users[0])
    return None


def load_dom_ids(tmp):
    """Every id the DOM passes saw — the completeness baseline."""
    ids = {}
    for pat in ("ts_slice*.json", "ts_profile.json", "ts_profile_dom2.json", "ts_bm_dom.json"):
        for f in glob.glob(os.path.join(tmp, pat)):
            try:
                for t in json.load(open(f, encoding="utf-8")):
                    if isinstance(t, dict) and t.get("id"):
                        ids[t["id"]] = t.get("dt")
            except Exception as e:
                print(f"WARN dom {os.path.basename(f)}: {e}")
    return ids


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--handle", required=True, help="account handle, no @ (operator id for bookmarks)")
    ap.add_argument("--cutoff", default=None, help="oldest date to keep, YYYY-MM-DD (required for --mode account)")
    ap.add_argument("--mode", choices=("account", "bookmarks"), default="account")
    ap.add_argument("--out", required=True, help="normalized JSON output path")
    ap.add_argument("--tmp", default=os.path.expanduser("~/.dev-browser/tmp"))
    ap.add_argument("--known-ids", default=None, help="ids to skip (incremental refresh)")
    a = ap.parse_args()
    handle = a.handle.lower().lstrip("@")
    bookmarks = a.mode == "bookmarks"
    if not bookmarks and not a.cutoff:
        ap.error("--cutoff is required unless --mode bookmarks")
    cutoff = a.cutoff or "1970-01-01"

    tweets = {}
    payloads = sorted(glob.glob(os.path.join(a.tmp, "tsnet_*.json")))
    for f in payloads:
        try:
            data = json.load(open(f, encoding="utf-8"))
        except Exception as e:
            print(f"WARN unparseable {os.path.basename(f)}: {e}")
            continue
        found = []
        walk(data, found)
        for t in found:
            try:
                e = extract(t)
            except Exception:
                continue
            if e["id"] not in tweets:
                tweets[e["id"]] = e
    print(f"payloads: {len(payloads)} | unique tweet objects: {len(tweets)}")

    if bookmarks:
        own = {i: t for i, t in tweets.items() if not t["retweeted"]}
    else:
        own = {i: t for i, t in tweets.items() if t["author"].lower() == handle and not t["retweeted"]}
    inwin = {i: t for i, t in own.items() if t["dt"] and t["dt"][:10] >= cutoff}
    print(f"{'bookmarks' if bookmarks else 'own'} non-RT: {len(own)} | in window (>= {cutoff}): {len(inwin)}")

    known = set()
    if a.known_ids and os.path.exists(a.known_ids):
        known = set(open(a.known_ids, encoding="utf-8").read().split())
    fresh = {i: t for i, t in inwin.items() if i not in known}
    print(f"fresh vs known_ids: {len(fresh)}")

    # thread grouping: self-replies under their conversation root
    continuations = {}
    for t in fresh.values():
        same = (t["reply_to_user"] or "").lower() == (t["author"] or "").lower() if bookmarks else (t["reply_to_user"] or "").lower() == handle
        if t["reply_to_id"] and same:
            continuations.setdefault(t["conversation_id"], []).append(t["id"])

    units = []
    used = set()
    for i, t in fresh.items():
        fold = (t["reply_to_user"] or "").lower() == (t["author"] or "").lower() if bookmarks else (t["reply_to_user"] or "").lower() == handle
        if i in used or (t["reply_to_id"] and fold):
            continue  # continuations are folded into their root
        chain_ids = [i] + [c for c in continuations.get(t["conversation_id"] or "", []) if c != i and c in inwin]
        chain = sorted((inwin[c] for c in chain_ids), key=lambda x: x["dt"] or "")
        for c in chain:
            used.add(c["id"])
        media = [m for c in chain for m in c["media"]]
        quoted = next((c["quoted"] for c in chain if c["quoted"]), None)
        units.append({
            "kind": "thread" if len(chain) > 1 else "tweet",
            "root_id": i, "dt": t["dt"], "author": t["author"], "text": t["text"],
            "tweet_ids": [c["id"] for c in chain],
            "tweets": [{"id": c["id"], "dt": c["dt"], "text": c["text"]} for c in chain],
            "quoted": quoted, "media": media,
        })
    units.sort(key=lambda u: u["dt"] or "")

    # articles (captured separately in ts_article_*.json)
    articles = []
    for f in sorted(glob.glob(os.path.join(a.tmp, "ts_article_*.json"))):
        try:
            art = json.load(open(f, encoding="utf-8"))
        except Exception:
            continue
        if art.get("id") in known:
            continue
        title = (art.get("listTxt", "").split("Article", 1)[-1].strip()
                 or art.get("title") or "")
        articles.append({"id": art["id"], "dt": art.get("dt"), "title": fix_mojibake(title[:120]),
                         "text": fix_mojibake(art.get("text", "")), "images": art.get("imgs", art.get("images", []))[:40],
                         "listTxt": art.get("listTxt", "")})

    # completeness reconciliation
    dom = load_dom_ids(a.tmp)
    net_ids = set(inwin.keys())
    dom_inwin = {i for i, dt in dom.items() if not dt or dt[:10] >= cutoff}
    missing = sorted(dom_inwin - net_ids - known)
    net_only = sorted(net_ids - set(dom.keys()))
    print(f"COMPLETENESS: net_ids={len(net_ids)} dom_ids(in-win)={len(dom_inwin)} "
          f"missing_from_net={len(missing)} net_only={len(net_only)}")
    if missing:
        print("  !! DOM saw these but network capture missed them — scroll further / re-run pass 3:")
        for mid in missing[:20]:
            print("     ", mid)

    profile = load_profile(a.tmp, handle)
    if profile:
        print(f"profile: @{profile['handle']} | {profile['followers']} followers | "
              f"joined {profile['joined'][:10] if profile['joined'] else '?'}")
    else:
        print("profile: none captured (no tsuser_*.json — add UserByScreenName to the pass-3 listener)")

    out = {
        "handle": handle, "mode": a.mode, "cutoff": None if bookmarks and not a.cutoff else cutoff,
        "profile": profile,
        "counts": {"units": len(units), "articles": len(articles),
                   "threads": sum(1 for u in units if u["kind"] == "thread")},
        "completeness": {"net_ids": len(net_ids), "dom_ids_in_window": len(dom_inwin),
                         "missing_from_net": missing, "net_only": net_only},
        "units": units, "articles": articles,
    }
    os.makedirs(os.path.dirname(os.path.abspath(a.out)) or ".", exist_ok=True)
    json.dump(out, open(a.out, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    verdict = "SUPERSET OK" if not missing else f"{len(missing)} MISSING — re-scroll before consuming"
    print(f"wrote {a.out} | units={len(units)} articles={len(articles)} | {verdict}")


if __name__ == "__main__":
    main()
