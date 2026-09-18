import SwiftUI

// MARK: - Blanc lunaire

/// Le blanc du splash n'est pas neutre : il est légèrement froid, comme un
/// clair de lune. C'est une couleur, pas du blanc — c'est ce qui unifie le
/// grade de bout en bout.
extension Color {
    static let lunar = Color(red: 0.93, green: 0.95, blue: 1.0)
}

// MARK: - La nébuleuse

/// Un anneau irrégulier, comme un cercle tracé à main levée. Le rayon ondule
/// selon quelques harmoniques — périodiques par construction, donc l'anneau se
/// referme parfaitement. `phase` fait tourner les irrégularités, pas le cercle :
/// la matière semble se déplacer le long de l'anneau.
struct NebulaRingShape: Shape {
    var seed: Int
    var phase: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        // Harmoniques déterministes, propres à chaque anneau.
        var state = UInt64(seed) &* 0x9E37_79B9_7F4A_7C15
        func next() -> CGFloat {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat((state >> 33) % 10_000) / 10_000
        }
        let harmonics: [(k: CGFloat, amp: CGFloat, shift: CGFloat)] = (0..<3).map { index in
            (k: CGFloat(index + 2),
             amp: 0.006 + next() * 0.016,
             shift: next() * 2 * .pi)
        }

        var path = Path()
        let samples = 160
        for step in 0...samples {
            let theta = CGFloat(step) / CGFloat(samples) * 2 * .pi
            var r = radius
            for h in harmonics {
                r += radius * h.amp * sin(h.k * theta + h.shift + phase)
            }
            let point = CGPoint(x: center.x + cos(theta) * r,
                                y: center.y + sin(theta) * r * 0.99)
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

/// La nébuleuse derrière la bouteille : trois halos de blanc lunaire
/// d'intensités différentes qui respirent en décalé, cerclés d'anneaux
/// ondulés qui tournent chacun à sa vitesse. Tout respire, rien ne clignote.
struct NebulaBloom: View {
    var t: Double
    var alpha: CGFloat
    /// Pulsation de l'impact : la nébuleuse se dilate quand il atterrit.
    var pulse: CGFloat
    /// Anneaux seuls, sans halos — sert à la copie « réfractée » dans le verre.
    var ringsOnly: Bool = false

    /// (rayon relatif à la largeur, graine, vitesse de phase, opacité, trait)
    private static let ringSpecs: [(radius: CGFloat, seed: Int, speed: Double,
                                    opacity: Double, width: CGFloat)] = [
        (0.62, 3, 0.110, 0.150, 0.8),
        (0.78, 7, -0.075, 0.120, 0.7),
        (0.95, 11, 0.055, 0.095, 0.7),
        (1.13, 17, -0.042, 0.070, 0.6),
        (1.32, 23, 0.030, 0.050, 0.6)
    ]

    /// Les halos vivent EN BAS, derrière le diablotin : c'est lui la source.
    /// Le haut de la bouteille doit rester noir — réduits et descendus.
    private static let haloSpecs: [(radius: CGFloat, opacity: Double,
                                    breathSpeed: Double, breathPhase: Double)] = [
        (0.40, 0.075, 0.43, 0.0),
        (0.74, 0.042, 0.31, 2.1),
        (1.22, 0.024, 0.53, 4.0)
    ]

    var body: some View {
        GeometryReader { geo in
            let w: CGFloat = geo.size.width
            let h: CGFloat = geo.size.height
            let swell: CGFloat = 1 + 0.025 * pulse

            ZStack {
                if !ringsOnly {
                    ForEach(0..<3) { index in
                        halo(spec: Self.haloSpecs[index], w: w, swell: swell)
                            .offset(y: h * 0.17)
                    }
                }
            }
            .frame(width: w, height: h)
            .position(x: w / 2, y: h * 0.55)
            .opacity(Double(alpha))
        }
    }

    private func halo(spec: (radius: CGFloat, opacity: Double,
                             breathSpeed: Double, breathPhase: Double),
                      w: CGFloat, swell: CGFloat) -> some View {
        let breath: Double = 0.82 + 0.18 * sin(t * spec.breathSpeed + spec.breathPhase)
        let radius: CGFloat = w * spec.radius * swell
        return Circle()
            .fill(
                RadialGradient(colors: [Color.lunar.opacity(spec.opacity * breath), .clear],
                               center: .center, startRadius: 0, endRadius: radius)
            )
            .frame(width: radius * 2, height: radius * 2)
    }

    private func ring(spec: (radius: CGFloat, seed: Int, speed: Double,
                             opacity: Double, width: CGFloat),
                      w: CGFloat) -> some View {
        let side: CGFloat = w * spec.radius * 2 * (1 + 0.015 * pulse)
        return NebulaRingShape(seed: spec.seed, phase: CGFloat(t * spec.speed))
            .stroke(Color.lunar.opacity(spec.opacity), lineWidth: spec.width)
            .frame(width: side, height: side)
    }
}

// MARK: - La poussière

/// Un plan de poussière : des points qui dérivent lentement, scintillent à
/// peine, et s'écartent quand le diablotin frappe le fond de la bouteille.
/// Tout est déterministe — la poussière dérive, elle ne grésille pas.
struct DustField: View {
    var t: Double
    var impulse: CGFloat
    var count: Int
    var sizeRange: ClosedRange<CGFloat>
    var alphaRange: ClosedRange<Double>
    /// Multiplicateur de dérive : le plan proche va plus vite (parallaxe).
    var speed: Double
    var seed: UInt64
    /// Flou de mise au point : net quand la caméra est posée, flou en macro.
    var defocus: CGFloat = 0

    /// Point d'impact en coordonnées relatives : le fond de la bouteille.
    private static let center = CGPoint(x: 0.5, y: 0.67)

    var body: some View {
        Canvas { context, size in
            var state: UInt64 = seed &* 0x9E37_79B9_7F4A_7C15
            func next() -> Double {
                state = state &* 6364136223846793005 &+ 1442695040888963407
                return Double((state >> 33) % 100_000) / 100_000
            }

            let cx = Self.center.x * size.width
            let cy = Self.center.y * size.height

            for _ in 0..<count {
                let x0 = next() * size.width
                let y0 = next() * size.height
                let radius = sizeRange.lowerBound
                    + CGFloat(next()) * (sizeRange.upperBound - sizeRange.lowerBound)
                let baseAlpha = alphaRange.lowerBound
                    + next() * (alphaRange.upperBound - alphaRange.lowerBound)
                let drift = (0.6 + next() * 0.9) * speed
                let heading = next() * 2 * .pi
                let twinklePhase = next() * 2 * .pi
                let swayPhase = next() * 2 * .pi

                // Dérive lente + balancement : la poussière « vole ».
                var x = x0 + CGFloat(cos(heading) * drift * 9 * t
                                     + sin(t * 0.5 + swayPhase) * 5)
                var y = y0 + CGFloat(sin(heading) * drift * 6 * t - drift * 7 * t)

                // L'impact : chaque grain est repoussé le long de son rayon,
                // d'autant moins qu'il est loin.
                if impulse > 0.001 {
                    var dx = x - cx, dy = y - cy
                    let distance = max(hypot(dx, dy), 1)
                    dx /= distance; dy /= distance
                    let falloff = CGFloat(exp(-Double(distance) / 260))
                    x += dx * impulse * 34 * falloff
                    y += dy * impulse * 34 * falloff
                }

                // On boucle sur les bords, avec une marge.
                x = (x + size.width + 40).truncatingRemainder(dividingBy: size.width + 40)
                y = (y + size.height + 40).truncatingRemainder(dividingBy: size.height + 40)

                let twinkle = 0.76 + 0.24 * sin(t * (0.6 + drift * 0.4) + twinklePhase)
                context.fill(
                    Path(ellipseIn: CGRect(x: x - radius, y: y - radius,
                                           width: radius * 2, height: radius * 2)),
                    with: .color(Color.lunar.opacity(baseAlpha * twinkle))
                )
            }
        }
        .blur(radius: defocus)
        .allowsHitTesting(false)
    }
}

// MARK: - Les détails du ciel

/// Étoile à quatre branches : deux capsules croisées, qui scintillent
/// lentement, chacune sur sa propre phase.
private struct CrossStar: View {
    var t: Double
    var size: CGFloat
    var phase: Double
    var baseAlpha: Double

    var body: some View {
        let shine = 0.45 + 0.55 * (0.5 + 0.5 * sin(t * 0.5 + phase))
        return ZStack {
            Capsule().frame(width: size, height: 0.7)
            Capsule().frame(width: 0.7, height: size)
        }
        .foregroundStyle(Color.lunar)
        .opacity(baseAlpha * shine)
    }
}

/// L'étoile filante : un cheveu de lumière qui traverse un coin du ciel, une
/// seule fois, pendant le calme avant le clin d'œil. Personne ne l'attend.
private struct ShootingStar: View {
    var t: Double
    static let window = 4.12...4.57

    var body: some View {
        GeometryReader { geo in
            if Self.window.contains(t) {
                let progress = CGFloat((t - Self.window.lowerBound)
                                       / (Self.window.upperBound - Self.window.lowerBound))
                let from = CGPoint(x: geo.size.width * 0.86, y: geo.size.height * 0.085)
                let to = CGPoint(x: geo.size.width * 0.62, y: geo.size.height * 0.205)
                let x = from.x + (to.x - from.x) * progress
                let y = from.y + (to.y - from.y) * progress
                let angle = atan2(to.y - from.y, to.x - from.x)

                Capsule()
                    .fill(
                        LinearGradient(colors: [.clear, Color.lunar],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: 46, height: 0.8)
                    .rotationEffect(.radians(Double(angle)))
                    .position(x: x, y: y)
                    .opacity(Double(sin(progress * .pi)) * 0.35)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Le fond galactique

/// Noir sur noir : des puits plus sombres que le fond, des voiles d'aurore à
/// peine au-dessus du noir qui dérivent en masses lentes, une bande laiteuse,
/// des étoiles à croix, un mini trident en constellation — et la poussière.
/// La profondeur vient de ce qui est plus noir, pas de ce qui brille.
struct GalaxyBackground: View {
    var t: Double
    /// Impulsion radiale de l'impact : la poussière s'écarte, puis reprend.
    var impulse: CGFloat
    /// Sortie Cheshire : le ciel s'éteint avec la scène.
    var dim: CGFloat
    /// Zoom caméra : sert à la profondeur de champ de la poussière.
    var zoom: CGFloat

    var body: some View {
        ZStack {
            // Le socle reste opaque jusqu'au bout : pendant la sortie
            // Cheshire, la scène fond vers le noir — jamais vers l'app.
            Color(red: 0.010, green: 0.011, blue: 0.020)

            ZStack {
                // Les puits : des nappes PLUS SOMBRES que le fond. C'est le
                // vignettage inversé qui donne le poids, la densité d'un ciel.
                RadialGradient(colors: [Color.black.opacity(0.85), .clear],
                               center: UnitPoint(x: 0.85, y: 0.15),
                               startRadius: 0, endRadius: 420)
                RadialGradient(colors: [Color.black.opacity(0.9), .clear],
                               center: UnitPoint(x: 0.10, y: 0.85),
                               startRadius: 0, endRadius: 480)

                // Les voiles d'aurore : d'immenses nappes gris-bleu à peine
                // au-dessus du noir, qui dérivent et tournent très lentement.
                aurora(width: 760, height: 300, tint: 0.011,
                       rotation: -24 + t * 0.55, x: 70 + sin(t * 0.12) * 30, y: -140)
                aurora(width: 680, height: 260, tint: 0.008,
                       rotation: 18 - t * 0.4, x: -90, y: 230 + sin(t * 0.09 + 1) * 26)

                // La voie lactée, en un souffle.
                Ellipse()
                    .fill(Color.lunar.opacity(0.011))
                    .frame(width: 900, height: 260)
                    .rotationEffect(.degrees(-28))
                    .offset(x: 60, y: -120)
                    .blur(radius: 70)

                skyDetails

                DustField(t: t, impulse: impulse, count: 40,
                          sizeRange: 0.4...0.95, alphaRange: 0.030...0.085,
                          speed: 1.0, seed: 11,
                          defocus: min(5, (zoom - 1) * 0.35))
            }
            .opacity(1 - Double(dim))
        }
        .ignoresSafeArea()
    }

    private func aurora(width: CGFloat, height: CGFloat, tint: Double,
                        rotation: Double, x: CGFloat, y: CGFloat) -> some View {
        Ellipse()
            .fill(Color(red: 0.52, green: 0.57, blue: 0.72).opacity(tint))
            .frame(width: width, height: height)
            .rotationEffect(.degrees(rotation))
            .offset(x: x, y: y)
            .blur(radius: 90)
    }

    /// Étoiles à croix, constellation-trident, bokehs errants, étoile filante.
    private var skyDetails: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height

            ZStack {
                CrossStar(t: t, size: 7, phase: 0.0, baseAlpha: 0.07)
                    .rotationEffect(.degrees(17))
                    .position(x: w * 0.18, y: h * 0.14)
                CrossStar(t: t, size: 5, phase: 2.3, baseAlpha: 0.06)
                    .rotationEffect(.degrees(-11))
                    .position(x: w * 0.83, y: h * 0.32)
                CrossStar(t: t, size: 6, phase: 4.1, baseAlpha: 0.055)
                    .rotationEffect(.degrees(8))
                    .position(x: w * 0.30, y: h * 0.82)

                // Le semis d'étoiles : minuscules, partout, chacune sa phase.
                Canvas { context, canvasSize in
                    let noise = InkNoise(seed: 201)
                    for i in 0..<60 {
                        let u = CGFloat(i)
                        let x = canvasSize.width * CGFloat(abs(noise(u * 1.7)))
                        let y = canvasSize.height * CGFloat(abs(noise(u * 2.9)))
                        let r = 0.5 + 0.6 * abs(noise(u * 4.1))
                        let tw = 0.5 + 0.5 * sin(t * (0.3 + 0.6 * Double(abs(noise(u * 5.3)))) + Double(i) * 1.7)
                        context.fill(
                            Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                            with: .color(Color.lunar.opacity((0.035 + 0.055 * tw))))
                    }
                }
                .allowsHitTesting(false)

                // Le mini trident, en trois points — à qui sait regarder.
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.lunar.opacity(0.032))
                        .frame(width: 1.6, height: 1.6)
                        .position(x: w * (0.115 + CGFloat(index) * 0.022),
                                  y: h * (0.245 - abs(CGFloat(index) - 1) * 0.016))
                }

                // Deux bokehs de premier plan, hors focus, qui errent.
                Circle()
                    .fill(Color.lunar.opacity(0.022))
                    .frame(width: 7, height: 7)
                    .blur(radius: 2.2)
                    .position(x: w * (0.12 + CGFloat(t) * 0.006),
                              y: h * (0.72 - CGFloat(t) * 0.004))
                Circle()
                    .fill(Color.lunar.opacity(0.017))
                    .frame(width: 9, height: 9)
                    .blur(radius: 2.8)
                    .position(x: w * (0.90 - CGFloat(t) * 0.005),
                              y: h * (0.58 + CGFloat(t) * 0.003))

                ShootingStar(t: t)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Grain de film

/// Le voile de pellicule : un bruit monochrome à ~1,5 %, mis à jour par pas de
/// 2-3 images. C'est lui qui fait « filmé » plutôt que « rendu ».
struct GrainOverlay: View {
    var t: Double

    var body: some View {
        Rectangle()
            .fill(Color.white)
            .colorEffect(ShaderLibrary.inkGrain(.float(Float(floor(t * 20) / 20))))
            .opacity(0.045)
            .blendMode(.plusLighter)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }
}
