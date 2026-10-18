import PencilKit
import SwiftUI

/// A PencilKit canvas for a signature (finger or Apple Pencil). Black ink on white.
struct SignaturePad: UIViewRepresentable {
    @Binding var drawing: PKDrawing

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .anyInput
        canvas.tool = PKInkingTool(.pen, color: .black, width: 3)
        canvas.backgroundColor = .white
        canvas.overrideUserInterfaceStyle = .light  // keep ink black in dark mode
        canvas.isOpaque = true
        canvas.delegate = context.coordinator
        canvas.drawing = drawing
        canvas.accessibilityLabel = String(localized: "Signature area. Draw your signature.")
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        if canvas.drawing != drawing { canvas.drawing = drawing }
    }

    func makeCoordinator() -> Coordinator { Coordinator(drawing: $drawing) }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let drawing: Binding<PKDrawing>
        init(drawing: Binding<PKDrawing>) { self.drawing = drawing }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            drawing.wrappedValue = canvasView.drawing
        }
    }
}

extension PKDrawing {
    /// A transparent PNG of the strokes, cropped to them, at 3× for print quality.
    func signaturePNG() -> Data? {
        guard !strokes.isEmpty else { return nil }
        let rect = bounds.insetBy(dx: -8, dy: -8)
        let image = UITraitCollection(userInterfaceStyle: .light).performAsCurrent { self.image(from: rect, scale: 3) }
        return image.pngData()
    }
}

/// Sheet to draw a signature. For a client signature it also asks for their name.
struct SignatureSheet: View {
    enum Purpose { case mine, client(documentTitle: String) }

    let purpose: Purpose
    let save: (_ png: Data, _ name: String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var drawing = PKDrawing()
    @State private var name = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(explanation).foregroundStyle(Color.ink2).font(.system(size: 15))
                if case .client = purpose {
                    TextField("Client's full name", text: $name)
                        .textContentType(.name)
                        .padding(12)
                        .background(Color.surface, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.line))
                }
                SignaturePad(drawing: $drawing)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.line))
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Color.ink3.opacity(0.5)).frame(height: 1).padding(.horizontal, 24).padding(.bottom, 48)
                            .allowsHitTesting(false)
                    }
                Button("Clear", systemImage: "arrow.uturn.backward") { drawing = PKDrawing() }
                    .disabled(drawing.strokes.isEmpty)
                Spacer()
            }
            .padding(16)
            .background(Color.canvas)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if let png = drawing.signaturePNG() { save(png, name.trimmingCharacters(in: .whitespaces)) }
                        dismiss()
                    }
                    .disabled(drawing.strokes.isEmpty || needsName)
                }
            }
        }
        .interactiveDismissDisabled(!drawing.strokes.isEmpty)
    }

    private var needsName: Bool {
        if case .client = purpose { return name.trimmingCharacters(in: .whitespaces).isEmpty }
        return false
    }

    private var title: String {
        switch purpose {
        case .mine: String(localized: "Your signature")
        case .client: String(localized: "Client signs")
        }
    }

    private var explanation: String {
        switch purpose {
        case .mine:
            String(localized: "Draw it once. It goes on your invoices.")
        case .client(let documentTitle):
            String(localized: "Hand your device to your client. Signing accepts this \(documentTitle.lowercased()) (or confirms the work on an invoice). Their name and today's date go on the PDF.")
        }
    }
}
