---
name: li-harvest
description: Harvest a LinkedIn profile — full profile, experience, education, skills, and posts — into normalized JSON, with a vault dossier writer. Logged-in, operator-driven, paced to protect the account. Invoke with /li-harvest.
disable-model-invocation: true
---

# li-harvest

> **Core insight:** LinkedIn's Voyager component-JSON is near-unparseable (deeply nested generic components, URN-referenced, cache-served). But two sources are clean and complete: the **rendered DOM innerText** of each `/details/` page (segment by the date-range line) for profile sections, and the **network-captured feed Update entities** for posts. Don't fight the component JSON — read what the page already renders.

Harvest any LinkedIn profile into normalized JSON (profile, experience, education, skills, posts), then render a vault dossier. Proven on a live profile: full experience with exact tenure/dates, plus original posts with text, dates, and engagement.

**Platform:** dev-browser **headful** (login needs a real window). Windows: call `dev-browser` directly. Depends on the **dev-browser** skill.

## The account-ban reality — read first

This runs through **your** logged-in LinkedIn session, and LinkedIn bans accounts for automation far more aggressively than X. Non-negotiable rules:
- **Pace safe-fast:** jittered human waits (2–4s), moderate scroll, **one profile section per dev-browser call** (also keeps each call under the ~120s shell wall).
- **Abort on challenge:** every call checks for `/checkpoint`, `/authwall`, "unusual activity", "verify". If seen, **stop immediately** and tell the operator — do not push.
- **Personal research use only**, on your own session. Not a bulk scraper.

---

## The pipeline

```
[1] LOGIN GATE   operator logs in manually (persistent "liharvest" page)
[2] CAPTURE      per surface, paced:
      profile main    → DOM innerText → li_profile_dom.txt
      /details/experience/ → DOM innerText → li_experience_dom.txt
      /details/education/  → DOM innerText → li_education_dom.txt
      /details/skills/     → DOM innerText → li_skills_dom.txt   (optional)
      /recent-activity/all/ → network Update payloads → livoy_posts_*.json
[3] PARSE        parse.py --handle <publicId> --dir <capture> → harvest.json
[4] CONSUME      ingest_dossier.py → <handle>-linkedin.md
```

Full capture scripts (paced, challenge-guarded, with the right waits): **`references/capture-scripts.md`**. Copy the capture dir to a working folder, then run parse + ingest.

## Stage 1 — login gate

LinkedIn is unusable logged-out (an authwall blocks everything). Session lives on a persistent named page `liharvest`.

```bash
dev-browser --timeout 60 <<'EOF'
const page = await browser.getPage("liharvest");
await page.goto("https://www.linkedin.com/feed/", { waitUntil: "commit", timeout: 60000 }).catch(()=>{});
let st=null; for(let i=0;i<10;i++){ await page.waitForTimeout(2500);
  st=await page.evaluate(()=>{const b=document.body;if(!b)return{r:0};const t=b.innerText||"";
    return{url:location.href, challenge:/\/checkpoint|\/authwall|unusual activity|verify/i.test(location.href+t.slice(0,300)),
    loggedIn:t.includes("Start a post")||(t.includes("My Network")&&t.includes("Notifications"))};}).catch(()=>({}));
  if(st.loggedIn||st.challenge)break; }
console.log(JSON.stringify(st));
EOF
```

If not `loggedIn`, **stop and have the operator log in manually** in the headful window (expect a first-login verification challenge — normal). Wait for their confirmation. Never script credentials.

## Stage 2 — the two capture techniques

### Profile sections → DOM innerText (the load-bearing technique)

The `/details/experience|education|skills/` pages **render the full section as clean text**, even though the JSON is component-hell. Navigate, **wait until the section's real content is present** (a date-range line appears — do NOT break early on nav/"recommended people" text that loads first), then grab `main.innerText`. `parse.py` segments it by the date-range anchor into structured rows (role/org/dates/duration/location/description/skills). Same for the profile main (name/headline/followers/about).

### Posts → network capture

The `/recent-activity/shares/` feed loads `/voyager/api/…` payloads with **feed `Update` entities** carrying full post text, author, and social counts. Register a `page.on("response")` listener on `/voyager/api/` **before** navigating, save each payload. **Pagination is a "Show more results" BUTTON, not infinite scroll** — clicking it walks the full history back years; scrolling alone caps at the first ~15-20 posts. `parse.py` extracts each post's text (emoji-safe mojibake repair), author, `is_own` (author == profile name), date (from the activity-id snowflake), and reactions/comments/reposts.

### Cache gotcha

Repeated visits make LinkedIn serve **cached (304)** responses, so a network re-capture gets nothing. DOM grabs are unaffected (they render from cache fine). For a network re-capture, disable cache first via CDP: `const c = await page.context().newCDPSession(page); await c.send("Network.enable"); await c.send("Network.setCacheDisabled", {cacheDisabled:true});`

### dev-browser exit code 4 is cosmetic

A QuickJS teardown assertion throws exit 4 *after* the script's work. **Read stdout first** — the files were written. Never re-run on exit-4 alone.

## Stage 3 — parse

```bash
python ~/.claude/skills/li-harvest/scripts/parse.py \
  --handle <publicId> --dir <capture_dir> --out <handle>-harvest.json
```

Reads the DOM texts + `livoy_posts_*.json`, emits the normalized artifact: `{profile, experience, education, skills, posts, counts}`. Every consumer reads this.

## Stage 4 — consume

Two consumers read the same normalized JSON (mirror the vault's split: one readable dossier + one file per post):

```bash
# a) the dossier — profile + experience + education + skills (+ a posts summary)
python ~/.claude/skills/li-harvest/scripts/ingest_dossier.py \
  --harvest <handle>-harvest.json --out /path/to/vault/dir/ --batch <date>

# b) one markdown file per post, corpus-style (frontmatter + full text)
python ~/.claude/skills/li-harvest/scripts/ingest_posts.py \
  --harvest <handle>-harvest.json --out /path/to/vault/posts_dir/ --batch <date> [--include-reposts]
```

`ingest_dossier.py` writes a single `<handle>-linkedin.md`; `ingest_posts.py` writes `<handle>-lipost-<slug>-<date>-<id>.md` per original post (a full-history harvest is 100+ files). Other output formats = another consumer reading the same JSON.

---

## Anti-patterns

| Don't | Do |
|---|---|
| Try to parse LinkedIn's Voyager component JSON for profile sections | Read the rendered DOM innerText of the `/details/` pages; segment by the date line |
| Break the section wait on the first "University"/name match | Wait for a real date-range line — "recommended people" text loads first and false-matches |
| Rapid-fire many pages on the account | One section per paced call; jittered waits; abort on any challenge |
| Scroll the activity feed to get post history | Click the **"Show more results" button** until it vanishes — scroll alone caps at the first page (~18 posts vs the full multi-year history) |
| Push through a `/checkpoint` or "unusual activity" screen | Stop, tell the operator, let it cool down |
| Re-run a network capture and expect fresh data | Disable cache via CDP first (304s otherwise); or rely on the DOM |
| Re-run on dev-browser exit code 4 | Read stdout — the files were written |
| `waitUntil:"networkidle"` | `waitUntil:"commit"` — LinkedIn never idles |
| Treat the logged-out route as equivalent | It authwalls; only a Google-referer public view works, and it redacts tenure/dates and caps posts |

## References & scripts

| File | What |
|---|---|
| `references/capture-scripts.md` | The paced per-surface capture scripts (login, sections, posts) |
| `references/recovery.md` | When LinkedIn changes: re-find the feed op / fix the section parser |
| `scripts/parse.py` | Stage 3 — DOM texts + post payloads → normalized JSON |
| `scripts/ingest_dossier.py` | Stage 4 — normalized JSON → single vault dossier (profile/exp/edu/skills) |
| `scripts/ingest_posts.py` | Stage 4 — normalized JSON → one markdown file per post (corpus-style) |
