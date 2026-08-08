import SwiftUI

// MARK: - L'invitation

/// L'ÉTAT VIDE DE LA PILE. Plus une boîte grise avec une phrase dedans : la
/// MÊME carte que les autres, même matière, même gabarit — mais son néon est
/// ALLUMÉ et respire, au lieu de ne s'éveiller qu'au geste.
///
/// La raison est de lecture : une carte éteinte au milieu d'une page dit
/// « il n'y a rien ». Une carte allumée dans une pile vide dit « c'est ICI
/// que ça se passe » — l'objet est déjà là, il attend son contenu.
///
/// Et on ne demande pas de commencer une séance : on MONTRE où appuyer. Trois
/// chevrons descendent en cascade vers le galet de la barre, en boucle. Une
/// flèche qui bouge vaut mieux qu'une phrase qui explique.
struct SwapEmptyCard: View {
    /// La marge du shader : le halo du tube allumé déborde loin, et un shader
    /// ne peint que dans son rectangle hôte.
    private static let pad: CGFloat = 54

    var body: some View {
        VStack(spacing: 0) {
            card
                .frame(width: SwapDeck.cardWidth, height: SwapDeck.cardHeight)
            chevrons
                .padding(.top, 16)
        }
        // La pile réserve la même hauteur : passer de l'état vide aux vraies
        // cartes ne doit pas faire sauter la page.
        .frame(maxWidth: .infinity)
        .frame(height: SwapDeck.deckHeight + 46)
    }

    // MARK: La carte

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Ta première séance")
                .font(.inter(19, .medium))
                .foregroundStyle(Color.white.opacity(0.95))
                .padding(.top, 8)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text("Rien ici pour l'instant")
                .font(.inter(11))
                .foregroundStyle(Color.white.opacity(0.46))
                .padding(.top, 5)
                .lineLimit(1)

            Spacer(minLength: 20)

            // Le cartouche bas garde le rythme typographique des vraies
            // cartes : une étiquette qui murmure, une valeur qui se pose.
            VStack(alignment: .leading, spacing: 5) {
                Text("POUR COMMENCER")
                    .font(.inter(8.5, .medium))
                    .tracking(1.3)
                    .foregroundStyle(Color.white.opacity(0.34))
                Text("le galet, en bas")
                    .font(.inter(12.5))
                    .foregroundStyle(Color.white.opacity(0.72))
            }
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background { ecrin }
        // La carte n'est pas un bouton : c'est le galet qu'il faut toucher,
        // et une carte qui répondrait au doigt enverrait le message inverse.
        .allowsHitTesting(false)
    }

    /// La matière, à l'identique de `SwapWorkoutCard` — mais `lit` ne vient
    /// plus d'un geste : il RESPIRE. Une respiration lente et jamais éteinte
    /// (0,52 au creux) : un néon qui descend à zéro clignote, et un
    /// clignotement dit « erreur », pas « viens ».
    private var ecrin: some View {
        GeometryReader { geo in
            let pad: CGFloat = Self.pad
            let w: CGFloat = geo.size.width + pad * 2
            let h: CGFloat = geo.size.height + pad * 2
            let wf: Float = Float(w)
            let hf: Float = Float(h)
            let padf: Float = Float(pad)
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                let t: Float = Float(tl.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 900))
                // L'AMPLITUDE EST LE SUJET. À 0,52-0,82 le tube devient une
                // CORDE orange fermée d'épaisseur égale autour d'un aplat
                // noir — la grammaire refusée huit fois sur la fente. Sur les
                // vraies cartes ce niveau n'existe qu'une fraction de seconde,
                // sous le doigt ; ici il serait permanent. À 0,30-0,56 la
                // carte est vivante et invite, sans se transformer en enseigne.
                let breath: Float = 0.30 + 0.26 * (0.5 + 0.5 * sin(t * 1.15))
                Rectangle()
                    .fill(.white)
                    .frame(width: w, height: h)
                    .colorEffect(ShaderLibrary.swapCard(
                        .float2(wf, hf), .float(t),
                        .float(padf), .float(24), .float(0),
                        // `charge` 0 : aucun geste ne la tire.
                        .float(0),
                        .float2(0, 1),
                        // `lit` : le tube, allumé et vivant.
                        .float(breath),
                        // `noir` 0 : l'obsidienne de la home, comme ses sœurs.
                        .float(0),
                        // `enterre` : le neutre vaut -4000, PAS zéro — zéro
                        // dirait que le pied de la carte touche la ligne de
                        // coupe d'une fente, et tuerait tube et fresnel.
                        .float(-4000),
                        // `nu` 0 : ici l'arête et le tube naissent ensemble,
                        // c'est la loi de la home.
                        .float(0)))
            }
            .offset(x: -pad, y: -pad)
        }
        .allowsHitTesting(false)
    }

    // MARK: Les chevrons

    /// Trois chevrons, et une lumière qui les DESCEND en boucle. Ils ne
    /// clignotent pas ensemble — c'est le passage de l'un à l'autre qui fait
    /// le mouvement, et le mouvement est ce qui désigne.
    private var chevrons: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            // 1,5 s par descente, puis le cycle reprend.
            let phase = (t / 1.5).truncatingRemainder(dividingBy: 1)
            VStack(spacing: -3) {
                ForEach(0..<3, id: \.self) { i in
                    let u = pass(phase, i)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(red: 1.0, green: 0.80, blue: 0.52)
                            .opacity(0.16 + 0.66 * u))
                        .offset(y: u * 2.5)
                        .shadow(color: Color(red: 1.0, green: 0.55, blue: 0.16)
                            .opacity(0.55 * u), radius: 6)
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// Le passage de la lumière sur le chevron `i` : un triangle, pas un
    /// créneau — l'allumage et l'extinction ont la même pente, donc rien ne
    /// claque.
    private func pass(_ phase: Double, _ i: Int) -> Double {
        let center = 0.16 + Double(i) * 0.17
        var d = abs(phase - center)
        // La boucle est circulaire : le chevron du haut doit pouvoir se
        // rallumer par la fin du cycle sans coupure.
        d = min(d, 1 - d)
        return max(0, 1 - d / 0.21)
    }
}
