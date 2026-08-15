import AVFoundation
import SwiftData
import SwiftUI

// MARK: - LA PAGE PROFIL — la maison des cartes

/// La refonte du 14-08 (« on va s'amuser un peu !! ») : l'ancienne page à
/// trois cartes est morte. À sa place : le halo de la home versé depuis la
/// DROITE (`bgAuroraProfil`, le champ miroité), le rond aux initiales en
/// dégradé néon sous son fil blanc animé, le badge de niveau, la pastille
/// moonCoin des pièces (tap → elle s'anime, puis le coffre), les réglages
/// dans leur overlay de verre, et LA COLLECTION : les quatre registres en
/// lignes, du plus petit au légendaire, avec les dos vides qui attendent.
///
/// Banc : `-profilLab` — la page seule, plein écran.
struct ProfilLuneView: View {
    @Binding var selection: WoopTab

    @Query(sort: \Workout.startedAt, order: .reverse)
    private var workouts: [Workout]
    @State private var showCoffre = false
    @State private var showReglages = false
    /// Le rebond de la pastille pièces au tap (0 → 1 → 0).
    @State private var coinKick: CGFloat = 0
    /// LA sonde du scroll — une seule, le champ vivant (le piège de la
    /// sonde constante : une sonde qui renvoie une constante ne rappelle
    /// jamais).
    @State private var scrollY: CGFloat = 0
    /// `-profilPli <p>` fige l'apparition du blur (captures).
    private static let pliFreeze: CGFloat? = UserDefaults.standard
        .string(forKey: "profilPli").flatMap { Double($0) }
        .map { CGFloat($0) }
    /// `-profilReglages` ouvre l'overlay réglages au lancement (captures).
    private static let reglagesNow =
        CommandLine.arguments.contains("-profilReglages")

    /// L'embrasement secret de KD (tap sur le rond, lot C).
    @State private var flambe: CGFloat = 0
    /// L'anneau d'XP éphémère (tap sur le badge Level, lot C).
    @State private var anneau: CGFloat = 0

    /// L'apparition du blur : comme TOUS les headers Apple — dès que le
    /// contenu passe dessous, le verre est là (rampe courte de 26 pt).
    private var pli: CGFloat {
        if let f = Self.pliFreeze { return min(max(f, 0), 1) }
        return min(max(scrollY / 26, 0), 1)
    }

    private static func sstep(_ v: CGFloat) -> CGFloat {
        let t = min(max(v, 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// Le trésor : la règle de la maison, 20 pièces par série faite.
    private var pieces: Int {
        let finies = workouts.filter { !$0.isActive }
        let series = finies.flatMap { $0.exercises ?? [] }
            .reduce(0) { $0 + $1.completedSets }
        return CoffreFortPurse.coins(doneSeries: series)
    }

    var body: some View {
        GeometryReader { geo in
            let p = pli
            let ps = Self.sstep(p)
            ZStack(alignment: .top) {
                ProfilFondNoir()

                ScrollView {
                    VStack(spacing: 0) {
                        banniere(geo)
                        nomBloc
                        ongletCartes
                            .padding(.top, 26)
                        registres
                            .padding(.top, 16)
                    }
                    .padding(.bottom, 120)
                }
                // La bannière prend TOUT le haut (la référence) : le
                // scroll monte jusqu'au bord physique de l'écran, le
                // liseré noir de 8 pt fait le tour.
                .ignoresSafeArea(edges: .top)
                .onScrollGeometryChange(for: CGFloat.self) { g in
                    // BORNÉE à 140 : au-delà, tout ce qui dépend du
                    // scroll est déjà à fond (blur, titre, fondu du
                    // géant) — le champ vivant s'arrête là et le scroll
                    // profond ne réveille PLUS la page (fluidité).
                    min(g.contentOffset.y + g.contentInsets.top, 140)
                } action: { _, y in
                    if abs(y - scrollY) > 0.25 { scrollY = y }
                }

                // LE HEADER FONDU (verdict : « pas de blur dégueu avec
                // trait ») : un DÉGRADÉ NOIR pur qui naît au scroll — du
                // noir plein sous la barre de statut, dissous en rien,
                // sans arête. Le contenu passe dessous et s'y éteint.
                LinearGradient(stops: [
                    .init(color: .black, location: 0.0),
                    .init(color: .black.opacity(0.86), location: 0.42),
                    .init(color: .black.opacity(0.0), location: 1.0),
                ], startPoint: .top, endPoint: .bottom)
                    .frame(height: 148)
                    .frame(maxWidth: .infinity)
                    .ignoresSafeArea(edges: .top)
                    .opacity(ps)
                    .allowsHitTesting(false)

                // Le titre du header : « Profil » se révèle avec le fondu,
                // centré sur la ligne des chips.
                Text("Profil")
                    .font(.inter(17, .semibold))
                    .tracking(-0.2)
                    .foregroundStyle(Color.inkPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .padding(.top, 4)
                    .opacity(ps)
                    .offset(y: 5 * (1 - ps))
                    .allowsHitTesting(false)

                // La rangée canonique : le chevron EXACTEMENT où il vit
                // sur la fiche d'exercice, les réglages en face.
                RangeeChips(retour: {
                    withAnimation(.easeOut(duration: 0.3)) {
                        selection = .home
                    }
                }) {
                    ChipVerre(symbole: "gearshape", label: "Réglages") {
                        withAnimation(.spring(response: 0.42,
                                              dampingFraction: 0.86)) {
                            showReglages = true
                        }
                    }
                }

                // KD LE VOYAGEUR — une seule vue transformée (la leçon
                // morphPhoto) : elle quitte le trône par une trajectoire
                // bombée et vient se tacker à côté du chevron. Et sur
                // l'ÉLASTIQUE du haut (tirer la page vers le bas), il SUIT
                // le contenu et grossit d'un souffle — la respiration du
                // zoom interne de la fiche, jamais une déchirure.
                // LE VOILE DU FOOTER (le frère jumeau du fondu du haut) :
                // le contenu se dissout vers la barre bijou — jamais un
                // bandeau, jamais un trait.
                VStack(spacing: 0) {
                    Spacer()
                    LinearGradient(stops: [
                        .init(color: .black.opacity(0.0), location: 0.0),
                        .init(color: .black.opacity(0.62), location: 0.55),
                        .init(color: .black.opacity(0.96), location: 1.0),
                    ], startPoint: .top, endPoint: .bottom)
                        .frame(height: 150)
                }
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)

                // LE BOOSTER TIRABLE : le géant planté dans le sol — on
                // le tire vers le haut, le sheet de verre s'ouvre. Sticky
                // au bas, il S'EFFACE dans la nuit au scroll et revient
                // en haut de course.
                TirageBooster(pieces: pieces, scrollY: scrollY)

                // L'overlay des réglages — le panneau de verre in-tree (la
                // sheet système tue le vrai Liquid Glass, leçon du
                // médaillon).
                if showReglages {
                    ReglagesOverlay(pieces: pieces) {
                        withAnimation(.spring(response: 0.4,
                                              dampingFraction: 0.9)) {
                            showReglages = false
                        }
                    }
                    .transition(.opacity)
                    .zIndex(10)
                }
            }
        }
        .fullScreenCover(isPresented: $showCoffre) {
            CoffreFortFlow(coins: pieces, onClose: { showCoffre = false })
        }
        .onAppear {
            if Self.reglagesNow { showReglages = true }
        }
    }

    // MARK: L'identité — la bannière, KD à cheval, le nom, le trésor

    /// LA BANNIÈRE (la référence Adobe) : l'aurora vivante ENFERMÉE dans
    /// un rectangle de ~20 % de l'écran — le reste de la page est rendu au
    /// noir profond. KD est collé À CHEVAL sur son bord bas, la pastille
    /// des pièces posée sur le côté droit.
    private func banniere(_ geo: GeometryProxy) -> some View {
        // La coque : les coins HAUTS au rayon de l'iPhone (55,
        // concentrique au châssis derrière le liseré de 5 pt), le bas
        // plus serré.
        let coque = UnevenRoundedRectangle(
            topLeadingRadius: 55, bottomLeadingRadius: 44,
            bottomTrailingRadius: 44, topTrailingRadius: 55,
            style: .continuous)
        return BanniereHalos()
            // Tout le HAUT de l'écran, Dynamic Island comprise (le
            // scroll ignore le safe area) — ~30 % de la page.
            .frame(height: max(230, geo.size.height * 0.30))
            .clipShape(coque)
            // LA DALLE DE VERRE (la référence des capsules) : le
            // Glass.clear du panneau réglages, posé en couvercle SUR les
            // halos — la lumière dessous, la lentille dessus, les arêtes
            // qui accrochent le blanc. KD et la pastille vivent AU-DESSUS
            // du verre.
            .overlay(
                coque
                    .fill(Color.clear)
                    .glassEffect(.clear, in: coque)
                    .allowsHitTesting(false))
            .overlay(coque
                .strokeBorder(Color.white.opacity(0.09), lineWidth: 1))
            .overlay(alignment: .bottomTrailing) {
                pastillePieces
                    .padding(.trailing, 14)
                    .padding(.bottom, 14)
            }
            .overlay(alignment: .bottomLeading) {
                RondAvatar(initiales: "KD", taille: 72,
                           flambe: flambe, anneau: anneau)
                    .padding(.leading, 18)
                    .offset(y: 36)
                    .onTapGesture {
                        UIImpactFeedbackGenerator(style: .light)
                            .impactOccurred(intensity: 0.7)
                        withAnimation(.easeOut(duration: 0.22)) { flambe = 1 }
                        withAnimation(.easeOut(duration: 0.9).delay(0.25)) {
                            flambe = 0
                        }
                    }
            }
            // Le petit liseré NOIR autour (la référence) : 5 pt de nuit
            // entre la bannière et les bords physiques de l'écran —
            // collée au châssis.
            .padding(.horizontal, 5)
            .padding(.top, 5)
    }

    /// Le nom, réduit, avec l'identifiant dessous — aligné sous KD.
    private var nomBloc: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 14) {
                Text("Kathryn")
                    .font(.inter(17, .bold))
                    .tracking(-0.2)
                    .foregroundStyle(Color.inkPrimary)
                // (retouche Apple : tout le texte de la page vit sur LA
                // grille de 20 pt — voir le padding du bloc.)
                // Le badge — un tap dévoile l'ANNEAU d'XP autour de KD,
                // deux secondes, puis il s'efface (sobre, jamais permanent).
                Button {
                    withAnimation(.spring(response: 0.4,
                                          dampingFraction: 0.8)) {
                        anneau = 1
                    }
                    withAnimation(.easeOut(duration: 0.7).delay(2.0)) {
                        anneau = 0
                    }
                } label: {
                    // La capsule REMPLIE du système (le contour seul
                    // faisait web — retouche Apple).
                    Text("Level 1")
                        .font(.inter(11, .semibold))
                        .tracking(0.5)
                        .foregroundStyle(Color.inkSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(Color.white.opacity(0.07)))
                }
                .buttonStyle(.plain)
            }
            Text("@kathrynd")
                .font(.inter(12, .semibold))
                .tracking(0.3)
                .foregroundStyle(Color.inkMuted)
        }
        .padding(.horizontal, 20)
        .padding(.top, 44)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// La pastille de la page BRAVO, en petit, posée SUR la bannière. Au
    /// tap elle SE RÉVEILLE (rebond + brille) puis ouvre le coffre — le
    /// délai est celui du bouton-pièce de la home (0,34 s).
    private var pastillePieces: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.42)) {
                coinKick = 1
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.32)) {
                coinKick = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
                showCoffre = true
            }
        } label: {
            HStack(spacing: 7) {
                // La pièce 3D de BRAVO — la recette gelée, en petit.
                MoonCoinView(coinR: 11, draggable: false,
                             yawOverride: 0.34, idleLife: 0, fps: 6,
                             reveal: 0.34, matte: 0)
                    .frame(width: 11 * MoonCoinView.hostScale,
                           height: 11 * MoonCoinView.hostScale)
                    .frame(width: 24, height: 24)
                    .rotationEffect(.degrees(Double(coinKick) * -14))
                Text("\(pieces)")
                    .font(.inter(15, .bold))
                    .foregroundStyle(Color.inkPrimary)
                    .contentTransition(.numericText())
                Text("pièces")
                    .font(.inter(11, .semibold))
                    .tracking(0.6)
                    .foregroundStyle(Color.inkSecondary)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .glassEffect(.regular.tint(Color.black.opacity(0.5))
                             .interactive(),
                         in: .capsule)
            .scaleEffect(1 + 0.10 * coinKick)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(pieces) pièces — ouvrir le coffre")
    }

    // MARK: Le titre de la collection

    private var ongletCartes: some View {
        // La recette maison des titres (celle d'« Exercices ») : Inter
        // bold, tracking négatif, le dégradé titleFade — LA signature de
        // cohérence entre les pages.
        Text("Cartes collectées")
            .font(.inter(24, .bold))
            .tracking(-0.3)
            .foregroundStyle(WoopGradient.titleFade)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
    }

    // MARK: Les quatre registres

    private static let registresProfil: [(nom: String, sous: String,
                                          pips: Int, total: Int)] = [
        ("Une Lune", "Normal", 1, 4),
        ("Deux Lunes", "Plus rare", 2, 11),
        ("Trois Lunes", "Très rare", 3, 4),
        ("Quatre Lunes", "Légendaire", 4, 6),
    ]

    private var registres: some View {
        VStack(spacing: 22) {
            ForEach(Self.registresProfil, id: \.nom) { reg in
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        HStack(spacing: 2.5) {
                            ForEach(0..<reg.pips, id: \.self) { _ in
                                CroissantLune(taille: 9,
                                              couleur: .profilBraise
                                                  .opacity(0.55))
                            }
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(reg.nom)
                                .font(.inter(15, .semibold))
                                .foregroundStyle(Color.inkPrimary)
                            Text(reg.sous)
                                .font(.inter(11, .regular))
                                .tracking(0.4)
                                .foregroundStyle(Color.inkMuted)
                        }
                        Spacer()
                        Text("0 / \(reg.total)")
                            .font(.inter(13, .semibold))
                            .monospacedDigit()
                            .foregroundStyle(Color.inkMuted)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.inkMuted)
                    }
                    .padding(.horizontal, 20)

                    // Les dos vides — plus tard, les collectées prendront
                    // leur place (pastille ×N pour les doublons, tap → la
                    // scène de résultat).
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(0..<reg.total, id: \.self) { _ in
                                DosVide(pips: reg.pips)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
    }
}

// MARK: - Le booster tirable

/// Le sachet 3D (celui du chantier booster, réutilisé tel quel — hit-test
/// coupé, ses gestes internes dorment) posé sur le voile du footer. On le
/// TIRE vers le haut : passé le seuil — ou d'un geste vif — le sheet de
/// verre s'ouvre et le sachet SAUTE dans son en-tête (UNE seule vue qui
/// voyage, la leçon morphPhoto). « Utiliser 20 pièces pour ouvrir un
/// booster ? » — Oui part vers le carrousel (la session booster écoute
/// la notification `woop.ouvrirCarrouselBoosters`) ; sinon l'overlay
/// descend et le sachet RESAUTILLE à sa place (ressort + haptique).
/// `-profilTirage` ouvre le sheet au lancement (captures).
struct TirageBooster: View {
    var pieces: Int
    /// Le scroll de la page : le géant s'efface dans la nuit dès qu'on
    /// descend, et revient en haut de course.
    var scrollY: CGFloat = 0
    /// Le prix d'un booster — la règle actée du 15-08.
    static let prix = 20

    @State private var ouvert =
        CommandLine.arguments.contains("-profilTirage")
    /// La traction du doigt (points vers le haut, ≥ 0).
    @State private var tire: CGFloat = 0
    /// La prise en main : l'haptique du début de traction, une fois.
    @State private var enMain = false
    /// Le REPLANTAGE : à la fermeture du sheet, le géant repart d'enfoui
    /// et rejaillit à sa place — le morphisme inverse du saut.
    @State private var enfoui: CGFloat = 0
    /// La POUSSÉE vers le bas (l'enterrement au doigt).
    @State private var pousse: CGFloat = 0
    /// La remontée d'INVITATION : toutes les ~7 s le sachet se soulève
    /// d'un souffle — « tire-moi » sans un mot.
    @State private var invite: CGFloat = 0
    /// ENTERRÉ : le sachet dort sous le sol, seule sa poignée de braise
    /// dépasse. L'état persiste entre les visites.
    @State private var enterre =
        UserDefaults.standard.bool(forKey: "profilBoosterEnterre")

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width

            ZStack(alignment: .bottom) {
                // Le voile + le sheet de verre.
                if ouvert {
                    Color.black.opacity(0.10)
                        .ignoresSafeArea()
                        .onTapGesture { fermer() }
                        .transition(.opacity)

                    sheet(W: W)
                        .transition(.move(edge: .bottom)
                            .combined(with: .opacity))
                }

                // LE SOL : le sachet GÉANT planté sous l'écran — on ne
                // voit que son sommet qui dépasse, et on l'EXTRAIT au
                // doigt. La bande de nuit pleine largeur avale le fond
                // noir du SCNView (fichier de la session booster — sa
                // transparence sera une ligne chez elle) ; le masque
                // fond son arête haute. Au seuil, le sol L'AVALE et il
                // rejaillit dans le sheet — « bim il arrive dans
                // l'overlay ».
                if !ouvert {
                    // Le fondu de nuit : visible en haut de course,
                    // effacé dès ~90 pt de scroll.
                    let fondu = 1 - min(max(scrollY / 90, 0), 1)

                    if !enterre {
                        // LE GÉANT NU : la lune à moitié visible, coupe
                        // nette au bord (le fondu du bas était moins
                        // bien — verdict). `invite` = la remontée
                        // périodique qui dit « tire-moi » sans un mot.
                        BoosterStage(still: false, frozenTear: nil,
                                     startOpen: false)
                            .frame(width: 560, height: 700)
                            .rotationEffect(.degrees(-8))
                            .allowsHitTesting(false)
                            .offset(x: 0,
                                    y: 385 + enfoui + pousse - tire - invite)
                            .opacity(fondu)
                            .ignoresSafeArea(edges: .bottom)
                            .transition(.move(edge: .bottom)
                                .combined(with: .opacity))

                        // LE CHEVRON DE BRAISE, gravé sur la crête du
                        // sachet (dans SES pixels — plus jamais un texte
                        // qui flotte sur les cartes). Il respire, et
                        // s'embrase pendant la remontée d'invitation.
                        if fondu > 0.1 {
                            TimelineView(.animation(
                                minimumInterval: 1.0 / 20.0)) { tl in
                                let t = tl.date.timeIntervalSinceReferenceDate
                                Image(systemName: "chevron.up")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(Color.profilBraise)
                                    .neonGlow(.profilBraise, radius: 8,
                                              opacity: 0.6)
                                    .opacity(0.45
                                        + 0.30 * sin(t * 2 * .pi / 2.4)
                                        + 0.35 * Double(invite / 9))
                            }
                            .offset(x: 0,
                                    y: -152 + enfoui + pousse - tire - invite)
                            .allowsHitTesting(false)

                            // La zone de traction : TIRER ouvre, POUSSER
                            // enterre — le geste miroir. Un tap ouvre
                            // aussi (l'affordance des pressés).
                            Color.clear
                                .frame(width: 300, height: 200)
                                .contentShape(Rectangle())
                                .onTapGesture { ouvrir() }
                                .gesture(DragGesture(minimumDistance: 4)
                                    .onChanged { v in
                                        if !enMain {
                                            enMain = true
                                            UIImpactFeedbackGenerator(
                                                style: .medium)
                                                .impactOccurred(intensity: 0.95)
                                        }
                                        let h = v.translation.height
                                        tire = max(0, -h)
                                        pousse = max(0, h) * 0.85
                                    }
                                    .onEnded { v in
                                        enMain = false
                                        let pred = v.predictedEndTranslation
                                            .height
                                        if -pred > 130 {
                                            ouvrir()
                                        } else if pred > 90 {
                                            enterrer()
                                        } else {
                                            UIImpactFeedbackGenerator(
                                                style: .soft)
                                                .impactOccurred(intensity: 0.6)
                                            withAnimation(.spring(
                                                response: 0.42,
                                                dampingFraction: 0.5)) {
                                                tire = 0
                                                pousse = 0
                                            }
                                        }
                                    })
                        }
                    } else if fondu > 0.1 {
                        // LA POIGNÉE DE BRAISE : le croissant du logo qui
                        // dépasse du sol — la braise sous la cendre. Un
                        // tap (ou un petit tirage) et le géant rejaillit.
                        TimelineView(.animation(
                            minimumInterval: 1.0 / 20.0)) { tl in
                            let t = tl.date.timeIntervalSinceReferenceDate
                            GlypheLune()
                                .fill(Color.profilBraise)
                                .frame(width: 30, height: 30)
                                .neonGlow(.profilBraise, radius: 9,
                                          opacity: 0.55)
                                .opacity(0.55
                                    + 0.25 * sin(t * 2 * .pi / 3.1))
                        }
                        .offset(y: 12)
                        .padding(20)
                        .contentShape(Rectangle())
                        .onTapGesture { deterrer() }
                        .gesture(DragGesture(minimumDistance: 6)
                            .onEnded { v in
                                if v.predictedEndTranslation.height < -40 {
                                    deterrer()
                                }
                            })
                        .opacity(Double(fondu))
                        .transition(.opacity)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height,
                   alignment: .bottom)
            .task {
                // La remontée d'INVITATION : toutes les ~7 s, le sachet
                // se soulève d'un souffle et se repose — « tire-moi »
                // sans un mot. Jamais pendant un geste ou enterré.
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(
                        Double.random(in: 6.0...8.5)))
                    guard !Task.isCancelled, !ouvert, !enterre,
                          tire == 0, pousse == 0 else { continue }
                    withAnimation(.easeInOut(duration: 0.55)) {
                        invite = 9
                    }
                    withAnimation(.easeInOut(duration: 0.75)
                        .delay(0.55)) {
                        invite = 0
                    }
                }
            }
        }
    }

    /// Le bruit du SAUT : « BoosterLeve » — l'arpège mineur en clochettes
    /// composé maison (gen_leve.py : sol, si bémol, ré — l'ascension
    /// poétique et mélancolique, un souffle d'air dessous). Le whoop de
    /// MoonGlide était trop triste (verdict).
    private static let sautChime: AVAudioPlayer? = {
        guard let url = Bundle.main.url(forResource: "BoosterLeve",
                                        withExtension: "wav")
        else { return nil }
        try? AVAudioSession.sharedInstance()
            .setCategory(.ambient, options: [.mixWithOthers])
        let p = try? AVAudioPlayer(contentsOf: url)
        p?.volume = 0.3
        p?.prepareToPlay()
        return p
    }()

    /// L'ouverture — par le tirage ou par le chevron : le sol l'avale,
    /// il rejaillit dans le sheet. Haptique LOURDE + l'arpège du lever.
    private func ouvrir() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        Self.sautChime?.currentTime = 0
        Self.sautChime?.play()
        withAnimation(.easeIn(duration: 0.14)) { tire = 0; pousse = 0 }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)
            .delay(0.1)) {
            ouvert = true
        }
    }

    /// L'ENTERREMENT : on pousse le géant vers le bas, il s'enfonce —
    /// seule sa poignée de braise reste. L'état persiste.
    private func enterrer() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 0.9)
        UserDefaults.standard.set(true, forKey: "profilBoosterEnterre")
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            enterre = true
            pousse = 0
            tire = 0
        }
    }

    /// LE RAPPEL : la poignée tirée (ou tapée), le géant rejaillit du
    /// sol en ressort — avec l'arpège du lever.
    private func deterrer() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.9)
        Self.sautChime?.currentTime = 0
        Self.sautChime?.play()
        UserDefaults.standard.set(false, forKey: "profilBoosterEnterre")
        enfoui = 320
        withAnimation(.easeOut(duration: 0.12)) { enterre = false }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.62)
            .delay(0.1)) {
            enfoui = 0
        }
    }

    /// La fermeture — LE MORPHISME INVERSE : le sheet descend (souple,
    /// sans rebond parasite) pendant que le géant SORT du sol et se
    /// replante dans le footer, en ressort. Haptique forte au départ.
    private func fermer() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.9)
        // Le géant repart d'enfoui — posé AVANT que le sol ne réapparaisse.
        enfoui = 250
        withAnimation(.spring(response: 0.5, dampingFraction: 0.88)) {
            ouvert = false
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.62)
            .delay(0.16)) {
            enfoui = 0
        }
    }

    private func sheet(W: CGFloat) -> some View {
        let forme = RoundedRectangle(cornerRadius: 28, style: .continuous)
        let manque = Self.prix - pieces
        return VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 10) {
                // LE TRÔNE : le sachet NU sur le verre — VIVANT : ses
                // gestes internes sont réveillés (le pan du chantier
                // booster le fait tourner sous le doigt — c'est pour ça
                // que le sheet n'a PAS de drag-fermeture), et par-dessus
                // sa respiration interne, une DANSE lente : balancement
                // ±2,5° et souffle d'échelle, périodes premières.
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    BoosterStage(still: false, frozenTear: nil,
                                 startOpen: false)
                        .frame(width: 240, height: 300)
                        .rotationEffect(.degrees(
                            2.5 * sin(t * 2 * .pi / 7.3)))
                        .scaleEffect(
                            1 + 0.025 * sin(t * 2 * .pi / 11.0 + 1.4))
                }
                .transition(.scale(scale: 0.6)
                    .combined(with: .opacity))
                .frame(height: 250)
                .padding(.top, 2)
                Text("Utiliser \(Self.prix) pièces\npour ouvrir un booster ?")
                    .font(.inter(20, .bold))
                    .tracking(-0.2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.inkPrimary)
                Text(manque > 0
                     ? "Il te manque \(manque) pièces."
                     : "Il t'en restera \(pieces - Self.prix).")
                    .font(.inter(13, .regular))
                    .foregroundStyle(Color.inkMuted)

                // NOTRE bouton primary — le diamant du trio auth, fumée
                // dorée (la page est de braise), et le retour de la
                // maison en secondaire.
                DiamondPrimaryButton(title: "OUVRIR",
                                     smokeWarmth: 0.6) {
                    // Le carrousel appartient à la session booster : elle
                    // écoute cette notification et prend la main.
                    NotificationCenter.default.post(
                        name: .init("woop.ouvrirCarrouselBoosters"),
                        object: nil)
                    fermer()
                }
                .disabled(manque > 0)
                .opacity(manque > 0 ? 0.4 : 1)
                .padding(.horizontal, 24)
                // Le retour en LIEN nu — pas de fond (verdict).
                Button(action: fermer) {
                    Text("RETOUR")
                        .font(.inter(13, .semibold))
                        .tracking(2.2)
                        .foregroundStyle(Color.inkMuted)
                        .padding(12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, -2)
            }
            .padding(.top, 14)
            .padding(.bottom, 30)
            .frame(maxWidth: .infinity)
            // Sans .interactive() — le verre interactif vole les drags.
            .glassEffect(.clear, in: forme)
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
        }
    }
}

// MARK: - Le rond aux initiales

/// Le rond centré : KD très FIN, habillé d'un dégradé de braises
/// SOMBRES qui voyage lentement dans les lettres, posé sur une matière
/// d'obsidienne — noir mat traversé d'un reflet poli qui tourne. Le fil
/// blanc animé de 0,7 pt reste, seul bijou. `taille` pilote TOUT
/// (lettres, lueurs, fil) : c'est la même vue qui voyage du trône au
/// dock du header.
struct RondAvatar: View {
    var initiales: String
    var taille: CGFloat = 72
    /// L'embrasement secret (0 → 1) : les braises sombres montent au
    /// rouge-or une seconde.
    var flambe: CGFloat = 0
    /// L'anneau d'XP éphémère (0 → 1) : un arc fin autour du rond.
    var anneau: CGFloat = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            let tour = Angle.degrees(
                t.truncatingRemainder(dividingBy: 8.0) / 8.0 * 360.0)
            // Le dégradé des lettres DÉRIVE : son axe tourne sur 13 s —
            // des braises profondes, jamais criardes.
            let phase = t.truncatingRemainder(dividingBy: 13.0) / 13.0
                * 2.0 * .pi
            let ax = 0.5 + 0.5 * cos(phase)
            let ay = 0.5 + 0.5 * sin(phase)
            let k = taille / 72
            let f = Double(flambe)
            // L'écho du halo : blanc chaud, jaune, orange — la palette de
            // la bannière, qui dérive dans les lettres.
            Text(initiales)
                .font(.inter(22 * k, .light))
                .tracking(3.5 * k)
                .foregroundStyle(LinearGradient(
                    colors: [Color(red: 1.00, green: 0.96, blue: 0.90),
                             Color(red: 1.00, green: 0.80, blue: 0.32),
                             Color(red: 1.00, green: 0.48 + 0.20 * f,
                                   blue: 0.14 + 0.20 * f)],
                    startPoint: UnitPoint(x: ax, y: ay),
                    endPoint: UnitPoint(x: 1 - ax, y: 1 - ay)))
                .neonGlow(.profilBraise, radius: 7 * k,
                          opacity: 0.30 + 0.50 * f)
                .frame(width: taille, height: taille)
                .background {
                    // LE VERRE NOIR (verdict : « verre noir sublime et
                    // reflet blanc ») : la profondeur sombre d'une bille
                    // de verre, la calotte de reflet blanc en haut, et
                    // l'éclat spéculaire qui la signe.
                    ZStack {
                        Circle().fill(RadialGradient(
                            colors: [Color(white: 0.17),
                                     Color(white: 0.05),
                                     Color(white: 0.01)],
                            center: UnitPoint(x: 0.38, y: 0.24),
                            startRadius: 1, endRadius: taille * 0.85))
                        // La calotte : le reflet d'une fenêtre lointaine.
                        Ellipse()
                            .fill(LinearGradient(
                                colors: [.white.opacity(0.30),
                                         .white.opacity(0.0)],
                                startPoint: .top, endPoint: .bottom))
                            .frame(width: taille * 0.70,
                                   height: taille * 0.32)
                            .offset(y: -taille * 0.27)
                            .blur(radius: 1)
                        // L'éclat : un point de blanc pur, à peine flou.
                        Circle()
                            .fill(Color.white.opacity(0.55))
                            .frame(width: taille * 0.055)
                            .offset(x: -taille * 0.17, y: -taille * 0.31)
                            .blur(radius: 0.4)
                    }
                }
                .clipShape(Circle())
                .overlay(
                    Circle().strokeBorder(
                        AngularGradient(stops: [
                            .init(color: .white.opacity(0.05), location: 0.0),
                            .init(color: .white.opacity(0.85), location: 0.12),
                            .init(color: .white.opacity(0.10), location: 0.30),
                            .init(color: .white.opacity(0.05), location: 0.55),
                            .init(color: .white.opacity(0.45), location: 0.78),
                            .init(color: .white.opacity(0.05), location: 1.0),
                        ], center: .center, angle: tour),
                        lineWidth: 0.7))
                // L'anneau d'XP : un arc de braise ultra-fin, éphémère —
                // il n'existe qu'au tap du badge (jamais un bijou de plus
                // en permanence). Le tiers plein = l'XP du niveau, en dur
                // tant que la mécanique n'existe pas.
                .overlay(
                    Circle()
                        .trim(from: 0, to: 0.30 * anneau)
                        .stroke(LinearGradient(
                            colors: [.profilBraise,
                                     Color(red: 1.0, green: 0.75,
                                           blue: 0.40)],
                            startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: taille + 12, height: taille + 12)
                        .opacity(Double(anneau)))
        }
    }
}

// MARK: - L'overlay des réglages

/// Le panneau de verre in-tree — il monte du bas sur un voile, se referme
/// au drag ou au voile. Dedans : le compte, la déconnexion, la
/// suppression (l'exigence App Store — le câblage réel viendra avec la
/// connexion Apple) et les conditions générales.
struct ReglagesOverlay: View {
    var pieces: Int
    var fermer: () -> Void

    @State private var glisse: CGFloat = 0
    @State private var showCGU = false
    @State private var confirmeSuppression = false
    @State private var noteSuppression = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // Le voile : PRESQUE RIEN — le verre doit refléter le monde
            // derrière lui, le voile ne fait que capter le tap de sortie.
            Color.black.opacity(0.10)
                .ignoresSafeArea()
                .onTapGesture { fermer() }

            let forme = RoundedRectangle(cornerRadius: 28, style: .continuous)
            // Le conteneur d'iOS 26 : c'est LUI qui allume la vraie
            // lentille du Liquid Glass sur les grandes formes.
            GlassEffectContainer {
            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 40, height: 4.5)
                    .padding(.top, 10)
                    .padding(.bottom, 16)

                Text("Réglages")
                    .font(.inter(21, .bold))
                    .foregroundStyle(Color.inkPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                // Le compte — l'échafaudage d'atelier ; le compte Apple
                // prendra cette place au chantier connexion.
                HStack(spacing: 12) {
                    Text("KD")
                        .font(.inter(14, .bold))
                        .tracking(1)
                        .foregroundStyle(Color.profilBraise)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.black.opacity(0.55)))
                        .overlay(Circle().strokeBorder(
                            Color.white.opacity(0.14), lineWidth: 0.7))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Kathryn")
                            .font(.inter(16, .semibold))
                            .foregroundStyle(Color.inkPrimary)
                        Text("\(pieces) pièces lune · Level 1")
                            .font(.inter(12, .regular))
                            .foregroundStyle(Color.inkMuted)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 18)

                VStack(spacing: 0) {
                    ligne("rectangle.portrait.and.arrow.right",
                          "Se déconnecter") {
                        // La déconnexion d'aujourd'hui : oublier la
                        // session locale — la vraie (Supabase/Apple)
                        // arrive avec le chantier connexion.
                        UserDefaults.standard.removeObject(
                            forKey: "woop.phone")
                        fermer()
                    }
                    separateur
                    ligne("doc.text", "Conditions générales d'utilisation") {
                        withAnimation(.easeOut(duration: 0.25)) {
                            showCGU = true
                        }
                    }
                    separateur
                    ligne("trash", "Supprimer mon compte",
                          teinte: Color(red: 1.0, green: 0.36, blue: 0.26)) {
                        confirmeSuppression = true
                    }
                    if noteSuppression {
                        Text("La suppression réelle sera activée avec la connexion Apple.")
                            .font(.inter(12, .regular))
                            .foregroundStyle(Color.inkMuted)
                            .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 26)
            }
            .frame(maxWidth: .infinity)
            // LE LIQUID GLASS CLAIR (verdict : « ça doit refléter
            // derrière ») : Glass.clear — le verre le plus lentille
            // d'iOS 26. SANS .interactive() : le verre interactif CAPTE
            // les touchers pour son shimmer et volait le drag du panneau
            // (« le drag ne marche plus » — payé).
            .glassEffect(.clear, in: forme)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
            .offset(y: glisse)
            .contentShape(Rectangle())
            // Le drag IMPARABLE : priorité haute avec distance minimale —
            // le panneau suit le doigt 1:1 partout (même en partant d'une
            // ligne-bouton : un tap ne bouge pas de 12 pt, le geste échoue
            // et le bouton reçoit son tap). Caoutchouc vers le haut, et la
            // fermeture lit la VITESSE (predictedEnd) : un petit geste vif
            // ferme, un grand geste hésitant revient en ressort.
            .highPriorityGesture(DragGesture(minimumDistance: 12)
                .onChanged { v in
                    let h = v.translation.height
                    glisse = h >= 0 ? h : h / 6
                }
                .onEnded { v in
                    if v.predictedEndTranslation.height > 150 {
                        fermer()
                    } else {
                        withAnimation(.spring(response: 0.32,
                                              dampingFraction: 0.82)) {
                            glisse = 0
                        }
                    }
                })
            .transition(.move(edge: .bottom).combined(with: .opacity))

            if showCGU {
                CGUPage {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showCGU = false
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .zIndex(20)
            }
        }
        .alert("Supprimer ton compte ?", isPresented: $confirmeSuppression) {
            Button("Supprimer", role: .destructive) {
                withAnimation { noteSuppression = true }
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Tes cartes et tes pièces seront perdues pour toujours.")
        }
    }

    private var separateur: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(height: 1)
            .padding(.leading, 54)
    }

    private func ligne(_ symbole: String, _ titre: String,
                       teinte: Color = .inkPrimary,
                       action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbole)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(teinte)
                    .frame(width: 26)
                Text(titre)
                    .font(.inter(15, .semibold))
                    .foregroundStyle(teinte)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.inkMuted)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Les conditions générales — le gabarit est posé, LE TEXTE RESTE À
/// RÉDIGER avant l'App Store.
struct CGUPage: View {
    var fermer: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 0) {
                RangeeChips(retour: fermer) { EmptyView() }
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Conditions générales d'utilisation")
                            .font(.inter(24, .bold))
                            .foregroundStyle(Color.inkPrimary)
                        Text("Le texte des conditions générales sera rédigé avant la publication sur l'App Store.")
                            .font(.inter(15, .regular))
                            .foregroundStyle(Color.inkSecondary)
                        Spacer(minLength: 200)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                }
            }
        }
    }
}

// MARK: - Le dos vide

/// Une carte qui ATTEND. Au tap, elle répond « je suis vide » : ses
/// liserés s'embrasent (l'image recomposée sur elle-même en écran — seuls
/// les pixels chauds montent, donc le néon suit exactement les traits) et
/// la main sent un petit grain sec. Les lunes de rareté du registre sont
/// posées par le code, comme sur les vraies cartes.
struct DosVide: View {
    var pips: Int
    @State private var pulse: CGFloat = 0
    /// Le RÊVE (lot A) : toutes les 8-15 s, un frisson de liseré très bas
    /// parcourt un dos au hasard — la collection respire. Chaque dos tire
    /// sa propre horloge : jamais deux frissons synchronisés.
    @State private var frisson: CGFloat = 0

    private static let dos: Image = {
        guard let p = Bundle.main.path(forResource: "carte-dos-vide",
                                       ofType: "png"),
              let ui = UIImage(contentsOfFile: p)
        else { return Image(systemName: "questionmark.diamond") }
        // MINIATURE une fois pour toutes : 25 dos qui compressent chacun
        // le PNG de 1024×1536 à 80 pt à chaque composition, c'était le
        // scroll qui rame — on rend à 2× la taille d'affichage, fini.
        let taille = CGSize(width: 160, height: 160 * 1672.0 / 941.0)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let mini = UIGraphicsImageRenderer(size: taille, format: format)
            .image { _ in
                ui.draw(in: CGRect(origin: .zero, size: taille))
            }
        return Image(uiImage: mini)
    }()

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .rigid)
                .impactOccurred(intensity: 0.7)
            withAnimation(.easeOut(duration: 0.16)) { pulse = 1 }
            withAnimation(.easeOut(duration: 0.7).delay(0.16)) { pulse = 0 }
        } label: {
            // L'anneau est ÉTEINT par défaut (le dos désaturé, gris
            // sombre) et il S'ALLUME en orange — au tap (pleine flamme),
            // ou quand son horloge le décide (une braise DISCRÈTE, à
            // peine 45 % — verdict « plus discret et subtil »).
            let allume = max(pulse, frisson * 0.45)
            ZStack {
                Self.dos
                    .resizable()
                    .aspectRatio(941.0 / 1672.0, contentMode: .fit)
                    .saturation(0.05)
                    .brightness(-0.015)
                Self.dos
                    .resizable()
                    .aspectRatio(941.0 / 1672.0, contentMode: .fit)
                    .opacity(allume)
                Self.dos
                    .resizable()
                    .aspectRatio(941.0 / 1672.0, contentMode: .fit)
                    .blendMode(.screen)
                    .opacity(0.55 * allume)
                Self.dos
                    .resizable()
                    .aspectRatio(941.0 / 1672.0, contentMode: .fit)
                    .blur(radius: 5)
                    .blendMode(.screen)
                    .opacity(0.5 * allume)
            }
            // Gabarit explicite (quatre dos par rangée) + le rayon de
            // 8 pt demandé. (Plus de lunes sous les dos.)
            .frame(width: 80, height: 80 * 1672.0 / 941.0)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .scaleEffect(1 + 0.035 * pulse)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Emplacement de carte vide")
        .task {
            // L'ALLUMAGE (verdict : « toutes les 4 secondes certaines
            // s'allument orange ») : chaque dos tire son horloge autour
            // de 4 s — décalées entre elles, quelques cartes s'embrasent
            // à chaque instant, jamais toutes ensemble. Coût nul entre
            // deux allumages (pas de TimelineView).
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: 5.0...9.0)))
                guard !Task.isCancelled else { break }
                // La braise se réveille LENTEMENT et s'éteint encore plus
                // lentement — un souffle, pas un clignotement.
                withAnimation(.easeInOut(duration: 0.9)) { frisson = 1 }
                withAnimation(.easeOut(duration: 1.5).delay(0.9)) {
                    frisson = 0
                }
            }
        }
    }
}

extension Color {
    /// La braise du profil — l'orange sombre de l'univers des cartes.
    static let profilBraise = Color(red: 1.0, green: 0.55, blue: 0.18)
}

// MARK: - Le glyphe du logo

/// LE croissant de la marque, exact : le path de `MoonGlyph` (les 18
/// cubiques du logo, WoopShared) en `Shape` — fini les croissants
/// génériques à deux cercles (verdict : « comme le logo »).
struct GlypheLune: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height / MoonGlyph.unitHeight)
        let dx = rect.midX - s / 2
        let dy = rect.midY - s * MoonGlyph.unitHeight / 2
        func pt(_ p: CGPoint) -> CGPoint {
            CGPoint(x: dx + p.x * s, y: dy + p.y * s)
        }
        var path = Path()
        path.move(to: pt(MoonGlyph.startPoint))
        for seg in MoonGlyph.segments {
            path.addCurve(to: pt(seg.end), control1: pt(seg.c1),
                          control2: pt(seg.c2))
        }
        path.closeSubpath()
        return path
    }
}

/// Le glyphe posé en pastille — petit et DISCRET (« trop de lunes mdr »).
struct CroissantLune: View {
    var taille: CGFloat
    var couleur: Color

    var body: some View {
        GlypheLune()
            .fill(couleur)
            .frame(width: taille, height: taille)
    }
}

// MARK: - Le fond de nuit

/// La page est rendue au NOIR : un dégradé subtil et profond (verdict :
/// « un fond noir dégradé joli, pas métal ») — chaud en haut, éteint en
/// bas. Le grain de la maison par-dessus.
struct ProfilFondNoir: View {
    var body: some View {
        ZStack {
            Color.black
            LinearGradient(stops: [
                .init(color: Color(red: 0.075, green: 0.062, blue: 0.052),
                      location: 0.0),
                .init(color: Color(red: 0.030, green: 0.026, blue: 0.023),
                      location: 0.38),
                .init(color: .black, location: 1.0),
            ], startPoint: .top, endPoint: .bottom)
            WoopGrain()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

/// L'hôte des halos de la bannière : trois grands foyers blanc/jaune/
/// orange qui naviguent et se fondent — jamais de noir (30 Hz, la
/// cadence des fonds).
private struct BanniereHalos: View {
    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                let t = Float(tl.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 900))
                Rectangle()
                    .fill(.white)
                    .colorEffect(ShaderLibrary.banniereHalos(
                        .float2(geo.size.width, geo.size.height),
                        .float(t)))
            }
        }
    }
}

// MARK: - Le banc

/// `-profilLab` : la page seule, sans la barre bijou — le chevron ne mène
/// nulle part, on fouette le visuel.
struct ProfilLab: View {
    @State private var selection = WoopTab.profile

    var body: some View {
        ProfilLuneView(selection: $selection)
            .statusBarHidden()
            .preferredColorScheme(.dark)
    }
}

#Preview { ProfilLab() }
