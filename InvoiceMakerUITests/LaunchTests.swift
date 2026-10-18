import XCTest

final class LaunchTests: XCTestCase {
    @MainActor
    func testLaunchShowsAppName() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Duly"].waitForExistence(timeout: 5))
    }
}
