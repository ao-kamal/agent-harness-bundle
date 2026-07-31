# Example: Multi-Agent Database Migration Refactor

This example demonstrates coordinating three agents to refactor a database layer from raw SQL to an ORM.

## Scenario

**Project**: E-commerce backend
**Task**: Migrate from raw `pg` queries to Drizzle ORM
**Scope**: 47 files, 15,000 LOC
**Estimated solo time**: 8+ hours
**Multi-agent time**: ~2 hours with 3 parallel workers

---

## Phase 1: Orchestrator Setup

### 1.1 Register and Plan

```bash
# Orchestrator registers
ensure_project(human_key="/data/projects/ecommerce-backend")
register_agent(
    project_key="/data/projects/ecommerce-backend",
    program="claude-code",
    model="opus-4.5",
    task_description="Orchestrating Drizzle ORM migration"
)
# Returns: agent_name="CoralReef"
```

### 1.2 Analyze File Distribution

```
src/
├── db/
│   ├── queries/          # 12 files - Worker A
│   │   ├── users.ts
│   │   ├── orders.ts
│   │   ├── products.ts
│   │   └── ...
│   ├── schema/           # 8 files - Worker B
│   │   ├── users.ts
│   │   ├── orders.ts
│   │   └── ...
│   └── client.ts         # 1 file - Orchestrator (shared)
├── api/
│   └── routes/           # 15 files - Worker C
│       ├── users.ts
│       ├── orders.ts
│       └── ...
└── tests/
    └── db/               # 11 files - Worker D
        └── *.test.ts
```

### 1.3 Reserve High-Contention Files

The orchestrator reserves the shared client file that all workers will import:

```bash
file_reservation_paths(
    project_key="/data/projects/ecommerce-backend",
    agent_name="CoralReef",
    paths=["src/db/client.ts", "drizzle.config.ts"],
    ttl_seconds=7200,
    exclusive=true,
    reason="Shared DB client - orchestrator manages"
)
```

---

## Phase 2: Spawn Workers

### 2.1 Worker A: Query Layer

**Reservation:**

```bash
file_reservation_paths(
    paths=["src/db/queries/**"],
    agent_name="CoralReef",  # Orchestrator reserves for worker
    ttl_seconds=3600
)
```

**Assignment message:**

````markdown
## Task: Migrate Query Layer to Drizzle

**Agent**: Worker A
**Thread**: DRIZZLE-MIGRATION-001

### Reserved Files

- src/db/queries/\*.ts (all 12 files)

### Task

Convert all raw SQL queries to Drizzle query builder syntax.

### Pattern to Follow

```typescript
// BEFORE (raw pg)
const users = await pool.query("SELECT * FROM users WHERE id = $1", [id]);

// AFTER (Drizzle)
const users = await db.select().from(usersTable).where(eq(usersTable.id, id));
```
````

### Constraints

- Import db client from '../client' (unchanged path)
- Use the schema types from '../schema/\*' (Worker B will create these)
- Do NOT modify the function signatures (API compatibility)

### Deliverables

- [ ] users.ts migrated (4 queries)
- [ ] orders.ts migrated (6 queries)
- [ ] products.ts migrated (5 queries)
- [ ] inventory.ts migrated (3 queries)
- [ ] All 12 files compile without errors

### Dependency

Wait for Worker B to complete schema files before final compilation.
Message when blocked or complete.

````

### 2.2 Worker B: Schema Definitions

**Assignment message:**
```markdown
## Task: Create Drizzle Schema Definitions

**Agent**: Worker B
**Thread**: DRIZZLE-MIGRATION-001

### Reserved Files
- src/db/schema/*.ts (8 files)

### Task
Create Drizzle table definitions matching the existing PostgreSQL schema.

### Pattern to Follow
```typescript
// src/db/schema/users.ts
import { pgTable, uuid, text, timestamp } from 'drizzle-orm/pg-core'

export const users = pgTable('users', {
  id: uuid('id').primaryKey().defaultRandom(),
  email: text('email').notNull().unique(),
  name: text('name'),
  createdAt: timestamp('created_at').defaultNow()
})

export type User = typeof users.$inferSelect
export type NewUser = typeof users.$inferInsert
````

### Deliverables

- [ ] users.ts schema
- [ ] orders.ts schema (with foreign keys)
- [ ] products.ts schema
- [ ] All 8 schema files with inferred types
- [ ] index.ts re-exporting all schemas

### Priority

This is blocking Worker A. Complete ASAP and notify.

````

### 2.3 Worker C: API Routes

**Assignment message:**
```markdown
## Task: Update API Routes for New Query Signatures

**Agent**: Worker C
**Thread**: DRIZZLE-MIGRATION-001

### Reserved Files
- src/api/routes/*.ts (15 files)

### Task
Update route handlers to use the migrated query functions.
Query signatures are unchanged, but return types may need adjustment.

### Deliverables
- [ ] All routes updated to use new type imports
- [ ] Error handling preserved
- [ ] No runtime changes (queries are drop-in compatible)

### Dependency
Can start immediately - query signatures are stable.
````

### 2.4 Worker D: Test Updates

**Assignment message:**

```markdown
## Task: Update Database Tests

**Agent**: Worker D
**Thread**: DRIZZLE-MIGRATION-001

### Reserved Files

- tests/db/\*.test.ts (11 files)

### Task

Update test files to work with Drizzle's test utilities.

### Key Changes

- Replace mock pool with Drizzle mock
- Update type assertions for inferred types
- Add migration tests for schema

### Deliverables

- [ ] All 11 test files updated
- [ ] Tests pass with mocked Drizzle client
- [ ] Migration test added

### Dependency

Wait for Workers A and B before running tests.
```

---

## Phase 3: Monitor and Coordinate

### 3.1 Orchestrator Monitoring Loop

```bash
# Every 15 minutes
fetch_inbox(
    project_key="/data/projects/ecommerce-backend",
    agent_name="CoralReef",
    since_ts="2026-01-21T10:00:00Z",
    include_bodies=true
)
```

### 3.2 Example: Handling a Blocker

Worker A reports:

```
Subject: BLOCKED: Need orders schema for foreign key types

I need the `orders` table type from Worker B to properly type
the order queries. Currently using `any` as placeholder.

Can Worker B prioritize orders.ts schema?
```

Orchestrator response:

```bash
send_message(
    sender_name="CoralReef",
    to=["WorkerB"],
    cc=["WorkerA"],
    subject="Re: BLOCKED: Need orders schema",
    body_md="@WorkerB please prioritize orders.ts schema. @WorkerA will unblock once you push.",
    thread_id="DRIZZLE-MIGRATION-001"
)
```

---

## Phase 4: Integration

### 4.1 Collect Completion Reports

All workers report complete. Orchestrator verifies:

```bash
# Check all files were modified
git status

# Run full test suite
bun run test

# Type check
bun run typecheck

# Lint
bun run lint
```

### 4.2 Release Reservations

```bash
release_file_reservations(
    project_key="/data/projects/ecommerce-backend",
    agent_name="CoralReef"
)
```

### 4.3 Final Commit

```bash
git add .
git commit -m "refactor: Migrate database layer to Drizzle ORM

- Converted 12 query files from raw pg to Drizzle builder
- Added 8 schema definitions with type inference
- Updated 15 API routes for new types
- Updated 11 test files

Multi-agent coordination via MCP Agent Mail.
Thread: DRIZZLE-MIGRATION-001

Co-authored-by: Worker A <worker-a@agents>
Co-authored-by: Worker B <worker-b@agents>
Co-authored-by: Worker C <worker-c@agents>
Co-authored-by: Worker D <worker-d@agents>
"
```

---

## Results

| Metric             | Solo Agent | Multi-Agent (4)           |
| ------------------ | ---------- | ------------------------- |
| Wall clock time    | ~8 hours   | ~2 hours                  |
| Total agent-hours  | 8          | 8 (same)                  |
| Integration issues | N/A        | 2 (minor type mismatches) |
| Conflicts          | N/A        | 0 (reservations worked)   |

---

## Lessons Learned

1. **Schema first**: Worker B (schema) should complete before Worker A (queries) starts final compilation
2. **Stable interfaces**: Keeping function signatures unchanged simplified integration
3. **Over-communicate types**: Sharing type definitions early prevented rework
4. **Orchestrator stayed available**: Quick blocker resolution kept workers productive
