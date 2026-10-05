import SwiftUI

// MARK: - TIRER VERS LE BAS POUR FERMER, comme Spotify (05-10-2026)
//
// Ses mots, TestFlight 87 : « les overlays ne sont pas hyper fluides quand je
// veux drag vers le bas » ; « dans Profil et Réglages, pas le menu : que le
// chevron, et le comportement à la Spotify au drag vers le bas pour fermer ».
//
// LA CAUSE DU MANQUE DE FLUIDITÉ (loi §2 de woop-architecture) : le décalage
// vivait en `@State` dans la feuille elle-même — chaque image du doigt
// réévaluait tout son corps (le matériau, les dégradés, la liste). Ici il vit
// dans un `@Observable` que SEUL le modificateur lit : le contenu, déjà
// construit, ne bouge que par son `offset`.

@MainActor @Observable
final class TirageVersLeBas {
    /// La descente sous le doigt (négative : un peu d'élastique vers le haut).
    var tire: CGFloat = 0
    /// Le doigt a pris la feuille (le filtre d'axe est passé).
    @ObservationIgnored var pris = false
    /// Profil : le dépassement du haut de la liste, lu au lâcher.
    @ObservationIgnored var depassement: CGFloat = 0

    /// Le geste, posé sur ce qu'on tire. `.global` : posé sur la vue qu'il
    /// déplace, une translation locale rétrécirait à mesure qu'elle descend.
    func geste(seuil: CGFloat = 110, onFermer: @escaping () -> Void) -> some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .onChanged { [self] v in
                let dy = v.translation.height
                if !pris {
                    // Vers le bas et franchement vertical, sinon la feuille
                    // laisse le doigt aux autres (liste, boutons).
                    guard dy > 0, dy > abs(v.translation.width) * 1.2 else { return }
                    pris = true
                }
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) { tire = dy > 0 ? dy : dy * 0.15 }
            }
            .onEnded { [self] v in
                guard pris else { return }
                pris = false
                if v.translation.height > seuil || v.predictedEndTranslation.height > seuil * 2.2 {
                    Haptique.leger()
                    onFermer()
                } else {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) { tire = 0 }
                }
            }
    }

    /// Remettre à plat sans animation (après une fermeture).
    func remettre() {
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) { tire = 0 }
        pris = false
        depassement = 0
    }
}

/// Le seul lecteur de `tire` : le contenu descend, se resserre à peine et
/// arrondit ses coins — l'arbre, lui, n'est pas reconstruit.
struct DecalageTirage: ViewModifier {
    let etat: TirageVersLeBas
    var page = false

    func body(content: Content) -> some View {
        let t = max(etat.tire, 0)
        content
            .scaleEffect(page ? 1 - min(t, 300) / 3000 : 1, anchor: .top)
            .clipShape(RoundedRectangle(cornerRadius: page ? (t > 1 ? 44 : 0) : 0, style: .continuous))
            .offset(y: etat.tire)
    }
}

// MARK: - La nav du bas cachée sur une page (05-10)

/// Une page plein écran (Profil, Réglages) DEMANDE que la nav se cache tant
/// qu'elle est l'onglet affiché. Le registre de `NavEtat` cache la nav dès
/// qu'UNE demande dit non — une demande « oui » restée d'une autre page ne
/// peut plus la rallumer ici.
struct NavCachee: ViewModifier {
    let jeton: String
    let actif: Bool

    func body(content: Content) -> some View {
        content
            .onChange(of: actif, initial: true) { _, a in
                if a { NavEtat.shared.publierBande(jeton, visible: false) }
                else { NavEtat.shared.retirerBande(jeton) }
            }
            .onDisappear { NavEtat.shared.retirerBande(jeton) }
    }
}
