//
//  LifeTrackShareTheme.swift
//  LifeTrackShareExtension
//
//  Minimal self-contained palette mirroring the LifeTrack app's Focus theme so
//  the share sheet matches without pulling the full app theme (which depends on
//  settings, UIApplication, TaskCategory, etc.).
//

import SwiftUI
import UIKit

enum LifeTrackShareTheme {
    static let accent = Color(shareHex: 0x3159D9)
    static let accentDeep = Color(shareHex: 0x243FA3)
    static let accentSoft = Color.dynamic(
        light: Color(shareHex: 0xE8EEFF),
        dark: Color(shareHex: 0x1D2A57)
    )

    static let backgroundTop = Color.dynamic(
        light: Color(shareHex: 0xF8FAFF),
        dark: Color(shareHex: 0x0E1019)
    )
    static let backgroundBottom = Color.dynamic(
        light: Color(shareHex: 0xEEF3F8),
        dark: Color(shareHex: 0x151827)
    )

    static let cardBackground = Color.dynamic(
        light: Color.white,
        dark: Color(shareHex: 0x1B1F2B)
    )
    static let cardElevated = Color.dynamic(
        light: Color.white,
        dark: Color(shareHex: 0x1F2431)
    )
    static let inputSurface = Color.dynamic(
        light: Color(shareHex: 0xF2F5FB),
        dark: Color(shareHex: 0x141826)
    )

    static let hairline = Color.dynamic(
        light: Color(shareHex: 0xDCE1ED),
        dark: Color(shareHex: 0x2D3345)
    )

    static let primaryText = Color.dynamic(
        light: Color(shareHex: 0x111827),
        dark: Color(shareHex: 0xF5F6FB)
    )
    static let secondaryText = Color.dynamic(
        light: Color(shareHex: 0x5F6673),
        dark: Color(shareHex: 0xA0A7BA)
    )
    static let placeholderText = Color.dynamic(
        light: Color(shareHex: 0x8791A1),
        dark: Color(shareHex: 0x6B7284)
    )

    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accentDeep.mixedShare(with: accent, amount: 0.18)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var appBackground: LinearGradient {
        LinearGradient(
            colors: [backgroundTop, backgroundBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension Color {
    init(shareHex hex: UInt, alpha: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    static func dynamic(light: Color, dark: Color) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }

    func mixedShare(with other: Color, amount: Double) -> Color {
        let clamped = min(max(amount, 0), 1)
        let source = UIColor(self).shareRGBA
        let target = UIColor(other).shareRGBA
        return Color(
            .sRGB,
            red: source.red + (target.red - source.red) * clamped,
            green: source.green + (target.green - source.green) * clamped,
            blue: source.blue + (target.blue - source.blue) * clamped,
            opacity: source.alpha + (target.alpha - source.alpha) * clamped
        )
    }
}

private extension UIColor {
    var shareRGBA: (red: Double, green: Double, blue: Double, alpha: Double) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        if getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return (Double(red), Double(green), Double(blue), Double(alpha))
        }
        var white: CGFloat = 0
        if getWhite(&white, alpha: &alpha) {
            return (Double(white), Double(white), Double(white), Double(alpha))
        }
        return (0, 0, 0, 1)
    }
}
