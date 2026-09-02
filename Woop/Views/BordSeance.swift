import SwiftUI

// MARK: - LE CONTOUR DE SÉANCE — l'app respire tant que la séance dure

/// UNE BRAISE SUR L'ARÊTE DE L'ÉCRAN (sa demande du 02-09 : « tout l'écran est
/// entouré d'un contour rouge qui respire pour montrer que c'est en cours »).
///
/// ⚠️ **IL VIT AU CHÂSSIS, PAS DANS LA HOME.** Il dit l'état de l'APP, pas
/// celui d'un widget : monté dans une page, il s'éteindrait au changement
/// d'onglet alors que la séance, elle, continue. C'est la même raison qui a
/// fait monter le player à la racine (§3).
///
/// ⚠️ **AUCUN `.blur`, AUCUN `Canvas`.** Un `.blur` pose un voile uniforme sur
/// tout le rectangle de son hôte — ici l'écran entier, à chaque image ; et un
/// `Canvas` plein écran rasterise toute sa surface même vide. Les deux lois
/// sont payées dans ce dépôt. Le dégradé se fait donc en **quatre passes de
/// `strokeBorder`** de largeurs décroissantes : du pur vecteur, l'école exacte
/// de la lueur de l'ardoise (« le MÊME liseré, une passe de plus »).
///
/// ⚠️ **`strokeBorder` et non `stroke`** : un `stroke` est centré sur le
/// chemin, donc la moitié de chaque passe tomberait HORS de l'écran et la
/// braise paraîtrait deux fois plus fine qu'elle n'est. `strokeBorder` rentre
/// vers l'intérieur — l'arête reste l'arête.
struct BordSeance: View {
    /// Une séance est ouverte. `false` : rien n'est monté, aucune horloge.
    var actif: Bool
    /// LE RAYON BAS DE LA CARD. ⚠️ **Il épouse la CARD, pas l'écran** (verdict
    /// 02-09 : « ça doit bouger que dans la card, pas dans le player »). Le
    /// haut de la card n'a pas de coins — il fond dans l'heure (§2.18) — donc
    /// la forme est une `UnevenRoundedRectangle`, et la braise s'arrête net au
    /// bas de la card : la bande du player reste à elle.
    var rayonBas: CGFloat = 30

    /// `-bordSeance` : la braise allumée SANS séance en base. Le simulateur ne
    /// démarre pas de séance tout seul. `static let` : évalué une fois.
    static let banc = CommandLine.arguments.contains("-bordSeance")
    /// `-sansBord` : le contour ÉTEINT, tout le reste identique. C'est la seule
    /// façon de répondre à « est-ce le contour ou la page ? » sans deviner.
    static let eteint = CommandLine.arguments.contains("-sansBord")

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// LES DEUX PÉRIODES, PREMIÈRES ENTRE ELLES — et c'est une loi de la
    /// maison, payée sur les liserés des cards et sur la fumée d'invite : un
    /// seul sinus se reconnaît en trois cycles et devient un CLIGNOTANT. Deux
    /// périodes incommensurables ne repassent jamais par le même état.
    ///
    /// ⚠️ Et elles ne sont pas celles de la fumée (7,3 et 11,7) : deux
    /// respirations à l'écran qui partagent une période finiraient par battre
    /// ensemble, et on lirait un métronome.
    private static let periodeA: Double = 6.1
    private static let periodeB: Double = 9.7

    /// LE PLANCHER N'EST PAS ZÉRO. La braise ne doit jamais disparaître : ce
    /// qu'elle dit — « une séance est en cours » — est vrai en permanence, et
    /// un signe d'état qui s'éteint par moments se lit comme un bug. Elle
    /// respire entre 0,40 et 1,00, jamais entre 0 et 1.
    private func souffle(_ t: Double) -> Double {
        guard !reduceMotion else { return 0.78 }
        let a = sin(t * 2 * .pi / Self.periodeA)
        let b = sin(t * 2 * .pi / Self.periodeB + 1.3)
        return 0.70 + 0.20 * a + 0.10 * b
    }

    var body: some View {
        if actif, !Self.eteint {
            // 20 Hz — la cadence à laquelle elle a dit « j'aime bien
            // l'épaisseur ». La fluidité ne se règle PAS ici (voir
            // tools/home-v2/ANALYSE-HOME-VIVANTE.md, §FLUIDITÉ).
            TimelineView(.animation(minimumInterval: 1.0 / 20.0,
                                    paused: reduceMotion)) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 900)
                contour(souffle(t), t * 360 / 9)
            }
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }

    /// LE RUBAN — c'est CETTE version qu'elle a validée (« j'aime bien
    /// l'épaisseur »), et c'est la seule chose qu'on garde.
    ///
    /// Trois couches serrées sur l'arête : le lit pose la couleur, le ruban est
    /// ce qu'on voit courir, le fil donne une tête à la lumière. Le dégradé
    /// TOURNE, la forme ne bouge pas — la loi des liserés de cette maison.
    ///
    /// ⚠️ Sa fluidité ne se corrige NI en changeant la cadence, NI en empilant
    /// moins de couches : les deux ont été essayés et mesurés, et les deux ont
    /// empiré. L'analyse est dans `tools/home-v2/ANALYSE-HOME-VIVANTE.md`.
    @ViewBuilder
    private func contour(_ s: Double, _ sTour: Double) -> some View {
        let forme = UnevenRoundedRectangle(
            topLeadingRadius: 0, bottomLeadingRadius: rayonBas,
            bottomTrailingRadius: rayonBas, topTrailingRadius: 0,
            style: .continuous)
        ZStack {
            forme
                .strokeBorder(Self.nappe(s * 0.55, .degrees(sTour)),
                              lineWidth: 14)
                .blur(radius: 14)
            forme
                .strokeBorder(Self.nappe(s, .degrees(sTour + 8)),
                              lineWidth: 5)
                .blur(radius: 4)
            forme
                .strokeBorder(Self.nappe(s * 1.15, .degrees(sTour + 18)),
                              lineWidth: 1.6)
                .blur(radius: 1.2)
        }
        .padding(2)
        .mask {
            LinearGradient(stops: [
                .init(color: .clear, location: 0.00),
                .init(color: .white.opacity(0.28), location: 0.10),
                .init(color: .white.opacity(0.80), location: 0.20),
                .init(color: .white, location: 0.30),
                .init(color: .white, location: 1.00)
            ], startPoint: .top, endPoint: .bottom)
        }
        .blendMode(.plusLighter)
    }

    /// LA NAPPE QUI TOURNE — trois crêtes de braise séparées par des zones
    /// MORTES. Ce sont les zones mortes qui font qu'on voit la lumière se
    /// déplacer : sans elles, l'anneau est uniforme et rien ne bouge.
    ///
    /// ⚠️ Des épaules FRANCHES, pas des fondus mous — la leçon écrite du
    /// liseré des cards : « des épaules franches, sinon la lumière bave sur
    /// tout le contour ». Le flou de 62 pt se charge de les adoucir ; s'il
    /// faut adoucir DEUX fois, c'est qu'il n'y a plus de forme du tout.
    ///
    /// ⚠️ Loi anti-brun : R reste à 1,00 partout, seul le VERT bouge — c'est
    /// lui qui fait passer de la braise profonde à l'orange.
    private static func nappe(_ f: Double, _ a: Angle) -> AngularGradient {
        func c(_ v: Double, _ o: Double) -> Color {
            Color(red: 1.0, green: v, blue: v * 0.28).opacity(o * f)
        }
        // ⚠️ **CE SONT LES ZONES MORTES QUI FONT VOIR LE MOUVEMENT** (verdict
        // 02-09 : « pas assez poussée, on capte pas »). Mon premier jet les
        // laissait à 6-8 % : la nappe restait allumée partout, donc la
        // rotation ne se lisait pas — un anneau uniforme qui tourne est
        // immobile. Elles tombent à 1,5 %, et les crêtes montent : c'est le
        // CONTRASTE qui se voit, pas la vitesse seule.
        //
        // Et DEUX crêtes au lieu de trois : à trois, les creux ne font plus
        // qu'un tiers de tour chacun et la lumière n'a jamais l'air de
        // voyager — elle scintille sur place.
        //
        // ⚠️ **LES DEUX CRÊTES NE SONT SURTOUT PAS OPPOSÉES**, et c'est le
        // défaut que la sonde a attrapé : à 0,17 et 0,66 elles étaient à
        // 176° l'une de l'autre — donc le flanc GAUCHE et le flanc DROIT
        // voyaient la même phase et s'allumaient ENSEMBLE. Mesuré : la
        // corrélation gauche/droite était montée à +0,56, c'est-à-dire que
        // la nappe PULSAIT au lieu de tourner. À 0,17 et 0,48 (112°), les
        // deux flancs ne peuvent plus culminer en même temps.
        return AngularGradient(stops: [
            .init(color: c(0.16, 0.015), location: 0.000),
            .init(color: c(0.30, 0.55), location: 0.090),
            .init(color: c(0.52, 1.20), location: 0.150),
            .init(color: c(0.80, 1.55), location: 0.172),   // CŒUR blanc-chaud
            .init(color: c(0.52, 1.15), location: 0.194),
            .init(color: c(0.30, 0.50), location: 0.255),
            .init(color: c(0.14, 0.015), location: 0.330),  // MORTE
            .init(color: c(0.16, 0.40), location: 0.400),
            .init(color: c(0.30, 1.05), location: 0.462),
            .init(color: c(0.62, 1.30), location: 0.482),   // CŒUR chaud
            .init(color: c(0.30, 1.00), location: 0.502),
            .init(color: c(0.16, 0.38), location: 0.575),
            .init(color: c(0.14, 0.015), location: 0.760),  // MORTE (longue)
            .init(color: c(0.16, 0.015), location: 1.000)
        ], center: .center, angle: a)
    }

    /// LE ROUGE DE LA MAISON — exactement celui du halo de la story TOP
    /// (`StorySuite.swift`, `halo`), jamais un rouge neuf : deux rouges à
    /// l'écran, ce sont deux marques.
    ///
    /// ⚠️ LOI ANTI-BRUN : « R reste à 1,00, on désature le VERT ». Une braise
    /// dont on baisse le rouge vire au brun — faute payée au jalon 1 du
    /// rasant, et deux fois depuis.
    private static let rouge = Color(red: 1.0, green: 0.20, blue: 0.05)
}
