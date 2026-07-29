import SwiftUI

/// La silhouette du splash — goutte pleine, deux cornes-griffes asymétriques —
/// en glyphe statique, avec deux petits yeux sombres. Le regard (`gaze`) se
/// décale d'un état à l'autre : sur l'écran verrouillé, les yeux bougent à
/// chaque série cochée, avec la transition animée du système.
struct ImpGlyph: View {
    var size: CGFloat
    /// Direction du regard, composantes dans [-1, 1].
    var gaze: CGSize = .zero

    var body: some View {
        ZStack {
            ImpShape()
                .fill(
                    LinearGradient(colors: [.white, .white.opacity(0.72)],
                                   startPoint: .top, endPoint: .bottom)
                )

            // Les yeux : deux trous d'ombre dans la goutte de lumière.
            ForEach([-1.0, 1.0], id: \.self) { side in
                Circle()
                    .fill(Color.black.opacity(0.82))
                    .frame(width: size * 0.115, height: size * 0.115)
                    .offset(x: size * (0.115 * side + 0.045 * gaze.width),
                            y: size * (-0.075 + 0.035 * gaze.height))
            }
        }
        .frame(width: size, height: size)
    }
}

struct ImpShape: Shape {
    /// (contrôle, arrivée) — Béziers quadratiques, repère unité. Les points
    /// sont ceux du diablotin de BottleSplash.
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
