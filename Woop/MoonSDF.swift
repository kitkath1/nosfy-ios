import SwiftUI

// MARK: - LUT SDF du croissant

/// Champ de distance signée du croissant du logo, pour le shader du
/// monolithe (`-logoLab`). Un seul champ, deux encodages :
///   R : distance signée SERRÉE, demi-portée `tightRange` — le bord net et
///       le dégradé de chaleur intérieur (l'épaisseur max du croissant vaut
///       0.1163 uc < 0.125 : le canal ne sature jamais dedans) ;
///   G : la MÊME distance, demi-portée `wideRange` — le bloom extérieur ;
///   B : le RÉSIDU de quantification de R, recentré sur 0,5 — cf. plus bas ;
///   A : constant à 255 — jamais de donnée dans l'alpha : SwiftUI peut
///       prémultiplier la texture (piège NebulaNoise).
///
/// POURQUOI UN RÉSIDU DANS B. Le canal R quantifie la distance par pas de
/// 2·0,125/255 uc = 0,106 pt de scène. À l'échelle de la scène c'est
/// invisible ; sous la caméra du splash, qui grossit seize fois, ce pas
/// devient 1,7 pt d'écran et le tube se met à monter en TERRASSES — un
/// escalier régulier, bien plus voyant qu'un bruit de même amplitude. B
/// porte donc l'erreur d'arrondi de R : la paire reconstruit la distance à
/// 0,0002 pt près, soit 255 fois mieux.
///
/// Le partage est choisi pour que R reste BIT À BIT ce qu'il était : la
/// scène normale échantillonne R seul, en bilinéaire matériel, et ne change
/// pas d'un LSB. Seule la branche macro du shader lit la paire — et elle la
/// lit en filtrage NEAREST, texel par texel, parce qu'un résidu est une
/// dent de scie : l'interpoler directement mélangerait deux marches
/// voisines et fabriquerait exactement le défaut qu'on vient de tuer. La
/// reconstruction se fait donc APRÈS décodage, sur les quatre texels.
///
/// Distances en unités-croissant (côté long de la bbox = 1), d > 0 à
/// l'EXTÉRIEUR, 0.5 encodé pile sur le contour. La texture couvre un carré
/// de `padding` uc, croissant centré. Ces constantes sont LA source de
/// vérité : elles partent au shader en `.float3(padding, tight, wide)` —
/// ne jamais les recopier en dur dans le .metal. Hors de [0,1]² en UV, le
/// shader prolonge analytiquement : d += length(uv − clamp(uv)) × padding.
enum MoonSDF {
    static let side = 512
    /// Côté du carré couvert par la texture, en unités-croissant.
    static let padding: Float = 1.5
    /// Demi-portée du canal R (bord net + chaleur intérieure).
    static let tightRange: Float = 0.125
    /// Demi-portée du canal G (bloom extérieur).
    static let wideRange: Float = 0.75

    static let image: Image = Image(decorative: makeLUT(), scale: 1)

    /// À appeler au lancement quand `-logoLab` est présent : ~75 M
    /// d'évaluations point-segment, ~0,1-0,2 s en parallèle — payées en
    /// tâche de fond pendant que le banc affiche son premier frame.
    static func warmUp() {
        Task.detached(priority: .userInitiated) { _ = Self.image }
    }

    // MARK: Fabrication

    private struct Seg {
        var a: SIMD2<Float>
        var d: SIMD2<Float>
        var invLen2: Float
    }

    /// Distance exacte à la polyligne (288 segments, erreur d'aplatissement
    /// 0,12 texel), signe par parité scanline demi-ouverte — insensible au
    /// sens de parcours et aux sommets pile sur une ligne de texels. Pas de
    /// rasterisation CGContext : aucun piège d'orientation Y (le buffer est
    /// rempli ligne 0 = haut, comme le SVG et comme SwiftUI).
    private static func makeLUT() -> CGImage {
        let n = side
        let center = SIMD2<Float>(0.5, Float(MoonGlyph.unitHeight) * 0.5)
        let unit = MoonGlyph.flattened(subdivisions: 16)

        // Polyligne en UV texture : croissant centré dans le carré `padding`.
        var segs: [Seg] = []
        segs.reserveCapacity(unit.count)
        for i in 0..<unit.count {
            let a = (unit[i] - center) / padding + SIMD2<Float>(0.5, 0.5)
            let b = (unit[(i + 1) % unit.count] - center) / padding + SIMD2<Float>(0.5, 0.5)
            let d = b - a
            let l2 = max(d.x * d.x + d.y * d.y, 1e-12)
            segs.append(Seg(a: a, d: d, invLen2: 1 / l2))
        }

        var data = [UInt8](repeating: 0, count: n * n * 4)
        data.withUnsafeMutableBufferPointer { buf in
            let base = buf.baseAddress!
            DispatchQueue.concurrentPerform(iterations: n) { j in
                let py = (Float(j) + 0.5) / Float(n)
                // Croisements de la scanline, triés : le signe se lit en
                // avançant un curseur, jamais un test pair/impair par texel.
                var xs: [Float] = []
                for s in segs where (s.a.y > py) != (s.a.y + s.d.y > py) {
                    xs.append(s.a.x + (py - s.a.y) * s.d.x / s.d.y)
                }
                xs.sort()
                var next = 0
                var inside = false
                for i in 0..<n {
                    let px = (Float(i) + 0.5) / Float(n)
                    while next < xs.count, xs[next] < px {
                        inside.toggle()
                        next += 1
                    }
                    var best = Float.greatestFiniteMagnitude
                    for s in segs {
                        let wx = px - s.a.x, wy = py - s.a.y
                        let t = min(max((wx * s.d.x + wy * s.d.y) * s.invLen2, 0), 1)
                        let dx = wx - t * s.d.x, dy = wy - t * s.d.y
                        best = min(best, dx * dx + dy * dy)
                    }
                    var d = sqrt(best) * padding          // uv → unités-croissant
                    if inside { d = -d }
                    let k = (j * n + i) * 4
                    // R inchangé ; B rattrape son arrondi. Le résidu se
                    // mesure sur la valeur CLAMPÉE, sinon les texels saturés
                    // (loin du croissant) porteraient un résidu qui n'existe
                    // pas et le décodage les ferait dériver.
                    let v = min(max(0.5 + d / (2 * tightRange), 0), 1)
                    let hi = (v * 255).rounded()
                    base[k]     = UInt8(hi)
                    base[k + 1] = quant(0.5 + d / (2 * wideRange))
                    base[k + 2] = quant(v * 255 - hi + 0.5)
                    base[k + 3] = 255
                }
            }
        }

        // ATTENTION — espace sRGB, PAS linéaire, et c'est contre-intuitif :
        // la distance est une donnée, on la voudrait linéaire. Mais SwiftUI
        // convertit la texture vers l'espace de travail du rendu, qui est
        // encodé sRGB : une source déclarée linéaire se fait GAMMA-ENCODER à
        // l'upload, et 0,5 (le contour) arrive à 0,735 sur le GPU. Le tube
        // se dessinait alors ~8 pt en retrait du tracé. Déclarée sRGB, la
        // conversion est l'identité et les octets arrivent intacts.
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let ctx = data.withUnsafeMutableBytes { b in
            CGContext(data: b.baseAddress, width: n, height: n,
                      bitsPerComponent: 8, bytesPerRow: n * 4, space: space,
                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        }
        return ctx!.makeImage()!
    }

    private static func quant(_ v: Float) -> UInt8 {
        UInt8((min(max(v, 0), 1) * 255).rounded())
    }
}
