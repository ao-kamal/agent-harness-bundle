---
name: database-migration-expert
display_name: Database Migration Expert
description: >-
  Create safe, reversible database migrations with Drizzle ORM and Supabase Postgres.
  Use when creating migrations, adding columns/tables, changing indexes, or planning
  zero-downtime schema changes.
triggers:
  - create migration
  - database migration
  - add column
  - add table
  - drizzle migrate
version: 1.0.0
author: jeffrey
category: devops
tags:
  - tool-drizzle
  - tool-supabase
  - db-postgres
  - ctx-production
difficulty: advanced
---

# Database Migration Expert

Generate safe, reversible database migrations for Supabase Postgres using Drizzle ORM. Default to
zero-downtime patterns and call out anything risky before proceeding.

## Quick Start (Repo Defaults)

1. Update `src/lib/db/schema.ts` with the desired change.
2. Generate migration SQL:
   ```bash
   bun run db:generate --name <migration-name>
   ```
3. Review the generated SQL in `drizzle/` for safety.
4. Apply locally or in a controlled environment:
   ```bash
   bun run db:push
   ```

For production, prefer explicit migration application and `CREATE INDEX CONCURRENTLY` when needed.

## Pre-Migration Checklist (Must Answer)

- Locks? What locks does this change take?
- Rollback path? How do we undo safely?
- Tested on prod-like data?
- Idempotent? Can it be re-run safely?
- Requires code deploy ordering?

## Safe Operations Table

| Status | Operation                          | Notes                                                                                           |
| ------ | ---------------------------------- | ----------------------------------------------------------------------------------------------- |
| OK     | Add table                          | Low risk; still review indexes and constraints.                                                 |
| OK     | Add nullable column                | Safe and non-blocking.                                                                          |
| OK     | Add column with default (Postgres) | Safe in PG 11+ (metadata-only). For large tables, prefer add nullable + backfill + set default. |
| OK     | Add index concurrently             | Use `CONCURRENTLY` in production to avoid table locks.                                          |
| WARN   | Drop unused column                 | Only after confirming no reads/writes; prefer soft-deprecate first.                             |
| NO     | Rename column                      | Requires multi-step migration.                                                                  |
| NO     | Change column type                 | Requires multi-step migration.                                                                  |

## Core Principles

1. Always reversible.
2. Zero-downtime safe (avoid blocking locks).
3. Preserve data by default.
4. Make changes incrementally.

## Standard Workflow

1. **Clarify intent**: What is the schema change and why?
2. **Choose safe path**: If rename or type change, use multi-step plan.
3. **Update schema** in `src/lib/db/schema.ts`.
4. **Generate SQL** and inspect for locks/rewrites.
5. **Add rollback** plan before executing.
6. **Execute** in staged environments.
7. **Verify** with targeted queries or tests.

## Migration Template (Drizzle Schema Example)

Use `templates/migration-template.ts` as a starting point for a new table + indexes + unique constraint.
After updating the schema, generate SQL with `bun run db:generate --name <migration-name>`.

## Multi-Step Rename Pattern (3 Migrations)

**Goal:** Rename `old_name` to `new_name` without downtime.

1. **Add new column + backfill**
   - Add `new_name` as nullable.
   - Backfill data in batches.
2. **Dual-write / read-switch**
   - Deploy app code that writes both columns and reads `new_name`.
   - Verify parity.
3. **Finalize**
   - Stop writing `old_name`.
   - Drop `old_name` after a full rollout window.

See `examples/rename-column-3-step.md`.

## Index Creation Guidance

- In production, prefer `CREATE INDEX CONCURRENTLY` to avoid blocking writes.
- Concurrent index creation cannot run inside a transaction.
- If Drizzle generates a blocking index, split it into a separate migration with manual SQL.

## Rollback Template

Use `templates/rollback-template.ts` to document rollback SQL. Every migration must have a rollback
plan, even if it is "drop the new table".

## Output Requirements

When responding to a migration request, provide:

1. **Migration plan** (steps + safety notes)
2. **Schema diff** (what changes in `schema.ts`)
3. **SQL review summary** (locks, rewrites, constraints)
4. **Rollback plan**
5. **Verification steps** (queries or tests)

## Validation

- Run the pre-migration checklist.
- Confirm the safe operations table applies.
- Ensure the rollback template exists for the change.
