//
//  LifeTrackTheme.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import SwiftUI
import UIKit

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
        switch self {
        case .focus, .sage, .dreamy: Color(hex: 0x111827)
        case .cobalt: Color(hex: 0x0B132B)
        case .ember: Color(hex: 0x21120F)
        }
    }

    var secondaryText: Color {
        switch self {
        case .focus, .sage, .dreamy: Color(hex: 0x5F6673)
        case .cobalt: Color(hex: 0x4E5871)
        case .ember: Color(hex: 0x66534F)
        }
    }

    var tertiaryText: Color {
        switch self {
        case .focus, .sage, .dreamy: Color(hex: 0x8791A1)
        case .cobalt: Color(hex: 0x7E8AA5)
        case .ember: Color(hex: 0x9A827C)
        }
    }

    var placeholderText: Color {
        switch self {
        case .focus, .sage, .dreamy: Color(hex: 0x596171)
        case .cobalt: Color(hex: 0x53617C)
        case .ember: Color(hex: 0x6D5750)
        }
    }

    var shadow: Color {
        tuned(baseShadow, vivid: vividAccent, pale: accentSoftBase).opacity(0.10 + max(LifeTrackAppTheme.colorStrength - 1, 0) * 0.08)
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
        switch self {
        case .focus: Color(hex: 0xF8FAFF)
        case .sage: Color(hex: 0xF7FBF8)
        case .dreamy: Color(hex: 0xFBF8FF)
        case .cobalt: Color(hex: 0xF4F8FF)
        case .ember: Color(hex: 0xFFF8F3)
        }
    }

    private var baseBackgroundBottom: Color {
        switch self {
        case .focus: Color(hex: 0xEEF3F8)
        case .sage: Color(hex: 0xEAF4EF)
        case .dreamy: Color(hex: 0xEEF2FF)
        case .cobalt: Color(hex: 0xDDEBFF)
        case .ember: Color(hex: 0xFFE7DB)
        }
    }

    private var baseAccent: Color {
        switch self {
        case .focus: Color(hex: 0x3159D9)
        case .sage: Color(hex: 0x2F7E66)
        case .dreamy: Color(hex: 0x6A5AE0)
        case .cobalt: Color(hex: 0x0957FF)
        case .ember: Color(hex: 0xE5482E)
        }
    }

    private var accentDeepBase: Color {
        switch self {
        case .focus: Color(hex: 0x243FA3)
        case .sage: Color(hex: 0x1E5D4A)
        case .dreamy: Color(hex: 0x4736C8)
        case .cobalt: Color(hex: 0x0030B8)
        case .ember: Color(hex: 0xA91F16)
        }
    }

    private var vividAccent: Color {
        switch self {
        case .focus: Color(hex: 0x6B7BFF)
        case .sage: Color(hex: 0x19A974)
        case .dreamy: Color(hex: 0xB05CFF)
        case .cobalt: Color(hex: 0x00A3FF)
        case .ember: Color(hex: 0xFF8A00)
        }
    }

    private var accentSoftBase: Color {
        switch self {
        case .focus: Color(hex: 0xE8EEFF)
        case .sage: Color(hex: 0xE7F4EF)
        case .dreamy: Color(hex: 0xEFECFF)
        case .cobalt: Color(hex: 0xDCEBFF)
        case .ember: Color(hex: 0xFFE7D6)
        }
    }

    private var secondaryAccentBase: Color {
        switch self {
        case .focus: Color(hex: 0x5865B8)
        case .sage: Color(hex: 0x519078)
        case .dreamy: Color(hex: 0x946FE8)
        case .cobalt: Color(hex: 0x00A3FF)
        case .ember: Color(hex: 0xFF8A00)
        }
    }

    private var baseShadow: Color {
        switch self {
        case .focus: Color(hex: 0x1D3557)
        case .sage: Color(hex: 0x143C2F)
        case .dreamy: Color(hex: 0x312E81)
        case .cobalt: Color(hex: 0x082A70)
        case .ember: Color(hex: 0x6F1D13)
        }
    }

    private var statusSuccessBase: Color {
        switch self {
        case .focus, .dreamy: Color(hex: 0x2F9E6D)
        case .sage: Color(hex: 0x238B64)
        case .cobalt: Color(hex: 0x009A84)
        case .ember: Color(hex: 0x2C8C6A)
        }
    }

    private var statusWarningBase: Color {
        switch self {
        case .focus, .dreamy: Color(hex: 0xD08B2E)
        case .sage: Color(hex: 0xB47B2A)
        case .cobalt: Color(hex: 0xDA8B00)
        case .ember: Color(hex: 0xEA6A12)
        }
    }

    private var statusDangerBase: Color {
        switch self {
        case .focus, .dreamy: Color(hex: 0xC94A4A)
        case .sage: Color(hex: 0xB84B4F)
        case .cobalt: Color(hex: 0xD83B6A)
        case .ember: Color(hex: 0xD93131)
        }
    }

    private var categoryTints: [Color] {
        switch self {
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
            return base.mixed(with: pale, amount: min(amount * 0.72, 1))
        }

        let amount = (strength - 1) / (LifeTrackAppTheme.colorStrengthRange.upperBound - 1)
        return base.mixed(with: vivid, amount: min(amount, 1))
    }

    private func tunedSoft(_ base: Color) -> Color {
        let strength = LifeTrackAppTheme.colorStrength
        if strength < 1 {
            let amount = (1 - strength) / (1 - LifeTrackAppTheme.colorStrengthRange.lowerBound)
            return base.mixed(with: Color.white, amount: min(amount * 0.55, 1))
        }

        let amount = (strength - 1) / (LifeTrackAppTheme.colorStrengthRange.upperBound - 1)
        return base.mixed(with: baseAccent, amount: min(amount * 0.20, 0.20))
    }

    private func tunedBackground(_ base: Color) -> Color {
        let strength = LifeTrackAppTheme.colorStrength
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
        static var backgroundTop: Color { LifeTrackAppTheme.current.backgroundTop }
        static var backgroundBottom: Color { LifeTrackAppTheme.current.backgroundBottom }
        static var card: Color { backgroundTop.mixed(with: Color.white, amount: 0.82).opacity(0.94) }
        static var cardElevated: Color { backgroundTop.mixed(with: Color.white, amount: 0.90) }
        static var primaryText: Color { LifeTrackAppTheme.current.primaryText }
        static var secondaryText: Color { LifeTrackAppTheme.current.secondaryText }
        static var tertiaryText: Color { LifeTrackAppTheme.current.tertiaryText }
        static var placeholderText: Color { LifeTrackAppTheme.current.placeholderText }
        static var hairline: Color { accentSoft.mixed(with: secondaryText, amount: 0.22) }
        static var accent: Color { LifeTrackAppTheme.current.accent }
        static var accentDeep: Color { LifeTrackAppTheme.current.accentDeep }
        static var accentSoft: Color { LifeTrackAppTheme.current.accentSoft }
        static var secondaryAccent: Color { LifeTrackAppTheme.current.secondaryAccent }
        static var success: Color { LifeTrackAppTheme.current.success }
        static var warning: Color { LifeTrackAppTheme.current.warning }
        static var danger: Color { LifeTrackAppTheme.current.danger }
        static var shadow: Color { LifeTrackAppTheme.current.shadow }

        static var accentGradient: LinearGradient {
            LinearGradient(
                colors: [accent, accentDeep.mixed(with: secondaryAccent, amount: 0.22)],
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
            colors: [
                ColorPalette.backgroundTop,
                ColorPalette.backgroundBottom
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension Font {
    static var lifeTrackHero: Font { Font.system(.largeTitle, design: LifeTrackAppTheme.current.fontDesign, weight: .bold) }
    static var lifeTrackTitle: Font { Font.system(.title2, design: LifeTrackAppTheme.current.fontDesign, weight: .semibold) }
    static var lifeTrackHeadline: Font { Font.system(.headline, design: LifeTrackAppTheme.current.fontDesign, weight: .semibold) }
    static var lifeTrackBody: Font { Font.system(.body, design: LifeTrackAppTheme.current.fontDesign, weight: .regular) }
    static var lifeTrackCallout: Font { Font.system(.callout, design: LifeTrackAppTheme.current.fontDesign, weight: .medium) }
    static var lifeTrackCaption: Font { Font.system(.caption, design: LifeTrackAppTheme.current.fontDesign, weight: .medium) }
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
            .shadow(color: LifeTrackTheme.ColorPalette.shadow, radius: 13, x: 0, y: 8)
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
