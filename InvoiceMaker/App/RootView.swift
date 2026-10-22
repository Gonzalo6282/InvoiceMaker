import InvoiceKit
import SwiftData
import SwiftUI

/// Decides onboarding vs. the app once at launch, then shows the shell.
struct RootView: View {
    @Query(sort: \Business.createdAt) private var businesses: [Business]
    @Query private var documents: [Document]
    @Environment(\.modelContext) private var context
    @State private var paywalls = PaywallService.shared
    @State private var consent = ConsentPrompt.shared
    @State private var phase: Phase?
    @State private var firstDocument: PersistentIdentifier?
    @State private var checkingICloud = false

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
                if let business = BusinessSetup.primary(businesses) {
                    AppShell(business: business, initialDocument: firstDocument)
                } else {
                    loading
                }
            case nil:
                loading
            }
        }
        .onChange(of: hasSyncedData) { _, synced in
            // iCloud data arrived while onboarding was showing and the user
            // hadn't created anything yet: go straight to their invoices.
            if synced, phase == .onboarding, !OnboardingState.createdData { phase = .app }
        }
        .sheet(item: $paywalls.nativePaywall) { request in
            NativePaywallView(placement: request.placement, onUnlock: request.onUnlock)
                .onDisappear { request.onClose() }
        }
        .alert(AnalyticsConsentText.title, isPresented: $consent.isShowing) {
            Button(AnalyticsConsentText.allow) { AppAnalytics.shared.setConsent(true) }
            Button(AnalyticsConsentText.deny, role: .cancel) { AppAnalytics.shared.setConsent(false) }
        } message: {
            Text(AnalyticsConsentText.message)
        }
        .task {
            await decidePhase()
            guard !arguments.contains("-uiTesting") else { return }
            // New users are asked after onboarding and its paywall (see
            // OnboardingView.complete); everyone else when the app opens.
            if phase == .app { consent.askIfNeeded() }
        }
        .task(id: businesses.isEmpty) {
            #if DEBUG
                // App Store screenshots: the demo business with sample documents.
                if businesses.isEmpty, arguments.contains("-demoData") {
                    let code = arguments.firstIndex(of: "-demoRegion").flatMap { i in arguments.indices.contains(i + 1) ? arguments[i + 1] : nil }
                    DemoData.seed(context, screenshots: true, region: code.flatMap { Region(countryCode: $0) } ?? .uk)
                    return
                }
            #endif
            // UI tests that skip onboarding start with a business for the device's region.
            guard businesses.isEmpty, skipOnboarding else { return }
            let code = Locale.current.region?.identifier ?? "GB"
            BusinessSetup.create(name: "", region: Region.resolve(countryCode: code), countryCode: code, in: context)
        }
    }

    private var loading: some View {
        VStack(spacing: 14) {
            ProgressView()
            if checkingICloud {
                Text("Looking for your invoices in iCloud…").font(.subheadline).foregroundStyle(Color.ink2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.canvas)
    }

    /// New users onboard; a business that synced from iCloud (named, or with
    /// documents) goes straight in. After a reinstall the local store starts
    /// empty, so when iCloud is on we first wait (briefly) for its data.
    private func decidePhase() async {
        guard phase == nil else { return }
        if skipOnboarding { phase = .app; return }
        let uiTesting = arguments.contains("-uiTesting")
        let watcher = CloudImportWatcher.shared
        if !uiTesting, !OnboardingState.isDone, !hasSyncedData, watcher.iCloudAvailable {
            // Real iCloud can take 10–20 s on a fresh install; if data turns up
            // later, the onChange above still leaves onboarding.
            checkingICloud = true
            await watcher.wait(timeout: .seconds(20)) { hasSyncedData }
            checkingICloud = false
        }
        let done = OnboardingState.isDone && !uiTesting
        phase = (done || hasSyncedData) ? .app : .onboarding
        if phase == .app, businesses.isEmpty, done {
            phase = .onboarding  // flag set but no data at all: start again
        }
    }

    /// A named business or any document means this isn't a new user.
    private var hasSyncedData: Bool {
        businesses.contains { !$0.name.isEmpty } || !documents.isEmpty
    }
}

#if DEBUG
    #Preview {
        RootView().modelContainer(DemoData.container())
    }
#endif
