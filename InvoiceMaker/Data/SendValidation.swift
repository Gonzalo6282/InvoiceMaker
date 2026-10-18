import Foundation

/// What must be filled in before a document can leave the app (mockup errors).
struct SendValidation: OptionSet, Sendable {
    let rawValue: Int
    static let missingClient = SendValidation(rawValue: 1 << 0)
    static let missingItems = SendValidation(rawValue: 1 << 1)

    static func check(_ doc: Document) -> SendValidation {
        var issues: SendValidation = []
        if doc.client == nil { issues.insert(.missingClient) }
        if !(doc.items ?? []).contains(where: { $0.rate > 0 && $0.quantity > 0 }) { issues.insert(.missingItems) }
        return issues
    }
}
