import XCTest

final class NavRuntimeUITests: XCTestCase {
    func testMoletteSurIPhone() {
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
        defer { app.terminate() }
        for (mode, depart, pas) in [("hiit", 10, 40.0), ("modere", 7, 40.0), ("escalier", 6, 53.0)] {
            app.launchArguments = ["-tapisLab", "-tapisFige", "-tapisNu", "-tapisMode", mode, "-sansSondeVol"]
            app.launch()
            XCTAssertTrue(app.staticTexts[String(depart)].firstMatch.waitForExistence(timeout: 12))
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.06, dy: 0.49)).tap()
            let photo = XCTAttachment(screenshot: app.screenshot())
            photo.name = "iphone-\(mode)-tap-a-cote"; photo.lifetime = .keepAlways; add(photo)
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.10, dy: 0.63))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 2 * pas, dy: 0)),
                        withVelocity: .slow, thenHoldForDuration: 0.1)
            XCTAssertTrue(app.staticTexts[String(depart + 2)].firstMatch.waitForExistence(timeout: 3))
            app.terminate()
        }
    }

    func testDeuxRobesWelcome() {
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
        defer { app.terminate() }
        for robe in ["welcome", "welcomeTexte"] {
            app.launchArguments = ["-rewardLab", "-robe", robe, "-rewardFreeze", "1", "-rewardNu", "-sansSondeVol"]
            app.launch()
            XCTAssertTrue(app.buttons["Later"].waitForExistence(timeout: 10))
            Thread.sleep(forTimeInterval: 2)
            let photo = XCTAttachment(screenshot: app.screenshot())
            photo.name = "iphone-\(robe)"; photo.lifetime = .keepAlways; add(photo)
            app.terminate()
        }
    }
}
