import XCTest

final class RestartPopupUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    override func tearDown() {
        XCUIApplication(bundleIdentifier: "fr.kathryn.woop").terminate()
        super.tearDown()
    }

    @MainActor
    private func lancer(_ langue: String) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
        app.launchArguments = ["-skipAuth", "-porteVue", "-sansVisite", "-sansSondeVol",
                               "-sansServeur", "-exoLab", "-restartFire", "-woop.langue", langue]
        app.launch()
        XCTAssertTrue(app.buttons["restart-launch"].waitForExistence(timeout: 25))
        return app
    }

    private func capturer(_ app: XCUIApplication, _ nom: String) {
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = nom
        capture.lifetime = .keepAlways
        add(capture)
    }

    @MainActor
    func testFrancaisTerminer() {
        let app = lancer("fr")
        XCTAssertTrue(app.staticTexts["Encore une série ?"].exists)
        XCTAssertEqual(app.buttons["restart-launch"].label, "Recommencer")
        XCTAssertEqual(app.buttons["restart-dismiss"].label, "Terminé")
        capturer(app, "relance-fr")
        app.buttons["restart-dismiss"].tap()
        XCTAssertTrue(app.buttons["restart-launch"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["SET 2"].exists)
        capturer(app, "retour-fiche")
    }

    @MainActor
    func testAnglaisRelancer() {
        let app = lancer("en")
        XCTAssertTrue(app.staticTexts["One more set?"].exists)
        XCTAssertEqual(app.buttons["restart-launch"].label, "Start again")
        capturer(app, "relance-en")
        app.buttons["restart-launch"].tap()
        XCTAssertTrue(app.buttons["restart-launch"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["SET 2"].waitForExistence(timeout: 8))
        capturer(app, "serie-relancee")
    }

    @MainActor
    func testFondEtRetourArrierePlan() {
        let app = lancer("fr")
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.buttons["restart-launch"].waitForExistence(timeout: 5))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
        XCTAssertTrue(app.buttons["restart-launch"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["SET 2"].exists)
    }

    @MainActor
    func testCroixFermeSansRelancer() {
        let app = lancer("fr")
        app.buttons["restart-close"].tap()
        XCTAssertTrue(app.buttons["restart-launch"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["SET 2"].exists)
    }
}
