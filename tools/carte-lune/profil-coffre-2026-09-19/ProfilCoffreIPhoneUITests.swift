import XCTest

final class NavRuntimeUITests: XCTestCase {
    @MainActor private func attendre(_ secondes: Int, app: XCUIApplication, nom: String) throws {
        print("FENETRE \(nom) DEBUT \(Date())")
        for _ in 0..<secondes / 5 {
            sleep(5)
            let niveau = ProcessInfo.processInfo.thermalState.rawValue
            print("THERMIQUE \(niveau) \(Date())")
            if niveau >= 2 { app.terminate(); throw XCTSkip("Arrêt thermique serious : endurance non validée") }
            if app.state != .runningForeground { app.terminate(); throw XCTSkip("App hors premier plan : mesure interrompue") }
        }
        print("FENETRE \(nom) FIN \(Date())")
    }
    @MainActor private func shot(_ app: XCUIApplication, _ nom: String) {
        let a = XCTAttachment(screenshot: app.screenshot()); a.name = nom; a.lifetime = .keepAlways; add(a)
    }
    @MainActor private func retour(_ app: XCUIApplication) throws {
        let b = try XCTUnwrap(app.buttons.matching(identifier: "Retour").allElementsBoundByIndex.first(where: { $0.isHittable }))
        b.tap()
    }
    @MainActor func testProfilCoffreEtRecuperation() throws {
        continueAfterFailure = false
        guard ProcessInfo.processInfo.thermalState == .nominal else { throw XCTSkip("Départ nominal requis") }
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop"); defer { app.terminate() }
        app.launchArguments = ["-skipAuth", "-porteVue", "-sansVisite", "-sondeVol", "-navProbe", "-ecranEveille", "-openTab", "profile", "-woop.langue", "fr"]
        app.launch()
        let later = app.buttons.matching(NSPredicate(format: "label == %@ OR label == %@", "Later", "Plus tard")).firstMatch
        if later.waitForExistence(timeout: 5) { later.tap() }
        XCTAssertTrue(app.staticTexts["Cartes collectées"].waitForExistence(timeout: 20))
        XCTAssertFalse(app.buttons["▶ Nosfy"].exists)
        XCTAssertEqual(app.staticTexts["Une Lune"].frame.minX, app.staticTexts["Deux Lunes"].frame.minX, accuracy: 1)
        shot(app, "iphone-profil-aligne")
        try attendre(120, app: app, nom: "profil-normal")
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "pièces —")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Pièce d'or"].waitForExistence(timeout: 12))
        shot(app, "iphone-coffre-or")
        try attendre(120, app: app, nom: "coffre-projecteur")
        XCUIDevice.shared.press(.home); sleep(3); app.activate()
        try attendre(15, app: app, nom: "coffre-reprise")
        try retour(app)
        XCTAssertTrue(app.staticTexts["Cartes collectées"].waitForExistence(timeout: 10))
        try retour(app)
        try attendre(120, app: app, nom: "home-recuperation")
        shot(app, "iphone-home-recuperation")
    }
    @MainActor func testProfilPoseGestes() throws {
        continueAfterFailure = false
        guard ProcessInfo.processInfo.thermalState.rawValue < 2 else { throw XCTSkip("Repos thermique requis") }
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop"); defer { app.terminate() }
        app.launchArguments = ["-skipAuth", "-porteVue", "-sansVisite", "-navProbe", "-sondeVol", "-ecranEveille", "-openTab", "profile", "-profilRepos", "-woop.langue", "fr"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Cartes collectées"].waitForExistence(timeout: 20))
        try attendre(15, app: app, nom: "profil-pose")
        shot(app, "iphone-profil-pose")
        let crete = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.90))
        crete.tap()
        let back = app.buttons.matching(NSPredicate(format: "label ==[c] %@", "retour")).firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 6)); shot(app, "iphone-panneau-pose")
        back.tap(); sleep(2)
        crete.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.62)))
        XCTAssertTrue(back.waitForExistence(timeout: 6)); back.tap()
        XCUIDevice.shared.press(.home); sleep(2); app.activate()
        try attendre(10, app: app, nom: "profil-pose-reprise")
        shot(app, "iphone-profil-pose-reprise")
    }
}
