# MyMCP Integration Architecture for Tasker

This document defines the bidirectional sync integration between Tasker (SwiftUI iOS app) and MyMCP (Go-based MCP gateway).

## Overview

The integration enables Tasker to sync tasks with MyMCP's PostgreSQL task database. MyMCP exposes RESTful API endpoints for CRUD operations and dispatches webhooks to Tasker when tasks change.

```
┌─────────────┐      HTTP API      ┌──────────────┐
│   Tasker    │ ◄────────────────► │    MyMCP     │
│  (SwiftUI)  │                    │   Gateway    │
└─────────────┘                    └──────────────┘
       ▲                                   │
       │         Webhooks                  │
       └───────────────────────────────────┘
```

## API Endpoints

MyMCP exposes the following REST endpoints under `/api/v1/tasks`:

### 1. List Tasks
- **GET** `/api/v1/tasks`
- **Query Params:**
  - `status` - Filter by status (open, completed, etc.)
  - `client` - Filter by client name
  - `project` - Filter by project
  - `assigned_to` - Filter by assigned agent
  - `limit` - Max results (default: 50, max: 500)
  - `offset` - Pagination offset
  - `order_by` - Sort column (created_at, updated_at, due_date, priority, title)
  - `order_desc` - Sort descending (true/false)
- **Response:**
```json
{
  "tasks": [ { "id": "uuid", "title": "...", ... } ],
  "count": 50,
  "total": 123,
  "offset": 0,
  "limit": 50
}
```

### 2. Create Task
- **POST** `/api/v1/tasks`
- **Body:**
```json
{
  "title": "Task title",
  "description": "Optional description",
  "client": "Client name",
  "project": "Project name",
  "due_date": "2026-02-25T23:59:59Z",
  "status": "open",
  "priority": 3,
  "urgency": "medium",
  "tags": ["tag1", "tag2"]
}
```
- **Response:** Full task object with `id`, `created_at`, `updated_at`

### 3. Update Task
- **PUT** `/api/v1/tasks/{id}`
- **Body:** Any updatable fields same as Create
- **Response:** Updated task object

### 4. Delete Task
- **DELETE** `/api/v1/tasks/{id}`
- **Response:**
```json
{
  "success": true,
  "deleted_id": "uuid",
  "rows_affected": 1
}
```

### 5. Sync Tasks (Delta Sync)
- **GET** `/api/v1/tasks/sync?since=2026-02-24T12:00:00Z`
- **Query Params:**
  - `since` - ISO8601 timestamp for delta sync
  - `status` - Optional status filter
  - `limit` - Max results
- **Response:**
```json
{
  "tasks": [ { "id": "...", "updated_at": "...", ... } ],
  "deleted_ids": ["uuid1", "uuid2"],
  "sync_timestamp": "2026-02-24T21:00:00Z"
}
```

### 6. Get Single Task
- **GET** `/api/v1/tasks/{id}`
- **Response:** Task object or 404

## Webhook Events

Tasker must expose a webhook endpoint (`POST /webhook`) to receive real-time updates from MyMCP.

### Event Types

#### tasker.task.created
Triggered when a task is created in MyMCP.
```json
{
  "event": "tasker.task.created",
  "timestamp": "2026-02-24T21:00:00Z",
  "data": {
    "id": "uuid",
    "title": "Task title",
    "description": "...",
    "client": "...",
    "project": "...",
    "due_date": "2026-02-25T23:59:59Z",
    "status": "open",
    "priority": 3,
    "urgency": "medium",
    "assigned_agent": "...",
    "tags": [...],
    "created_at": "2026-02-24T21:00:00Z",
    "updated_at": "2026-02-24T21:00:00Z"
  }
}
```

#### tasker.task.updated
Triggered when any task field is modified.
```json
{
  "event": "tasker.task.updated",
  "timestamp": "2026-02-24T21:05:00Z",
  "data": {
    "id": "uuid",
    "title": "Updated title",
    "status": "in_progress",
    "updated_at": "2026-02-24T21:05:00Z",
    "changes": ["title", "status"]
  }
}
```

#### tasker.task.completed
Triggered when task status changes to "completed".
```json
{
  "event": "tasker.task.completed",
  "timestamp": "2026-02-24T21:10:00Z",
  "data": {
    "id": "uuid",
    "title": "...",
    "completed_at": "2026-02-24T21:10:00Z",
    "actual_hours": 2.5
  }
}
```

#### tasker.task.deleted
Triggered when a task is permanently deleted.
```json
{
  "event": "tasker.task.deleted",
  "timestamp": "2026-02-24T21:15:00Z",
  "data": {
    "id": "uuid",
    "deleted_at": "2026-02-24T21:15:00Z"
  }
}
```

### Webhook Registration in MyMCP

Tasker must register its webhook on startup:
```bash
curl -X POST http://mymcp.local:8080/api/v1/webhooks \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Tasker Sync",
    "event": "tasker.task.created",
    "url": "https://tasker.app/webhook",
    "secret": "webhook-secret-key"
  }'
```

Register for all events:
- `tasker.task.created`
- `tasker.task.updated`
- `tasker.task.completed`
- `tasker.task.deleted`

## Authentication

All API calls require Bearer token authentication:
```
Authorization: Bearer ${token}
```

The token is configured in MyMCP's `config.yaml`:
```yaml
mcp:
  auth:
    token: "dev-token-change-in-prod"
```

## Swift Network Layer

See `Sources/Networking/MyMCPClient.swift` for the implementation.

## Sync Strategy

### Initial Sync
1. Tasker calls `GET /api/v1/tasks?limit=500` on first launch
2. Store `sync_timestamp` from latest `updated_at`

### Delta Sync
1. Periodically (every 30s or on app foreground) call `GET /api/v1/tasks/sync?since={last_sync}`
2. Apply updates, handle deletions via `deleted_ids`
3. Update `sync_timestamp`

### Real-time Sync
- Register webhook on app startup
- Re-register on each cold start (webhooks are ephemeral)
- Handle incoming webhooks immediately
- Use webhook receipt as trigger for delta sync on conflict

## Conflict Resolution

- Last-write-wins based on `updated_at` timestamp
- Webhook events take precedence over polling results
- If server task is newer, overwrite local
- If local task is newer, push to server

## Error Handling

### Network Errors
- Exponential backoff for retries (1s, 2s, 4s, 8s, max 60s)
- Queue offline changes for sync when back online

### 409 Conflict
- Fetch remote task and compare `updated_at`
- Merge or prompt user if manual intervention needed

### Auth Errors (401/403)
- Refresh token or prompt user to re-authenticate

## Workers Requiring Updates

To support the Tasker integration, the following MyMCP workers need updates:

### 1. `internal/workers/task_worker.go`
**Changes Required:**
- Add new HTTP handler methods for REST API endpoints (currently only has tool-based execution)
- Add `GetTaskByID(id string)` method for single task retrieval
- Add `SyncTasks(since time.Time)` method for delta sync with deleted task tracking
- Add soft-delete support (add `deleted_at` column) to track deletions for sync
- Add `RegisterChangeCallback()` to trigger webhooks on task changes

### 2. `cmd/gateway/main.go` (Gateway Router)
**Changes Required:**
- Add new router handlers:
  - `router.HandleFunc("/api/v1/tasks", taskListHandler).Methods("GET")`
  - `router.HandleFunc("/api/v1/tasks", taskCreateHandler).Methods("POST")`
  - `router.HandleFunc("/api/v1/tasks/{id}", taskGetHandler).Methods("GET")`
  - `router.HandleFunc("/api/v1/tasks/{id}", taskUpdateHandler).Methods("PUT")`
  - `router.HandleFunc("/api/v1/tasks/{id}", taskDeleteHandler).Methods("DELETE")`
  - `router.HandleFunc("/api/v1/tasks/sync", taskSyncHandler).Methods("GET")`

### 3. `cmd/gateway/webhooks.go`
**Changes Required:**
- Add webhook dispatch calls in task lifecycle:
  - `dispatchWebhook("tasker.task.created", task)` after task creation
  - `dispatchWebhook("tasker.task.updated", task)` after task update
  - `dispatchWebhook("tasker.task.completed", task)` when status becomes "completed"
  - `dispatchWebhook("tasker.task.deleted", deletionPayload)` after task deletion
- Add webhook signature validation helper (HMAC with secret)

### 4. `internal/workers/reminders_sync.go`
**Changes Required:**
- Extend sync to also trigger appropriate webhooks when Apple Reminders sync creates/updates tasks
- Ensure bidirectional sync doesn't cause webhook loops (add source attribution to prevent echo)

### 5. Database Schema (PostgreSQL)
**Migration Required:**
```sql
-- Add deleted_at for soft delete tracking
ALTER TABLE tasks ADD COLUMN deleted_at TIMESTAMP;

-- Add source attribution to prevent webhook loops
ALTER TABLE tasks ADD COLUMN change_source VARCHAR(50);

-- Add index for efficient sync queries
CREATE INDEX idx_tasks_updated_at ON tasks(updated_at);
CREATE INDEX idx_tasks_deleted_at ON tasks(deleted_at) WHERE deleted_at IS NOT NULL;
```

## Configuration

Tasker should expose settings for:
- MyMCP server URL
- Auth token
- Sync interval (default: 30s)
- Webhook URL (optional custom endpoint)

## Testing

Test the integration with:
```bash
# List tasks
curl -H "Authorization: Bearer dev-token" http://localhost:8080/api/v1/tasks

# Create task
curl -X POST -H "Authorization: Bearer dev-token" \
  -H "Content-Type: application/json" \
  -d '{"title":"Test from Tasker","status":"open"}' \
  http://localhost:8080/api/v1/tasks

# Sync endpoint
curl -H "Authorization: Bearer dev-token" \
  "http://localhost:8080/api/v1/tasks/sync?since=2026-02-24T00:00:00Z"
```
