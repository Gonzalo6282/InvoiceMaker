import Foundation
import SwiftData

/// Version 1 of the data model. CloudKit rules (checked by `CloudKitSchemaTests`):
/// every attribute is optional or has a default, nothing is unique, every
/// relationship is optional and has an inverse. Enums are stored as raw strings.
/// Models are `nonisolated`: SwiftData uses them off the main thread, and the
/// target's main-actor default would otherwise make that a runtime trap.
/// After the first TestFlight build, add `SchemaV2` + a migration stage instead
/// of editing these (ask Gonzalo first, per the spec).
enum SchemaV1: VersionedSchema {
    nonisolated static let versionIdentifier = Schema.Version(1, 0, 0)

    nonisolated static var models: [any PersistentModel.Type] {
        [
            Business.self, PaymentDetails.self, TaxRateRecord.self, Client.self, SavedItem.self, Document.self,
            LineItem.self,
        ]
    }
}

enum AppMigrationPlan: SchemaMigrationPlan {
    nonisolated static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    nonisolated static var stages: [MigrationStage] { [] }
}

typealias Business = SchemaV1.Business
typealias PaymentDetails = SchemaV1.PaymentDetails
typealias TaxRateRecord = SchemaV1.TaxRateRecord
typealias Client = SchemaV1.Client
typealias SavedItem = SchemaV1.SavedItem
typealias Document = SchemaV1.Document
typealias LineItem = SchemaV1.LineItem
