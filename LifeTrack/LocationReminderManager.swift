//
//  LocationReminderManager.swift
//  LifeTrack
//

import CoreLocation
import Foundation
import UserNotifications

final class LocationReminderManager: NSObject, CLLocationManagerDelegate {
    static let shared = LocationReminderManager()

    private let locationManager = CLLocationManager()
    private let regionPrefix = "lifetrack.location."

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    // MARK: - Public

    func requestPermissionIfNeeded() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        default:
            break
        }
    }

    func scheduleRegion(for task: LifeTask) {
        guard
            let lat = task.locationReminderLatitude,
            let lon = task.locationReminderLongitude
        else { return }

        let radius = task.locationReminderRadius ?? 150
        let center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let region = CLCircularRegion(
            center: center,
            radius: radius,
            identifier: regionIdentifier(for: task.id)
        )
        region.notifyOnEntry = task.locationReminderOnArrival
        region.notifyOnExit = !task.locationReminderOnArrival

        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }
        locationManager.startMonitoring(for: region)

        scheduleLocationNotification(for: task, region: region)
    }

    func cancelRegion(for taskID: UUID) {
        let identifier = regionIdentifier(for: taskID)
        for region in locationManager.monitoredRegions
            where region.identifier == identifier {
            locationManager.stopMonitoring(for: region)
        }
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    func restoreAllRegions(from tasks: [LifeTask]) {
        for task in tasks where task.hasLocationReminder && !task.isCompleted && !task.isDeleted {
            scheduleRegion(for: task)
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        deliverIfNeeded(identifier: region.identifier, event: "arrival")
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        deliverIfNeeded(identifier: region.identifier, event: "departure")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {}

    // MARK: - Private

    private func regionIdentifier(for taskID: UUID) -> String {
        regionPrefix + taskID.uuidString
    }

    private func scheduleLocationNotification(for task: LifeTask, region: CLCircularRegion) {
        let categoryTitle = resolvedCategoryTitle(for: task)
        let statusLine = locationStatusLine(for: task)
        let detailLine = task.alertDetailLine(categoryTitle: categoryTitle, includeLocationFallback: false)

        let content = UNMutableNotificationContent()
        content.title = task.title
        content.subtitle = detailLine
        content.body = ReminderScheduler.composeBody(lines: [statusLine, "Just now"])
        content.sound = .default
        content.categoryIdentifier = ReminderScheduler.categoryIdentifier
        content.threadIdentifier = "lifetrack.task-reminders"
        if #available(iOS 15.0, *) {
            content.interruptionLevel = task.priority == .high ? .timeSensitive : .active
            content.relevanceScore = task.priority == .high ? 0.97 : 0.7
        }
        content.userInfo = [
            ReminderScheduler.taskIDUserInfoKey: task.id.uuidString,
            ReminderScheduler.taskTitleUserInfoKey: task.title,
            ReminderScheduler.categoryTitleUserInfoKey: categoryTitle,
            ReminderScheduler.dueTimestampUserInfoKey: task.dueDate.timeIntervalSince1970,
            ReminderScheduler.themeIDUserInfoKey: LifeTrackAppTheme.current.rawValue,
            ReminderScheduler.reminderStatusUserInfoKey: statusLine,
            ReminderScheduler.reminderDetailUserInfoKey: detailLine,
            ReminderScheduler.isHighPriorityUserInfoKey: task.priority == .high
        ]

        let trigger = UNLocationNotificationTrigger(region: region, repeats: false)
        let request = UNNotificationRequest(
            identifier: regionIdentifier(for: task.id),
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func deliverIfNeeded(identifier: String, event: String) {
        // Notification is already scheduled via UNLocationNotificationTrigger — iOS delivers it automatically
    }

    private func locationStatusLine(for task: LifeTask) -> String {
        if let locationName = task.locationReminderName?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !locationName.isEmpty {
            return task.locationReminderOnArrival ? "Arrived near \(locationName)" : "Leaving \(locationName)"
        }

        return task.locationReminderOnArrival ? "You've arrived" : "You're leaving"
    }

    private func resolvedCategoryTitle(for task: LifeTask) -> String {
        if let category = TaskCategory(rawValue: task.categoryRawValue) {
            return category.title
        }

        return task.categoryRawValue
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmptyValue ?? TaskCategory.other.title
    }
}

private extension String {
    var nonEmptyValue: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
