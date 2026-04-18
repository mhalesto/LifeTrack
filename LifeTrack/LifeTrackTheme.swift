//
//  LifeTrackTheme.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import SwiftUI

enum LifeTrackTheme {
    enum ColorPalette {
        static let backgroundTop = Color(hex: 0xF8FAFF)
        static let backgroundBottom = Color(hex: 0xEEF3F8)
        static let card = Color.white.opacity(0.92)
        static let cardElevated = Color.white
        static let primaryText = Color(hex: 0x111827)
        static let secondaryText = Color(hex: 0x6B7280)
        static let tertiaryText = Color(hex: 0x9CA3AF)
        static let hairline = Color(hex: 0xDDE5EF)
        static let accent = Color(hex: 0x3159D9)
        static let accentSoft = Color(hex: 0xE8EEFF)
        static let success = Color(hex: 0x2F9E6D)
        static let warning = Color(hex: 0xD08B2E)
        static let danger = Color(hex: 0xC94A4A)
        static let shadow = Color(hex: 0x1D3557).opacity(0.10)
    }

    enum Radius {
        static let card: CGFloat = 8
        static let control: CGFloat = 8
        static let chip: CGFloat = 18
    }

    enum Spacing {
        static let xSmall: CGFloat = 6
        static let small: CGFloat = 10
        static let medium: CGFloat = 14
        static let large: CGFloat = 18
        static let xLarge: CGFloat = 24
        static let xxLarge: CGFloat = 32
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
    static let lifeTrackHero = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let lifeTrackTitle = Font.system(.title2, design: .rounded, weight: .semibold)
    static let lifeTrackHeadline = Font.system(.headline, design: .rounded, weight: .semibold)
    static let lifeTrackBody = Font.system(.body, design: .default, weight: .regular)
    static let lifeTrackCallout = Font.system(.callout, design: .default, weight: .medium)
    static let lifeTrackCaption = Font.system(.caption, design: .default, weight: .medium)
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
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
            .shadow(color: LifeTrackTheme.ColorPalette.shadow, radius: 16, x: 0, y: 10)
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
        switch self {
        case .health:
            CategoryStyle(tint: Color(hex: 0xB54A73), background: Color(hex: 0xFAEEF4), border: Color(hex: 0xE8C9D7))
        case .finance:
            CategoryStyle(tint: Color(hex: 0x2F7E66), background: Color(hex: 0xEAF6F0), border: Color(hex: 0xC8E5D7))
        case .work:
            CategoryStyle(tint: Color(hex: 0x4A5CC7), background: Color(hex: 0xEEF1FF), border: Color(hex: 0xD0D7FF))
        case .home:
            CategoryStyle(tint: Color(hex: 0xA6662D), background: Color(hex: 0xFFF3E8), border: Color(hex: 0xECD4BC))
        case .personal:
            CategoryStyle(tint: Color(hex: 0x2E6AA7), background: Color(hex: 0xEAF3FB), border: Color(hex: 0xC8DBF1))
        case .other:
            CategoryStyle(tint: Color(hex: 0x64748B), background: Color(hex: 0xF1F5F9), border: Color(hex: 0xD8E0EA))
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
