import SwiftUI
import AVFoundation

// MARK: - LA SCÈNE DE DÉPART
//
// Le plan complet vit dans `tools/home-v2/PLAN-SCENE-DEPART.md`. Ce qu'il faut
// savoir ici, et qui explique CHAQUE choix de ce fichier :
//
// ⚠️ LE DÉFAUT N'ÉTAIT PAS UNE DURÉE, C'ÉTAIT UNE ARCHITECTURE. `scene` valait
// `-tirage/150` : le pouce était le projectionniste. Un pouce parcourt 150 pt
// en 0,20 s, donc le film durait 0,20 s. Le correctif est de SÉPARER LE GESTE
// DU FILM — le doigt ARME (il ne fait que de la lumière), et au cran une
// partition de 1,95 s part toute seule que plus rien n'accélère.
//
// ⚠️ LE SCRUB EST MORT, ET TROIS MESURES INDÉPENDANTES LE DISENT :
//   · `home-fond-loop.mp4` = 859 images, 72 clés (GOP 11,9). Le geste demandait
//     4 295 img/s et 360 franchissements de clé par seconde, à tolérance ZÉRO.
//     AVPlayer en sert 15 à 25 : on voyait QUATRE images sur 859 ;
//   · le clip source ne dérive que de 47 pt en x / 28 pt en y sur 6 s — le
//     « roulé façon AirPods » n'a JAMAIS été dans l'image, il doit venir de la
//     transformation ;
//   · le fichier est un PALINDROME (split→reverse→concat) : l'image 858 vaut
//     l'image 0 à 0,71/255 près. `scrub = 1` montrait la MÊME image que
//     `scrub = 0`. Le geste ne changeait pas d'image, par construction.
//   On LIT donc les fichiers, en boucle, et on monte le `rate` pendant la
//   chute. Zéro seek.
//
// ⚠️ ET UN `Chambre(p: e)` NOURRI PAR UNE `Date` NE JOUE RIEN. `Chambre` est
// `Animatable` : SwiftUI n'interpole que si la valeur change DANS UNE
// TRANSACTION. Une horloge murale n'invalide aucun body. D'où l'unique
// `TimelineView` à la racine de la home.

// MARK: - La partition

/// LES INSTANTS, EN SECONDES ABSOLUES. L'école `BravoCine` / `MoonSplashBeat` :
/// des `static let` nommés, et **rien que** des fonctions pures de `e`. Rien
/// n'est stocké, donc `-departFige <e>` reconstitue la scène à n'importe quel
/// instant et on la juge sur images fixes.
enum DepartCine {

    /// La durée du film. Mesure de contrôle : l'ARRIVÉE de cette même page dure
    /// déjà 1,84 s. Le départ était à 0,20 s — un ordre de grandeur sous son
    /// propre écran.
    static let T: Double = 1.95

    /// LA COURSE, COMMUNE AU TEXTE ET À LA PILULE. Elle est DÉRIVÉE DEUX FOIS,
    /// et les deux dérivations tombent à 1,1 pt l'une de l'autre :
    ///  · le texte : le bas de l'ancien bloc (110..289, réduit à ×0,90 ancre
    ///    haute ⇒ 161,1 de haut) doit rejoindre le haut du nouveau (554) ⇒ 282,9
    ///  · la pilule : son centre (315 au repos) doit finir dans le cœur du lit,
    ///    mesuré à 599 ⇒ 284
    ///
    /// ⚠️ LES FLÈCHES DE KATHRYN FONT 450 pt, ET C'EST HONORÉ — mais en distance
    /// RELATIVE, pas en translation : la braise, clouée à l'arête basse, MONTE
    /// de 156 pt à la rencontre de ce qui descend. 284 + 156 = 440, sa mesure à
    /// 2 % près. Une translation écran de 450 mettrait le centre de la pilule
    /// 49 pt SOUS l'arête et couperait 63 % de l'objet.
    static let course: CGFloat = 334

    /// LA COURSE DU TEXTE — plus longue que celle de la pilule, et c'est voulu.
    ///
    /// Les deux blocs (l'accueil et l'arrivée) ont leurs BAS confondus à chaque
    /// image : l'accueil part de 291 et doit finir à 694, là où vit la phrase
    /// d'arrivée. 694 − 291 = **403**. Le plan du devant va donc plus loin que
    /// le plan du fond — c'est la parallaxe, et elle est dans le bon sens.
    ///
    /// ⚠️ **441 DEPUIS LE 02-09, ET C'EST UNE CONSÉQUENCE MÉCANIQUE.** La phrase
    /// d'accueil est passée de CINQ à QUATRE lignes ; elle est ancrée par le
    /// HAUT (`.padding(.top, 48)`), donc son bas est REMONTÉ d'une hauteur de
    /// ligne, tandis que la phrase d'arrivée, épinglée par le BAS
    /// (`leveeTiroir + 6`), n'a pas bougé d'un point. Sans ce recalage, les deux
    /// bas ne sont plus confondus et la bascule (`basculeAt` 0,94 · 0,12 s)
    /// devient un FAUX RACCORD : la ligne qu'on lit saute au moment précis où
    /// les mots se substituent — exactement ce que la métamorphose validée
    /// interdit.
    ///
    /// Le chiffre est MESURÉ, pas déduit : le pas de ligne vaut 38,35 pt
    /// (sommets d'encre de « Hello Kathryn, » à 131,0 et de « 6 workouts » à
    /// 207,7, deux pas — `tools/home-v2/mesure_cotes.py` sur
    /// `captures/pose-083906.png`). ⚠️ Ce n'est PAS `taille × 1,14 + interligne`
    /// (36,2) : la formule que `PhraseVue.sourd(_:)` utilise pour lire la lampe
    /// est fausse de 2,15 pt par ligne — défaut latent, sans conséquence
    /// visible, constaté ici et pas corrigé.
    /// 403 + 38,35 ≈ **441**.
    static let courseTexte: CGFloat = 441

    /// LE SOMMET DU FLOU, et l'instant où les mots changent.
    static let clocheAt = 0.10, clocheSommet = 1.00, clocheFin = 1.62
    /// ⚠️ **15, PAS 26** (verdict 22-08 : « il y a un petit calque blanc quand le
    /// texte descend »). Ce n'était pas un calque : à 26 pt de rayon sur un
    /// corps de 30, chaque ligne se DISSOUT en une dalle blanche pleine, et
    /// trois dalles empilées se lisent comme une nappe posée. À 15 on lit encore
    /// des mots hors du net — c'est une mise au point, pas une gomme.
    static let flouMax: CGFloat = 15
    static let basculeAt = 0.94, basculeFor = 0.12

    // Les fenêtres, en secondes.
    static let poseAt = 0.00,   poseFor = 0.28     // la card finit de se poser
    static let luneAt = 0.00,   luneFor = 0.45     // la lune se couche
    static let netAt  = 0.00,   netFor  = 0.26     // le net finit (chemin tap)
    static let verreAt = 0.26                       // le verre est DÉMONTÉ
    static let texteAt = 0.10,  texteFor = 1.42    // LA CHUTE DU TEXTE
    static let flouAt  = 0.10,  flouFor  = 0.68
    static let fadeAt  = 0.66,  fadeFor  = 0.64    // …et seulement là il s'éteint
    static let pilAt   = 0.14,  pilFor   = 1.42    // LA CHUTE DE LA PILULE
    static let zoomAt  = 0.20,  zoomFor  = 1.42
    static let roulXAt = 0.14,  roulXFor = 1.26
    static let roulYAt = 0.44,  roulYFor = 1.30
    static let rateAt  = 1.55                       // le film reprend sa cadence
    static let foyerAt = 0.74,  foyerFor = 0.92
    static let occAt   = 1.04,  occFor   = 0.68
    static let voileAt = 0.92,  voileFor = 0.66
    static let motAt   = 0.96,  motFor   = 0.82    // la nouvelle phrase
    static let motRetard = 0.13, motRampe = 0.56
    static let slidAt  = 0.95,  slidFor  = 0.87

    // MARK: Les courbes

    /// La fenêtre lissée — `x²(3−2x)`, la même partout dans le dépôt.
    static func sstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let t = min(max((x - a) / max(b - a, 1e-6), 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// LE PLONGEON — `timingCurve(0.62, 0, 0.20, 1)`, la courbe la plus lente du
    /// dépôt (celle de `WahouReveal`). Elle est TRÈS asymétrique, et c'est le
    /// point : 10 % du trajet dans les 26 premiers pour-cent du temps, puis
    /// l'objet s'élance, puis il s'installe très longuement. Une courbe
    /// régulière étirée sur 1,5 s donne un ASCENSEUR — et un ascenseur lent est
    /// pire qu'un ascenseur rapide.
    static func plongeon(_ a: Double, _ b: Double, _ x: Double) -> Double {
        bezier(0.62, 0.00, 0.20, 1.00, min(max((x - a) / max(b - a, 1e-6), 0), 1))
    }

    /// LE DOLLY — l'échelle appartient à la CAMÉRA, pas au corps : elle n'a donc
    /// pas la même courbe que la translation, et elle finit après elle.
    static func dolly(_ a: Double, _ b: Double, _ x: Double) -> Double {
        bezier(0.42, 0.00, 0.28, 1.00, min(max((x - a) / max(b - a, 1e-6), 0), 1))
    }

    /// La pose de la card : départ raccordé à la vitesse du doigt (l'élastique
    /// `tanh` a déjà décéléré), arrivée très molle.
    static func pose(_ a: Double, _ b: Double, _ x: Double) -> Double {
        bezier(0.10, 0.55, 0.36, 1.00, min(max((x - a) / max(b - a, 1e-6), 0), 1))
    }

    /// La courbe des feuilles d'Apple, pour l'arrivée du slider.
    static func feuille(_ a: Double, _ b: Double, _ x: Double) -> Double {
        bezier(0.22, 1.00, 0.36, 1.00, min(max((x - a) / max(b - a, 1e-6), 0), 1))
    }

    /// Une bézier cubique unitaire, résolue en x par Newton (5 tours suffisent :
    /// l'erreur tombe sous 1e-6, soit 0,0003 pt sur une course de 284).
    static func bezier(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double,
                       _ x: Double) -> Double {
        if x <= 0 { return 0 }
        if x >= 1 { return 1 }
        func cx(_ t: Double) -> Double {
            let u = 1 - t
            return 3 * u * u * t * x1 + 3 * u * t * t * x2 + t * t * t
        }
        func dcx(_ t: Double) -> Double {
            let u = 1 - t
            return 3 * u * u * x1 + 6 * u * t * (x2 - x1) + 3 * t * t * (1 - x2)
        }
        var t = x
        for _ in 0..<5 {
            let d = dcx(t)
            guard abs(d) > 1e-6 else { break }
            t -= (cx(t) - x) / d
            t = min(max(t, 0), 1)
        }
        let u = 1 - t
        return 3 * u * u * t * y1 + 3 * u * t * t * y2 + t * t * t
    }

    // MARK: Les grandeurs, une fonction pure par objet

    /// La descente du texte et celle de la pilule : **la même course, la même
    /// courbe**, décalées de 40 ms au départ comme à l'arrivée — le verre est
    /// plus lourd que l'encre.
    static func chuteTexte(_ e: Double) -> CGFloat {
        courseTexte * CGFloat(plongeon(texteAt, texteAt + texteFor, e))
    }

    /// LE FLOU EN CLOCHE — 0 → 26 → 0. Il monte pendant que le bloc descend, et
    /// il redescend pendant qu'il se pose. **Le changement de mots est caché à
    /// son sommet** : c'est ce qui fait qu'on lit une transformation et pas un
    /// remplacement.
    static func clocheTexte(_ e: Double) -> CGFloat {
        let monte = sstep(clocheAt, clocheSommet, e)
        let tombe = sstep(clocheSommet, clocheFin, e)
        return flouMax * CGFloat(monte * (1 - tombe))
    }

    /// LA POSE D'UNE LIGNE — sa remontée au net, décalée. Elle est écrite sur la
    /// RETOMBÉE de la cloche seulement : à la descente les trois lignes floutent
    /// ensemble (sinon le bloc se déchire), et c'est en revenant qu'elles se
    /// posent l'une après l'autre. C'est la vague, et elle ne coûte rien.
    static func poseLigne(_ e: Double, retard: Double) -> CGFloat {
        CGFloat(sstep(clocheSommet + retard, clocheFin + retard, e))
    }

    /// **CE QUI SORT DU NET PERD AUSSI SA MATIÈRE.** L'ancien bloc restait à
    /// PLEINE opacité jusqu'à e = 0,94, donc au sommet du flou on regardait un
    /// bloc blanc à 100 % étalé sur 15 pt — la vraie cause du « calque blanc ».
    /// Dans un vrai transfert de point, le sujet qui sort du net perd son
    /// contraste en même temps que sa netteté. Ici : jusqu'à −45 % au sommet.
    static func matiere(_ e: Double) -> Double {
        1 - 0.45 * Double(clocheTexte(e) / flouMax)
    }

    /// LE FONDU CROISÉ, 0,12 s au sommet du flou. À 26 pt de rayon, ni l'échange
    /// des mots ni le passage de cinq lignes à trois ne se voient.
    static func bascule(_ e: Double) -> Double {
        sstep(basculeAt, basculeAt + basculeFor, e)
    }
    static func chutePilule(_ e: Double) -> CGFloat {
        course * CGFloat(plongeon(pilAt, pilAt + pilFor, e))
    }
    /// L'APPROCHE. Elle finit 0,06 s APRÈS la chute : le sujet se pose, la
    /// caméra s'installe encore.
    static func zoomPilule(_ e: Double) -> CGFloat {
        1 + 0.22 * CGFloat(dolly(zoomAt, zoomAt + zoomFor, e))
    }
    /// LE ROULÉ, deux axes DÉCALÉS DE 0,30 s — et c'est tout l'effet. Deux axes
    /// synchrones se composent en un axe FIXE : on lit alors un plan qu'on
    /// incline. Décalés, l'axe résultant DÉRIVE et on lit un corps qui bascule.
    static func roulisX(_ e: Double) -> Double {
        8 * plongeon(roulXAt, roulXAt + roulXFor, e)
    }
    static func roulisY(_ e: Double) -> Double {
        -3 * bezier(0.30, 0, 0.30, 1,
                    min(max((e - roulYAt) / roulYFor, 0), 1))
    }
    /// LE FILM ACCÉLÈRE — deux appels en tout, pas de rampe, ZÉRO seek. Ce n'est
    /// pas une base de temps, c'est une vie interne : à 2,2 pendant 1,55 s le
    /// barycentre ne dérive que de 4 pt.
    /// ⚠️ **IL NE MONTE PLUS.** Il était à 2,2 pendant 1,55 s pour que les
    /// caustiques du verre s'accélèrent pendant la chute — un luxe. Mais il
    /// DOUBLAIT le coût de décodage exactement pendant le film : 137 Mpix/s au
    /// repos, **301 pendant la scène**, au pire moment possible. C'était une des
    /// deux causes du « la vidéo lag beaucoup ». À re-tenter à 1,4 seulement si
    /// la mesure au téléphone laisse de la marge.
    static func rate(_ e: Double) -> Float { 1.0 }

    static func foyer(_ e: Double) -> Double { sstep(foyerAt, foyerAt + foyerFor, e) }
    static func occlusion(_ e: Double) -> Double { sstep(occAt, occAt + occFor, e) }
    static func voile(_ e: Double) -> Double { sstep(voileAt, voileAt + voileFor, e) }
    static func slider(_ e: Double) -> Double { feuille(slidAt, slidAt + slidFor, e) }

    /// La nouvelle phrase, fragment par fragment. Recouvrement 77 % : c'est ce
    /// chevauchement qui fait la VAGUE — des fenêtres disjointes font une liste.
    static func mot(_ i: Int, _ e: Double) -> Double {
        let a = motAt + Double(i) * motRetard
        return sstep(a, a + motRampe, e)
    }
}

// MARK: - Un calque vidéo

/// UN PLAN, ET RIEN QU'UN PLAN. Deux exemplaires composent le fond de la home :
/// la braise clouée à l'arête basse, la pilule libre au-dessus.
///
/// ⚠️ L'IMAGE DE POSE EST **DANS** LA VUE, sous le `playerLayer`. Elle était
/// posée dehors, sous une vidéo OPAQUE qui la couvrait ; en additif elle
/// s'AJOUTERAIT et on verrait DEUX pilules, une fixe et une qui descend. Elle
/// s'efface sur `isReadyForDisplay`.
///
/// ⚠️ ON TRANSFORME, ON NE REDIMENSIONNE JAMAIS : un `AVPlayerLayer` dont la
/// frame change 60×/s relayoute et re-rend chaque image (loi payée dans
/// `DepartSeance`). Les mouvements vivent en `scaleEffect` / `offset` /
/// `rotation3DEffect` côté SwiftUI, jamais en `.frame` animée.
/// LE CELLIER DES VIDÉOS — un `AVURLAsset` par fichier, gardé.
///
/// ⚠️ **IL N'Y AVAIT AUCUN CACHE POUR SEIZE LECTEURS** (26-08). Chaque
/// `AVPlayerItem(url:)` construit son propre `AVURLAsset` et le fait PARSER :
/// l'en-tête du fichier, la table d'index, les pistes. Payé à chaque montage,
/// et les pages en montent plusieurs d'un coup — le Parcours en fait naître
/// une dizaine dans la même image. C'est une part directe du « les pages
/// mettent trop de temps à apparaître ».
///
/// ⚠️ **ON PARTAGE L'ASSET, JAMAIS L'ITEM.** Un `AVPlayerItem` n'appartient
/// qu'à un seul lecteur — le donner à deux, c'est le voir disparaître du
/// premier. L'asset, lui, est fait pour être partagé : c'est la ressource, pas
/// la lecture.
enum AssetsVideo {
    private static var cache: [String: AVURLAsset] = [:]
    private static let verrou = NSLock()

    /// L'asset du fichier, chargé une fois pour toutes. `nil` si le fichier
    /// n'est pas dans le bundle (l'appelant garde sa pose).
    static func asset(_ nom: String) -> AVURLAsset? {
        verrou.lock(); defer { verrou.unlock() }
        if let a = cache[nom] { return a }
        guard let url = Bundle.main.url(forResource: nom, withExtension: "mp4")
        else { return nil }
        let a = AVURLAsset(url: url,
                           options: [AVURLAssetPreferPreciseDurationAndTimingKey: false])
        cache[nom] = a
        return a
    }

    /// Un item neuf sur un asset chaud.
    static func item(_ nom: String) -> AVPlayerItem? {
        asset(nom).map { AVPlayerItem(asset: $0) }
    }

    /// LES BOUCLES DU CHEMIN CHAUD, cuites en fond de cale pendant le splash.
    /// On ne précharge QUE ce que la traversée rencontre à coup sûr : chauffer
    /// tout le dossier coûterait la mémoire de fichiers qu'on ne verra pas.
    static func chauffer() {
        Task.detached(priority: .utility) {
            // ⚠️ **LE FILM DE LA PORTE D'ABORD** (26-08, verdict « la vidéo
            // lag alors qu'une 4K ne lag pas »). Il s'ouvrait À FROID au
            // moment précis où le splash meurt : `AVPlayerItem(url:)` fait
            // parser le fichier, et `automaticallyWaitsToMinimizeStalling =
            // false` le fait partir SANS attendre son tampon. Le lecteur
            // hoquetait pendant que la sonde de cadence, elle, affichait
            // 60 img/s : le display link ne voit PAS un décodeur en retard.
            // Il se charge maintenant pendant les 3,9 s du splash, qui ne
            // coûtent qu'un shader.
            for nom in ["onb-arrivee", "onb-lune-loop",
                        "home-fond-flamme",
                        "home-fond-pilule", "story-pilule-droite",
                        "exos-fond-loop"] {
                guard let a = asset(nom) else { continue }
                _ = try? await a.load(.tracks)
            }
        }
    }
}

struct CalqueVideo: UIViewRepresentable {

    /// Le nom du fichier dans le bundle, sans extension.
    let nom: String
    /// L'image de pose dans les assets.
    let pose: String
    /// La cadence de lecture. 1,0 au repos, 2,2 pendant la chute.
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
            // ⚠️ **LE FILET DU DÉBORDEMENT** (ajouté 22-08, chantier de la
            // porte). Un `AVPlayerLayer` en `resizeAspectFill` sort de ses
            // bornes, et **le `clipShape` de SwiftUI ne rattrape PAS une couche
            // UIKit** — mesuré ailleurs à 2,3 pt de débord au lieu de 10 sur la
            // card exos. Ce calque n'était sauvé que par un hasard : le ratio du
            // cadre de la flamme (402,010/427,322 = 0,940766) est celui du
            // fichier (604/642 = 0,940810) à 4,4e-5 près, soit moins de 0,02 pt
            // de marge. Ce n'est pas un filet, c'est une coïncidence — et la
            // porte réutilise ce calque à d'autres cotes.
            clipsToBounds = true
            playerLayer.masksToBounds = true
        }
        required init?(coder: NSCoder) { fatalError() }
        override func layoutSubviews() {
            super.layoutSubviews()
            pose.frame = bounds
            // Pas d'animation implicite sur la frame du calque : au premier
            // layout elle glisserait depuis .zero.
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
        // L'asset vient du cellier : chaud, il ne se re-parse pas.
        guard let modele = AssetsVideo.item(nom)
        else { return v }                       // la pose tient la page seule
        let p = AVQueuePlayer()
        p.isMuted = true
        p.automaticallyWaitsToMinimizeStalling = false
        let c = context.coordinator
        c.looper = AVPlayerLooper(player: p, templateItem: modele)
        c.player = p
        v.playerLayer.player = p
        // ⚠️ LES RÉVEILS REJOUENT LE RATE DEMANDÉ (03-09, chantier chauffe
        // item 1) : les trois chemins ci-dessous faisaient un `play()` EN
        // DUR — chaque déverrouillage entre deux séries relançait TOUS les
        // lecteurs sous la porte `couvre`, et le cache de `updateUIView`
        // interdisait toute re-pause. Désormais chacun rejoue `c.rate` (ce
        // que l'hôte demande) : un lecteur en pose RESTE en pose.
        c.rate = rate
        if c.rate > 0 { p.rate = c.rate }
        // ⚠️ `preroll` LÈVE UNE EXCEPTION tant que le statut n'est pas
        // `readyToPlay` — appelé à la construction, il tue l'app au
        // lancement. Préroller reste permis (le filet anti-frames-
        // manquées) : c'est le play FINAL qui se conditionne.
        c.statut = p.observe(\.status, options: [.new]) { [weak c] joueur, _ in
            guard joueur.status == .readyToPlay else { return }
            joueur.preroll(atRate: 1) { fini in
                guard fini, let c, c.rate > 0 else { return }
                joueur.rate = c.rate
            }
        }
        // La pose s'efface quand la première image est là, pas avant.
        c.pret = v.playerLayer.observe(\.isReadyForDisplay, options: [.new]) {
            couche, _ in
            guard couche.isReadyForDisplay else { return }
            DispatchQueue.main.async { v.pose.isHidden = true }
        }
        c.retour = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil, queue: .main) { [weak p, weak c] _ in
                guard let p, let c, c.rate > 0 else { return }
                p.rate = c.rate
            }
        return v
    }

    func updateUIView(_ v: Vue, context: Context) {
        let c = context.coordinator
        guard let p = c.player else { return }
        // La cadence ne change qu'aux deux instants prévus : on ne réécrit pas
        // `rate` à chaque image, ça relancerait la lecture en boucle.
        guard abs(c.rate - rate) > 0.01 else { return }
        c.rate = rate
        if p.timeControlStatus != .paused || rate > 0 { p.rate = rate }
    }

    static func dismantleUIView(_ v: Vue, coordinator: Coordinator) {
        coordinator.player?.pause()
        coordinator.looper?.disableLooping()
        v.playerLayer.player = nil
    }
}

/// L'ENCART BAS DE LA SAFE AREA, transmis à la card.
///
/// ⚠️ Il ne s'écrit JAMAIS en dur. 34 pt est une cote d'iPhone 17 Pro, pas une
/// loi : elle change d'un modèle à l'autre, et un « 34 » figé ferait dériver
/// l'arête de la card sur tout autre appareil. La page le LIT dans son
/// `GeometryReader` et le passe.
private struct EncartBasKey: EnvironmentKey {
    static let defaultValue: CGFloat = 34
}

extension EnvironmentValues {
    var encartBas: CGFloat {
        get { self[EncartBasKey.self] }
        set { self[EncartBasKey.self] = newValue }
    }
}

/// LE SAC DES VARIANTES — la première ligne du bloc de départ, et le libellé du
/// slider. Ils changent à chaque tirage.
///
/// ⚠️ **UN SAC MÉLANGÉ, PAS UN `random`.** On tire SANS REMISE ; quand le sac est
/// vide on le remélange en interdisant que la première soit la dernière sortie.
/// Conséquences : jamais deux fois de suite la même, et on voit les 27 avant
/// d'en revoir une. Un `Int.random` pur redonnerait la même variante deux fois
/// sur sept — assez pour qu'elle croie que ça ne marche pas.
///
/// ⚠️ **LE TIRAGE SE FAIT DANS `lancer()`, JAMAIS DANS UN `body`.** Un body doit
/// rester pur : il est réévalué plusieurs fois par image, et le texte changerait
/// en plein fondu.
///
/// ⚠️ **DEUX RÈGLES D'ÉCRITURE, ÉLIMINATOIRES**, pour toute variante future :
///  1. **Virgule finale, sans exception.** La ligne 2 commence par un `s`
///     minuscule : un point rendrait le bloc agrammatical (« Be on fire. slide
///     to start your session. »).
///  2. **Le test se fait à TROIS lignes**, jamais sur la ligne seule. Écartée
///     sur ce seul motif : « Your excuses called, » — c'est une amorce de blague
///     qui appelle sa chute, et « slide to start » n'est pas sa chute.
///
/// Toutes les cotes ci-dessous sont mesurées à **CoreText avec
/// `Inter-SemiBold.otf` à 30 pt**, crénage GPOS compris. **Plafond : 300 pt**,
/// pas 330 — la largeur du bloc vaut `écran − 72`, donc elle tombe à 303 sur un
/// écran de 375 pt, et une ligne qui passerait à la ligne ferait grandir le bloc
/// VERS LE HAUT (il est ancré par le bas), déplaçant la seule ligne qu'on lit.
@MainActor
enum DepartMots {

    /// Écartées à la mesure, pour mémoire — elles débordent :
    /// « Be more stronger today, » 348 · « Destroy something today, » 375 ·
    /// « Terrify your future self, » 339 · « Time to be dangerous, » 325.
    /// ⚠️ La préférée de Kathryn (« be more stronger today ») est impossible
    /// deux fois : elle déborde ET l'anglais est cassé. « Be stronger today, »
    /// la remplace — le seul endroit où on réécrit ses mots.
    static let lignes = [
        "Alright Kathryn,", "There you are,", "Good to see you,",
        "Take your time,", "Nothing to prove,", "One more, Kathryn,",
        "You showed up,", "Be stronger today,", "Be a better version,",
        "Beat yesterday,", "No excuses today,", "Be on fire,",
        "Be badass today,", "Be sexy today,", "Be funking badass,",
        "Make it hurt,", "Zero mercy today,", "Wreck it, Kathryn,",
        "Earn the shower,", "The couch will wait,", "Nobody's watching,",
        "Feel free to panic,", "Legs, we're sorry,", "Scare the mirror,",
        "Summon the beast,", "Gravity is optional,", "The iron misses you,"
    ]

    /// Le libellé du slider. Le pouce mange les 90 pt de gauche de la capsule,
    /// d'où « Kick your ass » et non « Start Kick your Ass ».
    static let boutons = [
        "Start", "Begin", "Send it", "Let's go", "Unleash", "Just start",
        "Start Hulk", "Start Dude", "Beast mode", "Slide, killer",
        "Start, champ", "Kick your ass", "Start, dammit", "Start the fire",
        "Wake the beast", "Start suffering", "Start, gorgeous"
    ]

    private static var sacLignes: [String] = []
    private static var sacBoutons: [String] = []
    private static var derniereLigne: String?
    private static var dernierBouton: String?

    static func tirer() -> (ligne: String, bouton: String) {
        (piocher(&sacLignes, lignes, &derniereLigne),
         piocher(&sacBoutons, boutons, &dernierBouton))
    }

    private static func piocher(_ sac: inout [String], _ tout: [String],
                                _ derniere: inout String?) -> String {
        if sac.isEmpty {
            sac = tout.shuffled()
            // Le seul cas où le sac peut répéter : la première du nouveau sac
            // est la dernière de l'ancien. On l'échange avec sa voisine.
            if sac.count > 1, sac[0] == derniere { sac.swapAt(0, 1) }
        }
        let m = sac.removeFirst()
        derniere = m
        return m
    }
}

/// LA COULEUR DU FEU — **le ratio de canaux MESURÉ du lit**, pas un goût :
/// 1 : 0,272 : 0,015, teinte 15,7°, saturation 0,985.
///
/// ⚠️ Ajouter du lit à du lit ne change NI la teinte NI la saturation : la loi
/// anti-brun est satisfaite par CONSTRUCTION, pas par précaution. Un orange
/// « de goût » à 1 : 0,42 : 0,13 (saturation 0,87) DÉSATURE le feu — et une
/// saturation qui baisse, c'est exactement du brun.
enum Feu {
    static let lit = Color(red: 1.000, green: 0.272, blue: 0.015)
}

// MARK: - Le fond en deux plans

/// LE FOND DE LA HOME — deux calques additifs, une lampe entre les deux.
///
/// L'empilement, de bas en haut : ① la braise, clouée à l'arête basse, AUCUNE
/// transformation, jamais · ② le foyer, qui suit la pilule · ③ l'occlusion de
/// contact · ④ la pilule, qui descend, roule et grossit.
///
/// **La lampe est SOUS la pilule, et la pilule est additive.** Conséquence
/// gratuite, sans un seul shader : là où le verre est sombre on voit la braise ;
/// là où il est moyen il PREND la teinte du lit ; là où il est spéculaire il
/// reste blanc. C'est ce que fait du verre au-dessus d'un lit de braises, et la
/// loi « pas de shader sur un AVPlayerLayer » n'est pas contournée : elle est
/// rendue inutile.
struct FondDeuxCalques: View {

    /// Le temps de la scène, en secondes.
    var e: Double
    /// ⚠️ **L'ENTRÉE DE LA PILULE, 0 → 1** (26-08). Verdict : « la pill
    /// apparaît après le reste, pas avant ».
    ///
    /// Elle apparaissait EN PREMIER, et pour une raison qu'on ne pouvait pas
    /// deviner en cherchant un composant SwiftUI : **la pill rouge n'en est
    /// pas un**, c'est le calque vidéo `home-fond-pilule` de ce fond. Elle
    /// vivait donc dans la naissance de la card (easeOut 1,15 s dès t = 0),
    /// c'est-à-dire 380 ms AVANT le premier mot de la phrase.
    ///
    /// Un fondu sur le calque, et rien d'autre : pas question de retarder son
    /// LECTEUR (une vidéo qui démarre en retard se raccorde mal à la braise,
    /// qui, elle, ne bouge jamais).
    var pilule: Double = 1
    /// LA HOME DORT SOUS LA ROUTE (jalon 1) : les deux lecteurs cèdent la
    /// place à leur pose.
    @Environment(\.dort) private var dort

    /// ⚠️ LE BARREAU DU FOND VIDÉO (05-09) — `-fondPose` force les deux
    /// calques sur leur IMAGE DE POSE, comme quand la home dort. Rien
    /// d'autre ne change.
    ///
    /// POURQUOI IL EXISTE : sa balade dit « ça chauffe dès que je lance
    /// Woop », et la bissection du 05-09 sur son iPhone 15 a donné
    /// écran nu 1,0 % de processeur contre accueil 27,0 % — les 26 points
    /// sont TOUS dans la page, et aucun barreau de bloc (widgets, galet,
    /// pièce, grain) ne les a bougés. Restent ces deux lecteurs, qui
    /// tournent en boucle sur une page immobile.
    private var poseSeule: Bool { dort || FondPoseBanc.actif }

    // ⚠️ L'ÉCHELLE DES DEUX CALQUES EST CONSTANTE, ET C'EST CELLE DU REPOS.
    // C'était LA deuxième cause du bug : `aspectFill` remplit par la HAUTEUR
    // quand la card est pleine (ratio 0,442 contre 0,460) et par la LARGEUR
    // quand le tiroir l'a raccourcie (ratio 0,511) — et il CENTRE. Chaque point
    // de levée déplaçait donc le contenu de 0,5 pt, et à L = 156 on jetait
    // 58 % de la lumière de la braise hors du cadre.
    // Ici : plus d'aspectFill du tout. Une taille figée, deux ancrages.
    static let canevasW: CGFloat = 1080
    static let canevasH: CGFloat = 2348
    /// **874 pt pour 2348 lignes** — la card prend maintenant tout l'écran en
    /// largeur, et c'est un coup de chance mesuré : la vidéo fait 0,45997 de
    /// ratio, l'écran 0,46 (402 × 874). Le cadrage est donc EXACT, on ne rogne
    /// plus rien. (Avant, à marge 10, on perdait 7,7 pt de chaque côté.)
    static let K: CGFloat = 874.0 / 2348.0
    static var largeur: CGFloat { canevasW * K }   // 401,9
    static var hauteur: CGFloat { canevasH * K }   // 874,0

    // ⚠️ **CHAQUE CALQUE EST ROGNÉ À SA BOÎTE UTILE** (verdict 22-08 : « la
    // vidéo lag beaucoup »). Les fichiers ne portent plus le canevas entier :
    // la pilule ne vit qu'aux lignes 460..1210 et aux colonnes 0..980, la braise
    // qu'aux lignes 1460..2348. Budget de décodage mesuré :
    //   avant  152 Mpix/s au repos, **301 pendant le film** (le rate à 2,2)
    //   après   27 Mpix/s — 5,7× moins, et plus de pic pendant la scène.
    // Les cotes ci-dessous sont celles du ROGNAGE : elles doivent suivre
    // `recuit_calques.sh` au pixel, sinon les calques se décalent en silence.
    /// ⚠️ **MESURÉES À PLEINE RÉSOLUTION.** Payé : les premières cotes venaient
    /// de vignettes réduites 4×, qui perdent les pixels faibles — le rognage
    /// coupait 26 lignes en haut, 19 en bas et 29 colonnes à droite de la
    /// pilule, et **233 lignes** de la braise. Verdict : « la vidéo de la pilule
    /// est coupée en haut et sur les côtés ».
    /// Boîtes vraies (seuil 1/255, 8 images du canevas 1080×2348 en pleine
    /// définition) : pilule lignes **434..1229**, colonnes 0..1009 · braise à
    /// partir de la ligne **1227**. Les cotes ci-dessous prennent une marge et
    /// gardent la largeur entière.
    static let pilCropX: CGFloat = 0,    pilCropW: CGFloat = 1080
    static let pilCropY: CGFloat = 400,  pilCropH: CGFloat = 864
    static let braCropY: CGFloat = 1200, braCropH: CGFloat = 1148

    static var pilL: CGFloat { pilCropW * K }      // 364,8
    static var pilH: CGFloat { pilCropH * K }      // 279,2
    static var pilTop: CGFloat { pilCropY * K }    // 171,2 — depuis le haut de la card
    static var braL: CGFloat { canevasW * K }      // 401,9
    static var braH: CGFloat { braCropH * K }      // 330,5 — collée à l'arête basse

    /// Le centre de la pilule, mesuré : lignes 480..1182 du canevas, soit
    /// 178,7..440,0 pt une fois posé. C'est l'ancre de son échelle et de ses
    /// rotations — jamais le centre du cadre, qui est 128 pt plus bas.
    static let centrePilule: CGFloat = 309
    /// La bande de braise : lignes 1480..2347, soit 323 pt. Invariable.
    static let hauteurBraise: CGFloat = 323

    private var d: CGFloat { DepartCine.chutePilule(e) }
    private var k: CGFloat { DepartCine.zoomPilule(e) }
    /// L'ancre de l'échelle et des rotations : le centre de la pilule DANS SON
    /// CALQUE ROGNÉ, pas dans le canevas. 309 − 171,2 = 137,8 sur 279,2.
    private var ancre: UnitPoint {
        UnitPoint(x: 0.5,
                  y: Double((Self.centrePilule - Self.pilTop) / Self.pilH))
    }

    var body: some View {
        // ⚠️ **`Color.clear` EN HÔTE, ET C'EST UN PIÈGE DÉJÀ PAYÉ ICI** (voir
        // « la fente detail gonfle son hôte »). Un `ZStack` prend la taille de
        // son plus grand enfant : mes deux calques font 864 pt de HAUT FIXE,
        // donc le ZStack faisait 864 dans une card qui n'en propose que 708 —
        // et l'`overlay` de `GrandeCardVideo` le CENTRAIT. Mesuré : la braise
        // débordait de 78 pt SOUS l'arête de la card, le slider tombait dedans,
        // et la levée avait beau valoir 156 (vérifié à l'écran au banc
        // `-cotes`), rien ne bougeait. `Color.clear` accepte la proposition
        // telle quelle : l'hôte fait exactement la taille de la card, et les
        // calques débordent DEDANS, où le clip les attend.
        Color.clear
            // ① LA BRAISE — collée par son arête basse à l'arête de la card.
            // Elle ne bouge pas d'un pixel : elle EST le bas de la card.
            .overlay(alignment: .bottom) {
                // LA HOME DORT (jalon 1 de la route en arbre) : sous la route,
                // le lecteur cède la place à sa POSE — pas un rate 0 (ce
                // lecteur l'ignore par trois chemins, et le réveil flushe la
                // couche) : l'image, montée à la place du calque. Au réveil le
                // lecteur renaît derrière sa pose, comme à l'arrivée.
                if poseSeule {
                    Image("home-fond-flamme-poster")
                        .resizable().scaledToFill()
                        .frame(width: Self.braL, height: Self.braH)
                        .clipped()
                } else {
                    CalqueVideo(nom: "home-fond-flamme",
                                pose: "home-fond-flamme-poster",
                                rate: PlayerEtat.shared.couvre ? 0 : 1)
                        .frame(width: Self.braL, height: Self.braH)
                }
            }
            // ② LE FOYER — la braise REÇOIT, sans bouger. Un foyer LOCAL, pas un
            // lift global : mesuré, la zone chaude varie de ×3 d'une image à
            // l'autre (écart-type 20 %), donc une rampe globale se noierait dans
            // le bruit du feu. L'œil, lui, détecte une structure spatialement
            // corrélée bien en dessous de ce seuil.
            // ⚠️ La couleur est le RATIO DE CANAUX MESURÉ DU LIT (1 : 0,272 :
            // 0,015). Ajouter du lit à du lit ne change ni teinte ni saturation :
            // la loi anti-brun est satisfaite par CONSTRUCTION, pas par
            // précaution. (Un orange « de goût » à 1 : 0,42 : 0,13 désature le
            // feu — et une saturation qui baisse, c'est du brun.)
            .overlay { lueur.blendMode(.plusLighter) }

            // ④ LA PILULE — ancrée par son arête HAUTE au haut de la card, donc
            // la levée du tiroir ne la déplace plus jamais.
            // ⚠️ ORDRE : scaleEffect PUIS offset. L'inverse (S·T) multiplierait
            // le déplacement par k, soit 62 pt de course parasite.
            .overlay(alignment: .top) {
                Group {
                    if poseSeule {
                        Image("home-fond-pilule-poster")
                            .resizable().scaledToFill()
                            .frame(width: Self.pilL, height: Self.pilH)
                            .clipped()
                    } else {
                        CalqueVideo(nom: "home-fond-pilule",
                                    pose: "home-fond-pilule-poster",
                                    rate: PlayerEtat.shared.couvre ? 0 : DepartCine.rate(e))
                            .frame(width: Self.pilL, height: Self.pilH)
                    }
                }
                    .opacity(pilule)
                    // Le calque est rogné : il se repose à SA place dans la card.
                    .padding(.top, Self.pilTop)
                    .rotation3DEffect(.degrees(DepartCine.roulisX(e)),
                                      axis: (x: 1, y: 0, z: 0),
                                      anchor: ancre, perspective: 0.5)
                    .rotation3DEffect(.degrees(DepartCine.roulisY(e)),
                                      axis: (x: 0, y: 1, z: 0),
                                      anchor: ancre, perspective: 0.5)
                    .scaleEffect(k, anchor: ancre)
                    .offset(y: d)
                    .blendMode(.plusLighter)
            }
            // ⚠️ **UN SEUL GROUPE, ET IL ARRIVE EN DERNIER.** Posé sur la seule
            // pilule, elle s'isolerait et fusionnerait contre le NOIR de la
            // card : additif sur noir = identité, le foyer sortirait du calcul
            // et la pilule OCCULTERAIT la braise au lieu de s'y fondre — le tout
            // sans une seule erreur de compilation. C'est aussi pour ça que la
            // braise, le foyer et la pilule sont trois `overlay` du MÊME hôte et
            // pas une sous-vue groupée : ils doivent se composer entre eux.
            .compositingGroup()
            // ⑤ LE SCRIM — il protégeait la phrase du dôme. Il sort du fichier
            // vidéo (cuit dans la pilule il VOYAGERAIT avec elle et noircirait la
            // braise à l'arrivée) et s'éteint quand la pilule a quitté le haut.
            .overlay(alignment: .top) {
                Image("home-fond-scrim")
                    .resizable()
                    .frame(width: Self.largeur, height: Self.hauteur)
                    .allowsHitTesting(false)
                    .opacity(1 - DepartCine.sstep(0.10, 0.90, e))
                    .allowsHitTesting(false)
            }
    }

    /// Le foyer et sa portée. Le centre suit la pilule ; le rayon vertical
    /// grandit — ce n'est pas la braise qui monte, c'est la ZONE qu'elle
    /// éclaire. Un feu qui prend éclaire plus haut, il ne se déplace pas.
    private var lueur: some View {
        let f = DepartCine.foyer(e)
        let y = Self.centrePilule + d
        return GeometryReader { g in
            ZStack {
                // LA PORTÉE — l'atmosphère du feu, et c'est ELLE qui répond au
                // trou noir du haut. ⚠️ Mesuré sur la première capture de la
                // scène : **87 % des pixels du haut de la card (10..420 pt)
                // étaient sous 8/255.** Un objet qui descend de 284 pt dans un
                // cadre de 708 VIDE forcément le haut — c'est arithmétique, on
                // ne le remplit pas avec un autre objet, on l'éclaire.
                // Ce n'est pas la braise qui monte : c'est la zone qu'elle
                // éclaire. Un feu qui prend éclaire plus haut, il ne se déplace
                // pas d'un pixel.
                LinearGradient(
                    stops: [.init(color: .clear, location: 0.00),
                            .init(color: Feu.lit.opacity(0.020 * f), location: 0.34),
                            .init(color: Feu.lit.opacity(0.075 * f), location: 0.72),
                            .init(color: Feu.lit.opacity(0.115 * f), location: 1.00)],
                    startPoint: .top, endPoint: .bottom)
                    .allowsHitTesting(false)
                // LE FOYER — local, et il SUIT l'objet. Un lift global se
                // noierait : mesuré, la luminance de la zone chaude varie de ×3
                // d'une image à l'autre (écart-type 20 %). L'œil, lui, détecte
                // une structure spatialement corrélée bien sous ce seuil.
                EllipticalGradient(
                    colors: [Feu.lit.opacity(0.16 * f), .clear],
                    center: .center, endRadiusFraction: 0.5)
                    .frame(width: 520, height: 300 + 210 * CGFloat(f))
                    .position(x: g.size.width / 2,
                              y: min(y + 36, g.size.height - 28))
                    .allowsHitTesting(false)
            }
            .opacity(f)
            // ⚠️⚠️ **L'OCCLUSION DE CONTACT EST MORTE, ET ELLE N'AURAIT JAMAIS DÛ
            // NAÎTRE.** Elle a coûté deux verdicts (« on voit une sorte de calque
            // léger noir derrière le texte », puis « il y a toujours le
            // calque »). Voici les trois raisons, dans l'ordre où elles auraient
            // dû me suffire :
            //
            //  1. SA GÉOMÉTRIE ÉTAIT FAUSSE, et c'est arithmétique. C'était un
            //     `RadialGradient(.black.opacity(0.38) → .white, endRadius: 150)`
            //     dans un cadre de 304 × 124, en `multiply`. Le facteur appliqué
            //     au fond valait ×0,62 au centre, **×0,63 au bord haut/bas du
            //     cadre** (r = 62), et ×1,00 seulement à r = 150 — c'est-à-dire
            //     HORS du cadre. Le fond était donc encore assombri de 37 % au
            //     bord, puis intact d'un coup : on ne voyait pas une ellipse
            //     douce, on voyait **un rectangle**.
            //  2. Mon premier correctif (`.clear` → `.white`) était juste mais
            //     insuffisant : il a supprimé l'assombrissement UNIFORME hors du
            //     dégradé, pas la marche au bord du cadre.
            //  3. **La lumière vient d'EN BAS.** Un objet au-dessus d'une source
            //     ne projette rien sur elle. Je l'avais écrit ici même avant de
            //     l'ajouter quand même.
            //
            // LA LOI, générale : un blend ne se raisonne pas en « invisible », il
            // se raisonne en ÉLÉMENT NEUTRE — le blanc opaque pour `multiply` —
            // et cet élément neutre doit être atteint AVANT le bord du cadre.
        }
    }
}


/// `-fondPose` : les deux calques vidéo de la home rendent leur image de
/// pose au lieu de tourner. Le seul but est de MESURER ce qu'ils coûtent.
enum FondPoseBanc {
    static let actif = CommandLine.arguments.contains("-fondPose")
}
