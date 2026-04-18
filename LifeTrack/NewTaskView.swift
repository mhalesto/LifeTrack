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
    @State private var priority: TaskPriority
    @State private var recurrence: TaskRecurrence
    @State private var durationMinutes: Int
    @State private var documentStorageName: String?
    @State private var documentDisplayName: String?
    @State private var documentExtractedText: String
    @State private var documentAnalysisSummary: String?
    @State private var documentSuggestedTitle: String?
    @State private var documentSuggestedDueDate: Date?
    @State private var documentKeywords: [String]
    @State private var isImportingDocument = false
    @State private var isAnalyzingDocument = false
    @State private var isShowingCategoryManager = false
    @State private var pendingCategoryOption: TaskCategoryOption?
    @State private var documentError: String?
    @State private var didSave = false
    @State private var voiceTranscript = ""
    @State private var lastVoiceGeneratedTitle = ""
    @State private var didApplyVoiceCategory = false
    @State private var didApplyVoiceDueDate = false

    private let durationOptions = [15, 30, 45, 60, 90, 120]

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
        _priority = State(initialValue: task?.priority ?? template?.priority ?? .normal)
        _recurrence = State(initialValue: task?.recurrence ?? template?.recurrence ?? .none)
        _durationMinutes = State(initialValue: task?.scheduledDurationMinutes ?? template?.estimatedDurationMinutes ?? 30)
        _documentStorageName = State(initialValue: task?.documentStorageName)
        _documentDisplayName = State(initialValue: task?.documentDisplayName)
        _documentExtractedText = State(initialValue: task?.documentExtractedText ?? "")
        _documentAnalysisSummary = State(initialValue: task?.documentAnalysisSummary)
        _documentSuggestedTitle = State(initialValue: task?.documentSuggestedTitle)
        _documentSuggestedDueDate = State(initialValue: task?.documentSuggestedDueDate)
        _documentKeywords = State(initialValue: task?.documentKeywords ?? [])
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

                        planningCard

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

    private var planningCard: some View {
        SectionCardView {
            SectionHeaderView(title: "Planning", subtitle: "Help LifeTrack choose what matters today.")

            VStack(alignment: .leading, spacing: 8) {
                Text("Priority")
                    .font(.lifeTrackCaption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)

                HStack(spacing: 8) {
                    ForEach(TaskPriority.allCases) { option in
                        Button {
                            priority = option
                        } label: {
                            PriorityPillView(priority: option, isSelected: priority == option)
                        }
                        .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.95, pressedOpacity: 0.92))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Repeat")
                    .font(.lifeTrackCaption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 92), spacing: 8, alignment: .leading)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(TaskRecurrence.allCases) { option in
                        Button {
                            recurrence = option
                        } label: {
                            RecurrencePillView(recurrence: option, isSelected: recurrence == option)
                        }
                        .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.95, pressedOpacity: 0.92))
                    }
                }
            }
        }
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

                durationSelector
            }
            .padding(11)
            .background(LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.85), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                    .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.85), lineWidth: 0.8)
            }
        }
    }

    private var durationSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: LifeTrackTheme.Spacing.small) {
                Image(systemName: "timer")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.accent)

                Text("Duration")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                Spacer(minLength: 0)

                Text(durationTitle(for: durationMinutes))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 70), spacing: 8, alignment: .leading)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(durationOptions, id: \.self) { option in
                    Button {
                        durationMinutes = option
                    } label: {
                        Text(durationTitle(for: option))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(durationMinutes == option ? .white : LifeTrackTheme.ColorPalette.secondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(durationChipBackground(isSelected: durationMinutes == option), in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(durationMinutes == option ? Color.white.opacity(0.22) : LifeTrackTheme.ColorPalette.hairline.opacity(0.82), lineWidth: 0.8)
                            }
                    }
                    .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.95, pressedOpacity: 0.92))
                }
            }
        }
        .padding(11)
        .background(LifeTrackTheme.ColorPalette.cardElevated.opacity(0.66), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
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

            if isAnalyzingDocument {
                HStack(spacing: LifeTrackTheme.Spacing.small) {
                    ProgressView()
                        .tint(LifeTrackTheme.ColorPalette.accent)

                    Text("Reading document locally...")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }
                .padding(11)
                .background(LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.86), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
            } else if hasDocumentAnalysis {
                DocumentIntelligenceView(
                    summary: documentAnalysisSummary,
                    suggestedTitle: documentSuggestedTitle,
                    suggestedDueDate: documentSuggestedDueDate,
                    keywords: documentKeywords,
                    extractedText: documentExtractedText,
                    onApplySuggestion: applyDocumentSuggestion
                )
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
        clearDocumentAnalysis()
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
                analyzeDocument(storageName: storedDocument.storageName, displayName: storedDocument.displayName)
            } catch {
                documentError = "Document could not be attached."
                isAnalyzingDocument = false
            }
        case .failure:
            documentError = "Document could not be attached."
            isAnalyzingDocument = false
        }
    }

    private func analyzeDocument(storageName: String, displayName: String) {
        guard let url = DocumentStore.url(for: storageName) else {
            clearDocumentAnalysis()
            documentError = "Document was attached, but could not be read yet."
            return
        }

        clearDocumentAnalysis()
        isAnalyzingDocument = true

        Task {
            let result = await DocumentAnalysisManager.analyze(url: url, displayName: displayName)
            await MainActor.run {
                guard documentStorageName == storageName else {
                    return
                }

                documentExtractedText = result.extractedText
                documentAnalysisSummary = result.summary
                documentSuggestedTitle = result.suggestedTitle
                documentSuggestedDueDate = result.suggestedDueDate
                documentKeywords = result.keywords
                isAnalyzingDocument = false
            }
        }
    }

    private func clearDocumentAnalysis() {
        documentExtractedText = ""
        documentAnalysisSummary = nil
        documentSuggestedTitle = nil
        documentSuggestedDueDate = nil
        documentKeywords = []
    }

    private var hasDocumentAnalysis: Bool {
        documentAnalysisSummary != nil ||
            documentSuggestedTitle != nil ||
            documentSuggestedDueDate != nil ||
            !documentKeywords.isEmpty ||
            !documentExtractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func applyDocumentSuggestion() {
        if let suggestedTitle = documentSuggestedTitle, !suggestedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            title = suggestedTitle
        }

        if let documentSuggestedDueDate {
            dueDate = documentSuggestedDueDate
        }

        if documentKeywords.contains("insurance") || documentKeywords.contains("invoice") || documentKeywords.contains("bill") || documentKeywords.contains("tax") {
            categoryRawValue = TaskCategory.finance.rawValue
            pendingCategoryOption = nil
        } else if documentKeywords.contains("appointment") || documentKeywords.contains("medical") {
            categoryRawValue = TaskCategory.health.rawValue
            pendingCategoryOption = nil
        } else if documentKeywords.contains("school") || documentKeywords.contains("application") {
            categoryRawValue = TaskCategory.personal.rawValue
            pendingCategoryOption = nil
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
        let wasCompleted = existingTask?.isCompleted ?? false

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
            task.priority = priority
            task.recurrence = recurrence
            task.scheduledDurationMinutes = durationMinutes
            task.documentStorageName = documentStorageName
            task.documentDisplayName = documentDisplayName
            task.documentExtractedText = documentExtractedText
            task.documentAnalysisSummary = documentAnalysisSummary
            task.documentSuggestedTitle = documentSuggestedTitle
            task.documentSuggestedDueDate = documentSuggestedDueDate
            task.documentKeywords = documentKeywords
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
                priority: priority,
                recurrence: recurrence,
                estimatedDurationMinutes: durationMinutes,
                documentStorageName: documentStorageName,
                documentDisplayName: documentDisplayName,
                documentExtractedText: documentExtractedText,
                documentAnalysisSummary: documentAnalysisSummary,
                documentSuggestedTitle: documentSuggestedTitle,
                documentSuggestedDueDate: documentSuggestedDueDate,
                documentKeywords: documentKeywords,
                createdAt: now,
                updatedAt: now
            )
            modelContext.insert(task)
        }

        let nextRecurringTask: LifeTask?
        if !wasCompleted && task.isCompleted {
            nextRecurringTask = task.nextRecurringTask(completedAt: now)
            if let nextRecurringTask {
                modelContext.insert(nextRecurringTask)
            }
        } else {
            nextRecurringTask = nil
        }

        try? modelContext.save()
        ReminderScheduler.synchronizeReminder(
            taskID: task.id,
            title: task.title,
            categoryTitle: selectedCategoryOption.title,
            dueDate: task.dueDate,
            isCompleted: task.isCompleted
        )
        if let nextRecurringTask {
            TaskLifecycleManager.synchronizeReminder(
                for: nextRecurringTask,
                customCategories: customCategories
            )
        }
        didSave = true
        dismiss()
    }

    private var selectedCategory: TaskCategory {
        TaskCategory(rawValue: categoryRawValue) ?? .other
    }

    private func durationTitle(for minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        }

        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if remainingMinutes == 0 {
            return "\(hours)h"
        }

        return "\(hours)h \(remainingMinutes)m"
    }

    private func durationChipBackground(isSelected: Bool) -> some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(LifeTrackTheme.ColorPalette.accentGradient)
        }

        return AnyShapeStyle(LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.86))
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

private struct DocumentIntelligenceView: View {
    let summary: String?
    let suggestedTitle: String?
    let suggestedDueDate: Date?
    let keywords: [String]
    let extractedText: String
    let onApplySuggestion: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.small) {
            HStack(alignment: .top, spacing: LifeTrackTheme.Spacing.medium) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                    .frame(width: LifeTrackTheme.IconSize.largeCircle, height: LifeTrackTheme.IconSize.largeCircle)
                    .background(LifeTrackTheme.ColorPalette.accentSoft, in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text("Document Assistant")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                    Text(summary ?? "Searchable document text is saved locally.")
                        .font(.footnote)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let suggestedTitle {
                DocumentSuggestionRow(
                    symbolName: "sparkles",
                    title: suggestedTitle,
                    subtitle: suggestedDueDate.map { "Suggested due date: \($0.weekdayDateString)" } ?? "Suggested from the uploaded file."
                )

                LifeTrackPrimaryButton(
                    title: "Apply Document Suggestion",
                    systemImage: "wand.and.stars",
                    action: onApplySuggestion
                )
            }

            if !keywords.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 7) {
                        ForEach(keywords.prefix(6), id: \.self) { keyword in
                            Text(keyword.capitalized)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(LifeTrackTheme.ColorPalette.accentSoft, in: Capsule())
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            if !extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(extractedText)
                    .font(.caption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .lineLimit(3)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.86), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
            }
        }
        .padding(12)
        .background(LifeTrackTheme.ColorPalette.accentSoft.opacity(0.48), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.accent.opacity(0.18), lineWidth: 0.8)
        }
    }
}

private struct DocumentSuggestionRow: View {
    let symbolName: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: LifeTrackTheme.Spacing.small) {
            Image(systemName: symbolName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.warning)
                .frame(width: 30, height: 30)
                .background(LifeTrackTheme.ColorPalette.warning.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    .lineLimit(2)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(LifeTrackTheme.ColorPalette.cardElevated.opacity(0.86), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
    }
}

#Preview("New Task") {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: LifeTask.self, CustomTaskCategory.self, configurations: configuration)

    return NewTaskView(template: TaskTemplate.common.first)
        .modelContainer(container)
}
