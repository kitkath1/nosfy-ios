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
        if actif {
            // 20 Hz : un souffle de 6 s n'a pas besoin de 60. C'est la cadence
            // que le dépôt donne déjà à ses respirations lentes, et elle divise
            // la note par trois.
            // ⚠️ **20 Hz, ET C'EST MESURÉ — pas un compromis de principe.**
            //
            // J'étais passé à 60 Hz en croyant que le « pas fluide » venait de
            // la cadence. La sonde dit l'inverse : en séance, machine calme,
            // 60 Hz rend **4,5 img/s** et 20 Hz **6,1**. Trois passes de flou
            // plein cadre par image coûtent plus cher que le gain de netteté
            // qu'elles achètent — à 60 Hz on demande le triple de travail pour
            // dessiner une crête qui n'avance que de 0,7° de plus.
            //
            // La saccade venait du COÛT, pas du pas d'horloge : c'est en
            // retirant des passes qu'on la fait disparaître, pas en en
            // demandant plus souvent.
            TimelineView(.animation(paused: reduceMotion)) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 900)
                // UN TOUR EN 9 s. À 17 s, mesuré au film, la corrélation
                // gauche/droite valait +0,33 : la lumière voyageait vraiment,
                // mais trop lentement pour qu'on le PERÇOIVE — « on capte
                // pas ». Le mouvement doit se lire en une respiration, pas en
                // une minute.
                contour(souffle(t), t * 360 / 9)
            }
            // ⚠️ SOURD AU DOIGT. Il couvre l'écran entier : sans ça il
            // mangerait TOUS les touchers de l'app pendant la séance — le
            // piège du rideau, en version totale.
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }

    /// LES QUATRE PASSES. Elles partent toutes de l'arête et rentrent : la plus
    /// large est la plus faible (la lueur qui déborde dans la page), la plus
    /// fine est la plus vive (l'arête elle-même). C'est cette pile, et non un
    /// flou, qui fait la douceur.
    /// LA RECETTE EST CELLE DU HALO DE LA STORY TOP — `StorySuite.swift`
    /// (`halo`, autour de la ligne 1031). C'est SA référence : « comme la
    /// story ×2, tout le bord de l'écran animé en rouge ».
    ///
    /// ⚠️ **ET C'EST LE FLOU QUI FAIT TOUT.** Mon premier jet posait quatre
    /// traits NETS de largeurs décroissantes pour éviter une passe hors écran :
    /// ça donnait un cadre CERNÉ, pas un néon. Le néon vient de trois passes
    /// FLOUES (26, 8 et 1,1 pt) plus une arête blanche au cœur — la lumière
    /// déborde de son trait, c'est sa définition.
    ///
    /// ⚠️ Le prix est connu et assumé : trois `.blur` sur une forme plein
    /// écran, c'est trois passes hors écran par image. Dans la story ça dure
    /// une seconde ; ici ça dure toute la séance. **La cadence est donc à
    /// mesurer, pas à supposer** — et si elle ne tient pas, c'est le nombre de
    /// passes qui baisse, jamais le flou (sans lui il n'y a plus de néon).
    @ViewBuilder
    private func contour(_ s: Double, _ sTour: Double) -> some View {
        let forme = UnevenRoundedRectangle(
            topLeadingRadius: 0, bottomLeadingRadius: rayonBas,
            bottomTrailingRadius: rayonBas, topTrailingRadius: 0,
            style: .continuous)
        // ⚠️ **LA LUMIÈRE VOYAGE, ELLE NE PULSE PAS** (verdict 02-09 : « pas
        // type néon, type blur joli très fondu, type IA qui parle »).
        //
        // C'est la loi que ce dépôt a déjà écrite pour le liseré des cards :
        // « on ne fait PAS tourner la forme — on fait tourner le DÉGRADÉ : les
        // crêtes glissent le long d'un contour qui, lui, ne bouge pas d'un
        // pixel. C'est la lumière qui se promène, pas l'objet. »
        // (`cardLisereConique`, WidgetsCards.swift:361-367.)
        //
        // Deux couches qui tournent à des vitesses DIFFÉRENTES et en SENS
        // CONTRAIRE : leurs crêtes se croisent sans jamais se retrouver, donc
        // la figure ne se répète pas. Un seul anneau qui tourne, aussi lent
        // soit-il, finit par se reconnaître — c'est la même faute qu'un sinus
        // unique, en rotation.
        //
        // ⚠️ AUCUNE ARÊTE NETTE : c'est un cœur net, si fin soit-il, qui
        // dessine une LIGNE — et une ligne se lit comme une bordure. Il ne
        // reste ici que de la lumière très étalée.
        // ⚠️ **UN RUBAN FIN SUR L'ARÊTE, PAS UN HALO** (verdict 02-09 : « pourquoi
        // t'as fait de gros halos… là ça fait un peu fake »). C'est l'erreur
        // que j'ai faite en cherchant « très fondu » : un trait de 58 pt flouté
        // à 62 n'est pas de la lumière, c'est un LAVIS — il bave dans la page,
        // il n'a plus de bord, et rien ne dit plus où est l'arête.
        //
        // La lueur d'Apple Intelligence est l'inverse : une bande ÉTROITE et
        // VIVE collée au bord, à peine adoucie, dont les couleurs COURENT. Ce
        // qui la fait vivre est le mouvement le long de l'arête, pas l'étendue.
        //
        // Trois couches, de la plus large à la plus fine, toutes serrées :
        //  · le lit (14 pt, flou 14) — il pose la couleur et la fait déborder
        //    d'un cheveu, juste assez pour que l'arête ne soit pas dure ;
        //  · le ruban (5 pt, flou 4) — c'est LUI qu'on voit courir ;
        //  · le fil (1,6 pt, flou 1,2) — le cœur vif, décalé en phase, qui
        //    donne l'impression que la lumière a une TÊTE.
        // ⚠️ **DEUX COUCHES, PLUS TROIS** (verdict 02-09 : « c'est pas trop
        // fluide »). Sur un dégradé qui tourne, le manque de fluidité n'est
        // presque jamais la cadence — c'est le COÛT : chaque `.blur` sur une
        // forme plein cadre est une passe HORS ÉCRAN, et j'en demandais trois
        // par image. Le simulateur décroche, et le mouvement devient saccadé
        // alors que l'horloge, elle, est régulière.
        //
        // Le fil de 1,6 pt disparaît : il ne portait presque rien, et son flou
        // de 1,2 coûtait une passe entière. Le lit et le ruban suffisent — le
        // cœur vif est désormais DANS le dégradé (le point blanc-chaud), pas
        // dans une couche de plus.
        // ⚠️ **PLUS AUCUN `.blur` — ET C'EST LA CAUSE DU « ÇA LAG »**
        // (verdict 02-09 : « l'animation autour des bordures qui fait IA lag,
        // elle est pas naturelle »).
        //
        // Deux flous plein cadre par image ne peuvent être fluides À AUCUNE
        // CADENCE : à 60 Hz c'est le coût qui saccade (mesuré 4,5 img/s en
        // séance), à 20 Hz c'est le pas d'horloge qu'on voit. J'ai passé deux
        // tours à choisir entre les deux au lieu de sortir du piège.
        //
        // La douceur ne vient pas d'un flou, elle vient de DEUX sources qui ne
        // coûtent rien :
        //  · EN TRAVERS de la bande — une pile de `strokeBorder` concentriques
        //    d'opacité décroissante ; c'est l'école exacte de la lueur de
        //    l'ardoise (« le MÊME liseré, une passe de plus »), et c'est du
        //    pur vecteur ;
        //  · LE LONG de la bande — les épaules du dégradé angulaire, qui
        //    étaient déjà là et que le flou ne faisait que redoubler.
        //
        // Résultat : zéro passe hors écran, donc 60 Hz gratuit, donc une
        // lumière qui coule vraiment.
        ZStack {
            forme.strokeBorder(Self.nappe(s * 0.10, .degrees(sTour)), lineWidth: 34)
            forme.strokeBorder(Self.nappe(s * 0.16, .degrees(sTour)), lineWidth: 24)
            forme.strokeBorder(Self.nappe(s * 0.24, .degrees(sTour)), lineWidth: 16)
            forme.strokeBorder(Self.nappe(s * 0.34, .degrees(sTour + 4)), lineWidth: 10)
            forme.strokeBorder(Self.nappe(s * 0.50, .degrees(sTour + 8)), lineWidth: 5.5)
            forme.strokeBorder(Self.nappe(s * 0.70, .degrees(sTour + 12)), lineWidth: 2.5)
            forme.strokeBorder(Self.nappe(s * 0.85, .degrees(sTour + 16)), lineWidth: 1)
        }
        .padding(2)
        // ⚠️ **LE HAUT MEURT — ET C'EST LA LOI DE LA CARD, PAS UN RÉGLAGE.**
        // La robe n'a pas de coins hauts : « le haut FOND dans l'heure, le
        // liseré meurt vers le haut » (§2.18, PageCard). Sans cette rampe, le
        // `strokeBorder` referme la braise par un TRAIT DROIT en travers du
        // haut de l'écran — vu sur l'appareil, et c'est laid : on lit une
        // bordure collée, pas une lumière.
        //
        // Le fondu part de RIEN au ras du haut et n'atteint sa pleine force
        // qu'au quart de la card : les flancs émergent, le haut n'existe pas.
        .mask {
            LinearGradient(stops: [
                .init(color: .clear, location: 0.00),
                .init(color: .white.opacity(0.28), location: 0.10),
                .init(color: .white.opacity(0.80), location: 0.20),
                .init(color: .white, location: 0.30),
                .init(color: .white, location: 1.00)
            ], startPoint: .top, endPoint: .bottom)
        }
        // Les passes s'ADDITIONNENT : une braise est de la lumière, pas de la
        // peinture.
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
