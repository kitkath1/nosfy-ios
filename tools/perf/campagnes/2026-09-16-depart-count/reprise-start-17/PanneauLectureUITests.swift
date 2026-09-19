import XCTest
final class NavRuntimeUITests: XCTestCase {
    @MainActor
    func testFermerEtRouvrirPanneau() {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
        app.activate()
        let start = app.buttons["Start"]
        XCTAssertTrue(start.waitForExistence(timeout: 12))
        let later = app.buttons["Later"]
        XCTAssertTrue(later.isHittable)
        later.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(start.waitForNonExistence(timeout: 3))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.39)).tap()
        XCTAssertTrue(start.waitForExistence(timeout: 3))
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = "etat-iPhone-17"; image.lifetime = .keepAlways; add(image)
        let arbre = XCTAttachment(string: app.debugDescription)
        arbre.name = "arbre-iPhone-17"; arbre.lifetime = .keepAlways; add(arbre)
        print("START_PRESENT=\(start.exists)")
        if start.exists { print("START_FRAME=\(start.frame) HITTABLE=\(start.isHittable)") }
    }
}
