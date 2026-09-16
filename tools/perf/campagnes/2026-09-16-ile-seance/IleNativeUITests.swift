import XCTest

/// La preuve porte sur SpringBoard : un élément de la fenêtre Woop ne peut
/// pas faire passer ces tests. Les anciennes coordonnées de la fausse île
/// n'interviennent plus dans le parcours.
final class IleNativeUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func lancer(onglet: String) -> BancPilule {
        let b = BancPilule()
        b.app.launchArguments = ["-fouettagePilule", "-skipAuth", "-porteVue", "-sansVisite",
                                 "-activeWorkout", "-openTab", onglet]
        b.app.terminate()
        b.app.launch()
        XCTAssertTrue(b.sonde.waitForExistence(timeout: 60))
        // `seance` de l'ancien banc vient de PageCard, absente sur Profil.
        // L'activité réelle sera vérifiée dans SpringBoard juste après.
        XCTAssertTrue(b.attendre(15) { $0.dansIle }, b.etat()?.brut ?? "sonde absente")
        print("ILE-NATIVE lancement \(onglet) : \(b.etat()?.brut ?? "?")")
        if onglet == "home" {
            XCTAssertTrue(b.app.buttons["ile-seance-home"].waitForExistence(timeout: 5))
        } else {
            XCTAssertTrue(b.ile.waitForExistence(timeout: 5),
                          "La Live Activity ne remplace pas le repère dans Woop")
        }
        XCTAssertFalse(b.pilule.exists, "La pastille doit commencer dans l'île système")
        capture(b.app, "app-\(onglet)-repere-seance")
        return b
    }

    private func ileSysteme() -> XCUIApplication {
        XCUIDevice.shared.press(.home)
        let systeme = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let braise = systeme.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Séance en cours")).firstMatch
        let visible = braise.waitForExistence(timeout: 12)
        let arbre = XCTAttachment(string: systeme.debugDescription)
        arbre.name = "arbre-SpringBoard"
        arbre.lifetime = .keepAlways
        add(arbre)
        capture(systeme, "ile-native-compacte")
        XCTAssertTrue(visible, "La séance n'est pas rendue par SpringBoard")
        return systeme
    }

    private func centreIle(_ systeme: XCUIApplication) -> XCUICoordinate {
        systeme.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: systeme.frame.width / 2, dy: 30))
    }

    private func capture(_ app: XCUIApplication, _ nom: String) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = nom
        image.lifetime = .keepAlways
        add(image)
    }

    func test01_agrandissementNatifPuisRetourPastilleProfil() {
        let b = lancer(onglet: "profile")
        let systeme = ileSysteme()
        centreIle(systeme).press(forDuration: 1.2)
        XCTAssertTrue(systeme.staticTexts["Séance"].waitForExistence(timeout: 6),
                      "L'appui long système n'a pas agrandi l'île")
        capture(systeme, "ile-native-agrandie")
        systeme.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        centreIle(systeme).tap()
        XCTAssertTrue(b.app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(b.attendre(10) { !$0.dansIle && $0.grandPlayer == 0 })
        XCTAssertTrue(b.pilule.waitForExistence(timeout: 5))
        capture(b.app, "retour-ile-vers-pastille")
        b.jeter(b.centrePilule(), dy: -700)
        XCTAssertTrue(b.attendre(6) { $0.dansIle })
        XCTAssertTrue(b.ile.waitForExistence(timeout: 5), "Le jet doit rendre le repère dans Woop")
        XCTAssertFalse(b.pilule.exists)
        let retour = ileSysteme()
        centreIle(retour).tap()
        XCTAssertTrue(b.app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(b.pilule.waitForExistence(timeout: 8))
        b.centrePilule().tap()
        XCTAssertTrue(b.grandPlayer.waitForExistence(timeout: 8))
    }

    func test02_homeTapNatifOuvreLeDetail() {
        let b = lancer(onglet: "home")
        let systeme = ileSysteme()
        centreIle(systeme).tap()
        XCTAssertTrue(b.app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(b.grandPlayer.waitForExistence(timeout: 10),
                      "Retour Home : \(b.etat()?.brut ?? "sonde absente")")
        XCTAssertFalse(b.pilule.exists)
        capture(b.app, "retour-ile-vers-detail-home")
    }
}
