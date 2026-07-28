import SwiftUI

// MARK: - La tresse

/// La magie du diablotin : une double hélice de grains lumineux qui s'élève
/// de lui jusqu'au col. Chaque grain a son cycle, sa phase, sa taille — le
/// flux est continu, jamais mécanique. Une colonne de lueur douce court sous
/// les grains, et quelques étoiles à quatre branches voyagent dans le flux.
struct WispBraid: View {
    var t: Double
    /// Présence globale (naissance à l'impact, mort au fondu).
    var alpha: CGFloat
    /// Hauteur atteinte par la colonne : elle GRANDIT après l'impact.
    var rise: CGFloat
    /// Impulsion (clin d'œil, impact) : le flux s'embrase brièvement.
    var pulse: CGFloat

    private static let noise = InkNoise(seed: 71)

    var body: some View {
        Canvas { context, size in
            guard alpha > 0.01, rise > 0.02 else { return }
            let noise = Self.noise
            let w = size.width, h = size.height
            let centerX = w * 0.5 + w * 0.012 * CGFloat(sin(t * 0.4))
            let yBase = h * 0.745
            let yTop = h * (0.745 - 0.565 * rise)

            // La colonne de lueur : deux rubans sinus entrelacés, floutés —
            // c'est elle qui éclaire le verre de l'intérieur.
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: 4))
                for branch in 0..<2 {
                    var path = Path()
                    let steps = 44
                    for step in 0...steps {
                        let progress = CGFloat(step) / CGFloat(steps)
                        let y = yBase + (yTop - yBase) * progress
                        let amplitude = w * (0.105 - 0.068 * progress)
                        let drift: CGFloat = Self.noise(progress * 2.6) * 2.2
                        let ampMod: CGFloat = 0.75 + 0.5 * abs(Self.noise(progress * 1.7))
                        let axis: CGFloat = centerX + w * 0.03 * Self.noise(progress * 1.2 + 3)
                        let phaseA: Double = Double(progress) * 9.5 + Double(drift)
                        let phaseB: Double = t * 0.9 + Double(branch) * .pi * 0.88
                        let x: CGFloat = axis + amplitude * ampMod * CGFloat(sin(phaseA + phaseB))
                        if step == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    layer.stroke(
                        path,
                        with: .color(Color.lunar.opacity(
                            Double((0.085 + 0.05 * pulse) * alpha))),
                        style: StrokeStyle(lineWidth: 4.5, lineCap: .round)
                    )
                }
            }

            // Les grains : 150 sur deux brins, en flux continu.
            for i in 0..<150 {
                let seedA = abs(noise(CGFloat(i) * 1.7))
                let seedB = noise(CGFloat(i) * 2.9)
                let cycle = 5.5 + 3.5 * Double(seedA)
                let phase = Double(abs(noise(CGFloat(i) * 4.3)))
                var progress = CGFloat(((t / cycle) + phase)
                    .truncatingRemainder(dividingBy: 1))
                if progress < 0 { progress += 1 }
                // La colonne ne monte que jusqu'où elle a grandi.
                guard progress < rise else { continue }

                let y = yBase + (yTop - yBase) * progress / max(rise, 0.01)
                let branch = i % 2
                let amplitude = w * (0.105 - 0.068 * progress)
                let wobble = w * 0.022 * noise(CGFloat(i) * 6.1 + CGFloat(t) * 0.3)
                let gDrift: CGFloat = Self.noise(progress * 2.6) * 2.2
                let gAmp: CGFloat = 0.75 + 0.5 * abs(Self.noise(progress * 1.7))
                let gAxis: CGFloat = centerX + w * 0.03 * Self.noise(progress * 1.2 + 3)
                let gPhaseA: Double = Double(progress) * 9.5 + Double(gDrift)
                let gPhaseB: Double = t * 0.9 + Double(branch) * .pi * 0.88
                let x: CGFloat = gAxis + amplitude * gAmp * CGFloat(sin(gPhaseA + gPhaseB)) + wobble

                let radius = (0.6 + 1.1 * abs(seedB)) * (1 - 0.35 * progress)
                let breath = 0.55 + 0.45 * sin(t * (1.2 + 2.4 * Double(seedA))
                                               + Double(i) * 1.3)
                let fade = pow(sin(.pi * Double(min(progress / max(rise, 0.01), 1))), 0.7)
                let grainAlpha = fade * breath * (0.42 + 0.45 * Double(pulse))
                    * Double(alpha)

                // L'auréole d'abord, le grain net dessus — la matière lumineuse.
                context.fill(
                    Path(ellipseIn: CGRect(x: x - radius * 3.4, y: y - radius * 3.4,
                                           width: radius * 6.8, height: radius * 6.8)),
                    with: .color(Color.lunar.opacity(grainAlpha * 0.13))
                )
                context.fill(
                    Path(ellipseIn: CGRect(x: x - radius, y: y - radius,
                                           width: radius * 2, height: radius * 2)),
                    with: .color(.white.opacity(grainAlpha))
                )

                // Une étoile voyageuse de loin en loin.
                if i % 19 == 0 {
                    let armLength = radius * 4
                    var star = Path()
                    star.move(to: CGPoint(x: x - armLength, y: y))
                    star.addLine(to: CGPoint(x: x + armLength, y: y))
                    star.move(to: CGPoint(x: x, y: y - armLength))
                    star.addLine(to: CGPoint(x: x, y: y + armLength))
                    context.stroke(
                        star,
                        with: .color(.white.opacity(grainAlpha * 0.7)),
                        style: StrokeStyle(lineWidth: 0.5, lineCap: .round)
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .blendMode(.plusLighter)
    }
}

// MARK: - La poussière en suspension

/// Des grains immobiles suspendus dans le verre, à peine visibles, qui
/// scintillent chacun à son rythme — la profondeur intérieure de la bouteille.
struct InteriorDust: View {
    var t: Double
    var alpha: CGFloat

    private static let noise = InkNoise(seed: 83)

    var body: some View {
        Canvas { context, size in
            guard alpha > 0.01 else { return }
            let noise = Self.noise
            for i in 0..<16 {
                let x = size.width * (0.24 + 0.52 * Double(abs(noise(CGFloat(i) * 2.1))))
                let y = size.height * (0.34 + 0.52 * Double(abs(noise(CGFloat(i) * 3.7))))
                let radius = 0.5 + 0.6 * abs(noise(CGFloat(i) * 5.3))
                let twinkle = 0.4 + 0.6 * (0.5 + 0.5 * sin(t * (0.4 + 0.7 * Double(abs(noise(CGFloat(i))))) + Double(i) * 2.4))
                context.fill(
                    Path(ellipseIn: CGRect(x: x - radius, y: y - radius,
                                           width: radius * 2, height: radius * 2)),
                    with: .color(.white.opacity(0.05 * twinkle * Double(alpha)))
                )
            }
        }
        .allowsHitTesting(false)
        .blendMode(.plusLighter)
    }
}

// MARK: - Les étincelles du sol

/// La poussière posée au sol autour du contact : elle s'allume par pointes
/// brèves quand la lumière du diablotin la rase. Perspective écrasée.
struct FloorSparkle: View {
    var t: Double
    var alpha: CGFloat

    private static let noise = InkNoise(seed: 91)

    var body: some View {
        Canvas { context, size in
            guard alpha > 0.01 else { return }
            let noise = Self.noise
            let cx = size.width * 0.49
            let cy = size.height * 0.955
            for i in 0..<22 {
                let angle = Double(abs(noise(CGFloat(i) * 1.3))) * 2 * .pi
                let radius = size.width * (0.18 + 0.36 * Double(abs(noise(CGFloat(i) * 2.7))))
                let x = cx + CGFloat(cos(angle)) * radius
                let y = cy + CGFloat(sin(angle)) * radius * 0.16
                let dot = 0.5 + 0.7 * abs(noise(CGFloat(i) * 4.9))
                let pop = pow(max(0, sin(t * (0.8 + 2.2 * Double(abs(noise(CGFloat(i) * 6.1))))
                                         + Double(i) * 1.9)), 5)
                if pop > 0.3 {
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - dot * 3, y: y - dot * 3,
                                               width: dot * 6, height: dot * 6)),
                        with: .color(Color.lunar.opacity(0.10 * pop * Double(alpha)))
                    )
                }
                context.fill(
                    Path(ellipseIn: CGRect(x: x - dot, y: y - dot,
                                           width: dot * 2, height: dot * 2)),
                    with: .color(.white.opacity((0.04 + 0.45 * pop) * Double(alpha)))
                )
            }
        }
        .allowsHitTesting(false)
        .blendMode(.plusLighter)
    }
}
