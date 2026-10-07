import SwiftUI
import UIKit

// MARK: - LE FOND DES FEUILLES DE SÉANCE (07-10-2026)
//
// Ses mots : « les overlays dans l'app, tu peux les faire en dégradé de noir,
// le background quand on choisit un exo, et tout liquid glass aussi (celle
// aussi où on voit les séries) » ; « et des fois des dégradés aussi fins de
// rouge orangé, comme des petites braises, des filaments dans le header de
// l'overlay ».
//
// ⚠️ NI MATÉRIAU NI VERRE NATIF SOUS LE DOIGT : la feuille se tire vers le
// bas. Un flou (`.ultraThinMaterial`, l'ancien fond) ou un `glassEffect`
// déplacé à chaque image se ré-échantillonne à chaque image (mesuré sur son
// téléphone : un verre natif animé, 60 → 14 img/s). Le verre est DESSINÉ :
// le noir en dégradé, l'arête et sa lumière, une seconde arête pour
// l'épaisseur — c'est le `VerreV7` des cartes, à l'échelle d'une feuille.

struct FondFeuilleNoire: View {
    var rayon: CGFloat = 44
    var braises = true
    /// Barreau : la feuille sans ses braises.
    static let sansBraises = CommandLine.arguments.contains("-sansBraisesFeuille")

    var body: some View {
        let forme = RoundedRectangle(cornerRadius: rayon, style: .continuous)
        ZStack(alignment: .top) {
            LinearGradient(stops: [.init(color: Color(white: 0.09), location: 0),
                                   .init(color: Color(white: 0.035), location: 0.34),
                                   .init(color: .black, location: 1)],
                           startPoint: .top, endPoint: .bottom)
            // La lumière prise dans l'épaisseur du verre, sous l'arête haute.
            LinearGradient(colors: [.white.opacity(0.07), .clear],
                           startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.09))
            if braises && !Self.sansBraises {
                BraisesTete()
                    .frame(height: 118)
            }
            // La seconde arête : l'épaisseur.
            forme.inset(by: 2.5)
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.10), .white.opacity(0.02),
                                                      .white.opacity(0.05)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing),
                              lineWidth: 0.5)
        }
        .clipShape(forme)
    }
}

/// LES BRAISES DE LA TÊTE. Au bord haut, des filaments plus fins qu'un
/// pixel, rouge sombre, dont la brillance vient de petits points blancs
/// chauds ; un HALO rouge qui vit autour d'eux (il gonfle, respire, dérive de
/// quelques points sur place) ; et des BRAISES qui naissent des filaments,
/// montent en scintillant, refroidissent (blanc chaud → orangé → rouge qui
/// meurt) et s'éteignent. Tirés au hasard à chaque ouverture.
///
/// Ses mots, 07-10 : « le rouge et les braises beaucoup plus fins » ; « on
/// voit pas l'animation des braises : hyper réaliste, délicate, et filament et
/// halo dans le haut du header » ; « trop cheap : halo rouge qui bouge plus,
/// le filament plus fin, l'animation plus jolie ».
///
/// ⚠️ CHAUFFE : rien ne passe par SwiftUI image par image. Filaments et halo
/// sont dessinés UNE fois ; tout ce qui vit est Core Animation (opacités,
/// dérive et souffle des halos, `CAEmitterLayer` des braises) et tourne dans
/// le serveur de rendu : le fil principal ne fait rien. Aucun masque (un
/// masque sur une couche vivante = rendu hors écran à chaque image).
/// Jamais de balayage : le point chaud d'un filament ne voyage pas, il passe
/// d'un endroit à l'autre en fondu ; le halo bouge de quelques points, sur
/// place. Anti-brun : R reste à 1,00, la clarté vient d'un point blanc.
/// Barreaux : `-sansBraisesFeuille` (tout), `-braisesFeuilleFigees` (le
/// dessin sans aucune animation).
struct BraisesTete: View {
    static let figees = CommandLine.arguments.contains("-braisesFeuilleFigees")
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        BraisesVivantes(vivantes: !reduceMotion && !Self.figees
                            && !ProtectionThermique.shared.ambianceAuRepos)
            .allowsHitTesting(false)
    }
}

private struct BraisesVivantes: UIViewRepresentable {
    let vivantes: Bool
    func makeUIView(context: Context) -> VueBraises { VueBraises(vivantes: vivantes) }
    func updateUIView(_ vue: VueBraises, context: Context) {}
}

/// Un tirage reproductible (SplitMix64) : la même graine, le même dessin.
private struct HasardBraise {
    var s: UInt64
    mutating func suivant() -> CGFloat {
        s &+= 0x9E37_79B9_7F4A_7C15
        var z = s
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        return CGFloat(Double(z >> 11) / Double(UInt64(1) << 53))
    }
    mutating func entre(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * suivant() }
}

private struct FilBraise {
    var p0, c1, c2, p3: CGPoint
    var epaisseur: CGFloat

    var chemin: CGPath {
        let p = CGMutablePath()
        p.move(to: p0)
        p.addCurve(to: p3, control1: c1, control2: c2)
        return p
    }
    var longueur: CGFloat { hypot(p3.x - p0.x, p3.y - p0.y) }

    func point(_ t: CGFloat) -> CGPoint {
        let u = 1 - t
        return CGPoint(x: u * u * u * p0.x + 3 * u * u * t * c1.x + 3 * u * t * t * c2.x + t * t * t * p3.x,
                       y: u * u * u * p0.y + 3 * u * u * t * c1.y + 3 * u * t * t * c2.y + t * t * t * p3.y)
    }

    /// Deux à quatre filaments presque couchés, dans le HAUT de la tête :
    /// tout le tracé tient entre 5 pt et 34 % de la bande (capture du 07-10 :
    /// un fil penché descendait jusqu'au titre et à la vignette).
    static func tirer(_ graine: UInt64, _ size: CGSize) -> [FilBraise] {
        var h = HasardBraise(s: graine)
        let haut: CGFloat = 5, bas = size.height * 0.34
        func dans(_ y: CGFloat) -> CGFloat { min(max(y, haut), bas) }
        var fils: [FilBraise] = []
        for _ in 0 ..< 2 + Int(h.suivant() * 2.99) {
            let long = h.entre(90, 210)
            let x0 = h.entre(-30, size.width - long * 0.55)
            let y0 = h.entre(size.height * 0.07, size.height * 0.24)
            let p3 = CGPoint(x: x0 + long, y: dans(y0 + long * h.entre(-0.08, 0.08)))
            fils.append(FilBraise(p0: CGPoint(x: x0, y: y0),
                                  c1: CGPoint(x: x0 + long * 0.33, y: dans(y0 + h.entre(-7, 7))),
                                  c2: CGPoint(x: x0 + long * 0.66, y: dans(p3.y + h.entre(-7, 7))),
                                  p3: p3, epaisseur: h.entre(0.2, 0.3)))
        }
        return fils
    }
}

private final class VueBraises: UIView {
    private let vivantes: Bool
    private let graine = UInt64.random(in: 1 ... .max)
    private var taille: CGSize = .zero

    init(vivantes: Bool) {
        self.vivantes = vivantes
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        clipsToBounds = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) n'est pas utilisé") }

    override func layoutSubviews() {
        super.layoutSubviews()
        // La feuille se tire par translation : la taille ne bouge pas, on ne
        // redessine qu'à la naissance (ou à une vraie nouvelle taille).
        guard bounds.width > 0, bounds.height > 0, bounds.size != taille else { return }
        taille = bounds.size
        construire()
    }

    private func construire() {
        layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        let fils = FilBraise.tirer(graine, bounds.size)
        guard !fils.isEmpty else { return }

        // Le halo qui vit : un souffle rouge par filament, posé sur son point
        // chaud, qui gonfle, respire et dérive de quelques points, sur place.
        let souffles = fils.prefix(3).enumerated().map { rang, f in
            souffle(en: f.point(0.58), largeur: min(max(f.longueur * 0.95, 110), 210), rang: rang)
        }
        souffles.forEach(layer.addSublayer)

        let halo = calqueImage { ctx in
            for f in fils {
                Self.trait(ctx, f, largeur: 5, Self.haloLarge)
                Self.trait(ctx, f, largeur: 2, Self.haloSerre)
            }
        }
        // Deux états du même filament : chaud au milieu, ou chaud à ses
        // deux tiers. Ils se relaient en fondu — le point chaud change de
        // place sans jamais traverser.
        let chaudA = calqueImage { ctx in
            for f in fils { Self.trait(ctx, f, largeur: f.epaisseur, Self.filA) }
        }
        let chaudB = calqueImage { ctx in
            for f in fils { Self.trait(ctx, f, largeur: f.epaisseur, Self.filB) }
        }
        layer.addSublayer(halo)
        layer.addSublayer(chaudA)
        layer.addSublayer(chaudB)

        guard vivantes else { chaudB.opacity = 0; return }
        let decale = Double(graine % 1000) / 1000
        animer(chaudA, "opacity", [1, 0.2, 0.85, 0.3, 1], duree: 4.2, decale)
        animer(chaudB, "opacity", [0.2, 1, 0.3, 0.9, 0.2], duree: 4.2, decale)
        animer(halo, "opacity", [0.5, 1, 0.7, 0.95, 0.5], duree: 3.3, decale)
        for (rang, s) in souffles.enumerated() {
            let r = Double(rang), p = s.position
            animer(s, "position", [p, CGPoint(x: p.x + 7, y: p.y - 2), CGPoint(x: p.x - 5, y: p.y + 1.5),
                                   CGPoint(x: p.x + 3, y: p.y + 2.5), p].map { NSValue(cgPoint: $0) },
                   duree: 6.1 + r * 1.3, decale)
            animer(s, "transform.scale", [1, 1.22, 0.86, 1.12, 1], duree: 4.4 + r * 0.9, decale)
            animer(s, "opacity", [0.55, 1, 0.7, 0.95, 0.55], duree: 3.1 + r * 0.7, decale)
        }

        // Les braises naissent des points chauds.
        for f in fils {
            for (t, poids) in [(0.34, 0.9), (0.58, 1.3), (0.8, 0.9)] as [(CGFloat, Float)] {
                let p = f.point(t)
                guard p.x > 40, p.x < bounds.width - 40 else { continue }
                layer.addSublayer(emetteur(en: p, largeur: f.longueur * 0.14, poids: poids))
            }
        }
    }

    private func souffle(en p: CGPoint, largeur: CGFloat, rang: Int) -> CAGradientLayer {
        let g = CAGradientLayer()
        g.type = .radial
        g.bounds = CGRect(x: 0, y: 0, width: largeur, height: 58)
        g.position = p
        g.colors = [UIColor(red: 1, green: 0.13, blue: 0.04, alpha: 0.24).cgColor,
                    UIColor(red: 1, green: 0.09, blue: 0.03, alpha: 0.08).cgColor,
                    UIColor(red: 1, green: 0.08, blue: 0.03, alpha: 0).cgColor]
        g.locations = [0, 0.42, 1]
        g.startPoint = CGPoint(x: 0.5, y: 0.5)
        g.endPoint = CGPoint(x: 1, y: 1)
        return g
    }

    private func calqueImage(_ dessin: (CGContext) -> Void) -> CALayer {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = max(traitCollection.displayScale, 2)
        let image = UIGraphicsImageRenderer(size: bounds.size, format: format).image { dessin($0.cgContext) }
        let calque = CALayer()
        calque.frame = bounds
        calque.contents = image.cgImage
        calque.contentsScale = format.scale
        return calque
    }

    private static func trait(_ ctx: CGContext, _ f: FilBraise, largeur: CGFloat, _ degrade: CGGradient) {
        ctx.saveGState()
        ctx.addPath(f.chemin.copy(strokingWithWidth: largeur, lineCap: .round, lineJoin: .round, miterLimit: 2))
        ctx.clip()
        ctx.drawLinearGradient(degrade, start: f.p0, end: f.p3, options: [])
        ctx.restoreGState()
    }

    /// Une animation en boucle, douce (cubique), désaccordée d'une ouverture
    /// à l'autre ; elle survit au retour d'arrière-plan.
    private func animer(_ calque: CALayer, _ chemin: String, _ valeurs: [Any], duree: CFTimeInterval,
                        _ decale: Double) {
        let a = CAKeyframeAnimation(keyPath: chemin)
        a.values = valeurs
        a.calculationMode = .cubic
        a.duration = duree
        a.repeatCount = .infinity
        a.timeOffset = decale * duree
        a.isRemovedOnCompletion = false
        calque.add(a, forKey: chemin)
    }

    private func emetteur(en p: CGPoint, largeur: CGFloat, poids: Float) -> CAEmitterLayer {
        let e = CAEmitterLayer()
        e.frame = bounds
        e.emitterPosition = p
        e.emitterSize = CGSize(width: largeur, height: 1)
        e.emitterShape = .line
        e.renderMode = .additive
        e.seed = UInt32(truncatingIfNeeded: graine &+ UInt64(p.x * 31 + p.y))
        e.emitterCells = [Self.braise(poids, derive: 3), Self.braise(poids, derive: -3),
                          Self.etincelle(poids)]
        return e
    }

    /// La braise : invisible en elle-même, elle porte le mouvement (monter en
    /// dérivant) et le refroidissement ; ce qu'on voit, ce sont ses éclats —
    /// de très brèves lueurs d'éclat inégal qu'elle sème en route. D'où le
    /// SCINTILLEMENT d'une vraie braise, et sa traîne d'un cheveu.
    private static func braise(_ poids: Float, derive: CGFloat) -> CAEmitterCell {
        let c = CAEmitterCell()
        c.birthRate = 0.5 * poids
        c.lifetime = 2.2
        c.lifetimeRange = 0.7
        c.velocity = 7
        c.velocityRange = 5
        c.emissionRange = .pi * 2
        c.yAcceleration = -9
        c.xAcceleration = derive
        c.color = UIColor(red: 1, green: 0.95, blue: 0.85, alpha: 1).cgColor
        c.alphaSpeed = -0.4
        c.greenSpeed = -0.32
        c.blueSpeed = -0.5
        // ⚠️ Sans image, la cellule se dessine en CARRÉ blanc (capture du
        // 07-10) : on lui donne un pixel transparent.
        c.contents = vide
        c.emitterCells = [eclat]
        return c
    }

    private static let vide: CGImage? = {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1), format: format).image { _ in }.cgImage
    }()

    private static let eclat: CAEmitterCell = {
        let c = CAEmitterCell()
        c.contents = sprite
        c.contentsScale = 3
        c.birthRate = 22
        c.lifetime = 0.16
        c.lifetimeRange = 0.06
        c.velocity = 0
        c.scale = 0.42
        c.scaleRange = 0.22
        c.color = UIColor(white: 1, alpha: 0.55).cgColor
        c.alphaRange = 0.45
        c.alphaSpeed = -3
        return c
    }()

    /// L'étincelle : rare, vive, une fraction de seconde.
    private static func etincelle(_ poids: Float) -> CAEmitterCell {
        let c = CAEmitterCell()
        c.contents = sprite
        c.contentsScale = 3
        c.birthRate = 0.12 * poids
        c.lifetime = 0.5
        c.lifetimeRange = 0.2
        c.velocity = 24
        c.velocityRange = 10
        c.emissionRange = .pi * 2
        c.yAcceleration = -26
        c.scale = 0.28
        c.scaleSpeed = -0.3
        c.color = UIColor(red: 1, green: 1, blue: 0.95, alpha: 1).cgColor
        c.alphaSpeed = -1.8
        c.greenSpeed = -1.2
        c.blueSpeed = -1.8
        return c
    }

    /// Le grain de braise : un cœur blanc d'un demi-point, son halo orangé, le
    /// rouge qui meurt. 6 pt au total, ≤ 3 pt à l'écran.
    private static let sprite: CGImage? = {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 3
        let cote: CGFloat = 6
        return UIGraphicsImageRenderer(size: CGSize(width: cote, height: cote), format: format).image { r in
            let centre = CGPoint(x: cote / 2, y: cote / 2)
            r.cgContext.drawRadialGradient(degrade([(1, 0.97, 0.9, 1, 0), (1, 0.72, 0.42, 0.9, 0.14),
                                                    (1, 0.32, 0.09, 0.4, 0.36), (1, 0.14, 0.04, 0.1, 0.68),
                                                    (1, 0.1, 0.03, 0, 1)]),
                                           startCenter: centre, startRadius: 0,
                                           endCenter: centre, endRadius: cote / 2, options: [])
        }.cgImage
    }()

    /// Le filament : un rouge sombre et transparent ; la brillance vient d'un
    /// point presque blanc, court (jamais de l'épaisseur — « néon » = cheap).
    /// A : chaud au milieu. B : chaud au tiers et aux quatre cinquièmes.
    private static let filA = degrade([(1, 0.05, 0.02, 0, 0), (1, 0.06, 0.02, 0.3, 0.2),
                                       (1, 0.18, 0.05, 0.5, 0.44), (1, 0.5, 0.22, 0.85, 0.54),
                                       (1, 0.9, 0.8, 1, 0.58), (1, 0.45, 0.18, 0.8, 0.63),
                                       (1, 0.1, 0.03, 0.4, 0.78), (1, 0.05, 0.02, 0, 1)])
    private static let filB = degrade([(1, 0.05, 0.02, 0, 0), (1, 0.22, 0.06, 0.55, 0.27),
                                       (1, 0.88, 0.76, 1, 0.34), (1, 0.22, 0.06, 0.55, 0.41),
                                       (1, 0.06, 0.02, 0.3, 0.6), (1, 0.3, 0.1, 0.65, 0.74),
                                       (1, 0.86, 0.72, 0.95, 0.8), (1, 0.2, 0.06, 0.45, 0.86),
                                       (1, 0.05, 0.02, 0, 1)])
    private static let haloSerre = degrade([(1, 0.16, 0.04, 0, 0), (1, 0.18, 0.05, 0.14, 0.55),
                                            (1, 0.16, 0.04, 0, 1)])
    private static let haloLarge = degrade([(1, 0.12, 0.03, 0, 0), (1, 0.14, 0.04, 0.06, 0.55),
                                            (1, 0.12, 0.03, 0, 1)])

    /// (r, v, b, alpha, position)
    private static func degrade(_ arrets: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)]) -> CGGradient {
        CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                   colors: arrets.map { UIColor(red: $0.0, green: $0.1, blue: $0.2, alpha: $0.3).cgColor } as CFArray,
                   locations: arrets.map(\.4))!
    }
}
