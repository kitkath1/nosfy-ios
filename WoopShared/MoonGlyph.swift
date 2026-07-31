import SwiftUI

// MARK: - Le croissant du logo

/// Le croissant de lune du logo — le path unique de « lune (2).svg »
/// (AppIcon.icon), bbox réelle 735 × 702.191 dans le viewBox 749 × 718,
/// normalisé sur son côté long : le croissant occupe [0,1] × [0, 0.955362].
///
/// Tableau généré par script depuis le SVG (translation (−7, −2) puis
/// division par 735, 6 décimales) — à ne jamais retoucher à la main : la
/// bbox est celle de la COURBE (racines de la dérivée), pas des ancres, et
/// certains points de contrôle sortent légitimement de [0,1]. La fermeture
/// est exacte : l'arrivée du segment 18 est le point de départ.
enum MoonGlyph {
    /// Hauteur du croissant dans l'espace unité (702.191 / 735).
    static let unitHeight: CGFloat = 0.955362

    static let startPoint = CGPoint(x: 0.387985, y: 0.724702)

    /// Les 18 cubiques : (contrôle 1, contrôle 2, arrivée).
    static let segments: [(c1: CGPoint, c2: CGPoint, end: CGPoint)] = [
        (CGPoint(x: 0.417615, y: 0.739573), CGPoint(x: 0.455310, y: 0.743660), CGPoint(x: 0.499997, y: 0.744052)),
        (CGPoint(x: 0.594529, y: 0.744052), CGPoint(x: 0.623007, y: 0.689453), CGPoint(x: 0.671093, y: 0.728079)),
        (CGPoint(x: 0.719178, y: 0.766686), CGPoint(x: 0.800312, y: 0.822124), CGPoint(x: 0.879531, y: 0.814940)),
        (CGPoint(x: 0.908261, y: 0.812327), CGPoint(x: 0.867167, y: 0.761890), CGPoint(x: 0.873339, y: 0.729162)),
        (CGPoint(x: 0.875429, y: 0.715185), CGPoint(x: 0.883633, y: 0.702777), CGPoint(x: 0.896073, y: 0.692384)),
        (CGPoint(x: 0.911816, y: 0.679229), CGPoint(x: 0.971875, y: 0.630899), CGPoint(x: 1.000000, y: 0.591622)),
        (CGPoint(x: 0.986601, y: 0.641909), CGPoint(x: 0.963633, y: 0.689341), CGPoint(x: 0.934629, y: 0.733080)),
        (CGPoint(x: 0.903925, y: 0.780922), CGPoint(x: 0.986192, y: 0.845653), CGPoint(x: 0.944706, y: 0.875676)),
        (CGPoint(x: 0.900312, y: 0.901781), CGPoint(x: 0.832733, y: 0.848434), CGPoint(x: 0.773963, y: 0.882226)),
        (CGPoint(x: 0.687596, y: 0.923053), CGPoint(x: 0.623650, y: 0.951267), CGPoint(x: 0.559569, y: 0.955241)),
        (CGPoint(x: 0.495486, y: 0.959215), CGPoint(x: 0.512888, y: 0.863921), CGPoint(x: 0.467439, y: 0.898758)),
        (CGPoint(x: 0.422127, y: 0.934473), CGPoint(x: 0.385935, y: 0.969796), CGPoint(x: 0.322419, y: 0.948766)),
        (CGPoint(x: 0.165933, y: 0.894019), CGPoint(x: 0.052125, y: 0.759856), CGPoint(x: 0.002144, y: 0.605728)),
        (CGPoint(x: -0.012094, y: 0.558893), CGPoint(x: 0.049176, y: 0.552212), CGPoint(x: 0.050972, y: 0.492558)),
        (CGPoint(x: 0.052691, y: 0.432829), CGPoint(x: -0.007641, y: 0.351714), CGPoint(x: 0.024078, y: 0.275509)),
        (CGPoint(x: 0.087262, y: 0.140358), CGPoint(x: 0.214567, y: 0.037226), CGPoint(x: 0.369567, y: 0.000000)),
        (CGPoint(x: 0.206599, y: 0.108730), CGPoint(x: 0.131950, y: 0.289653), CGPoint(x: 0.191501, y: 0.484852)),
        (CGPoint(x: 0.230524, y: 0.593954), CGPoint(x: 0.291697, y: 0.679434), CGPoint(x: 0.387985, y: 0.724702)),
    ]

    /// Polyligne fermée du contour : `subdivisions` pas uniformes en t par
    /// cubique, en incluant t = 0 (le point de départ du segment) et jamais
    /// t = 1 — le dernier point du dernier segment rejoint le premier de la
    /// liste, sans doublon de fermeture. Consommée par MoonSDF.
    static func flattened(subdivisions: Int) -> [SIMD2<Float>] {
        assert(segments.last!.end == startPoint, "le path du croissant doit être fermé")
        var pts: [SIMD2<Float>] = []
        pts.reserveCapacity(segments.count * subdivisions)
        var p0 = startPoint
        for seg in segments {
            for s in 0..<subdivisions {
                let u = CGFloat(s) / CGFloat(subdivisions)
                let v = 1 - u
                let x = v * v * v * p0.x + 3 * v * v * u * seg.c1.x
                      + 3 * v * u * u * seg.c2.x + u * u * u * seg.end.x
                let y = v * v * v * p0.y + 3 * v * v * u * seg.c1.y
                      + 3 * v * u * u * seg.c2.y + u * u * u * seg.end.y
                pts.append(SIMD2<Float>(Float(x), Float(y)))
            }
            p0 = seg.end
        }
        return pts
    }
}

/// Le croissant en `Shape` — aspect-fit centré dans le rect (contrairement à
/// `ImpShape`, qui s'étire : la lune ne se déforme jamais).
struct MoonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height / MoonGlyph.unitHeight)
        let ox = rect.midX - scale / 2
        let oy = rect.midY - scale * MoonGlyph.unitHeight / 2
        func scaled(_ p: CGPoint) -> CGPoint {
            CGPoint(x: ox + p.x * scale, y: oy + p.y * scale)
        }
        var path = Path()
        path.move(to: scaled(MoonGlyph.startPoint))
        for seg in MoonGlyph.segments {
            path.addCurve(to: scaled(seg.end),
                          control1: scaled(seg.c1), control2: scaled(seg.c2))
        }
        path.closeSubpath()
        return path
    }
}
