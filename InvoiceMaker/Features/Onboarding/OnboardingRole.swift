import Foundation
import InvoiceKit

/// "What do you do?" (mockup ROLES) with the sample items and template for each.
enum OnboardingRole: String, CaseIterable, Identifiable {
    case freelancer, contractor, shop, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .freelancer: String(localized: "Freelancer")
        case .contractor: String(localized: "Contractor or trades")
        case .shop: String(localized: "Small shop")
        case .other: String(localized: "Something else")
        }
    }

    var detail: String {
        switch self {
        case .freelancer: String(localized: "Design, writing, consulting, photography")
        case .contractor: String(localized: "Builders, plumbers, cleaners, electricians")
        case .shop: String(localized: "Retail, food, products")
        case .other: String(localized: "Any other business")
        }
    }

    var icon: String {
        switch self {
        case .freelancer: "person.fill"
        case .contractor: "hammer.fill"
        case .shop: "bag.fill"
        case .other: "doc.text.fill"
        }
    }

    var template: InvoiceTemplate {
        switch self {
        case .freelancer: .studio
        case .contractor: .trades
        case .shop, .other: .clean
        }
    }

    /// The sample invoice's client: a business that reads as local and
    /// ordinary, so it's glanced at and passed over (no personal names).
    static func sampleClient(for region: Region) -> String {
        switch region {
        case .uk: "Marlow & Finch Ltd"
        case .us: "Oakridge Landscaping"
        case .au: "Harbourside Café Pty Ltd"
        case .ca: "Maple Ridge Builders"
        }
    }

    /// (description, quantity, rate, unit)
    var sampleItems: [(String, Decimal, Decimal, String)] {
        switch self {
        case .freelancer:
            [(String(localized: "Logo design"), 1, 650, "project"), (String(localized: "Brand guidelines"), 1, 400, "project"), (String(localized: "Revisions"), 3, 60, "hour")]
        case .contractor:
            [(String(localized: "Labour"), 6, 45, "hour"), (String(localized: "Materials"), 1, 180, "lot"), (String(localized: "Call-out fee"), 1, 60, "visit")]
        case .shop:
            [(String(localized: "Gift hamper, large"), 4, 55, "item"), (String(localized: "Delivery"), 1, 12, "trip")]
        case .other:
            [(String(localized: "Service"), 2, 120, "hour"), (String(localized: "Materials"), 1, 40, "lot")]
        }
    }
}
