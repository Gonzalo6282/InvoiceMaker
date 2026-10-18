import SwiftUI

/// The in-app paywall used when Superwall isn't available (same copy as the
/// mockup). Always shows price, trial end date, Restore, Terms and Privacy.
struct NativePaywallView: View {
    let placement: PaywallPlacement
    let onUnlock: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var purchases = PurchaseManager.shared
    @State private var selectedID: String?
    @State private var busy = false
    @State private var message: String?

    private var selected: PurchaseManager.Plan? {
        purchases.plans.first { $0.id == selectedID } ?? purchases.plans.first
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    plansList.padding(.horizontal, 22).padding(.top, 18)
                    if let message {
                        Banner(tone: .error, systemImage: "xmark.circle.fill", text: Text(message)).padding(.horizontal, 6)
                    }
                }
            }
            footer
        }
        .background(Color.canvas)
        .task {
            if purchases.plans.isEmpty { await purchases.loadPlans() }
            selectedID = selectedID ?? purchases.plans.first { $0.isYearly }?.id
        }
        .presentationDetents([.large])
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).foregroundStyle(.white.opacity(0.8))
                        .frame(width: 32, height: 32).background(.white.opacity(0.12), in: Circle())
                }
                .accessibilityLabel("Close")
            }
            Text(placement.headline).textStyle(.paywallHeadline).foregroundStyle(.white)
            Text("**Free:** create, edit and preview as many invoices as you like. **Premium:** send, print and save PDFs.")
                .font(.system(size: 15)).foregroundStyle(.white.opacity(0.8))
            VStack(alignment: .leading, spacing: 10) {
                ForEach(benefits, id: \.self) { text in
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark").font(.system(size: 11, weight: .heavy)).foregroundStyle(Color.paidInk)
                            .frame(width: 20, height: 20).background(Color.paid, in: Circle())
                        Text(text).font(.system(size: 15)).foregroundStyle(.white)
                    }
                }
            }
        }
        .padding(22)
        .background(Color.navy)
    }

    private var benefits: [String] {
        [
            String(localized: "Send by email, Messages or WhatsApp"), String(localized: "No \"Preview\" mark on your PDFs"),
            String(localized: "All 7 templates with your logo"), String(localized: "Payment buttons and QR code on invoices"),
        ]
    }

    @ViewBuilder private var plansList: some View {
        if purchases.plans.isEmpty {
            ProgressView().frame(maxWidth: .infinity).padding(30)
        } else {
            VStack(spacing: 10) {
                ForEach(purchases.plans) { plan in
                    Button { selectedID = plan.id } label: { planRow(plan) }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(plan.id == selected?.id ? .isSelected : [])
                }
            }
        }
    }

    private func planRow(_ plan: PurchaseManager.Plan) -> some View {
        let on = plan.id == selected?.id
        return HStack(spacing: 12) {
            Image(systemName: on ? "largecircle.fill.circle" : "circle").font(.system(size: 22)).foregroundStyle(on ? Color.brand : Color.ink3)
            VStack(alignment: .leading, spacing: 2) {
                Text(plan.isYearly ? "Yearly" : "Monthly").font(.system(size: 17, weight: .bold)).foregroundStyle(Color.ink)
                Text(detail(plan)).font(.system(size: 13)).foregroundStyle(Color.ink2)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text(plan.monthlyPrice ?? plan.price).font(.system(size: 17, weight: .heavy)).monospacedDigit().foregroundStyle(Color.ink)
                Text("a month").font(.system(size: 12)).foregroundStyle(Color.ink2)
            }
        }
        .padding(16)
        .background(Color.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(on ? Color.brand : Color.line, lineWidth: on ? 2 : 1))
    }

    private func detail(_ plan: PurchaseManager.Plan) -> String {
        if plan.isYearly {
            if let days = plan.trialDays { return String(localized: "\(days) days free, then \(plan.price) a year") }
            return String(localized: "\(plan.price) a year")
        }
        return String(localized: "Billed monthly, cancel any time")
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button(action: buy) {
                if busy { ProgressView().tint(.white) } else { Text(buttonTitle) }
            }
            .buttonStyle(.primary)
            .disabled(busy || selected == nil)
            .accessibilityIdentifier("paywallBuy")
            Text(terms).font(.system(size: 11.5)).foregroundStyle(Color.ink2).multilineTextAlignment(.center)
            HStack(spacing: 22) {
                Button("Restore", action: restore)
                Button("Terms") { openURL(AppLinks.terms) }
                Button("Privacy") { openURL(AppLinks.privacy) }
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.brand)
        }
        .padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 10)
        .background(.bar)
    }

    private var buttonTitle: String {
        if let plan = selected, plan.isYearly, let days = plan.trialDays { return String(localized: "Start \(days)-day free trial") }
        return String(localized: "Continue")
    }

    private var terms: String {
        let renew = String(localized: "Renews automatically unless cancelled at least 24 hours before the end of the period. Manage or cancel in Settings > [your name] > Subscriptions.")
        guard let plan = selected else { return renew }
        if plan.isYearly, let days = plan.trialDays,
            let end = Calendar.current.date(byAdding: .day, value: days, to: .now)
        {
            let endText = end.formatted(.dateTime.day().month(.wide))
            return String(localized: "Free until \(endText), then \(plan.price) a year. ") + renew
        }
        return (plan.isYearly ? String(localized: "\(plan.price) a year. ") : String(localized: "\(plan.price) a month. ")) + renew
    }

    private func buy() {
        guard let plan = selected else { return }
        busy = true
        message = nil
        Task {
            let outcome = await purchases.purchase(plan)
            busy = false
            switch outcome {
            case .purchased:
                dismiss()
                onUnlock()
            case .pending:
                message = String(localized: "Your purchase is waiting for approval. Premium unlocks as soon as it's approved.")
            case .cancelled:
                break
            case .failed:
                message = String(localized: "The payment didn't go through and you weren't charged. Check your payment method in the App Store and try again.")
            }
        }
    }

    private func restore() {
        busy = true
        Task {
            let restored = await purchases.restore()
            busy = false
            if restored {
                dismiss()
                onUnlock()
            } else {
                message = String(localized: "No active subscription found for this Apple ID.")
            }
        }
    }
}
