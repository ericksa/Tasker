import Foundation
import SwiftData

enum TaskStatus: String, Codable, CaseIterable, Identifiable {
    case backlog = "Backlog"
    case todo = "To Do"
    case inProgress = "In Progress"
    case done = "Done"
    case archived = "Archived"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .backlog: return "tray"
        case .todo: return "circle"
        case .inProgress: return "arrow.2.circlepath"
        case .done: return "checkmark.circle.fill"
        case .archived: return "archivebox"
        }
    }
    
    var color: String {
        switch self {
        case .backlog: return "gray"
        case .todo: return "blue"
        case .inProgress: return "orange"
        case .done: return "green"
        case .archived: return "secondary"
        }
    }
}

enum Priority: String, Codable, CaseIterable, Identifiable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case urgent = "Urgent"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .low: return "arrow.down"
        case .medium: return "minus"
        case .high: return "arrow.up"
        case .urgent: return "exclamationmark.triangle"
        }
    }
    
    var color: String {
        switch self {
        case .low: return "gray"
        case .medium: return "yellow"
        case .high: return "orange"
        case .urgent: return "red"
        }
    }
    
    var value: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .urgent: return 4
        }
    }
}

@Model
class Task {
    @Attribute(.unique) var id: UUID
    var title: String
    var taskDescription: String
    var status: TaskStatus
    var priority: Priority
    var dueDate: Date?
    var createdAt: Date
    var updatedAt: Date
    var tags: [String]
    var assignee: String?
    var isCompleted: Bool
    var completedAt: Date?
    var position: Int
    
    init(
        id: UUID = UUID(),
        title: String = "",
        description: String = "",
        status: TaskStatus = .backlog,
        priority: Priority = .medium,
        dueDate: Date? = nil,
        tags: [String] = [],
        assignee: String? = nil,
        position: Int = 0
    ) {
        self.id = id
        self.title = title
        self.taskDescription = description
        self.status = status
        self.priority = priority
        self.dueDate = dueDate
        self.createdAt = Date()
        self.updatedAt = Date()
        self.tags = tags
        self.assignee = assignee
        self.isCompleted = false
        self.completedAt = nil
        self.position = position
    }
    
    var displayTitle: String {
        title.isEmpty ? "Untitled Task" : title
    }
    
    var isOverdue: Bool {
        guard let due = dueDate else { return false }
        return due < Date() && !isCompleted
    }
    
    var formattedDueDate: String? {
        guard let due = dueDate else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: due, relativeTo: Date())
    }
    
    func markComplete() {
        isCompleted = true
        completedAt = Date()
        status = .done
        updatedAt = Date()
    }
    
    func markIncomplete() {
        isCompleted = false
        completedAt = nil
        updatedAt = Date()
    }
    
    func move(to newStatus: TaskStatus) {
        status = newStatus
        if newStatus == .done {
            markComplete()
        } else if newStatus != .done && isCompleted {
            markIncomplete()
        }
        updatedAt = Date()
    }
}

// MARK: - SwiftData Predicates

extension Task {
    static func predicate(for status: TaskStatus) -> Predicate<Task> {
        return #Predicate { task in
            task.status == status
        }
    }
    
    static func searchPredicate(query: String) -> Predicate<Task> {
        return #Predicate { task in
            query.isEmpty || task.title.localizedStandardContains(query)
        }
    }
}
