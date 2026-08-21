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
    @ViewBuilder var contenu: () -> Contenu

    var body: some View {
        GeometryReader { g in
            let W = g.size.width, H = g.size.height
            let e = encastre * W
            let dehors = RoundedRectangle(cornerRadius: rayon * W,
                                          style: .circular)
            let dedans = RoundedRectangle(cornerRadius: 0.1175 * W,
                                          style: .circular)
            ZStack {
                // ── 1. LA BEZEL, presque noire
                dehors.fill(Color(white: 0.014))

                // ── 2. LE LISERÉ ANGULAIRE, d'un seul trait : il porte à la
                // fois le gris des bords ordinaires ET les deux crêtes.
                dehors.stroke(cardLisereConique, lineWidth: 1.6)
                // le bloom, court (mesuré : 8-12 px aux crêtes, 4-5 ailleurs)
                dehors.stroke(cardLisereConique, lineWidth: 4.4)
                    .blur(radius: 2.4)
                    .opacity(0.46)

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
                    dedans.fill(RadialGradient(
                        colors: [Color(white: 0.157), .clear],
                        center: .topTrailing,
                        startRadius: 0, endRadius: W * 1.12))
                    dedans.fill(RadialGradient(
                        colors: [Color(white: 0.106), .clear],
                        center: .bottomLeading,
                        startRadius: 0, endRadius: W * 0.77))
                    // son liseré : même loi angulaire, mais il ne SATURE
                    // jamais — il reste du gris, plus clair en haut.
                    dedans.stroke(cardLisereDedans, lineWidth: 1.1)
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
let cardLisereConique = AngularGradient(stops: [
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
], center: .center)

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
    var valeur: String = "8.4"
    var unite: String = "kg"
    var legende: String = "weekly volume"
    var jours: [CardJour] = CardJour.semaineRef
    var gain: String = "+12%"
    var gainLegende: String = "vs last week"
    var moyenneLegende: String = "avg per session"
    var moyenne: String = "1.2 kg"
    /// 0 → 1 : l'arrivée (les barres poussent, l'encre se pose).
    var p: Double = 1

    var body: some View {
        CardCorps {
            GeometryReader { g in
                let W = g.size.width, H = g.size.height
                let marge = 0.129 * W

                // ── L'EN-TÊTE. Hauteur de capitale mesurée : 13,54 % de H
                // pour le gros chiffre, 4,08 % pour la légende ; une
                // capitale d'Inter vaut 0,715 de son corps.
                HStack(alignment: .lastTextBaseline, spacing: 0.012 * W) {
                    Text(valeur)
                        .font(.system(size: 0.1750 * H, weight: .regular))
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
                    .font(.system(size: 0.0430 * H, weight: .regular))
                    .tracking(0.0430 * H * 0.030)
                    .foregroundStyle(CardTon.encreDouce)
                    .modifier(AncrageGauche(x: marge, y: 0.277 * H))

                CardBoutonHaltere(W: W, H: H)
                    .position(x: 0.848 * W, y: 0.192 * H)

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
                Text(gain)
                    .font(.system(size: 0.0606 * H, weight: .regular))
                    .foregroundStyle(CardTon.ambreVif)
                    .position(x: 0.270 * W, y: 0.808 * H)
                Text(gainLegende)
                    .font(.system(size: 0.0350 * H, weight: .regular))
                    .foregroundStyle(CardTon.encreSourde)
                    .position(x: 0.270 * W, y: 0.861 * H)

                Rectangle()
                    .fill(CardTon.filet)
                    .frame(width: 0.8, height: 0.090 * H)
                    .position(x: 0.479 * W, y: 0.851 * H)

                // La VALEUR au-dessus de son libellé, comme la colonne de
                // gauche : les deux colonnes se lisent enfin pareil.
                Text(moyenne)
                    .font(.system(size: 0.0606 * H, weight: .regular))
                    .foregroundStyle(CardTon.encre)
                    .position(x: 0.700 * W, y: 0.808 * H)
                Text(moyenneLegende)
                    .font(.system(size: 0.0350 * H, weight: .regular))
                    .foregroundStyle(CardTon.encreSourde)
                    .position(x: 0.700 * W, y: 0.861 * H)
            }
        }
    }
}

// MARK: - LA CARD DES SÉANCES

struct CardSeances: View {
    var faites: Int = 4
    var prevues: Int = 5
    var legende: String = "sessions this week"
    var jours: [String] = ["M", "T", "W", "T", "F", "S", "S"]
    var pied: String = "1 session left to hit your goal"
    var p: Double = 1

    var body: some View {
        CardCorps {
            GeometryReader { g in
                let W = g.size.width, H = g.size.height
                let marge = 0.129 * W

                // Le « 4 / 5 » s'aligne sur le « 8.4 » de la card voisine —
                // même gouttière, même ligne d'œil — et il est POSÉ
                // AU-DESSUS de sa légende : il la recouvrait.
                HStack(alignment: .lastTextBaseline, spacing: 0.024 * W) {
                    Text("\(faites)")
                        .font(.system(size: 0.1750 * H, weight: .regular))
                        .foregroundStyle(LinearGradient(
                            colors: [Color(white: 1.00), Color(white: 0.788)],
                            startPoint: .top, endPoint: .bottom))
                    Text("/ \(prevues)")
                        .font(.system(size: 0.0817 * H, weight: .regular))
                        .foregroundStyle(CardTon.encreDouce)
                }
                .modifier(AncrageGauche(x: marge, y: 0.0694 * H))

                Text(legende)
                    .font(.system(size: 0.0430 * H, weight: .regular))
                    .tracking(0.0430 * H * 0.030)
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
                        .font(.system(size: 0.0430 * H, weight: .regular))
                        .foregroundStyle(CardTon.encreDouce)
                }
                .modifier(AncrageGauche(x: marge, y: 0.787 * H))
            }
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

    var body: some View {
        HStack(spacing: 14) {
            CardSeances(faites: faites, prevues: prevues, p: pose)
                .frame(width: 170, height: 170)
            CardVolume(valeur: volume, jours: jours, gain: gain,
                       moyenne: moyenne, p: pose)
                .frame(width: 170, height: 170)
        }
        .opacity(pose)
        .offset(y: 12 * (1 - pose))
    }

    /// Les cards prennent le courant APRÈS la phrase et AVANT la semaine :
    /// la lumière, les mots, les mesures, les objets.
    private var pose: Double { min(max((arrivee - 0.55) / 0.30, 0), 1) }
}
