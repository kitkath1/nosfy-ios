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
        /// T1 (LE TRAVELLING) : une flamme est une LUMIÈRE — elle se rend
        /// en additif dans la couche des feux, jamais dans sa section.
        var flamme = false
        /// §15 (LE CHEMIN D'ABORD) : la fenêtre dépasse le bord physique de
        /// l'écran de ce montant — la queue du fondu (base miroir cuite)
        /// vit hors champ à la pose, déjà morte quand elle entre au
        /// viewport (l'overshoot de la LOI F1).
        var overshoot: CGFloat = 0
        /// §15, D3 — LE VOYAGE EST NOIR : une braise de pose s'éteint dès
        /// le geste, morte à `extinctionVoyage × H` de déplacement.
        var extinctionVoyage: CGFloat = 0
        var pose: String { nom + "-poster" }
    }

    /// §15 (LE CHEMIN D'ABORD) : les feux uniques 540 pt sont MORTS — le
    /// décor est un PARFUM. Chaque couture de feu ne garde qu'une BRAISE
    /// de pose (160 pt visibles, vignette cuite, base miroir en
    /// overshoot), vive à la pose, éteinte dès le geste. Le voyage est
    /// noir : les galets et les capsules portent la page.
    static let les5: [EcranSpec] = [
        // ÉCRAN 1 — LE VERRE NOIR (col au bord, ventre aux 4/5 de la fenêtre)
        EcranSpec(id: 0,
                  haut: .init(nom: "duo-galet-noir", ratioHL: 1560.0/1206.0,
                              parallaxe: 0.10),
                  bas: .init(nom: "duo-flamme-blanche", ratioHL: 480.0/804.0,
                             flamme: true, overshoot: 80,
                             extinctionVoyage: 0.25)),
        EcranSpec(id: 1, haut: nil, bas: nil),   // LA BRAISE BLANCHE
        // ÉCRAN 3 — LE ROUGE (le haut = la frontière 2/3, le bas = la braise)
        EcranSpec(id: 2, haut: nil,
                  bas: .init(nom: "duo-flamme-rouge", ratioHL: 480.0/804.0,
                             flamme: true, overshoot: 80,
                             extinctionVoyage: 0.25)),
        EcranSpec(id: 3, haut: nil, bas: nil),   // LA BRAISE ROUGE
        // ÉCRAN 5 — LE BLEU (le haut = la frontière 4/5, le bas = la
        // flamme bleue, rendue dans la couche des feux)
        EcranSpec(id: 4,
                  haut: nil,
                  bas: .init(nom: "duo-flamme-bleue", ratioHL: 440.0/804.0,
                             flamme: true, extinctionVoyage: 0.30)),
    ]

    /// §15 : plus AUCUN feu chevauchant — la struct reste pour l'histoire,
    /// la liste est VIDE (le §13 l'avait remplie, le reframe l'a vidée).
    struct FeuUnique: Identifiable {
        let id: Int
        let nom: String
        let couture: Int
        let ratioHL: CGFloat = 1080.0 / 804.0
        var pose: String { nom + "-poster" }
        var ecrans: [Int] { [couture - 1, couture] }
    }
    static let feuxUniques: [FeuUnique] = []

    /// §15, D3 — LA LUEUR DE COUTURE : aux coutures de feu (1/2 et 3/4),
    /// une respiration de lumière très basse pendant le geste — motivée,
    /// teintée par le chapitre, morte aux poses. C'est TOUT le décor du
    /// voyage.
    struct LueurCouture: Identifiable {
        let id: Int
        let couture: Int      // la couture k : centre à y = k × H
        let teinte: (r: Double, g: Double, b: Double)
    }
    static let lueurs: [LueurCouture] = [
        LueurCouture(id: 0, couture: 1, teinte: (1.00, 0.96, 0.88)),
        LueurCouture(id: 1, couture: 3, teinte: (1.00, 0.42, 0.16)),
    ]

    /// Les flammes simples restantes (l'écran 5) pour la couche des feux.
    static let feux: [(ecran: Int, spec: FenetreSpec, enHaut: Bool)] = {
        var f: [(Int, FenetreSpec, Bool)] = []
        for e in les5 {
            if let h = e.haut, h.flamme { f.append((e.id, h, true)) }
            if let b = e.bas, b.flamme { f.append((e.id, b, false)) }
        }
        return f
    }()

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
        EtapeSpec(id: 3, ecran: 1, dx: -45, y: 580),
        EtapeSpec(id: 4, ecran: 2, dx: 55, y: 350),
        EtapeSpec(id: 5, ecran: 2, dx: -50, y: 480),
        EtapeSpec(id: 6, ecran: 3, dx: 45, y: 360),
        EtapeSpec(id: 7, ecran: 3, dx: -55, y: 450),
        EtapeSpec(id: 8, ecran: 4, dx: 50, y: 400),
        EtapeSpec(id: 9, ecran: 4, dx: -45, y: 495),
        EtapeSpec(id: 10, ecran: 4, dx: 0, y: 590, tresor: true),
    ]

    /// LES FRONTIÈRES (2e salve : « ça doit être le même élément ») — une
    /// fenêtre pleine capsule à cheval sur chaque couture de verre, et
    /// c'est le scroll qui fait le voyage (LOI 1). La rouge monte du
    /// bas-GAUCHE de l'écran 2 vers le haut de l'écran 3 ; la rouge-et-bleu
    /// du bas-droite de l'écran 4 vers le haut de l'écran 5. Une seule
    /// mécanique, deux instances.
    struct FrontiereSpec: Identifiable {
        let id: Int
        let nom: String
        let ratioHL: CGFloat
        /// Largeur en fraction d'écran (360/402 de la maquette).
        let largeurFrac: CGFloat
        /// La couture chevauchée : centre de la fenêtre à `couture × H`.
        let couture: Int
        let bord: Alignment
        var pose: String { nom + "-poster" }
        var ecrans: [Int] { [couture - 1, couture] }
    }

    static let frontieres: [FrontiereSpec] = [
        FrontiereSpec(id: 0, nom: "duo-galet-rouge",
                      ratioHL: 2100.0/1080.0, largeurFrac: 360.0/402.0,
                      couture: 2, bord: .leading),
        FrontiereSpec(id: 1, nom: "duo-galet-rougebleu",
                      ratioHL: 2100.0/1080.0, largeurFrac: 360.0/402.0,
                      couture: 4, bord: .trailing),
    ]
}

// MARK: - L'état

/// L'ÉTAT VIVANT DE LA PAGE — hors corps de vue (« @Observable, ET SURTOUT
/// PAS UN @State SUR LA PAGE », la loi de la porte). Le corps de
/// DuolinguoPage n'en relit rien ; seuls les écrans lisent LEUR booléen de
/// lecture, la frontière le sien.
@Observable final class EtatDuo {
    /// Quels lecteurs vivent : un par écran (l'écran courant + l'entrant).
    var lecture: [Bool] = [true, true, false, false, false]
    /// Les lecteurs des fenêtres frontières (2/3 rouge, 4/5 rouge-bleu).
    var lectureFrontieres: [Bool] = [false, false]
    /// §15 : plus de feux chevauchants — la liste est vide, les braises de
    /// pose vivent sur le booléen de LEUR écran.
    var lectureFeux: [Bool] = []
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
        for f in EcranSpec.frontieres {
            let veut = !gel && f.ecrans.contains(where: { $0 == a || $0 == b })
            if lectureFrontieres[f.id] != veut { lectureFrontieres[f.id] = veut }
        }
        for f in EcranSpec.feuxUniques {
            let veut = !gel && f.ecrans.contains(where: { $0 == a || $0 == b })
            if lectureFeux[f.id] != veut { lectureFeux[f.id] = veut }
        }
        let pose = Int((y / hauteur).rounded())
        let borne = max(0, min(4, pose))
        if ecranCourant != borne { ecranCourant = borne }
        // LA BASCULE d'une frontière (partition J4, généralisée 2e salve) :
        // quand SA couture traverse le centre du viewport, UNE haptique
        // légère — hystérésis 60 pt, une par traversée.
        if !gel {
            for f in EcranSpec.frontieres {
                let seuil = (CGFloat(f.couture) - 0.5) * hauteur
                let avant = yPrecedent < seuil
                let apres = y < seuil
                if avant != apres, abs(y - dernieresBascules[f.id]) > 60 {
                    dernieresBascules[f.id] = y
                    UIImpactFeedbackGenerator(style: .light)
                        .impactOccurred(intensity: 0.7)
                }
            }
        }
        yPrecedent = y
    }

    @ObservationIgnored private var yPrecedent: CGFloat = 0
    @ObservationIgnored private var dernieresBascules: [CGFloat] = [-10_000, -10_000]
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
    /// La hauteur d'écran (l'échelle des rideaux).
    let hauteur: CGFloat
    /// Les POSES de la fenêtre, en déplacement d = minY − restY : {0} pour
    /// une fenêtre d'écran, {0, −H} pour une frontière (deux chez-elle).
    var poses: [CGFloat] = [0]
    /// 4e salve, LOI F1 : LES RIDEAUX SONT MORTS. Le contenu de chaque
    /// fichier meurt au NOIR VRAI avant chaque bord de sa fenêtre — cuit
    /// (recuit_duo.sh) : aucune ligne n'est possible, par mathématique.
    /// Un rideau runtime était lui-même un calque (le verdict de Kathryn).
    /// T1 (LE TRAVELLING) : le feu est une LUMIÈRE — plusLighter, les
    /// bornes de la fenêtre cessent d'exister (un noir additionné = rien).
    var additif = false
    /// T2/LOI T3 : le SUJET (une capsule) reste net entre ses deux poses ;
    /// il ne défocalise qu'au-delà — il quitte son histoire.
    var sujet = false
    /// Le rayon max du rack focus (0 = mort ; réglé par `-duoFocus`).
    var flou: CGFloat = 0
    let joue: Bool

    var body: some View {
        Color.clear
            .frame(width: largeur, height: largeur * spec.ratioHL)
            .overlay {
                CalqueVideoPilote(nom: spec.nom, pose: spec.pose,
                                  rate: joue ? 1.0 : 0.0)
            }
            .clipped()
            .blendMode(additif ? .plusLighter : .normal)
            // LE TRAVELLING — tout se lit dans le proxy, zéro invalidation :
            // la parallaxe et le rack focus (T2). Net à la pose,
            // défocalisé en voyage.
            .visualEffect { [parallaxe = spec.parallaxe, restY, poses,
                            hauteur, sujet, flou] contenu, proxy in
                let d = proxy.frame(in: .scrollView).minY - restY
                let dist = poses.map { abs(d - $0) }.min() ?? 0
                let dy = -d * parallaxe
                // LE VOILE VIT DANS LA FENÊTRE (4e salve, payé à la sonde) :
                // un voile par ZONES d'écran posait une MARCHE à la couture,
                // en plein milieu du feu désormais continu (frames 401-403,
                // score 23). L'assombrissement s'applique à l'OBJET, en
                // uniforme — aucune marche spatiale n'est possible. Le feu
                // (additif) ne s'assombrit pas : il est le sujet de sa
                // couture.
                let r: CGFloat
                let nuit: CGFloat
                if sujet {
                    // Net entre ses poses ; au-delà, il fond dans la
                    // profondeur (rampe 0,35 H) et s'éteint à moitié.
                    let haut = poses.max() ?? 0
                    let bas = poses.min() ?? 0
                    let dehors = max(0, max(d - haut, bas - d))
                    let u = min(1, dehors / (0.35 * hauteur))
                    let s = u * u * (3 - 2 * u)
                    r = flou * s
                    nuit = 0.5 * s
                } else {
                    let u = min(1, dist / (0.5 * hauteur))
                    let s = u * u * (3 - 2 * u)
                    r = flou * s
                    var n: CGFloat = additif ? 0 : 0.35 * s
                    // §15 D3 recalé (verdict : « on ne voit plus les
                    // flammes au scroll ») : la flamme ne MEURT plus en
                    // voyage — elle S'INCLINE à ~55 % et se fond d'une
                    // page à l'autre. Ses bords n'existent pas dans la
                    // matière (vignette + fondus cuits) : elle peut
                    // voyager sans jamais couper.
                    if spec.extinctionVoyage > 0 {
                        let ue = min(1, dist / (spec.extinctionVoyage * hauteur))
                        n = max(n, 0.45 * (ue * ue * (3 - 2 * ue)))
                    }
                    nuit = n
                }
                return contenu.offset(y: dy).blur(radius: r)
                    .opacity(Double(1 - nuit))
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
                // T1 : les FLAMMES ne vivent plus ici — elles sont des
                // lumières, rendues dans la couche additive des feux
                // (FeuxDuo), hors des sections qui les clippaient (le
                // croisement de T3 exige de traverser la couture).
                if let haut = spec.haut, !haut.flamme {
                    FenetreVideo(spec: haut, largeur: g.size.width,
                                 restY: 0, hauteur: g.size.height,
                                 flou: DuoReglages.focusEffectif,
                                 joue: joue)
                        .offset(x: haut.decalageX)
                        .frame(maxWidth: .infinity, maxHeight: .infinity,
                               alignment: .top)
                }
                if let bas = spec.bas, !bas.flamme {
                    FenetreVideo(spec: bas, largeur: g.size.width,
                                 restY: g.size.height - g.size.width * bas.ratioHL,
                                 hauteur: g.size.height,
                                 flou: DuoReglages.focusEffectif,
                                 joue: joue)
                        .offset(x: bas.decalageX)
                        .frame(maxWidth: .infinity, maxHeight: .infinity,
                               alignment: .bottom)
                }
            }
        }
        .clipped()
    }
}

// MARK: - Les feux (T1/T3)

/// LA COUCHE DES FEUX — les cinq flammes en `.plusLighter` au-dessus de la
/// colonne : un pixel noir additionné ne rend rien, les bornes des
/// fenêtres cessent d'exister par construction. Et aux coutures de feu,
/// le contre-mouvement (T3) tend les deux flammes l'une vers l'autre —
/// elles se traversent, et l'additif fait de leur rencontre UN brasier.
private struct FeuxDuo: View {
    let etat: EtatDuo
    let hauteur: CGFloat
    let largeur: CGFloat

    var body: some View {
        ZStack(alignment: .top) {
            // §15 — LES BRAISES DE POSE : chaque flamme vit sur SON écran,
            // ancrée au bord bas, l'overshoot (base miroir cuite) sous le
            // bord physique ; elle s'éteint dès le geste (extinctionVoyage
            // dans FenetreVideo). Le voyage est noir.
            ForEach(Array(EcranSpec.feux.enumerated()), id: \.offset) { _, feu in
                let h = largeur * feu.spec.ratioHL
                let yLocal = feu.enHaut ? 0 : hauteur - h + feu.spec.overshoot
                FenetreVideo(spec: feu.spec, largeur: largeur,
                             restY: yLocal, hauteur: hauteur,
                             additif: true,
                             flou: DuoReglages.focusEffectif,
                             joue: etat.lecture[feu.ecran])
                    .offset(y: CGFloat(feu.ecran) * hauteur + yLocal)
            }
            // §15 D3 — LA LUEUR DE COUTURE : « une seule chose qui se fond
            // dans la page 1 et la page 2 au scroll » — UNE respiration de
            // lumière par couture de feu, très basse, teintée chapitre,
            // NULLE aux deux poses (sin²), à son pic à mi-traversée. Tout
            // le décor du voyage tient là.
            ForEach(EcranSpec.lueurs) { l in
                let hL: CGFloat = 260
                let rest = hauteur - hL / 2
                EllipticalGradient(
                    colors: [Color(red: l.teinte.r, green: l.teinte.g,
                                   blue: l.teinte.b).opacity(0.55), .clear],
                    center: .center)
                    .frame(width: largeur, height: hL)
                    .blendMode(.plusLighter)
                    .visualEffect { [rest, hauteur] c, p in
                        let d = rest - p.frame(in: .scrollView).minY
                        let u = max(0, min(1, d / hauteur))
                        let s = sin(.pi * u)
                        return c.opacity(Double(s * s) * DuoReglages.braiseMax)
                    }
                    .offset(y: CGFloat(l.couture) * hauteur - hL / 2)
            }
        }
        .frame(width: largeur, height: hauteur * 5, alignment: .top)
        .allowsHitTesting(false)
    }
}

/// Les réglages du travelling, lus une fois (`-duoFocus <pt>`, défaut 10,
/// 0 = mort — le verdict d'intensité de Kathryn se joue sur ce flag :
/// subtil 6 / assumé 10 / cinéma 14).
enum DuoReglages {
    /// §15 : le rack focus est MORT PAR DÉFAUT (son procès a eu lieu — il
    /// liquéfiait les feux). `-duoFocus <pt>` le ressuscite au banc.
    static let focusMax: CGFloat = {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: "-duoFocus"), i + 1 < a.count,
              let v = Double(a[i + 1]) else { return 0 }
        return CGFloat(max(0, v))
    }()
    /// §15 D3 : l'intensité de la lueur de couture (`-duoBraise <0-1>`).
    static let braiseMax: Double = {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: "-duoBraise"), i + 1 < a.count,
              let v = Double(a[i + 1]) else { return 0.28 }
        return max(0, min(1, v))
    }()
    /// reduceMotion coupe le rack focus (piège 19) — figé au lancement.
    static let focusEffectif: CGFloat =
        UIAccessibility.isReduceMotionEnabled ? 0 : focusMax
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
                // §15 D1 — LE CHEMIN EST LE SUJET : les galets montent
                // d'un cran (82 / actif 92 / trésor 104).
                GaletEtape(etat: quel,
                           numero: e.tresor ? nil : e.id + 1,
                           glyphe: e.tresor ? "moon.fill" : nil,
                           taille: e.tresor ? 104 : (quel == .actif ? 92 : 82),
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

// MARK: - La capsule vivante (T4)

/// LE BERCEMENT — une dérive de ±3 pt et une respiration d'échelle de
/// 0,6 %, portées par Core Animation (`repeatForever`) : AUCUN travail
/// par image côté SwiftUI. Périodes PREMIÈRES entre les deux capsules
/// (11 s / 13 s) — jamais en phase, la leçon des respirations de la home.
private struct CapsuleVivante<Contenu: View>: View {
    let periode: Double
    let vivante: Bool
    @ViewBuilder var contenu: () -> Contenu
    @State private var berce = false

    var body: some View {
        contenu()
            .offset(y: berce ? 3 : -3)
            .scaleEffect(berce ? 1.006 : 1.0)
            .onAppear {
                guard vivante else { return }
                withAnimation(.easeInOut(duration: periode)
                    .repeatForever(autoreverses: true)) { berce = true }
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
    static let noms = ["Le verre noir", "La braise blanche", "Le rouge",
                       "La braise rouge", "Le bleu"]

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
        // §15 — LA MORSURE FANTÔME (payée au film) : la pellicule noire de
        // la dalle est INVISIBLE sur le fond noir… sauf quand un galet
        // scrolle dessous pendant son fondu de sortie — un rectangle noir
        // qui « mord » tout ce qui passe. La sortie doit être RAPIDE et
        // physique (elle monte), le retour peut être doux.
        .offset(y: visible ? 0 : -22)
        .animation(visible ? .easeInOut(duration: 0.28)
                           : .easeOut(duration: 0.11), value: visible)
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
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    ForEach(EcranSpec.les5) { spec in
                        EcranDuo(spec: spec, etat: etat)
                            .containerRelativeFrame(.vertical)
                    }
                }
                .scrollTargetLayout()
                // T1 — LA COUCHE DES FEUX : les flammes additives, hors
                // des sections (le croisement de T3 traverse les coutures).
                .overlay(alignment: .top) {
                    FeuxDuo(etat: etat, hauteur: hauteur,
                            largeur: g.size.width)
                }
                // LES FRONTIÈRES — DANS le scroll (hors du scroll, la
                // sonde a une frame de retard : le galet glisserait contre
                // ses écrans — la marche à la couture). Offset CONSTANT en
                // coordonnées de contenu : le centre de chaque fenêtre sur
                // SA couture. Au-dessus des feux, sous les voiles.
                .overlay(alignment: .top) {
                    ForEach(EcranSpec.frontieres) { f in
                        let lf = g.size.width * f.largeurFrac
                        let hF = lf * f.ratioHL
                        let restF = hauteur - hF / 2
                        // La teinte de la lueur suit la température du
                        // monde traversé : chaud pour la capsule rouge,
                        // froid pour la rouge-et-bleu (la loi du chemin).
                        let teinte = f.id == 0
                            ? Color(red: 1.0, green: 0.92, blue: 0.78)
                            : Color(red: 0.80, green: 0.88, blue: 1.0)
                        CapsuleVivante(periode: f.id == 0 ? 5.5 : 6.5,
                                       vivante: !gel && !reduceMotion) {
                            FenetreVideo(spec: .init(nom: f.nom, ratioHL: f.ratioHL),
                                         largeur: lf,
                                         restY: restF,
                                         hauteur: hauteur,
                                         poses: [0, -hauteur],
                                         sujet: true,
                                         flou: DuoReglages.focusEffectif,
                                         joue: etat.lectureFrontieres[f.id])
                                // F3 — LA LUEUR DE PASSAGE, teintée : la
                                // capsule s'allume en passant devant la
                                // caméra (sin(π·u) × 0,22), s'éteint posée.
                                .overlay {
                                    RadialGradient(
                                        colors: [teinte.opacity(0.5), .clear],
                                        center: .center,
                                        startRadius: 0, endRadius: lf * 0.55)
                                        .blendMode(.plusLighter)
                                        .visualEffect { [restF, hauteur] c, p in
                                            let d = restF - p.frame(in: .scrollView).minY
                                            let u = max(0, min(1, d / hauteur))
                                            return c.opacity(Double(sin(.pi * u)) * 0.12)
                                        }
                                        .allowsHitTesting(false)
                                }
                                // §14 N0 — LE RIDEAU DES CAPSULES : le fondu
                                // profond en voyage (la régression réparée,
                                // ~300 pt perçus). Opacité 0 à la pose → 1
                                // dès 0,10 H de voyage (piège 11 : la rampe
                                // se règle sur l'ARÊTE). AMENDEMENT assumé
                                // de la LOI F1, restreinte aux feux.
                                .overlay {
                                    VStack(spacing: 0) {
                                        LinearGradient(
                                            colors: [.black, .black.opacity(0)],
                                            startPoint: .top, endPoint: .bottom)
                                            .frame(height: 300)
                                        Spacer(minLength: 0)
                                        LinearGradient(
                                            colors: [.black.opacity(0), .black],
                                            startPoint: .top, endPoint: .bottom)
                                            .frame(height: 300)
                                    }
                                    .visualEffect { [restF, hauteur] c, p in
                                        let d = p.frame(in: .scrollView).minY - restF
                                        let dist = min(abs(d), abs(d + hauteur))
                                        let u = min(1, dist / (0.10 * hauteur))
                                        return c.opacity(Double(u * u * (3 - 2 * u)))
                                    }
                                    .allowsHitTesting(false)
                                }
                                .compositingGroup()
                        }
                            // §15 D4 — LA COURBE EN S (0,10 H) + la retenue :
                            // échelle 1,02, tilt 2° en sin(π·u) — nul aux
                            // DEUX poses. Le premium par la retenue.
                            .visualEffect { [restF, hauteur] contenu, proxy in
                                let d = restF - proxy.frame(in: .scrollView).minY
                                let u = max(0, min(1, d / hauteur))
                                let s = sin(.pi * u)
                                return contenu
                                    .offset(y: 0.10 * hauteur * s)
                                    .scaleEffect(1 + 0.02 * s)
                                    .rotation3DEffect(.degrees(2.0 * s),
                                                      axis: (x: 1, y: 0, z: 0),
                                                      perspective: 0.5)
                            }
                            .frame(maxWidth: .infinity, alignment: f.bord)
                            .offset(y: CGFloat(f.couture) * hauteur - hF / 2)
                            .allowsHitTesting(false)
                    }
                }
                // ⚠️ LE GROUP EN DERNIER (le piège de l'additif, DepartCine) :
                // les blends plusLighter des feux et des lueurs se résolvent
                // contre la colonne DANS ce group — posé avant eux, un
                // additif-sur-transparent serait l'identité.
                .compositingGroup()
                // LE CHEMIN — au-dessus de tout, DANS le scroll.
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
