import SwiftUI

// MARK: - Banc de la page de succès (`-successLab`) — LE BARILLET
//
// La page de succès n'est pas une page : c'est LE CADRAN QUI SE RETOURNE.
// Le flow de la lentille s'arrête sur une pastille de verre noir posée dans
// son lit de feu ; la série finie, la caméra ne coupe pas — elle RASE ce lit
// et, quand elle ressort, il y a trois pastilles au lieu d'une.
//
//   T1. LE TRAVELLING RASANT (0 → 1,70). Le frontal est déjà pris (le dive
//       du sommet) : celui-ci est LATÉRAL, et c'est la même loi — 8^(u^2,05)
//       — mais le zoom vit DANS le shader (`successGlow`, caméra camZ/camO) :
//       le lit est recalculé à pleine résolution à tout grossissement, jamais
//       une image agrandie. On voit la matière : langues advectées, pointes
//       blanches, grain. LA COUPE se cache à 1,70 dans un pic de pointes
//       blanches — la matière la plus dense est le seul témoin de continuité.
//   T2. LA POSE (1,70 → 4,22). La pastille renaît PETITE par le bord haut,
//       redescend seule, se pose en goutte. Au contact, le lit ENCAISSE :
//       la brame accélère (Tf 2,6 → 0,7 s) et se détend — la poussière ne
//       naît pas, elle vient de la chute. Titre et sous-titre AFFLEURENT du
//       condensat, sur la courbe des chiffres du cadran.
//   T3. LE BARILLET (+2,20 → +3,45 après la pose). Les deux pastilles noires
//       sont LA MÊME pastille avec `ig = 0` : sur la nuit, une pastille sans
//       feu est invisible — on la devine à son seul dôme. Les faire vivre,
//       c'est MONTER `ig`, la rampe même qui a fait naître celle du centre :
//       aucune couche ne s'allume. Et le feu se TRANSMET — une langue de la
//       centrale part vers celle qui va prendre (la rafale du tap, réutilisée
//       telle quelle) avant que le cran ne tombe. Cran par cran, jamais
//       ensemble : un barillet ne tombe pas d'un bloc.
//   T4. LA MOLETTE (+3,75). Deux nombres, dans la clé du chrono. On les règle
//       en GLISSANT dessus — le même cran que le barillet, le même tic : le
//       coffre et la molette sont le même mécanisme.
//
// `-successAuto` rejoue le cycle en boucle de 11 s (films, simulateur).
// `-successFreeze <t>` fige la partition à t secondes (captures).
// `-successFPS` loggue la cadence réelle toutes les deux secondes.
//
// Toute la chorégraphie est FONCTION PURE du temps — aucune animation
// SwiftUI sur les uniforms (l'école ConnexionCine / SummitCine).
enum SuccessCine {
    // ---- T1 : le travelling rasant
    /// La poussée latérale, et LA COUPE au bout.
    static let push: Double = 1.70
    static var cutAt: Double { push }
    /// Le grossissement de départ et d'arrivée de la caméra du lit.
    static let camFrom: Double = 4.6
    static let camTo: Double = 24.0

    // ---- T2 : la renaissance et la pose
    static let enter: Double = 0.22
    static let descend: Double = 2.30
    static var landAt: Double { cutAt + enter + descend }

    // ---- Après la pose (horloge `landed`)
    /// L'encre est bue par la pastille : la laque monte, les voix naissent.
    static let dryA: Double = 0.50, dryB: Double = 2.20
    /// Titre et sous-titre affleurent du condensat.
    static let titleA: Double = 1.50, titleB: Double = 2.60
    /// LE BARILLET — la langue se penche, puis les crans tombent.
    static let leanL: Double = 2.20
    static let crankL: Double = 2.55
    static let leanR: Double = 2.62
    static let crankR: Double = 2.97
    /// Le coffre s'ouvre : les trois battent à l'unisson, une fois.
    static let vault: Double = 3.45
    /// La molette affleure à son tour.
    static let dialA: Double = 3.75, dialB: Double = 4.35
    /// Le silence de l'arrivée, puis la boucle du banc.
    static let cycle: Double = 11.0

    // ---- Les courbes

    static func sstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let u = min(max((x - a) / (b - a), 0), 1)
        return u * u * (3 - 2 * u)
    }

    /// La poussée : retenue au départ, violente à la fin — la loi du dive.
    static func pushU(_ e: Double) -> Double {
        min(max(e / push, 0), 1)
    }

    static func camZoom(_ e: Double) -> Double {
        camFrom * pow(camTo / camFrom, pow(pushU(e), 2.05))
    }

    /// Le flou qui couvre la coupe — il n'arrive qu'à la toute fin.
    static func camBlur(_ e: Double) -> Double {
        14 * sstep(0.55, 1.0, pushU(e))
    }

    /// L'inclinaison tenue : l'horizon n'est pas d'aplomb, on regarde
    /// DE CÔTÉ. Elle dérive à peine — jamais un mouvement qu'on lit.
    static func camTilt(_ e: Double) -> Double {
        -1.8 - 0.8 * pushU(e)
    }

    /// L'enveloppe d'un cran : attaque 0,10 s (6 frames à 60 Hz — plus
    /// jamais un scale qui claque), retombée douce.
    static func beat(_ x: Double) -> Double {
        guard x > 0 else { return 0 }
        return sstep(0, 0.10, x) * exp(-max(x - 0.10, 0) / 0.30)
    }

    /// La rampe d'allumage d'une pastille : front rapide, assise lente —
    /// la même matière qui prend, jamais un interrupteur.
    static func ignition(_ x: Double) -> Double {
        let u = min(max(x / 0.42, 0), 1)
        return pow(u, 0.42)
    }

    /// Le dépassement de l'éclosion (easeOutBack c1 = 0,8), ramené à
    /// ±1,2 % de rayon : le cran se SENT sans que la forme claque.
    static func backR(_ x: Double) -> Double {
        let u = min(max(x / 0.55, 0), 1)
        guard u < 1 else { return 1 }
        let c1 = 0.8
        let s = 1 + (c1 + 1) * pow(u - 1, 3) + c1 * pow(u - 1, 2)
        return 0.988 + 0.012 * s
    }
}

// MARK: - Le banc

struct SuccessLab: View {
    private static let frozen: Double? = {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "-successFreeze"), i + 1 < args.count,
              let v = Double(args[i + 1]) else { return nil }
        return max(v, 0)
    }()
    private static let cycling = CommandLine.arguments.contains("-successAuto")
    private static let showFPS = CommandLine.arguments.contains("-successFPS")

    /// L'horloge de la partition : posée à l'apparition, rejouable.
    @State private var startedAt = Date()
    /// Le cran entendu — le tic ne sonne qu'au basculement.
    @State private var heardCrank = 0
    @State private var probe = FPSProbe()

    /// Les deux nombres de la molette.
    @State private var kilos = 20
    @State private var reps = 12

    var body: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
                let now = tl.date
                let t = now.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 900)
                let e = elapsed(now: now, t: t)
                ZStack {
                    if e < SuccessCine.cutAt {
                        travelling(w: w, h: h, t: t, e: e)
                    } else {
                        trio(w: w, h: h, t: t, ne: e - SuccessCine.cutAt)
                    }
                }
                .onChange(of: crank(at: e)) { _, k in ring(k) }
                .onChange(of: tl.date) { _, d in
                    if Self.showFPS { probe.tick(d) }
                }
            }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)
        .onAppear {
            RocketHaptics.shared.prepare()
            LensChime.shared.prepare()
            LensTheme.shared.prepare()
            fire()
        }
    }

    // MARK: L'horloge

    private func elapsed(now: Date, t: Double) -> Double {
        if let f = Self.frozen { return f }
        if Self.cycling {
            return t.truncatingRemainder(dividingBy: SuccessCine.cycle)
        }
        return now.timeIntervalSince(startedAt)
    }

    /// Le numéro du cran atteint — 0 avant le premier, 3 quand le coffre
    /// est ouvert. C'est LUI qui déclenche le son et la vibration.
    private func crank(at e: Double) -> Int {
        let landed = e - SuccessCine.landAt
        if landed >= SuccessCine.vault { return 3 }
        if landed >= SuccessCine.crankR { return 2 }
        if landed >= SuccessCine.crankL { return 1 }
        return 0
    }

    private func ring(_ k: Int) {
        guard k != heardCrank else { return }
        // Un cycle qui reboucle repasse par 0 : pas de tic à la remise.
        defer { heardCrank = k }
        guard k > heardCrank else { return }
        if k == 3 { DialChime.shared.minute() } else { DialChime.shared.second() }
    }

    private func fire() {
        guard Self.frozen == nil, !Self.cycling else { return }
        startedAt = .now
        heardCrank = 0
        LensTheme.shared.play()
        let land = SuccessCine.landAt
        RocketHaptics.shared.surge(
            rise: SuccessCine.cutAt - 0.05,
            contact: land,
            beat: land + SuccessCine.vault,
            ticks: [land + SuccessCine.crankL, land + SuccessCine.crankR])
    }

    // MARK: T1 — le travelling rasant

    /// La caméra rase le lit de feu du cadran qui vient de s'arrêter. Le
    /// zoom est DANS le shader : `camZ` grossit, `camO` fait glisser le
    /// monde de côté. Le point du MONDE tenu au centre de l'écran dérive
    /// vers le large et vers le haut — le mouvement est oblique, jamais
    /// un travelling de rail.
    private func travelling(w: CGFloat, h: CGFloat,
                            t: Double, e: Double) -> some View {
        let g = SuccessGeometry(w: w, h: h)
        let u = SuccessCine.pushU(e)
        let z = SuccessCine.camZoom(e)
        // Le point du monde tenu au centre de l'écran.
        let held = CGPoint(x: g.mid.x + g.rBig * (0.70 + 0.85 * u),
                           y: g.mid.y - g.rBig * (0.05 + 0.40 * u))
        let oX = w * 0.5 - z * held.x
        let oY = h * 0.5 - z * held.y
        let shader = ShaderLibrary.successGlow(
            .float2(Float(w), Float(h)),
            .float2(Float(g.mid.x), Float(g.mid.y)),
            .float(Float(g.rBig)), .float(Float(t)),
            .float(1.0), .float(0.0), .float(0.0), .float(0.0),
            .float(Float(z)), .float2(Float(oX), Float(oY)))
        return ZStack {
            Color.black
            NightSpotlight().allowsHitTesting(false)
            Rectangle().fill(.white).colorEffect(shader)
                .allowsHitTesting(false)
            WoopGrain(density: 0.028, lightAlpha: 0.022, darkAlpha: 0.028)
                .allowsHitTesting(false)
        }
        .frame(width: w, height: h)
        .rotationEffect(.degrees(SuccessCine.camTilt(e)))
        .blur(radius: SuccessCine.camBlur(e))
        .clipped()
    }

    // MARK: T2/T3/T4 — le trio

    private func trio(w: CGFloat, h: CGFloat,
                      t: Double, ne: Double) -> some View {
        let g = SuccessGeometry(w: w, h: h)
        let landed = ne - (SuccessCine.enter + SuccessCine.descend)
        let dry = SuccessCine.sstep(SuccessCine.dryA, SuccessCine.dryB,
                                    max(landed, 0))
        let mid = midPastille(g: g, t: t, ne: ne, landed: landed, dry: dry)
        let left = sidePastille(g: g, t: t, landed: landed,
                                index: 0, crank: SuccessCine.crankL)
        let right = sidePastille(g: g, t: t, landed: landed,
                                 index: 1, crank: SuccessCine.crankR)
        let ink = inkDrive(g: g, ne: ne, landed: landed)
        let titleIn = SuccessCine.sstep(SuccessCine.titleA,
                                        SuccessCine.titleB, max(landed, 0))
        let dialIn = SuccessCine.sstep(SuccessCine.dialA,
                                       SuccessCine.dialB, max(landed, 0))
        return ZStack {
            world(w: w, h: h, t: t, mid: mid, left: left, right: right,
                  ink: ink)
            titles(g: g, opacity: titleIn)
            molette(g: g, opacity: dialIn)
        }
        .frame(width: w, height: h)
        .clipped()
    }

    /// Le monde sous le verre, puis LES TROIS LENTILLES enchaînées : chacune
    /// réfracte ce que la précédente a rendu. Elles ne se recouvrent pas —
    /// l'ordre est sans conséquence, et hors de son disque une lentille ne
    /// coûte qu'un échantillon.
    private func world(w: CGFloat, h: CGFloat, t: Double,
                       mid: Pastille, left: Pastille, right: Pastille,
                       ink: InkDrive) -> some View {
        ZStack {
            Color.black
            NightSpotlight().allowsHitTesting(false)
            SuccessStars(t: t).allowsHitTesting(false)
            // L'énergie de l'encre devenue lit de feu — DERRIÈRE les objets,
            // réfractée par leur verre. Les noires n'en ont pas : `ig = 0`
            // sort du shader à la première ligne, elles ne coûtent rien.
            glow(w: w, h: h, t: t, p: left)
            glow(w: w, h: h, t: t, p: right)
            glow(w: w, h: h, t: t, p: mid)
            if ink.stations.count >= 8 {
                Rectangle().fill(.white)
                    .colorEffect(inkShader(w: w, h: h, t: t, ink: ink,
                                           center: mid.center))
                    .allowsHitTesting(false)
            }
            WoopGrain(density: 0.028, lightAlpha: 0.022, darkAlpha: 0.028)
                .allowsHitTesting(false)
        }
        .frame(width: w, height: h)
        .compositingGroup()
        .layerEffect(lensShader(w: w, h: h, t: t, p: left),
                     maxSampleOffset: CGSize(width: 110, height: 110))
        .layerEffect(lensShader(w: w, h: h, t: t, p: right),
                     maxSampleOffset: CGSize(width: 110, height: 110))
        .layerEffect(lensShader(w: w, h: h, t: t, p: mid),
                     maxSampleOffset: CGSize(width: 110, height: 110))
    }

    // MARK: Les trois pastilles

    /// L'état d'une pastille — la MÊME matière pour les trois : seule
    /// `ig` (l'allumage du lit et des voix) les distingue.
    private struct Pastille {
        var center: CGPoint
        var radius: CGFloat
        var ig: Double = 0
        var ember: Double = 0.03
        var lacquer: Double = 0.66
        var pulse: Double = 0
        var flare: Double = 0
        var flareAng: Double = 0
        var squash: Double = 1
        var ripple: Double = 0
        var ripplePhase: Double = 0
    }

    /// La centrale : elle renaît par le bord haut, redescend seule, se pose
    /// en goutte — la géométrie du flow, à l'identique. Puis elle condense,
    /// s'allume, penche sa flamme vers ses voisines, et bat au coffre.
    private func midPastille(g: SuccessGeometry, t: Double,
                             ne: Double, landed: Double,
                             dry: Double) -> Pastille {
        let u = min(max((ne - SuccessCine.enter) / SuccessCine.descend, 0), 1)
        let e2 = u * u * (3 - 2 * u)
        // PETITE à la renaissance — elle prend sa taille en arrivant.
        let rEnd = g.rBig
        let radius = rEnd * (0.38 + 0.62 * SuccessCine.sstep(0.35, 1.0, u))
        let cyStart = -radius - 60
        var cy = cyStart + (g.mid.y - cyStart) * CGFloat(e2)
        let cx = g.mid.x
        // L'étirement suit la vitesse, et meurt à l'approche de la pose.
        let vel = 6 * u * (1 - u)
        var squash = 1 - 0.10 * min(vel / 1.5, 1)
            * (1 - SuccessCine.sstep(0.85, 1.0, u))
        var radiusV = radius
        var ripple = 0.0
        var pulse = 0.0
        var flare = 0.0
        var ang = 0.0
        if landed > 0 {
            // L'ATTERRISSAGE EN GOUTTE — écrasement, rebond, retombée.
            squash *= 1 + 0.11 * sin(landed * 14.5) * exp(-landed * 3.2)
            cy += CGFloat(2.6 * sin(landed * 2.1) * exp(-landed * 1.1))
            ripple = exp(-landed * 2.8)
            // LA LANGUE QUI SE PENCHE : avant chaque cran, la centrale
            // souffle DU CÔTÉ de celle qui va prendre. C'est la rafale du
            // tap, réutilisée telle quelle — la MÊME brame, amplifiée,
            // jamais une couche neuve. Le feu se transmet.
            let fl = SuccessCine.beat(landed - SuccessCine.leanL)
            let fr = SuccessCine.beat(landed - SuccessCine.leanR)
            flare = max(fl, fr)
            ang = fl >= fr ? .pi : 0
            // LE COFFRE S'OUVRE : un seul battement, à l'unisson.
            pulse = SuccessCine.beat(landed - SuccessCine.vault)
            radiusV *= 1 + CGFloat(0.010 * pulse)
        }
        var p = Pastille(center: CGPoint(x: cx, y: cy), radius: radiusV)
        // La braise vit pendant la chute, s'apaise en braise de VEILLE une
        // fois posée : sur la nuit, une pastille sans braise est invisible.
        let fall = 0.24 * (1 - SuccessCine.sstep(0, 1.2, max(landed, 0)))
        let veille = (0.11 + 0.05 * sin(t * 0.9))
            * SuccessCine.sstep(0.6, 1.6, max(landed, 0))
        p.ember = min(max(fall, veille) + 0.20 * flare, 1.0)
        p.lacquer = 0.66 * SuccessCine.sstep(0.55, 1.0, dry)
        p.ig = SuccessCine.sstep(0.08, 0.85, dry)
        p.pulse = pulse
        p.flare = flare
        p.flareAng = ang
        p.squash = squash
        p.ripple = ripple
        p.ripplePhase = max(landed, 0) * 30
        return p
    }

    /// Une latérale : la MÊME pastille, `ig = 0` — sur la nuit, sans feu,
    /// on ne la devine qu'à son dôme qui accroche le pinceau de lumière.
    /// Le cran la fait vivre en MONTANT `ig` : rien ne s'allume par-dessus.
    private func sidePastille(g: SuccessGeometry, t: Double, landed: Double,
                              index: Int, crank: Double) -> Pastille {
        let x = index == 0 ? g.mid.x - g.gap : g.mid.x + g.gap
        let age = max(landed, 0) - crank
        let ig = SuccessCine.ignition(age)
        var p = Pastille(center: CGPoint(x: x, y: g.mid.y),
                         radius: g.rSmall * SuccessCine.backR(age))
        p.ig = ig
        p.lacquer = 0.66
        // Éteinte : une braise de VEILLE minuscule — juste de quoi la
        // deviner. Allumée : la même veille que la centrale.
        p.ember = 0.028 + (0.09 + 0.04 * sin(t * 0.9 + Double(index) * 2.1)) * ig
        p.pulse = SuccessCine.beat(max(landed, 0) - SuccessCine.vault) * ig
        p.radius *= 1 + CGFloat(0.010 * p.pulse)
        return p
    }

    // MARK: Les shaders

    private func glow(w: CGFloat, h: CGFloat, t: Double,
                      p: Pastille) -> some View {
        let shader = ShaderLibrary.eclipseGlow(
            .float2(Float(w), Float(h)),
            .float2(Float(p.center.x), Float(p.center.y)),
            .float(Float(p.radius)), .float(Float(t)),
            .float(Float(p.ig)), .float(Float(p.pulse)),
            .float(Float(p.flare)), .float(Float(p.flareAng)))
        return Rectangle().fill(.white).colorEffect(shader)
            .allowsHitTesting(false)
    }

    /// Les uniforms sortis un à un : au-delà d'une poignée d'expressions
    /// dans l'appel, le type-checker abandonne (la leçon des 36 arguments).
    private func lensShader(w: CGFloat, h: CGFloat, t: Double,
                            p: Pastille) -> Shader {
        let sw = Float(w), sh = Float(h)
        let cx = Float(p.center.x), cy = Float(p.center.y)
        let rad = Float(p.radius)
        let emb = Float(p.ember), sq = Float(p.squash)
        let lac = Float(p.lacquer), ig = Float(p.ig)
        let rip = Float(p.ripple), rph = Float(p.ripplePhase)
        let pul = Float(p.pulse), ts = Float(t)
        return ShaderLibrary.liquidLens(
            .float2(sw, sh), .float2(cx, cy), .float(rad),
            .float(0.72), .float(0.12), .float(emb),
            .float(sq), .float(1.0), .float(ts),
            .float(0.0), .float(0.0), .float(0.0), .float(lac),
            .float(rip), .float(rph), .float(pul), .float(ig))
    }

    private func inkShader(w: CGFloat, h: CGFloat, t: Double,
                           ink: InkDrive, center: CGPoint) -> Shader {
        let birth = Float(SuccessCine.sstep(24, 170, Double(ink.length)))
        return ShaderLibrary.inkTrail(
            .float2(Float(w), Float(h)), .floatArray(ink.stations),
            .float2(Float(ink.boundsMin.x), Float(ink.boundsMin.y)),
            .float2(Float(ink.boundsMax.x), Float(ink.boundsMax.y)),
            .float(Float(t)), .float(Float(ink.dry)), .float(birth),
            .float(1.0), .float(1.0),
            .float2(Float(center.x), Float(center.y)))
    }

    // MARK: L'encre de la descente

    private struct InkDrive {
        var stations: [Float] = []
        var boundsMin: CGPoint = .zero
        var boundsMax: CGPoint = .zero
        var length: CGFloat = 0
        var dry: Double = 1
    }

    /// Le chemin RÉEL de la pastille, rééchantillonné comme un drag — et
    /// FIGÉ À LA POSE : une fenêtre glissante se vide d'un coup quand
    /// l'objet s'immobilise (le « battement noir » du flow, rejeté deux
    /// fois). Figé, le chemin demeure et ses âges courent.
    ///
    /// L'ACCÉLÉRATION DE POUSSIÈRE : au contact, `dry` court trois fois
    /// plus vite pendant un souffle — le lit encaisse la chute. La
    /// poussière ne naît pas, elle vient de quelque part.
    private func inkDrive(g: SuccessGeometry, ne: Double,
                          landed: Double) -> InkDrive {
        var d = InkDrive()
        guard ne > SuccessCine.enter + 0.10 else { return d }
        let land = SuccessCine.enter + SuccessCine.descend
        let neP = min(ne, land)
        let t0 = max(SuccessCine.enter, neP - 1.9)
        var pts: [(pos: CGPoint, age: Double)] = []
        let n = 30
        for i in 0...n {
            let tp = t0 + (neP - t0) * Double(i) / Double(n)
            let u = min(max((tp - SuccessCine.enter) / SuccessCine.descend,
                            0), 1)
            let e2 = u * u * (3 - 2 * u)
            let radius = g.rBig * (0.38 + 0.62 * SuccessCine.sstep(0.35, 1.0, u))
            let cyStart = -radius - 60
            let cy = cyStart + (g.mid.y - cyStart) * CGFloat(e2)
            pts.append((CGPoint(x: g.mid.x, y: cy), min(ne - tp, 2.6)))
        }
        guard let tr = successStations(from: pts) else { return d }
        d.stations = tr.sta
        d.boundsMin = tr.bMin
        d.boundsMax = tr.bMax
        d.length = tr.len
        // Le repli : l'encre est bue par la pastille. Le premier souffle
        // après le contact est TROIS FOIS plus rapide.
        let l = max(landed, 0)
        let shock = 0.40 * SuccessCine.sstep(0, 0.34, l)
        d.dry = min(SuccessCine.sstep(1.0, 3.8, l) + shock, 1)
        return d
    }

    // MARK: Les textes

    /// Ils n'entrent pas en fondu : ils AFFLEURENT du condensat, sur la
    /// courbe même des chiffres du cadran (flou qui se résorbe, échelle
    /// qui se pose) — la matière remonte, elle ne s'allume pas.
    private func titles(g: SuccessGeometry, opacity: Double) -> some View {
        VStack(spacing: 9) {
            Text("Série 1 terminée")
                .font(.inter(27, .medium))
                .foregroundStyle(Color.white.opacity(0.92))
            Text("1:12 · il en reste 3")
                .font(.inter(13, .medium))
                .foregroundStyle(Color.white.opacity(0.42))
        }
        .multilineTextAlignment(.center)
        .opacity(opacity)
        .blur(radius: (1 - opacity) * 7)
        .scaleEffect(0.95 + 0.05 * opacity)
        .position(x: g.mid.x, y: g.titleY)
        .allowsHitTesting(false)
    }

    /// LA MOLETTE — deux nombres, pas un formulaire. Ni carte, ni puits,
    /// ni −/+ : le fil de métal blanc du chrono, et le doigt qui glisse.
    private func molette(g: SuccessGeometry, opacity: Double) -> some View {
        HStack(spacing: 54) {
            SuccessDialNumber(value: $kilos, unit: "KG",
                              range: 0...300, perPoint: 1.0 / 9.0)
            SuccessDialNumber(value: $reps, unit: "REPS",
                              range: 1...60, perPoint: 1.0 / 13.0)
        }
        .opacity(opacity)
        .blur(radius: (1 - opacity) * 7)
        .scaleEffect(0.95 + 0.05 * opacity)
        .position(x: g.mid.x, y: g.dialY)
        .allowsHitTesting(opacity > 0.9)
    }
}

// MARK: - La géométrie du trio

/// Toute la géométrie en un seul endroit — le trio, les textes, la molette.
/// Les latérales sont posées de sorte que leurs lits de feu se TOUCHENT :
/// c'est par là que la flamme passera d'une pastille à l'autre.
private struct SuccessGeometry {
    let w: CGFloat, h: CGFloat

    var mid: CGPoint { CGPoint(x: w * 0.5, y: h * 0.34) }
    var rBig: CGFloat { w * 0.175 }
    var rSmall: CGFloat { w * 0.105 }
    var gap: CGFloat { rBig + rSmall + 26 }
    var titleY: CGFloat { h * 0.34 + rBig + 62 }
    var dialY: CGFloat { h * 0.70 }
}

// MARK: - Un nombre de la molette

/// Le fil de métal blanc du chrono — Inter Light, dégradé qui s'éteint vers
/// le bas —, et sous lui l'unité en petites capitales espacées : la clé de
/// la caption du cadran, à l'identique.
///
/// On le règle EN GLISSANT DESSUS. Pas un bouton : c'est la grammaire de
/// tout le flow — le doigt porte la matière. Chaque unité franchie est le
/// MÊME cran que le barillet, le même tic, la même vibration souple : le
/// coffre et la molette sont un seul mécanisme.
struct SuccessDialNumber: View {
    @Binding var value: Int
    let unit: String
    let range: ClosedRange<Int>
    /// Unités par point de glissement — la résistance du cran.
    let perPoint: Double

    @State private var valueAtGrab: Int?
    @State private var ticks = 0
    @State private var held = false

    var body: some View {
        VStack(spacing: 7) {
            Text("\(value)")
                .font(Font.custom("Inter-Light", size: 46).monospacedDigit())
                .tracking(0.5)
                .foregroundStyle(LinearGradient(stops: [
                    .init(color: .white, location: 0.0),
                    .init(color: .white.opacity(0.80), location: 0.55),
                    .init(color: .white.opacity(0.46), location: 1.0)
                ], startPoint: .top, endPoint: .bottom))
                .contentTransition(.numericText())
            Text(unit)
                .font(.inter(10.5, .semibold))
                .tracking(3.8)
                .foregroundStyle(Color.white.opacity(held ? 0.52 : 0.30))
        }
        // La zone tactile déborde largement du chiffre : on attrape un
        // nombre au pouce, pas au pixel.
        .frame(minWidth: 104, minHeight: 96)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { v in
                    if valueAtGrab == nil {
                        valueAtGrab = value
                        held = true
                    }
                    guard let base = valueAtGrab else { return }
                    // Vers le HAUT, la valeur monte : le geste de tout le
                    // flow — le doigt tire la matière vers le haut.
                    let delta = Int((-v.translation.height * perPoint)
                        .rounded())
                    let next = min(max(base + delta, range.lowerBound),
                                   range.upperBound)
                    guard next != value else { return }
                    value = next
                    ticks += 1
                    DialChime.shared.second()
                }
                .onEnded { _ in
                    valueAtGrab = nil
                    held = false
                }
        )
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.65),
                         trigger: ticks)
        .accessibilityElement()
        .accessibilityLabel(unit == "KG" ? "Poids" : "Répétitions")
        .accessibilityValue("\(value)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(value + 1, range.upperBound)
            case .decrement: value = max(value - 1, range.lowerBound)
            default: break
            }
        }
    }
}

// MARK: - Les étoiles rares

/// La nuit n'est pas un noir plat : quatorze étoiles posées une fois (hash
/// pur), qui respirent à peine — des billes douces, jamais des points durs.
private struct SuccessStars: View {
    let t: Double
    var body: some View {
        Canvas { ctx, sz in
            for i in 0..<14 {
                let s = Double(i) * 39.7 + 11.3
                let hx = abs((sin(s * 12.9898) * 43758.5453)
                    .truncatingRemainder(dividingBy: 1))
                let hy = abs((sin(s * 78.233) * 24634.6345)
                    .truncatingRemainder(dividingBy: 1))
                let x = sz.width * (0.06 + 0.88 * hx)
                let y = sz.height * (0.05 + 0.80 * hy)
                let breath = 0.5 + 0.5 * sin(t * (0.35 + 0.22 * hx) + s)
                let a = 0.05 + 0.13 * breath * breath
                let r: Double = hx > 0.72 ? 1.6 : 1.1
                ctx.fill(Path(ellipseIn:
                    CGRect(x: x - r * 2.2, y: y - r * 2.2,
                           width: r * 4.4, height: r * 4.4)),
                         with: .color(.white.opacity(a * 0.25)))
                ctx.fill(Path(ellipseIn:
                    CGRect(x: x - r / 2, y: y - r / 2,
                           width: r, height: r)),
                         with: .color(.white.opacity(a)))
            }
        }
    }
}

// MARK: - Le rééchantillonnage du chemin

/// 24 stations uniformes en ABSCISSE CURVILIGNE (x, y, âge, flânerie) —
/// le même calcul que la lentille : paramétrer par la hauteur seule tirait
/// des traits droits dès que le chemin se repliait.
private func successStations(from pts: [(pos: CGPoint, age: Double)])
    -> (sta: [Float], bMin: CGPoint, bMax: CGPoint, len: CGFloat)? {
    guard pts.count >= 2 else { return nil }
    var cum = [CGFloat](repeating: 0, count: pts.count)
    for i in 1..<pts.count {
        cum[i] = cum[i - 1] + hypot(pts[i].pos.x - pts[i - 1].pos.x,
                                    pts[i].pos.y - pts[i - 1].pos.y)
    }
    let S = cum[pts.count - 1]
    guard S > 14 else { return nil }
    let K = 24
    var xs = [Double](repeating: 0, count: K)
    var ys = [Double](repeating: 0, count: K)
    var ages = [Double](repeating: 0, count: K)
    var i = pts.count - 2
    var bMin = CGPoint(x: CGFloat.greatestFiniteMagnitude,
                       y: CGFloat.greatestFiniteMagnitude)
    var bMax = CGPoint(x: -CGFloat.greatestFiniteMagnitude,
                       y: -CGFloat.greatestFiniteMagnitude)
    for k in 0..<K {
        let s = S * (1 - CGFloat(k) / CGFloat(K - 1))
        while i > 0 && cum[i] > s { i -= 1 }
        let a = pts[i], b = pts[i + 1]
        let seg = cum[i + 1] - cum[i]
        let u = seg > 0.001 ? Double((s - cum[i]) / seg) : 0
        xs[k] = Double(a.pos.x) + Double(b.pos.x - a.pos.x) * u
        ys[k] = Double(a.pos.y) + Double(b.pos.y - a.pos.y) * u
        ages[k] = a.age + (b.age - a.age) * u
        bMin.x = min(bMin.x, CGFloat(xs[k]))
        bMin.y = min(bMin.y, CGFloat(ys[k]))
        bMax.x = max(bMax.x, CGFloat(xs[k]))
        bMax.y = max(bMax.y, CGFloat(ys[k]))
    }
    let dsStep = Double(S) / Double(K - 1)
    var raw = [Double](repeating: 0, count: K)
    for k in 0..<K {
        let a0 = ages[max(k - 1, 0)]
        let a1 = ages[min(k + 1, K - 1)]
        let span = Double(min(k + 1, K - 1) - max(k - 1, 0))
        let dAge = abs(a1 - a0) / max(span, 1)
        let vel = dsStep / max(dAge, 1e-4)
        let u = min(max((vel - 250) / (1400 - 250), 0), 1)
        raw[k] = 1 - u * u * (3 - 2 * u)
    }
    var sta: [Float] = []
    sta.reserveCapacity(4 * K)
    for k in 0..<K {
        let l = (raw[max(k - 1, 0)] + 2 * raw[k]
                 + raw[min(k + 1, K - 1)]) / 4
        sta.append(Float(xs[k]))
        sta.append(Float(ys[k]))
        sta.append(Float(ages[k]))
        sta.append(Float(l))
    }
    return (sta, bMin, bMax, S)
}

#Preview { SuccessLab() }
