---
name: x-harvest
description: Harvest a public X (Twitter) account's full post history, or the logged-in user's Bookmarks, via network-layer GraphQL capture into normalized JSON, with an optional Obsidian-vault corpus writer. Operator-driven (manual login). Invoke with /x-harvest.
disable-model-invocation: true
---

# x-harvest

> **Core insight:** X's own frontend receives every tweet as a GraphQL JSON payload. Capture *those* — not the DOM — and virtualization can't hide rows, long text isn't truncated, and threads/quotes/media arrive structured. The DOM is only a scroll motor and a completeness check.

Harvest any public X account — or the operator's **Bookmarks** — into a **normalized JSON** artifact (the universal output), then optionally render it to an Obsidian-vault markdown corpus (one consumer). Account harvest proven on a 253-post reference corpus. Bookmarks harvest proven on a 165-item logged-in corpus (GraphQL op `Bookmarks`, History → Bookmarks tab).

**Platform:** dev-browser must run **headful** (X login needs a real window). On Windows call `dev-browser` directly; from WSL call the Windows `.exe`. Depends on the **dev-browser** skill — load it if you haven't.

**Use only on your own logged-in session, for personal research.** This reads X's responses to *you*; it is not a redistribution tool.

---

## The pipeline — four stages

```
[1] LOGIN GATE   operator logs in manually (once, persistent page)
[2] CAPTURE      account: 4 surfaces → ~/.dev-browser/tmp/{tsnet_*, ts_slice*, ts_profile*, ts_article_*}.json
                 bookmarks: 1 surface → ~/.dev-browser/tmp/{tsnet_*, ts_bm_dom.json}
[3] PARSE        parse.py [--mode account|bookmarks] → <handle>-harvest-<date>.json  (+ completeness report)
[4] CONSUME      ingest_corpus.py [--mode account|bookmarks] → vault markdown   (optional)
```

Stage 2 is the craft. Stages 3-4 are deterministic scripts (`scripts/`). Everything writes to `~/.dev-browser/tmp/` (dev-browser's only writable dir) until parse pulls it out.

---

## Stage 1 — the login gate (interactive, once)

X is unusable logged-out. The session lives on a **persistent named page** (`xharvest`) so login survives across every capture call.

```bash
dev-browser --timeout 90 <<'EOF'
const page = await browser.getPage("xharvest");
await page.setViewportSize({ width: 1280, height: 900 });
await page.goto("https://x.com/home", { waitUntil: "commit", timeout: 60000 }).catch(()=>{});
await page.waitForTimeout(4000);
const walled = await page.evaluate(() =>
  !!document.querySelector('[data-testid="loginButton"]') ||
  document.body.innerText.includes("Sign in to X"));
console.log(JSON.stringify({ url: page.url(), loggedIn: !walled }));
EOF
```

If `loggedIn:false`, **stop and tell the operator to log in manually** in the headful window, then wait for their confirmation before Stage 2. Never script credentials — there is no secret-injection primitive, and typing a password lands it in the transcript. Reuse this page; do not re-navigate to login once in.

**Windows Chrome 151+ attach (bookmarks, or when Chrome-for-Testing is login-limited):** `--remote-debugging-port` is ignored on the *default* profile. Chrome-for-Testing often hits “We've temporarily limited your login.” Do **not** script a password into that window. Two working paths:

1. Operator enables `chrome://inspect/#remote-debugging` in the Chrome they are already logged into, then `dev-browser --connect` (no URL). Named pages do **not** persist across `--connect` invocations — keep Stage 2 in **one** script, or `listPages()` each time.
2. Copy the logged-in profile into a *non-default* `--user-data-dir`, launch `chrome.exe --user-data-dir=<copy> --remote-debugging-port=9222 --remote-allow-origins=*`, then `dev-browser --connect http://127.0.0.1:9222`. Cookie copies into a fresh dir often drop the X session — if the copy is walled, the operator logs in *in that attached window*.

Do not combine `--connect` with the `run` subcommand (the flag swallows it). Pipe the script or use a here-string. QuickJS teardown may exit 1 or 4 *after* stdout — treat the summary line + `tsnet_*.json` as success.

---

## Stage 2 — capture the surfaces

**Never trust one surface.** On the reference harvest, search found 76, profile-scroll found 191, and the Articles tab held 25 long-form pieces *neither* showed. Completeness is a **superset** of all four, cross-checked. Run all of them; the parse stage reconciles.

Full, ready-to-fill scripts (substitute `{{HANDLE}}`, `{{SINCE}}`, `{{UNTIL}}`, `{{CUTOFF}}`): **`references/capture-scripts.md`**. The order:

1. **Search slices** — `from:{{HANDLE}} since: until: -filter:replies&f=live`, date-sliced (~monthly) so no slice exceeds the scroll ceiling. DOM inventory of ids.
2. **Profile scroll** — the timeline back to `{{CUTOFF}}`. DOM inventory; catches what search drops.
3. **Profile scroll + network listener** ← **the load-bearing pass** (below). DOM scroll *drives* the GraphQL loads; the listener captures the full-fidelity payloads.
4. **Articles** — the `/articles` tab list, then each article's full rich-text (Articles never appear in tweet payloads).

**Bookmarks (logged-in operator only, skip 1–4):** one network pass on the Bookmarks tab. Current UI: `https://x.com/i/bookmarks` lands on `https://x.com/i/history` with the **Bookmarks** tab selected (next to Likes). GraphQL op (2026-08): `Bookmarks`. Capture script is surface **5** in `references/capture-scripts.md`. DOM inventory = every `article[data-testid="tweet"]` (other people's posts — do **not** filter to a handle). Write `ts_bm_dom.json`. Then `parse.py --mode bookmarks` (does not drop non-handle tweets).

### The network pass — THE technique

DOM-scroll to force X to fetch, and catch every timeline payload on the wire. Register the listener **before** navigating:

```js
let chunk = 0, userChunk = 0;
page.on("response", async (res) => {
  try {
    if (res.status() !== 200) return;
    const u = res.url();
    if (/graphql\/[^\/]+\/(UserByScreenName|UserByRestId)/.test(u)) {   // the profile/bio payload
      await writeFile("tsuser_" + String(++userChunk).padStart(3, "0") + ".json", await res.text()); return;
    }
    if (!/graphql\/[^\/]+\/(UserOriginalsTimeline|UserTweets|UserTweetsAndReplies|SearchTimeline|TweetDetail|Bookmarks)/.test(u)) return;
    await writeFile("tsnet_" + String(++chunk).padStart(3, "0") + ".json", await res.text());
  } catch (e) { console.log("resp: " + e.message.slice(0, 60)); }
});
```

`UserByScreenName` fires on the profile `goto` (before any scroll) and carries the **profile/bio** — name, bio, follower/following/tweet counts, join date, location, website, pinned tweet, professional category. Free to grab; parse folds it into the harvest's `profile` block.

Then scroll the profile with the **stale-and-cutoff** loop (jittered `mouse.wheel`, stop after N stale ticks or M tweets older than `{{CUTOFF}}`, ignoring the pinned tweet). Full loop in `references/capture-scripts.md`. The `note_tweet` field in these payloads is the **untruncated** long-text — this is why the network pass beats any DOM `innerText`.

**If the GraphQL operation names don't match** (X renames them periodically) → the listener writes nothing (`netChunks:0`). Do not push on; run **`references/graphql-recovery.md`** to re-discover the current operation names, patch the regex, re-run.

### Rate limits — expected, not failure

X throttles aggressive scrolling. Signatures and responses:
- **`"Something went wrong"` / a Retry button** → click it (`page.getByRole("button",{name:/retry/i}).first().click()`) and continue.
- **Timeline won't render (0 tweets after ~15 waits)** → prepend a **180s cooldown** (`await page.waitForTimeout(180000)`) and run the pass in the background (`run_in_background: true`) so the wall clock doesn't kill it.
- Pace between article fetches 4.5–8s. `waitUntil:"commit"` always — `networkidle`/`domcontentloaded` hang on X.

### dev-browser exit code 4 (or 1) is cosmetic

A QuickJS teardown assertion (`list_empty(&rt->gc_obj_list)`) throws exit 4 or 1 *after* the script's work. **Read stdout first** — if the summary line printed and the `tsnet_*.json` files exist, the capture succeeded. Never re-run on that assertion alone.

---

## Stage 3 — parse to normalized JSON

```bash
python ~/.claude/skills/x-harvest/scripts/parse.py \
  --handle {{HANDLE}} --cutoff {{CUTOFF}} \
  --out ./{{HANDLE}}-harvest-<date>.json \
  [--mode account|bookmarks] \
  [--known-ids path/to/known_ids.txt]
```

Reads every `~/.dev-browser/tmp/tsnet_*.json` + `ts_article_*.json` + `tsuser_*.json`, walks the payloads (`rest_id`+`legacy` nodes), extracts full text / threads / quotes / media / article bodies + the account **`profile`** (bio, metrics, join date, pinned, links), groups self-reply threads by `conversation_id`, drops retweets and (optionally) `known_ids`, and emits the **one normalized artifact** every consumer reads.

`--mode bookmarks` (default remains `account`): keep every author's tweets, skip the handle filter, skip the cutoff unless you pass one, reconcile against `ts_bm_dom.json`.

**Completeness gate (do not skip):** parse also reconciles the network ids against the DOM inventories (`ts_slice*.json`, `ts_profile*.json`, `ts_bm_dom.json`) and prints `missing_from_net: [...]`. **A non-trivial miss list means the network pass didn't cover everything the DOM saw — scroll further or re-run the network pass before consuming.** An empty miss list is the proof the harvest is a true superset.

---

## Stage 4 — consume (vault corpus, or your own)

The reference consumer writes the Obsidian-vault corpus (frontmatter + `<handle>-{tw|thr|art}-slug-date-id.md` + thread concatenation + quoted/media sections + `known_ids` incremental dedup). Schema in `references/corpus-schema.md`.

```bash
python ~/.claude/skills/x-harvest/scripts/ingest_corpus.py \
  --harvest ./{{HANDLE}}-harvest-<date>.json \
  --operator {{HANDLE}} --corpus /path/to/vault/corpus/ \
  --batch <date> \
  [--mode account|bookmarks]
```

Any other consumer (CSV, a prospect-research digest, JSONL) reads the same normalized JSON — **never re-scrape to change output format.** That split is the whole point of the two layers.

---

## Incremental refresh

A re-run is a first run with a `known_ids.txt` (one id per line — the ingest step maintains it, or derive it from existing corpus filenames). Pass `--known-ids` to parse and `--corpus` already-populated to ingest: only genuinely new posts get written. Set `{{CUTOFF}}` to a little before the last harvest's newest date so the windows overlap and nothing falls through the seam.

---

## Anti-patterns

| Don't | Do |
|---|---|
| Scrape `innerText` from the DOM as the source of truth | Capture the GraphQL payloads; DOM is the scroll motor + completeness check only |
| Trust the search tab alone | Harvest search + profile + articles; reconcile to a superset |
| Treat truncated tweet text as the full post | Read `note_tweet` from the payload (untruncated) |
| Script the X login | Manual login on the persistent `xharvest` page; wait for the operator |
| Re-run on dev-browser exit code 4 or 1 (QuickJS teardown) | Read stdout — data was written before the teardown assertion |
| Filter bookmark tweets to one handle | Bookmarks are other people's posts; `--mode bookmarks` keeps every author |
| Log in through Chrome for Testing | Attach to the operator's real Chrome (`--connect`) or a copied `--user-data-dir` |
| Combine `--connect` with `dev-browser run` | Pipe the script / here-string; `run` is swallowed |
| Push on when `netChunks:0` | Run `references/graphql-recovery.md`; X renamed the operations |
| `waitUntil:"networkidle"` | `waitUntil:"commit"` — X never goes idle |
| Hammer through a rate-limit | Click Retry, add the 180s cooldown, background the run |
| Re-scrape to get a different output format | Add a consumer that reads the normalized JSON |

---

## References & scripts

| File | What |
|---|---|
| `references/capture-scripts.md` | The 4-surface account scripts plus surface 5 (Bookmarks) |
| `references/graphql-recovery.md` | When X renames its GraphQL operations: re-discover and re-patch |
| `references/corpus-schema.md` | The vault-corpus consumer's frontmatter + filename spec |
| `scripts/parse.py` | Stage 3 — payloads → normalized JSON + completeness report |
| `scripts/ingest_corpus.py` | Stage 4 — normalized JSON → vault markdown (reference consumer) |
