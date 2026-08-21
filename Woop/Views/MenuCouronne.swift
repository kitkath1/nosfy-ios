import SwiftUI
import UIKit

// MARK: - LA COURONNE — le menu qui éclôt AUTOUR du galet
//
// Commandé le 21-08 : *« comme AssistiveTouch, quand j'appuie longuement ça
// vient autour en mode haptique et ça ouvre autour de lui le menu en blur
// rond »*.
//
// L'idée règle un défaut de structure : la colonne est ancrée en bas de l'écran
// quoi qu'il arrive, **donc le galet est obligé de rentrer chez lui avant
// d'ouvrir**. Un menu qui naît là où l'objet se trouve rend enfin le transport
// utile.
//
// SIX LOIS, et la première est celle qui a décidé de toute la forme :
//
//  1. **LA COURONNE NE PEUT PAS PORTER LES MOTS.** Mesuré : « Progression »
//     fait ~150 pt de large à 26 pt ; quatre mots autour d'un rayon de 104 sur
//     une dalle de 402 ne rentrent pas, et près d'un coin pas du tout. Donc la
//     couronne porte des MÉDAILLONS, et le mot n'apparaît QUE sous le doigt,
//     un seul à la fois, en grand. C'est la grammaire d'AssistiveTouch et de
//     watchOS — et c'est plus premium que quatre étiquettes : la bague est
//     sobre, c'est le doigt qui révèle.
//
//  2. **ON NE VISE RIEN : LA SÉLECTION SE FAIT PAR L'ANGLE.** Le pouce part
//     vers un médaillon et il est choisi. C'est l'ergonomie à une main, et ça
//     supprime d'un coup toute la classe de bugs de zone sensible.
//
//  3. **ICI, ET SEULEMENT ICI, LE VERRE NATIF EST LÉGITIME.** Il lui faut un
//     BORD légitime et de quoi RÉFRACTER : un disque a un vrai bord, et il est
//     posé sur la vidéo — du contenu DOUX, le seul que `.clear` ait le droit de
//     recouvrir. ⚠️ Et jamais un `.blur` : il pose un voile uniforme sur tout
//     le rectangle de son hôte, il ne sait pas s'arrêter en rond.
//
//  4. **LE DISQUE EST MONTÉ À TAILLE CONSTANTE**, révélé par un masque — un
//     `glassEffect` aux bounds vivants reste flou plat pour toujours.
//
//  5. **L'ANNEAU DE CHARGE DEVIENT LE BORD DU DISQUE.** Rien n'apparaît, tout
//     se transforme : c'est la seule façon que l'éclosion ne se lise pas comme
//     un « pop ».
//
//  6. **UNE SEULE HORLOGE.** Charge et éclosion sont des fonctions pures de
//     `(now, état)` sous une `TimelineView` — un `withAnimation` n'interpole
//     que les `animatableData` des MODIFICATEURS, une valeur lue dans un `body`
//     saute à sa cible sur-le-champ.
//
// Bancs : `-couronneLab` (au doigt) · `-couronneRejoue` (l'éclosion en boucle)
// · `-couronneGrille` (les 10 positions du galet, pour prouver que les quatre
// médaillons restent à l'écran).

// MARK: - Les glyphes

/// ⚠️ Jamais un SF Symbol : à cette taille, **c'est le tracé qui fait la
/// marque**. Les quatre glyphes sont dessinés au trait dans un carré unité,
/// dans la même langue que `GlypheMaison` et `GlypheLune` — capuchons ronds,
/// épaisseur constante, aucun remplissage.

/// LA PROGRESSION — une ligne qui monte, avec un creux : une courbe qui monte
/// tout droit est un logo de banque, une courbe qui rechute puis repart est un
/// entraînement.
struct GlypheProgression: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height, x = r.minX, y = r.minY
        func pt(_ a: Double, _ b: Double) -> CGPoint {
            CGPoint(x: x + a * w, y: y + b * h)
        }
        var p = Path()
        p.move(to: pt(0.06, 0.74))
        p.addLine(to: pt(0.34, 0.44))
        p.addLine(to: pt(0.55, 0.60))
        p.addLine(to: pt(0.94, 0.18))
        return p
    }
}

/// LA COLLECTION — deux cartes, dont la seconde n'est qu'ÉBAUCHÉE (son épaule
/// haute et son flanc droit). Deux rectangles complets se lisent comme un
/// tableau ; une carte et l'ombre d'une autre se lisent comme une pile.
struct GlypheCollection: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height, x = r.minX, y = r.minY
        func pt(_ a: Double, _ b: Double) -> CGPoint {
            CGPoint(x: x + a * w, y: y + b * h)
        }
        var p = Path()
        p.addRoundedRect(
            in: CGRect(x: x + 0.06 * w, y: y + 0.26 * h,
                       width: 0.64 * w, height: 0.66 * h),
            cornerSize: CGSize(width: 0.13 * w, height: 0.13 * w),
            style: .continuous)
        // l'ébauche de la carte du dessous
        p.move(to: pt(0.26, 0.14))
        p.addLine(to: pt(0.82, 0.14))
        p.addQuadCurve(to: pt(0.94, 0.26), control: pt(0.94, 0.14))
        p.addLine(to: pt(0.94, 0.72))
        return p
    }
}

/// LES RÉGLAGES — deux rails et leurs curseurs. L'engrenage est le cliché du
/// genre et devient une bouillie sous 20 pt ; deux glissières tiennent au trait
/// fin et disent la même chose.
struct GlypheReglages: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height, x = r.minX, y = r.minY
        func pt(_ a: Double, _ b: Double) -> CGPoint {
            CGPoint(x: x + a * w, y: y + b * h)
        }
        var p = Path()
        p.move(to: pt(0.06, 0.32)); p.addLine(to: pt(0.94, 0.32))
        p.move(to: pt(0.06, 0.70)); p.addLine(to: pt(0.94, 0.70))
        p.addEllipse(in: CGRect(x: x + 0.55 * w, y: y + 0.32 * h - 0.10 * w,
                                width: 0.20 * w, height: 0.20 * w))
        p.addEllipse(in: CGRect(x: x + 0.25 * w, y: y + 0.70 * h - 0.10 * w,
                                width: 0.20 * w, height: 0.20 * w))
        return p
    }
}

// MARK: - Le médaillon

/// LE MÉDAILLON — le bol noir de la page exo, en générique.
///
/// La recette du liseré vient de `FlammeJauge` (l'anneau calé au pixel sur la
/// référence en août) et sa loi est contre-intuitive :
///
/// > **UN LISERÉ N'EST PAS UN ARC CONTINU.** Sur la référence, la chromie
/// > médiane du tour vaut +0,10 — il est NEUTRE — et il fait QUATRE événements
/// > séparés. Un anneau d'intensité constante lit « bordure » ; quatre éclats
/// > séparés lisent « métal poli ».
///
/// Le bol est noir mais PAS plat : il s'éclaircit à peine sous le milieu (la
/// lumière de la page vient d'en bas), et l'ombre portée le DÉCOLLE — sans
/// elle, un rond noir sur du noir n'existe pas.
struct Medaillon<Contenu: View>: View {
    var taille: CGFloat = 34
    @ViewBuilder var contenu: () -> Contenu

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    stops: [
                        .init(color: Color(white: 0.098), location: 0.00),
                        .init(color: Color(white: 0.068), location: 0.42),
                        .init(color: Color(white: 0.034), location: 0.74),
                        .init(color: Color(white: 0.016), location: 1.00),
                    ],
                    center: UnitPoint(x: 0.516, y: 0.585),
                    startRadius: 0, endRadius: taille * 0.85))

            Circle()
                .strokeBorder(AngularGradient(
                    stops: [
                        .init(color: .white.opacity(0.10), location: 0.000),
                        .init(color: .white.opacity(0.46), location: 0.098),
                        .init(color: .white.opacity(0.14), location: 0.180),
                        .init(color: .white.opacity(0.10), location: 0.280),
                        .init(color: .white.opacity(0.62), location: 0.430),
                        .init(color: .white.opacity(0.30), location: 0.500),
                        .init(color: .white.opacity(0.86), location: 0.580),
                        .init(color: .white.opacity(0.20), location: 0.660),
                        .init(color: .white.opacity(0.10), location: 0.790),
                        .init(color: .white.opacity(0.44), location: 0.882),
                        .init(color: .white.opacity(0.10), location: 0.960),
                        .init(color: .white.opacity(0.10), location: 1.000),
                    ],
                    center: .center, angle: .zero),
                    lineWidth: max(taille / 38, 0.8))

            contenu()
        }
        .frame(width: taille, height: taille)
        .shadow(color: .black.opacity(0.55), radius: taille * 0.10, y: 1)
        .shadow(color: .black.opacity(0.35), radius: taille * 0.32, y: 4)
    }
}

/// L'ENCRE DES MÉDAILLONS : blanc en tête, gris au pied. Une lettre pleinement
/// blanche est PLATE ; une lettre qui s'éteint vers le bas a du relief.
extension ShapeStyle where Self == LinearGradient {
    static var encreMedaillon: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .white, location: 0.00),
                .init(color: .white.opacity(0.97), location: 0.42),
                .init(color: Color(white: 0.62), location: 1.00),
            ],
            startPoint: .top, endPoint: .bottom)
    }
}

/// Les quatre sections, et ce que porte chacune.
enum SectionMenu: Int, CaseIterable {
    case profil, progression, collection, reglages

    var titre: String {
        switch self {
        case .profil: return "Profil"
        case .progression: return "Progression"
        case .collection: return "Collection"
        case .reglages: return "Réglages"
        }
    }

    /// ⚠️ LE TRAIT EST FIN, et c'est une mesure : à 0,085 (la valeur de
    /// `GlypheMaison`, calée pour un glyphe de 25 pt) un médaillon de 46 rendait
    /// un trait de 3,9 pt — presque le double de la marque. À 0,036 il tombe à
    /// 1,7 pt : le tracé redevient un dessin au lieu d'un pictogramme gras.
    /// Le monogramme suit : Medium, pas Semibold.
    @ViewBuilder
    func glyphe(_ taille: CGFloat) -> some View {
        let trait = StrokeStyle(lineWidth: taille * 0.030,
                                lineCap: .round, lineJoin: .round)
        switch self {
        case .profil:
            Text("KD")
                .font(.inter(taille * 0.34, .medium))
                .tracking(taille * 0.012)
                .foregroundStyle(.encreMedaillon)
        case .progression:
            GlypheProgression().stroke(.encreMedaillon, style: trait)
                .frame(width: taille * 0.52, height: taille * 0.52)
        case .collection:
            GlypheCollection().stroke(.encreMedaillon, style: trait)
                .frame(width: taille * 0.50, height: taille * 0.50)
        case .reglages:
            GlypheReglages().stroke(.encreMedaillon, style: trait)
                .frame(width: taille * 0.52, height: taille * 0.52)
        }
    }
}

// MARK: - La géométrie

/// OÙ SE POSENT LES QUATRE MÉDAILLONS. La couronne s'oriente vers la PLACE
/// LIBRE : anneau large au milieu de l'écran, quart d'arc dans un coin,
/// demi-arc le long d'un bord — exactement ce que fait AssistiveTouch.
///
/// La méthode est bête et increvable : on balaie les 360°, on garde les angles
/// où un médaillon tient entièrement à l'écran, on prend la plus grande plage
/// CONTINUE, et on y répartit les quatre. Si la plage est trop courte, on
/// resserre le rayon et on recommence. Aucun cas particulier de coin à écrire.
///
/// Propriété heureuse, et elle décide de la place du mot : avec un nombre PAIR
/// d'items répartis au centre de la plage, **aucun item ne tombe sur l'axe** —
/// le milieu de l'arc est toujours libre.
struct CouronneGeo {
    var rayon: CGFloat = 104
    var angles: [Double] = []
    var axe: Double = -.pi / 2
    var centre: CGPoint = .zero

    static let rayonMedaillon: CGFloat = 23
    static let garde: CGFloat = 8

    /// L'écart MINIMAL entre deux médaillons, en points d'arc. C'est lui qui
    /// commande tout le reste : 46 pt de médaillon + 22 pt d'air.
    static let ecartement: CGFloat = 68

    /// ⚠️ LE RAYON SUIT L'ESPACE, il ne le subit pas — verdict « espace
    /// davantage les logos ». L'ancienne version répartissait les quatre sur
    /// TOUTE la plage libre : dans un coin, la plage vaut ~90°, ce qui donne
    /// 22° d'écart, soit 35 pt d'arc à r = 88 — pour des médaillons de 46. Ils
    /// se CHEVAUCHAIENT, d'où l'entassement.
    ///
    /// La loi juste : l'écart est FIXE en points (68), donc l'écart angulaire
    /// vaut 68/r — et c'est le RAYON qui grandit jusqu'à ce que les quatre
    /// tiennent dans la plage. Un coin étroit ne serre plus les médaillons, il
    /// éloigne la couronne.
    static func calcule(centre: CGPoint, taille: CGSize,
                        n: Int = 4) -> CouronneGeo {
        var g = CouronneGeo()
        g.centre = centre
        var repli: (r: CGFloat, debut: Double, span: Double, arc: CGFloat)?
        for r in [CGFloat(106), 122, 138, 154, 170] {
            guard let plage = plageLibre(centre: centre, taille: taille,
                                         r: r) else { continue }
            let (debut, span) = plage
            let arc = CGFloat(span) * r
            if repli == nil || arc > repli!.arc {
                repli = (r, debut, span, arc)
            }
            // Il faut (n-1) écarts entre les centres, plus un demi de chaque
            // côté pour ne pas coller aux bords de la plage.
            guard arc >= ecartement * CGFloat(n) else { continue }
            g.rayon = r
            g.axe = debut + span / 2
            let pas: Double = Double(ecartement / r)
            var a: [Double] = []
            for k in 0..<n {
                let d: Double = (Double(k) - Double(n - 1) / 2) * pas
                a.append(g.axe + d)
            }
            // PROFIL EN TÊTE, toujours du même côté : l'extrémité la plus
            // proche du haut. Sans ça l'ordre bascule selon le coin et on ne
            // retrouve jamais la même section au même endroit.
            if let f = a.first, let l = a.last,
               ecart(l, -.pi / 2) < ecart(f, -.pi / 2) {
                a.reverse()
            }
            g.angles = a
            return g
        }
        // Aucun rayon ne loge les quatre à l'écartement voulu : on prend celui
        // qui offre le plus d'arc et on serre. Mieux vaut un menu serré qu'un
        // menu absent.
        if let f = repli {
            g.rayon = f.r
            g.axe = f.debut + f.span / 2
            let pas: Double = f.span / Double(n)
            var a: [Double] = []
            for k in 0..<n {
                let d: Double = (Double(k) - Double(n - 1) / 2) * pas
                a.append(g.axe + d)
            }
            if let p = a.first, let l = a.last,
               ecart(l, -.pi / 2) < ecart(p, -.pi / 2) {
                a.reverse()
            }
            g.angles = a
            return g
        }
        let haut: Double = -Double.pi / 2 - 0.6
        var secours: [Double] = []
        for k in 0..<n { secours.append(haut + 0.4 * Double(k)) }
        g.angles = secours
        return g
    }

    /// L'écart angulaire absolu, ramené dans [0, π].
    private static func ecart(_ a: Double, _ b: Double) -> Double {
        var d = abs(a - b).truncatingRemainder(dividingBy: 2 * .pi)
        if d > .pi { d = 2 * .pi - d }
        return d
    }

    /// La plus grande plage continue d'angles où un médaillon tient.
    private static func plageLibre(centre: CGPoint, taille: CGSize,
                                   r: CGFloat) -> (Double, Double)? {
        let pas = 120
        var bon = [Bool](repeating: false, count: pas)
        for i in 0..<pas {
            let a = Double(i) / Double(pas) * 2 * .pi
            let p = CGPoint(x: centre.x + r * CGFloat(cos(a)),
                            y: centre.y + r * CGFloat(sin(a)))
            let m = rayonMedaillon + garde
            bon[i] = p.x - m >= 0 && p.x + m <= taille.width
                && p.y - m >= 0 && p.y + m <= taille.height
        }
        guard bon.contains(true) else { return nil }
        if !bon.contains(false) {
            // Tout l'écran est libre : un arc large, mais jamais l'anneau
            // complet — un menu fermé sur lui-même n'a pas de début.
            return (-.pi / 2 - 1.35, 2.70)
        }
        var meilleur = (debut: 0, longueur: 0)
        var i = 0
        // On part d'un trou pour que le balayage circulaire ne coupe pas une
        // plage en deux.
        while bon[i] { i += 1 }
        var courant = -1
        var longueur = 0
        for k in 0..<pas {
            let j = (i + k) % pas
            if bon[j] {
                if courant < 0 { courant = j; longueur = 0 }
                longueur += 1
                if longueur > meilleur.longueur {
                    meilleur = (courant, longueur)
                }
            } else {
                courant = -1
            }
        }
        guard meilleur.longueur > 0 else { return nil }
        let unite = 2 * .pi / Double(pas)
        return (Double(meilleur.debut) * unite,
                Double(meilleur.longueur) * unite)
    }
}

// MARK: - Les halos de la couronne

/// LE VERRE NE MONTRE QUE CE QU'IL RÉFRACTE — posé sur du noir il est à jeun
/// (p95 mesuré à 23, le verdict payé deux fois). Trois foyers chauds sous le
/// disque lui donnent de quoi manger, et la nuit qui les porte rend les
/// médaillons lisibles.
///
/// La rampe s'écrit EN CANAUX : le bleu s'éteint d'abord, puis le vert. Une
/// interpolation entre deux teintes passerait par un orange désaturé — du BRUN.
struct CouronneHalos: View {
    var p: Double
    var centre: CGPoint
    var rayon: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let foyers: [(a: Double, r: Double,
                                 c: (Double, Double, Double),
                                 f: Double, T: Double)] = [
        (-0.9, 1.15, (1.00, 0.62, 0.24), 0.62, 13.0),
        (1.7, 0.86, (1.00, 0.46, 0.14), 0.46, 17.0),
        (0.4, 0.62, (1.00, 0.88, 0.66), 0.34, 23.0),
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            ZStack {
                // LA NUIT, sans bord : elle ne porte rien, elle rend lisible.
                RadialGradient(
                    stops: [
                        .init(color: .black.opacity(0.84), location: 0.00),
                        .init(color: .black.opacity(0.70), location: 0.42),
                        .init(color: .black.opacity(0.30), location: 0.74),
                        .init(color: .black.opacity(0.00), location: 1.00),
                    ],
                    center: .center, startRadius: 0,
                    endRadius: rayon * 2.15)
                    .frame(width: rayon * 4.3, height: rayon * 4.3)

                ZStack {
                    ForEach(0..<Self.foyers.count, id: \.self) { i in
                        foyer(i, t: t)
                    }
                }
                .blendMode(.plusLighter)
                .compositingGroup()
            }
            .position(centre)
        }
        .opacity(p)
        .allowsHitTesting(false)
    }

    /// ⚠️ Les mesures vivent DEHORS, dans un type à part et TYPÉ. Le
    /// vérificateur de types SATURE sur un dégradé dont les couleurs, les
    /// opacités et les rayons sont calculés en une seule expression (payé ici,
    /// build refusé) — et les découper en instructions dans un `@ViewBuilder`
    /// donne « type '()' cannot conform to 'View' ».
    private struct Feu {
        var coeur: Color = .clear
        var queue: Color = .clear
        var rayon: CGFloat = 0
        var dx: CGFloat = 0
        var dy: CGFloat = 0
    }

    private func mesures(_ i: Int, _ t: Double) -> Feu {
        let f = Self.foyers[i]
        let s: Double = reduceMotion ? 1.0
            : 1 + 0.10 * sin(t * 2 * .pi / f.T)
        let force: Double = f.f * s
        var x = Feu()
        x.coeur = Color(red: f.c.0, green: f.c.1, blue: f.c.2)
            .opacity(force)
        x.queue = Color(red: f.c.0, green: f.c.1 * 0.72, blue: f.c.2 * 0.42)
            .opacity(force * 0.38)
        x.rayon = rayon * CGFloat(f.r)
        x.dx = CGFloat(cos(f.a)) * rayon * 0.72
        x.dy = CGFloat(sin(f.a)) * rayon * 0.72
        return x
    }

    @ViewBuilder
    private func foyer(_ i: Int, t: Double) -> some View {
        let x = mesures(i, t)
        RadialGradient(
            stops: [
                .init(color: x.coeur, location: 0.00),
                .init(color: x.queue, location: 0.46),
                .init(color: .clear, location: 1.00),
            ],
            center: .center, startRadius: 0, endRadius: x.rayon)
            .frame(width: x.rayon * 2, height: x.rayon * 2)
            .offset(x: x.dx, y: x.dy)
    }
}

// MARK: - La couronne

/// L'ÉCLOSION. `p` = 0 rien, 1 la couronne posée.
struct CouronneVue: View {
    var p: Double
    var geo: CouronneGeo
    var survol: Int?
    var choisi: Int?
    /// 0 → 1 après le choix : l'élu reste, les autres s'effacent.
    var effacement: Double
    /// 0 → 1 depuis le dernier changement de survol : l'arrivée du mot.
    var arrivee: Double = 1
    /// Le gabarit de la page — le mot doit rester dedans.
    var taille: CGSize = .zero

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var rayonDisque: CGFloat { geo.rayon + 44 }

    var body: some View {
        ZStack {
            CouronneHalos(p: min(p * 2.2, 1), centre: geo.centre,
                          rayon: geo.rayon)

            disque

            ForEach(0..<geo.angles.count, id: \.self) { i in
                medaillon(i)
            }

            mot
        }
        .allowsHitTesting(false)
    }

    // MARK: le verre

    /// ⚠️ TAILLE CONSTANTE, révélé par un MASQUE : un `glassEffect` aux bounds
    /// vivants reste flou plat pour toujours. Et il est démonté sous 1 % —
    /// le verre natif IGNORE `.opacity`.
    @ViewBuilder
    private var disque: some View {
        if p > 0.01 {
            let d = rayonDisque * 2
            ZStack {
                GlassEffectContainer(spacing: 0) {
                    Color.clear
                        .frame(width: d, height: d)
                        .glassEffect(.clear, in: .circle)
                }
                // L'ÉPAISSEUR DE LA VITRE. Un verre sans limbe est une image
                // floue : c'est l'assombrissement juste sous l'arête qui dit
                // qu'il a une TRANCHE. (L'ombre du limbe de l'iPod, en rond.)
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [.black.opacity(0.30),
                                     .black.opacity(0.10)],
                            startPoint: .top, endPoint: .bottom),
                        lineWidth: 9)
                    .blur(radius: 4)
                    .frame(width: d - 2, height: d - 2)
                // LE FIL SPÉCULAIRE — et il n'est PAS un anneau d'intensité
                // constante : quatre événements séparés, neutres, la loi du
                // liseré du médaillon portée au grand cercle. Un anneau
                // régulier lit « bordure » ; quatre éclats lisent « verre ».
                Circle()
                    .strokeBorder(AngularGradient(
                        stops: [
                            .init(color: .white.opacity(0.06), location: 0.00),
                            .init(color: .white.opacity(0.34), location: 0.10),
                            .init(color: .white.opacity(0.08), location: 0.20),
                            .init(color: .white.opacity(0.06), location: 0.30),
                            .init(color: .white.opacity(0.46), location: 0.44),
                            .init(color: .white.opacity(0.18), location: 0.52),
                            .init(color: .white.opacity(0.72), location: 0.60),
                            .init(color: .white.opacity(0.14), location: 0.70),
                            .init(color: .white.opacity(0.06), location: 0.80),
                            .init(color: .white.opacity(0.30), location: 0.89),
                            .init(color: .white.opacity(0.06), location: 1.00),
                        ],
                        center: .center, angle: .zero),
                        lineWidth: 1.1)
                    .frame(width: d, height: d)
            }
            .frame(width: d, height: d)
            .mask {
                Circle()
                    .frame(width: d, height: d)
                    .scaleEffect(0.24 + 0.76 * p)
            }
            .position(geo.centre)
        }
    }

    // MARK: les médaillons

    @ViewBuilder
    private func medaillon(_ i: Int) -> some View {
        let s = SectionMenu.allCases[i]
        let m = mesures(i)
        Medaillon(taille: 46) { s.glyphe(46) }
            .scaleEffect(m.ech)
            .blur(radius: m.flou)
            .opacity(m.alpha)
            .position(x: geo.centre.x + CGFloat(cos(geo.angles[i])) * m.rayon,
                      y: geo.centre.y + CGFloat(sin(geo.angles[i])) * m.rayon)
    }

    /// Les mesures d'un médaillon. ⚠️ Elles vivent DEHORS, dans un type à
    /// part : le vérificateur de types SATURE sur une vue aux mesures
    /// inlinées, et les découper en instructions dans un `@ViewBuilder` donne
    /// « type '()' cannot conform to 'View' ».
    private struct Mesures {
        var rayon: CGFloat = 0
        var ech: CGFloat = 1
        var flou: CGFloat = 0
        var alpha: Double = 1
    }

    private func mesures(_ i: Int) -> Mesures {
        // L'ARRIVÉE EN ÉVENTAIL : chacun part du galet et rejoint sa place,
        // avec 55 ms d'écart. Ils ne se posent pas ensemble — une couronne qui
        // apparaît d'un bloc est une image, pas une éclosion.
        let retard = Double(i) * 0.055 / 0.42
        let x = min(max((p - retard) / (1 - retard), 0), 1)
        let a = 1 - pow(1 - x, 2.6)
        let sous = survol == i ? 1.0 : 0.0
        let voisin = (survol != nil && survol != i) ? 1.0 : 0.0
        let doux: Double = reduceMotion ? 0 : 1
        var m = Mesures()
        m.rayon = geo.rayon * CGFloat(0.22 + 0.78 * a)
        m.ech = CGFloat(0.72 + 0.28 * a + 0.16 * sous - 0.06 * voisin)
        m.flou = CGFloat(7 * (1 - a) + 1.8 * doux * voisin)
        var al = a * (1 - 0.42 * voisin)
        if let c = choisi, c != i { al *= 1 - effacement }
        m.alpha = al
        return m
    }

    // MARK: le mot

    /// LE MOT N'EXISTE QUE SOUS LE DOIGT, et il se pose sur l'AXE de l'arc —
    /// le seul endroit toujours libre (avec un nombre pair d'items, aucun ne
    /// tombe sur l'axe). Il ne suit pas le médaillon : l'œil ne doit pas
    /// courir après lui.
    @ViewBuilder
    private var mot: some View {
        if let s = survol ?? choisi, s < SectionMenu.allCases.count,
           s < geo.angles.count {
            let m = encre(arrivee)
            let a = geo.angles[s]
            let droite = cos(a) >= 0
            // ⚠️ LE MOT VIT À CÔTÉ DE SON MÉDAILLON — verdict « le texte
            // Profil n'est pas à côté de Profil ». Je l'avais posé sur l'axe
            // de l'arc, au motif que l'œil ne doit pas courir après lui ; mais
            // une étiquette qui ne touche pas ce qu'elle nomme ne nomme rien.
            // Il se pose donc DANS LE PROLONGEMENT du rayon, au-delà du
            // médaillon, et il s'écrit du côté où il y a de la place.
            let r = geo.rayon + 23 + 16
            let px = geo.centre.x + CGFloat(cos(a)) * r
            let py = geo.centre.y + CGFloat(sin(a)) * r
            Text(SectionMenu.allCases[s].titre)
                .font(.inter(22, .semibold))
                .tracking(m.track)
                .foregroundStyle(LinearGradient(
                    stops: [
                        .init(color: .white, location: 0.00),
                        .init(color: .white.opacity(0.98), location: 0.46),
                        .init(color: Color(white: 0.80), location: 1.00),
                    ],
                    startPoint: .top, endPoint: .bottom))
                // ⚠️ AUCUNE OMBRE PORTÉE — verdict « c'est pas Apple », et il
                // est juste : Apple ne pose jamais d'ombre derrière du texte.
                // Un titre se détache par la MATIÈRE qui est dessous (ici la
                // nuit du disque, épaissie pour ça), jamais par un halo noir
                // collé à ses lettres. Une ombre sous un mot, c'est le web.
                .blur(radius: m.flou)
                .fixedSize()
                .opacity(p * m.alpha)
                .frame(width: 200, alignment: droite ? .leading : .trailing)
                .offset(x: droite ? 100 : -100, y: m.dy)
                .position(x: min(max(px, 14), max(taille.width - 14, 14)),
                          y: min(max(py, 14), max(taille.height - 14, 14)))
        }
    }

    /// LE MOT NE SE POSE PAS, IL ARRIVE — verdict « les textes sont juste
    /// plaqués ». Un mot qui apparaît à sa taille finale, net et opaque, est
    /// une décalcomanie. Trois grandeurs le font exister :
    ///   • le TRACKING se resserre (+0,050 → +0,012 em) : le mot se DENSIFIE,
    ///     il ne fait pas que devenir visible ;
    ///   • le FLOU tombe de 5 à 0 : c'est une mise au point, pas un fondu.
    ///     Le couple flou + densité fait la profondeur ; le flou seul ne fait
    ///     qu'un brouillard (la loi de la phrase de la home) ;
    ///   • il MONTE de 7 pt : il vient de derrière le verre.
    private struct Encre {
        var track: CGFloat = 0
        var flou: CGFloat = 0
        var alpha: Double = 1
        var dy: CGFloat = 0
    }

    private func encre(_ a: Double) -> Encre {
        let x: Double = min(max(a, 0), 1)
        let e: Double = 1 - pow(1 - x, 2.4)
        var m = Encre()
        m.track = CGFloat(25 * (0.050 - 0.038 * e))
        m.flou = CGFloat(5 * (1 - e))
        m.alpha = e
        m.dy = CGFloat(7 * (1 - e))
        return m
    }
}

// MARK: - L'anneau de charge

/// L'ANNEAU QUI SE REMPLIT, puis **QUI DEVIENT LE BORD DU DISQUE**. C'est le
/// détail qui fait la pièce : rien n'apparaît, tout se transforme. Un menu qui
/// « pop » est un menu ; un menu dont la jauge se détend en arête est un objet.
///
/// La charge est VISIBLE, et c'est ce qui rend l'attente supportable : on ne
/// subit pas 0,55 s, on voit une jauge se remplir.
struct AnneauCharge: View {
    /// 0 → 1, le remplissage.
    var charge: Double
    /// 0 → 1, l'éclosion : l'anneau s'étend et meurt.
    var bloom: Double
    var centre: CGPoint
    var rayonFinal: CGFloat

    private static let rayon: CGFloat = 39

    var body: some View {
        let etale = 1 + (rayonFinal / Self.rayon - 1) * min(bloom / 0.55, 1)
        let vie = charge > 0.001 || bloom > 0.001
        ZStack {
            if vie {
                Circle()
                    .trim(from: 0, to: max(charge, bloom > 0 ? 1 : 0))
                    .stroke(LinearGradient(
                        colors: [Color(red: 1.00, green: 0.93, blue: 0.82),
                                 Color(red: 1.00, green: 0.66, blue: 0.30)],
                        startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: Self.rayon * 2, height: Self.rayon * 2)
                    .rotationEffect(.degrees(-90))
                    .scaleEffect(etale)
                    .opacity((0.35 + 0.65 * charge)
                             * (1 - min(bloom / 0.62, 1)))
                    .shadow(color: Color(red: 1.0, green: 0.72, blue: 0.36)
                        .opacity(0.55 * charge), radius: 6)
                    .position(centre)
            }
        }
        .allowsHitTesting(false)
    }
}
