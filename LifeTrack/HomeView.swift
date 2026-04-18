//
//  HomeView.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LifeTask.dueDate, order: .forward) private var tasks: [LifeTask]

    @State private var isShowingTemplatePicker = false
    @State private var isShowingTaskEditor = false
    @State private var selectedTemplate: TaskTemplate?
    @State private var editingTask: LifeTask?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                LifeTrackTheme.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.xLarge) {
                        header

                        summaryGrid

                        quickActions

                        if tasks.isEmpty {
                            EmptyStateView(
                                title: "Start with one clear next step",
                                message: "Create a task, attach important files, and LifeTrack will keep the dashboard useful from day one.",
                                actionTitle: "Create Task",
                                action: openBlankTask
                            )
                        } else {
                            prioritySection
                            recentDocumentsSection
                        }
                    }
                    .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
                    .padding(.top, LifeTrackTheme.Spacing.large)
                    .padding(.bottom, 126)
                }
                .scrollIndicators(.hidden)

                PrimaryFloatingButton {
                    isShowingTemplatePicker = true
                }
                .padding(.trailing, LifeTrackTheme.Spacing.xLarge)
                .padding(.bottom, LifeTrackTheme.Spacing.xLarge)
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $isShowingTemplatePicker) {
                TemplatePickerView(
                    onSelectBlank: openBlankTaskFromPicker,
                    onSelectTemplate: openTemplateFromPicker
                )
            }
            .sheet(isPresented: $isShowingTaskEditor) {
                NewTaskView(template: selectedTemplate)
            }
            .sheet(item: $editingTask) { task in
                NewTaskView(task: task)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.large) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(greeting)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)

                    Text(Date().weekdayDateString)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
                }

                Spacer()

                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                    .frame(width: 42, height: 42)
                    .background(LifeTrackTheme.ColorPalette.accentSoft, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.8), lineWidth: 1)
                    }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [LifeTrackTheme.ColorPalette.accent, Color(hex: 0x6B7BFF)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 10, height: 34)

                    Text("LifeTrack")
                        .font(.lifeTrackHero)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                }

                Text("A calm command center for tasks, reminders, and important documents.")
                    .font(.subheadline)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: LifeTrackTheme.Spacing.medium) {
            StatCardView(
                title: "Due Today",
                value: dueTodayTasks.count,
                subtitle: "Needs attention",
                symbolName: "sun.max",
                tint: LifeTrackTheme.ColorPalette.accent
            )

            StatCardView(
                title: "Upcoming",
                value: upcomingTasks.count,
                subtitle: "Planned ahead",
                symbolName: "calendar",
                tint: Color(hex: 0x5865B8)
            )

            StatCardView(
                title: "Completed",
                value: completedTasks.count,
                subtitle: "Finished",
                symbolName: "checkmark.seal",
                tint: LifeTrackTheme.ColorPalette.success
            )

            StatCardView(
                title: "Overdue",
                value: overdueTasks.count,
                subtitle: "Past due",
                symbolName: "exclamationmark.triangle",
                tint: LifeTrackTheme.ColorPalette.danger
            )
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.medium) {
            SectionHeaderView(title: "Quick Actions", subtitle: "Move fast without losing structure.")

            ScrollView(.horizontal) {
                HStack(spacing: LifeTrackTheme.Spacing.medium) {
                    QuickActionButton(
                        title: "New task",
                        subtitle: "Start fresh",
                        symbolName: "plus",
                        tint: LifeTrackTheme.ColorPalette.accent,
                        action: openBlankTask
                    )

                    QuickActionButton(
                        title: "Email follow-up",
                        subtitle: "Use template",
                        symbolName: "envelope.badge",
                        tint: TaskCategory.work.style.tint,
                        action: {
                            selectedTemplate = TaskTemplate.common.first { $0.id == "email" }
                            isShowingTaskEditor = true
                        }
                    )

                    QuickActionButton(
                        title: "Templates",
                        subtitle: "Smart shortcuts",
                        symbolName: "sparkles",
                        tint: Color(hex: 0x7B61D1),
                        action: { isShowingTemplatePicker = true }
                    )
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.medium) {
            SectionHeaderView(
                title: "Today's Focus",
                subtitle: "The highest-signal tasks right now.",
                trailing: "\(priorityTasks.count)"
            )

            if priorityTasks.isEmpty {
                SectionCardView {
                    CompactMessageView(
                        symbolName: "checkmark.circle",
                        title: "No open focus tasks",
                        message: "Everything urgent is complete. Add a task when the next priority appears."
                    )
                }
            } else {
                VStack(spacing: LifeTrackTheme.Spacing.small) {
                    ForEach(priorityTasks) { task in
                        TaskRowView(
                            task: task,
                            onToggleCompletion: { toggleCompletion(for: task) },
                            onEdit: { editingTask = task },
                            onDelete: { delete(task) }
                        )
                    }
                }
            }
        }
    }

    private var recentDocumentsSection: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.medium) {
            SectionHeaderView(
                title: "Recent Documents",
                subtitle: "Files connected to your tasks.",
                trailing: documentTasks.isEmpty ? nil : "\(documentTasks.count)"
            )

            if documentTasks.isEmpty {
                SectionCardView {
                    CompactMessageView(
                        symbolName: "doc.badge.plus",
                        title: "No documents yet",
                        message: "Attach a file from any task to keep supporting context nearby."
                    )
                }
            } else {
                VStack(spacing: LifeTrackTheme.Spacing.small) {
                    ForEach(Array(documentTasks.prefix(3))) { task in
                        NavigationLink {
                            TaskDetailView(task: task)
                        } label: {
                            RecentDocumentRow(task: task)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var dueTodayTasks: [LifeTask] {
        tasks.filter { !$0.isCompleted && Calendar.current.isDateInToday($0.dueDate) }
    }

    private var upcomingTasks: [LifeTask] {
        tasks.filter { !$0.isCompleted && $0.dueDate > Date() && !Calendar.current.isDateInToday($0.dueDate) }
    }

    private var completedTasks: [LifeTask] {
        tasks.filter(\.isCompleted)
    }

    private var overdueTasks: [LifeTask] {
        tasks.filter(\.isOverdue)
    }

    private var priorityTasks: [LifeTask] {
        Array((overdueTasks + dueTodayTasks + upcomingTasks).prefix(5))
    }

    private var documentTasks: [LifeTask] {
        tasks
            .filter(\.hasDocument)
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        default:
            return "Good evening"
        }
    }

    private func openBlankTask() {
        selectedTemplate = nil
        isShowingTaskEditor = true
    }

    private func openBlankTaskFromPicker() {
        selectedTemplate = nil
        isShowingTemplatePicker = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            isShowingTaskEditor = true
        }
    }

    private func openTemplateFromPicker(_ template: TaskTemplate) {
        selectedTemplate = template
        isShowingTemplatePicker = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            isShowingTaskEditor = true
        }
    }

    private func toggleCompletion(for task: LifeTask) {
        withAnimation(.snappy) {
            task.isCompleted.toggle()
            task.updatedAt = Date()
            try? modelContext.save()
            syncReminder(for: task)
        }
    }

    private func delete(_ task: LifeTask) {
        withAnimation(.snappy) {
            ReminderScheduler.cancel(taskID: task.id)
            DocumentStore.delete(storageName: task.documentStorageName)
            modelContext.delete(task)
            try? modelContext.save()
        }
    }

    private func syncReminder(for task: LifeTask) {
        ReminderScheduler.synchronizeReminder(
            taskID: task.id,
            title: task.title,
            categoryTitle: task.category.title,
            dueDate: task.dueDate,
            isCompleted: task.isCompleted
        )
    }
}

private struct CompactMessageView: View {
    let symbolName: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: LifeTrackTheme.Spacing.medium) {
            Image(systemName: symbolName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                .frame(width: 38, height: 38)
                .background(LifeTrackTheme.ColorPalette.accentSoft, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                Text(message)
                    .font(.footnote)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct RecentDocumentRow: View {
    let task: LifeTask

    var body: some View {
        HStack(spacing: LifeTrackTheme.Spacing.medium) {
            Image(systemName: "doc.text")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(task.category.style.tint)
                .frame(width: 42, height: 42)
                .background(task.category.style.background, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(task.documentDisplayName ?? "Document")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    .lineLimit(1)

                Text(task.title)
                    .font(.footnote)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
        }
        .padding(14)
        .background(LifeTrackTheme.ColorPalette.cardElevated, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.8), lineWidth: 0.7)
        }
    }
}

#Preview {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: LifeTask.self, configurations: configuration)

    container.mainContext.insert(
        LifeTask(
            title: "Review insurance documents",
            category: .finance,
            dueDate: Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date(),
            documentStorageName: "insurance.pdf",
            documentDisplayName: "Insurance policy.pdf"
        )
    )
    container.mainContext.insert(
        LifeTask(
            title: "Book health check",
            category: .health,
            dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        )
    )

    return HomeView()
        .modelContainer(container)
}
