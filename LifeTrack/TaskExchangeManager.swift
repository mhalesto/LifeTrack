//
//  TaskExchangeManager.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

enum TaskExchangeFormat: String, CaseIterable, Identifiable {
    case json
    case csv
    case tsv

    var id: String { rawValue }

    var title: String {
        switch self {
        case .json: "JSON"
        case .csv: "Excel CSV"
        case .tsv: "TSV"
        }
    }

    var subtitle: String {
        switch self {
        case .json: "Best for backup and full-fidelity restore."
        case .csv: "Opens cleanly in Excel, Numbers, and Sheets."
        case .tsv: "Spreadsheet-friendly plain text."
        }
    }

    var symbolName: String {
        switch self {
        case .json: "curlybraces"
        case .csv: "tablecells"
        case .tsv: "list.bullet.rectangle"
        }
    }

    var contentType: UTType {
        switch self {
        case .json:
            return .json
        case .csv:
            return .commaSeparatedText
        case .tsv:
            return .tabSeparatedText
        }
    }

    var fileExtension: String {
        switch self {
        case .json: "json"
        case .csv: "csv"
        case .tsv: "tsv"
        }
    }

    var delimiter: Character {
        switch self {
        case .json, .csv: ","
        case .tsv: "\t"
        }
    }

    static var importContentTypes: [UTType] {
        [.json, .commaSeparatedText, .tabSeparatedText, .plainText]
    }

    static func inferred(from fileName: String) -> TaskExchangeFormat? {
        switch URL(fileURLWithPath: fileName).pathExtension.lowercased() {
        case "json": return .json
        case "csv": return .csv
        case "tsv", "tab": return .tsv
        case "txt": return .csv
        default: return nil
        }
    }
}

struct TaskExchangeFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { TaskExchangeFormat.importContentTypes }
    static var writableContentTypes: [UTType] { TaskExchangeFormat.allCases.map(\.contentType) }

    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct TaskImportSummary: Equatable {
    var created: Int
    var updated: Int
    var skipped: Int
    var skippedReasons: [String]

    var imported: Int {
        created + updated
    }
}

enum TaskExchangeError: LocalizedError {
    case emptyFile
    case unsupportedFormat
    case missingColumns([String])
    case noImportableRows([String])
    case invalidEncoding

    var errorDescription: String? {
        switch self {
        case .emptyFile:
            return "The selected file is empty."
        case .unsupportedFormat:
            return "LifeTrack can import JSON, CSV, and TSV files. For Excel, export or save the sheet as CSV first."
        case .missingColumns(let columns):
            return "The file is missing required columns: \(columns.joined(separator: ", "))."
        case .noImportableRows(let reasons):
            if reasons.isEmpty {
                return "No tasks could be imported from that file."
            }

            return "No tasks could be imported. \(reasons.prefix(3).joined(separator: " "))"
        case .invalidEncoding:
            return "The file could not be read as text."
        }
    }
}

@MainActor
enum TaskExchangeManager {
    private static let csvHeaders = [
        "id",
        "title",
        "due_date",
        "due_time",
        "category",
        "category_label",
        "status",
        "priority",
        "recurrence",
        "duration_minutes",
        "notes",
        "template_action",
        "created_at",
        "updated_at",
        "deleted_at",
        "document_name",
        "document_keywords"
    ]

    static func templateData(format: TaskExchangeFormat) throws -> Data {
        let now = Date()
        let calendar = Calendar.current
        let firstDueDate = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        let secondDueDate = calendar.date(byAdding: .day, value: 7, to: now) ?? now
        let records = [
            TaskExchangeRecord(
                title: "Pay electricity bill",
                dueDateDate: dateString(firstDueDate),
                dueDateTime: "09:00",
                category: TaskCategory.finance.rawValue,
                categoryLabel: TaskCategory.finance.title,
                status: TaskExchangeStatus.inProgress.rawValue,
                priority: TaskPriority.high.rawValue,
                recurrence: TaskRecurrence.monthly.rawValue,
                durationMinutes: 20,
                notes: "Attach the invoice, confirm the amount, then mark complete."
            ),
            TaskExchangeRecord(
                title: "Book dental appointment",
                dueDateDate: dateString(secondDueDate),
                dueDateTime: "14:30",
                category: TaskCategory.health.rawValue,
                categoryLabel: TaskCategory.health.title,
                status: TaskExchangeStatus.inProgress.rawValue,
                priority: TaskPriority.normal.rawValue,
                recurrence: TaskRecurrence.none.rawValue,
                durationMinutes: 30,
                notes: "Replace these sample rows with your own tasks before importing."
            )
        ]

        switch format {
        case .json:
            let package = TaskExchangePackage(
                exportedAt: isoDateString(now),
                tasks: records
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            return try encoder.encode(package)
        case .csv, .tsv:
            let text = spreadsheetText(records: records, delimiter: format.delimiter)
            return Data(text.utf8)
        }
    }

    static func exportData(
        format: TaskExchangeFormat,
        tasks: [LifeTask],
        customCategories: [CustomTaskCategory]
    ) throws -> Data {
        let records = tasks
            .sorted { first, second in
                if first.dueDate == second.dueDate {
                    return first.title.localizedCaseInsensitiveCompare(second.title) == .orderedAscending
                }

                return first.dueDate < second.dueDate
            }
            .map { exportRecord(for: $0, customCategories: customCategories) }

        switch format {
        case .json:
            let package = TaskExchangePackage(
                exportedAt: isoDateString(Date()),
                tasks: records
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            return try encoder.encode(package)
        case .csv, .tsv:
            let text = spreadsheetText(records: records, delimiter: format.delimiter)
            return Data(text.utf8)
        }
    }

    static func shareableExportURL(
        format: TaskExchangeFormat,
        tasks: [LifeTask],
        customCategories: [CustomTaskCategory],
        fileName: String
    ) throws -> URL {
        let data = try exportData(
            format: format,
            tasks: tasks,
            customCategories: customCategories
        )
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LifeTrackTaskExports", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let sanitizedName = sanitizedFileName(fileName, fallbackExtension: format.fileExtension)
        let destinationURL = directory.appendingPathComponent(sanitizedName)

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        try data.write(to: destinationURL, options: .atomic)
        return destinationURL
    }

    static func shareableTemplateURL(
        format: TaskExchangeFormat,
        fileName: String
    ) throws -> URL {
        let data = try templateData(format: format)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LifeTrackTaskTemplates", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let sanitizedName = sanitizedFileName(fileName, fallbackExtension: format.fileExtension)
        let destinationURL = directory.appendingPathComponent(sanitizedName)

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        try data.write(to: destinationURL, options: .atomic)
        return destinationURL
    }

    static func importTasks(
        from data: Data,
        fileName: String,
        existingTasks: [LifeTask],
        customCategories: [CustomTaskCategory],
        modelContext: ModelContext
    ) throws -> TaskImportSummary {
        guard !data.isEmpty else {
            throw TaskExchangeError.emptyFile
        }

        guard let format = TaskExchangeFormat.inferred(from: fileName) else {
            throw TaskExchangeError.unsupportedFormat
        }

        let records: [TaskExchangeRecord]
        switch format {
        case .json:
            records = try decodeJSONRecords(from: data)
        case .csv, .tsv:
            guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) else {
                throw TaskExchangeError.invalidEncoding
            }
            records = try decodeSpreadsheetRecords(from: text, delimiter: format.delimiter)
        }

        return try importRecords(
            records,
            existingTasks: existingTasks,
            customCategories: customCategories,
            modelContext: modelContext
        )
    }

    private static func importRecords(
        _ records: [TaskExchangeRecord],
        existingTasks: [LifeTask],
        customCategories: [CustomTaskCategory],
        modelContext: ModelContext
    ) throws -> TaskImportSummary {
        var created = 0
        var updated = 0
        var skipped = 0
        var skippedReasons: [String] = []
        let now = Date()
        var customCategoryCache = customCategories
        var existingByID = Dictionary(uniqueKeysWithValues: existingTasks.map { ($0.id, $0) })
        var affectedTasks: [LifeTask] = []

        for (index, record) in records.enumerated() {
            let rowNumber = index + 2
            let cleanedTitle = record.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanedTitle.isEmpty else {
                skipped += 1
                skippedReasons.append("Row \(rowNumber): title is required.")
                continue
            }

            guard let dueDate = parsedDueDate(record: record) else {
                skipped += 1
                skippedReasons.append("Row \(rowNumber): due date is required.")
                continue
            }

            let taskID = parsedUUID(record.id) ?? UUID()
            let categoryRawValue = resolvedCategoryRawValue(
                record: record,
                customCategories: &customCategoryCache,
                modelContext: modelContext
            )
            let status = TaskExchangeStatus(record.status)
            let createdAt = parsedDate(record.createdAt) ?? now
            let updatedAt = parsedDate(record.updatedAt) ?? now
            let deletedAt = status == .bin ? (parsedDate(record.deletedAt) ?? now) : nil

            if let existing = existingByID[taskID] {
                apply(
                    record: record,
                    to: existing,
                    title: cleanedTitle,
                    dueDate: dueDate,
                    categoryRawValue: categoryRawValue,
                    status: status,
                    deletedAt: deletedAt,
                    updatedAt: updatedAt
                )
                updated += 1
                affectedTasks.append(existing)
            } else {
                let task = LifeTask(
                    id: taskID,
                    title: cleanedTitle,
                    category: TaskCategory(rawValue: categoryRawValue) ?? .other,
                    categoryRawValue: categoryRawValue,
                    dueDate: dueDate,
                    isCompleted: status == .done,
                    notes: record.notes ?? "",
                    templateAction: TaskTemplateAction(rawValue: record.templateAction ?? "") ?? .none,
                    priority: TaskPriority(rawValue: normalizedRawValue(record.priority)) ?? .normal,
                    recurrence: TaskRecurrence(rawValue: normalizedRawValue(record.recurrence)) ?? .none,
                    estimatedDurationMinutes: sanitizedDuration(record.durationMinutes),
                    deletedAt: deletedAt,
                    createdAt: createdAt,
                    updatedAt: updatedAt
                )
                modelContext.insert(task)
                existingByID[taskID] = task
                created += 1
                affectedTasks.append(task)
            }
        }

        if created + updated == 0 {
            throw TaskExchangeError.noImportableRows(skippedReasons)
        }

        try? modelContext.save()

        for task in affectedTasks {
            TaskLifecycleManager.synchronizeReminder(for: task, customCategories: customCategoryCache)
        }

        return TaskImportSummary(
            created: created,
            updated: updated,
            skipped: skipped,
            skippedReasons: skippedReasons
        )
    }

    private static func apply(
        record: TaskExchangeRecord,
        to task: LifeTask,
        title: String,
        dueDate: Date,
        categoryRawValue: String,
        status: TaskExchangeStatus,
        deletedAt: Date?,
        updatedAt: Date
    ) {
        task.title = title
        task.dueDate = dueDate
        task.categoryRawValue = categoryRawValue
        task.isCompleted = status == .done
        task.deletedAt = deletedAt
        task.notes = record.notes ?? ""
        task.templateAction = TaskTemplateAction(rawValue: record.templateAction ?? "") ?? .none
        task.priority = TaskPriority(rawValue: normalizedRawValue(record.priority)) ?? .normal
        task.recurrence = TaskRecurrence(rawValue: normalizedRawValue(record.recurrence)) ?? .none
        task.estimatedDurationMinutes = sanitizedDuration(record.durationMinutes)
        task.updatedAt = updatedAt
    }

    private static func exportRecord(
        for task: LifeTask,
        customCategories: [CustomTaskCategory]
    ) -> TaskExchangeRecord {
        let categoryOption = task.categoryOption(customCategories: customCategories)
        return TaskExchangeRecord(
            id: task.id.uuidString,
            title: task.title,
            dueDate: isoDateString(task.dueDate),
            dueDateLocal: localDateTimeString(task.dueDate),
            dueDateDate: dateString(task.dueDate),
            dueDateTime: timeString(task.dueDate),
            category: task.categoryRawValue,
            categoryLabel: categoryOption.title,
            status: TaskExchangeStatus(task).rawValue,
            priority: task.priority.rawValue,
            recurrence: task.recurrence.rawValue,
            durationMinutes: task.scheduledDurationMinutes,
            notes: task.notes,
            templateAction: task.templateAction.rawValue,
            createdAt: isoDateString(task.createdAt),
            updatedAt: isoDateString(task.updatedAt),
            deletedAt: task.deletedAt.map(isoDateString),
            documentDisplayName: task.documentDisplayName,
            documentKeywords: task.documentKeywords
        )
    }

    private static func decodeJSONRecords(from data: Data) throws -> [TaskExchangeRecord] {
        let decoder = JSONDecoder()

        if let package = try? decoder.decode(TaskExchangePackage.self, from: data) {
            return package.tasks
        }

        return try decoder.decode([TaskExchangeRecord].self, from: data)
    }

    private static func decodeSpreadsheetRecords(
        from text: String,
        delimiter: Character
    ) throws -> [TaskExchangeRecord] {
        let rows = CSVCodec.decode(text, delimiter: delimiter)
        guard !rows.isEmpty else {
            throw TaskExchangeError.emptyFile
        }

        let headers = rows[0].map(normalizedHeader)
        let hasTitle = headers.contains("title") || headers.contains("task") || headers.contains("name")
        let hasDate = headers.contains("due_date") || headers.contains("date") || headers.contains("due_at") || headers.contains("due")

        var missingColumns: [String] = []
        if !hasTitle {
            missingColumns.append("title")
        }
        if !hasDate {
            missingColumns.append("due_date")
        }
        if !missingColumns.isEmpty {
            throw TaskExchangeError.missingColumns(missingColumns)
        }

        return rows.dropFirst().compactMap { row in
            guard row.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
                return nil
            }

            let values = Dictionary(uniqueKeysWithValues: headers.enumerated().map { index, header in
                (header, index < row.count ? row[index] : "")
            })

            return TaskExchangeRecord(
                id: firstValue(in: values, keys: ["id", "task_id", "uuid"]),
                title: firstValue(in: values, keys: ["title", "task", "name"]) ?? "",
                dueDate: firstValue(in: values, keys: ["due_at", "due", "due_datetime", "due_date_time", "due_date_time_iso"]),
                dueDateLocal: firstValue(in: values, keys: ["due_date_local", "due_local", "local_due_date"]),
                dueDateDate: firstValue(in: values, keys: ["due_date", "date", "day"]),
                dueDateTime: firstValue(in: values, keys: ["due_time", "time"]),
                category: firstValue(in: values, keys: ["category", "type", "label"]),
                categoryLabel: firstValue(in: values, keys: ["category_label", "label_name", "type_label"]),
                status: firstValue(in: values, keys: ["status", "state", "progress", "is_completed", "completed"]),
                priority: firstValue(in: values, keys: ["priority"]),
                recurrence: firstValue(in: values, keys: ["recurrence", "repeat", "repeats"]),
                durationMinutes: Int(firstValue(in: values, keys: ["duration_minutes", "duration", "minutes"]) ?? ""),
                notes: firstValue(in: values, keys: ["notes", "note", "description"]),
                templateAction: firstValue(in: values, keys: ["template_action", "template"]),
                createdAt: firstValue(in: values, keys: ["created_at", "created"]),
                updatedAt: firstValue(in: values, keys: ["updated_at", "updated"]),
                deletedAt: firstValue(in: values, keys: ["deleted_at", "deleted"]),
                documentDisplayName: firstValue(in: values, keys: ["document_name", "document", "file_name"]),
                documentKeywords: firstValue(in: values, keys: ["document_keywords", "keywords"])?
                    .components(separatedBy: CharacterSet(charactersIn: ";,\n"))
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )
        }
    }

    private static func spreadsheetText(records: [TaskExchangeRecord], delimiter: Character) -> String {
        var rows: [[String]] = [csvHeaders]
        rows.append(contentsOf: records.map(spreadsheetRow))

        return CSVCodec.encode(rows, delimiter: delimiter)
    }

    private static func sanitizedFileName(_ fileName: String, fallbackExtension: String) -> String {
        let cleanedName = fileName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = "LifeTrack Tasks.\(fallbackExtension)"
        let resolvedName = cleanedName.isEmpty ? fallback : cleanedName

        if URL(fileURLWithPath: resolvedName).pathExtension.isEmpty {
            return "\(resolvedName).\(fallbackExtension)"
        }

        return resolvedName
    }

    private static func spreadsheetRow(for record: TaskExchangeRecord) -> [String] {
        let duration = record.durationMinutes.map(String.init) ?? ""
        let keywords = record.documentKeywords?.joined(separator: "; ") ?? ""

        return [
            record.id ?? "",
            record.title,
            record.dueDateDate ?? "",
            record.dueDateTime ?? "",
            record.category ?? "",
            record.categoryLabel ?? "",
            record.status ?? TaskExchangeStatus.inProgress.rawValue,
            record.priority ?? TaskPriority.normal.rawValue,
            record.recurrence ?? TaskRecurrence.none.rawValue,
            duration,
            record.notes ?? "",
            record.templateAction ?? "",
            record.createdAt ?? "",
            record.updatedAt ?? "",
            record.deletedAt ?? "",
            record.documentDisplayName ?? "",
            keywords
        ]
    }

    private static func resolvedCategoryRawValue(
        record: TaskExchangeRecord,
        customCategories: inout [CustomTaskCategory],
        modelContext: ModelContext
    ) -> String {
        let categoryText = [record.category, record.categoryLabel]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? ""

        if let builtIn = TaskCategory.allCases.first(where: { category in
            category.rawValue.caseInsensitiveCompare(categoryText) == .orderedSame ||
                category.title.caseInsensitiveCompare(categoryText) == .orderedSame
        }) {
            return builtIn.rawValue
        }

        if categoryText.lowercased().hasPrefix("custom:") {
            if let custom = customCategories.first(where: { $0.rawValue.caseInsensitiveCompare(categoryText) == .orderedSame }) {
                return custom.rawValue
            }

            let uuidText = String(categoryText.dropFirst("custom:".count))
            if let id = UUID(uuidString: uuidText) {
                let title = record.categoryLabel?.trimmingCharacters(in: .whitespacesAndNewlines)
                let custom = CustomTaskCategory(
                    id: id,
                    title: title?.isEmpty == false ? title! : "Imported",
                    symbolName: "tag",
                    colorHex: colorHex(for: title ?? uuidText)
                )
                modelContext.insert(custom)
                customCategories.append(custom)
                return custom.rawValue
            }
        }

        guard !categoryText.isEmpty else {
            return TaskCategory.other.rawValue
        }

        if let existing = customCategories.first(where: { $0.title.caseInsensitiveCompare(categoryText) == .orderedSame }) {
            return existing.rawValue
        }

        let custom = CustomTaskCategory(
            title: categoryText,
            symbolName: "tag",
            colorHex: colorHex(for: categoryText)
        )
        modelContext.insert(custom)
        customCategories.append(custom)
        return custom.rawValue
    }

    private static func colorHex(for text: String) -> Int {
        let palette = [0x3159D9, 0x6A5AE0, 0x2F7E66, 0xD08B2E, 0xC94A4A, 0xB54A73, 0x009A84, 0xE5482E]
        let index = abs(text.hashValue) % palette.count
        return palette[index]
    }

    private static func sanitizedDuration(_ minutes: Int?) -> Int {
        min(max(minutes ?? 30, 5), 24 * 60)
    }

    private static func normalizedHeader(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: ".", with: "_")
    }

    private static func normalizedRawValue(_ value: String?) -> String {
        value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "_") ?? ""
    }

    private static func firstValue(in values: [String: String], keys: [String]) -> String? {
        keys
            .compactMap { values[$0]?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    private static func parsedDueDate(record: TaskExchangeRecord) -> Date? {
        for value in [record.dueDate, record.dueDateLocal].compactMap({ $0 }) {
            if let date = parsedDate(value) {
                return date
            }
        }

        guard let dateText = record.dueDateDate?.trimmingCharacters(in: .whitespacesAndNewlines), !dateText.isEmpty else {
            return nil
        }

        let timeText = record.dueDateTime?.trimmingCharacters(in: .whitespacesAndNewlines)
        return parsedDateAndTime(dateText: dateText, timeText: timeText?.isEmpty == false ? timeText : nil)
    }

    private static func parsedDateAndTime(dateText: String, timeText: String?) -> Date? {
        if let timeText {
            let text = [dateText, timeText].joined(separator: " ")
            if let date = parsedDate(text) {
                return date
            }
        } else if dateText.contains(":"),
                  let date = parsedDate(dateText) {
            return date
        }

        guard let dateOnly = parsedDateOnly(dateText) else {
            return nil
        }

        let calendar = Calendar.current
        let time = parsedTimeOnly(timeText ?? "09:00") ?? (hour: 9, minute: 0)
        return calendar.date(
            bySettingHour: time.hour,
            minute: time.minute,
            second: 0,
            of: dateOnly
        )
    }

    private static func parsedDate(_ text: String?) -> Date? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }

        if let date = isoFormatter(includeFractionalSeconds: true).date(from: text) ??
            isoFormatter(includeFractionalSeconds: false).date(from: text) {
            return date
        }

        for format in [
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd h:mm a",
            "yyyy-MM-dd'T'HH:mm",
            "yyyy/MM/dd HH:mm",
            "dd/MM/yyyy HH:mm",
            "MM/dd/yyyy HH:mm",
            "dd MMM yyyy HH:mm",
            "MMM d, yyyy HH:mm",
            "yyyy-MM-dd",
            "yyyy/MM/dd",
            "dd/MM/yyyy",
            "MM/dd/yyyy",
            "dd MMM yyyy",
            "MMM d, yyyy"
        ] {
            let formatter = dateFormatter(format)
            if let date = formatter.date(from: text) {
                return date
            }
        }

        return nil
    }

    private static func parsedDateOnly(_ text: String) -> Date? {
        for format in ["yyyy-MM-dd", "yyyy/MM/dd", "dd/MM/yyyy", "MM/dd/yyyy", "dd MMM yyyy", "MMM d, yyyy"] {
            if let date = dateFormatter(format).date(from: text) {
                return date
            }
        }

        return nil
    }

    private static func parsedTimeOnly(_ text: String) -> (hour: Int, minute: Int)? {
        for format in ["HH:mm", "H:mm", "h:mm a", "h:mma"] {
            let formatter = dateFormatter(format)
            if let date = formatter.date(from: text) {
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                if let hour = components.hour, let minute = components.minute {
                    return (hour, minute)
                }
            }
        }

        return nil
    }

    private static func parsedUUID(_ text: String?) -> UUID? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }

        return UUID(uuidString: text)
    }

    private static func isoDateString(_ date: Date) -> String {
        isoFormatter(includeFractionalSeconds: true).string(from: date)
    }

    private static func localDateTimeString(_ date: Date) -> String {
        dateFormatter("yyyy-MM-dd HH:mm").string(from: date)
    }

    private static func dateString(_ date: Date) -> String {
        dateFormatter("yyyy-MM-dd").string(from: date)
    }

    private static func timeString(_ date: Date) -> String {
        dateFormatter("HH:mm").string(from: date)
    }

    private static func isoFormatter(includeFractionalSeconds: Bool) -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = includeFractionalSeconds ? [.withInternetDateTime, .withFractionalSeconds] : [.withInternetDateTime]
        return formatter
    }

    private static func dateFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter
    }
}

private struct TaskExchangePackage: Codable {
    var appName = "LifeTrack"
    var schemaVersion = 1
    let exportedAt: String
    let tasks: [TaskExchangeRecord]
}

private struct TaskExchangeRecord: Codable {
    var id: String?
    var title: String
    var dueDate: String?
    var dueDateLocal: String?
    var dueDateDate: String?
    var dueDateTime: String?
    var category: String?
    var categoryLabel: String?
    var status: String?
    var priority: String?
    var recurrence: String?
    var durationMinutes: Int?
    var notes: String?
    var templateAction: String?
    var createdAt: String?
    var updatedAt: String?
    var deletedAt: String?
    var documentDisplayName: String?
    var documentKeywords: [String]?

    init(
        id: String? = nil,
        title: String,
        dueDate: String? = nil,
        dueDateLocal: String? = nil,
        dueDateDate: String? = nil,
        dueDateTime: String? = nil,
        category: String? = nil,
        categoryLabel: String? = nil,
        status: String? = nil,
        priority: String? = nil,
        recurrence: String? = nil,
        durationMinutes: Int? = nil,
        notes: String? = nil,
        templateAction: String? = nil,
        createdAt: String? = nil,
        updatedAt: String? = nil,
        deletedAt: String? = nil,
        documentDisplayName: String? = nil,
        documentKeywords: [String]? = nil
    ) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.dueDateLocal = dueDateLocal
        self.dueDateDate = dueDateDate
        self.dueDateTime = dueDateTime
        self.category = category
        self.categoryLabel = categoryLabel
        self.status = status
        self.priority = priority
        self.recurrence = recurrence
        self.durationMinutes = durationMinutes
        self.notes = notes
        self.templateAction = templateAction
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.documentDisplayName = documentDisplayName
        self.documentKeywords = documentKeywords
    }
}

private enum TaskExchangeStatus: String {
    case inProgress = "in_progress"
    case done
    case bin

    init(_ task: LifeTask) {
        if task.isDeleted {
            self = .bin
        } else if task.isCompleted {
            self = .done
        } else {
            self = .inProgress
        }
    }

    init(_ value: String?) {
        let normalized = value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_") ?? ""

        switch normalized {
        case "done", "complete", "completed", "finished", "true", "yes", "1":
            self = .done
        case "bin", "trash", "deleted", "delete", "archived":
            self = .bin
        default:
            self = .inProgress
        }
    }
}

private enum CSVCodec {
    static func encode(_ rows: [[String]], delimiter: Character) -> String {
        rows
            .map { row in
                row.map { escape($0, delimiter: delimiter) }.joined(separator: String(delimiter))
            }
            .joined(separator: "\n")
    }

    static func decode(_ text: String, delimiter: Character) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var isInsideQuotes = false
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]

            if isInsideQuotes {
                if character == "\"" {
                    let nextIndex = text.index(after: index)
                    if nextIndex < text.endIndex, text[nextIndex] == "\"" {
                        field.append("\"")
                        index = nextIndex
                    } else {
                        isInsideQuotes = false
                    }
                } else {
                    field.append(character)
                }
            } else if character == "\"" {
                isInsideQuotes = true
            } else if character == delimiter {
                row.append(field)
                field = ""
            } else if character == "\n" {
                row.append(field)
                rows.append(row)
                row = []
                field = ""
            } else if character == "\r" {
                let nextIndex = text.index(after: index)
                if nextIndex < text.endIndex, text[nextIndex] == "\n" {
                    index = nextIndex
                }
                row.append(field)
                rows.append(row)
                row = []
                field = ""
            } else {
                field.append(character)
            }

            index = text.index(after: index)
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }

        return rows.filter { row in
            row.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
    }

    private static func escape(_ value: String, delimiter: Character) -> String {
        let needsQuotes = value.contains(delimiter) ||
            value.contains("\n") ||
            value.contains("\r") ||
            value.contains("\"")

        guard needsQuotes else {
            return value
        }

        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
