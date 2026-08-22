import AVFoundation
import SwiftUI
import UIKit

// MARK: - La page BRAVO (`-bravoLab`)
//
// La série est finie. La caméra est COLLÉE à la pièce qui tombe, puis elle
// recule de 3,9× et découvre toute la scène — la pluie de pièces au complet.
// Une fois posée, la lune RESPIRE en boucle, et la page se referme dessous
// sur deux cartes de saisie et deux gestes.
//
// TOUT CE QUI SUIT EST MESURÉ SUR LE FICHIER. Rien n'est choisi au goût.
//
// LES TROIS ACTES DE LA SOURCE
//   chute   0,00 → 2,90 s : le barycentre lumineux descend de 0,057 à 0,388,
//           en u² EXACT (c'est une chute libre : cy = 0,057 + 0,330·u²), et le
//           delta inter-image culmine à 0,0244.
//   rebond  2,90 → 4,00 s : le delta s'effondre à 0,0049, le mouvement meurt.
//   veille  4,00 → 8,04 s : delta 0,0016, mais la luminance MONTE de 0,026 à
//           0,049 — la pièce s'illumine jusqu'à la dernière image.
//
// LE DÉBIT N'EST PAS UN GOÛT. Source à 24 img/s exactement : au débit k
// l'écran affiche 60/24/k rafraîchissements par image à 60 Hz et 120/24/k à
// 120 — entier des deux côtés SEULEMENT pour 1,25 et 2,5. Le débit 1,0 bat
// lui-même en 3:2 à 60 Hz : LE REPOS EST 1,25, PAS 1,0. Et `rate` n'est pas
// animable (chaque écriture est une discontinuité du CMTimebase) : UN SEUL
// palier 2,5 → 1,25, posé sur le rebond, là où la scène décélère d'elle-même.
// `play()` étant littéralement `rate = 1.0`, le débit se pose APRÈS lui.
//
// LE CADRAGE : 3,90 → 1,00.
//   • 3,90 est le PLANCHER du gros plan : en dessous, l'image (16:9) ne couvre
//     plus la hauteur de l'écran et son bord haut — mesuré à 250/255, la pièce
//     y entre tranchée — traverserait la page en ligne claire. À 3,90 l'image
//     fait 862 pt pour 852 d'écran : elle couvre, tout juste.
//   • 1,00 est le SEUL cadrage qui montre toute la scène : les satellites
//     s'étalent de x 0,078 à 0,923, et dès l'échelle 1,25 la ligne de coupe
//     tombe en plein sur l'un d'eux (mesuré 251/255 — une couture franche).
//     Entre 1,00 et 2,15 il n'y a RIEN d'utilisable.
//   • Le créneau de repos vaut EXACTEMENT la hauteur de l'image à 1,00
//     (W·9/16 = 221 pt, 26 % de la page) : c'est la condition pour que le
//     fondu de bords serve à quelque chose — dans un cadre plus haut, l'image
//     ne touche plus ses bords et le masque ne fond que du noir.
//
// LE MASQUE VIENT APRÈS L'ÉCHELLE, ET IL EST CALÉ SUR L'ÉCRAN. La page du
// trésor masque AVANT de zoomer : SwiftUI compose alors dans un tampon à la
// taille non zoomée et n'agrandit QUE CE TAMPON — le « zoom rastérisé,
// exactement le cheap ». Et un fondu calé sur l'IMAGE sort du champ dès
// l'échelle 1,1 : il ne masque plus rien.
//
// LA SOURCE EST EN 1080p, ET ELLE LE RESTE. Le master embarqué est
// suréchantillonné HORS LIGNE en Lanczos vers 2160p : le GPU ne fait plus une
// magnification bilinéaire de 2,6× au gros plan, il échantillonne un master
// deux fois plus dense. Mesuré au cadrage du gros plan : +14 % d'acutance
// moyenne, +23 % au p99, pour 0,8 Mo de plus. Ça ne crée pas de détail —
// ça cesse d'en détruire.
//
// LA BOUCLE EST LÉGÈRE, ET C'EST MESURÉ. Elle ne joue QU'À l'échelle 1,00,
// où 1 179 px d'écran sont nourris par 1 920 px de source : le 2160p n'y sert
// à RIEN, et il coûtait cher — mesuré à l'écran, 26,8 img/s effectives pour
// 30 attendues, avec jusqu'à trois images répétées d'affilée. Le 2160p reste
// pour la cinématique (jouée une fois, puis démontée) ; la boucle, qui tourne
// à l'infini sous la page, est un H.264 1080p de 1,0 Mo au lieu de 3,4.
//
// LA BOUCLE EST UN VA-ET-VIENT, ET C'EST OBLIGATOIRE. La luminance monte sans
// arrêt de 5 à 8 s (0,0310 → 0,0494) : reboucler 8 → 5 ferait chuter la
// lumière de 37 % en une image, un clignotement toutes les 2,4 s. Et aucune
// fenêtre ne referme la boucle (la montée est monotone : la meilleure laisse
// encore 3,3 % d'écart). Le fichier de boucle est donc [5→8] suivi de [8→5 à
// l'envers] : il COMMENCE et FINIT sur l'image du RELAIS, mesurée à 0,0309 des
// deux côtés contre 0,0307 côté cinématique — saut nul au bouclage ET au
// raccord. La lune respire au lieu de battre.
enum BravoCine {
    /// Les deux seuls débits propres à 60 comme à 120 Hz.
    static let rateFast: Float = 2.5
    static let rateSlow: Float = 1.25
    /// La chute, en temps SOURCE.
    static let fallSrc: Double = 2.90
    /// LE RELAIS : image 120 (5,00 s), et c'est la PREMIÈRE image du fichier
    /// de boucle — vérifié, 0,0307 contre 0,0309.
    ///
    /// Il était à l'image 191 (7,958 s). La queue durait alors 4,05 s pendant
    /// lesquelles le delta inter-image de la source vaut 0,0016 à 0,0049 :
    /// QUATRE SECONDES OÙ RIEN NE BOUGE. C'était ça, « grave lente ». La queue
    /// tombe à 1,68 s et l'arrivée de 5,21 s à 2,84 s.
    /// On ne calcule jamais depuis `duration`.
    static let handoffFrame: Int64 = 120
    static var handoffSrc: Double { Double(handoffFrame) / 24.0 }

    /// La chute à l'écran : 1,16 s.
    static var fallScreen: Double { fallSrc / Double(rateFast) }
    /// Le recul du cadrage, qui part à la seconde où la pièce touche.
    static let settleFor: Double = 1.50
    static var settledAt: Double { fallScreen + settleFor }
    // ---- LA DEUXIÈME CAMÉRA. Elle ne bouge NI la vidéo NI la pastille par
    // un `scaleEffect` : la vidéo lit la caméra dans la GÉOMÉTRIE DE SON CADRE
    // et la pastille dans les COORDONNÉES qu'on passe à son shader. Les deux
    // sont donc redessinées à la résolution de l'écran à chaque échelle —
    // jamais une image agrandie. C'est l'école du monolithe de la connexion.
    // Le reste de la page (textes, cartes, boutons) n'a pas besoin d'être
    // transformé : il naît APRÈS le recul, quand la caméra est déjà revenue.
    static let diveAt: Double = 2.66
    static let diveFor: Double = 0.46
    static let countAt: Double = 3.16
    static let countFor: Double = 1.25
    /// LE REZOOM SUR LA LUNE. Après la gerbe, la caméra ne recule pas tout de
    /// suite : elle VA CHERCHER le croissant, seul objet allumé de la page,
    /// et le tient un souffle. L'ancre GLISSE de la pastille vers la pièce —
    /// une caméra qui se rapproche recadre, elle ne se contente pas de grossir.
    static let moonAt: Double = 4.58
    static let moonFor: Double = 0.72
    static let camMoon: CGFloat = 5.20
    /// La place de la pièce dans la capsule, mesurée sur la référence :
    /// centre à 0,248 de la largeur, donc à −0,252 du centre.
    static let coinOffset: CGFloat = -0.252

    static let pullAt: Double = 5.68
    static let pullFor: Double = 1.05
    /// Le grossissement du plongeon. 2,40 et pas plus : au-delà, la pastille
    /// (rapport 2,71 mesuré sur la référence) devient plus large que l'écran.
    static let camDive: CGFloat = 2.40
    /// LE JAILLISSEMENT : à la seconde où le compte se ferme. La gerbe part
    /// donc AVANT le recul (4,41 contre 4,55) : les pièces sortent pendant que
    /// la caméra est encore au plus près, et elles retombent pendant qu'elle
    /// s'éloigne — c'est le recul qui les emporte, pas un fondu.
    static var burstAt: Double { countAt + countFor }
    /// Le contenu naît une fois la caméra revenue.
    static var contentAt: Double { pullAt + pullFor - 0.20 }

    /// LE POULS DU NÉON, reproduit à l'identique du shader de la pièce :
    /// même horloge (celle-là même qu'on avance avec `neonBoost`), même
    /// période, même amplitude. C'est ce qui garantit que la capsule bat AVEC
    /// sa lune et non à côté d'elle.
    static func neonPulse(_ e: Double, t: Double) -> Double {
        let tc = t + neonBoost(e)
        return 0.5 + 0.5 * sin(tc * 6.2832 * 180 / 900 + 1.7)
    }

    /// LE SOUFFLE DE LA PASTILLE au moment où ses lunes s'échappent : un halo
    /// clair naît DANS la capsule, à l'endroit exact d'où les pièces sortent,
    /// et retombe. Attaque en cinq images, extinction en 0,55 s — l'énergie
    /// qui part avec elles, pas un flash posé dessus.
    static func pillFlare(_ e: Double) -> Double {
        let x = e - burstAt
        guard x > 0 else { return 0 }
        return min(x / 0.085, 1) * exp(-max(x - 0.085, 0) / 0.55)
    }

    /// L'AVANCE D'HORLOGE DU CROISSANT. Le néon respire sur 5 s et son point
    /// chaud parcourt le tube en 3,5 s : sur un plongeon de 0,72 s on n'en
    /// voyait qu'un cinquième, donc rien du tout. L'horloge de la pièce prend
    /// donc 3,2 s d'avance par seconde pendant qu'on s'approche — elle vit
    /// quatre fois plus vite le temps qu'on la regarde, puis reprend son
    /// rythme, simplement décalée. Monotone et continu : jamais un saut.
    static func neonBoost(_ e: Double) -> Double {
        // EN PERMANENCE, PAS SEULEMENT AU PLONGEON. Au repos, la lune de la
        // pastille ne scintillait pas : son souffle fait ±18 % sur 5 s et son
        // point chaud parcourt le tube en 3,5 s — à cette échelle, sur un
        // objet de 16 pt, c'est indétectable. Son horloge court donc 3,6×
        // plus vite À DEMEURE (souffle de 1,4 s, point chaud de 1,0 s : un
        // tube de néon qui VIT), avec un supplément pendant qu'on l'approche.
        2.6 * max(e, 0) + 3.2 * min(max(e - moonAt, 0), 1.8)
    }

    /// Le glissement de l'ancre, de la pastille vers la lune.
    static func anchorMix(_ e: Double) -> CGFloat {
        CGFloat(sstep(moonAt, moonAt + moonFor, e))
    }

    /// La caméra : 1 → 2,40 (la pastille) → 5,20 (la lune) → 1. Chaque palier
    /// part et arrive à pente nulle : elle ne s'arrête jamais net.
    static func camZ(_ e: Double) -> CGFloat {
        let up = CGFloat(sstep(diveAt, diveAt + diveFor, e))
        let moon = CGFloat(sstep(moonAt, moonAt + moonFor, e))
        let down = CGFloat(sstep(pullAt, pullAt + pullFor, e))
        let z = 1 + (camDive - 1) * up + (camMoon - camDive) * moon
        return 1 + (z - 1) * (1 - down)
    }

    /// La pastille affleure pendant que la caméra plonge.
    static func pillIn(_ e: Double) -> Double {
        sstep(diveAt - 0.10, diveAt + 0.34, e)
    }

    /// Le compte. EaseOut : il part vite et s'assoit — un butin qu'on
    /// dénombre, pas un chronomètre qui défile.
    static func count(_ e: Double, to total: Int) -> Int {
        let u = min(max((e - countAt) / countFor, 0), 1)
        let eased = 1 - pow(1 - u, 2.2)
        return Int((Double(total) * eased).rounded())
    }
    /// Le relais, à l'écran : 5,21 s.
    static var handoffAt: Double {
        fallScreen + (handoffSrc - fallSrc) / Double(rateSlow)
    }

    static let zoomOpen: CGFloat = 3.90
    static let zoomRest: CGFloat = 1.00
    /// Le flou du gros plan — il se résorbe avec le recul. Ce n'est pas une
    /// rustine de résolution : c'est la mise au point qui se fait, et c'est
    /// l'école du plongeon de la connexion (le flou couvre la trame avant
    /// qu'elle ne se voie).
    static let blurOpen: CGFloat = 8.0

    static func sstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let u = min(max((x - a) / (b - a), 0), 1)
        return u * u * (3 - 2 * u)
    }

    /// Le recul, 0 → 1. Départ à pente nulle, arrivée à pente nulle : la
    /// caméra ne s'arrête jamais net.
    static func pull(_ e: Double) -> Double {
        sstep(fallScreen, settledAt, e)
    }

    static func zoom(_ e: Double) -> CGFloat {
        // Exponentielle, comme le plongeon : à échelle constante par seconde,
        // le recul se SENT linéaire à l'œil.
        zoomOpen * pow(zoomRest / zoomOpen, CGFloat(pull(e)))
    }

    static func blur(_ e: Double) -> CGFloat {
        blurOpen * (1 - CGFloat(sstep(0.10, 0.85, pull(e))))
    }
}

// MARK: - La page

struct BravoView: View {
    var reps: Int = 12
    /// En `Double` comme partout dans le modèle (`DraftSet.weight`) : le jour
    /// où la molette gagne des demi-kilos, la page les affiche déjà.
    var kilos: Double = 20
    /// Le repos réellement choisi dans la feuille — le troisième constat.
    var rest: Int = 60
    var onStartTimer: (Int, Int) -> Void = { _, _ in }
    var onFinish: () -> Void = {}

    @State private var cine: AVPlayer?
    @State private var loop: AVQueuePlayer?
    @State private var looper: AVPlayerLooper?
    @State private var onLoop = false
    @State private var visible = false
    @State private var startedAt = Date()
    @State private var handoffObserver: Any?
    @State private var loopReady: NSKeyValueObservation?
    /// LE FILET SOUS LE TRAPÈZE. `AVPlayerLooper` change d'item à chaque
    /// bouclage, et la couche vidéo se VIDE le temps d'une à trois images —
    /// mesuré sur 25 s d'enregistrement : deux trous à luminance 0,0000
    /// exactement, espacés d'une période de boucle. Comme le fichier commence
    /// et finit sur la MÊME image, il suffit de poser cette image dessous et
    /// de rendre l'hôte du lecteur transparent : le trou se remplit tout seul
    /// avec ce qu'on devait y voir. Aucune synchronisation, aucun fondu.
    @State private var loopFirstFrame: UIImage?
    /// LE TAS AU SOL, en vidéo. Ce que j'avais tenté de fabriquer en shader —
    /// et que Kathryn a refusé deux fois — existe en rendu 3D : un tas de
    /// pièces posé sur un sol sombre, sous une colonne de lumière. Il comble
    /// exactement le vide du bas de page, et il le comble PAR LE SUJET.
    @State private var floor: AVQueuePlayer?
    @State private var floorLooper: AVPlayerLooper?
    @State private var floorFrame: UIImage?
    /// La partition est finie : plus rien ne bouge côté SwiftUI. On ARRÊTE
    /// l'horloge — sans quoi la page recalcule la géométrie de la vidéo et
    /// repasse son masque, son rognage et son flou SOIXANTE FOIS PAR SECONDE
    /// pour rien, et c'est ça qui mangeait la cadence (mesuré : 25 img/s
    /// effectives pour 30 attendues, jusqu'à 6 images répétées d'affilée —
    /// le codec n'y était pour rien, passer la boucle de 2160p à 1080p n'avait
    /// rien changé). La vidéo, elle, continue toute seule : elle vit dans
    /// CoreAnimation, pas dans la passe SwiftUI.
    @State private var settled = false

    /// LE TOUCHER DE LA PASTILLE : une fumée d'or sombre s'en échappe et
    /// quelques petites pièces sautent. Rien ne change d'état — c'est une
    /// RÉPONSE, pas un mode.
    @State private var tapAt: Date?
    @State private var tapEnd: Date?
    @State private var tapTick = 0
    @State private var repsValue = 12
    @State private var kilosValue: Double = 20

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private static let skipCine = CommandLine.arguments.contains("-bravoFreeze")

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = geo.size.height
            // Le créneau de repos vaut EXACTEMENT la hauteur de l'image à
            // l'échelle 1 : l'image touche ses bords, donc le fondu a de la
            // matière à éteindre.
            // LE CRÉNEAU RESPIRE. Les deux cartes de saisie sont parties : la
            // vidéo peut prendre 330 pt au lieu de 221. L'IMAGE, elle, reste à
            // l'échelle 1,00 — c'est le seul cadrage qui montre toute la scène,
            // et dès 1,25 la ligne de coupe tombe sur un satellite (251/255,
            // mesuré). Les 109 pt de plus sont donc de la NUIT autour d'elle,
            // invisible sur OLED, et c'est ce qui donne son air à la page.
            // LA SOURCE EST RECADRÉE À 92 % DE SA LARGEUR, et c'est mesuré :
            // sur cette ligne de coupe, la luminance vaut 0 et le gradient 0
            // à TOUTES les images — on tranche dans du noir absolu. À 86 % on
            // entamait déjà un satellite (164/255, gradient 126). Le rapport
            // passe de 16:9 à 1766:1080, donc l'image gagne 9 % de hauteur
            // sans qu'une seule pièce soit coupée. C'est tout ce que la source
            // peut donner : agrandir DAVANTAGE demande un rendu en portrait.
            let imgH = W * 1080.0 / 1766.0
            // Le créneau colle à l'image : elle touche ses bords, donc le
            // fondu a de la matière à éteindre (la leçon du trésor).
            let slotRest = imgH
            // L'horloge se rendort une fois la page posée (voir `settled`) —
            // MAIS PAS SOUS LE DOIGT. Figée, `tl.date` ne bouge plus : la
            // gerbe du toucher sortait sur son `guard age > 0` et le souffle
            // de la pastille sur le sien, si bien que taper la page posée ne
            // donnait plus que la fumée — seule à porter sa propre horloge.
            TimelineView(.animation(minimumInterval: 1.0 / 60.0,
                                    paused: reduceMotion
                                        || (settled && tapAt == nil))) { tl in
                let e = clock(tl.date)
                let z = BravoCine.zoom(e)
                let slot = H + (slotRest - H) * CGFloat(BravoCine.pull(e))
                let bornU = BravoCine.sstep(BravoCine.contentAt,
                                            BravoCine.contentAt + 0.70, e)
                // LE POINT D'ANCRAGE de la deuxième caméra : le centre de la
                // pastille au repos. Tout se dilate autour de LUI, donc la
                // pastille ne bouge pas d'un pixel pendant qu'on plonge — c'est
                // la caméra qui vient à elle.
                let tPage = tl.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 900)
                let cam = BravoCine.camZ(e)
                let pillW = 54 * BravoPillView.ratio
                // LE CENTRE OPTIQUE. Les cartes parties, le bloc (pastille +
                // textes + échappée) ne fait plus que 206 pt : collé sous la
                // vidéo il laissait 40 % de la page vide en bas. Il respire
                // donc dans TOUT ce qui reste, et se pose un peu AU-DESSUS du
                // milieu — centré au cordeau, l'œil le trouve trop bas
                // (la leçon de la page du trésor).
                // TOUT REMONTE. Le bloc se posait à 42 % de l'espace libre —
                // il restait un trou entre la vidéo et la pastille, et un
                // autre sous les chiffres. À 0,17 la page se resserre vers le
                // haut et la nuit se rassemble EN BAS, d'un seul tenant,
                // là où le lien l'occupe.
                let blockH: CGFloat = 234
                let gap = max((H - slotRest - blockH) * 0.17, 16)
                let aY = slotRest + gap + 27
                // L'ANCRE GLISSE de la pastille vers la lune pendant le rezoom.
                let aX = W / 2 + pillW * BravoCine.coinOffset
                    * BravoCine.anchorMix(e)
                let anchor = CGPoint(x: aX, y: aY)
                ZStack(alignment: .top) {
                    Color.black.ignoresSafeArea()
                    cinema(W: W, slot: slot, zoom: z,
                           blur: BravoCine.blur(e), cam: cam)
                        .offset(x: (anchor.x - W / 2) * (1 - cam),
                                y: anchor.y * (1 - cam))
                    BravoPillView(center: CGPoint(
                                    x: anchor.x + (W / 2 - anchor.x) * cam,
                                    y: aY),
                                  height: 54 * cam,
                                  amount: BravoCine.pillIn(e),
                                  count: BravoCine.count(e, to: 50),
                                  cam: cam,
                                  neonBoost: BravoCine.neonBoost(e),
                                  flare: max(BravoCine.pillFlare(e),
                                             tapFlare(tl.date)),
                                  // Le pouls est calculé DANS la pastille, sur
                                  // sa propre horloge : elle continue de battre
                                  // quand celle de la page s'est arrêtée.
                                  pulse: 0)
                        .contentShape(Rectangle())
                        .onTapGesture { fireTap() }
                    // La poignée du toucher : moins nombreuses, plus petites,
                    // et elles ne montent pas aussi haut.
                    if let tapAt {
                        CoinField(source: CGPoint(x: W / 2, y: aY),
                                  anchor: anchor, cam: cam,
                                  age: tl.date.timeIntervalSince(tapAt),
                                  clock: tPage, ground: H + 420, width: W,
                                  count: 7, sizeMin: 6.5, sizeSpan: 3.5,
                                  lift: 0.62)
                        CoinSmoke(center: CGPoint(
                                    x: anchor.x + (W / 2 - anchor.x) * cam,
                                    y: aY),
                                  // LA POSITION suit la caméra en plein, la
                                  // PORTÉE est plafonnée. L'hôte de la fumée
                                  // vaut `rayon × 2 + 132` et son shader tire
                                  // trois fBm à quatre octaves PAR PIXEL : à
                                  // `cam` 5,20 le rayon montait à 95 pt, donc
                                  // un hôte de 323 pt de côté — une falaise de
                                  // surface qui tombe pile sur la fenêtre la
                                  // plus chargée de la page. Au-delà de 2, la
                                  // fumée d'un doigt n'a plus rien à gagner.
                                  radius: 54 * min(cam, 2.0) * 0.34,
                                  start: tapAt, end: tapEnd, palette: .dark)
                            .allowsHitTesting(false)
                    }
                    CoinField(source: CGPoint(x: W / 2, y: aY),
                              anchor: anchor, cam: cam,
                              age: e - BravoCine.burstAt,
                              clock: tl.date.timeIntervalSinceReferenceDate
                                  .truncatingRemainder(dividingBy: 900),
                              // LE SOL, ENTRE DEUX ÉCUEILS. À 58 pt du bas le
                              // tas était collé au footer, coupé par le bord
                              // et mêlé au bouton de rejeu : « moche ». À 168
                              // il montait SUR le lien « Revenir à l'exercice ».
                              // À 118 il se pose dans la nuit du bas, sous le
                              // texte et au-dessus du bord — son propre plan.
                              // Le « sol » est HORS ÉCRAN : les pièces ne se
                              // posent plus, elles sortent du champ.
                              ground: H + 420,
                              width: W)
                    VStack(spacing: 0) {
                        Color.clear.frame(height: slotRest + gap + 54 + 20)
                        content(e)
                        Spacer(minLength: 0)
                        footerLink
                            .opacity(rise(0.47, e))
                            // UNE OPACITÉ NULLE N'EST PAS SOURDE AU DOIGT.
                            // Ce lien est le dernier enfant du ZStack, donc
                            // AU-DESSUS de la vidéo — et la vidéo est en
                            // `allowsHitTesting(false)`, elle laisse tout
                            // passer. Une bande invisible de 44 pt vivait
                            // donc sous l'image pendant toute la cérémonie,
                            // et son action DÉMONTE la page.
                            .allowsHitTesting(rise(0.47, e) > 0.5)
                        // LE SOL, tout en bas. Il naît en dernier, après les
                        // chiffres et l'échappée : la page se referme dessus.
                        floorVideo(W: W)
                            .opacity(rise(0.56, e))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)
        .background(Color.black)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.7),
                         trigger: tapTick)
        .onAppear {
            CoinChime.shared.prepare()
            start()
        }
        .onDisappear(perform: teardown)
    }

    /// L'horloge de la partition — fonction pure du temps, l'école de
    /// ConnexionCine : aucune animation SwiftUI ne pilote la caméra.
    private func clock(_ now: Date) -> Double {
        if Self.skipCine || reduceMotion { return 99 }
        return now.timeIntervalSince(startedAt)
    }

    // MARK: Le cinéma

    /// L'ordre des modificateurs EST le sujet : l'image prend sa taille
    /// zoomée, le créneau la ROGNE, et le fondu ne s'applique qu'ensuite —
    /// donc à la résolution de l'écran, sur des bords fixes.
    private func cinema(W: CGFloat, slot: CGFloat, zoom: CGFloat,
                        blur: CGFloat, cam: CGFloat) -> some View {
        // La caméra entre ICI, dans la GÉOMÉTRIE — pas dans un `scaleEffect`.
        // L'AVPlayerLayer reçoit de nouvelles bornes et redécode à la bonne
        // taille : le grossissement est sans perte.
        let vw = W * zoom * cam
        let vh = vw * 1080.0 / 1766.0
        return ZStack {
            Color.black
            ZStack {
                // Le filet : la première image de la boucle, posée SOUS les
                // lecteurs. On ne la voit jamais — sauf pendant les une à
                // trois images où la boucle change d'item.
                if let loopFirstFrame, onLoop {
                    Image(uiImage: loopFirstFrame).resizable()
                }
                if let cine {
                    CinematicPlayer(player: cine).opacity(onLoop ? 0 : 1)
                }
                if let loop {
                    CinematicPlayer(player: loop, opaqueBackground: false)
                        .opacity(onLoop ? 1 : 0)
                }
            }
            .frame(width: vw, height: vh)
            // Un flou de rayon nul reste une PASSE HORS ÉCRAN : on le démonte
            // dès qu'il ne peint plus rien.
            .modifier(SoftBlur(radius: blur))
        }
        .frame(width: W * cam, height: max(slot * cam, 1))
        .clipped()
        .mask(edgeFade)
        .opacity(visible ? 1 : 0)
        .allowsHitTesting(false)
    }

    /// LE TAS AU SOL. La source est PORTRAIT (2160 × 3836) et son sujet ne
    /// vit que dans les 18 % du bas : on n'en garde que les 24 % inférieurs,
    /// et la coupe tombe dans une bande mesurée à 2,8/255 — du noir, donc
    /// invisible. À 393 pt de large elle fait 168 pt : un vrai footer.
    /// 2 160 px de source pour 1 179 à l'écran : on DÉCIME, aucun étirement.
    ///
    /// Comme celle du header, elle NE BOUCLE PAS : sa lumière monte de 355 %
    /// du début à la fin. Le fichier embarqué est donc un VA-ET-VIENT — il
    /// commence et finit sur la même image (0,0065 contre 0,0067, mesuré) —,
    /// et le même filet est posé dessous : à chaque changement d'item,
    /// `AVPlayerLooper` vide la couche pendant une à trois images.
    @ViewBuilder
    private func floorVideo(W: CGFloat) -> some View {
        let h = W * 502.0 / 1180.0
        ZStack {
            if let floorFrame {
                Image(uiImage: floorFrame).resizable()
            }
            if let floor {
                CinematicPlayer(player: floor, opaqueBackground: false)
            }
        }
        .frame(width: W, height: h)
        .clipped()
        // Le haut de la coupe s'éteint sur 9 % : la bande y est déjà à
        // 2,8/255, ce fondu ne fait que garantir qu'aucune arête ne se lise.
        .mask(LinearGradient(stops: [
            .init(color: .clear, location: 0.0),
            .init(color: .black, location: 0.09),
            .init(color: .black, location: 1.0)
        ], startPoint: .top, endPoint: .bottom))
        .allowsHitTesting(false)
    }

    /// Le fondu de bords, en espace ÉCRAN. Le haut est le seul bord chargé :
    /// à l'échelle 1 un satellite touche l'arête de la source (mesuré 58/255)
    /// et pendant la chute cette arête monte à 250. Les flancs ne portent que
    /// du bokeh, le bas est mesuré à 4.
    private var edgeFade: some View {
        LinearGradient(stops: [
            .init(color: .clear, location: 0.0),
            .init(color: .black, location: 0.070),
            .init(color: .black, location: 0.930),
            .init(color: .clear, location: 1.0)
        ], startPoint: .leading, endPoint: .trailing)
        .mask(
            LinearGradient(stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .black, location: 0.080),
                .init(color: .black, location: 0.950),
                .init(color: .clear, location: 1.0)
            ], startPoint: .top, endPoint: .bottom)
        )
    }

    // MARK: Le texte, les cartes, les deux gestes

    /// LE BLOC DU MILIEU : le titre, la ligne, et les trois chiffres de la
    /// série. Le lien, lui, ne vit PLUS ici — il est épinglé au footer, où il
    /// était bien : une échappée se pose au bord de la page, pas au milieu
    /// d'une composition.
    /// Chaque ligne arrive à SON tour. Un bloc qui monte d'un seul morceau
    /// est un calque qu'on déplace ; échelonné, c'est une page qui s'écrit.
    /// Les écarts (0,00 / 0,13 / 0,26 / 0,33 / 0,40) sont assez courts pour
    /// qu'on ne les compte pas, assez longs pour qu'on les sente.
    private func rise(_ d: Double, _ e: Double) -> Double {
        BravoCine.sstep(BravoCine.contentAt + d,
                        BravoCine.contentAt + d + 0.62, e)
    }

    private func content(_ e: Double) -> some View {
        VStack(spacing: 0) {
            Text("Bravo")
                .font(.inter(30, .semibold))
                .tracking(-0.3)
                .foregroundStyle(WoopGradient.silverText)
                .opacity(rise(0, e))
                .offset(y: (1 - rise(0, e)) * 16)

            Text("Your set is complete.")
                .font(.inter(14))
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 9)
                .padding(.horizontal, 20)
                .opacity(rise(0.13, e))
                .offset(y: (1 - rise(0.13, e)) * 14)

            kpis(e).padding(.top, 30)

            // LE GAIN — l'économie tranchée : 20 pièces la série. BRAVO
            // annonce ce que le coffre comptera, avec la pièce gelée de
            // la maison (jamais une image).
            HStack(spacing: 6) {
                Text("+\(CoffreFortPurse.perSeries)")
                    .font(.inter(16, .semibold))
                    .foregroundStyle(Color.woopGold.opacity(0.92))
                    .monospacedDigit()
                MoonCoinView(coinR: 13, draggable: false, yawOverride: 0.34,
                             idleLife: 0, fps: 6, reveal: 0.34, matte: 1)
                    .frame(width: 13 * MoonCoinView.hostScale,
                           height: 13 * MoonCoinView.hostScale)
                    .frame(width: 28, height: 28)
                Text("coins earned")
                    .font(.inter(13))
                    .foregroundStyle(Color.inkSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
            .opacity(rise(0.46, e))
            .offset(y: (1 - rise(0.46, e)) * 14)
        }
        .frame(maxWidth: .infinity)
    }

    /// LES TROIS CHIFFRES DE LA SÉRIE. Pas des champs — ils ne se règlent
    /// plus —, des CONSTATS : ce qui a été fait. D'où le traitement d'un
    /// trophée et non d'un contrôle : le chiffre en dégradé plein (l'argent
    /// de la maison, celui du titre), l'unité en petites capitales espacées
    /// sous lui, et rien autour. Aucune carte, aucun trait, aucun fond : sur
    /// la nuit, trois colonnes d'encre suffisent — la séparation vient de
    /// l'espace, jamais d'un séparateur.
    private func kpis(_ e: Double) -> some View {
        // Les kilos entiers s'écrivent entiers (l'école de la molette) ; le
        // repos s'écrit comme le cadran l'a décompté.
        let kiloText = kilosValue == kilosValue.rounded()
            ? String(Int(kilosValue.rounded()))
            : String(format: "%.1f", kilosValue)
        return HStack(spacing: 0) {
            kpi("\(repsValue)", "REPS", 0.26, e)
            kpi(kiloText, "KG", 0.33, e)
            kpi(String(format: "%d:%02d", rest / 60, rest % 60),
                "REST", 0.40, e)
        }
        .padding(.horizontal, 26)
    }

    private func kpi(_ value: String, _ unit: String,
                     _ delay: Double, _ e: Double) -> some View {
        let u = rise(delay, e)
        return kpiBody(value, unit).opacity(u).offset(y: (1 - u) * 18)
    }

    private func kpiBody(_ value: String, _ unit: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(Font.custom("Inter-Light", size: 34).monospacedDigit())
                .tracking(0.5)
                .foregroundStyle(WoopGradient.silverText)
            Text(unit)
                .font(.inter(9.5, .semibold))
                .tracking(3.4)
                .foregroundStyle(Color.white.opacity(0.30))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    /// L'ÉCHAPPÉE, au footer — ni fond ni contour : sur la nuit, un cadre
    /// clair se lit comme un bug. C'est l'encre seule qui le dit.
    private var footerLink: some View {
        Button(action: onFinish) {
            Text("Back to exercise")
                .font(.inter(15, .medium))
                .foregroundStyle(Color.inkSecondary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: La mise en route

    private func start() {
        guard cine == nil else { return }
        repsValue = reps
        kilosValue = kilos
        startedAt = .now

        guard let url = Bundle.main.url(forResource: "piece-bravo",
                                        withExtension: "mp4") else {
            visible = true
            return
        }

        // LA BOUCLE, montée tout de suite mais muette : elle doit être prête
        // et à sa première image quand le relais tombe, sinon le raccord
        // montre une image noire.
        if let lurl = Bundle.main.url(forResource: "piece-bravo-loop",
                                      withExtension: "mp4") {
            let q = AVQueuePlayer()
            q.isMuted = true
            q.automaticallyWaitsToMinimizeStalling = false
            let item = AVPlayerItem(url: lurl)
            looper = AVPlayerLooper(player: q, templateItem: item)
            grabLoopFirstFrame(url: lurl)
            // LE PRÉCHARGEMENT. `preroll` amorce le pipeline de décodage SANS
            // avancer l'horloge : au relais, la première image est déjà prête
            // et la couche n'a pas une seule frame de noir à montrer. Il n'est
            // appelable qu'une fois l'item `.readyToPlay` — d'où l'observation.
            loopReady = q.observe(\.status, options: [.initial, .new]) { p, _ in
                guard p.status == .readyToPlay else { return }
                p.preroll(atRate: BravoCine.rateSlow) { _ in }
            }
            loop = q
        }

        // LE SOL : monté et amorcé comme la boucle du header.
        if let furl = Bundle.main.url(forResource: "piece-sol",
                                      withExtension: "mp4") {
            let q = AVQueuePlayer()
            q.isMuted = true
            q.automaticallyWaitsToMinimizeStalling = false
            floorLooper = AVPlayerLooper(player: q,
                                         templateItem: AVPlayerItem(url: furl))
            floor = q
            q.play()
            q.rate = BravoCine.rateSlow
            grabFirstFrame(url: furl) { floorFrame = $0 }
        }

        let p = AVPlayer(playerItem: AVPlayerItem(url: url))
        // La piste audio a été retirée à l'encodage ; le muet est une
        // ceinture — une cinématique ne coupe jamais la musique de personne.
        p.isMuted = true
        // À poser AVANT toute écriture de `rate`, sinon le débit est différé.
        p.automaticallyWaitsToMinimizeStalling = false
        p.actionAtItemEnd = .pause
        cine = p

        guard !Self.skipCine, !reduceMotion else {
            visible = true
            onLoop = true
            loop?.play()
            loop?.rate = BravoCine.rateSlow
            return
        }

        // LE RELAIS : la boucle démarre et on croise vers elle. Sa première
        // image EST l'image 191 de la cinématique — mêmes pixels, le fondu ne
        // peut pas se voir.
        handoffObserver = p.addBoundaryTimeObserver(
            forTimes: [NSValue(time: CMTime(value: BravoCine.handoffFrame,
                                            timescale: 24))],
            queue: .main) { [weak p] in
                loop?.play()
                loop?.rate = BravoCine.rateSlow
                // ÉCHANGE SEC, JAMAIS UN FONDU. Le fondu croisé de 0,30 s
                // était LE « flash noir » : pendant qu'il courait, la couche
                // entrante n'avait pas encore produit sa première image, donc
                // le composite se mélangeait à du NOIR — mesuré à l'écran,
                // 0,0497 → 0,0299 en 0,13 s, soit 60 %, exactement ce que
                // rend un mélange à mi-course contre du noir.
                // Les deux couches montrent la MÊME image (l'image 120), donc
                // un échange en une frame est invisible par construction. Les
                // 50 ms laissent au décodeur le temps de présenter la sienne ;
                // se tromper d'une image ne coûte rien, elles sont identiques.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    onLoop = true
                    p?.pause()
                }
                // ET ON LE DÉMONTE. La cinématique est un master 2160p HEVC :
                // le garder en mémoire après le relais, c'est laisser un
                // décodeur 4K vivant sous la page pour rien, à côté des deux
                // boucles. Une fois la boucle à l'écran, il n'a plus rien à
                // montrer — on le rend.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    if let ho = handoffObserver {
                        cine?.removeTimeObserver(ho)
                        handoffObserver = nil
                    }
                    cine?.replaceCurrentItem(with: nil)
                    cine = nil
                }
            }

        // `play()` d'abord, le débit ENSUITE : `play()` est littéralement
        // `rate = 1.0` et écraserait le 2,5.
        p.play()
        p.rate = BravoCine.rateFast
        withAnimation(.easeOut(duration: 0.40)) { visible = true }

        // L'HORLOGE DE LA PAGE S'ARRÊTE UNE FOIS TOUT POSÉ. Elle recalculait
        // la géométrie de la vidéo, repassait son masque, son rognage et son
        // flou, et réévaluait tout le champ de pièces SOIXANTE FOIS PAR
        // SECONDE alors que plus rien ne bouge — trois lecteurs vivants
        // par-dessus, et la page ramait. Ce qui doit continuer à vivre (l'or
        // de la pastille, le pouls de sa lune) a sa PROPRE horloge à 12 Hz,
        // dans le composant ; les deux vidéos, elles, vivent dans
        // CoreAnimation et n'ont jamais eu besoin de la passe SwiftUI.
        DispatchQueue.main.asyncAfter(
            deadline: .now() + BravoCine.contentAt + 2.6) { settled = true }

        // LE PALIER UNIQUE, sur le rebond : la scène décélère au même
        // instant, donc la loi « jamais un scale qui claque » est tenue par
        // la physique de l'image et non par une courbe.
        DispatchQueue.main.asyncAfter(deadline: .now() + BravoCine.fallScreen) {
            cine?.rate = BravoCine.rateSlow
        }
    }

    /// La première image du fichier de boucle, extraite une fois, à tolérance
    /// NULLE : on veut CETTE image-là, pas sa voisine.
    private func grabLoopFirstFrame(url: URL) {
        grabFirstFrame(url: url) { loopFirstFrame = $0 }
    }

    /// La première image d'un fichier, à tolérance NULLE : on veut CETTE
    /// image-là, pas sa voisine — c'est le filet qui bouche le trou du
    /// bouclage, il doit porter exactement ce qu'on devait voir.
    ///
    /// ET IL DOIT ABOUTIR — C'ÉTAIT ÇA, LES VOILES NOIRS. Cette extraction est
    /// lancée DEUX FOIS dans le même tour de boucle que le master 3532×2160
    /// joué à 2,5× : jusqu'à cinq clients de décodage réclamés au même
    /// instant. Sous cette bousculade, le générateur rend `nil` — et le
    /// `guard let image else { return }` nu qui vivait ici l'avalait en
    /// silence. Le filet restait alors nil POUR TOUTE LA VIE DE LA PAGE, et
    /// chaque changement d'item redevenait ce qu'il était avant qu'on pose le
    /// filet : le noir de la page à la place de l'image, toutes les 4,8 s en
    /// haut et 12,9 s en bas. Adouci par le fondu de bords, ça ne se lit pas
    /// comme une arête mais comme un VOILE.
    ///
    /// Et c'est ce qui explique « des fois » : cette course est le SEUL
    /// événement non déterministe de la page — tout le reste (l'horloge, le
    /// zoom, la caméra, le flou) est une fonction pure du temps mural. Deux
    /// ouvertures du même build ne donnent donc pas le même résultat.
    ///
    /// Le filet n'a pas de date limite serrée : il doit seulement être posé
    /// avant le PREMIER bouclage. On laisse donc passer la bousculade et on
    /// redemande, plutôt que d'abandonner à la première rebuffade.
    private func grabFirstFrame(url: URL, tries: Int = 3,
                                _ done: @escaping (UIImage) -> Void) {
        let gen = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        gen.appliesPreferredTrackTransform = true
        gen.requestedTimeToleranceBefore = .zero
        gen.requestedTimeToleranceAfter = .zero
        gen.generateCGImagesAsynchronously(
            forTimes: [NSValue(time: .zero)]) { _, image, _, _, error in
            guard let image else {
                guard tries > 1 else {
                    // On ne meurt plus muet : si le filet est vraiment perdu,
                    // la console le dit, et les voiles ont un nom.
                    print("[BRAVO] filet PERDU — \(url.lastPathComponent) : "
                          + String(describing: error))
                    return
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    grabFirstFrame(url: url, tries: tries - 1, done)
                }
                return
            }
            let ui = UIImage(cgImage: image)
            DispatchQueue.main.async { done(ui) }
        }
    }

    /// Le souffle du toucher : la même enveloppe que le jaillissement, en
    /// plus court — la pastille répond, elle ne rejoue pas la cérémonie.
    private func tapFlare(_ now: Date) -> Double {
        guard let tapAt else { return 0 }
        let x = now.timeIntervalSince(tapAt)
        guard x > 0 else { return 0 }
        return min(x / 0.07, 1) * exp(-max(x - 0.07, 0) / 0.34) * 0.72
    }

    /// Un tintement MINIMAL — le son de pièce déjà synthétisé de la maison,
    /// pas une fanfare — et une vibration souple. La fumée se démonte une
    /// fois éteinte pour rendre ses images.
    private func fireTap() {
        tapAt = .now
        tapEnd = nil
        tapTick += 1
        CoinChime.shared.chink()
        let mark = Date.now.addingTimeInterval(0.16)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { tapEnd = mark }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            if tapEnd == mark { tapAt = nil; tapEnd = nil }
        }
    }

    private func teardown() {
        if let handoffObserver { cine?.removeTimeObserver(handoffObserver) }
        handoffObserver = nil
        loopReady?.invalidate(); loopReady = nil
        cine?.pause(); cine = nil
        loop?.pause(); loop = nil
        looper = nil
        floor?.pause(); floor = nil
        floorLooper = nil
    }
}

// (Le `SoftBlur` privé qui vivait ici a rejoint la maison : `StoryVideo.swift`
// porte désormais le même, partagé — deux copies du même nom dans un module,
// et le compilateur tranche.)

// MARK: - La carte de saisie

/// Une carte de Liquid Glass, l'en-tête et son glyphe, un filet, puis les deux
/// facettes rondes et le nombre. TROIS gestes sur le même objet, et ils ne se
/// marchent pas dessus :
///   — les facettes `−` / `+`, avec la répétition au maintien ;
///   — le GLISSEMENT vertical sur le nombre : la molette ;
///   — le TAP sur le nombre : la saisie au clavier.
/// Le piège : un `DragGesture(minimumDistance: 0)` posé sur le nombre AVALE le
/// tap et rend la saisie manuelle inatteignable. La distance minimale est donc
/// non nulle, et le tap vit dans son propre reconnaisseur.
struct GlassStepperCard: View {
    let title: String
    let symbol: String
    let unit: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    /// Unités par point de glissement — la résistance du cran.
    let perPoint: Double

    @State private var valueAtGrab: Int?
    @State private var ticks = 0
    @State private var held = false
    @State private var typing = ""
    @FocusState private var editing: Bool

    private static let shape = RoundedRectangle(cornerRadius: 26,
                                                style: .continuous)

    var body: some View {
        VStack(spacing: 0) {
            header
            // Le filet ne borde rien : il SÉPARE, à l'intérieur d'une matière
            // qui se détache déjà seule. Rentré de 18 pt pour ne jamais
            // toucher l'arête de la carte — un trait qui atteint le bord
            // redevient un contour.
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 1)
                .padding(.horizontal, 18)
            row
        }
        .background {
            Color.clear.glassEffect(
                .regular.tint(Color.black.opacity(held ? 0.34 : 0.48)),
                in: Self.shape)
        }
        .animation(.easeOut(duration: 0.22), value: held)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.inter(11, .semibold))
                .tracking(2.4)
                .foregroundStyle(Color.inkMuted)
            Spacer(minLength: 8)
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.34))
        }
        .padding(.horizontal, 20)
        .padding(.top, 15)
        .padding(.bottom, 13)
    }

    private var row: some View {
        HStack(spacing: 0) {
            facet("minus") { step(-1) }
            Spacer(minLength: 0)
            number
            Spacer(minLength: 0)
            facet("plus") { step(1) }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private var number: some View {
        VStack(spacing: 3) {
            Group {
                if editing {
                    TextField("", text: $typing)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .focused($editing)
                        .frame(width: 120)
                } else {
                    Text("\(value)")
                        .contentTransition(.numericText())
                }
            }
            .font(Font.custom("Inter-Light", size: 42).monospacedDigit())
            .tracking(0.5)
            .foregroundStyle(LinearGradient(stops: [
                .init(color: .white, location: 0.0),
                .init(color: .white.opacity(0.82), location: 0.55),
                .init(color: .white.opacity(0.50), location: 1.0)
            ], startPoint: .top, endPoint: .bottom))

            Text(unit)
                .font(.inter(10.5, .semibold))
                .tracking(3.8)
                .foregroundStyle(Color.white.opacity(held ? 0.55 : 0.32))
        }
        .frame(minWidth: 118, minHeight: 58)
        .contentShape(Rectangle())
        .onTapGesture {
            typing = "\(value)"
            editing = true
        }
        .gesture(
            // Distance minimale NON NULLE : sinon ce reconnaisseur avale le
            // tap et la saisie au clavier devient inatteignable.
            DragGesture(minimumDistance: 8)
                .onChanged { v in
                    if valueAtGrab == nil { valueAtGrab = value; held = true }
                    guard let base = valueAtGrab else { return }
                    // Vers le HAUT la valeur monte : le doigt tire la matière,
                    // comme partout ailleurs dans l'app.
                    let d = Int((-v.translation.height * perPoint).rounded())
                    set(base + d)
                }
                .onEnded { _ in valueAtGrab = nil; held = false }
        )
        .onChange(of: editing) { _, now in
            guard !now else { return }
            if let v = Int(typing.filter(\.isNumber)) { set(v) }
        }
        .toolbar {
            if editing {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("OK") { editing = false }
                }
            }
        }
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.65),
                         trigger: ticks)
        .accessibilityElement()
        .accessibilityLabel(title.capitalized)
        .accessibilityValue("\(value)")
        .accessibilityAdjustableAction { d in
            switch d {
            case .increment: step(1)
            case .decrement: step(-1)
            default: break
            }
        }
    }

    /// Une facette : du verre, un signe, et la répétition au maintien — le
    /// correctif durement gagné des steppers de la fiche.
    private func facet(_ glyph: String,
                       action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: glyph)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.78))
                .frame(width: 56, height: 56)
                .background {
                    Color.clear.glassEffect(
                        .regular.tint(Color.white.opacity(0.06)).interactive(),
                        in: Circle())
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .buttonRepeatBehavior(.enabled)
    }

    private func step(_ d: Int) { set(value + d) }

    private func set(_ raw: Int) {
        let next = min(max(raw, range.lowerBound), range.upperBound)
        guard next != value else { return }
        value = next
        ticks += 1
        DialChime.shared.second()
    }
}

// MARK: - Le banc

/// `-bravoLab` : la page seule, rejouable. `-bravoAuto` la relance en boucle,
/// `-bravoFreeze` l'ouvre déjà posée (captures de la mise en page).
struct BravoLab: View {
    private static let cycling = CommandLine.arguments.contains("-bravoAuto")

    @State private var run = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            // Rejouer, c'est REMONTER la vue : les lecteurs repartent de zéro
            // et la partition avec eux.
            BravoView().id(run)
        }
        .overlay(alignment: .bottomTrailing) {
            Button { run += 1 } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.inkPrimary)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding(.trailing, 14)
            .padding(.bottom, 22)
        }
        .task {
            guard Self.cycling else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(9))
                run += 1
            }
        }
    }
}

#Preview { BravoLab() }

// MARK: - La pastille du butin

/// La capsule de nuit cerclée d'un fil d'or, la pièce en anthracite et le
/// compte. Sa géométrie arrive en POINTS D'ÉCRAN, déjà multipliée par la
/// caméra : le shader la redessine à chaque échelle, donc le fil de 0,7 pt
/// reste un vrai fil antialiasé même quand la caméra a plongé de 2,4×.
///
/// Le rapport 2,71 : 1 et la place de la pièce (à 0,25 de la largeur) sont
/// MESURÉS sur la référence de Kathryn, pas choisis.
struct BravoPillView: View {
    let center: CGPoint
    /// Hauteur de la capsule, caméra comprise.
    let height: CGFloat
    let amount: Double
    let count: Int
    let cam: CGFloat
    /// L'avance d'horloge de la pièce pendant que la caméra plonge sur elle.
    let neonBoost: Double
    /// Le souffle du jaillissement, 0 → 1 → 0.
    let flare: Double
    /// Inutilisé — conservé pour ne pas changer l'ordre des membres. Le pouls
    /// est calculé dans le corps, sur l'horloge propre du composant.
    let pulse: Double

    @State private var burstTick = 0

    /// Mesuré : 361 × 133 px.
    static let ratio: CGFloat = 2.71
    /// Le liseré, en points d'ÉCRAN au repos. Kathryn le veut à 0,7 — plus fin
    /// que sa propre référence, qui mesure 1,2 pt à l'échelle. Il suit la
    /// caméra : une caméra qui s'approche grossit aussi le fil.
    private static let rimRest: CGFloat = 0.7

    var body: some View {
        // La capsule respire AVEC son néon : ±0,7 % de hauteur. Assez pour
        // que la page ne soit pas une image, trop peu pour qu'on voie un
        // objet qui grossit.
        let height = self.height * (1 + 0.007 * CGFloat(pulse))
        let w = height * BravoPillView.ratio
        let coinR = height * 0.30
        GeometryReader { geo in
            let sw = Float(geo.size.width), sh = Float(geo.size.height)
            TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { tl in
                let t = Float(tl.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 900))
                // Le scalaire SORTI de l'appel : une expression de plus dans
                // un `colorEffect` et le type-checker abandonne (la leçon des
                // 36 arguments de `navMonolith`).
                let tc: Double = Double(t) + neonBoost
                let ph: Double = tc * 6.2832 * 180.0 / 900.0 + 1.7
                let pulseNow: Float = Float(0.5 + 0.5 * sin(ph))
                Rectangle()
                    .fill(.white)
                    .colorEffect(ShaderLibrary.bravoPill(
                        .float2(sw, sh),
                        .float2(Float(center.x), Float(center.y)),
                        .float2(Float(w / 2), Float(height / 2)),
                        .float(Float(Self.rimRest * cam)),
                        .float(t),
                        .float(Float(amount)),
                        .float(Float(flare)),
                        .float(pulseNow)))
                    .allowsHitTesting(false)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .overlay {
                content(coinR: coinR, w: w)
                    .position(center)
                    .opacity(amount)
                    .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
    }

    private func content(coinR: CGFloat, w: CGFloat) -> some View {
        HStack(spacing: height * 0.14) {
            // LA PIÈCE DU HEADER DE LA HOME, en anthracite : `matte: 1` éteint
            // le MÉTAL seul et laisse le croissant en néon. Le cadre est plus
            // petit que l'hôte du shader — le bloom déborde volontairement,
            // comme sur la référence.
            MoonCoinView(coinR: coinR, draggable: false, matte: 1,
                         timeBoost: neonBoost)
                .frame(width: coinR * 2.2, height: coinR * 2.2)
            Text("\(count)")
                .font(Font.custom("Inter-Light",
                                  size: height * 0.50).monospacedDigit())
                .tracking(0.5)
                .foregroundStyle(LinearGradient(stops: [
                    .init(color: .white.opacity(0.92), location: 0.0),
                    .init(color: .white.opacity(0.72), location: 0.55),
                    .init(color: .white.opacity(0.48), location: 1.0)
                ], startPoint: .top, endPoint: .bottom))
                .contentTransition(.numericText())
        }
        .frame(width: w, height: height)
        // Le compte SONNE tous les dix, jamais à chaque unité : cinquante tics
        // seraient une mitraillette. Un tock grave à l'arrivée referme.
        .onChange(of: count / 10) { _, _ in DialChime.shared.second() }
        // LE JAILLISSEMENT SONNE UNE FOIS : le tintement de pièce synthétisé
        // de la maison, et le tock grave qui referme le compte. Jamais les
        // vingt pièces séparément — ce serait une averse de gravier.
        .onChange(of: count == 50) { _, done in
            guard done else { return }
            CoinChime.shared.chink()
            DialChime.shared.minute()
            burstTick += 1
        }
        // LA VIBRATION EST LOURDE : c'est une masse qui sort, pas une paillette.
        .sensoryFeedback(.impact(weight: .heavy, intensity: 1.0),
                         trigger: burstTick)
    }
}

// MARK: - Le champ de pièces

/// LA VRAIE PIÈCE DU HEADER, EN NOIR MAT, AVEC SON NÉON. Pas une imitation :
/// c'est `moonCoin` lui-même — l'anneau poli, la face de laque, la tranche,
/// la softbox de la maison, le croissant en néon qui respire et son point
/// chaud qui voyage le long du tube. Le seul changement est `knobs.z = 1`,
/// qui fait glisser le MÉTAL vers un anthracite neutre et laisse le bloc néon
/// intact : le métal s'éteint, la lune reste allumée.
///
/// Le premier jet était un modèle réduit écrit à la main — silhouette, laque,
/// tranche, croissant booléen — pour ne pas payer trente-quatre fois un shader
/// de 450 lignes. C'était du carton : à côté de la vraie pièce, rien ne tient.
/// Le calcul refait proprement : à 14 pt de rayon, l'hôte fait 48 pt de côté,
/// et `moonCoin` sort AVANT tout calcul dès que le pixel dépasse le halo
/// (`dSil > coinR·0,52`). La surface réellement ombrée tourne autour de
/// 2 500 px² par pièce en @3x — vingt-quatre pièces coûtent donc ~2 % de
/// l'écran. Ce qu'il ne faut PAS faire, c'est monter vingt-quatre
/// `MoonCoinView` : chacune porterait son propre `TimelineView`. Ici une seule
/// horloge — celle de la page — pilote tout le champ.
///
/// MOINS NOMBREUSES ET PLUS GROSSES. À 6-10 pt une pièce est un grain, quelle
/// que soit la qualité du shader. Vingt-quatre à 11-17 pt lisent comme un tas.
struct CoinField: View {
    let source: CGPoint
    let anchor: CGPoint
    let cam: CGFloat
    /// Le temps depuis le jaillissement. Négatif : le champ n'existe pas.
    let age: Double
    /// L'horloge de la page (repliée sur 900 s, comme partout).
    let clock: Double
    let ground: CGFloat
    /// La largeur de la page : le tas doit tenir DEDANS. Une pièce coupée par
    /// le bord d'écran n'est plus une pièce, c'est un défaut.
    let width: CGFloat

    /// Le nombre et le calibre : la gerbe du compte en veut vingt-quatre de
    /// 11-17 pt ; le TOUCHER n'en veut qu'une poignée, plus petites.
    var count: Int = 24
    var sizeMin: Double = 11
    var sizeSpan: Double = 6
    var lift: Double = 1
    private static let g: Double = 310

    var body: some View {
        ZStack {
            ForEach(states(), id: \.i) { st in
                coin(st)
            }
        }
        .allowsHitTesting(false)
    }

    private func coin(_ st: State) -> some View {
        let side = st.r * MoonCoinView.hostScale
        return Rectangle()
            .fill(.white)
            .frame(width: side, height: side)
            .colorEffect(ShaderLibrary.moonCoin(
                .float2(Float(side), Float(side)),
                .float(Float(clock)),
                .float2(0, 0),
                .float(Float(st.yaw)),
                .float(Float(st.r)),
                // `reveal` porte l'allumage du NÉON : à 0 la pièce garde son
                // métal, sa tranche et ses reflets — une pièce éteinte reste
                // une pièce. On ne fait jamais apparaître une lumière.
                .float(Float(st.lit)),
                .float(1),
                .float3(MoonSDF.padding, MoonSDF.tightRange, MoonSDF.wideRange),
                .float3(0.5, 0.485, 0.71),
                // knobs.z = 1 : LE MAT. Le métal glisse vers l'anthracite, le
                // bloc néon n'est pas touché.
                // knobs.z = 1 le MAT, knobs.w = 1 le POLI : ces pièces-là sont
                // plus sombres et plus brillantes que celle de la pastille.
                .float4(0.86, 0.62, 1.0, 1.0),
                .image(MoonSDF.image)))
            .position(st.p)
            .opacity(st.alpha)
    }

    // MARK: La partition d'une pièce

    struct State: Identifiable {
        let i: Int
        var id: Int { i }
        var p: CGPoint
        var r: CGFloat
        var yaw: Double
        var lit: Double
        var alpha: Double
    }

    private func cameraed(_ p: CGPoint) -> CGPoint {
        CGPoint(x: anchor.x + (p.x - anchor.x) * cam,
                y: anchor.y + (p.y - anchor.y) * cam)
    }

    private func states() -> [State] {
        guard age > 0 else { return [] }
        var out: [State] = []
        out.reserveCapacity(count)
        for i in 0..<count {
            let delay = 0.035 * Self.hash(i, 7)
            let tau = age - delay
            guard tau > 0 else { continue }

            let ang = -Double.pi / 2 + (Self.hash(i, 1) - 0.5) * 0.84
            let speed = (158 + 82 * Self.hash(i, 2)) * lift
            let vy = sin(ang) * speed, vx = cos(ang) * speed
            // L'éventail s'ouvre en tombant : elles partent en grappe serrée
            // et se posent en TAS, jamais en colonne.
            let drift = (Self.hash(i, 11) - 0.5) * 360
            let restR = sizeMin + sizeSpan * Self.hash(i, 3)
            let gy = Double(ground) - 30 * Self.hash(i, 12)

            // L'instant du contact, en fermé.
            let c0 = Double(source.y) - gy
            let disc = vy * vy - 4 * Self.g * c0
            let tLand = disc > 0 ? (-vy + disc.squareRoot()) / (2 * Self.g) : 99

            var x: Double, y: Double, yaw: Double, ramp: Double
            if tau < tLand {
                x = Double(source.x) + vx * tau + drift * tau * tau
                y = Double(source.y) + vy * tau + Self.g * tau * tau
                yaw = (7.0 + 5.5 * Self.hash(i, 4)) * tau + Self.hash(i, 6) * 6.28
                ramp = 0
            } else {
                let d = tau - tLand
                let slide = (1 - exp(-3.4 * d)) / 3.4
                x = Double(source.x) + vx * tLand + drift * tLand * tLand
                  + (vx + 2 * drift * tLand) * slide
                y = gy - 13 * abs(sin(d * 9.5)) * exp(-d * 4.2)
                // Le lacet se range sur un angle de repos LARGE : à quelques
                // dixièmes de radian la pièce se pose presque de face, donc
                // ronde. Adossée, son ellipse s'ouvre et sa tranche se voit.
                let rest = (Self.hash(i, 8) - 0.5) * 2.30
                yaw = rest + ((7.0 + 5.5 * Self.hash(i, 4)) * tLand
                              + Self.hash(i, 6) * 6.28 - rest) * exp(-d * 3.0)
                ramp = min(d / 0.8, 1)
            }

            // LE CLIGNOTEMENT : chaque pièce sa porte (5,5 à 11 s) et sa
            // phase. À tout instant certaines brûlent, d'autres dorment, et
            // aucune ne bat avec sa voisine.
            // LE LIT N'A PAS DE LUNES. Un tas de croissants qui clignotent au
            // pied de la page faisait une guirlande — « moche ». Les pièces
            // SORTENT allumées de la pastille (ce sont ses lunes qui partent),
            // et leur néon s'éteint EN SE POSANT : ce qui reste au sol est du
            // métal nu, sombre, qui n'accroche que la softbox. La seule
            // lumière de la page redevient la pastille, et le tas devient ce
            // qu'il doit être — de la matière, pas un décor lumineux.
            let lit = tau < tLand ? 1.0 : (1 - ramp)

            // Le tas tient dans la page : on ramène les extrêmes vers
            // l'intérieur plutôt que de les laisser sortir par les flancs.
            let margin = Double(restR) * 1.6 + 14
            x = min(max(x, margin), Double(width) - margin)
            // ELLES NE S'ACCUMULENT PLUS EN BAS. Le tas au sol a été refusé
            // deux fois : les pièces sombres qui se recouvrent y dessinaient
            // des croissants parasites. Elles tombent donc et s'éteignent
            // AVANT le bas de la page — la gerbe redevient un geste, pas un
            // décor qui reste.
            let fade = 1 - Self.sstep(Double(ground) * 0.70,
                                      Double(ground) * 0.90, y)
            guard fade > 0.01 else { continue }
            out.append(State(i: i, p: cameraed(CGPoint(x: x, y: y)),
                             r: CGFloat(restR) * cam, yaw: yaw, lit: lit,
                             alpha: fade))
        }
        return out
    }

    private static func sstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let u = min(max((x - a) / (b - a), 0), 1)
        return u * u * (3 - 2 * u)
    }

    private static func hash(_ i: Int, _ k: Int) -> Double {
        let s = sin(Double(i) * 12.9898 + Double(k) * 78.233) * 43758.5453
        return s - floor(s)
    }
}
