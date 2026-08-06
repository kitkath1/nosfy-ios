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
    /// C'est désormais la FICHE qui l'écrit (depuis la montée du doigt) :
    /// le galet la lit, il ne la possède plus.
    @Binding var flood: Double
    /// La lentille couvre la page : le verre dort (horloges en pause).
    var asleep: Bool = false
    /// LE GESTE UNIQUE : le galet ne déclenche plus rien lui-même — il
    /// RAPPORTE son doigt (en points plein écran) à la fiche, qui blanchit
    /// la page, monte la lentille déjà soulevée, et lui passe le relais.
    let onDrive: (CGPoint, CGFloat) -> Void
    let onRelease: (CGPoint, CGFloat) -> Void
    /// Le lancement direct — pour l'accessibilité seulement.
    let onLaunch: () -> Void

    @State private var pull: CGFloat = 0
    /// La renaissance : quand la nuit de la page revient, la braise se
    /// rallume d'une bouffée (attaque 0,12 s, retombée ~0,9 s).
    @State private var wakeAt: Date?
    /// LA VIBRATION FORTE qui annonce le début : un coup lourd dès que le
    /// doigt engage vraiment le galet, une fois par geste.
    @State private var beganBeat = 0
    @State private var began = false
    /// La place réservée dans la mise en page. Le verre déborde : en haut
    /// pour son halo et la portée de sa réfraction (`maxSampleOffset`),
    /// en bas jusqu'au bord physique de l'écran, sous la zone sûre.
    static let height: CGFloat = 160
    private static let padTop: CGFloat = 120
    private static let padBottom: CGFloat = 60

    /// Le papier de la maison — celui du voile, celui de la lentille.
    private static let paper = Color(red: 0.956, green: 0.952, blue: 0.942)

    /// Ce que le geste a soulevé : le galet monte AVEC le doigt — suivi
    /// direct sur 60 pt (toute la montée nocturne se VOIT sur la page),
    /// puis la résistance s'épaissit, et de toute façon l'aube arrive.
    private var lift: CGFloat {
        min(pull, 60) + max(pull - 60, 0) * 0.25
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
        .sensoryFeedback(.impact(weight: .heavy, intensity: 1.0),
                         trigger: beganBeat)
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
            // La chaleur vit sur la MONTÉE NOCTURNE (flood ≤ 0,22 au bout
            // du temps 1) : la braise fait son crescendo pendant que la
            // page est encore sombre — c'est là qu'on doit la voir.
            let heat = sstep(0.02, 0.26, u)
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
            // La respiration ×2,5 (« elle peut le faire davantage ») —
            // mêmes horloges que la bulle de la lentille, amplitude d'un
            // être qui dort.
            let D = w * 0.60 + 6.5 * sin(t * 0.63) * calm
            let squash = 1.08
            let crestY = Self.padTop + 20 - lift
                         + 6.0 * sin(t * 0.80) * calm
            let cyD = crestY + D / squash
            // La calotte n'approche JAMAIS son limbe du bord : à 1,03 D
            // son échantillonnage sortait de la nacre et peignait les
            // « traits noirs dégueus » du verdict. Le feu du geste vient
            // des traits de LUMIÈRE au-dessus — eux ne savent pas faire
            // de noir.
            let Rg = D * (0.62 + 0.06 * heat)
            let cX = Float(w / 2)
            let cY = Float(cyD)

            // — La braise : CHUCHOTÉE au repos (elle vit à l'intérieur du
            //   dôme, une chaleur qui circule), crescendo au doigt,
            //   bouffée de renaissance, et l'anti-fournaise : elle cède
            //   au voile.
            let emberBase = 0.06 + 0.04 * sin(t * 0.9)
            let emberV = Float(min((emberBase + 0.40 * heat
                                    + 0.25 * Double(wake)) * (1 - 0.85 * fv),
                                   0.55))

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
            // L'ÉPAULE EST MORTE. Mesurée par le jury : 225 → 164 → 220 en
            // trois pixels sous le fil, sur tout l'arc — un creux étroit
            // coincé entre deux clairs, c'est-à-dire un CONTOUR dessiné,
            // pas un éclairage. La règle qui remplace le réglage : sur
            // toute coupe verticale de la crête, la dérivée ne change de
            // signe qu'UNE fois. Le volume vient du corps, du fil et du
            // bloom — jamais d'une rainure.
            let flanc = Self.toward(0.878, 0.822, 0.726, fv)
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
                            .init(color: flanc, location: 0.93),
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
                      inkFade: inkFade, t: t)
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
                       fv: Double, inkFade: Double,
                       t: Double) -> some View {
        // L'ancre de l'écriture : la crête SANS son souffle — elle suit
        // le doigt (lift), jamais la respiration.
        let inkY = Self.padTop + 20 - lift
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
        // La couronne respire avec le corps — même horloge 0,63.
        let breathe = 0.5 + 0.5 * sin(t * 0.63)
        let filA = (0.88 + 0.12 * breathe) * live
        let bloomA = (0.55 + 0.9 * heat) * (0.78 + 0.30 * breathe) * live
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
                // « L'ancre orange s'étire vers le haut » : sous la
                // chaleur du geste, le bloom s'élargit et s'élève.
                Ellipse()
                    .stroke(bloomC.opacity(bloomA),
                            lineWidth: 8 + 12 * heat)
                    .blur(radius: 6 + 9 * heat)
                    .frame(width: 2 * (D + 4 + 10 * heat),
                           height: 2 * (D + 4 + 10 * heat) / squash)
                    .position(x: w / 2, y: cyD - 8 * heat)
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

            // LA POUDRE : un champ, calculé par pixel — le galet souffle
            // sa brume au sommet de chaque respiration, davantage sous le
            // doigt.
            dust(w: w, H: H, D: D, squash: squash, cyD: cyD, t: t,
                 heat: heat, live: 1 - 0.9 * fv)

            // L'invite, moderne et légère : deux chevrons gris
            // superposés en cascade, et le mot COUCHÉ DANS L'ARC —
            // une gravure, pas une étiquette.
            Group {
                chevrons(t: t)
                    .position(x: w / 2, y: inkY + 26)
                // DROIT, HAUT, ET IMMOBILE. Deux fautes payées ici :
                // couché dans l'arc il lisait « bug d'affichage » ; puis,
                // même droit, ancré à la crête il DÉRIVAIT de ±6 pt avec
                // la respiration du galet — une ligne de texte qui flotte
                // sans arrêt, c'est exactement ce qu'on lit comme fake.
                // La matière respire, l'écriture ne respire pas.
                Text(label)
                    .font(.inter(13, .light))
                    .tracking(0.6)
                    .foregroundStyle(Color.black.opacity(0.42))
                    .position(x: w / 2, y: inkY + 58)
            }
            .opacity(inkFade)
        }
        .frame(width: w, height: H)
    }

    /// Les deux chevrons gris superposés — celui du haut respire une
    /// demi-phase en avance : l'invitation, jamais un panneau.
    private func chevrons(t: Double) -> some View {
        let a1 = 0.5 + 0.5 * sin(t * 2.0)
        let a2 = 0.5 + 0.5 * sin(t * 2.0 - 0.9)
        return ZStack {
            Image(systemName: "chevron.up")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.14 + 0.18 * a1))
                .offset(y: -4.5)
            Image(systemName: "chevron.up")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.14 + 0.18 * a2))
                .offset(y: 3.5)
        }
    }

    /// LA POUDRE : une BRUME au-dessus de la crête, jamais des points.
    /// À bout de bras on ne doit voir qu'un voile ; un grain ne se
    /// distingue qu'en approchant. D'où : des motes SOUS LE PIXEL
    /// (0,28-0,56 pt — l'anti-aliasing fait le reste), une opacité de
    /// souffle (≤ 0,14), et beaucoup — une poudre est une QUANTITÉ, pas
    /// une taille. Aucune croix, aucun trait : un pictogramme d'étincelle
    /// est un dessin, pas de la lumière. Elles naissent sur la crête,
    /// flottent (elles ne fusent pas), meurent en cloche, et l'émission
    /// suit l'EXPIRATION du galet — le doigt la redouble.
    private func dust(w: CGFloat, H: CGFloat, D: CGFloat, squash: CGFloat,
                      cyD: CGFloat, t: Double, heat: Double,
                      live: Double) -> some View {
        let breathe = 0.5 + 0.5 * sin(t * 0.63)
        let emission = Float((0.35 + 0.65 * breathe * breathe)
                             * (1 + 1.2 * heat) * live)
        let cx = Float(w / 2), cy = Float(cyD)
        let rd = Float(D), sq = Float(squash), tt = Float(t)
        return Rectangle()
            .fill(.black)   // JAMAIS .clear : le `* color.a` avale tout
            .colorEffect(ShaderLibrary.pebbleDust(
                .float2(cx, cy), .float2(rd, sq),
                .float(tt), .float(emission)))
            .frame(width: w, height: H)
            .allowsHitTesting(false)
    }

    /// Les poussières d'étoiles de la nuit, au-dessus de la crête —
    /// positions gelées par hachage (stables d'une frame à l'autre),
    /// scintillement LENT par phases décalées : des présences, pas des
    /// clignotants.
    private func starField(w: CGFloat, crestY: CGFloat,
                           t: Double) -> some View {
        Canvas { ctx, _ in
            // La même finesse que la poudre : sous le pixel, en souffle —
            // sinon la brume devient fine et les étoiles restent des
            // points, l'incohérence saute aux yeux.
            for i in 0..<26 {
                let h1 = Self.hash01(i * 3 + 1)
                let h2 = Self.hash01(i * 3 + 2)
                let h3 = Self.hash01(i * 3 + 3)
                let x = 14 + h1 * (w - 28)
                let y = crestY - 14 - h2 * 108
                let r = 0.16 + h3 * 0.16
                let tw = 0.55 + 0.45 * sin(t * (0.30 + h1 * 0.55)
                                           + h2 * 6.28)
                let a = (0.14 + 0.22 * h3) * tw
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

    // MARK: Le geste — UN SEUL, rapporté à la fiche en plein écran

    /// Le galet ne juge plus la course : il monte sous le doigt et
    /// rapporte chaque position (espace .global = l'espace de la
    /// lentille) — la fiche décide du voile, du montage et du relais.
    private var lifter: some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .global)
            .onChanged { v in
                pull = max(0, -v.translation.height)
                if pull > 8, !began {
                    began = true
                    beganBeat += 1
                }
                onDrive(v.location, v.velocity.height)
            }
            .onEnded { v in
                began = false
                onRelease(v.location, v.velocity.height)
                withAnimation(.spring(response: 0.42,
                                      dampingFraction: 0.74)) {
                    pull = 0
                }
            }
    }
}
