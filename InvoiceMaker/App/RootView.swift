import InvoiceKit
import SwiftUI

/// Placeholder until the app shell (T4.1) replaces it.
struct RootView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                Text("Duly")
                    .textStyle(.largeTitle)
                    .foregroundStyle(Color.ink)
                Text("InvoiceKit \(InvoiceKit.version)")
                    .font(.footnote)
                    .foregroundStyle(Color.ink2)
                #if DEBUG
                    NavigationLink("Design system") { DesignGalleryView() }
                        .padding(.top, 16)
                #endif
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.canvas)
        }
    }
}

#Preview {
    RootView()
}
