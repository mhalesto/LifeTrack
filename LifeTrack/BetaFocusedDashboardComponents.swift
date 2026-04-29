//
//  BetaFocusedDashboardComponents.swift
//  LifeTrack
//

import SwiftUI

struct BetaFocusedDashboardBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    BetaFocusedDashboardPalette.backgroundTop,
                    BetaFocusedDashboardPalette.backgroundBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [Color.white.opacity(0.65), Color.clear],
                center: .topLeading,
                startRadius: 20,
                endRadius: 240
            )
            .offset(x: -70, y: -40)

            RadialGradient(
                colors: [Color(hex: 0xFFD78C).opacity(0.22), Color.clear],
                center: .topTrailing,
                startRadius: 30,
                endRadius: 260
            )
            .offset(x: 110, y: -30)
        }
    }
}

struct BetaFocusedDashboardCard<Content: View>: View {
    let background: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(BetaFocusedDashboardPalette.border, lineWidth: 0.8)
        }
        .shadow(color: BetaFocusedDashboardPalette.softShadow, radius: 18, x: 0, y: 8)
    }
}

struct BetaFocusedDashboardPlanPreview: View {
    let preview: BetaFocusedDashboardPlanPreviewModel
    let onRescue: (() -> Void)?

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(BetaFocusedDashboardPalette.heroAccent)
                .frame(width: 28, height: 28)
                .background(BetaFocusedDashboardPalette.dangerBackground.opacity(0.9), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(preview.summary)
                    .font(BetaFocusedDashboardTypography.body.weight(.semibold))
                    .foregroundStyle(BetaFocusedDashboardPalette.headerText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(preview.detail)
                    .font(BetaFocusedDashboardTypography.bodySmall)
                    .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 0)

            if let onRescue {
                Button(action: onRescue) {
                    Text("Rescue")
                        .font(BetaFocusedDashboardTypography.bodySmall.weight(.semibold))
                        .foregroundStyle(BetaFocusedDashboardPalette.overdueTint)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(BetaFocusedDashboardPalette.dangerBackground, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(BetaFocusedDashboardPalette.border.opacity(0.85), lineWidth: 0.8)
        }
    }
}

struct BetaFocusedDashboardMetricColumn: View {
    let symbolName: String
    let tint: Color
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbolName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.16), in: Circle())

            Text(value.formatted())
                .font(BetaFocusedDashboardTypography.statValue)
                .foregroundStyle(BetaFocusedDashboardPalette.headerText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.55)

            Text(label)
                .font(BetaFocusedDashboardTypography.body)
                .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}

struct BetaFocusedDashboardVerticalRule: View {
    var body: some View {
        Rectangle()
            .fill(BetaFocusedDashboardPalette.border)
            .frame(width: 1, height: 68)
            .padding(.horizontal, 4)
    }
}

struct BetaFocusedDashboardSunBackdrop: View {
    private var phase: TimeOfDayPhase {
        TimeOfDayPhase.current
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Circle()
                .fill(phase.glowColor.opacity(0.22))
                .frame(width: 64, height: 64)
                .blur(radius: 8)
                .offset(x: 6, y: -6)

            Image(systemName: phase.symbolName)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: phase.symbolGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .offset(x: -2, y: 0)
        }
        .frame(width: 80, height: 44, alignment: .topTrailing)
        .accessibilityHidden(true)
    }
}

struct BetaFocusedDashboardStartHereBand: View {
    let recommendation: DailyFocusRecommendation
    let categoryOption: TaskCategoryOption
    let visuals: BetaFocusedDashboardCategoryVisuals
    let scheduledBlock: ScheduledBlock?
    let healthState: BetaFocusedDashboardTaskHealthState?
    let onOpen: () -> Void
    let onComplete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Label("Start here", systemImage: "sparkles")
                    .font(BetaFocusedDashboardTypography.bodySmall.weight(.semibold))
                    .foregroundStyle(BetaFocusedDashboardPalette.heroAccent)

                Spacer(minLength: 0)

                Text(scheduleHint)
                    .font(BetaFocusedDashboardTypography.bodySmall)
                    .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)
                    .lineLimit(1)
            }

            HStack(alignment: .center, spacing: 10) {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(visuals.background)
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: categoryOption.symbolName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(visuals.tint)
                    }

                Button(action: onOpen) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recommendation.task.title)
                            .font(BetaFocusedDashboardTypography.taskTitle.weight(.semibold))
                            .foregroundStyle(BetaFocusedDashboardPalette.headerText)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        HStack(spacing: 6) {
                            Text(recommendation.reason.title)
                                .font(BetaFocusedDashboardTypography.bodySmall)
                                .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)

                            BetaFocusedDashboardCategoryChip(
                                title: categoryOption.title,
                                tint: visuals.tint,
                                background: visuals.background
                            )

                            if let healthState {
                                BetaFocusedDashboardHealthChip(state: healthState)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)

                Button(action: onComplete) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(BetaFocusedDashboardPalette.completedTint, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Complete start here task")
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [
                    BetaFocusedDashboardPalette.dangerBackground.opacity(0.78),
                    Color.white.opacity(0.74)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(BetaFocusedDashboardPalette.heroAccent.opacity(0.18), lineWidth: 0.8)
        }
    }

    private var scheduleHint: String {
        if let scheduledBlock {
            return "Fits \(BetaFocusedDashboardTimeFormatter.timeOnly.string(from: scheduledBlock.startDate))"
        }

        if recommendation.task.isOverdue {
            return "Rescue candidate"
        }

        return "Next best action"
    }
}

struct BetaFocusedDashboardTaskRow: View {
    let task: LifeTask
    let categoryOption: TaskCategoryOption
    let visuals: BetaFocusedDashboardCategoryVisuals
    let healthState: BetaFocusedDashboardTaskHealthState?
    let onOpen: () -> Void
    let onToggleCompletion: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(visuals.background)
                .frame(width: 38, height: 38)
                .overlay {
                    Image(systemName: categoryOption.symbolName)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(visuals.tint)
                }

            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(BetaFocusedDashboardTypography.taskTitle)
                        .foregroundStyle(BetaFocusedDashboardPalette.headerText)
                        .multilineTextAlignment(.leading)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    HStack(spacing: 5) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)

                        Text(scheduleLabel)
                            .font(BetaFocusedDashboardTypography.body)
                            .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        if let healthState {
                            BetaFocusedDashboardHealthChip(state: healthState)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            BetaFocusedDashboardCategoryChip(
                title: categoryOption.title,
                tint: visuals.tint,
                background: visuals.background
            )

            Button(action: onToggleCompletion) {
                ZStack {
                    Circle()
                        .stroke(
                            task.isCompleted ? BetaFocusedDashboardPalette.completedTint : BetaFocusedDashboardPalette.border,
                            lineWidth: 2
                        )
                        .frame(width: 24, height: 24)

                    if task.isCompleted {
                        Circle()
                            .fill(BetaFocusedDashboardPalette.completedTint)
                            .frame(width: 24, height: 24)

                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isCompleted ? "Mark incomplete" : "Mark complete")
        }
        .padding(.vertical, 7)
        .padding(.trailing, 3)
    }

    private var scheduleLabel: String {
        let calendar = Calendar.current

        if calendar.isDateInToday(task.dueDate) {
            return "Today, \(BetaFocusedDashboardTimeFormatter.timeOnly.string(from: task.dueDate))"
        }

        if calendar.isDateInTomorrow(task.dueDate) {
            return "Tomorrow, \(BetaFocusedDashboardTimeFormatter.timeOnly.string(from: task.dueDate))"
        }

        return BetaFocusedDashboardTimeFormatter.dateAndTime.string(from: task.dueDate)
    }
}

struct BetaFocusedDashboardCategoryChip: View {
    let title: String
    let tint: Color
    let background: Color

    var body: some View {
        Text(title)
            .font(BetaFocusedDashboardTypography.chip)
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(background, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(tint.opacity(0.18), lineWidth: 0.8)
            }
    }
}

struct BetaFocusedDashboardHealthChip: View {
    let state: BetaFocusedDashboardTaskHealthState

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: state.symbolName)
                .font(.system(size: 8.5, weight: .bold))
            Text(state.title)
                .lineLimit(1)
        }
        .font(BetaFocusedDashboardTypography.bodySmall.weight(.semibold))
        .foregroundStyle(state.tint)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(state.background, in: Capsule())
        .overlay {
            Capsule()
                .stroke(state.tint.opacity(0.16), lineWidth: 0.7)
        }
    }
}

struct BetaFocusedDashboardTinyBadge: View {
    let title: String
    let tint: Color
    let background: Color

    var body: some View {
        Text(title)
            .font(BetaFocusedDashboardTypography.bodySmall.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(background, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(tint.opacity(0.16), lineWidth: 0.7)
            }
    }
}

struct BetaFocusedDashboardActionChip: View {
    let title: String
    let systemImage: String
    let tint: Color
    var isCompact = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: isCompact ? 13 : 14, weight: .semibold))
                Text(title)
                    .font((isCompact ? BetaFocusedDashboardTypography.bodySmall : BetaFocusedDashboardTypography.body).weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .foregroundStyle(tint)
            .padding(.horizontal, isCompact ? 7 : 11)
            .padding(.vertical, isCompact ? 8 : 10)
            .frame(maxWidth: .infinity)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(BetaFocusedDashboardPalette.border, lineWidth: 0.8)
            }
        }
        .buttonStyle(.plain)
    }
}

struct BetaFocusedDashboardToolTile: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Circle()
                    .fill(tint.opacity(0.14))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: systemImage)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(tint)
                    }

                Text(title)
                    .font(BetaFocusedDashboardTypography.bodySmall.weight(.semibold))
                    .foregroundStyle(tint)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 96)
            .frame(minHeight: 84)
            .padding(.horizontal, 6)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(BetaFocusedDashboardPalette.border, lineWidth: 0.8)
            }
        }
        .buttonStyle(.plain)
    }
}

struct BetaFocusedDashboardTabBar: View {
    @Binding var selectedTab: BetaFocusedDashboardTab

    var body: some View {
        HStack(spacing: 6) {
            tabButton(tab: .home, title: "Home", systemImage: "house.fill")
            tabButton(tab: .capture, title: "Capture", systemImage: "plus.circle")
            tabButton(tab: .focus, title: "Focus", systemImage: "scope")
            tabButton(tab: .tools, title: "Tools", systemImage: "square.grid.2x2")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(BetaFocusedDashboardPalette.border, lineWidth: 0.8)
        }
        .shadow(color: BetaFocusedDashboardPalette.softShadow, radius: 18, x: 0, y: 8)
    }

    private func tabButton(tab: BetaFocusedDashboardTab, title: String, systemImage: String) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: isSelected ? .semibold : .medium))

                Text(title)
                    .font(BetaFocusedDashboardTypography.nav.weight(isSelected ? .semibold : .medium))
            }
            .foregroundStyle(isSelected ? BetaFocusedDashboardPalette.navAccent : BetaFocusedDashboardPalette.secondaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .overlay(alignment: .top) {
                if isSelected {
                    Capsule()
                        .fill(BetaFocusedDashboardPalette.navAccent)
                        .frame(width: 24, height: 3)
                        .offset(y: -8)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private enum TimeOfDayPhase {
    case morning
    case day
    case evening
    case night

    static var current: TimeOfDayPhase {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<10: return .morning
        case 10..<17: return .day
        case 17..<21: return .evening
        default: return .night
        }
    }

    var symbolName: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .day: return "sun.max.fill"
        case .evening: return "sunset.fill"
        case .night: return "moon.stars.fill"
        }
    }

    var symbolGradient: [Color] {
        switch self {
        case .morning: return [Color(hex: 0xF7C26B), Color(hex: 0xF4A45C)]
        case .day: return [Color(hex: 0xFFD27A), Color(hex: 0xF6A148)]
        case .evening: return [Color(hex: 0xE5896A), Color(hex: 0xCB6E78)]
        case .night: return [Color(hex: 0x9DA4D8), Color(hex: 0x6F77B6)]
        }
    }

    var glowColor: Color {
        switch self {
        case .morning: return Color(hex: 0xFFD78C)
        case .day: return Color(hex: 0xFFC76A)
        case .evening: return Color(hex: 0xE5896A)
        case .night: return Color(hex: 0xB6BDE7)
        }
    }
}
