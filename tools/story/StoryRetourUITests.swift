import XCTest

final class NavRuntimeUITests: XCTestCase {
    override func tearDown() {
        XCUIApplication(bundleIdentifier: "fr.kathryn.woop").terminate()
        super.tearDown()
    }

    @MainActor
    func testRelanceSessionReelle() {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
        // Aucun contournement de l'authentification ni donnée de démonstration.
        app.launchArguments = ["-sansSondeVol", "-navProbe", "-openTab", "home"]
        app.launch()
        if app.buttons["Later"].waitForExistence(timeout: 5) { app.buttons["Later"].tap() }
        XCTAssertTrue(app.buttons["person"].waitForExistence(timeout: 25))
        XCTAssertFalse(app.buttons["story-test-ouvrir"].exists)
        app.buttons["figure.strengthtraining.functional"].tap()
        XCTAssertTrue(app.staticTexts["Exercices"].waitForExistence(timeout: 5))
        app.buttons["house.fill"].tap()
        XCTAssertTrue(app.buttons["person"].waitForExistence(timeout: 5))
        let home = XCTAttachment(screenshot: app.screenshot())
        home.name = "session-reelle-home"; home.lifetime = .keepAlways; add(home)
        app.buttons["person"].tap()
        XCTAssertTrue(app.buttons["Réglages"].waitForExistence(timeout: 5))
        let profil = XCTAttachment(screenshot: app.screenshot())
        profil.name = "session-reelle-profil"; profil.lifetime = .keepAlways; add(profil)
        app.buttons["Retour"].tap()
        XCTAssertTrue(app.buttons["person"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testRetourStoryEtInterruption() {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
        app.launchArguments = ["-skipAuth", "-porteVue", "-sansVisite", "-sansSondeVol",
                               "-storyProbe", "-navProbe", "-openTab", "home"]
        app.launch()
        defer { app.terminate() }
        let ouvrir = app.buttons["story-test-ouvrir"]
        XCTAssertTrue(ouvrir.waitForExistence(timeout: 30))
        for tour in 0..<2 {
            ouvrir.tap()
            let etat = app.staticTexts["story-etat"]
            XCTAssertTrue(etat.waitForExistence(timeout: 4))
            for _ in 0..<2 {
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.085)).tap()
            }
            XCTAssertTrue(etat.label.contains("page=2"), etat.label)
            if tour == 0 {
                XCUIDevice.shared.press(.home)
                sleep(2)
                app.activate()
                XCTAssertTrue(etat.waitForExistence(timeout: 5))
                XCTAssertTrue(etat.label.contains("page=2"), etat.label)
            }
            let story = XCTAttachment(screenshot: app.screenshot())
            story.name = "story-analyse-\(tour)"; story.lifetime = .keepAlways; add(story)
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.14))
                .press(forDuration: 0.05, thenDragTo:
                    app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75)))
            XCTAssertTrue(ouvrir.waitForExistence(timeout: 5))
            let retour = app.staticTexts["story-test-retour"]
            XCTAssertEqual(retour.label, "mouvement=0;couverture=0;route=0")
            let home = XCTAttachment(screenshot: app.screenshot())
            home.name = "home-apres-story-\(tour)"; home.lifetime = .keepAlways; add(home)
        }
    }

    @MainActor
    func testChauffeRetourStory() {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
        app.launchArguments = ["-skipAuth", "-porteVue", "-sansVisite", "-sondeVol",
                               "-ecranEveille", "-storyProbe", "-navProbe", "-openTab", "home"]
        app.launch()
        defer { app.terminate() }
        let ouvrir = app.buttons["story-test-ouvrir"]
        XCTAssertTrue(ouvrir.waitForExistence(timeout: 30))
        func repos(_ secondes: Int) {
            for _ in 0..<(secondes / 10) {
                sleep(10)
                XCTAssertFalse(app.staticTexts["▲▲"].exists || app.staticTexts["▲▲▲"].exists,
                               "Arrêt du stress : thermique serious ou critical")
            }
        }
        repos(120)
        for tour in 0..<3 {
            ouvrir.tap()
            XCTAssertTrue(app.staticTexts["story-etat"].waitForExistence(timeout: 5))
            if tour == 0 {
                sleep(1)
                let intro = XCTAttachment(screenshot: app.screenshot())
                intro.name = "introduction-texte"; intro.lifetime = .keepAlways; add(intro)
                sleep(5)
            } else {
                sleep(6)
            }
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.085)).tap()
            XCTAssertTrue(app.staticTexts["story-etat"].label.contains("page=1"))
            sleep(2) // Les détails sont réellement visibles avant l’analyse.
            for page in 2...3 {
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.085)).tap()
                XCTAssertTrue(app.staticTexts["story-etat"].label.contains("page=\(page)"))
                sleep(2)
            }
            let story = XCTAttachment(screenshot: app.screenshot())
            story.name = "therm-story-\(tour)"; story.lifetime = .keepAlways; add(story)
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.14))
                .press(forDuration: 0.05, thenDragTo:
                    app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75)))
            XCTAssertTrue(ouvrir.waitForExistence(timeout: 5))
            XCTAssertEqual(app.staticTexts["story-test-retour"].label, "mouvement=0;couverture=0;route=0")
            repos(10)
        }
        repos(180)
        let fin = XCTAttachment(screenshot: app.screenshot())
        fin.name = "therm-home-fin"; fin.lifetime = .keepAlways; add(fin)
    }

    @MainActor
    func testReouvertureIntroduction() {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
        app.launchArguments = ["-skipAuth", "-porteVue", "-sansVisite", "-sansSondeVol",
                               "-storyProbe", "-navProbe", "-openTab", "home"]
        app.launch()
        let ouvrir = app.buttons["story-test-ouvrir"]
        XCTAssertTrue(ouvrir.waitForExistence(timeout: 30))
        for _ in 0..<6 {
            ouvrir.tap()
            XCTAssertTrue(app.staticTexts["story-etat"].waitForExistence(timeout: 5))
            sleep(5)
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.10))
                .press(forDuration: 0.05, thenDragTo:
                    app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75)))
            XCTAssertTrue(ouvrir.waitForExistence(timeout: 5))
            XCTAssertEqual(app.staticTexts["story-test-retour"].label, "mouvement=0;couverture=0;route=0")
            sleep(1)
        }
    }

    @MainActor
    func testToasterDepuisIle() {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
        app.launchArguments = ["-skipAuth", "-porteVue", "-sansVisite", "-sansSondeVol",
                               "-pileTest", "-navProbe", "-openTab", "home"]
        app.launch()
        defer { app.terminate() }
        let annonce = app.descendants(matching: .any)["annonce-ile-120"]
        XCTAssertTrue(annonce.waitForExistence(timeout: 22))
        XCTAssertLessThan(annonce.frame.minY, 85, "La dalle doit rester au sommet, sans double safe area")
        Thread.sleep(forTimeInterval: 0.7)
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "toaster-ile-pieces"; capture.lifetime = .keepAlways; add(capture)
        let booster = app.descendants(matching: .any)["annonce-ile-1"]
        XCTAssertTrue(booster.waitForExistence(timeout: 8))
        Thread.sleep(forTimeInterval: 0.7)
        let suite = XCTAttachment(screenshot: app.screenshot())
        suite.name = "toaster-ile-booster"; suite.lifetime = .keepAlways; add(suite)
        XCTAssertTrue(booster.waitForNonExistence(timeout: 6))
    }
}
