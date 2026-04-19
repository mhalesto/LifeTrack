//
//  LifeTrackSettings.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import Foundation
import UIKit

enum LifeTrackSettings {
    enum Keys {
        static let nickname = "LifeTrack.settings.nickname"
        static let themeID = "LifeTrack.settings.themeID"
        static let avatarVersion = "LifeTrack.settings.avatarVersion"
        static let animationsEnabled = "LifeTrack.settings.animationsEnabled"
        static let colorStrength = "LifeTrack.settings.colorStrength"
        static let binRetentionPeriod = "LifeTrack.settings.binRetentionPeriod"
        static let lastDashboardMessageText = "LifeTrack.settings.lastDashboardMessageText"
        static let reminderActionTipPending = "LifeTrack.notifications.reminderActionTipPending"
        static let reminderActionTipShown = "LifeTrack.notifications.reminderActionTipShown"
        static let isProEnabled = "LifeTrack.settings.isProEnabled"
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
