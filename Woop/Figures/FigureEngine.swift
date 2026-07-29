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

/// Courbe quadratique qui PASSE par `m` à t = 0,5 — et redevient une droite
/// quand `m` est le milieu de `a` et `b`. C'est l'interpolation à trois
/// keyframes du moteur : la trajectoire peut enfin être courbe.
private func quadThrough(_ a: CGFloat, _ m: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
    let c = 2 * m - (a + b) / 2
    let u = 1 - t
    return u * u * a + 2 * u * t * c + t * t * b
}

private func quadThrough(_ a: CGPoint, _ m: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
    CGPoint(x: quadThrough(a.x, m.x, b.x, t), y: quadThrough(a.y, m.y, b.y, t))
}

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
    /// 0 = câble au repos (il pendouille), 1 = sous charge (raide). Un câble
    /// qui pend pendant l'effort tue toute sensation de poids.
    var tension: CGFloat = 0.35

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
            // Câbles : tendus pendant l'effort, détendus aux points morts.
            let sag = scale * (0.004 + 0.055 * (1 - tension))
            for end in targets {
                path.move(to: a)
                path.addQuadCurve(
                    to: end,
                    control: CGPoint(x: (a.x + end.x) / 2, y: (a.y + end.y) / 2 + sag)
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

            // Tension du câble : proportionnelle à la vitesse du geste — raide
            // pendant l'effort, détendu aux points morts.
            let tension: CGFloat
            if animated {
                let dt = 0.05
                let v = abs(progressValue(time, lagFraction: 0)
                            - progressValue(time - dt, lagFraction: 0)) / dt
                tension = min(1, v * CGFloat(design.duration) * 1.5 + 0.12)
            } else {
                tension = 0.35
            }

            // Matériel : trait blanc à peine posé, le décor ne rivalise pas
            // avec la constellation.
            let equipmentPath = EquipmentShape(equipment: design.equipment, pose: pose,
                                               target: pose, progress: 0, tension: tension)
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

    /// Progression d'une répétition. Trois choses la distinguent d'un
    /// métronome : un court maintien aux deux extrêmes, un effort (aller) plus
    /// lent que le retour, et le fait qu'aucune répétition n'est identique —
    /// le temps est légèrement gauchi et l'amplitude varie de quelques
    /// pourcents d'une rep à l'autre. `lagFraction` décale la phase, c'est la
    /// traîne des extrémités.
    private func progressValue(_ time: TimeInterval, lagFraction: Double) -> CGFloat {
        // Dérive lente et non commensurable avec la rep : brise la périodicité.
        let warped = time + (sin(time * 0.29) + sin(time * 0.171 + 1.7)) * 0.03 * design.duration
        let t = warped - lagFraction * design.duration
        var cycle = (t / design.duration).truncatingRemainder(dividingBy: 2)
        if cycle < 0 { cycle += 2 }
        // L'aller occupe 54 % du cycle, le retour 46 %.
        let up = 1.08
        let raw = cycle < up ? cycle / up : 1 - (cycle - up) / (2 - up)
        // Maintien de ~9 % à chaque extrême : la contraction se tient.
        let hold = 0.09
        let u = min(max((raw - hold) / (1 - 2 * hold), 0), 1)
        var p = CGFloat(0.5 - 0.5 * cos(.pi * u))
        // Amplitude de rep légèrement variable : parfois un poil sous le plein
        // débattement, parfois un soupçon au-delà.
        p *= 0.985 + 0.025 * CGFloat(sin(time * 0.113 + 0.8))
        return min(p, 1.02)
    }

    /// Interpole un os en polaire autour de son articulation parente, en
    /// passant par la pose intermédiaire quand l'exercice en a une : l'angle
    /// tourne par le plus court chemin, la longueur reste celle des poses.
    /// C'est le pivot articulaire qui remplace l'étirement caoutchouc.
    private func boneCurve(parentA: CGPoint, childA: CGPoint,
                           parentM: CGPoint?, childM: CGPoint?,
                           parentB: CGPoint, childB: CGPoint,
                           parentNow: CGPoint, _ t: CGFloat) -> CGPoint {
        func polar(_ p: CGPoint, _ c: CGPoint) -> (ang: CGFloat, len: CGFloat) {
            (atan2(c.y - p.y, c.x - p.x), hypot(c.x - p.x, c.y - p.y))
        }
        func unwrap(_ ang: CGFloat, near ref: CGFloat) -> CGFloat {
            var d = ang - ref
            while d > .pi { d -= 2 * .pi }
            while d < -.pi { d += 2 * .pi }
            return ref + d
        }
        let a = polar(parentA, childA)
        let b = polar(parentB, childB)
        let angM: CGFloat, lenM: CGFloat, angB: CGFloat
        if let pm = parentM, let cm = childM {
            let m = polar(pm, cm)
            angM = unwrap(m.ang, near: a.ang)
            angB = unwrap(b.ang, near: angM)
            lenM = m.len
        } else {
            angB = unwrap(b.ang, near: a.ang)
            angM = (a.ang + angB) / 2
            lenM = (a.len + b.len) / 2
        }
        let ang = quadThrough(a.ang, angM, angB, t)
        let len = quadThrough(a.len, lenM, b.len, t)
        return CGPoint(x: parentNow.x + cos(ang) * len,
                       y: parentNow.y + sin(ang) * len)
    }

    /// Genou par cinématique inverse : hanche mobile, cheville ancrée au sol,
    /// cuisse et tibia de longueur constante. `hint` choisit le sens de flexion.
    private func ikKnee(hip: CGPoint, ankle: CGPoint,
                        thigh: CGFloat, shin: CGFloat, hint: CGPoint) -> CGPoint {
        let dx = ankle.x - hip.x, dy = ankle.y - hip.y
        let dist = max(hypot(dx, dy), 0.0001)
        let d = min(max(dist, abs(thigh - shin) + 0.001), thigh + shin - 0.001)
        let ux = dx / dist, uy = dy / dist
        let a = (thigh * thigh - shin * shin + d * d) / (2 * d)
        let h = sqrt(max(thigh * thigh - a * a, 0))
        let base = CGPoint(x: hip.x + ux * a, y: hip.y + uy * a)
        let k1 = CGPoint(x: base.x - uy * h, y: base.y + ux * h)
        let k2 = CGPoint(x: base.x + uy * h, y: base.y - ux * h)
        return hypot(k1.x - hint.x, k1.y - hint.y) <= hypot(k2.x - hint.x, k2.y - hint.y)
            ? k1 : k2
    }

    /// Pose vivante. Le buste initie, coudes puis mains puis chevilles suivent
    /// avec leur retard ; le bassin contrebalance les bras ; les pieds des
    /// exercices debout restent plantés au sol (genoux en IK) ; la queue de
    /// cheval a l'inertie d'un pendule ; et un balancement + une respiration
    /// imperceptibles habitent la figure même entre deux répétitions.
    private func livePose(_ time: TimeInterval) -> FigurePose {
        guard animated else { return design.start }

        let a = design.start, b = design.end
        let m = design.mid

        let tTorso = progressValue(time, lagFraction: 0)
        let tHead = progressValue(time, lagFraction: 0.04)
        let tTail = progressValue(time, lagFraction: 0.10)
        let tElbow = progressValue(time, lagFraction: 0.025)
        let tHand = progressValue(time, lagFraction: 0.05)
        let tKnee = progressValue(time, lagFraction: 0.02)
        let tAnkle = progressValue(time, lagFraction: 0.04)

        func through(_ ka: CGPoint, _ km: CGPoint?, _ kb: CGPoint, _ t: CGFloat) -> CGPoint {
            quadThrough(ka, km ?? CGPoint(x: (ka.x + kb.x) / 2, y: (ka.y + kb.y) / 2), kb, t)
        }

        var p = FigurePose()
        p.headRadius = a.headRadius + (b.headRadius - a.headRadius) * min(tTorso, 1)

        // Le tronc mène.
        p.neck = through(a.neck, m?.neck, b.neck, tTorso)
        p.chest = through(a.chest, m?.chest, b.chest, tTorso)
        p.waist = through(a.waist, m?.waist, b.waist, tTorso)
        p.hip = through(a.hip, m?.hip, b.hip, tTorso)
        p.shoulder = through(a.shoulder, m?.shoulder, b.shoulder, tTorso)
        p.head = through(a.head, m?.head, b.head, tHead)

        // Bras : pivot épaule → coude, puis coude → main.
        p.elbowNear = boneCurve(parentA: a.shoulder, childA: a.elbowNear,
                                parentM: m?.shoulder, childM: m?.elbowNear,
                                parentB: b.shoulder, childB: b.elbowNear,
                                parentNow: p.shoulder, tElbow)
        p.handNear = boneCurve(parentA: a.elbowNear, childA: a.handNear,
                               parentM: m?.elbowNear, childM: m?.handNear,
                               parentB: b.elbowNear, childB: b.handNear,
                               parentNow: p.elbowNear, tHand)
        p.elbowFar = boneCurve(parentA: a.shoulder, childA: a.elbowFar,
                               parentM: m?.shoulder, childM: m?.elbowFar,
                               parentB: b.shoulder, childB: b.elbowFar,
                               parentNow: p.shoulder, tElbow)
        p.handFar = boneCurve(parentA: a.elbowFar, childA: a.handFar,
                              parentM: m?.elbowFar, childM: m?.handFar,
                              parentB: b.elbowFar, childB: b.handFar,
                              parentNow: p.elbowFar, tHand)

        // Contrepoids : quand les mains partent d'un côté, le bassin recule de
        // l'autre — la masse reste au-dessus des appuis.
        let reach = (p.handNear.x + p.handFar.x) / 2 - p.chest.x
        p.hip.x -= reach * 0.07
        p.waist.x -= reach * 0.045

        // Jambes. Si la cheville ne bouge presque pas entre les deux poses et
        // vit près du sol, l'exercice se joue debout : on la cloue au sol et le
        // genou absorbe en IK — fini les pieds qui glissent.
        func leg(kneeA: CGPoint, kneeM: CGPoint?, kneeB: CGPoint,
                 ankleA: CGPoint, ankleM: CGPoint?, ankleB: CGPoint) -> (knee: CGPoint, ankle: CGPoint) {
            let hintKnee = boneCurve(parentA: a.hip, childA: kneeA,
                                     parentM: m?.hip, childM: kneeM,
                                     parentB: b.hip, childB: kneeB,
                                     parentNow: p.hip, tKnee)
            let planted = hypot(ankleB.x - ankleA.x, ankleB.y - ankleA.y) < 0.045
                && ankleA.y > 0.72
            if planted {
                let thigh = hypot(kneeA.x - a.hip.x, kneeA.y - a.hip.y)
                let shin = hypot(ankleA.x - kneeA.x, ankleA.y - kneeA.y)
                let knee = ikKnee(hip: p.hip, ankle: ankleA,
                                  thigh: thigh, shin: shin, hint: hintKnee)
                return (knee, ankleA)
            }
            let ankle = boneCurve(parentA: kneeA, childA: ankleA,
                                  parentM: kneeM, childM: ankleM,
                                  parentB: kneeB, childB: ankleB,
                                  parentNow: hintKnee, tAnkle)
            return (hintKnee, ankle)
        }
        let near = leg(kneeA: a.kneeNear, kneeM: m?.kneeNear, kneeB: b.kneeNear,
                       ankleA: a.ankleNear, ankleM: m?.ankleNear, ankleB: b.ankleNear)
        p.kneeNear = near.knee; p.ankleNear = near.ankle
        let far = leg(kneeA: a.kneeFar, kneeM: m?.kneeFar, kneeB: b.kneeFar,
                      ankleA: a.ankleFar, ankleM: m?.ankleFar, ankleB: b.ankleFar)
        p.kneeFar = far.knee; p.ankleFar = far.ankle

        // Queue de cheval : suit avec retard, plus l'inertie du mouvement de
        // la tête — elle balaie quand la tête accélère, comme un pendule.
        p.ponytail = through(a.ponytail, m?.ponytail, b.ponytail, tTail)
        let dt = 0.06
        let headPrev = through(a.head, m?.head, b.head,
                               progressValue(time - dt, lagFraction: 0.04))
        p.ponytail.x -= (p.head.x - headPrev.x) / dt * 0.10
        p.ponytail.y -= (p.head.y - headPrev.y) / dt * 0.06

        // Micro-vie : sway lent + respiration, amplitudes sous le demi-point.
        let sway = CGFloat(sin(time * 0.8)) * 0.0034
        let breathe = CGFloat(sin(time * 1.9)) * 0.0022
        p.head.x += sway * 1.4; p.head.y += breathe * 0.8
        p.neck.x += sway * 1.2
        p.chest.x += sway; p.chest.y += breathe
        p.shoulder.x += sway * 1.1; p.shoulder.y += breathe * 0.9
        p.ponytail.x += sway * 2.2; p.ponytail.y -= breathe * 1.4

        return p
    }
}

/// Un exercice dessiné = deux poses + du matériel + une cadence.
/// `mid`, optionnelle, est la pose de passage : la trajectoire la traverse à
/// mi-répétition au lieu de filer en ligne droite — indispensable aux gestes
/// rotationnels, dont le milieu n'est pas la moyenne des extrêmes.
struct FigureDesign {
    var start: FigurePose
    var end: FigurePose
    var mid: FigurePose? = nil
    var equipment: FigureEquipment = .none
    var duration: Double = 1.6
}
