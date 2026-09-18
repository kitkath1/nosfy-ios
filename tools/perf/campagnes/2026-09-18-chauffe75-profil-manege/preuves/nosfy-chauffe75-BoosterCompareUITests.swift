import XCTest
import UIKit
final class NavRuntimeUITests: XCTestCase {
 @MainActor func testProfilBoosterCompare() throws {
  guard ProcessInfo.processInfo.thermalState == .nominal else { throw XCTSkip("Attendre thermique nominal") }
  let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
  defer { app.terminate() }
  for (nom, enterre) in [("B1", "YES"), ("A", "NO"), ("B2", "YES")] {
   guard ProcessInfo.processInfo.thermalState.rawValue < 2 else { return }
   app.launchArguments = ["-skipAuth", "-porteVue", "-sansVisite", "-sondeVol", "-ecranEveille", "-navProbe", "-openTab", "profile", "-profilBoosterEnterre", enterre]
   app.launch()
   guard app.staticTexts["Cartes collectées"].waitForExistence(timeout: 15) else {
    print(app.debugDescription); app.terminate(); XCTFail("Profil absent"); return
   }
   let a = XCTAttachment(screenshot: app.screenshot()); a.name = "profil-" + nom; a.lifetime = .keepAlways; add(a)
   print("VARIANTE \(nom) ENTERRE \(enterre)")
   for i in 1...6 {
    sleep(10)
    print("\(nom) \(i * 10)s THERMIQUE \(ProcessInfo.processInfo.thermalState.rawValue)")
    if ProcessInfo.processInfo.thermalState.rawValue >= 2 { app.terminate(); return }
   }
   app.terminate()
  }
 }
}
