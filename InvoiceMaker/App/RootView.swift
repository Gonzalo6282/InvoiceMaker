import InvoiceKit
import SwiftData
import SwiftUI

/// Waits for the business to exist, then shows the app shell.
struct RootView: View {
    @Query(sort: \Business.createdAt) private var businesses: [Business]
    @Environment(\.modelContext) private var context
    @State private var paywalls = PaywallService.shared
    @State private var askConsent = false

    var body: some View {
        Group {
            if let business = businesses.first {
                AppShell(business: business)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.canvas)
            }
        }
        .sheet(item: $paywalls.nativePaywall) { request in
            NativePaywallView(placement: request.placement, onUnlock: request.onUnlock)
        }
        .fullScreenCover(isPresented: $askConsent) {
            ConsentView { granted in
                AppAnalytics.shared.setConsent(granted)
                askConsent = false
            }
        }
        .task {
            guard !ProcessInfo.processInfo.arguments.contains("-uiTesting") else { return }
            if await AppAnalytics.needsConsentPrompt() {
                askConsent = true
            } else {
                await AppAnalytics.shared.enableByDefaultIfNotAsked()
            }
        }
        .task(id: businesses.isEmpty) {
            // Until onboarding (M8) exists: start a business for the device's region.
            guard businesses.isEmpty else { return }
            let code = Locale.current.region?.identifier ?? "GB"
            BusinessSetup.create(name: "", region: Region.resolve(countryCode: code), countryCode: code, in: context)
        }
    }
}

#if DEBUG
    #Preview {
        RootView().modelContainer(DemoData.container())
    }
#endif
