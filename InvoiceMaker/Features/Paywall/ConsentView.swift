import SwiftUI

/// UK/EEA users are asked before any analytics (mockup onboarding "consent").
struct ConsentView: View {
    let answer: (Bool) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(alignment: .leading, spacing: 16) {
                IconChip(systemName: "chart.bar.fill", size: 64)
                Text("Allow anonymous analytics?").textStyle(.largeTitle).foregroundStyle(Color.ink)
                Text("We count things like \"invoice created\" to see what's slow or confusing. No names, no invoice contents, no tracking across other apps. You can change this any time in Settings.")
                    .font(.body).foregroundStyle(Color.ink2)
            }
            .padding(.horizontal, 24)
            Spacer()
            VStack(spacing: 10) {
                Button("Allow") { answer(true) }.buttonStyle(.primary)
                Button("Don't allow") { answer(false) }.buttonStyle(.ghost)
            }
            .padding(24)
        }
        .background(Color.canvas)
        .interactiveDismissDisabled()
    }
}
