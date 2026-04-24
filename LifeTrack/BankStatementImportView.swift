//
//  BankStatementImportView.swift
//  LifeTrack
//
//  Bank statement import flow. Pick file → parse → review staged
//  transactions → commit to `MoneyEntry` rows with source=.imported.
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct BankStatementImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MoneyEntry.startDate, order: .reverse) private var existingEntries: [MoneyEntry]

    @State private var stage: Stage = .pickFile
    @State private var statement: ParsedStatement?
    @State private var staged: [StagedRow] = []
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var isFilePickerPresented = false

    enum Stage: Equatable {
        case pickFile
        case parsing
        case review
        case done(imported: Int, skipped: Int)
    }

    private var existingKeys: Set<String> {
        Set(existingEntries.compactMap { entry in
            guard entry.source == .imported else { return nil }
            return StagedRow.duplicateKey(
                date: entry.startDate,
                amount: entry.typeRawValue == MoneyTransactionType.income.rawValue ? entry.amount : -entry.amount,
                description: entry.notes
            )
        })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LifeTrackTheme.appBackground.ignoresSafeArea()

                Group {
                    switch stage {
                    case .pickFile:
                        pickFileContent
                    case .parsing:
                        parsingContent
                    case .review:
                        reviewContent
                    case .done(let imported, let skipped):
                        doneContent(imported: imported, skipped: skipped)
                    }
                }
            }
            .navigationTitle("Import Statement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $isFilePickerPresented,
                allowedContentTypes: allowedTypes,
                allowsMultipleSelection: false
            ) { result in
                handlePickResult(result)
            }
            .alert("Couldn't read that file", isPresented: errorBinding, actions: {
                Button("OK") { errorMessage = nil }
            }, message: {
                Text(errorMessage ?? "")
            })
        }
    }

    private var allowedTypes: [UTType] {
        [.pdf, .commaSeparatedText, .plainText, .text]
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    // MARK: Stages

    private var pickFileContent: some View {
        VStack(spacing: LifeTrackTheme.Spacing.large) {
            Spacer()

            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.accent)

            VStack(spacing: 8) {
                Text("Import a bank statement")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                Text("Pick a PDF, CSV, or OFX file. Everything is parsed on this device — nothing leaves your phone.")
                    .font(.subheadline)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Button(action: { isFilePickerPresented = true }) {
                Label("Choose statement…", systemImage: "tray.and.arrow.down")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(LifeTrackTheme.ColorPalette.accentGradient, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
            }
            .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.98))
            .padding(.horizontal, 24)

            supportedFormatsFootnote

            Spacer()
        }
    }

    private var supportedFormatsFootnote: some View {
        VStack(spacing: 4) {
            Text("Works with PDF, CSV, TXT, and OFX exports.")
            Text("Standard Bank SA statements get full transaction parsing.")
        }
        .font(.caption)
        .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
    }

    private var parsingContent: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text("Reading your statement…")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
            Spacer()
        }
    }

    private var reviewContent: some View {
        VStack(spacing: 0) {
            if let statement {
                statementSummaryHeader(statement)
            }

            List {
                Section {
                    ForEach($staged) { $row in
                        StagedTransactionRow(
                            row: $row,
                            currencyCode: statement?.currencyCode ?? MoneyCurrency.defaultCode
                        )
                    }
                    .onDelete { indexes in
                        staged.remove(atOffsets: indexes)
                    }
                } header: {
                    Text("Review \(staged.count) transactions")
                } footer: {
                    Text("Tap a row to edit the amount, date, or category. Uncheck to skip. Swipe left to remove.")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)

            commitBar
        }
    }

    private func statementSummaryHeader(_ statement: ParsedStatement) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(statement.bankName)
                .font(.headline.weight(.bold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

            if let holder = statement.accountHolder {
                Text(holder)
                    .font(.subheadline)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
            }

            HStack(spacing: 16) {
                summaryPill(
                    icon: "arrow.down.circle.fill",
                    label: "In",
                    value: MoneyFormatting.currency(statement.totalDeposits, code: statement.currencyCode),
                    tint: LifeTrackTheme.ColorPalette.success
                )
                summaryPill(
                    icon: "arrow.up.circle.fill",
                    label: "Out",
                    value: MoneyFormatting.currency(abs(statement.totalPayments), code: statement.currencyCode),
                    tint: LifeTrackTheme.ColorPalette.danger
                )
            }
            .padding(.top, 4)

            let duplicateCount = staged.filter(\.isDuplicate).count
            if duplicateCount > 0 {
                Label("\(duplicateCount) already imported — unchecked by default", systemImage: "info.circle")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.warning)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(LifeTrackTheme.ColorPalette.cardElevated)
    }

    private func summaryPill(icon: String, label: String, value: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
        }
    }

    private var commitBar: some View {
        let selectedCount = staged.filter(\.isSelected).count
        return VStack(spacing: 0) {
            Divider()
            Button(action: commit) {
                HStack {
                    if isImporting {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    Text(isImporting ? "Importing…" : "Import \(selectedCount) transaction\(selectedCount == 1 ? "" : "s")")
                }
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    selectedCount == 0
                        ? AnyShapeStyle(LifeTrackTheme.ColorPalette.tertiaryText)
                        : AnyShapeStyle(LifeTrackTheme.ColorPalette.accentGradient),
                    in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                )
            }
            .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.98))
            .disabled(selectedCount == 0 || isImporting)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(LifeTrackTheme.ColorPalette.cardElevated)
    }

    private func doneContent(imported: Int, skipped: Int) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.success)

            Text("Imported \(imported) transaction\(imported == 1 ? "" : "s")")
                .font(.title2.weight(.bold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

            if skipped > 0 {
                Text("\(skipped) skipped (duplicates or unchecked)")
                    .font(.subheadline)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
            }

            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)

            Spacer()
        }
    }

    // MARK: Actions

    private func handlePickResult(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            stage = .parsing
            Task.detached(priority: .userInitiated) {
                do {
                    let text = try BankStatementReader.readText(from: url)
                    let parsed = try BankStatementImporter.parse(text)
                    await MainActor.run {
                        applyParsed(parsed)
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                        stage = .pickFile
                    }
                }
            }
        }
    }

    private func applyParsed(_ parsed: ParsedStatement) {
        statement = parsed
        let existing = existingKeys
        staged = parsed.transactions.map { transaction in
            let key = StagedRow.duplicateKey(
                date: transaction.date,
                amount: transaction.amount,
                description: transaction.descriptionText
            )
            let isDuplicate = existing.contains(key)
            return StagedRow(
                source: transaction,
                descriptionText: transaction.descriptionText,
                detailText: transaction.detailText,
                date: transaction.date,
                amount: transaction.amount,
                category: transaction.suggestedCategory ?? "Uncategorized",
                isSelected: !isDuplicate,
                isDuplicate: isDuplicate
            )
        }
        stage = .review
    }

    private func commit() {
        guard let statement else { return }
        isImporting = true
        let currencyCode = statement.currencyCode
        let rowsToCommit = staged.filter(\.isSelected)
        for row in rowsToCommit {
            let entry = MoneyEntry(
                type: row.amount >= 0 ? .income : .expense,
                amount: abs(row.amount),
                currencyCode: currencyCode,
                category: row.category,
                dateScope: .day,
                startDate: row.date,
                notes: row.notesText,
                source: .imported
            )
            modelContext.insert(entry)
        }
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Couldn't save the imported entries: \(error.localizedDescription)"
            isImporting = false
            return
        }
        let imported = rowsToCommit.count
        let skipped = staged.count - imported
        isImporting = false
        stage = .done(imported: imported, skipped: skipped)
    }
}

// MARK: - Staged Row

struct StagedRow: Identifiable {
    let id = UUID()
    let source: ParsedTransaction
    var descriptionText: String
    var detailText: String?
    var date: Date
    var amount: Double
    var category: String
    var isSelected: Bool
    var isDuplicate: Bool

    var notesText: String {
        if let detailText, !detailText.isEmpty {
            return "\(descriptionText) — \(detailText)"
        }
        return descriptionText
    }

    static func duplicateKey(date: Date, amount: Double, description: String) -> String {
        let day = ISO8601DateFormatter.dayKey.string(from: date)
        let amountKey = String(format: "%.2f", amount)
        let desc = description
            .uppercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(day)|\(amountKey)|\(desc)"
    }
}

// MARK: - Row view

private struct StagedTransactionRow: View {
    @Binding var row: StagedRow
    let currencyCode: String
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Button {
                    row.isSelected.toggle()
                } label: {
                    Image(systemName: row.isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(row.isSelected ? LifeTrackTheme.ColorPalette.accent : LifeTrackTheme.ColorPalette.tertiaryText)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    Text(row.descriptionText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Text(row.date, format: .dateTime.day().month(.abbreviated).year(.twoDigits))
                            .font(.caption)
                            .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        Text("·")
                            .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
                        Text(row.category)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                    }

                    if row.isDuplicate {
                        Text("Already imported")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.warning)
                    }
                }

                Spacer(minLength: 8)

                Text(MoneyFormatting.currency(row.amount, code: currencyCode))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(row.amount < 0 ? LifeTrackTheme.ColorPalette.danger : LifeTrackTheme.ColorPalette.success)
                    .monospacedDigit()
            }

            Button {
                withAnimation(.snappy(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.bold))
                    Text(isExpanded ? "Hide details" : "Edit")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
            }
            .buttonStyle(.plain)

            if isExpanded {
                editor
            }
        }
        .padding(.vertical, 4)
        .opacity(row.isSelected ? 1.0 : 0.55)
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledContent("Description") {
                TextField("Description", text: $row.descriptionText)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("Amount") {
                TextField("Amount", value: $row.amount, format: .number)
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.trailing)
            }
            DatePicker("Date", selection: $row.date, displayedComponents: .date)
            LabeledContent("Category") {
                TextField("Category", text: $row.category)
                    .multilineTextAlignment(.trailing)
            }
            if let detail = row.detailText, !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
            }
        }
        .font(.footnote)
        .padding(10)
        .background(LifeTrackTheme.ColorPalette.backgroundTop, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
