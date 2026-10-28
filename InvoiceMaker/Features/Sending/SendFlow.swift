import AuthenticationServices
import InvoiceKit
import SwiftData
import SwiftUI

/// Send / print / save PDF for one document: validate → Premium gate →
/// (first time) optional Sign in with Apple → share sheet. Marks the document
/// sent and logs invoice_sent / pdf_exported.
@MainActor
@Observable
final class SendFlow {
    var issues: SendValidation = []
    var sharing: SharedPDF?
    var exporting: PDFFile?
    var offeringSignIn = false
    var errorMessage: String?

    @ObservationIgnored private var pendingShare: (() -> Void)?
    static let signInOfferedKey = "signInOfferedAtFirstSend"

    func send(_ doc: Document, business: Business, taxes: [TaxRate], context: ModelContext) {
        issues = SendValidation.check(doc)
        guard issues.isEmpty else { return }
        let placement: PaywallPlacement = doc.kind == .estimate ? .estimateSend : .invoiceSend
        PaywallService.shared.gate(placement, params: ["document_type": doc.kind.rawValue]) { [weak self] in
            guard let self else { return }
            let share = { self.share(doc, business: business, taxes: taxes) }
            if AccountService.shared.isAvailable, !AccountService.shared.isSignedIn,
                !UserDefaults.standard.bool(forKey: Self.signInOfferedKey)
            {
                UserDefaults.standard.set(true, forKey: Self.signInOfferedKey)
                pendingShare = share
                offeringSignIn = true
            } else {
                share()
            }
        }
    }

    /// Called when the sign-in offer closes (signed in or skipped).
    func continueAfterSignInOffer() {
        let share = pendingShare
        pendingShare = nil
        share?()
    }

    func print(_ doc: Document, business: Business, taxes: [TaxRate]) {
        PaywallService.shared.gate(.invoiceExportPDF) { [weak self] in
            guard let pdf = self?.render(doc, business: business, taxes: taxes) else { return }
            PrintPDF.print(pdf.data, jobName: doc.number) { completed in
                if completed { AppAnalytics.shared.log(.pdfExported, ["method": "print", "document_type": doc.kind.rawValue]) }
            }
        }
    }

    func savePDF(_ doc: Document, business: Business, taxes: [TaxRate]) {
        PaywallService.shared.gate(.invoiceExportPDF) { [weak self] in
            guard let pdf = self?.render(doc, business: business, taxes: taxes) else { return }
            self?.exporting = PDFFile(data: pdf.data)
        }
    }

    /// After the share sheet closes.
    /// Returns true when the document was actually sent (not printed or saved).
    @discardableResult
    func finished(_ doc: Document, completed: Bool, activity: UIActivity.ActivityType?, context: ModelContext) -> Bool {
        sharing = nil
        guard completed else { return false }
        let fileActivities: Set<String> = [
            UIActivity.ActivityType.print.rawValue, UIActivity.ActivityType.saveToCameraRoll.rawValue,
            "com.apple.DocumentManagerUICore.SaveToFiles",
        ]
        if let activity, fileActivities.contains(activity.rawValue) {
            AppAnalytics.shared.log(.pdfExported, ["method": activity.rawValue, "document_type": doc.kind.rawValue])
            return false
        } else {
            DocumentActions(context: context).markSent(doc)
            AppAnalytics.shared.log(.invoiceSent, [
                "method": activity?.rawValue ?? "unknown", "document_type": doc.kind.rawValue,
                "made_with": MadeWithDuly.isOn() ? "on" : "off",
            ])
            return true
        }
    }

    private func share(_ doc: Document, business: Business, taxes: [TaxRate]) {
        sharing = render(doc, business: business, taxes: taxes)
    }

    private func render(_ doc: Document, business: Business, taxes: [TaxRate]) -> SharedPDF? {
        do {
            return try SharedPDF.make(document: doc, business: business, taxes: taxes)
        } catch {
            errorMessage = String(localized: "The PDF couldn't be made. Please try again.")
            return nil
        }
    }

    /// The share sheet's header line.
    func shareTitle(for pdf: SharedPDF) -> String {
        NetworkMonitor.shared.isOnline
            ? pdf.url.lastPathComponent
            : String(localized: "You're offline. Mail and WhatsApp will send this as soon as you have signal.")
    }
}

/// "Keep your subscription if you change phone": optional, shown once at first send.
struct SignInOfferSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            IconChip(systemName: "person.crop.circle.badge.checkmark", size: 56)
            Text("Keep Premium on every device").textStyle(.total).foregroundStyle(Color.ink)
            Text("Sign in with Apple so your subscription follows you to a new iPhone or iPad. Optional: your invoices stay on your device and iCloud either way.")
                .font(.subheadline).foregroundStyle(Color.ink2)
            SignInWithAppleButton(.signIn) { AccountService.shared.prepare($0) } onCompletion: { result in
                Task {
                    do {
                        try await AccountService.shared.complete(result)
                        dismiss()
                    } catch {
                        self.error = AccountService.report(error, step: "Sign in (first send)")
                    }
                }
            }
            .frame(height: 50)
            if let error { Text(error).font(.footnote).foregroundStyle(Color.due) }
            Button("Not now") { dismiss() }.frame(maxWidth: .infinity).foregroundStyle(Color.brand)
        }
        .padding(24)
        .presentationDetents([.medium])
    }
}
