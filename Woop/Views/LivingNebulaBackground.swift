import SwiftUI
import UIKit

// MARK: - Le fond : une photo FIXE, rendue vivante par-dessus
//
// La nébuleuse est une photographie. Elle ne bouge pas d'un pixel : aucun
// zoom, aucune rotation, aucun Ken Burns, aucun flou. Ce qui vit, ce sont les
// couches procédurales posées PAR-DESSUS, toutes calées sur la MÊME projection
// (coordonnées normalisées 0-1) — donc identiques sur tous les iPhone.
//
// L'ordre de la scène, du fond vers l'avant :
//   0. la photo, immobile ;
//   1. une copie ONDULÉE de sa couche lumineuse (warp d'UV le long de la
//      veine) — ce sont les nuages EUX-MÊMES qui bougent ;
//   2. la veine vivante (shader) : bruit fractal lent, curl, circulation,
//      respiration désynchronisée, zones qui s'allument et s'effacent ;
//   3. les particules diamants (shader) : advection le long du champ tangent
//      aux filaments, traînées qui dessinent les courbes ;
//   4. le Canvas : nœuds, pulsars, vagues de sheen, grains mesurés de la
//      photo, chemins de dérive pré-advectés ;
//   5. la brume noire (shader), qui occulte et donne la profondeur.
//
// Seule contrainte de lisibilité : les boîtes des contrôles sont assourdies
// au feather, JAMAIS une bande pleine largeur.

struct LivingNebulaBackground: View {
    /// L'horloge de la scène (s depuis l'apparition).
    var t: Double
    /// Inclinaison lissée du téléphone : elle ne bouge QUE les couches
    /// procédurales — l'image, elle, reste strictement fixe.
    var tilt: CGVector = .zero
    /// Les zones à assourdir (fractions d'écran). Vide = rien n'est assourdi.
    var readabilityBoxes: [CGRect] = NebulaConfig.controlBoxes

    var body: some View {
        GeometryReader { geo in
            let L = Layout(size: geo.size)
            let fade = smooth(t / NebulaConfig.revealDuration)
            let gpuT = Float(t.truncatingRemainder(dividingBy: 900))

            ZStack(alignment: .topLeading) {
                // ---- 0. LA PHOTO. Immobile. Point.
                Image(NebulaConfig.imageName)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: L.imgW, height: L.imgH)
                    .offset(x: L.offX, y: L.offY)

                // ---- 5. La brume noire : elle passe DEVANT la photo mais
                // DERRIÈRE la lumière ajoutée — elle occulte la matière, elle
                // n'éteint pas les étincelles.
                darkMist(L, gpuT, Float(fade))

                // ---- 1-4. Toute la lumière ajoutée, en un seul groupe :
                // un seul offscreen, un seul masque de lisibilité, un seul
                // plusLighter au-dessus de la photo.
                ZStack(alignment: .topLeading) {
                    warpedGlow(L, gpuT, fade)
                    livingVein(L, gpuT, Float(fade))
                    diamondDust(L, gpuT, Float(fade))
                    canvasLayer(L, fade)
                }
                .compositingGroup()
                .mask { readabilityMask(L) }
                .blendMode(.plusLighter)
            }
            .clipped()
        }
        .allowsHitTesting(false)
    }

    // MARK: La projection — la même pour tout

    /// Aspect-fill avec un surplus de `bleed` : la parallaxe des couches
    /// procédurales ne découvre jamais un bord.
    struct Layout {
        let w: CGFloat, h: CGFloat
        let scale: CGFloat, imgW: CGFloat, imgH: CGFloat
        let offX: CGFloat, offY: CGFloat

        init(size: CGSize) {
            w = max(size.width, 1)
            h = max(size.height, 1)
            let b = NebulaConfig.bleed * 2
            let ref = NebulaConfig.refSize
            scale = max((w + b) / ref.width, (h + b) / ref.height)
            imgW = ref.width * scale
            imgH = ref.height * scale
            offX = (w - imgW) / 2
            offY = (h - imgH) / 2
        }

        /// Unités image → points écran.
        func map(_ u: CGPoint) -> CGPoint {
            CGPoint(x: offX + u.x * imgW, y: offY + u.y * imgH)
        }
    }

    /// Le décalage d'une couche procédurale selon sa profondeur.
    private func par(_ depth: CGFloat) -> CGSize {
        CGSize(width: tilt.dx * depth, height: tilt.dy * depth)
    }

    // MARK: 1. La copie ondulée de la couche lumineuse

    /// La VAGUE de distorsion : un warp des UV le long de la veine, jamais un
    /// overlay blanc. Amplitude 3-6 px, λ ≈ 220 px, ~30 px/s qui remonte le
    /// tracé — c'est ce qui tue définitivement l'effet « photo figée ».
    private func warpedGlow(_ L: Layout, _ gpuT: Float, _ fade: Double) -> some View {
        let amp = NebulaConfig.warpAmplitude * Float(L.scale)
        let ramp = min(1, max(0, (t - 0.3) / 2.0))
        return Image(NebulaConfig.glowImageName)
            .resizable()
            .interpolation(.high)
            .frame(width: L.imgW, height: L.imgH)
            .distortionEffect(
                ShaderLibrary.nebulaVeinWave(
                    .float2(L.imgW, L.imgH), .float(gpuT),
                    .float4(amp, NebulaConfig.warpWavelength * Float(L.scale),
                            NebulaConfig.warpSpeed * Float(L.scale),
                            NebulaConfig.veinHalfWidth)),
                maxSampleOffset: CGSize(width: CGFloat(amp) * 2.4,
                                        height: CGFloat(amp) * 1.2))
            .blendMode(.plusLighter)
            .opacity(NebulaConfig.warpLayerOpacity * fade * ramp)
            .offset(x: L.offX, y: L.offY)
    }

    // MARK: 2. La veine vivante

    /// Rendue en DEMI-résolution puis agrandie ×2 : le contenu est vaporeux,
    /// l'upscale bilinéaire est invisible, le GPU travaille 4× moins.
    private func livingVein(_ L: Layout, _ gpuT: Float, _ fade: Float) -> some View {
        Rectangle()
            .fill(.black)
            .frame(width: L.imgW / 2, height: L.imgH / 2)
            .colorEffect(ShaderLibrary.nebulaLivingVein(
                .float2(L.imgW / 2, L.imgH / 2), .float(gpuT), .float(fade),
                .float4(NebulaConfig.veinHalfWidth, NebulaConfig.veinEdgeNoise,
                        NebulaConfig.veinGain, NebulaConfig.veinLumaFloor),
                .float4(NebulaConfig.veinMainCycle, NebulaConfig.veinBreathCycle,
                        NebulaConfig.veinFlowSpeed, 0),
                .image(NebulaField.image),
                .image(NebulaNoise.image)))
            .scaleEffect(2, anchor: .topLeading)
            .blendMode(.plusLighter)
            .offset(x: L.offX + par(NebulaConfig.parallaxMid).width,
                    y: L.offY + par(NebulaConfig.parallaxMid).height)
    }

    // MARK: 3. Les particules diamants

    /// Pleine résolution : les grains sont sub-pixel, un upscale les tuerait.
    private func diamondDust(_ L: Layout, _ gpuT: Float, _ fade: Float) -> some View {
        let s = Float(L.scale)
        return Rectangle()
            .fill(.black)
            .frame(width: L.imgW, height: L.imgH)
            .colorEffect(ShaderLibrary.nebulaDiamondDust(
                .float2(L.imgW, L.imgH), .float(gpuT), .float(fade),
                .float4(NebulaConfig.dustCell * s, NebulaConfig.dustLumaGate,
                        NebulaConfig.dustGain, NebulaConfig.flareChance),
                .float4(NebulaConfig.dustSpeedMin * s, NebulaConfig.dustSpeedMax * s,
                        NebulaConfig.dustTrailMin * s, NebulaConfig.dustTrailMax * s),
                .float4(NebulaConfig.dustLifeMin, NebulaConfig.dustLifeMax,
                        NebulaConfig.dustSizeMin * s, NebulaConfig.dustSizeMax * s),
                .image(NebulaField.image)))
            .blendMode(.plusLighter)
            .offset(x: L.offX + par(NebulaConfig.parallaxFront).width,
                    y: L.offY + par(NebulaConfig.parallaxFront).height)
    }

    // MARK: 5. La brume noire

    private func darkMist(_ L: Layout, _ gpuT: Float, _ fade: Float) -> some View {
        Rectangle()
            .fill(.black)
            .frame(width: L.imgW / 2, height: L.imgH / 2)
            .colorEffect(ShaderLibrary.nebulaDarkMist(
                .float2(L.imgW / 2, L.imgH / 2), .float(gpuT), .float(fade),
                .float4(NebulaConfig.mistOpacity, NebulaConfig.mistSpeed,
                        NebulaConfig.mistScale, NebulaConfig.mistImpGuard),
                .image(NebulaField.image),
                .image(NebulaNoise.image)))
            .scaleEffect(2, anchor: .topLeading)
            .offset(x: L.offX + par(NebulaConfig.parallaxMid * 0.6).width,
                    y: L.offY + par(NebulaConfig.parallaxMid * 0.6).height)
    }

    // MARK: 4. Le Canvas — ce que la photo contient déjà, mis en mouvement

    private func canvasLayer(_ L: Layout, _ fade: Double) -> some View {
        Canvas { ctx, _ in
            drawKnots(ctx, L, fade)
            drawSheen(ctx, L, fade)
            drawGlimmers(ctx, L, fade)
            drawSpecks(ctx, L, fade)
            drawDrift(ctx, L, fade)
        }
        .frame(width: L.w, height: L.h)
    }

    /// Les nœuds brillants MESURÉS respirent, et les PULSARS flashent :
    /// montée/retombée en 3-5 s DÉPHASÉES, +12-18 % de lumière, rayon
    /// ×1,00-1,06. Le nœud contre le champ téléphone vit lui aussi.
    private func drawKnots(_ context: GraphicsContext, _ L: Layout, _ fade: Double) {
        var g = context
        g.blendMode = .plusLighter
        for (i, k) in NebulaConfig.knots.enumerated() {
            let pos = L.map(k.p)
            let period = NebulaConfig.lerp(NebulaConfig.knotBreathRange,
                                           NebulaConfig.hash(i, 40))
            let breath = 0.5 + 0.5 * sin(t * 2 * .pi / period
                                         + NebulaConfig.hash(i, 41) * 6.283)
            let a = (NebulaConfig.knotBaseAlpha + 0.025 * NebulaConfig.hash(i, 42))
                * breath * fade
            if a > 0.004 {
                let r = k.r * L.scale * 2.4 * (0.90 + 0.14 * CGFloat(breath))
                g.fill(disc(pos, r), with: softWhite(pos, r, a))
            }
            guard k.pulsar else { continue }
            let pulse = pow(0.5 + 0.5 * sin(t * 2 * .pi / k.period
                                            + NebulaConfig.hash(i, 45) * 6.283), 3.0)
            let pa = (NebulaConfig.pulsarAlpha + 0.045 * NebulaConfig.hash(i, 46))
                * pulse * fade
            guard pa > 0.006 else { continue }
            let pr = k.r * L.scale * 2.0 * (1 + NebulaConfig.pulsarScale * CGFloat(pulse))
            g.fill(disc(pos, pr), with: softWhite(pos, pr, pa))
        }
    }

    /// Les VAGUES blanches qui PARCOURENT la veine : des paquets de sheen
    /// ÉTIRÉS le long du tracé (jamais des ronds), qui remontent le trajet.
    private func drawSheen(_ context: GraphicsContext, _ L: Layout, _ fade: Double) {
        for (k, period) in NebulaConfig.sheenPeriods.enumerated() {
            let head = 1 - ((t / period + Double(k) * 0.45)
                .truncatingRemainder(dividingBy: 1))
            for j in -4...4 {
                let uu = CGFloat(head) + CGFloat(j) * 0.024
                guard uu > 0.02, uu < 0.98 else { continue }
                let p = NebulaConfig.vein(uu)
                let pos = L.map(p)
                let g = exp(-Double(j * j) / 6.0)
                let a = NebulaConfig.sheenAlpha * g * fade * (k == 0 ? 1 : 0.72)
                guard a > 0.004 else { continue }
                // La tangente locale : le paquet est ÉTIRÉ dans le sens de la
                // veine — c'est ça qui le fait lire comme une onde, pas un rond.
                let q = NebulaConfig.vein(min(0.999, uu + 0.02))
                let ang = atan2(q.y - p.y, (q.x - p.x) * L.imgW / L.imgH)
                let r = (30 + 10 * CGFloat(NebulaConfig.hash(j + 5 + k * 9, 110))) * L.scale
                context.drawLayer { layer in
                    layer.blendMode = .plusLighter
                    layer.translateBy(x: pos.x, y: pos.y)
                    layer.rotate(by: .radians(ang))
                    let rect = CGRect(x: -r * 0.55, y: -r * 2.1,
                                      width: r * 1.10, height: r * 4.2)
                    layer.fill(
                        Path(ellipseIn: rect),
                        with: .radialGradient(
                            Gradient(stops: [
                                .init(color: .white.opacity(a), location: 0.0),
                                .init(color: .white.opacity(a * 0.32), location: 0.55),
                                .init(color: .clear, location: 1.0)
                            ]),
                            center: .zero, startRadius: 0, endRadius: r * 2.1))
                }
            }
        }
    }

    /// Les points de lumière RÉELS de la photo : chacun reçoit un
    /// micro-scintillement PROPORTIONNEL à sa luminance locale. La nébuleuse
    /// vibre par ses centaines de composants — rien n'est posé au hasard.
    private func drawGlimmers(_ context: GraphicsContext, _ L: Layout, _ fade: Double) {
        var g = context
        g.blendMode = .plusLighter
        for (i, s) in NebulaConfig.glimmers.enumerated() {
            let lum = Double(s.z)
            let freq = NebulaConfig.lerp(NebulaConfig.glimmerTwinkleRange,
                                         NebulaConfig.hash(i, 120))
            let tw = pow(0.5 + 0.5 * sin(t * freq + NebulaConfig.hash(i, 121) * 6.283), 3.0)
            let a = (0.06 + 0.80 * tw) * lum * fade
            guard a > 0.015 else { continue }
            let base = L.map(CGPoint(x: CGFloat(s.x), y: CGFloat(s.y)))
            let dx = CGFloat(sin(t * (0.18 + 0.25 * NebulaConfig.hash(i, 122)) + Double(i))) * 1.4
            let dy = CGFloat(cos(t * (0.14 + 0.22 * NebulaConfig.hash(i, 123)) + Double(i) * 1.7)) * 1.1
            let r = 0.4 + 0.6 * CGFloat(NebulaConfig.hash(i, 124)) + CGFloat(tw) * 0.3
            g.fill(disc(CGPoint(x: base.x + dx, y: base.y + dy), r),
                   with: .color(.white.opacity(a)))
        }
    }

    /// Les poussières RÉELLES détectées autour des gros diablotins : les
    /// grains qui existent déjà se mettent à étinceler.
    private func drawSpecks(_ context: GraphicsContext, _ L: Layout, _ fade: Double) {
        var g = context
        g.blendMode = .plusLighter
        for (i, s) in NebulaConfig.impSpecks.enumerated() {
            let freq = 0.6 + 2.2 * NebulaConfig.hash(i, 130)
            let tw = pow(0.5 + 0.5 * sin(t * freq + NebulaConfig.hash(i, 131) * 6.283), 3.5)
            let a = (0.10 + 0.60 * tw) * Double(s.z) * fade
            guard a > 0.02 else { continue }
            let base = L.map(CGPoint(x: CGFloat(s.x), y: CGFloat(s.y)))
            let r = 0.45 + 0.55 * CGFloat(NebulaConfig.hash(i, 132)) + CGFloat(tw) * 0.4
            g.fill(disc(base, r), with: .color(.white.opacity(a)))
        }
    }

    /// Les chemins de dérive PRÉ-ADVECTÉS sur les crêtes de luminance : le
    /// grain avance le long de son filament à 6-14 px/s et traîne 8-16 px
    /// DERRIÈRE lui, le long du chemin. Aucune trajectoire ne traverse le
    /// noir : c'est garanti par construction, pas par réglage.
    private func drawDrift(_ context: GraphicsContext, _ L: Layout, _ fade: Double) {
        var fl = context
        fl.blendMode = .plusLighter
        let front = par(NebulaConfig.parallaxFront)
        for (i, pts) in NebulaConfig.driftPaths.enumerated() {
            let n = pts.count
            guard n > 2 else { continue }
            let speedPt = NebulaConfig.lerp(NebulaConfig.driftSpeedRange,
                                            NebulaConfig.hash(i, 150))
            let lenPt = Double(n - 1) * 6.0 * Double(L.scale)
            let dur = max(4.0, lenPt / speedPt)
            let u = (t / dur + NebulaConfig.hash(i, 151)).truncatingRemainder(dividingBy: 1)
            let x = u * Double(n - 1)
            let j = min(Int(x), n - 2)
            let f = CGFloat(x - Double(j))
            let p0 = pts[j], p1 = pts[j + 1]
            let lum = Double(p0.z) + (Double(p1.z) - Double(p0.z)) * Double(f)
            let base = L.map(CGPoint(x: CGFloat(p0.x) + (CGFloat(p1.x) - CGFloat(p0.x)) * f,
                                     y: CGFloat(p0.y) + (CGFloat(p1.y) - CGFloat(p0.y)) * f))
            let par: CGSize = i % 6 == 0 ? front : .zero
            let pos = CGPoint(x: base.x + par.width, y: base.y + par.height)
            let life = sin(.pi * u)
            let hz = 0.5 + 1.5 * NebulaConfig.hash(i, 152)
            let tw = 0.40 + 0.60 * pow(0.5 + 0.5 * sin(t * 2 * .pi * hz + Double(i)), 2)
            let hero = NebulaConfig.hash(i, 153) > 0.88
            let a = (hero ? 0.55 : 0.15 + 0.55 * lum) * life * tw * fade
            guard a > 0.02 else { continue }
            let shade = 0.70 + 0.30 * lum
            let r: CGFloat = hero ? 0.85 : 0.35 + 0.45 * CGFloat(NebulaConfig.hash(i, 154))

            // La traînée : 8-16 px LE LONG du chemin, jamais en travers.
            var remaining = (2.8 + 2.6 * NebulaConfig.hash(i, 155)) / (6.0 * Double(L.scale))
            var tail = Path()
            tail.move(to: pos)
            var jj = j
            var ff = Double(f)
            for _ in 0..<4 {
                guard remaining > 0 else { break }
                let step = min(remaining, max(ff, 0.001))
                ff = max(0, ff - step)
                remaining -= step
                let q0 = pts[jj], q1 = pts[min(jj + 1, n - 1)]
                let qp = L.map(CGPoint(x: CGFloat(q0.x) + (CGFloat(q1.x) - CGFloat(q0.x)) * CGFloat(ff),
                                       y: CGFloat(q0.y) + (CGFloat(q1.y) - CGFloat(q0.y)) * CGFloat(ff)))
                tail.addLine(to: CGPoint(x: qp.x + par.width, y: qp.y + par.height))
                if ff <= 0 {
                    if jj == 0 { break }
                    jj -= 1
                    ff = 1
                }
            }
            fl.stroke(tail, with: .color(Color(white: shade).opacity(a * 0.40)),
                      style: StrokeStyle(lineWidth: max(0.6, r * 0.9), lineCap: .round))
            fl.fill(disc(pos, r), with: .color(Color(white: shade).opacity(a)))
        }
    }

    // MARK: Lisibilité

    /// Blanc partout, percé en douceur (feather ~13 pt) derrière les SEULES
    /// boîtes du texte et des champs. Jamais une bande pleine largeur.
    @ViewBuilder
    private func readabilityMask(_ L: Layout) -> some View {
        if readabilityBoxes.isEmpty {
            Rectangle().fill(Color.white)
        } else {
            ZStack {
                Rectangle().fill(Color.white)
                ForEach(0..<readabilityBoxes.count, id: \.self) { i in
                    let b = readabilityBoxes[i]
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(white: NebulaConfig.controlFloor))
                        .frame(width: b.width * L.w, height: b.height * L.h)
                        .position(x: b.midX * L.w, y: b.midY * L.h)
                        .blur(radius: NebulaConfig.controlFeather)
                }
            }
            .compositingGroup()
            .luminanceToAlpha()
        }
    }

    // MARK: Petits outils

    private func disc(_ c: CGPoint, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }

    private func softWhite(_ c: CGPoint, _ r: CGFloat, _ a: Double) -> GraphicsContext.Shading {
        .radialGradient(
            Gradient(stops: [
                .init(color: .white.opacity(a), location: 0.0),
                .init(color: .white.opacity(a * 0.32), location: 0.5),
                .init(color: .clear, location: 1.0)
            ]),
            center: c, startRadius: 0, endRadius: r)
    }

    private func smooth(_ x: Double) -> Double {
        let c = min(max(x, 0), 1)
        return c * c * (3 - 2 * c)
    }
}

// MARK: - Le CHAMP : la photo transformée en donnée
//
// C'est la pièce qui rend impossible le reproche « les particules sont
// n'importe où ». On calcule UNE FOIS, au lancement, à partir du PNG :
//   R = l'énergie      — la luminance normalisée : sous le seuil, RIEN ne naît ;
//   G,B = la tangente  — le gradient de luminance TOURNÉ DE 90°, c'est-à-dire
//                        la direction des filaments eux-mêmes.
// Les shaders n'ont plus qu'à lire cette texture : chaque grain se pose sur de
// la matière et avance le long d'une crête. L'animation épouse la photo par
// construction, pas par réglage.
//
// La texture est écrite en espace LINÉAIRE : la donnée arrive au GPU telle
// qu'on l'a calculée, aucune conversion sRGB ne vient la recourber.

enum NebulaField {
    /// Demi-résolution : le champ est lisse, 426×923 suffisent largement.
    private static let divisor = 2

    static let image: Image = Image(decorative: make(), scale: 1)

    /// À appeler tôt (splash) : le calcul prend quelques millisecondes, autant
    /// qu'il ne tombe pas sur la première image de l'écran.
    static func warmUp() { _ = image }

    private static func make() -> CGImage {
        let ref = NebulaConfig.refSize
        let w = Int(ref.width) / divisor
        let h = Int(ref.height) / divisor

        // ---- 1. La photo, ré-échantillonnée telle quelle (aucune conversion :
        // on lit la donnée du PNG, pas une couleur).
        var lum = [Float](repeating: 0, count: w * h)
        if let src = UIImage(named: NebulaConfig.imageName)?.cgImage {
            var bytes = [UInt8](repeating: 0, count: w * h * 4)
            bytes.withUnsafeMutableBytes { buf in
                guard let ctx = CGContext(
                    data: buf.baseAddress, width: w, height: h,
                    bitsPerComponent: 8, bytesPerRow: w * 4,
                    space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return }
                ctx.interpolationQuality = .high
                ctx.draw(src, in: CGRect(x: 0, y: 0, width: w, height: h))
            }
            for i in 0..<(w * h) { lum[i] = Float(bytes[i * 4]) }
        }

        // ---- 2. Un lissage court : le grain du capteur n'est pas de la matière.
        let smooth = blur(lum, w, h, radius: 2)

        // ---- 3. L'énergie : ce qui reste au-dessus du noir, normalisé et
        // légèrement redressé — c'est le poids de spawn de TOUT le reste.
        var energy = [Float](repeating: 0, count: w * h)
        for i in 0..<(w * h) {
            let e = max(0, (smooth[i] - 2.5) / 42.0)
            energy[i] = powf(min(1, e), 0.80)
        }

        // ---- 4. Le tenseur de structure : la direction des crêtes.
        var jxx = [Float](repeating: 0, count: w * h)
        var jxy = [Float](repeating: 0, count: w * h)
        var jyy = [Float](repeating: 0, count: w * h)
        for y in 1..<(h - 1) {
            for x in 1..<(w - 1) {
                let i = y * w + x
                let gx = (smooth[i + 1] - smooth[i - 1]) * 0.5
                let gy = (smooth[i + w] - smooth[i - w]) * 0.5
                jxx[i] = gx * gx
                jxy[i] = gx * gy
                jyy[i] = gy * gy
            }
        }
        let bxx = blur(jxx, w, h, radius: 6)
        let bxy = blur(jxy, w, h, radius: 6)
        let byy = blur(jyy, w, h, radius: 6)

        // ---- 5. La tangente = le gradient TOURNÉ DE 90°.
        //
        // Une orientation n'a pas de sens : ±T décrivent la même crête. Si on
        // tranche par une règle locale (« vers le haut »), le champ bascule
        // d'un pixel à l'autre là où la crête est horizontale et le flux part
        // en tous sens — c'est exactement ce qui donne l'impression que « les
        // particules sont n'importe où ». On tranche donc par une référence
        // GLOBALE et lisse : le sens de la VEINE elle-même, qui remonte le
        // tracé mesuré. Et là où la crête n'existe pas (champ isotrope), on
        // retombe entièrement sur la veine.
        var data = [UInt8](repeating: 0, count: w * h * 4)
        for y in 0..<h {
            for x in 0..<w {
                let i = y * w + x
                let ref = veinDirection(u: Float(x) / Float(w),
                                        v: Float(y) / Float(h),
                                        w: Float(w), h: Float(h))
                // L'angle DOUBLÉ : la seule représentation où l'on peut
                // moyenner une orientation sans qu'elle s'annule.
                let a2 = atan2f(2 * bxy[i], bxx[i] - byy[i])
                let aGrad = a2 * 0.5
                var tx = -sinf(aGrad)          // gradient tourné de 90°
                var ty = cosf(aGrad)
                if tx * ref.0 + ty * ref.1 < 0 { tx = -tx; ty = -ty }

                // La cohérence de la crête : sous 0,35, il n'y a pas de
                // filament, seulement du bruit — on suit la veine.
                let tr = bxx[i] + byy[i]
                let dif = sqrtf((bxx[i] - byy[i]) * (bxx[i] - byy[i])
                                + 4 * bxy[i] * bxy[i])
                let coh = tr > 1e-5 ? min(1, dif / tr / 0.35) : 0
                tx = tx * coh + ref.0 * (1 - coh)
                ty = ty * coh + ref.1 * (1 - coh)
                let n = max(sqrtf(tx * tx + ty * ty), 1e-5)
                tx /= n; ty /= n

                let k = i * 4
                data[k]     = UInt8(max(0, min(255, energy[i] * 255)))
                data[k + 1] = UInt8(max(0, min(255, (0.5 + 0.5 * tx) * 255)))
                data[k + 2] = UInt8(max(0, min(255, (0.5 + 0.5 * ty) * 255)))
                data[k + 3] = 255
            }
        }

        // ---- 6. Les sphères sont des OBJETS, pas de la nébuleuse : aucune
        // poussière ne doit ramper dessus. On y éteint l'énergie.
        for imp in NebulaConfig.imps {
            guard let limb = imp.limb else { continue }
            let cx = Float(limb.c.x) * Float(w)
            let cy = Float(limb.c.y) * Float(h)
            let r = Float(limb.r) / Float(divisor) * 1.04
            let x0 = max(0, Int(cx - r)), x1 = min(w - 1, Int(cx + r))
            let y0 = max(0, Int(cy - r)), y1 = min(h - 1, Int(cy + r))
            guard x0 < x1, y0 < y1 else { continue }
            for y in y0...y1 {
                for x in x0...x1 {
                    let dx = Float(x) - cx, dy = Float(y) - cy
                    let d = sqrtf(dx * dx + dy * dy)
                    guard d < r else { continue }
                    let k = (y * w + x) * 4
                    let fadeIn = min(1, (r - d) / max(r * 0.18, 1))
                    data[k] = UInt8(Float(data[k]) * (1 - 0.88 * fadeIn))
                }
            }
        }

        // ---- 7. Espace LINÉAIRE : la donnée n'est pas une couleur.
        let space = CGColorSpace(name: CGColorSpace.linearSRGB) ?? CGColorSpaceCreateDeviceRGB()
        let img = data.withUnsafeMutableBytes { buf -> CGImage? in
            CGContext(data: buf.baseAddress, width: w, height: h,
                      bitsPerComponent: 8, bytesPerRow: w * 4, space: space,
                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)?.makeImage()
        }
        return img ?? blankField(w, h)
    }

    /// Le sens de la VEINE au point (u,v) — la référence globale qui tranche
    /// l'ambiguïté ±T. Elle REMONTE le tracé mesuré, en unités pixel du champ.
    private static func veinDirection(u: Float, v: Float,
                                      w: Float, h: Float) -> (Float, Float) {
        let pts = NebulaConfig.veinPts
        var best = Float.greatestFiniteMagnitude
        var dir: (Float, Float) = (0, -1)
        // L'espace est corrigé de l'aspect : une distance vaut la même chose
        // en x et en y, comme sur la photo.
        let px = u * w, py = v * h
        for i in 0..<(pts.count - 1) {
            let ax = Float(pts[i].x) * w, ay = Float(pts[i].y) * h
            let bx = Float(pts[i + 1].x) * w, by = Float(pts[i + 1].y) * h
            let ex = bx - ax, ey = by - ay
            let t = max(0, min(1, ((px - ax) * ex + (py - ay) * ey)
                               / max(ex * ex + ey * ey, 1e-5)))
            let dx = px - (ax + ex * t), dy = py - (ay + ey * t)
            let d = dx * dx + dy * dy
            if d < best {
                best = d
                // Vers le HAUT du tracé : de i+1 vers i.
                let n = max(sqrtf(ex * ex + ey * ey), 1e-5)
                dir = (-ex / n, -ey / n)
            }
        }
        return dir
    }

    /// Flou séparable par deux passes de boîte : suffisant, et instantané.
    private static func blur(_ src: [Float], _ w: Int, _ h: Int, radius: Int) -> [Float] {
        var a = src, b = [Float](repeating: 0, count: w * h)
        for _ in 0..<2 {
            for y in 0..<h {
                var sum: Float = 0
                let row = y * w
                for x in -radius...radius { sum += a[row + min(w - 1, max(0, x))] }
                let inv = 1 / Float(radius * 2 + 1)
                for x in 0..<w {
                    b[row + x] = sum * inv
                    sum -= a[row + min(w - 1, max(0, x - radius))]
                    sum += a[row + min(w - 1, max(0, x + radius + 1))]
                }
            }
            for x in 0..<w {
                var sum: Float = 0
                for y in -radius...radius { sum += b[min(h - 1, max(0, y)) * w + x] }
                let inv = 1 / Float(radius * 2 + 1)
                for y in 0..<h {
                    a[y * w + x] = sum * inv
                    sum -= b[min(h - 1, max(0, y - radius)) * w + x]
                    sum += b[min(h - 1, max(0, y + radius + 1)) * w + x]
                }
            }
        }
        return a
    }

    private static func blankField(_ w: Int, _ h: Int) -> CGImage {
        var data = [UInt8](repeating: 128, count: w * h * 4)
        for i in 0..<(w * h) { data[i * 4] = 0 }
        let space = CGColorSpace(name: CGColorSpace.linearSRGB) ?? CGColorSpaceCreateDeviceRGB()
        return data.withUnsafeMutableBytes { buf -> CGImage in
            CGContext(data: buf.baseAddress, width: w, height: h,
                      bitsPerComponent: 8, bytesPerRow: w * 4, space: space,
                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!.makeImage()!
        }
    }
}
