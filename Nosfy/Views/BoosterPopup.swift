import SwiftUI
import AVFoundation

// MARK: - L'ÉTAT PARTAGÉ DU SACRE
//
// LE PIÈGE QUI IMPOSE CE FICHIER : le contenu d'un onglet est construit
// PARESSEUSEMENT. Tant que personne n'a ouvert le profil, `ProfilLuneView`
// n'existe pas — donc elle n'écoute aucune `NotificationCenter`, et le
// premier « Ouvrir un Booster » ne faisait RIEN. Une notification est un
// cri dans une pièce vide : il faut que quelqu'un y soit déjà.
//
// L'état, lui, se lit à la racine. Le Manège se monte AU-DESSUS du
// TabView et de la barre bijou (`WoopApp.mainBody`) : il n'a plus besoin
// que qui que ce soit ait été instancié avant lui, et le flow reste celui
// d'où on vient — on ouvre un booster depuis la home SANS passer par
// l'onglet profil.
//
// Le parcours complet est écrit dans `tools/sacre/PARCOURS-BOOSTER.md`,
// et ce que le serveur doit lui servir dans `SUPABASE-PIPELINE.md`.

/// Le chef d'orchestre du parcours booster — une seule instance, lue à la
/// racine de l'app.
@Observable
final class SacreEtat {
    static let shared = SacreEtat()
    private init() {}

    /// La pop-up de proposition (« Un booster t'attend »).
    var popupOuverte = false
    /// Le Manège — le carrousel des sachets, monté à la racine.
    var manegeOuvert = false
    /// LA ROUE EST POSÉE : la mise en place cinématique est finie — le
    /// coordinateur du manège le publie. C'est CE signal (jamais un
    /// minuteur fixe) qui autorise l'éclipse de la home : sur téléphone,
    /// la compilation Metal décale la roue, et un « +2 s » fixe faisait
    /// tomber la désallocation de la home EN PLEIN dévissage.
    var manegePose = false
    /// LA MORSURE DE LA CARD — la profondeur à laquelle la card 2D a déchiré
    /// le sachet (BoosterCard.swift, le glissement). Le manège la reprend
    /// (`BoosterLab.dechirureDepart`). ⚠️ nil pour toute autre porte (les
    /// pills du profil, le coffre, un TAP sur la card) : un sachet qui n'a
    /// pas été mordu arrive intact. Effacée à la fermeture du manège et à
    /// l'envol de la carte — jamais une constante à la racine (relecture
    /// adverse, 30-08 : « 0,30 pour tout le monde, tout le temps »).
    var morsureCard: Float? = nil
    /// La carte que la page profil doit ACCUEILLIR (l'envol accompli).
    /// Elle est posée APRÈS la bascule d'onglet : la page doit exister
    /// pour l'entendre — et son `onAppear` la relit en filet de sécurité.
    var arriveeDemandee: CarteEnvolee?

    /// Le compteur des sachets non ouverts — la pill du profil et le
    /// nombre de tours du manège.
    ///
    /// ⚠️⚠️ **IL A ÉTÉ UNE CONSTANTE PENDANT TOUT L'ÉTÉ, ET ÇA NE SE VOYAIT
    /// PAS.** `= 1`, en mémoire, jamais persisté ; son SEUL écrivain était
    /// `WoopApp:1185`, `max(1, n − 1)` — un plancher qui le rendait
    /// **invariant**. Un sachet gagné en fin de séance (réellement inséré
    /// dans `user_boosters` côté serveur) n'apparaissait nulle part, et un
    /// sachet ouvert ne retirait rien. La pill du profil affichait « 1 » à
    /// vie, avec le bouton OUVRIR toujours allumé.
    ///
    /// ⚠️ **DÉSORMAIS IL LIT `user_boosters`** (`etat_coffre().boosters_or`,
    /// les lignes à `opened_at is null`) dès que le serveur a parlé. La
    /// valeur locale reste dessous, et elle ne sert plus qu'à deux choses :
    /// les bancs (`-sacreNoir`), et l'app sans compte connecté.
    /// ⚠️ `@MainActor` sur la PROPRIÉTÉ, pas sur la classe : `SacreEtat` est
    /// lu depuis des contextes non isolés (le coordinateur du manège), et
    /// l'isoler entièrement propagerait la contrainte à tout le parcours
    /// booster. Ce nombre-ci, lui, ne se lit que dans des corps de vue.
    @MainActor
    var boostersEnAttente: Int {
        get { EconomieWoop.shared.boosters }
        set { EconomieWoop.shared.maquetteBoosters = max(newValue, 0) }
    }

    /// LA DEUXIÈME RÉSERVE : les boosters NOIRS, ceux qu'une pièce noire
    /// ouvre et qui rendent une légendaire (`tools/sacre/PLAN-BOOSTER-NOIR.md`).
    ///
    /// Deux réserves qui ne se croisent JAMAIS — verdict Kathryn : « on
    /// n'aura jamais les deux ensemble ». Deux compteurs, deux portes, deux
    /// manèges. Côté serveur c'est le même `user_boosters`, filtré sur
    /// `origine = 'legendaire'` (§4 decies de la note backend) — et sur la
    /// page argent, **solde et sachets ouvrables sont LE MÊME NOMBRE**, le
    /// sachet noir naissant au claim.
    ///
    /// ⚠️ Il ne pouvait pas monter avant le 29-08 : `roll_rare` n'existait
    /// pas, donc aucune pièce d'argent ne tombait, donc toute la robe noire
    /// du Sacre — ses textures bakées, sa card légendaire — était
    /// inatteignable par le jeu. Le banc `-sacreNoir` en sème un.
    @MainActor
    var boostersNoirsEnAttente: Int {
        get { EconomieWoop.shared.boostersNoirs }
        set { EconomieWoop.shared.maquetteNoirs = max(newValue, 0) }
    }
    /// La robe que le manège doit porter à sa prochaine ouverture — posée
    /// par la proposition ou par la pill, jamais devinée par la vue.
    var robeCourante: RobeBooster = SacreEtat.bancNoir ? .noire : .lune

    /// `-sacreNoir` : le parcours du booster NOIR de bout en bout, sans
    /// backend — une réserve noire semée, et la proposition de fin de séance
    /// (comme le bouton d'essai de la home) qui offre le noir. Tant que la
    /// pièce noire n'est pas servie par le serveur, c'est la seule façon de
    /// juger la porte.
    static let bancNoir = CommandLine.arguments.contains("-sacreNoir")
    /// Une proposition arrivée pendant un manège ouvert : elle repart
    /// à la fermeture (jamais perdue).
    var propositionEnAttente = false

    /// La proposition (aujourd'hui le bouton d'essai de la home ; demain
    /// la fin de séance).
    func proposer(robe: RobeBooster = .lune) {
        // Un manège déjà ouvert : la proposition ATTEND au lieu de se
        // perdre — elle repart à la fermeture (la pill du profil
        // n'était qu'un filet, pas une réponse).
        if manegeOuvert {
            propositionEnAttente = true
            return
        }
        robeCourante = Self.bancNoir ? .noire : robe
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
            popupOuverte = true
        }
    }

    /// L'ouverture du Manège — depuis la pop-up comme depuis la pill du
    /// profil. On reste dans le flow où on est.
    ///
    /// SÉQUENCER, jamais superposer : monté à l'instant du tap, le
    /// manège payait son warm-up SceneKit PENDANT la sortie du panneau
    /// (vidéo + verre + poudre encore vivants) — le carrousel naissait
    /// en saccades. Le panneau sort d'abord, la scène se monte ensuite.
    func ouvrirManege(robe: RobeBooster? = nil) {
        #if DEBUG
        traceQA("sacre : ouvrirManege(\(String(describing: robe))) dejaOuvert=\(manegeOuvert) popup=\(popupOuverte)")
        #endif
        guard !manegeOuvert else { return }
        // La pill du profil dit QUELLE réserve elle ouvre ; la pop-up, elle,
        // a déjà posé la robe en proposant. Rien ne la devine.
        if let robe { robeCourante = robe }
        manegePose = false
        let panneauSort = popupOuverte
        withAnimation(.easeOut(duration: 0.22)) { popupOuverte = false }
        DispatchQueue.main.asyncAfter(
            deadline: .now() + (panneauSort ? 0.32 : 0.06)) {
            // Un re-tap du bouton démo pendant la fenêtre a pu ROUVRIR
            // la pop-up (proposer ne garde que !manegeOuvert) : on la
            // referme AVANT tout — sinon elle vivait sous le Sacre et
            // réapparaissait à l'arrivée profil.
            if self.popupOuverte {
                withAnimation(.easeOut(duration: 0.22)) {
                    self.popupOuverte = false
                }
            }
            guard !self.manegeOuvert else { return }
            withAnimation(.easeInOut(duration: 0.38)) {
                self.manegeOuvert = true
            }
        }
    }

    /// Le chevron des deux écrans du Sacre : on rend la main à la home.
    func fermerManege() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        manegePose = false
        morsureCard = nil
        withAnimation(.easeInOut(duration: 0.32)) { manegeOuvert = false }
        // La proposition mise en attente reprend la parole.
        if propositionEnAttente {
            propositionEnAttente = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                self.proposer()
            }
        }
    }
}

// MARK: - La boucle vidéo de l'overlay

/// L'hôte : un `AVPlayerLayer` nu — `VideoPlayer` (AVKit) apporterait ses
/// commandes et son fond, dont une pop-up n'a que faire.
final class BoosterLoopLayerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

/// Les trois sachets en éventail, fumée qui monte. L'école des démons :
/// `AVPlayerLooper` (jamais un `seek(.zero)` sur `didPlayToEndTime` — il
/// laisse une image noire au raccord), le looper RETENU par le
/// coordinateur, et le muet obligatoire.
///
/// LE FICHIER EST RECUIT AVANT L'APP. Et CE QUI FAISAIT VOIR LA BOUCLE
/// N'ÉTAIT PAS LA COUTURE — elle était déjà au niveau du mouvement
/// naturel. C'ÉTAIT UNE RAMPE D'EXPOSITION : la scène source **s'éclaire
/// de 55 %** du début à la fin (luminance moyenne 3,93 → 6,11). L'œil ne
/// voyait pas un raccord, il voyait la lumière monter puis retomber d'un
/// coup dans le noir. Chaque image est donc ramenée à la luminance
/// médiane du plan (gains 0,885 à 1,374) : la rampe tombe à **0 %**.
///
/// LA DEUXIÈME CAUSE, DÉBUSQUÉE APRÈS : **la caméra DÉRIVE**. Une
/// translation propre de +0,25 px par image en x et −0,17 en y — +21 et
/// −16 px sur le plan. Un long fondu croisé sur un plan qui glisse ne
/// fond pas, il DÉDOUBLE : les liserés des sachets sortaient en double
/// exposition, et ça se lit « cheap » à dix mètres. Le plan est donc
/// STABILISÉ (dérive mesurée par corrélation de phase sur la zone des
/// sachets, droite ajustée en écartant les images que la fumée fait
/// mentir, recalage bicubique, marges recoupées). Netteté au cœur du
/// fondu : 6,25 contre 6,97 hors fondu — il ne reste que la fumée qui se
/// mélange, et c'est exactement ce qu'on veut d'elle.
///
/// ET LE RACCORD LUI-MÊME A DISPARU : la boucle est un **PING-PONG** —
/// aller puis retour, sans redoubler les deux extrêmes. C'est la
/// technique de l'overlay flamme du panneau « Recommencer », et elle est
/// imbattable : il n'y a plus de raccord à cacher, puisqu'il n'y en a
/// plus. La couture tombe à ZÉRO — pas « petite », nulle : la dernière
/// image EST la voisine de la première. Plus de fondu croisé, donc plus
/// une once du dédoublement qu'il coûtait. Le plan dure deux fois plus
/// longtemps (9,4 s au lieu de 3,5), ce qui éloigne d'autant la période.
///
/// Sur cette base — plan fixe, exposition plate, aller-retour — reste le
/// cadrage : CENTRÉ sur les sachets (le cœur lumineux tombe à 49,7 % de
/// la largeur) et élargi, la fumée blanche de gauche et le reflet au sol
/// (hors champ dans la première coupe) sont dans le plan.
///
/// L'autre chose qui disait « une vidéo », c'était le RECTANGLE. Il n'y
/// en a plus du tout : le plan n'est plus un bandeau bord à bord masqué
/// sur ses flancs, c'est un OBJET DE LUMIÈRE posé au milieu de la nuit du
/// panneau, en additif — l'école de l'overlay flamme. Le noir de la
/// source disparaît sans détourage (mesuré : 89 % des pixels sous
/// 12/255, et le fond est à 0,00 exactement), il ne reste que les
/// sachets et leur fumée.
struct BoosterLoopVideo: UIViewRepresentable {
    /// LA ROBE CHANGE LE PLAN. Le panneau noir montrait les sachets ORANGE
    /// du set Lune : il promettait la mauvaise chose avant même le premier
    /// mot. `booster-loop-noir.mp4` est le MÊME plan (même caméra, même
    /// fumée, même ping-pong — tout ce qui a été payé plus haut reste vrai),
    /// dégradé au froid hors ligne : saturation 0,10 et une pointe de bleu.
    /// Mesuré sur une image du milieu, l'écart R−B des pixels clairs passe
    /// de **+55 (l'orange) à −2 (neutre)**.
    ///
    /// ⚠️ Ce que ce dégradé NE FAIT PAS : les sachets filmés gardent le
    /// DESSIN du set Lune (leur liseré, leur croissant). De près on voit
    /// des sachets du set Lune éteints, pas des sachets noirs. Un vrai plan
    /// noir demande un rendu, pas un étalonnage.
    var robe: RobeBooster = .lune

    final class Coordinator {
        var player: AVQueuePlayer?
        // Relâché, la boucle s'arrête au premier tour et le plan se fige.
        var looper: AVPlayerLooper?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> BoosterLoopLayerView {
        let v = BoosterLoopLayerView()
        v.backgroundColor = .clear
        v.isUserInteractionEnabled = false
        // Le cadre qu'on lui donne est au ratio EXACT du fichier (1,45) :
        // rien n'est recadré, toute la scène recuisinée est à l'écran.
        v.playerLayer.videoGravity = .resizeAspectFill
        let plan = robe == .noire ? "booster-loop-noir" : "booster-loop"
        guard let url = Bundle.main.url(forResource: plan,
                                        withExtension: "mp4") else {
            // Sans le fichier, le panneau reste le panneau : son verre et
            // sa nuit. On ne pose jamais un rectangle noir « en attendant ».
            return v
        }
        let p = AVQueuePlayer()
        p.isMuted = true
        // Rien à mettre en tampon : le fichier est dans le paquet.
        p.automaticallyWaitsToMinimizeStalling = false
        context.coordinator.looper = AVPlayerLooper(
            player: p, templateItem: AVPlayerItem(url: url))
        context.coordinator.player = p
        v.playerLayer.player = p
        p.play()
        return v
    }

    func updateUIView(_ v: BoosterLoopLayerView, context: Context) {}

    static func dismantleUIView(_ v: BoosterLoopLayerView,
                                coordinator: Coordinator) {
        coordinator.player?.pause()
        coordinator.looper?.disableLooping()
        v.playerLayer.player = nil
    }
}

// MARK: - LE PANNEAU BOOSTER

/// L'HÔTE. Le conteneur reste monté (transparent, sourd au doigt quand il
/// est vide) : c'est LUI qui joue l'entrée et la sortie du panneau —
/// l'école du « Recommencer » de la fiche d'exercice, à la lettre. Sans
/// ce conteneur, le panneau serait inséré et retiré d'un coup, et sa
/// descente n'aurait jamais lieu.
struct BoosterPopupHote: View {
    var ouverte: Bool
    var robe: RobeBooster = .lune
    var onOuvrir: () -> Void = {}
    var onFermer: () -> Void = {}

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .bottom) {
                Color.clear
                if ouverte {
                    // Le voile : assez pour détacher le panneau, assez
                    // peu pour que le verre ait encore une page à
                    // échantillonner.
                    Color.black.opacity(0.12)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { onFermer() }
                        .transition(.opacity)
                    // La largeur descend d'ICI : le panneau doit connaître
                    // sa taille AVANT d'entrer — un panneau qui monte du
                    // bas ne peut pas se mesurer en chemin.
                    BoosterPopup(W: g.size.width, robe: robe,
                                 onOuvrir: onOuvrir, onFermer: onFermer)
                        .transition(.move(edge: .bottom))
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(ouverte)
        .animation(.spring(response: 0.45, dampingFraction: 0.86),
                   value: ouverte)
    }
}

/// LA PROPOSITION, MONTÉE DU BAS. Le jumeau du panneau « Recommencer » :
/// même verre, même nuit qui fond, même primaire, même échappée en encre
/// nue — et la même sortie, on le TIRE VERS LE BAS pour dire non. Les
/// coins HAUTS seuls sont arrondis : le bas appartient à l'écran (le
/// CADRE FANTÔME au ras d'un bord est une faute déjà payée).
struct BoosterPopup: View {
    var W: CGFloat
    var robe: RobeBooster = .lune
    var onOuvrir: () -> Void = {}
    var onFermer: () -> Void = {}

    /// LES MOTS APPARTIENNENT À LA ROBE. Le noir ne promet pas « une carte
    /// du set Lune » : il promet CE QU'IL EST, une légendaire garantie —
    /// c'est la seule certitude que l'app vende, elle a le droit de se dire.
    private var titre: String {
        robe == .noire ? "Un booster NOIR t'attend." : "Un booster t'attend !"
    }

    private var sousTitre: String {
        robe == .noire
            ? "Une carte LÉGENDAIRE dort à l'intérieur."
            : "Une carte du set Lune dort à l'intérieur."
    }

    /// La fumée du diamant suit le monde : braise sur le set Lune, presque
    /// froide sur le noir (la palette du manège noir, tenue jusqu'ici).
    private var chaleurFumee: Float { robe == .noire ? 0.12 : 0.55 }

    /// Le drag de rangement — sur TOUTE la surface : le geste SIMULTANÉ
    /// laisse les deux boutons garder leurs taps (12 pt de course avant
    /// que le drag n'existe).
    @State private var pull: CGFloat = 0
    /// L'horloge de la caméra du plan — la pose, les retours et la poudre
    /// s'écrivent dessus (fonction pure du temps, rien à semer).
    @State private var naissance = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Coins HAUTS seuls — le bas appartient à l'écran.
    private static let forme = UnevenRoundedRectangle(
        cornerRadii: .init(topLeading: 34, bottomLeading: 0,
                           bottomTrailing: 0, topTrailing: 34),
        style: .continuous)
    /// Le ratio du fichier recuit — l'emplacement est taillé dessus pour
    /// que rien ne soit recadré.
    private static let ratioVideo: CGFloat = 1.45

    // LES INTERRUPTEURS DE LA BISSECTION. « On dirait que ça lag » ne se
    // répare pas au jugé : on éteint une pièce à la fois et on lit la
    // sonde (`-fps`). Ils restent — le prochain doute se tranchera en
    // quatre lancements au lieu de quatre suppositions.
    //
    // MESURÉ AU SIMULATEUR (18-08), panneau ouvert sur la home :
    //
    //     home seule .......... 19 à 31 img/s   (trous 50-88 ms)
    //     tout ................ 10,2 img/s      (pire trou 245 ms)
    //     sans la POUDRE ...... 14,6            → elle coûte le plus
    //     sans le VERRE ....... 13,2            → puis lui
    //     sans la CAMÉRA ...... 10,9            → presque rien
    //     sans le PLAN ........ 10,2            → RIEN DU TOUT
    //
    // La vidéo, qu'on soupçonnait depuis le début, ne coûte pas une
    // image : une couche `AVPlayerLayer` est décodée par le matériel et
    // composée par le GPU. Ce qui coûte, c'est ce que le FIL PRINCIPAL
    // redessine — le Canvas des paillettes — et ce que le compositeur
    // doit rééchantillonner — le verre posé sur une home qui bouge.
    //
    // Note d'honnêteté : le simulateur rend en logiciel, et la home
    // elle-même n'y tient que 19 à 31 img/s. Ces chiffres classent les
    // coupables, ils ne prédisent pas le téléphone.
    private static let sansVerre = CommandLine.arguments.contains("-noGlass")
    private static let sansPlan = CommandLine.arguments.contains("-noVideo")
    private static let sansPoudre = CommandLine.arguments
        .contains("-noPoudre")
    private static let sansCamera = CommandLine.arguments
        .contains("-noCamera")

    /// L'emplacement du plan, au ratio exact du fichier.
    private var slotH: CGFloat { W / Self.ratioVideo }

    var body: some View {
        panneau(W: W, slotH: slotH)
            .frame(width: W, height: hauteur)
            .offset(y: pull)
        // TOUTE la surface attrape le drag (la leçon « j'arrive pas à
        // drag » : une zone rendue transparente au toucher).
        .contentShape(Self.forme)
        .simultaneousGesture(dismissDrag)
    }

    /// La hauteur du panneau : l'emplacement du plan, plus la somme
    /// EXACTE de ce qui s'écrit dessous. Calculée plutôt que laissée au
    /// contenu — un panneau qui monte du bas doit connaître sa taille
    /// AVANT d'entrer — et calculée JUSTE, sinon tout le mou tombe dans
    /// le même trou entre le sous-titre et le diamant.
    private var hauteur: CGFloat { slotH + 246 }

    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .onChanged { v in pull = max(0, v.translation.height) }
            .onEnded { _ in
                if pull > 90 {
                    onFermer()
                } else {
                    withAnimation(.spring(response: 0.34,
                                          dampingFraction: 0.82)) { pull = 0 }
                }
            }
    }

    private func panneau(W: CGFloat, slotH: CGFloat) -> some View {
        VStack(spacing: 0) {
            // La réserve du header, plus 34 pt d'AIR FRANC : la scène a
            // fini de s'éteindre bien avant le titre (le masque la fond
            // dès 46 % de sa hauteur), le texte ne lui marche pas dessus.
            Color.clear.frame(height: slotH + 34)

            Text(titre)
                .font(.inter(20, .semibold))
                .foregroundStyle(Color.inkPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 30)
            Text(sousTitre)
                .font(.inter(12.5))
                .foregroundStyle(Color.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.top, 7)
                .padding(.horizontal, 30)

            // Le mou du panneau se prend ICI : l'emplacement du plan est
            // ancré en haut, il ne doit jamais bouger d'un pixel.
            Spacer(minLength: 0)

            DiamondPrimaryButton(title: "Ouvrir un Booster",
                                 smokeWarmth: chaleurFumee) {
                onOuvrir()
            }
            .padding(.horizontal, 26)
            .padding(.top, 32)

            // L'échappée en ENCRE SEULE — sur la nuit, un cadre clair se
            // lit comme un bug (l'école du footer de BRAVO).
            Button { onFermer() } label: {
                Text("Plus tard")
                    .font(.inter(15, .medium))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
            // Le pied appartient à l'écran : la marge dégage l'indicateur.
            .padding(.bottom, 34)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // LE VERRE EST LE VRAI (il échantillonne la page vivante), et
        // par-dessus LA NUIT QUI FOND.
        //
        // ELLE FOND AU PIED DE LA VIDÉO, PAS À UNE FRACTION DU PANNEAU.
        // Les paliers étaient posés en dur (0,95 → 0,88 à 38 % → 0,25 au
        // pied) alors que la vidéo, elle, finissait à 57 % : mesuré, il
        // restait **69 % de noir** à sa base — le vrai verre n'avait
        // aucune chance de se voir, et le fondu ne devenait rien. Les
        // paliers se calculent donc sur `slotH / hauteur du panneau` :
        // noir plein sous l'image (elle a besoin de son fond), chute
        // franche dans les 34 pt qui suivent, puis le verre règne — le
        // titre, le sous-titre et le diamant vivent dessus.
        .background {
            GeometryReader { p in
                let H = max(p.size.height, 1)
                let pied = min(slotH / H, 0.9)
                ZStack {
                    // Jamais `.interactive()` sur un grand verre : il vole
                    // les gestes de ce qui vit dessus.
                    if !Self.sansVerre {
                        Color.clear.glassEffect(
                            .regular.tint(Color.black.opacity(0.30)),
                            in: Self.forme)
                    }
                    Self.forme
                        .fill(LinearGradient(stops: [
                            .init(color: .black.opacity(0.95), location: 0),
                            .init(color: .black.opacity(0.93),
                                  location: pied * 0.56),
                            .init(color: .black.opacity(0.72),
                                  location: pied),
                            .init(color: .black.opacity(0.56),
                                  location: min(pied + 40 / H, 0.99)),
                            .init(color: .black.opacity(0.54), location: 1)
                        ], startPoint: .top, endPoint: .bottom))
                        .allowsHitTesting(false)
                }
            }
        }
        // L'OVERLAY, À L'ÉCOLE DE LA FLAMME du panneau « Recommencer ».
        // Ce n'est plus un bandeau vidéo posé en haut du panneau : c'est
        // un OBJET DE LUMIÈRE au milieu de la nuit. Il est dimensionné
        // par la HAUTEUR de son emplacement, centré, et composé en
        // ADDITIF — le noir de la source disparaît sans détourage (89 %
        // des pixels sous 12/255, fond mesuré à 0,00), il ne reste que
        // les sachets et leur fumée. Plus de masques de flancs à
        // entretenir : le plan DÉBORDE le panneau, et c'est la forme du
        // panneau qui porte les coins.
        .overlay(alignment: .top) {
            ZStack {
                // LA CAMÉRA PORTE LA VIE, PAS LE FICHIER. Le plan est
                // volontairement TRÈS lent (0,45×, 17,7 s) : à cette
                // vitesse la fumée ne monte plus, elle DÉRIVE — et une
                // dérive n'a pas de sens, donc l'aller-retour cesse de se
                // voir. C'était le dernier aveu du ping-pong : une fumée
                // qui remonte à l'envers, l'œil le sait ; une flamme peut
                // faire l'aller-retour, une fumée non.
                //
                // Ce qui bouge vraiment, c'est la caméra : la POSE
                // d'entrée, puis deux respirations et une dérive, toutes
                // sur des périodes PREMIÈRES entre elles et avec les
                // 17,7 s du plan. Rien ne retombe jamais en phase : il
                // n'existe aucun instant où l'image est deux fois la
                // même, donc aucun cycle à repérer.
                //
                // ET LA CAMÉRA PASSE PAR UNE TRANSFORMATION, PAS PAR LA
                // FRAME — c'est la leçon du « ça lag beaucoup ».
                // Redimensionner un `AVPlayerLayer` soixante fois par
                // seconde le fait relayouter ET re-rendre à chaque image :
                // le panneau saccadait. La règle maison (« le zoom par la
                // géométrie, jamais par scaleEffect ») a été écrite pour
                // des vues RENDUES — qu'on rastérise puis qu'on étire. Une
                // couche vidéo, elle, est une texture : le GPU
                // l'échantillonne pour rien, et ±7 % sur une source de
                // 1160 px ne se voit pas. Cadence 30 Hz : le plan lui-même
                // n'affiche que 10,7 images par seconde.
                TimelineView(.animation(minimumInterval: 1.0 / 30.0,
                                        paused: reduceMotion
                                            || Self.sansCamera)) { tl in
                    let e = tl.date.timeIntervalSince(naissance)
                    let fige = reduceMotion || Self.sansCamera
                    let pose: CGFloat = fige
                        ? 1 : 1 + 0.10 * CGFloat(exp(-e * 1.9))
                    let respire: CGFloat = fige ? 1
                        : 1 + 0.050 * CGFloat(sin(e * 2 * .pi / 37.0))
                            + 0.024 * CGFloat(sin(e * 2 * .pi / 23.0 + 1.7))
                    let dx: CGFloat = fige ? 0
                        : 7 * CGFloat(sin(e * 2 * .pi / 41.0 + 0.6))
                    let dy: CGFloat = fige ? 0
                        : 5 * CGFloat(sin(e * 2 * .pi / 29.0))
                    if !Self.sansPlan {
                    BoosterLoopVideo(robe: robe)
                        // POSÉE UNE FOIS. Elle ne bouge plus jamais.
                        .frame(width: slotH * Self.ratioVideo,
                               height: slotH)
                        // LE FONDU DE PIED EST CUIT DANS LE FICHIER, plus
                        // dans un `.mask` : un masque sur une couche vidéo
                        // force un rendu HORS ÉCRAN de tout le plan à
                        // chaque image, et il ne servait qu'à multiplier
                        // par une rampe verticale — ce qu'un encodeur fait
                        // une fois pour toutes. Mêmes paliers (plein
                        // jusqu'à 60 %, 0,40 à 84 %, nul au bord).
                        .blendMode(.plusLighter)
                        .scaleEffect(pose * respire)
                        .offset(x: dx, y: dy)
                    }
                }
                // LA POUDRE DE DIAMANT — dessinée par l'app, pas par le
                // fichier, et sur SA propre horloge (le plan n'a pas à se
                // ré-évaluer au rythme des paillettes). C'est ELLE qui
                // tranche la question du « on voit que c'est une vidéo » :
                // des grains qui vivent chacun sur son cycle ne bouclent
                // JAMAIS ensemble, donc plus rien à l'écran ne peut se
                // répéter. La recette de la poussière de rubis de
                // l'overlay flamme, en blanc et or.
                if !Self.sansPoudre {
                    PoudreBooster(W: W, slotH: slotH, naissance: naissance)
                }
            }
            // La boîte d'ancrage : le plan déborde et reste CENTRÉ — un
            // `frame` ne rogne pas, c'est le panneau qui le fait, avec
            // ses coins.
            .frame(width: W, height: slotH)
            .allowsHitTesting(false)
        }
        .clipShape(Self.forme)
        // Le fil du bord — seulement là où la feuille se détache du fond.
        .overlay {
            Self.forme
                .strokeBorder(LinearGradient(stops: [
                    .init(color: Color.white.opacity(0.16), location: 0),
                    .init(color: Color.white.opacity(0.03), location: 0.18),
                    .init(color: .clear, location: 0.45)
                ], startPoint: .top, endPoint: .bottom), lineWidth: 1)
                .allowsHitTesting(false)
        }
        // La poignée du panneau — elle dit « tire-moi vers le bas ».
        .overlay(alignment: .top) {
            Capsule()
                .fill(Color.white.opacity(0.28))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .allowsHitTesting(false)
        }
    }

}

// MARK: - La poudre de diamant

/// LES PAILLETTES. Très très fines : des croix taillées de 0,6 à 2,0 pt
/// qui montent en dérivant autour des sachets, chacune sur SON cycle,
/// chacune son scintillement. Fonction pure du temps — aucun état, rien à
/// semer, et surtout aucune période commune : c'est ce qui rend la scène
/// définitivement inépuisable, et c'est ce qui achève de tuer le « on
/// voit que c'est une vidéo ».
///
/// Blanc et or, jamais de rose : l'or appartient aux sachets, le blanc à
/// la lune. La recette de la poussière de rubis de l'overlay flamme.
///
/// Vue à part, avec SA propre horloge à 30 Hz : le plan vidéo n'a aucune
/// raison de se ré-évaluer au rythme des paillettes (et il saccadait
/// quand il le faisait).
struct PoudreBooster: View {
    var W: CGFloat
    var slotH: CGFloat
    var naissance: Date

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Assez pour que ça brille partout, assez peu pour que le Canvas
    /// reste une broutille : 52 grains à 30 Hz coûtent moins que 26 à 60.
    private static let grains = 52

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0,
                                paused: reduceMotion)) { tl in
            let t = tl.date.timeIntervalSince(naissance)
            Canvas { ctx, _ in
                // L'ADDITIF SE DEMANDE AU CONTEXTE, pas à la vue : un
                // `.blendMode` posé sur le Canvas force un rendu HORS
                // ÉCRAN de tout l'emplacement à chaque image, alors
                // qu'ici il ne concerne que des grains d'un pixel.
                ctx.blendMode = .plusLighter
                for i in 0 ..< Self.grains {
                    let vie = 3.0 + 3.4 * Self.hash(i, 2)
                    let cyc = (t / vie + Self.hash(i, 5))
                        .truncatingRemainder(dividingBy: 1)
                    // Naît sur la table, autour des sachets, et monte d'un
                    // souffle en dérivant.
                    let cx = W / 2 + (Self.hash(i, 1) - 0.5) * W * 0.80
                    let cy = slotH * (0.34 + 0.52 * Self.hash(i, 3))
                    let x = cx + sin(t * (0.35 + 0.5 * Self.hash(i, 8))
                                     + Self.hash(i, 9) * 6.28) * 9
                    let y = cy - CGFloat(cyc) * slotH * 0.42
                    // Le voile de vie : entre en douceur, meurt en montant
                    // — et scintille TRANCHÉ (le cube), comme les pierres
                    // du slider.
                    let s = sin(.pi * cyc)
                    let tw = 0.5 + 0.5 * sin(t * (7 + 12 * Self.hash(i, 4))
                                             + Self.hash(i, 6) * 6.28)
                    let a = s * s * (0.20 + 0.80 * tw * tw * tw)
                    guard a > 0.02 else { continue }
                    let r = CGFloat(0.6 + 1.4 * Self.hash(i, 7))
                    // Deux tempéraments : la braise dorée des sachets et
                    // le blanc lunaire — deux tiers d'or, un tiers de lune.
                    let c = Self.hash(i, 10) < 0.34
                        ? Color(red: 0.96, green: 0.97, blue: 1.00)
                        : Color(red: 1.00, green: 0.62, blue: 0.26)
                    var etoile = Path()
                    etoile.move(to: CGPoint(x: -r, y: 0))
                    etoile.addLine(to: CGPoint(x: 0, y: -r * 0.22))
                    etoile.addLine(to: CGPoint(x: r, y: 0))
                    etoile.addLine(to: CGPoint(x: 0, y: r * 0.22))
                    etoile.closeSubpath()
                    etoile.move(to: CGPoint(x: 0, y: -r))
                    etoile.addLine(to: CGPoint(x: r * 0.22, y: 0))
                    etoile.addLine(to: CGPoint(x: 0, y: r))
                    etoile.addLine(to: CGPoint(x: -r * 0.22, y: 0))
                    etoile.closeSubpath()
                    ctx.fill(etoile.applying(
                        CGAffineTransform(translationX: x, y: y)
                            .rotated(by: (Self.hash(i, 11) - 0.5) * 0.9)),
                             with: .color(c.opacity(a * 0.85)))
                    // Le cœur vif — c'est lui la facette.
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: x - 0.45, y: y - 0.45,
                                               width: 0.9, height: 0.9)),
                        with: .color(Color.white.opacity(a * 0.9)))
                }
            }
        }
        .allowsHitTesting(false)
        .frame(width: W, height: slotH)
    }

    private static func hash(_ i: Int, _ k: Int) -> Double {
        let s = sin(Double(i) * 12.9898 + Double(k) * 78.233) * 43758.5453
        return s - floor(s)
    }
}

// MARK: - Le sachet en vignette

/// UNE IMAGE DU PAQUET, PAS D'UN CATALOGUE. Les PNG de `Woop/Media` sont
/// des ressources nues : `Image("booster-pill")` cherche dans les
/// catalogues d'assets et ne trouve RIEN — silencieusement (le bouton
/// d'essai est resté un carré vide une capture durant). Le chargement
/// passe donc par le bundle, comme le dos des cartes.
///
/// Et c'est bien une image, pas une `SCNView` : une scène SceneKit dans
/// une capsule coûterait le prix d'une page pour vingt pixels.
struct SachetVignette: View {
    var largeur: CGFloat
    var hauteur: CGFloat
    var robe: RobeBooster = .lune

    private static let lune: UIImage? = charger("booster-pill")
    /// **LES DEUX VIGNETTES SONT JUMELLES DEPUIS LE 28-08.**
    ///
    /// La noire était mon bake du dessin À PLAT : posée à côté du rendu 3D
    /// orange, elle lisait « autocollant » — mesuré, 0,3 % de pixels
    /// spéculaires contre 3,45 %, et il fallait un alpha et un mode de
    /// composition à elle. Les deux viennent maintenant des rendus de
    /// Kathryn, même studio, même cadrage, même échelle
    /// (`tools/coffre-v2/bake_vignettes.py`) : plus qu'un seul mode, plus
    /// d'alpha à entretenir, et 2,52 % contre 1,87 % de spéculaires.
    private static let noire: UIImage? = charger("booster-pill-noir")

    private static func charger(_ nom: String) -> UIImage? {
        Bundle.main.path(forResource: nom, ofType: "png")
            .flatMap { UIImage(contentsOfFile: $0) }
    }

    var body: some View {
        if let ui = robe == .noire ? Self.noire : Self.lune {
            Image(uiImage: ui)
                .resizable()
                .scaledToFit()
                .frame(width: largeur, height: hauteur)
        // ⚠️ COMPOSITION NORMALE, ET PLUS ADDITIVE. Le sachet vivait en
        // `plusLighter` : sur la pill, posé sur du noir, personne ne voyait
        // qu'il était TRANSLUCIDE. À cheval sur la plaque du coffre, on
        // voyait le coin arrondi de la carte À TRAVERS lui — un objet qu'on
        // doit pouvoir prendre en main ne peut pas être un fantôme. Les deux
        // vignettes portent donc un alpha (silhouette mesurée au bake,
        // `tools/coffre-v2/bake_vignettes.py` : la luminance ne SAIT PAS
        // séparer le sachet de son halo, ils sont à la même valeur).
        }
    }
}

// MARK: - La pill Booster (le header du profil)

/// La sœur de la pastille des pièces, à côté d'elle : le sachet en 3D (une
/// image du rendu, pas une SCNView — une scène SceneKit dans une capsule
/// coûterait le prix d'une page pour vingt pixels) et le nombre de
/// boosters qui attendent. Un clic ouvre le Manège.
///
/// C'est la RÉCUPÉRATION du parcours : dire « Plus tard » à la pop-up ne
/// perd jamais un sachet, et cette pill est la porte pour y revenir.
struct PillBooster: View {
    var nombre: Int
    var robe: RobeBooster = .lune
    var action: () -> Void

    @State private var kick: CGFloat = 0

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.42)) {
                kick = 1
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.30)) { kick = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { action() }
        } label: {
            HStack(spacing: 7) {
                SachetVignette(largeur: 15, hauteur: 26, robe: robe)
                    .frame(width: 20, height: 24)
                    .rotationEffect(.degrees(Double(kick) * -10))
                Text("\(nombre)")
                    .font(.inter(15, .bold))
                    .foregroundStyle(Color.inkPrimary)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .glassEffect(.regular.tint(Color.black.opacity(0.5))
                             .interactive(),
                         in: .capsule)
            .scaleEffect(1 + 0.10 * kick)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(robe == .noire
            ? "\(nombre) booster noir — ouvrir le manège des légendaires"
            : "\(nombre) booster — ouvrir le manège")
    }
}
