//
//  BetaFocusedDashboardOverdueRescue.swift
//  LifeTrack
//

import SwiftUI

private enum BetaFocusedDashboardOverdueBucket: CaseIterable {
    case reschedule
    case snooze
    case someday
    case markDone
    case delete

    var title: String {
        switch self {
        case .reschedule: "Reschedule"
        case .snooze: "Snooze"
        case .someday: "Someday"
        case .markDone: "Mark Done"
        case .delete: "Delete"
        }
    }

    var subtitle: String {
        switch self {
        case .reschedule: "Recent or important tasks worth putting back on the calendar."
        case .snooze: "Tasks that can wait a few days without being forgotten."
        case .someday: "Older tasks that still matter, but do not belong in today."
        case .markDone: "Recurring items that were probably handled outside LifeTrack."
        case .delete: "Very old, low-priority tasks likely safe to move to the bin."
        }
    }

    var primaryActionTitle: String {
        switch self {
        case .reschedule: "Tomorrow"
        case .snooze: "Snooze"
        case .someday: "Someday"
        case .markDone: "Done"
        case .delete: "Delete"
        }
    }

    var symbolName: String {
        switch self {
        case .reschedule: "calendar.badge.clock"
        case .snooze: "moon.zzz.fill"
        case .someday: "tray"
        case .markDone: "checkmark.circle.fill"
        case .delete: "trash"
        }
    }

    var tint: Color {
        switch self {
        case .reschedule:
            BetaFocusedDashboardPalette.captureTint
        case .snooze:
            BetaFocusedDashboardPalette.warningTint
        case .someday:
            BetaFocusedDashboardPalette.importExportTint
        case .markDone:
            BetaFocusedDashboardPalette.completedTint
        case .delete:
            BetaFocusedDashboardPalette.overdueTint
        }
    }

    var background: Color {
        switch self {
        case .reschedule:
            BetaFocusedDashboardPalette.financeBackground
        case .snooze:
            BetaFocusedDashboardPalette.warningBackground
        case .someday:
            BetaFocusedDashboardPalette.personalBackground
        case .markDone:
            BetaFocusedDashboardPalette.workBackground
        case .delete:
            BetaFocusedDashboardPalette.dangerBackground
        }
    }

    static func recommended(for task: LifeTask, referenceDate: Date = Date(), calendar: Calendar = .current) -> BetaFocusedDashboardOverdueBucket {
        let overdueDays = max(
            calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: task.dueDate),
                to: calendar.startOfDay(for: referenceDate)
            ).day ?? 0,
            0
        )

        if task.recurrence != .none && overdueDays <= 7 {
            return .markDone
        }

        if overdueDays >= 45 && task.priority == .low {
            return .delete
        }

        if overdueDays >= 14 {
            return .someday
        }

        if overdueDays >= 3 {
            return .snooze
        }

        return .reschedule
    }
}

struct BetaFocusedDashboardOverdueRescueSheet: View {
    @Environment(\.dismiss) private var dismiss

    let tasks: [LifeTask]
    let customCategories: [CustomTaskCategory]
    let onOpenTask: (LifeTask) -> Void
    let onReschedule: (LifeTask) -> Void
    let onSnooze: (LifeTask) -> Void
    let onSomeday: (LifeTask) -> Void
    let onComplete: (LifeTask) -> Void
    let onDelete: (LifeTask) -> Void

    private var sortedTasks: [LifeTask] {
        tasks
            .filter { !$0.isDeleted && !$0.isCompleted }
            .sorted { first, second in
                if first.priority.focusScore != second.priority.focusScore {
                    return first.priority.focusScore > second.priority.focusScore
                }

                return first.dueDate < second.dueDate
            }
    }

    private var groupedTasks: [(bucket: BetaFocusedDashboardOverdueBucket, tasks: [LifeTask])] {
        BetaFocusedDashboardOverdueBucket.allCases.compactMap { bucket in
            let matches = sortedTasks.filter { BetaFocusedDashboardOverdueBucket.recommended(for: $0) == bucket }
            guard !matches.isEmpty else { return nil }
            return (bucket, matches)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BetaFocusedDashboardBackground()
                    .ignoresSafeArea()

                if sortedTasks.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            header

                            ForEach(groupedTasks, id: \.bucket) { group in
                                rescueSection(bucket: group.bucket, tasks: group.tasks)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 16)
                        .padding(.bottom, 28)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle("Overdue Rescue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(sortedTasks.count) overdue task\(sortedTasks.count == 1 ? "" : "s")")
                .font(.system(size: 24, weight: .semibold, design: .serif))
                .foregroundStyle(BetaFocusedDashboardPalette.headerText)

            Text("LifeTrack grouped the backlog by the fastest useful action. Clear a section at a time or triage one task.")
                .font(BetaFocusedDashboardTypography.body)
                .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(BetaFocusedDashboardPalette.completedTint)

            Text("Backlog rescued")
                .font(.system(size: 24, weight: .semibold, design: .serif))
                .foregroundStyle(BetaFocusedDashboardPalette.headerText)

            Text("No overdue tasks need cleanup right now.")
                .font(BetaFocusedDashboardTypography.body)
                .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 28)
    }

    private func rescueSection(bucket: BetaFocusedDashboardOverdueBucket, tasks: [LifeTask]) -> some View {
        BetaFocusedDashboardCard(background: BetaFocusedDashboardPalette.cardSecondary) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: bucket.symbolName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(bucket.tint)
                        .frame(width: 30, height: 30)
                        .background(bucket.background, in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(bucket.title) · \(tasks.count)")
                            .font(BetaFocusedDashboardTypography.section)
                            .foregroundStyle(BetaFocusedDashboardPalette.headerText)

                        Text(bucket.subtitle)
                            .font(BetaFocusedDashboardTypography.bodySmall)
                            .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            tasks.forEach { apply(bucket, to: $0) }
                        }
                    } label: {
                        Text("Apply")
                            .font(BetaFocusedDashboardTypography.bodySmall.weight(.semibold))
                            .foregroundStyle(bucket.tint)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(bucket.background, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                VStack(spacing: 0) {
                    ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                        BetaFocusedDashboardRescueTaskRow(
                            task: task,
                            categoryOption: task.categoryOption(customCategories: customCategories),
                            bucket: bucket,
                            onOpen: { onOpenTask(task) },
                            onPrimaryAction: { apply(bucket, to: task) },
                            onReschedule: { onReschedule(task) },
                            onSnooze: { onSnooze(task) },
                            onSomeday: { onSomeday(task) },
                            onComplete: { onComplete(task) },
                            onDelete: { onDelete(task) }
                        )

                        if index < tasks.count - 1 {
                            Divider()
                                .overlay(BetaFocusedDashboardPalette.border)
                                .padding(.leading, 48)
                        }
                    }
                }
            }
        }
    }

    private func apply(_ bucket: BetaFocusedDashboardOverdueBucket, to task: LifeTask) {
        switch bucket {
        case .reschedule:
            onReschedule(task)
        case .snooze:
            onSnooze(task)
        case .someday:
            onSomeday(task)
        case .markDone:
            onComplete(task)
        case .delete:
            onDelete(task)
        }
    }
}

private struct BetaFocusedDashboardRescueTaskRow: View {
    let task: LifeTask
    let categoryOption: TaskCategoryOption
    let bucket: BetaFocusedDashboardOverdueBucket
    let onOpen: () -> Void
    let onPrimaryAction: () -> Void
    let onReschedule: () -> Void
    let onSnooze: () -> Void
    let onSomeday: () -> Void
    let onComplete: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(categoryOption.background)
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: categoryOption.symbolName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(categoryOption.tint)
                }

            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(BetaFocusedDashboardTypography.taskTitle)
                        .foregroundStyle(BetaFocusedDashboardPalette.headerText)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    HStack(spacing: 6) {
                        Text(overdueLabel)
                            .font(BetaFocusedDashboardTypography.bodySmall)
                            .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)

                        BetaFocusedDashboardCategoryChip(
                            title: categoryOption.title,
                            tint: categoryOption.tint,
                            background: categoryOption.background
                        )

                        if let healthState = task.betaFocusedHealthState() {
                            BetaFocusedDashboardHealthChip(state: healthState)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button(action: onPrimaryAction) {
                Text(bucket.primaryActionTitle)
                    .font(BetaFocusedDashboardTypography.bodySmall.weight(.semibold))
                    .foregroundStyle(bucket.tint)
                    .lineLimit(1)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .background(bucket.background, in: Capsule())
            }
            .buttonStyle(.plain)

            Menu {
                Button("Reschedule tomorrow", systemImage: "calendar.badge.clock", action: onReschedule)
                Button("Snooze 3 days", systemImage: "moon.zzz.fill", action: onSnooze)
                Button("Move to someday", systemImage: "tray", action: onSomeday)
                Button("Mark done", systemImage: "checkmark.circle.fill", action: onComplete)
                Button("Move to bin", systemImage: "trash", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }

    private var overdueLabel: String {
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: task.dueDate),
            to: Calendar.current.startOfDay(for: Date())
        ).day ?? 0

        if days <= 0 {
            return "Overdue today"
        }

        return days == 1 ? "1 day overdue" : "\(days) days overdue"
    }
}
