import Foundation
import SwiftData

/// The current data model (v1.1). CloudKit rules (checked by
/// `CloudKitSchemaTests`): every attribute is optional or has a default,
/// nothing is unique, every relationship is optional and has an inverse.
/// Enums are stored as raw strings. Models are `nonisolated`: SwiftData uses
/// them off the main thread, and the target's main-actor default would
/// otherwise make that a runtime trap.
///
/// Changes from v1 (additive, lightweight migration):
/// - Document: `recurrenceRaw`, `nextRecurrence`, `recurringFromNumber`, `photos`
/// - JobPhoto (new)
///
/// Before the release that ships a new version, deploy the CloudKit schema to
/// Production (CloudKit Console) after running a Debug build once.
enum SchemaV2: VersionedSchema {
    nonisolated static let versionIdentifier = Schema.Version(2, 0, 0)

    nonisolated static var models: [any PersistentModel.Type] {
        [
            Business.self, PaymentDetails.self, TaxRateRecord.self, Client.self, SavedItem.self, Document.self,
            LineItem.self, JobPhoto.self,
        ]
    }
}

enum AppMigrationPlan: SchemaMigrationPlan {
    nonisolated static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self] }
    nonisolated static var stages: [MigrationStage] {
        [.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)]
    }
}

/// The current schema; app code only uses these names.
typealias CurrentSchema = SchemaV2
typealias Business = SchemaV2.Business
typealias PaymentDetails = SchemaV2.PaymentDetails
typealias TaxRateRecord = SchemaV2.TaxRateRecord
typealias Client = SchemaV2.Client
typealias SavedItem = SchemaV2.SavedItem
typealias Document = SchemaV2.Document
typealias LineItem = SchemaV2.LineItem
typealias JobPhoto = SchemaV2.JobPhoto
