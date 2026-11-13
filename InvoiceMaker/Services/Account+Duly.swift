// SliceAccount (SliceLibrary) does Sign in with Apple and Delete account;
// Duly supplies its name and its own "what deleting does" wording.
@_exported import SliceAccount
import SwiftUI

enum DulyAccount {
    /// After Firebase has started (DulyAnalytics.configure).
    static func start() {
        AccountService.shared.start(AccountConfig(appName: "Duly", logPrefix: "[Duly account]"))
    }

    /// Settings > Account: Sign in with Apple, or Signed in + Delete account.
    static var rows: some View {
        AccountRows(deleteExplanation: "This deletes your sign-in and unlinks your subscription from it. Your invoices stay on this device and in your iCloud; delete the app to remove them. To stop paying, cancel the subscription in Settings > [your name] > Subscriptions.")
    }
}
