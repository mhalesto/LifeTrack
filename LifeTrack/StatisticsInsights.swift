//
//  StatisticsInsights.swift
//  LifeTrack
//

import Foundation

enum StatisticsInsights {
    static func completionInsight(bestPoint: ProductivityStatPoint?) -> String {
        guard let bestPoint, bestPoint.completedCount > 0 else {
            return "No completed tasks in this range yet."
        }
        return "\(bestPoint.label) had the strongest completion count with \(bestPoint.completedCount) finished."
    }

    static func overdueInsight(points: [ProductivityStatPoint], totalOverdue: Int) -> String {
        if totalOverdue == 0 {
            return "No overdue tasks in this range. The schedule is holding steady."
        }
        guard let peak = points.max(by: { $0.overdueCount < $1.overdueCount }) else {
            return "Overdue tasks will appear here as trends develop."
        }
        return "The highest overdue count was \(peak.overdueCount) around \(peak.label)."
    }
}
