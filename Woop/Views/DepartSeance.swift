import SwiftUI
import AVFoundation

// MARK: - LE DÉPART DE SÉANCE — le panneau du galet play
//
// Le galet play de la barre bijou n'allume plus la séance à sec : il
// ouvre CE panneau — le jumeau assumé de la pop-up booster (même verre,
// même nuit qui fond, même primaire diamant, même échappée en encre
// nue), avec en header LA LUNE QUI SE CHARGE entre l'haltère et les
// disques : `start-entrainement-loop.mp4`, recuit en PING-PONG
// aller-retour (couture mesurée à 0,2 quand deux voisines ordinaires
// valent 0,95 — mathématiquement invisible), muet, composé en ADDITIF
// (le noir de la source disparaît sans détourage). La rampe de +20 % de
// la source n'a PAS été aplatie : c'est la lune qui monte en braise —
// en aller-retour elle devient une RESPIRATION de 16 s.
//
// « Commencer » crée la séance (le `startWorkout` existant de la
// racine), bascule sur la page des exercices et ARME le tuto à
// projecteurs (la première fois seulement).

/// Le chef d'orchestre du départ — une seule instance, lue à la racine
/// (l'école `SacreEtat` : un onglet paresseux n'entend personne).
@Observable
final class DepartEtat {
    static let shared = DepartEtat()
    private init() {}

    /// Le panneau du galet play.
    var panneauOuvert = false
    /// Le tuto de la page exercices est demandé (posé par « Commencer »,
    /// consommé par la page à son apparition).
    var tutoDemande = false
    /// LE PANNEAU DE PAUSE (le stop de la page exercices) — voir
    /// PlayerSeance.swift.
    var pauseOuverte = false
    /// LA CLÔTURE DEMANDÉE par le player (le « Terminer » du panneau
    /// stop de l'ardoise) : la racine l'exécute — elle seule tient la
    /// séance, la bascule d'onglet et la chaîne de fin.
    var clotureDemandee = false
    /// La notif des pièces à l'arrivée home post-clôture : le gain à
    /// annoncer, nil = rien. La chaîne de fin de séance l'orchestre
    /// (trophée → pièces → pop-up booster).
    var notifPieces: Int?

    // MARK: LE CHEMIN EN ARBRE (27-08, jalon 1 de tools/road/AUDIT-ROAD.md)
    //
    // La route quitte le `fullScreenCover` de la home pour un hôte à la
    // RACINE (zIndex 4, sous la pause, la pop-up booster et le Manège) :
    // un cover cachait tout ce qui vit à la racine — une lune qui appelait
    // `SacreEtat.proposer()` ouvrait la pop-up DERRIÈRE la route. Même
    // école que le panneau du galet : un état partagé, un seul hôte.

    /// La route est ouverte.
    var cheminOuvert = false
    /// L'état du chemin au moment de l'ouverture — dérivé des séances par
    /// la home (`EcranSpec.etapeEtFaits`), lu par la racine pour monter la
    /// page. La racine ne connaît pas les séances finies : la porte les lui
    /// donne.
    var cheminEtape = 0
    var cheminFaits: Set<Int> = []
    /// Les dates de complétion des séances faites (`Workout.endedAt`) — 28-08,
    /// sa règle : « les jours apparaissent le jour où le user a terminé sa
    /// séance ». Elles voyagent AVEC les faits : un galet fait porte SA date.
    var cheminDates: [Int: Date] = [:]
    /// ⚠️ **UN GALET EST AU DOIGT** (28-08) — le seul but de ce drapeau est de
    /// faire taire le geste de sortie de `CheminHote` pendant le port. Il est
    /// écrit deux fois par port (prise / lâcher) et **lu uniquement dans la
    /// fermeture du geste**, jamais dans un `body` : sans ça, chaque image du
    /// port reconstruirait la route sous le doigt et tuerait la séquence.
    var galetPorte = false
    /// ⚠️ **LE SOMMEIL DE LA HOME ARRIVE APRÈS LA TRANSITION** (28-08, « on
    /// voit un lag à l'arrivée »). `\.dort` lisait `cheminOuvert` : la home
    /// s'endormait À L'INSTANT du basculement — 14 horloges mises en pause,
    /// vidéos posées, verre démonté — c'est-à-dire EN PLEIN MILIEU de la
    /// course de la route. Le coût du sommeil se payait sur les images de la
    /// transition (le piège de la vue lourde pendant un film, déjà payé ici).
    /// Elle s'endort maintenant une fois la route arrivée, et se RÉVEILLE
    /// immédiatement à la fermeture — le réveil, lui, doit précéder la sortie.
    var homeDort = false
    /// Les nœuds spéciaux (lune, trésor, pièce) déjà RÉCLAMÉS — persistés
    /// tant que la source des rewards (`coin_ledger`, `user_boosters`) n'est
    /// pas là : sans ça, une lune re-tapable à chaque lancement = boosters
    /// infinis. Le jour du backend, cette clé devient une lecture serveur.
    var reclamees: Set<Int> = Set(UserDefaults.standard
        .array(forKey: "chemin.reclamees") as? [Int] ?? []) {
        didSet {
            UserDefaults.standard.set(Array(reclamees).sorted(),
                                      forKey: "chemin.reclamees")
        }
    }

    func ouvrirChemin(etape: Int, faits: Set<Int>, dates: [Int: Date] = [:]) {
        print("[SONDE-CHEMIN] DepartEtat.ouvrirChemin — déjà ouvert ? \(cheminOuvert)")
        guard !cheminOuvert else { return }
        cheminEtape = etape
        cheminFaits = faits
        cheminDates = dates
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        // ⚠️ EASE, PAS RESSORT (28-08) : un ressort à 0,88 d'amortissement
        // dépasse puis revient, et ce retour se lisait comme un décalage. Sur
        // un fondu il n'y a rien à faire dépasser — la courbe doit juste
        // arriver et s'arrêter.
        withAnimation(.easeOut(duration: 0.40)) {
            cheminOuvert = true
        }
        // le fondu dure 0,40 s : on endort après, jamais pendant.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) { [weak self] in
            guard let self, self.cheminOuvert else { return }
            self.homeDort = true
        }
    }

    /// `sansAnimation` : la page est DÉJÀ sortie au doigt (le geste l'a
    /// emmenée hors écran) — la transition de l'hôte ne doit pas la rejouer.
    func fermerChemin(sansAnimation: Bool = false) {
        // Le réveil PRÉCÈDE la sortie : la home doit être vivante quand elle
        // réapparaît, pas la rattraper une demi-seconde plus tard.
        homeDort = false
        if sansAnimation {
            var tx = Transaction()
            tx.disablesAnimations = true
            withTransaction(tx) { cheminOuvert = false }
        } else {
            withAnimation(.easeInOut(duration: 0.34)) { cheminOuvert = false }
        }
    }

    func reclamer(_ id: Int) { reclamees.insert(id) }

    func proposer() {
        guard !panneauOuvert else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
            panneauOuvert = true
        }
    }

    func fermer() {
        withAnimation(.easeOut(duration: 0.22)) { panneauOuvert = false }
    }
}

// MARK: - Le sommeil de la home (jalon 1)

/// `\.dort` — LA HOME DORT SOUS LA ROUTE. Le `fullScreenCover` retirait la
/// vue présentante gratuitement ; en arbre, SwiftUI rend un frère occulté —
/// mesuré au sim : home seule 50-59 img/s, route seule 59-60, les deux
/// ensemble 12-21 (cinq décodeurs vidéo, le verre natif de la home qui
/// recapture une vidéo vivante sous une route opaque). Le sommeil est le
/// PRIX de la sortie du cover : verre démonté (`verreDemonte`), vidéos en
/// POSE (l'image, pas le lecteur — `CalqueVideo` ignore `rate` par trois
/// chemins et un réveil 0→1 flushe la couche), horloges qui peuvent se taire.
/// La home reste MONTÉE : elle est là au premier point du doigt quand la
/// route sortira au geste, sans rejouer son arrivée.
private struct DortKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var dort: Bool {
        get { self[DortKey.self] }
        set { self[DortKey.self] = newValue }
    }
}

// MARK: - L'hôte de la route, et LE GESTE (jalon 5)

/// LE GESTE « COMME SPOTIFY » (verdict 26-08 : « quitter l'écran sans le
/// chevron, très sensible ») : la route se TIRE vers la droite, de
/// n'importe où — le jumeau gestuel du `chevron.left`. Sur les chapitres
/// 2 à 5 le vertical appartient au paging : « au milieu de l'écran » =
/// l'horizontal, ou rien.
///
/// Les lois, toutes payées ailleurs dans la maison :
/// - `.simultaneousGesture`, jamais `.gesture` (exclusif, il perdrait contre
///   les 45 drags des galets) ni `.highPriorityGesture` (il tuerait le scroll
///   de ce toucher sans pouvoir échouer sur la direction) — l'école du
///   `tirageGeste` de la home ;
/// - le VERROU D'AXE se décide UNE fois, au premier point reconnu (12 pt —
///   jamais moins : le chevron et les boutons du panneau sont des `Button`
///   nus sous ce drag) ;
/// - l'offset s'écrit par image sur CET enveloppeur mince, en
///   `visualEffect` (post-layout) — jamais un `@State` de la page (ré-évaluée
///   par image), jamais un `.offset` du conteneur (le ScrollView hors écran
///   re-négocie ses insets) ;
/// - un geste peut mourir sans `onEnded` (Reachability, arrière-plan) :
///   remise à plat sur `startLocation` + chien de garde à jeton (0,6 s — un
///   doigt qui marque un temps n'est pas un geste mort) ;
/// - la home dort dessous (`\.dort`) : elle est là au premier point du
///   doigt, sous un voile noir qui s'ouvre avec la course.
struct CheminHote<Contenu: View>: View {
    /// La page est sortie au doigt : l'hôte la démonte SANS animation.
    var onSortie: () -> Void
    @ViewBuilder var contenu: () -> Contenu

    @State private var tirage: CGFloat = 0
    /// 0 indécis · 1 horizontal (à nous) · −1 vertical (au scroll)
    @State private var axe = 0
    @State private var debut: CGPoint? = nil
    @State private var seuilFranchi = false
    @State private var jeton = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { g in
            let L = max(g.size.width, 1)
            let p = min(max(tirage / L, 0), 1)
            ZStack {
                // le voile sur la home endormie : 0,35 → 0 avec la course
                Color.black.opacity(0.35 * (1 - p))
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                contenu()
                    .visualEffect { [tirage] c, _ in c.offset(x: tirage) }
                    // ⚠️ **LA ZONE TACTILE SUIT LE DÉPLACEMENT** (27-08, cause
                    // CONFIRMÉE du gel de TOUTE l'app). `visualEffect` déplace
                    // les PIXELS hors écran, PAS le hit-test : la page du
                    // chemin, poussée à droite (`tirage` grand, sortie ou
                    // geste en cours), restait plein cadre au toucher et
                    // MANGEAIT tous les touchers de l'app (menu, stop, molette,
                    // clic, chevron) — invisible, jusqu'au kill. Dès qu'elle
                    // n'est plus à sa place, elle cesse de prendre le doigt ;
                    // au repos (tirage ~ 0) elle reste pleinement interactive.
                    .allowsHitTesting(tirage < 2)
            }
            .simultaneousGesture(
                // ⚠️ **24 pt, PAS 12** (28-08, « je clique n'importe où dans
                // l'écran et ça se ferme »). Ce n'était pas l'overlay qui se
                // fermait : c'était TOUTE LA ROUTE qui partait. À 12 pt, un
                // pouce qui roule en tapant suffit à armer le geste, et le
                // verrou d'axe ne demande qu'un dx positif.
                DragGesture(minimumDistance: 24, coordinateSpace: .local)
                    .onChanged { v in
                        if debut != v.startLocation {
                            debut = v.startLocation
                            axe = 0
                            seuilFranchi = false
                        }
                        // ⚠️ LE JOUET PASSE AVANT LA SORTIE : un galet au
                        // doigt gèle ce geste pour toute la durée de la
                        // course (`axe = -1` le condamne jusqu'au prochain
                        // `startLocation`), et la page rentre si elle avait
                        // déjà glissé. Sans ça, porter un galet vers la
                        // droite faisait sortir de la route.
                        if DepartEtat.shared.galetPorte {
                            axe = -1
                            if tirage > 0 {
                                withAnimation(.spring(response: 0.38,
                                                      dampingFraction: 0.86)) {
                                    tirage = 0
                                }
                            }
                            return
                        }
                        if axe == 0 {
                            let dx = v.translation.width, dy = v.translation.height
                            axe = (abs(dx) > 1.4 * abs(dy) && dx > 0) ? 1 : -1
                        }
                        guard axe == 1 else { return }
                        tirage = max(0, v.translation.width)
                        armerChienDeGarde()
                        if !seuilFranchi, tirage > 0.28 * L {
                            seuilFranchi = true
                            UIImpactFeedbackGenerator(style: .light)
                                .impactOccurred(intensity: 0.7)
                        }
                    }
                    .onEnded { v in
                        defer { axe = 0; debut = nil }
                        guard axe == 1 else { return }
                        jeton += 1
                        // « très sensible » : 28 % de la largeur, OU l'élan
                        // (la course prédite dépasse 60 %).
                        // ⚠️ **L'ÉLAN EXIGE MAINTENANT UNE COURSE RÉELLE**
                        // (28-08). `predictedEndTranslation` extrapole la
                        // VITESSE : un pouce qui roule de 12-20 pt en tapant
                        // prédit plus de 240 pt, donc franchissait les 60 % à
                        // lui seul — et la route sortait sur un TAP. C'est le
                        // seul chemin du code qui produise une disparition
                        // sèche (`fermerChemin(sansAnimation:)`), et c'est ce
                        // qu'elle prenait pour « l'overlay se ferme tout seul ».
                        // Le flick reste servi, mais il doit avoir vraiment
                        // parcouru 12 % de la largeur.
                        let sort = tirage > 0.28 * L
                            || (tirage > 0.12 * L
                                && v.predictedEndTranslation.width > 0.60 * L)
                        if sort {
                            UIImpactFeedbackGenerator(style: .soft)
                                .impactOccurred(intensity: 0.6)
                            withAnimation(reduceMotion
                                          ? .easeOut(duration: 0.12)
                                          : .easeOut(duration: 0.26)) {
                                tirage = L * 1.02
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.27) {
                                onSortie()
                            }
                        } else {
                            withAnimation(.spring(response: 0.38,
                                                  dampingFraction: 0.86)) {
                                tirage = 0
                            }
                        }
                    })
        }
    }

    /// Le geste meurt sans `onEnded` : à 0,6 s sans nouvelle, la page rejoint
    /// l'état stable le plus proche.
    ///
    /// ⚠️ **IL COMMET LA SORTIE, PAS SEULEMENT `tirage = 0`** (27-08). Avant, un
    /// geste mort au-delà du seuil (le doigt volé au bord bas, EXACTEMENT là où
    /// vit ce tirage) se contentait de ramener `tirage = 0` — la page revenait
    /// pleine à l'écran mais `cheminOuvert` restait `true`, montée au-dessus du
    /// TabView : la route « encore là alors que je crois être rentrée ». Si le
    /// seuil de sortie était franchi, on FERME franchement (`onSortie` →
    /// `fermerChemin`, démontage) ; sinon seulement on revient à sa place.
    private func armerChienDeGarde() {
        jeton += 1
        let j = jeton
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            guard jeton == j, axe == 1 else { return }
            axe = 0
            debut = nil
            if seuilFranchi {
                onSortie()
            } else {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                    tirage = 0
                }
            }
        }
    }
}

// MARK: - La boucle vidéo du départ

/// Le plan de la lune qui se charge — l'école exacte de la pop-up
/// booster : `AVPlayerLooper` (jamais un seek sur didPlayToEndTime),
/// looper RETENU, muet, et le démontage qui rend tout.
struct DepartLoopVideo: UIViewRepresentable {
    final class Coordinator {
        var player: AVQueuePlayer?
        var looper: AVPlayerLooper?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> BoosterLoopLayerView {
        let v = BoosterLoopLayerView()
        v.backgroundColor = .clear
        v.isUserInteractionEnabled = false
        v.playerLayer.videoGravity = .resizeAspectFill
        guard let url = Bundle.main.url(
            forResource: "start-entrainement-loop",
            withExtension: "mp4") else {
            // Sans le fichier, le panneau reste le panneau — jamais un
            // rectangle noir « en attendant ».
            return v
        }
        let p = AVQueuePlayer()
        p.isMuted = true
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

// MARK: - L'hôte

/// Le conteneur reste MONTÉ (transparent, sourd au doigt quand il est
/// vide) : c'est lui qui joue l'entrée et la sortie — l'école du
/// « Recommencer », à la lettre.
struct DepartPanneauHote: View {
    var ouverte: Bool
    var onCommencer: () -> Void = {}
    var onFermer: () -> Void = {}

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .bottom) {
                Color.clear
                if ouverte {
                    Color.black.opacity(0.12)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { onFermer() }
                        .transition(.opacity)
                    DepartPanneau(W: g.size.width,
                                  onCommencer: onCommencer,
                                  onFermer: onFermer)
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

// MARK: - Le panneau

struct DepartPanneau: View {
    var W: CGFloat
    var onCommencer: () -> Void = {}
    var onFermer: () -> Void = {}

    @State private var pull: CGFloat = 0
    @State private var naissance = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Coins HAUTS seuls — le bas appartient à l'écran.
    private static let forme = UnevenRoundedRectangle(
        cornerRadii: .init(topLeading: 34, bottomLeading: 0,
                           bottomTrailing: 0, topTrailing: 34),
        style: .continuous)
    /// Le ratio du fichier recuit (1080×608) — l'emplacement est taillé
    /// dessus pour que rien ne soit recadré.
    private static let ratioVideo: CGFloat = 1080.0 / 608.0

    private var slotH: CGFloat { W / Self.ratioVideo }
    private var hauteur: CGFloat { slotH + 246 }

    var body: some View {
        panneau(W: W, slotH: slotH)
            .frame(width: W, height: hauteur)
            .offset(y: pull)
            .contentShape(Self.forme)
            .simultaneousGesture(dismissDrag)
    }

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
            Color.clear.frame(height: slotH + 34)

            Text("Ta séance commence ici.")
                .font(.inter(20, .semibold))
                .foregroundStyle(Color.inkPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 30)
            Text("Choisis ton premier exercice — la lune s'occupe du feu.")
                .font(.inter(12.5))
                .foregroundStyle(Color.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.top, 7)
                .padding(.horizontal, 30)

            Spacer(minLength: 0)

            DiamondPrimaryButton(title: "Commencer",
                                 smokeWarmth: 0.55) {
                onCommencer()
            }
            .padding(.horizontal, 26)
            .padding(.top, 32)

            Button { onFermer() } label: {
                Text("Plus tard")
                    .font(.inter(15, .medium))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
            .padding(.bottom, 34)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            GeometryReader { p in
                let H = max(p.size.height, 1)
                let pied = min(slotH / H, 0.9)
                ZStack {
                    // Jamais `.interactive()` sur un grand verre : il
                    // vole les gestes de ce qui vit dessus.
                    Color.clear.glassEffect(
                        .regular.tint(Color.black.opacity(0.30)),
                        in: Self.forme)
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
        // L'OBJET DE LUMIÈRE : le plan en additif, la caméra vivante
        // par transformation (jamais la frame — un AVPlayerLayer
        // redimensionné 60×/s relayoute et re-rend chaque image), des
        // périodes PREMIÈRES entre elles et avec les 16 s du plan :
        // aucun instant n'est deux fois le même.
        .overlay(alignment: .top) {
            ZStack {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0,
                                        paused: reduceMotion)) { tl in
                    let e = tl.date.timeIntervalSince(naissance)
                    let pose: CGFloat = reduceMotion
                        ? 1 : 1 + 0.10 * CGFloat(exp(-e * 1.9))
                    let respire: CGFloat = reduceMotion ? 1
                        : 1 + 0.045 * CGFloat(sin(e * 2 * .pi / 37.0))
                            + 0.022 * CGFloat(sin(e * 2 * .pi / 23.0 + 1.7))
                    let dx: CGFloat = reduceMotion ? 0
                        : 6 * CGFloat(sin(e * 2 * .pi / 41.0 + 0.6))
                    let dy: CGFloat = reduceMotion ? 0
                        : 4 * CGFloat(sin(e * 2 * .pi / 29.0))
                    DepartLoopVideo()
                        .frame(width: slotH * Self.ratioVideo,
                               height: slotH)
                        .blendMode(.plusLighter)
                        .scaleEffect(pose * respire)
                        .offset(x: dx, y: dy)
                }
            }
            .frame(width: W, height: slotH)
            .allowsHitTesting(false)
        }
        .clipShape(Self.forme)
        .overlay {
            Self.forme
                .strokeBorder(LinearGradient(stops: [
                    .init(color: Color.white.opacity(0.16), location: 0),
                    .init(color: Color.white.opacity(0.03), location: 0.18),
                    .init(color: .clear, location: 0.45)
                ], startPoint: .top, endPoint: .bottom), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .top) {
            Capsule()
                .fill(Color.white.opacity(0.28))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .allowsHitTesting(false)
        }
    }
}
