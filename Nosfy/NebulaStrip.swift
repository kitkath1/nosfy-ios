import SwiftUI

// MARK: - Bande de nébuleuse cuite (carte Objectif)

/// La structure du ruban de nébuleuse de la carte « Objectif », générée UNE
/// fois au lancement — comme la LUT du ciel, mais pour la qualité : à 30 fps
/// un shader ne peut pas payer les dizaines d'octaves et l'advection qui font
/// la finesse d'une astrophoto ; ici on les paie une seule fois, sur CPU, en
/// tâche de fond pendant le splash.
///
/// Texture 1024×320, tuilable en X (le ruban dérive sans couture, jamais en Y) :
///   R : filaments fins — ridged multifractal anisotrope (étiré ~3,5×
///       horizontalement), warpé, puis ADVECTÉ le long d'un champ de courant
///       (line integral convolution) : c'est le lissé directionnel, la soie.
///   G : brume large — fbm doux, sert de voile de fond ET de rideau
///       d'occulteurs dans le shader.
///   B : seconde couche de filaments (autre graine) — la parallaxe de
///       profondeur du ruban.
///   A : 255 — jamais de donnée dans l'alpha (prémultiplication).
///
/// Un fenêtrage vertical fond les bords haut/bas à zéro : le sampler clamp
/// du shader ne peut jamais étirer une rangée non nulle.
enum NebulaStrip {
    static let image: Image = Image(decorative: make(), scale: 1)

    /// À appeler tôt au lancement, à côté de NebulaNoise.warmUp().
    static func warmUp() {
        Task.detached(priority: .userInitiated) { _ = Self.image }
    }

    private static let width = 1024
    private static let height = 320

    // MARK: Bruit (treillis enveloppé en X seulement)

    private static func hash(_ x: Int, _ y: Int, _ seed: UInt32) -> Float {
        var h: UInt32 = UInt32(truncatingIfNeeded: x) &* 374_761_393
        h &+= UInt32(truncatingIfNeeded: y) &* 668_265_263
        h &+= seed &* 2_246_822_519
        h = (h ^ (h >> 13)) &* 1_274_126_177
        h ^= h >> 16
        return Float(h & 0x00FF_FFFF) * (1.0 / 16_777_215.0)
    }

    /// Bruit de valeur : X enveloppé modulo `cellsX` (tileabilité), Y libre.
    private static func vnoise(_ u: Float, _ v: Float,
                               _ cellsX: Int, _ cellsY: Int, _ seed: UInt32) -> Float {
        let x = u * Float(cellsX), y = v * Float(cellsY)
        let xi = Int(floor(x)), yi = Int(floor(y))
        let fx = x - Float(xi), fy = y - Float(yi)
        let sx = fx * fx * (3 - 2 * fx), sy = fy * fy * (3 - 2 * fy)
        let x0 = ((xi % cellsX) + cellsX) % cellsX
        let x1 = (x0 + 1) % cellsX
        let a = hash(x0, yi, seed), b = hash(x1, yi, seed)
        let c = hash(x0, yi + 1, seed), d = hash(x1, yi + 1, seed)
        let top = a + (b - a) * sx
        let bot = c + (d - c) * sx
        return top + (bot - top) * sy
    }

    private static func fbm(_ u: Float, _ v: Float,
                            _ cellsX: Int, _ cellsY: Int,
                            _ octaves: Int, _ seed: UInt32) -> Float {
        var s: Float = 0, amp: Float = 0.5, norm: Float = 0
        var cx = cellsX, cy = cellsY
        for o in 0..<octaves {
            s += amp * vnoise(u, v, cx, cy, seed &+ UInt32(o) &* 0x9E37_79B9)
            norm += amp
            cx *= 2; cy *= 2; amp *= 0.5
        }
        return s / max(norm, 0.001)
    }

    /// Ridged multifractal à la Musgrave, anisotrope : le détail fin ne pousse
    /// que sur les crêtes larges — filaments qui se ramifient.
    private static func ridged(_ u: Float, _ v: Float,
                               _ cellsX: Int, _ cellsY: Int,
                               _ octaves: Int, _ seed: UInt32) -> Float {
        var s: Float = 0, amp: Float = 0.5, prev: Float = 1
        var cx = cellsX, cy = cellsY
        for o in 0..<octaves {
            let n = vnoise(u, v, cx, cy, seed &+ UInt32(o) &* 0x85EB_CA6B) * 2 - 1
            var r = 1 - abs(n)
            r = r * r
            s += r * amp * prev
            prev = min(max(r * 2, 0), 1)
            cx *= 2; cy *= 2; amp *= 0.5
        }
        return min(s * 1.35, 1)
    }

    // MARK: Fabrication

    /// Un champ de filaments : ridged anisotrope (7×9 cellules sur 1024×320 →
    /// features ~3,5× plus larges que hautes à l'écran), double warp.
    private static func bakeField(_ seed: UInt32) -> [Float] {
        var field = [Float](repeating: 0, count: width * height)
        let invW = 1.0 as Float / Float(width)
        let invH = 1.0 as Float / Float(height)
        for j in 0..<height {
            let v = Float(j) * invH
            for i in 0..<width {
                let u = Float(i) * invW
                // Warp imbriqué : le premier plie le domaine, le second plie
                // le warp lui-même — les tendrilles se courbent au lieu de
                // suivre le treillis.
                let w1x = fbm(u, v, 4, 3, 3, seed &+ 11) - 0.5
                let w1y = fbm(u, v, 4, 3, 3, seed &+ 23) - 0.5
                let w2x = fbm(u + 0.10 * w1x, v + 0.16 * w1y, 7, 5, 3, seed &+ 37) - 0.5
                let w2y = fbm(u + 0.12 * w1y, v + 0.13 * w1x, 7, 5, 3, seed &+ 41) - 0.5
                let r = ridged(u + 0.05 * w2x, v + 0.14 * w2y, 7, 9, 6, seed)
                field[j * width + i] = r
            }
        }
        return field
    }

    /// Advection (LIC) : chaque texel devient la moyenne du champ le long
    /// d'une ligne de courant quasi horizontale, courbée par un bruit lent.
    /// C'est CE lissage directionnel qui transforme un bruit en soie filée.
    private static func advect(_ field: [Float], _ seed: UInt32) -> [Float] {
        var out = [Float](repeating: 0, count: width * height)
        let invW = 1.0 as Float / Float(width)
        let invH = 1.0 as Float / Float(height)
        let steps = 9
        let stepLen = 2.2 as Float          // texels par pas
        for j in 0..<height {
            let v = Float(j) * invH
            for i in 0..<width {
                let u = Float(i) * invW
                // Direction du courant : horizontale ±~24°, courbée lentement.
                let ang = (fbm(u, v, 5, 4, 3, seed &+ 53) - 0.5) * 0.85
                let dx = cosf(ang) * stepLen
                let dy = sinf(ang) * stepLen
                var acc: Float = 0
                var wsum: Float = 0
                for k in -steps...steps {
                    let fk = Float(k)
                    let xi = Float(i) + dx * fk
                    let yi = Float(j) + dy * fk
                    let x = ((Int(xi.rounded()) % width) + width) % width
                    let y = min(max(Int(yi.rounded()), 0), height - 1)
                    let wgt = 1.0 - abs(fk) / Float(steps + 1)
                    acc += field[y * width + x] * wgt
                    wsum += wgt
                }
                out[j * width + i] = acc / wsum
            }
        }
        return out
    }

    private static func make() -> CGImage {
        let filA = advect(bakeField(0x51A7_2E9D), 0x51A7_2E9D)
        let filB = advect(bakeField(0x0BEE_5EED), 0x0BEE_5EED)

        var data = [UInt8](repeating: 0, count: width * height * 4)
        let invW = 1.0 as Float / Float(width)
        let invH = 1.0 as Float / Float(height)
        for j in 0..<height {
            let v = Float(j) * invH
            // Fenêtre verticale : les bords fondent à zéro, le clamp du
            // sampler ne peut jamais étirer une rangée habitée.
            let winT = min(max(v / 0.12, 0), 1)
            let winB = min(max((1 - v) / 0.12, 0), 1)
            let win = winT * winT * (3 - 2 * winT) * winB * winB * (3 - 2 * winB)
            for i in 0..<width {
                let u = Float(i) * invW
                let k = (j * width + i) * 4
                // Contraste : plancher coupé puis courbe — les filaments se
                // détachent sur du noir, jamais un lavis gris uniforme.
                let a = filA[j * width + i]
                let fA = powf(max(a * 1.35 - 0.28, 0), 1.55)
                let b = filB[j * width + i]
                let fB = powf(max(b * 1.30 - 0.30, 0), 1.65)
                let g = fbm(u, v, 5, 4, 4, 0x27D4_EB2F)
                data[k]     = UInt8(min(max(fA * win * 255, 0), 255))
                data[k + 1] = UInt8(min(max(g * win * 255, 0), 255))
                data[k + 2] = UInt8(min(max(fB * win * 255, 0), 255))
                data[k + 3] = 255
            }
        }

        // Espace linéaire : la texture est une DONNÉE (voir NebulaNoise).
        let space = CGColorSpace(name: CGColorSpace.linearSRGB) ?? CGColorSpaceCreateDeviceRGB()
        let ctx = data.withUnsafeMutableBytes { buf in
            CGContext(data: buf.baseAddress, width: width, height: height,
                      bitsPerComponent: 8, bytesPerRow: width * 4, space: space,
                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        }
        return ctx!.makeImage()!
    }
}
