import AVFoundation
import SwiftUI
import UIKit

// MARK: - LA CHAMBRE AU TRÉSOR (coffre v2) — LA SCÈNE RETOURNÉE
//
// Le plan : `tools/coffre-v2/PLAN-COFFRE-V2.md`, §15 pour la scène.
//
// ⚠️⚠️ **LA CHAMBRE EST RETOURNÉE, ET C'EST UNE LOI DE PHYSIQUE, PAS UN GOÛT.**
// Verdict du 26-08 : « ça manque de mise en valeur, il faut un podium et un
// spotlight — mais avec le fond gris j'ai pas l'impression qu'on va y arriver ».
// Elle avait raison avant de savoir pourquoi : **un projecteur n'est pas de la
// lumière, c'est du NOIR.** Le sol de la chambre était mesuré à L 148-152 sur
// toute la moitié basse ; on ne peut pas éclairer ce qui est déjà éclairé.
//
// ⚠️ **ET SON FOND EST NOTRE CHAMBRE, À L'ENVERS.** Mesuré sur six points de la
// rampe : sa maquette et un simple `vflip` du fichier donnent la même courbe à
// 10/255 près (R à 254, le VERT qui monte, le BLEU à zéro, chute au noir).
// Aucun nouveau rendu n'a été nécessaire — le fichier est recuit avec `vflip`.
//
// Les lois de la page, réécrites pour la scène :
//  1. **LE MUR EST EN HAUT, LE NOIR EN BAS.** La barre néon coupe à 0,344 H ;
//     les deux tiers du bas sont à zéro absolu, et c'est cette réserve de noir
//     qui rend le projecteur possible.
//  2. **LE SOCLE NE BOUGE PAS, LES PIÈCES VIENNENT DESSUS** (sa décision).
//     Une seule estrade, au centre, sous une seule lumière.
//  3. **LE PROJECTEUR EST FIXE ET IL DÉSIGNE.** La sélectionnée est celle qui
//     est SOUS la lumière. Un projecteur qui suivrait la pièce ne désignerait
//     plus rien : il deviendrait un accessoire de la pièce.
//  4. **L'ENCRE A DEUX RÉGIMES** : sombre sur le mur éclairé (le titre), claire
//     sur le noir (le compte, la card de verre). Le même écran, deux nuits.
//  5. **LE FILM NE SE MORPHE PAS EN PAGE** : il se termine par un fondu au
//     noir, un noir TENU, puis le projecteur s'allume.

// MARK: - Les cotes

enum CoffreV2Cotes {
    /// Le patron `GrandeCardExos`, à la lettre.
    static let margeHaut: CGFloat = 10
    static let rayon: CGFloat = 55
    /// Le diamètre de la pièce posée sur le socle.
    ///
    /// ⚠️ **130 → 150 : LE SUJET ÉTAIT TROP PETIT, MESURÉ CONTRE OPAL.** Sa
    /// gemme occupe 38 % de la largeur d'écran ; notre sachet en occupait
    /// **24,5 %** (relevé sur la capture). Un objet qui tient dans le quart
    /// central d'un écran n'est pas présenté, il est rangé.
    static let piece: CGFloat = 150
    /// La case de la planche vaut ce multiple du diamètre (voir `recuit_pieces`).
    static let marge: CGFloat = 1.18
    /// La levée maximale de la card au tirage — la même bande que la home.
    static let levee: CGFloat = 140

    // ── LA SCÈNE
    /// Où la barre néon se pose À L'ÉCRAN (cadrage A du §15.5 : les deux tiers
    /// du bas restent noirs). ⚠️ Coût mesuré de cette remontée : la première
    /// ligne visible du mur passe de L 157 à L 171 — on ne perd que les gris
    /// les plus pâles, et rien d'autre.
    ///
    /// ⚠️⚠️ **0,375 → 0,225, ET C'EST LA CONTRADICTION DU §13 QUI SE DÉNOUE.**
    /// « Un grand sachet » et « ne pas empiéter » avaient été déclarés
    /// incompatibles — ils l'étaient À CADRAGE CONSTANT. Le calcul qui le
    /// prouve, sur un écran de 874 pt : sachet à 150 de base, son sommet au
    /// repos tombe à `yHaut − 93 − 158`. Pour qu'il reste 20 pt sous le néon
    /// il faut `yHaut ≥ barreY·H + 271`. À l'ancien cadrage (barre à 328 pt)
    /// cela imposait le socle à 599 pt = 0,685 H — **plus BAS qu'il n'était**.
    /// La scène ne pouvait pas remonter sans que la barre remonte d'abord.
    ///
    /// Et ce qui clouait la barre, c'était le TITRE : trois lignes de 30 pt
    /// descendaient jusqu'à 235 pt, et il vit sur le mur ÉCLAIRÉ (encre
    /// sombre) — la barre passée au-dessus, il tombait dans le noir et
    /// devenait illisible. Le titre a donc rapetissé (voir `ligne`).
    static let barreY: CGFloat = 0.225
    /// Où elle est DANS LE FICHIER retourné (mesuré, pic de gradient).
    static let barreSalle: CGFloat = 0.5071
    /// Son étendue : elle a des bouts visibles, c'est un objet dans la pièce.
    static let barreX0: CGFloat = 0.169
    static let barreX1: CGFloat = 0.821
    /// largeur / hauteur du fichier (1620 × 3518).
    static let ratioSalle: CGFloat = 1620.0 / 3518.0

    // ── LE SOCLE
    /// L'ellipse du DESSUS du socle, en fraction de hauteur d'écran. C'est le
    /// sol de la pièce présentée.
    ///
    /// ⚠️ Calé À L'ENVERS, depuis la contrainte du haut : au tap la pièce
    /// grossit ET lévite, et c'est CE sommet-là qui ne doit pas toucher la
    /// barre. À 0,615 il n'en restait que 23 pt (« c'est collé au néon : non »,
    /// déjà payé une fois). À 0,632 l'écart mesuré est de **50 pt** ouverte et
    /// de 100 au repos.
    ///
    /// ⚠️ **0,665 → 0,545 (28-08) : « le background prend trop de place, plus
    /// de place pour le podium ».** Mesuré contre Opal : le centre de son
    /// sujet est à **0,28 H**, le nôtre était à **0,52 H** — l'objet vivait
    /// dans la moitié basse, loin de sa lumière. L'écart réel était de 24
    /// points, pas de 15. Le sachet centré passe de 0,52 à 0,40 H.
    ///
    /// ⚠️ Puis **+10 px** à sa demande (0,545 → 0,5564 sur un écran de
    /// 874 pt) — rendus gratuitement par le titre passé à un seul mot, qui
    /// ne descend plus que jusqu'à 155 pt.
    static let podiumY: CGFloat = 0.5564
    /// La largeur du CYLINDRE, en fraction de largeur d'écran. ⚠️ C'est SA
    /// cote, mesurée sur sa maquette (0,3932) : le socle n'est pas un réglage,
    /// c'est un objet qu'elle a dessiné. Il ne doit pas dominer la pièce.
    static let podiumW: CGFloat = 0.393

    // ── LE TAP
    /// ⚠️ « je tap, elle grossit un peu mais pas trop » : ×1,25, et pas ×1,9.
    /// C'est la LUMIÈRE qui fait la mise en valeur, plus la taille.
    static let loupeF: CGFloat = 1.22
    /// Et elle DÉCOLLE du socle — c'est la lévitation qui dit « on la regarde ».
    static let levit: CGFloat = 16
    /// ⚠️ **ELLE NE TOUCHE PAS TOUT À FAIT, ET C'EST SON CHOIX.** J'avais
    /// d'abord posé les pièces sur le vide (13 pt trop haut, cf. `cylPose`),
    /// puis corrigé jusqu'au contact — verdict : « là elles sont trop
    /// collées ». Le juste milieu est un VOL de 8 pt : une pièce de verre qui
    /// affleure son socle, ce n'est pas une erreur de pose, c'est la seule
    /// chose qui dise qu'elle est précieuse. (8 → **18** : « remonte un peu
    /// les pièces du podium, elles sont trop collées dessus ». Trois passes sur
    /// cette seule cote — 13 pt de vide involontaire, puis le contact franc,
    /// puis ce vol-ci, qui est le seul qui ait été DEMANDÉ.)
    static let vol: CGFloat = 18

    static var forme: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: rayon,
                               bottomLeadingRadius: rayon,
                               bottomTrailingRadius: rayon,
                               topTrailingRadius: rayon,
                               style: .continuous)
    }
}

/// LE SOCLE, MESURÉ SUR LA MAQUETTE DE KATHRYN (`~/Desktop/podium.png`,
/// 941 × 1672). L'asset `coffre-podium` en est le découpage
/// `crop 603 × 418 à (169, 1028)`, remis à l'échelle d'affichage (906 × 628).
///
/// ⚠️⚠️ **IL SE COMPOSE EN ADDITIF, ET C'EST MESURÉ.** « Tu vas le fondre dans
/// le noir » : il n'y a **rien à fondre**. Le noir de la chambre retournée là
/// où le socle se pose est à **zéro exact** (moyenne 0,0000, max 0,0 sur
/// y/H 0,60 → 0,95), et le pourtour du socle dans sa maquette est à L 1,2-4,4.
/// `.plusLighter` fait donc un détourage PARFAIT : le fond noir de l'image
/// disparaît de lui-même, et sa retombée de lumière au sol arrive avec elle.
/// Pas de masque à dessiner, pas d'alpha à détourer, pas de bord à raccorder.
///
/// ⚠️ Corollaire : ça n'est vrai QUE dans la zone noire. Le socle ne doit jamais
/// chevaucher la barre ni le mur — au-dessus de 0,50 H, l'additif éclaircirait
/// le décor.
enum CoffreV2Podium {
    /// largeur / hauteur du découpage (`crop 884 × 493 à (28, 961)`).
    ///
    /// ⚠️⚠️ **ON PREND BEAUCOUP PLUS LARGE QUE LE SOCLE, ET C'EST LE CORRECTIF
    /// DE « ON VOIT LA DÉMARCATION DE LA PHOTO DU PODIUM QUAND L'ÉCRAN
    /// S'ÉCLAIRE ».** Sa retombée de lumière va jusqu'à x 0,05 de la maquette
    /// (mesuré : L 4,4 de moyenne à gauche du socle). Le premier découpage la
    /// TRANCHAIT — et `.plusLighter` faisait alors apparaître le RECTANGLE de
    /// la photo dès que la scène montait d'un cran. On prend donc toute la
    /// retombée, et les quatre bords meurent en COSINUS dans l'image elle-même
    /// (13 % en haut, 20 % en bas, 15 % de chaque côté). Vérifié : les trois
    /// premiers pixels de chaque bord sont à **0,01 sur 255**.
    static let ratio: CGFloat = 1.79310
    /// La largeur du cylindre, en fraction de la largeur du découpage.
    static let cylLarge: CGFloat = 0.41855
    static let cylCX: CGFloat = 0.49887
    static let cylBas: CGFloat = 0.63895
    /// ⚠️⚠️ **LE NIVEAU DE POSE.** `cylHaut` (0,245) est le bord ARRIÈRE de
    /// l'ellipse du dessus, pas sa surface : un objet posé là est posé sur le
    /// vide, derrière le socle — c'était le « les pièces flottent au-dessus ».
    /// Mesuré au profil, la face du dessus va de y 1082 à 1140 (sa lèvre
    /// avant, L 82,7) : son centre est à **0,30426**, et c'est là qu'une pièce
    /// TOUCHE.
    static let cylPose: CGFloat = 0.30426
}

/// LE FILM D'ARRIVÉE, MESURÉ — `coffre-arrivee.mp4` v3 (1280 × 1248).
///
/// ⚠️⚠️ **LA v1 ÉTAIT CUITE 3,4 FOIS TROP SOMBRE, ET ÇA A COÛTÉ DEUX FOIS.**
/// Mesuré : la pièce plafonnait à **L 70 sur 255** quand la même pièce dans la
/// planche de sprites monte à 255 — le film était un FANTÔME de ce qu'il devait
/// présenter. Première conséquence : « l'arrivée ne se voit pas ». Seconde,
/// plus sournoise : **toutes les mesures du §1.1 avaient été prises dessus**,
/// et c'est pour ça que le plan écartait les images 0-27 comme « 1,15 s de
/// temps mort, L 2,6 ». Sur la SOURCE, les deux pièces y sont parfaitement
/// visibles et tournent lentement : c'est une approche, pas un vide.
///
/// **ON PREND LE CYCLE ENTIER : 0 → 95**, soit 96 images et **4,00 s** — plus
/// rien n'est coupé (le fichier en contient DEUX identiques, on en garde un).
/// Trois verdicts successifs pour en arriver là (« l'entrée ne se voit pas »,
/// « tu l'as coupée trop tôt », « pas assez longue, tu l'as trop coupée ») :
/// à chaque fois j'ai rallongé d'un bout, il fallait rendre le film ENTIER.
///   · 0-27  : les deux pièces approchent, lentes ;
///   · 28-31 : LA RUÉE, elles font irruption en flou de mouvement ;
///   · 32-75 : elles culbutent et grossissent jusqu'au SOMMET ;
///   · 76-78 : **la pièce se met sur la TRANCHE** — un galet de verre vu par
///             le chant, rétroéclairé ;
///   · 79-95 : elles REPARTENT dans la nuit — et c'est sur ce retrait que le
///             fondu au noir vient se poser. Une sortie, pas une coupe.
///
/// Recadré `crop=2214:2160:744:0` — symétrique autour du centre de la matière
/// (mesuré sur les 73 images : union x ∈ [0,2057 ; 0,7583], y jusqu'à 0,9995,
/// donc aucune coupe verticale possible). Le cadre vaut la largeur de l'écran,
/// et la pièce y fait 96 % de cette largeur au sommet.
enum CoffreV2Film {
    /// hauteur / largeur du fichier (1280 × 1248).
    static let ratio: CGFloat = 1248.0 / 1280.0
    /// La hauteur, en fraction d'écran, où le film se pose.
    static let ancreY: CGFloat = 0.42
}

/// LA GÉOMÉTRIE DE LA SCÈNE, calculée UNE fois par image et lue partout.
///
/// ⚠️ Sortie des `ViewBuilder` : le vérificateur de types sature sur des
/// mesures inlinées (piège maison, payé deux fois sur ce fichier).
struct SceneCoffre: Equatable {
    let W: CGFloat
    let H: CGFloat

    // ── La chambre : elle garde sa taille, on la fait GLISSER pour que sa
    //    barre tombe où on veut. Jamais une déformation.
    var hSalle: CGFloat { W / CoffreV2Cotes.ratioSalle }
    var ySalle: CGFloat {
        CoffreV2Cotes.barreY * H - CoffreV2Cotes.barreSalle * hSalle + hSalle / 2
    }

    /// La barre néon, dans l'espace de la page.
    var barre: CGRect {
        let y = CoffreV2Cotes.barreY * H
        let l = (CoffreV2Cotes.barreX1 - CoffreV2Cotes.barreX0) * W
        let cx = W / 2 + ((CoffreV2Cotes.barreX0 + CoffreV2Cotes.barreX1) / 2 - 0.5) * W
        return CGRect(x: cx - l / 2, y: y - 1, width: l, height: 2)
    }

    // ── Le socle
    /// La largeur de l'IMAGE (le cylindre n'en occupe que 61 %).
    var podL: CGFloat { W * CoffreV2Cotes.podiumW / CoffreV2Podium.cylLarge }
    var podH: CGFloat { podL / CoffreV2Podium.ratio }
    /// LE DESSUS DU SOCLE — la surface où une pièce TOUCHE (voir `cylPose`).
    var yHaut: CGFloat { CoffreV2Cotes.podiumY * H }
    /// LE PIED DU SOCLE — le sol de celle qui attend à côté, dans le noir.
    var yBas: CGFloat {
        yHaut + (CoffreV2Podium.cylBas - CoffreV2Podium.cylPose) * podH
    }
    var podCentre: CGPoint {
        CGPoint(x: W / 2 + (0.5 - CoffreV2Podium.cylCX) * podL,
                y: yHaut - CoffreV2Podium.cylPose * podH + podH / 2)
    }
    /// Où le reflet du socle a fini de mourir : le texte commence après.
    var podFin: CGFloat { podCentre.y + podH / 2 }

    /// ⚠️ **LE PAS DU RAIL DIT SI LE GESTE EXISTE.** À 0,42 W la voisine
    /// tombait à moitié hors du cadre et, assombrie, elle n'était plus qu'une
    /// tache sombre sur du noir : personne ne devine un geste qu'aucun pixel
    /// n'annonce. À 0,38 W son centre est dans l'écran et on la VOIT attendre
    /// au pied du socle.
    ///
    /// ⚠️ 0,38 → 0,415 (28-08) : le 0,38 réparait l'INVISIBILITÉ du voisin,
    /// et il fallait le rapprocher parce que rien d'autre ne l'annonçait.
    /// Maintenant qu'il a sa flaque de lumière et moins de flou, il n'a plus
    /// besoin d'être au milieu du plateau — il peut reprendre sa distance et
    /// rendre l'air autour du sujet.
    var pas: CGFloat { W * 0.415 }
}

// MARK: - La planche de sprites

/// UNE PIÈCE, UN TOUR DE MANÈGE, 72 CASES.
///
/// ⚠️ **ON NE SEEKE JAMAIS DANS UNE VIDÉO.** `DepartCine.swift:15-26` porte
/// les trois mesures qui l'ont tué : le geste réclamait **4 295 img/s**,
/// AVPlayer en sert 15 à 25, on voyait **quatre images sur 859**. Le tour de
/// Kathryn est donc découpé à la cuisson en une PLANCHE : une texture chargée
/// une fois, et le doigt ne fait plus que choisir une case.
struct PlanchePiece {
    let nom: String
    let cases: Int
    let colonnes: Int
    /// LA COULEUR QU'ELLE POSE SUR LE SOL — voir `ObjetSocle.lueur`.
    let lueur: Color

    static let or = PlanchePiece(nom: "piece-or", cases: 72, colonnes: 9,
                                 lueur: Color(red: 1.00, green: 0.74, blue: 0.34))
    static let argent = PlanchePiece(nom: "piece-argent", cases: 72, colonnes: 9,
                                     lueur: Color(red: 0.64, green: 0.79, blue: 0.98))

}

/// La pièce à l'écran : une case de la planche, découpée à la volée.
///
/// ⚠️ **LA PLANCHE EST CHARGÉE UNE FOIS ET RETENUE.** Un `Image(nom)` par
/// image de geste rechargerait la texture à chaque tour de doigt — c'est la
/// version paresseuse du seek qu'on vient d'éviter.
///
/// ⚠️⚠️ **ET ELLE EST `Animatable` SUR SON ANGLE**, ce qui n'est pas un
/// raffinement : sans ça, `withAnimation { tours[i] += 1 }` n'anime RIEN.
/// SwiftUI n'interpole que ce qui est animatable ; une propriété nue d'une vue
/// maison reçoit la valeur d'arrivée en UNE image, et la chiquenaude du tap
/// serait un saut.
struct PieceSprite: View, Animatable {
    let planche: PlanchePiece
    /// L'angle courant, en tours (0 → 1 = un tour complet).
    var tour: Double
    var diametre: CGFloat = CoffreV2Cotes.piece

    var animatableData: Double {
        get { tour }
        set { tour = newValue }
    }

    @State private var source: CGImage?

    private var k: Int {
        Int((tour * Double(planche.cases)).rounded())
    }

    /// ⚠️ **ON DÉCOUPE LE `CGImage`, ON NE JOUE PAS AVEC LES CADRES.**
    /// Le premier jet posait la planche entière dans un cadre neuf fois plus
    /// large, la décalait d'un `offset`, puis rognait — et il affichait la
    /// **case 12 au lieu de la case 0**. `offset` est une transformation de
    /// RENDU, pas de layout : le `frame(alignment:)` qui suit aligne des
    /// bornes qui n'ont pas bougé.
    ///
    /// `cropping(to:)` ne copie RIEN — c'est une fenêtre sur les mêmes octets.
    private var cellule: CGImage? {
        guard let source else { return nil }
        let c = CGFloat(planche.colonnes)
        let l = ceil(CGFloat(planche.cases) / c)
        let w = CGFloat(source.width) / c
        let h = CGFloat(source.height) / l
        let i = ((k % planche.cases) + planche.cases) % planche.cases
        return source.cropping(to: CGRect(x: CGFloat(i % planche.colonnes) * w,
                                          y: CGFloat(i / planche.colonnes) * h,
                                          width: w, height: h))
    }

    var body: some View {
        let cote = diametre * CoffreV2Cotes.marge
        Group {
            if let cellule {
                Image(decorative: cellule, scale: 1)
                    .resizable()
                    .interpolation(.high)
            } else {
                Color.clear
            }
        }
        .frame(width: cote, height: cote)
        .task(id: planche.nom) {
            guard source == nil else { return }
            source = UIImage(named: planche.nom)?.cgImage
        }
    }
}

// MARK: - Le fond de la chambre

/// LE DÉCOR, EN SOUS-VUE ÉQUATABLE.
///
/// ⚠️ Pendant le drag du manège, `page` s'écrit soixante fois par seconde et la
/// page entière se ré-évalue avec elle. Le décor, lui, ne dépend que de la
/// géométrie et d'une clarté : sans `.equatable()` il se reconstruisait à
/// chaque image pour rien — et c'est une des quatre causes mesurées de « c'est
/// pas fluide pour passer d'une pièce à l'autre ».
///
/// ⚠️⚠️ **LA CHAMBRE GLISSE, ELLE NE SE DÉFORME PAS.** On veut la barre à
/// 0,375 H et le fichier la porte à 0,507 : le film garde donc sa taille et sa
/// largeur d'écran, et on le fait remonter. Le bas découvert est du noir —
/// exactement le même que celui du film.
struct SalleFond: View, Equatable {
    let scene: SceneCoffre
    let clarte: Double

    var body: some View {
        ZStack {
            // L'IMAGE DE POSE, dessous : le filet du fond. Le décodage du
            // simulateur est LOGICIEL et rate des frames ; sans elle, un raté
            // peint tout en NOIR.
            Image("salle-poster")
                .resizable()
                .aspectRatio(contentMode: .fill)
            SalleVideo()
        }
        .frame(width: scene.W, height: scene.hSalle)
        .position(x: scene.W / 2, y: scene.ySalle)
        // LE DÉCOR SE RETIRE quand on ouvre la pièce : c'est le théâtre, et il
        // se fait en BAISSANT le reste, jamais en posant un voile (un voile
        // grise l'objet aussi). ⚠️ Et il ne MONTE jamais : éclaircir un décor
        // fait apparaître ses bords (§15.15, §16.1).
        .opacity(clarte)
    }
}

/// LA CHAMBRE, en boucle. L'école exacte des exos et de la home :
/// `AVPlayerLooper` (jamais un seek sur `didPlayToEndTime`), looper RETENU par
/// le coordinateur, muet, et **le fond de la couche TRANSPARENT** — c'est
/// l'image de pose dessous qui doit se voir quand le décodeur rate une frame,
/// sinon le raté DEVIENT le glitch noir.
///
/// ⚠️ **LE FICHIER EST RETOURNÉ ET RECUIT EN 1620 × 3518.** Retourné parce que
/// la scène a besoin de noir en bas (§15) ; recuit parce qu'il faisait 540 px
/// de large pour une card qui en demande 1206 au 3× — verdict « quand c'est
/// gros on voit tous les défauts ».
struct SalleVideo: UIViewRepresentable {
    final class Coordinator {
        var player: AVQueuePlayer?
        var looper: AVPlayerLooper?
        var retour: NSObjectProtocol?
        deinit { if let r = retour { NotificationCenter.default.removeObserver(r) } }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> BoosterLoopLayerView {
        let v = BoosterLoopLayerView()
        v.backgroundColor = .clear
        v.isUserInteractionEnabled = false
        v.playerLayer.videoGravity = .resizeAspectFill
        v.playerLayer.backgroundColor = UIColor.clear.cgColor
        // ⚠️ `resizeAspectFill` DÉBORDE SES BORNES : un `CALayer` ne masque
        // pas ses enfants, et le `clipShape` de SwiftUI ne rattrape pas une
        // couche UIKit. Les deux masques, pas un seul.
        v.clipsToBounds = true
        v.playerLayer.masksToBounds = true

        guard let url = Bundle.main.url(forResource: "coffre-salle-loop",
                                        withExtension: "mp4") else { return v }
        let item = AVPlayerItem(url: url)
        let p = AVQueuePlayer(playerItem: item)
        p.isMuted = true
        p.automaticallyWaitsToMinimizeStalling = false
        context.coordinator.looper = AVPlayerLooper(player: p, templateItem: item)
        context.coordinator.player = p
        v.playerLayer.player = p
        p.play()
        context.coordinator.retour = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil, queue: .main) { _ in p.play() }
        return v
    }

    func updateUIView(_ view: BoosterLoopLayerView, context: Context) {}

    static func dismantleUIView(_ view: BoosterLoopLayerView,
                                coordinator: Coordinator) {
        coordinator.player?.pause()
        view.playerLayer.player = nil
        coordinator.looper = nil
        coordinator.player = nil
    }
}

/// LA FORME DE LA SCÈNE — plein cadre en haut, arrondie en bas, et elle se
/// RACCOURCIT à la levée pour découvrir la lune.
///
/// ⚠️ `Animatable` sur la levée : sans ça le masque saute au lieu de suivre le
/// ressort du lâcher (la loi des rampes sous `withAnimation`, payée partout
/// dans ce dépôt).
struct FormeScene: Shape {
    var levee: CGFloat

    var animatableData: CGFloat {
        get { levee }
        set { levee = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let r = CGRect(x: rect.minX, y: rect.minY, width: rect.width,
                       height: max(0, rect.height - levee))
        return UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: CoffreV2Cotes.rayon,
            bottomTrailingRadius: CoffreV2Cotes.rayon,
            topTrailingRadius: 0,
            style: .continuous
        ).path(in: r)
    }
}

// MARK: - Le projecteur

/// L'ÉVENTAIL — le trapèze COURT et doux, en coordonnées de page. Porté
/// verbatim de `RewardCard.Eventail`, la seule forme de faisceau validée du
/// dépôt : c'est elle qui donne le triangle ÉLÉGANT plutôt qu'un cône découpé.
struct EventailCoffre: Shape {
    let haut: CGFloat
    let bas: CGFloat
    let cx: CGFloat
    let hautL: CGFloat
    let basL: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: cx - hautL / 2, y: haut))
        p.addLine(to: CGPoint(x: cx + hautL / 2, y: haut))
        p.addLine(to: CGPoint(x: cx + basL / 2, y: bas))
        p.addLine(to: CGPoint(x: cx - basL / 2, y: bas))
        p.closeSubpath()
        return p
    }
}

/// LE BALAYAGE — l'horloge du faisceau, portée telle quelle de la robe
/// « You Made It ». Deux harmoniques aux périodes premières entre elles : la
/// course est large ET jamais mécanique — **le projecteur CHERCHE**. Une seule
/// sinusoïde se lit comme un métronome en trois allers.
func balayageCoffre(_ t: Double) -> Double {
    let v = sin(t * 0.62) * 0.78 + sin(t * 0.29 + 1.3) * 0.30
    return max(-1, min(1, v))
}

/// **LE PROJECTEUR.** Ce que le retournement de la chambre a rendu possible, et
/// ce que la robe `spotlight` des rewards a déjà appris à faire.
///
/// ⚠️ **IL NE SE DESSINE PAS, IL SE CREUSE** : ce qui le fait exister, c'est le
/// noir autour, pas le blanc dedans. Et surtout — verdict du 26-08 — **il ne
/// lave PAS la page** : une nappe qui s'étale finit toujours par s'arrêter
/// quelque part, et là où elle s'arrête on lit le bord de l'image (§15.15).
///
/// **DEUX ÉVENTAILS** (« la lumière a un corps et une âme ») : la nappe LARGE
/// et douce, et le CŒUR étroit et plus vif, écrasé à 0,55 en x. Leurs flancs
/// sont **FONDUS** par un masque latéral — *un trait à bord franc sur du noir
/// est de l'encre, pas de la lumière* — et c'est ce fondu-là qui fait
/// l'élégance du triangle. Ils tournent ensemble, **ancrés à leur source**.
///
/// Plus deux foyers serrés : la **couronne** sur le crâne de la pièce (le gros
/// plan qu'elle a montré) et la **flaque** sur le socle, qui dit que ça pose.
///
/// ⚠️ Teinte : la rampe maison — **R à 1,00, le vert monte, le bleu reste bas**.
/// Le blanc pur des rewards virerait au bleuté à côté de ce néon.
///
/// ⚠️ `Equatable` : pendant le drag, la page entière se ré-évalue soixante fois
/// par seconde, et sans ça le faisceau se reconstruirait (avec ses deux flous)
/// à chaque image, pour rien.
struct Projecteur: View, Equatable {
    let scene: SceneCoffre
    /// Le diamètre et le centre de la pièce PRÉSENTÉE : le faisceau tombe sur
    /// elle, pas sur la page.
    let piece: CGFloat
    let pieceY: CGFloat
    /// 0 → 1 : éteint / nominal. Il monte au tap et sous le doigt.
    var force: Double = 1

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 2310)
            corps(balayage: balayageCoffre(t))
                .opacity(force * (1 + 0.055 * sin(t * 2 * .pi / 5.5)))
        }
        .allowsHitTesting(false)
        .blendMode(.plusLighter)
    }

    private func corps(balayage: Double) -> some View {
        let d = piece
        let haut = scene.barre.midY
        let bas = pieceY + d * 0.30
        let ancre = UnitPoint(x: 0.5, y: haut / max(scene.H, 1))
        return ZStack {
            Group {
                // LA NAPPE — large, douce, elle meurt vite.
                EventailCoffre(haut: haut, bas: bas + d * 0.55, cx: scene.W / 2,
                               hautL: d * 0.42, basL: d * 2.05)
                    .fill(LinearGradient(stops: [
                        .init(color: Color(red: 1.0, green: 0.80, blue: 0.55)
                            .opacity(0.23), location: 0),
                        .init(color: Color(red: 1.0, green: 0.72, blue: 0.40)
                            .opacity(0.075), location: 0.46),
                        // ⚠️ ELLE MEURT AVANT D'ARRIVER (0,90 et pas 1) : un
                        // faisceau premium suggère du volume, il ne repeint pas
                        // un coin de gris jusqu'au bout.
                        //
                        // ⚠️ ET ON NE DIVISE PAS PAR DEUX D'UN COUP. « Plus
                        // léger » a été payé d'un « le spotlight a disparu ! » :
                        // mesuré, la charge du faisceau était tombée de 23,7 à
                        // 11,8. Elle est remontée à ~17 — entre les deux, et
                        // c'est là qu'il fallait viser du premier coup.
                        .init(color: .clear, location: 0.90)
                    ], startPoint: .top, endPoint: .bottom))
                    .mask(LinearGradient(stops: [
                        .init(color: .clear, location: 0.04),
                        .init(color: .white, location: 0.30),
                        .init(color: .white, location: 0.70),
                        .init(color: .clear, location: 0.96)
                    ], startPoint: .leading, endPoint: .trailing))
                    .blur(radius: 19)
                // LE CŒUR — étroit, plus vif.
                EventailCoffre(haut: haut, bas: bas, cx: scene.W / 2,
                               hautL: d * 0.24, basL: d * 1.15)
                    .fill(LinearGradient(stops: [
                        .init(color: Color(red: 1.0, green: 0.90, blue: 0.72)
                            .opacity(0.37), location: 0),
                        .init(color: Color(red: 1.0, green: 0.82, blue: 0.56)
                            .opacity(0.115), location: 0.38),
                        .init(color: .clear, location: 0.90)
                    ], startPoint: .top, endPoint: .bottom))
                    .mask(LinearGradient(stops: [
                        .init(color: .clear, location: 0.20),
                        .init(color: .white, location: 0.42),
                        .init(color: .white, location: 0.58),
                        .init(color: .clear, location: 0.80)
                    ], startPoint: .leading, endPoint: .trailing))
                    .blur(radius: 13)
            }
            .rotationEffect(.degrees(13 * balayage), anchor: ancre)
            // ⚠️ **LA COURONNE EST MORTE** (verdict : « tu as le spotlight ET
            // un gros halo, faut choisir »). Cette ellipse posée sur le crâne
            // de la pièce faisait une galette floue DERRIÈRE l'objet : deux
            // sources dans la même scène, c'est une de trop, et c'est le
            // contraire de la loi 3. Il ne reste que l'éventail — qui éclaire —
            // et la flaque — qui dit que ça pose.
            // LA FLAQUE — juste de quoi dire que ça POSE.
            Ellipse()
                .fill(RadialGradient(
                    colors: [Color(red: 1.0, green: 0.80, blue: 0.52)
                        .opacity(0.32), .clear],
                    center: .center, startRadius: 0,
                    endRadius: scene.W * CoffreV2Cotes.podiumW * 0.62))
                .frame(width: scene.W * CoffreV2Cotes.podiumW * 1.16,
                       height: scene.W * CoffreV2Cotes.podiumW * 0.32)
                .blur(radius: 11)
                .position(x: scene.W / 2, y: scene.yHaut + 3)
        }
        .frame(width: scene.W, height: scene.H)
        // Une seule passe de composition pour les quatre foyers floutés.
        .compositingGroup()
    }
}

/// LA LÉVITATION — elle ne flotte pas d'une hauteur, elle RESPIRE.
///
/// ⚠️ En `ViewModifier` avec l'horloge DEDANS, comme `CarteLevee` des exos :
/// `body(content:)` reçoit l'arbre **déjà construit**, donc le relire vingt
/// fois par seconde ne reconstruit rien. Et l'ombre, elle, ne bouge pas —
/// c'est l'écart entre l'objet et son ombre qui fait la lévitation.
struct Levitation: ViewModifier {
    /// 1 = elle est sur le socle · 0 = elle attend au sol, et alors elle ne
    /// respire pas (ce qui pose ne lévite pas).
    let force: CGFloat

    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 900)
            content.offset(y: -force * 3.2 * CGFloat(sin(t * 2 * .pi / 4.7)))
        }
    }
}

// MARK: - L'allumage

/// **L'INSTANT OÙ LA SCÈNE PREND VIE.** Depuis le retournement, ce n'est plus
/// « faire naître une chambre » mais **allumer une lampe sur un objet** — le
/// geste d'un projecteur de théâtre, et c'est bien plus simple à réussir.
///
/// Quatre choses au même instant, toutes de la LUMIÈRE :
///  1. **LA NAPPE** — la scène est inondée de chaud pendant 0,4 s.
///  2. **LA BARRE FRAPPE** — montée 45 ms, chute 0,40 s. Une lampe frappe et
///     s'éteint doucement ; l'inverse se lit comme un bug d'affichage.
///  3. **L'ONDE TRAVERSE LE SOCLE** — un anneau écrasé sur le dessus du socle,
///     là où il y a de la lumière. ⚠️ Sur du noir, un anneau clair flotte.
///  4. L'ombre et la pièce encaissent, mais ça se joue dans `piece(_:)`.
///
/// ⚠️ **UNE SEULE HORLOGE, ET ELLE NE VIT QUE PENDANT LE CHOC.** Au repos ce
/// sous-arbre **n'existe pas**. C'est aussi ce qui évite deux pièges maison
/// d'un coup : le DOUBLE `withAnimation` sur la même valeur au même tour (qui
/// n'anime rien), et les courbes DÉRIVÉES d'un état animé (que SwiftUI ne joue
/// jamais, puisqu'il n'évalue le corps qu'une fois, à la valeur d'arrivée).
struct Atterrissage: View {
    let ne: Date
    let contact: CGPoint
    let diam: CGFloat
    let barre: CGRect
    let plein: CGSize
    var force: Double = 1

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
            let age = tl.date.timeIntervalSince(ne)
            let frappe = Self.coup(age, montee: 0.045, chute: 0.40) * force
            let u = min(max(age / 0.62, 0), 1)
            let e = 1 - pow(1 - u, 2.4)
            let large = diam * (0.30 + 2.5 * CGFloat(e))
            let mort = pow(1 - u, 1.6) * force
            ZStack {
                RadialGradient(
                    colors: [Color(red: 1.0, green: 0.62, blue: 0.22),
                             Color(red: 1.0, green: 0.36, blue: 0.06)
                                .opacity(0.35),
                             .clear],
                    center: UnitPoint(x: 0.5,
                                      y: barre.midY / max(plein.height, 1)),
                    startRadius: 0,
                    endRadius: plein.width * 1.25)
                    .frame(width: plein.width, height: plein.height)
                    .position(x: plein.width / 2, y: plein.height / 2)
                    .opacity(0.46 * frappe)
                Capsule(style: .continuous)
                    .fill(Color(red: 1.0, green: 1.0, blue: 0.87))
                    .frame(width: barre.width, height: 9)
                    .blur(radius: 4)
                    .position(x: barre.midX, y: barre.midY)
                    .opacity(0.80 * frappe)
                Capsule(style: .continuous)
                    .fill(Color(red: 1.0, green: 0.545, blue: 0.0))
                    .frame(width: barre.width * 1.04, height: 58)
                    .blur(radius: 28)
                    .position(x: barre.midX, y: barre.midY + 14)
                    .opacity(0.50 * frappe)
                Ellipse()
                    .strokeBorder(Color(red: 1.0, green: 0.90, blue: 0.78),
                                  lineWidth: 1 + 3 * (1 - CGFloat(e)))
                    .frame(width: large, height: large * 0.30)
                    .blur(radius: 2.5)
                    .position(contact)
                    .opacity(0.55 * mort)
            }
        }
        .allowsHitTesting(false)
        .blendMode(.plusLighter)
    }

    private static func coup(_ age: Double, montee: Double,
                             chute: Double) -> Double {
        guard age > 0 else { return 0 }
        if age < montee { return age / montee }
        return exp(-(age - montee) / chute)
    }
}

/// **LA GERBE DE PIÈCES** — au doigt sur la pièce, une poignée de petites
/// s'échappe d'elle en éventail, tourne, retombe et s'éteint.
///
/// (C'est la réponse au dernier des quatre défauts du §13, et elle est venue
/// par le bout qu'on n'attendait pas : « plein de petites pièces sortent »
/// n'était pas un bug à trouver, c'était une envie à coder.)
///
/// ⚠️ **UN SEUL `Canvas`, ET LE SPRITE RÉSOLU UNE FOIS** — la loi
/// `PoudreBooster`, reprise telle quelle de la gerbe de flammes des rewards.
/// Empiler des vues par grain, ce serait une horloge par grain ; résoudre
/// l'image par grain, ce serait un décodage par grain et par image. Ici :
/// une horloge, une résolution, vingt-six tracés.
///
/// ⚠️ Et les trajectoires sont **déterministes par hash** — jamais un `random`
/// par image, qui ferait grésiller la gerbe au lieu de la faire voler.
struct GerbePieces: View {
    let ne: Date
    /// D'où elles sortent, dans l'espace de la page.
    let centre: CGPoint
    /// L'asset de la petite pièce (l'or ou la noire, selon celle qu'on touche).
    let sprite: String
    /// La page entière — le `Canvas` dessine en coordonnées de page.
    let plein: CGSize

    static let grains = 30
    /// Au-delà, plus rien ne vit : le `Canvas` rend un tracé vide.
    static let duree: Double = 2.2

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
            gerbe(age: tl.date.timeIntervalSince(ne))
        }
        .allowsHitTesting(false)
    }

    private func gerbe(age: Double) -> some View {
        Canvas { ctx, _ in
            guard age < Self.duree else { return }
            let img = ctx.resolve(Image(sprite))
            for i in 0 ..< Self.grains {
                let retard = Self.hash(i, 9) * 0.14
                let u = age - retard
                guard u > 0, u < 2.0 else { continue }
                // L'ÉVENTAIL : vers le haut, ouvert de ±62°.
                let angle = (-Double.pi / 2) + (Self.hash(i, 1) - 0.5) * 2.16
                // ⚠️ **PLUS AMPLE QU'AU PREMIER JET.** À 150-480 pt/s sous une
                // pesanteur de 560, l'apogée tombait à **40 pt** : les pièces
                // ne quittaient jamais le disque et on ne voyait rien. À
                // 280-620 sous 470 elles montent de 120 à 200 pt — elles
                // SORTENT de la pièce, ce qui était toute la demande.
                let vitesse = 280 + 340 * Self.hash(i, 2)
                let x = centre.x + CGFloat(cos(angle) * vitesse * u)
                // La pesanteur : elles retombent, elles ne s'envolent pas.
                let y = centre.y + CGFloat(sin(angle) * vitesse * u
                                           + 470 * u * u)
                let taille = CGFloat(14 + 16 * Self.hash(i, 3))
                let vie = 1.25 + 0.85 * Self.hash(i, 4)
                let a = max(0, 1 - u / vie)
                guard a > 0.02 else { continue }
                var couche = ctx
                couche.opacity = a
                couche.translateBy(x: x, y: y)
                couche.rotate(by: .radians((Self.hash(i, 5) - 0.5) * 5
                                           + u * 4.2 * (Self.hash(i, 6) - 0.5)))
                couche.draw(img, in: CGRect(x: -taille / 2, y: -taille / 2,
                                            width: taille, height: taille))
            }
        }
        // ⚠️ LE CADRE EST EXPLICITE : le `Canvas` dessine en coordonnées de
        // PAGE, il lui faut donc la page entière et pas la taille que le
        // ZStack voudra bien lui proposer.
        .frame(width: plein.width, height: plein.height)
        .position(x: plein.width / 2, y: plein.height / 2)
    }

    private static func hash(_ i: Int, _ k: Int) -> Double {
        let s = sin(Double(i) * 12.9898 + Double(k) * 78.233) * 43758.5453
        return s - floor(s)
    }
}

// MARK: - La petite card de verre

/// **LE PIED DE PAGE** — verdict du 26-08 : « le composant footer n'est pas
/// assez travaillé ». Il ne l'était pas, et c'est mérité : un chiffre, un mot
/// et une pilule posés l'un sous l'autre, ça n'est pas un composant, ce sont
/// trois objets qui flottent au même endroit.
///
/// Ce qui en fait UN objet, et c'est tout le sujet :
///  — **une seule dalle**, le compte et la phrase séparés par un filet ;
///  — **un liseré spéculaire en haut, qui MEURT À SES DEUX BOUTS** — c'est lui
///    qui donne l'épaisseur au verre, et c'est la seule chose qui sépare une
///    dalle de verre d'un rectangle gris. Un liseré qui va d'un bord à l'autre
///    ne l'éclaire pas, il le DESSINE (loi maison, payée sur la carte
///    dépliable et sur le médaillon) ;
///  — le mot en **petites capitales espacées** : sous un grand chiffre, une
///    minuscule de même graisse fait légende d'infographie.
///
/// ⚠️ C'est le verre de NUIT (teinte noire 0,55, liseré blanc 0,07) : depuis le
/// retournement de la chambre, tout ce qui est sous la barre est sur du noir
/// absolu. Et le texte est POSÉ SUR le verre, jamais dedans — une `Text` à
/// l'intérieur d'un conteneur de verre est lentillée et se dédouble.
/// CE QUE LE PIED PORTE — **la description de l'objet posé sur le socle**,
/// et rien d'autre.
///
/// C'est la loi qui est sortie de quatre versions ratées : le pied a essayé
/// d'être un portefeuille, un compteur, un mode d'emploi et une porte, tout
/// à la fois. Depuis que le booster a SA page (`ObjetSocle`), chaque écran
/// n'a plus qu'un sujet — donc le pied non plus.
///
/// ⚠️ **LES PAGES NE SONT PAS SYMÉTRIQUES, ET C'EST VOULU** (analyse
/// `tools/coffre-v2/PLAN-PIED-COFFRE.md`) : l'or S'ACCUMULE (100 pièces = un
/// booster, donc une progression a du sens), l'argent TOMBE (tirage serveur
/// rare, une pièce = un booster, donc il n'y a RIEN à accumuler). D'où
/// `progression` optionnelle — et surtout : ne jamais inventer de jauge pour
/// l'argent, la seule qui existerait serait le *pity timer*, et l'exposer
/// rendrait la rareté farmable.
/// L'ARRIVÉE FLOUE — le vocabulaire de la maison, en un modificateur.
///
/// Flou 9 → 0, décalage 9 → 0, opacité 0 → 1, avec un retard par rang. C'est
/// ce que fait déjà le titre du coffre et la cascade de la home ; ici il sert
/// au titre de l'historique ET à chacune de ses lignes.
///
/// ⚠️ **LE RAYON RETOMBE À ZÉRO EXACT.** Un `.blur(radius:)` même minuscule
/// force une passe hors écran à chaque image ; laissé à 0,3 « pour la
/// douceur », il coûterait ce prix-là pour toujours. Le test `p > 0,995`
/// l'éteint franchement — c'est la forme déjà retenue dans `titre`.
struct ArriveeFloue: ViewModifier {
    let p: Double
    let rang: Int

    func body(content: Content) -> some View {
        let q = min(max((p - 0.055 * Double(rang)) / 0.62, 0), 1)
        return content
            .blur(radius: q > 0.995 ? 0 : 9 * (1 - q))
            .offset(y: 9 * (1 - q))
            .opacity(q)
    }
}

/// La sonde du haut de liste. ⚠️ Elle renvoie l'OFFSET, une valeur qui
/// change : une sonde qui renvoie une constante ne rappelle jamais.
struct HautDeListe: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct PiedVariante {
    let solde: Int
    let mot: String
    /// UNE ligne. La règle de cette page, en note de bas de page.
    let regle: String
    let progression: Progression?
    /// Non-nil = c'est une page de BOOSTER : elle porte le bouton d'ouverture.
    let robe: RobeBooster?
    /// ⚠️ LA COULEUR DE L'OBJET POSÉ SUR LE SOCLE — la même que sa flaque
    /// (`ObjetSocle.lueur`), et pour la même raison : la braise de la jauge et
    /// l'aura du bouton doivent appartenir à la page, sinon ce sont deux
    /// systèmes de couleur sur un même écran.
    let lueur: Color

    struct Progression {
        let reste: Int
        let palier: Int
    }
}

struct PiedCoffre: View {
    let v: PiedVariante
    /// Ouvrir le manège de CETTE page — nil sur une page de pièce.
    var onOuvrir: (() -> Void)?

    /// ⚠️⚠️ **LA PLAQUE EST MORTE, ET C'EST LA LEÇON D'OPAL (28-08).**
    /// 128 → 104 → **plus de plaque du tout**. Verdict : *« ça fait cheap »*,
    /// trois fois, sur trois mises en page différentes. La cause n'était
    /// aucune des trois : **notre pied était une plaque parce que le texte
    /// n'avait nulle part où se poser.** Chez Opal, le rocher prend 30 % de
    /// la hauteur, ne porte AUCUNE information, et c'est exactement ce qui
    /// autorise le texte à s'écrire à même la pierre — sans card, sans
    /// nappe, sans bord. Un sol qui ne dit rien est ce qui permet d'écrire
    /// dessus.
    ///
    /// Donc : le socle remonte (`podiumY` 0,665 → 0,545), le bas devient du
    /// sol, et le pied redevient une INSCRIPTION. Plus de nappe d'encre,
    /// plus de liseré, plus de coin arrondi — il ne reste que ce qui se lit.
    ///
    /// ⚠️ Et sa GRAMMAIRE est celle d'Opal, pas la nôtre : le compte, la
    /// règle, la jauge, **le reste SOUS la jauge** (« 1/3 jours » chez elle),
    /// puis un bouton large. Le verdict *« la jauge et 60 to go, on comprend
    /// pas »* venait de les avoir mis CÔTE À CÔTE : un nombre posé à droite
    /// d'une barre se lit comme une légende d'axe. Sous elle, il se lit comme
    /// sa valeur.
    static let taille = CGSize(width: 320, height: 146)

    /// 0 → 1 : la jauge se REMPLIT en arrivant (voir `jauge`).
    @State private var remplie: Double = 0
    /// Le nombre qui DESCEND — animé, sinon `.numericText()` ne joue rien.
    @State private var restant: Int = 0
    /// 0 → 1 en boucle : la position du lustre sur la partie remplie.
    @State private var balaie: Double = 0
    /// 0 → 1 en boucle : la respiration du bouton, quand il a la parole.
    @State private var appel: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            // ⚠️ LE SOURD ET L'ENTENDANT SONT SÉPARÉS ICI, ET PAS PLUS HAUT :
            // un `allowsHitTesting(false)` posé sur le bloc entier tuerait
            // aussi le bouton (l'ancienne version le rattrapait par un
            // `overlay` posé APRÈS le modificateur — plus de plaque, plus
            // d'overlay, il faut le dire explicitement).
            VStack(spacing: 0) {
                haut
                regle.padding(.top, 4)
                if let p = v.progression { jauge(p).padding(.top, 12) }
            }
            .allowsHitTesting(false)
            bouton
        }
        .frame(width: Self.taille.width, height: Self.taille.height,
               alignment: .top)
        // ⚠️ L'INSCRIPTION EST SUR DU NOIR, SANS NAPPE : il lui faut donc
        // son propre décollement, sinon la lueur du socle la mange. Une
        // ombre portée noire et LARGE ne se voit pas — elle creuse juste ce
        // qu'il faut sous les lettres.
        .shadow(color: .black.opacity(0.55), radius: 14, y: 2)
    }

    // MARK: Les blocs — nommés, jamais inlinés
    //
    // ⚠️ Ce fichier SATURE le vérificateur de types sur les vues aux mesures
    // inlinées (payé deux fois). Chaque bloc sort en propriété.

    private var haut: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text("\(v.solde)")
                .font(.inter(30, .semibold))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.96))
                .contentTransition(.numericText())
            Text(v.mot)
                .font(.inter(13, .medium))
                .foregroundStyle(.white.opacity(0.50))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    /// La règle de CETTE page — une ligne, grise. Elle ne parle que de
    /// l'objet posé sur le socle, donc elle n'a plus rien à démêler.
    private var regle: some View {
        Text(v.regle)
            .font(.inter(12, .medium))
            .foregroundStyle(.white.opacity(0.44))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    /// LA JAUGE, ET CE QUI RESTE **SOUS** ELLE.
    ///
    /// ⚠️ **« la jauge et 60 to go, on comprend pas » — la cause était la
    /// mise en page, pas les mots.** Les deux vivaient CÔTE À CÔTE, et un
    /// nombre posé à droite d'une barre se lit comme une légende d'axe : on
    /// cherche à quoi il se rapporte. Opal met le sien DESSOUS et centré
    /// (« 1/3 jours ») — là, il ne peut être que la valeur de la barre. Rien
    /// d'autre n'a changé.
    /// ⚠️⚠️ **CE QUI LUI MANQUAIT, C'ÉTAIT L'APRÈS** (verdict : *« pour la
    /// partie booster avec la jauge, anime-la davantage »*). Elle se
    /// remplissait une fois à l'arrivée, puis elle était morte — et une page
    /// où plus rien ne bouge n'a plus rien à dire. Trois vies lui sont
    /// rendues, dans cet ordre d'utilité :
    ///
    /// 1. **LE NOMBRE COMPTE.** « 60 to go » apparaissait ; il DESCEND
    ///    maintenant de 100 à 60 en même temps que la barre se remplit. Un
    ///    chiffre qui bouge se lit comme une mesure, un chiffre qui apparaît
    ///    se lit comme une étiquette. (`contentTransition(.numericText())`
    ///    sur une valeur qu'on anime vraiment — sans ça il ne se passe rien.)
    /// 2. **LA TÊTE PORTE UNE BRAISE**, dans la couleur de la page : elle dit
    ///    où ça avance, et elle relie la jauge à l'objet posé sur le socle.
    /// 3. **UN LUSTRE PASSE** sur la partie REMPLIE, toutes les 3,2 s. Lent et
    ///    faible — c'est ce qui distingue « en cours » de « figé ».
    ///    ⚠️ En `repeatForever` sur un `@State` lu par un `offset`, PAS en
    ///    `TimelineView` : le premier anime un MODIFICATEUR, le second
    ///    ré-évalue un corps à chaque image (coût mesuré ailleurs dans la
    ///    maison).
    private func jauge(_ p: PiedVariante.Progression) -> some View {
        let part = min(max(Double(p.reste) / Double(max(p.palier, 1)), 0), 1)
        return VStack(spacing: 7) {
            GeometryReader { g in
                rail(g.size.width, part: part)
                    .onAppear { demarrer(p) }
            }
            .frame(width: 196, height: 3)
            Text("\(restant) to go")
                .font(.inter(11, .semibold))
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
                .foregroundStyle(.white.opacity(0.50))
                .fixedSize()
        }
        // ⚠️ **LA PASSATION.** Quand un sachet attend déjà, la jauge n'est
        // plus le sujet : c'est le bouton. Une page ne doit jamais avoir deux
        // choses qui appellent en même temps — elle s'efface d'un tiers et
        // laisse la lumière à « Ouvrir » (voir `bouton`).
        .opacity(v.solde > 0 ? 0.62 : 1)
    }

    private func rail(_ largeur: CGFloat, part: Double) -> some View {
        let plein = max(largeur * part * remplie, 2)
        return ZStack(alignment: .leading) {
            Capsule().fill(Color.white.opacity(0.09))
            Capsule()
                .fill(Color.white.opacity(0.80))
                // ⚠️ **ELLE SE REMPLIT À L'ARRIVÉE**, elle n'est pas déjà
                // pleine. Le ressort dépasse d'un cheveu et se pose : une
                // jauge qui arrive sec se lit comme une valeur figée, pas
                // comme une avancée.
                .frame(width: plein)
                .overlay(alignment: .leading) { lustre(plein) }
            braise.offset(x: plein - 2)
        }
    }

    /// Le lustre : une bande claire qui traverse la partie remplie. Elle est
    /// masquée par la capsule pleine, donc elle ne déborde jamais dessus.
    private func lustre(_ plein: CGFloat) -> some View {
        LinearGradient(colors: [.clear, .white.opacity(0.85), .clear],
                       startPoint: .leading, endPoint: .trailing)
            .frame(width: 46)
            .offset(x: -46 + (plein + 46) * balaie)
            .clipped()
            .allowsHitTesting(false)
    }

    /// La braise de tête — dans la couleur de l'objet posé sur le socle.
    private var braise: some View {
        Circle()
            .fill(v.lueur)
            .frame(width: 5, height: 5)
            .shadow(color: v.lueur.opacity(0.9), radius: 4)
            .shadow(color: v.lueur.opacity(0.5), radius: 9)
            .opacity(remplie)
    }

    private func demarrer(_ p: PiedVariante.Progression) {
        restant = p.palier
        withAnimation(.spring(response: 0.75,
                              dampingFraction: 0.72).delay(0.25)) {
            remplie = 1
            restant = max(p.palier - p.reste, 0)
        }
        withAnimation(.linear(duration: 3.2).repeatForever(autoreverses: false)
                        .delay(0.9)) {
            balaie = 1
        }
    }

    /// ⚠️ `highPriorityGesture` ET PAS un `Button` : le geste de la page est
    /// posé sur un ANCÊTRE qui couvre tout l'écran, et un bouton d'enfant s'y
    /// fait AFFAMER dès que le drag reconnaît — la loi payée sur le stop du
    /// player. La priorité haute passe devant.
    @ViewBuilder
    private var bouton: some View {
        if v.robe != nil, v.solde > 0, let onOuvrir {
            // ⚠️ **LARGE ET SOUS LE TEXTE, PAS UNE PASTILLE DANS UN COIN.**
            // Dans la plaque, il était collé en haut à droite : un bouton
            // logé dans l'angle d'une carte se lit comme une commande de la
            // carte. Posé pleine largeur SOUS ce qu'il concerne, il se lit
            // comme la conclusion de la page — c'est la place qu'Opal donne
            // à « Verrouillée » et à « Gem actuelle ».
            Text("Ouvrir")
                .font(.inter(14.5, .semibold))
                .foregroundStyle(.black.opacity(0.88))
                .frame(width: 216, height: 44)
                .background(Capsule().fill(.white.opacity(0.94)))
                // ⚠️ **IL RESPIRE PARCE QUE LA JAUGE S'EST TUE.** C'est la
                // passation : la jauge dit « il te manque encore », le bouton
                // dit « celui-là est à toi ». Quand les deux existent, un seul
                // a le droit d'appeler. Une aura dans la couleur de la page,
                // et pas un changement de taille : un bouton qui grossit et
                // rétrécit sous le doigt devient une cible mouvante.
                .shadow(color: v.lueur.opacity(0.30 + 0.34 * appel),
                        radius: 12 + 12 * appel)
                .padding(.top, 16)
                .contentShape(Capsule())
                .highPriorityGesture(TapGesture().onEnded { onOuvrir() })
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.5)
                                    .repeatForever(autoreverses: true)) {
                        appel = 1
                    }
                }
        }
    }
}

/// LES MESURES D'UNE PIÈCE, sorties de la vue.
///
/// ⚠️ **LE VÉRIFICATEUR DE TYPES SATURE SUR UNE VUE AUX MESURES INLINÉES** —
/// piège déjà payé deux fois sur ce fichier.
///
/// ⚠️⚠️ **ET TOUT Y EST LINÉAIRE OU MONOTONE EN `page` / `loupe`.** SwiftUI
/// n'évalue le corps d'une page QU'UNE FOIS par animation, à la valeur
/// d'arrivée, puis interpole les MODIFICATEURS. Une courbe non linéaire écrite
/// ici ne serait jamais jouée — seuls ses deux bouts le seraient. `mont` est
/// affine par morceaux et `page` est monotone entre deux crans : interpoler la
/// mesure ou interpoler le modificateur donne le même résultat.
private struct MesuresPiece {
    /// 1 = elle est SUR LE SOCLE, sous la lumière · 0 = elle attend à côté,
    /// dans le noir, au niveau du sol.
    let mont: Double
    let prise: Double
    let recul: Double
    let loupe: Double
    let sort: Double
    let diam: CGFloat
    let cx: CGFloat
    let cy: CGFloat
    /// LE NIVEAU OÙ L'OBJET POSE — le dessus du socle quand il est présenté,
    /// le sol de la pièce quand il attend. C'est là que sa flaque se peint.
    let sol: CGFloat

    init(e: Double, scene: SceneCoffre, prise: Double, recul: Double,
         loupe: Double, sort: Double) {
        // ⚠️ **LE SOCLE NE PORTE QU'UNE PIÈCE À LA FOIS** (`1 − 2|e|`), et
        // c'est voulu : à mi-course les deux sont descendues et **l'estrade est
        // LIBRE**. C'est le plus beau moment du geste — une scène vide, une
        // lumière qui attend. Avec `1 − |e|` on aurait deux demi-pièces en
        // lévitation au-dessus du même socle, ce qui ne veut rien dire.
        // ⚠️ **LISSÉ** : `max(0, 1−2|e|)` a un COUDE à |e| = 0,5 — la pièce
        // changeait de direction d'un coup au milieu du voyage, et ça se lit
        // comme un à-coup (« c'est pas fluide pour passer d'une pièce à
        // l'autre »). Le smoothstep lui donne des tangentes nulles aux deux
        // bouts : elle quitte le socle et s'y repose sans arête.
        let brut = max(0, 1 - 2 * min(abs(e), 1))
        self.mont = brut * brut * (3 - 2 * brut)
        self.prise = prise
        self.recul = recul
        self.loupe = loupe
        self.sort = sort
        let mm = CGFloat(mont)
        let ll = CGFloat(loupe)
        let ss = CGFloat(sort)

        // Hors de la lumière elle est plus petite : elle a reculé dans l'ombre.
        // ⚠️ 0,13 → 0,24 : le sujet est passé de 130 à 150, et le voisin a
        // grossi avec lui — mesuré sur la capture, il faisait **32 % de la
        // largeur d'écran contre 33 % pour le sujet**. Un voisin aussi gros
        // que ce qu'on présente n'attend pas son tour, il se dispute la
        // vedette. Il recule donc davantage : c'est la profondeur qui répare,
        // pas l'assombrissement (qu'on vient justement de réduire).
        let base = CoffreV2Cotes.piece * (1 - 0.24 * (1 - mm))
        self.diam = base * (1 + (CoffreV2Cotes.loupeF - 1) * ll) * (1 - 0.10 * ss)

        // ⚠️ **LA MARCHE** : sur le socle, ou au pied du socle. Deux hauteurs
        // franches, jamais un décalage cosmétique — c'est le socle qui fait la
        // différence de niveau, et c'est pour ça qu'elle se lit.
        let sol = scene.yBas + (scene.yHaut - scene.yBas) * mm
        self.sol = sol
        // Elle AFFLEURE son socle (8 pt), et elle décolle franchement au tap.
        let vol = sol - CoffreV2Cotes.vol * mm - CoffreV2Cotes.levit * ll
        self.cy = vol - diam / 2

        // ⚠️ La sortante s'en va PAR LE CÔTÉ, elle ne se dissout pas : un objet
        // qui devient translucide n'existe pas dans le monde, un objet qui sort
        // du cadre, si. (Verdict « on voit qu'elle se transforme en
        // transparence… trop cheap ».)
        let x0 = scene.W / 2 + CGFloat(e) * scene.pas
        let dehors = x0 + (e >= 0 ? 1 : -1) * scene.W * 0.34
        self.cx = x0 + (dehors - x0) * ss
    }

    /// Ce qui est hors de la lumière est hors de la mise au point.
    /// ⚠️ Rayon RÉDUIT (7 → 5) : `.blur` sur une `Image` force une passe hors
    /// écran à CHAQUE image, et pendant le geste il y en a deux. C'est du coût
    /// pur, et le flou n'a jamais eu besoin d'aller si loin pour dire « pas
    /// encore à toi ».
    /// ⚠️ 5,0 → 3,4 (28-08) : le voisin doit se RECONNAÎTRE, pas seulement
    /// se deviner. Avec sa flaque sous lui, il n'a plus besoin d'autant de
    /// flou pour dire « pas encore à toi » — et il gagne d'être identifiable
    /// depuis le bord de l'écran, ce qui est tout l'enjeu de « le user,
    /// comment il SAIT ? ».
    var flou: CGFloat { CGFloat(3.4 * (1 - mont) + 4.0 * recul) }
    /// ⚠️ **ELLE S'ASSOMBRIT, ELLE NE S'EFFACE PAS.** Sur du noir, baisser
    /// l'opacité et baisser la lumière donnent presque la même image — mais
    /// l'une raconte « elle est sortie du faisceau » et l'autre « elle est en
    /// train de disparaître ». On raconte la première.
    ///
    /// ⚠️ **−0,24 → −0,17 le 28-08, ET C'EST DE LA DÉCOUVRABILITÉ, PAS DU
    /// GOÛT.** Verdict de Kathryn : *« quand on arrive on voit la pièce or,
    /// mais on sait pas qu'on a des boosters »*. Mesuré sur la capture, les
    /// voisins vivaient entre **2 et 13** de luminance — le carrousel DISAIT
    /// déjà qu'il y a autre chose, personne ne pouvait le lire. Remontés, on
    /// reconnaît un sachet orange au bord de l'écran : on sait qu'il existe
    /// une page suivante, et laquelle. C'est le réglage le moins cher de tout
    /// ce chantier.
    /// ⚠️ −0,17 → −0,13 : même raison que le flou, et même bénéficiaire.
    var eteinte: Double { -0.13 * (1 - mont) - 0.16 * recul - 0.22 * sort }
    /// La tenue s'avance de 14 %. ⚠️ La profondeur se joue À DEUX : grossir
    /// seul se lit comme un zoom, c'est le RECUL de l'autre qui fabrique
    /// l'espace.
    var echelle: CGFloat { CGFloat(1 + 0.14 * prise - 0.12 * recul) }
}

// MARK: - La page

struct CoffreV2Page: View {
    let coins: Int
    /// L'historique, construit par l'enveloppe (`CoffreFortFlow`) depuis les
    /// séances : la page reste bête, elle affiche ce qu'on lui donne.
    var gains: [GainCoffre] = []
    var onClose: () -> Void = {}

    /// ⚠️⚠️ **`eclat` EST MORT, ET C'EST LUI QUI FAISAIT VOIR LE BORD DE
    /// L'IMAGE** (verdict : « il y a toujours la démarcation, car tu as activé
    /// que toute la page devienne plus claire au tap : non, pas besoin »). Il
    /// montait `.brightness(0,10)` et `.saturation(1,14)` sur TOUTE la
    /// chambre — et éclaircir un décor, c'est exactement ce qui fait
    /// apparaître ses bords (la loi du §15.15, deuxième application en deux
    /// heures). Il datait de la loi 1, écrite quand la page n'avait pas de
    /// projecteur ; maintenant qu'elle en a un, **c'est le faisceau qui répond
    /// au doigt**, pas la pièce entière. Une seule lampe, et elle est locale.
    /// La pression vit désormais dans `presse`.
    @State private var presse: Double = 0

    /// ⚠️ **UNE ROTATION PAR PIÈCE** (verdict : « quand je tourne une pièce
    /// l'autre tourne aussi »). Un seul `tour` était partagé : elles n'étaient
    /// pas deux objets, elles étaient un objet peint deux fois.
    /// Un angle par cran du manège (les pièces tournent, les sachets non).
    @State private var tours: [Double] =
        Array(repeating: 0, count: CoffreV2Page.manege.count)
    @State private var tourPrise: Double = 0
    @State private var dernierGrain = 0

    /// La pièce que le doigt tient (index du manège), ou `nil`.
    @State private var tenue: Int?

    /// LE MANÈGE — `page` est continue pendant le geste.
    @State private var page: Double = 0
    @State private var pagePrise: Double = 0
    @State private var cible: Cible?
    @State private var dernierCran = 0
    /// La pièce est-elle SUR le socle ? Le passage de cette frontière est le
    /// seul moment du geste où quelque chose arrive vraiment — il se SENT.
    @State private var dernierSurSocle = true
    @State private var tenuP: Double = 0

    /// LE TIRAGE de la card — la levée découvre la lune, comme la home.
    @State private var tirage: CGFloat = 0

    // ── L'ARRIVÉE, en TROIS temps et pas un morphing
    @State private var arrivee: Double = 0
    /// LE FILM : 1 pendant qu'il joue, 0 après son FONDU AU NOIR.
    @State private var filmOp: Double = 1
    /// LA SCÈNE : 0 dans le noir, 1 quand le projecteur est allumé.
    @State private var pageOp: Double = 0
    @State private var lecteur: AVPlayer?
    @State private var filmVisible = false
    @State private var passe = false

    // ── L'ALLUMAGE / LE CHOC
    @State private var choc = 0
    @State private var chocNe: Date?
    @State private var chocIdx = 0
    @State private var chocForce: Double = 1

    // ── LE TAP
    /// 0 → 1 : la pièce présentée grossit d'un quart, lévite, et le faisceau
    /// monte. ⚠️ Plus de loupe à 0,64 W — « elle grossit un peu mais pas trop ».
    @State private var loupe: Double = 0
    @State private var loupeIdx = 0
    @State private var fumeeNe: Date?
    @State private var fumeeFin: Date?
    /// L'horloge de la gerbe (`GerbePieces`), ou `nil` : au repos ce
    /// sous-arbre n'existe pas.
    @State private var gerbeNe: Date?
    /// ⚠️ **LES TEXTES ONT LEUR PROPRE HORLOGE** : portés par `loupe`, ils se
    /// dissolvaient pendant les 0,62 s du ressort — une page entière qui
    /// devient translucide sous l'objet, et c'est ça qu'on lit comme « cheap ».
    @State private var texteOp: Double = 1
    /// ⚠️⚠️ **LE PIED NE LIT PAS `page`, IL LIT LE CRAN** — et c'est une cause
    /// mesurable de « c'est pas fluide au drag ». `glassEffect` est un matériau
    /// système : en croiser DEUX en fondu sur `page`, c'est deux passes de
    /// matériau à CHAQUE image du geste, pour une information qui ne change
    /// qu'au cran. Il lit donc un index discret, avec son propre fondu.
    @State private var piedIdx = 0
    /// La page des gains est montée par-dessus la scène.
    @State private var gainsOuverts = false
    /// 0 → 1 : la cascade d'arrivée de la page des gains (titre puis lignes).
    @State private var apparu: Double = 0
    /// De combien la page des gains est tirée vers le bas, en points.
    @State private var tireGains: CGFloat = 0
    /// La liste est-elle en HAUT ? Le geste de fermeture ne s'arme que là.
    @State private var enHaut = true
    /// Le chien de garde du geste : un drag peut mourir sans `onEnded`.
    @State private var tirNe: Date?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let sansFilm = CommandLine.arguments.contains("-coffreSansFilm")
    private static let skipAuto = CommandLine.arguments.contains("-coffreSkip")
    private static let argentDabord = CommandLine.arguments.contains("-coffreArgent")
    /// ⚠️ `-coffreTap` fait le tap tout seul : **le simulateur ne fabrique pas
    /// de doigt**, donc une réponse au tap qu'aucun banc ne déclenche n'est
    /// jamais filmée, donc jamais vérifiée. `-coffreTapFerme` la referme.
    private static let tapAuto = CommandLine.arguments.contains("-coffreTap")
    private static let tapFerme = CommandLine.arguments.contains("-coffreTapFerme")
    /// `-coffrePage <v>` FIGE le manège à mi-voyage (l'instant où le socle est
    /// LIBRE, c'est-à-dire tout le sujet du geste).
    ///
    /// ⚠️ **UN ARGUMENT DE LANCEMENT N'ARRIVE PAS TOUJOURS EN `NSNumber`** :
    /// `-coffrePage 0.35` arrive en `String`. Mesuré au `print`, et j'ai cru
    /// pendant trois captures que le manège était cassé alors qu'il n'était
    /// jamais figé. **On lit les deux formes, toujours.**
    private static let pageFigee: Double? = nombre("coffrePage")
    /// `-coffreGains` : la page des gains ouverte d'entrée (le simulateur ne
    /// fabrique pas de doigt).
    private static let gainsAuto = CommandLine.arguments.contains("-coffreGains")

    static func nombre(_ cle: String) -> Double? {
        let o = UserDefaults.standard.object(forKey: cle)
        if let n = o as? NSNumber { return n.doubleValue }
        if let t = o as? String { return Double(t) }
        return nil
    }

    // MARK: Les grandeurs dérivées

    /// La lune du secret : elle se découvre quand la card se soulève. Le seuil
    /// et la course sont ceux de la home (`luneP`).
    private var luneP: Double {
        min(max((-Double(tirage) - 70) / 60, 0), 1)
    }

    /// ⚠️ **DEUX ENCRES SUR LE MÊME ÉCRAN, ET C'EST LE RETOURNEMENT QUI L'A
    /// IMPOSÉ.** Le titre vit sur le MUR ÉCLAIRÉ (L 157 → 250) : il lui faut
    /// l'encre sombre de la maison. Le compte et la card vivent sur le NOIR
    /// ABSOLU : il leur faut du blanc. Le même écran, deux régimes, et la barre
    /// néon est la frontière.
    private var encreMur: Color { Color(white: 0.10) }

    /// CE QU'ON POSE SUR LE SOCLE — et le coffre en a QUATRE, plus deux.
    ///
    /// ⚠️ **LA DÉCISION DU 28-08, ET ELLE VIENT D'UNE MESURE.** Le sachet
    /// vivait dans un coin du pied ; agrandi, il montait 49 pt DANS le reflet
    /// du socle (la scène meurt à 693 pt, il commençait à 644). Rétréci, on
    /// ne le voyait plus. **« Un grand sachet qui sort de la carte » et « ne
    /// pas empiéter sur la scène » ne peuvent pas être vrais ensemble à cet
    /// endroit** — ce n'était pas un réglage à trouver, c'était une
    /// contradiction.
    ///
    /// Verdict de Kathryn : *« le user, quand il se rend sur la page coffre,
    /// il peut voir ses boosters »*. Donc le booster n'est pas un badge dans
    /// un coin : **c'est un objet du coffre, et il a son écran**, comme les
    /// pièces. Il n'empiète alors sur rien — il EST la scène.
    ///
    /// LA LOI QUI EN DÉCOULE, et qui range tout le reste :
    /// **le pied décrit TOUJOURS l'objet posé sur le socle.** Une règle,
    /// quatre pages, aucun cas particulier.
    enum ObjetSocle {
        case piece(PlanchePiece)
        case booster(RobeBooster)

        /// La planche du sprite, quand il y en a une (la gerbe de pièces
        /// n'existe que pour les pièces).
        var planche: PlanchePiece? {
            if case .piece(let p) = self { return p }
            return nil
        }

        /// ⚠️⚠️ **LA LUMIÈRE VIENT DE L'OBJET, C'EST LA 4ᵉ LOI D'OPAL.** Sa
        /// gemme éclaire le rocher en VERT ; la gemme verrouillée n'éclaire
        /// rien. Chez nous le socle était éclairé par le néon de la pièce —
        /// **la même lumière pour les quatre objets**, et c'est la vraie
        /// raison pour laquelle les quatre pages se ressemblaient. Une page
        /// ne se distinguait que par son objet, jamais par son ambiance.
        ///
        /// Chaque objet tient donc sa flaque. Et le bénéfice n'est pas
        /// seulement d'identité : en traversant, **la couleur du sol change
        /// AVANT que l'objet n'arrive** — la transition se raconte toute
        /// seule, sans une ligne d'animation en plus.
        var lueur: Color {
            switch self {
            case .piece(let p): return p.lueur
            case .booster(let r):
                switch r {
                // La braise du set Lune.
                case .lune: return Color(red: 1.00, green: 0.49, blue: 0.17)
                // Le violet sourd du noir — sa robe, et rien d'autre.
                case .noire: return Color(red: 0.60, green: 0.40, blue: 0.99)
                }
            }
        }
    }

    /// Les deux économies, chacune : sa pièce, puis ce qu'elle ouvre.
    private static let manege: [ObjetSocle] = [
        .piece(.or), .booster(.lune),
        .piece(.argent), .booster(.noire),
    ]
    private static var dernierePage: Double { Double(manege.count - 1) }

    /// LA PIÈCE PRÉSENTÉE — le faisceau la suit quand elle grandit et lévite.
    /// (Il ne la suit PAS latéralement : le projecteur est fixe, et c'est ce
    /// qui fait qu'il DÉSIGNE. Voir la loi 3.)
    private var piecePresD: CGFloat {
        CoffreV2Cotes.piece * (1 + (CoffreV2Cotes.loupeF - 1) * CGFloat(loupe))
    }
    private func piecePresY(_ sc: SceneCoffre) -> CGFloat {
        sc.yHaut - CoffreV2Cotes.vol
            - CoffreV2Cotes.levit * CGFloat(loupe) - piecePresD / 2
    }

    /// CE QUE CHAQUE PAGE DIT — quatre faits, et une seule source par nombre.
    ///
    /// ⚠️ **« EARNED » N'EST PAS « DISPONIBLE ».** Le pied affichait
    /// `séries × 20`, un total GAGNÉ que rien ne débitait : tant qu'aucune
    /// pièce ne s'achetait quelque chose, les deux mots désignaient le même
    /// nombre. **Le booster à 100 pièces les sépare.** Le solde retranche donc
    /// ce que les sachets déjà en réserve ont coûté.
    ///
    /// ⚠️ **UN NOMBRE MONTRÉ À DEUX ENDROITS N'EXISTE QU'UNE FOIS.** Les
    /// sachets ouvrables sont lus dans `SacreEtat` — LA source des pills du
    /// profil. Deux maquettes indépendantes se contrediraient à l'écran avant
    /// même que le serveur n'arrive.
    ///
    /// ⚠️ Maquette assumée jusqu'au ledger : le jour où `etat_coffre()` est
    /// branché (il est DÉPLOYÉ, `SacreServeur.etatCoffre`), ces six nombres
    /// viennent d'un seul appel et ce corps-ci disparaît — la vue, elle, ne
    /// bouge pas d'une ligne.
    private static let prixBooster = 100

    /// LA PAGE DES GAINS — noire, un dégradé, et une ligne par gain.
    ///
    /// Elle vit EN OVERLAY et pas en `sheet` : le coffre est déjà présenté en
    /// `fullScreenCover`, et empiler une feuille sur un cover donne la
    /// poignée grise du système au milieu de la nuit — le contraire de cette
    /// page. En overlay, elle monte du bas comme le reste de la maison.
    @ViewBuilder
    private func pageGains(_ sc: SceneCoffre) -> some View {
        if gainsOuverts {
            ZStack(alignment: .top) {
                LinearGradient(
                    colors: [Color(white: 0.055), .black, .black],
                    startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                VStack(alignment: .leading, spacing: 0) {
                    // ⚠️ **LE TITRE S'ALIGNE SUR LA COLONNE DE TEXTE DES
                    // LIGNES, PAS SUR LE BORD DE LA PAGE** (« le texte est
                    // trop décalé, il doit être plus sur la droite »). La page
                    // avait DEUX marges gauches qui se contredisaient : le
                    // titre et les vignettes à 26, les intitulés à 26+40+14 =
                    // 80. Elle n'en a plus qu'une — titre, intitulés et dates
                    // sur un seul axe — et seules les vignettes pendent à sa
                    // gauche, comme des pochettes.
                    Text("Mes gains")
                        .font(.inter(30, .bold))
                        .tracking(-0.4)
                        // ⚠️ **ICI c'est le VRAI `titleFade`, le blanc.** Sur
                        // le coffre il fallait son miroir noir parce que le
                        // titre vit sur le mur ÉCLAIRÉ ; cette page-ci est
                        // noire, c'est le sens pour lequel il a été fait.
                        .foregroundStyle(WoopGradient.titleFade)
                        // ⚠️⚠️ **ALIGNÉ SUR L'ENCRE, PAS SUR LA BOÎTE.**
                        // Verdict : *« le titre n'est pas aligné sur le côté
                        // gauche, il est décalé bizarre »*. Les deux boîtes de
                        // texte étaient pourtant à la MÊME cote (80). Mesuré
                        // au fil à plomb sur la capture : l'encre du titre
                        // tombait à **82,0** et celle des intitulés à
                        // **80,7** — un talon de glyphe deux fois plus large,
                        // parce qu'il croît avec le corps (≈ 0,067 × la
                        // taille : 2,0 pt à 30, 0,7 pt à 14).
                        //
                        // **1,3 pt, et c'est le pire écart possible** : assez
                        // proche pour qu'on lise « ça devrait être aligné »,
                        // assez loin pour qu'on voie que ça ne l'est pas. Un
                        // décalage franc se lirait comme une intention.
                        .padding(.leading, Self.colonne - Self.talon)
                        .padding(.top, 72)
                        .padding(.bottom, 18)
                        .modifier(ArriveeFloue(p: apparu, rang: 0))
                    if gains.isEmpty {
                        Text("Rien encore. Une série faite, vingt pièces.")
                            .font(.inter(13))
                            .foregroundStyle(.white.opacity(0.44))
                            .padding(.leading, Self.colonne)
                            .modifier(ArriveeFloue(p: apparu, rang: 1))
                    } else {
                        listeGains
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 26)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            // ⚠️ **ELLE SUIT LE DOIGT** — voir `gesteFermer`. Le décalage est
            // posé sur le TOUT (fond compris) : une page qu'on tire et dont le
            // fond reste collé n'est pas une page qu'on tire.
            .offset(y: tireGains)
            .onAppear {
                apparu = 0
                tireGains = 0
                enHaut = true
                withAnimation(.easeOut(duration: 0.62)) { apparu = 1 }
            }
            // ⚠️ **`highPriorityGesture` ET PAS `gesture`.** Le geste du
            // coffre est posé sur un ANCÊTRE plein écran : un geste d'enfant
            // s'y fait affamer dès que l'ancêtre reconnaît (loi payée sur le
            // stop du player et sur le bouton « Ouvrir »). La priorité haute
            // passe devant — et la garde `gainsOuverts` dans `gestePage`
            // protège le manège. **Il faut les deux, pas l'une des deux.**
            .highPriorityGesture(gesteFermer)
            .overlay(alignment: .topTrailing) {
                // Même cote que le chevron et la pill : 44, à 63 du haut.
                // Trois ronds sur la même règle dans toute la page.
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: Self.chip, height: Self.chip)
                    .glassEffect(.clear, in: .circle)
                    .padding(.trailing, 22)
                    .padding(.top, 63)
                    .contentShape(Circle())
                    // ⚠️ `highPriorityGesture` : le geste de fermeture au
                    // doigt est posé sur le PARENT de cette croix. Un tap
                    // d'enfant sous un drag de parent se fait affamer —
                    // `minimumDistance: 12` le protège en théorie, la
                    // priorité haute le protège en fait. La loi de la maison
                    // dit de ne jamais parier sur l'arbitrage de SwiftUI.
                    .highPriorityGesture(TapGesture().onEnded {
                        fermerGains()
                    })
            }
        }
    }

    /// LE GESTE QUI FERME — tirer la page vers le bas.
    ///
    /// ⚠️ **IL NE S'ARME QU'EN HAUT DE LISTE** (`enHaut`) : sinon un
    /// défilement vers le bas fermerait la page au lieu de la remonter, et le
    /// scroll deviendrait inutilisable.
    ///
    /// ⚠️ **UN DRAG PEUT MOURIR SANS `onEnded`** — doigt volé au bord bas,
    /// appel entrant, geste préempté par le système. Sans chien de garde, on
    /// récupère une page à moitié tirée et JAMAIS fermée, avec sa zone
    /// tactile toujours en place : c'est le gel app-wide du chemin Duolingo,
    /// mot pour mot. Le chien de garde COMMET la sortie si le seuil était
    /// franchi, il ne se contente pas de remettre à zéro.
    private var gesteFermer: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { v in
                guard enHaut else { return }
                tirNe = Date()
                // Vers le haut, on résiste : la page ne monte pas, elle
                // n'a nulle part où aller.
                tireGains = v.translation.height > 0
                    ? v.translation.height
                    : v.translation.height * 0.18
                armerChienDeGarde()
            }
            .onEnded { v in
                tirNe = nil
                // Au seuil OU à la vitesse : un geste vif et court ferme
                // aussi, sinon il faut « finir le mouvement » et ça se sent.
                let vite = v.predictedEndTranslation.height > 260
                if tireGains > 120 || vite { fermerGains() }
                else {
                    withAnimation(.spring(response: 0.38,
                                          dampingFraction: 0.86)) {
                        tireGains = 0
                    }
                }
            }
    }

    private func armerChienDeGarde() {
        let ne = tirNe
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            guard gainsOuverts, tirNe == ne, tirNe != nil else { return }
            // Le doigt n'a plus donné signe depuis 450 ms : le geste est mort
            // sans `onEnded`. On TRANCHE dans le sens où il allait.
            if tireGains > 120 { fermerGains() }
            else {
                withAnimation(.spring(response: 0.38,
                                      dampingFraction: 0.86)) {
                    tireGains = 0
                }
            }
            tirNe = nil
        }
    }

    private func fermerGains() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeInOut(duration: 0.28)) { gainsOuverts = false }
        tireGains = 0
    }

    /// L'axe vertical de la page : le titre, les intitulés, les dates.
    /// (26 de marge + 40 de vignette + 14 d'écart, mesuré sur `ligneGain`.)
    private static let colonne: CGFloat = 54
    /// La correction optique du titre : la différence de talon entre un
    /// glyphe de 30 pt et un de 14 (mesurée sur la capture, 82,0 − 80,7).
    private static let talon: CGFloat = 1.3

    /// LA LISTE — et son bandeau de verre.
    ///
    /// ⚠️ **LE FLOU NE VIT QUE PENDANT L'ARRIVÉE, JAMAIS EN PERMANENCE.**
    /// « la liste en dessous avec blur » ne peut pas être un voile posé sur
    /// elle : `.blur` force une passe hors écran, et sur un `ScrollView`
    /// c'est une passe PAR IMAGE DE DÉFILEMENT — plus des dates illisibles.
    /// C'est son ARRIVÉE qui est floue, en cascade, comme le titre du coffre.
    /// `ArriveeFloue` remet le rayon à zéro exact dès que c'est fini.
    ///
    /// ⚠️ Et la cascade se PLAFONNE à huit rangs : sans ça la vingtième ligne
    /// arriverait une seconde et demie après la première, et la page aurait
    /// l'air en panne.
    private var listeGains: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(Array(gains.enumerated()), id: \.element.id) { i, g in
                    ligneGain(g)
                        .modifier(ArriveeFloue(p: apparu,
                                               rang: min(i + 1, 8)))
                }
            }
            // ⚠️ La sonde du défilement : elle n'arme le geste de fermeture
            // qu'en HAUT de liste, sinon un défilement vers le bas fermerait
            // la page au lieu de la remonter. **Une sonde qui renvoie une
            // constante ne rappelle JAMAIS** — celle-ci renvoie l'offset, qui
            // change.
            .background {
                GeometryReader { g in
                    Color.clear.preference(
                        key: HautDeListe.self,
                        value: g.frame(in: .named("gains")).minY)
                }
            }
        }
        .coordinateSpace(name: "gains")
        .onPreferenceChange(HautDeListe.self) { y in enHaut = y > -4 }
        // Le bandeau qui fait disparaître la liste sous le titre.
        // ⚠️ `.clear` et pas `.regular` : le givré laiteux est interdit, et
        // ce qui passe dessous est du contenu en MOUVEMENT — le seul cas où
        // `.clear` est le bon.
        .mask {
            LinearGradient(stops: [.init(color: .clear, location: 0),
                                   .init(color: .white, location: 0.045),
                                   .init(color: .white, location: 1)],
                           startPoint: .top, endPoint: .bottom)
        }
    }

    /// Une ligne : l'objet gagné, ce qu'il a rapporté, et QUAND.
    private func ligneGain(_ g: GainCoffre) -> some View {
        HStack(spacing: 14) {
            Group {
                if let robe = g.robe {
                    SachetVignette(largeur: 24, hauteur: 41, robe: robe)
                } else {
                    PieceSprite(planche: .or, tour: 0, diametre: 34)
                }
            }
            .frame(width: 40, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(g.titre)
                    .font(.inter(14, .medium))
                    .foregroundStyle(.white.opacity(0.90))
                Text(g.date.formatted(.dateTime.day().month(.wide)))
                    .font(.inter(11.5))
                    .foregroundStyle(.white.opacity(0.40))
            }
            Spacer(minLength: 8)
            Text("+\(g.montant)")
                .font(.inter(16, .semibold))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.92))
        }
        .padding(.vertical, 13)
        .overlay(alignment: .bottom) {
            Rectangle().fill(.white.opacity(0.06)).frame(height: 1)
        }
    }

    /// QUATRE PAGES, QUATRE DESCRIPTIONS — dans l'ordre du manège.
    /// Chacune ne parle que de l'objet posé sur son socle.
    private var variantes: [PiedVariante] {
        let sacre = SacreEtat.shared
        let depense = sacre.boostersEnAttente * Self.prixBooster
        let dispo = max(coins - depense, 0)
        return [
            // ① la pièce d'or : ce qu'elle vaut, ce qui la gagne.
            PiedVariante(solde: dispo, mot: "coins",
                         regle: "20 coins for every set you finish.",
                         progression: nil, robe: nil,
                         lueur: Self.manege[0].lueur),
            // ② le booster orange : combien j'en ai, ce qu'il coûte, et
            //    COMBIEN IL M'EN MANQUE — la jauge est enfin sur la page de
            //    l'objet dont elle parle.
            PiedVariante(solde: sacre.boostersEnAttente,
                         mot: sacre.boostersEnAttente == 1
                            ? "booster" : "boosters",
                         regle: "100 coins open one.",
                         progression: .init(reste: dispo % Self.prixBooster,
                                            palier: Self.prixBooster),
                         robe: .lune, lueur: Self.manege[1].lueur),
            // ③ la pièce d'argent : elle ne s'accumule pas, elle TOMBE.
            PiedVariante(solde: sacre.boostersNoirsEnAttente,
                         mot: sacre.boostersNoirsEnAttente == 1
                            ? "silver coin" : "silver coins",
                         regle: "A rare drop, never earned.",
                         progression: nil, robe: nil,
                         lueur: Self.manege[2].lueur),
            // ④ le booster noir : pas de jauge (rien à accumuler), et son
            //    compte EST le solde d'argent — le sachet naît au claim.
            PiedVariante(solde: sacre.boostersNoirsEnAttente,
                         mot: sacre.boostersNoirsEnAttente == 1
                            ? "legendary booster" : "legendary boosters",
                         regle: "One silver coin opens it.",
                         progression: nil, robe: .noire,
                         lueur: Self.manege[3].lueur),
        ]
    }

    /// LE BOUTON « OUVRIR » — et un piège de présentation.
    ///
    /// ⚠️ Le coffre est un `fullScreenCover` ; le Manège, lui, se monte à la
    /// RACINE (`WoopApp.mainBody`, sous le cover). Ouvrir le manège d'ici
    /// l'aurait ouvert DERRIÈRE la page : rien à l'écran, et une cérémonie
    /// qui tourne pour personne. On ferme donc le coffre d'abord, et le
    /// manège part quand le cover a fini de descendre.
    /// LE BOUTON DES GAINS — en haut à droite, en verre.
    ///
    /// ⚠️ `glassEffect(.clear)` et pas `.regular` : la loi de la maison
    /// interdit le givré laiteux, et ici le contenu SOUS le verre est doux
    /// (le mur éclairé, un dégradé) — c'est exactement le cas où `.clear`
    /// est le bon. Le pied, lui, portait du texte net : il a dû renoncer au
    /// verre (voir `PiedCoffre`). Même loi, deux réponses opposées, parce
    /// que ce n'est pas le composant qui décide, c'est ce qu'il y a dessous.
    /// La cote du `ChipVerre` — la pill des gains la partage, elle ne
    /// s'invente plus la sienne.
    static let chip: CGFloat = 44

    private var boutonGains: some View {
        Image(systemName: "list.bullet")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white.opacity(0.92))
            .frame(width: Self.chip, height: Self.chip)
            .glassEffect(.clear, in: .circle)
            .overlay(Circle().strokeBorder(.white.opacity(0.10), lineWidth: 1))
            .contentShape(Circle())
            // ⚠️ La page n'a qu'un geste, posé sur un ancêtre plein écran :
            // un tap d'enfant s'y fait affamer.
            .highPriorityGesture(TapGesture().onEnded {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                    gainsOuverts = true
                }
            })
            .accessibilityLabel("Historique des gains")
    }

    /// LA SYNTHÈSE TIENT DANS UNE BARRE DE 20 POINTS.
    ///
    /// Le problème que Kathryn a nommé — *« on sait pas qu'on a des
    /// boosters »* — appelait un écran d'inventaire ; c'était disproportionné
    /// pour QUATRE objets fixes (ça aurait troqué un écrin contre un relevé
    /// de compte, et ajouté un étage au parcours). Une rangée de crans dit
    /// les trois mêmes choses, sans quitter la scène :
    ///
    ///   · **ce qui existe** — quatre crans, donc quatre pages ;
    ///   · **où je suis** — le cran plein ;
    ///   · **ce que je possède** — le cran s'allume quand le compte est > 0.
    ///
    /// Et chaque cran est une PORTE : on le touche, le rail y va. Le glissé
    /// reste, il n'est simplement plus le chemin qu'il faut deviner.
    private var barreDeCrans: some View {
        HStack(spacing: 11) {
            ForEach(0 ..< Self.manege.count, id: \.self) { i in
                cran(i)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.black.opacity(0.34)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.06),
                                        lineWidth: 1))
    }

    private func cran(_ i: Int) -> some View {
        let ici = Int(page.rounded()) == i
        let possede = variantes[min(i, variantes.count - 1)].solde > 0
        // Un cran PLEIN = j'y suis. Un cran allumé = j'y ai quelque chose.
        // Un cran éteint = la page existe, elle est vide.
        return Capsule()
            .fill(.white.opacity(ici ? 0.92 : (possede ? 0.44 : 0.16)))
            .frame(width: ici ? 20 : 7, height: 7)
            .animation(.spring(response: 0.34, dampingFraction: 0.78),
                       value: ici)
            .contentShape(Capsule().inset(by: -10))
            // ⚠️ `highPriorityGesture` : le geste de page est posé sur un
            // ANCÊTRE plein écran, un tap d'enfant s'y fait affamer.
            .highPriorityGesture(TapGesture().onEnded {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.52, dampingFraction: 0.86)) {
                    page = Double(i)
                }
                if piedIdx != i {
                    withAnimation(.easeInOut(duration: 0.30)) { piedIdx = i }
                }
            })
    }

    /// La robe de la page courante — nil si c'est une pièce qui est posée.
    private var robeDeLaPage: RobeBooster? {
        variantes[min(piedIdx, variantes.count - 1)].robe
    }

    private func ouvrirManege(_ robe: RobeBooster) {
        onClose()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            SacreEtat.shared.ouvrirManege(robe: robe)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let sc = SceneCoffre(W: geo.size.width, H: geo.size.height)
            let bas = max(tirage, 0)
            ZStack(alignment: .topLeading) {
                Color.black.ignoresSafeArea()

                // LA LUNE, sous la card : elle n'existe que découverte. Et
                // depuis le retournement elle se découvre sur du NOIR — elle
                // n'a jamais été aussi bien posée.
                if luneP > 0.01 {
                    LuneSecrete(p: luneP)
                        .frame(maxWidth: .infinity)
                        .position(x: sc.W / 2, y: sc.H - 52)
                }

                carte(sc).offset(y: bas)
                socle(sc).offset(y: bas)
                flaques(sc).offset(y: bas)
                poudre(sc).offset(y: bas)
                Projecteur(scene: sc,
                           piece: piecePresD,
                           pieceY: piecePresY(sc),
                           force: pageOp * (1 + 0.55 * loupe + 0.18 * presse))
                    .equatable()
                    .offset(y: bas)
                if let ne = chocNe {
                    Atterrissage(ne: ne,
                                 contact: CGPoint(x: sc.W / 2, y: sc.yHaut),
                                 diam: CoffreV2Cotes.piece,
                                 barre: sc.barre,
                                 plein: geo.size,
                                 force: chocForce)
                        .offset(y: bas)
                }
                // LA FUMÉE NOIRE de la pièce ouverte — le shader `coinSmoke`
                // en palette SOMBRE, composée exprès « à peine plus claire que
                // la nuit » pour cette page-ci.
                if let ne = fumeeNe {
                    CoinSmoke(center: CGPoint(x: sc.W / 2,
                                              y: sc.yHaut - CoffreV2Cotes.piece / 2),
                              radius: CoffreV2Cotes.piece * 0.62,
                              start: ne, end: fumeeFin, palette: .dark)
                        .offset(y: bas)
                }
                contenu(sc).offset(y: bas)
                // LA GERBE passe DEVANT : elle sort de la pièce, elle ne se
                // cache pas derrière.
                if let ne = gerbeNe {
                    GerbePieces(ne: ne,
                                centre: CGPoint(x: sc.W / 2,
                                                y: piecePresY(sc)),
                                sprite: (Self.manege[loupeIdx].planche?.nom
                                         ?? PlanchePiece.or.nom) + "-mini",
                                plein: CGSize(width: sc.W, height: sc.H))
                        .offset(y: bas)
                }
                // ⚠️ **ALIGNÉE SUR LE CHEVRON, ET DE LA MÊME TAILLE QUE LUI.**
                // Mesuré : elle était centrée à 78 pt contre 85 pour le
                // chevron, en 38 × 38 contre 44 × 44 — sept points d'écart et
                // deux tailles. Sa cote était écrite à la main et ne
                // connaissait pas le chevron. Elle est maintenant DÉRIVÉE de
                // lui : `63 + 44/2`, la seule cote canonique de la maison.
                boutonGains
                    .position(x: sc.W - 22 - Self.chip / 2,
                              y: 63 + Self.chip / 2)
                    .opacity(pageOp * (gainsOuverts ? 0 : 1))
                if filmVisible { film(sc) }
                pageGains(sc)
            }
            .contentShape(Rectangle())
            .gesture(gestePage(sc))
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear(perform: demarrer)
        .onDisappear { lecteur?.pause() }
    }

    // MARK: La card et la chambre

    @ViewBuilder
    private func carte(_ sc: SceneCoffre) -> some View {
        Color.black
            .overlay(
                // ⚠️ LE `Color.clear` TIENT LA TAILLE : `aspectRatio(.fill)` ne
                // prend PAS la taille proposée (défaut mesuré sur les exos).
                Color.clear
                    .overlay {
                        SalleFond(scene: sc,
                                  clarte: pageOp * (1 - 0.45 * loupe))
                            .equatable()
                    }
                    // ⚠️⚠️ **LE MUR PREND TOUT L'ÉCRAN — NI COUPÉ, NI FONDU**
                    // (verdict : « je voulais pas que la partie grise soit
                    // fondue, elle prend juste bien tout l'écran iPhone, elle
                    // était coupée avant »). Deux jets ont échoué avant celui-
                    // ci : le patron `GrandeCardExos` (marge de 10 pt + quatre
                    // coins à 55) DÉCOUPAIT le mur en haut, et le masque en
                    // dégradé que j'ai posé ensuite le faisait MOURIR sous
                    // l'encoche. Elle ne voulait ni l'un ni l'autre.
                    //
                    // `FormeScene` garde le seul comportement qui compte — la
                    // card se RACCOURCIT par le bas, sinon la lune est
                    // inatteignable (`offset(y: max(tirage,0))` ne fait RIEN
                    // quand on tire vers le haut) — et rend le haut au plein
                    // cadre.
                    .clipShape(FormeScene(levee: max(-tirage, 0)))
            )
            .frame(height: sc.H)
            .ignoresSafeArea()
    }

    /// LES FLAQUES — une par objet, dans SA couleur (voir `ObjetSocle.lueur`).
    ///
    /// ⚠️ Elles se peignent en une passe SÉPARÉE des objets, et pas dans la
    /// boucle des sprites : le corps du `ForEach` des pièces empile déjà flou,
    /// échelle, lévitation, keyframes, position et ombre — y ajouter deux
    /// vues, c'est le mur du vérificateur de types, et ce fichier l'a déjà
    /// touché deux fois.
    ///
    /// ⚠️ Et c'est ce qui rend le VOISIN lisible : au repos il vivait entre 2
    /// et 13 de luminance, une tache sombre sur du noir. Une flaque, même à
    /// 0,16, lui donne un sol — on ne voit pas l'objet, on voit qu'il y a
    /// quelque chose de posé là. C'est exactement la 4ᵉ capture d'Opal.
    @ViewBuilder
    private func flaques(_ sc: SceneCoffre) -> some View {
        ZStack {
            ForEach(Array(Self.manege.enumerated()), id: \.offset) { i, ob in
                let m = MesuresPiece(e: Double(i) - page, scene: sc,
                                     prise: 0, recul: 0,
                                     loupe: (loupeIdx == i) ? loupe : 0,
                                     sort: (loupeIdx == i) ? 0 : loupe)
                contact(ob, m: m, sc: sc)
                lavis(ob, m: m, sc: sc)
                lueurObjet(ob, m: m, sc: sc)
            }
        }
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }

    /// LA POUDRE DE PAILLETTE DU PASSAGE — et elle FAIT un travail.
    ///
    /// ⚠️⚠️ **ELLE EST ÉMISE PAR CELUI QUI PART, DANS LA COULEUR DE CELUI QUI
    /// ARRIVE.** C'est le passage de témoin : l'animation raconte le
    /// changement d'identité au lieu de le décorer. Sans cette règle, une
    /// poudre n'est qu'un confetti de plus.
    ///
    /// ⚠️ **ELLE SE PILOTE PAR `page`, PAS PAR UNE HORLOGE.** Un grain dont la
    /// position vient d'un `TimelineView` joue une séquence ; un grain dont la
    /// position vient de `page` SUIT LE DOIGT — on tire à moitié, la poudre
    /// est à moitié ; on relâche, elle revient. C'est la différence entre un
    /// effet et une matière, et c'est gratuit : la valeur existe déjà.
    ///
    /// ⚠️ **LE `Canvas` NE VIT QUE PENDANT LE VOYAGE.** Loi de la maison : un
    /// `Canvas` rastérise TOUTE sa surface même vide. Il se monte au premier
    /// cheveu de mouvement et se démonte à la pose — au repos, coût zéro.
    ///
    /// ⚠️ **AUCUN `@State` ÉCRIT PAR IMAGE** (piège `page-reevaluee`) : les
    /// grains sont une fonction pure de (graine, `page`). Rien ne s'écrit.
    @ViewBuilder
    private func poudre(_ sc: SceneCoffre) -> some View {
        let d = page - page.rounded()
        if abs(d) > 0.004 {
            Canvas(rendersAsynchronously: false) { ctx, taille in
                Self.grains(ctx: &ctx, taille: taille, scene: sc,
                            page: page, depart: depart, arrivee: arrive)
            }
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
            .ignoresSafeArea()
        }
    }

    /// L'objet qu'on QUITTE et celui qu'on REJOINT, en couleurs.
    private var depart: Color {
        Self.manege[min(max(Int(page.rounded()), 0), Self.manege.count - 1)]
            .lueur
    }
    private var arrive: Color {
        let vers = page > page.rounded() ? Int(page.rounded()) + 1
                                         : Int(page.rounded()) - 1
        return Self.manege[min(max(vers, 0), Self.manege.count - 1)].lueur
    }

    /// ⚠️ Le dessin sort en `static` et prend son contexte en `inout` : le
    /// corps d'un `Canvas` écrit dans la vue est un des chemins les plus
    /// sûrs vers le mur du vérificateur de types sur ce fichier.
    private static func grains(ctx: inout GraphicsContext, taille: CGSize,
                               scene: SceneCoffre, page: Double,
                               depart: Color, arrivee: Color) {
        // `t` : 0 au départ du voyage, 1 à mi-chemin, 0 à l'arrivée. La poudre
        // NAÎT et MEURT dans le même geste — elle ne traîne pas sur la page
        // d'après.
        let d = abs(page - page.rounded())
        let t = min(d * 2, 1)
        let vie = sin(t * .pi)
        guard vie > 0.001 else { return }
        let sens: CGFloat = page > page.rounded() ? -1 : 1
        let x0 = scene.W / 2
        let y0 = scene.yHaut - CoffreV2Cotes.vol
        for k in 0..<70 {
            // Graine déterministe : le grain k est TOUJOURS le même grain.
            let a = Double(k) * 2.3999632
            let r = (sin(Double(k) * 12.9898) * 43758.5453)
            let f = r - r.rounded(.down)
            let g = (sin(Double(k) * 78.233) * 12345.6789)
            let h = g - g.rounded(.down)

            // Un cône vers le haut, penché du côté d'où l'on vient.
            let etale = CGFloat(0.35 + 0.65 * f)
            let dx = CGFloat(cos(a)) * scene.podL * 0.52 * etale
                     + sens * CGFloat(t) * scene.W * 0.20
            let dy = -CGFloat(t) * (58 + 96 * CGFloat(h)) + CGFloat(t * t) * 34
            let p = CGPoint(x: x0 + dx * CGFloat(t), y: y0 + dy)
            let rayon = CGFloat(0.8 + 1.4 * h) * (1 - CGFloat(t) * 0.35)
            // ⚠️ LA COULEUR VIRE EN COURS DE VOL : chaque grain part de la
            // teinte de l'objet qui s'en va et arrive dans celle de l'autre.
            let teinte = t < 0.5 ? depart : arrivee
            let al = vie * (0.35 + 0.65 * f)
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - rayon, y: p.y - rayon,
                                            width: rayon * 2,
                                            height: rayon * 2)),
                     with: .color(teinte.opacity(al)))
        }
    }

    /// ①  LA TACHE DE CONTACT — **masquée PAR LA MATIÈRE DU SOCLE.**
    ///
    /// ⚠️⚠️ **C'EST LE SEUL CHANGEMENT QUI SÉPARE « UNE LUMIÈRE » D'« UN
    /// CALQUE ».** Verdict : *« les halos font pas naturel, on dirait des
    /// calques »* — et c'en était un, littéralement : une ellipse à dégradé
    /// radial posée en additif PAR-DESSUS le socle. Quatre raisons pour que
    /// l'œil le voie : (a) une empreinte géométrique parfaite, alignée sur
    /// les axes, à décroissance régulière — aucune lumière ne tombe comme ça
    /// sur un cylindre ; (b) elle ne connaissait pas la matière qu'elle
    /// éclairait, allumant le socle, le sol et le VIDE derrière le socle à la
    /// même valeur ; (c) elle n'éclairait pas l'objet ; (d) elle s'ajoutait à
    /// un socle DÉJÀ additif, et deux additifs empilés saturent — or une zone
    /// saturée n'a plus de matière.
    ///
    /// Le remède : le dégradé passe en `.mask(...)` de l'IMAGE DU SOCLE,
    /// convertie en alpha par sa LUMINANCE. ⚠️ Pas par son alpha : le fichier
    /// est un PNG à fond noir opaque (il se compose en additif, voir
    /// `CoffreV2Podium`) — masquer par l'alpha rendrait le rectangle qu'on
    /// veut justement tuer. Par la luminance, c'est le liseré du socle qui
    /// prend le plus de lumière, son corps sombre moins, et le vide autour
    /// rien du tout. **La lumière suit la matière, et le bord de l'ellipse
    /// n'existe plus puisque c'est le socle qui découpe.**
    private func contact(_ ob: ObjetSocle, m: MesuresPiece,
                         sc: SceneCoffre) -> some View {
        // Le centre est légèrement DERRIÈRE le point de pose : la flaque est
        // vue de trois quarts, son foyer n'est pas au contact mais un peu
        // au-delà. C'est ce décalage qui lui donne sa profondeur.
        let foyer = UnitPoint(x: 0.5, y: CoffreV2Podium.cylPose + 0.06)
        return RadialGradient(colors: [ob.lueur.opacity(0.95),
                                       ob.lueur.opacity(0.20),
                                       ob.lueur.opacity(0)],
                              center: foyer,
                              startRadius: 0, endRadius: sc.podL * 0.58)
            .frame(width: sc.podL, height: sc.podH)
            .mask {
                Image("coffre-podium")
                    .resizable()
                    .interpolation(.high)
                    .frame(width: sc.podL, height: sc.podH)
                    .luminanceToAlpha()
            }
            .position(sc.podCentre)
            .opacity(pageOp * max(0.62 * m.mont + 0.26 * m.loupe, 0))
    }

    /// ②  LE LAVIS — très large, très faible, sans bord visible.
    ///
    /// Une seule ellipse essayait d'être à la fois le contact et l'ambiance :
    /// elle ne lisait ni comme l'un ni comme l'autre. Celle-ci ne fait que
    /// poser l'objet sur un sol — c'est elle qui rend le VOISIN lisible, lui
    /// qui n'a pas de socle sous les pieds.
    ///
    /// ⚠️⚠️ **LOI : UN DÉGRADÉ RADIAL DOIT ATTEINDRE ZÉRO AVANT LE BORD DE SA
    /// FORME, SINON LA FORME DEVIENT LE BORD.** Premier jet : une `Ellipse`
    /// de 185 × 30 remplie d'un radial de rayon 96. À 15 px du centre — le
    /// bord BAS de l'ellipse — le dégradé était encore à ~85 % ; la forme le
    /// coupait donc net. Mesuré sur la capture : **une marche horizontale en
    /// travers de l'écran à 0,656 H, 13,5 → 6,8 de luminance en deux
    /// lignes.** Exactement le défaut de calque qu'on venait de corriger, sous
    /// une autre forme.
    ///
    /// Le remède est géométrique : un DISQUE dont le dégradé meurt pile à son
    /// rayon, puis `scaleEffect` pour l'écraser en flaque. La décroissance
    /// suit alors l'écrasement, et il n'y a plus de bord à couper.
    private func lavis(_ ob: ObjetSocle, m: MesuresPiece,
                       sc: SceneCoffre) -> some View {
        let r = sc.podL * (0.23 + 0.20 * CGFloat(m.mont))
        let force = 0.13 + 0.10 * m.mont - 0.10 * m.sort
        return RadialGradient(colors: [ob.lueur.opacity(0.55),
                                       ob.lueur.opacity(0.10),
                                       ob.lueur.opacity(0)],
                              center: .center,
                              startRadius: 0, endRadius: r)
            .frame(width: r * 2, height: r * 2)
            .scaleEffect(x: 1, y: 0.17, anchor: .center)
            .position(x: m.cx, y: m.sol + 2)
            .opacity(pageOp * max(force, 0))
    }

    /// ③  LA LUEUR DE L'OBJET — celle que le sprite ne porte plus.
    ///
    /// ⚠️ Le bake ne met plus le halo du rendu dans l'alpha (`bake_vignettes`,
    /// « la lueur appartient à la scène, pas au sprite ») : le sachet est
    /// maintenant NET, bord de 2 px, et sa lueur se fabrique ici. Elle y gagne
    /// de prendre la couleur de la page, de suivre le voyage, et de s'éteindre
    /// quand l'objet quitte la lumière — trois choses qu'un halo peint dans
    /// des pixels ne saura jamais faire.
    ///
    /// ⚠️ Un dégradé radial et **pas un `.blur` sur une copie de l'image** :
    /// un flou force une passe hors écran PAR OBJET, à chaque image de geste
    /// (loi de la maison). Ici, quatre objets × deux gestes = zéro passe.
    private func lueurObjet(_ ob: ObjetSocle, m: MesuresPiece,
                            sc: SceneCoffre) -> some View {
        let d = m.diam
        return Ellipse()
            .fill(RadialGradient(colors: [ob.lueur.opacity(0.42),
                                          ob.lueur.opacity(0)],
                                 center: .center,
                                 startRadius: 0, endRadius: d * 0.95))
            .frame(width: d * 1.9, height: d * 2.1)
            .position(x: m.cx, y: m.cy)
            .opacity(pageOp * max(0.22 + 0.42 * m.mont - 0.20 * m.sort, 0))
    }

    /// LE SOCLE. Voir `CoffreV2Podium` : il se compose en ADDITIF, et son fond
    /// noir disparaît de lui-même parce que le noir de la scène est à zéro
    /// exact. Aucun masque, aucun alpha, aucun bord à raccorder.
    @ViewBuilder
    private func socle(_ sc: SceneCoffre) -> some View {
        Image("coffre-podium")
            .resizable()
            .interpolation(.high)
            .frame(width: sc.podL, height: sc.podH)
            .position(sc.podCentre)
            .blendMode(.plusLighter)
            .opacity(pageOp * (1 - 0.30 * loupe))
            .allowsHitTesting(false)
    }

    // MARK: Le contenu

    @ViewBuilder
    private func contenu(_ sc: SceneCoffre) -> some View {
        // ⚠️ +58 → +103 : `PiedCoffre` n'est plus une plaque de 104 mais une
        // inscription de 146, et `.position` centre son cadre. Le haut du
        // texte tombe donc à `podFin + 30` — juste sous le reflet du socle,
        // là où le sol devient lisible.
        let piedY = sc.podFin + 103
        // ⚠️ CE QUI EST SOUS LE SOCLE REMONTE AVEC LE BORD BAS DE LA CARD —
        // sinon, card tirée, le texte se retrouve posé sur la bande de nuit
        // qui découvre la lune. C'est `MonteAvecLaCard` des exos, en une ligne.
        let monte = min(tirage, 0) * 0.9
        ZStack(alignment: .topLeading) {
            // ⚠️ **LE TITRE VIT SUR LE MUR, DONC IL EST EN ENCRE SOMBRE.** Le
            // retournement l'a fait tomber en pleine lumière (L 157 → 250) ; du
            // blanc y serait illisible. On ne l'a pas déplacé pour autant : de
            // grandes lettres sombres sur un mur lumineux, c'est une affiche —
            // c'est mieux que ce qu'il était.
            // ⚠️ **UNE SEULE RANGÉE, ET C'EST LE CHEVRON QUI DONNE LA LIGNE.**
            // Le titre vivait SOUS lui, centré à 141 pt quand le chevron
            // l'était à 85 (mesuré). Dans un `HStack` alignés au centre, les
            // deux partagent la même ligne par construction — plus aucune
            // cote à entretenir. Place vérifiée : chevron de 22 à 66, titre
            // ≈ 130 pt, la pill commence à 343 — 147 pt de marge.
            HStack(alignment: .center, spacing: 14) {
                ChipVerre(symbole: "chevron.left", label: "Fermer",
                          clarte: 1, action: onClose)
                titre
            }
            .padding(.leading, 22)
            // Le mur étant plein cadre, le chevron retrouve sa cote
            // canonique — « la position du chevron ne bouge JAMAIS d'une page
            // à l'autre » (`RangeeChips`).
            .padding(.top, 63)
            .opacity(pageOp * texteOp)

            piece(sc)

            // LE PIED : un seul objet, et les deux pièces s'y croisent à
            // taille FIXE. Deux dalles montées/démontées au cran feraient
            // sauter la mise en page d'un texte à l'autre.
            barreDeCrans
                .position(x: sc.W / 2, y: piedY - PiedCoffre.taille.height / 2 - 26)
                .opacity(pageOp)
                .offset(y: monte)

            PiedCoffre(v: variantes[min(piedIdx, variantes.count - 1)],
                       onOuvrir: robeDeLaPage.map { r in { ouvrirManege(r) } })
                .id(piedIdx)
                .transition(.opacity)
            .position(x: sc.W / 2, y: piedY)
            .opacity(pageOp)
            .offset(y: monte)
        }
    }

    /// LE TITRE — un seul mot, et **c'est lui qui a dénoué le cadrage**.
    ///
    /// ⚠️⚠️ Trois lignes de 30 pt (« Find what / you worked / for. »)
    /// descendaient à 235 pt. Le titre ne peut vivre QUE sur le mur ÉCLAIRÉ
    /// (encre sombre) : la barre néon ne pouvait donc jamais passer au-dessus
    /// de 0,315 H, et sous cette barre le sachet à sa vraie taille ne rentrait
    /// plus. C'est ce nœud-là qui faisait passer « grand sachet » et « ne pas
    /// empiéter » pour une contradiction (§13). J'avais dû le rapetisser à
    /// 17 pt pour libérer la scène — **un seul mot ne fait qu'une ligne**, il
    /// reprend donc ses 30 pt sans rien coûter : chevron jusqu'à 101, titre de
    /// 117 à 155, néon à 197 — 42 pt d'air.
    ///
    /// Sa cote est celle du titre de la page Calendrier (`CalLab.enTeteBac`) :
    /// `inter(30, .bold)`, tracking −0,4. ⚠️ Mais PAS son dégradé :
    /// `WoopGradient.titleFade` va du BLANC plein au blanc 0,25 — il est fait
    /// pour du fond sombre. Ici le mur est en pleine lumière, il faut son
    /// **miroir noir** : mêmes arrêts, même diagonale, en encre.
    private var titre: some View {
        let p = min(max(arrivee / 0.90, 0), 1)
        return Text("Rewards")
            .font(.inter(30, .bold))
            .tracking(-0.4)
            .foregroundStyle(Self.encreFade)
            .blur(radius: p > 0.995 ? 0 : 9 * (1 - p))
            .offset(y: 9 * (1 - p))
            .opacity(p)
    }

    /// Le miroir noir de `WoopGradient.titleFade`.
    private static let encreFade = LinearGradient(
        stops: [
            .init(color: .black.opacity(0.92), location: 0.0),
            .init(color: .black.opacity(0.82), location: 0.32),
            .init(color: .black.opacity(0.52), location: 0.68),
            .init(color: .black.opacity(0.22), location: 1.0)
        ],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    // MARK: La pièce et la marche

    /// ⚠️⚠️ **LE SOCLE NE BOUGE PAS, LES PIÈCES VIENNENT DESSUS** (sa décision
    /// du 26-08). Le manège est devenu une MARCHE : la présentée est debout sur
    /// l'estrade, dans le faisceau ; l'autre attend **au pied du socle**, plus
    /// bas, dans le noir. Tirer fait descendre l'une et monter l'autre.
    ///
    /// Ça règle du même coup, et physiquement, le verdict « la pièce floue doit
    /// être plus basse » : elle n'est plus décalée de quelques points par
    /// convention, **elle est par terre**.
    @ViewBuilder
    private func piece(_ sc: SceneCoffre) -> some View {
        // ⚠️⚠️⚠️ **LE CADRE NE BOUGE JAMAIS, C'EST L'ÉCHELLE QUI TRAVAILLE.**
        // Animer le `frame` d'une `Image`, ce n'est pas l'agrandir : SwiftUI ne
        // sait pas interpoler un rendu bitmap, alors il FOND l'ancienne image
        // dans la nouvelle — c'était le « on voit qu'elle se transforme en
        // transparence, trop cheap ». Le cadre vaut donc toujours la plus
        // grande taille possible, et `scaleEffect` fait le reste.
        let cadre = CoffreV2Cotes.piece * CoffreV2Cotes.loupeF
        ZStack {
            ForEach(Array(Self.manege.enumerated()), id: \.offset) { i, pl in
                let e = Double(i) - page
                let m = MesuresPiece(e: e, scene: sc,
                                     prise: (tenue == i) ? tenuP : 0,
                                     recul: (tenue != nil && tenue != i)
                                            ? tenuP : 0,
                                     loupe: (loupeIdx == i) ? loupe : 0,
                                     sort: (loupeIdx == i) ? 0 : loupe)
                let f: CGFloat = (chocIdx == i) ? CGFloat(chocForce) : 0

                objetSurSocle(pl, i: i, cadre: cadre)
                    // ⚠️ Le flou et l'échelle sont LÉGAUX ICI : ce sont des
                    // IMAGES, pas du verre natif (l'interdit du §6.3 ne vaut
                    // que pour `glassEffect`).
                    .blur(radius: m.flou)
                    .brightness(m.eteinte)
                    .scaleEffect(m.echelle * m.diam / cadre)
                    // ELLE RESPIRE (±3,2 pt, 4,7 s) — et seulement quand elle
                    // est SUR le socle : ce qui pose ne lévite pas.
                    .modifier(Levitation(force: CGFloat(m.mont)))
                    // ELLE ENCAISSE L'ALLUMAGE : écrasement franc, rebond, puis
                    // elle se range. ⚠️ En keyframes et pas en deux
                    // `withAnimation` sur la même valeur au même tour — ça, ça
                    // n'anime RIEN. ⚠️ Et AVANT le `.position` : `.position`
                    // fait remplir tout le parent, un `scaleEffect` posé après
                    // pivoterait sur le bas de l'ÉCRAN.
                    .keyframeAnimator(initialValue: 0.0, trigger: choc) { v, k in
                        v.scaleEffect(x: 1 + 0.13 * k * f,
                                      y: 1 - 0.13 * k * f,
                                      anchor: .bottom)
                    } keyframes: { _ in
                        CubicKeyframe(1.0, duration: 0.05)
                        CubicKeyframe(-0.28, duration: 0.13)
                        CubicKeyframe(0.10, duration: 0.14)
                        CubicKeyframe(0.0, duration: 0.22)
                    }
                    .position(x: m.cx, y: m.cy)
                    .opacity(pageOp)
                    // L'objet tenu ou LEVÉ décolle : son ombre s'éloigne. Elle
                    // reste SERRÉE — une auréole large se lit comme de la
                    // transparence, pas comme du poids.
                    .shadow(color: .black.opacity(0.45 * m.prise
                                                  + 0.34 * m.loupe),
                            radius: 20 * m.prise + 24 * m.loupe,
                            y: 14 * m.prise + 18 * m.loupe)
            }
        }
        .allowsHitTesting(false)
    }

    /// L'objet du cran `i`, dans le CADRE COMMUN — pièce ou sachet, ils
    /// voyagent sur le même rail et subissent les mêmes mesures.
    ///
    /// ⚠️ Le sachet est une IMAGE, pas la scène 3D. Le géant du profil
    /// (`BoosterStage`) est la vitrine idéale — mais une `SCNView` qu'on
    /// met à l'échelle et qu'on floute à chaque image de geste, c'est le lag
    /// lui-même (loi de la maison). L'échange se fera comme au manège du
    /// Sacre : l'image voyage, le 3D prend sa place UNE FOIS POSÉ. Pour
    /// l'instant, l'image seule — elle suffit à juger la mise en scène.
    @ViewBuilder
    private func objetSurSocle(_ objet: ObjetSocle, i: Int,
                               cadre: CGFloat) -> some View {
        switch objet {
        case .piece(let pl):
            PieceSprite(planche: pl, tour: tours[i], diametre: cadre)
        case .booster(let robe):
            // ⚠️ LE CADRE RESTE CELUI DE LA PIÈCE — toutes les mesures du
            // rail (échelle, position, lévitation) sont calculées dessus. Le
            // sachet DÉBORDE ce cadre au lieu de le changer : ×1,55 en
            // hauteur, sinon un objet vertical logé dans un carré fait la
            // taille d'une fiole et le socle a l'air vide.
            //
            // Et il monte de la moitié de ce qu'il gagne : sans ça, il
            // s'enfoncerait dans le socle — son PIED doit rester là où se
            // pose le bas de la pièce.
            let h = cadre * 1.55
            SachetVignette(largeur: h * 84 / 145, hauteur: h, robe: robe)
                .frame(width: cadre, height: cadre)
                .offset(y: -(h - cadre) / 2)
        }
    }

    // MARK: Les gestes

    /// ⚠️⚠️ **UN SEUL GESTE POUR TOUTE LA PAGE, ET C'EST LA LEÇON DE CE
    /// CHANTIER.** Il y en avait DEUX : un sur la pièce, un sur la page. Celui
    /// de la pièce était posé sur un conteneur qui, à cause des `.position()`
    /// de ses enfants, **prend tout l'écran** — avec `minimumDistance: 0` il
    /// gagnait partout. Trois symptômes pour une seule cause : la seconde pièce
    /// inatteignable, la card qui ne se soulève pas, le tap qui ne passe pas.
    ///
    /// Le remède n'est pas de border le premier geste et d'espérer que SwiftUI
    /// arbitre comme on l'imagine — c'est de **ne plus rien avoir à arbitrer**.
    private enum Cible { case piece, manege, card, fond }

    private func gestePage(_ sc: SceneCoffre) -> some Gesture {
        let ouverte = loupe > 0.02
        let d = CoffreV2Cotes.piece * (ouverte ? CoffreV2Cotes.loupeF : 1)
        let centre = CGPoint(x: sc.W / 2,
                             y: sc.yHaut - d / 2
                                - (ouverte ? CoffreV2Cotes.levit : 0))
        // ⚠️ **LA PRISE MANGEAIT LE MILIEU DE L'ÉCRAN.** À 0,70 de diamètre,
        // le rayon valait 91 pt — une fenêtre de 182 pt de large ET de haut,
        // pile à la hauteur où le doigt passe pour faire défiler : tout geste
        // qui commençait là TOURNAIT la pièce au lieu de pousser le manège, et
        // comme la rotation marche bien, on ne comprenait pas pourquoi le
        // manège ne bougeait pas. À 0,56 on garde 8 pt de marge autour du
        // disque au lieu de 26 : on attrape encore l'objet sans viser, et on
        // rend l'écran au geste.
        let prise = d * 0.56
        return DragGesture(minimumDistance: 0)
            .onChanged { v in
                // ⚠️⚠️ **LA PAGE DES GAINS EST OUVERTE : LE COFFRE EST SOURD.**
                // Bug trouvé en préparant le geste de fermeture, et qui
                // existait déjà : ce geste-ci est posé sur un ancêtre PLEIN
                // ÉCRAN. Un doigt promené sur la page des gains faisait donc
                // TOURNER LE MANÈGE derrière l'overlay opaque — personne ne
                // l'a jamais vu parce que rien ne le montre, mais la page
                // courante et le pied changeaient dans le dos du user.
                //
                // ⚠️ La garde ne suffit pas à faire marcher le geste de la
                // page des gains, et le `highPriorityGesture` de celle-ci ne
                // suffit pas à protéger le manège : il faut les DEUX.
                guard !gainsOuverts else { return }
                if cible == nil {
                    // Pendant l'arrivée, la page n'écoute qu'une chose : le
                    // raccourci. Rien d'autre ne doit répondre.
                    guard passe else { return }
                    let dd = hypot(v.startLocation.x - centre.x,
                                   v.startLocation.y - centre.y)
                    if dd < prise {
                        cible = .piece
                        let i = ouverte ? loupeIdx : Int(page.rounded())
                        tenue = min(max(i, 0), tours.count - 1)
                        tourPrise = tours[tenue!]
                        dernierGrain = Int(tourPrise * 36)
                        UIImpactFeedbackGenerator(style: .soft)
                            .impactOccurred(intensity: 0.6)
                        withAnimation(.easeOut(duration: 0.26)) { presse = 1 }
                        if !ouverte {
                            withAnimation(.spring(response: 0.34,
                                                  dampingFraction: 0.72)) {
                                tenuP = 1
                            }
                        }
                    } else if ouverte {
                        // ⚠️ LA PIÈCE OUVERTE PREND TOUTE LA PAGE : hors d'elle
                        // il n'y a plus ni manège ni tirage, seulement la
                        // sortie. Deux mises en scène ne se disputent pas le
                        // même doigt.
                        cible = .fond
                    } else {
                        // Hors de la pièce, l'axe décide — et il ne se
                        // rediscute pas : un axe testé à chaque image oscille.
                        let dx = abs(v.translation.width)
                        let dy = abs(v.translation.height)
                        guard max(dx, dy) > 10 else { return }
                        cible = dy > dx ? .card : .manege
                        if cible == .manege { pagePrise = page }
                    }
                }
                switch cible {
                case .piece:
                    guard let t = tenue else { break }
                    // 320 pt de doigt = un tour complet.
                    tours[t] = tourPrise + Double(v.translation.width) / 320
                    // LE GRAIN DE LA ROTATION : un tic tous les 10°. ⚠️ Jamais
                    // à chaque image : la trame du moteur se sature et on ne
                    // sent plus rien.
                    let g = Int(tours[t] * 36)
                    if g != dernierGrain {
                        dernierGrain = g
                        UIImpactFeedbackGenerator(style: .light)
                            .impactOccurred(intensity: 0.32)
                    }
                case .manege:
                    // ⚠️⚠️ **LE RAIL SUIT LE DOIGT** — et c'est un
                    // RETOURNEMENT assumé. Le code portait « vers la droite
                    // amène la pièce noire » (sa demande d'alors), donc le rail
                    // allait à l'INVERSE du doigt. Elle décrit aujourd'hui la
                    // convention normale — « je drag vers la gauche pour voir
                    // la pièce de droite » — et c'est elle qui gagne : on
                    // pousse le rail, on ne commande pas une direction.
                    //
                    // Et la course est ÉLASTIQUE aux deux bouts : bornée sec,
                    // la pièce se COLLE au bord et le doigt continue dans le
                    // vide — c'est ça qui se lit comme « pas naturel ».
                    let brut = pagePrise - Double(v.translation.width) / 230
                    let fin = Self.dernierePage
                    if brut < 0 {
                        page = tanh(brut / 0.42) * 0.16
                    } else if brut > fin {
                        page = fin + tanh((brut - fin) / 0.42) * 0.16
                    } else {
                        page = brut
                    }
                    let cran = Int((page * 10).rounded())
                    if cran != dernierCran {
                        dernierCran = cran
                        UIImpactFeedbackGenerator(style: .light)
                            .impactOccurred(intensity: 0.42)
                    }
                case .card:
                    let t = v.translation.height
                    let net = t < 0 ? min(t + 14, 0) : max(t - 14, 0)
                    tirage = CoffreV2Cotes.levee * CGFloat(tanh(Double(net) / 190))
                case .fond, nil:
                    break
                }
            }
            .onEnded { v in
                let quoi = cible
                cible = nil
                let immobile = hypot(v.translation.width,
                                     v.translation.height) < 10
                // LE TAP : pas de cible décidée et le doigt n'a pas bougé.
                // Pendant l'arrivée, c'est LUI qui passe l'intro.
                if quoi == nil, immobile {
                    if !passe { passerDevant() }
                    return
                }
                switch quoi {
                case .piece:
                    // ⚠️ LA RETOMBÉE EST PLUS LENTE QUE LA MONTÉE (0,62 contre
                    // 0,26). Une lampe frappe et s'éteint doucement.
                    withAnimation(.easeInOut(duration: 0.62)) { presse = 0 }
                    let t = tenue
                    tenue = nil
                    withAnimation(.spring(response: 0.46,
                                          dampingFraction: 0.82)) { tenuP = 0 }
                    if immobile, let t {
                        if loupe > 0.5 { fermerLoupe() } else { ouvrirLoupe(t) }
                    }
                case .manege:
                    // LE CRAN : on tombe sur la pièce la plus proche, élan
                    // compris. Une pièce ne s'immobilise pas entre deux faces —
                    // et ici, surtout pas à côté du socle, qui doit porter
                    // quelqu'un.
                    //
                    // ⚠️ **UN GESTE FRANC COMMET TOUJOURS.** L'arrondi seul
                    // pouvait RENVOYER EN ARRIÈRE une course de 100 pt suivie
                    // d'un lâcher mou — et c'est ça, « inversement ça marche
                    // pas ». Au-delà d'un quart de course, on part du côté où
                    // le doigt allait, sans rediscuter l'arrondi.
                    let reste = -Double(v.predictedEndTranslation.width
                                        - v.translation.width) / 230
                    var but = (page + reste).rounded()
                    if abs(page - pagePrise) > 0.25 {
                        but = page > pagePrise ? ceil(page) : floor(page)
                    }
                    let cible2 = min(max(but, 0), Self.dernierePage)
                    dernierSurSocle = true
                    if cible2 != page.rounded() {
                        UIImpactFeedbackGenerator(style: .rigid)
                            .impactOccurred(intensity: 0.7)
                    }
                    withAnimation(.spring(response: 0.46, dampingFraction: 0.86)) {
                        page = cible2
                    }
                    let n = Int(cible2)
                    if n != piedIdx {
                        withAnimation(.easeInOut(duration: 0.30)) { piedIdx = n }
                    }
                case .card:
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                        tirage = 0
                    }
                case .fond:
                    fermerLoupe()
                case nil:
                    break
                }
            }
    }

    // MARK: Le tap

    /// **ON PRÉSENTE LA PIÈCE.** ⚠️ Plus de loupe à 0,64 W (« trop gros, et
    /// c'est collé au néon ») : elle grossit d'un quart, **décolle du socle**,
    /// et c'est le **FAISCEAU** qui monte de 45 % pendant que le reste de la
    /// scène se retire. C'est la lumière qui fait la mise en valeur, plus la
    /// taille — et du même coup le sommet de la pièce reste à 128 pt sous la
    /// barre.
    ///
    /// ⚠️ Le ressort est posé sur un SEUL curseur, pas sur trois réglages qui
    /// se cherchent : c'est la seule façon que la transition soit d'un bloc.
    private func ouvrirLoupe(_ i: Int) {
        loupeIdx = i
        // ⚠️ **ELLE SE PRÉSENTE : UN TOUR COMPLET PENDANT QU'ELLE MONTE.** Un
        // objet qui grossit sans tourner, c'est un zoom ; un objet qui TOURNE
        // en venant, c'est un objet qu'on vous montre. Un tour ENTIER et pas un
        // demi : elle retrouve sa face. Le même `withAnimation` porte les deux.
        // ⚠️ Et ça n'anime que parce que `PieceSprite` est `Animatable`.
        withAnimation(.spring(response: 0.62, dampingFraction: 0.88)) {
            loupe = 1
            tours[i] += 1
        }
        // Les textes ne se dissolvent pas SOUS le mouvement : ils sont partis
        // avant qu'il commence.
        withAnimation(.easeOut(duration: 0.16)) { texteOp = 0 }
        fumeeNe = .now
        fumeeFin = nil
        // ⚠️ LA GERBE. Elle part du centre de la pièce et vit 2,2 s ; passé ce
        // délai on démonte le sous-arbre, mais SEULEMENT si personne n'a
        // retapé entre-temps (le jeton, comme pour la fumée et le choc).
        gerbeNe = .now
        let jetonG = gerbeNe
        DispatchQueue.main.asyncAfter(deadline: .now() + GerbePieces.duree) {
            guard gerbeNe == jetonG else { return }
            gerbeNe = nil
        }
        // « Un plus petit bruit, élégant, très discret, premium » : le même
        // métal, mais bas et grave — un objet lourd qu'on approche.
        CoinChime.shared.chink(volume: 0.14, rate: 0.72)
        // Le boum de la gerbe : ferme, court. C'est une poignée qu'on lâche.
        UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.9)
    }

    private func fermerLoupe() {
        guard loupe > 0.02 else { return }
        withAnimation(.spring(response: 0.58, dampingFraction: 0.92)) {
            loupe = 0
        }
        // Ils reviennent APRÈS que la pièce est reposée — jamais pendant.
        withAnimation(.easeIn(duration: 0.24).delay(0.30)) { texteOp = 1 }
        // La fumée ne se coupe pas : elle se DISSIPE (le shader porte son
        // propre relâchement, 0,45 s).
        fumeeFin = .now
        let jeton = fumeeNe
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            guard fumeeNe == jeton else { return }
            fumeeNe = nil
            fumeeFin = nil
        }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.45)
    }

    // MARK: L'arrivée — film, fondu au noir, allumage

    @ViewBuilder
    private func film(_ sc: SceneCoffre) -> some View {
        if let lecteur {
            // ⚠️⚠️ **PLEIN CADRE, ET AUCUN MASQUE.** L'ancienne version posait
            // le film dans une bande de 26 % de l'écran sous un fondu sur ses
            // QUATRE bords — et le fondu vertical **mangeait la pièce** (elle
            // occupe y ∈ [0,02 ; 0,96] du cadre, le masque effaçait de 0 à 0,10
            // et de 0,90 à 1). Voilà le « fondue bizarrement ».
            //
            // Le fichier est recadré sur la bande où vivent les pièces, ses
            // quatre bords sont à **zéro absolu** (mesuré) : il n'y a rien à
            // fondre, du noir sur du noir. Il se termine par un fondu au noir
            // et un noir TENU (`terminer`), jamais par un morphing vers la
            // pièce de la page — celui-là a été recalé deux fois.
            CinematicPlayer(player: lecteur)
                .frame(width: sc.W, height: sc.W * CoffreV2Film.ratio)
                .position(x: sc.W / 2, y: sc.H * CoffreV2Film.ancreY)
                .opacity(filmOp)
                .allowsHitTesting(false)
        }
    }

    private func demarrer() {
        guard !passe, pageOp == 0 else { return }
        // ⚠️ LA CUISSON DU SHADER DE FUMÉE, HORS DU CHEMIN D'AFFICHAGE. SwiftUI
        // compile un shader PARESSEUSEMENT, au premier usage, sur le fil
        // principal : sans ça, le premier tap paierait la compilation entière —
        // et c'est justement l'image où la pièce se présente.
        CoinSmokeWarm.warmUp()
        CoinChime.shared.prepare()
        // `-coffreArgent` visait « la deuxième pièce » ; depuis que chaque
        // économie a DEUX pages (sa pièce, son booster), l'argent est au
        // cran 2. `-coffrePage <n>` reste le moyen d'ouvrir n'importe où.
        if Self.argentDabord { page = 2; piedIdx = 2 }
        if let f = Self.pageFigee { page = f; piedIdx = Int(f.rounded()) }
        if Self.gainsAuto {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                gainsOuverts = true
            }
        }
        // Sans film (ou sous Reduce Motion), la page est là tout de suite : on
        // ne fait jamais attendre devant une absence.
        guard !Self.sansFilm, !reduceMotion,
              let url = Bundle.main.url(forResource: "coffre-arrivee",
                                        withExtension: "mp4") else {
            passe = true
            allumer(duree: 0.30)
            return
        }
        let p = AVPlayer(url: url)
        p.automaticallyWaitsToMinimizeStalling = false
        p.isMuted = true
        lecteur = p
        filmVisible = true
        p.play()
        // Le film fait 96 images = 4,00 s : le cycle ENTIER. On le laisse
        // aller au bout — il finit sur les pièces qui repartent dans la nuit —
        // puis le fondu au noir se pose sur ce retrait.
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.05) { terminer() }
        if Self.skipAuto {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { passerDevant() }
        }
    }

    private func passerDevant() {
        guard !passe else { return }
        terminer(fondu: 0.18, noir: 0.08)
    }

    /// ⚠️⚠️ **LE FILM SE TERMINE COMME UN FILM** (verdict : « joue plutôt le
    /// fondu noir de fin de vidéo »). Fondu au noir, **un vrai noir tenu**, puis
    /// le projecteur s'allume. Le noir entre les deux n'est pas une économie,
    /// c'est la coupure : sans lui, le film et la page se chevauchent et on
    /// retombe sur le fondu bizarre, recalé deux fois.
    private func terminer(fondu: Double = 0.44, noir: Double = 0.18) {
        guard !passe else { return }
        passe = true
        withAnimation(.easeIn(duration: fondu)) { filmOp = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + fondu) {
            lecteur?.pause()
            lecteur = nil
            filmVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + fondu + noir) {
            allumer()
        }
    }

    /// **L'ALLUMAGE — c'est ici qu'est l'effet, et le retournement l'a rendu
    /// facile.** Avant, il fallait faire naître une chambre entière en 0,22 s ;
    /// maintenant la scène EST noire et il n'y a plus qu'à **allumer une lampe
    /// sur un objet**. C'est le geste d'un projecteur de théâtre.
    private func allumer(duree: Double = 0.22) {
        let i = min(max(Int(page.rounded()), 0), tours.count - 1)
        withAnimation(.easeOut(duration: duree)) { pageOp = 1 }
        frapper(i, force: 1)
        withAnimation(.linear(duration: 1.18).delay(0.22)) { arrivee = 1.18 }
        // LA PICHENETTE D'ARRIVÉE — le rail avance d'un cheveu et revient.
        // Un carrousel muet ne dit pas qu'il tourne : on peut poser des
        // crans (`barreDeCrans`), il reste qu'un geste s'apprend mieux en le
        // VOYANT qu'en le déduisant. Elle ne part que depuis le premier cran
        // et sans doigt en cours — jamais contre l'utilisateur.
        if page == 0, tenue == nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                guard page == 0, tenue == nil else { return }
                withAnimation(.easeInOut(duration: 0.34)) { page = 0.085 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
                    guard page > 0, page < 0.2, tenue == nil else { return }
                    withAnimation(.spring(response: 0.55,
                                          dampingFraction: 0.72)) { page = 0 }
                }
            }
        }
        // Le banc du tap : le simulateur ne fabrique pas de doigt.
        if Self.tapAuto {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                ouvrirLoupe(i)
            }
            if Self.tapFerme {
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.6) {
                    fermerLoupe()
                }
            }
        }
    }

    /// LE CHOC — l'instant, et rien d'autre. Il MONTE l'effet et le démonte une
    /// seconde plus tard ; le compteur `choc`, lui, ne redescend jamais (c'est
    /// le déclencheur des keyframes, et une date remise à `nil` les
    /// re-déclencherait au démontage).
    private func frapper(_ i: Int, force: Double) {
        chocIdx = i
        chocForce = force
        chocNe = .now
        choc += 1
        let jeton = choc
        UIImpactFeedbackGenerator(style: .heavy)
            .impactOccurred(intensity: force)
        CoinChime.shared.chink(volume: Float(0.30 * force))
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard choc == jeton else { return }
            chocNe = nil
        }
    }
}

// MARK: - Le banc

/// `-coffre2` : la page seule.
/// `-coffreSansFilm` saute l'arrivée · `-coffreSkip` la passe à 1,2 s (le
/// simulateur ne tape pas) · `-coffreArgent` ouvre sur la seconde pièce ·
/// `-coffrePage <v>` fige le manège (0,5 = **le socle est libre**) ·
/// `-coffreTap` présente la pièce tout seul, `-coffreTapFerme` la repose.
struct CoffreV2Lab: View {
    /// ⚠️ Le banc passe par **l'enveloppe**, pas par la page nue : c'est
    /// `CoffreFortFlow` qui interroge les séances pour bâtir l'historique
    /// des gains. Monté en direct, le banc affichait « Rien encore » alors
    /// que la base était pleine — un faux négatif qui aurait pu passer pour
    /// un bug de la page.
    /// ⚠️ Le banc n'a PAS de base : la route `-coffre2` court-circuite
    /// l'ensemencement de `-demoData`, donc l'historique y est vide — et
    /// c'est JUSTE, ce n'est pas un défaut de la page. Pour juger la liste,
    /// `-coffreGains` monte la page avec un échantillon ; sans lui, le banc
    /// passe par l'enveloppe et montre ce que la base contient.
    private static let echantillon: [GainCoffre] = {
        let jour = 86_400.0
        return [
            (2.0, 240, "12 séries"), (4.0, 180, "9 séries"),
            (5.0, 100, "5 séries"), (9.0, 300, "15 séries"),
            (11.0, 160, "8 séries"), (14.0, 220, "11 séries"),
        ].map { (j, m, t) in
            GainCoffre(id: UUID(), date: Date(timeIntervalSinceNow: -j * jour),
                       montant: m, robe: nil, titre: t)
        }
    }()

    var body: some View {
        Group {
            if CommandLine.arguments.contains("-coffreGains") {
                CoffreV2Page(coins: 1240, gains: Self.echantillon)
            } else {
                CoffreFortFlow(coins: 1240)
            }
        }
        .preferredColorScheme(.dark)
    }
}
