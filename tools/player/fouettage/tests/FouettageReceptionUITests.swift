import XCTest

/// LA RÉCEPTION DU PAN MAÎTRE — de VRAIS touchers (XCUITest), parce que
/// le doigt fantôme (`-playerDoigt`) appelle suivreDelta/commettre en
/// direct et court-circuite le recognizer : le banc historique est
/// AVEUGLE à un refus de réception. Ces cas couvrent le trou.
///
/// Bug chassé (03-09, Kathryn) : « le player ouvert ne se ferme plus au
/// drag vers le bas — à chaque fois, dès le début, sans passer par le
/// stop ». Discrimination :
///   · test02 échoue partout → refus de réception (ouvert/pauseOuverte)
///     ou pan absent — lire les prints -gesteSonde dans le xcresult :
///     pas de `maitre BEGAN` = la touche n'arrive pas au pan ;
///   · test03 seul échoue → la porte scroll (la liste vole le geste) ;
///   · tout passe → l'arbre est SAIN, le coupable est le build installé
///     sur le téléphone.
///
/// Réutilise BancNav (patron de la session 07) : même copie jetable,
/// même sonde d'état (`pOuvert`, `p`), mêmes gestes déterministes.
final class FouettageReceptionUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func lancerEnSeance() -> BancNav {
        let b = BancNav()
        b.lancer(["-demoData", "-activeWorkout"])
        XCTAssertTrue(b.attendre(10) { $0.seance },
            "PRÉ-REQUIS : la séance active n'est jamais publiée ; sonde=\(b.etat()?.brut ?? "ABSENTE")")
        return b
    }

    /// Ouvre le player par un TAP dalle (vrai toucher) et attend la pose.
    private func ouvrirPlayer(_ b: BancNav) {
        b.taper(b.pointTap(.dalle))
        XCTAssertTrue(b.attendre(6) { $0.pOuvert && $0.p > 0.95 },
            "le player ne s'ouvre pas au tap dalle ; sonde=\(b.etat()?.brut ?? "ABSENTE")")
        // la pose (fondu 0,22 s) doit être finie : on teste le régime posé.
        Thread.sleep(forTimeInterval: 0.9)
    }

    /// 01 — la porte d'entrée : le tap dalle ouvre. (Si CE cas casse, les
    /// suivants ne parlent plus de la fermeture.)
    func test01_seance_tapDalle_ouvre() {
        let b = lancerEnSeance()
        ouvrirPlayer(b)
    }

    /// 02 — LE CAS DU BUG : player ouvert, drag lent vers le bas sur le
    /// HAUT du corps (titre/chrono — aucune liste sous le doigt, la porte
    /// scroll n'a rien à dire). La position décide : mi-course franchie.
    func test02_playerOuvert_dragBasHautDuCorps_ferme() {
        let b = lancerEnSeance()
        ouvrirPlayer(b)
        let haut = b.pointEcran(x: b.app.frame.midX, y: 300)
        b.glisser(haut, dy: 480)
        XCTAssertTrue(b.attendre(6) { !$0.pOuvert && $0.p < 0.05 },
            "LE BUG : drag descendant (haut du corps) et le player reste ouvert — "
            + "sonde=\(b.etat()?.brut ?? "ABSENTE") ; lire les prints -gesteSonde : "
            + "pas de `maitre BEGAN` = refus de réception (ouvert/pauseOuverte/pan absent)")
    }

    /// 03 — la même fermeture, née sur la LISTE (le centre du corps) : la
    /// porte scroll doit rendre le geste à l'offset 0 (loi Apple Music).
    func test03_playerOuvert_dragBasSurListe_ferme() {
        let b = lancerEnSeance()
        ouvrirPlayer(b)
        let liste = b.pointEcran(x: b.app.frame.midX, y: b.app.frame.midY + 60)
        b.glisser(liste, dy: 440)
        XCTAssertTrue(b.attendre(6) { !$0.pOuvert && $0.p < 0.05 },
            "porte scroll : drag descendant né sur la liste jamais rendu au pan — "
            + "sonde=\(b.etat()?.brut ?? "ABSENTE") ; -gesteSonde : `maitre BEGAN` "
            + "sans `PREND` = la branche scroll ne revient pas à 0")
    }

    /// 05 — LE GESTE DE KATHRYN (mesuré au tel 04-09, six drags volés) :
    /// player ouvert, drag descendant né BAS (y≈770, dans le rect que la
    /// bande nav revendique fenêtre) — la bande doit REFUSER (garde
    /// `!PlayerEtat.monte` du 04-09) et le player doit fermer. Sur le
    /// build du tel d'hier soir : `bande RECOIT → DÉCIDE repli → COMMET`,
    /// le drag était mangé.
    func test05_playerOuvert_dragBasNeDansLaZoneBande_ferme() {
        let b = lancerEnSeance()
        // le rect que la bande revendique se LIT à la sonde (il a déjà
        // bougé de 18 pt le 04-09 au matin — jamais de y en dur)
        guard let avant = b.etat(), avant.bandeH > 0 else {
            XCTFail("sonde/géométrie de bande absente"); return
        }
        let yViser = CGFloat(avant.bandeY) + 30
        ouvrirPlayer(b)
        let bas = b.pointEcran(x: b.app.frame.midX, y: yViser)
        b.glisser(bas, dy: 260)
        XCTAssertTrue(b.attendre(6) { !$0.pOuvert && $0.p < 0.05 },
            "LE VOL DE LA BANDE : drag né bas (pays du pouce) jamais rendu au player — "
            + "sonde=\(b.etat()?.brut ?? "ABSENTE") ; -gesteSonde : `bande RECOIT` "
            + "player ouvert = la garde !monte est absente ou trouée")
    }

    /// 04 — le flick : l'élan (>450 pt/s) doit fermer même à faible course.
    func test04_playerOuvert_flickBas_ferme() {
        let b = lancerEnSeance()
        ouvrirPlayer(b)
        let haut = b.pointEcran(x: b.app.frame.midX, y: 320)
        let fin = haut.withOffset(CGVector(dx: 0, dy: 300))
        haut.press(forDuration: 0.05, thenDragTo: fin,
                   withVelocity: .fast, thenHoldForDuration: 0.05)
        XCTAssertTrue(b.attendre(6) { !$0.pOuvert && $0.p < 0.05 },
            "le flick descendant ne ferme pas — sonde=\(b.etat()?.brut ?? "ABSENTE")")
    }
}
