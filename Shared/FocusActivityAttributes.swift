//
//  FocusActivityAttributes.swift
//  Shared between LifeTrack and LifeTrackControlWidgetExtension so the
//  ActivityKit Live Activity uses the same registered type on both sides.
//

import ActivityKit
import Foundation

struct LifeTrackControlWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var dueDate: Date
        var isCompleted: Bool
        var isOverdue: Bool
        var noteSummary: String?
    }

    var taskID: String
    var title: String
    var categoryTitle: String
    var categorySymbol: String
    var accentColorHex: UInt
}
