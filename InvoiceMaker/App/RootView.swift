import InvoiceKit
import SwiftData
import SwiftUI

/// Waits for the business to exist, then shows the app shell.
struct RootView: View {
    @Query(sort: \Business.createdAt) private var businesses: [Business]
    @Environment(\.modelContext) private var context

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
