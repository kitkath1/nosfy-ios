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

        // ---- LES TROUS. Trois porteuses de périodes incommensurables (137°,
        // 89°, 211° : aucun rapport simple, donc aucune périodicité
        // perceptible), seuillées dur. Là où `open` vaut 0, le cheveu n'existe
        // PAS — pas « atténué » : mort. Les paquets morts font 20 à 60°.
        // Dérive de 0,035 rad/s : ils respirent, ils ne défilent pas.
        let per = NebulaConfig.hairGapPeriodsDeg
        let wg = NebulaConfig.hairGapWeights
        let wSum = wg.reduce(0, +)
        let phG = (0..<per.count).map { NebulaConfig.hash(index * 4 + $0, 78) * 6.283 }
        func open(_ ang: Double) -> Double {
            let d = ang * 180 / .pi + t * NebulaConfig.hairGapDrift * 180 / .pi
            var acc = 0.0
            for k in 0..<per.count {
                let dir: Double = k % 2 == 0 ? 1 : -1
                acc += wg[k] * (0.5 + 0.5 * sin(dir * d * 2 * .pi / per[k] + phG[k]))
            }
            return smooth((acc / wSum - NebulaConfig.hairGapThreshold)
                          / NebulaConfig.hairGapRamp)
        }
        let ph2 = phG[1], ph3 = phG[2]
        /// La largeur RESPIRE le long de l'arc, sur d'autres porteuses encore.
        func swell(_ ang: Double) -> CGFloat {
            let d = ang * 180 / .pi
            let u = 0.5 + 0.5 * sin(d * 2 * .pi / 73 + ph2 * 1.7)
            let v = 0.5 + 0.5 * sin(-d * 2 * .pi / 41 + ph3 * 2.3 + t * 0.11)
            return NebulaConfig.lerp(NebulaConfig.hairWidthSwing, u * 0.65 + v * 0.35)
        }

        // ---- OÙ le cheveu a le droit de vivre. Le relevé de la photo est
        // maximal AU SOMMET DU CRÂNE : l'y laisser à pleine force donne un
        // DIADÈME (le défaut relevé au round précédent). On y coupe donc 78 %,
        // et l'on prime les FLANCS (|cos θ|) et les JOUES (moitié basse) — là
        // où la lumière frise vraiment sur une sphère.
        func place(_ ang: Double) -> Double {
            let c = cos(ang), s = sin(ang)          // s > 0 = vers le bas
            var dd = ang + .pi / 2                  // écart au sommet du crâne
            while dd > .pi { dd -= 2 * .pi }
            while dd < -.pi { dd += 2 * .pi }
            let cw = NebulaConfig.hairCrownWidthDeg * .pi / 180
            let crown = 1 - NebulaConfig.hairCrownKill * exp(-dd * dd / (cw * cw))
            let flank = 1 - NebulaConfig.hairFlankBoost * (1 - pow(abs(c), 0.85))
            let cheek = 1 + NebulaConfig.hairCheekBoost * max(0, s)
            return crown * flank * cheek
        }

        // La LUMIÈRE DOUCE QUI PASSE : un croissant large qui traverse le
        // limbe en 10-18 s. Jamais un halo fixe, jamais un cercle.
        let sweepT = NebulaConfig.lerp(NebulaConfig.sweepPeriod, NebulaConfig.hash(index, 80))
        let sweepC = ((t / sweepT + NebulaConfig.hash(index, 81))
            .truncatingRemainder(dividingBy: 1)) * 2 * .pi

        func hairAlpha(_ ang: Double) -> Double {
            let o = open(ang)
            guard o > 0.001 else { return 0 }
            let ramp = smooth((rim(ang) - NebulaConfig.hairRimGate) / NebulaConfig.hairRimRamp)
            guard ramp > 0.001 else { return 0 }
            var dd = ang - sweepC
            if dd > .pi { dd -= 2 * .pi }
            if dd < -.pi { dd += 2 * .pi }
            let sweep = exp(-dd * dd / NebulaConfig.sweepWidth)
            // Le dégradé du bouton velours : vif en tête, 0,10 en pied, 0 au bout.
            let base = NebulaConfig.hairAlphaMin
                + (NebulaConfig.hairAlphaMax - NebulaConfig.hairAlphaMin) * pow(ramp, 0.80)
            return min(NebulaConfig.hairAlphaMax,
                       base * o * place(ang) * (0.45 + 0.80 * sweep)) * fade
        }

        // ---- 1. LE CHEVEU, en RUBANS FUSELÉS.
        //
        // ⚠️ Pourquoi pas un stroke : des centaines de tronçons de 0,8 pt
        // empilés en plusLighter voient leurs bouts arrondis se recouvrir, les
        // alphas s'ajoutent périodiquement, et le liseré se lit comme une
        // CHAÎNETTE PERLÉE — c'est exactement le défaut relevé au round
        // précédent. Ici, chaque tronçon VIVANT de l'arc est un ruban FERMÉ,
        // rempli UNE seule fois : le recouvrement additif est structurellement
        // impossible. Le ruban naît d'une largeur nulle et meurt d'une largeur
        // nulle — le cheveu s'allume et s'éteint sans jamais couper net.
        struct Sample { let p: CGPoint; let n: CGPoint; let a: Double; let ang: Double }
        let step = 1.5 * .pi / 180
        let count = Int((2 * Double.pi / step).rounded())
        var run: [Sample] = []

        func flush() {
            defer { run.removeAll(keepingCapacity: true) }
            guard run.count >= 3 else { return }
            let m = Double(run.count - 1)
            // Le demi-cheveu au rang i : fuseau nul aux deux bouts (sin^0,65 :
            // ventre large, pointes fines), largeur qui respire le long de
            // l'arc, et un peu d'épaisseur là où le rim est vif.
            func half(_ i: Int) -> CGFloat {
                let u = Double(i) / m
                let taper = pow(sin(.pi * u), 0.65)
                let e = run[i]
                return NebulaConfig.hairWidth * swell(e.ang) * CGFloat(taper)
                    * CGFloat(0.40 + 0.60 * e.a / NebulaConfig.hairAlphaMax) * 0.5
            }
            var ribbon = Path()
            for i in 0..<run.count {
                let w = half(i), e = run[i]
                let p = CGPoint(x: e.p.x + e.n.x * w, y: e.p.y + e.n.y * w)
                if i == 0 { ribbon.move(to: p) } else { ribbon.addLine(to: p) }
            }
            for i in stride(from: run.count - 1, through: 0, by: -1) {
                let w = half(i), e = run[i]
                ribbon.addLine(to: CGPoint(x: e.p.x - e.n.x * w, y: e.p.y - e.n.y * w))
            }
            ribbon.closeSubpath()
            // Un SEUL remplissage : aucun recouvrement additif possible, donc
            // aucune perle. L'opacité du tronçon est sa moyenne pondérée par le
            // fuseau — les bouts effilés font le reste du dégradé.
            var num = 0.0, den = 0.0
            for i in 0..<run.count {
                let wgt = pow(sin(.pi * Double(i) / m), 0.65) + 0.08
                num += run[i].a * wgt
                den += wgt
            }
            edge.fill(ribbon, with: .color(.white.opacity(min(1, num / max(den, 1e-6) * 1.22))))
        }

        for k in 0...count {
            let ang = Double(k) * step
            let a = hairAlpha(ang)
            if a > 0.012 {
                // La normale au contour (radiale) : le ruban a l'épaisseur d'un
                // cheveu, perpendiculaire à l'arête, comme l'arête du bouton.
                run.append(Sample(p: point(ang),
                                  n: CGPoint(x: CGFloat(cos(ang)), y: CGFloat(sin(ang))),
                                  a: a, ang: ang))
            } else if !run.isEmpty {
                flush()
            }
        }
        flush()

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
                * (0.40 + 0.60 * place(ang))
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
            guard rim(fAng) > 0.12, place(fAng) > 0.30 else { continue }
            let freq = 1.0 + 3.2 * NebulaConfig.hash(fid, 91)
            let tw = pow(0.5 + 0.5 * sin(t * freq + NebulaConfig.hash(fid, 92) * 6.283), 4.0)
            let fa = 0.55 * tw * (0.10 + 0.90 * rim(fAng)) * place(fAng) * fade
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
        let rise = imp.filamentRise * L.scale

        for k in 0..<imp.filaments {
            let fid = index * 7 + k
            let cycle = NebulaConfig.lerp(NebulaConfig.filamentCycle, NebulaConfig.hash(fid, 200))
            let u = ((t + NebulaConfig.hash(fid, 201) * cycle) / cycle)
                .truncatingRemainder(dividingBy: 1)
            // Elle se dissout puis se reforme : jamais présente en permanence.
            let alive = sin(.pi * min(1, u * 1.18))
            guard alive > 0.03 else { continue }

            // Le pied : derrière/au-dessus de la tête, jamais deux au même
            // endroit. L'écart reste sous ±0,55 rad : au-delà, la mèche naît sur
            // le FLANC et se lit comme un grand arc qui balaie de côté au lieu
            // d'une brume qui monte du crâne.
            let spread = (NebulaConfig.hash(fid, 202) - 0.5) * 1.1
            let footAng = -.pi / 2 + spread
            let foot = CGPoint(x: anchorC.x + CGFloat(cos(footAng)) * headR * 0.94,
                               y: anchorC.y + CGFloat(sin(footAng)) * headR * 0.94)
            let h = rise * NebulaConfig.lerp(NebulaConfig.filamentRiseSwing,
                                             NebulaConfig.hash(fid, 203))
            let bend = CGFloat(NebulaConfig.hash(fid, 204) - 0.5) * h * 0.50
            let wob = CGFloat(sin(t * (0.30 + 0.34 * NebulaConfig.hash(fid, 205))
                                  + Double(fid) * 1.9)) * h * 0.16

            let p0 = foot
            let p1 = CGPoint(x: foot.x + bend * 0.45 + wob, y: foot.y - h * 0.42)
            let p2 = CGPoint(x: foot.x + bend * 1.05 - wob * 0.7, y: foot.y - h * 0.78)
            let p3 = CGPoint(x: foot.x + bend * 0.72 + wob * 0.4, y: foot.y - h)

            // Quatre tronçons de Bézier, chacun rempli UNE fois, tous dans le
            // MÊME calque flouté : la mèche s'affine et s'éteint vers le bout
            // sans qu'aucun bout arrondi ne se recouvre en plusLighter — donc
            // aucun chapelet, et un seul offscreen par mèche au lieu de seize.
            let vigor = NebulaConfig.filamentAlpha * alive
                * (0.62 + 0.38 * NebulaConfig.hash(fid, 206)) * fade
            guard vigor > 0.012 else { continue }
            g.drawLayer { layer in
                layer.addFilter(.blur(radius: NebulaConfig.filamentBlur))
                layer.blendMode = .normal
                let chunks = 4, per = 5
                for c in 0..<chunks {
                    let v0 = CGFloat(c) / CGFloat(chunks)
                    let v1 = CGFloat(c + 1) / CGFloat(chunks)
                    let mid = Double((v0 + v1) / 2)
                    let taper = pow(1 - mid, 1.25)
                    let a = vigor * taper
                    guard a > 0.010 else { continue }
                    var seg = Path()
                    for s in 0...per {
                        let v = v0 + (v1 - v0) * CGFloat(s) / CGFloat(per)
                        let pt = bezier(p0, p1, p2, p3, v)
                        if s == 0 { seg.move(to: pt) } else { seg.addLine(to: pt) }
                    }
                    let w = NebulaConfig.lerp(NebulaConfig.filamentWidth, (1 - mid) * 0.92)
                    layer.stroke(seg, with: .color(.white.opacity(min(1, a))),
                                 style: StrokeStyle(lineWidth: w, lineCap: .round,
                                                    lineJoin: .round))
                }
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
        for m in 0..<NebulaConfig.smokePlumes {
            let id = index * 5 + m
            let cycle = NebulaConfig.lerp(NebulaConfig.smokeCycle, NebulaConfig.hash(id, 60))
            let u = ((t + NebulaConfig.hash(id, 61) * cycle) / cycle)
                .truncatingRemainder(dividingBy: 1)
            // Elle naît épaisse au ras de l'épaule, s'étire en montant, se
            // dissipe en haut : présente, jamais un nuage franc.
            let growth = sin(.pi * pow(u, 0.75))
            let alpha = NebulaConfig.smokeAlpha * growth * fade
            guard alpha > 0.015 else { continue }
            // Deux volutes aux épaules, une qui monte derrière la tête.
            let s: CGFloat = m == 0 ? -1 : (m == 1 ? 1 : 0.25)
            let sway = CGFloat(sin(t * 0.11 + Double(index) * 1.7 + Double(m) * 2.4))
                * r * 0.34
            let rise = r * NebulaConfig.smokeRise * CGFloat(u)
            // Elle part de l'épaule et S'ÉCARTE du corps en montant : c'est en
            // quittant le noir de la sphère qu'elle se met à manger des étoiles.
            let mc = CGPoint(x: c.x + s * r * (0.90 + NebulaConfig.smokeSpread * CGFloat(u))
                                + sway * CGFloat(u + 0.3),
                             y: c.y + r * 0.72 - rise)
            let mr = r * (0.26 + 0.34 * CGFloat(u))
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: mr * 0.62))
                // Une volute effilée, penchée : jamais un rond.
                layer.translateBy(x: mc.x, y: mc.y)
                layer.rotate(by: .radians(Double(sway / max(r, 1)) * 0.6))
                layer.fill(Path(ellipseIn: CGRect(x: -mr * 0.78, y: -mr * 1.25,
                                                  width: mr * 1.56, height: mr * 2.5)),
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
