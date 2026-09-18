import XCTest

final class HomePrenomsUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    override func tearDown() {
        XCUIApplication(bundleIdentifier: "fr.kathryn.woop").terminate()
        super.tearDown()
    }

    @MainActor
    private func verifier(_ langue: String, prenom: String, nombre: Int, capture: String) {
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
        app.launchArguments = ["-skipAuth", "-porteVue", "-sansVisite", "-sansSondeVol",
                               "-sansServeur", "-homeV2", "-phraseFige", "1",
                               "-semaineFaits", String(nombre), "-woop.langue", langue,
                               "-woop.prenom", prenom]
        app.launch()
        let phrase = app.descendants(matching: .any).matching(identifier: "home-phrase").firstMatch
        XCTAssertTrue(phrase.waitForExistence(timeout: 20))
        let salut = langue == "fr" ? "Bonjour" : "Hello"
        let semaine = langue == "fr" ? "Cette semaine," : "This week,"
        let unite = langue == "fr" ? (nombre == 1 ? "séance" : "séances")
                                   : (nombre == 1 ? "workout" : "workouts")
        XCTAssertTrue(phrase.label.hasPrefix("\(salut) \(prenom), \(semaine) \(nombre) \(unite)"), phrase.label)
        XCTAssertFalse(phrase.label.contains("Déjà"))
        // La capture attend la fin du phrasé ; le prénom et les cartes sont posés.
        Thread.sleep(forTimeInterval: 9)
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = capture
        image.lifetime = .keepAlways
        add(image)
    }

    @MainActor func testFrancaisPrenomCourt() {
        verifier("fr", prenom: "Kathryn", nombre: 1, capture: "fr-court-1-seance")
    }

    @MainActor func testFrancaisPrenomLong() {
        verifier("fr", prenom: "Anne-Charlotte", nombre: 3, capture: "fr-long-3-seances")
    }

    @MainActor func testAnglaisPrenomLong() {
        verifier("en", prenom: "Christopher-James", nombre: 1, capture: "en-long-1-workout")
    }
}
