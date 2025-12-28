import WidgetKit
import SwiftUI
import os.log

struct Provider: TimelineProvider {
    let logger = Logger(subsystem: "com.shashinoguchi.widgetTask", category: "Widget")

    func placeholder(in context: Context) -> SimpleEntry {
        logger.fault("--- [Swift] placeholder called ---")
        return SimpleEntry(date: Date(), message: "Placeholder Message")
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        logger.fault("--- [Swift] getSnapshot called ---")
        let entry = SimpleEntry(date: Date(), message: "Snapshot Message")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        logger.fault("--- [Swift] getTimeline Start ---")
        
        // Fetch data from App Group (UserDefaults)
        let suiteName = "group.com.shashinoguchi.widgetTask"
        let userDefaults = UserDefaults(suiteName: suiteName)
        
        if userDefaults == nil {
            logger.fault("--- [Swift] UserDefaults is NIL for suite: \(suiteName) ---")
        } else {
            logger.fault("--- [Swift] UserDefaults initialized for suite: \(suiteName) ---")
        }
        
        userDefaults?.synchronize()
        
        let message = userDefaults?.string(forKey: "message_key") ?? "No Message (Read Failed)"
        logger.fault("--- [Swift] Read Message: \(message) ---")
        
        // Create entry
        let entry = SimpleEntry(date: Date(), message: message)

        // Refresh policy
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let message: String
}

struct MessageWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack {
            Text("Latest Message:")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(entry.message)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding()
        }
        .containerBackground(for: .widget) {
            Color.white
        }
    }
}

@main
struct MessageWidget: Widget {
    let kind: String = "MessageWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                MessageWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                MessageWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Message Widget")
        .description("Displays the latest received message.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
