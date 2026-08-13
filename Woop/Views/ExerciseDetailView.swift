import SwiftUI
import SwiftData

// MARK: - La fiche, qui est aussi l'éditeur

/// LA fiche d'un exercice — et son éditeur. Elle a absorbé l'ancienne feuille
/// modale `LogExerciseSheet` : il n'y a plus « consulter », puis « ouvrir pour
/// saisir ». Il y a un seul écran, où l'on règle et où l'on lance.
///
/// La page est NOIRE, et LA CARTE EST MORTE en musculation : plus de fond
/// posé, plus de découpe à grands coins — c'était cette arête franche à
/// 115 pt, avec le feu coupé net derrière, qui donnait la lecture « une
/// carte qui scrolle ». Le feu du header a désormais une QUEUE et s'éteint
/// tout seul dans la nuit de la page (voir `HeaderEmberCard`), la photo
/// monte dedans, et le titre passe SOUS elle, sur deux lignes. En plancher
/// le GALET D'AUBE — un galet de verre noir draggable où la lumière dort
/// (`LaunchPebble.swift`). Le cardio, lui, garde sa carte et son fond : sa
/// page défile, et un contenu qui défile a besoin d'un couteau.
/// L'ancien dôme blanc et son échancrure dorment, inutilisés, dans
/// `ExerciseSetupCard.swift` / `NotchedCard.swift`.
///
/// Le banc : `-exoLab` ouvre cette fiche seule (+ `-activeWorkout` pour voir
/// la pastille et son échancrure).
struct ExerciseDetailView: View {
    let exercise: Exercise

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]

    @State private var confirmation: String?

    // Le brouillon. Il vivait dans la feuille modale ; c'est désormais l'état de
    // la page elle-même. On part de ZÉRO série : la première naît du geste de
    // lancement, elle n'attend pas déjà là.
    @State private var sets: [DraftSet] = []
    @State private var restSeconds = 60
    @State private var phases: [DraftPhase] = [
        DraftPhase(kind: .repos, seconds: 30, speed: 6),
        DraftPhase(kind: .acceleration, seconds: 30, speed: 16)
    ]
    @State private var repeatCount = 1
    @State private var steadySeconds = 900
    @State private var steadySpeed: Double = 7
    @State private var incline: Double = 0

    /// Ce que la lumière du galet a déjà versé sur la page [0,1] — écrit
    /// par la fiche depuis la montée du doigt : le fond blanchit TRÈS
    /// vite, bien avant l'entrée de la bulle.
    @State private var flood: Double = 0

    /// LE GESTE UNIQUE : le doigt du galet, transmis vivant à la lentille
    /// (sa cinquième prise). Tant qu'il vit, c'est LUI qui porte la bulle
    /// du monde blanc — un seul geste, de la nuit au sommet.
    @State private var lensHandoff: LiquidLensLab.Handoff?
    /// Le battement du montage — l'haptique du dôme d'avant, au moment où
    /// la lentille entre.
    @State private var launchBeat = 0
    /// La taille plein écran, mémorisée pour le banc (les points de doigt
    /// synthétiques parlent l'espace de la lentille).
    @State private var pageFull = CGSize(width: 402, height: 874)

    /// La montée de la lentille (0 bord bas → 1 sommet) depuis un y plein
    /// écran — LE MÊME barème que `climbOf` du lab : les deux mondes
    /// mesurent le doigt avec la même règle. PIÈGE PAYÉ : h = 0 (une
    /// géométrie photographiée avant le premier layout) faisait un NaN
    /// qui empoisonnait `flood`, l'opacité du voile ET tous les uniforms
    /// du shader — le galet mourait pour toujours, sans un cri.
    private static func climbGlobal(y: CGFloat, h: CGFloat) -> Double {
        min(max(Double((h * 0.90 - y) / max(h * 0.72, 1)), 0), 1.06)
    }

    /// LES TROIS TEMPS du geste (verdict : « on doit voir le galet de la
    /// page exo monter ») : temps 1, la MONTÉE VISIBLE SUR LA NUIT —
    /// climb 0 → 0,14, le voile ne fait que se réchauffer (≤ 13 %) ;
    /// temps 2, l'AUBE — 0,14 → 0,22, le blanc verse sur ~50 pt de doigt,
    /// un battement qu'on VOIT ; temps 3, le RELAIS — la bulle, révélée
    /// en fondu papier-sur-papier, continue le galet sous le même doigt.
    ///
    /// La lentille est PRÉ-MONTÉE invisible à 0,10 : son shader chauffe
    /// sous la nuit, sa première frame ne coûte rien en plein geste —
    /// le hoquet du montage est mort.
    private static let mountClimb = 0.10
    private static let nightEnd = 0.14
    private static let dawnEnd = 0.22

    /// La montée courante du doigt, la révélation (en HYSTÉRÉSIS :
    /// montrée à 0,22, cachée sous 0,17 — la plongée est réversible sous
    /// le doigt), et le sommet (après lui, plus aucun retour ne s'arme).
    @State private var driveClimb: Double = 0
    @State private var lensShown = false
    @State private var summited = false
    /// Le drag de retour en cours : son point de départ (y global).
    @State private var returnFrom: CGFloat?

    // MARK: Le header qui se rétrécit

    /// L'offset du scroll de la page muscu — LE scalaire du header : toute
    /// la partition du rétrécissement est fonction pure de lui, remonter
    /// rembobine pixel pour pixel. Jamais un withAnimation.
    @State private var scrollY: CGFloat = 0
    /// La photo au repos : 225 (« réduis encore les images », 13 août) —
    /// c'était 285.
    private static let heroCap: CGFloat = 225
    /// La course du rétrécissement, en points de scroll.
    private static let collapseSpan: CGFloat = 140
    /// La place réservée en tête du scroll (photo + titre étendus) : FIXE.
    /// Le header se dessine en OVERLAY au-dessus — un inset qui changerait
    /// de hauteur re-layouterait le scroll à chaque frame (la loi de la
    /// maison : on anime en offset, jamais la place réservée).
    private static let expandedHeader: CGFloat = 12 + 225 + 8 + 92
    /// `-headerFreeze <y>` : fige l'offset vu par le header (le simulateur
    /// ne scrolle pas) — les poses du morphing se capturent.
    private static let headerFreeze: CGFloat? = {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "-headerFreeze"),
              i + 1 < args.count,
              let v = Double(args[i + 1]) else { return nil }
        return CGFloat(v)
    }()
    private var headerY: CGFloat { Self.headerFreeze ?? scrollY }

    private static func lp(_ a: CGFloat, _ b: CGFloat,
                           _ u: Double) -> CGFloat {
        a + (b - a) * CGFloat(u)
    }
    /// Le point précédent du doigt — la poussière sonore se sème à la
    /// DISTANCE parcourue, jamais au temps.
    @State private var lastDrive: CGPoint?

    private static func sstep(_ a: Double, _ b: Double,
                              _ x: Double) -> Double {
        let u = min(max((x - a) / (b - a), 0), 1)
        return u * u * (3 - 2 * u)
    }

    /// L'avancement de l'aube, et la caméra qui en découle.
    private var dawn: Double {
        Self.sstep(Self.nightEnd, Self.dawnEnd, driveClimb)
    }
    /// `8^(u²)` : part lentement, accélère fort — la grammaire des deux
    /// plongées déjà validées (8^(u^1,8) connexion, 8^(u^2,05) sommet).
    private var dive: Double {
        lensShown ? 8.0 : pow(8.0, dawn * dawn)
    }
    /// Le battement de blanc qui cache la coupe : une cloche brève autour
    /// de la fin de plongée, au-dessus de tout — le marron y est
    /// impossible, et la couture aussi. Il n'existe que tant que le geste
    /// vit : le ressort du retour repasserait par la cloche, et un éclair
    /// fantôme signerait l'abandon.
    private var flashA: Double {
        guard running != nil, !lensShown else { return 0 }
        let bell = max(0.0, 1.0 - abs(dawn - 0.90) / 0.10)
        return 0.9 * bell * bell
    }


    /// La série en cours d'exécution au compteur, s'il y en a une. Un `item:`
    /// plutôt qu'un booléen : c'est l'indice qui porte l'information, et il ne
    /// peut pas se désynchroniser.
    @State private var running: RunningSeries?

    private struct RunningSeries: Identifiable {
        let id: Int
        /// La série a été CRÉÉE par ce lancement (et non reprise) : si le
        /// doigt abandonne avant la révélation de la bulle, on la défait.
        var appended = false
    }

    /// LA SÉRIE TERMINÉE, entre l'envol et le retour : ce que la pastille a
    /// remporté en partant. Tant qu'il est non-nil, la page BRAVO est posée ;
    /// son retour écrit ces chiffres dans la carte — pas avant : la carte
    /// s'actualise sous les yeux, à l'air libre, jamais sous une page.
    @State private var finished: FinishedSeries?

    private struct FinishedSeries {
        let index: Int
        let reps: Int
        let kilos: Double
        let rest: Int
        let seconds: Int
    }

    /// LA QUESTION DU RETOUR. Après BRAVO, le panneau « Recommencer ? »
    /// porte la série vécue tant qu'il est à l'écran — l'écriture dans la
    /// carte attend sa SORTIE : c'est elle qu'on regarde (les pièces, le
    /// compte), et le panneau qui descend la découvre.
    @State private var restartAsk: FinishedSeries?
    /// La volée de pièces vers la carte Série : l'instant du départ.
    @State private var coinsAt: Date?
    /// La carte Série en repère global — la cible des pièces.
    @State private var seriesCardFrame: CGRect = .zero
    /// Le prochain montage du cadran naît POSÉ (le bouton du panneau) —
    /// pas de plongée, un 3-2-1 à la place.
    @State private var posedLaunch = false

    private var active: Workout? { workouts.first { $0.isActive } }
    private var isStrength: Bool { exercise.tracking == .setsRepsWeight }

    // MARK: Le banc de l'aube — le simulateur ne drague pas (l'école -cineTest)

    /// `-aubeAuto` rejoue en boucle la montée de lumière du galet, sans
    /// jamais déclencher ; `-aubeFire` joue UNE traversée complète (aube →
    /// pose de la lentille → retour à la nuit) ; `-aubeFreeze <u>` fige la
    /// course à u ∈ [0,1] pour les captures. Sans argument : inertes.
    private static let aubeAuto = CommandLine.arguments.contains("-aubeAuto")
    private static let aubeFire = CommandLine.arguments.contains("-aubeFire")
    private static let aubeFreeze: Double? = {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "-aubeFreeze"), i + 1 < args.count,
              let v = Double(args[i + 1]) else { return nil }
        return min(max(v, 0), 1)
    }()

    private func runAubeBench() async {
        // `-restartFire` : le panneau « Recommencer ? » se monte seul
        // (le simulateur ne revient pas de BRAVO au doigt) ;
        // `-restartAuto` le referme à 3 s (la volée de pièces se filme) ;
        // `-restartLaunch` appuie sur « Lancer » à 3 s (la porte posée).
        if CommandLine.arguments.contains("-restartFire") {
            try? await Task.sleep(for: .seconds(1.4))
            if sets.isEmpty {
                sets.append(DraftSet(reps: 12, weight: 20))
            }
            let ask = FinishedSeries(index: 0, reps: 12, kilos: 20,
                                     rest: 60, seconds: 47)
            restartAsk = ask
            if CommandLine.arguments.contains("-restartAuto") {
                try? await Task.sleep(for: .seconds(3))
                exitRestart(ask, thenLaunch: false)
            } else if CommandLine.arguments.contains("-restartLaunch") {
                try? await Task.sleep(for: .seconds(3))
                exitRestart(ask, thenLaunch: true)
            }
            return
        }
        if let u = Self.aubeFreeze { flood = u; return }
        guard Self.aubeAuto || Self.aubeFire else { return }
        try? await Task.sleep(for: .seconds(2))
        // Le doigt synthétique parle l'espace plein écran, comme le vrai :
        // y depuis la montée voulue, par le MÊME barème (climbGlobal⁻¹).
        func point(at climb: Double) -> CGPoint {
            CGPoint(x: pageFull.width / 2
                        + 18 * sin(climb * 7.0),
                    y: pageFull.height * 0.90
                        - climb * pageFull.height * 0.72)
        }
        if Self.aubeFire {
            // LE GESTE UNIQUE, sans doigt : la montée traverse la nuit,
            // le blanc, l'entrée de la bulle et file au SOMMET — toute la
            // partition (coupe, descente, chrono) s'enchaîne d'elle-même.
            // Un vrai doigt ne bouge pas pendant un hoquet : le banc
            // marque le même temps d'arrêt après le seuil de montage.
            var t0 = Date()
            var held = false
            var c = 0.0
            while !Task.isCancelled {
                let u = Date().timeIntervalSince(t0) / 3.4
                if u >= 1 { break }
                let e = u * u * (3 - 2 * u)
                // Un doigt SAVOURE la plongée : dans la zone de l'aube,
                // la montée est plafonnée à ~0,10/s — le film montre ce
                // que la main vivra.
                let maxStep = (c > 0.11 && c < 0.25) ? 0.0017 : 0.03
                c = min(e, c + maxStep)
                driveMoved(point(at: c), -1400)
                if !held, running != nil {
                    held = true
                    try? await Task.sleep(for: .milliseconds(280))
                    t0 = t0.addingTimeInterval(0.28)
                }
                try? await Task.sleep(for: .milliseconds(16))
            }
            driveMoved(point(at: 1.0), -1400)
            // LE RELAIS PEUT RATER À LA RELANCE. Si la lentille s'est montée
            // trop tard (relance plus lente que le premier lancement — mesuré :
            // install fraîche OK, terminate+launch bloqué au monde blanc,
            // bulle au repos), le doigt synthétique a fini son œuvre avant
            // qu'elle ne l'entende : le `handoff` ne change plus, elle ne
            // saura jamais. Le banc rejoue donc la fin de la montée jusqu'à
            // ce que le sommet soit PRIS — un vrai doigt, lui, insisterait.
            var tries = 0
            while !summited, tries < 6, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(400))
                for k in 0...10 {
                    driveMoved(point(at: 0.5 + 0.05 * Double(k)), -1400)
                    try? await Task.sleep(for: .milliseconds(16))
                }
                tries += 1
            }
            driveEnded(point(at: 1.0), 0)
        } else {
            // La boucle de l'aube : montée SOUS le seuil de la bulle,
            // retombée, silence — le voile respire, rien ne se monte.
            let t0 = Date()
            while !Task.isCancelled {
                let ph = Date().timeIntervalSince(t0)
                    .truncatingRemainder(dividingBy: 5.6)
                let r = min(max((ph - 1.6) / 1.3, 0), 1)
                let f = min(max((ph - 3.4) / 0.7, 0), 1)
                // Sous le seuil de pré-montage : l'aube seule, jamais
                // la bulle.
                let c = 0.08 * (r * r * (3 - 2 * r))
                    * (1 - f * f * (3 - 2 * f))
                if ph < 4.4 {
                    driveMoved(point(at: c), -600)
                } else if flood > 0 {
                    driveEnded(point(at: 0), 0)
                }
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    /// La silhouette de la carte noire : coins hauts seulement — elle file
    /// bord à bord et jusqu'en bas d'écran, comme la référence.
    private static let pageShape = UnevenRoundedRectangle(
        cornerRadii: .init(topLeading: 40, bottomLeading: 0,
                           bottomTrailing: 0, topTrailing: 40),
        style: .continuous)

    var body: some View {
        GeometryReader { geo in
            // LA CARTE NOIRE, désormais RÉSERVÉE AU CARDIO : pleine largeur,
            // grands coins hauts, elle s'inscrit sur la braise et coupe le
            // scroll sur sa silhouette — jamais un pixel de contenu ne remonte
            // sur l'orange. La musculation ne défile pas : elle n'a rien à
            // couper, donc elle n'a plus de carte du tout. Le noir lui vient
            // du socle, en fond, comme à tout le monde.
            ZStack(alignment: .top) {
                if isStrength {
                    strengthPage
                } else {
                    cardioPage
                        .background(Self.pageShape.fill(Color.black))
                        .clipShape(Self.pageShape)
                }
            }
            // Le socle et la braise vivent en FOND, hors jeu de layout : la
            // carte-braise a déjà fait dérailler la largeur de la page une
            // fois — plus rien d'elle ne participe à la mise en page.
            .background {
                ZStack(alignment: .top) {
                    Color.black
                    // La braise se tait pendant la lentille : elle brûle à
                    // 30 Hz sous un plein écran qui, lui, tourne à 60.
                    // En muscu elle n'est plus ICI, en fond, mais AU-DESSUS,
                    // en lumière (l'overlay juste dessous) ; le cardio, qui
                    // garde sa carte noire, garde son feu derrière elle.
                    if !isStrength, running == nil { HeaderEmberCard() }
                }
                .ignoresSafeArea()
            }
            // LA LUMIÈRE DE LA PAGE — au-dessus du contenu, et c'est une
            // nécessité, pas une coquetterie. La photo est un fichier à fond
            // NOIR OPAQUE : posée par-dessus un feu de fond, elle y poinçonne
            // un rectangle noir de 240 pt de large, et le seul remède (fondre
            // son quart haut) effacerait la tête et les épaules du sujet. En
            // additif le problème n'existe pas : sur la nuit de la page le
            // noir du halo n'AJOUTE rien, et sur la photo la lumière se POSE
            // au lieu de masquer — le montant de la machine et l'épaule du
            // sujet prennent leur liseré chaud. Ce n'est plus un fond derrière
            // une image, c'est une source qui éclaire une scène.
            // Sous les chips et sous la carte Série : les deux `safeAreaInset`
            // sont appliqués après, leur verre fumé reste intact.
            // LE FOND DU HEADER — photo entière + grand titre, SOUS la
            // lumière : la photo est un fichier à fond noir opaque, elle
            // doit rester sous l'additif pour que la lumière se POSE sur
            // elle (au-dessus, elle poinçonne un rectangle noir dans
            // l'aurore — payé au premier retour de Kathryn).
            .overlay(alignment: .top) {
                if isStrength { collapsingHeaderBack }
            }
            .overlay {
                ZStack(alignment: .top) {
                    Color.clear
                    if isStrength, running == nil {
                        // La lumière s'apaise quand le header se condense :
                        // la petite carte n'a pas besoin d'un feu derrière.
                        ExoHeaderGlow()
                            .opacity(1 - 0.8 * Self.sstep(0, 90,
                                                          Double(headerY)))
                    }
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
            // LA CARTE-NOTIFICATION + sa vignette — AU-DESSUS de la
            // lumière : le verre reste intact (le sandwich de la maison :
            // glow < carte de verre), et la vignette recadrée y est nette.
            .overlay(alignment: .top) {
                if isStrength { collapsingHeaderFront }
            }
            // La taille pour le banc — JAMAIS une géométrie d'avant le
            // premier layout (le zéro faisait le NaN ci-dessus).
            .onAppear {
                if geo.size.height > 100 {
                    pageFull = CGSize(
                        width: geo.size.width,
                        height: geo.size.height + geo.safeAreaInsets.top
                                + geo.safeAreaInsets.bottom)
                }
                // Les moteurs de la lentille chauffent ICI, à l'entrée de
                // la fiche : leur préparation au montage (session audio,
                // haptique) gelait l'app ~0,2 s en pleine plongée — le
                // hoquet mangeait l'aube. Des singletons : au montage,
                // leurs prepare() ne coûtent plus rien.
                RocketHaptics.shared.prepare()
                LensTheme.shared.prepare()
                LensChime.shared.prepare()
                Paillettes.shared.prepare()
            }
            .onChange(of: geo.size) { _, s in
                if s.height > 100 {
                    pageFull = CGSize(
                        width: s.width,
                        height: s.height + geo.safeAreaInsets.top
                                + geo.safeAreaInsets.bottom)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) { headerChips }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if isStrength {
                    // La carte Séries a DÉMÉNAGÉ dans le flux du scroll
                    // (sous le header) — le galet reste seul en bas.
                    VStack(spacing: 0) {
                        // LA BULLE DE LA LENTILLE, du côté de la nuit :
                        // même course, même écriture de `flood` que le
                        // dôme qu'elle remplace — mais le verre est le
                        // VRAI (le shader de la lentille, appelé avec les
                        // nombres de son repos). Bord à bord, elle déborde
                        // jusqu'au bord physique de l'écran.
                        // Le lecteur (`WorkoutPill`) est retiré du décor
                        // pour l'instant — il reviendra, décision à venir.
                        LaunchPebble(
                            label: "Glisser pour démarrer",
                            flood: $flood,
                            asleep: running != nil,
                            onDrive: { p, vy in driveMoved(p, vy) },
                            onRelease: { p, vy in driveEnded(p, vy) },
                            onLaunch: launch
                        )
                    }
                } else {
                    primaryAction
                }
            }
        }
        // LA PLONGÉE DANS LE GALET — la troisième caméra de la maison
        // (connexion → la lune ; sommet → la pastille ; ici → le galet).
        // Zoom exponentiel ancré sur son cœur, PILOTÉ PAR LE DOIGT : tu
        // recules, la caméra recule — réversible jusqu'à la coupe. Le
        // voile, le flash et la lentille vivent AU-DESSUS du sous-arbre
        // zoomé, nets pendant que la page plonge.
        .scaleEffect(dive, anchor: UnitPoint(x: 0.5, y: 0.84))
        .task { await runAubeBench() }
        // Le chevron du chip a remplacé la barre système : deux flèches de
        // retour seraient une de trop.
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        // L'appareil confirme la série en même temps que les paillettes partent.
        .sensoryFeedback(.success, trigger: sets.filter(\.isDone).count)
        // Le battement du montage : la lentille vient d'entrer sous le doigt.
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.9),
                         trigger: launchBeat)
        // LE RACCORD. La lumière du galet inonde la page pendant le geste —
        // le verre chauffe sur la MÊME rampe que ce voile ; quand la
        // lentille se pose, elle ouvre sur CE papier-là. Aucune transition
        // n'est jouée : il n'y a rien à traverser, c'est la même lumière
        // qui continue.
        .overlay {
            ZStack {
                if flood > 0.001 {
                    Self.paper
                        .opacity(floodVeil)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
                // (Ici vivaient des « stries de vitesse ». Un trait à
                // largeur constante et bords francs sur du noir n'est pas
                // de la lumière, c'est de l'ENCRE — la lecture BD était
                // juste. Toute la matière de la maison est un CHAMP, sans
                // bord : braise, halo, bloom, fil. Le spectaculaire de la
                // plongée, c'est le zoom, le blanc qui verse et le flash —
                // jamais un objet posé par-dessus.)
                // Le flash de la coupe — au-dessus de tout.
                if flashA > 0.001 {
                    Color.white
                        .opacity(flashA)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
                if let series = running {
                    // PRÉ-MONTÉE INVISIBLE puis RÉVÉLÉE dans l'aube : son
                    // monde blanc est le même papier que le voile — le
                    // fondu est indétectable, seule la bulle se
                    // matérialise, déjà à hauteur, déjà sous le doigt.
                    LiquidLensLab(
                        headline: exercise.name,
                        faceLabel: "SÉRIE \(series.id + 1)",
                        seriesNumber: series.id + 1,
                        onFinish: { outcome in
                            startBravo(series.id, outcome)
                        },
                        onCancel: {
                            running = nil
                            lensHandoff = nil
                            driveClimb = 0
                            lensShown = false
                            summited = false
                            withAnimation(.easeOut(duration: 0.28)) {
                                flood = 0
                            }
                        },
                        handoff: lensHandoff,
                        onSummit: { summited = true },
                        posedStart: posedLaunch
                    )
                    .opacity(lensShown
                             ? 1
                             : Self.sstep(0.18, Self.dawnEnd, driveClimb))
                    // La porte POSÉE entre en fondu (launchPosed anime son
                    // montage) ; la porte du geste reste une coupe — son
                    // écriture d'état n'est pas animée, le fondu ne joue pas.
                    .transition(.opacity)
                    // L'atterrissage : la bulle se POSE dans le monde
                    // blanc au moment de sa révélation.
                    .scaleEffect(lensShown ? 1.0 : 1.04)
                    .animation(.spring(response: 0.45,
                                       dampingFraction: 0.55),
                               value: lensShown)
                    // LE DRAG DE RETOUR — partout dans le monde blanc,
                    // tant que le sommet n'est pas franchi : tirer vers
                    // le bas rejoue la plongée à l'envers, sous le doigt,
                    // réversible. Simultané : la lentille garde ses
                    // gestes (un drag bas, chez elle, ne fait rien).
                    .simultaneousGesture(returnDrag)
                }
                // LA PAGE BRAVO. Elle remplace le cadran à l'instant où la
                // pastille a percé le bord haut — noir sur noir, la coupe
                // est invisible, et sa pièce TOMBE du même bord : le raccord
                // est dans le geste. Le cadran est DÉMONTÉ, pas caché : deux
                // plein-écrans vivants empilés, c'est la cadence qui paie
                // (la leçon mesurée de la page elle-même).
                if let f = finished {
                    BravoView(reps: f.reps,
                              kilos: f.kilos,
                              rest: f.rest,
                              onFinish: { closeBravo(f) })
                }
                // LE PANNEAU DU RETOUR — « Recommencer ? ». Le conteneur
                // reste monté (transparent, sourd au doigt quand vide) :
                // c'est lui qui joue l'entrée et la sortie du panneau.
                GeometryReader { g in
                    ZStack(alignment: .bottom) {
                        Color.clear
                        if let ask = restartAsk {
                            RestartSheet(
                                onLaunch: {
                                    exitRestart(ask, thenLaunch: true)
                                },
                                onDismiss: {
                                    exitRestart(ask, thenLaunch: false)
                                })
                                .frame(height: g.size.height * 0.52)
                                .transition(.move(edge: .bottom))
                        }
                    }
                    .ignoresSafeArea()
                    .animation(.spring(response: 0.45,
                                       dampingFraction: 0.86),
                               value: restartAsk == nil)
                }
                .allowsHitTesting(restartAsk != nil)
                // LES PIÈCES DE LA SÉRIE — au-dessus de tout : la carte
                // s'écrit en lumière pendant que le panneau descend.
                if let at = coinsAt {
                    GeometryReader { g in
                        let og = g.frame(in: .global).origin
                        let tgt = seriesCardFrame == .zero
                            ? CGPoint(x: g.size.width - 64,
                                      y: g.size.height - 210)
                            : CGPoint(x: seriesCardFrame.maxX - 44 - og.x,
                                      y: seriesCardFrame.midY - og.y)
                        SeriesCoinFlight(
                            start: at,
                            source: CGPoint(x: g.size.width / 2,
                                            y: g.size.height * 0.74),
                            target: tgt,
                            onDone: { coinsAt = nil })
                    }
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                }
            }
        }
    }

    /// Le papier arrive VITE — la page a basculé bien avant la fin du geste,
    /// pour que le dernier tiers de la course se fasse déjà dans le blanc.
    private var floodVeil: Double {
        let u = min(max((flood - 0.12) / 0.46, 0), 1)
        return u * u * (3 - 2 * u)
    }

    /// Le papier de la maison — celui du dôme, celui de la lentille.
    private static let paper = Color(red: 0.956, green: 0.952, blue: 0.942)

    // MARK: Les deux corps de page

    /// LA MUSCULATION DÉFILE DÉSORMAIS — et son header SE RÉTRÉCIT. La
    /// photo et le titre ne vivent plus dans le flux : ils sont dessinés
    /// par `collapsingHeader` en overlay, au-dessus du scroll, et le flux
    /// ne fait que leur RÉSERVER une place fixe en tête. Au scroll, la
    /// photo se réduit en vignette dans une petite carte de verre
    /// (« notification »), le titre s'y condense, et l'historique des
    /// séries monte dessous. Le galet, lui, ne bouge pas du bas.
    private var strengthPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // La place du header étendu — FIXE : le header se dessine
                // au-dessus et se rétrécit sans que rien ne re-layoute.
                Color.clear.frame(height: Self.expandedHeader)
                // LA FLAMME-JAUGE (le composant de la session parallèle,
                // commité d75cf88) tient désormais la place de l'ancienne
                // carte Séries — même verre, même rôle, sa vie à elle.
                FlammeJauge(done: sets.filter(\.isDone).count)
                    .padding(.horizontal, 20)
                    // La cible des pièces : la carte se déclare en global,
                    // la volée sait où se poser — même en plein scroll.
                    .background {
                        GeometryReader { p in
                            Color.clear
                                .onAppear {
                                    seriesCardFrame = p.frame(in: .global)
                                }
                                .onChange(of: p.frame(in: .global)) { _, f in
                                    seriesCardFrame = f
                                }
                        }
                    }
                    .padding(.top, 4)
                historySection
                Color.clear.frame(height: 30)
            }
        }
        .scrollIndicators(.hidden)
        .onScrollGeometryChange(for: CGFloat.self) { geo in
            geo.contentOffset.y + geo.contentInsets.top
        } action: { _, y in
            scrollY = max(0, y)
        }
    }

    /// L'HISTORIQUE DES SÉRIES — les lignes de la story 2, adoptées par la
    /// fiche : faites en or et pièces, à venir en encre éteinte.
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("HISTORIQUE DES SÉRIES")
                .font(.inter(10, .medium))
                .tracking(2.6)
                .foregroundStyle(Color.white.opacity(0.40))
                .padding(.top, 26)
                .padding(.bottom, 2)
            ForEach(Array(sets.enumerated()), id: \.element.id) { i, s in
                SetHistoryRow(rank: i + 1,
                              reps: s.reps,
                              kilos: s.weight,
                              seconds: s.isDone ? s.durationSeconds
                                                : restSeconds,
                              done: s.isDone)
            }
            if sets.isEmpty {
                Text("Aucune série encore — glisse pour démarrer.")
                    .font(.inter(13))
                    .foregroundStyle(Color.inkMuted)
            }
        }
        .padding(.horizontal, 20)
    }

    /// Le cardio garde sa page qui défile et ses blocs sombres : le dôme blanc
    /// est le système de la musculation — il rejoindra le reste quand le
    /// composant sera généralisé.
    private var cardioPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                titleBlock(big: false)
                hero(maxHeight: 210)
                if let lastTime { LastTimeBanner(text: lastTime) }
                editor
                if let confirmation {
                    Label(confirmation, systemImage: "checkmark.circle.fill")
                        .font(.inter(13, .medium))
                        .foregroundStyle(Color.woopGold)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 26)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: Le header qui se rétrécit

    /// La ligne specs de la carte-notification : « 24 kg • 12 reps ».
    private var headerSpecs: String {
        let reps = sets.first?.reps ?? 12
        let kg = sets.first?.weight ?? 20
        let kgText = kg == kg.rounded()
            ? String(Int(kg)) : String(format: "%.1f", kg)
        return "\(kgText) kg • \(reps) reps"
    }

    /// LE HEADER QUI SE RÉTRÉCIT — en DEUX couches, et c'est structurel :
    /// la photo entière et le grand titre vivent SOUS la lumière additive
    /// (le fond noir opaque de la photo doit recevoir la lumière, pas la
    /// poinçonner) ; la carte-notification et sa vignette recadrée vivent
    /// AU-DESSUS (le verre reste intact). Le fondu croisé fit→fills fait
    /// le pont entre les deux couches sans que l'œil le voie.
    ///
    /// Tout est fonction pure de `headerY` — remonter rembobine pixel pour
    /// pixel, aucun withAnimation. La grammaire est celle de StoryPortal :
    /// UN scalaire interpole position, taille ET rayon. (Jamais de
    /// matchedGeometryEffect — la maison anime à la main.)

    /// Les nombres partagés de la partition — UNE seule loi pour les deux
    /// couches (l'obligation des lois accordées, l'école ExercisesView).
    private struct HeaderPose {
        let u: Double
        let pw: CGFloat, ph: CGFloat, px: CGFloat, rad: CGFloat
        let swap: Double, cardIn: Double, bigOut: Double
        init(W: CGFloat, y: CGFloat) {
            u = ExerciseDetailView.sstep(
                0, Double(ExerciseDetailView.collapseSpan), Double(y))
            pw = ExerciseDetailView.lp(W, 54, u)
            ph = ExerciseDetailView.lp(ExerciseDetailView.heroCap, 54, u)
            px = ExerciseDetailView.lp(0, 28, u)
            rad = ExerciseDetailView.lp(0, 14, u)
            // L'entière (.fit, bords fondus) cède TÔT à la vignette
            // recadrée : le .fit qui rapetisse dans un cadre qui change
            // d'aspect flotte — le recadrage l'ancre (mesuré à u=0,5).
            swap = ExerciseDetailView.sstep(0.45, 0.72, u)
            // La carte ne naît qu'une fois la photo presque posée.
            cardIn = ExerciseDetailView.sstep(0.58, 0.92, u)
            bigOut = 1 - ExerciseDetailView.sstep(0.28, 0.62, u)
        }
    }

    /// La couche ARRIÈRE : photo entière + grand titre, sous la lumière.
    private var collapsingHeaderBack: some View {
        GeometryReader { g in
            let p = HeaderPose(W: g.size.width, y: headerY)
            ZStack(alignment: .topLeading) {
                if p.bigOut > 0.001 {
                    titleBlock(big: true)
                        .padding(.horizontal, 20)
                        .offset(y: Self.lp(12 + Self.heroCap + 8,
                                           12 + Self.heroCap - 18, p.u))
                        .opacity(p.bigOut)
                }
                if p.swap < 0.999 {
                    hero(maxHeight: Self.heroCap)
                        .frame(width: p.pw, height: p.ph)
                        .clipShape(RoundedRectangle(cornerRadius: p.rad,
                                                    style: .continuous))
                        .offset(x: p.px, y: 12)
                        .opacity(1 - p.swap)
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// La couche AVANT : la carte-notification et sa vignette, sur la
    /// lumière — le verre exact de la maison.
    private var collapsingHeaderFront: some View {
        GeometryReader { g in
            let W = g.size.width
            let p = HeaderPose(W: W, y: headerY)
            ZStack(alignment: .topLeading) {
                HStack(spacing: 12) {
                    // La place de la vignette : la photo la survole.
                    Color.clear.frame(width: 54, height: 54)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.name)
                            .font(.inter(16, .semibold))
                            .foregroundStyle(Color.inkPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text(headerSpecs)
                            .font(.inter(12))
                            .foregroundStyle(Color.inkMuted)
                    }
                    Spacer(minLength: 8)
                    let earned = sets.filter(\.isDone).count
                        * CoffreFortPurse.perSeries
                    if earned > 0 {
                        HStack(spacing: 5) {
                            Text("+\(earned)")
                                .font(.inter(14, .semibold))
                                .foregroundStyle(Color.woopGold.opacity(0.92))
                                .monospacedDigit()
                            // La pièce GELÉE de la maison — la recette de
                            // la story, au néon baissé.
                            MoonCoinView(coinR: 13, draggable: false,
                                         yawOverride: 0.34, idleLife: 0,
                                         fps: 6, reveal: 0.34, matte: 1)
                                .frame(width: 13 * MoonCoinView.hostScale,
                                       height: 13 * MoonCoinView.hostScale)
                                .frame(width: 28, height: 28)
                        }
                    }
                }
                .padding(.leading, 8)
                .padding(.trailing, 14)
                .frame(width: W - 40, height: 66)
                .background {
                    Color.clear.glassEffect(
                        .regular.tint(Color.black.opacity(0.5)),
                        in: RoundedRectangle(cornerRadius: 22,
                                             style: .continuous))
                }
                .overlay(RoundedRectangle(cornerRadius: 22,
                                          style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
                .opacity(p.cardIn)
                .offset(x: 20, y: 6)

                if p.swap > 0.001 {
                    ExercisePhoto(exercise: exercise, fills: true)
                        .frame(width: p.pw, height: p.ph)
                        .clipShape(RoundedRectangle(cornerRadius: p.rad,
                                                    style: .continuous))
                        .offset(x: p.px, y: 12)
                        .opacity(p.swap)
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: En-tête

    /// Le chevron dans son carré de verre, et son double « … » en face —
    /// celui-ci s'ouvrira plus tard en carte (date, heure) : il a déjà sa
    /// place, il n'a pas encore son geste.
    private var headerChips: some View {
        HStack {
            headerChip("chevron.left", label: "Retour") { dismiss() }
            Spacer()
            headerChip("ellipsis", label: "Options") {}
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    private func headerChip(_ symbol: String, label: String,
                            action: @escaping () -> Void) -> some View {
        let shape = RoundedRectangle(cornerRadius: 15, style: .continuous)
        return Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.inkPrimary)
                .frame(width: 44, height: 44)
                .background {
                    // Verre fumé FONCÉ, comme le chip « Done » de la référence :
                    // un objet sombre posé sur la braise, qu'elle traverse à
                    // peine — le halo vient de la nappe, pas d'une ombre.
                    Color.clear
                        .glassEffect(.regular.tint(Color.black.opacity(0.5))
                            .interactive(), in: shape)
                }
                .overlay(shape.strokeBorder(Color.white.opacity(0.08),
                                            lineWidth: 1))
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// EXACTEMENT le titre de la home — même fonte, même graisse, même
    /// interlettrage négatif, même dégradé. Le sous-titre dit la zone
    /// travaillée, en retrait, comme la référence.
    ///
    /// `big` : la version de la fiche muscu, sur DEUX lignes. Le corps ne
    /// change pas (30, comme partout) — ce qui change, c'est qu'il n'est
    /// plus ÉCRASÉ : « Woodchopper poulie haute » demande ~450 pt sur une
    /// ligne pour 362 disponibles, donc le `minimumScaleFactor(0,62)` le
    /// rendait en réalité à 24. Deux lignes, et il retrouve sa taille
    /// pleine. La largeur est bornée à 300 pour que la coupure tombe après
    /// « Woodchopper » (le mouvement, puis la machine) et pas après
    /// « poulie » — sur les noms courts, la borne ne se voit jamais.
    ///
    /// `WoopGradient.titleFade` est déjà DIAGONAL, précisément pour ce cas :
    /// un dégradé horizontal rallume le début de chaque ligne et un titre
    /// sur deux lignes se met à clignoter. Rien à y toucher.
    private func titleBlock(big: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(exercise.name)
                .font(.inter(30, .semibold))
                .tracking(-0.3)
                .foregroundStyle(WoopGradient.titleFade)
                .lineLimit(big ? 2 : 1)
                .minimumScaleFactor(big ? 0.9 : 0.62)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: big ? 300 : nil, alignment: .leading)
            Text("\(exercise.category.rawValue) • \(exercise.muscle)")
                .font(.inter(13))
                .foregroundStyle(Color.inkMuted)
        }
    }

    /// La photo NUE, fondue dans le noir de la carte : ni liseré, ni lueur,
    /// ni angles — un cadre dessiné redonnerait « une image dans une boîte »,
    /// et c'est exactement ce qui rendait cheap. Le fond de l'image est déjà
    /// le noir de la page ; les masques n'éteignent que les bords, là où une
    /// jambe ou un montant de machine buterait net sur l'arête.
    private func hero(maxHeight: CGFloat) -> some View {
        ExercisePhoto(exercise: exercise, fills: false)
            .frame(maxWidth: .infinity, maxHeight: maxHeight)
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .white, location: 0.07),
                        .init(color: .white, location: 0.86),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            }
            // Deux masques chaînés se multiplient : les quatre bords
            // s'éteignent sans dégradé bidimensionnel.
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .white, location: 0.05),
                        .init(color: .white, location: 0.95),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .leading, endPoint: .trailing
                )
            }
    }

    // MARK: L'éditeur cardio

    @ViewBuilder
    private var editor: some View {
        switch exercise.tracking {
        case .setsRepsWeight:
            // La musculation vit dans la dalle : rien ici.
            EmptyView()
        case .intervals:
            IntervalBlock(phases: $phases, repeatCount: $repeatCount)
        case .steady:
            SteadyBlock(seconds: $steadySeconds, speed: $steadySpeed,
                        incline: $incline, isStairs: exercise.id == "escalier")
        }
    }

    // MARK: Le geste principal du cardio

    /// Le bas d'écran du cardio, inchangé : sa fiche ne fait qu'enregistrer.
    private var primaryAction: some View {
        VStack(spacing: 10) {
            DiamondPrimaryButton(title: "Enregistrer l'exercice") {
                save()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background {
            // Le contenu défile DERRIÈRE le bouton : sans ce fondu, un bloc
            // viendrait se couper net sur son arête.
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0), location: 0),
                    .init(color: .black.opacity(0.62), location: 0.42),
                    .init(color: .black.opacity(0.88), location: 1)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    /// Ce que la pastille affiche de la séance : la part des séries faites.
    private var doneFraction: Double {
        guard !sets.isEmpty else { return 0 }
        return Double(sets.filter(\.isDone).count) / Double(sets.count)
    }

    /// Le geste de lancement. La page part de zéro série : la première naît
    /// ici, et chaque relance en crée une nouvelle quand les précédentes sont
    /// faites — on ne règle plus AVANT, on fait, et la carte compte.
    private func launch() {
        let index: Int
        let appended: Bool
        if let pending = sets.firstIndex(where: { !$0.isDone }) {
            index = pending
            appended = false
        } else {
            sets.append(DraftSet(reps: sets.last?.reps ?? 12,
                                 weight: sets.last?.weight ?? 20))
            index = sets.count - 1
            appended = true
        }
        running = RunningSeries(id: index, appended: appended)
        launchBeat += 1
    }

    // MARK: Le geste unique

    /// Le doigt du galet, en points plein écran. La fiche blanchit la
    /// page sur les premiers centimètres (le voile sature avant la
    /// bulle), monte la lentille à `mountClimb` — DÉJÀ soulevée — puis
    /// lui transmet le doigt vivant : un seul geste, de la nuit de la
    /// fiche au sommet du monde blanc.
    private func driveMoved(_ p: CGPoint, _ vy: CGFloat) {
        let c = Self.climbGlobal(y: p.y, h: pageFull.height)
        driveClimb = c
        // Temps 1 : le voile se réchauffe à peine (13 % à la fin de la
        // montée nocturne) ; temps 2 : l'aube verse le reste.
        flood = 0.22 * Self.sstep(0, Self.nightEnd, c)
                + 0.78 * Self.sstep(Self.nightEnd, Self.dawnEnd, c)
        if running == nil, c >= Self.mountClimb { launch() }
        if running != nil {
            lensHandoff = .init(point: p, velocityY: vy, live: true)
            // L'hystérésis de la révélation : montrée à 0,22, cachée si
            // le doigt redescend sous 0,17 — on oscille librement.
            if c >= Self.dawnEnd { lensShown = true }
            else if c < 0.17 { lensShown = false }
        } else {
            // Le grondement vit dès le premier point — le MÊME moteur que
            // la lentille : au relais, il ne change pas de main.
            RocketHaptics.shared.dragLevel(c)
            // La poussière sonore de la nuit ; passé le relais, c'est la
            // lentille qui la sème (une seule source à la fois).
            if let prev = lastDrive {
                Paillettes.shared.travel(hypot(p.x - prev.x, p.y - prev.y),
                                         level: c)
            }
            lastDrive = p
        }
    }

    /// Le relâcher. Bulle révélée : la lentille possède le geste (sa
    /// retombée, son sommet). Avant la révélation : la nuit se referme,
    /// et la série créée par CE lancement se défait — rien n'a eu lieu.
    private func driveEnded(_ p: CGPoint, _ vy: CGFloat) {
        if lensShown, running != nil {
            lensHandoff = .init(point: p, velocityY: vy, live: false)
        } else {
            closeBack()
        }
    }

    /// La nuit se referme sur la fiche — l'abandon et le retour partagent
    /// le même geste de rangement.
    private func closeBack() {
        if let r = running, r.appended,
           let last = sets.last, !last.isDone {
            sets.removeLast()
        }
        running = nil
        lensHandoff = nil
        summited = false
        lensShown = false
        posedLaunch = false
        lastDrive = nil
        RocketHaptics.shared.dragEnd()
        Paillettes.shared.end()
        withAnimation(.spring(response: 0.40, dampingFraction: 0.80)) {
            driveClimb = 0
        }
        withAnimation(.easeOut(duration: 0.22)) { flood = 0 }
    }

    /// LE DRAG DE RETOUR : l'inverse exact de la plongée, piloté par le
    /// doigt via `driveClimb` — le zoom recule, le blanc se résorbe, la
    /// nuit revient. Ne s'arme que sur un doigt NEUF (le geste d'origine
    /// vit dans le handoff) et jamais après le sommet.
    private var returnDrag: some Gesture {
        DragGesture(minimumDistance: 14, coordinateSpace: .global)
            .onChanged { v in
                guard lensShown, !summited,
                      lensHandoff?.live != true,
                      v.translation.height > 0 else { return }
                if returnFrom == nil {
                    returnFrom = v.startLocation.y
                    lastDrive = v.location
                }
                // La poussière suit aussi le chemin du retour.
                if let prev = lastDrive {
                    Paillettes.shared.travel(
                        hypot(v.location.x - prev.x,
                              v.location.y - prev.y),
                        level: Self.climbGlobal(y: v.location.y,
                                                h: pageFull.height))
                }
                lastDrive = v.location
                // ~300 pt de descente pour défaire toute la plongée.
                let back = Double(v.translation.height) / 300.0
                let c = max(Self.dawnEnd * (1 - back), 0)
                driveClimb = c
                if c < 0.17 { lensShown = false }
                flood = 0.22 * Self.sstep(0, Self.nightEnd, c)
                        + 0.78 * Self.sstep(Self.nightEnd, Self.dawnEnd, c)
                RocketHaptics.shared.dragLevel(c)
            }
            .onEnded { v in
                guard returnFrom != nil else { return }
                returnFrom = nil
                lastDrive = nil
                RocketHaptics.shared.dragEnd()
                Paillettes.shared.end()
                if driveClimb < 0.11 {
                    // Revenue assez loin : la fiche reprend sa nuit.
                    closeBack()
                } else {
                    // Pas assez : la plongée se rejoue jusqu'au monde
                    // blanc, en ressort.
                    lensShown = true
                    withAnimation(.spring(response: 0.42,
                                          dampingFraction: 0.78)) {
                        driveClimb = Self.dawnEnd
                        flood = 1
                    }
                }
            }
    }

    private func target(for index: Int) -> String {
        guard sets.indices.contains(index) else { return "" }
        let set = sets[index]
        return "\(set.reps) reps · \(set.weight.formatted(.number.precision(.fractionLength(0...1)))) kg"
    }

    /// L'envol s'achève : le cadran rend la main, la page BRAVO prend la
    /// scène. Le papier tombe en même temps que la lentille — on passe d'une
    /// nuit à l'autre, le voile blanc n'a rien à faire entre les deux.
    private func startBravo(_ index: Int, _ o: LiquidLensLab.SeriesOutcome) {
        finished = FinishedSeries(index: index,
                                  reps: o.reps,
                                  kilos: o.kilos,
                                  rest: o.restSeconds,
                                  seconds: o.effortSeconds)
        flood = 0
        running = nil
        lensHandoff = nil
        driveClimb = 0
        lensShown = false
        summited = false
        posedLaunch = false
    }

    /// « Revenir à l'exercice » : BRAVO se retire, et la carte s'actualise —
    /// avec les VRAIS chiffres de la feuille, pas les valeurs de départ. Le
    /// repos choisi devient celui de l'exercice.
    private func closeBravo(_ f: FinishedSeries) {
        finished = nil
        restSeconds = f.rest
        // La carte ne s'écrit PLUS ici : l'écriture attend la sortie du
        // panneau « Recommencer ? » — les pièces et le compte se REGARDENT,
        // et c'est le panneau qui descend qui les découvre.
        restartAsk = f
    }

    /// La sortie du panneau — les trois chemins (drag, « Non », « Lancer »)
    /// passent ici.
    private func exitRestart(_ f: FinishedSeries, thenLaunch: Bool) {
        restartAsk = nil
        if thenLaunch {
            // Le cadran couvre la scène dans un instant : la carte s'écrit
            // sans cérémonie — les pièces n'ont de sens qu'à l'air libre.
            settleSeries(f, coins: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) {
                launchPosed()
            }
        } else {
            settleSeries(f, coins: true)
        }
    }

    /// L'écriture de la série, et sa lumière : la volée de pièces part
    /// d'abord, la carte s'allume quand elles se posent.
    private func settleSeries(_ f: FinishedSeries, coins: Bool) {
        guard sets.indices.contains(f.index), !sets[f.index].isDone
        else { return }
        let write = {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) {
                sets[f.index].reps = f.reps
                sets[f.index].weight = f.kilos
                sets[f.index].isDone = true
                sets[f.index].durationSeconds = f.seconds
            }
        }
        if coins {
            coinsAt = .now
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55,
                                          execute: write)
        } else {
            write()
        }
    }

    /// LA PORTE POSÉE : le cadran naît directement à demeure — pas de
    /// plongée, pas de sommet à gravir. Le panneau descend, le cadran
    /// s'éclaire en fondu, et c'est LUI qui compte 3-2-1 avant de lancer
    /// le temps (l'allumage du repos, rebranché sur l'effort).
    private func launchPosed() {
        let index: Int
        let appended: Bool
        if let pending = sets.firstIndex(where: { !$0.isDone }) {
            index = pending
            appended = false
        } else {
            sets.append(DraftSet(reps: sets.last?.reps ?? 12,
                                 weight: sets.last?.weight ?? 20))
            index = sets.count - 1
            appended = true
        }
        posedLaunch = true
        summited = true
        lensShown = true
        withAnimation(.easeOut(duration: 0.40)) {
            running = RunningSeries(id: index, appended: appended)
        }
        launchBeat += 1
    }

    // MARK: Historique

    /// La dernière fois que cet exercice a été fait, séance en cours exclue.
    private var lastLogged: LoggedExercise? {
        for workout in workouts where !workout.isActive {
            if let logged = workout.orderedExercises.first(where: { $0.exerciseID == exercise.id }) {
                return logged
            }
        }
        return nil
    }

    /// Ce qui a été fait la dernière fois sur cet exercice.
    private var lastTime: String? {
        guard let logged = lastLogged else { return nil }
        guard !logged.orderedSets.isEmpty else { return logged.summary }
        let count = logged.orderedSets.count
        let reps = logged.orderedSets.first?.reps ?? 0
        let weight = logged.maxWeight
        return "\(count) × \(reps) à \(weight.formatted(.number.precision(.fractionLength(0...1)))) kg"
    }

    // MARK: Enregistrement

    /// Enregistrer ne quitte PAS la fiche. On confirme, on repart d'une série
    /// vierge réglée sur les derniers chiffres, et on reste là.
    private func save() {
        var draft = LoggedDraft()
        switch exercise.tracking {
        case .setsRepsWeight:
            draft.sets = sets
            draft.restSeconds = restSeconds
        case .intervals:
            // Le cycle est construit une fois puis répété autant de fois que demandé.
            draft.cycles = Array(repeating: phases, count: max(repeatCount, 1))
        case .steady:
            draft.cycles = [[DraftPhase(kind: .recuperation,
                                        seconds: steadySeconds, speed: steadySpeed)]]
            draft.incline = incline
        }
        add(draft)

        if isStrength {
            // On repart de zéro série : la carte redit « 0 série en cours »,
            // et le prochain geste en fera naître une.
            withAnimation(.easeOut(duration: 0.25)) { sets = [] }
        }
    }

    /// Ajoute l'exercice à la séance en cours, en la créant si besoin.
    private func add(_ draft: LoggedDraft) {
        let workout: Workout
        if let active {
            workout = active
        } else {
            workout = Workout()
            context.insert(workout)
        }

        let logged = LoggedExercise(exerciseID: exercise.id,
                                    order: workout.exerciseCount,
                                    restSeconds: draft.restSeconds)
        logged.workout = workout
        context.insert(logged)

        for (index, set) in draft.sets.enumerated() {
            // Une série lancée au compteur arrive déjà cochée, avec son temps
            // sous tension : elle a été faite, pas seulement prévue.
            let entry = StrengthSet(reps: set.reps, weight: set.weight, order: index,
                                    isDone: set.isDone,
                                    durationSeconds: set.durationSeconds)
            entry.loggedExercise = logged
            context.insert(entry)
        }

        for (cycleIndex, cycle) in draft.cycles.enumerated() {
            for (order, phase) in cycle.enumerated() {
                let entry = CardioPhase(kind: phase.kind, seconds: phase.seconds,
                                        speed: phase.speed, cycleIndex: cycleIndex,
                                        order: order, incline: draft.incline)
                entry.loggedExercise = logged
                context.insert(entry)
            }
        }

        try? context.save()
        WorkoutActivityController.ensure(workout)
        withAnimation(.easeOut(duration: 0.25)) {
            confirmation = "Ajouté à ta séance en cours"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation { confirmation = nil }
        }
    }
}

// MARK: - Le halo du header (musculation)

/// LA LUMIÈRE DU HAUT DE FICHE : une seule source, hors cadre, en haut à
/// droite. Elle remplace le cadrage de `bgAurora` le jour où la carte noire
/// est morte — voir `ExoHeaderGlow.metal`, qui raconte pourquoi aucun
/// recadrage de ce champ-là ne pouvait donner un dégradé.
///
/// La hauteur est celle de la LUMIÈRE, pas d'une bande : il n'y a pas de
/// bord bas à cacher, le champ arrive à zéro tout seul bien avant 340. Elle
/// est posée en `plusLighter` par la page — ce halo n'est pas un fond, il
/// ÉCLAIRE ce qui est déjà dessiné.
///
/// 30 Hz suffisent : la seule chose qui bouge est une respiration de 22 s.
struct ExoHeaderGlow: View {
    var height: CGFloat = 340

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                let t = Float(tl.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 4096))
                Rectangle()
                    .fill(.black)   // JAMAIS .clear : le `* color.a` avale tout
                    .colorEffect(ShaderLibrary.exoHeaderGlow(
                        .float2(geo.size.width, height),
                        .float(t)))
            }
        }
        .frame(height: height)
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }
}

// MARK: - La carte-braise du header

/// La bande embrasée du haut de page — et c'est une CARTE, pas un décor :
/// plus tard elle se DÉPLIERA (la référence todo-list : date, heure, Done).
/// D'où son nom et sa frontière nette ; l'ouverture viendra s'y brancher.
///
/// La matière n'est pas imitée, elle est REPRISE : `bgAurora`, le champ
/// embrasé de la connexion. L'aurore y vit dans le bas d'un écran entier —
/// on rend donc le champ à sa hauteur virtuelle (`fieldHeight`) et on n'en
/// CADRE que la tranche basse, la plus riche : les rideaux de feu remplissent
/// la bande, la crête brûle juste derrière les coins de la carte noire.
///
/// 30 Hz suffisent : c'est un fond, pas un geste sous le doigt.
struct HeaderEmberCard: View {
    /// Hauteur visible de la bande — à peine plus que le header : la carte
    /// noire commence vers 118 pt, ses coins mordent jusqu'à ~158. Une bande
    /// plus haute gaspille la crête derrière le noir, là où personne ne la
    /// voit (le premier cadrage brûlait ENTIÈREMENT sous la carte).
    var height: CGFloat = 150
    /// Hauteur virtuelle du champ dont on cadre le bas. Comprimé : la crête
    /// et ses rideaux remplissent la bande au lieu de s'étirer sur un écran.
    /// C'est la crête — le fil embrasé du bord bas du champ, PLEINE largeur —
    /// qui doit affleurer derrière les coins de la carte noire ; les rideaux,
    /// eux, sont capricieux et se massent d'un côté selon l'instant.
    var fieldHeight: CGFloat = 260

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                let t = Float(tl.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 4096))
                Rectangle()
                    .fill(.black)   // JAMAIS .clear : le `* color.a` avale tout
                    .frame(width: geo.size.width, height: fieldHeight)
                    .colorEffect(ShaderLibrary.bgAurora(
                        .float2(geo.size.width, fieldHeight),
                        .float(t),
                        .float2(0, 0)))
                    .frame(width: geo.size.width, height: height,
                           alignment: .bottom)
                    .clipped()
                    // LE LIT DE BRAISE : le champ respire sur de longues
                    // minutes et passe par des creux presque noirs — un
                    // header-carte doit brûler à CHAQUE instant. Trois nappes
                    // fixes en `plusLighter` garantissent le plancher de feu,
                    // centres enfouis sous la carte noire : seule leur épaule
                    // haute affleure, et l'aurore vivante module par-dessus.
                    // En overlay : jamais dans le jeu de layout.
                    .overlay(alignment: .bottom) {
                        ZStack(alignment: .bottom) {
                            Ellipse()
                                .fill(Color(red: 1.0, green: 0.52, blue: 0.14))
                                .frame(width: 520, height: 130)
                                .blur(radius: 50)
                                .opacity(0.42)
                                .offset(y: 60)
                            Ellipse()
                                .fill(Color(red: 0.95, green: 0.25, blue: 0.05))
                                .frame(width: 280, height: 95)
                                .blur(radius: 40)
                                .opacity(0.38)
                                .offset(x: -135, y: 48)
                            Ellipse()
                                .fill(Color(red: 1.0, green: 0.68, blue: 0.25))
                                .frame(width: 230, height: 80)
                                .blur(radius: 34)
                                .opacity(0.40)
                                .offset(x: 150, y: 44)
                        }
                        .blendMode(.plusLighter)
                    }
                    .clipped()
            }
        }
        .frame(height: height)
        .allowsHitTesting(false)
    }
}
