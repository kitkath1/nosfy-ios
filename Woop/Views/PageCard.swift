import SwiftUI
import UIKit

// MARK: - PageCard — LA ROBE de page + la bande du bas (§3 : la robe
// est par page, LE PLAYER est GLOBAL)

/// LA ROBE UNIVERSELLE (plan `tools/player/PLAN-PLAYER-CARD.md`, §2.15
/// → §2.18 → §3) : chaque page est une GROSSE CARD — le haut FOND dans
/// l'heure (aucune limite, verdict 31-08), marges fines de 8 pt, coins
/// BAS seulement, liseré des flancs fondu vers le haut — et sa bande du
/// bas DÉTACHÉE : la dalle player en séance, le trait + LA LUNE hors
/// séance, RIEN pendant l'exercice actif (§2.17).
///
/// DEPUIS LE §3 (le revirement overlay) : cette vue ne porte PLUS le
/// player déployé. La dalle est un BOUTON — tap → `ouvrir()`, drag
/// arbitré par le PAN MAÎTRE de bande (`PanBande.swift`) : LE player
/// unique de la racine (`PlayerMonde.swift`) monte PAR-DESSUS tout.
/// La page ne bouge JAMAIS (la doctrine anti-bugs).
/// ⚠️ ÉTAT RÉEL DE LA LUNE (03-09) : sa prise n'est PLUS branchée —
/// `tirageLune` est orphelin, `levee` reste à 0, la lune ne se révèle
/// plus. Le bas appartient à la bande et à son pan. Sa mort ou son
/// re-logement (une zone du pan) est une DÉCISION DE KATHRYN en
/// attente (plan §5) — le code dort ici en attendant le verdict.
struct PageCard<Page: View, Dalle: View, Nav: View>: View {
    private let page: Page
    private let dalle: Dalle
    /// LA NAV DU BAS (03-09) — son PROPRE slot, que le geste du player
    /// n'enveloppe JAMAIS. C'est ce qui règle les trois bugs (tap qui ouvre
    /// le player, drag qui pilote le player, lag) : voir plan §6bis. La dalle
    /// player garde son tap+drag, la nav a le sien.
    private let nav: Nav
    private let dockH: CGFloat

    /// `true` = la dalle player dans la bande ; `false` = HORS SÉANCE :
    /// la page est PLEIN ÉCRAN (§3.4quater), le drag de la prise basse
    /// invisible soulève la card à l'élastique et révèle LA LUNE.
    private let enSeance: Bool
    /// §2.17 : `false` = AUCUNE bande (galet enclenché, chrono) — la
    /// card prend presque toute la hauteur.
    private let bandeVisible: Bool
    /// §3.4quater : la prise basse de la lune (hors séance). La home
    /// passe `false` — son tiroir possède déjà le geste du bas.
    private let luneAuDrag: Bool

    init(dockH: CGFloat = 76,
         enSeance: Bool = true,
         bandeVisible: Bool = true,
         luneAuDrag: Bool = true,
         @ViewBuilder page: () -> Page,
         @ViewBuilder dalle: () -> Dalle,
         @ViewBuilder nav: () -> Nav = { EmptyView() }) {
        self.dockH = dockH
        self.enSeance = enSeance
        self.bandeVisible = bandeVisible
        self.luneAuDrag = luneAuDrag
        self.page = page()
        self.dalle = dalle()
        self.nav = nav()
    }

    /// La porte d'onglet — seule la PageCard de l'onglet AFFICHÉ publie
    /// sa géométrie de bande au pan racine (quatre instances vivent en
    /// même temps dans le TabView : sans cette garde elles se battraient).
    @Environment(\.ongletCache) private var ongletCache

    /// La levée de L'ÉLASTIQUE LUNE (hors séance seulement) — 0…0,16.
    @State private var levee: CGFloat = 0
    @State private var dragFrom: CGFloat?
    /// LE CHIEN DE GARDE des tirages (§2.18, le piège : un DragGesture
    /// peut mourir SANS `onEnded` — payé : la lune restait ALLUMÉE).
    @State private var chienJeton = 0

    /// Le trait (grabber) + son air, au-dessus de la dalle. La cote vit
    /// dans `BandeCote` (une source, partagée avec l'arbitre de zones).
    private var grabH: CGFloat { BandeCote.grab }
    /// La descente de la dalle dans la zone home-bar — **MORTE le 04-09,
    /// verdict Kathryn** : « dès que je drag dans la partie noire, bim je
    /// quitte l'app ». La bande mordait le bas physique de 18 pt (verdict
    /// 01-09), ce qui posait la nav PILE dans la zone des gestes système
    /// d'iOS (Home/Reachability, non désactivables) — le drag du bas ne
    /// pouvait pas être fiable. Elle a TRANCHÉ : la bande SORT de la zone
    /// système, le drag redevient sûr. La cote reste une propriété pour
    /// que le jour où le débat revient, il revienne ICI.
    private var descente: CGFloat { 0 }
    /// La bande du bas au repos : trait + dalle, MOINS la descente (la
    /// card gagne autant). L'air bas de 2 pt est mort à la compaction du
    /// 04-09 (« trop haut »).
    private var bandeH: CGFloat { grabH + dockH - descente }

    var body: some View {
        GeometryReader { g in
            // ⚠️ LA RACINE VIT DANS LA ZONE SÛRE (verdict T1 : le
            // chevron coupé) — un `.ignoresSafeArea()` de racine VOLAIT
            // les insets de la page.
            let W = g.size.width
            let Hs = g.size.height
            // §3.4quinquies (« il y a un petit espace en bas ») : hors
            // séance le PLEIN ÉCRAN est PHYSIQUE — la page descend sous
            // la home bar.
            let safeBottom = g.safeAreaInsets.bottom
            // LES PAGES SONT TOUJOURS RELEVÉES (03-09) : dès que la bande est
            // là (séance OU pas), la card vit dans la zone sûre et la bande
            // occupe le bas. Le PLEIN ÉCRAN physique n'est plus le défaut hors
            // séance : il ne reste QUE pour `bandeVisible == false` (exercice
            // en cours), où la bande entière se retire.
            let hPage = bandeVisible ? Hs : Hs + safeBottom
            // La course de l'élastique lune (la même échelle qu'avant).
            let repos = max(Hs - 14 - grabH - dockH, 1)
            ZStack(alignment: .bottom) {
                // -1) LE FOND DE L'APP — le noir sur lequel la card
                //     flotte (couche interne : n'affecte pas les insets
                //     du root).
                Color.black.ignoresSafeArea()
                // 0) HORS SÉANCE : LA LUNE que la card découvre
                //    (construite à p=1, modulée — la loi de la bande
                //    exo : jamais un `p` vivant).
                if !enSeance, bandeVisible {
                    luneFond
                }
                // 1) LA CARD-PAGE — soulevée SEULEMENT par l'élastique
                //    lune (≤ 0,16 de course) ; en séance elle est
                //    IMMOBILE (le player global passe par-dessus).
                pageEnCard
                    .frame(width: W, height: hPage)
                    .offset(y: -levee * repos
                        + (bandeVisible ? 0 : safeBottom))
                // 2) LA BANDE DU BAS — TOUJOURS présente quand `bandeVisible`
                //    (séance OU pas) : elle porte la nav en permanence (loi
                //    §0, « pages toujours relevées »). Elle ne se retire que
                //    pendant l'exercice en cours (`bandeVisible == false`).
                //    L'ancienne prise-lune invisible de 30 pt a cédé la place :
                //    le bas appartient désormais à la bande et à son geste.
                if bandeVisible {
                    bande
                        .offset(y: descente)
                }
            }
            // ⚠️ **ALIGNÉ EN BAS, ET ÇA REND 17 pt À TOUTES LES PAGES** (02-09,
            // « remonte la pill nav qui est collée en bas »).
            //
            // Hors séance le plus grand enfant de ce ZStack fait `Hs +
            // safeBottom` (la card plein écran physique) ; une `.frame` de
            // hauteur `Hs` CENTRE ce qui la dépasse, donc la card débordait de
            // `safeBottom / 2` en haut ET en bas. MESURÉ sur iPhone 15 : le
            // galet du menu, à qui le code donne `.padding(.bottom, 24)`,
            // n'avait plus que **7 pt d'air** — 845 pt sur un écran de 852.
            // 24 − 7 = 17 = 34 / 2. Ce n'était donc pas un padding trop petit,
            // c'était un débordement.
            //
            // Aligné en bas, le débordement passe ENTIÈREMENT en haut — où il
            // ne coûte rien : la card n'a pas de coins hauts et « le haut fond
            // dans l'heure » (§2.18), c'est sa loi depuis le début.
            //
            // ⚠️ EN SÉANCE, RIEN NE CHANGE : `hPage == Hs`, aucun enfant ne
            // dépasse, l'alignement n'a alors aucun effet. Les quatre pages
            // hors séance remontent ensemble — home, exercices, progress,
            // fiche — et c'est voulu : le défaut était commun.
            .frame(width: W, height: Hs, alignment: .bottom)
        }
        // LA VISIBILITÉ SE PUBLIE MÊME BANDE DÉMONTÉE : pendant
        // l'exercice (`bandeVisible == false`) la bande n'existe plus et
        // son `onGeometryChange` ne parle plus — sans ces lignes, le pan
        // racine garderait une porte OUVERTE sur un rect périmé.
        .onChange(of: bandeVisible, initial: true) { _, v in
            guard !ongletCache else { return }
            NavEtat.shared.bandeVisiblePubliee = v
            NavEtat.shared.bandeEnSeance = enSeance
        }
        .onChange(of: ongletCache) { _, cache in
            if !cache {
                NavEtat.shared.bandeVisiblePubliee = bandeVisible
                NavEtat.shared.bandeEnSeance = enSeance
            }
        }
        // (Le bouclier système NE vit PLUS ici : une préférence posée à
        //  plusieurs niveaux imbriqués sur 4 onglets montés est le motif
        //  « Bound preference updated multiple times per frame » — suspect
        //  n°1 du GEL du 03-09. UN seul émetteur : le TabView du châssis,
        //  WoopApp. Voir tools/nav/PLAN-GESTE-SYSTEME.md + le plan final.)
    }

    // MARK: la bande (en séance) — la dalle est un BOUTON

    /// La hauteur canonique de la dalle player — INCHANGÉE (l'invariant
    /// fouetté). En séance elle vit au-dessus de la nav ; hors séance elle
    /// n'existe pas et la nav prend toute la bande. La COTE vit dans
    /// `BandeCote` (PanBande.swift) : une seule source, consommée aussi
    /// par l'arbitre de zones.
    private var dalleH: CGFloat { BandeCote.dalle }

    private var bande: some View {
        VStack(spacing: 0) {
            // (LE TRAIT EST MORT le 04-09 : « enlève le petit trait,
            //  ça n'a plus d'intérêt » — il ne portait plus de geste
            //  depuis que le TAP de la nav l'efface. La bande gagne
            //  toute sa hauteur : `BandeCote.grab` est à zéro.)
            // (LA DALLE A QUITTÉ LA BANDE le 04-09 : le player est la
            //  PILULE VAGABONDE, montée au châssis. La bande ne porte
            //  plus QUE la nav — le paramètre `dalle:` survit pour les
            //  bancs, il n'est plus rendu ici.)
            // LA NAV — ses taps à elle (glyphes, dépli en mini) ; son drag
            // vit lui aussi chez le pan maître.
            nav
        }
        // Les TAPS SwiftUI deviennent sourds dès que le monde du player
        // est monté (le yoyo mort — le toucher-sous-le-noir du vol de
        // fermeture). Le PAN, lui, vit à la FENÊTRE (NavPanHote, racine)
        // et n'est pas concerné par cette porte.
        .allowsHitTesting(!PlayerEtat.shared.monte)
        // LA PUBLICATION DE GÉOMÉTRIE (plan final 03-09, étape 2) : la
        // SEULE PageCard visible publie le rect FENÊTRE de sa bande vers
        // `NavEtat` — c'est la porte du pan racine.
        // ⚠️ `frame(in:.global)` INCLUT DÉJÀ l'`.offset(y: descente)` des
        // ancêtres — MESURÉ au banc de fouettage (le double-décalage
        // faisait viser la porte 18 pt trop bas et affaiblissait la
        // parade anti-strip-système d'autant). La loi 39f95f9 parle du
        // HIT-TEST, pas de la lecture de géométrie : on publie TEL QUEL.
        .onGeometryChange(for: CGRect.self) {
            $0.frame(in: .global)
        } action: { r in
            guard !ongletCache else { return }
            NavEtat.shared.bandeRectFenetre = r
            NavEtat.shared.bandeEnSeance = enSeance
            NavEtat.shared.bandeVisiblePubliee = bandeVisible
        }
    }

    // MARK: la robe de card

    /// LA GROSSE CARD (§2.15→§2.18) : marges 8, coins BAS seulement, le
    /// HAUT FOND dans l'heure, le liseré meurt vers le haut. La card se
    /// TERMINE au-dessus de la bande (padding bas).
    private var pageEnCard: some View {
        page
            // LE CONTOUR DE SÉANCE — DANS LA CARD, jamais sur l'écran (verdict
            // 02-09 : « ça doit bouger que dans la card, pas dans le player »).
            // Posé AVANT le `clipShape` : la braise est ainsi taillée par la
            // robe elle-même, donc elle s'arrête net au bas de la card et la
            // bande du player reste à elle.
            .overlay { BordSeance(actif: enSeance || BordSeance.banc) }
            .clipShape(Self.robeCard)
            // §3.4quater (verdict 01-09) : MARGES 0, LISERÉ MORT
            // (« padding noir à supprimer comme leur border ») — la card
            // va BORD À BORD, elle ne se lit plus que par son BAS.
            // HORS SÉANCE : PLEIN ÉCRAN (padding bas 0) — seul
            // l'élastique lune la soulève.
            .padding(.bottom, bandeVisible ? bandeH : 0)
            .animation(.easeInOut(duration: 0.25), value: bandeVisible)
            // ⚠️ le @Query des pages arrive APRÈS la première image :
            // sans cette ligne, la card CLAQUE à l'atterrissage.
            .animation(.easeInOut(duration: 0.25), value: enSeance)
            // ⚠️ LE SNAP DE 52 pt (03-09, workflow fluidité — certain à
            // la lecture) : le commit du repli change `dockH` (76⇄24,
            // 152⇄100) donc `bandeH` donc ce padding — et un
            // `.animation(value:)` inerte NEUTRALISE le `withAnimation`
            // ambiant de `poser()` pour son sous-arbre : la nav glissait,
            // la card SAUTAIT. Même durée que le commit (0,25 s).
            .animation(.easeInOut(duration: 0.25), value: dockH)
    }

    /// Coins BAS seulement — le haut fond dans le châssis (§2.18).
    private static var robeCard: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 0, bottomLeadingRadius: 30,
            bottomTrailingRadius: 30, topTrailingRadius: 0,
            style: .continuous)
    }

    // MARK: la lune (hors séance)

    /// LE SECRET (§2.14) — construite à p = 1, seule sa NAISSANCE est
    /// modulée (opacité + échelle) par la levée.
    private var luneFond: some View {
        let n = min(1, levee * 7)
        return VStack(spacing: 0) {
            Spacer(minLength: 0)
            LuneSecrete(p: 1)
                .opacity(Double(n))
                .scaleEffect(0.82 + 0.18 * n)
                .padding(.bottom, 46)
        }
        .frame(maxWidth: .infinity)
    }

    /// L'ÉLASTIQUE (tanh, ~16 % de course max) ; au relâcher, toujours
    /// le retour — et le CHIEN commet si le geste meurt sans onEnded.
    private func tirageLune(course: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .onChanged { v in
                if dragFrom == nil { dragFrom = levee }
                let brut = max(0, -v.translation.height / course)
                levee = 0.16 * CGFloat(tanh(Double(brut) * 7))
                armerChien { ranger() }
            }
            .onEnded { _ in
                chienJeton += 1
                dragFrom = nil
                ranger()
            }
    }

    private func armerChien(_ commettre: @escaping () -> Void) {
        chienJeton += 1
        let jeton = chienJeton
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            guard jeton == chienJeton, dragFrom != nil else { return }
            dragFrom = nil
            commettre()
        }
    }

    private func ranger() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            levee = 0
        }
    }
}

// MARK: - Les petits objets du player déployé (consommés par
// PlayerMonde — vues PARTAGÉES, jamais deux copies qui divergent)

/// LA BARRE BLANCHE — la progression au déployé : son DÉGRADÉ COULISSE
/// le long du segment rempli, à l'horloge LOCALE (le pattern validé du
/// liseré de la molette — un `repeatForever` posé par `withAnimation`
/// se fait avaler quand le parent est ré-évalué).
struct BarreBlancheAnimee: View {
    var progress: Double
    /// §3.4quater fluidité : l'horloge se TAIT pendant le vol et au
    /// repos — elle ne tourne que le player POSÉ.
    /// ⚠️ SANS DÉFAUT (chantier chauffe 03-09, item 2) : le `= true`
    /// permissif a laissé la comète de la dalle battre à 30 Hz sur
    /// chaque page en séance. Chaque site CHOISIT sa porte, le
    /// compilateur y veille.
    var vivante: Bool

    var body: some View {
        GeometryReader { g in
            let w = g.size.width * min(max(progress, 0.04), 1)
            TimelineView(.animation(minimumInterval: 1.0 / 30.0,
                                    paused: !vivante)) { tl in
                let clock = tl.date.timeIntervalSinceReferenceDate
                let u = CGFloat(
                    clock.truncatingRemainder(dividingBy: 2.2) / 2.2)
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.14))
                    // ⚠️ LE CONTRASTE FAIT LA COMÈTE (payé v9.3) : une
                    // comète blanche sur un segment à 0,92 était
                    // INVISIBLE (255+n=255). Le segment tient à 0,62.
                    Capsule().fill(Color.white.opacity(0.62))
                        .frame(width: w)
                        .overlay(alignment: .leading) {
                            LinearGradient(
                                colors: [.clear, .white, .clear],
                                startPoint: .leading, endPoint: .trailing)
                                .frame(width: 88)
                                .offset(x: u * (w + 88) - 88)
                        }
                        .clipShape(Capsule())
                }
            }
        }
    }
}

/// LA FORME TICKET DE CINÉMA — coins doux, DEUX ENCOCHES
/// semi-circulaires au milieu des flancs.
struct TicketShape: Shape {
    var coin: CGFloat = 9
    var encoche: CGFloat = 5.5

    func path(in r: CGRect) -> Path {
        let base = Path(roundedRect: r, cornerRadius: coin)
        let gauche = Path(ellipseIn: CGRect(
            x: r.minX - encoche, y: r.midY - encoche,
            width: encoche * 2, height: encoche * 2))
        let droite = Path(ellipseIn: CGRect(
            x: r.maxX - encoche, y: r.midY - encoche,
            width: encoche * 2, height: encoche * 2))
        return base.subtracting(gauche).subtracting(droite)
    }
}

/// LE BADGE NÉON — la recette de la mini-card ×2 en format ticket :
/// il dit les sets FAITS (jamais un total — il n'existe pas).
struct BadgeSetsNeon: View {
    var texte: String
    /// §3.4septies F1 : la respiration ne vit que POSÉ — en boucle
    /// infinie permanente, elle invalidait le pied pendant le drag et
    /// chauffait l'arbre pré-monté.
    var vivant: Bool = true
    @State private var respire = false

    var body: some View {
        Text(texte)
            .font(.system(size: 9, weight: .bold))
            .monospacedDigit()
            .tracking(0.4)
            .foregroundStyle(Color(white: 0.98))
            .shadow(color: .white.opacity(respire ? 0.90 : 0.55), radius: 2)
            .shadow(color: .white.opacity(respire ? 0.38 : 0.18), radius: 7)
            .padding(.leading, 15)
            .padding(.trailing, 9)
            .padding(.vertical, 4)
            .background {
                TicketShape()
                    .fill(LinearGradient(colors: [Color(white: 0.13),
                                                  Color(white: 0.05)],
                                         startPoint: .top, endPoint: .bottom))
                TicketShape()
                    .stroke(
                        LinearGradient(
                            stops: [.init(color: .white.opacity(0.26),
                                          location: 0),
                                    .init(color: .white.opacity(0.04),
                                          location: 0.5),
                                    .init(color: .clear, location: 1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing),
                        lineWidth: 1)
            }
            .overlay(alignment: .leading) {
                GeometryReader { gg in
                    Path { p in
                        p.move(to: CGPoint(x: 0.5, y: 3))
                        p.addLine(to: CGPoint(x: 0.5,
                                              y: gg.size.height - 3))
                    }
                    .stroke(Color.white.opacity(0.28),
                            style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                }
                .frame(width: 1)
                .offset(x: 9)
            }
            .rotationEffect(.degrees(-7))
            .onChange(of: vivant, initial: true) { _, v in
                if v {
                    withAnimation(.easeInOut(duration: 1.7)
                        .repeatForever(autoreverses: true)) {
                        respire = true
                    }
                } else {
                    var t = Transaction()
                    t.disablesAnimations = true
                    withTransaction(t) { respire = false }
                }
            }
    }
}

/// LA SCÈNE — la zone d'atterrissage du héros, le titre de l'exercice
/// EN COURS, la barre-comète, la partition aux deux fondus.
struct ScenePlayer: View {
    var levee: CGFloat
    var titre: String
    var groupes: [SlateGroupe]
    @Binding var deplies: Set<String>
    /// §3.4octies : le MASK des fondus ne vit que POSÉ — une
    /// re-composition offscreen par frame pendant le vol, sinon.
    var pose: Bool = true
    /// §3.4decies (verdict : « j'arrive pas à drag vers le bas ») — la
    /// liste occupe tout le centre et son ScrollView possédait le
    /// geste MÊME SANS rien à scroller. Mesuré, jamais deviné.
    @State private var contenuH: CGFloat = 0
    @State private var cadreH: CGFloat = 1

    var body: some View {
        let t = min(max(levee, 0), 1)
        VStack(spacing: 0) {
            // §3.4quater (« l'image du jour est sur la progress bar ») :
            // le CD posé (centre 176, bas ~289) vivait SUR le titre —
            // la scène commence désormais SOUS lui.
            Spacer().frame(height: 305)
            Text(titre)
                .font(.inter(21, .semibold))
                .foregroundStyle(Color.white.opacity(0.94))
                .lineLimit(1)
            // Aucune fraction affichée (on ne sait jamais où s'arrête
            // le user) — la barre parle seule.
            BarreBlancheAnimee(progress: 0.6, vivante: t > 0.98)
                .frame(width: 220, height: 5)
                .padding(.top, 14)
            Spacer().frame(height: 22)
            SlateListe(groupes: groupes, courant: "courant",
                       basAir: 260,
                       onContentHeight: { contenuH = $0 },
                       deplies: $deplies)
                .equatable()
                // LA LISTE NE CAPTURE QUE SI ELLE SCROLLE : contenu ≤
                // cadre = le drag TRAVERSE au player (le centre de
                // l'écran redevient une prise). `scrollDisabled` agit
                // par environnement — l'EquatableView n'y peut rien.
                .scrollDisabled(contenuH <= cadreH + 1)
                .onGeometryChange(for: CGFloat.self) {
                    $0.size.height
                } action: { cadreH = $0 }
                .padding(.horizontal, 12)
                .mask {
                    if pose {
                        LinearGradient(stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.07),
                            .init(color: .black, location: 0.68),
                            .init(color: .clear, location: 0.87),
                        ], startPoint: .top, endPoint: .bottom)
                    } else {
                        Rectangle()
                    }
                }
        }
        .opacity(Double(max(0, (t - 0.45) * 2.2)))
    }
}

/// LE PIED — le héros en vol (mini-card jour + ticket), le médaillon
/// stop né en fondu, « Page exercices » en verre. Les boutons ne
/// s'arment que POSÉS (t > 0,95).
struct PiedPlayer: View {
    var levee: CGFloat
    /// §3.4octies : le verre natif ne vit que POSÉ (60 → 14 img/s
    /// sinon) — en vol, la doublure mate.
    var pose: Bool = true
    var jour: Date
    var sticker: String
    var setsFaits: Int
    var stopActif: Bool = false
    var onStop: () -> Void = {}
    var pageExosActif: Bool = false
    var onPageExercices: () -> Void = {}

    var body: some View {
        GeometryReader { gp in
            let t = min(max(levee, 0), 1)
            let x0: CGFloat = 41, y0: CGFloat = 18 + 38
            let x1 = gp.size.width / 2, y1: CGFloat = 176
            ZStack {
                MiniCardJour(date: jour, sticker: sticker,
                             stickerBasGauche: true)
                    .overlay(alignment: .trailing) {
                        BadgeSetsNeon(texte: "\(setsFaits) SETS",
                                      vivant: t > 0.98)
                            .offset(x: 26)
                            .opacity(Double(max(0, (t - 0.25) * 1.6)))
                    }
                    .scaleEffect(0.58 + 1.12 * t)
                    .position(x: x0 + (x1 - x0) * t, y: y0 + (y1 - y0) * t)
                    .opacity(t > 0.03 ? 1 : 0)
                    .allowsHitTesting(false)

                MedaillonStop(lueur: true, action: onStop)
                    .scaleEffect(1.35)
                    .position(x: x1, y: gp.size.height - 140)
                    .opacity(Double(max(0, (t - 0.55) * 2.2)))
                    .allowsHitTesting(stopActif && t > 0.95)

                Text("Page exercices")
                    .font(.inter(15, .semibold))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 13)
                    .modifier(VerreOuMat(pose: pose))
                    .contentShape(Capsule())
                    .highPriorityGesture(
                        TapGesture().onEnded { onPageExercices() })
                    .position(x: x1, y: gp.size.height - 80)
                    .opacity(Double(max(0, (t - 0.6) * 2.5)))
                    .allowsHitTesting(pageExosActif && t > 0.95)
            }
        }
    }
}

// MARK: - Le banc : `-pageCardLab`

/// Banc de LA ROBE (§3 : le player se teste au GLOBAL, via
/// `-playerOuvert` / `-playerCycle`) : la card, la bande, la dalle
/// bouton, la lune (`-pageCardLune`).
struct PageCardLab: View {
    private static let demoStart = Date().addingTimeInterval(-27 * 60)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            PageCard(
                     enSeance: !CommandLine.arguments
                         .contains("-pageCardLune"),
                     page: { demoPage },
                     dalle: { demoDalle })
        }
        .preferredColorScheme(.dark)
    }

    private var demoDalle: some View {
        WorkoutPill(exercise: ExerciseCatalog.all[0],
                    progress: 0.4,
                    startedAt: Self.demoStart,
                    docked: true,
                    lisere: false,
                    doneSeries: 2,
                    exoCount: 3,
                    jour: Self.demoStart,
                    jourSticker: "sticker-flamme",
                    titreCourant: ExerciseCatalog.all[0].name)
    }

    /// LA PAGE bidon : NOIRE plein cadre (la robe vient du moteur), du
    /// contenu RÉALISTE jusqu'en bas.
    private var demoPage: some View {
        ZStack(alignment: .top) {
            Color.black
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 66)
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 96, weight: .thin))
                    .foregroundStyle(.white.opacity(0.42))
                    .frame(maxWidth: .infinity)
                Spacer().frame(height: 30)
                Text("Développé couché à la barre")
                    .font(.inter(30, .bold))
                    .foregroundStyle(.white)
                Text("Haut · Pectoraux, triceps, épaules")
                    .font(.inter(15, .regular))
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.top, 6)
                Spacer().frame(height: 34)
                ForEach(1..<4) { i in
                    HStack(spacing: 0) {
                        Text("Set \(i)")
                            .font(.inter(16, .medium))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(width: 70, alignment: .leading)
                        Text("12 reps · 20 kg · 60 s")
                            .font(.inter(15, .regular))
                            .foregroundStyle(.white.opacity(0.5))
                        Spacer()
                        Text("Upcoming")
                            .font(.inter(13, .regular))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .padding(.vertical, 15)
                }
                Spacer(minLength: 0)
            }
            .padding(26)
        }
    }
}

/// §3.4octies — LE VERRE OU LA DOUBLURE : le verre natif ne vit que le
/// player POSÉ (la loi payée : un verre aux bounds vivants re-échantillonne
/// son fond à chaque frame, 60 → 14 img/s) ; en vol, une capsule mate.
struct VerreOuMat: ViewModifier {
    var pose: Bool

    func body(content: Content) -> some View {
        if pose {
            content
                .glassEffect(.regular.tint(Color.black.opacity(0.35))
                                 .interactive(),
                             in: .capsule)
        } else {
            content
                .background(
                    Capsule().fill(Color.black.opacity(0.45)))
                .overlay(
                    Capsule().strokeBorder(
                        Color.white.opacity(0.12), lineWidth: 1))
        }
    }
}
