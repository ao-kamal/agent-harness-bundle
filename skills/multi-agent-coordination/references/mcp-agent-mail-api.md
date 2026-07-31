# MCP Agent Mail API Reference

Quick reference for the MCP Agent Mail tools used in multi-agent coordination.

---

## Core Concepts

### Projects

A project is a working directory where agents collaborate. All agents working in the same directory share the same project.

### Agents

An agent is an identity within a project. Names are auto-generated adjective+noun combinations (e.g., "BlueLake", "CoralReef").

### Messages

Markdown messages with threading support, importance levels, and acknowledgment tracking.

### File Reservations

Advisory locks on file paths or glob patterns to prevent conflicts.

---

## Essential Tools

### Project Setup

#### `ensure_project`

Create or verify a project exists.

```python
ensure_project(
    human_key="/data/projects/my-project"  # Absolute path to working directory
)
# Returns: { id, slug, human_key, created_at }
```

#### `register_agent`

Register or update an agent identity.

```python
register_agent(
    project_key="/data/projects/my-project",
    program="claude-code",        # Agent program type
    model="opus-4.5",             # Model identifier
    task_description="Working on feature X"
)
# Returns: { id, name, program, model, task_description, ... }
```

**Agent naming rules**:

- Names are auto-generated (recommended) or must be adjective+noun
- Valid: "BlueLake", "CoralReef", "GreenHill"
- Invalid: "DatabaseMigrator", "Worker1"

---

### Messaging

#### `send_message`

Send a message to one or more agents.

```python
send_message(
    project_key="/data/projects/my-project",
    sender_name="BlueLake",
    to=["CoralReef", "GreenHill"],   # Primary recipients
    cc=["RedBear"],                   # Optional CC
    subject="Task assignment",
    body_md="## Task\n\nYour work...",
    thread_id="FEATURE-001",          # Optional, for threading
    importance="normal",              # low/normal/high/urgent
    ack_required=False                # Request acknowledgment
)
```

#### `reply_message`

Reply to an existing message (preserves thread).

```python
reply_message(
    project_key="/data/projects/my-project",
    message_id=1234,                  # ID of message to reply to
    sender_name="CoralReef",
    body_md="## Update\n\nTask complete..."
)
```

#### `fetch_inbox`

Get recent messages for an agent.

```python
fetch_inbox(
    project_key="/data/projects/my-project",
    agent_name="BlueLake",
    since_ts="2026-01-21T10:00:00Z",  # Optional: only newer messages
    limit=20,
    include_bodies=True,              # Include full message content
    urgent_only=False                 # Filter to high/urgent only
)
# Returns: [{ id, subject, from, created_ts, importance, body_md, ... }]
```

#### `acknowledge_message`

Mark a message as acknowledged (for ack_required messages).

```python
acknowledge_message(
    project_key="/data/projects/my-project",
    agent_name="CoralReef",
    message_id=1234
)
```

#### `mark_message_read`

Mark a message as read (without acknowledging).

```python
mark_message_read(
    project_key="/data/projects/my-project",
    agent_name="CoralReef",
    message_id=1234
)
```

---

### File Reservations

#### `file_reservation_paths`

Request advisory locks on file patterns.

```python
file_reservation_paths(
    project_key="/data/projects/my-project",
    agent_name="BlueLake",
    paths=[
        "src/components/*.tsx",     # Glob pattern
        "src/hooks/useAuth.ts",     # Specific file
        "tests/auth/**"             # Recursive glob
    ],
    ttl_seconds=3600,               # Lock duration (min 60)
    exclusive=True,                 # Exclusive vs shared
    reason="Auth feature implementation"
)
# Returns: { granted: [...], conflicts: [...] }
```

**Conflict response example**:

```json
{
  "granted": [],
  "conflicts": [
    {
      "path": "src/components/*.tsx",
      "holders": [
        {
          "agent_name": "CoralReef",
          "expires_ts": "2026-01-21T12:00:00Z"
        }
      ]
    }
  ]
}
```

#### `release_file_reservations`

Release your locks.

```python
# Release all your reservations
release_file_reservations(
    project_key="/data/projects/my-project",
    agent_name="BlueLake"
)

# Release specific paths
release_file_reservations(
    project_key="/data/projects/my-project",
    agent_name="BlueLake",
    paths=["src/components/*.tsx"]
)

# Release by ID
release_file_reservations(
    project_key="/data/projects/my-project",
    agent_name="BlueLake",
    file_reservation_ids=[101, 102]
)
```

#### `renew_file_reservations`

Extend TTL without releasing.

```python
renew_file_reservations(
    project_key="/data/projects/my-project",
    agent_name="BlueLake",
    extend_seconds=1800              # Add 30 minutes
)
```

#### `force_release_file_reservation`

Force-release another agent's stale lock.

```python
force_release_file_reservation(
    project_key="/data/projects/my-project",
    agent_name="BlueLake",           # Your name (requester)
    file_reservation_id=123,         # The reservation to release
    note="Agent inactive for >1 hour",
    notify_previous=True             # Send notification to holder
)
```

**Use sparingly**: Only for genuinely abandoned locks.

---

### Discovery

#### `whois`

Get details about an agent.

```python
whois(
    project_key="/data/projects/my-project",
    agent_name="CoralReef",
    include_recent_commits=True
)
# Returns: { id, name, program, model, task_description, recent_commits, ... }
```

#### `search_messages`

Full-text search across messages.

```python
search_messages(
    project_key="/data/projects/my-project",
    query="authentication blocked",   # FTS5 query
    limit=20
)
# Returns: [{ id, subject, from, created_ts, ... }]
```

**Query syntax**:

- Phrase: `"build plan"`
- Prefix: `auth*`
- Boolean: `auth AND blocked`

#### `summarize_thread`

Get AI-generated summary of a thread.

```python
summarize_thread(
    project_key="/data/projects/my-project",
    thread_id="FEATURE-001",
    include_examples=True
)
# Returns: { thread_id, summary: { participants, key_points, action_items } }
```

---

### Macros (Convenience Wrappers)

#### `macro_start_session`

One-call session bootstrap.

```python
macro_start_session(
    human_key="/data/projects/my-project",
    program="claude-code",
    model="opus-4.5",
    task_description="Feature work",
    file_reservation_paths=["src/**"],
    file_reservation_ttl_seconds=3600,
    inbox_limit=10
)
# Returns: { project, agent, file_reservations, inbox }
```

#### `macro_prepare_thread`

Prepare to join an existing thread.

```python
macro_prepare_thread(
    project_key="/data/projects/my-project",
    thread_id="FEATURE-001",
    program="claude-code",
    model="opus-4.5"
)
# Returns: { agent, thread_summary, inbox }
```

---

## Best Practices

### Naming Conventions

| Entity      | Convention              | Example                    |
| ----------- | ----------------------- | -------------------------- |
| Thread ID   | FEATURE-NNN or TASK-NNN | `AUTH-001`, `REFACTOR-042` |
| Project key | Absolute path           | `/data/projects/my-app`    |
| Agent name  | Auto-generated          | `BlueLake`, `CoralReef`    |

### Message Etiquette

- **Subject**: Keep under 80 characters
- **Body**: Use Markdown, include code blocks
- **Threading**: Always use thread_id for related messages
- **Targeting**: Only message agents who need to act

### Reservation Strategy

| Duration | Use Case                           |
| -------- | ---------------------------------- |
| 1 hour   | Quick fixes, small features        |
| 2 hours  | Medium features, refactors         |
| 4 hours  | Large features, complex migrations |
| 8+ hours | Consider breaking into phases      |

### Error Handling

| Error                  | Cause                    | Solution               |
| ---------------------- | ------------------------ | ---------------------- |
| "Agent not registered" | Missing registration     | Call `register_agent`  |
| "Reservation conflict" | Another agent holds lock | Message holder or wait |
| "Project not found"    | Wrong path               | Verify absolute path   |
| "Thread not found"     | Invalid thread_id        | Check thread exists    |

---

## Resources

For more details, see the MCP Agent Mail server documentation or use:

```bash
# CLI health check
mcp-agent-mail health_check

# List agents in a project
resource://agents/{project-slug}

# Read specific inbox
resource://inbox/{AgentName}?project=/path&limit=20
```
