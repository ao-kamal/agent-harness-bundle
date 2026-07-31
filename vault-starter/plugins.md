# Recommended Community Plugins

This vault starter doesn't ship these plugins pre-installed — Obsidian plugins are per-machine binaries, not something a git repo should carry. Install them yourself, once, through Obsidian's own plugin browser:

**Settings → Community plugins → Turn on community plugins (if this is a new vault, Restricted Mode is on by default) → Browse → search by name → Install → Enable.**

## The five worth installing

| Plugin | What it does | Why it's here |
|---|---|---|
| **Dataview** | A query engine that lets you build live, auto-updating lists and tables from your notes' frontmatter (e.g. "every article tagged `writing` that isn't marked read yet"). | Obsidian's native Bases feature (the `.base` files, like `clippings-queue.base` in this starter) covers a lot of the same ground now, but Dataview is more flexible for anything Bases doesn't reach — inline queries inside a note, more complex filters. Worth having even if Bases becomes your main tool. |
| **Obsidian Git** | Auto-commits and auto-pushes your vault to a GitHub remote on a timer. This is your backup. | Without it, this vault is one drive failure away from gone. Set it up the same day you start using the vault, not after you've written 200 notes. See the setup note below — the defaults are worth changing. |
| **Obsidian Link Embed** | Turns a pasted URL into a rich preview card (title, thumbnail, description) instead of a bare link. | Makes the Scratch/ and Clippings/ folders much more pleasant to skim — you can tell what a clipped link actually is at a glance. |
| **Templater** | Runs templates with logic (dates, prompts, conditional text) instead of Obsidian's built-in static templates. | Drives whatever you build in `Templates/` — daily notes, weekly reviews, anything with a repeating structure you want pre-filled. |
| **Obsidian to Anki** | Exports notes (or parts of notes) into Anki flashcard decks for spaced repetition. | Optional — only useful if you actually use Anki. Not referenced anywhere else in this vault's conventions; skip it if you don't do spaced repetition. |

## Setting up Obsidian Git properly

The plugin's defaults are conservative in a way that leaves a real backup gap. After installing, go to its settings and change:

- **Auto push interval**: set to a real number (e.g. `30` minutes). The default is `0` — disabled — which means your commits stay local until you push manually. A local-only commit doesn't survive a dead drive.
- **List changed files in commit message body**: turn on. Costs nothing, makes your git log far more useful when you're trying to find when something changed.
- **Disable popups for no changes**: turn on. The plugin checks on a timer regardless of whether anything changed; without this you get a notification every few minutes for nothing.
- Leave **auto-backup after every file change** off. If an agent (or you, editing quickly) touches many files in a short window, per-change commits spam your history for no benefit — the timed interval already catches everything.

One real gap to know about: Obsidian Git only runs while Obsidian is open with this vault as the active window. If you (or Claude Code, working in this folder from the terminal) modify files while Obsidian is closed, nothing gets committed until you next open the vault. If you expect a lot of terminal-side editing, either get in the habit of `git add -A && git commit && git push` from the terminal when you're done, or set up a scheduled task that does it on a timer independent of Obsidian being open.
