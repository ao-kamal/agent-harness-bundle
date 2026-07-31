# Commit Message Examples

Real-world examples organized by type and complexity.

---

## Feature Commits

### Simple Feature

```
feat(auth): add password reset via email

Users can request a password reset link sent to their email.
Token expires after 1 hour.

Closes #142
```

### Feature with Breaking Change

```
feat(api)!: require API key for all endpoints

BREAKING CHANGE: All API endpoints now require authentication.

Previously, read endpoints were public. This improves security
but requires clients to update.

Migration steps:
1. Generate an API key in Settings > API
2. Add header: Authorization: Bearer <key>
3. Handle 401 responses for invalid/expired keys

Refs #301
```

### Complex Feature

```
feat(dashboard): add real-time notifications

Implements WebSocket-based notifications showing:
- New messages
- Task assignments
- System alerts

Features:
- Automatic reconnection on disconnect
- Unread badge counter
- Sound toggle in user preferences
- Mobile-friendly slide-up animation

Browser support: Chrome 80+, Firefox 75+, Safari 14+

Closes #567, #568
```

---

## Bug Fix Commits

### Simple Fix

```
fix(api): return 404 for missing user instead of 500

The endpoint was throwing an unhandled exception when
user ID didn't exist. Now returns proper 404 response.

Fixes #234
```

### Fix with Root Cause

```
fix(webhooks): prevent duplicate deliveries on worker restart

Webhook deliveries were duplicated when the worker process
restarted during message processing.

Root cause: Queue acknowledgment happened after HTTP call,
so unfinished deliveries were re-queued on restart.

Fix: Generate idempotency key from delivery ID. Receivers
can deduplicate using X-Delivery-Id header.

Fixes #287
```

### Security Fix

```
fix(auth): prevent timing attack on password comparison

Changed from direct string comparison to constant-time
comparison using crypto.timingSafeEqual().

The timing difference was measurable (~50ms variance)
which could leak password length information.

Fixes #401
```

---

## Refactor Commits

### Simple Refactor

```
refactor(db): extract SQL builder from user repository

Moved query construction to dedicated QueryBuilder class.
Reduces duplication and enables better testing.

No behavior changes. All tests pass.
```

### Large Refactor

```
refactor(api): migrate from callbacks to async/await

Converted all API handlers from callback style to modern
async/await syntax for improved readability.

Changes:
- Replaced 47 callback functions
- Added proper error boundaries
- Removed pyramid of doom patterns
- Updated ESLint rules to enforce async style

Tests updated. No functionality changes.
```

---

## Documentation Commits

### Simple Docs

```
docs(readme): add local development setup instructions
```

### API Documentation

```
docs(api): document rate limiting behavior

Added documentation for:
- Rate limit headers (X-RateLimit-*)
- Per-endpoint limits
- Retry-After behavior
- Best practices for handling 429

Refs #445
```

---

## Test Commits

### Adding Tests

```
test(auth): add edge cases for token validation

New test cases:
- Expired token (should return 401)
- Malformed JWT (should return 400)
- Valid token with revoked user (should return 403)
- Token without required scopes (should return 403)

Coverage: 89% → 94%
```

### Fixing Flaky Test

```
test(e2e): fix race condition in notification test

The test was checking for notification before the WebSocket
connection was fully established.

Fix: Wait for 'connected' event before triggering action.
```

---

## Chore Commits

### Dependencies

```
chore(deps): update react to 19.0.0

- Updated react and react-dom to 19.0.0
- Fixed deprecated lifecycle warnings
- Updated test snapshots

No breaking changes in application.
```

### Tooling

```
chore(lint): add stricter TypeScript config

Enabled:
- strict: true
- noImplicitAny: true
- strictNullChecks: true

Fixed 23 type errors revealed by stricter checking.
```

---

## CI/Build Commits

### CI Change

```
ci(github): add automated release workflow

New workflow triggers on version tags (v*) and:
- Runs full test suite
- Builds production artifacts
- Creates GitHub release with changelog
- Publishes to npm registry

Refs #500
```

### Build Change

```
build(docker): reduce image size from 1.2GB to 340MB

Changes:
- Multi-stage build (builder + runtime)
- Alpine base instead of Ubuntu
- Only copy production dependencies
- Remove dev files from final image
```

---

## Performance Commits

```
perf(api): cache user profile lookups

Added Redis cache for user profiles with 5-minute TTL.

Before: p50=45ms, p99=230ms
After:  p50=3ms,  p99=48ms (cache hit)

Cache invalidation triggers:
- User profile update
- User deletion
- Manual cache clear

Refs #333
```

---

## Multi-Author Commits

```
feat(search): implement fuzzy matching algorithm

Adds Levenshtein distance-based fuzzy search for user
queries. Tolerance configurable via SEARCH_FUZZ_DISTANCE.

Co-authored-by: Alice Chen <alice@example.com>
Co-authored-by: Bob Smith <bob@example.com>
```

---

## What NOT to Write

These are real examples of bad commits. Don't do this:

```
# Too vague
fix bug
update code
misc changes
stuff

# Past tense (should be imperative)
Fixed the login issue
Added new feature

# WIP commits (squash before merging)
WIP
wip: still working on it

# No context
asdf
test
temp

# Useless message
PR feedback
Code review changes
```

---

## Commit Message Checklist

Use this before every commit:

- [ ] Type matches the change (feat/fix/docs/etc.)
- [ ] Scope identifies the affected area
- [ ] Subject is imperative ("add" not "added")
- [ ] Subject is under 50 characters
- [ ] Subject starts lowercase, no period
- [ ] Body explains WHY, not just WHAT
- [ ] Body wrapped at 72 characters
- [ ] Breaking changes marked with `!` and footer
- [ ] Related issues referenced in footer
