import Foundation

public enum DocumentKind: String, CaseIterable, Sendable, Codable {
    case invoice
    case estimate
    case receipt
}

/// Prefix + zero-padded counter per kind, e.g. INV-0013. Counters go up by
/// one with each new document and never reuse a number.
public struct DocumentNumbering: Equatable, Sendable, Codable {
    public var prefixes: [DocumentKind: String]
    public var next: [DocumentKind: Int]
    public var padding: Int

    public static let defaultPrefixes: [DocumentKind: String] = [.invoice: "INV-", .estimate: "EST-", .receipt: "REC-"]

    public init(prefixes: [DocumentKind: String] = defaultPrefixes, next: [DocumentKind: Int] = [:], padding: Int = 4) {
        self.prefixes = prefixes
        self.next = next
        self.padding = padding
    }

    /// The number the next document of this kind will get, without using it up.
    public func peek(_ kind: DocumentKind) -> String {
        Self.format(prefix: prefixes[kind] ?? "", number: nextNumber(kind), padding: padding)
    }

    /// Returns the next number and moves the counter on.
    public mutating func take(_ kind: DocumentKind) -> String {
        let value = peek(kind)
        next[kind] = nextNumber(kind) + 1
        return value
    }

    private func nextNumber(_ kind: DocumentKind) -> Int { max(next[kind] ?? 1, 1) }

    public static func format(prefix: String, number: Int, padding: Int) -> String {
        let digits = String(max(number, 0))
        let zeros = String(repeating: "0", count: max(padding - digits.count, 0))
        return prefix + zeros + digits
    }
}
