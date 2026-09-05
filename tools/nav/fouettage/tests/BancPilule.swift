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
    /// Le geste est COMMIS : ni doigt, ni vol de rappel en cours.
    var pose: Bool { !enDrag && !enVol }
}

final class BancPilule {
    let app = XCUIApplication()

    func lancer(_ args: [String]) {
        app.launchArguments = ["-fouettagePilule", "-skipAuth"] + args
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
            .matching(identifier: "fouettage-grand-player").firstMatch
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
        // ⚠️ ON NE VISE PAS LE CENTRE DE L'ÎLE (04-09, mesuré) : son
        // centre tombe à y≈30, c'est-à-dire DANS le trou physique de la
        // Dynamic Island, que le système se réserve — un toucher n'y
        // arrive pas à l'app. Seule la lèvre BASSE de la capsule (sous le
        // trou) est atteignable au doigt. Si un jour le tap doit marcher
        // « sur l'île », c'est cette lèvre qu'il faut épaissir.
        return pointEcran(x: r.midX, y: r.maxY - 6)
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

    /// Attend une SÉANCE vivante et une pilule posée.
    func attendreSeance() {
        XCTAssertTrue(attendre(20) { $0.seance },
            "séance jamais active ; sonde=\(etat()?.brut ?? "ABSENTE")")
        XCTAssertTrue(pilule.waitForExistence(timeout: 10),
            "la pilule n'est jamais apparue en séance")
        // ⚠️ ON IMPRIME LES RECTS. Une marque posée APRÈS un `.position`
        // rend le rect du CONTENEUR, pas celui de l'objet — on viserait
        // le centre de l'écran en croyant viser la pastille. Ça se lit,
        // ça ne se devine pas.
        print("FOUET-PILULE rects : écran=\(app.frame) pilule=\(pilule.frame)")
    }
}
