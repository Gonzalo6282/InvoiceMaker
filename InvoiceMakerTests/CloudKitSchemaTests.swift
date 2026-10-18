import CoreData
import SwiftData
import Testing

@testable import InvoiceMaker

/// CloudKit refuses models that break these rules, and it only shows up on a
/// real device with iCloud. Catch it here instead.
@MainActor
struct CloudKitSchemaTests {
    let model = NSManagedObjectModel.makeManagedObjectModel(for: SchemaV1.models)

    @Test func everyModelIsInTheSchema() {
        #expect(Set(model.entities.compactMap(\.name)) == ["Business", "PaymentDetails", "TaxRateRecord", "Client", "SavedItem", "Document", "LineItem"])
    }

    @Test func noUniqueConstraints() {
        for entity in model.entities {
            #expect(entity.uniquenessConstraints.isEmpty, "\(entity.name ?? "?") has a unique constraint")
        }
    }

    @Test func everyAttributeIsOptionalOrHasADefault() {
        for entity in model.entities {
            for (name, attribute) in entity.attributesByName {
                #expect(
                    attribute.isOptional || attribute.defaultValue != nil,
                    "\(entity.name ?? "?").\(name) needs a default value or must be optional")
            }
        }
    }

    @Test func everyRelationshipIsOptionalWithAnInverse() {
        for entity in model.entities {
            for (name, relationship) in entity.relationshipsByName {
                #expect(relationship.isOptional, "\(entity.name ?? "?").\(name) must be optional")
                #expect(relationship.inverseRelationship != nil, "\(entity.name ?? "?").\(name) needs an inverse")
                #expect(relationship.deleteRule != .denyDeleteRule, "\(entity.name ?? "?").\(name) can't use deny")
            }
        }
    }

    @Test func inMemoryContainerOpens() throws {
        let container = try ModelContainerFactory.make(.inMemory)
        let context = container.mainContext
        context.insert(Business(name: "Kestrel Joinery"))
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Business>()) == 1)
    }
}
