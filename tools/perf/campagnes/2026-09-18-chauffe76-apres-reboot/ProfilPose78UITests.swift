import XCTest
final class NavRuntimeUITests: XCTestCase {
 @MainActor private func capture(_ app: XCUIApplication, _ nom: String) {
  let a = XCTAttachment(screenshot: app.screenshot()); a.name = nom
  a.lifetime = .keepAlways; add(a)
 }
 @MainActor func testProfilPoseEtGestes78() throws {
  continueAfterFailure = false
  let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
  app.launchArguments = ["-skipAuth", "-porteVue", "-sansVisite", "-navProbe", "-sondeVol", "-ecranEveille", "-openTab", "profile", "-profilRepos"]
  app.launch()
  XCTAssertTrue(app.staticTexts["Cartes collectées"].waitForExistence(timeout: 20))
  sleep(8)
  capture(app, "78-profil-pose")
  let crete = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.90))
  crete.tap()
  XCTAssertTrue(app.buttons["RETOUR"].waitForExistence(timeout: 5), "Le tap du sachet en pose doit ouvrir son panneau")
  sleep(3)
  capture(app, "78-panneau-tap")
  app.buttons["RETOUR"].tap()
  sleep(2)
  crete.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.62)))
  XCTAssertTrue(app.buttons["RETOUR"].waitForExistence(timeout: 5), "Le tirage reste disponible en pose")
  app.buttons["RETOUR"].tap()
  sleep(2)
  XCUIDevice.shared.press(.home)
  sleep(2)
  app.activate()
  sleep(3)
  capture(app, "78-pose-apres-reprise")
  app.buttons["Retour"].firstMatch.tap()
  sleep(3)
  capture(app, "78-home")
  app.terminate()
 }
}
