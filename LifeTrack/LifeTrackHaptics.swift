//
//  LifeTrackHaptics.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import UIKit

enum LifeTrackHaptics {
    static func lightImpact() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
}
