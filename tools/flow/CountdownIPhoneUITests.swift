import XCTest

/// Runner externe : cible la Release installée, sans créer ni finir de séance.
final class NavRuntimeUITests: XCTestCase {
    @MainActor
    func testLecteurDepartSurIPhone() {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
        app.launchArguments = ["-countLab", "-sansServeur", "-sondeVol", "-navProbe", "-ecranEveille"]
        app.terminate()
        app.launch()
        let film = app.buttons["depart-compte-rebours"]
        let rejouer = app.buttons["depart-rejouer"]
        func marque(_ nom: String) {
            print("WOOP_COUNT_IPHONE \(nom) \(ISO8601DateFormatter().string(from: Date()))")
        }
        func capture(_ nom: String) {
            let a = XCTAttachment(screenshot: app.screenshot())
            a.name = nom
            a.lifetime = .keepAlways
            add(a)
        }
        XCTAssertTrue(film.waitForExistence(timeout: 15))
        capture("iphone-count-premiere-lecture")
        XCTAssertTrue(rejouer.waitForExistence(timeout: 12))
        marque("repos-avant")
        Thread.sleep(forTimeInterval: 20)
        capture("iphone-count-repos-avant")
        for n in 1...3 {
            marque("lecture-\(n)-tap")
            rejouer.tap()
            XCTAssertTrue(film.waitForExistence(timeout: 3))
            capture("iphone-count-lecture-\(n)")
            XCTAssertTrue(rejouer.waitForExistence(timeout: 10))
            marque("lecture-\(n)-fin")
            Thread.sleep(forTimeInterval: 3)
        }
        rejouer.tap()
        XCTAssertTrue(film.waitForExistence(timeout: 3))
        film.tap()
        XCTAssertTrue(rejouer.waitForExistence(timeout: 3))
        marque("tap-passe")
        rejouer.tap()
        XCTAssertTrue(film.waitForExistence(timeout: 3))
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 7)
        app.activate()
        XCTAssertTrue(film.waitForExistence(timeout: 2))
        XCTAssertTrue(rejouer.waitForExistence(timeout: 10))
        marque("repos-apres")
        Thread.sleep(forTimeInterval: 25)
        capture("iphone-count-repos-apres")
        marque("fin")
        // Ne pas relancer avant la collecte des journaux de cette exécution.
    }
}
