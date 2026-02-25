import SwiftUI
import SwiftData

struct TaskCreationModal: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var description = ""
    @State private var selectedStatus: TaskStatus = .backlog
    @State private var selectedPriority: Priority = .medium
    @State private var dueDate: Date?
    @State private var hasDueDate = false
    @State private var tags: [String] = []
    @State private var newTag = ""
    @State private var assignee = ""
    
    @State private var showingValidationError = false
    @State private var validationMessage = ""
    
    var editingTask: Task?
    var defaultStatus: TaskStatus = .backlog
    
    init(editingTask: Task? = nil, defaultStatus: TaskStatus = .backlog) {
        self.editingTask = editingTask
        self.defaultStatus = defaultStatus
        
        if let task = editingTask {
            _title = State(initialValue: task.title)
            _description = State(initialValue: task.taskDescription)
            _selectedStatus = State(initialValue: task.status)
            _selectedPriority = State(initialValue: task.priority)
            _tags = State(initialValue: task.tags)
            _assignee = State(initialValue: task.assignee ?? "")
            
            if let due = task.dueDate {
                _dueDate = State(initialValue: due)
                _hasDueDate = State(initialValue: true)
            }
        } else {
            _selectedStatus = State(initialValue: defaultStatus)
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Task Details")) {
                    TextField("Title", text: $title)
                        .font(.headline)
                    
                    ZStack(alignment: .topLeading) {
                        if description.isEmpty {
                            Text("Description (optional)")
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        
                        TextEditor(text: $description)
                            .frame(minHeight: 80)
                    }
                }
                
                Section(header: Text("Status")) {
                    Picker("Status", selection: $selectedStatus) {
                        ForEach(TaskStatus.allCases) { status in
                            Label(status.rawValue, systemImage: status.icon)
                                .tag(status)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                
                Section(header: Text("Priority")) {
                    Picker("Priority", selection: $selectedPriority) {
                        ForEach(Priority.allCases) { priority in
                            Label(priority.rawValue, systemImage: priority.icon)
                                .tag(priority)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                
                Section(header: Text("Due Date")) {
                    Toggle("Set Due Date", isOn: $hasDueDate)
                    
                    if hasDueDate {
                        DatePicker(
                            "Due Date",
                            selection: Binding(
                                get: { dueDate ?? Date() },
                                set: { dueDate = $0 }
                            ),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }
                
                Section(header: Text("Assignee")) {
                    TextField("Assignee (optional)", text: $assignee)
                }
                
                Section(header: Text("Tags")) {
                    HStack {
                        TextField("Add tag", text: $newTag)
                        
                        Button(action: addTag) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                        }
                        .disabled(newTag.isEmpty || tags.contains(newTag))
                    }
                    
                    if !tags.isEmpty {
                        FlowLayout(spacing: 8) {
                            ForEach(tags, id: \.self) { tag in
                                TagChip(tag: tag) {
                                    removeTag(tag)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(editingTask == nil ? "New Task" : "Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTask()
                    }
                    .disabled(!isValid)
                }
            }
            .alert("Validation Error", isPresented: $showingValidationError) {
                Button("OK") {}
            } message: {
                Text(validationMessage)
            }
        }
    }
    
    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    private func validate() -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        
        if trimmedTitle.isEmpty {
            validationMessage = "Please enter a task title."
            return false
        }
        
        if trimmedTitle.count < 2 {
            validationMessage = "Task title must be at least 2 characters."
            return false
        }
        
        return true
    }
    
    private func saveTask() {
        guard validate() else {
            showingValidationError = true
            return
        }
        
        if let existingTask = editingTask {
            // Update existing task
            existingTask.title = title.trimmed
            existingTask.taskDescription = description.trimmed
            existingTask.status = selectedStatus
            existingTask.priority = selectedPriority
            existingTask.dueDate = hasDueDate ? dueDate : nil
            existingTask.assignee = assignee.isEmpty ? nil : assignee.trimmed
            existingTask.tags = tags
            existingTask.updatedAt = Date()
            
            if selectedStatus == .done && !existingTask.isCompleted {
                existingTask.markComplete()
            } else if selectedStatus != .done && existingTask.isCompleted {
                existingTask.markIncomplete()
            }
        } else {
            // Create new task
            let task = Task(
                title: title.trimmed,
                description: description.trimmed,
                status: selectedStatus,
                priority: selectedPriority,
                dueDate: hasDueDate ? dueDate : nil,
                tags: tags,
                assignee: assignee.isEmpty ? nil : assignee.trimmed
            )
            
            modelContext.insert(task)
        }
        
        dismiss()
    }
    
    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { return }
        
        tags.append(trimmed)
        newTag = ""
    }
    
    private func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }
}

// MARK: - Helper Views

struct TagChip: View {
    let tag: String
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.caption)
            
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .foregroundColor(.blue)
        .cornerRadius(8)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: result.positions[index].x + bounds.minX, y: result.positions[index].y + bounds.minY), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
                
                self.size.width = max(self.size.width, x)
                self.size.height = y + lineHeight
            }
        }
    }
}

// MARK: - String Extensions

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
