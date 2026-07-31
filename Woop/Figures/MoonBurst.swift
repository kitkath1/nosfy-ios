import SwiftUI

// MARK: - L'éclat : le monolithe explose, et la lune se rassemble
//
// Le raccord entre la cinématique et la page de connexion. Le pavé ne
// rapetisse plus en filant vers son coin — il DÉTONE, et ses éclats se
// rassemblent pour redevenir la lune, posée, à sa place.
//
// L'idée qui fait tout : les particules ne se contentent pas de retomber. Après
// la moitié de leur vie, elles sont RAPPELÉES vers le point de pose. On ne
// regarde donc pas une explosion puis, séparément, un objet qui apparaît : on
// regarde une explosion QUI DEVIENT l'objet. C'est le même geste, et c'est ce
// qui rend le raccord inévitable au lieu d'arbitraire.
//
// Fonction PURE DU TEMPS, comme tout le reste du plan : `age` entre, l'image
// sort. Rien ne s'accumule, la séquence se rejoue à l'identique, et
// `-moonSplashFreeze` fige l'éclat aussi bien que le travelling.
struct MoonBurst: View {
    /// Secondes écoulées depuis la détonation. Négatif = rien.
    var age: Double
    /// D'où part la gerbe et où elle se rassemble, en points.
    var origin: CGPoint
    var target: CGPoint

    /// 260 éclats : en dessous on compte les points, au-dessus le Canvas
    /// commence à peser plus que le shader qu'il recouvre.
    private static let count = 260
    private static let life: Double = 2.05
    /// L'instant du RAPPEL : avant, les éclats fuient ; après, ils reviennent.
    private static let recall: Double = 0.62

    var body: some View {
        Canvas(opaque: false, colorMode: .nonLinear,
               rendersAsynchronously: false) { ctx, size in
            guard age >= 0, age < Self.life else { return }
            draw(&ctx, size: size)
        }
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }

    private func draw(_ ctx: inout GraphicsContext, size: CGSize) {
        for i in 0..<Self.count {
            let h1 = Self.hash(i, 11), h2 = Self.hash(i, 29)
            let h3 = Self.hash(i, 47), h4 = Self.hash(i, 71)

            // Une gerbe parfaitement synchrone se lit comme une forme qui
            // grandit, pas comme une explosion : chacun part à son heure.
            let delay = 0.055 * h4
            let a = age - delay
            guard a > 0 else { continue }
            let span = Self.life - delay
            let u = a / span
            guard u < 1 else { continue }

            // Direction : légèrement biaisée vers le haut, comme toute gerbe
            // qui a de l'élan et pas encore de poids.
            let ang = h1 * 2 * .pi
            let speed = 260 + 720 * h2 * h2
            // Traînée exponentielle : l'éclat part vite et se pose. Intégrale
            // exacte, jamais une position intégrée image par image.
            let drag = 3.1
            let travelled = speed * (1 - exp(-drag * a)) / drag
            let gravity = 150.0 * a * a
            let flyX = origin.x + cos(ang) * travelled
            let flyY = origin.y + sin(ang) * travelled * 0.86 + gravity

            // LE RAPPEL. Après 62 % de la course, l'éclat est repris par la
            // lune qui se reforme — d'autant plus vite qu'il est petit.
            let pull = Self.smooth(min(max((u - Self.recall) / (1 - Self.recall), 0), 1))
            let eager = 0.55 + 0.45 * h3
            let k = min(pull * eager * 1.35, 1)
            // Le point de rassemblement est légèrement dispersé : 260 points
            // exactement confondus feraient une étoile, pas une lune.
            let jitterR = 26.0 * (1 - k) + 9.0 * h2
            let land = CGPoint(x: target.x + cos(ang * 3.1 + h1) * jitterR,
                               y: target.y + sin(ang * 3.1 + h1) * jitterR)
            let x = flyX + (land.x - flyX) * k
            let y = flyY + (land.y - flyY) * k

            // L'enveloppe : naissance franche, longue vie, extinction douce
            // pile quand la lune, elle, achève de s'allumer.
            let env = min(u / 0.05, 1) * (1 - Self.smooth(min(max((u - 0.55) / 0.45, 0), 1)))
            guard env > 0.01 else { continue }
            let tw = 0.62 + 0.38 * sin(a * (7 + 9 * h3) + h1 * 6.28)

            // Blanc au cœur de l'explosion, or en s'éloignant : la couleur
            // raconte la température, pas la décoration.
            let warm = min(travelled / 420.0, 1)
            let col = Color(red: 1.0,
                            green: 0.97 - 0.23 * warm,
                            blue: 0.90 - 0.55 * warm)
            let r = (0.9 + 2.0 * h3 * h3) * (0.55 + 0.45 * (1 - u))
            ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r,
                                            width: r * 2, height: r * 2)),
                     with: .color(col.opacity(env * tw)))
        }
    }

    private static func smooth(_ x: Double) -> Double { x * x * (3 - 2 * x) }

    private static func hash(_ i: Int, _ salt: Int) -> Double {
        var v = UInt64(truncatingIfNeeded: i &* 0x9E3779B1 &+ salt &* 0x85EBCA6B)
        v ^= v >> 15; v = v &* 0x2545F491_4F6CDD1D; v ^= v >> 13
        return Double(v % 100_000) / 100_000
    }
}

// MARK: - Le flash

/// L'éclair de la détonation : un cœur blanc qui devient or en s'étalant, sur
/// tout l'écran. En `plusLighter`, donc il ne peut qu'AJOUTER de la lumière —
/// jamais laver l'image en gris.
struct MoonFlash: View {
    var intensity: Double
    var origin: CGPoint

    var body: some View {
        GeometryReader { geo in
            let d = max(geo.size.width, geo.size.height)
            // UN ÉCLAIR, PAS UN VOILE. Le premier réglage portait la jupe du
            // dégradé à 1 086 points — bien au-delà du cadre —, si bien que ses
            // tons moyens couvraient TOUT l'écran : la détonation lavait l'image
            // en beige, exactement le défaut que cette maison passe son temps à
            // chasser. Un éclair a un cœur brûlant et une chute rapide : la
            // portée tombe à 0,42 de l'écran, et deux arrêts intermédiaires
            // rapprochés font mourir la lumière au lieu de l'étaler.
            RadialGradient(
                stops: [
                    .init(color: Color(red: 1.0, green: 0.99, blue: 0.96)
                        .opacity(intensity), location: 0),
                    .init(color: Color(red: 1.0, green: 0.86, blue: 0.55)
                        .opacity(intensity * 0.55), location: 0.16),
                    .init(color: Color(red: 1.0, green: 0.58, blue: 0.20)
                        .opacity(intensity * 0.16), location: 0.42),
                    .init(color: .clear, location: 1),
                ],
                center: UnitPoint(x: origin.x / max(geo.size.width, 1),
                                  y: origin.y / max(geo.size.height, 1)),
                startRadius: 0,
                endRadius: d * (0.14 + 0.28 * intensity))
        }
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }
}
