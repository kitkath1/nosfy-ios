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
    static let piece: CGFloat = 130
    /// La case de la planche vaut ce multiple du diamètre (voir `recuit_pieces`).
    static let marge: CGFloat = 1.18
    /// La levée maximale de la card au tirage — la même bande que la home.
    static let levee: CGFloat = 140

    // ── LA SCÈNE
    /// Où la barre néon se pose À L'ÉCRAN (cadrage A du §15.5 : les deux tiers
    /// du bas restent noirs). ⚠️ Coût mesuré de cette remontée : la première
    /// ligne visible du mur passe de L 157 à L 171 — on ne perd que les gris
    /// les plus pâles, et rien d'autre.
    static let barreY: CGFloat = 0.375
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
    static let podiumY: CGFloat = 0.665
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
    var pas: CGFloat { W * 0.38 }
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

    static let or = PlanchePiece(nom: "piece-or", cases: 72, colonnes: 9)
    static let argent = PlanchePiece(nom: "piece-argent", cases: 72, colonnes: 9)

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
struct PiedCoffre: View {
    let compte: String
    let mot: String
    let ligne: String

    static let taille = CGSize(width: 352, height: 86)

    var body: some View {
        let forme = RoundedRectangle(cornerRadius: 26, style: .continuous)
        HStack(spacing: 15) {
            VStack(alignment: .leading, spacing: 4) {
                Text(compte)
                    .font(.inter(30, .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.96))
                    .contentTransition(.numericText())
                Text(mot.uppercased())
                    .font(.inter(9.5, .semibold))
                    .tracking(1.3)
                    .foregroundStyle(.white.opacity(0.40))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 106, alignment: .leading)
            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 1, height: 42)
            Text(ligne)
                .font(.inter(12.5, .medium))
                .lineSpacing(2)
                .foregroundStyle(.white.opacity(0.74))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .frame(width: Self.taille.width, height: Self.taille.height)
        .background {
            Color.clear.glassEffect(.regular.tint(Color.black.opacity(0.55)),
                                    in: forme)
        }
        .overlay(forme.strokeBorder(Color.white.opacity(0.07), lineWidth: 1))
        .overlay(alignment: .top) {
            LinearGradient(colors: [.clear, .white.opacity(0.17), .clear],
                           startPoint: .leading, endPoint: .trailing)
                .frame(height: 1)
                .padding(.horizontal, 40)
                .offset(y: 1)
        }
        // ⚠️ LA PAGE N'A QU'UN SEUL GESTE (voir `gestePage`) : rien ici ne doit
        // se mettre à arbitrer avec lui — c'est exactement la panne payée.
        .allowsHitTesting(false)
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
        let base = CoffreV2Cotes.piece * (1 - 0.13 * (1 - mm))
        self.diam = base * (1 + (CoffreV2Cotes.loupeF - 1) * ll) * (1 - 0.10 * ss)

        // ⚠️ **LA MARCHE** : sur le socle, ou au pied du socle. Deux hauteurs
        // franches, jamais un décalage cosmétique — c'est le socle qui fait la
        // différence de niveau, et c'est pour ça qu'elle se lit.
        let sol = scene.yBas + (scene.yHaut - scene.yBas) * mm
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
    var flou: CGFloat { CGFloat(5.0 * (1 - mont) + 4.0 * recul) }
    /// ⚠️ **ELLE S'ASSOMBRIT, ELLE NE S'EFFACE PAS.** Sur du noir, baisser
    /// l'opacité et baisser la lumière donnent presque la même image — mais
    /// l'une raconte « elle est sortie du faisceau » et l'autre « elle est en
    /// train de disparaître ». On raconte la première.
    var eteinte: Double { -0.24 * (1 - mont) - 0.16 * recul - 0.22 * sort }
    /// La tenue s'avance de 14 %. ⚠️ La profondeur se joue À DEUX : grossir
    /// seul se lit comme un zoom, c'est le RECUL de l'autre qui fabrique
    /// l'espace.
    var echelle: CGFloat { CGFloat(1 + 0.14 * prise - 0.12 * recul) }
}

// MARK: - La page

struct CoffreV2Page: View {
    let coins: Int
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
    @State private var tours: [Double] = [0, 0]
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

    /// LES DEUX PIÈCES : l'or (les pièces gagnées) puis la noire (à gagner).
    private static let manege: [PlanchePiece] = [.or, .argent]

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

    /// CE QU'ELLES VEULENT DIRE — le compte, son mot, et la ligne de verre.
    ///
    /// ⚠️ L'économie n'est tranchée qu'à MOITIÉ dans le dépôt :
    /// `CoffreFortPurse.perSeries = 20` dit ce qu'une série RAPPORTE, et rien
    /// nulle part ne dit ce qu'une pièce ACHÈTE. Le jour où le prix du booster
    /// est tranché, c'est ici qu'on l'écrit — et nulle part ailleurs.
    private func compte(_ i: Int) -> (String, String, String) {
        i == 0
            ? ("\(coins)", "coins earned",
               "20 coins for every set you finish.")
            : ("0", "legendary coins",
               "One opens a legendary card booster.")
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
                                sprite: Self.manege[loupeIdx].nom + "-mini",
                                plein: CGSize(width: sc.W, height: sc.H))
                        .offset(y: bas)
                }
                if filmVisible { film(sc) }
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
        let piedY = sc.podFin + 58
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
            VStack(alignment: .leading, spacing: 26) {
                ChipVerre(symbole: "chevron.left", label: "Fermer",
                          clarte: 1, action: onClose)
                VStack(alignment: .leading, spacing: 2) {
                    ligne("Find what", clair: true, i: 0)
                    ligne("you worked", clair: false, i: 1)
                    ligne("for.", clair: true, i: 2)
                }
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
            PiedCoffre(compte: compte(piedIdx).0, mot: compte(piedIdx).1,
                       ligne: compte(piedIdx).2)
                .id(piedIdx)
                .transition(.opacity)
            .position(x: sc.W / 2, y: piedY)
            .opacity(pageOp)
            .offset(y: monte)
        }
    }

    private func ligne(_ texte: String, clair: Bool, i: Int) -> some View {
        // La cascade de la home : `retard 0,14`, `duree 0,90` — trois lignes
        // font donc 1,18 s, et pas 0,50 (l'erreur du premier plan).
        let p = min(max((arrivee - 0.14 * Double(i)) / 0.90, 0), 1)
        return Text(texte)
            .font(.inter(30, .semibold))
            .tracking(-0.4)
            .foregroundStyle(encreMur.opacity(clair ? 0.95 : 0.55))
            .blur(radius: p > 0.995 ? 0 : 9 * (1 - p))
            .offset(y: 9 * (1 - p))
            .opacity(p)
    }

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

                PieceSprite(planche: pl, tour: tours[i], diametre: cadre)
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
                    if brut < 0 {
                        page = tanh(brut / 0.42) * 0.16
                    } else if brut > 1 {
                        page = 1 + tanh((brut - 1) / 0.42) * 0.16
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
                    let cible2 = min(max(but, 0), 1)
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
        if Self.argentDabord { page = 1; piedIdx = 1 }
        if let f = Self.pageFigee { page = f }
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
    var body: some View {
        CoffreV2Page(coins: 1240)
            .preferredColorScheme(.dark)
    }
}
