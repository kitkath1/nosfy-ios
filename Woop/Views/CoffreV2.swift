import AVFoundation
import CoreMotion
import os
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
    ///
    /// ⚠️⚠️ **TOUT CE PARAGRAPHE EST DE L'HISTOIRE : LA BARRE N'EXISTE PLUS**
    /// (28-08, « on passe en mode sombre noir »). La salle éclairée et son
    /// néon sont remplacés par un fond de SPOTLIGHT (`SalleFond`), et il n'y
    /// a plus rien à faire tomber sur une cote : la lumière descend du haut
    /// de l'écran. Le raisonnement reste écrit parce qu'il explique pourquoi
    /// le socle est là où il est — pas parce qu'il vaut encore.
    ///
    /// `barreSalle`, `barreX0/X1` et `ratioSalle` sont morts avec le film :
    /// c'étaient des cotes MESURÉES DANS UN FICHIER (pic de gradient à
    /// 0,5071). Ne jamais recaler une mise en page sur un pixel de vidéo.
    static let sourceY: CGFloat = 0.012

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
    ///
    /// ⚠️ **0,5564 → 0,6064 (29-08) : LA COTE N'EST PLUS UN CHOIX.** Le socle
    /// vit dans le fond (`coffre-arche`) ; sa surface de pose tombe où elle
    /// tombe. Mesurée au liseré : 0,742 de l'image, remontée de 130 px pour
    /// que le pied retrouve son air (voir `bake_arche.py`). Toucher à ce
    /// nombre, c'est décoller les objets de leur socle.
    ///
    /// ⚠️ **CETTE COTE N'EST PLUS À NOUS : elle est cuite dans le fond.** Elle
    /// et `MONTE` dans le bake doivent bouger ENSEMBLE.
    static let podiumY: CGFloat = 0.5569
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

    /// ⚠️⚠️ **LA SOURCE DE LA LUMIÈRE — ET ELLE N'EST PLUS UNE BARRE.**
    ///
    /// Elle s'appelait `barre` et c'était le néon de la salle éclairée : tout
    /// le décor GLISSAIT pour que le néon du film tombe dessus. La salle est
    /// morte (§20), mais **deux vues partaient de là** et ne peuvent pas
    /// rester orphelines : `Projecteur` (le faisceau qui désigne l'objet) et
    /// `Atterrissage` (l'onde du choc). Elles gardent donc leur ancre — c'est
    /// maintenant **le haut de l'écran**, d'où descend le spot.
    ///
    /// C'est plus simple que ce qu'on remplace : une constante au lieu d'un
    /// calage sur un pixel du film (`barreSalle = 0,5071`, mesuré au pic de
    /// gradient — voilà ce qu'on ne fera plus jamais).
    var barre: CGRect {
        CGRect(x: W * 0.30, y: CoffreV2Cotes.sourceY * H - 1,
               width: W * 0.40, height: 2)
    }

    // ── Le socle
    //
    // ⚠️⚠️ **LE SOCLE VIT MAINTENANT DANS LE FOND** (29-08, « non, enlève le
    // nôtre »). `coffre-podium.png` a disparu de la page : c'est celui de
    // l'arche qui porte les objets. Ces cotes ne se déduisent donc plus des
    // proportions d'un PNG (`CoffreV2Podium`) mais de mesures faites SUR LE
    // FOND, au liseré orange saturé — la luminance ne pouvait pas servir, les
    // caustiques du sol traversent toute la largeur.
    //
    // Tout le reste de la page continue de s'y raccrocher sans une ligne de
    // changement : la pose des objets, la MARCHE entre le dessus et le sol des
    // voisins, l'atterrissage, la gerbe, le pied. C'était le pari du §20.1 —
    // il tient, à condition que ces quatre cotes disent la vérité.

    /// La largeur du plateau, mesurée : 0,447 de la largeur d'écran.
    var podL: CGFloat { W * 0.447 }
    /// De la surface de pose à la base : 0,742 → 0,860 de l'image, laquelle
    /// couvre 0,8173 de l'écran → 0,0965 H.
    var podH: CGFloat { H * 0.0965 }
    /// LE DESSUS DU SOCLE — la surface où un objet TOUCHE.
    var yHaut: CGFloat { CoffreV2Cotes.podiumY * H }
    /// LE PIED DU SOCLE — le sol de celui qui attend à côté, dans le noir.
    var yBas: CGFloat { yHaut + podH }
    /// ⚠️ Son plateau n'est PAS centré : 0,506 W, mesuré. Un objet posé à
    /// W/2 flotterait de 7 pt à côté de son axe — invisible seul, criant
    /// quand la flaque l'éclaire.
    var podCentre: CGPoint { CGPoint(x: W * 0.506, y: yHaut + podH / 2) }
    /// ⚠️ **OÙ LE DÉCOR MEURT — ET CE N'EST PAS OÙ LE SOCLE POSE.** Mesuré
    /// sur l'image cuite, la luminance de la bande centrale tombe à zéro
    /// seulement à **0,715 H** : les anneaux du socle et leur lueur
    /// descendent bien plus bas que sa base (0,653). Déduit de `yBas`, le
    /// pied remontait de 60 pt et **la barre de crans se posait SUR le
    /// socle** — vu sur capture, deux fois.
    ///
    /// Une empreinte VISUELLE ne se déduit pas d'une cote de géométrie : elle
    /// se mesure sur l'image qu'on affiche.
    var podFin: CGFloat { H * 0.715 }

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
/// ⚠️⚠️ **LES FONDS VIVENT DANS `Woop/Media`, DONC `Image(nom)` NE LES TROUVE
/// PAS.** Ce sont des ressources NUES du bundle, pas des entrées de catalogue :
/// `Image("coffre-arche")` cherche dans `Assets.xcassets`, ne trouve rien, et
/// **ne dit rien** — la vue est simplement vide. La loi est déjà écrite sur
/// `SachetVignette` ; elle m'a repris ici.
///
/// ⚠️ Ce que ça a caché : `Image("coffre-spot")` échouait AUSSI depuis le
/// début. L'image de pose du spotlight — celle dont j'ai écrit qu'elle était
/// OBLIGATOIRE parce que le décodeur du simulateur rate des images — n'a
/// jamais été affichée une seule fois. Un filet de sécurité qu'on croit posé
/// et qui n'existe pas est pire que pas de filet.
///
/// ⚠️ Et elles sont RETENUES : un `UIImage(contentsOfFile:)` par image de
/// geste rechargerait 3 Mo de PNG à chaque tour de doigt.
enum FondCoffre {
    private static let cache = OSAllocatedUnfairLock(initialState: [String: Image]())

    static func image(_ nom: String) -> Image? {
        cache.withLock { c in
            if let deja = c[nom] { return deja }
            guard let chemin = Bundle.main.path(forResource: nom, ofType: "png"),
                  let ui = UIImage(contentsOfFile: chemin) else { return nil }
            let im = Image(uiImage: ui)
            c[nom] = im
            return im
        }
    }
}

/// ⚠️⚠️ **LE GYROSCOPE — ET CE N'EST PAS « BOUGER LE FOND ».**
///
/// Sa demande (29-08) : *« mets l'image de fond en mode gyroscope ? »*. Le
/// piège est entier dans la géométrie de cette page : **le socle vit DANS le
/// fond** depuis l'arche (§24). Bouger l'image seule, c'est faire glisser
/// l'estrade sous l'objet posé dessus — la pièce se retrouve dans le vide.
///
/// Le mouvement est donc celui d'un **diorama**, pas d'un calque :
///
///   • le décor (arche + socle + néons + flaques) glisse de ±7 pt,
///   • ce qui est POSÉ dessus (l'objet, son faisceau, la poudre) de ±10 pt,
///   • le CHROME (chevron, titre, pill, crans, pied) ne bouge JAMAIS.
///
/// Les 3 pt d'écart sont la parallaxe : l'objet lévite au-dessus du socle,
/// il balaie donc un peu plus que lui quand la boîte tourne. C'est assez pour
/// donner la profondeur, assez peu pour qu'il reste sur son estrade.
///
/// ⚠️ **L'ATTITUDE DE RÉFÉRENCE DÉRIVE, ET C'EST OBLIGATOIRE.** Figer le
/// neutre sur le premier échantillon, c'est condamner la page à la posture
/// qu'on avait à l'ouverture : couché sur une table puis relevé, tout est en
/// butée. La référence suit donc l'attitude courante avec une constante de
/// ~4 s : la page réagit au MOUVEMENT, et se recentre dès qu'on tient droit.
///
/// ⚠️ **LE SIMULATEUR N'A PAS DE GYROSCOPE, ET C'EST LE PIÈGE À NON-
/// RÉGRESSION.** `isDeviceMotionAvailable` y est faux. Si le sur-cadrage
/// (`echelle`) s'appliquait quand même, tous les bancs `-coffre*` rendraient
/// un décor zoomé de 5 % **pour rien** — et je jugerais des captures qui ne
/// sont pas ce que le téléphone affiche. D'où `actif` : sans capteur, la
/// modification est l'IDENTITÉ, au pixel près.
@MainActor
final class GyroFond: ObservableObject {
    static let shared = GyroFond()

    /// Inclinaison normalisée dans [−1, 1] sur chaque axe. `.zero` = neutre.
    @Published private(set) var incl: CGSize = .zero
    /// Vrai seulement quand le capteur tourne VRAIMENT (téléphone, page
    /// ouverte). C'est lui qui autorise le sur-cadrage.
    @Published private(set) var actif = false

    /// ⚠️ `-coffreSansGyro` l'éteint — indispensable pour mesurer la cadence :
    /// une sonde qui compare deux régimes doit pouvoir figer celui-ci.
    private static let coupe = CommandLine.arguments.contains("-coffreSansGyro")

    private let mm = CMMotionManager()
    private var refRoll = 0.0
    private var refPitch = 0.0
    private var amorce = false
    private var abonnes = 0

    /// ±17° de course utile. Au-delà, on est en butée : on ne regarde plus
    /// l'écran, on le montre à quelqu'un.
    private let plage = 0.30
    /// Suivi de la référence : 0,004 à 60 Hz ≈ 4,2 s de constante de temps.
    private let derive = 0.004
    /// Lissage de la sortie. Sans lui, le bruit du capteur fait vibrer le
    /// décor de 1 pt en permanence — c'est visible, et ça se lit comme un bug.
    private let lisse = 0.10

    private init() {}

    /// ⚠️⚠️ **LE BANC DE L'INCLINAISON — ET IL N'EST PAS UN CONFORT.** Le
    /// simulateur n'a pas de gyroscope : sans ce drapeau, **la seule chose que
    /// je ne peux PAS voir est justement celle qui casse** — le bord noir
    /// découvert par le décalage, et l'objet qui glisse de son socle en butée.
    /// Les deux ne se voient qu'à l'extrême, et l'extrême ne se produit jamais
    /// tout seul.
    ///
    ///     -coffreIncl 1,m1        // droite en butée, bas en butée
    ///     -coffreIncl m1,0        // gauche en butée, à plat
    ///
    /// ⚠️ C'est une paire `-clé valeur` : elle vit dans le domaine d'arguments
    /// de `UserDefaults`, **pas** dans `CommandLine.arguments` (piège payé deux
    /// fois sur cette page).
    ///
    /// ⚠️⚠️ **ET `m` VEUT DIRE MOINS, PARCE QUE LE TIRET EST INTERDIT ICI —
    /// PAYÉ AU BANC, ET C'EST UN FAUX NÉGATIF PARFAIT.** `-coffreIncl -1,-1`
    /// s'est lancé sans une erreur et a rendu une capture… identique au
    /// neutre : `NSUserDefaults` lit tout jeton commençant par un tiret comme
    /// une NOUVELLE CLÉ, jamais comme la valeur de la précédente. La moitié
    /// négative de la course était donc intestable **en se présentant comme
    /// testée** — et c'est justement le côté où le bord se découvre.
    private static let force: CGSize? = {
        guard let t = UserDefaults.standard.string(forKey: "coffreIncl")
        else { return nil }
        let p = t.split(separator: ",")
            .map { Double($0.replacingOccurrences(of: "m", with: "-")) ?? 0 }
        guard !p.isEmpty else { return nil }
        return CGSize(width: p[0], height: p.count > 1 ? p[1] : 0)
    }()

    func demarrer() {
        abonnes += 1
        guard abonnes == 1, !Self.coupe else { return }
        if let f = Self.force { actif = true; incl = f; return }
        guard mm.isDeviceMotionAvailable, !mm.isDeviceMotionActive else { return }
        mm.deviceMotionUpdateInterval = 1.0 / 60.0
        mm.startDeviceMotionUpdates(to: .main) { [weak self] m, _ in
            guard let self, let m else { return }
            self.echantillon(roll: m.attitude.roll, pitch: m.attitude.pitch)
        }
        actif = true
    }

    func arreter() {
        abonnes = max(abonnes - 1, 0)
        guard abonnes == 0 else { return }
        mm.stopDeviceMotionUpdates()
        actif = false
        amorce = false
        incl = .zero
    }

    private func echantillon(roll: Double, pitch: Double) {
        if !amorce { refRoll = roll; refPitch = pitch; amorce = true }
        refRoll += (roll - refRoll) * derive
        refPitch += (pitch - refPitch) * derive
        func borne(_ v: Double) -> Double { min(max(v / plage, -1), 1) }
        // ⚠️ SIGNE : le décor part À L'OPPOSÉ de l'inclinaison, comme le fond
        // d'écran d'iOS. Pencher à droite, c'est regarder la scène par la
        // droite : on découvre son flanc droit, donc le contenu file à gauche.
        let cx = -borne(roll - refRoll)
        let cy = -borne(pitch - refPitch)
        incl = CGSize(width: incl.width + (cx - incl.width) * lisse,
                      height: incl.height + (cy - incl.height) * lisse)
    }
}

/// ⚠️ **UN `ViewModifier`, PAS UN `@State` DANS LA PAGE — ET C'EST LA LOI DE
/// LA MAISON** (« la page qui se ré-évalue par image »). Un `@State`
/// d'inclinaison écrit 60 fois par seconde sur `CoffreV2` rejouerait le corps
/// ENTIER de la page à chaque échantillon : les quatre objets, leurs flaques,
/// le pied, la pill. Ici l'abonnement vit dans le modificateur : seul son
/// `body(content:)` — deux modificateurs de géométrie sur un contenu opaque —
/// est réévalué.
struct Parallaxe: ViewModifier {
    @ObservedObject private var gyro = GyroFond.shared
    let ampl: CGSize
    /// Sur-cadrage. ⚠️ **IL EST OBLIGATOIRE DÈS QUE LE FOND BOUGE** : l'arche
    /// est cuite EXACTEMENT à la taille de l'écran, la décaler d'un point
    /// découvre un point de noir sur le bord opposé.
    var echelle: CGFloat = 1
    /// ⚠️ **L'ANCRE EST LE SOCLE, JAMAIS LE CENTRE DE L'ÉCRAN.** Agrandir
    /// autour du centre déplacerait la surface de pose de 9 pt — c'est-à-dire
    /// exactement le décollage qu'on cherche à éviter. Ancré sur le socle,
    /// `yHaut` est INVARIANT : seul le décor autour respire.
    var ancre: UnitPoint = .center

    func body(content: Content) -> some View {
        content
            .scaleEffect(gyro.actif ? echelle : 1, anchor: ancre)
            .offset(x: gyro.incl.width * ampl.width,
                    y: gyro.incl.height * ampl.height)
    }
}

extension View {
    func parallaxe(_ ampl: CGSize, echelle: CGFloat = 1,
                   ancre: UnitPoint = .center) -> some View {
        modifier(Parallaxe(ampl: ampl, echelle: echelle, ancre: ancre))
    }
}

/// Les deux amplitudes du diorama, et le sur-cadrage qui les rend possibles.
enum CoffreParallaxe {
    /// Le décor : arche, socle, néons, flaques.
    static let fond = CGSize(width: 7, height: 4)
    /// Ce qui est POSÉ dessus : l'objet, son faisceau, la poudre du passage.
    static let objets = CGSize(width: 10, height: 5.5)
    /// ⚠️ **1,05 N'EST PAS UN GOÛT, C'EST LA MARGE DE `fond`.** Ancré au socle
    /// (x 0,506 · y 0,5569) sur un écran de 402 × 874, il découvre 9,9 pt à
    /// droite, 10,2 à gauche, 24 en haut et 19 en bas — soit ≥ 7 et ≥ 4
    /// partout. Le baisser, c'est laisser apparaître le bord noir.
    ///
    /// ⚠️ Ce qu'il ROGNE a été vérifié sur l'image : 24 pt en haut, où l'arche
    /// n'a que ses tubes verticaux qui sortaient DÉJÀ du cadre, et 19 pt en
    /// bas, où `bake_arche.py` a effacé au noir pur (mesuré : max = 0 sur les
    /// 222 dernières lignes). Rien de dessiné n'est perdu.
    static let echelle: CGFloat = 1.05
    static let ancre = UnitPoint(x: 0.506, y: CoffreV2Cotes.podiumY)
}

struct SalleFond: View, Equatable {
    let scene: SceneCoffre
    let clarte: Double

    /// largeur / hauteur de `coffre-spot-loop.mp4` (1206 × 1608).
    ///
    /// ⚠️ Elle change avec la COUPE du bake : couper plus haut raccourcit le
    /// fichier. Les deux doivent bouger ENSEMBLE — une vue qui garde
    /// l'ancienne cote étire la vidéo sans rien dire.
    static let ratio: CGFloat = 1206.0 / 1608.0

    /// ⚠️⚠️ **LA SALLE ÉCLAIRÉE EST MORTE ; LE SPOT PREND SA PLACE, EN
    /// MOUVEMENT** (28-08 « on passe en mode sombre noir », puis 29-08
    /// « t'as pas utilisé la vidéo, t'as mis un vieux spotlight »).
    ///
    /// ⚠️ **LE PREMIER JET PARTAIT DU MAUVAIS RENDU, ET LA MESURE LE DIT** :
    /// `spotlight .png` porte **514 pixels de braise** pour une luminance
    /// moyenne de 8,5, là où la vidéo en porte **3 738** pour 20,3. Sept fois
    /// plus d'étincelles. J'avais comparé les deux SUR LA TEINTE (V−B : +9
    /// contre +8) et conclu que c'était le même rendu — **deux mesures qui
    /// concordent sur une couleur ne disent rien du dessin.**
    ///
    /// La boucle est cuite par `tools/coffre-v2/bake_spot.py` : socle coupé
    /// (il reste un PNG à part, les flaques le prennent comme MASQUE), mise
    /// en **ping-pong** parce que le travelling de la source est monotone et
    /// ne boucle pas, et recuite à 1206 de large — décoder 2160 pour un
    /// écran qui en demande 1206, c'est quatre fois trop de pixels par image.
    ///
    /// ⚠️ **AJUSTÉE À LA LARGEUR, POSÉE EN HAUT — PAS ÉTIRÉE.** Un
    /// `aspectFill` rognerait 31 % de la largeur pour rien. Ici le spot
    /// couvre le haut jusqu'à ~0,69 H, et le bas reste noir : c'est
    /// exactement là que vivent le socle (0,556 H) et son sol. Son bord bas
    /// est éteint EN COSINUS **dans le fichier** — un `.mask` sur une couche
    /// vidéo forcerait une passe hors écran à chaque image.
    ///
    /// ⚠️ **L'IMAGE DE POSE EST OBLIGATOIRE, ET C'EST UNE LEÇON PAYÉE** : le
    /// décodeur du simulateur est LOGICIEL, il rate des images, et sans elle
    /// le raté DEVIENT un glitch noir plein écran.
    /// ⚠️ `-coffreSpot` ramène le spotlight en boucle — le fond d'avant, gardé
    /// pour comparer les deux SUR LES QUATRE PAGES. C'est là que ce décor se
    /// juge : sous la pièce d'argent (froide) et le booster noir (violet),
    /// une arche franchement ORANGE est un pari, pas un réglage.
    static let spot = CommandLine.arguments.contains("-coffreSpot")

    var body: some View {
        Group {
            if SalleFond.spot {
                let h = scene.W / SalleFond.ratio
                ZStack {
                    FondCoffre.image("coffre-spot")?
                        .resizable().interpolation(.high)
                    SpotVideo()
                }
                .frame(width: scene.W, height: h)
                .position(x: scene.W / 2, y: h / 2)
            } else {
                // ⚠️ Cuite EXACTEMENT à la taille de l'écran (1206 × 2622) :
                // le glissement, le fondu des bords et l'extinction du bas
                // vivent dans le fichier, pas ici. Une vue qui recadre un
                // décor est une vue qui peut le décaler d'un demi-point sans
                // que personne ne le voie — et ici un demi-point décale le
                // SOCLE, donc tous les objets.
                FondCoffre.image("coffre-arche")?
                    .resizable()
                    .interpolation(.high)
                    .frame(width: scene.W, height: scene.H)
                    .position(x: scene.W / 2, y: scene.H / 2)
            }
        }
        // LE DÉCOR SE RETIRE quand on ouvre la pièce : c'est le théâtre, et il
        // se fait en BAISSANT le reste, jamais en posant un voile (un voile
        // grise l'objet aussi). ⚠️ Et il ne MONTE jamais : éclaircir un décor
        // fait apparaître ses bords (§15.15, §16.1).
        .opacity(clarte)
    }
}

/// LA BOUCLE DU SPOT. L'école exacte des exos et de la home : `AVPlayerLooper`
/// (**jamais** un seek sur `didPlayToEndTime`), looper RETENU par le
/// coordinateur, muet, et **le fond de la couche TRANSPARENT** — c'est l'image
/// de pose dessous qui doit se voir quand le décodeur rate une image, sinon le
/// raté DEVIENT le glitch noir.
///
/// ⚠️ Elle remplace `SalleVideo`, supprimée hier avec le mur éclairé. Elle est
/// plus simple : plus de glissement pour faire tomber un néon sur une cote,
/// plus de calage sur un pixel du film (`barreSalle = 0,5071` restera l'exemple
/// de ce qu'on ne refait pas). Elle se pose, et c'est tout.
struct SpotVideo: UIViewRepresentable {
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
        // ⚠️ `resizeAspectFill` DÉBORDE SES BORNES : un `CALayer` ne masque pas
        // ses enfants, et le `clipShape` de SwiftUI ne rattrape pas une couche
        // UIKit. Les deux masques, pas un seul.
        v.clipsToBounds = true
        v.playerLayer.masksToBounds = true

        guard let url = Bundle.main.url(forResource: "coffre-spot-loop",
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

// MARK: - La pill du compte, la barre fine, l'en-tête de l'objet (§29, 30-08)

/// LA PILL DU COMPTE — un glyphe, un nombre, et rien d'autre.
///
/// ⚠️ C'est l'ancienne `PillPrix` DESCENDUE dans le pied, sans son liquide
/// (30-08, la grammaire d'Opal — `tools/coffre-v2/PLAN-PIED-COFFRE.md` §29) :
/// la progression vit maintenant dans `BarreFine`, sous elle. Le glyphe dit
/// l'objet — la pièce (sprite, cases de 320 px) ou le sachet
/// (`SachetVignette` à 15 × 26, la taille validée sur la pill du profil).
///
/// ⚠️ `.clear` et jamais `.regular` : pas la recette de `PillBooster`
/// (`.regular` teinté, l'interdit de la maison). Et posée sur du NOIR ABSOLU,
/// ce verre n'a rien à réfracter (`HomeNuit:536`) — le repli connu est la
/// recette de `PiecesNotif` (noir 0,35 + `.clear` derrière). À juger sur
/// capture, pas d'avance.
struct PillCompte: View {
    enum Glyphe {
        case piece(PlanchePiece)
        case sachet(RobeBooster)
    }

    let glyphe: Glyphe
    let nombre: Int

    var body: some View {
        HStack(spacing: 9) {
            image
            Text("\(nombre)")
                .font(.inter(17, .semibold))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.95))
                .contentTransition(.numericText())
        }
        .padding(.leading, 13)
        .padding(.trailing, 17)
        .frame(height: 44)
        .glassEffect(.clear, in: .capsule)
        .overlay(Capsule().strokeBorder(.white.opacity(0.13), lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 12, y: 4)
    }

    @ViewBuilder
    private var image: some View {
        switch glyphe {
        case .piece(let p):
            // ⚠️ Le sprite de la pièce, pas un glyphe SF : c'est LA pièce de
            // l'app. ⚠️ Défaut connu (§27.6) : à 22 pt l'or et l'argent se
            // distinguent mal — c'est le NOM en haut qui les nomme.
            PieceSprite(planche: p, tour: 0, diametre: 22)
        case .sachet(.lune):
            // ⚠️ LE SACHET DÉTOURÉ DE LA CARD DE FIN (30-08 : « prends le
            // booster détouré Lune de la pop-up de fin, on a réussi à le
            // faire et c'est good ») : `booster-hero`, l'asset de
            // `BoosterCard` (795 × 1334, alpha réel, h/w 1,69) — un objet du
            // catalogue, donc `Image(_:)` le trouve. Le noir n'a pas encore
            // son détouré : il garde sa vignette.
            Image("booster-hero")
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 26)
        case .sachet(let r):
            SachetVignette(largeur: 15, hauteur: 26, robe: r)
                .frame(width: 20, height: 24)
        }
    }
}

/// CE QUE LA BARRE DIT — des DONNÉES, jamais des valeurs rendues.
///
/// ⚠️ `part` et la légende ne se calculent PAS dans `variantes` (relue six
/// fois par passe de corps) : une horloge posée là ne bougerait que quand la
/// page se réévalue. La barre les dérive elle-même, et seul le cas `.horloge`
/// est enveloppé dans un `TimelineView` (§29.11 ④).
enum JaugeCoffre {
    /// « 🪙 40 / 100 » — ce qu'on a vers ce que ça coûte, et DANS QUELLE
    /// monnaie : la mini pièce devant la légende (30-08, « petite pièce or
    /// pour le rappel, on comprend pas »).
    case compte(courant: Int, cible: Int, monnaie: PlanchePiece)
    /// Le versement quotidien. `disponible` = il est dû (il se réclame au tap
    /// du Claim — décision du 30-08, `tools/annonces/PLAN-COFFRE-ANNONCES.md`
    /// §5.3) ; sinon `prochain` = le prochain minuit de la maison, RENDU par
    /// le serveur (`etat_coffre().retour_prochain`), jamais calculé ici.
    case horloge(montant: Int, disponible: Bool, prochain: Date)
}

/// LA BARRE FINE — celle d'Opal, mesurée (§29.3) : 3 pt, un rail à blanc
/// 0,10, un remplissage CLAIR de bout en bout, aucun pouce, et la légende
/// DESSOUS, à 15.
///
/// ⚠️ Le §27 avait écrit « une barre est plate par nature, on la remplace ».
/// C'est Kathryn qui la rétablit, avec un modèle sous les yeux — et le modèle
/// tient parce qu'il ne demande PAS à la barre d'être belle : il la fait
/// minuscule et lui donne une légende. On ne rejoue pas le §26.4 : pas de
/// dégradé sombre (l'œil lit un dégradé par son arrêt le plus sombre), pas de
/// tête (un disque au bout d'une barre est un pouce), pas de 5 pt.
///
/// ⚠️ `Animatable` sur `remplie` (l'arrivée — le même ressort que l'ancienne
/// pill, `:2690`) : la largeur rendue est `part × remplie`, et c'est SwiftUI
/// qui interpole `remplie`. Une courbe écrite dans le corps ne serait jamais
/// jouée (mémoire `woop-piege-rampes-withanimation`).
struct BarreFine: View, Animatable {
    let jauge: JaugeCoffre
    let lueur: Color
    var remplie: Double

    var animatableData: Double {
        get { remplie }
        set { remplie = newValue }
    }

    static let largeur: CGFloat = 240
    static let epaisseur: CGFloat = 3

    var body: some View {
        switch jauge {
        case .compte(let courant, let cible, let monnaie):
            rendu(part: Self.part(courant, sur: cible),
                  legende: "\(courant) / \(cible)", monnaie: monnaie)
        case .horloge(let montant, let disponible, let prochain):
            // ⚠️ La minute, pas l'image : une légende en heures n'a pas
            // besoin de plus, et la page n'est pas relue (loi §2). Le test
            // « minuit passé » vit ici aussi.
            TimelineView(.periodic(from: .now, by: 60)) { ctx in
                let h = Self.horloge(montant: montant, disponible: disponible,
                                     prochain: prochain, now: ctx.date)
                rendu(part: h.part, legende: h.legende, monnaie: nil)
            }
        }
    }

    private static func part(_ courant: Int, sur cible: Int) -> Double {
        guard cible > 0 else { return 0 }
        return min(max(Double(courant) / Double(cible), 0), 1)
    }

    /// L'horloge du +10 : la part du jour écoulée, et ce qu'il reste.
    /// ⚠️ Passé `prochain`, le versement est DÛ : la barre passe à « to
    /// claim » localement, jusqu'à la prochaine lecture du serveur — jamais
    /// une horloge neuve à « in 24 h » sur un versement dû (§29.7).
    static func horloge(montant: Int, disponible: Bool, prochain: Date,
                        now: Date) -> (part: Double, legende: String) {
        // En toutes lettres (30-08 : « +10 pièces in 6 hours par exemple »).
        let restant = prochain.timeIntervalSince(now)
        if disponible || restant <= 0 {
            return (1, "+\(montant) coins to claim")
        }
        let part = min(max(1 - restant / 86_400, 0), 1)
        let minutes = Int((restant / 60).rounded(.up))
        if minutes < 60 {
            return (part, "+\(montant) coins in \(minutes) minute\(minutes == 1 ? "" : "s")")
        }
        let heures = Int((restant / 3600).rounded())
        return (part, "+\(montant) coins in \(heures) hour\(heures == 1 ? "" : "s")")
    }

    private func rendu(part: Double, legende: String,
                       monnaie: PlanchePiece?) -> some View {
        VStack(spacing: 16) {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.10))
                    .frame(width: Self.largeur, height: Self.epaisseur)
                // Clair → clair : la lueur de la page ÉCLAIRCIE, vers le
                // blanc. Aucun arrêt sombre — Opal va de L 220 à L 250.
                Capsule()
                    .fill(LinearGradient(
                        colors: [lueur.mix(with: .white, by: 0.55), .white],
                        startPoint: .leading, endPoint: .trailing))
                    .frame(width: Self.largeur * CGFloat(part * remplie),
                           height: Self.epaisseur)
            }
            HStack(spacing: 6) {
                // La mini pièce dit la monnaie de la jauge — sur la page du
                // sachet, sans elle « 40 / 100 » ne dit pas de quoi.
                if let monnaie {
                    PieceSprite(planche: monnaie, tour: 0, diametre: 16)
                }
                Text(legende)
                    .font(.inter(15, .medium))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.60))
            }
        }
    }
}

/// L'EN-TÊTE DE L'OBJET — son nom, et une phrase qui dit ce que c'est.
///
/// Il prend la place de l'ancienne pill de prix, au-dessus de l'objet
/// (0,222 H), à la même hauteur qu'elle (≈ 40 pt) : rien d'autre ne bouge.
/// « Je veux le nom » (30-08) — 14, dégradé, casse de phrase (« Or Piece »,
/// pas des capitales : elle les a refusées deux fois ce jour-là, `c56db68`
/// et `9a7c429`).
///
/// ⚠️ **PAS `titleFade`** : il va de blanc à 0,25, fait pour un titre de 30.
/// Sur une ligne de 14 la diagonale devient quasi horizontale et la dernière
/// lettre tombe à 0,25 — « Gold Coi_ ». Un fondu court (1,00 → 0,55) garde le
/// dégradé ET la dernière lettre. À MESURER sur capture (§29.6).
struct EnTeteObjet: View {
    let nom: String
    let phrase: String

    private static let fade = LinearGradient(
        stops: [.init(color: .white, location: 0),
                .init(color: .white.opacity(0.55), location: 1)],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    var body: some View {
        VStack(spacing: 5) {
            Text(nom)
                .font(.inter(14, .semibold))
                .foregroundStyle(Self.fade)
            // Une ligne, sans tiret (verdict). Le facteur est un filet : la
            // plus longue phrase mesurée tient à 1,0 sur 320.
            Text(phrase)
                .font(.inter(15, .medium))
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(width: 320)
        .shadow(color: .black.opacity(0.45), radius: 10, y: 2)
    }
}

/// CE QUE CHAQUE PAGE DIT — le nom et sa phrase en haut, la pill et sa barre
/// en bas (§29). *Le pied décrit toujours l'objet posé sur le socle.*
struct PiedVariante {
    /// Le nom de l'objet — en haut, à la place de l'ancienne pill de prix.
    let nom: String
    /// Une ligne, sans tiret : ce que c'est.
    let phrase: String
    /// La pill du pied : le glyphe de l'objet et son nombre (solde ou sachets).
    let glyphe: PillCompte.Glyphe
    let nombre: Int
    /// Une petite ligne SOUS la pill, sur les pages de pièces (30-08 : « ça
    /// fait trop vide ») — la règle qui les gagne, en un souffle.
    let sousPill: String?
    /// La barre fine sous la pill — nil sur les pages argent et noire (rien
    /// ne s'accumule VERS ces objets : une jauge exposerait la pitié, ou
    /// écrirait « 2 / 1 » — tranché le 30-08, « page argent et noir sans
    /// barre »).
    let jauge: JaugeCoffre?
    /// Non-nil = c'est une page de BOOSTER : elle porte le bouton d'ouverture.
    let robe: RobeBooster?
    /// LA PORTE DE L'HISTOIRE (30-08 : « un bouton Discover history qui mène
    /// sur la page avec l'histoire et la vidéo ») — sur les pages de PIÈCES,
    /// dont le bas n'avait pas de bouton : l'or ouvre l'histoire du sachet
    /// Lune, l'argent celle du légendaire (chaque récit parle de sa pièce).
    /// Les pages de sachets y vont déjà par le second tap sur l'objet.
    let histoire: RobeBooster?
    /// Le bouton — actif (le primaire) ou mat (« Locked », même place, même
    /// hauteur : le verrouillé se dit par la MATIÈRE, 5ᵉ loi d'Opal). Les
    /// pages de pièces n'en ont pas.
    let bouton: (mot: String, actif: Bool)?
    /// ⚠️ LA COULEUR DE L'OBJET POSÉ SUR LE SOCLE — la même que sa flaque
    /// (`ObjetSocle.lueur`) : la barre et l'aura du bouton appartiennent à la
    /// page, sinon ce sont deux systèmes de couleur sur un même écran.
    let lueur: Color
}

struct PiedCoffre: View {
    let v: PiedVariante
    /// 0 → 1 : l'arrivée de la barre (le ressort de l'ancienne pill).
    var remplie: Double = 1
    /// Ouvrir le manège de CETTE page — nil sur une page de pièce.
    var onOuvrir: (() -> Void)?
    /// Ouvrir l'histoire d'une robe (la vidéo, puis la page).
    var onHistoire: ((RobeBooster) -> Void)?

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
    /// ⚠️ **UNE SEULE GRILLE POUR LES QUATRE PAGES.** 146 → 196 : le bouton
    /// primaire fait 58 de haut, et il est là sur TOUTES les pages. La
    /// hauteur ne dépend donc plus de ce que la page a à dire — c'est ce qui
    /// fait qu'on lit un composant à deux états et non deux composants.
    ///
    /// ⚠️ Et le bouton est ANCRÉ EN BAS, pas empilé : sur les pages sans
    /// jauge il reste à la même hauteur qu'ailleurs. Un bouton qui se déplace
    /// d'une page à l'autre se cherche à chaque fois.
    /// ⚠️ 196 → 208 (30-08) : avec la ligne sous la pill ET la barre ET sa
    /// légende (page Or), le cadre de 196 était PLEIN — mesuré, 13 pt entre
    /// « +10 coins in 6 hours » et le bouton. Douze de plus, pris par le bas :
    /// l'ancre du pied descend de 6 (`contenu`), le haut et les crans ne
    /// bougent pas, le bas tombe à 838 — sous la zone sûre (874 − 34 = 840).
    static let taille = CGSize(width: 320, height: 208)

    var body: some View {
        VStack(spacing: 0) {
            // La grammaire d'Opal (§29.4) : la pill, [la petite ligne], la
            // barre et sa légende DESSOUS, le bouton ancré en bas. Le Spacer
            // absorbe, le bouton ne bouge pas d'une page à l'autre.
            // ⚠️ 12 → 24 entre la pill et la barre (30-08 : « bien espacer
            // davantage ») ; avec la ligne, 10 + 17 + 20.
            PillCompte(glyphe: v.glyphe, nombre: v.nombre)
                .allowsHitTesting(false)
            if let s = v.sousPill {
                Text(s)
                    .font(.inter(14, .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .padding(.top, 10)
                    .allowsHitTesting(false)
            }
            if let j = v.jauge {
                BarreFine(jauge: j, lueur: v.lueur, remplie: remplie)
                    .padding(.top, v.sousPill == nil ? 24 : 20)
                    .allowsHitTesting(false)
            }
            Spacer(minLength: 0)
            bouton
        }
        .frame(width: Self.taille.width, height: Self.taille.height,
               alignment: .top)
        .shadow(color: .black.opacity(0.55), radius: 14, y: 2)
    }

    // MARK: Les blocs — nommés, jamais inlinés
    //
    // ⚠️ Ce fichier SATURE le vérificateur de types sur les vues aux mesures
    // inlinées (payé deux fois). Chaque bloc sort en propriété.

    /// ⚠️ `highPriorityGesture` ET PAS un `Button` : le geste de la page est
    /// posé sur un ANCÊTRE qui couvre tout l'écran, et un bouton d'enfant s'y
    /// fait AFFAMER dès que le drag reconnaît — la loi payée sur le stop du
    /// player. La priorité haute passe devant.
    @ViewBuilder
    private var bouton: some View {
        if let b = v.bouton, b.actif, let onOuvrir {
            // ⚠️⚠️ **LE PRIMAIRE DE LA MAISON, ET IL FAUT LE PRENDRE EN
            // PRIORITÉ HAUTE.** `DiamondPrimaryButton` est bâti sur un
            // `Button` ; le geste de la page est posé sur un ANCÊTRE plein
            // écran avec `minimumDistance: 0`. Un `Button` d'enfant s'y fait
            // AFFAMER dès que le drag reconnaît — la panne payée sur le stop
            // du player, et déjà sur l'ancien « Ouvrir » de ce fichier.
            //
            // On lui passe donc une action VIDE et c'est notre tap prioritaire
            // qui commet l'ouverture : deux chemins vers la même action
            // risqueraient de l'ouvrir deux fois.
            DiamondPrimaryButton(title: b.mot) {}
                .allowsHitTesting(false)
                .contentShape(Capsule())
                .highPriorityGesture(TapGesture().onEnded { onOuvrir() })
        } else if let b = v.bouton {
            // ⚠️ **LE VERROUILLÉ SE DIT PAR LA MATIÈRE** (5ᵉ loi d'Opal,
            // §17.3) : même place, même hauteur, le bijou en moins. Du verre
            // mat et un mot qui dit ce qui manque — jamais un cadenas seul,
            // jamais un bouton grisé qui a l'air cassé.
            //
            // ⚠️ `glassEffect(.clear)` et pas `.regular` : le givré laiteux
            // est interdit, et ce qui passe dessous est du décor DOUX.
            // La casse des boutons (30-08, « même pour locked ») : une phrase.
            // ⚠️ LE MÊME LETTRAGE QUE LE PRIMAIRE (`BoutonPrimaire:156-158`,
            // 18 semibold, −0,2) : deux états d'un composant partagent la
            // casse ET le lettrage — tranché le 30-08 (« le mat oui »).
            Text(b.mot.enPhrase)
                .font(.inter(18, .semibold))
                .tracking(-0.2)
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .glassEffect(.clear, in: .capsule)
                .overlay(Capsule().strokeBorder(.white.opacity(0.10), lineWidth: 1))
                .allowsHitTesting(false)
        } else if let h = v.histoire, let onHistoire {
            // LA PORTE DE L'HISTOIRE — la même capsule de verre que le mat,
            // mais ÉVEILLÉE (encre à 0,92, liseré 0,16) : c'est une action,
            // pas un verrou. Même place, même hauteur, même lettrage que le
            // primaire — la grille des quatre pages tient.
            // ⚠️ Priorité haute, comme le primaire : un tap d'enfant sous le
            // geste de page se fait affamer.
            Text("Discover history".enPhrase)
                .font(.inter(18, .semibold))
                .tracking(-0.2)
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .glassEffect(.clear, in: .capsule)
                .overlay(Capsule().strokeBorder(.white.opacity(0.16), lineWidth: 1))
                .contentShape(Capsule())
                .highPriorityGesture(TapGesture().onEnded {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onHistoire(h)
                })
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
    /// 0 → 1 : le liquide de la pill MONTE à l'arrivée. ⚠️ C'est la seule
    /// chose qui bouge sur la page une fois posée : l'œil y va, donc il va
    /// sur la progression — l'animation fait le travail d'une explication.
    @State private var remplie: Double = 0
    @State private var gainsOuverts = false

    // ── L'HISTOIRE D'UN BOOSTER (29-08) : la vidéo, puis la page.
    /// La robe dont l'histoire est ouverte ; nil = fermée.
    @State private var histoire: RobeBooster?
    /// true pendant la cinématique, false une fois sur la page.
    @State private var histoireFilm = false
    @State private var histoireLecteur: AVPlayer?
    /// 0 → 1 : la cascade d'arrivée de la page (titre, corps, pièce).
    @State private var histoireApparue: Double = 0
    /// « Passer » n'apparaît qu'après une seconde : un geste ne s'annonce pas,
    /// mais une porte doit finir par être visible.
    @State private var passerVisible = false
    @State private var tireHistoire: CGFloat = 0
    @State private var tirHistNe: Date?
    @State private var finFilm: NSObjectProtocol?
    /// 0 → 360 en boucle : la position du reflet qui court autour des anneaux.
    @State private var tourNeon: Double = 0
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
    /// `-coffreStory noir|lune` : la cinématique puis la page, d'entrée.
    ///
    /// ⚠️ **UN DRAPEAU À VALEUR SE LIT DANS `UserDefaults`, PAS DANS
    /// `CommandLine.arguments`** — et la maison l'avait déjà payé sur
    /// `-coffrePage` (voir `nombre(_:)` juste en dessous, dont le commentaire
    /// dit « mesuré au print »). iOS parse les paires `-clé valeur` de la
    /// ligne de commande dans le domaine d'arguments de `UserDefaults` ;
    /// chercher « -coffreStory » dans `arguments` ne trouve rien, **et ne dit
    /// rien**. Ma page ne s'ouvrait pas, sans la moindre erreur.
    private static let storyAuto: RobeBooster? = {
        guard let v = UserDefaults.standard.string(forKey: "coffreStory")
        else { return nil }
        return v == "noir" ? .noire : .lune
    }()

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

    /// CE QUE CHAQUE PAGE DIT — quatre faits, et **une seule source pour
    /// tous**, depuis le 29-08.
    ///
    /// ⚠️ Le prix vivait ici, en dur, à 100 — pendant que `ProfilLune.prix`
    /// disait 20. Deux écrans enchaînés depuis la même page, deux prix pour le
    /// même objet. Il est maintenant lu (`etat_coffre().prix_booster`), et la
    /// constante a disparu : c'est la seule façon qu'elle ne réapparaisse pas.
    private var economie: EconomieWoop { EconomieWoop.shared }

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
                        // ⚠️ **ALIGNÉ À GAUCHE, SUR LA MARGE DE LA PAGE**
                        // (29-08). Il était calé sur la COLONNE DE TEXTE des
                        // lignes (54 de plus) pour donner un seul axe
                        // vertical — mais quand la liste est VIDE il n'y a
                        // plus de colonne à quoi s'aligner : il ne reste
                        // qu'un titre qui a l'air poussé vers la droite sans
                        // raison. Un alignement qui dépend d'un contenu
                        // absent n'est pas un alignement.
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
                        .padding(.leading, 0)
                        .padding(.top, 72)
                        .padding(.bottom, 18)
                        .modifier(ArriveeFloue(p: apparu, rang: 0))
                    if gains.isEmpty {
                        Text("Rien encore. Une série faite, vingt pièces.")
                            .font(.inter(13))
                            .foregroundStyle(.white.opacity(0.44))
                            .modifier(ArriveeFloue(p: apparu, rang: 1))
                    } else {
                        listeGains
                    }
                    Spacer(minLength: 0)
                }
                // ⚠️⚠️ **SANS CE `maxWidth`, LE BLOC SE CENTRE — ET C'EST CE
                // QUI FAISAIT « Mes gains toujours pas à gauche ».** Le
                // `ZStack` est en `alignment: .top` : verticalement il colle
                // en haut, mais HORIZONTALEMENT il centre. Un `VStack` prend
                // la largeur de son plus large enfant, donc :
                //
                //   · liste PLEINE  → le `ScrollView` s'étale, le bloc fait
                //     toute la largeur, le titre tombe à 26 du bord ✓
                //   · liste VIDE    → il ne reste qu'un titre et une phrase,
                //     le bloc se rétracte à leur largeur… et se centre ✗
                //
                // J'avais « corrigé » en mettant le padding du titre à zéro :
                // ça ne pouvait rien y faire, le décalage ne venait pas d'un
                // padding mais de l'ABSENCE DE LARGEUR. C'est le piège maison
                // de la vue sans taille intrinsèque, deuxième fois sur cette
                // page — et deuxième fois que c'est l'état VIDE qui le
                // révèle.
                .frame(maxWidth: .infinity, alignment: .leading)
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

    // MARK: - L'HISTOIRE D'UN BOOSTER — la vidéo, puis la page (29-08)

    /// ⚠️⚠️ **LA DEUXIÈME SOUS-PAGE DU COFFRE**, après celle des gains, et les
    /// mêmes lois : en OVERLAY (le coffre est un `fullScreenCover`, une
    /// `sheet` dessus donne la poignée grise), la garde sur `gestePage` (sans
    /// elle un doigt ici ferait tourner le manège derrière — le bug du §19.4,
    /// déjà payé), la fermeture au chevron ET au doigt avec son chien de garde.
    ///
    /// Deux temps : la CINÉMATIQUE (8 s, passable d'un tap — verdict : « à
    /// chaque fois mais passable ; si c'est lourd, vue une fois la saute »),
    /// puis la PAGE : le sachet fondu au noir en header, un texte à la Apple,
    /// la pièce qui déborde du coin.
    @ViewBuilder
    private func pageHistoire(_ sc: SceneCoffre) -> some View {
        if let robe = histoire {
            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()
                if histoireFilm, let p = histoireLecteur {
                    filmHistoire(sc, p).transition(.opacity)
                } else {
                    contenuHistoire(sc, robe)
                }
            }
            .frame(width: sc.W, height: sc.H)
            .transition(.opacity)
            .offset(y: tireHistoire)
            .highPriorityGesture(gesteFermerHistoire)
            // ⚠️ Déplacer des pixels ne déplace pas la zone tactile : une page
            // tirée hors de sa place ne doit plus rien prendre (le gel
            // app-wide de `CheminHote`, mot pour mot).
            .allowsHitTesting(tireHistoire < 2)
        }
    }

    /// LA CINÉMATIQUE — plein cadre, et un tap n'importe où la passe.
    ///
    /// ⚠️ `CinematicPlayer` est en `resizeAspect` CODÉ EN DUR : il ne convient
    /// qu'à un cadre au ratio exact du fichier. Le fichier est recuit à
    /// 1206 × 2622 (`bake_story.py`), le ratio de l'écran — ça colle à 1e-4.
    private func filmHistoire(_ sc: SceneCoffre, _ p: AVPlayer) -> some View {
        ZStack(alignment: .bottomTrailing) {
            CinematicPlayer(player: p)
                .frame(width: sc.W, height: sc.H)
            // ⚠️ **PAS DE BOUTON « PASSER »** (verdict du 29-08 : « enlève le
            // bouton passer car on peut tap dessus et ça enlève »). J'en
            // avais mis un au nom de « une porte doit être visible » — mais
            // ici la porte, c'est TOUT L'ÉCRAN : n'importe quel tap passe. Un
            // bouton qui double un geste déjà universel n'ajoute qu'un objet
            // à regarder pendant un film.
            EmptyView()
        }
        .contentShape(Rectangle())
        // ⚠️ Le drag de fermeture est posé sur le parent en priorité haute ;
        // les deux s'arbitrent par la distance — un tap ne bouge pas de 12 pt,
        // le drag échoue, le tap passe. C'est le patron de la croix des gains.
        .highPriorityGesture(TapGesture().onEnded { passerHistoire() })
    }

    /// LA PAGE — le header fixe, et le récit qui défile dessous.
    ///
    /// Cotes relevées sur sa maquette Figma : chevron à 0,06 H, sachet de
    /// 0,12 à 0,37 H fondu vers le noir, titre à 0,45 H, corps dessous, la
    /// pièce en bas à droite coupée par le bord.
    ///
    /// ⚠️ **LE HEADER NE DÉFILE PAS, LE TEXTE OUI** (29-08 : « fais un scroll
    /// blur très premium »). Un sachet qui monterait avec le texte
    /// redeviendrait une illustration d'article ; fixe, il reste l'objet dont
    /// on parle, et le texte passe DESSOUS. C'est ce passage sous le fondu
    /// qui fait le « premium » — pas un effet ajouté, une profondeur.
    private func contenuHistoire(_ sc: SceneCoffre, _ robe: RobeBooster) -> some View {
        ZStack(alignment: .topLeading) {
            // LA PIÈCE — entière dans un coin elle fait vignette, débordante
            // elle fait décor. Cases de 320 px : elle tient à 230 pt.
            // ⚠️ **ELLE DÉBORDE LARGEMENT, ET ELLE EST EN SOURDINE.** Posée à
            // 0,90 / 0,94 en pleine lumière, elle passait DERRIÈRE le
            // troisième paragraphe et le rendait illisible : ses anneaux
            // clairs traversaient le gris du texte. Une pièce entière dans un
            // coin fait vignette ; une pièce à moitié sortie du cadre et
            // baissée fait décor. Le texte défile, donc la collision était
            // certaine à un moment ou à un autre — il fallait qu'elle cesse
            // d'être un objet pour devenir une lueur.
            PieceSprite(planche: robe == .noire ? .argent : .or,
                        tour: 0, diametre: 230)
                .modifier(Levitation(force: 1))
                .position(x: sc.W * 1.02, y: sc.H * 1.02)
                .opacity(0.5)
                .modifier(ArriveeFloue(p: histoireApparue, rang: 5))
                .allowsHitTesting(false)

            recitHistoire(sc, robe)
            enteteHistoire(sc, robe)

            // LE CHEVRON — la règle des trois ronds du coffre : 44, à 63 du
            // haut, 22 du bord. ⚠️ `ChipVerre` est un `Button` sous le drag du
            // parent : on le rend sourd et c'est notre tap prioritaire qui
            // ferme — la loi payée sur le stop du player.
            ChipVerre(symbole: "chevron.left", label: "Retour", clarte: 0) {}
                .allowsHitTesting(false)
                .contentShape(Rectangle())
                .highPriorityGesture(TapGesture().onEnded { fermerHistoire() })
                .padding(.leading, 22)
                .padding(.top, 63)
        }
    }

    /// LE HEADER : le sachet qui se FOND dans le noir. ⚠️ Un masque en
    /// dégradé, pas un `.blur` — un flou poserait un voile uniforme sur tout
    /// le rectangle de l'hôte (loi de la maison, payée).
    private func enteteHistoire(_ sc: SceneCoffre, _ robe: RobeBooster) -> some View {
        SachetVignette(largeur: 210 * 84 / 145, hauteur: 210, robe: robe)
            .mask {
                LinearGradient(stops: [.init(color: .white, location: 0),
                                       .init(color: .white, location: 0.52),
                                       .init(color: .clear, location: 1.0)],
                               startPoint: .top, endPoint: .bottom)
            }
            .position(x: sc.W / 2, y: sc.H * 0.245)
            .allowsHitTesting(false)
    }

    /// LE RÉCIT — quatre paragraphes qui défilent, chacun arrivant dans le
    /// flou (`ArriveeFloue`, le vocabulaire de la maison : rayon 9 → 0,
    /// décalage 9 → 0, un rang de retard par bloc).
    ///
    /// ⚠️ **LE FONDU DU HAUT EST UN MASQUE, ET IL EST OBLIGATOIRE** : sans
    /// lui, la première ligne de texte apparaît d'un coup au bord du header,
    /// comme coupée au couteau. Avec, elle naît du noir.
    ///
    /// ⚠️ Le rayon de flou retombe à ZÉRO exact quand l'arrivée est finie :
    /// un `.blur` même minuscule force une passe hors écran à chaque image,
    /// et sur un `ScrollView` c'est à chaque image de DÉFILEMENT.
    private func recitHistoire(_ sc: SceneCoffre, _ robe: RobeBooster) -> some View {
        let t = robe == .noire ? Self.recitNoir : Self.recitLune
        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                Text(t.titre)
                    .font(.inter(34, .semibold))
                    .tracking(-0.4)
                    .foregroundStyle(.white.opacity(0.96))
                    .lineSpacing(2)
                    .modifier(ArriveeFloue(p: histoireApparue, rang: 0))
                ForEach(Array(t.corps.enumerated()), id: \.offset) { i, para in
                    Text(para)
                        .font(.inter(17))
                        .foregroundStyle(.white.opacity(i == 0 ? 0.72 : 0.52))
                        .lineSpacing(5)
                        .modifier(ArriveeFloue(p: histoireApparue, rang: i + 1))
                }
                Color.clear.frame(height: 190)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 26)
            .padding(.top, sc.H * 0.42)
        }
        .mask {
            LinearGradient(stops: [.init(color: .clear, location: 0),
                                   .init(color: .white, location: 0.30),
                                   .init(color: .white, location: 1)],
                           startPoint: .top, endPoint: .bottom)
        }
    }

    struct RecitBooster { let titre: String; let corps: [String] }

    /// ⚠️ Sans tirets dans le texte affiché (verdict explicite du 29-08). Et
    /// sans chiffre que le serveur ne garantit pas : le nombre de cartes d'un
    /// sachet n'est écrit nulle part, on ne l'invente pas ici.
    static let recitNoir = RecitBooster(
        titre: "Legendary\nbooster",
        corps: [
            "A black booster always holds one legendary card. Not a chance at one. One, guaranteed.",
            "It opens with a single silver coin. You cannot buy that coin, and you cannot earn it by training. It falls, rarely, somewhere along the path, and when it does, this is where it goes.",
            "Inside, the card comes from the sealed registry: the pieces that exist in few copies, forged once and never again. The moon on the wrapper is the only thing that tells you which one waits.",
            "Nothing else in the vault works this way. Everything else is patience. This one is luck, and it is meant to feel like it.",
        ])
    static let recitLune = RecitBooster(
        titre: "The Lune\nbooster",
        corps: [
            "Every session you finish earns one. No condition, no streak to keep. You train, it arrives.",
            "A hundred coins buy another, and coins come twenty at a time, one set after the next. That is the whole economy: the work you already do, counted.",
            "Inside waits a hand from the Lune set, drawn when you tear it open and not a moment before. Most of them are common. Some are not.",
            "It is the booster you will open the most, and the one the vault was built around.",
        ])


    private func ouvrirHistoire(_ robe: RobeBooster) {
        fermerLoupe()
        histoire = robe
        histoireApparue = 0
        tireHistoire = 0
        passerVisible = false
        // ⚠️ LE SON RESPECTE L'INTERRUPTEUR SILENCIEUX. Toutes les boucles de
        // l'app sont muettes ; cette cinématique a une piste, et elle est
        // légitime — mais `.ambient` et jamais `.playback`, sinon un coffre
        // ouvert dans le métro fait du bruit.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .moviePlayback)
        let nom = robe == .noire ? "story-booster-noir" : "story-booster-lune"
        guard !reduceMotion,
              let url = Bundle.main.url(forResource: nom, withExtension: "mp4") else {
            // Sans film, la page est là tout de suite : on ne fait jamais
            // attendre devant une absence.
            histoireFilm = false
            withAnimation(.easeOut(duration: 0.62)) { histoireApparue = 1 }
            return
        }
        let p = AVPlayer(url: url)
        p.automaticallyWaitsToMinimizeStalling = false
        histoireLecteur = p
        histoireFilm = true
        p.play()
        // ⚠️ On écoute la fin du FILM — jamais un seek dessus. Un observateur
        // par lecture, retiré à la fin.
        finFilm = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: p.currentItem,
            queue: .main) { _ in finirFilmHistoire() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.3)) { passerVisible = true }
        }
    }

    private func passerHistoire() { finirFilmHistoire() }

    /// La fin du film — au bout, ou passée d'un tap : le même chemin.
    private func finirFilmHistoire() {
        guard histoireFilm else { return }
        if let f = finFilm { NotificationCenter.default.removeObserver(f); finFilm = nil }
        withAnimation(.easeInOut(duration: 0.34)) { histoireFilm = false }
        histoireLecteur?.pause()
        histoireLecteur = nil
        withAnimation(.easeOut(duration: 0.70).delay(0.10)) { histoireApparue = 1 }
    }

    private func fermerHistoire() {
        if let f = finFilm { NotificationCenter.default.removeObserver(f); finFilm = nil }
        histoireLecteur?.pause()
        histoireLecteur = nil
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeInOut(duration: 0.30)) { histoire = nil }
        tireHistoire = 0
        tirHistNe = nil
    }

    /// Tirer la page vers le bas la ferme — et ⚠️ un drag peut mourir sans
    /// `onEnded` (doigt volé au bord, appel entrant) : le chien de garde
    /// COMMET la sortie si le seuil était franchi, sinon on récupère une page
    /// à moitié tirée et jamais fermée.
    private var gesteFermerHistoire: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { v in
                tirHistNe = Date()
                tireHistoire = v.translation.height > 0
                    ? v.translation.height : v.translation.height * 0.18
                let ne = tirHistNe
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    guard histoire != nil, tirHistNe == ne, tirHistNe != nil else { return }
                    if tireHistoire > 120 { fermerHistoire() }
                    else {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                            tireHistoire = 0
                        }
                    }
                    tirHistNe = nil
                }
            }
            .onEnded { v in
                tirHistNe = nil
                if tireHistoire > 120 || v.predictedEndTranslation.height > 260 {
                    fermerHistoire()
                } else {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                        tireHistoire = 0
                    }
                }
            }
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
    ///
    /// ⚠️⚠️ **LA DÉPENSE SIMULÉE EST MORTE, ET ELLE FAISAIT MENTIR DEUX
    /// ÉCRANS.** Le pied calculait `dispo = coins − boostersEnAttente × 100`
    /// — une retenue pour des sachets que personne n'avait achetés. Mesuré :
    /// la pastille du profil disait 1240, on la tapait, le coffre s'ouvrait
    /// par-dessus et la MÊME grandeur y devenait 1140, sans qu'aucune
    /// transaction ait eu lieu. Le solde n'a plus qu'une source
    /// (`EconomieWoop`), et un solde ne se corrige pas à l'affichage : il se
    /// débite au serveur ou il ne bouge pas.
    ///
    /// ⚠️ Cette propriété est CALCULÉE et appelée six fois par passe de corps
    /// (dont une dans une boucle de quatre) : elle ne fait QUE lire
    /// l'observable. Jamais un appel réseau ici.
    private var variantes: [PiedVariante] {
        let e = economie
        let prix = max(e.prixBooster, 1)
        return [
            // ① la pièce d'or : son solde, et l'horloge du versement quotidien.
            //    ⚠️ En anglais, comme le reste de la page (tranché 30-08).
            PiedVariante(nom: "Gold Coin",
                         phrase: "Opens a Lune Booster.",
                         glyphe: .piece(.or), nombre: e.or,
                         // ⚠️ Le taux vient du serveur (`pieces_par_serie`).
                         sousPill: "\(e.piecesParSerie) coins for every set you finish.",
                         jauge: jaugeRetour(e),
                         robe: nil, histoire: .lune, bouton: nil,
                         lueur: Self.manege[0].lueur),
            // ② le booster Lune : combien j'en ai, et où en est le prochain.
            //    ⚠️ `reste` est DÉRIVÉ PAR LE SERVEUR (`solde_or mod prix`) ;
            //    sous la conversion (M1, à poser) il vaudra le solde même.
            //    ⚠️ La phrase ne dit AUCUN nombre de cartes : le code de la
            //    page du récit refuse de l'écrire (voir `recitLune`).
            PiedVariante(nom: "Lune Booster",
                         phrase: "A pack of cards from the Lune set.",
                         glyphe: .sachet(.lune), nombre: e.boosters,
                         sousPill: nil,
                         jauge: .compte(courant: e.reste, cible: prix, monnaie: .or),
                         robe: .lune, histoire: nil,
                         // La casse est celle du composant (`enPhrase`) :
                         // « Ouvrir » / « Locked ». « N COINS TO GO » est
                         // mort : la barre le dit déjà (§26.2, la redondance).
                         bouton: e.boosters > 0
                            ? ("OUVRIR", true) : ("LOCKED", false),
                         lueur: Self.manege[1].lueur),
            // ③ la pièce d'argent : PAS de barre — elle TOMBE (p ≈ 1/30), et
            //    la seule jauge possible exposerait la pitié.
            PiedVariante(nom: "Silver Coin",
                         phrase: "Opens a Legendary Booster.",
                         glyphe: .piece(.argent), nombre: e.argent,
                         sousPill: "A rare drop from the path.",
                         jauge: nil, robe: nil, histoire: .noire, bouton: nil,
                         lueur: Self.manege[2].lueur),
            // ④ le booster noir : pas de barre non plus (rien ne s'accumule
            //    vers lui, il naît d'une pièce entière ; « courant / 1 »
            //    écrirait « 2 / 1 »). Son compte EST le solde d'argent.
            PiedVariante(nom: "Legendary Booster",
                         phrase: "One legendary card, guaranteed.",
                         glyphe: .sachet(.noire), nombre: e.boostersNoirs,
                         sousPill: nil,
                         jauge: nil, robe: .noire, histoire: nil,
                         bouton: e.boostersNoirs > 0
                            ? ("OUVRIR", true) : ("LOCKED", false),
                         lueur: Self.manege[3].lueur),
        ]
    }

    /// L'HORLOGE DU +10 — seulement quand on SAIT. `prochainRetour` est lu du
    /// serveur (`etat_coffre().retour_prochain`, M1) ou posé par la maquette ;
    /// sans lui, pas de barre : une barre à une heure inventée mentirait.
    private func jaugeRetour(_ e: EconomieWoop) -> JaugeCoffre? {
        if e.retourDisponible {
            return .horloge(montant: e.piecesRetourQuotidien, disponible: true,
                            prochain: .distantFuture)
        }
        guard let prochain = e.prochainRetour else { return nil }
        return .horloge(montant: e.piecesRetourQuotidien, disponible: false,
                        prochain: prochain)
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
        let possede = variantes[min(i, variantes.count - 1)].nombre > 0
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

    /// ⚠️⚠️ **CE BOUTON PROMETTAIT « bought for 100 coins » ET NE DÉBITAIT
    /// RIEN.** Il fermait le coffre et posait l'état partagé — c'est tout.
    /// Pire, sa garde (`boostersEnAttente > 0`) ne pouvait JAMAIS être
    /// fausse : le compteur naissait à 1 et son décompte était plafonné par
    /// `max(1, n − 1)`. Une porte toujours ouverte avec un cadenas peint
    /// dessus.
    ///
    /// ⚠️ **UN SACHET EN RÉSERVE S'OUVRE GRATUITEMENT** — c'est le sens de
    /// l'avoir gagné. Le débit ne part que pour un sachet qu'on n'a pas, et
    /// **seulement pour la robe LUNE** : le noir ne s'achète pas, il se paie
    /// d'une pièce d'argent qui tombe (`claim_booster_legendaire`), et cette
    /// porte-là est déjà tenue par le solde d'argent.
    private func ouvrirManege(_ robe: RobeBooster) {
        if robe == .noire || economie.boosters > 0 {
            onClose()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                SacreEtat.shared.ouvrirManege(robe: robe)
            }
            return
        }
        Task {
            let sort = await economie.acheterBooster()
            guard case .obtenu = sort else {
                // Le pied dit déjà « N COINS TO GO » sur la même page : il n'y
                // a rien à annoncer de plus, et il se met à jour tout seul
                // (le solde vient d'être relu par l'achat refusé).
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                return
            }
            onClose()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                SacreEtat.shared.ouvrirManege(robe: robe)
            }
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
                // ⚠️ **LES NÉONS SONT LA MÊME IMAGE QUE L'ARCHE** : ils
                // prennent le mouvement du décor au pixel près, sur-cadrage
                // compris. Un point d'écart et les anneaux allumés sortent de
                // leurs anneaux.
                neonSocle(sc)
                    .parallaxe(CoffreParallaxe.fond,
                               echelle: CoffreParallaxe.echelle,
                               ancre: CoffreParallaxe.ancre)
                    .offset(y: bas)
                // ⚠️ **ET LES FLAQUES AUSSI, POUR UNE RAISON QU'ON NE VOIT
                // PAS DANS LEUR CODE** : `contact` se masque par l'IMAGE DE
                // FOND entière. Fond sur-cadré et masque non sur-cadré, la
                // lumière de contact se décale de 5 % — elle allumerait le sol
                // à côté du socle.
                flaques(sc)
                    .parallaxe(CoffreParallaxe.fond,
                               echelle: CoffreParallaxe.echelle,
                               ancre: CoffreParallaxe.ancre)
                    .offset(y: bas)
                // La poudre vit dans l'air, pas sur le socle : amplitude des
                // objets, et pas de sur-cadrage (elle n'a pas de bord).
                poudre(sc).parallaxe(CoffreParallaxe.objets).offset(y: bas)
                // ⚠️⚠️ **DEUX FAISCEAUX SE SONT ADDITIONNÉS.** Le fond
                // porte maintenant SON spot ; celui-ci descendait par-dessus.
                // Mesuré sur la bande centrale, le vert dépassait le bleu de
                // **+17 à +20 dans l'app contre +8 dans sa référence** — la
                // crème du Projecteur (V 0,80 · B 0,55) s'ajoutait en
                // `plusLighter` et virait le faisceau au kaki.
                //
                // Il ne disparaît pas pour autant : il fait deux choses que
                // l'image ne saura jamais faire — il SUIT l'objet, et il
                // FORCE au tap. Il perd donc les deux tiers de sa force au
                // repos et garde toute sa réponse au geste.
                Projecteur(scene: sc,
                           piece: piecePresD,
                           pieceY: piecePresY(sc),
                           // ⚠️ **REMONTÉ DE 0,34 À 0,86** : il avait été
                           // baissé parce que le fond portait SON faisceau
                           // (§20.8). L'arche n'en a pas — elle éclaire par
                           // ses liserés, latéralement. Sans ce projecteur,
                           // plus rien ne DÉSIGNE l'objet posé.
                           force: pageOp * (0.86 + 0.55 * loupe + 0.18 * presse))
                    .equatable()
                    .parallaxe(CoffreParallaxe.objets)
                    .offset(y: bas)
                if let ne = chocNe {
                    Atterrissage(ne: ne,
                                 contact: CGPoint(x: sc.W / 2, y: sc.yHaut),
                                 diam: CoffreV2Cotes.piece,
                                 barre: sc.barre,
                                 plein: geo.size,
                                 force: chocForce)
                        .parallaxe(CoffreParallaxe.objets)
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
                        .parallaxe(CoffreParallaxe.objets)
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
                        .parallaxe(CoffreParallaxe.objets)
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
                    .opacity(pageOp * (gainsOuverts || histoire != nil ? 0 : 1))
                if filmVisible { film(sc) }
                pageGains(sc)
                pageHistoire(sc)
            }
            .contentShape(Rectangle())
            .gesture(gestePage(sc))
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear {
            demarrer()
            // ⚠️ LE CAPTEUR NE TOURNE QUE PAGE OUVERTE. Un `CMMotionManager`
            // laissé en marche continue de réveiller le processeur à 60 Hz
            // depuis n'importe quel autre écran — c'est de la batterie brûlée
            // pour un décor que personne ne regarde.
            GyroFond.shared.demarrer()
            withAnimation(.spring(response: 0.80, dampingFraction: 0.75)
                            .delay(0.45)) { remplie = 1 }
        }
        .onDisappear {
            lecteur?.pause()
            GyroFond.shared.arreter()
        }
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
                            // ⚠️ **DEDANS, PAS SUR `carte`.** Le décor bouge ;
                            // le `clipShape(FormeScene)` qui donne à la card
                            // son bord bas arrondi, LUI, ne doit jamais
                            // bouger — sinon le coin de la card se promène
                            // sur l'écran quand on penche le téléphone.
                            .parallaxe(CoffreParallaxe.fond,
                                       echelle: CoffreParallaxe.echelle,
                                       ancre: CoffreParallaxe.ancre)
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

    /// ⚠️⚠️ **LES NÉONS DU SOCLE — ET C'EST L'IDENTITÉ QU'ILS RÉPARENT.**
    ///
    /// Le §23.8 avait mesuré la casse : avec le spotlight, l'écart de teinte
    /// entre les quatre pages était de **101 points** ; avec l'arche, de
    /// **23**. Un décor a sa couleur, et il gagnait contre la flaque.
    ///
    /// Or les pixels saturés de l'arche portent **35,9 % de la lumière totale
    /// de l'image**, dont 28,8 % dans la bande du socle. Les sortir du décor,
    /// c'est reprendre la main sur ce tiers-là — au bon endroit.
    ///
    /// ⚠️ **CE QUI REND ÇA POSSIBLE EST UNE SOUSTRACTION, PAS UNE
    /// SUPERPOSITION** (`bake_neon.py`). Poser un néon coloré sur l'image
    /// intacte, c'est ajouter à de l'orange déjà là : on peut le surcharger,
    /// jamais le faire virer au bleu. La base a donc son socle ÉTEINT
    /// (saturation R−B 21,9 → 8,9 dans la bande, −44 % de luminance), et
    /// c'est cette couche-ci qui le rallume, dans la couleur de la page.
    ///
    /// ⚠️ Seuls les néons DU SOCLE sortent : ceux de l'arche restent dans la
    /// base (mesuré : R−B 3,4 → 3,4 hors bande). Toute la scène qui change de
    /// couleur à chaque page serait trop fort — le décor garde son identité,
    /// l'objet garde la sienne.
    @ViewBuilder
    private func neonSocle(_ sc: SceneCoffre) -> some View {
        if !SalleFond.spot {
            FondCoffre.image("coffre-arche-neon")?
                .resizable()
                .interpolation(.high)
                .frame(width: sc.W, height: sc.H)
                .position(x: sc.W / 2, y: sc.H / 2)
                // ⚠️ `colorMultiply` sur un GRIS : le noir n'ajoute rien, le
                // gris prend la teinte. C'est pour ça que le bake sort les
                // anneaux en niveaux de gris et non en orange.
                .colorMultiply(teinteNeon)
                .blendMode(.plusLighter)
                // ② L'ÉCLAT À LA POSE — une RÉPONSE, pas une boucle : elle ne
                // joue que quand l'objet touche, donc elle ne s'use pas.
                .opacity(pageOp * (1 + 0.75 * chocForce))
                .allowsHitTesting(false)
            balayage(sc)
        }
    }

    /// ③ LE BALAYAGE ANGULAIRE — un reflet qui court autour des anneaux.
    ///
    /// C'est ce qui fait « néon allumé » plutôt que « néon peint ». ⚠️ Et
    /// c'est **la seule des trois qui peut lasser** : elle joue en permanence,
    /// là où la teinte est une transition et l'éclat une réponse. Elle est
    /// donc tenue court — un sur-éclat de +30 %, une révolution en 7 s, et
    /// une SEULE crête (pas deux, pas quatre : un phare, pas un gyrophare).
    ///
    /// ⚠️ Le centre du dégradé est celui du SOCLE, pas de l'écran : sinon le
    /// reflet ne tourne pas autour des anneaux, il balaie la page.
    ///
    /// ⚠️ **COÛT NON MESURÉ, ET IL EST RÉEL** : un `.mask` animé sur une image
    /// plein écran force une passe hors écran à CHAQUE image. Le simulateur
    /// est aveugle à ça (loi de la maison) — il faut la sonde sur le
    /// téléphone, et `./tools/charge.sh` avant.
    @ViewBuilder
    private func balayage(_ sc: SceneCoffre) -> some View {
        FondCoffre.image("coffre-arche-neon")?
            .resizable()
            .interpolation(.high)
            .frame(width: sc.W, height: sc.H)
            .position(x: sc.W / 2, y: sc.H / 2)
            .colorMultiply(teinteNeon)
            // ⚠️⚠️ **ON TOURNE LA VUE, PAS L'ANGLE DU DÉGRADÉ — ET C'EST LE
            // PIÈGE MAISON DES RAMPES SOUS `withAnimation`.** Premier jet :
            // `AngularGradient(angle: .degrees(tourNeon))`. Un
            // `AngularGradient` est un `ShapeStyle`, pas un modificateur :
            // SwiftUI **ne l'interpole jamais**. Il évalue le corps une fois,
            // à la valeur d'arrivée — et 360° est identique à 0°, donc rien
            // ne bougeait. Mesuré : l'écart de luminance gauche/droite restait
            // à −4,7 pendant 5 secondes, immobile.
            //
            // `rotationEffect`, lui, EST un modificateur. Le dégradé est donc
            // figé dans un carré qu'on fait tourner autour du centre du socle.
            // Le carré doit couvrir l'écran depuis ce centre, d'où la
            // diagonale doublée.
            .mask {
                AngularGradient(
                    stops: [.init(color: .clear, location: 0.00),
                            .init(color: .white, location: 0.12),
                            .init(color: .clear, location: 0.26),
                            .init(color: .clear, location: 1.00)],
                    center: .center, angle: .zero)
                    .frame(width: hypot(sc.W, sc.H) * 2,
                           height: hypot(sc.W, sc.H) * 2)
                    .rotationEffect(.degrees(tourNeon))
                    .position(sc.podCentre)
            }
            .blendMode(.plusLighter)
            .opacity(pageOp * 0.30)
            .allowsHitTesting(false)
            .onAppear {
                // ⚠️ `repeatForever` sur un `@State` lu par un MODIFICATEUR :
                // ça anime un modificateur, pas un corps. Un `TimelineView`
                // ré-évaluerait la vue à chaque image.
                withAnimation(.linear(duration: 7).repeatForever(autoreverses: false)) {
                    tourNeon = 360
                }
            }
    }

    /// La couleur du néon, INTERPOLÉE entre les deux pages voisines : elle
    /// vire pendant le voyage, elle ne saute pas au cran. Le socle annonce
    /// donc l'objet qui arrive avant qu'il ne soit posé — la même idée que la
    /// poudre du passage.
    private var teinteNeon: Color {
        let p = min(max(page, 0), Self.dernierePage)
        let i = Int(p)
        let j = min(i + 1, Self.manege.count - 1)
        return Self.manege[min(i, Self.manege.count - 1)].lueur
            .mix(with: Self.manege[j].lueur, by: p - Double(i))
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
        // ⚠️⚠️ **70 → 340, ET C'EST LA MOITIÉ DE LA LEÇON.** Passer au grain
        // fin (0,30-0,95 au lieu de 0,8-2,2) sans toucher au NOMBRE a divisé
        // l'encre totale par **9** — 338 pt² avant, 37 après. Verdict : « je
        // vois rien ». Une poudre fine n'est pas une poudre grosse en plus
        // petit : **c'est plus de grains**. La poudre du grattage en met 90
        // sur la largeur d'un pouce ; la nôtre traverse tout l'écran.
        //
        // 340 rend 64 % de l'ancienne encre avec des grains 2,3× plus fins :
        // le même poids à l'œil, sans le confetti.
        for k in 0..<340 {
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
            // ⚠️⚠️ **LE RÉGIME DIAMANT DE LA MAISON, PAS LE MIEN.** Mes grains
            // faisaient 0,8 à 2,2 pt — verdict : *« les petites particules
            // sont trop grosses, prends la petite poussière de diamant des
            // pop-up »*. Elle avait raison, et la maison avait déjà payé la
            // leçon : `PoudreGrattage` note « le grain le plus gros reste SOUS
            // le point ; avant, le plus petit faisait déjà 1,2 ».
            //
            // Ce qui compte n'est d'ailleurs pas la taille moyenne mais le
            // RÉGIME : des grains presque tous sourds, quelques-uns qui
            // éclatent. Une taille uniforme donne du grouillement ; c'est de
            // la poussière, pas du diamant. Les trois cotes viennent
            // maintenant d'un seul endroit — deux poudres dans une app, ce
            // sont deux vérités sur ce qu'est une paillette.
            let eclat = PoudreGrattage.eclat(Double(k) * 12.9898 + t * 9)
            let rayon = PoudreGrattage.rayon(eclat)
            // ⚠️ LA COULEUR VIRE EN COURS DE VOL, mais LÉGÈREMENT : le grain
            // reste du diamant (blanc, un sur cinq vers le froid) et ne prend
            // qu'un tiers de la couleur de la page. Le passage de témoin —
            // partir dans la teinte de celui qui s'en va, arriver dans celle
            // de l'autre — survit sans que la poudre vire à l'orange.
            let teinte = PoudreGrattage.teinte(k)
                .mix(with: t < 0.5 ? depart : arrivee, by: 0.34)
            let al = vie * (0.35 + 0.65 * eclat) * (0.45 + 0.55 * f)
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
            // ⚠️⚠️ **LE MASQUE CHANGE DE SOURCE, PAS DE PRINCIPE.** La loi du
            // §18 tient : *la lumière se masque par la MATIÈRE* — c'est elle
            // qui sépare « une lumière » d'« un calque ». Seulement la matière
            // n'est plus un PNG de socle : c'est le socle DU FOND.
            //
            // ⚠️ Le masque est donc l'image de fond ENTIÈRE, à sa place
            // exacte. C'est légal parce que le dégradé est déjà borné au
            // plateau par son `frame` + `position` : hors de là il vaut zéro,
            // et le reste de l'arche ne peut rien allumer.
            .mask {
                FondCoffre.image("coffre-arche")?
                    .resizable()
                    .interpolation(.high)
                    .frame(width: sc.W, height: sc.H)
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

    // MARK: Le contenu

    @ViewBuilder
    private func contenu(_ sc: SceneCoffre) -> some View {
        // ⚠️ +58 → +103 : `PiedCoffre` n'est plus une plaque de 104 mais une
        // inscription de 146, et `.position` centre son cadre. Le haut du
        // texte tombe donc à `podFin + 30` — juste sous le reflet du socle,
        // là où le sol devient lisible.
        // ⚠️ +103 → +109 (30-08) : le pied a grandi de 12 par le BAS (196 →
        // 208, voir `PiedCoffre.taille`) ; `.position` centre le cadre, donc
        // l'ancre descend de 6 pour que le haut reste à `podFin + 5`.
        let piedY = sc.podFin + 109
        // ⚠️ CE QUI EST SOUS LE SOCLE REMONTE AVEC LE BORD BAS DE LA CARD —
        // sinon, card tirée, le texte se retrouve posé sur la bande de nuit
        // qui découvre la lune. C'est `MonteAvecLaCard` des exos, en une ligne.
        let monte = min(tirage, 0) * 0.9
        // La variante du cran, lue UNE fois (`variantes` est calculée).
        let v = variantes[min(piedIdx, variantes.count - 1)]
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
                // ⚠️ `clarte: 0` DEPUIS LE PASSAGE AU NOIR. Le composant
                // porte déjà la loi : 0 = la nuit (verre fumé noir, glyphe
                // blanc), 1 = une lumière (verre transparent, glyphe à
                // l'encre sombre). Le coffre lui disait encore « lumière »
                // parce que le mur était éclairé — mesuré sur la capture, le
                // chevron ressortait à **65 de luminance contre 18 pour la
                // pill des gains** : une dalle grise posée sur la nuit.
                ChipVerre(symbole: "chevron.left", label: "Fermer",
                          clarte: 0, action: onClose)
                titre
            }
            .padding(.leading, 22)
            // Le mur étant plein cadre, le chevron retrouve sa cote
            // canonique — « la position du chevron ne bouge JAMAIS d'une page
            // à l'autre » (`RangeeChips`).
            .padding(.top, 63)
            .opacity(pageOp * texteOp)

            // ⚠️⚠️ **SEUL L'OBJET PREND LE MOUVEMENT DANS CETTE PILE.** Tout
            // le reste de `contenu` est du CHROME — chevron, titre, pill,
            // crans, pied. Du chrome qui dérive au gyroscope, ce n'est plus une
            // scène qui respire, c'est une interface qui glisse : on ne sait
            // plus si le bouton qu'on vise est là où on le voit.
            piece(sc).parallaxe(CoffreParallaxe.objets)

            // ⚠️ **LE NOM ET SA PHRASE VIVENT AVEC L'OBJET, PAS SOUS LE SOCLE**
            // (§29) : à la cote de l'ancienne pill de prix, FIXE — un texte
            // qui monte et descend avec ce qu'il décrit se lit comme un
            // ballon de BD. Le pied lit le CRAN (`piedIdx`), jamais `page`.
            EnTeteObjet(nom: v.nom, phrase: v.phrase)
                .id(piedIdx)
                .transition(.opacity)
                .position(x: sc.W / 2, y: sc.H * 0.222)
                .opacity(pageOp * texteOp)

            // LE PIED : un seul objet, et les deux pièces s'y croisent à
            // taille FIXE. Deux dalles montées/démontées au cran feraient
            // sauter la mise en page d'un texte à l'autre.
            barreDeCrans
                .position(x: sc.W / 2, y: piedY - PiedCoffre.taille.height / 2 - 26)
                .opacity(pageOp)
                .offset(y: monte)

            PiedCoffre(v: v, remplie: remplie,
                       onOuvrir: robeDeLaPage.map { r in { ouvrirManege(r) } },
                       onHistoire: { r in ouvrirHistoire(r) })
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
            // ⚠️⚠️ **LE PASSAGE AU NOIR A TUÉ SON ENCRE.** « Rewards » était
            // un dégradé NOIR (`encreFade`) pour une seule raison : il vivait
            // sur le mur ÉCLAIRÉ. Le mur est mort (§20) — sur le fond
            // spotlight il n'existait tout simplement plus. Il reprend le
            // VRAI `titleFade`, le blanc, celui pour lequel il a été fait.
            .foregroundStyle(WoopGradient.titleFade)
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
                guard !gainsOuverts, histoire == nil else { return }
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
                        // ⚠️ **PREMIER TAP : LA LOUPE. DEUXIÈME TAP : L'HISTOIRE**
                        // (verdict du 29-08). Le même geste ne change pas de
                        // sens selon la page — il va PLUS LOIN : on regarde de
                        // près, puis on entre. Sur une pièce, le deuxième tap
                        // referme la loupe, comme avant : une pièce n'a pas
                        // d'histoire à raconter.
                        if loupe > 0.5 {
                            if case .booster(let robe) = Self.manege[loupeIdx] {
                                ouvrirHistoire(robe)
                            } else { fermerLoupe() }
                        } else { ouvrirLoupe(t) }
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
        // `-coffreStory noir|lune` : l'histoire d'un booster d'entrée.
        if let robe = Self.storyAuto {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                page = robe == .noire ? 3 : 1
                piedIdx = Int(page)
                ouvrirHistoire(robe)
            }
        }
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
        // ⚠️⚠️ **LE BANC DOIT SEMER LA MAQUETTE LUI-MÊME DEPUIS LE
        // BRANCHEMENT.** La page ne lit plus ses arguments : elle lit
        // `EconomieWoop`. Sans cette ligne le banc afficherait 0 pièce et
        // « Rien encore » — et je jugerais un pied vide en croyant juger le
        // pied. C'est le même faux négatif que celui déjà payé ici (« monté
        // en direct, le banc affichait Rien encore alors que la base était
        // pleine »), sous sa deuxième forme.
        .onAppear {
            EconomieWoop.shared.poserMaquette(or: 1240,
                                              journal: Self.echantillon)
        }
        .preferredColorScheme(.dark)
    }
}
