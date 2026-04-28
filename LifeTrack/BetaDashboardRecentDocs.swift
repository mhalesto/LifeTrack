//
//  BetaDashboardRecentDocs.swift
//  LifeTrack
//
//  Recent documents section extracted from BetaDashboardView. Receives
//  the precomputed list of tasks-with-documents plus the custom categories
//  it needs to render category badges on each row.
//

import SwiftUI

struct BetaDashboardRecentDocsSection: View {
    let documentTasks: [LifeTask]
    let customCategories: [CustomTaskCategory]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Text("Recent Documents")
                    .font(.betaSection)
                    .foregroundStyle(BetaPalette.primaryText)

                Image(systemName: "info.circle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BetaPalette.tertiaryText)

                Spacer(minLength: 0)

                if !documentTasks.isEmpty {
                    Text("\(documentTasks.count)")
                        .font(.betaCaption(12, weight: .semibold))
                        .foregroundStyle(BetaPalette.lightChromeText)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(BetaPalette.lightCardFill, in: Capsule())
                }
            }

            if documentTasks.isEmpty {
                emptyState
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(documentTasks.prefix(3))) { task in
                        NavigationLink {
                            TaskDetailView(task: task)
                        } label: {
                            BetaRecentDocumentRow(
                                task: task,
                                categoryOption: task.categoryOption(customCategories: customCategories)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(BetaPalette.accent.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(BetaPalette.accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("No documents yet")
                    .font(.lifeTrack(.subheadline, weight: .semibold))
                    .foregroundStyle(BetaPalette.lightCardPrimaryText)
                Text("Attach a file from any task to keep supporting context nearby.")
                    .font(.lifeTrack(.footnote, weight: .regular))
                    .foregroundStyle(BetaPalette.lightCardSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BetaPalette.lightCardFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(BetaPalette.lightCardBorder, lineWidth: 0.8)
        }
    }
}
