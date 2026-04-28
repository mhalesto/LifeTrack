//
//  BetaDashboardDailyFocus.swift
//  LifeTrack
//
//  Daily Focus section extracted from BetaDashboardView. Receives the
//  precomputed task list + sort metadata plus per-task and per-action
//  callbacks so the parent stays in charge of mutations and sheet
//  presentation.
//

import SwiftUI

struct BetaDashboardDailyFocusSection: View {
    let dailyFocusTasks: [LifeTask]
    let dailyFocusCountLabel: String
    let focusSortOrder: DashboardSortOrder
    let todayFocusProgress: Double
    let customCategories: [CustomTaskCategory]
    let onToggleCompletion: (LifeTask) -> Void
    let onEdit: (LifeTask) -> Void
    let onDelete: (LifeTask) -> Void
    let onPresentSortSheet: () -> Void
    let onResetMyDay: () -> Void
    let onRescheduleOverdue: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.clear)
                .background(
                    DailyFocusBackdrop()
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(BetaPalette.lightCardBorder, lineWidth: 1)
                }
                .shadow(color: BetaPalette.lightCardShadow, radius: 14, y: 6)

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 8) {
                    Text("Daily Focus")
                        .font(.betaSection)
                        .foregroundStyle(BetaPalette.lightCardPrimaryText)

                    Text(dailyFocusCountLabel)
                        .font(.betaCaption(12, weight: .medium))
                        .foregroundStyle(BetaPalette.lightCardSecondaryText)

                    Spacer(minLength: 0)

                    sortButton
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)

                focusList
                    .padding(.horizontal, 14)
                    .padding(.bottom, 18)
            }
        }
    }

    private var sortButton: some View {
        Button(action: onPresentSortSheet) {
            HStack(spacing: 6) {
                Text(focusSortOrder.rawValue)
                    .font(.betaCaption(13, weight: .semibold))
                    .foregroundStyle(BetaPalette.lightCardPrimaryText)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(BetaPalette.lightCardSecondaryText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                ZStack(alignment: .leading) {
                    Capsule().fill(BetaPalette.lightCardFill)
                    if focusSortOrder == .today {
                        GeometryReader { proxy in
                            Capsule()
                                .fill(BetaPalette.accent.opacity(0.24))
                                .frame(width: proxy.size.width * CGFloat(todayFocusProgress))
                        }
                    }
                }
            }
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(
                        focusSortOrder == .today ? BetaPalette.accent.opacity(0.24) : Color.clear,
                        lineWidth: 1
                    )
            }
            .shadow(color: BetaPalette.lightCardShadow, radius: 4, y: 2)
            .animation(.easeInOut(duration: 0.22), value: todayFocusProgress)
            .animation(.easeInOut(duration: 0.18), value: focusSortOrder)
        }
        .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.96, pressedOpacity: 0.92))
    }

    private var focusList: some View {
        Group {
            if dailyFocusTasks.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(BetaPalette.lightCardSecondaryText)
                    Text("Nothing in focus — you're all caught up.")
                        .font(.betaBody(14, weight: .medium))
                        .foregroundStyle(BetaPalette.lightCardSecondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(BetaPalette.lightCardFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                VStack(spacing: 8) {
                    ForEach(dailyFocusTasks) { task in
                        TaskRowView(
                            task: task,
                            onToggleCompletion: { onToggleCompletion(task) },
                            onEdit: { onEdit(task) },
                            onDelete: { onDelete(task) },
                            categoryOption: task.categoryOption(customCategories: customCategories),
                            showsBorder: false
                        )
                        .contextMenu {
                            if FocusActivityController.shared.isPinned(task) {
                                Button(role: .destructive) {
                                    FocusActivityController.shared.stop()
                                } label: {
                                    Label("Unpin from Lock Screen", systemImage: "pin.slash")
                                }
                            } else if !task.isCompleted {
                                Button {
                                    FocusActivityController.shared.start(
                                        for: task,
                                        customCategories: customCategories
                                    )
                                } label: {
                                    Label("Pin to Lock Screen", systemImage: "pin")
                                }
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        betaFocusPlanningButton(
                            title: "Reset My Day",
                            symbol: "arrow.clockwise",
                            tint: BetaPalette.accent,
                            action: onResetMyDay
                        )

                        betaFocusPlanningButton(
                            title: "Reschedule Overdue",
                            symbol: "calendar.badge.clock",
                            tint: BetaPalette.overdue,
                            action: onRescheduleOverdue
                        )
                    }
                }
            }
        }
    }
}
