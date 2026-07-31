---
name: git-commit-craftsman
display_name: Git Commit Craftsman
description: >-
  Write clear, conventional commit messages with proper scope. Generate
  well-structured commits following Conventional Commits with good subject lines,
  helpful body text, and proper footers.
triggers:
  - commit
  - git commit
  - write commit
  - commit message
  - conventional commit
version: 1.0.0
author: jeffrey
category: workflow
tags:
  - ctx-cli
  - ctx-git
  - tool-git
difficulty: beginner
---

# Git Commit Craftsman

Write clear, conventional commit messages that make your git history readable and useful. This skill teaches the **Conventional Commits** specification with practical examples.

## Why Good Commit Messages Matter

- **Clearer history** → Faster debugging when things break
- **Better review context** → Fewer regressions slip through
- **Easier releases** → Changelogs write themselves
- **Team communication** → Future you (and teammates) will thank you

---

## The Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Required:** `type` and `subject`
**Optional:** `scope`, `body`, `footer`

---

## Commit Types

| Type       | When to Use                 | Example                                          |
| ---------- | --------------------------- | ------------------------------------------------ |
| `feat`     | New feature for users       | `feat(auth): add Google OAuth login`             |
| `fix`      | Bug fix for users           | `fix(api): handle null user in profile endpoint` |
| `docs`     | Documentation only          | `docs(readme): add installation steps`           |
| `style`    | Formatting, no code change  | `style(lint): fix eslint warnings`               |
| `refactor` | Code change, no feature/fix | `refactor(db): extract query builder`            |
| `perf`     | Performance improvement     | `perf(api): cache user lookups`                  |
| `test`     | Adding/updating tests       | `test(auth): add login failure cases`            |
| `chore`    | Maintenance tasks           | `chore(deps): update dependencies`               |
| `ci`       | CI/CD changes               | `ci(github): add deploy workflow`                |
| `build`    | Build system changes        | `build(docker): optimize image size`             |

---

## Scope Examples

The scope identifies what part of the codebase changed:

| Scope    | Meaning                      |
| -------- | ---------------------------- |
| `auth`   | Authentication/authorization |
| `api`    | API endpoints                |
| `ui`     | User interface               |
| `db`     | Database/schema              |
| `cli`    | Command-line interface       |
| `deps`   | Dependencies                 |
| `config` | Configuration                |

---

## Subject Line Rules

1. **Use imperative mood** — "add feature" not "added feature"
2. **Don't capitalize** first letter — `add` not `Add`
3. **No period** at the end
4. **Max 50 characters** — be concise

**Good:** `add user profile validation`
**Bad:** `Added user profile validation.`

---

## Body Rules

1. **Wrap at 72 characters** per line
2. **Explain WHAT and WHY**, not HOW (code shows how)
3. **Use bullet points** for multiple changes
4. **Reference issues** with `#123` or `Fixes #123`

---

## Footer Patterns

### Issue References

```
Fixes #123
Closes #456
Refs #789
```

### Breaking Changes

```
BREAKING CHANGE: API now requires authentication header

The /api/users endpoint no longer accepts anonymous requests.
Update clients to include Bearer token.
```

### Co-authors

```
Co-authored-by: Name <email@example.com>
```

---

## Complete Examples

### Simple Feature

```
feat(auth): add Google OAuth login flow

Users can now sign in with their Google accounts. This adds:
- OAuth callback handler
- Token refresh logic
- User profile sync

Closes #142
```

### Bug Fix with Context

```
fix(webhooks): ensure idempotent delivery with dedup key

Webhook deliveries were being duplicated when the worker restarted
during processing. Added a unique delivery ID to prevent retries
from creating duplicates.

Root cause: Missing transaction boundary in queue processor.

Fixes #287
```

### Breaking Change

```
feat(api)!: require authentication for all endpoints

BREAKING CHANGE: All API endpoints now require Bearer token auth.

Previously, read-only endpoints were public. This change improves
security but requires all clients to authenticate.

Migration:
1. Generate API key in dashboard
2. Add Authorization header to requests
3. Handle 401 responses

Refs #301
```

### Multi-File Refactor

```
refactor(db): extract query builder from repository classes

Moved SQL generation into dedicated QueryBuilder class to:
- Reduce duplication across repositories
- Enable query composition
- Simplify testing with mock builder

No behavior changes. All existing tests pass.
```

### Dependency Update

```
chore(deps): update react to 19.0.0

- Updated react and react-dom to 19.0.0
- Migrated deprecated lifecycle methods
- Updated test snapshots

No breaking changes in application code.
```

---

## Anti-Patterns (Don't Do This)

| Bad               | Why It's Bad                  |
| ----------------- | ----------------------------- |
| `fix bug`         | What bug? Where?              |
| `update code`     | What code? What changed?      |
| `WIP`             | Don't commit work-in-progress |
| `misc changes`    | Be specific                   |
| `Fixed the thing` | Past tense, vague             |
| `asdf`            | Meaningless                   |
| `PR feedback`     | Describe the actual change    |
| `Refactoring.`    | No period, explain what       |

---

## Quick Decision Tree

```
Is it a new feature users can see?
  → feat

Does it fix a bug?
  → fix

Does it change behavior without fixing/adding?
  → refactor

Does it make things faster?
  → perf

Does it only touch tests?
  → test

Does it only touch docs?
  → docs

Is it build/CI/tooling?
  → chore, ci, or build
```

---

## Git Workflow Integration

### Before Committing

1. **Review your diff** — `git diff --staged`
2. **One logical change per commit** — don't mix unrelated changes
3. **Run tests** — ensure commit doesn't break the build

### Writing the Message

```bash
# Open editor for full message
git commit

# Quick message (subject only)
git commit -m "feat(auth): add password reset flow"

# Subject + body
git commit -m "feat(auth): add password reset flow" -m "Adds email-based password reset with secure token generation."
```

### Amending (Before Push Only)

```bash
# Fix the last commit message
git commit --amend

# Add forgotten files to last commit
git add forgotten-file.ts
git commit --amend --no-edit
```

---

## Template for Your Editor

Configure git to use a commit template:

```bash
git config --global commit.template ~/.gitmessage
```

See `templates/commit-message.md` for a ready-to-use template.

---

## Validation Checklist

Before pushing, verify:

- [ ] Type is correct for the change
- [ ] Scope accurately identifies affected area
- [ ] Subject is imperative, lowercase, under 50 chars
- [ ] Body explains WHY (if non-obvious)
- [ ] Breaking changes marked with `!` and `BREAKING CHANGE`
- [ ] Related issues referenced
