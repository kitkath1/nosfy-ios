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

    init(dockH: CGFloat = 76,
         leveeInitiale: CGFloat = 0,
         autoCycle: Bool = false,
         @ViewBuilder page: () -> Page,
         @ViewBuilder dalle: @escaping (CGFloat) -> Dalle,
         @ViewBuilder detail: @escaping (CGFloat) -> Detail,
         @ViewBuilder pied: @escaping (CGFloat) -> Pied) {
        self.dockH = dockH
        self.autoCycle = autoCycle
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
    /// L'échelle RÉELLE de l'écran (un snapshot 2x sur écran 3x = flou
    /// permanent, payé v5).
    @Environment(\.displayScale) private var displayScale

    /// Le trait (grabber) + son air, au-dessus de la dalle.
    private var grabH: CGFloat { 18 }

    // Les courbes du rendu (E/F) : net jusqu'à mi-course, dissolution finale.
    private func lisse(_ u: CGFloat) -> CGFloat {
        let t = min(max(u, 0), 1); return t * t * (3 - 2 * t)
    }
    // DEUX CARDS D'ABORD, LE FONDU APRÈS (verdict v8.1, « j'insiste à
    // 100 % ») : pendant le push les deux cards restent NETTES et entières —
    // le flou ne démarre qu'à 70 % de course, l'extinction qu'à 78 %.
    private var flouCard: CGFloat { 24 * lisse((levee - 0.7) / 0.28) }
    private var opaciteCard: CGFloat { 1 - lisse((levee - 0.78) / 0.2) }

    var body: some View {
        GeometryReader { g in
            let H = g.size.height
            let safeTop = g.safeAreaInsets.top
            let safeBottom = g.safeAreaInsets.bottom
            // ⚠️ LA DALLE NE COLLE PAS LE FOOTER (verdict v8.1) : au repos
            // elle s'arrête AU-DESSUS de l'indicateur home (+6 pt d'air).
            let bandeH = grabH + dockH + safeBottom + 6 + 10
            let zoneH = max(H - bandeH, 1)
            // Le corps du player à TAILLE FINALE : il s'arrête SOUS la zone
            // sûre du haut — jamais collé à l'heure.
            let corpsH = max(H - safeTop - 8, 1)
            let course = max(corpsH - (grabH + dockH), 1)
            // La course VISIBLE : au repos, le bas de la dalle vit au-dessus
            // de l'indicateur — pas au bord physique.
            let repos = max(course - safeBottom - 6, 1)
            ZStack(alignment: .bottom) {
                // 1) LA CARD-PAGE — poussée en CONTACT 1:1 par le sommet du
                //    player (même course). Vivante et nette jusqu'à
                //    mi-course ; snapshot flouté en dissolution finale.
                VStack(spacing: 0) {
                    pageLayer
                        .frame(width: g.size.width, height: zoneH)
                        .blur(radius: flouCard)
                        .opacity(Double(opaciteCard))
                        .offset(y: -levee * repos)
                    Spacer(minLength: 0)
                }
                // 2) LE PLAYER-CARD — noir pur, taille finale, il GLISSE
                //    depuis le bas (le bord d'écran le coupe : il grandit).
                corpsPlayer(course: repos, zone: CGSize(width: g.size.width,
                                                        height: zoneH))
                    .frame(width: g.size.width, height: corpsH,
                           alignment: .top)
                    .offset(y: (1 - levee) * repos)
            }
            .frame(width: g.size.width, height: H)
            .clipped()
            // LA CINÉMATIQUE DU BANC : le cycle complet en boucle, avec la
            // vraie capture à chaque montée (fidèle au geste).
            .task(id: autoCycle) {
                guard autoCycle else { return }
                let zone = CGSize(width: g.size.width, height: zoneH)
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
                RadialGradient(
                    stops: [
                        .init(color: Color.white.opacity(0.12), location: 0),
                        .init(color: Color.white.opacity(0.04),
                              location: 0.45),
                        .init(color: .clear, location: 1),
                    ],
                    center: UnitPoint(x: 0.5, y: 0.0),
                    startRadius: 0, endRadius: 460)
                .frame(height: 340)
                .blendMode(.plusLighter)
                .opacity(Double(levee))
                .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: La card-page

    @ViewBuilder
    private var pageLayer: some View {
        if let snap, levee > 0.5 {
            // Le snapshot ne sert QUE la dissolution finale (E) — avant,
            // c'est la vraie vue qui sort, nette, objet entier.
            snap.resizable()
        } else {
            page
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
                                if levee > 0.9, v.velocity.height > 900 {
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
        // LE PIED — le morph du stop + « Page exercices », par-dessus la
        // partition. Inerte au banc (tranche 0).
        .overlay(alignment: .bottom) {
            if levee > 0.02 {
                pied(levee)
                    .allowsHitTesting(false)
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
            }
            .onEnded { v in
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
        let renderer = ImageRenderer(content:
            page.frame(width: zone.width, height: zone.height))
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

// MARK: - Le banc : `-pageCardLab`

/// Banc de `PageCard` (tranche 0, v6) : card-page NOIRE au contenu réaliste,
/// player noir pur, VRAI médaillon transporté, verre molette sans bordure.
/// `-pageCardLevee 0.5` fige la levée pour les CAPTURES (méthode H : le rendu
/// se valide sur image AVANT tout build device).
struct PageCardLab: View {
    @State private var deplies: Set<String> = ["courant"]

    /// La levée figée du banc de captures (absente = geste vivant).
    private static let leveeFigee: CGFloat? = {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: "-pageCardLevee"), i + 1 < a.count,
              let v = Double(a[i + 1]) else { return nil }
        return CGFloat(min(max(v, 0), 1))
    }()

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
                     leveeInitiale: Self.leveeFigee ?? 0,
                     autoCycle: CommandLine.arguments
                         .contains("-pageCardAuto"),
                     page: { demoPage },
                     dalle: { l in vraieDalle(l) },
                     detail: { l in vraiePartition(l) },
                     pied: { l in piedMorph(l) })
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

    /// LA SCÈNE + LA PARTITION (v7) : sous la zone d'atterrissage du héros,
    /// le titre de l'exercice EN COURS + LA VEINE D'OR, puis la SlateListe.
    /// Aucune plaque — encres sur le noir du corps (D/F).
    private func vraiePartition(_ levee: CGFloat) -> some View {
        let t = min(max(levee, 0), 1)
        return VStack(spacing: 0) {
            // La zone d'atterrissage du héros (il VOLE dans le pied ; la
            // card posée fait ~133 pt de haut, la zone lui donne l'air).
            Spacer().frame(height: 210)
            Text(ExerciseCatalog.all[0].name)
                .font(.inter(21, .semibold))
                .foregroundStyle(Color.white.opacity(0.94))
                .lineLimit(1)
            // LA BARRE BLANCHE (verdict 30-08) : plus épaisse que la veine,
            // et son dégradé COULISSE — compositée, jamais une horloge.
            BarreBlancheAnimee(progress: 0.6)
                .frame(width: 220, height: 5)
                .padding(.top, 14)
            // (Pas de « Set 3 of 5 » : on ne sait jamais où le user
            // s'arrête — aucun total n'existe. La barre parle seule.)
            Spacer().frame(height: 22)
            SlateListe(groupes: Self.demoGroupes, courant: "courant",
                       basAir: 260, deplies: $deplies)
                .equatable()
                .padding(.horizontal, 12)
                // LES DEUX FONDUS (verdict 30-08, « trop marqué ») : en HAUT
                // les rangées FONDENT en glissant sous le header fixe du
                // player (CD + titre + barre) ; en BAS elles s'éteignent
                // avant la zone des contrôles. Jamais une coupe nette.
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

    /// LE PIED (v7) — UN SEUL OBJET EN VOL : le HÉROS mini-card jour quitte
    /// la gauche de la dalle et se pose au centre en grossissant (le CD).
    /// Le stop NAÎT en fondu à sa place du bas (plus bas — verdict v6), le
    /// verre « Page exercices » dessous.
    private func piedMorph(_ levee: CGFloat) -> some View {
        GeometryReader { gp in
            let t = min(max(levee, 0), 1)
            // Le trajet du héros : la vignette de la dalle → le centre-haut
            // (posé à y1=176, la card ~133 de haut vit entre le trait et le
            // titre de la scène, sans jamais le couvrir).
            let x0: CGFloat = 41, y0: CGFloat = 18 + 38
            let x1 = gp.size.width / 2, y1: CGFloat = 176
            ZStack {
                // LE HÉROS — la MÊME mini-card jour, à sa taille NATIVE,
                // transportée et grossie au scale (aucune taille animée) :
                // 0,58 (la vignette de la dalle) → 1,7 (le CD posé).
                MiniCardJour(date: Self.demoStart, sticker: "sticker-flamme",
                             stickerBasGauche: true)
                    // LE BADGE « 5 SETS » (les FAITS — un total n'existe
                    // pas) : la mini-card néon de la ×2 en badge, penchée,
                    // SUPERPOSÉE au côté bas-droit de la card jour (~55 %
                    // dedans). Il ne s'allume qu'en vol/posé.
                    .overlay(alignment: .trailing) {
                        // PLUS PETIT, SUR LE FLANC (verdict v8.1) : à cheval
                        // sur le bord droit, mi-hauteur, ~55 % dedans.
                        BadgeSetsNeon(texte: "5 SETS")
                            .offset(x: 26)
                            .opacity(Double(max(0, (t - 0.25) * 1.6)))
                    }
                    .scaleEffect(0.58 + 1.12 * t)
                    .position(x: x0 + (x1 - x0) * t, y: y0 + (y1 - y0) * t)
                    .opacity(t > 0.03 ? 1 : 0)

                // LE STOP — le vrai médaillon, posé : il NAÎT en fondu,
                // il ne vole plus (un seul héros).
                MedaillonStop(lueur: true)
                    .scaleEffect(1.35)
                    .position(x: x1, y: gp.size.height - 140)
                    .opacity(Double(max(0, (t - 0.55) * 2.2)))

                Text("Page exercices")
                    .font(.inter(15, .semibold))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 13)
                    .glassEffect(.regular.tint(Color.black.opacity(0.35))
                                     .interactive(),
                                 in: .capsule)
                    .position(x: x1, y: gp.size.height - 80)
                    .opacity(Double(max(0, (t - 0.6) * 2.5)))
            }
        }
    }

    /// LA PAGE bidon (v6) : NOIRE, la robe de la maison, du contenu RÉALISTE
    /// jusqu'en bas — jamais un aplat qui se lit « calque » au push.
    private var demoPage: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color(white: 0.05))
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
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }
}
