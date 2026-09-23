import SwiftUI

// MARK: - LE BOUTON « AJOUTER UN EXERCICE » (23-09)
//
// « Anime davantage le bouton pour ajouter un exercice, avec effet de
//   particules blanches très fines dans ses bordures, like 0,4 px — et fond
//   qui devient plus clair au tap — + haptique. » (Kathryn, 23-09.)
//
// ⚠️ LES PARTICULES SONT CUITES, PAS REDESSINÉES. Trois nappes de points
// sont dessinées UNE FOIS chacune, aplaties, puis on ne fait plus varier
// que leur OPACITÉ. C'est la loi mesurée sur son iPhone le 05-09 :
// redessiner pour animer coûte 33 à 38 % de processeur, animer une valeur
// en coûte 4 à 18 %. Un bouton reste à l'écran toute la séance : une
// `TimelineView` ici serait le pire endroit du dépôt.
//
// ⚠️ ET CE N'EST PAS UN BALAYAGE. Les trois nappes ne glissent pas : elles
// s'allument et s'éteignent SUR PLACE, décalées dans le temps. Chaque point
// scintille là où il est né — aucune bande ne parcourt le bord.
//
// Son barreau : `-sansBordParticules` (le bord redevient un trait sobre).

enum BordBanc {
    static let sans = ProcessInfo.processInfo.arguments
        .contains("-sansBordParticules")
}

struct BoutonAjouter: View {
    let texte: String
    let enGeste: Bool
    let action: () -> Void

    @State private var appuye = false
    @State private var scintille = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let forme = RoundedRectangle(cornerRadius: 14, style: .continuous)
    private static let teinte = Color(red: 1.0, green: 0.78, blue: 0.58)
    /// Les trois nappes : leur opacité au repos et au sommet de leur cycle.
    private static let nappes: [(bas: Double, haut: Double)] =
        [(0.30, 0.95), (0.22, 0.80), (0.34, 0.70)]

    var body: some View {
        HStack(spacing: 8) {
            Text("+").font(.inter(15, .medium))
            Text(texte).font(.inter(13.5, .semibold))
        }
        .foregroundStyle(Self.teinte)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background {
            // ⚠️ LE FOND MONTE SOUS LE DOIGT, ET SEULEMENT SOUS LE DOIGT.
            // Il redescend au relâché : la cause reste le pouce, jamais une
            // horloge. Une couleur est animable — rien n'est refabriqué.
            Self.forme
                .fill(Color(white: appuye ? 0.135 : 0.055))
                .animation(.easeOut(duration: appuye ? 0.10 : 0.28), value: appuye)
        }
        .background { bord }
        .contentShape(Self.forme)
        .highPriorityGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !appuye else { return }
                    appuye = true
                    Haptique.leger()
                }
                .onEnded { g in
                    appuye = false
                    // ⚠️ LE DOIGT DOIT ÊTRE RESTÉ SUR LE BOUTON. Un
                    // `DragGesture` répond partout une fois commencé : sans
                    // ce test, on ajouterait un exercice en glissant le
                    // doigt dehors — exactement ce qu'un bouton ne fait pas.
                    let d = g.translation
                    guard abs(d.width) < 44, abs(d.height) < 44 else { return }
                    Haptique.moyen()
                    action()
                }
        )
        .opacity(enGeste ? 0.55 : 1)
        // ⚠️ RÉ-ARMÉ ICI, DANS LA FEUILLE. Un `repeatForever` posé par un
        // parent se fait avaler dès que ce parent est ré-évalué (piège payé
        // sur `PageCard.swift`), et le bord s'éteindrait sans rien dire.
        .task(id: anime) { scintille = anime }
    }

    private var anime: Bool { !BordBanc.sans && !reduceMotion && !enGeste }

    @ViewBuilder private var bord: some View {
        if BordBanc.sans {
            Self.forme.strokeBorder(Self.teinte.opacity(0.42),
                                    style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
        } else {
            ZStack {
                ForEach(Array(Self.nappes.enumerated()), id: \.offset) { i, n in
                    NappeBord(graine: UInt64(i) &* 9781 &+ 17)
                        .opacity(scintille ? n.haut : n.bas)
                        .animation(anime
                            ? .easeInOut(duration: 1.5 + Double(i) * 0.4)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.5)
                            : nil,
                            value: scintille)
                }
            }
            // Sous le doigt, le bord se réveille franchement — la même
            // cause que le fond, au même instant.
            .brightness(appuye ? 0.22 : 0)
            .animation(.easeOut(duration: appuye ? 0.10 : 0.28), value: appuye)
        }
    }
}

// MARK: - Une nappe de points

/// ⚠️ DESSINÉE UNE FOIS, PUIS APLATIE. Son contenu ne dépend QUE de sa
/// graine : aucune horloge n'entre ici, donc `drawingGroup` la rastérise
/// une fois pour toutes et l'animation d'opacité ne la retouche jamais.
private struct NappeBord: View {
    let graine: UInt64

    /// Les points par point de contour. ⚠️ C'est la DENSITÉ qui fait la
    /// lumière, jamais la taille ni l'opacité de chacun — la leçon payée
    /// le même jour sur l'ouverture (60 000 puis 320 000 points : de la
    /// poussière deux fois).
    private static let parPoint: Int = 3

    var body: some View {
        Canvas { ctx, taille in
            let r: CGFloat = 14
            let chemin = Self.contour(taille, r)
            guard chemin.count > 1 else { return }
            var h = graine &+ 0x9E3779B97F4A7C15
            func hasard() -> Double {
                h ^= h >> 30; h = h &* 0xBF58476D1CE4E5B9
                h ^= h >> 27; h = h &* 0x94D049BB133111EB
                h ^= h >> 31
                return Double(h & 0xFFFFFF) / Double(0x1000000)
            }
            let n = chemin.count * Self.parPoint
            for _ in 0..<n {
                let p = chemin[Int(hasard() * Double(chemin.count)) % chemin.count]
                // ⚠️ SOUS LE PIXEL. Le point fait 0,4 pt de côté et se pose
                // à une position FRACTIONNAIRE : l'anticrénelage le répartit
                // sur ses voisins, et ce dépôt partiel est exactement ce
                // qu'elle appelle « très fine ». Un point plein donnerait
                // du poivre.
                let dx = (hasard() - 0.5) * 2.1
                let dy = (hasard() - 0.5) * 2.1
                // La plupart sont sombres, quelques-unes crèvent le blanc :
                // la brillance vient de la blancheur, jamais de l'épaisseur.
                let e = pow(hasard(), 2.2)
                let c: CGFloat = 0.4
                ctx.fill(Path(ellipseIn: CGRect(x: p.x + dx - c / 2,
                                                y: p.y + dy - c / 2,
                                                width: c, height: c)),
                         with: .color(.white.opacity(0.10 + 0.90 * e)))
            }
        }
        .drawingGroup()
        .allowsHitTesting(false)
    }

    /// Le contour, échantillonné À PAS CONSTANT. ⚠️ Découper en quatre
    /// fractions égales entasse les points dans les coins, et le bord
    /// gauche devient deux fois plus épais que le haut (vu le 23-09 sur la
    /// maquette) : de l'épaisseur, donc « fake ».
    private static func contour(_ t: CGSize, _ r: CGFloat) -> [CGPoint] {
        var P: [CGPoint] = []
        let (w, h) = (t.width, t.height)
        guard w > 2 * r + 1, h > 2 * r + 1 else { return P }
        func seg(_ a: CGPoint, _ b: CGPoint) {
            let L = hypot(b.x - a.x, b.y - a.y)
            let n = max(1, Int(L))
            for i in 0..<n {
                let u = CGFloat(i) / CGFloat(n)
                P.append(CGPoint(x: a.x + (b.x - a.x) * u, y: a.y + (b.y - a.y) * u))
            }
        }
        func arc(_ cx: CGFloat, _ cy: CGFloat, _ a0: Double) {
            let n = max(1, Int(r * .pi / 2))
            for i in 0..<n {
                let a = (a0 + 90 * Double(i) / Double(n)) * .pi / 180
                P.append(CGPoint(x: cx + r * CGFloat(cos(a)), y: cy + r * CGFloat(sin(a))))
            }
        }
        seg(CGPoint(x: r, y: 0), CGPoint(x: w - r, y: 0));      arc(w - r, r, -90)
        seg(CGPoint(x: w, y: r), CGPoint(x: w, y: h - r));      arc(w - r, h - r, 0)
        seg(CGPoint(x: w - r, y: h), CGPoint(x: r, y: h));      arc(r, h - r, 90)
        seg(CGPoint(x: 0, y: h - r), CGPoint(x: 0, y: r));      arc(r, r, 180)
        return P
    }
}
