import Photos
import PhotosUI
import SwiftUI

/// Asks for Photos access with the iOS permission pop-up before the logo
/// picker opens. Denied: explains why and links to Settings.
enum PhotoAccess {
    /// True when the app may show the picker (full or limited access).
    static func request() async -> Bool {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            return status == .authorized || status == .limited
        default:
            return false
        }
    }
}

extension View {
    /// Turns any view into a "pick a logo" button that asks for Photos access first.
    func logoPhotoPicker(selection: Binding<PhotosPickerItem?>) -> some View {
        modifier(LogoPhotoPicker(selection: selection))
    }
}

private struct LogoPhotoPicker: ViewModifier {
    @Binding var selection: PhotosPickerItem?
    @State private var showingPicker = false
    @State private var showingDenied = false
    @Environment(\.openURL) private var openURL

    func body(content: Content) -> some View {
        Button {
            Task {
                if await PhotoAccess.request() { showingPicker = true } else { showingDenied = true }
            }
        } label: {
            content
        }
        .buttonStyle(.plain)
        .photosPicker(isPresented: $showingPicker, selection: $selection, matching: .images)
        .alert("Allow access to Photos", isPresented: $showingDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("Duly needs access to your photos to add your logo to invoices. You can allow it in Settings.")
        }
    }
}
