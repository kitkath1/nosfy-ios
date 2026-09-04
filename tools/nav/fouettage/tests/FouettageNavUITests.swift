import XCTest

/// LES 10 CAS DU FOUETTAGE NAV — l'ordre alphabétique est NORMATIF
/// (XCTest joue test01→test10) : hors séance d'abord, la séance après,
/// pour que l'état persistant (`openTab`, séance semée) ne remonte
/// jamais le courant.
final class FouettageNavUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func test01_naissance_horsSeance_navDeployee() {
        let b = BancNav(); b.lancer(["-fermeSeances"])
        XCTAssertTrue(b.attendre(5) { !$0.mini && !$0.seance && $0.navH == 70 && $0.playerAuNeant },
            "naissance fausse ; sonde=\(b.etat()?.brut ?? "ABSENTE")")
        XCTAssertEqual(b.hauteurBande(), 82, accuracy: 3, "grab 12 + nav 70 = 82 pt (compaction 04-09)")
        b.auPremierPlan("cas01")
    }

    func test02_horsSeance_dragBasNav_replie_cardAllonge() {
        let b = BancNav(); b.lancer(["-fermeSeances"])
        let h0 = b.hauteurBande()
        b.gesteAttendu("cas02-repli",
                       geste: { b.glisser(b.pointDrag(.nav), dy: 52) },
                       attendu: { $0.mini && $0.playerAuNeant })
        let h1 = b.hauteurBande()
        XCTAssertEqual(h0 - h1, 50, accuracy: 3,
                       "la card gagne 50 pt (bande \(h0)→\(h1))")
    }

    func test03_horsSeance_dragHaut_redeploie() {
        let b = BancNav(); b.lancer(["-fermeSeances"]); b.replier()
        b.gesteAttendu("cas03-depli",
                       geste: { b.glisser(b.pointDrag(.grabber), dy: -60) },
                       attendu: { !$0.mini && $0.playerAuNeant })
        XCTAssertEqual(b.hauteurBande(), 82, accuracy: 3, "rend ses 82 pt")
    }

    func test04_exercices_grabberDragBas_replie() {
        let b = BancNav(); b.lancer(["-fermeSeances", "-openTab", "exercises"])
        XCTAssertTrue(b.attendre(5) { $0.page == "exos" },
            "pont openTab→page ; sonde=\(b.etat()?.brut ?? "?")")
        b.gesteAttendu("cas04-grabber",
                       geste: { b.glisser(b.pointDrag(.grabber), dy: 52) },
                       attendu: { $0.mini && $0.playerAuNeant })
    }

    func test05_horsSeance_tapBandeMini_deploie() {
        let b = BancNav(); b.lancer(["-fermeSeances"]); b.replier()
        // LE POINT DU DOIGT : le centre VISIBLE de la nav mini. Trois
        // tentatives ; si toutes échouent, UN tap de diagnostic 18 pt
        // plus haut (la position de LAYOUT) départage « le tap est
        // mort » de « la zone tactile ne suit pas l'offset `descente` »
        // (la loi tapis : .offset déplace les pixels, pas le hit).
        for t in 1 ... 3 {
            b.taper(b.pointTap(.nav))
            if b.attendre(2.5, { !$0.mini }) {
                if t > 1 { print("FOUET-NAV cas05 : ok tentative \(t)") }
                b.auPremierPlan("cas05"); return
            }
        }
        b.taper(b.pointTap(.nav, dyCorrection: -18))
        let deplieAuLayout = b.attendre(2.5) { !$0.mini }
        b.auPremierPlan("cas05")
        XCTFail(deplieAuLayout
            ? "cas05 — le tap au point VISIBLE ne déploie pas, mais 18 pt plus haut OUI : "
              + "la zone tactile de la bande ne suit pas l'offset `descente` (loi tapis) — "
              + "le doigt réel rate pareil"
            : "cas05 — tap de dépli MORT (visible ET layout) ; sonde=\(b.etat()?.brut ?? "?")")
    }

    func test06_horsSeance_tapGlyphes_interieur_puis_extreme() {
        let b = BancNav(); b.lancer(["-fermeSeances"])
        let ordre = ["home", "exos", "prog", "profil"]
        guard let e0 = b.etat(), !e0.mini, ordre.contains(e0.page) else {
            XCTFail("état initial illisible ; sonde=\(b.etat()?.brut ?? "?")"); return
        }
        // 1) un glyphe INTÉRIEUR (exos, dx=-38) — sauf si on y est déjà.
        if e0.page != "exos" {
            b.gesteAttendu("cas06-tap-exos",
                           geste: { b.taper(b.pointTap(.nav, dx: (1 - 1.5) * 76)) },
                           attendu: { $0.page == "exos" && !$0.mini })
        }
        // 2) le glyphe EXTRÊME gauche (home, dx=-114) : il teste le VRAI
        //    espacement visuel (pasOuvert=76 est un offset x — si le hit
        //    ne le suit pas, home/profil sont intapables au doigt).
        //    Viser home — jamais profil : profil n'a pas de PageCard, y
        //    naître au cas suivant tuerait la marque. Finir sur home
        //    range aussi `openTab` pour la suite.
        for t in 1 ... 3 {
            b.taper(b.pointTap(.nav, dx: (0 - 1.5) * 76))
            if b.attendre(2.5, { $0.page == "home" }) {
                if t > 1 { print("FOUET-NAV cas06-extreme : ok tentative \(t)") }
                b.auPremierPlan("cas06"); return
            }
        }
        // diagnostic : le même glyphe à sa position de LAYOUT (pas 44).
        b.taper(b.pointTap(.nav, dx: (0 - 1.5) * 44))
        let vaAuLayout = b.attendre(2.5) { $0.page == "home" }
        b.auPremierPlan("cas06")
        XCTFail(vaAuLayout
            ? "cas06 — le glyphe home répond à sa position de LAYOUT (±44) mais pas à sa "
              + "position VISIBLE (±76) : le hit des glyphes ne suit pas l'offset x — "
              + "les glyphes extrêmes sont intapables au doigt"
            : "cas06 — tap du glyphe extrême MORT ; sonde=\(b.etat()?.brut ?? "?")")
    }

    /// La naissance de la séance SEMÉE (mini ou déployée) dépend du
    /// timing du semis SwiftData face au `onChange(of: active != nil)`
    /// sans `initial:` (WoopApp) — le banc NORMALISE vers déployée : la
    /// naissance-mini du vrai flow (tap play) reste un verdict téléphone.
    private func normaliseDeployee(_ b: BancNav) {
        XCTAssertTrue(b.attendre(6) { $0.seance && $0.playerAuNeant },
            "séance active, player fermé ; sonde=\(b.etat()?.brut ?? "ABSENTE")")
        if b.etat()?.mini == true { b.deployer() }
        XCTAssertTrue(b.attendre(3) { !$0.mini }, "normalisation vers déployée impossible")
    }

    func test07_seance_dragBasNav_replieSousPlayer() {
        let b = BancNav(); b.lancer(["-activeWorkout"])
        normaliseDeployee(b)
        XCTAssertEqual(b.hauteurBande(), 158, accuracy: 3, "12+76+70 = 158 pt")
        b.gesteAttendu("cas07-repli-sous-player",
                       geste: { b.glisser(b.pointDrag(.nav), dy: 52) },
                       attendu: { $0.mini && $0.playerAuNeant && $0.jamaisOuvert })
        XCTAssertEqual(b.hauteurBande(), 108, accuracy: 3, "12+76+20 = 108 pt")
    }

    func test08_seance_dragHautGrabber_redeploieSousPlayer() {
        let b = BancNav(); b.lancer(["-activeWorkout"])
        normaliseDeployee(b)
        b.gesteAttendu("cas08-vers-mini",
                       geste: { b.glisser(b.pointDrag(.nav), dy: 52) },
                       attendu: { $0.mini && $0.playerAuNeant })
        // Le dépli part du GRABBER : en mini-séance (bande 120) la zone
        // nav vit sous le plancher système que la porte du pan refuse.
        b.gesteAttendu("cas08-redeploie",
                       geste: { b.glisser(b.pointDrag(.grabber), dy: -60) },
                       attendu: { !$0.mini && $0.playerAuNeant && $0.jamaisOuvert })
    }

    func test09_seance_dragBasSurDalle_replie_jamaisOuvre() {
        let b = BancNav(); b.lancer(["-activeWorkout"])
        normaliseDeployee(b)
        // LE CAS CENTRAL : drag descendant né sur la DALLE → repli,
        // JAMAIS l'overlay — et « jamais » se prouve aux COMPTEURS
        // (ouv=0, pMax<0.2), pas à l'état final (un flash ouvre-referme
        // laisserait un état final propre).
        b.gesteAttendu("cas09-dalle-repli",
                       geste: { b.glisser(b.pointDrag(.dalle), dy: 52) },
                       attendu: { $0.mini && $0.playerAuNeant && $0.jamaisOuvert })
    }

    func test10_seance_tapDalle_puis_dragHautDalle_ouvrent() {
        let b = BancNav(); b.lancer(["-activeWorkout"])
        XCTAssertTrue(b.attendre(6) { $0.seance })
        let ecran = b.app.frame
        b.gesteAttendu("cas10a-tap-ouvre",
                       geste: { b.taper(b.pointTap(.dalle)) },
                       attendu: { $0.pOuvert && $0.p > 0.95 })
        b.gesteAttendu("cas10b-referme",
                       geste: { b.glisser(b.pointEcran(x: ecran.midX, y: ecran.height * 0.35), dy: 320) },
                       attendu: { $0.playerAuNeant })
        b.gesteAttendu("cas10c-drag-ouvre",
                       geste: { b.glisser(b.pointDrag(.dalle), dy: -300) },
                       attendu: { $0.pOuvert })
        b.gesteAttendu("cas10d-referme",
                       geste: { b.glisser(b.pointEcran(x: ecran.midX, y: ecran.height * 0.35), dy: 320) },
                       attendu: { $0.playerAuNeant })
    }
}
