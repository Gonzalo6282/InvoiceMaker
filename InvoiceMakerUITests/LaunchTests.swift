import XCTest

final class LaunchTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testFirstRunCreatesAnInvoiceWithAnItem() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-skipOnboarding"]
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

final class SendFlowTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testSendNeedsClientAndItemThenShowsPaywall() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-skipOnboarding"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Create your first invoice"].waitForExistence(timeout: 10))
        app.buttons["New invoice"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["INV-0001"].waitForExistence(timeout: 5))

        // Nothing filled in: both errors.
        app.buttons["send"].tap()
        XCTAssertTrue(app.staticTexts["Add a client before sending."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Add at least one item with a price."].exists)

        // Add a client and an item.
        app.buttons["pickClient"].tap()
        let name = app.textFields["newClientName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Ostara Cafe\n")
        app.buttons["addItem"].firstMatch.tap()
        let rate = app.textFields["lineRate"].firstMatch
        XCTAssertTrue(rate.waitForExistence(timeout: 5))
        rate.tap()
        rate.typeText("40")
        app.buttons["lineDone"].tap()
        XCTAssertFalse(app.staticTexts["Add a client before sending."].exists)

        // Free user: the paywall (native fallback, no keys on CI) appears.
        app.buttons["send"].tap()
        XCTAssertTrue(app.staticTexts["Send this invoice"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Restore"].exists)
        XCTAssertTrue(app.buttons["Terms"].exists)
        XCTAssertTrue(app.buttons["Privacy"].exists)
    }
}

final class AccessibilityTests: XCTestCase {
    @MainActor
    func testLargestTextSizeStillWorks() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting", "-skipOnboarding",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        app.launch()
        XCTAssertTrue(app.staticTexts["Create your first invoice"].waitForExistence(timeout: 10))
        app.buttons["New invoice"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["INV-0001"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["send"].exists)
        XCTAssertTrue(app.buttons["addItem"].firstMatch.exists)
    }
}
