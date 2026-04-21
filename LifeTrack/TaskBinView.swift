//
//  TaskBinView.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import SwiftData
import SwiftUI

struct TaskBinView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LifeTask.updatedAt, order: .reverse) private var tasks: [LifeTask]
    @Query(sort: \CustomTaskCategory.title) private var customCategories: [CustomTaskCategory]

    @AppStorage(LifeTrackSettings.Keys.binRetentionPeriod) private var binRetentionRawValue = TaskBinRetentionPeriod.fallback.rawValue
    @AppStorage(LifeTrackSettings.Keys.animationsEnabled) private var animationsEnabled = true

    @State private var isConfirmingDeleteAll = false
    @State private var restoredToastState: TaskRestoredToastState?

    var body: some View {
        ZStack {
            LifeTrackTheme.appBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.large) {
                    header
                    policyCard
                    taskSection
                }
                .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
                .padding(.top, LifeTrackTheme.Spacing.medium)
                .padding(.bottom, LifeTrackTheme.Spacing.xxLarge)
            }
            .scrollIndicators(.hidden)
        }
        .overlay {
            if isConfirmingDeleteAll {
                LifeTrackConfirmationOverlay(
                    symbolName: "trash.fill",
                    title: "Delete all forever?",
                    message: "This will permanently remove every task in the Bin, including attached documents. This cannot be undone.",
                    confirmTitle: "Delete Forever",
                    cancelTitle: "Cancel",
                    tint: LifeTrackTheme.ColorPalette.danger,
                    isDestructive: true,
                    onConfirm: deleteAllForever,
                    onCancel: { isConfirmingDeleteAll = false }
                )
            }
        }
        .overlay(alignment: .bottom) {
            if let restoredToastState {
                TaskRestoredToast(
                    taskTitle: restoredToastState.taskTitle,
                    onDismiss: { dismissRestoredToast(id: restoredToastState.id) }
                )
                .task(id: restoredToastState.id) {
                    try? await Task.sleep(nanoseconds: 2_400_000_000)
                    await MainActor.run {
                        dismissRestoredToast(id: restoredToastState.id)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: purgeExpiredItems)
        .onChange(of: binRetentionRawValue) { _, _ in
            purgeExpiredItems()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Bin")
                .font(.lifeTrackHero)
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

            Text("Deleted tasks stay here temporarily with their documents, notes, and schedule details intact.")
                .font(.subheadline)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var policyCard: some View {
        SectionCardView {
            HStack(alignment: .top, spacing: LifeTrackTheme.Spacing.medium) {
                Image(systemName: retentionPeriod == .immediately ? "trash.slash" : "clock.arrow.circlepath")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                    .frame(width: LifeTrackTheme.IconSize.largeCircle, height: LifeTrackTheme.IconSize.largeCircle)
                    .background(LifeTrackTheme.ColorPalette.accentSoft, in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("Auto-delete: \(retentionPeriod.title)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                    Text(policyDescription)
                        .font(.footnote)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: LifeTrackTheme.Spacing.small)

                if !deletedTasks.isEmpty {
                    Button {
                        isConfirmingDeleteAll = true
                    } label: {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.danger)
                            .frame(width: 34, height: 34)
                            .background(LifeTrackTheme.ColorPalette.danger.opacity(0.10), in: Circle())
                    }
                    .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.92))
                    .accessibilityLabel("Delete all forever")
                }
            }
        }
    }

    private var taskSection: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.large) {
            if deletedTasks.isEmpty {
                SectionHeaderView(
                    title: "Deleted Tasks",
                    trailing: nil,
                    infoMessage: "Restoring a task returns it to the dashboard and recreates a reminder if its due date is still in the future."
                )

                SectionCardView {
                    HStack(alignment: .top, spacing: LifeTrackTheme.Spacing.medium) {
                        Image(systemName: "trash")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                            .frame(width: LifeTrackTheme.IconSize.largeCircle, height: LifeTrackTheme.IconSize.largeCircle)
                            .background(LifeTrackTheme.ColorPalette.backgroundTop, in: Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Bin is empty")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                            Text("Deleted and auto-archived tasks will appear here unless your Bin setting is set to Immediately.")
                                .font(.footnote)
                                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            } else {
                if !userDeletedTasks.isEmpty {
                    binGroup(
                        title: "Deleted",
                        infoMessage: "Tasks you removed from the dashboard. Restore them to return to your active lists.",
                        items: userDeletedTasks
                    )
                }

                if !archivedTasks.isEmpty {
                    binGroup(
                        title: "Archived",
                        infoMessage: "Completed tasks automatically archived based on your Keep Completed setting. Restore to bring them back to the dashboard.",
                        items: archivedTasks
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func binGroup(title: String, infoMessage: String, items: [LifeTask]) -> some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.small) {
            SectionHeaderView(
                title: title,
                trailing: items.count.formatted(),
                infoMessage: infoMessage
            )

            VStack(spacing: LifeTrackTheme.Spacing.small) {
                ForEach(items) { task in
                    TaskBinRow(
                        task: task,
                        categoryOption: task.categoryOption(customCategories: customCategories),
                        expiresAt: task.deletedAt.map(retentionPeriod.expirationDate(from:)),
                        onRestore: { restore(task) },
                        onDeleteForever: { deleteForever(task) }
                    )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .scale(scale: 0.98))
                    ))
                }
            }
            .animation(animationsEnabled ? .snappy(duration: 0.22) : nil, value: items.map(\.id))
        }
    }

    private var deletedTasks: [LifeTask] {
        tasks
            .filter(\.isDeleted)
            .sorted { first, second in
                (first.deletedAt ?? first.updatedAt) > (second.deletedAt ?? second.updatedAt)
            }
    }

    private var archivedTasks: [LifeTask] {
        deletedTasks.filter { $0.completedAt != nil }
    }

    private var userDeletedTasks: [LifeTask] {
        deletedTasks.filter { $0.completedAt == nil }
    }

    private var retentionPeriod: TaskBinRetentionPeriod {
        TaskBinRetentionPeriod(rawValue: binRetentionRawValue) ?? .fallback
    }

    private var policyDescription: String {
        if retentionPeriod == .immediately {
            return "Tasks are deleted forever as soon as you delete them. Existing Bin items are also cleared."
        }

        return "Tasks in the Bin are permanently removed \(retentionPeriod.title.lowercased()) after deletion."
    }

    private func restore(_ task: LifeTask) {
        let taskTitle = task.title
        LifeTrackHaptics.lightImpact()
        performWithOptionalAnimation {
            TaskLifecycleManager.restore(
                task,
                in: modelContext,
                customCategories: customCategories
            )
        }
        showRestoredToast(taskTitle: taskTitle)
    }

    private func deleteForever(_ task: LifeTask) {
        LifeTrackHaptics.lightImpact()
        performWithOptionalAnimation {
            TaskLifecycleManager.permanentlyDelete(task, in: modelContext)
        }
    }

    private func deleteAllForever() {
        isConfirmingDeleteAll = false
        LifeTrackHaptics.lightImpact()
        performWithOptionalAnimation {
            for task in deletedTasks {
                TaskLifecycleManager.permanentlyDelete(task, in: modelContext)
            }
        }
    }

    private func purgeExpiredItems() {
        TaskLifecycleManager.purgeExpiredBinItems(
            from: tasks,
            in: modelContext,
            retentionPeriod: retentionPeriod
        )
    }

    private func performWithOptionalAnimation(_ updates: () -> Void) {
        guard animationsEnabled else {
            updates()
            return
        }

        withAnimation(.snappy) {
            updates()
        }
    }

    private func showRestoredToast(taskTitle: String) {
        let toastState = TaskRestoredToastState(taskTitle: taskTitle)

        guard animationsEnabled else {
            restoredToastState = toastState
            return
        }

        withAnimation(.snappy(duration: 0.2)) {
            restoredToastState = toastState
        }
    }

    private func dismissRestoredToast(id: UUID?) {
        guard id == nil || restoredToastState?.id == id else {
            return
        }

        guard animationsEnabled else {
            restoredToastState = nil
            return
        }

        withAnimation(.snappy(duration: 0.18)) {
            restoredToastState = nil
        }
    }
}

private struct TaskBinRow: View {
    let task: LifeTask
    let categoryOption: TaskCategoryOption
    let expiresAt: Date?
    let onRestore: () -> Void
    let onDeleteForever: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.small) {
            HStack(alignment: .top, spacing: LifeTrackTheme.Spacing.medium) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle.dotted")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(statusTint)
                    .frame(width: LifeTrackTheme.IconSize.largeCircle, height: LifeTrackTheme.IconSize.largeCircle)
                    .background(statusTint.opacity(0.11), in: Circle())

                VStack(alignment: .leading, spacing: 6) {
                    Text(task.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                        .lineLimit(2)

                    HStack(spacing: 7) {
                        CategoryChipView(option: categoryOption)

                        StatusPillView(
                            title: task.dueDate.dayMonthString,
                            symbolName: "calendar",
                            tint: LifeTrackTheme.ColorPalette.secondaryText
                        )

                        if task.hasDocument {
                            StatusPillView(
                                title: "File",
                                symbolName: "paperclip",
                                tint: LifeTrackTheme.ColorPalette.secondaryAccent
                            )
                        }
                    }
                }

                Spacer(minLength: LifeTrackTheme.Spacing.small)

                Menu {
                    Button(role: .destructive, action: onDeleteForever) {
                        Label("Delete Forever", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .frame(width: 32, height: 32)
                        .background(LifeTrackTheme.ColorPalette.backgroundTop, in: Circle())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: LifeTrackTheme.Spacing.small) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(deletedText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)

                    Text(expirationText)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
                }

                Spacer(minLength: LifeTrackTheme.Spacing.small)

                Button(action: onRestore) {
                    Label("Restore", systemImage: "arrow.uturn.left")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .background(LifeTrackTheme.ColorPalette.accentGradient, in: Capsule())
                }
                .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.96, pressedOpacity: 0.92))
            }
        }
        .padding(12)
        .background(LifeTrackTheme.ColorPalette.cardElevated, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.8), lineWidth: 0.7)
        }
    }

    private var statusTint: Color {
        task.isCompleted ? LifeTrackTheme.ColorPalette.success : LifeTrackTheme.ColorPalette.secondaryText
    }

    private var deletedText: String {
        guard let deletedAt = task.deletedAt else {
            return "Moved to Bin"
        }

        return "Deleted \(deletedAt.dayMonthString) at \(deletedAt.timeString)"
    }

    private var expirationText: String {
        guard let expiresAt else {
            return "Expires based on your Bin setting"
        }

        if expiresAt <= Date() {
            return "Expires now"
        }

        return "Expires \(expiresAt.dayMonthString) at \(expiresAt.timeString)"
    }
}

#Preview {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: LifeTask.self, CustomTaskCategory.self, configurations: configuration)
    let task = LifeTask(
        title: "Review insurance renewal",
        category: .finance,
        dueDate: Date(),
        documentStorageName: "insurance.pdf",
        documentDisplayName: "Insurance.pdf",
        deletedAt: Date()
    )
    container.mainContext.insert(task)

    return NavigationStack {
        TaskBinView()
    }
    .modelContainer(container)
}
