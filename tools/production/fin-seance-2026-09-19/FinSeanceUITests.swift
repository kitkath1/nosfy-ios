import XCTest
final class FinSeanceUITests: XCTestCase {
 @MainActor func parcours(sept:Bool,reduce:Bool) {
  continueAfterFailure=false
  let app=XCUIApplication(bundleIdentifier:"fr.kathryn.woop")
  app.launchArguments=["-skipAuth","-porteVue","-sansVisite","-sansSondeVol","-navProbe","-demoData","-qaFin","-openTab","home","-woop.langue","fr"]
  if sept {app.launchArguments.append("-qaSept")}
  if reduce {app.launchArguments.append("-qaReduce")}
  app.launch()
  let bouton=app.buttons["qa.fin"]
  XCTAssertTrue(bouton.waitForExistence(timeout:40))
  sleep(10)
  bouton.tap()
  // Le reçu de test arrive localement ; les vraies RPC ont leur banc API séparé.
  let etatStory=app.staticTexts["story-etat"]
  XCTAssertTrue(etatStory.waitForExistence(timeout:25))
  for page in 1...3 {
   app.coordinate(withNormalizedOffset:CGVector(dx:0.85,dy:0.085)).tap()
   let atteint=NSPredicate(format:"label CONTAINS %@", "page=\(page)")
   expectation(for:atteint,evaluatedWith:etatStory)
   waitForExpectations(timeout:5)
  }
  // Le montant est contrôlé par le banc Swift puis sur la capture WIN.
  // SwiftUI ne publie pas le texte animé dans l’arbre XCTest de ce rendu.
  sleep(4)
  let story=XCTAttachment(screenshot:app.screenshot());story.name="story-20-un-sachet";story.lifetime = .keepAlways;add(story)
  app.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.14)).press(forDuration:0.05,thenDragTo:app.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.8)))
  let sceau=app.staticTexts["route.seance-accomplie"]
  XCTAssertTrue(sceau.waitForExistence(timeout:8))
  let route=app.staticTexts["qa.route"]
  XCTAssertTrue(route.label.contains(sept ? "faits=7;actif=9;fete=1" : "faits=1;actif=1;fete=1"),route.label)
  sleep(2)
  let vue=XCTAttachment(screenshot:app.screenshot());vue.name=sept ? "route-sept-reduce" : "route-premier-accompli";vue.lifetime = .keepAlways;add(vue)
  XCUIDevice.shared.press(.home);sleep(1);app.activate()
  XCTAssertTrue(sceau.waitForExistence(timeout:5))
  XCTAssertTrue(route.label.contains(sept ? "faits=7;actif=9;fete=1" : "faits=1;actif=1;fete=1"),route.label)
  app.terminate()
 }
 @MainActor func testPremiereSeance(){parcours(sept:false,reduce:false)}
 @MainActor func testSeptiemeReduceMotion(){parcours(sept:true,reduce:true)}
}
