import SwiftUI

/// Example SwiftUI View demonstrating MyMCP integration
struct TaskerSyncExampleView: View {
    
    @StateObject private var viewModel = TaskSyncViewModel()
    @State private var newTaskTitle = ""
    @State private var showError = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Connection Status
                connectionStatusBar
                
                // Task List
                List {
                    Section(header: Text("Tasks")) {
                        ForEach(viewModel.tasks) { task in
                            TaskRowView(task: task) { action in
                                handleTaskAction(task, action: action)
                            }
                        }
                    }
                }
                
                // Add Task Section
                VStack(spacing: 12) {
                    TextField("New task title", text: $newTaskTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button(action: createTask) {
                        Label("Add Task", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newTaskTitle.isEmpty || !viewModel.isConnected)
                    
                    HStack(spacing: 20) {
                        Button(action: { viewModel.performInitialSync() }) {
                            Label("Full Sync", systemImage: "arrow.clockwise")
                        }
                        .disabled(!viewModel.isConnected || viewModel.isSyncing)
                        
                        Button(action: { viewModel.performDeltaSync() }) {
                            Label("Delta Sync", systemImage: "arrow.clockwise.circle")
                        }
                        .disabled(!viewModel.isConnected || viewModel.isSyncing)
                    }
                    .font(.caption)
                }
                .padding()
                .background(Color(.systemGray6))
            }
            .navigationTitle("Tasker + MyMCP")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { viewModel.startAutoSync() }) {
                        Label("Auto Sync", systemImage: viewModel.lastSyncTime == nil ? "play.circle" : "checkmark.circle.fill")
                    }
                    .disabled(!viewModel.isConnected)
                }
            }
            .onAppear {
                // Configure with MyMCP server details
                // This would normally come from user settings or secure storage
                viewModel.configure(
                    baseURL: "http://localhost:8080",
                    token: "dev-token-change-in-prod"
                )
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
            .onChange(of: viewModel.errorMessage) { _ in
                showError = viewModel.errorMessage != nil
            }
            .onChange(of: showError) { isShown in
                if !isShown {
                    viewModel.errorMessage = nil
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var connectionStatusBar: some View {
        HStack {
            Circle()
                .fill(viewModel.isConnected ? .green : .red)
                .frame(width: 10, height: 10)
            
            Text(viewModel.isConnected ? "Connected to MyMCP" : "Not Connected")
                .font(.caption)
            
            Spacer()
            
            if let lastSync = viewModel.lastSyncTime {
                Text("Last sync: \(lastSync, style: .relative) ago")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if viewModel.isSyncing {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding()
        .background(viewModel.isConnected ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
    }
    
    // MARK: - Actions
    
    private func createTask() {
        guard !newTaskTitle.isEmpty else { return }
        viewModel.createTask(title: newTaskTitle)
        newTaskTitle = ""
    }
    
    private func handleTaskAction(_ task: MyMCPTask, action: TaskRowAction) {
        switch action {
        case .complete:
            viewModel.completeTask(id: task.id)
        case .delete:
            viewModel.deleteTask(id: task.id)
        }
    }
}

// MARK: - Supporting Views

enum TaskRowAction {
    case complete
    case delete
}

struct TaskRowView: View {
    let task: MyMCPTask
    let onAction: (TaskRowAction) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 32, height: 32)
                
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                    .font(.system(size: 14, weight: .semibold))
            }
            
            // Task info
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.body)
                    .strikethrough(task.status == "completed")
                
                HStack(spacing: 8) {
                    if let dueDate = task.dueDate {
                        Label(dueDate.formatted(.dateTime.month(.short).day()), systemImage: "calendar")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("• \(task.status.capitalized)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if !task.tags.isEmpty {
                        Text("• \(task.tags.joined(separator: ", "))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Actions
            if task.status != "completed" {
                Button(action: { onAction(.complete) }) {
                    Image(systemName: "checkmark.circle")
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
            }
            
            Button(action: { onAction(.delete) }) {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .foregroundColor(.red)
        }
        .padding(.vertical, 4)
    }
    
    private var statusIcon: String {
        switch task.status {
        case "completed": return "checkmark.circle.fill"
        case "in_progress": return "play.fill"
        default: return "circle"
        }
    }
    
    private var statusColor: Color {
        switch task.status {
        case "completed": return .green
        case "in_progress": return .blue
        case "open": return .gray
        default: return .orange
        }
    }
}

// MARK: - Preview

#Preview {
    TaskerSyncExampleView()
}
