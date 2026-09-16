import XCTest

final class NavRuntimeUITests: XCTestCase {
    @MainActor
    func testIleReelle() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
        app.activate()
        XCTAssertTrue(app.staticTexts["In session · 7 min"].waitForExistence(timeout: 10),
                      "Le banc sans données de compte doit être visible")
        let origine = app.coordinate(withNormalizedOffset: .zero)
        let w = app.frame.width, h = app.frame.height
        let y = 130 + 0.82 * (h - 122 - 130)
        origine.withOffset(CGVector(dx: w / 2, dy: y))
            .press(forDuration: 0.03,
                   thenDragTo: origine.withOffset(CGVector(dx: w / 2, dy: 45)),
                   withVelocity: 2200, thenHoldForDuration: 0)
        Thread.sleep(forTimeInterval: 2)
        XCTAssertFalse(app.staticTexts["In session · 7 min"].exists,
                       "Le jet doit ranger la pastille dans l'île")
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "iphone-ile-au-repos"; capture.lifetime = .keepAlways
        add(capture)
        // Une seule fenêtre de repos ; les protections restent actives.
        Thread.sleep(forTimeInterval: 45)
        XCTAssertEqual(app.state, .runningForeground)
        origine.withOffset(CGVector(dx: w / 2, dy: 66)).tap()
        XCTAssertTrue(app.staticTexts["In session · 7 min"].waitForExistence(timeout: 5),
                      "Le tap doit ressortir la pastille")
        let sortie = XCTAttachment(screenshot: app.screenshot())
        sortie.name = "iphone-pastille-sortie"; sortie.lifetime = .keepAlways
        add(sortie)
    }
}
