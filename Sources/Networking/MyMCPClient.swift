import Foundation

// MARK: - Models

/// Represents a task from MyMCP
struct MyMCPTask: Codable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let client: String?
    let project: String?
    let emailSubject: String?
    let emailFrom: String?
    let emailID: String?
    let dueDate: Date?
    let status: String
    let priority: Int
    let urgency: String
    let assignedAgent: String?
    let source: String
    let estimatedHours: Double?
    let actualHours: Double?
    let hourlyRate: Double?
    let billingStatus: String
    let tags: [String]
    let documentRefs: [String]?
    let appleReminderID: String?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, client, project
        case emailSubject = "email_subject"
        case emailFrom = "email_from"
        case emailID = "email_id"
        case dueDate = "due_date"
        case status, priority, urgency
        case assignedAgent = "assigned_agent"
        case source
        case estimatedHours = "estimated_hours"
        case actualHours = "actual_hours"
        case hourlyRate = "hourly_rate"
        case billingStatus = "billing_status"
        case tags
        case documentRefs = "document_refs"
        case appleReminderID = "apple_reminder_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Request body for creating/updating a task
struct MyMCPTaskRequest: Codable {
    let title: String
    let description: String?
    let client: String?
    let project: String?
    let dueDate: Date?
    let status: String?
    let priority: Int?
    let urgency: String?
    let tags: [String]?
    
    enum CodingKeys: String, CodingKey {
        case title, description, client, project
        case dueDate = "due_date"
        case status, priority, urgency, tags
    }
}

/// Response from list tasks endpoint
struct MyMCPListResponse: Codable {
    let tasks: [MyMCPTask]
    let count: Int
    let total: Int
    let offset: Int
    let limit: Int
}

/// Response from sync endpoint
struct MyMCPSyncResponse: Codable {
    let tasks: [MyMCPTask]
    let deletedIds: [String]
    let syncTimestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case tasks
        case deletedIds = "deleted_ids"
        case syncTimestamp = "sync_timestamp"
    }
}

/// Webhook payload structure
struct MyMCPWebhookPayload: Codable {
    let event: String
    let timestamp: Date
    let data: MyMCPTask
}

/// Webhook registration request
struct MyMCPWebhookRegistration: Codable {
    let name: String
    let event: String
    let url: String
    let secret: String?
    let headers: [String: String]?
}

// MARK: - Errors

enum MyMCPError: Error {
    case invalidURL
    case invalidResponse
    case unauthorized
    case notFound
    case conflict
    case serverError(Int)
    case networkError(Error)
    case decodingError(Error)
    case syncFailed(String)
}

extension MyMCPError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid MyMCP server URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Authentication failed"
        case .notFound:
            return "Task not found"
        case .conflict:
            return "Conflict with server state"
        case .serverError(let code):
            return "Server error (HTTP \(code))"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .syncFailed(let reason):
            return "Sync failed: \(reason)"
        }
    }
}

// MARK: - MyMCP Client

/// Client for communicating with MyMCP API
actor MyMCPClient {
    
    // MARK: - Properties
    
    let baseURL: URL
    let token: String
    private let session: URLSession
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder
    
    // MARK: - Initialization
    
    init(baseURL: URL, token: String) {
        self.baseURL = baseURL
        self.token = token
        
        // Configure URLSession
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
        
        // Configure date encoding/decoding (ISO8601)
        self.jsonEncoder = JSONEncoder()
        self.jsonEncoder.dateEncodingStrategy = .iso8601
        
        self.jsonDecoder = JSONDecoder()
        self.jsonDecoder.dateDecodingStrategy = .iso8601
    }
    
    convenience init?(baseURLString: String, token: String) {
        guard let url = URL(string: baseURLString) else { return nil }
        self.init(baseURL: url, token: token)
    }
    
    // MARK: - API Methods
    
    // MARK: List Tasks
    
    /// List tasks with optional filters
    func listTasks(
        status: String? = nil,
        client: String? = nil,
        project: String? = nil,
        assignedTo: String? = nil,
        limit: Int = 50,
        offset: Int = 0,
        orderBy: String = "created_at",
        orderDesc: Bool = true
    ) async throws -> MyMCPListResponse {
        
        var components = URLComponents(url: baseURL.appendingPathComponent("/api/v1/tasks"), resolvingAgainstBaseURL: true)!
        var queryItems: [URLQueryItem] = []
        
        if let status = status { queryItems.append(URLQueryItem(name: "status", value: status)) }
        if let client = client { queryItems.append(URLQueryItem(name: "client", value: client)) }
        if let project = project { queryItems.append(URLQueryItem(name: "project", value: project)) }
        if let assignedTo = assignedTo { queryItems.append(URLQueryItem(name: "assigned_to", value: assignedTo)) }
        
        queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        queryItems.append(URLQueryItem(name: "offset", value: String(offset)))
        queryItems.append(URLQueryItem(name: "order_by", value: orderBy))
        queryItems.append(URLQueryItem(name: "order_desc", value: String(orderDesc)))
        
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        
        guard let url = components.url else {
            throw MyMCPError.invalidURL
        }
        
        let request = makeRequest(url: url, method: "GET")
        let data = try await performRequest(request)
        
        return try jsonDecoder.decode(MyMCPListResponse.self, from: data)
    }
    
    // MARK: Get Single Task
    
    /// Get a single task by ID
    func getTask(id: String) async throws -> MyMCPTask {
        let url = baseURL.appendingPathComponent("/api/v1/tasks/\(id)")
        let request = makeRequest(url: url, method: "GET")
        let data = try await performRequest(request)
        
        return try jsonDecoder.decode(MyMCPTask.self, from: data)
    }
    
    // MARK: Create Task
    
    /// Create a new task
    func createTask(_ task: MyMCPTaskRequest) async throws -> MyMCPTask {
        let url = baseURL.appendingPathComponent("/api/v1/tasks")
        var request = makeRequest(url: url, method: "POST")
        request.httpBody = try jsonEncoder.encode(task)
        
        let data = try await performRequest(request)
        return try jsonDecoder.decode(MyMCPTask.self, from: data)
    }
    
    /// Convenience method to create task with individual parameters
    func createTask(
        title: String,
        description: String? = nil,
        client: String? = nil,
        project: String? = nil,
        dueDate: Date? = nil,
        status: String = "open",
        priority: Int = 3,
        urgency: String = "medium",
        tags: [String]? = nil
    ) async throws -> MyMCPTask {
        let request = MyMCPTaskRequest(
            title: title,
            description: description,
            client: client,
            project: project,
            dueDate: dueDate,
            status: status,
            priority: priority,
            urgency: urgency,
            tags: tags
        )
        return try await createTask(request)
    }
    
    // MARK: Update Task
    
    /// Update an existing task
    func updateTask(id: String, _ updates: MyMCPTaskRequest) async throws -> MyMCPTask {
        let url = baseURL.appendingPathComponent("/api/v1/tasks/\(id)")
        var request = makeRequest(url: url, method: "PUT")
        request.httpBody = try jsonEncoder.encode(updates)
        
        let data = try await performRequest(request)
        return try jsonDecoder.decode(MyMCPTask.self, from: data)
    }
    
    /// Mark task as completed
    func completeTask(id: String, actualHours: Double? = nil) async throws -> MyMCPTask {
        var updates = MyMCPTaskRequest(
            title: "",
            description: nil,
            client: nil,
            project: nil,
            dueDate: nil,
            status: "completed",
            priority: nil,
            urgency: nil,
            tags: nil
        )
        return try await updateTask(id: id, updates)
    }
    
    // MARK: Delete Task
    
    /// Delete a task
    func deleteTask(id: String) async throws {
        let url = baseURL.appendingPathComponent("/api/v1/tasks/\(id)")
        let request = makeRequest(url: url, method: "DELETE")
        _ = try await performRequest(request)
    }
    
    // MARK: Sync
    
    /// Get tasks changed since a specific timestamp (delta sync)
    func syncTasks(since: Date, status: String? = nil, limit: Int = 500) async throws -> MyMCPSyncResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("/api/v1/tasks/sync"), resolvingAgainstBaseURL: true)!
        
        let formatter = ISO8601DateFormatter()
        var queryItems = [URLQueryItem(name: "since", value: formatter.string(from: since))]
        
        if let status = status {
            queryItems.append(URLQueryItem(name: "status", value: status))
        }
        queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw MyMCPError.invalidURL
        }
        
        let request = makeRequest(url: url, method: "GET")
        let data = try await performRequest(request)
        
        return try jsonDecoder.decode(MyMCPSyncResponse.self, from: data)
    }
    
    // MARK: Webhook Registration
    
    /// Register a webhook for task events
    func registerWebhook(
        name: String,
        event: String,
        url: String,
        secret: String? = nil,
        headers: [String: String]? = nil
    ) async throws -> String {
        
        let registration = MyMCPWebhookRegistration(
            name: name,
            event: event,
            url: url,
            secret: secret,
            headers: headers
        )
        
        let endpoint = baseURL.appendingPathComponent("/api/v1/webhooks")
        var request = makeRequest(url: endpoint, method: "POST")
        request.httpBody = try jsonEncoder.encode(registration)
        
        let data = try await performRequest(request)
        
        // Parse response to get webhook ID
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["id"] as? String else {
            throw MyMCPError.invalidResponse
        }
        
        return id
    }
    
    /// Unregister a webhook
    func unregisterWebhook(id: String) async throws {
        let url = baseURL.appendingPathComponent("/api/v1/webhooks/\(id)")
        let request = makeRequest(url: url, method: "DELETE")
        _ = try await performRequest(request)
    }
    
    // MARK: - Helper Methods
    
    private func makeRequest(url: URL, method: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }
    
    private func performRequest(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw MyMCPError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                return data
            case 401:
                throw MyMCPError.unauthorized
            case 404:
                throw MyMCPError.notFound
            case 409:
                throw MyMCPError.conflict
            default:
                throw MyMCPError.serverError(httpResponse.statusCode)
            }
            
        } catch let error as MyMCPError {
            throw error
        } catch {
            throw MyMCPError.networkError(error)
        }
    }
}

// MARK: - Webhook Handler

/// Protocol for handling MyMCP webhook events
protocol MyMCPWebhookHandler: AnyObject {
    func handleTaskCreated(_ task: MyMCPTask)
    func handleTaskUpdated(_ task: MyMCPTask)
    func handleTaskCompleted(_ task: MyMCPTask)
    func handleTaskDeleted(id: String)
}

/// Default webhook handler that delegates to a delegate
class MyMCPWebhookProcessor {
    
    weak var handler: MyMCPWebhookHandler?
    private let jsonDecoder: JSONDecoder
    
    init() {
        self.jsonDecoder = JSONDecoder()
        self.jsonDecoder.dateDecodingStrategy = .iso8601
    }
    
    /// Process incoming webhook payload
    func processWebhook(data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let event = json["event"] as? String else {
            print("Invalid webhook payload")
            return
        }
        
        switch event {
        case "tasker.task.created":
            if let task = try? jsonDecoder.decode(MyMCPTask.self, from: data) {
                handler?.handleTaskCreated(task)
            }
            
        case "tasker.task.updated":
            if let task = try? jsonDecoder.decode(MyMCPTask.self, from: data) {
                handler?.handleTaskUpdated(task)
            }
            
        case "tasker.task.completed":
            if let task = try? jsonDecoder.decode(MyMCPTask.self, from: data) {
                handler?.handleTaskCompleted(task)
            }
            
        case "tasker.task.deleted":
            if let taskData = json["data"] as? [String: Any],
               let id = taskData["id"] as? String {
                handler?.handleTaskDeleted(id: id)
            }
            
        default:
            print("Unknown webhook event: \(event)")
        }
    }
}

// MARK: - Sync Manager

/// Manages bidirectional sync with MyMCP
actor MyMCPSyncManager {
    
    private let client: MyMCPClient
    private var lastSyncTimestamp: Date?
    private var syncTimer: Timer?
    private let syncInterval: TimeInterval
    
    var onTasksReceived: (([MyMCPTask], [String]) -> Void)?
    var onError: ((MyMCPError) -> Void)?
    
    init(client: MyMCPClient, syncInterval: TimeInterval = 30) {
        self.client = client
        self.syncInterval = syncInterval
    }
    
    /// Perform initial full sync
    func performInitialSync() async {
        do {
            let response = try await client.listTasks(limit: 500)
            lastSyncTimestamp = response.tasks.map(\.updatedAt).max()
            await MainActor.run {
                onTasksReceived?(response.tasks, [])
            }
        } catch let error as MyMCPError {
            await MainActor.run { onError?(error) }
        } catch {
            await MainActor.run { onError?(.networkError(error)) }
        }
    }
    
    /// Perform delta sync (tasks changed since last sync)
    func performDeltaSync() async {
        guard let since = lastSyncTimestamp else {
            await performInitialSync()
            return
        }
        
        do {
            let response = try await client.syncTasks(since: since)
            lastSyncTimestamp = response.syncTimestamp
            await MainActor.run {
                onTasksReceived?(response.tasks, response.deletedIds)
            }
        } catch let error as MyMCPError {
            await MainActor.run { onError?(error) }
        } catch {
            await MainActor.run { onError?(.networkError(error)) }
        }
    }
    
    /// Start periodic sync
    func startPeriodicSync() {
        Task {
            await performDeltaSync()
        }
        
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.performDeltaSync()
            }
        }
    }
    
    /// Stop periodic sync
    func stopPeriodicSync() {
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    /// Push local task changes to server
    func pushTask(_ task: MyMCPTaskRequest) async throws -> MyMCPTask {
        return try await client.createTask(task)
    }
    
    /// Get the last sync timestamp
    func getLastSyncTimestamp() -> Date? {
        return lastSyncTimestamp
    }
    
    /// Set the last sync timestamp (e.g., from persisted storage)
    func setLastSyncTimestamp(_ date: Date) {
        lastSyncTimestamp = date
    }
}
