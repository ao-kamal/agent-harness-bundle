# Corpus schema — the vault-corpus consumer

The reference consumer (`scripts/ingest_corpus.py`) renders the normalized harvest JSON into an Obsidian-vault markdown corpus. This is the schema it writes. Other consumers (CSV, digest, JSONL) read the same normalized JSON and ignore this entirely.

## Filename

```
<operator>-{tw|thr|art}-<slug>-<YYYYMMDD>-<last6ofRootId>.md
```

Bookmarks (`--mode bookmarks`):

```
bm-<author>-<slug>-<YYYYMMDD>-<last6ofRootId>.md
```

- `tw` single tweet · `thr` thread · `art` Article · `bm` a saved post by someone else
- `<slug>` — first ~55 chars of the text, lowercased, non-alphanumerics → `-`, URLs stripped
- date is the post's `date_posted`; the id suffix guarantees uniqueness across same-day, same-slug posts

Example: `example-handle-thr-your-biggest-competitor-has-no-website-20260630-289499.md`

## Frontmatter

```yaml
---
operator: 'example-handle'        # the account harvested (= --operator)
source: 'twitter'                  # or 'twitter-article' / 'twitter-bookmark'
source_url: 'https://x.com/<operator>/status/<root_id>'
author: '<handle>'                 # bookmarks: the tweet author, not the operator
source_id: '<root_id>'
date_posted: 'YYYY-MM-DD'
date_ingested: 'YYYY-MM-DD'        # = --batch
is_reply: false
contains_image: <bool>
images:                            # media URLs, or []
- 'https://pbs.twimg.com/media/...'
thread_tweet_ids:                  # [] for singles; ordered ids for threads
- '<id1>'
- '<id2>'
quoted_tweet_id: '<id>' | null
language: 'en'
type: 'tweet' | 'thread' | 'article' | 'tweet-media-only'
refresh_batch: 'YYYY-MM-DD'        # = --batch; groups a harvest run
triage: 'pending'                  # a downstream review flag
---
```

Articles add `title` and `capture_note`; the article body carries an `## Article images` section instead of `images`.

## Body

- **Single tweet:** the `note_tweet` text (or `full_text`), verbatim.
- **Thread:** the root, then each continuation separated by:
  ```
  ---
  *(thread continuation i/n — id <id>, <iso-dt>)*
  ```
- **Quoted tweet:** appended as `## Quoted tweet (@author, id <id>)` + the quoted text.
- **Media:** appended as `## Media` + a bullet per URL.

## Profile file

If the harvest carries a `profile` block, the consumer writes one `<operator>-profile.md`. Unlike posts (immutable, never overwritten), the profile is **current-state and overwrites on every refresh**.

```yaml
---
operator: '<handle>'
source: 'twitter-profile'
source_url: 'https://x.com/<handle>'
source_id: '<user_rest_id>'
date_ingested: 'YYYY-MM-DD'
display_name: '<name>'
followers: 12345                   # unquoted numbers
following: 678
tweet_count: 9012
joined: 'YYYY-MM-DD'
location: '<location>' | null
website: '<url>' | null
verified: <bool>                   # the visible checkmark (is_blue_verified)
professional_type: '<Creator|Business>' | null
professional_category: []          # e.g. ['Entrepreneur']
pinned_tweet_id: '<id>' | null
language: 'en'
type: 'profile'
refresh_batch: 'YYYY-MM-DD'
triage: 'pending'
---
```

Body = the bio text, then an `## Bio links` section (expanded URLs) if any.

## Incremental dedup

`known_ids` is a flat file, one root id per line. Ingest **skips any id already present** and appends newly written ids. `write_file` also refuses to overwrite an existing corpus file (belt-and-suspenders). To refresh: pass the same `--corpus` dir and (optionally) `--known-ids`; only genuinely new posts get written.

## Tuning for a different vault

The consumer is config-driven via flags (`--operator`, `--corpus`, `--batch`). To change the *shape* — different frontmatter fields, a different filename template, different section formatting — copy `ingest_corpus.py` to a new consumer and edit the `fm()` field list and the `write` block. The normalized harvest JSON is stable; only the consumer changes. That is the two-layer contract.
