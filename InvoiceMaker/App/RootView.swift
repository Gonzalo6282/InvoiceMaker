import InvoiceKit
import SwiftData
import SwiftUI

/// Decides onboarding vs. the app once at launch, then shows the shell.
struct RootView: View {
    @Query(sort: \Business.createdAt) private var businesses: [Business]
    @Query private var documents: [Document]
    @Environment(\.modelContext) private var context
    @State private var paywalls = PaywallService.shared
    @State private var askConsent = false
    @State private var phase: Phase?
    @State private var firstDocument: PersistentIdentifier?

    enum Phase { case onboarding, app }

    private var arguments: [String] { ProcessInfo.processInfo.arguments }
    private var skipOnboarding: Bool { arguments.contains("-skipOnboarding") }

    var body: some View {
        Group {
            switch phase {
            case .onboarding:
                OnboardingView { doc in
                    firstDocument = doc.persistentModelID
                    phase = .app
                }
            case .app:
                if let business = businesses.first {
                    AppShell(business: business, initialDocument: firstDocument)
                } else {
                    loading
                }
            case nil:
                loading
            }
        }
        .sheet(item: $paywalls.nativePaywall) { request in
            NativePaywallView(placement: request.placement, onUnlock: request.onUnlock)
        }
        .alert(AnalyticsConsentText.title, isPresented: $askConsent) {
            Button(AnalyticsConsentText.allow) { AppAnalytics.shared.setConsent(true) }
            Button(AnalyticsConsentText.deny, role: .cancel) { AppAnalytics.shared.setConsent(false) }
        } message: {
            Text(AnalyticsConsentText.message)
        }
        .task {
            decidePhase()
            guard !arguments.contains("-uiTesting") else { return }
            askConsent = AppAnalytics.needsConsentPrompt
        }
        .task(id: businesses.isEmpty) {
            // UI tests that skip onboarding start with a business for the device's region.
            guard businesses.isEmpty, skipOnboarding else { return }
            let code = Locale.current.region?.identifier ?? "GB"
            BusinessSetup.create(name: "", region: Region.resolve(countryCode: code), countryCode: code, in: context)
        }
    }

    private var loading: some View {
        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.canvas)
    }

    /// New users onboard; a business that synced from iCloud (named, or with
    /// documents) goes straight in.
    private func decidePhase() {
        guard phase == nil else { return }
        if skipOnboarding { phase = .app; return }
        let done = OnboardingState.isDone && !arguments.contains("-uiTesting")
        if let business = businesses.first {
            phase = (!done && business.name.isEmpty && documents.isEmpty) ? .onboarding : .app
        } else {
            phase = .onboarding
        }
    }
}

#if DEBUG
    #Preview {
        RootView().modelContainer(DemoData.container())
    }
#endif
