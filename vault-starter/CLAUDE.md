# Personal Knowledge Management System

This is a PKM vault following Kepano's (Steph Ango, Obsidian CEO) philosophy. See `docs/field-guide/05-vault-hygiene.md` in the harness bundle for why this structure exists and what it protects against.

## Core Principles

1. **Properties over folders** - Never create subfolders for topics. Use `categories` property.
2. **Flat structure** - All folders contain files directly, no nesting.
3. **Single sentence is valid** - Embrace atomic notes. Even tiny thoughts deserve a note.
4. **Link profusely** - Create [[wiki links]] between related notes, even if target doesn't exist yet.
5. **Evergreen content** - Old notes are still valuable. Don't deprioritize by age.
6. **Separate AI from personal** - AI-generated research and conversation outputs go to Dialogues/, not Mine/. Mine/ is for your own writing.

## Folder Structure

```
Scratch/     <- Quick capture from Chrome clipper + scratchpad (zero friction)
Mine/        <- Personal writing — plans, visions, original thinking (ONLY your own content)
Clippings/   <- External content: articles, tweets, transcripts (flat, no subfolders)
Dialogues/   <- Conversation outputs from Claude sessions + AI-generated research
References/  <- Research reports, methodology docs, tool references
Daily/       <- Daily notes (from Daily Notes plugin)
Templates/   <- Note templates
Archive/     <- On-hold or inactive work
```

**Type is determined by frontmatter property, NOT folder:**
- `type: tweet`
- `type: article`
- `type: transcript`
- `type: note`
- `type: dialogue`
- `type: reference`
- `type: resource`

## As You Grow: More Vaults

This vault is for personal knowledge only — your own thinking, your own reading. As you take on client work or build craft knowledge in a specific domain (writing, a trade, a hobby you're systematizing), that content belongs in a *separate* vault, not folded into this one. Mixing them degrades this vault's search, backlinks, and graph view — see `docs/field-guide/05-vault-hygiene.md` for the reasoning (it's the single highest-leverage habit in this whole system, and the easiest one to skip by accident). Start this vault clean, and keep it that way as you add others.

## Clipping Processing

When files appear in Scratch/ (from Chrome Web Clipper or manual capture):

1. Read the file — determine type (tweet, article, transcript)
2. If YouTube URL with no transcript content: extract transcript via `defuddle parse <url> --md` or yt-dlp
3. Add/fix frontmatter:
   - Ensure `consumed: false` exists (checkbox property)
   - Infer `categories` from content (check existing vault categories first, avoid duplicates)
   - Verify `type` is correct: tweet, article, or transcript
   - Add `author` if missing
   - Add `processed_date` if missing
   - Remove `status: active` if present (deprecated property)
4. Generate filename per convention: `{topic-slug}-{author-slug}.md`
5. Move to Clippings/
6. If the content is craft knowledge for a domain you're building a separate knowledge base for, ALSO flag for staging: note in the file's Related section which other vault it could benefit

## Consumption Tracking

- Clippings use `consumed: true/false` property (checkbox)
- When you say you've read/watched something, set `consumed: true`
- The `clippings-queue.base` in the vault root shows unread items grouped by type
- Do NOT set consumed to true unless you explicitly say you've consumed it

## Mode Separation

### Thinking Mode (Default)
When you say "help me think" or you're exploring ideas:
- Ask questions to clarify your thinking
- Don't produce artifacts (outlines, drafts, etc.)
- Take notes on what we discover
- Help find connections between ideas

**CRITICAL:** Do not write drafts, outlines, or finished content in thinking mode. Only gather, question, and note.

### Production Mode
Only when you explicitly say "let's write" or "create the note":
- Generate the actual artifact
- Use proper frontmatter format
- Create appropriate [[backlinks]]
- Place in correct folder

## Note Frontmatter Format

### For Tweets (Clippings)
```yaml
---
author: "@username"
tweet_date: YYYY-MM-DD
processed_date: YYYY-MM-DD
url: https://x.com/...
categories: [topic1, topic2, topic3]
type: tweet
consumed: false
hasThread: false
hasQuote: false
---
```

### For Articles (Clippings)
```yaml
---
author: "Author Name"
processed_date: YYYY-MM-DD
url: https://...
categories: [topic1, topic2]
type: article
consumed: false
---
```

### For Transcripts / YouTube (Clippings)
```yaml
---
author: "Channel Name"
published: YYYY-MM-DD
processed_date: YYYY-MM-DD
url: https://youtube.com/...
categories: [topic1, topic2]
type: transcript
consumed: false
---
```

### For Personal Writing (Mine)
```yaml
---
created: YYYY-MM-DD
categories: [topic1, topic2]
type: note
---
```

### For Dialogues
```yaml
---
created: YYYY-MM-DD
source: claude
categories: [topic1, topic2]
type: dialogue
participants: [me, claude]
---
```

### For References
```yaml
---
created: YYYY-MM-DD
categories: [topic1, topic2]
type: reference
---
```

## Filename Convention

`topic-slug-author.md` for clippings (tweets, articles, transcripts)
`topic-slug.md` for personal notes (Mine/)
`YYYY-MM-DD-topic-slug.md` for dialogues

## Categorization Rules

1. **Check existing categories first** - Before assigning categories, scan existing notes to see what categories are already in use. New categories are fine, but check first to avoid creating duplicates or synonyms of existing ones.
2. **Infer freely** - Don't ask for categories. Make your best guess.
3. **Primary topic for filename** - Pick the most specific/relevant topic for the filename.
4. **All topics in properties** - Put all relevant topics in `categories: []` array.
5. **Always pluralize** - Use `workflows` not `workflow`, `tools` not `tool`.
6. **Lowercase, hyphenated** - Use `claude-code` not `Claude Code` or `claudeCode`.

## Backlinks

When creating a note, add a `## Related` section with [[wiki links]] to:
- Notes by the same author
- Notes on the same topic
- Notes that reference similar concepts

Even if the linked note doesn't exist yet, create the link as a breadcrumb.

## Memory Conventions

Claude Code keeps its own per-project memory automatically — a `memory/` folder under `~/.claude/projects/<this-vault-path>/` with an index file (`MEMORY.md`) and individual topic files. Nothing to install; it's a built-in feature. What's worth doing deliberately is following a consistent convention so the memory stays useful instead of turning into an unsorted pile:

1. **File memories under exactly four types** — `user` (durable facts about you, true across every project), `project` (current status of one ongoing thing — what's done, what's next, where the real artifact lives), `reference` (reusable how-to knowledge not tied to one project), `feedback` (a correction you gave, written as a rule so it isn't repeated). `feedback` is normally the largest bucket by far — that's expected, not a sign of anything wrong.
2. **Name files `{type}_{topic_slug}.md`**, and keep the slug topic-stable. A later session about the same project should update the *same* file, not create a dated variant.
3. **Keep `MEMORY.md`'s one-line entries current** — rewrite the line in place as a project's status changes, don't append a changelog. Organize the index under the same four `##` headers every time: User, Project, Reference, Feedback.
4. **Write `feedback` memories in the shape**: what went wrong → why it matters → how to apply the fix next time. That shape is what makes it usable as a rule, not just a journal entry.
5. **Cross-reference related memories** with `[[wikilink]]` syntax against the memory's `name` field (not its filename) — e.g. a `reference` memory that came out of a specific project links back to `[[project_that_project]]`.

None of this requires configuration. It's a habit you tell Claude to follow (this file is where you do that), since the platform itself imposes no taxonomy or naming convention on its own.

## Commands

### /bookmark
Quick capture - paste a URL, Claude fetches and categorizes it.

### /hunt [topic]
Semantic search across all notes for a topic.

### /forgotten
Resurface old notes you haven't looked at in a while.

### /think
Enter thinking mode - explore ideas without producing.

## Interest Profile

Claude may build knowledge about your interests over time, but:
- Use it for **suggestions only**
- Never auto-apply it to categorization without showing you
- You decide what categories stick

## Processing Queue

When processing new content:
- Auto-process 90%+ immediately
- Flag uncertain items (ambiguous category, multi-topic) for your review
- Never skip - everything gets a note, even if minimal

## What NOT To Do

- Don't create subfolders for topics within Clippings, Mine, etc.
- Don't ask for categories - infer them
- Don't write drafts in thinking mode
- Don't add daily rituals you didn't ask for
- Don't track revisit dates (too much overhead)
- Don't over-engineer - keep it simple
- **Don't summarize reference materials** - When moving external content into the vault, preserve the FULL original content exactly as written. Add frontmatter and a Related section, but never condense, extract key points, or rewrite the body.
- **Don't put AI outputs in Mine/** - Mine/ is exclusively for your own writing. Claude session outputs go to Dialogues/.
- **Don't add `status: active`** - This property is deprecated. Use `consumed` for clippings tracking instead.
