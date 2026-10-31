#if DEBUG
    import CoreData
    import Foundation
    import SwiftData

    /// Debug only. Creates every record type and field of the current schema in
    /// the CloudKit **Development** environment, so "Deploy Schema Changes" moves
    /// the complete schema to Production (fields that the app hasn't written yet,
    /// like `nextRecurrence` or `recurringFromNumber`, are otherwise missing).
    /// Run once from Xcode with the launch argument `-initCloudKitSchema`.
    /// Apple's recipe: "Syncing model data across a person's devices" (SwiftData).
    nonisolated enum CloudKitSchemaInitializer {
        static func run(containerID: String) throws {
            guard let model = NSManagedObjectModel.makeManagedObjectModel(for: CurrentSchema.models) else {
                throw CocoaError(.featureUnsupported)
            }
            // A throwaway store file: only the model matters, the app's data isn't touched.
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("cloudkit-schema-\(UUID().uuidString).store")
            let description = NSPersistentStoreDescription(url: url)
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: containerID)
            description.shouldAddStoreAsynchronously = false
            let container = NSPersistentCloudKitContainer(name: "InvoiceMakerSchema", managedObjectModel: model)
            container.persistentStoreDescriptions = [description]
            var loadError: Error?
            container.loadPersistentStores { _, error in loadError = error }
            if let loadError { throw loadError }
            try container.initializeCloudKitSchema()
            for store in container.persistentStoreCoordinator.persistentStores {
                try container.persistentStoreCoordinator.remove(store)
            }
            try? FileManager.default.removeItem(at: url)
        }
    }
#endif
