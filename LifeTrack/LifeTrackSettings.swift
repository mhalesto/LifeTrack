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
