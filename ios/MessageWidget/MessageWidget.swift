import WidgetKit
import SwiftUI
import AppIntents
import os.log

// --- Token Refresher ---
class TokenRefresher {
    static func refreshAccessToken() async -> String? {
        let logger = Logger(subsystem: "com.shashinoguchi.widgetTask", category: "TokenRefresh")
        let suiteName = "group.com.shashinoguchi.widgetTask"
        guard let userDefaults = UserDefaults(suiteName: suiteName),
              let urlStr = userDefaults.string(forKey: "supabase_url"),
              let anonKey = userDefaults.string(forKey: "supabase_anon_key"),
              let refreshToken = userDefaults.string(forKey: "supabase_refresh_token") else {
            logger.error("--- [Swift] Missing refresh token or credentials ---")
            return nil
        }
        
        guard let url = URL(string: "\(urlStr)/auth/v1/token?grant_type=refresh_token") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(anonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = ["refresh_token": refreshToken]
        request.httpBody = try? JSONEncoder().encode(body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                // Parse response to get new access token
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let newAccessToken = json["access_token"] as? String,
                   let newRefreshToken = json["refresh_token"] as? String {
                    // Save new tokens
                    userDefaults.set(newAccessToken, forKey: "supabase_access_token")
                    userDefaults.set(newRefreshToken, forKey: "supabase_refresh_token")
                    logger.info("--- [Swift] Token refreshed successfully ---")
                    return newAccessToken
                }
            } else {
                logger.error("--- [Swift] Token refresh failed ---")
            }
        } catch {
            logger.error("--- [Swift] Token refresh error: \(error.localizedDescription) ---")
        }
        return nil
    }
    
    static func getValidToken() async -> String? {
        let suiteName = "group.com.shashinoguchi.widgetTask"
        guard let userDefaults = UserDefaults(suiteName: suiteName),
              let currentToken = userDefaults.string(forKey: "supabase_access_token") else {
            return await refreshAccessToken()
        }
        
        // Try to use current token first, if it fails we'll refresh
        return currentToken
    }
}

// --- Models ---
struct Task: Codable, Identifiable {
    let id: String
    let title: String
    var isDone: Bool
    var doneAt: String?
    let createdAt: String
    // Reset Config
    let resetType: Int?
    let resetValue: Int?
    let scheduledResetAt: String?
    // Confirmation
    var isConfirmed: Bool?
    var confirmedAt: String?
    
    // CodingKeys to handle both camelCase (app) and snake_case (Supabase)
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case isDone = "is_done"
        case doneAt = "done_at"
        case createdAt = "created_at"
        case resetType = "reset_type"
        case resetValue = "reset_value"
        case scheduledResetAt = "scheduled_reset_at"
        case isConfirmed = "is_confirmed"
        case confirmedAt = "confirmed_at"
    }
    
    // Helper to check if task is effectively done
    var isEffectivelyDone: Bool {
        if !isDone { return false }
        
        if let scheduledStr = scheduledResetAt {
            // Parse ISO8601 string
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            if let scheduledDate = formatter.date(from: scheduledStr) {
                if Date() > scheduledDate {
                    return false // Expired, so show as Undone
                }
            } else {
                // Fallback without fractional seconds
                formatter.formatOptions = [.withInternetDateTime]
                if let scheduledDate = formatter.date(from: scheduledStr) {
                    if Date() > scheduledDate {
                        return false
                    }
                }
            }
        }
        return true
    }
    
    // Helper to check if task should be visible
    var isVisible: Bool {
        return true
    }
}

// --- App Intents ---

// 1. Intent for Toggling Task (Interactive)
@available(iOS 17.0, *)
struct ToggleTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Task"
    
    @Parameter(title: "Task ID")
    var taskId: String
    
    @Parameter(title: "Is My Task")
    var isMyTask: Bool
    
    init() {}
    
    init(taskId: String, isMyTask: Bool) {
        self.taskId = taskId
        self.isMyTask = isMyTask
    }
    
    func perform() async throws -> some IntentResult {
        let logger = Logger(subsystem: "com.shashinoguchi.widgetTask", category: "AppIntent")
        logger.info("--- [Swift] ToggleTaskIntent performed for ID: \(taskId) ---")
        
        let suiteName = "group.com.shashinoguchi.widgetTask"
        let userDefaults = UserDefaults(suiteName: suiteName)
        
        // Save debug log immediately
        userDefaults?.set("ToggleTaskIntent started for: \(taskId)", forKey: "widget_debug_log")
        
        // Try to find and toggle task in both keys
        let keys = ["my_tasks_key", "partner_tasks_key_0", "partner_tasks_key_1"]
        
        for key in keys {
            if let jsonString = userDefaults?.string(forKey: key),
               let data = jsonString.data(using: .utf8),
               var tasks = try? JSONDecoder().decode([Task].self, from: data) {
                
                if let index = tasks.firstIndex(where: { $0.id == taskId }) {
                    let isMyTask = key == "my_tasks_key"
                    
                    // The original code had an outer `if let index = tasks.firstIndex(...)`
                    // The provided change re-introduces a loop and an `if tasks[index].id == taskId` check.
                    // To faithfully apply the change, we'll replace the inner logic block.
                    // The `for index in 0..<tasks.count` and `if tasks[index].id == taskId`
                    // are redundant given the outer `firstIndex` but are part of the requested change.
                    for index in 0..<tasks.count {
                        if tasks[index].id == taskId {
                            var updates: [String: Any] = [:]
                            
                            // Prepare update values without modifying tasks yet
                            let isConfirmed = tasks[index].isConfirmed ?? false
                            var newIsDone = tasks[index].isDone
                            var newIsConfirmed = tasks[index].isConfirmed
                            var newDoneAt = tasks[index].doneAt
                            
                            if isConfirmed {
                                if isMyTask {
                                    // --- My Confirmed Task -> Undone (reset everything) ---
                                    newIsDone = false
                                    newIsConfirmed = false
                                    newDoneAt = nil
                                    
                                    updates["is_done"] = false
                                    updates["is_confirmed"] = false
                                    updates["done_at"] = NSNull()
                                } else {
                                    // --- Partner's Confirmed Task -> Done (just remove confirmation) ---
                                    newIsConfirmed = false
                                    updates["is_confirmed"] = false
                                }
                                
                            } else if isMyTask {
                                // --- My Task (Not Confirmed): Toggle Done/Undone ---
                                let currentIsDone = tasks[index].isDone
                                newIsDone = !currentIsDone
                                newDoneAt = newIsDone ? ISO8601DateFormatter().string(from: Date()) : nil
                                
                                updates["is_done"] = newIsDone
                                updates["done_at"] = newIsDone ? (newDoneAt as Any) : NSNull()
                                
                            } else {
                                // --- Partner Task (Not Confirmed): Done -> Confirmed ---
                                if tasks[index].isDone {
                                    newIsConfirmed = true
                                    updates["is_confirmed"] = true
                                } else {
                                    // Partner hasn't finished yet. Do nothing.
                                    return .result()
                                }
                            }
                            
                            // --- Apply changes and save locally OPTIMISTICALLY ---
                            tasks[index].isDone = newIsDone
                            tasks[index].isConfirmed = newIsConfirmed
                            tasks[index].doneAt = newDoneAt
                            
                            if let newData = try? JSONEncoder().encode(tasks),
                               let newJsonString = String(data: newData, encoding: .utf8) {
                                userDefaults?.set(newJsonString, forKey: key)
                                logger.info("--- [Swift] Saved local changes (Optimistic) ---")
                            }

                            // --- Sync to Supabase (PATCH) with auto-refresh ---
                            var dbUpdateSuccess = false
                            
                            if !updates.isEmpty,
                               let urlStr = userDefaults?.string(forKey: "supabase_url"),
                               let anonKey = userDefaults?.string(forKey: "supabase_anon_key"),
                               var token = userDefaults?.string(forKey: "supabase_access_token"),
                               let url = URL(string: "\(urlStr)/rest/v1/tasks?id=eq.\(taskId)") {
                                
                                // Try up to 2 times (original + retry after refresh)
                                for attempt in 1...2 {
                                    var request = URLRequest(url: url)
                                    request.httpMethod = "PATCH"
                                    request.addValue(anonKey, forHTTPHeaderField: "apikey")
                                    request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                                    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                                    request.addValue("return=minimal", forHTTPHeaderField: "Prefer")
                                    
                                    do {
                                        request.httpBody = try JSONSerialization.data(withJSONObject: updates)
                                        logger.info("--- [Swift] Sending PATCH request (attempt \(attempt)) ---")
                                        userDefaults?.set("Sending PATCH to \(taskId) (attempt \(attempt))...", forKey: "widget_debug_log")
                                        
                                        let (data, response) = try await URLSession.shared.data(for: request)
                                        if let httpResponse = response as? HTTPURLResponse {
                                            logger.info("--- [Swift] Response Status: \(httpResponse.statusCode) ---")
                                            
                                            if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                                                dbUpdateSuccess = true
                                                userDefaults?.set("SUCCESS: PATCH \(taskId) -> \(httpResponse.statusCode)", forKey: "widget_debug_log")
                                                break // Success, exit loop
                                            } else if httpResponse.statusCode == 401 && attempt == 1 {
                                                // Token expired, try to refresh
                                                logger.info("--- [Swift] Token expired, refreshing... ---")
                                                if let newToken = await TokenRefresher.refreshAccessToken() {
                                                    token = newToken
                                                    continue // Retry with new token
                                                }
                                            }
                                            
                                            let bodyStr = String(data: data, encoding: .utf8) ?? "No Body"
                                            logger.error("--- [Swift] Supabase Error: \(httpResponse.statusCode), Body: \(bodyStr) ---")
                                            userDefaults?.set("ERROR: \(httpResponse.statusCode) - \(bodyStr)", forKey: "widget_debug_log")
                                        }
                                    } catch {
                                        logger.error("--- [Swift] Network Error: \(error.localizedDescription) ---")
                                        userDefaults?.set("NETWORK ERROR: \(error.localizedDescription)", forKey: "widget_debug_log")
                                    }
                                    break // Exit on error (unless it's 401 on first attempt)
                                }
                            } else {
                                userDefaults?.set("ERROR: Missing credentials or URL", forKey: "widget_debug_log")
                            }
                            
                            if !dbUpdateSuccess {
                                logger.error("--- [Swift] DB update failed, but local changes kept (Optimistic) ---")
                            }
                            
                            // Reload timeline
                            WidgetCenter.shared.reloadAllTimelines()
                            return .result()
                        }
                    }
                    return .result()
                }
            }
        }
        
        return .result()
    }
}

// 1.5. Intent for Refreshing Widget Data from Supabase
@available(iOS 17.0, *)
struct RefreshIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh Tasks"
    
    @Parameter(title: "Target")
    var target: TaskTarget
    
    init() {
        self.target = TaskTarget(id: "me", name: "My Tasks")
    }
    
    init(mode: TaskMode) {
        // Convert TaskMode to TaskTarget
        switch mode {
        case .me:
            self.target = TaskTarget(id: "me", name: "My Tasks")
        case .partner1:
            self.target = TaskTarget(id: "partner1", name: "Partner 1")
        case .partner2:
            self.target = TaskTarget(id: "partner2", name: "Partner 2")
        }
    }
    
    init(target: TaskTarget) {
        self.target = target
    }
    
    func perform() async throws -> some IntentResult {
        let logger = Logger(subsystem: "com.shashinoguchi.widgetTask", category: "Refresh")
        logger.info("--- [Swift] RefreshIntent performed for target: \(target.id) ---")
        
        let suiteName = "group.com.shashinoguchi.widgetTask"
        let userDefaults = UserDefaults(suiteName: suiteName)
        
        guard let urlStr = userDefaults?.string(forKey: "supabase_url"),
              let anonKey = userDefaults?.string(forKey: "supabase_anon_key"),
              let token = userDefaults?.string(forKey: "supabase_access_token") else {
            logger.error("--- [Swift] Missing Supabase credentials ---")
            WidgetCenter.shared.reloadAllTimelines()
            return .result()
        }
        
        // Determine which data to fetch based on target
        let key: String
        let userId: String?
        
        switch target.id {
        case "me":
            key = "my_tasks_key"
            userId = userDefaults?.string(forKey: "current_user_id")
        case "partner1":
            key = "partner_tasks_key_0"
            userId = userDefaults?.string(forKey: "partner_id_0")
        case "partner2":
            key = "partner_tasks_key_1"
            userId = userDefaults?.string(forKey: "partner_id_1")
        default:
            logger.error("--- [Swift] Unknown target ID: \(target.id) ---")
            WidgetCenter.shared.reloadAllTimelines()
            return .result()
        }
        
        guard let uid = userId, !uid.isEmpty else {
            logger.error("--- [Swift] No user ID for target \(target.id) ---")
            WidgetCenter.shared.reloadAllTimelines()
            return .result()
        }
        
        // Fetch data from Supabase
        guard let url = URL(string: "\(urlStr)/rest/v1/tasks?user_id=eq.\(uid)&order=created_at") else {
            logger.error("--- [Swift] Invalid URL ---")
            userDefaults?.set("ERROR: Invalid URL", forKey: "widget_debug_log")
            WidgetCenter.shared.reloadAllTimelines()
            return .result()
        }
        
        // Backup existing data before attempting refresh
        let existingData = userDefaults?.string(forKey: key)
        var fetchSucceeded = false
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(anonKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Try up to 2 times (original + retry after token refresh)
        var currentToken = token
        for attempt in 1...2 {
            var req = URLRequest(url: url)
            req.httpMethod = "GET"
            req.addValue(anonKey, forHTTPHeaderField: "apikey")
            req.addValue("Bearer \(currentToken)", forHTTPHeaderField: "Authorization")
            req.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                
                if let httpResponse = response as? HTTPURLResponse {
                    logger.info("--- [Swift] Refresh Response Status: \(httpResponse.statusCode) (attempt \(attempt)) ---")
                    
                    if httpResponse.statusCode == 200 {
                        // Save raw JSON string directly (no re-encoding)
                        if let jsonString = String(data: data, encoding: .utf8) {
                            userDefaults?.set(jsonString, forKey: key)
                            userDefaults?.set("SUCCESS: Refreshed \(key)", forKey: "widget_debug_log")
                            logger.info("--- [Swift] Saved raw JSON to \(key), length: \(jsonString.count) ---")
                            fetchSucceeded = true
                        }
                        break // Success, exit loop
                    } else if httpResponse.statusCode == 401 && attempt == 1 {
                        // Token expired, try to refresh
                        logger.info("--- [Swift] Token expired, refreshing... ---")
                        if let newToken = await TokenRefresher.refreshAccessToken() {
                            currentToken = newToken
                            continue // Retry with new token
                        }
                    }
                    
                    let bodyStr = String(data: data, encoding: .utf8) ?? "No Body"
                    logger.error("--- [Swift] Supabase Error: \(httpResponse.statusCode), Body: \(bodyStr) ---")
                    userDefaults?.set("ERROR: HTTP \(httpResponse.statusCode)", forKey: "widget_debug_log")
                }
            } catch {
                logger.error("--- [Swift] Refresh Network Error: \(error.localizedDescription) ---")
                userDefaults?.set("ERROR: \(error.localizedDescription)", forKey: "widget_debug_log")
            }
            break // Exit on error (unless 401 on first attempt)
        }
        
        // If fetch failed and we have existing data, restore it (ensure it's not lost)
        if !fetchSucceeded, let backup = existingData {
            userDefaults?.set(backup, forKey: key)
            logger.info("--- [Swift] Refresh failed, preserved existing data ---")
        }
        
        // Reload timeline
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// 2. Intent for Configuration (Select Mode)
@available(iOS 17.0, *)
struct SelectTaskModeIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Task Mode"
    static var description: IntentDescription = IntentDescription("Choose whose tasks to display.")
    
    @Parameter(title: "Mode")
    var target: TaskTarget
    
    init() {
        self.target = TaskTarget(id: "me", name: "My Tasks")
    }
    
    init(target: TaskTarget) {
        self.target = target
    }
}

@available(iOS 17.0, *)
enum TaskMode: String { // Removed AppEnum conformance as it's no longer used directly in Intent
    case me
    case partner1
    case partner2
}

@available(iOS 16.0, *)
struct TaskTarget: AppEntity {
    let id: String
    let name: String
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Display Target"
    static var defaultQuery = TaskTargetQuery()
        
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

@available(iOS 16.0, *)
struct TaskTargetQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [TaskTarget] {
        return try await suggestedEntities().filter { identifiers.contains($0.id) }
    }
    
    func suggestedEntities() async throws -> [TaskTarget] {
        let defaults = UserDefaults(suiteName: "group.com.shashinoguchi.widgetTask")
        var targets: [TaskTarget] = []
        
        targets.append(TaskTarget(id: "me", name: "My Tasks"))
        
        // Partner 1
        if let _ = defaults?.string(forKey: "partner_id_0") {
             let name = defaults?.string(forKey: "partner_name_0") ?? "Partner 1"
             targets.append(TaskTarget(id: "partner1", name: name))
        }
        
        // Partner 2
        if let _ = defaults?.string(forKey: "partner_id_1") {
             let name = defaults?.string(forKey: "partner_name_1") ?? "Partner 2"
             targets.append(TaskTarget(id: "partner2", name: name))
        }
        
        return targets
    }
    
    func defaultResult() async -> TaskTarget? {
        return TaskTarget(id: "me", name: "My Tasks")
    }
}

// --- Provider ---
struct Provider: AppIntentTimelineProvider {
    let logger = Logger(subsystem: "com.shashinoguchi.widgetTask", category: "Widget")

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), tasks: [], mode: .me, partnerName: nil)
    }

    func snapshot(for configuration: SelectTaskModeIntent, in context: Context) async -> SimpleEntry {
        SimpleEntry(date: Date(), tasks: [
            Task(id: "1", title: "Sample Task", isDone: false, doneAt: nil, createdAt: "", resetType: nil, resetValue: nil, scheduledResetAt: nil)
        ], mode: TaskMode(rawValue: configuration.target.id) ?? .me, partnerName: nil)
    }
    
    func timeline(for configuration: SelectTaskModeIntent, in context: Context) async -> Timeline<SimpleEntry> {
        logger.info("--- [Swift] getTimeline Start (Target: \(configuration.target.id)) ---")
        
        let suiteName = "group.com.shashinoguchi.widgetTask"
        let userDefaults = UserDefaults(suiteName: suiteName)
        
        // Use configuration.target directly to allow independent widgets
        let targetId = configuration.target.id
        let mode: TaskMode
        
        switch targetId {
        case "partner1": mode = .partner1
        case "partner2": mode = .partner2
        default: mode = .me
        }
        
        // Select key based on mode
        let key: String
        let nameKey: String?
        
        switch mode {
        case .me:
            key = "my_tasks_key"
            nameKey = nil
        case .partner1:
            key = "partner_tasks_key_0"
            nameKey = "partner_name_0"
        case .partner2:
            key = "partner_tasks_key_1"
            nameKey = "partner_name_1"
        }
        
        var tasks: [Task] = []
        var partnerName: String? = nil
        
        if let jsonString = userDefaults?.string(forKey: key) {
            if let data = jsonString.data(using: .utf8) {
                do {
                    tasks = try JSONDecoder().decode([Task].self, from: data)
                } catch {
                    logger.error("--- [Swift] JSON Decode Error: \(error.localizedDescription) ---")
                }
            }
        }
        
        if let nKey = nameKey {
            partnerName = userDefaults?.string(forKey: nKey)
        }
        
        let entry = SimpleEntry(date: Date(), tasks: tasks, mode: mode, partnerName: partnerName)
        return Timeline(entries: [entry], policy: .atEnd)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let tasks: [Task]
    let mode: TaskMode
    let partnerName: String?
}

// --- Views ---
struct TaskCardView: View {
    let task: Task
    let family: WidgetFamily
    
    // Retro Pop Colors
    let doneColor = Color(red: 0.89, green: 0.69, blue: 0.29) // Mustard Yellow
    let baseColor = Color(red: 0.88, green: 0.90, blue: 0.93) // Base Gray
    let textColor = Color(red: 0.17, green: 0.24, blue: 0.31) // Vintage Navy
    
    var body: some View {
        let isDone = task.isEffectivelyDone
        let isConfirmed = task.isConfirmed ?? false
        
        GeometryReader { geo in
            ZStack {
                // Background
                if isConfirmed {
                    // Confirmed State (Gold/Yellow)
                    Color(red: 0.89, green: 0.69, blue: 0.29).opacity(0.2)
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color(red: 0.89, green: 0.69, blue: 0.29), lineWidth: 2)
                } else if isDone {
                    // Done State (Concave / Pressed)
                    doneColor
                    // Inner Shadow Simulation (only for non-small widgets)
                    if family != .systemSmall {
                        LinearGradient(
                            gradient: Gradient(colors: [.black.opacity(0.15), .clear]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .mask(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(lineWidth: 4)
                                .blur(radius: 4)
                        )
                    }
                } else {
                    // Undone State (Convex / Unpressed)
                    baseColor
                    // Light Source (only for non-small widgets)
                    if family != .systemSmall {
                        LinearGradient(
                            gradient: Gradient(colors: [.white.opacity(0.8), .clear]),
                            startPoint: .topLeading,
                            endPoint: .center
                        )
                    }
                }
                
                // Content
                VStack(alignment: .leading, spacing: 3) {
                    // Title
                    Text(task.title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(isDone ? .white : textColor)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .shadow(color: isDone ? .black.opacity(0.1) : .clear, radius: 0, x: 0, y: 1)
                    
                    Spacer()
                    
                    // Status Text (Big) and Time (Vertical layout)
                    VStack(alignment: .leading, spacing: 1) {
                        if isConfirmed {
                            Text("CONFIRMED")
                                .font(.system(size: 36, weight: .black, design: .rounded))
                                .foregroundColor(Color(red: 0.89, green: 0.69, blue: 0.29))
                                .tracking(1.0)
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                            if let confirmedAtStr = task.confirmedAt, let timeStr = formatDoneTime(confirmedAtStr) {
                                Text(timeStr)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(red: 0.89, green: 0.69, blue: 0.29).opacity(0.7))
                                    .contentTransition(.numericText())
                            }
                        } else if isDone {
                            Text("DONE")
                                .font(.system(size: 42, weight: .black, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))
                                .tracking(1.0)
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                            if let doneAtStr = task.doneAt, let timeStr = formatDoneTime(doneAtStr) {
                                Text(timeStr)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.7))
                                    .contentTransition(.numericText())
                            }
                        } else {
                            Text("UNDONE")
                                .font(.system(size: 42, weight: .black, design: .rounded))
                                .foregroundColor(textColor.opacity(0.3))
                                .tracking(1.0)
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                        }
                    }
                    .id(isConfirmed ? "confirmed" : (isDone ? "done" : "undone"))
                    .transition(.push(from: .bottom))
                    .animation(.snappy, value: isDone)
                }
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: family == .systemSmall ? .clear : (isDone ? .clear : .black.opacity(0.15)), radius: 3, x: 3, y: 3)
        .shadow(color: family == .systemSmall ? .clear : (isDone ? .clear : .white.opacity(0.9)), radius: 3, x: -2, y: -2)
    }
    
    func formatDoneTime(_ dateStr: String) -> String? {
        let isoFormatter = ISO8601DateFormatter()
        
        // Try with fractional seconds first
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: dateStr) {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            return timeFormatter.string(from: date)
        }
        
        // Fallback: try without fractional seconds
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: dateStr) {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            return timeFormatter.string(from: date)
        }
        
        return nil
    }
}

struct MessageWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if family == .systemSmall {
            // Small widget: Full widget as task display
            smallWidgetView
        } else {
            // Medium/Large widgets: Header + Cards
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 6) {
                    // Icon (left of name)
                    Image(systemName: entry.mode == .me ? "person.fill" : "heart.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color(red: 0.89, green: 0.69, blue: 0.29))
                    
                    Text(headerText(for: entry.mode))
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(Color(red: 0.17, green: 0.24, blue: 0.31).opacity(0.6))
                        .tracking(1.5)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Refresh Button (Neumorphic Capsule)
                    if #available(iOS 17.0, *) {
                        Button(intent: RefreshIntent(mode: entry.mode)) {
                            ZStack {
                                // Neumorphic background
                                Capsule()
                                    .fill(Color(red: 0.88, green: 0.90, blue: 0.93))
                                    .shadow(color: .white.opacity(0.8), radius: 2, x: -2, y: -2)
                                    .shadow(color: Color(red: 0.68, green: 0.70, blue: 0.75).opacity(0.5), radius: 2, x: 2, y: 2)
                                
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Color(red: 0.17, green: 0.24, blue: 0.31).opacity(0.6))
                            }
                            .frame(width: 44, height: 22)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 2)
                .padding(.horizontal, 2)
                
                if entry.tasks.isEmpty {
                    VStack {
                        Image(systemName: "list.bullet.clipboard")
                            .font(.largeTitle)
                            .foregroundColor(.gray.opacity(0.3))
                        Text("No tasks")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    TaskGridView(tasks: entry.tasks, family: family, isMyTask: entry.mode == .me, mode: entry.mode)
                }
            }
            .padding(2)
            .containerBackground(for: .widget) {
                Color(red: 0.88, green: 0.90, blue: 0.93)
            }
        }
    }
    
    var smallWidgetView: some View {
        let task = entry.tasks.filter { $0.isVisible }.first ?? entry.tasks.first
        let isDone = task?.isEffectivelyDone ?? false
        let isConfirmed = task?.isConfirmed ?? false
        let textColor = Color(red: 0.17, green: 0.24, blue: 0.31)
        let backgroundColor: Color = {
            if isConfirmed {
                return Color(red: 0.89, green: 0.69, blue: 0.29).opacity(0.3)
            } else if isDone {
                return Color(red: 0.89, green: 0.69, blue: 0.29) // Mustard Yellow
            } else {
                return Color(red: 0.88, green: 0.90, blue: 0.93) // Base Gray
            }
        }()
        
        return Group {
            if let task = task {
                if #available(iOS 17.0, *) {
                    Button(intent: ToggleTaskIntent(taskId: task.id, isMyTask: entry.mode == .me)) {
                        smallTaskContent(task: task, isDone: isDone, isConfirmed: isConfirmed, textColor: textColor)
                    }
                    .buttonStyle(.plain)
                } else {
                    smallTaskContent(task: task, isDone: isDone, isConfirmed: isConfirmed, textColor: textColor)
                }
            } else {
                VStack {
                    Image(systemName: "list.bullet.clipboard")
                        .font(.largeTitle)
                        .foregroundColor(.gray.opacity(0.3))
                    Text("No tasks")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .containerBackground(for: .widget) {
            backgroundColor
        }
    }
    
    func smallTaskContent(task: Task, isDone: Bool, isConfirmed: Bool, textColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            // Title
            Text(task.title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(isDone ? .white : textColor)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
            
            // Status Text (Big) and Time (Vertical layout)
            VStack(alignment: .leading, spacing: 1) {
                if isConfirmed {
                    Text("CONFIRMED")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundColor(Color(red: 0.89, green: 0.69, blue: 0.29))
                        .tracking(1.0)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    if let confirmedAtStr = task.confirmedAt, let timeStr = formatDoneTime(confirmedAtStr) {
                        Text(timeStr)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0.89, green: 0.69, blue: 0.29).opacity(0.7))
                    }
                } else if isDone {
                    Text("DONE")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                        .tracking(1.0)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    if let doneAtStr = task.doneAt, let timeStr = formatDoneTime(doneAtStr) {
                        Text(timeStr)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }
                } else {
                    Text("UNDONE")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundColor(textColor.opacity(0.3))
                        .tracking(1.0)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    func formatDoneTime(_ dateStr: String) -> String? {
        let isoFormatter = ISO8601DateFormatter()
        
        // Try with fractional seconds first
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: dateStr) {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            return timeFormatter.string(from: date)
        }
        
        // Fallback: try without fractional seconds
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: dateStr) {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            return timeFormatter.string(from: date)
        }
        
        return nil
    }
    
    func headerText(for mode: TaskMode) -> String {
        if mode == .me {
            return "MY TASKS"
        }
        
        if let name = entry.partnerName, !name.isEmpty {
            return name.uppercased()
        }
        
        switch mode {
        case .partner1: return "PARTNER 1"
        case .partner2: return "PARTNER 2"
        default: return "PARTNER"
        }
    }
}

struct TaskGridView: View {
    let tasks: [Task]
    let family: WidgetFamily
    let isMyTask: Bool
    let mode: TaskMode
    
    let spacing: CGFloat = 12
    
    var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 2
            let config = layoutConfig
            let columns = config.columns
            let rows = config.rows
            
            let maxTasks = columns * rows
            // Filter tasks based on visibility
            let visibleTasks = tasks.filter { $0.isVisible }
            let displayTasks = Array(visibleTasks.prefix(maxTasks))
            
            let width = (geo.size.width - (CGFloat(columns - 1) * spacing)) / CGFloat(columns)
            let height = (geo.size.height - (CGFloat(rows - 1) * spacing)) / CGFloat(rows)
            
            VStack(spacing: spacing) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<columns, id: \.self) { col in
                            let index = row * columns + col
                            if index < displayTasks.count {
                                taskButton(for: displayTasks[index], width: width, height: height)
                            } else {
                                Spacer()
                                    .frame(width: width, height: height)
                            }
                        }
                    }
                }
            }
        }
    }
    
    var layoutConfig: (columns: Int, rows: Int) {
        switch family {
        case .systemSmall: return (1, 1)
        case .systemMedium: return (2, 1)
        case .systemLarge: return (2, 3)
        default: return (2, 1)
        }
    }
    
    @ViewBuilder
    func taskButton(for task: Task, width: CGFloat, height: CGFloat) -> some View {
        if #available(iOS 17.0, *) {
            Button(intent: ToggleTaskIntent(taskId: task.id, isMyTask: isMyTask)) {
                TaskCardView(task: task, family: family)
            }
            .buttonStyle(.plain)
            .frame(width: width, height: height)
        } else {
            TaskCardView(task: task, family: family)
                .frame(width: width, height: height)
        }
    }
}

@main
struct MessageWidget: Widget {
    let kind: String = "MessageWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectTaskModeIntent.self, provider: Provider()) { entry in
            MessageWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("OMAMORI Tasks")
        .description("Choose to display your tasks or your partner's tasks.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
