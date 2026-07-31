# Self-Test: multi-agent-coordination

This file validates that the skill package is complete and follows all requirements.

---

## Structure Validation

### Required Files

- [x] `SKILL.md` exists with valid YAML frontmatter
- [x] `examples/refactoring-example.md` exists
- [x] `templates/task-assignment.md` exists
- [x] `references/mcp-agent-mail-api.md` exists
- [x] `SELF-TEST.md` exists (this file)

### Frontmatter Validation

```yaml
name: multi-agent-coordination # ✓ Matches directory name
description: >- # ✓ Present and descriptive
  Coordinate multiple Claude Code agents...
triggers: # ✓ Has relevant triggers
  - coordinate agents
  - multi-agent
  - parallel agents
  - agent mail
version: 1.0.0 # ✓ Semantic version
author: jeffrey # ✓ Correct author
category: multi-agent # ✓ Appropriate category
difficulty: advanced # ✓ Appropriate difficulty
```

---

## Content Validation

### SKILL.md Requirements

- [x] **Explicit reservation examples**: Section "Step 3: Reserve Files" shows glob patterns
- [x] **Task assignment template reference**: Links to templates/task-assignment.md
- [x] **Merge/integration checklist**: Section "Step 6: Integrate Results"
- [x] **Guidance for handling blockers**: Section "Handling Conflicts"
- [x] **Architecture diagram**: ASCII diagram showing orchestrator/worker pattern
- [x] **When to use guidance**: Table with scenarios and recommendations

### Example File Requirements

- [x] **Realistic scenario**: Database migration to Drizzle ORM
- [x] **Multi-phase workflow**: Setup → Spawn → Monitor → Integrate
- [x] **Concrete code examples**: File reservation calls, message examples
- [x] **Results comparison**: Solo vs multi-agent timing table
- [x] **Lessons learned**: Documented insights from example

### Template File Requirements

- [x] **Complete structure**: All sections for task assignment
- [x] **Placeholder markers**: [TASK_NAME], [WORKER_NAME], etc.
- [x] **Communication protocol**: How to report blockers/completion
- [x] **Acceptance criteria section**: Checklist format
- [x] **Quick checklist**: Pre-start verification

### Reference File Requirements

- [x] **Core tools documented**: ensure_project, register_agent, send_message, etc.
- [x] **File reservation tools**: file_reservation_paths, release, renew, force_release
- [x] **Code examples**: Python-style function calls
- [x] **Error handling table**: Common errors and solutions
- [x] **Best practices**: Naming, etiquette, strategy

---

## Safety Validation

### No Protected Content

- [x] Does NOT contain `writing-skills` methodology
- [x] Does NOT explain how to create skills
- [x] Focuses purely on agent coordination, not skill authoring

### Safe Operations

- [x] No dangerous commands without context
- [x] Force-release documented with caution
- [x] Reservation TTLs encourage reasonable durations
- [x] Integration step includes running tests before commit

---

## Completeness Checklist

Per the task specification (jsm-yrz.11.3):

- [x] Workflow steps cover all 6 phases from spec
- [x] Best practices section present
- [x] Package contents match spec structure
- [x] Examples show realistic multi-agent scenario
- [x] Templates are ready-to-use
- [x] References cover MCP Agent Mail API

---

## Manual Verification Steps

To fully validate this skill, an agent should be able to:

1. **Read SKILL.md** and understand the multi-agent workflow
2. **Copy task-assignment.md template** and customize for a real task
3. **Reference mcp-agent-mail-api.md** for correct tool usage
4. **Follow refactoring-example.md** as a guide for complex migrations
5. **Complete a multi-agent task** with fewer conflicts than uncoordinated work

---

## Validation Status

| Check                    | Status |
| ------------------------ | ------ |
| Structure complete       | PASS   |
| Frontmatter valid        | PASS   |
| Content requirements met | PASS   |
| No protected content     | PASS   |
| Safe operations          | PASS   |
| Completeness             | PASS   |

**Overall**: VALID
