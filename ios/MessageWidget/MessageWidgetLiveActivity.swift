//
//  MessageWidgetLiveActivity.swift
//  MessageWidget
//
//  Created by 橋之口祥吾 on 2025/12/28.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct MessageWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct MessageWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MessageWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension MessageWidgetAttributes {
    fileprivate static var preview: MessageWidgetAttributes {
        MessageWidgetAttributes(name: "World")
    }
}

extension MessageWidgetAttributes.ContentState {
    fileprivate static var smiley: MessageWidgetAttributes.ContentState {
        MessageWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: MessageWidgetAttributes.ContentState {
         MessageWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: MessageWidgetAttributes.preview) {
   MessageWidgetLiveActivity()
} contentStates: {
    MessageWidgetAttributes.ContentState.smiley
    MessageWidgetAttributes.ContentState.starEyes
}
