//
//  BetaDashboardHeroHelpers.swift
//  LifeTrack
//
//  Pure view helpers used by the beta dashboard hero cards, streak
//  stats, and focus planning row. No instance state.
//

import SwiftUI

// MARK: - Shell

func productivityHeroShell<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    ZStack(alignment: .topLeading) {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(BetaPalette.heroBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(BetaPalette.heroShellStroke, lineWidth: 1)
            }
            .shadow(color: BetaPalette.heroShadow, radius: 18, y: 8)

        content()
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 14)
    }
    .frame(minHeight: 240)
    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
}

// MARK: - Metric / Progress / Insight

func heroMetricPill(title: String, value: String, subtitle: String, tint: Color, symbolName: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 5) {
            Image(systemName: symbolName)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 18, height: 18)
                .background(tint.opacity(0.13), in: Circle())

            Text(title)
                .font(.betaCaption(10, weight: .semibold))
                .foregroundStyle(BetaPalette.secondaryText)
                .lineLimit(1)
        }

        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value)
                .font(.betaRounded(19, role: .title, weight: .bold))
                .foregroundStyle(BetaPalette.primaryText)
                .monospacedDigit()
                .lineLimit(1)
            Text(subtitle)
                .font(.betaCaption(9, weight: .medium))
                .foregroundStyle(BetaPalette.tertiaryText)
                .lineLimit(1)
        }
    }
    .padding(.horizontal, 9)
    .padding(.vertical, 8)
    .frame(height: 68)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(BetaPalette.heroGlassFill, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    .overlay {
        RoundedRectangle(cornerRadius: 15, style: .continuous)
            .stroke(BetaPalette.heroGlassStroke, lineWidth: 1)
    }
}

func heroProgressRow(title: String, value: String, progress: Double, tint: Color) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        HStack {
            Text(title)
                .font(.betaCaption(12, weight: .semibold))
                .foregroundStyle(BetaPalette.primaryText)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(value)
                .font(.betaRounded(12, role: .caption, weight: .bold))
                .foregroundStyle(BetaPalette.secondaryText)
                .monospacedDigit()
        }

        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(tint.opacity(0.14))
                Capsule()
                    .fill(tint)
                    .frame(width: max(8, proxy.size.width * CGFloat(min(max(progress, 0), 1))))
            }
        }
        .frame(height: 7)
    }
}

func heroInsightRow(title: String, subtitle: String, symbolName: String, tint: Color) -> some View {
    HStack(spacing: 9) {
        Image(systemName: symbolName)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(tint)
            .frame(width: 28, height: 28)
            .background(tint.opacity(0.12), in: Circle())

        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.betaCaption(11, weight: .bold))
                .foregroundStyle(BetaPalette.primaryText)
                .lineLimit(1)
            Text(subtitle)
                .font(.betaCaption(10, weight: .medium))
                .foregroundStyle(BetaPalette.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }

        Spacer(minLength: 0)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    .background(BetaPalette.heroGlassFill, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    .overlay {
        RoundedRectangle(cornerRadius: 15, style: .continuous)
            .stroke(BetaPalette.heroGlassStroke, lineWidth: 1)
    }
}

// MARK: - Action buttons

func heroActionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .bold))
            Text(title)
                .font(.betaBody(14, weight: .semibold))
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .background(
            LinearGradient(
                colors: [Color(hex: 0x1F1B2E), Color(hex: 0x2A2540)],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: Capsule()
        )
        .shadow(color: Color.black.opacity(0.18), radius: 8, y: 4)
    }
    .buttonStyle(.plain)
}

func heroInlineActionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .bold))
            Text(title)
                .font(.betaCaption(12, weight: .bold))
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(.white)
        .lineLimit(1)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            LinearGradient(
                colors: [Color(hex: 0x1F1B2E), Color(hex: 0x2A2540)],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: Capsule()
        )
        .shadow(color: Color.black.opacity(0.14), radius: 7, y: 3)
    }
    .buttonStyle(.plain)
}

// MARK: - Streak stat cell

func streakStatCell(icon: String, iconTint: Color, value: String, unit: String, label: String) -> some View {
    HStack(spacing: 10) {
        Image(systemName: icon)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(iconTint)

        VStack(alignment: .leading, spacing: 0) {
            Text(value)
                .font(.betaStreakStat)
                .foregroundStyle(BetaPalette.primaryText)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(unit)
                .font(.betaCaption(11, weight: .medium))
                .foregroundStyle(BetaPalette.secondaryText)
            Text(label)
                .font(.betaCaption(11, weight: .medium))
                .foregroundStyle(BetaPalette.secondaryText)
        }

        Spacer(minLength: 0)
    }
    .padding(.horizontal, 8)
    .frame(maxWidth: .infinity)
}

// MARK: - Focus planning button

func betaFocusPlanningButton(title: String, symbol: String, tint: Color, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Label(title, systemImage: symbol)
            .font(.lifeTrack(.caption, weight: .bold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 9)
            .background(
                BetaPalette.lightCardFill.mixed(with: tint, amount: LifeTrackAppTheme.isDarkModeEnabled ? 0.08 : 0.03),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(tint.opacity(LifeTrackAppTheme.isDarkModeEnabled ? 0.30 : 0.22), lineWidth: 0.8)
            }
    }
    .buttonStyle(.plain)
}
