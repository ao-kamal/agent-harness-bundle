# Recovery — when LinkedIn changes

LinkedIn reshuffles its DOM and Voyager operations periodically. Two failure modes, both quick to fix.

## Section parser returns 0 rows (experience/education)

`parse.py` segments the DOM innerText by the **date-range line** (`DATE_RE`). If a capture's `li_experience_dom.txt` has content but parse finds 0 entries, the date formatting changed. Inspect the text:

```bash
python - <<'PY'
import re
t = open("li_experience_dom.txt", encoding="utf-8").read()
for ln in [l.strip() for l in t.split("\n") if l.strip()][:20]:
    print(repr(ln))
PY
```

Find the date line (e.g. `"May 2023 - Present · 3 yrs 3 mos"`) and adjust `DATE_RE` in `scripts/parse.py` to match. The entry structure is stable: **title = 2 lines above the date line, org = 1 line above**; only the date format tends to drift.

If the DOM grab captured only "recommended people" / footer (no dates), the capture's **wait broke too early** — the section hadn't rendered. Re-capture; the script in `capture-scripts.md` waits for a date line specifically, but a very slow load can still miss. Increase the poll count or add a scroll-to-top before reading.

## Posts capture is empty (`postPayloads:0`)

Either the feed operation was renamed, or responses came back **cached (304)**. First disable cache (CDP, see SKILL.md) and re-run. If still empty, the `Update` type / `commentary` field moved — dump what the feed actually returns:

```bash
# in a dev-browser call on /recent-activity/all/, log the graphql ops:
# page.on("response", r => { const m=r.url().match(/queryId=(\w+)/); if(m) console.log(m[1]); })
```

Then confirm the payload still carries `com.linkedin.voyager.dash.feed.Update` entities with a `commentary` field; if the type path changed, update the `endswith("Update")` check and `_text_of(u.get("commentary"))` in `parse_posts`.

## Reaction counts partly missing

Normal — `SocialActivityCounts` load progressively as the feed renders. Scroll more rounds in the posts capture to fill them. The post text, date, author, and is-own are independent of the counts and always present.

## The whole profile authwalls

You've been logged out or challenged. Re-run the login gate; if a `/checkpoint` appears, the operator resolves it manually. Do not automate around it.
