import SwiftUI
import AVFoundation

// MARK: - La bibliothèque d'exercices — page NUIT, halo braise, couronne
//
// Page immersive : plus de barre bijou ici — un chevron à côté du titre
// ramène à la home. Le halo braise morphe derrière LES CARTES, franchement à
// gauche (le flanc droit est une nuit franche : il appartient à la molette).
// Les cartes : petites, rectangulaires, décalées en deux colonnes façon
// Pinterest, SANS bordure — des silhouettes sombres posées sur la lumière.
// Tout est net, sauf le FOOTER : la dernière rangée fond dans un voile de
// flou au bord bas, et taper une carte prise dans le voile la fait remonter
// (souffle + vibration) au lieu de l'ouvrir.
//
// Le filtre est la COURONNE du bord droit (molette v5) : un petit disque de
// verre liquide fumé, un anneau de graduations fines dont le dégradé de
// lumière fait la forme, des labels en casse naturelle à l'encre dégradé
// blanc. Au doigt posé, la scène s'éteint et se floute, la fumée s'échappe.

struct ExercisesView: View {
    /// Le chevron du header ramène à la home : la page connaît l'onglet.
    @Binding var selection: WoopTab

    @State private var filter: ExerciseCategory?

    /// Ouvre une fiche dès le lancement : `-openExercise woop-haute`. Même
    /// usage que `-openTab` et `-openActiveSheet` (captures d'écran
    /// automatisées uniquement) — sans ça, la fiche n'est atteignable qu'au
    /// doigt, et le simulateur ne se pilote pas en ligne de commande.
    @State private var deepLinked: Exercise?

    /// L'état du scroll : offset et hauteur du viewport — c'est avec eux (et
    /// les hauteurs FIXES de carte) que le tap sait si une carte est prise
    /// dans le voile du footer. Pas de mesure par carte, que de l'arithmétique.
    @State private var scrollOffset: CGFloat = 0
    @State private var viewportH: CGFloat = 700
    @State private var scrolledID: String?
    @State private var focusPulse = 0

    /// Le doigt est sur la couronne : la scène derrière s'éteint et se
    /// floute pour ne laisser vivre que les traits et les dégradés.
    @State private var dialEngaged = false

    /// L'horodatage du dernier choix de section : le halo pulse en réponse.
    @State private var haloPulseAt: Date?

    /// LE TUTO À PROJECTEURS (armé par « Commencer » du panneau de
    /// départ, la première fois seulement) : la nuit tombe sur toute la
    /// page SAUF deux fenêtres — la première card et la couronne. Les
    /// taps DANS les fenêtres passent aux vraies vues (le geste réel EST
    /// l'apprentissage) ; n'importe quel tap éteint le tuto.
    @State private var tutoActif = false
    /// La naissance du tuto — LA CASCADE s'écrit dessus : le voile
    /// tombe, PUIS la fenêtre de la card s'ouvre, PUIS la molette
    /// (jamais tout d'un coup — la loi de la maison).
    @State private var tutoNe = Date()

    /// La géométrie de la grille, en constantes : hauteur de carte, gouttière,
    /// décalage Pinterest de la seconde colonne, marge haute du contenu.
    private static let cardHeight: CGFloat = 200
    private static let gutter: CGFloat = 13
    private static let stagger: CGFloat = 30
    private static let topPad: CGFloat = 8

    private var shown: [Exercise] {
        let categories = filter.map { [$0] } ?? ExerciseCategory.allCases
        return categories.flatMap { ExerciseCatalog.exercises(in: $0) }
    }

    /// Deux colonnes remplies en alternance — indices dans `shown`, pour que
    /// le calcul du voile retrouve la position de chaque carte.
    private var columnsIdx: ([Int], [Int]) {
        var left: [Int] = [], right: [Int] = []
        for i in shown.indices {
            if i.isMultiple(of: 2) { left.append(i) } else { right.append(i) }
        }
        return (left, right)
    }

    /// `-exosVoile <p>` fige l'apparition du voile du haut (captures) — le
    /// simulateur ne se fait pas défiler en ligne de commande. Même usage que
    /// `-profilPli`, qui fige le fondu du profil.
    private static let voileFreeze: Double? = UserDefaults.standard
        .string(forKey: "exosVoile").flatMap { Double($0) }

    /// La naissance du voile du haut, la loi du profil : la rampe courte de
    /// 26 pt, adoucie en smoothstep — le voile n'apparaît pas d'un trait, il
    /// monte avec le premier pouce de scroll.
    private var topVeil: Double {
        if let f = Self.voileFreeze { return min(max(f, 0), 1) }
        let t = min(max(Double(scrollOffset) / 26, 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// La prise du voile pour la carte d'indice `i` : 0 = nette, 1 = fondue
    /// au bord bas. Même loi que le `visualEffect` des cartes — les deux
    /// DOIVENT rester accordées, c'est elle qui décide du geste au tap.
    private func veilT(_ i: Int) -> Double {
        let col = CGFloat(i % 2), row = CGFloat(i / 2)
        let top = Self.topPad + col * Self.stagger
                + row * (Self.cardHeight + Self.gutter)
        let maxY = top + Self.cardHeight - scrollOffset
        return Double(min(max(1.0 - (viewportH - maxY) / 210, 0), 1))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ExosHaloBackground(pulseAt: haloPulseAt)
                VStack(alignment: .leading, spacing: 14) {
                    header
                    grid
                }
                .blur(radius: dialEngaged ? 13 : 0)
                // La poussée de profondeur : la scène RECULE légèrement sous
                // le doigt — c'est elle qui fait le « zoom » du théâtre.
                .scaleEffect(dialEngaged ? 0.975 : 1.0)
            }
            // Le théâtre du toucher : la nuit tombe sur toute la scène —
            // cartes, header, halo — sous la couronne seule.
            .overlay {
                Color.black.opacity(dialEngaged ? 0.55 : 0)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            .animation(.spring(response: 0.42, dampingFraction: 0.85),
                       value: dialEngaged)
            .overlay(alignment: .trailing) {
                ArcDial(selection: $filter, engaged: $dialEngaged)
                    .frame(width: 240, height: 520)
                    .anchorPreference(key: SlotAnchorKey.self,
                                      value: .bounds) {
                        ["tuto-dial": $0]
                    }
            }
            // LE TUTO À PROJECTEURS — au-dessus de tout (couronne
            // comprise : elle reste visible et interactive dans SA
            // fenêtre, les taps des fenêtres passent au travers).
            .overlayPreferenceValue(SlotAnchorKey.self) { anchors in
                tutoCouche(anchors)
            }
            // N'importe quel tap éteint le tuto — dans une fenêtre il
            // fait AUSSI l'action réelle (la card s'ouvre, la couronne
            // s'engage) : le geste appris est le geste fait.
            .simultaneousGesture(TapGesture().onEnded {
                if tutoActif { eteindreTuto() }
            })
            .onAppear { armerTutoSiDemande() }
            .onChange(of: DepartEtat.shared.tutoDemande) { _, d in
                if d { armerTutoSiDemande() }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $deepLinked) { ExerciseDetailView(exercise: $0) }
            .sensoryFeedback(.impact(weight: .light, intensity: 0.9),
                             trigger: focusPulse)
            .onChange(of: filter) { _, _ in
                // Nouveau filtre : la grille repart en tête, le halo répond
                // d'une pulsation — calée sur le souffle sonore de la pose.
                haloPulseAt = .now
                scrollOffset = 0
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    scrolledID = shown.first?.id
                }
            }
            .task {
                if let id = UserDefaults.standard.string(forKey: "openExercise") {
                    deepLinked = ExerciseCatalog.exercise(id: id)
                }
            }
        }
    }

    /// Chevron + « Exercices » : le header maison a remplacé la barre système
    /// ET la barre bijou — la sortie de la page, c'est lui.
    ///
    /// La rangée est celle de la MAISON (`RangeeChips`, cotes 20 / 4 / 8) :
    /// le chevron seul sur sa ligne, exactement où il vit sur la fiche
    /// d'exercice et sur le profil. Le titre descend SOUS lui — porté par la
    /// même rangée, il flottait 20 pt plus bas que partout ailleurs, et la
    /// position du chevron ne bouge JAMAIS d'une page à l'autre.
    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            RangeeChips(retour: {
                withAnimation(.easeOut(duration: 0.3)) {
                    selection = .home
                }
            }) { EmptyView() }

            VStack(alignment: .leading, spacing: 5) {
                Text("Exercices")
                    .font(.inter(32, .bold))
                    .tracking(-0.3)
                    .foregroundStyle(WoopGradient.titleFade)
                Text("Construis tes séances à partir de ta bibliothèque.")
                    .font(.inter(13))
                    .foregroundStyle(Color.inkSecondary)
            }
            .padding(.horizontal, 20)
        }
    }

    /// Le Pinterest : deux colonnes décalées à gauche de la couronne. Au
    /// repos tout est net ; les DEUX bords fondent — le bas dans le voile de
    /// chaque carte, le haut dans le fondu noir qui naît au scroll.
    private var grid: some View {
        ScrollView {
            HStack(alignment: .top, spacing: Self.gutter) {
                cardColumn(columnsIdx.0)
                cardColumn(columnsIdx.1)
                    .padding(.top, Self.stagger)
            }
            .scrollTargetLayout()
            .padding(.top, Self.topPad)
            .padding(.leading, 20)
            .padding(.trailing, ArcDial.touchCorridor)
            .padding(.bottom, 60)
            .animation(.easeOut(duration: 0.28), value: filter)
        }
        .scrollPosition(id: $scrolledID, anchor: .top)
        .onScrollGeometryChange(for: CGFloat.self,
                                of: { $0.contentOffset.y + $0.contentInsets.top }) { _, new in
            scrollOffset = new
        }
        .onScrollGeometryChange(for: CGFloat.self,
                                of: { $0.containerSize.height }) { _, new in
            viewportH = new
        }
        .scrollIndicators(.hidden)
        // LE FONDU DU HAUT — la recette du profil (« pas de blur dégueu avec
        // trait » : un DÉGRADÉ NOIR pur, aucune arête), né au scroll, sur la
        // même rampe courte de 26 pt : dès que le contenu passe dessous, le
        // voile est là. Sans lui, les cartes se COUPENT net au bord haut.
        //
        // Une différence avec le profil, et elle est structurelle : là-bas le
        // voile est collé au bord de l'écran, il n'a donc pas de bord haut.
        // Ici il naît au bord haut de la GRILLE, avec le halo qui vit
        // au-dessus — il doit donc se dissoudre des DEUX côtés, sinon son
        // propre bord tracerait une ligne noire en travers de la braise.
        //
        // Posé APRÈS les sondes de scroll : un overlay glissé avant elles
        // marche, mais il met une vue entre la sonde et son ScrollView pour
        // rien — et cette page a déjà payé le prix des sondes fragiles.
        .overlay(alignment: .top) {
            LinearGradient(stops: [
                .init(color: .black.opacity(0.0), location: 0.0),
                .init(color: .black, location: 0.34),
                .init(color: .black.opacity(0.62), location: 0.52),
                .init(color: .black.opacity(0.0), location: 1.0),
            ], startPoint: .top, endPoint: .bottom)
            // Le noir plein tombe EXACTEMENT sur le bord haut de la grille
            // (0,34 × 64 = 21,8, la remontée) : c'est là que la coupe a lieu.
            //
            // Et il ne descend que 42 pt plus bas. À 76 pt, le voile n'était
            // plus un traitement de bord mais un RIDEAU : il éteignait la
            // moitié de la photo de la première rangée — et d'abord celle de
            // GAUCHE, qui démarre 30 pt plus haut que la droite (le décalage
            // Pinterest la pousse d'autant plus loin dans le noir).
            .frame(height: 64)
            .offset(y: -22)
            .opacity(topVeil)
            .allowsHitTesting(false)
        }
    }

    // MARK: le tuto à projecteurs

    /// L'armement : demandé par « Commencer » (DepartEtat), servi UNE
    /// fois (UserDefaults) — `-tutoExos` le rejoue au banc à volonté.
    private func armerTutoSiDemande() {
        let banc = CommandLine.arguments.contains("-tutoExos")
        guard DepartEtat.shared.tutoDemande || banc else { return }
        DepartEtat.shared.tutoDemande = false
        let deja = UserDefaults.standard.bool(forKey: "tutoExosVu")
        guard !deja || banc else { return }
        UserDefaults.standard.set(true, forKey: "tutoExosVu")
        // La page se pose d'abord, le voile tombe ensuite — et la
        // CASCADE (voile → card → molette) s'écrit sur tutoNe.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            tutoNe = Date()
            withAnimation(.easeInOut(duration: 0.3)) { tutoActif = true }
        }
    }

    private func eteindreTuto() {
        guard tutoActif else { return }
        withAnimation(.easeOut(duration: 0.3)) { tutoActif = false }
    }

    /// Le voile percé : la nuit sur toute la page, DEUX fenêtres de
    /// lumière (la card, la couronne) aux liserés de braise qui
    /// respirent. Les taps des fenêtres passent au travers
    /// (`contentShape` evenOdd) — le voile absorbe le reste.
    @ViewBuilder
    private func tutoCouche(_ anchors: [String: Anchor<CGRect>])
        -> some View {
        if tutoActif {
            GeometryReader { g in
                let cardRect = anchors["tuto-card"]
                    .map { g[$0].insetBy(dx: -8, dy: -8) }
                // La fenêtre SERRE la couronne (l'arc du bord droit) —
                // le cadre de l'ArcDial fait 240×520 et avalerait la
                // moitié de la grille ; elle déborde l'écran à droite,
                // la découpe s'ouvre vers le bord.
                let dialRect = anchors["tuto-dial"].map { a -> CGRect in
                    let r = g[a]
                    return CGRect(x: r.maxX - 104, y: r.midY - 135,
                                  width: 132, height: 270)
                }
                let braise = Color(red: 1.0, green: 0.56, blue: 0.2)
                // LA CASCADE — jamais tout d'un coup : le voile tombe
                // (0 → 0,4), la fenêtre de la card S'OUVRE (0,45 →
                // 0,85), puis celle de la molette (1,05 → 1,45). Les
                // fenêtres s'ouvrent en grandissant depuis leur centre,
                // les mots naissent avec elles.
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                    let age = tl.date.timeIntervalSince(tutoNe)
                    let sstep: (Double, Double) -> Double = { a, b in
                        let u = min(max((age - a) / (b - a), 0), 1)
                        return u * u * (3 - 2 * u)
                    }
                    let k1 = sstep(0.45, 0.85)
                    let k2 = sstep(1.05, 1.45)
                    let trous = [
                        cardRect.flatMap { r in k1 > 0.01
                            ? r.insetBy(dx: r.width / 2 * (1 - k1),
                                        dy: r.height / 2 * (1 - k1)) : nil },
                        dialRect.flatMap { r in k2 > 0.01
                            ? r.insetBy(dx: r.width / 2 * (1 - k2),
                                        dy: r.height / 2 * (1 - k2)) : nil },
                    ].compactMap { $0 }
                    let vie = 0.55 + 0.35 * sin(age * 2 * .pi / 2.6)
                    ZStack {
                        // LE FLOU DEMANDÉ : le voile est une MATIÈRE —
                        // le reste de la page se floute sous elle, les
                        // fenêtres restent nettes (le trou evenOdd ne
                        // floute rien). La nuit par-dessus, plus légère
                        // qu'avant : le flou porte déjà la mise à
                        // l'écart.
                        VoileTuto(trous: trous)
                            .fill(.ultraThinMaterial,
                                  style: FillStyle(eoFill: true))
                            .opacity(sstep(0, 0.4))
                            .ignoresSafeArea()
                        VoileTuto(trous: trous)
                            .fill(Color.black.opacity(0.5 * sstep(0, 0.4)),
                                  style: FillStyle(eoFill: true))
                            .ignoresSafeArea()
                        ForEach(Array(trous.enumerated()),
                                id: \.offset) { _, r in
                            RoundedRectangle(cornerRadius: 20,
                                             style: .continuous)
                                .stroke(braise, lineWidth: 1.4)
                                .frame(width: r.width, height: r.height)
                                .position(x: r.midX, y: r.midY)
                                .opacity(0.95 * vie)
                                .allowsHitTesting(false)
                            RoundedRectangle(cornerRadius: 20,
                                             style: .continuous)
                                .stroke(braise, lineWidth: 5)
                                .blur(radius: 7)
                                .frame(width: r.width, height: r.height)
                                .position(x: r.midX, y: r.midY)
                                .opacity(0.55 * vie)
                                .blendMode(.screen)
                                .allowsHitTesting(false)
                        }
                        if let c = cardRect {
                            Text("Choisis ton premier exercice")
                                .font(.inter(13, .medium))
                                .foregroundStyle(Color.white.opacity(0.85))
                                .position(x: max(c.midX, 110),
                                          y: c.maxY + 24)
                                .opacity(k1)
                                .allowsHitTesting(false)
                        }
                        if let d = dialRect {
                            Text("La molette filtre")
                                .font(.inter(12, .medium))
                                .foregroundStyle(Color.white.opacity(0.7))
                                .position(x: d.minX - 8, y: d.minY - 18)
                                .opacity(k2)
                                .allowsHitTesting(false)
                        }
                    }
                }
                // Le hit-test sur les fenêtres PLEINES (pas celles en
                // cours d'ouverture) : les taps y passent dès le début —
                // un tuto n'est jamais un mur.
                .contentShape(.interaction,
                              VoileTuto(trous: [cardRect, dialRect]
                                  .compactMap { $0 }),
                              eoFill: true)
                .onTapGesture { eteindreTuto() }
            }
            .ignoresSafeArea()
            .transition(.opacity)
        }
    }

    private func cardColumn(_ indices: [Int]) -> some View {
        let list = shown
        return LazyVStack(spacing: Self.gutter) {
            ForEach(Array(indices.enumerated()), id: \.element) { row, i in
                let exercise = list[i]
                Button {
                    if veilT(i) < 0.35 {
                        deepLinked = exercise
                    } else {
                        // Une carte prise dans le voile se REJOINT d'abord :
                        // le scroll la remonte, avec le souffle et l'impact.
                        focusPulse += 1
                        ArcChime.shared.card()
                        withAnimation(.spring(response: 0.5,
                                              dampingFraction: 0.8)) {
                            scrolledID = exercise.id
                        }
                    }
                } label: {
                    ExerciseCard(exercise: exercise)
                }
                .buttonStyle(CardPressStyle())
                .id(exercise.id)
                // L'ancre du tuto : la PREMIÈRE card publie son rect —
                // le projecteur se découpe dessus (l'école SlotAnchorKey).
                .anchorPreference(key: SlotAnchorKey.self,
                                  value: .bounds) {
                    i == 0 ? ["tuto-card": $0] : [:]
                }
                // La cascade du changement de section : chaque carte arrive
                // en montant, avec un léger retard par rangée — on
                // redistribue les cartes, on ne les téléporte pas.
                .transition(.asymmetric(
                    insertion: AnyTransition.opacity
                        .combined(with: .offset(y: 26))
                        .animation(.spring(response: 0.5, dampingFraction: 0.82)
                            .delay(Double(row) * 0.04)),
                    removal: AnyTransition.opacity
                        .combined(with: .offset(y: 12))
                        .animation(.easeIn(duration: 0.16))
                ))
                // Le voile du footer : flou + extinction fonction de la
                // distance du bas de la carte au bord bas du viewport —
                // même loi que `veilT`, côté GPU.
                .visualEffect { content, proxy in
                    let f = proxy.frame(in: .scrollView)
                    let vh = proxy.bounds(of: .scrollView)?.height ?? 780
                    let t = min(max(1.0 - (vh - f.maxY) / 210, 0), 1)
                    return content
                        .blur(radius: 9 * t * t)
                        .opacity(1 - 0.5 * t * t)
                }
            }
        }
    }
}

/// Le voile du tuto : la page entière MOINS les fenêtres (evenOdd).
private struct VoileTuto: Shape {
    var trous: [CGRect]
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addRect(rect)
        for t in trous {
            p.addRoundedRect(in: t,
                             cornerSize: CGSize(width: 20, height: 20),
                             style: .continuous)
        }
        return p
    }
}

// MARK: - Le fond nuit + halo braise

/// L'hôte du shader `exosHalo` : le pattern AuroraFloor — TimelineView 30 Hz,
/// rectangle plein (JAMAIS `.clear` : le `* color.a` final avale tout), temps
/// absolu modulo 900 s. `pulseAt` : l'horodatage du dernier choix de section —
/// la pulsation est une fonction pure de l'âge, recalculée par image.
private struct ExosHaloBackground: View {
    var pulseAt: Date?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0,
                                    paused: reduceMotion)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 900)
                let pulse: Double = {
                    guard let at = pulseAt else { return 0 }
                    let a = timeline.date.timeIntervalSince(at)
                    guard a >= 0, a < 2 else { return 0 }
                    return min(a / 0.08, 1.0) * exp(-a / 0.35)
                }()
                Rectangle()
                    .fill(.white)
                    .colorEffect(ShaderLibrary.exosHalo(
                        .float2(geo.size.width, geo.size.height),
                        .float(t),
                        .float(pulse)
                    ))
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - La couronne (molette v5)

/// Le filtre de la page. AUCUNE surface, aucun rail : un anneau de
/// graduations fines dont le DÉGRADÉ DE LUMIÈRE fait la forme (blanches au
/// point focal, extinction cosinus le long de l'arc — la référence de
/// Kathryn), autour d'une petite couronne de verre liquide fumé aux deux
/// tiers posée sur le bord. Les labels : casse naturelle, encre dégradé
/// blanc, l'actif net, les voisins floutés — le flou est la seule profondeur.
/// Les graduations et le cran d'index TOURNENT avec le tambour sous le
/// dégradé fixe : c'est le défilement des traits sous la lumière qui fait la
/// rotation. Au doigt posé : la scène derrière s'éteint (ExercisesView), la
/// fumée du compteur s'échappe de la couronne, les labels s'éventaillent et
/// grossissent. La physique ne change pas : crans aimantés, élastique aux
/// bouts, tick + vibration par cran.
private struct ArcDial: View {
    @Binding var selection: ExerciseCategory?
    /// Le doigt est posé : ExercisesView éteint la scène derrière.
    @Binding var engaged: Bool

    /// Position continue sur le tambour, en crans (0 = Tout).
    @State private var pos: Double = 0
    @State private var dragBase: Double?
    @State private var detent = 0
    /// Les horodatages du toucher : la fumée et l'onde en sont des fonctions
    /// pures recalculées par image — aucune mutation par frame.
    @State private var touchStart: Date?
    @State private var touchEnd: Date?

    private static let items: [(String, ExerciseCategory?)] = {
        var all: [(String, ExerciseCategory?)] = [("Tout", nil)]
        for category in ExerciseCategory.allCases {
            all.append((category.rawValue, category))
        }
        return all
    }()

    /// La géométrie : couronne presque posée sur le bord, graduations
    /// serrées autour d'elle (pas de 5°, mesuré sur la référence), labels
    /// en éventail SEULEMENT à l'engagement — au repos, l'actif vit en petit
    /// sous la couronne, dans le couloir de nuit, jamais sur les cartes.
    private let knobR: CGFloat = 44
    private let ringR: CGFloat = 72

    /// La largeur du couloir de nuit : la SEULE bande où la molette prend le
    /// doigt. La grille s'en sert pour son encart droit — les deux DOIVENT
    /// rester accordées, sans quoi la molette mange les cartes ou l'inverse.
    static let touchCorridor: CGFloat = 112
    private let tickPitch: Double = .pi / 36
    private let labelSpacing: Double = 0.52

    var body: some View {
        GeometryReader { geo in
            let kx = geo.size.width - 28
            let ky = geo.size.height / 2
            ZStack {
                smoke(kx: kx, ky: ky, w: geo.size.width, h: geo.size.height)
                knob(kx: kx, ky: ky)
                ticks(kx: kx, ky: ky)
                restLabel(kx: kx, ky: ky)
                labels(kx: kx, ky: ky)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            // La molette DESSINE sur toute sa largeur (l'éventail des labels
            // déborde sur les cartes, c'est le spectacle) mais ne REÇOIT le
            // doigt que sur le couloir de nuit — sinon sa zone tactile de
            // 240 pt avale la colonne droite du Pinterest (qui s'arrête à
            // 112 pt du bord) et taper une carte engage le tambour.
            .allowsHitTesting(false)
            .overlay(alignment: .trailing) {
                Color.clear
                    .frame(width: Self.touchCorridor)
                    .contentShape(Rectangle())
                    .gesture(drag)
            }
        }
        .sensoryFeedback(.selection, trigger: detent)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: engaged)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Filtre de catégorie")
        .accessibilityValue(Self.items[Int(pos.rounded())].0)
        .accessibilityAdjustableAction { direction in
            let maxPos = Double(Self.items.count - 1)
            let next = direction == .increment ? min(pos.rounded() + 1, maxPos)
                                               : max(pos.rounded() - 1, 0)
            pos = next
            selection = Self.items[Int(next)].1
        }
    }

    /// La fumée : montée uniquement pendant et juste après le toucher — au
    /// repos ce sous-arbre n'existe pas, coût nul.
    @ViewBuilder
    private func smoke(kx: CGFloat, ky: CGFloat,
                       w: CGFloat, h: CGFloat) -> some View {
        if let start = touchStart {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let now = timeline.date
                let age = now.timeIntervalSince(start)
                let attack = min(age / 0.10, 1.0)
                let release = touchEnd.map { now.timeIntervalSince($0) } ?? 0
                let puff = attack * exp(-max(release, 0) / 0.45)
                let t = now.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 900)
                Rectangle()
                    .fill(.white)
                    .colorEffect(ShaderLibrary.knobSmoke(
                        .float2(w, h),
                        .float(t),
                        .float4(kx, ky, knobR, ringR),
                        .float(puff),
                        .float(age)
                    ))
            }
            .allowsHitTesting(false)
        }
    }

    /// La couronne : du VRAI verre liquide — un murmure de braise derrière
    /// le disque (le verre a enfin quelque chose à réfracter), un dôme
    /// spéculaire large et faible (la règle du piano black), un arc de
    /// reflet interne en bas, un liseré hairline qui RESPIRE à deux sinus
    /// incommensurables, et le cran d'index qui tourne avec le tambour.
    private func knob(kx: CGFloat, ky: CGFloat) -> some View {
        let drumDelta = -pos * labelSpacing
        return ZStack {
            // Le murmure de braise : quasi imperceptible en soi, il n'existe
            // que réfracté par le verre — c'est lui qui rend le disque
            // LIQUIDE au lieu de plat.
            RadialGradient(
                colors: [Color(red: 1.0, green: 0.72, blue: 0.38)
                             .opacity(engaged ? 0.22 : 0.13),
                         .clear],
                center: .center, startRadius: 2, endRadius: knobR * 1.45
            )
            .frame(width: knobR * 3, height: knobR * 3)

            Color.clear
                .frame(width: knobR * 2, height: knobR * 2)
                .glassEffect(.regular.tint(Color.black.opacity(0.20))
                                 .interactive(),
                             in: .circle)
                .overlay {
                    // Dôme spéculaire : LARGE et FAIBLE — au-delà, le verre
                    // noir devient plastique.
                    Circle().fill(
                        RadialGradient(
                            colors: [.white.opacity(0.11), .clear],
                            center: UnitPoint(x: 0.42, y: 0.16),
                            startRadius: 1, endRadius: knobR * 1.35
                        )
                    )
                }
                .overlay {
                    // L'arc de reflet interne, couché contre le bord bas.
                    Circle()
                        .inset(by: 3.5)
                        .trim(from: 0.14, to: 0.36)
                        .stroke(Color.white.opacity(0.10),
                                style: StrokeStyle(lineWidth: 4,
                                                   lineCap: .round))
                        .blur(radius: 2.6)
                }
                .overlay {
                    // Le liseré vivant : la respiration des icônes de la nav.
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                        let clock = tl.date.timeIntervalSinceReferenceDate
                        let warm = 0.5 + 0.5 * sin(clock * 0.83)
                        let cool = 0.5 + 0.5 * sin(clock * 0.57 + 1.7)
                        Circle().strokeBorder(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(
                                        (engaged ? 0.55 : 0.30) + 0.12 * warm),
                                          location: 0.0),
                                    .init(color: .white.opacity(0.05 + 0.03 * cool),
                                          location: 0.55),
                                    .init(color: .white.opacity(0.0), location: 1.0)
                                ],
                                startPoint: .top, endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                    }
                }
                .overlay {
                    Circle()
                        .fill(Color.white.opacity(engaged ? 0.85 : 0.50))
                        .frame(width: 3.5, height: 3.5)
                        .offset(x: -(knobR - 11) * CGFloat(cos(drumDelta)),
                                y: -(knobR - 11) * CGFloat(sin(drumDelta)))
                }
        }
        .position(x: kx, y: ky)
    }

    /// L'anneau de graduations — la référence copiée : RIEN que des traits,
    /// blancs au focal (côté cartes), extinction cosinus le long de l'arc.
    /// Chaque trait est LUI-MÊME un dégradé (pied vif côté disque, pointe
    /// évanescente), sa longueur suit la lumière, et les plus brillants
    /// portent un bloom très doux — c'est la gravure de la référence.
    private func ticks(kx: CGFloat, ky: CGFloat) -> some View {
        let drum = pos * labelSpacing
        let boost: Double = engaged ? 1.0 : 0.72
        return ForEach(0..<72, id: \.self) { k in
            let theta = Double(k) * tickPitch - drum
            let delta = abs(atan2(sin(theta - .pi), cos(theta - .pi)))
            let fade = pow(max(0.0, cos(delta * 0.82)), 1.6) * boost
            if fade > 0.02 {
                Capsule()
                    .fill(LinearGradient(
                        stops: [
                            .init(color: .white.opacity(fade), location: 0.0),
                            .init(color: .white.opacity(fade * 0.45),
                                  location: 0.62),
                            .init(color: .white.opacity(0.0), location: 1.0)
                        ],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(width: 1.1, height: 9 + 5 * fade)
                    .shadow(color: .white.opacity(max(0.0, (fade - 0.78) * 1.1)),
                            radius: 2.5)
                    .rotationEffect(.radians(theta - .pi / 2))
                    .position(x: kx + ringR * CGFloat(cos(theta)),
                              y: ky + ringR * CGFloat(sin(theta)))
            }
        }
    }

    /// Au repos : l'actif en PETIT, sous la couronne, dans le couloir de
    /// nuit — plus jamais un grand nom couché sur les cartes.
    private func restLabel(kx: CGFloat, ky: CGFloat) -> some View {
        let idx = Int(min(max(pos.rounded(), 0),
                          Double(Self.items.count - 1)))
        return Text(Self.items[idx].0)
            .font(.inter(12.5, .medium))
            .tracking(0.3)
            .foregroundStyle(WoopGradient.silverText)
            .fixedSize()
            .opacity(engaged ? 0.0 : 0.80)
            .blur(radius: engaged ? 4 : 0)
            .position(x: kx, y: ky + knobR + 24)
            .allowsHitTesting(false)
    }

    /// À l'engagement : le grand éventail se déploie — casse naturelle,
    /// encre dégradé blanc, le flou pour seule profondeur. Il PEUT passer
    /// sur les cartes : elles sont éteintes, le chevauchement est le
    /// spectacle. Au repos, il n'existe pas.
    private func labels(kx: CGFloat, ky: CGFloat) -> some View {
        let labelR: CGFloat = engaged ? 124 : 96
        return ForEach(0..<Self.items.count, id: \.self) { i in
            let delta = (Double(i) - pos) * labelSpacing
            let n = abs(delta) / labelSpacing
            Text(Self.items[i].0)
                .font(.inter(22, .semibold))
                .tracking(0.4)
                .foregroundStyle(WoopGradient.silverText)
                .fixedSize()
                .blur(radius: 2.6 * min(n, 2.0))
                .opacity(engaged ? (n < 0.5 ? 1.0 : max(0.16, 0.85 - 0.30 * n))
                                 : 0.0)
                .scaleEffect((engaged ? 1.0 : 0.55)
                             * max(0.5, 1.0 - 0.28 * min(n, 1.8)))
                .rotationEffect(.radians(-delta * 0.9))
                .position(x: kx - labelR * CGFloat(cos(delta)),
                          y: ky - labelR * CGFloat(sin(delta)))
                .allowsHitTesting(false)
        }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragBase == nil {
                    touchStart = .now
                    touchEnd = nil
                    engaged = true
                }
                let base = dragBase ?? pos
                dragBase = base
                let maxPos = Double(Self.items.count - 1)
                // Le tambour suit le doigt : ~100 pt de glisse par cran.
                var p = base + Double(value.translation.height) / 100.0
                // Élastique aux extrémités : le tambour résiste, il ne bute pas.
                if p < 0 { p *= 0.30 }
                if p > maxPos { p = maxPos + (p - maxPos) * 0.30 }
                pos = p
                let d = Int(min(max(p, 0), maxPos).rounded())
                if d != detent {
                    detent = d
                    ArcChime.shared.tick()
                }
            }
            .onEnded { _ in
                dragBase = nil
                engaged = false
                touchEnd = .now
                // La fumée finit de se dissoudre, puis son hôte se démonte —
                // sauf si un nouveau toucher a repris entre-temps.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    if touchEnd != nil { touchStart = nil; touchEnd = nil }
                }
                let maxPos = Double(Self.items.count - 1)
                let snapped = min(max(pos.rounded(), 0), maxPos)
                withAnimation(.spring(response: 0.34, dampingFraction: 0.76)) {
                    pos = snapped
                }
                let idx = Int(snapped)
                if Self.items[idx].1 != selection {
                    withAnimation(.easeOut(duration: 0.28)) {
                        selection = Self.items[idx].1
                    }
                    ArcChime.shared.pose()
                }
            }
    }
}

// MARK: - Les sons de la couronne et de la grille

/// Les voix du cadran éclipse, reprises : le tick des crans, le souffle de la
/// pose, le tock d'une carte qui remonte du voile. `.ambient` +
/// `mixWithOthers` — jamais par-dessus la musique de la salle.
@MainActor
final class ArcChime {
    static let shared = ArcChime()

    private let tickPlayer: AVAudioPlayer?
    private let posePlayer: AVAudioPlayer?
    private let cardPlayer: AVAudioPlayer?

    private init() {
        try? AVAudioSession.sharedInstance()
            .setCategory(.ambient, options: [.mixWithOthers])
        func load(_ name: String) -> AVAudioPlayer? {
            guard let url = Bundle.main.url(forResource: name,
                                            withExtension: "wav") else {
                return nil
            }
            let player = try? AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            return player
        }
        tickPlayer = load("DialTick")
        posePlayer = load("DialTap")
        cardPlayer = load("DialTock")
    }

    func tick() { play(tickPlayer, volume: 0.38) }
    func pose() { play(posePlayer, volume: 0.55) }
    func card() { play(cardPlayer, volume: 0.50) }

    private func play(_ player: AVAudioPlayer?, volume: Float) {
        guard let player else { return }
        player.volume = volume
        player.currentTime = 0
        player.play()
    }
}

// MARK: - Carte d'exercice

/// Le zoom et la vibration du tap : la carte répond sous le doigt — un
/// tassement bref, un impact — avant de partir vers la fiche.
private struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.72),
                       value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .medium, intensity: 0.85),
                             trigger: configuration.isPressed) { _, pressed in
                pressed
            }
    }
}

struct ExerciseCard: View {
    let exercise: Exercise

    private static let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

    /// Le noir de la carte : PUR sur toute la zone de la photo — le contrat
    /// qui fond les images sans couture — soulevé en métal léger seulement
    /// sous le bloc texte. SANS BORDURE : sur la page nuit, c'est le halo qui
    /// passe derrière qui dessine la silhouette.
    private static let noirMetal = LinearGradient(
        stops: [
            .init(color: .black, location: 0.0),
            .init(color: .black, location: 0.58),
            .init(color: Color(red: 0.049, green: 0.051, blue: 0.061), location: 0.85),
            .init(color: Color(red: 0.086, green: 0.090, blue: 0.102), location: 1.0)
        ],
        startPoint: .top, endPoint: .bottom
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // La vignette : réduite, centrée, FONDUE — les deux masques
            // chaînés du héros de la fiche (ils se multiplient : les quatre
            // bords s'évaporent dans le noir pur de la carte).
            ExercisePhoto(exercise: exercise)
                .frame(width: 88, height: 88)
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .white, location: 0.18),
                            .init(color: .white, location: 0.82),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                }
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .white, location: 0.18),
                            .init(color: .white, location: 0.82),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .leading, endPoint: .trailing
                    )
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 14)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name)
                    .font(.inter(11.5, .semibold))
                    .foregroundStyle(Color.inkPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(exercise.muscle)
                    .font(.inter(9.5))
                    .foregroundStyle(Color.white.opacity(0.46))
                    .lineLimit(1)

                Text(exercise.equipment.rawValue.uppercased())
                    .font(.inter(7.5, .bold))
                    .tracking(0.7)
                    .foregroundStyle(Color.white.opacity(0.32))
                    .padding(.horizontal, 5).padding(.vertical, 2.5)
                    .background(Capsule().fill(Color.white.opacity(0.05)))
                    .padding(.top, 2)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { Self.shape.fill(Self.noirMetal) }
        .clipShape(Self.shape)
    }
}
