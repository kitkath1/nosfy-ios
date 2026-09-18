import CoreText
import SwiftUI
import UIKit

// MARK: - Semis de points d'un glyphe

/// Un caractère transformé en nuage de points. Le chiffre n'est JAMAIS dessiné
/// comme du texte : on récupère le contour exact du glyphe et on sème une trame
/// hexagonale à l'intérieur. Ce sont ces points, et eux seuls, qui portent la
/// lumière — d'où la lecture « pointillisme » plutôt que « texte blanc flouté ».
///
/// Le semis ne dépend que du couple (caractère, taille) : il est calculé une
/// fois puis mémorisé. À l'exécution, changer de seconde ne coûte rien.
enum GlyphCloud {

    /// Un glyphe semé. Les ordonnées ont pour origine la LIGNE DE BASE, et sont
    /// donc négatives au-dessus d'elle. C'est ce qui permet d'aligner un « : »
    /// avec des chiffres sans le moindre cas particulier : tous les glyphes
    /// partagent la même référence, celle de la typographie.
    struct Cloud {
        var points: [CGPoint]
        var width: CGFloat
        var height: CGFloat

        static let empty = Cloud(points: [], width: 0, height: 0)
    }

    /// Pas de la trame, en fraction de la taille de police. Plus il est grand,
    /// plus le chiffre est aéré — et plus il faut de bloom pour qu'il se
    /// referme à l'œil.
    private static let pitchRatio: CGFloat = 0.078

    private static let lock = NSLock()
    private static var cache: [String: Cloud] = [:]

    static func cloud(for character: Character, size: CGFloat) -> Cloud {
        let key = "\(character)@\(Int(size.rounded()))"

        lock.lock()
        if let hit = cache[key] {
            lock.unlock()
            return hit
        }
        lock.unlock()

        let built = build(character, size: size)

        lock.lock()
        cache[key] = built
        lock.unlock()
        return built
    }

    // MARK: Construction

    private static func build(_ character: Character, size: CGFloat) -> Cloud {
        guard let path = outline(character, size: size) else { return .empty }
        let box = path.boundingBoxOfPath
        guard box.width.isFinite, box.height.isFinite,
              box.width > 0, box.height > 0 else { return .empty }

        let pitch = max(2, size * pitchRatio)
        // Trame hexagonale : les rangées sont espacées de √3/2 fois le pas et
        // décalées d'un demi-pas une fois sur deux. Une trame carrée se lirait
        // comme un quadrillage — le regard accroche les alignements verticaux.
        let rowStep = pitch * 0.866
        let rows = Int((box.height / rowStep).rounded(.up)) + 1
        let cols = Int((box.width / pitch).rounded(.up)) + 1

        var points: [CGPoint] = []
        points.reserveCapacity(rows * cols / 2)

        // L'ordre de balayage est significatif : il est identique d'un glyphe à
        // l'autre, donc le point d'indice n d'un chiffre et celui du suivant se
        // trouvent à des hauteurs comparables. C'est ce qui rend le morphisme
        // d'une seconde à l'autre cohérent sans le moindre appariement calculé.
        for row in 0...rows {
            let y = box.minY + CGFloat(row) * rowStep
            let stagger = row.isMultiple(of: 2) ? 0 : pitch / 2
            for col in 0...cols {
                let x = box.minX + CGFloat(col) * pitch + stagger
                // Bruit déterministe : sans lui la trame reste lisible en tant
                // que trame, et le procédé saute aux yeux.
                let jx = (hash(row, col, 1) - 0.5) * pitch * 0.55
                let jy = (hash(row, col, 2) - 0.5) * pitch * 0.55
                let point = CGPoint(x: x + jx, y: y + jy)
                if path.contains(point, using: .winding) {
                    points.append(point)
                }
            }
        }

        return Cloud(points: points, width: box.width, height: -box.minY)
    }

    /// Le contour du glyphe, retourné en repère écran (y vers le bas) et calé
    /// sur la ligne de base.
    private static func outline(_ character: Character, size: CGFloat) -> CGPath? {
        let base = UIFont.systemFont(ofSize: size, weight: .thin)
        // SF Rounded, comme partout ailleurs dans l'app. Le semis abstrait déjà
        // beaucoup la forme, mais les terminaisons rondes se lisent encore.
        let font = base.fontDescriptor.withDesign(.rounded)
            .map { UIFont(descriptor: $0, size: size) } ?? base

        let ctFont = font as CTFont
        var units = Array(String(character).utf16)
        var glyphs = [CGGlyph](repeating: 0, count: units.count)
        guard CTFontGetGlyphsForCharacters(ctFont, &units, &glyphs, units.count),
              let glyph = glyphs.first,
              let path = CTFontCreatePathForGlyph(ctFont, glyph, nil) else { return nil }

        let box = path.boundingBoxOfPath
        guard box.width.isFinite, box.height.isFinite else { return nil }

        // On ramène l'abscisse à zéro et on retourne l'axe vertical. La ligne de
        // base reste à y = 0 : elle n'est pas translatée, c'est tout l'intérêt.
        var transform = CGAffineTransform(translationX: -box.minX, y: 0)
            .concatenating(CGAffineTransform(scaleX: 1, y: -1))
        return path.copy(using: &transform)
    }

    /// Même idiome de pseudo-aléatoire que le reste du projet : déterministe,
    /// sans état, stable d'une image à l'autre.
    private static func hash(_ a: Int, _ b: Int, _ salt: Int) -> CGFloat {
        let v = sin(Double(a) * 127.1 + Double(b) * 311.7 + Double(salt) * 74.7) * 43758.5453
        return CGFloat(v - v.rounded(.down))
    }
}

// MARK: - Le cadran

/// La page de séance : un anneau de points qui s'allument, et au centre le
/// chrono en pointillisme de lumière. Tout est dérivé du temps absolu — aucun
/// état accumulé, donc revenir d'arrière-plan affiche la bonne valeur sans le
/// moindre rattrapage.
struct LightDial: View {
    let startedAt: Date
    /// Vrai sous Reduce Motion : la cadence tombe à 1 Hz et les micro-dérives
    /// s'arrêtent. Le chrono, lui, continue de compter — il n'est pas décoratif.
    var calm = false

    /// Douze points, un toutes les cinq secondes : un tour vaut exactement une
    /// minute. C'est la seule géométrie qui justifie le « toutes les 5 s »
    /// autrement que par un chiffre arbitraire.
    private static let dotCount = 12
    private static let stepSeconds: Double = 5

    /// Durée de la floraison d'un point, et du morphisme d'un chiffre.
    private static let ignition: Double = 0.6
    private static let morph: Double = 0.45

    var body: some View {
        TimelineView(.animation(minimumInterval: calm ? 1.0 : 1.0 / 30.0)) { timeline in
            let elapsed = max(0, timeline.date.timeIntervalSince(startedAt))

            Canvas(opaque: false, colorMode: .nonLinear, rendersAsynchronously: false) { ctx, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) * 0.33
                drawRing(&ctx, center: center, radius: radius, elapsed: elapsed)
                drawNumerals(&ctx, center: center, fontSize: radius * 0.92, elapsed: elapsed)
            }
            // On ajoute de la lumière à du noir, on ne le grise jamais.
            .blendMode(.plusLighter)
        }
        .allowsHitTesting(false)
    }

    // MARK: L'anneau

    /// La comète : le point de tête est le plus gros et le plus blanc, ceux qui
    /// l'ont précédé décroissent en rayon et en luminosité derrière lui. Les
    /// points pas encore allumés n'existent pas — pas de piste en pointillé,
    /// sinon l'anneau se lit comme une jauge et non comme une lumière.
    private func drawRing(_ ctx: inout GraphicsContext, center: CGPoint,
                          radius: CGFloat, elapsed: Double) {
        let step = Int(floor(elapsed / Self.stepSeconds))
        let sinceStep = elapsed - Double(step) * Self.stepSeconds
        let bloom = min(1, sinceStep / Self.ignition)
        // Lissage en S : un point qui apparaît linéairement « pope ».
        let eased = bloom * bloom * (3 - 2 * bloom)

        let oldest = min(step, Self.dotCount - 1)
        guard oldest >= 0 else { return }

        // Du plus ancien vers la tête : la tête est peinte en dernier, donc
        // c'est elle qui domine là où les halos se recouvrent.
        for age in stride(from: oldest, through: 0, by: -1) {
            var intensity = pow(1 - Double(age) / Double(Self.dotCount - 1), 1.9)
            if age == 0 {
                // La tête grandit dans sa place au lieu d'y apparaître, et
                // respire ensuite très légèrement — le même souffle que l'orbe
                // de la séance en cours.
                intensity *= (0.34 + 0.66 * eased) * (1 + 0.08 * sin(elapsed * 1.5))
            }
            guard intensity > 0.01 else { continue }

            let index = ((step - age) % Self.dotCount + Self.dotCount) % Self.dotCount
            // Le premier point est en haut, la course se fait dans le sens des
            // aiguilles d'une montre.
            let angle = -Double.pi / 2 + Double(index) * 2 * .pi / Double(Self.dotCount)
            let position = CGPoint(x: center.x + radius * cos(angle),
                                   y: center.y + radius * sin(angle))

            let core = 2.0 + 5.2 * intensity
            let halos: [(scale: Double, alpha: Double)] = [
                (4.2, 0.11), (2.1, 0.28), (1.0, 0.97)
            ]
            for halo in halos {
                let r = CGFloat(core * halo.scale)
                let rect = CGRect(x: position.x - r, y: position.y - r,
                                  width: r * 2, height: r * 2)
                ctx.fill(Path(ellipseIn: rect), with: .radialGradient(
                    Gradient(colors: [.white.opacity(halo.alpha * intensity), .clear]),
                    center: position, startRadius: 0, endRadius: r))
            }
        }
    }

    // MARK: Le chrono

    private func drawNumerals(_ ctx: inout GraphicsContext, center: CGPoint,
                              fontSize: CGFloat, elapsed: Double) {
        let whole = Int(elapsed)
        let current = Self.label(whole)
        let previous = Self.label(max(0, whole - 1))

        let raw = min(1, (elapsed - Double(whole)) / Self.morph)
        let progress = calm ? 1 : raw * raw * (3 - 2 * raw)

        // Les points sont répartis en paliers d'opacité : quelques remplissages
        // par image au lieu d'un par point. Même parade que le champ de
        // poussière de l'atmosphère, pour la même raison.
        let levels = 5
        var buckets = [[CGPoint]](repeating: [], count: levels)

        func place(_ point: CGPoint, alpha: Double) {
            guard alpha > 0.02 else { return }
            let bucket = min(levels - 1, max(0, Int(alpha * Double(levels))))
            buckets[bucket].append(point)
        }

        // Chasse fixe imposée par la mise en page, jamais par la police : sans
        // ça le nuage change de largeur chaque seconde et l'ensemble tressaute.
        func advance(_ character: Character) -> CGFloat {
            character == ":" ? fontSize * 0.30 : fontSize * 0.62
        }

        let currentChars = Array(current)
        let previousChars = Array(previous)
        // Le morphisme point à point suppose deux chaînes superposables. Aux
        // rares changements de longueur (9:59 → 10:00) on croise en fondu.
        let morphable = currentChars.count == previousChars.count

        let total = currentChars.reduce(CGFloat(0)) { $0 + advance($1) }
        let reference = GlyphCloud.cloud(for: "0", size: fontSize)
        let baseline = center.y + reference.height / 2
        var cursor = center.x - total / 2

        func screen(_ point: CGPoint, at x: CGFloat) -> CGPoint {
            CGPoint(x: x + point.x, y: baseline + point.y)
        }

        for (slot, character) in currentChars.enumerated() {
            let cloud = GlyphCloud.cloud(for: character, size: fontSize)
            let slotStart = cursor
            let slotWidth = advance(character)
            cursor += slotWidth
            let originX = slotStart + (slotWidth - cloud.width) / 2

            let old = morphable ? previousChars[slot] : character
            guard old != character, progress < 1 else {
                for point in cloud.points { place(screen(point, at: originX), alpha: 1) }
                continue
            }

            // Le chiffre sortant se réorganise en le chiffre entrant : les
            // points glissent d'une forme à l'autre. Ceux qui n'ont pas de
            // correspondant s'éteignent ou s'allument sur place.
            let from = GlyphCloud.cloud(for: old, size: fontSize)
            let fromX = slotStart + (slotWidth - from.width) / 2
            let shared = min(from.points.count, cloud.points.count)

            for index in 0..<shared {
                let a = screen(from.points[index], at: fromX)
                let b = screen(cloud.points[index], at: originX)
                place(CGPoint(x: a.x + (b.x - a.x) * progress,
                              y: a.y + (b.y - a.y) * progress), alpha: 1)
            }
            for index in shared..<from.points.count {
                place(screen(from.points[index], at: fromX), alpha: 1 - progress)
            }
            for index in shared..<cloud.points.count {
                place(screen(cloud.points[index], at: originX), alpha: progress)
            }
        }

        // Trois couronnes concentriques plutôt qu'un flou : un dégradé radial
        // par point coûterait mille remplissages par image, et un filtre de
        // flou impose une passe hors écran. Trois cercles plats donnent la même
        // décroissance à l'œil, pour rien.
        let dot = max(1.0, fontSize * 0.017)
        let layers: [(scale: CGFloat, alpha: Double)] = [
            (3.4, 0.055), (1.9, 0.13), (1.0, 0.92)
        ]

        for layer in layers {
            let r = dot * layer.scale
            for level in 0..<levels where !buckets[level].isEmpty {
                var path = Path()
                for point in buckets[level] {
                    path.addEllipse(in: CGRect(x: point.x - r, y: point.y - r,
                                               width: r * 2, height: r * 2))
                }
                let alpha = (Double(level) + 0.5) / Double(levels) * layer.alpha
                ctx.fill(path, with: .color(.white.opacity(alpha)))
            }
        }
    }

    // MARK: Habillage

    /// « 4:07 », « 12:30 », « 1:04:22 ».
    static func label(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        let padded = String(format: "%02d", secs)
        if hours > 0 {
            return "\(hours):\(String(format: "%02d", minutes)):\(padded)"
        }
        return "\(minutes):\(padded)"
    }

    /// Ce que VoiceOver doit entendre — le nuage de points, lui, est muet.
    static func spoken(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        switch (minutes, secs) {
        case (0, let s): return "\(s) seconde\(s > 1 ? "s" : "")"
        case (let m, 0): return "\(m) minute\(m > 1 ? "s" : "")"
        case (let m, let s): return "\(m) minute\(m > 1 ? "s" : "") \(s)"
        }
    }
}
