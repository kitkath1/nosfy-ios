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

// MARK: - Silhouette

/// Construit un contour galbé le long d'une polyligne : la largeur varie d'un
/// point à l'autre. C'est ce qui distingue une vraie silhouette d'un bonhomme
/// bâton — les membres ont un volume qui s'affine vers les extrémités.
private func taperedOutline(_ points: [CGPoint], _ widths: [CGFloat]) -> Path {
    guard points.count >= 2, points.count == widths.count else { return Path() }

    var left: [CGPoint] = []
    var right: [CGPoint] = []

    for (index, point) in points.enumerated() {
        // Direction locale : moyenne des segments adjacents, pour éviter les angles durs.
        let previous = points[max(index - 1, 0)]
        let next = points[min(index + 1, points.count - 1)]
        var dx = next.x - previous.x
        var dy = next.y - previous.y
        let length = max(sqrt(dx * dx + dy * dy), 0.0001)
        dx /= length; dy /= length

        let half = widths[index] / 2
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

private func lerpWidths(_ from: CGFloat, _ mid: CGFloat, _ to: CGFloat,
                        count: Int) -> [CGFloat] {
    (0..<count).map { index in
        let t = CGFloat(index) / CGFloat(max(count - 1, 1))
        return t < 0.5
            ? from + (mid - from) * (t * 2)
            : mid + (to - mid) * ((t - 0.5) * 2)
    }
}

struct FigureShape: Shape {
    var pose: FigurePose
    /// 0 = pose de départ, 1 = pose d'arrivée.
    var progress: CGFloat
    var target: FigurePose
    /// `true` pour ne tracer que les membres éloignés (rendus plus discrets).
    var farLimbsOnly: Bool = false

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

        // Un membre est un seul contour continu. Pas de cercle aux articulations :
        // en tracé (et non en aplat), ils ressortaient comme des renflements.
        func limb(_ a: CGPoint, _ control: CGPoint, _ b: CGPoint,
                  _ w0: CGFloat, _ w1: CGFloat, _ w2: CGFloat) {
            let pts = sampleQuad(pt(a), pt(control), pt(b), steps: 14)
            let widths = lerpWidths(w0 * scale, w1 * scale, w2 * scale, count: pts.count)
            path.addPath(taperedOutline(pts, widths))
        }

        if farLimbsOnly {
            limb(p.shoulder, p.elbowFar, p.handFar, 0.030, 0.023, 0.014)
            limb(p.hip, p.kneeFar, p.ankleFar, 0.044, 0.030, 0.017)
            return path
        }

        // Tête, légèrement ovale
        let head = pt(p.head)
        let rx = p.headRadius * scale
        let ry = p.headRadius * scale * 1.12
        path.addEllipse(in: CGRect(x: head.x - rx, y: head.y - ry,
                                   width: rx * 2, height: ry * 2))

        // Queue de cheval, effilée
        let tailA = CGPoint(x: head.x + p.ponytail.x * scale * 0.32,
                            y: head.y + p.ponytail.y * scale * 0.22)
        let tailB = CGPoint(x: head.x + p.ponytail.x * scale,
                            y: head.y + p.ponytail.y * scale)
        let tailControl = CGPoint(x: tailA.x + (tailB.x - tailA.x) * 0.25,
                                  y: tailA.y + (tailB.y - tailA.y) * 1.15)
        let tailPoints = sampleQuad(tailA, tailControl, tailB, steps: 8)
        path.addPath(taperedOutline(
            tailPoints,
            lerpWidths(0.030 * scale, 0.022 * scale, 0.006 * scale, count: tailPoints.count)
        ))

        // Buste : épaules larges, taille marquée, hanches pleines. C'est cette
        // variation de largeur qui donne la silhouette féminine.
        let torsoPoints = [pt(p.neck), pt(p.chest), pt(p.waist), pt(p.hip)]
        path.addPath(taperedOutline(
            torsoPoints,
            [0.048 * scale, 0.082 * scale, 0.055 * scale, 0.090 * scale]
        ))

        // Bras et jambes proches
        limb(p.shoulder, p.elbowNear, p.handNear, 0.032, 0.024, 0.015)
        limb(p.hip, p.kneeNear, p.ankleNear, 0.048, 0.032, 0.018)

        // Pieds
        for ankle in [p.ankleNear, p.ankleFar] {
            let a = pt(ankle)
            path.addPath(taperedOutline(
                [a, CGPoint(x: a.x + scale * 0.040, y: a.y + scale * 0.004)],
                [0.017 * scale, 0.011 * scale]
            ))
        }

        return path
    }
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

// MARK: - Vue composée

/// Dessin d'un exercice : silhouette en trait dégradé blanc → transparent, matériel plus discret.
/// `animated` fait boucler le mouvement entre les deux poses.
struct ExerciseFigure: View {
    let design: FigureDesign
    var animated: Bool = false
    var lineWidth: CGFloat = 1.2

    @State private var progress: CGFloat = 0
    @State private var appeared: CGFloat = 0

    var body: some View {
        ZStack {
            EquipmentShape(equipment: design.equipment, pose: design.start,
                           target: design.end, progress: progress)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.20), .white.opacity(0.05)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: lineWidth * 0.7,
                                       lineCap: .round, lineJoin: .round)
                )

            // Membres éloignés : même trait, simplement en retrait.
            FigureShape(pose: design.start, progress: progress,
                        target: design.end, farLimbsOnly: true)
                .stroke(Color.woopViolet.opacity(0.22),
                        style: StrokeStyle(lineWidth: lineWidth * 0.8, lineJoin: .round))

            // Silhouette au premier plan. On trace le contour galbé au lieu de le
            // remplir : on garde le dessin en ligne, mais avec de vraies formes.
            FigureShape(pose: design.start, progress: progress, target: design.end)
                .stroke(WoopGradient.figureStroke,
                        style: StrokeStyle(lineWidth: lineWidth, lineJoin: .round))
        }
        .aspectRatio(1, contentMode: .fit)
        .opacity(appeared)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = 1 }
            guard animated else { return }
            withAnimation(
                .easeInOut(duration: design.duration)
                    .repeatForever(autoreverses: true)
                    .delay(0.35)
            ) {
                progress = 1
            }
        }
    }
}

/// Un exercice dessiné = deux poses + du matériel + une cadence.
struct FigureDesign {
    var start: FigurePose
    var end: FigurePose
    var equipment: FigureEquipment = .none
    var duration: Double = 1.6
}
