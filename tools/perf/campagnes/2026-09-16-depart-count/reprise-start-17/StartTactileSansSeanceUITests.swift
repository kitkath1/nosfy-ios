import XCTest
final class NavRuntimeUITests: XCTestCase {
    @MainActor func testStartTactileSansSeance() {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
        app.launchArguments = ["-sansSondeVol", "-ecranEveille", "-navProbe", "-homeChemin", "-startTactileLab"]
        app.launch()
        func capturer(_ nom: String) {
            let image = XCTAttachment(screenshot: app.screenshot()); image.name=nom; image.lifetime = .keepAlways; add(image)
            let arbre = XCTAttachment(string: app.debugDescription); arbre.name=nom+"-arbre"; arbre.lifetime = .keepAlways; add(arbre)
        }
        let start = app.buttons["Start"]
        XCTAssertTrue(start.waitForExistence(timeout: 25))
        XCTAssertTrue(start.isHittable)
        capturer("avant-start-banc")
        start.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let film = app.buttons["depart-compte-rebours"]
        let vu = film.waitForExistence(timeout: 4)
        capturer("apres-start-banc")
        XCTAssertTrue(vu, "Le vrai bouton Start doit monter le film, sans séance créée au banc")
        XCTAssertTrue(film.waitForNonExistence(timeout: 12))
        XCTAssertTrue(app.buttons["Entraînements"].isSelected)
        capturer("apres-film-banc")
    }
}
