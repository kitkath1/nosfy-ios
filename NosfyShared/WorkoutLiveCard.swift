import SwiftUI

/// Le même contenu lisible dans la bannière système et l'île déployée.
struct WorkoutLiveCard: View {
    let state: WorkoutActivityAttributes.ContentState
    let startedAt: Date
    var stale = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                WorkoutLivePortrait(size: 64)
                WorkoutLiveDetails(state: state, stale: stale)
                    .frame(maxWidth: .infinity, alignment: .leading)
                WorkoutLiveClock(state: state, startedAt: startedAt)
                    .font(.system(size: 23, weight: .medium, design: .rounded))
                    .frame(width: 85, alignment: .trailing)
                    .layoutPriority(1)
            }
            WorkoutLiveProgress(focus: state.focus, english: state.language == "en")
            if state.focus != nil {
                HStack(spacing: 5) {
                    Text(state.language == "en" ? "Session" : "Séance")
                    Text(startedAt, style: .timer).monospacedDigit()
                        .frame(maxWidth: 75, alignment: .leading)
                    Spacer()
                    Text("Nosfy")
                }
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.48))
            }
        }
        .padding(16)
        .foregroundStyle(.white)
    }
}

/// Le portrait choisi pour les grandes présentations ; ressource locale fixe.
struct WorkoutLivePortrait: View {
    var size: CGFloat = 48

    var body: some View {
        Image("LiveNosfyPortrait")
            .resizable()
            .scaledToFill()
            .scaleEffect(1.1)
            .frame(width: size, height: size)
            .clipped()
            .blendMode(.screen)
            .accessibilityHidden(true)
    }
}

struct WorkoutLiveDetails: View {
    let state: WorkoutActivityAttributes.ContentState
    var stale = false
    private var english: Bool { state.language == "en" }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(state.focus?.name ?? (english ? "Workout in progress" : "Séance en cours"))
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .lineLimit(2)
                .contentTransition(.opacity)
            if let focus = state.focus {
                Text(focus.phaseLabel(english: english, stale: stale))
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(focus.calm ? .white.opacity(0.65) : WorkoutLiveMoon.amber)
                if let detail = focus.detail(english: english) {
                    Text(detail)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                        .contentTransition(.numericText())
                }
            } else {
                Text(summary)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    private var summary: String {
        guard state.exerciseCount > 0 else {
            return english ? "Choose your first exercise" : "Choisissez votre premier exercice"
        }
        var parts = ["\(state.exerciseCount) \(english ? "exercise" : "exercice")\(state.exerciseCount > 1 ? "s" : "")"]
        if state.setCount > 0 { parts.append("\(state.setCount) \(english ? "sets" : "séries")") }
        if state.volume > 0 { parts.append("\(state.volume) kg") }
        return parts.joined(separator: " · ")
    }
}

struct WorkoutLiveClock: View {
    let state: WorkoutActivityAttributes.ContentState
    let startedAt: Date

    var body: some View {
        Group {
            if let focus = state.focus, focus.sport != .swimming {
                let phase = focus.phase
                if let end = phase.endsAt, let start = phase.startedAt {
                    Text(timerInterval: start...max(start, end), countsDown: true)
                } else if let start = phase.startedAt {
                    Text(timerInterval: start.addingTimeInterval(-phase.elapsed)...Date.distantFuture,
                         countsDown: false)
                } else {
                    Text(Self.duration(phase.elapsed))
                }
            } else {
                Text(startedAt, style: .timer)
            }
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.65)
        .multilineTextAlignment(.trailing)
        .foregroundStyle(.white)
    }

    private static func duration(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
            : String(format: "%d:%02d", s / 60, s % 60)
    }
}

struct WorkoutLiveProgress: View {
    let focus: WorkoutLiveFocus?
    var english = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isLuminanceReduced) private var luminanceReduced

    var body: some View {
        if let focus {
            if focus.phase.kind == .rest, let start = focus.phase.startedAt,
               let end = focus.phase.endsAt, end > start {
                ProgressView(timerInterval: start...end, countsDown: true) {
                    EmptyView()
                } currentValueLabel: { EmptyView() }
                .tint(WorkoutLiveMoon.amber)
                .accessibilityLabel(english ? "Rest remaining" : "Repos restant")
            } else if !focus.stages.isEmpty {
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(focus.stages) { stage in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(stage.recovery ? Color.white.opacity(0.28) : WorkoutLiveMoon.amber)
                            .frame(width: 22)
                            .frame(height: 3 + 21 * min(max(stage.value, 0) / (focus.sport == .stairs ? 15 : 20), 1))
                            .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .bottom)))
                    }
                }
                .frame(height: 24, alignment: .bottom)
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(reduceMotion || luminanceReduced ? nil : .easeOut(duration: 0.4),
                           value: focus.stages)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(english ? "Recent pace changes" : "Dernières allures")
            }
        }
    }
}

/// Le path EXACT du logo. Un seul reflet au changement, aucun moteur continu.
struct WorkoutLiveMoon: View {
    let focus: WorkoutLiveFocus?
    var size: CGFloat = 26
    static let amber = Color(red: 1, green: 0.63, blue: 0.28)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isLuminanceReduced) private var luminanceReduced

    var body: some View {
        ZStack {
            MoonShape().fill(focus?.calm == true ? .white.opacity(0.75) : Self.amber)
            if !reduceMotion && !luminanceReduced {
                MoonShape().fill(.clear)
                    .modifier(MoonReflection(progress: 1))
                    .id("\(focus?.source.uuidString ?? "session")-\(focus?.revision ?? 0)")
                    .transition(.asymmetric(
                        insertion: .modifier(active: MoonReflection(progress: 0),
                                             identity: MoonReflection(progress: 1)),
                        removal: .identity))
            }
        }
        .frame(width: size, height: size)
        .animation(reduceMotion || luminanceReduced ? nil : .easeInOut(duration: 0.75),
                   value: focus?.revision)
        .accessibilityLabel("Nosfy")
    }
}

private struct MoonReflection: AnimatableModifier {
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    func body(content: Content) -> some View {
        content.overlay {
            GeometryReader { geo in
                LinearGradient(colors: [.clear, .white, .clear],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: geo.size.width * 0.45)
                    .offset(x: geo.size.width * (-0.5 + progress * 1.6))
            }
            .mask(MoonShape())
        }
    }
}
