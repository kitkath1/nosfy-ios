import XCTest

/// LA SÉANCE DE BOUT EN BOUT, À VRAIS TOUCHERS (03-10, retours TestFlight 86) :
/// la séance vide, l'ajout, trois séries (slider, Stop, note, Valider, repos),
/// le slider « Terminer » ; « Refaire » sur un compte qui a un passé ; le HIIT.
/// Monté dans une COPIE jetable par `monte.sh` — le dépôt n'a pas de cible de test.
final class BoutEnBoutUITests: XCTestCase {
    var app: XCUIApplication!
    static let preuves = ProcessInfo.processInfo.environment["BEB_PREUVES"]
        ?? "/tmp/beb-preuves"

    override func setUpWithError() throws { continueAfterFailure = true }

    // MARK: outils

    func lancer(_ args: [String]) {
        app = XCUIApplication()
        app.launchArguments = args
        app.launch()
    }

    func log(_ s: String) { print("BEB \(s)") }

    func capture(_ nom: String) {
        let s = XCUIScreen.main.screenshot()
        let a = XCTAttachment(screenshot: s)
        a.name = nom; a.lifetime = .keepAlways
        add(a)
        try? FileManager.default.createDirectory(atPath: Self.preuves, withIntermediateDirectories: true)
        try? s.pngRepresentation.write(to: URL(fileURLWithPath: "\(Self.preuves)/\(nom).png"))
        log("capture \(nom)")
    }

    func arbre(_ nom: String) {
        try? FileManager.default.createDirectory(atPath: Self.preuves, withIntermediateDirectories: true)
        try? app.debugDescription.write(toFile: "\(Self.preuves)/\(nom).txt", atomically: true, encoding: .utf8)
        log("arbre \(nom)")
    }

    func bouton(_ debut: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", debut)).firstMatch
    }

    /// Le bouton du BAS parmi ses homonymes : la carte de la home garde le
    /// sien sous la séance (« Ajouter un exercice » ×2 dans l'arbre).
    func boutonDuBas(_ debut: String) -> XCUIElement {
        let q = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", debut))
        return q.allElementsBoundByIndex.max { $0.frame.minY < $1.frame.minY } ?? q.firstMatch
    }

    /// La séance vide est à l'écran (après le 3-2-1 de `-goAuto`).
    @discardableResult
    func attendreLaSeanceVide(_ nom: String) -> Bool {
        attendre(texte("Compose"), 45, nom)
    }

    func texte(_ exact: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label == %@", exact)).firstMatch
    }

    @discardableResult
    func attendre(_ e: XCUIElement, _ t: TimeInterval, _ nom: String) -> Bool {
        let ok = e.waitForExistence(timeout: t)
        log("\(nom) : \(ok ? "trouvé \(e.frame)" : "ABSENT après \(Int(t)) s")")
        if !ok { arbre("absent-\(nom)") }
        return ok
    }

    func pause(_ s: Double) { Thread.sleep(forTimeInterval: s) }

    func taper(_ x: CGFloat, _ y: CGFloat) {
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y)).tap()
    }

    /// Un VRAI glissé du pouce, du bouton gauche au bout droit du slider.
    func glisser(_ e: XCUIElement, _ nom: String) {
        let f = e.frame
        let o = app.coordinate(withNormalizedOffset: .zero)
        let a = o.withOffset(CGVector(dx: f.minX + 30, dy: f.midY))
        let b = o.withOffset(CGVector(dx: f.maxX - 4, dy: f.midY))
        log("glisse \(nom) \(f)")
        a.press(forDuration: 0.15, thenDragTo: b, withVelocity: 520, thenHoldForDuration: 0.2)
    }

    /// Le Stop du cadran : le médaillon de 74 pt posé 8 pt au-dessus de « Stop ».
    func stop(_ nom: String) {
        let t = texte("Stop")
        guard attendre(t, 12, "stop-\(nom)") else { return }
        let f = t.frame
        log("tape Stop \(nom)")
        taper(f.midX, f.minY - 45)
    }

    /// Une série : la laisser courir, Stop, la note, Valider.
    func serie(_ i: Int) {
        let passer = bouton("Passer l'animation")
        if passer.waitForExistence(timeout: 6) { log("passe l'animation \(i)"); passer.tap() }
        // Stop n'est vivant qu'EN COURS (pendant l'arrivée du cadran il est
        // éteint, à 0,35, et ne prend pas le doigt).
        let enCours = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "en cours")).firstMatch
        attendre(enCours, 25, "en-cours-\(i)")
        pause(3.0)
        capture("s\(i)-a-effort")
        let valider = bouton("Valider")
        for essai in 1...3 where !valider.exists {
            stop("\(i).\(essai)")
            _ = valider.waitForExistence(timeout: 4)
        }
        guard attendre(valider, 2, "valider-\(i)") else { return }
        pause(0.8)
        capture("s\(i)-b-note")
        if i == 1 {
            arbre("s1-note")
            log("note : « Série 1 » à l'écran = \(texte("Série 1").exists), onglet Cadran = \(app.buttons["Cadran"].exists)/\(app.buttons["Cadran"].isHittable)")
            let repos = bouton("Repos")
            if repos.exists {
                repos.tap(); pause(1.2)
                capture("s1-c-menu-repos")
                arbre("s1-menu-repos")
                taper(195, 120); pause(0.8)
            } else { log("menu Repos ABSENT") }
        }
        valider.tap()
        pause(2.0)
        capture("s\(i)-d-apres-valider")
    }

    // MARK: 1 — compte neuf : vide, ajout, trois séries, Terminer

    func test01_videAjoutTroisSeriesTerminer() {
        lancer(["-skipAuth", "-sansPlafond", "-goAuto"])
        guard attendreLaSeanceVide("vide-compose") else { return }
        pause(1.5)
        let ajouter = boutonDuBas("Ajouter un exercice")
        log("vide : Ajouter \(ajouter.frame)")
        capture("01-vide-neuve")
        log("vide : Refaire = \(bouton("Refaire").exists), Terminer = \(bouton("Terminer").exists)")
        ajouter.tap()
        let champ = app.textFields.firstMatch
        guard attendre(champ, 8, "feuille-champ") else { return }
        pause(0.8)
        capture("02-feuille")
        champ.tap()
        champ.typeText("Woodchopper")
        pause(1.0)
        let ligne = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Woodchopper poulie haute")).firstMatch
        guard attendre(ligne, 6, "ligne-woodchopper") else { return }
        ligne.tap()
        pause(0.5)
        let valider = bouton("Ajouter (1)")
        guard attendre(valider, 4, "ajouter-1") else { return }
        valider.tap()
        let go = bouton("Allez, go")
        guard attendre(go, 10, "slider-go") else { return }
        pause(1.5)
        capture("03-page-un-exercice")
        log("page : « Terminer » en haut = \(bouton("Terminer").exists)")
        glisser(go, "go-serie-1")
        serie(1)
        for i in 2...3 {
            let lancerS = bouton("Lancer")
            guard attendre(lancerS, 12, "slider-lancer-\(i)") else { return }
            pause(1.0)
            if i == 2 { capture("s1-e-repos") }
            glisser(lancerS, "lancer-\(i)")
            serie(i)
        }
        pause(2.5)
        capture("04-apres-trois-series")
        arbre("04-apres-trois-series")
        var terminer = app.buttons.matching(NSPredicate(format: "label == %@", "Terminer")).firstMatch
        if !terminer.waitForExistence(timeout: 6) {
            log("pas de slider Terminer : je referme le cadran par son chevron")
            taper(37, 96)
            pause(2.0)
            capture("05-cadran-referme")
            arbre("05-cadran-referme")
            terminer = app.buttons.matching(NSPredicate(format: "label == %@", "Terminer")).firstMatch
        }
        guard attendre(terminer, 12, "slider-terminer") else { return }
        pause(1.5)
        capture("06-page-tout-fait")
        glisser(terminer, "terminer")
        pause(1.2)
        capture("07-terminer-1s")
        log("après Terminer : carte STOP (« Arrêter la séance ») = \(app.buttons["Arrêter la séance"].exists)")
        pause(3.0)
        capture("08-terminer-4s")
        arbre("08-terminer-4s")
        pause(5.0)
        capture("09-terminer-9s")
    }

    // MARK: 2 — un passé : « Refaire ta séance de … »

    func test02_refaire() {
        lancer(["-skipAuth", "-sansPlafond", "-demoData", "-goAuto"])
        let refaire = bouton("Refaire ta séance")
        guard attendre(refaire, 45, "refaire") else { capture("r-absent"); return }
        pause(1.5)
        capture("r1-vide-avec-passe")
        log("refaire : \(refaire.label)")
        refaire.tap()
        let go = bouton("Allez, go")
        guard attendre(go, 10, "refaite-slider") else { return }
        pause(1.8)
        capture("r2-refaite")
        arbre("r2-refaite")
    }

    // MARK: 3 — le HIIT : 0 km/h lumineux, pas de nav, rien ne passe seul

    func test03_hiit() {
        lancer(["-skipAuth", "-sansPlafond", "-goAuto"])
        guard attendreLaSeanceVide("h-compose") else { return }
        pause(1.0)
        let ajouter = boutonDuBas("Ajouter un exercice")
        ajouter.tap()
        let champ = app.textFields.firstMatch
        guard attendre(champ, 8, "h-champ") else { return }
        champ.tap()
        champ.typeText("HIIT")
        pause(1.0)
        let ligne = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "HIIT sur tapis")).firstMatch
        guard attendre(ligne, 6, "h-ligne") else { arbre("h-feuille"); return }
        ligne.tap(); pause(0.5)
        bouton("Ajouter (1)").tap()
        let go = bouton("Allez, go")
        guard attendre(go, 10, "h-slider") else { return }
        pause(1.5)
        glisser(go, "h-go")
        pause(4.0)
        capture("h1-depart-4s")
        arbre("h1-depart")
        let nav = ["Accueil", "Home", "Exercices", "Exercises", "Profil", "Profile"]
            .filter { app.buttons[$0].exists && app.buttons[$0].isHittable }
        log("HIIT : boutons de nav touchables = \(nav)")
        pause(1.0)
        capture("h2-depart-5s")
        pause(22.0)
        capture("h3-apres-27s-sans-toucher")
        arbre("h3-apres-27s")
        log("HIIT à 27 s sans toucher : Stop = \(app.buttons["Stop"].exists), Go = \(app.buttons["Go"].exists)")

        // La vitesse : un vrai glissé vers la droite sur le galet.
        let o = app.coordinate(withNormalizedOffset: .zero)
        let km = app.staticTexts["km/h"]
        let cx = km.exists ? km.frame.midX : 196, cy = km.exists ? km.frame.minY - 30 : 530
        o.withOffset(CGVector(dx: cx, dy: cy))
            .press(forDuration: 0.1, thenDragTo: o.withOffset(CGVector(dx: cx + 150, dy: cy)),
                   withVelocity: 300, thenHoldForDuration: 0.3)
        pause(1.2)
        capture("h4-vitesse-reglee")
        log("vitesse après glissé : \(vitesseLue())")

        // Stop (un toucher court) : la récup, la pop flamme, le 0.
        app.buttons["Stop"].tap()
        pause(1.0)
        capture("h5-stop-1s")
        arbre("h5-stop-1s")
        pause(1.5)
        capture("h6-stop-2-5s")
        log("après Stop : Go = \(app.buttons["Go"].exists), vitesse = \(vitesseLue())")
        // La pop flamme se ferme par « Close » (un toucher à côté la referme
        // aussi, sans relancer : vu au premier passage).
        let close = app.buttons["Close"]
        log("pop flamme : Close = \(close.exists)")
        if close.exists { close.tap(); pause(1.0); capture("h6b-pop-fermee") }
        pause(14.0)
        capture("h7-recup-17s-sans-toucher")
        log("récup à 17 s sans toucher : Go = \(app.buttons["Go"].exists), Stop = \(app.buttons["Stop"].exists)")

        // Go : l'effort repart, de 0.
        if app.buttons["Go"].exists { app.buttons["Go"].tap() }
        pause(1.5)
        capture("h8-reprise")
        log("après Go : Stop = \(app.buttons["Stop"].exists), vitesse = \(vitesseLue())")
        pause(1.5)
        capture("h8b-reprise-3s")

        // Maintiens pour terminer.
        let b = app.buttons["Stop"].exists ? app.buttons["Stop"] : app.buttons["Go"]
        b.press(forDuration: 1.8)
        pause(2.0)
        capture("h9-fini-2s")
        arbre("h9-fini-2s")
        pause(4.0)
        capture("h10-fini-6s")
        let nav2 = ["house.fill", "figure.strengthtraining.traditional", "person", "gearshape"]
            .filter { app.buttons[$0].exists && app.buttons[$0].isHittable }
        log("après Finish : boutons de nav touchables = \(nav2)")
    }

    /// Le chiffre du galet (le seul texte numérique au-dessus de « km/h »).
    func vitesseLue() -> String {
        let km = app.staticTexts["km/h"]
        guard km.exists else { return "?" }
        let f = km.frame
        let t = app.staticTexts.allElementsBoundByIndex.first {
            $0.frame.maxY <= f.minY + 2 && $0.frame.maxY > f.minY - 90
                && abs($0.frame.midX - f.midX) < 40 && Int($0.label) != nil
        }
        return t?.label ?? "?"
    }
}
