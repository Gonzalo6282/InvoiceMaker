import CoreData
import Foundation

/// Notes when the first iCloud import has finished, so a reinstall on a phone
/// whose data is in iCloud doesn't show onboarding before that data arrives.
/// Started before the store opens so the first import event isn't missed.
@MainActor
final class CloudImportWatcher {
    static let shared = CloudImportWatcher()

    private(set) var firstImportFinished = false
    private var observer: NSObjectProtocol?

    /// True when this device is signed in to iCloud (data may be coming).
    var iCloudAvailable: Bool { FileManager.default.ubiquityIdentityToken != nil }

    func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: .main
        ) { note in
            let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event
            guard let event, event.type == .import, event.endDate != nil else { return }
            MainActor.assumeIsolated { CloudImportWatcher.shared.firstImportFinished = true }
        }
    }

    /// Waits until the first import ends, `ready()` returns true, or `timeout` passes.
    func wait(timeout: Duration, ready: () -> Bool) async {
        let clock = ContinuousClock()
        let end = clock.now + timeout
        while !firstImportFinished, !ready(), clock.now < end {
            try? await Task.sleep(for: .milliseconds(200))
        }
    }
}
