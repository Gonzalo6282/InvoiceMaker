import InvoiceKit
import Testing

@testable import InvoiceMaker

struct AppSmokeTests {
    @Test func invoiceKitIsLinked() {
        #expect(!InvoiceKit.version.isEmpty)
    }
}
