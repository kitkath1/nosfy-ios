import SwiftUI

// MARK: - Nuances de blanc

/// Toute la palette du splash : des blancs lunaires sur une partition de
/// noirs. C'est la retenue qui fait le luxe, pas la couleur.
private enum InkWhite {
    static let stroke = LinearGradient(
        stops: [
            .init(color: .lunar, location: 0.0),
            .init(color: Color.lunar.opacity(0.92), location: 0.34),
            .init(color: Color(red: 0.78, green: 0.81, blue: 0.90).opacity(0.88), location: 0.68),
            .init(color: Color.lunar.opacity(0.50), location: 1.0)
        ],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    /// Liseré du diablotin : une arête de lumière qui vient d'en haut — vive
    /// sur la crête et les cornes, éteinte le long des flancs.
    static let rim = LinearGradient(
        stops: [
            .init(color: Color.lunar.opacity(0.80), location: 0.0),
            .init(color: Color.lunar.opacity(0.16), location: 0.40),
            .init(color: Color.lunar.opacity(0.03), location: 1.0)
        ],
        startPoint: .top, endPoint: .bottom
    )

    /// Les yeux : blanc pur en haut, argent lunaire en bas — de la porcelaine.
    static let eye = LinearGradient(
        stops: [
            .init(color: .white, location: 0.0),
            .init(color: Color.lunar.opacity(0.97), location: 0.45),
            .init(color: Color(red: 0.76, green: 0.80, blue: 0.92), location: 1.0)
        ],
        startPoint: .top, endPoint: .bottom
    )

    /// L'encre du corps : noir bleuté en crête, cœur profond, assise à peine
    /// plus chaude. Trois noirs qui se répondent — c'est ça, les beaux noirs.
    static let body = LinearGradient(
        stops: [
            .init(color: Color(red: 0.040, green: 0.040, blue: 0.078), location: 0.0),
            .init(color: Color(red: 0.014, green: 0.014, blue: 0.030), location: 0.55),
            .init(color: Color(red: 0.011, green: 0.008, blue: 0.009), location: 1.0)
        ],
        startPoint: .top, endPoint: .bottom
    )
}

// MARK: - Le dessin

/// La bouteille de lait du croquis : bouchon débordant, lèvre, col court,
/// épaules rondes, flancs presque droits. Le corps se dessine d'abord — le
/// bouchon n'arrive qu'une fois le diablotin à l'intérieur, pour sceller la
/// bouteille derrière lui.
private enum Bottle {
    static let bodyLine = inkPolyline(from: CGPoint(x: 0.420, y: 0.160), [
        .line(0.420, 0.225),
        .curve(0.415, 0.290, 0.330, 0.315),
        .curve(0.155, 0.360, 0.140, 0.460),
        .line(0.135, 0.845),
        .curve(0.140, 0.945, 0.245, 0.952),
        .line(0.755, 0.952),
        .curve(0.860, 0.945, 0.865, 0.845),
        .line(0.860, 0.460),
        .curve(0.845, 0.360, 0.670, 0.315),
        .curve(0.585, 0.290, 0.580, 0.225),
        .line(0.580, 0.160)
    ])

    /// Le bouchon déborde du col : c'est ce porte-à-faux qui fait « bouteille
    /// de lait ».
    static let capLine = inkPolyline(from: CGPoint(x: 0.400, y: 0.148), [
        .line(0.400, 0.048),
        .curve(0.400, 0.028, 0.435, 0.026),
        .line(0.565, 0.026),
        .curve(0.600, 0.028, 0.600, 0.048),
        .line(0.600, 0.148)
    ])

    /// La lèvre : le petit trait horizontal sous le bouchon.
    static let collarLine = inkPolyline(from: CGPoint(x: 0.398, y: 0.152), [
        .line(0.602, 0.148)
    ])

    static let body = InkStroke(points: bodyLine, width: 0.015, seed: 3)
    static let cap = InkStroke(points: capLine, width: 0.014, seed: 11, samples: 90)
    static let collar = InkStroke(points: collarLine, width: 0.011,
                                  taper: 0.24, seed: 23, samples: 40)
    /// Le même contour, en plus large : le lit du balayage de lumière.
    static let sweep = InkStroke(points: bodyLine, width: 0.026, seed: 3)

    /// Le corps contracté de 10 % : le lit des bandes de reflet internes,
    /// celles qui suivent la courbe des épaules à l'intérieur du verre.
    static let innerLine: [CGPoint] = bodyLine.map { p in
        CGPoint(x: 0.5 + (p.x - 0.5) * 0.90, y: 0.56 + (p.y - 0.56) * 0.915)
    }
    static let innerBand = InkStroke(points: innerLine, width: 0.016,
                                     wobble: 0.002, seed: 31)
    /// Version large : les nappes de reflet d'épaule, en feuille de lumière.
    static let innerSheet = InkStroke(points: innerLine, width: 0.036,
                                      wobble: 0.002, seed: 33)
    /// Version propre, sans tremblement : les longues bandes verticales qui
    /// courent sur toute la hauteur du corps — la signature du verre poli.
    static let innerClean = InkStroke(points: innerLine, width: 0.020,
                                      wobble: 0.0004, seed: 37)

}

/// Le second contour du verre : le même corps, contracté vers le centre.
/// Tracé ouvert (pas de ligne à travers le col). C'est l'écart entre les deux
/// contours qui donne l'épaisseur de la paroi — le verre devient massif.
private struct InnerGlassShape: Shape {
    func path(in rect: CGRect) -> Path {
        let cx: CGFloat = 0.5, cy: CGFloat = 0.56
        var path = Path()
        let points = Bottle.bodyLine.map { p -> CGPoint in
            let x = cx + (p.x - cx) * 0.955
            let y = cy + (p.y - cy) * 0.968
            return CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        path.move(to: points[0])
        for point in points.dropFirst() { path.addLine(to: point) }
        return path
    }
}

/// L'arête de verre physique. La lumière ne court jamais uniformément le long
/// d'une arête réelle : elle s'accroche là où la surface tourne — épaules,
/// coins, col — et s'éteint le long des flancs droits. Chaque segment du
/// contour reçoit donc SA largeur et SON intensité, déduites de la courbure
/// locale, plus deux termes de lumière (le ciel en haut, le sol embrasé en
/// bas). Deux passes : le bloom d'abord, l'arête vive ensuite.
/// La géométrie éclairée d'un contour : épine rééchantillonnée, courbure
/// locale, et ENVELOPPE — une structure d'environnement bruitée le long du
/// tracé (plages irrégulières, pics, accidents). C'est elle qui distingue un
/// reflet réel d'une formule.
private struct GlassEdgeModel {
    let spine: [CGPoint]
    let feature: [CGFloat]
    let envelope: [CGFloat]

    private static func computeFeature(_ points: [CGPoint]) -> [CGFloat] {
        let n = points.count
        var curvature = [CGFloat](repeating: 0, count: n)
        for i in 1..<(n - 1) {
            let v1x = points[i].x - points[i - 1].x
            let v1y = points[i].y - points[i - 1].y
            let v2x = points[i + 1].x - points[i].x
            let v2y = points[i + 1].y - points[i].y
            curvature[i] = abs(atan2(v1x * v2y - v1y * v2x, v1x * v2x + v1y * v2y))
        }
        var smooth = curvature
        for i in 0..<n {
            var sum: CGFloat = 0, count: CGFloat = 0
            for j in max(0, i - 3)...min(n - 1, i + 3) { sum += curvature[j]; count += 1 }
            smooth[i] = sum / count
        }
        let peak = smooth.max() ?? 1
        return (0..<n).map { i in
            let yNorm = points[i].y * BottleStage.aspect
            let top = smoothstep((0.42 - yNorm) / 0.26) * 0.35
            return min(1, smooth[i] / peak * 1.15 + top)
        }
    }

    private static func computeEnvelope(_ n: Int, seed: UInt64) -> [CGFloat] {
        let env = InkNoise(seed: seed)
        return (0..<n).map { i in
            clamp01(0.55 + 0.45 * env(CGFloat(i) / 28) + 0.20 * env(CGFloat(i) / 9 + 40))
        }
    }

    init(line: [CGPoint], noiseSeed: UInt64) {
        let scaled = line.map { CGPoint(x: $0.x, y: $0.y / BottleStage.aspect) }
        let points = inkResample(scaled, count: 220)
        spine = points
        feature = Self.computeFeature(points)
        envelope = Self.computeEnvelope(points.count, seed: noiseSeed)
    }

    /// L'arête interne : un décalage le long de la NORMALE intérieure — une
    /// vraie épaisseur de paroi, pas une homothétie.
    init(offsetFrom base: GlassEdgeModel, distance: CGFloat, noiseSeed: UInt64) {
        let n = base.spine.count
        let centroid = CGPoint(x: 0.5, y: 0.56 / BottleStage.aspect)
        var points: [CGPoint] = []
        points.reserveCapacity(n)
        for i in 0..<n {
            let p = base.spine[i]
            let a = base.spine[max(0, i - 1)], b = base.spine[min(n - 1, i + 1)]
            var dx = b.x - a.x, dy = b.y - a.y
            let length = max(hypot(dx, dy), 0.0001)
            dx /= length; dy /= length
            var nx = -dy, ny = dx
            if nx * (centroid.x - p.x) + ny * (centroid.y - p.y) < 0 { nx = -nx; ny = -ny }
            points.append(CGPoint(x: p.x + nx * distance, y: p.y + ny * distance))
        }
        spine = points
        feature = base.feature
        envelope = Self.computeEnvelope(n, seed: noiseSeed)
    }

    static let outer = GlassEdgeModel(line: Bottle.bodyLine, noiseSeed: 97)
    static let inner = GlassEdgeModel(offsetFrom: outer, distance: 0.0132, noiseSeed: 98)

    /// Les éclats auto-placés : les maxima locaux de courbure × enveloppe —
    /// là où le verre accroche vraiment la lumière, pas où on l'a décidé.
    static let glints: [(x: CGFloat, y: CGFloat, size: CGFloat, freq: Double, phase: Double)] = {
        let m = outer
        let score = (0..<m.spine.count).map { m.feature[$0] * m.envelope[$0] }
        var picks: [Int] = []
        for i in 4..<(score.count - 4) where score[i] > 0.42 {
            if score[i] >= score[i - 1] && score[i] >= score[i + 1]
                && !picks.contains(where: { abs($0 - i) < 14 }) {
                picks.append(i)
            }
        }
        picks = Array(picks.sorted { score[$0] > score[$1] }.prefix(10))
        let rng = InkNoise(seed: 41)
        return picks.enumerated().map { (k, i) in
            (x: m.spine[i].x, y: m.spine[i].y * BottleStage.aspect,
             size: 1.5 + 2.5 * abs(rng(CGFloat(k) * 3.3)),
             freq: 0.6 + 0.8 * Double(abs(rng(CGFloat(k) * 5.7))),
             phase: Double(abs(rng(CGFloat(k) * 7.9))) * 6.28)
        }
    }()
}

/// Les arêtes de verre. Deux Canvas : les BLOOMS, masqués par l'intérieur de
/// la bouteille (bord dur dehors, fondu 6-10 px dedans — rien ne sort jamais),
/// et les CHEVEUX (0,45-0,9 px), posés sur la silhouette. L'arête interne n'a
/// aucun bloom : le noir de l'interstice est aussi important que les lignes.
private struct GlassEdges: View {
    var t: Double
    var glow: CGFloat
    var alpha: CGFloat

    private static let drift = InkNoise(seed: 55)

    private func map(_ p: CGPoint, _ size: CGSize) -> CGPoint {
        CGPoint(x: p.x * size.width, y: p.y * BottleStage.aspect * size.height)
    }

    /// L'intensité d'un segment : courbure + braise + biais de lumière +
    /// enveloppe d'environnement dérivante + extinction des flancs plats.
    private func intensity(_ m: GlassEdgeModel, _ i: Int, weight: CGFloat) -> CGFloat {
        let f = m.feature[i]
        let yNorm = m.spine[i].y * BottleStage.aspect
        let ember = smoothstep((yNorm - 0.80) / 0.14) * 0.55 * glow
        let shimmer = 1 - 0.10 * f * (1 - CGFloat(sin(t * 0.7 + Double(i) * 0.05)))
        let sideBias = 1.12 - 0.24 * m.spine[i].x
        let e = clamp01(m.envelope[i] + 0.10 * Self.drift(CGFloat(i) / 28 + CGFloat(t) * 0.04))
        let flank: CGFloat = (yNorm > 0.35 && yNorm < 0.75 && f < 0.15) ? 0.10 : 1
        var value = (0.14 + 0.95 * f + ember) * shimmer * sideBias * weight * (0.50 + e * 0.85) * flank
        if e > 0.88 { value = min(1, value * 1.4) }   // pic à blanc pur
        return value
    }

    var body: some View {
        ZStack {
            // Le fondu intérieur de paroi : coupe net au bord (masque),
            // s'évanouit sur ~7 px vers le dedans.
            BottleInteriorShape()
                .stroke(Color.white, lineWidth: 2.5)
                .blur(radius: 5)
                .opacity(Double((0.24 + 0.20 * glow) * alpha))
                .mask(BottleInteriorShape())

            // Blooms bucketés (12 paliers, ~12 strokes au lieu de 440),
            // masqués : l'asymétrie du bord réel.
            Canvas { context, size in
                guard alpha > 0.01 else { return }
                let m = GlassEdgeModel.outer
                var buckets = [Int: Path]()
                for i in 0..<(m.spine.count - 1) {
                    let bucket = min(11, Int(intensity(m, i, weight: 1) * 12))
                    guard bucket > 4 else { continue }
                    var segment = Path()
                    segment.move(to: map(m.spine[i], size))
                    segment.addLine(to: map(m.spine[i + 1], size))
                    buckets[bucket, default: Path()].addPath(segment)
                }
                for (bucket, path) in buckets {
                    let k = CGFloat(bucket) / 12
                    context.stroke(
                        path,
                        with: .color(.white.opacity(Double(k * 0.14 * alpha))),
                        style: StrokeStyle(lineWidth: 6 - 3.5 * k, lineCap: .round)
                    )
                }
            }
            .mask(BottleInteriorShape())

            // Les cheveux : l'externe, puis l'interne à 40 % — la ligne
            // jumelle, avec le noir garanti entre les deux.
            Canvas { context, size in
                guard alpha > 0.01 else { return }
                let layers: [(GlassEdgeModel, CGFloat)] = [(.outer, 1.0), (.inner, 0.4)]
                for (m, weight) in layers {
                    for i in 0..<(m.spine.count - 1) {
                        let value = intensity(m, i, weight: weight)
                        guard value > 0.02 else { continue }
                        var segment = Path()
                        segment.move(to: map(m.spine[i], size))
                        segment.addLine(to: map(m.spine[i + 1], size))
                        context.stroke(
                            segment,
                            with: .color(.white.opacity(Double(min(1, value * 1.2) * alpha))),
                            style: StrokeStyle(
                                lineWidth: (0.45 + 0.45 * m.feature[i]) * (weight == 1 ? 1 : 0.8),
                                lineCap: .round
                            )
                        )
                    }
                }
            }
        }
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }
}

/// L'intérieur du verre : le même contour, refermé en haut du col. Sert à la
/// fois de matière (le verre) et de masque (rien ne déborde de la bouteille).
private struct BottleInteriorShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let points = Bottle.bodyLine.map {
            CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height)
        }
        path.move(to: points[0])
        for point in points.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }
}

/// Le diablotin, silhouette fine : flancs en S, épaules resserrées, cornes
/// allongées en flammes — la droite un soupçon plus haute, l'asymétrie du
/// dessin à la main.
private enum Imp {
    static let outline = inkPolyline(from: CGPoint(x: 0.500, y: 0.972), [
        .curve(0.300, 0.965, 0.195, 0.885),
        .curve(0.085, 0.775, 0.110, 0.570),
        .curve(0.125, 0.430, 0.205, 0.330),
        .curve(0.140, 0.240, 0.180, 0.020),
        .curve(0.250, 0.150, 0.310, 0.240),
        .curve(0.500, 0.190, 0.690, 0.235),
        .curve(0.760, 0.130, 0.835, 0.000),
        .curve(0.865, 0.190, 0.805, 0.325),
        .curve(0.885, 0.430, 0.900, 0.570),
        .curve(0.925, 0.775, 0.815, 0.885),
        .curve(0.710, 0.965, 0.500, 0.972)
    ], steps: 16)
}

private struct ImpBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let points = Imp.outline.map {
            CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height)
        }
        path.move(to: points[0])
        for point in points.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }
}

/// Une veine d'encre : une volute à peine plus claire que le corps, qui
/// dérive lentement à l'intérieur de lui. L'encre tourne encore.
private struct InkVeinShape: Shape {
    var phase: CGFloat
    var seed: CGFloat

    func path(in rect: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        let sway = sin(phase + seed) * 0.05
        let lift = cos(phase * 0.7 + seed * 2) * 0.03

        var path = Path()
        path.move(to: p(0.24 + sway, 0.80))
        path.addCurve(to: p(0.55 + sway * 0.5, 0.52 + lift),
                      control1: p(0.26, 0.66),
                      control2: p(0.38 + sway, 0.55 + lift))
        path.addCurve(to: p(0.72 - sway, 0.68 - lift),
                      control1: p(0.70 + sway * 0.4, 0.50),
                      control2: p(0.78 - sway * 0.6, 0.58))
        return path
    }
}

// MARK: - La queue

/// L'épine de la queue, avec propagation : la base mène, la pointe suit en
/// retard et amplifie — c'est le fouet d'une vraie queue, pas un métronome.
/// `drag` la déplie vers le haut (elle traîne pendant la chute) ; au repos
/// elle s'enroule contre la paroi du verre, un peu collée — c'est voulu.
private func tailSpine(drag: CGFloat, t: Double, whip: CGFloat) -> [CGPoint] {
    func mix(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * drag, y: a.y + (b.y - a.y) * drag)
    }
    let anchor = CGPoint(x: 0.640, y: 0.880)
    // Repos : elle longe le fond, remonte le long du verre.
    let restA = CGPoint(x: 0.940, y: 1.010)
    let restB = CGPoint(x: 1.170, y: 0.930)
    let restTip = CGPoint(x: 1.235, y: 0.700)
    // Chute : elle flotte au-dessus de lui, tirée par l'air.
    let dragA = CGPoint(x: 0.870, y: 0.540)
    let dragB = CGPoint(x: 0.980, y: 0.150)
    let dragTip = CGPoint(x: 1.060, y: -0.140)

    let a = mix(restA, dragA)
    let b = mix(restB, dragB)
    let tip = mix(restTip, dragTip)

    var points = sampleQuadPoints(anchor, a, b, steps: 11)
    points.append(contentsOf: sampleQuadPoints(
        b,
        CGPoint(x: b.x + (tip.x - b.x) * 0.2, y: b.y + (tip.y - b.y) * 0.75),
        tip, steps: 11
    ).dropFirst())

    // Propagation : chaque point ondule en retard sur le précédent, et
    // d'autant plus fort qu'il est loin de la base.
    let amplitude = (0.030 + 0.10 * whip) * (1 - drag * 0.4)
        + drag * 0.018
    let period = drag > 0.5 ? 0.9 : 2.6
    for index in points.indices {
        let progress = CGFloat(index) / CGFloat(points.count - 1)
        let weight = pow(progress, 1.6)
        let wave = sin(2 * .pi * t / period - Double(progress) * 2.6)
        points[index].x += amplitude * weight * CGFloat(wave) * 0.75
        points[index].y -= amplitude * weight * CGFloat(wave) * 0.55
    }
    return points
}

private func sampleQuadPoints(_ a: CGPoint, _ control: CGPoint, _ b: CGPoint,
                              steps: Int) -> [CGPoint] {
    (0...steps).map { step in
        let t = CGFloat(step) / CGFloat(steps)
        let u = 1 - t
        return CGPoint(
            x: u * u * a.x + 2 * u * t * control.x + t * t * b.x,
            y: u * u * a.y + 2 * u * t * control.y + t * t * b.y
        )
    }
}

/// Le ruban de la queue, effilé de la base vers la pointe.
private struct TailShape: Shape {
    var drag: CGFloat
    var t: Double
    var whip: CGFloat

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height)
        let spine = tailSpine(drag: drag, t: t, whip: whip).map {
            CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height)
        }
        let widths = spine.indices.map { index -> CGFloat in
            let progress = CGFloat(index) / CGFloat(spine.count - 1)
            return (0.048 - 0.038 * progress) * scale
        }
        return inkRibbon(spine, widths)
    }
}

/// Le fer de lance au bout de la queue — le triangle qui dit « diable ».
private struct TailSpadeShape: Shape {
    var drag: CGFloat
    var t: Double
    var whip: CGFloat

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height)
        let spine = tailSpine(drag: drag, t: t, whip: whip).map {
            CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height)
        }
        guard spine.count >= 3 else { return Path() }
        let tip = spine[spine.count - 1]
        let previous = spine[spine.count - 3]
        var dx = tip.x - previous.x, dy = tip.y - previous.y
        let length = max(hypot(dx, dy), 0.0001)
        dx /= length; dy /= length

        let size = scale * 0.098
        let point = CGPoint(x: tip.x + dx * size, y: tip.y + dy * size)
        let barbLeft = CGPoint(x: tip.x - dy * size * 0.55 - dx * size * 0.18,
                               y: tip.y + dx * size * 0.55 - dy * size * 0.18)
        let barbRight = CGPoint(x: tip.x + dy * size * 0.55 - dx * size * 0.18,
                                y: tip.y - dx * size * 0.55 - dy * size * 0.18)
        let notch = CGPoint(x: tip.x - dx * size * 0.30, y: tip.y - dy * size * 0.30)

        var path = Path()
        path.move(to: point)
        path.addQuadCurve(to: barbLeft,
                          control: CGPoint(x: (point.x + barbLeft.x) / 2 - dy * size * 0.18,
                                           y: (point.y + barbLeft.y) / 2 + dx * size * 0.18))
        path.addLine(to: notch)
        path.addLine(to: barbRight)
        path.addQuadCurve(to: point,
                          control: CGPoint(x: (point.x + barbRight.x) / 2 + dy * size * 0.18,
                                           y: (point.y + barbRight.y) / 2 - dx * size * 0.18))
        path.closeSubpath()
        return path
    }
}

// MARK: - Le visage

/// L'œil fermé : un simple « ◡ », comme le croissant blanc du croquis.
private struct ClosedEyeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.3))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.3),
                          control: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

/// Le scintillement : une étoile à quatre branches qui apparaît sur le
/// catchlight de l'œil ouvert, l'espace d'un clin d'œil.
private struct SparkleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        let waist = r * 0.18
        var path = Path()
        path.move(to: CGPoint(x: c.x, y: c.y - r))
        path.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y),
                          control: CGPoint(x: c.x + waist, y: c.y - waist))
        path.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r),
                          control: CGPoint(x: c.x + waist, y: c.y + waist))
        path.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y),
                          control: CGPoint(x: c.x - waist, y: c.y + waist))
        path.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r),
                          control: CGPoint(x: c.x - waist, y: c.y - waist))
        path.closeSubpath()
        return path
    }
}

/// Deux globes de porcelaine, pas deux pastilles : dégradé lunaire, ombrage
/// sphérique, double catchlight — et un regard. Les yeux se déplacent avec
/// `gaze`, les catchlights restent presque en place : c'est ce contre-
/// mouvement qui crée la pupille qu'on ne dessine pas.
private struct ImpFace: View {
    var eyes: CGFloat
    var wink: CGFloat
    var blink: CGFloat
    var squint: CGFloat
    /// Direction du regard, en unités d'œil (-1…1).
    var gaze: CGPoint
    /// Étoile sur le catchlight pendant le clin d'œil.
    var sparkle: CGFloat
    var pop: CGFloat
    /// Inverse du zoom : les lueurs restent des effets d'écran.
    var screen: CGFloat

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let dx = gaze.x * w * 0.022
            let dy = gaze.y * h * 0.016

            ZStack {
                eye(w: w, h: h, closed: blink, squint: (1 - 0.24 * wink) * (1 - 0.3 * squint),
                    sparkle: sparkle)
                    .rotationEffect(.degrees(-5))
                    .position(x: 0.365 * w + dx, y: 0.485 * h + dy)

                eye(w: w, h: h, closed: max(wink, blink), squint: 1 - 0.3 * squint,
                    sparkle: 0)
                    .rotationEffect(.degrees(5))
                    .position(x: 0.635 * w + dx, y: 0.485 * h + dy)
            }
            .shadow(color: Color.lunar.opacity(0.45), radius: 5 * screen)
        }
    }

    private func eye(w: CGFloat, h: CGFloat, closed: CGFloat, squint: CGFloat,
                     sparkle: CGFloat) -> some View {
        let ew = w * 0.125 * pop
        let eh = h * 0.170 * max(eyes, 0) * pop * squint
        // L'œil ouvert s'éteint AVANT que le croissant n'apparaisse : jamais
        // les deux à la fois, sinon l'œil fait planète à anneau.
        let openAlpha = Double(pow(clamp01(1 - closed * 1.6), 2))
        let crescentAlpha = Double(smoothstep((closed - 0.45) / 0.3))
        return ZStack {
            ZStack {
                Ellipse().fill(InkWhite.eye)
                // Ombrage sphérique : le bas du globe s'éteint, à peine.
                Ellipse()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.68),
                                .init(color: .black.opacity(0.09), location: 1.0)
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                // Double catchlight, en léger contre-mouvement du regard.
                Ellipse()
                    .fill(Color.white)
                    .frame(width: ew * 0.20, height: eh * 0.17)
                    .offset(x: -ew * 0.17 - gaze.x * ew * 0.10,
                            y: -eh * 0.22 - gaze.y * eh * 0.08)
                    .opacity(0.9)
                Ellipse()
                    .fill(Color.white)
                    .frame(width: ew * 0.08, height: eh * 0.07)
                    .offset(x: ew * 0.14 - gaze.x * ew * 0.10,
                            y: eh * 0.12 - gaze.y * eh * 0.08)
                    .opacity(0.35)
            }
            .frame(width: ew, height: eh)
            .opacity(openAlpha)

            ClosedEyeShape()
                .stroke(InkWhite.eye,
                        style: StrokeStyle(lineWidth: h * 0.026, lineCap: .round))
                .frame(width: w * 0.155, height: h * 0.075)
                .opacity(crescentAlpha)

            if sparkle > 0.01 {
                SparkleShape()
                    .fill(Color.white)
                    .frame(width: ew * (0.5 + 0.4 * sparkle), height: ew * (0.5 + 0.4 * sparkle))
                    .offset(x: -ew * 0.17, y: -eh * 0.22)
                    .opacity(Double(sparkle))
                    .shadow(color: .white.opacity(0.8), radius: 3 * screen)
            }
        }
    }
}

// MARK: - Chorégraphie

/// Fenêtre temporelle lissée : monte à `a`, redescend à `b`.
private func span(_ t: Double, _ a: Double, _ riseLen: Double,
                  _ b: Double, _ fallLen: Double) -> CGFloat {
    smoothstep(CGFloat((t - a) / riseLen)) * (1 - smoothstep(CGFloat((t - b) / fallLen)))
}

private func ramp(_ t: Double, _ start: Double, _ len: Double) -> CGFloat {
    smoothstep(CGFloat((t - start) / len))
}

/// Une image de la séquence. Tout est fonction pure du temps : la chorégraphie
/// se lit comme une partition et se rejoue à l'identique image par image.
private struct SplashBeat {
    var zoom: CGFloat = 1
    var camX: CGFloat = 0.5
    var camY: CGFloat = 0.5
    var ink: CGFloat = 0
    /// Position de la pointe du crayon, en coordonnées de la boîte.
    var pen: CGPoint = .zero
    var penAlpha: CGFloat = 0
    /// Position du bas du diablotin, en hauteurs de bouteille.
    var impY: CGFloat = -0.62
    var appear: CGFloat = 0
    /// Compression horizontale ; la verticale s'en déduit, à volume constant.
    var squash: CGFloat = 1
    /// 1 = la queue flotte derrière lui (chute), 0 = enroulée contre le verre.
    var tailDrag: CGFloat = 0
    /// Amplitude supplémentaire du battement — le fouet de l'impact.
    var whip: CGFloat = 0
    var glow: CGFloat = 0
    /// Horloge d'après-impact : elle cadence l'onde et les yeux.
    var settle: CGFloat = 0
    /// Frisson : il se secoue une fois, juste après avoir atterri.
    var shiver: CGFloat = 0
    /// Enfoncement de la bouteille sous le poids du bouchon, en points.
    var sink: CGFloat = 0
    /// Position et présence du balayage de lumière sur le contour.
    var sweepPos: CGFloat = 0
    var sweepAlpha: CGFloat = 0
    var wink: CGFloat = 0
    /// La transmutation : 0 = trait d'encre à main levée, 1 = arête de verre
    /// physique. L'encre devient verre au moment de l'impact.
    var become: CGFloat = 0
    /// Présence de la nébuleuse derrière la bouteille.
    var nebula: CGFloat = 0
    /// Sortie Cheshire : la scène s'éteint, les yeux restent, puis clignent.
    var fade: CGFloat = 0
    var blink: CGFloat = 0
    var eyesAlpha: CGFloat = 1
    /// Impulsion radiale donnée à la poussière au moment de l'impact.
    var impulse: CGFloat = 0

    /// L'image finale, pour qui a désactivé les animations.
    static let resolved = SplashBeat(zoom: 1, camX: 0.5, camY: 0.5, ink: 1,
                                     impY: 0.945, appear: 1, squash: 1,
                                     glow: 0.72, settle: 1, become: 1, nebula: 1)

    static let penBody = inkResample(Bottle.bodyLine, count: 160)
    static let penCap = inkResample(Bottle.capLine, count: 60)

    static func point(on track: [CGPoint], at progress: CGFloat) -> CGPoint {
        track[Int(clamp01(progress) * CGFloat(track.count - 1))]
    }

    /// La partition.
    ///   0,0 – 1,5   macro sur la pointe : le corps s'écrit, la caméra recule
    ///   1,55 – 2,0  il apparaît, micro-temps d'arrêt — l'anticipation
    ///   2,0 – 2,5   plongeon, la queue traîne, goutte d'encre dans le col
    ///   2,52        impact — verre, nébuleuse et poussière répondent
    ///   2,7 – 3,5   yeux, frisson, le bouchon scelle, la bouteille s'enfonce
    ///   3,55        balayage de lumière sur le contour
    ///   3,75        poussée caméra — clin d'œil
    ///   4,6 – 5,5   sortie Cheshire : tout s'éteint sauf les yeux
    static func at(_ t: Double) -> SplashBeat {
        var beat = SplashBeat()

        // L'encre. Le corps d'abord ; bouchon et lèvre après la capture.
        let bodyP = ramp(t, -0.10, 1.50)
        let capP = ramp(t, 3.00, 0.35)
        let collarP = ramp(t, 3.40, 0.13)
        beat.ink = 0.84 * bodyP + 0.11 * capP + 0.05 * collarP

        beat.pen = t < 2.0 ? point(on: penBody, at: bodyP)
                           : point(on: penCap, at: capP)
        beat.penAlpha = min(1, span(t, -0.10, 0.05, 1.42, 0.12)
                             + span(t, 2.98, 0.08, 3.50, 0.10))

        // La caméra. Un seul mouvement continu : recul exponentiel depuis la
        // pointe du crayon, une poussée vers le visage pour le clin d'œil —
        // et une micro-dérive de main sur tout le plan : filmé, pas rendu.
        let push = span(t, 3.70, 0.22, 4.10, 0.35)
        let follow = ramp(t, 0.5, 1.0)
        let driftX = 0.0012 * (sin(t * 1.43) + 0.6 * sin(t * 2.17 + 1.3))
        let driftY = 0.0012 * (sin(t * 1.19 + 0.7) + 0.6 * sin(t * 1.87))
        beat.zoom = 1 + 23 * CGFloat(exp(-2.9 * t)) + 0.16 * push
        beat.camX = beat.pen.x + (0.5 - beat.pen.x) * follow + CGFloat(driftX)
        beat.camY = beat.pen.y + (0.5 - beat.pen.y) * follow + 0.16 * push + CGFloat(driftY)

        // L'entrée : il apparaît, respire un temps — puis plonge. C'est le
        // temps d'arrêt qui rend le plongeon délicieux.
        beat.appear = ramp(t, 1.55, 0.18)
        switch t {
        case ..<1.55:
            beat.impY = -0.62
        case ..<1.85:
            beat.impY = -0.62 + 0.20 * ramp(t, 1.55, 0.30)
        case ..<2.02:
            beat.impY = -0.42 - 0.045 * span(t, 1.85, 0.10, 1.97, 0.08)
        case ..<2.32:
            let u = (t - 2.02) / 0.30
            beat.impY = -0.44 + 0.74 * CGFloat(u * u)
        case ..<2.52:
            beat.impY = 0.30 + 0.63 * CGFloat((t - 2.32) / 0.20)
        default:
            let s = t - 2.52
            beat.impY = 0.945 - 0.015 * CGFloat(cos(13 * s) * exp(-4.5 * s))
        }

        beat.squash = 1
            + 0.06 * span(t, 1.85, 0.08, 1.95, 0.07)   // il se tasse avant de sauter
            - 0.07 * span(t, 1.97, 0.07, 2.10, 0.10)   // il s'étire en plongeant
            - 0.73 * span(t, 2.26, 0.10, 2.48, 0.10)   // il se faufile dans le col
            + 0.34 * span(t, 2.54, 0.06, 2.66, 0.22)   // il s'étale au fond
        if t > 2.70 {
            beat.squash += 0.05 * CGFloat(sin(15 * (t - 2.70)) * exp(-6 * (t - 2.70)))
        }

        // La queue traîne dès qu'il apparaît, se rétracte après l'impact ;
        // le fouet, juste au moment où il touche le fond.
        beat.tailDrag = span(t, 1.58, 0.25, 2.50, 0.35)
        beat.whip = span(t, 2.52, 0.06, 2.80, 0.30)

        // L'impact éclaire le verre : un éclat, puis une clarté qui s'installe.
        beat.glow = ramp(t, 2.52, 0.16)
            * (0.75 + 0.25 * CGFloat(exp(-max(0, t - 2.65) * 2.2)))
        beat.settle = clamp01(CGFloat((t - 2.52) / 1.2))
        beat.impulse = t > 2.52
            ? CGFloat(exp(-(t - 2.52) * 2.4) * (1 - exp(-(t - 2.52) * 9)))
            : 0

        beat.shiver = span(t, 2.98, 0.07, 3.10, 0.12)
        beat.sink = 2.4 * span(t, 3.30, 0.09, 3.46, 0.30)

        // L'éclat qui court le long du contour, une seule fois.
        beat.sweepPos = ramp(t, 3.52, 0.42) * 0.92
        beat.sweepAlpha = span(t, 3.52, 0.10, 3.86, 0.12)

        beat.wink = span(t, 3.75, 0.12, 4.00, 0.22)

        // La transmutation : à l'impact, le dessin prend vie — l'encre à main
        // levée se change en verre physique.
        beat.become = ramp(t, 2.52, 0.45)

        // La nébuleuse naît avec la bouteille, s'épanouit à l'impact.
        beat.nebula = clamp01((beat.ink - 0.5) / 0.4)
            * (0.30 + 0.70 * ramp(t, 2.52, 0.30))

        // La sortie Cheshire : la scène s'éteint, les yeux tiennent le plan,
        // clignent une fois, puis s'éteignent à leur tour.
        beat.fade = ramp(t, 4.60, 0.40)
        beat.blink = ramp(t, 5.05, 0.14)
        beat.eyesAlpha = 1 - ramp(t, 5.24, 0.24)
        return beat
    }
}

// MARK: - La scène

/// Bouteille, verre, diablotin, encre, nébuleuse. Ordre des plans volontaire :
/// le diablotin passe **derrière** l'encre, c'est ce qui le fait entrer dans
/// la bouteille au lieu de glisser devant.
/// Les caustiques du contact : 13 filaments courbes qui rayonnent du point
/// de contact, chacun sa longueur, sa fréquence et sa phase — et un grain de
/// lumière confiné au halo, qui scintille en pointes brèves. Aucun élément
/// n'est synchrone avec un autre : deux phases égales = mécanique = faux.
private struct CausticBurst: View {
    var t: Double
    var glow: CGFloat
    var side: CGFloat

    private static let noise = InkNoise(seed: 29)

    var body: some View {
        Canvas { context, size in
            let noise = Self.noise
            let origin = CGPoint(x: size.width / 2, y: size.height / 2)

            for i in 0..<13 {
                let hash = noise(CGFloat(i) * 3.7)
                let angle = Double.pi * (0.15 + 0.7 * (Double(hash) * 0.5 + 0.5))
                let length = 20 + 50 * abs(noise(CGFloat(i) * 5.1))
                let tip = CGPoint(x: origin.x - CGFloat(cos(angle)) * length,
                                  y: origin.y - CGFloat(sin(angle)) * length * 0.35)
                let control = CGPoint(x: (origin.x + tip.x) / 2 + 15 * noise(CGFloat(i) * 7.3),
                                      y: (origin.y + tip.y) / 2)
                var path = Path()
                path.move(to: origin)
                path.addQuadCurve(to: tip, control: control)
                let twinkle = 0.5 + 0.5 * sin(t * (0.3 + 0.6 * Double(abs(hash)))
                                              + Double(i) * 2.1)
                context.stroke(
                    path,
                    with: .color(.white.opacity((0.10 + 0.22 * twinkle) * Double(glow))),
                    style: StrokeStyle(lineWidth: 0.5 + 0.4 * abs(hash), lineCap: .round)
                )
            }

            for j in 0..<60 {
                let px = origin.x + side * 0.75 * noise(CGFloat(j) * 1.9)
                let py = origin.y - side * 0.22 * abs(noise(CGFloat(j) * 2.3)) + side * 0.04
                let pop = pow(max(0, sin(t * (2 + 4 * Double(abs(noise(CGFloat(j)))))
                                         + Double(j))), 4)
                context.fill(
                    Path(ellipseIn: CGRect(x: px, y: py, width: 1, height: 1)),
                    with: .color(.white.opacity((0.08 + 0.55 * pop) * Double(glow)))
                )
            }
        }
        .frame(width: side * 2.4, height: side * 1.2)
        .allowsHitTesting(false)
    }
}

private struct BottleStage: View {
    let beat: SplashBeat
    let t: Double

    /// Boîte du dessin : la bouteille est ~2,4 fois plus haute que large.
    static let aspect: CGFloat = 0.53

    /// Les 12 crans du halo angulaire — tirés du bruit une fois pour toutes,
    /// premier et dernier égaux pour que la boucle soit invisible.
    static let haloStops: [Gradient.Stop] = {
        let noise = InkNoise(seed: 63)
        var stops: [Gradient.Stop] = (0...12).map { i in
            .init(color: .white.opacity(0.5 + 0.5 * Double(abs(noise(CGFloat(i) * 2.3)))),
                  location: CGFloat(i) / 12)
        }
        stops[stops.count - 1] = .init(color: stops[0].color, location: 1)
        return stops
    }()

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            // Les lueurs et le flou sont des effets d'écran : divisés par le
            // zoom ici, ils gardent la même taille une fois la scène agrandie.
            let screen = 1 / max(beat.zoom, 1)
            let side = w * 0.46
            let squashY = pow(1 / max(beat.squash, 0.05), 0.55)
            let scene = 1 - beat.fade

            let reveal = clamp01((beat.ink - 0.5) / 0.4)
            let trail = clamp01((beat.impY + 0.5) / 0.45) * clamp01((0.92 - beat.impY) / 0.22)
            let ring = min(1, beat.settle / 0.45)
            let kick = beat.settle > 0 ? sin(ring * 2 * .pi) * exp(-ring * 3) : 0
            let breath = beat.settle >= 1 ? 0.008 * sin(2 * .pi * t / 3.4) : 0
            let bob = kick * h * 0.012 + beat.sink

            ZStack {
                NebulaBloom(t: t, alpha: beat.nebula * scene, pulse: beat.impulse)

                // La réfraction feinte : les anneaux redessinés dans le verre,
                // décalés et plus lumineux — le fond « casse » en le traversant.
                NebulaBloom(t: t, alpha: beat.nebula * scene * 1.25,
                            pulse: beat.impulse, ringsOnly: true)
                    .offset(x: 2.6, y: 1.6)
                    .mask(BottleInteriorShape())
                    .opacity(Double(reveal))

                // L'environnement mord dans le verre : la fumée cosmique,
                // décalée et comprimée, revue à travers la paroi.
                Rectangle()
                    .fill(Color.white)
                    .colorEffect(ShaderLibrary.glassSmoke(.float(Float(t))))
                    .blendMode(.plusLighter)
                    .offset(x: 4, y: 2)
                    .scaleEffect(x: 0.88)
                    .mask(BottleInteriorShape())
                    .opacity(Double(reveal * scene))
                Rectangle()
                    .fill(Color.white)
                    .colorEffect(ShaderLibrary.glassSmoke(.float(Float(t) + 40)))
                    .blendMode(.plusLighter)
                    .scaleEffect(x: 0.55)
                    .mask(BottleInteriorShape()
                        .stroke(Color.white, lineWidth: w * 0.11))
                    .mask(BottleInteriorShape())
                    .opacity(Double(reveal * scene))

                // Et plus fort encore près des parois : une lentille casse
                // davantage au bord qu'au centre.
                NebulaBloom(t: t, alpha: beat.nebula * scene * 1.6,
                            pulse: beat.impulse, ringsOnly: true)
                    .offset(x: 5, y: 3)
                    .mask(BottleInteriorShape()
                        .stroke(Color.white, lineWidth: w * 0.11))
                    .mask(BottleInteriorShape())
                    .opacity(Double(reveal))

                floor(w: w, h: h, scene: scene)

                glass(w: w, h: h, reveal: reveal * scene, ring: ring)
                    .offset(y: bob)

                // Le rétro-éclairage structuré : un cœur quasi blanc, un
                // halo moyen modulé par bruit angulaire qui tourne lentement,
                // et des caustiques — filaments + grain. Plus aucun dégradé
                // radial lisse au-delà du cœur : le lisse, c'est le CGI.
                ZStack {
                    // Le brasier : le cœur a le droit d'être cramé — c'est la
                    // source. Large d'abord, incandescent au centre.
                    // La colonne de lumière : elle monte derrière lui sur un
                    // tiers de la bouteille — c'est elle qui le silhouette.
                    Ellipse()
                        .fill(Color.lunar.opacity(0.32))
                        .frame(width: w * 0.52, height: h * 0.17)
                        .offset(y: -h * 0.045)
                        .blur(radius: 13)
                    Ellipse()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: w * 0.64, height: w * 0.30)
                        .blur(radius: 9)
                    Ellipse()
                        .fill(Color.white.opacity(1.0))
                        .frame(width: w * 0.32, height: w * 0.13)
                        .blur(radius: 2.5)
                    Ellipse()
                        .fill(
                            RadialGradient(colors: [Color.lunar.opacity(0.34), .clear],
                                           center: .center, startRadius: w * 0.05,
                                           endRadius: side * 0.95)
                        )
                        .frame(width: side * 2.2, height: side * 1.15)
                        .mask(
                            AngularGradient(stops: BottleStage.haloStops, center: .center)
                                .rotationEffect(.degrees(t * 3))
                                .frame(width: side * 2.4, height: side * 2.4)
                        )

                    CausticBurst(t: t, glow: beat.glow, side: side)
                }
                .position(x: w * 0.49, y: h * 0.932)
                .opacity(Double(beat.glow * scene) * (0.95 + 0.4 * Double(beat.impulse)))
                .blendMode(.plusLighter)

                // Le liseré de contact : là où il touche le sol, la lumière
                // se pince en un trait vif.
                Ellipse()
                    .stroke(Color.white.opacity(0.68), lineWidth: 0.7)
                    .frame(width: side * 0.52 * beat.squash, height: h * 0.010)
                    .position(x: w / 2, y: h * 0.945)
                    .blur(radius: 0.6)
                    .opacity(Double(beat.glow * scene))
                    .blendMode(.plusLighter)

                // Ombre double sous lui : une serrée sombre, une large douce.
                Ellipse()
                    .fill(Color.black.opacity(0.55 * Double(beat.settle * scene)))
                    .frame(width: side * 0.55 * beat.squash, height: h * 0.018)
                    .position(x: w / 2, y: h * 0.947)
                    .blur(radius: 3)
                Ellipse()
                    .fill(Color.black.opacity(0.30 * Double(beat.settle * scene)))
                    .frame(width: side * 0.95 * beat.squash, height: h * 0.035)
                    .position(x: w / 2, y: h * 0.947)
                    .blur(radius: 8)

                // La traînée de la chute : deux fantômes qui s'estompent.
                ForEach(1..<3) { step in
                    impVisual(eyes: 0, screen: screen, scene: scene, ghost: true, side: side)
                        .frame(width: side, height: side)
                        .scaleEffect(x: beat.squash, y: squashY, anchor: .bottom)
                        .position(x: w / 2,
                                  y: beat.impY * h - side / 2 - CGFloat(step) * h * 0.05)
                        .opacity(Double(trail) * 0.16 / Double(step))
                        .blur(radius: CGFloat(step) * 2.4)
                }

                impVisual(eyes: smoothstep((beat.settle - 0.14) / 0.16),
                          screen: screen, scene: scene, ghost: false, side: side)
                    .frame(width: side, height: side)
                    .scaleEffect(x: beat.squash * (1 + breath * 0.4),
                                 y: squashY * (1 + breath), anchor: .bottom)
                    .rotationEffect(.degrees(-6 * Double(beat.wink)
                                             + 2.2 * Double(beat.shiver) * sin(t * 42)),
                                    anchor: .bottom)
                    .position(x: w / 2, y: beat.impY * h - side / 2)
                    .opacity(Double(beat.appear))

                droplets(w: w, h: h, scene: scene)

                bottleInkLayer(w: w, h: h, scene: scene, bob: bob, screen: screen)

                penLayer(w: w, h: h, scene: scene, screen: screen)
            }
            // Le verrou tonal : écrase mécaniquement les gris moyens — le
            // filet de sécurité anti-« opaque ». Les noirs et les blancs
            // passent intacts.
            .colorEffect(ShaderLibrary.glassGamma(.float(1.12)))
            .blur(radius: min(7, (beat.zoom - 1) * 0.5) * screen)
        }
    }

    // MARK: Sol

    /// L'assise : une flaque de lumière qui s'éclaire avec le verre, et le
    /// reflet du trait sous la bouteille — le sol de galerie.
    private func floor(w: CGFloat, h: CGFloat, scene: CGFloat) -> some View {
        ZStack {
            // La flaque, réduite de moitié : c'est le REFLET qui doit gagner.
            Ellipse()
                .fill(Color.lunar.opacity(Double((0.015 + 0.07 * beat.glow) * scene)))
                .frame(width: w * 1.05, height: h * 0.05)
                .position(x: w / 2, y: h * 0.968)
                .blur(radius: 12)
            Ellipse()
                .fill(Color.lunar.opacity(Double((0.05 + 0.22 * beat.glow
                                                  + 0.35 * beat.impulse) * scene)))
                .frame(width: w * 0.5, height: h * 0.028)
                .position(x: w / 2, y: h * 0.962)
                .blur(radius: 9)

            // La ligne de contact : pleine largeur, quasi blanche — c'est le
            // trait qui brûle sous une bouteille posée sur un sol éclairé.
            Ellipse()
                .stroke(Color.white.opacity(Double((0.35 + 0.55 * beat.glow) * scene)),
                        lineWidth: 0.7)
                .frame(width: w * 0.68, height: h * 0.014)
                .position(x: w / 2, y: h * 0.955)
                .blur(radius: 0.4)
                .blendMode(.plusLighter)

            // Le miroir : reflet net au contact, fondu TOTAL à un quart de sa
            // hauteur — un fondu lent dirait flaque d'eau, pas laque noire.
            // Et il ondule, à peine : la surface est réelle.
            ZStack {
                BottleInk(progress: beat.ink, screen: 1,
                          bodyAlpha: 1 - 0.95 * beat.become)
                GlassEdges(t: t, glow: beat.glow, alpha: beat.become * 0.7)
            }
            .scaleEffect(x: 1, y: -1)
            .offset(y: h * 0.906)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.948),
                        .init(color: .white.opacity(0.30), location: 0.958),
                        .init(color: .white.opacity(0.08), location: 0.988),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .blur(radius: 1.6)
            .distortionEffect(ShaderLibrary.floorRipple(.float(Float(t))),
                              maxSampleOffset: CGSize(width: 3, height: 2))
            .opacity(Double(scene))
        }
    }

    // MARK: Verre

    /// Le verre : un voile lunaire quasi imperceptible, deux reflets, une
    /// ouverture esquissée au col — qui s'éclaire quand il tombe dedans.
    private func glass(w: CGFloat, h: CGFloat, reveal: CGFloat, ring: CGFloat) -> some View {
        ZStack {
            // L'intérieur est NOIR. Pas de voile, pas de lavis : la seule
            // lumière intérieure vient du diablotin, en bas. Un unique souffle
            // remonte du sol dans le tiers inférieur — c'est tout.
            BottleInteriorShape()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .clear, location: 0.62),
                            .init(color: Color.lunar.opacity(0.06 * beat.glow), location: 1.0)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )

            // Les nappes d'épaule : la feuille de lumière large qui suit la
            // courbe du verre — le ciel qui se reflète dans l'épaule. La
            // gauche domine (côté lumière), la droite répond en écho.
            Rectangle()
                .fill(Color.lunar)
                .mask(InkStrokeShape(stroke: Bottle.innerSheet, progress: 0.155,
                                     trimFrom: 0.045))
                .blur(radius: 1.2)
                .opacity(Double(0.06 + 0.13 * beat.glow))
            Rectangle()
                .fill(Color.lunar)
                .mask(InkStrokeShape(stroke: Bottle.innerSheet, progress: 0.955,
                                     trimFrom: 0.860))
                .blur(radius: 1.2)
                .opacity(Double(0.04 + 0.09 * beat.glow))

            // Le cœur net de chaque nappe, posé dessus.
            Rectangle()
                .fill(Color.lunar)
                .mask(InkStrokeShape(stroke: Bottle.innerBand, progress: 0.13,
                                     trimFrom: 0.055))
                .blur(radius: 0.5)
                .opacity(Double(0.08 + 0.16 * beat.glow))
            Rectangle()
                .fill(Color.lunar)
                .mask(InkStrokeShape(stroke: Bottle.innerBand, progress: 0.945,
                                     trimFrom: 0.875))
                .blur(radius: 0.5)
                .opacity(Double(0.05 + 0.10 * beat.glow))

            // Le col-colonne : 3 stries verticales pleine hauteur du goulot,
            // espacement irrégulier, la plus vive décentrée — le verre étroit
            // concentre la lumière.
            Capsule()
                .fill(Color.white.opacity(0.12 + 0.10 * beat.glow))
                .frame(width: 0.7, height: h * 0.070)
                .position(x: w * 0.452, y: h * 0.197)
                .opacity(0.8 + 0.2 * sin(t * 0.5 + 1.2))
            Capsule()
                .fill(Color.white.opacity(0.22 + 0.18 * beat.glow))
                .frame(width: 1.0, height: h * 0.072)
                .position(x: w * 0.487, y: h * 0.196)
                .opacity(0.8 + 0.2 * sin(t * 0.7 + 3.4))
            Capsule()
                .fill(Color.white.opacity(0.08 + 0.07 * beat.glow))
                .frame(width: 0.6, height: h * 0.066)
                .position(x: w * 0.538, y: h * 0.198)
                .opacity(0.8 + 0.2 * sin(t * 0.4 + 5.1))

            // Les longues verticales : deux bandes propres qui courent sur
            // TOUTE la hauteur du corps, fondues aux extrémités — le reflet
            // d'environnement d'un verre poli. C'est elles qui font « photo ».
            Rectangle()
                .fill(Color.lunar)
                .mask(InkStrokeShape(stroke: Bottle.innerClean, progress: 0.365,
                                     trimFrom: 0.185))
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.28),
                            .init(color: .white.opacity(0.9), location: 0.45),
                            .init(color: .white, location: 0.62),
                            .init(color: .white.opacity(0.3), location: 0.82),
                            .init(color: .clear, location: 0.92)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .blur(radius: 0.7)
                .opacity(Double(0.06 + 0.09 * beat.glow))
            Rectangle()
                .fill(Color.lunar)
                .mask(InkStrokeShape(stroke: Bottle.innerClean, progress: 0.815,
                                     trimFrom: 0.635))
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.30),
                            .init(color: .white.opacity(0.8), location: 0.50),
                            .init(color: .white, location: 0.66),
                            .init(color: .clear, location: 0.90)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .blur(radius: 0.7)
                .opacity(Double(0.04 + 0.07 * beat.glow))

            // Les bandes de flanc : l'environnement se reflète dans la paroi,
            // par touches verticales presque nettes, jamais uniformes.
            Rectangle()
                .fill(Color.lunar)
                .mask(InkStrokeShape(stroke: Bottle.innerBand, progress: 0.265,
                                     trimFrom: 0.195))
                .blur(radius: 0.8)
                .opacity(Double(0.05 + 0.09 * beat.glow))
            Rectangle()
                .fill(Color.lunar)
                .mask(InkStrokeShape(stroke: Bottle.innerBand, progress: 0.335,
                                     trimFrom: 0.290))
                .blur(radius: 0.8)
                .opacity(Double(0.03 + 0.05 * beat.glow))
            Rectangle()
                .fill(Color.lunar)
                .mask(InkStrokeShape(stroke: Bottle.innerBand, progress: 0.725,
                                     trimFrom: 0.660))
                .blur(radius: 0.8)
                .opacity(Double(0.04 + 0.07 * beat.glow))
            Rectangle()
                .fill(Color.lunar)
                .mask(InkStrokeShape(stroke: Bottle.innerBand, progress: 0.790,
                                     trimFrom: 0.745))
                .blur(radius: 0.8)
                .opacity(Double(0.025 + 0.045 * beat.glow))

            // Le pied : double anneau — la masse du verre épais du fond.
            Ellipse()
                .stroke(Color.lunar.opacity(0.10 + 0.24 * beat.glow), lineWidth: 0.7)
                .frame(width: w * 0.60, height: h * 0.045)
                .position(x: w / 2, y: h * 0.912)
                .blur(radius: 0.8)
            Ellipse()
                .stroke(Color.lunar.opacity(0.05 + 0.13 * beat.glow), lineWidth: 0.6)
                .frame(width: w * 0.67, height: h * 0.050)
                .position(x: w / 2, y: h * 0.930)
                .blur(radius: 0.9)

            // Les tirets de réfraction : la dalle du fond hache la lumière
            // en petits segments verticaux, entre la bande sombre et l'arête.
            ForEach(0..<5) { index in
                let dashX = [0.30, 0.42, 0.53, 0.63, 0.72][index]
                Capsule()
                    .fill(Color.white.opacity(0.10 + 0.22 * beat.glow))
                    .frame(width: 0.7, height: h * 0.008)
                    .position(x: w * dashX, y: h * 0.9245)
                    .opacity(0.6 + 0.4 * sin(t * (0.6 + Double(index) * 0.23)
                                             + Double(index) * 1.9))
            }

            // Un seul reflet vertical, fin et presque net, côté lumière.
            Capsule()
                .fill(LinearGradient(colors: [Color.lunar.opacity(0.09), Color.lunar.opacity(0.01)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: w * 0.020, height: h * 0.26)
                .position(x: w * 0.215, y: h * 0.58)
                .blur(radius: 1)

            // L'ouverture du col : une vraie bouche en 3D — l'arc avant
            // brillant, l'arrière en retrait.
            Ellipse()
                .stroke(Color.lunar.opacity(0.10 + 0.08 * beat.glow), lineWidth: 0.7)
                .frame(width: w * 0.15, height: h * 0.012)
                .position(x: w / 2, y: h * 0.162)
            Ellipse()
                .trim(from: 0.02, to: 0.48)
                .stroke(Color.white.opacity(0.22 + 0.20 * beat.glow),
                        style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
                .frame(width: w * 0.15, height: h * 0.012)
                .position(x: w / 2, y: h * 0.162)

            // La bande sombre du pied : le verre épais du fond se détache de
            // l'embrasement du contact — c'est elle qui donne l'assise 3D.
            Rectangle()
                .fill(Color.black.opacity(0.8))
                .frame(width: w, height: h * 0.009)
                .position(x: w / 2, y: h * 0.9425)
                .blur(radius: 0.5)

            // L'onde de l'impact, contenue par le verre.
            if ring > 0.001 && ring < 1 {
                Ellipse()
                    .stroke(Color.lunar.opacity(0.45 * (1 - ring)),
                            lineWidth: 1.4 * (1 - ring) + 0.4)
                    .frame(width: w * (0.2 + 1.4 * ring), height: h * (0.04 + 0.26 * ring))
                    .position(x: w / 2, y: h * 0.94)
            }
        }
        .mask(BottleInteriorShape())
        .opacity(Double(reveal))
    }

    // MARK: Diablotin

    /// Corps en encre vivante (veines qui dérivent), queue propagée, ombre
    /// double, visage. Sur la sortie Cheshire, tout suit `scene` sauf les
    /// yeux : ils tiennent le plan seuls.
    private func impVisual(eyes: CGFloat, screen: CGFloat, scene: CGFloat,
                           ghost: Bool, side: CGFloat) -> some View {
        let rim = 0.85 - 0.45 * smoothstep(beat.settle / 0.35)
        let pop = 1 + 0.22 * sin(smoothstep((beat.settle - 0.14) / 0.24) * .pi)
        // Clignement naturel, un peu après l'ouverture des yeux.
        let naturalBlink = span(t, 2.98, 0.05, 3.06, 0.06)
        // Pré-plissement : les yeux se préparent au clin d'œil.
        let squint = span(t, 3.66, 0.06, 3.74, 0.05)
        // Le regard : vers nous, puis il SUIT LA PLUME qui scelle le bouchon
        // au-dessus de lui, redescend vers nous — et clin d'œil.
        let gaze = gazeDirection

        return ZStack {
            ZStack {
                TailShape(drag: beat.tailDrag, t: t, whip: beat.whip)
                    .fill(InkWhite.body)
                TailShape(drag: beat.tailDrag, t: t, whip: beat.whip)
                    .stroke(InkWhite.rim, lineWidth: 0.5)
                    .opacity(0.25 + Double(rim) * 0.55)
                TailSpadeShape(drag: beat.tailDrag, t: t, whip: beat.whip)
                    .fill(InkWhite.body)
                TailSpadeShape(drag: beat.tailDrag, t: t, whip: beat.whip)
                    .stroke(InkWhite.rim, lineWidth: 0.5)
                    .opacity(0.25 + Double(rim) * 0.55)

                ImpBodyShape()
                    .fill(InkWhite.body)

                // L'encre tourne encore : deux veines qui dérivent en lui.
                if !ghost {
                    InkVeinShape(phase: CGFloat(t) * 0.18, seed: 1.3)
                        .stroke(Color.lunar.opacity(0.028),
                                style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .blur(radius: 3)
                        .mask(ImpBodyShape())
                    InkVeinShape(phase: CGFloat(t) * 0.13 + 2, seed: 4.7)
                        .stroke(Color.lunar.opacity(0.022),
                                style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .blur(radius: 2.5)
                        .mask(ImpBodyShape())
                }

                // Le reflet sur le crâne : l'encre est encore humide.
                ImpBodyShape()
                    .fill(
                        RadialGradient(colors: [Color.lunar.opacity(0.05), .clear],
                                       center: UnitPoint(x: 0.42, y: 0.26),
                                       startRadius: 0, endRadius: 80)
                    )

                // Le rebond : la lumière du sol remonte sur son ventre — sa
                // moitié basse baigne dans la lueur qu'il projette lui-même.
                if !ghost {
                    ImpBodyShape()
                        .fill(
                            RadialGradient(colors: [Color.lunar.opacity(0.14), .clear],
                                           center: UnitPoint(x: 0.5, y: 1.02),
                                           startRadius: 0, endRadius: side * 0.60)
                        )
                        .opacity(Double(beat.glow))
                }

                // La laque : une fenêtre de lumière déformée, posée sur la
                // courbe du crâne — c'est elle qui fait « sphère laquée ».
                if !ghost {
                    Ellipse()
                        .fill(
                            LinearGradient(colors: [Color.lunar.opacity(0.11), .clear],
                                           startPoint: .top, endPoint: .bottom)
                        )
                        .frame(width: side * 0.30, height: side * 0.13)
                        .rotationEffect(.degrees(-16))
                        .offset(x: -side * 0.11, y: -side * 0.16)
                        .blur(radius: 2.5)
                        .mask(ImpBodyShape())
                }

                // Liseré directionnel : vif sur crête et cornes, éteint après.
                ImpBodyShape()
                    .stroke(InkWhite.rim, lineWidth: 0.75)
                    .opacity(Double(rim) * 0.65)

                // L'arc laqué : UN reflet net sur la courbe haute du crâne —
                // c'est lui qui fait « sphère brillante », pas le halo doux.
                if !ghost {
                    ImpBodyShape()
                        .stroke(Color.white.opacity(0.5), lineWidth: 0.9)
                        .blur(radius: 0.4)
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .white, location: 0.0),
                                    .init(color: .white.opacity(0), location: 0.42)
                                ],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .opacity(Double(0.35 + 0.45 * beat.glow))
                }

                // Le rim inversé : le rétro-éclairage embrase son bord bas.
                // Deux sources de lumière = un corps qui existe.
                ImpBodyShape()
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: .clear, location: 0.55),
                                .init(color: Color.lunar.opacity(0.75), location: 0.85),
                                .init(color: .white.opacity(1.0), location: 1.0)
                            ],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 1.0
                    )
                    .opacity(Double(beat.glow))
            }
            .opacity(Double(scene))

            if !ghost {
                ImpFace(eyes: eyes, wink: beat.wink,
                        blink: max(beat.blink, naturalBlink), squint: squint,
                        gaze: gaze, sparkle: sparkleNow, pop: pop, screen: screen)
                    .opacity(Double(beat.eyesAlpha))
            }
        }
        .shadow(color: Color.lunar.opacity((0.08 + 0.14 * Double(rim)) * Double(scene)),
                radius: 10 * screen)
    }

    /// Où regarde-t-il. Vers nous — puis vers la plume pendant le scellage —
    /// puis un lent vagabondage pendant la tenue du plan.
    private var gazeDirection: CGPoint {
        let followPen = span(t, 3.02, 0.20, 3.50, 0.18)
        if followPen > 0.01 {
            let target = CGPoint(x: clamp01((beat.pen.x - 0.35) / 0.3) * 2 - 1, y: -0.85)
            return CGPoint(x: target.x * followPen, y: target.y * followPen)
        }
        if t > 4.15 && t < 4.60 {
            let wander = ramp(t, 4.15, 0.25) * (1 - ramp(t, 4.45, 0.15))
            return CGPoint(x: 0.35 * wander * CGFloat(sin((t - 4.15) * 2.4)),
                           y: 0.12 * wander)
        }
        return .zero
    }

    /// L'étoile sur le catchlight, au pic du clin d'œil.
    private var sparkleNow: CGFloat {
        span(t, 3.80, 0.09, 3.97, 0.14)
    }

    // MARK: Gouttelettes

    /// Trois gouttes d'encre giclent à l'atterrissage, montent en arc,
    /// retombent, disparaissent. 450 millisecondes de vie.
    private func droplets(w: CGFloat, h: CGFloat, scene: CGFloat) -> some View {
        // Les arcs s'écartent de lui : les gouttes doivent se détacher sur le
        // verre éclairé, pas se perdre devant sa silhouette.
        let params: [(vx: CGFloat, vy: CGFloat, size: CGFloat)] = [
            (-0.34, -0.55, 2.8), (0.16, -0.68, 2.2), (0.38, -0.48, 2.5)
        ]
        let born = 2.54
        let life = (t - born) / 0.45

        return ZStack {
            if life > 0 && life < 1 {
                let age = CGFloat(t - born)
                ForEach(0..<3) { index in
                    let p = params[index]
                    let x = w * (0.5 + p.vx * age)
                    let y = h * (0.78 + p.vy * age + 1.35 * age * age)
                    Circle()
                        .fill(InkWhite.body)
                        .overlay(Circle().stroke(Color.lunar.opacity(0.7), lineWidth: 0.5))
                        .frame(width: p.size, height: p.size)
                        .position(x: x, y: y)
                        .opacity(Double((1 - CGFloat(life)) * scene))
                }
            }
        }
    }

    // MARK: Encre

    /// Le trait, son segment frais qui « sèche », et le balayage de lumière.
    private func bottleInkLayer(w: CGFloat, h: CGFloat, scene: CGFloat,
                                bob: CGFloat, screen: CGFloat) -> some View {
        let bodyP = clamp01(beat.ink / 0.84)

        return ZStack {
            // L'encre — qui s'efface du corps quand le verre prend vie.
            BottleInk(progress: beat.ink, screen: screen,
                      bodyAlpha: 1 - 0.82 * beat.become)

            // Les arêtes : blooms masqués dedans, cheveux jumeaux dessus.
            GlassEdges(t: t, glow: beat.glow, alpha: beat.become)

            // Palier 4 — les spéculaires durs. Nets, presque blancs, rares.
            hardSpeculars(w: w, h: h, screen: screen)

            // L'encre fraîche brille, puis sèche : une fenêtre plus lumineuse
            // juste derrière la plume.
            if bodyP > 0.02 && bodyP < 1 {
                InkStrokeShape(stroke: Bottle.body, progress: bodyP,
                               trimFrom: max(0, bodyP - 0.055))
                    .fill(Color.white)
                    .blur(radius: 0.4)
                    .opacity(0.55)
                    .shadow(color: Color.lunar.opacity(0.6), radius: 3 * screen)
            }

            // L'éclat qui court une fois le long du contour scellé.
            if beat.sweepAlpha > 0.01 {
                Rectangle()
                    .fill(Color.white)
                    .mask {
                        InkStrokeShape(stroke: Bottle.sweep,
                                       progress: min(1, beat.sweepPos + 0.10),
                                       trimFrom: beat.sweepPos)
                    }
                    .blur(radius: 1.6 * screen)
                    .opacity(Double(beat.sweepAlpha) * 0.85)
            }

            // Le ping spéculaire sur le bouchon, à la fin du balayage.
            capPing(w: w, h: h, screen: screen)
        }
        .opacity(Double(scene))
        .offset(y: bob)
    }

    /// Les spéculaires durs — palier 4 de l'échelle de valeurs. Un trait
    /// brûlant sur le col, deux arcs rasoir sur les épaules. Nets (flou ≤ 0,5),
    /// presque blancs, avec un vrai bloom autour. Trois, pas trente.
    private func hardSpeculars(w: CGFloat, h: CGFloat, screen: CGFloat) -> some View {
        let presence = Double(beat.become * (0.35 + 0.65 * beat.glow))
        let breathe = 0.86 + 0.14 * sin(t * 0.8)

        return ZStack {
            // Le nœud lumineux : col + bouchon sont l'endroit le plus chaud
            // de l'image. Une nappe de bloom large les baigne…
            Ellipse()
                .fill(
                    RadialGradient(colors: [Color.lunar.opacity(0.07), .clear],
                                   center: .center, startRadius: 0, endRadius: w * 0.17)
                )
                .frame(width: w * 0.34, height: h * 0.11)
                .position(x: w * 0.5, y: h * 0.095)
                .opacity(presence)

            // …et les deux parois du goulot saturent, presque blanches.
            Capsule()
                .fill(Color.white)
                .frame(width: 1.0, height: h * 0.050)
                .rotationEffect(.degrees(1.5))
                .position(x: w * 0.426, y: h * 0.193)
                .shadow(color: .white.opacity(0.95), radius: 2.5 * screen)
                .shadow(color: .white.opacity(0.4), radius: 7 * screen)
                .opacity(presence * breathe * 1.15)
            Capsule()
                .fill(Color.white)
                .frame(width: 0.8, height: h * 0.042)
                .rotationEffect(.degrees(-1.5))
                .position(x: w * 0.574, y: h * 0.195)
                .shadow(color: .white.opacity(0.85), radius: 2.5 * screen)
                .opacity(presence * 0.75 * (2 - breathe))

            // Les arcs d'épaule : rasoir, posés sur l'arête elle-même.
            Rectangle()
                .fill(Color.white)
                .mask(InkStrokeShape(stroke: Bottle.body, progress: 0.925,
                                     trimFrom: 0.868))
                .shadow(color: .white.opacity(0.7), radius: 4 * screen)
                .opacity(presence * 0.9)
            Rectangle()
                .fill(Color.white)
                .mask(InkStrokeShape(stroke: Bottle.body, progress: 0.125,
                                     trimFrom: 0.058))
                .shadow(color: .white.opacity(0.6), radius: 4 * screen)
                .opacity(presence * 0.6 * (2 - breathe))

            // Les étoiles du verre : le bouchon en majesté, puis des micro-
            // glints semés sur les points chauds — chacun sa phase.
            SparkleShape()
                .fill(Color.white)
                .frame(width: 6, height: 6)
                .position(x: w * 0.60, y: h * 0.033)
                .opacity(Double(ramp(t, 3.95, 0.3)) * (0.40 + 0.30 * sin(t * 0.9 + 1)))
                .shadow(color: .white.opacity(0.9), radius: 3 * screen)
                .shadow(color: .white.opacity(0.4), radius: 8 * screen)
            // Les éclats auto-placés : les maxima de courbure × enveloppe.
            // Jamais deux phases synchrones — le synchrone, c'est le faux.
            ForEach(0..<GlassEdgeModel.glints.count, id: \.self) { index in
                let glint = GlassEdgeModel.glints[index]
                let pulse = pow(max(0, sin(t * glint.freq + glint.phase)), 3)
                if glint.size > 3.2 {
                    SparkleShape()
                        .fill(Color.white)
                        .frame(width: glint.size * 1.8, height: glint.size * 1.8)
                        .position(x: glint.x * w, y: glint.y * h)
                        .opacity(presence * pulse)
                } else {
                    Circle()
                        .fill(Color.white)
                        .frame(width: glint.size, height: glint.size)
                        .position(x: glint.x * w, y: glint.y * h)
                        .opacity(presence * pulse * 0.9)
                }
            }
        }
        .blendMode(.plusLighter)
    }

    private func capPing(w: CGFloat, h: CGFloat, screen: CGFloat) -> some View {
        let ping = span(t, 3.88, 0.07, 4.00, 0.12)
        return SparkleShape()
            .fill(Color.white)
            .frame(width: 7 * ping, height: 7 * ping)
            .position(x: w * 0.575, y: h * 0.032)
            .opacity(Double(ping) * 0.9)
            .shadow(color: .white.opacity(0.7), radius: 3 * screen)
    }

    // MARK: Plume

    /// La pointe qui écrit, et les étincelles qui en tombent.
    private func penLayer(w: CGFloat, h: CGFloat, scene: CGFloat,
                          screen: CGFloat) -> some View {
        ZStack {
            if beat.penAlpha > 0.01 {
                Circle()
                    .fill(Color.white)
                    .frame(width: 4.2 * screen, height: 4.2 * screen)
                    .shadow(color: .white.opacity(0.95), radius: 5 * screen)
                    .shadow(color: .white.opacity(0.5), radius: 14 * screen)
                    .position(x: beat.pen.x * w, y: beat.pen.y * h)
                    .opacity(Double(beat.penAlpha))
            }

            // Les étincelles : des grains qui tombent de la plume en macro.
            ForEach(0..<4) { index in
                let bornAt = 0.18 + Double(index) * 0.31
                let age = t - bornAt
                if age > 0 && age < 0.42 {
                    let origin = SplashBeat.point(
                        on: SplashBeat.penBody,
                        at: ramp(bornAt, -0.10, 1.50)
                    )
                    let fall = CGFloat(age)
                    Circle()
                        .fill(Color.lunar)
                        .frame(width: 1.3 * screen, height: 1.3 * screen)
                        .position(x: origin.x * w + fall * w * 0.02 * (index.isMultiple(of: 2) ? 1 : -1),
                                  y: origin.y * h + fall * fall * h * 0.35)
                        .opacity(Double(1 - age / 0.42) * 0.8)
                        .shadow(color: .white.opacity(0.6), radius: 2 * screen)
                }
            }
        }
        .opacity(Double(scene))
    }
}

/// L'encre. Le dégradé est posé sur toute la boîte puis masqué par les traits :
/// s'il suivait la forme, la teinte glisserait pendant que le trait s'écrit.
private struct BottleInk: View {
    var progress: CGFloat
    var screen: CGFloat
    /// La transmutation retire l'encre du corps (le verre la remplace) ;
    /// bouchon et lèvre restent dessinés.
    var bodyAlpha: CGFloat = 1

    var body: some View {
        Rectangle()
            .fill(InkWhite.stroke)
            .mask {
                ZStack {
                    trace(Bottle.body, clamp01(progress / 0.84))
                        .opacity(Double(bodyAlpha))
                    trace(Bottle.cap, clamp01((progress - 0.84) / 0.11))
                    trace(Bottle.collar, clamp01((progress - 0.95) / 0.05))
                }
            }
            // Lueur serrée : le trait ne doit JAMAIS embuer l'intérieur.
            .shadow(color: Color.lunar.opacity(0.25), radius: 2.5 * screen)
    }

    @ViewBuilder
    private func trace(_ stroke: InkStroke, _ progress: CGFloat) -> some View {
        InkStrokeShape(stroke: stroke, progress: progress)
            .fill(Color.white)
        InkStrokeShape(stroke: stroke.echo, progress: progress)
            .fill(Color.white.opacity(0.32))
    }
}

// MARK: - Splash

/// Un plan-séquence : macro sur l'encre qui s'écrit, recul continu, plongeon
/// par le col ouvert, scellage, clin d'œil — et une sortie Cheshire : tout
/// s'éteint sauf les yeux. Un toucher passe la séquence.
struct SplashView: View {
    var onFinish: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var finished = false
    @State private var landed = false
    @State private var winked = false
    @State private var start: Date?

    private static let bottleWidth: CGFloat = 190
    private var bottleHeight: CGFloat { Self.bottleWidth / BottleStage.aspect }

    var body: some View {
        ZStack {
            if reduceMotion {
                composition(.resolved, t: 0)
            } else {
                // Une seule horloge : chaque image est recalculée depuis la
                // partition, rien ne peut se désynchroniser.
                TimelineView(.animation) { context in
                    let t = start.map { context.date.timeIntervalSince($0) } ?? 0
                    composition(.at(t), t: t)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .sensoryFeedback(.impact(weight: .heavy, intensity: 0.75), trigger: landed)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.5), trigger: winked)
        .onAppear { start = Date() }
        .task { await run() }
    }

    /// Les plans, du fond vers l'œil : galaxie, bouteille, poussière proche,
    /// vignette vivante, grain. Pas de titre : la bouteille seule.
    @ViewBuilder
    private func composition(_ beat: SplashBeat, t: Double) -> some View {
        ZStack {
            GalaxyBackground(t: t, impulse: beat.impulse, dim: beat.fade,
                             zoom: beat.zoom)

            // L'environnement : les volutes que le verre pourra refléter et
            // déformer — sans elles, aucune matière n'est crédible.
            Rectangle()
                .fill(Color.white)
                .colorEffect(ShaderLibrary.glassSmoke(.float(Float(t))))
                .blendMode(.plusLighter)
                .opacity(1 - Double(beat.fade))
                .ignoresSafeArea()
                .allowsHitTesting(false)

            BottleStage(beat: beat, t: t)
                .frame(width: Self.bottleWidth, height: bottleHeight)
                .scaleEffect(beat.zoom)
                .offset(x: -beat.zoom * (beat.camX - 0.5) * Self.bottleWidth,
                        y: -beat.zoom * (beat.camY - 0.5) * bottleHeight)
                .rotationEffect(.degrees(-6 * Double(clamp01((beat.zoom - 1) / 7))))

            DustField(t: t, impulse: beat.impulse, count: 12,
                      sizeRange: 1.0...1.6, alphaRange: 0.045...0.10,
                      speed: 2.1, seed: 47,
                      defocus: 0.6 + min(4, (beat.zoom - 1) * 0.3))
                .opacity(1 - Double(beat.fade))
                .ignoresSafeArea()
                .allowsHitTesting(false)

            vignette(beat)

            GrainOverlay(t: t)
                .opacity(1 - 0.6 * Double(beat.fade))
        }
    }

    /// La vignette respire avec le plan : serrée en macro, ouverte au recul,
    /// resserrée sur le clin d'œil.
    private func vignette(_ beat: SplashBeat) -> some View {
        let macroTight = clamp01((beat.zoom - 1) / 8)
        let push = clamp01((beat.zoom - 1) * 4) * (beat.settle >= 1 ? 1 : 0)
        let radius = 480 - 150 * macroTight - 50 * push
        return RadialGradient(colors: [.clear, .black.opacity(0.62)],
                              center: .center, startRadius: 130, endRadius: radius)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }

    /// Le rythme est tenu ici : les retours haptiques doivent tomber sur
    /// l'image, pas à côté.
    private func run() async {
        if reduceMotion {
            try? await Task.sleep(for: .seconds(1.2))
            finish()
            return
        }
        try? await Task.sleep(for: .seconds(2.52))
        landed = true
        try? await Task.sleep(for: .seconds(1.23))
        winked = true
        try? await Task.sleep(for: .seconds(1.85))
        finish()
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        onFinish()
    }
}

#Preview {
    SplashView()
        .preferredColorScheme(.dark)
}
