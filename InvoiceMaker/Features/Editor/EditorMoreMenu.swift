import InvoiceKit
import SwiftUI

/// The "…" menu in the editor (mockup docMore): duplicate, mark paid, receipt,
/// convert, client signs, delete.
struct EditorMoreMenu: View {
    let document: Document
    let business: Business
    let actions: DocumentActions
    let open: (Document) -> Void
    let close: () -> Void
    let print: () -> Void
    let savePDF: () -> Void

    @State private var showingSignature = false
    @State private var confirmingDelete = false

    var body: some View {
        Menu {
            Button("Print", systemImage: "printer", action: print).keyboardShortcut("p", modifiers: .command)
            Button("Save PDF to Files", systemImage: "folder", action: savePDF)
            Divider()
            Button("Duplicate", systemImage: "plus.square.on.square") {
                open(actions.duplicate(document, business: business))
            }
            if document.kind == .invoice {
                if document.status == .paid {
                    Button("Mark as unpaid", systemImage: "arrow.uturn.backward.circle") { actions.markUnpaid(document) }
                    Button("Make receipt", systemImage: "doc.badge.plus") {
                        open(actions.makeReceipt(for: document, business: business))
                    }
                } else {
                    Button("Mark as paid", systemImage: "checkmark.circle") { actions.markPaid(document); ReviewPrompt.ask(after: .markedPaid) }
                }
            }
            if document.kind == .estimate, document.status != .converted {
                Button("Turn into invoice", systemImage: "arrow.triangle.2.circlepath") {
                    open(actions.convertToInvoice(document, business: business))
                }
            }
            if document.kind != .receipt {
                Button("Client signs on this device", systemImage: "signature") { showingSignature = true }
            }
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive) { confirmingDelete = true }
        } label: {
            Label("More actions", systemImage: "ellipsis.circle")
        }
        .accessibilityIdentifier("docMore")
        .sheet(isPresented: $showingSignature) {
            SignatureSheet(purpose: .client(documentTitle: business.title(for: document.kind))) { png, name in
                actions.recordClientSignature(document, image: png, name: name)
            }
        }
        .confirmationDialog(
            "Delete \(document.number)?", isPresented: $confirmingDelete, titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                close()
                actions.delete(document)
            }
        } message: {
            Text("This can't be undone.")
        }
    }
}
