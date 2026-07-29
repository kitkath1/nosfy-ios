import SwiftUI

// MARK: - Brouillon

struct DraftSet: Identifiable {
    let id = UUID()
    var reps: Int = 12
    var weight: Double = 20
    /// Renseignés quand la série a été lancée au compteur. `isDone` pilote à la
    /// fois l'aspect de la card et le libellé du bouton principal.
    var isDone: Bool = false
    var durationSeconds: Int = 0
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

    /// La série en cours d'exécution au compteur, s'il y en a une.
    @State private var running: RunningSeries?

    /// L'indice de la série lancée. Un `item:` plutôt qu'un booléen : c'est
    /// l'indice qui porte l'information, et il ne peut pas se désynchroniser.
    private struct RunningSeries: Identifiable {
        let id: Int
    }

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
                    .padding(.bottom, 24)
                }
            }
            // Le geste principal est ancré en bas d'écran, pas perdu dans un
            // coin de barre de navigation : c'est LE bouton de cette feuille.
            .safeAreaInset(edge: .bottom) { primaryAction }
            .navigationTitle(exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                        .foregroundStyle(Color.inkSecondary)
                }
            }
        }
        .presentationBackground(Color.woopSheet)
        .preferredColorScheme(.dark)
        // L'appareil confirme la série en même temps que les paillettes partent.
        .sensoryFeedback(.success, trigger: sets.filter(\.isDone).count)
        .fullScreenCover(item: $running) { series in
            LiveExerciseView(exercise: exercise,
                             seriesNumber: series.id + 1,
                             target: target(for: series.id)) { seconds in
                complete(series.id, seconds: seconds)
            } onCancel: {
                running = nil
            }
        }
    }

    // MARK: Le geste principal

    /// Le bas de l'écran dit toujours l'étape suivante. Tant qu'une série
    /// attend, un seul geste : la lancer. Une fois tout fait, les deux suites
    /// possibles se présentent côte à côte — en refaire une, ou enregistrer.
    /// Le lien sous la card ne suffisait pas : personne ne le voyait.
    private var primaryAction: some View {
        VStack(spacing: 10) {
            if canAddSeries {
                Button {
                    withAnimation(.easeOut(duration: 0.25)) { addSeries() }
                } label: {
                    Label("Ajouter une série", systemImage: "plus")
                }
                .buttonStyle(WoopSecondaryButtonStyle())
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Button(primaryTitle) {
                if let index = pendingSeries {
                    running = RunningSeries(id: index)
                } else {
                    save()
                }
            }
            .buttonStyle(WoopPrimaryButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background {
            // Le contenu défile DERRIÈRE le bouton : sans ce fondu, une card
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

    private var primaryTitle: String {
        pendingSeries == nil ? "Enregistrer l'exercice" : "Lancer la série"
    }

    /// La première série pas encore faite. Nul pour le cardio, qui n'a pas de
    /// séries à lancer : sa feuille ne fait qu'enregistrer.
    private var pendingSeries: Int? {
        guard exercise.tracking == .setsRepsWeight else { return nil }
        return sets.firstIndex { !$0.isDone }
    }

    /// On ne propose d'en ajouter une qu'une fois les précédentes faites :
    /// sinon le bas de l'écran offrirait deux gestes concurrents.
    private var canAddSeries: Bool {
        exercise.tracking == .setsRepsWeight && pendingSeries == nil
    }

    private func addSeries() {
        sets.append(DraftSet(reps: sets.last?.reps ?? 12,
                             weight: sets.last?.weight ?? 20))
    }

    private func target(for index: Int) -> String {
        guard sets.indices.contains(index) else { return "" }
        let set = sets[index]
        return "\(set.reps) reps · \(set.weight.formatted(.number.precision(.fractionLength(0...1)))) kg"
    }

    private func complete(_ index: Int, seconds: Int) {
        running = nil
        // Le plein écran met un peu moins d'une demi-seconde à se refermer.
        // Valider tout de suite ferait jouer les paillettes derrière lui, donc
        // pour personne — on attend que la card soit à l'air libre.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            guard sets.indices.contains(index) else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) {
                sets[index].isDone = true
                sets[index].durationSeconds = seconds
            }
        }
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
                // Pas de biseau néon sur une série faite : dans cette app le
                // violet dit « actif », c'est l'or qui dit « accompli ». La
                // pastille suffit, et elle parle le même langage que les séries
                // cochées de la séance en cours.
                WoopCard(cornerRadius: 18, padding: 16) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 8) {
                            Text("Série \(index + 1)")
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundStyle(Color.inkPrimary)
                            if set.isDone {
                                DoneBadge(seconds: set.durationSeconds)
                            }
                            Spacer(minLength: 0)
                            if sets.count > 1 {
                                Button {
                                    withAnimation { sets.removeAll { $0.id == set.id } }
                                } label: {
                                    Image(systemName: "minus.circle")
                                        .foregroundStyle(Color.inkMuted)
                                }
                            }
                        }
                        // Les steppers restent actifs après coup : le réalisé
                        // diffère souvent du prévu, et c'est le réalisé qui compte.
                        NumberStepper(label: "Répétitions", value: $set.reps,
                                      range: 1...60, step: 1, unit: "reps")
                        DecimalStepper(label: "Charge", value: $set.weight,
                                       range: 0...300, step: 2.5, unit: "kg")
                    }
                }
                // Les paillettes débordent volontairement de la card : une
                // gerbe rognée par son propre cadre n'est plus une gerbe.
                .overlay { SparkleBurst(trigger: set.isDone ? 1 : 0) }
            }

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

// MARK: - Série accomplie

/// La marque d'une série faite, et le temps que le compteur a mesuré. C'est la
/// seule information de cette feuille qui n'ait pas été saisie à la main — d'où
/// l'or, réservé dans toute l'app à ce qui a été gagné.
struct DoneBadge: View {
    let seconds: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .bold))
            Text(WoopDuration.label(seconds))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(Color.woopGold)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Capsule().fill(Color.woopGold.opacity(0.14)))
        .overlay(Capsule().strokeBorder(Color.woopGold.opacity(0.32), lineWidth: 1))
        .transition(.scale(scale: 0.7).combined(with: .opacity))
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
