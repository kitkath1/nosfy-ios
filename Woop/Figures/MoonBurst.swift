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

    /// 340 éclats — mais des ÉCLATS, pas des confettis : voir `draw`.
    private static let count = 340
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

    // TROIS RÈGLES, ET C'EST TOUT CE QUI SÉPARE UNE GERBE D'UN LANCER DE
    // CONFETTIS.
    //
    // 1. UNE ÉTINCELLE QUI FILE EST UN TRAIT, PAS UN POINT. À 700 points par
    //    seconde, un éclat parcourt douze points pendant qu'une image est
    //    affichée : l'œil, comme l'obturateur, voit une TRAÎNÉE. Des disques
    //    ronds à cette vitesse ne peuvent lire que « confetti ». On trace donc
    //    le segment parcouru, et il se raccourcit tout seul quand l'éclat
    //    ralentit — la forme raconte la vitesse sans qu'on ait à l'écrire.
    //
    // 2. LOI DE PUISSANCE SUR LES MAGNITUDES. Une nuée de très fines, quelques
    //    moyennes, deux ou trois vives : c'est la hiérarchie qui fait lire
    //    « poussière de lumière » plutôt que « semis régulier ». Exposant 3,2,
    //    la même leçon que le ciel du monolithe et que la pluie d'étoiles de
    //    la carte.
    //
    // 3. UNE COQUILLE, PAS UN NUAGE. Les vitesses se serrent autour d'une
    //    valeur commune (±28 %) au lieu de s'étaler de un à quatre : le front
    //    de l'explosion se lit comme un souffle qui s'ouvre, et non comme un
    //    sac qu'on renverse.
    private func draw(_ ctx: inout GraphicsContext, size: CGSize) {
        // L'ONDE : un cercle très fin qui s'ouvre et meurt en un tiers de
        // seconde. Trois points d'épaisseur, presque rien — mais c'est lui qui
        // donne l'échelle du souffle, et sans lui la gerbe flotte.
        if age < 0.42 {
            let u = age / 0.42
            let r = 24 + 420 * (1 - pow(1 - u, 2.2))
            let a = (1 - u) * (1 - u) * 0.5
            ctx.stroke(Path(ellipseIn: CGRect(x: origin.x - r, y: origin.y - r,
                                              width: r * 2, height: r * 2)),
                       with: .color(Color(red: 1.0, green: 0.93, blue: 0.80)
                           .opacity(a)),
                       lineWidth: 1.2 + 1.6 * (1 - u))
        }

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

            // UNE COQUILLE, pas un nuage : les vitesses se serrent autour
            // d'une valeur commune. Un souffle qui s'ouvre, et non un sac
            // qu'on renverse.
            let ang = h1 * 2 * .pi
            let speed = 620 * (0.72 + 0.56 * h2)
            // Traînée exponentielle : l'éclat part vite et se pose. Intégrale
            // exacte, jamais une position intégrée image par image.
            let drag = 3.1
            let travelled = speed * (1 - exp(-drag * a)) / drag
            // Le poids est un MURMURE. À 150 les éclats retombaient en cloche
            // — le geste d'un feu d'artifice de kermesse. Une poussière de
            // lumière ne pèse presque rien : elle s'ouvre et s'éteint.
            let gravity = 26.0 * a * a
            let flyX = origin.x + cos(ang) * travelled
            let flyY = origin.y + sin(ang) * travelled * 0.92 + gravity

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

            // LA MAGNITUDE SUIT UNE LOI DE PUISSANCE — exposant 3,2. La très
            // grande majorité des éclats sont à la limite du visible ; deux ou
            // trois portent la lumière. C'est cette hiérarchie, et elle seule,
            // qui fait lire « poussière » au lieu de « semis ».
            let mag = 0.055 + 0.945 * pow(h3, 3.2)
            let w = (0.30 + 1.15 * mag) * (0.6 + 0.4 * (1 - u))
            let alpha = env * tw * (0.16 + 0.84 * mag)

            // ET ON TRACE LE SEGMENT PARCOURU, pas un disque. À six cents
            // points par seconde, l'éclat couvre dix points le temps d'une
            // image : l'œil voit une TRAÎNÉE. Un rond, à cette vitesse, ne
            // peut lire que « confetti ». Le trait se raccourcit tout seul
            // quand la traînée freine — la forme raconte la vitesse sans
            // qu'on ait à l'écrire — et redevient un point à l'arrivée.
            let back = max(a - 0.026, 0)
            let tBack = speed * (1 - exp(-drag * back)) / drag
            let bx0 = origin.x + cos(ang) * tBack
            let by0 = origin.y + sin(ang) * tBack * 0.92 + 26.0 * back * back
            let px = bx0 + (land.x - bx0) * k
            let py = by0 + (land.y - by0) * k

            var seg = Path()
            seg.move(to: CGPoint(x: px, y: py))
            seg.addLine(to: CGPoint(x: x, y: y))
            ctx.stroke(seg, with: .color(col.opacity(alpha)),
                       style: StrokeStyle(lineWidth: w, lineCap: .round))
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
