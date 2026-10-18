import SwiftUI
import UIKit

/// UIActivityViewController for files (works as a popover on iPad).
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var completion: ((_ completed: Bool, _ activity: UIActivity.ActivityType?) -> Void)?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { activity, completed, _, _ in completion?(completed, activity) }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// Wraps a URL so `.sheet(item:)` can present it.
struct SharedFile: Identifiable {
    let id = UUID()
    let url: URL
}
