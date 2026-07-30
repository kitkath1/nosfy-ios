import SwiftUI
import SwiftData
import CoreText

@main
struct WoopApp: App {
    let container: ModelContainer

    init() {
        // Les Inter (Woop/Fonts) s'enregistrent ici : l'Info.plist est généré
        // par Xcode, il n'y a pas de clé UIAppFonts où les déclarer.
        for url in Bundle.main.urls(forResourcesWithExtension: "otf", subdirectory: nil) ?? [] {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        do {
            container = try ModelContainer(
                for: Workout.self, LoggedExercise.self, StrengthSet.self, CardioPhase.self
            )
        } catch {
            fatalError("Impossible d'initialiser la base : \(error)")
        }
        if CommandLine.arguments.contains("-demoData") {
            DemoData.seedIfEmpty(in: container)
        }
        if CommandLine.arguments.contains("-activeWorkout") {
            DemoData.seedActiveWorkout(in: container)
        }
        // La LUT du ciel se génère en tâche de fond pendant le splash — au
        // premier rendu de la home, elle est déjà prête. (NebulaStrip n'est
        // plus chauffée : la carte Objectif est redevenue pure lumière.)
        NebulaNoise.warmUp()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .tint(.woopViolet)
        }
        .modelContainer(container)
    }
}

// MARK: - Racine

enum WoopTab: String, Hashable {
    case home, exercises, progress, calendar
}

struct RootView: View {
    /// Banc d'essai du splash : lancée avec `-splashTest`, l'app ne va jamais
    /// à l'accueil — la séquence se termine sur un bouton « Rejouer ».
    private static let splashTest = CommandLine.arguments.contains("-splashTest")
    /// Banc d'essai de la Live Activity : `-cometTest` affiche les composants
    /// de l'écran verrouillé (comète-progression, diablotin) dans l'app —
    /// le simulateur ne sait pas montrer l'écran verrouillé.
    private static let cometTest = CommandLine.arguments.contains("-cometTest")
    /// Banc d'essai du bouton CONNEXION : `-buttonLab`, page noire nue.
    private static let buttonLab = CommandLine.arguments.contains("-buttonLab")
    /// Banc d'essai de la carte Objectif : `-cardLab`, page noire nue.
    private static let cardLab = CommandLine.arguments.contains("-cardLab")
    /// Banc d'essai du cadran éclipse : `-counterLab`, page noire nue.
    private static let counterLab = CommandLine.arguments.contains("-counterLab")
    @State private var showSplash = true
    /// L'authentification suit le splash à CHAQUE lancement ; un toucher sur
    /// « Se connecter » fait entrer immédiatement. `-skipAuth` la court-circuite
    /// (captures d'écran automatisées uniquement).
    @State private var showAuth = !CommandLine.arguments.contains("-skipAuth")
    @State private var selection: WoopTab = {
        if let raw = UserDefaults.standard.string(forKey: "openTab"),
           let tab = WoopTab(rawValue: raw) {
            return tab
        }
        return .home
    }()

    /// L'entraînement ouvert, s'il y en a un.
    @Query(filter: #Predicate<Workout> { $0.endedAt == nil },
           sort: \Workout.startedAt, order: .reverse)
    private var activeWorkouts: [Workout]

    @Environment(\.modelContext) private var modelContext

    /// La feuille tient SA séance, pas « la séance ouverte » : à l'instant où on
    /// termine, il n'y a plus de séance ouverte — présentée sur un booléen, la
    /// feuille se viderait en plein récapitulatif.
    @State private var sheetWorkout: Workout?
    /// Morphisme : la carte de séance est la source du zoom vers la feuille.
    @Namespace private var overlayZoom

    private var active: Workout? { activeWorkouts.first }

    var body: some View {
        if Self.splashTest {
            splashBench
        } else if Self.cometTest {
            cometBench
        } else if Self.buttonLab {
            ConnexionButtonLab()
        } else if Self.cardLab {
            ObjectiveCardLab()
        } else if Self.counterLab {
            CounterLab()
        } else {
            mainBody
        }
    }

    /// Le banc d'essai de l'écran verrouillé : la comète démarrée il y a
    /// 12 minutes (traversée en 90), et le diablotin sous trois regards.
    private var cometBench: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 40) {
                ProgressComet(startedAt: .now.addingTimeInterval(-12 * 60))
                    .frame(height: 34)
                ProgressComet(startedAt: .now.addingTimeInterval(-45 * 60))
                    .frame(height: 34)
                HStack(spacing: 30) {
                    ImpGlyph(size: 26, gaze: .zero)
                    ImpGlyph(size: 26, gaze: CGSize(width: -1, height: 0.3))
                    ImpGlyph(size: 26, gaze: CGSize(width: 1, height: -0.5))
                    ImpGlyph(size: 17, gaze: CGSize(width: 0.6, height: 0))
                }
            }
            .padding(.horizontal, 24)
        }
    }

    /// Le banc d'essai : rien que le splash, en boucle à la demande.
    @ViewBuilder
    private var splashBench: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if showSplash {
                SplashView {
                    withAnimation(.easeOut(duration: 0.4)) { showSplash = false }
                }
            } else {
                Button {
                    showSplash = true
                } label: {
                    Label("Rejouer", systemImage: "arrow.counterclockwise")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color.inkPrimary)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }
        }
    }

    private var mainBody: some View {
        ZStack {
            // « Un seul ciel » : horloge globale (temps absolu modulo 900 s)
            // + état partagé SkyState (scroll, révélation, gyro) — chaque
            // onglet rend EXACTEMENT les mêmes pixels, et changer d'onglet ne
            // change rien au ciel. Un onglet caché n'est pas rendu : le coût
            // GPU reste celui d'une seule instance.
            TabView(selection: $selection) {
                Tab("Accueil", systemImage: "house.fill", value: WoopTab.home) {
                    HomeView(selection: $selection)
                }
                Tab("Exercices", systemImage: "figure.strengthtraining.functional",
                    value: WoopTab.exercises) {
                    ExercisesView()
                }
                Tab("Progrès", systemImage: "chart.line.uptrend.xyaxis", value: WoopTab.progress) {
                    ProgressionView()
                }
                Tab("Calendrier", systemImage: "calendar", value: WoopTab.calendar) {
                    CalendarView()
                }
            }
            // Verre fumé permanent : le verre adaptatif devenait laiteux sur
            // la brume cramée (libellés illisibles) ; en sombre forcé, la
            // lumière qui le traverse devient une signature.
            .toolbarColorScheme(.dark, for: .tabBar)
            .modifier(ActiveAccessory(workout: active, namespace: overlayZoom,
                                      hidden: selection == .exercises) {
                sheetWorkout = active
            })
            .sheet(item: $sheetWorkout) { workout in
                // « Annuler cette séance » la supprime pendant que la feuille
                // se referme : on ne lit pas un objet déjà sorti de la base.
                if !workout.isDeleted {
                    ActiveWorkoutSheet(workout: workout) {
                        // « Ajouter un exercice » : on referme la feuille et on
                        // ouvre la bibliothèque — c'est là qu'on loggue.
                        sheetWorkout = nil
                        selection = .exercises
                    }
                    .navigationTransition(.zoom(sourceID: "activeOverlay", in: overlayZoom))
                }
            }

            if showAuth {
                // Le socle noir reste en place pendant tout le tuilage
                // splash → auth : jamais un pixel de la home ne transparaît.
                Color.black.ignoresSafeArea()
                    .zIndex(8)
                    .transition(.opacity)
                if !showSplash {
                    AuthView { phone in
                        UserDefaults.standard.set(phone, forKey: "woop.phone")
                        withAnimation(.easeOut(duration: 0.6)) { showAuth = false }
                    }
                    .transition(.opacity)
                    .zIndex(9)
                }
            }

            if showSplash {
                // Le splash tient sa propre horloge : lui seul sait quand sa
                // séquence est finie, et il peut être passé d'un toucher.
                SplashView {
                    withAnimation(.easeOut(duration: 0.5)) { showSplash = false }
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        // Live Activity : une séance restée ouverte retrouve son île au
        // lancement ; démarrage/fin ailleurs suivent le cycle réel.
        .onAppear { WorkoutActivityController.ensure(active) }
        .onChange(of: activeWorkouts.isEmpty) { _, _ in
            WorkoutActivityController.ensure(active)
            celebrateFinishedWorkout()
        }
        .onChange(of: sheetWorkout == nil) { _, _ in celebrateFinishedWorkout() }
        .task {
            // `-openActiveSheet` ouvre la feuille de séance dès le lancement
            // (captures d'écran automatisées uniquement).
            if CommandLine.arguments.contains("-openActiveSheet"), sheetWorkout == nil {
                sheetWorkout = active
            }
            // Rattrapage : toutes les séances terminées repartent à chaque
            // lancement. Une séance finie hors ligne (salle en mode avion)
            // monte donc au premier lancement avec du réseau — l'upsert
            // merge-duplicates rend l'envoi répété inoffensif.
            let workouts = (try? modelContext.fetch(FetchDescriptor<Workout>())) ?? []
            let snapshots = workouts.filter { $0.endedAt != nil }.map { $0.snapshot() }
            Task.detached { await SupabaseSync.shared.push(snapshots) }
        }
        #if DEBUG
        .overlay(alignment: .topTrailing) {
            // Bouton de test : rejoue le splash. Debug uniquement.
            if !showSplash {
                Button {
                    showSplash = true
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.inkSecondary)
                        .frame(width: 34, height: 34)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .padding(.trailing, 16)
                .padding(.top, 4)
            }
        }
        #endif
    }

    /// Un entraînement vient d'être terminé : la récompense doit être VUE. On
    /// attend que la feuille soit refermée, on ramène sur la home, et la carte
    /// Objectif remplit alors son rond. Appelé à chaque étape possible de ce
    /// retour — `deliver()` ne joue qu'une fois.
    private func celebrateFinishedWorkout() {
        guard WoopCelebration.shared.awaiting,
              sheetWorkout == nil, active == nil else { return }
        if selection != .home { selection = .home }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            WoopCelebration.shared.deliver()
        }
    }
}

/// L'overlay de séance n'existe que s'il y a une séance ouverte. On n'utilise
/// plus `tabViewBottomAccessory` : sa hauteur est figée par le système, trop
/// petite pour le halo égaliseur + la ligne entraînement/Arrêter. La carte
/// flotte donc au-dessus de la barre d'onglets, en verre liquide natif.
/// Cachée sur l'onglet Exercices : c'est là qu'on ajoute — la carte masquerait
/// les boutons d'ajout en bas des fiches.
private struct ActiveAccessory: ViewModifier {
    let workout: Workout?
    let namespace: Namespace.ID
    var hidden: Bool = false
    let onTap: () -> Void

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let workout, !hidden {
                ActiveWorkoutOverlay(workout: workout, onOpen: onTap)
                    .matchedTransitionSource(id: "activeOverlay", in: namespace)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 58)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.25), value: hidden)
    }
}

// MARK: - Données de démonstration

/// Peuplées uniquement avec l'argument de lancement `-demoData`.
enum DemoData {
    /// Ouvre une séance en cours (argument `-activeWorkout`) : sert à vérifier
    /// visuellement l'overlay de séance sans passer par l'interface.
    @MainActor
    static func seedActiveWorkout(in container: ModelContainer) {
        let context = container.mainContext
        let open = (try? context.fetchCount(FetchDescriptor<Workout>(
            predicate: #Predicate { $0.endedAt == nil }))) ?? 0
        guard open == 0 else { return }

        let workout = Workout(startedAt: .now.addingTimeInterval(-8 * 60))
        context.insert(workout)
        let logged = LoggedExercise(exerciseID: "hip-thrust", order: 0)
        logged.workout = workout
        context.insert(logged)
        let set = StrengthSet(reps: 12, weight: 45, order: 0)
        set.loggedExercise = logged
        context.insert(set)
        try? context.save()
    }

    @MainActor
    static func seedIfEmpty(in container: ModelContainer) {
        let context = container.mainContext
        let existing = (try? context.fetchCount(FetchDescriptor<Workout>())) ?? 0
        guard existing == 0 else { return }

        let calendar = Calendar.current
        func daysAgo(_ days: Int, hour: Int = 18) -> Date {
            let day = calendar.date(byAdding: .day, value: -days, to: .now) ?? .now
            return calendar.date(bySettingHour: hour, minute: 15, second: 0, of: day) ?? day
        }

        struct Plan {
            let days: Int
            let strength: [(String, [(Int, Double)])]
            let cardio: [(String, [(PhaseKind, Int, Double)])]
        }

        let plans: [Plan] = [
            Plan(days: 26,
                 strength: [("woop-haute", [(12, 15), (12, 15), (10, 17.5)]),
                            ("hip-thrust", [(12, 40), (10, 45)])],
                 cardio: []),
            Plan(days: 24,
                 strength: [],
                 cardio: [("hiit-tapis", [(.repos, 60, 6), (.acceleration, 30, 13), (.recuperation, 90, 6), (.acceleration, 30, 13), (.recuperation, 90, 6), (.sprint, 30, 14)])]),
            Plan(days: 21,
                 strength: [("kickback", [(15, 10), (15, 10), (12, 12.5)]),
                            ("pull-through", [(12, 25), (12, 27.5)])],
                 cardio: []),
            Plan(days: 19,
                 strength: [("woop-haute", [(12, 17.5), (12, 17.5), (10, 20)]),
                            ("rotation-milieu", [(15, 12.5), (15, 12.5)])],
                 cardio: []),
            Plan(days: 16,
                 strength: [],
                 cardio: [("escalier", [(.recuperation, 600, 7), (.acceleration, 300, 9)])]),
            Plan(days: 14,
                 strength: [("hip-thrust", [(12, 45), (10, 50), (10, 50)]),
                            ("abduction", [(15, 7.5), (15, 7.5)])],
                 cardio: []),
            Plan(days: 12,
                 strength: [("woop-haute", [(12, 20), (10, 20), (10, 22.5)]),
                            ("gainage-militaire", [(10, 10), (10, 10)])],
                 cardio: []),
            Plan(days: 9,
                 strength: [],
                 cardio: [("hiit-tapis", [(.repos, 60, 6), (.acceleration, 30, 14), (.recuperation, 90, 6), (.acceleration, 30, 14), (.recuperation, 90, 6), (.sprint, 30, 15), (.repos, 120, 5)])]),
            Plan(days: 7,
                 strength: [("abduction", [(15, 10), (15, 10), (12, 12.5)]),
                            ("squat-poulie", [(15, 25), (15, 25)])],
                 cardio: []),
            Plan(days: 5,
                 strength: [("woop-haute", [(12, 22.5), (12, 22.5), (10, 25)]),
                            ("crunch-machine", [(15, 30), (15, 32.5)])],
                 cardio: []),
            Plan(days: 4,
                 strength: [("hip-thrust", [(12, 50), (10, 55), (8, 60)])],
                 cardio: [("tapis-lent", [(.recuperation, 1200, 5.5)])]),
            Plan(days: 2,
                 strength: [("kickback", [(15, 12.5), (15, 12.5), (12, 15)]),
                            ("pull-through", [(12, 27.5), (12, 30)])],
                 cardio: []),
            Plan(days: 1,
                 strength: [("woop-haute", [(12, 25), (12, 25), (10, 27.5)]),
                            ("gainage-militaire", [(8, 10), (8, 10)])],
                 cardio: [])
        ]

        for plan in plans {
            let workout = Workout(startedAt: daysAgo(plan.days))
            workout.endedAt = daysAgo(plan.days).addingTimeInterval(60 * 52)
            context.insert(workout)
            var order = 0

            for (exerciseID, sets) in plan.strength {
                let logged = LoggedExercise(exerciseID: exerciseID, order: order)
                logged.workout = workout
                context.insert(logged)
                for (i, s) in sets.enumerated() {
                    let set = StrengthSet(reps: s.0, weight: s.1, order: i)
                    set.loggedExercise = logged
                    context.insert(set)
                }
                order += 1
            }

            for (exerciseID, cycles) in plan.cardio {
                let logged = LoggedExercise(exerciseID: exerciseID, order: order)
                logged.workout = workout
                context.insert(logged)
                for (i, c) in cycles.enumerated() {
                    let phase = CardioPhase(kind: c.0, seconds: c.1, speed: c.2,
                                            cycleIndex: i / 2, order: i % 2)
                    phase.loggedExercise = logged
                    context.insert(phase)
                }
                order += 1
            }
        }

        try? context.save()
    }
}
