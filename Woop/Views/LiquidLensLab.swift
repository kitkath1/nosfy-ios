import SwiftUI

// MARK: - Banc de la lentille liquide (`-lensLab`)
//
// Une page de papier, une bulle de verre qui affleure au bord bas, et le
// drag qui la fait émerger : dôme d'abord, cercle complet ensuite, le monde
// réfracté et déchiré en arc-en-ciel à travers le verre, le bord en braise
// — orange mangé de noir, pointes jaunes. Relâcher trop tôt : le liquide
// retombe en ressort. Aller au bout : la cérémonie — la lentille file au
// centre, le verre fond, le blanc avale la coupe, et le monde ressort en
// noir : le cadran éclipse posé exactement où était la bulle, ses halos qui
// s'allument en canon, son disque devenu liquid glass noir.
//
// `-lensFreeze <p>` fige la progression du drag (captures au banc).
// Toute la chorégraphie est FONCTION PURE du temps et de la progression —
// aucune animation SwiftUI sur les uniforms (l'école ConnexionCine).
struct LiquidLensLab: View {
    private static let frozen: Double? = {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "-lensFreeze"), i + 1 < args.count,
              let v = Double(args[i + 1]) else { return nil }
        return min(max(v, 0), 1)
    }()

    /// Le papier de la maison — le crème de la dalle d'exercice.
    private static let paper = Color(red: 0.956, green: 0.952, blue: 0.942)
    private static let ink = Color.black.opacity(0.88)

    /// La cérémonie sans doigt : `-lensCommit` la déclenche seul, depuis
    /// p = 0,85 — le simulateur ne drague pas (l'école `-cineTest`).
    private static let autoCommit = CommandLine.arguments.contains("-lensCommit")

    /// La progression posée par le doigt (drag en cours), sinon nil.
    @State private var fingerP: Double?
    /// Relâcher sous le seuil : le liquide retombe — ressort pur du temps.
    @State private var release: (p: Double, at: Date)?
    /// Relâcher au-delà du seuil : la cérémonie est engagée. La progression
    /// du commit est FIGÉE dedans : sans elle, p retomberait à zéro et la
    /// lentille sauterait au repos avant de voyager.
    @State private var commit: (p: Double, at: Date)?
    /// Le VRAI monde du cadran est monté DERRIÈRE la page dès le commit —
    /// le débordement du verre le révèle par transparence : le monde qu'on
    /// devine est le monde qu'on obtient. `counterBirth` est calée pour que
    /// l'allumage des voix continue le geste de la vision ; `counterFace`
    /// est l'instant de la coupe (chiffres, éclosion). `whiteDismissed` :
    /// la page, devenue entièrement transparente, est retirée — la coupe
    /// ne change RIEN à l'écran.
    @State private var counterBirth: Date?
    @State private var counterFace: Date?
    @State private var whiteDismissed = false
    @State private var commitTaps = 0
    @State private var swapTaps = 0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
                let now = tl.date
                let t = now.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 900)
                let p = progress(at: now)
                let ce = commit.map { now.timeIntervalSince($0.at) }
                let lens = lensState(w: w, h: h, t: t, p: p, ce: ce)
                ZStack {
                    // Le VRAI monde d'abord, DERRIÈRE : le verre le révèle
                    // par transparence pendant le débordement.
                    if counterBirth != nil {
                        counterWorld(w: w, h: h, now: now)
                    }
                    // La page par-dessus, tant qu'elle n'est pas devenue
                    // entièrement transparente.
                    if !whiteDismissed {
                        whiteWorld(w: w, h: h, t: t, p: p, ce: ce, lens: lens)
                    }
                    LensParticles(now: now, lensCenter: lens.center,
                                  lensR: lens.radius, p: p,
                                  ceStart: commit?.at, face: counterFace)
                        .allowsHitTesting(false)
                }
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .gesture(dragGesture, isEnabled: Self.frozen == nil)
        .onAppear {
            guard Self.autoCommit else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                startCeremony(from: 0.85)
            }
        }
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.9),
                         trigger: commitTaps)
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 1.0),
                         trigger: swapTaps)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }

    // MARK: Le monde blanc

    /// Tout ce qui doit passer À TRAVERS le verre vit dans cette couche :
    /// papier, grain, textes. Le layerEffect la réfracte en bloc.
    private func whiteWorld(w: CGFloat, h: CGFloat, t: Double,
                            p: Double, ce: Double?,
                            lens: Lens) -> some View {
        // Les scalaires SORTIS de l'appel : le type-checker abandonne sinon
        // (leçon des 36 arguments de navMonolith).
        let sizeW = Float(w), sizeH = Float(h)
        let cX = Float(lens.center.x), cY = Float(lens.center.y)
        let rad = Float(lens.radius)
        let f0 = Float(lens.f0), dispV = Float(lens.disp)
        let emberV = Float(lens.ember), squashV = Float(lens.squash)
        let tS = Float(t)
        let visionV = Float(lens.vision), spillV = Float(lens.spill)
        let igV = Float(lens.sceneIg), pDriveV = Float(lens.pDrive)
        let lensShader = ShaderLibrary.liquidLens(
            .float2(sizeW, sizeH), .float2(cX, cY), .float(rad),
            .float(f0), .float(dispV), .float(emberV),
            .float(squashV), .float(1.0), .float(tS),
            .float(visionV), .float(spillV), .float(igV))
        let veilShader = ShaderLibrary.inkVeil(
            .float2(sizeW, sizeH), .float2(cX, cY), .float(rad),
            .float(pDriveV), .float(tS), .float(visionV))
        return ZStack {
            Self.paper
            // Le grain du papier : il se tord lui aussi sous le verre.
            WoopGrain(density: 0.030, lightAlpha: 0.020, darkAlpha: 0.045)
                .allowsHitTesting(false)
            // Les volutes d'encre noir-orangé — les FUTURS halos — peintes
            // dans la couche que le verre réfracte : on les voit se tordre
            // derrière la bille, et elles convergent dans la vision. La
            // passe est DÉMONTÉE une fois la vision pleine : plus un pixel
            // de shader pour rien pendant le débordement.
            if lens.vision < 0.98 {
                Rectangle()
                    .fill(.white)
                    .colorEffect(veilShader)
                    .allowsHitTesting(false)
            }
            Text("Une nouvelle ère\nd'entraînement.")
                .font(.inter(27, .medium))
                .foregroundStyle(Self.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .blur(radius: 5 * sstep(0.15, 0.45, p))
                .opacity(1 - sstep(0.10, 0.40, p))
                .position(x: w / 2, y: h * 0.42 - 26 * sstep(0.05, 0.50, p))
            // Le titre que la lentille vient déchirer en arc-en-ciel : il
            // n'existe vraiment qu'à travers le verre — dès que le limbe le
            // couvre, l'original s'efface pour ne laisser QUE la copie
            // réfractée (sinon les deux se lisent : glitch, pas verre).
            // La fenêtre est large : la réfraction ATTRAPE le texte avant
            // que le limbe le touche (au bord, le verre échantillonne
            // au-delà de lui) — l'original doit céder dès ce moment-là.
            let covered = sstep(-95, 10,
                                h * 0.60 - (lens.center.y - lens.radius))
            Text("Start Training")
                .font(.inter(31, .semibold))
                .foregroundStyle(Self.ink)
                .opacity((ce != nil ? 1 : sstep(0.45, 0.70, p))
                         * (1 - 0.85 * covered)
                         * (1 - sstep(1.05, 1.35, p)))
                .position(x: w / 2, y: h * 0.60)
            Text("Glisse vers le haut")
                .font(.inter(13, .medium))
                .foregroundStyle(Color.black.opacity(0.35))
                .opacity(1 - sstep(0.04, 0.25, p))
                .position(x: w / 2, y: h - 42)
        }
        .frame(width: w, height: h)
        .compositingGroup()
        .layerEffect(lensShader,
                     maxSampleOffset: CGSize(width: 110, height: 110))
    }

    // MARK: Le monde noir

    /// La page du cadran — le décor de `-counterLab`, le disque en liquid
    /// glass : les halos se reflètent dans la laque.
    private func counterWorld(w: CGFloat, h: CGFloat,
                              now: Date) -> some View {
        ZStack {
            Color.black
            NightSpotlight()
                .allowsHitTesting(false)
            if let birth = counterBirth {
                EclipseCounter(startedAt: counterFace ?? birth,
                               caption: "Série 1",
                               birth: birth,
                               faceBirth: counterFace,
                               birthDiameter: 68,
                               gloss: 1)
            }
            WoopGrain(density: 0.028, lightAlpha: 0.022, darkAlpha: 0.028)
                .allowsHitTesting(false)
            // Rejouer (banc seulement) : une vraie pastille identifiable,
            // apparue une seconde après l'arrivée. Tout reprend au papier.
            let fe = counterFace.map { now.timeIntervalSince($0) } ?? 9
            let chipIn = min(max((fe - 1.0) / 0.5, 0), 1)
            Button {
                fingerP = nil
                release = nil
                commit = nil
                counterBirth = nil
                counterFace = nil
                whiteDismissed = false
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 11, weight: .semibold))
                    Text("REJOUER")
                        .font(.inter(11, .semibold))
                        .tracking(2.6)
                }
                .foregroundStyle(Color.white.opacity(0.55))
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(Capsule().stroke(Color.white.opacity(0.16),
                                             lineWidth: 1))
            }
            .opacity(chipIn * chipIn * (3 - 2 * chipIn))
            .position(x: w / 2, y: h - 52)
        }
        // Le cadre de l'ÉCRAN, impératif : le cadran (540 pt de large)
        // déborde l'écran ; sans lui le ZStack prend la taille du cadran et
        // le GeometryReader le pose en haut-gauche — tout glisse de ~69 pt
        // à droite, et le raccord noir-sur-noir se voit.
        .frame(width: w, height: h)
        .clipped()
    }

    // MARK: La chorégraphie

    /// La progression : le doigt, sinon la cérémonie (figée au commit),
    /// sinon le ressort du relâcher, sinon zéro.
    private func progress(at now: Date) -> Double {
        if let f = Self.frozen { return f }
        if let c = commit { return c.p }
        if let fp = fingerP { return fp }
        if let r = release {
            let e = now.timeIntervalSince(r.at)
            // Rappel amorti avec un souffle de rebond : du liquide, pas un
            // ressort de tiroir.
            return max(r.p * exp(-6.0 * e) * cos(5.2 * e), -0.05)
        }
        return 0
    }

    /// L'état de la lentille — géométrie et matière, du repos au morphisme.
    struct Lens {
        var center: CGPoint
        var radius: CGFloat
        var f0 = 0.80, disp = 0.22, ember = 0.0, squash = 1.0
        var vision = 0.0, spill = 0.0, sceneIg = 0.0, pDrive = 0.0
    }

    private func lensState(w: CGFloat, h: CGFloat, t: Double,
                           p: Double, ce: Double?) -> Lens {
        // LA TRANSFORMATION SUIT LE DOIGT : une seule trajectoire,
        // paramétrée par pDrive ∈ [0, 2] — émergence (0→1) puis
        // CONDENSATION au centre (1→2). Le doigt la pilote en direct ; au
        // relâcher, l'horloge la termine sur LE MÊME chemin, puis la
        // matière s'encre. Aucun artifice autour : le verre, c'est tout.
        var pDrive = min(max(p, -0.06), 2.1)
        if let ce {
            let dur1 = LensCine.condenseTime(from: pDrive)
            pDrive = pDrive + (2.0 - pDrive)
                * sstep(0.0, max(dur1, 0.001), ce)
        }
        let p1 = min(pDrive, 1)
        let rise = sstep(0.0, 0.92, p1)
        let condense = sstep(0.25, 0.96, p1)
        // Au repos la bulle respire — deux périodes sans rapport entier.
        let calm = 1 - sstep(0.0, 0.25, pDrive)
        let R0 = w * 0.66 + 2.6 * sin(t * 0.63) * calm
        let R1 = w * 0.315
        var radius = R0 + (R1 - R0) * condense
        let cyRest = h - 24 + 3.5 * sin(t * 0.80) * calm + radius
        var cy = cyRest + (h * 0.60 - cyRest) * rise
        // Le second segment : la condensation, sous le doigt.
        let t2 = sstep(1.0, 1.95, pDrive)
        radius += (34 - radius) * t2
        cy += (h * 0.5 - cy) * t2
        var f0 = 0.80 - 0.16 * sstep(0.30, 0.95, p1) - 0.22 * t2
        var disp = (0.22 + 1.50 * sstep(0.42, 0.85, p1)) * (1 - 0.75 * t2)
        // La braise s'allume DÈS les premiers centimètres du drag, culmine
        // à mi-course, et meurt dans la condensation.
        var ember = sstep(0.03, 0.15, p1)
                    * (0.55 + 0.45 * sin(.pi * min(max(p1, 0) / 0.90, 1.0)))
                    * (1 - sstep(0.82, 0.97, p1))
        ember = max(ember, (0.10 + 0.05 * sin(t * 0.9))
                            * (1 - sstep(0.02, 0.20, pDrive)))
        ember *= 1 - sstep(1.02, 1.30, pDrive)
        // Le liquide qui pousse est plus large que haut ; libre, il est
        // rond ; condensé, il s'étire d'un souffle puis se pose.
        var squash = (1 + 0.10 * (1 - sstep(0.30, 0.80, pDrive)))
                     * (1 - 0.05 * sin(.pi * t2))
        // LA VISION naît SOUS LE DOIGT : en fin de course, le verre révèle
        // le monde d'après. Reculer le doigt la fait reculer — c'est un
        // objet, pas une transition lancée.
        var vision = sstep(1.72, 2.0, pDrive)
        var spill = 0.0
        let cx = w / 2
        if let ce {
            // Au relâcher : la condensation se termine sur le même chemin,
            // la vision s'achève, puis le monde DÉBORDE de la bille.
            let dur1 = LensCine.condenseTime(from: min(max(p, 0), 2.1))
            // Micro-tremblement amorti quand la bille se pose.
            if ce > dur1 {
                squash *= 1 + 0.022 * sin((ce - dur1) * 30)
                          * exp(-(ce - dur1) * 7)
            }
            vision = max(vision, sstep(dur1 - 0.10, dur1 + 0.10, ce))
            spill = sstep(dur1 + 0.06, dur1 + 0.80, ce)
        }
        // Les voix de la scène s'allument avec la vision puis le
        // débordement — la naissance du cadran reprendra ce niveau.
        let sceneIg = 0.5 * vision + 0.4 * spill
        var lens = Lens(center: CGPoint(x: cx, y: cy), radius: radius)
        lens.f0 = f0; lens.disp = disp; lens.ember = ember
        lens.squash = squash; lens.vision = vision; lens.spill = spill
        lens.sceneIg = sceneIg; lens.pDrive = pDrive
        return lens
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                guard commit == nil, counterBirth == nil else { return }
                let raw = -v.translation.height / 330
                // Le doigt pilote TOUTE la trajectoire (émergence puis
                // condensation, p ∈ [0, 2]) ; résistance douce aux bornes.
                if raw <= 0 { fingerP = max(raw * 0.15, -0.05) }
                else if raw < 2 { fingerP = raw }
                else { fingerP = min(2 + (raw - 2) * 0.15, 2.1) }
                release = nil
            }
            .onEnded { _ in
                guard commit == nil, counterBirth == nil,
                      let fp = fingerP else { return }
                fingerP = nil
                if fp >= 0.55 {
                    startCeremony(from: fp)
                } else {
                    release = (fp, .now)
                }
            }
    }

    /// La cérémonie : la progression du commit est figée, la coupe est
    /// programmée au pic du blanc — démontage du papier et naissance du
    /// cadran dans la même transaction, sans animation : le flash couvre la
    /// frame la plus chère.
    private func startCeremony(from p: Double) {
        let swapDate = Date(timeIntervalSinceNow: LensCine.swapDelay(from: p))
        commit = (p, .now)
        commitTaps += 1
        // Le vrai monde est monté TOUT DE SUITE, derrière la page : ses
        // voix s'allument en phase avec la vision (naissance calée sur la
        // coupe − 1,125 s = le niveau que la scène aura atteint), ses
        // chiffres et son éclosion attendent la coupe (`counterFace` dans
        // le futur : rien ne bouge avant elle).
        counterBirth = swapDate.addingTimeInterval(-1.125)
        counterFace = swapDate
        DispatchQueue.main.asyncAfter(
            deadline: .now() + LensCine.swapDelay(from: p)) {
            var tx = Transaction()
            tx.disablesAnimations = true
            withTransaction(tx) { whiteDismissed = true }
            swapTaps += 1
        }
    }

    private func sstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let u = min(max((x - a) / (b - a), 0), 1)
        return u * u * (3 - 2 * u)
    }
}

// MARK: - La partition du morphisme

/// Le seul événement discret : LA COUPE, posée quand la bille est noire et
/// la page drainée — un disque de 68 pt noir sur fond noir, invisible par
/// nature. Le compteur renaît de cette même bille. Tout le reste est
/// fonction pure du doigt et du temps dans `lensState`.
private enum LensCine {
    /// Le temps pour TERMINER la condensation depuis le p du relâcher —
    /// même vitesse que si le doigt avait fini le geste.
    static func condenseTime(from p: Double) -> Double {
        max(2.0 - p, 0) * (0.30 / 1.45)
    }
    /// Le délai de la coupe : condensation restante + vision + débordement.
    static func swapDelay(from p: Double) -> Double {
        condenseTime(from: p) + 0.88
    }
}
