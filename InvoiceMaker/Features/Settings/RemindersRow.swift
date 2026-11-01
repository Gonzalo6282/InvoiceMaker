import SwiftData
import SwiftUI
import UIKit

/// Settings > Reminders: payment reminders on this phone (off by default).
/// Notification permission is asked only when the user turns this on.
struct RemindersRow: View {
    let business: Business
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @AppStorage(Reminders.enabledKey) private var remindersOn = false
    @State private var denied = false

    @State private var next: (date: Date, title: String)?
    @State private var testSent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            toggle
            if remindersOn { status }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .task(id: remindersOn) {
            // Rescheduling runs in the background; give it a moment, then read what iOS has queued.
            try? await Task.sleep(for: .seconds(1))
            next = await Reminders.nextPaymentReminder()
        }
        .alert("Notifications are off for Duly", isPresented: $denied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
            }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("Turn them on in iPhone Settings > Notifications > Duly, then try again.")
        }
    }

    private var toggle: some View {
        Toggle(isOn: Binding(get: { remindersOn }, set: { change($0) })) {
            HStack(spacing: 12) {
                IconChip(systemName: "bell.fill", tint: .warn)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Payment reminders").font(.callout).foregroundStyle(Color.ink)
                    Text("3 days before and on the due date of each unpaid invoice")
                        .font(.footnote).foregroundStyle(Color.ink2)
                }
            }
        }
        .accessibilityIdentifier("paymentReminders")
    }

    /// When the next reminder fires, and a way to see one now.
    private var status: some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                if let next {
                    Text("Next reminder: \(next.title) · \(next.date.formatted(date: .abbreviated, time: .shortened))")
                } else {
                    Text("No reminders scheduled yet. They're set for sent, unpaid invoices that have a due date.")
                }
            }
            .font(.footnote).foregroundStyle(Color.ink2)
            .accessibilityIdentifier("nextReminder")
            Button(testSent ? "Test reminder sent. It arrives in about 5 seconds." : "Send a test reminder") {
                Task {
                    await Reminders.sendTest(
                        title: String(localized: "Test reminder from Duly"),
                        body: String(localized: "Payment reminders look like this. They arrive at 9:00."))
                    testSent = true
                }
            }
            .font(.footnote.weight(.semibold))
            .disabled(testSent)
            .accessibilityIdentifier("testReminder")
        }
        .padding(.leading, 44)
    }

    private func change(_ on: Bool) {
        remindersOn = on
        AppAnalytics.shared.log(.remindersChanged, ["on": on ? "true" : "false"])
        guard on else { return Reminders.reschedule(context: context, business: business) }
        Task {
            if await Reminders.requestPermission() {
                Reminders.reschedule(context: context, business: business)
            } else {
                remindersOn = false
                denied = true
            }
        }
    }
}
