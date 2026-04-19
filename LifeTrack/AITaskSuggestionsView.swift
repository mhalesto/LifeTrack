//
//  AITaskSuggestionsView.swift
//  LifeTrack
//

import SwiftData
import SwiftUI

struct AITaskSuggestionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var advisor = AITaskAdvisor.shared

    let tasks: [LifeTask]

    @State private var appliedIDs: Set<UUID> = []

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
            if advisor.focusSuggestions.isEmpty && advisor.overallInsight.isEmpty {
                await advisor.analyze(tasks: tasks)
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
                    Image(systemName: "sparkles")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(Color(red: 0.95, green: 0.82, blue: 0.3))
                }
                VStack(spacing: 6) {
                    Text("AI Task Suggestions")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                    Text("Powered by Claude · Ultimate")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
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
            suggestionsContent
        }
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 40)
            ProgressView()
                .scaleEffect(1.4)
                .tint(Color(red: 0.95, green: 0.72, blue: 0.1))
            Text("Analysing your tasks…")
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
                Task { await advisor.analyze(tasks: tasks) }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color(red: 0.95, green: 0.72, blue: 0.1))
        }
        .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
    }

    private var suggestionsContent: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.xLarge) {
            if !advisor.overallInsight.isEmpty {
                insightCard
            }
            if !advisor.focusSuggestions.isEmpty {
                section(title: "Focus Today", icon: "target", color: Color(red: 0.95, green: 0.72, blue: 0.1)) {
                    ForEach(advisor.focusSuggestions) { suggestion in
                        suggestionRow(suggestion)
                    }
                }
            }
            if !advisor.rescheduleSuggestions.isEmpty {
                section(title: "Reschedule", icon: "calendar.badge.clock", color: Color(red: 0.45, green: 0.65, blue: 0.95)) {
                    ForEach(advisor.rescheduleSuggestions) { suggestion in
                        suggestionRow(suggestion)
                    }
                }
            }
            refreshButton
        }
        .padding(.top, LifeTrackTheme.Spacing.xLarge)
    }

    // MARK: - Insight Card

    private var insightCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(red: 0.95, green: 0.82, blue: 0.3))
                .frame(width: 32, height: 32)
                .background(Color(red: 0.95, green: 0.82, blue: 0.3).opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text("Insight")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(red: 0.95, green: 0.82, blue: 0.3))
                Text(advisor.overallInsight)
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

    // MARK: - Section

    private func section<Content: View>(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.small) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
            }
            VStack(spacing: LifeTrackTheme.Spacing.small) {
                content()
            }
        }
    }

    // MARK: - Suggestion Row

    private func suggestionRow(_ suggestion: AITaskSuggestion) -> some View {
        let applied = appliedIDs.contains(suggestion.id)
        let accentColor: Color = suggestion.type == .focus
            ? Color(red: 0.95, green: 0.72, blue: 0.1)
            : Color(red: 0.45, green: 0.65, blue: 0.95)

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.taskTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    .lineLimit(2)
                Text(suggestion.reasoning)
                    .font(.caption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .lineLimit(2)
            }

            Spacer()

            if suggestion.type == .reschedule && !applied {
                Button {
                    applyReschedule(suggestion)
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 13, weight: .semibold))
                        Text(suggestion.badge)
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(accentColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                Text(suggestion.badge)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(applied ? .green : accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((applied ? Color.green : accentColor).opacity(0.12), in: Capsule())
                    .overlay(Capsule().stroke((applied ? Color.green : accentColor).opacity(0.3), lineWidth: 1))
            }
        }
        .padding(LifeTrackTheme.Spacing.medium)
        .background(LifeTrackTheme.ColorPalette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Refresh

    private var refreshButton: some View {
        VStack(spacing: 6) {
            Button {
                Task { await advisor.analyze(tasks: tasks) }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh Analysis")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(red: 0.95, green: 0.72, blue: 0.1))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(red: 0.95, green: 0.72, blue: 0.1).opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            if let date = advisor.lastRefreshed {
                Text("Last updated \(date.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
            }
        }
    }

    // MARK: - Actions

    private func applyReschedule(_ suggestion: AITaskSuggestion) {
        guard let date = suggestion.suggestedDate,
              let task = tasks.first(where: { $0.id == suggestion.taskID }) else { return }
        task.dueDate = date
        task.updatedAt = Date()
        try? modelContext.save()
        _ = withAnimation(.snappy) { appliedIDs.insert(suggestion.id) }
    }
}
