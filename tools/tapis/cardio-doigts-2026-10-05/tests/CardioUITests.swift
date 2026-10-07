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

    // MARK: 06-10 — la vitesse dans tous les sens, et le contrôle total

    /// Le km/h affiché dans la pastille du bas (un nombre seul, au milieu de l'écran).
    func vitesse() -> String {
        let t = app.staticTexts.allElementsBoundByIndex.filter {
            !$0.label.isEmpty && $0.label.allSatisfy(\.isNumber) && $0.frame.midY > 380 && $0.frame.midY < 620
        }
        return t.first?.label ?? "?"
    }
    func moins(_ n: Int) {
        let b = app.buttons["Moins vite"]
        guard attendre(b, 10, "moins") else { return }
        for _ in 0..<n { b.tap(); pause(0.2) }
    }
    func verifier(_ attendu: String, _ quoi: String) {
        let v = vitesse()
        log("\(v == attendu ? "OK" : "KO") \(quoi) : \(v) (attendu \(attendu))")
        XCTAssertEqual(v, attendu, quoi)
    }

    func test03_vitesse_hiit() {
        lancer(["-skipAuth", "-sansPlafond", "-demoData", "-goAuto", "-bancHiit", "direct"])
        guard attendre(boutonDuBas("Go"), 60, "go") else { return }
        pause(1.5); capture("v01-pret")
        verifier("0", "au départ")
        plus(5); verifier("5", "+ ×5")
        app.buttons["Plus vite"].press(forDuration: 2.6); pause(0.5)
        verifier("20", "maintenir + jusqu'à la butée")
        moins(25); verifier("0", "− ×25, plancher")
        plus(12); verifier("12", "+ ×12")
        capture("v02-12-avant-go")
        // contrôle total : rien ne part seul
        pause(5); log("après 5 s sans toucher : go = \(boutonDuBas("Go").exists)")
        XCTAssertTrue(boutonDuBas("Go").exists, "rien ne part seul")
        boutonDuBas("Go").tap(); pause(2)
        verifier("12", "le GO garde la vitesse")
        capture("v03-effort")
        // toucher la pastille du chrono en courant : rien
        pt(196, 0.315 * app.frame.height).tap(); pause(1)
        log("toucher la pastille : stop toujours là = \(app.buttons["Stop"].exists)")
        XCTAssertTrue(app.buttons["Stop"].exists, "la pastille n'arrête rien")
        plus(2); verifier("14", "+ ×2 pendant l'effort")
        pause(6)   // rien ne s'arrête seul
        XCTAssertTrue(app.buttons["Stop"].exists, "rien ne s'arrête seul")
        app.buttons["Stop"].tap(); pause(1.5)
        capture("v04-pause")
        verifier("0", "après Stop")
        pause(6); log("pause tenue 6 s : terminer = \(app.staticTexts["Terminer"].exists)")
        XCTAssertTrue(app.staticTexts["Terminer"].exists, "la pause attend")
        plus(8); verifier("8", "+ ×8 en pause")
        toucherSousMot("Reprendre"); pause(2)
        verifier("8", "Reprendre garde la vitesse")
        capture("v05-set2")
        pause(2)
        app.buttons["Stop"].tap(); pause(1.5)
        toucherSousMot("Terminer"); pause(2.5)
        capture("v06-fin"); arbre("v06-fin")
        let lignes = app.staticTexts.allElementsBoundByIndex.map(\.label).filter { $0.contains("km/h") }
        log("fin : \(lignes)")
        XCTAssertTrue(lignes.contains { $0.hasSuffix("· 14 km/h") }, "set 1 à 14")
        XCTAssertTrue(lignes.contains { $0.hasSuffix("· 8 km/h") }, "set 2 à 8")
        XCTAssertTrue(lignes.contains("14 km/h"), "max 14")
    }

    func test04_escalier() {
        lancer(["-skipAuth", "-sansPlafond", "-openTab", "exercises", "-openExercise", "escalier", "-departSerieAuto"])
        guard attendre(boutonDuBas("Go"), 40, "go") else { return }
        pause(1.5); capture("e01-pret")
        moins(10); verifier("1", "− ×10, niveau plancher")
        plus(20); verifier("15", "+ ×20, niveau plafond")
        moins(6); verifier("9", "− ×6")
        boutonDuBas("Go").tap(); pause(3)
        verifier("9", "le GO garde le niveau")
        capture("e02-effort")
        app.buttons["Pause"].tap(); pause(1.5)
        capture("e03-pause")
        toucherSousMot("Terminer"); pause(2.5)
        capture("e04-fin")
    }

    // MARK: 06-10 — voir sa séance en pleine course, puis revenir

    func test05_seance_pendant_hiit() {
        lancer(["-skipAuth", "-sansPlafond", "-demoData", "-goAuto", "-bancHiit", "direct"])
        guard attendre(boutonDuBas("Go"), 60, "go") else { return }
        plus(10); boutonDuBas("Go").tap(); pause(3)
        capture("s01-effort")
        // la pilule du haut : son temps, à gauche (le ■ à droite ouvre la carte STOP)
        pt(95, 26).tap(); pause(2.5)
        capture("s02-seance-ouverte"); arbre("s02-seance-ouverte")
        let enCours = app.staticTexts["En cours."].exists, toutFait = app.staticTexts["Tout est fait."].exists
        log("page pendant le HIIT : en cours = \(enCours) · tout est fait = \(toutFait)")
        XCTAssertTrue(enCours && !toutFait, "la page dit En cours pendant le HIIT")
        // le slider « Retour · HIIT » : un vrai glissé
        let s = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Retour")).allElementsBoundByIndex
            .max { $0.frame.minY < $1.frame.minY }
        if let s, s.frame.minY > 600 {
            pt(s.frame.minX + 34, s.frame.midY).press(forDuration: 0.1, thenDragTo: pt(s.frame.maxX - 4, s.frame.midY),
                                                     withVelocity: XCUIGestureVelocity(500), thenHoldForDuration: 0.2)
            pause(3)
        } else { log("slider Retour ABSENT"); arbre("absent-slider-retour") }
        capture("s03-retour-hiit")
        let stop = app.buttons["Stop"].exists
        log("retour au HIIT : stop = \(stop) · vitesse = \(vitesse())")
        XCTAssertTrue(stop, "le HIIT tourne toujours")
        app.buttons["Stop"].tap(); pause(1.5)
        toucherSousMot("Terminer"); pause(2.5)
        capture("s04-fin")
        let b = app.buttons["Retour à la séance"]
        guard attendre(b, 5, "bouton-retour") else { return }
        b.tap(); pause(3)
        capture("s05-seance-finie")
        log("après le bouton : tout est fait (page) = \(app.staticTexts["Tout est fait."].exists) · TA SÉANCE = \(app.staticTexts["TA SÉANCE"].exists)")
    }

    // MARK: 06-10 — l'écran noir après un tirage du cadran (son TestFlight 89)

    func glisserSlider(_ debut: String) -> Bool {
        let b = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", debut)).allElementsBoundByIndex
            .max { $0.frame.minY < $1.frame.minY }
        guard let b, b.exists else { log("slider \(debut) ABSENT"); return false }
        let f = b.frame
        pt(f.minX + 30, f.midY).press(forDuration: 0.15, thenDragTo: pt(f.maxX - 4, f.midY),
                                       withVelocity: XCUIGestureVelocity(520), thenHoldForDuration: 0.2)
        return true
    }
    func tirerCadran(_ nom: String) {
        pt(196, 300).press(forDuration: 0.1, thenDragTo: pt(196, 620),
                           withVelocity: XCUIGestureVelocity(500), thenHoldForDuration: 0.1)
        pause(0.5); capture("\(nom)-a")
        pause(2.0); capture("\(nom)-b"); arbre("\(nom)-b")
        let page = app.staticTexts["TA SÉANCE"].exists
        let cadran = app.buttons["Cadran"].exists
        let touchable = app.buttons.allElementsBoundByIndex.filter { $0.isHittable }.count
        log("\(nom) : page = \(page) · cadran = \(cadran) · boutons touchables = \(touchable)")
    }
    func attendreEffort(_ i: Int) {
        let passer = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Passer l'animation")).firstMatch
        if passer.waitForExistence(timeout: 6) { passer.tap() }
        let enCours = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "en cours")).firstMatch
        attendre(enCours, 25, "en-cours-\(i)")
        pause(1.5)
    }
    func stopEtValider(_ i: Int) {
        let valider = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Valider")).firstMatch
        for _ in 1...3 where !valider.exists {
            let t = app.staticTexts.matching(NSPredicate(format: "label == %@", "Stop")).firstMatch
            if t.exists { pt(t.frame.midX, t.frame.minY - 50).tap() }
            _ = valider.waitForExistence(timeout: 4)
        }
        if valider.exists { valider.tap() } else { log("valider ABSENT \(i)") }
        pause(2)
    }

    func test06_tirage_cadran() {
        lancer(["-skipAuth", "-sansPlafond", "-demoData", "-goAuto"])
        let refaire = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Refaire")).firstMatch
        guard attendre(refaire, 45, "refaire") else { return }
        pt(refaire.frame.maxX - 50, refaire.frame.midY).tap(); pause(3)
        capture("c01-seance")
        guard glisserSlider("Allez, go") else { return }
        attendreEffort(1)
        capture("c02-effort")
        // ① tirer PENDANT l'effort : le cadran résiste, la série continue
        tirerCadran("c03-tire-effort")
        stopEtValider(1)
        // ② tirer PENDANT le repos : la page de séance
        pause(1.5)
        tirerCadran("c04-tire-repos")
        // ③ revenir au cadran par le slider de la page, puis tirer encore
        if glisserSlider("Allez, go") {
            pause(1.0); capture("c05-relance-a")
            tirerCadran("c06-tire-pendant-compte")   // pendant le 3-2-1 / l'arrivée
            pause(2)
            if glisserSlider("Allez, go") { attendreEffort(2); tirerCadran("c07-tire-effort-2") }
        }
        // ④ toucher une ligne puis ▶ de la playlist, et tirer
        capture("c08-fin"); arbre("c08-fin")
    }

    /// Son cas exact (06-10, TestFlight 89, écran noir) : repos → tirage → page →
    /// retour sur la MÊME série encore au repos. Avant : le cadran restait
    /// descendu à 900 pt (le fond de séance seul, rien à toucher).
    func test07_retour_pendant_repos() {
        lancer(["-skipAuth", "-sansPlafond", "-demoData", "-goAuto"])
        let refaire = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Refaire")).firstMatch
        guard attendre(refaire, 45, "refaire") else { return }
        pt(refaire.frame.maxX - 50, refaire.frame.midY).tap(); pause(3)
        // une série de plus au premier exercice (la playlist de sa ligne)
        let titre = app.staticTexts.matching(NSPredicate(format: "label == %@", "Prête.")).firstMatch
        let y = titre.exists ? titre.frame.maxY + 190 : 380
        pt(250, y).tap(); pause(1.5)
        let ajouter = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Ajouter une série")).firstMatch
        if attendre(ajouter, 4, "ajouter-serie") { ajouter.tap(); pause(0.8) }
        pt(196, 60).tap(); pause(1.2)
        capture("r01-deux-series")
        guard glisserSlider("Allez, go") else { return }
        attendreEffort(1)
        stopEtValider(1)
        pause(1.5)
        capture("r02-repos")
        tirerCadran("r03-tire-repos")
        // retour sur la même série, toujours au repos
        _ = glisserSlider("Allez, go")
        pause(2.5)
        capture("r04-retour"); arbre("r04-retour")
        let cadran = app.buttons["Cadran"]
        log("retour pendant le repos : cadran visible = \(cadran.exists && cadran.isHittable) · cadran y = \(cadran.frame.minY)")
        XCTAssertTrue(cadran.exists && cadran.isHittable && cadran.frame.minY < 300, "le cadran est à sa place")
    }

    /// (06-10, « repos comme les autres exos ! ») : la toute dernière série de la
    /// séance a son repos, puis le slider rend la page.
    func test08_dernier_repos() {
        lancer(["-skipAuth", "-sansPlafond", "-demoData", "-goAuto"])
        let compose = app.staticTexts.matching(NSPredicate(format: "label == %@", "Compose ta séance")).firstMatch
        guard attendre(compose, 45, "vide") else { return }
        pause(1.2)
        pt(196, compose.frame.minY - 30 - 48).tap()
        let champ = app.textFields.firstMatch
        guard attendre(champ, 8, "feuille") else { return }
        champ.tap(); champ.typeText("Crunch"); pause(0.8)
        let l = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Crunch au sol")).firstMatch
        guard attendre(l, 5, "crunch") else { return }
        l.tap(); pause(0.4)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Ajouter (")).firstMatch.tap()
        pause(3)
        capture("d01-une-serie"); arbre("d01-une-serie")
        guard glisserSlider("Allez, go") else { return }
        attendreEffort(1)
        stopEtValider(1)
        pause(1.5)
        capture("d02-dernier-repos"); arbre("d02-dernier-repos")
        let repos = app.staticTexts["Repos"].exists, dernier = app.staticTexts["Dernier repos"].exists
        log("après la dernière série : repos = \(repos) · dernier repos = \(dernier)")
        XCTAssertTrue(repos, "un repos après la dernière série")
        guard glisserSlider("Retour") else { XCTFail("slider Retour absent"); return }
        pause(3)
        capture("d03-page"); arbre("d03-page")
        log("page : tout est fait = \(app.staticTexts["Tout est fait."].exists)")
        XCTAssertTrue(app.staticTexts["Tout est fait."].exists, "la page, tout est fait")
    }

    // MARK: 06-10 — les retours du TestFlight 90

    func ouvrirSeanceRefaite() -> Bool {
        lancer(["-skipAuth", "-sansPlafond", "-demoData", "-goAuto"])
        let refaire = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Refaire")).firstMatch
        guard attendre(refaire, 45, "refaire") else { return false }
        pt(refaire.frame.maxX - 50, refaire.frame.midY).tap(); pause(3)
        return true
    }
    func ouvrirPremiereLigne() {
        let titre = app.staticTexts.matching(NSPredicate(format: "label == %@", "Prête.")).firstMatch
        let enCours = app.staticTexts.matching(NSPredicate(format: "label == %@", "En cours.")).firstMatch
        let t = titre.exists ? titre : enCours
        let y = t.exists ? t.frame.maxY + 190 : 380
        pt(250, y).tap(); pause(1.5)
    }
    var ajouterSerie: XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Ajouter une série")).firstMatch
    }

    /// ① Quinze séries, défiler, « Ajouter » toujours là.
    func test09_liste_longue() {
        guard ouvrirSeanceRefaite() else { return }
        ouvrirPremiereLigne()
        guard attendre(ajouterSerie, 5, "ajouter") else { return }
        for _ in 0..<14 { ajouterSerie.tap(); pause(0.25) }
        pause(0.8); capture("l01-quinze")
        let series = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Série ")).count
        log("séries visibles : \(series) · ajouter touchable = \(ajouterSerie.isHittable)")
        // défiler vers le bas puis vers le haut DANS la liste
        pt(200, 700).press(forDuration: 0.05, thenDragTo: pt(200, 520), withVelocity: XCUIGestureVelocity(600), thenHoldForDuration: 0.1)
        pause(0.8); capture("l02-defile-bas")
        pt(200, 520).press(forDuration: 0.05, thenDragTo: pt(200, 720), withVelocity: XCUIGestureVelocity(600), thenHoldForDuration: 0.1)
        pause(0.8); capture("l03-defile-haut")
        let ouverte = ajouterSerie.exists && ajouterSerie.isHittable
        log("après les deux défilements : la liste est ouverte = \(ouverte)")
        XCTAssertTrue(ouverte, "défiler vers le haut ne ferme plus la feuille")
        ajouterSerie.tap(); pause(0.5)
        log("ajouter encore : ok")
    }

    /// ② Ajouter des séries, puis enchaîner deux passages sans geler ; ③ le rang.
    func test10_series_ajoutees() {
        guard ouvrirSeanceRefaite() else { return }
        ouvrirPremiereLigne()
        guard attendre(ajouterSerie, 5, "ajouter") else { return }
        for _ in 0..<3 { ajouterSerie.tap(); pause(0.3) }
        pt(196, 60).tap(); pause(1.2)
        for i in 1...3 {
            guard glisserSlider("Allez, go") || glisserSlider("Lancer") else { log("slider absent au tour \(i)"); break }
            attendreEffort(i)
            let rang = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Série ")).firstMatch.label
            log("tour \(i) : \(rang)")
            stopEtValider(i)
            pause(2.5)
            capture("a0\(i)-apres-valider")
            // retour à la page, puis reprise depuis la page
            tirerCadran("a0\(i)-tire")
        }
        capture("a09-fin"); arbre("a09-fin")
        log("page après trois passages : \(app.staticTexts.allElementsBoundByIndex.map(\.label).filter { $0.contains("reps") || $0.contains("séries") }.prefix(4))")
    }

    /// ⑤ Corriger une série faite.
    func test11_corriger() {
        guard ouvrirSeanceRefaite() else { return }
        guard glisserSlider("Allez, go") else { return }
        attendreEffort(1)
        stopEtValider(1)
        pause(2)
        tirerCadran("k01-page")
        ouvrirPremiereLigne()
        capture("k02-playlist"); arbre("k02-playlist")
        // la série faite : la première ligne de la liste
        let faite = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", " reps")).allElementsBoundByIndex
            .filter { $0.frame.minY > 400 }.first
        guard let faite else { log("série faite ABSENTE"); return }
        log("avant : \(faite.label)")
        faite.tap(); pause(1.5)
        capture("k03-feuille"); arbre("k03-feuille")
        let valider = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Valider")).firstMatch
        guard attendre(valider, 4, "feuille-correction") else { return }
        // la molette : glisser vers la gauche monte les reps
        let m = valider.frame
        pt(196, m.minY - 40).press(forDuration: 0.05, thenDragTo: pt(60, m.minY - 40), withVelocity: XCUIGestureVelocity(300), thenHoldForDuration: 0.1)
        pause(0.8); capture("k04-molette")
        valider.tap(); pause(1.5)
        capture("k05-corrigee"); arbre("k05-corrigee")
        let apres = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", " reps")).allElementsBoundByIndex
            .filter { $0.frame.minY > 400 }.first?.label ?? "?"
        log("après : \(apres)")
    }

    /// (07-10) Rajouter un exercice DÉJÀ dans la séance : une série de plus.
    func test12_meme_exercice() {
        guard ouvrirSeanceRefaite() else { return }
        capture("m01-avant"); arbre("m01-avant")
        let avant = app.staticTexts.allElementsBoundByIndex.map(\.label).filter { $0.contains("série") || $0.contains("séries") }
        log("avant : \(avant.prefix(4))")
        // le « + » du bas
        let plus = app.buttons.matching(NSPredicate(format: "label == %@", "plus")).allElementsBoundByIndex
            .max { $0.frame.minY < $1.frame.minY }
        if let plus { plus.tap() } else { pt(358, 790).tap() }
        let champ = app.textFields.firstMatch
        guard attendre(champ, 8, "feuille") else { return }
        champ.tap(); champ.typeText("Woodchopper poulie haute"); pause(0.8)
        let l = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Woodchopper poulie haute")).firstMatch
        guard attendre(l, 5, "woodchopper") else { return }
        l.tap(); pause(0.4)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Ajouter (")).firstMatch.tap()
        pause(2.5)
        capture("m02-apres"); arbre("m02-apres")
        let lignes = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Woodchopper poulie haute")).count
        let apres = app.staticTexts.allElementsBoundByIndex.map(\.label).filter { $0.contains("série") || $0.contains("séries") }
        log("après : lignes Woodchopper = \(lignes) · \(apres.prefix(4))")
        XCTAssertEqual(lignes, 1, "une seule ligne Woodchopper")
    }
}
