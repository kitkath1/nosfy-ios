import XCTest

final class NavRuntimeUITests: XCTestCase {
    @MainActor
    func testFermetureContinueDepuisLeContenu() {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
        app.launchArguments = ["-sansSondeVol", "-sansVisite", "-openTab", "home",
                               "-chambreLongue", "regularite"]
        app.launch()
        defer { app.terminate() }
        let semaine = app.staticTexts.matching(NSPredicate(format: "label IN %@", ["Semaine", "Week"])).firstMatch
        XCTAssertTrue(semaine.waitForExistence(timeout: 12))
        let avant = XCTAttachment(screenshot: app.screenshot())
        avant.name = "widget-avant-descente"; avant.lifetime = .keepAlways; add(avant)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
            .press(forDuration: 0.1, thenDragTo:
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.77)),
                   withVelocity: XCUIGestureVelocity(rawValue: 130), thenHoldForDuration: 0.2)
        XCTAssertTrue(semaine.waitForNonExistence(timeout: 4))
        let apres = XCTAttachment(screenshot: app.screenshot())
        apres.name = "widget-apres-descente"; apres.lifetime = .keepAlways; add(apres)
    }
}
