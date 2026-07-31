---
created: 2026-04-08
categories:
- vault-creation
- agent-vaults
- methodologies
type: reference
updated: 2026-04-28
---

# Agent Vault Creation Methodology

How to build a subject-matter vault that grounds multi-agent pipelines in source material. Follows Karpathy's LLM Wiki philosophy: raw sources stay immutable, an LLM-generated wiki layer provides navigable indexes and maps, and a schema tells the LLM how everything fits together. Every vault gets an `AGENTS.md` orientation file so any agent — polishing, executing, or querying — gets oriented in 60 seconds.

Derived from the WriteWithAI vault (396 files, 10 MOCs), PGA vault (127 files, 6 MOCs), cold-outreach v1 vault (120 files, 6 MOCs, multi-source acquisition), the swipefile-vault (145 atomic templates, structured retrieval surface), and cold-outreach v2 (in-place migration with widened scope, Twitter Articles acquisition, delta ingestion).

**When to create a vault:** Before building a deliverable pipeline that requires craft knowledge the existing vaults don't cover. If the PGA vault covers EEC methodology and the WriteWithAI vault covers writing craft, but you need cold outreach methodology from specific Twitter operators and YouTube channels — that's a new vault.

**Three vault types now exist:**
- **Authored vaults** (WriteWithAI, PGA): source material from a single author/course, pre-extracted to markdown. Simpler ingestion — files already exist, you classify them.
- **Multi-source vaults** (cold-outreach v1, cold-outreach v2): source material scraped from multiple operators across platforms (Twitter timeline, Twitter Articles, YouTube, web blogs, articles, research). Requires an acquisition pipeline before ingestion. More moving parts but captures live operator knowledge that doesn't exist in packaged courses.
- **Structured retrieval vaults** (swipefile-vault): atomic entries with retrieval-friendly metadata (`structural_tags`, `audience`, `use_when`, `avoid_when`, `slot_guidance`, `quotable_lines`). Designed for LLM librarian dispatch via two-step progressive disclosure (Step 1: ≤300-word menu of candidate IDs; Step 2: full templates on request). Benchmark-validated end-to-end with golden queries.

---

## Prerequisites

- **For authored vaults:** Source material extracted to markdown files (course transcripts, articles, posts, book notes)
- **For multi-source vaults:** Operator handles/channels/URLs identified, API keys for scraping tools (Apify, Firecrawl), yt-dlp installed, dev-browser logged into Twitter (if Twitter Articles in scope)
- **For structured retrieval vaults:** Atomic source material (e.g., a swipe file with discrete templates), schema for retrieval metadata, benchmark golden queries with expected_top_set IDs
- A sibling vault to cross-reference (if one exists)
- A clear scope: what domain does this vault cover? What does it NOT cover?
- A build spec (for multi-source vaults): document every phase, every operator, every acquisition source before writing any code. The cold-outreach v2 BUILD-SPEC.md was 1,586 lines.

---

## Phase 0: Build Planning (multi-source and structured retrieval vaults)

Skip this for authored vaults where source files already exist.

### Dependency-graph execution with beads

Use `br` (beads_rust) to create a bead per phase with explicit dependencies. This prevents out-of-order execution and gives you a machine-readable execution plan.

```bash
br init
br create "Phase A: Vault Architecture" -t task -p 0 -l <project>
br create "Phase B.0: Actor Verification" -t task -p 0 -l <project>
br dep add <B.0-id> <A-id>  # B.0 blocked by A
br dep cycles               # MUST be empty before execution
```

**Always label v2+ beads** to distinguish from v1 historical beads in the same DB. Bead descriptions are runbooks: WHAT TO DO / OUTPUTS / SUCCESS CRITERIA / FAILURE MODE / BACKGROUND. Self-contained — never need to consult the spec.

Use `bv --robot-triage` to get the next actionable bead. Mark beads `in_progress` when starting, `closed` with a reason string when done. NEVER use bare `bv` in agent contexts (interactive TUI).

### Operator selection

Choose operators who:
- Produce content within your vault's scope (not adjacent — within)
- Have enough public content for a meaningful corpus (200+ tweets, or 10+ long-form videos, or a blog with 5+ in-scope articles)
- Are distinct enough to enable cross-operator concept detection (2+ operators saying the same thing independently is a strong signal)
- Match the platform constraints of your acquisition tools (e.g., dev-browser login state required for Twitter Articles)

Track each operator's platform presence: Twitter handle, Twitter Articles availability, YouTube channel URL, blog/newsletter URLs, known website domains (for the link-share EXCLUDE rule).

**Per-operator scope can vary:** v2 introduced articles-only scope for some operators (Priya Sandhu, Elliot Marsh) where the operational density is in long-form Articles, not the timeline. Other operators get YouTube-only (Marco Renwick) or timeline+articles (Terrence Ashgrove). Per-operator scope decisions belong in the BUILD-SPEC's source inventory section.

### AGENTS.md authoring

Every vault gets an `AGENTS.md` file at the vault root. Authored at Phase 0 or early Phase 1, updated as the project evolves. Sections:

1. **What this vault is** — one-paragraph mission
2. **Current state** — phase, bead state, file counts
3. **Operator profile** — who's running this, communication preferences, process preferences
4. **Agent role by phase** — planning vs polishing vs executing matrix
5. **Key files & where to look** — table with mutation rules
6. **Tools** — table + per-tool gotchas
7. **Conventions** — beads, LLM work, file mutations, logging, validation cadence
8. **Anti-patterns** — table of "don't do X / why"
9. **What done looks like** — pointer to BUILD-SPEC success criteria
10. **Sibling vaults** — when to cross-reference

`AGENTS.md` is the agent equivalent of `README.md`. New convention as of v2: prefer `AGENTS.md` over `README.md` for agent-targeted vaults. Beads-workflow polish prompts read `AGENTS.md` on every round.

---

## Phase 1: Architecture

Create the directory structure:

```
AgentVaults/[vault-name]/
  .obsidian/                ← clone from a sibling vault for config consistency
  AGENTS.md                 ← agent orientation (Phase 0/1)
  BUILD-SPEC.md             ← authoritative spec (locked after authoring)
  schema.md                 ← schema (co-evolved during build)
  raw/                      ← source files — body content immutable; classification fields populated by F.2
    _excluded/              ← files excluded by F.1 with reason; audit trail
  scripts/                  ← Python utility scripts for the pipeline
  wiki/
    index.md                ← master catalog (built at Phase I)
    excluded.md             ← files skipped and why, with pipe-delimited table
    log.md                  ← chronological build log with timestamps
    failures.log            ← structured failure log: timestamp | phase | tool | input | error | retries | status
    costs.log               ← API costs: timestamp | operator | tool | $cost | item_count
    mocs/                   ← Maps of Content, one per domain
    mocs-v1/                ← (v2+ only) archived prior MOC versions for migration audit
    concepts/               ← cross-operator concept pages (built at Phase F.5)
    article-urls/           ← (multi-source w/ Twitter Articles) per-operator URL lists from dev-browser scroll-extract
    phase-status/           ← per-phase JSON completion files
    prompts/                ← versioned classification prompts (F.1, F.2)
    operator-domains.json   ← operator → website domains (for link-share filtering)
    discovered-sources.json ← bookmark/link-share URLs found during classification
    last_ingested.json      ← (multi-source) per-operator delta state
    phase-completion.json   ← aggregate phase status
```

### Staging directories (multi-source vaults)

Content that doesn't fit the vault's scope but belongs in a sibling vault goes to staging:

```
AgentVaults/_staging/
  sales-adjacent/           ← post-booking content, agency sales process
  pga-adjacent/             ← agency packaging, EEC, Loom pitch
  writewithai-adjacent/     ← general copywriting craft
  voice-fidelity/           ← voice calibration only
  _staging-index.md         ← intake queue for future vault sessions
```

STAGE destinations are specific to each vault's scope neighbors. Define them at architecture time.

### Three layers (unchanged)

- **raw/** — source body content immutable. Classification frontmatter mutable via atomic_write_frontmatter.py.
- **wiki/** — LLM-generated. Index, MOCs, concept pages, logs — all maintained by the pipeline. Regenerable from raw/ if corrupted.
- **schema.md** — co-evolved. Tells the LLM how the vault works.

### Spec authoring

For multi-source and structured retrieval vaults: write a BUILD-SPEC.md before any acquisition runs. v2's spec was 1,586 lines covering 20 sections + 7 appendices. Comprehensive specs catch scope ambiguities, edge cases, and tooling gotchas before they become mid-build problems.

Specs are locked once authored. Material changes go through versioned migration (see Phase M).

---

## Phase B: Backup Infrastructure

Set up git + remote + plugin BEFORE running acquisition or ingestion. A vault build that crashes mid-execution without backup loses everything. Backup infrastructure is independent of vault content — apply this phase to any vault type.

### One git repo per vault

Each vault is its own git repository with its own GitHub remote. Independent vaults = independent backups, independent commit histories, independent rollback. Do NOT nest one vault as a subdirectory of another vault that's also git-tracked — see "Multi-Vault Folder Topology" section below for why.

```bash
cd /path/to/AgentVaults/{vault-name}
git init -b master
git config user.email "{your-email}"
git config user.name "{your-name}"
```

### Repo naming convention

Private GitHub repos under your account, suffixed `-vault`:
- `<your-github-user>/cold-outreach-vault`
- `<your-github-user>/agent-pga-vault`
- `<your-github-user>/agent-writewithai-vault`
- `<your-github-user>/swipefile-vault` (project repos may skip the suffix convention if the name already reads clearly as a vault)
- `<your-github-user>/agent-staging-vault`

### .gitignore (vault-type templates)

**Common to all vaults** — Obsidian per-machine state, beads SQLite (regenerable from JSONL), secrets, Python caches, OS files, temp files:

```gitignore
# Beads — keep JSONL (source of truth in git), ignore SQLite (regenerable)
.beads/*.db
.beads/*.db-wal
.beads/*.db-shm
.beads/.sync.lock
.beads/.bv.lock
.beads/.br_history/
.beads/daemon.lock
.beads/daemon.log
.beads/daemon.pid

# bv local config
.bv/

# Obsidian per-machine state
.obsidian/workspace.json
.obsidian/workspace-mobile.json
.obsidian/cache
.obsidian/graph.json

# Python
__pycache__/
*.pyc
*.pyo
.pytest_cache/
.mypy_cache/
.venv/
venv/

# Secrets
.env
.env.*
*.env
*.secret
*.secret.json

# OS files
.DS_Store
Thumbs.db
desktop.ini

# Temporary files
*.tmp
*.bak
*.backup
*~
```

**Multi-source vaults** add Firecrawl scratch caches:
```gitignore
.firecrawl/
```

**Vaults with active polish loops** add temp script directory:
```gitignore
scripts/_polish_temp/
```

**Vaults with IDE/agent state** (projects with `.codex/`, `.gemini/`, `.cursor/`, `.swarm/`, `.ntm/`, `.vscode/`) — these are per-machine transient, not for backup:
```gitignore
.codex/
.cursor/
.gemini/
.gemini.mcp.json.*.bak
.ntm/
.swarm/
.vscode/
.claude/settings.local.json
```

Keep `AGENTS.md`, `CLAUDE.md`, `.skill-loop-progress-*.md`, and shared agent definitions in `.claude/agents/` — those are vault content, not local state.

### Initial commit + GitHub remote

```bash
cd /path/to/vault
git add -A
git commit -m "snapshot: initial backup of {vault-name}"
gh repo create <your-github-user>/{vault-name}-vault \
    --private \
    --description "{one-line description}" \
    --source=. \
    --remote=origin \
    --push
```

The `gh repo create --source=. --remote=origin --push` flow creates the remote, sets it as origin, and pushes the current branch in one step.

### Obsidian Git plugin install

For new vaults that don't yet have `.obsidian/`:

1. **Create plugin directory:**
   ```bash
   mkdir -p {vault}/.obsidian/plugins/obsidian-git
   ```
2. **Copy plugin files** from a working source (e.g., your PKM vault):
   ```bash
   cp ObsidianVault/.obsidian/plugins/obsidian-git/{main.js,manifest.json,styles.css,obsidian_askpass.sh} \
      {vault}/.obsidian/plugins/obsidian-git/
   ```
3. **Write `data.json`** with optimized settings (template below)
4. **Enable in `community-plugins.json`:**
   ```json
   ["obsidian-git"]
   ```

### Optimized plugin settings (data.json template)

```json
{
  "commitMessage": "vault backup: {{date}}",
  "autoCommitMessage": "vault backup: {{date}}",
  "commitDateFormat": "YYYY-MM-DD HH:mm:ss",
  "autoSaveInterval": 10,
  "autoPushInterval": 30,
  "autoPullInterval": 0,
  "autoPullOnBoot": true,
  "autoCommitOnlyStaged": false,
  "disablePush": false,
  "pullBeforePush": true,
  "showErrorNotices": true,
  "disablePopupsForNoChanges": true,
  "listChangedFilesInMessageBody": true,
  "showStatusBar": true,
  "syncMethod": "merge",
  "autoBackupAfterFileChange": false,
  "treeStructure": false,
  "basePath": ""
}
```

**Three settings worth calling out (improvements over plugin defaults):**

| Setting | Default | Recommended | Why |
|---|---|---|---|
| `autoPushInterval` | 0 (disabled) | **30** (minutes) | Closes the manual-push gap. Local commits without push leave work vulnerable if disk fails between commit and your next manual push. |
| `listChangedFilesInMessageBody` | false | **true** | Commit messages include the changed-file list — much better git log audit trail. Costs nothing. |
| `disablePopupsForNoChanges` | false | **true** | Silences "no changes to commit" notifications. The 10-minute interval triggers regardless; popups when there's nothing to commit are noise. |

**`autoBackupAfterFileChange: false`** — keep false even for agent-modified vaults. Setting it true triggers commits on every file change which spams the log when an agent writes 50 files in a minute. The 10-minute interval already captures changes; finer granularity is overkill.

### First-open setup (per vault, once)

When you first open a new vault in Obsidian:

1. Settings → Community plugins → "Turn on community plugins" (toggles off Restricted Mode)
2. The pre-installed obsidian-git plugin auto-loads with the optimized config
3. Verify: a "vault backup: ..." commit should fire within 10 minutes

This is unavoidable manual work — Obsidian's Restricted Mode is per-vault and there's no settings file to pre-disable it.

### Backup gap: agent-modified vaults

The Obsidian Git plugin only runs while Obsidian is open with that vault as the active window. For vaults primarily modified by agents (Claude Code subagents writing files via terminal, NOT through Obsidian), there's a backup gap when Obsidian isn't open.

Three patterns to close the gap:

1. **Manual discipline** — end every agent session with `git add -A && git commit -m "..." && git push` from terminal. Simple, requires habit.
2. **Scheduled task** — Windows Task Scheduler running a script every N minutes that commits + pushes. Independent of Obsidian. Best for vaults heavily modified outside Obsidian.
3. **Wrapper in agent prompts** — instruct execution agents to commit + push at end of each session. Manual to set up but automated once configured.

Pattern 1 is simplest. Use 2 if you forget often. Pattern 3 needs explicit instruction in each bead's WHAT TO DO step.

### Sunset path

When a vault becomes inactive (project complete, pivot away from domain), it can stay on GitHub indefinitely as a frozen archive. Last-state-pushed remains accessible. No need to delete the repo unless cleaning up the GitHub UI.

---

## Phase 2: Schema Design

Write `schema.md` BEFORE ingesting any files. It defines:

### Source classification types

Define types that fit your source material. Eight types worked well for cold-outreach: playbook, tactic, framework, research, case-study, template, principle, synthesis. PGA uses: framework, template, tutorial, case-study, faq, prompt, strategy, opinion. swipefile-vault uses pattern_types specific to copywriting moves.

Choose types that reflect actual content — don't force-fit.

### Signal scoring (1-5)

Define what signal measures for THIS vault. The signal criterion should be domain-specific:
- PGA: "EEC craft density — actionable methodology, templates, examples"
- cold-outreach v1: "How directly actionable for someone doing cold outreach today"
- cold-outreach v2: "Cold outreach craft density OR operational density OR offer-construction density"

Each level needs a one-sentence definition AND an example of what qualifies. The critical distinction is 5 vs 4 ("can you copy-paste it" vs "do you need to adapt it") and 4 vs 3 ("concrete do-THIS" vs "here's context").

**Post-culling signal distribution will NOT be bell-shaped.** Before culling, aim for a bell curve (more 3s than 5s). After culling with per-operator caps, signal 4-5 files concentrate because signal 3 is capped at 10/operator and signal 5 is uncapped. This is by design — the cull preserves the highest-value files.

### Layered tags (boolean overlays)

Three boolean tags that cross-cut classification types:
- `has_template` — contains fill-in-the-blank artifact or operational playbook
- `has_evidence` — includes quantitative data, A/B results, metrics, campaign outcomes
- `has_example` — includes concrete worked example (named company, specific scenario)

These enable queries like "give me all signal 4+ files that have templates" regardless of type.

### Topic tag vocabulary — emergent expansion methodology (v2-introduced)

Define an INITIAL closed set of topic tags (cold-outreach v1 used exactly 20). Read from schema.md at runtime, never hardcoded in scripts. The fixed set prevents tag sprawl.

**v2 introduced emergent vocabulary expansion:** new tags are NOT pre-decided when widening scope. Instead, they emerge during F.2 calibration when the classifier reports `tag_fit_confidence: low` clustered around the same conceptual territory.

The mechanism:
1. Calibration sample includes content from all in-scope domains.
2. F.2 classification prompt asks for `tag_fit_confidence` (high/medium/low) and a `tag_gap_note` string per file.
3. Patterns where 3+ files report low confidence on the same conceptual gap → propose a new tag.
4. Tags appended to schema.md vocabulary with rationale logged in wiki/log.md.
5. C.2 prompt template variable `{topic_tag_vocabulary_from_schema_md}` picks them up automatically at runtime — no prompt edit needed.
6. Re-calibrate under updated vocabulary. Required >=90% high-confidence agreement before locking.

Could be 0 additions (existing vocabulary covers new content) or many. Data decides.

Tags should be specific to the domain, not generic. "cold-email-structure" not "email." "psychology-reciprocity" not "psychology."

### Filename convention

Standardize filenames: `{operator}-{type_code}-{slug}-{yyyymmdd}-{id_suffix}.md`

Type codes: `tw` (tweet), `thr` (thread), `yt` (YouTube transcript), `art` (article — both Twitter Articles and web articles), `pod` (podcast), `book` (book notes), `syn` (synthesis).

The slug comes from a slugify function: lowercase, spaces to hyphens, strip punctuation, cap at 60 chars at word boundary. The id_suffix (last 6 chars of source ID) prevents collisions.

### Frontmatter schemas (per file type)

Define separate schemas for:
- **Raw files:** acquisition fields (operator, source, source_url, source_id, date_posted, date_ingested, **acquisition_method** (v2)) + classification fields (type, signal, tags, layered tags, parent_moc, **tag_fit_confidence**, **tag_gap_note** (v2)) + source-specific fields (is_reply, contains_image, etc.)
- **Concept pages:** type, signal (always 5), operators (2+), source_files, canonical_statement
- **Synthesis files:** no operator field, synthesis-specific fields

**v2 acquisition_method enum:** `dev-browser-defuddle` (Twitter Articles), `apify-tweet-scraper` (Twitter timeline), `yt-dlp-defuddle` (YouTube), `firecrawl-batch` (web blogs).

**Key pattern:** acquisition fields are populated at finalization (B.14). Classification fields are set to null initially and populated during classification (F.2). This two-phase approach lets validation check each phase independently.

### Query workflow, cross-vault references, health metrics

Define how downstream pipelines read the vault, how to link across vaults (dual format: Obsidian wikilink + file:/// markdown link), and a health metrics table with Target and Actual columns.

**The Query Workflow section MUST name both entry points explicitly:**

1. **Catalog entry — `wiki/index.md`.** Master catalog table (filename, operator, type, signal, tags, parent MOC for every file). Use when scanning for files matching a filter, or when you don't yet know which MOC covers the topic.
2. **Topical entry — `wiki/mocs/`.** One MOC per domain. Use when you know the topic area and want the curated, signal-ranked reading list.

Then the common drill-down: concept pages (`canonical_statement` + `source_files`) → raw files (full content + frontmatter) → cross-vault references.

An agent landing in a fresh vault reads `AGENTS.md` first, then `schema.md`. If the Query Workflow section only names MOC-first navigation, the agent may never discover `wiki/index.md` — which is the highest-leverage single navigation file. Document both.

---

## Phase 3: Acquisition (multi-source vaults)

Skip this for authored vaults where source files already exist.

### Acquisition tools and their quirks

**Twitter timeline (Apify `apidojo/tweet-scraper`):**
- Verify the actor works BEFORE running production scrapes. Run a 10-tweet test, check field schema.
- Fields like `inReplyToId`, `quote`, `entities.media` are absent (not null) on non-applicable tweets.
- Language filter (`tweetLanguage: 'en'`) is imperfect — Twitter assigns `lang: 'zxx'` to URL-heavy tweets.
- Use `ApifyClientAsync` for true async. Cost: ~$0.0004/tweet.
- `maxItems: 5000` per operator is a safe ceiling. Log if pagination limit hit.
- **Apify does NOT capture Twitter Article bodies.** It captures article-shaped tweets but only the `t.co` stub URL — the actual long-form content is not in the response. v1 cold-outreach correctly excluded these as `link_share_no_commentary`. v2 introduced the dev-browser+defuddle pattern below to capture article bodies.

**Twitter Articles (dev-browser scroll-extract + defuddle — v2-introduced):**
- Twitter Articles are long-form posts with URL pattern `/{user}/status/{id}` (same as tweets — distinguishable only by being on the user's `/articles` tab). Render client-side as React SPA.
- Acquisition is two-stage:
  1. **URL mapping:** dev-browser navigates to `https://x.com/{handle}/articles`, scrolls progressively (1000px increments, 1500ms waits), extracts `a[href*='/status/']` URLs from rendered DOM, accumulates with dedup until stable for 6 rounds.
  2. **Body extraction:** defuddle parse on each individual URL → clean markdown.
- dev-browser depends on persistent Twitter login (Playwright profile state). Phase A.0 pre-flight verifies login is current.
- dev-browser **cannot run multiple browser instances** reliably against the same Twitter session. Article URL mapping is sequential per operator. Body extraction (defuddle) IS parallel.
- defuddle artifact: linkifies plain-text mentions like "pipelineiq.com" inside article bodies into spurious `/status/` URLs. Cosmetic — strip in post-process.
- **Firecrawl does NOT work on Twitter** (confirmed in v2 testing). dev-browser+defuddle is the only working approach for Twitter Articles content.

**YouTube (yt-dlp):**
- `extract_flat: True` on a channel URL returns TAB entries (Videos, Shorts, Live), not individual videos. You must point at the `/videos` tab URL and use `extract_flat: 'in_playlist'` to get individual video metadata.
- Flat extraction does NOT include subtitle/caption metadata. Check captions at transcription time, not selection time.
- Video selection criteria that worked: duration 3-45 minutes + keyword match in title + English captions available. This filters shorts (<3min, no captions) and marathon podcasts (>45min, low density).
- **v2 raised primary cap from 20 to 25 per operator** to accommodate operational content alongside craft.
- For mixed-content operators (e.g., Marco Renwick whose videos blend tactical content with heavy program promotion): pre-screen titles for pitch markers, halt that operator's transcript ingestion if spot-check shows >40% pitch density.

**Web blogs (Firecrawl):**
- API uses keyword arguments: `fc.batch_scrape(urls, formats=['markdown'])` — not a params dict as second arg.
- For blog enumeration: `fc.map(blog_root_url)` returns full URL list. Filter to in-scope (e.g., `/blogs/{slug}` paths).
- Then `fc.batch_scrape(urls, formats=['markdown'], poll_interval=2, wait_timeout=300)` for content.
- Beehiiv and other React SPAs require Firecrawl's headless mode. `curl` + defuddle will NOT work on JS-rendered sites.
- defuddle does NOT work on `raw.githubusercontent.com` URLs (plain text, not HTML).

**Transcription (defuddle + yt-dlp subtitle fallback):**
- defuddle is the primary tool for YouTube transcripts. Fallback: yt-dlp subtitle download + `strip_subtitle_timestamps.py`.
- Both tools depend on existing caption tracks — neither transcribes audio.
- yt-dlp prefers manual subtitles over auto-generated when `writesubtitles=True` comes before `writeautomaticsub=True`.
- Auto-captions are readable for English content. Spot-check 3 random transcripts per operator before proceeding.

### Async parallel acquisition

Use `asyncio.gather` with `return_exceptions=True` for concurrent API calls. Wrap synchronous SDKs (yt-dlp, firecrawl) in `loop.run_in_executor`. Pattern:

```python
jobs = {
    "B.1": fetch_twitter_delta("operator1", start_date),
    "B.2": fetch_twitter_delta("operator2", start_date),
    "B.3": list_youtube_delta("channel_url1", "operator", last_video_date),
    "B.5": list_youtube_full("channel_url2", "operator"),
    "B.6": fetch_blog_map_and_scrape("blog_root_url"),
}
results = await asyncio.gather(*jobs.values(), return_exceptions=True)
```

If one job fails, others still complete. Log failures, retry individually.

**Twitter Articles URL mapping runs OUTSIDE the parallel block** (B.8 sequential per operator) due to dev-browser single-instance constraint. Body extraction (B.9) is parallel via concurrent.futures.ThreadPoolExecutor.

### Staging directory for raw outputs

Acquisition outputs go to `scripts/staging/` first (JSON for tweets, JSON for video metadata, markdown for articles/transcripts). Finalization (Phase B.14) moves them to `raw/` with proper filenames and frontmatter. This separation means a failed finalization doesn't corrupt staging data.

### Synthesis files as first-class inputs

Research synthesis files from the ObsidianVault (or other sources) can be copied into staging and finalized as `*-syn-*.md` files. They get the same classification treatment as scraped content.

### Operator-domains.json

Track each operator's website domains for the link-share EXCLUDE rule's exception. v2 adds new operator domains: priyasandhu → pipelineiq.com; elliotmarsh → pipelineiq.com (same — partners); marcorenwick → outreachfoundry.com, leadkit.io, marcorenwick.io; processforge → processforge.io.

---

## Phase 4: Finalization (B.14) — with mechanical body checks (v2)

Transform staging outputs into raw files with proper filenames and acquisition frontmatter.

### Tweet processing

- Filter retweets (never enter raw/)
- Detect threads: group by `conversationId`, combine tweets from same operator into `*-thr-*` files
- Download images for tweets with media (`entities.media` or top-level `media`)
- Set classification fields to null (populated in Phase 5)

### Twitter Article processing (v2)

- For each article URL with successful defuddle extraction:
  - Slug from article H1 heading (slugify per Section 4)
  - id-suffix: last 6 of numeric source_id from URL
  - Frontmatter populated with `acquisition_method: dev-browser-defuddle`
  - Body: defuddle markdown
  - contains_image: true if body has `![..]()` patterns
  - images: list of `pbs.twimg.com` URLs in body

### YouTube transcript processing

- Filename: `{operator}-yt-{slug}-{yyyymmdd}-{video_id}.md` (full YouTube video ID as id-suffix)
- Frontmatter `acquisition_method: yt-dlp-defuddle` (or `yt-dlp-subtitle-fallback` if fallback chain used)
- Detect partial transcripts via heuristic (last 100 chars without sentence terminator → `transcript_partial: true`)

### Web blog article processing

- Filename: `{operator}-art-{slug}-{yyyymmdd}-{id-suffix}.md` (id-suffix: 6-char hash of URL)
- Frontmatter `acquisition_method: firecrawl-batch`

### Mechanical body content checks (v2)

Run `scripts/validate_layer1.py --check-body` on every raw/ file before promoting:
- Body content >200 bytes (after frontmatter `---` close marker)
- Body contains at least one alphanumeric character
- Article files have a body section after frontmatter close
- Transcript files do not match known-stub patterns ("thanks for watching", "subscribe and like", "[music]" only)

Files failing checks route to `raw/_excluded/` with reason `mechanical_body_check_failed`. This complements the human-judgment B.12 spot-check with a mechanical filter that catches obvious garbage before subagent classification cost is paid.

### Validation gate

Run `validate_layer1.py --phase post-B.14 raw/` to verify all acquisition fields are present before proceeding to classification. Phase-gated validation means post-B.14 only checks acquisition fields; F.2 mode adds classification field checks.

---

## Phase 5: Classification (F.0.5 + F.1 + F.2) — subagent-only (v2)

Two-layer classification: signal filter first, then type/signal/tag assignment. v2 adds F.0.5 v1 _excluded re-evaluation for in-place migrations.

**v2 critical correction: ALL LLM work uses subagent invocation (Claude Code Task tool), NOT direct API calls.** The v1 BUILD-SPEC said "Sonnet 4.6" / "Opus 4.6" implying API; mid-execution correction propagated to v2 spec. Subagents handle batches up to 150 files, up to 5 concurrent.

### F.0.5 v1 _excluded re-evaluation (v2 in-place migrations only)

When v2 widens scope or adds a new acquisition method, v1 exclusions need re-evaluation:

**Rule 1 — Article stub replacement:**
For each v1 stub file in `raw/_excluded/` whose `source_id` matches a Twitter Article URL acquired in B.9: delete the stub. The full article file replaces it. Apply atomically.

**Rule 2 — Scope re-evaluation:**
For files excluded under v1 with reasons that are now in scope (e.g., `post_booking_nurture` becoming the operator's pre-call nurture work in v2): re-classify under v2 widened scope via Sonnet subagent. Decision returns one of:
- KEEP_EXCLUDED (out of scope under v2; reason updated to e.g., `client_post_discovery_call_nurture`)
- MOVE_TO_RAW (in scope under v2; classification fields cleared, will be populated in F.2)
- DELETE_FOR_REPLACEMENT (rare; for stubs only — Rule 1 territory)

### F.1 Signal Filter — mechanical EXCLUDE rules

Ten rules applied in order (first match wins). These are objective and automatable:

1. `retweet_without_commentary` — pure retweet
2. `bookmark_curation_thread` — lists bookmarks without analysis
3. `meta_discourse_no_actionable_content` — discusses topic without method
4. `link_share_no_commentary` — shares link with <20 words. Exception: operator's own domain (per operator-domains.json) → INGEST
5. `reply_too_short_no_insight` — reply <20 words without template/framework
6. `non_english_content` — majority non-English
7. `client_post_discovery_call_nurture` — (v2 renamed from `post_booking_nurture`) — work AFTER the discovery call ends, for the client's sales team to close. NOT the operator's pre-call show-rate nurture.
8. `discovery_call_content` — the call itself, not booking it
9. `agency_general_ops_unrelated_to_offer` — (v2 new) general agency operations not grounded in cold outreach (hiring, finance, retention beyond outreach ops, agency sales process)
10. `majority_out_of_scope` — <50% in-scope
11. `tangential_reference_only` — mentions topic in passing

STAGE files go to `_staging/` directories. EXCLUDE files go to `raw/_excluded/` and are logged in `wiki/excluded.md`.

### F.2 Classification — type, signal, tags, fit confidence (v2)

For each INGEST file, assign: type (from closed set), signal (1-5), tags (1-3 from topic vocabulary), layered tags (has_template, has_evidence, has_example), and (v2) tag_fit_confidence (high/medium/low) + tag_gap_note (string|null).

**Prompt calibration (Layer 2):** Write F.1 and F.2 prompts, store as versioned files in `wiki/prompts/`. Test on a calibration sample (cold-outreach v1: 23-24 files; v2: 30-31 files for broader corpus). Iterate until >=90% agreement. Lock the prompt version before production runs.

**Calibration sample recipe (v2):** Cover the diversity of your corpus including new operators and content types. Cold-outreach v2 used: 4 short tweets from primary op, 3 long tweets/threads, 3 short tweets from secondary op, 2 long tweets/threads, 2 Twitter Articles from primary op, 3 Articles from new op A, 2 Articles from new op B, 2 YouTube transcripts from new YouTube op, 2 web blog articles, 1 image-only tweet, 2 reply tweets, 2 delta YouTube transcripts, 1 synthesis, 1 bibliography, 2-3 known edge cases.

**Per-operator validation round (v2):** After Layer 2 calibration locks, run 10 random files from EACH operator's corpus under locked prompt. Required >=85% agreement per operator. Catches operator-specific bias missed by diversity-skewed calibration.

### Vocabulary emergence during calibration (v2)

Review F.2 outputs for `tag_fit_confidence: low` entries. Patterns where 3+ files in calibration sample report low fit on the same conceptual territory → propose a new tag. Append to schema.md vocabulary, log rationale in wiki/log.md. Re-calibrate under updated vocabulary; require >=90% high-confidence agreement before locking.

### JSON parse failure retry (v2)

Subagent classifier returning malformed JSON (truncated, embedded markdown blocks, malformed quoting): retry the SAME file once with the same prompt. On second fail, route to `raw/_excluded/` with reason `subagent_json_parse_failure`, log full subagent response, continue batch. Persistent parse failures across multiple files signal a prompt issue and trigger systematic-failure halt.

### Atomic write pattern

All frontmatter updates use temp-file-then-rename: write to `{path}.tmp`, `os.fsync`, then `os.replace`. Retry 3 times with 500ms delay on Windows if rename fails. Log failures to `wiki/failures.log`. This prevents half-written files on crash.

---

## Phase 6: Dedup + Culling (F.3 + F.4)

### F.3 Dedup (within-operator)

Group files by (operator, tag combination). Within each cluster of 3+ files, detect near-duplicates using subagent cluster judges (read-only, return survivors/redundant/extensions). Apply deletions atomically at end of F.3 (not per-cluster). Conflict rule: survivorship wins across clusters.

Scope: "covered better elsewhere" applies ONLY within the same operator. Cross-operator synthesis is handled in concept identification.

Cold-outreach v1 removed 51 duplicates from 627 files across 96 clusters.

### F.4 Signal-weighted culling

Apply per-operator caps: signal 5 unlimited, signal 4 max 15/operator, signal 3 max 10/operator.

Tiebreaker for which files to drop: (1) fewest layered tags (fewer true flags = less valuable), then (2) lowest topic-tag count.

Move excess to `raw/_cull_removed/` (recoverable). Log to `wiki/excluded.md`.

**Culling is aggressive by design.** Cold-outreach v1 went from 769 post-dedup files to 120 post-cull. This concentrates the vault on the highest-value files.

**Expect post-culling signal distribution to be top-heavy.** Signal 5 is uncapped, signal 3 is capped at 10/op. The pre-culling bell curve inverts. This is correct — the culling IS the prioritization.

---

## Phase 7: Cross-Operator Concept Identification (F.5)

This is the highest-value analytical step. It finds mechanisms that multiple operators discovered independently.

### Tag alignment (mechanical)

Group all signal 3+ files by topic tag combination across operators. Any combination with files from 2+ distinct operators is a concept candidate.

### LLM confirmation (Opus subagent)

For each candidate, read the files and confirm they describe the same craft mechanism. Reject if:
- Merely shared tags without shared mechanism (tag-match-only)
- Reply-pair only (one operator replying to another — reaction, not independent convergence)
- Verbatim duplication (>90% text overlap)
- Source files were culled (insufficient data)

### Concept page structure

```markdown
---
type: concept
signal: 5
tags: [{union of tags from contributing files}]
operators: [{2+ operator slugs}]
source_files: ['[[raw/file1.md]]', '[[raw/file2.md]]']
canonical_statement: 'One-sentence liftable synthesis'
---
# {Concept Name}
## Canonical Statement
## How It Works
## Operator Formulations (verbatim quotes per operator)
## Tensions (where operators disagree)
## When To Apply
## Related Concepts
## See Also (sibling vaults)
```

### Quality gate (three tests)

1. **Specificity:** canonical statement names a specific technique, not generic advice
2. **Source-dependency:** would the statement be indistinguishable from a Google search result without the sources?
3. **Tension:** if "all operators converge," verify it — reject pages that confirm agreement without synthesizing difference

Cold-outreach v1 produced 2 concepts from 4 candidates. v2's broader corpus (7 operators + ProcessForge) is expected to produce more. Low count is a valid outcome — it means few genuine cross-operator mechanisms exist. Do not force concepts to hit a target number.

---

## Phase 8: MOC Assignment (H) — with v1 archival (v2)

### v1 MOC archival (v2 in-place migrations)

Before H.1 restructures the active wiki/mocs/, archive current state via `scripts/archive_v1_mocs.py`:
```bash
cp wiki/mocs/*.md wiki/mocs-v1/
```

Idempotent: if mocs-v1/ already has files, log warning but do not overwrite.

### MOC structure finalization

Start with a provisional MOC hypothesis based on tag groupings AND prior version's MOCs (for migrations). Then apply mechanical restructuring triggers running on actual classified file distribution:

- **Keep** if no MOC contains >40% of signal 3+ files AND no MOC contains <3 files
- **Split** if any MOC >45% of files AND content naturally divides into sub-topics
- **Merge** if 2+ MOCs each have <5 files

Cold-outreach v1 expanded from 5 to 6 MOCs by splitting cold-message-craft (61% of files) into email-structure and personalization-craft. v2 expects 7-10 MOCs after operational and offer-construction content distributes.

### MOC file template

```markdown
---
type: moc
tags: [{tags this MOC covers}]
---
# {MOC Name}
## TLDR (2-3 sentences)
## Signal 5 (concepts first, then raw files)
## Signal 4 (grouped by tag)
## Signal 3 (grouped by tag)
## See Also (cross-MOC + cross-vault links)
```

### Parent MOC assignment

Run `assign_parent_moc.py` to tag every signal 3+ file, concept page, and synthesis file with its parent MOC. The script reads MOC frontmatter tags to build a tag-to-MOC mapping, then assigns based on tag overlap.

### Post-MOC distributional audit (Layer 3 dominance handling)

For each MOC, count signal 3+ entries by operator. If any operator exceeds **50% (v2 lowered from v1's 60%)** of any single MOC's signal 3+ entries, drop dominant operator's WEAKEST files from that MOC until under 50%. Weakest = lowest signal first, then lowest layered tag count. Files dropped: not deleted, but parent_moc set to null. They remain in raw/ as classified files but don't appear in any MOC.

---

## Phase 9: Index, Validation, Completion (I-J-K)

### Index generation

`generate_index.py` produces a pipe-delimited table: filename | operator | type | signal | tags | parent_moc. One line per raw file + concept page.

### Health metrics

Fill in the Actual column of schema.md's health metrics table. Record targets vs actuals honestly — deviations are lessons, not failures.

### Final validation (11 checks + v2-specific additions)

v1 checks (inherited):
1. `orphan_files` — every signal 3+ raw file appears in a MOC (body wikilinks, not just frontmatter)
2. `signal_3plus_in_moc` — every signal 3+ file has parent_moc set
3. `concept_in_moc` — every concept page has parent_moc set
4. `excluded_complete` — excluded.md exists and is populated
5. `bell_curve` — signal 4 is in the top 2 tiers (post-culling, not raw bell curve)
6. `moc_distinct` — no two MOCs have >50% tag overlap
7. `crossvault_resolve` — all file:/// links in MOCs resolve to existing files
8. `filename_collision` — all filenames in raw/ are unique
9. `yaml_valid` — all .md files have valid YAML frontmatter
10. `health_metrics` — schema.md health table has values (no empty Actual cells)
11. `batch_cap` — no batch exceeded 150 files

v2 additions:
12. `acquisition_method_correct` — Twitter Article files have `acquisition_method: dev-browser-defuddle`
13. `v1_stubs_deleted` — all v1 _excluded/ stub files for Twitter Articles are deleted (Rule 1)
14. `last_ingested_complete` — wiki/last_ingested.json has non-null timestamps for all sources
15. `article_urls_present` — wiki/article-urls/ has files for the 4 article-source operators (if applicable)
16. `mocs_v1_archive_present` — wiki/mocs-v1/ retains prior MOC archive
17. `spec_locked_status` — BUILD-SPEC.md has status: locked, prior version archived

### Build completion

Mark all phases complete in `phase-completion.json`. Write a build summary to `wiki/log.md` covering: total files, staged files, excluded files, concept pages, MOC structure, health metrics, methodology deviations, and total API cost.

For v2 builds, also update `wiki/last_ingested.json` with end-of-build timestamps so future delta runs operate from a known state.

---

## Phase M: Migration (v1 → v2 in-place — NEW)

When widening scope or adding new acquisition methods, prefer in-place migration over creating a new vault.

### Why in-place

- Existing raw/ files don't need to move — they're still valid sources
- wiki/index, MOCs, concepts can be regenerated
- Cross-vault references stay valid (no path changes)
- Audit trail preserved via *-v1.md archived files
- Significantly less migration friction than parallel-vault approach

### Migration phases (M.1-M.7)

**M.1 — Spec archival:**
1. `cp BUILD-SPEC.md BUILD-SPEC-v1.md`
2. Update v1 frontmatter: `status: archived`, `archived_on: {date}`, `superseded_by: BUILD-SPEC.md`
3. Author or rename new BUILD-SPEC.md (e.g., `mv BUILD-SPEC-v2-DRAFT.md BUILD-SPEC.md`)
4. Update v2 frontmatter: `status: locked`, `locked_on: {date}`

**M.2 — Schema migration:**
1. `cp schema.md schema-v1.md`
2. Update schema.md for new scope, new acquisition_method enum values, vocabulary emergence note
3. Add Migration History section listing prior versions

**M.3 — Existing raw file preservation:**
- NO modification to existing raw files
- Their classifications remain valid under updated schema (additive only)
- New emergent vocabulary added during F.2 calibration on broader corpus

**M.4 — Article stub cleanup (F.0.5 Rule 1):**
- Identify stub files in raw/_excluded/ whose source_id matches Twitter Article URLs acquired in v2 B.9
- Delete identified stubs; full article files take their place

**M.5 — v1 excluded re-evaluation (F.0.5 Rule 2):**
- For v1 exclusions with reasons that are now in scope: subagent re-classifies, decision applied atomically (KEEP_EXCLUDED or MOVE_TO_RAW)

**M.6 — Existing MOC re-evaluation (H.1):**
- v1 MOCs retained as v2 hypotheses; restructuring triggers run on combined file distribution
- v1 MOCs archived to wiki/mocs-v1/ before restructuring

**M.7 — Index regeneration (I):**
- wiki/index.md rewritten from scratch
- wiki/last_ingested.json populated for all operators with v2 run timestamp

### Rollback plan

If v2 build fails catastrophically mid-execution:
1. v1 BUILD-SPEC and schema preserved as `*-v1.md`. Restore by renaming.
2. raw/_excluded/ content retained until F.0.5 explicitly runs.
3. v2-acquired files in raw/ identifiable by filename pattern. Selective rollback possible.
4. wiki/ contents fully regenerable from raw/ via Phase F-K re-run.

---

## Phase D: Delta Ingestion (NEW)

After initial build, future content acquisition runs as delta — fetch only new content since last run.

### last_ingested.json schema

```json
{
  "operator-handle": {
    "platform": "twitter|youtube|twitter-articles|blog|...",
    "last_run": "YYYY-MM-DD",
    "last_tweet_id": "<numeric>",
    "last_tweet_date": "YYYY-MM-DD",
    "youtube_last_video_date": "YYYY-MM-DD",
    "articles_last_mapped": "YYYY-MM-DD",
    "blog_last_mapped": "YYYY-MM-DD"
  }
}
```

### Delta acquisition mechanism

**Twitter timeline operators:**
- Read `last_tweet_date`, set Apify `start: "{date+1}"`
- Fetch returns only newer tweets
- Deduplicate by `source_id` against existing raw/ files (safety net)

**Twitter Articles operators:**
- Re-run dev-browser scroll-extract
- Diff returned URL list against `wiki/article-urls/{operator}.txt`
- New URLs run through B.9 (defuddle) and F.1/F.2
- Update wiki/article-urls/{operator}.txt with full new list

**YouTube operators:**
- Read `youtube_last_video_date`, filter `upload_date > last`
- Run new videos through B.10/B.11/B.12/F.1/F.2

**Web blogs:**
- firecrawl `map` returns full URL list
- Diff against existing raw/ files by URL hash
- New URLs through B.13/F.1/F.2

### Delta and Phase F

New files run through F.1 → F.2 with locked prompts. Do NOT re-trigger F.3, F.4, F.5, H.1 unless F.6 distributional check flags an anomaly. New concept candidates at F.5 might emerge — main session evaluates whether to re-run F.5 across full corpus or accept new files as standalone.

After delta run, update last_ingested.json with new timestamps.

### Delta cost estimate

Per delta run (e.g., monthly): $2-10 ($0.20-1 Apify + $1-5 Sonnet classification on new files only). Significantly less than initial build's $20-100.

---

## Phase 10: Base Design

Design Obsidian Base views during the vault spec, not after the build. Bases are how humans browse the vault — without them, the vault is only accessible through Claude queries or manual file browsing.

### Standard Bases (create for every vault)

These 5 Bases work on any vault with the standard frontmatter (signal, type, tags, read):

| Base | Filter | Purpose |
|------|--------|---------|
| `signal-5.base` | signal == 5 | Highest signal content |
| `by-signal.base` | (all raw files) | All files sortable by signal |
| `by-type.base` | (all raw files) | Filter by classification type |
| `learning-queue.base` | read == false | Unread files sorted by signal |
| `high-value-unread.base` | read == false AND signal >= 4 | Top-priority learning |

### Domain-specific Bases (design per vault)

Based on the vault's query workflow (Section 4 of schema.md) and the frontmatter fields available. Common patterns:

- **Tag browser** — filter by topic tags
- **Template gallery** — has_template == true
- **Evidence/metrics view** — has_evidence == true
- **Framework collection** — type == "framework"
- **Case study browser** — type == "case-study"
- **MOC dashboard** — type == "moc" (cards view)
- **Acquisition method browser** (v2) — group by acquisition_method to see corpus composition

### Requirements for Base support

- All raw files MUST have `read: false` in initial frontmatter (added at B.14 finalization)
- The frontmatter schema in schema.md must include `read` as a documented field
- MOC files must have `type: moc` in frontmatter for the MOC dashboard Base
- Topic tags must be a fixed vocabulary (not ad hoc) for tag-based Bases to be useful

### Where Bases live

If the vault is part of a consolidated multi-vault Obsidian vault (e.g., AgentVaults/), Bases go in a shared `bases/` directory at the Obsidian vault root. If the vault is standalone, Bases go in the vault root or a `bases/` directory.

### BUILD-SPEC integration

Add a "Base Design" section to the BUILD-SPEC after the Validation section. List each Base with: filename, filter logic, columns, sort order, and which consulting/query workflow it supports.

---

## Multi-Vault Folder Topology

When you have multiple Obsidian vaults that share a parent directory (e.g., `AgentVaults/cold-outreach/`, `AgentVaults/pga/`, etc.), the parent directory should NOT itself be an Obsidian vault.

### Why parent-as-vault conflicts with per-vault setup

If `AgentVaults/` has its own `.obsidian/` AND each sub-vault also has its own `.obsidian/`:

1. **Indexing duplication.** Obsidian opening the parent vault indexes all sub-vault content INCLUDING their `.obsidian/` config dirs. Slows search, graph view, file picker. Sub-vault config files appear as regular files in the parent's tree.
2. **Plugin cross-talk if both are open.** If parent and one sub-vault are both open in different Obsidian windows, each runs its own obsidian-git plugin. They watch overlapping file sets. Phantom commits happen — the same file change can trigger commits in both `.git`'s.
3. **Plugin scope confusion.** Parent's obsidian-git with `basePath=""` would try to commit sub-vault files. You can block this with `.gitignore` at the parent level, but if you forget, double-tracking occurs.
4. **Merge conflict on shared files.** Anything visible in both vaults (cross-vault references, shared config snippets) can be modified through either vault. The `.obsidian` config files at parent level vs sub-vault level diverge silently.

### Plain folder pattern (recommended)

```
AgentVaults/                          ← plain folder, no .obsidian/, no .git
├── cold-outreach/                    ← Obsidian vault, own .obsidian/, own .git, own remote
├── pga/                              ← Obsidian vault, own .obsidian/, own .git, own remote
├── writewithai/                      ← Obsidian vault, own .obsidian/, own .git, own remote
├── newsletter-growth/                ← (same)
├── bases/                            ← (same)
├── swipefile-vault/                  ← project, own .git, own remote (vault optional)
└── _staging/                         ← global staging, own .git for backup, no .obsidian/
```

You open each sub-vault separately in Obsidian when you need it. No "uber vault" view.

### When unified workspace IS valuable (rarely)

Cross-domain queries — "what do my craft vaults collectively say about X?" Better solved by:
- A Python script that greps across multiple vault dirs
- An Obsidian Bases vault (`bases/` folder with `.base` files) configured to query specific paths across the parent dir — Bases works across multiple vaults if pointed at the right paths
- An LLM that reads multiple vaults sequentially during a session

None of these require a parent-as-vault setup.

### When demoting parent to plain folder

If a parent has historically been a vault but you want to demote:

```bash
# 1. Move any tracked content (e.g., active project) into its own repo
cd Parent/active-project
git init -b master
gh repo create user/active-project-repo --private --source=. --remote=origin --push

# 2. Delete parent .git (after confirming what was tracked is now in own repos)
rm -rf Parent/.git

# 3. Delete parent .obsidian (no longer a vault)
rm -rf Parent/.obsidian

# 4. Delete the now-meaningless parent GitHub repo (if it was its own repo)
gh repo delete user/old-parent-repo --yes
```

The demotion is reversible until you confirm and clean up. Each step's data is preserved on GitHub before deletion.

### Cross-vault references after demotion

The `[[vault-name:path/to/file]]` syntax remains a documentation convention (NOT clickable in Obsidian — neither parent-vault nor demoted-folder makes them clickable). Pair with `file:///` markdown links for clickable navigation per BUILD-SPEC §2.

---

## Git Hygiene & Lessons

### Audit before pushing >1GB

Before `git push -u origin master` on a large repo, check the `.git` size:

```bash
du -sh .git
```

If >1GB, audit what's making it big:
```bash
du -sh .git/* | sort -hr
git rev-list --objects --all | head -20
git count-objects -vH
```

For build-once subject-matter vaults where current state is the goal (not history): a fresh `git init` is acceptable per "current state only" intent. Lose history, gain manageable repo size.

The trigger pattern: OutreachVault had a 5.5GB `.git` from accumulated historical large files. Push would have exceeded GitHub's 2GB single-push limit AND taken hours over home internet. Solution: `rm -rf .git && git init && git add -A && commit && push` produced a clean current-state-only repo at ~700MB.

### Catch nested .git's during initial commit

When initializing a parent vault, `git status` may show sub-directories as untracked. If those sub-directories have their OWN `.git`, the parent will commit them as **submodule references** (mode `160000`) rather than tracking their files inline.

Symptom: parent commit creates entries like `create mode 160000 SubDir` with byte-counts way smaller than the actual content.

Resolution depends on intent:
- **Subdirectory should be its own independent repo** → gitignore it from parent. Parent doesn't track it; subdir's own `.git` handles backup.
- **Subdirectory should be tracked inline by parent** → remove the subdir's `.git` (`rm -rf SubDir/.git`), then `git add SubDir` from parent. Loses sub-repo's history.

Discovered when OutreachVault parent was initialized: `Prospects/` showed as `mode 160000` because it had its own `.git` already (`<your-github-user>/prospects` remote). Resolved by adding `Prospects/` to parent `.gitignore` — keeps independent repo, parent `.git` just covers `Clients/`.

### Per-vault .gitignore lifecycle

Start lean. Add patterns as bloat surfaces:

1. **Initial commit**: just the obvious — Obsidian per-machine, beads SQLite, secrets, OS files.
2. **First push >100MB**: identify large files via `find . -type f -size +50M`. Either keep (small enough) or gitignore (recoverable from source).
3. **First push >1GB**: aggressive — gitignore any directory matching scraped-binary-asset patterns (PNG screenshots, raw video, audio, large JSON dumps that can be re-fetched).
4. **Periodically**: `git rev-list --objects --all | sort -k1 | head -20` to find any blobs that crept into history.

### Recoverable vs essential content

When deciding what to gitignore, ask: "If this is lost, can I reproduce it?"

| Content | Recoverable? | Default action |
|---|---|---|
| Web-scraped HTML/PNG screenshots | Yes (re-scrape from web) | Gitignore unless small/few |
| Raw scraped JSON (LinkedIn posts, Twitter timeline) | Maybe (Apify dataset retention is 7 days) | Track if <50MB total |
| YouTube transcripts | Yes (re-run yt-dlp + defuddle) | Track (small text) |
| Defuddle markdown of Twitter Articles | Re-acquirable via dev-browser+defuddle | Track (small text) |
| Operator-authored content (markdown, deliverables) | NO — irreplaceable | Always track |
| Python scripts | Tracked in repo; `.git` is the source of truth | Always track |
| Test fixtures (golden files for regression) | Generated from acquisition; can re-derive | Track if needed for build reproducibility |
| `.beads/*.db` SQLite | Yes, regenerable from `issues.jsonl` via `br sync` | Always gitignore (binary) |
| `.beads/issues.jsonl` | NO — bead history source of truth | Always track |

Example: OutreachVault's `Clients/Client A/design-reference/` was 2.8GB of Frame.io / VEED screenshots scraped for design inspiration. Recoverable from web. Gitignored. The actual deliverables (specs, docs, research) total <2MB and ARE tracked.

---

## Polish Loop Methodology

After bead creation but before bead execution, run an iterative polish loop. Each pass focuses on a single quality lens. Multiple passes catch what single-pass review misses.

### When to run polish

After initial bead creation completes, before any bead's `--status in_progress`. Polish is plan-space refinement; it's much cheaper than fixing during implementation.

### 8-pass mission catalog (proven)

Per-pass mission, with the underlying concern each addresses:

| Pass | Mission | What it catches |
|---|---|---|
| 1 | **Test coverage** | Beads with implicit "verify" steps but no explicit unit/e2e/integration tests. Polish prompt explicitly asks: "comprehensive unit tests and e2e test scripts with great, detailed logging." |
| 2 | **Failure mode comprehensiveness** | Generic "halt and investigate" failure modes. Replaces with realistic-failure-scenarios + recovery procedures + escalation paths + partial-success handling + resumability + cross-bead cascade + idempotence + critical-vs-tolerable gap + cost-related failures. |
| 3 | **Edge case coverage** | Empty/zero-input cases, boundary values, race conditions, type/encoding edge cases, mid-run state, operator-specific edge cases. Different from Pass 2 — these are VALID inputs the bead's logic doesn't anticipate. |
| 4 | **Logging and observability** | Mid-execution progress for long-running phases (>30 min batches), per-batch counts, per-file diagnostic logs, structured key=value format, ISO timestamps, resume-relevant logging. |
| 5 | **Atomicity and resumability** | State files explicit (paths, schemas), resume detection predicate per bead, idempotence forward + reverse. (This pass stalled on a 9-section initial scope; retry with 3-section scope succeeded — see anti-patterns below.) |
| 6 | **Cross-bead consistency** | Bead references match (IDs, schema fields, file paths). Naming inconsistencies across beads (e.g., `yt-dlp-defuddle` vs `defuddle-youtube`). BUILD-SPEC section references still valid post-rename. |
| 7 | **Concrete commands and explicit paths** | Vague "run the tool" replaced with copy-paste-able CLI invocations. Env var prerequisites named. Subagent invocation pattern shown explicitly. |
| 8 | **Holistic + wall-clock + anti-pattern weaving** | Final check. Wall-clock estimates per bead. AGENTS.md anti-patterns mapped to specific beads. Test fixture capture step assigned. Final dependency graph cycle check. |

### Orchestration: `repeatedly-apply-skill`

The Claude Code skill `repeatedly-apply-skill` orchestrates the loop. Per pass:

1. Plan the mission (from the catalog above)
2. Launch a subagent with mission-specific prompt
3. Subagent does the work, returns report
4. Orchestrator verifies + commits + updates progress file
5. Launch next pass

Strictly serial — never parallel. Each pass changes the bead descriptions; next pass must see those changes.

### Progress file pattern

`.skill-loop-progress-{YYYY-MM-DD}-{skill-name}.md` at vault root. Single source of truth for loop state. After compaction, the agent reads it first to resume from the right pass.

```markdown
# Skill Loop Progress
# Skill: beads-workflow polish
# Target: cold-outreach v2 beads (label=v2, count=22)
# Total Passes: 8
# Started: 2026-04-27

## Status: IN PROGRESS — Pass 5 of 8

## Missions
1. **Test coverage** — ...
2. **Failure mode comprehensiveness** — ...
...

## Completed Passes

### Pass 1 — Test Coverage — 2026-04-27 / 00:48
- Beads modified: 22 / 22
- Verdict: PRODUCTIVE
```

Use a dated filename per loop run; never overwrite a previous loop's progress file (audit trail value).

### Anti-pattern: stalling on overly-broad scope

Pass 5 (atomicity and resumability) initially asked the subagent to add 9 sub-categories per bead. The subagent stalled — too much planning before any writing started. Watchdog killed it after 600s of no progress.

Resolution: re-launch with **narrowed scope** (3 sub-categories per bead instead of 9). Subagent succeeded in 30 minutes.

Lesson: per pass, give the subagent at most 3-5 concrete deliverables per bead. If a pass needs more, split it into two passes.

### Anti-pattern: `br update --description` size limit on Windows

`br update <id> --description "..."` on Windows hits the command-line length limit (~28KB) when bead descriptions exceed that. Polish passes 6+ surfaced this — many beads grew past 28KB after passes 1-5.

Resolution: direct SQLite writes to `.beads/beads.db` instead of the `br update` CLI. Pattern:

```python
import sqlite3, json
from pathlib import Path

VAULT = Path(r"C:\Users\<you>\Documents\AgentVaults\cold-outreach")
conn = sqlite3.connect(VAULT / ".beads" / "beads.db")
cur = conn.cursor()
cur.execute(
    "UPDATE issues SET description = ?, updated_at = datetime('now') WHERE id = ?",
    (new_desc, bead_id),
)
cur.execute(
    "INSERT OR IGNORE INTO dirty_issues (issue_id) VALUES (?)",
    (bead_id,),
)
cur.execute(
    "INSERT INTO events (issue_id, event_type, payload, occurred_at) "
    "VALUES (?, 'description_updated', ?, datetime('now'))",
    (bead_id, json.dumps({"length": len(new_desc)})),
)
conn.commit()
conn.close()
```

Then run `br sync --flush-only` to flush the dirty state to JSONL for git tracking.

This pattern bypasses the CLI limit while preserving br's auto-sync semantics.

### Anti-pattern: don't commit per-pass for un-tracked vaults

The orchestration skill's default is `git commit` per pass for audit trail. For vaults that aren't yet under git (the case during cold-outreach v2 polish — the parent vault was untracked), skip commits. Track progress via the progress file + `.beads/.br_history/`.

After backup setup completes (each vault has its own remote), enable per-pass commits via the skill default.

### Stop conditions

Per skill defaults:
- Pass cap reached (K == N) → stop, complete
- Two consecutive ZERO-CHANGE passes → stop, convergence
- Thrashing (same lines flipping back and forth) → stop, conflicting criteria
- User-specified target met → stop, goal reached

For bead polish, 8 passes have been productive end-to-end on a 22-bead corpus. Don't run more than 9 unless specific evidence the corpus needs more.

---

## Utility Scripts

A multi-source vault needs a mechanical backbone. v1's ten scripts plus v2's additions:

**v1 inherited:**
| Script | Purpose |
|--------|---------|
| `slugify.py` | Filename slug generation (importable + CLI) |
| `validate_layer1.py` | Phase-gated schema validator (post-B.14 and F.2 modes); v2: adds `--check-body` for mechanical body checks |
| `phase_status.py` | Read/write phase completion JSON |
| `atomic_write_frontmatter.py` | Atomic YAML frontmatter update (temp+rename, 3x retry on Windows) |
| `strip_subtitle_timestamps.py` | SRT/VTT → clean plaintext |
| `cull_f4.py` | Signal-weighted dominance culling |
| `aggregate_distribution.py` | Per-operator/signal/type/tag distribution stats |
| `assign_parent_moc.py` | Tag-to-MOC mapping + parent_moc assignment |
| `generate_index.py` | Vault index table generation |
| `validate_final.py` | 11-check final validation suite (v2: adds 6 more) |

**v2 additions:**
| Script | Purpose |
|--------|---------|
| `dev_browser_articles.py` | Wraps dev-browser scroll-extract for Twitter Articles URL mapping; one operator per invocation |
| `defuddle_articles.py` | Reads URL list from wiki/article-urls/{operator}.txt, parallel defuddle (max 5 concurrent), writes raw/{operator}-art-... files with frontmatter |
| `reevaluate_excluded.py` | F.0.5 driver for v1 _excluded re-evaluation; subagent batches with Rule 1 (stub deletion) and Rule 2 (scope re-eval) decisions |
| `archive_v1_mocs.py` | Pre-H.1: copies wiki/mocs/* to wiki/mocs-v1/ for migration audit trail |

Conventions: argparse with `--help`, explicit file paths (no implicit cwd), exit 0/1, errors to stderr, mutation scripts use atomic writes, read-only scripts never modify files, topic tags read from schema.md at runtime.

These scripts are vault-specific but the patterns are portable. Copy and adapt for new vaults.

---

## AGENTS.md convention

Every vault gets an `AGENTS.md` file at the vault root. New convention as of v2: prefer `AGENTS.md` over `README.md` for agent-targeted vaults.

**Why AGENTS.md, not README.md:**
- README.md convention is human-targeted (open source repo onboarding)
- AGENTS.md is the convention adopted by Codex and other coding-agent tools as the project-level orientation file
- Beads-workflow polish prompts read AGENTS.md on every round ("Reread AGENTS dot md so it's still fresh in your mind")
- Removes ambiguity about what's for who: AGENTS.md is unambiguously for any AI agent working in the project

**Sections** (see Phase 0 AGENTS.md authoring above for the full list — copy that pattern):

1. What this vault is (one-paragraph mission)
2. Current state (phase, bead state, file counts)
3. Operator profile (who, communication preferences, process preferences)
4. Agent role by phase (planning vs polishing vs executing matrix)
5. Key files & where to look (table with mutation rules)
6. Tools (table + per-tool gotchas)
7. Conventions
8. Anti-patterns (table of don't-do-X / why)
9. What done looks like (pointer to BUILD-SPEC success criteria)
10. Sibling vaults (cross-reference guidance)

**Length target:** 150-300 lines. Long enough to be useful, short enough that an agent rereads it without fatigue. Heavily linked out — point to BUILD-SPEC for spec details, point to schema.md for vocabulary, point to specific bead IDs for current execution state.

**Mutability:** AGENTS.md evolves with the project. Phase transitions, new conventions, new anti-patterns. Update `last_updated` field on every modification. Reference the change in wiki/log.md.

---

## What NOT To Do

- **Don't skip the build spec for multi-source vaults.** The cold-outreach v2 build spec was 1,586 lines. Without it, you'll rediscover edge cases mid-build.
- **Don't make direct Anthropic API calls.** All LLM work uses Claude Code Task tool subagent invocation. Per global CLAUDE.md preference and v2 BUILD-SPEC §13.
- **Don't pre-decide new tag vocabulary when widening scope.** v2 introduced emergent vocabulary expansion via F.2 calibration's tag_fit_confidence reports. Pre-deciding tags conflicts with the methodology.
- **Don't expect Apify to capture Twitter Article bodies.** Apify captures article-shaped tweets but only as t.co stub URLs. v1 cold-outreach had 11 stubs in _excluded/ - the actual content was lost until v2 introduced dev-browser+defuddle.
- **Don't try to use Firecrawl on Twitter.** Confirmed not working as of 2026-04-27. Use dev-browser+defuddle.
- **Don't run dev-browser article mapping in parallel across operators.** Single browser instance constraint against the same Twitter session. Sequential per operator. Body extraction (defuddle) IS parallel.
- **Don't skip per-operator validation round in F.2 calibration.** Catches operator-specific bias missed by diversity-skewed calibration sample. Particularly important for builds with many new operators.
- **Don't use `extract_flat: True` on YouTube channel root URLs.** You get tab entries, not videos. Point at `/videos` tab with `extract_flat: 'in_playlist'`.
- **Don't pass Firecrawl params as a positional dict.** Use keyword arguments: `formats=['markdown']`.
- **Don't assume YouTube auto-captions are garbage.** Spot-check showed 3/3 readable English. Auto-captions are fine for cold outreach content.
- **Don't expect a bell curve after culling.** Signal 5 is uncapped, signal 3 is capped at 10/op. The distribution inverts by design.
- **Don't force concept page count to hit a target.** Cold-outreach v1 produced 2 concepts from 4 candidates. The quality gate (specificity, source-dependency, tension) matters more than count.
- **Don't summarize raw files.** The raw files ARE the knowledge. Index one-liners and MOC wikilinks are enough for navigation.
- **Don't over-engineer the schema.** Start lean, but for multi-source vaults you DO need all three frontmatter schemas (raw, concept, synthesis) defined upfront.
- **Don't deep-read every file during classification.** F.1 EXCLUDE rules are mechanical. F.2 subagent classification handles the bulk. Save human judgment for calibration samples and concept confirmation.
- **Don't skip mechanical body checks at B.14.** Catches obvious garbage (defuddle returning stubs, transcripts with only outro spam) before subagent classification cost. v2 GPT Pro review #2 kernel.
- **Don't take generic enterprise advice from review passes literally.** v2's GPT Pro review proposed ML-driven signal filtering (regression - the Sonnet subagent IS the ML approach), context-aware dynamic tags (conflicts with controlled vocabulary), and other generic enterprise patterns that don't fit a build-once subject-matter vault. Integrate kernels surgically, push back on misreads.
- **Don't write SOPs early.** Wait until a process is run 50-100 times before SOP-ing it. Early SOPs go stale within a week as the process evolves. v1's "Write Utility Scripts" bead is the boundary — scripts get written, not SOP-ed, until they're stable.
- **Don't make a parent folder an Obsidian vault when it contains independent sub-vaults.** Nested `.obsidian/` + per-sub-vault `.obsidian/` causes indexing duplication, plugin cross-talk if both opened, and merge conflicts on shared config. Demote parent to plain folder; each sub-vault is independent. See "Multi-Vault Folder Topology" section.
- **Don't push 1GB+ git histories without auditing for bloat.** Run `du -sh .git` before push. If >1GB, identify what's bloating it. For build-once vaults, fresh-init is acceptable per current-state-only intent.
- **Don't run polish passes with 9-section missions.** Subagent stalls on overly-broad scope. Narrow to 3-5 concrete deliverables per bead per pass. Pass 5 atomicity attempt #1 (9 sections) stalled at 600s; retry with 3 sections succeeded in 30 min.
- **Don't `br update --description` for descriptions exceeding 28KB on Windows.** CLI length limit. Use direct SQLite writes to `.beads/beads.db` with `dirty_issues` + `events` row inserts.
- **Don't auto-commit-per-pass before vault git is set up.** The orchestration skill's default commit-per-pass requires git to exist. Skip during initial polish if the vault is not yet under git; rely on progress file + br history for audit.
- **Don't trust the Obsidian Git plugin to back up agent-modified vaults.** The plugin only fires when Obsidian is open with that vault. Agents writing files via Claude Code (Obsidian closed) don't trigger backup. Close the gap with manual `git add -A && commit && push` post-session, or scheduled task, or wrapper in agent prompts.
- **Don't assume "plugin installed" = "vault is being backed up."** Plugin requires Obsidian to be open with that vault active. Verify backup with `git remote -v` (does it have a remote?) and `gh api repos/{user}/{repo}/commits --jq '.[0].commit.author.date'` (last commit date on remote).

---

## Lessons Learned: Cold-Outreach v1 (2026-04-11)

**What went well:**
- Beads dependency graph prevented out-of-order execution across 16 phases
- Async parallel acquisition cut wall-clock time (5 API calls in parallel)
- Heuristic classifier achieved 100% agreement with Opus on 23-file calibration sample
- Content fingerprinting caught 51 near-duplicates that would have inflated the corpus
- Mechanical EXCLUDE rules removed 49 low-value files before any judgment calls

**What surprised us:**
- yt-dlp `extract_flat` on channel root returns tab metadata, not video metadata. Cost 15 minutes of debugging.
- Firecrawl API changed to keyword-only arguments. The old `batch_scrape(urls, {"formats": [...]})` pattern broke. Always check SDK signatures.
- Aggressive culling removed 85% of files (869 → 120). This felt extreme but produced a focused, high-signal vault.
- Only 2 cross-operator concepts from 4 candidates. Most "shared tags" are coincidental, not convergent mechanisms.
- quicklinescopy (third operator) contributed 0 files — channel had only YouTube Shorts, all under 3 minutes. Operator selection should verify long-form content exists.
- 11 Terrence Ashgrove article-shaped tweets ended up in _excluded/ as content-less stubs. Only discovered during v2 planning when investigating Twitter Articles acquisition.

**What we'd change:**
- Verify operator content volume before building beads (quicklinescopy was zero signal)
- Set up subagent-only execution from start (mid-execution correction)
- Define cross-vault reference targets more carefully — 0 refs when sibling vaults lack MOC files is a structural limitation, not a vault quality issue
- Consider raising signal 3 cap from 10/op to 15/op to retain more contextual files

---

## Lessons Learned: Cold-Outreach v2 (2026-04-28, planning phase)

**What v2 improved over v1:**
- Twitter Articles acquisition pattern (dev-browser scroll-extract + defuddle) — captures content that v1 lost as t.co stubs
- Emergent vocabulary expansion methodology — new tags emerge from F.2 calibration, not pre-decided
- Subagent-only execution language baked into spec from the start
- In-place migration pattern with v1 archival (BUILD-SPEC-v1.md, schema-v1.md, mocs-v1/)
- Delta ingestion mechanism with last_ingested.json
- Mechanical body content checks at B.14 (catches garbage before subagent cost)
- JSON parse failure retry on subagent return (resilience)
- Per-operator validation round (catches operator-specific bias)

**What surprised us:**
- Most generic AI-coding-tool reviewers (GPT Pro Extended Reasoning) propose enterprise patterns that don't fit a build-once subject-matter vault. Out of 9 proposed revisions, 0 were wholehearted-agree, 3 had small kernels worth integrating, 6 were misreads or proposed regressions. Don't take review passes literally — surface kernels, push back on the rest.
- Apify silently captures Twitter Articles as t.co stubs without warning. Required deep investigation of v1 _excluded/ to discover. Always inspect what an acquisition tool actually returns vs what you expect.
- dev-browser login state is the most fragile dependency in v2. Pre-flight verification at A.0 is critical — failure mid-B.8 would be hard to diagnose.
- Twitter usernames are case-insensitive in URLs but case-sensitive in regex. One operator's articles-tab URLs used their handle in all lowercase, while the vault's own frontmatter recorded their display name in mixed case — a naive exact-match regex missed the connection. Use a case-insensitive regex `/i` flag when matching a handle across both forms.

**What v2 didn't change (still right from v1):**
- Aggressive culling (signal-weighted caps with low signal-3 threshold)
- Cross-operator concept identification with 2+ operator threshold
- 8 classification types (didn't need to add an "operational" type — operational content distributes across existing types)
- Three-frontmatter-schema model (raw, concept, synthesis)
- 5-layer validation cadence

---

## Lessons Learned: Backup Setup (2026-04-28)

Discovered while setting up GitHub backups for the agent vaults that only ObsidianVault was actually backed up to GitHub. OutreachVault and AgentVaults were local-only. ~3000 files / ~200MB of agent vault work and months of swipefile-vault progress were one drive failure away from being lost.

**What we found:**

- Of 3 top-level vault parent dirs, only 1 was on GitHub (ObsidianVault PKM)
- AgentVaults parent had 81 manual commits over months (swipefile-vault project) but NO REMOTE — Obsidian Git plugin was installed at parent level but auto-fire wasn't catching the work patterns reliably
- OutreachVault `.git` was 5.5GB of historical bloat; current working tree was 4GB (3.5GB recoverable Client A client design-reference screenshots)
- OutreachVault/Prospects had its own nested `.git` already pushing to `<your-github-user>/prospects` — independently of the parent
- All 5 craft sub-vaults under AgentVaults (cold-outreach, pga, writewithai, newsletter-growth, bases) were UNTRACKED — the v1 BUILD-SPEC structure assumed they'd be tracked under AgentVaults parent `.git` but the parent never actively committed them

**What we learned:**

- "Obsidian Git plugin installed" ≠ "vault is being backed up." Plugin requires Obsidian to be open with the vault active. Agent-modified vaults don't trigger Obsidian's file watcher reliably.
- "Has a remote" matters more than "has commits." Local commits without push leave work vulnerable. `autoPushInterval=30` was the missing setting.
- Nested `.git`'s are easy to miss until `git status` shows mode 160000 references. Always inspect for sub-repos before initializing parent.
- Recoverable binary content (web screenshots, image references) can be the bulk of vault size. Audit before push; gitignore aggressively if the content is reproducible from web sources.
- The "all my vaults are backed up via Obsidian Git plugin" assumption needed verification, not trust. Concrete check: `for vault in vaults; do git remote -v; done`. Only ObsidianVault had a remote.

**What changed:**

- Each vault now has its own GitHub repo + remote (8 new repos created, 1 deleted as redundant)
- AgentVaults parent demoted from Obsidian vault → plain folder (no `.obsidian/`, no `.git`)
- `_staging/` moved out from under demoted parent into its own repo (`agent-staging-vault`) for global cross-vault staging
- Obsidian Git plugin pre-installed in 6 sub-vaults with optimized `data.json` (`autoPushInterval=30`, `listChangedFilesInMessageBody=true`, `disablePopupsForNoChanges=true`)
- ObsidianVault settings updated to match
- This methodology document updated with Phase B (Backup Infrastructure), Multi-Vault Folder Topology, Git Hygiene & Lessons, and Polish Loop Methodology sections

**What's still open:**

- First-open Obsidian setup per new vault (toggle off Restricted Mode) — manual UI step
- Backup gap for agent-modified vaults — solved by manual discipline post-session, scheduled task, or agent-prompt wrapper. Pattern not yet codified.
- OutreachVault Client A work product (design-reference dirs gitignored as recoverable) unbacked-up if Client A eventually needs the binary assets. Re-evaluate if active client work resumes.

---

## Concept Page Growth (Post-Ingestion)

Concept pages accumulate over time from four sources:

1. **Cross-operator detection** (F.5) — found during build when 2+ operators describe the same mechanism
2. **Implementation sessions** — when building a skill file reveals an insight worth preserving
3. **Pipeline runs** — when deliverable generation reveals patterns
4. **CASS session mining** — when `cass search` surfaces repeated techniques or failure modes

Each concept page must be grounded in real results: source files, operator quotes, or session references. The quality gate (specificity, source-dependency, tension) applies to all sources.

---

## Where This Fits

Vault creation is a PREREQUISITE — not a phase within any other methodology. Create the vault in a separate session before starting the deliverable spec process.

- The [[deliverable-spec-methodology]] Phase 1 (Vault Grounding) requires vaults to exist
- The [[pipeline-construction-methodology]] lists vault creation as a prerequisite before Phase 0
- The mining layer (designed after all output specs are complete) reads from vaults for timeless craft knowledge

---

## Existing Vaults

| Vault | Path | Scope | Files | MOCs | Type | Remote | Last build |
|-------|------|-------|-------|------|------|--------|------------|
| ObsidianVault (PKM) | `Documents/ObsidianVault/` | Personal knowledge — scratch, mine, clippings, dialogues, references, daily | n/a | n/a | Authored (PKM) | github.com/<your-github-user>/obsidian-pkm-vault | active |
| WriteWithAI | `AgentVaults/writewithai/` | Writing craft — copywriting, hooks, headlines, structure, editing, voice, email, newsletters | 396 | 10 | Authored | github.com/<your-github-user>/agent-writewithai-vault | — |
| PGA | `AgentVaults/pga/` | EEC craft — outlining, writing, landing pages, voice, outreach, packaging & pricing | 127 | 6 | Authored | github.com/<your-github-user>/agent-pga-vault | — |
| cold-outreach v1 | `AgentVaults/cold-outreach/` (pre-v2 state) | Cold outreach — cold touchpoint through first call booking. Twitter operators, YouTube transcripts, articles, research | 120 | 6 | Multi-source | github.com/<your-github-user>/cold-outreach-vault | 2026-04-11 |
| cold-outreach v2 | `AgentVaults/cold-outreach/` (in planning) | Cold outreach craft + as-a-service operations + offer construction. 7 operators + ProcessForge blog. | TBD | 7-10 (target) | Multi-source (in-place migration) | github.com/<your-github-user>/cold-outreach-vault | planned |
| swipefile-vault | `AgentVaults/swipefile-vault/` | Rael Kestrel copywriting templates — atomic structural moves with retrieval metadata for librarian dispatch | 145 | n/a (uses pattern_types instead) | Structured retrieval | github.com/<your-github-user>/swipefile-vault | 2026-04-27 |
| newsletter-growth | `AgentVaults/newsletter-growth/` | Newsletter growth (separate domain — pre-Daniel-pivot artifact) | 122 | 5 | Multi-source | github.com/<your-github-user>/agent-newsletter-growth-vault | — |
| bases | `AgentVaults/bases/` | Obsidian Bases (database views) for cross-vault queries | 15 | n/a | Bases | github.com/<your-github-user>/agent-bases-vault | — |
| _staging | `AgentVaults/_staging/` | Global staging for content awaiting ingestion into existing or future vaults | varies | n/a | Staging | github.com/<your-github-user>/agent-staging-vault | — |
| OutreachVault parent | `Documents/OutreachVault/` | Client work product (Clients/) — Client A deliverables minus 3.5GB recoverable design references | varies | n/a | Mixed | github.com/<your-github-user>/prospects-vault | — (sunset) |
| Prospects pipeline | `Documents/OutreachVault/Prospects/` | prospect outreach pipeline (sub-repo of OutreachVault parent) | varies | n/a | Multi-source | github.com/<your-github-user>/prospects | — (sunset) |

WriteWithAI and PGA are authored by Marcus Chen & Elena Rourke. Cold-outreach v1 is scraped from coldreachmarcus, Terrence Ashgrove, Quicklinescopy + 4 article sources. v2 adds Priya Sandhu (PipelineIQ), Elliot Marsh (PipelineIQ), Marco Renwick (Outreach Foundry), and ProcessForge blog. swipefile-vault is from Rael Kestrel's *Kestrel Swipe File* Parts 1-3.

---

## Vault Health Check

Run Phase 9 (I-J-K) validation, plus these additional items:

- [ ] AGENTS.md exists at vault root, last_updated field current
- [ ] Health metrics table is current (filled after latest ingestion)
- [ ] Log.md records the latest activity
- [ ] If ms is available, vault is indexed (`ms index`)
- [ ] "Where This Fits" section references match current phase numbering in [[pipeline-construction-methodology]] and [[deliverable-spec-methodology]]
- [ ] For multi-source vaults: phase-completion.json shows all phases complete
- [ ] For multi-source vaults: scripts/ directory contains all utility scripts and they pass `--help`
- [ ] For v2+ migrated vaults: BUILD-SPEC-v1.md, schema-v1.md, mocs-v1/ archived
- [ ] For v2+ migrated vaults: last_ingested.json populated for all operators
- [ ] **Backup:** vault has its own GitHub remote (`git remote -v` returns a URL)
- [ ] **Backup:** most recent local commit is reachable on remote (`git log origin/master -1` matches `git log -1`)
- [ ] **Backup:** Obsidian Git plugin installed in `.obsidian/plugins/obsidian-git/` (or vault is backed up via different mechanism — scheduled task, agent-prompt wrapper, manual discipline)
- [ ] **Backup:** plugin `data.json` has optimized settings: `autoPushInterval > 0`, `listChangedFilesInMessageBody=true`, `disablePopupsForNoChanges=true`
- [ ] **Backup:** parent folder is NOT itself an Obsidian vault (no parent-level `.obsidian/` if vault sits in a sub-directory of a multi-vault parent)
- [ ] **Backup:** `.gitignore` excludes binary regenerable content (`.beads/*.db`, `.firecrawl/`, `_polish_temp/`, IDE/agent state dirs, recoverable web-scraped binary assets)
- [ ] **Backup:** `.git` size is reasonable (`du -sh .git` < 1GB for build-once vaults; if larger, audit for historical bloat)

---

## Related

- [[pipeline-construction-methodology]] — parent methodology (vault creation is a prerequisite)
- [[deliverable-spec-methodology]] — Phase 1 requires vaults to exist
- `/skill-forge` — skill file standards (relevant when vaults inform skill file creation)
