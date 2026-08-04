import SwiftUI

// MARK: - Banc de la lentille liquide (`-lensLab`) — BANC A : LA MONTÉE
//
// Une page de papier, une bulle de verre qui affleure au bord bas. Le doigt
// la cueille et la PORTE : la pill suit le doigt, grossit en montant, le
// verre s'étire avec la vitesse — du liquide, pas un widget. Derrière elle,
// une traînée d'encre FINE s'écrit sur le papier là où le doigt est passé —
// charbon noir, braise orange, pointes jaunes : les couleurs des halos.
// Elle vit un instant, boit le papier, sèche. Relâcher : le liquide retombe
// en ressort et repasse sur sa propre encre pendant qu'elle s'efface.
//
// RIEN D'AUTRE : pas de relais du haut, pas de transformation, pas de nuit
// — c'est le banc de LA MONTÉE seule. Verdict de Kathryn avant tout geste
// suivant (bancs B, C, D).
//
// `-lensFreeze <p>` fige la montée à p ∈ [0,1] (captures au banc).
// `-lensAuto` rejoue la montée seul, en boucle de 7 s (films) — le
// simulateur ne drague pas (l'école `-cineTest`).
// Toute la chorégraphie est FONCTION PURE du temps et du doigt — aucune
// animation SwiftUI sur les uniforms (l'école ConnexionCine).
struct LiquidLensLab: View {
    private static let frozen: Double? = {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "-lensFreeze"), i + 1 < args.count,
              let v = Double(args[i + 1]) else { return nil }
        return min(max(v, 0), 1)
    }()

    private static let cycling = CommandLine.arguments.contains("-lensAuto")

    /// Le papier de la maison — le crème de la dalle d'exercice.
    private static let paper = Color(red: 0.956, green: 0.952, blue: 0.942)
    private static let ink = Color.black.opacity(0.88)

    private struct Sample {
        var pos: CGPoint
        var at: Date
    }

    /// Le doigt en cours, sinon nil.
    @State private var fingerLoc: CGPoint?
    /// Le chemin écrit par le doigt — la matière de l'encre.
    @State private var dragPath: [Sample] = []
    /// Relâcher : le liquide retombe — ressort pur du temps, l'encre sèche.
    @State private var release: (climb: Double, x: CGFloat, at: Date)?
    /// L'étirement lissé (vitesse verticale du doigt) — le verre est liquide.
    @State private var stretch: Double = 0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
                let now = tl.date
                let t = now.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 900)
                let d = drive(now: now, t: t, w: w, h: h)
                let lens = lensState(w: w, h: h, t: t,
                                     climb: d.climb, fx: d.fx)
                whiteWorld(w: w, h: h, t: t, climb: d.climb,
                           lens: lens, d: d)
                    .contentShape(Rectangle())
                    .gesture(dragGesture(h: h),
                             isEnabled: Self.frozen == nil && !Self.cycling)
            }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }

    // MARK: Le monde blanc

    /// Tout ce qui doit passer À TRAVERS le verre vit dans cette couche :
    /// papier, grain, encre, textes. Le layerEffect la réfracte en bloc.
    private func whiteWorld(w: CGFloat, h: CGFloat, t: Double,
                            climb: Double, lens: Lens,
                            d: Drive) -> some View {
        // Les scalaires SORTIS de l'appel : le type-checker abandonne sinon
        // (leçon des 36 arguments de navMonolith).
        let sizeW = Float(w), sizeH = Float(h)
        let cX = Float(lens.center.x), cY = Float(lens.center.y)
        let rad = Float(lens.radius)
        let f0 = Float(lens.f0), dispV = Float(lens.disp)
        let emberV = Float(lens.ember), squashV = Float(lens.squash)
        let tS = Float(t)
        let lensShader = ShaderLibrary.liquidLens(
            .float2(sizeW, sizeH), .float2(cX, cY), .float(rad),
            .float(f0), .float(dispV), .float(emberV),
            .float(squashV), .float(1.0), .float(tS),
            .float(0.0), .float(0.0), .float(0.0))
        let hasTrail = d.sta.count >= 8 && d.dry < 0.999
        // La tache NAÎT en fondu avec la longueur du chemin — jamais de
        // seuil qui pop (la leçon du calque rectangulaire).
        let birthV = Float(sstep(24, 170, Double(d.pathLen)))
        let trailShader = ShaderLibrary.inkTrail(
            .float2(sizeW, sizeH), .floatArray(d.sta),
            .float2(Float(d.boundsMin.x), Float(d.boundsMin.y)),
            .float2(Float(d.boundsMax.x), Float(d.boundsMax.y)),
            .float(tS), .float(Float(d.dry)), .float(birthV),
            .float(1.0))
        return ZStack {
            Self.paper
            // Le grain du papier : il se tord lui aussi sous le verre.
            WoopGrain(density: 0.030, lightAlpha: 0.020, darkAlpha: 0.045)
                .allowsHitTesting(false)
            // L'ENCRE : le filament écrit par le doigt, peint dans la
            // couche que le verre réfracte — la pill repasse dessus et le
            // tord. Démontée sitôt sèche : plus un pixel de shader pour rien.
            if hasTrail {
                Rectangle()
                    .fill(.white)
                    .colorEffect(trailShader)
                    .allowsHitTesting(false)
            }
            Text("Une nouvelle ère\nd'entraînement.")
                .font(.inter(27, .medium))
                .foregroundStyle(Self.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .blur(radius: 5 * sstep(0.18, 0.50, climb))
                .opacity(1 - sstep(0.12, 0.45, climb))
                .position(x: w / 2, y: h * 0.42 - 26 * sstep(0.08, 0.55, climb))
            // Le titre que la lentille vient déchirer en arc-en-ciel : il
            // n'existe vraiment qu'à travers le verre — dès que le limbe le
            // couvre, l'original s'efface pour ne laisser QUE la copie
            // réfractée (sinon les deux se lisent : glitch, pas verre).
            let covered = sstep(-95, 10,
                                h * 0.60 - (lens.center.y - lens.radius))
            Text("Start Training")
                .font(.inter(31, .semibold))
                .foregroundStyle(Self.ink)
                .opacity(sstep(0.38, 0.62, climb) * (1 - 0.85 * covered))
                .position(x: w / 2, y: h * 0.60)
            Text("Glisse vers le haut")
                .font(.inter(13, .medium))
                .foregroundStyle(Color.black.opacity(0.35))
                .opacity(1 - sstep(0.04, 0.22, climb))
                .position(x: w / 2, y: h - 42)
        }
        .frame(width: w, height: h)
        .compositingGroup()
        .layerEffect(lensShader,
                     maxSampleOffset: CGSize(width: 110, height: 110))
    }

    // MARK: La chorégraphie

    /// Tout ce que la frame doit savoir : la montée, le doigt, l'encre.
    private struct Drive {
        var climb: Double
        var fx: CGFloat
        var sta: [Float] = []
        var boundsMin: CGPoint = .zero
        var boundsMax: CGPoint = .zero
        var pathLen: CGFloat = 0
        var dry: Double = 1
    }

    /// La montée depuis la hauteur du doigt : 0 au bord bas, 1 en haut.
    private func climbOf(y: CGFloat, h: CGFloat) -> Double {
        min(max(Double((h * 0.90 - y) / (h * 0.72)), 0), 1.06)
    }

    private func drive(now: Date, t: Double,
                       w: CGFloat, h: CGFloat) -> Drive {
        if let f = Self.frozen {
            return cyclePose(tau: 0.8 + 3.0 * f, t: t, w: w, h: h,
                             still: true)
        }
        if Self.cycling {
            return cyclePose(tau: t.truncatingRemainder(dividingBy: 7.0),
                             t: t, w: w, h: h, still: false)
        }
        if let loc = fingerLoc {
            var d = Drive(climb: climbOf(y: loc.y, h: h), fx: loc.x)
            let pts = dragPath.map { (pos: $0.pos,
                                      age: now.timeIntervalSince($0.at)) }
            if let tr = stations(from: pts) {
                d.sta = tr.sta; d.boundsMin = tr.bMin
                d.boundsMax = tr.bMax; d.pathLen = tr.len
                d.dry = 0
            }
            return d
        }
        if let r = release {
            let e = now.timeIntervalSince(r.at)
            // Rappel amorti avec un souffle de rebond : du liquide, pas un
            // ressort de tiroir.
            let c = max(r.climb * exp(-6.0 * e) * cos(5.2 * e), -0.05)
            var d = Drive(climb: c,
                          fx: w / 2 + (r.x - w / 2) * CGFloat(exp(-4.0 * e)))
            let pts = dragPath.map { (pos: $0.pos,
                                      age: now.timeIntervalSince($0.at)) }
            if let tr = stations(from: pts) {
                d.sta = tr.sta; d.boundsMin = tr.bMin
                d.boundsMax = tr.bMax; d.pathLen = tr.len
                // L'encre boit le papier et s'efface pendant la retombée.
                d.dry = sstep(0.25, 2.0, e)
            }
            return d
        }
        return Drive(climb: 0, fx: w / 2)
    }

    /// La montée SANS doigt (`-lensAuto`, `-lensFreeze`) : le même geste,
    /// écrit en fonction pure — repos (0→0,8 s), montée (0,8→3,8 s), tenue
    /// (3,8→4,5 s), retombée et séchage, silence, boucle à 7 s.
    private func cyclePose(tau: Double, t: Double,
                           w: CGFloat, h: CGFloat, still: Bool) -> Drive {
        func finger(_ tp: Double) -> CGPoint {
            let u = min(max((tp - 0.8) / 3.0, 0), 1)
            let e = u * u * (3 - 2 * u)
            var y = h * 0.90 - CGFloat(e) * h * 0.72
            var x = w * 0.5 + w * 0.055 * CGFloat(sin(u * 8.5 + 0.6))
            // Le CROCHET : à mi-course le doigt part à droite et REDESCEND
            // un souffle — le repli du chemin que le vrai doigt fait, celui
            // qui tirait des traits : chaque film le teste désormais.
            let hook = sstep(0.38, 0.52, u) * (1 - sstep(0.52, 0.70, u))
            x += w * 0.16 * CGFloat(hook)
            y += h * 0.045 * CGFloat(hook)
            return CGPoint(x: x, y: y)
        }
        if tau < 0.8 && !still { return Drive(climb: 0, fx: w / 2) }
        let riseTau = min(tau, 3.8)
        // Le chemin déjà parcouru, rééchantillonné comme un vrai drag.
        var pts: [(pos: CGPoint, age: Double)] = []
        let n = 30
        for i in 0...n {
            let tp = 0.8 + (riseTau - 0.8) * Double(i) / Double(n)
            // Les âges RÉELS, même figé : le bas de la tache a l'âge du
            // geste — la vitesse et le séchage se jugent en capture.
            pts.append((finger(tp), tau - tp))
        }
        let loc = finger(riseTau)
        var d = Drive(climb: climbOf(y: loc.y, h: h), fx: loc.x)
        if tau > 4.5 && !still {
            let e = tau - 4.5
            d.climb = max(climbOf(y: finger(3.8).y, h: h)
                          * exp(-6.0 * e) * cos(5.2 * e), -0.05)
            d.fx = w / 2 + (finger(3.8).x - w / 2) * CGFloat(exp(-4.0 * e))
            d.dry = sstep(0.25, 2.0, e)
        } else {
            d.dry = 0
        }
        if let tr = stations(from: pts) {
            d.sta = tr.sta; d.boundsMin = tr.bMin
            d.boundsMax = tr.bMax; d.pathLen = tr.len
        }
        return d
    }

    /// Rééchantillonne le chemin du doigt en 24 stations (x, y, âge,
    /// flânerie) uniformes en ABSCISSE CURVILIGNE — le vrai tracé, quel
    /// que soit le geste : descentes, crochets, boucles. Le paramétrage
    /// par la hauteur seule tirait des traits droits dès que le chemin se
    /// repliait (le bug des « traits pas naturels » de Kathryn).
    /// La FLÂNERIE (doigt lent = la flaque gonfle) est calculée ici puis
    /// lissée 1-2-1 : aucune marche entre stations. Station 0 = la pointe
    /// (le doigt), station K-1 = la base (le départ du geste).
    private func stations(from pts: [(pos: CGPoint, age: Double)])
        -> (sta: [Float], bMin: CGPoint, bMax: CGPoint, len: CGFloat)? {
        guard pts.count >= 2 else { return nil }
        // Longueurs cumulées le long du chemin.
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
            // k = 0 à la pointe (fin du chemin), k = K-1 à la base.
            let s = S * (1 - CGFloat(k) / CGFloat(K - 1))
            while i > 0 && cum[i] > s { i -= 1 }
            let a = pts[i]
            let b = pts[i + 1]
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
            let dAge = abs(a1 - a0) / Double(min(k + 1, K - 1)
                                             - max(k - 1, 0))
            let vel = dsStep / max(dAge, 1e-4)
            raw[k] = 1 - sstep(250, 1400, vel)
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

    /// L'état de la lentille — géométrie et matière de la montée.
    struct Lens {
        var center: CGPoint
        var radius: CGFloat
        var f0 = 0.80, disp = 0.22, ember = 0.0, squash = 1.0
    }

    private func lensState(w: CGFloat, h: CGFloat, t: Double,
                           climb: Double, fx: CGFloat) -> Lens {
        // LE DOIGT PORTE LA PILL : l'émergence libère la bulle du bord bas,
        // puis elle monte posée au-dessus du doigt et GROSSIT en montant.
        let e = sstep(0.0, 0.30, climb)
        // Au repos la bulle respire — deux périodes sans rapport entier.
        let calm = 1 - sstep(0.0, 0.22, climb)
        let R0 = w * 0.66 + 2.6 * CGFloat(sin(t * 0.63)) * CGFloat(calm)
        let Rc = w * 0.26 + w * 0.115 * CGFloat(sstep(0.28, 1.0, climb))
        let radius = R0 + (Rc - R0) * CGFloat(e)
        let cyRest = h - 24 + 3.5 * CGFloat(sin(t * 0.80)) * CGFloat(calm)
                     + radius
        let cyRide = h * 0.90 - CGFloat(climb) * h * 0.72 - radius * 0.55
        let cy = cyRest + (cyRide - cyRest) * CGFloat(e)
        let cx = w / 2 + (fx - w / 2) * CGFloat(sstep(0.06, 0.34, climb))
        var lens = Lens(center: CGPoint(x: cx, y: cy), radius: radius)
        lens.f0 = 0.80 - 0.14 * sstep(0.30, 0.95, climb)
        lens.disp = 0.22 + 1.50 * sstep(0.40, 0.85, climb)
        // La braise s'allume dès les premiers centimètres et respire sur
        // toute la montée — elle ne meurt plus : elle attend le banc C.
        var ember = sstep(0.02, 0.12, climb)
                    * (0.50 + 0.35 * sin(.pi * min(max(climb, 0) / 0.92, 1.0)))
        ember = max(ember, (0.10 + 0.05 * sin(t * 0.9)) * calm)
        lens.ember = ember
        // Le liquide qui pousse au bord est plus large que haut ; porté
        // vite, il s'étire — la vitesse du doigt est dans `stretch`.
        lens.squash = (1 + 0.10 * (1 - e)) * (1 - stretch)
        return lens
    }

    private func dragGesture(h: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                let now = Date()
                if fingerLoc == nil {
                    dragPath = [Sample(pos: v.location, at: now)]
                }
                fingerLoc = v.location
                release = nil
                // La vitesse verticale, lissée → l'étirement du verre.
                let target = min(max(Double(-v.velocity.height) / 2600,
                                     -0.05), 0.14)
                stretch += (target - stretch) * 0.25
                if let last = dragPath.last,
                   hypot(v.location.x - last.pos.x,
                         v.location.y - last.pos.y) > 7 {
                    dragPath.append(Sample(pos: v.location, at: now))
                    if dragPath.count > 90 {
                        dragPath.removeFirst(dragPath.count - 90)
                    }
                }
            }
            .onEnded { v in
                guard let loc = fingerLoc else { return }
                fingerLoc = nil
                stretch = 0
                release = (climbOf(y: loc.y, h: h), loc.x, .now)
            }
    }

    private func sstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let u = min(max((x - a) / (b - a), 0), 1)
        return u * u * (3 - 2 * u)
    }
}
