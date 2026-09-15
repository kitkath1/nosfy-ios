import XCTest

final class NavRuntimeUITests: XCTestCase {
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
        try app.screenshot().pngRepresentation.write(to: dossier.appendingPathComponent("reglages-build7.png"), options: .atomic)
        try app.debugDescription.write(to: dossier.appendingPathComponent("reglages-build7-tree.txt"), atomically: true, encoding: .utf8)
        print("WOOP_NAVIGATION_APRES_RELANCE_OK")
    }

    @MainActor
    func testDefilerProfil() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
        XCTAssertNotEqual(app.state, .notRunning)
        app.activate()
        XCTAssertTrue(app.buttons["Réglages"].waitForExistence(timeout: 5))
        app.swipeUp()
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
        try app.screenshot().pngRepresentation.write(to: dossier.appendingPathComponent("home-sans-bienvenue6.png"), options: .atomic)
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
        try app.screenshot().pngRepresentation.write(to: dossier.appendingPathComponent("profil-build6.png"), options: .atomic)
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
        try app.screenshot().pngRepresentation.write(to: dossier.appendingPathComponent("home-build6.png"), options: .atomic)
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
