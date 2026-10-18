import InvoiceKit
import SwiftUI

/// Placeholder until T4.3 builds the full editor.
struct DocumentEditorView: View {
    let document: Document
    let business: Business

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(document.number).textStyle(.docNumber).foregroundStyle(Color.ink)
            StatusPill(status: document.displayStatus())
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.canvas)
        .navigationTitle(business.title(for: document.kind))
        .navigationBarTitleDisplayMode(.inline)
    }
}
