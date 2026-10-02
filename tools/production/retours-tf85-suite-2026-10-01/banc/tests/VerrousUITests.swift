import XCTest

/// L'état relu de la sonde des verrous (`clé=valeur;…`).
struct Verrous {
    let brut: String
    private let d: [String: String]
    init?(_ s: String) {
        guard s.contains("stories=") else { return nil }
        brut = s
        var dd = [String: String]()
        for part in s.split(separator: ";") {
            let kv = part.split(separator: "=", maxSplits: 1)
            if kv.count == 2 { dd[String(kv[0])] = String(kv[1]) }
        }
        d = dd
    }
    subscript(_ k: String) -> String { d[k] ?? "?" }
    func vrai(_ k: String) -> Bool { d[k] == "1" }
    var homeLibre: Bool {
        self["stories"] == "0" && self["couv"] == "0" && self["onglet"] == "home"
            && !vrai("homeDort") && !vrai("chemin") && !vrai("popup") && !vrai("manege")
    }
}

/// LES RETOURS TESTFLIGHT 85 (01-10) — rejoués à vrais touchers.
final class VerrousUITests: XCTestCase {
    var app: XCUIApplication!
    static let preuves = ProcessInfo.processInfo.environment["BANC_PREUVES"]
        ?? "/tmp/banc-verrous-preuves"

    override func setUpWithError() throws { continueAfterFailure = true }

    // MARK: outils

    func lancer(_ args: [String]) {
        app = XCUIApplication()
        app.launchArguments = args
        app.launch()
    }

    func sonde() -> Verrous? {
        let e = app.descendants(matching: .any).matching(identifier: "sonde-verrous").firstMatch
        guard e.exists else { return nil }
        return Verrous(e.label)
    }

    @discardableResult
    func attendre(_ t: TimeInterval, _ nom: String = "", _ c: (Verrous) -> Bool) -> Verrous? {
        let fin = Date().addingTimeInterval(t)
        var dernier: Verrous?
        while Date() < fin {
            if let v = sonde() {
                dernier = v
                if c(v) { return v }
            }
            Thread.sleep(forTimeInterval: 0.3)
        }
        print("BANC attente ratée \(nom) ; sonde=\(dernier?.brut ?? "ABSENTE")")
        return nil
    }

    func taper(_ x: CGFloat, _ y: CGFloat) {
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: x, dy: y)).tap()
    }

    func capture(_ nom: String) {
        let s = XCUIScreen.main.screenshot()
        let a = XCTAttachment(screenshot: s)
        a.name = nom; a.lifetime = .keepAlways
        add(a)
        try? FileManager.default.createDirectory(atPath: Self.preuves,
                                                 withIntermediateDirectories: true)
        try? s.pngRepresentation.write(to: URL(fileURLWithPath: "\(Self.preuves)/\(nom).png"))
        print("BANC capture \(nom) ; sonde=\(sonde()?.brut ?? "?")")
    }

    func arbre(_ nom: String) {
        let t = app.debugDescription
        try? t.write(toFile: "\(Self.preuves)/\(nom).txt", atomically: true, encoding: .utf8)
    }

    /// La home est-elle VIVANTE ? La sonde libre, et la phrase touchable.
    func verifierHome(_ nom: String) {
        Thread.sleep(forTimeInterval: 1.0)
        capture("\(nom)-1s")
        Thread.sleep(forTimeInterval: 3.0)
        capture("\(nom)-4s")
        arbre("\(nom)-arbre")
        let v = sonde()
        let phrase = app.descendants(matching: .any).matching(identifier: "home-phrase").firstMatch
        print("BANC \(nom) phrase existe=\(phrase.exists) touchable=\(phrase.exists && phrase.isHittable)")
        XCTAssertTrue(v?.homeLibre == true, "\(nom) : home verrouillée ; sonde=\(v?.brut ?? "ABSENTE")")
        XCTAssertTrue(phrase.exists && phrase.isHittable, "\(nom) : la phrase de la home n'est pas touchable")
    }

    /// Le chevron retour d'une page (Route, Sacre) : le bouton d'abord, sinon
    /// trois points en haut à gauche ; s'arrête dès que `fait` est vrai.
    func chevron(_ nom: String, _ fait: @escaping (Verrous) -> Bool) {
        let b = app.buttons.matching(NSPredicate(format:
            "label CONTAINS[c] 'back' OR label CONTAINS[c] 'retour' OR label CONTAINS[c] 'chevron' OR label CONTAINS[c] 'précédent'")).firstMatch
        if b.exists, b.frame.minY < 200 {
            print("BANC \(nom) chevron trouvé : \(b.label) \(b.frame)")
            app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: b.frame.midX, dy: b.frame.midY)).tap()
            if attendre(3, nom, fait) != nil { return }
        }
        for (x, y) in [(30.0, 72.0), (36.0, 64.0), (24.0, 84.0), (40.0, 100.0)] {
            taper(x, y)
            if attendre(3, nom, fait) != nil { print("BANC \(nom) chevron à (\(x),\(y))"); return }
        }
        capture("\(nom)-chevron-sourd")
    }

    /// La card booster est posée : on tape le sachet (le sachet EST le bouton).
    /// Trois hauteurs essayées, la première qui ouvre le manège gagne.
    func ouvrirLeBooster(_ nom: String) -> Bool {
        guard attendre(40, "popup", { $0.vrai("popup") }) != nil else {
            capture("\(nom)-pas-de-popup"); return false
        }
        Thread.sleep(forTimeInterval: 1.4)
        capture("\(nom)-popup")
        arbre("\(nom)-popup-arbre")
        let w = app.frame.width, h = app.frame.height
        for fy in [0.42, 0.36, 0.48, 0.30] {
            taper(w / 2, h * fy)
            if attendre(3, "manege") { $0.vrai("manege") } != nil {
                print("BANC \(nom) sachet tapé à y=\(fy)")
                return true
            }
        }
        capture("\(nom)-sachet-sourd")
        return false
    }

    // MARK: 1 — Route → booster → manège → chevron → home

    func test1_route_booster_chevron() {
        lancer(["-skipAuth", "-sansVisite", "-boosterRoute", "-boosterCine"])
        XCTAssertNotNil(attendre(40, "route", { $0.vrai("chemin") }), "la Route ne s'ouvre pas")
        capture("t1-route")
        guard ouvrirLeBooster("t1") else { XCTFail("le sachet ne répond pas"); return }
        attendre(20, "pose") { $0.vrai("pose") }
        Thread.sleep(forTimeInterval: 1.5)
        capture("t1-manege")
        arbre("t1-manege-arbre")
        chevron("t1-sacre") { !$0.vrai("manege") }
        verifierHome("t1-home")
    }

    // MARK: 2 — Route → booster → manège → envol → profil → home

    func test2_route_booster_envol() {
        lancer(["-skipAuth", "-sansVisite", "-boosterRoute", "-boosterCine", "-boosterEnvol"])
        XCTAssertNotNil(attendre(40, "route", { $0.vrai("chemin") }), "la Route ne s'ouvre pas")
        guard ouvrirLeBooster("t2") else { XCTFail("le sachet ne répond pas"); return }
        let arrivee = attendre(60, "profil") { !$0.vrai("manege") }
        capture("t2-apres-envol")
        arbre("t2-apres-envol-arbre")
        XCTAssertNotNil(arrivee, "le manège ne se referme pas")
        Thread.sleep(forTimeInterval: 4)
        capture("t2-profil")
        // Retour à la home : le chevron du Profil (la barre est cachée sur le
        // Profil ; le bas de page, c'est le sachet qui ouvre son panneau).
        chevron("t2-profil") { $0["onglet"] == "home" }
        verifierHome("t2-home")
    }

    // MARK: 3 — Route → booster « Later » → fermer la Route → home

    func test3_route_later() {
        lancer(["-skipAuth", "-sansVisite", "-boosterRoute"])
        XCTAssertNotNil(attendre(40, "route", { $0.vrai("chemin") }), "la Route ne s'ouvre pas")
        guard attendre(40, "popup", { $0.vrai("popup") }) != nil else {
            capture("t3-pas-de-popup"); XCTFail("pas de pop-up"); return
        }
        Thread.sleep(forTimeInterval: 1.4)
        let later = app.buttons.matching(NSPredicate(
            format: "label CONTAINS[c] 'later' OR label CONTAINS[c] 'tard'")).firstMatch
        if later.exists { later.tap() } else { taper(app.frame.width / 2, app.frame.height * 0.74) }
        attendre(4, "popup-ferme") { !$0.vrai("popup") }
        capture("t3-route-sans-popup")
        arbre("t3-route-arbre")
        chevron("t3-route") { !$0.vrai("chemin") }
        verifierHome("t3-home")
    }

    // MARK: 4 — le Claim du Welcome Back : combien de taps ?

    /// `quand` : secondes entre l'ouverture de la card et le premier tap ;
    /// `glisse` : le pouce glisse de N pt pendant le tap.
    func claim(_ nom: String, robeTexte: Bool, quand: Double, glisse: CGFloat) -> Int {
        var args = ["-skipAuth", "-sansVisite", "-welcomeForce"]
        if robeTexte { args.append("-welcomeRobeTexte") }
        lancer(args)
        guard attendre(30, "welcome", { $0.vrai("welcome") }) != nil else {
            capture("\(nom)-pas-de-card"); return -1
        }
        Thread.sleep(forTimeInterval: quand)
        let bouton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'claim'")).firstMatch
        // Le centre du bouton tel que l'accessibilité le donne ; à défaut, la cote
        // calculée de la card (bas de card − Later − marge).
        var cx = app.frame.width / 2, cy = app.frame.height / 2 + 121
        // ⚠️ Pas le cadre d'accessibilité : sur la robe texte il rend le CENTRE
        // de la card (mesuré le 01-10). On vise le bouton VISIBLE (capture).
        if bouton.exists { print("BANC claim accessibilité \(bouton.frame)") }
        if quand > 1 { capture("\(nom)-avant") }
        var n = 0
        while n < 12 {
            n += 1
            let p = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: cx, dy: cy))
            if glisse > 0 {
                p.press(forDuration: 0.06,
                        thenDragTo: p.withOffset(CGVector(dx: glisse, dy: glisse / 2)))
            } else {
                p.tap()
            }
            if attendre(1.2, "", { !$0.vrai("welcome") }) != nil { break }
        }
        let ferme = !(sonde()?.vrai("welcome") ?? true)
        print("BANC CLAIM \(nom) robe=\(robeTexte ? "texte" : "video") quand=\(quand) glisse=\(glisse) taps=\(n) ferme=\(ferme) bouton=(\(Int(cx)),\(Int(cy))) existe=\(bouton.exists)")
        return ferme ? n : 99
    }

    // MARK: 5 — en séance : un cardio fini, puis une muscu (le bug « page rouge »)

    /// Le banc `-bancCardioMuscu` (posé le 01-10 par une autre session) joue
    /// le geste sans doigt ; ici on REGARDE : à chaque changement d'onglet ou
    /// de fiche une capture, et la page rouge se lit dans la sonde (onglet
    /// exercices SANS fiche pendant que la séance tourne).
    func test5_cardio_puis_muscu() {
        lancer(["-skipAuth", "-sansVisite", "-sansServeur", "-goAuto", "-bancCardioMuscu",
                "-departSerieAuto", "-cardioAuto", "-cardioConstant", "-cardioLecteur"])
        var dernier = ""
        var rouge = 0
        let fin = Date().addingTimeInterval(170)
        var i = 0
        while Date() < fin {
            if let v = sonde() {
                let cle = "\(v["onglet"])-\(v["fiche"])"
                if cle != dernier { dernier = cle; capture("t5-\(i)-\(cle)") }
                if v.vrai("seance"), v["onglet"] == "exercises", v["fiche"] == "-" {
                    rouge += 1
                    if rouge == 1 { capture("t5-PAGE-ROUGE-\(i)") }
                }
                if v["fiche"] == "woop-haute", i > 20 { break }
            }
            i += 1
            Thread.sleep(forTimeInterval: 0.5)
        }
        Thread.sleep(forTimeInterval: 3)
        capture("t5-fin")
        print("BANC CARDIO-MUSCU echantillons-page-rouge=\(rouge) dernier=\(dernier)")
        XCTAssertEqual(rouge, 0, "la page Exercices s'est montrée en séance")
    }

    // MARK: 6 — LA VRAIE FIN DE SÉANCE : cardio, muscu, Terminer, story, Route,
    // booster, manège, chevron, home — tout le parcours, sans serveur.

    func test6_fin_de_seance_complete() {
        lancer(["-skipAuth", "-sansVisite", "-sansServeur", "-goAuto", "-bancCardioMuscu",
                "-departSerieAuto", "-cardioAuto", "-cardioConstant", "-cardioLecteur",
                "-terminerSeanceAuto", "150"])
        var dernier = ""
        var rouge = 0
        var vuStory = false, vuRoute = false
        let fin = Date().addingTimeInterval(260)
        var i = 0
        while Date() < fin {
            if let v = sonde() {
                let cle = "\(v["onglet"])-\(v["fiche"])-s\(v["stories"])-c\(v["chemin"])-p\(v["popup"])"
                if cle != dernier { dernier = cle; capture("t6-\(i)-\(cle)") }
                if v.vrai("seance"), v["onglet"] == "exercises", v["fiche"] == "-" {
                    rouge += 1
                    if rouge == 1 { capture("t6-PAGE-ROUGE-\(i)") }
                }
                if v["stories"] != "0" { vuStory = true }
                if v.vrai("chemin") { vuRoute = true }
                if v.vrai("popup") { break }
            }
            i += 1
            Thread.sleep(forTimeInterval: 0.5)
        }
        print("BANC FIN echantillons-page-rouge=\(rouge) story=\(vuStory) route=\(vuRoute) dernier=\(dernier)")
        XCTAssertEqual(rouge, 0, "la page Exercices s'est montrée en séance")
        guard ouvrirLeBooster("t6") else {
            capture("t6-sans-booster")
            // Pas de pop-up : on referme la Route s'il y en a une, et on juge la home.
            if sonde()?.vrai("chemin") == true { chevron("t6-route") { !$0.vrai("chemin") } }
            verifierHome("t6-home-sans-booster")
            return
        }
        Thread.sleep(forTimeInterval: 8)
        capture("t6-manege")
        chevron("t6-sacre") { !$0.vrai("manege") }
        verifierHome("t6-home")
    }

    func test4_claim() {
        var bilan: [String] = []
        for robe in [false, true] {
            for (quand, glisse, nom) in [(2.0, 0.0, "pose"), (0.6, 0.0, "tot"),
                                         (2.0, 8.0, "glisse8"), (2.0, 16.0, "glisse16")] {
                let n = claim("t4-\(robe ? "texte" : "video")-\(nom)", robeTexte: robe,
                              quand: quand, glisse: CGFloat(glisse))
                bilan.append("\(robe ? "texte" : "video")-\(nom)=\(n)")
            }
        }
        print("BANC CLAIM BILAN \(bilan.joined(separator: " "))")
    }
}
