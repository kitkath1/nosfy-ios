import SwiftUI

// ════════════════════════════════════════════════════════════════════════
// LA VISITE GUIDÉE DE LA HOME — v2 « la lampe et la carte » (14-09, nuit)
// tools/porte/PLAN-VISITE-PREMIUM.md — le plan qu'on code, section par section.
//
// Quatre temps sur la Home (galets → progression → profil → pièces), UN objet net à la
// fois. La page entière RECULE (0,965, WoopApp), un voile de cinq couches tombe dessus
// (blur, blur de blur, noir, la FLAQUE de lumière centrée sur l'objet, la vignette),
// percé d'UNE fenêtre à la forme de l'objet (coins de la card, capsule du glyphe, cercle
// de la pièce) qui s'ouvre puis GLISSE ET SE MORPHE d'un objet au suivant ; l'objet
// AVANCE (1,04, `visiteAncre`) ; une carte de VERRE ancrée à lui porte l'alternance de la
// Home (la claire mot par mot, la sourde en fondu), quatre points et « Suivant › » ;
// « Passer » en haut à droite ; le doigt TRAVERSE la fenêtre.
//
// RIEN NE SE REDESSINE POUR ANIMER (la loi du 05-09) : le voile est une vue `Animatable`
// sur les six nombres de sa fenêtre — le système interpole, le corps n'est ré-évalué que
// pendant un vol (0,6 s) ; le reste = opacités, une échelle, des springs. Aucune horloge.
// Les rayons de flou ne bougent jamais. Le voile est DÉMONTÉ à la fin.
//
// Bancs / barreaux : `-visiteHome [1-4]` (PremiereArrivee) · `-sansVisite` (rien) ·
// `-visiteNoir` (la carte en matière noire) · `-visiteFlou1` (un seul flou).
// ════════════════════════════════════════════════════════════════════════

// MARK: - Les ancres

/// Les cadres des quatre objets, publiés de la Home et de la nav, lus à la racine.
struct VisiteAncreKey: PreferenceKey {
    static let defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>],
                       nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

/// Le modificateur d'un objet de la visite : il publie son cadre, il AVANCE quand la
/// visite le met en avant, et il TERMINE la visite quand le doigt le traverse — l'objet
/// fait alors ce qu'il fait toujours (la route, le coffre, l'onglet) : le tuto n'est
/// jamais un mur.
private struct VisiteAncre: ViewModifier {
    let nom: String
    var depart = DepartEtat.shared

    func body(content: Content) -> some View {
        let focus = depart.visiteOuverte && depart.visiteFocus == nom
        content
            .scaleEffect(focus ? VisiteHome.avance : 1)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: focus)
            .simultaneousGesture(TapGesture().onEnded {
                if depart.visiteOuverte { PremiereArrivee.finirVisite() }
            })
            .anchorPreference(key: VisiteAncreKey.self, value: .bounds) { [nom: $0] }
    }
}

extension View {
    /// Publie le cadre de cette vue sous ce nom — pour la visite de la Home.
    func visiteAncre(_ nom: String) -> some View {
        modifier(VisiteAncre(nom: nom))
    }
}

// MARK: - Les quatre temps

struct VisiteTemps: Identifiable {
    let id: Int
    let ancre: String
    /// La forme de la fenêtre : `nil` = les coins de la card (26 + 10) ; `.capsule` ;
    /// `.cercle`.
    let forme: Forme
    let clairFr: String, clairEn: String
    let sourdFr: String, sourdEn: String
    var claire: String { L(clairFr, clairEn) }
    var sourde: String { L(sourdFr, sourdEn) }

    enum Forme { case card, capsule, cercle }

    /// Les textes (sport, clair / sourd, deux langues — PLAN § 2 i).
    static let tous: [VisiteTemps] = [
        VisiteTemps(id: 0, ancre: "visite-galets", forme: .card,
                    clairFr: "Commence ton entraînement.", clairEn: "Start your workout.",
                    sourdFr: "Ton parcours, séance après séance.",
                    sourdEn: "Your path, workout after workout."),
        VisiteTemps(id: 1, ancre: "visite-progression", forme: .card,
                    clairFr: "Tes progrès.", clairEn: "Your progress.",
                    sourdFr: "Chaque séance compte.", sourdEn: "Every workout counts."),
        VisiteTemps(id: 2, ancre: "visite-profil", forme: .capsule,
                    clairFr: "Ton profil.", clairEn: "Your profile.",
                    sourdFr: "Tes Boosters et ta collection.",
                    sourdEn: "Your Boosters and your collection."),
        VisiteTemps(id: 3, ancre: "visite-pieces", forme: .cercle,
                    clairFr: "Tes pièces.", clairEn: "Your coins.",
                    sourdFr: "Gagne-les en t'entraînant. Ouvre des Boosters.",
                    sourdEn: "Earn them by training. Open Boosters."),
    ]
}

// MARK: - La fenêtre (la forme percée)

/// Le rectangle plein écran percé d'UNE fenêtre arrondie — ses nombres arrivent DÉJÀ
/// interpolés (par `VoileVisite`, la vue Animatable) : cette forme ne s'anime pas
/// elle-même.
private struct Fenetre: Shape {
    var rect: CGRect
    var rayon: CGFloat
    var ouverture: CGFloat

    var trou: CGRect? {
        guard ouverture > 0.01, rect.width > 1, rect.height > 1 else { return nil }
        return rect.insetBy(dx: rect.width / 2 * (1 - ouverture),
                            dy: rect.height / 2 * (1 - ouverture))
    }

    func path(in r: CGRect) -> Path {
        var p = Path()
        p.addRect(r)
        if let t = trou {
            let ray = min(rayon, t.width / 2, t.height / 2)
            p.addRoundedRect(in: t, cornerSize: CGSize(width: ray, height: ray),
                             style: .continuous)
        }
        return p
    }
}

// MARK: - Le voile — la vue Animatable (cinq couches + la fenêtre)

/// Les six nombres de la fenêtre (x, y, l, h, rayon, ouverture) sont animables : sous
/// `withAnimation`, le système les interpole et ce corps est ré-évalué image par image
/// — la flaque, dont le centre est celui de la fenêtre, GLISSE avec elle. Hors vol, le
/// corps n'est pas ré-évalué : tout est en cache.
private struct VoileVisite: View, Animatable {
    var x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat
    var rayon: CGFloat
    var ouverture: CGFloat
    /// Les réglages qui ne s'interpolent pas ici (ils ont leur propre animation).
    let opacite: Double
    let battement: Double
    let halo: Double
    let taille: CGSize
    let flou1: Bool

    init(rect: CGRect, rayon: CGFloat, ouverture: CGFloat, opacite: Double,
         battement: Double, halo: Double, taille: CGSize, flou1: Bool) {
        x = rect.minX; y = rect.minY; w = rect.width; h = rect.height
        self.rayon = rayon; self.ouverture = ouverture
        self.opacite = opacite; self.battement = battement; self.halo = halo
        self.taille = taille; self.flou1 = flou1
    }

    typealias Quatre = AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>>
    var animatableData: AnimatablePair<Quatre, AnimatablePair<CGFloat, CGFloat>> {
        get { .init(.init(.init(x, y), .init(w, h)), .init(rayon, ouverture)) }
        set {
            x = newValue.first.first.first; y = newValue.first.first.second
            w = newValue.first.second.first; h = newValue.first.second.second
            rayon = newValue.second.first; ouverture = newValue.second.second
        }
    }

    private var rect: CGRect { CGRect(x: x, y: y, width: w, height: h) }
    private var forme: Fenetre { Fenetre(rect: rect, rayon: rayon, ouverture: ouverture) }
    private let eo = FillStyle(eoFill: true)

    var body: some View {
        let f = forme
        let centre = UnitPoint(x: rect.midX / max(taille.width, 1),
                               y: rect.midY / max(taille.height, 1))
        ZStack {
            // ① le premier flou — la matière
            f.fill(.ultraThinMaterial, style: eo)
            // ② BLUR DE BLUR — la même page, floutée une seconde fois par-dessus
            if !flou1 {
                f.fill(.regularMaterial, style: eo).opacity(0.55)
            }
            // ③ le noir — qui BAT pendant le vol
            f.fill(Color.black.opacity(0.46 + 0.07 * battement), style: eo)
            // ④ LA FLAQUE — la nuit se referme autour de l'objet
            f.fill(RadialGradient(colors: [.clear, .black.opacity(0.80)],
                                  center: centre,
                                  startRadius: 70,
                                  endRadius: taille.height * 0.85),
                   style: eo)
            // ⑤ la vignette — constante, dans les coins
            f.fill(RadialGradient(colors: [.clear, .black.opacity(0.16)],
                                  center: .center,
                                  startRadius: taille.height * 0.5,
                                  endRadius: taille.height * 0.95),
                   style: eo)
            // LA FENÊTRE : un liseré neutre et un halo doux qui se POSE (la mise
            // au point) — jamais une bordure lumineuse.
            if let t = f.trou {
                let ray = min(rayon, t.width / 2, t.height / 2)
                RoundedRectangle(cornerRadius: ray, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    .frame(width: t.width, height: t.height)
                    .position(x: t.midX, y: t.midY)
                RoundedRectangle(cornerRadius: ray, style: .continuous)
                    .stroke(Color.white.opacity(0.5), lineWidth: 8)
                    .blur(radius: 16)
                    .frame(width: t.width, height: t.height)
                    .position(x: t.midX, y: t.midY)
                    .opacity(halo)
            }
        }
        .opacity(opacite)
        .allowsHitTesting(false)
    }
}

// MARK: - La carte

/// La carte de Nosfy, ancrée à l'objet : verre (ou matière noire au barreau), bounds
/// FIXES 300 × 168, un bec vers l'objet, la claire mot par mot, la sourde en fondu, les
/// quatre points et « Suivant › ».
private struct CarteVisite: View {
    let temps: VisiteTemps
    let index: Int
    let total: Int
    let dernier: Bool
    /// Le bec pointe vers le haut (la carte est SOUS l'objet) ou vers le bas.
    let becEnHaut: Bool
    /// L'abscisse du bec dans la carte (depuis son centre).
    let becX: CGFloat
    let noir: Bool
    let onSuivant: () -> Void

    static let largeur: CGFloat = 300
    static let hauteur: CGFloat = 168
    private static let rayon: CGFloat = 24

    @State private var sourdeVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // LA MATIÈRE — le verre échantillonne le voile (la page floutée, la
            // flaque) ; le texte est un FRÈRE du verre, jamais son enfant (le
            // piège de l'encre lentillée).
            if noir {
                RoundedRectangle(cornerRadius: Self.rayon, style: .continuous)
                    .fill(Color.black.opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: Self.rayon, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
            } else {
                RoundedRectangle(cornerRadius: Self.rayon, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .glassEffect(.clear, in: RoundedRectangle(cornerRadius: Self.rayon,
                                                              style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Self.rayon, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 0) {
                MotsFlou([(temps.claire, true)], taille: 22)
                Text(temps.sourde)
                    .font(.inter(15))
                    .foregroundStyle(Color.white.opacity(0.42))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
                    .opacity(sourdeVisible ? 1 : 0)
                    .offset(y: sourdeVisible ? 0 : 4)
                Spacer(minLength: 0)
                HStack(spacing: 0) {
                    // LES QUATRE POINTS — le courant s'étire en pilule.
                    HStack(spacing: 6) {
                        ForEach(0..<total, id: \.self) { i in
                            Capsule()
                                .fill(Color.white.opacity(i == index ? 1 : 0.30))
                                .frame(width: i == index ? 16 : 6, height: 6)
                        }
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: index)
                    Spacer(minLength: 0)
                    Button(action: onSuivant) {
                        HStack(spacing: 4) {
                            Text(dernier ? L("Terminer", "Done") : L("Suivant", "Next"))
                            if !dernier {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                        }
                        .font(.inter(15, .semibold))
                        .foregroundStyle(Color.white.opacity(0.92))
                        .padding(.vertical, 8)
                        .padding(.leading, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)
        }
        .frame(width: Self.largeur, height: Self.hauteur)
        // LE BEC — vers l'objet.
        .overlay(alignment: becEnHaut ? .top : .bottom) {
            Bec(versLeHaut: becEnHaut)
                .fill(noir ? Color.black.opacity(0.92) : Color.white.opacity(0.14))
                .frame(width: 14, height: 8)
                .offset(x: becX, y: becEnHaut ? -8 : 8)
        }
        .onAppear {
            withAnimation(.easeOut(duration: reduceMotion ? 0 : 0.4)
                .delay(reduceMotion ? 0 : 0.35)) {
                sourdeVisible = true
            }
        }
    }
}

private struct Bec: Shape {
    var versLeHaut: Bool
    func path(in r: CGRect) -> Path {
        var p = Path()
        if versLeHaut {
            p.move(to: CGPoint(x: r.minX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.midX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        } else {
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        }
        p.closeSubpath()
        return p
    }
}

// MARK: - La visite

struct VisiteHome: View {
    /// La page recule à cette échelle (WoopApp) ; l'objet mis en avant prend `avance`.
    static let recul: CGFloat = 0.965
    static let avance: CGFloat = 1.04
    private static let noir = CommandLine.arguments.contains("-visiteNoir")
    private static let flou1 = CommandLine.arguments.contains("-visiteFlou1")

    let ancres: [String: Anchor<CGRect>]
    /// Le temps de départ (0 en production ; le banc `-visiteHome n` en choisit un).
    var depart: Int = 0
    let onFin: () -> Void

    @State private var etape = 0
    /// Le voile est tombé (0 → 1).
    @State private var voile: Double = 0
    /// La fenêtre est ouverte (0 → 1) — puis elle glisse, ouverte.
    @State private var ouverture: CGFloat = 0
    /// Le halo de la fenêtre : 0,6 à l'ouverture, se pose à 0,28.
    @State private var halo: Double = 0.6
    /// Le noir qui bat pendant le vol.
    @State private var battement: Double = 0
    @State private var carte = false
    @State private var passer = false
    @State private var sortie = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var temps: VisiteTemps {
        VisiteTemps.tous[min(max(etape, 0), VisiteTemps.tous.count - 1)]
    }

    var body: some View {
        // Deux lecteurs : l'externe (dans la zone sûre) ne sert qu'à lire l'inset du
        // haut ; l'interne ignore la zone sûre — c'est dans SON repère que les ancres
        // se résolvent et que le voile couvre tout l'écran.
        GeometryReader { ext in
            let insetHaut = ext.safeAreaInsets.top
            corps(insetHaut: insetHaut)
        }
    }

    private func corps(insetHaut: CGFloat) -> some View {
        GeometryReader { g in
            let cadreCourant = cadre(temps, g)
            let rayon = rayon(temps, cadreCourant)
            let ouvert = cadreCourant == nil ? 0 : ouverture
            ZStack {
                VoileVisite(rect: cadreCourant ?? .zero, rayon: rayon, ouverture: ouvert,
                            opacite: voile, battement: battement, halo: halo,
                            taille: g.size, flou1: Self.flou1)
                    .ignoresSafeArea()
                    // LE TAP HORS FENÊTRE = le temps suivant ; DANS la fenêtre, le
                    // doigt TRAVERSE (contentShape evenOdd) — l'objet répond.
                    .overlay {
                        Color.clear
                            .contentShape(.interaction,
                                          Fenetre(rect: cadreCourant ?? .zero,
                                                  rayon: rayon, ouverture: ouvert),
                                          eoFill: true)
                            .onTapGesture { suivant() }
                            .ignoresSafeArea()
                    }

                // LA CARTE — sous l'objet, ou au-dessus quand il est bas.
                if carte, let c = cadreCourant {
                    let pose = placement(c, g)
                    CarteVisite(temps: temps, index: etape, total: VisiteTemps.tous.count,
                                dernier: prochain(depuis: etape + 1) == nil,
                                becEnHaut: pose.dessous, becX: pose.becX,
                                noir: Self.noir, onSuivant: { suivant() })
                        .position(pose.centre)
                        .contentShape(Rectangle())
                        .onTapGesture { suivant() }
                        .id(temps.id)
                        .transition(.asymmetric(
                            insertion: .opacity
                                .combined(with: .scale(scale: 0.94))
                                .combined(with: .offset(y: 10)),
                            removal: .opacity.combined(with: .scale(scale: 0.97))))
                }

                // « PASSER » — en haut à GAUCHE (à droite, il heurterait la pièce du
                // trésor au quatrième temps et la pastille Nosfy sous le voile),
                // discret, zone 44 pt, sous la barre d'état.
                if passer {
                    Button(action: { terminer(passe: true) }) {
                        Text(L("Passer", "Skip"))
                            .font(.inter(15, .medium))
                            .foregroundStyle(Color.white.opacity(0.55))
                            .frame(minWidth: 60, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .position(x: 16 + 30, y: insetHaut + 22)
                    .transition(.opacity)
                }
            }
        }
        .ignoresSafeArea()
        .task { entrer() }
    }

    // MARK: la géométrie

    /// Le cadre d'un temps À L'ÉCRAN : l'ancre (en layout), ramenée par le recul de la
    /// page autour du centre de l'écran, élargie de l'avance de l'objet, puis de 10 pt.
    private func cadre(_ t: VisiteTemps, _ g: GeometryProxy) -> CGRect? {
        guard let a = ancres[t.ancre] else { return nil }
        let r = g[a]
        guard r.width > 4, r.height > 4 else { return nil }
        let c = CGPoint(x: g.size.width / 2, y: g.size.height / 2)
        let s = Self.recul
        let recule = CGRect(x: c.x + (r.minX - c.x) * s, y: c.y + (r.minY - c.y) * s,
                            width: r.width * s, height: r.height * s)
        let a2 = (Self.avance - 1) / 2
        return recule
            .insetBy(dx: -recule.width * a2, dy: -recule.height * a2)
            .insetBy(dx: -10, dy: -10)
    }

    private func rayon(_ t: VisiteTemps, _ r: CGRect?) -> CGFloat {
        guard let r else { return 36 }
        switch t.forme {
        case .card: return 36
        case .capsule: return r.height / 2
        case .cercle: return min(r.width, r.height) / 2
        }
    }

    /// Où se pose la carte : sous l'objet s'il y a la place, sinon au-dessus ; centrée
    /// sur lui, bornée à 16 pt des bords ; le bec vise son centre.
    private func placement(_ r: CGRect, _ g: GeometryProxy) -> (centre: CGPoint, dessous: Bool, becX: CGFloat) {
        let l = CarteVisite.largeur, h = CarteVisite.hauteur
        let dessous = r.maxY + 20 + h < g.size.height - g.safeAreaInsets.bottom - 8
        let y = dessous ? r.maxY + 20 + h / 2 : r.minY - 20 - h / 2
        let x = min(max(r.midX, 16 + l / 2), g.size.width - 16 - l / 2)
        let becX = min(max(r.midX - x, -l / 2 + 28), l / 2 - 28)
        return (CGPoint(x: x, y: y), dessous, becX)
    }

    /// Le premier temps dont l'objet est à l'écran, à partir de `i`.
    private func prochain(depuis i: Int) -> Int? {
        var k = i
        while k < VisiteTemps.tous.count {
            if ancres[VisiteTemps.tous[k].ancre] != nil { return k }
            k += 1
        }
        return nil
    }

    private func d(_ s: Double) -> Double { reduceMotion ? 0 : s }

    // MARK: la cascade

    /// L'entrée (PLAN § 2 g) : la page recule et le voile monte (0,7 s) ; à 0,35 la
    /// fenêtre s'ouvre et l'objet avance ; à 0,6 « Passer » ; à 0,8 la carte ; à 1,15 le
    /// halo se pose.
    private func entrer() {
        print("[visite-home] ancres reçues : \(ancres.keys.sorted().joined(separator: ", "))")
        guard let premier = prochain(depuis: depart) else {
            print("[visite-home] aucun temps possible — la visite se lève sans rien montrer")
            onFin()
            return
        }
        etape = premier
        DepartEtat.shared.visiteReculee = true
        withAnimation(.easeInOut(duration: d(0.7))) { voile = 1 }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(d(0.35)))
            guard !sortie else { return }
            withAnimation(.spring(response: d(0.55), dampingFraction: 0.82)) { ouverture = 1 }
            DepartEtat.shared.visiteFocus = temps.ancre
            try? await Task.sleep(for: .seconds(d(0.25)))
            withAnimation(.easeOut(duration: d(0.3))) { passer = true }
            try? await Task.sleep(for: .seconds(d(0.2)))
            guard !sortie else { return }
            withAnimation(.spring(response: d(0.5), dampingFraction: 0.86)) { carte = true }
            try? await Task.sleep(for: .seconds(d(0.35)))
            withAnimation(.easeInOut(duration: d(0.5))) { halo = 0.28 }
        }
    }

    /// Le temps suivant : tic + main ; la carte sort ; la fenêtre GLISSE et se morphe,
    /// la flaque suit, le noir bat ; l'objet quitté revient, le suivant avance ; la
    /// carte revient à sa nouvelle place.
    private func suivant() {
        guard !sortie, carte, ouverture > 0.9 else { return }
        guard let k = prochain(depuis: etape + 1) else {
            terminer(passe: false)
            return
        }
        NosfySon.tic()
        Haptique.leger()
        withAnimation(.easeOut(duration: d(0.22))) { carte = false }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(d(0.05)))
            guard !sortie else { return }
            withAnimation(.timingCurve(0.3, 0.8, 0.2, 1, duration: d(0.6))) { etape = k }
            DepartEtat.shared.visiteFocus = VisiteTemps.tous[k].ancre
            withAnimation(.easeInOut(duration: d(0.3))) { battement = 1 }
            halo = 0.5
            try? await Task.sleep(for: .seconds(d(0.3)))
            withAnimation(.easeInOut(duration: d(0.3))) { battement = 0 }
            try? await Task.sleep(for: .seconds(d(0.1)))
            guard !sortie else { return }
            withAnimation(.spring(response: d(0.5), dampingFraction: 0.86)) { carte = true }
            withAnimation(.easeInOut(duration: d(0.5))) { halo = 0.28 }
        }
    }

    /// La sortie — le dernier tap (paillette + main moyenne) ou « Passer » (tic) : la
    /// carte sort, la fenêtre se referme sur l'objet, puis le voile s'éteint et la page
    /// revient AVEC lui ; le démontage et la mémoire à la fin.
    private func terminer(passe: Bool) {
        guard !sortie else { return }
        sortie = true
        if passe { NosfySon.tic() } else { NosfySon.paillette() }
        Haptique.moyen()
        DepartEtat.shared.visiteFocus = nil
        withAnimation(.easeOut(duration: d(0.22))) { carte = false; passer = false }
        withAnimation(.easeInOut(duration: d(0.35))) { ouverture = 0 }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(d(0.2)))
            DepartEtat.shared.visiteReculee = false
            withAnimation(.easeInOut(duration: d(0.6))) { voile = 0 }
            try? await Task.sleep(for: .seconds(d(0.65)))
            onFin()
        }
    }
}
