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
                            .degrees(souffle + 16 * chambre))
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

    /// `-chambre` fige la chambre OUVERTE : le simulateur ne sait pas
    /// tenir un doigt, et une chambre ne se juge qu'ouverte.
    @State private var chambre: Double =
        CommandLine.arguments.contains("-chambre") ? 1 : 0
    @State private var presseAt: Date?
    @State private var etaitOuverte = false
    @State private var doigt: CGPoint?

    var body: some View {
        CardCorps(lisere: lisere, verre: verre, chambre: chambre,
                  doigt: doigt) {
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
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .circular))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { v in
                    doigt = v.location
                    guard presseAt == nil else { return }
                    presseAt = Date()
                    etaitOuverte = chambre > 0.5
                    guard !etaitOuverte else { return }
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    withAnimation(.timingCurve(0.22, 1, 0.36, 1,
                                               duration: 0.52)) { chambre = 1 }
                }
                .onEnded { _ in
                    // DEUX GESTES, UNE SEULE CHAMBRE — la grammaire des menus
                    // contextuels d'iOS : un TAP la laisse ouverte (on veut
                    // lire), un APPUI TENU n'est qu'un aperçu et se referme au
                    // relâchement. Et un tap sur une chambre déjà ouverte la
                    // referme.
                    let court = Date()
                        .timeIntervalSince(presseAt ?? Date()) < 0.28
                    let ferme = etaitOuverte || !court
                    presseAt = nil
                    withAnimation(.easeOut(duration: 0.28)) { doigt = nil }
                    guard ferme else { return }
                    withAnimation(.timingCurve(0.30, 0, 0.40, 1,
                                               duration: 0.34)) { chambre = 0 }
                }
        )
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

    /// `-chambre` fige la chambre OUVERTE : le simulateur ne sait pas
    /// tenir un doigt, et une chambre ne se juge qu'ouverte.
    @State private var chambre: Double =
        CommandLine.arguments.contains("-chambre") ? 1 : 0
    @State private var presseAt: Date?
    @State private var etaitOuverte = false
    @State private var doigt: CGPoint?

    var body: some View {
        CardCorps(lisere: lisere, verre: verre, chambre: chambre,
                  doigt: doigt) {
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
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .circular))
        // ⚠️ UN SEUL GESTE : un `onLongPressGesture` volerait le tap.
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { v in
                    doigt = v.location
                    guard presseAt == nil else { return }
                    presseAt = Date()
                    etaitOuverte = chambre > 0.5
                    guard !etaitOuverte else { return }
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    withAnimation(.timingCurve(0.22, 1, 0.36, 1,
                                               duration: 0.52)) { chambre = 1 }
                }
                .onEnded { _ in
                    // DEUX GESTES, UNE SEULE CHAMBRE — la grammaire des menus
                    // contextuels d'iOS : un TAP la laisse ouverte (on veut
                    // lire), un APPUI TENU n'est qu'un aperçu et se referme au
                    // relâchement. Et un tap sur une chambre déjà ouverte la
                    // referme.
                    let court = Date()
                        .timeIntervalSince(presseAt ?? Date()) < 0.28
                    let ferme = etaitOuverte || !court
                    presseAt = nil
                    withAnimation(.easeOut(duration: 0.28)) { doigt = nil }
                    guard ferme else { return }
                    // RIEN à la main au relâchement : le silence à la fin se
                    // sent plus cher qu'un second clac.
                    withAnimation(.timingCurve(0.30, 0, 0.40, 1,
                                               duration: 0.34)) { chambre = 0 }
                }
        )
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

/// `-cardsLab` : les deux cards en grand (la taille de la référence) et à
/// leur taille de home, avec l'arrivée qui rejoue en boucle.
struct CardsLab: View {
    @State private var p: Double = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 26) {
                Text("LES CARDS")
                    .font(.system(size: 11, weight: .semibold)).tracking(2.4)
                    .foregroundStyle(.white.opacity(0.38))
                CardVolume(p: p)
                    .frame(width: 330, height: 333)
                HStack(spacing: 16) {
                    CardSeances(p: p).frame(width: 169, height: 171)
                    CardVolume(p: p).frame(width: 169, height: 171)
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

// MARK: - La rangée de la home

/// Les deux widgets de la home. Gouttière 24 (celle de la phrase et de
/// l'ardoise de la semaine), écart 14 : les deux cards remplissent la
/// largeur utile, et elles sont CARRÉES (la référence l'est à 1 %).
struct CardsRangee: View {
    var faites: Int = 4
    var prevues: Int = 5
    var volume: String = "8.4"
    var moyenne: String = "1.2 kg"
    var gain: String = "+12%"
    var jours: [CardJour] = CardJour.semaineRef
    /// 0 → 1, l'arrivée de la page.
    var arrivee: Double = 1
    var lisere: Bool = true
    var verre: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            CardSeances(faites: faites, prevues: prevues, p: pose,
                        lisere: lisere, verre: verre)
                .frame(width: 170, height: 170)
            CardVolume(valeur: volume, jours: jours, gain: gain,
                       moyenne: moyenne, p: pose,
                       lisere: lisere, verre: verre)
                .frame(width: 170, height: 170)
        }
        .opacity(pose)
        .offset(y: 12 * (1 - pose))
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
