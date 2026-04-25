//
//  LifeTrackControlWidgetLiveActivity.swift
//  LifeTrackControlWidget
//
//  Live Activity that pins a single focus task to the lock screen
//  and Dynamic Island until it is completed or manually dismissed.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct LifeTrackControlWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LifeTrackControlWidgetAttributes.self) { context in
            lockScreen(context: context)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(accent(context).opacity(0.9))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.attributes.categorySymbol)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(accent(context))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    statusChip(context: context)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                        Text(context.attributes.categoryTitle)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let summary = context.state.noteSummary, !summary.isEmpty {
                        Text(summary)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(2)
                    }
                }
            } compactLeading: {
                Image(systemName: context.attributes.categorySymbol)
                    .foregroundStyle(accent(context))
            } compactTrailing: {
                Text(relativeDue(context.state.dueDate))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(context.state.isOverdue ? Color.red : .white)
            } minimal: {
                Image(systemName: context.attributes.categorySymbol)
                    .foregroundStyle(accent(context))
            }
            .keylineTint(accent(context))
        }
    }

    private func accent(_ context: ActivityViewContext<LifeTrackControlWidgetAttributes>) -> Color {
        Color(hex: context.attributes.accentColorHex)
    }

    @ViewBuilder
    private func lockScreen(context: ActivityViewContext<LifeTrackControlWidgetAttributes>) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(accent(context).opacity(0.22))
                Image(systemName: context.attributes.categorySymbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(accent(context))
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.categoryTitle.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .tracking(0.6)
                Text(context.attributes.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                if let summary = context.state.noteSummary, !summary.isEmpty {
                    Text(summary)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)

            statusChip(context: context)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func statusChip(context: ActivityViewContext<LifeTrackControlWidgetAttributes>) -> some View {
        let label: String
        let color: Color
        if context.state.isCompleted {
            label = "Done"
            color = .green
        } else if context.state.isOverdue {
            label = "Overdue · \(relativeDue(context.state.dueDate))"
            color = .red
        } else {
            label = relativeDue(context.state.dueDate)
            color = accent(context)
        }

        return Text(label)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.18), in: Capsule())
    }

    private func relativeDue(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

private extension Color {
    init(hex: UInt, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

extension LifeTrackControlWidgetAttributes {
    fileprivate static var preview: LifeTrackControlWidgetAttributes {
        LifeTrackControlWidgetAttributes(
            taskID: "preview",
            title: "Review insurance documents",
            categoryTitle: "Finance",
            categorySymbol: "banknote",
            accentColorHex: 0x4F8CFF
        )
    }
}

extension LifeTrackControlWidgetAttributes.ContentState {
    fileprivate static var upcoming: LifeTrackControlWidgetAttributes.ContentState {
        .init(dueDate: Date().addingTimeInterval(3600), isCompleted: false, isOverdue: false, noteSummary: "Confirm renewal date")
    }

    fileprivate static var overdue: LifeTrackControlWidgetAttributes.ContentState {
        .init(dueDate: Date().addingTimeInterval(-1800), isCompleted: false, isOverdue: true, noteSummary: nil)
    }
}

#Preview("Lock Screen", as: .content, using: LifeTrackControlWidgetAttributes.preview) {
    LifeTrackControlWidgetLiveActivity()
} contentStates: {
    LifeTrackControlWidgetAttributes.ContentState.upcoming
    LifeTrackControlWidgetAttributes.ContentState.overdue
}
