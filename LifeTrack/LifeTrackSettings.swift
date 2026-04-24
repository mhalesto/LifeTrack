//
//  LifeTrackSettings.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import Foundation
import UIKit
import WidgetKit

nonisolated enum LifeTrackSharedGroup {
    static let suiteName = "group.com.currenttech.LifeTrack"
    static var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }
}

nonisolated struct FocusWidgetSnapshot: Codable {
    struct Item: Codable, Identifiable {
        let id: String
        let title: String
        let dueDate: Date
        let isOverdue: Bool
        let isDueToday: Bool
    }

    static let userDefaultsKey = "widget.focusSnapshot"

    let generatedAt: Date
    let items: [Item]
    let overdueCount: Int
    let dueTodayCount: Int
    let upcomingCount: Int
}

enum FocusWidgetSnapshotPublisher {
    @MainActor
    static func publish(
        focusTasks: [LifeTask],
        overdueCount: Int,
        dueTodayCount: Int,
        upcomingCount: Int,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) {
        let items: [FocusWidgetSnapshot.Item] = focusTasks.prefix(5).map { task in
            FocusWidgetSnapshot.Item(
                id: task.id.uuidString,
                title: task.title,
                dueDate: task.dueDate,
                isOverdue: task.dueDate < referenceDate,
                isDueToday: calendar.isDateInToday(task.dueDate)
            )
        }

        let snapshot = FocusWidgetSnapshot(
            generatedAt: referenceDate,
            items: items,
            overdueCount: overdueCount,
            dueTodayCount: dueTodayCount,
            upcomingCount: upcomingCount
        )

        guard let defaults = LifeTrackSharedGroup.defaults,
              let data = try? JSONEncoder.snapshotEncoder.encode(snapshot)
        else {
            return
        }

        defaults.set(data, forKey: FocusWidgetSnapshot.userDefaultsKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

extension JSONEncoder {
    static let snapshotEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

extension JSONDecoder {
    static let snapshotDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

nonisolated enum LifeTrackSettings {
    nonisolated enum Keys {
        static let nickname = "LifeTrack.settings.nickname"
        static let themeID = "LifeTrack.settings.themeID"
        static let darkModeEnabled = "LifeTrack.settings.darkModeEnabled"
        static let appearanceMode = "LifeTrack.settings.appearanceMode"
        static let appFontChoice = "LifeTrack.settings.appFontChoice"
        static let titleTextScale = "LifeTrack.settings.titleTextScale"
        static let bodyTextScale = "LifeTrack.settings.bodyTextScale"
        static let captionTextScale = "LifeTrack.settings.captionTextScale"
        static let avatarVersion = "LifeTrack.settings.avatarVersion"
        static let animationsEnabled = "LifeTrack.settings.animationsEnabled"
        static let colorStrength = "LifeTrack.settings.colorStrength"
        static let binRetentionPeriod = "LifeTrack.settings.binRetentionPeriod"
        static let completedArchivePeriod = "LifeTrack.settings.completedArchivePeriod"
        static let lastDashboardMessageText = "LifeTrack.settings.lastDashboardMessageText"
        static let reminderActionTipPending = "LifeTrack.notifications.reminderActionTipPending"
        static let reminderActionTipShown = "LifeTrack.notifications.reminderActionTipShown"
        static let isProEnabled = "LifeTrack.settings.isProEnabled"
        static let claudeAPIKey = "LifeTrack.settings.claudeAPIKey"
        static let lastBackupDate = "LifeTrack.settings.lastBackupDate"
        static let dashboardExperience = "LifeTrack.settings.dashboardExperience"
        static let betaShapesOpacity = "LifeTrack.settings.betaShapesOpacity"
        static let hideStatusBar = "LifeTrack.settings.hideStatusBar"
        static let moneyCurrencyCode = "LifeTrack.settings.moneyCurrencyCode"
        static let moneyCurrencyLocked = "LifeTrack.settings.moneyCurrencyLocked"
        static let calendarSyncedEventMap = "LifeTrack.settings.calendarSyncedEventMap"
    }
}

enum DashboardExperience: String, CaseIterable, Identifiable {
    case `default` = "default"
    case beta = "beta"

    var id: String { rawValue }

    static let fallback: DashboardExperience = .beta

    var title: String {
        switch self {
        case .default: "Default Dashboard"
        case .beta: "Beta Dashboard"
        }
    }

    var subtitle: String {
        switch self {
        case .default: "The stable, full-featured home screen."
        case .beta: "New layout with streaks, metrics, and quick actions."
        }
    }
}

enum TaskBinRetentionPeriod: String, CaseIterable, Identifiable {
    case immediately
    case twelveHours
    case oneDay
    case sevenDays
    case thirtyDays

    var id: String { rawValue }

    static let fallback: TaskBinRetentionPeriod = .sevenDays

    static var current: TaskBinRetentionPeriod {
        let savedValue = UserDefaults.standard.string(forKey: LifeTrackSettings.Keys.binRetentionPeriod) ?? fallback.rawValue
        return TaskBinRetentionPeriod(rawValue: savedValue) ?? fallback
    }

    var title: String {
        switch self {
        case .immediately: "Immediately"
        case .twelveHours: "12 hours"
        case .oneDay: "1 day"
        case .sevenDays: "7 days"
        case .thirtyDays: "30 days"
        }
    }

    var subtitle: String {
        switch self {
        case .immediately:
            "Skip the Bin and delete forever."
        case .twelveHours:
            "Keep deleted tasks briefly."
        case .oneDay:
            "Hold deleted tasks until tomorrow."
        case .sevenDays:
            "A balanced recovery window."
        case .thirtyDays:
            "Keep more time to restore mistakes."
        }
    }

    var duration: TimeInterval {
        switch self {
        case .immediately: 0
        case .twelveHours: 12 * 60 * 60
        case .oneDay: 24 * 60 * 60
        case .sevenDays: 7 * 24 * 60 * 60
        case .thirtyDays: 30 * 24 * 60 * 60
        }
    }

    func expirationDate(from deletedAt: Date) -> Date {
        deletedAt.addingTimeInterval(duration)
    }

    func isExpired(deletedAt: Date, referenceDate: Date = Date()) -> Bool {
        referenceDate >= expirationDate(from: deletedAt)
    }
}

enum CompletedArchivePeriod: String, CaseIterable, Identifiable {
    case off
    case thirtyDays
    case ninetyDays
    case sixMonths
    case oneYear

    var id: String { rawValue }

    static let fallback: CompletedArchivePeriod = .ninetyDays

    static var current: CompletedArchivePeriod {
        let savedValue = UserDefaults.standard.string(forKey: LifeTrackSettings.Keys.completedArchivePeriod) ?? fallback.rawValue
        return CompletedArchivePeriod(rawValue: savedValue) ?? fallback
    }

    var title: String {
        switch self {
        case .off: "Keep everything"
        case .thirtyDays: "30 days"
        case .ninetyDays: "90 days"
        case .sixMonths: "6 months"
        case .oneYear: "1 year"
        }
    }

    var subtitle: String {
        switch self {
        case .off:
            "Completed tasks stay on the dashboard forever."
        case .thirtyDays:
            "Move completed tasks to Bin after 30 days."
        case .ninetyDays:
            "A balanced archive window for most workflows."
        case .sixMonths:
            "Keep half a year of completed history on hand."
        case .oneYear:
            "Archive only after a full year of history."
        }
    }

    var ageLimit: TimeInterval? {
        switch self {
        case .off: nil
        case .thirtyDays: 30 * 24 * 60 * 60
        case .ninetyDays: 90 * 24 * 60 * 60
        case .sixMonths: 180 * 24 * 60 * 60
        case .oneYear: 365 * 24 * 60 * 60
        }
    }

    func shouldArchive(completedAt: Date, referenceDate: Date = Date()) -> Bool {
        guard let ageLimit else { return false }
        return referenceDate.timeIntervalSince(completedAt) >= ageLimit
    }
}

enum AvatarImageStore {
    private static let filename = "profile-avatar.jpg"

    static var hasAvatar: Bool {
        FileManager.default.fileExists(atPath: avatarURL.path)
    }

    static func loadAvatarImage() -> UIImage? {
        UIImage(contentsOfFile: avatarURL.path)
    }

    static func saveAvatar(data: Data) throws {
        guard let sourceImage = UIImage(data: data) else {
            throw AvatarImageError.invalidImage
        }

        try saveAvatar(image: sourceImage)
    }

    static func saveAvatar(image sourceImage: UIImage) throws {
        let image = sourceImage.preparingThumbnail(of: CGSize(width: 640, height: 640)) ?? sourceImage
        guard let jpegData = image.jpegData(compressionQuality: 0.88) else {
            throw AvatarImageError.couldNotEncode
        }

        try FileManager.default.createDirectory(
            at: avatarDirectory,
            withIntermediateDirectories: true
        )
        try jpegData.write(to: avatarURL, options: .atomic)
    }

    static func deleteAvatar() {
        try? FileManager.default.removeItem(at: avatarURL)
    }

    private static var avatarDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LifeTrack", isDirectory: true)
    }

    private static var avatarURL: URL {
        avatarDirectory.appendingPathComponent(filename)
    }
}

enum AvatarImageError: Error {
    case invalidImage
    case couldNotEncode
}
