//
//  BetaDashboardComponents.swift
//  LifeTrack
//
//  Reusable chrome extracted from BetaDashboardView: tab bar,
//  document row, summary card, and hero pager.
//

import Combine
import SwiftUI

// MARK: - Tab Bar

struct BetaDashboardTabBar: View {
    @Binding var selectedTab: BetaTab

    private struct Item {
        let tab: BetaTab
        let icon: String
        let selectedIcon: String
        let label: String
    }

    private let items: [Item] = [
        Item(tab: .home, icon: "house", selectedIcon: "house.fill", label: "Home"),
        Item(tab: .tasks, icon: "list.bullet", selectedIcon: "list.bullet", label: "Tasks"),
        Item(tab: .focus, icon: "scope", selectedIcon: "scope", label: "Focus"),
        Item(tab: .habits, icon: "flame", selectedIcon: "flame.fill", label: "Habits"),
        Item(tab: .more, icon: "ellipsis", selectedIcon: "ellipsis", label: "More")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.tab) { item in
                tabButton(item)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(BetaPalette.footerFill)
                .shadow(color: Color.black.opacity(0.18), radius: 20, y: 10)
                .shadow(color: BetaPalette.accent.opacity(LifeTrackAppTheme.isDarkModeEnabled ? 0.20 : 0.08), radius: 20, y: 8)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(BetaPalette.footerStroke, lineWidth: 1)
        }
    }

    private func tabButton(_ item: Item) -> some View {
        let isSelected = selectedTab == item.tab
        return Button {
            selectedTab = item.tab
        } label: {
            VStack(spacing: 5) {
                Image(systemName: isSelected ? item.selectedIcon : item.icon)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? BetaPalette.accent : BetaPalette.lightChromeText)
                Text(item.label)
                    .font(.betaCaption(11, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? BetaPalette.accent : BetaPalette.lightChromeText)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Recent Document Row

struct BetaRecentDocumentRow: View {
    let task: LifeTask
    let categoryOption: TaskCategoryOption

    var body: some View {
        HStack(spacing: LifeTrackTheme.Spacing.medium) {
            Image(systemName: "doc.text")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(categoryOption.tint)
                .frame(width: 42, height: 42)
                .background(categoryOption.background, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(task.documentDisplayName ?? "Document")
                    .font(.lifeTrack(.subheadline, weight: .semibold))
                    .foregroundStyle(BetaPalette.lightCardPrimaryText)
                    .lineLimit(1)

                Text(task.title)
                    .font(.lifeTrack(.footnote, weight: .regular))
                    .foregroundStyle(BetaPalette.lightCardSecondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(BetaPalette.lightCardTertiaryText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(BetaPalette.lightCardFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(BetaPalette.lightCardBorder, lineWidth: 0.7)
        }
    }
}

// MARK: - Summary Task Card

struct BetaSummaryTaskCard: View {
    let task: LifeTask
    let categoryOption: TaskCategoryOption
    let onToggleCompletion: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: LifeTrackTheme.Spacing.small) {
            Button(action: onToggleCompletion) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(task.isCompleted ? LifeTrackTheme.ColorPalette.success : LifeTrackTheme.ColorPalette.tertiaryText)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 7) {
                Text(task.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(task.isCompleted ? LifeTrackTheme.ColorPalette.secondaryText : LifeTrackTheme.ColorPalette.primaryText)
                    .strikethrough(task.isCompleted)
                    .lineLimit(2)

                WrappingChipLayout(spacing: 7, rowSpacing: 6) {
                    CategoryChipView(option: categoryOption)

                    StatusPillView(
                        title: task.dueDate.dayMonthString,
                        symbolName: task.isOverdue ? "exclamationmark.circle.fill" : "clock",
                        tint: task.isOverdue ? LifeTrackTheme.ColorPalette.danger : LifeTrackTheme.ColorPalette.secondaryText
                    )

                    StatusPillView(
                        title: task.durationTitle,
                        symbolName: "timer",
                        tint: LifeTrackTheme.ColorPalette.secondaryText
                    )

                    if task.priority == .high {
                        StatusPillView(
                            title: "High",
                            symbolName: "flag.fill",
                            tint: TaskPriority.high.tint
                        )
                    }

                    if task.recurrence != .none {
                        StatusPillView(
                            title: task.recurrence.shortTitle,
                            symbolName: "repeat",
                            tint: task.recurrence.tint
                        )
                    }

                    if task.hasDocument {
                        Image(systemName: "paperclip")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                            .frame(width: 22, height: 22)
                            .background(LifeTrackTheme.ColorPalette.backgroundTop, in: Circle())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Menu {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }
                Button(role: .destructive, action: onDelete) {
                    Label("Move to Bin", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .frame(width: 30, height: 30)
                    .background(LifeTrackTheme.ColorPalette.backgroundBottom.opacity(0.8), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(LifeTrackTheme.ColorPalette.cardElevated, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.8), lineWidth: 0.7)
        }
    }
}

// MARK: - Hero Pager

struct HeroPager: View {
    let pages: [AnyView]
    var isPremium: Bool = false

    private let cardHeight: CGFloat = 240
    @State private var currentIndex: Int? = 0
    @State private var isDragging: Bool = false
    @State private var lastInteraction: Date = .distantPast
    @State private var isPinned: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(pages.indices, id: \.self) { index in
                        pages[index]
                            .frame(height: cardHeight)
                            .containerRelativeFrame(.horizontal)
                            .id(index)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $currentIndex)
            .scrollDisabled(isPinned)
            .frame(height: cardHeight)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isDragging { isDragging = true }
                    }
                    .onEnded { _ in
                        isDragging = false
                        lastInteraction = Date()
                    }
            )
            .overlay(alignment: .topTrailing) {
                if isPremium {
                    HeroPagerPinButton(isPinned: $isPinned)
                        .padding(.top, 14)
                        .padding(.trailing, 16)
                }
            }
            .onChange(of: currentIndex) { _, _ in
                lastInteraction = Date()
            }
            .onReceive(Timer.publish(every: 7, on: .main, in: .common).autoconnect()) { now in
                guard !isPinned else { return }
                guard !isDragging else { return }
                guard !pages.isEmpty else { return }
                guard now.timeIntervalSince(lastInteraction) >= 6.5 else { return }
                let current = currentIndex ?? 0
                withAnimation(.easeInOut(duration: 0.45)) {
                    currentIndex = (current + 1) % pages.count
                }
                lastInteraction = now
            }

            HeroPagerDots(currentIndex: currentIndex ?? 0, count: pages.count)
        }
    }
}

private struct HeroPagerPinButton: View {
    @Binding var isPinned: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                isPinned.toggle()
            }
        } label: {
            Image(systemName: isPinned ? "pin.fill" : "pin")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(isPinned ? Color.red : BetaPalette.secondaryText)
                .rotationEffect(.degrees(isPinned ? 0 : 35))
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(isPinned ? Color.red.opacity(0.16) : LifeTrackTheme.ColorPalette.cardElevated.opacity(0.85))
                )
                .overlay(
                    Circle()
                        .stroke(isPinned ? Color.red.opacity(0.55) : LifeTrackTheme.ColorPalette.hairline.opacity(0.7), lineWidth: 0.8)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPinned ? "Unpin slide" : "Pin slide")
    }
}

struct HeroPagerDots: View {
    let currentIndex: Int
    let count: Int

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == currentIndex ? BetaPalette.accent : BetaPalette.accent.opacity(0.25))
                    .frame(width: i == currentIndex ? 20 : 7, height: 7)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentIndex)
    }
}
