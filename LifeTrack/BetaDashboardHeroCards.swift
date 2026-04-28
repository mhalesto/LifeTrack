//
//  BetaDashboardHeroCards.swift
//  LifeTrack
//
//  Hero pager cards extracted from BetaDashboardView. Each card takes only
//  the values it actually needs - no shared @Query / @EnvironmentObject -
//  so the parent stays responsible for computing streaks, counts, and
//  routing taps to sheets.
//

import SwiftUI

// MARK: - Today plan

struct TodayPlanHeroCard: View {
    let dueToday: Int
    let upcoming: Int
    let overdue: Int
    let canPresentSheet: Bool
    let onPlanMyDay: () -> Void
    let onOpenAI: () -> Void

    var body: some View {
        let subtitle: String
        if overdue > 0 {
            subtitle = "\(overdue) overdue task\(overdue == 1 ? "" : "s") need a decision before new work."
        } else if dueToday > 0 {
            subtitle = "\(dueToday) task\(dueToday == 1 ? "" : "s") due today. Start with the clearest next step."
        } else {
            subtitle = "No tasks due today. Pull one upcoming item forward if you want momentum."
        }

        return productivityHeroShell {
            VStack(alignment: .leading, spacing: 9) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Today's Plan")
                        .font(.betaHeroTitle)
                        .foregroundStyle(BetaPalette.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Text(subtitle)
                        .font(.betaBody(13))
                        .foregroundStyle(BetaPalette.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    heroMetricPill(
                        title: "Due",
                        value: dueToday.formatted(),
                        subtitle: "today",
                        tint: BetaPalette.statDueToday,
                        symbolName: "sun.max.fill"
                    )
                    heroMetricPill(
                        title: "Next",
                        value: upcoming.formatted(),
                        subtitle: "upcoming",
                        tint: BetaPalette.statUpcoming,
                        symbolName: "calendar"
                    )
                    heroMetricPill(
                        title: "Risk",
                        value: overdue.formatted(),
                        subtitle: "overdue",
                        tint: BetaPalette.statOverdue,
                        symbolName: "exclamationmark.triangle.fill"
                    )
                }

                Spacer(minLength: 0)

                HStack(spacing: 10) {
                    heroActionButton(title: "Plan My Day", systemImage: "wand.and.stars", action: onPlanMyDay)
                        .disabled(!canPresentSheet)
                        .opacity(canPresentSheet ? 1 : 0.65)

                    Spacer(minLength: 0)

                    heroInlineActionButton(title: "AI", systemImage: "brain.head.profile", action: onOpenAI)
                }
            }
        }
    }
}

// MARK: - Weekly rhythm

struct WeeklyRhythmCard: View {
    let counts: [Int]
    let streakWeek: Int
    let canOpenReview: Bool
    let onOpenReview: () -> Void

    var body: some View {
        let maxV = max(counts.max() ?? 0, 1)
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekAgo = cal.date(byAdding: .day, value: -6, to: today) ?? today
        let symbols = cal.veryShortWeekdaySymbols

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(BetaPalette.heroBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(BetaPalette.heroShellStroke, lineWidth: 1)
                }
                .shadow(color: BetaPalette.heroShadow, radius: 18, y: 8)

            VStack(alignment: .leading, spacing: 9) {
                Text("This Week's Rhythm")
                    .font(.betaHeroTitle)
                    .foregroundStyle(BetaPalette.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(streakWeek > 0
                     ? "You finished a task on \(streakWeek) of 7 days."
                     : "No completions yet.\nFinish one to start the rhythm.")
                    .font(.betaBody(13))
                    .foregroundStyle(BetaPalette.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(0..<7, id: \.self) { i in
                        let day = cal.date(byAdding: .day, value: i, to: weekAgo) ?? today
                        let isToday = cal.isDate(day, inSameDayAs: today)
                        let heightValue = max(6, CGFloat(counts[i]) / CGFloat(maxV) * 58)
                        VStack(spacing: 4) {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: isToday
                                            ? [BetaPalette.accent, BetaPalette.accentDeep]
                                            : [BetaPalette.accent.opacity(0.55), BetaPalette.accent.opacity(0.28)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(height: heightValue)
                            Text(symbols[cal.component(.weekday, from: day) - 1])
                                .font(.system(size: 10, weight: isToday ? .bold : .medium))
                                .foregroundStyle(isToday ? BetaPalette.primaryText : BetaPalette.secondaryText)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 78)

                Button(action: onOpenReview) {
                    HStack(spacing: 6) {
                        Text("Open Review")
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
                .disabled(!canOpenReview)
                .opacity(canOpenReview ? 1 : 0.65)
            }
            .padding(.horizontal, 22)
            .padding(.top, 16)
            .padding(.bottom, 12)
        }
        .frame(minHeight: 240)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

// MARK: - Next move

struct NextMoveHeroCard: View {
    let focusCount: Int
    let activeCount: Int
    let completedCount: Int
    let overdue: Int
    let upcoming: Int
    let dueToday: Int
    let canPresentSheet: Bool
    let onReview: () -> Void

    var body: some View {
        let completionShare = activeCount == 0 ? 0 : Int((Double(completedCount) / Double(activeCount)) * 100)
        let subtitle: String
        if overdue > 0 {
            subtitle = "Clear or reschedule the backlog so today feels honest."
        } else if upcoming > dueToday {
            subtitle = "Your next seven days are loaded. Decide what deserves attention now."
        } else {
            subtitle = "Your queue is light. Review progress and keep priorities tidy."
        }

        return productivityHeroShell {
            VStack(alignment: .leading, spacing: 10) {
                VStack(spacing: 9) {
                    heroProgressRow(
                        title: "Open queue",
                        value: "\(focusCount)",
                        progress: activeCount == 0 ? 0 : Double(focusCount) / Double(max(activeCount, 1)),
                        tint: BetaPalette.accent
                    )
                    heroProgressRow(
                        title: "Completed share",
                        value: "\(completionShare)%",
                        progress: Double(completionShare) / 100,
                        tint: BetaPalette.statCompleted
                    )
                    heroProgressRow(
                        title: "Overdue pressure",
                        value: "\(overdue)",
                        progress: min(Double(overdue) / Double(max(focusCount, 1)), 1),
                        tint: BetaPalette.statOverdue
                    )
                }
                .padding(10)
                .background(BetaPalette.heroGlassFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .center, spacing: 10) {
                        Text("Next Best Move")
                            .font(.betaHeroTitle)
                            .foregroundStyle(BetaPalette.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.70)

                        Spacer(minLength: 6)

                        heroInlineActionButton(title: "Review", systemImage: "chart.bar.fill", action: onReview)
                            .disabled(!canPresentSheet)
                            .opacity(canPresentSheet ? 1 : 0.65)
                    }

                    Text(subtitle)
                        .font(.betaCaption(12, weight: .medium))
                        .foregroundStyle(BetaPalette.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - Streak hero

struct StreakHeroCard: View {
    let streakCurrent: Int
    let streakBest: Int
    let streakWeek: Int
    let streakSubtitle: String
    let canPresentSheet: Bool
    let onViewStreaks: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Card background
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(BetaPalette.heroBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(BetaPalette.heroShellStroke, lineWidth: 1)
                }
                .shadow(color: BetaPalette.heroShadow, radius: 18, y: 8)

            // Illustration on right - extends down so the stone reads above the stats row
            HStack {
                Spacer(minLength: 110)
                StreakHeroIllustration()
                    .scaleEffect(0.82)
                    .frame(width: 180, height: 180)
                    .padding(.trailing, -12)
            }
            .padding(.top, 4)
            .frame(maxWidth: .infinity, alignment: .trailing)

            // Left text + docked stats
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("\(streakCurrent)-day streak")
                        .font(.betaHeroTitle)
                        .foregroundStyle(BetaPalette.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(streakSubtitle)
                        .font(.betaBody(14))
                        .foregroundStyle(BetaPalette.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(action: onViewStreaks) {
                        HStack(spacing: 6) {
                            Text("View Streaks")
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
                    .disabled(!canPresentSheet)
                    .opacity(canPresentSheet ? 1 : 0.65)
                }
                .padding(.horizontal, 22)
                .padding(.top, 20)

                Spacer(minLength: 6)

                // Docked stats row
                StreakStatsRowView(streakCurrent: streakCurrent, streakBest: streakBest, streakWeek: streakWeek)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(minHeight: 240)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct StreakStatsRowView: View {
    let streakCurrent: Int
    let streakBest: Int
    let streakWeek: Int

    var body: some View {
        HStack(spacing: 0) {
            streakStatCell(icon: "flame.fill", iconTint: BetaPalette.accent, value: "\(streakCurrent)", unit: "Day", label: "Current")
            Divider().frame(height: 44).overlay(BetaPalette.faintBorder)
            streakStatCell(icon: "star.fill", iconTint: BetaPalette.accent, value: "\(streakBest)", unit: "Days", label: "Best")
            Divider().frame(height: 44).overlay(BetaPalette.faintBorder)
            streakStatCell(icon: "calendar", iconTint: BetaPalette.accent, value: "\(streakWeek)/7", unit: "Days", label: "This Week")
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(BetaPalette.heroGlassFill)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(BetaPalette.heroGlassStroke, lineWidth: 1)
        }
    }
}

// MARK: - Upgrade

struct UpgradeHeroCard: View {
    let isUltimate: Bool
    let canPresentSheet: Bool
    let onSeePlans: () -> Void

    private static let features: [(String, String)] = [
        ("brain.head.profile", "AI Suggestions"),
        ("calendar.badge.clock", "Smart Schedule"),
        ("icloud.fill", "Auto Backups"),
        ("timer", "Focus Timer"),
        ("flame.fill", "Habit Streaks"),
        ("doc.badge.plus", "Templates"),
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(BetaPalette.heroBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(BetaPalette.heroShellStroke, lineWidth: 1)
                }
                .shadow(color: BetaPalette.heroShadow, radius: 18, y: 8)

            VStack(alignment: .leading, spacing: 0) {
                // - top row: title + crown
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(isUltimate ? "You're Ultimate" : "Unlock Ultimate")
                            .font(.betaHeroTitle)
                            .foregroundStyle(BetaPalette.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        Text(isUltimate
                             ? "Every premium feature unlocked."
                             : "AI, scheduling, backups & more.")
                            .font(.betaBody(13))
                            .foregroundStyle(BetaPalette.secondaryText)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [BetaPalette.accent.opacity(0.18), BetaPalette.accentDeep.opacity(0.10)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 52, height: 52)
                        Image(systemName: isUltimate ? "crown.fill" : "sparkles")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [BetaPalette.accent, BetaPalette.accentDeep],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }

                Spacer(minLength: 12)

                // - feature chips grid
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                    spacing: 8
                ) {
                    ForEach(Self.features, id: \.0) { icon, label in
                        HStack(spacing: 5) {
                            Image(systemName: icon)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(BetaPalette.accent)
                            Text(label)
                                .font(.betaCaption(10, weight: .semibold))
                                .foregroundStyle(BetaPalette.primaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(BetaPalette.heroGlassFill.opacity(isUltimate ? 1 : 0.9), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(BetaPalette.heroGlassStroke, lineWidth: 0.7)
                        }
                    }
                }

                Spacer(minLength: 14)

                // - CTA button
                Button {
                    if !isUltimate { onSeePlans() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isUltimate ? "checkmark.seal.fill" : "crown.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text(isUltimate ? "Your Plan" : "See Plans")
                            .font(.betaBody(14, weight: .semibold))
                        if !isUltimate {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: 0x1F1B2E), Color(hex: 0x2A2540)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .shadow(color: Color.black.opacity(0.18), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(isUltimate || !canPresentSheet)
                .opacity(isUltimate ? 0.8 : 1)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .frame(minHeight: 240)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
