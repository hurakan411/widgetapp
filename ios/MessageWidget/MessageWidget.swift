import WidgetKit
import SwiftUI
import AppIntents
import os.log

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
        
        // Try to find and toggle task in both keys
        let keys = ["my_tasks_key", "partner_tasks_key_0", "partner_tasks_key_1", "partner_tasks_key_2"]
        
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
                            
                            // Check if task is Confirmed
                            let isConfirmed = tasks[index].isConfirmed ?? false
                            
                            if isConfirmed {
                                // --- Confirmed -> Done (just remove confirmation) ---
                                tasks[index].isConfirmed = false
                                updates["is_confirmed"] = false
                                // Keep isDone as true, don't change doneAt
                                
                            } else if isMyTask {
                                // --- My Task (Not Confirmed): Toggle Done/Undone ---
                                let currentIsDone = tasks[index].isDone
                                let newState = !currentIsDone
                                
                                tasks[index].isDone = newState
                                let doneAtStr = newState ? ISO8601DateFormatter().string(from: Date()) : nil
                                tasks[index].doneAt = doneAtStr
                                
                                updates["is_done"] = newState
                                updates["done_at"] = newState ? (doneAtStr as Any) : NSNull()
                                
                            } else {
                                // --- Partner Task (Not Confirmed): Done -> Confirmed ---
                                if tasks[index].isDone {
                                    tasks[index].isConfirmed = true
                                    updates["is_confirmed"] = true
                                } else {
                                    // Partner hasn't finished yet. Do nothing.
                                    return .result()
                                }
                            }
                            
                            // --- Save Local ---
                            if let newData = try? JSONEncoder().encode(tasks),
                               let newJsonString = String(data: newData, encoding: .utf8) {
                                userDefaults?.set(newJsonString, forKey: key)
                            }
                            
                            // --- Sync to Supabase (PATCH) ---
                            if !updates.isEmpty,
                               let urlStr = userDefaults?.string(forKey: "supabase_url"),
                               let anonKey = userDefaults?.string(forKey: "supabase_anon_key"),
                               let token = userDefaults?.string(forKey: "supabase_access_token"),
                               let url = URL(string: "\(urlStr)/rest/v1/tasks?id=eq.\(taskId)") {
                                
                                var request = URLRequest(url: url)
                                request.httpMethod = "PATCH"
                                request.addValue(anonKey, forHTTPHeaderField: "apikey")
                                request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                                request.addValue("return=minimal", forHTTPHeaderField: "Prefer")
                                
                                do {
                                    request.httpBody = try JSONSerialization.data(withJSONObject: updates)
                                    logger.info("--- [Swift] Sending PATCH request to \(url.absoluteString) ---")
                                    let (data, response) = try await URLSession.shared.data(for: request)
                                    if let httpResponse = response as? HTTPURLResponse {
                                        logger.info("--- [Swift] Response Status: \(httpResponse.statusCode) ---")
                                        if httpResponse.statusCode >= 300 {
                                            let bodyStr = String(data: data, encoding: .utf8) ?? "No Body"
                                            logger.error("--- [Swift] Supabase Error: \(httpResponse.statusCode), Body: \(bodyStr) ---")
                                        }
                                    }
                                } catch {
                                    logger.error("--- [Swift] Network Error: \(error.localizedDescription) ---")
                                }
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

// 2. Intent for Configuration (Select Mode)
@available(iOS 17.0, *)
struct SelectTaskModeIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Task Mode"
    static var description: IntentDescription = IntentDescription("Choose whose tasks to display.")
    
    @Parameter(title: "Mode", default: .me)
    var mode: TaskMode
}

@available(iOS 17.0, *)
enum TaskMode: String, AppEnum {
    case me
    case partner1
    case partner2
    case partner3
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Task Mode"
    static var caseDisplayRepresentations: [TaskMode : DisplayRepresentation] = [
        .me: "My Tasks",
        .partner1: "Partner 1",
        .partner2: "Partner 2",
        .partner3: "Partner 3"
    ]
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
        ], mode: configuration.mode, partnerName: nil)
    }
    
    func timeline(for configuration: SelectTaskModeIntent, in context: Context) async -> Timeline<SimpleEntry> {
        logger.info("--- [Swift] getTimeline Start (Mode: \(configuration.mode.rawValue)) ---")
        
        let suiteName = "group.com.shashinoguchi.widgetTask"
        let userDefaults = UserDefaults(suiteName: suiteName)
        
        // Use configuration.mode directly to allow independent widgets
        let mode = configuration.mode
        
        // Select key based on mode
        let key: String
        let nameKey: String?
        
        switch mode {
        case .me:
            key = "my_tasks_key"
            nameKey = nil
        case .partner1:
            key = "partner_tasks_key_0"
            nameKey = "partner_name_key_0"
        case .partner2:
            key = "partner_tasks_key_1"
            nameKey = "partner_name_key_1"
        case .partner3:
            key = "partner_tasks_key_2"
            nameKey = "partner_name_key_2"
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
                    // Inner Shadow Simulation (Top-Left Dark, Bottom-Right Light for Inset)
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
                } else {
                    // Undone State (Convex / Unpressed)
                    baseColor
                    // Light Source (Top-Left)
                    LinearGradient(
                        gradient: Gradient(colors: [.white.opacity(0.8), .clear]),
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    // Title
                    Text(task.title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(isDone ? .white : textColor)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .shadow(color: isDone ? .black.opacity(0.1) : .clear, radius: 0, x: 0, y: 1)
                    
                    Spacer()
                    
                    // Status Text (Big)
                    Group {
                        if isConfirmed {
                            Text("CONFIRMED")
                                .font(.system(size: 20, weight: .black, design: .rounded)) // Slightly smaller to fit
                                .foregroundColor(Color(red: 0.89, green: 0.69, blue: 0.29))
                                .tracking(1.0)
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                        } else if isDone {
                            if let doneAtStr = task.doneAt, let timeStr = formatDoneTime(doneAtStr) {
                                HStack(alignment: .lastTextBaseline, spacing: 4) {
                                    Text("DONE")
                                        .font(.system(size: 24, weight: .black, design: .rounded))
                                        .foregroundColor(.white.opacity(0.9))
                                        .tracking(1.0)
                                        .minimumScaleFactor(0.5)
                                    Text(timeStr)
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundColor(.white.opacity(0.7))
                                        .contentTransition(.numericText())
                                }
                            } else {
                                 Text("DONE")
                                    .font(.system(size: 24, weight: .black, design: .rounded))
                                    .foregroundColor(.white.opacity(0.9))
                                    .tracking(1.0)
                                    .minimumScaleFactor(0.5)
                            }
                        } else {
                            Text("UNDONE")
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundColor(textColor.opacity(0.3))
                                .tracking(1.0)
                                .minimumScaleFactor(0.5)
                        }
                    }
                    .id(isConfirmed ? "confirmed" : (isDone ? "done" : "undone"))
                    .transition(.push(from: .bottom))
                    .animation(.snappy, value: isDone)
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: isDone ? .clear : .black.opacity(0.15), radius: 3, x: 3, y: 3)
        .shadow(color: isDone ? .clear : .white.opacity(0.9), radius: 3, x: -2, y: -2)
    }
    
    func formatDoneTime(_ dateStr: String) -> String? {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
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
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(headerText(for: entry.mode))
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(Color(red: 0.17, green: 0.24, blue: 0.31).opacity(0.6))
                    .tracking(1.5)
                    .lineLimit(1)
                Spacer()
                Image(systemName: entry.mode == .me ? "person.fill" : "heart.fill")
                    .font(.caption2)
                    .foregroundColor(Color(red: 0.89, green: 0.69, blue: 0.29))
            }
            .padding(.bottom, 8)
            .padding(.horizontal, 4)
            
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
        .padding(8)
        .containerBackground(for: .widget) {
            Color(red: 0.88, green: 0.90, blue: 0.93)
        }
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
        case .partner3: return "PARTNER 3"
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
            let spacing: CGFloat = 8
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
                TaskCardView(task: task)
            }
            .buttonStyle(.plain)
            .frame(width: width, height: height)
        } else {
            TaskCardView(task: task)
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
