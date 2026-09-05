import XCTest

/// LES CAS DU LOT 2 — chacun rejoue, à VRAIS TOUCHERS, une phrase du
/// verdict téléphone du 04-09 :
///
///   « quand je clique sur active session il y a de gros bugs, la
///     navigation redevient des petits points alors qu'on avait dit non,
///     impossible de cliquer sur la bulle, pas d'overlay, l'application
///     devient impraticable et chauffe en permanence. »
///
/// L'ordre alphabétique est NORMATIF (XCTest joue test01→test08).
final class FouettagePiluleUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    // MARK: — « la navigation redevient des petits points »

    func test01_seance_navResteEntiere() {
        let b = BancPilule(); b.lancer(["-activeWorkout"])
        b.attendreSeance()
        guard let e = b.etat() else { return XCTFail("sonde absente") }
        XCTAssertFalse(e.mini,
            "LA CAUSE N° 1 EST REVENUE : la séance replie la nav ; sonde=\(e.brut)")
        XCTAssertEqual(e.navH, 42, accuracy: 0.5,
            "la nav doit garder sa hauteur pleine en séance ; sonde=\(e.brut)")
        XCTAssertTrue(e.navVisible, "la nav doit être publiée visible")
    }

    func test02_seance_leTapDeNavNavigueDuPremierCoup() {
        let b = BancPilule(); b.lancer(["-activeWorkout"])
        b.attendreSeance()
        guard let e0 = b.etat(), e0.page == "home" else {
            return XCTFail("état de départ inattendu ; sonde=\(b.etat()?.brut ?? "?")")
        }
        // UN SEUL tap doit suffire : le garde « en mini, tout tap déploie »
        // avalait le premier de chaque séance sans jamais naviguer.
        b.taper(b.centreGlyphe(1))
        XCTAssertTrue(b.attendre(4) { $0.page == "exos" },
            "LE PREMIER TAP EST ENCORE CONFISQUÉ ; sonde=\(b.etat()?.brut ?? "?")")
        b.auPremierPlan("cas02")
    }

    // MARK: — « impossible de cliquer sur la bulle, pas d'overlay »

    func test03_seance_tapPilule_ouvreLeGrandPlayer() {
        let b = BancPilule(); b.lancer(["-activeWorkout"])
        b.attendreSeance()
        b.gesteAttendu("cas03-tap-ouvre",
                       geste: { b.taper(b.centrePilule()) },
                       attendu: { $0.grandPlayer >= 1 })
        XCTAssertTrue(b.grandPlayer.waitForExistence(timeout: 4),
            "le grand player n'est pas à l'écran")
    }

    func test04_seance_lachee_sePoseLaOuOnLaLache_etPasDansLIle() {
        let b = BancPilule(); b.lancer(["-activeWorkout"])
        b.attendreSeance()
        guard let e0 = b.etat() else { return XCTFail("sonde absente") }
        let y0 = e0.yRatio
        // Un drag VERS LE HAUT, franc mais posé (tenue au lever) : elle
        // doit se poser plus haut — surtout PAS partir dans l'île.
        b.gesteAttendu("cas04-pose",
                       geste: { b.glisser(b.centrePilule(), dy: -220) },
                       attendu: { !$0.dansIle && $0.yRatio < y0 - 0.10 })
        XCTAssertEqual(b.etat()?.entreesIle, 0,
            "elle est passée par l'île alors qu'on l'a seulement DÉPLACÉE")
    }

    func test05_seance_deplacementLateralLent_nAspirePasDansLIle() {
        let b = BancPilule(); b.lancer(["-activeWorkout"])
        b.attendreSeance()
        // LA PORTE RESSERRÉE : avant, ~125 pt de côté suffisaient à
        // l'avaler — sans intention, et sans plus aucun moyen d'ouvrir
        // le player. Un déplacement LENT ne doit plus rien déclencher.
        b.glisser(b.centrePilule(), dx: -150, dy: 0)
        XCTAssertTrue(b.attendre(4) { $0.pose && !$0.dansIle },
            "un simple déplacement latéral l'aspire encore dans l'île ; "
            + "sonde=\(b.etat()?.brut ?? "?")")
        XCTAssertEqual(b.etat()?.entreesIle, 0, "entrée d'île non voulue")
        b.auPremierPlan("cas05")
    }

    // MARK: — LE CAS CENTRAL : l'île n'est pas une impasse

    func test06_seance_ile_seRempli_puisSonTapOuvreLePlayer() {
        let b = BancPilule(); b.lancer(["-activeWorkout"])
        b.attendreSeance()
        // 1) on l'envoie EN HAUT — la porte volontaire de l'île.
        b.gesteAttendu("cas06a-entre-dans-ile",
                       geste: { b.jeter(b.centrePilule(), dy: -700) },
                       attendu: { $0.dansIle })
        XCTAssertTrue(b.ile.waitForExistence(timeout: 4),
            "l'île n'est pas à l'écran alors que l'état dit qu'on y est")
        // 2) UN TAP SUR L'ÎLE DOIT OUVRIR LE PLAYER. C'était le trou : il
        //    ne faisait que l'en sortir, donc « pas d'overlay ».
        b.gesteAttendu("cas06b-tap-ile-ouvre",
                       geste: { b.taper(b.centreIle()) },
                       attendu: { $0.grandPlayer >= 1 })
        XCTAssertTrue(b.grandPlayer.waitForExistence(timeout: 4),
            "LE TAP DE L'ÎLE N'OUVRE TOUJOURS PAS LE PLAYER")
    }

    func test07_seance_ileSeQuitteAuDrag() {
        let b = BancPilule(); b.lancer(["-activeWorkout"])
        b.attendreSeance()
        b.gesteAttendu("cas07a-entre",
                       geste: { b.jeter(b.centrePilule(), dy: -700) },
                       attendu: { $0.dansIle })
        // Le drag reste la sortie — sinon on est enfermé (le tap ouvre).
        b.gesteAttendu("cas07b-sort",
                       geste: { b.glisser(b.centreIle(), dy: 160) },
                       attendu: { !$0.dansIle })
        XCTAssertTrue(b.pilule.waitForExistence(timeout: 4),
            "la pilule n'est pas revenue après la sortie d'île")
    }

    // MARK: — « l'application devient impraticable » : la nav qui part

    func test08_navRevientApresUnAllerRetourDansUnOnglet() {
        let b = BancPilule(); b.lancer(["-activeWorkout"])
        b.attendreSeance()
        XCTAssertTrue(b.etat()?.navVisible == true, "nav absente au départ")
        // Trois allers-retours entre les onglets : chaque PageCard
        // publie/retire sa voix au registre. Un jeton ORPHELIN (jamais
        // retiré) gèlerait la nav cachée POUR TOUJOURS — c'est le risque
        // exact du correctif ④, et c'est ce cas qui le surveille.
        for tour in 1 ... 3 {
            b.taper(b.centreGlyphe(1))
            XCTAssertTrue(b.attendre(4) { $0.page == "exos" },
                          "tour \(tour) : exos jamais atteint")
            b.taper(b.centreGlyphe(0))
            XCTAssertTrue(b.attendre(4) { $0.page == "home" },
                          "tour \(tour) : retour home impossible")
            XCTAssertTrue(b.attendre(4) { $0.navVisible },
                "tour \(tour) : LA NAV A DISPARU POUR DE BON ; "
                + "sonde=\(b.etat()?.brut ?? "?")")
        }
        b.auPremierPlan("cas08")
    }
}
