//
//  HealthKitEnergyReader.swift
//  LifeTrack
//

import Combine
import Foundation
import HealthKit
import SwiftUI

// MARK: - Energy Level

enum EnergyLevel: String {
    case high, moderate, low, unknown

    var label: String {
        switch self {
        case .high:     return "High Energy"
        case .moderate: return "Moderate Energy"
        case .low:      return "Low Energy"
        case .unknown:  return "Energy Unknown"
        }
    }

    var sfSymbol: String {
        switch self {
        case .high:     return "bolt.fill"
        case .moderate: return "bolt.badge.clock.fill"
        case .low:      return "battery.25percent"
        case .unknown:  return "questionmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .high:     return Color(red: 0.18, green: 0.72, blue: 0.38)
        case .moderate: return Color(red: 0.9,  green: 0.55, blue: 0.1)
        case .low:      return Color(red: 0.85, green: 0.25, blue: 0.25)
        case .unknown:  return LifeTrackTheme.ColorPalette.secondaryText
        }
    }

    var plannerNote: String {
        switch self {
        case .high:
            return "You're well-rested — tackling bigger items first."
        case .moderate:
            return "Balanced energy day — a mix of quick wins and focused work."
        case .low:
            return "Low sleep or HRV detected. Shorter tasks surfaced first to build momentum."
        case .unknown:
            return "Connect Apple Health to get energy-aware suggestions."
        }
    }

    // Score delta applied per task in DailyFocusPlanner
    // Positive = boost for short tasks, negative = penalty for long tasks when low
    func scoreDelta(for durationMinutes: Int) -> Int {
        guard self == .low, durationMinutes > 0 else { return 0 }
        if durationMinutes <= 30 { return 25 }
        if durationMinutes >= 60 { return -15 }
        return 0
    }
}

// MARK: - Reader

@MainActor
final class HealthKitEnergyReader: ObservableObject {
    static let shared = HealthKitEnergyReader()

    @Published var energyLevel: EnergyLevel = .unknown
    @Published var sleepHours: Double = 0
    @Published var hrv: Double = 0
    @Published var isAuthorized = false

    private let store = HKHealthStore()

    private var readTypes: Set<HKObjectType> {
        [
            HKCategoryType(.sleepAnalysis),
            HKQuantityType(.heartRateVariabilitySDNN)
        ]
    }

    private init() {}

    func requestAuthorizationAndRefresh() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            isAuthorized = true
            await refresh()
        } catch {}
    }

    func refresh() async {
        async let s = fetchSleepHours()
        async let h = fetchLatestHRV()
        let (sleep, hrv) = await (s, h)
        self.sleepHours = sleep
        self.hrv = hrv
        self.energyLevel = computeLevel(sleepHours: sleep, hrv: hrv)
    }

    // MARK: - HealthKit Queries

    private func fetchSleepHours() async -> Double {
        let type = HKCategoryType(.sleepAnalysis)
        let now = Date()
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: now)
        guard let startOfYesterday = cal.date(byAdding: .day, value: -1, to: startOfToday) else { return 0 }

        let predicate = HKQuery.predicateForSamples(withStart: startOfYesterday, end: now)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: 0)
                    return
                }
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                ]
                let totalSeconds = samples
                    .filter { asleepValues.contains($0.value) }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                continuation.resume(returning: totalSeconds / 3600)
            }
            store.execute(query)
        }
    }

    private func fetchLatestHRV() async -> Double {
        let type = HKQuantityType(.heartRateVariabilitySDNN)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: 0)
                    return
                }
                let ms = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                continuation.resume(returning: ms)
            }
            store.execute(query)
        }
    }

    // MARK: - Scoring

    private func computeLevel(sleepHours: Double, hrv: Double) -> EnergyLevel {
        guard sleepHours > 0 || hrv > 0 else { return .unknown }

        var score = 0

        // Sleep: 0–2 pts
        if sleepHours >= 7 {
            score += 2
        } else if sleepHours >= 6 {
            score += 1
        } else if sleepHours < 5 && sleepHours > 0 {
            score -= 1
        }

        // HRV: 0–2 pts (only if we have data)
        if hrv > 0 {
            if hrv >= 50 {
                score += 2
            } else if hrv >= 30 {
                score += 1
            } else if hrv < 20 {
                score -= 1
            }
        }

        switch score {
        case 3...: return .high
        case 1...2: return .moderate
        default:   return .low
        }
    }
}
