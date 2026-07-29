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

    /// Les yeux : BLANC PUR — de la porcelaine neutre, l'ombrage vient de la
    /// valeur, jamais d'une teinte. Le moindre bleu ferait « lavande ».
    static let eye = LinearGradient(
        stops: [
            .init(color: .white, location: 0.0),
            .init(color: Color(white: 0.97), location: 0.45),
            .init(color: Color(white: 0.86), location: 1.0)
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
            let top = smoothstep((0.42 - yNorm) / 0.26) * 0.10
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

/// La passe sombre : l'épine externe strokée en noir sur le tiers haut de la
/// bouteille — quand le fond est un voile lumineux, une arête de verre réelle
/// est PLUS SOMBRE que lui. Blend normal, jamais additif.
private struct GlassDarkEdge: View {
    var alpha: CGFloat

    var body: some View {
        Canvas { context, size in
            guard alpha > 0.01 else { return }
            let m = GlassEdgeModel.outer
            func map(_ p: CGPoint) -> CGPoint {
                CGPoint(x: p.x * size.width, y: p.y * BottleStage.aspect * size.height)
            }
            for i in 0..<(m.spine.count - 1) {
                let yNorm = m.spine[i].y * BottleStage.aspect
                let dark = 0.60 * smoothstep((0.50 - yNorm) / 0.22)
                guard dark > 0.02 else { continue }
                var segment = Path()
                segment.move(to: map(m.spine[i]))
                segment.addLine(to: map(m.spine[i + 1]))
                context.stroke(
                    segment,
                    with: .color(.black.opacity(Double(dark * alpha))),
                    style: StrokeStyle(lineWidth: yNorm < 0.14 ? 1.6 : 1.4,
                                       lineCap: .round)
                )
            }
        }
        .allowsHitTesting(false)
    }
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
        // La clé penche franchement à gauche : un plateau a un côté dominant.
        let sideBias = 1.18 - 0.40 * m.spine[i].x
        let e = clamp01(m.envelope[i] + 0.10 * Self.drift(CGFloat(i) / 28 + CGFloat(t) * 0.04))
        // Les flancs droits MEURENT : un contour réel n'existe que là où la
        // lumière accroche. L'enveloppe décide des accidents — 2-3 éclats par
        // flanc, et de vrais trous entre eux. L'œil perd la ligne, la retrouve.
        let flankZone = smoothstep((yNorm - 0.33) / 0.06)
            * (1 - smoothstep((yNorm - 0.74) / 0.08))
        let flat = 1 - smoothstep((f - 0.06) / 0.12)
        let accident = smoothstep((e - 0.62) / 0.22)
        let flank = 1 - flankZone * flat * (1 - max(0.06, accident * 0.9))
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
                .opacity(Double((0.14 + 0.13 * glow) * alpha))
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

/// Le diablotin, silhouette précieuse : une goutte pleine aux courbes
/// TENDUES — la ligne est dessinée par la tension, jamais par le bruit — et
/// deux cornes-griffes : nées d'un point étroit du crâne, cambrées, effilées
/// en aiguille. La droite un souffle plus haute — l'asymétrie de la main.
private enum Imp {
    static let outline = inkPolyline(from: CGPoint(x: 0.500, y: 0.975), [
        .curve(0.318, 0.968, 0.208, 0.890),   // assise gauche pleine
        .curve(0.106, 0.780, 0.118, 0.582),   // flanc gauche tendu
        .curve(0.132, 0.442, 0.240, 0.322),   // joue gauche
        .curve(0.196, 0.246, 0.226, 0.150),   // corne g. : petite griffe cambrée
        .curve(0.243, 0.108, 0.260, 0.130),   // pointe fine
        .curve(0.296, 0.205, 0.354, 0.262),   // bord interne, retour au crâne
        .curve(0.500, 0.212, 0.646, 0.256),   // crâne entre les cornes
        .curve(0.692, 0.162, 0.728, 0.094),   // corne d. : bord interne raide
        .curve(0.744, 0.048, 0.764, 0.078),   // pointe aiguille, plus haute
        .curve(0.798, 0.180, 0.774, 0.316),   // bord externe, cambrure inverse
        .curve(0.862, 0.424, 0.878, 0.582),   // joue droite
        .curve(0.892, 0.780, 0.796, 0.890),   // flanc droit
        .curve(0.690, 0.968, 0.500, 0.975)    // assise droite
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

// MARK: - La couronne

/// La géométrie de la couronne : pour chaque point de l'outline du diablotin,
/// sa normale extérieure — et trois populations tirées une fois pour toutes :
/// les grains de givre, la dentelle, les moustaches.
private enum CoronaModel {
    static let points: [CGPoint] = Imp.outline
    static let normals: [CGPoint] = {
        let n = points.count
        let centroid = CGPoint(x: 0.5, y: 0.55)
        return (0..<n).map { i in
            let a = points[max(0, i - 1)], b = points[min(n - 1, i + 1)]
            var dx = b.x - a.x, dy = b.y - a.y
            let length = max(hypot(dx, dy), 0.0001)
            dx /= length; dy /= length
            var nx = -dy, ny = dx
            if nx * (centroid.x - points[i].x) + ny * (centroid.y - points[i].y) > 0 {
                nx = -nx; ny = -ny
            }
            return CGPoint(x: nx, y: ny)
        }
    }()

    struct Spark {
        let index: Int
        let distance: CGFloat
        let slide: CGFloat
        let size: CGFloat
        let freq: Double
        let phase: Double
    }

    /// Les grains : denses contre la surface, raréfiés au loin (décroissance
    /// quadratique de la distance).
    static let sparks: [Spark] = {
        let noise = InkNoise(seed: 113)
        return (0..<150).map { i in
            let u = CGFloat(i)
            return Spark(
                index: Int(abs(noise(u * 1.7)) * CGFloat(points.count - 1)),
                distance: pow(abs(noise(u * 2.9)), 2) * 0.085,
                slide: noise(u * 4.1) * 0.015,
                size: 0.5 + 1.1 * abs(noise(u * 5.3)),
                freq: 0.5 + 2.3 * Double(abs(noise(u * 6.7))),
                phase: Double(abs(noise(u * 8.1))) * 6.28
            )
        }
    }()

    /// La dentelle : des micro-filaments courbes posés SUR la silhouette.
    static let laces: [(index: Int, length: Int, bow: CGFloat, alpha: Double,
                        freq: Double, phase: Double)] = {
        let noise = InkNoise(seed: 127)
        return (0..<22).map { i in
            let u = CGFloat(i)
            return (index: Int(abs(noise(u * 1.9)) * CGFloat(points.count - 12)),
                    length: 4 + Int(abs(noise(u * 3.1)) * 7),
                    bow: noise(u * 4.7) * 0.020,
                    alpha: 0.22 + 0.38 * Double(abs(noise(u * 6.1))),
                    freq: 0.3 + 0.9 * Double(abs(noise(u * 7.3))),
                    phase: Double(abs(noise(u * 9.1))) * 6.28)
        }
    }()

    /// Les moustaches : rares, longues, presque invisibles — l'aura respire.
    static let whiskers: [(index: Int, length: CGFloat, freq: Double, phase: Double)] = {
        let noise = InkNoise(seed: 131)
        return (0..<7).map { i in
            let u = CGFloat(i)
            return (index: Int(abs(noise(u * 2.3)) * CGFloat(points.count - 1)),
                    length: 0.05 + 0.09 * abs(noise(u * 3.7)),
                    freq: 0.25 + 0.5 * Double(abs(noise(u * 5.1))),
                    phase: Double(abs(noise(u * 6.9))) * 6.28)
        }
    }()
}

/// Le givre de lumière : la couronne de particules accrochée à sa silhouette —
/// grains scintillants, dentelle de filaments, moustaches. Tout est déphasé,
/// rien n'est symétrique. Elle hérite de ses mouvements (squash, respiration).
private struct ImpCorona: View {
    var t: Double
    var alpha: CGFloat
    /// Le clin d'œil et l'impact la font flamber.
    var pulse: CGFloat

    var body: some View {
        Canvas { context, size in
            guard alpha > 0.01 else { return }
            let side = min(size.width, size.height)
            func at(_ index: Int, out distance: CGFloat, slide: CGFloat) -> CGPoint {
                let i = min(max(index, 1), CoronaModel.points.count - 2)
                let p = CoronaModel.points[i]
                let n = CoronaModel.normals[i]
                return CGPoint(
                    x: (p.x + n.x * distance - n.y * slide) * size.width,
                    y: (p.y + n.y * distance + n.x * slide) * size.height
                )
            }

            // Les grains. La lumière vit dans la FLAQUE : dense à sa base,
            // raréfiée vers la crête — jamais une guirlande posée au contour.
            for spark in CoronaModel.sparks {
                let position = at(spark.index, out: spark.distance, slide: spark.slide)
                let py = CoronaModel.points[min(max(spark.index, 1),
                                                CoronaModel.points.count - 2)].y
                let baseWeight = 0.18 + 0.82 * Double(smoothstep((py - 0.38) / 0.42))
                let near = 1 - spark.distance / 0.09
                let twinkle = 0.25 + 0.75 * pow(0.5 + 0.5 * sin(t * spark.freq + spark.phase), 3)
                let a = twinkle * Double(near) * (0.85 + 0.6 * Double(pulse)) * Double(alpha)
                    * baseWeight
                let r = spark.size
                // Chaque grain porte son auréole — c'est la matière lumineuse.
                context.fill(
                    Path(ellipseIn: CGRect(x: position.x - r * 3.2, y: position.y - r * 3.2,
                                           width: r * 6.4, height: r * 6.4)),
                    with: .color(Color.lunar.opacity(a * 0.13))
                )
                context.fill(
                    Path(ellipseIn: CGRect(x: position.x - r, y: position.y - r,
                                           width: r * 2, height: r * 2)),
                    with: .color(.white.opacity(a))
                )
            }

            // La dentelle — pondérée elle aussi vers la base.
            for lace in CoronaModel.laces {
                var path = Path()
                path.move(to: at(lace.index, out: 0.004, slide: 0))
                let mid = at(lace.index + lace.length / 2, out: 0.004 + lace.bow, slide: 0)
                let end = at(lace.index + lace.length, out: 0.004, slide: 0)
                path.addQuadCurve(to: end, control: mid)
                let ly = CoronaModel.points[min(max(lace.index, 1),
                                               CoronaModel.points.count - 2)].y
                let laceWeight = 0.30 + 0.70 * Double(smoothstep((ly - 0.38) / 0.42))
                let flicker = 0.7 + 0.3 * sin(t * lace.freq + lace.phase)
                context.stroke(
                    path,
                    with: .color(.white.opacity(lace.alpha * flicker * laceWeight
                                                * (0.8 + 0.6 * Double(pulse)) * Double(alpha))),
                    style: StrokeStyle(lineWidth: 0.4 * side / 87, lineCap: .round)
                )
            }

            // Les moustaches.
            for whisker in CoronaModel.whiskers {
                let sway = CGFloat(sin(t * whisker.freq + whisker.phase)) * 0.012
                var path = Path()
                path.move(to: at(whisker.index, out: 0.006, slide: 0))
                let mid = at(whisker.index, out: whisker.length * 0.5, slide: sway * 0.5)
                let end = at(whisker.index, out: whisker.length, slide: sway)
                path.addQuadCurve(to: end, control: mid)
                let breathe = 0.5 + 0.5 * sin(t * whisker.freq * 0.7 + whisker.phase + 2)
                context.stroke(
                    path,
                    with: .color(.white.opacity(0.13 * breathe * Double(alpha))),
                    style: StrokeStyle(lineWidth: 0.35 * side / 87, lineCap: .round)
                )
            }
        }
        .allowsHitTesting(false)
        .blendMode(.plusLighter)
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

// MARK: - La dissolution

/// La sortie du diablotin : son corps se défait en 240 particules qui
/// CONDENSENT en une sphère de lumière — l'orbe, avec sa dentelle et son
/// cœur — puis l'orbe s'égrène : les grains montent en spirale dans le haut
/// du verre, décélèrent, s'affinent, s'éteignent. Les deux derniers grains
/// brillants sont ses yeux, qui montent côte à côte.
private struct ImpDissolve: View {
    var t: Double
    var dissolve: CGFloat
    var disperse: CGFloat
    var glow: CGFloat

    /// Rôles par index : 0-1 yeux, 2-561 coquille sphérique, 562-651 cœur,
    /// 652-731 gerbes polaires, 732-799 fil vers le col.
    struct Grain {
        let startImp: CGPoint
        let phi: CGFloat
        let theta0: Double
        let omega: Double
        let orbit: CGFloat
        let stagIn: CGFloat
        let stagOut: CGFloat
        let riseTop: CGFloat
        let unscrew: Double
        let swayFreq: Double
        let phase: Double
        let size: CGFloat
        let bright: Double
        let hero: Bool
        let straggler: Bool
        /// Tours COMPLETS d'enroulement pendant le morphisme (signés) — un
        /// entier, pour que le grain arrive exactement sur sa place de sphère.
        let turns: Double
        /// Gonflement de la nappe à mi-vol : le ruban s'ouvre puis se referme.
        let bulge: CGFloat
    }

    private static let impSide: CGFloat = 0.30
    private static let impSideH: CGFloat = 0.30 * BottleStage.aspect
    private static let orbCenterY: CGFloat = 0.74
    private static let orbR: CGFloat = 0.125

    static let grains: [Grain] = {
        let noise = InkNoise(seed: 151)
        return (0..<800).map { i in
            let u = CGFloat(i)
            let index = Int(abs(noise(u * 1.3)) * CGFloat(Imp.outline.count - 1))
            let inward = sqrt(abs(noise(u * 2.1)))
            let outlinePoint = Imp.outline[index]
            var start = CGPoint(x: 0.5 + (outlinePoint.x - 0.5) * inward,
                                y: 0.55 + (outlinePoint.y - 0.55) * inward)

            // Sphère VRAIE : cos(phi) uniforme — le limbe se densifie tout
            // seul à la projection, comme sur une vraie boule.
            let phi = acos(max(-1, min(1, 2 * abs(noise(u * 3.9)) - 1)))
            var orbit = Self.orbR * (0.94 + 0.10 * abs(noise(u * 4.3)))
            var size: CGFloat
            let classPick = abs(noise(u * 5.9))
            if classPick < 0.55 { size = 0.4 + 0.3 * abs(noise(u * 6.1)) }
            else if classPick < 0.88 { size = 0.7 + 0.5 * abs(noise(u * 6.3)) }
            else { size = 0.9 + 0.4 * abs(noise(u * 6.5)) }
            var bright = 0.26 + 0.36 * Double(abs(noise(u * 9.7)))
            let hero = abs(noise(u * 16.1)) > 0.96
            if hero { bright = 0.9 + 0.1 * Double(abs(noise(u * 16.3))) }

            // Le PELAGE : la surface part en premier (inward ≈ 1 = sur le
            // contour), le cœur suit — le corps s'écorce en vagues.
            var stagIn = clamp01((1 - inward) * 0.75 + abs(noise(u * 6.7)) * 0.25)
            var riseTop = 0.10 + 0.32 * abs(noise(u * 7.9))
            let straggler = abs(noise(u * 17.3)) < 0.20

            // La NAPPE : les grains d'un même quartier du contour tournent
            // dans le même sens — des rubans qui s'enroulent, pas une pluie.
            let nappe = (index * 4) / max(1, Imp.outline.count)
            var turns = Double(nappe % 2 == 0 ? 1 : -1)
            if abs(noise(u * 18.3)) > 0.82 { turns *= 2 }
            var bulge = 0.35 + 0.65 * abs(noise(u * 19.1))

            if i >= 562 && i < 652 {
                // Cœur : petit rayon, enroulement discret.
                orbit = Self.orbR * 0.5 * pow(abs(noise(u * 4.5)), 0.6)
                size *= 0.7
                bright *= 0.7
                bulge = 0.15
            } else if i >= 652 && i < 732 {
                // Gerbes polaires : cônes serrés haut et bas, plus vifs.
                orbit = Self.orbR * (1.0 + 0.35 * abs(noise(u * 4.7)))
                bright *= 1.35
            } else if i >= 732 {
                // Fil : il rejoindra la tresse, plus fin.
                size *= 0.75
                riseTop = 0.14 + 0.10 * abs(noise(u * 8.1))
                stagIn = 0.3 + 0.5 * abs(noise(u * 8.3))
                bulge = 0.5
            }
            if i < 2 {
                // Les yeux : ils partent en DERNIER, glissent sans tourbillon —
                // deux braises qui traversent calmement le chaos.
                start = CGPoint(x: i == 0 ? 0.365 : 0.635, y: 0.485)
                bright = 1.6
                size = 2.2
                stagIn = 0.92
                riseTop = 0.19
                turns = 0
                bulge = 0.10
            }
            return Grain(
                startImp: start,
                phi: phi,
                theta0: Double(noise(u * 8.7)) * .pi,
                omega: (0.10 + 0.25 * Double(abs(noise(u * 10.1))))
                    * (noise(u * 11.3) > 0 ? 1 : -1),
                orbit: orbit,
                stagIn: stagIn,
                stagOut: abs(noise(u * 12.7)),
                riseTop: riseTop,
                unscrew: 1.2 + 1.4 * Double(abs(noise(u * 13.7))),
                swayFreq: 0.5 + 0.8 * Double(abs(noise(u * 14.1))),
                phase: Double(abs(noise(u * 15.7))) * 6.28,
                size: size,
                bright: bright,
                hero: hero,
                straggler: straggler,
                turns: turns,
                bulge: bulge
            )
        }
    }()

    /// La dentelle électrique : 7 filaments × 4 variantes en MARCHE ALÉATOIRE
    /// (les micro-angles SONT l'électricité), chacun avec 2 branches filles
    /// qui jaillissent vers l'extérieur. Redessinée 8 fois par seconde.
    struct LaceVariant {
        let main: [CGPoint]
        let branches: [[CGPoint]]
    }

    static let lace: [[LaceVariant]] = {
        let noise = InkNoise(seed: 173)
        var filaments: [[LaceVariant]] = []
        for f in 0..<7 {
            var variants: [LaceVariant] = []
            for v in 0..<4 {
                let u = CGFloat(f * 17 + v * 5)
                let direction: Double = noise(u * 2.1) > 0 ? 1 : -1
                let steps = 10 + Int(abs(noise(u * 3.3)) * 6)
                var angle = Double(noise(u * 1.3)) * .pi * 2
                var points: [CGPoint] = []
                var angles: [Double] = []
                for k in 0...steps {
                    let kk = CGFloat(k) / CGFloat(steps)
                    let radius = 1 + 0.04 * noise(u * 7.7 + CGFloat(k) * 2.3)
                        + 0.12 * sin(.pi * kk) * abs(noise(u * 5.1))
                    points.append(CGPoint(x: CGFloat(cos(angle)) * radius,
                                          y: CGFloat(sin(angle)) * radius))
                    angles.append(angle)
                    angle += direction * (0.11 + 0.05 * Double(abs(noise(u * 9.3 + CGFloat(k)))))
                        + 0.065 * Double(noise(u * 11.1 + CGFloat(k) * 3.1))
                }
                // Les branches filles : elles décollent du parent et MONTENT
                // en rayon (vers 1.10-1.22) — les gerbes de l'orbe.
                var branches: [[CGPoint]] = []
                for b in 0..<2 {
                    let bu = u + CGFloat(b) * 31 + 7
                    let k0 = Int(CGFloat(steps) * (0.30 + 0.40 * abs(noise(bu * 1.9))))
                    var bAngle = angles[min(k0, angles.count - 1)]
                    let bDir: Double = noise(bu * 2.7) > 0 ? 1 : -1
                    let bSteps = 4 + Int(abs(noise(bu * 3.9)) * 3)
                    var bRadius = 1 + 0.04 * noise(u * 7.7 + CGFloat(k0) * 2.3)
                    var bPoints: [CGPoint] = [points[min(k0, points.count - 1)]]
                    for kb in 0..<bSteps {
                        bAngle += bDir * (0.08 + 0.04 * Double(abs(noise(bu * 5.3 + CGFloat(kb)))))
                        bRadius += (0.10 + 0.12 * abs(noise(bu * 6.1))) / CGFloat(bSteps)
                        bPoints.append(CGPoint(x: CGFloat(cos(bAngle)) * bRadius,
                                               y: CGFloat(sin(bAngle)) * bRadius))
                    }
                    branches.append(bPoints)
                }
                variants.append(LaceVariant(main: points, branches: branches))
            }
            filaments.append(variants)
        }
        return filaments
    }()

    var body: some View {
        Canvas { context, size in
            guard dissolve > 0.001 else { return }
            let w = size.width, h = size.height
            let impTopY = 0.945 - Self.impSideH
            let orbFade = 1 - smoothstep(disperse / 0.55)
            let orbAlpha = Double(dissolve * orbFade)
            // La seconde inspiration, juste avant l'envol.
            let inhale = span(t, 5.95, 0.12, 6.18, 0.22)
            let radiusScale = 1 - 0.10 * inhale
            let brightScale = 1 + 0.35 * Double(inhale)
            let center = CGPoint(x: w * 0.5, y: h * Self.orbCenterY)

            // Le cœur voilé : trois disques, jamais cramés.
            if orbAlpha > 0.01 {
                context.drawLayer { layer in
                    layer.addFilter(.blur(radius: 10))
                    layer.fill(Path(ellipseIn: CGRect(x: center.x - w * 0.065 * radiusScale,
                                                      y: center.y - w * 0.062 * radiusScale,
                                                      width: w * 0.13 * radiusScale,
                                                      height: w * 0.124 * radiusScale)),
                               with: .color(Color.lunar.opacity(0.07 * orbAlpha)))
                }
                context.drawLayer { layer in
                    layer.addFilter(.blur(radius: 5))
                    layer.fill(Path(ellipseIn: CGRect(x: center.x - w * 0.035 * radiusScale,
                                                      y: center.y - w * 0.033 * radiusScale,
                                                      width: w * 0.07 * radiusScale,
                                                      height: w * 0.066 * radiusScale)),
                               with: .color(Color.lunar.opacity(0.12 * orbAlpha)))
                }
                // LE NOYAU : cramé. Un orbe sans cœur blanc n'est pas une
                // source, c'est une décoration. Il s'allume quand la sphère
                // se referme — et FLASHE à l'instant où elle se scelle :
                // l'événement lumineux global (voile, poche, arêtes suivent
                // via beat.flash, calé sur le même instant).
                let nucleusK = Double(smoothstep((dissolve - 0.55) / 0.35))
                let flare = Double(span(t, 5.30, 0.10, 5.65, 0.45))
                if nucleusK > 0.01 {
                    let burst = w * (0.030 + 0.055 * flare)
                    context.drawLayer { layer in
                        layer.addFilter(.blur(radius: 9))
                        layer.fill(Path(ellipseIn: CGRect(x: center.x - burst, y: center.y - burst,
                                                          width: burst * 2, height: burst * 2)),
                                   with: .color(.white.opacity((0.30 + 0.50 * flare) * nucleusK * orbAlpha)))
                    }
                    context.drawLayer { layer in
                        layer.addFilter(.blur(radius: 1.5))
                        layer.fill(Path(ellipseIn: CGRect(x: center.x - w * 0.016, y: center.y - w * 0.015,
                                                          width: w * 0.032, height: w * 0.030)),
                                   with: .color(.white.opacity(0.95 * nucleusK * orbAlpha)))
                    }
                    context.fill(Path(ellipseIn: CGRect(x: center.x - w * 0.007, y: center.y - w * 0.0065,
                                                        width: w * 0.014, height: w * 0.013)),
                                 with: .color(.white.opacity(nucleusK * orbAlpha)))
                }

                // La dentelle : 4-5 filaments allumés sur 7, variante qui
                // change 8×/s — l'éclair, pas le compas.
                let variantIndex = Int(t * 8) % 4
                let laceNoise = InkNoise(seed: 179)
                for f in 0..<7 {
                    let flick = pow(max(0, sin(t * (0.9 + Double(abs(laceNoise(CGFloat(f) * 3.1))))
                                              + Double(f) * 1.9)), 2.5)
                    guard flick > 0.05 else { continue }
                    let variant = Self.lace[f][variantIndex]
                    // La dentelle rampe SUR LA FACE de la sphère (rayon
                    // 0,60-0,92), jamais pile au limbe : c'est la densité qui
                    // dessine la frontière, pas un cercle tracé. Les branches
                    // filles, elles, s'éjectent au-delà — les gerbes.
                    let face = 0.60 + 0.32 * CGFloat(abs(laceNoise(CGFloat(f) * 7.7)))
                    func mapped(_ units: [CGPoint]) -> Path {
                        var path = Path()
                        for (k, unit) in units.enumerated() {
                            let point = CGPoint(
                                x: center.x + unit.x * Self.orbR * face * radiusScale * w,
                                y: center.y + unit.y * Self.orbR * face * radiusScale * w * 0.92)
                            if k == 0 { path.move(to: point) } else { path.addLine(to: point) }
                        }
                        return path
                    }
                    let main = mapped(variant.main)
                    // La gaine floue, puis le cœur vif — jamais un trait sec.
                    context.drawLayer { layer in
                        layer.addFilter(.blur(radius: 2.5))
                        layer.stroke(main, with: .color(.white.opacity(0.18 * orbAlpha * flick)),
                                     style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    }
                    context.stroke(main, with: .color(.white.opacity(0.95 * orbAlpha * flick)),
                                   style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
                    for branch in variant.branches {
                        let bp = mapped(branch)
                        context.stroke(bp, with: .color(.white.opacity(0.8 * orbAlpha * flick)),
                                       style: StrokeStyle(lineWidth: 0.5, lineCap: .round))
                        // La pointe de la branche : un éclat.
                        if flick > 0.5, let tipUnit = branch.last {
                            let tp = CGPoint(x: center.x + tipUnit.x * Self.orbR * face * radiusScale * w,
                                             y: center.y + tipUnit.y * Self.orbR * face * radiusScale * w * 0.92)
                            context.fill(Path(ellipseIn: CGRect(x: tp.x - 1.1, y: tp.y - 1.1,
                                                                width: 2.2, height: 2.2)),
                                         with: .color(.white.opacity(orbAlpha * flick)))
                        }
                    }
                }
            }

            // Les grains.
            for (i, grain) in Self.grains.enumerated() {
                // Le pelage s'étale : des vagues d'écorçage, pas un départ
                // groupé — la moitié de la beauté est dans l'inégalité.
                let condenseK = smoothstep((dissolve - grain.stagIn * 0.45) / 0.55)
                guard condenseK > 0.001 else { continue }
                // easeInOutCubic : le grain accélère, PLANE à mi-vol (c'est
                // là que le ruban et la traînée existent), puis se pose.
                func ease(_ k: CGFloat) -> CGFloat {
                    k < 0.5 ? 4 * k * k * k : 1 - pow(-2 * k + 2, 3) / 2
                }
                let condense = ease(condenseK)

                let startX = (0.5 + (grain.startImp.x - 0.5) * Self.impSide) * w
                let startY = (impTopY + grain.startImp.y * Self.impSideH) * h

                // La sphère : projection 3D, rotation propre.
                let theta = grain.theta0 + t * grain.omega
                let sinPhi = sin(grain.phi)
                let x3 = CGFloat(sinPhi) * CGFloat(cos(theta))
                let z3 = CGFloat(sinPhi) * CGFloat(sin(theta))
                let y3 = CGFloat(cos(grain.phi))
                var targetX = center.x + x3 * grain.orbit * radiusScale * w
                var targetY = center.y + y3 * grain.orbit * radiusScale * w * 0.92
                let backFace = z3 < 0

                // Gerbes polaires : plaquées vers les pôles.
                if i >= 652 && i < 732 {
                    let pole: CGFloat = i % 2 == 0 ? -1 : 1
                    targetX = center.x + x3 * grain.orbit * 0.22 * w
                    targetY = center.y + pole * grain.orbit * (1.05 + 0.85 * abs(y3)) * w * 0.92
                }

                // LE MORPHISME : jamais une droite. Chaque grain s'enroule
                // autour d'un pivot qui migre du cœur du corps vers le cœur
                // de l'orbe ; les grains d'une même nappe tournent ensemble —
                // le corps se délite en rubans qui se tordent, gonflent à
                // mi-vol, et se referment en sphère. `turns` est entier :
                // chaque grain arrive exactement sur sa place.
                let bodyCX = w * 0.5
                let bodyCY = (impTopY + 0.55 * Self.impSideH) * h
                let a0 = Double(atan2(startY - bodyCY, startX - bodyCX))
                let r0 = Double(hypot(startX - bodyCX, startY - bodyCY))
                let a1 = Double(atan2(targetY - center.y, targetX - center.x))
                let r1 = Double(hypot(targetX - center.x, targetY - center.y))
                var deltaA = a1 - a0
                deltaA = atan2(sin(deltaA), cos(deltaA))
                let sweep = deltaA + grain.turns * 2 * .pi
                func vortex(_ k: CGFloat) -> CGPoint {
                    let kk = Double(k)
                    let angle = a0 + sweep * kk
                    let inflate = 1 + Double(grain.bulge) * 0.55 * sin(.pi * kk)
                    let radius = (r0 + (r1 - r0) * kk) * inflate
                    return CGPoint(
                        x: bodyCX + (center.x - bodyCX) * k + CGFloat(cos(angle) * radius),
                        y: bodyCY + (center.y - bodyCY) * k + CGFloat(sin(angle) * radius))
                }
                let head = vortex(condense)
                var x = head.x
                var y = head.y

                // L'envol : fenêtre courte, stagger long — l'inégalité est la vie.
                let release = clamp01((disperse - grain.stagOut * 0.65) / 0.35)
                var alphaMul: Double = 1
                if release > 0.001 {
                    let rise = 1 - pow(2, -8 * Double(release))
                    let top = grain.straggler
                        ? Self.orbCenterY - (Self.orbCenterY - grain.riseTop) * 0.45
                        : grain.riseTop
                    y -= (targetY - top * h) * CGFloat(rise)
                    // Dévissage : la spirale s'ouvre en montant.
                    let beta = grain.unscrew * rise
                    let spin = CGFloat(cos(theta + beta)) * grain.orbit * w
                    x = center.x + (spin + (x - center.x) * 0.2) * (1 + CGFloat(rise) * 2.2)
                        + CGFloat(sin(t * grain.swayFreq + grain.phase)) * 0.015 * w * (1 + CGFloat(rise) * 2)
                    if grain.straggler {
                        alphaMul = Double(1 - smoothstep((CGFloat(release) - 0.45) / 0.15))
                    }
                }

                let twinkle = 0.35 + 0.65 * pow(0.5 + 0.5 * sin(t * grain.swayFreq * 2.4 + grain.phase), 2)
                var alpha = Double(condense) * twinkle * grain.bright * brightScale * alphaMul
                    * Double(pow(1 - release, 0.6))
                if backFace && release < 0.3 { alpha *= 0.28 }
                // Les derniers éclats : les héros flashent en mourant.
                if grain.hero, release > 0.82, release < 0.92 {
                    alpha += Double(pow(sin((release - 0.82) / 0.10 * .pi), 2)) * 0.8
                }
                guard alpha > 0.01 else { continue }

                let radius = max(0.25, grain.size * (1 - 0.75 * CGFloat(release)))

                // LA TRAÎNÉE : en plein vol, le grain est un cheveu de
                // lumière — sa vitesse s'écrit dans le cadre. Longue à
                // mi-course, résorbée à l'arrivée : jamais un point téléporté.
                if release < 0.01, condense > 0.03, condense < 0.985 {
                    let trailK = sin(.pi * Double(condense))
                    if trailK > 0.05 {
                        let back = vortex(ease(max(0, condenseK - 0.085)))
                        var streak = Path()
                        streak.move(to: back)
                        streak.addLine(to: CGPoint(x: x, y: y))
                        context.stroke(
                            streak,
                            with: .color(.white.opacity(min(1, alpha) * 0.38 * trailK)),
                            style: StrokeStyle(lineWidth: max(0.3, radius * 0.6),
                                               lineCap: .round))
                    }
                }

                // L'auréole du grain, puis le grain net — deux passes, partout.
                if alpha > 0.04 {
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - radius * 3.2, y: y - radius * 3.2,
                                               width: radius * 6.4, height: radius * 6.4)),
                        with: .color(Color.lunar.opacity(min(1, alpha) * 0.11))
                    )
                }
                context.fill(
                    Path(ellipseIn: CGRect(x: x - radius, y: y - radius,
                                           width: radius * 2, height: radius * 2)),
                    with: .color(.white.opacity(min(1, alpha)))
                )
                if grain.hero, release < 0.5 {
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - radius * 2.25, y: y - radius * 2.25,
                                               width: radius * 4.5, height: radius * 4.5)),
                        with: .color(.white.opacity(min(1, alpha) * 0.07))
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .blendMode(.plusLighter)
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
        let ew = w * 0.135 * pop
        let eh = h * 0.182 * max(eyes, 0) * pop * squint
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
    /// La tresse : présence et hauteur de la colonne de magie.
    var wisp: CGFloat = 0
    var wispRise: CGFloat = 0
    /// La transmutation : 0 = trait d'encre à main levée, 1 = arête de verre
    /// physique. L'encre devient verre au moment de l'impact.
    var become: CGFloat = 0
    /// Présence de la nébuleuse derrière la bouteille.
    var nebula: CGFloat = 0
    /// La sortie : le corps condense en orbe de particules, qui s'égrène
    /// ensuite en lumière fine vers le haut du verre.
    var dissolve: CGFloat = 0
    var disperse: CGFloat = 0
    var fade: CGFloat = 0
    var blink: CGFloat = 0
    var eyesAlpha: CGFloat = 1
    /// Impulsion radiale donnée à la poussière au moment de l'impact.
    var impulse: CGFloat = 0
    /// Le flash d'événement : toute la scène répond à la transformation
    /// (voile, arêtes, miroir) — deux souffles, condensation puis envol.
    var flash: CGFloat = 0

    /// L'image finale, pour qui a désactivé les animations.
    static let resolved = SplashBeat(zoom: 1, camX: 0.5, camY: 0.5, ink: 1,
                                     impY: 0.945, appear: 1, squash: 1,
                                     glow: 0.72, settle: 1, wisp: 1, wispRise: 1, become: 1, nebula: 1)

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
        // La poussée finale : lente, continue — la caméra s'approche pendant
        // qu'il se transforme, et accompagne l'envol jusqu'au fondu.
        let endPush = ramp(t, 4.30, 2.80)
        let follow = ramp(t, 0.5, 1.0)
        let driftX = 0.0012 * (sin(t * 1.43) + 0.6 * sin(t * 2.17 + 1.3))
        let driftY = 0.0012 * (sin(t * 1.19 + 0.7) + 0.6 * sin(t * 1.87))
        beat.zoom = 1 + 23 * CGFloat(exp(-2.9 * t)) + 0.16 * push + 0.55 * endPush
        beat.camX = beat.pen.x + (0.5 - beat.pen.x) * follow + CGFloat(driftX)
        beat.camY = beat.pen.y + (0.5 - beat.pen.y) * follow + 0.16 * push
            + 0.21 * endPush + CGFloat(driftY)

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

        // La tresse naît de l'impact et grandit vers le col ; le clin d'œil
        // la fait pulser.
        beat.wisp = ramp(t, 2.62, 0.9)
        beat.wispRise = ramp(t, 2.62, 1.8)

        // La transmutation : à l'impact, le dessin prend vie — l'encre à main
        // levée se change en verre physique.
        beat.become = ramp(t, 2.52, 0.45)

        // La nébuleuse naît avec la bouteille, s'épanouit à l'impact.
        beat.nebula = clamp01((beat.ink - 0.5) / 0.4)
            * (0.30 + 0.70 * ramp(t, 2.52, 0.30))

        // La sortie : à 4,4 s son corps se dissout — les particules
        // condensent en orbe ; à 4,75 l'orbe s'égrène vers le haut du verre
        // en lumière très fine, pendant que la scène fond.
        // Le premier flash est l'ÉVÉNEMENT : il détone à l'instant précis où
        // la sphère se scelle (dissolve s'achève à 5,45) — bref, franc.
        beat.flash = 0.85 * span(t, 5.30, 0.10, 5.62, 0.45)
            + span(t, 6.02, 0.10, 6.45, 0.50)
        // La métamorphose prend SON temps : ~1 s d'écorçage et de rubans.
        beat.dissolve = ramp(t, 4.40, 1.05)
        beat.disperse = ramp(t, 6.10, 1.50)
        beat.eyesAlpha = 1 - ramp(t, 4.90, 0.30)
        beat.fade = ramp(t, 7.30, 0.70)
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
                let control = CGPoint(x: (origin.x + tip.x) / 2 + 38 * noise(CGFloat(i) * 7.3),
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
            // Petit dans son grand verre : c'est le rapport d'échelle qui
            // fait « précieux » — une petite créature dans une grande lumière.
            let side = w * 0.30
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

                // LE VOILE : la grande lumière derrière la bouteille. Il naît
                // avec le verre et s'intensifie quand l'orbe se forme —
                // pendant que le brasier du sol, lui, s'assombrit (croisé).
                Rectangle()
                    .fill(Color.white)
                    .visualEffect { content, proxy in
                        content.colorEffect(ShaderLibrary.lightVeil(
                            .float2(proxy.size), .float(Float(t)),
                            .float(Float(beat.become * (1 + 0.25 * beat.dissolve + 0.35 * beat.flash)))))
                    }
                    .frame(width: w * 2.6, height: h * 1.8)
                    .position(x: w / 2, y: h * 0.42)
                    .blendMode(.plusLighter)
                    .opacity(Double(scene))

                // LA POCHE D'OMBRE : le verre absorbe le contre-jour en
                // incidence rasante — l'intérieur reste plus sombre que le
                // voile, et tout ce que la bouteille contient (orbe, dentelle,
                // tresse) gagne son contraste contre elle. Elle naît avec le
                // verre et cède pendant le flash : la lumière inonde tout.
                Rectangle()
                    .fill(Color.white)
                    .visualEffect { content, proxy in
                        content.colorEffect(ShaderLibrary.glassPocket(
                            .float2(proxy.size), .float(Float(t)),
                            .float(Float(beat.become * (1 - 0.30 * beat.flash)))))
                    }
                    .mask(BottleInteriorShape())
                    .blendMode(.multiply)
                    .opacity(Double(scene))

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
                        .fill(Color.white.opacity(0.38))
                        .frame(width: w * 0.64, height: w * 0.30)
                        .blur(radius: 9)
                    Ellipse()
                        .fill(Color.white.opacity(1.0))
                        .frame(width: w * 0.22, height: w * 0.09)
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
                .opacity(Double(beat.glow * scene) * (0.95 + 0.4 * Double(beat.impulse))
                         * Double(1 - 0.5 * beat.dissolve))
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

                // LA COLONNE : la lumière monte derrière lui — cœur serré,
                // corps, jupe — fondue vers le haut. Son corps noir la
                // DÉCOUPE : c'est la découpe qui le silhouette.
                ZStack {
                    Capsule()
                        .fill(Color.white.opacity(0.70))
                        .frame(width: side * 0.07, height: h * 0.30)
                        .blur(radius: 3)
                    Ellipse()
                        .fill(Color.lunar.opacity(0.28))
                        .frame(width: w * 0.22, height: h * 0.30)
                        .blur(radius: 8)
                    Ellipse()
                        .fill(Color.lunar.opacity(0.10))
                        .frame(width: w * 0.36, height: h * 0.32)
                        .blur(radius: 14)
                }
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .white.opacity(0.12), location: 0.25),
                            .init(color: .white.opacity(0.28), location: 0.50),
                            .init(color: .white.opacity(0.55), location: 0.75),
                            .init(color: .white, location: 1.0)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .scaleEffect(x: 1 + 0.05 * CGFloat(sin(t * 0.27)), anchor: .bottom)
                .position(x: w * 0.5 + 2.2 * CGFloat(sin(t * 0.19)),
                          y: h * 0.945 - h * 0.155)
                .opacity(Double(beat.glow * scene) * Double(1 - 0.4 * beat.dissolve)
                         * (0.88 + 0.12 * sin(t * 0.41)))
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

                // La magie : la tresse qui s'élève de lui, la poussière en
                // suspension dans le verre, les étincelles au sol.
                WispBraid(t: t, alpha: beat.wisp * scene,
                          rise: beat.wispRise,
                          pulse: clamp01(beat.impulse + span(t, 3.70, 0.15, 4.05, 0.30)))
                    .mask(BottleInteriorShape())
                InteriorDust(t: t, alpha: beat.wisp * scene * beat.glow)
                    .mask(BottleInteriorShape())
                FloorSparkle(t: t, alpha: beat.glow * scene)

                if beat.dissolve > 0.001 {
                    ImpDissolve(t: t, dissolve: beat.dissolve,
                                disperse: beat.disperse, glow: beat.glow)
                        .mask(BottleInteriorShape())
                }

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
        // Le pli du miroir : la ligne d'horizon de la laque.
        let fold: CGFloat = 0.9525
        let flipScale: CGFloat = 0.92

        // Ce que le sol reflète : le brasier, l'OCCLUSION noire de la
        // silhouette (sans elle, pas de miroir physique), la lueur du
        // diablotin, le trait et les arêtes, la bande sombre du pied.
        let impSide = w * 0.46
        let mirrorSource = ZStack {
            Ellipse()
                .fill(Color.white.opacity(0.20 * Double(beat.glow)))
                .frame(width: w * 0.5, height: w * 0.2)
                .position(x: w * 0.49, y: h * 0.93)
                .blur(radius: 8)
            BottleInteriorShape()
                .fill(Color.black.opacity(0.50))
            Ellipse()
                .fill(Color.white.opacity(0.24 * Double(beat.glow)))
                .frame(width: w * 0.24, height: w * 0.10)
                .position(x: w * 0.5, y: h * 0.90)
                .blur(radius: 5)

            // Le diablotin lui-même : sa lueur, puis sa silhouette qui MORD
            // en noir dans le reflet lumineux — le signal du miroir physique.
            ImpBodyShape()
                .fill(Color.white)
                .blur(radius: 10)
                .frame(width: impSide, height: impSide)
                .position(x: w / 2, y: h * 0.945 - impSide / 2)
                .opacity(0.30 * Double(beat.glow) * Double(clamp01(1 - beat.dissolve * 1.15)))
            ImpBodyShape()
                .fill(Color.black.opacity(0.60))
                .frame(width: impSide, height: impSide)
                .position(x: w / 2, y: h * 0.945 - impSide / 2)
                .opacity(Double(clamp01(1 - beat.dissolve * 1.15)))

            // Et l'orbe pendant la transformation.
            if beat.dissolve > 0.001 {
                ImpDissolve(t: t, dissolve: beat.dissolve,
                            disperse: beat.disperse, glow: beat.glow)
                    .opacity(0.35)
            }
            BottleInk(progress: beat.ink, screen: 1,
                      bodyAlpha: 1 - 0.82 * beat.become)
            GlassEdges(t: t, glow: beat.glow, alpha: beat.become * 0.85)
            Rectangle()
                .fill(Color.black.opacity(0.45))
                .frame(width: w, height: h * 0.009)
                .position(x: w / 2, y: h * 0.9425)
                .blur(radius: 0.8)
        }

        // Masque EN ESPACE SOURCE (avant le flip) : le reflet couvre le tiers
        // bas de la bouteille, le plus dense près du pli.
        let sourceMask = LinearGradient(
            stops: [
                .init(color: .clear, location: 0.58),
                .init(color: .white.opacity(0.22), location: 0.72),
                .init(color: .white.opacity(0.45), location: 0.845),
                .init(color: .white.opacity(0.75), location: fold),
                .init(color: .white.opacity(0.82), location: 1.0)
            ],
            startPoint: .top, endPoint: .bottom
        )
        let sharpMask = LinearGradient(
            stops: [
                .init(color: .clear, location: 0.86),
                .init(color: .white, location: 0.875),
                .init(color: .white, location: 1.0)
            ],
            startPoint: .top, endPoint: .bottom
        )
        let flipOffset = (1 + flipScale) * (fold - 0.5) * h

        return ZStack {
            // Le reflet du VOILE dans la laque : le sol reflète d'abord la
            // lumière — le signal n°1 du miroir physique.
            Rectangle()
                .fill(Color.white)
                .visualEffect { content, proxy in
                    content.colorEffect(ShaderLibrary.lightVeil(
                        .float2(proxy.size), .float(Float(t)),
                        .float(Float(beat.become * (0.55 + 0.4 * beat.flash)))))
                }
                .frame(width: w * 2.6, height: h * 1.8)
                .scaleEffect(x: 1, y: -1)
                .position(x: w / 2, y: h * (2 * fold - 0.42))
                .blendMode(.plusLighter)
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: fold - 0.004),
                            .init(color: .white, location: fold + 0.01),
                            .init(color: .clear, location: min(1, fold + 0.38))
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )

            // Le corps du reflet : flou doux.
            mirrorSource
                .mask(sourceMask)
                .blur(radius: 1.8)
                .scaleEffect(x: 0.985, y: -flipScale)
                .offset(y: flipOffset)

            // Le net-au-contact : les arêtes seules, presque nettes, sur les
            // premiers points sous le pli — c'est LE signal de la laque.
            GlassEdges(t: t, glow: beat.glow, alpha: beat.become * 0.85)
                .mask(sharpMask)
                .blur(radius: 0.25)
                .opacity(0.55)
                .scaleEffect(x: 0.985, y: -flipScale)
                .offset(y: flipOffset)

            // La ligne de contact, et les flaques résiduelles divisées par 2.
            Ellipse()
                .stroke(Color.white.opacity(Double((0.30 + 0.45 * beat.glow) * scene)),
                        lineWidth: 0.7)
                .frame(width: w * 0.58, height: h * 0.014)
                .position(x: w / 2, y: h * 0.955)
                .blur(radius: 0.4)
                .blendMode(.plusLighter)
            Ellipse()
                .fill(Color.lunar.opacity(Double((0.012 + 0.04 * beat.glow) * scene)))
                .frame(width: w * 1.05, height: h * 0.05)
                .position(x: w / 2, y: h * 0.968)
                .blur(radius: 12)
            Ellipse()
                .fill(Color.lunar.opacity(Double((0.03 + 0.10 * beat.glow
                                                  + 0.35 * beat.impulse) * scene)))
                .frame(width: w * 0.5, height: h * 0.028)
                .position(x: w / 2, y: h * 0.962)
                .blur(radius: 9)
        }
        .opacity(Double(scene))
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
                .opacity(Double(0.08 + 0.15 * beat.glow))
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
            // Chaque strie a SA vie : inclinaison, hauteur, dérive latérale
            // et respiration propres — jamais trois verticales au garde-à-vous.
            Capsule()
                .fill(Color.white.opacity(0.10 + 0.09 * beat.glow))
                .frame(width: 0.7, height: h * 0.058)
                .rotationEffect(.degrees(1.6))
                .position(x: w * 0.452 + 0.9 * CGFloat(sin(t * 0.09 + 0.4)),
                          y: h * 0.201)
                .opacity(0.55 + 0.45 * sin(t * 0.5 + 1.2))
            Capsule()
                .fill(Color.white.opacity(0.22 + 0.18 * beat.glow))
                .frame(width: 1.0, height: h * 0.072)
                .rotationEffect(.degrees(-0.8))
                .position(x: w * 0.487 + 0.6 * CGFloat(sin(t * 0.13 + 2.8)),
                          y: h * 0.196)
                .opacity(0.75 + 0.25 * sin(t * 0.7 + 3.4))
            Capsule()
                .fill(Color.white.opacity(0.06 + 0.06 * beat.glow))
                .frame(width: 0.5, height: h * 0.044)
                .rotationEffect(.degrees(2.1))
                .position(x: w * 0.538 + 1.1 * CGFloat(sin(t * 0.07 + 5.0)),
                          y: h * 0.191)
                .opacity(0.45 + 0.55 * sin(t * 0.4 + 5.1))

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
            // Le halo-silhouette : SA forme exacte, dilatée en trois couches
            // de plus en plus douces — la lumière épouse ses cornes et ses
            // flancs au lieu d'être une forme posée derrière lui.
            if !ghost {
                ZStack {
                    ImpBodyShape()
                        .fill(Color.white)
                        .blur(radius: 4)
                        .opacity(0.45)
                    ImpBodyShape()
                        .fill(Color.white)
                        .blur(radius: 12)
                        .opacity(0.22)
                    ImpBodyShape()
                        .fill(Color.lunar)
                        .blur(radius: 28)
                        .opacity(0.08)
                }
                .blendMode(.plusLighter)
                .opacity(Double(beat.glow * scene)
                         * Double(1 - smoothstep((beat.dissolve - 0.05) / 0.45))
                         * (0.88 + 0.12 * sin(t * 0.47)))
            }

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

                // L'encre tourne encore : deux veines qui dérivent en lui —
                // la matière VIT, elle doit se voir.
                if !ghost {
                    InkVeinShape(phase: CGFloat(t) * 0.18, seed: 1.3)
                        .stroke(Color.lunar.opacity(0.060),
                                style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .blur(radius: 3)
                        .mask(ImpBodyShape())
                    InkVeinShape(phase: CGFloat(t) * 0.13 + 2, seed: 4.7)
                        .stroke(Color.lunar.opacity(0.048),
                                style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .blur(radius: 2.5)
                        .mask(ImpBodyShape())
                }

                // Le reflet sur le crâne : l'encre est encore humide — le
                // glacis qui fait TOURNER le noir en sphère. Il doit se LIRE :
                // c'est lui qui dit « obsidienne », pas « trou noir ».
                ImpBodyShape()
                    .fill(
                        RadialGradient(colors: [Color.lunar.opacity(0.16), .clear],
                                       center: UnitPoint(x: 0.42, y: 0.26),
                                       startRadius: 0, endRadius: side * 0.70)
                    )

                // Le Fresnel des flancs : l'obsidienne accroche le voile en
                // incidence rasante — deux lisières de sheen, l'une plus
                // faible (la clé est à gauche, l'écho à droite).
                if !ghost {
                    ImpBodyShape()
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.lunar.opacity(0.055), location: 0.0),
                                    .init(color: .clear, location: 0.22),
                                    .init(color: .clear, location: 0.78),
                                    .init(color: Color.lunar.opacity(0.035), location: 1.0)
                                ],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .opacity(Double(beat.glow))
                }

                // Le rebond : la lumière du sol remonte sur son ventre — sa
                // moitié basse baigne dans la lueur qu'il projette lui-même.
                if !ghost {
                    ImpBodyShape()
                        .fill(
                            RadialGradient(colors: [Color.lunar.opacity(0.24), .clear],
                                           center: UnitPoint(x: 0.5, y: 1.02),
                                           startRadius: 0, endRadius: side * 0.70)
                        )
                        .opacity(Double(beat.glow))
                }

                // La laque : une fenêtre de lumière déformée, posée sur la
                // courbe du crâne — c'est elle qui fait « sphère laquée ».
                if !ghost {
                    Ellipse()
                        .fill(
                            LinearGradient(colors: [Color.lunar.opacity(0.26), .clear],
                                           startPoint: .top, endPoint: .bottom)
                        )
                        .frame(width: side * 0.30, height: side * 0.13)
                        .rotationEffect(.degrees(-16))
                        .offset(x: -side * 0.11, y: -side * 0.16)
                        .blur(radius: 2)
                        .mask(ImpBodyShape())

                    // L'écho du spéculaire : une petite fenêtre secondaire à
                    // droite du crâne — deux accroches, jamais une seule.
                    Ellipse()
                        .fill(
                            LinearGradient(colors: [Color.lunar.opacity(0.13), .clear],
                                           startPoint: .top, endPoint: .bottom)
                        )
                        .frame(width: side * 0.14, height: side * 0.06)
                        .rotationEffect(.degrees(12))
                        .offset(x: side * 0.16, y: -side * 0.13)
                        .blur(radius: 1.8)
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
                        .opacity(Double(0.45 + 0.45 * beat.glow))
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
            // L'ÉCORÇAGE : le corps tient pendant que les premières nappes
            // se déchirent de sa surface — le chevauchement fait le délitage,
            // pas un fondu. Il ne disparaît qu'aux deux tiers du morphisme.
            .opacity(Double(scene) * Double(1 - smoothstep((beat.dissolve - 0.18) / 0.55)))

            if !ghost {
                ImpCorona(t: t,
                          alpha: smoothstep((beat.settle - 0.25) / 0.3) * beat.glow,
                          pulse: clamp01(beat.wink + beat.impulse))
                    .opacity(Double(scene) * Double(1 - smoothstep((beat.dissolve - 0.05) / 0.45)))
            }

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

            // La polarité : contre le voile lumineux, l'arête haute se
            // découpe en NOIR — c'est la signature de la photo de référence.
            GlassDarkEdge(alpha: beat.become)

            // Les arêtes : blooms masqués dedans, cheveux jumeaux dessus —
            // et elles flarent au moment de la transformation.
            GlassEdges(t: t, glow: beat.glow,
                       alpha: beat.become * (1 + 0.30 * beat.flash))

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
    @State private var dissolved = false
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
        .sensoryFeedback(.impact(weight: .light, intensity: 0.35), trigger: dissolved)
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

            // Les grandes volutes : la fumée cosmique qui monte le long des
            // flancs — c'est elle qui donne au verre un monde à refléter.
            Rectangle()
                .fill(Color.white)
                .visualEffect { content, proxy in
                    content.colorEffect(ShaderLibrary.cosmosWisps(
                        .float(Float(t)), .float2(proxy.size)))
                }
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
        try? await Task.sleep(for: .seconds(0.72))
        dissolved = true
        try? await Task.sleep(for: .seconds(3.75))
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
