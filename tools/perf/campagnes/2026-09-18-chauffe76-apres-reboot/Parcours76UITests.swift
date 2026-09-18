import XCTest
import UIKit

final class NavRuntimeUITests: XCTestCase {
 @MainActor private func garderFrais(_ app: XCUIApplication) throws {
  let niveau = ProcessInfo.processInfo.thermalState.rawValue
  print("THERMIQUE IPHONE \(niveau) à \(Date())")
  if niveau >= 2 {
   app.terminate()
   throw XCTSkip("Thermique serious : parcours interrompu, validation non acquise")
  }
 }
 @MainActor private func attendre(_ secondes: Int, _ app: XCUIApplication, _ nom: String) throws {
  print("FENETRE \(nom) DEBUT \(Date())")
  for _ in 0..<secondes / 5 { sleep(5); try garderFrais(app) }
  print("FENETRE \(nom) FIN \(Date())")
 }
 @MainActor private func exiger(_ condition: Bool, _ message: String, _ app: XCUIApplication) throws {
  if !condition {
   print(app.debugDescription)
   app.terminate()
   XCTFail(message)
   throw NSError(domain: "NosfyChauffe", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
  }
 }
 @MainActor private func capture(_ app: XCUIApplication, _ nom: String) {
  let a = XCTAttachment(screenshot: app.screenshot()); a.name = nom
  a.lifetime = .keepAlways; add(a)
 }
 @MainActor private func retour(_ app: XCUIApplication) throws {
  guard let bouton = app.buttons.matching(identifier: "Retour")
   .allElementsBoundByIndex.first(where: { $0.isHittable }) else {
    try exiger(false, "Retour absent", app); return
  }
  bouton.tap()
 }
 @MainActor func testParcours76() throws {
  continueAfterFailure = true
  print("THERMIQUE AU DEPART \(ProcessInfo.processInfo.thermalState.rawValue)")
  guard ProcessInfo.processInfo.thermalState == .nominal else {
   throw XCTSkip("Départ nominal requis pour cette endurance")
  }
  let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
  defer { app.terminate() }
  let commun = ["-skipAuth", "-porteVue", "-sansVisite", "-sondeVol", "-ecranEveille", "-navProbe", "-storyProbe"]
  app.launchArguments = commun + ["-openTab", "profile", "-boosterCine"]
  app.launch()
  try exiger(app.staticTexts["Cartes collectées"].waitForExistence(timeout: 20), "Profil absent", app)
  capture(app, "76-profil")
  try attendre(60, app, "profil")
  try retour(app)
  let story = app.buttons["story-test-ouvrir"]
  try exiger(story.waitForExistence(timeout: 10), "Home absente après Profil", app)
  try attendre(60, app, "home-apres-profil")
  capture(app, "76-home-avant-stories")
  for cycle in 1...2 {
   story.tap()
   try exiger(app.staticTexts["story-etat"].waitForExistence(timeout: 5), "Story absente", app)
   try attendre(10, app, "story-resume-\(cycle)")
   for n in 1...3 {
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.085)).tap()
    try exiger(app.staticTexts["story-etat"].label.contains("page=\(n)"), "Page story attendue \(n)", app)
    try attendre(5, app, "story-\(cycle)-\(n)")
   }
   app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.14))
    .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75)))
   try exiger(story.waitForExistence(timeout: 5), "Retour story absent", app)
   try exiger(app.staticTexts["story-test-retour"].label == "mouvement=0;couverture=0;route=0", "Moteur story encore pris", app)
   app.buttons["booster-test-ouvrir"].tap()
   try attendre(15, app, "ouverture-booster-\(cycle)")
   capture(app, "76-carte-\(cycle)")
   XCUIDevice.shared.press(.home)
   sleep(2)
   app.activate()
   try attendre(5, app, "carte-reprise-\(cycle)")
   try retour(app)
   try exiger(story.waitForExistence(timeout: 5), "Retour carte absent", app)
   try attendre(60, app, "home-retour-carte-\(cycle)")
  }
  try attendre(180, app, "home-recuperation")
  capture(app, "76-home-recuperation")
  app.terminate()
  try garderFrais(app)
  app.launchArguments = commun + ["-openTab", "home", "-boosterGallery"]
  app.launch()
  try exiger(app.buttons["booster-test-ouvrir"].waitForExistence(timeout: 20), "Banc manège absent", app)
  app.buttons["booster-test-ouvrir"].tap()
  try attendre(60, app, "manege")
  capture(app, "76-manege")
  XCUIDevice.shared.press(.home)
  sleep(2)
  app.activate()
  try attendre(5, app, "manege-reprise")
  try retour(app)
  try exiger(app.buttons["story-test-ouvrir"].waitForExistence(timeout: 5), "Retour manège absent", app)
  try attendre(120, app, "home-apres-manege")
  capture(app, "76-home-apres-manege")
 }

 @MainActor func testFonctionnel76() throws {
  continueAfterFailure = true
  let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
  try garderFrais(app)
  defer { app.terminate() }
  app.launchArguments = ["-skipAuth", "-porteVue", "-sansVisite", "-sondeVol", "-ecranEveille", "-navProbe", "-storyProbe", "-openTab", "profile", "-boosterCine"]
  app.launch()
  try exiger(app.staticTexts["Cartes collectées"].waitForExistence(timeout: 20), "Profil absent", app)
  capture(app, "76-court-profil")
  try attendre(5, app, "court-profil")
  try retour(app)
  let story = app.buttons["story-test-ouvrir"]
  try exiger(story.waitForExistence(timeout: 10), "Retour Profil absent", app)
  story.tap()
  try exiger(app.staticTexts["story-etat"].waitForExistence(timeout: 5), "Story absente", app)
  for n in 1...3 {
   app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.085)).tap()
   try exiger(app.staticTexts["story-etat"].label.contains("page=\(n)"), "Page story attendue \(n)", app)
   try attendre(5, app, "court-story-\(n)")
  }
  app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.14))
   .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75)))
  try exiger(story.waitForExistence(timeout: 5), "Retour story absent", app)
  app.buttons["booster-test-ouvrir"].tap()
  try attendre(15, app, "court-booster")
  capture(app, "76-court-carte")
  XCUIDevice.shared.press(.home)
  sleep(2)
  app.activate()
  try attendre(5, app, "court-carte-reprise")
  try retour(app)
  try exiger(story.waitForExistence(timeout: 5), "Retour carte absent", app)
  try attendre(10, app, "court-home-retour")
  capture(app, "76-court-home")
 }

 @MainActor func testManegeEtRetourNormal76() throws {
  continueAfterFailure = true
  let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
  try garderFrais(app)
  defer { app.terminate() }
  app.launchArguments = ["-skipAuth", "-porteVue", "-sansVisite", "-sondeVol", "-ecranEveille", "-navProbe", "-storyProbe", "-openTab", "home", "-boosterGallery"]
  app.launch()
  try exiger(app.buttons["booster-test-ouvrir"].waitForExistence(timeout: 20), "Banc absent", app)
  app.buttons["booster-test-ouvrir"].tap()
  try attendre(5, app, "court-manege")
  capture(app, "76-court-manege")
  XCUIDevice.shared.press(.home); sleep(2); app.activate()
  try attendre(5, app, "court-manege-reprise")
  try retour(app)
  try exiger(app.buttons["story-test-ouvrir"].waitForExistence(timeout: 5), "Retour manège absent", app)
  try attendre(10, app, "court-home-apres-manege")
  app.terminate()
  app.launchArguments = ["-sansSondeVol", "-openTab", "home"]
  app.launch()
  sleep(3)
  capture(app, "76-retour-normal")
  try exiger(!app.buttons["story-test-ouvrir"].exists, "Banc encore visible", app)
 }

 @MainActor func testRepriseApresRepos76() throws {
  continueAfterFailure = true
  let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
  app.terminate()
  for n in 0...20 {
   let niveau = ProcessInfo.processInfo.thermalState.rawValue
   print("REPOS APP FERMEE \(n * 15)s THERMIQUE \(niveau) à \(Date())")
   if niveau == 0 {
    try testParcours76()
    return
   }
   if n < 20 { sleep(15) }
  }
  throw XCTSkip("Après cinq minutes app fermée, départ toujours non nominal ; aucune endurance lancée")
 }
}
