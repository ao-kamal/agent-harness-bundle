# Capture scripts — the four surfaces

## Contents
Placeholders · 1 Search slices · 2 Profile scroll (DOM) · 3 Profile scroll + network capture (load-bearing) · 4a Articles list · 4b Article full-text

Fill the placeholders, run each via the Bash tool as a `dev-browser` heredoc on the persistent `xharvest` page. All output lands in `~/.dev-browser/tmp/`. Run in order; the parse stage reconciles them.

**Placeholders**
- `{{HANDLE}}` — the account, no `@` (e.g. `termsheetinator`)
- `{{SINCE}}` / `{{UNTIL}}` — per search slice, `YYYY-MM-DD` (keep slices ~monthly so none exceeds the scroll ceiling)
- `{{CUTOFF}}` — oldest date to harvest back to, `YYYY-MM-DD`

All scripts use `waitUntil:"commit"` (X hangs on `networkidle`/`domcontentloaded`) and tolerate the rate-limit Retry button. Read stdout before assuming failure (exit code 4 is a cosmetic teardown assertion).

---

## 1 — Search slices (DOM inventory)

Run once per date slice. Change `{{SINCE}}`/`{{UNTIL}}` and the output filename (`ts_slice1`, `ts_slice2`, …) each time.

```bash
dev-browser --timeout 540 <<'EOF'
const page = await browser.getPage("xharvest");
const q = "from:{{HANDLE}} since:{{SINCE}} until:{{UNTIL}} -filter:replies";
const url = "https://x.com/search?q=" + encodeURIComponent(q) + "&src=typed_query&f=live";
await page.goto(url, { waitUntil: "commit", timeout: 45000 }).catch(e => console.log("nav: " + e.message.slice(0,80)));
let ready = false;
for (let i = 0; i < 15; i++) {
  await page.waitForTimeout(2000);
  const st = await page.evaluate(() => ({
    tweets: document.querySelectorAll('article[data-testid="tweet"]').length,
    empty: document.body.innerText.includes("No results for"),
    broken: document.body.innerText.includes("Something went wrong"),
  }));
  if (st.broken) { const r = page.getByRole("button", { name: /retry/i }); if (await r.count()) await r.first().click().catch(()=>{}); continue; }
  if (st.tweets > 0 || st.empty) { ready = st.tweets > 0; break; }
}
const acc = {};
if (ready) {
  let stale = 0, ticks = 0;
  while (stale < 6 && ticks < 110) {
    ticks++;
    const batch = await page.evaluate(() => {
      const out = [];
      for (const art of document.querySelectorAll('article[data-testid="tweet"]')) {
        const link = Array.from(art.querySelectorAll('a[href*="/{{HANDLE}}/status/"]')).find(a => a.querySelector("time"));
        if (!link) continue;
        const m = link.getAttribute("href").match(/status\/(\d+)/); if (!m) continue;
        const txt = art.querySelector('div[data-testid="tweetText"]');
        const ctx = art.querySelector('[data-testid="socialContext"]');
        out.push({ id: m[1], dt: link.querySelector("time")?.getAttribute("datetime") || null,
          text: txt ? txt.innerText : "", truncated: !!art.querySelector('[data-testid="tweet-text-show-more-link"]'),
          isArticle: !!art.querySelector('a[href*="/i/article/"]'),
          hasQuote: !!art.querySelector('div[role="link"] div[data-testid="tweetText"]'),
          ctx: ctx ? ctx.innerText.slice(0, 40) : null });
      }
      return out;
    }).catch(() => []);
    let fresh = 0;
    for (const t of batch) if (!acc[t.id]) { acc[t.id] = t; fresh++; }
    stale = fresh === 0 ? stale + 1 : 0;
    await page.mouse.wheel(0, 2400 + Math.floor(Math.random() * 700));
    await page.waitForTimeout(850 + Math.floor(Math.random() * 500));
    if (ticks % 18 === 0) await page.waitForTimeout(2500);
  }
}
const items = Object.values(acc);
await writeFile("ts_slice1.json", JSON.stringify(items, null, 1));
console.log(JSON.stringify({ slice: "{{SINCE}}..{{UNTIL}}", count: items.length, truncated: items.filter(x=>x.truncated).length, articles: items.filter(x=>x.isArticle).length }));
EOF
```

---

## 2 — Profile scroll (DOM inventory)

Catches what search drops. Stops on stale ticks OR seeing enough posts older than `{{CUTOFF}}` (pinned tweet ignored).

```bash
dev-browser --timeout 420 <<'EOF'
const page = await browser.getPage("xharvest");
await page.goto("https://x.com/{{HANDLE}}", { waitUntil: "commit", timeout: 45000 }).catch(e => console.log("nav: " + e.message.slice(0,80)));
for (let i = 0; i < 12; i++) { await page.waitForTimeout(2000); const n = await page.evaluate(() => document.querySelectorAll('article[data-testid="tweet"]').length).catch(()=>0); if (n > 0) break; }
const CUTOFF = "{{CUTOFF}}";
const acc = {}; let stale = 0, ticks = 0, oldsSeen = 0;
while (stale < 7 && oldsSeen < 4 && ticks < 160) {
  ticks++;
  const batch = await page.evaluate(() => {
    const out = [];
    for (const art of document.querySelectorAll('article[data-testid="tweet"]')) {
      const link = Array.from(art.querySelectorAll('a[href*="/{{HANDLE}}/status/"]')).find(a => a.querySelector("time"));
      if (!link) continue;
      const m = link.getAttribute("href").match(/status\/(\d+)/); if (!m) continue;
      const txt = art.querySelector('div[data-testid="tweetText"]');
      const ctx = art.querySelector('[data-testid="socialContext"]');
      out.push({ id: m[1], dt: link.querySelector("time")?.getAttribute("datetime") || null,
        text: txt ? txt.innerText : "", truncated: !!art.querySelector('[data-testid="tweet-text-show-more-link"]'),
        hasQuote: !!art.querySelector('div[role="link"] div[data-testid="tweetText"]'),
        ctx: ctx ? ctx.innerText.slice(0, 40) : null });
    }
    return out;
  }).catch(() => []);
  let fresh = 0;
  for (const t of batch) if (!acc[t.id]) { acc[t.id] = t; fresh++; const pin = t.ctx && /pin/i.test(t.ctx); if (t.dt && t.dt.slice(0,10) < CUTOFF && !pin) oldsSeen++; }
  stale = fresh === 0 ? stale + 1 : 0;
  await page.mouse.wheel(0, 2500 + Math.floor(Math.random() * 700));
  await page.waitForTimeout(800 + Math.floor(Math.random() * 450));
  if (ticks % 20 === 0) await page.waitForTimeout(2600);
}
const items = Object.values(acc);
await writeFile("ts_profile.json", JSON.stringify(items, null, 1));
console.log(JSON.stringify({ total: items.length, ticks, oldsSeen, oldest: items.map(t=>t.dt).sort()[0] }));
EOF
```

---

## 3 — Profile scroll + network capture (the load-bearing pass)

Same scroll, but a `page.on("response")` listener writes every timeline GraphQL payload to `tsnet_*.json` — the full-fidelity source (untruncated `note_tweet`, threads, quotes, media). Writes `ts_profile_dom2.json` as the DOM cross-check. If throttled, uncomment the 180s cooldown and run with `run_in_background: true`.

```bash
dev-browser --timeout 560 <<'EOF'
const page = await browser.getPage("xharvest");
// await page.waitForTimeout(180000);   // <-- uncomment if rate-limited
let chunk = 0, userChunk = 0;
page.on("response", async (res) => {
  try {
    if (res.status() !== 200) return;
    const u = res.url();
    // profile payload — fires on the goto below, before any scroll
    if (/graphql\/[^\/]+\/(UserByScreenName|UserByRestId)/.test(u)) {
      await writeFile("tsuser_" + String(++userChunk).padStart(3, "0") + ".json", await res.text());
      return;
    }
    if (!/graphql\/[^\/]+\/(UserOriginalsTimeline|UserTweets|UserTweetsAndReplies|SearchTimeline|TweetDetail)/.test(u)) return;
    await writeFile("tsnet_" + String(++chunk).padStart(3, "0") + ".json", await res.text());
  } catch (e) { console.log("resp: " + e.message.slice(0, 60)); }
});
await page.goto("https://x.com/{{HANDLE}}", { waitUntil: "commit", timeout: 45000 }).catch(e => console.log("nav: " + e.message.slice(0,80)));
let rendered = false;
for (let i = 0; i < 15; i++) {
  await page.waitForTimeout(2500);
  const n = await page.evaluate(() => document.querySelectorAll('article[data-testid="tweet"]').length).catch(()=>0);
  if (n > 0) { rendered = true; break; }
  const r = page.getByRole("button", { name: /retry/i }); if (await r.count()) await r.first().click().catch(()=>{});
}
if (!rendered) { console.log(JSON.stringify({ aborted: "timeline throttled", netChunks: chunk })); }
else {
  const CUTOFF = "{{CUTOFF}}";
  const acc = {}; let stale = 0, ticks = 0, oldsSeen = 0;
  while (stale < 8 && oldsSeen < 5 && ticks < 210) {
    ticks++;
    const batch = await page.evaluate(() => {
      const out = [];
      for (const art of document.querySelectorAll('article[data-testid="tweet"]')) {
        const link = Array.from(art.querySelectorAll('a[href*="/{{HANDLE}}/status/"]')).find(a => a.querySelector("time"));
        if (!link) continue;
        const m = link.getAttribute("href").match(/status\/(\d+)/); if (!m) continue;
        const ctx = art.querySelector('[data-testid="socialContext"]');
        out.push({ id: m[1], dt: link.querySelector("time")?.getAttribute("datetime") || null, ctx: ctx ? ctx.innerText.slice(0, 30) : null });
      }
      return out;
    }).catch(() => []);
    let fresh = 0;
    for (const t of batch) if (!acc[t.id]) { acc[t.id] = t; fresh++; if (t.dt && t.dt.slice(0,10) < CUTOFF && !(t.ctx && /pin/i.test(t.ctx))) oldsSeen++; }
    stale = fresh === 0 ? stale + 1 : 0;
    await page.mouse.wheel(0, 2000 + Math.floor(Math.random() * 600));
    await page.waitForTimeout(1000 + Math.floor(Math.random() * 500));
    if (ticks % 20 === 0) await page.waitForTimeout(3000);
  }
  await page.waitForTimeout(3500);   // let the last payloads land
  await writeFile("ts_profile_dom2.json", JSON.stringify(Object.values(acc), null, 1));
  const dts = Object.values(acc).map(t=>t.dt).filter(Boolean).sort();
  console.log(JSON.stringify({ ticks, domIds: Object.keys(acc).length, netChunks: chunk, userChunks: userChunk, oldest: dts[0], newest: dts[dts.length-1] }));
}
EOF
```

For **search-slice** network payloads too (denser than profile for a tight date range), run this same listener while doing surface 1's search scroll — the regex already includes `SearchTimeline`.

**`netChunks:0` with tweets rendered = X renamed the GraphQL operations.** Go to `graphql-recovery.md`.

---

## 4a — Articles list

The `/articles` tab. Articles appear in *no* tweet timeline.

```bash
dev-browser --timeout 120 <<'EOF'
const page = await browser.getPage("xharvest");
await page.goto("https://x.com/{{HANDLE}}/articles", { waitUntil: "commit", timeout: 40000 }).catch(e => console.log("nav: " + e.message.slice(0,80)));
await page.waitForTimeout(5000);
const hasTab = await page.evaluate(() => !document.body.innerText.includes("This account doesn") && !document.body.innerText.includes("page doesn"));
const acc = {};
if (hasTab) {
  for (let tick = 0; tick < 12; tick++) {
    const batch = await page.evaluate(() => {
      const out = [];
      for (const cell of document.querySelectorAll('[data-testid="cellInnerDiv"]')) {
        const link = Array.from(cell.querySelectorAll("a[href]")).map(a => a.getAttribute("href")).find(h => /\/status\/\d+|\/i\/article/.test(h));
        const time = cell.querySelector("time");
        if (link) out.push({ link, dt: time ? time.getAttribute("datetime") : null, txt: cell.innerText.slice(0, 220).replace(/\s+/g, " ") });
      }
      return out;
    }).catch(() => []);
    for (const a of batch) if (!acc[a.link]) acc[a.link] = a;
    await page.mouse.wheel(0, 1500);
    await page.waitForTimeout(900);
  }
}
const items = Object.values(acc);
await writeFile("ts_articles_list.json", JSON.stringify(items, null, 1));
console.log(JSON.stringify({ hasTab, count: items.length }));
EOF
```

## 4b — Article full-text

Visits each listed article, grabs the rich-text body (fallback selector chain), paces 4.5–8s between. Writes one `ts_article_<id>.json` each.

```bash
dev-browser --timeout 560 <<'EOF'
const page = await browser.getPage("xharvest");
let net = 0;
page.on("response", async (res) => { try { if (res.status()===200 && /graphql\/[^\/]+\/TweetDetail/.test(res.url())) await writeFile("tsart_net_" + String(++net).padStart(3,"0") + ".json", await res.text()); } catch(e){} });
const list = JSON.parse(await readFile("ts_articles_list.json"));
const done = [];
for (const item of list) {
  const id = (item.link.match(/status\/(\d+)/) || [])[1]; if (!id) continue;
  try {
    await page.goto("https://x.com" + item.link, { waitUntil: "commit", timeout: 40000 });
    let best = { len: 0 };
    for (let i = 0; i < 10; i++) {
      await page.waitForTimeout(2200);
      const cur = await page.evaluate(() => {
        const sel = document.querySelector('[data-testid="twitterArticleRichTextView"]') || document.querySelector('[data-testid="twitter-article"]') || document.querySelector("main article") || document.querySelector("main");
        const title = document.querySelector("h1, [data-testid='twitterArticleTitle']");
        const imgs = sel ? Array.from(sel.querySelectorAll("img")).map(im => im.src).filter(s => /pbs\.twimg/.test(s)) : [];
        return { len: sel ? sel.innerText.length : 0, title: title ? title.innerText : null, text: sel ? sel.innerText : "", imgs };
      }).catch(() => ({ len: 0 }));
      if (cur.len > best.len) best = cur;
      if (best.len > 1500 && cur.len === best.len) break;
    }
    await writeFile("ts_article_" + id + ".json", JSON.stringify({ id, dt: item.dt, listTxt: item.txt, title: best.title, chars: best.len, imgs: best.imgs || [], text: best.text || "" }));
    done.push({ id, chars: best.len, title: (best.title || item.txt.slice(0,60)).slice(0,70) });
  } catch (e) { done.push({ id, err: e.message.slice(0, 60) }); }
  await page.waitForTimeout(4500 + Math.floor(Math.random() * 3500));
}
console.log(JSON.stringify(done, null, 1));
EOF
```
