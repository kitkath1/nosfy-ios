import SwiftUI

// MARK: - Le galet d'aube — la bulle de la lentille, du côté de la nuit

/// Le lancement de la fiche d'exercice : LA BULLE DE LA LENTILLE elle-même,
/// posée au bord bas de la page noire. Pas une imitation — le MÊME shader
/// (`liquidLens`, le seul layerEffect du projet), appelé avec les nombres
/// du début de sa montée : la calotte de verre, sa réfraction, sa couronne
/// de braise. Rien du fichier lentille n'est modifié : ses réglages sont
/// des prises externes, on lui donne d'autres nombres, c'est tout.
///
/// Sur la page noire, le verre n'aurait rien à réfracter : alors LA BULLE
/// PORTE LE JOUR. Sa couche arrière est un disque de papier — le monde
/// blanc, enfermé dans le verre, qui fond en noir à son limbe (le verre
/// boit la nuit à son bord). Le doigt tire : la braise fait son crescendo,
/// le jour se verse dans la page (le voile crème inchangé), et un verre
/// plein de jour sur une page de jour se fond — la lentille rouvre sur la
/// même bulle, au bord bas. Le même objet, littéralement le même shader.
///
/// Le contrat du dôme est repris à l'identique : course 116 pt, `flood`
/// écrit en direct, rampe du voile intouchée.
struct LaunchPebble: View {
    let label: String
    /// Fraction de la course déjà parcourue [0,1] — la page monte son
    /// voile dessus, le verre chauffe sa braise sur LA MÊME rampe.
    @Binding var flood: Double
    /// La lentille couvre la page : le verre dort (horloges en pause).
    var asleep: Bool = false
    /// Le doigt a tiré jusqu'au bout de la course.
    let onLaunch: () -> Void

    @State private var pull: CGFloat = 0
    @State private var fired = 0
    /// La renaissance : quand la nuit de la page revient, la braise se
    /// rallume d'une bouffée (attaque 0,12 s, retombée ~0,9 s).
    @State private var wakeAt: Date?

    /// La course qui déclenche — celle du dôme, validée au pouce.
    private static let travel: CGFloat = 116
    /// La place réservée dans la mise en page. Le verre déborde : en haut
    /// pour son halo et la portée de sa réfraction (`maxSampleOffset`),
    /// en bas jusqu'au bord physique de l'écran, sous la zone sûre.
    static let height: CGFloat = 160
    private static let padTop: CGFloat = 120
    private static let padBottom: CGFloat = 60

    /// Le papier de la maison — celui du voile, celui de la lentille.
    private static let paper = Color(red: 0.956, green: 0.952, blue: 0.942)

    /// Ce que le geste a soulevé : la même résistance que le dôme — le
    /// verre monte d'un tiers du tirage, le bout de course se SENT.
    private var lift: CGFloat {
        let u = min(pull / Self.travel, 1)
        return u * Self.travel * 0.34
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0,
                                paused: asleep)) { tl in
            let now = tl.date
            canvas(t: now.timeIntervalSinceReferenceDate
                       .truncatingRemainder(dividingBy: 900),
                   wake: wakeLevel(at: now))
        }
        .frame(height: Self.height)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .gesture(lifter)
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.9),
                         trigger: fired)
        .onChange(of: asleep) { was, sleeps in
            if was && !sleeps { wakeAt = Date() }
        }
        .accessibilityRepresentation {
            Button(label) { onLaunch() }
        }
    }

    // MARK: La bulle

    /// La couche que le verre réfracte + le layerEffect de la lentille.
    /// Dessinée en `background` débordant : elle ne participe pas au
    /// layout. Tous les scalaires sortent en `let` (la leçon des 36
    /// arguments : le type-checker abandonne sinon).
    private func canvas(t: Double, wake: Float) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let H = Self.padTop + geo.size.height + Self.padBottom

            // — Les horloges du repos : CELLES de la bulle de la lentille
            //   (0,63 / 0,80), pour que l'objet garde le même pouls dans
            //   les deux mondes. Le souffle se tait sous le doigt.
            let calm = 1.0 - min(Double(pull) / 40.0, 1.0)
            let u = flood
            let heat = sstep(0.02, 0.75, u)
            // La rampe du voile — LA MÊME que floodVeil côté fiche : le
            // verre se fond quand la page se remplit.
            let fu = min(max((u - 0.12) / 0.46, 0), 1)
            let fv = fu * fu * (3 - 2 * fu)

            // — LE DÉCOUPLAGE (verdict du jury, tours 1-5 payés) : D est
            //   le dôme VISIBLE, dessiné en direct ; la calotte de verre
            //   Rg est RÉDUITE à 0,74 D pour que son limbe — qui
            //   échantillonne jusqu'à ×1,32 — reste DANS la nacre. Le
            //   gouffre noir venait de là : toute structure de couche à
            //   portée du limbe se fait étaler en bandes. Au drag, la
            //   calotte grandit vers la crête et sa braise fait son
            //   crescendo : le repos est la maquette, le geste réveille
            //   le verre de feu de la lentille.
            let D = w * 0.60 + 2.6 * sin(t * 0.63) * calm
            let squash = 1.08
            let crestY = Self.padTop + 20 - lift
                         + 3.5 * sin(t * 0.80) * calm
            let cyD = crestY + D / squash
            let Rg = D * (0.62 + 0.41 * heat)
            let cX = Float(w / 2)
            let cY = Float(cyD)

            // — La braise : CHUCHOTÉE au repos (elle vit à l'intérieur du
            //   dôme, une chaleur qui circule), crescendo au doigt,
            //   bouffée de renaissance, et l'anti-fournaise : elle cède
            //   au voile.
            let emberBase = 0.06 + 0.04 * sin(t * 0.9)
            let emberV = Float(min((emberBase + 0.85 * heat
                                    + 0.25 * Double(wake)) * (1 - 0.85 * fv),
                                   1.0))

            // — Les prises du verre : magnification douce, dispersion
            //   quasi nulle (les franges couleur « sentent le procédé »).
            let sizeW = Float(w), sizeH = Float(H)
            let radV = Float(Rg)
            // f0 0,97 au repos : à 0,92 la discontinuité de magnification
            // au bord de la calotte dessinait un anneau fantôme dans la
            // nacre. Le verre se fait liquide sous le doigt seulement.
            let f0V = Float(0.995 - 0.16 * heat), dispV = Float(0.05)
            // shade 0,35 : l'assombrissement du limbe tombe à ~1,6 %, le
            // givre à ~5 %, la fenêtre spéculaire s'étouffe — à 1,0 la
            // calotte se lisait comme une assiette DANS l'assiette.
            let squashV = Float(squash), shadeV = Float(0.12)
            let tS = Float(t)
            let zero = Float(0)
            let lensShader = ShaderLibrary.liquidLens(
                .float2(sizeW, sizeH), .float2(cX, cY), .float(radV),
                .float(f0V), .float(dispV), .float(emberV),
                .float(squashV), .float(shadeV), .float(tS),
                .float(zero), .float(zero), .float(zero), .float(zero),
                .float(zero), .float(zero), .float(zero), .float(zero))

            // — Le disque de jour s'étend à 1,38 R : la calotte échantillonne
            //   jusqu'à ~1,32 R au limbe (edgeF du shader) — un fondu qui
            //   meurt À R rendait une bande de caoutchouc sombre de 45 pt
            //   autour du dôme (mesuré contre le banc -lensFreeze : chez la
            //   lentille, le limbe boit du PAPIER). Le fondu vit DEHORS :
            //   papier → or → orange profond (saturation TENUE, l'anti-brun)
            //   → nuit en ~30 pt au-dessus de la crête — c'est le halo de la
            //   maquette, que la couronne du shader vient chauffer.
            //   Chaque teinte remonte vers le papier avec le voile (`fv`) :
            //   aucun fantôme sombre sous le crème.
            let inkFade = max(0.0, 1.0 - u / 0.32)
            // LA NACRE (verdicts du jury) : cœur crème VOILÉ ≈ #EFE9DC,
            // jamais un pixel sous luma ~140 dans le dôme, des dégradés
            // qu'on ne peut pas pointer au zoom. L'épaule de la maquette
            // n'est PLUS dans la couche : c'est l'assombrissement du
            // verre lui-même (≤ 4,5 % au limbe de la calotte) — pile
            // l'amplitude « occlusion gaussienne » exigée.
            // UNE SEULE RESPIRATION (jury tour 10) : sous le fil, crème
            // chaude → épaule L≈170 → FOYER chaud L≈235 (R−B ≈ 55, dans
            // le tiers haut, sous la flèche) → longue extinction voilée
            // vers L≈136 en bas d'écran, en réchauffant — la dérivée ne
            // change de signe que deux fois, plus aucun anneau lisible.
            // Un gradient radial ne sait faire que des ANNEAUX : le foyer
            // y devenait un donut. Le radial ne porte plus qu'UNE descente
            // (pied chaud → épaule → corps → voile du bas) ; le foyer est
            // un voile elliptique séparé, LOCALISÉ sous la flèche.
            let bas = Self.toward(0.600, 0.530, 0.440, fv)
            let basH = Self.toward(0.630, 0.560, 0.460, fv)
            let corps = Self.toward(0.840, 0.790, 0.700, fv)
            let epaule = Self.toward(0.700, 0.660, 0.600, fv)
            let piedChaud = Self.toward(0.957, 0.871, 0.792, fv)
            let foyerC = Self.toward(0.975, 0.915, 0.780, fv)

            ZStack(alignment: .topLeading) {
                // Transparent partout ailleurs : la carte Série vit juste
                // au-dessus, la nuit reste la page.
                Color.clear

                // LES PETITES LUMIÈRES DERRIÈRE ELLE — « très discrètes,
                // à peine des suggestions » (jury : 1-2 px, ≤ 40 %).
                starField(w: w, crestY: crestY, t: t)

                // Le dôme nacre : dessin DIRECT, lisse jusqu'au bord —
                // plus AUCUNE structure à portée du limbe.
                Ellipse()
                    .fill(RadialGradient(
                        stops: [
                            .init(color: bas, location: 0.0),
                            .init(color: basH, location: 0.35),
                            .init(color: corps, location: 0.80),
                            .init(color: epaule, location: 0.952),
                            .init(color: piedChaud, location: 0.997),
                            .init(color: piedChaud, location: 1.0)
                        ],
                        center: .center, startRadius: 0, endRadius: D))
                    .frame(width: 2 * D, height: 2 * D / squash)
                    .position(x: w / 2, y: cyD)

                // LE FOYER : l'éclat chaud localisé sous la flèche — un
                // voile, pas un anneau. Dans la couche : le verre le
                // réfracte, la lumière vit DANS la matière.
                Ellipse()
                    .fill(RadialGradient(
                        stops: [
                            .init(color: foyerC.opacity(0.40),
                                  location: 0.0),
                            .init(color: foyerC.opacity(0.16),
                                  location: 0.60),
                            .init(color: foyerC.opacity(0.0),
                                  location: 1.0)
                        ],
                        center: .center, startRadius: 0,
                        endRadius: w * 0.40))
                    .frame(width: w * 0.80, height: 190)
                    .position(x: w / 2, y: crestY + 84)
                    .blur(radius: 14)
            }
            .frame(width: w, height: H)
            .compositingGroup()
            .layerEffect(lensShader,
                         maxSampleOffset: CGSize(width: 110, height: 110))
            // AU-DESSUS du verre — jamais réfractés (jury : « l'encre est
            // POSÉE sur le dôme, elle n'est pas dedans ») : le fil blanc
            // de crête, son bloom chaud, et l'encre droite.
            .overlay {
                dress(w: w, H: H, D: D, squash: squash, cyD: cyD,
                      crestY: crestY, heat: heat, fv: fv,
                      inkFade: inkFade)
            }
            .offset(y: -Self.padTop)
            .allowsHitTesting(false)
        }
    }

    /// L'habillage AU-DESSUS du verre : le fil de crête et son bloom —
    /// un trait blanc-chaud de 2 pt qui épouse le dôme, maximum à
    /// l'apex, fondu vers les flancs (jury : « fil de 2-4 px quasi
    /// blanc, la chaleur n'est que dans le bloom ») — et l'encre,
    /// droite, nette, posée SUR le dôme.
    private func dress(w: CGFloat, H: CGFloat, D: CGFloat, squash: CGFloat,
                       cyD: CGFloat, crestY: CGFloat, heat: Double,
                       fv: Double, inkFade: Double) -> some View {
        // La palette du contre-jury : bloom AMBRE saturé (R/G ≥ 1,8 — le
        // beige est la dérive marron), un « baiser » orange vif contre le
        // fil pour que la lumière PRENNE sur la crête, et l'arête des
        // flancs en ambre profond — le bord d'une source lumineuse ne
        // passe JAMAIS par un gris neutre.
        // Le fil est une LUMIÈRE, pas un stroke : cloche gaussienne
        // (trait fin + flou), pic NEUTRE (R−B ≤ 6 — le blanc chaud
        // lisait « contour teinté »), qui décroît dès l'apex le long de
        // l'arc. Le baiser est une pointe, jamais un anneau.
        let filC = Color(red: 0.988, green: 0.982, blue: 0.968)
        let baiserC = Color(red: 0.98, green: 0.52, blue: 0.20)
        let bloomC = Color(red: 1.00, green: 0.55, blue: 0.18)
        let flancC = Color(red: 0.42, green: 0.22, blue: 0.075)
        let live = (1 - 0.90 * fv)
        let filA = 1.0 * live
        let bloomA = (0.55 + 0.9 * heat) * live
        // Décroissance dès la crête : à l'aplomb des flancs le fil est
        // déjà éteint, l'ambre prend le relais.
        let c0 = min((crestY + D * 0.02) / H, 1)
        let c1 = min((crestY + D * 0.30) / H, 1)
        let arcFade = LinearGradient(
            stops: [
                .init(color: .white, location: 0),
                .init(color: .white, location: c0),
                .init(color: .white.opacity(0.45),
                      location: c0 + (c1 - c0) * 0.45),
                .init(color: .clear, location: c1)
            ],
            startPoint: .top, endPoint: .bottom)
        // Les flancs, complémentaires : l'arête ambre prend le relais là
        // où le fil meurt.
        let f0m = min((crestY + D * 0.04) / H, 1)
        let f1m = min((crestY + D * 0.16) / H, 1)
        let flancFade = LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .clear, location: f0m),
                .init(color: .white, location: f1m),
                .init(color: .white, location: 1)
            ],
            startPoint: .top, endPoint: .bottom)

        return ZStack(alignment: .topLeading) {
            Ellipse()
                .stroke(flancC.opacity(0.85 * live), lineWidth: 2.2)
                .blur(radius: 1.6)
                .frame(width: 2 * (D + 0.5),
                       height: 2 * (D + 0.5) / squash)
                .position(x: w / 2, y: cyD)
                .mask(flancFade)

            // Le fil vit tout entier CÔTÉ NUIT (D + 1, soudé au pied) :
            // contre le noir il est une lumière.
            ZStack(alignment: .topLeading) {
                Ellipse()
                    .stroke(bloomC.opacity(bloomA), lineWidth: 8)
                    .blur(radius: 6)
                    .frame(width: 2 * (D + 4), height: 2 * (D + 4) / squash)
                    .position(x: w / 2, y: cyD)
                Ellipse()
                    .stroke(baiserC.opacity(0.90 * live), lineWidth: 2.0)
                    .blur(radius: 0.6)
                    .frame(width: 2 * (D + 2.4),
                           height: 2 * (D + 2.4) / squash)
                    .position(x: w / 2, y: cyD)
                Ellipse()
                    .stroke(filC.opacity(filA), lineWidth: 1.7)
                    .blur(radius: 0.6)
                    .frame(width: 2 * (D + 1), height: 2 * (D + 1) / squash)
                    .position(x: w / 2, y: cyD)
            }
            .mask(arcFade)

            // L'encre ASSISE dans le papier (~#2A2622, luma ~40) — plus
            // claire, elle flottait.
            Group {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(red: 0.165, green: 0.149,
                                           blue: 0.133))
                    .position(x: w / 2, y: crestY + 56)
                Text(label)
                    .font(.inter(15, .medium))
                    .foregroundStyle(Color(red: 0.165, green: 0.149,
                                           blue: 0.133).opacity(0.94))
                    .position(x: w / 2, y: crestY + 88)
            }
            .opacity(inkFade)
        }
        .frame(width: w, height: H)
    }

    /// Les poussières d'étoiles de la nuit, au-dessus de la crête —
    /// positions gelées par hachage (stables d'une frame à l'autre),
    /// scintillement LENT par phases décalées : des présences, pas des
    /// clignotants.
    private func starField(w: CGFloat, crestY: CGFloat,
                           t: Double) -> some View {
        Canvas { ctx, _ in
            for i in 0..<18 {
                let h1 = Self.hash01(i * 3 + 1)
                let h2 = Self.hash01(i * 3 + 2)
                let h3 = Self.hash01(i * 3 + 3)
                let x = 14 + h1 * (w - 28)
                let y = crestY - 14 - h2 * 108
                let r = 0.5 + h3 * 0.5
                let tw = 0.55 + 0.45 * sin(t * (0.30 + h1 * 0.55)
                                           + h2 * 6.28)
                let a = (0.06 + 0.18 * h3) * tw
                ctx.fill(
                    Path(ellipseIn: CGRect(x: x - r, y: y - r,
                                           width: 2 * r, height: 2 * r)),
                    with: .color(Color(red: 1.0, green: 0.95, blue: 0.85)
                        .opacity(a)))
            }
        }
        .allowsHitTesting(false)
    }

    /// Un hachage entier → [0,1] stable (pas de hasard d'exécution : la
    /// nuit ne change pas d'étoiles à chaque lancement).
    private static func hash01(_ n: Int) -> Double {
        var x = UInt64(n &* 2654435761)
        x ^= x >> 13; x = x &* 0x9E3779B97F4A7C15; x ^= x >> 31
        return Double(x % 100_000) / 100_000
    }

    /// Une teinte qui remonte vers le papier avec le voile.
    private static func toward(_ r: Double, _ g: Double, _ b: Double,
                               _ fv: Double) -> Color {
        Color(red: r + (0.956 - r) * fv,
              green: g + (0.952 - g) * fv,
              blue: b + (0.942 - b) * fv)
    }

    /// La bouffée de renaissance — la grammaire de l'`invitePulse`.
    private func wakeLevel(at date: Date) -> Float {
        guard let wakeAt else { return 0 }
        let age = date.timeIntervalSince(wakeAt)
        guard age >= 0, age < 4 else { return 0 }
        return Float((1.0 - exp(-age / 0.12)) * exp(-age / 0.9))
    }

    private func sstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let u = min(max((x - a) / (b - a), 0), 1)
        return u * u * (3 - 2 * u)
    }

    // MARK: Le geste — le contrat du dôme, inchangé

    private var lifter: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { v in
                pull = max(0, -v.translation.height)
                flood = Double(min(pull / Self.travel, 1))
            }
            .onEnded { _ in
                if pull >= Self.travel {
                    fired += 1
                    flood = 1
                    onLaunch()
                } else {
                    withAnimation(.easeOut(duration: 0.22)) { flood = 0 }
                }
                withAnimation(.spring(response: 0.42,
                                      dampingFraction: 0.74)) {
                    pull = 0
                }
            }
    }
}
