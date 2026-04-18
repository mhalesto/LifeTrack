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
    @Query(sort: \CustomTaskCategory.title) private var customCategories: [CustomTaskCategory]

    @StateObject private var voiceInput = VoiceTaskInputManager()

    private let existingTask: LifeTask?
    private let originalDocumentStorageName: String?

    @State private var title: String
    @State private var categoryRawValue: String
    @State private var dueDate: Date
    @State private var isCompleted: Bool
    @State private var notes: String
    @State private var templateAction: TaskTemplateAction
    @State private var documentStorageName: String?
    @State private var documentDisplayName: String?
    @State private var isImportingDocument = false
    @State private var isShowingCategoryManager = false
    @State private var pendingCategoryOption: TaskCategoryOption?
    @State private var documentError: String?
    @State private var didSave = false
    @State private var voiceTranscript = ""
    @State private var lastVoiceGeneratedTitle = ""
    @State private var didApplyVoiceCategory = false
    @State private var didApplyVoiceDueDate = false

    init(task: LifeTask? = nil, template: TaskTemplate? = nil) {
        existingTask = task
        originalDocumentStorageName = task?.documentStorageName

        let template = template
        _title = State(initialValue: task?.title ?? template?.title ?? "")
        _categoryRawValue = State(initialValue: task?.categoryRawValue ?? template?.category.rawValue ?? TaskCategory.personal.rawValue)
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
                    VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.large) {
                        header

                        voiceCard

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
                    .padding(.top, LifeTrackTheme.Spacing.medium)
                    .padding(.bottom, 30)
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
            .sheet(isPresented: $isShowingCategoryManager) {
                CategoryManagerView { option in
                    categoryRawValue = option.id
                    pendingCategoryOption = option
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .onDisappear {
                voiceInput.stopRecording()

                if !didSave && documentStorageName != originalDocumentStorageName {
                    DocumentStore.delete(storageName: documentStorageName)
                }
            }
            .onChange(of: voiceInput.transcript) { _, newTranscript in
                voiceTranscript = newTranscript
                applyVoiceTranscript(newTranscript)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(existingTask == nil ? "New Task" : "Edit Task")
                .font(.system(.title, design: LifeTrackAppTheme.current.fontDesign, weight: .bold))
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

            VStack(alignment: .leading, spacing: 7) {
                Text("Title")
                    .font(.lifeTrackCaption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)

                ZStack(alignment: .leading) {
                    if title.isEmpty {
                        Text("e.g. Send quarterly insurance update")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.placeholderText)
                            .padding(.horizontal, 14)
                            .allowsHitTesting(false)
                    }

                    TextField("", text: $title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                        .textInputAutocapitalization(.sentences)
                        .padding(13)
                }
                .background(LifeTrackTheme.ColorPalette.backgroundTop, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                        .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.9), lineWidth: 0.8)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Category")
                    .font(.lifeTrackCaption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 92), spacing: 8, alignment: .leading)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(categoryOptions) { option in
                        Button {
                            categoryRawValue = option.id
                            pendingCategoryOption = nil
                        } label: {
                            CategoryChipView(option: option, isSelected: categoryRawValue == option.id)
                        }
                        .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.95, pressedOpacity: 0.92))
                    }
                }

                Button {
                    isShowingCategoryManager = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                        Text("Custom category")
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(LifeTrackTheme.ColorPalette.accentSoft, in: Capsule())
                }
                .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.96))
            }
        }
    }

    private var voiceCard: some View {
        VoiceInputCard(
            transcript: $voiceTranscript,
            isRecording: voiceInput.isRecording,
            audioLevel: voiceInput.audioLevel,
            feedbackMessage: voiceInput.feedbackMessage,
            authorizationMessage: voiceInput.authorizationMessage,
            onToggleRecording: { voiceInput.toggleRecording() },
            onApplyTranscript: { applyVoiceTranscript(voiceTranscript, force: true) },
            onClearTranscript: {
                voiceInput.clearTranscript()
                voiceTranscript = ""
            }
        )
    }

    private var dateCard: some View {
        SectionCardView {
            SectionHeaderView(title: "Due Date", subtitle: "LifeTrack will schedule a reminder.")

            VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.medium) {
                HStack(spacing: LifeTrackTheme.Spacing.medium) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                        .frame(width: LifeTrackTheme.IconSize.largeCircle, height: LifeTrackTheme.IconSize.largeCircle)
                        .background(LifeTrackTheme.ColorPalette.accentSoft, in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text(dueDate.weekdayDateString)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        Text(dueDate.timeString)
                            .font(.footnote)
                            .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }

                VStack(spacing: 0) {
                    DatePickerRow(title: "Date") {
                        DatePicker("", selection: $dueDate, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .tint(LifeTrackTheme.ColorPalette.accent)
                            .fixedSize()
                    }

                    Divider()
                        .padding(.leading, 54)

                    DatePickerRow(title: "Time") {
                        DatePicker("", selection: $dueDate, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .tint(LifeTrackTheme.ColorPalette.accent)
                            .fixedSize()
                    }
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 4)
                .background(LifeTrackTheme.ColorPalette.cardElevated.opacity(0.75), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
            }
            .padding(11)
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
                    .frame(minHeight: 126)
                    .scrollContentBackground(.hidden)
                    .padding(9)

                if notes.isEmpty {
                    Text("Write the details that will make this task easier later...")
                        .font(.body)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.placeholderText)
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
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                    .frame(width: LifeTrackTheme.IconSize.largeCircle, height: LifeTrackTheme.IconSize.largeCircle)
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

    private var categoryOptions: [TaskCategoryOption] {
        TaskCategoryOption.all(customCategories: customCategories)
    }

    private var selectedCategoryOption: TaskCategoryOption {
        if let pendingCategoryOption, pendingCategoryOption.id == categoryRawValue {
            return pendingCategoryOption
        }

        return TaskCategoryOption.resolved(rawValue: categoryRawValue, customCategories: customCategories)
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

    private func applyVoiceTranscript(_ transcript: String, force: Bool = false) {
        let cleanedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTranscript.isEmpty else {
            return
        }

        let draft = VoiceTaskParser.parse(cleanedTranscript)

        if let draftTitle = draft.title, force || title.isEmpty || title == lastVoiceGeneratedTitle {
            title = draftTitle
            lastVoiceGeneratedTitle = draftTitle
        }

        if let draftCategory = draft.category, force || !didApplyVoiceCategory {
            categoryRawValue = draftCategory.rawValue
            pendingCategoryOption = nil
            didApplyVoiceCategory = true
        }

        if let draftDueDate = draft.dueDate, force || !didApplyVoiceDueDate {
            dueDate = draftDueDate
            didApplyVoiceDueDate = true
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
            task.categoryRawValue = categoryRawValue
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
                category: selectedCategory,
                categoryRawValue: categoryRawValue,
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
            categoryTitle: selectedCategoryOption.title,
            dueDate: task.dueDate,
            isCompleted: task.isCompleted
        )
        didSave = true
        dismiss()
    }

    private var selectedCategory: TaskCategory {
        TaskCategory(rawValue: categoryRawValue) ?? .other
    }
}

private struct DatePickerRow<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: LifeTrackTheme.Spacing.medium) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

            Spacer(minLength: LifeTrackTheme.Spacing.medium)

            content
        }
        .frame(minHeight: 44)
    }
}

#Preview("New Task") {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: LifeTask.self, CustomTaskCategory.self, configurations: configuration)

    return NewTaskView(template: TaskTemplate.common.first)
        .modelContainer(container)
}
