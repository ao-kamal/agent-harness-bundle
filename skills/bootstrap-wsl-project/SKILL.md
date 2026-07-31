---
name: bootstrap-wsl-project
description: Bootstrap a /mnt/c-located project to use ext4 native filesystem for hot-data dirs (SQLite, locks, build caches) via symlinks. Avoids WSL2 9p performance pathology — SQLite/fsync over 9p is 10-100× slower than native ext4. Use when setting up a new WSL2 + Windows hybrid project, when SQLite write-locks time out, when build performance is mysteriously slow, when `node_modules` / `target` / `.beads` need to be migrated, or when running `init-fast-data` against an existing project. Triggers: "wsl project setup", "bootstrap wsl project", "fast data symlink", "9p sqlite slow", "init-fast-data", "wsl performance fix".
---

# Bootstrap WSL Project

> **Core insight:** Anything that does sustained `fsync()` or `fcntl(F_SETLK)` belongs on native ext4, not /mnt/c/. WSL2's 9p protocol layer over Windows NTFS makes those operations 10-100× slower under concurrent access — fine for read-mostly source code, pathological for SQLite databases, lock files, and build caches.

## How to invoke this skill

This skill is **not** a CLI binary. There is no `bootstrap-wsl-project` executable. Invocation paths:

- **Inside Claude Code:** invoke via the Skill tool / agent — Claude follows the work loop below using `init-fast-data` (the actual script in `$PATH`) plus repo-state checks.
- **Manual operator-side equivalent:** read this file and follow the work loop steps with `init-fast-data` directly. Steps 1-7 below are operator-runnable bash.

The actual data-migrating tool is `/root/.local/bin/init-fast-data` (a standalone bash script). This skill orchestrates it.

## When to use

| Situation | Run this skill |
|---|---|
| Creating a new project on /mnt/c/ | YES — bootstrap BEFORE `br init` / `cargo new` / `npm init` |
| Existing project with SQLite write-lock timeouts | YES — retrofit via this skill |
| Existing project with `node_modules` / `target` on /mnt/c/ | YES — symlink those to ext4 |
| Project already on ext4 (`/root/...`, `/home/...`) | NO — no migration needed; refuse early |
| Read-only repos / docs-only projects | NO — no hot data to migrate |

## Prerequisites

- WSL2 environment (this skill is a no-op outside it).
- `init-fast-data` script in PATH at `/root/.local/bin/init-fast-data`. Verify with `which init-fast-data`. If missing, the script can be re-installed from the policy in `~/.claude/CLAUDE.md` → "Hot vs cold filesystem rule."
- Project root has `.git/` (the skill uses git presence as a safety check).
- No live processes have files open in any target hot-dir (`init-fast-data` will refuse via `lsof +D` precheck — kill running services / agents first).

## The work loop

1. **Detect project type** — `pyproject.toml` / `Cargo.toml` / `package.json`.
2. **Recommend hot-dir set** — based on detected type (table below).
3. **Detect shared-DB case** — see "Shared-DB-across-projects detection" below; may require running from a parent dir, not the nested project.
4. **Confirm scope with operator** — show recommended hot-dirs; let them edit (or use `--scripted` to skip prompt).
5. **Run `init-fast-data`** per hot-dir — it does cross-fs copy + size-verify + source-delete + symlink + `.gitignore`.
6. **Optionally append README section** — surface the WSL Hot Data Layout addition for confirmation; never auto-edit.
7. **Validate** — confirm symlinks resolve to /root/, ext4 paths exist + non-empty, .gitignore captures them.
8. **Report** — print final state to operator.

## Project type → recommended hot-dirs

| Detected files | Project type | Hot-dirs |
|---|---|---|
| `pyproject.toml` or `requirements.txt` | Python | `.venv`, `__pycache__`, `.pytest_cache` |
| `Cargo.toml` | Rust | `target` |
| `package.json` + `next.config.*` | Next.js | `node_modules`, `.next` |
| `package.json` (generic Node) | Node | `node_modules` |
| Multiple of above | Polyglot | Union of relevant hot-dirs (skill confirms with operator) |

**`.beads/` is deliberately excluded** from every row — see Anti-Patterns table. The beads-workflow requires `git add .beads/issues.jsonl`, and git refuses to traverse symlinks. The 9p cost for the beads SQLite is acceptable for the planning + occasional-update workload that this dir actually sees in practice.

## Shared-DB-across-projects detection

Some projects nest inside a parent vault that hosts a shared resource (e.g., a monorepo with shared `node_modules`, or a meta-project with a shared build cache). Migrating the nested project's symlink doesn't help — the actual data is up the tree.

Detection (recursive walk; substitute your candidate hot-dir for `<hot-dir>`):

```bash
target="<hot-dir>"
cur="$(pwd -P)"
while [[ -L "$cur/$target" ]]; do
  resolved="$(readlink -f "$cur/$target")"
  parent="$(dirname "$resolved")"
  echo "  $cur/$target → $resolved (actual data lives at $parent)"
  cur="$parent"
done
echo "Run init-fast-data $target from: $cur"
```

If the loop walks more than one level, the operator must run from the **deepest non-symlinked parent** — that's where the data actually lives. Nested projects' symlinks transitively resolve once the parent is migrated.

## THE EXACT PROMPT — manual interactive bootstrap (operator-side)

```bash
cd /mnt/c/Users/<you>/Documents/MyProject
# 1. Detect project type:
ls pyproject.toml Cargo.toml package.json 2>/dev/null
# 2. Pick hot-dirs from the table above based on what's present (NEVER include .beads/ — see Anti-Patterns)
# 3. Verify no processes have files open in those dirs (init-fast-data refuses anyway):
lsof +D .venv 2>/dev/null
# 4. Migrate (init-fast-data validates + does the work atomically):
init-fast-data .venv .pytest_cache
# 5. Validate:
ls -la .venv .pytest_cache
grep -E '^/?(\.venv|\.pytest_cache)$' .gitignore
```

## THE EXACT PROMPT — manual scripted bootstrap (no prompts)

```bash
cd /mnt/c/Users/<you>/Documents/MyProject
init-fast-data .venv .pytest_cache
# Idempotent — safe to re-run; already-symlinked dirs are skipped (with target validation).
# DO NOT include .beads/ — git refuses to traverse symlinks; see Anti-Patterns.
```

## THE EXACT PROMPT — append README section (after bootstrap, no nested fences)

Use this exact text. Heredoc terminator is `END_OF_README_BLOCK` (intentionally distinct from any nested code fence):

```bash
cat <<'END_OF_README_BLOCK' >> README.md

## WSL Hot Data Layout

Hot-data dirs (`.venv`, `.pytest_cache`, build caches, etc.) live on native ext4 at `/root/projects-data/<project-basename>/` and are symlinked into the project tree. SQLite + 9p is pathological under concurrent access — see `~/.claude/CLAUDE.md` → "Hot vs cold filesystem rule."

To rebuild the layout on a fresh WSL machine, run from this project's root:

    init-fast-data .venv .pytest_cache

(Adjust the dir list to match this project's actual hot-data set. `.beads/` is deliberately excluded — git refuses to traverse symlinks and beads-workflow requires the JSONL committed.)
END_OF_README_BLOCK
```

## Validation checks

After running, the skill verifies (in order):

1. Each hot-dir at `<proj>/<rel>` is a symlink: `[ -L "<proj>/<rel>" ]`.
2. `readlink -f <proj>/<rel>` resolves to a path under `/root/`.
3. The resolved ext4 dir exists and is non-empty (or expected-empty for fresh dirs).
4. The filesystem hosting `/root/` is one of the linux-native types: `stat -f / | grep -E 'Type: (ext[234]|btrfs|xfs|zfs)'`. (Note: WSL2 reports ext4 as **`ext2/ext3`** in `stat -f`, not `ext4` — naive `grep ext4` is always-false. Don't fall for it.)
5. `<proj>/.gitignore` contains `/<rel>` or bare `<rel>` for each hot-dir.
6. For shared-DB: parent symlink target lives at `/root/`, AND nested-project symlinks resolve transitively into `/root/`.

Any failure → skill reports which check failed and stops. Does NOT attempt repair without operator confirmation.

## Anti-patterns

| Don't | Do |
|---|---|
| Symlink `.beads/` to ext4 | **Refuse — incompatible with beads-workflow.** Git refuses to traverse symlinks (`fatal: pathspec '.beads/issues.jsonl' is beyond a symbolic link`), and the beads-workflow requires `git add .beads/issues.jsonl` to commit the issue graph. Leave `.beads/` as a real dir on /mnt/c/; gitignore the SQLite DB + WAL/SHM/lock + `.br_recovery/`; track `issues.jsonl` and `config.json`. The 9p cost is acceptable for the planning workload this dir actually sees (NOT swarm-style concurrent writes). |
| Run on a project already on ext4 (`pwd -P` not under /mnt/c/) | Skill exits early — no migration needed |
| Manually create `/root/projects-data/<proj>/<rel>` + `ln -s` yourself | Use `init-fast-data` — does cross-fs copy + size-verify + source-delete + .gitignore + idempotency in one safe step |
| Skip the `.gitignore` step | Hot-data must be gitignored — it lives outside the repo's git tree |
| Commit the symlinks themselves expecting them to work on collaborators' machines | Document via the README section above; collaborators rebuild via `init-fast-data` (or this skill) |
| Auto-edit existing README without confirmation | Surface proposed addition; let operator choose |
| Run on a /mnt/c/ project without `.git/` | Refuse — too risky to mutate non-git-tracked layouts |
| Forget the shared-DB case for nested projects | Walk symlinks recursively; run from the deepest non-symlinked parent |
| Use naive `grep ext4` for filesystem-type checks | WSL2's `stat -f` reports ext4 as `ext2/ext3`; use `grep -E 'ext[234]'` or just check path is under `/root/` |
| Run while live processes have the data open | `init-fast-data` refuses via `lsof +D`; kill the holding processes first |

## Idempotency + safety guards

`init-fast-data` is safe to re-run. The script:

- **Skips already-symlinked dirs** (only when target is under `/root/`; warns if pointing elsewhere).
- **Refuses on basename collisions** — uses a `.init-fast-data.source` stamp file in the data root to detect when two projects with the same basename map to the same `/root/projects-data/<proj>/`. Caller must rename or move-aside.
- **Refuses if any open file handles** are detected in the target dir (`lsof +D` precheck).
- **Atomic-ish migration** — cross-fs copy with `cp -a`, byte-size verify, then source delete. On any failure, partial dest is rolled back.
- **Dedupes `.gitignore`** — checks both `/<rel>` and bare `<rel>` forms before adding.

## Reference

The underlying policy + heuristic table lives in `~/.claude/CLAUDE.md` → "Win+WSL Hybrid Architecture → Hot vs cold filesystem rule." This skill is the systematic workflow; `init-fast-data` is the one-shot tool the workflow drives.
