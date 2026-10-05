import XCTest

/// PROFIL, RÉGLAGES ET OVERLAYS, À VRAIS DOIGTS (05-10, retours TestFlight 87) :
/// « on voit le menu dans Profil et Réglages ; non, que le chevron et le drag
/// vers le bas pour fermer, comme Spotify » ; « les overlays pas hyper fluides
/// au drag vers le bas ». Monté dans une COPIE jetable par `joue.sh`.
final class NavTirageUITests: XCTestCase {
    var app: XCUIApplication!
    static let preuves = ProcessInfo.processInfo.environment["APPLE_PREUVES"] ?? "/tmp/nav-preuves"

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
        log("\(nom) : \(ok ? "trouvé \(e.frame)" : "ABSENT après \(Int(t)) s")")
        if !ok { arbre("absent-\(nom)") }
        return ok
    }
    func pt(_ x: CGFloat, _ y: CGFloat) -> XCUICoordinate {
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y))
    }
    /// Un vrai pouce qui tire vers le bas, à vitesse de main.
    func tirer(_ x: CGFloat, de y0: CGFloat, a y1: CGFloat) {
        pt(x, y0).press(forDuration: 0.05, thenDragTo: pt(x, y1),
                        withVelocity: XCUIGestureVelocity(900), thenHoldForDuration: 0)
    }
    func nav(_ nom: String) -> XCUIElement { app.buttons.matching(NSPredicate(format: "label == %@", nom)).firstMatch }
    func navVisible() -> Bool { nav("Accueil").exists && nav("Accueil").isHittable }

    func test01_profil_reglages() {
        lancer(["-skipAuth", "-sansPlafond"])
        guard attendre(nav("Profil"), 40, "nav-home") else { return }
        pause(2); capture("n01-home")
        nav("Profil").tap(); pause(2.5)
        capture("n02-profil"); log("profil : nav visible = \(navVisible())")
        tirer(196, de: 260, a: 700); pause(2)
        capture("n03-profil-tire"); log("après tirage profil : nav visible = \(navVisible()) · réglages-chip = \(app.buttons["Réglages"].exists)")
        guard attendre(nav("Réglages"), 8, "nav-reglages") else { return }
        nav("Réglages").tap(); pause(2.5)
        capture("n04-reglages"); log("réglages : nav visible = \(navVisible())")
        tirer(196, de: 230, a: 720); pause(2)
        capture("n05-reglages-tire"); log("après tirage réglages : nav visible = \(navVisible())")
    }

    func test02_overlays() {
        lancer(["-skipAuth", "-sansPlafond", "-demoData", "-goAuto"])
        let compose = app.staticTexts.matching(NSPredicate(format: "label == %@", "Compose ta séance")).firstMatch
        guard attendre(compose, 45, "vide") else { return }
        pause(1.5)
        pt(196, compose.frame.minY - 30 - 48).tap(); pause(1.5)
        let champ = app.textFields.firstMatch
        guard attendre(champ, 8, "feuille") else { return }
        capture("o01-feuille")
        tirer(196, de: 112, a: 640); pause(1.5)
        capture("o02-feuille-tiree"); log("feuille après tirage : champ = \(champ.exists)")
        let refaire = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Refaire")).firstMatch
        guard attendre(refaire, 8, "refaire") else { return }
        // le bouton « Refaire » de la carte (sa partie droite)
        pt(refaire.frame.maxX - 50, refaire.frame.midY).tap(); pause(3)
        capture("o03-seance"); arbre("o03-seance")
        // la première ligne : sous le chiffre entre deux traits
        let titre = app.staticTexts.matching(NSPredicate(format: "label == %@", "Prête.")).firstMatch
        let y = titre.exists ? titre.frame.maxY + 190 : 380
        pt(250, y).tap(); pause(1.5)
        capture("o04-playlist"); arbre("o04-playlist")
        tirer(196, de: 560, a: 840); pause(1.5)
        capture("o05-playlist-tiree")
    }
}
