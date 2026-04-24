//
//  BetaDashboardPalette.swift
//  LifeTrack
//
//  Beta dashboard palette. Warm purple/pink/peach pastel aesthetic
//  by default; accent/status tints and text tones route through
//  `LifeTrackAppTheme.current` so it reacts to theme and
//  color-strength changes just like the default dashboard.
//

import SwiftUI

enum BetaPalette {
    private static var isDark: Bool { LifeTrackAppTheme.isDarkModeEnabled }

    // Background washes
    static var bgTop: Color {
        isDark
            ? Color(hex: 0x12111D).mixed(with: theme.accentDeep, amount: 0.10)
            : Color(hex: 0xF8F2FB)
    }
    static var bgMid: Color {
        isDark
            ? Color(hex: 0x201935).mixed(with: theme.accentSoft, amount: 0.18)
            : Color(hex: 0xF7ECF1)
    }
    static var bgBottom: Color {
        isDark
            ? Color(hex: 0x251932).mixed(with: theme.secondaryAccent, amount: 0.10)
            : Color(hex: 0xFBF2E9)
    }

    // Hero streak card
    static var heroTop: Color {
        isDark
            ? Color(hex: 0x33284A).mixed(with: theme.accent, amount: 0.18)
            : Color(hex: 0xE8DEF6)
    }
    static var heroMid: Color {
        isDark
            ? Color(hex: 0x241B36).mixed(with: theme.accentDeep, amount: 0.10)
            : Color(hex: 0xF0DEEA)
    }
    static var heroBottom: Color {
        isDark
            ? Color(hex: 0x1E162A).mixed(with: theme.warning, amount: 0.06)
            : Color(hex: 0xFBE5D2)
    }

    static var faintBorder: Color {
        isDark ? Color.white.opacity(0.10) : Color.black.opacity(0.05)
    }

    static var peach: Color {
        LifeTrackAppTheme.isDarkModeEnabled ? theme.secondaryAccent.mixed(with: theme.warning, amount: 0.35) : Color(hex: 0xFFB07A)
    }
    static var peachDeep: Color {
        LifeTrackAppTheme.isDarkModeEnabled ? theme.accent.mixed(with: theme.secondaryAccent, amount: 0.4) : Color(hex: 0xFF8EAC)
    }

    // Alert
    static var alertBg: Color {
        isDark
            ? Color(hex: 0x2C2224).mixed(with: theme.warning, amount: 0.12)
            : Color(hex: 0xFCE7DA)
    }
    static var alertIconBg: Color {
        isDark
            ? Color(hex: 0x4A3532).mixed(with: theme.warning, amount: 0.14)
            : Color(hex: 0xFFD2B8)
    }
    static var alertIcon: Color {
        isDark ? theme.warning.mixed(with: Color.white, amount: 0.12) : Color(hex: 0xD97757)
    }
    static var alertText: Color {
        isDark ? Color.white.opacity(0.92) : Color(hex: 0xB35A3F)
    }

    // Category placeholders kept for any legacy usage
    static let catHome = Color(hex: 0xC98258)
    static let catHomeBg = Color(hex: 0xF2E4D6)
    static let catPersonal = Color(hex: 0x3B82F6)
    static let catPersonalBg = Color(hex: 0xE0ECFE)
    static let catHealth = Color(hex: 0x10B981)
    static let catHealthBg = Color(hex: 0xDCF3E8)
    static let catFallback = Color(hex: 0x8B5CF6)
    static let catFallbackBg = Color(hex: 0xEADDFB)

    // MARK: Theme-reactive tones

    private static var theme: LifeTrackAppTheme { LifeTrackAppTheme.current }

    static var primaryText: Color { theme.primaryText }
    static var secondaryText: Color { theme.secondaryText }
    static var tertiaryText: Color { theme.tertiaryText }

    static var accent: Color { theme.accent }
    static var accentDeep: Color { theme.accentDeep }
    static var accentSoft: Color { theme.accentSoft }

    static var overdue: Color { theme.danger }

    // Stat icons — tinted per category of stat, but each routed through the theme
    static var statDueToday: Color { theme.accent }
    static var statDueTodayBg: Color { theme.accentSoft }
    static var statUpcoming: Color { theme.secondaryAccent }
    static var statUpcomingBg: Color { theme.secondaryAccent.opacity(0.18) }
    static var statCompleted: Color { theme.success }
    static var statCompletedBg: Color { theme.success.opacity(0.18) }
    static var statOverdue: Color { theme.danger }
    static var statOverdueBg: Color { theme.danger.opacity(0.18) }

    // Wave strokes below each stat
    static var waveDueToday: Color { theme.accentDeep }
    static var waveUpcoming: Color { theme.secondaryAccent }
    static var waveCompleted: Color { theme.success }
    static var waveOverdue: Color { theme.danger }

    // Quick actions
    static var qaPlanTint: Color { theme.warning }
    static var qaPlanBg: Color { theme.warning.opacity(0.14) }
    static var qaHabitsTint: Color { theme.danger }
    static var qaHabitsBg: Color { theme.danger.opacity(0.14) }
    static var qaReviewTint: Color { theme.secondaryAccent }
    static var qaReviewBg: Color { theme.secondaryAccent.opacity(0.14) }
    static var qaFocusTint: Color { theme.accent }
    static var qaFocusBg: Color { theme.accentSoft }
    static var qaAccentTint: Color { theme.accent }
    static var qaAccentBg: Color { theme.accentSoft }
    static var qaSuccessTint: Color { theme.success }
    static var qaSuccessBg: Color { theme.success.opacity(0.14) }
    static var qaInfoTint: Color { theme.secondaryAccent }
    static var qaInfoBg: Color { theme.secondaryAccent.opacity(0.14) }
    static var qaWarningTint: Color { theme.warning }
    static var qaWarningBg: Color { theme.warning.opacity(0.14) }
    static var qaDangerTint: Color { theme.danger }
    static var qaDangerBg: Color { theme.danger.opacity(0.14) }

    static var heroShellStroke: Color { isDark ? Color.white.opacity(0.28) : Color.white.opacity(0.5) }
    static var heroGlassFill: Color {
        isDark
            ? Color.white.opacity(0.10).mixed(with: theme.accentSoft, amount: 0.06)
            : Color.white.opacity(0.55)
    }
    static var heroGlassStroke: Color { isDark ? Color.white.opacity(0.22) : Color.white.opacity(0.55) }
    static var heroShadow: Color {
        isDark
            ? theme.accentDeep.opacity(0.24)
            : BetaPalette.accentDeep.opacity(0.08)
    }

    static var lightCardFill: Color {
        isDark
            ? Color(hex: 0x1A2027)
                .mixed(with: theme.accentSoft, amount: 0.06)
                .mixed(with: theme.backgroundTop, amount: 0.10)
            : Color.white
    }
    static var lightCardShadow: Color {
        isDark
            ? Color.black.opacity(0.24)
            : Color.black.opacity(0.04)
    }
    static var lightCardBorder: Color {
        isDark
            ? Color.white.opacity(0.10).mixed(with: theme.accent, amount: 0.10)
            : BetaPalette.faintBorder
    }
    static var lightCardPrimaryText: Color {
        isDark
            ? Color.white.opacity(0.96)
            : theme.primaryText
    }
    static var lightCardSecondaryText: Color {
        isDark
            ? Color.white.opacity(0.74).mixed(with: theme.accentSoft, amount: 0.10)
            : theme.secondaryText
    }
    static var lightCardTertiaryText: Color {
        isDark
            ? Color.white.opacity(0.54)
            : theme.tertiaryText
    }
    static var lightChromeText: Color {
        isDark
            ? Color.white.opacity(0.68)
            : theme.secondaryText
    }
    static var footerFill: Color {
        isDark
            ? Color(hex: 0x12181D)
                .mixed(with: theme.accentSoft, amount: 0.04)
                .mixed(with: theme.backgroundTop, amount: 0.08)
            : Color.white
    }
    static var footerStroke: Color {
        isDark
            ? Color.white.opacity(0.10).mixed(with: theme.accent, amount: 0.08)
            : Color.white.opacity(0.8)
    }

    // Gradients
    static var appBackground: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: bgTop, location: 0.0),
                .init(color: bgMid, location: 0.45),
                .init(color: bgBottom, location: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var heroBackground: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: heroTop, location: 0.0),
                .init(color: heroMid, location: 0.55),
                .init(color: heroBottom, location: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var fabGradient: LinearGradient {
        LinearGradient(
            colors: [accentDeep, accent],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accentDeep],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
