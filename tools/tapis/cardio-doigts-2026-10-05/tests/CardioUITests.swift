import XCTest

/// LE CARDIO DE BOUT EN BOUT, À VRAIS DOIGTS (05-10, retours TestFlight 87) :
/// « je choisis un km/h, après je clique sur GO et ça lance » ; « pas de gros
/// bouton pour terminer » ; « en courant c'est horrible ». Monté par `joue.sh`.
final class CardioUITests: XCTestCase {
    var app: XCUIApplication!
    static let preuves = ProcessInfo.processInfo.environment["APPLE_PREUVES"] ?? "/tmp/cardio-preuves"

    override func setUpWithError() throws { continueAfterFailure = true }

    func lancer(_ args: [String]) { app = XCUIApplication(); app.launchArguments = args; app.launch() }
    func log(_ s: String) { print("BEB \(s)") }
    func pause(_ s: Double) { Thread.sleep(forTimeInterval: s) }
    func capture(_ nom: String) {
        let s = XCUIScreen.main.screenshot()
        try? FileManager.default.createDirectory(atPath: Self.preuves, withIntermediateDirectories: true)
        try? s.pngRepresentation.write(to: URL(fileURLWithPath: "\(Self.preuves)/\(nom).png"))
        log("capture \(nom)")
    }
    func arbre(_ nom: String) {
        try? FileManager.default.createDirectory(atPath: Self.preuves, withIntermediateDirectories: true)
        try? app.debugDescription.write(toFile: "\(Self.preuves)/\(nom).txt", atomically: true, encoding: .utf8)
    }
    @discardableResult
    func attendre(_ e: XCUIElement, _ t: TimeInterval, _ nom: String) -> Bool {
        let ok = e.waitForExistence(timeout: t)
        log("\(nom) : \(ok ? "trouvé" : "ABSENT après \(Int(t)) s")")
        if !ok { arbre("absent-\(nom)") }
        return ok
    }
    func pt(_ x: CGFloat, _ y: CGFloat) -> XCUICoordinate {
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y))
    }
    /// Le bouton du BAS parmi ses homonymes (le GO de la pastille et celui du médaillon).
    func boutonDuBas(_ label: String) -> XCUIElement {
        let q = app.buttons.matching(NSPredicate(format: "label == %@", label))
        return q.allElementsBoundByIndex.max { $0.frame.minY < $1.frame.minY } ?? q.firstMatch
    }
    func texte(_ debut: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", debut)).firstMatch
    }
    /// Toucher un médaillon par son mot, écrit dessous (62 pt plus haut).
    func toucherSousMot(_ mot: String) {
        let t = app.staticTexts.matching(NSPredicate(format: "label == %@", mot)).allElementsBoundByIndex
            .max { $0.frame.minY < $1.frame.minY }
        guard let t else { log("mot \(mot) ABSENT"); return }
        pt(t.frame.midX, t.frame.minY - 60).tap()
    }
    func plus(_ n: Int) {
        let b = app.buttons["Plus vite"]
        guard attendre(b, 10, "plus") else { return }
        for _ in 0..<n { b.tap(); pause(0.25) }
    }

    func test01_hiit() {
        lancer(["-skipAuth", "-sansPlafond", "-demoData", "-goAuto", "-bancHiit", "direct"])
        guard attendre(boutonDuBas("Go"), 60, "go") else { return }
        pause(1.5); capture("h01-pret")
        plus(9); pause(1); capture("h02-9kmh")
        boutonDuBas("Go").tap(); pause(4)
        capture("h03-set1")
        guard attendre(app.buttons["Stop"], 5, "stop") else { return }
        app.buttons["Stop"].tap(); pause(1.5)
        capture("h04-pause"); log("set 1 terminé : \(texte("SET 1 TERMIN").exists)")
        plus(4); pause(0.6)
        toucherSousMot("Reprendre"); pause(3.5)
        capture("h05-set2")
        app.buttons["Stop"].tap(); pause(1.5)
        toucherSousMot("Terminer"); pause(2)
        capture("h06-fin"); arbre("h06-fin")
        log("tout est fait : \(texte("Tout est fait").exists)")
        // le slider « Retour à la séance »
        // le slider s'appelle « Retour » (son mot) ; le chevron aussi — le plus bas
        let r = app.buttons.matching(NSPredicate(format: "label == %@", "Retour")).allElementsBoundByIndex
            .max { $0.frame.minY < $1.frame.minY }
        if let r, r.frame.minY > 600 {
            let y = r.frame.midY
            pt(r.frame.minX + 40, y).press(forDuration: 0.1, thenDragTo: pt(r.frame.maxX - 6, y),
                                           withVelocity: XCUIGestureVelocity(500), thenHoldForDuration: 0.2)
            log("slider retour glissé")
            pause(3.5)
        } else { log("slider retour ABSENT") }
        capture("h07-apres-retour"); arbre("h07-apres-retour")
        log("après retour : tout-est-fait = \(texte("Tout est fait").exists) · TA SÉANCE = \(texte("TA SÉANCE").exists)")
    }

    func test02_tapis_lent() {
        lancer(["-skipAuth", "-sansPlafond", "-openTab", "exercises", "-openExercise", "tapis-lent", "-departSerieAuto"])
        guard attendre(boutonDuBas("Go"), 40, "go") else { return }
        pause(1.5); capture("t01-pret")
        plus(6); pause(1)
        boutonDuBas("Go").tap(); pause(4)
        capture("t02-court")
        guard attendre(app.buttons["Pause"], 5, "pause") else { return }
        app.buttons["Pause"].tap(); pause(1.5)
        capture("t03-pause")
        toucherSousMot("Terminer"); pause(2.5)
        capture("t04-fin"); arbre("t04-fin")
    }
}
