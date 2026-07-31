# Git Commit Message Template

Copy this template to `~/.gitmessage` and configure git:

```bash
git config --global commit.template ~/.gitmessage
```

---

## Template File

Save this content as `~/.gitmessage`:

```
# <type>(<scope>): <subject>
# │       │         │
# │       │         └─⫸ Summary in imperative mood, max 50 chars, no period
# │       │
# │       └─⫸ Commit Scope: auth|api|ui|db|cli|deps|config|etc.
# │
# └─⫸ Commit Type: feat|fix|docs|style|refactor|perf|test|chore|ci|build

# --- Body (optional) ---
# Explain WHAT changed and WHY. Wrap at 72 characters.
# Use bullet points for multiple changes:
# - First change
# - Second change

# --- Footer (optional) ---
# Refs #123
# Fixes #456
# BREAKING CHANGE: Description of what breaks and how to migrate
# Co-authored-by: Name <email@example.com>

# ─────────────────────────────────────────────────────────────────
# Types:
#   feat:     New feature for the user
#   fix:      Bug fix for the user
#   docs:     Documentation only changes
#   style:    Formatting, white-space (no code change)
#   refactor: Code change that neither fixes nor adds feature
#   perf:     Performance improvement
#   test:     Adding or updating tests
#   chore:    Maintenance tasks
#   ci:       CI/CD changes
#   build:    Build system or dependencies
#
# Rules:
#   - Subject: imperative mood, lowercase, no period, max 50 chars
#   - Body: wrap at 72 chars, explain what/why not how
#   - Footer: issue refs, breaking changes, co-authors
#   - Breaking: add ! after type, e.g., feat(api)!: change auth
# ─────────────────────────────────────────────────────────────────
```

---

## Usage

After configuring, running `git commit` (without `-m`) opens your editor with this template. Lines starting with `#` are comments and won't appear in the final message.

### Quick Commits

For simple commits, you can still use `-m`:

```bash
git commit -m "fix(auth): handle expired token gracefully"
```

### Multi-line Commits

For commits that need a body:

```bash
git commit -m "feat(api): add user search endpoint" -m "Supports filtering by name, email, and role. Returns paginated results with total count."
```

---

## Editor Tips

### VS Code

Add to settings.json:

```json
{
  "git.inputValidationSubjectLength": 50,
  "git.inputValidationLength": 72
}
```

### Vim

Add to .vimrc:

```vim
autocmd FileType gitcommit setlocal textwidth=72
autocmd FileType gitcommit setlocal spell
```

### Emacs

Add to init.el:

```elisp
(add-hook 'git-commit-mode-hook
          (lambda ()
            (setq fill-column 72)
            (turn-on-auto-fill)))
```
