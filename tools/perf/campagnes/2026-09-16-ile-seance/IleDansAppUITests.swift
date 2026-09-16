import XCTest

/// La séance doit rester accessible DANS Woop, sans passer par SpringBoard.
final class IleDansAppUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func lancer(_ onglet: String = "profile") -> BancPilule {
        let b = BancPilule()
        b.app.launchArguments = ["-fouettagePilule", "-skipAuth", "-porteVue",
                                 "-sansVisite", "-activeWorkout", "-openTab", onglet]
        b.app.terminate()
        b.app.launch()
        XCTAssertTrue(b.sonde.waitForExistence(timeout: 60))
        XCTAssertTrue(b.attendre(12) { $0.dansIle })
        if onglet != "home" { XCTAssertTrue(b.ile.waitForExistence(timeout: 8)) }
        return b
    }

    private func capture(_ b: BancPilule, _ nom: String) {
        let a = XCTAttachment(screenshot: b.app.screenshot())
        a.name = nom
        a.lifetime = .keepAlways
        add(a)
    }

    func test01_reperePresentPuisTapDetailSansQuitterWoop() {
        let b = lancer()
        XCTAssertFalse(b.pilule.exists)
        let chrono = b.app.staticTexts["seance-ile-chrono"]
        let stop = b.app.buttons["seance-ile-stop"]
        XCTAssertTrue(chrono.exists)
        XCTAssertTrue(stop.exists)
        XCTAssertLessThan(chrono.frame.maxX, b.app.frame.midX - 63)
        XCTAssertGreaterThan(stop.frame.minX, b.app.frame.midX + 63)
        XCTAssertLessThan(chrono.frame.midY, 48)
        XCTAssertLessThan(stop.frame.midY, 48)
        capture(b, "repere-profil")
        b.centreIle().tap()
        XCTAssertTrue(b.attendre(6) { !$0.dansIle && $0.pose })
        XCTAssertTrue(b.pilule.waitForExistence(timeout: 5))
        capture(b, "pastille-sortie-profil")
        b.centrePilule().tap()
        XCTAssertTrue(b.grandPlayer.waitForExistence(timeout: 6))
        capture(b, "detail-depuis-pastille")
    }

    func test02_dragPoseJetEtRecuperation() {
        let b = lancer("exercises")
        b.glisser(b.pointEcran(x: b.app.frame.midX - 96, y: 33), dy: 220)
        XCTAssertTrue(b.attendre(6) { !$0.dansIle && $0.pose })
        XCTAssertTrue(b.pilule.waitForExistence(timeout: 5))
        let depart = b.pilule.frame.midY
        b.glisser(b.centrePilule(), dy: 160)
        XCTAssertTrue(b.attendre(5) { !$0.dansIle && $0.pose })
        XCTAssertGreaterThan(b.pilule.frame.midY, depart + 90)
        b.jeter(b.centrePilule(), dy: -700)
        XCTAssertTrue(b.attendre(6) { $0.dansIle })
        XCTAssertTrue(b.ile.waitForExistence(timeout: 5))
        capture(b, "retour-dans-repere")
        b.centreIle().tap()
        XCTAssertTrue(b.pilule.waitForExistence(timeout: 6))
    }

    func test03_stopDuRepereRepond() {
        let b = lancer("exercises")
        let avant = b.etat()?.nbStop ?? -1
        let stop = b.app.buttons["seance-ile-stop"]
        XCTAssertTrue(stop.exists)
        b.pointEcran(x: stop.frame.midX, y: stop.frame.midY).tap()
        XCTAssertTrue(b.attendre(6) { $0.nbStop > avant })
        XCTAssertTrue(b.etat()?.dansIle == true)
        capture(b, "stop-depuis-repere")
    }

    func test04_homeTapOuvreLeDetail() {
        let b = lancer("home")
        XCTAssertTrue(b.app.buttons["ile-seance-home"].waitForExistence(timeout: 5))
        XCTAssertFalse(b.pilule.exists)
        capture(b, "repere-home")
        b.pointEcran(x: b.app.frame.midX, y: 57).tap()
        XCTAssertTrue(b.grandPlayer.waitForExistence(timeout: 6))
        capture(b, "detail-depuis-home")
    }
}
