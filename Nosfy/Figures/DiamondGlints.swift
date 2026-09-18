import SwiftUI

// MARK: - Éclats bijou

/// Les éclats-étoiles du bouton CONNEXION (voir `diamondGlints` dans
/// DiamondButton.metal), extraits en overlay réutilisable : quelques facettes
/// qui flashent sur le périmètre du composant — une bague qu'on tourne sous
/// la lumière, jamais une guirlande. Monochrome blanc, prémultiplié : hors
/// des flashs, l'overlay n'existe pas.
///
/// `strength` : 1.0 = registre du CONNEXION (CTA) ; ~0.5-0.7 = murmure pour
/// les cartes. Coupé par Reduce Motion.
struct DiamondGlints: View {
    var cornerRadius: CGFloat
    var strength: Double = 1.0

    /// Marge de débordement : les rayons des étoiles dépassent un peu du bord.
    private static let pad: CGFloat = 12

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var onScreen = true

    var body: some View {
        // Le porteur de la sonde de visibilité est un calque VIDE qui, lui,
        // ne disparaît jamais : sous le pli, on retire le TimelineView, pas
        // l'observateur — sinon plus personne pour annoncer le retour.
        Color.clear
            .overlay {
                // Depuis que la surface diamant sert TOUTES les cartes, une
                // grille en porte une douzaine à l'écran : un TimelineView qui
                // continue de battre sous le pli est du courant dépensé pour
                // personne. Hors ScrollView le rappel ne se déclenche pas et la
                // valeur reste à `true` — dégradation sans risque (même contrat
                // que la carte hebdomadaire).
                if !reduceMotion && onScreen {
                    GeometryReader { geo in
                        let w = geo.size.width + Self.pad * 2
                        let h = geo.size.height + Self.pad * 2
                        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                            let t = Float(tl.date.timeIntervalSinceReferenceDate
                                .truncatingRemainder(dividingBy: 900))
                            Rectangle()
                                .fill(.white)
                                .frame(width: w, height: h)
                                .colorEffect(ShaderLibrary.diamondGlints(
                                    .float2(Float(w), Float(h)), .float(t),
                                    .float(Float(Self.pad)), .float(Float(cornerRadius)),
                                    .float(Float(strength))))
                        }
                        .offset(x: -Self.pad, y: -Self.pad)
                    }
                }
            }
            .onScrollVisibilityChange(threshold: 0.02) { visible in
                onScreen = visible
            }
            .allowsHitTesting(false)
    }
}

extension View {
    /// Sème les éclats-étoiles du registre diamant sur le contour de la vue.
    func diamondGlints(cornerRadius: CGFloat, strength: Double = 1.0) -> some View {
        overlay { DiamondGlints(cornerRadius: cornerRadius, strength: strength) }
    }
}
