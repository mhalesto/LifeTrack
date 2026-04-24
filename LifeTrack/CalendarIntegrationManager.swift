//
//  CalendarIntegrationManager.swift
//  LifeTrack
//

import Combine
import EventKit
import Foundation

struct CalendarBusyBlock: Identifiable, Hashable {
    let id: String
    let title: String
    let calendarTitle: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let isAllDay: Bool

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Busy event" : trimmed
    }

    var detailLine: String {
        if let location, !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\(calendarTitle) · \(location)"
        }

        return calendarTitle
    }

    var shareLabel: String {
        "Busy (Apple Calendar)"
    }
}

@MainActor
final class CalendarIntegrationManager: ObservableObject {
    enum AccessError: LocalizedError {
        case accessUnavailable
        case noWritableCalendar

        var errorDescription: String? {
            switch self {
            case .accessUnavailable:
                return "Calendar access is required to sync scheduled blocks back to Apple Calendar."
            case .noWritableCalendar:
                return "No writable Apple Calendar was found for new events."
            }
        }
    }

    static let shared = CalendarIntegrationManager()

    @Published private(set) var authorizationStatus: EKAuthorizationStatus
    @Published private(set) var cachedBusyBlocks: [CalendarBusyBlock] = []
    @Published private(set) var loadedRange: DateInterval?
    @Published private(set) var isLoadingBusyBlocks = false
    @Published private(set) var isRequestingAccess = false
    @Published private(set) var lastErrorMessage: String?

    private let eventStore = EKEventStore()
    private var storeChangedObserver: NSObjectProtocol?

    private init() {
        authorizationStatus = Self.currentAuthorizationStatus()
        storeChangedObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.refreshAuthorizationStatus()

                guard let loadedRange = self.loadedRange else {
                    return
                }

                await self.loadBusyBlocks(in: loadedRange, force: true)
            }
        }
    }

    deinit {
        if let storeChangedObserver {
            NotificationCenter.default.removeObserver(storeChangedObserver)
        }
    }

    var hasReadAccess: Bool {
        switch authorizationStatus {
        case .authorized, .fullAccess:
            return true
        default:
            return false
        }
    }

    var needsPermissionPrompt: Bool {
        switch authorizationStatus {
        case .notDetermined, .writeOnly:
            return true
        default:
            return false
        }
    }

    var accessSummary: String {
        switch authorizationStatus {
        case .authorized, .fullAccess:
            return "Apple Calendar busy times are included in planning and availability."
        case .notDetermined:
            return "Connect Apple Calendar to keep meetings and appointments out of your task plan."
        case .writeOnly:
            return "LifeTrack needs full calendar access to read your busy times."
        case .denied, .restricted:
            return "Calendar access is off. Enable it in Settings to use live busy times."
        @unknown default:
            return "Calendar access status is unavailable right now."
        }
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = Self.currentAuthorizationStatus()
    }

    func requestAccessIfNeeded() async -> Bool {
        refreshAuthorizationStatus()

        guard !hasReadAccess else {
            return true
        }

        guard needsPermissionPrompt else {
            lastErrorMessage = AccessError.accessUnavailable.localizedDescription
            return false
        }

        isRequestingAccess = true
        defer { isRequestingAccess = false }

        do {
            let granted = try await eventStore.requestFullAccessToEvents()

            refreshAuthorizationStatus()

            guard granted && hasReadAccess else {
                lastErrorMessage = AccessError.accessUnavailable.localizedDescription
                return false
            }

            if let loadedRange {
                await loadBusyBlocks(in: loadedRange, force: true)
            }

            return true
        } catch {
            refreshAuthorizationStatus()
            lastErrorMessage = error.localizedDescription
            return false
        }
    }

    func loadBusyBlocks(in requestedRange: DateInterval, force: Bool = false) async {
        refreshAuthorizationStatus()

        let targetRange: DateInterval
        if let loadedRange, !force {
            if loadedRange.contains(requestedRange) {
                return
            }

            targetRange = loadedRange.union(with: requestedRange)
        } else {
            targetRange = requestedRange
        }

        guard hasReadAccess else {
            loadedRange = targetRange
            cachedBusyBlocks = []
            return
        }

        isLoadingBusyBlocks = true
        defer { isLoadingBusyBlocks = false }

        cachedBusyBlocks = fetchBusyBlocks(in: targetRange)
        loadedRange = targetRange
        lastErrorMessage = nil
    }

    func busyBlocks(overlapping interval: DateInterval) -> [CalendarBusyBlock] {
        cachedBusyBlocks
            .filter { $0.endDate > interval.start && $0.startDate < interval.end }
            .sorted { first, second in
                if first.startDate == second.startDate {
                    return first.endDate < second.endDate
                }

                return first.startDate < second.startDate
            }
    }

    func upsertSyncedEvent(for task: LifeTask, startDate: Date, endDate: Date) throws {
        guard hasReadAccess else {
            throw AccessError.accessUnavailable
        }

        let calendar = eventStore.defaultCalendarForNewEvents ??
            eventStore.calendars(for: .event).first(where: \.allowsContentModifications)

        guard let calendar else {
            throw AccessError.noWritableCalendar
        }

        let event = syncedEvent(for: task.id) ?? EKEvent(eventStore: eventStore)
        event.calendar = calendar
        event.title = task.title
        event.startDate = startDate
        event.endDate = max(endDate, startDate.addingTimeInterval(5 * 60))
        event.isAllDay = false
        event.location = task.locationReminderName
        event.notes = eventNotes(for: task)

        if let meetingLink = task.advancedFields[AdvancedTaskField.meetingLink.rawValue],
           let url = URL(string: meetingLink.trimmingCharacters(in: .whitespacesAndNewlines)),
           !meetingLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            event.url = url
        }

        try eventStore.save(event, span: .thisEvent, commit: true)
        CalendarSyncedEventStore.set(eventIdentifier: event.eventIdentifier, for: task.id)
    }

    func removeSyncedEvent(for taskID: UUID) throws {
        guard hasReadAccess else {
            throw AccessError.accessUnavailable
        }

        guard let eventIdentifier = CalendarSyncedEventStore.eventIdentifier(for: taskID) else {
            return
        }

        guard let event = eventStore.event(withIdentifier: eventIdentifier) else {
            CalendarSyncedEventStore.set(eventIdentifier: nil, for: taskID)
            return
        }

        try eventStore.remove(event, span: .thisEvent, commit: true)
        CalendarSyncedEventStore.set(eventIdentifier: nil, for: taskID)
    }

    private func fetchBusyBlocks(in interval: DateInterval) -> [CalendarBusyBlock] {
        let predicate = eventStore.predicateForEvents(
            withStart: interval.start,
            end: interval.end,
            calendars: nil
        )

        return eventStore.events(matching: predicate)
            .filter(shouldInclude(_:))
            .map { event in
                CalendarBusyBlock(
                    id: "\(event.eventIdentifier ?? UUID().uuidString)-\(event.startDate.timeIntervalSince1970)",
                    title: event.title ?? "",
                    calendarTitle: event.calendar.title,
                    startDate: event.startDate,
                    endDate: max(event.endDate, event.startDate.addingTimeInterval(5 * 60)),
                    location: event.location,
                    isAllDay: event.isAllDay
                )
            }
            .sorted { first, second in
                if first.startDate == second.startDate {
                    return first.endDate < second.endDate
                }

                return first.startDate < second.startDate
            }
    }

    private func shouldInclude(_ event: EKEvent) -> Bool {
        guard !event.isAllDay else {
            return false
        }

        if event.status == .canceled {
            return false
        }

        if event.availability == .free {
            return false
        }

        return event.endDate > event.startDate
    }

    private func syncedEvent(for taskID: UUID) -> EKEvent? {
        guard let eventIdentifier = CalendarSyncedEventStore.eventIdentifier(for: taskID) else {
            return nil
        }

        guard let event = eventStore.event(withIdentifier: eventIdentifier) else {
            CalendarSyncedEventStore.set(eventIdentifier: nil, for: taskID)
            return nil
        }

        return event
    }

    private func eventNotes(for task: LifeTask) -> String {
        var parts: [String] = []
        let trimmedNotes = task.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNotes.isEmpty {
            parts.append(trimmedNotes)
        }

        parts.append("Synced from LifeTrack")
        parts.append("LifeTrack Task ID: \(task.id.uuidString)")
        return parts.joined(separator: "\n\n")
    }

    private static func currentAuthorizationStatus() -> EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }
}

private enum CalendarSyncedEventStore {
    private static let defaults = UserDefaults.standard

    static func eventIdentifier(for taskID: UUID) -> String? {
        loadMapping()[taskID.uuidString]
    }

    static func set(eventIdentifier: String?, for taskID: UUID) {
        var mapping = loadMapping()
        if let eventIdentifier, !eventIdentifier.isEmpty {
            mapping[taskID.uuidString] = eventIdentifier
        } else {
            mapping.removeValue(forKey: taskID.uuidString)
        }

        guard let data = try? JSONEncoder().encode(mapping) else {
            return
        }

        defaults.set(data, forKey: LifeTrackSettings.Keys.calendarSyncedEventMap)
    }

    private static func loadMapping() -> [String: String] {
        guard let data = defaults.data(forKey: LifeTrackSettings.Keys.calendarSyncedEventMap),
              let mapping = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }

        return mapping
    }
}

private extension DateInterval {
    func contains(_ other: DateInterval) -> Bool {
        start <= other.start && end >= other.end
    }

    func union(with other: DateInterval) -> DateInterval {
        DateInterval(start: min(start, other.start), end: max(end, other.end))
    }
}
