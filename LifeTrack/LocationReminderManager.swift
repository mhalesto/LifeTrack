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
        let content = UNMutableNotificationContent()
        content.title = task.locationReminderOnArrival ? "You've arrived!" : "You're leaving!"
        content.subtitle = task.title
        content.body = task.locationReminderName.map { "Near \($0)" } ?? ""
        content.sound = .default
        content.categoryIdentifier = ReminderScheduler.categoryIdentifier
        content.userInfo = [
            ReminderScheduler.taskIDUserInfoKey: task.id.uuidString,
            ReminderScheduler.taskTitleUserInfoKey: task.title
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
}
