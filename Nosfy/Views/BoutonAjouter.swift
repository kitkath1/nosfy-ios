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
    static let sans = EffetsSeanceBanc.sans
        || ProcessInfo.processInfo.arguments.contains("-sansBordParticules")
}

struct BoutonAjouter: View {
    let texte: String
    let enGeste: Bool
    /// ⚠️ L'INVITATION (24-09) — un compteur, pas un booléen. Quand il
    /// change, le bouton joue SON onde, celle du tap : c'est l'app qui
    /// montre du doigt l'action suivante, avec le même geste que celui
    /// qu'elle attend. Un booléen ne rejouerait pas deux invitations
    /// d'affilée (deux exercices terminés dans la même séance).
    var invite: Int = 0
    let action: () -> Void

    @State private var appuye = false
    @State private var scintille = false
    /// Le tour de l'onde : il change à chaque tap, ce qui REMONTE la vue et
    /// relance son animation depuis zéro. Un booléen ne rejouerait pas deux
    /// taps rapprochés.
    @State private var tour = 0
    /// L'éclat du bord au moment du tap — il part à 1 et retombe.
    @State private var eclat: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// ⚠️ LES COTES SONT CELLES DU PRIMAIRE, à l'identique — c'est ce que
    /// « le même thème » veut dire. Elles sont LUES chez lui
    /// (`BoutonPrimaire.hauteur`) : le jour où il change, celui-ci suit.
    private static let forme = Capsule()
    private static let lumiere = Color(red: 0.90, green: 0.90, blue: 0.95)
    /// Les trois nappes de particules : opacité au repos, et au sommet.
    private static let nappes: [(bas: Double, haut: Double)] =
        [(0.30, 0.95), (0.22, 0.80), (0.34, 0.70)]

    /// L'appui, 0 → 1. Le primaire l'appelle `p` : même nom, même rôle.
    private var p: Double { appuye ? 1 : 0 }

    var body: some View {
        ZStack {
            plaque
            halos
            mot
        }
        .frame(height: BoutonPrimaire.hauteur)
        .frame(maxWidth: .infinity)
        .clipShape(Self.forme)
        // LE LISERÉ — le même que le primaire, EN POINTILLÉ. C'est la seule
        // différence entre les deux boutons, et c'est elle qui dit
        // « celui-ci ajoute » : un trait continu ferme une forme, un
        // pointillé laisse une place à prendre.
        .overlay { liserePointille }
        // Les cheveux blancs dans le bord (23-09) — ils suivent désormais
        // la capsule, pas l'ancien coin de 14.
        .overlay { bord }
        // ⚠️ L'ONDE DU TAP (24-09 : « un effet wahou au clic »). Deux
        // anneaux qui NAISSENT sur le contour et s'en éloignent — la même
        // langue que le pulsar du point de séance. La lumière a une cause
        // (le doigt) et un bord (le contour) : rien ne traverse le bouton.
        .overlay {
            if tour > 0 { OndeTap().id(tour).allowsHitTesting(false) }
        }
        .contentShape(Self.forme)
        // L'APPUI A DU POIDS — le même tassement que le primaire.
        .scaleEffect(appuye ? 0.975 : 1)
        .animation(.spring(response: 0.30, dampingFraction: 0.72), value: appuye)
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
                    wahou()
                    action()
                }
        )
        .opacity(enGeste ? 0.55 : 1)
        // ⚠️ RÉ-ARMÉ ICI, DANS LA FEUILLE. Un `repeatForever` posé par un
        // parent se fait avaler dès que ce parent est ré-évalué (piège payé
        // sur `PageCard.swift`), et le bord s'éteindrait sans rien dire.
        .task(id: anime) { scintille = anime }
        .onChange(of: invite) { _, _ in wahou() }
    }

    private var anime: Bool { !BordBanc.sans && !reduceMotion && !enGeste }

    /// L'onde part, et le bord flambe une demi-seconde. ⚠️ Deux temps dans
    /// le MÊME tour de boucle : la valeur est posée à 1 sans animation,
    /// puis animée vers 0 — sinon elle partirait de là où elle était et
    /// deux taps rapprochés ne donneraient qu'un demi-éclat.
    private func wahou() {
        guard !reduceMotion else { return }
        tour &+= 1
        var tr = Transaction(); tr.disablesAnimations = true
        withTransaction(tr) { eclat = 1 }
        withAnimation(.easeOut(duration: 0.55)) { eclat = 0 }
    }

    // MARK: Le thème du primaire, repris à l'identique

    /// NOIR : la plaque EST le noir de la page ; seuls le liseré et la
    /// nappe du bas disent le bouton.
    private var plaque: some View {
        Self.forme.fill(LinearGradient(
            colors: [Color(white: 0.016), Color(white: 0.004)],
            startPoint: .top, endPoint: .bottom))
    }

    /// LA LUMIÈRE VIENT D'EN DESSOUS — deux nappes ancrées sous le bord
    /// bas, qui montent et s'allument sous le doigt. La cause est le
    /// pouce, jamais une horloge.
    private var halos: some View {
        ZStack {
            Self.forme.fill(EllipticalGradient(
                stops: [
                    .init(color: Self.lumiere.opacity(0.125 + 0.25 * p), location: 0),
                    .init(color: Self.lumiere.opacity(0.045 + 0.085 * p), location: 0.40),
                    .init(color: Self.lumiere.opacity(0.016), location: 0.78),
                    .init(color: .clear, location: 1)
                ],
                center: UnitPoint(x: 0.5, y: 1.10 - 0.18 * p),
                startRadiusFraction: 0, endRadiusFraction: 1.15))
            Self.forme.fill(EllipticalGradient(
                colors: [Self.lumiere.opacity(0.065 + 0.18 * p), .clear],
                center: UnitPoint(x: 0.5, y: 1.02 - 0.12 * p),
                startRadiusFraction: 0, endRadiusFraction: 0.60))
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.70), value: p)
    }

    /// Le mot, au corps du primaire, le « + » dans sa gouttière à gauche —
    /// le texte reste CENTRÉ, comme chez lui.
    private var mot: some View {
        Text(texte)
            .font(.inter(18, .semibold))
            .tracking(-0.2)
            .foregroundStyle(.white.opacity(0.96))
            .shadow(color: .white.opacity(0.16 + 0.30 * p), radius: 7)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 52)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .leading) {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.leading, 22)
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.70), value: p)
    }

    /// ⚠️⚠️ LE POINTILLÉ (24-09 : « quasiment le même thème que le bouton
    /// primaire, mais en pointillé »). Le dégradé est celui du primaire —
    /// presque rien en haut, la lumière le prend par le bas — posé sur un
    /// trait DISCONTINU. Un point d'épaisseur : « la brillance vient de la
    /// blancheur, jamais de l'épaisseur ».
    private var liserePointille: some View {
        Self.forme.strokeBorder(
            LinearGradient(
                colors: [.white.opacity(0.055 + 0.10 * eclat),
                         .white.opacity(0.17 + 0.24 * p + 0.30 * eclat)],
                startPoint: .top, endPoint: .bottom),
            style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [5, 5]))
            .animation(.spring(response: 0.28, dampingFraction: 0.70), value: p)
    }

    @ViewBuilder private var bord: some View {
        if BordBanc.sans {
            EmptyView()          // le pointillé suffit : il est déjà là
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
            // cause que la lumière du bas, au même instant.
            .brightness(appuye ? 0.22 : 0)
            .animation(.easeOut(duration: appuye ? 0.10 : 0.28), value: appuye)
            // ET IL FLAMBE AU RELÂCHÉ, une demi-seconde.
            .brightness(0.45 * eclat)
            .allowsHitTesting(false)
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
            // ⚠️ LE RAYON SUIT LA FORME (24-09). Le bouton est passé en
            // CAPSULE : un contour dessiné avec un coin de 14 aurait semé
            // les points à côté du bord, et on aurait vu deux traits.
            let r: CGFloat = min(taille.height, taille.width) / 2
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

// MARK: - L'onde du tap

/// ⚠️ ELLE SE REMONTE À CHAQUE TAP (`.id(tour)`), et c'est le seul moyen
/// d'être sûr qu'elle rejoue : une animation relancée sur la même vue
/// repart de l'état où elle en était, donc un double tap rapide ne
/// donnerait qu'une demi-onde.
///
/// Deux anneaux, le second en retard d'un tiers : on voit une onde qui
/// part, pas un clignotement. Ils s'éloignent de 6 % — assez pour se
/// détacher du bouton, jamais assez pour cogner ses voisins.
private struct OndeTap: View {
    @State private var parti = false

    private static let forme = Capsule()

    var body: some View {
        ZStack {
            anneau(0)
            anneau(0.13)
        }
        .onAppear { parti = true }
    }

    private func anneau(_ retard: Double) -> some View {
        Self.forme
            // Un point d'épaisseur : un cheveu de lumière, jamais un néon.
            .strokeBorder(.white, lineWidth: 1)
            .scaleEffect(parti ? 1.06 : 1.0)
            .opacity(parti ? 0 : 0.85)
            .animation(.easeOut(duration: 0.55).delay(retard), value: parti)
    }
}
