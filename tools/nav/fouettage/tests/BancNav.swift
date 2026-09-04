import XCTest

/// L'état relu de la sonde (`clé=valeur;…`).
struct EtatSonde {
    let brut: String
    private let d: [String: String]
    init?(_ valeur: Any?) {
        guard let s = valeur as? String, s.contains("mini=") else { return nil }
        brut = s
        var dd = [String: String]()
        for part in s.split(separator: ";") {
            let kv = part.split(separator: "=", maxSplits: 1)
            if kv.count == 2 { dd[String(kv[0])] = String(kv[1]) }
        }
        d = dd
    }
    var mini: Bool { d["mini"] == "1" }
    var enSuivi: Bool { d["enSuivi"] == "1" }
    var suivi: Double { Double(d["suivi"] ?? "") ?? -1 }
    var navH: Double { Double(d["navH"] ?? "") ?? -1 }
    var page: String { d["page"] ?? "?" }
    var pMonte: Bool { d["pMonte"] == "1" }
    var pOuvert: Bool { d["pOuvert"] == "1" }
    var p: Double { Double(d["p"] ?? "") ?? -1 }
    var pMax: Double { Double(d["pMax"] ?? "") ?? -1 }
    var ouvertures: Int { Int(d["ouv"] ?? "") ?? -1 }
    var seance: Bool { d["seance"] == "1" }
    /// Le rect fenêtre de la bande VISIBLE, publié par la marque (ce
    /// que LE DOIGT voit) ; on vise avec LUI, jamais avec le frame
    /// accessibilité (un `.offset` ancêtre peut mentir). Si la porte de
    /// prod diverge du visible (le double-décalage de +18 mesuré au banc
    /// adverse 03-09), les rouges le disent — c'est voulu.
    var bandeY: Double { Double(d["bandeY"] ?? "") ?? -1 }
    var bandeH: Double { Double(d["bandeH"] ?? "") ?? -1 }
    var playerAuNeant: Bool { !pMonte && !pOuvert && p < 0.01 }
    /// L'overlay ne s'est JAMAIS ouvert ni même approché (le flash
    /// ouvre-referme pendant un drag laisserait un état final propre —
    /// seuls les compteurs le voient).
    var jamaisOuvert: Bool { ouvertures == 0 && pMax < 0.2 }
}

/// Le strip système du bas : la porte du pan REFUSE tout toucher à
/// moins de `safeBottom` du bas de bande (parade Reachability). Tout
/// point de DRAG doit viser au-dessus, avec une marge.
private let safeBottom: CGFloat = 34
private let margePlancher: CGFloat = 6

final class BancNav {
    let app = XCUIApplication()

    func lancer(_ args: [String]) {
        app.launchArguments = ["-fouettageNav", "-skipAuth", "-gesteSonde"] + args
        app.launch()
        XCTAssertTrue(bande.waitForExistence(timeout: 60),
            "LANCEMENT INVALIDE — la marque de bande n'est jamais apparue")
        XCTAssertTrue(attendre(10) { $0.bandeH > 0 },
            "la géométrie de bande n'est jamais publiée ; sonde=\(etat()?.brut ?? "ABSENTE")")
        Thread.sleep(forTimeInterval: 1.5)
    }

    var bande: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "fouettage-bande").firstMatch
    }
    var sonde: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "fouettage-nav-sonde").firstMatch
    }
    func etat() -> EtatSonde? { EtatSonde(sonde.value) }

    // MARK: les points visés — depuis la SONDE (la géométrie du pan)

    enum Zone { case grabber, dalle, nav }

    private func dy(_ z: Zone, _ e: EtatSonde) -> CGFloat {
        switch z {
        case .grabber: return 5
        case .dalle: return 18 + 38
        case .nav: return 18 + (e.seance ? 76 : 0) + CGFloat(e.navH) / 2
        }
    }

    private func exige(_ cond: Bool, _ message: String) -> Bool {
        if !cond { XCTFail(message) }
        return cond
    }

    /// Un point de DRAG : plafonné au-dessus du strip système (la porte
    /// du pan refuse en dessous de `maxY − safeBottom` — viser là serait
    /// tester un refus voulu, pas le drag).
    func pointDrag(_ z: Zone, dx: CGFloat = 0) -> XCUICoordinate {
        guard let e = etat(), exige(e.bandeH > 0, "sonde/géométrie absente au moment de viser \(z)") else {
            return app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        }
        let plafond = CGFloat(e.bandeH) - safeBottom - margePlancher
        let d = min(dy(z, e), max(plafond, 5))
        return pointEcran(x: app.frame.midX + dx, y: CGFloat(e.bandeY) + d)
    }

    /// Un point de TAP : le point que LE DOIGT vise — le centre VISIBLE
    /// de la zone, jamais corrigé. (Si la zone tactile réelle est
    /// décalée, c'est un bug à révéler, pas à contourner.)
    func pointTap(_ z: Zone, dx: CGFloat = 0, dyCorrection: CGFloat = 0) -> XCUICoordinate {
        guard let e = etat(), exige(e.bandeH > 0, "sonde/géométrie absente au moment de viser \(z)") else {
            return app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        }
        return pointEcran(x: app.frame.midX + dx,
                          y: CGFloat(e.bandeY) + dy(z, e) + dyCorrection)
    }

    func pointEcran(x: CGFloat, y: CGFloat) -> XCUICoordinate {
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: x, dy: y))
    }

    // MARK: les gestes

    /// presse 0,08 s + drag + TENUE 0,22 s : vélocité ~nulle au lever →
    /// le commit se décide à la POSITION (déterministe), et la tenue
    /// reste sous les chiens de garde.
    func glisser(_ depuis: XCUICoordinate, dy: CGFloat) {
        let fin = depuis.withOffset(CGVector(dx: 0, dy: dy))
        depuis.press(forDuration: 0.08, thenDragTo: fin,
                     withVelocity: .default, thenHoldForDuration: 0.22)
    }
    func taper(_ ou: XCUICoordinate) { ou.tap() }

    @discardableResult
    func attendre(_ timeout: TimeInterval = 3.0, _ cond: (EtatSonde) -> Bool) -> Bool {
        let fin = Date().addingTimeInterval(timeout)
        while Date() < fin {
            if let e = etat(), cond(e) { return true }
            Thread.sleep(forTimeInterval: 0.15)
        }
        return false
    }

    /// Tolérance anti-flake : 3 tentatives (le sim peut perdre UN
    /// toucher ; un vrai bug les perd TOUS), verdict sur l'état COMMIS
    /// (`!enSuivi`), premier plan vérifié après chaque tentative.
    func gesteAttendu(_ nom: String, tentatives: Int = 3,
                      geste: () -> Void, attendu: @escaping (EtatSonde) -> Bool) {
        for t in 1 ... tentatives {
            geste()
            let ok = attendre(3.0) { !$0.enSuivi && attendu($0) }
            auPremierPlan(nom)
            if ok {
                if t > 1 { print("FOUET-NAV \(nom) : ok tentative \(t)") }
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

    /// La hauteur de bande STABILISÉE (deux lectures égales) — jamais un
    /// sleep sec seul : l'animation du commit dure 0,25 s mais le sim
    /// chargé peut l'étirer.
    func hauteurBande() -> CGFloat {
        var derniere: Double = -1
        let fin = Date().addingTimeInterval(3.0)
        while Date() < fin {
            Thread.sleep(forTimeInterval: 0.3)
            guard let e = etat() else { continue }
            if e.bandeH == derniere { return CGFloat(e.bandeH) }
            derniere = e.bandeH
        }
        return CGFloat(derniere)
    }

    // MARK: les briques

    func replier() {
        gesteAttendu("brique-replier",
                     geste: { glisser(pointDrag(.nav), dy: 52) },
                     attendu: { $0.mini && $0.playerAuNeant })
    }
    /// Le dépli au DRAG part toujours du GRABBER : en mini, la zone nav
    /// visible vit presque entière dans le strip système que la porte du
    /// pan refuse (parade Reachability) — le grabber est la seule prise
    /// de drag que la spec garantit dans les deux états.
    func deployer() {
        gesteAttendu("brique-deployer",
                     geste: { glisser(pointDrag(.grabber), dy: -60) },
                     attendu: { !$0.mini && !$0.pOuvert })
    }
}
