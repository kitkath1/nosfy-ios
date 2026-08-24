import SwiftUI
import AVFoundation
import Observation

// LA DUOLINGUO_PAGE — « LE CHEMIN DE FEU » (24-08).
// Plan : tools/duolingo/PLAN-DUOLINGUO.md. Jalon J1 : la colonne nue —
// cinq écrans vidéo, l'aimant de page, le rate piloté, la fenêtre
// frontière 4/5 à cheval sur la couture. Le chemin de galets vient en J2/J3.
//
// Les lois de la maison qui tiennent cette page :
//  - VStack NON-lazy : une LazyVStack ne garantit AUCUN voisin monté et
//    ferait naître un lecteur EN PLEIN geste de frontière (poster figé
//    contre jumelle vivante). Les ~10 lecteurs naissent UNE fois ; le coût
//    se pilote au RATE — un AVPlayerLayer à rate 0 ne décode pas.
//  - UNE SEULE SONDE PAR SCROLL, sur un type composé (le champ vivant
//    emporte les stables) ; elle écrit un @Observable HORS corps de page,
//    et le corps de la page n'en relit RIEN (piège de la page ré-évaluée).
//  - RATIO FICHIER = RATIO FENÊTRE : chaque fenêtre dérive sa hauteur du
//    ratio du fichier cuit — rien n'est rogné par resizeAspectFill, les
//    extinctions cuites tombent où le plan les attend.
//  - ON TRANSFORME, ON NE REDIMENSIONNE JAMAIS : parallaxe et voiles en
//    visualEffect (tout se lit dans le proxy, zéro invalidation).

// MARK: - Les cotes (EcranSpec)

/// LA TABLE DES CINQ ÉCRANS — les cotes mesurées au numpy sur les maquettes
/// (plan §2bis, shots/maquette-ecran-*.png). Le recalage d'un écran repassé
/// par Kathryn = le diff d'une ligne ici (jalon R-n).
///
/// La hauteur d'une fenêtre ne s'écrit PAS : elle se DÉRIVE du ratio du
/// fichier cuit (h = largeur × ratioHL), pour que le ratio fenêtre soit
/// exactement le ratio fichier sur n'importe quel écran.
struct EcranSpec: Equatable, Identifiable {
    let id: Int
    /// Fenêtre clouée au bord HAUT (nil = la frontière l'occupe).
    let haut: FenetreSpec?
    /// Fenêtre clouée au bord BAS (nil = la frontière l'occupe).
    let bas: FenetreSpec?

    struct FenetreSpec: Equatable {
        let nom: String          // fichier duo-* dans le bundle
        let ratioHL: CGFloat     // hauteur/largeur du fichier cuit
        var parallaxe: CGFloat = 0   // le verre est lourd, il prend du retard
        var decalageX: CGFloat = 0   // décalage horizontal (cadrages latéraux)
        var pose: String { nom + "-poster" }
    }

    static let les5: [EcranSpec] = [
        // ÉCRAN 1 — LE VERRE NOIR (col au bord, ventre aux 4/5 de la fenêtre)
        EcranSpec(id: 0,
                  haut: .init(nom: "duo-galet-noir", ratioHL: 1560.0/1206.0,
                              parallaxe: 0.10),
                  bas: .init(nom: "duo-flamme-blanche", ratioHL: 524.0/804.0)),
        // ÉCRAN 2 — LA FLAMME SUSPENDUE
        EcranSpec(id: 1,
                  haut: .init(nom: "duo-flamme-blanche-haut", ratioHL: 646.0/804.0),
                  bas: .init(nom: "duo-galet-rouge", ratioHL: 600.0/1206.0,
                             parallaxe: 0.10)),
        // ÉCRAN 3 — LE ROUGE (la parité exos, en matière)
        EcranSpec(id: 2,
                  haut: .init(nom: "duo-verre-rouge", ratioHL: 840.0/1206.0,
                              parallaxe: 0.12),
                  bas: .init(nom: "duo-flamme-rouge", ratioHL: 600.0/804.0)),
        // ÉCRAN 4 — LE FEU RENVERSÉ (le bas appartient à la frontière)
        EcranSpec(id: 3,
                  haut: .init(nom: "duo-flamme-rouge-haut", ratioHL: 608.0/804.0),
                  bas: nil),
        // ÉCRAN 5 — LE BLEU (le haut appartient à la frontière)
        EcranSpec(id: 4,
                  haut: nil,
                  bas: .init(nom: "duo-flamme-bleue", ratioHL: 466.0/804.0)),
    ]

    /// LE SERPENTIN (J3) — les 11 étapes, posées dans la bande noire
    /// MESURÉE de chaque écran (§2bis du plan), cotes pour 874 pt de haut.
    /// La dernière est LE NŒUD-TRÉSOR (« le chest Duolingo, c'est le
    /// booster de Woop ») : plus grand, il porte la lune, il promet.
    struct EtapeSpec: Equatable, Identifiable {
        let id: Int
        let ecran: Int
        let dx: CGFloat        // écart à l'axe (serpentin ±62)
        let y: CGFloat         // dans l'écran, base 874
        var tresor = false
    }

    static let etapes: [EtapeSpec] = [
        EtapeSpec(id: 0, ecran: 0, dx: 0, y: 542),
        EtapeSpec(id: 1, ecran: 1, dx: -58, y: 385),
        EtapeSpec(id: 2, ecran: 1, dx: 52, y: 500),
        EtapeSpec(id: 3, ecran: 1, dx: -40, y: 615),
        EtapeSpec(id: 4, ecran: 2, dx: 55, y: 350),
        EtapeSpec(id: 5, ecran: 2, dx: -50, y: 480),
        EtapeSpec(id: 6, ecran: 3, dx: 45, y: 360),
        EtapeSpec(id: 7, ecran: 3, dx: -55, y: 450),
        EtapeSpec(id: 8, ecran: 4, dx: 50, y: 400),
        EtapeSpec(id: 9, ecran: 4, dx: -45, y: 495),
        EtapeSpec(id: 10, ecran: 4, dx: 0, y: 590, tresor: true),
    ]

    /// LA FRONTIÈRE 4/5 : une seule fenêtre à cheval sur la couture, ancrée
    /// trailing — le dôme rouge vit au bas de l'écran 4, le ventre bleu au
    /// haut de l'écran 5, et c'est le scroll qui fait le voyage (LOI 1).
    /// CLOUÉE en J1 (parallaxe 0) : un objet à cheval sur deux poses n'a pas
    /// de repos unique — sa chorégraphie (courbe en S) est la partition J4.
    static let frontiere = FenetreSpec(nom: "duo-galet-rougebleu",
                                       ratioHL: 2100.0/1080.0,
                                       parallaxe: 0)
    /// Largeur de la frontière en fraction de l'écran (360/402 de la maquette).
    static let frontiereLargeur: CGFloat = 360.0 / 402.0
}

// MARK: - L'état

/// L'ÉTAT VIVANT DE LA PAGE — hors corps de vue (« @Observable, ET SURTOUT
/// PAS UN @State SUR LA PAGE », la loi de la porte). Le corps de
/// DuolinguoPage n'en relit rien ; seuls les écrans lisent LEUR booléen de
/// lecture, la frontière le sien.
@Observable final class EtatDuo {
    /// Quels lecteurs vivent : un par écran (l'écran courant + l'entrant).
    var lecture: [Bool] = [true, true, false, false, false]
    /// Le lecteur de la fenêtre frontière 4/5.
    var lectureFrontiere = false
    /// Le gel du banc (`-duoFreeze`) et de reduceMotion : tout à l'arrêt.
    var gel = false
    /// L'étape ACTIVE du chemin (0-based). Session UI : reset au relaunch.
    var etape = 0
    /// L'écran posé (pour le titre de la dalle) et le geste en cours
    /// (la dalle s'efface pendant le scroll).
    var ecranCourant = 0
    var enGeste = false
    /// La naissance : les étapes déjà apparues (cascade d'ouverture).
    var nees: Set<Int> = []

    /// Recalcule les rates depuis l'offset — écritures GARDÉES : la sonde
    /// tombe à chaque image, les booléens ne bougent qu'aux frontières.
    func piloter(y: CGFloat, hauteur: CGFloat) {
        guard hauteur > 0 else { return }
        let a = max(0, min(4, Int(floor(y / hauteur))))
        let b = max(0, min(4, Int(ceil(y / hauteur))))
        for i in 0..<5 {
            let veut = !gel && (i == a || i == b)
            if lecture[i] != veut { lecture[i] = veut }
        }
        let front = !gel && (a == 3 || b == 3 || a == 4 || b == 4)
        if lectureFrontiere != front { lectureFrontiere = front }
        let pose = Int((y / hauteur).rounded())
        let borne = max(0, min(4, pose))
        if ecranCourant != borne { ecranCourant = borne }
    }
}

/// LA SONDE — une seule, composée : le champ vivant (y) emporte le stable
/// (fin). Deux sondes sur le même scroll se volent les rappels.
private struct SondeDuo: Equatable {
    var y: CGFloat
    var fin: CGFloat
}

// MARK: - Le lecteur qui sait naître en pause

/// `CalqueVideoPilote` — le jumeau de `CalqueVideo` (DepartCine) avec le
/// trou du « né en pause » comblé. L'original force la lecture par TROIS
/// chemins qui ignorent `rate` : le `play()` de makeUIView, la complétion
/// du preroll, le retour de foreground — un voisin monté à rate 0
/// s'auto-relançait au `readyToPlay` et sa garde (`c.rate == rate`) ne le
/// re-pausait jamais. Ici, les trois chemins rejouent `coordinator.rate`.
///
/// Tout le reste est la loi de l'original : pose DANS la vue sous le
/// playerLayer (le trou du looper : 1-3 images vides par tour), effacée sur
/// `isReadyForDisplay` ; aspectFill + clipsToBounds + masksToBounds (le
/// clipShape SwiftUI ne rattrape pas une couche UIKit) ; frame posée sous
/// CATransaction ; looper RETENU ; preroll attaché à la KVO `.status`
/// (appelé avant readyToPlay il TUE l'app).
struct CalqueVideoPilote: UIViewRepresentable {

    let nom: String
    let pose: String
    var rate: Float = 1.0

    final class Vue: UIView {
        let pose = UIImageView()
        let playerLayer = AVPlayerLayer()
        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .clear
            isUserInteractionEnabled = false
            pose.contentMode = .scaleAspectFill
            pose.clipsToBounds = true
            addSubview(pose)
            playerLayer.videoGravity = .resizeAspectFill
            playerLayer.backgroundColor = UIColor.clear.cgColor
            layer.addSublayer(playerLayer)
            clipsToBounds = true
            playerLayer.masksToBounds = true
        }
        required init?(coder: NSCoder) { fatalError() }
        override func layoutSubviews() {
            super.layoutSubviews()
            pose.frame = bounds
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            playerLayer.frame = bounds
            CATransaction.commit()
        }
    }

    final class Coordinator {
        var player: AVQueuePlayer?
        var looper: AVPlayerLooper?
        var retour: NSObjectProtocol?
        var statut: NSKeyValueObservation?
        var pret: NSKeyValueObservation?
        var rate: Float = 1
        deinit {
            if let r = retour { NotificationCenter.default.removeObserver(r) }
            statut?.invalidate()
            pret?.invalidate()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> Vue {
        let v = Vue()
        v.pose.image = UIImage(named: pose)
        guard let url = Bundle.main.url(forResource: nom, withExtension: "mp4")
        else { return v }                       // la pose tient la page seule
        let p = AVQueuePlayer()
        p.isMuted = true
        p.automaticallyWaitsToMinimizeStalling = false
        let c = context.coordinator
        c.rate = rate
        c.looper = AVPlayerLooper(player: p, templateItem: AVPlayerItem(url: url))
        c.player = p
        v.playerLayer.player = p
        // NÉ EN PAUSE : pas de play() si le rate initial est nul — le
        // preroll chargera la première image, elle suffira.
        if rate > 0 { p.rate = rate }
        c.statut = p.observe(\.status, options: [.new]) { [weak c] joueur, _ in
            guard joueur.status == .readyToPlay else { return }
            joueur.preroll(atRate: 1) { [weak c] fini in
                guard fini, let c else { return }
                DispatchQueue.main.async { c.player?.rate = c.rate }
            }
        }
        c.pret = v.playerLayer.observe(\.isReadyForDisplay, options: [.new]) {
            couche, _ in
            guard couche.isReadyForDisplay else { return }
            DispatchQueue.main.async { v.pose.isHidden = true }
        }
        c.retour = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil, queue: .main) { [weak c] _ in
            guard let c else { return }
            c.player?.rate = c.rate
        }
        return v
    }

    func updateUIView(_ v: Vue, context: Context) {
        let c = context.coordinator
        guard let p = c.player else { return }
        guard abs(c.rate - rate) > 0.01 else { return }
        c.rate = rate
        p.rate = rate
    }

    static func dismantleUIView(_ v: Vue, coordinator: Coordinator) {
        coordinator.player?.pause()
        coordinator.looper?.disableLooping()
        v.playerLayer.player = nil
    }
}

// MARK: - Une fenêtre vidéo

/// LA FENÊTRE : `Color.clear` + overlay + clipped — la SEULE forme qui ne
/// gonfle pas son hôte (le piège detail-gonfle, payé à l'échelle page sur
/// l'iPod). Taille CONSTANTE ; les mouvements vivent au-dessus.
private struct FenetreVideo: View {
    let spec: EcranSpec.FenetreSpec
    let largeur: CGFloat
    /// La position de REPOS de la fenêtre dans le viewport, quand son écran
    /// est à la pose. ⚠️ La parallaxe se calcule sur le DÉPLACEMENT
    /// (minY − restY), jamais sur minY absolu : une fenêtre du bas vit à
    /// minY = 674 au repos — le minY nu la décalait de −67 pt à la pose
    /// (mesuré : le dôme rouge remontait dans la bande du chemin).
    let restY: CGFloat
    let joue: Bool

    var body: some View {
        Color.clear
            .frame(width: largeur, height: largeur * spec.ratioHL)
            .overlay {
                CalqueVideoPilote(nom: spec.nom, pose: spec.pose,
                                  rate: joue ? 1.0 : 0.0)
            }
            .clipped()
            // La parallaxe : le verre est lourd, il prend du retard sur le
            // doigt. Tout se lit dans le proxy — zéro invalidation.
            .visualEffect { [parallaxe = spec.parallaxe, restY] contenu, proxy in
                let d = proxy.frame(in: .scrollView).minY - restY
                return contenu.offset(y: -d * parallaxe)
            }
    }
}

// MARK: - Un écran

/// UN ÉCRAN DE LA COLONNE — fond noir absolu, au plus deux fenêtres clouées
/// aux bords. Entrées STABLES (spec + etat) ; seul le booléen de lecture de
/// CET écran est lu ici — l'Observation ne réveille que lui.
private struct EcranDuo: View {
    let spec: EcranSpec
    let etat: EtatDuo

    var body: some View {
        let joue = etat.lecture[spec.id]
        GeometryReader { g in
            ZStack {
                Color.black
                if let haut = spec.haut {
                    FenetreVideo(spec: haut, largeur: g.size.width,
                                 restY: 0, joue: joue)
                        .offset(x: haut.decalageX)
                        .frame(maxWidth: .infinity, maxHeight: .infinity,
                               alignment: .top)
                }
                if let bas = spec.bas {
                    FenetreVideo(spec: bas, largeur: g.size.width,
                                 restY: g.size.height - g.size.width * bas.ratioHL,
                                 joue: joue)
                        .offset(x: bas.decalageX)
                        .frame(maxWidth: .infinity, maxHeight: .infinity,
                               alignment: .bottom)
                }
            }
            // LE VOILE SORTANT (LOI 1 : la frontière appartient à UN objet,
            // les autres s'effacent) — le « fondu noir quand nécessaire » du
            // brief, version runtime : l'écran qui part sous le bord haut
            // reçoit 0→12 % de nuit. Un Color en visualEffect : la géométrie
            // pilote l'opacité, rien n'invalide la page.
            .overlay {
                Color.black
                    .visualEffect { contenu, proxy in
                        let f = proxy.frame(in: .scrollView)
                        let sortie = max(0, min(1, -f.minY / max(1, f.height)))
                        return contenu.opacity(Double(sortie) * 0.12)
                    }
                    .allowsHitTesting(false)
            }
        }
        .clipped()
    }
}

// MARK: - Le chemin

/// LE SERPENTIN — une seule couche pour toute la colonne, posée au-dessus
/// du verre vidéo. Pas de fil : dans le noir OLED, le chemin se lit par
/// les galets seuls (le pointillé board-game est interdit, LOI 4).
private struct CheminDuo: View {
    let etat: EtatDuo
    let hauteur: CGFloat
    let largeur: CGFloat
    /// L'étape suivante vit sur un autre écran → la page défile d'une pose.
    var onEcranSuivant: (Int) -> Void = { _ in }

    var body: some View {
        let k = hauteur / 874.0
        ZStack(alignment: .topLeading) {
            ForEach(EcranSpec.etapes) { e in
                let quel = etatDe(e)
                GaletEtape(etat: quel,
                           numero: e.tresor ? nil : e.id + 1,
                           glyphe: e.tresor ? "moon.fill" : nil,
                           taille: e.tresor ? 98 : (quel == .actif ? 84 : 76),
                           onTap: { tape(e) })
                    .scaleEffect(etat.nees.contains(e.id) ? 1 : 0.92)
                    .opacity(etat.nees.contains(e.id) ? 1 : 0)
                    .position(x: largeur / 2 + e.dx,
                              y: (CGFloat(e.ecran) * 874 + e.y) * k)
            }
        }
        .frame(width: largeur, height: hauteur * 5, alignment: .topLeading)
    }

    private func etatDe(_ e: EcranSpec.EtapeSpec) -> EtapeEtat {
        if e.id < etat.etape { return .accompli }
        if e.id == etat.etape { return .actif }
        if e.id == etat.etape + 1 { return .prochain }
        return .verrouille
    }

    /// LE PASSAGE D'ÉTAPE (partition §7) : l'adieu de l'actif, la bascule,
    /// l'allumage du suivant — et si le suivant vit sur l'écran d'après,
    /// la page défile vers sa POSE aimantée (jamais une mi-course que
    /// l'aimant re-happerait).
    private func tape(_ e: EcranSpec.EtapeSpec) {
        guard e.id == etat.etape,
              etat.etape + 1 < EcranSpec.etapes.count else { return }
        let suivant = etat.etape + 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                etat.etape = suivant
            }
        }
        let la = EcranSpec.etapes[suivant].ecran
        if la != e.ecran {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                onEcranSuivant(la)
            }
        }
    }
}

// MARK: - La dalle de chapitre

/// LA DALLE — verre natif `.clear` NOURRI par la vidéo (chaque écran a sa
/// fenêtre haute au repos : il y a toujours de la matière dessous, le cas
/// exact que la loi affinée du 20-08 autorise). L'encre vit AU-DESSUS du
/// verre, jamais dans le conteneur (l'encre lentillée = fantômes). Elle
/// s'efface pendant le geste — le verre se DÉMONTE sous 1 % (le natif
/// ignore `.opacity`), l'encre fond.
private struct DalleChapitre: View {
    let etat: EtatDuo
    static let noms = ["Le verre noir", "La flamme suspendue", "Le rouge",
                       "Le feu renversé", "Le bleu"]

    var body: some View {
        let visible = !etat.enGeste
        ZStack {
            if visible {
                GlassEffectContainer(spacing: 0) {
                    Color.clear
                        .glassEffect(.clear,
                                     in: RoundedRectangle(cornerRadius: 20))
                }
                // LA PELLICULE — l'école de la molette : une pellicule noire
                // AU-DESSUS du verre, SOUS l'encre. Sans elle, l'encre
                // blanche se perd sur la flamme blanche (écran 2) et le
                // bout de la capsule lentille un anneau fantôme sur le
                // flanc clair du galet noir (écran 1).
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.30))
            }
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("CHAPITRE 1")
                        .font(.system(size: 11, weight: .semibold))
                        .kerning(1.6)
                        .foregroundStyle(Color(white: 0.52))
                    ZStack(alignment: .leading) {
                        Text(Self.noms[etat.ecranCourant])
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(LinearGradient(
                                colors: [Color(white: 1.0), Color(white: 0.82)],
                                startPoint: .top, endPoint: .bottom))
                            .id(etat.ecranCourant)
                            .transition(.opacity)
                    }
                }
                Spacer(minLength: 12)
                // LE RAIL DE JEU — la surface, pas la stratégie : chiffres
                // FACTICES, monochromes, inertes cette session.
                HStack(spacing: 14) {
                    rail(glyphe: "moon.fill", valeur: "240")
                    rail(glyphe: "flame.fill", valeur: "7")
                }
            }
            .padding(.horizontal, 18)
            .opacity(visible ? 1 : 0)
        }
        .frame(height: 58)
        .padding(.horizontal, 20)
        .animation(.easeInOut(duration: 0.28), value: visible)
        .animation(.easeInOut(duration: 0.35), value: etat.ecranCourant)
        .allowsHitTesting(false)
    }

    private func rail(glyphe: String, valeur: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: glyphe)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(white: 0.60))
            Text(valeur)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(LinearGradient(
                    colors: [Color(white: 0.98), Color(white: 0.78)],
                    startPoint: .top, endPoint: .bottom))
        }
    }
}

// MARK: - La page

struct DuolinguoPage: View {
    /// L'état vivant — créé ici, JAMAIS relu par ce corps.
    @State private var etat = EtatDuo()
    /// Le jeton de scroll du banc (`-duoEcran`, `-duoAuto`).
    @State private var ordre = ScrollPosition()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Options du banc, lues DANS la vue (jamais dans RootView).
    var ecranInitial: Int = 0
    var etapeInitiale: Int = 0
    var gel = false
    var auto = false

    var body: some View {
        // LE PROXY EST DEHORS, seul le défilement fuit la zone sûre (école
        // CoffreFortFlow : un ignoresSafeArea sur le GeometryReader rend une
        // encoche de ZÉRO).
        GeometryReader { g in
            let hauteur = g.size.height + g.safeAreaInsets.top + g.safeAreaInsets.bottom
            let largeurFront = g.size.width * EcranSpec.frontiereLargeur
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    ForEach(EcranSpec.les5) { spec in
                        EcranDuo(spec: spec, etat: etat)
                            .containerRelativeFrame(.vertical)
                    }
                }
                .scrollTargetLayout()
                // LA FRONTIÈRE 4/5 — DANS le scroll (hors du scroll, la
                // sonde a une frame de retard : le galet glisserait contre
                // ses écrans — la marche à la couture). Offset CONSTANT en
                // coordonnées de contenu : le centre de la fenêtre sur la
                // couture, à y = 4 × hauteur. Sous le chemin (J2+), au-dessus
                // des écrans.
                .overlay(alignment: .top) {
                    let hFront = largeurFront * EcranSpec.frontiere.ratioHL
                    FenetreVideo(spec: EcranSpec.frontiere,
                                 largeur: largeurFront,
                                 restY: hauteur - hFront / 2,
                                 joue: etatFrontiere)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .offset(y: 4 * hauteur - hFront / 2)
                        .allowsHitTesting(false)
                }
                // LE CHEMIN — au-dessus du verre vidéo, DANS le scroll.
                .overlay(alignment: .top) {
                    CheminDuo(etat: etat, hauteur: hauteur,
                              largeur: g.size.width) { ecran in
                        withAnimation(.easeInOut(duration: 0.7)) {
                            ordre.scrollTo(y: CGFloat(ecran) * hauteur)
                        }
                        UIImpactFeedbackGenerator(style: .medium)
                            .impactOccurred(intensity: 0.9)
                    }
                }
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollPosition($ordre)
            .background(Color.black)
            .ignoresSafeArea()
            // UNE sonde, composée ; l'action pilote les rates (écritures
            // gardées dans EtatDuo — les booléens ne bougent qu'aux
            // frontières, la page ne se ré-évalue pas).
            .onScrollGeometryChange(for: SondeDuo.self) { geo in
                SondeDuo(y: geo.contentOffset.y + geo.contentInsets.top,
                         fin: max(0, geo.contentSize.height - geo.containerSize.height))
            } action: { _, neuf in
                etat.piloter(y: neuf.y, hauteur: hauteur)
            }
            // LA PHASE, séparée de la géométrie (une sonde de phase ne vole
            // pas les rappels de la sonde composée) : la dalle s'efface au
            // doigt, revient à la pose.
            .onScrollPhaseChange { _, neuf in
                let geste = neuf != .idle
                if etat.enGeste != geste { etat.enGeste = geste }
            }
            .onAppear {
                etat.gel = gel || reduceMotion
                etat.etape = etapeInitiale
                etat.piloter(y: CGFloat(ecranInitial) * hauteur, hauteur: hauteur)
                if ecranInitial > 0 {
                    ordre.scrollTo(y: CGFloat(ecranInitial) * hauteur)
                }
                if auto { lancerAuto(hauteur: hauteur) }
                naissance()
            }
        }
        .background(Color.black.ignoresSafeArea())
        // LA DALLE — hors scroll (école PorteEntree : le header vit hors
        // scroll), posée sous l'île.
        .overlay(alignment: .top) {
            DalleChapitre(etat: etat)
                .padding(.top, 8)
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .sondeCadence("duo")
    }

    /// L'OUVERTURE (partition §7, version J3) : les étapes naissent en
    /// cascade, 60 ms d'écart, après que la colonne s'est posée.
    private func naissance() {
        if etat.gel {
            etat.nees = Set(EcranSpec.etapes.map(\.id))
            return
        }
        for (n, e) in EcranSpec.etapes.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + Double(n) * 0.06) {
                _ = withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                    etat.nees.insert(e.id)
                }
            }
        }
    }

    /// Le corps ne lit pas `etat`… sauf ce booléen discret de la frontière,
    /// isolé ici pour que seule la fenêtre frontière se réévalue.
    private var etatFrontiere: Bool { etat.lectureFrontiere }

    /// `-duoAuto` : l'aller-retour filmé 1 → 5 → 1, une pose par écran —
    /// le film du fouettage (école `-porteAuto` : scrollTo dans withAnimation).
    private func lancerAuto(hauteur: CGFloat) {
        let poses: [Int] = Array(0...4) + Array((0...3).reversed())
        for (n, ecran) in poses.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6 + Double(n) * 2.2) {
                withAnimation(.easeInOut(duration: 1.1)) {
                    ordre.scrollTo(y: CGFloat(ecran) * hauteur)
                }
            }
        }
    }
}

// MARK: - Le banc

/// LE BANC `-duoLab` — la page seule, plein écran. Flags secondaires :
/// `-duoEcran <1-5>` naissance posée sur l'écran n, `-duoFreeze` vidéos en
/// pause sur leur pose (mesures numpy stables), `-duoAuto` l'aller-retour
/// filmé du fouettage.
struct DuoLab: View {
    var body: some View {
        let args = CommandLine.arguments
        let ecran: Int = {
            guard let i = args.firstIndex(of: "-duoEcran"), i + 1 < args.count,
                  let n = Int(args[i + 1]) else { return 0 }
            return max(0, min(4, n - 1))
        }()
        let etape: Int = {
            guard let i = args.firstIndex(of: "-duoEtape"), i + 1 < args.count,
                  let n = Int(args[i + 1]) else { return 0 }
            return max(0, min(EcranSpec.etapes.count - 1, n))
        }()
        if args.contains("-duoGalets") {
            // La mire du galet-étape (J2) : la grammaire seule, deux fonds.
            GaletEtapeLab()
        } else {
            DuolinguoPage(ecranInitial: ecran,
                          etapeInitiale: etape,
                          gel: args.contains("-duoFreeze"),
                          auto: args.contains("-duoAuto"))
                .environment(\.colorScheme, .dark)
        }
    }
}
