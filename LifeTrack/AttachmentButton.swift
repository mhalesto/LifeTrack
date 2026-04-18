//
//  AttachmentButton.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import SwiftUI

struct AttachmentButton: View {
    let documentDisplayName: String?
    let onAttach: () -> Void
    let onRemove: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.medium) {
            Button(action: onAttach) {
                HStack(spacing: LifeTrackTheme.Spacing.medium) {
                    Image(systemName: documentDisplayName == nil ? "arrow.up.doc" : "doc.text")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                        .frame(width: LifeTrackTheme.IconSize.largeCircle, height: LifeTrackTheme.IconSize.largeCircle)
                        .background(LifeTrackTheme.ColorPalette.accentSoft, in: Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(documentDisplayName ?? "Attach secure document")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                            .lineLimit(1)

                        Text(documentDisplayName == nil ? "Store a file with this task." : "Tap to replace this attachment.")
                            .font(.footnote)
                            .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
                }
                .padding(12)
                .background(LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.85), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.hairline)
                }
            }
            .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.985))

            if documentDisplayName != nil, let onRemove {
                Button(role: .destructive, action: onRemove) {
                    Label("Remove attachment", systemImage: "trash")
                        .font(.footnote.weight(.semibold))
                }
                .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.98))
                .foregroundStyle(LifeTrackTheme.ColorPalette.danger)
            }
        }
    }
}
