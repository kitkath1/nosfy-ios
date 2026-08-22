import SwiftUI

// MARK: - LE MODE ÉDITION DES WIDGETS — « LA VITRINE »
//
// Le plan : `tools/home-v2/PLAN-EDITION-WIDGETS.md`. Le flow :
//
//   appui 0,50 s sur une card → ÉDITION (respiration ±1,4°, pastilles lune)
//   → tap lune → LISTE (Change / Remove) → « Change » → LA VITRINE :
//   la home recule (le trio du menu), le bas se masque, le widget vole au
//   centre À SA VRAIE TAILLE, le carousel à crans autour de lui, un fin
//   reflet blanc sur l'actif — tap = confirmer, tap dehors = annuler.
//
// Les lois qui gouvernent ce fichier (toutes déjà payées ailleurs) :
//  · le verre natif ignore `.opacity` → on le DÉMONTE (`if p > 0.01`) et on
//    le révèle par un MASQUE à taille constante ;
//  · l'encre vit AU-DESSUS du conteneur de verre, jamais dedans ;
//  · un seul curseur par geste, fenêtres dérivées — jamais d'asyncAfter
//    échelonnés ;
//  · la vidéo ne recule jamais ; le scrim n'est JAMAIS noir total ;
//  · le simulateur ne sait ni long-press ni drag → chaque pièce a son banc.

// MARK: - La pastille lune

/// LA PASTILLE « MODIFIER » — le bol noir maison (`Medaillon`, PEINT : un
/// verre natif de 22 pt sur un coin noir est à jeun, p95 mesuré à 23) et le
/// glyphe lune très discret. Elle ne veut pas dire « supprimer » : elle est
/// la porte des choix.
struct PastilleLune: View {
    /// 0 → 1, l'arrivée (scale 0,6 → 1,06 → 1,00 — l'école des cinq points).
    var p: Double
    var action: () -> Void

    var body: some View {
        if p > 0.005 {
            Medaillon(taille: 22) {
                CroissantLune(taille: 11, couleur: .white.opacity(0.72))
            }
            // La prise dépasse le dessin : 22 pt ne s'attrapent pas.
            .contentShape(Circle().inset(by: -12))
            .onTapGesture {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                action()
            }
            .scaleEffect(echelle)
            .opacity(min(p * 2.2, 1))
        }
    }

    private var echelle: Double {
        p <= 0.8 ? 0.60 + 0.575 * (p / 0.8)
                 : 1.06 - 0.06 * ((p - 0.8) / 0.2)
    }
}

// MARK: - La drop-list

/// « Très Apple : deux lignes, énormément de vide, blur noir, aucune énorme
/// modal. » Un panneau de verre `.clear` pendu à la pastille, la plaque
/// noire SUR le verre SOUS l'encre (la recette de la chambre des cards), et
/// la sélection par MISE AU POINT typographique — rien derrière le mot,
/// jamais (la loi § 13.7 du plan home). Pas de rouge sur « Remove » : la
/// destruction ne crie pas.
struct ListeEdition: View {
    /// 0 → 1, l'ouverture (curseur livré image par image par l'appelant).
    var p: Double
    var onChanger: () -> Void
    var onSupprimer: () -> Void

    @State private var sous: Int?

    static let largeur: CGFloat = 156
    static let hauteur: CGFloat = 118

    var body: some View {
        let L = Self.largeur, H = Self.hauteur
        let forme = RoundedRectangle(cornerRadius: 24, style: .continuous)
        ZStack {
            if p > 0.01 {
                GlassEffectContainer(spacing: 0) {
                    Color.clear
                        .frame(width: L, height: H)
                        .glassEffect(.clear, in: forme)
                }
                .mask { masque(forme) }
                // 0,62 et pas 0,50 : dessous il y a l'ENCRE NETTE de la
                // card (le gros chiffre) — à 0,50 le verre en réfractait un
                // fantôme tordu, le piège du chiffre-lentillé.
                forme.fill(Color.black.opacity(0.62))
                    .frame(width: L, height: H)
                    .mask { masque(forme) }
                VStack(spacing: 2) {
                    item("Change", 0)
                    item("Remove", 1)
                }
                .opacity(fen(0.45, 1))
                .offset(y: 4 * (1 - fen(0.45, 1)))
            }
        }
        .frame(width: L, height: H)
        .contentShape(forme)
        .gesture(choixGeste)
    }

    /// Le panneau NAÎT de la pastille : un masque à taille constante qui
    /// s'ouvre depuis le coin haut-droit — les bounds du verre ne bougent
    /// jamais (l'école `MenuCouronne`).
    private func masque(_ forme: RoundedRectangle) -> some View {
        forme
            .frame(width: Self.largeur, height: Self.hauteur)
            .scaleEffect(0.18 + 0.82 * adouci(fen(0, 0.7)),
                         anchor: .topTrailing)
    }

    private func item(_ titre: String, _ i: Int) -> some View {
        let s: Double = sous == i ? 1 : 0
        // ⚠️ SwiftUI n'interpole pas une graisse : deux Texts croisés.
        return ZStack {
            Text(titre).font(.inter(15, .regular)).tracking(0.4)
                .opacity(1 - s)
            Text(titre).font(.inter(15, .medium)).tracking(0.2)
                .opacity(s)
        }
        .foregroundStyle(.white.opacity(0.80 + 0.20 * s))
        .scaleEffect(1 + 0.05 * s)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .animation(.easeOut(duration: 0.14), value: sous)
    }

    /// UN SEUL DragGesture : le survol (mise au point) et le choix. Un tap
    /// simple passe par le même chemin — pose, survol, relâchement.
    private var choixGeste: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                let dedans = v.location.x > -20
                    && v.location.x < Self.largeur + 20
                    && v.location.y > -12
                    && v.location.y < Self.hauteur + 12
                let nouveau = dedans
                    ? (v.location.y < Self.hauteur / 2 ? 0 : 1) : nil
                if nouveau != sous {
                    sous = nouveau
                    if nouveau != nil {
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                }
            }
            .onEnded { _ in
                let choix = sous
                sous = nil
                guard let c = choix else { return }
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                if c == 0 { onChanger() } else { onSupprimer() }
            }
    }

    private func fen(_ a: Double, _ b: Double) -> Double {
        min(max((p - a) / (b - a), 0), 1)
    }
    private func adouci(_ x: Double) -> Double { 1 - pow(1 - x, 1.8) }
}

// MARK: - Le refus (la loi du dernier widget)

/// « Gardez au moins un widget. » Pas de rouge, pas d'alerte système : une
/// pop-up de verre flottante qui s'excuse presque — `RefusalHaptic` (les
/// deux `rigid` à 90 ms, le « non » universel maison), et elle part toute
/// seule au bout de 2,2 s.
struct RefusPopup: View {
    var p: Double

    var body: some View {
        let forme = RoundedRectangle(cornerRadius: 22, style: .continuous)
        ZStack {
            if p > 0.01 {
                // ⚠️ PEINTE, pas du verre natif : la pop-up se pose SUR la
                // phrase (30 pt d'encre nette), et le verre en réfractait
                // un fantôme RENVERSÉ au-dessus du titre — mesuré, et
                // aucune plaque ne le tue (le verre réfracte AVANT la
                // plaque, par construction). Ici le monde sous la pop-up
                // n'est que de l'encre : il n'y a rien de bon à manger,
                // donc on peint — la même leçon que la pastille.
                forme
                    .fill(RadialGradient(
                        stops: [
                            .init(color: Color(white: 0.115), location: 0.00),
                            .init(color: Color(white: 0.065), location: 0.60),
                            .init(color: Color(white: 0.040), location: 1.00),
                        ],
                        center: UnitPoint(x: 0.42, y: 0.20),
                        startRadius: 0, endRadius: 260))
                    .frame(width: 300, height: 64)
                    .overlay {
                        forme.strokeBorder(LinearGradient(
                            colors: [.white.opacity(0.20),
                                     .white.opacity(0.05)],
                            startPoint: .top, endPoint: .bottom),
                            lineWidth: 0.8)
                    }
                    .shadow(color: .black.opacity(0.55), radius: 8, y: 2)
                    .shadow(color: .black.opacity(0.35), radius: 26, y: 10)
                    .mask { masque(forme) }
                VStack(spacing: 3) {
                    Text("Keep at least one widget")
                        .font(.inter(14, .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                    Text("Your Home needs an active glance.")
                        .font(.inter(12))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .opacity(min(max((p - 0.35) / 0.65, 0), 1))
            }
        }
        .frame(width: 300, height: 64)
        .offset(y: 8 * (1 - p))
    }

    private func masque(_ forme: RoundedRectangle) -> some View {
        forme
            .frame(width: 300, height: 64)
            .scaleEffect(0.86 + 0.14 * p)
    }
}

// MARK: - La poudre d'adieu

/// LA SUPPRESSION PART EN PAILLETTES — la loi du swap (« paillettes, plus
/// jamais de dissolution ») : la mort d'un widget est un swap vers rien.
/// Cinquante-deux grains blancs, déterministes par rang, qui naissent DANS
/// la card et s'éloignent en montant. Transitoire : l'hôte démonte la vue
/// au bout de 0,9 s.
struct PoudreAdieu: View {
    let depuis: Date

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 40)) { tl in
            let t = tl.date.timeIntervalSince(depuis)
            Canvas { ctx, size in
                guard t >= 0, t < 0.85 else { return }
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                for i in 0..<52 {
                    let a1 = Double((i &* 2654435761) % 1024) / 1024
                    let a2 = Double(((i &+ 13) &* 40503) % 1024) / 1024
                    let a3 = Double(((i &+ 5) &* 2654435761) % 1024) / 1024
                    let ang = a1 * 2 * .pi
                    let r0 = 12 + 62 * a2
                    let vie = 0.34 + 0.42 * a3
                    let k = min(t / vie, 1)
                    guard k < 1 else { continue }
                    let e = 1 - pow(1 - k, 2.2)
                    let x = c.x + cos(ang) * (r0 + 34 * e)
                    let y = c.y + sin(ang) * (r0 + 34 * e) - 26 * e
                    let d = 1.0 + 1.6 * a2
                    let op = (1 - k) * (0.35 + 0.55 * a3)
                    ctx.fill(Path(ellipseIn: CGRect(x: x - d / 2, y: y - d / 2,
                                                    width: d, height: d)),
                             with: .color(.white.opacity(op)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Le reflet blanc de l'actif

/// LE WIDGET ACTIF DE LA VITRINE ne porte qu'UN fin reflet blanc sur son
/// contour — pas de grosse border, pas d'orange (et on ne RALLUME pas
/// l'or : la loi du 22-08). C'est l'anatomie du liseré des cards (deux
/// crêtes aux mêmes coins), passée toute en blanc, qui respire ±3°.
struct LisereActif: View {
    var p: Double
    /// LE REFLET SE VERSE : la crête n'apparaît pas sur place — elle
    /// arrive du flanc d'où la card vient (±80° × la distance au cran) et
    /// se cale en haut à l'atterrissage. La lumière suit le mouvement.
    var verse: Angle = .zero

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if p > 0.01 {
            TimelineView(.animation(minimumInterval: 1.0 / 12,
                                    paused: reduceMotion)) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                let a = Angle.degrees(reduceMotion ? 0
                                      : 3.0 * sin(t * 2 * .pi / 9.4))
                let forme = RoundedRectangle(cornerRadius: 0.152 * 170,
                                             style: .circular)
                ZStack {
                    forme.stroke(Self.blanc(a + verse), lineWidth: 1.4)
                    forme.stroke(Self.blanc(a + verse), lineWidth: 4.0)
                        .blur(radius: 2.6)
                        .opacity(0.50)
                }
                .opacity(p)
            }
        }
    }

    private static func blanc(_ a: Angle) -> AngularGradient {
        AngularGradient(stops: [
            .init(color: .white.opacity(0.10), location: 0.000),
            .init(color: .white.opacity(0.04), location: 0.125),
            .init(color: .white.opacity(0.14), location: 0.300),
            .init(color: .white.opacity(0.85), location: 0.366),
            .init(color: .white.opacity(0.85), location: 0.386),
            .init(color: .white.opacity(0.15), location: 0.430),
            .init(color: .white.opacity(0.05), location: 0.625),
            .init(color: .white.opacity(0.12), location: 0.800),
            .init(color: .white.opacity(0.95), location: 0.862),
            .init(color: .white.opacity(1.00), location: 0.888),
            .init(color: .white.opacity(0.85), location: 0.910),
            .init(color: .white.opacity(0.12), location: 0.950),
            .init(color: .white.opacity(0.10), location: 1.000),
        ], center: .center, angle: a)
    }
}

// MARK: - LA VITRINE

/// LE CAROUSEL SPATIAL — la mathématique du manège du booster, transposée
/// à plat : crans flottants (pas 210 pt), scrub direct, cible bornée à
/// ±2 crans de la main, ressort au lâcher, cran haptique à chaque
/// changement de centre. UN SEUL VERRE À LA FOIS : seul le widget au centre
/// porte le `glassEffect` — les voisins sont des clones peints, sombres et
/// floutés (le flou vit sur du peint, jamais sur du verre).
struct VitrineHote: View {
    let slot: Int
    /// Le catalogue offert (sans le widget déjà posé sur l'autre slot).
    let choix: [WidgetKind]
    /// Le widget actuel du slot — `nil` pour un slot fantôme (l'ajout).
    let depart: WidgetKind?
    /// La frame ÉCRAN du slot (le vol part de là, et y revient).
    let origine: CGRect
    /// LES VRAIES DONNÉES — les mêmes que la rangée : le clone qui vole
    /// est LA card, pas une doublure (mesuré : « 17.0 » en vol qui devenait
    /// « 5.5 » à l'atterrissage — deux objets, pas un).
    var faites: Int = 4
    var prevues: Int = 5
    var volume: String = "8.4"
    var volumeUnite: String = "kg"
    var jours: [CardJour] = CardJour.semaineRef
    var gain: String = "+12%"
    var moyenne: String = "1.2 kg"
    var piedSeances: String = "1 session left to hit your goal"
    var moisFaits: Set<Int>? = nil
    var hiit: HiitPeakInfo = HiitPeakInfo()
    var peak: PeakEffortInfo = PeakEffortInfo()
    var auto: Bool = false
    /// LA SORTIE COMMENCE : la page relâche son recul PENDANT que l'élu
    /// vole — pas après (« l'élu descend avec la nappe », la grammaire de
    /// fermeture du menu).
    var onSortie: () -> Void = {}
    /// Le verdict : le widget choisi, ou `nil` si on a annulé.
    var onFini: (WidgetKind?) -> Void

    @State private var p: Double = 0
    @State private var sortie = false
    @State private var elu: WidgetKind?
    @State private var offset: Double = 0
    @State private var grab: Double?
    @State private var dernierCentre = 0
    @State private var lancee = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// LA ROUE INVISIBLE : 82° par cran sur l'orbite, 230 pt de doigt par
    /// cran sous le pouce. Rien n'est dessiné — le moyeu vit dans le tiers
    /// bas, et c'est la lumière, les ombres et les trois flous qui révèlent
    /// le cercle.
    /// ⚠️ 115° était TROP LOIN (verdict « je les trouve trop éloignés ») :
    /// l'œil ne reliait plus les trois points, les nacelles se lisaient
    /// comme deux taches dans les coins et la diagonale était MORTE. Une
    /// roue se lit quand les wagons SE SUIVENT : à 82°, le voisin affleure
    /// le coin bas de l'apex le long de l'arc (~13 pt d'air), et les
    /// centres des voisins tombent sur les GOUTTIÈRES de la page (24/378).
    private static let pasAngle: Double = 82
    private static let pasPt: CGFloat = 230

    var body: some View {
        GeometryReader { g in
            // LA DÉRIVE ORBITALE DU REPOS : ±0,35° sur 7,3 s (période
            // première avec les respirations des cards) — la roue flotte,
            // jamais figée. 12 Hz suffisent, et l'horloge dort sous Reduce
            // Motion. Elle s'exprime en CRANS (0,35/115) pour entrer dans
            // le même curseur que tout le reste.
            TimelineView(.animation(minimumInterval: 1.0 / 12,
                                    paused: reduceMotion)) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                let derive = reduceMotion ? 0
                    : (0.35 / Self.pasAngle) * sin(t * 2 * .pi / 7.3)
                // Deux ponts Animatable emboîtés : `p` (l'entrée/sortie) et
                // `offset` (la roue) sont chacun livrés image par image —
                // les fenêtres, le montage du verre et LA MISE AU POINT se
                // calculent sur la VRAIE valeur, pas sur la cible d'une
                // transaction.
                Chambre(p: p) { pv in
                    Chambre(p: offset) { off in
                        scene(g, pv, off + derive)
                    }
                }
            }
        }
        .onAppear {
            guard !lancee else { return }
            lancee = true
            let i = depart.flatMap { choix.firstIndex(of: $0) } ?? 0
            offset = Double(i)
            dernierCentre = i
            withAnimation(.timingCurve(0.22, 1, 0.36, 1,
                                       duration: reduceMotion ? 0.30 : 0.62)) {
                p = 1
            }
            if auto { jouerAuto() }
            if let k = VitrineBanc.choisit, choix.contains(k) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                    if let j = choix.firstIndex(of: k) { recentrer(j) }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        confirmer(k)
                    }
                }
            }
        }
    }

    // MARK: la scène — LA ROUE INVISIBLE

    @ViewBuilder
    private func scene(_ g: GeometryProxy, _ pv: Double,
                       _ off: Double) -> some View {
        let W = g.size.width, H = g.size.height
        // Le moyeu (invisible) au tiers bas, l'orbite au quart de la
        // hauteur : l'apex trône à ~43 % de l'écran, les voisins à ±115°
        // plongent dans les coins bas, tranchés par les bords, et le
        // quatrième choix vit SOUS l'écran — il en remonte quand on tourne.
        let moyeu = CGPoint(x: W / 2, y: 0.665 * H)
        let rayon = 0.205 * H
        // LA MISE AU POINT : la distance signée au cran le plus proche.
        // Une pure fonction de `off` (livré image par image) — elle pilote
        // le flou de mouvement de l'apex, le voyage du reflet, le nom qui
        // traîne et la respiration du scrim. Aucune horloge, aucun état.
        let fracSigne = off - off.rounded()
        ZStack {
            // LE SCRIM — jamais noir total (verdict « l'écran noir non ! »),
            // et il RESPIRE avec la rotation : la pièce s'assombrit quand la
            // roue tourne, se rouvre au cran.
            Color.black.opacity((0.30 + 0.05 * min(abs(fracSigne) * 3, 1))
                                * fen(pv, 0, 0.5))
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { annuler() }

            ForEach(Array(choix.enumerated()), id: \.element) { i, kind in
                nacelle(kind, i: i, off: off, pv: pv,
                        moyeu: moyeu, rayon: rayon, fracSigne: fracSigne)
            }

            nomMoyeu(off: off, pv: pv, moyeu: moyeu, rayon: rayon,
                     fracSigne: fracSigne)
        }
        .simultaneousGesture(roueGeste(n: choix.count))
    }

    /// UNE NACELLE — droite, jamais couchée (la micro-inclinaison de ±4°
    /// max dit l'arc sans coucher l'encre : le point qui sépare la molette
    /// d'horloger de la roue de casino).
    @ViewBuilder
    private func nacelle(_ kind: WidgetKind, i: Int, off: Double,
                         pv: Double, moyeu: CGPoint, rayon: CGFloat,
                         fracSigne: Double) -> some View {
        let d = Double(i) - off
        let volant = kind == (sortie ? elu : depart)
        // LA NAISSANCE PAR L'ARC : rien n'entre par les flancs — un excès
        // d'angle qui se résorbe pousse chaque nacelle sous le bord bas,
        // échelonné par rang (les plus lointaines arrivent en dernier et
        // repartent en premier, par construction des fenêtres).
        let rang = min(abs(Int(d.rounded())), 3)
        let entree = fen(pv, 0.42 + 0.08 * Double(rang), 1.0)
        let excede = (volant || reduceMotion) ? 0
            : 55.0 * (1 - adouci(entree))
        let theta = min(max(d * Self.pasAngle
                            + (d >= 0 ? excede : -excede), -160), 160)
        if abs(theta) < 128 || volant {
            let a = abs(theta) / Self.pasAngle       // 0 à l'apex, 1 au cran
            let rad = theta * .pi / 180
            let surArc = CGPoint(x: moyeu.x + rayon * sin(rad),
                                 y: moyeu.y - rayon * cos(rad))
            // LE VOL : du slot à l'apex (et retour) — un seul curseur.
            let vol = (reduceMotion || !volant) ? 1.0
                : adouci(fen(pv, 0.15, 0.85))
            let pos = volant
                ? CGPoint(x: origine.midX + (surArc.x - origine.midX) * vol,
                          y: origine.midY + (surArc.y - origine.midY) * vol)
                : surArc
            let actif = a < 0.22 && pv > 0.92 && !sortie
            // LES TROIS FLOUS — la profondeur (en CARRÉ de l'angle : le
            // plan focal est à l'apex), et la mise au point (la roue tourne
            // floue, s'arrête nette — coupée sous Reduce Motion).
            // Les voisins restent PRÉSENTS (verdict « trop éloignés ») :
            // le flou plafonne à ~3,4 pt au cran — on doit encore LIRE le
            // widget d'à côté, pas deviner une tache.
            let flouProfondeur = 3.4 * pow(min(a, 1.3), 2)
            let flouApex = reduceMotion ? 0
                : 2.2 * min(abs(fracSigne) * 4, 1) * (1 - min(a * 3, 1))
            let am = pow(min(a, 1), 1.4)
            // Le vol raccorde l'ÉCHELLE (la rangée en édition est zoomée
            // 0,96) ; et l'apex se REFAIT en échelle avec le point
            // (1,015 → 1,00) — jamais le flou seul.
            let zOrigine = Double(origine.width) / 170
            let zVol = volant ? zOrigine + (1 - zOrigine) * vol : 1
            let echelle = (1 - 0.34 * min(a, 1.15)) * zVol
                * (1 + (actif && !reduceMotion
                        ? 0.015 * min(abs(fracSigne) * 4, 1) : 0))

            carte(kind, actif: actif)
                .frame(width: 170, height: 170)
                .overlay {
                    // LE VOILE MONTE DU PIED : la nuit de la page mange les
                    // nacelles par le bas — jamais un noir plat.
                    RoundedRectangle(cornerRadius: 0.152 * 170,
                                     style: .circular)
                        .fill(LinearGradient(
                            stops: [
                                .init(color: .black.opacity(0.55 * am),
                                      location: 0.00),
                                .init(color: .black.opacity(0.26 * am),
                                      location: 1.00),
                            ],
                            startPoint: .bottom, endPoint: .top))
                        .allowsHitTesting(false)
                }
                .overlay { LisereActif(p: actif ? 1 : 0,
                                       verse: .degrees(-80 * fracSigne)) }
                .overlay {
                    // Un voisin se tape : il monte à l'apex.
                    if !actif, pv > 0.9, !sortie {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { recentrer(i) }
                    }
                }
                .blur(radius: flouProfondeur + flouApex)
                .rotationEffect(.degrees(4 * sin(rad)))
                // UNE SEULE SOURCE, EN HAUT : l'ombre s'allonge et
                // s'adoucit en descendant l'arc — c'est elle qui vend le
                // cercle sans le dessiner.
                .shadow(color: .black.opacity(0.28 + 0.24 * min(a, 1)),
                        radius: 10 + 16 * min(a, 1),
                        y: 5 + 13 * min(a, 1))
                .scaleEffect(echelle)
                .position(pos)
                .opacity(volant ? 1 : entree)
        }
    }

    /// Le widget de la vitrine. SEUL l'actif a le verre et le doigt : les
    /// voisins sont peints et inertes.
    @ViewBuilder
    private func carte(_ kind: WidgetKind, actif: Bool) -> some View {
        let mode: CardMode = actif
            ? .vitrine(onTap: { confirmer(kind) })
            : .inerte
        switch kind {
        case .regularite:
            if let mf = moisFaits {
                CardSeances(faites: faites, prevues: prevues,
                            pied: piedSeances, p: 1,
                            lisere: true, verre: actif,
                            moisFaits: mf, interaction: mode)
            } else {
                CardSeances(faites: faites, prevues: prevues,
                            pied: piedSeances, p: 1,
                            lisere: true, verre: actif, interaction: mode)
            }
        case .volume:
            CardVolume(valeur: volume, unite: volumeUnite, jours: jours,
                       gain: gain, moyenne: moyenne, p: 1,
                       lisere: true, verre: actif, interaction: mode)
        case .hiitPeak:
            CardHiitPeak(vitesse: hiit.vitesse,
                         repetitions: hiit.repetitions,
                         pic: hiit.pic, picLargeur: hiit.picLargeur,
                         chambreLigne: hiit.chambreLigne, p: 1,
                         lisere: true, verre: actif, interaction: mode)
        case .peakEffort:
            CardPeakEffort(titre: peak.titre, valeur: peak.valeur,
                           chambreHaut: peak.chambreHaut,
                           chambreBas: peak.chambreBas,
                           nouveau: peak.nouveau, p: 1,
                           lisere: true, verre: actif, interaction: mode)
        }
    }

    /// Le nom, AU MOYEU — `01 — REGULARITY`. Il traîne sur la rotation
    /// (8 % du pas), plonge dans le creux avec un souffle de flou, et son
    /// tracking se resserre à l'atterrissage : le mot se pose.
    @ViewBuilder
    private func nomMoyeu(off: Double, pv: Double, moyeu: CGPoint,
                          rayon: CGFloat, fracSigne: Double) -> some View {
        let iC = min(max(Int(off.rounded()), 0), choix.count - 1)
        let dip = min(abs(fracSigne) * 2, 1)
        Text("\(choix[iC].numero) — \(choix[iC].nom)")
            .font(.system(size: 11, weight: .semibold))
            .tracking(2.4 + 1.2 * dip)
            .foregroundStyle(.white.opacity(0.38))
            .blur(radius: 1.5 * dip)
            .offset(x: -18 * fracSigne)
            .position(x: moyeu.x, y: moyeu.y - rayon + 85 + 30)
            .opacity((1 - dip) * fen(pv, 0.80, 1) * (sortie ? 0 : 1))
            .allowsHitTesting(false)
    }

    // MARK: le geste de la roue

    /// LA BUTÉE ÉLASTIQUE : au-delà du premier ou du dernier cran la roue
    /// se retient en tanh (±0,30 cran max) — un refus doux, jamais un mur.
    private func borneDouce(_ brut: Double, max borneMax: Double) -> Double {
        if brut < 0 { return -0.30 * tanh(-brut / 0.45) }
        if brut > borneMax {
            return borneMax + 0.30 * tanh((brut - borneMax) / 0.45)
        }
        return brut
    }

    private func roueGeste(n: Int) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { v in
                guard p >= 0.999, !sortie else { return }
                if grab == nil {
                    // Le verrou d'axe : la roue se tourne à l'horizontale.
                    guard abs(v.translation.width)
                            > abs(v.translation.height) else { return }
                    grab = offset
                }
                guard let g0 = grab else { return }
                offset = borneDouce(g0 - Double(v.translation.width)
                                    / Double(Self.pasPt),
                                    max: Double(n - 1))
                let c = min(max(Int(offset.rounded()), 0), n - 1)
                if c != dernierCentre {
                    dernierCentre = c
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            }
            .onEnded { v in
                guard let g0 = grab else { return }
                grab = nil
                let borne = Double(n - 1)
                let vel = min(max(-Double(v.velocity.width)
                                  / Double(Self.pasPt), -6), 6)
                // La cible : jamais à plus de deux crans de la main (la loi
                // du manège — une molette d'horloger, pas un jackpot).
                var cibleC = (offset + vel * 0.35).rounded()
                cibleC = min(max(cibleC, g0.rounded() - 2), g0.rounded() + 2)
                cibleC = min(max(cibleC, 0), borne)
                withAnimation(.spring(response: 0.42,
                                      dampingFraction: 0.86)) {
                    offset = cibleC
                }
                let c = Int(cibleC)
                if c != dernierCentre {
                    dernierCentre = c
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            }
    }

    private func recentrer(_ i: Int) {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            offset = Double(i)
        }
        if i != dernierCentre {
            dernierCentre = i
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    // MARK: le verdict

    private func confirmer(_ k: WidgetKind) {
        guard !sortie else { return }
        elu = k
        CommitHaptic.play()
        jouerSortie(annule: false)
    }

    private func annuler() {
        guard !sortie, p > 0.5 else { return }
        elu = depart
        jouerSortie(annule: true)
    }

    /// LA SORTIE RACONTE : les voisins s'effacent d'abord (leur fenêtre
    /// meurt dès que `p` quitte 1), puis l'élu vole vers le slot pendant
    /// que le retrait se relâche — « on voit partir ce qu'on a choisi ».
    /// Et le silence : aucune haptique à la repose.
    private func jouerSortie(annule: Bool) {
        sortie = true
        let choisi = elu
        onSortie()
        withAnimation(.timingCurve(0.30, 0, 0.20, 1,
                                   duration: reduceMotion ? 0.28 : 0.55)) {
            p = 0
        }
        DispatchQueue.main.asyncAfter(
            deadline: .now() + (reduceMotion ? 0.30 : 0.58)) {
            onFini(annule ? nil : choisi)
        }
    }

    /// `-vitrineAuto` : la roue tourne toute seule — le simulateur ne sait
    /// pas draguer, et des crans ne se jugent qu'en les regardant passer.
    private func jouerAuto() {
        Timer.scheduledTimer(withTimeInterval: 1.8, repeats: true) { _ in
            guard !sortie else { return }
            let n = choix.count
            let c = (dernierCentre + 1) % n
            dernierCentre = c
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                offset = Double(c)
            }
        }
    }

    private func fen(_ p: Double, _ a: Double, _ b: Double) -> Double {
        min(max((p - a) / (b - a), 0), 1)
    }
    private func adouci(_ x: Double) -> Double { 1 - pow(1 - x, 1.8) }
}

// MARK: - Les bancs

/// Les drapeaux du chantier. ⚠️ Chacun est AUSSI dans la liste `homeV2` de
/// `WoopApp` : un drapeau qui n'y serait pas lancerait l'app normale, et on
/// croirait le banc cassé en regardant l'ancienne page (leçon payée).
enum EditionBanc {
    /// `-editWidgets` : le mode édition s'ouvre tout seul après l'arrivée.
    static let ouvre = CommandLine.arguments.contains("-editWidgets")
    /// `-editFige <p>` : l'entrée en édition figée à un avancement.
    static let fige: Double? = {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: "-editFige"), i + 1 < a.count,
              let v = Double(a[i + 1]) else { return nil }
        return min(max(v, 0), 1)
    }()
    /// `-editListe <0|1>` : la drop-list ouverte sur ce slot.
    static let liste: Int? = {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: "-editListe"), i + 1 < a.count,
              let v = Int(a[i + 1]), (0...1).contains(v) else { return nil }
        return v
    }()
    /// `-editRefus` : joue une suppression REFUSÉE (à lancer avec
    /// `-slots regularite,vide`).
    static let refus = CommandLine.arguments.contains("-editRefus")
    /// `-editSupprime` : joue une suppression acceptée (poudre + fantôme).
    static let supprime = CommandLine.arguments.contains("-editSupprime")
}

enum VitrineBanc {
    /// `-vitrineLab` : la vitrine s'ouvre toute seule sur le slot 0.
    static let ouvre = CommandLine.arguments.contains("-vitrineLab")
    /// `-vitrineAuto` : et sa roue tourne en boucle.
    static let auto = CommandLine.arguments.contains("-vitrineAuto")
    /// `-vitrineChoisit <widget>` : la vitrine centre ce widget puis le
    /// CONFIRME toute seule — le seul moyen de vérifier en capture le vol
    /// retour, l'écriture du slot et la matérialisation sur la home.
    static let choisit: WidgetKind? = {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: "-vitrineChoisit"), i + 1 < a.count
        else { return nil }
        return WidgetKind(rawValue: a[i + 1])
    }()
}

enum SlotsBanc {
    /// `-slots <a,b>` force les deux slots au lancement — ex.
    /// `-slots regularite,vide`. Écrit dans le stockage : les bancs vivent
    /// sur le simulateur dédié.
    static let force: [String]? = {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: "-slots"), i + 1 < a.count
        else { return nil }
        let v = a[i + 1].split(separator: ",").map(String.init)
        guard !v.isEmpty else { return nil }
        return v
    }()
}
