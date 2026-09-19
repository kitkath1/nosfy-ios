import XCTest
import UIKit

final class NavRuntimeUITests: XCTestCase {
    @MainActor private func refroidi() throws {
        let therm = ProcessInfo.processInfo.thermalState.rawValue
        print("THERMIQUE IPHONE: \(therm)")
        if therm >= 2 { throw XCTSkip("Téléphone chaud : aucun stress supplémentaire") }
    }
    @MainActor private func capture(_ app: XCUIApplication, _ nom: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = nom; a.lifetime = .keepAlways; add(a)
    }
    @MainActor private func page(_ app: XCUIApplication, _ n: Int) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.085)).tap()
        XCTAssertTrue(app.staticTexts["story-etat"].label.contains("page=\(n)"))
    }
    @MainActor func testAStoriesFrancaisesEtAnglaises() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
        defer { app.terminate() }
        for langue in ["fr", "en"] {
            try refroidi()
            app.launchArguments = ["-storyLab", "-storyProbe", "-navProbe", "-sansSondeVol", "-woop.langue", langue]
            app.launch()
            let fr = langue == "fr"
            XCTAssertTrue(app.staticTexts[fr ? "glisse vers le haut" : "swipe up"].waitForExistence(timeout: 12))
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.58))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.27)))
            XCTAssertTrue(app.staticTexts["story-etat"].waitForExistence(timeout: 5))
            sleep(6)
            XCTAssertTrue(app.staticTexts[fr ? "Résumé" : "Summary"].exists)
            XCTAssertTrue(app.staticTexts[fr ? "votre séance" : "your session"].exists)
            XCTAssertTrue(app.staticTexts[fr ? "du 12 janvier" : "on January 12"].exists)
            capture(app, "\(langue)-resume")
            page(app, 1)
            XCTAssertTrue(app.staticTexts[fr ? "Détails" : "Details"].exists)
            XCTAssertTrue(app.staticTexts[fr ? "Woodchopper poulie haute" : "High cable woodchopper"].waitForExistence(timeout: 3))
            capture(app, "\(langue)-details")
            page(app, 2)
            sleep(2)
            let textes = app.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: "\n")
            print("ANALYSE \(langue): \(textes)")
            XCTAssertFalse(textes.contains(fr ? "Big push day." : "Belle poussée."))
            XCTAssertTrue(textes.contains(fr ? "Belle poussée." : "Big push day."))
            capture(app, "\(langue)-analyse")
            page(app, 3)
            XCTAssertTrue(app.staticTexts[fr ? "pièces gagnées" : "coins earned"].waitForExistence(timeout: 3))
            capture(app, "\(langue)-butin")
            app.terminate()
            try refroidi()
        }
    }
    @MainActor func testBExceptionsDansLesDeuxLangues() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
        defer { app.terminate() }
        for (langue, flag, titre) in [("fr", "-storyTop", "Meilleur cardio"), ("en", "-storyTopMuscu", "Top Lifting"),
                                      ("fr", "-storyDouble", "Double séance"), ("en", "-storyDouble", "Double day")] {
            try refroidi()
            app.launchArguments = ["-storyLab", "-storyAuto", flag, "-sansSondeVol", "-woop.langue", langue]
            app.launch()
            XCTAssertTrue(app.staticTexts[titre].waitForExistence(timeout: 15))
            sleep(7)
            capture(app, "\(langue)\(flag)")
            app.terminate()
        }
    }
    @MainActor func testCRetourBoosterEtStories() throws {
        continueAfterFailure = false
        try refroidi()
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
        app.launchArguments = ["-skipAuth", "-porteVue", "-sansVisite", "-sondeVol", "-ecranEveille",
                               "-storyProbe", "-navProbe", "-openTab", "home", "-boosterCine"]
        app.launch()
        defer { app.terminate() }
        let story = app.buttons["story-test-ouvrir"]
        let booster = app.buttons["booster-test-ouvrir"]
        XCTAssertTrue(story.waitForExistence(timeout: 30))
        #if targetEnvironment(simulator)
        let avant = 1, apres = 2 // parcours fonctionnel, aucune mesure thermique
        #else
        let avant = 6, apres = 12
        #endif
        for _ in 0..<avant { sleep(10); try refroidi() }
        capture(app, "home-avant-parcours")
        story.tap()
        XCTAssertTrue(app.staticTexts["story-etat"].waitForExistence(timeout: 5))
        sleep(6)
        for n in 1...3 { page(app, n); sleep(2); try refroidi() }
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.14))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75)))
        XCTAssertTrue(story.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["story-test-retour"].label, "mouvement=0;couverture=0;route=0")
        try refroidi()
        booster.tap()
        for _ in 0..<3 { sleep(4); try refroidi() }
        let boutonsRetour = app.buttons.matching(identifier: "Retour")
        let retour = try XCTUnwrap(boutonsRetour.allElementsBoundByIndex.first(where: { $0.isHittable }))
        capture(app, "booster-resultat")
        XCUIDevice.shared.press(.home)
        sleep(2)
        app.activate()
        XCTAssertTrue(retour.waitForExistence(timeout: 5))
        retour.tap()
        XCTAssertTrue(story.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["story-test-retour"].label, "mouvement=0;couverture=0;route=0")
        for _ in 0..<apres { sleep(10); try refroidi() }
        capture(app, "home-apres-parcours")
    }
    @MainActor func testDManègeInterruptionEtFermeture() throws {
        continueAfterFailure = false
        try refroidi()
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
        app.launchArguments = ["-skipAuth", "-porteVue", "-sansVisite", "-sondeVol", "-ecranEveille",
                               "-storyProbe", "-navProbe", "-openTab", "home", "-boosterGallery"]
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.buttons["booster-test-ouvrir"].waitForExistence(timeout: 20))
        app.buttons["booster-test-ouvrir"].tap()
        sleep(3)
        try refroidi()
        capture(app, "manege-avant-interruption")
        XCUIDevice.shared.press(.home)
        sleep(2)
        app.activate()
        sleep(1)
        let retour = try XCTUnwrap(app.buttons.matching(identifier: "Retour")
            .allElementsBoundByIndex.first(where: { $0.isHittable }))
        capture(app, "manege-apres-interruption")
        retour.tap()
        XCTAssertTrue(app.buttons["story-test-ouvrir"].waitForExistence(timeout: 5))
        sleep(5)
        try refroidi()
        capture(app, "home-apres-manege")
    }

}
