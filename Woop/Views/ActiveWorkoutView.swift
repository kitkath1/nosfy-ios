import SwiftUI
import SwiftData

// MARK: - La séance en cours se dit par le GALET
//
// Il n'y a plus d'overlay de séance. La carte flottante en verre liquide
// (poignée, halo égaliseur, « Terminer l'entraînement » en pleine largeur) a
// été retirée le 2026-08-05, comme la pastille de lecteur qui l'avait
// brièvement remplacée : « seul le bouton central animé suffit ». Une séance
// ouverte se lit maintenant au galet de la barre, dont le triangle se referme
// en cercle de néon (JewelTabBar, paramètre `running`) — et c'est ce même
// galet qui ramène la séance, la feuille portant le geste de fin.

// MARK: - Le geste de fin

/// « Terminer l'entraînement » : le même bouton dans la carte flottante et dans
/// la feuille — c'est lui qui se déplace pendant le morphisme, donc il ne peut
/// pas exister en deux versions. Verre clair sur verre fumé, pleine largeur :
/// c'est l'action de la séance, pas une commande parmi d'autres.
struct FinishWorkoutButton: View {
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 11, weight: .bold))
                Text("Terminer l'entraînement")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
            }
            .foregroundStyle(Color.inkPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Capsule().fill(Color.white.opacity(0.10)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }
}

// MARK: - Respiration de lumière

/// La signature de la séance en cours : pas un visualiseur, une énergie.
/// Un orbe de lumière blanche glisse lentement le long d'un filament et laisse
/// une traînée qui s'éteint, pendant que de fines poussières montent — le même
/// langage que le splash (orbe électrique, poussière), en blanc.
struct BreathingGlow: View {
    var paused = false

    private static let dustCount = 14

    /// Pseudo-aléatoire déterministe par indice — stable d'une frame à l'autre.
    private static func hash(_ i: Int, _ seed: Double) -> Double {
        let v = sin(Double(i) * 127.1 + seed * 311.7) * 43758.5453
        return v - v.rounded(.down)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: paused)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let w = size.width, h = size.height

                // La position de l'orbe : un glissement lent gauche-droite,
                // avec une ondulation verticale décalée — la course ne se
                // répète jamais à l'identique.
                func orb(_ time: Double) -> CGPoint {
                    CGPoint(x: w * (0.5 + 0.37 * sin(time * 0.55)),
                            y: h * (0.5 + 0.17 * sin(time * 1.15 + 0.9)))
                }

                // Le filament : la ligne de vie que l'orbe parcourt, à peine
                // là, éteinte aux deux bouts.
                var line = Path()
                line.move(to: CGPoint(x: 0, y: h * 0.5))
                for step in 1...48 {
                    let x = Double(step) / 48
                    line.addLine(to: CGPoint(x: w * x,
                                             y: h * (0.5 + 0.05 * sin(x * 4.2 + t * 0.3))))
                }
                ctx.stroke(line, with: .linearGradient(
                    Gradient(stops: [.init(color: .clear, location: 0),
                                     .init(color: .white.opacity(0.10), location: 0.3),
                                     .init(color: .white.opacity(0.10), location: 0.7),
                                     .init(color: .clear, location: 1)]),
                    startPoint: .zero, endPoint: CGPoint(x: w, y: 0)), lineWidth: 1)

                // La traînée : les positions récentes de l'orbe, qui
                // s'éteignent et rétrécissent — la mémoire du mouvement.
                for k in stride(from: 26, through: 1, by: -1) {
                    let age = Double(k) / 26
                    let p = orb(t - Double(k) * 0.055)
                    let radius = CGFloat(3 + 16 * (1 - age))
                    let alpha = 0.30 * pow(1 - age, 1.8)
                    let rect = CGRect(x: p.x - radius, y: p.y - radius,
                                      width: radius * 2, height: radius * 2)
                    ctx.fill(Path(ellipseIn: rect), with: .radialGradient(
                        Gradient(colors: [.white.opacity(alpha), .clear]),
                        center: p, startRadius: 0, endRadius: radius))
                }

                // L'orbe : un cœur quasi blanc pur, deux halos concentriques,
                // et une pulsation d'effort (~4 s) qui gonfle le tout.
                let head = orb(t)
                let pulse = 1.0 + 0.10 * sin(t * 1.5)
                let halos: [(r: Double, alpha: Double)] = [
                    (30 * pulse, 0.16), (16 * pulse, 0.38), (7 * pulse, 0.95)
                ]
                for halo in halos {
                    let radius = CGFloat(halo.r)
                    let rect = CGRect(x: head.x - radius, y: head.y - radius,
                                      width: radius * 2, height: radius * 2)
                    ctx.fill(Path(ellipseIn: rect), with: .radialGradient(
                        Gradient(colors: [.white.opacity(halo.alpha), .clear]),
                        center: head, startRadius: 0, endRadius: radius))
                }

                // Les poussières : elles montent lentement, scintillent à
                // peine, et naissent/meurent en fondu aux bords.
                for i in 0..<Self.dustCount {
                    let speed = 0.028 + 0.05 * Self.hash(i, 1)
                    let phase = Self.hash(i, 2)
                    let yFrac = 1.0 - (t * speed + phase)
                        .truncatingRemainder(dividingBy: 1)
                    let x = w * Self.hash(i, 3)
                        + 7 * sin(t * (0.5 + Self.hash(i, 4)) + Double(i))
                    let fade = pow(sin(.pi * yFrac), 1.4)
                    let twinkle = 0.55 + 0.45 * sin(t * (1.1 + Self.hash(i, 5)) + Double(i) * 2.4)
                    let radius = 0.7 + 1.0 * Self.hash(i, 6)
                    let rect = CGRect(x: x - radius, y: h * yFrac - radius,
                                      width: radius * 2, height: radius * 2)
                    ctx.fill(Path(ellipseIn: rect),
                             with: .color(.white.opacity(0.55 * fade * twinkle)))
                }
            }
            .blendMode(.plusLighter)
        }
        // Les bouts s'évanouissent dans le verre : pas d'arête, que de la lumière.
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .white, location: 0.16),
                    .init(color: .white, location: 0.84),
                    .init(color: .clear, location: 1.0)
                ],
                startPoint: .leading, endPoint: .trailing
            )
        )
    }
}

// MARK: - Feuille de la séance en cours

struct ActiveWorkoutSheet: View {
    let workout: Workout
    /// « Ajouter un exercice » : fourni par la racine, ferme la feuille et
    /// ouvre la bibliothèque.
    var onAddExercise: (() -> Void)? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var confirmFinish = false
    @State private var recap: Workout?

    var body: some View {
        NavigationStack {
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
                                    WorkoutActivityController.sync(workout)
                                }
                            }
                        }

                        Button {
                            onAddExercise?()
                        } label: {
                            Label("Ajouter un exercice", systemImage: "plus")
                        }
                        .buttonStyle(WoopSecondaryButtonStyle())

                        Button("Annuler cette séance", role: .destructive) {
                            context.delete(workout)
                            try? context.save()
                            WorkoutActivityController.end()
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
            .navigationTitle("")
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
        // Tout liquid glass, comme le mini overlay : la feuille est du verre
        // fumé, la home transparaît derrière — aucun fond galactique propre.
        .presentationBackground {
            Color.clear
                .glassEffect(.regular.tint(Color.black.opacity(0.32)), in: .rect)
        }
        .preferredColorScheme(.dark)
    }

    /// Le même contenu que le mini overlay : l'orbe d'énergie, la pastille,
    /// « Séance en cours » et le bouton de fin — la continuité du morphisme se
    /// joue là, et c'est LE seul endroit d'où on termine : plus de gros bouton
    /// en bas de la feuille, qui doublait le geste.
    /// Pas de fond propre : la feuille entière est déjà le même verre que la
    /// carte, le header pose directement dessus.
    private var header: some View {
        VStack(spacing: 13) {
            BreathingGlow(paused: reduceMotion)
                .frame(height: 60)

            HStack(spacing: 12) {
                PulsingDot()

                VStack(alignment: .leading, spacing: 2) {
                    Text("Séance en cours")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color.inkPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.inkMuted)
                }

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 6)

            FinishWorkoutButton(enabled: !workout.orderedExercises.isEmpty) {
                confirmFinish = true
            }
            .padding(.horizontal, 6)
        }
        .padding(.init(top: 6, leading: 2, bottom: 10, trailing: 2))
    }

    private var subtitle: String {
        let count = workout.exerciseCount
        let exos = count == 0 ? "aucun exercice" : "\(count) exercice\(count > 1 ? "s" : "")"
        return "\(exos) · \(Int(workout.duration / 60)) min"
    }

    private func finish() {
        workout.endedAt = .now
        try? context.save()
        WorkoutActivityController.end()
        // Un entraînement de plus dans la semaine : la home doit le fêter.
        WoopCelebration.shared.workoutFinished()
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
                    // Pastille : la photo recadrée au centre, là où tombe le
                    // muscle en lumière. Un exercice retiré du catalogue n'a
                    // plus d'image — la ligne garde son nom et se passe d'elle.
                    if let exo = logged.exercise {
                        ExercisePhoto(exercise: exo)
                            .frame(width: 46, height: 46)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(WoopGradient.diamondRim, lineWidth: 0.75)
                            }
                    }

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
                        if let workout = logged.workout {
                            WorkoutActivityController.sync(workout)
                        }
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
                // L'orbe de la Live Activity se déplace à chaque série cochée.
                if let workout = set.loggedExercise?.workout {
                    WorkoutActivityController.sync(workout)
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
                    // Pastille : la photo recadrée au centre, là où tombe le
                    // muscle en lumière. Un exercice retiré du catalogue n'a
                    // plus d'image — la ligne garde son nom et se passe d'elle.
                    if let exo = logged.exercise {
                        ExercisePhoto(exercise: exo)
                            .frame(width: 46, height: 46)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(WoopGradient.diamondRim, lineWidth: 0.75)
                            }
                    }

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
