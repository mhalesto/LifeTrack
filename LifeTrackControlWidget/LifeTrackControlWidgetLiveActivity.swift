//
//  LifeTrackControlWidgetLiveActivity.swift
//  LifeTrackControlWidget
//
//  Created by Halalisani Mbanjwa on 2026/04/19.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct LifeTrackControlWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct LifeTrackControlWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LifeTrackControlWidgetAttributes.self) { context in
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

extension LifeTrackControlWidgetAttributes {
    fileprivate static var preview: LifeTrackControlWidgetAttributes {
        LifeTrackControlWidgetAttributes(name: "World")
    }
}

extension LifeTrackControlWidgetAttributes.ContentState {
    fileprivate static var smiley: LifeTrackControlWidgetAttributes.ContentState {
        LifeTrackControlWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: LifeTrackControlWidgetAttributes.ContentState {
         LifeTrackControlWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: LifeTrackControlWidgetAttributes.preview) {
   LifeTrackControlWidgetLiveActivity()
} contentStates: {
    LifeTrackControlWidgetAttributes.ContentState.smiley
    LifeTrackControlWidgetAttributes.ContentState.starEyes
}
