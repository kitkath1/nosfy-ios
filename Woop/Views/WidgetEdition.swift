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
                    forme.stroke(Self.blanc(a), lineWidth: 1.4)
                    forme.stroke(Self.blanc(a), lineWidth: 4.0)
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

    private static let pas: CGFloat = 210

    var body: some View {
        GeometryReader { g in
            // Deux ponts Animatable emboîtés : `p` (l'entrée/sortie) et
            // `offset` (la roue) sont chacun livrés image par image — les
            // fenêtres et le montage du verre se calculent sur la VRAIE
            // valeur, pas sur la cible d'une transaction.
            Chambre(p: p) { pv in
                Chambre(p: offset) { off in
                    scene(g, pv, off)
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

    // MARK: la scène

    @ViewBuilder
    private func scene(_ g: GeometryProxy, _ pv: Double,
                       _ off: Double) -> some View {
        let W = g.size.width, H = g.size.height
        let cible = CGPoint(x: W / 2, y: H * 0.42)
        ZStack {
            // LE SCRIM — la home s'enfonce dans le noir, JAMAIS noir total
            // (verdict « l'écran noir non ! ») : la vidéo doit continuer de
            // nourrir le verre du widget central.
            Color.black.opacity(0.30 * fen(pv, 0, 0.5))
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { annuler() }

            ForEach(Array(choix.enumerated()), id: \.element) { i, kind in
                item(kind, i: i, off: off, pv: pv, cible: cible)
            }

            nomCentre(off: off, pv: pv, cible: cible)
        }
        .simultaneousGesture(roueGeste(n: choix.count))
    }

    @ViewBuilder
    private func item(_ kind: WidgetKind, i: Int, off: Double,
                      pv: Double, cible: CGPoint) -> some View {
        let d = Double(i) - off
        let ad = abs(d)
        let volant = kind == (sortie ? elu : depart)
        let posRoue = CGPoint(x: cible.x + CGFloat(d) * Self.pas, y: cible.y)
        // LE VOL : du slot au centre (et retour à la sortie) — un seul
        // curseur, la position est une interpolation de `pv`, jamais deux
        // `withAnimation` croisés. Reduce Motion : pas de vol, des fondus.
        let vol = reduceMotion ? 1.0 : adouci(fen(pv, 0.15, 0.85))
        let entree = fen(pv, 0.55, 1.0)
        let pos: CGPoint = volant
            ? CGPoint(x: origine.midX + (posRoue.x - origine.midX) * vol,
                      y: origine.midY + (posRoue.y - origine.midY) * vol)
            : CGPoint(x: posRoue.x + (d >= 0 ? 40 : -40) * (1 - entree),
                      y: posRoue.y)
        let actif = ad < 0.25 && pv > 0.92 && !sortie
        let flou = ad < 0.25 ? 0 : 2.6 * min(ad, 1)
        // Le vol raccorde aussi l'ÉCHELLE : en mode édition la rangée est
        // zoomée arrière (0,96) — le clone part à la taille exacte du slot
        // et grandit en volant, sinon la prise de relais saute de 4 %.
        let zOrigine = Double(origine.width) / 170
        let zVol = volant ? zOrigine + (1 - zOrigine) * vol : 1

        carte(kind, actif: actif)
            .frame(width: 170, height: 170)
            .overlay {
                // Le voile des voisins — ils reculent dans la nuit.
                RoundedRectangle(cornerRadius: 0.152 * 170, style: .circular)
                    .fill(Color.black.opacity(0.45 * min(ad, 1)))
                    .allowsHitTesting(false)
            }
            .overlay { LisereActif(p: actif ? 1 : 0) }
            .overlay {
                // Un voisin se tape : il vient au centre. (Sa card est
                // inerte — un seul widget est interactif à la fois.)
                if !actif, pv > 0.9, !sortie {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { recentrer(i) }
                }
            }
            .blur(radius: flou)
            .scaleEffect((1 - 0.14 * min(ad, 1.3))
                         * (volant ? zVol : 0.92 + 0.08 * entree))
            .position(pos)
            .opacity(volant ? 1 : entree)
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

    /// Le nom sous le centre — `01 — REGULARITY`, qui plonge à zéro entre
    /// deux crans (le texte change caché dans le creux).
    @ViewBuilder
    private func nomCentre(off: Double, pv: Double,
                           cible: CGPoint) -> some View {
        let iC = min(max(Int(off.rounded()), 0), choix.count - 1)
        let dip = 1 - min(abs(off - Double(iC)) * 2, 1)
        Text("\(choix[iC].numero) — \(choix[iC].nom)")
            .font(.system(size: 11, weight: .semibold))
            .tracking(2.4)
            .foregroundStyle(.white.opacity(0.38))
            .position(x: cible.x, y: cible.y + 85 + 28)
            .opacity(dip * fen(pv, 0.80, 1) * (sortie ? 0 : 1))
            .allowsHitTesting(false)
    }

    // MARK: le geste de la roue

    private func roueGeste(n: Int) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { v in
                guard p >= 0.999, !sortie else { return }
                if grab == nil {
                    // Le verrou d'axe : la roue est horizontale.
                    guard abs(v.translation.width)
                            > abs(v.translation.height) else { return }
                    grab = offset
                }
                guard let g0 = grab else { return }
                let borne = Double(n - 1)
                offset = min(max(g0 - Double(v.translation.width)
                                 / Double(Self.pas), -0.35), borne + 0.35)
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
                                  / Double(Self.pas), -6), 6)
                // La cible : jamais à plus de deux crans de la main (la loi
                // du manège), et jamais hors de la roue.
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
