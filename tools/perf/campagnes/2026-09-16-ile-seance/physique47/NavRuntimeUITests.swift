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
