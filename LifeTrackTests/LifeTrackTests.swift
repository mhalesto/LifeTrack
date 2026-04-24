//
//  LifeTrackTests.swift
//  LifeTrackTests
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import Foundation
import Testing
@testable import LifeTrack

struct LifeTrackTests {

    @Test func emailTemplateCreatesEmailActionTaskDefaults() {
        let template = TaskTemplate.common.first { $0.id == "email" }

        #expect(template?.title == "Send follow-up email")
        #expect(template?.category == .work)
        #expect(template?.action == .email)
        #expect(template?.notes.contains("Subject: Follow up") == true)
    }

    @Test func completedTaskIsNeverOverdue() {
        let task = LifeTask(
            title: "Past task",
            category: .finance,
            dueDate: Date(timeIntervalSinceNow: -3600),
            isCompleted: true
        )

        #expect(task.isOverdue == false)
    }

    @Test func voiceParserDetectsAppointmentTomorrow() {
        let referenceDate = Date(timeIntervalSince1970: 1_766_016_000)
        let draft = VoiceTaskParser.parse(
            "Remind me to book a dentist appointment tomorrow",
            referenceDate: referenceDate
        )

        #expect(draft.title == "Book a dentist appointment")
        #expect(draft.notes == nil)
        #expect(draft.category == .health)
        #expect(draft.dueDate != nil)
    }

    @Test func voiceParserDetectsFinanceCategory() {
        let draft = VoiceTaskParser.parse("Review insurance payment in two days")

        #expect(draft.category == .finance)
        #expect(draft.title == "Review insurance payment")
    }

    @Test func voiceParserHandlesHourOffsetInTheNextHour() throws {
        let reference = Date(timeIntervalSince1970: 1_766_016_000)
        let draft = VoiceTaskParser.parse(
            "Remind me to check power cables in the next hour",
            referenceDate: reference
        )

        #expect(draft.title == "Check power cables")
        let due = try #require(draft.dueDate)
        let delta = due.timeIntervalSince(reference)
        #expect(abs(delta - 3600) < 2)
    }

    @Test func voiceParserHandlesAnHourFromNow() throws {
        let reference = Date(timeIntervalSince1970: 1_766_016_000)
        let draft = VoiceTaskParser.parse(
            "Check power cables an hour from now",
            referenceDate: reference
        )

        #expect(draft.title == "Check power cables")
        let due = try #require(draft.dueDate)
        #expect(abs(due.timeIntervalSince(reference) - 3600) < 2)
    }

    @Test func voiceParserHandlesAboutAnHour() throws {
        let reference = Date(timeIntervalSince1970: 1_766_016_000)
        let draft = VoiceTaskParser.parse(
            "Check the power cables about an hour",
            referenceDate: reference
        )

        let due = try #require(draft.dueDate)
        #expect(abs(due.timeIntervalSince(reference) - 3600) < 2)
        #expect(draft.title == "Check the power cables")
    }

    @Test func voiceParserHandlesSpecificMinuteOffset() throws {
        let reference = Date(timeIntervalSince1970: 1_766_016_000)
        let draft = VoiceTaskParser.parse(
            "Remind me to start the oven in 30 minutes",
            referenceDate: reference
        )

        #expect(draft.title == "Start the oven")
        let due = try #require(draft.dueDate)
        #expect(abs(due.timeIntervalSince(reference) - 1800) < 2)
    }

    @Test func voiceParserHandlesHalfAnHour() throws {
        let reference = Date(timeIntervalSince1970: 1_766_016_000)
        let draft = VoiceTaskParser.parse(
            "Remind me to check the oven in half an hour",
            referenceDate: reference
        )

        #expect(draft.title == "Check the oven")
        let due = try #require(draft.dueDate)
        #expect(abs(due.timeIntervalSince(reference) - 1800) < 2)
    }

    @Test func voiceParserHandlesTwoHours() throws {
        let reference = Date(timeIntervalSince1970: 1_766_016_000)
        let draft = VoiceTaskParser.parse(
            "Remind me to call the client in 2 hours",
            referenceDate: reference
        )

        #expect(draft.title == "Call the client")
        let due = try #require(draft.dueDate)
        #expect(abs(due.timeIntervalSince(reference) - 7200) < 2)
    }

    @Test func voiceParserSplitsNotesOnBecauseClause() {
        let draft = VoiceTaskParser.parse(
            "Remind me to check the power cables in an hour because they've been overheating"
        )

        #expect(draft.title == "Check the power cables")
        #expect(draft.notes == "They've been overheating")
    }

    @Test func voiceParserSplitsNotesOnSentenceBoundary() {
        let draft = VoiceTaskParser.parse(
            "Send the quarterly insurance update tomorrow. Include the Q2 numbers and last year's spreadsheet."
        )

        #expect(draft.title == "Send the quarterly insurance update")
        #expect(draft.notes == "Include the Q2 numbers and last year's spreadsheet.")
        #expect(draft.category == .finance)
    }

    @Test func voiceParserKeepsTitleWhenNoAdditionalContext() {
        let draft = VoiceTaskParser.parse("Buy groceries")

        #expect(draft.title == "Buy groceries")
        #expect(draft.notes == nil)
    }

    // MARK: - CompletedArchivePeriod

    @Test func archivePeriodOffNeverArchives() {
        let deepPast = Date(timeIntervalSinceNow: -365 * 24 * 60 * 60 * 10)
        #expect(CompletedArchivePeriod.off.shouldArchive(completedAt: deepPast) == false)
    }

    @Test func archivePeriodArchivesWhenOlderThanLimit() {
        let reference = Date()
        let olderThanNinetyDays = reference.addingTimeInterval(-91 * 24 * 60 * 60)
        #expect(CompletedArchivePeriod.ninetyDays.shouldArchive(
            completedAt: olderThanNinetyDays,
            referenceDate: reference
        ) == true)
    }

    @Test func archivePeriodDoesNotArchiveRecentlyCompleted() {
        let reference = Date()
        let twoDaysAgo = reference.addingTimeInterval(-2 * 24 * 60 * 60)
        #expect(CompletedArchivePeriod.thirtyDays.shouldArchive(
            completedAt: twoDaysAgo,
            referenceDate: reference
        ) == false)
    }

    // MARK: - TaskBinRetentionPeriod

    @Test func binRetentionExpiresAfterDuration() {
        let reference = Date()
        let deletedEightDaysAgo = reference.addingTimeInterval(-8 * 24 * 60 * 60)
        #expect(TaskBinRetentionPeriod.sevenDays.isExpired(
            deletedAt: deletedEightDaysAgo,
            referenceDate: reference
        ) == true)
    }

    @Test func binRetentionImmediateIsAlwaysExpired() {
        let now = Date()
        #expect(TaskBinRetentionPeriod.immediately.isExpired(
            deletedAt: now,
            referenceDate: now
        ) == true)
    }

    // MARK: - DailyFocusPlanner

    @MainActor
    @Test func focusPlannerPrioritizesOverdueOverUpcoming() {
        let now = Date()
        let overdue = LifeTask(
            title: "Overdue",
            category: .work,
            dueDate: now.addingTimeInterval(-86_400)
        )
        let upcoming = LifeTask(
            title: "Upcoming",
            category: .work,
            dueDate: now.addingTimeInterval(86_400 * 5)
        )

        let recs = DailyFocusPlanner.recommendations(from: [upcoming, overdue])
        #expect(recs.first?.task.title == "Overdue")
        #expect(recs.first?.reason == .overdue)
    }

    @MainActor
    @Test func focusPlannerReturnsAtLeastThreeWhenAvailable() {
        let now = Date()
        let tasks = (0..<6).map { index in
            LifeTask(
                title: "Task \(index)",
                category: .work,
                dueDate: now.addingTimeInterval(TimeInterval(index * 3600))
            )
        }

        let recs = DailyFocusPlanner.recommendations(from: tasks)
        #expect(recs.count >= 3 && recs.count <= 5)
    }

    @MainActor
    @Test func focusPlannerShouldOfferResetWhenManyOverdue() {
        let now = Date()
        let overdueTasks = (0..<4).map { index in
            LifeTask(
                title: "Overdue \(index)",
                category: .work,
                dueDate: now.addingTimeInterval(-TimeInterval((index + 1) * 3600))
            )
        }
        #expect(DailyFocusPlanner.shouldOfferReset(for: overdueTasks) == true)
    }

    @MainActor
    @Test func focusPlannerDoesNotOfferResetForLightLoad() {
        let now = Date()
        let light = [
            LifeTask(title: "One", category: .work, dueDate: now.addingTimeInterval(3600)),
            LifeTask(title: "Two", category: .work, dueDate: now.addingTimeInterval(7200))
        ]
        #expect(DailyFocusPlanner.shouldOfferReset(for: light) == false)
    }

    @MainActor
    @Test func focusPlannerResetScheduleAssignsSlotsToFocusTasks() {
        let now = Date(timeIntervalSince1970: 1_766_016_000)
        let a = LifeTask(title: "A", category: .work, dueDate: now.addingTimeInterval(-3600))
        let b = LifeTask(title: "B", category: .work, dueDate: now.addingTimeInterval(-1800))
        let c = LifeTask(title: "C", category: .work, dueDate: now.addingTimeInterval(3600))

        let plan = DailyFocusPlanner.resetSchedule(
            for: [a, b, c],
            focusIDs: [a.id, b.id],
            referenceDate: now
        )

        let focusTitles = plan.compactMap { ($0.0.id == a.id || $0.0.id == b.id) ? $0.0.title : nil }
        #expect(focusTitles.contains("A"))
        #expect(focusTitles.contains("B"))
    }

    // MARK: - StatisticsInsights

    @Test func completionInsightHandlesNilBestPoint() {
        #expect(StatisticsInsights.completionInsight(bestPoint: nil)
            == "No completed tasks in this range yet.")
    }

    @Test func completionInsightHandlesZeroCompletions() {
        let point = ProductivityStatPoint(
            date: Date(),
            endDate: Date(),
            label: "Mon",
            completedCount: 0,
            overdueCount: 0
        )
        #expect(StatisticsInsights.completionInsight(bestPoint: point)
            == "No completed tasks in this range yet.")
    }

    @Test func completionInsightDescribesBestPoint() {
        let point = ProductivityStatPoint(
            date: Date(),
            endDate: Date(),
            label: "Mon",
            completedCount: 7,
            overdueCount: 1
        )
        #expect(StatisticsInsights.completionInsight(bestPoint: point)
            == "Mon had the strongest completion count with 7 finished.")
    }

    @Test func overdueInsightWhenZeroTotal() {
        #expect(StatisticsInsights.overdueInsight(points: [], totalOverdue: 0)
            == "No overdue tasks in this range. The schedule is holding steady.")
    }

    @Test func overdueInsightWithNoPointsButPositiveTotal() {
        #expect(StatisticsInsights.overdueInsight(points: [], totalOverdue: 3)
            == "Overdue tasks will appear here as trends develop.")
    }

    @Test func overdueInsightReportsPeak() {
        let low = ProductivityStatPoint(
            date: Date(),
            endDate: Date(),
            label: "Tue",
            completedCount: 0,
            overdueCount: 1
        )
        let high = ProductivityStatPoint(
            date: Date(),
            endDate: Date(),
            label: "Fri",
            completedCount: 0,
            overdueCount: 4
        )
        #expect(StatisticsInsights.overdueInsight(points: [low, high], totalOverdue: 5)
            == "The highest overdue count was 4 around Fri.")
    }

    // MARK: - Bank statement import

    private static let sbsaSample = """
    3 month statement
    From: 07 Aug 25
    To: 05 Nov 25
    Account number: 13 502 415 3
    Account holder: MR. HALALISANI MBANJWA
    Product name: ACHIEVAACC
    STANDARD BANK
    ANTON LEMBEDE S
    05 Nov 2025
    Transaction details Available Balance: R10.00
    Date Description Payments Deposits Balance
    STATEMENT OPENING BALANCE -119.97
    25 Aug 25 EXCESS INTEREST
    EXCESS INTEREST
    -1.97 -121.94
    29 Aug 25 HALA
    IB TRANSFER FROM
    300.00 178.06
    30 Aug 25 FIXED MONTHLY FEE
    FIXED MONTHLY FEE
    -115.00 63.06
    01 Sep 25 DNH*GODADD AMSTERDAM NLD 30-08-2025
    16H30:14
    FEE- POS DECLINED INSUFF FUNDS
    -8.50 54.56
    01 Sep 25 UCOUNT
    MEMBERSHIP FEE
    -25.00 29.56
    08 Oct 25 MTN PREPAID 0837853774 E
    PRE-PAID PAYMENT TO
    -10.00 29.24
    03 Nov 25 *****2411156 11H32 *****4145
    IB TRANSFER FROM
    150.00 30.00
    """

    @Test func sbsaParserDetectsStandardBankFormat() {
        #expect(StandardBankSAStatementParser.canParse(Self.sbsaSample))
        #expect(!StandardBankSAStatementParser.canParse("Capitec Bank statement"))
    }

    @Test func sbsaParserExtractsHeaderFields() throws {
        let statement = try StandardBankSAStatementParser.parse(Self.sbsaSample)
        #expect(statement.bankName == "Standard Bank of South Africa")
        #expect(statement.accountNumber == "13 502 415 3")
        #expect(statement.accountHolder == "MR. HALALISANI MBANJWA")
        #expect(statement.currencyCode == "ZAR")
        #expect(statement.openingBalance == -119.97)
    }

    @Test func sbsaParserExtractsTransactionCount() throws {
        let statement = try StandardBankSAStatementParser.parse(Self.sbsaSample)
        #expect(statement.transactions.count == 7)
    }

    @Test func sbsaParserDistinguishesPaymentsAndDeposits() throws {
        let statement = try StandardBankSAStatementParser.parse(Self.sbsaSample)
        let deposits = statement.transactions.filter { $0.amount > 0 }
        let payments = statement.transactions.filter { $0.amount < 0 }
        #expect(deposits.count == 2)
        #expect(payments.count == 5)
        #expect(deposits.map(\.amount).reduce(0, +) == 450.00)
    }

    @Test func sbsaParserPreservesDetailLines() throws {
        let statement = try StandardBankSAStatementParser.parse(Self.sbsaSample)
        let godaddy = statement.transactions.first { $0.descriptionText.contains("GODADD") }
        #expect(godaddy?.detailText?.contains("POS DECLINED") == true)
        #expect(godaddy?.amount == -8.50)
    }

    @Test func sbsaParserSuggestsCategories() throws {
        let statement = try StandardBankSAStatementParser.parse(Self.sbsaSample)
        let fee = statement.transactions.first { $0.descriptionText == "FIXED MONTHLY FEE" }
        #expect(fee?.suggestedCategory == "Bank fees")

        let mtn = statement.transactions.first { $0.descriptionText.contains("MTN") }
        #expect(mtn?.suggestedCategory == "Telecoms")

        let transferIn = statement.transactions.first { $0.descriptionText == "HALA" }
        #expect(transferIn?.suggestedCategory == "Transfer in")
    }

    @Test func sbsaParserParsesTransactionDates() throws {
        let statement = try StandardBankSAStatementParser.parse(Self.sbsaSample)
        let first = try #require(statement.transactions.first)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Africa/Johannesburg") ?? .current
        let components = cal.dateComponents([.year, .month, .day], from: first.date)
        #expect(components.year == 2025)
        #expect(components.month == 8)
        #expect(components.day == 25)
    }

    @Test func duplicateKeyIsStableForSameTransaction() {
        let a = ParsedTransaction(
            date: Date(timeIntervalSince1970: 1_756_000_000),
            descriptionText: "MTN PREPAID",
            amount: -10.00,
            currencyCode: "ZAR"
        )
        let b = ParsedTransaction(
            date: Date(timeIntervalSince1970: 1_756_000_000),
            descriptionText: "mtn prepaid ",
            amount: -10.00,
            currencyCode: "ZAR"
        )
        #expect(a.duplicateKey() == b.duplicateKey())
    }

    @Test func dispatcherRoutesToStandardBankParser() throws {
        let statement = try BankStatementImporter.parse(Self.sbsaSample)
        #expect(statement.bankName == "Standard Bank of South Africa")
        #expect(!statement.transactions.isEmpty)
    }

    @Test func genericParserHandlesSingleLineCsvLikeInput() throws {
        let text = """
        2025-09-01 Coffee shop -45.50
        2025-09-02 Salary payment 15000.00
        """
        let statement = try GenericBankStatementParser.parse(text)
        #expect(statement.transactions.count == 2)
        #expect(statement.transactions.first?.amount == -45.50)
        #expect(statement.transactions.last?.amount == 15000.00)
    }

    @Test func categorizerFallsBackToNilForUnknownMerchant() {
        #expect(BankStatementCategorizer.category(for: "ZZZ UNKNOWN MERCHANT", detail: nil) == nil)
    }

}
