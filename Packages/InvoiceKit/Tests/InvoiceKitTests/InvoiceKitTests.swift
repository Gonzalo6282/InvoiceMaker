import InvoiceKit
import Testing

struct InvoiceKitTests {
    @Test func versionIsSet() {
        #expect(InvoiceKit.version == "0.1.0")
    }
}
