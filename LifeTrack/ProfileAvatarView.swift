//
//  ProfileAvatarView.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import SwiftUI
import UIKit

struct ProfileAvatarView: View {
    let size: CGFloat
    let avatarVersion: Int
    var showsEditBadge = false

    @State private var avatarImage: UIImage?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            avatarContent
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.9), lineWidth: max(1, size * 0.035))
                }
                .shadow(color: LifeTrackTheme.ColorPalette.shadow, radius: size * 0.22, x: 0, y: size * 0.12)

            if showsEditBadge {
                Image(systemName: "camera.fill")
                    .font(.system(size: max(10, size * 0.15), weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: size * 0.32, height: size * 0.32)
                    .background(LifeTrackTheme.ColorPalette.accent, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(Color.white, lineWidth: max(1, size * 0.025))
                    }
            }
        }
        .frame(width: size, height: size)
        .task(id: avatarVersion) {
            avatarImage = AvatarImageStore.loadAvatarImage()
        }
    }

    @ViewBuilder
    private var avatarContent: some View {
        if let avatarImage {
            Image(uiImage: avatarImage)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        LifeTrackTheme.ColorPalette.accentSoft,
                        LifeTrackTheme.ColorPalette.backgroundTop
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: size * 0.58, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
            }
        }
    }
}

struct ProfileAvatarButton: View {
    let avatarVersion: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ProfileAvatarView(size: 42, avatarVersion: avatarVersion)
                .overlay(alignment: .bottomTrailing) {
                    Circle()
                        .fill(LifeTrackTheme.ColorPalette.cardElevated)
                        .frame(width: 14, height: 14)
                        .overlay {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                        }
                        .offset(x: 1, y: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open settings")
    }
}

#Preview {
    ZStack {
        LifeTrackTheme.appBackground
            .ignoresSafeArea()
        ProfileAvatarView(size: 96, avatarVersion: 0, showsEditBadge: true)
    }
}
