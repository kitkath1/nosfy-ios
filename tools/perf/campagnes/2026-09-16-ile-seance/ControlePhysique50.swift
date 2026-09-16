import XCTest

final class NavRuntimeUITests: XCTestCase {
    @MainActor
    func testIleNativeSurSeanceExistante() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
        XCTAssertNotEqual(app.state, .notRunning)
        app.activate()
        if app.buttons["Later"].waitForExistence(timeout: 3) { app.buttons["Later"].tap() }
        Thread.sleep(forTimeInterval: 3)
        func capture(_ cible: XCUIApplication, _ nom: String) {
            let shot = XCTAttachment(screenshot: cible.screenshot())
            shot.name = nom
            shot.lifetime = .keepAlways
            add(shot)
            let tree = XCTAttachment(string: cible.debugDescription)
            tree.name = nom + "-arbre"
            tree.lifetime = .keepAlways
            add(tree)
        }
        capture(app, "physique47-home-avant")
        XCUIDevice.shared.press(.home)
        let systeme = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let braise = systeme.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Séance en cours")).firstMatch
        let visible = braise.waitForExistence(timeout: 10)
        capture(systeme, "physique47-compacte")
        guard visible else {
            app.activate()
            throw XCTSkip("Aucune activité native visible ; aucune séance créée par le banc.")
        }
        let centre = systeme.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: systeme.frame.width / 2, dy: 30))
        centre.press(forDuration: 1.2)
        XCTAssertTrue(systeme.staticTexts["Séance"].waitForExistence(timeout: 6))
        capture(systeme, "physique47-agrandie")
        systeme.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        centre.tap()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        Thread.sleep(forTimeInterval: 3)
        capture(app, "physique47-retour-home")
        print("WOOP_ILE47_PHYSIQUE_AFFICHAGE_EXPANSION_RETOUR_OK")
    }

    @MainActor
    func testRepereDansWoopSurSeanceExistante() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
        app.activate()
        Thread.sleep(forTimeInterval: 3)
        func element(_ id: String) -> XCUIElement {
            app.descendants(matching: .any).matching(identifier: id).firstMatch
        }
        func point(_ x: CGFloat, _ y: CGFloat) -> XCUICoordinate {
            app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y))
        }
        func capture(_ nom: String) {
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = nom
            shot.lifetime = .keepAlways
            add(shot)
        }
        let home = app.buttons["ile-seance-home"]
        let ile = element("seance-ile")
        let pastille = element("seance-pastille")
        let detail = element("seance-detail")
        capture("physique-repere-depart")
        if !home.exists && !ile.exists && !pastille.exists && !detail.exists {
            if app.staticTexts["pull to start"].isHittable {
                throw XCTSkip("Home sans séance active ; aucune séance créée par le banc.")
            }
            XCTFail("Le repère de séance est absent dans l'état observé.")
            return
        }
        if home.exists {
            point(app.frame.midX, 57).tap()
            XCTAssertTrue(detail.waitForExistence(timeout: 7))
            capture("physique-detail-depuis-home")
            app.staticTexts["Page exercices"].firstMatch.tap()
        }
        XCTAssertTrue(ile.waitForExistence(timeout: 8))
        capture("physique-repere-exercices")
        point(app.frame.midX, 57).tap()
        XCTAssertTrue(pastille.waitForExistence(timeout: 7))
        Thread.sleep(forTimeInterval: 1)
        capture("physique-pastille-sortie")
        let depart = pastille.frame
        point(depart.midX, depart.midY).press(forDuration: 0.08,
            thenDragTo: point(depart.midX, depart.midY - 150),
            withVelocity: .slow, thenHoldForDuration: 0.25)
        Thread.sleep(forTimeInterval: 1)
        XCTAssertTrue(pastille.exists)
        let pose = pastille.frame
        XCTAssertLessThan(pose.midY, depart.midY - 70)
        point(pose.midX, pose.midY).press(forDuration: 0.02,
            thenDragTo: point(pose.midX, 10),
            withVelocity: 2400, thenHoldForDuration: 0)
        XCTAssertTrue(ile.waitForExistence(timeout: 7))
        point(app.frame.midX, 57).tap()
        XCTAssertTrue(pastille.waitForExistence(timeout: 7))
        Thread.sleep(forTimeInterval: 1)
        point(pastille.frame.midX, pastille.frame.midY).tap()
        XCTAssertTrue(detail.waitForExistence(timeout: 7))
        capture("physique-detail-depuis-pastille")
    }

    /// Le lab utilise le vrai composant sans créer de séance dans le compte.
    @MainActor
    func testGestesDuComposantSurIPhone() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
        app.launchArguments = ["-piluleLab", "-sondeVol", "-ecranEveille"]
        app.launch()
        func element(_ id: String) -> XCUIElement {
            app.descendants(matching: .any).matching(identifier: id).firstMatch
        }
        func point(_ x: CGFloat, _ y: CGFloat) -> XCUICoordinate {
            app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y))
        }
        func capture(_ nom: String) {
            let a = XCTAttachment(screenshot: app.screenshot())
            a.name = nom
            a.lifetime = .keepAlways
            add(a)
        }
        let pilule = element("seance-pastille")
        let ile = element("seance-ile")
        XCTAssertTrue(app.staticTexts["In session · 7 min"].waitForExistence(timeout: 15))
        XCTAssertTrue(pilule.waitForExistence(timeout: 5))
        let debut = pilule.frame
        point(debut.midX, debut.midY).press(forDuration: 0.02,
            thenDragTo: point(debut.midX, 5), withVelocity: 2400, thenHoldForDuration: 0)
        XCTAssertTrue(ile.waitForExistence(timeout: 7))
        Thread.sleep(forTimeInterval: 2)
        let chrono = element("seance-ile-chrono")
        let stop = element("seance-ile-stop")
        XCTAssertTrue(chrono.exists)
        XCTAssertTrue(stop.exists)
        XCTAssertLessThan(chrono.frame.maxX, app.frame.midX - 63)
        XCTAssertGreaterThan(stop.frame.minX, app.frame.midX + 63)
        XCTAssertLessThan(chrono.frame.midY, 48)
        XCTAssertLessThan(stop.frame.midY, 48)
        capture("composant-iphone-repere-1")
        Thread.sleep(forTimeInterval: 1)
        capture("composant-iphone-repere-2")
        print("WOOP_REPERE_PALIER_DEBUT")
        Thread.sleep(forTimeInterval: 25)
        print("WOOP_REPERE_PALIER_FIN")
        point(app.frame.midX, 57).tap()
        XCTAssertTrue(pilule.waitForExistence(timeout: 7))
        Thread.sleep(forTimeInterval: 2)
        capture("composant-iphone-sortie-tap")
        let pose = pilule.frame
        point(pose.midX, pose.midY).press(forDuration: 0.08,
            thenDragTo: point(pose.midX, pose.midY - 150),
            withVelocity: .slow, thenHoldForDuration: 0.3)
        Thread.sleep(forTimeInterval: 1.5)
        XCTAssertTrue(pilule.exists)
        XCTAssertLessThan(pilule.frame.midY, pose.midY - 70)
        let haut = pilule.frame
        point(haut.midX, haut.midY).press(forDuration: 0.02,
            thenDragTo: point(haut.midX, 5), withVelocity: 2400, thenHoldForDuration: 0)
        XCTAssertTrue(ile.waitForExistence(timeout: 7))
        point(app.frame.midX, 57).press(forDuration: 0.08,
            thenDragTo: point(app.frame.midX, 270),
            withVelocity: .slow, thenHoldForDuration: 0.3)
        XCTAssertTrue(pilule.waitForExistence(timeout: 7))
        Thread.sleep(forTimeInterval: 2)
        capture("composant-iphone-sortie-drag")
        point(pilule.frame.midX, pilule.frame.midY).tap()
        XCTAssertTrue(element("seance-detail").waitForExistence(timeout: 7))
        capture("composant-iphone-detail")
    }

    @MainActor
    func testHomeDuComposantSurIPhone() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
        app.launchArguments = ["-piluleLab", "-piluleLabHome", "-sondeVol", "-ecranEveille"]
        app.terminate()
        app.launch()
        let home = app.buttons["ile-seance-home"]
        XCTAssertTrue(home.waitForExistence(timeout: 15))
        Thread.sleep(forTimeInterval: 20)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "composant-home-halo-blanc"
        shot.lifetime = .keepAlways
        add(shot)
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: app.frame.midX, dy: 57)).tap()
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(identifier: "seance-detail").firstMatch.waitForExistence(timeout: 7))
    }

    @MainActor
    func testCaptureNormale() throws {
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
        XCTAssertNotEqual(app.state, .notRunning)
        app.activate()
        Thread.sleep(forTimeInterval: 3)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "physique47-normale"
        shot.lifetime = .keepAlways
        add(shot)
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "physique47-normale-arbre"
        tree.lifetime = .keepAlways
        add(tree)
    }
}
