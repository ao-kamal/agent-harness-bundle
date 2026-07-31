# Rename Column (3-Step, Zero-Downtime)

Goal: Rename `users.display_name` to `users.full_name` without downtime.

## Step 1: Add New Column + Backfill

- Add `full_name` as nullable.
- Backfill in batches to avoid long locks.

Example backfill (Postgres-safe batching):

```sql
WITH batch AS (
  SELECT ctid
  FROM users
  WHERE full_name IS NULL
  LIMIT 1000
)
UPDATE users u
SET full_name = u.display_name
FROM batch
WHERE u.ctid = batch.ctid;
```

Run repeatedly until complete.

## Step 2: Dual-Write and Read Switch

- Deploy app code that writes both `display_name` and `full_name`.
- Reads should prefer `full_name`, fallback to `display_name`.
- Monitor for parity issues.

## Step 3: Drop Old Column

- After at least one full rollout window, remove writes to `display_name`.
- Drop the old column in a final migration.

```sql
ALTER TABLE users DROP COLUMN display_name;
```

## Safety Notes

- Never rename directly in production.
- Keep rollback ready until after Step 3 is complete.
