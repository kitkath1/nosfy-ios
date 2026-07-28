import SwiftUI
import SwiftData

@main
struct WoopApp: App {
    let container: ModelContainer

    init() {
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
        // La LUT du ciel se génère en tâche de fond pendant le splash — au
        // premier rendu de la home, elle est déjà prête.
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

    @State private var showSplash = true
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

    @State private var showActiveSheet = false

    private var active: Workout? { activeWorkouts.first }

    var body: some View {
        if Self.splashTest {
            splashBench
        } else {
            mainBody
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
                    HomeView(selection: $selection, showActiveSheet: $showActiveSheet)
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
            .modifier(ActiveAccessory(workout: active) { showActiveSheet = true })
            .sheet(isPresented: $showActiveSheet) {
                if let active {
                    ActiveWorkoutSheet(workout: active)
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
}

/// Le conteneur de verre de la barre d'onglets s'affiche même quand son contenu
/// est vide : on n'attache donc le modificateur que s'il y a une séance ouverte.
private struct ActiveAccessory: ViewModifier {
    let workout: Workout?
    let onTap: () -> Void

    func body(content: Content) -> some View {
        if let workout {
            content.tabViewBottomAccessory {
                ActiveWorkoutAccessory(workout: workout, onTap: onTap)
            }
        } else {
            content
        }
    }
}

// MARK: - Données de démonstration

/// Peuplées uniquement avec l'argument de lancement `-demoData`.
enum DemoData {
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
                            ("sdt-roumain", [(12, 25), (12, 27.5)])],
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
                 strength: [("sdt-roumain", [(12, 30), (12, 30), (10, 32.5)]),
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
                            ("gainage-militaire-1j", [(8, 10), (8, 10)])],
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
