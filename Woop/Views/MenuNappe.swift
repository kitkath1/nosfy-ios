import SwiftUI

// MARK: - LE GALET ET LES HALOS (chantier A, plan § 13)
//
// Un seul bouton en bas à gauche, et le bas de l'écran qui s'allume en
// halos quand on le touche. Pas de barre, pas de sheet, pas de feuille.
//
// TROIS LOIS, chacune payée par un verdict :
//
//  1. **UN HALO N'A PAS DE BORD — UNE FEUILLE EN A FORCÉMENT UN.** Deux
//     jets se sont perdus à faire une feuille de verre : fondue au masque
//     elle devient un frost (« pourquoi t'as mis du blur ? »), gardée nette
//     elle devient une boîte grise posée sur l'écran (« non, horrible »).
//     Si le dessin demande « fondu », l'objet ne peut pas être une surface.
//  2. **LES HALOS SONT LUMINEUX.** « Halo fondu noir » voulait dire : des
//     halos, sur un fond qui COMMENCE fondu en noir. Un halo noir est une
//     ombre, et une ombre sur du noir ne se voit pas (« que du full noir »).
//  3. **LE FOND NE RECULE PAS, LE CONTENU RECULE.** Un `scaleEffect` sur la
//     card vidéo transforme un `AVPlayerLayer` — une couche UIKit qui
//     n'interpole PAS dans la transaction SwiftUI et recalcule son cadrage
//     `resizeAspectFill` à chaque bounds. Elle SAUTE au lieu de glisser, et
//     comme elle prend tout l'écran, c'est tout l'écran qui semble décaler
//     (« une sorte de décalage de tout l'écran »). La vidéo est le monde :
//     elle reste. C'est le mobilier qui s'éloigne.
//
// Et la chorégraphie tient à **UN SEUL CURSEUR**, jamais à une chaîne de
// minuteurs : chaque réveil d'`asyncAfter` est une MARCHE, et quatre
// animations qui démarrent chacune de son côté ne peuvent pas couler.
//
// Bancs : `-menuLab`, `-menuRejoue` (l'ouverture en boucle).

// MARK: - Le glyphe

/// LA MAISON QUI DEVIENT UN CHEVRON — un vrai MORPHISME, pas un fondu
/// croisé. Le toit de la maison EST déjà un chevron à l'envers : il suffit
/// de le retourner et de laisser le corps se rétracter dans sa pointe.
/// `p` = 0 la maison, 1 le chevron.
struct GlypheMaison: Shape {
    var p: Double = 0

    var animatableData: Double {
        get { p }
        set { p = newValue }
    }

    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height, x = r.minX, y = r.minY
        func pt(_ a: Double, _ b: Double) -> CGPoint {
            CGPoint(x: x + a * w, y: y + b * h)
        }
        func mix(_ a: Double, _ b: Double) -> Double { a + (b - a) * p }
        var path = Path()
        // LE TOIT se retourne : la pointe descend, les deux bas montent.
        path.move(to: pt(mix(0.04, 0.16), mix(0.47, 0.36)))
        path.addLine(to: pt(0.50, mix(0.07, 0.68)))
        path.addLine(to: pt(mix(0.96, 0.84), mix(0.47, 0.36)))
        // LE CORPS se rétracte DANS la pointe : ses quatre points
        // convergent, il disparaît sans s'effacer.
        if p < 0.97 {
            path.move(to: pt(mix(0.155, 0.50), mix(0.415, 0.66)))
            path.addLine(to: pt(mix(0.155, 0.50), mix(0.930, 0.68)))
            path.addLine(to: pt(mix(0.845, 0.50), mix(0.930, 0.68)))
            path.addLine(to: pt(mix(0.845, 0.50), mix(0.415, 0.66)))
        }
        return path
    }
}

/// Le néon blanc : cœur blanc pur, tube, halo COURT. La recette de
/// `NeonPrimaryButton` en blanc — au-delà de 10 pt de portée, un halo
/// devient du néon de bar.
private struct NeonMaison: View {
    var taille: CGFloat
    var morph: Double
    /// 0 → 1 : la pose du doigt monte le néon AVANT même le tap.
    var feu: Double

    var body: some View {
        GlypheMaison(p: morph)
            .stroke(Color(white: 1.0),
                    style: StrokeStyle(lineWidth: taille * 0.085,
                                       lineCap: .round, lineJoin: .round))
            .shadow(color: .white.opacity(0.90), radius: taille * 0.045)
            .shadow(color: .white.opacity(0.52 + 0.32 * feu),
                    radius: taille * 0.16)
            .shadow(color: .white.opacity(0.18 + 0.26 * feu),
                    radius: taille * 0.34)
            .frame(width: taille, height: taille)
    }
}

// MARK: - Le galet

/// Le bouton du menu : un disque de VERRE NATIF, l'encre au-dessus du
/// conteneur. **Quatre états et non deux** — au repos il RESPIRE, au doigt
/// POSÉ il se creuse et son néon monte (on sent qu'il a compris avant qu'on
/// lâche), à l'ouverture il MORPHE, et une ONDE part de lui.
struct GaletMaison: View {
    var taille: CGFloat = 62
    /// 0 = maison, 1 = chevron.
    var morph: Double = 0
    var appui: Bool = false
    /// LE FEU QUI SURVIT AU DOIGT. Le néon monte à la pose (`appui`), mais il
    /// doit rester allumé PENDANT LA CHUTE : au milieu de l'écran, le verre
    /// natif n'a rien à réfracter (la loi du verre à jeun, p95 = 23) et le
    /// galet s'efface littéralement — vérifié à la capture. C'est son néon,
    /// et lui seul, qui le porte de la main jusqu'au sol.
    var feuSup: Double = 0
    /// RANGÉ SUR LE FLANC. Le galet quitte le rond pour une NAVETTE
    /// allongée, dont la moitié sort de l'écran : il ne reste qu'un bout de
    /// verre sur le bord, et c'est par ce bout qu'on le retire.
    var range: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Le nom du verre pour le MORPHISME natif : c'est `glassEffectID` qui
    /// autorise ici un changement de bounds. Sans lui, la loi tient — un
    /// `glassEffect` redimensionné reste flou plat pour toujours.
    @Namespace private var verre

    private var largeur: CGFloat { range ? 26 : taille }
    private var hauteur: CGFloat { range ? 84 : taille }

    /// LA NAVETTE RANGÉE — et deux verdicts dedans (« c'est trop noir » +
    /// « il faut un petit signal trait blanc léger, on peut tirer dessus »).
    ///
    /// Elle était un TROU : `.clear` posé sur la partie sombre de la page n'a
    /// rien à réfracter (la loi du verre à jeun, p95 = 23) et ne rend donc
    /// qu'un creux noir. Trois pièces la rendent, et aucune n'est un « lait » —
    /// un voile blanc uniforme est la signature d'un frost, pas d'un verre :
    ///
    ///   • **L'ARÊTE.** Le Liquid Glass se lit par ses BORDS : un cheveu
    ///     spéculaire sur le contour, vif au milieu et mort aux deux pointes.
    ///     C'est lui, et lui seul, qui dit « verre » plutôt que « trou ».
    ///   • **LE SOUFFLE DE CLARTÉ**, très bas (7 %), plus clair en haut :
    ///     assez pour que la navette ne soit plus un manque, trop peu pour
    ///     blanchir.
    ///   • **LA POIGNÉE.** Un trait blanc de 2,5 × 20, posé dans la MOITIÉ
    ///     VISIBLE (la navette est centrée sur l'arête de l'écran : seule sa
    ///     droite existe). C'est l'invite — la grammaire de la barre d'accueil
    ///     d'iOS, verticale. Elle respire avec le galet, elle ne clignote pas.
    ///
    /// ⚠️ Tout ceci vit AU-DESSUS du conteneur de verre : dedans, ce serait
    /// lentillé (le chiffre-trou-dans-du-métal du galet de l'objectif).
    @ViewBuilder
    private var navette: some View {
        ZStack {
            Capsule()
                .fill(LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.105), location: 0.00),
                        .init(color: .white.opacity(0.045), location: 0.45),
                        .init(color: .white.opacity(0.075), location: 1.00),
                    ],
                    startPoint: .top, endPoint: .bottom))
            Capsule()
                .stroke(LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.00), location: 0.00),
                        .init(color: .white.opacity(0.40), location: 0.26),
                        .init(color: .white.opacity(0.62), location: 0.55),
                        .init(color: .white.opacity(0.28), location: 0.80),
                        .init(color: .white.opacity(0.00), location: 1.00),
                    ],
                    startPoint: .top, endPoint: .bottom),
                    lineWidth: 0.9)
            Capsule()
                .fill(Color.white.opacity(0.74))
                .frame(width: 2.5, height: 20)
                .offset(x: 6)
                .shadow(color: .white.opacity(0.45), radius: 2.5)
        }
        .frame(width: largeur, height: hauteur)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let souffle = reduceMotion ? 1.0
                : 1 + 0.02 * sin(t * 2 * .pi / 4.3)
            ZStack {
                // ⚠️ PLUS D'ANNEAU. Un cercle qui s'étale d'un bouton est un
                // *ripple* — la signature de Material Design, et c'est
                // exactement ce qui sonnait cheap. Chez Apple un bouton ne
                // PROJETTE rien : il se comprime, et c'est LA SCÈNE qui
                // répond (ici l'allumage directionnel des halos).
                // LE VERRE, seul dans son conteneur. Rond quand il est de
                // service, NAVETTE quand il est rangé — et c'est le même
                // verre qui se déforme, pas deux objets qui se remplacent.
                GlassEffectContainer(spacing: 0) {
                    Color.clear
                        .frame(width: largeur, height: hauteur)
                        .glassEffect(.clear.interactive(),
                                     in: range ? AnyShape(Capsule())
                                               : AnyShape(Circle()))
                        .glassEffectID("galet", in: verre)
                }
                // L'ENCRE, au-dessus du conteneur. ⚠️ Le verre natif IGNORE
                // `.opacity` — mais l'encre, elle, se DÉMONTE : rangé, le
                // galet n'est plus un bouton, c'est une poignée.
                if range {
                    navette
                } else {
                    NeonMaison(taille: taille * 0.40, morph: morph,
                               feu: max(appui ? 1 : 0, feuSup))
                }
            }
            .scaleEffect((appui ? 0.94 : 1) * souffle)
            // Un amortissement BAS : la compression est franche, et le
            // relâchement DÉPASSE (≈ 1,02) avant de se poser. Un bouton qui
            // revient sec se sent bon marché.
            .animation(.spring(response: 0.30, dampingFraction: 0.55),
                       value: appui)
        }
        .frame(width: taille, height: taille)
    }
}

// MARK: - Les halos

/// LE FOND DU MENU — deux couches, et **les halos sont LUMINEUX**.
///
///   1. LA NUIT QUI COMMENCE FONDUE : un noir qui naît de rien en haut de
///      la zone et se densifie en descendant. Il porte la lisibilité, et
///      son bord haut n'existe pas.
///   2. LES HALOS PAR-DESSUS, EN LUMIÈRE AJOUTÉE : quatre foyers chauds de
///      grand rayon, posés bas, qui RESPIRENT sur des périodes premières
///      entre elles (sinon elles battent ensemble et ça pulse).
///
/// La rampe de couleur s'écrit EN CANAUX (le bleu s'éteint d'abord, puis le
/// vert) : une interpolation entre deux teintes passerait par un orange
/// désaturé — c'est-à-dire du BRUN, la faute payée au jalon 1 du rasant.
struct MenuHalos: View {
    var p: Double
    /// La place du doigt (fractions de l'écran) : le foyer le plus proche
    /// gagne 12 %, et TOUS se décalent un peu vers lui. La lumière suit la
    /// main.
    var doigt: CGPoint?

    /// LE GALET, d'où part la lumière. Les foyers s'allument DANS L'ORDRE DE
    /// LEUR DISTANCE À LUI : on ne voit pas un anneau partir, on voit la
    /// lumière se propager depuis la main. C'est la même loi que l'arrivée
    /// de la home — la pièce s'allume avant que les mots n'existent.
    static let galet = CGPoint(x: 0.09, y: 0.96)
    /// Le rang d'allumage d'un foyer (0 = le plus proche du galet).
    static let ordre: [Int] = {
        let d = foyers.enumerated().map { i, f -> (Int, Double) in
            let dx = f.x - galet.x, dy = f.y - galet.y
            return (i, dx * dx + dy * dy)
        }.sorted { $0.1 < $1.1 }.map(\.0)
        var r = [Int](repeating: 0, count: foyers.count)
        for (rang, i) in d.enumerated() { r[i] = rang }
        return r
    }()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let foyers: [(x: Double, y: Double, r: Double,
                         c: (Double, Double, Double),
                         f: Double, T: Double)] = [
        (0.30, 1.02, 0.82, (1.00, 0.62, 0.24), 0.78, 13.0),
        (0.72, 1.06, 0.66, (1.00, 0.46, 0.14), 0.60, 17.0),
        (0.50, 1.12, 0.44, (1.00, 0.88, 0.66), 0.48, 23.0),
        (0.06, 0.96, 0.48, (1.00, 0.52, 0.18), 0.38, 29.0),
    ]

    /// 1 si le doigt est sur ce foyer, 0 s'il est loin — gaussienne courte.
    private func proche(_ i: Int) -> Double {
        guard let d = doigt else { return 0 }
        let f = Self.foyers[i]
        let dx = d.x - f.x, dy = (d.y - f.y) * 0.6
        return exp(-(dx * dx + dy * dy) / 0.10)
    }

    /// Le décalage des foyers vers le doigt : 6 pt, pas plus. Une lumière
    /// qui suit la main de trop loin devient un objet qui la poursuit.
    private func decalage(_ taille: CGSize) -> CGSize {
        guard let d = doigt, !reduceMotion else { return .zero }
        return CGSize(width: (d.x - 0.5) * 6 / taille.width,
                      height: (d.y - 0.8) * 6 / taille.height)
    }

    var body: some View {
        GeometryReader { g in
            let W = g.size.width, H = g.size.height
            TimelineView(.animation(minimumInterval: 1.0 / 24)) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                ZStack {
                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0.00), location: 0.00),
                            .init(color: .black.opacity(0.30), location: 0.34),
                            .init(color: .black.opacity(0.50), location: 0.68),
                            .init(color: .black.opacity(0.62), location: 1.00),
                        ],
                        startPoint: .top, endPoint: .bottom)
                        .frame(height: H * 0.62)
                        .frame(maxHeight: .infinity, alignment: .bottom)

                    ZStack {
                        ForEach(0..<Self.foyers.count, id: \.self) { i in
                            let f = Self.foyers[i]
                            let s = reduceMotion ? 1.0
                                : 1 + 0.10 * sin(t * 2 * .pi / f.T)
                            // L'ALLUMAGE : chaque foyer a sa fenêtre sur
                            // `p`, calée sur sa distance au galet.
                            let rang = Double(Self.ordre[i])
                            let dep = rang * 0.16
                            let all = min(max((p - dep) / (1 - dep), 0), 1)
                            let force = f.f * s * all * (1 + 0.12 * proche(i))
                            // la parallaxe : tous se décalent vers la main
                            let par = decalage(g.size)
                            RadialGradient(
                                stops: [
                                    .init(color: Color(red: f.c.0,
                                                       green: f.c.1,
                                                       blue: f.c.2)
                                        .opacity(force), location: 0.00),
                                    .init(color: Color(red: f.c.0,
                                                       green: f.c.1 * 0.72,
                                                       blue: f.c.2 * 0.42)
                                        .opacity(force * 0.38), location: 0.46),
                                    .init(color: .clear, location: 1.00),
                                ],
                                center: UnitPoint(x: f.x + par.width,
                                                  y: f.y + par.height),
                                startRadius: 0, endRadius: W * f.r)
                        }
                    }
                    .blendMode(.plusLighter)
                    .compositingGroup()
                }
            }
            .frame(width: W, height: H)
            // Ils MONTENT à peine : c'est leur densité qui fait la montée,
            // pas leur position. Un halo qui voyage est un objet.
            .offset(y: 24 * (1 - p))
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - La pastille KD

/// LE ROND KD DU PROFIL — le médaillon de la page exo, en NOIR.
///
/// La recette du liseré vient de `FlammeJauge` (l'anneau du médaillon, calé au
/// pixel sur la référence en août) et sa loi est contre-intuitive :
///
/// > **UN LISERÉ N'EST PAS UN ARC CONTINU.** Sur la référence, la chromie
/// > médiane du tour vaut +0,10 — il est NEUTRE — et il fait QUATRE événements
/// > séparés (bas-droite, haut-droite, bas-gauche, et la « bague » en
/// > haut-gauche, la plus vive). Un anneau d'intensité constante lit
/// > « bordure » ; quatre éclats séparés lisent « métal poli ».
///
/// Le bol est noir mais PAS plat : il s'éclaircit à peine sous le milieu (la
/// lumière de la page vient d'en bas, comme la nappe de flamme de la vidéo), et
/// l'ombre portée le DÉCOLLE — sans elle, un rond noir sur du noir n'existe pas.
struct PastilleKD: View {
    var taille: CGFloat = 34

    var body: some View {
        ZStack {
            // LE BOL. Un noir qui monte à peine vers le bas-droite : un aplat
            // parfait est un trou, un bol est un objet.
            Circle()
                .fill(RadialGradient(
                    stops: [
                        // Mesuré à la capture : à 0,130 au cœur le bol tirait
                        // vers le GRIS sur la nappe de flamme. Il faut un noir
                        // qui ne s'éclaire qu'à peine — c'est le liseré qui
                        // porte la lumière, jamais le fond.
                        .init(color: Color(white: 0.098), location: 0.00),
                        .init(color: Color(white: 0.068), location: 0.42),
                        .init(color: Color(white: 0.034), location: 0.74),
                        .init(color: Color(white: 0.016), location: 1.00),
                    ],
                    center: UnitPoint(x: 0.516, y: 0.585),
                    startRadius: 0, endRadius: taille * 0.85))

            // LE LISERÉ — quatre éclats, neutres, sur un cheveu de 0,9 pt à
            // 34 pt de diamètre (il suit la taille pour rester un CHEVEU).
            Circle()
                .strokeBorder(AngularGradient(
                    stops: [
                        .init(color: .white.opacity(0.10), location: 0.000),
                        .init(color: .white.opacity(0.46), location: 0.098),
                        .init(color: .white.opacity(0.14), location: 0.180),
                        .init(color: .white.opacity(0.10), location: 0.280),
                        .init(color: .white.opacity(0.62), location: 0.430),
                        .init(color: .white.opacity(0.30), location: 0.500),
                        .init(color: .white.opacity(0.86), location: 0.580),
                        .init(color: .white.opacity(0.20), location: 0.660),
                        .init(color: .white.opacity(0.10), location: 0.790),
                        .init(color: .white.opacity(0.44), location: 0.882),
                        .init(color: .white.opacity(0.10), location: 0.960),
                        .init(color: .white.opacity(0.10), location: 1.000),
                    ],
                    center: .center, angle: .zero),
                    lineWidth: max(taille / 38, 0.8))

            // L'ENCRE : blanc en tête, gris au pied. Une lettre pleinement
            // blanche est PLATE ; une lettre qui s'éteint vers le bas a du
            // relief (l'école du titre de la home).
            Text("KD")
                .font(.inter(taille * 0.375, .semibold))
                .tracking(taille * 0.012)
                .foregroundStyle(LinearGradient(
                    stops: [
                        .init(color: .white, location: 0.00),
                        .init(color: .white.opacity(0.97), location: 0.42),
                        .init(color: Color(white: 0.62), location: 1.00),
                    ],
                    startPoint: .top, endPoint: .bottom))
        }
        .frame(width: taille, height: taille)
        // L'OMBRE QUI DÉCOLLE : deux étages, l'un serré pour le contact,
        // l'autre large pour la profondeur. Un rond noir sans ombre, sur une
        // page noire, n'a pas de bord — donc pas d'existence.
        .shadow(color: .black.opacity(0.55), radius: taille * 0.10, y: 1)
        .shadow(color: .black.opacity(0.35), radius: taille * 0.32, y: 4)
    }
}

// MARK: - Les items et LA LOUPE

/// LES QUATRE SECTIONS, ET LA LOUPE DE VERRE QUI LES SURVOLE.
///
/// C'est la pièce maîtresse, et la maison avait déjà le bon composant : la
/// loupe du panneau 3-7 de la home, celle qu'elle a validée (« garde le zoom
/// natif »). On la remonte ici, à la verticale.
///
/// Un galet de verre SUIT le doigt le long de la colonne ; sous lui le titre
/// est GROSSI et poussé ; le galet S'AIMANTE d'un item à l'autre (jamais
/// posé entre deux) avec un CRAN haptique à chaque passage ; les voisins
/// reculent et pâlissent — la loupe creuse un puits.
///
/// ⚠️ Les deux lois du verre : le galet vit dans son CONTENEUR et les titres
/// AU-DESSUS (dedans, un titre grossi serait lentillé) ; et le galet garde
/// une taille de LAYOUT constante — c'est son offset qui bouge, jamais ses
/// bounds, sinon le flou devient plat pour toujours.
struct MenuItems: View {
    /// 0 → 1, la cascade d'arrivée.
    var p: Double
    /// L'item choisi, qui RESTE quand les autres s'effacent.
    var choisi: Int?
    /// L'item survolé au drag, et l'ouverture de la mise au point.
    var survol: Int?
    var loupe: Double
    var onChoix: (Int) -> Void = { _ in }
    var onSurvol: (Int?) -> Void = { _ in }

    /// LES HORODATAGES DE LA FUMÉE DES SECTIONS — le doigt qui glisse sur la
    /// colonne fume comme le galet et comme la molette des exercices. Trois
    /// objets qu'on prend au doigt, une seule matière.
    @State private var touche: Date?
    @State private var lache: Date?
    /// LA PLACE DU DOIGT dans la colonne. La fumée le SUIT — centrée sur le
    /// marqueur (x = 34) elle était à moitié hors écran et cachée derrière la
    /// vignette : pendant un vrai drag le doigt est sur les MOTS, à 150-300 pt,
    /// et on ne voyait rien. C'est la leçon de la molette : la fumée naît là où
    /// la main touche.
    @State private var main: CGPoint?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// ⚠️ TROIS SECTIONS, EN ANGLAIS, DANS CET ORDRE (verdict 22-08). Le
    /// « Réglages » est retiré — pas supprimé d'une intention, RETIRÉ le temps
    /// qu'il ait une page. Et « Collection » cède sa place à « Exercises », qui
    /// a la sienne.
    /// La page l'est déjà partout ailleurs (« Sessions this week », « Weekly
    /// volume ») : la colonne était la dernière pièce en français.
    static let titres = ["Profile", "Progress", "Exercises"]
    static let pas: CGFloat = 56
    static let hauteurItem: CGFloat = 38
    static let corps: CGFloat = 26
    private var n: Int { Self.titres.count }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // LA FUMÉE DES SECTIONS, tout au fond : elle sort DE SOUS le mot,
            // jamais par-dessus. Posée au-dessus, elle laiterait l'encre.
            fumee
            // LE LISERÉ DU CADRE : un fil chaud très fin qui naît sur le
            // bord gauche à la hauteur de l'item survolé. Le cadre RÉPOND —
            // c'est un des micro-détails qui font que l'objet est vivant.
            if loupe > 0.01, let s = survol {
                Capsule()
                    .fill(LinearGradient(
                        colors: [Color(red: 1.00, green: 0.72, blue: 0.38),
                                 Color(red: 1.00, green: 0.72, blue: 0.38)
                                    .opacity(0)],
                        startPoint: .leading, endPoint: .trailing))
                    .frame(width: 26, height: 2)
                    .offset(x: -16, y: yItem(s) - 1)
                    .opacity(loupe * 0.85)
                    .blur(radius: 0.6)
            }

            ForEach(0..<n, id: \.self) { i in
                titre(i)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .offset(x: 32, y: yItem(i) - Self.hauteurItem / 2)
            }
        }
        .frame(height: CGFloat(n) * Self.pas, alignment: .topLeading)
        .contentShape(Rectangle())
        .gesture(drag)
    }

    private func yItem(_ i: Int) -> CGFloat {
        CGFloat(i) * Self.pas + Self.hauteurItem / 2
    }

    // MARK: l'encre

    /// LA MISE AU POINT — et **rien derrière**.
    ///
    /// ⚠️ La pastille de verre posée sous le titre a été TUÉE : un chip
    /// derrière un mot est la grammaire d'Android et du web. Apple n'entoure
    /// jamais l'élément actif — il le rend plus PRÉSENT et ÉLOIGNE les
    /// autres. La sélection se dit par la typographie et la profondeur.
    ///
    /// Le titre survolé grossit, sa graisse MONTE (deux textes croisés —
    /// SwiftUI ne sait pas interpoler une graisse) et son tracking se
    /// RESSERRE : le mot se densifie au lieu de simplement grossir. Les
    /// voisins se floutent, pâlissent et reculent.
    /// Les mesures d'un titre. ⚠️ Elles vivent DEHORS, dans un type à
    /// part : dans le corps d'un `@ViewBuilder`, une suite d'instructions
    /// n'est pas une vue (« type '()' cannot conform to 'View' »), et tout
    /// mis en une seule expression le vérificateur de types SATURE. Un petit
    /// type de mesures règle les deux d'un coup.
    private struct Mesures {
        var track: CGFloat = 0
        var flou: CGFloat = 0
        var alpha: Double = 1
        var ech: CGFloat = 1
        var dx: CGFloat = 0
        var dy: CGFloat = 0
        var sous: Double = 0
        var bas: Double = 0.74
    }

    private func mesures(_ i: Int) -> Mesures {
        let a = avancement(i)
        let sous = (survol == i) ? loupe : 0
        let voisin = (survol != nil && survol != i) ? loupe : 0
        let doux: Double = reduceMotion ? 0 : 1
        var m = Mesures()
        // Le tracking se resserre À L'ARRIVÉE (+0,062 → +0,020 em) puis
        // encore SOUS LE DOIGT : le mot se POSE, puis se densifie.
        var tr = 0.062
        tr -= 0.042 * a
        tr -= 0.014 * sous
        m.track = Self.corps * CGFloat(tr)
        // Le couple flou + ÉCHELLE fait la mise au point ; le flou seul ne
        // fait qu'un brouillard (la loi de la phrase de la home).
        var fl = 11 * (1 - a)
        fl += 2.6 * doux * voisin
        m.flou = CGFloat(fl)
        m.alpha = a * sort(i) * (1 - 0.45 * voisin)
        var e = 1.0
        e += 0.06 * (1 - a)
        e += 0.10 * doux * sous
        e -= 0.02 * voisin
        m.ech = CGFloat(e)
        m.dx = CGFloat(5 * sous)
        m.dy = CGFloat(16 * (1 - a))
        m.sous = sous
        m.bas = 0.74 + 0.22 * sous
        return m
    }

    /// LA MISE AU POINT — et **rien derrière**. La pastille de verre a été
    /// TUÉE : un chip derrière un mot est la grammaire d'Android et du web.
    /// Apple n'entoure jamais l'élément actif — il le rend plus PRÉSENT et
    /// ÉLOIGNE les autres. Le titre survolé grossit, sa graisse MONTE (deux
    /// textes croisés : SwiftUI ne sait pas interpoler une graisse) et son
    /// tracking se resserre ; les voisins se floutent et reculent.
    @ViewBuilder
    private func titre(_ i: Int) -> some View {
        let m = mesures(i)
        // La ligne est-elle sous le doigt ? C'est le MÊME signal que la fumée :
        // les deux aperçus arrivent avec elle.
        let vu = (survol == i) || survolBanc == i
        HStack(spacing: 12) {
            // LE PROFIL PORTE SON VISAGE. C'est la grammaire des Réglages
            // d'Apple : la ligne du compte porte l'avatar au fer. La pastille
            // vit DANS la ligne — elle arrive, floute et recule avec elle,
            // sinon on aurait deux objets au lieu d'une rangée.
            //
            // ⚠️ ET LE CRÉNEAU EXISTE SUR LES QUATRE LIGNES, même vides. Sans
            // lui, « Profil » partait 46 pt plus à droite que les trois autres
            // et la colonne devenait BOITEUSE (mesuré à la capture : 78 pt
            // contre 32). Un menu se lit au fer ; c'est l'icône qui s'aligne
            // sur les mots, jamais l'inverse.
            ZStack {
                // LES TROIS MARQUEURS, TOUS AU MÊME NIVEAU, MAIS PAS AU MÊME
                // RÉGIME. La pastille KD est une IDENTITÉ : elle est toujours
                // là. Les deux autres sont des APERÇUS — ils n'existent que
                // sous le doigt (verdict 22-08 : « uniquement quand je drag la
                // section, pour pas alourdir »). Trois vignettes permanentes
                // font une liste de réglages ; une vignette qui vient quand on
                // la regarde fait un objet vivant.
                switch i {
                case 0: PastilleKD(taille: 34)
                case 1: MiniProgress()
                        // ⚠️ ELLE ENTRE PAR LA DROITE, de sous le mot. Un
                        // fondu seul ferait clignoter une image ; c'est le
                        // déplacement qui dit d'où elle vient. Et elle est
                        // posée APRÈS la fumée dans la pile — elle arrive
                        // AVEC elle et AU-DESSUS d'elle.
                        .opacity(vu ? 1 : 0)
                        .offset(x: vu ? 0 : 22)
                        .scaleEffect(vu ? 1 : 0.86)
                        .animation(.timingCurve(0.22, 1, 0.36, 1,
                                                duration: 0.34), value: vu)
                case 2: MiniExercices()
                        .opacity(vu ? 1 : 0)
                        .offset(x: vu ? 0 : 22)
                        .scaleEffect(vu ? 1 : 0.86)
                        .animation(.timingCurve(0.22, 1, 0.36, 1,
                                                duration: 0.34), value: vu)
                default: Color.clear.frame(width: 34, height: 34)
                }
            }
            .frame(width: 34, height: 34)
            ZStack(alignment: .leading) {
                // ⚠️ DEUX TEXTES CROISÉS : SwiftUI ne sait pas interpoler une
                // GRAISSE. La graisse de repos est montée d'un cran (Regular →
                // Medium) et celle du survol aussi (Medium → Semibold) :
                // « un peu plus grasse » sans toucher au corps.
                Text(Self.titres[i])
                    .font(.inter(Self.corps, .medium))
                    .opacity(1 - m.sous)
                Text(Self.titres[i])
                    .font(.inter(Self.corps, .semibold))
                    .opacity(m.sous)
            }
            .tracking(m.track)
            .foregroundStyle(LinearGradient(
                colors: [Color(white: 1.00), Color(white: m.bas)],
                startPoint: UnitPoint(x: 0.10 + 0.55 * m.sous, y: 0),
                endPoint: UnitPoint(x: 0.75 + 0.35 * m.sous, y: 1)))
        }
        .blur(radius: m.flou)
        .opacity(m.alpha)
        .scaleEffect(m.ech, anchor: .leading)
        .offset(x: m.dx, y: m.dy)
        .frame(height: Self.hauteurItem, alignment: .leading)
    }

    /// L'ARRIVÉE PROGRESSIVE, du BAS vers le haut. Le retard est passé à
    /// **90 ms** : à 55 ms les quatre mots arrivaient presque ensemble et la
    /// cascade ne se voyait pas.
    private func avancement(_ i: Int) -> Double {
        let retard = Double(n - 1 - i) * 0.090 / 0.62
        let x = min(max((p - retard) / (1 - retard), 0), 1)
        return 1 - pow(1 - x, 2.4)
    }

    private func sort(_ i: Int) -> Double {
        guard let c = choisi else { return 1 }
        return i == c ? 1 : 0
    }

    // MARK: le doigt

    /// Un seul geste pour toute la colonne : c'est lui qui permet le SURVOL
    /// (on garde le doigt et on glisse), impossible avec un tap par item.
    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { g in
                if touche == nil { touche = Date(); lache = nil }
                main = g.location
                let i = min(max(Int(g.location.y / Self.pas), 0), n - 1)
                if i != survol { onSurvol(i) }
            }
            .onEnded { g in
                let i = min(max(Int(g.location.y / Self.pas), 0), n - 1)
                main = g.location
                lache = Date()
                onSurvol(nil)
                onChoix(i)
            }
    }

    /// LA FUMÉE DE LA SECTION SOUS LE DOIGT. Elle vit sur la ligne survolée et
    /// la SUIT d'un item à l'autre — c'est la même bouffée qui se déplace, pas
    /// une par ligne.
    /// ⚠️ Rayon 20 et pas 31 : une ligne de texte n'est pas un disque de 62 pt,
    /// et l'enveloppe du shader est proportionnelle au rayon — à 31 la fumée
    /// débordait sur les voisines et le survol ne se lisait plus.
    @ViewBuilder
    private var fumee: some View {
        if let s = survol ?? survolBanc {
            // Elle suit le doigt en x, et s'aimante à la LIGNE en y : le doigt
            // tremble, la ligne non — une fumée qui vibre verticalement entre
            // deux items se lit comme un défaut.
            let y = CGFloat(s) * Self.pas + Self.hauteurItem / 2
            PanacheSection(start: touche, fin: lache,
                           foyer: CGPoint(x: main?.x ?? 120, y: y))
        }
    }
}

/// LA FUMÉE DU GALET PORTÉ — le jumeau exact de celle de la molette des
/// exercices (`ArcSmoke`), au même shader `knobSmoke` et à la même enveloppe :
/// attaque de 0,10 s, extinction exponentielle en 0,45 s au relâcher. Deux
/// objets ronds qu'on prend au doigt dans la même app doivent fumer pareil.
///
/// ⚠️ LE CADRE EST BORNÉ, PAS PLEIN ÉCRAN. L'enveloppe du shader décroît en
/// `exp(-d / (R × 0,82))` avec R = 31, et l'onde du toucher meurt à
/// `R + 0,32 × 150 = 79 pt` : tout est éteint à 80 pt du centre. Un cadre de
/// 240 pt laisse 40 pt de marge et évite de peindre du vide sur tout l'écran à
/// chaque image.
///
/// ⚠️ ET IL SUIT LE GALET. Le centre est passé en coordonnées LOCALES (le
/// milieu du cadre) et c'est le `.position` qui porte le déplacement : le
/// shader n'a pas à connaître la page.
/// `-fumeeBanc` : la bouffée FORCÉE, sans doigt. Le simulateur ne sait pas
/// draguer et `simctl` n'a pas de commande `tap` — sans ce banc, la fumée n'est
/// jugeable qu'à la main, donc jamais en capture.
/// ⚠️ Au niveau du FICHIER : une `static let` dans un type générique
/// (`MenuHote<Fond, Contenu>`) ne compile pas.
private let fumeeBanc = CommandLine.arguments.contains("-fumeeBanc")

/// `-menuSurvol <n>` : la section `n` FORCÉE sous le doigt. Le simulateur ne
/// sait pas survoler et `simctl` n'a pas de commande `tap` — sans ce banc, les
/// deux aperçus (qui n'existent QUE sous le doigt) ne se capturent jamais.
private let survolBanc: Int? = {
    let a = CommandLine.arguments
    guard let i = a.firstIndex(of: "-menuSurvol"), i + 1 < a.count else { return nil }
    return Int(a[i + 1])
}()

/// LES MINI CARDS DU MENU — la même ardoise que les pochettes du widget
/// « This week. » de la home, réduites à la taille de la pastille KD.
///
/// ⚠️ C'est une CITATION, pas un objet neuf : même dégradé (0,060 → 0,030),
/// même cheveu blanc à 6 %, même lumière posée en haut-gauche, même sticker
/// tranché par le bord bas. Trois marqueurs de sections doivent appartenir à la
/// même famille — un badge inventé pour l'occasion se verrait.
private struct MiniCarteMenu<Contenu: View>: View {
    var cote: CGFloat = 34
    @ViewBuilder var contenu: () -> Contenu

    private var forme: RoundedRectangle {
        RoundedRectangle(cornerRadius: cote * 0.26, style: .continuous)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            forme.fill(LinearGradient(
                colors: [Color(white: 0.060), Color(white: 0.030)],
                startPoint: .top, endPoint: .bottom))
            forme.strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
            forme.fill(EllipticalGradient(
                stops: [.init(color: .white.opacity(0.07), location: 0),
                        .init(color: .clear, location: 1)],
                center: UnitPoint(x: 0.25, y: 0.08),
                startRadiusFraction: 0, endRadiusFraction: 1.0))
                .blendMode(.plusLighter)
            contenu()
        }
        .frame(width: cote, height: cote)
        .clipShape(forme)
    }
}

/// La mini de PROGRESS : la date du jour et un sticker, comme une pochette du
/// bac. Le sticker est tranché par le bord bas — la coupe est un choix, c'est
/// la loi de la pochette.
private struct MiniProgress: View {
    var cote: CGFloat = 34

    private static let fJour: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "d"; return f
    }()
    private static let fMois: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR"); f.dateFormat = "MMM"
        return f
    }()

    var body: some View {
        MiniCarteMenu(cote: cote) {
            VStack(alignment: .leading, spacing: -1) {
                Text(Self.fJour.string(from: Date()) + ".")
                    .font(.inter(cote * 0.265, .bold))
                    .foregroundStyle(Color.inkPrimary)
                Text(Self.fMois.string(from: Date()).uppercased())
                    .font(.inter(cote * 0.145, .semibold))
                    .tracking(0.4)
                    .foregroundStyle(Color(white: 1).opacity(0.45))
            }
            .padding(.leading, cote * 0.14)
            .padding(.top, cote * 0.10)
            // ⚠️ LE STICKER RESTE DEDANS. Sur la pochette du widget il est
            // tranché par le bord bas — la coupe y est un choix, l'ardoise fait
            // 70 pt. À 34 pt la coupe mange la moitié du sticker et on ne
            // reconnaît plus rien : il est remonté et réduit pour tenir en
            // entier (bas à 31,6 pour un côté de 34).
            Image("sticker-flamme")
                .resizable().scaledToFit()
                .frame(width: cote * 0.42, height: cote * 0.42)
                .position(x: cote * 0.60, y: cote * 0.72)
        }
    }
}

/// La mini d'EXERCISES : la photo d'un exercice, sombrée pour rester une
/// ardoise et pas une vignette de galerie.
private struct MiniExercices: View {
    var cote: CGFloat = 34

    var body: some View {
        MiniCarteMenu(cote: cote) {
            // ⚠️ `scaledToFit`, PAS `toFill`. En remplissage, un cadre carré
            // découpé dans une photo verticale ne montrait qu'un morceau de
            // torse énorme — « l'image est trop grosse ». Ajustée, la
            // silhouette entière tient, et c'est elle qu'on reconnaît.
            Image("exo-crunch-machine")
                .resizable().scaledToFit()
                .padding(cote * 0.10)
                .opacity(0.80)
        }
    }
}

/// LE PANACHE D'UNE SECTION — il MONTE du doigt, il n'entoure rien.
///
/// ⚠️ Il remplace `knobSmoke` ici, et c'est une question de FORME, pas de
/// réglage : ce shader ne peint que pour `r > R`, donc il laisse un TROU
/// circulaire au centre. Autour du galet c'est juste — la pastille l'occupe.
/// Sur un mot il n'y a rien à occuper, et on voyait un rond (verdict 22-08 :
/// « pourquoi il y a un rond dans le menu pour la fumée au drag des
/// sections »). Le doigt ne le remplit pas : il est POSÉ dessus, pas dedans.
///
/// Même shader que l'invite (`panacheInvite`, HomeNuit.metal), à l'échelle
/// 0,45 : les lignes voisines sont à 56 pt, un panache pleine hauteur les
/// traverserait.
private struct PanacheSection: View {
    let start: Date?
    let fin: Date?
    let foyer: CGPoint

    private static let larg: CGFloat = 190
    private static let haut: CGFloat = 104
    private static let echelle: Float = 0.45
    private static let origine = Date()

    var body: some View {
        if let start = fumeeBanc ? (start ?? Self.origine) : start {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                let now = tl.date
                let age = now.timeIntervalSince(start)
                let attack = min(age / 0.10, 1.0)
                let release = fumeeBanc ? 0
                    : (fin.map { now.timeIntervalSince($0) } ?? 0)
                // Même enveloppe gestuelle que le galet : attaque 0,10 s,
                // extinction exponentielle en 0,45 s au relâcher.
                let puff = attack * exp(-max(release, 0) / 0.45)
                let t = now.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 900)
                Rectangle()
                    .fill(.white)
                    .colorEffect(ShaderLibrary.panacheInvite(
                        .float2(Float(Self.larg), Float(Self.haut)),
                        .float(t),
                        // Le foyer est au BAS de la boîte : la fumée monte.
                        .float2(Float(Self.larg / 2), Float(Self.haut - 6)),
                        .float(Float(min(puff, 1) * 0.85)),
                        .float(Self.echelle)
                    ))
                    .frame(width: Self.larg, height: Self.haut)
                    .position(x: foyer.x, y: foyer.y - Self.haut / 2 + 6)
            }
            .allowsHitTesting(false)
        }
    }
}

private struct GaletFumee: View {
    let start: Date?
    let fin: Date?
    let centre: CGPoint

    /// Le rayon de la source. 31 pour le galet (`MenuHote.centre` vaut
    /// 24 + 31) ; plus petit pour une ligne de menu, qui n'est pas un disque.
    var rayon: CGFloat = 31
    private static let cote: CGFloat = 240
    private static let origine = Date()

    var body: some View {
        if let start = fumeeBanc ? (start ?? Self.origine) : start {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                let now = tl.date
                let age = now.timeIntervalSince(start)
                let attack = min(age / 0.10, 1.0)
                let release = fumeeBanc ? 0
                    : (fin.map { now.timeIntervalSince($0) } ?? 0)
                let puff = attack * exp(-max(release, 0) / 0.45)
                let t = now.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 900)
                Rectangle()
                    .fill(.white)
                    .colorEffect(ShaderLibrary.knobSmoke(
                        .float2(Float(Self.cote), Float(Self.cote)),
                        .float(t),
                        .float4(Float(Self.cote / 2), Float(Self.cote / 2),
                                Float(rayon), Float(rayon)),
                        .float(puff),
                        // ⚠️ L'ÂGE EST PLAFONNÉ À 1,2 s, ET C'EST PROPRE À CE
                        // GALET. Le shader fait glisser le champ de bruit de
                        // `age × 80` px le long du rayon : sur la molette des
                        // exercices le toucher dure un instant, mais on PORTE
                        // le galet plusieurs secondes — à 15 s le bruit est
                        // échantillonné sur 1 200 px de déplacement radial et
                        // les volutes dégénèrent en RAYONS DROITS, mesuré au
                        // banc `-fumeeBanc`. Plafonné, la fumée continue de
                        // vivre par la dérive temporelle (`t`), sans s'étirer.
                        // (L'onde du toucher meurt en `exp(-age/0,32)` : elle
                        // est éteinte bien avant 1,2 s, le plafond ne la touche
                        // pas.)
                        .float(min(age, 1.2))
                    ))
                    .frame(width: Self.cote, height: Self.cote)
                    .position(centre)
            }
            .allowsHitTesting(false)
        }
    }
}

// MARK: - L'hôte

/// LA CHORÉGRAPHIE — **un seul curseur, jamais une chaîne de minuteurs.**
/// Chaque `asyncAfter` est une MARCHE ; quatre animations qui démarrent
/// chacune de son côté ne peuvent pas couler. Une seule grandeur `p`,
/// animée UNE fois, dont chaque pièce dérive son avancement.
struct MenuHote<Fond: View, Contenu: View>: View {
    @Binding var ouvert: Bool
    var onChoix: (Int) -> Void = { _ in }
    /// LE FOND — la vidéo. **Il ne recule PAS** : une couche UIKit ne sait
    /// pas s'échelonner dans une transaction SwiftUI, elle saute.
    /// LA COURONNE au lieu de la colonne : le menu éclôt AUTOUR du galet, là
    /// où il se trouve. Les deux formes cohabitent le temps de l'A/B — la
    /// colonne est validée, on ne la jette pas sur une intuition.
    /// (Déclarée AVANT les `@ViewBuilder` : l'init membre à membre suit
    /// l'ordre des propriétés, et les closures doivent rester en dernier.)
    var couronne: Bool = false
    /// LA PAGE DOIT SAVOIR QUE LE GALET EST RANGÉ : quand il s'encastre dans
    /// le mur, le slider de la rangée reprend la largeur qu'il libère.
    var onRange: (Bool) -> Void = { _ in }
    /// LA PAGE RANGE LE GALET. Au départ d'une séance, la rangée du bas
    /// appartient au player : le galet s'encastre dans le mur tout seul,
    /// et il en ressort quand la séance s'achève.
    var rangerDemande: Bool = false
    /// LE GALET EST DU MOBILIER, PAS UN OUTIL. ⚠️ Tiroir ouvert, sa prise
    /// (généreuse par nécessité) chevauche le pouce du slider pendant toute
    /// l'animation de rangement — et comme il est au-dessus de tout, c'est LUI
    /// qui gagnait le doigt : « quand j'ai commencé à slider, la petite pilule
    /// m'a suivi tout l'écran ». Rangé pour laisser la place, il ne doit plus
    /// l'attraper.
    var verrouille: Bool = false
    /// UN RECUL COMMANDÉ PAR LA PAGE, 0 → 1 — la vitrine des widgets s'en
    /// sert : elle éteint le mobilier avec EXACTEMENT le trio du menu
    /// (flou 7 + échelle 0,974 + extinction), sans dupliquer la pile.
    /// `retrait` est déjà un `max` : une entrée de plus, pas un mécanisme.
    var reculExterne: Double = 0
    @ViewBuilder var fond: () -> Fond
    /// LE MOBILIER — lui recule.
    @ViewBuilder var contenu: () -> Contenu

    @State private var p: Double = 0
    @State private var appui = false
    @State private var choisi: Int?
    @State private var elu: Int?
    @State private var survol: Int?
    @State private var loupe: Double = 0
    @State private var doigt: CGPoint?
    /// LE GALET DANS LA MAIN — son écart à sa place, en points. Il repart
    /// toujours de zéro : le galet a UNE place, on ne fait que l'en éloigner.
    @State private var porte: CGSize = .zero
    /// Le doigt l'a vraiment emmené (au-delà de 12 pt) — sinon c'est un tap.
    @State private var enMain = false
    /// ⚠️ LES HORODATAGES DE LA FUMÉE, et ils sont accrochés à `enMain`, pas à
    /// l'appui : un simple TAP ouvre le menu, et il ne doit pas cracher une
    /// bouffée. La fumée est le signe qu'on PORTE le galet.
    @State private var porteStart: Date?
    @State private var porteEnd: Date?
    /// RANGÉ sur le flanc gauche.
    @State private var range = false
    /// L'écart au DÉBUT du geste : sans lui, reprendre un galet déjà déplacé
    /// le ferait sauter à l'origine du doigt.
    @State private var depart: CGSize = .zero
    /// L'écart BRUT, non borné : c'est lui qui dit si le doigt a poussé le
    /// galet DANS le mur — le geste qui le range.
    @State private var brut: CGSize = .zero
    /// CE GESTE A SORTI LE GALET DU MUR. ⚠️ Sans ce verrou, une traction
    /// COURTE (12 à 17 pt) laissait le centre visé sous le seuil de
    /// rangement et la navette SE RECOLLAIT au lâcher — « je galère à la
    /// récupérer ». On ne peut pas ranger et déranger dans le même geste.
    @State private var sortiDuMur = false
    /// Le jeton de la POSE : il déclenche la piste de keyframes de
    /// l'écrasement. Un compteur, pas un booléen — deux chutes de suite
    /// doivent rejouer.
    @State private var pose = 0
    /// Le néon reste armé pendant toute la chute, et ne retombe qu'une fois
    /// posé — sinon le galet traverse le noir du milieu d'écran en fantôme.
    @State private var feuChute: Double = 0
    /// Le retard de l'ouverture sur le lâcher : au tap elle part tout de
    /// suite, à la chute elle part juste avant le contact.
    @State private var retard: Double = 0

    // LA COURONNE — tout à l'horloge : la charge et l'éclosion sont lues dans
    // un `body`, or un `withAnimation` n'interpole QUE les `animatableData`
    // des modificateurs (une valeur lue dans un body saute à sa cible).
    @State private var chargeAt: Date?
    /// L'instant du dernier MOUVEMENT du doigt. C'est lui qui
    /// commande la charge : ce n'est pas la POSE qui arme, c'est
    /// l'IMMOBILITÉ. On peut donc porter le galet n'importe où, s'y
    /// arrêter sans lâcher, et la couronne éclôt à cet endroit.
    @State private var mouvementAt: Date = .distantPast
    @State private var chargeJeton = 0
    @State private var pouls: Timer?
    @State private var cOuverte = false
    @State private var cAt: Date = .distantPast
    @State private var cDepart: Double = 0
    @State private var cSens: Double = 0
    @State private var cSurvol: Int?
    @State private var cChoisi: Int?
    @State private var cChoixAt: Date = .distantPast
    @State private var cSurvolAt: Date = .distantPast
    /// LE RECUL DU MOBILIER quand la couronne éclôt. Il nourrit des
    /// MODIFICATEURS (échelle, opacité) — c'est le seul cas où `withAnimation`
    /// interpole vraiment, donc le seul qui a le droit de ne pas être à
    /// l'horloge. Et il est OBLIGATOIRE : `.clear` GIVRE ce qui est net, donc
    /// l'encre de la phrase doit s'être effacée avant que le disque n'arrive.
    @State private var recul: Double = 0

    /// 0,55 s. L'appui long d'Apple vaut 0,4-0,5 s ; au-delà de ~0,8 s on croit
    /// à un bug avant de croire à une cérémonie. Ce qui rend l'attente
    /// supportable n'est pas sa durée, c'est que la jauge soit VISIBLE.
    private static var tCharge: Double { 0.55 }
    private static var tEclosion: Double { 0.62 }
    private static var tRepli: Double { 0.34 }
    private static var espace: String { "menu" }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// LA CHUTE. 0,30 s, et l'ouverture démarre à 0,26 — 40 ms AVANT le
    /// contact. C'est la loi de la maison (« la lumière passe avant la
    /// géométrie », « l'oreille arrive avant l'œil ») : le sol s'allume pour
    /// RECEVOIR le galet, on ne voit pas une lampe s'allumer après un choc.
    /// ⚠️ Calculées, pas stockées : un type GÉNÉRIQUE ne peut pas porter de
    /// propriété statique stockée.
    private static var chute: Double { 0.30 }
    private static var avance: Double { 0.04 }
    private static var rayon: CGFloat { 31 }
    /// L'abscisse du CENTRE du galet à sa place (marge 24 + demi-galet).
    private static var centre: CGFloat { 55 }
    /// L'écart auquel le galet BUTE contre le bord gauche — la position la
    /// plus à gauche que `borne` autorise. Tout le rangement se mesure par
    /// rapport à elle, jamais par rapport à l'écran.
    private static var mur: CGFloat { 8 + rayon - centre }
    /// LA NAVETTE EST COUPÉE PAR LE BORD, et c'est tout le dessin : son centre
    /// tombe SUR l'arête de l'écran, donc sa moitié gauche n'existe pas. Une
    /// pilule entière posée à côté du bord est un widget égaré ; une forme
    /// tranchée par le cadre est une POIGNÉE de tiroir.
    ///
    /// ⚠️ Elle avait été sortie à 20 pt pour qu'on puisse l'attraper — c'était
    /// traiter le symptôme : ce qui rend l'objet saisissable n'est pas sa
    /// visibilité, c'est sa PRISE (invisible, 30 pt vers la droite et 34 en
    /// haut et en bas). Le dessin peut donc redevenir juste.
    private static var saillie: CGFloat { 0 }
    /// LA HAUTEUR OÙ LA PAGE RANGE LE GALET. Au ras du bas (le défaut), la
    /// languette tombait juste à côté du slider puis du player — deux objets
    /// qui se disputent le même coin. Elle se pose à mi-hauteur : loin de la
    /// rangée, loin de la phrase, et sous le pouce.
    private static func hauteurRange(_ s: CGSize) -> CGFloat {
        max(s.height * 0.42, 0)
    }

    private func fen(_ a: Double, _ b: Double) -> Double {
        min(max((p - a) / (b - a), 0), 1)
    }
    private func adouci(_ x: Double) -> Double { 1 - pow(1 - x, 1.8) }
    private var lumiere: Double { fen(0.00, 0.34) }
    private var montee: Double { adouci(fen(0.06, 0.74)) }

    /// ⚠️ **LE RETRAIT DU MOBILIER APPARTIENT AUX DEUX FORMES.** Le flou de 7 pt
    /// et l'extinction à 18 % étaient pilotés par le SEUL `recul`, que le chemin
    /// de la couronne met à 1 — la colonne ne les a jamais reçus. Résultat
    /// mesuré à la capture sur la vraie home : « Profile » se lisait par-dessus
    /// « This week. » et les deux cards de verre, encore nettes à 66 %.
    /// C'est aussi ce qui manquait au souvenir « menu liste BLUR halo » : le
    /// blur existait, il était branché sur l'autre menu.
    private var retrait: Double { max(montee, recul, reculExterne) }
    private var items: Double { fen(0.30, 1.00) }
    private var morph: Double { adouci(fen(0.46, 0.86)) }

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .bottomLeading) {
                fond()

                contenu()
                    // ⚠️ LE MOBILIER DOIT AVOIR DISPARU AVANT QUE LE VERRE
                    // N'ARRIVE, et pas seulement reculé. `.clear` GIVRE ce
                    // qui est NET : dans le banc le disque ne couvrait que la
                    // vidéo — du contenu doux — et il faisait lentille ; dans
                    // la vraie home il couvre « Cette semaine. », les mini
                    // cards et le slider, et il redevient un FROST (verdict :
                    // « le gros rond c'est pas du liquid glass mais du blur »).
                    // Reculer à 0,66 ne suffit pas : il faut que l'encre soit
                    // à la fois presque éteinte ET adoucie, pour que le verre
                    // n'ait plus que du doux à manger.
                    .blur(radius: 7 * retrait)
                    .scaleEffect(1 - 0.026 * retrait, anchor: .center)
                    .opacity(1 - 0.88 * retrait)

                Color.black.opacity(0.20 * retrait)
                    .ignoresSafeArea()
                    .allowsHitTesting(ouvert)
                    .onTapGesture { fermer(nil) }

                // ⚠️ **ON DÉMONTE, ON N'ÉTEINT PAS** (26-08). `MenuHalos`
                // était MONTÉ en permanence à `opacity(lumiere)` — donc son
                // sous-arbre vivait (et son shader tournait) pendant toute la
                // vie de la home pour peindre du VIDE. C'est le précédent
                // `verreMonte`, et celui du `rate` resté à 2,2 : une opacité
                // nulle n'arrête rien.
                if lumiere > 0.001 {
                    MenuHalos(p: montee, doigt: doigt)
                        .opacity(lumiere)
                }

                if !couronne {
                    MenuItems(p: items, choisi: choisi, survol: survol,
                              loupe: loupe,
                              onChoix: { i in fermer(i) },
                              onSurvol: { i in poserDoigt(i, g.size) })
                        .padding(.bottom, g.size.height * 0.155)
                        .allowsHitTesting(ouvert)
                }

                // LA COURONNE. Sa couche de sélection n'existe QUE lorsqu'elle
                // est ouverte, et elle est posée SOUS le galet : pendant
                // l'appui tenu, c'est le geste du galet qui nourrit la
                // sélection — un seul doigt, du premier contact au choix.
                if couronne {
                    TimelineView(.animation(minimumInterval: 1.0 / 60)) { ctx in
                        let now = ctx.date
                        let b = bloom(now)
                        let geo = CouronneGeo.calcule(
                            centre: galetPos(g.size), taille: g.size)
                        ZStack {
                            // ⚠️ LA COUCHE DE SORTIE, et elle est posée en
                            // PREMIER : c'est elle qui ferme. Le verdict « ça
                            // a ouvert et là c'est bloqué » venait de là — un
                            // `Color.clear` seul dans une `TimelineView` dont
                            // les autres enfants sont tous en `.position()`
                            // n'a aucune taille INTRINSÈQUE : la couche
                            // apparaissait à l'instant même où la pile
                            // changeait de gabarit, et le geste ne s'y
                            // accrochait pas. Le cadre est donc FORCÉ, ouvert
                            // ou fermé, et il ne bouge plus jamais.
                            if cOuverte {
                                Color.clear
                                    .contentShape(Rectangle())
                                    .gesture(gesteCouronne(geo))
                                // Filet de sécurité : un simple tap ferme,
                                // même si le drag ne s'accroche pas.
                                    .onTapGesture { fermerC() }
                            }
                            CouronneVue(p: b, geo: geo, survol: cSurvol,
                                        choisi: cChoisi,
                                        effacement: effacementC(now),
                                        arrivee: arriveeMot(now),
                                        taille: g.size)
                            AnneauCharge(charge: charge(now), bloom: b,
                                         centre: geo.centre,
                                         rayonFinal: geo.rayon + 44)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }

                // LA FUMÉE DU PORT — la même que la molette de la page
                // exercices (`knobSmoke`, ExosHalo.metal), pour que deux objets
                // ronds qu'on prend au doigt dans la même app se comportent
                // pareil. Elle naît du disque et grimpe le long de son bord.
                //
                // ⚠️ ELLE N'EXISTE PAS AU REPOS. Le sous-arbre entier est absent
                // tant que le galet n'est pas porté : un `colorEffect` est une
                // passe de shader par image, et la home en a déjà assez.
                // ⚠️ ET ELLE EST BORNÉE À 240 pt AUTOUR DU GALET, pas plein
                // écran. L'enveloppe du shader décroît en `exp(-d / (R·0,82))`
                // avec R = 31 : la fumée est éteinte à 75 pt du centre, une
                // passe plein écran peindrait du vide sur 90 % de sa surface.
                GaletFumee(start: porteStart, fin: porteEnd,
                           centre: galetPos(g.size))
                GaletMaison(morph: morph, appui: appui, feuSup: feuChute,
                            range: range)
                    // ⚠️ PIÈGE PAYÉ ICI, et il vaut pour toute l'app :
                    // **DEUX `withAnimation` SUR LA MÊME VALEUR DANS LE MÊME
                    // TOUR NE JOUENT RIEN.** Écrire 0 → 1 puis 1 → 0 dans le
                    // même bloc laisse SwiftUI diffuser 0 → 0 : il ne voit
                    // aucun changement, et l'aller-retour n'existe tout
                    // simplement pas. Un écrasement est un ALLER-RETOUR : sa
                    // forme juste est une piste de keyframes, dont le premier
                    // palier porte le vol. (Et il est posé AVANT les marges,
                    // sinon son ancre basse tombe 24 pt plus bas et l'objet
                    // glisse au lieu de s'aplatir.)
                    .keyframeAnimator(initialValue: 0.0, trigger: pose) {
                        vue, v in
                        vue.scaleEffect(x: 1 + 0.15 * v, y: 1 - 0.15 * v,
                                        anchor: .bottom)
                    } keyframes: { _ in
                        KeyframeTrack {
                            LinearKeyframe(0.0, duration: Self.chute)
                            SpringKeyframe(1.0, duration: 0.06,
                                           spring: .snappy)
                            SpringKeyframe(0.0, duration: 0.40,
                                           spring: Spring(response: 0.36,
                                                          dampingRatio: 0.48))
                        }
                    }
                    .padding(.leading, 24)
                    .padding(.bottom, 24)
                    // ⚠️ LA PRISE DE LA NAVETTE — « parfois je suis bloquée,
                    // j'arrive plus à la tirer ». Deux causes, mesurables :
                    //  · la navette fait 84 pt de haut, le cadre du galet 62 :
                    //    **ses 11 pt du haut et du bas débordaient hors de la
                    //    zone sensible**. Doigt posé sur la pointe = rien ;
                    //  · il n'en reste que 13 pt à l'écran, collés à l'arête —
                    //    et le système se réserve cette bande pour ses propres
                    //    gestes de bord.
                    // Le remède est le même pour les deux : une prise LARGE
                    // qui déborde vers la droite, pour qu'on puisse commencer
                    // le geste LOIN du bord. Le pad vertical est symétrique
                    // mais le ZStack aligne en bas — d'où la compensation
                    // d'offset, sinon le galet remonterait de 26 pt.
                    .padding(.vertical, range ? 34 : 0)
                    .padding(.trailing, range ? 30 : 0)
                    .offset(x: porte.width,
                            y: porte.height + (range ? 34 : 0))
                    .contentShape(range ? AnyShape(Rectangle())
                                        : AnyShape(Circle()))
                    .allowsHitTesting(!verrouille)
                    // ⚠️ UN SEUL GESTE. Un `onLongPressGesture` même à
                    // 0,01 s VOLE le tap qui le suit (le piège déjà payé sur
                    // le puits de l'iPod, où le tap simple devait être posé
                    // AVANT l'appui). Un `DragGesture(minimumDistance: 0)`
                    // donne les TROIS d'un coup : l'état « doigt posé » à
                    // `onChanged`, le PORT si le doigt l'emmène, et le tap à
                    // `onEnded` s'il n'a pas fui.
                    .gesture(
                        DragGesture(minimumDistance: 0,
                                    coordinateSpace: .named(Self.espace))
                            .onChanged { v in
                                if !appui {
                                    appui = true
                                    // ⚠️ LA FUMÉE PART AU CONTACT — au TAP comme
                                    // au drag (verdict 22-08). Elle était
                                    // accrochée au seuil de 12 pt pour qu'un tap
                                    // ne crache pas de bouffée ; c'est
                                    // l'inverse qui est voulu : on touche le
                                    // galet, il fume. Jamais par défaut, en
                                    // revanche — `porteStart` naît nil et
                                    // meurt au relâcher.
                                    porteStart = Date()
                                    porteEnd = nil
                                    depart = porte
                                    // Jamais de `brut` périmé d'un geste
                                    // précédent : il décide du rangement.
                                    brut = porte
                                    sortiDuMur = false
                                    UIImpactFeedbackGenerator(style: .soft)
                                        .impactOccurred()
                                    // L'APPUI TENU part ICI, du même geste :
                                    // un `onLongPressGesture`, même à 0,01 s,
                                    // VOLERAIT le tap qui le suit.
                                    if couronne, !range, !cOuverte {
                                        mouvementAt = Date()
                                        armer()
                                    }
                                }
                                // Couronne ouverte : le MÊME doigt continue
                                // dans la sélection. On ne relâche pas pour
                                // choisir — c'est la grammaire des menus
                                // contextuels d'iOS.
                                if cOuverte {
                                    viserC(v.location, g.size)
                                    return
                                }
                                let d = hypot(v.translation.width,
                                              v.translation.height)
                                if d > 12, !enMain {
                                    enMain = true
                                    // ON LE TIRE : dès qu'il quitte le mur,
                                    // la navette redevient galet. Un seul
                                    // geste, aucune poignée à viser.
                                    if range {
                                        // ⚠️ PLUS DE REBASAGE. Recaler l'écart
                                        // sur le mur faisait SAUTER la navette
                                        // de 20 pt vers la droite dès qu'on la
                                        // touchait — donc elle résistait quand
                                        // on voulait la pousser, et le geste
                                        // partait de travers quand on voulait
                                        // la sortir. Elle DÉCOLLE simplement :
                                        // le ressort la décolle du mur, et
                                        // l'écart continue de compter depuis
                                        // là où elle était.
                                        withAnimation(.spring(
                                            response: 0.26,
                                            dampingFraction: 0.70)) {
                                                range = false
                                            }
                                        sortiDuMur = true
                                        onRange(false)
                                        return
                                    }
                                }
                                // Le galet reste attrapable MENU OUVERT : il
                                // n'y a pas deux modes, il y a un objet.
                                guard enMain else { return }
                                brut = CGSize(
                                    width: depart.width + v.translation.width,
                                    height: depart.height + v.translation.height)
                                // Il suit le doigt au point près — aucune
                                // animation ici : une transaction entre le
                                // doigt et l'objet, c'est du retard qu'on sent.
                                porte = borne(brut, g.size)
                                // Le doigt bouge : la charge repart de zéro.
                                // C'est l'ARRÊT qui ouvre, pas la pose.
                                mouvementAt = Date()
                            }
                            .onEnded { v in
                                appui = false
                                let tenu = enMain
                                enMain = false
                                if porteStart != nil { porteEnd = Date() }
                                desarmer()
                                // La couronne était déjà ouverte : ce doigt-là
                                // ne fait plus qu'une chose, choisir.
                                if cOuverte {
                                    choisirC(v.location, g.size)
                                    return
                                }
                                if tenu {
                                    // POUSSÉ DANS LE MUR : il se range sur le
                                    // flanc. Sinon il RETOMBE, et c'est sa
                                    // chute qui ouvre le menu.
                                    //
                                    // ⚠️ LE SEUIL EST UNE POSITION VISÉE, pas
                                    // un écart : « le centre que le doigt
                                    // demande est-il à moins de 18 pt du bord
                                    // gauche ». C'est continu, ça se lit à
                                    // l'œil pendant le geste, et surtout ça ne
                                    // dépend plus d'aucune base — les deux
                                    // versions par écart se sont contredites
                                    // (l'une recollait la navette au mur,
                                    // l'autre rendait le rangement
                                    // inatteignable).
                                    if !sortiDuMur,
                                       Self.centre + brut.width < 18 {
                                        ranger(g.size)
                                        // LE MENU PART AVEC SON BOUTON. On
                                        // range l'objet, pas seulement sa
                                        // forme : laisser quatre mots ouverts
                                        // sous une poignée encastrée serait un
                                        // état sans propriétaire.
                                        if ouvert {
                                            retard = 0
                                            ouvert = false
                                        }
                                        fermerC()
                                    } else {
                                        lacher()
                                    }
                                    return
                                }
                                let d = hypot(v.translation.width,
                                              v.translation.height)
                                guard d < 40 else { return }
                                // Tapé alors qu'il est rangé : il sort du mur
                                // ET ouvre — le même geste rend les deux.
                                if range {
                                    withAnimation(.spring(response: 0.30,
                                                          dampingFraction: 0.7)) {
                                        range = false
                                    }
                                    onRange(false)
                                    lacher()
                                    return
                                }
                                // LE CHEMIN RAPIDE : relâché avant la fin de
                                // la charge, ça OUVRE quand même. La charge
                                // n'est pas un seuil à franchir, c'est une
                                // cérémonie offerte à qui prend le temps.
                                if couronne {
                                    ouvrirC()
                                    return
                                }
                                retard = 0
                                ouvert.toggle()
                            }
                    )
            }
            .coordinateSpace(.named(Self.espace))
            .onChange(of: ouvert) { _, v in jouer(v) }
            .onChange(of: rangerDemande) { _, v in
                if v, !range {
                    brut = CGSize(width: 0, height: -Self.hauteurRange(g.size))
                    ranger(g.size)
                } else if !v, range {
                    withAnimation(.spring(response: 0.36,
                                          dampingFraction: 0.76)) {
                        range = false
                        porte = .zero
                    }
                    onRange(false)
                }
            }
            .onAppear {
                // ⚠️ L'ÉTAT INITIAL N'EST PAS UN CHANGEMENT : une page qui
                // s'ouvre DÉJÀ en séance n'a jamais fait basculer
                // `rangerDemande`, donc le `onChange` ne parle pas. Le galet
                // restait posé sur le player.
                if rangerDemande, !range {
                    brut = CGSize(width: 0, height: -Self.hauteurRange(g.size))
                    ranger(g.size)
                }
                bancChute(g.size)
            }
        }
    }

    // MARK: - La couronne

    /// Le centre du galet dans le repère de la page — c'est là que la couronne
    /// éclôt, et c'est ce qui rend enfin le transport UTILE : le menu naît là
    /// où l'objet se trouve, il n'a plus besoin de rentrer d'abord.
    private func galetPos(_ taille: CGSize) -> CGPoint {
        CGPoint(x: Self.centre + porte.width,
                y: taille.height - Self.centre + porte.height)
    }

    private func charge(_ now: Date) -> Double {
        guard chargeAt != nil, !range, !cOuverte else { return 0 }
        let t = now.timeIntervalSince(mouvementAt)
        return min(max(t / Self.tCharge, 0), 1)
    }

    private func bloom(_ now: Date) -> Double {
        guard cSens != 0 else { return cDepart }
        let duree = cSens > 0 ? Self.tEclosion : Self.tRepli
        let x = min(max(now.timeIntervalSince(cAt) / duree, 0), 1)
        // La courbe des feuilles d'Apple, à la main : elle part vite et se
        // POSE longuement — c'est ce dernier tiers qui fait le luxe.
        let e = cSens > 0 ? 1 - pow(1 - x, 2.2) : x
        return min(max(cDepart + cSens * e, 0), 1)
    }

    private func effacementC(_ now: Date) -> Double {
        guard cChoisi != nil else { return 0 }
        return min(max(now.timeIntervalSince(cChoixAt) / 0.09, 0), 1)
    }

    /// L'arrivée du mot, remise à zéro à CHAQUE changement de survol : le mot
    /// se refait la mise au point d'une section à l'autre, il ne commute pas.
    private func arriveeMot(_ now: Date) -> Double {
        min(max(now.timeIntervalSince(cSurvolAt) / 0.19, 0), 1)
    }

    /// LA CHARGE S'ARME. Le grondement haptique double la jauge exactement :
    /// `dragLevel` tient une vibration continue et sait la faire enfler — un
    /// `UIImpactFeedbackGenerator` ne sait faire que des chocs.
    private func armer() {
        chargeAt = Date()
        chargeJeton &+= 1
        let tok = chargeJeton
        RocketHaptics.shared.prepare()
        pouls?.invalidate()
        // ⚠️ L'ÉCHÉANCE SE DÉCALE à chaque mouvement, donc elle ne peut pas
        // être un `asyncAfter` posé une fois pour toutes : c'est le pouls qui
        // la surveille, et lui seul.
        pouls = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { t in
            guard tok == chargeJeton, chargeAt != nil else {
                t.invalidate(); return
            }
            guard !range, !cOuverte else { return }
            let x = min(Date().timeIntervalSince(mouvementAt) / Self.tCharge, 1)
            RocketHaptics.shared.dragLevel(x * 0.55)
            if x >= 1 { ouvrirC() }
        }
    }

    private func desarmer() {
        chargeJeton &+= 1
        chargeAt = nil
        pouls?.invalidate()
        pouls = nil
        RocketHaptics.shared.dragEnd()
    }

    private func ouvrirC() {
        desarmer()
        guard !cOuverte else { return }
        cOuverte = true
        cChoisi = nil
        cSurvol = nil
        cDepart = bloom(Date())
        cSens = 1
        cAt = Date()
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.50)) {
            recul = 1
        }
    }

    private func fermerC() {
        guard cOuverte else { return }
        cOuverte = false
        // LE GALET RENTRE APRÈS LE TRAVAIL. Ouvert en plein écran, il reste où
        // le doigt le tenait ; le menu refermé, il regagne son coin. C'est ce
        // qui réconcilie « ouvrir n'importe où » et « retour systématique au
        // coin gauche » : les deux sont vrais, mais pas au même moment.
        if !range, porte != .zero {
            withAnimation(.timingCurve(0.55, 0.0, 1.0, 0.45,
                                       duration: Self.chute)) {
                porte = .zero
            }
            pose &+= 1
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.chute) {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            }
        }
        cDepart = bloom(Date())
        cSens = -1
        cAt = Date()
        cSurvol = nil
        withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.40)) {
            recul = 0
        }
        // RIEN à la fermeture : un geste qui se termine dans le silence se
        // sent plus cher qu'un geste qui claque deux fois.
    }

    /// LA SÉLECTION SE FAIT PAR L'ANGLE, jamais sur une cible : le pouce part
    /// vers un médaillon et il est choisi. C'est l'ergonomie à une main — et ça
    /// supprime d'un coup toute la classe de bugs de zone sensible.
    private func vise(_ pt: CGPoint, _ geo: CouronneGeo) -> Int? {
        let dx = pt.x - geo.centre.x, dy = pt.y - geo.centre.y
        let d = hypot(dx, dy)
        // Le cœur est la zone d'ANNULATION : on revient au centre et on lâche.
        // ⚠️ ET IL FAUT AUSSI UNE BORNE EXTÉRIEURE, qui manquait : sans elle,
        // un tap à l'autre bout de l'écran restait « aligné » avec un
        // médaillon et le CHOISISSAIT au lieu de fermer. Tout ce qui tombe
        // hors de la bague ferme.
        guard d > 42, d < geo.rayon + 54 else { return nil }
        let a = atan2(dy, dx)
        var best: Int?
        var meilleur = 0.62
        for (i, ang) in geo.angles.enumerated() {
            var e = abs(a - ang).truncatingRemainder(dividingBy: 2 * .pi)
            if e > .pi { e = 2 * .pi - e }
            if e < meilleur { meilleur = e; best = i }
        }
        return best
    }

    private func viserC(_ pt: CGPoint, _ taille: CGSize) {
        let geo = CouronneGeo.calcule(centre: galetPos(taille), taille: taille)
        let i = vise(pt, geo)
        guard i != cSurvol else { return }
        cSurvol = i
        cSurvolAt = Date()
        if i != nil { UISelectionFeedbackGenerator().selectionChanged() }
    }

    private func choisirC(_ pt: CGPoint, _ taille: CGSize) {
        let geo = CouronneGeo.calcule(centre: galetPos(taille), taille: taille)
        if let i = vise(pt, geo) {
            cChoisi = i
            cChoixAt = Date()
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) {
                fermerC()
                onChoix(i)
            }
        } else {
            fermerC()
        }
    }

    private func gesteCouronne(_ geo: CouronneGeo) -> some Gesture {
        DragGesture(minimumDistance: 0,
                    coordinateSpace: .named(Self.espace))
            .onChanged { v in
                let i = vise(v.location, geo)
                guard i != cSurvol else { return }
                cSurvol = i
                cSurvolAt = Date()
                if i != nil { UISelectionFeedbackGenerator().selectionChanged() }
            }
            .onEnded { v in
                if let i = vise(v.location, geo) {
                    cChoisi = i
                    cChoixAt = Date()
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) {
                        fermerC()
                        onChoix(i)
                    }
                } else {
                    fermerC()
                }
            }
    }

    /// Le galet ne sort jamais de l'écran : 8 pt de garde tout autour.
    private func borne(_ t: CGSize, _ s: CGSize) -> CGSize {
        let r = Self.rayon, m: CGFloat = 8
        let cx = 24 + r, cy = s.height - 24 - r
        return CGSize(
            width: min(max(t.width, m + r - cx), s.width - m - r - cx),
            height: min(max(t.height, m + r - cy), s.height - m - r - cy))
    }

    /// LE LÂCHER — **le galet RENTRE TOUJOURS AU COIN GAUCHE.** Verdict du
    /// 21-08 : *« il doit se remettre au coin gauche systématiquement »*. Le
    /// laisser où le doigt l'abandonne (essayé, refusé le même jour) en fait un
    /// widget qui traîne ; un objet qui retrouve sa place est un bijou — et la
    /// page garde une composition stable au lieu d'un bouton qui erre.
    ///
    /// La seule exception est le RANGEMENT : poussé dans le mur, il y reste.
    ///
    /// Trois temps qui ne se chevauchent pas :
    ///
    ///   1. **LA CHUTE.** Une courbe qui ACCÉLÈRE jusqu'au sol
    ///      (`timingCurve(0.55, 0, 1, 0.45)` ≈ une gravité constante) : un
    ///      objet qui revient en `easeOut` ne tombe pas, il est RANGÉ. C'est
    ///      toute la différence entre un widget et une masse.
    ///   2. **LE CONTACT.** 60 ms d'écrasement sur sa base, puis un ressort mal
    ///      amorti qui le rend à sa forme — plus un choc LOURD à la main.
    ///   3. **L'OUVERTURE**, partie 40 ms plus tôt : le sol est déjà allumé
    ///      quand il touche.
    private func lacher() {
        let doux = reduceMotion
        let duree = doux ? 0.22 : Self.chute
        withAnimation(.timingCurve(0.55, 0.0, 1.0, 0.45, duration: duree)) {
            porte = .zero
        }
        // Le néon reste plein jusqu'au contact, puis s'éteint en se posant.
        // ⚠️ Le retour à zéro doit vivre dans un AUTRE tour de boucle : écrit
        // ici, il annulerait l'allumage (même piège que l'écrasement).
        feuChute = 1
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.34).delay(duree)) {
                feuChute = 0
            }
        }
        if !doux {
            pose &+= 1
            DispatchQueue.main.asyncAfter(deadline: .now() + duree) {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }
        }
        retard = max(duree - Self.avance, 0)
        // LA COURONNE ÉCLÔT AU CONTACT — 40 ms avant, comme la colonne : le
        // sol s'allume pour recevoir le galet, on ne voit pas une lampe
        // s'allumer après un choc.
        if couronne {
            let r = retard
            DispatchQueue.main.asyncAfter(deadline: .now() + r) { ouvrirC() }
            return
        }
        guard !ouvert else { return }
        // ⚠️ **LA COLONNE N'ATTEND PLUS LE GALET** (26-08). Verdict : « la
        // fumée apparaît, puis il y a un délai, puis le menu arrive trop
        // tard — la fumée et le menu doivent faire partie de la MÊME
        // transition ». Ce `retard` (jusqu'à 0,26 s) était pensé pour la
        // COURONNE, qui éclôt au sol sous le galet et doit donc attendre sa
        // chute ; la colonne, elle, naît sur le côté et n'a rien à attendre.
        // Elle héritait d'une cérémonie qui n'est pas la sienne.
        retard = 0
        ouvert = true
    }

    /// LE RANGEMENT. Poussé dans le bord gauche, le galet s'y ENCASTRE : il
    /// devient une navette dont le centre tombe pile SUR l'arête, donc dont la
    /// moitié sort de l'écran. Il ne reste qu'un bout de verre — assez pour le
    /// voir, trop peu pour qu'il occupe la page.
    ///
    /// Sa hauteur, elle, ne change pas : on le range à l'endroit où on l'a
    /// poussé, pas à une place imposée.
    private func ranger(_ taille: CGSize) {
        // La navette fait 84 de haut : son centre doit rester à 52 pt des deux
        // bords. Les bornes sont exprimées en ÉCART à la place de repos, qui
        // est à 55 pt du bas.
        let y = min(max(brut.height, 107 - taille.height), 3)
        withAnimation(.spring(response: 0.36, dampingFraction: 0.74)) {
            range = true
            porte = CGSize(width: -Self.centre + Self.saillie, height: y)
        }
        onRange(true)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    /// `-menuChute` : le simulateur ne sait pas poser un doigt, donc le banc
    /// porte le galet lui-même, le tient, le lâche, referme — en boucle. Sans
    /// lui, la chute ne se juge pas.
    private func bancChute(_ taille: CGSize) {
        // `-couronneGrille` (jalon C2) : le galet fait le tour des six places
        // et la couronne s'ouvre à chacune. C'est la PREUVE que les quatre
        // médaillons tiennent partout — la garantie ne vaut rien tant qu'on ne
        // l'a pas vue aux six coins.
        if CommandLine.arguments.contains("-couronneGrille") {
            let places: [CGSize] = [
                .zero,
                CGSize(width: taille.width - 110, height: 0),
                CGSize(width: 0, height: -(taille.height - 110)),
                CGSize(width: taille.width - 110,
                       height: -(taille.height - 110)),
                CGSize(width: taille.width / 2 - 55,
                       height: -(taille.height / 2 - 55)),
                CGSize(width: taille.width - 110,
                       height: -(taille.height / 2 - 55)),
            ]
            var k = 0
            Timer.scheduledTimer(withTimeInterval: 2.6, repeats: true) { _ in
                fermerC()
                porte = places[k % places.count]
                k += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    ouvrirC()
                }
            }
            return
        }
        // `-couronneRejoue` : le simulateur ne sait pas poser un doigt, donc
        // la couronne s'ouvre et se referme seule — c'est le seul moyen de
        // juger l'éclosion image par image.
        if CommandLine.arguments.contains("-couronneRejoue") {
            Timer.scheduledTimer(withTimeInterval: 4.4, repeats: true) { _ in
                if cOuverte { fermerC() } else { ouvrirC() }
            }
            return
        }
        // `-menuRange` : le galet se pousse tout seul dans le mur, s'y range,
        // et se fait tirer — pour juger la navette sans doigt.
        if CommandLine.arguments.contains("-menuRange") {
            Timer.scheduledTimer(withTimeInterval: 6.0, repeats: true) { _ in
                brut = CGSize(width: -120, height: -260)
                ranger(taille)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation(.spring(response: 0.34,
                                          dampingFraction: 0.72)) {
                        range = false
                    }
                    lacher()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.2) {
                    retard = 0
                    ouvert = false
                }
            }
            return
        }
        guard CommandLine.arguments.contains("-menuChute") else { return }
        Timer.scheduledTimer(withTimeInterval: 5.2, repeats: true) { _ in
            appui = true
            withAnimation(.easeInOut(duration: 0.55)) {
                porte = borne(CGSize(width: 250, height: -600), taille)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                appui = false
                lacher()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.9) {
                retard = 0
                ouvert = false
                fermerC()
            }
        }
    }

    /// UNE SEULE animation, UNE seule courbe. `.timingCurve(0.22, 1, 0.36, 1)`
    /// est celle des feuilles d'Apple : elle part vite et se POSE longuement
    /// — c'est ce dernier tiers qui fait le luxe.
    private func jouer(_ v: Bool) {
        if v { choisi = nil }
        // Le seul retard admis, et il n'est pas une marche : il décale le
        // DÉPART de l'unique animation, il ne la découpe pas.
        let r = v ? retard : 0
        retard = 0
        withAnimation(.timingCurve(0.22, 1, 0.36, 1,
                                   duration: v ? 0.78 : 0.52).delay(r)) {
            p = v ? 1 : 0
        }
        guard !v else { return }
        survol = nil
        doigt = nil
        withAnimation(.easeOut(duration: 0.20)) { loupe = 0 }
        if let i = elu {
            // 0,18 et non 0,52 : juste de quoi VOIR l'élu s'allumer (son
            // animation dure 0,07) avant que la route ne parte. La colonne
            // finit de se retirer PAR-DESSUS la page qui arrive — « on voit
            // partir ce qu'on a choisi » reste vrai, sans faire attendre.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                choisi = nil
                elu = nil
                onChoix(i)
            }
        }
    }

    /// LA LOUPE s'aimante d'un item à l'autre, avec un CRAN à chaque
    /// passage — c'est le cran qui fait qu'on la sent sans la regarder.
    private func poserDoigt(_ i: Int?, _ taille: CGSize) {
        guard let i else {
            withAnimation(.easeOut(duration: 0.22)) {
                survol = nil
                loupe = 0
            }
            doigt = nil
            return
        }
        if survol != i { UISelectionFeedbackGenerator().selectionChanged() }
        withAnimation(.spring(response: 0.30, dampingFraction: 0.78)) {
            survol = i
            loupe = 1
        }
        // la place du doigt, pour que les halos suivent la main
        let bas = taille.height * 0.155
        let y = taille.height - bas - CGFloat(3 - i) * MenuItems.pas
        doigt = CGPoint(x: 0.22, y: y / taille.height)
    }

    /// Le tap d'un item : l'élu RESTE, les autres s'effacent d'abord — on
    /// voit partir ce qu'on a choisi.
    private func fermer(_ i: Int?) {
        guard ouvert else { return }
        if let i {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            withAnimation(.easeOut(duration: 0.07)) { choisi = i }
        }
        elu = i
        // ⚠️ **PLUS DE MARCHE AVANT LA FERMETURE** (26-08). Choisir une section
        // coûtait 0,13 s ICI, puis 0,52 s dans `jouer(false)`, AVANT même que
        // `onChoix` ne soit appelé : la page de destination ne commençait à se
        // construire qu'à ~0,65 s — et elle est chère à construire. C'est la
        // moitié du « on dirait un chargement ». La fermeture se JOUE, elle
        // ne se fait plus attendre.
        ouvert = false
    }
}

// MARK: - Le banc

/// `-menuLab` : le menu sur la vraie card vidéo (pour que le galet ait de
/// quoi réfracter) avec un mobilier témoin qui RECULE — sans lui, on ne
/// juge pas la profondeur. `-menuRejoue` l'ouvre et le referme tout seul.
///
/// `-couronneLab` joue la MÊME page avec la couronne au lieu de la colonne :
/// c'est l'A/B, et les deux formes cohabitent tant que le verdict n'est pas
/// rendu — la colonne est validée, on ne la jette pas sur une intuition.
struct MenuLab: View {
    @State private var ouvert = false

    private var couronne: Bool {
        CommandLine.arguments.contains("-couronneLab")
            || CommandLine.arguments.contains("-couronneRejoue")
            || CommandLine.arguments.contains("-couronneGrille")
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            MenuHote(ouvert: $ouvert, couronne: couronne) {
                GrandeCardVideo(naissance: 1)
            } contenu: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bonjour Kathryn,")
                        .font(.inter(30, .semibold))
                        .foregroundStyle(.white)
                    Text("vous avez fait")
                        .font(.inter(30, .semibold))
                        .foregroundStyle(.white.opacity(0.42))
                    Text("3 entraînements")
                        .font(.inter(30, .semibold))
                        .foregroundStyle(.white)
                }
                .padding(.leading, 24)
                .padding(.top, 48)
                .frame(maxWidth: .infinity, maxHeight: .infinity,
                       alignment: .topLeading)
            }
        }
        .onAppear {
            guard CommandLine.arguments.contains("-menuRejoue") else { return }
            Timer.scheduledTimer(withTimeInterval: 4.6, repeats: true) { _ in
                ouvert.toggle()
            }
        }
    }
}
