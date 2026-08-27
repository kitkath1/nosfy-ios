import SwiftUI
import SwiftData

// MARK: - Ce que la story raconte

/// Une série. Le modèle de l'app porte `reps` et `weight` (`StrengthSet`) ;
/// les pièces, elles, n'existent nulle part encore — il n'y a pas d'économie
/// de jetons dans le modèle, `gain` a toujours été passé de l'extérieur. Elles
/// sont donc posées à la main pour l'instant, et le jour où la règle existera
/// c'est le seul endroit à changer.
struct StorySet: Identifiable {
    let id = UUID()
    let rank: Int
    let reps: Int
    let kilos: Double
    let coins: Int
}

/// LE SPORT D'UNE SÉANCE D'EXCEPTION (« TOP SESSION », 26-08 soir) :
/// la meilleure séance de la semaine, cardio ou musculation. Le
/// déclencheur VIENDRA du fact engine (plan backend §4 quater) — ici ne
/// vit que la donnée, et le banc qui la force.
enum TopSport {
    case cardio, muscu

    /// La pastille (les paillettes de Kathryn, détourées TS1).
    var pastille: String {
        self == .cardio ? "sticker-pastille-basket"
                        : "sticker-pastille-haltere"
    }
    /// Les deux lignes géantes (le contrat bigLines : 3-9 signes —
    /// gabarits du banc, l'IA remplira le même moule).
    var bigLines: [String] {
        self == .cardio ? ["TOP", "RUN"] : ["TOP", "LIFT"]
    }
    var sousTexte: String {
        self == .cardio ? "Your best cardio this week."
                        : "Your best lifting this week."
    }
    /// Le titre de la card — le registre des autres cards rewards.
    var titre: String {
        self == .cardio ? "Top Cardio" : "Top Lifting"
    }
}

/// LE FAIT « ×2 » : les deux séances du jour local, RECOPIÉES (la
/// mini-card montre leurs heures — jamais inventées, backend §4 septies).
struct DoubleFait {
    /// Les heures de début des deux séances, « HH:mm », dans l'ordre.
    var heures: [String]
    /// Le total des minutes du jour.
    var minutes: Int
}

/// Le récit d'une séance, découplé de SwiftData pour que le banc puisse le
/// fabriquer sans base.
struct StorySession {
    var title: String
    var dateLabel: String
    var minutes: Int
    var exos: Int
    var series: Int
    var kcal: Int
    var sets: [StorySet]
    /// La partition par exercice (la grammaire de l'ardoise) : quand elle
    /// est là, la story 2 pose `SlateListe` — la liste dépliable, ses
    /// petites flammes — à la place des cinq lignes plates.
    var groupes: [SlateGroupe] = []
    /// L'EXCEPTION : quand la séance est la meilleure de la semaine, la
    /// story ouvre sur la page TOP SESSION (4 pages ce jour-là).
    var top: TopSport? = nil
    /// L'AUTRE EXCEPTION (27-08, plan ../rewards/PLAN-VARIANT-X2.md) :
    /// la DEUXIÈME séance du même jour — la story ouvre sur la page
    /// « ×2 ». Si TOP et ×2 tombent le même jour, ×2 prend la page
    /// d'ouverture (c'est le jour ; la semaine attendra — Q3 du plan).
    var double: DoubleFait? = nil

    /// Les valeurs de la maquette — partition comprise, pour que le banc
    /// `-storyLab` montre la liste dépliable de la story 2.
    static let demo: StorySession = {
        var s = StorySession(
            title: "Haut du corps",
            dateLabel: "Séance du 12 janvier",
            minutes: 42, exos: 7, series: 18, kcal: 310,
            sets: [
                StorySet(rank: 1, reps: 12, kilos: 20, coins: 20),
                StorySet(rank: 2, reps: 12, kilos: 24, coins: 15),
                StorySet(rank: 3, reps: 15, kilos: 18, coins: 12),
                StorySet(rank: 4, reps: 10, kilos: 30, coins: 18),
                StorySet(rank: 5, reps: 8, kilos: 35, coins: 18)
            ])
        let all = ExerciseCatalog.all
        s.groupes = (0..<3).map { i in
            let exo = all[(i * 5) % all.count]
            // 3, 4 puis SEPT séries : le troisième exercice couvre le cas
            // « plus de cinq » de la rangée de flammes (cinq stickers et
            // un « +2 »), qu'aucune donnée de démo ne montrait.
            let combien = [3, 4, 7][i]
            return SlateGroupe(
                id: "\(i)-\(exo.id)", exercise: exo,
                rows: (0..<combien).map { r in
                    SlateLigne(reps: 12 - r, kilos: 20 + Double(r) * 2,
                               seconds: 52 + r * 9, done: true)
                })
        }
        return s
    }()

    /// La lecture d'une vraie séance. Les cinq séries montrées sont les cinq
    /// premières de la séance, tous exercices confondus.
    init(workout: Workout) {
        title = workout.categories.first?.rawValue ?? "Séance"
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "d MMMM"
        dateLabel = "Séance du " + f.string(from: workout.startedAt)
        minutes = max(1, Int(workout.duration / 60))
        exos = workout.orderedExercises.count
        let all = workout.orderedExercises.flatMap { $0.sets ?? [] }
        series = all.count
        // Une estimation franche tant qu'il n'y a pas de calcul de dépense :
        // sept kilocalories par minute d'effort.
        kcal = minutes * 7
        // Les mêmes gains que la maquette, tant que l'économie n'existe pas.
        let purse = [20, 15, 12, 18, 18]
        sets = all.prefix(5).enumerated().map { i, s in
            StorySet(rank: i + 1, reps: s.reps, kilos: s.weight,
                     coins: purse[i % purse.count])
        }
        if sets.isEmpty { sets = StorySession.demo.sets }
        // La partition : les mêmes groupes que l'ardoise (le barème de
        // `SessionSlate.buildGroupes`, côté séance persistée).
        groupes = workout.orderedExercises.compactMap { le in
            guard let exo = le.exercise, !le.orderedSets.isEmpty
            else { return nil }
            return SlateGroupe(
                id: le.exerciseID, exercise: exo,
                rows: le.orderedSets.map {
                    SlateLigne(reps: $0.reps, kilos: $0.weight,
                               seconds: $0.isDone ? $0.durationSeconds
                                                  : le.restSeconds,
                               done: $0.isDone)
                })
        }
    }

    init(title: String, dateLabel: String, minutes: Int, exos: Int,
         series: Int, kcal: Int, sets: [StorySet]) {
        self.title = title; self.dateLabel = dateLabel
        self.minutes = minutes; self.exos = exos
        self.series = series; self.kcal = kcal; self.sets = sets
    }
}

/// Ce qu'il faut pour ouvrir une story : la séance, et le rectangle de la
/// carte d'où elle sort.
struct StoryLaunch: Identifiable {
    let id = UUID()
    let workout: Workout
    let rect: CGRect
}

// MARK: - La partition

enum StoryCine {
    /// LES DURÉES D'ÉCRAN. La première porte l'intro cinématique EN PLUS de
    /// son temps de lecture : la verrière SESSION ENDED (zoom, défilement,
    /// plongeon — 4,8 s), puis le résumé qui se lit (voir `EndedCine`).
    static let hold: [Double] = [12.6, 7.0, 7.0]

    /// L'OUVERTURE DU PORTAIL — le rectangle de la carte devient l'écran.
    static let portal: Double = 0.62
    /// LE DÉZOOM. Départ raide, très longue traîne : c'est la traîne qui fait
    /// le luxe, pas l'amplitude.
    static let dezoom: Double = 2.40
    /// Le grossissement de départ, en multiples de l'échelle qui remplit
    /// l'écran. 2,4 fois : au-delà on ne lit plus la scène, en deçà ce n'est
    /// plus une entrée.
    static let punch: CGFloat = 2.40
    /// LA FENÊTRE SE REFERME à 60 % de hauteur, une fois le dézoom posé. Une
    /// seule chose bouge à la fois — la course d'avant finit à vitesse NULLE
    /// et celle-ci démarre à vitesse nulle, donc pas d'angle à la jonction.
    static let windowAt: Double = 2.40
    static let windowFor: Double = 0.72
    /// La part de la hauteur d'écran que garde la vidéo, au repos.
    static let windowShare: CGFloat = 0.60
    /// Le contenu entre pendant que la fenêtre se referme.
    static let contentAt: Double = 2.62

    /// Le pas doux de la maison. Chaque cinématique porte sa copie — la
    /// maison ne partage pas cette fonction.
    static func sstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let u = min(max((x - a) / (b - a), 0), 1)
        return u * u * (3 - 2 * u)
    }

    /// Une sortie à traîne longue : dérivée forte au départ, NULLE à
    /// l'arrivée. C'est la courbe du dézoom.
    static func outLong(_ u: Double, _ k: Double = 3.4) -> Double {
        let c = min(max(u, 0), 1)
        return 1 - pow(1 - c, k)
    }
}

// MARK: - Les indicateurs

/// Les trois segments du haut. Pilotés par l'horloge, JAMAIS par une animation
/// sur une largeur : une animation dérive, ne sait pas se mettre en pause à
/// mi-course, et repart de travers quand on saute une page.
struct StoryProgress: View {
    let count: Int
    let current: Int
    /// L'avancement de la page en cours, 0 → 1.
    let progress: Double

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<count, id: \.self) { i in
                GeometryReader { geo in
                    let fill: Double = i < current ? 1
                        : (i == current ? min(max(progress, 0), 1) : 0)
                    ZStack(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.18))
                        Capsule(style: .continuous)
                            .fill(LinearGradient(
                                colors: [Color.white.opacity(0.92),
                                         Color(red: 0.98, green: 0.86,
                                               blue: 0.66)],
                                startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(0, geo.size.width * fill))
                    }
                }
                .frame(height: 2.5)
            }
        }
    }
}

// MARK: - Le flot

/// Trois écrans, sept secondes chacun, un tap pour passer. La grammaire
/// d'Instagram, dans la nuit de Woop.
struct StoryFlow: View {
    let session: StorySession
    /// L'avancement du portail, 0 → 1. Le contenu ne démarre sa partition
    /// qu'une fois le portail ouvert : sinon la cinématique court derrière un
    /// masque fermé.
    var onClose: () -> Void = {}

    @State private var page = 0
    @State private var beat = 0
    @State private var pageStart = Date.now
    @State private var pausedAt: Date? = nil
    /// La descente au doigt, pour la fermeture.
    @State private var fall: CGFloat = 0
    @State private var pressStart: Date? = nil
    @State private var pressToken = 0
    @State private var moved = false
    @State private var tapBeat = 0
    /// Le cadre de la partition de la story 2, dans le repère du flux :
    /// un tap né dedans appartient à la liste (il déplie), le chef ne
    /// rend aucun verdict de page. Mesuré par la page qui la porte,
    /// remis à zéro à
    /// chaque changement de page.
    @State private var partitionRect: CGRect = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var paused: Bool { pausedAt != nil }

    // MARK: La table des pages

    /// Les rôles d'écran. L'ordre est LA grammaire : l'exception
    /// s'insère AVANT le résumé (« la première vue de la story »).
    enum PageRole { case ouverture, resume, details, analyse, butin }

    /// Trois pages les jours ordinaires (l'ouverture PORTE le résumé,
    /// c'est son acte B) ; quatre les jours d'exception.
    private var roles: [PageRole] {
        exception == nil
            ? [.ouverture, .details, .analyse, .butin]
            : [.ouverture, .resume, .details, .analyse, .butin]
    }
    /// La page d'ouverture d'exception, s'il y en a une : ×2 d'abord
    /// (le jour), TOP sinon (la semaine).
    private var exception: StoryEnded.Mode? {
        if session.double != nil { return .double }
        if session.top != nil { return .top }
        return nil
    }
    private func pageRole(_ p: Int) -> PageRole {
        roles[min(max(p, 0), roles.count - 1)]
    }
    private var dernier: Int { roles.count - 1 }
    /// Les durées, par rôle — la page TOP garde le hold de l'ouverture,
    /// le résumé seul se lit plus vite.
    private func duree(_ p: Int) -> Double {
        switch pageRole(p) {
        case .ouverture: return StoryCine.hold[0]
        case .resume: return 6.5
        case .details: return StoryCine.hold[1]
        case .analyse: return StoryCine.hold[2]
        // Le butin : la chorégraphie (pièce, compteur, plaquages) puis
        // la lecture.
        case .butin: return 8.0
        }
    }

    var body: some View {
        GeometryReader { geo in
            let H = geo.size.height
            ZStack {
                Color.black.ignoresSafeArea()

                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
                    let now = tl.date
                    let t = clock(now)
                    ZStack {
                        Group {
                            // LA PAGINATION SUIT L'EXCEPTION : un jour
                            // « top session », la verrière plonge dans
                            // la page TOP (mode .top) et le résumé
                            // devient SA page — quatre écrans. Les jours
                            // ordinaires, trois. L'ancien `StoryOne`
                            // (lune néon) attend le verdict — rien n'est
                            // supprimé.
                            switch pageRole(page) {
                            case .ouverture:
                                StoryEnded(session: session, t: t,
                                           now: now, size: geo.size,
                                           paused: paused,
                                           mode: exception ?? .complet)
                            case .resume:
                                StoryEnded(session: session, t: t,
                                           now: now, size: geo.size,
                                           paused: paused, mode: .resume)
                            case .details:
                                StoryDetails(session: session, t: t,
                                             now: now, size: geo.size,
                                             paused: paused,
                                             onPartitionRect: {
                                                 partitionRect = $0
                                             })
                            case .analyse:
                                StoryAnalyse(session: session, t: t,
                                             now: now, size: geo.size,
                                             paused: paused,
                                             onPartitionRect: {
                                                 partitionRect = $0
                                             })
                            // LE BUTIN (26-08 nuit) : la pièce du
                            // coffre, le compteur, les boosters.
                            case .butin:
                                StoryWin(session: session, t: t,
                                         size: geo.size, paused: paused,
                                         onCardRect: {
                                             partitionRect = $0
                                         })
                            }
                        }
                        .id(beat)
                        .transition(.opacity)

                        // Les indicateurs, au-dessus de tout. Ils vivent DANS
                        // l'horloge : une barre de progression pilotée par une
                        // animation dérive et ne sait pas reprendre après une
                        // pause.
                        VStack {
                            StoryProgress(
                                count: roles.count, current: page,
                                progress: t / duree(page))
                                .padding(.horizontal, 14)
                                .padding(.top, 10)
                            Spacer()
                        }
                    }
                }
            }
            // LA DESCENTE : la page suit le doigt avec de la résistance, et
            // ses coins s'arrondissent — elle redevient un objet qu'on repose.
            .scaleEffect(1 - min(fall / H, 0.22) * 0.5, anchor: .center)
            .clipShape(RoundedRectangle(cornerRadius: min(fall * 0.4, 44),
                                        style: .continuous))
            .offset(y: fall)
            .contentShape(Rectangle())
            // LE REPÈRE COMMUN : la partition se mesure et le chef écoute
            // dans le même espace nommé — on ne compare jamais deux
            // repères sans les aligner.
            .coordinateSpace(name: "storyFlow")
            // SIMULTANÉ, pas exclusif : un DragGesture à distance NULLE
            // posé en `.gesture` prend le doigt au contact et ANNULE les
            // Buttons enfants — les rangées de la partition ne se
            // dépliaient jamais. Le chef observe tout, décide au lâcher,
            // et renonce dans la zone de la partition.
            .simultaneousGesture(conductor(size: geo.size))
        }
        .background(Color.black)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.55),
                         trigger: tapBeat)
        .task(id: beat) { await conduct() }
    }

    // MARK: L'horloge

    /// Le temps écoulé sur la page, pause déduite.
    private func clock(_ now: Date) -> Double {
        (pausedAt ?? now).timeIntervalSince(pageStart)
    }

    /// L'avance automatique. Un `Task` par page plutôt qu'un `Timer` : il
    /// meurt tout seul quand la page change, et il respecte la pause sans
    /// avoir à jongler avec des invalidations.
    private func conduct() async {
        let d = duree(page)
        while !Task.isCancelled {
            if pausedAt == nil, Date.now.timeIntervalSince(pageStart) >= d {
                advance()
                return
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    // MARK: Le passage

    private func advance() {
        if page >= dernier { onClose(); return }
        go(to: page + 1)
    }

    private func go(to p: Int) {
        guard p >= 0, p <= dernier else { return }
        tapBeat += 1
        pageStart = .now
        pausedAt = nil
        // Le rect de la partition meurt avec sa page — la story 2 le
        // remesurera si elle revient.
        partitionRect = .zero
        // Jamais de coupe franche entre deux plans : un fondu court, et
        // l'identité change DANS l'animation pour que la transition existe.
        withAnimation(.easeInOut(duration: 0.30)) {
            page = p
            beat += 1
        }
    }

    // MARK: Le chef d'orchestre

    /// UN SEUL reconnaisseur pour le tap, l'appui long et la descente. Trois
    /// gestes empilés se disputent le doigt : on perd soit la pause, soit le
    /// tap, soit la fermeture. Ici tout est décidé au lâcher, sur la distance
    /// et la durée.
    private func conductor(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0,
                    coordinateSpace: .named("storyFlow"))
            .onChanged { v in
                if pressStart == nil {
                    pressStart = .now
                    moved = false
                    pressToken += 1
                    let token = pressToken
                    // L'APPUI LONG met la story en pause — l'horloge ET
                    // l'image. Armé à 240 ms : en deçà, un tap franc
                    // déclencherait une micro-pause visible.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                        guard pressToken == token, pressStart != nil,
                              !moved, pausedAt == nil else { return }
                        pausedAt = .now
                    }
                }
                if abs(v.translation.height) > 8
                    || abs(v.translation.width) > 8 { moved = true }
                // La descente ne prend QUE vers le bas, et avec de
                // l'élastique : suivi franc sur 90 pt, puis 28 %. JAMAIS
                // depuis la partition : en simultané, tirer la liste des
                // séries vers le bas emporterait toute la story.
                // Pages 1 ET 2 : la partition des Détails ET la story
                // card (le tilt au drag vit dedans) — un drag né là ne
                // tire pas la story vers le bas.
                if page >= 1, partitionRect.contains(v.startLocation) {
                    fall = 0
                } else {
                    let d = v.translation.height
                    fall = d > 0 ? min(d, 90) + max(d - 90, 0) * 0.28 : 0
                }
            }
            .onEnded { v in
                pressToken += 1
                let held = Date.now.timeIntervalSince(pressStart ?? .now)
                let wasPaused = pausedAt != nil
                pressStart = nil
                // Reprise : on décale le départ de la durée de la pause,
                // l'avancement reprend exactement où il s'était arrêté.
                if let p = pausedAt {
                    pageStart = pageStart.addingTimeInterval(
                        Date.now.timeIntervalSince(p))
                    pausedAt = nil
                }

                let down = v.translation.height
                let goDown = down > 110
                    || (down > 40 && v.predictedEndTranslation.height > 300)
                if goDown {
                    withAnimation(.easeIn(duration: 0.22)) { fall = 900 }
                    onClose()
                    return
                }
                withAnimation(.spring(response: 0.38,
                                      dampingFraction: 0.82)) { fall = 0 }

                // LE TAP : court, sans déplacement, et sans pause en cours.
                guard !moved, held < 0.5, !wasPaused else { return }
                // LA ZONE DE LA PARTITION (story 2) : un tap né dans la
                // liste appartient à la liste — il déplie une rangée, le
                // chef ne rend AUCUN verdict de page. Mais il REMET
                // l'horloge : tant qu'on explore, la story attend.
                // (Sans ça : la vignette d'un exercice vit dans le tiers
                // gauche → « je reviens à la première ».)
                // `clock > 0,95` : la partition ne FOND qu'à ~1 s — son
                // rect ne compte pas tant qu'elle est invisible.
                if page >= 1, clock(Date.now) > 0.95,
                   partitionRect.contains(v.startLocation) {
                    // L'horloge se PROLONGE sans rejouer l'entrée : recalée
                    // à 1,2 s (toutes les rampes d'entrée sont finies à
                    // 1,0), jamais à zéro — un reset nu faisait replonger
                    // la partition à opacité 0 et tout « clignotait ».
                    pageStart = Date.now.addingTimeInterval(-1.2)
                    return
                }
                // Le tiers gauche revient en arrière — la grammaire du genre.
                if v.location.x < size.width / 3 {
                    page == 0 ? go(to: 0) : go(to: page - 1)
                } else {
                    advance()
                }
            }
    }
}

// MARK: - Le portail

/// LE MORPH. La page story est montée PLEIN ÉCRAN dès le départ, vidéo déjà en
/// lecture, et c'est un MASQUE aux dimensions de la carte qui la découpe. Un
/// seul scalaire fait grandir ce masque jusqu'à l'écran entier. Lecture : la
/// carte s'OUVRE, elle ne se fait pas remplacer par un fondu.
///
/// Pas de `matchedGeometryEffect` : il n'y en a aucun dans tout le projet, et
/// il se battrait de toute façon contre l'hôte débordant du shader de la
/// carte. La maison anime à la main, la partition dans une seule fonction.
struct StoryPortal: View {
    /// Le rectangle de départ, en coordonnées ÉCRAN.
    let from: CGRect
    var fromRadius: CGFloat = 24
    let session: StorySession
    var onClose: () -> Void = {}

    @State private var open: CGFloat = 0
    @State private var closing = false

    /// Le rayon des coins de l'appareil. Un plein écran qui garde 24 de rayon
    /// a l'air d'une carte géante ; à zéro il a l'air d'une capture. Au rayon
    /// de l'écran, le masque disparaît. (Constante, et non l'API privée
    /// `_displayCornerRadius` : un nom de clé privé dans un binaire livré est
    /// un risque qu'un coin de masque ne vaut pas.)
    private let deviceRadius: CGFloat = 52

    var body: some View {
        GeometryReader { geo in
            let full = CGRect(origin: .zero, size: geo.size)
            // LE FILET. Si le rectangle de départ n'est pas arrivé (une
            // préférence qui n'a pas encore remonté, une pile vide), un
            // `.zero` ferait s'ouvrir le portail depuis le coin HAUT-GAUCHE en
            // 0 × 0 : une déchirure en diagonale au lieu d'une carte qui
            // s'ouvre. On retombe alors sur une carte au centre — le
            // mouvement reste juste, il part simplement d'ailleurs.
            let start: CGRect = from.width > 1 && from.height > 1 ? from
                : CGRect(x: (geo.size.width - 220) / 2,
                         y: (geo.size.height - 282) / 2,
                         width: 220, height: 282)
            let u = CGFloat(StoryCine.sstep(0, 1, Double(open)))
            let r = CGRect(
                x: start.minX + (full.minX - start.minX) * u,
                y: start.minY + (full.minY - start.minY) * u,
                width: start.width + (full.width - start.width) * u,
                height: start.height + (full.height - start.height) * u)
            StoryFlow(session: session, onClose: close)
                .mask {
                    RoundedRectangle(
                        cornerRadius: fromRadius
                            + (deviceRadius - fromRadius) * u,
                        style: .continuous)
                        .frame(width: r.width, height: r.height)
                        .position(x: r.midX, y: r.midY)
                }
        }
        .ignoresSafeArea()
        .background(Color.black.opacity(Double(open)).ignoresSafeArea())
        .onAppear {
            // LE COUP. `slam()` est l'enveloppe la plus lourde de l'app —
            // 0,72 s de pose. Le fichier de SwapFeedback documente pourquoi
            // `.sensoryFeedback(.impact(intensity: 1))` ne peut pas la
            // produire : ce n'est pas une secousse, c'est un atterrissage.
            SwapFeedback.shared.slam()
            withAnimation(.timingCurve(0.32, 0, 0.24, 1,
                                       duration: StoryCine.portal)) {
                open = 1
            }
        }
    }

    private func close() {
        guard !closing else { return }
        closing = true
        withAnimation(.timingCurve(0.4, 0, 0.7, 1, duration: 0.34)) {
            open = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) { onClose() }
    }
}

// MARK: - Le banc

/// `-storyLab`. La story rejouée en boucle depuis une carte factice posée là
/// où le deck de la Home pose la sienne — c'est la méthode maison pour juger
/// une cinématique : on la revoit toutes les N secondes sans y toucher.
struct StoryLab: View {
    @State private var run = 0
    @State private var showing = false
    /// `-storyAuto` ouvre la story tout seul et la rejoue : une cinématique se
    /// juge en la regardant COURIR, pas sur une image figée, et un doigt ne
    /// tire jamais deux fois pareil.
    private static let auto = CommandLine.arguments.contains("-storyAuto")

    /// L'EXCEPTION AU BANC : `-storyTop` force la page TOP SESSION
    /// cardio, `-storyTopMuscu` la muscu — le vrai déclencheur viendra
    /// du fact engine (backend §4 quater).
    private static var demoSession: StorySession {
        var s = StorySession.demo
        if CommandLine.arguments.contains("-storyTopMuscu") {
            s.top = .muscu
        } else if CommandLine.arguments.contains("-storyTop") {
            s.top = .cardio
        }
        // `-storyDouble` : la deuxième séance du jour — la page « ×2 ».
        if CommandLine.arguments.contains("-storyDouble") {
            s.double = DoubleFait(heures: ["07:12", "19:40"],
                                  minutes: s.minutes + 54)
        }
        return s
    }

    var body: some View {
        GeometryReader { geo in
            let card = CGRect(
                x: (geo.size.width - 220) / 2,
                y: geo.size.height * 0.42,
                width: 220, height: 282)
            ZStack {
                Color(red: 0.016, green: 0.016, blue: 0.024).ignoresSafeArea()
                if !showing {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.black)
                        .frame(width: 220, height: 282)
                        .position(x: card.midX, y: card.midY)
                        .overlay {
                            Text("glisse vers le haut")
                                .font(.inter(12))
                                .foregroundStyle(Color.inkMuted)
                                .position(x: card.midX, y: card.midY)
                        }
                        .gesture(
                            DragGesture(minimumDistance: 6)
                                .onEnded { v in
                                    if v.translation.height < -60 {
                                        showing = true
                                    }
                                })
                }
                if showing {
                    StoryPortal(from: card, session: Self.demoSession) {
                        showing = false
                        run += 1
                        if Self.auto {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                                showing = true
                            }
                        }
                    }
                    .id(run)
                }
            }
            .onAppear {
                guard Self.auto else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    showing = true
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
