import XCTest

final class CountdownUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func lancer(_ args: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-skipAuth", "-porteVue", "-sansVisite", "-sansSondeVol"] + args
        app.terminate()
        app.launch()
        return app
    }

    private func attendre(_ secondes: TimeInterval, _ condition: @escaping () -> Bool) -> Bool {
        XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in condition() }, object: nil)],
            timeout: secondes) == .completed
    }

    private func capturer(_ app: XCUIApplication, _ nom: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = nom
        a.lifetime = .keepAlways
        add(a)
    }

    func test01_finNaturelleEtRelecture() {
        let app = lancer(["-countLab", "-sansServeur"])
        defer { app.terminate() }
        let film = app.buttons["depart-compte-rebours"]
        XCTAssertTrue(film.waitForExistence(timeout: 15))
        capturer(app, "count-film")
        let rejouer = app.buttons["depart-rejouer"]
        XCTAssertTrue(rejouer.waitForExistence(timeout: 12))
        XCTAssertFalse(film.exists)
        rejouer.tap()
        XCTAssertTrue(film.waitForExistence(timeout: 3))
        XCTAssertTrue(rejouer.waitForExistence(timeout: 10))
    }

    func test02_tapPuisPauseArrierePlan() {
        let app = lancer(["-countLab", "-sansServeur"])
        defer { app.terminate() }
        let film = app.buttons["depart-compte-rebours"]
        let rejouer = app.buttons["depart-rejouer"]
        XCTAssertTrue(film.waitForExistence(timeout: 15))
        film.tap()
        XCTAssertTrue(rejouer.waitForExistence(timeout: 3))
        rejouer.tap()
        XCTAssertTrue(film.waitForExistence(timeout: 3))
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 7)
        app.activate()
        XCTAssertTrue(film.waitForExistence(timeout: 2), "Le film doit reprendre sa lecture suspendue")
        XCTAssertTrue(rejouer.waitForExistence(timeout: 10))
    }

    func test03_startRouteFilmPuisExercicesUneSeuleSeance() {
        // Compte QA existant ; aucune séance semée par -activeWorkout.
        let app = lancer(["-countProbe", "-sessionBanc", "-homeChemin", "-duoEtape", "0"])
        defer { app.terminate() }
        let sonde = app.staticTexts["count-state"]
        XCTAssertTrue(sonde.waitForExistence(timeout: 25))
        XCTAssertTrue(sonde.label.contains("actives=0"), sonde.label)
        let start = app.buttons["Start"].firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 25))
        capturer(app, "route-avant-start")
        start.doubleTap()
        let film = app.buttons["depart-compte-rebours"]
        XCTAssertTrue(film.waitForExistence(timeout: 4))
        capturer(app, "route-countdown")
        XCTAssertTrue(attendre(12) { !film.exists && sonde.label.contains("film=0") })
        XCTAssertTrue(sonde.label.contains("actives=1"), sonde.label)
        XCTAssertTrue(sonde.label.contains("page=exercises"), sonde.label)
        capturer(app, "route-arrivee-exercices")
        print("WOOP_COUNT_ETAT=\(sonde.label)")
        // L'envoi serveur est indépendant de l'image. La vérification REST
        // lit ensuite précisément cet UUID et nettoie cette seule ligne QA.
        Thread.sleep(forTimeInterval: 8)
        XCTAssertTrue(sonde.label.contains("actives=1"), sonde.label)
    }

    func test04_startSansSondePuisRepriseSansDoublon() {
        // Le test03 a laissé une séance locale. Pas de sonde count-state :
        // sa lecture de filmDepart masquait le défaut de montage du lecteur.
        let app = lancer(["-sansServeur", "-homeChemin", "-duoEtape", "2"])
        defer { app.terminate() }
        let start = app.buttons["Start"].firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 25))
        start.tap()
        let film = app.buttons["depart-compte-rebours"]
        XCTAssertTrue(film.waitForExistence(timeout: 4))
        capturer(app, "depart-sans-sonde")
        XCTAssertTrue(film.waitForNonExistence(timeout: 12))
        XCTAssertTrue(app.buttons["Entraînements"].isSelected)
        capturer(app, "exercices-apres-film-sans-sonde")

        // Relire le même contexte ensuite, quand le lecteur est démonté.
        app.terminate()
        app.launchArguments += ["-countProbe"]
        app.launch()
        let sonde = app.staticTexts["count-state"]
        XCTAssertTrue(sonde.waitForExistence(timeout: 25))
        XCTAssertTrue(sonde.label.contains("actives=1"), sonde.label)
    }
}
