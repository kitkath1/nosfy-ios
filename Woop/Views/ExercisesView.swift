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
                WoopBackground()
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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ExerciseFigure(design: ExerciseFigures.design(for: exercise.id),
                           animated: false, lineWidth: 1.6)
                .frame(height: 92)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.system(.footnote, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color.inkPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2, reservesSpace: true)
                    .fixedSize(horizontal: false, vertical: true)

                Text(exercise.muscle)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(Color.inkMuted)
                    .lineLimit(1)

                Text(exercise.equipment.rawValue.uppercased())
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(Color.white.opacity(0.32))
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.05)))
                    .padding(.top, 2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .metalSurface(cornerRadius: 22)
    }
}

// MARK: - Détail

struct ExerciseDetailView: View {
    let exercise: Exercise

    @Environment(\.modelContext) private var context
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]

    @State private var showLogger = false
    @State private var confirmation: String?
    @State private var paused = false

    private var active: Workout? { workouts.first { $0.isActive } }

    /// Ce qui a été fait la dernière fois sur cet exercice.
    private var lastTime: String? {
        for workout in workouts where !workout.isActive {
            if let logged = workout.orderedExercises.first(where: { $0.exerciseID == exercise.id }) {
                if !logged.orderedSets.isEmpty {
                    let count = logged.orderedSets.count
                    let reps = logged.orderedSets.first?.reps ?? 0
                    let weight = logged.maxWeight
                    return "\(count) × \(reps) à \(weight.formatted(.number.precision(.fractionLength(0...1)))) kg"
                }
                return logged.summary
            }
        }
        return nil
    }

    var body: some View {
        ZStack {
            WoopBackground()
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

                    Button("Ajouter à l'entraînement") { showLogger = true }
                        .buttonStyle(WoopPrimaryButtonStyle())

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

    private var hero: some View {
        ZStack(alignment: .topTrailing) {
            ExerciseFigure(design: ExerciseFigures.design(for: exercise.id),
                           animated: !paused, lineWidth: 2.4)
                .id(paused)
                .padding(26)
                .frame(height: 296)
                .frame(maxWidth: .infinity)

            Button {
                withAnimation(.easeOut(duration: 0.2)) { paused.toggle() }
            } label: {
                Image(systemName: paused ? "play.fill" : "pause.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.inkSecondary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.white.opacity(0.06)))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(16)
        }
        .metalSurface(cornerRadius: 24, neon: true)
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
            let entry = StrengthSet(reps: set.reps, weight: set.weight, order: index)
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
