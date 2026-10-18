import XCTest

final class LaunchTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testFirstRunCreatesAnInvoiceWithAnItem() throws {
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

        // Add an item: description, rate, done. The simulator region is US: sales tax 8.875%.
        app.buttons["addItem"].firstMatch.tap()
        let description = app.descendants(matching: .any)["lineDescription"].firstMatch
        XCTAssertTrue(description.waitForExistence(timeout: 5))
        description.tap()
        description.typeText("Labour")
        let rate = app.textFields["lineRate"].firstMatch
        rate.tap()
        rate.typeText("50")
        app.buttons["lineDone"].tap()

        let total = app.staticTexts["documentTotal"].firstMatch
        XCTAssertTrue(total.waitForExistence(timeout: 5))
        XCTAssertTrue(total.label.contains("54.44"), "Total was \(total.label)")
        XCTAssertTrue(app.staticTexts["Labour"].exists)
    }
}
