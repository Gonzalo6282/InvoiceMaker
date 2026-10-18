import CoreData
import SwiftData
import Testing

@testable import InvoiceMaker

/// CloudKit refuses models that break these rules, and it only shows up on a
/// real device with iCloud. Catch it here instead.
@MainActor
struct CloudKitSchemaTests {
    // Optional binding works whether the API returns an optional or not.
    let model: NSManagedObjectModel? = NSManagedObjectModel.makeManagedObjectModel(for: SchemaV1.models)
    var entities: [NSEntityDescription] { model?.entities ?? [] }

    @Test func everyModelIsInTheSchema() {
        #expect(model != nil)
        #expect(Set(entities.compactMap(\.name)) == ["Business", "PaymentDetails", "TaxRateRecord", "Client", "SavedItem", "Document", "LineItem"])
    }

    @Test func noUniqueConstraints() {
        for entity in entities {
            #expect(entity.uniquenessConstraints.isEmpty, "\(entity.name ?? "?") has a unique constraint")
        }
    }

    @Test func everyAttributeIsOptionalOrHasADefault() {
        for entity in entities {
            for (name, attribute) in entity.attributesByName {
                #expect(
                    attribute.isOptional || attribute.defaultValue != nil,
                    "\(entity.name ?? "?").\(name) needs a default value or must be optional")
            }
        }
    }

    @Test func everyRelationshipIsOptionalWithAnInverse() {
        for entity in entities {
            for (name, relationship) in entity.relationshipsByName {
                #expect(relationship.isOptional, "\(entity.name ?? "?").\(name) must be optional")
                #expect(relationship.inverseRelationship != nil, "\(entity.name ?? "?").\(name) needs an inverse")
                #expect(relationship.deleteRule != NSDeleteRule.denyDeleteRule, "\(entity.name ?? "?").\(name) can't use deny")
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

@MainActor
struct ModelContainerFactoryTests {
    @Test func testsGetAnInMemoryStore() throws {
        let result = ModelContainerFactory.forApp(arguments: ["-uiTesting"], environment: [:])
        let container = try result.get()
        #expect(container.configurations.first?.isStoredInMemoryOnly == true)
        let unit = try ModelContainerFactory.forApp(arguments: [], environment: ["XCTestConfigurationFilePath": "x"]).get()
        #expect(unit.configurations.first?.isStoredInMemoryOnly == true)
    }
}
