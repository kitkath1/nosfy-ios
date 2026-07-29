import SwiftUI
import SwiftData

struct ExercisesView: View {
    @State private var filter: ExerciseCategory?

    private var shown: [ExerciseCategory] {
        filter.map { [$0] } ?? ExerciseCategory.allCases
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // EXACTEMENT le même ciel que la home : horloge globale, état
                // partagé (scroll, révélation, gyro) — changer d'onglet ne
                // change rien. Un onglet caché n'est pas rendu : coût nul.
                WoopBackground(animated: true)
                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        Text("Construis tes séances à partir de ta bibliothèque.")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(Color.inkSecondary)

                        CategoryFilter(selection: $filter)

                        ForEach(shown) { category in
                            VStack(alignment: .leading, spacing: 14) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(category.rawValue)
                                        .font(.system(.title3, design: .rounded, weight: .semibold))
                                        .foregroundStyle(Color.inkPrimary)
                                    Text(category.subtitle)
                                        .font(.footnote)
                                        .foregroundStyle(Color.inkMuted)
                                }

                                LazyVGrid(
                                    columns: [GridItem(.flexible(), spacing: 14),
                                              GridItem(.flexible(), spacing: 14)],
                                    spacing: 14
                                ) {
                                    ForEach(ExerciseCatalog.exercises(in: category)) { exercise in
                                        NavigationLink {
                                            ExerciseDetailView(exercise: exercise)
                                        } label: {
                                            ExerciseCard(exercise: exercise)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 130)
                }
            }
            .navigationTitle("Exercices")
        }
    }
}

// MARK: - Filtre de catégorie

struct CategoryFilter: View {
    @Binding var selection: ExerciseCategory?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "Tout", isOn: selection == nil) { selection = nil }
                ForEach(ExerciseCategory.allCases) { category in
                    FilterChip(title: category.rawValue, isOn: selection == category) {
                        selection = selection == category ? nil : category
                    }
                }
            }
        }
        .scrollClipDisabled()
    }

    private struct FilterChip: View {
        let title: String
        let isOn: Bool
        let action: () -> Void

        var body: some View {
            Button(action: { withAnimation(.easeOut(duration: 0.2)) { action() } }) {
                Text(title)
                    .font(.system(.footnote, design: .rounded, weight: .semibold))
                    .foregroundStyle(isOn ? Color.white : Color.inkSecondary)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 9)
                    .background(
                        Capsule().fill(isOn ? AnyShapeStyle(WoopGradient.neonFill)
                                            : AnyShapeStyle(Color.white.opacity(0.045)))
                    )
                    .overlay(
                        Capsule().strokeBorder(
                            isOn ? Color.white.opacity(0.35) : Color.white.opacity(0.09),
                            lineWidth: 1
                        )
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Carte d'exercice

struct ExerciseCard: View {
    let exercise: Exercise

    private static let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Bord à bord, sans marge : le noir de la photo EST le noir de la
            // carte, une marge ne séparerait rien de rien — elle ne ferait que
            // rapetisser le corps.
            ExercisePhoto(exercise: exercise)
                .frame(height: 152)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.inter(12.5, .semibold))
                    .foregroundStyle(Color.inkPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2, reservesSpace: true)
                    .fixedSize(horizontal: false, vertical: true)

                Text(exercise.muscle)
                    .font(.inter(10))
                    .foregroundStyle(Color.inkMuted)
                    .lineLimit(1)

                Text(exercise.equipment.rawValue.uppercased())
                    .font(.inter(8, .bold))
                    .tracking(0.8)
                    .foregroundStyle(Color.white.opacity(0.32))
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.05)))
                    .padding(.top, 2)
            }
            .padding(.horizontal, 14)
            .padding(.top, 11)
            .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(Self.shape)
        .diamondSurface(cornerRadius: 22)
    }
}

// MARK: - Détail

struct ExerciseDetailView: View {
    let exercise: Exercise

    @Environment(\.modelContext) private var context
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]

    @State private var showLogger = false
    @State private var confirmation: String?

    private var active: Workout? { workouts.first { $0.isActive } }

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

    var body: some View {
        ZStack {
            // Pas de ciel ici : la fiche est une page NOIRE. La photo occupe le
            // haut de l'écran et son fond doit se perdre dans la page — une
            // nébuleuse derrière lui redessinerait aussitôt son rectangle.
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    hero

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Tag(text: exercise.category.rawValue)
                            Tag(text: exercise.equipment.rawValue)
                        }

                        Text(exercise.name)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.inkPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(exercise.muscle)
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(Color.woopViolet)
                    }

                    WoopCard(cornerRadius: 18, padding: 18) {
                        VStack(alignment: .leading, spacing: 14) {
                            InfoBlock(label: "Exécution", text: exercise.cue)
                            Divider().overlay(Color.white.opacity(0.06))
                            InfoBlock(label: "Erreur à éviter", text: exercise.mistake,
                                      accent: true)
                        }
                    }

                    if let confirmation {
                        Label(confirmation, systemImage: "checkmark.circle.fill")
                            .font(.system(.footnote, design: .rounded, weight: .medium))
                            .foregroundStyle(Color.woopGold)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    DiamondPrimaryButton(title: "Lancer l'entraînement") { showLogger = true }

                    if active == nil {
                        Text("Aucune séance en cours — elle sera créée automatiquement.")
                            .font(.caption)
                            .foregroundStyle(Color.inkMuted)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 130)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showLogger) {
            LogExerciseSheet(exercise: exercise, lastTime: lastTime) { draft in
                add(draft)
            }
        }
    }

    /// La photo ENTIÈRE, jamais rognée : sur la fiche, c'est le mouvement
    /// complet — l'appui, l'angle, la machine — qui porte l'information.
    private var hero: some View {
        ExercisePhoto(exercise: exercise, fills: false)
            .frame(height: 340)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .diamondSurface(cornerRadius: 24, neon: true)
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

// MARK: - Petits composants

struct Tag: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .tracking(0.9)
            .foregroundStyle(Color.white.opacity(0.42))
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(Capsule().fill(Color.white.opacity(0.05)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }
}

struct InfoBlock: View {
    let label: String
    let text: String
    var accent: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.9)
                .foregroundStyle(accent ? Color.woopGold.opacity(0.85) : Color.inkMuted)
            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
