---
name: multi-agent-coordination
display_name: Multi-Agent Coordination
description: >-
  Coordinate multiple Claude Code agents on complex tasks using MCP Agent Mail.
  Use when running parallel agents, orchestrating large refactors, or
  coordinating frontend/backend/test specialists.
triggers:
  - coordinate agents
  - multi-agent
  - parallel agents
  - agent mail
  - agent swarm
  - orchestrate agents
version: 1.0.0
author: jeffrey
category: multi-agent
tags:
  - ctx-multi-agent
  - tool-mcp
  - tool-agent-mail
  - workflow-coordination
difficulty: advanced
---

# Multi-Agent Coordination

Orchestrate multiple Claude Code agents working on different parts of a large task using **MCP Agent Mail**. This skill covers message-based coordination, file reservations to prevent conflicts, and structured task decomposition.

## Prerequisites

- MCP Agent Mail server configured and running
- Understanding of your project's file structure
- Clear task boundaries for parallelization

## Architecture Overview

```
                    ┌─────────────────────┐
                    │   Orchestrator      │
                    │   (You/Main Agent)  │
                    └──────────┬──────────┘
                               │
              ┌────────────────┼────────────────┐
              │                │                │
              ▼                ▼                ▼
     ┌────────────┐   ┌────────────┐   ┌────────────┐
     │  Worker A  │   │  Worker B  │   │  Worker C  │
     │ (Frontend) │   │ (Backend)  │   │  (Tests)   │
     └──────┬─────┘   └──────┬─────┘   └──────┬─────┘
            │                │                │
            ▼                ▼                ▼
     ┌──────────────────────────────────────────────┐
     │          File Reservations (Locks)           │
     │  src/components/** │ src/api/** │ tests/**   │
     └──────────────────────────────────────────────┘
```

---

## When to Use Multi-Agent Coordination

| Scenario                     | Recommendation             |
| ---------------------------- | -------------------------- |
| Large refactors (10+ files)  | Use this skill             |
| Parallel feature development | Use this skill             |
| Specialized roles (FE/BE/QA) | Use this skill             |
| Simple bug fix (1-3 files)   | Single agent is sufficient |
| Sequential dependent changes | Single agent is simpler    |

---

## Workflow Steps

### Step 1: Register as Orchestrator

Before spawning workers, establish your identity and reserve orchestrator-level files:

```bash
# Using MCP Agent Mail tools
ensure_project(human_key="/your/project/path")
register_agent(
    project_key="/your/project/path",
    program="claude-code",
    model="opus-4.5",
    task_description="Orchestrating multi-agent refactor"
)
```

**Record your agent name** (e.g., "BlueLake") - you'll use this to send/receive messages.

### Step 2: Plan Task Decomposition

Analyze the work and identify parallelizable boundaries:

1. **File boundaries**: Which files can be modified independently?
2. **Logical boundaries**: Frontend vs backend vs tests
3. **Dependency boundaries**: What must complete before other work starts?

**Good decomposition example:**

```
Task: "Add user authentication feature"

Worker A (Frontend):
  - src/components/LoginForm.tsx
  - src/components/AuthProvider.tsx
  - src/hooks/useAuth.ts

Worker B (Backend):
  - src/api/auth/*.ts
  - src/lib/auth/*.ts

Worker C (Tests):
  - tests/auth/*.test.ts
  - tests/e2e/login.spec.ts
```

**Bad decomposition** (overlapping concerns):

```
Worker A: "Implement login"     # Too vague, files overlap
Worker B: "Handle auth state"   # Will conflict with A
```

### Step 3: Reserve Files

Before spawning workers, claim file reservations to prevent conflicts:

```bash
file_reservation_paths(
    project_key="/your/project/path",
    agent_name="BlueLake",  # Your orchestrator name
    paths=[
        "src/components/Auth*",
        "src/api/auth/**",
        "tests/auth/**"
    ],
    ttl_seconds=7200,       # 2 hours
    exclusive=true,
    reason="Multi-agent auth feature implementation"
)
```

**Reservation strategies:**

| Pattern                | Use Case                      |
| ---------------------- | ----------------------------- |
| `src/components/*.tsx` | All components in a directory |
| `src/api/auth/**`      | All files in auth subtree     |
| `README.md`            | Single file                   |
| `*.config.ts`          | All config files              |

### Step 4: Spawn Agents with Clear Instructions

Each worker needs explicit instructions. Use this template:

```markdown
## Task Assignment for Worker A

**Role**: Frontend Authentication

**Reserved Files** (you may edit these):

- src/components/LoginForm.tsx
- src/components/AuthProvider.tsx
- src/hooks/useAuth.ts

**Constraints**:

- Do NOT modify files outside your reservation
- Follow existing code patterns
- Add TypeScript types for all exports

**Deliverables**:

1. [ ] LoginForm component with email/password fields
2. [ ] AuthProvider context for session state
3. [ ] useAuth hook with login/logout methods

**Communication**:

- Reply to this thread when blocked
- Mark deliverables complete in your reply
- Tag @BlueLake (orchestrator) for questions

**Deadline**: Complete before integration phase
```

Send the assignment via Agent Mail:

```bash
send_message(
    project_key="/your/project/path",
    sender_name="BlueLake",
    to=["WorkerAgentName"],
    subject="Task Assignment: Frontend Authentication",
    body_md="...",  # Template above
    thread_id="AUTH-FEATURE-001"
)
```

### Step 5: Monitor Progress

Periodically check your inbox for updates:

```bash
fetch_inbox(
    project_key="/your/project/path",
    agent_name="BlueLake",
    include_bodies=true
)
```

**Handle blockers proactively:**

- If a worker reports a blocker, respond immediately
- Adjust reservations if work boundaries need to shift
- Spawn additional workers if bottlenecks form

### Step 6: Integrate Results

When workers report completion:

1. **Release reservations** for completed sections:

   ```bash
   release_file_reservations(
       project_key="/your/project/path",
       agent_name="BlueLake",
       paths=["src/components/Auth*"]
   )
   ```

2. **Run integration tests**:

   ```bash
   bun run test
   bun run lint
   bun run typecheck
   ```

3. **Review integration points** - files that multiple workers may have touched indirectly

4. **Commit combined changes** with attribution:

   ```bash
   git commit -m "feat: Add user authentication

   Co-authored-by: Worker A <worker-a@agents>
   Co-authored-by: Worker B <worker-b@agents>
   "
   ```

---

## Best Practices

### Keep Subtasks Independent

- Each worker should be able to complete their task without waiting for others
- If dependencies exist, sequence the work phases

### Over-Communicate Context

- Include full context in task assignments
- Workers don't have your conversation history
- Specify exact file paths, not vague descriptions

### Reserve Conservatively

- Only reserve files you'll actually modify
- Set reasonable TTLs (don't lock for 24 hours)
- Release reservations as soon as work completes

### Set Clear Deliverables

- Use checkboxes for discrete items
- Define "done" explicitly (tests passing, types added, etc.)
- Include acceptance criteria

### Plan for Failures

- What if a worker crashes? Document recovery steps
- What if work takes longer? Have escalation path
- What if conflicts arise? Define resolution process

---

## Common Patterns

### Pattern 1: Divide by Layer

```
Orchestrator assigns:
- Worker A: UI components
- Worker B: API routes
- Worker C: Database queries
- Worker D: Tests for all layers
```

### Pattern 2: Divide by Feature Slice

```
Orchestrator assigns:
- Worker A: User auth (all layers)
- Worker B: Billing (all layers)
- Worker C: Dashboard (all layers)
```

### Pattern 3: Specialist + Generalist

```
Orchestrator assigns:
- Specialist A: Security-sensitive code
- Generalist B: Bulk migrations
- Generalist C: Documentation updates
```

---

## Handling Conflicts

If you encounter `FILE_RESERVATION_CONFLICT`:

1. **Check who holds the reservation**:

   ```bash
   # The conflict response includes holder info
   ```

2. **Coordinate via message**:

   ```bash
   send_message(
       to=["ConflictingAgent"],
       subject="Reservation conflict on src/api/*",
       body_md="I need to modify src/api/users.ts. Can you release or coordinate?"
   )
   ```

3. **Wait for expiry** (if agent is inactive)

4. **Force release** (only if agent confirmed inactive):
   ```bash
   force_release_file_reservation(
       project_key="...",
       agent_name="YourName",
       file_reservation_id=123,
       note="Agent appears inactive for >30 mins"
   )
   ```

---

## Troubleshooting

| Problem                | Cause                    | Solution                             |
| ---------------------- | ------------------------ | ------------------------------------ |
| "Agent not registered" | Missing registration     | Call `register_agent` first          |
| Reservation conflict   | Another agent holds lock | Message holder or wait for TTL       |
| Messages not received  | Wrong project_key        | Verify exact path                    |
| Workers not responding | May have crashed         | Check process status, respawn        |
| Integration failures   | Incomplete work          | Verify all deliverables before merge |

---

## Next Steps

After mastering basic coordination:

1. Use thread summaries for complex multi-day efforts
2. Implement pre-commit guards to enforce reservations
3. Set up automated status broadcasts for long-running tasks
4. Explore the MCP Agent Mail API reference for advanced patterns
