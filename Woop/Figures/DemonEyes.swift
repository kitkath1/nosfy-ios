import SwiftUI

// MARK: - Les yeux dans le noir
//
// Le moment démon de l'éclipse : dans le noir absolu, DEUX YEUX s'ouvrent —
// une demi-seconde, pas plus — puis se referment, et le rideau se lève.
//
// Ce sont les yeux du diablotin, pas des yeux d'Halloween : même géométrie
// que `ImpGlyph` (deux ronds, écartés de 23 % de la tête, posés au-dessus du
// centre), mais INVERSÉS — chez lui ce sont deux trous d'ombre dans une
// goutte de lumière ; ici, deux braises dans une nuit d'encre. La mascotte
// vivait dans l'ancien splash et veille sur l'écran d'authentification :
// c'est l'univers de la maison qui regarde, pas un accessoire.
//
// Fonction pure de `age`, comme tout le plan. L'ouverture est une PAUPIÈRE
// (l'œil naît en fente et s'arrondit), le regard glisse d'un cheveu vers le
// spectateur pendant la tenue, et la fermeture est plus lente que
// l'ouverture — un être qui se rendort, pas une lampe qu'on coupe.
struct DemonEyes: View {
    /// Secondes depuis le début du moment. Négatif = rien.
    var age: Double
    /// Le centre du regard, en points.
    var center: CGPoint

    /// Ouverture 0,18 s · tenue 0,32 s · fermeture 0,22 s.
    static let duration: Double = 0.72

    var body: some View {
        Canvas(opaque: false, colorMode: .nonLinear,
               rendersAsynchronously: false) { ctx, _ in
            guard age >= 0, age < Self.duration else { return }

            // La paupière : ouverte vite, refermée lentement.
            let open = Self.smooth(min(age / 0.18, 1))
                     * (1 - Self.smooth(max((age - 0.50) / 0.22, 0)))
            guard open > 0.02 else { return }

            // Le regard glisse vers le spectateur pendant la tenue.
            let drift = CGFloat(2.4 * Self.smooth(min(max((age - 0.16) / 0.30, 0), 1)))

            let gap: CGFloat = 21          // le demi-écart des yeux du glyphe
            let r: CGFloat = 6.6           // le rayon d'un œil
            for side in [CGFloat(-1), CGFloat(1)] {
                let cx = center.x + side * gap + drift
                let cy = center.y
                let h = r * CGFloat(open)  // la fente devient un rond

                // Le halo de braise, très serré — il ne doit éclairer que
                // l'œil, jamais révéler un visage qui n'existe pas.
                let glowRect = CGRect(x: cx - r * 3.4, y: cy - r * 3.4 * 0.8,
                                      width: r * 6.8, height: r * 6.8 * 0.8)
                ctx.fill(Path(ellipseIn: glowRect),
                         with: .radialGradient(
                            Gradient(colors: [
                                Color(red: 1.00, green: 0.36, blue: 0.10)
                                    .opacity(0.22 * open),
                                .clear,
                            ]),
                            center: CGPoint(x: cx, y: cy),
                            startRadius: 0, endRadius: r * 3.4))

                // L'œil : un cœur presque blanc dans une iris de braise.
                let eyeRect = CGRect(x: cx - r, y: cy - h,
                                     width: r * 2, height: h * 2)
                ctx.fill(Path(ellipseIn: eyeRect),
                         with: .color(Color(red: 1.00, green: 0.52, blue: 0.16)
                             .opacity(0.95 * open)))
                let coreRect = CGRect(x: cx - r * 0.48, y: cy - h * 0.52,
                                      width: r * 0.96, height: h * 1.04)
                ctx.fill(Path(ellipseIn: coreRect),
                         with: .color(Color(red: 1.00, green: 0.88, blue: 0.68)
                             .opacity(0.95 * open)))
            }
        }
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }

    private static func smooth(_ x: Double) -> Double {
        let c = min(max(x, 0), 1)
        return c * c * (3 - 2 * c)
    }
}
