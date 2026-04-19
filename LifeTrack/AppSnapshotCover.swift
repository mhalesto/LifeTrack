//
//  AppSnapshotCover.swift
//  LifeTrack
//

import SwiftUI
import UIKit

enum AppSnapshotCover {
    private static let coverTag = 987_654

    static func show() {
        guard let window = keyWindow() else { return }

        if let existing = window.viewWithTag(coverTag) {
            existing.alpha = 1
            window.bringSubviewToFront(existing)
            return
        }

        let hosting = UIHostingController(rootView: SplashScreenView(playsIntroAnimation: false))
        hosting.view.tag = coverTag
        hosting.view.frame = window.bounds
        hosting.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hosting.view.backgroundColor = UIColor(LifeTrackTheme.ColorPalette.backgroundTop)

        window.addSubview(hosting.view)
        window.layoutIfNeeded()

        objc_setAssociatedObject(hosting.view as UIView, &hostingKey, hosting, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    static func hide(animated: Bool = true) {
        guard let window = keyWindow(), let cover = window.viewWithTag(coverTag) else { return }

        guard animated else {
            cover.removeFromSuperview()
            return
        }

        UIView.animate(withDuration: 0.18,
                       animations: { cover.alpha = 0 },
                       completion: { _ in cover.removeFromSuperview() })
    }

    private static var hostingKey: UInt8 = 0

    private static func keyWindow() -> UIWindow? {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }

        return windows.first(where: { $0.isKeyWindow }) ?? windows.first
    }
}
