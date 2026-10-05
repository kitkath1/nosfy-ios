import XCTest

/// LA SÉANCE DE BOUT EN BOUT, À VRAIS TOUCHERS (03-10, retours TestFlight 86) :
/// la séance vide, l'ajout, trois séries (slider, Stop, note, Valider, repos),
/// le slider « Terminer » ; « Refaire » sur un compte qui a un passé ; le HIIT.
/// Monté dans une COPIE jetable par `monte.sh` — le dépôt n'a pas de cible de test.
final class AppleUITests: XCTestCase {
    var app: XCUIApplication!
    static let preuves = ProcessInfo.processInfo.environment["APPLE_PREUVES"]
        ?? "/tmp/apple-preuves"

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

    // MARK: 1 — vide → ajout en deux temps → séance → playlist → tirage Spotify → 3 séries

    func test01_parcours() {
        lancer(["-skipAuth", "-sansPlafond", "-demoData", "-goAuto"])
        guard attendre(texte("Compose ta séance"), 45, "vide") else { return }
        pause(2.0)
        capture("01-vide")
        log("vide : Refaire = \(bouton("Refaire").exists)")
        // le + du centre
        let plus = app.buttons.matching(NSPredicate(format: "label == %@", "plus")).firstMatch
        let p = plus.exists ? plus : app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 196, dy: 396)) as Any
        if let b = p as? XCUIElement { b.tap() } else { taper(196, 396) }
        let champ = app.textFields.firstMatch
        guard attendre(champ, 8, "feuille") else { return }
        pause(1.0)
        capture("02-feuille-zones")
        arbre("02-feuille-zones")
        // la zone Abdos (2e carré), puis le crunch et le gainage
        let abdos = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@", "Abdos")).firstMatch
        if abdos.exists { abdos.tap() } else { taper(141, 290) }
        pause(1.0)
        capture("03-feuille-exos")
        for nom in ["Crunch au sol", "Gainage"] {
            let l = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", nom)).firstMatch
            if attendre(l, 5, "ligne-\(nom)") { l.tap(); pause(0.4) }
        }
        bouton("Ajouter (").tap()
        // l'arrivée
        pause(0.4); capture("04-arrivee-a")
        pause(0.5); capture("04-arrivee-b")
        pause(1.6); capture("05-prete")
        arbre("05-prete")
        log("page : Prête = \(texte("Prête.").exists), Terminer = \(bouton("Terminer").exists)")
        // la playlist : toucher la ligne du crunch
        let ligneCrunch = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Crunch au sol")).firstMatch
        guard attendre(ligneCrunch, 6, "ligne-crunch") else { return }
        ligneCrunch.tap()
        pause(1.2)
        capture("06-playlist")
        arbre("06-playlist")
        log("playlist : Ajouter une série = \(bouton("Ajouter une série").exists), À suivre = \(texte("À SUIVRE").exists)")
        if bouton("Ajouter une série").exists { bouton("Ajouter une série").tap(); pause(0.8); capture("07-playlist-plus-une") }
        // fermer la playlist (toucher le voile en haut)
        taper(196, 60); pause(1.0)
        // lancer la 1re série (le slider)
        let go = bouton("Allez, go")
        guard attendre(go, 8, "slider-go") else { return }
        glisser(go, "go")
        serie(1)
        // au repos : l'onglet Séries = la playlist du cadran
        let series = app.buttons["Séries"]
        if attendre(series, 10, "onglet-series") {
            series.tap(); pause(1.2)
            capture("08-cadran-playlist")
            arbre("08-cadran-playlist")
            log("cadran playlist : Ajouter une série = \(bouton("Ajouter une série").exists), À suivre = \(texte("À SUIVRE").exists)")
            app.buttons["Cadran"].tap(); pause(0.6)
        }
        // la pop « YOU WIN » se ferme d'elle-même : on attend le repos posé
        let lancer = bouton("Lancer")
        attendre(lancer, 12, "repos-slider")
        pause(1.5)
        capture("08b-repos")
        // LE TIRAGE SPOTIFY : tirer le cadran vers le bas
        let o = app.coordinate(withNormalizedOffset: .zero)
        o.withOffset(CGVector(dx: 196, dy: 300))
            .press(forDuration: 0.1, thenDragTo: o.withOffset(CGVector(dx: 196, dy: 560)), withVelocity: 400, thenHoldForDuration: 0.1)
        pause(0.6); capture("09-tirage-a")
        pause(1.6); capture("10-apres-tirage")
        arbre("10-apres-tirage")
        log("après tirage : En cours = \(texte("En cours.").exists), Prête = \(texte("Prête.").exists), cadran = \(app.buttons["Cadran"].exists)")
        // la suite : relancer depuis la page et finir
        let lancer2 = bouton("Allez, go")
        if attendre(lancer2, 10, "slider-go-2") {
            glisser(lancer2, "go-2"); serie(2)
            let lancer3 = bouton("Lancer")
            if attendre(lancer3, 12, "lancer-3") { glisser(lancer3, "lancer-3"); serie(3) }
        }
        pause(2.5)
        capture("11-fin-serie-crunch")
        taper(37, 96); pause(2.0)
        capture("12-page-apres-crunch")
        arbre("12-page-apres-crunch")
    }

    /// Une série : attendre l'effort, Stop, la note (sans kg pour le crunch), Valider.
    func serie(_ i: Int) {
        let passer = bouton("Passer l'animation")
        if passer.waitForExistence(timeout: 6) { passer.tap() }
        let enCours = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "en cours")).firstMatch
        attendre(enCours, 25, "en-cours-\(i)")
        pause(2.5)
        capture("s\(i)-a-effort")
        let valider = bouton("Valider")
        for essai in 1...3 where !valider.exists {
            let t = texte("Stop")
            if t.exists { let f = t.frame; taper(f.midX, f.minY - 52) } else { log("Stop absent \(i).\(essai)") }
            _ = valider.waitForExistence(timeout: 4)
        }
        guard attendre(valider, 2, "valider-\(i)") else { return }
        pause(0.8)
        capture("s\(i)-b-note")
        arbre("s\(i)-note")
        log("note \(i) : kg à l'écran = \(app.staticTexts["kg"].exists), reps = \(app.staticTexts["reps"].exists)")
        valider.tap()
        pause(2.0)
        capture("s\(i)-c-apres-valider")
    }

    // MARK: 2 — le désordre : le gainage avant les Woodchopper, et glisser pour supprimer (05-10)

    func test02_desordre() {
        lancer(["-skipAuth", "-sansPlafond", "-goAuto"])
        let compose = texte("Compose ta séance")
        guard attendre(compose, 45, "vide") else { return }
        pause(1.5)
        capture("d01-vide-tete")
        // le + : 30 pt au-dessus du titre, 96 de haut
        taper(196, compose.frame.minY - 30 - 48)
        let champ = app.textFields.firstMatch
        guard attendre(champ, 8, "feuille") else { return }
        champ.tap(); champ.typeText("Woodchopper")
        pause(0.8)
        let w = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Woodchopper poulie haute")).firstMatch
        if attendre(w, 5, "w") { w.tap() }
        champ.tap(); champ.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 11) + "Gainage")
        pause(0.8)
        let g = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Gainage")).firstMatch
        if attendre(g, 5, "g") { g.tap() }
        bouton("Ajouter (").tap()
        pause(2.5)
        capture("d02-prete")
        // la playlist du GAINAGE, pas du premier exercice
        let lg = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Gainage")).firstMatch
        let ligneG = lg.exists ? lg : app.staticTexts["Gainage"]
        guard attendre(ligneG, 6, "ligne-gainage") else { arbre("d-absent-gainage"); return }
        ligneG.tap()
        pause(1.2)
        capture("d03-playlist-gainage")
        arbre("d03-playlist-gainage")
        // la série 1 du gainage : sa ligne (« Série 1 »)
        let s1 = app.staticTexts["Série 1"]
        guard attendre(s1, 5, "serie1-gainage") else { return }
        s1.tap()
        let enCours = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "en cours")).firstMatch
        let passer = bouton("Passer l'animation")
        if passer.waitForExistence(timeout: 8) { passer.tap() }
        attendre(enCours, 25, "gainage-en-cours")
        pause(3.0)
        capture("d04-gainage-effort")
        let valider = bouton("Valider")
        for _ in 1...3 where !valider.exists {
            let t = texte("Stop"); if t.exists { let f = t.frame; taper(f.midX, f.minY - 52) }
            _ = valider.waitForExistence(timeout: 4)
        }
        if attendre(valider, 2, "gainage-note") {
            pause(0.8)
            capture("d05-gainage-note")
            arbre("d05-gainage-note")
            log("note gainage : reps = \(app.staticTexts["reps"].exists), kg = \(app.staticTexts["kg"].exists)")
            valider.tap()
        }
        pause(3.0)
        capture("d06-apres-note")
        // retour à la page (le chevron du cadran)
        taper(37, 96); pause(2.2)
        capture("d07-page")
        arbre("d07-page")
        // glisser la ligne Woodchopper vers la gauche, puis Supprimer
        let lw = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Woodchopper")).firstMatch
        if attendre(lw, 6, "ligne-w") {
            let f = lw.frame
            let o = app.coordinate(withNormalizedOffset: .zero)
            o.withOffset(CGVector(dx: 300, dy: f.midY)).press(forDuration: 0.05, thenDragTo: o.withOffset(CGVector(dx: 140, dy: f.midY)), withVelocity: 600, thenHoldForDuration: 0.1)
            pause(0.8)
            capture("d08-glisse")
            let sup = app.buttons["Supprimer"]
            if attendre(sup, 3, "supprimer") { sup.tap(); pause(1.2) }
            capture("d09-supprime")
            log("après suppression : Woodchopper = \(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Woodchopper")).firstMatch.exists)")
        }
    }
}
