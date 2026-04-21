//
//  SmartSchedulingOptimizerView.swift
//  LifeTrack
//

import SwiftUI

struct SmartSchedulingOptimizerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var advisor = SmartSchedulingAdvisor.shared
    @ObservedObject private var energyReader = HealthKitEnergyReader.shared

    let tasks: [LifeTask]

    private let gold = Color(red: 0.95, green: 0.72, blue: 0.1)

    var body: some View {
        ZStack(alignment: .top) {
            LifeTrackTheme.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    header
                    content
                        .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
                        .padding(.bottom, LifeTrackTheme.Spacing.xxLarge)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText.opacity(0.7))
                    .symbolRenderingMode(.hierarchical)
            }
            .padding(LifeTrackTheme.Spacing.xLarge)
        }
        .task {
            if advisor.scheduledBlocks.isEmpty && advisor.dayStrategy.isEmpty {
                await energyReader.refresh()
                await advisor.optimize(tasks: tasks, energyLevel: energyReader.energyLevel)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.12, green: 0.06, blue: 0.28), Color(red: 0.07, green: 0.04, blue: 0.18)],
                startPoint: .top, endPoint: .bottom
            )
            VStack(spacing: 14) {
                Spacer().frame(height: 48)
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.08))
                        .frame(width: 72, height: 72)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(gold)
                }
                VStack(spacing: 6) {
                    Text("Smart Scheduling")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                    HStack(spacing: 6) {
                        Image(systemName: energyReader.energyLevel.sfSymbol)
                            .font(.caption)
                            .foregroundStyle(energyReader.energyLevel.color)
                        Text("\(energyReader.energyLevel.label) · Powered by Claude · Ultimate")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                Spacer().frame(height: 24)
            }
        }
        .frame(height: 210)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if advisor.isLoading {
            loadingView
        } else if let error = advisor.error {
            errorView(error)
        } else {
            scheduleContent
        }
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 40)
            ProgressView()
                .scaleEffect(1.4)
                .tint(gold)
            Text("Building your optimal schedule…")
                .font(.subheadline)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 32)
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(LifeTrackTheme.ColorPalette.danger)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task {
                    await energyReader.refresh()
                    await advisor.optimize(tasks: tasks, energyLevel: energyReader.energyLevel)
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(gold)
        }
        .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
    }

    private var scheduleContent: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.xLarge) {
            if !advisor.dayStrategy.isEmpty {
                strategyCard
            }
            if !advisor.scheduledBlocks.isEmpty {
                timelineSection
            }
            if !advisor.unscheduledTitles.isEmpty {
                unscheduledSection
            }
            refreshButton
        }
        .padding(.top, LifeTrackTheme.Spacing.xLarge)
    }

    // MARK: - Strategy Card

    private var strategyCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(red: 0.95, green: 0.82, blue: 0.3))
                .frame(width: 32, height: 32)
                .background(Color(red: 0.95, green: 0.82, blue: 0.3).opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text("Today's Strategy")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(red: 0.95, green: 0.82, blue: 0.3))
                Text(advisor.dayStrategy)
                    .font(.subheadline)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(LifeTrackTheme.Spacing.medium)
        .background(Color(red: 0.95, green: 0.82, blue: 0.3).opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(red: 0.95, green: 0.82, blue: 0.3).opacity(0.2), lineWidth: 1)
        }
    }

    // MARK: - Timeline

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.small) {
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(gold)
                Text("Optimized Schedule")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
            }

            VStack(spacing: 0) {
                ForEach(Array(advisor.scheduledBlocks.enumerated()), id: \.element.id) { index, block in
                    blockRow(block, isLast: index == advisor.scheduledBlocks.count - 1)
                }
            }
            .background(LifeTrackTheme.ColorPalette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func blockRow(_ block: ScheduledBlock, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(spacing: 2) {
                    Text(block.start)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(gold)
                        .monospacedDigit()
                    Text(block.end)
                        .font(.caption2)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
                        .monospacedDigit()
                }
                .frame(width: 44)

                Rectangle()
                    .fill(gold.opacity(0.3))
                    .frame(width: 2)
                    .frame(height: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(block.taskTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                        .lineLimit(2)
                    Text(block.reasoning)
                        .font(.caption)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .lineLimit(2)
                }

                Spacer()

                Text(block.energyTag)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(gold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(gold.opacity(0.12), in: Capsule())
                    .overlay(Capsule().stroke(gold.opacity(0.3), lineWidth: 1))
            }
            .padding(LifeTrackTheme.Spacing.medium)

            if !isLast {
                Divider()
                    .padding(.horizontal, LifeTrackTheme.Spacing.medium)
            }
        }
    }

    // MARK: - Unscheduled

    private var unscheduledSection: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.small) {
            HStack(spacing: 6) {
                Image(systemName: "tray.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                Text("Carry Over")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
            }

            VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.small) {
                ForEach(Array(advisor.unscheduledTitles.enumerated()), id: \.offset) { _, title in
                    HStack(spacing: 8) {
                        Image(systemName: "circle")
                            .font(.system(size: 12))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
                        Text(title)
                            .font(.subheadline)
                            .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, LifeTrackTheme.Spacing.medium)
                    .padding(.vertical, 10)
                    .background(LifeTrackTheme.ColorPalette.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    // MARK: - Refresh

    private var refreshButton: some View {
        VStack(spacing: 6) {
            Button {
                Task {
                    await energyReader.refresh()
                    await advisor.optimize(tasks: tasks, energyLevel: energyReader.energyLevel)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh Schedule")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(gold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(gold.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            if let date = advisor.lastRefreshed {
                Text("Last updated \(date.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
            }
        }
    }
}
