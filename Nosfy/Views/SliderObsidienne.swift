import SwiftUI

// MARK: - LE SLIDER OBSIDIENNE
//
// Une capsule d'obsidienne LONGUE et son pouce de chrome. Deuxième registre du
// slider de validation, à côté du médaillon braise de `GaletSlide` : là où le
// médaillon est une cérémonie (feu, or, braises au sol), celui-ci est un
// GESTE — noir, blanc, minimal. Même machinerie, registre inverse.
//
// Toute la matière tient dans UN colorEffect (`sliderObsidienne`, en queue de
// `NavMonolith.metal`), pas dans une pile de couches SwiftUI. Deux raisons, et
// elles sont chèrement payées ailleurs dans ce dépôt :
//   — `.blur` pose un CALQUE : un voile clair uniforme sur tout le rectangle
//     de son hôte, aux coins carrés, que ni masque ni blend ne rattrapent.
//   — un `AngularGradient` sur une capsule de 345 × 68 met ses crêtes dans un
//     mouchoir de poche : la calotte droite n'occupe que 11° du tour.
// Le SDF, lui, sait où est le bord et quelle est sa normale. Le reste suit.
//
// Ce qui vit AU-DESSUS du shader, et seulement ça : le texte (masqué par le
// pouce), la poudre, la flèche (un glyphe peint dans un shader ne prend pas de
// ressort) et la zone de prise.
//
// LES DEUX INSTANTS DE L'ARRIVÉE, à ne jamais confondre :
//   — L'ARMEMENT, quand la course franchit 72 % le doigt encore posé. « Tu
//     peux lâcher. » Réversible : on se désarme en redescendant.
//   — LE COMMIT, quand on lâche au-dessus. Là seulement : l'onde blanche, la
//     gerbe, le triple coup, l'arpège.
struct SliderObsidienne: View {

    // MARK: Ce que l'appelant règle

    var label: String = "Start"
    /// Hauteur de la piste. Toutes les autres cotes en découlent — elles sont
    /// relevées sur la référence en fraction de CETTE hauteur.
    var height: CGFloat = 68
    /// La braise du déjà-poussé, derrière le pouce. « Extrêmement subtile »
    /// est une consigne : à 0,02 on la voit déjà, à 0,05 la capsule n'est
    /// plus noire. Zéro par défaut — la référence n'en a pas.
    var braise: Double = 0
    /// Les micro-diamants dans la poudre. À trancher à l'œil : « vraiment de
    /// la poudre blanche » peut vouloir dire poudre SEULE.
    var diamants: Bool = true
    /// BANC : rejoue le geste tout seul, en boucle. Le simulateur ne drague
    /// pas — sans ça, la traînée ne se filme pas.
    var auto: Bool = false
    /// Le mot au CENTRE DE LA PISTE, au lieu du centre de la course libre.
    ///
    /// Par défaut `false` — le composant décale son mot pour qu'aucune lettre
    /// ne dorme sous le pouce au repos (voir `texte`). Mais posé dans une
    /// card, sous un lien centré, ce décalage se LIT comme un défaut
    /// d'alignement : les deux mots doivent tomber sur le même axe (verdict
    /// Kathryn, 29-08, la card STOP). À n'activer que pour un mot COURT, qui
    /// tient dans la course libre sans toucher le pouce.
    var labelCentre: Bool = false
    /// Le veto. `false` ⇒ la course est REFUSÉE : grenat, deux coups secs.
    var validate: () -> Bool = { true }
    var onConfirm: () -> Void = {}
    /// La chaleur du geste, 0→1, pour que l'hôte s'embrase avec lui.
    var onMood: (CGFloat) -> Void = { _ in }
    /// BANC SEULEMENT : fige la course à p ∈ [0,1].
    var pose: CGFloat? = nil
    /// BANC SEULEMENT : force la prise (le gonflement + la flèche).
    var poseGrip: CGFloat? = nil

    // MARK: L'état du geste

    @State private var drag: CGFloat = 0
    @State private var dragging = false
    @State private var refused = false
    @State private var flashAt: Date = .distantPast
    @State private var okBeat = 0
    @State private var gripStart: Date? = nil
    @State private var gripEnd: (date: Date, level: CGFloat)? = nil
    @State private var lastTouch: Date = .distantPast
    /// L'armement : franchi, réversible, et il se SENT avant de se voir.
    @State private var arme = false
    @State private var lastCran = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.ongletCache) private var ongletCache
    @Environment(\.scenePhase) private var scenePhase
    @State private var monte = false
    @State private var retourTask: Task<Void, Never>?

    /// Le slider sert aussi les panneaux de série et d'arrêt : sa pause
    /// suit son hôte, jamais l'onglet Home d'un rythme global. Visible,
    /// il garde toute sa matière à 60 Hz, même sans geste en cours.
    private var dort: Bool {
        !monte || ongletCache || scenePhase != .active
    }

    // MARK: La poudre

    /// LA POUDRE BLANCHE. La `Dust` du médaillon, amputée de son or : ici
    /// tout est blanc, il n'y a ni braise au sol ni teinte pêche. Ce qui
    /// reste, c'est la loi — semer À LA DISTANCE, jamais au temps : un doigt
    /// arrêté ne sème rien, et c'est ça qui fait qu'on croit à la matière.
    struct Dust: Identifiable {
        let id = UUID()
        let born: Date
        let x: CGFloat
        let y: CGFloat
        /// La vitesse héritée du pouce — la poussière reste DERRIÈRE.
        let vx: CGFloat
        let rise: CGFloat
        let size: CGFloat
        /// Le scintillement : chaque grain a sa fréquence et sa phase.
        let freq: Double
        let phase: Double
    }

    /// LES MICRO-DIAMANTS : plus rares que la poudre, et TAILLÉS — quatre
    /// branches fines, un cœur vif. Leur scintillement est TRANCHÉ (cube du
    /// sinus) : presque éteints, puis un éclat. C'est l'éclat qui fait la
    /// facette ; un scintillement doux ne fait qu'une bulle.
    struct Diamond: Identifiable {
        let id = UUID()
        let born: Date
        let x: CGFloat
        let y: CGFloat
        let vx: CGFloat
        let rise: CGFloat
        let ray: CGFloat
        let freq: Double
        let phase: Double
        let tilt: Double
    }

    @State private var dusts: [Dust] = []
    @State private var gems: [Diamond] = []
    @State private var lastDustX: CGFloat?
    @State private var lastGemX: CGFloat?
    /// L'odomètre du SON. Un traqueur à part : `Paillettes` se nourrit de
    /// CHAQUE déplacement, le seuil de la poussière ne le concerne pas.
    @State private var lastSoundX: CGFloat?
    /// La position du pouce à l'image précédente. C'est elle qui sème — donc
    /// le ressort du commit sème lui aussi, et le retour en arrière non.
    @State private var lastAx: CGFloat?
    @State private var autoStart: Date? = nil
    @State private var autoP: CGFloat = 0
    @State private var autoGrip: CGFloat = 0

    private static let dustLife: Double = 0.9
    private static let gemLife: Double = 1.15
    /// La hauteur du Canvas : la poudre monte HORS de la piste. En overlay,
    /// donc zéro emprise de layout — un hôte plus haut posé en frère
    /// pousserait tout le slider vers le bas (payé au round 6 du médaillon).
    private static let cielH: CGFloat = 130

    // MARK: Les cotes, toutes relevées sur la référence

    /// Marge du rectangle-hôte du shader. L'ombre et le débord du pouce vivent
    /// DEDANS : le fondu d'hôte (0,42 × pad) les éteint avant l'arête, sinon
    /// le shader pose une PLAQUE rectangulaire en travers du fond.
    private static let pad: CGFloat = 52
    /// 226 px sur 331 dans la référence.
    private var medalH: CGFloat { height * 0.683 }
    /// La capsule du pouce est COUCHÉE : 380 × 226 px, soit 1,68.
    private var medalW: CGFloat { medalH * 1.68 }
    /// 50 px sur 331 — et l'encart vertical vaut exactement le même, ce qui
    /// tombe juste : le pouce est centré en hauteur.
    private var encart: CGFloat { height * 0.151 }
    private var axPad: CGFloat { medalW / 2 + encart }
    /// Le seuil : assez haut pour qu'un frôlement ne parte pas, assez bas pour
    /// que le dernier centimètre ne soit pas une épreuve.
    private static let seuil: CGFloat = 0.72

    // Les réglages du fil de métal liquide. Ce sont les valeurs de la nav bar,
    // reprises telles quelles — elles ont été payées là-bas. UNE seule change :
    // l'or tombe à zéro. La référence montre du CHROME, pas de l'or.
    private static let repetition: Float = 0.80
    private static let angle: Float = 94 * .pi / 180
    private static let softness: Float = 0.20      // haut ⇒ la dispersion MEURT
    private static let contour: Float = 0.88
    private static let distortion: Float = 0.42
    private static let speed: Float = 0.20
    // Asymétriques, TOUJOURS : symétriques, R et B tombent au même endroit,
    // s'additionnent sans vert entre, et l'arête vire au MAGENTA. Poussés
    // au-dessus de ceux de la barre (0,012 / 0,024) parce que la référence
    // tient une chroma de 161 là où la barre en rendait 57 — mais pas plus :
    // à 0,03 la barre virait « bulle de savon ».
    private static let shiftRed: Float = 0.017
    private static let shiftBlue: Float = 0.032
    private static let influence: Float = 7.0
    private static let gold: Float = 0.0
    private static let lineW: Float = 1.05
    private static let glow: Float = 0.30
    private static let floorLevel: Float = 0.30    // sans plancher : fil troué

    // MARK: Le corps

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let travel = max(W - 2 * axPad, 1)
            let p = pose ?? (auto ? autoP : min(max(drag / travel, 0), 1))
            let ax = axPad + p * travel

            TimelineView(.animation(minimumInterval: 1.0 / 60.0,
                                    paused: dort)) { tl in
                let now = tl.date
                let grip = poseGrip ?? (auto ? autoGrip : gripLevel(at: now))
                let flash = max(0, 1 - now.timeIntervalSince(flashAt) / 0.45)

                // `Color.clear` porte le layout ; tout le reste vit en
                // background/overlay — ZÉRO emprise.
                Color.clear
                    .frame(width: W, height: height)
                    .background {
                        matiere(W: W, ax: ax, p: p, grip: grip,
                                flash: flash, now: now)
                            .allowsHitTesting(false)
                    }
                    // LE TEXTE, sous le pouce : il est peint au-dessus du
                    // shader (le pouce est DANS le shader), mais son masque
                    // lui creuse un trou à l'aplomb du pouce. C'est le pouce
                    // qui mange les lettres, pas l'inverse.
                    .overlay {
                        texte(W: W, ax: ax, p: p, now: now)
                            .allowsHitTesting(false)
                    }
                    .overlay {
                        poudre(now: now)
                            .frame(width: W, height: Self.cielH)
                            .allowsHitTesting(false)
                    }
                    .overlay {
                        fleche(grip: grip, p: p, flash: flash)
                            .position(x: ax, y: height / 2)
                            .allowsHitTesting(false)
                    }
                    .overlay {
                        // LA PRISE : le pouce, et rien d'autre. La piste
                        // n'est pas un tapis à doigt — sinon le moindre
                        // frôlement de la page part en course.
                        Capsule()
                            .fill(Color.clear)
                            .frame(width: medalW + 12, height: medalH + 12)
                            .contentShape(Capsule())
                            .position(x: ax, y: height / 2)
                            .gesture(push(travel: travel))
                    }
                    .onChange(of: now) { _, d in
                        pas(to: d, ax: ax, p: p, travel: travel)
                    }
            }
            // UNE SEULE animation implicite sur `drag`. Deux `withAnimation`
            // sur la même valeur dans le même tour ne jouent RIEN.
            .animation(.spring(response: 0.34, dampingFraction: 0.76),
                       value: drag)
        }
        .frame(height: height)
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.9),
                         trigger: okBeat)
        .accessibilityRepresentation {
            Button(label) {
                guard !dort else { return }
                if validate() { onConfirm() }
            }
        }
        .onAppear { monte = true }
        .onDisappear {
            monte = false
            suspendre()
        }
        .onChange(of: dort) { _, auRepos in
            if auRepos { suspendre() }
        }
    }

    // MARK: La matière — un seul shader

    private func matiere(W: CGFloat, ax: CGFloat, p: CGFloat,
                         grip: CGFloat, flash: Double,
                         now: Date) -> some View {
        // TOUS les scalaires sortis en `let` typés AVANT l'appel : à une
        // douzaine d'uniforms, le type-checker de Swift rend les armes
        // (« unable to type-check this expression in reasonable time »).
        let pad = Float(Self.pad)
        let hw = Float(W + 2 * Self.pad)
        let hh = Float(height + 2 * Self.pad)
        let t = Float(now.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: 900))
        // Le pouce enfle sous le doigt. Il déborde alors la capsule — c'est
        // VOULU, et le shader ne le clippe pas : clippé, il se ferait
        // trancher net à l'arête.
        let zoom = Float(1 + 0.12 * grip)
        let px = Float(ax)
        let pw = Float(medalW / 2) * zoom
        let ph = Float(medalH / 2) * zoom
        let press = Float(grip)
        let h = Float(height)
        let refus = Float(refused ? 1 : 0)
        let fl = Float(flash)
        let br = Float(braise) * Float(p)
        // L'ARMEMENT pousse la lumière SANS toucher à l'arité : il enfle
        // l'amplitude du fil et le pic du liseré de flanc, rien d'autre.
        let a = Float(arme ? 1 : 0)
        let amp = Float(1.42) * (1 + 0.45 * a)
        let pic = Float(0.239) * (1 + 0.55 * a)

        return Rectangle()
            // JAMAIS `.clear` : l'alpha nul de l'hôte avale TOUT le rendu.
            // C'est le shader qui décide de chaque alpha, pas l'hôte.
            .fill(.white)
            .frame(width: CGFloat(hw), height: CGFloat(hh))
            .colorEffect(Self.dithered(ShaderLibrary.sliderObsidienne(
                .float2(hw, hh), .float(t), .float(pad),
                .float4(px, pw, ph, press),
                .float4(Self.repetition, Self.angle,
                        Self.softness, Self.contour),
                .float4(Self.distortion, Self.speed,
                        Self.shiftRed, Self.shiftBlue),
                .float4(Self.influence, Self.gold, Self.lineW, Self.glow),
                .float(Self.floorLevel),
                // voile 10 % en haut, mort à 60 % de la hauteur ; anneau noir
                // 5,6 % ; pic du liseré de flanc à 24 % de blanc.
                .float4(0.100, 0.60, h * 0.056, pic),
                // le liseré vit à 2,9 % de profondeur, demi-largeur 1,9 %,
                // centré 30° AU-DESSUS de l'horizontale, sigma 32°.
                .float4(h * 0.029, h * 0.019, 30, 32),
                // l'ombre : 62 % de noir, étalée sur 26 % de la hauteur.
                // Large et molle — la référence en tient encore un tiers
                // trente points plus bas.
                .float4(0.62, h * 0.26, 0, 0),
                // amplitude du fil : seul sur du noir, il doit porter la
                // forme à lui tout seul.
                .float4(br, refus, fl, amp))))
    }

    /// Le dither de SwiftUI EN PLUS de celui du shader : la matière entière
    /// est faite de dégradés de 2 %, et sur OLED ils bandent atrocement.
    private static func dithered(_ shader: Shader) -> Shader {
        var s = shader
        s.dithersColor = true
        return s
    }

    // MARK: Le texte

    /// « START » en néon blanc. Trois couches, et chacune répond à un
    /// défaut précis :
    ///   — le dégradé vertical : une encre plate se lit imprimée, pas allumée ;
    ///   — LA LAMPE : le pouce éclaire les lettres qu'il approche ;
    ///   — la lueur : le halo court qui décolle les lettres de la pierre.
    ///
    /// LE BALAYAGE EST MORT (verdict Kathryn 21-08 : « j'aime pas l'effet
    /// balayage »). Il avait le défaut de tous les reflets automatiques : il
    /// tourne en rond QUOI QU'ON FASSE, donc il ne dit rien — et une lumière
    /// qui repasse toutes les trois secondes sans raison, c'est un chargement,
    /// pas un bijou. Sa remplaçante est MOTIVÉE : la source de lumière, c'est
    /// le pouce. Il éclaire le mot en s'en approchant, et il le mange en
    /// arrivant dessus. Rien ne bouge tant que le doigt ne bouge pas.
    private func texte(W: CGFloat, ax: CGFloat, p: CGFloat,
                       now: Date) -> some View {
        // Le texte s'éteint sur la fin de course : à l'armement il n'y a plus
        // rien à lire, on ne lit pas ce qu'on est en train de faire.
        let vie = Double(1 - min(1, max(0, (p - 0.35) / 0.35)))
        // MUET AU REPOS (verdict 13-09 : « enlève le texte — il apparaît
        // quand le user commence à slider ») : le mot NAÎT sur les premiers
        // 8 % de course, et meurt comme avant à l'armement. Zéro texte
        // dormant — dans TOUS les écrans qui montent ce composant.
        let naissance = Double(min(1, max(0, p / 0.08)))

        // La casse des boutons (30-08, « pareil dans le switch ») : une phrase,
        // comme le primaire — l'interlettrage des capitales tombe avec elles.
        // LA VOIX DU PRIMAIRE (verdict 13-09 : « même taille de font que
        // les boutons primary, pour consistance ») — le label vivait en
        // système ~10 pt pendant que le primaire parle en Inter 18 semibold.
        let encre = Text(label.enPhrase)
            .font(.inter(18, .semibold))
            .tracking(-0.2)

        // LA LARGEUR UTILE : la course LIBRE, pas la piste. Centré sur la
        // piste, le texte a son premier caractère sous le pouce au repos —
        // on lit son mot amputé de sa première lettre avant d'avoir touché à
        // soit. Il se centre donc entre le bord de fuite du pouce au repos et
        // le bout de la capsule, et il se resserre s'il n'y tient pas.
        // `labelCentre` : le mot se centre sur la PISTE (l'axe de la card), et
        // sa largeur utile se prend alors SYMÉTRIQUEMENT — la même marge des
        // deux côtés, sinon un mot long viendrait mourir sous le pouce.
        let libre = labelCentre
            ? max(W - 2 * (medalW + encart) - 16, 40)
            : max(W - medalW - 2 * encart - 16, 40)
        let centre = labelCentre
            ? W / 2
            : (medalW + encart + (W - encart)) / 2

        return ZStack {
            encre
                .foregroundStyle(LinearGradient(
                    colors: [Color(white: 0.94), Color(white: 0.54)],
                    startPoint: .top, endPoint: .bottom))
                .background {
                    encre.foregroundStyle(.white)
                        .blur(radius: 4)
                        .opacity(0.30)
                        .blendMode(.plusLighter)
                }
                .overlay {
                    // LA LAMPE. Un halo centré sur le pouce, dans le repère du
                    // mot : les lettres qu'il approche s'allument, les autres
                    // restent en veille. Il rayonne sur une fois et demie sa
                    // propre largeur — au-delà, le mot s'allume en entier et
                    // on retombe sur un éclairage plat.
                    GeometryReader { g in
                        RadialGradient(
                            colors: [Color.white.opacity(0.50), .clear],
                            center: UnitPoint(
                                x: (ax - (centre - g.size.width / 2))
                                    / max(g.size.width, 1),
                                y: 0.5),
                            startRadius: 0,
                            endRadius: medalW * 1.5)
                            .blendMode(.plusLighter)
                    }
                    .mask { encre }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(width: libre)
                .position(x: centre, y: height / 2)
        }
        .frame(width: W, height: height)
        .opacity(vie * naissance)
        // LE TROU DU POUCE. Un `Rectangle` moins la capsule, en
        // `destinationOut`, le bord adouci de 4 pt DANS un calque du Canvas —
        // un `.blur` posé sur une forme SwiftUI, lui, déposerait son voile
        // rectangulaire sur tout l'hôte.
        .mask {
            Canvas { ctx, size in
                ctx.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .color(.white))
                ctx.blendMode = .destinationOut
                let trou = CGRect(x: ax - medalW / 2 - 5,
                                  y: size.height / 2 - medalH / 2 - 5,
                                  width: medalW + 10, height: medalH + 10)
                ctx.drawLayer { calque in
                    calque.addFilter(.blur(radius: 4))
                    calque.fill(Path(roundedRect: trou,
                                     cornerRadius: (medalH + 10) / 2),
                                with: .color(.white))
                }
            }
        }
    }

    // MARK: La poudre

    private func poudre(now: Date) -> some View {
        Canvas { ctx, size in
            // Le Canvas est plus haut que la piste pour que rien ne soit
            // décapité — les coordonnées, elles, restent en espace piste.
            ctx.translateBy(x: 0, y: (Self.cielH - height) / 2)
            for d in dusts {
                let age = now.timeIntervalSince(d.born)
                guard age >= 0, age < Self.dustLife else { continue }
                let u = age / Self.dustLife
                let fade = (1 - u) * (1 - u)
                let tw = 0.55 + 0.45 * sin(age * d.freq + d.phase)
                // La profondeur par la TAILLE : les plus petits grains sont
                // les plus lointains — plus sourds, jamais flous.
                let a = fade * tw * (0.52 + 0.48 * Double(min(d.size, 1)))
                let x = d.x + d.vx * CGFloat(1 - exp(-age * 3)) * 18
                let y = d.y - d.rise * CGFloat(u) * 14
                let r = d.size * (0.8 + 0.5 * CGFloat(u))
                let box = CGRect(x: x - r, y: y - r,
                                 width: r * 2, height: r * 2)
                if r < 0.75 {
                    // LE GRAIN À PLAT : sous 0,75 pt (deux pixels), un
                    // dégradé radial ne dessine plus rien qu'un point — et
                    // cent cinquante dégradés par image, si. Le point plat
                    // est le prix de la densité.
                    ctx.fill(Path(ellipseIn: box),
                             with: .color(Color.white.opacity(a * 0.90)))
                } else {
                    ctx.fill(
                        Path(ellipseIn: box),
                        with: .radialGradient(
                            Gradient(colors: [Color.white.opacity(a * 0.95),
                                              Color.white.opacity(a * 0.30),
                                              .clear]),
                            center: CGPoint(x: x, y: y),
                            startRadius: 0, endRadius: r * 2.2))
                }
            }
            for g in gems {
                let age = now.timeIntervalSince(g.born)
                guard age >= 0, age < Self.gemLife else { continue }
                let u = age / Self.gemLife
                let fade = (1 - u) * (1 - u)
                let s = 0.5 + 0.5 * sin(age * g.freq + g.phase)
                let tw = 0.30 + 0.70 * s * s * s
                let a = fade * tw
                let x = g.x + g.vx * CGFloat(1 - exp(-age * 3)) * 16
                let y = g.y - g.rise * CGFloat(u) * 18
                let r = g.ray * (0.85 + 0.35 * CGFloat(u))
                let ice = Color(red: 0.92, green: 0.96, blue: 1.0)
                var star = Path()
                star.move(to: CGPoint(x: -r, y: 0))
                star.addLine(to: CGPoint(x: 0, y: -r * 0.13))
                star.addLine(to: CGPoint(x: r, y: 0))
                star.addLine(to: CGPoint(x: 0, y: r * 0.13))
                star.closeSubpath()
                star.move(to: CGPoint(x: 0, y: -r))
                star.addLine(to: CGPoint(x: r * 0.13, y: 0))
                star.addLine(to: CGPoint(x: 0, y: r))
                star.addLine(to: CGPoint(x: -r * 0.13, y: 0))
                star.closeSubpath()
                let placed = star.applying(
                    CGAffineTransform(translationX: x, y: y)
                        .rotated(by: g.tilt))
                ctx.fill(placed, with: .color(ice.opacity(a * 0.85)))
                ctx.fill(
                    Path(ellipseIn: CGRect(x: x - 0.8, y: y - 0.8,
                                           width: 1.6, height: 1.6)),
                    with: .color(Color.white.opacity(a * 0.95)))
            }
        }
        // Pas de blend mode : les grains sont blancs sur du noir, le
        // par-dessus rend la même lumière — et un `plusLighter` ici forcerait
        // un groupe de composition qui se voit sous un panneau de verre.
        .allowsHitTesting(false)
    }

    // MARK: La flèche

    /// Tracée à la main, pas `arrow.right` : relevée sur la référence, la tête
    /// est BEAUCOUP plus ouverte que celle de SF Symbols — branches à 38° de
    /// l'horizontale, et une hauteur totale égale à la largeur.
    ///
    /// Elle BLANCHIT avec la course : grise au repos, blanc franc à l'arrivée.
    /// C'est le seul indicateur de progression du composant — il n'y a ni
    /// jauge, ni compteur, ni remplissage de piste.
    private func fleche(grip: CGFloat, p: CGFloat, flash: Double) -> some View {
        let cote = medalH * 0.522
        let trait = medalH * 0.049
        let encre = 0.31 + 0.62 * Double(p) + 0.20 * flash
        // La lueur du commit est BRIDÉE : à pleine dose, le halo flouté de la
        // flèche l'efface elle-même — au pic on voyait une tache blanche à la
        // place du glyphe. Une flèche qui disparaît au moment où elle
        // triomphe, c'est le contraire de ce qu'on raconte.
        let lueur = min(0.72, 0.45 * Double(p) * Double(p) + 0.28 * flash)
        // LE GLYPHE QUI REFROIDIT. Au lâcher il est BLANC CHAUD, puis il
        // descend l'échelle d'une braise — or, orange, rouge sombre — avant de
        // revenir au gris de repos. Du métal qui a pris le coup, pas une
        // couleur qui clignote : la teinte suit la RETOMBÉE du flash, elle ne
        // peut donc pas se désynchroniser de lui.
        //
        // Le POIDS, lui, ne lâche qu'à la toute fin (0,12) : relâché en même
        // temps que la teinte, le rouge n'a pas le temps d'exister et on ne
        // voit qu'un blanc qui pâlit. C'est la fin de la rampe qui porte tout
        // le registre braise de l'app — celui du BRAVO et du booster.
        let feu = Self.braise(1 - flash)
        let dose = min(1, flash / 0.12)
        let couleur = Color(red: 1 - (1 - feu.0) * dose,
                            green: 1 - (1 - feu.1) * dose,
                            blue: 1 - (1 - feu.2) * dose)
        let dessin = Path { pth in
            let c = cote / 2
            let tip = CGPoint(x: cote, y: c)
            pth.move(to: CGPoint(x: 0, y: c))
            pth.addLine(to: tip)
            // 38° : dy = 0,78 × dx. La branche couvre 64 % de la largeur.
            let dx = cote * 0.64
            pth.move(to: CGPoint(x: cote - dx, y: c - dx * 0.78))
            pth.addLine(to: tip)
            pth.addLine(to: CGPoint(x: cote - dx, y: c + dx * 0.78))
        }
        let style = StrokeStyle(lineWidth: trait,
                                lineCap: .round, lineJoin: .round)
        return dessin
            .stroke(couleur.opacity(min(1, encre)), style: style)
            // La lueur n'EXISTE PAS au repos : elle naît avec la course. Un
            // halo permanent ferait de la flèche une lampe témoin.
            .background {
                dessin
                    .stroke(couleur, style: style)
                    .blur(radius: 5)
                    .opacity(lueur)
                    .blendMode(.plusLighter)
            }
            .frame(width: cote, height: cote)
            // Le grossissement : la nav bar le fait à la main elle aussi.
            // Ressort à amortissement BAS — le relâchement DÉPASSE avant de
            // se poser.
            .scaleEffect(1 + 0.22 * grip)
            .animation(.spring(response: 0.30, dampingFraction: 0.55),
                       value: grip)
    }

    /// L'ÉCHELLE D'UNE BRAISE, en trois segments : blanc chaud → or → orange →
    /// rouge sombre. C'est la rampe de `SetEntrySheet.fire`, et elle vaut ici
    /// pour la même raison : une interpolation directe du blanc au rouge passe
    /// par du ROSE, qui n'existe nulle part dans un métal qui refroidit.
    /// Jamais de violet — il n'y en a pas dans l'app.
    private static func braise(_ u: Double) -> (Double, Double, Double) {
        let k = min(max(u, 0), 1)
        if k < 0.34 {
            let t = k / 0.34
            return (1.0, 1.0 - 0.14 * t, 1.0 - 0.45 * t)
        } else if k < 0.68 {
            let t = (k - 0.34) / 0.34
            return (1.0, 0.86 - 0.31 * t, 0.55 - 0.35 * t)
        } else {
            let t = (k - 0.68) / 0.32
            return (1.0 - 0.10 * t, 0.55 - 0.33 * t, 0.20 - 0.08 * t)
        }
    }

    // MARK: La rampe de prise

    /// 0,13 s à la montée, 0,30 s à la retombée — la courbe de la nav bar.
    ///
    /// LE CHIEN DE GARDE : un `DragGesture` volé par un parent (un panneau
    /// tirable, un `ScrollView`) n'appelle JAMAIS `onEnded`, et le pouce
    /// resterait gonflé pour toujours. On ne peut pas corriger l'état pendant
    /// le rendu — on lit donc la PÉREMPTION au lieu de l'écrire.
    private static let stale: TimeInterval = 0.18

    private func vivant(at date: Date) -> Bool {
        dragging && date.timeIntervalSince(lastTouch) < Self.stale
    }

    private func gripLevel(at date: Date) -> CGFloat {
        if vivant(at: date), let s = gripStart {
            return min(1, CGFloat(date.timeIntervalSince(s) / 0.13))
        }
        if dragging {
            let dt = date.timeIntervalSince(lastTouch) - Self.stale
            return max(0, 1 - CGFloat(dt / 0.30))
        }
        if let e = gripEnd {
            let dt = date.timeIntervalSince(e.date)
            return max(0, e.level * (1 - CGFloat(dt / 0.30)))
        }
        return 0
    }

    // MARK: Le pas de temps — TOUT état s'écrit ici, jamais dans le rendu

    private func pas(to d: Date, ax: CGFloat, p: CGFloat, travel: CGFloat) {
        // Le changement de porte peut encore livrer la dernière date du
        // Timeline : aucun pas de banc, son ou mood après la suspension.
        guard !dort else { return }
        if auto { cycleAuto(at: d, ax: ax) }

        // La poudre est semée par le DÉPLACEMENT du pouce, pas par le doigt :
        // le ressort du commit sème donc lui aussi, et le retour en arrière
        // ne sème rien — la poudre tombe derrière, elle ne précède jamais.
        if let last = lastAx, ax > last, !reduceMotion,
           (dragging || auto || d.timeIntervalSince(flashAt) < 0.35) {
            semer(at: ax, vitesse: (ax - last) * 60,
                  niveau: Double(min(max(p, 0), 1)))
        }
        lastAx = ax

        // Le ménage : on ne garde en mémoire que ce qui est encore en vol.
        dusts.removeAll { d.timeIntervalSince($0.born) > Self.dustLife }
        gems.removeAll { d.timeIntervalSince($0.born) > Self.gemLife }

        onMood(dragging || auto ? p : (drag > 0 ? p : 0))
    }

    /// LE CYCLE DU BANC : repos, poussée, tenue, commit, retour. 5,2 s.
    private func cycleAuto(at d: Date, ax: CGFloat) {
        let start = autoStart ?? {
            autoStart = d
            return d
        }()
        let u = d.timeIntervalSince(start)
            .truncatingRemainder(dividingBy: 5.2)
        switch u {
        case ..<0.35:
            autoP = 0; autoGrip = 0; arme = false
        case ..<2.15:
            let k = (u - 0.35) / 1.80
            autoP = CGFloat(k * k * (3 - 2 * k))
            autoGrip = min(1, CGFloat((u - 0.35) / 0.13))
        case ..<2.55:
            autoP = 1; autoGrip = 1
            if !arme { arme = true }
        case ..<3.05:
            autoP = 1
            autoGrip = max(0, 1 - CGFloat((u - 2.55) / 0.30))
            if d.timeIntervalSince(flashAt) > 1.0 {
                flashAt = d
                okBeat += 1
                CommitHaptic.play()
                Paillettes.shared.announce(after: 0.03)
                gerbe(at: ax)
            }
        case ..<3.45:
            let k = (u - 3.05) / 0.40
            autoP = CGFloat(1 - k * k * (3 - 2 * k))
            autoGrip = 0; arme = false
        default:
            autoP = 0; autoGrip = 0; arme = false
        }
    }

    // MARK: Semer

    private func semer(at x: CGFloat, vitesse vx: CGFloat, niveau: Double) {
        // LE BRUIT : du cristal semé à la distance, hauteur et densité qui
        // montent avec la course. `Paillettes` se nourrit de chaque
        // déplacement, AVANT tout seuil de poussière.
        if let ls = lastSoundX {
            Paillettes.shared.travel(abs(x - ls), level: niveau)
        }
        lastSoundX = x
        // À LA DISTANCE, jamais au temps : un doigt arrêté ne sème rien.
        if let last = lastDustX, abs(x - last) < 2.5 { return }
        lastDustX = x
        // DE LA POUDRE, PAS DES CONFETTIS : cinq à neuf grains par pas de
        // 2,5 pt, de 0,3 à 1 pt. Plus dense que celle du médaillon — là-bas
        // elle accompagne un feu, ici elle est le SEUL événement de la piste.
        // Ils naissent au bord de FUITE du pouce : la capsule fait 78 pt de
        // large, les grains du médaillon (nés à 4 pt du centre) naîtraient
        // ici SOUS le verre.
        let bord = medalW / 2
        let n = Int.random(in: 5...9)
        for _ in 0..<n {
            dusts.append(Dust(
                born: .now,
                x: x - bord - CGFloat.random(in: 0...30),
                y: height / 2 + CGFloat.random(in: -14...14),
                vx: -max(vx, 0) / 900 - CGFloat.random(in: 0.2...1.0),
                rise: CGFloat.random(in: 0.4...1.3),
                size: CGFloat.random(in: 0.30...1.00),
                freq: Double.random(in: 9...24),
                phase: Double.random(in: 0...(2 * .pi))))
        }
        if dusts.count > 220 { dusts.removeFirst(dusts.count - 220) }
        // Les pierres : une par ~12 pt de course — plus rares que la poudre,
        // sinon elles ne sont plus des pierres.
        guard diamants else { return }
        if lastGemX.map({ abs(x - $0) >= 12 }) ?? true {
            lastGemX = x
            gems.append(Diamond(
                born: .now,
                x: x - bord - CGFloat.random(in: 0...26),
                y: height / 2 + CGFloat.random(in: -15...15),
                vx: -CGFloat.random(in: 0.2...0.7),
                rise: CGFloat.random(in: 0.5...1.1),
                ray: CGFloat.random(in: 1.4...2.6),
                freq: Double.random(in: 14...30),
                phase: Double.random(in: 0...(2 * .pi)),
                tilt: Double.random(in: -0.5...0.5)))
            if gems.count > 28 { gems.removeFirst(gems.count - 28) }
        }
    }

    /// LA GERBE DU COMMIT : d'un coup, quarante grains, deux fois plus vifs
    /// et lancés plus loin. Le filet du geste devient une décharge — c'est ce
    /// contraste de DÉBIT qui dit « c'est parti », pas la couleur.
    private func gerbe(at x: CGFloat) {
        guard !reduceMotion else { return }
        let bord = medalW / 2
        for _ in 0..<60 {
            dusts.append(Dust(
                born: .now,
                x: x - bord * CGFloat.random(in: 0.2...1.0)
                    - CGFloat.random(in: 0...44),
                y: height / 2 + CGFloat.random(in: -20...20),
                vx: -CGFloat.random(in: 0.8...3.2),
                rise: CGFloat.random(in: 0.8...2.4),
                size: CGFloat.random(in: 0.30...1.20),
                freq: Double.random(in: 9...26),
                phase: Double.random(in: 0...(2 * .pi))))
        }
        if dusts.count > 280 { dusts.removeFirst(dusts.count - 280) }
    }

    // MARK: Le geste

    /// Un geste interrompu par le changement d'onglet ou de scène ne se
    /// valide jamais au retour. Seuls ses états visuels sont remis à zéro.
    private func suspendre() {
        retourTask?.cancel()
        retourTask = nil
        if dragging {
            RocketHaptics.shared.dragEnd()
            Paillettes.shared.end()
        }
        let moodActif = dragging || drag != 0 || autoP != 0
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            drag = 0
            dragging = false
            refused = false
            arme = false
            lastCran = 0
            flashAt = .distantPast
            gripStart = nil
            gripEnd = nil
            lastTouch = .distantPast
            lastAx = nil
            lastDustX = nil
            lastGemX = nil
            lastSoundX = nil
            dusts.removeAll()
            gems.removeAll()
            autoStart = nil
            autoP = 0
            autoGrip = 0
            if moodActif { onMood(0) }
        }
    }

    private func push(travel: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { v in
                guard !dort, !refused else { return }
                lastTouch = .now
                if !dragging {
                    dragging = true
                    gripStart = .now
                    lastCran = 0
                    lastAx = nil
                    CranHaptique.prepare()
                    UIImpactFeedbackGenerator(style: .soft)
                        .impactOccurred(intensity: 0.5)
                }
                drag = min(max(v.translation.width, 0), travel)
                let niveau = Double(min(max(drag / travel, 0), 1))
                guard !reduceMotion else { return }
                RocketHaptics.shared.dragLevel(niveau)
                // LES CRANS SE RESSERRENT *ET* DURCISSENT. Trente crans
                // répartis en `16n + 14n³` : seize au début, plus du double
                // de densité sur le dernier tiers. Et chacun tape plus fort
                // que le précédent — `CranHaptique` change de générateur en
                // route (doux → moyen → rigide) au lieu du `selectionChanged`
                // de la molette, qui a UNE seule force et ne raconte donc
                // aucune montée. C'est la main qui doit savoir qu'on approche
                // du bout, avant les yeux.
                let cran = Int(16 * niveau + 14 * pow(niveau, 3))
                if cran != lastCran {
                    lastCran = cran
                    CranHaptique.play(niveau)
                }
                // L'ARMEMENT — réversible, et il se sent des deux côtés.
                let franchi = CGFloat(niveau) > Self.seuil
                if franchi != arme {
                    arme = franchi
                    // Le coup le plus dur de toute la course AVANT le commit :
                    // c'est le seul instant où la main doit comprendre sans
                    // regarder qu'elle peut lâcher.
                    UIImpactFeedbackGenerator(style: .rigid)
                        .impactOccurred(intensity: franchi ? 1.0 : 0.40)
                }
            }
            .onEnded { _ in
                guard !dort, dragging else { return }
                let atteint = gripLevel(at: .now)
                dragging = false
                gripStart = nil
                gripEnd = (date: .now, level: atteint)
                lastDustX = nil
                lastGemX = nil
                lastSoundX = nil
                RocketHaptics.shared.dragEnd()
                Paillettes.shared.end()
                guard !refused else { return }
                guard drag > travel * Self.seuil else {
                    arme = false
                    drag = 0
                    return
                }
                guard validate() else {
                    refuse()
                    return
                }
                okBeat += 1
                flashAt = .now
                CommitHaptic.play()
                // L'arpège, collé au flash à la frame près.
                Paillettes.shared.announce(after: 0.03)
                gerbe(at: axPad + travel)
                drag = travel
                onConfirm()
                retourTask?.cancel()
                retourTask = Task { @MainActor in
                    do { try await Task.sleep(for: .seconds(0.45)) }
                    catch { return }
                    guard !Task.isCancelled, !dort else { return }
                    arme = false
                    drag = 0
                }
            }
    }

    /// LE REFUS. Il se voit (grenat), il se sent (deux coups secs), et il
    /// RENVOIE — le mood retombe SEC avec lui : on ne joue pas quand on refuse.
    private func refuse() {
        refused = true
        arme = false
        RefusalHaptic.play()
        drag = 0
        onMood(0)
        retourTask?.cancel()
        retourTask = Task { @MainActor in
            do { try await Task.sleep(for: .seconds(0.42)) }
            catch { return }
            guard !Task.isCancelled, !dort else { return }
            refused = false
        }
    }
}

// MARK: - Les crans de la course

/// LA MONTÉE DANS LA MAIN. Le `UISelectionFeedbackGenerator` de la molette
/// n'a qu'UNE force : trente de ses crans font trente fois le même clic, et
/// une graduation qui ne change pas ne dit pas qu'on approche. Ici la force
/// monte deux fois — en INTENSITÉ (0,28 → 1,00, continu) et en MATIÈRE (le
/// générateur lui-même passe de `.soft` à `.medium` puis `.rigid`). C'est le
/// changement de matière qui porte : l'intensité seule s'entend comme « plus
/// fort », le passage au rigide s'entend comme « ça se verrouille ».
///
/// Les trois générateurs sont gardés vivants et préparés : en fabriquer un
/// par cran coûte un allumage du moteur à chaque coup, et les premiers
/// arrivent en retard — la traînée haptique se lit alors en pointillés.
@MainActor
enum CranHaptique {
    private static let doux = UIImpactFeedbackGenerator(style: .soft)
    private static let moyen = UIImpactFeedbackGenerator(style: .medium)
    private static let dur = UIImpactFeedbackGenerator(style: .rigid)

    static func prepare() {
        doux.prepare(); moyen.prepare(); dur.prepare()
    }

    static func play(_ niveau: Double) {
        let n = min(max(niveau, 0), 1)
        let force = 0.28 + 0.72 * n
        switch n {
        case ..<0.42: doux.impactOccurred(intensity: force)
        case ..<0.74: moyen.impactOccurred(intensity: force)
        default: dur.impactOccurred(intensity: force)
        }
    }
}
