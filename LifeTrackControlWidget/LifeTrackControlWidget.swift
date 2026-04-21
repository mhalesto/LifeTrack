//
//  LifeTrackControlWidget.swift
//  LifeTrackControlWidget
//
//  Created by Halalisani Mbanjwa on 2026/04/19.
//

import WidgetKit
import SwiftUI
import AppIntents

enum SharedGroup {
    static let suiteName = "group.com.currenttech.LifeTrack"
    static let snapshotKey = "widget.focusSnapshot"
}

struct FocusSnapshot: Codable {
    struct Item: Codable, Identifiable {
        let id: String
        let title: String
        let dueDate: Date
        let isOverdue: Bool
        let isDueToday: Bool
    }

    let generatedAt: Date
    let items: [Item]
    let overdueCount: Int
    let dueTodayCount: Int
    let upcomingCount: Int

    static let empty = FocusSnapshot(
        generatedAt: Date(),
        items: [],
        overdueCount: 0,
        dueTodayCount: 0,
        upcomingCount: 0
    )

    static func load() -> FocusSnapshot {
        guard let defaults = UserDefaults(suiteName: SharedGroup.suiteName),
              let data = defaults.data(forKey: SharedGroup.snapshotKey)
        else {
            return .empty
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(FocusSnapshot.self, from: data)) ?? .empty
    }
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: ConfigurationAppIntent(), snapshot: .empty)
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: configuration, snapshot: FocusSnapshot.load())
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let snapshot = FocusSnapshot.load()
        let entry = SimpleEntry(date: Date(), configuration: configuration, snapshot: snapshot)
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    let snapshot: FocusSnapshot
}

struct LifeTrackControlWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: Provider.Entry

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        default:
            mediumView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "target")
                    .font(.caption.weight(.semibold))
                Text("Today's Focus")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.tint)

            if entry.snapshot.items.isEmpty {
                Text("Nothing scheduled")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if let first = entry.snapshot.items.first {
                Text(first.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Text(dueLabel(for: first))
                    .font(.caption2)
                    .foregroundStyle(first.isOverdue ? Color.red : Color.secondary)
            }

            Spacer(minLength: 0)

            countsRow
        }
        .padding(12)
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "target")
                    .font(.footnote.weight(.semibold))
                Text("Today's Focus")
                    .font(.footnote.weight(.semibold))
                Spacer()
                countsRow
            }
            .foregroundStyle(.tint)

            if entry.snapshot.items.isEmpty {
                Text("All clear — no focus tasks yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(entry.snapshot.items.prefix(3)) { item in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: item.isOverdue ? "exclamationmark.circle.fill" : "circle")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(item.isOverdue ? Color.red : Color.secondary)
                            Text(item.title)
                                .font(.footnote.weight(.medium))
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text(dueLabel(for: item))
                                .font(.caption2)
                                .foregroundStyle(item.isOverdue ? Color.red : Color.secondary)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
    }

    private var countsRow: some View {
        HStack(spacing: 8) {
            countChip(
                count: entry.snapshot.overdueCount,
                label: "overdue",
                color: .red,
                symbol: "exclamationmark.circle.fill"
            )
            countChip(
                count: entry.snapshot.dueTodayCount,
                label: "today",
                color: .orange,
                symbol: "sun.max.fill"
            )
        }
    }

    @ViewBuilder
    private func countChip(count: Int, label: String, color: Color, symbol: String) -> some View {
        if count > 0 {
            HStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.caption2)
                Text("\(count)")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(color)
            .accessibilityLabel("\(count) \(label)")
        }
    }

    private func dueLabel(for item: FocusSnapshot.Item) -> String {
        if item.isOverdue { return "Overdue" }
        if item.isDueToday { return "Today" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: item.dueDate)
    }
}

struct LifeTrackControlWidget: Widget {
    let kind: String = "LifeTrackControlWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            LifeTrackControlWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today's Focus")
        .description("See your top LifeTrack focus tasks at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemMedium) {
    LifeTrackControlWidget()
} timeline: {
    SimpleEntry(
        date: .now,
        configuration: ConfigurationAppIntent(),
        snapshot: FocusSnapshot(
            generatedAt: .now,
            items: [
                FocusSnapshot.Item(id: "1", title: "Submit tax return", dueDate: .now.addingTimeInterval(-3600), isOverdue: true, isDueToday: false),
                FocusSnapshot.Item(id: "2", title: "Gym session", dueDate: .now.addingTimeInterval(3600), isOverdue: false, isDueToday: true),
                FocusSnapshot.Item(id: "3", title: "Call Mom", dueDate: .now.addingTimeInterval(7200), isOverdue: false, isDueToday: true)
            ],
            overdueCount: 2,
            dueTodayCount: 4,
            upcomingCount: 7
        )
    )
}
