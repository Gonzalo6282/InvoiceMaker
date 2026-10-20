import SwiftData
import SwiftUI

@main
struct InvoiceMakerApp: App {
    private let store: Result<ModelContainer, Error>

    init() {
        CloudImportWatcher.shared.start()
        store = ModelContainerFactory.forApp()
        // Order matters: Firebase, then RevenueCat, then Superwall (uses RevenueCat).
        AppAnalytics.shared.configure()
        PurchaseManager.shared.configure()
        PaywallService.shared.configure()
        AccountService.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            switch store {
            case .success(let container):
                RootView().modelContainer(container)
            case .failure(let error):
                StoreErrorView(error: error)
            }
        }
    }
}

/// Shown only if no data store can be opened at all, instead of crashing.
struct StoreErrorView: View {
    let error: Error

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(Color.warn)
            Text("Duly couldn't open its data").textStyle(.total).multilineTextAlignment(.center)
            Text("Please restart the app. If this keeps happening, contact support from the App Store page.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.ink2)
            Text(String(describing: error))
                .font(.footnote.monospaced())
                .foregroundStyle(Color.ink3)
                .accessibilityIdentifier("storeError")
        }
        .padding(24)
    }
}
