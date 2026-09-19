import XCTest

/// L'état relu de la sonde (`clé=valeur;…`).
struct EtatPilule {
    let brut: String
    private let d: [String: String]
    init?(_ valeur: Any?) {
        guard let s = valeur as? String, s.contains("navVis=") else { return nil }
        brut = s
        var dd = [String: String]()
        for part in s.split(separator: ";") {
            let kv = part.split(separator: "=", maxSplits: 1)
            if kv.count == 2 { dd[String(kv[0])] = String(kv[1]) }
        }
        d = dd
    }
    var navVisible: Bool { d["navVis"] == "1" }
    var navH: Double { Double(d["navH"] ?? "") ?? -1 }
    var mini: Bool { d["mini"] == "1" }
    var page: String { d["page"] ?? "?" }
    var seance: Bool { d["seance"] == "1" }
    var dansIle: Bool { d["dansIle"] == "1" }
    var enDrag: Bool { d["enDrag"] == "1" }
    var enVol: Bool { d["enVol"] == "1" }
    var yRatio: Double { Double(d["yRatio"] ?? "") ?? -1 }
    var grandPlayer: Int { Int(d["gp"] ?? "") ?? -1 }
    var entreesIle: Int { Int(d["ile"] ?? "") ?? -1 }
    var navFutCachee: Bool { d["navCachee"] == "1" }
    var nbDrag: Int { Int(d["drag"] ?? "") ?? -1 }
    var nbChanged: Int { Int(d["chg"] ?? "") ?? -1 }
    var nbTap: Int { Int(d["tap"] ?? "") ?? -1 }
    var nbDehors: Int { Int(d["out"] ?? "") ?? -1 }
    /// Le STOP de l'île a été pressé (V2 : il vit à DROITE de la fine).
    var nbStop: Int { Int(d["stop"] ?? "") ?? -1 }
    /// Le geste est COMMIS : ni doigt, ni vol de rappel en cours.
    var pose: Bool { !enDrag && !enVol }
}

final class BancPilule {
    let app = XCUIApplication()

    func lancer(_ args: [String]) {
        // ⚠️ `-piluleSortie` DEPUIS LE 05-09 : la pastille VOLE dans l'île
        // 0,55 s après le départ de séance (le nouveau défaut). Tous les
        // cas de ce banc ont été écrits dans le monde d'avant, pastille
        // posée — sans ce barreau, `attendreSeance()` guette un corps qui
        // n'est plus monté et TOUT est rouge avant le premier geste.
        // L'entrée dans l'île reste testée : cas 05 (la porte ne s'ouvre
        // pas par accident), cas 06a/07a (elle s'ouvre au jet voulu).
        app.launchArguments = ["-fouettagePilule", "-skipAuth",
                               "-piluleSortie"] + args
        app.launch()
        XCTAssertTrue(sonde.waitForExistence(timeout: 60),
            "LANCEMENT INVALIDE — la sonde n'est jamais apparue")
        XCTAssertTrue(attendre(20) { $0.navH > 0 },
            "l'état de nav n'est jamais publié ; sonde=\(etat()?.brut ?? "ABSENTE")")
        Thread.sleep(forTimeInterval: 1.5)
    }

    var sonde: XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: "fouettage-pilule-sonde").firstMatch
    }
    var pilule: XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: "fouettage-pilule").firstMatch
    }
    var ile: XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: "fouettage-ile").firstMatch
    }
    var grandPlayer: XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier IN %@",
                                  ["fouettage-grand-player", "seance-detail"]))
            .firstMatch
    }
    var bande: XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: "fouettage-bande").firstMatch
    }

    func etat() -> EtatPilule? { EtatPilule(sonde.value) }

    // MARK: viser — on LIT les rects, on ne les calcule jamais

    func pointEcran(x: CGFloat, y: CGFloat) -> XCUICoordinate {
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: x, dy: y))
    }

    /// Le centre VISIBLE de la pilule — jamais corrigé : si la zone
    /// tactile réelle est décalée, c'est un bug à RÉVÉLER, pas à
    /// contourner (la loi tapis : `.offset` déplace les pixels, pas le hit).
    func centrePilule() -> XCUICoordinate {
        let r = pilule.frame
        XCTAssertTrue(r.height > 10, "la pilule n'a pas de rect (r=\(r))")
        return pointEcran(x: r.midX, y: r.midY)
    }

    func centreIle() -> XCUICoordinate {
        let r = ile.frame
        XCTAssertTrue(r.height > 10, "l'île n'a pas de rect (r=\(r))")
        print("FOUET-PILULE rect ile=\(r)")
        // La capsule finit à y60 ; sa lèvre basse est accessible à y57.
        return pointEcran(x: r.midX, y: 57)
    }

    /// Le centre d'un glyphe de nav (0 = accueil, 1 = exercices, 2 = profil).
    /// La rangée vit à `padding(.bottom, 18)` du bord PHYSIQUE, hauteur 42 :
    /// son centre tombe à 18 + 21 = 39 pt du bas. Le pas horizontal est
    /// `NavGeo.pasOuvert` = 76 (trois glyphes centrés → −76, 0, +76).
    func centreGlyphe(_ i: Int) -> XCUICoordinate {
        let f = app.frame
        return pointEcran(x: f.midX + CGFloat(i - 1) * 76,
                          y: f.maxY - 39)
    }

    /// ⚠️ LA TABBAR NATIVE HANTE L'ÉCRAN ~1-2 s AU LANCEMENT EN SÉANCE
    /// (identifié par la session Foyer, 13-09, dump d'accessibilité) :
    /// malgré `.toolbarVisibility(.hidden, for: .tabBar)`, son Button
    /// « Exercices » reste HIT-TESTABLE au même point (196, 813) que le
    /// glyphe custom « Entraînements », et ABSORBE le premier tap par
    /// coordonnée sans naviguer. La fenêtre se referme seule — d'où
    /// l'intermittence (2 pass / 7 fail selon la chaleur du conteneur).
    /// AVANT le premier tap de nav par coordonnée, on attend qu'elle
    /// parte : sinon on mesure la tabbar fantôme, pas la nav custom.
    /// (Remède de banc ; le fantôme lui-même — un vrai risque doigt de
    /// 2 s — est un sujet CHÂSSIS, signalé, hors de ce banc.)
    func attendreNavPropre() {
        // ⚠️ L'INTERCEPTION EST TEMPORELLE, PAS INTERROGEABLE : la native
        // rapporte déjà `isHittable=false` pendant qu'elle avale le tap
        // réel par coordonnée (le hit-test système la met devant, l'API
        // XCUITest la dit cachée) — s'y fier fait sortir l'attente
        // aussitôt, et on remesure le fantôme. La seule vérité mesurée
        // est la contre-épreuve du Foyer : « +2 s avant le tap → passe ».
        // On pose donc un délai de tassement FERME (2,5 s), et on imprime
        // ce que l'arbre montre encore, pour garder l'œil sur la fenêtre.
        Thread.sleep(forTimeInterval: 2.5)
        let f = app.tabBars.buttons["Exercices"]
        if f.exists {
            print("FOUET-PILULE tabbar native encore dans l'arbre à 2,5 s "
                + "(hittable=\(f.isHittable)) — délai en place, on tape")
        }
    }

    // MARK: les gestes

    /// presse 0,08 s + drag + TENUE 0,22 s : vélocité ~nulle au lever →
    /// le commit se décide à la POSITION (déterministe).
    func glisser(_ depuis: XCUICoordinate, dx: CGFloat = 0, dy: CGFloat) {
        let fin = depuis.withOffset(CGVector(dx: dx, dy: dy))
        depuis.press(forDuration: 0.08, thenDragTo: fin,
                     withVelocity: .default, thenHoldForDuration: 0.22)
    }

    /// Un VRAI jet : pas de tenue au lever, vitesse élevée — c'est ce que
    /// la porte de l'île exige désormais (> 500 pt/s latéral).
    func jeter(_ depuis: XCUICoordinate, dx: CGFloat = 0, dy: CGFloat) {
        let fin = depuis.withOffset(CGVector(dx: dx, dy: dy))
        depuis.press(forDuration: 0.02, thenDragTo: fin,
                     withVelocity: 2400, thenHoldForDuration: 0.0)
    }

    func taper(_ ou: XCUICoordinate) { ou.tap() }

    @discardableResult
    func attendre(_ timeout: TimeInterval = 3.0,
                  _ cond: (EtatPilule) -> Bool) -> Bool {
        let fin = Date().addingTimeInterval(timeout)
        while Date() < fin {
            if let e = etat(), cond(e) { return true }
            Thread.sleep(forTimeInterval: 0.15)
        }
        return false
    }

    /// Tolérance anti-flake : 3 tentatives (le sim peut perdre UN
    /// toucher ; un vrai bug les perd TOUS), verdict sur l'état COMMIS,
    /// premier plan vérifié après chaque tentative.
    func gesteAttendu(_ nom: String, tentatives: Int = 3,
                      geste: () -> Void,
                      attendu: @escaping (EtatPilule) -> Bool) {
        for t in 1 ... tentatives {
            geste()
            let ok = attendre(4.0) { $0.pose && attendu($0) }
            // ⚠️ ON IMPRIME CHAQUE TENTATIVE. Un état final ne dit pas
            // CE QUI a échoué : si la 1re tentative a ouvert le player,
            // les 2 suivantes tapent dans un player plein écran et le
            // verdict final ment sur la cause.
            print("FOUET-PILULE \(nom) t\(t) ok=\(ok) "
                + "sonde=\(etat()?.brut ?? "ABSENTE")")
            auPremierPlan(nom)
            if ok {
                if t > 1 { print("FOUET-PILULE \(nom) : ok tentative \(t)") }
                return
            }
        }
        XCTFail("\(nom) — jamais obtenu après \(tentatives) tentatives ; "
            + "sonde=\(etat()?.brut ?? "ABSENTE")")
    }

    func auPremierPlan(_ nom: String) {
        XCTAssertEqual(app.state, .runningForeground,
                       "\(nom) — L'APP N'EST PLUS AU PREMIER PLAN")
    }

    /// Lance une séance avec la pastille VISIBLE. ⚠️ DEPUIS LE 06-09 LE
    /// FOYER GATE LA PASTILLE SUR LA HOME (WoopApp : `selection != .home`
    /// — la home « séance en cours » affiche déjà chrono et feu, la
    /// pastille y serait une deuxième lampe). Un banc pastille qui se
    /// lance sur la home guette donc un corps qui n'est JAMAIS monté et
    /// tout est rouge avant le premier geste — payé le 06-09, deux runs.
    /// `-openTab exercises` (domaine d'arguments UserDefaults) ouvre là
    /// où elle vit.
    func lancerEnSeanceAvecPilule() {
        lancer(["-activeWorkout", "-openTab", "exercises"])
        attendreSeance(avecPilule: true)
    }

    /// Attend une SÉANCE vivante — et la pilule seulement là où elle VIT.
    /// ⚠️ Depuis le gate du Foyer (06-09), la home en séance n'affiche PAS
    /// la pastille : les cas nav (01, 02, 08), lancés sur la home, ne
    /// guettent que la séance ; les cas pastille passent par
    /// `lancerEnSeanceAvecPilule()` qui exige aussi le corps.
    func attendreSeance(avecPilule: Bool = false) {
        XCTAssertTrue(attendre(20) { $0.seance },
            "séance jamais active ; sonde=\(etat()?.brut ?? "ABSENTE")")
        guard avecPilule else { return }
        XCTAssertTrue(pilule.waitForExistence(timeout: 10),
            "la pilule n'est jamais apparue en séance")
        // ⚠️ ON IMPRIME LES RECTS. Une marque posée APRÈS un `.position`
        // rend le rect du CONTENEUR, pas celui de l'objet — on viserait
        // le centre de l'écran en croyant viser la pastille. Ça se lit,
        // ça ne se devine pas.
        print("FOUET-PILULE rects : écran=\(app.frame) pilule=\(pilule.frame)")
    }
}
