import SwiftUI
import SwiftData

struct TaskCardView: View {
    @Bindable var task: Task
    @Environment(\.modelContext) private var modelContext
    
    var onEdit: () -> Void
    var onDelete: () -> Void
    var onComplete: () -> Void
    
    @State private var showingDeleteConfirmation = false
    @State private var offset: CGFloat = 0
    @State private var isDragging = false
    
    var body: some View {
        ZStack {
            // Background layer for swipe actions
            HStack {
                Spacer()
                HStack(spacing: 0) {
                    Button(action: { onComplete() }) {
                        Image(systemName: task.isCompleted ? "arrow.uturn.backward" : "checkmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 80, height: 80)
                            .background(task.isCompleted ? Color.orange : Color.green)
                    }
                    
                    Button(action: { onEdit() }) {
                        Image(systemName: "pencil")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 80, height: 80)
                            .background(Color.blue)
                    }
                    
                    Button(action: { showingDeleteConfirmation = true }) {
                        Image(systemName: "trash")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 80, height: 80)
                            .background(Color.red)
                    }
                }
            }
            
            // Front card layer
            cardContent
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                )
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            isDragging = true
                            if value.translation.width < 0 {
                                offset = max(value.translation.width, -240)
                            } else if task.status != .done && value.translation.width > 0 {
                                offset = min(value.translation.width, 80)
                            }
                        }
                        .onEnded { value in
                            isDragging = false
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if offset < -200 {
                                    showingDeleteConfirmation = true
                                    offset = 0
                                } else if offset > 60 && !task.isCompleted {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        onComplete()
                                    }
                                    offset = 0
                                } else {
                                    offset = 0
                                }
                            }
                        }
                )
        }
        .confirmationDialog("Delete Task?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
    }
    
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(task.displayTitle)
                    .font(.headline)
                    .lineLimit(2)
                    .strikethrough(task.isCompleted)
                
                Spacer()
                
                PriorityBadge(priority: task.priority)
            }
            
            if !task.taskDescription.isEmpty {
                Text(task.taskDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            if !task.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(task.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                    }
                }
            }
            
            HStack {
                if let assignee = task.assignee {
                    HStack(spacing: 4) {
                        Image(systemName: "person.circle")
                            .font(.caption)
                        Text(assignee)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let dueDate = task.formattedDueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption)
                        Text(dueDate)
                            .font(.caption)
                    }
                    .foregroundColor(task.isOverdue ? .red : .secondary)
                }
            }
        }
        .padding(12)
        .opacity(isDragging ? 0.9 : 1)
    }
}

struct PriorityBadge: View {
    let priority: Priority
    
    var body: some View {
        Image(systemName: priority.icon)
            .foregroundColor(colorForPriority)
            .frame(width: 24, height: 24)
            .background(colorForPriority.opacity(0.1))
            .cornerRadius(4)
    }
    
    private var colorForPriority: Color {
        switch priority {
        case .low: return .gray
        case .medium: return .yellow
        case .high: return .orange
        case .urgent: return .red
        }
    }
}
