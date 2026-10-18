import XCTest

final class OnboardingTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testOnboardingCreatesFirstInvoiceThenSoftPaywall() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Create and send an invoice in 60 seconds"].waitForExistence(timeout: 10))
        app.buttons["onboardingNext"].tap()

        XCTAssertTrue(app.staticTexts["What do you do?"].waitForExistence(timeout: 3))
        app.buttons["Contractor or trades"].firstMatch.tap()
        app.buttons["onboardingNext"].tap()

        let name = app.textFields["onboardingBusinessName"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.tap()
        name.typeText("Kestrel Joinery")
        app.buttons["onboardingNext"].tap()

        XCTAssertTrue(app.staticTexts["Here's your first invoice"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["Ruth Adeyemi"].exists || app.textFields.element(boundBy: 0).exists)
        app.buttons["onboardingDone"].tap()

        // Soft paywall over the new invoice; closing it keeps the invoice.
        XCTAssertTrue(app.staticTexts["Send invoices that get paid"].waitForExistence(timeout: 5))
        app.buttons["Close"].tap()
        XCTAssertTrue(app.staticTexts["INV-0001"].waitForExistence(timeout: 5))
    }
}
