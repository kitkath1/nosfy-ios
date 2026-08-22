import SwiftUI

// MARK: - LES DEUX CARDS DE LA HOME (jalon V3, plan § 12)
//
// La commande du 21-08, référence en main : « je veux exactement ça à
// 100 %, tous les détails, tout ». Deux widgets noirs, très travaillés :
//
//   CARD GAUCHE  « 4 / 5 · sessions this week » — sept pastilles, et en
//                pied un anneau d'ambre avec sa phrase.
//   CARD DROITE  « 8.4 t · weekly volume » — un bouton haltère, un graphe
//                de sept barres à segments d'ambre, un pied à deux colonnes.
//
// LA SIGNATURE, et c'est elle qu'il ne faut pas rater : DEUX TRAÎNÉES DE
// LUMIÈRE posées HORS du corps, séparées de lui par un jour de nuit — une
// DORÉE qui contourne le coin haut-droit, une BLANCHE au coin bas-gauche.
// Ce ne sont pas des liserés : ce sont des reflets, avec leur bloom, leurs
// bouts arrondis et leur extinction aux deux extrémités.
//
// TOUT est en FRACTION du corps de la card (largeur pour l'horizontal,
// hauteur pour le vertical) : la card doit survivre à sa taille. Les
// valeurs viennent de la sonde sur la référence (corps 607 × 613 px).
//
// Banc : `-cardsLab`. Note : `tools/home-v2/compare_widget.py` note le
// rendu contre la référence, région par région — la cible est 9,8/10.

// MARK: - La palette (échantillonnée sur la référence)

enum CardTon {
    /// L'ambre des segments et des chiffres de gain — mesuré #fbb566 au
    /// plus clair.
    static let ambreVif = Color(red: 0.98, green: 0.71, blue: 0.40)
    static let ambre = Color(red: 0.85, green: 0.63, blue: 0.37)
    static let ambreSombre = Color(red: 0.71, green: 0.50, blue: 0.27)
    /// L'or des traînées — presque crème à son sommet.
    static let orVif = Color(red: 1.00, green: 0.93, blue: 0.79)
    static let orChaud = Color(red: 0.99, green: 0.75, blue: 0.40)
    /// Les encres, mesurées : #fdfdfd · #959392 · #7f7e7e · #595959.
    static let encre = Color(white: 0.99)
    static let encreDouce = Color(white: 0.581)
    static let encreSourde = Color(white: 0.569)
    static let encreJour = Color(white: 0.589)
    /// Le corps : #171717 en haut, #0b0b0b au milieu et en bas.
    static let corpsHaut = Color(white: 0.090)
    static let corpsBas = Color(white: 0.043)
    /// Le rail des barres et le filet.
    static let railHaut = Color(white: 0.200)
    static let railBas = Color(white: 0.110)
    static let filet = Color(white: 0.155)
}

// MARK: - Les traînées de lumière

/// UN REFLET sur l'arête : la MÊME forme que le corps, agrandie du jour,
/// tracée au trait fin — puis MASQUÉE pour n'exister qu'autour d'un coin.
///
/// ⚠️ Le premier jet traçait un arc de CERCLE au rayon du corps. Or le
/// corps a des coins CONTINUS (la squircle d'Apple) : un arc circulaire du
/// même rayon s'en décolle au milieu du virage, et le reflet flotte à côté
/// de la card au lieu de l'épouser. La seule façon juste est de reprendre
/// la forme elle-même, agrandie.
///
/// Le masque fait deux choses d'un coup : il choisit le coin, ET il donne
/// l'extinction aux deux bouts — un reflet d'intensité constante serait un
/// liseré, donc un pictogramme.
struct CardTrainee: View {
    enum Coin { case hautDroit, basGauche }

    var coin: Coin
    /// Le rayon du corps, en fraction de la largeur.
    var rayon: CGFloat
    /// Le jour entre le bord du corps et le reflet.
    var jour: CGFloat = 0.017
    var epaisseur: CGFloat = 0.008
    var chaud = true
    /// La portée du reflet le long des bords, en fraction de la largeur.
    var portee: CGFloat = 0.47
    var lueur: Double = 0.55

    var body: some View {
        GeometryReader { g in
            let W = g.size.width, H = g.size.height
            let j = jour * W
            let e = max(0.8, epaisseur * W)
            let forme = RoundedRectangle(cornerRadius: rayon * W + j,
                                         style: .continuous)
            ZStack {
                forme.stroke(teinteVive, lineWidth: e * 3.4)
                    .blur(radius: e * 2.8)
                    .opacity(lueur)
                forme.stroke(teinteVive, lineWidth: e)
            }
            .frame(width: W + 2 * j, height: H + 2 * j)
            .position(x: W / 2, y: H / 2)
            .mask {
                RadialGradient(
                    stops: [
                        .init(color: .white, location: 0.00),
                        .init(color: .white.opacity(0.98), location: 0.42),
                        .init(color: .white.opacity(0.55), location: 0.70),
                        .init(color: .clear, location: 1.00),
                    ],
                    center: coin == .hautDroit ? .topTrailing
                                               : .bottomLeading,
                    startRadius: 0, endRadius: portee * W)
                .frame(width: W + 2 * j, height: H + 2 * j)
                .position(x: W / 2, y: H / 2)
            }
        }
    }

    private var teinteVive: LinearGradient {
        chaud
            ? LinearGradient(colors: [CardTon.orChaud, CardTon.orVif,
                                      CardTon.orChaud],
                             startPoint: .leading, endPoint: .trailing)
            : LinearGradient(colors: [Color(white: 1.0), Color(white: 0.86)],
                             startPoint: .bottom, endPoint: .top)
    }
}

// MARK: - Le corps

/// L'écrin commun aux deux cards. Deux découvertes de la sonde, et elles
/// changent tout :
///
/// 1. **LE CORPS N'EST PAS UNE SQUIRCLE.** Ajustement d'une superellipse sur
///    200 points du contour : n = 2,0 — c'est un ARC DE CERCLE PUR, de rayon
///    **14,6 % de la largeur**. Un coin continu d'Apple y met un galbe que
///    la référence n'a pas.
/// 2. **LE LISERÉ EST UN DÉGRADÉ ANGULAIRE.** Il fait le tour, et son
///    intensité tourne avec l'angle : deux POINTS MORTS aux coins haut-gauche
///    (#1B1A1A) et bas-droit (#141414), et deux CRÊTES aux coins haut-droit
///    (l'or, #FEF6D0 écrêté au blanc) et bas-gauche (le blanc pur). Les
///    « traînées » ne sont pas des objets posés à côté : **c'est ce liseré
///    lui-même, saturé sur un arc** — 141° au coin d'or, 118° au coin blanc.
///
/// Et la card est faite de DEUX coques : la bezel, puis un panneau encastré
/// de **3,45 % de la largeur**, avec son propre liseré (plus clair que
/// l'extérieur sur le bord haut) et sa bavure vers l'intérieur.
/// Aucune ombre portée, aucun halo ambiant : à 6 px du bord on est au fond.
struct CardCorps<Contenu: View>: View {
    /// Le rayon extérieur, en fraction de la largeur — CIRCULAIRE.
    var rayon: CGFloat = 0.152
    /// L'encastrement du panneau : 3,45 % de la largeur (21 px sur 607).
    var encastre: CGFloat = 0.0345
    /// LE LISERÉ ANGULAIRE et son bloom. Apple n'en met pas — mais il porte
    /// ici les deux crêtes de lumière qui font la bezel. À trancher à l'œil.
    var lisere: Bool = true
    /// LE FOND EN VERRE NATIF, à l'essai. ⚠️ La loi dit qu'il GIVRE ce qui
    /// est net, et une card de 170 pt n'est QUE de l'encre nette : on s'attend
    /// donc à un frost, pas à une lentille. Le banc est là pour le voir.
    var verre: Bool = false
    /// LA CHAMBRE NOIRE, 0 → 1. Sous le doigt, le verre se FERME : une plaque
    /// noire tombe derrière l'encre et le fond vidéo cesse de passer.
    /// ⚠️ Ce n'est PAS le verre qu'on éteint — il ignore `.opacity`. On pose
    /// une plaque PAR-DESSUS lui et SOUS l'encre.
    ///
    /// Et ce n'est pas un ornement : quand le globe clair de la vidéo passe
    /// derrière « 8.4 kg », la lisibilité tombe. Le noir arrive exactement au
    /// moment où l'on REGARDE — le verre pour l'ambiance, le noir pour lire.
    var chambre: Double = 0
    /// LA PLACE DU DOIGT dans la card, en points. La lumière la suit — la
    /// même loi que les halos du menu, déjà validée : la lumière suit la main.
    var doigt: CGPoint?
    /// L'INCLINAISON DE LA CARD (le mode édition), en degrés. La crête du
    /// liseré CONTRE-TOURNE de cet angle : la lampe reste fixe dans la pièce
    /// pendant que l'objet penche — la loi 1 de la maison appliquée au
    /// wiggle. Sans elle, la lumière voyagerait avec la card et l'oscillation
    /// se lirait comme un calque qui tourne, pas comme un objet qui respire.
    var penche: Double = 0
    @ViewBuilder var contenu: () -> Contenu

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { g in
            let W = g.size.width, H = g.size.height
            let e = encastre * W
            let dehors = RoundedRectangle(cornerRadius: rayon * W,
                                          style: .circular)
            let dedans = RoundedRectangle(cornerRadius: 0.1175 * W,
                                          style: .circular)
            ZStack {
                // ── 1. LA BEZEL. ⚠️ Presque noire en mode plein, mais
                // ABSENTE en mode verre : un fond opaque derrière un verre,
                // c'est un verre posé sur un mur — il ne peut rien réfracter.
                if !verre { dehors.fill(Color(white: 0.014)) }

                // ── 2. LE LISERÉ ANGULAIRE, d'un seul trait : il porte à la
                // fois le gris des bords ordinaires ET les deux crêtes.
                if lisere {
                    // ⚠️ L'HORLOGE DORT sous Reduce Motion, et elle est LENTE
                    // (12 Hz) : une dérive de 3° sur 9 s n'a aucun besoin de
                    // 60 images par seconde.
                    TimelineView(.animation(minimumInterval: 1.0 / 12,
                                            paused: reduceMotion)) { tl in
                        let t = tl.date.timeIntervalSinceReferenceDate
                        // LA RESPIRATION DU REPOS : ±3° sur 9,4 s. On ne la
                        // voit pas, on la sent. La période est volontairement
                        // bâtarde pour que deux cards voisines ne battent
                        // jamais ensemble.
                        let souffle = reduceMotion ? 0
                            : 3.0 * sin(t * 2 * .pi / 9.4)
                        // ET LA CRÊTE GLISSE SOUS LE DOIGT : 16° pendant que
                        // la chambre se ferme. C'est LE signal « objet réel » —
                        // un verre ne se prouve pas en bougeant son contenu,
                        // mais en déplaçant la lumière sur sa surface.
                        let gr = cardLisereConique(
                            .degrees(souffle + 16 * chambre - penche))
                        ZStack {
                            dehors.stroke(gr, lineWidth: 1.6)
                            dehors.stroke(gr, lineWidth: 4.4)
                                .blur(radius: 2.4)
                                .opacity(0.46)
                            // LE CADRE S'ALLUME QUAND LA CHAMBRE SE FERME : ce
                            // qui identifie l'objet ne bouge jamais, seul son
                            // intérieur change — il devient PLUS présent.
                            dehors.stroke(gr, lineWidth: 2.6)
                                .blur(radius: 1.2)
                                .opacity(0.55 * chambre)
                        }
                        .frame(width: W, height: H)
                    }
                }
                if verre {
                    GlassEffectContainer(spacing: 0) {
                        Color.clear
                            .frame(width: W, height: H)
                            .glassEffect(.clear, in: dehors)
                    }
                }

                // ── 3. LE PANNEAU ENCASTRÉ
                ZStack {
                    // LA MATIÈRE, modèle exact de la sonde : ce n'est ni un
                    // aplat ni un dégradé linéaire, mais un plancher très bas
                    // et DEUX lueurs radiales posées sur l'anti-diagonale —
                    // la haut-droite qui culmine à #282828, la bas-gauche aux
                    // deux tiers de sa force (#1B1B1B). Strictement NEUTRE :
                    // |R−B| ≤ 0,7/255 partout, toute la chaleur de la card
                    // vient des reflets et du contenu, jamais du fond.
                    dedans.fill(Color(white: 0.012))
                        .opacity(verre ? 0 : 1)
                    // Les deux lueurs de l'anti-diagonale survivent en mode
                    // verre, mais au TIERS : elles disent la lumière posée
                    // sans reboucher ce qu'on vient d'ouvrir.
                    // Les deux lueurs GLISSENT VERS LE DOIGT de 7 pt au
                    // plus : au-delà, la lumière n'accompagne plus la main,
                    // elle la poursuit.
                    let dx = ((doigt.map { $0.x / W } ?? 0.5) - 0.5) * 0.090
                    let dy = ((doigt.map { $0.y / H } ?? 0.5) - 0.5) * 0.090
                    dedans.fill(RadialGradient(
                        colors: [Color(white: 0.157), .clear],
                        center: UnitPoint(x: 1 + dx, y: 0 + dy),
                        startRadius: 0, endRadius: W * 1.12))
                        .opacity(verre ? 0.34 : 1)
                    dedans.fill(RadialGradient(
                        colors: [Color(white: 0.106), .clear],
                        center: UnitPoint(x: 0 + dx, y: 1 + dy),
                        startRadius: 0, endRadius: W * 0.77))
                        .opacity(verre ? 0.34 : 1)
                    // son liseré : même loi angulaire, mais il ne SATURE
                    // jamais — il reste du gris, plus clair en haut.
                    dedans.stroke(cardLisereDedans, lineWidth: 1.1)
                    // LA PLAQUE : sur le verre, sous l'encre.
                    dedans.fill(Color.black).opacity(0.93 * chambre)
                }
                .padding(e)

                contenu()
            }
        }
    }

}

// MARK: - Les deux liserés angulaires

/// Le liseré de la bezel. `AngularGradient` part de l'est et tourne dans
    /// le sens des aiguilles (y vers le bas) : 0,125 = coin bas-droit,
    /// 0,375 = bas-gauche, 0,625 = haut-gauche, 0,875 = haut-droit.
/// LE LISERÉ, ORIENTABLE. ⚠️ On ne fait PAS tourner la forme — on fait tourner
/// le DÉGRADÉ : les deux crêtes glissent le long d'un contour qui, lui, ne
/// bouge pas d'un pixel. Faire pivoter la card entière aurait déplacé son
/// encre ; c'est la lumière qui se promène, pas l'objet.
func cardLisereConique(_ a: Angle) -> AngularGradient {
    AngularGradient(stops: cardLisereStops, center: .center, angle: a)
}

let cardLisereStops: [Gradient.Stop] = [
    // Le balayage des deux crêtes est MESURÉ : 141° au coin d'or,
    // 118° au coin blanc — soit 0,39 et 0,33 de tour. Des épaules
    // franches, sinon la lumière bave sur tout le contour.
    .init(color: Color(white: 0.20), location: 0.000),
    .init(color: Color(white: 0.075), location: 0.125),   // MORT (bas-droit)
    .init(color: Color(white: 0.11), location: 0.255),
    .init(color: Color(white: 0.30), location: 0.335),
    .init(color: Color(white: 1.00), location: 0.366),    // BLANC (bas-gauche)
    .init(color: Color(white: 1.00), location: 0.386),
    .init(color: Color(white: 0.30), location: 0.412),
    .init(color: Color(white: 0.13), location: 0.470),
    .init(color: Color(white: 0.085), location: 0.625),   // MORT (haut-gauche)
    .init(color: Color(white: 0.13), location: 0.770),
    .init(color: CardTon.orChaud.opacity(0.60), location: 0.830),
    .init(color: CardTon.orVif, location: 0.862),         // OR (haut-droit)
    .init(color: Color(white: 1.00), location: 0.888),
    .init(color: CardTon.orChaud, location: 0.910),
    .init(color: Color(white: 0.19), location: 0.945),
    .init(color: Color(white: 0.20), location: 1.000),
]

let cardLisereConique = AngularGradient(stops: cardLisereStops,
                                        center: .center)

/// Le liseré du panneau : la même loi, sans jamais saturer.
let cardLisereDedans = AngularGradient(stops: [
    .init(color: Color(white: 0.17), location: 0.000),
    .init(color: Color(white: 0.075), location: 0.125),
    .init(color: Color(white: 0.24), location: 0.300),
    .init(color: Color(white: 0.40), location: 0.375),
    .init(color: Color(white: 0.26), location: 0.480),
    .init(color: Color(white: 0.115), location: 0.625),
    .init(color: Color(white: 0.30), location: 0.800),
    .init(color: Color(white: 0.36), location: 0.880),
    .init(color: Color(white: 0.17), location: 1.000),
], center: .center)


// MARK: - Le graphe à barres

/// Une journée du graphe : sa hauteur de rail et son nombre de segments.
struct CardJour: Identifiable {
    let lettre: String
    /// La hauteur du rail, en fraction de la hauteur de la card.
    let rail: Double
    let segments: Int
    var id: String { lettre + String(rail) }

    /// Les sept jours de la référence, mesurés (rails et segments).
    static let semaineRef: [CardJour] = [
        CardJour(lettre: "M", rail: 0.123, segments: 2),
        CardJour(lettre: "T", rail: 0.105, segments: 2),
        CardJour(lettre: "W", rail: 0.165, segments: 3),
        CardJour(lettre: "T", rail: 0.188, segments: 3),
        CardJour(lettre: "F", rail: 0.230, segments: 5),
        CardJour(lettre: "S", rail: 0.136, segments: 2),
        CardJour(lettre: "S", rail: 0.048, segments: 1),
    ]
}

/// UNE BARRE : un RAIL sombre rempli par le bas d'une pile de SEGMENTS
/// d'ambre. Chaque segment est une petite touche LAQUÉE — dégradé vertical
/// et arête claire en haut — et non un rectangle plat : c'est ce relief qui
/// fait la valeur de la pièce.
private struct CardBarre: View {
    var jour: CardJour
    var W: CGFloat
    var H: CGFloat
    /// 0 → 1, la pousse de la barre à l'arrivée.
    var p: Double

    /// Mesurés : barre 5,4 % de la largeur, segment 2,7 % de la hauteur,
    /// écart 0,16 %.
    private var larg: CGFloat { 0.054 * W }
    private var hSeg: CGFloat { 0.0272 * H }
    private var ecart: CGFloat { 0.0016 * H }

    var body: some View {
        let hRail = max(hSeg, CGFloat(jour.rail) * H * CGFloat(p))
        let n = Int((Double(jour.segments) * p).rounded(.down))
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: larg * 0.255, style: .continuous)
                .fill(LinearGradient(
                    colors: [CardTon.railHaut, CardTon.railBas],
                    startPoint: .top, endPoint: .bottom))
                .overlay(alignment: .top) {
                    // l'arête du haut : le rail est un OBJET, pas un trou
                    RoundedRectangle(cornerRadius: larg * 0.255,
                                     style: .continuous)
                        .strokeBorder(LinearGradient(
                            colors: [.white.opacity(0.26), .clear],
                            startPoint: .top, endPoint: .center),
                            lineWidth: 0.7)
                }
                .frame(width: larg, height: hRail)

            VStack(spacing: ecart) {
                ForEach(0..<max(0, n), id: \.self) { _ in
                    RoundedRectangle(cornerRadius: larg * 0.121,
                                     style: .continuous)
                        // ⚠️ Le dégradé d'un segment est HORIZONTAL, pas
                        // vertical : mesuré #EEA557 à gauche, #E29B58 au
                        // milieu, #FFC582 à droite — un cylindre éclairé
                        // par la droite, et non une touche laquée.
                        .fill(LinearGradient(
                            stops: [
                                .init(color: Color(red: 0.93, green: 0.65,
                                                   blue: 0.34), location: 0.00),
                                .init(color: Color(red: 0.89, green: 0.61,
                                                   blue: 0.35), location: 0.48),
                                .init(color: Color(red: 1.00, green: 0.77,
                                                   blue: 0.51), location: 1.00),
                            ],
                            startPoint: .leading, endPoint: .trailing))
                        .overlay(alignment: .top) {
                            Capsule().fill(Color.white.opacity(0.34))
                                .frame(height: 0.7)
                                .padding(.horizontal, larg * 0.16)
                                .padding(.top, 0.7)
                        }
                        .frame(width: larg, height: hSeg)
                }
            }
        }
        .frame(width: larg, alignment: .bottom)
    }
}

// MARK: - Le bouton haltère

/// Le glyphe : une barre centrale, deux disques épais au contact, deux
/// disques fins à l'extérieur — de chaque côté. Ses proportions font tout.
struct HaltereGlyphe: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        func bloc(_ cx: Double, _ dw: Double, _ dh: Double) {
            let bw = dw * w, bh = dh * h
            p.addRoundedRect(in: CGRect(x: r.minX + cx * w - bw / 2,
                                        y: r.midY - bh / 2,
                                        width: bw, height: bh),
                             cornerSize: CGSize(width: bw * 0.30,
                                                height: bw * 0.30))
        }
        bloc(0.50, 0.34, 0.115)   // la barre
        bloc(0.305, 0.105, 0.70)  // disque épais gauche
        bloc(0.695, 0.105, 0.70)  // disque épais droit
        bloc(0.155, 0.090, 0.44)  // disque fin gauche
        bloc(0.845, 0.090, 0.44)  // disque fin droit
        return p
    }
}

private struct CardBoutonHaltere: View {
    var W: CGFloat
    var H: CGFloat

    var body: some View {
        let d = 0.183 * H
        ZStack {
            Circle().fill(Color.white.opacity(0.042))
            Circle().strokeBorder(Color.white.opacity(0.135), lineWidth: 0.9)
            HaltereGlyphe()
                .fill(LinearGradient(
                    colors: [CardTon.orChaud, CardTon.ambre],
                    startPoint: .top, endPoint: .bottom))
                .frame(width: d * 0.64, height: d * 0.50)
        }
        .frame(width: d, height: d)
    }
}

// MARK: - Le geste des cards (les trois grammaires)

/// CE QUE LE DOIGT A LE DROIT DE FAIRE sur une card, selon l'endroit où
/// elle vit. ⚠️ UN SEUL `DragGesture(minimumDistance: 0)` porte tout — un
/// `onLongPressGesture`, même à 0,01 s, VOLE le tap qui le suit (loi payée
/// trois fois : l'iPod, le galet du menu, et ici même).
enum CardMode {
    /// Le banc : tap = chambre (elle reste), appui tenu = aperçu refermé
    /// au relâchement. La grammaire d'origine, intacte.
    case libre
    /// LA HOME : tap = chambre ; **0,50 s immobile = le mode édition**.
    /// L'aperçu d'appui tenu meurt ici (sa fenêtre 0,28 → 0,50 s est trop
    /// courte pour exister) — il renaît dans la vitrine, où le long press
    /// n'a plus d'emploi. Arbitrage A du plan édition-widgets.
    case home(onEdition: () -> Void)
    /// LA VITRINE : tap = confirmer ; appui 0,18 s = l'aperçu de la
    /// chambre (ouvert tant que le doigt est posé). Le retard des 0,18 s
    /// n'est pas un style : sans lui, chaque départ de swipe ferait
    /// clignoter la chambre du widget central.
    case vitrine(onTap: () -> Void)
    /// LE MODE ÉDITION : la card ne répond plus au doigt — seule sa
    /// pastille parle. (Comme le springboard : une app qui frétille ne se
    /// lance pas.)
    case inerte
}

/// Le geste partagé des quatre cards. Les états du toucher vivent ICI (et
/// pas dans chaque card) pour que la grammaire soit une seule fois vraie.
/// La CHAMBRE, elle, reste l'état de la card : le modificateur ne fait que
/// la piloter à travers un binding.
struct CardTouche: ViewModifier {
    var mode: CardMode
    @Binding var chambre: Double
    @Binding var doigt: CGPoint?

    @State private var presseAt: Date?
    @State private var etaitOuverte = false
    @State private var aBouge = false
    /// Invalide les rendez-vous (`asyncAfter`) d'une presse déjà finie.
    @State private var jeton = 0
    /// Le long press a tiré : le relâchement n'a plus rien à dire.
    @State private var editionTiree = false

    /// 0,50 s — l'arbitrage F du plan (0,4-0,5 s chez Apple ; la tolérance
    /// de mouvement est de 10 pt, au-delà c'est un drag, pas un appui).
    private static let seuilEdition = 0.50
    private static let seuilApercu = 0.18

    @ViewBuilder
    func body(content: Content) -> some View {
        if case .inerte = mode {
            content
        } else {
            content.gesture(geste)
        }
    }

    private var geste: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                doigt = v.location
                if presseAt != nil {
                    // Le doigt a fui : plus un appui. (10 pt, la tolérance
                    // du long press d'Apple.)
                    if max(abs(v.translation.width),
                           abs(v.translation.height)) > 10 {
                        aBouge = true
                    }
                    return
                }
                presseAt = Date()
                etaitOuverte = chambre > 0.5
                aBouge = false
                editionTiree = false
                jeton += 1
                let mien = jeton
                switch mode {
                case .libre:
                    guard !etaitOuverte else { return }
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    ouvrir()
                case .home(let onEdition):
                    if !etaitOuverte {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        ouvrir()
                    }
                    // LE RENDEZ-VOUS DE L'ÉDITION. Un `DragGesture` ne
                    // rappelle pas un doigt immobile : le seuil se tient à
                    // l'horloge, et le jeton le tue si la presse finit avant.
                    DispatchQueue.main.asyncAfter(
                        deadline: .now() + Self.seuilEdition) {
                        guard jeton == mien, presseAt != nil, !aBouge
                        else { return }
                        editionTiree = true
                        // La chambre se range : l'édition est un mode de la
                        // PAGE, pas un état de la card.
                        withAnimation(.timingCurve(0.30, 0, 0.40, 1,
                                                   duration: 0.30)) {
                            chambre = 0
                        }
                        onEdition()
                    }
                case .vitrine:
                    DispatchQueue.main.asyncAfter(
                        deadline: .now() + Self.seuilApercu) {
                        guard jeton == mien, presseAt != nil, !aBouge
                        else { return }
                        ouvrir()
                    }
                case .inerte:
                    break
                }
            }
            .onEnded { _ in
                let court = Date()
                    .timeIntervalSince(presseAt ?? Date()) < 0.28
                let bouge = aBouge
                let edition = editionTiree
                presseAt = nil
                jeton += 1
                withAnimation(.easeOut(duration: 0.28)) { doigt = nil }
                switch mode {
                case .libre:
                    guard etaitOuverte || !court else { return }
                    fermer()
                case .home:
                    // L'édition a pris la main : le relâchement se tait.
                    guard !edition else { return }
                    guard etaitOuverte || !court else { return }
                    fermer()
                case .vitrine(let onTap):
                    // La chambre de la vitrine ne survit JAMAIS au doigt :
                    // c'est un aperçu, pas un état.
                    if chambre > 0.01 { fermer() }
                    if court, !bouge { onTap() }
                case .inerte:
                    break
                }
            }
    }

    private func ouvrir() {
        withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.52)) {
            chambre = 1
        }
    }

    private func fermer() {
        // RIEN dans la main au relâchement : le silence à la fin se sent
        // plus cher qu'un second clac.
        withAnimation(.timingCurve(0.30, 0, 0.40, 1, duration: 0.34)) {
            chambre = 0
        }
    }
}

// MARK: - LA CARD DU VOLUME

struct CardVolume: View {
    @Environment(\.harmonieInter) private var interUnifie
    var valeur: String = "8.4"
    var unite: String = "kg"
    var legende: String = "Weekly volume"
    var jours: [CardJour] = CardJour.semaineRef
    var gain: String = "+12%"
    var gainLegende: String = "vs last week"
    var moyenneLegende: String = "avg per session"
    var moyenne: String = "1.2 kg"
    /// 0 → 1 : l'arrivée (les barres poussent, l'encre se pose).
    var p: Double = 1
    var lisere: Bool = true
    var verre: Bool = false
    /// LES QUATRE DERNIÈRES SEMAINES, normalisées — l'intérieur de la chambre.
    /// La plus récente en dernier, et c'est elle qui brille.
    var semaines: [[Double]] = [
        [0.32, 0.20, 0.44, 0.28, 0.52, 0.16, 0.10],
        [0.40, 0.34, 0.30, 0.56, 0.44, 0.22, 0.14],
        [0.28, 0.46, 0.52, 0.38, 0.62, 0.30, 0.18],
        [0.44, 0.36, 0.58, 0.50, 0.78, 0.34, 0.12],
    ]
    var totalMois: String = "31.6"
    var record: String = "8.4"
    /// L'inclinaison du mode édition (degrés) — transmise au liseré, qui
    /// contre-tourne.
    var penche: Double = 0
    /// La grammaire du doigt (banc / home / vitrine / inerte).
    var interaction: CardMode = .libre

    /// `-chambre` fige la chambre OUVERTE : le simulateur ne sait pas
    /// tenir un doigt, et une chambre ne se juge qu'ouverte.
    @State private var chambre: Double =
        CommandLine.arguments.contains("-chambre") ? 1 : 0
    @State private var doigt: CGPoint?

    var body: some View {
        CardCorps(lisere: lisere, verre: verre, chambre: chambre,
                  doigt: doigt, penche: penche) {
            Chambre(p: chambre) { c in
                ZStack {
                    surface
                        .opacity(1 - 0.93 * ChambreTemps.recul(c))
                        .blur(radius: 2.2 * ChambreTemps.recul(c))
                        .scaleEffect(1 - 0.05 * ChambreTemps.recul(c))
                    quatreSemaines(ChambreTemps.fond(c))
                }
            }
        }
        // ⚠️ Un `Rectangle`, et c'est la CORRECTION : l'ancien rayon 26 était
        // codé en dur (juste à 170 pt, faux partout ailleurs — au banc 330 le
        // rayon réel fait 50). Les cards sont posées à 14 pt l'une de
        // l'autre : les coins d'une prise rectangulaire ne peuvent voler le
        // doigt à personne.
        .contentShape(Rectangle())
        .modifier(CardTouche(mode: interaction,
                             chambre: $chambre, doigt: $doigt))
    }

    /// L'INTÉRIEUR — QUATRE SEMAINES, QUATRE BARRES, DEUX CHIFFRES.
    ///
    /// ⚠️ Les quatre COURBES sont mortes, et le verdict était juste : à 170 pt,
    /// quatre polylignes grises superposées sur du noir sont illisibles par
    /// CONSTRUCTION — ce n'était pas un réglage de gris. Une barre par semaine
    /// se lit d'un coup d'œil, et c'est **la même matière que la surface** :
    /// les sept barres du jour se rassemblent en une seule.
    ///
    /// Et les deux chiffres du pied sont ceux qu'on a RETIRÉS du dessus : on ne
    /// les a pas supprimés, on les a rangés à l'étage où ils ont de la place.
    @ViewBuilder
    private func quatreSemaines(_ f: Double) -> some View {
        if f > 0.001 {
            GeometryReader { g in
                let W = g.size.width, H = g.size.height
                let totaux = semaines.map { $0.reduce(0, +) }
                let hautMax = max(totaux.max() ?? 1, 0.001)
                let sol = 0.720 * H
                let pas = 0.150 * W
                let x0 = 0.500 * W - 1.5 * pas

                // LE SOL : un seul filet, celui sur lequel les barres posent.
                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 0.640 * W, height: 0.5)
                    .position(x: 0.500 * W, y: sol)
                    .opacity(f)

                ForEach(0..<totaux.count, id: \.self) { k in
                    let rang = totaux.count - 1 - k
                    let retard = Double(rang) * 0.12
                    let a = min(max((f - retard)
                                    / max(1 - retard, 0.001), 0), 1)
                    let h = 0.300 * H * CGFloat(totaux[k] / hautMax)
                    Capsule()
                        .fill(rang == 0
                              ? CardTon.ambreVif
                              : Color(white: 0.42 - 0.06 * Double(rang)))
                        .frame(width: 0.095 * W, height: max(h * CGFloat(a), 1))
                        .position(x: x0 + CGFloat(k) * pas,
                                  y: sol - h * CGFloat(a) / 2)
                        .shadow(color: rang == 0
                                ? CardTon.ambreVif.opacity(0.45 * a) : .clear,
                                radius: 0.030 * W)
                }

                Text("this week")
                    .font(.system(size: 0.0327 * H, weight: .regular))
                    .foregroundStyle(CardTon.ambreVif.opacity(0.85))
                    .opacity(f)
                    .position(x: x0 + 3 * pas, y: sol + 0.055 * H)

                // LE GROS CHIFFRE ET SON TITRE.
                HStack(alignment: .lastTextBaseline, spacing: 0.012 * W) {
                    Text(totalMois)
                        .font(interUnifie
                              ? .inter(0.1750 * H, .semibold)
                              : .system(size: 0.1750 * H, weight: .regular))
                        .foregroundStyle(LinearGradient(
                            colors: [Color(white: 1.00), Color(white: 0.863)],
                            startPoint: .top, endPoint: .bottom))
                    Text("kg")
                        .font(.system(size: 0.0700 * H, weight: .regular))
                        .foregroundStyle(CardTon.encreDouce)
                }
                .modifier(AncrageGauche(x: 0.129 * W, y: 0.0694 * H))
                Text("This month")
                    .font(.system(size: 0.0500 * H, weight: .regular))
                    .tracking(0.0500 * H * 0.030)
                    .foregroundStyle(CardTon.encreDouce)
                    .modifier(AncrageGauche(x: 0.129 * W, y: 0.277 * H))

                // LE PIED : les deux chiffres retirés de la surface.
                Text(record)
                    .font(.system(size: 0.0606 * H, weight: .regular))
                    .foregroundStyle(CardTon.encre)
                    .position(x: 0.290 * W, y: 0.858 * H)
                Text("best week")
                    .font(.system(size: 0.0350 * H, weight: .regular))
                    .foregroundStyle(CardTon.encreSourde)
                    .position(x: 0.290 * W, y: 0.912 * H)
                Text(moyenne)
                    .font(.system(size: 0.0606 * H, weight: .regular))
                    .foregroundStyle(CardTon.encre)
                    .position(x: 0.700 * W, y: 0.858 * H)
                Text("avg / session")
                    .font(.system(size: 0.0350 * H, weight: .regular))
                    .foregroundStyle(CardTon.encreSourde)
                    .position(x: 0.700 * W, y: 0.912 * H)
            }
            .opacity(f)
        }
    }

    private var surface: some View {
            GeometryReader { g in
                let W = g.size.width, H = g.size.height
                let marge = 0.129 * W

                // ── L'EN-TÊTE. Hauteur de capitale mesurée : 13,54 % de H
                // pour le gros chiffre, 4,08 % pour la légende ; une
                // capitale d'Inter vaut 0,715 de son corps.
                HStack(alignment: .lastTextBaseline, spacing: 0.012 * W) {
                    Text(valeur)
                        .font(interUnifie
                              ? .inter(0.1750 * H, .semibold)
                              : .system(size: 0.1750 * H,
                                        weight: .regular))
                        // pas un blanc plat : un dégradé métallique vertical
                        // (#FFFFFF au sommet, #DCDCDC à la base — mesuré)
                        .foregroundStyle(LinearGradient(
                            colors: [Color(white: 1.00), Color(white: 0.863)],
                            startPoint: .top, endPoint: .bottom))
                    Text(unite)
                        .font(.system(size: 0.0700 * H, weight: .regular))
                        .foregroundStyle(CardTon.encreDouce)
                }
                .modifier(AncrageGauche(x: marge, y: 0.0694 * H))

                Text(legende)
                    // 0,0430 × 170 = 7,31 pt : juste sur la référence, illisible
                    // en vrai sous un chiffre de 29,75. Porté à 0,0500 —
                    // le rapport légende/chiffre passe de 0,246 à 0,286,
                    // ce qui reste une légende.
                    .font(.system(size: 0.0500 * H, weight: .regular))
                    .tracking(0.0500 * H * 0.030)
                    .foregroundStyle(CardTon.encreDouce)
                    .modifier(AncrageGauche(x: marge, y: 0.277 * H))

                // ── LE GRAPHE. Base des rails à 63,5 % — et pas 69,2 : ce
                // que je prenais pour le pied des barres était la LETTRE du
                // jour, qui vit dessous.
                ForEach(Array(jours.enumerated()), id: \.offset) { i, j in
                    let cx = (0.156 + 0.1115 * Double(i)) * W
                    CardBarre(jour: j, W: W, H: H, p: p)
                        .position(x: cx,
                                  y: 0.635 * H - CGFloat(j.rail) * H * p / 2)
                    Text(j.lettre)
                        .font(.system(size: 0.0327 * H, weight: .regular))
                        .foregroundStyle(CardTon.encreJour)
                        .position(x: cx, y: 0.6857 * H)
                }

                // ── LE FILET : de 12,4 % à 86,9 %, à 75,3 % de hauteur.
                Rectangle()
                    .fill(Color.white.opacity(0.090))
                    .frame(width: 0.7196 * W, height: 0.0033 * W)
                    .position(x: 0.4964 * W, y: 0.7567 * H)

                // ── LE PIED : DEUX COLONNES CENTRÉES (et non alignées à
                // gauche — mesuré : centres à 27 % et 70 % de la largeur).
                // Seul au pied, il se CENTRE : une colonne restée à 27 %
                // laisserait un vide à droite qui se lirait comme un oubli.
                Text(gain)
                    .font(.system(size: 0.0606 * H, weight: .regular))
                    .foregroundStyle(CardTon.ambreVif)
                    .position(x: 0.500 * W, y: 0.808 * H)
                Text(gainLegende)
                    .font(.system(size: 0.0350 * H, weight: .regular))
                    .foregroundStyle(CardTon.encreSourde)
                    .position(x: 0.500 * W, y: 0.861 * H)

                // ⚠️ LA DEUXIÈME COLONNE EST MORTE (« 1,2 kg / avg per
                // session »), et son filet séparateur avec elle. Deux
                // chiffres au pied d'une card de 170 pt, c'est un tableau de
                // bord : on lit le premier, on subit le second. Il ne reste
                // que le gain — la seule ligne qui dise quelque chose.
                // L'HALTÈRE aussi : un pictogramme dans un rond, c'est un
                // bouton qui ne fait rien.
            }
    }
}

// MARK: - LA CARD DES SÉANCES

struct CardSeances: View {
    @Environment(\.harmonieInter) private var interUnifie
    var faites: Int = 4
    var prevues: Int = 5
    var legende: String = "Sessions this week"
    var jours: [String] = ["M", "T", "W", "T", "F", "S", "S"]
    var pied: String = "1 session left to hit your goal"
    var p: Double = 1
    var lisere: Bool = true
    var verre: Bool = false
    /// LES JOURS DU MOIS DÉJÀ FAITS — l'intérieur de la chambre. Le câblage
    /// aux vraies séances vient au jalon du flow ; ici, une trame plausible.
    var moisFaits: Set<Int> = [2, 3, 5, 8, 9, 12, 14, 15, 18, 19, 20, 21]
    var moisJours: Int = 31
    var penche: Double = 0
    var interaction: CardMode = .libre

    /// `-chambre` fige la chambre OUVERTE : le simulateur ne sait pas
    /// tenir un doigt, et une chambre ne se juge qu'ouverte.
    @State private var chambre: Double =
        CommandLine.arguments.contains("-chambre") ? 1 : 0
    @State private var doigt: CGPoint?

    var body: some View {
        CardCorps(lisere: lisere, verre: verre, chambre: chambre,
                  doigt: doigt, penche: penche) {
            Chambre(p: chambre) { c in
                ZStack {
                    surface
                        .opacity(1 - 0.93 * ChambreTemps.recul(c))
                        .blur(radius: 2.2 * ChambreTemps.recul(c))
                        .scaleEffect(1 - 0.05 * ChambreTemps.recul(c))
                    mois(ChambreTemps.fond(c))
                }
            }
        }
        // ⚠️ Un `Rectangle` — voir CardVolume : l'ancien rayon 26 en dur
        // mentait à toute autre taille que 170.
        .contentShape(Rectangle())
        // ⚠️ UN SEUL GESTE : un `onLongPressGesture` volerait le tap.
        .modifier(CardTouche(mode: interaction,
                             chambre: $chambre, doigt: $doigt))
    }

    /// L'INTÉRIEUR — LE MOIS. Les sept pastilles de la semaine s'écartent en
    /// une grille de trente et un points : une seule matière, deux échelles.
    /// Ils arrivent en CASCADE, dans l'ordre de lecture — une grille qui
    /// apparaît d'un bloc est une image, pas une révélation.
    @ViewBuilder
    private func mois(_ f: Double) -> some View {
        if f > 0.001 {
            GeometryReader { g in
                let W = g.size.width, H = g.size.height
                let pas = 0.101 * W
                let x0 = 0.500 * W - 3 * pas
                // LES LETTRES DES JOURS — sans elles, trente et un points ne
                // sont qu'une trame : c'est la colonne qui leur donne un sens.
                // Même corps que les lettres de la card voisine (0,0327 × H),
                // sinon les deux intérieurs ne se lisent pas pareil.
                ForEach(0..<7, id: \.self) { c in
                    Text(jours[c])
                        .font(.system(size: 0.0327 * H, weight: .regular))
                        .foregroundStyle(CardTon.encreJour)
                        .opacity(f)
                        .position(x: x0 + CGFloat(c) * pas, y: 0.262 * H)
                }
                // ⚠️ L'HORLOGE DORT quand la chambre est fermée : hors
                // ouverture, ce scintillement ne coûte pas une image.
                TimelineView(.animation(minimumInterval: 1.0 / 24,
                                        paused: f < 0.02)) { tl in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    // ⚠️ LE CADRE EST FORCÉ. Une `TimelineView` se dimensionne
                    // sur SON contenu : les `.position()` visaient le cadre de
                    // la TimelineView et non celui de la card, et la grille
                    // partait en DIAGONALE (chaque point se posait dans un
                    // cadre plus grand que le précédent). C'est la cousine du
                    // piège de la couche sans taille intrinsèque.
                    ZStack {
                        ForEach(0..<moisJours, id: \.self) { j in
                            point(j, t: t, f: f, W: W, H: H,
                                  pas: pas, x0: x0)
                        }
                    }
                    .frame(width: W, height: H)
                }
                // Aligné comme la légende de la card voisine — un titre
                // centré ici tombait pile sur le « 4 » de la surface qui
                // transparaît encore.
                Text("This month")
                    .font(.system(size: 0.0500 * H, weight: .regular))
                    .tracking(0.0500 * H * 0.030)
                    .foregroundStyle(CardTon.encreDouce)
                    .opacity(f)
                    .modifier(AncrageGauche(x: 0.129 * W, y: 0.120 * H))
            }
        }
    }

    /// UN POINT DU MOIS. Les faits SCINTILLENT en blanc néon par-dessus leur
    /// ambre — un cœur blanc qui monte et redescend, et son halo court.
    ///
    /// ⚠️ Chaque point a sa PROPRE période, et elles sont volontairement
    /// incommensurables (2,3 s + une fraction tirée de son rang) : des
    /// périodes voisines finissent par battre ENSEMBLE, et une grille qui
    /// pulse d'un bloc n'est plus un scintillement, c'est un clignotant.
    @ViewBuilder
    private func point(_ j: Int, t: Double, f: Double,
                       W: CGFloat, H: CGFloat,
                       pas: CGFloat, x0: CGFloat) -> some View {
        let fait = moisFaits.contains(j + 1)
        let retard = Double(j) * 0.011
        let a = min(max((f - retard) / max(1 - retard, 0.001), 0), 1)
        let per = 2.3 + 1.7 * (Double((j &* 37) % 100) / 100)
        let br = 0.5 + 0.5 * sin(t * 2 * .pi / per + Double(j) * 1.618)
        let sc = fait ? br * br : 0
        ZStack {
            Circle()
                .fill(fait ? CardTon.ambreVif : Color(white: 0.26))
            if fait {
                Circle()
                    .fill(Color.white)
                    .opacity(0.10 + 0.62 * sc)
                    .blur(radius: 0.3)
            }
        }
        .frame(width: 0.050 * W, height: 0.050 * W)
        .shadow(color: .white.opacity(0.55 * sc), radius: 0.055 * W)
        .opacity(a * (fait ? 1 : 0.6))
        .scaleEffect((0.35 + 0.65 * a) * (1 + 0.10 * sc))
        .position(x: x0 + CGFloat(j % 7) * pas,
                  y: 0.345 * H + CGFloat(j / 7) * pas)
    }

    private var surface: some View {
            GeometryReader { g in
                let W = g.size.width, H = g.size.height
                let marge = 0.129 * W

                // Le « 4 / 5 » s'aligne sur le « 8.4 » de la card voisine —
                // même gouttière, même ligne d'œil — et il est POSÉ
                // AU-DESSUS de sa légende : il la recouvrait.
                HStack(alignment: .lastTextBaseline, spacing: 0.024 * W) {
                    Text("\(faites)")
                        .font(interUnifie
                              ? .inter(0.1750 * H, .semibold)
                              : .system(size: 0.1750 * H,
                                        weight: .regular))
                        .foregroundStyle(LinearGradient(
                            colors: [Color(white: 1.00), Color(white: 0.788)],
                            startPoint: .top, endPoint: .bottom))
                    Text("/ \(prevues)")
                        .font(.system(size: 0.0817 * H, weight: .regular))
                        .foregroundStyle(CardTon.encreDouce)
                }
                .modifier(AncrageGauche(x: marge, y: 0.0694 * H))

                Text(legende)
                    // 0,0430 × 170 = 7,31 pt : juste sur la référence, illisible
                    // en vrai sous un chiffre de 29,75. Porté à 0,0500 —
                    // le rapport légende/chiffre passe de 0,246 à 0,286,
                    // ce qui reste une légende.
                    .font(.system(size: 0.0500 * H, weight: .regular))
                    .tracking(0.0500 * H * 0.030)
                    .foregroundStyle(CardTon.encreDouce)
                    .modifier(AncrageGauche(x: marge, y: 0.277 * H))

                // Les sept pastilles
                ForEach(0..<jours.count, id: \.self) { i in
                    let on = Double(i) < Double(faites) * p
                    Circle()
                        .fill(on
                              ? LinearGradient(colors: [CardTon.ambreVif,
                                                        CardTon.ambre],
                                               startPoint: .top,
                                               endPoint: .bottom)
                              : LinearGradient(colors: [Color(white: 0.20),
                                                        Color(white: 0.135)],
                                               startPoint: .top,
                                               endPoint: .bottom))
                        .frame(width: 0.052 * W, height: 0.052 * W)
                        .shadow(color: on ? CardTon.ambre.opacity(0.55)
                                          : .clear,
                                radius: 0.030 * W)
                        .position(x: (0.156 + 0.1115 * Double(i)) * W,
                                  y: 0.578 * H)
                    Text(jours[i])
                        .font(.system(size: 0.046 * H, weight: .medium))
                        .foregroundStyle(CardTon.encreJour)
                        .position(x: (0.156 + 0.1115 * Double(i)) * W,
                                  y: 0.680 * H)
                }

                Rectangle()
                    .fill(LinearGradient(
                        colors: [.clear, CardTon.filet, CardTon.filet, .clear],
                        startPoint: .leading, endPoint: .trailing))
                    .frame(width: W - marge * 2, height: 0.8)
                    .position(x: W / 2, y: 0.756 * H)

                HStack(spacing: 0.038 * W) {
                    ZStack {
                        Circle().strokeBorder(CardTon.ambreVif, lineWidth: 1.2)
                        Circle().fill(CardTon.ambreVif)
                            .frame(width: 0.016 * W, height: 0.016 * W)
                    }
                    .frame(width: 0.058 * W, height: 0.058 * W)
                    Text(pied)
                        .font(.system(size: 0.0500 * H, weight: .regular))
                        .foregroundStyle(CardTon.encreDouce)
                }
                .modifier(AncrageGauche(x: marge, y: 0.787 * H))
            }
    }
}

// MARK: - LA CARD HIIT PEAK (widget 03)

/// LE MEILLEUR SEGMENT HAUTE INTENSITÉ DE LA SEMAINE — surtout pas un
/// graphe cardio. **La ligne de vitesse** : une ligne de minuscules
/// segments PEINTS (la loi des 9 pt interdit les micro-verres, et N verres
/// = N passes) dont la meilleure portion devient plus dense et plus
/// lumineuse. La rampe de chaleur s'écrit EN CANAUX (on allume le vert puis
/// le bleu quand la chaleur monte) — jamais un `mix` entre deux teintes, le
/// chemin droit passe par le brun. Et le rail froid ne se MÉLANGE jamais à
/// l'ambre : un segment est froid OU chaud, c'est la hauteur qui fait la
/// continuité.
struct CardHiitPeak: View {
    @Environment(\.harmonieInter) private var interUnifie
    var vitesse: String = "17.0"
    var unite: String = "km/h"
    var legende: String = "Top interval this week"
    var repetitions: String = "4 × 40 s"
    var repsLegende: String = "best segment"
    /// La position du pic le long de la ligne (0 → 1) et sa largeur.
    var pic: Double = 0.62
    var picLargeur: Double = 0.26
    var chambreLigne: String = "17.0 km/h · 40 s · ×4"
    var chambreSous: String = "this week's peak"
    var p: Double = 1
    var lisere: Bool = true
    var verre: Bool = false
    var penche: Double = 0
    var interaction: CardMode = .libre

    @State private var chambre: Double =
        CommandLine.arguments.contains("-chambre") ? 1 : 0
    @State private var doigt: CGPoint?

    var body: some View {
        CardCorps(lisere: lisere, verre: verre, chambre: chambre,
                  doigt: doigt, penche: penche) {
            Chambre(p: chambre) { c in
                ZStack {
                    surface
                        .opacity(1 - 0.93 * ChambreTemps.recul(c))
                        .blur(radius: 2.2 * ChambreTemps.recul(c))
                        .scaleEffect(1 - 0.05 * ChambreTemps.recul(c))
                    interieur(ChambreTemps.fond(c))
                }
            }
        }
        .contentShape(Rectangle())
        .modifier(CardTouche(mode: interaction,
                             chambre: $chambre, doigt: $doigt))
    }

    /// L'aperçu de la chambre : la ligne du pic, en toutes lettres.
    @ViewBuilder
    private func interieur(_ f: Double) -> some View {
        if f > 0.001 {
            GeometryReader { g in
                let W = g.size.width, H = g.size.height
                Text(chambreLigne)
                    .font(.system(size: 0.0560 * H, weight: .regular))
                    .foregroundStyle(LinearGradient(
                        colors: [Color(white: 1.00), Color(white: 0.863)],
                        startPoint: .top, endPoint: .bottom))
                    .position(x: 0.500 * W, y: 0.470 * H)
                Text(chambreSous)
                    .font(.system(size: 0.0350 * H, weight: .regular))
                    .foregroundStyle(CardTon.encreSourde)
                    .position(x: 0.500 * W, y: 0.560 * H)
            }
            .opacity(f)
        }
    }

    private var surface: some View {
        GeometryReader { g in
            let W = g.size.width, H = g.size.height
            let marge = 0.129 * W

            HStack(alignment: .lastTextBaseline, spacing: 0.012 * W) {
                Text(vitesse)
                    .font(interUnifie
                          ? .inter(0.1750 * H, .semibold)
                          : .system(size: 0.1750 * H, weight: .regular))
                    .foregroundStyle(LinearGradient(
                        colors: [Color(white: 1.00), Color(white: 0.863)],
                        startPoint: .top, endPoint: .bottom))
                Text(unite)
                    .font(.system(size: 0.0700 * H, weight: .regular))
                    .foregroundStyle(CardTon.encreDouce)
            }
            .modifier(AncrageGauche(x: marge, y: 0.0694 * H))

            Text(legende)
                .font(.system(size: 0.0500 * H, weight: .regular))
                .tracking(0.0500 * H * 0.030)
                .foregroundStyle(CardTon.encreDouce)
                .modifier(AncrageGauche(x: marge, y: 0.277 * H))

            // ── LA LIGNE DE VITESSE. 25 segments, la même famille laquée
            // que `CardBarre`, couchée. Le pic est une ENVELOPPE continue
            // (hauteur) et un matériau discret (froid OU chaud) : la
            // continuité vient de la géométrie, jamais d'un mélange gris →
            // ambre qui fabriquerait du brun.
            let n = 25
            let y = 0.575 * H
            ForEach(0..<n, id: \.self) { i in
                let u = Double(i) / Double(n - 1)
                let ecart = (u - pic) / (picLargeur * 0.55)
                let e = exp(-ecart * ecart)
                let chaud = e > 0.12
                let t = chaud ? (e - 0.12) / 0.88 : 0
                let a = min(max((p - 0.4 * u) / 0.6, 0), 1)
                let h = H * (0.026 + 0.062 * e) * a
                Capsule()
                    .fill(chaud
                          ? Color(red: 1.00,
                                  green: 0.62 + 0.37 * t,
                                  blue: 0.28 + 0.68 * t * t)
                          : Color(white: 0.26))
                    .frame(width: 0.0135 * W, height: max(h, 1))
                    .shadow(color: chaud
                            ? Color(red: 1.00, green: 0.80, blue: 0.50)
                                .opacity(0.55 * e * a)
                            : .clear,
                            radius: 0.020 * W)
                    .position(x: (0.129 + 0.742 * u) * W, y: y)
                    .opacity(Double(a) * (chaud ? 1 : 0.85))
            }

            // ── LE PIED — la colonne centrée des cards voisines.
            Text(repetitions)
                .font(.system(size: 0.0606 * H, weight: .regular))
                .foregroundStyle(CardTon.encre)
                .position(x: 0.500 * W, y: 0.808 * H)
            Text(repsLegende)
                .font(.system(size: 0.0350 * H, weight: .regular))
                .foregroundStyle(CardTon.encreSourde)
                .position(x: 0.500 * W, y: 0.861 * H)
        }
    }
}

// MARK: - LA CARD PEAK EFFORT (widget 04)

/// LE MOMENT LE PLUS FORT DE LA SEMAINE, tous types confondus — un
/// highlight sportif, pas un score. Une seule forme liquide noire au
/// centre, discrète, qui attrape un REFLET quand un nouveau peak est
/// détecté (le liseré par événements, la loi du médaillon à flamme). Mais
/// l'encre garde les données : à côté de deux cards denses, un widget
/// presque vide se lirait comme un bug.
struct CardPeakEffort: View {
    @Environment(\.harmonieInter) private var interUnifie
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var titre: String = "Hip Thrust"
    var valeur: String = "+10 kg"
    var contexte: String = "This week's highlight"
    var chambreHaut: String = "60 kg × 8"
    var chambreBas: String = "previous best · 55 kg"
    /// Un nouveau peak vient d'être détecté : la forme attrape le reflet.
    var nouveau: Bool = true
    var p: Double = 1
    var lisere: Bool = true
    var verre: Bool = false
    var penche: Double = 0
    var interaction: CardMode = .libre

    @State private var chambre: Double =
        CommandLine.arguments.contains("-chambre") ? 1 : 0
    @State private var doigt: CGPoint?

    var body: some View {
        CardCorps(lisere: lisere, verre: verre, chambre: chambre,
                  doigt: doigt, penche: penche) {
            Chambre(p: chambre) { c in
                ZStack {
                    surface
                        .opacity(1 - 0.93 * ChambreTemps.recul(c))
                        .blur(radius: 2.2 * ChambreTemps.recul(c))
                        .scaleEffect(1 - 0.05 * ChambreTemps.recul(c))
                    interieur(ChambreTemps.fond(c))
                }
            }
        }
        .contentShape(Rectangle())
        .modifier(CardTouche(mode: interaction,
                             chambre: $chambre, doigt: $doigt))
    }

    @ViewBuilder
    private func interieur(_ f: Double) -> some View {
        if f > 0.001 {
            GeometryReader { g in
                let W = g.size.width, H = g.size.height
                Text(chambreHaut)
                    .font(.system(size: 0.0700 * H, weight: .regular))
                    .foregroundStyle(LinearGradient(
                        colors: [Color(white: 1.00), Color(white: 0.863)],
                        startPoint: .top, endPoint: .bottom))
                    .position(x: 0.500 * W, y: 0.455 * H)
                Text(chambreBas)
                    .font(.system(size: 0.0350 * H, weight: .regular))
                    .foregroundStyle(CardTon.encreSourde)
                    .position(x: 0.500 * W, y: 0.555 * H)
            }
            .opacity(f)
        }
    }

    private var surface: some View {
        GeometryReader { g in
            let W = g.size.width, H = g.size.height
            let marge = 0.129 * W

            // Le sur-titre : PEAK, tracké large — c'est lui le glyphe.
            Text("PEAK")
                .font(.system(size: 0.0560 * H, weight: .regular))
                .tracking(0.0560 * H * 0.16)
                .foregroundStyle(CardTon.encreDouce)
                .modifier(AncrageGauche(x: marge, y: 0.0770 * H))

            // ── LA FORME LIQUIDE NOIRE, et son reflet-événement.
            forme(W: W, H: H)
                .opacity(min(max((p - 0.2) / 0.6, 0), 1))

            // ── L'ENCRE, au-dessus de la forme.
            Text(titre)
                .font(.system(size: 0.0606 * H, weight: .regular))
                .foregroundStyle(CardTon.encreDouce)
                .position(x: 0.500 * W, y: 0.410 * H)
                .opacity(min(max((p - 0.3) / 0.5, 0), 1))
            Text(valeur)
                .font(interUnifie
                      ? .inter(0.1500 * H, .semibold)
                      : .system(size: 0.1500 * H, weight: .regular))
                .foregroundStyle(LinearGradient(
                    colors: [Color(white: 1.00), Color(white: 0.863)],
                    startPoint: .top, endPoint: .bottom))
                .position(x: 0.500 * W, y: 0.560 * H)
                .opacity(min(max((p - 0.4) / 0.5, 0), 1))

            Text(contexte)
                .font(.system(size: 0.0350 * H, weight: .regular))
                .foregroundStyle(CardTon.encreSourde)
                .position(x: 0.500 * W, y: 0.885 * H)
                .opacity(min(max((p - 0.5) / 0.5, 0), 1))
        }
    }

    /// La forme : un galet organique PEINT (l'école `galetMedaillon` — il
    /// brille sur tout fond parce qu'il n'emprunte rien), et le balayage
    /// blanc qui le traverse quand `nouveau`. ⚠️ L'horloge ne tourne que si
    /// le reflet existe, et dort sous Reduce Motion.
    @ViewBuilder
    private func forme(W: CGFloat, H: CGFloat) -> some View {
        // Plus LARGE et plus BASSE qu'un ovale (0,66 × 0,30) : une flaque,
        // pas un médaillon. Et PRESQUE invisible : le premier jet à 0,078
        // de blanc se lisait comme un ovale gris posé — la forme doit se
        // deviner, c'est le reflet-événement qui la révèle.
        let fw = 0.66 * W, fh = 0.30 * W
        ZStack {
            Ellipse()
                .fill(RadialGradient(
                    stops: [
                        .init(color: Color(white: 0.050), location: 0.00),
                        .init(color: Color(white: 0.028), location: 0.55),
                        .init(color: Color(white: 0.006), location: 1.00),
                    ],
                    center: UnitPoint(x: 0.36, y: 0.26),
                    startRadius: 0, endRadius: fw * 0.72))
            Ellipse()
                .strokeBorder(LinearGradient(
                    colors: [.white.opacity(0.13), .clear, .clear],
                    startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.8)
            if nouveau, !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    // Un passage de 1,2 s toutes les 4,6 s — un événement,
                    // pas un gyrophare.
                    let cycle = t.truncatingRemainder(dividingBy: 4.6)
                    let ph = min(max(cycle / 1.2, 0), 1)
                    Capsule()
                        .fill(LinearGradient(
                            colors: [.clear, .white.opacity(0.50), .clear],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: fw * 0.22, height: fh * 1.6)
                        .rotationEffect(.degrees(24))
                        .offset(x: fw * (ph - 0.5) * 1.4)
                        .blur(radius: 2.5)
                        .opacity(ph <= 0 || ph >= 1 ? 0
                                 : 0.9 * sin(.pi * ph))
                        .frame(width: fw, height: fh)
                }
                .mask(Ellipse())
            }
        }
        .frame(width: fw, height: fh)
        .rotationEffect(.degrees(-8))
        .position(x: 0.500 * W, y: 0.520 * H)
    }
}

// MARK: - LE FANTÔME DE SLOT

/// UN SLOT VIDE N'EST PAS UN TROU : c'est un fantôme — la grammaire des
/// mini-cards « à faire » de la semaine (verre `.clear` nu, la vidéo passe
/// au travers). Il dit « il y a une place ici » sans le crier, et son tap
/// ouvre la vitrine : c'est LE chemin d'ajout. Bounds constants (170), la
/// matérialisation d'une card se fait par-dessus, le verre ne se démonte
/// jamais.
struct CardFantome: View {
    /// 0 → 1 : le mode édition (le + s'affirme un peu).
    var edition: Double = 0

    var body: some View {
        GeometryReader { g in
            let W = g.size.width, H = g.size.height
            let forme = RoundedRectangle(cornerRadius: 0.152 * W,
                                         style: .circular)
            ZStack {
                GlassEffectContainer(spacing: 0) {
                    Color.clear
                        .frame(width: W, height: H)
                        .glassEffect(.clear, in: forme)
                }
                forme.strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                ZStack {
                    Capsule().frame(width: 0.13 * W, height: 1.2)
                    Capsule().frame(width: 1.2, height: 0.13 * W)
                }
                .foregroundStyle(.white.opacity(0.25 + 0.25 * edition))
            }
        }
    }
}

// MARK: - Les données des widgets

/// Ce que la card HIIT Peak affiche — calculé par `SemaineStats`, ou les
/// défauts de banc.
struct HiitPeakInfo {
    var vitesse = "17.0"
    var repetitions = "4 × 40 s"
    var chambreLigne = "17.0 km/h · 40 s · ×4"
    var pic = 0.62
    var picLargeur = 0.26
}

/// Ce que la card Peak Effort affiche.
struct PeakEffortInfo {
    var titre = "Hip Thrust"
    var valeur = "+10 kg"
    var chambreHaut = "60 kg × 8"
    var chambreBas = "previous best · 55 kg"
    var nouveau = true
}

/// LES CHIFFRES DE LA SEMAINE — calculés UNE fois (à l'apparition de la
/// page, jamais dans un `body` : la home vit sous une TimelineView 60 Hz,
/// et le piège de la page ré-évaluée par image a déjà été payé).
///
/// Les décisions du plan (arbitrage E) :
///  · une séance TERMINÉE (`endedAt != nil`) vaut exécution de son plan —
///    `CardioPhase` n'a aucune notion de réalisé, et `totalVolume` ignore
///    `isDone` : on ne filtre pas ce que le modèle ne sait pas dire ;
///  · l'escalier est EXCLU du HIIT peak (son `speed` est un niveau de
///    machine, pas des km/h) ;
///  · la semaine commence LUNDI (la convention du calendrier).
struct SemaineStats {
    var faites = 0
    var pied = ""
    var volumeValeur = "0"
    var volumeUnite = "kg"
    var gain = "—"
    var moyenne = "—"
    var jours: [CardJour] = CardJour.semaineRef
    var moisFaits: Set<Int> = []
    var hiit: HiitPeakInfo?
    var peak: PeakEffortInfo?

    static func calcule(_ workouts: [Workout], prevues: Int,
                        maintenant: Date = .now) -> SemaineStats {
        var cal = Calendar.current
        cal.firstWeekday = 2
        guard let semaine = cal.dateInterval(of: .weekOfYear,
                                             for: maintenant)
        else { return SemaineStats() }
        let finies = workouts.filter { !$0.isActive }
        let cette = finies.filter {
            $0.startedAt >= semaine.start && $0.startedAt < semaine.end
        }
        let avant = finies.filter { $0.startedAt < semaine.start }
        let precedente = avant.filter {
            $0.startedAt >= semaine.start.addingTimeInterval(-7 * 86400)
        }

        var s = SemaineStats()
        s.faites = cette.count
        let restent = max(prevues - cette.count, 0)
        s.pied = restent == 0 ? "goal reached"
            : "\(restent) session\(restent > 1 ? "s" : "") left to hit your goal"

        // ── LE VOLUME
        let v = cette.reduce(0) { $0 + $1.totalVolume }
        let vPrev = precedente.reduce(0) { $0 + $1.totalVolume }
        (s.volumeValeur, s.volumeUnite) = Self.kg(v)
        if vPrev > 0 {
            let d = Int(((v - vPrev) / vPrev * 100).rounded())
            s.gain = d >= 0 ? "+\(d)%" : "−\(-d)%"
        } else {
            s.gain = "new"
        }
        if s.faites > 0 {
            let (mv, mu) = Self.kg(v / Double(s.faites))
            s.moyenne = "\(mv) \(mu)"
        }

        // ── LA RÉGULARITÉ : les rails du graphe, jour par jour (lundi en
        // tête). L'« effort » d'un jour = volume + un proxy pour le cardio
        // (20 kg-équivalent la minute) — c'est une jauge, pas un bilan.
        var efforts = [Double](repeating: 0, count: 7)
        var segments = [Int](repeating: 0, count: 7)
        for w in cette {
            let wd = cal.component(.weekday, from: w.startedAt)
            let i = (wd + 5) % 7
            efforts[i] += w.totalVolume + 20 * Double(w.cardioMinutes)
            segments[i] += 1
        }
        let maxE = max(efforts.max() ?? 1, 1)
        let lettres = ["M", "T", "W", "T", "F", "S", "S"]
        s.jours = (0..<7).map { i in
            let f = efforts[i] / maxE
            return CardJour(lettre: lettres[i],
                            rail: 0.048 + 0.182 * f,
                            segments: efforts[i] > 0
                                ? min(max(Int((f * 5).rounded()), 1), 5) : 0)
        }

        // ── LE MOIS (l'intérieur de la chambre des séances)
        if let mois = cal.dateInterval(of: .month, for: maintenant) {
            s.moisFaits = Set(finies
                .filter { $0.startedAt >= mois.start && $0.startedAt < mois.end }
                .map { cal.component(.day, from: $0.startedAt) })
        }

        s.hiit = Self.hiitPeak(cette)
        s.peak = Self.peakEffort(cette: cette, avant: avant)
        return s
    }

    // ── HIIT PEAK : le meilleur segment haute intensité. Les répétitions
    // s'INFÈRENT en matchant (kind, vitesse, durée) à travers les cycles —
    // fiable sur le vrai flow (le même cycle répété), et le score est
    // vitesse × (durée × répétitions), départagé à la vitesse.
    private static func hiitPeak(_ cette: [Workout]) -> HiitPeakInfo? {
        var best: (score: Double, v: Double, s: Int, n: Int)?
        func candidat(_ v: Double, _ sec: Int, _ n: Int) {
            // LA HAUTE INTENSITÉ D'ABORD. Un score linéaire en durée fait
            // gagner la MARCHE (mesuré : « 5,5 km/h · 20:00 continuous »
            // battait les sprints) : la vitesse pèse en puissance 2,2, la
            // durée en racine — et sous 9,5 km/h ce n'est pas un peak.
            guard v >= 9.5 else { return }
            let score = pow(v, 2.2) * pow(Double(sec * n), 0.5)
            if best == nil || score > best!.score
                || (score == best!.score && v > best!.v) {
                best = (score, v, sec, n)
            }
        }
        for w in cette {
            for ex in w.orderedExercises {
                guard let e = ex.exercise, e.tracking != .setsRepsWeight,
                      ex.exerciseID != "escalier" else { continue }
                if e.tracking == .intervals {
                    var groupes: [String: (v: Double, s: Int, n: Int)] = [:]
                    for ph in ex.orderedPhases where ph.isEffort {
                        let cle = "\(ph.kindRaw)|\(ph.speed)|\(ph.seconds)"
                        var g = groupes[cle] ?? (ph.speed, ph.seconds, 0)
                        g.n += 1
                        groupes[cle] = g
                    }
                    for g in groupes.values { candidat(g.v, g.s, g.n) }
                } else {
                    // Un steady concourt comme un segment continu ×1 :
                    // « 15.1 km/h · 5:08 continuous ».
                    for ph in ex.orderedPhases where ph.seconds >= 120 {
                        candidat(ph.speed, ph.seconds, 1)
                    }
                }
            }
        }
        guard let b = best else { return nil }
        let v = vitesse(b.v)
        var info = HiitPeakInfo()
        info.vitesse = v
        if b.n > 1 {
            info.repetitions = "\(b.n) × \(duree(b.s))"
            info.chambreLigne = "\(v) km/h · \(duree(b.s)) · ×\(b.n)"
        } else {
            info.repetitions = "\(duree(b.s)) continuous"
            info.chambreLigne = "\(v) km/h · \(duree(b.s))"
        }
        return info
    }

    // ── PEAK EFFORT : le moment le plus fort, priorité charge > vitesse >
    // volume (l'ordre du plan, à fouetter). À défaut de record battu, la
    // plus grosse charge de la semaine — un widget vide serait un bug.
    private static func peakEffort(cette: [Workout],
                                   avant: [Workout]) -> PeakEffortInfo? {
        var maxAvant: [String: Double] = [:]
        for w in avant {
            for ex in w.orderedExercises where ex.maxWeight > 0 {
                maxAvant[ex.exerciseID] =
                    max(maxAvant[ex.exerciseID] ?? 0, ex.maxWeight)
            }
        }
        // 1. LA CHARGE — « Hip Thrust · +10 kg ».
        var charge: (nom: String, delta: Double, poids: Double, reps: Int)?
        var plusLourd: (nom: String, poids: Double, reps: Int)?
        for w in cette {
            for ex in w.orderedExercises where ex.maxWeight > 0 {
                let reps = ex.orderedSets
                    .filter { $0.weight == ex.maxWeight }
                    .map(\.reps).max() ?? 0
                if plusLourd == nil || ex.maxWeight > plusLourd!.poids {
                    plusLourd = (ex.name, ex.maxWeight, reps)
                }
                guard let prev = maxAvant[ex.exerciseID], prev > 0,
                      ex.maxWeight > prev else { continue }
                let delta = ex.maxWeight - prev
                if charge == nil || delta > charge!.delta {
                    charge = (ex.name, delta, ex.maxWeight, reps)
                }
            }
        }
        if let c = charge {
            return PeakEffortInfo(
                titre: c.nom,
                valeur: "+\(poids(c.delta)) kg",
                chambreHaut: "\(poids(c.poids)) kg × \(c.reps)",
                chambreBas: "previous best · \(poids(c.poids - c.delta)) kg",
                nouveau: true)
        }
        // 2. LA VITESSE — « HIIT · 17.0 km/h ».
        var vAvant: Double = 0
        for w in avant {
            for ex in w.orderedExercises where ex.exerciseID != "escalier" {
                for ph in ex.orderedPhases where ph.isEffort {
                    vAvant = max(vAvant, ph.speed)
                }
            }
        }
        var vitesse: (nom: String, v: Double, s: Int, n: Int)?
        for w in cette {
            for ex in w.orderedExercises where ex.exerciseID != "escalier" {
                for ph in ex.orderedPhases where ph.isEffort {
                    if ph.speed > vAvant,
                       vitesse == nil || ph.speed > vitesse!.v {
                        let n = ex.orderedPhases.filter {
                            $0.isEffort && $0.speed == ph.speed
                                && $0.seconds == ph.seconds
                        }.count
                        vitesse = (ex.name, ph.speed, ph.seconds, n)
                    }
                }
            }
        }
        if let v = vitesse {
            let vs = Self.vitesse(v.v)
            return PeakEffortInfo(
                titre: v.nom,
                valeur: "\(vs) km/h",
                chambreHaut: "\(duree(v.s))\(v.n > 1 ? " × \(v.n)" : "")",
                chambreBas: "fastest ever",
                nouveau: true)
        }
        // 3. À DÉFAUT : la plus grosse charge de la semaine, sans le reflet.
        if let p = plusLourd {
            return PeakEffortInfo(
                titre: p.nom,
                valeur: "\(poids(p.poids)) kg",
                chambreHaut: "\(poids(p.poids)) kg × \(p.reps)",
                chambreBas: "heaviest this week",
                nouveau: false)
        }
        return nil
    }

    // ── Les formats. ⚠️ TOUJOURS le POINT décimal : les cards parlent
    // anglais, et `formatted(.number)` suit la locale du téléphone —
    // mesuré : « 5,5 km/h » sur une card qui dit « continuous ».
    private static func kg(_ v: Double) -> (String, String) {
        if v >= 10000 {
            return (String(format: "%.1f", v / 1000), "t")
        }
        if v >= 100 { return ("\(Int(v.rounded()))", "kg") }
        return (String(format: "%.1f", v), "kg")
    }
    private static func poids(_ v: Double) -> String {
        v == v.rounded() ? "\(Int(v))" : String(format: "%.1f", v)
    }
    private static func vitesse(_ v: Double) -> String {
        String(format: "%.1f", v)
    }
    private static func duree(_ s: Int) -> String {
        s < 90 ? "\(s) s" : String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - Le catalogue

/// LES QUATRE WIDGETS de la home. L'ordre est celui de la vitrine.
enum WidgetKind: String, CaseIterable, Identifiable {
    case regularite, volume, hiitPeak, peakEffort

    var id: String { rawValue }

    var numero: String {
        switch self {
        case .regularite: return "01"
        case .volume: return "02"
        case .hiitPeak: return "03"
        case .peakEffort: return "04"
        }
    }

    /// Le nom de la vitrine — la zone widgets parle anglais (arbitrage D).
    var nom: String {
        switch self {
        case .regularite: return "REGULARITY"
        case .volume: return "VOLUME"
        case .hiitPeak: return "HIIT PEAK"
        case .peakEffort: return "PEAK EFFORT"
        }
    }
}

// MARK: - L'ancrage

/// Poser un bloc par son coin HAUT-GAUCHE dans un `GeometryReader` : SwiftUI
/// ne sait le faire qu'au centre (`position`), et mesurer chaque texte pour
/// recentrer serait une usine. Un `alignmentGuide` fait le travail.
private struct AncrageGauche: ViewModifier {
    var x: CGFloat
    var y: CGFloat
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity,
                   alignment: .topLeading)
            .offset(x: x, y: y)
    }
}

// MARK: - Le banc

/// `-cardsLab` : une card en grand (la taille de la référence) et les
/// quatre à leur taille de home, avec l'arrivée qui rejoue en boucle.
/// `-widgetHiit` / `-widgetPeak` mettent le widget neuf en grand.
struct CardsLab: View {
    @State private var p: Double = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 22) {
                Text("LES CARDS")
                    .font(.system(size: 11, weight: .semibold)).tracking(2.4)
                    .foregroundStyle(.white.opacity(0.38))
                if CommandLine.arguments.contains("-widgetHiit") {
                    CardHiitPeak(p: p).frame(width: 330, height: 333)
                } else if CommandLine.arguments.contains("-widgetPeak") {
                    CardPeakEffort(p: p).frame(width: 330, height: 333)
                } else {
                    CardVolume(p: p).frame(width: 330, height: 333)
                }
                HStack(spacing: 16) {
                    CardSeances(p: p).frame(width: 169, height: 171)
                    CardVolume(p: p).frame(width: 169, height: 171)
                }
                HStack(spacing: 16) {
                    CardHiitPeak(p: p).frame(width: 169, height: 171)
                    CardPeakEffort(p: p).frame(width: 169, height: 171)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) { p = 1 }
            Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
                withAnimation(.easeIn(duration: 0.3)) { p = 0 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation(.easeOut(duration: 1.0)) { p = 1 }
                }
            }
        }
    }
}

// MARK: - La respiration du mode édition

/// L'OSCILLATION DU MODE ÉDITION — pas le jiggle d'iOS : ±1,4°, lent, une
/// période PROPRE à chaque card (2,9 s / 3,7 s, premières entre elles,
/// sinon elles battent ensemble), en opposition de phase. L'angle est
/// LIVRÉ au contenu : la card l'applique en `rotationEffect` ET le passe au
/// liseré qui contre-tourne (la lampe reste fixe).
///
/// ⚠️ L'horloge n'existe qu'en mode édition (20 Hz suffisent à 1,4° sur
/// 3 s) et JAMAIS sous Reduce Motion — hors édition le sous-arbre est le
/// contenu nu, pas une TimelineView en pause (la page a déjà ses horloges).
private struct RespireEdition<C: View>: View {
    var edition: Double
    var periode: Double
    var phase: Double
    @ViewBuilder var contenu: (Double) -> C

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if edition < 0.005 || reduceMotion {
            contenu(0)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 20)) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                contenu(1.4 * edition
                        * sin(t * 2 * .pi / periode + phase))
            }
        }
    }
}

// MARK: - La rangée de la home

/// Les deux slots de widgets de la home. Gouttière 24 (celle de la phrase
/// et de l'ardoise de la semaine), écart 14 : les deux cards remplissent la
/// largeur utile, et elles sont CARRÉES (la référence l'est à 1 %).
///
/// LE MODE ÉDITION vit ici : le zoom arrière de la zone, la respiration de
/// chaque card, les pastilles lune. L'ÉTAT, lui, vit AU-DESSUS (la page) —
/// tout `@State` posé ici serait perdu au démontage `verreMonte`.
struct CardsRangee: View {
    var faites: Int = 4
    var prevues: Int = 5
    var volume: String = "8.4"
    var volumeUnite: String = "kg"
    var moyenne: String = "1.2 kg"
    var gain: String = "+12%"
    var jours: [CardJour] = CardJour.semaineRef
    var pied: String = "1 session left to hit your goal"
    var moisFaits: Set<Int>? = nil
    var hiit: HiitPeakInfo = HiitPeakInfo()
    var peak: PeakEffortInfo = PeakEffortInfo()
    /// 0 → 1, l'arrivée de la page.
    var arrivee: Double = 1
    var lisere: Bool = true
    var verre: Bool = false
    /// LES DEUX SLOTS — `nil` = le fantôme. Persistés par la page
    /// (`widgetSlot0/1` en `@AppStorage`).
    var slots: [WidgetKind?] = [.regularite, .volume]
    /// 0 → 1, l'entrée du mode édition (curseur animé par la page, livré
    /// image par image via `Chambre`).
    var edition: Double = 0
    /// Le mode édition est ACTIF : les cards deviennent inertes, seules
    /// les pastilles parlent.
    var editionActive: Bool = false
    /// Le slot dont la card VOLE dans la vitrine : il garde sa place,
    /// vide (le clone est dans l'overlay).
    var masque: Int? = nil
    var onEdition: ((Int) -> Void)? = nil
    var onPastille: ((Int) -> Void)? = nil
    var onFantome: ((Int) -> Void)? = nil

    var body: some View {
        Chambre(p: edition) { ed in
            HStack(spacing: 14) {
                slotVue(0, ed)
                slotVue(1, ed)
            }
            // LE ZOOM ARRIÈRE de la zone — un transform, jamais un frame :
            // les bounds du verre ne bougent pas (précédent licite : le
            // retrait du menu scale déjà le mobilier verre compris).
            .scaleEffect(1 - 0.04 * ed, anchor: .center)
        }
        .opacity(pose)
        .offset(y: 12 * (1 - pose))
    }

    @ViewBuilder
    private func slotVue(_ i: Int, _ ed: Double) -> some View {
        if masque == i {
            // La card est partie dans la vitrine : le slot tient sa place.
            Color.clear.frame(width: 170, height: 170)
        } else if let kind = slots[i] {
            RespireEdition(edition: ed,
                           periode: i == 0 ? 2.9 : 3.7,
                           phase: i == 0 ? 0 : .pi) { angle in
                carte(kind, slot: i, penche: angle)
                    .frame(width: 170, height: 170)
                    .overlay(alignment: .topTrailing) {
                        // LA PASTILLE — posée SUR le coin (elle déborde de
                        // 8 pt), elle suit la respiration de sa card : elle
                        // est DE la card. 70 ms d'écart entre les deux.
                        PastilleLune(p: pastilleP(i, ed)) {
                            onPastille?(i)
                        }
                        .offset(x: 8, y: -8)
                    }
                    .rotationEffect(.degrees(angle))
            }
            .frame(width: 170, height: 170)
        } else {
            CardFantome(edition: ed)
                .frame(width: 170, height: 170)
                .contentShape(Rectangle())
                .onTapGesture { onFantome?(i) }
        }
    }

    @ViewBuilder
    private func carte(_ kind: WidgetKind, slot: Int,
                       penche: Double) -> some View {
        let mode: CardMode = editionActive
            ? .inerte
            : (onEdition.map { f in CardMode.home(onEdition: { f(slot) }) }
               ?? .libre)
        switch kind {
        case .regularite:
            if let mf = moisFaits {
                CardSeances(faites: faites, prevues: prevues, pied: pied,
                            p: pose, lisere: lisere, verre: verre,
                            moisFaits: mf,
                            penche: penche, interaction: mode)
            } else {
                CardSeances(faites: faites, prevues: prevues, pied: pied,
                            p: pose, lisere: lisere, verre: verre,
                            penche: penche, interaction: mode)
            }
        case .volume:
            CardVolume(valeur: volume, unite: volumeUnite, jours: jours,
                       gain: gain, moyenne: moyenne, p: pose,
                       lisere: lisere, verre: verre,
                       penche: penche, interaction: mode)
        case .hiitPeak:
            CardHiitPeak(vitesse: hiit.vitesse,
                         repetitions: hiit.repetitions,
                         pic: hiit.pic, picLargeur: hiit.picLargeur,
                         chambreLigne: hiit.chambreLigne,
                         p: pose, lisere: lisere, verre: verre,
                         penche: penche, interaction: mode)
        case .peakEffort:
            CardPeakEffort(titre: peak.titre, valeur: peak.valeur,
                           chambreHaut: peak.chambreHaut,
                           chambreBas: peak.chambreBas,
                           nouveau: peak.nouveau,
                           p: pose, lisere: lisere, verre: verre,
                           penche: penche, interaction: mode)
        }
    }

    /// La fenêtre d'arrivée de la pastille du slot `i` : 70 ms d'écart.
    private func pastilleP(_ i: Int, _ ed: Double) -> Double {
        let a = 0.55 + 0.165 * Double(i)
        return min(max((ed - a) / (1 - a), 0), 1)
    }

    /// Les cards prennent le courant APRÈS la phrase et AVANT la semaine :
    /// la lumière, les mots, les mesures, les objets.
    private var pose: Double { min(max((arrivee - 0.55) / 0.30, 0), 1) }
}

// MARK: - Le pont entre une animation et un `body`

/// ⚠️ **UN `withAnimation` N'INTERPOLE QUE LES `animatableData` DES
/// MODIFICATEURS.** Une valeur lue dans un `body` — pour en dériver des
/// fenêtres échelonnées, par exemple — saute à sa cible sur-le-champ. Ce petit
/// pont existe pour ça : il est `Animatable`, donc SwiftUI lui livre `p` image
/// par image, et son contenu peut enfin s'en servir pour calculer des retards.
///
/// C'est la forme déjà payée sur la phrase de la home (`PhraseVue`), rendue
/// générique — une chorégraphie à plusieurs pièces n'en a pas d'autre.
struct Chambre<Contenu: View>: View, Animatable {
    var p: Double
    @ViewBuilder var contenu: (Double) -> Contenu

    var animatableData: Double {
        get { p }
        set { p = newValue }
    }

    var body: some View { contenu(p) }
}

/// Les fenêtres de la chorégraphie, partagées par les deux cards : le noir
/// tombe d'abord, la surface recule ensuite, l'intérieur arrive en dernier.
/// La lumière avant la géométrie, comme partout dans cette maison.
enum ChambreTemps {
    static func fen(_ p: Double, _ a: Double, _ b: Double) -> Double {
        min(max((p - a) / (b - a), 0), 1)
    }
    /// Le noir et le cadre : les premiers, et vite.
    static func nuit(_ p: Double) -> Double { fen(p, 0.00, 0.18) }
    /// La surface recule — elle ne DISPARAÎT pas : on doit la sentir derrière.
    static func recul(_ p: Double) -> Double { fen(p, 0.12, 0.55) }
    /// L'intérieur arrive du fond, en dernier.
    static func fond(_ p: Double) -> Double { fen(p, 0.30, 1.00) }
}
