# Tasker

SwiftUI starter app for task management workflows.

## Tech Stack
- Swift
- SwiftUI
- Xcode project (`Tasker.xcodeproj`)
- Shell helper scripts in `Scripts/`

## Setup
1. `cd Tasker`
2. Open `Tasker.xcodeproj` in Xcode.
3. Build and run app target.

## Usage
Current app scaffold renders `ContentView` and is ready for feature development.

## Webhook Integrations
Suggested outbound events for future sync engine:
- `tasker.task.created`
- `tasker.task.completed`
- `tasker.project.archived`

Example payload:
```json
{
  "event": "tasker.task.completed",
  "task_id": "abc123",
  "completed_at": "2026-02-22T18:00:00Z"
}
```
