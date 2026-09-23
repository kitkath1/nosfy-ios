import SwiftUI

// MARK: - LE POINT REC (23-09) — l'onglet Exercices pendant une séance
//
// « Pas de pastille, juste une icône ronde qui pulse, comme un REC — avec un
//   effet diamant un peu à l'intérieur. » (Kathryn, 23-09.)
//
// Pendant une séance, le coureur de l'onglet Exercices disparaît sous un
// POINT : un brillant noir de 26 pt — couronne de huit facettes, table
// étoilée, arêtes d'un demi-point en argent — avec au centre une braise
// rouge qui respire. Le tap ne change pas : c'est l'onglet DESSOUS qui
// répond, et `ongletChoisi` remonte déjà le lecteur depuis le 22-09.
//
// ⚠️⚠️ POURQUOI IL EST POSÉ PAR-DESSUS LA BARRE, ET PAS DANS L'ONGLET.
// Trois essais mesurés le 23-09, et c'est la seule route qui marche :
//   · une `View` maison à `@State` dans le `label:` d'un `Tab` n'est
//     JAMAIS ré-évaluée quand la séance s'ouvre — l'onglet gardait son
//     coureur alors que l'île était déjà rouge ;
//   · un `if/else` dans le `label:` change le TYPE de la vue
//     (`_ConditionalContent`) et la barre garde la branche prise au montage ;
//   · et surtout : le MÊME symbole passe par `Image(systemName:)` et **pas**
//     par `Image(uiImage:)`. Une icône d'onglet n'accepte qu'un symbole ou
//     un asset — jamais une image fabriquée à l'exécution.
// En surimpression, le point est une vraie vue. C'est ce qui lui permet de
// RESPIRER, ce qu'un item d'onglet ne fera jamais.
//
// ⚠️ ET IL NE REDESSINE RIEN POUR ANIMER. La pierre est dessinée UNE FOIS
// et aplatie ; seules l'opacité et l'échelle du cœur et du halo sont
// animées. Loi mesurée sur son iPhone le 05-09 : redessiner pour animer
// coûte 33 à 38 % de processeur, animer une valeur en coûte 4 à 18 %.
//
// Son barreau : `-sansRec` (l'onglet garde son coureur, rien n'est posé).

enum RecBanc {
    static let sans = ProcessInfo.processInfo.arguments.contains("-sansRec")
}

// MARK: - Le point, posé sur la barre

struct PointRecSurBarre: View {
    let enSeance: Bool

    /// Le côté du point. 26 pt : un témoin d'enregistrement, pas une pastille.
    private static let cote: CGFloat = 26
    /// ⚠️ MESURÉ, PAS DEVINÉ, et mesuré DEUX FOIS. Le centre des glyphes
    /// d'onglet est à 2436 px du haut sur la dalle de l'iPhone 15
    /// (1179 × 2556), soit 40 pt du bas de l'ÉCRAN. Mais cette
    /// surimpression est posée à la RACINE, dont le bas s'arrête à la zone
    /// sûre : 40 pt d'écran font 6 pt ici. Si la barre change, on la
    /// remesure — on ne la devine pas.
    private static let hauteur: CGFloat = 6

    @State private var respire = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var actif: Bool { enSeance && !RecBanc.sans }

    var body: some View {
        Group {
            if actif {
                ZStack {
                    // ⚠️ LE DISQUE QUI COUVRE LE COUREUR. L'onglet dessous
                    // existe toujours — c'est lui qui prend le doigt — mais
                    // on ne doit plus le voir. La barre est noire : un
                    // disque noir un peu plus large suffit, sans bord.
                    Circle()
                        .fill(.black)
                        .frame(width: Self.cote + 14, height: Self.cote + 14)
                    Diamant()
                        .frame(width: Self.cote, height: Self.cote)
                    Coeur(respire: respire && !reduceMotion)
                        .frame(width: Self.cote, height: Self.cote)
                }
                .frame(height: Self.cote)
                .padding(.bottom, Self.hauteur - Self.cote / 2)
                // ⚠️ IL NE PREND JAMAIS LE DOIGT. Le tap doit descendre
                // jusqu'à l'onglet natif, sinon on casse la navigation pour
                // un ornement.
                .allowsHitTesting(false)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: actif)
        // ⚠️ RÉ-ARMÉ DANS LA FEUILLE — un `repeatForever` posé par un parent
        // se fait avaler dès que ce parent est ré-évalué (piège payé sur
        // `PageCard.swift`), et la respiration s'arrêterait sans rien dire.
        // `task(id:)` l'éteint aussi dès que la séance se ferme.
        .task(id: actif) { respire = actif }
    }
}

// MARK: - Le cœur de braise, la seule chose qui bouge

/// ⚠️ SÉPARÉ DE LA PIERRE EXPRÈS. Si le cœur vivait dans le `Canvas`, faire
/// respirer la braise obligerait à REDESSINER tout le brillant à chaque
/// image. Ici la pierre est figée et seul ce petit disque s'anime —
/// opacité et échelle, deux valeurs que le système interpole seul.
private struct Coeur: View {
    let respire: Bool

    var body: some View {
        GeometryReader { g in
            let d = min(g.size.width, g.size.height)
            let r = d * 0.44 * 0.36
            ZStack {
                // le halo : il reste dans la pierre, jamais un projecteur
                Circle()
                    .fill(RadialGradient(
                        colors: [Color(red: 1.0, green: 0.30, blue: 0.10).opacity(0.55),
                                 .clear],
                        center: .center, startRadius: 0, endRadius: d * 0.46))
                    .frame(width: d, height: d)
                    .opacity(respire ? 0.95 : 0.30)
                Circle()
                    .fill(RadialGradient(
                        colors: [Color(red: 1.00, green: 0.24, blue: 0.10),
                                 Color(red: 0.42, green: 0.05, blue: 0.02)],
                        center: .center, startRadius: 0, endRadius: r))
                    .frame(width: r * 2, height: r * 2)
                    .opacity(respire ? 1.0 : 0.52)
                    .scaleEffect(respire ? 1.0 : 0.80)
            }
            .frame(width: g.size.width, height: g.size.height)
            .animation(respire
                ? .easeInOut(duration: 1.25).repeatForever(autoreverses: true)
                : .easeOut(duration: 0.2),
                value: respire)
        }
    }
}

// MARK: - Le brillant

/// ⚠️ UNE SOURCE DE LUMIÈRE FIXE, en haut à gauche. Chaque facette brille
/// selon SON ORIENTATION — jamais parce qu'une bande lui passe dessus.
/// C'est ce qui fait la pierre, et c'est aussi ce qui interdit le balayage.
private struct Diamant: View {
    /// L'éclat de la pierre est CONSTANT : c'est le cœur qui respire, pas
    /// elle. Une pierre qui clignote, ce serait une lampe.
    private static let eclat = 0.62
    private static let source = -125.0 * .pi / 180.0
    private static let facettes = 8

    var body: some View {
        Canvas { ctx, taille in
            let c = CGPoint(x: taille.width / 2, y: taille.height / 2)
            let R = min(taille.width, taille.height) / 2 - 0.5
            let Rt = R * 0.44
            let k = 0.32 + 0.68 * Self.eclat

            // Le corps : une braise qui meurt, presque noire.
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - R, y: c.y - R,
                                            width: R * 2, height: R * 2)),
                     with: .radialGradient(
                        Gradient(colors: [Self.encre(0.22, k), Self.encre(0.04, k)]),
                        center: c, startRadius: 0, endRadius: R))

            // LA COURONNE — une ou deux facettes seulement attrapent la
            // lumière. Les remplir toutes donnait du plastique (23-09).
            for i in 0..<Self.facettes {
                let a0 = Double(i) / Double(Self.facettes) * 2 * .pi - .pi / 8
                let a1 = a0 + 2 * .pi / Double(Self.facettes)
                let g = pow(max(0, cos((a0 + a1) / 2 - Self.source)), 6.0)
                var p = Path()
                p.move(to: Self.pt(c, R, a0))
                p.addLine(to: Self.pt(c, R, a1))
                p.addLine(to: Self.pt(c, Rt, a1))
                p.addLine(to: Self.pt(c, Rt, a0))
                p.closeSubpath()
                ctx.fill(p, with: .color(Self.argent(0.05 + 0.34 * g, k)))
            }

            // LA TABLE, sombre, étoilée de ses propres arêtes — jamais un aplat.
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - Rt, y: c.y - Rt,
                                            width: Rt * 2, height: Rt * 2)),
                     with: .color(Self.encre(0.09, k)))
            for i in 0..<Self.facettes {
                let a = Double(i) / Double(Self.facettes) * 2 * .pi
                let f = pow(max(0, cos(a - Self.source)), 2.0)
                var p = Path(); p.move(to: c); p.addLine(to: Self.pt(c, Rt, a))
                ctx.stroke(p, with: .color(Self.argent(0.12 + 0.47 * f, k)),
                           lineWidth: 0.5)
            }
            // LES ARÊTES — un demi-point, donc UN pixel sur sa dalle. Ce
            // sont elles qui portent la brillance : jamais l'épaisseur.
            for i in 0..<Self.facettes {
                let a = Double(i) / Double(Self.facettes) * 2 * .pi - .pi / 8
                let f = pow(max(0, cos(a - Self.source)), 1.5)
                var p = Path()
                p.move(to: Self.pt(c, Rt, a)); p.addLine(to: Self.pt(c, R, a))
                ctx.stroke(p, with: .color(Self.argent(0.20 + 0.75 * f, k)),
                           lineWidth: 0.5)
            }
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - Rt, y: c.y - Rt,
                                              width: Rt * 2, height: Rt * 2)),
                       with: .color(Self.argent(0.47, k)), lineWidth: 0.5)
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - R, y: c.y - R,
                                              width: R * 2, height: R * 2)),
                       with: .color(Self.argent(0.36, k)), lineWidth: 0.5)

            // L'ÉCLAT : un point, jamais plus large qu'un point.
            let s = Self.pt(c, Rt * 0.46, Self.source)
            let sr = 0.95
            ctx.fill(Path(ellipseIn: CGRect(x: s.x - sr, y: s.y - sr,
                                            width: sr * 2, height: sr * 2)),
                     with: .color(.white.opacity(0.92)))
        }
        // ⚠️ APLATI UNE FOIS. Rien ici ne dépend du temps : la pierre est
        // rastérisée et ne sera plus jamais recalculée.
        .drawingGroup()
    }

    private static func pt(_ c: CGPoint, _ r: Double, _ a: Double) -> CGPoint {
        CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
    }
    private static func encre(_ v: Double, _ k: Double) -> Color {
        Color(red: v * k, green: v * k * 0.30, blue: v * k * 0.18)
    }
    private static func argent(_ v: Double, _ k: Double) -> Color {
        Color(red: v * k, green: v * k * 0.96, blue: v * k * 0.92)
    }
}
