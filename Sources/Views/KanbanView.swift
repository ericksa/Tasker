import SwiftUI
import SwiftData

struct KanbanView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Task.position) private var allTasks: [Task]
    
    @State private var showingTaskCreation = false
    @State private var selectedTask: Task?
    @State private var selectedColumn: TaskStatus = .backlog
    @State private var searchText = ""
    @State private var showingFilterSheet = false
    @State private var selectedPriorityFilter: Priority?
    @State private var selectedAssigneeFilter: String?
    
    // Drag and drop state
    @State private var draggingTask: Task?
    @State private var dropTargetColumn: TaskStatus?
    
    var filteredTasks: [Task] {
        allTasks.filter { task in
            let matchesSearch = searchText.isEmpty || 
                task.title.localizedCaseInsensitiveContains(searchText) ||
                task.taskDescription.localizedCaseInsensitiveContains(searchText)
            
            let matchesPriority = selectedPriorityFilter.map { task.priority == $0 } ?? true
            let matchesAssignee = selectedAssigneeFilter.map { task.assignee == $0 } ?? true
            
            return matchesSearch && matchesPriority && matchesAssignee
        }
    }
    
    private let columns: [TaskStatus] = [.backlog, .todo, .inProgress, .done, .archived]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search and filter bar
                HStack(spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Search tasks...", text: $searchText)
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    
                    Button(action: { showingFilterSheet = true }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.title3)
                            .foregroundColor(selectedPriorityFilter != nil || selectedAssigneeFilter != nil ? .blue : .primary)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                // Kanban board
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(columns) { status in
                            KanbanColumn(
                                status: status,
                                tasks: tasks(for: status),
                                draggingTask: $draggingTask,
                                dropTargetColumn: $dropTargetColumn,
                                onTaskDrop: { task, newStatus in
                                    moveTask(task, to: newStatus)
                                },
                                onEdit: { task in
                                    selectedTask = task
                                    selectedColumn = status
                                    showingTaskCreation = true
                                },
                                onDelete: { task in
                                    deleteTask(task)
                                },
                                onComplete: { task in
                                    toggleTaskCompletion(task)
                                },
                                onAddTask: {
                                    selectedTask = nil
                                    selectedColumn = status
                                    showingTaskCreation = true
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Tasker")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        selectedTask = nil
                        selectedColumn = .backlog
                        showingTaskCreation = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button(role: .destructive) {
                            archiveCompletedTasks()
                        } label: {
                            Label("Archive Completed", systemImage: "archivebox")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingTaskCreation) {
                TaskCreationModal(
                    editingTask: selectedTask,
                    defaultStatus: selectedColumn
                )
            }
            .sheet(isPresented: $showingFilterSheet) {
                FilterSheet(
                    selectedPriority: $selectedPriorityFilter,
                    selectedAssignee: $selectedAssigneeFilter,
                    allAssignees: Array(Set(allTasks.compactMap { $0.assignee })).sorted()
                )
            }
        }
        .onAppear {
            ensurePositions()
        }
    }
    
    private func tasks(for status: TaskStatus) -> [Task] {
        filteredTasks.filter { $0.status == status }.sorted { $0.position < $1.position }
    }
    
    private func moveTask(_ task: Task, to newStatus: TaskStatus) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            task.move(to: newStatus)
            
            // Update positions for tasks in the new column
            let tasksInColumn = tasks(for: newStatus)
            for (index, t) in tasksInColumn.enumerated() {
                t.position = index
            }
            
            try? modelContext.save()
        }
    }
    
    private func deleteTask(_ task: Task) {
        withAnimation {
            modelContext.delete(task)
            try? modelContext.save()
        }
    }
    
    private func toggleTaskCompletion(_ task: Task) {
        withAnimation {
            if task.isCompleted {
                task.markIncomplete()
            } else {
                task.markComplete()
            }
            try? modelContext.save()
        }
    }
    
    private func archiveCompletedTasks() {
        withAnimation {
            for task in allTasks where task.isCompleted && task.status != .archived {
                task.move(to: .archived)
            }
            try? modelContext.save()
        }
    }
    
    private func ensurePositions() {
        for status in columns {
            let statusTasks = allTasks.filter { $0.status == status }.sorted { $0.createdAt < $1.createdAt }
            for (index, task) in statusTasks.enumerated() {
                if task.position != index {
                    task.position = index
                }
            }
        }
        try? modelContext.save()
    }
}

struct KanbanColumn: View {
    let status: TaskStatus
    let tasks: [Task]
    @Binding var draggingTask: Task?
    @Binding var dropTargetColumn: TaskStatus?
    let onTaskDrop: (Task, TaskStatus) -> Void
    let onEdit: (Task) -> Void
    let onDelete: (Task) -> Void
    let onComplete: (Task) -> Void
    let onAddTask: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Column header
            HStack {
                Image(systemName: status.icon)
                    .foregroundColor(statusColor)
                
                Text(status.rawValue)
                    .font(.headline)
                
                Spacer()
                
                Text("\(tasks.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(columnHeaderColor)
            .cornerRadius(12, corners: [.topLeft, .topRight])
            
            // Task list
            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(tasks) { task in
                        TaskCardView(
                            task: task,
                            onEdit: { onEdit(task) },
                            onDelete: { onDelete(task) },
                            onComplete: { onComplete(task) }
                        )
                        .opacity(draggingTask?.id == task.id ? 0.5 : 1)
                        .onDrag {
                            draggingTask = task
                            return NSItemProvider(object: task.id.uuidString as NSString)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .frame(minHeight: 100)
            }
            .frame(width: 300)
            .background(Color(.systemBackground))
            .cornerRadius(12, corners: [.bottomLeft, .bottomRight])
            .onDrop(of: ["public.text"], isTargeted: $isHovering) { providers in
                guard let draggingTask = draggingTask else { return false }
                onTaskDrop(draggingTask, status)
                self.draggingTask = nil
                return true
            }
            
            // Add task button
            Button(action: onAddTask) {
                HStack {
                    Image(systemName: "plus")
                    Text("Add Task")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .frame(width: 316)
        .background(columnBackgroundColor.opacity(isHovering ? 1.0 : 0.8))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovering ? statusColor : Color.clear, lineWidth: 2)
        )
    }
    
    private var statusColor: Color {
        switch status {
        case .backlog: return .gray
        case .todo: return .blue
        case .inProgress: return .orange
        case .done: return .green
        case .archived: return .secondary
        }
    }
    
    private var columnHeaderColor: Color {
        switch status {
        case .backlog: return Color.gray.opacity(0.15)
        case .todo: return Color.blue.opacity(0.15)
        case .inProgress: return Color.orange.opacity(0.15)
        case .done: return Color.green.opacity(0.15)
        case .archived: return Color.secondary.opacity(0.15)
        }
    }
    
    private var columnBackgroundColor: Color {
        switch status {
        case .backlog: return Color.gray.opacity(0.1)
        case .todo: return Color.blue.opacity(0.1)
        case .inProgress: return Color.orange.opacity(0.1)
        case .done: return Color.green.opacity(0.1)
        case .archived: return Color.secondary.opacity(0.1)
        }
    }
}

struct FilterSheet: View {
    @Binding var selectedPriority: Priority?
    @Binding var selectedAssignee: String?
    let allAssignees: [String]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Priority")) {
                    ForEach(Priority.allCases) { priority in
                        Button(action: {
                            selectedPriority = selectedPriority == priority ? nil : priority
                        }) {
                            HStack {
                                Image(systemName: priority.icon)
                                    .foregroundColor(priorityColor(priority))
                                Text(priority.rawValue)
                                
                                Spacer()
                                
                                if selectedPriority == priority {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                    
                    if selectedPriority != nil {
                        Button("Clear Priority Filter") {
                            selectedPriority = nil
                        }
                        .foregroundColor(.red)
                    }
                }
                
                if !allAssignees.isEmpty {
                    Section(header: Text("Assignee")) {
                        ForEach(allAssignees, id: \.self) { assignee in
                            Button(action: {
                                selectedAssignee = selectedAssignee == assignee ? nil : assignee
                            }) {
                                HStack {
                                    Image(systemName: "person.circle")
                                    Text(assignee)
                                    
                                    Spacer()
                                    
                                    if selectedAssignee == assignee {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            .foregroundColor(.primary)
                        }
                        
                        if selectedAssignee != nil {
                            Button("Clear Assignee Filter") {
                                selectedAssignee = nil
                            }
                            .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("Filter Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func priorityColor(_ priority: Priority) -> Color {
        switch priority {
        case .low: return .gray
        case .medium: return .yellow
        case .high: return .orange
        case .urgent: return .red
        }
    }
}

// MARK: - Rounded Corner Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
