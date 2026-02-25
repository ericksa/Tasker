import SwiftUI
import SwiftData

@main
struct TaskerApp: App {
    var body: some Scene {
        WindowGroup {
            KanbanView()
        }
        .modelContainer(for: Task.self)
    }
}
