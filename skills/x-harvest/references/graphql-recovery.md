# GraphQL recovery — when X renames its operations

X periodically renames its GraphQL operations and reshapes the response JSON. When that happens the capture writes nothing (`netChunks:0` while tweets clearly render) or `parse.py` extracts far fewer tweets than the DOM inventory saw. This is the skill's expected failure mode — the fix is re-discovery, not a rewrite.

## Symptom → which layer broke

| Symptom | Broke | Fix |
|---|---|---|
| `netChunks:0`, tweets on screen | the **operation-name regex** (listener never matched) | § A below |
| `netChunks` healthy, but `parse.py` finds ~0 tweets | the **field paths** in `extract()` | § B below |
| Some tweets parsed, threads/quotes/media missing | one specific field path | § B, targeted |

## A — Re-discover the operation names

Dump every GraphQL URL X actually calls while the timeline loads, then read the operation names out of the paths:

```bash
dev-browser --timeout 120 <<'EOF'
const page = await browser.getPage("xharvest");
const ops = new Set();
page.on("response", (res) => { const m = res.url().match(/graphql\/[^\/]+\/([A-Za-z0-9]+)/); if (m) ops.add(m[1]); });
await page.goto("https://x.com/{{HANDLE}}", { waitUntil: "commit", timeout: 45000 }).catch(()=>{});
for (let i = 0; i < 8; i++) { await page.waitForTimeout(2000); await page.mouse.wheel(0, 2000); }
console.log(JSON.stringify([...ops].sort()));
EOF
```

Look for the timeline operations — historically `UserTweets`, `UserTweetsAndReplies`, `SearchTimeline`, `TweetDetail` — and the **profile** operation, historically `UserByScreenName` (or `UserByRestId`), which fires once on the profile `goto`. Whatever the current names are, update the regex in **both** `references/capture-scripts.md` (surface 3) and the listener snippet in `SKILL.md`:

```js
if (!/graphql\/[^\/]+\/(NewName1|NewName2|SearchTimeline|TweetDetail)/.test(res.url())) return;
```

Re-run the capture. Confirm `tsnet_*.json` files now appear.

## B — Re-discover the field paths

If payloads capture but `parse.py` finds nothing, X reshaped the tweet object. Inspect one payload and find the current path to a tweet node (a `rest_id` + `legacy.created_at` object) and the fields:

```bash
python - <<'PY'
import json, glob, os
f = sorted(glob.glob(os.path.expanduser("~/.dev-browser/tmp/tsnet_*.json")))[0]
d = json.load(open(f, encoding="utf-8"))
def find(node, path=""):
    if isinstance(node, dict):
        if "rest_id" in node and isinstance(node.get("legacy"), dict) and "created_at" in node["legacy"]:
            print("TWEET NODE at", path or "<root>")
            print("  legacy keys:", sorted(node["legacy"])[:20])
            print("  has note_tweet:", "note_tweet" in node, "| quoted_status_result:", "quoted_status_result" in node, "| article:", "article" in node)
            return True
        for k, v in node.items():
            if find(v, f"{path}.{k}"): return True
    elif isinstance(node, list):
        for i, v in enumerate(node):
            if find(v, f"{path}[{i}]"): return True
    return False
find(d)
PY
```

`parse.py`'s `walk()` finds tweet nodes **structurally** (any `rest_id`+`legacy` dict, anywhere), so it survives most re-nesting automatically — that's deliberate. What breaks are the specific extractions in `extract()`:

| Field | Current path in `extract()` |
|---|---|
| full long text | `note_tweet.note_tweet_results.result.text` |
| plain text | `legacy.full_text` |
| author handle | `core.user_results.result.legacy.screen_name` (or `.core.screen_name`) |
| quoted tweet | `quoted_status_result.result` (unwrap `TweetWithVisibilityResults` → `.tweet`) |
| media | `legacy.extended_entities.media[]` → `.media_url_https` |
| thread linkage | `legacy.in_reply_to_status_id_str`, `legacy.conversation_id_str` |
| article flag | `article.article_results.result` |

Profile fields (in the `UserByScreenName` node, `__typename == "User"`) have migrated between `legacy`, `core`, `avatar`, `location`, and `verification` — `extract_profile()` already checks all of them with fallbacks. If a profile field comes back empty, print the User node's `legacy`/`core` keys with the § B probe and add the new home to the `_first(...)` chain:

| Field | Paths checked |
|---|---|
| name / handle | `core.name`/`legacy.name`, `core.screen_name`/`legacy.screen_name` |
| bio + links | `legacy.description`, `legacy.entities.description.urls[].expanded_url` |
| metrics | `legacy.followers_count` / `friends_count` / `statuses_count` |
| joined | `core.created_at` / `legacy.created_at` |
| verified | `verification.verified` / `legacy.verified` |
| pinned / avatar / banner | `legacy.pinned_tweet_ids_str[0]`, `avatar.image_url`/`legacy.profile_image_url_https`, `legacy.profile_banner_url` |

Compare each against the payload's current shape (use the probe above, printing the keys of a node), patch the path in `scripts/parse.py`'s `extract()`, re-run. Keep the structural `walk()` untouched — only the leaf paths move.

## Principle

The skill hardcodes exactly two fragile things: the operation-name regex (§A) and the leaf field paths (§B). Both are re-discoverable in minutes with the probes above. Never hand-scrape the DOM as a substitute — you lose `note_tweet`, threads, quotes, and media, and the completeness reconciliation with it.
