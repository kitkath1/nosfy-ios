import XCTest

final class FermetureChambreUITests: XCTestCase {
    override func setUpWithError() throws {
        #if !targetEnvironment(simulator)
        throw XCTSkip("Parcours local réservé au simulateur")
        #endif
        continueAfterFailure = false
    }

    private func ouvrir(_ kind: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-skipAuth", "-porteVue", "-sansVisite", "-sansServeur",
                               "-sansSondeVol", "-openTab", "home", "-woop.langue", "fr",
                               "-chambreVide", "-chambreLongue", kind]
        app.launch()
        XCTAssertTrue(app.staticTexts["Semaine"].waitForExistence(timeout: 15))
        return app
    }

    private func tirer(_ app: XCUIApplication, de: CGFloat, vers: CGFloat) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: de))
            .press(forDuration: 0.1, thenDragTo:
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: vers)))
    }

    func test01_tirerDepuisLeContenuEnHautFerme() {
        let app = ouvrir("regularite")
        defer { app.terminate() }
        tirer(app, de: 0.45, vers: 0.69)
        XCTAssertTrue(app.staticTexts["Semaine"].waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Accueil"].waitForExistence(timeout: 3))
    }

    func test02_gesteCourtDePoigneeEtAnnulation() {
        let app = ouvrir("volume")
        defer { app.terminate() }
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12))
            .press(forDuration: 0.1, thenDragTo:
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.145)),
                   withVelocity: .slow, thenHoldForDuration: 0.3)
        XCTAssertTrue(app.staticTexts["Semaine"].exists)
        tirer(app, de: 0.12, vers: 0.23)
        XCTAssertTrue(app.staticTexts["Semaine"].waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Accueil"].waitForExistence(timeout: 3))
    }

    func test03_leDefilementGardeLaChambre() {
        let app = ouvrir("hiit")
        defer { app.terminate() }
        tirer(app, de: 0.76, vers: 0.40)
        XCTAssertTrue(app.staticTexts["Semaine"].exists)
        tirer(app, de: 0.46, vers: 0.60)
        XCTAssertTrue(app.staticTexts["Semaine"].exists,
                      "Un drag commencé dans le contenu défilé ne ferme pas la chambre")
        // L'en-tête ferme aussi après avoir fait défiler le contenu.
        tirer(app, de: 0.12, vers: 0.36)
        XCTAssertTrue(app.staticTexts["Semaine"].waitForNonExistence(timeout: 3))
    }
}
