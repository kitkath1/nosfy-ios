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
            SwapCardHeading(title: "Ta première séance",
                            subtitle: "Rien ici pour l'instant")

            Spacer(minLength: 20)

            // Le cartouche bas garde le rythme typographique des vraies
            // cartes — mais il parle PLUS BAS (opacités 0,34/0,72, resserré
            // à 5 pt) : une carte sans contenu n'a rien à affirmer.
            SwapCardStat(label: "POUR COMMENCER", value: "le galet, en bas",
                         labelOpacity: 0.34, valueOpacity: 0.72, spacing: 5)
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        // La matière vit dans le design system (SwapCardSurface.swift) —
        // ici le tube ne vient pas d'un geste : il RESPIRE (`.respiration`,
        // et l'amplitude de la respiration est documentée là-bas). Le pull
        // vertical est le neutre historique de cette carte.
        .background {
            SwapCardSurface(pull: CGSize(width: 0, height: 1),
                            lit: .respiration)
        }
        // La carte n'est pas un bouton : c'est le galet qu'il faut toucher,
        // et une carte qui répondrait au doigt enverrait le message inverse.
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
