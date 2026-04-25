//
//  RecurringTransactionsView.swift
//  LifeTrack
//
//  CRUD for RecurringMoneyTransaction templates and a "run now" button
//  that emits any pending MoneyEntry rows immediately.
//

import SwiftData
import SwiftUI

struct RecurringTransactionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \RecurringMoneyTransaction.nextRunDate, order: .forward)
    private var templates: [RecurringMoneyTransaction]

    @State private var editingTemplate: RecurringMoneyTransaction?
    @State private var showingNew = false
    @State private var lastRunMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if templates.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No recurring items yet")
                                .font(.headline)
                            Text("Add subscriptions, salary, rent, or any expense you don't want to log every time.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                } else {
                    Section("Active") {
                        ForEach(templates.filter(\.isActive)) { template in
                            row(for: template)
                        }
                    }
                    let inactive = templates.filter { !$0.isActive }
                    if !inactive.isEmpty {
                        Section("Paused") {
                            ForEach(inactive) { template in
                                row(for: template)
                            }
                        }
                    }
                }

                if let lastRunMessage {
                    Section {
                        Text(lastRunMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Recurring")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showingNew = true
                        } label: {
                            Label("New template", systemImage: "plus")
                        }
                        Button {
                            runNow()
                        } label: {
                            Label("Generate pending entries", systemImage: "clock.arrow.circlepath")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingNew) {
                RecurringTransactionEditor(template: nil) { saved in
                    modelContext.insert(saved)
                    try? modelContext.save()
                }
            }
            .sheet(item: $editingTemplate) { template in
                RecurringTransactionEditor(template: template) { _ in
                    template.updatedAt = Date()
                    try? modelContext.save()
                }
            }
        }
    }

    private func row(for template: RecurringMoneyTransaction) -> some View {
        Button {
            editingTemplate = template
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: template.type.symbolName)
                        .foregroundStyle(template.type.tint)
                    Text(template.label)
                        .font(.headline)
                    Spacer()
                    Text(MoneyFormatting.currency(template.amount, code: template.currencyCode))
                        .font(.subheadline.monospacedDigit())
                }
                HStack(spacing: 6) {
                    Text(template.cadence.title)
                    Text("•")
                    Text("Next: \(template.nextRunDate.formatted(date: .abbreviated, time: .omitted))")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                modelContext.delete(template)
                try? modelContext.save()
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                template.isActive.toggle()
                template.updatedAt = Date()
                try? modelContext.save()
            } label: {
                Label(template.isActive ? "Pause" : "Resume",
                      systemImage: template.isActive ? "pause.circle" : "play.circle")
            }
            .tint(.orange)
        }
    }

    private func runNow() {
        let inserted = RecurringMoneyExpander.runPendingExpansions(
            templates: templates.filter(\.isActive),
            modelContext: modelContext
        )
        lastRunMessage = inserted == 0
            ? "No pending entries — everything is up to date."
            : "Generated \(inserted) entr\(inserted == 1 ? "y" : "ies")."
    }
}

// MARK: - Editor

private struct RecurringTransactionEditor: View {
    @Environment(\.dismiss) private var dismiss
    let template: RecurringMoneyTransaction?
    let onSave: (RecurringMoneyTransaction) -> Void

    @State private var label: String
    @State private var amountText: String
    @State private var category: String
    @State private var notes: String
    @State private var type: MoneyTransactionType
    @State private var cadence: RecurringMoneyCadence
    @State private var anchorDate: Date
    @State private var includeInMonthlySpending: Bool
    @State private var hasEndDate: Bool
    @State private var endDate: Date

    init(template: RecurringMoneyTransaction?, onSave: @escaping (RecurringMoneyTransaction) -> Void) {
        self.template = template
        self.onSave = onSave
        _label = State(initialValue: template?.label ?? "")
        _amountText = State(initialValue: template.map { String(format: "%.2f", $0.amount) } ?? "")
        _category = State(initialValue: template?.category ?? "")
        _notes = State(initialValue: template?.notes ?? "")
        _type = State(initialValue: template?.type ?? .expense)
        _cadence = State(initialValue: template?.cadence ?? .monthly)
        _anchorDate = State(initialValue: template?.anchorDate ?? Date())
        _includeInMonthlySpending = State(initialValue: template?.includeInMonthlySpending ?? true)
        _hasEndDate = State(initialValue: template?.endDate != nil)
        _endDate = State(initialValue: template?.endDate ?? Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Basics") {
                    TextField("Name (e.g. Netflix, Rent)", text: $label)
                    Picker("Type", selection: $type) {
                        ForEach(MoneyTransactionType.allCases) { t in
                            Label(t.title, systemImage: t.symbolName).tag(t)
                        }
                    }
                    HStack {
                        Text("Amount")
                        Spacer()
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 140)
                    }
                    TextField("Category", text: $category)
                }

                Section("Schedule") {
                    Picker("Cadence", selection: $cadence) {
                        ForEach(RecurringMoneyCadence.allCases) { c in
                            Text(c.title).tag(c)
                        }
                    }
                    DatePicker("Starts on", selection: $anchorDate, displayedComponents: .date)
                    Toggle("Has end date", isOn: $hasEndDate.animation())
                    if hasEndDate {
                        DatePicker("Ends on", selection: $endDate, in: anchorDate..., displayedComponents: .date)
                    }
                }

                Section("Tracking") {
                    Toggle("Include in monthly spending", isOn: $includeInMonthlySpending)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(template == nil ? "New recurring" : "Edit recurring")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        !label.trimmingCharacters(in: .whitespaces).isEmpty &&
        (Double(amountText) ?? 0) > 0
    }

    private func save() {
        let amount = Double(amountText) ?? 0
        if let template {
            template.label = label
            template.type = type
            template.amount = amount
            template.category = category
            template.notes = notes
            template.cadence = cadence
            template.anchorDate = anchorDate
            template.nextRunDate = max(anchorDate, template.nextRunDate)
            template.endDate = hasEndDate ? endDate : nil
            template.includeInMonthlySpending = includeInMonthlySpending
            onSave(template)
        } else {
            let new = RecurringMoneyTransaction(
                label: label,
                type: type,
                amount: amount,
                category: category,
                cadence: cadence,
                anchorDate: anchorDate,
                endDate: hasEndDate ? endDate : nil,
                includeInMonthlySpending: includeInMonthlySpending,
                notes: notes
            )
            onSave(new)
        }
    }
}
