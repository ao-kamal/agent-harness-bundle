# Self-Test: git-commit-craftsman

This file validates the skill contains all required content per the plan specification.

## Validation Checklist

### SKILL.md Structure

- [x] **Frontmatter present** with required fields:
  - [x] `name: git-commit-craftsman`
  - [x] `description` with clear purpose
  - [x] `triggers` including "commit", "git commit", "write commit"
  - [x] `version: 1.0.0`
  - [x] `author: jeffrey`

### Types Table

- [x] **Commit types table exists** with all required types:
  - [x] `feat` - new features
  - [x] `fix` - bug fixes
  - [x] `docs` - documentation
  - [x] `style` - formatting
  - [x] `refactor` - code restructuring
  - [x] `perf` - performance
  - [x] `test` - tests
  - [x] `chore` - maintenance
  - [x] `ci` - CI/CD
  - [x] `build` - build system

### Scope Examples

- [x] **Scope examples included**:
  - [x] `auth`
  - [x] `api`
  - [x] `ui`
  - [x] `db`
  - [x] `cli`
  - [x] `deps`

### Subject Line Rules

- [x] **Subject rules documented**:
  - [x] Imperative mood requirement
  - [x] Don't capitalize first letter
  - [x] No period at end
  - [x] Max 50 characters

### Body Rules

- [x] **Body rules documented**:
  - [x] Wrap at 72 characters
  - [x] Explain WHAT and WHY, not HOW
  - [x] Use bullets for multiple items
  - [x] Reference issues with `#123`

### Examples

- [x] **Required examples present**:
  - [x] Simple feature commit
  - [x] Bug fix with context
  - [x] Breaking change with `!` and `BREAKING CHANGE` footer
  - [x] Multi-file refactor example
  - [x] Dependency update example

### Anti-Patterns

- [x] **Anti-patterns list exists** with bad examples:
  - [x] `fix bug` (vague)
  - [x] `update code` (vague)
  - [x] `WIP` (incomplete)
  - [x] `misc changes` (vague)
  - [x] Past tense examples
  - [x] Meaningless commits

### Additional Content

- [x] **Template file exists**: `templates/commit-message.md`
- [x] **Examples file exists**: `examples/commit-examples.md`

## Manual Verification Steps

To fully validate this skill:

1. **Read SKILL.md** and verify it teaches conventional commits clearly
2. **Check the types table** matches Conventional Commits spec
3. **Review examples** for accuracy and usefulness
4. **Test the template** by using it for an actual commit
5. **Verify accessibility** - a beginner should understand the content

## Test Commands

```bash
# Verify file structure
ls -la content/premium-skills/git-commit-craftsman/

# Expected output:
# SKILL.md
# SELF-TEST.md
# templates/commit-message.md
# examples/commit-examples.md

# Check frontmatter
head -20 content/premium-skills/git-commit-craftsman/SKILL.md

# Verify types table exists
grep -A 15 "Commit Types" content/premium-skills/git-commit-craftsman/SKILL.md

# Verify anti-patterns exist
grep -A 10 "Anti-Patterns" content/premium-skills/git-commit-craftsman/SKILL.md

# Verify breaking change example exists
grep -i "BREAKING CHANGE" content/premium-skills/git-commit-craftsman/SKILL.md
```

## Acceptance Criteria Status

| Criterion                     | Status |
| ----------------------------- | ------ |
| Matches plan spec             | ✅     |
| Includes concrete examples    | ✅     |
| Passes validation             | ✅     |
| Self-contained (no plan refs) | ✅     |
| Beginner accessible           | ✅     |
| Senior useful                 | ✅     |

## Notes

- This skill follows Conventional Commits 1.0.0 specification
- Examples drawn from real-world patterns
- Template compatible with git's commit.template feature
- Does not include protected content (skill-creation methodology)
