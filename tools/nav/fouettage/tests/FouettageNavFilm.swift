import XCTest

/// LE SCÉNARIO DU FILM (classe à part, hors 10/10) — repli puis dépli,
/// avec des plateaux de repos pour le juge. UNE tentative par geste :
/// un retry ferait un aller-retour de plus et le juge, qui exige la
/// séquence haut-bas-haut, le prendrait pour un saut du rendu.
final class FouettageNavFilm: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testFilmRepliDepli() {
        let b = BancNav(); b.lancer(["-fermeSeances"])
        XCTAssertTrue(b.attendre(5) { !$0.mini && !$0.seance })
        Thread.sleep(forTimeInterval: 2.5)                 // plateau HAUT
        b.gesteAttendu("film-repli", tentatives: 1,
                       geste: { b.glisser(b.pointDrag(.nav), dy: 52) },
                       attendu: { $0.mini && $0.playerAuNeant })
        Thread.sleep(forTimeInterval: 2.5)                 // plateau BAS
        b.gesteAttendu("film-depli", tentatives: 1,
                       geste: { b.glisser(b.pointDrag(.grabber), dy: -60) },
                       attendu: { !$0.mini && $0.playerAuNeant })
        Thread.sleep(forTimeInterval: 2.5)                 // plateau HAUT
    }
}
