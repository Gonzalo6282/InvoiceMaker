import CoreData
import Foundation
import Observation

/// Notes when the first iCloud import has finished, so a reinstall on a phone
/// whose data is in iCloud doesn't show onboarding before that data arrives.
/// Started before the store opens so the first import event isn't missed.
/// Also keeps the latest sync results for Settings > iCloud backup.
@MainActor
@Observable
final class CloudImportWatcher {
    static let shared = CloudImportWatcher()

    /// One finished iCloud upload (export), download (import) or setup.
    struct SyncResult {
        let kind: String
        let date: Date
        let error: String?
    }

    private(set) var firstImportFinished = false
    /// "iCloud" or "This device only: <reason>", set when the store opens.
    var storeDescription = "Not opened yet"
    private(set) var lastResults: [String: SyncResult] = [:]
    @ObservationIgnored private var observer: NSObjectProtocol?

    /// True when this device is signed in to iCloud (data may be coming).
    var iCloudAvailable: Bool { FileManager.default.ubiquityIdentityToken != nil }

    func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: .main
        ) { note in
            let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event
            guard let event, let end = event.endDate else { return }
            let kind: String = switch event.type {
            case .setup: "Setup"
            case .import: "Download"
            case .export: "Upload"
            @unknown default: "Other"
            }
            let error = event.error.map { error -> String in
                let ns = error as NSError
                return "\(ns.localizedDescription) (\(ns.domain) \(ns.code))"
            }
            let isImport = event.type == .import
            MainActor.assumeIsolated {
                let watcher = CloudImportWatcher.shared
                if isImport { watcher.firstImportFinished = true }
                watcher.lastResults[kind] = SyncResult(kind: kind, date: end, error: error)
            }
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
