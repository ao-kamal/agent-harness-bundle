---
name: vault-forge
description: Build a subject-matter agent vault (knowledge corpus) that grounds multi-agent work in verified source material. Use when the user says "build a vault", "new agent vault", "create a corpus", or invokes /vault-forge. Covers operator selection, acquisition with content gates, classification, MOC/concept synthesis, and mechanical validation. User-invoked — never fire opportunistically.
disable-model-invocation: true
---

# Vault Forge

> **Core insight:** A vault is only as good as its worst capture. Every file must earn its place through verified content, every status claim must be provable by a script, and every quote in the synthesis layer must grep back into the corpus. The failure mode is never "the agent couldn't build the vault" — it's "the agent built a vault that lies about itself."

Builds an agent vault following the canonical methodology. The methodology doc is the source of truth for *what* a vault is; this skill enforces *how to build one without fabricating it*. Every phase ends on a mechanical gate — if the gate can't pass, the phase isn't done, no matter how done it feels.

## Before you start

Read the canonical methodology (structure, phases, directory layout — do not re-derive it):

```
ObsidianVault/References/vault-creation-methodology.md
```

Skim the failure canon so the anti-patterns below have faces:

```
ObsidianVault/References/vault-creation-failure-canon.md
ObsidianVault/References/vault-creation-canon-sibling-vaults.md
```

(Paths relative to the Obsidian vault root — locate it on the current machine before reading.)

## The phases

### 1. Scope

Decide: domain, what is in scope, what is NOT, vault type (authored / multi-source / structured retrieval), operator list.

- Verify each operator has enough in-scope material **before committing** (200+ tweets, or 10+ long-form pieces, or 5+ in-scope articles). A zero-yield operator discovered mid-build is a wasted bead chain.
- Per-operator scope can vary (articles-only, YouTube-only, timeline+articles). Write the decision down per operator.

**Gate:** written scope with explicit exclusions + per-operator material-volume verification. No build spec until this exists.

### 2. Spec & plan

Write BUILD-SPEC.md (phases, operators, acquisition sources, success criteria) and lay out the bead graph (`br init`, one bead per phase, `br dep cycles` MUST be empty before execution). Bead descriptions are self-contained runbooks.

**Gate:** BUILD-SPEC.md exists and is committed; `br dep cycles` returns empty.

### 3. Architecture

Scaffold the directory tree exactly per the methodology (AGENTS.md, schema.md, raw/, wiki/ with index.md + log.md + failures.log, scripts/, mocs/, concepts/, _excluded/). Author AGENTS.md now, update as the build evolves.

**Gate:** tree exists, AGENTS.md + schema.md committed. `git log` shows the scaffold commit.

### 4. Acquire

Discover → verify → acquire. **Never acquire blind.**

1. **Discover** the canonical URL for every target piece. Verify it resolves AND matches the claimed content (fetch, read the title/H1). A URL that 404s is reported NOT FOUND — never guessed. Some domains soft-404 (return HTTP 200 with error content on any slug — svpg.com does this); for those, status means nothing, only content verification counts.
2. **Acquire** via the appropriate tool (Firecrawl for blogs, x-harvest for X, yt-dlp for YouTube). Pace requests (~12s between calls); on rate limits, cool down 65s and retry (3x), then log the failure and move on.
3. **Gate every file at write time** — run the hollow-content gate (below) on each capture. Failures are logged as failures in the acquisition log. A failure logged is progress; a failure written as success is the original sin.

**Gate:** acquisition_log.json shows every URL attempted with status; zero files in raw/ below the gate thresholds; failure count is honest and non-zero failures exist as failure records, not as files.

### 5. The Gate (hollow-content check)

Run against every file before it counts as acquired. Mechanical, no judgment calls:

- Body (post-frontmatter) ≥ 1,500 chars for articles (≥ 2,500 preferred; tweets exempt).
- Zero hollow markers in the first 3,000 chars: `page not found`, `post not found`, `404`, `this page couldn't be found`, `subscribe to continue`, `over 1,200,000 subscribers`, `we need your support`, `members only`, `error establishing a database connection`.
- Near-dup check: identical first-40-words body prefix = same capture under multiple names; keep the longest, quarantine the rest.
- Thread/podcast captures must contain real artifacts (tweet URLs / timestamps), not tidy "Step 1 / Principle 2" prose — that structure with no artifacts is AI summary, not capture.

Quarantine failures into `raw/_quarantined/` with a ledger entry. Never delete — evidence stays auditable.

**Gate:** gate script reports 0 quarantined among files claimed as acquired, and the quarantine ledger exists for every rejection.

### 6. Classify

Populate frontmatter (type from the 8-type vocabulary, signal 1-5, tags from the closed schema vocabulary). Batch-classify is fine; then **spot-check 5 files by hand against your own judgment before trusting the run** — if the classifier's signal doesn't match your read, fix the classifier, not the sample. Cheap models inflate signal on good titles over bad bodies; paywalled teasers score high and are worth nothing.

**Gate:** 100% of raw files have valid YAML frontmatter (parse-test every file), type ∈ vocabulary, signal ∈ 1-5, tags ⊆ schema vocabulary, and the spot-check is recorded in the log.

### 7. Synthesize

MOCs (per domain), concept pages (cross-operator), wiki/index.md regenerated from the corpus.

**Every quotation in synthesis must be verified**: normalize whitespace/case, grep the quoted text against the cited file's body. A quote that doesn't grep back is fabrication — remove it or re-source it, and treat its neighbors as suspect. When sources are missing, the synthesis says so; it never fills gaps from plausibility.

**Gate:** link-checker reports zero broken wikilinks AND quote-verifier reports zero unverified quotes. Both numbers come from scripts, not from your feeling about the files.

### 8. Validate

Run the full validation suite. Then run it **again from a clean shell** (or have a second agent run it). Green means: all suites pass, manifest hashes match disk, and the corpus passes the hollow gate. If a suite fails, investigate — do not edit the test to match the failure unless the expectation itself is proven stale, and log the change with reasoning.

**Gate:** two consecutive clean full-suite runs (independent invocations), manifest regenerated and committed.

### 9. Ship

Commit everything. The log gets the final entry with real counts (files, MOCs, concepts, failures encountered). Update AGENTS.md current-state. Note what to revisit after first real use.

**Gate:** final commit exists; `git status` clean; log's final counts match `manifest.json`.

## Commit cadence

Commit after every phase gate. One commit per gate, message names the phase. A build lost to an uncommitted working tree is the most preventable catastrophe in this domain.

## Anti-patterns

| Don't | Do |
|---|---|
| Save a 404/paywall page and log the scrape as successful | Gate content at write time; log failures as failures |
| Define success as "fetch completed + file written" | Define success as "content verified against the claim" |
| Trust HTTP status on known soft-404 domains | Content-verify (title/H1 present) regardless of status |
| Write synthesis quotes from memory of a source | Grep every quote back into the cited file before it ships |
| Declare "all tests green" from your own run | Re-run from a clean shell; attach raw output to any status claim |
| Guess URL slugs when discovery fails | Report NOT FOUND with what you tried; ask or substitute a verified piece |
| Bundle mandated multi-pass work into one command | Run each pass as specified; a shortcut here is a lie in the log |
| Edit a failing test to green without proof the expectation is stale | Investigate first; log test changes with reasoning |
| Delete rejected files | Quarantine with a ledger; evidence stays auditable |
| Fill synthesis gaps with plausible-sounding content | State the gap; leave it visible until a real source fills it |
| Skip the pre-build operator volume check | Verify material volume before committing beads |
| One giant commit at the end | Commit at every phase gate |

## The one command per phase

When a phase gate requires a script, the script's output — not your narration — is the record. If no gate script exists yet for a phase, write it first (it becomes part of the vault's `scripts/`), then run it, then claim the gate.

## References

| Topic | Where |
|---|---|
| Canonical methodology (structure, full phase detail) | `ObsidianVault/References/vault-creation-methodology.md` |
| Failure canon (12 failure modes, verbatim evidence) | `ObsidianVault/References/vault-creation-failure-canon.md` |
| Sibling-vault patterns (14 techniques, per-vault profiles) | `ObsidianVault/References/vault-creation-canon-sibling-vaults.md` |
| X/Twitter acquisition | `x-harvest` skill |
| Web scraping | `firecrawl` skill |
| Browser automation / login-gated capture | `dev-browser` skill |
| Bead graph planning | `beads-workflow` skill |
| Proven gate implementations (port + parameterize) | any built vault's `_remediation/` scripts — e.g. the product-lead vault's `phase1_gate.py`, `phase3b_acquire.py`, `phase2_purge.py` |
