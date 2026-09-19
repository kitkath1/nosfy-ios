import XCTest

final class HistoriqueUITests: XCTestCase {
    @MainActor private func ouvrir(chambre: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-histoQA", "-demoData", "-sansServeur", "-sansSondeVol", "-woop.langue", "fr"]
        if chambre { app.launchArguments.append("-histoChambre") }
        app.launch()
        return app
    }

    @MainActor private func verifier(_ app: XCUIApplication, pieces: Int) {
        let etat = app.staticTexts["qa.historique"]
        XCTAssertTrue(etat.waitForExistence(timeout: 12))
        XCTAssertTrue(etat.label.contains("pieces=\(pieces);attente=false"), etat.label)
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "story-historique-\(pieces)"; capture.lifetime = .keepAlways; add(capture)
    }

    @MainActor func testWidgetJourUniqueOuvreSaStory() {
        let app = ouvrir(); defer { app.terminate() }
        let jour = app.buttons["historique-jour-1"]
        XCTAssertTrue(jour.waitForExistence(timeout: 30)); jour.tap()
        verifier(app, pieces: 41)
    }

    @MainActor func testWidgetDeuxSeancesChoisirLaDeuxieme() {
        let app = ouvrir(); defer { app.terminate() }
        let jour = app.buttons["historique-jour-0"]
        XCTAssertTrue(jour.waitForExistence(timeout: 30)); jour.tap()
        let choix = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "18:00")).firstMatch
        XCTAssertTrue(choix.waitForExistence(timeout: 5)); choix.tap()
        verifier(app, pieces: 73)
    }

    @MainActor func testChambreJourVidePuisDeuxSeances() {
        let app = ouvrir(chambre: true); defer { app.terminate() }
        let vide = app.descendants(matching: .any).matching(identifier: "regularite-jour-2").firstMatch
        XCTAssertTrue(vide.waitForExistence(timeout: 30)); vide.tap()
        XCTAssertFalse(app.staticTexts["qa.historique"].exists)
        let fait = app.descendants(matching: .any).matching(identifier: "regularite-jour-0").firstMatch
        XCTAssertTrue(fait.exists); fait.tap()
        let choix = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "09:00")).firstMatch
        XCTAssertTrue(choix.waitForExistence(timeout: 5)); choix.tap()
        verifier(app, pieces: 20)
    }
}
