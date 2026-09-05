import XCTest

/// LE DIAGNOSTIC DE GESTE — à quoi ressemble un « vrai doigt » pour la
/// pastille ? Chaque cas relance l'app et joue UNE forme de geste, puis
/// imprime `yRatio` et `gp`. Celui qui déplace la pastille (yRatio change,
/// gp reste 0) est la forme à mettre dans le banc.
///
/// ⚠️ C'est un OUTIL, pas une non-régression : il ne tourne qu'à la main
/// (`-only-testing:WoopUITests/DiagGestePilule`).
final class DiagGestePilule: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func joue(_ nom: String, _ geste: (BancPilule) -> Void) {
        let b = BancPilule(); b.lancer(["-activeWorkout"])
        b.attendreSeance()
        let avant = b.etat()?.yRatio ?? -1
        print("DIAG \(nom) AVANT : \(b.etat()?.brut ?? "?")")
        geste(b)
        Thread.sleep(forTimeInterval: 2.0)
        let e = b.etat()
        print("DIAG \(nom) : yRatio \(avant) → \(e?.yRatio ?? -1) "
            + "| drag=\(e?.nbDrag ?? -1) chg=\(e?.nbChanged ?? -1) "
            + "tap=\(e?.nbTap ?? -1) out=\(e?.nbDehors ?? -1) "
            + "gp=\(e?.grandPlayer ?? -1)")
    }

    /// LA LIGNE DE BASE : on lance, on ne touche à RIEN. Si `gp` vaut
    /// déjà 1 ici, tous les cas « le tap ouvre le player » passaient à
    /// FAUX — un compteur qui compte tout seul est pire qu'aucun compteur.
    func testA0_rien() { joue("A0-rien") { _ in } }

    func testA_coordPress008() {
        joue("A-coord-press0.08") { b in
            let d = b.centrePilule()
            d.press(forDuration: 0.08,
                    thenDragTo: d.withOffset(CGVector(dx: 0, dy: -220)),
                    withVelocity: .default, thenHoldForDuration: 0.22)
        }
    }

    func testB_coordPress060() {
        joue("B-coord-press0.60") { b in
            let d = b.centrePilule()
            d.press(forDuration: 0.60,
                    thenDragTo: d.withOffset(CGVector(dx: 0, dy: -220)),
                    withVelocity: .slow, thenHoldForDuration: 0.30)
        }
    }

    func testC_coordVelocityBasse() {
        joue("C-coord-velocity-basse") { b in
            let d = b.centrePilule()
            d.press(forDuration: 0.25,
                    thenDragTo: d.withOffset(CGVector(dx: 0, dy: -220)),
                    withVelocity: XCUIGestureVelocity(rawValue: 320),
                    thenHoldForDuration: 0.40)
        }
    }

    /// LE TEST DÉCISIF : la MÊME pastille, SEULE sur son banc, sans le
    /// châssis autour. Si le drag marche ici et pas dans l'app, le geste
    /// est mangé par un ANCÊTRE de la vraie hiérarchie ; s'il échoue ici
    /// aussi, le défaut est dans la pastille elle-même.
    func testE_bancPiluleLab() {
        let b = BancPilule()
        b.app.launchArguments = ["-fouettagePilule", "-skipAuth", "-piluleLab"]
        b.app.launch()
        XCTAssertTrue(b.pilule.waitForExistence(timeout: 40),
                      "la pastille n'est pas au banc -piluleLab")
        Thread.sleep(forTimeInterval: 2.0)
        let avant = b.etat()?.yRatio ?? -1
        let d = b.centrePilule()
        d.press(forDuration: 0.25,
                thenDragTo: d.withOffset(CGVector(dx: 0, dy: -180)),
                withVelocity: XCUIGestureVelocity(rawValue: 320),
                thenHoldForDuration: 0.40)
        Thread.sleep(forTimeInterval: 2.0)
        let e = b.etat()
        print("DIAG E-piluleLab : yRatio \(avant) → \(e?.yRatio ?? -1) "
            + "| drag=\(e?.nbDrag ?? -1) gp=\(e?.grandPlayer ?? -1)")
    }

    func testD_swipeUp() {
        joue("D-swipeUp-slow") { b in
            b.pilule.swipeUp(velocity: .slow)
        }
    }
}
