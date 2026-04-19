//
//  SubscriptionTier.swift
//  LifeTrack
//

import SwiftUI

// MARK: - Tier

enum SubscriptionTier: Int, Comparable, Codable {
    case free     = 0
    case standard = 1
    case ultimate = 2

    static func < (lhs: SubscriptionTier, rhs: SubscriptionTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .free:     "Free"
        case .standard: "Standard"
        case .ultimate: "Ultimate"
        }
    }

    var badgeGradient: LinearGradient {
        switch self {
        case .free:
            return LinearGradient(colors: [.gray.opacity(0.6), .gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
        case .standard:
            return LinearGradient(colors: [Color(red: 0.45, green: 0.35, blue: 0.95), Color(red: 0.3, green: 0.55, blue: 0.98)], startPoint: .leading, endPoint: .trailing)
        case .ultimate:
            return LinearGradient(colors: [Color(red: 0.95, green: 0.72, blue: 0.1), Color(red: 0.98, green: 0.5, blue: 0.15)], startPoint: .leading, endPoint: .trailing)
        }
    }

    var accentColor: Color {
        switch self {
        case .free:     .gray
        case .standard: Color(red: 0.45, green: 0.35, blue: 0.95)
        case .ultimate: Color(red: 0.95, green: 0.72, blue: 0.1)
        }
    }

    var monthlyPriceLabel: String {
        switch self {
        case .free:     "Free"
        case .standard: "$3 / month"
        case .ultimate: "$8 / month"
        }
    }

    var yearlyPriceLabel: String {
        switch self {
        case .free:     "Free"
        case .standard: "$25 / year"
        case .ultimate: "$60 / year"
        }
    }

    var yearlyMonthlyCost: String {
        switch self {
        case .free:     ""
        case .standard: "$2.08/mo"
        case .ultimate: "$5/mo"
        }
    }

    var yearlyDiscount: String {
        switch self {
        case .free:     ""
        case .standard: "Save 31%"
        case .ultimate: "Save 38%"
        }
    }

    var tagline: String {
        switch self {
        case .free:     "Core task management"
        case .standard: "Your productivity OS"
        case .ultimate: "AI-powered productivity"
        }
    }

    var features: [TierFeature] {
        switch self {
        case .free:
            return [
                TierFeature("Task creation & categories", "checkmark.circle.fill", .green),
                TierFeature("Due dates & notes", "checkmark.circle.fill", .green),
                TierFeature("Document attachments", "checkmark.circle.fill", .green),
                TierFeature("Statistics & insights", "checkmark.circle.fill", .green),
                TierFeature("Basic notifications", "checkmark.circle.fill", .green),
                TierFeature("Control Widgets", "checkmark.circle.fill", .green)
            ]
        case .standard:
            return [
                TierFeature("Everything in Free", "checkmark.circle.fill", .green),
                TierFeature("Daily Planning Ritual", "sunrise.fill", Color(red: 0.95, green: 0.55, blue: 0.1)),
                TierFeature("Habit Tracking & Streaks", "flame.fill", Color(red: 0.95, green: 0.3, blue: 0.2)),
                TierFeature("Weekly Review Mode", "chart.bar.doc.horizontal.fill", Color(red: 0.35, green: 0.6, blue: 0.95)),
                TierFeature("Location Reminders", "location.fill", Color(red: 0.3, green: 0.7, blue: 0.95)),
                TierFeature("HealthKit Energy Scheduling", "heart.fill", Color(red: 0.9, green: 0.25, blue: 0.45)),
                TierFeature("Custom Themes", "paintpalette.fill", Color(red: 0.45, green: 0.35, blue: 0.95))
            ]
        case .ultimate:
            return [
                TierFeature("Everything in Standard", "checkmark.circle.fill", .green),
                TierFeature("AI Task Suggestions", "sparkles", Color(red: 0.95, green: 0.72, blue: 0.1)),
                TierFeature("Smart Scheduling Optimizer", "brain.head.profile", Color(red: 0.95, green: 0.72, blue: 0.1)),
                TierFeature("iCloud Backup & Export", "icloud.fill", Color(red: 0.95, green: 0.72, blue: 0.1)),
                TierFeature("Priority Support", "person.crop.circle.badge.checkmark", Color(red: 0.95, green: 0.72, blue: 0.1))
            ]
        }
    }
}

// MARK: - Feature Item

struct TierFeature: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color

    init(_ title: String, _ icon: String, _ color: Color) {
        self.title = title
        self.icon = icon
        self.color = color
    }
}
