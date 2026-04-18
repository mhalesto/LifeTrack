//
//  DocumentSearchView.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import SwiftData
import SwiftUI

struct DocumentSearchView: View {
    @Query(sort: \LifeTask.updatedAt, order: .reverse) private var tasks: [LifeTask]
    @Query(sort: \CustomTaskCategory.title) private var customCategories: [CustomTaskCategory]

    @State private var searchText = ""

    var body: some View {
        ZStack {
            LifeTrackTheme.appBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.large) {
                    header
                    searchCard
                    resultSection
                }
                .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
                .padding(.top, LifeTrackTheme.Spacing.medium)
                .padding(.bottom, LifeTrackTheme.Spacing.xxLarge)
            }
            .scrollIndicators(.hidden)
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Documents")
                .font(.lifeTrackHero)
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

            Text("Search uploaded files, extracted text, references, and linked tasks.")
                .font(.subheadline)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var searchCard: some View {
        HStack(spacing: LifeTrackTheme.Spacing.small) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)

            ZStack(alignment: .leading) {
                if searchText.isEmpty {
                    Text("Search insurance, invoice, policy, passport...")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.placeholderText)
                        .lineLimit(1)
                }

                TextField("", text: $searchText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
                }
                .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.9))
                .accessibilityLabel("Clear search")
            }
        }
        .padding(13)
        .background(LifeTrackTheme.ColorPalette.cardElevated, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.85), lineWidth: 0.8)
        }
    }

    private var resultSection: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.small) {
            SectionHeaderView(
                title: "Results",
                trailing: filteredDocuments.isEmpty ? nil : filteredDocuments.count.formatted(),
                infoMessage: "Search runs locally across file names, task titles, OCR text, document summaries, and detected keywords."
            )

            if documentTasks.isEmpty {
                SectionCardView {
                    CompactDocumentSearchMessage(
                        symbolName: "doc.badge.plus",
                        title: "No documents yet",
                        message: "Attach a file to a task and LifeTrack will make it searchable when possible."
                    )
                }
            } else if filteredDocuments.isEmpty {
                SectionCardView {
                    CompactDocumentSearchMessage(
                        symbolName: "magnifyingglass",
                        title: "No matching documents",
                        message: "Try a file name, category, policy number, invoice keyword, or task title."
                    )
                }
            } else {
                VStack(spacing: LifeTrackTheme.Spacing.small) {
                    ForEach(filteredDocuments) { task in
                        NavigationLink {
                            TaskDetailView(task: task)
                        } label: {
                            DocumentSearchResultRow(
                                task: task,
                                categoryOption: task.categoryOption(customCategories: customCategories),
                                query: searchText
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var documentTasks: [LifeTask] {
        tasks
            .filter(\.hasDocument)
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var filteredDocuments: [LifeTask] {
        let cleanedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedQuery.isEmpty else {
            return documentTasks
        }

        return documentTasks.filter { task in
            searchBlob(for: task)
                .range(of: cleanedQuery, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    private func searchBlob(for task: LifeTask) -> String {
        [
            task.title,
            task.notes,
            task.documentDisplayName ?? "",
            task.documentAnalysisSummary ?? "",
            task.documentSuggestedTitle ?? "",
            task.documentKeywords.joined(separator: " "),
            task.documentExtractedText
        ]
        .joined(separator: " ")
    }
}

private struct DocumentSearchResultRow: View {
    let task: LifeTask
    let categoryOption: TaskCategoryOption
    let query: String

    var body: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.small) {
            HStack(alignment: .top, spacing: LifeTrackTheme.Spacing.medium) {
                Image(systemName: "doc.text")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(categoryOption.tint)
                    .frame(width: LifeTrackTheme.IconSize.largeCircle, height: LifeTrackTheme.IconSize.largeCircle)
                    .background(categoryOption.background, in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text(task.documentDisplayName ?? "Document")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                        .lineLimit(1)

                    Text(task.title)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
            }

            if let summary = task.documentAnalysisSummary {
                Text(summary)
                    .font(.footnote)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .lineLimit(2)
            }

            if !task.documentKeywords.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 7) {
                        ForEach(task.documentKeywords.prefix(5), id: \.self) { keyword in
                            Text(keyword.capitalized)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(LifeTrackTheme.ColorPalette.accentSoft, in: Capsule())
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let snippet {
                Text(snippet)
                    .font(.caption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .lineLimit(2)
                    .padding(9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.86), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
            }
        }
        .padding(12)
        .background(LifeTrackTheme.ColorPalette.cardElevated, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.8), lineWidth: 0.7)
        }
    }

    private var snippet: String? {
        let cleanedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedQuery.isEmpty else {
            return nil
        }

        let searchable = task.documentExtractedText
        guard let range = searchable.range(of: cleanedQuery, options: [.caseInsensitive, .diacriticInsensitive]) else {
            return nil
        }

        let lowerBound = searchable.index(range.lowerBound, offsetBy: -80, limitedBy: searchable.startIndex) ?? searchable.startIndex
        let upperBound = searchable.index(range.upperBound, offsetBy: 140, limitedBy: searchable.endIndex) ?? searchable.endIndex
        return String(searchable[lowerBound..<upperBound])
    }
}

private struct CompactDocumentSearchMessage: View {
    let symbolName: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: LifeTrackTheme.Spacing.medium) {
            Image(systemName: symbolName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                .frame(width: LifeTrackTheme.IconSize.largeCircle, height: LifeTrackTheme.IconSize.largeCircle)
                .background(LifeTrackTheme.ColorPalette.accentSoft, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                Text(message)
                    .font(.footnote)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: LifeTask.self, CustomTaskCategory.self, configurations: configuration)
    let task = LifeTask(
        title: "Renew insurance",
        category: .finance,
        dueDate: Date(),
        documentStorageName: "insurance.pdf",
        documentDisplayName: "Insurance policy.pdf",
        documentExtractedText: "Policy renewal date 18 May. Invoice reference INV-2940.",
        documentAnalysisSummary: "Detected: insurance, policy. Date found: 18 May.",
        documentSuggestedTitle: "Renew insurance by 18 May",
        documentKeywords: ["insurance", "policy", "renewal"]
    )
    container.mainContext.insert(task)

    return NavigationStack {
        DocumentSearchView()
    }
    .modelContainer(container)
}
