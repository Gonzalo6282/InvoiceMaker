import XCTest

final class LaunchTests: XCTestCase {
    @MainActor
    func testLaunchShowsAppName() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        let storeError = app.staticTexts["storeError"]
        if storeError.waitForExistence(timeout: 2) {
            XCTFail("Store failed to open: \(storeError.label)")
        }
        XCTAssertTrue(app.staticTexts["Duly"].waitForExistence(timeout: 5))
    }
}
