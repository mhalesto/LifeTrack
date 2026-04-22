//
//  TaskDataExchangeView.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import SwiftData
import SwiftUI

enum TaskDataExchangeEntryMode: Hashable {
    case overview
    case importTasks
    case exportTasks
}

private enum TaskDataExchangeSection: Hashable {
    case importTasks
    case exportTasks
}

struct TaskDataExchangeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LifeTask.updatedAt, order: .reverse) private var tasks: [LifeTask]
    @Query(sort: \CustomTaskCategory.title) private var customCategories: [CustomTaskCategory]

    let initialMode: TaskDataExchangeEntryMode
    let showsCloseButton: Bool

    @State private var selectedExportFormat: TaskExchangeFormat = .json
    @State private var selectedTemplateFormat: TaskExchangeFormat = .csv
    @State private var selectedTemplateIDs: Set<String> = Set(TaskTemplate.common.map(\.id))
    @State private var exportDocument = TaskExchangeFileDocument()
    @State private var templateDocument = TaskExchangeFileDocument()
    @State private var shareURL: URL?
    @State private var templateShareURL: URL?
    @State private var isExporting = false
    @State private var isExportingTemplate = false
    @State private var isImporting = false
    @State private var didFocusInitialMode = false
    @State private var feedback: TaskExchangeFeedback?

    init(initialMode: TaskDataExchangeEntryMode = .overview, showsCloseButton: Bool = false) {
        self.initialMode = initialMode
        self.showsCloseButton = showsCloseButton
    }

    var body: some View {
        ZStack {
            LifeTrackTheme.appBackground
                .ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.large) {
                        header
                        if let feedback {
                            TaskExchangeFeedbackView(feedback: feedback) {
                                self.feedback = nil
                            }
                        }
                        summaryCard
                        importCard
                            .id(TaskDataExchangeSection.importTasks)
                        templateCard
                        exportCard
                            .id(TaskDataExchangeSection.exportTasks)
                        schemaCard
                    }
                    .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
                    .padding(.top, LifeTrackTheme.Spacing.medium)
                    .padding(.bottom, LifeTrackTheme.Spacing.xxLarge)
                }
                .scrollIndicators(.hidden)
                .onAppear {
                    refreshShareURL()
                    refreshTemplateShareURL()
                    focusInitialMode(with: proxy)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsCloseButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }
            }
        }
        .onChange(of: selectedExportFormat) { _, _ in
            refreshShareURL()
        }
        .onChange(of: selectedTemplateFormat) { _, _ in
            refreshTemplateShareURL()
        }
        .onChange(of: selectedTemplateIDs) { _, _ in
            refreshTemplateShareURL()
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: TaskExchangeFormat.importContentTypes,
            allowsMultipleSelection: false,
            onCompletion: handleImport
        )
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: selectedExportFormat.contentType,
            defaultFilename: exportFileName,
            onCompletion: handleExport
        )
        .fileExporter(
            isPresented: $isExportingTemplate,
            document: templateDocument,
            contentType: selectedTemplateFormat.contentType,
            defaultFilename: templateFileName,
            onCompletion: handleTemplateExport
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Task Data")
                .font(.lifeTrackHero)
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

            Text("Import or export tasks with statuses, due dates, categories, priority, recurrence, duration, notes, and optional money fields.")
                .font(.subheadline)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var summaryCard: some View {
        SectionCardView {
            SectionHeaderView(
                title: "Current Library",
                subtitle: "Exports include active, completed, and Bin tasks."
            )

            HStack(spacing: LifeTrackTheme.Spacing.small) {
                TaskExchangeMetricPill(title: "Tasks", value: tasks.count.formatted(), symbolName: "checklist")
                TaskExchangeMetricPill(title: "Done", value: tasks.filter(\.isCompleted).count.formatted(), symbolName: "checkmark.seal")
                TaskExchangeMetricPill(title: "Bin", value: tasks.filter(\.isDeleted).count.formatted(), symbolName: "trash")
            }
        }
    }

    private var importCard: some View {
        SectionCardView {
            SectionHeaderView(
                title: "Import",
                subtitle: "Accepts JSON, CSV, and TSV. For Excel, save the sheet as CSV first."
            )

            VStack(alignment: .leading, spacing: 9) {
                TaskExchangeRequirementRow(
                    symbolName: "textformat",
                    title: "Required",
                    message: "`title` and `due_date` columns are required. `due_time` is optional and defaults to 09:00."
                )

                TaskExchangeRequirementRow(
                    symbolName: "tag",
                    title: "Labels",
                    message: "`category` or `category_label` sets the task type. Unknown labels become custom categories."
                )

                TaskExchangeRequirementRow(
                    symbolName: "circle.dotted",
                    title: "Status",
                    message: "Use `in_progress`, `done`, or `bin`. Common values like completed, open, deleted, and yes also work."
                )

                TaskExchangeRequirementRow(
                    symbolName: "creditcard",
                    title: "Money",
                    message: "Optional fields like `financial_enabled`, `planned_amount`, `actual_amount`, and `currency_code` add budget metadata."
                )
            }

            LifeTrackPrimaryButton(
                title: "Import Tasks",
                systemImage: "square.and.arrow.down",
                action: { isImporting = true }
            )
        }
    }

    private var templateSelectionSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("Include templates")
                    .font(.lifeTrackCaption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)

                Spacer(minLength: 8)

                Text("\(selectedTemplateIDs.count) of \(TaskTemplate.common.count)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)

                Button(allTemplatesSelected ? "Clear" : "Select all") {
                    if allTemplatesSelected {
                        selectedTemplateIDs.removeAll()
                    } else {
                        selectedTemplateIDs = Set(TaskTemplate.common.map(\.id))
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
            }

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                spacing: 8
            ) {
                ForEach(TaskTemplate.common) { template in
                    TemplateIncludeChip(
                        template: template,
                        isSelected: selectedTemplateIDs.contains(template.id)
                    ) {
                        toggleTemplate(template.id)
                    }
                }
            }
        }
    }

    private var allTemplatesSelected: Bool {
        selectedTemplateIDs.count == TaskTemplate.common.count
    }

    private var selectedTemplates: [TaskTemplate] {
        TaskTemplate.common.filter { selectedTemplateIDs.contains($0.id) }
    }

    private func toggleTemplate(_ id: String) {
        if selectedTemplateIDs.contains(id) {
            selectedTemplateIDs.remove(id)
        } else {
            selectedTemplateIDs.insert(id)
        }
    }

    private var templateCard: some View {
        SectionCardView {
            SectionHeaderView(
                title: "Import Template",
                subtitle: "Download or share a ready file with the correct columns and sample rows."
            )

            TaskExchangeRequirementRow(
                symbolName: "doc.badge.gearshape",
                title: "Use this first",
                message: "Edit the sample rows in Excel, Numbers, Sheets, or a text editor, then import the completed file back into LifeTrack."
            )

            templateSelectionSection

            TaskExchangeFormatPicker(
                selectedFormat: $selectedTemplateFormat,
                title: "Template format"
            )

            LifeTrackPrimaryButton(
                title: "Download Template",
                systemImage: "square.and.arrow.down",
                isDisabled: selectedTemplateIDs.isEmpty,
                action: prepareTemplateExport
            )

            if let templateShareURL {
                ShareLink(
                    item: templateShareURL,
                    subject: Text("LifeTrack import template"),
                    message: Text("LifeTrack import template in \(selectedTemplateFormat.title) format."),
                    preview: SharePreview(templateFileName)
                ) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share Template")
                    }
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(LifeTrackTheme.ColorPalette.cardElevated, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                            .stroke(LifeTrackTheme.ColorPalette.hairline, lineWidth: 0.8)
                    }
                }
                .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.985))
                .simultaneousGesture(TapGesture().onEnded(refreshTemplateShareURL))
                .accessibilityLabel("Share import template")
            } else {
                LifeTrackSecondaryButton(
                    title: "Prepare Template",
                    systemImage: "doc.badge.plus",
                    action: refreshTemplateShareURL
                )
            }
        }
    }

    private var exportCard: some View {
        SectionCardView {
            SectionHeaderView(
                title: "Export",
                subtitle: "Choose a format for backup, spreadsheet editing, or sharing."
            )

            TaskExchangeRequirementRow(
                symbolName: "square.and.arrow.up.on.square",
                title: "Share",
                message: "Use Share / AirDrop for AirDrop, Messages, Mail, WhatsApp, or any installed social share extension."
            )

            TaskExchangeFormatPicker(
                selectedFormat: $selectedExportFormat,
                title: "Export format"
            )

            LifeTrackPrimaryButton(
                title: "Save to Files",
                systemImage: "square.and.arrow.up",
                isDisabled: tasks.isEmpty,
                action: prepareExport
            )

            if let shareURL, !tasks.isEmpty {
                ShareLink(
                    item: shareURL,
                    subject: Text("LifeTrack task export"),
                    message: Text("LifeTrack task export in \(selectedExportFormat.title) format."),
                    preview: SharePreview(exportFileName)
                ) {
                    HStack(spacing: 8) {
                        Image(systemName: "airdrop")
                        Text("Share / AirDrop")
                    }
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(LifeTrackTheme.ColorPalette.cardElevated, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                            .stroke(LifeTrackTheme.ColorPalette.hairline, lineWidth: 0.8)
                    }
                }
                .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.985))
                .simultaneousGesture(TapGesture().onEnded(refreshShareURL))
                .accessibilityLabel("Share export with AirDrop, social apps, messages, or mail")
            } else {
                LifeTrackSecondaryButton(
                    title: "Prepare Share File",
                    systemImage: "airdrop",
                    action: refreshShareURL
                )
                .disabled(tasks.isEmpty)
                .opacity(tasks.isEmpty ? 0.45 : 1)
            }
        }
    }

    private var schemaCard: some View {
        SectionCardView {
            SectionHeaderView(
                title: "Spreadsheet Columns",
                subtitle: "Use these labels when creating a CSV or TSV manually."
            )

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 112), spacing: 8, alignment: .leading)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(schemaColumns, id: \.self) { column in
                    Text(column)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(requiredColumns.contains(column) ? LifeTrackTheme.ColorPalette.accent : LifeTrackTheme.ColorPalette.secondaryText)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(
                            requiredColumns.contains(column) ? LifeTrackTheme.ColorPalette.accentSoft : LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.86),
                            in: Capsule()
                        )
                }
            }
        }
    }

    private var schemaColumns: [String] {
        [
            "title",
            "due_date",
            "due_time",
            "category",
            "status",
            "priority",
            "recurrence",
            "duration_minutes",
            "notes",
            "financial_enabled",
            "financial_type",
            "planned_amount",
            "actual_amount",
            "currency_code",
            "budget_category",
            "payment_date",
            "include_in_monthly_spending"
        ]
    }

    private var requiredColumns: Set<String> {
        ["title", "due_date"]
    }

    private var exportFileName: String {
        let date = Date().formatted(Date.FormatStyle().year().month(.twoDigits).day(.twoDigits))
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "-")
        return "LifeTrack Tasks \(date).\(selectedExportFormat.fileExtension)"
    }

    private var templateFileName: String {
        "LifeTrack Import Template.\(selectedTemplateFormat.fileExtension)"
    }

    private func prepareExport() {
        do {
            let data = try TaskExchangeManager.exportData(
                format: selectedExportFormat,
                tasks: tasks,
                customCategories: customCategories
            )
            exportDocument = TaskExchangeFileDocument(data: data)
            refreshShareURL()
            isExporting = true
        } catch {
            feedback = .error(error.localizedDescription)
        }
    }

    private func prepareTemplateExport() {
        guard !selectedTemplateIDs.isEmpty else {
            feedback = .error("Pick at least one template to include.")
            return
        }
        do {
            let data = try TaskExchangeManager.templateData(
                format: selectedTemplateFormat,
                templates: selectedTemplates
            )
            templateDocument = TaskExchangeFileDocument(data: data)
            refreshTemplateShareURL()
            isExportingTemplate = true
        } catch {
            feedback = .error(error.localizedDescription)
        }
    }

    private func refreshShareURL() {
        guard !tasks.isEmpty else {
            shareURL = nil
            return
        }

        do {
            shareURL = try TaskExchangeManager.shareableExportURL(
                format: selectedExportFormat,
                tasks: tasks,
                customCategories: customCategories,
                fileName: exportFileName
            )
        } catch {
            shareURL = nil
            feedback = .error(error.localizedDescription)
        }
    }

    private func refreshTemplateShareURL() {
        guard !selectedTemplateIDs.isEmpty else {
            templateShareURL = nil
            return
        }
        do {
            templateShareURL = try TaskExchangeManager.shareableTemplateURL(
                format: selectedTemplateFormat,
                fileName: templateFileName,
                templates: selectedTemplates
            )
        } catch {
            templateShareURL = nil
        }
    }

    private func focusInitialMode(with proxy: ScrollViewProxy) {
        guard !didFocusInitialMode else {
            return
        }

        didFocusInitialMode = true

        let target: TaskDataExchangeSection?
        switch initialMode {
        case .overview:
            target = nil
        case .importTasks:
            target = .importTasks
        case .exportTasks:
            target = .exportTasks
        }

        guard let target else {
            return
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            withAnimation(.snappy(duration: 0.32)) {
                proxy.scrollTo(target, anchor: .top)
            }
        }
    }

    private func handleExport(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            feedback = .success("Export ready", "\(tasks.count.formatted()) tasks exported as \(selectedExportFormat.title).")
        case .failure(let error):
            feedback = .error(error.localizedDescription)
        }
    }

    private func handleTemplateExport(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            feedback = .success("Template ready", "\(selectedTemplateFormat.title) import template saved.")
        case .failure(let error):
            feedback = .error(error.localizedDescription)
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                feedback = .error("No file was selected.")
                return
            }

            importTasks(from: url)
        case .failure(let error):
            feedback = .error(error.localizedDescription)
        }
    }

    private func importTasks(from url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            let summary = try TaskExchangeManager.importTasks(
                from: data,
                fileName: url.lastPathComponent,
                existingTasks: tasks,
                customCategories: customCategories,
                modelContext: modelContext
            )
            feedback = .imported(summary)
            refreshShareURL()
        } catch {
            feedback = .error(error.localizedDescription)
        }
    }
}

private enum TaskExchangeFeedback: Equatable {
    case success(String, String)
    case imported(TaskImportSummary)
    case error(String)
}

private struct TaskExchangeFeedbackView: View {
    let feedback: TaskExchangeFeedback
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: LifeTrackTheme.Spacing.medium) {
            Image(systemName: symbolName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: LifeTrackTheme.IconSize.largeCircle, height: LifeTrackTheme.IconSize.largeCircle)
                .background(tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                Text(message)
                    .font(.footnote)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if !skippedReasons.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(skippedReasons.prefix(3), id: \.self) { reason in
                            Text(reason)
                                .font(.caption)
                                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.top, 3)
                }
            }

            Spacer(minLength: 0)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
                    .frame(width: 28, height: 28)
                    .background(LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.8), in: Circle())
            }
            .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.9))
        }
        .padding(12)
        .background(LifeTrackTheme.ColorPalette.cardElevated, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 0.8)
        }
    }

    private var title: String {
        switch feedback {
        case .success(let title, _):
            return title
        case .imported(let summary):
            return summary.skipped == 0 ? "Import complete" : "Import partially complete"
        case .error:
            return "Could not complete action"
        }
    }

    private var message: String {
        switch feedback {
        case .success(_, let message):
            return message
        case .imported(let summary):
            let importedText = "\(summary.imported.formatted()) imported"
            let createdText = "\(summary.created.formatted()) new"
            let updatedText = "\(summary.updated.formatted()) updated"
            let skippedText = summary.skipped == 0 ? "none skipped" : "\(summary.skipped.formatted()) skipped"
            return "\(importedText): \(createdText), \(updatedText), \(skippedText)."
        case .error(let message):
            return message
        }
    }

    private var skippedReasons: [String] {
        if case .imported(let summary) = feedback {
            return summary.skippedReasons
        }

        return []
    }

    private var symbolName: String {
        switch feedback {
        case .success, .imported:
            return "checkmark.seal"
        case .error:
            return "exclamationmark.triangle"
        }
    }

    private var tint: Color {
        switch feedback {
        case .success, .imported:
            return LifeTrackTheme.ColorPalette.success
        case .error:
            return LifeTrackTheme.ColorPalette.danger
        }
    }
}

private struct TaskExchangeMetricPill: View {
    let title: String
    let value: String
    let symbolName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: symbolName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.accent)

            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.82), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.8), lineWidth: 0.8)
        }
    }
}

private struct TaskExchangeRequirementRow: View {
    let symbolName: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: LifeTrackTheme.Spacing.small) {
            Image(systemName: symbolName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                .frame(width: 30, height: 30)
                .background(LifeTrackTheme.ColorPalette.accentSoft, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                Text(message)
                    .font(.caption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct TaskExchangeFormatPicker: View {
    @Binding var selectedFormat: TaskExchangeFormat
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.lifeTrackCaption)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 92), spacing: 8, alignment: .leading)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(TaskExchangeFormat.allCases) { format in
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            selectedFormat = format
                        }
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: format.symbolName)
                                .font(.system(size: 12, weight: .bold))

                            Text(format.title)
                                .font(.caption.weight(.bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                        }
                        .foregroundStyle(selectedFormat == format ? .white : LifeTrackTheme.ColorPalette.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            selectedFormat == format ? AnyShapeStyle(LifeTrackTheme.ColorPalette.accentGradient) : AnyShapeStyle(LifeTrackTheme.ColorPalette.accentSoft.opacity(0.72)),
                            in: Capsule()
                        )
                        .overlay {
                            Capsule()
                                .stroke(selectedFormat == format ? Color.white.opacity(0.24) : LifeTrackTheme.ColorPalette.accent.opacity(0.16), lineWidth: 0.8)
                        }
                    }
                    .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.96, pressedOpacity: 0.92))
                }
            }
        }
    }
}

private struct TaskExchangeFormatRow: View {
    let format: TaskExchangeFormat
    let isSelected: Bool

    var body: some View {
        HStack(spacing: LifeTrackTheme.Spacing.medium) {
            Image(systemName: format.symbolName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isSelected ? .white : LifeTrackTheme.ColorPalette.accent)
                .frame(width: 40, height: 40)
                .background(isSelected ? AnyShapeStyle(LifeTrackTheme.ColorPalette.accentGradient) : AnyShapeStyle(LifeTrackTheme.ColorPalette.accentSoft), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(format.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                Text(format.subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: LifeTrackTheme.Spacing.small)

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(isSelected ? LifeTrackTheme.ColorPalette.accent : LifeTrackTheme.ColorPalette.tertiaryText.opacity(0.55))
        }
        .padding(12)
        .background(
            isSelected ? LifeTrackTheme.ColorPalette.accentSoft.opacity(0.58) : LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.78),
            in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                .stroke(isSelected ? LifeTrackTheme.ColorPalette.accent.opacity(0.28) : LifeTrackTheme.ColorPalette.hairline.opacity(0.8), lineWidth: 0.8)
        }
    }
}

private struct TemplateIncludeChip: View {
    let template: TaskTemplate
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSelected ? LifeTrackTheme.ColorPalette.accent : LifeTrackTheme.ColorPalette.tertiaryText)

                VStack(alignment: .leading, spacing: 2) {
                    Text(template.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                        .lineLimit(1)
                    Text(template.category.title)
                        .font(.caption2)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                (isSelected ? LifeTrackTheme.ColorPalette.accentSoft : LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.6)),
                in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                    .stroke(
                        isSelected ? LifeTrackTheme.ColorPalette.accent.opacity(0.55) : LifeTrackTheme.ColorPalette.hairline.opacity(0.9),
                        lineWidth: isSelected ? 1.1 : 0.8
                    )
            }
        }
        .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.97))
        .accessibilityLabel("\(template.title), \(isSelected ? "included" : "excluded")")
    }
}

#Preview {
    NavigationStack {
        TaskDataExchangeView()
    }
    .modelContainer(for: [LifeTask.self, CustomTaskCategory.self], inMemory: true)
}
