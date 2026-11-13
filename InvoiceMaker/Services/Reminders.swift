import Foundation
import InvoiceKit
import SwiftData
import UIKit
import UserNotifications

/// Local notifications on the user's own phone (v1.1):
/// - payment reminders (Settings switch, off by default): 3 days before and
///   on the due date of each sent, unpaid invoice;
/// - "ready to send" when a recurring invoice's next copy is due.
/// Permission is asked only when the user turns one of these on.
/// Everything is rebuilt from the data whenever the app opens or closes, so
/// a paid, deleted or edited invoice never leaves a stale reminder. Rebuilding
/// replaces reminders in place and removes only stale ones, so there is never
/// a moment with nothing scheduled (iOS can suspend the app mid-way when it
/// goes to the background).
@MainActor
enum Reminders {
    static let enabledKey = "paymentRemindersOn"
    /// Our notifications only (Superwall schedules its own trial reminder).
    nonisolated static let idPrefix = "duly."
    /// The Settings test reminder: outside `idPrefix`, so rescheduling never removes it.
    nonisolated static let testID = "duly-test"
    /// iOS keeps 64 pending notifications per app; leave room for Superwall's.
    static let limit = 50
    static let hour = 9

    static var isOn: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    nonisolated struct Planned: Equatable, Sendable {
        let id: String
        let date: Date
        let title: String
        let body: String
    }

    /// What should be scheduled, soonest first.
    static func plan(
        documents: [Document], business: Business, taxes: [TaxRate], paymentReminders: Bool, now: Date = .now,
        calendar: Calendar = .current
    ) -> [Planned] {
        func nine(_ day: Date) -> Date {
            calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
        }
        var planned: [Planned] = []
        for doc in documents where doc.kind == .invoice {
            let client = doc.client?.name ?? ""
            if paymentReminders, doc.status == .sent, let due = doc.dueDate {
                let amount = business.money(doc.totals(taxes: taxes).total, currency: doc.currencyCode)
                let body = client.isEmpty ? amount : "\(client) · \(amount)"
                let dueDay = nine(due)
                if let before = calendar.date(byAdding: .day, value: -3, to: dueDay) {
                    planned.append(Planned(
                        id: "\(idPrefix)due-before.\(doc.number)", date: before,
                        title: String(localized: "\(doc.number) is due in 3 days"), body: body))
                }
                planned.append(Planned(
                    id: "\(idPrefix)due-today.\(doc.number)", date: dueDay,
                    title: String(localized: "\(doc.number) is due today"), body: body))
            }
            if let recurrence = doc.recurrence, let next = doc.nextRecurrence {
                let body = client.isEmpty
                    ? String(localized: "Open Duly to check it and send it.")
                    : String(localized: "For \(client). Open Duly to check it and send it.")
                planned.append(Planned(
                    id: "\(idPrefix)recurring.\(doc.number)", date: nine(next),
                    title: readyTitle(recurrence), body: body))
            }
        }
        return Array(planned.filter { $0.date > now }.sorted { $0.date < $1.date }.prefix(limit))
    }

    /// Whole sentences, so each language can word them its own way.
    static func readyTitle(_ recurrence: Recurrence) -> String {
        switch recurrence {
        case .weekly: String(localized: "Your weekly invoice is ready")
        case .monthly: String(localized: "Your monthly invoice is ready")
        case .yearly: String(localized: "Your yearly invoice is ready")
        }
    }

    /// The previous rebuild; each one waits for it, so two never interleave.
    private static var lastRebuild: Task<Void, Never>?

    /// Brings our pending notifications in line with the current plan.
    static func reschedule(context: ModelContext, business: Business) {
        let documents = (try? context.fetch(FetchDescriptor<Document>())) ?? []
        let taxes = (try? BusinessSetup.taxes(in: context, includingArchived: true)) ?? []
        let planned = plan(documents: documents, business: business, taxes: taxes, paymentReminders: isOn)
        // Closing the app: ask iOS for time to finish before it suspends us.
        let time = BackgroundTime(name: "Duly reminders")
        let previous = lastRebuild
        lastRebuild = Task {
            await previous?.value
            await apply(planned)
            time.end()
        }
    }

    /// Notifications can show (allowed, or quietly allowed).
    nonisolated static func canNotify() async -> Bool {
        switch await UNUserNotificationCenter.current().notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: true
        default: false
        }
    }

    /// Pending reminders that are no longer in the plan (paid, deleted, edited, switched off).
    nonisolated static func staleIDs(pending: [String], planned: [Planned]) -> [String] {
        let wanted = Set(planned.map(\.id))
        return pending.filter { $0.hasPrefix(idPrefix) && !wanted.contains($0) }
    }

    /// Off the main actor's data: only plain values come in. Adds (or replaces,
    /// same identifier) everything planned first, then removes what's stale.
    nonisolated private static func apply(_ planned: [Planned]) async {
        let center = UNUserNotificationCenter.current()
        let allowed = await canNotify()
        let pending = await center.pendingNotificationRequests().map(\.identifier)
        if allowed {
            for item in planned {
                let content = UNMutableNotificationContent()
                content.title = item.title
                content.body = item.body
                content.sound = .default
                let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: item.date)
                let request = UNNotificationRequest(
                    identifier: item.id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
                try? await center.add(request)
            }
        }
        let stale = staleIDs(pending: pending, planned: allowed ? planned : [])
        if !stale.isEmpty { center.removePendingNotificationRequests(withIdentifiers: stale) }
    }

    /// The soonest payment reminder iOS has queued (Settings shows it, so the
    /// user can see reminders are set up without waiting for 9:00).
    nonisolated static func nextPaymentReminder() async -> (date: Date, title: String)? {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return pending
            .filter { $0.identifier.hasPrefix("\(idPrefix)due-") }
            .compactMap { request -> (date: Date, title: String)? in
                guard let trigger = request.trigger as? UNCalendarNotificationTrigger, let date = trigger.nextTriggerDate() else { return nil }
                return (date, request.content.title)
            }
            .min { $0.date < $1.date }
    }

    /// Settings > Reminders > "Send a test reminder": arrives in 5 seconds, with
    /// the app open (see NotificationPresenter) or closed. False if notifications are off.
    nonisolated static func sendTest(title: String, body: String) async -> Bool {
        guard await requestPermission() else { return false }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: testID, content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false))
        try? await UNUserNotificationCenter.current().add(request)
        return true
    }

    /// Asks iOS for permission (once; later calls return the saved answer).
    nonisolated static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        case .denied: return false
        default: return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        }
    }
}

/// A little time from iOS to finish work after the app goes to the background.
final class BackgroundTime {
    private var id = UIBackgroundTaskIdentifier.invalid

    init(name: String) {
        id = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in self?.end() }
    }

    func end() {
        guard id != .invalid else { return }
        UIApplication.shared.endBackgroundTask(id)
        id = .invalid
    }
}

/// Without a delegate iOS stays silent when a notification fires while Duly
/// is open (a 9:00 reminder with the app on screen was simply dropped).
nonisolated final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate, Sendable {
    static let shared = NotificationPresenter()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
