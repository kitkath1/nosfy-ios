import XCTest

final class NavRuntimeUITests: XCTestCase {
    @MainActor private func capture(_ app: XCUIApplication, _ nom: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = nom; a.lifetime = .keepAlways; add(a)
    }
    @MainActor private func lancer(_ args: [String] = []) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
        app.launchArguments = ["-skipAuth", "-porteVue", "-sansVisite", "-sansSondeVol", "-woop.langue", "fr"] + args
        app.launch()
        return app
    }
    @MainActor func testAHomesEtEnTete() throws {
        continueAfterFailure = false
        let app = lancer()
        defer { app.terminate() }
        let phrase = app.descendants(matching: .any)["home-phrase"].firstMatch
        XCTAssertTrue(phrase.waitForExistence(timeout: 20))
        sleep(4)
        let homeY = phrase.frame.minY + 36.3 / 2
        print("AXE HOME: \(homeY), RECT: \(phrase.frame)")
        capture(app, "home-normale")
        app.buttons["Entraînements"].tap()
        let retour = app.buttons["Retour"].firstMatch
        XCTAssertTrue(retour.waitForExistence(timeout: 10))
        sleep(1)
        print("AXE CHEVRON: \(retour.frame.midY)")
        XCTAssertEqual(homeY, retour.frame.midY, accuracy: 1.0)
        capture(app, "exercices-alignement")
        retour.tap()
        XCTAssertTrue(phrase.waitForExistence(timeout: 5))
        #if targetEnvironment(simulator)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.50, dy: 0.70))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.50, dy: 0.36)))
        sleep(3)
        capture(app, "home-texte-au-slider")
        #endif
        app.terminate()
        app.launchArguments += ["-homeSeance"]
        app.launch()
        XCTAssertTrue(phrase.waitForExistence(timeout: 20))
        sleep(4)
        print("AXE HOME NOIRE: \(phrase.frame.minY + 36.3 / 2)")
        XCTAssertEqual(phrase.frame.minY + 36.3 / 2, homeY, accuracy: 1.0)
        capture(app, "home-noire")
    }
    @MainActor func testBRouteSansMenuEtRetour() throws {
        continueAfterFailure = false
        let app = lancer(["-homeChemin"])
        defer { app.terminate() }
        let chapitre = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'CHAPITRE '")).firstMatch
        XCTAssertTrue(chapitre.waitForExistence(timeout: 20))
        sleep(2)
        for nom in ["Accueil", "Entraînements", "Profil"] {
            XCTAssertFalse(app.buttons[nom].exists, "Menu interdit sur Route: \(nom)")
        }
        capture(app, "route-sans-menu")
        let retour = try XCTUnwrap(app.buttons.allElementsBoundByIndex.first {
            $0.isHittable && $0.frame.midX < 100 && $0.frame.midY < 200
        })
        retour.tap()
        XCTAssertTrue(app.buttons["Entraînements"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Entraînements"].isHittable)
        app.buttons["Entraînements"].tap()
        XCTAssertTrue(app.buttons["Retour"].firstMatch.waitForExistence(timeout: 5))
        capture(app, "navigation-apres-route")
    }
}
