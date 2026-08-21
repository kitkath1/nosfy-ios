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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                // LE VERRE, seul dans son conteneur.
                GlassEffectContainer(spacing: 0) {
                    Color.clear
                        .frame(width: taille, height: taille)
                        .glassEffect(.clear.interactive(), in: .circle)
                }
                // L'ENCRE, au-dessus du conteneur.
                NeonMaison(taille: taille * 0.40, morph: morph,
                           feu: appui ? 1 : 0)
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let titres = ["Profil", "Progression", "Collection", "Réglages"]
    static let pas: CGFloat = 56
    static let hauteurItem: CGFloat = 38
    static let corps: CGFloat = 26
    private var n: Int { Self.titres.count }

    var body: some View {
        ZStack(alignment: .topLeading) {
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
        ZStack(alignment: .leading) {
            Text(Self.titres[i])
                .font(.inter(Self.corps, .regular))
                .opacity(1 - m.sous)
            Text(Self.titres[i])
                .font(.inter(Self.corps, .medium))
                .opacity(m.sous)
        }
        .tracking(m.track)
        .foregroundStyle(LinearGradient(
            colors: [Color(white: 1.00), Color(white: m.bas)],
            startPoint: UnitPoint(x: 0.10 + 0.55 * m.sous, y: 0),
            endPoint: UnitPoint(x: 0.75 + 0.35 * m.sous, y: 1)))
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
                let i = min(max(Int(g.location.y / Self.pas), 0), n - 1)
                if i != survol { onSurvol(i) }
            }
            .onEnded { g in
                let i = min(max(Int(g.location.y / Self.pas), 0), n - 1)
                onSurvol(nil)
                onChoix(i)
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

    private func fen(_ a: Double, _ b: Double) -> Double {
        min(max((p - a) / (b - a), 0), 1)
    }
    private func adouci(_ x: Double) -> Double { 1 - pow(1 - x, 1.8) }
    private var lumiere: Double { fen(0.00, 0.34) }
    private var montee: Double { adouci(fen(0.06, 0.74)) }
    private var items: Double { fen(0.30, 1.00) }
    private var morph: Double { adouci(fen(0.46, 0.86)) }

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .bottomLeading) {
                fond()

                contenu()
                    .scaleEffect(1 - 0.026 * montee, anchor: .center)
                    .opacity(1 - 0.34 * montee)

                Color.black.opacity(0.20 * montee)
                    .ignoresSafeArea()
                    .allowsHitTesting(ouvert)
                    .onTapGesture { fermer(nil) }

                MenuHalos(p: montee, doigt: doigt)
                    .opacity(lumiere)

                MenuItems(p: items, choisi: choisi, survol: survol,
                          loupe: loupe,
                          onChoix: { i in fermer(i) },
                          onSurvol: { i in poserDoigt(i, g.size) })
                    .padding(.bottom, g.size.height * 0.155)
                    .allowsHitTesting(ouvert)

                GaletMaison(morph: morph, appui: appui)
                    .padding(.leading, 24)
                    .padding(.bottom, 24)
                    .contentShape(Circle())
                    // ⚠️ UN SEUL GESTE. Un `onLongPressGesture` même à
                    // 0,01 s VOLE le tap qui le suit (le piège déjà payé sur
                    // le puits de l'iPod, où le tap simple devait être posé
                    // AVANT l'appui). Un `DragGesture(minimumDistance: 0)`
                    // donne les deux d'un coup : l'état « doigt posé » à
                    // `onChanged`, et le tap à `onEnded` si le doigt n'a pas
                    // fui.
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                guard !appui else { return }
                                appui = true
                                UIImpactFeedbackGenerator(style: .soft)
                                    .impactOccurred()
                            }
                            .onEnded { g in
                                appui = false
                                let d = hypot(g.translation.width,
                                              g.translation.height)
                                guard d < 40 else { return }
                                ouvert.toggle()
                            }
                    )
            }
            .onChange(of: ouvert) { _, v in jouer(v) }
        }
    }

    /// UNE SEULE animation, UNE seule courbe. `.timingCurve(0.22, 1, 0.36, 1)`
    /// est celle des feuilles d'Apple : elle part vite et se POSE longuement
    /// — c'est ce dernier tiers qui fait le luxe.
    private func jouer(_ v: Bool) {
        if v { choisi = nil }
        withAnimation(.timingCurve(0.22, 1, 0.36, 1,
                                   duration: v ? 0.78 : 0.52)) {
            p = v ? 1 : 0
        }
        guard !v else { return }
        survol = nil
        doigt = nil
        withAnimation(.easeOut(duration: 0.20)) { loupe = 0 }
        if let i = elu {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.52) {
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
        DispatchQueue.main.asyncAfter(deadline: .now() + (i == nil ? 0 : 0.13)) {
            ouvert = false
        }
    }
}

// MARK: - Le banc

/// `-menuLab` : le menu sur la vraie card vidéo (pour que le galet ait de
/// quoi réfracter) avec un mobilier témoin qui RECULE — sans lui, on ne
/// juge pas la profondeur. `-menuRejoue` l'ouvre et le referme tout seul.
struct MenuLab: View {
    @State private var ouvert = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            MenuHote(ouvert: $ouvert) {
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
