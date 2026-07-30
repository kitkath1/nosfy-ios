import SwiftUI

// MARK: - L'aura des diablotins
//
// ⚠️ RÈGLE ABSOLUE : AUCUN halo radial autour d'une sphère. Pas de cercle
// diffus, pas de blur ≥ 6 px, pas d'anneau fantôme. Toute la vie d'un
// diablotin habite son LIMBE.
//
// Le modèle exact du liseré est l'arête de lumière du bouton primaire
// (Theme.swift, WoopPrimaryButtonStyle) : un cheveu blanc d'un point,
// dégradé 0,65 → 0,10 → 0. On le reproduit ici sur l'arête des sphères, mais
// posé sur la CRÊTE RÉELLE mesurée dans la photo (72 relevés de 5° : rayon du
// rim et brillance du rim). Conséquence structurelle : le cheveu ne peut
// s'allumer QUE là où la photo est déjà allumée — un cercle complet est
// impossible par construction, pas par réglage.
//
// S'y ajoutent : une lumière douce qui PASSE (croissant mobile, 10-18 s),
// 2-3 glints spéculaires qui parcourent l'arc, des micro-facettes au ras du
// contour, des particules nées sur le contour qui s'échappent et meurent,
// des mèches de brume au-dessus des têtes, de la fumée TRÈS NOIRE aux
// épaules — et les yeux.

struct DevilAuraOverlay: View {
    var t: Double
    var tilt: CGVector = .zero

    var body: some View {
        GeometryReader { geo in
            let L = LivingNebulaBackground.Layout(size: geo.size)
            let fade = smooth(t / NebulaConfig.revealDuration)

            Canvas { ctx, _ in
                for (i, imp) in NebulaConfig.imps.enumerated() {
                    drawSmoke(ctx, imp, i, L, fade)
                }
                for (i, imp) in NebulaConfig.imps.enumerated() {
                    drawFilaments(ctx, imp, i, L, fade)
                    drawLimb(ctx, imp, i, L, fade)
                }
                for (i, imp) in NebulaConfig.imps.enumerated() {
                    drawEyes(ctx, imp, i, L, fade)
                }
            }
            .frame(width: L.w, height: L.h)
        }
        .allowsHitTesting(false)
    }

    // MARK: Le liseré-diamant

    private func drawLimb(_ context: GraphicsContext, _ imp: NebulaConfig.Imp,
                          _ index: Int, _ L: LivingNebulaBackground.Layout,
                          _ fade: Double) {
        guard let limb = imp.limb else { return }
        let c = L.map(limb.c)
        let r = limb.r * L.scale
        let n = limb.prof.count
        guard n > 8, limb.ridge.count == n else { return }

        var edge = context
        edge.blendMode = .plusLighter

        /// La brillance du rim MESURÉE dans la photo, à l'angle voulu.
        func rim(_ ang: Double) -> Double {
            var a = ang / (2 * .pi) * Double(n)
            a = a.truncatingRemainder(dividingBy: Double(n))
            if a < 0 { a += Double(n) }
            let i = Int(a) % n
            let f = a - Double(Int(a))
            return limb.prof[i] * (1 - f) + limb.prof[(i + 1) % n] * f
        }
        /// Le RAYON du rim au même angle : le cheveu suit la crête, pas un cercle.
        func ridge(_ ang: Double) -> CGFloat {
            var a = ang / (2 * .pi) * Double(n)
            a = a.truncatingRemainder(dividingBy: Double(n))
            if a < 0 { a += Double(n) }
            let i = Int(a) % n
            let f = a - Double(Int(a))
            return CGFloat(limb.ridge[i] * (1 - f) + limb.ridge[(i + 1) % n] * f) * r
        }
        func point(_ ang: Double) -> CGPoint {
            let rr = ridge(ang)
            return CGPoint(x: c.x + CGFloat(cos(ang)) * rr,
                           y: c.y + CGFloat(sin(ang)) * rr)
        }

        // Le bruit angulaire du diamant : deux porteuses de période 40-70°,
        // dérive lente. C'est lui qui éteint ~1/3 de l'arc éligible : le
        // cheveu ne vit jamais sur plus des deux tiers du contour visible.
        let p1 = NebulaConfig.lerp(NebulaConfig.hairNoisePeriodDeg, NebulaConfig.hash(index, 78))
        let p2 = NebulaConfig.lerp(NebulaConfig.hairNoisePeriodDeg, NebulaConfig.hash(index, 79))
        let f1 = 360.0 / p1, f2 = 360.0 / p2
        func spark(_ ang: Double) -> Double {
            let a = 0.5 + 0.5 * sin(ang * f1 + t * 0.55 + Double(index) * 2.7)
            let b = 0.5 + 0.5 * sin(-ang * f2 + t * 0.34 + Double(index) * 5.1)
            return a * 0.62 + b * 0.38
        }

        // La LUMIÈRE DOUCE QUI PASSE : un croissant large qui traverse le
        // limbe en 10-18 s. Jamais un halo fixe, jamais un cercle.
        let sweepT = NebulaConfig.lerp(NebulaConfig.sweepPeriod, NebulaConfig.hash(index, 80))
        let sweepC = ((t / sweepT + NebulaConfig.hash(index, 81))
            .truncatingRemainder(dividingBy: 1)) * 2 * .pi

        // ---- 1. LE CHEVEU. Un trait CONTINU de 1,15 pt posé sur la crête
        // mesurée. Le pas est de 1,25° : à ce rythme les tronçons se
        // recouvrent largement et l'opacité varie en douceur de l'un à
        // l'autre — jamais un chapelet de perles, jamais un pointillé.
        // Les DEUX portes (crête de la photo, bruit angulaire) sont
        // adoucies : le cheveu s'allume et meurt, il ne clignote pas.
        let segs = n * 4
        let dA = 2 * .pi / Double(segs)
        func hairAlpha(_ ang: Double) -> Double {
            let p = rim(ang)
            let ramp = smooth((p - NebulaConfig.hairRimGate) / 0.20)
            guard ramp > 0.001 else { return 0 }
            let gate = smooth((spark(ang) - 0.28) / 0.24)
            guard gate > 0.001 else { return 0 }
            var dd = ang - sweepC
            if dd > .pi { dd -= 2 * .pi }
            if dd < -.pi { dd += 2 * .pi }
            let sweep = exp(-dd * dd / NebulaConfig.sweepWidth)
            // Le dégradé du bouton velours : vif en tête, 0,10 en pied, 0 au bout.
            let base = NebulaConfig.hairAlphaMin
                + (NebulaConfig.hairAlphaMax - NebulaConfig.hairAlphaMin) * pow(ramp, 0.80)
            return min(NebulaConfig.hairAlphaMax,
                       base * (0.26 + 0.74 * gate) * (0.40 + 0.85 * sweep)) * fade
        }
        var prevPt = point(0)
        var prevA = hairAlpha(0)
        for s in 1...segs {
            let ang = Double(s) * dA
            let pt = point(ang)
            let a = hairAlpha(ang)
            let mid = (prevA + a) * 0.5
            if mid > 0.015 {
                var arc = Path()
                arc.move(to: prevPt)
                arc.addLine(to: pt)
                edge.stroke(arc, with: .color(.white.opacity(mid)),
                            style: StrokeStyle(lineWidth: NebulaConfig.hairWidth,
                                               lineCap: .round))
            }
            prevPt = pt
            prevA = a
        }

        // ---- 2. Les GLINTS spéculaires : 2-3 étincelles de 3-5 px qui
        // PARCOURENT l'arc en 8-12 s, avec un streak posé LE LONG de l'arête.
        let glintCount = NebulaConfig.glintCountRange.lowerBound
            + (index % (NebulaConfig.glintCountRange.count))
        for g in 0..<glintCount {
            let gid = index * 5 + g
            let lap = NebulaConfig.lerp(NebulaConfig.glintLap, NebulaConfig.hash(gid, 84))
            let dir: Double = gid % 2 == 0 ? 1 : -1
            let ang = (t / lap + NebulaConfig.hash(gid, 85)) * 2 * .pi * dir
            let u = (t / (lap * 0.83) + NebulaConfig.hash(gid, 86))
                .truncatingRemainder(dividingBy: 1)
            let ga = pow(max(0, sin(.pi * u)), 1.4) * (0.10 + 0.90 * rim(ang))
            guard ga > 0.05 else { continue }
            let gp = point(ang)
            let tx = CGFloat(-sin(ang)), ty = CGFloat(cos(ang))
            let sl: CGFloat = 2.8
            var streak = Path()
            streak.move(to: CGPoint(x: gp.x - tx * sl, y: gp.y - ty * sl))
            streak.addLine(to: CGPoint(x: gp.x + tx * sl, y: gp.y + ty * sl))
            edge.stroke(streak, with: .color(.white.opacity(0.42 * ga * fade)),
                        style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
            let gr = NebulaConfig.lerp(NebulaConfig.glintSize, NebulaConfig.hash(gid, 88))
            edge.fill(disc(gp, gr), with: .radialGradient(
                Gradient(stops: [
                    .init(color: .white.opacity(0.95 * ga * fade), location: 0.0),
                    .init(color: .white.opacity(0.28 * ga * fade), location: 0.5),
                    .init(color: .clear, location: 1.0)
                ]),
                center: gp, startRadius: 0, endRadius: gr))
        }

        // ---- 3. Les micro-facettes : 0,5-1,5 px AU RAS du contour, cadences
        // toutes différentes — la taille diamant, pas un scintillement.
        for k in 0..<12 {
            let fid = index * 20 + k
            let fAng = NebulaConfig.hash(fid, 90) * 6.283
            guard rim(fAng) > 0.12 else { continue }
            let freq = 1.0 + 3.2 * NebulaConfig.hash(fid, 91)
            let tw = pow(0.5 + 0.5 * sin(t * freq + NebulaConfig.hash(fid, 92) * 6.283), 4.0)
            let fa = 0.55 * tw * (0.10 + 0.90 * rim(fAng)) * fade
            guard fa > 0.03 else { continue }
            let fp = point(fAng)
            let fr = 0.35 + 0.5 * CGFloat(NebulaConfig.hash(fid, 93))
            edge.fill(disc(fp, fr), with: .color(.white.opacity(fa)))
        }

        // ---- 4. Les particules nées sur SON contour : elles s'échappent en
        // dérivant, scintillent, puis meurent — plus denses côté lumière.
        for k in 0..<NebulaConfig.limbSparkCount {
            let pid = index * 16 + k
            let life = NebulaConfig.lerp(NebulaConfig.limbSparkLife, NebulaConfig.hash(pid, 97))
            let u = ((t + NebulaConfig.hash(pid, 98) * life) / life)
                .truncatingRemainder(dividingBy: 1)
            let ang = NebulaConfig.hash(pid, 99) * 6.283 + t * 0.02
            let a = sin(.pi * u) * 0.30 * (0.10 + 0.90 * rim(ang)) * fade
            guard a > 0.02 else { continue }
            let drift = CGFloat(u) * NebulaConfig.lerp(NebulaConfig.limbSparkDrift,
                                                       NebulaConfig.hash(pid, 100))
            let sway = CGFloat(sin(t * 0.9 + Double(pid))) * 1.6
            let rr = ridge(ang) + drift
            let pp = CGPoint(x: c.x + CGFloat(cos(ang)) * rr + sway,
                             y: c.y + CGFloat(sin(ang)) * rr)
            let pr = 0.4 + 0.5 * CGFloat(NebulaConfig.hash(pid, 101))
            edge.fill(disc(pp, pr), with: .color(.white.opacity(a)))
        }
    }

    // MARK: Les mèches au-dessus des têtes

    /// 1 à 4 mèches de brume TRÈS fine par gros diablotin (0 ou 1 pour les
    /// petits) : elles naissent derrière/au-dessus de la tête, montent de
    /// 12 à 60 pt, courbent en Bézier irrégulière (jamais une droite),
    /// s'épaississent de 0,3 à 1,3 pt, s'effacent vers le bout, ondulent, se
    /// dissolvent puis se reforment. Phase, vitesse, courbure et intensité
    /// DIFFÉRENTES par diablotin — à première vue l'image paraît fixe.
    private func drawFilaments(_ context: GraphicsContext, _ imp: NebulaConfig.Imp,
                               _ index: Int, _ L: LivingNebulaBackground.Layout,
                               _ fade: Double) {
        guard imp.filaments > 0 else { return }
        var g = context
        g.blendMode = .plusLighter

        let anchorC: CGPoint
        let headR: CGFloat
        if let limb = imp.limb {
            anchorC = L.map(limb.c)
            headR = limb.r * L.scale
        } else {
            let e0 = L.map(imp.eyes[0].c), e1 = L.map(imp.eyes[1].c)
            anchorC = CGPoint(x: (e0.x + e1.x) / 2, y: (e0.y + e1.y) / 2)
            headR = hypot(e1.x - e0.x, e1.y - e0.y) * 1.5
        }
        let rise = imp.filamentRise * L.scale / 2.2

        for k in 0..<imp.filaments {
            let fid = index * 7 + k
            let cycle = NebulaConfig.lerp(NebulaConfig.filamentCycle, NebulaConfig.hash(fid, 200))
            let u = ((t + NebulaConfig.hash(fid, 201) * cycle) / cycle)
                .truncatingRemainder(dividingBy: 1)
            // Elle se dissout puis se reforme : jamais présente en permanence.
            let alive = sin(.pi * min(1, u * 1.18))
            guard alive > 0.03 else { continue }

            // Le pied : derrière/au-dessus de la tête, jamais deux au même endroit.
            let spread = (NebulaConfig.hash(fid, 202) - 0.5) * 1.5
            let footAng = -.pi / 2 + spread
            let foot = CGPoint(x: anchorC.x + CGFloat(cos(footAng)) * headR * 0.94,
                               y: anchorC.y + CGFloat(sin(footAng)) * headR * 0.94)
            let h = rise * (0.55 + 0.75 * CGFloat(NebulaConfig.hash(fid, 203)))
            let bend = CGFloat(NebulaConfig.hash(fid, 204) - 0.5) * h * 0.85
            let wob = CGFloat(sin(t * (0.30 + 0.34 * NebulaConfig.hash(fid, 205))
                                  + Double(fid) * 1.9)) * h * 0.16

            let p0 = foot
            let p1 = CGPoint(x: foot.x + bend * 0.45 + wob, y: foot.y - h * 0.42)
            let p2 = CGPoint(x: foot.x + bend * 1.05 - wob * 0.7, y: foot.y - h * 0.78)
            let p3 = CGPoint(x: foot.x + bend * 0.72 + wob * 0.4, y: foot.y - h)

            // 16 tronçons : la mèche s'affine et s'éteint vers le bout, sans
            // qu'aucun dégradé de trait ne soit nécessaire.
            let steps = 16
            var prev = p0
            for s in 1...steps {
                let v = CGFloat(s) / CGFloat(steps)
                let pt = bezier(p0, p1, p2, p3, v)
                let taper = Double(1 - v)
                let w = NebulaConfig.lerp(NebulaConfig.filamentWidth, Double(1 - v) * 0.9)
                let a = NebulaConfig.filamentAlpha * alive * pow(taper, 1.35)
                    * (0.55 + 0.45 * NebulaConfig.hash(fid, 206)) * fade
                if a > 0.012 {
                    var seg = Path()
                    seg.move(to: prev)
                    seg.addLine(to: pt)
                    g.drawLayer { layer in
                        layer.addFilter(.blur(radius: NebulaConfig.filamentBlur))
                        layer.stroke(seg, with: .color(.white.opacity(a)),
                                     style: StrokeStyle(lineWidth: w, lineCap: .round))
                    }
                }
                prev = pt
            }
        }
    }

    // MARK: La fumée noire

    /// Des volutes TRÈS NOIRES qui montent des épaules : elles mangent les
    /// étoiles sur leur passage — c'est ça qui les rend réelles. Discrètes.
    private func drawSmoke(_ context: GraphicsContext, _ imp: NebulaConfig.Imp,
                           _ index: Int, _ L: LivingNebulaBackground.Layout,
                           _ fade: Double) {
        guard imp.smoke, let limb = imp.limb else { return }
        let c = L.map(limb.c)
        let r = limb.r * L.scale
        for m in 0..<2 {
            let id = index * 2 + m
            let cycle = NebulaConfig.lerp(NebulaConfig.smokeCycle, NebulaConfig.hash(id, 60))
            let u = ((t + NebulaConfig.hash(id, 61) * cycle) / cycle)
                .truncatingRemainder(dividingBy: 1)
            let growth = sin(.pi * u)
            let alpha = NebulaConfig.smokeAlpha * growth * fade
            guard alpha > 0.02 else { continue }
            let s: CGFloat = m == 0 ? -1 : 1
            let sway = CGFloat(sin(t * 0.08 + Double(index) + Double(m) * 2.4)) * r * 0.3
            let mc = CGPoint(x: c.x + s * r * 0.86 + sway,
                             y: c.y + r * 0.55 - r * CGFloat(u) * 1.25)
            let mr = r * (0.34 + 0.42 * CGFloat(growth))
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: mr * 0.5))
                layer.fill(Path(ellipseIn: CGRect(x: mc.x - mr, y: mc.y - mr * 0.7,
                                                  width: mr * 2, height: mr * 1.4)),
                           with: .color(.black.opacity(alpha)))
            }
        }
    }

    // MARK: Les yeux

    private func drawEyes(_ context: GraphicsContext, _ imp: NebulaConfig.Imp,
                          _ index: Int, _ L: LivingNebulaBackground.Layout,
                          _ fade: Double) {
        switch NebulaConfig.eyeMode {
        case .glowOnly: drawEyeGlow(context, imp, index, L, fade)
        case .animated: drawEyeLife(context, imp, index, L, fade)
        }
    }

    /// Mode B — on ne redessine RIEN : un très léger halo blanc flouté
    /// derrière les yeux de la photo, pulsation 5-12 %, désynchronisée.
    private func drawEyeGlow(_ context: GraphicsContext, _ imp: NebulaConfig.Imp,
                             _ index: Int, _ L: LivingNebulaBackground.Layout,
                             _ fade: Double) {
        var g = context
        g.blendMode = .plusLighter
        for (j, eye) in imp.eyes.enumerated() {
            let id = index * 3 + j
            let period = NebulaConfig.lerp(NebulaConfig.glowOnlyPeriod, NebulaConfig.hash(id, 210))
            let amp = NebulaConfig.lerp(NebulaConfig.glowOnlyPulse, NebulaConfig.hash(id, 211))
            let pulse = 1 + amp * sin(t * 2 * .pi / period + NebulaConfig.hash(id, 212) * 6.283)
            let p = L.map(eye.c)
            let r = eye.len * L.scale * 0.95
            g.drawLayer { layer in
                layer.addFilter(.blur(radius: r * 0.35))
                layer.fill(disc(p, r), with: .radialGradient(
                    Gradient(stops: [
                        .init(color: .white.opacity(NebulaConfig.glowOnlyAlpha * pulse * fade), location: 0),
                        .init(color: .clear, location: 1)
                    ]),
                    center: p, startRadius: 0, endRadius: r))
            }
        }
    }

    /// Mode A — les yeux figés sont RECOUVERTS par des caches couleur-corps
    /// serrés sur la fente, et des yeux CODÉS vivent par-dessus : le regard
    /// glisse, les clignements sont désynchronisés, la braise respire.
    private func drawEyeLife(_ context: GraphicsContext, _ imp: NebulaConfig.Imp,
                             _ index: Int, _ L: LivingNebulaBackground.Layout,
                             _ fade: Double) {
        // ---- Les caches : épousent EXACTEMENT la forme de la fente (×1,18 en
        // longueur, ×1,55 en hauteur), donc pas de disque noir autour de
        // l'œil — la lueur de la photo sur la sphère survit.
        let grey = imp.body / 255
        for eye in imp.eyes {
            let p = L.map(eye.c)
            let cover = NebulaConfig.fierceEyePath(
                center: p, len: eye.len * L.scale * 1.18,
                ratio: eye.ratio * 0.761, tilt: eye.tilt,
                inward: eye.inward, openness: 1)
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: 2.6))
                layer.fill(cover, with: .color(Color(white: grey).opacity(fade)))
            }
        }

        // ---- La vie.
        let wake = awake(imp, index)
        let c = (t + imp.phase * 3).truncatingRemainder(dividingBy: imp.blinkPeriod)
        let window = imp.blinkPeriod - NebulaConfig.blinkDuration
        let blink = c > window
            ? max(0, sin((c - window) / NebulaConfig.blinkDuration * .pi)) : 0
        let openness = max(0, 1 - blink) * wake
        guard openness > 0.03 else { return }
        let ember = 0.80 + 0.20 * sin(t * 1.1 + imp.phase * 4) * sin(t * 0.6 + imp.phase)
        let a = ember * openness * fade

        // Le REGARD : une dérive à deux porteuses, commune aux deux yeux — il
        // se pose quelque part, revient, repart. Jamais un balayage régulier.
        let ewAvg = (imp.eyes[0].len + imp.eyes[1].len) / 2 * L.scale
        let ehAvg = ewAvg / 2.6
        let gx = (CGFloat(sin(t * 0.071 + imp.phase * 2.3))
                  + CGFloat(sin(t * 0.023 + imp.phase * 4.1))) * 0.5 * ewAvg * imp.gaze
        let gy = CGFloat(cos(t * 0.049 + imp.phase * 1.7)) * ehAvg * imp.gaze * 0.6

        for eye in imp.eyes {
            let e = L.map(eye.c)
            let len = eye.len * L.scale
            let g = CGPoint(x: e.x + gx, y: e.y + gy)

            // L'orbite lumineuse DE LA PHOTO, reconstruite au même profil :
            // l'œil vit dans sa lueur, pas dans un trou. Ce n'est PAS un halo
            // de sphère — c'est la brûlure de l'œil, serrée sur lui.
            var glow = context
            glow.blendMode = .plusLighter
            let hw = len * 0.78, hv = len * 0.52
            glow.fill(
                Path(ellipseIn: CGRect(x: e.x - hw, y: e.y - hv,
                                       width: hw * 2, height: hv * 2)),
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: .white.opacity(0.24 * a), location: 0.0),
                        .init(color: .white.opacity(0.09 * a), location: 0.5),
                        .init(color: .clear, location: 1.0)
                    ]),
                    center: e, startRadius: 0, endRadius: max(hw, hv)))

            // La FENTE : deux cubiques lisses, coin externe haut et épais,
            // fuselage vers une pointe interne qui plonge vers l'arête du nez.
            // Feather 1,4 px SEULEMENT : elle reste tranchante comme la photo.
            let slit = NebulaConfig.fierceEyePath(
                center: g, len: len, ratio: eye.ratio, tilt: eye.tilt,
                inward: eye.inward, openness: max(0.05, CGFloat(openness)))
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: NebulaConfig.eyeFeather))
                layer.fill(slit, with: .color(.white.opacity(0.58 * a)))
            }
            let hh = len / (eye.ratio * 1.37)
            context.fill(slit, with: .linearGradient(
                Gradient(stops: [
                    .init(color: .white.opacity(min(1, 0.99 * a)), location: 0.0),
                    .init(color: Color(white: 0.86).opacity(0.88 * a), location: 1.0)
                ]),
                startPoint: CGPoint(x: g.x, y: g.y - hh),
                endPoint: CGPoint(x: g.x, y: g.y + hh)))
        }
    }

    /// L'éveil : les dormeurs s'éteignent 4-6 s par cycle de 14-20 s. Les
    /// caches restent, les yeux codés disparaissent — l'orbe redevient aveugle.
    private func awake(_ imp: NebulaConfig.Imp, _ index: Int) -> Double {
        guard imp.sleeper else { return 1 }
        let period = NebulaConfig.lerp(NebulaConfig.sleepCycle, NebulaConfig.hash(index, 50))
        let asleep = NebulaConfig.lerp(NebulaConfig.sleepLength, NebulaConfig.hash(index, 51))
        let c = (t + imp.phase * 5).truncatingRemainder(dividingBy: period)
        guard c < asleep else { return 1 }
        let out = smooth(c / 0.5)
        let back = 1 - smooth((c - (asleep - 0.5)) / 0.5)
        return 1 - min(out, back)
    }

    // MARK: Petits outils

    private func disc(_ c: CGPoint, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }

    private func bezier(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint,
                        _ p3: CGPoint, _ u: CGFloat) -> CGPoint {
        let v = 1 - u
        let a = v * v * v, b = 3 * v * v * u, c = 3 * v * u * u, d = u * u * u
        return CGPoint(x: a * p0.x + b * p1.x + c * p2.x + d * p3.x,
                       y: a * p0.y + b * p1.y + c * p2.y + d * p3.y)
    }

    private func smooth(_ x: Double) -> Double {
        let c = min(max(x, 0), 1)
        return c * c * (3 - 2 * c)
    }
}
