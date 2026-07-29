import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Live Activity « séance en cours »

/// L'île et l'écran verrouillé pendant une séance. Une Live Activity est un
/// instantané : pas d'animation continue — le mouvement vient de deux sources
/// seulement : le chrono système (`Text(_, style: .timer)`, gratuit) et les
/// transitions animées entre deux mises à jour d'état (l'orbe se déplace à
/// chaque série cochée / exercice ajouté). Tout le dessin est donc statique
/// et déterministe, dérivé de l'état.
struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            // Écran verrouillé : la bannière noire velours, l'orbe en tête —
            // le mini overlay de l'app, décliné sans verre (pas de backdrop à
            // réfracter ici).
            WorkoutBanner(context: context)
                .activityBackgroundTint(Color(red: 0.016, green: 0.016, blue: 0.024))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        ImpGlyph(size: 22, gaze: Self.gaze(context.state))
                        Text("Séance")
                            .font(.system(.footnote, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    WorkoutTimer(startedAt: context.attributes.startedAt)
                        .font(.system(.footnote, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        ProgressComet(startedAt: context.attributes.startedAt)
                            .frame(height: 30)
                        Text(Self.summary(context.state))
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                ImpGlyph(size: 17, gaze: Self.gaze(context.state))
            } compactTrailing: {
                WorkoutTimer(startedAt: context.attributes.startedAt)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: 52)
            } minimal: {
                ImpGlyph(size: 17, gaze: Self.gaze(context.state))
            }
            .keylineTint(.white)
        }
    }

    /// Le regard du diablotin se déplace à chaque mise à jour d'état.
    static func gaze(_ state: WorkoutActivityAttributes.ContentState) -> CGSize {
        let seed = Double(state.exerciseCount * 13 + state.setCount * 7 + state.volume + 1)
        func h(_ k: Double) -> Double {
            let v = sin(seed * 127.1 + k * 311.7) * 43758.5453
            return (v - v.rounded(.down)) * 2 - 1
        }
        return CGSize(width: h(1), height: h(2) * 0.6)
    }

    static func summary(_ state: WorkoutActivityAttributes.ContentState) -> String {
        guard state.exerciseCount > 0 else { return "aucun exercice" }
        var parts = ["\(state.exerciseCount) exo\(state.exerciseCount > 1 ? "s" : "")"]
        if state.setCount > 0 { parts.append("\(state.setCount) série\(state.setCount > 1 ? "s" : "")") }
        if state.volume > 0 { parts.append("\(state.volume) kg") }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Bannière d'écran verrouillé

private struct WorkoutBanner: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        VStack(spacing: 10) {
            ProgressComet(startedAt: context.attributes.startedAt)
                .frame(height: 34)

            HStack(spacing: 11) {
                ImpGlyph(size: 26, gaze: WorkoutLiveActivity.gaze(context.state))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Séance en cours")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(WorkoutLiveActivity.summary(context.state))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                }

                Spacer(minLength: 8)

                WorkoutTimer(startedAt: context.attributes.startedAt)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
        }
        .padding(.init(top: 14, leading: 16, bottom: 14, trailing: 16))
    }
}

// MARK: - Chrono

/// Le seul élément « vivant » sans mise à jour : le système fait tourner le
/// chrono tout seul.
private struct WorkoutTimer: View {
    let startedAt: Date

    var body: some View {
        Text(startedAt, style: .timer)
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
    }
}
