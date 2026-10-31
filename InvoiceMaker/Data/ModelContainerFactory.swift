import Foundation
import OSLog
import SwiftData

enum ModelContainerFactory {
    static let cloudKitContainerID = "iCloud.uk.slice-of-life.invoicemaker"

    enum Storage {
        /// On disk, synced to the user's private iCloud database.
        case cloudKit
        /// On disk, no sync (used if CloudKit can't start).
        case local
        /// Tests and previews.
        case inMemory
        /// A store file without sync (migration tests).
        case file(URL)
    }

    /// In-memory store for unit tests, with autosave off: its timer could fire
    /// after a test has released the container and trap (flaky CI, 19 Oct).
    /// Tests save explicitly.
    @MainActor
    static func makeForTests() throws -> ModelContainer {
        let container = try make(.inMemory)
        container.mainContext.autosaveEnabled = false
        return container
    }

    static func make(_ storage: Storage) throws -> ModelContainer {
        let schema = Schema(versionedSchema: CurrentSchema.self)
        let configuration: ModelConfiguration =
            switch storage {
            case .cloudKit:
                ModelConfiguration(schema: schema, cloudKitDatabase: .private(cloudKitContainerID))
            case .local:
                ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            case .inMemory:
                ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            case .file(let url):
                ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            }
        return try ModelContainer(for: schema, migrationPlan: AppMigrationPlan.self, configurations: configuration)
    }

    /// The app's container: CloudKit, falling back to local storage so the app
    /// always opens. Tests get a clean in-memory store: UI tests pass
    /// `-uiTesting`; unit tests are detected by XCTest's environment variable
    /// (CI builds are unsigned, and CloudKit needs the iCloud entitlement).
    static func forApp(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Result<ModelContainer, Error> {
        let log = Logger(subsystem: "uk.slice-of-life.invoicemaker", category: "data")
        if arguments.contains("-uiTesting") || environment["XCTestConfigurationFilePath"] != nil {
            return Result { try make(.inMemory) }
        }
        #if DEBUG
            if arguments.contains("-initCloudKitSchema") {
                do {
                    try CloudKitSchemaInitializer.run(containerID: cloudKitContainerID)
                    log.notice("CloudKit schema initialised in Development")
                } catch {
                    log.error("CloudKit schema init failed: \(error.localizedDescription)")
                }
            }
        #endif
        do {
            let container = try make(.cloudKit)
            Task { @MainActor in CloudImportWatcher.shared.storeDescription = String(localized: "iCloud") }
            return .success(container)
        } catch {
            log.error("CloudKit store failed, using local store: \(error.localizedDescription)")
            let reason = (error as NSError).localizedDescription
            Task { @MainActor in CloudImportWatcher.shared.storeDescription = String(localized: "This device only: \(reason)") }
            return Result { try make(.local) }
        }
    }
}
