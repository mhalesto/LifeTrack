//
//  AvatarCropView.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import SwiftUI
import UIKit

struct AvatarCropView: View {
    let image: UIImage
    let onCancel: () -> Void
    let onSave: (UIImage) -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let cropSize: CGFloat = 292

    var body: some View {
        NavigationStack {
            ZStack {
                LifeTrackTheme.appBackground
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.xLarge) {
                    header

                    VStack(spacing: LifeTrackTheme.Spacing.large) {
                        cropper
                        guidance
                    }
                    .frame(maxWidth: .infinity)

                    Spacer(minLength: 0)

                    LifeTrackPrimaryButton(title: "Use Photo", systemImage: "checkmark", action: saveCrop)
                }
                .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
                .padding(.top, LifeTrackTheme.Spacing.large)
                .padding(.bottom, LifeTrackTheme.Spacing.xLarge)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .fontWeight(.semibold)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Reset", action: resetCrop)
                        .fontWeight(.semibold)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Position Photo")
                .font(.lifeTrackTitle)
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

            Text("Drag to center your face. Pinch to zoom before saving.")
                .font(.footnote)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var cropper: some View {
        ZStack {
            Circle()
                .fill(LifeTrackTheme.ColorPalette.cardElevated)
                .frame(width: cropSize, height: cropSize)
                .shadow(color: LifeTrackTheme.ColorPalette.shadow, radius: 18, x: 0, y: 12)

            Image(uiImage: image.normalizedForAvatar())
                .resizable()
                .scaledToFill()
                .frame(width: cropSize, height: cropSize)
                .scaleEffect(scale)
                .offset(offset)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.92), lineWidth: 3)
                }
                .overlay {
                    Circle()
                        .stroke(LifeTrackTheme.ColorPalette.accent.opacity(0.22), lineWidth: 12)
                }
                .contentShape(Circle())
                .gesture(dragGesture.simultaneously(with: magnificationGesture))
        }
        .frame(width: cropSize, height: cropSize)
    }

    private var guidance: some View {
        HStack(spacing: LifeTrackTheme.Spacing.medium) {
            CropTip(symbolName: "hand.draw", title: "Drag", subtitle: "Reposition")
            CropTip(symbolName: "plus.magnifyingglass", title: "Pinch", subtitle: "Zoom")
            CropTip(symbolName: "arrow.counterclockwise", title: "Reset", subtitle: "Start over")
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                offset = clampedOffset(
                    CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    ),
                    scale: scale
                )
            }
            .onEnded { _ in
                offset = clampedOffset(offset, scale: scale)
                lastOffset = offset
            }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(lastScale * value, 1), 4)
                offset = clampedOffset(offset, scale: scale)
            }
            .onEnded { _ in
                scale = min(max(scale, 1), 4)
                offset = clampedOffset(offset, scale: scale)
                lastScale = scale
                lastOffset = offset
            }
    }

    private func saveCrop() {
        let croppedImage = image.croppedAvatarImage(
            cropSize: cropSize,
            scale: scale,
            offset: offset,
            outputSize: 640
        )
        onSave(croppedImage)
    }

    private func resetCrop() {
        withAnimation(.smooth(duration: 0.2)) {
            scale = 1
            lastScale = 1
            offset = .zero
            lastOffset = .zero
        }
    }

    private func clampedOffset(_ proposedOffset: CGSize, scale: CGFloat) -> CGSize {
        let normalizedImage = image.normalizedForAvatar()
        let imageSize = normalizedImage.size
        let baseScale = max(cropSize / imageSize.width, cropSize / imageSize.height)
        let displayedWidth = imageSize.width * baseScale * scale
        let displayedHeight = imageSize.height * baseScale * scale
        let maxX = max((displayedWidth - cropSize) / 2, 0)
        let maxY = max((displayedHeight - cropSize) / 2, 0)

        return CGSize(
            width: min(max(proposedOffset.width, -maxX), maxX),
            height: min(max(proposedOffset.height, -maxY), maxY)
        )
    }
}

private struct CropTip: View {
    let symbolName: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: symbolName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.accent)

            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

            Text(subtitle)
                .font(.caption2.weight(.medium))
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(LifeTrackTheme.ColorPalette.cardElevated, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.85), lineWidth: 0.7)
        }
    }
}

private extension UIImage {
    func normalizedForAvatar() -> UIImage {
        guard imageOrientation != .up else {
            return self
        }

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func croppedAvatarImage(cropSize: CGFloat, scale: CGFloat, offset: CGSize, outputSize: CGFloat) -> UIImage {
        let normalizedImage = normalizedForAvatar()
        let imageSize = normalizedImage.size
        let baseScale = max(cropSize / imageSize.width, cropSize / imageSize.height)
        let effectiveScale = baseScale * scale
        let displayedWidth = imageSize.width * effectiveScale
        let displayedHeight = imageSize.height * effectiveScale
        let imageOrigin = CGPoint(
            x: (cropSize - displayedWidth) / 2 + offset.width,
            y: (cropSize - displayedHeight) / 2 + offset.height
        )

        let cropRect = CGRect(
            x: max((0 - imageOrigin.x) / effectiveScale, 0),
            y: max((0 - imageOrigin.y) / effectiveScale, 0),
            width: min(cropSize / effectiveScale, imageSize.width),
            height: min(cropSize / effectiveScale, imageSize.height)
        )

        let output = CGSize(width: outputSize, height: outputSize)
        let drawScale = outputSize / cropRect.width
        let renderer = UIGraphicsImageRenderer(size: output)

        return renderer.image { _ in
            normalizedImage.draw(
                in: CGRect(
                    x: -cropRect.minX * drawScale,
                    y: -cropRect.minY * drawScale,
                    width: imageSize.width * drawScale,
                    height: imageSize.height * drawScale
                )
            )
        }
    }
}

#Preview {
    AvatarCropView(
        image: UIImage(systemName: "person.crop.circle.fill") ?? UIImage(),
        onCancel: {},
        onSave: { _ in }
    )
}
