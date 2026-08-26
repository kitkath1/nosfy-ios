import SwiftUI

// MARK: - Le vol lointain
//
// Pendant les voiles de l'éclipse, une poignée d'oiseaux traverse la nuit —
// très loin, en contre-jour. Ils ne sont VISIBLES que là où ils croisent la
// lueur de la lune : ce sont des silhouettes opaques posées sur un ciel déjà
// noir, exactement comme au cinéma. C'est leur distance qui les rend sûrs —
// un corbeau de près est un dessin animé ; six battements d'ailes minuscules
// devant une lune, c'est du film muet.
//
// Fonction pure de `age`, comme tout le plan : la volée se rejoue à
// l'identique et se fige sous `-moonSplashFreeze`.
struct NightBirds: View {
    /// Secondes depuis le départ de la volée. Négatif = rien.
    var age: Double
    /// Le centre de la lune à l'écran — les trajectoires passent dessous.
    var moon: CGPoint
    /// L'ÉCHELLE DE LA VOLÉE. 1 = le réglage d'origine, calé sur la lune
    /// PLEIN ÉCRAN du plan-séquence.
    ///
    /// ⚠️ La Lune de Sang, elle, fait ~200 pt de large : à l'échelle 1 les
    /// oiseaux mesuraient 7 pt d'envergure pour un trait de 1,1 — mesuré à la
    /// sonde, ils étaient bien dessinés et bien placés, mais indiscernables.
    /// Ce n'est pas un défaut du composant : c'est une distance qui n'est plus
    /// la même. Le réglage de l'archive n'est pas touché (défaut 1).
    var echelle: CGFloat = 1
    /// `-corbeauxSonde` : la volée en ROUGE, pour vérifier qu'elle est
    /// dessinée et OÙ — des silhouettes noires sur une nuit noire ne se
    /// prouvent pas à l'œil.
    static let sonde = CommandLine.arguments.contains("-corbeauxSonde")

    var body: some View {
        Canvas(opaque: false, colorMode: .nonLinear,
               rendersAsynchronously: false) { ctx, size in
            guard age >= 0 else { return }
            for i in 0..<6 {
                let h1 = Self.hash(i, 3), h2 = Self.hash(i, 17)
                let h3 = Self.hash(i, 31)

                // Une volée lâche : chacun part à son heure, sur sa ligne.
                let a = age - (Double(i) * 0.16 + 0.4 * h1)
                guard a > 0 else { continue }

                // Traversée de droite à gauche — trois secondes et des
                // poussières, chacun à son allure.
                let span: Double = Double(size.width) + 160.0
                let v: Double = span / (3.1 + 0.6 * h2)
                let xd: Double = Double(size.width) + 60.0 - v * a
                guard xd > -60.0 else { continue }
                let drift: Double = -34.0 + 92.0 * h3
                let bob: Double = 9.0 * sin(a * 1.3 + h1 * 6.3)
                let x = CGFloat(xd)
                let y = moon.y + CGFloat(drift + bob)

                // Le glyphe du lointain : deux courbes, les ailes qui battent.
                let w = CGFloat(3.2 + 3.4 * h2) * echelle
                let phase: Double = a * 2.0 * Double.pi * (2.6 + 1.6 * h1)
                let flap = CGFloat(sin(phase + h3 * 6.3))
                let tip: CGFloat = -w * (0.55 * flap + 0.15)
                var p = Path()
                p.move(to: CGPoint(x: x - w, y: y + tip))
                p.addQuadCurve(to: CGPoint(x: x, y: y),
                               control: CGPoint(x: x - w * 0.45, y: y + w * 0.22))
                p.addQuadCurve(to: CGPoint(x: x + w, y: y + tip),
                               control: CGPoint(x: x + w * 0.45, y: y + w * 0.22))
                ctx.stroke(p, with: .color(NightBirds.sonde
                                           ? .red : .black.opacity(0.92)),
                           style: StrokeStyle(lineWidth: 1.1 * echelle,
                                              lineCap: .round))
            }
        }
        .allowsHitTesting(false)
    }

    private static func hash(_ i: Int, _ salt: Int) -> Double {
        var v = UInt64(truncatingIfNeeded: i &* 0x9E3779B1 &+ salt &* 0x85EBCA6B)
        v ^= v >> 15; v = v &* 0x2545F491_4F6CDD1D; v ^= v >> 13
        return Double(v % 100_000) / 100_000
    }
}
