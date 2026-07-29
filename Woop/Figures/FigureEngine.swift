import SwiftUI

// MARK: - Pose

/// Squelette d'une silhouette féminine minimaliste, en coordonnées normalisées (0…1, y vers le bas).
/// Deux poses interpolées suffisent à décrire un mouvement de musculation.
struct FigurePose {
    var head = CGPoint(x: 0.50, y: 0.16)
    var headRadius: CGFloat = 0.058
    var neck = CGPoint(x: 0.50, y: 0.235)
    var chest = CGPoint(x: 0.505, y: 0.315)
    var waist = CGPoint(x: 0.498, y: 0.405)
    var hip = CGPoint(x: 0.50, y: 0.475)

    var shoulder = CGPoint(x: 0.50, y: 0.258)
    var elbowNear = CGPoint(x: 0.548, y: 0.352)
    var handNear = CGPoint(x: 0.578, y: 0.445)
    var elbowFar = CGPoint(x: 0.455, y: 0.352)
    var handFar = CGPoint(x: 0.432, y: 0.445)

    var kneeNear = CGPoint(x: 0.527, y: 0.655)
    var ankleNear = CGPoint(x: 0.527, y: 0.855)
    var kneeFar = CGPoint(x: 0.473, y: 0.655)
    var ankleFar = CGPoint(x: 0.473, y: 0.855)

    /// Direction de la queue de cheval, relative à la tête.
    var ponytail = CGPoint(x: -0.075, y: 0.055)

    static func lerp(_ a: FigurePose, _ b: FigurePose, _ t: CGFloat) -> FigurePose {
        func p(_ x: CGPoint, _ y: CGPoint) -> CGPoint {
            CGPoint(x: x.x + (y.x - x.x) * t, y: x.y + (y.y - x.y) * t)
        }
        var out = FigurePose()
        out.head = p(a.head, b.head)
        out.headRadius = a.headRadius + (b.headRadius - a.headRadius) * t
        out.neck = p(a.neck, b.neck)
        out.chest = p(a.chest, b.chest)
        out.waist = p(a.waist, b.waist)
        out.hip = p(a.hip, b.hip)
        out.shoulder = p(a.shoulder, b.shoulder)
        out.elbowNear = p(a.elbowNear, b.elbowNear)
        out.handNear = p(a.handNear, b.handNear)
        out.elbowFar = p(a.elbowFar, b.elbowFar)
        out.handFar = p(a.handFar, b.handFar)
        out.kneeNear = p(a.kneeNear, b.kneeNear)
        out.ankleNear = p(a.ankleNear, b.ankleNear)
        out.kneeFar = p(a.kneeFar, b.kneeFar)
        out.ankleFar = p(a.ankleFar, b.ankleFar)
        out.ponytail = p(a.ponytail, b.ponytail)
        return out
    }
}

// MARK: - Matériel

/// À quel point du corps la poignée de poulie est attachée.
enum CableAttach {
    case nearHand, farHand, bothHands, nearAnkle
}

/// Le décor autour de la silhouette : poulie, machine, tapis. Dessiné plus discrètement que le corps.
enum FigureEquipment {
    case none
    /// Poulie reliée au corps. `anchor` en coordonnées normalisées.
    case cable(anchor: CGPoint, attach: CableAttach)
    case benchHipThrust
    case crunchMachine
    case treadmill
    case stairs
}

// MARK: - Échantillonnage

/// Échantillonne une courbe quadratique en une polyligne.
private func sampleQuad(_ a: CGPoint, _ control: CGPoint, _ b: CGPoint,
                        steps: Int = 10) -> [CGPoint] {
    (0...steps).map { step in
        let t = CGFloat(step) / CGFloat(steps)
        let u = 1 - t
        return CGPoint(
            x: u * u * a.x + 2 * u * t * control.x + t * t * b.x,
            y: u * u * a.y + 2 * u * t * control.y + t * t * b.y
        )
    }
}

// MARK: - Squelette échantillonné

/// Une portion du corps sous forme de polyligne normalisée, avec sa largeur
/// locale : c'est le rail sur lequel les poussières s'accrochent.
private struct BodySegment {
    var points: [CGPoint]
    var widths: [CGFloat]
    var far: Bool
}

/// Subdivise une polyligne en interpolant linéairement points et largeurs.
private func densify(_ points: [CGPoint], _ widths: [CGFloat], per: Int) -> ([CGPoint], [CGFloat]) {
    var outP: [CGPoint] = []
    var outW: [CGFloat] = []
    for i in 0..<(points.count - 1) {
        for s in 0..<per {
            let t = CGFloat(s) / CGFloat(per)
            outP.append(CGPoint(x: points[i].x + (points[i + 1].x - points[i].x) * t,
                                y: points[i].y + (points[i + 1].y - points[i].y) * t))
            outW.append(widths[i] + (widths[i + 1] - widths[i]) * t)
        }
    }
    outP.append(points[points.count - 1])
    outW.append(widths[widths.count - 1])
    return (outP, outW)
}

private func widthRamp(_ from: CGFloat, _ mid: CGFloat, _ to: CGFloat, count: Int) -> [CGFloat] {
    (0..<count).map { index in
        let t = CGFloat(index) / CGFloat(max(count - 1, 1))
        return t < 0.5 ? from + (mid - from) * (t * 2)
                       : mid + (to - mid) * ((t - 0.5) * 2)
    }
}

/// Découpe une pose en segments. L'ordre est fixe : les particules mémorisent
/// leur index de segment et retrouvent leur membre à chaque image.
private func bodySegments(_ p: FigurePose) -> [BodySegment] {
    var segs: [BodySegment] = []

    // 0 — tête : une spirale resserrée, pour que les grains remplissent le
    // disque au lieu de dessiner un anneau vide.
    let headSteps = 22
    let headPts = (0...headSteps).map { i -> CGPoint in
        let t = CGFloat(i) / CGFloat(headSteps)
        let a = t * 4 * .pi
        let r = p.headRadius * (0.15 + 0.65 * t)
        return CGPoint(x: p.head.x + cos(a) * r,
                       y: p.head.y + sin(a) * r * 1.12)
    }
    segs.append(BodySegment(points: headPts,
                            widths: Array(repeating: p.headRadius * 0.75, count: headPts.count),
                            far: false))

    // 1 — queue de cheval, effilée
    let tailA = CGPoint(x: p.head.x + p.ponytail.x * 0.32, y: p.head.y + p.ponytail.y * 0.22)
    let tailB = CGPoint(x: p.head.x + p.ponytail.x, y: p.head.y + p.ponytail.y)
    let tailC = CGPoint(x: tailA.x + (tailB.x - tailA.x) * 0.25,
                        y: tailA.y + (tailB.y - tailA.y) * 1.15)
    let tailPts = sampleQuad(tailA, tailC, tailB, steps: 8)
    segs.append(BodySegment(points: tailPts,
                            widths: widthRamp(0.028, 0.020, 0.006, count: tailPts.count),
                            far: false))

    // 2 — buste : épaules, taille marquée, hanches pleines
    let (torsoP, torsoW) = densify([p.neck, p.chest, p.waist, p.hip],
                                   [0.048, 0.082, 0.055, 0.090], per: 5)
    segs.append(BodySegment(points: torsoP, widths: torsoW, far: false))

    // 3/4 — bras et jambe proches
    let armN = sampleQuad(p.shoulder, p.elbowNear, p.handNear, steps: 12)
    segs.append(BodySegment(points: armN, widths: widthRamp(0.032, 0.024, 0.014, count: armN.count), far: false))
    let legN = sampleQuad(p.hip, p.kneeNear, p.ankleNear, steps: 12)
    segs.append(BodySegment(points: legN, widths: widthRamp(0.048, 0.032, 0.017, count: legN.count), far: false))

    // 5/6 — pieds
    for ankle in [p.ankleNear, p.ankleFar] {
        segs.append(BodySegment(points: [ankle, CGPoint(x: ankle.x + 0.040, y: ankle.y + 0.004)],
                                widths: [0.016, 0.010],
                                far: ankle == p.ankleFar))
    }

    // 7/8 — membres éloignés, plus discrets
    let armF = sampleQuad(p.shoulder, p.elbowFar, p.handFar, steps: 12)
    segs.append(BodySegment(points: armF, widths: widthRamp(0.030, 0.022, 0.013, count: armF.count), far: true))
    let legF = sampleQuad(p.hip, p.kneeFar, p.ankleFar, steps: 12)
    segs.append(BodySegment(points: legF, widths: widthRamp(0.044, 0.029, 0.016, count: legF.count), far: true))

    return segs
}

/// Contour galbé d'un segment, en pixels : la largeur varie le long de la
/// polyligne. C'est lui qui rend la silhouette immédiatement humaine.
private func taperedPath(_ seg: BodySegment, in rect: CGRect) -> Path {
    let scale = min(rect.width, rect.height)
    let pts = seg.points.map { CGPoint(x: rect.minX + $0.x * rect.width,
                                       y: rect.minY + $0.y * rect.height) }
    guard pts.count >= 2 else { return Path() }

    var left: [CGPoint] = []
    var right: [CGPoint] = []
    for (index, point) in pts.enumerated() {
        let previous = pts[max(index - 1, 0)]
        let next = pts[min(index + 1, pts.count - 1)]
        var dx = next.x - previous.x
        var dy = next.y - previous.y
        let length = max(sqrt(dx * dx + dy * dy), 0.0001)
        dx /= length; dy /= length
        let half = seg.widths[index] * scale / 2
        left.append(CGPoint(x: point.x - dy * half, y: point.y + dx * half))
        right.append(CGPoint(x: point.x + dy * half, y: point.y - dx * half))
    }
    var path = Path()
    path.move(to: left[0])
    for point in left.dropFirst() { path.addLine(to: point) }
    for point in right.reversed() { path.addLine(to: point) }
    path.closeSubpath()
    return path
}

/// Position, normale et largeur locale à `t` (0…1) le long d'un segment.
private func samplePoint(_ seg: BodySegment, _ t: CGFloat) -> (pos: CGPoint, normal: CGVector, width: CGFloat) {
    let n = seg.points.count
    let x = min(max(t, 0), 1) * CGFloat(n - 1)
    let i = min(Int(x), n - 2)
    let f = x - CGFloat(i)
    let a = seg.points[i], b = seg.points[i + 1]
    let pos = CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f)
    var dx = b.x - a.x, dy = b.y - a.y
    let len = max(sqrt(dx * dx + dy * dy), 0.0001)
    dx /= len; dy /= len
    let w = seg.widths[i] + (seg.widths[i + 1] - seg.widths[i]) * f
    return (pos, CGVector(dx: -dy, dy: dx), w)
}

// MARK: - Matériel dessiné

struct EquipmentShape: Shape {
    var equipment: FigureEquipment
    var pose: FigurePose
    var target: FigurePose
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let p = FigurePose.lerp(pose, target, progress)
        func pt(_ n: CGPoint) -> CGPoint {
            CGPoint(x: rect.minX + n.x * rect.width, y: rect.minY + n.y * rect.height)
        }
        let scale = min(rect.width, rect.height)
        var path = Path()

        switch equipment {
        case .none:
            break

        case .cable(let anchor, let attach):
            let a = pt(anchor)
            let targets: [CGPoint] = {
                switch attach {
                case .nearHand: return [pt(p.handNear)]
                case .farHand: return [pt(p.handFar)]
                case .bothHands: return [pt(p.handNear), pt(p.handFar)]
                case .nearAnkle: return [pt(p.ankleNear)]
                }
            }()
            // Montant de la poulie
            path.move(to: CGPoint(x: a.x, y: rect.maxY))
            path.addLine(to: CGPoint(x: a.x, y: rect.minY + rect.height * 0.06))
            // Poulie
            let r = scale * 0.026
            path.addEllipse(in: CGRect(x: a.x - r, y: a.y - r, width: r * 2, height: r * 2))
            // Câbles, avec une légère détente
            for end in targets {
                path.move(to: a)
                path.addQuadCurve(
                    to: end,
                    control: CGPoint(x: (a.x + end.x) / 2, y: (a.y + end.y) / 2 + scale * 0.03)
                )
            }

        case .benchHipThrust:
            let y = rect.minY + rect.height * 0.46
            path.move(to: CGPoint(x: rect.minX + rect.width * 0.12, y: y))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.44, y: y))
            path.move(to: CGPoint(x: rect.minX + rect.width * 0.16, y: y))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.16, y: rect.maxY * 0.94))
            path.move(to: CGPoint(x: rect.minX + rect.width * 0.40, y: y))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.40, y: rect.maxY * 0.94))
            // Barre sur les hanches
            let hp = pt(p.hip)
            let r = scale * 0.042
            path.addEllipse(in: CGRect(x: hp.x - r, y: hp.y - r * 1.25, width: r * 2, height: r * 2))

        case .crunchMachine:
            // Dossier incliné + coussin d'épaules
            path.move(to: CGPoint(x: rect.minX + rect.width * 0.30, y: rect.minY + rect.height * 0.88))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.minY + rect.height * 0.30))
            path.move(to: CGPoint(x: rect.minX + rect.width * 0.24, y: rect.minY + rect.height * 0.88))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.62, y: rect.minY + rect.height * 0.88))
            let sh = pt(p.shoulder)
            path.move(to: CGPoint(x: sh.x - scale * 0.09, y: sh.y - scale * 0.03))
            path.addLine(to: CGPoint(x: sh.x + scale * 0.05, y: sh.y - scale * 0.03))

        case .treadmill:
            let deck = rect.minY + rect.height * 0.90
            path.move(to: CGPoint(x: rect.minX + rect.width * 0.14, y: deck))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.86, y: deck))
            // Rouleaux
            let r = scale * 0.022
            for x in [rect.minX + rect.width * 0.16, rect.minX + rect.width * 0.84] {
                path.addEllipse(in: CGRect(x: x - r, y: deck - r + scale * 0.02,
                                           width: r * 2, height: r * 2))
            }
            // Console
            path.move(to: CGPoint(x: rect.minX + rect.width * 0.80, y: deck))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.80, y: rect.minY + rect.height * 0.34))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.68, y: rect.minY + rect.height * 0.30))

        case .stairs:
            let stepW = rect.width * 0.13
            let stepH = rect.height * 0.10
            var x = rect.minX + rect.width * 0.12
            var y = rect.minY + rect.height * 0.92
            path.move(to: CGPoint(x: x, y: y))
            for _ in 0..<5 {
                y -= stepH
                path.addLine(to: CGPoint(x: x, y: y))
                x += stepW
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        return path
    }
}

// MARK: - Poussière cosmique

/// Générateur déterministe : le même semis de particules à chaque lancement,
/// pour que les figures ne « clignotent » pas d'une apparition à l'autre.
private struct SplitMix64 {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func unit() -> CGFloat { CGFloat(next() >> 11) / CGFloat(1 << 53) }
    mutating func range(_ lo: CGFloat, _ hi: CGFloat) -> CGFloat { lo + (hi - lo) * unit() }
}

/// Teinte d'une poussière : blanc pur, blanc glacé, ou soupçon de violet.
private enum DustTint {
    case white, ice, violet

    func color(_ opacity: CGFloat) -> Color {
        switch self {
        case .white: return .white.opacity(opacity)
        case .ice: return Color(red: 0.84, green: 0.89, blue: 1.0).opacity(opacity)
        case .violet: return Color(red: 0.72, green: 0.62, blue: 0.98).opacity(opacity * 0.8)
        }
    }
}

/// Une poussière accrochée au squelette : elle suit son membre pendant le
/// mouvement, scintille et dérive légèrement autour de sa position.
private struct StarDust {
    var segment: Int          // -1 = poussière libre autour de la silhouette
    var t: CGFloat            // position le long du segment (ou x si libre)
    var lateral: CGFloat      // écart perpendiculaire, -1…1 (ou y si libre)
    var size: CGFloat         // rayon du cœur, en fraction de l'échelle
    var brightness: CGFloat
    var tint: DustTint
    var isStar: Bool          // les rares grosses étoiles gardent un cœur net
    var twinklePhase: CGFloat
    var twinkleSpeed: CGFloat
    var driftPhase: CGFloat
    var driftSpeed: CGFloat
    var far: Bool
}

/// Semis unique : les poses partagent toutes le même squelette, la répartition
/// (calculée sur la pose par défaut) vaut donc pour tous les exercices.
private let cosmicDust: [StarDust] = {
    var rng = SplitMix64(state: 0x57_4F_4F_50)   // « WOOP »
    let segs = bodySegments(FigurePose())
    let bodyCount = 440

    // Densité surtout portée par la longueur : les membres fins doivent rester
    // lisibles, pas seulement le buste.
    let weights = segs.map { seg -> CGFloat in
        var len: CGFloat = 0
        for i in 0..<(seg.points.count - 1) {
            len += hypot(seg.points[i + 1].x - seg.points[i].x,
                         seg.points[i + 1].y - seg.points[i].y)
        }
        let avgW = seg.widths.reduce(0, +) / CGFloat(seg.widths.count)
        return len * (avgW * 1.5 + 0.024) * (seg.far ? 0.55 : 1.0)
    }
    let total = weights.reduce(0, +)

    var dust: [StarDust] = []
    for (index, seg) in segs.enumerated() {
        let count = max(3, Int(CGFloat(bodyCount) * weights[index] / total))
        for _ in 0..<count {
            // Écart latéral en cloche : le cœur du membre dense, les bords vaporeux.
            let lateral = (rng.unit() + rng.unit() + rng.unit()) / 1.5 - 1.0
            let star = rng.unit() < 0.07
            let tintRoll = rng.unit()
            dust.append(StarDust(
                segment: index,
                t: rng.unit(),
                lateral: lateral,
                size: star ? rng.range(0.0065, 0.0100) : rng.range(0.0024, 0.0056),
                brightness: star ? rng.range(0.85, 1.0) : rng.range(0.42, 0.9),
                tint: tintRoll < 0.78 ? .white : (tintRoll < 0.94 ? .ice : .violet),
                isStar: star,
                twinklePhase: rng.range(0, 2 * .pi),
                twinkleSpeed: rng.range(0.7, 2.3),
                driftPhase: rng.range(0, 2 * .pi),
                driftSpeed: rng.range(0.3, 0.9),
                far: seg.far
            ))
        }
    }

    // Poussière libre : quelques grains qui flottent autour du corps,
    // comme dans le ciel de l'app.
    for _ in 0..<26 {
        dust.append(StarDust(
            segment: -1,
            t: rng.range(0.14, 0.86),
            lateral: rng.range(0.10, 0.92),
            size: rng.range(0.0022, 0.0048),
            brightness: rng.range(0.10, 0.30),
            tint: rng.unit() < 0.8 ? .white : .ice,
            isStar: false,
            twinklePhase: rng.range(0, 2 * .pi),
            twinkleSpeed: rng.range(0.4, 1.1),
            driftPhase: rng.range(0, 2 * .pi),
            driftSpeed: rng.range(0.15, 0.45),
            far: false
        ))
    }
    return dust
}()

// MARK: - Vue composée

/// Dessin d'un exercice en mode cosmique : la silhouette est une constellation
/// de particules blanches en dégradé — denses et brillantes en haut, vaporeuses
/// vers le bas — qui suivent le squelette pendant le mouvement. Le matériel
/// reste un simple trait, en retrait.
struct ExerciseFigure: View {
    let design: FigureDesign
    var animated: Bool = false
    var lineWidth: CGFloat = 1.2

    @State private var appeared: CGFloat = 0

    var body: some View {
        Group {
            if animated {
                TimelineView(.animation) { timeline in
                    canvas(time: timeline.date.timeIntervalSinceReferenceDate)
                }
            } else {
                canvas(time: 0)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .opacity(appeared)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { appeared = 1 }
        }
    }

    private func canvas(time: TimeInterval) -> some View {
        Canvas(rendersAsynchronously: true) { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let scale = min(size.width, size.height)
            let pose = livePose(time)
            let segs = bodySegments(pose)

            // Matériel : trait blanc à peine posé, le décor ne rivalise pas
            // avec la constellation.
            let equipmentPath = EquipmentShape(equipment: design.equipment, pose: pose,
                                               target: pose, progress: 0)
                .path(in: rect)
            context.stroke(
                equipmentPath,
                with: .linearGradient(
                    Gradient(colors: [.white.opacity(0.16), .white.opacity(0.035)]),
                    startPoint: CGPoint(x: rect.midX, y: rect.minY),
                    endPoint: CGPoint(x: rect.midX, y: rect.maxY)
                ),
                style: StrokeStyle(lineWidth: max(lineWidth * 0.55, 0.7),
                                   lineCap: .round, lineJoin: .round)
            )

            // Voile corporel : la silhouette galbée remplie d'un blanc laiteux
            // à peine visible, adouci au flou. Les étoiles scintillent par-dessus,
            // mais c'est lui qu'on lit — une femme, pas un nuage.
            var veil = context
            veil.addFilter(.blur(radius: scale * 0.007))
            for (index, seg) in segs.enumerated() {
                let baseOpacity: CGFloat = seg.far ? 0.045 : 0.125
                let shading = GraphicsContext.Shading.linearGradient(
                    Gradient(colors: [.white.opacity(baseOpacity),
                                      .white.opacity(baseOpacity * 0.38)]),
                    startPoint: CGPoint(x: rect.midX, y: rect.minY),
                    endPoint: CGPoint(x: rect.midX, y: rect.maxY)
                )
                if index == 0 {
                    // La tête : un ovale plein, pas un anneau.
                    let rx = pose.headRadius * scale
                    let ry = rx * 1.12
                    let c = CGPoint(x: rect.minX + pose.head.x * rect.width,
                                    y: rect.minY + pose.head.y * rect.height)
                    veil.fill(Path(ellipseIn: CGRect(x: c.x - rx, y: c.y - ry,
                                                     width: rx * 2, height: ry * 2)),
                              with: shading)
                } else {
                    veil.fill(taperedPath(seg, in: rect), with: shading)
                }
            }

            // Sur les petites vignettes, on éclaircit le semis : moins de
            // grains, sinon tout se fond en tache.
            let stride = scale < 70 ? 3 : (scale < 150 ? 2 : 1)
            let sizeBoost = 0.72 + lineWidth * 0.22

            for (index, dust) in cosmicDust.enumerated() {
                if stride > 1 && index % stride != 0 { continue }

                var pos: CGPoint
                var opacity: CGFloat

                if dust.segment >= 0 {
                    guard dust.segment < segs.count else { continue }
                    let seg = segs[dust.segment]
                    let (anchor, normal, width) = samplePoint(seg, dust.t)
                    // Dérive perpendiculaire, très légère : la poussière respire
                    // sans quitter son membre.
                    let breathe = sin(time * dust.driftSpeed + dust.driftPhase) * 0.0035
                    let offset = dust.lateral * width * 0.46 + breathe
                    pos = CGPoint(x: rect.minX + (anchor.x + normal.dx * offset) * rect.width,
                                  y: rect.minY + (anchor.y + normal.dy * offset) * rect.height)
                    opacity = dust.brightness
                    if dust.far { opacity *= 0.38 }
                } else {
                    // Poussière libre : lente dérive elliptique autour de son point.
                    let x = dust.t + sin(time * dust.driftSpeed + dust.driftPhase) * 0.014
                    let y = dust.lateral + cos(time * dust.driftSpeed * 0.8 + dust.driftPhase) * 0.011
                    pos = CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
                    opacity = dust.brightness
                }

                // Dégradé vertical : blanc éclatant en haut, voile en bas.
                let yNorm = (pos.y - rect.minY) / max(rect.height, 1)
                opacity *= min(max(1.06 - 0.52 * yNorm, 0.32), 1.0)

                // Scintillement doux, jamais stroboscopique : la forme reste stable.
                opacity *= 0.80 + 0.20 * sin(time * dust.twinkleSpeed + dust.twinklePhase)
                if opacity <= 0.015 { continue }

                let r = dust.size * scale * sizeBoost
                let halo = r * (dust.isStar ? 2.9 : 2.1)

                // Un seul remplissage radial par grain : cœur lumineux,
                // halo qui s'évanouit — c'est ce qui rend l'étoile réaliste.
                let gradient = Gradient(stops: [
                    .init(color: dust.tint.color(opacity), location: 0),
                    .init(color: dust.tint.color(opacity * 0.32), location: 0.30),
                    .init(color: dust.tint.color(0), location: 1)
                ])
                context.fill(
                    Path(ellipseIn: CGRect(x: pos.x - halo, y: pos.y - halo,
                                           width: halo * 2, height: halo * 2)),
                    with: .radialGradient(gradient, center: pos,
                                          startRadius: 0, endRadius: halo)
                )
                if dust.isStar {
                    context.fill(
                        Path(ellipseIn: CGRect(x: pos.x - r * 0.45, y: pos.y - r * 0.45,
                                               width: r * 0.9, height: r * 0.9)),
                        with: .color(.white.opacity(min(opacity * 1.15, 1)))
                    )
                }
            }
        }
    }

    /// Progression d'une répétition, avec ce qui fait qu'un vrai mouvement ne
    /// ressemble pas à un métronome : un court maintien à la contraction et au
    /// relâchement, et un effort (aller) plus lent que le retour.
    /// `lagFraction` décale la phase — c'est ce qui crée la traîne des
    /// extrémités, en fraction de la durée d'une répétition.
    private func progressValue(_ time: TimeInterval, lagFraction: Double) -> CGFloat {
        let t = time - lagFraction * design.duration
        var cycle = (t / design.duration).truncatingRemainder(dividingBy: 2)
        if cycle < 0 { cycle += 2 }
        // L'aller occupe 54 % du cycle, le retour 46 %.
        let up = 1.08
        let raw = cycle < up ? cycle / up : 1 - (cycle - up) / (2 - up)
        // Maintien de ~9 % à chaque extrême : la contraction se tient.
        let hold = 0.09
        let u = min(max((raw - hold) / (1 - 2 * hold), 0), 1)
        return CGFloat(0.5 - 0.5 * cos(.pi * u))
    }

    /// Interpole un os en polaire autour de son articulation parente : l'angle
    /// tourne par le plus court chemin, la longueur reste quasi constante.
    /// C'est ce qui remplace l'étirement caoutchouc du lerp cartésien par un
    /// vrai pivot articulaire.
    private func boneMix(parentA: CGPoint, childA: CGPoint,
                         parentB: CGPoint, childB: CGPoint,
                         parentNow: CGPoint, _ t: CGFloat) -> CGPoint {
        let va = CGVector(dx: childA.x - parentA.x, dy: childA.y - parentA.y)
        let vb = CGVector(dx: childB.x - parentB.x, dy: childB.y - parentB.y)
        let lenA = hypot(va.dx, va.dy), lenB = hypot(vb.dx, vb.dy)
        let angA = atan2(va.dy, va.dx), angB = atan2(vb.dy, vb.dx)
        var delta = angB - angA
        while delta > .pi { delta -= 2 * .pi }
        while delta < -.pi { delta += 2 * .pi }
        let ang = angA + delta * t
        let len = lenA + (lenB - lenA) * t
        return CGPoint(x: parentNow.x + cos(ang) * len,
                       y: parentNow.y + sin(ang) * len)
    }

    /// Pose vivante. Le buste initie le mouvement ; coudes, mains, genoux,
    /// chevilles et queue de cheval suivent chacun avec leur retard — le
    /// follow-through des vrais corps. Les membres pivotent en arc autour de
    /// leurs articulations, et un balancement + une respiration imperceptibles
    /// habitent la figure même entre deux répétitions.
    private func livePose(_ time: TimeInterval) -> FigurePose {
        guard animated else { return design.start }

        let a = design.start, b = design.end

        func mix(_ x: CGPoint, _ y: CGPoint, _ t: CGFloat) -> CGPoint {
            CGPoint(x: x.x + (y.x - x.x) * t, y: x.y + (y.y - x.y) * t)
        }

        // Le tronc mène.
        var p = FigurePose.lerp(a, b, progressValue(time, lagFraction: 0))

        let headP = progressValue(time, lagFraction: 0.04)
        let tailP = progressValue(time, lagFraction: 0.10)
        let elbowP = progressValue(time, lagFraction: 0.025)
        let handP = progressValue(time, lagFraction: 0.05)
        let kneeP = progressValue(time, lagFraction: 0.02)
        let ankleP = progressValue(time, lagFraction: 0.04)

        p.head = mix(a.head, b.head, headP)
        p.ponytail = mix(a.ponytail, b.ponytail, tailP)

        // Bras : pivot épaule → coude, puis coude → main.
        p.elbowNear = boneMix(parentA: a.shoulder, childA: a.elbowNear,
                              parentB: b.shoulder, childB: b.elbowNear,
                              parentNow: p.shoulder, elbowP)
        p.handNear = boneMix(parentA: a.elbowNear, childA: a.handNear,
                             parentB: b.elbowNear, childB: b.handNear,
                             parentNow: p.elbowNear, handP)
        p.elbowFar = boneMix(parentA: a.shoulder, childA: a.elbowFar,
                             parentB: b.shoulder, childB: b.elbowFar,
                             parentNow: p.shoulder, elbowP)
        p.handFar = boneMix(parentA: a.elbowFar, childA: a.handFar,
                            parentB: b.elbowFar, childB: b.handFar,
                            parentNow: p.elbowFar, handP)

        // Jambes : pivot hanche → genou, puis genou → cheville.
        p.kneeNear = boneMix(parentA: a.hip, childA: a.kneeNear,
                             parentB: b.hip, childB: b.kneeNear,
                             parentNow: p.hip, kneeP)
        p.ankleNear = boneMix(parentA: a.kneeNear, childA: a.ankleNear,
                              parentB: b.kneeNear, childB: b.ankleNear,
                              parentNow: p.kneeNear, ankleP)
        p.kneeFar = boneMix(parentA: a.hip, childA: a.kneeFar,
                            parentB: b.hip, childB: b.kneeFar,
                            parentNow: p.hip, kneeP)
        p.ankleFar = boneMix(parentA: a.kneeFar, childA: a.ankleFar,
                             parentB: b.kneeFar, childB: b.ankleFar,
                             parentNow: p.kneeFar, ankleP)

        // Micro-vie : sway lent + respiration, amplitudes sous le demi-point.
        let sway = CGFloat(sin(time * 0.8)) * 0.0038
        let breathe = CGFloat(sin(time * 1.9)) * 0.0024
        p.head.x += sway * 1.4; p.head.y += breathe * 0.8
        p.neck.x += sway * 1.2
        p.chest.x += sway; p.chest.y += breathe
        p.shoulder.x += sway * 1.1; p.shoulder.y += breathe * 0.9
        p.ponytail.x += sway * 2.2; p.ponytail.y -= breathe * 1.4

        return p
    }
}

/// Un exercice dessiné = deux poses + du matériel + une cadence.
struct FigureDesign {
    var start: FigurePose
    var end: FigurePose
    var equipment: FigureEquipment = .none
    var duration: Double = 1.6
}
