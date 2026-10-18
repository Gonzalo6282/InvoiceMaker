import XCTest

final class LaunchTests: XCTestCase {
    @MainActor
    func testFirstRunCreatesAnInvoice() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        let storeError = app.staticTexts["storeError"]
        if storeError.waitForExistence(timeout: 2) {
            XCTFail("Store failed to open: \(storeError.label)")
        }
        // First run: empty invoices list with the call to action.
        XCTAssertTrue(app.staticTexts["Create your first invoice"].waitForExistence(timeout: 10))
        app.buttons["New invoice"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["INV-0001"].waitForExistence(timeout: 5))
    }
}
