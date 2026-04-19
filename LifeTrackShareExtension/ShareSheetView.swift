//
//  ShareSheetView.swift
//  LifeTrackShareExtension
//

import Combine
import SwiftUI

struct SharedAttachmentPreview: Identifiable, Equatable {
    let id: UUID
    let symbolName: String
    let displayName: String
    let typeDetail: String
}

final class ShareSheetModel: ObservableObject {
    @Published var note: String = ""
    @Published var previews: [SharedAttachmentPreview] = []
    @Published var isLoading: Bool = true
    @Published var isPosting: Bool = false
}

struct ShareSheetView: View {
    @ObservedObject var model: ShareSheetModel
    var onCancel: () -> Void
    var onPost: () -> Void

    @FocusState private var noteFocused: Bool

    private var canPost: Bool {
        guard !model.isPosting else { return false }
        if !model.previews.isEmpty { return true }
        return !model.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            LifeTrackShareTheme.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 14)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        attachmentsSection
                        notesCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                noteFocused = true
            }
        }
    }

    private var topBar: some View {
        HStack(alignment: .center) {
            Button(action: onCancel) {
                Text("Cancel")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(LifeTrackShareTheme.secondaryText)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        Capsule().fill(LifeTrackShareTheme.cardBackground)
                    )
                    .overlay {
                        Capsule().stroke(LifeTrackShareTheme.hairline, lineWidth: 0.7)
                    }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 12)

            Button(action: onPost) {
                HStack(spacing: 6) {
                    if model.isPosting {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 13, weight: .bold))
                    }
                    Text(model.isPosting ? "Posting" : "Post")
                        .font(.system(.subheadline, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 10)
                .background {
                    Capsule()
                        .fill(canPost
                              ? AnyShapeStyle(LifeTrackShareTheme.accentGradient)
                              : AnyShapeStyle(LifeTrackShareTheme.accent.opacity(0.35)))
                }
                .shadow(color: canPost ? LifeTrackShareTheme.accent.opacity(0.28) : .clear, radius: 10, x: 0, y: 5)
            }
            .buttonStyle(.plain)
            .disabled(!canPost)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LifeTrackShareTheme.accentGradient)
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .shadow(color: LifeTrackShareTheme.accent.opacity(0.3), radius: 8, x: 0, y: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text("Send to LifeTrack")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(LifeTrackShareTheme.primaryText)
                Text("We'll create a review task from what you share.")
                    .font(.footnote)
                    .foregroundStyle(LifeTrackShareTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var attachmentsSection: some View {
        if model.isLoading {
            loadingAttachmentsCard
        } else if !model.previews.isEmpty {
            attachmentsCard
        }
    }

    private var loadingAttachmentsCard: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(LifeTrackShareTheme.accent)
                .frame(width: 34, height: 34)
                .background(LifeTrackShareTheme.accentSoft.opacity(0.55), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("Preparing share")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(LifeTrackShareTheme.primaryText)
                Text("Reading the shared items…")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(LifeTrackShareTheme.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LifeTrackShareTheme.cardElevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(LifeTrackShareTheme.hairline.opacity(0.8), lineWidth: 0.7)
        }
    }

    private var attachmentsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: "Attachments",
                trailing: "\(model.previews.count)"
            )

            VStack(spacing: 8) {
                ForEach(model.previews) { preview in
                    attachmentRow(for: preview)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LifeTrackShareTheme.cardElevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(LifeTrackShareTheme.hairline.opacity(0.8), lineWidth: 0.7)
        }
    }

    private func attachmentRow(for preview: SharedAttachmentPreview) -> some View {
        HStack(spacing: 12) {
            Image(systemName: preview.symbolName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(LifeTrackShareTheme.accent)
                .frame(width: 34, height: 34)
                .background(LifeTrackShareTheme.accentSoft, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(preview.displayName)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(LifeTrackShareTheme.primaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(preview.typeDetail)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(LifeTrackShareTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(LifeTrackShareTheme.inputSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Note", trailing: nil)

            ZStack(alignment: .topLeading) {
                if model.note.isEmpty {
                    Text("Add context, a title, or instructions (optional)")
                        .font(.system(.subheadline))
                        .foregroundStyle(LifeTrackShareTheme.placeholderText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $model.note)
                    .focused($noteFocused)
                    .scrollContentBackground(.hidden)
                    .font(.system(.subheadline))
                    .foregroundStyle(LifeTrackShareTheme.primaryText)
                    .frame(minHeight: 120, alignment: .topLeading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
            }
            .background(LifeTrackShareTheme.inputSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(LifeTrackShareTheme.hairline.opacity(0.8), lineWidth: 0.7)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LifeTrackShareTheme.cardElevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(LifeTrackShareTheme.hairline.opacity(0.8), lineWidth: 0.7)
        }
    }

    private func sectionHeader(title: String, trailing: String?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(.subheadline, weight: .bold))
                .foregroundStyle(LifeTrackShareTheme.primaryText)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(LifeTrackShareTheme.secondaryText)
                    .monospacedDigit()
            }
        }
    }
}
