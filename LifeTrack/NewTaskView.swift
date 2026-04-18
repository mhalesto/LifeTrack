//
//  NewTaskView.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct NewTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let existingTask: LifeTask?
    private let originalDocumentStorageName: String?

    @State private var title: String
    @State private var category: TaskCategory
    @State private var dueDate: Date
    @State private var isCompleted: Bool
    @State private var notes: String
    @State private var templateAction: TaskTemplateAction
    @State private var documentStorageName: String?
    @State private var documentDisplayName: String?
    @State private var isImportingDocument = false
    @State private var documentError: String?
    @State private var didSave = false

    init(task: LifeTask? = nil, template: TaskTemplate? = nil) {
        existingTask = task
        originalDocumentStorageName = task?.documentStorageName

        let template = template
        _title = State(initialValue: task?.title ?? template?.title ?? "")
        _category = State(initialValue: task?.category ?? template?.category ?? .personal)
        _dueDate = State(initialValue: task?.dueDate ?? template?.dueDate ?? Date())
        _isCompleted = State(initialValue: task?.isCompleted ?? false)
        _notes = State(initialValue: task?.notes ?? template?.notes ?? "")
        _templateAction = State(initialValue: task?.templateAction ?? template?.action ?? .none)
        _documentStorageName = State(initialValue: task?.documentStorageName)
        _documentDisplayName = State(initialValue: task?.documentDisplayName)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LifeTrackTheme.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.xLarge) {
                        header

                        taskCard

                        dateCard

                        notesCard

                        documentCard

                        if templateAction == .email {
                            templateActionCard
                        }

                        if existingTask != nil {
                            statusCard
                        }
                    }
                    .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
                    .padding(.top, LifeTrackTheme.Spacing.large)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .fileImporter(
                isPresented: $isImportingDocument,
                allowedContentTypes: [.item],
                allowsMultipleSelection: false,
                onCompletion: handleDocumentImport
            )
            .onDisappear {
                if !didSave && documentStorageName != originalDocumentStorageName {
                    DocumentStore.delete(storageName: documentStorageName)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(existingTask == nil ? "New Task" : "Edit Task")
                .font(.lifeTrackHero)
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

            Text(existingTask == nil ? "Capture the next step with enough context to act on it." : "Refine the details and keep reminders accurate.")
                .font(.subheadline)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var taskCard: some View {
        SectionCardView {
            SectionHeaderView(title: "Task Details", subtitle: "Name it clearly and classify it.")

            VStack(alignment: .leading, spacing: 8) {
                Text("Title")
                    .font(.lifeTrackCaption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)

                TextField("e.g. Send quarterly insurance update", text: $title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    .textInputAutocapitalization(.sentences)
                    .padding(14)
                    .background(LifeTrackTheme.ColorPalette.backgroundTop, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                            .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.9), lineWidth: 0.8)
                    }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Category")
                    .font(.lifeTrackCaption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)

                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(TaskCategory.allCases) { option in
                            Button {
                                category = option
                            } label: {
                                CategoryChipView(category: option, isSelected: category == option)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private var dateCard: some View {
        SectionCardView {
            SectionHeaderView(title: "Due Date", subtitle: "LifeTrack will schedule a reminder.")

            HStack(spacing: LifeTrackTheme.Spacing.medium) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                    .frame(width: 44, height: 44)
                    .background(LifeTrackTheme.ColorPalette.accentSoft, in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(dueDate.weekdayDateString)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                    Text(dueDate.timeString)
                        .font(.footnote)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }

                Spacer()

                DatePicker("", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
            }
            .padding(12)
            .background(LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.85), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                    .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.85), lineWidth: 0.8)
            }
        }
    }

    private var notesCard: some View {
        SectionCardView {
            SectionHeaderView(title: "Notes", subtitle: "Add context, links, or draft text.")

            ZStack(alignment: .topLeading) {
                TextEditor(text: $notes)
                    .font(.body)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    .frame(minHeight: 148)
                    .scrollContentBackground(.hidden)
                    .padding(10)

                if notes.isEmpty {
                    Text("Write the details that will make this task easier later...")
                        .font(.body)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }
            }
            .background(LifeTrackTheme.ColorPalette.backgroundTop, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                    .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.9), lineWidth: 0.8)
            }
        }
    }

    private var documentCard: some View {
        SectionCardView {
            SectionHeaderView(title: "Document", subtitle: "Attach a file stored locally with this task.")

            AttachmentButton(
                documentDisplayName: documentDisplayName,
                onAttach: { isImportingDocument = true },
                onRemove: documentDisplayName == nil ? nil : { removeDocument() }
            )

            if let documentError {
                Text(documentError)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.danger)
            }
        }
    }

    private var templateActionCard: some View {
        SectionCardView {
            SectionHeaderView(title: "Template Action", subtitle: "This shortcut stays attached to the task.")

            HStack(spacing: LifeTrackTheme.Spacing.medium) {
                Image(systemName: "envelope.badge")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                    .frame(width: 42, height: 42)
                    .background(LifeTrackTheme.ColorPalette.accentSoft, in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("Email draft")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                    Text("Open a pre-filled email from the task detail screen.")
                        .font(.footnote)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }
            }
        }
    }

    private var statusCard: some View {
        SectionCardView {
            Toggle(isOn: $isCompleted) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Completed")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                    Text("Completed tasks will not schedule reminders.")
                        .font(.footnote)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }
            }
            .tint(LifeTrackTheme.ColorPalette.success)
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func removeDocument() {
        if documentStorageName != originalDocumentStorageName {
            DocumentStore.delete(storageName: documentStorageName)
        }
        documentStorageName = nil
        documentDisplayName = nil
    }

    private func handleDocumentImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                return
            }

            do {
                let pendingDocumentStorageName = documentStorageName
                let storedDocument = try DocumentStore.saveSecurityScopedFile(from: url)
                if pendingDocumentStorageName != originalDocumentStorageName {
                    DocumentStore.delete(storageName: pendingDocumentStorageName)
                }
                documentStorageName = storedDocument.storageName
                documentDisplayName = storedDocument.displayName
                documentError = nil
            } catch {
                documentError = "Document could not be attached."
            }
        case .failure:
            documentError = "Document could not be attached."
        }
    }

    private func save() {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let now = Date()

        let task: LifeTask
        if let existingTask {
            task = existingTask
            if originalDocumentStorageName != documentStorageName {
                DocumentStore.delete(storageName: originalDocumentStorageName)
            }
            task.title = cleanedTitle
            task.category = category
            task.dueDate = dueDate
            task.isCompleted = isCompleted
            task.notes = notes
            task.templateAction = templateAction
            task.documentStorageName = documentStorageName
            task.documentDisplayName = documentDisplayName
            task.updatedAt = now
        } else {
            task = LifeTask(
                title: cleanedTitle,
                category: category,
                dueDate: dueDate,
                isCompleted: isCompleted,
                notes: notes,
                templateAction: templateAction,
                documentStorageName: documentStorageName,
                documentDisplayName: documentDisplayName,
                createdAt: now,
                updatedAt: now
            )
            modelContext.insert(task)
        }

        try? modelContext.save()
        ReminderScheduler.synchronizeReminder(
            taskID: task.id,
            title: task.title,
            categoryTitle: task.category.title,
            dueDate: task.dueDate,
            isCompleted: task.isCompleted
        )
        didSave = true
        dismiss()
    }
}

#Preview("New Task") {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: LifeTask.self, configurations: configuration)

    return NewTaskView(template: TaskTemplate.common.first)
        .modelContainer(container)
}
