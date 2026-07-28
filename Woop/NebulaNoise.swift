import SwiftUI

// MARK: - LUT de bruit pour le ciel nébuleuse

/// Texture 512² générée une fois au lancement et passée aux shaders du ciel
/// (un seul argument `.image` par shader — d'où les champs empilés en canaux) :
///   R : fbm 4 octaves, graine A — masses nuageuses et warp
///   G : fbm 4 octaves, graine B — seconde composante du warp, octaves alternées
///   B : ridged multifractal Musgrave 6 octaves — wisps filamentaires
///   A : constant à 255 — jamais de donnée dans l'alpha : SwiftUI peut
///       prémultiplier la texture, ce qui écraserait R, G et B.
///
/// Chaque octave est un treillis ENTIER de cellules sur la tuile et la
/// lacunarité vaut exactement 2 : toutes les octaves se referment sur les
/// bords, donc la texture se tuile sans couture avec un sampler `repeat`.
/// Dans le shader, un fetch bilinéaire remplace ~40 instructions de hash :
/// c'est ce qui rend la nébuleuse riche payable à 30 fps.
enum NebulaNoise {
    static let image: Image = Image(decorative: makeLUT(), scale: 1)

    /// À appeler tôt au lancement : la génération (~14 évaluations de bruit
    /// par texel × 262 144 texels) se paie une fois, en tâche de fond,
    /// pendant le splash — jamais au premier rendu de la home.
    static func warmUp() {
        Task.detached(priority: .userInitiated) { _ = Self.image }
    }

    private static let side = 512

    // MARK: Bruit

    /// Hash entier (xxHash-like) : déterministe, sans état, wrappable.
    private static func hash(_ x: Int, _ y: Int, _ seed: UInt32) -> Float {
        var h: UInt32 = UInt32(truncatingIfNeeded: x) &* 374_761_393
        h &+= UInt32(truncatingIfNeeded: y) &* 668_265_263
        h &+= seed &* 2_246_822_519
        h = (h ^ (h >> 13)) &* 1_274_126_177
        h ^= h >> 16
        return Float(h & 0x00FF_FFFF) * (1.0 / 16_777_215.0)
    }

    /// Bruit de valeur sur un treillis de `cells` cellules, enveloppé modulo
    /// `cells` : la condition de tileabilité.
    private static func valueNoise(_ u: Float, _ v: Float, _ cells: Int, _ seed: UInt32) -> Float {
        let x = u * Float(cells), y = v * Float(cells)
        let xi = Int(x), yi = Int(y)
        let fx = x - Float(xi), fy = y - Float(yi)
        let sx = fx * fx * (3 - 2 * fx), sy = fy * fy * (3 - 2 * fy)
        let x1 = (xi + 1) % cells, y1 = (yi + 1) % cells
        let a = hash(xi, yi, seed), b = hash(x1, yi, seed)
        let c = hash(xi, y1, seed), d = hash(x1, y1, seed)
        let top = a + (b - a) * sx
        let bot = c + (d - c) * sx
        return top + (bot - top) * sy
    }

    /// fbm 4 octaves, treillis 6→48. Graine différente par octave : les
    /// octaves d'un même canal ne s'alignent jamais entre elles.
    private static func fbm4(_ u: Float, _ v: Float, _ seed: UInt32) -> Float {
        var s: Float = 0, amp: Float = 0.5
        var cells = 6
        for octave in 0..<4 {
            s += amp * valueNoise(u, v, cells, seed &+ UInt32(octave) &* 0x9E37_79B9)
            cells *= 2
            amp *= 0.5
        }
        return s * (1.0 / 0.9375)
    }

    /// Ridged multifractal à la Musgrave : chaque octave est pondérée par la
    /// précédente, donc le détail fin ne pousse QUE sur les crêtes larges.
    /// C'est ça qui donne des filaments de largeur 1 px → 50 px qui se
    /// ramifient, au lieu d'un bruit uniformément rugueux.
    private static func ridgedMF(_ u: Float, _ v: Float, _ seed: UInt32) -> Float {
        var s: Float = 0, amp: Float = 0.5, prev: Float = 1
        var cells = 5
        for octave in 0..<6 {
            let n = valueNoise(u, v, cells, seed &+ UInt32(octave) &* 0x85EB_CA6B) * 2 - 1
            var r = 1 - abs(n)
            r = r * r
            s += r * amp * prev
            prev = min(max(r * 2, 0), 1)
            cells *= 2
            amp *= 0.5
        }
        return min(s * 1.3, 1)
    }

    // MARK: Fabrication

    private static func makeLUT() -> CGImage {
        let n = side
        var data = [UInt8](repeating: 0, count: n * n * 4)
        let inv = 1.0 as Float / Float(n)

        for j in 0..<n {
            let v = Float(j) * inv
            for i in 0..<n {
                let u = Float(i) * inv
                let k = (j * n + i) * 4
                data[k]     = UInt8(min(max(fbm4(u, v, 0x51AB_2E9D) * 255, 0), 255))
                data[k + 1] = UInt8(min(max(fbm4(u, v, 0x0BAD_5EED) * 255, 0), 255))
                data[k + 2] = UInt8(min(max(ridgedMF(u, v, 0x27D4_EB2F) * 255, 0), 255))
                data[k + 3] = 255
            }
        }

        // Espace linéaire : le bruit est une DONNÉE, pas une couleur — on ne
        // veut pas qu'une conversion sRGB→linéaire vienne la recourber au
        // moment de l'upload GPU.
        let space = CGColorSpace(name: CGColorSpace.linearSRGB) ?? CGColorSpaceCreateDeviceRGB()
        let ctx = data.withUnsafeMutableBytes { buf in
            CGContext(data: buf.baseAddress, width: n, height: n,
                      bitsPerComponent: 8, bytesPerRow: n * 4, space: space,
                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        }
        return ctx!.makeImage()!
    }
}
