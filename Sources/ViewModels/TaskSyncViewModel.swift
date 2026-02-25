import Foundation
import SwiftUI

/// ViewModel for managing task sync with MyMCP
@MainActor
class TaskSyncViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var tasks: [MyMCPTask] = []
    @Published var isSyncing = false
    @Published var lastSyncTime: Date?
    @Published var errorMessage: String?
    @Published var isConnected = false
    
    // MARK: - Private Properties
    
    private var client: MyMCPClient?
    private var syncManager: MyMCPSyncManager?
    private var webhookProcessor: MyMCPWebhookProcessor?
    
    // MARK: - Configuration
    
    /// Configure the MyMCP connection
    func configure(baseURL: String, token: String) {
        guard let client = MyMCPClient(baseURLString: baseURL, token: token) else {
            self.errorMessage = "Invalid MyMCP configuration"
            return
        }
        
        self.client = client
        self.syncManager = MyMCPSyncManager(client: client)
        self.webhookProcessor = MyMCPWebhookProcessor()
        self.webhookProcessor?.handler = self
        
        // Set up callbacks
        Task {
            await syncManager?.setCallbacks(
                onTasksReceived: { [weak self] tasks, deletedIds in
                    self?.handleSync(tasks: tasks, deletedIds: deletedIds)
                },
                onError: { [weak self] error in
                    self?.handleError(error)
                }
            )
        }
        
        self.isConnected = true
    }
    
    // MARK: - Sync Operations
    
    /// Perform initial full sync
    func performInitialSync() {
        guard let syncManager = syncManager else {
            errorMessage = "Not configured"
            return
        }
        
        isSyncing = true
        errorMessage = nil
        
        Task {
            await syncManager.performInitialSync()
            isSyncing = false
        }
    }
    
    /// Start automatic periodic sync
    func startAutoSync() {
        guard let syncManager = syncManager else { return }
        
        Task {
            await syncManager.startPeriodicSync()
        }
    }
    
    /// Stop automatic sync
    func stopAutoSync() {
        guard let syncManager = syncManager else { return }
        
        Task {
            await syncManager.stopPeriodicSync()
        }
    }
    
    /// Manual delta sync
    func performDeltaSync() {
        guard let syncManager = syncManager else {
            errorMessage = "Not configured"
            return
        }
        
        isSyncing = true
        
        Task {
            await syncManager.performDeltaSync()
            isSyncing = false
        }
    }
    
    // MARK: - Task CRUD
    
    /// Create a new task locally and push to MyMCP
    func createTask(
        title: String,
        description: String? = nil,
        dueDate: Date? = nil,
        priority: Int = 3
    ) {
        guard let client = client else {
            errorMessage = "Not configured"
            return
        }
        
        let request = MyMCPTaskRequest(
            title: title,
            description: description,
            client: nil,
            project: nil,
            dueDate: dueDate,
            status: "open",
            priority: priority,
            urgency: "medium",
            tags: nil
        )
        
        Task {
            do {
                let task = try await client.createTask(request)
                tasks.append(task)
            } catch {
                handleError(error as? MyMCPError ?? .syncFailed(error.localizedDescription))
            }
        }
    }
    
    /// Update an existing task
    func updateTask(id: String, updates: MyMCPTaskRequest) {
        guard let client = client else {
            errorMessage = "Not configured"
            return
        }
        
        Task {
            do {
                let task = try await client.updateTask(id: id, updates)
                if let index = tasks.firstIndex(where: { $0.id == id }) {
                    tasks[index] = task
                }
            } catch {
                handleError(error as? MyMCPError ?? .syncFailed(error.localizedDescription))
            }
        }
    }
    
    /// Mark task as complete
    func completeTask(id: String) {
        guard let client = client else {
            errorMessage = "Not configured"
            return
        }
        
        Task {
            do {
                let task = try await client.completeTask(id: id)
                if let index = tasks.firstIndex(where: { $0.id == id }) {
                    tasks[index] = task
                }
            } catch {
                handleError(error as? MyMCPError ?? .syncFailed(error.localizedDescription))
            }
        }
    }
    
    /// Delete a task
    func deleteTask(id: String) {
        guard let client = client else {
            errorMessage = "Not configured"
            return
        }
        
        Task {
            do {
                try await client.deleteTask(id: id)
                tasks.removeAll { $0.id == id }
            } catch {
                handleError(error as? MyMCPError ?? .syncFailed(error.localizedDescription))
            }
        }
    }
    
    // MARK: - Webhook Handling
    
    /// Process incoming webhook data from MyMCP
    func processWebhook(_ data: Data) {
        webhookProcessor?.processWebhook(data: data)
    }
    
    /// Register webhooks with MyMCP (call on app launch)
    func registerWebhooks(callbackURL: String) async {
        guard let client = client else { return }
        
        do {
            // Register for all task events
            _ = try await client.registerWebhook(
                name: "Tasker - Created",
                event: "tasker.task.created",
                url: callbackURL,
                secret: nil
            )
            
            _ = try await client.registerWebhook(
                name: "Tasker - Updated",
                event: "tasker.task.updated",
                url: callbackURL,
                secret: nil
            )
            
            _ = try await client.registerWebhook(
                name: "Tasker - Completed",
                event: "tasker.task.completed",
                url: callbackURL,
                secret: nil
            )
            
            _ = try await client.registerWebhook(
                name: "Tasker - Deleted",
                event: "tasker.task.deleted",
                url: callbackURL,
                secret: nil
            )
            
        } catch {
            handleError(error as? MyMCPError ?? .syncFailed(error.localizedDescription))
        }
    }
    
    // MARK: - Private Methods
    
    private func handleSync(tasks: [MyMCPTask], deletedIds: [String]) {
        // Remove deleted tasks
        self.tasks.removeAll { deletedIds.contains($0.id) }
        
        // Update or insert new/modified tasks
        for task in tasks {
            if let index = self.tasks.firstIndex(where: { $0.id == task.id }) {
                self.tasks[index] = task
            } else {
                self.tasks.append(task)
            }
        }
        
        // Sort by updated_at descending
        self.tasks.sort { $0.updatedAt > $1.updatedAt }
        
        self.lastSyncTime = Date()
    }
    
    private func handleError(_ error: MyMCPError) {
        self.errorMessage = error.localizedDescription
    }
}

// MARK: - MyMCPWebhookHandler Protocol Conformance

extension TaskSyncViewModel: MyMCPWebhookHandler {
    
    func handleTaskCreated(_ task: MyMCPTask) {
        if !tasks.contains(where: { $0.id == task.id }) {
            tasks.append(task)
            tasks.sort { $0.updatedAt > $1.updatedAt }
        }
    }
    
    func handleTaskUpdated(_ task: MyMCPTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
        }
    }
    
    func handleTaskCompleted(_ task: MyMCPTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
        }
    }
    
    func handleTaskDeleted(id: String) {
        tasks.removeAll { $0.id == id }
    }
}

// MARK: - SyncManager Helper Extension

extension MyMCPSyncManager {
    func setCallbacks(
        onTasksReceived: @escaping ([MyMCPTask], [String]) -> Void,
        onError: @escaping (MyMCPError) -> Void
    ) {
        self.onTasksReceived = onTasksReceived
        self.onError = onError
    }
}
