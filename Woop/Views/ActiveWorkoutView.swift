import SwiftUI
import SwiftData

// MARK: - Accessoire de barre d'onglets

/// Barre flottante au-dessus de la navigation, sur le modèle du « en cours de
/// lecture » d'iOS. C'est le seul endroit où l'on utilise le liquid glass natif :
/// elle survole le contenu, donc elle doit le laisser transparaître.
struct ActiveWorkoutAccessory: View {
    let workout: Workout
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 11) {
                PulsingDot()

                VStack(alignment: .leading, spacing: 1) {
                    Text("Séance en cours")
                        .font(.system(.footnote, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color.inkPrimary)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(Color.inkMuted)
                }

                Spacer()

                Image(systemName: "chevron.up")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.woopViolet)
            }
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }

    private var subtitle: String {
        let count = workout.exerciseCount
        let exos = count == 0 ? "aucun exercice" : "\(count) exercice\(count > 1 ? "s" : "")"
        return "\(exos) · \(Int(workout.duration / 60)) min"
    }
}

// MARK: - Feuille de la séance en cours

struct ActiveWorkoutSheet: View {
    let workout: Workout

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var confirmFinish = false
    @State private var recap: Workout?

    var body: some View {
        NavigationStack {
            ZStack {
                WoopBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header

                        if workout.orderedExercises.isEmpty {
                            WoopCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Ta séance est prête.")
                                        .font(.system(.subheadline, design: .rounded,
                                                      weight: .semibold))
                                        .foregroundStyle(Color.inkPrimary)
                                    Text("Ajoute maintenant ton premier exercice depuis la bibliothèque.")
                                        .font(.footnote)
                                        .foregroundStyle(Color.inkMuted)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        } else {
                            ForEach(workout.orderedExercises) { logged in
                                ActiveExerciseCard(logged: logged) {
                                    withAnimation { context.delete(logged) }
                                }
                            }
                        }

                        Button("Terminer l'entraînement") { confirmFinish = true }
                            .buttonStyle(WoopPrimaryButtonStyle())
                            .disabled(workout.orderedExercises.isEmpty)
                            .opacity(workout.orderedExercises.isEmpty ? 0.4 : 1)

                        Button("Annuler cette séance", role: .destructive) {
                            context.delete(workout)
                            try? context.save()
                            dismiss()
                        }
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(Color.inkMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Entraînement en cours")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                        .foregroundStyle(Color.inkSecondary)
                }
            }
            .alert("Terminer cette séance ?", isPresented: $confirmFinish) {
                Button("Continuer la séance", role: .cancel) {}
                Button("Terminer") { finish() }
            } message: {
                Text("\(workout.exerciseCount) exercices · \(workout.setCount) séries · \(Int(workout.duration / 60)) minutes.")
            }
            .navigationDestination(item: $recap) { finished in
                WorkoutRecapView(workout: finished) { dismiss() }
            }
        }
        .presentationBackground(Color.woopSheet)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        WoopCard(neon: true) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Démarré à \(workout.startedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(Color.inkMuted)
                    Text("\(Int(workout.duration / 60)) minutes")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.inkPrimary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Volume")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(Color.inkMuted)
                    Text("\(Int(workout.totalVolume)) kg")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color.woopViolet)
                }
            }
        }
    }

    private func finish() {
        workout.endedAt = .now
        try? context.save()
        // La séance est déjà enregistrée localement ; l'envoi vers Supabase part
        // en tâche de fond et n'a pas le droit de bloquer l'interface.
        let snapshot = workout.snapshot()
        Task.detached { await SupabaseSync.shared.push([snapshot]) }
        recap = workout
    }
}

// MARK: - Exercice pendant la séance

/// Chaque série peut être cochée, et le réalisé corrigé : ce qui a été fait
/// diffère souvent de ce qui était prévu.
struct ActiveExerciseCard: View {
    @Bindable var logged: LoggedExercise
    var onDelete: () -> Void

    @Environment(\.modelContext) private var context
    @State private var expanded = true

    var body: some View {
        WoopCard(cornerRadius: 18, padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    ExerciseFigure(design: ExerciseFigures.design(for: logged.exerciseID),
                                   animated: false, lineWidth: 1.3)
                        .frame(width: 42, height: 42)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(logged.name)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(Color.inkPrimary)
                            .lineLimit(1)
                        Text(progressLabel)
                            .font(.caption)
                            .foregroundStyle(Color.inkMuted)
                    }

                    Spacer()

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(Color.inkMuted)
                    }
                }

                if !logged.orderedSets.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(Array(logged.orderedSets.enumerated()), id: \.element.id) { index, set in
                            SetRow(set: set, index: index)
                        }
                    }

                    Button {
                        let last = logged.orderedSets.last
                        let entry = StrengthSet(reps: last?.reps ?? 12,
                                                weight: last?.weight ?? 20,
                                                order: logged.orderedSets.count)
                        entry.loggedExercise = logged
                        context.insert(entry)
                    } label: {
                        Label("Ajouter une série", systemImage: "plus")
                            .font(.system(.caption, design: .rounded, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.woopViolet)
                }

                if !logged.orderedPhases.isEmpty {
                    LoggedPhaseTimeline(phases: logged.orderedPhases)
                }
            }
        }
    }

    private var progressLabel: String {
        if logged.orderedSets.isEmpty { return logged.summary }
        return "\(logged.completedSets) séries sur \(logged.orderedSets.count) terminées"
    }
}

/// Une série : case à cocher, répétitions et charge réellement effectuées.
struct SetRow: View {
    @Bindable var set: StrengthSet
    let index: Int

    var body: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    set.isDone.toggle()
                }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(set.isDone ? Color.woopGold.opacity(0.18)
                                         : Color.white.opacity(0.04))
                        .frame(width: 26, height: 26)
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(set.isDone ? Color.woopGold.opacity(0.55)
                                                 : Color.white.opacity(0.14),
                                      lineWidth: 1)
                        .frame(width: 26, height: 26)
                    if set.isDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.woopGold)
                    } else {
                        Text("\(index + 1)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.inkMuted)
                    }
                }
            }
            .buttonStyle(.plain)

            MiniStepper(text: "\(set.reps) reps",
                        onMinus: { set.reps = max(1, set.reps - 1) },
                        onPlus: { set.reps = min(60, set.reps + 1) })

            Spacer(minLength: 0)

            MiniStepper(text: "\(set.weight.formatted(.number.precision(.fractionLength(0...1)))) kg",
                        onMinus: { set.weight = max(0, set.weight - 2.5) },
                        onPlus: { set.weight = min(300, set.weight + 2.5) })
        }
        .opacity(set.isDone ? 0.55 : 1)
    }
}

/// Version compacte du pas-à-pas, pour corriger le réalisé sans quitter la séance.
struct MiniStepper: View {
    let text: String
    let onMinus: () -> Void
    let onPlus: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onMinus) {
                Image(systemName: "minus")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 26, height: 26)
            }
            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.inkPrimary)
                .frame(minWidth: 56)
                .contentTransition(.numericText())
            Button(action: onPlus) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 26, height: 26)
            }
        }
        .foregroundStyle(Color.woopViolet)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.white.opacity(0.09), lineWidth: 1)
        )
        .buttonStyle(.plain)
    }
}

/// Timeline en lecture seule d'un cardio enregistré.
struct LoggedPhaseTimeline: View {
    let phases: [CardioPhase]

    private var total: Int { max(phases.reduce(0) { $0 + $1.seconds }, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(phases) { phase in
                        let width = geo.size.width * CGFloat(phase.seconds) / CGFloat(total)
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(Color.white.opacity(0.14 + 0.58 * phase.kind.intensity))
                            .frame(width: max(width - 2, 2),
                                   height: 10 + 26 * phase.kind.intensity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
            .frame(height: 38)

            Text(logged)
                .font(.caption2)
                .foregroundStyle(Color.inkMuted)
        }
    }

    private var logged: String {
        let minutes = total / 60
        let peak = phases.map(\.speed).max() ?? 0
        let cycleCount = Set(phases.map(\.cycleIndex)).count
        return "\(minutes) min · \(cycleCount) cycle\(cycleCount > 1 ? "s" : "") · pic \(peak.formatted(.number.precision(.fractionLength(0...1)))) km/h"
    }
}

// MARK: - Carte en lecture seule (historique)

struct LoggedExerciseCard: View {
    let logged: LoggedExercise

    var body: some View {
        WoopCard(cornerRadius: 18, padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ExerciseFigure(design: ExerciseFigures.design(for: logged.exerciseID),
                                   animated: false, lineWidth: 1.3)
                        .frame(width: 42, height: 42)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(logged.name)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(Color.inkPrimary)
                            .lineLimit(1)
                        Text(logged.summary)
                            .font(.caption)
                            .foregroundStyle(Color.inkMuted)
                    }
                    Spacer()
                }

                if !logged.orderedSets.isEmpty {
                    FlowChips(items: logged.orderedSets.map {
                        "\($0.reps) × \($0.weight.formatted(.number.precision(.fractionLength(0...1)))) kg"
                    })
                    if logged.restSeconds > 0 {
                        Text("Récupération \(logged.restSeconds) s")
                            .font(.caption2)
                            .foregroundStyle(Color.inkMuted)
                    }
                }

                if !logged.orderedPhases.isEmpty {
                    LoggedPhaseTimeline(phases: logged.orderedPhases)
                }
            }
        }
    }
}

/// Petites pastilles qui s'enroulent sur plusieurs lignes.
struct FlowChips: View {
    let items: [String]
    var highlight: [Bool] = []

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 6)],
                  alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, text in
                Chip(text: text, isHot: index < highlight.count && highlight[index])
            }
        }
    }

    private struct Chip: View {
        let text: String
        let isHot: Bool

        private var ink: Color { isHot ? .woopGold : .inkSecondary }
        private var fill: Color { isHot ? Color.woopGold.opacity(0.12) : Color.white.opacity(0.05) }
        private var edge: Color { isHot ? Color.woopGold.opacity(0.30) : Color.white.opacity(0.08) }

        var body: some View {
            Text(text)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity)
                .background(Capsule().fill(fill))
                .overlay(Capsule().strokeBorder(edge, lineWidth: 1))
        }
    }
}

// MARK: - Récapitulatif de fin de séance

struct WorkoutRecapView: View {
    let workout: Workout
    let onClose: () -> Void

    var body: some View {
        ZStack {
            WoopBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    WoopCard(neon: true) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Séance terminée")
                                .font(.system(.footnote, design: .rounded))
                                .foregroundStyle(Color.inkMuted)
                            HStack(spacing: 24) {
                                StatBlock(value: "\(Int(workout.duration / 60))", label: "minutes")
                                StatBlock(value: "\(workout.exerciseCount)", label: "exercices")
                                StatBlock(value: "\(workout.setCount)", label: "séries")
                            }
                        }
                    }

                    ForEach(workout.orderedExercises) { logged in
                        LoggedExerciseCard(logged: logged)
                    }

                    Button("Terminé") { onClose() }
                        .buttonStyle(WoopPrimaryButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Récapitulatif")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
    }
}
