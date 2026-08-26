import SwiftUI

// MARK: - Brouillon

struct DraftSet: Identifiable {
    let id = UUID()
    var reps: Int = 12
    var weight: Double = 20
    /// Renseignés quand la série a été lancée au compteur. `isDone` pilote à la
    /// fois l'aspect du bloc et le libellé du bouton principal.
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

// MARK: - Le filet d'un bloc

/// Ce qui sépare deux sections d'un MÊME bloc. Un `Divider` natif porte ses
/// propres marges et sa propre couleur : sur du noir pur il dessine une barre
/// grise, et le bloc se met à ressembler à un tableau. Ici c'est un cheveu de
/// lumière, à peine posé — la séparation se devine, elle ne se lit pas.
struct EditorHairline: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(height: 0.5)
    }
}

/// Le titre d'un bloc de réglage : même encre, même graisse que le grand titre
/// de la fiche, une taille en dessous. Toute la page parle d'une seule voix.
struct EditorBlockTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.inter(15, .semibold))
            .foregroundStyle(WoopGradient.silverText)
    }
}

/// Le pied d'un bloc : ce que les réglages du dessus totalisent. Il ferme le
/// bloc au lieu de flotter au-dessus dans son propre cadre — le nombre de séries
/// et le volume ne sont pas une autre information, c'est LA conséquence de
/// celles-ci. La récupération est du même monde : elle reste dans le bloc.
struct EditorSummary: View {
    let left: String
    let right: String

    var body: some View {
        HStack {
            Text(left)
            Spacer(minLength: 8)
            Text(right)
        }
        .font(.inter(13, .medium))
        .foregroundStyle(Color.inkSecondary)
    }
}

// MARK: - Musculation

/// Les séries, la récupération et le total dans UN SEUL bloc serti. Trois cadres
/// empilés disaient trois choses ; il n'y en a qu'une — le réglage de cet
/// exercice — et elle se lit de haut en bas : ce qu'on soulève, ce qu'on
/// récupère, ce que ça fait.
struct StrengthBlock: View {
    @Binding var sets: [DraftSet]
    @Binding var restSeconds: Int

    var body: some View {
        WoopCard(cornerRadius: 20, padding: 18) {
            VStack(alignment: .leading, spacing: 16) {
                ForEach($sets) { $set in
                    seriesSection(set: $set,
                                  index: sets.firstIndex { $0.id == set.id } ?? 0)
                    EditorHairline()
                }

                // Les steppers restent actifs après coup : le réalisé diffère
                // souvent du prévu, et c'est le réalisé qui compte.
                NumberStepper(label: "Récupération", value: $restSeconds,
                              range: 0...300, step: 15, unit: "s")

                EditorHairline()

                EditorSummary(left: "\(sets.count) série\(sets.count > 1 ? "s" : "")",
                              right: "\(Int(totalVolume)) kg de volume")
            }
        }
    }

    private var totalVolume: Double {
        sets.reduce(0) { $0 + $1.weight * Double($1.reps) }
    }

    @ViewBuilder
    private func seriesSection(set: Binding<DraftSet>, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 8) {
                EditorBlockTitle(text: "Série \(index + 1)")
                if set.wrappedValue.isDone {
                    DoneBadge(seconds: set.wrappedValue.durationSeconds)
                }
                Spacer(minLength: 0)
                if sets.count > 1 {
                    Button {
                        let id = set.wrappedValue.id
                        withAnimation { sets.removeAll { $0.id == id } }
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.inkMuted)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            NumberStepper(label: "Répétitions", value: set.reps,
                          range: 1...60, step: 1, unit: "reps")
            DecimalStepper(label: "Charge", value: set.weight,
                           range: 0...300, step: 2.5, unit: "kg")
        }
        // Les paillettes débordent volontairement de la section : une gerbe
        // rognée par son propre cadre n'est plus une gerbe.
        .overlay { SparkleBurst(trigger: set.wrappedValue.isDone ? 1 : 0) }
    }
}

// MARK: - HIIT — un cycle composé de phases, répété

struct IntervalBlock: View {
    @Binding var phases: [DraftPhase]
    @Binding var repeatCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            WoopCard(cornerRadius: 20, padding: 18) {
                VStack(alignment: .leading, spacing: 16) {
                    EditorBlockTitle(text: "Aperçu du cycle")
                    PhaseTimeline(phases: phases)
                    NumberStepper(label: "Répéter le cycle", value: $repeatCount,
                                  range: 1...30, step: 1, unit: "fois")
                    EditorHairline()
                    EditorSummary(
                        left: "\(max(repeatCount, 1)) cycle\(repeatCount > 1 ? "s" : "")",
                        right: WoopDuration.label(cycleSeconds * max(repeatCount, 1))
                    )
                }
            }

            ForEach($phases) { $phase in
                PhaseCard(phase: $phase,
                          index: phases.firstIndex { $0.id == phase.id } ?? 0,
                          canDelete: phases.count > 1) {
                    let id = phase.id
                    withAnimation { phases.removeAll { $0.id == id } }
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
}

// MARK: - Effort continu

struct SteadyBlock: View {
    @Binding var seconds: Int
    @Binding var speed: Double
    @Binding var incline: Double
    let isStairs: Bool
    /// L'escalier compte en niveaux de machine, la piscine n'a pas de
    /// pente : seul le tapis a une inclinaison à saisir.
    var hasIncline: Bool = true

    var body: some View {
        WoopCard(cornerRadius: 20, padding: 18) {
            VStack(alignment: .leading, spacing: 16) {
                NumberStepper(label: "Durée", value: $seconds,
                              range: 60...7200, step: 60, unit: "s")
                DecimalStepper(label: isStairs ? "Niveau" : "Vitesse",
                               value: $speed, range: 0...25, step: 0.5,
                               unit: isStairs ? "" : "km/h")
                if !isStairs, hasIncline {
                    DecimalStepper(label: "Inclinaison", value: $incline,
                                   range: 0...20, step: 0.5, unit: "%")
                }

                EditorHairline()

                EditorSummary(
                    left: WoopDuration.label(seconds),
                    right: isStairs
                        ? "niveau \(speed.formatted(.number.precision(.fractionLength(0...1))))"
                        : "\(speed.formatted(.number.precision(.fractionLength(0...1)))) km/h"
                )
            }
        }
    }
}

// MARK: - Série accomplie

/// La marque d'une série faite, et le temps que le compteur a mesuré. C'est la
/// seule information de cette page qui n'ait pas été saisie à la main — d'où
/// l'or, réservé dans toute l'app à ce qui a été gagné.
struct DoneBadge: View {
    let seconds: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .bold))
            Text(WoopDuration.label(seconds))
                .font(.inter(11, .semibold))
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
                .font(.inter(13))
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
        WoopCard(cornerRadius: 20, padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    EditorBlockTitle(text: "Phase \(index + 1)")
                    IntensityBadge(kind: phase.kind)
                    Spacer()
                    if canDelete {
                        Button(action: onDelete) {
                            Image(systemName: "minus.circle")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.inkMuted)
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
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
            .font(.inter(9, .bold))
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
            .font(.inter(13, .semibold))
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

    /// Les crans de la roue sont EXACTEMENT ceux que les signes parcourent :
    /// aucune valeur ne doit être atteignable d'un côté et pas de l'autre.
    private var choices: [Int] {
        Array(stride(from: range.lowerBound, through: range.upperBound, by: step))
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.inter(15))
                .foregroundStyle(Color.inkSecondary)
            Spacer(minLength: 8)
            StepperControl(
                text: display(value),
                onMinus: { value = max(range.lowerBound, value - step) },
                onPlus: { value = min(range.upperBound, value + step) }
            ) {
                Picker(label, selection: $value) {
                    ForEach(choices, id: \.self) { Text(display($0)).tag($0) }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
            }
        }
    }

    private func display(_ v: Int) -> String {
        guard unit == "s" else { return "\(v) \(unit)" }
        if v < 60 { return "\(v) s" }
        let m = v / 60, s = v % 60
        return s == 0 ? "\(m) min" : "\(m):\(String(format: "%02d", s))"
    }
}

struct DecimalStepper: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String

    private var choices: [Double] {
        Array(stride(from: range.lowerBound, through: range.upperBound, by: step))
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.inter(15))
                .foregroundStyle(Color.inkSecondary)
            Spacer(minLength: 8)
            StepperControl(
                text: display(value),
                onMinus: { value = max(range.lowerBound, value - step) },
                onPlus: { value = min(range.upperBound, value + step) }
            ) {
                Picker(label, selection: $value) {
                    ForEach(choices, id: \.self) { Text(display($0)).tag($0) }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
            }
        }
    }

    private func display(_ v: Double) -> String {
        let number = v.formatted(.number.precision(.fractionLength(0...1)))
        return unit.isEmpty ? number : "\(number) \(unit)"
    }
}

/// La facette de réglage de la famille diamant : deux signes qui incrémentent,
/// et une valeur qui s'ouvre sur une roue de verre.
///
/// Deux détails la font enfin marcher, là où l'ancienne version ratait la
/// majorité des touchers. Le `contentShape` : sous `.buttonStyle(.plain)`, la
/// zone tactile n'est pas le cadre de mise en page mais la boîte du GLYPHE —
/// 13 pt dans un cadre de 40, soit les deux tiers de la surface morts, très
/// loin des 44 pt du minimum Apple. Et le `buttonRepeatBehavior` : aller de 20
/// à 100 kg demandait trente-deux appuis.
///
/// La roue ne remplace pas les signes, elle les double. Le geste courant est
/// l'ajustement d'un cran — un menu pour ça serait une punition ; le geste rare
/// est le grand saut, et c'est lui qui avait besoin d'un raccourci.
struct StepperControl<Wheel: View>: View {
    let text: String
    let onMinus: () -> Void
    let onPlus: () -> Void
    @ViewBuilder var wheel: Wheel

    @State private var picking = false

    private let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)

    var body: some View {
        HStack(spacing: 0) {
            facet("minus", action: onMinus)

            Button { picking = true } label: {
                HStack(spacing: 5) {
                    Text(text)
                        .font(.inter(15, .semibold))
                        .foregroundStyle(WoopGradient.silverText)
                        .contentTransition(.numericText())
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.32))
                }
                .frame(minWidth: 92, minHeight: 34)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            facet("plus", action: onPlus)
        }
        .background(shape.fill(Color.white.opacity(0.05)))
        .overlay {
            shape.strokeBorder(WoopGradient.diamondRim, lineWidth: 1)
                // Le liseré est posé PAR-DESSUS les facettes : sans ça, il capte
                // les touchers qui atterrissent sur le contour.
                .allowsHitTesting(false)
        }
        .popover(isPresented: $picking) {
            wheel
                .frame(width: 210, height: 178)
                .presentationCompactAdaptation(.popover)
                // Verre liquide natif : la roue flotte au-dessus de la page
                // noire au lieu d'y poser une plaque opaque.
                .presentationBackground {
                    Color.clear
                        .glassEffect(.regular.tint(Color.black.opacity(0.45)), in: .rect)
                }
        }
    }

    private func facet(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(WoopGradient.controlInk)
                .frame(width: 40, height: 34)
                // LE correctif : la zone tactile devient le cadre entier.
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .buttonRepeatBehavior(.enabled)
    }
}
