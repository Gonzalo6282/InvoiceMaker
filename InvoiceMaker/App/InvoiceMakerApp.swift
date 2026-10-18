import SwiftData
import SwiftUI

@main
struct InvoiceMakerApp: App {
    private let container = ModelContainerFactory.forApp()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
