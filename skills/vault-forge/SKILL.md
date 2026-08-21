---
name: vault-forge
description: Builds a subject-matter agent vault (knowledge corpus) grounded in verified sources. Use when the user says "build a vault", "new agent vault", "create a corpus", or invokes /vault-forge.
disable-model-invocation: true
---

# Vault Forge

> **Core Insight:** A vault is only as good as its worst capture — every file earns its place through verified content, every status claim is provable by a script that has proven it can fail, and no quote ships unless it greps back into the corpus.

## When to Use

| Situation | Action |
|---|---|
| Build a new vault from scraped operators/sources | All phases in order |
| Ingest an existing export (course files already on disk) | Same phases; Phase 4 swaps to the ingestion-integrity pass |
| Remediate an existing vault (hollow captures suspected) | Re-run Phase 5 gate + Phase 8 suite against it |
| Delta-refresh / add operators to an existing vault | Out of scope — see methodology §Incremental |

## Flow

```
Scope ──▶ Spec&Plan ──▶ Architecture ──▶ Acquire ──▶ Gate ──▶ Classify ──▶ Synthesize ──▶ Validate ──▶ Ship
(scope     BUILD-SPEC    tree+schema+   acq_log    ledger   frontmatter   MOCs/concepts   suite×2    final
 verified) +beads        suite+manifest reconciled clean    spot-check    quotes grep     green      commit
```

Every phase ends on a **Gate**: a condition a script can verify. If the gate can't pass, the phase isn't done — no matter how done it feels.

## Before you start

**Locate the reference docs** (resolution order — stop at first hit):

1. `%USERPROFILE%\Documents\ObsidianVault\References\vault-creation-methodology.md` (WSL: `/mnt/c/Users/USER/Documents/ObsidianVault/References/…`)
2. `<bundle-repo>/docs/methodology/vault-creation-methodology.md` — ⚠️ anonymized fork (operator names swapped); treat names as placeholders
3. Absent everywhere → **reduced-fidelity mode**: proceed using this skill's anti-pattern table as the failure canon; write `reduced-fidelity: reference docs unavailable` as the first `wiki/log.md` entry. Never stall; never invent paths.

Failure-canon companions (`vault-creation-failure-canon.md`, `vault-creation-canon-sibling-vaults.md`, same folder): read the sections routed per-phase in the References table — do not load them whole.

**Environment:** Python 3 + PyYAML wherever gate scripts run (WSL: `pip install --break-system-packages pyyaml`). `br`, `firecrawl`, `yt-dlp` installed (bundle Stage 2 covers both OSes).

## The phases

### 1. Scope

Decide: domain, in/out of scope, vault type (**authored** / multi-source / structured retrieval), operator-or-author list.

- **Multi-source:** verify each operator's material volume before committing — 200+ tweets, or 10+ long-form pieces, or 5+ in-scope articles. A zero-yield operator discovered mid-build is a wasted bead chain.
- **Authored:** verify the export instead — ≥20 in-scope source files or ≥50k body chars. The author list is the single author.
- Per-operator/per-source scope variations (articles-only, YouTube-only) get written into the scope doc, one line each.

**Gate:** written scope with explicit exclusions + volume verification recorded per operator/author.

### 2. Spec & plan

Create the vault repo **first**: `git init -b master` in `AgentVaults/<vault-name>/` (Windows: `%USERPROFILE%\Documents\AgentVaults\`; WSL builds work via `/mnt/c/…`). Everything after this phase commits into it.

Write BUILD-SPEC.md (phases, sources/operators, acquisition surfaces, success criteria including a **minimum-corpus number**, validation-suite contents per Phase 3). Lay out the bead graph (`br init` **from the vault root**; one bead per phase; `br dep cycles` MUST return empty). Bead descriptions are self-contained runbooks.

WSL swarms: redirect `.beads/` to native ext4 per the hot-data rule before `br init`.

**Gate:** repo initialized; BUILD-SPEC.md committed; `br dep cycles` empty.

### 3. Architecture

Scaffold exactly this tree:

```
AGENTS.md  BUILD-SPEC.md  schema.md  manifest.json
raw/                ← captures; raw/_excluded/ and raw/_quarantined/ live inside it
scripts/            ← gate scripts live here
wiki/index.md  wiki/log.md  wiki/failures.log
wiki/mocs/  wiki/concepts/  wiki/prompts/  wiki/phase-status/
```

Author AGENTS.md now. Author schema.md fully: type vocabulary (pick per domain, ~8 types), closed tag list, signal 1–5 **each level defined with one sentence + one example**.

Author `scripts/run_all_tests.py` now (it will grow per phase): minimum suites — (1) YAML parse-test every raw file, (2) type/signal/tag ∈ schema vocabulary, (3) hollow-content gate over raw/, (4) wikilink checker, (5) quote-verifier, (6) manifest reconciliation, (7) log-counts-vs-manifest.

Generate `manifest.json`: `{ "<relative-path>": "<sha256>" }` covering raw/ (excluding `_quarantined/`), wiki/, schema.md, AGENTS.md. Regenerate at every subsequent gate.

**Gate:** tree exists; schema.md defines all three vocabularies; `run_all_tests.py --help` exits 0; initial manifest.json committed.

### 4. Acquire

**Multi-source** — discover → verify → acquire. **Never acquire blind.**

Dispatch discovery with THE EXACT PROMPT (adapt targets, keep the contract):

```
You are doing URL DISCOVERY ONLY (no content scraping). For each target piece,
find its CANONICAL url, fetch it, and verify the page title/H1 actually matches
the claimed piece. Report per item: url | http status | title proof | paywalled y/n.
A url that 404s, soft-404s, or shows different content = NOT FOUND, listing what
you tried. Never guess slugs. Some domains return HTTP 200 on any slug (svpg.com
does) — status proves nothing there, content proof is mandatory. Output the
numbered list as your final message.
```

Acquire via the matching tool (Firecrawl blogs · x-harvest X · yt-dlp YouTube). Pace ~12s between calls; rate-limited → cool down 65s, retry up to 3×. URLs still failing are marked `TRANSIENT-FAILED`; after the main batch completes, run **one retry sweep** over them; only sweep survivors' remaining failures become `FINAL-FAILED`.

Log every attempt to `acquisition_log.json` — `{timestamp, url|source_path, status ∈ {SUCCESS, REJECT-GATE, FAIL-*, NOT FOUND, SKIP}, reasons, output_path}`.

**Authored** — replace acquisition with the ingestion-integrity pass: verify every source file parses, sha-dedupe identical bodies, log each kept file as `SUCCESS` with `source_path` (no URL exists — do not invent one).

**Gate:** every planned piece appears in `acquisition_log.json` exactly once with a terminal status; zero files in `raw/` **outside `_quarantined/`** fail the Phase-5 gate; SUCCESS entries reconcile 1:1 with files on disk (zero orphans either way).

### 5. The Gate (hollow-content check)

Mechanical — run the gate script over every capture **at write time**. No judgment calls:

- Body (post-frontmatter) **≥ 2,500 chars** for articles (tweets exempt).
- Title↔content match: page H1/title contains or matches the discovery-claimed title.
- Truncation check: last 200 chars end cleanly — no mid-sentence cutoff, no continuation cue (`read the full`, `continue reading`, `keep reading`, `subscribe to continue`).
- Zero hollow markers in the first 3,000 chars: `page not found`, `post not found`, `404`, `this page couldn't be found`, `over 1,200,000 subscribers`, `we need your support`, `members only`, `error establishing a database connection`.
- Near-dup: identical first-40-word body prefix = same capture renamed; keep longest, quarantine rest.
- Threads/podcasts carry real artifacts (tweet URLs, timestamps) — tidy "Step 1 / Principle 2" prose with none is AI summary, not capture.

Rejections go to `raw/_quarantined/` + one ledger line each. Never delete.

**Gate script self-test (once, before first PASS counts):** point the gate at a fixture dir containing a literal "Page not found" file, a 900-char article, and two identical-body files. All three MUST come back REJECTED with reasons. A gate that cannot fail cannot vouch for anything.

**Gate:** self-test passed (recorded in `wiki/log.md`); current corpus run reports zero rejects outside `_quarantined/`; ledger has one entry per reject.

### 6. Classify

Populate frontmatter from schema.md's vocabularies (type, signal 1–5, tags). Batch-classification is fine. Cheap models inflate signal on good titles over bad bodies; paywalled teasers score high and are worth nothing.

Then the spot-check — **recorded so it can't be faked**. Append to `wiki/log.md` a block listing exactly 5 filenames, the classifier's type/signal/tags for each, your agree/disagree verdict per field, and any classifier corrections taken. If your read disagrees with the classifier, fix the classification pipeline, not the sample.

**Gate:** 100% of raw files parse as valid YAML with in-vocabulary fields (suite suite-1/2 green) + spot-check block present in `wiki/log.md`.

### 7. Synthesize

MOCs per domain, cross-operator concept pages, `wiki/index.md` regenerated from the corpus.

**Every quotation greps back**: normalize whitespace/case, search the quote inside the cited file's body. Misses are fabrication — remove or re-source, and re-check everything sourced from the same file. Missing sources are stated as gaps; synthesis never fills them from plausibility. ("Neighbors" = anything else cited from the same source file.)

**Gate:** suite suites 4+5 green — zero broken wikilinks, zero unverified quotes — from script output, not narration.

### 8. Validate

Run `python scripts/run_all_tests.py`. Raw output goes into `wiki/log.md` (or a linked file) — the output is the record, not your summary of it.

Then one **independent invocation**: a separate OS-process run — fresh shell, or a dispatched agent with this exact instruction —

```
You are validating a vault build independently. From <vault-root>, run
`python scripts/run_all_tests.py`. Do not modify ANY file. Write the complete
raw stdout/stderr to wiki/validation-independent-run.md and reply with only
the pass/fail summary line.
```

Two consecutive all-green runs (author's + independent) close the gate. A failing suite gets investigated; expectations change only when provably stale, with reasoning logged.

**Gate:** both runs green with raw outputs persisted; manifest regenerated and committed post-run.

### 9. Ship

Final commit. `wiki/log.md` closing entry carries real counts (files, MOCs, concepts, failures encountered — including the zeros). AGENTS.md current-state updated. Note follow-ups for first real use.

**Gate:** `git status` clean; log counts == freshly regenerated `manifest.json` counts; raw/ file count ≥ BUILD-SPEC's minimum-corpus number. An internally-consistent near-empty vault is still a failed build.

## Commit cadence

One commit per phase gate, named for the phase. An uncommitted working tree is the most preventable catastrophe in this domain.

## Gate scripts

Written when first needed, stored in the vault's `scripts/`, and **each must pass a can-fail self-test**: feed it a known-bad fixture (fabricated quote, broken link, hollow file) and watch it FAIL before any PASS output is admissible. Port proven implementations rather than writing fresh — see References. Attach raw script output to every status claim; narration is not evidence.

## Anti-patterns

| Don't | Do |
|---|---|
| Log a scrape successful because the fetch completed | Gate content at write time; failures are log records, never files |
| Trust HTTP status on soft-404 domains | Verify title/H1 content regardless of status |
| Let a 1,600-char teaser pass the length check | Enforce truncation cues + title match + the 2,500 floor |
| Quote a source from memory | Grep every quote into its cited file before shipping |
| Declare tests green from your own console | Persist raw output; require one independent invocation |
| Write a gate script that always says PASS | Can-fail self-test before any PASS counts |
| Guess URL slugs | Report NOT FOUND + attempts; substitute only verified pieces |
| Bundle mandated multi-pass work into one command | Each pass runs as specified; shortcuts are lies in the log |
| Edit a failing test to green | Prove the expectation stale, log the change with reasoning |
| Delete rejected files | Quarantine + ledger; evidence stays auditable |
| Fill synthesis gaps plausibly | Name the gap; leave it visible until a real source lands |
| Skip the volume check | Verify material volume before committing beads |
| One giant final commit | Commit at every gate |
| Author vaults through the acquisition machinery | Authored exports take the ingestion-integrity pass |

## Pre-ship checklist

- [ ] Acquisition/integrity log reconciles 1:1 with raw/ (outside `_quarantined/`)
- [ ] Gate self-tests recorded; corpus run clean
- [ ] Spot-check block in `wiki/log.md` with per-file verdicts
- [ ] Zero broken wikilinks; zero unverified quotes (script outputs persisted)
- [ ] Manifest regenerated; hashes match disk; counts match log
- [ ] Two independent green suite runs with raw outputs persisted
- [ ] Corpus ≥ BUILD-SPEC minimum-corpus number
- [ ] `git status` clean

## References — read per phase, not wholesale

| Phase | Read | Where |
|---|---|---|
| 1–2 | Build planning, bead graphs, authored-vault exemptions | methodology §Phase 0–2 |
| 3 | Directory layout, utility scripts | methodology §Architecture + §Utility Scripts (`validate_final.py` pattern) |
| 4 | Acquisition discipline, soft-404s, pacing | failure canon §WT-3, §WT-4; methodology §acquisition |
| 5 | Hollow-gate design + thresholds origin | failure canon §WT-1 |
| 6 | Signal-inflation war story | sibling canon §1.1 (WriteWithAI) |
| 7 | Fabricated-quote forensics | failure canon §FM-2, §WT-2 |
| 8 | Status-claim inflation, independent validation | failure canon §FM-3, §FM-7 |
| tools | x-harvest · firecrawl · dev-browser · beads-workflow skills | installed alongside |
| proven gate code | Port + parameterize | product-lead vault `_remediation/` (`phase1_gate.py`, `phase3b_acquire.py`) if present on-machine; else author per §Gate scripts |
