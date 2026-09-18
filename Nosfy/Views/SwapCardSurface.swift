import SwiftUI

// MARK: - L'écrin des cartes swap (design system)

/// LA MATIÈRE DES CARTES SWAP — extraite le 2026-08-18 pour le design
/// system (chantier carnet de cuir) : jusque-là, `SwapWorkoutCard` et
/// `SwapEmptyCard` portaient chacune une copie verbatim de cet hôte de
/// shader. La recette vit dans `swapCard` (AuroraHome.metal) : noir mat
/// brossé, sheen d'incidence (~34 s), fresnel du bord, hairline morte au
/// repos, foyer directionnel qui suit le doigt, tube de néon iso-distance
/// −14 pt, glow extérieur, pointes-bijou, poinçon du croissant. Ici il n'y
/// a QUE l'hôte : le gabarit (220 × 282), l'éventail, le reflet et la gerbe
/// restent à `SwapDeck` — l'écrin est la matière, pas la mise en scène.
///
/// Deux régimes de tube, et c'est TOUTE la différence entre les deux
/// consommatrices :
/// - `.geste(tapAt:)` — le tube est ÉTEINT au repos, il ne vit que de la
///   charge du geste et de la bouffée du toucher (les vraies cartes) ;
/// - `.respiration` — le tube respire, jamais éteint (l'état vide, qui
///   invite au lieu de répondre).
struct SwapCardSurface: View {
    /// Ce qui allume le tube de néon.
    enum Lit {
        /// La bouffée du toucher : 0,10 s d'attaque, ~0,45 s d'extinction,
        /// puis le tube se rendort. Le neutre est `.distantPast`.
        case geste(tapAt: Date)
        /// La respiration de l'invitation. L'AMPLITUDE EST LE SUJET : à
        /// 0,52-0,82 le tube devient une CORDE orange fermée d'épaisseur
        /// égale autour d'un aplat noir — la grammaire refusée huit fois
        /// sur la fente. Sur les vraies cartes ce niveau n'existe qu'une
        /// fraction de seconde, sous le doigt ; en respiration permanente
        /// il serait une enseigne. À 0,30-0,56 la carte est vivante et
        /// invite, sans se transformer en enseigne. Et elle ne descend
        /// jamais à zéro : un néon qui s'éteint clignote, et un
        /// clignotement dit « erreur », pas « viens ».
        case respiration
    }

    /// La phase de la carte : plusieurs cartes, plusieurs reflets
    /// désynchronisés (la pile passe la profondeur).
    var seed: Float = 0
    /// La montée du geste (0 → 1) : l'écrin s'embrase avec elle.
    var charge: Float = 0
    /// La direction où le doigt tire (unitaire) : le foyer de lumière s'y
    /// masse à mesure que la charge monte.
    var pull: CGSize = CGSize(width: 1, height: 0)
    /// Le régime du tube.
    var lit: Lit = .geste(tapAt: .distantPast)

    /// Marge du shader : au repos le souffle doré de l'arête tient en
    /// quelques points, mais sous le geste le halo déborde loin — un shader
    /// ne peint que dans son rectangle hôte.
    static let pad: CGFloat = 54
    /// Le rayon de la famille swap.
    static let cornerRadius: CGFloat = 24

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width + Self.pad * 2
            let h = geo.size.height + Self.pad * 2
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                let t = Float(tl.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 900))
                Rectangle()
                    .fill(.white)
                    .frame(width: w, height: h)
                    .colorEffect(ShaderLibrary.swapCard(
                        .float2(w, h), .float(t),
                        .float(Float(Self.pad)),
                        .float(Float(Self.cornerRadius)), .float(seed),
                        .float(charge),
                        .float2(Float(pull.width), Float(pull.height)),
                        .float(neon(at: tl.date, t: t)),
                        // `noir` 0 : la home garde son obsidienne.
                        // `enterre` très négatif : rien n'est enfoncé dans
                        // quoi que ce soit ici. Le neutre de ce paramètre
                        // n'est PAS zéro — zéro voudrait dire « le bord bas
                        // touche la ligne de coupe d'une fente », et
                        // tuerait tube et fresnel.
                        // `nu` 0 : l'arête et le tube naissent ensemble du
                        // geste, c'est la loi de la home.
                        .float(0), .float(-4000), .float(0)))
            }
            .offset(x: -Self.pad, y: -Self.pad)
        }
        .allowsHitTesting(false)
    }

    /// La lumière du tube à cet instant, selon le régime.
    private func neon(at date: Date, t: Float) -> Float {
        switch lit {
        case .geste(let tapAt):
            // Le tube ne vit que du geste et du toucher. Le tap y souffle
            // une bouffée qui retombe seule.
            let since = date.timeIntervalSince(tapAt)
            let pulse = since < 0 ? 0
                : Float(min(since / 0.10, 1) * exp(-max(since - 0.10, 0) / 0.45))
            return max(charge, min(pulse, 1))
        case .respiration:
            return 0.30 + 0.26 * (0.5 + 0.5 * sin(t * 1.15))
        }
    }
}

// MARK: - L'en-tête des cartes swap

/// Le haut de carte de la famille : le titre qui respire sous la nappe du
/// tube (14 pt du bord, il porte loin — collé en haut, le texte baignait
/// dedans), la ligne grise dessous. Partagé par la vraie carte et l'état
/// vide — même corps, mêmes opacités, mêmes marges.
struct SwapCardHeading: View {
    let title: String
    let subtitle: String

    var body: some View {
        Text(title)
            .font(.inter(19, .medium))
            .foregroundStyle(Color.white.opacity(0.95))
            .padding(.top, 8)
            .lineLimit(1)
            .minimumScaleFactor(0.7)

        Text(subtitle)
            .font(.inter(11))
            .foregroundStyle(Color.white.opacity(0.46))
            .padding(.top, 5)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

// MARK: - Le cartouche des cartes swap

/// Une mesure du cartouche bas : l'étiquette murmure en capitales espacées,
/// la valeur se pose dessous. Les opacités sont des paramètres parce que
/// l'état vide parle PLUS BAS que les vraies cartes (0,34/0,72 contre
/// 0,46/0,88) — c'est voulu, pas une dérive : une carte sans contenu n'a
/// rien à affirmer.
struct SwapCardStat: View {
    let label: String
    let value: String
    var labelOpacity: Double = 0.46
    var valueOpacity: Double = 0.88
    var spacing: CGFloat = 7

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            // Relevées : à 30 % de blanc, la nappe d'or du tube les mangeait.
            Text(label)
                .font(.inter(8.5, .medium))
                .tracking(1.3)
                .foregroundStyle(Color.white.opacity(labelOpacity))
            Text(value)
                .font(.inter(12.5))
                .foregroundStyle(Color.white.opacity(valueOpacity))
        }
        // Un chiffre ne se plie jamais : « 52 min » est un bloc.
        .lineLimit(1)
        .fixedSize(horizontal: false, vertical: true)
    }
}
