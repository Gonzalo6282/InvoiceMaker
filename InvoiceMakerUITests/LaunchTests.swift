import XCTest

final class LaunchTests: XCTestCase {
    @MainActor
    func testLaunchShowsAppName() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Duly"].waitForExistence(timeout: 5))
    }
}
