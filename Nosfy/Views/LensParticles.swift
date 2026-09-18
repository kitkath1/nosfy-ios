import SwiftUI

// MARK: - Les particules de la lentille
//
// Un seul champ, cinq vies, ZÉRO état : chaque particule est une fonction
// pure (graine, horloges) → position/couleur — l'école de la maison. Monté
// dans les DEUX mondes avec les mêmes horloges : il traverse la coupe sans
// couture, se fige (`-lensFreeze`) et se rejoue.
//
// LE PINCEAU : des BILLES — cœur net (1-2 pt) + halo doux — jamais des
// rectangles durs. La persistance : rien ne meurt en boucle visible — la
// cascade coule (400-700 pt/s, un front qui se déverse), et ce qui est
// arrivé RESTE : couronne accumulée, champ d'étoiles permanent.
//
//   1. Le sillage : dès le premier centimètre de drag, des billes très
//      discrètes se dessinent DERRIÈRE la bulle, le long du chemin parcouru
//      depuis le bas — le tracé du doigt.
//   2. La métamorphose : aspirées vers l'orbite, elles traversent le
//      SPECTRE puis prennent les teintes des quatre voix, en haut.
//   3. La cascade : DEUX colonnes qui se déversent des extrémités de la
//      Dynamic Island dès la fin du morphisme — gorge dense à la bouche,
//      évasement en tombant, étincelles blanches, champagne au dernier
//      quart (réfs 1 et 4).
//   4. Le dépôt : la couronne s'accumule sur le limbe et RESTE.
//   5. Le champ d'étoiles : la rémanence permanente (réf 3).
//
// Plus tard : un vecteur gravité CoreMotion s'ajoutera aux trajectoires.
struct LensParticles: View {
    let now: Date
    let lensCenter: CGPoint
    let lensR: CGFloat
    let p: Double
    let ceStart: Date?
    let face: Date?

    /// Les teintes des quatre voix du cadran (EclipseHalo).
    private static let tints: [(Double, Double, Double)] = [
        (0.93, 0.95, 1.00), (1.00, 0.70, 0.33),
        (1.00, 1.00, 1.00), (1.00, 0.78, 0.50)
    ]
    private static let champagne = (0.91, 0.78, 0.48)

    var body: some View {
        Canvas { ctx, sz in
            let t = now.timeIntervalSinceReferenceDate
            let ce = ceStart.map { now.timeIntervalSince($0) } ?? -1
            let fe = face.map { now.timeIntervalSince($0) } ?? -1
            let w = sz.width, hgt = sz.height

            // Le pinceau : halo doux + cœur net.
            func bead(_ x: Double, _ y: Double, _ core: Double,
                      _ r: Double, _ g: Double, _ b: Double, _ a: Double,
                      stretch: Double = 1) {
                guard a > 0.004 else { return }
                let col = Color(red: r, green: g, blue: b)
                let hs = core * 2.6
                ctx.fill(Path(ellipseIn:
                    CGRect(x: x - hs / 2, y: y - hs / 2 * stretch,
                           width: hs, height: hs * stretch)),
                         with: .color(col.opacity(a * 0.22)))
                ctx.fill(Path(ellipseIn:
                    CGRect(x: x - core / 2, y: y - core / 2 * stretch,
                           width: core, height: core * stretch)),
                         with: .color(col.opacity(a)))
            }

            // (Le sillage de billes a cédé la place aux VOLUTES D'ENCRE du
            // shader `inkVeil` — de la fumée dans la couche réfractée, pas
            // des points. Les confettis de métamorphose et la cascade-champagne ont
            // été SUPPRIMÉS — verdict de Kathryn : le morphisme est PUR, le
            // verre seul. La cascade reviendra en MATIÈRE granulaire Metal,
            // jugée sur les mesures de la référence — jamais en billes.)

            if fe >= 0 {
                // ---- 4 : le dépôt — la couronne s'accumule et RESTE,
                // trois profondeurs, quelques billes qui débordent.
                let cum = sstep(0.4, 2.4, fe)
                if cum > 0.01 {
                    for k in 0..<140 {
                        let phi = (h(k, 41) - 0.5) * 2.1
                        let depth = k % 3
                        let wR = 0.62 + 0.38 * sstep(-0.3, 0.6, phi)
                        let stray = h(k, 46) > 0.9 ? 14.0 : 0.0
                        let rr = lensR + 3 + 9 * h(k, 42) + stray
                        let x = lensCenter.x + rr * sin(phi)
                        let y = lensCenter.y - rr * cos(phi)
                            + sin(t * 0.6 + Double(k)) * 1.5
                        let tw = 0.70 + 0.30 * sin(t * 0.9 + Double(k) * 1.7)
                        let appear = sstep(0.4 + 1.7 * h(k, 44),
                                           0.8 + 1.7 * h(k, 44), fe)
                        let a = (0.20 + 0.30 * h(k, 43))
                            * (depth == 0 ? 1 : depth == 1 ? 0.7 : 0.45)
                            * cum * tw * wR * appear
                        let tint = Self.tints[k % 4]
                        bead(x, y,
                             (depth == 0 ? 1.6 : depth == 1 ? 1.15 : 0.8)
                                 * (0.8 + 0.5 * h(k, 45)),
                             tint.0, tint.1, tint.2, a)
                    }
                }

                // ---- 5 : le champ d'étoiles — la rémanence PERMANENTE.
                let star = sstep(0.9, 2.0, fe)
                if star > 0.01 {
                    for m in 0..<110 {
                        let x = h(m, 51) * w
                        let y = h(m, 52) * hgt
                        let dx = x - lensCenter.x, dy = y - lensCenter.y
                        if dx * dx + dy * dy < 150 * 150 { continue }
                        let tw = 0.55 + 0.45 * sin(t * (0.4 + 0.5 * h(m, 53))
                                                   + Double(m))
                        let drift = sin(t * 0.20 + Double(m) * 0.7) * 2.5
                        bead(x + drift, y + drift * 0.4,
                             0.8 + 0.9 * h(m, 55),
                             0.93, 0.94, 1.0,
                             (0.16 + 0.22 * h(m, 54)) * star * tw)
                    }
                }
            }
        }
    }

    /// Hash déterministe (graine, canal) → [0, 1).
    private func h(_ i: Int, _ k: Int) -> Double {
        var s = UInt64(bitPattern: Int64(i &* 1_000_003 &+ k &* 7_919))
        s ^= s >> 33
        s = s &* 0xFF51_AFD7_ED55_8CCD
        s ^= s >> 33
        s = s &* 0xC4CE_B9FE_1A85_EC53
        s ^= s >> 33
        return Double(s % 1_048_576) / 1_048_576
    }

    private func sstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let u = min(max((x - a) / (b - a), 0), 1)
        return u * u * (3 - 2 * u)
    }
}
