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

// MARK: - La page

struct DuolinguoPage: View {
    /// L'état vivant — créé ici, JAMAIS relu par ce corps.
    @State private var etat = EtatDuo()
    /// Le jeton de scroll du banc (`-duoEcran`, `-duoAuto`).
    @State private var ordre = ScrollPosition()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Options du banc, lues DANS la vue (jamais dans RootView).
    var ecranInitial: Int = 0
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
            .onAppear {
                etat.gel = gel || reduceMotion
                etat.piloter(y: CGFloat(ecranInitial) * hauteur, hauteur: hauteur)
                if ecranInitial > 0 {
                    ordre.scrollTo(y: CGFloat(ecranInitial) * hauteur)
                }
                if auto { lancerAuto(hauteur: hauteur) }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .sondeCadence("duo")
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
        DuolinguoPage(ecranInitial: ecran,
                      gel: args.contains("-duoFreeze"),
                      auto: args.contains("-duoAuto"))
            .environment(\.colorScheme, .dark)
    }
}
