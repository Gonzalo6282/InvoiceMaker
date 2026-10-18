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
    }

    static func make(_ storage: Storage) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration: ModelConfiguration =
            switch storage {
            case .cloudKit:
                ModelConfiguration(schema: schema, cloudKitDatabase: .private(cloudKitContainerID))
            case .local:
                ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            case .inMemory:
                ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            }
        return try ModelContainer(for: schema, migrationPlan: AppMigrationPlan.self, configurations: configuration)
    }

    /// The app's container: CloudKit, falling back to local storage so the app
    /// always opens. UI tests pass `-uiTesting` to get a clean in-memory store.
    static func forApp(arguments: [String] = ProcessInfo.processInfo.arguments) -> ModelContainer {
        if arguments.contains("-uiTesting") {
            return (try? make(.inMemory)) ?? fatalContainer()
        }
        do {
            return try make(.cloudKit)
        } catch {
            Logger(subsystem: "uk.slice-of-life.invoicemaker", category: "data")
                .error("CloudKit store failed, using local store: \(error.localizedDescription)")
            return (try? make(.local)) ?? fatalContainer()
        }
    }

    private static func fatalContainer() -> ModelContainer {
        // Last resort so the app still opens (data won't persist this session).
        guard let container = try? make(.inMemory) else {
            preconditionFailure("Could not create any SwiftData store")
        }
        return container
    }
}
