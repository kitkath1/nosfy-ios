import SwiftUI

// MARK: - Brouillon

struct DraftSet: Identifiable {
    let id = UUID()
    var reps: Int = 12
    var weight: Double = 20
}

struct DraftPhase: Identifiable {
    let id = UUID()
    var kind: PhaseKind = .recuperation
    var seconds: Int = 45
    var speed: Double = 7
}

struct LoggedDraft {
    var sets: [DraftSet] = []
    var restSeconds: Int = 0
    /// Une entrée par cycle ; chaque cycle contient ses phases.
    var cycles: [[DraftPhase]] = []
    var incline: Double = 0
}

// MARK: - Feuille de saisie

struct LogExerciseSheet: View {
    let exercise: Exercise
    /// Ce qui a été fait la dernière fois sur cet exercice, s'il y a un historique.
    var lastTime: String?
    let onSave: (LoggedDraft) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var sets: [DraftSet] = [DraftSet()]
    @State private var restSeconds = 60
    @State private var phases: [DraftPhase] = [
        DraftPhase(kind: .repos, seconds: 30, speed: 6),
        DraftPhase(kind: .acceleration, seconds: 30, speed: 16)
    ]
    @State private var repeatCount = 1
    @State private var steadySeconds = 900
    @State private var steadySpeed: Double = 7
    @State private var incline: Double = 0

    var body: some View {
        NavigationStack {
            ZStack {
                WoopBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let lastTime {
                            LastTimeBanner(text: lastTime)
                        }
                        switch exercise.tracking {
                        case .setsRepsWeight: strengthEditor
                        case .intervals:      intervalEditor
                        case .steady:         steadyEditor
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                        .foregroundStyle(Color.inkSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") { save() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationBackground(Color.woopSheet)
        .preferredColorScheme(.dark)
    }

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
        onSave(draft)
        dismiss()
    }

    // MARK: Musculation

    private var strengthEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            summaryStrip(left: "\(sets.count) série\(sets.count > 1 ? "s" : "")",
                         right: "\(Int(totalVolume)) kg de volume")

            ForEach($sets) { $set in
                let index = sets.firstIndex(where: { $0.id == set.id }) ?? 0
                WoopCard(cornerRadius: 18, padding: 16) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Série \(index + 1)")
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundStyle(Color.inkPrimary)
                            Spacer()
                            if sets.count > 1 {
                                Button {
                                    withAnimation { sets.removeAll { $0.id == set.id } }
                                } label: {
                                    Image(systemName: "minus.circle")
                                        .foregroundStyle(Color.inkMuted)
                                }
                            }
                        }
                        NumberStepper(label: "Répétitions", value: $set.reps,
                                      range: 1...60, step: 1, unit: "reps")
                        DecimalStepper(label: "Charge", value: $set.weight,
                                       range: 0...300, step: 2.5, unit: "kg")
                    }
                }
            }

            Button {
                withAnimation {
                    sets.append(DraftSet(reps: sets.last?.reps ?? 12,
                                         weight: sets.last?.weight ?? 20))
                }
            } label: {
                Label("Ajouter une série", systemImage: "plus")
            }
            .buttonStyle(WoopSecondaryButtonStyle())

            WoopCard(cornerRadius: 18, padding: 16) {
                NumberStepper(label: "Récupération", value: $restSeconds,
                              range: 0...300, step: 15, unit: "s")
            }
        }
    }

    private var totalVolume: Double {
        sets.reduce(0) { $0 + $1.weight * Double($1.reps) }
    }

    // MARK: HIIT — un cycle composé de phases, répété

    private var intervalEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            summaryStrip(
                left: "\(max(repeatCount, 1)) cycle\(repeatCount > 1 ? "s" : "")",
                right: durationLabel(cycleSeconds * max(repeatCount, 1))
            )

            WoopCard(cornerRadius: 18, padding: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Aperçu du cycle")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color.inkPrimary)
                    PhaseTimeline(phases: phases)
                    NumberStepper(label: "Répéter le cycle", value: $repeatCount,
                                  range: 1...30, step: 1, unit: "fois")
                }
            }

            ForEach($phases) { $phase in
                let index = phases.firstIndex(where: { $0.id == phase.id }) ?? 0
                PhaseCard(phase: $phase, index: index, canDelete: phases.count > 1) {
                    withAnimation { phases.removeAll { $0.id == phase.id } }
                }
            }

            // Ajout rapide : construire un cycle sans saisir quarante nombres.
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8),
                                GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(PhaseKind.allCases) { kind in
                    Button {
                        withAnimation {
                            phases.append(DraftPhase(kind: kind,
                                                     seconds: kind.defaultSeconds,
                                                     speed: kind.defaultSpeed))
                        }
                    } label: {
                        Text(kind.rawValue)
                    }
                    .buttonStyle(PhaseAddStyle(intensity: kind.intensity))
                }
            }
        }
    }

    private var cycleSeconds: Int { phases.reduce(0) { $0 + $1.seconds } }

    // MARK: Effort continu

    private var steadyEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            summaryStrip(
                left: durationLabel(steadySeconds),
                right: isStairs
                    ? "niveau \(steadySpeed.formatted(.number.precision(.fractionLength(0...1))))"
                    : "\(steadySpeed.formatted(.number.precision(.fractionLength(0...1)))) km/h"
            )

            WoopCard(cornerRadius: 18, padding: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    NumberStepper(label: "Durée", value: $steadySeconds,
                                  range: 60...7200, step: 60, unit: "s")
                    DecimalStepper(label: isStairs ? "Niveau" : "Vitesse",
                                   value: $steadySpeed, range: 0...25, step: 0.5,
                                   unit: isStairs ? "" : "km/h")
                    if !isStairs {
                        DecimalStepper(label: "Inclinaison", value: $incline,
                                       range: 0...20, step: 0.5, unit: "%")
                    }
                }
            }
        }
    }

    private var isStairs: Bool { exercise.id == "escalier" }

    // MARK: Habillage

    private func durationLabel(_ seconds: Int) -> String {
        let m = seconds / 60, s = seconds % 60
        return s == 0 ? "\(m) min" : "\(m) min \(s) s"
    }

    private func summaryStrip(left: String, right: String) -> some View {
        HStack {
            Text(left)
            Spacer()
            Text(right)
        }
        .font(.system(.footnote, design: .rounded, weight: .medium))
        .foregroundStyle(Color.inkSecondary)
        .padding(.horizontal, 16).padding(.vertical, 12)
        .metalSurface(cornerRadius: 16)
    }
}

// MARK: - Rappel de la dernière séance

/// Bien plus utile qu'une suggestion vague : ce qui a réellement été fait la fois d'avant.
struct LastTimeBanner: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.caption)
                .foregroundStyle(Color.inkMuted)
            Text("Dernière séance : \(text)")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(Color.inkSecondary)
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }
}

// MARK: - Timeline des phases

/// Les phases se distinguent par la hauteur et la luminosité, jamais par la
/// couleur : multiplier les teintes casserait la sobriété de l'interface.
struct PhaseTimeline: View {
    let phases: [DraftPhase]

    private var total: Int { max(phases.reduce(0) { $0 + $1.seconds }, 1) }

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(phases) { phase in
                    let width = geo.size.width * CGFloat(phase.seconds) / CGFloat(total)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.20 + 0.62 * phase.kind.intensity),
                                    Color.white.opacity(0.06 + 0.22 * phase.kind.intensity)
                                ],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .frame(width: max(width - 2, 3),
                               height: 16 + 40 * phase.kind.intensity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .frame(height: 58)
    }
}

// MARK: - Carte d'une phase

struct PhaseCard: View {
    @Binding var phase: DraftPhase
    let index: Int
    let canDelete: Bool
    let onDelete: () -> Void

    var body: some View {
        WoopCard(cornerRadius: 18, padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Text("Phase \(index + 1)")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color.inkPrimary)
                    IntensityBadge(kind: phase.kind)
                    Spacer()
                    if canDelete {
                        Button(action: onDelete) {
                            Image(systemName: "minus.circle")
                                .foregroundStyle(Color.inkMuted)
                        }
                    }
                }

                Picker("Type", selection: $phase.kind) {
                    ForEach(PhaseKind.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                NumberStepper(label: "Durée", value: $phase.seconds,
                              range: 5...900, step: 5, unit: "s")
                DecimalStepper(label: "Vitesse", value: $phase.speed,
                               range: 0...25, step: 0.5, unit: "km/h")
            }
        }
    }
}

struct IntensityBadge: View {
    let kind: PhaseKind

    var body: some View {
        Text(kind.rawValue.uppercased())
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .tracking(0.7)
            .foregroundStyle(Color.white.opacity(0.35 + 0.55 * kind.intensity))
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Capsule().fill(Color.white.opacity(0.04 + 0.09 * kind.intensity)))
    }
}

struct PhaseAddStyle: ButtonStyle {
    let intensity: Double

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.footnote, design: .rounded, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.45 + 0.5 * intensity))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color.white.opacity(0.035 + 0.055 * intensity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08 + 0.14 * intensity), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.65 : 1)
    }
}

// MARK: - Contrôles

struct NumberStepper: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let unit: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color.inkSecondary)
            Spacer()
            StepperControl(
                text: display,
                onMinus: { value = max(range.lowerBound, value - step) },
                onPlus: { value = min(range.upperBound, value + step) }
            )
        }
    }

    private var display: String {
        guard unit == "s" else { return "\(value) \(unit)" }
        if value < 60 { return "\(value) s" }
        let m = value / 60, s = value % 60
        return s == 0 ? "\(m) min" : "\(m):\(String(format: "%02d", s))"
    }
}

struct DecimalStepper: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color.inkSecondary)
            Spacer()
            StepperControl(
                text: "\(value.formatted(.number.precision(.fractionLength(0...1)))) \(unit)",
                onMinus: { value = max(range.lowerBound, value - step) },
                onPlus: { value = min(range.upperBound, value + step) }
            )
        }
    }
}

struct StepperControl: View {
    let text: String
    let onMinus: () -> Void
    let onPlus: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onMinus) {
                Image(systemName: "minus")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 38, height: 34)
            }
            Text(text)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.inkPrimary)
                .frame(minWidth: 74)
                .contentTransition(.numericText())
            Button(action: onPlus) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 38, height: 34)
            }
        }
        .foregroundStyle(Color.woopViolet)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(WoopGradient.bevel, lineWidth: 1)
        )
        .buttonStyle(.plain)
    }
}
