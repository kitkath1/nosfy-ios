import XCTest

// Le banc ajoute seulement des métadonnées d'accessibilité à PriseVitesse.
// Les événements passent tous par le vrai hit-testing et le vrai DragGesture.
final class MoletteVitesseUITests: XCTestCase {
    private func verifier(_ mode: String, depart: Int, pas: CGFloat) {
        let app = XCUIApplication(bundleIdentifier: "fr.kathryn.woop")
        app.launchArguments = ["-tapisLab", "-tapisFige", "-tapisNu", "-tapisMode", mode,
                               "-sansSondeVol", "-skipAuth"]
        app.launch()
        defer { app.terminate() }
        let prise = app.otherElements["test.molette"]
        XCTAssertTrue(prise.waitForExistence(timeout: 15))
        let origine = app.coordinate(withNormalizedOffset: .zero)
        let cadre = prise.frame
        func point(_ x: CGFloat, _ y: CGFloat) -> XCUICoordinate {
            origine.withOffset(CGVector(dx: x, dy: y))
        }
        func valeur(_ champ: String, _ attendu: String, timeout: TimeInterval = 2) {
            let predicat = NSPredicate(format: "value CONTAINS %@", "\(champ)=\(attendu);")
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicat, object: prise)], timeout: timeout), .completed, "\(champ): \(prise.value ?? "nil")")
        }
        valeur("vitesse", "\(depart)")
        valeur("arc", "false")
        // En haut à gauche de la bande : hors de l'ancienne zone de prise
        // et à côté du disque, là où le doigt imprécis doit ouvrir.
        point(cadre.minX + 24, cadre.minY + 22).tap()
        valeur("arc", "true", timeout: 0.7)
        valeur("vitesse", "\(depart)")
        valeur("sceau", "false")
        let photo = XCTAttachment(screenshot: app.screenshot())
        photo.name = "\(mode)-tap-a-cote"
        photo.lifetime = .keepAlways
        add(photo)
        // Reprendre avant le repli : glissement depuis le bord gauche.
        let y = cadre.minY + 60
        point(30, y).press(forDuration: 0.05,
                          thenDragTo: point(30 + pas * 2, y),
                          withVelocity: .slow, thenHoldForDuration: 0.1)
        valeur("vitesse", "\(depart + 2)")
        valeur("prise", "false")
        valeur("sceau", "true")
        valeur("arc", "false", timeout: 4)
        // Sens inverse, prise directe dans le bas de la bande.
        point(cadre.midX, cadre.maxY - 25).press(forDuration: 0.05,
            thenDragTo: point(cadre.midX - pas, cadre.maxY - 25),
            withVelocity: .slow, thenHoldForDuration: 0.1)
        valeur("vitesse", "\(depart + 1)")
        valeur("prise", "false")
        // Le chrono garde son tap dans le chevauchement des deux commandes.
        // h se déduit de la borne basse réelle (h - 102), avec la safe area.
        let h = cadre.maxY - app.frame.minY + 102
        point(cadre.midX, h * 0.315).tap()
        valeur("etat", mode == "hiit" ? "repos" : "pause")
    }

    func testHIIT() { verifier("hiit", depart: 10, pas: 40) }
    func testCardio() { verifier("modere", depart: 7, pas: 40) }
    func testEscalier() { verifier("escalier", depart: 6, pas: 53) }
}
