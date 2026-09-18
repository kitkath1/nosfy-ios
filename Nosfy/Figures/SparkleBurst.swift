import SwiftUI

// MARK: - Paillettes

/// La salve d'une série validée : des étoiles à quatre branches jaillissent du
/// point de validation, s'écartent en montant, puis retombent et s'éteignent.
///
/// Blanc et or, jamais violet : dans cette app l'or est réservé à ce qui a été
/// gagné. Et l'étoile est celle du diablotin du splash — branches creusées près
/// du centre, ce qui donne l'éclat. Quatre triangles feraient un jouet.
///
/// La salve ne dure qu'une seconde et quart, puis la `TimelineView` s'endort :
/// hors célébration, cette vue ne coûte rien.
struct SparkleBurst: View {
    /// Toute variation déclenche une salve. Constant, il ne se passe rien.
    var trigger: Int
    /// D'où part la gerbe, en fraction de la surface. Par défaut la pastille de
    /// validation, en haut à gauche de la card.
    var origin: UnitPoint = UnitPoint(x: 0.30, y: 0.17)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt: Date?
    /// Deux salves rapprochées ne doivent pas s'éteindre l'une l'autre.
    @State private var generation = 0

    private static let count = 22
    private static let life: Double = 1.25

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: startedAt == nil)) { timeline in
            Canvas(opaque: false, colorMode: .nonLinear, rendersAsynchronously: false) { ctx, size in
                guard let startedAt else { return }
                draw(&ctx, size: size, t: timeline.date.timeIntervalSince(startedAt))
            }
            .blendMode(.plusLighter)
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in fire() }
    }

    private func fire() {
        // Sous Reduce Motion la pastille apparaît, et c'est tout : une gerbe de
        // projectiles est exactement ce que ce réglage demande d'éviter.
        guard !reduceMotion else { return }
        generation += 1
        let mine = generation
        startedAt = .now
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.life + 0.1) {
            if generation == mine { startedAt = nil }
        }
    }

    private func draw(_ ctx: inout GraphicsContext, size: CGSize, t: Double) {
        guard t >= 0, t < Self.life, size.width > 1, size.height > 1 else { return }
        let source = CGPoint(x: size.width * origin.x, y: size.height * origin.y)

        for index in 0..<Self.count {
            // Les paillettes ne partent pas toutes ensemble : une gerbe
            // parfaitement synchrone se lit comme une seule forme qui grandit.
            let delay = 0.10 * Self.hash(index, 7)
            let span = Self.life - delay
            let u = (t - delay) / span
            guard u > 0, u < 1 else { continue }
            let age = u * span

            let angle = -Double.pi / 2 + (Self.hash(index, 1) - 0.5) * 2.6
            let speed = 70 + 150 * Self.hash(index, 2)
            let x = source.x + cos(angle) * speed * age
            // Le terme quadratique est la pesanteur : une paillette monte, puis
            // retombe. Sans lui, la gerbe s'échappe et ne « pèse » rien.
            let y = source.y + sin(angle) * speed * age + 190 * age * age

            // Allumage franc, extinction longue.
            let alpha = pow(sin(.pi * pow(u, 0.62)), 1.1)
            let twinkle = 0.72 + 0.28 * sin(age * 13 + Double(index))
            let side = (4.5 + 6.0 * Self.hash(index, 3)) * twinkle
            let spin = (Self.hash(index, 4) - 0.5) * 6 * age
            let tint: Color = Self.hash(index, 5) > 0.55 ? .woopGold : .white

            // Le halo d'abord : sans lui l'étoile est un pictogramme posé sur le
            // fond, pas une lumière qui vient de la card.
            let halo = side * 1.9
            ctx.fill(
                Path(ellipseIn: CGRect(x: x - halo, y: y - halo,
                                       width: halo * 2, height: halo * 2)),
                with: .radialGradient(
                    Gradient(colors: [tint.opacity(0.30 * alpha), .clear]),
                    center: CGPoint(x: x, y: y), startRadius: 0, endRadius: halo))

            let star = Self.star.applying(
                CGAffineTransform(scaleX: side, y: side)
                    .concatenating(CGAffineTransform(rotationAngle: spin))
                    .concatenating(CGAffineTransform(translationX: x, y: y)))
            ctx.fill(star, with: .color(tint.opacity(0.95 * alpha)))
        }
    }

    /// Étoile à quatre branches, rayon 1, centrée sur l'origine.
    private static let star: Path = {
        let waist = 0.18
        var path = Path()
        path.move(to: CGPoint(x: 0, y: -1))
        path.addQuadCurve(to: CGPoint(x: 1, y: 0), control: CGPoint(x: waist, y: -waist))
        path.addQuadCurve(to: CGPoint(x: 0, y: 1), control: CGPoint(x: waist, y: waist))
        path.addQuadCurve(to: CGPoint(x: -1, y: 0), control: CGPoint(x: -waist, y: waist))
        path.addQuadCurve(to: CGPoint(x: 0, y: -1), control: CGPoint(x: -waist, y: -waist))
        path.closeSubpath()
        return path
    }()

    private static func hash(_ index: Int, _ salt: Int) -> Double {
        let v = sin(Double(index) * 127.1 + Double(salt) * 311.7) * 43758.5453
        return v - v.rounded(.down)
    }
}
