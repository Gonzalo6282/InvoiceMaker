import XCTest

/// Captures the screens used for the App Store images, with the demo business
/// (Kestrel Joinery). Runs only when SCREENSHOT_DIR is set (the "Screenshots"
/// workflow), so normal CI skips it.
final class AppStoreScreenshots: XCTestCase {
    private var dir: URL?
    private var app: XCUIApplication!  // swiftlint:disable:this implicitly_unwrapped_optional

    override func setUpWithError() throws {
        continueAfterFailure = true
        guard let path = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"], !path.isEmpty else {
            throw XCTSkip("SCREENSHOT_DIR not set")
        }
        dir = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: URL(fileURLWithPath: path), withIntermediateDirectories: true)
    }

    @MainActor
    func testCaptureAppStoreScreens() {
        // 1. Invoice list: statuses and the owed total.
        launch(hideSidebar: true)
        shot("01-list")

        // 2–3. A finished invoice, then its PDF with the template strip.
        open("INV-0007")
        shot("02-editor")
        tapPreview()
        shot("03-templates")

        // 4. Paid invoice: banner, then the PDF.
        launch(hideSidebar: true)
        open("INV-0009")
        shot("04-paid-editor")
        tapPreview()
        shot("05-paid-pdf")

        // 5. Send: the share sheet over the PDF.
        launch(hideSidebar: true)
        open("INV-0007")
        app.buttons["send"].firstMatch.tap()
        sleep(3)
        shot("06-share")

        // 6. Estimate (Quote in the UK) accepted, ready to turn into an invoice.
        launch(hideSidebar: true)
        segment(1)
        shot("07-quotes-list")
        tapFirstRow()
        shot("08-quote-editor")
        tapPreview()
        shot("09-quote-pdf")

        // 7. Receipt.
        launch(hideSidebar: true)
        segment(2)
        tapFirstRow()
        tapPreview()
        shot("10-receipt-pdf")

        // 8. Clients.
        launch()
        goTo("Clients")
        sleep(1)
        shot("11-clients")

        // 9. Invoice look (templates and colours) in Settings.
        launch()
        goTo("Settings")
        let look = app.staticTexts["Invoice look"].firstMatch
        if look.waitForExistence(timeout: 5) { look.tap() }
        sleep(1)
        shot("12-invoice-look")
    }

    // MARK: Helpers

    @MainActor
    private func launch(hideSidebar: Bool = false) {
        app?.terminate()
        app = XCUIApplication()
        // SCREENSHOT_REGION: US (default, $ and estimates) or UK (£ and quotes).
        let us = (ProcessInfo.processInfo.environment["SCREENSHOT_REGION"] ?? "US").uppercased() != "UK"
        app.launchArguments = [
            "-uiTesting", "-skipOnboarding", "-demoData", "-premium", hideSidebar ? "-hideSidebar" : "-showSidebar",
            "-demoRegion", us ? "US" : "GB",
            "-AppleLanguages", us ? "(en-US)" : "(en-GB)", "-AppleLocale", us ? "en_US" : "en_GB",
        ]
        app.launch()
        let client = us ? "Oakridge Landscaping" : "Marlow & Finch Architects"
        XCTAssertTrue(app.staticTexts[client].firstMatch.waitForExistence(timeout: 20))
        sleep(1)
    }

    /// Tab on iPhone, sidebar row on iPad.
    @MainActor
    private func goTo(_ name: String) {
        let tab = app.tabBars.buttons[name]
        if tab.exists { tab.tap() } else { app.staticTexts[name].firstMatch.tap() }
        sleep(1)
    }

    @MainActor
    private func open(_ number: String) {
        let row = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", number)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "No row \(number)")
        row.tap()
        sleep(2)
    }

    @MainActor
    private func tapFirstRow() {
        let row = app.staticTexts.matching(NSPredicate(format: "label CONTAINS ' · '")).firstMatch
        if row.waitForExistence(timeout: 5) { row.tap() }
        sleep(2)
    }

    @MainActor
    private func segment(_ index: Int) {
        let control = app.segmentedControls.firstMatch
        XCTAssertTrue(control.waitForExistence(timeout: 5))
        control.buttons.element(boundBy: index).tap()
        sleep(1)
    }

    @MainActor
    private func tapPreview() {
        let preview = app.buttons["Preview"].firstMatch
        if preview.waitForExistence(timeout: 5) { preview.tap() }
        sleep(3)
    }

    @MainActor
    private func shot(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir { try? screenshot.pngRepresentation.write(to: dir.appendingPathComponent("\(name).png")) }
    }
}
