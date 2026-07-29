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
                        ImpGlyph(size: 22)
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
                        StaticOrb(state: context.state)
                            .frame(height: 42)
                        Text(Self.summary(context.state))
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                ImpGlyph(size: 17)
            } compactTrailing: {
                WorkoutTimer(startedAt: context.attributes.startedAt)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: 52)
            } minimal: {
                ImpGlyph(size: 17)
            }
            .keylineTint(.white)
        }
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
            StaticOrb(state: context.state)
                .frame(height: 46)

            HStack(spacing: 11) {
                ImpGlyph(size: 26)

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

// MARK: - L'orbe, version instantané

/// Le même langage que l'overlay de l'app — cœur blanc, traînée de comète,
/// filament, poussières — mais figé. La position de l'orbe est dérivée de
/// l'état : à chaque série cochée ou exercice ajouté, il se déplace (et le
/// système anime la transition). Aucun blur : que des dégradés radiaux, sûrs
/// dans le rendu widget.
private struct StaticOrb: View {
    let state: WorkoutActivityAttributes.ContentState

    /// Pseudo-aléatoire déterministe dérivé de l'état.
    private func hash(_ seed: Double) -> Double {
        let v = sin(Double(state.exerciseCount * 13 + state.setCount * 7 + 1) * 127.1
                    + seed * 311.7) * 43758.5453
        return v - v.rounded(.down)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let x = w * (0.24 + 0.52 * hash(1))
            let y = h * (0.38 + 0.24 * hash(2))
            // La traînée fuit du côté opposé à la course.
            let dir: CGFloat = hash(3) < 0.5 ? 1 : -1
            let trailLength = w * 0.34

            ZStack {
                // Le filament, à peine là.
                Rectangle()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .white.opacity(0.12), location: 0.3),
                                .init(color: .white.opacity(0.12), location: 0.7),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                    .position(x: w / 2, y: y)

                // La traînée : une capsule dégradée qui meurt loin de l'orbe.
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: dir > 0 ? [.clear, .white.opacity(0.30)]
                                            : [.white.opacity(0.30), .clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: trailLength, height: 13)
                    .position(x: x - dir * trailLength / 2, y: y)

                // Les halos concentriques, puis le cœur.
                Circle()
                    .fill(RadialGradient(colors: [.white.opacity(0.18), .clear],
                                         center: .center, startRadius: 0, endRadius: 26))
                    .frame(width: 52, height: 52)
                    .position(x: x, y: y)
                Circle()
                    .fill(RadialGradient(colors: [.white.opacity(0.55), .clear],
                                         center: .center, startRadius: 0, endRadius: 13))
                    .frame(width: 26, height: 26)
                    .position(x: x, y: y)
                Circle()
                    .fill(.white)
                    .frame(width: 5, height: 5)
                    .position(x: x, y: y)

                // Les poussières.
                ForEach(0..<6, id: \.self) { i in
                    let seed = Double(i) * 4.7
                    Circle()
                        .fill(.white.opacity(0.20 + 0.30 * hash(seed + 5)))
                        .frame(width: 1.5 + 1.5 * hash(seed + 6),
                               height: 1.5 + 1.5 * hash(seed + 6))
                        .position(x: w * hash(seed + 7),
                                  y: h * (0.15 + 0.7 * hash(seed + 8)))
                }
            }
        }
    }
}

// MARK: - Le diablotin

/// La silhouette du splash — goutte pleine, deux cornes-griffes asymétriques —
/// en glyphe statique. Les points de contrôle sont ceux de BottleSplash.
private struct ImpGlyph: View {
    var size: CGFloat

    var body: some View {
        ImpShape()
            .fill(
                LinearGradient(colors: [.white, .white.opacity(0.72)],
                               startPoint: .top, endPoint: .bottom)
            )
            .frame(width: size, height: size)
    }
}

private struct ImpShape: Shape {
    /// (contrôle, arrivée) — Béziers quadratiques, repère unité.
    private static let segments: [(CGPoint, CGPoint)] = [
        (CGPoint(x: 0.318, y: 0.968), CGPoint(x: 0.208, y: 0.890)),
        (CGPoint(x: 0.106, y: 0.780), CGPoint(x: 0.118, y: 0.582)),
        (CGPoint(x: 0.132, y: 0.442), CGPoint(x: 0.240, y: 0.322)),
        (CGPoint(x: 0.196, y: 0.246), CGPoint(x: 0.226, y: 0.150)),
        (CGPoint(x: 0.243, y: 0.108), CGPoint(x: 0.260, y: 0.130)),
        (CGPoint(x: 0.296, y: 0.205), CGPoint(x: 0.354, y: 0.262)),
        (CGPoint(x: 0.500, y: 0.212), CGPoint(x: 0.646, y: 0.256)),
        (CGPoint(x: 0.692, y: 0.162), CGPoint(x: 0.728, y: 0.094)),
        (CGPoint(x: 0.744, y: 0.048), CGPoint(x: 0.764, y: 0.078)),
        (CGPoint(x: 0.798, y: 0.180), CGPoint(x: 0.774, y: 0.316)),
        (CGPoint(x: 0.862, y: 0.424), CGPoint(x: 0.878, y: 0.582)),
        (CGPoint(x: 0.892, y: 0.780), CGPoint(x: 0.796, y: 0.890)),
        (CGPoint(x: 0.690, y: 0.968), CGPoint(x: 0.500, y: 0.975))
    ]

    func path(in rect: CGRect) -> Path {
        func scaled(_ p: CGPoint) -> CGPoint {
            CGPoint(x: rect.minX + p.x * rect.width, y: rect.minY + p.y * rect.height)
        }
        var path = Path()
        path.move(to: scaled(CGPoint(x: 0.500, y: 0.975)))
        for (control, end) in Self.segments {
            path.addQuadCurve(to: scaled(end), control: scaled(control))
        }
        path.closeSubpath()
        return path
    }
}
