//
//  CalrAIMacrosWidgetLiveActivity.swift
//  CalrAIMacrosWidget
//
//  Created by Ciaran Liddy on 04/02/2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct CalrAIMacrosWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct CalrAIMacrosWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CalrAIMacrosWidgetAttributes.self) { context in
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

extension CalrAIMacrosWidgetAttributes {
    fileprivate static var preview: CalrAIMacrosWidgetAttributes {
        CalrAIMacrosWidgetAttributes(name: "World")
    }
}

extension CalrAIMacrosWidgetAttributes.ContentState {
    fileprivate static var smiley: CalrAIMacrosWidgetAttributes.ContentState {
        CalrAIMacrosWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: CalrAIMacrosWidgetAttributes.ContentState {
         CalrAIMacrosWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: CalrAIMacrosWidgetAttributes.preview) {
   CalrAIMacrosWidgetLiveActivity()
} contentStates: {
    CalrAIMacrosWidgetAttributes.ContentState.smiley
    CalrAIMacrosWidgetAttributes.ContentState.starEyes
}
