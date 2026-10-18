import Testing

@testable import InvoiceMaker

struct DesignSystemTests {
    @Test(arguments: [
        ("Marlow & Finch Architects", "MF"), ("Ostara Café", "OC"), ("jonas", "J"), ("", "?"), ("  ", "?"),
        ("Ünal Öztürk", "ÜÖ"), ("4 Seasons Ltd", "4S"),
    ])
    func avatarInitials(name: String, expected: String) {
        #expect(Avatar.initials(for: name) == expected)
    }
}
