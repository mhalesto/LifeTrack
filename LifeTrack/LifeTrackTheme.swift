//
//  LifeTrackTheme.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import SwiftUI
import UIKit

enum LifeTrackFontChoice: String, CaseIterable, Identifiable {
    case appDefault
    case classic
    case rounded
    case serif

    var id: String { rawValue }

    static let fallback: LifeTrackFontChoice = .appDefault

    var title: String {
        switch self {
        case .appDefault: "App Default"
        case .classic: "Classic"
        case .rounded: "Rounded"
        case .serif: "Serif"
        }
    }

    var subtitle: String {
        switch self {
        case .appDefault: "Uses each theme's current font styling."
        case .classic: "A clean system look with neutral shapes."
        case .rounded: "Softer, friendlier curves across the app."
        case .serif: "Higher-contrast titles with a more editorial feel."
        }
    }

    func resolvedDesign(default defaultDesign: Font.Design) -> Font.Design {
        switch self {
        case .appDefault: defaultDesign
        case .classic: .default
        case .rounded: .rounded
        case .serif: .serif
        }
    }
}

enum LifeTrackTypography {
    enum Role {
        case title
        case body
        case caption
    }

    static let defaultScale = 1.0
    static let sliderStep = 0.02
    static let titleScaleRange: ClosedRange<Double> = 0.90...1.14
    static let bodyScaleRange: ClosedRange<Double> = 0.94...1.10
    static let captionScaleRange: ClosedRange<Double> = 0.92...1.08

    static var fontChoice: LifeTrackFontChoice {
        let savedChoice = UserDefaults.standard.string(forKey: LifeTrackSettings.Keys.appFontChoice) ?? LifeTrackFontChoice.fallback.rawValue
        return LifeTrackFontChoice(rawValue: savedChoice) ?? .fallback
    }

    static var titleScale: Double {
        clamped(
            UserDefaults.standard.object(forKey: LifeTrackSettings.Keys.titleTextScale) as? Double ?? defaultScale,
            role: .title
        )
    }

    static var bodyScale: Double {
        clamped(
            UserDefaults.standard.object(forKey: LifeTrackSettings.Keys.bodyTextScale) as? Double ?? defaultScale,
            role: .body
        )
    }

    static var captionScale: Double {
        clamped(
            UserDefaults.standard.object(forKey: LifeTrackSettings.Keys.captionTextScale) as? Double ?? defaultScale,
            role: .caption
        )
    }

    static func range(for role: Role) -> ClosedRange<Double> {
        switch role {
        case .title: titleScaleRange
        case .body: bodyScaleRange
        case .caption: captionScaleRange
        }
    }

    static func clamped(_ value: Double, role: Role) -> Double {
        let limits = range(for: role)
        return min(max(value, limits.lowerBound), limits.upperBound)
    }

    static func scale(for role: Role) -> Double {
        switch role {
        case .title: titleScale
        case .body: bodyScale
        case .caption: captionScale
        }
    }

    static func isDefault(fontChoiceRaw: String, titleScale: Double, bodyScale: Double, captionScale: Double) -> Bool {
        let savedChoice = LifeTrackFontChoice(rawValue: fontChoiceRaw) ?? .fallback
        return savedChoice == .appDefault
            && abs(clamped(titleScale, role: .title) - defaultScale) < 0.001
            && abs(clamped(bodyScale, role: .body) - defaultScale) < 0.001
            && abs(clamped(captionScale, role: .caption) - defaultScale) < 0.001
    }

    static func font(
        _ textStyle: Font.TextStyle,
        weight: Font.Weight = .regular,
        defaultDesign: Font.Design = LifeTrackAppTheme.current.fontDesign
    ) -> Font {
        let role = role(for: textStyle)
        let scale = scale(for: role)
        let design = fontChoice.resolvedDesign(default: defaultDesign)

        guard abs(scale - defaultScale) > 0.001 else {
            return .system(textStyle, design: design, weight: weight)
        }

        return .system(size: scaledPointSize(basePointSize(for: textStyle), role: role), weight: weight, design: design)
    }

    static func font(
        size: CGFloat,
        role: Role,
        weight: Font.Weight = .regular,
        defaultDesign: Font.Design = LifeTrackAppTheme.current.fontDesign
    ) -> Font {
        .system(
            size: scaledPointSize(size, role: role),
            weight: weight,
            design: fontChoice.resolvedDesign(default: defaultDesign)
        )
    }

    static func scaledPointSize(_ size: CGFloat, role: Role) -> CGFloat {
        size * scale(for: role)
    }

    private static func role(for textStyle: Font.TextStyle) -> Role {
        switch textStyle {
        case .largeTitle, .title, .title2, .title3, .headline:
            .title
        case .body, .callout, .subheadline:
            .body
        case .footnote, .caption, .caption2:
            .caption
        default:
            .body
        }
    }

    private static func basePointSize(for textStyle: Font.TextStyle) -> CGFloat {
        UIFont.preferredFont(forTextStyle: uiTextStyle(for: textStyle)).pointSize
    }

    private static func uiTextStyle(for textStyle: Font.TextStyle) -> UIFont.TextStyle {
        switch textStyle {
        case .largeTitle:
            .largeTitle
        case .title:
            .title1
        case .title2:
            .title2
        case .title3:
            .title3
        case .headline:
            .headline
        case .body:
            .body
        case .callout:
            .callout
        case .subheadline:
            .subheadline
        case .footnote:
            .footnote
        case .caption:
            .caption1
        case .caption2:
            .caption2
        default:
            .body
        }
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case auto
    case light
    case dark

    var id: String { rawValue }

    static let fallback: AppearanceMode = .auto

    var title: String {
        switch self {
        case .auto: "Auto"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var symbolName: String {
        switch self {
        case .auto: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.stars.fill"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .auto: nil
        case .light: .light
        case .dark: .dark
        }
    }

    func resolve(system: ColorScheme) -> ColorScheme {
        switch self {
        case .auto: system
        case .light: .light
        case .dark: .dark
        }
    }

    static var current: AppearanceMode {
        if let raw = UserDefaults.standard.string(forKey: LifeTrackSettings.Keys.appearanceMode),
           let mode = AppearanceMode(rawValue: raw) {
            return mode
        }
        if UserDefaults.standard.object(forKey: LifeTrackSettings.Keys.darkModeEnabled) != nil {
            return UserDefaults.standard.bool(forKey: LifeTrackSettings.Keys.darkModeEnabled) ? .dark : .light
        }
        return fallback
    }
}

enum LifeTrackAppTheme: String, CaseIterable, Identifiable {
    case focus
    case sage
    case dreamy
    case cobalt
    case ember

    var id: String { rawValue }

    static let fallback: LifeTrackAppTheme = .focus
    static let colorStrengthRange: ClosedRange<Double> = 0.55...1.35

    static var current: LifeTrackAppTheme {
        let savedID = UserDefaults.standard.string(forKey: LifeTrackSettings.Keys.themeID) ?? fallback.rawValue
        return LifeTrackAppTheme(rawValue: savedID) ?? fallback
    }

    static var colorStrength: Double {
        let savedValue = UserDefaults.standard.object(forKey: LifeTrackSettings.Keys.colorStrength) as? Double ?? 1
        return min(max(savedValue, colorStrengthRange.lowerBound), colorStrengthRange.upperBound)
    }

    static var isDarkModeEnabled: Bool {
        if let raw = UserDefaults.standard.string(forKey: LifeTrackSettings.Keys.appearanceMode),
           let mode = AppearanceMode(rawValue: raw) {
            switch mode {
            case .light: return false
            case .dark: return true
            case .auto: break
            }
        }
        return UserDefaults.standard.object(forKey: LifeTrackSettings.Keys.darkModeEnabled) as? Bool ?? false
    }

    var title: String {
        switch self {
        case .focus: "Focus Blue"
        case .sage: "Sage"
        case .dreamy: "Dreamy"
        case .cobalt: "Cobalt"
        case .ember: "Ember"
        }
    }

    var subtitle: String {
        switch self {
        case .focus: "Crisp, classic, and productive."
        case .sage: "Soft green calm for steady days."
        case .dreamy: "Airy lavender with a softer mood."
        case .cobalt: "Sharper blue energy for decisive days."
        case .ember: "Warm, bold, and high-contrast."
        }
    }

    var symbolName: String {
        switch self {
        case .focus: "scope"
        case .sage: "leaf"
        case .dreamy: "moon.stars"
        case .cobalt: "bolt.circle"
        case .ember: "flame"
        }
    }

    var backgroundTop: Color {
        tunedBackground(baseBackgroundTop)
    }

    var backgroundBottom: Color {
        tunedBackground(baseBackgroundBottom)
    }

    var accent: Color {
        tuned(baseAccent, vivid: vividAccent, pale: accentSoftBase)
    }

    var accentDeep: Color {
        tuned(accentDeepBase, vivid: vividAccent, pale: baseAccent)
    }

    var accentSoft: Color {
        tunedSoft(accentSoftBase)
    }

    var secondaryAccent: Color {
        tuned(secondaryAccentBase, vivid: vividAccent, pale: accentSoftBase)
    }

    var success: Color {
        tuned(statusSuccessBase, vivid: statusSuccessBase.mixed(with: vividAccent, amount: 0.28), pale: accentSoftBase)
    }

    var warning: Color {
        tuned(statusWarningBase, vivid: statusWarningBase.mixed(with: vividAccent, amount: 0.20), pale: accentSoftBase)
    }

    var danger: Color {
        tuned(statusDangerBase, vivid: statusDangerBase.mixed(with: vividAccent, amount: 0.18), pale: accentSoftBase)
    }

    var primaryText: Color {
        if LifeTrackAppTheme.isDarkModeEnabled {
            return Color(hex: 0xF5F7FA)
        }

        return switch self {
        case .focus, .sage, .dreamy: Color(hex: 0x111827)
        case .cobalt: Color(hex: 0x0B132B)
        case .ember: Color(hex: 0x21120F)
        }
    }

    var secondaryText: Color {
        if LifeTrackAppTheme.isDarkModeEnabled {
            return switch self {
            case .focus: Color(hex: 0xB1BACB)
            case .sage: Color(hex: 0xB1C3BA)
            case .dreamy: Color(hex: 0xC0BAD8)
            case .cobalt: Color(hex: 0xAEC1D9)
            case .ember: Color(hex: 0xD2B0A3)
            }
        }

        return switch self {
        case .focus, .sage, .dreamy: Color(hex: 0x5F6673)
        case .cobalt: Color(hex: 0x4E5871)
        case .ember: Color(hex: 0x66534F)
        }
    }

    var tertiaryText: Color {
        if LifeTrackAppTheme.isDarkModeEnabled {
            return switch self {
            case .focus: Color(hex: 0x778294)
            case .sage: Color(hex: 0x78857E)
            case .dreamy: Color(hex: 0x877FA0)
            case .cobalt: Color(hex: 0x798CA5)
            case .ember: Color(hex: 0x95776E)
            }
        }

        return switch self {
        case .focus, .sage, .dreamy: Color(hex: 0x8791A1)
        case .cobalt: Color(hex: 0x7E8AA5)
        case .ember: Color(hex: 0x9A827C)
        }
    }

    var placeholderText: Color {
        if LifeTrackAppTheme.isDarkModeEnabled {
            return secondaryText.opacity(0.78)
        }

        return switch self {
        case .focus, .sage, .dreamy: Color(hex: 0x596171)
        case .cobalt: Color(hex: 0x53617C)
        case .ember: Color(hex: 0x6D5750)
        }
    }

    var shadow: Color {
        let baseOpacity = LifeTrackAppTheme.isDarkModeEnabled ? 0.18 : 0.10
        return tuned(baseShadow, vivid: vividAccent, pale: accentSoftBase).opacity(baseOpacity + max(LifeTrackAppTheme.colorStrength - 1, 0) * 0.08)
    }

    var fontDesign: Font.Design {
        switch self {
        case .sage: .default
        case .ember: .serif
        case .focus, .dreamy, .cobalt: .rounded
        }
    }

    func categoryTint(for category: TaskCategory) -> Color {
        let palette = categoryTints
        let color = palette[category.themeIndex % palette.count]
        return tuned(color, vivid: color.mixed(with: vividAccent, amount: 0.34), pale: accentSoftBase)
    }

    private var baseBackgroundTop: Color {
        if LifeTrackAppTheme.isDarkModeEnabled {
            return switch self {
            case .focus: Color(hex: 0x0F141A)
            case .sage: Color(hex: 0x0F1513)
            case .dreamy: Color(hex: 0x111219)
            case .cobalt: Color(hex: 0x0E141B)
            case .ember: Color(hex: 0x131111)
            }
        }

        return switch self {
        case .focus: Color(hex: 0xF8FAFF)
        case .sage: Color(hex: 0xF7FBF8)
        case .dreamy: Color(hex: 0xFBF8FF)
        case .cobalt: Color(hex: 0xF4F8FF)
        case .ember: Color(hex: 0xFFF8F3)
        }
    }

    private var baseBackgroundBottom: Color {
        if LifeTrackAppTheme.isDarkModeEnabled {
            return switch self {
            case .focus: Color(hex: 0x090D13)
            case .sage: Color(hex: 0x090D0C)
            case .dreamy: Color(hex: 0x0A0B12)
            case .cobalt: Color(hex: 0x080C13)
            case .ember: Color(hex: 0x0B0909)
            }
        }

        return switch self {
        case .focus: Color(hex: 0xEEF3F8)
        case .sage: Color(hex: 0xEAF4EF)
        case .dreamy: Color(hex: 0xEEF2FF)
        case .cobalt: Color(hex: 0xDDEBFF)
        case .ember: Color(hex: 0xFFE7DB)
        }
    }

    private var baseAccent: Color {
        if LifeTrackAppTheme.isDarkModeEnabled {
            return switch self {
            case .focus: Color(hex: 0x73A1FF)
            case .sage: Color(hex: 0x27C66C)
            case .dreamy: Color(hex: 0xA185FF)
            case .cobalt: Color(hex: 0x37B7FF)
            case .ember: Color(hex: 0xFF946A)
            }
        }

        return switch self {
        case .focus: Color(hex: 0x3159D9)
        case .sage: Color(hex: 0x2F7E66)
        case .dreamy: Color(hex: 0x6A5AE0)
        case .cobalt: Color(hex: 0x0957FF)
        case .ember: Color(hex: 0xE5482E)
        }
    }

    private var accentDeepBase: Color {
        if LifeTrackAppTheme.isDarkModeEnabled {
            return switch self {
            case .focus: Color(hex: 0x4D73EA)
            case .sage: Color(hex: 0x179C57)
            case .dreamy: Color(hex: 0x7258E9)
            case .cobalt: Color(hex: 0x0B8CFF)
            case .ember: Color(hex: 0xEE623F)
            }
        }

        return switch self {
        case .focus: Color(hex: 0x243FA3)
        case .sage: Color(hex: 0x1E5D4A)
        case .dreamy: Color(hex: 0x4736C8)
        case .cobalt: Color(hex: 0x0030B8)
        case .ember: Color(hex: 0xA91F16)
        }
    }

    private var vividAccent: Color {
        if LifeTrackAppTheme.isDarkModeEnabled {
            return switch self {
            case .focus: Color(hex: 0x9AD1FF)
            case .sage: Color(hex: 0x5BE68F)
            case .dreamy: Color(hex: 0xE193FF)
            case .cobalt: Color(hex: 0x7BE2FF)
            case .ember: Color(hex: 0xFFB467)
            }
        }

        return switch self {
        case .focus: Color(hex: 0x6B7BFF)
        case .sage: Color(hex: 0x19A974)
        case .dreamy: Color(hex: 0xB05CFF)
        case .cobalt: Color(hex: 0x00A3FF)
        case .ember: Color(hex: 0xFF8A00)
        }
    }

    private var accentSoftBase: Color {
        if LifeTrackAppTheme.isDarkModeEnabled {
            return switch self {
            case .focus: Color(hex: 0x17253B)
            case .sage: Color(hex: 0x112419)
            case .dreamy: Color(hex: 0x211A37)
            case .cobalt: Color(hex: 0x11283E)
            case .ember: Color(hex: 0x301A15)
            }
        }

        return switch self {
        case .focus: Color(hex: 0xE8EEFF)
        case .sage: Color(hex: 0xE7F4EF)
        case .dreamy: Color(hex: 0xEFECFF)
        case .cobalt: Color(hex: 0xDCEBFF)
        case .ember: Color(hex: 0xFFE7D6)
        }
    }

    private var secondaryAccentBase: Color {
        if LifeTrackAppTheme.isDarkModeEnabled {
            return switch self {
            case .focus: Color(hex: 0x65C3FF)
            case .sage: Color(hex: 0x37D87C)
            case .dreamy: Color(hex: 0xD978FF)
            case .cobalt: Color(hex: 0x5FD9FF)
            case .ember: Color(hex: 0xFFBA73)
            }
        }

        return switch self {
        case .focus: Color(hex: 0x5865B8)
        case .sage: Color(hex: 0x519078)
        case .dreamy: Color(hex: 0x946FE8)
        case .cobalt: Color(hex: 0x00A3FF)
        case .ember: Color(hex: 0xFF8A00)
        }
    }

    private var baseShadow: Color {
        if LifeTrackAppTheme.isDarkModeEnabled {
            return switch self {
            case .focus: Color(hex: 0x050A17)
            case .sage: Color(hex: 0x08100F)
            case .dreamy: Color(hex: 0x090613)
            case .cobalt: Color(hex: 0x04101F)
            case .ember: Color(hex: 0x120909)
            }
        }

        return switch self {
        case .focus: Color(hex: 0x1D3557)
        case .sage: Color(hex: 0x143C2F)
        case .dreamy: Color(hex: 0x312E81)
        case .cobalt: Color(hex: 0x082A70)
        case .ember: Color(hex: 0x6F1D13)
        }
    }

    private var statusSuccessBase: Color {
        if LifeTrackAppTheme.isDarkModeEnabled {
            return switch self {
            case .focus, .dreamy: Color(hex: 0x46D7A1)
            case .sage: Color(hex: 0x4FD29F)
            case .cobalt: Color(hex: 0x29D5B5)
            case .ember: Color(hex: 0x5AD59F)
            }
        }

        return switch self {
        case .focus, .dreamy: Color(hex: 0x2F9E6D)
        case .sage: Color(hex: 0x238B64)
        case .cobalt: Color(hex: 0x009A84)
        case .ember: Color(hex: 0x2C8C6A)
        }
    }

    private var statusWarningBase: Color {
        if LifeTrackAppTheme.isDarkModeEnabled {
            return switch self {
            case .focus, .dreamy: Color(hex: 0xFFBF63)
            case .sage: Color(hex: 0xF5B95C)
            case .cobalt: Color(hex: 0xFFC857)
            case .ember: Color(hex: 0xFF9E54)
            }
        }

        return switch self {
        case .focus, .dreamy: Color(hex: 0xD08B2E)
        case .sage: Color(hex: 0xB47B2A)
        case .cobalt: Color(hex: 0xDA8B00)
        case .ember: Color(hex: 0xEA6A12)
        }
    }

    private var statusDangerBase: Color {
        if LifeTrackAppTheme.isDarkModeEnabled {
            return switch self {
            case .focus, .dreamy: Color(hex: 0xFF7D9A)
            case .sage: Color(hex: 0xFF8A8F)
            case .cobalt: Color(hex: 0xFF6F9E)
            case .ember: Color(hex: 0xFF7C72)
            }
        }

        return switch self {
        case .focus, .dreamy: Color(hex: 0xC94A4A)
        case .sage: Color(hex: 0xB84B4F)
        case .cobalt: Color(hex: 0xD83B6A)
        case .ember: Color(hex: 0xD93131)
        }
    }

    private var categoryTints: [Color] {
        if LifeTrackAppTheme.isDarkModeEnabled {
            return switch self {
            case .focus:
                [Color(hex: 0xFF7AAC), Color(hex: 0x4FD4A8), Color(hex: 0x7EA3FF), Color(hex: 0xFFB35C), Color(hex: 0x70D5FF), Color(hex: 0x97A5C4)]
            case .sage:
                [Color(hex: 0xE98FB6), Color(hex: 0x5ED3A6), Color(hex: 0x87C5B8), Color(hex: 0xE8B36C), Color(hex: 0x66C3AE), Color(hex: 0x95A99F)]
            case .dreamy:
                [Color(hex: 0xFF88D3), Color(hex: 0x68D0BF), Color(hex: 0x9B82FF), Color(hex: 0xF0A76A), Color(hex: 0x8192FF), Color(hex: 0xA79ACB)]
            case .cobalt:
                [Color(hex: 0xFF6DB8), Color(hex: 0x4EE0D6), Color(hex: 0x42B9FF), Color(hex: 0xFFB261), Color(hex: 0x6FD4FF), Color(hex: 0x8EA6C8)]
            case .ember:
                [Color(hex: 0xFF7CA3), Color(hex: 0x66D1A7), Color(hex: 0xFF8C6B), Color(hex: 0xFFB15F), Color(hex: 0xFF8164), Color(hex: 0xB5968D)]
            }
        }

        return switch self {
        case .focus:
            [Color(hex: 0xB54A73), Color(hex: 0x2F7E66), Color(hex: 0x4A5CC7), Color(hex: 0xA6662D), Color(hex: 0x2E6AA7), Color(hex: 0x64748B)]
        case .sage:
            [Color(hex: 0xA24F6A), Color(hex: 0x2F7E66), Color(hex: 0x527D77), Color(hex: 0x9B7440), Color(hex: 0x41776B), Color(hex: 0x66776F)]
        case .dreamy:
            [Color(hex: 0xB25C94), Color(hex: 0x3B8A7B), Color(hex: 0x6A5AE0), Color(hex: 0xA96D4D), Color(hex: 0x6366C8), Color(hex: 0x7A718F)]
        case .cobalt:
            [Color(hex: 0xB01868), Color(hex: 0x008C8C), Color(hex: 0x0957FF), Color(hex: 0xB85F00), Color(hex: 0x005BD6), Color(hex: 0x56657F)]
        case .ember:
            [Color(hex: 0xC0325B), Color(hex: 0x2C8C6A), Color(hex: 0xB94625), Color(hex: 0xD26B11), Color(hex: 0xA3382A), Color(hex: 0x77605A)]
        }
    }

    private func tuned(_ base: Color, vivid: Color, pale: Color) -> Color {
        let strength = LifeTrackAppTheme.colorStrength
        if strength < 1 {
            let amount = (1 - strength) / (1 - LifeTrackAppTheme.colorStrengthRange.lowerBound)
            let maxAmount = LifeTrackAppTheme.isDarkModeEnabled ? 0.52 : 0.72
            return base.mixed(with: pale, amount: min(amount * maxAmount, maxAmount))
        }

        let amount = (strength - 1) / (LifeTrackAppTheme.colorStrengthRange.upperBound - 1)
        if LifeTrackAppTheme.isDarkModeEnabled {
            return base.mixed(with: vivid, amount: min(amount * 0.58, 0.58))
        }
        return base.mixed(with: vivid, amount: min(amount, 1))
    }

    private func tunedSoft(_ base: Color) -> Color {
        let strength = LifeTrackAppTheme.colorStrength
        if LifeTrackAppTheme.isDarkModeEnabled {
            if strength < 1 {
                let amount = (1 - strength) / (1 - LifeTrackAppTheme.colorStrengthRange.lowerBound)
                return base.mixed(with: baseBackgroundTop, amount: min(amount * 0.24, 0.24))
            }

            let amount = (strength - 1) / (LifeTrackAppTheme.colorStrengthRange.upperBound - 1)
            return base.mixed(with: vividAccent, amount: min(amount * 0.12, 0.12))
        }

        if strength < 1 {
            let amount = (1 - strength) / (1 - LifeTrackAppTheme.colorStrengthRange.lowerBound)
            return base.mixed(with: Color.white, amount: min(amount * 0.55, 1))
        }

        let amount = (strength - 1) / (LifeTrackAppTheme.colorStrengthRange.upperBound - 1)
        return base.mixed(with: baseAccent, amount: min(amount * 0.20, 0.20))
    }

    private func tunedBackground(_ base: Color) -> Color {
        let strength = LifeTrackAppTheme.colorStrength
        if LifeTrackAppTheme.isDarkModeEnabled {
            if strength < 1 {
                let amount = (1 - strength) / (1 - LifeTrackAppTheme.colorStrengthRange.lowerBound)
                return base.mixed(with: Color.black, amount: min(amount * 0.10, 0.10))
            }

            let amount = (strength - 1) / (LifeTrackAppTheme.colorStrengthRange.upperBound - 1)
            return base.mixed(with: accentSoftBase, amount: min(amount * 0.14, 0.14))
        }

        if strength < 1 {
            let amount = (1 - strength) / (1 - LifeTrackAppTheme.colorStrengthRange.lowerBound)
            return base.mixed(with: Color.white, amount: min(amount * 0.70, 1))
        }

        let amount = (strength - 1) / (LifeTrackAppTheme.colorStrengthRange.upperBound - 1)
        return base.mixed(with: accentSoftBase, amount: min(amount * 0.42, 0.42))
    }
}

enum LifeTrackTheme {
    enum ColorPalette {
        private static var currentTheme: LifeTrackAppTheme { LifeTrackAppTheme.current }

        static var isDarkTheme: Bool { LifeTrackAppTheme.isDarkModeEnabled }
        static var backgroundTop: Color { currentTheme.backgroundTop }
        static var backgroundBottom: Color { currentTheme.backgroundBottom }
        static var card: Color {
            if isDarkTheme {
                return backgroundBottom
                    .mixed(with: Color(hex: 0x171D23), amount: 0.72)
                    .mixed(with: accentSoft, amount: 0.05)
                    .opacity(0.98)
            }
            return backgroundTop.mixed(with: Color.white, amount: 0.82).opacity(0.94)
        }
        static var cardElevated: Color {
            if isDarkTheme {
                return backgroundBottom
                    .mixed(with: Color(hex: 0x1B2229), amount: 0.78)
                    .mixed(with: accentSoft, amount: 0.06)
            }
            return backgroundTop.mixed(with: Color.white, amount: 0.90)
        }
        static var primaryText: Color { currentTheme.primaryText }
        static var secondaryText: Color { currentTheme.secondaryText }
        static var tertiaryText: Color { currentTheme.tertiaryText }
        static var placeholderText: Color { currentTheme.placeholderText }
        static var hairline: Color {
            if isDarkTheme {
                return Color.white.opacity(0.10).mixed(with: accent, amount: 0.08)
            }
            return accentSoft.mixed(with: secondaryText, amount: 0.22)
        }
        static var accent: Color { currentTheme.accent }
        static var accentDeep: Color { currentTheme.accentDeep }
        static var accentSoft: Color { currentTheme.accentSoft }
        static var secondaryAccent: Color { currentTheme.secondaryAccent }
        static var success: Color { currentTheme.success }
        static var warning: Color { currentTheme.warning }
        static var danger: Color { currentTheme.danger }
        static var shadow: Color { currentTheme.shadow }
        static var controlSurface: Color {
            isDarkTheme ? cardElevated : backgroundTop.opacity(0.78)
        }
        static var controlSurfaceStrong: Color {
            isDarkTheme
                ? cardElevated.mixed(with: Color.white, amount: 0.03)
                : backgroundTop.opacity(0.82)
        }
        static var chartPlotBackground: Color {
            isDarkTheme
                ? cardElevated.mixed(with: Color.black, amount: 0.14).opacity(0.96)
                : backgroundTop.opacity(0.46)
        }
        static var chartPlotBorder: Color {
            isDarkTheme ? hairline.opacity(0.92) : hairline.opacity(0.32)
        }
        static var chartGrid: Color {
            isDarkTheme ? Color.white.opacity(0.08).mixed(with: accent, amount: 0.06) : hairline.opacity(0.55)
        }

        static var accentGradient: LinearGradient {
            LinearGradient(
                colors: isDarkTheme
                    ? [accent, secondaryAccent.mixed(with: accentDeep, amount: 0.32)]
                    : [accent, accentDeep.mixed(with: secondaryAccent, amount: 0.22)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        static func categoryTint(for category: TaskCategory) -> Color {
            LifeTrackAppTheme.current.categoryTint(for: category)
        }
    }

    enum Radius {
        static let card: CGFloat = 8
        static let control: CGFloat = 8
        static let chip: CGFloat = 18
    }

    enum Spacing {
        static let xSmall: CGFloat = 6
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xLarge: CGFloat = 20
        static let xxLarge: CGFloat = 28
    }

    enum IconSize {
        static let smallCircle: CGFloat = 30
        static let mediumCircle: CGFloat = 38
        static let largeCircle: CGFloat = 42
    }

    static var appBackground: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: ColorPalette.backgroundTop, location: 0),
                .init(
                    color: LifeTrackTheme.ColorPalette.isDarkTheme
                        ? ColorPalette.backgroundTop.mixed(with: ColorPalette.accentSoft, amount: 0.06)
                        : ColorPalette.backgroundTop.mixed(with: ColorPalette.accentSoft, amount: 0.04),
                    location: 0.42
                ),
                .init(color: ColorPalette.backgroundBottom, location: 1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension Font {
    static var lifeTrackHero: Font { .lifeTrack(.largeTitle, weight: .bold) }
    static var lifeTrackTitle: Font { .lifeTrack(.title2, weight: .semibold) }
    static var lifeTrackHeadline: Font { .lifeTrack(.headline, weight: .semibold) }
    static var lifeTrackBody: Font { .lifeTrack(.body, weight: .regular) }
    static var lifeTrackCallout: Font { .lifeTrack(.callout, weight: .medium) }
    static var lifeTrackSubheadline: Font { .lifeTrack(.subheadline, weight: .semibold) }
    static var lifeTrackFootnote: Font { .lifeTrack(.footnote, weight: .medium) }
    static var lifeTrackCaption: Font { .lifeTrack(.caption, weight: .medium) }

    static func lifeTrack(
        _ textStyle: Font.TextStyle,
        weight: Font.Weight = .regular,
        defaultDesign: Font.Design = LifeTrackAppTheme.current.fontDesign
    ) -> Font {
        LifeTrackTypography.font(textStyle, weight: weight, defaultDesign: defaultDesign)
    }

    static func lifeTrack(
        size: CGFloat,
        role: LifeTrackTypography.Role,
        weight: Font.Weight = .regular,
        defaultDesign: Font.Design = LifeTrackAppTheme.current.fontDesign
    ) -> Font {
        LifeTrackTypography.font(size: size, role: role, weight: weight, defaultDesign: defaultDesign)
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    func mixed(with color: Color, amount: Double) -> Color {
        let amount = min(max(amount, 0), 1)
        let source = UIColor(self).lifeTrackRGBA
        let target = UIColor(color).lifeTrackRGBA

        return Color(
            .sRGB,
            red: source.red + (target.red - source.red) * amount,
            green: source.green + (target.green - source.green) * amount,
            blue: source.blue + (target.blue - source.blue) * amount,
            opacity: source.alpha + (target.alpha - source.alpha) * amount
        )
    }
}

private extension UIColor {
    var lifeTrackRGBA: (red: Double, green: Double, blue: Double, alpha: Double) {
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

struct LifeTrackCardModifier: ViewModifier {
    let padding: CGFloat
    let backgroundColor: Color

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                    .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.75), lineWidth: 0.7)
            }
            .shadow(
                color: LifeTrackTheme.ColorPalette.shadow,
                radius: LifeTrackTheme.ColorPalette.isDarkTheme ? 8 : 13,
                x: 0,
                y: LifeTrackTheme.ColorPalette.isDarkTheme ? 3 : 8
            )
    }
}

extension View {
    func lifeTrackCard(
        padding: CGFloat = LifeTrackTheme.Spacing.large,
        backgroundColor: Color = LifeTrackTheme.ColorPalette.card
    ) -> some View {
        modifier(LifeTrackCardModifier(padding: padding, backgroundColor: backgroundColor))
    }
}

struct CategoryStyle {
    let tint: Color
    let background: Color
    let border: Color
}

extension TaskCategory {
    var style: CategoryStyle {
        let tint = LifeTrackTheme.ColorPalette.categoryTint(for: self)
        return CategoryStyle(
            tint: tint,
            background: tint.opacity(0.12),
            border: tint.opacity(0.24)
        )
    }

    fileprivate var themeIndex: Int {
        switch self {
        case .health: 0
        case .finance: 1
        case .work: 2
        case .home: 3
        case .personal: 4
        case .other: 5
        }
    }
}

extension Date {
    var dayMonthString: String {
        formatted(Date.FormatStyle().month(.abbreviated).day())
    }

    var weekdayDateString: String {
        formatted(Date.FormatStyle().weekday(.wide).month(.abbreviated).day())
    }

    var timeString: String {
        formatted(Date.FormatStyle().hour().minute())
    }
}
