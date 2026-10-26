import AuthenticationServices
import SwiftUI

/// Sign in with Apple (optional) and Delete account, in Settings.
struct AccountRows: View {
    let account: AccountService
    @State private var confirmingDelete = false
    @State private var deleting = false
    @State private var error: String?
    @State private var restoring = false
    @State private var restoreMessage: String?

    var body: some View {
        Group {
            if !account.isAvailable {
                Row(icon: "apple.logo", iconTint: .neutral, title: "Sign in with Apple",
                    meta: String(localized: "Available once the app is fully set up"))
            } else if account.isSignedIn {
                Row(icon: "apple.logo", iconTint: .neutral, title: "Signed in with Apple", meta: account.email)
                RowDivider()
                Button { confirmingDelete = true } label: { Row(title: "Delete account", titleColor: .due) }.buttonStyle(.plain)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sign in to link your account across devices. Optional.").font(.footnote).foregroundStyle(Color.ink2)
                    SignInWithAppleButton(.signIn) { account.prepare($0) } onCompletion: { result in
                        Task {
                            do { try await account.complete(result) } catch { self.error = AccountService.report(error, step: "Sign in") }
                        }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 44)
                }
                .padding(14)
            }
            RowDivider()
            // Always visible: Apple expects a Restore button wherever purchases are tied to an account.
            Button(action: restore) {
                Row(icon: "arrow.clockwise", iconTint: .brand, title: "Restore purchases",
                    value: restoring ? String(localized: "Checking…") : nil)
            }
            .buttonStyle(.plain)
            .disabled(restoring)
            .accessibilityIdentifier("restorePurchases")
        }
        .alert("Restore purchases", isPresented: Binding(get: { restoreMessage != nil }, set: { if !$0 { restoreMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(restoreMessage ?? "")
        }
        .sheet(isPresented: $confirmingDelete) {
            DeleteAccountSheet(account: account) { error = $0 }
        }
        .alert("Something went wrong", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(error ?? "")
        }
    }
}

extension AccountRows {
    fileprivate func restore() {
        restoring = true
        Task {
            let premium = await PurchaseManager.shared.restore()
            restoring = false
            restoreMessage = premium
                ? String(localized: "Premium is active on this device.")
                : String(localized: "No active subscription found for this Apple ID.")
        }
    }
}

/// Apple requires a fresh sign-in to revoke the token when deleting.
private struct DeleteAccountSheet: View {
    let account: AccountService
    let failed: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Delete your account?").textStyle(.total).foregroundStyle(Color.ink)
            Text("This deletes your sign-in and unlinks your subscription from it. Your invoices stay on this device and in your iCloud; delete the app to remove them. To stop paying, cancel the subscription in Settings > [your name] > Subscriptions.")
                .font(.subheadline).foregroundStyle(Color.ink2)
            Text("Confirm with Apple to finish:").font(.subheadline.weight(.semibold))
            SignInWithAppleButton(.continue) { account.prepare($0) } onCompletion: { result in
                Task {
                    do {
                        try await account.deleteAccount(with: result)
                    } catch {
                        if let message = AccountService.report(error, step: "Delete account") { failed(message) }
                    }
                    dismiss()
                }
            }
            .frame(height: 48)
            Button("Cancel") { dismiss() }.frame(maxWidth: .infinity)
        }
        .padding(24)
        .presentationDetents([.medium])
    }
}
