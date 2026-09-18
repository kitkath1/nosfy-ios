import SwiftUI

// MARK: - Petites fonctions de temps

/// Ramène une valeur dans [0, 1].
func clamp01(_ x: CGFloat) -> CGFloat { min(max(x, 0), 1) }

/// Rampe douce sur [0, 1] : sert à enchaîner les temps d'une chorégraphie sans
/// que rien ne démarre ni ne s'arrête net.
func smoothstep(_ x: CGFloat) -> CGFloat {
    let t = clamp01(x)
    return t * t * (3 - 2 * t)
}

// MARK: - Bruit

/// Bruit lisse et déterministe dans [-1, 1]. Déterministe volontairement : un
/// trait qui tremblerait autrement à chaque image grésillerait. Ici c'est le
/// crayon qui a hésité une fois pour toutes, pas l'écran qui vibre.
struct InkNoise {
    var seed: UInt64 = 1

    private func sample(_ index: Int) -> CGFloat {
        var x = UInt64(bitPattern: Int64(index)) &+ seed &* 0x9E37_79B9_7F4A_7C15
        x ^= x >> 30; x = x &* 0xBF58_476D_1CE4_E5B9
        x ^= x >> 27; x = x &* 0x94D0_49BB_1331_11EB
        x ^= x >> 31
        return CGFloat(x % 20_001) / 10_000 - 1
    }

    /// Interpolation cosinus : les écarts sont longs, comme la dérive d'un
    /// poignet — pas du bruit blanc, qui donnerait un trait sale.
    func callAsFunction(_ t: CGFloat) -> CGFloat {
        let index = Int(floor(t))
        let fraction = t - CGFloat(index)
        let eased = (1 - cos(fraction * .pi)) / 2
        return sample(index) + (sample(index + 1) - sample(index)) * eased
    }
}

// MARK: - Géométrie d'un tracé

/// Un dessin se décrit comme une suite de droites et de quadratiques, en
/// coordonnées normalisées. C'est la forme la plus lisible pour poser un tracé
/// à la main dans du code : on lit la table, on voit la bouteille.
enum InkSegment {
    case line(CGFloat, CGFloat)
    /// Contrôle, puis arrivée.
    case curve(CGFloat, CGFloat, CGFloat, CGFloat)
}

/// Développe une suite de segments en polyligne dense.
func inkPolyline(from start: CGPoint, _ segments: [InkSegment], steps: Int = 14) -> [CGPoint] {
    var points = [start]
    var current = start

    for segment in segments {
        switch segment {
        case .line(let x, let y):
            let end = CGPoint(x: x, y: y)
            for step in 1...steps {
                let t = CGFloat(step) / CGFloat(steps)
                points.append(CGPoint(x: current.x + (end.x - current.x) * t,
                                      y: current.y + (end.y - current.y) * t))
            }
            current = end

        case .curve(let cx, let cy, let x, let y):
            let end = CGPoint(x: x, y: y)
            let control = CGPoint(x: cx, y: cy)
            for step in 1...steps {
                let t = CGFloat(step) / CGFloat(steps)
                let u = 1 - t
                points.append(CGPoint(
                    x: u * u * current.x + 2 * u * t * control.x + t * t * end.x,
                    y: u * u * current.y + 2 * u * t * control.y + t * t * end.y
                ))
            }
            current = end
        }
    }
    return points
}

/// Ré-échantillonne une polyligne à pas constant : la progression du tracé et
/// la pression du crayon se raisonnent en longueur parcourue, pas en nombre de
/// points — sinon le crayon ralentirait dans les courbes.
func inkResample(_ points: [CGPoint], count: Int) -> [CGPoint] {
    guard points.count > 1, count > 1 else { return points }

    var marks: [CGFloat] = [0]
    var total: CGFloat = 0
    for index in 1..<points.count {
        total += hypot(points[index].x - points[index - 1].x,
                       points[index].y - points[index - 1].y)
        marks.append(total)
    }
    guard total > 0 else { return points }

    var out: [CGPoint] = []
    out.reserveCapacity(count)
    var cursor = 1
    for index in 0..<count {
        let target = total * CGFloat(index) / CGFloat(count - 1)
        while cursor < points.count - 1 && marks[cursor] < target { cursor += 1 }
        let span = max(marks[cursor] - marks[cursor - 1], 0.0001)
        let t = clamp01((target - marks[cursor - 1]) / span)
        let a = points[cursor - 1], b = points[cursor]
        out.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
    }
    return out
}

/// Ruban d'encre : le contour d'un trait dont l'épaisseur varie point par point.
/// Les deux bords sont lissés par des quadratiques passant par les milieux — un
/// ruban facetté trahirait le dessin dès qu'on zoome dedans, et on zoome
/// beaucoup dans ce dessin.
func inkRibbon(_ points: [CGPoint], _ widths: [CGFloat]) -> Path {
    guard points.count >= 3, points.count == widths.count else { return Path() }

    var left: [CGPoint] = [], right: [CGPoint] = []
    left.reserveCapacity(points.count)
    right.reserveCapacity(points.count)

    for (index, point) in points.enumerated() {
        // Direction locale : moyenne des segments adjacents, pour éviter que la
        // normale ne bascule brutalement dans un angle.
        let previous = points[max(index - 1, 0)]
        let next = points[min(index + 1, points.count - 1)]
        var dx = next.x - previous.x, dy = next.y - previous.y
        let length = max(hypot(dx, dy), 0.0001)
        dx /= length; dy /= length

        let half = widths[index] / 2
        left.append(CGPoint(x: point.x - dy * half, y: point.y + dx * half))
        right.append(CGPoint(x: point.x + dy * half, y: point.y - dx * half))
    }

    func trace(_ side: [CGPoint], into path: inout Path) {
        for index in 1..<(side.count - 1) {
            let mid = CGPoint(x: (side[index].x + side[index + 1].x) / 2,
                              y: (side[index].y + side[index + 1].y) / 2)
            path.addQuadCurve(to: mid, control: side[index])
        }
        path.addLine(to: side[side.count - 1])
    }

    var path = Path()
    path.move(to: left[0])
    trace(left, into: &path)
    path.addLine(to: right[right.count - 1])
    trace(right.reversed(), into: &path)
    path.closeSubpath()
    return path
}

// MARK: - Trait

/// Un trait à main levée. La polyligne, elle, est parfaite : ce sont le
/// tremblement, la pression et la progression qui la rendent humaine.
struct InkStroke {
    /// Points en coordonnées normalisées (0…1 sur la boîte du dessin).
    var points: [CGPoint]
    /// Largeur nominale, en fraction du côté court de la boîte.
    var width: CGFloat = 0.019
    /// Amplitude du tremblement, même unité.
    var wobble: CGFloat = 0.0045
    /// Longueur d'onde du tremblement, en nombre d'échantillons.
    var wavelength: CGFloat = 16
    /// Part du trait sur laquelle le crayon appuie puis relâche.
    var taper: CGFloat = 0.09
    var seed: UInt64 = 1
    var samples: Int = 170

    /// Le repentir : un second passage, plus fin et plus tremblé, posé sur le
    /// premier. C'est ce doublement qui fait « dessiné » plutôt que « calculé ».
    var echo: InkStroke {
        var copy = self
        copy.seed = seed &* 31 &+ 7
        copy.width *= 0.5
        copy.wobble *= 2.4
        copy.wavelength *= 0.7
        return copy
    }
}

/// Le trait, tracé de `trimFrom` jusqu'à `progress`. Tant qu'il n'est pas
/// fini, il se termine en pointe : le crayon est encore posé quelque part.
/// Avec `trimFrom > 0`, seule une fenêtre du trait est visible — c'est ce qui
/// permet de faire courir un éclat de lumière le long d'un tracé.
struct InkStrokeShape: Shape {
    var stroke: InkStroke
    var progress: CGFloat = 1
    var trimFrom: CGFloat = 0

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        guard stroke.points.count >= 2, progress > trimFrom + 0.004 else { return Path() }

        let scale = min(rect.width, rect.height)
        let mapped = stroke.points.map {
            CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height)
        }
        let spine = inkResample(mapped, count: stroke.samples)
        let jitter = InkNoise(seed: stroke.seed)
        let pressure = InkNoise(seed: stroke.seed &* 7 &+ 13)

        // Tremblement : chaque point dérive le long de sa normale.
        var drawn: [CGPoint] = []
        drawn.reserveCapacity(spine.count)
        for (index, point) in spine.enumerated() {
            let previous = spine[max(index - 1, 0)]
            let next = spine[min(index + 1, spine.count - 1)]
            var dx = next.x - previous.x, dy = next.y - previous.y
            let length = max(hypot(dx, dy), 0.0001)
            dx /= length; dy /= length
            let drift = jitter(CGFloat(index) / stroke.wavelength) * stroke.wobble * scale
            drawn.append(CGPoint(x: point.x - dy * drift, y: point.y + dx * drift))
        }

        let count = drawn.count
        let last = max(2, Int((CGFloat(count - 1) * min(progress, 1)).rounded()))
        let first = min(max(0, Int((CGFloat(count - 1) * clamp01(trimFrom)).rounded())),
                        last - 2)
        let visible = Array(drawn[first...last])
        let finished = progress >= 1

        let widths: [CGFloat] = visible.indices.map { index in
            let t = CGFloat(first + index) / CGFloat(count - 1)
            // La main n'appuie pas régulièrement.
            let breathing = 0.72 + 0.4 * (pressure(t * 6) * 0.5 + 0.5)
            // Attaque et levée du crayon.
            let ends = min(smoothstep(t / stroke.taper), smoothstep((1 - t) / stroke.taper))
            // Pointes de la fenêtre visible : celle du crayon en cours, et
            // celle de l'arrière de la fenêtre quand le trait est fenêtré.
            let tip = finished ? 1 : smoothstep(CGFloat(visible.count - 1 - index) / 7)
            let head = first > 0 ? smoothstep(CGFloat(index) / 7) : 1
            return stroke.width * scale * breathing * ends * tip * head
        }

        return inkRibbon(visible, widths)
    }
}
