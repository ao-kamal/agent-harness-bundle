# 05 — Vault Hygiene

This bundle can optionally set you up with a personal notes vault (`vault-starter/`, built for Obsidian — a free notes app). This chapter is why that vault is structured the way it is, and why the structure matters more than it looks like it should. If you skip the vault entirely, the memory-system section at the end still applies — it's built into Claude Code itself, not something you opt into.

## Kepano's principle: keep a messy vault for your agents, and a clean one for yourself

This comes from Steph Ango (who writes as Kepano, and runs Obsidian), describing a practice he attributes to Andrej Karpathy: **keep your personal vault clean, and create a separate, messier vault for anything an AI agent produces.** The reasoning isn't about tidiness for its own sake — it's about provenance. Ango puts it directly: he wants his personal vault to be high signal-to-noise, with every piece of content having a *known origin* — written by him, or deliberately curated by him from an external source he can name.

**The failure mode, stated precisely:** if AI-generated content and your own writing mix too freely in one vault, every retrieval surface in that vault quietly stops being trustworthy as a representation of *your* thinking. Search results blend your own reasoning with a model's. Backlinks connect ideas you actually had to ideas a model generated on your behalf. The graph view, the quick switcher, everything — all of it silently loses the property of being scoped to what's actually yours. This isn't a hypothetical: it's the default outcome of not deciding otherwise, because nothing about a folder full of markdown files stops you from saving an AI's output next to your own notes.

**The promotion gate.** The fix isn't "never let AI output into your personal vault" — it's that crossing over should be a deliberate, reviewed act, not something that happens by default. Ango: "only once your agent-facing workflow produces useful artifacts would I bring those into the primary vault." Something an agent wrote sits in the agent-facing space until you've actually read it and decided it's worth keeping in the space that represents your own thinking — at which point you move it, on purpose, not automatically.

Karpathy's own version of this generalizes the idea past Obsidian entirely: keep an authoritative source-of-record layer that you personally curate, and a clearly separate derived/synthesized layer, connected by explicit links rather than merged together. The pattern is bigger than any one note-taking app.

**Why this can't be fixed retroactively.** Ango draws an analogy to "low-background steel" — steel produced before nuclear weapons testing began contaminating the atmosphere, which is still sought out today for equipment sensitive enough that even trace radiation matters, because *no steel made after that point can ever be uncontaminated again*. The same logic applies to your notes after generative AI: once your own writing and AI output are mixed together with no record of which is which, you can't go back and un-mix them. The boundary either exists from the start, or the ability to certify anything in the vault as "purely mine" is gone for good. That's why this vault starter separates `Mine/` (only ever your own writing) from `Dialogues/` (AI conversation output) from day one, rather than starting simple and adding the separation "later, once it matters."

## The PKM system you're inheriting

The vault starter implements five portable principles that trace back to Kepano's broader writing on personal knowledge management, plus one addition specific to this bundle's AI-assisted workflow:

1. **Properties over folders.** Don't create a subfolder per topic. Use a `categories` frontmatter property instead, and let one note carry as many categories as actually apply.
2. **Flat structure.** Every folder holds files directly — no nesting by topic inside `Clippings/`, `Mine/`, and so on.
3. **A single sentence is a valid note.** Don't wait until an idea is fully formed to write it down.
4. **Link profusely.** Create `[[wiki links]]` to related notes even when the target doesn't exist yet — the link itself is a breadcrumb for a note you haven't written.
5. **Evergreen content.** Old notes don't get deprioritized just for being old. There's no expiry.
6. **Separate AI output from your own writing.** This is the bundle-specific addition, and it's the operational form of the Kepano principle above: `Dialogues/` holds AI conversation output, `Mine/` holds only what you actually wrote.

**Type lives in frontmatter, never in the folder.** The folder a note sits in answers "where did this come from" (clipped from the web, written by you, produced by a conversation with Claude). A `type:` property in the note's frontmatter answers "what kind of thing is this" (a tweet, an article, a transcript, a personal note). The two questions are independent, and conflating them is what pushes people back toward folder-per-topic, which principle 1 already ruled out. The full folder list and frontmatter schema for each type live in `vault-starter/CLAUDE.md`.

**Mode separation: thinking vs. production.** When you're exploring an idea out loud, that's Thinking Mode — Claude asks questions, takes notes on what you discover together, and produces nothing polished. Nothing gets written as a finished artifact until you explicitly say so ("let's write," "create the note") — that's Production Mode. The point of keeping these separate: a thinking-out-loud conversation should never accidentally leave behind a half-finished draft that looks more decided than it actually is.

## The memory system: built in, not something you set up

Separately from any vault, Claude Code keeps its own per-project memory automatically — you don't install this, and there's no configuration file for it. The first time Claude Code runs in a new project folder, it creates a `memory/` directory alongside an index file (`MEMORY.md`). What's worth deliberately building is the *convention* layer on top of that automatic behavior, because the platform itself doesn't enforce any taxonomy — left alone, the memory folder just becomes an unsorted pile of files.

**Four types, and one of them will dominate.** Memories are organized into exactly four kinds: `user` (durable facts about you personally, true across every project — this bucket stays small), `project` (the current status of one ongoing thing: what's done, what's next, where the real source-of-truth artifact lives — updated in place as things change, not superseded by a new file each time), `reference` (reusable how-to knowledge not tied to any one project's current status), and `feedback` (a correction you gave, written as a rule so the same mistake doesn't repeat). In practice, `feedback` ends up the largest bucket by a wide margin — that reflects a healthy working pattern (catch a correction, encode it as a rule, move on), not a problem.

**Topic-stable filenames, updated in place.** A memory about an ongoing project is named for the project, not for the session that wrote it — `project_your-thing.md`, not something dated. A later session touching the same project should find and update that same file, not create a dated variant next to it. `MEMORY.md`'s one-line summaries work the same way: they're current-state snapshots you rewrite as things change, not a running log you append to.

**The feedback habit is the one to build deliberately.** Every time you correct something Claude did, that correction is worth capturing as a `feedback` memory in the shape: what went wrong → why it matters → how to apply the fix going forward. This is the single highest-leverage habit in the whole memory system — it's the mechanism that turns "I had to explain this again" into "I never had to explain this again."

Cross-reference related memories with `[[wikilink]]` syntax against a memory's internal name (not its filename) — the same linking convention as the vault itself, so a `reference` memory that came out of a specific project can point back to `[[project_that_project]]` and vice versa.
