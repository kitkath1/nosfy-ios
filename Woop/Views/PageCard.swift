import SwiftUI
import UIKit

// MARK: - PageCard — le player-card qui grandit et pousse la page (tranche 0)

/// UN COMPOSANT, UNE LOI (plan `tools/player/PLAN-PLAYER-CARD.md`, §2.6 v6).
///
/// LE LAYOUT : chaque page est une grosse card qui flotte sur le fond noir ;
/// le player vit SOUS elle, détaché, avec son trait. LE MOUVEMENT : drag ↑ →
/// le player-card NOIR grandit et POUSSE la card-page en CONTACT 1:1 — elle
/// sort par le haut à la vitesse où il monte, objet entier, NETTE jusqu'à
/// mi-course ; le flou n'est que sa dissolution finale. Drag ↓ (ou flick
/// depuis la partition) : tout se rejoue à l'envers.
///
/// LES LOIS v6 (payées au 0/10 du 30-08) :
/// A. PUSH 1:1 — `offset_card = -levee × course` (la course DU player) : le
///    contact fait le « poussé », jamais une évaporation sur place.
/// D. NOIR ABSOLU — aucun aplat gris : le corps du player est NOIR PUR,
///    l'objet se lit par ses coins, son trait et la lumière.
/// E. PAS D'EFFET CALQUE — la vue VIVANTE est poussée (un offset ne coûte
///    rien) jusqu'à mi-course ; le snapshot flouté ne prend le relais qu'au
///    moment où le flou commence (levee > 0,5).
/// F. UNE SEULE MATIÈRE — à pleine levée rien ne dépasse derrière le sommet
///    (opacité de la card → 0), pas de plaque, pas de fond qui tranche.
/// G. LA FLUIDITÉ SE MESURE — la capture se fait UNE fois à la prise ; le
///    hitch éventuel se traque à la sonde sur l'appareil, pas à l'oreille.
struct PageCard<Page: View, Dalle: View, Detail: View, Pied: View>: View {
    private let page: Page
    private let dalle: (CGFloat) -> Dalle
    private let detail: (CGFloat) -> Detail
    private let pied: (CGFloat) -> Pied
    private let dockH: CGFloat

    /// `autoCycle` (banc) : joue la cinématique complète en boucle —
    /// capture, montée spring, pause, rangement — pour FILMER l'animation
    /// globale au simulateur sans doigt.
    private let autoCycle: Bool
    /// LE LAYOUT UNIVERSEL (§2.14) : `true` = le player dessous (la dalle,
    /// le déployé) ; `false` = HORS SÉANCE — le trait seul invite, le drag
    /// ÉLASTIQUE soulève la card et révèle LA LUNE (le secret de la home,
    /// homogène partout).
    private let enSeance: Bool
    /// §2.17 (verdict 31-08 : « le player n'arrive JAMAIS dès que le galet
    /// est enclenché et pendant le chrono ») : `false` = AUCUNE bande — ni
    /// dalle, ni trait, ni lune ; la card prend presque toute la hauteur.
    /// L'hôte le dérive de son état (plongée, série en cours).
    private let bandeVisible: Bool

    init(dockH: CGFloat = 76,
         leveeInitiale: CGFloat = 0,
         autoCycle: Bool = false,
         enSeance: Bool = true,
         bandeVisible: Bool = true,
         @ViewBuilder page: () -> Page,
         @ViewBuilder dalle: @escaping (CGFloat) -> Dalle,
         @ViewBuilder detail: @escaping (CGFloat) -> Detail,
         @ViewBuilder pied: @escaping (CGFloat) -> Pied) {
        self.dockH = dockH
        self.autoCycle = autoCycle
        self.enSeance = enSeance
        self.bandeVisible = bandeVisible
        self.page = page()
        self.dalle = dalle
        self.detail = detail
        self.pied = pied
        _levee = State(initialValue: leveeInitiale)
    }

    /// 0 : card nette + dalle détachée en bas. 1 : player déployé, card partie.
    @State private var levee: CGFloat
    /// La levée au début du geste — le doigt reprend où il attrape.
    @State private var dragFrom: CGFloat?
    /// LE SNAPSHOT FIGÉ de la card-page — capturé UNE fois à la prise, montré
    /// SEULEMENT quand le flou commence (E) : avant, la vue vivante est
    /// poussée telle quelle.
    @State private var snap: Image?
    @State private var snapJeton = 0
    /// LE CHIEN DE GARDE des tirages (§2.18, le piège de la maison : un
    /// DragGesture peut mourir SANS `onEnded` — pointeur sorti de la
    /// fenêtre, présentation, Reachability ; payé : la lune restait
    /// ALLUMÉE au repos). Réarmé à chaque frame ; s'il aboie, il COMMET
    /// l'état stable le plus proche — jamais un simple reset.
    @State private var chienJeton = 0
    /// L'échelle RÉELLE de l'écran (un snapshot 2x sur écran 3x = flou
    /// permanent, payé v5).
    @Environment(\.displayScale) private var displayScale

    /// Le trait (grabber) + son air, au-dessus de la dalle.
    private var grabH: CGFloat { 18 }
    /// La bande du bas au repos (en zone sûre) : trait + dalle + 6 pt d'air.
    private var bandeH: CGFloat { grabH + dockH + 6 }

    // Les courbes du rendu (E/F) : net jusqu'à mi-course, dissolution finale.
    private func lisse(_ u: CGFloat) -> CGFloat {
        let t = min(max(u, 0), 1); return t * t * (3 - 2 * t)
    }
    // DEUX CARDS NETTES D'ABORD (~40 % de course), PUIS LA DISSOLUTION
    // (§2.13 bis — « il manque le blur de disparition comme on avait ») :
    // le flou monte sur la seconde moitié du vol, l'extinction suit.
    private var flouCard: CGFloat { 24 * lisse((levee - 0.40) / 0.5) }
    private var opaciteCard: CGFloat { 1 - lisse((levee - 0.55) / 0.35) }

    var body: some View {
        GeometryReader { g in
            // ⚠️ LA RACINE VIT DANS LA ZONE SÛRE (verdict T1 : le chevron de
            // la fiche coupé, le retour mort) — un `.ignoresSafeArea()` de
            // racine VOLAIT les insets de la page : ses GeometryReader
            // internes lisaient zéro, le header remontait sous la status
            // bar. La page garde ses insets ; SEUL le player plonge au bord
            // physique du bas (l'offset +safeBottom).
            let W = g.size.width
            let Hs = g.size.height
            let safeBottom = g.safeAreaInsets.bottom
            // Le corps à TAILLE FINALE : de 8 pt sous le haut sûr jusqu'au
            // bord PHYSIQUE du bas.
            let corpsH = max(Hs + safeBottom - 8, 1)
            // La course : au repos, le bas de la dalle vit à 6 pt au-dessus
            // de l'indicateur.
            let repos = max(Hs - 14 - grabH - dockH, 1)
            ZStack(alignment: .bottom) {
                // -1) LE FOND DE L'APP — le noir sur lequel la card flotte
                //     (§2.15 : la page n'atteint plus les bords, le fond
                //     vient du moteur). Couche INTERNE : elle n'affecte pas
                //     les insets du root (le bug T1 venait du root).
                Color.black.ignoresSafeArea()
                // 0) HORS SÉANCE : LA LUNE dans la nuit que la card découvre
                //    (construite à p=1, modulée par-dessus — la loi de la
                //    bande exo : jamais un `p` vivant, trois ombres).
                if !enSeance, bandeVisible {
                    luneFond
                }
                // 1) LA CARD-PAGE — la GROSSE CARD PERMANENTE (§2.15) :
                //    coins, marges et liseré posés par `pageEnCard`, dans un
                //    cadre plein (les marges vivent DANS le cadre — le
                //    layout ne bouge pas au swap snapshot). Poussée en
                //    CONTACT 1:1, coupée au cadre.
                pageLayer
                    .frame(width: W, height: Hs)
                    .blur(radius: flouCard)
                    .opacity(Double(opaciteCard))
                    .offset(y: -levee * repos)
                    .frame(width: W, height: Hs, alignment: .top)
                    .clipped()
                // 2) LE PLAYER-CARD — noir pur, taille finale ; lui seul
                //    plonge au bord physique (le +safeBottom). EN SÉANCE.
                if enSeance, bandeVisible {
                    corpsPlayer(course: repos, zone: CGSize(width: W,
                                                            height: Hs))
                        .frame(width: W, height: corpsH,
                               alignment: .top)
                        .offset(y: safeBottom + (1 - levee) * repos)
                } else if bandeVisible {
                    // LE TRAIT SEUL — l'invitation hors séance : le drag
                    // élastique soulève la card, la lune se lève dessous.
                    Capsule()
                        .fill(Color.white.opacity(0.28))
                        .frame(width: 36, height: 4)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .contentShape(Rectangle())
                        .gesture(tirageLune(
                            course: repos,
                            zone: CGSize(width: W, height: Hs)))
                }
            }
            .frame(width: W, height: Hs)
            // LA CINÉMATIQUE DU BANC : le cycle complet en boucle, avec la
            // vraie capture à chaque montée (fidèle au geste).
            .task(id: autoCycle) {
                guard autoCycle, enSeance else { return }
                let zone = CGSize(width: g.size.width, height: Hs)
                try? await Task.sleep(for: .seconds(1.2))
                while !Task.isCancelled {
                    capture(zone: zone)
                    // La capture (30-80 ms) ne doit pas MANGER le début du
                    // vol : une frame de respiration avant d'animer, et une
                    // montée de démo plus lente — le vol du héros se LIT.
                    try? await Task.sleep(for: .milliseconds(60))
                    withAnimation(.spring(response: 0.85,
                                          dampingFraction: 0.88)) {
                        levee = 1
                    }
                    try? await Task.sleep(for: .seconds(2.4))
                    if Task.isCancelled { return }
                    ranger()
                    try? await Task.sleep(for: .seconds(1.6))
                }
            }
            // LE SPOTLIGHT — une LUMIÈRE, pas une nappe (v5 : la « couche »
            // claire était un radial trop fort au bord trop court). Long
            // fondu additif, très doux, né avec la levée.
            .overlay(alignment: .top) {
                // §2.19 : la lumière monte JUSQU'AU CHÂSSIS — coupée à la
                // safe top, elle laissait la status bar noire pure :
                // c'était ÇA, « la barre noire une fois le player
                // ouvert ». (`ignoresSafeArea` sur l'enfant d'un overlay
                // ne l'étendait presque pas — mesuré : la mécanique frame
                // étendu + offset, elle, ne ment pas.)
                let safeTop = g.safeAreaInsets.top
                RadialGradient(
                    stops: [
                        .init(color: Color.white.opacity(0.12), location: 0),
                        .init(color: Color.white.opacity(0.04),
                              location: 0.45),
                        .init(color: .clear, location: 1),
                    ],
                    center: UnitPoint(x: 0.5, y: 0.0),
                    startRadius: 0, endRadius: 460)
                .frame(height: 340 + safeTop)
                .offset(y: -safeTop)
                .blendMode(.plusLighter)
                .opacity(Double(levee))
                .allowsHitTesting(false)
            }
        }
        // (Plus de `.ignoresSafeArea()` racine — le bug du chevron coupé.)
    }

    // MARK: La card-page

    @ViewBuilder
    private var pageLayer: some View {
        if let snap {
            // LE SNAPSHOT (T1.2, le pattern app-switcher) : dès la PRISE la
            // page vivante est remplacée par son image morte — l'offset ne
            // coûte rien (la vraie fiche porte vidéos et shaders : la
            // pousser vivante était le « pas fluide »). L'image contient
            // DÉJÀ la card (coins, marges, liseré — §2.15) : rien à
            // habiller, la card — déjà card — est poussée telle quelle.
            snap.resizable()
        } else {
            pageEnCard
        }
    }

    /// LA GROSSE CARD PERMANENTE (§2.15, verdict 30-08 : « toute la page
    /// détail EST une card, comme ma capture ») : la page vit dans la card
    /// DÈS LE REPOS — coins 30, marges fines (12 latéral, 6 sous le haut
    /// sûr), liseré discret — et la card SE TERMINE au-dessus de la bande
    /// du player (le padding bas remplace l'inset d'avant). Le clip ROGNE
    /// LE DESSIN sans toucher au layout (pas le piège T1.2 du cadre
    /// raccourci) ; le padding est un « iPhone un peu plus étroit », la
    /// page s'y adapte (ses `safeAreaInsets` internes lisent 0). LA MÊME
    /// vue à l'écran et dans la capture : le swap vivant→snapshot est
    /// invisible.
    private var pageEnCard: some View {
        page
            .clipShape(Self.robeCard)
            .overlay(
                Self.robeCard
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                    // §2.18 : LE LISERÉ MEURT VERS LE HAUT — jamais une
                    // ligne en travers sous l'heure, les flancs fondent.
                    .mask(LinearGradient(
                        stops: [.init(color: .clear, location: 0),
                                .init(color: .black, location: 0.14)],
                        startPoint: .top, endPoint: .bottom)))
            // Marges FINES (verdict 31-08 : « sur le côté c'est trop
            // espacé ») : 8 pt — invisibles en haut (noir sur noir),
            // structurantes en bas.
            .padding(.horizontal, 8)
            // §2.18 : AUCUNE limite en haut (« hors de question ») — pas
            // de padding top : le noir de la page FOND dans le noir de
            // l'app jusque sous l'heure, comme home et exercices.
            // §2.17 : bande cachée (galet enclenché, chrono) = la card
            // reprend presque tout — le changement de hauteur est UNIQUE
            // par événement (jamais par image), animé ici même.
            .padding(.bottom, bandeVisible ? (enSeance ? bandeH : 34) : 12)
            .animation(.easeInOut(duration: 0.25), value: bandeVisible)
    }

    /// La robe §2.18 : coins BAS seulement — le haut fond dans le châssis
    /// (la « limite » sous l'heure était une invention, verdict 31-08).
    private static var robeCard: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 0, bottomLeadingRadius: 30,
            bottomTrailingRadius: 30, topTrailingRadius: 0,
            style: .continuous)
    }

    /// LA LUNE (§2.14, hors séance) — le secret de la home, réutilisé tel
    /// quel : construite à p = 1, seule sa NAISSANCE est modulée (opacité +
    /// échelle) par la levée — jamais un `p` vivant (trois ombres par image).
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

    /// LE TIRAGE HORS SÉANCE — l'élastique de la home : la card se soulève,
    /// résiste (tanh, ~16 % de course max), la lune se lève ; au relâcher,
    /// toujours le retour. Jamais un déploiement.
    private func tirageLune(course: CGFloat, zone: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .onChanged { v in
                if dragFrom == nil {
                    dragFrom = levee
                    snapJeton += 1
                    if levee < 0.02 { capture(zone: zone) }
                }
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

    /// Réarme le chien à chaque frame de geste ; s'il aboie (~0,35 s sans
    /// nouvelle frame ni `onEnded`), il libère la prise et COMMET.
    private func armerChien(_ commettre: @escaping () -> Void) {
        chienJeton += 1
        let jeton = chienJeton
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            guard jeton == chienJeton, dragFrom != nil else { return }
            dragFrom = nil
            commettre()
        }
    }

    // MARK: Le corps du player-card

    private func corpsPlayer(course: CGFloat, zone: CGSize) -> some View {
        VStack(spacing: 0) {
            // LE PETIT TRAIT — la poignée premium.
            Capsule()
                .fill(Color.white.opacity(0.28))
                .frame(width: 36, height: 4)
                .padding(.top, 8)
                .frame(height: grabH)
            // LA DALLE — le sommet du player, et LA poignée du geste.
            dalle(levee)
                .frame(height: dockH)
                .contentShape(Rectangle())
                .gesture(tirage(course: course, zone: zone))
            // LA PARTITION — montée SEULEMENT au lever (loi 2). Un FLICK
            // descendant franc la range aussi (§2.1 ter).
            if levee > 0.02 {
                detail(levee)
                    .frame(maxWidth: .infinity, maxHeight: .infinity,
                           alignment: .top)
                    .opacity(Double(min(1, levee * 1.6)))
                    .transition(.opacity)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 20)
                            .onEnded { v in
                                if levee > 0.9, v.velocity.height > 650 {
                                    ranger()
                                }
                            })
            } else {
                Spacer(minLength: 0)
            }
        }
        // NOIR PUR (D/F) : pas de teinte — l'objet tient par ses coins, son
        // trait et la lumière. Le fond de la dalle (noir) ne fait AUCUNE
        // couture avec le corps.
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 30, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 30,
                style: .continuous)
            .fill(Color.black))
        // LA PRISE DU HEADER (verdict T1 : « j'arrive pas à drag le player
        // déplié ») — au déployé, tout le header (CD + titre + barre, rien
        // n'y scrolle) est une prise de rangement, façon Apple Music. Sous
        // le pied : ses boutons gardent la priorité.
        .overlay(alignment: .top) {
            if levee > 0.5 {
                Color.clear
                    .frame(height: 300)
                    .contentShape(Rectangle())
                    .gesture(tirage(course: course, zone: zone))
            }
        }
        // LE PIED — le héros en vol + les contrôles, par-dessus la
        // partition. Hit-transparent hors de ses objets : le slot arme ses
        // boutons lui-même, et seulement posés (t > 0,95).
        .overlay(alignment: .bottom) {
            if levee > 0.02 {
                pied(levee)
            }
        }
    }

    // MARK: Le geste

    private func tirage(course: CGFloat, zone: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .global)
            .onChanged { v in
                if dragFrom == nil {
                    dragFrom = levee
                    snapJeton += 1
                    // UNE capture par geste, à la prise (G : le hitch se
                    // mesure ; le snapshot n'est affiché qu'à mi-course).
                    if levee < 0.02 { capture(zone: zone) }
                }
                let d = -v.translation.height / course
                levee = min(max((dragFrom ?? 0) + d, 0), 1)
                // Le chien COMMET le côté le plus proche (la loi : jamais
                // un simple reset — sinon une card abandonnée à mi-vol).
                armerChien {
                    if levee > 0.5 {
                        withAnimation(.spring(response: 0.42,
                                              dampingFraction: 0.86)) {
                            levee = 1
                        }
                    } else {
                        ranger()
                    }
                }
            }
            .onEnded { v in
                chienJeton += 1
                dragFrom = nil
                let vy = v.velocity.height
                let cible: CGFloat = vy < -280 ? 1
                    : vy > 280 ? 0
                    : (levee > 0.5 ? 1 : 0)
                if cible == 0 { ranger() } else {
                    withAnimation(.spring(response: 0.42,
                                          dampingFraction: 0.86)) {
                        levee = 1
                    }
                }
            }
    }

    private func ranger() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            levee = 0
        }
        let jeton = snapJeton
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if snapJeton == jeton, levee < 0.02 { snap = nil }
        }
    }

    @MainActor
    private func capture(zone: CGSize) {
        // La capture rend EXACTEMENT ce que l'œil voyait (la card entière,
        // marges comprises — l'alpha autour reste transparent, le fond noir
        // du moteur vit derrière) : le swap vivant→snapshot est invisible.
        let renderer = ImageRenderer(content:
            pageEnCard
                .frame(width: zone.width, height: zone.height))
        renderer.scale = displayScale
        if let ui = renderer.uiImage { snap = Image(uiImage: ui) }
    }
}

// MARK: - Les petits objets du player déployé

/// LA BARRE BLANCHE — la progression de l'exercice en cours au déployé :
/// plus épaisse que la veine (5 pt), blanche, et son DÉGRADÉ COULISSE le
/// long du segment rempli. Le mouvement est COMPOSITÉ (un offset en
/// `repeatForever`) : zéro réévaluation par image — la leçon du
/// colorEffect 30 Hz (60 → 16 img/s) n'est pas repayée.
struct BarreBlancheAnimee: View {
    var progress: Double

    var body: some View {
        GeometryReader { g in
            let w = g.size.width * min(max(progress, 0.04), 1)
            // ⚠️ L'HORLOGE LOCALE, pas une transaction (payé DEUX fois v9 :
            // « je ne vois pas l'animation ») : un `repeatForever` posé par
            // `withAnimation` se fait avaler quand le parent est ré-évalué
            // par la levée. Le pattern VALIDÉ de la maison (le liseré vivant
            // de la molette) : `TimelineView` local — x = f(horloge), pas
            // d'état, rien à avaler. Seule cette barre (220×5) se redessine.
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                let clock = tl.date.timeIntervalSinceReferenceDate
                let u = CGFloat(
                    clock.truncatingRemainder(dividingBy: 2.2) / 2.2)
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.14))
                    // ⚠️ LE CONTRASTE FAIT LA COMÈTE (payé v9.3 : « toujours
                    // pas d'animation ») — une comète blanche sur un segment
                    // à 0,92 de blanc était INVISIBLE par construction
                    // (255+quoi que ce soit = 255). Le segment descend à
                    // 0,62 : encore une barre blanche à l'œil, et la comète
                    // pleine lumière se LIT en voyageant.
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

/// LA FORME TICKET DE CINÉMA — rectangle aux coins doux, DEUX ENCOCHES
/// semi-circulaires au milieu des flancs (les crans du ticket à l'ancienne).
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

/// LE BADGE NÉON — LA RECETTE DE LA MINI-CARD ×2 (StorySuite, néon BLANC) en
/// format badge : card noire à dégradé + liseré fondu, texte néon blanc à
/// DOUBLE ombre (serrée 3 + nappe 12), penchée, superposée SUR LE CÔTÉ de la
/// card jour. Il dit les sets FAITS (jamais un total — il n'existe pas). La
/// respiration est une lueur compositée (`repeatForever`), pas une horloge.
struct BadgeSetsNeon: View {
    var texte: String
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
                // LE TICKET DE CINÉMA (verdict 30-08) — la forme à
                // encoches, la MÊME matière noire (dégradé + liseré fondu).
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
            // LA DÉCHIRURE — la fine ligne pointillée du ticket, bornée à
            // sa hauteur réelle.
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
            .onAppear {
                withAnimation(.easeInOut(duration: 1.7)
                    .repeatForever(autoreverses: true)) { respire = true }
            }
    }
}

// MARK: - Les vues PARTAGÉES du player déployé (banc ET pages réelles)

/// LA SCÈNE — la zone d'atterrissage du héros, le titre de l'exercice EN
/// COURS, la barre-comète, la partition aux deux fondus. UNE seule vue pour
/// le banc et les vraies pages : jamais deux copies qui divergent.
struct ScenePlayer: View {
    var levee: CGFloat
    var titre: String
    var groupes: [SlateGroupe]
    @Binding var deplies: Set<String>

    var body: some View {
        let t = min(max(levee, 0), 1)
        VStack(spacing: 0) {
            // La zone d'atterrissage du héros (il VOLE dans le pied ; la
            // card posée fait ~133 pt de haut, la zone lui donne l'air).
            Spacer().frame(height: 210)
            Text(titre)
                .font(.inter(21, .semibold))
                .foregroundStyle(Color.white.opacity(0.94))
                .lineLimit(1)
            // LA BARRE — la comète coulisse en continu ; aucune fraction
            // affichée (on ne sait jamais où s'arrête le user).
            BarreBlancheAnimee(progress: 0.6)
                .frame(width: 220, height: 5)
                .padding(.top, 14)
            Spacer().frame(height: 22)
            SlateListe(groupes: groupes, courant: "courant",
                       basAir: 260, deplies: $deplies)
                .equatable()
                .padding(.horizontal, 12)
                // LES DEUX FONDUS : en HAUT les rangées fondent sous le
                // header fixe, en BAS elles s'éteignent avant les contrôles.
                .mask(
                    LinearGradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.07),
                        .init(color: .black, location: 0.68),
                        .init(color: .clear, location: 0.87),
                    ], startPoint: .top, endPoint: .bottom))
        }
        // La scène naît avec l'atterrissage du héros.
        .opacity(Double(max(0, (t - 0.45) * 2.2)))
    }
}

/// LE PIED — le héros en vol (la mini-card jour + son ticket), le vrai
/// médaillon stop né en fondu, « Page exercices » en verre. Hit-transparent
/// hors de ses objets ; les boutons ne s'arment que POSÉS (t > 0,95) et
/// seulement si l'hôte les branche (le banc les laisse inertes).
struct PiedPlayer: View {
    var levee: CGFloat
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
            // Le trajet du héros : la vignette de la dalle → le centre-haut.
            let x0: CGFloat = 41, y0: CGFloat = 18 + 38
            let x1 = gp.size.width / 2, y1: CGFloat = 176
            ZStack {
                // LE HÉROS — la MÊME mini-card jour, à sa taille native,
                // transportée et grossie au scale. Jamais interactive.
                MiniCardJour(date: jour, sticker: sticker,
                             stickerBasGauche: true)
                    .overlay(alignment: .trailing) {
                        BadgeSetsNeon(texte: "\(setsFaits) SETS")
                            .offset(x: 26)
                            .opacity(Double(max(0, (t - 0.25) * 1.6)))
                    }
                    .scaleEffect(0.58 + 1.12 * t)
                    .position(x: x0 + (x1 - x0) * t, y: y0 + (y1 - y0) * t)
                    .opacity(t > 0.03 ? 1 : 0)
                    .allowsHitTesting(false)

                // LE STOP — le vrai médaillon, né en fondu, actif seulement
                // POSÉ (jamais un bouton qui vole sous le doigt).
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
                    .glassEffect(.regular.tint(Color.black.opacity(0.35))
                                     .interactive(),
                                 in: .capsule)
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

/// La levée FIGÉE des bancs de capture (`-pageCardLevee <0…1>`) — partagée :
/// le Lab ET la vraie fiche la lisent (§2.16 : le bandeau du bug B était
/// invisible aux sondes tant que le déplié réel ne se capturait pas).
enum PageCardBanc {
    static let leveeFigee: CGFloat? = {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: "-pageCardLevee"), i + 1 < a.count,
              let v = Double(a[i + 1]) else { return nil }
        return CGFloat(min(max(v, 0), 1))
    }()
}

/// Banc de `PageCard` (tranche 0, v6) : card-page NOIRE au contenu réaliste,
/// player noir pur, VRAI médaillon transporté, verre molette sans bordure.
/// `-pageCardLevee 0.5` fige la levée pour les CAPTURES (méthode H : le rendu
/// se valide sur image AVANT tout build device).
struct PageCardLab: View {
    @State private var deplies: Set<String> = ["courant"]

    private static let demoStart = Date().addingTimeInterval(-27 * 60)
    private static let demoGroupes: [SlateGroupe] = {
        let exos = ExerciseCatalog.all
        func lignes(_ faits: Int, _ total: Int) -> [SlateLigne] {
            (0..<total).map {
                SlateLigne(reps: 12, kilos: 20,
                           seconds: $0 < faits ? 47 : 60,
                           done: $0 < faits)
            }
        }
        var out = [SlateGroupe(id: "courant", exercise: exos[0],
                               rows: lignes(2, 5))]
        if exos.count > 2 {
            out.append(SlateGroupe(id: exos[1].id, exercise: exos[1],
                                   rows: lignes(3, 3)))
            out.append(SlateGroupe(id: exos[2].id, exercise: exos[2],
                                   rows: lignes(0, 4)))
        }
        return out
    }()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            PageCard(dockH: 86,
                     leveeInitiale: PageCardBanc.leveeFigee ?? 0,
                     autoCycle: CommandLine.arguments
                         .contains("-pageCardAuto"),
                     // `-pageCardLune` : le banc du mode HORS SÉANCE (le
                     // trait, l'élastique, la lune).
                     enSeance: !CommandLine.arguments
                         .contains("-pageCardLune"),
                     page: { demoPage },
                     dalle: { l in vraieDalle(l) },
                     // Les vues PARTAGÉES (T1) — le banc et les vraies pages
                     // montent les mêmes, données de démo ici.
                     detail: { l in
                         ScenePlayer(levee: l,
                                     titre: ExerciseCatalog.all[0].name,
                                     groupes: Self.demoGroupes,
                                     deplies: $deplies)
                     },
                     pied: { l in
                         PiedPlayer(levee: l, jour: Self.demoStart,
                                    sticker: "sticker-flamme", setsFaits: 5)
                     })
        }
        .preferredColorScheme(.dark)
    }

    /// LA VRAIE DALLE (v7, héros-jour) : la MINI-CARD JOUR à gauche (la date
    /// vit là), le titre dit L'EXERCICE EN COURS, le stop à droite. Vignette
    /// et stop s'éteignent dès que leurs relais du pied prennent la main.
    private func vraieDalle(_ levee: CGFloat) -> some View {
        WorkoutPill(exercise: ExerciseCatalog.all[0],
                    progress: 0.4,
                    startedAt: Self.demoStart,
                    docked: true,
                    lisere: false,
                    doneSeries: 2,
                    exoCount: 3,
                    stopVisible: levee < 0.03,
                    jour: Self.demoStart,
                    jourSticker: "sticker-flamme",
                    jourVisible: levee < 0.03,
                    titreCourant: ExerciseCatalog.all[0].name,
                    hauteurDock: 86)
            // LA DALLE SE TAIT PENDANT LE VOL : son titre renaît dans la
            // scène — jamais deux fois le même texte à l'écran. L'opacité
            // n'éteint PAS le hit-test : le geste reste sur la dalle.
            .opacity(Double(1 - min(1, levee * 2.2)))
    }

    /// LA PAGE bidon (v6) : NOIRE, du contenu RÉALISTE jusqu'en bas — jamais
    /// un aplat qui se lit « calque » au push. PLEIN CADRE : la robe de card
    /// est posée par le MOTEUR — et NOIR PUR (§2.18) : le gris 0.05
    /// fabriquait un « bord » en haut que la vraie fiche n'a pas.
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
                // Le bas VIVANT de la fiche : des encres jusqu'en bas.
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
