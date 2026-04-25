//
//  MoneyReminderScheduler.swift
//  LifeTrack
//
//  Local notifications for money flows: bills due tomorrow and
//  monthly over-budget alerts. Designed to be idempotent — safe
//  to call repeatedly (e.g. on every scene-active).
//

import Foundation
import UserNotifications

enum MoneyReminderScheduler {
    private static let billPrefix = "lifetrack.money.bill."
    private static let overBudgetPrefix = "lifetrack.money.overbudget."
    private static let categoryIdentifier = "LIFETRACK_MONEY_REMINDER"

    /// Re-schedule reminders. Cancels any existing money notifications first
    /// so the system reflects the current data exactly.
    static func synchronize(
        bills: [MoneyBillSnapshot],
        monthlyActualSpending: Double,
        monthlyAdjustedPlannedSpending: Double,
        currencyCode: String,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        Task {
            let center = UNUserNotificationCenter.current()
            await cancelExisting(in: center)

            guard await ReminderScheduler.requestAuthorizationIfNeeded() else { return }

            scheduleBillReminders(
                bills: bills,
                currencyCode: currencyCode,
                now: now,
                calendar: calendar,
                center: center
            )

            scheduleOverBudgetReminder(
                actual: monthlyActualSpending,
                planned: monthlyAdjustedPlannedSpending,
                currencyCode: currencyCode,
                now: now,
                center: center
            )
        }
    }

    private static func cancelExisting(in center: UNUserNotificationCenter) async {
        let pending = await center.pendingNotificationRequests()
        let toCancel = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(billPrefix) || $0.hasPrefix(overBudgetPrefix) }
        if !toCancel.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: toCancel)
        }
    }

    private static func scheduleBillReminders(
        bills: [MoneyBillSnapshot],
        currencyCode: String,
        now: Date,
        calendar: Calendar,
        center: UNUserNotificationCenter
    ) {
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
            ?? now.addingTimeInterval(86_400)
        // Fire at 09:00 local on the day before the bill is due.
        for bill in bills where bill.status != .paid {
            guard let triggerDate = calendar.date(
                bySettingHour: 9, minute: 0, second: 0,
                of: calendar.date(byAdding: .day, value: -1, to: bill.dueDate) ?? bill.dueDate
            ) else { continue }
            guard triggerDate > now, triggerDate < startOfTomorrow.addingTimeInterval(60 * 60 * 24 * 7) else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Bill due tomorrow"
            content.body = "\(bill.title) — \(MoneyFormatting.currency(bill.plannedAmount, code: currencyCode))"
            content.sound = .default
            content.categoryIdentifier = categoryIdentifier

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: billPrefix + bill.id.uuidString,
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    private static let overBudgetLastFiredKey = "LifeTrack.money.overBudgetLastFiredDay"

    private static func scheduleOverBudgetReminder(
        actual: Double,
        planned: Double,
        currencyCode: String,
        now: Date,
        center: UNUserNotificationCenter
    ) {
        guard planned > 0, actual > planned else { return }

        // Fire at most once per calendar day.
        let dayKey = ISO8601DateFormatter.dayOnly.string(from: now)
        let defaults = UserDefaults.standard
        if defaults.string(forKey: overBudgetLastFiredKey) == dayKey { return }
        defaults.set(dayKey, forKey: overBudgetLastFiredKey)

        let overBy = actual - planned
        let content = UNMutableNotificationContent()
        content.title = "Over budget"
        content.body = "You're \(MoneyFormatting.currency(overBy, code: currencyCode)) over plan this month."
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let identifier = overBudgetPrefix + dayKey
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }
}

private extension ISO8601DateFormatter {
    static let dayOnly: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()
}
