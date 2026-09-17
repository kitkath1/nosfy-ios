import SwiftUI
import Observation

// ════════════════════════════════════════════════════════════════════════
// LA VISITE GUIDÉE DE LA HOME — v4 « LA BRUME » (14-09, matin)
// tools/porte/PLAN-VISITE-PREMIUM.md — le plan qu'on code, section par section.
//
// Son verdict sur la v2 : « les encadrés font fake, pas naturel ; je pense à un
// dégradé de blur noir, dégradé de la Home, la partie entourée moins fake ». Donc :
// AUCUNE FORME. La Home ne change pas, on ne dessine rien dessus. On la couvre d'une
// BRUME — deux flous (le blur de blur) et un noir — qui est ABSENTE autour du vrai
// objet du temps et qui se referme en FONDU tout autour (140 pt ; 80 pt pour les
// petits objets). Quatre temps = quatre endroits où la brume s'ouvre. Les mots, en
// grand, dans la brume ; « Touche pour continuer » à la place de tout bouton ;
// « Passer » ; le doigt traverse la poche claire.
//
// RIEN NE SE REDESSINE POUR ANIMER (la loi du 05-09) : la brume est une vue
// Animatable sur les cinq nombres de sa poche (x, y, l, h, rayon) — le système
// interpole pendant le glissement (0,7 s), rien d'autre ; la poche est un trou à
// bords FLOUTÉS À RAYON CONSTANT (une passe hors écran, en cache hors vol) ; le reste =
// des opacités. Aucune horloge. Démontée à la fin, jamais cachée.
//
// Bancs / barreaux : `-visiteHome [1-4]` (PremiereArrivee) · `-sansVisite` (rien) ·
// `-visiteFlou1` (un seul flou).
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

/// Les préférences d'ancre ne traversent pas toujours l'hôte d'un onglet.
/// Ces cadres sont relevés uniquement pendant la visite, sur l'onglet visible.
@Observable
final class ReperesVisite {
    static let shared = ReperesVisite()
    var cadres: [String: CGRect] = [:]
}

struct CadreVisite: ViewModifier {
    let nom: String
    @Environment(\.ongletCache) private var cache

    func body(content: Content) -> some View {
        content.background {
            if DepartEtat.shared.visiteOuverte, !cache {
                Color.clear
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { cadre in
                        guard ReperesVisite.shared.cadres[nom] != cadre else { return }
                        ReperesVisite.shared.cadres[nom] = cadre
                    }
                    .onDisappear { ReperesVisite.shared.cadres[nom] = nil }
                    .allowsHitTesting(false)
            }
        }
    }
}

/// Le modificateur d'un objet de la visite : il publie son cadre, et il TERMINE la
/// visite quand le doigt le traverse — l'objet fait alors ce qu'il fait toujours (la
/// route, le coffre, l'onglet) : le tuto n'est jamais un mur. Il ne le touche pas
/// autrement : pas d'échelle, pas de lumière — l'objet est simplement le seul net.
private struct VisiteAncre: ViewModifier {
    let nom: String
    var depart = DepartEtat.shared

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(TapGesture().onEnded {
                if depart.visiteOuverte { PremiereArrivee.finirVisite() }
            })
            .anchorPreference(key: VisiteAncreKey.self, value: .bounds) { [nom: $0] }
            .modifier(CadreVisite(nom: nom))
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
    /// La forme de la poche : les coins de la card, la capsule du glyphe, le cercle
    /// de la pièce — et la largeur du fondu (140 pt ; 80 pt pour les petits objets).
    let forme: Forme
    let clairFr: String, clairEn: String
    let sourdFr: String, sourdEn: String
    var claire: String { L(clairFr, clairEn) }
    var sourde: String { L(sourdFr, sourdEn) }

    enum Forme { case card, capsule, cercle }
    var petit: Bool { forme != .card }

    /// Les textes (sport, clair / sourd, deux langues — PLAN § 4).
    static let tous: [VisiteTemps] = [
        // Un seul mot (verdict 14-09 : « juste un mot, Commencer, pas sur deux lignes
        // le gros texte — fais comme Tes progrès »).
        VisiteTemps(id: 0, ancre: "visite-galets", forme: .card,
                    clairFr: "Commencer.", clairEn: "Start.",
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

// MARK: - La brume (la vue Animatable)

/// La brume plein écran, ABSENTE dans une poche à bords fondus autour de l'objet.
/// Ses cinq nombres (x, y, l, h, rayon) sont animables : sous `withAnimation`, la
/// poche GLISSE d'un objet au suivant et prend sa forme ; le fondu (`fondu`) est le
/// flou d'un masque à rayon CONSTANT — une passe hors écran, en cache hors vol.
struct BrumeVisite: View, Animatable {
    var x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat
    var rayon: CGFloat
    let fondu: CGFloat
    let opacite: Double
    let flou1: Bool

    init(rect: CGRect, rayon: CGFloat, fondu: CGFloat, opacite: Double, flou1: Bool) {
        x = rect.minX; y = rect.minY; w = rect.width; h = rect.height
        self.rayon = rayon; self.fondu = fondu; self.opacite = opacite; self.flou1 = flou1
    }

    typealias Quatre = AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>>
    var animatableData: AnimatablePair<Quatre, CGFloat> {
        get { .init(.init(.init(x, y), .init(w, h)), rayon) }
        set {
            x = newValue.first.first.first; y = newValue.first.first.second
            w = newValue.first.second.first; h = newValue.first.second.second
            rayon = newValue.second
        }
    }

    var body: some View {
        ZStack {
            // ① le premier flou — la matière
            Rectangle().fill(.ultraThinMaterial)
            // ② BLUR DE BLUR — la même page, floutée une seconde fois par-dessus
            if !flou1 { Rectangle().fill(.regularMaterial).opacity(0.55) }
            // ③ LE DÉGRADÉ DE NOIR (verdict 14-09 : « dégradé de noir ») — pas un
            //    noir plat : la nuit est plus claire en haut, plus profonde vers le
            //    bas, et se referme un peu plus dans les coins.
            Rectangle().fill(LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.66), location: 0),
                    .init(color: .black.opacity(0.78), location: 0.45),
                    .init(color: .black.opacity(0.90), location: 1)
                ],
                startPoint: .top, endPoint: .bottom))
            Rectangle().fill(RadialGradient(
                colors: [.clear, .black.opacity(0.22)],
                center: .center, startRadius: 180, endRadius: 720))
        }
        .ignoresSafeArea()
        // LA POCHE : le masque est plein, PERCÉ par la forme de l'objet aux bords
        // floutés (le fondu) — pas de trait, pas d'arête : la brume s'efface en
        // dégradé autour de lui.
        .mask {
            ZStack {
                Rectangle().fill(.black)
                if w > 1, h > 1 {
                    RoundedRectangle(cornerRadius: min(rayon, w / 2, h / 2), style: .continuous)
                        .fill(.black)
                        .frame(width: w, height: h)
                        .position(x: x + w / 2, y: y + h / 2)
                        .blur(radius: fondu / 2.6)
                        .blendMode(.destinationOut)
                }
            }
            .compositingGroup()
            .ignoresSafeArea()
        }
        .opacity(opacite)
        .allowsHitTesting(false)
    }
}

/// Le rectangle plein écran percé de la poche — pour le TOUCHER seulement : le tap
/// hors poche = le temps suivant, le tap dans la poche traverse vers l'objet.
struct PerceVisite: Shape {
    var rect: CGRect
    var rayon: CGFloat
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.addRect(r)
        if rect.width > 1, rect.height > 1 {
            let ray = min(rayon, rect.width / 2, rect.height / 2)
            p.addRoundedRect(in: rect, cornerSize: CGSize(width: ray, height: ray),
                             style: .continuous)
        }
        return p
    }
}

// MARK: - La visite

/// L'état d'ouverture est observé dans un corps de vue, indépendamment des
/// changements d'ancres. Sur une Home immobile, la closure de préférences
/// seule pouvait ne jamais monter la visite demandée.
struct VisiteHomeHote: View {
    let ancres: [String: Anchor<CGRect>]
    var body: some View {
        let etat = DepartEtat.shared
        if etat.visiteOuverte, !ancres.isEmpty || !ReperesVisite.shared.cadres.isEmpty {
            VisiteHome(ancres: ancres, depart: etat.visiteEtape,
                       onFin: { PremiereArrivee.finirVisite() })
                .transition(.opacity)
                .zIndex(29)
        }
    }
}

struct VisiteHome: View {
    private static let flou1 = CommandLine.arguments.contains("-visiteFlou1")
    /// La marge claire autour de l'objet, et le fondu de la brume.
    private static let marge: CGFloat = 24
    private static let fonduGrand: CGFloat = 140
    private static let fonduPetit: CGFloat = 80
    /// La colonne des mots : la loi de la phrase de la Home (24 pt, 300 pt).
    private static let margeTexte: CGFloat = 24
    private static let largeurTexte: CGFloat = 300
    private static let hauteurTexte: CGFloat = 190

    let ancres: [String: Anchor<CGRect>]
    /// Le temps de départ (0 en production ; le banc `-visiteHome n` en choisit un).
    var depart: Int = 0
    let onFin: () -> Void

    @State private var etape = 0
    /// La brume est tombée (0 → 1).
    @State private var brume: Double = 0
    /// L'APPARITION (verdict 14-09 : « apparition plus blur, jolie ») : la poche naît
    /// LARGE (1,6 × l'objet) et se RESSERRE sur lui pendant que la brume monte — la
    /// nuit se referme autour de l'objet, elle ne tombe pas d'un bloc.
    @State private var dilatation: CGFloat = 1.6
    @State private var mots = false
    @State private var invite = false
    @State private var respiration: Double = 0
    @State private var passer = false
    @State private var sortie = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var temps: VisiteTemps {
        VisiteTemps.tous[min(max(etape, 0), VisiteTemps.tous.count - 1)]
    }
    private var dernier: Bool { prochain(depuis: etape + 1) == nil }

    var body: some View {
        // Deux lecteurs : l'externe (dans la zone sûre) ne sert qu'à lire l'inset du
        // haut ; l'interne ignore la zone sûre — c'est dans SON repère que les ancres
        // se résolvent et que la brume couvre tout l'écran.
        GeometryReader { ext in
            corps(insetHaut: ext.safeAreaInsets.top, insetBas: ext.safeAreaInsets.bottom)
        }
    }

    private func corps(insetHaut: CGFloat, insetBas: CGFloat) -> some View {
        GeometryReader { g in
            let poche = poche(temps, g)
            let rayon = rayon(temps, poche)
            let fondu = temps.petit ? Self.fonduPetit : Self.fonduGrand
            ZStack {
                BrumeVisite(rect: poche ?? .zero, rayon: rayon, fondu: fondu,
                      opacite: brume, flou1: Self.flou1)
                    // LE TAP HORS POCHE = le temps suivant ; DANS la poche, le doigt
                    // TRAVERSE (contentShape evenOdd) — l'objet répond.
                    .overlay {
                        Color.clear
                            .contentShape(.interaction, PerceVisite(rect: poche ?? .zero, rayon: rayon),
                                          eoFill: true)
                            .onTapGesture { suivant() }
                            .ignoresSafeArea()
                    }

                // LES MOTS — dans la brume, sous la poche (ou au-dessus quand l'objet
                // est bas) : la claire mot par mot, la sourde en fondu, puis l'invite
                // qui respire. Pas de bouton.
                if mots, let p = poche {
                    let dessous = p.maxY + fondu * 0.5 + 28 + Self.hauteurTexte
                        < g.size.height - insetBas - 8
                    let yBord = dessous ? p.maxY + fondu * 0.5 + 28 : p.minY - fondu * 0.5 - 28
                    VStack(alignment: .leading, spacing: 0) {
                        // COMME DANS LE FILM, MOT APRÈS MOT (verdict 14-09 : « comme si
                        // quelqu'un parlait ») : la claire, puis la sourde qui prend la
                        // parole quand la claire a fini — le même phrasé, le même flou.
                        MotsFlou([(temps.claire, true)], taille: 32)
                        MotsFlou([(temps.sourde, false)], taille: 17,
                                 base: MotsFlou.duree([(temps.claire, true)]) - 0.3)
                            .padding(.top, 10)
                        Text(dernier ? L("Touche pour commencer", "Tap to start")
                                     : L("Touche pour continuer", "Tap to continue"))
                            .font(.inter(14))
                            .foregroundStyle(Color.white.opacity(0.38 + 0.22 * respiration))
                            .padding(.top, 20)
                            .opacity(invite ? 1 : 0)
                            .blur(radius: invite ? 0 : 6)
                    }
                    .frame(width: Self.largeurTexte, height: Self.hauteurTexte,
                           alignment: dessous ? .topLeading : .bottomLeading)
                    .position(x: Self.margeTexte + Self.largeurTexte / 2,
                              y: dessous ? yBord + Self.hauteurTexte / 2
                                         : yBord - Self.hauteurTexte / 2)
                    .id(temps.id)
                    .transition(.asymmetric(insertion: .opacity,
                                            removal: .fonduFlou))
                    .allowsHitTesting(false)
                }

                // « PASSER » — un mot, en haut à gauche, sous la barre d'état.
                if passer {
                    Button(action: { terminer(passe: true) }) {
                        Text(L("Passer", "Skip"))
                            .font(.inter(15, .medium))
                            .foregroundStyle(Color.white.opacity(0.50))
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
        .onChange(of: etape) { _, valeur in
            DepartEtat.shared.visiteEtape = valeur
        }
    }

    // MARK: la géométrie

    /// La poche d'un temps : le cadre du VRAI objet, élargi de la marge — nil si
    /// l'objet n'est pas à l'écran.
    private func poche(_ t: VisiteTemps, _ g: GeometryProxy) -> CGRect? {
        let r: CGRect
        if let a = ancres[t.ancre] {
            r = g[a]
        } else if let cadre = ReperesVisite.shared.cadres[t.ancre] {
            let origine = g.frame(in: .global).origin
            r = cadre.offsetBy(dx: -origine.x, dy: -origine.y)
        } else { return nil }
        guard r.width > 4, r.height > 4 else { return nil }
        let p = r.insetBy(dx: -Self.marge, dy: -Self.marge)
        // La dilatation de l'apparition (1,6 → 1) : la poche se resserre sur l'objet.
        return p.insetBy(dx: -p.width * (dilatation - 1) / 2,
                         dy: -p.height * (dilatation - 1) / 2)
    }

    private func rayon(_ t: VisiteTemps, _ r: CGRect?) -> CGFloat {
        guard let r else { return 26 + Self.marge }
        switch t.forme {
        case .card: return 26 + Self.marge
        case .capsule: return r.height / 2
        case .cercle: return min(r.width, r.height) / 2
        }
    }

    /// Le premier temps dont l'objet est à l'écran, à partir de `i`.
    private func prochain(depuis i: Int) -> Int? {
        var k = i
        while k < VisiteTemps.tous.count {
            let cle = VisiteTemps.tous[k].ancre
            if ancres[cle] != nil || ReperesVisite.shared.cadres[cle] != nil { return k }
            k += 1
        }
        return nil
    }

    private func d(_ s: Double) -> Double { reduceMotion ? 0 : s }

    // MARK: la cascade (PLAN § 1 e)

    /// L'entrée : la brume tombe (0,8 s), la poche est DÉJÀ sur le premier objet ;
    /// à 0,6 les mots ; à 0,95 la sourde ; à 2,1 l'invite ; « Passer » avec la brume.
    private func entrer() {
        print("[visite-home] ancres reçues : \(ancres.keys.sorted().joined(separator: ", "))")
        guard let premier = prochain(depuis: depart) else {
            print("[visite-home] aucun temps possible — la visite se lève sans rien montrer")
            onFin()
            return
        }
        etape = premier
        // LA MAIN (verdict : « plus d'haptique ») : la brume qui tombe se sent, douce.
        Haptique.doux()
        withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: d(1.1))) {
            brume = 1
            dilatation = 1
        }
        withAnimation(.easeOut(duration: d(0.5)).delay(d(0.7))) { passer = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(d(0.8)))
            guard !sortie else { return }
            Haptique.leger()
            withAnimation(.easeOut(duration: d(0.25))) { mots = true }
            try? await Task.sleep(for: .seconds(d(dureeParole())))
            guard !sortie else { return }
            withAnimation(.easeOut(duration: d(0.6))) { invite = true }
            armerRespiration()
        }
    }

    /// Le temps que la claire puis la sourde mettent à se dire — l'invite attend.
    private func dureeParole() -> Double {
        let claire = MotsFlou.duree([(temps.claire, true)])
        return claire - 0.3 + MotsFlou.duree([(temps.sourde, false)]) + 0.5
    }

    private func armerRespiration() {
        guard !reduceMotion else { respiration = 0.5; return }
        respiration = 0
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            respiration = 1
        }
    }

    /// Le temps suivant : tic + main ; les mots se dissolvent ; la poche GLISSE vers
    /// l'objet suivant et prend sa forme ; les nouveaux mots.
    private func suivant() {
        guard !sortie, mots else { return }
        guard let k = prochain(depuis: etape + 1) else {
            terminer(passe: false)
            return
        }
        NosfySon.tic()
        Haptique.moyen()
        withAnimation(.easeOut(duration: d(0.3))) { mots = false }
        invite = false
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(d(0.05)))
            guard !sortie else { return }
            withAnimation(.timingCurve(0.3, 0.8, 0.2, 1, duration: d(0.7))) { etape = k }
            try? await Task.sleep(for: .seconds(d(0.55)))
            guard !sortie else { return }
            // La poche s'est posée sur l'objet suivant : une main douce, et les mots.
            Haptique.doux()
            withAnimation(.easeOut(duration: d(0.25))) { mots = true }
            try? await Task.sleep(for: .seconds(d(dureeParole())))
            guard !sortie else { return }
            withAnimation(.easeOut(duration: d(0.6))) { invite = true }
            armerRespiration()
        }
    }

    /// La sortie — le dernier tap (paillette + main moyenne) ou « Passer » (tic) : les
    /// mots se dissolvent, la brume se lève (0,7 s) — la Home revient entière ; le
    /// démontage et la mémoire à la fin.
    private func terminer(passe: Bool) {
        guard !sortie else { return }
        sortie = true
        if passe { NosfySon.tic(); Haptique.leger() } else { NosfySon.paillette(); Haptique.succes() }
        withAnimation(.easeOut(duration: d(0.3))) { mots = false; passer = false }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(d(0.1)))
            // La brume se lève comme elle est venue : elle s'ouvre autour de l'objet
            // pendant qu'elle s'éteint — l'apparition à l'envers.
            withAnimation(.easeInOut(duration: d(0.8))) { brume = 0; dilatation = 1.6 }
            try? await Task.sleep(for: .seconds(d(0.85)))
            onFin()
        }
    }
}

/// LES DEUX MAINS QUI MANQUAIENT (verdict 14-09 : « plus d'haptique ») : la douce,
/// pour la brume qui tombe et la poche qui se pose ; le succès, pour la fin.
extension Haptique {
    private static let souple = UIImpactFeedbackGenerator(style: .soft)
    private static let notification = UINotificationFeedbackGenerator()
    static func doux() {
        souple.impactOccurred(intensity: 0.8)
        souple.prepare()
    }
    static func succes() {
        notification.notificationOccurred(.success)
        notification.prepare()
    }
}
