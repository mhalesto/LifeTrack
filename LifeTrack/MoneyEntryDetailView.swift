//
//  MoneyEntryDetailView.swift
//  LifeTrack
//
//  Detail + light edit sheet for a MoneyEntry. Imported rows show their
//  bank description and detail line, plus editable category, notes, and
//  monthly-spending toggle. Manual and recurring entries reuse the same
//  view since the editable fields apply equally.
//

import SwiftData
import SwiftUI

struct MoneyEntryDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let entry: MoneyEntry

    @State private var category: String
    @State private var notes: String
    @State private var includeInMonthlySpending: Bool
    @State private var isShowingDeleteConfirm = false

    init(entry: MoneyEntry) {
        self.entry = entry
        _category = State(initialValue: entry.category)
        _notes = State(initialValue: entry.notes)
        _includeInMonthlySpending = State(initialValue: entry.includeInMonthlySpending)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: entry.type.symbolName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(entry.type.tint)
                            .frame(width: 38, height: 38)
                            .background(entry.type.tint.opacity(0.12), in: Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(MoneyFormatting.signedCurrency(signedAmount, code: entry.currencyCode))
                                .font(.title3.weight(.bold))
                                .foregroundStyle(amountTint)
                            Text(entry.type.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        }
                        Spacer()
                    }
                }

                Section("Details") {
                    LabeledContent("Date", value: entry.startDate.formatted(date: .abbreviated, time: .omitted))
                    LabeledContent("Currency", value: entry.currencyCode)
                    LabeledContent("Source", value: entry.source.title)
                    if let endDate = entry.endDate, endDate != entry.startDate {
                        LabeledContent("End", value: endDate.formatted(date: .abbreviated, time: .omitted))
                    }
                    LabeledContent("Logged", value: entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                }

                if let detail = entry.detailText, !detail.isEmpty {
                    Section("Bank reference") {
                        Text(detail)
                            .font(.subheadline)
                            .textSelection(.enabled)
                    }
                }

                if let balance = entry.balanceAfter {
                    Section("Balance after") {
                        Text(MoneyFormatting.currency(balance, code: entry.currencyCode))
                            .font(.subheadline.weight(.semibold))
                    }
                }

                if entry.source == .imported,
                   entry.sourceStatementName != nil || entry.sourceStatementPeriodStart != nil {
                    Section("Statement") {
                        if let name = entry.sourceStatementName {
                            LabeledContent("File", value: name)
                                .lineLimit(2)
                        }
                        if let start = entry.sourceStatementPeriodStart,
                           let end = entry.sourceStatementPeriodEnd {
                            LabeledContent("Period", value: "\(start.formatted(date: .abbreviated, time: .omitted)) – \(end.formatted(date: .abbreviated, time: .omitted))")
                        } else if let start = entry.sourceStatementPeriodStart {
                            LabeledContent("From", value: start.formatted(date: .abbreviated, time: .omitted))
                        }
                    }
                }

                Section("Category") {
                    TextField("Category", text: $category)
                        .textInputAutocapitalization(.words)
                }

                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...8)
                }

                Section {
                    Toggle("Include in monthly spending", isOn: $includeInMonthlySpending)
                } footer: {
                    Text("Turn off to keep this entry on the ledger but exclude it from your monthly spend totals.")
                }

                Section {
                    Button(role: .destructive) {
                        isShowingDeleteConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete entry")
                        }
                    }
                }
            }
            .navigationTitle("Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveAndDismiss() }
                        .disabled(!hasChanges)
                }
            }
            .confirmationDialog(
                "Delete this entry?",
                isPresented: $isShowingDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { deleteAndDismiss() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes the entry from your ledger. It won't affect bills or recurring templates.")
            }
        }
    }

    private var signedAmount: Double {
        switch entry.type {
        case .expense, .debtPayment: return -entry.amount
        case .income, .savings, .transfer: return entry.amount
        }
    }

    private var amountTint: Color {
        switch entry.type {
        case .expense, .debtPayment: return LifeTrackTheme.ColorPalette.danger
        case .income, .savings: return LifeTrackTheme.ColorPalette.success
        case .transfer: return LifeTrackTheme.ColorPalette.secondaryText
        }
    }

    private var trimmedCategory: String {
        let cleaned = category.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Uncategorized" : cleaned
    }

    private var hasChanges: Bool {
        trimmedCategory != entry.category ||
        notes != entry.notes ||
        includeInMonthlySpending != entry.includeInMonthlySpending
    }

    private func saveAndDismiss() {
        entry.category = trimmedCategory
        entry.notes = notes
        entry.includeInMonthlySpending = includeInMonthlySpending
        entry.updatedAt = Date()
        try? modelContext.save()
        dismiss()
    }

    private func deleteAndDismiss() {
        modelContext.delete(entry)
        try? modelContext.save()
        dismiss()
    }
}
