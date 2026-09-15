import XCTest

final class NavRuntimeUITests: XCTestCase {
    @MainActor
    func testRetourPullEtChapitre() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
        app.activate()
        if app.buttons["Later"].exists { app.buttons["Later"].tap() }
        let dossier = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let invite = app.staticTexts["pull to start"]
        XCTAssertTrue(invite.waitForExistence(timeout: 5))
        for i in 0..<12 {
            try app.screenshot().pngRepresentation.write(to: dossier.appendingPathComponent("chapitre31-\(i).png"))
            Thread.sleep(forTimeInterval: 0.35)
        }
        for cycle in 0..<3 {
            XCTAssertTrue(invite.isHittable)
            invite.tap()
            Thread.sleep(forTimeInterval: 2.2)
            try app.screenshot().pngRepresentation.write(to: dossier.appendingPathComponent("pull31-ouvert-\(cycle).png"))
            let debut = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.23))
            let fin = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.53))
            debut.press(forDuration: 0.08, thenDragTo: fin, withVelocity: .slow, thenHoldForDuration: 0)
            Thread.sleep(forTimeInterval: 1.4)
            XCTAssertTrue(invite.waitForExistence(timeout: 5))
            XCTAssertTrue(invite.isHittable)
            try app.screenshot().pngRepresentation.write(to: dossier.appendingPathComponent("pull31-retour-\(cycle).png"))
        }
        app.buttons["person"].tap()
        XCTAssertTrue(app.buttons["Réglages"].waitForExistence(timeout: 5))
        app.buttons["Retour"].tap()
        XCTAssertTrue(invite.waitForExistence(timeout: 5))
        print("WOOP_RETOURS_PULL_CHAPITRE_OK")
    }

    @MainActor
    func testAllersRetoursMesures() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
        app.activate()
        if app.buttons["Later"].exists { app.buttons["Later"].tap() }
        for cycle in 0..<4 {
            XCTAssertTrue(app.buttons["figure.strengthtraining.functional"].waitForExistence(timeout: 5))
            app.buttons["figure.strengthtraining.functional"].tap()
            XCTAssertTrue(app.staticTexts["Exercices"].waitForExistence(timeout: 5))
            app.swipeUp()
            app.buttons["house.fill"].tap()
            XCTAssertTrue(app.buttons["person"].waitForExistence(timeout: 5))
            app.buttons["person"].tap()
            XCTAssertTrue(app.buttons["Réglages"].waitForExistence(timeout: 5))
            app.swipeUp()
            app.swipeDown()
            XCTAssertTrue(app.buttons["Retour"].waitForExistence(timeout: 5))
            app.buttons["Retour"].tap()
            XCTAssertTrue(app.buttons["person"].waitForExistence(timeout: 5))
            print("WOOP_ALLER_RETOUR_\(cycle)_OK")
        }
    }

    @MainActor
    func testCapturerInvitation() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
        XCTAssertNotEqual(app.state, .notRunning)
        app.activate()
        let invite = app.staticTexts["pull to start"]
        XCTAssertTrue(invite.waitForExistence(timeout: 5))
        XCTAssertTrue(invite.isHittable)
        let dossier = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let r = invite.frame
        let a = app.frame
        let cadre: [String: Double] = ["x":r.minX, "y":r.minY, "w":r.width, "h":r.height, "appW":a.width, "appH":a.height]
        try JSONSerialization.data(withJSONObject: cadre, options: [.prettyPrinted]).write(to: dossier.appendingPathComponent("invite-cadre.json"))
        for i in 0..<8 {
            try app.screenshot().pngRepresentation.write(to: dossier.appendingPathComponent("invite-\(i).png"), options: .atomic)
            Thread.sleep(forTimeInterval: 0.18)
        }
        print("WOOP_INVITATION_CAPTUREE_SANS_APPUI")
    }

    @MainActor
    func testOuvrirBancCoutHome() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
        app.launchArguments = ["-sansSondeVol", "-ecranEveille", "-navProbe", "-bancCoutHome", "-openTab", "home"]
        app.launch()
        XCTAssertTrue(app.buttons["person"].waitForExistence(timeout: 15))
        print("WOOP_BANC_COUT_HOME_OUVERT")
    }

    @MainActor
    func testOuvrirHomeEveillee() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
        app.launchArguments = ["-sansSondeVol", "-ecranEveille", "-navProbe", "-openTab", "home"]
        app.launch()
        XCTAssertTrue(app.buttons["person"].waitForExistence(timeout: 15))
        print("WOOP_HOME_EVEILLEE")
    }

    @MainActor
    func testEcranNuPretPourMesure() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
        XCTAssertNotEqual(app.state, .notRunning)
        app.activate()
        if app.buttons["Later"].exists {
            app.buttons["Later"].tap()
            XCTAssertTrue(app.buttons["Later"].waitForNonExistence(timeout: 5))
        }
        XCTAssertFalse(app.buttons["person"].exists)
        XCTAssertFalse(app.buttons["Réglages"].exists)
        let dossier = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try app.screenshot().pngRepresentation.write(to: dossier.appendingPathComponent("ecran-nu.png"), options: .atomic)
        print("WOOP_ECRAN_NU_PRET")
    }

    @MainActor
    func testRemonterProfil() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
        XCTAssertNotEqual(app.state, .notRunning)
        app.activate()
        XCTAssertTrue(app.buttons["Réglages"].waitForExistence(timeout: 5))
        let rangee = app.staticTexts["Deux Lunes"]
        XCTAssertTrue(rangee.exists)
        let avant = rangee.frame.minY
        app.swipeDown()
        XCTAssertGreaterThan(rangee.frame.minY, avant + 100, "Le contenu doit réellement remonter")
        let dossier = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try app.screenshot().pngRepresentation.write(to: dossier.appendingPathComponent("profil-retour-sommet.png"), options: .atomic)
        print("WOOP_PROFIL_REMONTE_OK")
    }

    @MainActor
    func testHomePretePourMesure() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
        XCTAssertNotEqual(app.state, .notRunning)
        app.activate()
        if app.buttons["Later"].exists {
            app.buttons["Later"].tap()
            XCTAssertTrue(app.buttons["Later"].waitForNonExistence(timeout: 5))
        }
        XCTAssertTrue(app.buttons["person"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["person"].isHittable)
        let dossier = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try app.screenshot().pngRepresentation.write(to: dossier.appendingPathComponent("home-mesure.png"), options: .atomic)
        print("WOOP_HOME_PRETE_MESURE")
    }

    @MainActor
    func testNavigationApresRelance() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
        XCTAssertNotEqual(app.state, .notRunning)
        app.activate()
        if app.buttons["Later"].exists { app.buttons["Later"].tap() }
        let exercices = app.buttons["figure.strengthtraining.functional"]
        XCTAssertTrue(exercices.waitForExistence(timeout: 5))
        exercices.tap()
        XCTAssertTrue(app.staticTexts["Exercices"].waitForExistence(timeout: 5))
        app.buttons["house.fill"].tap()
        app.buttons["person"].tap()
        XCTAssertTrue(app.buttons["Réglages"].waitForExistence(timeout: 5))
        app.buttons["Réglages"].tap()
        XCTAssertTrue(app.staticTexts["Se déconnecter"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Supprimer mon compte"].exists)
        let dossier = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try app.screenshot().pngRepresentation.write(to: dossier.appendingPathComponent("reglages-build9.png"), options: .atomic)
        // La capture et les assertions suffisent ; le dump complet peut bloquer XCTest.
        print("WOOP_NAVIGATION_APRES_RELANCE_OK")
    }

    @MainActor
    func testDefilerProfil() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
        XCTAssertNotEqual(app.state, .notRunning)
        app.activate()
        if app.buttons["Later"].exists {
            app.buttons["Later"].tap()
            XCTAssertTrue(app.buttons["Later"].waitForNonExistence(timeout: 5))
        }
        XCTAssertTrue(app.buttons["Réglages"].waitForExistence(timeout: 5))
        let rangee = app.staticTexts["Deux Lunes"]
        XCTAssertTrue(rangee.exists)
        let avant = rangee.frame.minY
        app.swipeUp()
        XCTAssertLessThan(rangee.frame.minY, avant - 100, "Le contenu doit réellement défiler")
        let dossier = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try app.screenshot().pngRepresentation.write(to: dossier.appendingPathComponent("profil-scroll.png"), options: .atomic)
        print("WOOP_PROFIL_DEFILE_OK")
    }

    @MainActor
    func testFermerBienvenue() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
        XCTAssertNotEqual(app.state, .notRunning)
        app.activate()
        let plusTard = app.buttons["Later"]
        XCTAssertTrue(plusTard.waitForExistence(timeout: 5))
        plusTard.tap()
        XCTAssertTrue(plusTard.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["person"].isHittable)
        let dossier = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try app.screenshot().pngRepresentation.write(to: dossier.appendingPathComponent("home-sans-bienvenue9.png"), options: .atomic)
        print("WOOP_BIENVENUE_FERMEE_OK")
    }

    @MainActor
    func testHomeVersProfil() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
        XCTAssertNotEqual(app.state, .notRunning)
        app.activate()
        let profil = app.buttons["person"]
        XCTAssertTrue(profil.waitForExistence(timeout: 5))
        profil.tap()
        XCTAssertTrue(app.buttons["Réglages"].waitForExistence(timeout: 5))
        let dossier = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try app.screenshot().pngRepresentation.write(to: dossier.appendingPathComponent("profil-build9.png"), options: .atomic)
        print("WOOP_HOME_VERS_PROFIL_OK")
    }

    @MainActor
    func testProfilVersHome() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
        XCTAssertNotEqual(app.state, .notRunning)
        app.activate()
        XCTAssertTrue(app.buttons["Retour"].waitForExistence(timeout: 5))
        app.buttons["Retour"].tap()
        XCTAssertTrue(app.buttons["person"].waitForExistence(timeout: 5))
        let dossier = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try app.screenshot().pngRepresentation.write(to: dossier.appendingPathComponent("home-build9.png"), options: .atomic)
        print("WOOP_PROFIL_VERS_HOME_OK")
    }

    @MainActor
    func testHomeExosHome() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
        XCTAssertNotEqual(app.state, .notRunning)
        app.activate()
        let exercices = app.buttons["figure.strengthtraining.functional"]
        XCTAssertTrue(exercices.waitForExistence(timeout: 5))
        exercices.tap()
        XCTAssertTrue(app.staticTexts["Exercices"].waitForExistence(timeout: 5))
        app.buttons["house.fill"].tap()
        XCTAssertTrue(app.buttons["person"].waitForExistence(timeout: 5))
        print("WOOP_HOME_EXOS_HOME_OK")
    }

    @MainActor
    func testPagesEtReglages() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
        XCTAssertNotEqual(app.state, .notRunning)
        app.activate()
        XCTAssertTrue(app.buttons["Retour"].waitForExistence(timeout: 5))
        app.buttons["Retour"].tap()
        let exercices = app.buttons["figure.strengthtraining.functional"]
        XCTAssertTrue(exercices.waitForExistence(timeout: 5))
        exercices.tap()
        XCTAssertTrue(app.staticTexts["Exercices"].waitForExistence(timeout: 5))
        app.buttons["house.fill"].tap()
        XCTAssertTrue(app.buttons["person"].waitForExistence(timeout: 5))
        app.buttons["person"].tap()
        let reglages = app.buttons["Réglages"]
        XCTAssertTrue(reglages.waitForExistence(timeout: 5))
        reglages.tap()
        XCTAssertTrue(app.staticTexts["Se déconnecter"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Supprimer mon compte"].exists)
        let dossier = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try app.screenshot().pngRepresentation.write(to: dossier.appendingPathComponent("reglages-screen.png"), options: .atomic)
        try app.debugDescription.write(to: dossier.appendingPathComponent("reglages-tree.txt"), atomically: true, encoding: .utf8)
        print("WOOP_PAGES_ET_REGLAGES_OK")
    }

    @MainActor
    func testCaptureCurrentScreen() throws {
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
        XCTAssertNotEqual(app.state, .notRunning)
        app.activate()
        let dossier = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try app.screenshot().pngRepresentation.write(to: dossier.appendingPathComponent("current-screen.png"), options: .atomic)
        let arbre = app.debugDescription
        try arbre.write(to: dossier.appendingPathComponent("current-tree.txt"), atomically: true, encoding: .utf8)
        print("WOOP_CAPTURE_SAVED")
    }

    @MainActor
    func testInspectThenOneProfileTap() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
        XCTAssertNotEqual(app.state, .notRunning, "Woop doit déjà tourner : aucun lancement autorisé")
        app.activate()
        let before = XCTAttachment(string: app.debugDescription)
        before.name = "01-before-tree"
        before.lifetime = .keepAlways
        add(before)
        print("WOOP_NAV_BEFORE\n" + app.debugDescription)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "02-before-screen"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let profile = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Profil")).firstMatch
        XCTAssertTrue(profile.exists, "Élément Profil absent : aucune coordonnée devinée")
        print("WOOP_NAV_PROFILE_HITTABLE=\(profile.isHittable) FRAME=\(profile.frame)")
        profile.tap()
        let after = XCTAttachment(string: app.debugDescription)
        after.name = "03-after-tree"
        after.lifetime = .keepAlways
        add(after)
        print("WOOP_NAV_AFTER\n" + app.debugDescription)
        let afterScreenshot = XCTAttachment(screenshot: app.screenshot())
        afterScreenshot.name = "04-after-screen"
        afterScreenshot.lifetime = .keepAlways
        add(afterScreenshot)
    }
}
