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
    /// 112 depuis le dock du player : le bas du frame du galet est à
    /// 76 pt du bord physique (la dalle incrustée, trait aéré) et la
    /// nacre doit CONTINUER de couler derrière la pierre jusqu'au bord —
    /// à 60 le raster s'arrêtait net, une tranche de dôme coupée au
    /// cutter dans la bande de la pastille.
    private static let padBottom: CGFloat = 112
    /// La marge LATÉRALE du raster — LE CARRÉ BLANC DU TÉLÉPHONE. Le dôme
    /// déborde de ~40 pt de chaque côté de l'écran et le limbe de la
    /// calotte échantillonne jusqu'à 1,32 R : sans marge, la couche
    /// s'arrête au bord et le shader clampe ses lectures sur la DERNIÈRE
    /// colonne — la nacre coupée s'y étale en petit bloc net (visible sur
    /// l'appareil seulement, affaire de précision GPU ; le simulateur
    /// passait à côté). La marge donne au limbe du vrai monde à boire,
    /// exactement comme `padTop` le fait pour le halo.
    private static let padSide: CGFloat = 120

    /// Le papier de la maison — celui du voile, celui de la lentille.
    private static let paper = Color(red: 0.956, green: 0.952, blue: 0.942)

    /// BANC SEULEMENT — `-galetT <s>` fige l'horloge de la respiration.
    /// Sans elle, le dôme respire de ±6,5 pt de rayon et la crête de
    /// ±6 pt : deux captures ne tombent jamais sur la même géométrie, et
    /// toute mesure au dixième de point est un mensonge. En production
    /// la prise est nil : rien ne change.
    static let tFreeze: Double? = Self.arg("-galetT")

    // MARK: Le liseré — le deuxième trait, à l'INTÉRIEUR du dôme

    /// Δ : de combien de points le liseré est rentré sous le bord. C'est
    /// le seul nombre que la maquette ne donne pas — il se choisit à la
    /// planche-contact. Plafond dur à 34 : au-delà de ~40 pt le liseré
    /// entre dans la portée du limbe de la calotte (1,32 Rg = 182,7 pt du
    /// centre) et se fait étaler en bandes.
    /// **14 pt, choisi à la planche-contact** : à 10 le liseré se lit
    /// encore accroché au dégradé chaud du bord, à 20 il descend trop
    /// profond dans le dôme sur les flancs. À 6 il est carrément
    /// contaminé par la lèvre sombre du bord (base mesurée à 130 L au
    /// lieu de 209, largeur 12 pt : ce n'est plus un liseré).
    /// Le plafond de 22 est une affaire de verre, et il se calcule SOUS LE
    /// DOIGT, pas au repos : la calotte grossit avec la chaleur
    /// (Rg = D·(0,62 + 0,06·heat) = 163,7) et son limbe échantillonne
    /// jusqu'à 1,32 Rg, soit 200 pt au-dessus du centre. Le liseré est à
    /// b − Δ = 223,3 − Δ. Au repos on aurait droit à 40 pt ; à pleine
    /// chaleur la marge tombe à 23,3. Mesuré : à Δ=14 le liseré est
    /// strictement identique posé et dans la couche, aux deux régimes —
    /// il ne touche jamais le verre.
    static let lisereDelta = min(max(Self.arg("-galetLisere") ?? 14, 0), 22)
    /// σ de la cloche. **0,60 pt → FWHM 1,41 pt, soit 4,2 px à 3×** : le
    /// cœur reste sous le pixel, l'antialiasing fait le reste.
    static let lisereSigma = Self.arg("-galetLisereW") ?? 0.60
    /// k : la couverture au pic. **1,00 → pic L ≈ 248 sur la nacre, soit
    /// +37 L, R−B +8** : un vrai filet blanc, la valeur de son verdict.
    /// 0,70 en ferait une suggestion ; 0 l'éteint (le témoin de l'A/B).
    static let lisereK = Self.arg("-galetLisereK") ?? 1.00
    /// LE SOUFFLE — σ et amplitude de la seconde cloche, très large et
    /// très faible, qui entoure le cœur. C'est le SEUL levier qui reste
    /// pour « renforcer » : à k = 1 le cœur est déjà blanc plein, il n'y
    /// a plus rien à monter. Le halo est ce qui sépare une lumière d'un
    /// trait blanc — un trait n'a pas de halo.
    static let lisereHalo = Self.arg("-galetLisereHalo") ?? 3.4
    static let lisereHaloA = Self.arg("-galetLisereHaloA") ?? 0.16
    /// LE DÉGRADÉ DES DEUX BOUTS, en degrés depuis le sommet : pleine
    /// intensité jusqu'à `lisereFull`, éteint à `lisereEnd`. Le contour
    /// sort de l'écran à 56,44° — le fondu doit donc se terminer un peu
    /// après, sinon le liseré est GUILLOTINÉ par le bord de l'écran, et
    /// un trait qui s'arrête net se lit comme un trait tracé.
    static let lisereFull = Self.arg("-galetLisereFull") ?? 34
    static let lisereEnd = Self.arg("-galetLisereEnd") ?? 58
    /// LA POUDRE DE DIAMANT semée sur le liseré. « Quasi invisible » est
    /// une DENSITÉ (un grain sur ~50 allumé à un instant donné), pas une
    /// opacité : diviser l'alpha ferait disparaître les grains au lieu de
    /// les affiner — la leçon payée sur la poudre du galet.
    static let lisereDust = Self.arg("-galetLisereDust") ?? 0.55
    /// L'OMBRE DU BORD — la profondeur maximale du creux (fraction
    /// retirée à la matière, atteinte à 4 pt sous le contour sur les
    /// flancs) et sa longueur de remontée τ. Cible mesurée sur la
    /// maquette : ×0,54 au fond du creux, retour aux neuf dixièmes vers
    /// 30 pt. `-galetOmbre 0` l'éteint (le témoin de l'A/B).
    static let ombre = Self.arg("-galetOmbre") ?? 0.46
    static let ombreTau = Self.arg("-galetOmbreTau") ?? 14
    /// L'AMPLITUDE DE LA RESPIRATION, en multiple. 1,0 = le réglage posé
    /// (±6,2 pt de rayon, ±5,9 pt de crête, soit 11,8 pt de course à la
    /// crête). `-galetSouffle 0.6` la calme, `1.4` l'exagère — le seul
    /// juge est l'œil, et ça se règle sans recompiler.
    static let souffleAmp = Self.arg("-galetSouffle") ?? 1.0
    private static func arg(_ flag: String) -> Double? {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: flag), i + 1 < a.count,
              let v = Double(a[i + 1]) else { return nil }
        return v
    }

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
            canvas(t: Self.tFreeze
                       ?? now.timeIntervalSinceReferenceDate
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
            // La largeur du RASTER : l'écran plus ses deux marges — tout
            // ce que le verre peut lire vit dans la couche.
            let W2 = w + 2 * Self.padSide
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
            // LA RESPIRATION, RELEVÉE (« anime-la un peu plus, pour
            // inciter à la toucher »). Trois choses changent, la période
            // n'en fait pas partie :
            //  — la FORME : plus un sinus, un souffle asymétrique (voir
            //    `breath`). C'est ça qui sépare « ça oscille » de « ça
            //    respire », et c'est ce qu'on a envie de toucher.
            //  — l'AMPLITUDE : ±6,2 pt de rayon, ±5,9 pt de crête, et le
            //    dôme GONFLE VERS LE HAUT (le rayon monte, la crête
            //    s'élève) au lieu que les deux dérivent sur des horloges
            //    séparées, en se contredisant la moitié du temps. On
            //    était monté à ±9,5 / ±9 : trop, « on dirait un bug » —
            //    mais le vrai coupable n'était pas là (voir `dress`).
            //  — le REPORT : la crête suit le corps d'un demi-temps.
            //    C'est le vieux principe du dessin animé — un corps
            //    souple ne bouge pas d'un bloc — et il coûte un `lag`.
            let amp = Self.souffleAmp
            let gonfle = Self.swell(t) * calm * amp
            let suit = Self.swell(t, lag: 0.55) * calm * amp
            let D = w * 0.60 + 6.2 * gonfle
            let squash = 1.08
            let crestY = Self.padTop + 20 - lift - 5.9 * suit
            let cyD = crestY + D / squash
            // La calotte n'approche JAMAIS son limbe du bord : à 1,03 D
            // son échantillonnage sortait de la nacre et peignait les
            // « traits noirs dégueus » du verdict. Le feu du geste vient
            // des traits de LUMIÈRE au-dessus — eux ne savent pas faire
            // de noir.
            let Rg = D * (0.62 + 0.06 * heat)
            let cX = Float(W2 / 2)
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
            let sizeW = Float(W2), sizeH = Float(H)
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
            // — LE LISERÉ : la deuxième courbe, rentrée de Δ sous le bord.
            //   Il respire avec le corps (même horloge 0,63, mais d'un
            //   souffle : ±6 %, pas ±12 — un liseré qui pulse se voit) et
            //   il cède au voile comme tout le reste : quand la page se
            //   remplit de jour, il n'a plus rien à border.
            // Le cœur du liseré est déjà blanc plein : le faire pulser
            // ne ferait que le faire CLIGNOTER. C'est son HALO qui
            // respire — et il ANTICIPE le mouvement d'un quart de temps.
            // La lumière se lève juste avant que le corps ne monte :
            // c'est l'anticipation, et c'est ce qui fait qu'un objet a
            // l'air de vouloir quelque chose.
            let brAvance = Self.breath(t, lag: -0.32)
            let lisSouffle: Double = 0.97 + 0.03 * brAvance
            let lisLive: Double = 1 - 0.90 * fv
            let lisGain = Float(Self.lisereK * lisSouffle * lisLive)
            let lisCX = Float(W2 / 2)
            let lisD = Float(D), lisSq = Float(squash)
            let lisDelta = Float(Self.lisereDelta)
            let lisSigma = Float(Self.lisereSigma)
            let lisHalo = Float(Self.lisereHalo)
            let lisHaloA = Float(Self.lisereHaloA * (0.62 + 0.76 * brAvance))
            // Le fondu travaille en cosinus (il décroît quand on descend
            // vers les flancs) : symétrique gauche/droite sans un seul
            // test de signe.
            let lisFull = Float(cos(Self.lisereFull * .pi / 180))
            let lisEnd = Float(cos(Self.lisereEnd * .pi / 180))
            // La poudre cède au voile comme le reste, et redouble sous le
            // doigt — le liseré scintille davantage quand il chauffe.
            let lisDustA = Float(Self.lisereDust * (1 + 0.8 * heat) * lisLive)
            let lisT = Float(t)
            // L'ombre cède au voile comme tout le reste : quand la page se
            // remplit de jour, un creux sombre serait une tache.
            let lisOmbre = Float(Self.ombre * lisLive)
            let lisTau = Float(Self.ombreTau)
            let lisereShader = ShaderLibrary.galetLisere(
                .float2(lisCX, cY),
                .float2(lisD, lisSq),
                .float2(lisDelta, lisSigma),
                .float2(lisHalo, lisHaloA),
                .float2(lisFull, lisEnd),
                .float2(lisDustA, lisT),
                .float2(lisOmbre, lisTau),
                .float(lisGain))

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
                // Décalées de la marge : leurs positions vivent dans le
                // repère de l'ÉCRAN, le raster est plus large qu'elles.
                starField(w: w, crestY: crestY, t: t)
                    .offset(x: Self.padSide)

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
                    .position(x: W2 / 2, y: cyD)

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
                    .position(x: W2 / 2, y: crestY + 84)
                    .blur(radius: 14)
            }
            .frame(width: W2, height: H)
            .compositingGroup()
            .layerEffect(lensShader, maxSampleOffset: Self.maxSample)
            // AU-DESSUS du verre — jamais réfractés (jury : « l'encre est
            // POSÉE sur le dôme, elle n'est pas dedans ») : le fil blanc
            // de crête, son bloom chaud, et l'encre droite.
            .overlay {
                dress(w: w, H: H, D: D, squash: squash, cyD: cyD,
                      crestY: crestY, heat: heat, fv: fv,
                      inkFade: inkFade, suit: suit, t: t)
            }
            // LE BORD (ombre + liseré) EST PEINT EN DERNIER, après
            // l'habillage. Ce n'est pas un détail d'ordre : le bloom du
            // `dress` est un stroke de 8 pt flouté de 6, posé à D+4 —
            // il bave donc jusqu'à ~6 pt DANS la matière et rallumait
            // exactement la zone qu'on cherche à creuser. Mesuré : le
            // creux ne rendait que la moitié de la profondeur commandée.
            // Le bloom garde sa part DEHORS (l'ombre ne travaille que
            // pour dist < 0), il perd seulement son débordement dedans.
            .compositingGroup()
            .colorEffect(lisereShader)
            .offset(x: -Self.padSide, y: -Self.padTop)
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
                       fv: Double, inkFade: Double, suit: Double,
                       t: Double) -> some View {
        // L'ANCRE DE L'ÉCRITURE — elle suit le doigt (lift) ET, depuis la
        // respiration relevée, le souffle du dôme.
        //
        // Elle ne le suivait pas : l'invite restait fixe pendant que le
        // galet montait de 17 pt sous elle. Verdict de Kathryn, et il est
        // juste : « ça fait sensation de bug ». Le mécanisme, mesuré —
        // l'écart crête → texte passait de 48 à 66 pt, ±16 %. L'œil
        // s'accroche à ce qui est NET : un texte immobile et lisible
        // devient malgré lui le repère fixe de la scène, et ce n'est plus
        // le dôme qu'on voit respirer, c'est le dôme qu'on voit GLISSER
        // derrière lui. Une grande forme molle qui coulisse sous un
        // élément net ne se lit jamais comme de la vie : elle se lit
        // comme un calque qui n'a pas suivi. (La preuve était déjà là :
        // sous le doigt, `lift` emporte tout et rien ne cloche.)
        //
        // MAIS PAS À 1:1. Le texte est 57 pt sous la crête, où la surface
        // se déplace moins que le sommet — et surtout un bord net bouge
        // dix fois plus visiblement qu'un bord flou : 12 pt de typo qui
        // monte et descend, c'est trop. À 0,70, l'écart ne varie plus que
        // de 3,5 pt, et ce reliquat ne se lit pas comme un décalage : il
        // se lit comme de la profondeur — le texte imprimé légèrement
        // SOUS la surface au lieu d'être un autocollant posé dessus.
        let inkY = Self.padTop + 20 - lift - 5.9 * suit * 0.70
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
        // La couronne respire avec le corps — le MÊME souffle, pas une
        // horloge parallèle, et elle l'anticipe comme le halo du liseré.
        let breathe = Self.breath(t, lag: -0.32)
        let filA = (0.84 + 0.16 * breathe) * live
        let bloomA = (0.55 + 0.9 * heat) * (0.68 + 0.48 * breathe) * live
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

            // L'invite : les deux chevrons, et l'inscription RESSUSCITÉE
            // (« il manque le texte minimal », 15 août — elle était morte
            // du 14). Minimale : l'encre discrète sous les chevrons, le
            // nom du geste, rien d'autre.
            chevrons(t: t)
                .position(x: w / 2, y: inkY + 30)
                .opacity(inkFade)
            Text(label)
                .font(.inter(13, .medium))
                .tracking(0.1)
                .foregroundStyle(Color.black.opacity(0.34))
                .position(x: w / 2, y: inkY + 57)
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
        // La poudre part sur l'EXPIRATION — le galet souffle sa brume en
        // se relâchant, pas en gonflant. Avec le souffle asymétrique, la
        // détente dure 62 % du cycle : la traîne est plus longue et plus
        // lisible qu'avec le sinus.
        let breathe = Self.breath(t, lag: 0.9)
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

    /// LA RESPIRATION — une seule horloge pour tout l'objet.
    ///
    /// La PÉRIODE ne bouge pas : 0,63 rad/s, celle de la bulle de la
    /// lentille, pour que le galet garde le même pouls dans les deux
    /// mondes. Ce qui change, c'est la FORME. Un souffle n'est pas un
    /// sinus : il gonfle vite, marque le haut, et se relâche plus
    /// lentement. Cette asymétrie-là est ce qui fait la différence entre
    /// un objet qui oscille et un objet qui respire — et un objet qui
    /// respire, on a envie d'y poser le doigt.
    ///
    /// `lag` en secondes : positif = en retard (le report du geste, la
    /// crête qui suit le corps), négatif = en avance (l'anticipation, la
    /// lumière qui se lève juste avant le mouvement).
    static func breath(_ t: Double, lag: Double = 0) -> Double {
        let period = 2 * Double.pi / 0.63
        var p = ((t - lag) / period).truncatingRemainder(dividingBy: 1)
        if p < 0 { p += 1 }
        let rise = 0.38
        let tri = p < rise ? p / rise : 1 - (p - rise) / (1 - rise)
        return tri * tri * (3 - 2 * tri)
    }

    /// Le souffle centré : −1 au creux, +1 au sommet de l'inspiration.
    static func swell(_ t: Double, lag: Double = 0) -> Double {
        breath(t, lag: lag) * 2 - 1
    }

    private func sstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let u = min(max((x - a) / (b - a), 0), 1)
        return u * u * (3 - 2 * u)
    }

    // MARK: Le geste — UN SEUL, rapporté à la fiche en plein écran

    /// Le galet ne juge plus la course : il monte sous le doigt et
    /// rapporte chaque position (espace .global = l'espace de la
    /// lentille) — la fiche décide du voile, du montage et du relais.
    fileprivate static let maxSample = CGSize(width: 110, height: 110)

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

// (Ici vivait la prise `-galetLisereIn`, qui glissait le liseré DANS la
// couche pour que le verre le réfracte. Mesuré : à Δ = 14 le liseré est
// entièrement hors de portée du limbe, et les deux places rendaient le
// même pixel — au repos comme sous le doigt. Un non-sujet ne mérite pas
// une branche. Et depuis que le bord porte aussi son OMBRE, la place
// n'est plus libre : il doit passer après l'habillage.)
