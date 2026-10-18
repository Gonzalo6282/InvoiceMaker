import InvoiceKit
import SwiftUI

/// Placeholder until the app shell (T4.1) replaces it.
struct RootView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Duly")
                .font(.system(size: 34, weight: .heavy))
            Text("InvoiceKit \(InvoiceKit.version)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    RootView()
}
