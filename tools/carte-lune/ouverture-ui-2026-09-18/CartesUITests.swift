import XCTest

final class NavRuntimeUITests: XCTestCase {
    @MainActor private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
        app.launchArguments = ["-cartesQA", "-welcomeClaimAuto", "-skipAuth", "-porteVue", "-sansVisite", "-sansSondeVol", "-openTab", "profile", "-woop.langue", "fr"] + extra
        app.launch()
        let later = app.buttons.matching(NSPredicate(format: "label == %@ OR label == %@", "Later", "Plus tard")).firstMatch
        if later.waitForExistence(timeout: 6) {
            let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: later)
            XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 15), .completed)
        }
        return app
    }
    @MainActor private func shot(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot());a.name = name;a.lifetime = .keepAlways;add(a)
    }
    @MainActor func testADeuxPortesEtCollectionVide() throws {
        continueAfterFailure = false
        let app = launch(["-cartesExporter"]);defer { app.terminate() }
        let orange = app.buttons["profil-booster-orange"]
        XCTAssertTrue(orange.waitForExistence(timeout: 60))
        XCTAssertTrue(app.buttons["profil-booster-noir"].exists)
        XCTAssertTrue(app.staticTexts["cartes-qa-collection"].label.contains("references=0"))
        shot(app,"profil-vide-deux-stocks")
        orange.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label ==[c] %@", "ouvrir")).firstMatch.waitForExistence(timeout: 8))
        shot(app,"coffre-orange")
    }
    @MainActor func testBOrangeJusquaCollection() throws {
        continueAfterFailure = false
        let app = launch(["-boosterCine"]);defer { app.terminate() }
        XCTAssertTrue(app.buttons["profil-booster-orange"].waitForExistence(timeout: 35))
        app.buttons["profil-booster-orange"].tap()
        let ouvrir = app.buttons.matching(NSPredicate(format: "label ==[c] %@", "ouvrir")).firstMatch
        XCTAssertTrue(ouvrir.waitForExistence(timeout: 8));ouvrir.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let etat = app.staticTexts["cartes-qa-ouverture"]
        shot(app,"apres-ouvrir"); XCTAssertTrue(etat.waitForExistence(timeout: 10))
        let revelee = NSPredicate(format: "label CONTAINS %@", "revelee=true")
        expectation(for: revelee, evaluatedWith: etat)
        waitForExpectations(timeout: 50)
        XCTAssertFalse(etat.label.contains("carte=;"))
        XCTAssertFalse(etat.label.contains("rarete=common"))
        shot(app,"orange-carte-reelle")
        let retour = try XCTUnwrap(app.buttons.matching(identifier: "Retour").allElementsBoundByIndex.first(where: { $0.isHittable }))
        retour.tap()
        XCTAssertTrue(app.buttons["profil-booster-orange"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["cartes-qa-collection"].label.contains("references=1"))
        shot(app,"collection-premiere-carte")
    }
    @MainActor func testCNoirGratuitEtReconnexion() throws {
        continueAfterFailure = false
        let app = launch(["-boosterCine"]);defer { app.terminate() }
        XCTAssertTrue(app.buttons["profil-booster-noir"].waitForExistence(timeout: 35))
        app.buttons["profil-booster-noir"].tap()
        let ouvrir = app.buttons.matching(NSPredicate(format: "label ==[c] %@", "ouvrir")).firstMatch
        XCTAssertTrue(ouvrir.waitForExistence(timeout: 8));shot(app,"coffre-noir-offert");ouvrir.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let etat = app.staticTexts["cartes-qa-ouverture"]
        shot(app,"apres-ouvrir"); XCTAssertTrue(etat.waitForExistence(timeout: 10))
        expectation(for: NSPredicate(format: "label CONTAINS %@", "revelee=true"), evaluatedWith: etat)
        waitForExpectations(timeout: 50)
        XCTAssertTrue(etat.label.contains("rarete=legendary"));shot(app,"noir-legendaire-reelle")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["profil-booster-noir"].waitForExistence(timeout: 35))
        XCTAssertTrue(app.staticTexts["cartes-qa-collection"].label.contains("references=2"))
        shot(app,"collection-apres-relance")
    }
    @MainActor func testDDeuxManegesEtInterruption() throws {
        continueAfterFailure = false
        for couleur in ["orange","noir"] {
            let app = launch();defer { app.terminate() }
            XCTAssertTrue(app.buttons["profil-booster-"+couleur].waitForExistence(timeout: 35))
            app.buttons["profil-booster-"+couleur].tap()
            let ouvrir=app.buttons.matching(NSPredicate(format: "label ==[c] %@", "ouvrir")).firstMatch
            XCTAssertTrue(ouvrir.waitForExistence(timeout: 8));ouvrir.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            XCTAssertTrue(app.staticTexts["cartes-qa-ouverture"].waitForExistence(timeout: 10))
            shot(app,"manege-"+couleur)
            XCUIDevice.shared.press(.home);app.activate()
            XCTAssertFalse(app.staticTexts["cartes-qa-ouverture"].label.contains("revelee=true"))
            shot(app,"manege-"+couleur+"-reprise")
            let retour=try XCTUnwrap(app.buttons.matching(identifier:"Retour").allElementsBoundByIndex.first(where:{$0.isHittable}))
            retour.tap()
            XCTAssertTrue(app.buttons["profil-booster-"+couleur].waitForExistence(timeout: 8))
        }
    }
}
