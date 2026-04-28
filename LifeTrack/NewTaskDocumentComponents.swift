//
//  NewTaskDocumentComponents.swift
//  LifeTrack
//
//  Document-intelligence UI extracted from NewTaskView. Each type takes its
//  inputs as parameters and owns no shared state with the parent.
//

import SwiftUI
import VisionKit

struct DocumentIntelligenceView: View {
    let summary: String?
    let suggestedTitle: String?
    let suggestedDueDate: Date?
    let keywords: [String]
    let extractedText: String
    let hasApplied: Bool
    let onApplySuggestion: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.small) {
            HStack(alignment: .top, spacing: LifeTrackTheme.Spacing.medium) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                    .frame(width: LifeTrackTheme.IconSize.largeCircle, height: LifeTrackTheme.IconSize.largeCircle)
                    .background(LifeTrackTheme.ColorPalette.accentSoft, in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text("Document Assistant")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                    Text(summary ?? "Searchable document text is saved locally.")
                        .font(.footnote)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let suggestedTitle {
                DocumentSuggestionRow(
                    symbolName: "sparkles",
                    title: suggestedTitle,
                    subtitle: suggestedDueDate.map { "Suggested due date: \($0.weekdayDateString)" } ?? "Suggested from the uploaded file."
                )

                if hasApplied {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.callout.weight(.semibold))
                        Text("Suggestion applied to task")
                            .font(.callout.weight(.semibold))
                    }
                    .foregroundStyle(LifeTrackTheme.ColorPalette.success)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LifeTrackTheme.ColorPalette.success.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    LifeTrackPrimaryButton(
                        title: "Apply Document Suggestion",
                        systemImage: "wand.and.stars",
                        action: onApplySuggestion
                    )
                }
            }

            if !keywords.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 7) {
                        ForEach(keywords.prefix(6), id: \.self) { keyword in
                            Text(keyword.capitalized)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(LifeTrackTheme.ColorPalette.accentSoft, in: Capsule())
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            if !extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(extractedText)
                    .font(.caption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .lineLimit(3)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.86), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
            }
        }
        .padding(12)
        .background(LifeTrackTheme.ColorPalette.accentSoft.opacity(0.48), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.accent.opacity(0.18), lineWidth: 0.8)
        }
    }
}

private struct DocumentSuggestionRow: View {
    let symbolName: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: LifeTrackTheme.Spacing.small) {
            Image(systemName: symbolName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.warning)
                .frame(width: 30, height: 30)
                .background(LifeTrackTheme.ColorPalette.warning.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    .lineLimit(2)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(LifeTrackTheme.ColorPalette.cardElevated.opacity(0.86), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
    }
}

struct DocumentCaptureButton: View {
    let title: String
    let subtitle: String
    let symbolName: String
    let tint: Color
    let isAvailable: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: symbolName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                        .lineLimit(1)

                    Text(isAvailable ? subtitle : "Unavailable")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(11)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.82), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                    .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.82), lineWidth: 0.8)
            }
            .opacity(isAvailable ? 1 : 0.5)
        }
        .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.97, pressedOpacity: 0.93))
        .disabled(!isAvailable)
    }
}

enum DocumentScanAvailability {
    static var isSupported: Bool {
        VNDocumentCameraViewController.isSupported
    }
}
