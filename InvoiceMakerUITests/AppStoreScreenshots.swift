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
        open(lang.invoice(7))
        shot("02-editor")
        tapPreview()
        shot("03-templates")

        // 4. Paid invoice: banner, then the PDF.
        launch(hideSidebar: true)
        open(lang.invoice(9))
        shot("04-paid-editor")
        tapPreview()
        shot("05-paid-pdf")

        // 5. Send: the share sheet over the PDF.
        launch(hideSidebar: true)
        open(lang.invoice(7))
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
        goTo(lang.clients)
        sleep(1)
        shot("11-clients")

        // 10. Job photos (v1.1): the photo strip on the invoice, then the photo page of the PDF.
        launch(hideSidebar: true)
        open(lang.invoice(7))
        let addPhotos = app.descendants(matching: .any)["addPhotos"].firstMatch
        for _ in 0..<8 where !(addPhotos.exists && addPhotos.isHittable) {
            app.swipeUp(velocity: .slow)
        }
        sleep(1)
        shot("13-photos-editor")
        tapPreview()
        for _ in 0..<4 { app.swipeUp() }
        sleep(2)
        shot("14-photos-pdf")

        // 9. Invoice look (templates and colours) in Settings.
        launch()
        goTo(lang.settings)
        let look = app.staticTexts[lang.invoiceLook].firstMatch
        if look.waitForExistence(timeout: 5) { look.tap() }
        sleep(1)
        shot("12-invoice-look")
    }

    // MARK: Helpers

    /// SCREENSHOT_REGION: US (default, $ and estimates), UK (£ and quotes),
    /// AU (A$, GST, quotes), CA (C$, HST, estimates), DE or FR (euros, German or French app text).
    struct Language {
        let demoRegion: String
        let languages: String
        let locale: String
        let firstClient: String
        let invoicePrefix: String
        let clients: String
        let settings: String
        let invoiceLook: String
        let preview: String
        let sidebarWords: [String]

        func invoice(_ n: Int) -> String { invoicePrefix + String(format: "%04d", n) }

        static var current: Language {
            switch (ProcessInfo.processInfo.environment["SCREENSHOT_REGION"] ?? "US").uppercased() {
            case "UK":
                Language(
                    demoRegion: "GB", languages: "(en-GB)", locale: "en_GB", firstClient: "Marlow & Finch Architects",
                    invoicePrefix: "INV-", clients: "Clients", settings: "Settings", invoiceLook: "Invoice look",
                    preview: "Preview", sidebarWords: ["sidebar"])
            case "AU":
                Language(
                    demoRegion: "AU", languages: "(en-AU)", locale: "en_AU", firstClient: "Harbourside Café Pty Ltd",
                    invoicePrefix: "INV-", clients: "Clients", settings: "Settings", invoiceLook: "Invoice look",
                    preview: "Preview", sidebarWords: ["sidebar"])
            case "CA":
                Language(
                    demoRegion: "CA", languages: "(en-CA)", locale: "en_CA", firstClient: "Maple Ridge Builders",
                    invoicePrefix: "INV-", clients: "Clients", settings: "Settings", invoiceLook: "Invoice look",
                    preview: "Preview", sidebarWords: ["sidebar"])
            case "DE":
                Language(
                    demoRegion: "DE", languages: "(de)", locale: "de_DE", firstClient: "Lindenhof Gartenbau GmbH",
                    invoicePrefix: "RE-", clients: "Kunden", settings: "Einstellungen", invoiceLook: "Rechnungsdesign",
                    preview: "Vorschau", sidebarWords: ["Seitenleiste", "sidebar"])
            case "FR":
                Language(
                    demoRegion: "FR", languages: "(fr)", locale: "fr_FR", firstClient: "Boulangerie des Tilleuls SARL",
                    invoicePrefix: "FAC-", clients: "Clients", settings: "Réglages", invoiceLook: "Apparence des factures",
                    preview: "Aperçu", sidebarWords: ["barre latérale", "sidebar"])
            default:
                Language(
                    demoRegion: "US", languages: "(en-US)", locale: "en_US", firstClient: "Oakridge Landscaping",
                    invoicePrefix: "INV-", clients: "Clients", settings: "Settings", invoiceLook: "Invoice look",
                    preview: "Preview", sidebarWords: ["sidebar"])
            }
        }
    }

    private let lang = Language.current

    @MainActor
    private func launch(hideSidebar: Bool = false) {
        app?.terminate()
        app = XCUIApplication()
        // Demo job photos for invoice 0007 (read by DemoData in Debug builds; the simulator shares the Mac's disk).
        app.launchEnvironment["DEMO_PHOTOS_DIR"] = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().appendingPathComponent("DemoPhotos").path
        app.launchArguments = [
            "-uiTesting", "-skipOnboarding", "-demoData", "-premium", hideSidebar ? "-hideSidebar" : "-showSidebar",
            "-demoRegion", lang.demoRegion, "-AppleLanguages", lang.languages, "-AppleLocale", lang.locale,
        ]
        app.launch()
        XCTAssertTrue(app.staticTexts[lang.firstClient].firstMatch.waitForExistence(timeout: 20))
        sleep(1)
        // iPad: hide the sidebar so the list and the document get the room.
        if hideSidebar {
            let words = lang.sidebarWords.map { "label CONTAINS[c] '\($0)'" }.joined(separator: " OR ")
            let toggle = app.buttons.matching(NSPredicate(format: words)).firstMatch
            if toggle.exists, app.staticTexts[lang.settings].firstMatch.isHittable {
                toggle.tap()
                sleep(1)
            }
        }
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
        let preview = app.buttons[lang.preview].firstMatch
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
