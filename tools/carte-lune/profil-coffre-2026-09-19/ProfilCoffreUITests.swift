import XCTest

final class NavRuntimeUITests: XCTestCase {
    @MainActor private func launch(_ extra: [String] = [], langue: String = "fr") -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
        app.launchArguments = ["-cartesQA", "-skipAuth", "-porteVue", "-sansVisite", "-sansSondeVol", "-openTab", "profile", "-woop.langue", langue] + extra
        app.launch()
        XCTAssertTrue(app.buttons["profil-booster-orange"].waitForExistence(timeout: 30))
        return app
    }
    @MainActor private func shot(_ app: XCUIApplication, _ nom: String) {
        let a = XCTAttachment(screenshot: app.screenshot()); a.name = nom; a.lifetime = .keepAlways; add(a)
    }
    @MainActor private func ouvrir(_ app: XCUIApplication, noir: Bool = false) {
        app.buttons[noir ? "profil-booster-noir" : "profil-booster-orange"].tap()
        let bouton = app.buttons.matching(NSPredicate(format: "label ==[c] %@", "ouvrir")).firstMatch
        XCTAssertTrue(bouton.waitForExistence(timeout: 12))
        bouton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["cartes-qa-ouverture"].waitForExistence(timeout: 12))
    }
    @MainActor private func revelation(_ app: XCUIApplication) {
        let e = app.staticTexts["cartes-qa-ouverture"]
        let attente = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", "revelee=true"), object: e)
        XCTAssertEqual(XCTWaiter.wait(for: [attente], timeout: 60), .completed)
        XCTAssertFalse(e.label.contains("carte=;"))
    }
    @MainActor private func envol(_ app: XCUIApplication) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)).press(forDuration: 0.05,
            thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)), withVelocity: .fast, thenHoldForDuration: 0.05)
        XCTAssertTrue(app.buttons["profil-booster-orange"].waitForExistence(timeout: 15))
    }
    @MainActor func testAProfilEtQuatrePagesCoffre() throws {
        for langue in ["fr", "en"] {
            let app = launch(langue: langue)
            XCTAssertFalse(app.buttons["▶ Nosfy"].exists)
            XCTAssertFalse(app.buttons["Nosfy Start"].exists)
            let noms = ["Une Lune", "Deux Lunes", "Trois Lunes", "Quatre Lunes"]
            let origine = app.staticTexts[noms[0]].frame.minX
            for nom in noms {
                let titre = app.staticTexts[nom]
                if !titre.isHittable { app.swipeUp() }
                XCTAssertEqual(titre.frame.minX, origine, accuracy: 1, nom)
            }
            shot(app, "profil-aligne-" + langue)
            app.terminate()
            let pages: [(String, String, String)] = [
                ("profil-booster-orange", "Booster Lune", "Lune Booster"),
                ("profil-booster-noir", "Booster légendaire", "Legendary Booster"),
                ("argent", "Pièce d'argent", "Silver Coin"),
                ("or", "Pièce d'or", "Gold Coin")]
            for (id, fr, en) in pages {
                let page = launch(langue: langue)
                let pill: XCUIElement
                if id == "argent" {
                    pill = page.buttons.matching(NSPredicate(format: "label CONTAINS %@", langue == "fr" ? "pièces d'argent" : "silver coins")).firstMatch
                } else if id == "or" {
                    pill = page.buttons.matching(NSPredicate(format: "label CONTAINS %@", langue == "fr" ? "pièces —" : "coins —")).firstMatch
                } else { pill = page.buttons[id] }
                pill.tap()
                XCTAssertTrue(page.staticTexts[langue == "fr" ? fr : en].waitForExistence(timeout: 12))
                sleep(5)
                shot(page, "coffre-" + id + "-" + langue)
                page.terminate()
            }
        }
    }
    @MainActor func testBReessayerApresReponsePerdue() throws {
        let app = launch(["-boosterCine", "-cartesQACoupure"]); defer { app.terminate() }
        ouvrir(app)
        XCTAssertTrue(app.buttons["Réessayer"].waitForExistence(timeout: 45))
        XCTAssertFalse(app.staticTexts["cartes-qa-ouverture"].label.contains("revelee=true"))
        shot(app, "orange-reponse-perdue")
        app.buttons["Réessayer"].tap()
        revelation(app); shot(app, "orange-reprise-reelle"); envol(app)
        XCTAssertTrue(app.staticTexts["cartes-qa-collection"].label.contains("references=1;exemplaires=1"))
        shot(app, "orange-un-seul-exemplaire")
    }
    @MainActor func testCRelanceApresReponsePerdueNoir() throws {
        let app = launch(["-boosterCine", "-cartesQACoupure"])
        ouvrir(app, noir: true)
        XCTAssertTrue(app.buttons["Réessayer"].waitForExistence(timeout: 45))
        shot(app, "noir-reponse-perdue")
        app.terminate()
        let reprise = launch(["-boosterCine"]); defer { reprise.terminate() }
        ouvrir(reprise, noir: true); revelation(reprise)
        XCTAssertTrue(reprise.staticTexts["cartes-qa-ouverture"].label.contains("rarete=legendary"))
        shot(reprise, "noir-meme-sachet-apres-relance"); envol(reprise)
        XCTAssertTrue(reprise.staticTexts["cartes-qa-collection"].label.contains("exemplaires=2"))
    }
}
