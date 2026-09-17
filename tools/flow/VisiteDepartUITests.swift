import XCTest

final class VisiteDepartUITests: XCTestCase {
    override func setUpWithError() throws {
        #if !targetEnvironment(simulator)
        throw XCTSkip("Banc réservé au simulateur : préparation de données locales de test")
        #endif
        continueAfterFailure = false
    }

    private func lancer(_ args: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-skipAuth", "-porteVue", "-sansSondeVol", "-sansServeur"] + args
        app.terminate()
        app.launch()
        return app
    }

    private func capturer(_ app: XCUIApplication, _ nom: String) {
        if nom.hasPrefix("visite-") || nom == "profil-visite-blanc" {
            Thread.sleep(forTimeInterval: 1.5) // laisser finir le phrasé avant la capture
        }
        let piece = XCTAttachment(screenshot: app.screenshot())
        piece.name = nom
        piece.lifetime = .keepAlways
        add(piece)
    }

    func test01_routeFilmPuisInvitationFrancaiseEtPasser() {
        let app = lancer(["-sansVisite", "-homeChemin", "-duoEtape", "2", "-woop.langue", "fr", "-exosCards"])
        defer { app.terminate() }
        let start = app.buttons["Start"].firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 15))
        capturer(app, "start-des-arrivee")
        start.tap()
        let film = app.buttons["depart-compte-rebours"]
        XCTAssertTrue(film.waitForExistence(timeout: 4))
        XCTAssertTrue(film.waitForNonExistence(timeout: 12))
        let titre = app.descendants(matching: .any)["visite-exercice-titre"]
        XCTAssertTrue(titre.waitForExistence(timeout: 4))
        XCTAssertEqual(titre.label, "Choisissez un exercice")
        capturer(app, "visite-exercice-fr")
        let passer = app.buttons["visite-exercice-passer"]
        XCTAssertEqual(passer.label, "Passer")
        passer.tap()
        XCTAssertTrue(passer.waitForNonExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Entraînements"].isSelected)
        app.buttons["Accueil"].tap()
        app.buttons["Entraînements"].tap()
        XCTAssertFalse(passer.exists, "Un simple retour d'onglet ne rejoue pas le guide")
    }

    func test02_carteAnglaiseTappableDansLaFenetre() {
        let app = lancer(["-sansVisite", "-openTab", "exercises", "-tutoExos", "-woop.langue", "en", "-exosCards"])
        defer { app.terminate() }
        let titre = app.descendants(matching: .any)["visite-exercice-titre"]
        XCTAssertTrue(titre.waitForExistence(timeout: 15))
        XCTAssertEqual(titre.label, "Choose an exercise")
        XCTAssertEqual(app.buttons["visite-exercice-passer"].label, "Skip")
        capturer(app, "visite-exercice-en")
        let carte = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'exercice-'")).firstMatch
        XCTAssertTrue(carte.isHittable)
        carte.tap()
        XCTAssertTrue(titre.waitForNonExistence(timeout: 3))
        XCTAssertTrue(carte.waitForNonExistence(timeout: 3), "La vraie fiche doit remplacer la grille")
        capturer(app, "fiche-depuis-guide")
    }

    func test03_invitationRespecteLeModeListe() {
        let app = lancer(["-sansVisite", "-openTab", "exercises", "-tutoExos", "-woop.langue", "en", "-exosListe"])
        defer { app.terminate() }
        let passer = app.buttons["visite-exercice-passer"]
        XCTAssertTrue(passer.waitForExistence(timeout: 15))
        capturer(app, "visite-exercice-liste")
        passer.tap()
        XCTAssertTrue(passer.waitForNonExistence(timeout: 2))
    }

    func test04_profilResteTappablePendantLaVisite() {
        let app = lancer(["-openTab", "home", "-visiteHome", "3", "-woop.langue", "fr", "-fermeSeances"])
        defer { app.terminate() }
        let passer = app.buttons["Passer"]
        XCTAssertTrue(passer.waitForExistence(timeout: 15))
        capturer(app, "profil-visite-blanc")
        Thread.sleep(forTimeInterval: 0.65)
        capturer(app, "profil-visite-souffle")
        let profil = app.buttons["Profil"].firstMatch
        XCTAssertTrue(profil.isHittable)
        profil.tap()
        XCTAssertTrue(passer.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Réglages"].waitForExistence(timeout: 3))
    }
    func test05_visiteDepuisLePremierTempsJusquAuProfil() {
        let app = lancer(["-openTab", "home", "-visiteHome", "1", "-woop.langue", "fr", "-fermeSeances"])
        defer { app.terminate() }
        XCTAssertTrue(app.staticTexts["Commencer."].waitForExistence(timeout: 15))
        let horsPoche = app.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.18))
        horsPoche.tap()
        XCTAssertTrue(app.staticTexts["progrès."].waitForExistence(timeout: 5))
        horsPoche.tap()
        XCTAssertTrue(app.staticTexts["profil."].waitForExistence(timeout: 5))
        capturer(app, "profil-apres-deux-etapes")
        app.buttons["Profil"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Passer"].waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Réglages"].waitForExistence(timeout: 3))
    }

}
