# Capture scripts — per surface, paced

## Contents
Placeholders · challenge guard · 1 Profile main · 2 Experience · 3 Education · 4 Skills · 5 Posts

Run each as a separate `dev-browser` call on the persistent `liharvest` page (one per call keeps you under the ~120s shell wall and paces the account). Fill `{{PUB}}` = the profile's public identifier (the `/in/<PUB>/` slug). All output lands in `~/.dev-browser/tmp/`; copy those files to a capture dir for `parse.py`.

**Every call must abort on a challenge.** Each script below checks for `/checkpoint`, `/authwall`, "unusual activity", "verify" and stops. If a call reports `challenge:true`, **do not continue** — tell the operator and let the account cool down.

Pacing: `waitUntil:"commit"`, jittered waits, moderate scroll. Read stdout before assuming failure (exit-code-4 is a cosmetic teardown; the files were written).

---

## 1 — Profile main (name / headline / followers / about)

```bash
dev-browser --timeout 90 <<'EOF'
const page = await browser.getPage("liharvest");
await page.goto("https://www.linkedin.com/in/{{PUB}}/", { waitUntil: "commit", timeout: 45000 }).catch(e=>console.log("nav: "+e.message.slice(0,50)));
let txt="", ch=false;
for(let i=0;i<12;i++){ await page.waitForTimeout(2200+Math.floor(Math.random()*500));
  const st=await page.evaluate(()=>{const m=document.querySelector("main")||document.body;const t=m?m.innerText:"";
    return{t, ch:/\/checkpoint|\/authwall|unusual activity|verify/i.test(location.href)};}).catch(()=>({t:""}));
  ch=st.ch; if(ch) break;
  if(st.t.length>800 && /About|followers/i.test(st.t)){ txt=st.t; break; } }
// expand the About "see more" if present, then re-read
await page.getByText(/^…see more$|^see more$/i).first().click({timeout:1500}).catch(()=>{});
await page.waitForTimeout(1200);
txt = await page.evaluate(()=>{const m=document.querySelector("main")||document.body;return m?m.innerText:"";}).catch(()=>txt);
await writeFile("li_profile_dom.txt", txt);
console.log(JSON.stringify({challenge:ch, len:txt.length}));
EOF
```

## 2 — Experience (`/details/experience/`)

The wait is the crux: poll until a **date-range line** appears (real experience content), NOT just any text — "recommended people" loads first and false-matches on words like "University".

```bash
dev-browser --timeout 100 <<'EOF'
const page = await browser.getPage("liharvest");
await page.goto("https://www.linkedin.com/in/{{PUB}}/details/experience/", { waitUntil: "commit", timeout: 45000 }).catch(e=>console.log("nav: "+e.message.slice(0,50)));
let txt="", ch=false;
const DATE=/(?:[A-Z][a-z]{2} )?\d{4}\s*[-–]\s*(?:Present|(?:[A-Z][a-z]{2} )?\d{4})/;
for(let i=0;i<14;i++){ await page.waitForTimeout(2300+Math.floor(Math.random()*500));
  const st=await page.evaluate(()=>{const m=document.querySelector("main")||document.body;return{t:m?m.innerText:"", ch:/\/checkpoint|\/authwall|unusual activity|verify/i.test(location.href)};}).catch(()=>({t:""}));
  ch=st.ch; if(ch) break;
  if(DATE.test(st.t)){ txt=st.t; break; } }
for(let i=0;i<3;i++){ await page.mouse.wheel(0,1000); await page.waitForTimeout(1300); }
txt = await page.evaluate(()=>{const m=document.querySelector("main")||document.body;return m?m.innerText:"";}).catch(()=>txt);
await writeFile("li_experience_dom.txt", txt);
console.log(JSON.stringify({challenge:ch, len:txt.length, hasDate:DATE.test(txt)}));
EOF
```

## 3 — Education (`/details/education/`)

Identical to experience with the URL and output filename changed. The same date-line wait avoids the early false-match.

```bash
dev-browser --timeout 100 <<'EOF'
const page = await browser.getPage("liharvest");
await page.goto("https://www.linkedin.com/in/{{PUB}}/details/education/", { waitUntil: "commit", timeout: 45000 }).catch(e=>console.log("nav: "+e.message.slice(0,50)));
let txt="", ch=false;
const DATE=/(?:[A-Z][a-z]{2} )?\d{4}\s*[-–]\s*(?:Present|(?:[A-Z][a-z]{2} )?\d{4})/;
for(let i=0;i<14;i++){ await page.waitForTimeout(2300+Math.floor(Math.random()*500));
  const st=await page.evaluate(()=>{const m=document.querySelector("main")||document.body;return{t:m?m.innerText:"", ch:/\/checkpoint|\/authwall|unusual activity|verify/i.test(location.href)};}).catch(()=>({t:""}));
  ch=st.ch; if(ch) break;
  if(DATE.test(st.t)){ txt=st.t; break; } }
await page.waitForTimeout(1500);
txt = await page.evaluate(()=>{const m=document.querySelector("main")||document.body;return m?m.innerText:"";}).catch(()=>txt);
await writeFile("li_education_dom.txt", txt);
console.log(JSON.stringify({challenge:ch, len:txt.length, hasDate:DATE.test(txt)}));
EOF
```

## 4 — Skills (`/details/skills/`, optional)

Like posts, a long skill list paginates behind a **"Show more results" button** — click it until it's gone, then grab the DOM. (Short lists have no button; the loop just exits.) `parse.py` stops at the "More profiles for you" / footer boundary, so the recommended-people section that follows never leaks in.

```bash
dev-browser --timeout 100 <<'EOF'
const page = await browser.getPage("liharvest");
await page.goto("https://www.linkedin.com/in/{{PUB}}/details/skills/", { waitUntil: "commit", timeout: 45000 }).catch(e=>console.log("nav: "+e.message.slice(0,50)));
for(let i=0;i<8;i++){ await page.waitForTimeout(2200); const l=await page.evaluate(()=>document.body?document.body.innerText.length:0).catch(()=>0); if(l>600)break; }
let clicks=0, ch=false, gone=0;
for(let r=0; r<18 && !ch && gone<3; r++){
  await page.evaluate(()=>window.scrollTo(0, document.body.scrollHeight)).catch(()=>{});
  await page.waitForTimeout(1200);
  const btn = page.getByRole("button", { name: /show more results|show all/i });
  if(await btn.count()){ await btn.first().click().catch(()=>{}); clicks++; gone=0; await page.waitForTimeout(2000+Math.floor(Math.random()*600)); }
  else { gone++; await page.waitForTimeout(1200); }
  if(r%5===4){ ch=await page.evaluate(()=>/\/checkpoint|\/authwall|unusual activity/i.test(location.href)).catch(()=>false); }
}
const txt = await page.evaluate(()=>{const m=document.querySelector("main")||document.body;return m?m.innerText:"";}).catch(()=>"");
await writeFile("li_skills_dom.txt", txt);
console.log(JSON.stringify({challenge:ch, clicks, len:txt.length}));
EOF
```

## 5 — Posts (`/recent-activity/shares/`, network capture)

**The feed paginates by a "Show more results" BUTTON, not infinite scroll.** Scrolling alone stops at the first page (~15-20 items); *clicking the button* walks the full history back years. Register the Voyager listener **before** navigating, then click "Show more results" until it disappears (history exhausted). Use `/shares/` for her own posts (or `/all/` for posts + reposts). CDP cache-disable is required on a re-harvest or you get 304s.

```bash
dev-browser --timeout 115 <<'EOF'
const page = await browser.getPage("liharvest");
try{ const c=await page.context().newCDPSession(page); await c.send("Network.enable"); await c.send("Network.setCacheDisabled",{cacheDisabled:true}); }catch(e){}
let idx=0;
page.on("response", async (res)=>{ try{
  const u=res.url(); if(!/\/voyager\/api\//.test(u)||res.status()!==200) return;
  const b=await res.text(); if(/\.feed\.Update|"commentary"/.test(b)){ await writeFile("livoy_posts_"+String(++idx).padStart(3,"0")+".json", b); }
}catch(e){} });
await page.goto("https://www.linkedin.com/in/{{PUB}}/recent-activity/shares/", { waitUntil:"commit", timeout:45000 }).catch(e=>console.log("nav: "+e.message.slice(0,50)));
for(let i=0;i<7;i++){ await page.waitForTimeout(2500); const l=await page.evaluate(()=>document.body?document.body.innerText.length:0).catch(()=>0); if(l>1500)break; }
let clicks=0, ch=false, gone=0;
for(let r=0; r<22 && !ch && gone<3; r++){
  await page.evaluate(()=>window.scrollTo(0, document.body.scrollHeight)).catch(()=>{});
  await page.waitForTimeout(1200);
  const btn = page.getByRole("button", { name: /show more results/i });
  if(await btn.count()){ await btn.first().click().catch(()=>{}); clicks++; gone=0; await page.waitForTimeout(2200+Math.floor(Math.random()*800)); }
  else { gone++; await page.waitForTimeout(1500); }
  if(r%5===4){ ch=await page.evaluate(()=>/\/checkpoint|\/authwall|unusual activity/i.test(location.href)).catch(()=>false); }
}
await page.waitForTimeout(2500);
console.log(JSON.stringify({challenge:ch, clicks, postPayloads:idx, buttonGone:gone>=3}));
EOF
```

`buttonGone:true` means the full history loaded (the button vanishes at the end). If a very long history hits the ~120s wall before the button is gone, re-run the call **without re-navigating** (the page keeps its loaded state) to continue clicking from where it stopped. Watch for a challenge and stop if one appears.
