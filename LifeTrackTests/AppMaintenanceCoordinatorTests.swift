//
//  AppMaintenanceCoordinatorTests.swift
//  LifeTrackTests
//

import Foundation
import Testing
@testable import LifeTrack

struct AppMaintenanceCoordinatorTests {

    @Test func initialRunExecutesAllMaintenance() {
        let snapshot = AppMaintenanceSnapshot(
            dayStamp: 20260428,
            recurringTemplateDigest: 1,
            recurringTaskDigest: 2,
            billMatchingDigest: 3,
            moneyPresentationDigest: 4,
            spotlightDigest: 5
        )

        let plan = AppMaintenancePlan.make(
            previous: nil,
            current: snapshot,
            trigger: .initialLaunch
        )

        #expect(plan.runRecurringMoneyExpansion)
        #expect(plan.runRecurringTaskCatchUp)
        #expect(plan.runBillAutoMatch)
        #expect(plan.publishMoneyOutputs)
        #expect(plan.reindexSpotlight)
    }

    @Test func unchangedForegroundRunSkipsWork() {
        let snapshot = AppMaintenanceSnapshot(
            dayStamp: 20260428,
            recurringTemplateDigest: 11,
            recurringTaskDigest: 12,
            billMatchingDigest: 13,
            moneyPresentationDigest: 14,
            spotlightDigest: 15
        )

        let plan = AppMaintenancePlan.make(
            previous: snapshot,
            current: snapshot,
            trigger: .sceneBecameActive
        )

        #expect(plan.shouldRunAnyWork == false)
    }

    @Test func recurringTemplateChangeTriggersExpansionAndMoneyOutputs() {
        let previous = AppMaintenanceSnapshot(
            dayStamp: 20260428,
            recurringTemplateDigest: 1,
            recurringTaskDigest: 10,
            billMatchingDigest: 20,
            moneyPresentationDigest: 30,
            spotlightDigest: 40
        )
        let current = AppMaintenanceSnapshot(
            dayStamp: 20260428,
            recurringTemplateDigest: 2,
            recurringTaskDigest: 10,
            billMatchingDigest: 20,
            moneyPresentationDigest: 30,
            spotlightDigest: 40
        )

        let plan = AppMaintenancePlan.make(
            previous: previous,
            current: current,
            trigger: .sceneBecameActive
        )

        #expect(plan.runRecurringMoneyExpansion)
        #expect(plan.publishMoneyOutputs)
        #expect(plan.runRecurringTaskCatchUp == false)
        #expect(plan.reindexSpotlight == false)
    }

    @Test func dayChangeTriggersDailyMaintenance() {
        let previous = AppMaintenanceSnapshot(
            dayStamp: 20260428,
            recurringTemplateDigest: 1,
            recurringTaskDigest: 2,
            billMatchingDigest: 3,
            moneyPresentationDigest: 4,
            spotlightDigest: 5
        )
        let current = AppMaintenanceSnapshot(
            dayStamp: 20260429,
            recurringTemplateDigest: 1,
            recurringTaskDigest: 2,
            billMatchingDigest: 3,
            moneyPresentationDigest: 4,
            spotlightDigest: 5
        )

        let plan = AppMaintenancePlan.make(
            previous: previous,
            current: current,
            trigger: .sceneBecameActive
        )

        #expect(plan.runRecurringMoneyExpansion)
        #expect(plan.runRecurringTaskCatchUp)
        #expect(plan.publishMoneyOutputs)
        #expect(plan.reindexSpotlight)
    }
}
