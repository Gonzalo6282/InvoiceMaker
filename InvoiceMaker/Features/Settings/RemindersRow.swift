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

    var body: some View {
        Toggle(isOn: Binding(get: { remindersOn }, set: change)) {
            HStack(spacing: 12) {
                IconChip(systemName: "bell.fill", tint: .warn)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Payment reminders").font(.callout).foregroundStyle(Color.ink)
                    Text("3 days before and on the due date of each unpaid invoice")
                        .font(.footnote).foregroundStyle(Color.ink2)
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .accessibilityIdentifier("paymentReminders")
        .alert("Notifications are off for Duly", isPresented: $denied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
            }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("Turn them on in iPhone Settings > Notifications > Duly, then try again.")
        }
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
