import PhotosUI
import SwiftData
import SwiftUI

/// Job photos on a document (v1.1). Picked with the system photo picker (no
/// Photos permission needed), stored downscaled, printed after the document.
struct EditorPhotosSection: View {
    @Bindable var document: Document
    @Environment(\.modelContext) private var context
    @State private var picked: [PhotosPickerItem] = []
    @State private var loading = false

    static let maxPhotos = 10

    var body: some View {
        GroupedSection(header: "Job photos", footer: "Shown on a page after the invoice. Up to 10.") {
            let photos = document.sortedPhotos
            if !photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(photos) { photo in thumbnail(photo) }
                    }
                    .padding(14)
                }
                RowDivider()
            }
            PhotosPicker(
                selection: $picked, maxSelectionCount: max(1, Self.maxPhotos - photos.count), matching: .images
            ) {
                Row(icon: "camera.fill", iconTint: .item, title: photos.isEmpty ? "Add photos" : "Add more photos") {
                    if loading { ProgressView() }
                }
            }
            .buttonStyle(.plain)
            .disabled(photos.count >= Self.maxPhotos || loading)
            .accessibilityIdentifier("addPhotos")
        }
        .onChange(of: picked) { _, items in add(items) }
    }

    private func thumbnail(_ photo: JobPhoto) -> some View {
        let image = photo.imageData.flatMap(UIImage.init(data:))
        return Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Color.canvas
            }
        }
        .frame(width: 76, height: 76)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.line, lineWidth: 1))
        .contextMenu {
            Button("Remove photo", systemImage: "trash", role: .destructive) { remove(photo) }
        }
        .accessibilityLabel(Text("Job photo"))
        .accessibilityAction(named: Text("Remove photo")) { remove(photo) }
    }

    private func add(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        loading = true
        Task {
            defer {
                loading = false
                picked = []
            }
            var position = (document.photos ?? []).map(\.position).max().map { $0 + 1 } ?? 0
            for item in items {
                guard (document.photos ?? []).count < Self.maxPhotos,
                    let data = try? await item.loadTransferable(type: Data.self),
                    let jpeg = JobPhotoImage.prepare(data)
                else { continue }
                let photo = JobPhoto(position: position, imageData: jpeg)
                context.insert(photo)
                photo.document = document
                position += 1
                AppAnalytics.shared.log(.photoAdded)
            }
            document.updatedAt = .now
        }
    }

    private func remove(_ photo: JobPhoto) {
        photo.document = nil
        context.delete(photo)
        document.updatedAt = .now
    }
}

enum JobPhotoImage {
    /// At most 1600 px on the long side, JPEG: sharp in the PDF, small in iCloud.
    static func prepare(_ data: Data, maxSide: CGFloat = 1600) -> Data? {
        guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else { return nil }
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.75)
    }
}
