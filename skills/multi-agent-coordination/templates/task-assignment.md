# Task Assignment Template

Copy and customize this template when spawning worker agents.

---

## Task Assignment: [TASK_NAME]

**Agent**: [WORKER_NAME]
**Thread ID**: [THREAD-XXX]
**Orchestrator**: [YOUR_AGENT_NAME]
**Priority**: [P0/P1/P2/P3]
**Estimated Duration**: [X hours]

---

### Context

[Provide background on the larger effort. Workers don't have your conversation history.]

**Project Goal**: [What is the overall objective?]

**Your Role**: [What specialized function does this worker serve?]

**Why This Matters**: [How does this task contribute to the goal?]

---

### Reserved Files

You have exclusive write access to these files/patterns:

```
[List exact paths or glob patterns]
- src/components/Auth*.tsx
- src/hooks/useAuth.ts
- tests/auth/*.test.ts
```

**Do NOT modify** files outside this list. If you need to change other files, message the orchestrator first.

---

### Task Description

[Clear, specific description of what needs to be done]

#### Subtasks

1. [ ] [First deliverable]
2. [ ] [Second deliverable]
3. [ ] [Third deliverable]

---

### Technical Requirements

**Code Patterns to Follow**:

```typescript
// Example of expected pattern
[Show code example if applicable]
```

**Constraints**:

- [Constraint 1: e.g., "Use existing error handling patterns"]
- [Constraint 2: e.g., "Maintain backward compatibility"]
- [Constraint 3: e.g., "Add TypeScript types for all exports"]

**Dependencies**:

- [Dependency 1: e.g., "Wait for Worker B to complete schema before final type check"]
- [Dependency 2: e.g., "Use the API from @/lib/auth (already exists)"]

---

### Acceptance Criteria

This task is complete when:

- [ ] All subtasks above are checked
- [ ] Code compiles without errors (`bun run typecheck`)
- [ ] Relevant tests pass (`bun run test [files]`)
- [ ] Lint passes (`bun run lint [files]`)
- [ ] [Any additional criteria]

---

### Communication Protocol

**When to message the orchestrator**:

- You encounter a blocker
- You need to modify files outside your reservation
- You discover scope creep or unexpected complexity
- You complete all deliverables

**How to report completion**:

```markdown
## Completion Report

**Status**: Complete / Partial / Blocked

**Deliverables**:

- [x] Deliverable 1 - [notes]
- [x] Deliverable 2 - [notes]
- [ ] Deliverable 3 - BLOCKED: [reason]

**Test Results**:

- Tests: X passed, Y failed
- Type check: Clean / X errors
- Lint: Clean / X warnings

**Notes**:
[Any context for the orchestrator]

**Files Modified**:

- src/components/AuthForm.tsx (created)
- src/hooks/useAuth.ts (modified)
```

**Thread ID**: Always use `[THREAD-XXX]` in your messages for tracking.

---

### Escalation

If you are blocked for more than **30 minutes**:

1. Send a message with subject prefix `BLOCKED:`
2. Include what you've tried
3. Include what you need to proceed
4. Tag the orchestrator explicitly

---

### Reference Materials

- [Link to relevant documentation]
- [Link to similar completed work]
- [Link to API reference]

---

## Quick Checklist Before Starting

- [ ] I understand my reserved files
- [ ] I understand the acceptance criteria
- [ ] I know how to report blockers
- [ ] I have all dependencies I need (or know what to wait for)
