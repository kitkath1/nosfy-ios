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
        /// §16 G2 « tous les écrans » : la capsule vidéo d'un écran (le
        /// verre noir) reçoit aussi l'émergence — floue et sombre dès
        /// qu'elle quitte sa pose, résolue posée.
        var emerge = false
        var pose: String { nom + "-poster" }
    }

    /// §15 (LE CHEMIN D'ABORD) : les feux uniques 540 pt sont MORTS — le
    /// décor est un PARFUM. Chaque couture de feu ne garde qu'une BRAISE
    /// de pose (160 pt visibles, vignette cuite, base miroir en
    /// overshoot), vive à la pose, éteinte dès le geste. Le voyage est
    /// noir : les galets et les capsules portent la page.
    static let les5: [EcranSpec] = [
        // ÉCRAN 1 — LE VERRE NOIR (col au bord, ventre aux 4/5 de la fenêtre)
        // §19 : les 4 braises séparées sont MORTES — deux vidéos par
        // couture, c'est topologiquement condamné (l'entre-deux). Chaque
        // couture de feu = UN feu-larme chevauchant (`feuxUniques`).
        EcranSpec(id: 0,
                  haut: .init(nom: "duo-galet-noir", ratioHL: 1560.0/1206.0,
                              parallaxe: 0.10, emerge: true),
                  bas: nil),
        EcranSpec(id: 1, haut: nil, bas: nil),   // LA BRAISE BLANCHE
        EcranSpec(id: 2, haut: nil, bas: nil),   // LE ROUGE
        EcranSpec(id: 3, haut: nil, bas: nil),   // LA BRAISE ROUGE
        // ÉCRAN 5 — LE BLEU (le haut = la frontière 4/5, le bas = la
        // flamme bleue, rendue dans la couche des feux)
        EcranSpec(id: 4,
                  haut: nil,
                  bas: .init(nom: "duo-flamme-bleue", ratioHL: 440.0/804.0,
                             flamme: true, extinctionVoyage: 0.30)),
    ]

    /// §19 — LE FEU UNIQUE-LARME : la topologie du §13 (un fichier
    /// chevauchant par couture — l'école des capsules validées) × la
    /// matière du §17 (crush + vignette 2D + fondu partout). Le cœur du
    /// feu vit SUR la couture (rangée 320 du fichier 804×640) : à la pose
    /// basse les plumes montent DU bord (le footer), à la pose haute la
    /// lueur-reflet saigne DU bord derrière la dalle (le header), au
    /// scroll UN corps traverse — l'espace entre les flammes n'existe
    /// plus, par construction.
    struct FeuUnique: Identifiable {
        let id: Int
        let nom: String
        let couture: Int
        let ratioHL: CGFloat = 640.0 / 804.0
        var pose: String { nom + "-poster" }
        var ecrans: [Int] { [couture - 1, couture] }
    }
    static let feuxUniques: [FeuUnique] = [
        FeuUnique(id: 0, nom: "duo-feu-blanc", couture: 1),
        FeuUnique(id: 1, nom: "duo-feu-rouge", couture: 3),
    ]

    /// §19 : la lueur de couture est MORTE — le corps du feu EST la
    /// continuité.
    struct LueurCouture: Identifiable {
        let id: Int
        let couture: Int
        let teinte: (r: Double, g: Double, b: Double)
    }
    static let lueurs: [LueurCouture] = []

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
        /// La NATURE d'un nœud (27-08, audit tools/road/AUDIT-ROAD.md §4,
        /// §4 bis) : une séance, ou l'un des trois nœuds spéciaux du
        /// chapitre — la PIÈCE (l'or en disque, ouvre la card reward), la
        /// LUNE du milieu et le TRÉSOR de fin (l'or en anneau, ouvrent le
        /// booster).
        enum Nature: Equatable { case seance, piece, lune, tresor }
        let id: Int
        let ecran: Int
        /// Le RANG dans l'écran (0…8). ⚠️ Les ids sont des INDEX : quatre
        /// sites indexent `etapes[etat.etape]` — ils restent CONTIGUS
        /// (`ecran × 9 + n`), et c'est `n` qu'on lit pour le rang, jamais
        /// `id % 10` (l'ancienne base 10 est morte avec les 10 par écran).
        let n: Int
        let dx: CGFloat        // écart à l'axe (serpentin alterné ±60)
        let y: CGFloat         // dans l'écran, base 874
        let nature: Nature
        var tresor: Bool { nature == .tresor }
        var lune: Bool { nature == .lune }
        /// Les deux nœuds à croissant — la lune du milieu et le trésor.
        var moon: Bool { nature == .lune || nature == .tresor }
        var piece: Bool { nature == .piece }
        /// Tout ce qui n'est pas une séance : ni date, ni jour du calendrier.
        var special: Bool { nature != .seance }
    }

    /// LE CHAPITRE (27-08, point A tranché par Kathryn) : **9 nœuds par
    /// écran** — `S1 S2 ¢ S3 S4 ☾ S5 S6 ☾` : six séances, la pièce au rang 2
    /// (la petite récompense rapide, après deux séances), la lune avant la
    /// 5e séance, le trésor qui ferme le chapitre.
    ///
    /// Pourquoi neuf, et pourquoi ALTERNÉ (mesuré, `tools/road/layout_x15.py`) :
    /// à ×1,5 (Ø 93, lunes 117), dix nœuds par écran ne tiennent pas (15 à
    /// 23 pt d'air), et une sinusoïde lente donne de −22 à −38 pt — les
    /// galets se chevauchent. Le serpentin ALTERNÉ (dx = ±60, amplitude
    /// ≥ 58,5 obligatoire) au pas 67,5 (y 740 → 200) donne **30,0 pt d'air
    /// minimum entre TOUTES les paires** — et c'est le PAS qui fixe ce
    /// minimum (2 × 67,5 − 105), pas l'amplitude. L'organique vient du
    /// jitter en y (±4) et d'un souffle de ±1,5 sur dx, jamais de
    /// l'amplitude (la moduler à 0,8 fait tomber l'air à 15 pt).
    static let parEcran = 9
    static let composition: [EtapeSpec.Nature] = [
        .seance, .seance, .piece, .seance, .seance, .lune, .seance, .seance,
        .tresor,
    ]
    static let etapes: [EtapeSpec] = {
        var out: [EtapeSpec] = []
        for ecran in 0..<5 {
            for n in 0..<parEcran {
                let id = ecran * parEcran + n
                let pas: CGFloat = (740 - 200) / CGFloat(parEcran - 1)
                let jitterY = CGFloat(sin(Double(id) * 12.9898)) * 4
                let y: CGFloat = 740 - CGFloat(n) * pas + jitterY
                let cote: CGFloat = n % 2 == 0 ? 1 : -1
                let souffle = CGFloat(sin(Double(id) * 7.31 + 0.4)) * 1.5
                let dx = cote * (60 + souffle)
                out.append(EtapeSpec(id: id, ecran: ecran, n: n,
                                     dx: dx, y: y,
                                     nature: composition[n]))
            }
        }
        return out
    }()

    /// LES SÉANCES SEULES, dans l'ordre du chemin — le calendrier ne compte
    /// que celles-là : un nœud spécial n'est pas un jour (le « jour
    /// fantôme » de l'audit, quand `etape` tombait sur une lune et
    /// qu'aucun galet n'était actif ce jour-là).
    static let seances: [EtapeSpec] = etapes.filter { !$0.special }
    /// Le rang-jour d'une séance (nil pour un nœud spécial).
    static func jour(deId id: Int) -> Int? {
        seances.firstIndex { $0.id == id }
    }
    /// L'id de la k-ième séance, bornée au chemin.
    static func id(pourJour k: Int) -> Int {
        seances[min(max(k, 0), seances.count - 1)].id
    }

    /// D2 — LE CHEMIN LIT LES SÉANCES (27-08, jalon 0 de l'audit). Le
    /// jour 0 du chemin est le jour de la PREMIÈRE séance terminée ;
    /// aujourd'hui est `etape` ; chaque jour où une séance s'est terminée
    /// est FAIT. Tant qu'aucune séance n'existe, le chemin commence
    /// aujourd'hui. Le chemin est borné à sa dernière séance (30 jours pour
    /// cinq écrans) — le jour où le backend dérivera les chapitres, cette
    /// fonction changera de source, rien d'autre.
    static func etapeEtFaits(seancesFinies: [Date],
                             aujourdhui: Date = Date()) -> (etape: Int, faits: Set<Int>) {
        let cal = Calendar.current
        let jours = seancesFinies.map { cal.startOfDay(for: $0) }
        let today = cal.startOfDay(for: aujourdhui)
        guard let j0 = jours.min(), j0 <= today else {
            return (id(pourJour: 0), [])
        }
        func rang(_ d: Date) -> Int {
            cal.dateComponents([.day], from: j0, to: d).day ?? 0
        }
        let etape = id(pourJour: rang(today))
        let faits = Set(jours.map { id(pourJour: rang($0)) }
                            .filter { $0 < etape })
        return (etape, faits)
    }

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

    /// §16 recalé (« les pills sont trop proéminentes ») : 360 → 300 pt
    /// de large (~583 pt de haut au lieu de 700) — les galets restent les
    /// acteurs, la capsule reste l'événement.
    static let frontieres: [FrontiereSpec] = [
        FrontiereSpec(id: 0, nom: "duo-galet-rouge",
                      ratioHL: 2100.0/1080.0, largeurFrac: 300.0/402.0,
                      couture: 2, bord: .leading),
        FrontiereSpec(id: 1, nom: "duo-galet-rougebleu",
                      ratioHL: 2100.0/1080.0, largeurFrac: 300.0/402.0,
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
    /// §19 : les lecteurs des feux-larmes chevauchants (coutures 1/2, 3/4).
    var lectureFeux: [Bool] = [true, false]
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
    /// ⚠️ **LES JOURS RÉELLEMENT FAITS** (26-08). Sans eux, un jour raté et un
    /// jour réussi rendaient la même pastille : `etatDe()` ne savait dire que
    /// « avant / égal / après ». Verdict : « il doit immédiatement être compris
    /// que cette séance n'a pas été faite ».
    ///
    /// ⚠️ **C'EST DU DÉMO EN ATTENDANT LE BACKEND, ET C'EST ASSUMÉ.** Le
    /// chemin n'a aucun lien avec les `Workout` : le câbler est du backend, que
    /// le chantier a explicitement repoussé (décision D2 du plan). En attendant,
    /// un motif déterministe — pas aléatoire : une page qui change d'avis à
    /// chaque relance ne se juge pas. Le jour où la base parlera, cette seule
    /// ligne devient une lecture de `Workout.endedAt`, et rien d'autre ne bouge.
    var faits: Set<Int> = Set(EcranSpec.seances.enumerated()
        .filter { $0.offset % 4 != 2 }.map { $0.element.id })
    /// Les nœuds spéciaux (lune, trésor, pièce) déjà RÉCLAMÉS — mémoire de
    /// session en attendant la source des rewards (`coin_ledger`,
    /// `user_boosters`) ; sans elle, une lune re-tapable à chaque
    /// lancement = boosters infinis (audit §4).
    var reclamees: Set<Int> = []
    /// LE JOUET (27-08, point 7 tranché « en mode jouet ») : l'id du galet
    /// PORTÉ au doigt, ou nil. Écrit deux fois par port (prise / lâcher),
    /// jamais par image : le parent le lit pour le `zIndex` (un galet
    /// soulevé passe DEVANT) et pour couper le scroll pendant le port.
    var porte: Int? = nil
    /// §23 LE BRANCHEMENT — la page a un hôte : le tap de l'actif ouvre
    /// le panneau de départ au lieu d'avancer l'étape (le banc, lui, ne
    /// change pas d'un poil).
    var branchee = false
    /// Le panneau de départ (l'overlay liquid glass au-dessus de l'actif).
    var departOuvert = false

    /// Recalcule les rates depuis l'offset — écritures GARDÉES : la sonde
    /// tombe à chaque image, les booléens ne bougent qu'aux frontières.
    func piloter(y: CGFloat, hauteur: CGFloat) {
        guard hauteur > 0 else { return }
        // §19 (« des fois lag/écran noir au scroll ») : un lecteur qui
        // passe rate 0→1 EN PLEIN geste flushe sa couche — des frames
        // noires. Le remède : réveiller les voisins UNE page à l'avance
        // (a-1…b+1) — plus aucun réveil en plein voyage, et un lecteur
        // à rate 0 ne décode toujours pas.
        let a = max(0, min(4, Int(floor(y / hauteur)) - 1))
        let b = max(0, min(4, Int(ceil(y / hauteur)) + 1))
        for i in 0..<5 {
            let veut = !gel && (i >= a && i <= b)
            if lecture[i] != veut { lecture[i] = veut }
        }
        for f in EcranSpec.frontieres {
            let veut = !gel && f.ecrans.contains(where: { $0 >= a && $0 <= b })
            if lectureFrontieres[f.id] != veut { lectureFrontieres[f.id] = veut }
        }
        for f in EcranSpec.feuxUniques {
            let veut = !gel && f.ecrans.contains(where: { $0 >= a && $0 <= b })
            if lectureFeux[f.id] != veut { lectureFeux[f.id] = veut }
        }
        let pose = Int((y / hauteur).rounded())
        let borne = max(0, min(4, pose))
        if ecranCourant != borne { ecranCourant = borne }
        // LES HAPTIQUES DU SCROLL (sa demande du 25-08) : UNE haptique
        // légère quand une couture — les QUATRE : capsules (2/3, 4/5) ET
        // feux (1/2, 3/4) — traverse le centre du viewport. Hystérésis
        // 60 pt, une par traversée.
        if !gel {
            for (k, couture) in coutures.enumerated() {
                let seuil = (CGFloat(couture) - 0.5) * hauteur
                let avant = yPrecedent < seuil
                let apres = y < seuil
                if avant != apres, abs(y - dernieresBascules[k]) > 60 {
                    dernieresBascules[k] = y
                    UIImpactFeedbackGenerator(style: .light)
                        .impactOccurred(intensity: 0.7)
                }
            }
        }
        yPrecedent = y
    }

    /// L'ATTERRISSAGE : le « thock » quand la page se POSE sur un autre
    /// écran que celui du départ du geste (appelé par la sonde de phase).
    func gesteCommence() { ecranAuDepart = ecranCourant }
    func gesteFini() {
        guard !gel, ecranCourant != ecranAuDepart else { return }
        ecranAuDepart = ecranCourant
        UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.85)
    }

    @ObservationIgnored private let coutures = [1, 2, 3, 4]
    @ObservationIgnored private var ecranAuDepart = 0
    @ObservationIgnored private var yPrecedent: CGFloat = 0
    @ObservationIgnored private var dernieresBascules: [CGFloat] =
        [-10_000, -10_000, -10_000, -10_000]
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
    /// §17 LA BOULE DE FEU : une braise se CONDENSE en voyage (échelle
    /// vers `boule`, ancrée sur sa couture) et se DÉVOILE à la pose —
    /// sin(π·u), nul aux deux poses, réversible au doigt.
    var boule: CGFloat = 0
    var ancreBoule: UnitPoint = .center
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
                var sc: CGFloat = 1
                if sujet {
                    // LOI G (§16) — LE SUJET ÉMERGE : la loi T3 (« le
                    // sujet voyage net ») est MORTE. En traversée la
                    // capsule est FLOUE et SOMBRE, tout se résout à ZÉRO
                    // aux poses (sin(π·u)) — elle arrive de la
                    // profondeur, les galets règnent pendant le voyage.
                    let haut = poses.max() ?? 0
                    let bas = poses.min() ?? 0
                    let u = max(0, min(1, (haut - d) / max(1, haut - bas)))
                    // §17 cover-flow : |sin(2πu)| — floue/sombre à
                    // l'APPROCHE, NETTE face caméra au centre (le moment
                    // de présentation), floue au départ, nette posée.
                    let sTrav = abs(sin(2 * .pi * u))
                    // au-delà de ses poses elle quitte son histoire :
                    // elle fond (rampe 0,35 H) et s'éteint à moitié.
                    let dehors = max(0, max(d - haut, bas - d))
                    let ud = min(1, dehors / (0.35 * hauteur))
                    let sd = ud * ud * (3 - 2 * ud)
                    r = flou * (sTrav + sd)
                    // §16 doublé (« améliore 100 % l'effet ») : le noir
                    // de traversée monte à 0,5 — elle ÉMERGE vraiment.
                    nuit = min(0.85, 0.5 * sTrav + 0.5 * sd)
                } else {
                    let u = min(1, dist / (0.5 * hauteur))
                    let s = u * u * (3 - 2 * u)
                    r = flou * s
                    var n: CGFloat = additif ? 0 : 0.35 * s
                    // §17 — LA CONDENSATION : au voyage la braise se
                    // contracte vers sa couture (l'ancre fait le
                    // morphisme) ; l'inclinaison 55 % du §15 est MORTE,
                    // la boule EST le « montrer moins ». Léger dim 0,2
                    // pour une boule dense, pas éblouissante.
                    if boule > 0 {
                        let ub = min(1, dist / hauteur)
                        let sb = sin(.pi * ub)
                        sc = 1 - (1 - boule) * sb
                        n = max(n, 0.20 * sb)
                    } else if spec.extinctionVoyage > 0 {
                        // reduceMotion : le repli simple (fondu, pas de
                        // morphisme).
                        let ue = min(1, dist / (spec.extinctionVoyage * hauteur))
                        n = max(n, 0.45 * (ue * ue * (3 - 2 * ue)))
                    }
                    nuit = n
                }
                return contenu.offset(y: dy)
                    .scaleEffect(sc, anchor: ancreBoule)
                    .blur(radius: r)
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
                                 sujet: haut.emerge,
                                 flou: haut.emerge
                                     ? DuoReglages.focusPillEffectif
                                     : DuoReglages.focusEffectif,
                                 joue: joue)
                        .offset(x: haut.decalageX)
                        .frame(maxWidth: .infinity, maxHeight: .infinity,
                               alignment: .top)
                }
                if let bas = spec.bas, !bas.flamme {
                    FenetreVideo(spec: bas, largeur: g.size.width,
                                 restY: g.size.height - g.size.width * bas.ratioHL,
                                 hauteur: g.size.height,
                                 sujet: bas.emerge,
                                 flou: bas.emerge
                                     ? DuoReglages.focusPillEffectif
                                     : DuoReglages.focusEffectif,
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
    /// §18 P1 — la zone morte du HUD se MESURE au runtime, jamais ne se
    /// déclare (la dalle vit SOUS la safe area : ~y 67→125 physique) :
    /// les braises suspendues naissent SOUS elle.
    let decalageHaut: CGFloat

    var body: some View {
        ZStack(alignment: .top) {
            // §19 — LES FEUX-LARMES CHEVAUCHANTS : un objet par couture de
            // feu (école FrontiereSpec), cœur SUR la couture, additif. Le
            // voile de geste + dévoilement au repos restent (sa
            // chorégraphie) ; un dim de voyage léger (RARE-2).
            ForEach(EcranSpec.feuxUniques) { f in
                let h = largeur * f.ratioHL
                let restF = hauteur - h / 2
                FenetreVideo(spec: .init(nom: f.nom, ratioHL: f.ratioHL,
                                         extinctionVoyage: 1.1),
                             largeur: largeur,
                             restY: restF,
                             hauteur: hauteur,
                             poses: [0, -hauteur],
                             additif: true,
                             flou: DuoReglages.focusEffectif,
                             joue: etat.lectureFeux[f.id])
                    .blur(radius: etat.enGeste && !etat.gel
                          ? DuoReglages.voileGeste : 0)
                    .animation(etat.enGeste
                               ? .easeIn(duration: 0.25)
                               : .easeOut(duration: 0.7),
                               value: etat.enGeste)
                    .offset(y: CGFloat(f.couture) * hauteur - h / 2)
            }
            // La flamme simple de l'écran 5 (la bleue — rien dessous).
            ForEach(Array(EcranSpec.feux.enumerated()), id: \.offset) { _, feu in
                let h = largeur * feu.spec.ratioHL
                // §18 P1 : l'offset entre dans yLocal — qui nourrit restY
                // ET l'offset ensemble (un offset seul poserait dist ≈ 130
                // à la pose : une mini-condensation permanente).
                let yLocal = feu.enHaut ? decalageHaut : hauteur - h
                // §17 — LA BOULE : en voyage la braise se condense vers
                // SA couture (l'ancre fait le morphisme) ; §17 M2 — LE
                // DÉVOILEMENT : pendant le geste tout est voilé de blur,
                // au repos la braise se dévoile doucement (0,7 s).
                FenetreVideo(spec: feu.spec, largeur: largeur,
                             restY: yLocal, hauteur: hauteur,
                             additif: true,
                             flou: DuoReglages.focusEffectif,
                             joue: etat.lecture[feu.ecran])
                    .blur(radius: etat.enGeste && !etat.gel
                          ? DuoReglages.voileGeste : 0)
                    .animation(etat.enGeste
                               ? .easeIn(duration: 0.25)
                               : .easeOut(duration: 0.7),
                               value: etat.enGeste)
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
    /// §16 G2 — l'arrivée des capsules : la rotation (`-duoArrivee <deg>`,
    /// défaut 7) et le blur du sujet (`-duoFocusPill <pt>`, défaut 10) —
    /// tous deux résolus à zéro aux poses, coupés par reduceMotion.
    static let arriveeDeg: Double = {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: "-duoArrivee"), i + 1 < a.count,
              let v = Double(a[i + 1]) else { return 16 }
        return max(0, min(25, v))
    }()
    static let focusPill: CGFloat = {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: "-duoFocusPill"), i + 1 < a.count,
              let v = Double(a[i + 1]) else { return 16 }
        return CGFloat(max(0, v))
    }()
    static let arriveeEffectif: Double =
        UIAccessibility.isReduceMotionEnabled ? 0 : arriveeDeg
    static let focusPillEffectif: CGFloat =
        UIAccessibility.isReduceMotionEnabled ? 0 : focusPill
    /// §17 — la taille de la boule (`-duoBoule <0-1>`, défaut 0,32) et le
    /// voile de blur du geste (le dévoilement au repos, `-duoVoile <pt>`).
    static let bouleScale: CGFloat = {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: "-duoBoule"), i + 1 < a.count,
              let v = Double(a[i + 1]) else { return 0.32 }
        return CGFloat(max(0.1, min(1, v)))
    }()
    static let voileGeste: CGFloat = {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: "-duoVoile"), i + 1 < a.count,
              let v = Double(a[i + 1]) else { return 9 }
        return CGFloat(max(0, v))
    }()
    static let bouleEffectif: CGFloat =
        UIAccessibility.isReduceMotionEnabled ? 0 : bouleScale
    /// §18 P0.2 — le log de phase du scroll (`-duoLogPhase`).
    static let logPhase = CommandLine.arguments.contains("-duoLogPhase")
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
    /// §23 — le panneau confirmé (la page transmet à son hôte).
    var onDemarrer: () -> Void = {}
    /// Les nœuds spéciaux disponibles, tapés : la page ne connaît ni le
    /// booster ni les pièces — elle transmet l'id à son hôte (la racine).
    var onLune: ((Int) -> Void)? = nil
    var onPiece: ((Int) -> Void)? = nil
    var onEcranSuivant: (Int) -> Void = { _ in }

    var body: some View {
        let k = hauteur / 874.0
        ZStack(alignment: .topLeading) {
            ForEach(EcranSpec.etapes) { e in
                let quel = etatDe(e)
                // ×1,5 (27-08, audit §3) : séance 93, nœuds à croissant 117,
                // pièce 80 — spéciale, mais la lune reste l'événement.
                let d = dateDe(e)
                // LE FUTUR NE PORTE PLUS UN RANG, IL PORTE UNE PROMESSE :
                // « une petite flamme translucide très légère pour signaler
                // à faire, sans donner l'impression que le contenu est déjà
                // accessible » (verdict). Un chiffre d'étape se lit comme un
                // contenu ; une flamme se lit comme une intention. Le
                // contour `flame` (pas `flame.fill`) : le cheveu seul, le
                // fantôme d'une flamme — le levier gratuit mesuré au fouet
                // (`hierarchical` sur flame.fill est un no-op).
                let futur = d == nil && !e.special
                let glyphe: String? = e.moon ? "moon.fill"
                    : (e.piece ? "circle.inset.filled"
                       : (futur ? "flame" : nil))
                let nee = etat.nees.contains(e.id)
                GaletEtape(etat: quel,
                           numero: nil,
                           glyphe: glyphe,
                           taille: e.moon ? 117 : (e.piece ? 80 : 93),
                           graine: Double(e.id),
                           // le budget verre : la lentille native ne vit
                           // que là où la VIDÉO passe dessous — les gouttes
                           // de bord (monuments et coutures de feu) des
                           // écrans voisins. Au cœur du noir, le natif ne
                           // fait qu'un voile gris (mesuré v11). Panneau
                           // ouvert, le verre des autres se coupe (le natif
                           // ignore l'opacité du projecteur).
                           lentille: abs(e.ecran - etat.ecranCourant) <= 1
                               && (e.n <= 1 || e.n >= 7 || e.special)
                               && !(etat.departOuvert && e.id != etat.etape),
                           date: d,
                           // LE JOUET : seuls l'actif, les faits et les
                           // spéciaux disponibles se portent — un verrouillé
                           // refuse par l'immobilité (la loi du refus).
                           portable: portable(quel),
                           onTap: { tape(e) },
                           onPort: { enMain in
                               etat.porte = enMain ? e.id : nil
                               // le panneau est ancré à la position de
                               // spec : porter l'actif le laisserait sur
                               // place — il se referme.
                               if enMain, etat.departOuvert {
                                   withAnimation(.easeOut(duration: 0.18)) {
                                       etat.departOuvert = false
                                   }
                               }
                           })
                    .scaleEffect(nee ? 1 : 0.92)
                    // LE PROJECTEUR : panneau ouvert, la route s'éteint
                    // autour du couple galet + panneau (0,45).
                    .opacity(nee ? (etat.departOuvert && e.id != etat.etape
                                    ? 0.45 : 1) : 0)
                    .animation(.easeInOut(duration: 0.35),
                               value: etat.departOuvert)
                    // opacité 0 n'est pas « absent » : un galet non né ne
                    // prend pas le doigt.
                    .allowsHitTesting(nee)
                    // un galet soulevé passe DEVANT ses voisins (et le
                    // panneau, zIndex 5) — le ZStack est ordonné par id.
                    .zIndex(etat.porte == e.id ? 100 : 0)
                    .position(x: largeur / 2 + e.dx,
                              y: (CGFloat(e.ecran) * 874 + e.y) * k)
            }
            // §23 — L'ILLUMINATION + LE PANNEAU DE DÉPART, ancrés au galet
            // actif (ils défilent avec le chemin, jamais posés sur l'écran).
            if etat.branchee {
                let e = EcranSpec.etapes[min(etat.etape,
                                             EcranSpec.etapes.count - 1)]
                let px = largeur / 2 + e.dx
                let py = (CGFloat(e.ecran) * 874 + e.y) * k
                // LE PANNEAU NAÎT DU GALET (27-08, audit §6) : ancré sur
                // px (clampé aux marges — le clamp n'absorbe que ±45 pt,
                // le halo et la naissance portent le reste), offsets × k,
                // au-dessus ou au-dessous selon le tiers d'écran.
                // Dessous dès que l'actif n'est plus tout en bas : le
                // panneau couvre alors des nœuds PASSÉS (éteints par le
                // projecteur), jamais la suite du chemin ni la dalle.
                let dessous = e.y < 600
                let xp = min(max(px, 148 + 12), largeur - 148 - 12)
                let yp = dessous ? py + 138 * k : py - 130 * k
                // LA LUMIÈRE PARTAGÉE : le halo de l'actif s'étire jusqu'à
                // l'arête du panneau — un dégradé PEINT, sous le verre
                // (jamais faire respirer le verre lui-même).
                Circle()
                    .fill(RadialGradient(
                        colors: [.white.opacity(0.22), .white.opacity(0.06),
                                 .clear],
                        center: .center, startRadius: 0, endRadius: 150))
                    .frame(width: 320, height: 320)
                    .position(x: px, y: py)
                    .blendMode(.plusLighter)
                    .opacity(etat.departOuvert ? 1 : 0)
                    .animation(.easeInOut(duration: 0.35),
                               value: etat.departOuvert)
                    .allowsHitTesting(false)
                if etat.departOuvert {
                    PanneauDepartChemin(
                        onCommencer: { fermerEtDemarrer() },
                        onPlusTard: {
                            withAnimation(.easeOut(duration: 0.22)) {
                                etat.departOuvert = false
                            }
                        })
                        .position(x: xp, y: yp)
                        // LA NAISSANCE : le panneau GRANDIT depuis le galet.
                        // ⚠️ Posée APRÈS `.position`, la transition enveloppe
                        // le frame du PARENT — la colonne entière (largeur ×
                        // 5 h) : l'ancre s'exprime dans CE frame (mesuré au
                        // fouet : l'ancien `.scale(0,88)` centré glissait de
                        // ~200 pt, caché par l'opacité 0).
                        .transition(.opacity.combined(
                            with: .scale(scale: 0.6,
                                         anchor: UnitPoint(
                                            x: px / largeur,
                                            y: py / (hauteur * 5)))))
                        .zIndex(5)
                }
            }
        }
        .frame(width: largeur, height: hauteur * 5, alignment: .topLeading)
    }

    /// §23 — le PRIMARY : l'haptique, le panneau LIBÈRE la scène (0,15 s,
    /// la loi des deux mouvements), puis l'hôte prend la main.
    private func fermerEtDemarrer() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.easeOut(duration: 0.18)) { etat.departOuvert = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { onDemarrer() }
    }

    /// ⚠️ **LES CINQ ÉTATS DU VERDICT, ET ILS N'EXISTAIENT PAS** (26-08).
    /// `etatDe` ne connaissait que avant / égal / après : un jour RÉUSSI et un
    /// jour RATÉ rendaient exactement la même pastille, et le chemin ne portait
    /// aucune date. Désormais :
    ///   · passé + fait      → `.accompli`, la date légèrement éclairée ;
    ///   · passé + non fait  → `.rate`, l'encre presque fantôme ;
    ///   · aujourd'hui       → `.actif`, halo blanc + la vraie date du jour ;
    ///   · futur             → `.prochain` / `.verrouille`, la petite flamme ;
    ///   · fin de chapitre   → `.lune(dispo:)`, plus gros, sombre ou illuminé.
    private func etatDe(_ e: EcranSpec.EtapeSpec) -> EtapeEtat {
        // Les nœuds spéciaux : PASSIFS (audit §4, « on ne m'impose rien ») —
        // disponibles dès que le chemin les a dépassés, réclamables une
        // fois. `etape` n'est jamais un id spécial (le calendrier ne compte
        // que les séances), donc « dépassé » = `etape > id`.
        if e.special {
            if etat.reclamees.contains(e.id) { return .reclame }
            let dispo = etat.etape > e.id
            return e.piece ? .piece(dispo: dispo) : .lune(dispo: dispo)
        }
        if e.id < etat.etape {
            return etat.faits.contains(e.id) ? .accompli : .rate
        }
        if e.id == etat.etape { return .actif }
        // le prochain = la séance suivante (pas le nœud suivant : un
        // spécial peut s'intercaler).
        if let j = EcranSpec.jour(deId: etat.etape),
           EcranSpec.id(pourJour: j + 1) == e.id, e.id != etat.etape {
            return .prochain
        }
        return .verrouille
    }

    /// LE JOUET : ce qui se porte. Un verrouillé, un prochain, un spécial
    /// fermé refusent par l'immobilité (la grammaire du refus du galet).
    private func portable(_ etat: EtapeEtat) -> Bool {
        switch etat {
        case .actif, .accompli, .parfait: return true
        case .lune(let dispo), .piece(let dispo): return dispo
        default: return false
        }
    }

    /// LA DATE D'UN GALET — le chemin est un CALENDRIER : l'étape courante est
    /// aujourd'hui, chaque rang vaut un jour. Les galets passés portent donc
    /// leur vraie date, et l'actif la date du jour.
    ///
    /// ⚠️ Seuls le PASSÉ et AUJOURD'HUI en portent une. Un jour futur qui
    /// afficherait sa date promettrait un contenu qu'on n'a pas : le verdict
    /// dit « ne pas donner l'impression que le contenu est déjà accessible ».
    private func dateDe(_ e: EcranSpec.EtapeSpec) -> DateGalet? {
        guard !e.special, e.id <= etat.etape,
              let jE = EcranSpec.jour(deId: e.id),
              let jA = EcranSpec.jour(deId: etat.etape) else { return nil }
        // le calendrier compte les SÉANCES, pas les nœuds : un spécial
        // entre deux séances n'est pas un jour.
        let jours = jE - jA
        guard let d = Calendar.current.date(byAdding: .day, value: jours,
                                            to: Date()) else { return nil }
        return DateGalet.depuis(d)
    }

    /// LE PASSAGE D'ÉTAPE (partition §7) : l'adieu de l'actif, la bascule,
    /// l'allumage du suivant — et si le suivant vit sur l'écran d'après,
    /// la page défile vers sa POSE aimantée (jamais une mi-course que
    /// l'aimant re-happerait).
    private func tape(_ e: EcranSpec.EtapeSpec) {
        // Les nœuds spéciaux AVANT la garde de l'actif (audit §4 : le cas
        // lune tombait dans l'avancement). Disponible et pas encore réclamé,
        // le nœud se GRAVE et transmet à l'hôte — HORS de la transaction du
        // geste (un geste annulé garde son état) : la racine ouvre la pop-up
        // booster (lune) ou fait descendre le gain (pièce), au-dessus de la
        // route en arbre.
        if e.special {
            guard etat.etape > e.id, !etat.reclamees.contains(e.id) else { return }
            let cible: ((Int) -> Void)? = e.moon ? onLune : onPiece
            guard let cible else { return }
            withAnimation(.easeInOut(duration: 0.45)) {
                etat.reclamees.insert(e.id)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { cible(e.id) }
            return
        }
        // §23 : branchée, l'étape courante ne s'avance plus au tap — elle
        // PROPOSE (le panneau de départ). L'avance viendra de la séance.
        if etat.branchee, e.id == etat.etape {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.80)) {
                etat.departOuvert = true
            }
            return
        }
        guard e.id == etat.etape,
              let j = EcranSpec.jour(deId: etat.etape),
              j + 1 < EcranSpec.seances.count else { return }
        // l'avance saute les nœuds spéciaux : la séance suivante.
        let suivant = EcranSpec.id(pourJour: j + 1)
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
    /// §23 — le chevron de retour (dans la capsule, à gauche du bloc).
    var onRetour: (() -> Void)? = nil
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
                if let onRetour {
                    Button {
                        UIImpactFeedbackGenerator(style: .light)
                            .impactOccurred()
                        onRetour()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color(white: 0.82))
                            .frame(width: 30, height: 58)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                VStack(alignment: .leading, spacing: 3) {
                    // §22 : un écran = un chapitre de 10 gouttes.
                    Text("CHAPITRE \(etat.ecranCourant + 1)")
                        .font(.system(size: 11, weight: .semibold))
                        .kerning(1.6)
                        .foregroundStyle(Color(white: 0.52))
                        .contentTransition(.numericText())
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
        .allowsHitTesting(onRetour != nil)
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
    /// `ecranInitial` 0 = DÉRIVÉ de l'étape (une source : le panneau ne
    /// naît plus hors écran quand l'actif vit sur un autre chapitre).
    var ecranInitial: Int = 0
    var etapeInitiale: Int = 0
    /// D2 (jalon 0) — les séances FAITES, données par l'hôte depuis la base
    /// (`EcranSpec.etapeEtFaits`). nil = le motif démo du banc.
    var faits: Set<Int>? = nil
    /// Les nœuds spéciaux déjà réclamés (l'hôte les persiste).
    var reclamees: Set<Int>? = nil
    /// Jalon 1 : les nœuds spéciaux disponibles, tapés — l'hôte ouvre le
    /// booster (lune) ou fait descendre les pièces (pièce). nil = le banc.
    var onLune: ((Int) -> Void)? = nil
    var onPiece: ((Int) -> Void)? = nil
    var gel = false
    var auto = false
    /// §18 P0.1 — `-duoAutoLent` : le même aller-retour, durée ×3 (les
    /// calques et les relais se jugent au ralenti).
    var lent = false
    /// §23 — les deux sorties. La page ne connaît JAMAIS son hôte : le
    /// chevron appelle `onRetour`, le panneau confirmé appelle
    /// `onDemarrer`. `nil` = le banc `-duoLab`, rien ne change.
    var onRetour: (() -> Void)? = nil
    var onDemarrer: (() -> Void)? = nil

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
                            largeur: g.size.width,
                            decalageHaut: g.safeAreaInsets.top + 58 + 12)
                }
                // LE JOUET : pendant qu'un galet est porté, le scroll dort — légal
        // ici SEULEMENT parce que le port est un geste PRIORITAIRE qui a
        // déjà le doigt (une ceinture contre un second doigt, jamais posée
        // depuis une horloge). Deux ré-évaluations par port, pas par image.
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
                                         flou: DuoReglages.focusPillEffectif,
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
                            // §19 — LE GROS ZOOM-DÉZOOM + LA ROTATION
                            // COVER-FLOW (sa demande : « gros zoom puis
                            // dézoom et rotation à la Apple ») : la
                            // capsule passe PRÈS de la caméra (+20 % au
                            // centre du voyage), se dresse face à toi
                            // (rotation signée sin 2πu, nulle aux poses),
                            // puis DÉZOOME en se posant. La courbe en S
                            // (0,10 H) l'attarde au centre.
                            .visualEffect { [restF, hauteur] contenu, proxy in
                                let d = restF - proxy.frame(in: .scrollView).minY
                                let u = max(0, min(1, d / hauteur))
                                let s = sin(.pi * u)
                                let sSigne = sin(2 * .pi * u)
                                return contenu
                                    .offset(y: 0.10 * hauteur * s)
                                    .scaleEffect(1 + 0.20 * s)
                                    .rotation3DEffect(
                                        .degrees(DuoReglages.arriveeEffectif * sSigne),
                                        axis: (x: 1, y: 0, z: 0),
                                        perspective: 0.6)
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
                              largeur: g.size.width,
                              onDemarrer: { onDemarrer?() },
                              onLune: onLune, onPiece: onPiece) { ecran in
                        withAnimation(.easeInOut(duration: 0.7)) {
                            ordre.scrollTo(y: CGFloat(ecran) * hauteur)
                        }
                        UIImpactFeedbackGenerator(style: .medium)
                            .impactOccurred(intensity: 0.9)
                    }
                }
            }
            .scrollTargetBehavior(.paging)
            .scrollDisabled(etat.porte != nil)
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
            .onScrollPhaseChange { vieux, neuf in
                // §18 P0.2 — LE LOG DE PHASE (`-duoLogPhase`) : la preuve
                // que la phase tombe (ou pas) au scrollTo programmé —
                // print (--console-pty) ET fichier du conteneur (films).
                if DuoReglages.logPhase {
                    let ligne = "phase \(vieux) -> \(neuf) t=\(Date().timeIntervalSince1970)\n"
                    print("DUOPHASE: \(ligne)", terminator: "")
                    if let d = FileManager.default.urls(
                        for: .documentDirectory, in: .userDomainMask).first {
                        let f = d.appendingPathComponent("duo-phase.log")
                        if let h = try? FileHandle(forWritingTo: f) {
                            h.seekToEndOfFile()
                            h.write(ligne.data(using: .utf8)!)
                            try? h.close()
                        } else {
                            try? ligne.write(to: f, atomically: true,
                                             encoding: .utf8)
                        }
                    }
                }
                let geste = neuf != .idle
                if etat.enGeste != geste {
                    etat.enGeste = geste
                    // le thock d'atterrissage : la page s'est posée sur
                    // un AUTRE écran que celui du départ du geste.
                    if geste { etat.gesteCommence() } else { etat.gesteFini() }
                }
            }
            .onAppear {
                etat.branchee = onDemarrer != nil
                etat.gel = gel || reduceMotion
                etat.etape = min(max(etapeInitiale, 0),
                                 EcranSpec.etapes.count - 1)
                if let faits { etat.faits = faits }
                if let reclamees { etat.reclamees = reclamees }
                // La page NAÎT POSÉE sur l'écran de l'actif : `piloter`
                // d'abord (les lecteurs de la cible sont réveillés avant
                // le premier rendu), puis un scrollTo NON animé — jamais un
                // scroll animé à la naissance (la phase tombe, la dalle se
                // démonte, un balayage réveille des lecteurs en vol).
                let ecranDepart = ecranInitial > 0
                    ? ecranInitial : EcranSpec.etapes[etat.etape].ecran
                etat.piloter(y: CGFloat(ecranDepart) * hauteur, hauteur: hauteur)
                if ecranDepart > 0 {
                    ordre.scrollTo(y: CGFloat(ecranDepart) * hauteur)
                }
                if auto { lancerAuto(hauteur: hauteur) }
                naissance()
            }
        }
        .background(Color.black.ignoresSafeArea())
        // LA DALLE — hors scroll (école PorteEntree : le header vit hors
        // scroll), posée sous l'île.
        .overlay(alignment: .top) {
            DalleChapitre(etat: etat, onRetour: onRetour)
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
        // §22 : 50 étapes — la cascade resserrée à 35 ms, sinon 3 s.
        for (n, e) in EcranSpec.etapes.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + Double(n) * 0.035) {
                _ = withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                    etat.nees.insert(e.id)
                }
            }
        }
        // §23 — L'ARRIVÉE PROPOSE : branchée, une fois la cascade posée,
        // le galet courant s'illumine et le panneau naît (haptique douce).
        // Conditionnée à « la page est posée sur l'écran de l'actif, sans
        // geste » — sinon un scroll pendant la cascade faisait naître le
        // panneau hors écran ; elle réessaie au repos suivant.
        if etat.branchee {
            func proposerQuandPose(essai: Int) {
                let ecranActif = EcranSpec.etapes[etat.etape].ecran
                if !etat.enGeste, etat.ecranCourant == ecranActif {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.80)) {
                        etat.departOuvert = true
                    }
                } else if essai < 20 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        proposerQuandPose(essai: essai + 1)
                    }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) {
                proposerQuandPose(essai: 0)
            }
            // banc : `-duoAutoDepart` — le primary se confirme seul à
            // +3,8 s (le film du départ sans doigt).
            if CommandLine.arguments.contains("-duoAutoDepart") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.easeOut(duration: 0.18)) {
                        etat.departOuvert = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        onDemarrer?()
                    }
                }
            }
        }
    }

    /// `-duoAuto` : l'aller-retour filmé 1 → 5 → 1, une pose par écran —
    /// le film du fouettage (école `-porteAuto` : scrollTo dans withAnimation).
    private func lancerAuto(hauteur: CGFloat) {
        let f: Double = lent ? 3.0 : 1.0
        let poses: [Int] = Array(0...4) + Array((0...3).reversed())
        for (n, ecran) in poses.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6 + Double(n) * 2.2 * f) {
                withAnimation(.easeInOut(duration: 1.1 * f)) {
                    ordre.scrollTo(y: CGFloat(ecran) * hauteur)
                }
            }
        }
    }
}


// MARK: - Le panneau de départ (§23)

/// LE PETIT OVERLAY LIQUID GLASS au-dessus du galet actif : à gauche la
/// MINI-CARD (sticker flamme + la date du jour), à droite le titre, le
/// PRIMARY et le bouton-lien. Le verre est natif `.clear` + pellicule
/// noire AU-DESSUS, l'encre au-dessus de tout (l'école de la dalle,
/// verbatim). Taille CONSTANTE — l'entrée est un transform (la loi des
/// bounds vivants).
private struct PanneauDepartChemin: View {
    var onCommencer: () -> Void
    var onPlusTard: () -> Void

    // (Les `static let jour/mois` d'ici étaient du code MORT au commentaire
    // trompeur — la date vient de `MiniCardJour(date: Date())`, vivante,
    // même source que le galet. Retirés au fouet du 27-08.)

    var body: some View {
        HStack(spacing: 14) {
            miniCard
            VStack(alignment: .leading, spacing: 9) {
                Text("Session du jour")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(LinearGradient(
                        colors: [Color(white: 1.0), Color(white: 0.84)],
                        startPoint: .top, endPoint: .bottom))
                Button(action: onCommencer) {
                    Text("Commencer")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(white: 0.06))
                        .padding(.horizontal, 20)
                        .frame(height: 34)
                        .background(Capsule().fill(Color(white: 0.96)))
                }
                .buttonStyle(.plain)
                Button(action: onPlusTard) {
                    Text("Plus tard")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(width: 296)
        .background {
            ZStack {
                GlassEffectContainer(spacing: 0) {
                    Color.clear
                        .glassEffect(.clear,
                                     in: RoundedRectangle(cornerRadius: 28))
                }
                // la pellicule : le noir AU-DESSUS du verre, sous l'encre.
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.black.opacity(0.32))
            }
        }
        .shadow(color: .black.opacity(0.55), radius: 20, y: 10)
    }

    /// ⚠️ **LA VRAIE MINI-CARD DE LA HOME, PAS UNE APPROXIMATION** (26-08).
    /// Verdict : « tu as pris le bon composant général, mais il faut reprendre
    /// LA VRAIE mini-card carrée utilisée sur la Home dans "Toute la semaine" —
    /// vraie mini-card, vraie date, vrai sticker flamme, même design que la
    /// Home. Pas une approximation. »
    ///
    /// Et c'en était une : double coque à 15/13 pt de rayon contre 10 sur la
    /// Home, un `flame.fill` système dégradé à la place du STICKER, le jour
    /// centré à 24 pt au lieu d'être calé en haut à gauche à 10, aucun grain,
    /// aucune nappe elliptique, 66 × 88 au lieu de 70 × 78. Deux objets qui se
    /// ressemblaient, et qui divergeaient à chaque retouche de l'un des deux.
    /// C'est littéralement le même code qui rend les deux maintenant.
    private var miniCard: some View {
        MiniCardJour(date: Date(),
                     // Le sticker FLAMME, celui de la Home — lu dans sa table,
                     // jamais recopié : `SemaineStrip.stickers[1]`.
                     sticker: SemaineStrip.sticker(1),
                     faite: true,
                     largeur: 70, hauteur: 78)
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
        if args.contains("-pillMire") {
            // §20 Pil-1 : la mire des matières (natif / liquidLens / peint /
            // métal sablé) sur noir et sur feu.
            PillMireLab()
        } else if args.contains("-duoGalets") {
            // La mire du galet-étape (J2) : la grammaire seule, deux fonds.
            GaletEtapeLab()
        } else {
            DuolinguoPage(ecranInitial: ecran,
                          etapeInitiale: etape,
                          gel: args.contains("-duoFreeze"),
                          auto: args.contains("-duoAuto")
                              || args.contains("-duoAutoLent"),
                          lent: args.contains("-duoAutoLent"))
                .environment(\.colorScheme, .dark)
        }
    }
}
