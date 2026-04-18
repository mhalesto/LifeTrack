//
//  TaskDetailView.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import QuickLook
import SwiftData
import SwiftUI

struct TaskDetailView: View {
    @Environment(\.openURL) private var openURL
    @Query(sort: \CustomTaskCategory.title) private var customCategories: [CustomTaskCategory]
    let task: LifeTask
    @State private var previewURL: URL?

    var body: some View {
        ZStack {
            LifeTrackTheme.appBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.large) {
                    taskHero

                    SectionCardView {
                        SectionHeaderView(title: "Schedule")

                        DetailRow(
                            symbolName: "calendar.badge.clock",
                            title: task.dueDate.weekdayDateString,
                            subtitle: "Due at \(task.dueDate.timeString)",
                            tint: LifeTrackTheme.ColorPalette.accent
                        )
                    }

                    if !task.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        SectionCardView {
                            SectionHeaderView(title: "Notes")

                            Text(task.notes)
                                .font(.body)
                                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if let documentURL {
                        SectionCardView {
                            SectionHeaderView(title: "Document", subtitle: "Stored locally with this task.")

                            Button {
                                previewURL = documentURL
                            } label: {
                                DetailRow(
                                    symbolName: "doc.text",
                                    title: task.documentDisplayName ?? "Document",
                                    subtitle: "Open preview",
                                    tint: categoryOption.tint
                                )
                            }
                            .buttonStyle(.plain)

                            if let shareDocumentURL {
                                ShareLink(
                                    item: shareDocumentURL,
                                    preview: SharePreview(task.documentDisplayName ?? "Document")
                                ) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "square.and.arrow.up")
                                        Text("Share Document")
                                    }
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(LifeTrackTheme.ColorPalette.accentSoft, in: Capsule())
                                }
                            } else {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Share Document")
                                }
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
                            }
                        }
                    }

                    if task.templateAction == .email, let emailURL {
                        SectionCardView {
                            SectionHeaderView(title: "Template Action")

                            Button {
                                openURL(emailURL)
                            } label: {
                                DetailRow(
                                    symbolName: "envelope.badge",
                                    title: "Open Email Draft",
                                    subtitle: "Uses this task title and notes",
                                    tint: LifeTrackTheme.ColorPalette.accent
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
                .padding(.top, LifeTrackTheme.Spacing.medium)
                .padding(.bottom, LifeTrackTheme.Spacing.xxLarge)
            }
            .scrollIndicators(.hidden)
        }
        .navigationBarTitleDisplayMode(.inline)
        .quickLookPreview($previewURL)
    }

    private var taskHero: some View {
        SectionCardView {
            VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.medium) {
                CategoryChipView(option: categoryOption)

                Text(task.title)
                    .font(.system(.title, design: LifeTrackAppTheme.current.fontDesign, weight: .bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    StatusPillView(
                        title: task.isCompleted ? "Completed" : "Open",
                        symbolName: task.isCompleted ? "checkmark.circle.fill" : "circle",
                        tint: task.isCompleted ? LifeTrackTheme.ColorPalette.success : LifeTrackTheme.ColorPalette.accent
                    )

                    StatusPillView(
                        title: task.dueDate.dayMonthString,
                        symbolName: task.isOverdue ? "exclamationmark.circle.fill" : "calendar",
                        tint: task.isOverdue ? LifeTrackTheme.ColorPalette.danger : LifeTrackTheme.ColorPalette.secondaryText
                    )

                    if task.hasDocument {
                        StatusPillView(
                            title: "Document",
                            symbolName: "paperclip",
                            tint: LifeTrackTheme.ColorPalette.secondaryText
                        )
                    }
                }
            }
        }
    }

    private var documentURL: URL? {
        guard let storageName = task.documentStorageName else {
            return nil
        }

        return DocumentStore.url(for: storageName)
    }

    private var categoryOption: TaskCategoryOption {
        task.categoryOption(customCategories: customCategories)
    }

    private var shareDocumentURL: URL? {
        guard let storageName = task.documentStorageName else {
            return nil
        }

        return DocumentStore.shareableURL(
            for: storageName,
            displayName: task.documentDisplayName
        )
    }

    private var emailURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.queryItems = [
            URLQueryItem(name: "subject", value: task.title),
            URLQueryItem(name: "body", value: task.notes)
        ]
        return components.url
    }
}

private struct DetailRow: View {
    let symbolName: String
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        HStack(spacing: LifeTrackTheme.Spacing.medium) {
            Image(systemName: symbolName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: LifeTrackTheme.IconSize.largeCircle, height: LifeTrackTheme.IconSize.largeCircle)
                .background(tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    .lineLimit(2)

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
            }

            Spacer()
        }
        .padding(12)
        .background(LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.9), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.85), lineWidth: 0.8)
        }
    }
}

#Preview {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: LifeTask.self, CustomTaskCategory.self, configurations: configuration)

    TaskDetailView(
        task: LifeTask(
            title: "Send follow-up email",
            category: .work,
            dueDate: Calendar.current.date(byAdding: .hour, value: 4, to: Date()) ?? Date(),
            notes: "Subject: Follow up\n\nHi,\n\nI wanted to follow up on this task.",
            templateAction: .email
        )
    )
    .modelContainer(container)
}
