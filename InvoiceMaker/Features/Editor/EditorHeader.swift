import InvoiceKit
import SwiftUI

struct EditorHeader: View {
    let document: Document

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Label("Saved", systemImage: "checkmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.ink3)
                Text(document.number.isEmpty ? " " : document.number)
                    .textStyle(.docNumber)
                    .foregroundStyle(Color.ink)
            }
            Spacer()
            StatusPill(status: document.displayStatus()).padding(.bottom, 6)
        }
        .padding(.horizontal, 16)
        .padding(.top, 2)
    }
}

/// Status banners (mockup editorBody): paid → send receipt, sent, accepted → invoice, converted.
struct EditorBanners: View {
    let document: Document
    let business: Business
    let actions: DocumentActions
    let open: (Document) -> Void

    var body: some View {
        let status = document.displayStatus()
        let clientName = document.client.map { $0.contactName.isEmpty ? $0.name : $0.contactName } ?? String(localized: "your client")
        if document.kind == .invoice, status == .paid {
            Banner(
                tone: .ok, systemImage: "checkmark.circle.fill",
                text: Text("**Paid on \(business.mediumDate(document.paidOn ?? .now)).** Send a receipt so your client has proof."),
                actionTitle: String(localized: "Make receipt"), action: { open(actions.makeReceipt(for: document, business: business)) })
        } else if document.status == .sent, let sentAt = document.sentAt {
            Banner(
                tone: .info, systemImage: "paperplane.fill",
                text: Text("**Sent on \(business.mediumDate(sentAt)).** Changes save automatically. Send again so \(clientName) has the latest version."))
        }
        if document.kind == .estimate, document.status == .accepted {
            Banner(
                tone: .ok, systemImage: "signature",
                text: Text("**Accepted.** Signed by \(document.signedName.isEmpty ? clientName : document.signedName)."),
                actionTitle: String(localized: "Turn into invoice"), action: { open(actions.convertToInvoice(document, business: business)) })
        }
        if document.kind == .invoice, document.clientSignatureData != nil {
            Banner(
                tone: .ok, systemImage: "signature",
                text: Text("**Signed by \(document.signedName.isEmpty ? clientName : document.signedName).** The signature is on the PDF."))
        }
        if document.kind == .estimate, document.status == .converted {
            Banner(
                tone: .info, systemImage: "arrow.triangle.2.circlepath",
                text: Text("This was turned into invoice \(document.convertedToNumber ?? "").")
            )
        }
    }
}
