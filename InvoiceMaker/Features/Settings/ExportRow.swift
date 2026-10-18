import SwiftUI

/// "Export everything" in Settings: PDFs in a ZIP and all data as CSV. Free.
struct ExportRow: View {
    let business: Business
    @Environment(\.modelContext) private var context
    @State private var exporting = false
    @State private var file: SharedFile?
    @State private var failed = false

    var body: some View {
        Button(action: export) {
            Row(icon: "square.and.arrow.down.fill", title: "Export everything",
                meta: String(localized: "PDFs in a ZIP and all data as CSV. Free.")) {
                if exporting { ProgressView() }
            }
        }
        .buttonStyle(.plain)
        .disabled(exporting)
        .sheet(item: $file) { file in
            ShareSheet(items: [file.url]).ignoresSafeArea()
        }
        .alert("Export didn't work", isPresented: $failed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please try again. If it keeps happening, report a problem in Help.")
        }
    }

    private func export() {
        exporting = true
        Task { @MainActor in
            defer { exporting = false }
            do {
                file = SharedFile(url: try DataExporter(context: context, business: business).makeZip())
            } catch {
                failed = true
            }
        }
    }
}
