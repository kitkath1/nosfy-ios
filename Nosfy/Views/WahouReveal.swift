import SwiftUI

// MARK: - LA RÉVÉLATION
//
// La dernière étape du geste : la carte est tombée au fond du trou, le trait
// de la fente s'embrase — et de cet embrasement la carte RENAÎT, la caméra
// plonge dessus, la traverse en travelling, puis recule d'un coup pendant que
// le choc part dans la main. Elle se pose à 80 % de l'écran, noire, son tube
// allumé, prête à porter la vidéo.
//
// TROIS DÉCISIONS PORTENT TOUTE LA SÉQUENCE :
//
// 1. LA CARTE EST LA MÊME, VUE DE PLUS PRÈS. Elle est dessinée à sa taille de
//    pile (174 × 224) et c'est la CAMÉRA qui l'agrandit. Redessiner une grande
//    carte aurait gardé le tube à 14 pt du bord et son cœur à 1 pt : sur 322 pt
//    de large, le néon serait devenu un cheveu, et le grain de l'obsidienne un
//    aplat. Un zoom de caméra GROSSIT la matière — c'est à ça qu'on reconnaît
//    un objectif qui s'approche, et c'est gratuit puisque le shader continue de
//    rendre sa petite surface.
//
// 2. LE ZOOM DÉPASSE, PUIS REVIENT — c'est UN mouvement, pas deux. Enchaîner
//    zoom, pause, dézoom se lit comme deux animations collées. La grammaire
//    keynote, c'est le DÉPASSEMENT : la carte doit sortir du cadre (pic à
//    3,1 × = 539 pt de large pour un écran de 402) avant de se poser à 1,85 ×.
//    Si les bords restent visibles au pic, on ne lit pas un plongeon, on lit un
//    rebond élastique.
//
// 3. LA PILE SORT DE LA HIÉRARCHIE. Pendant le pic on empilerait l'aurore plein
//    écran à 30 Hz, la fente, QUATRE cartes à shader, le grain et la grande
//    carte. La leçon de la flamme est écrite dans ce projet : 18-36 img/s au
//    simulateur, verdict « pas fluide, trop cheap ». Un `.opacity(0)` ne
//    suffirait pas — une vue transparente rend quand même.

struct WahouReveal: View {
    /// Le gain que la carte emportait.
    var gain: Int
    /// Le chevron : on rend la main.
    var onClose: () -> Void

    /// L'échelle de la carte, en multiples de sa taille FINALE (80 % de
    /// l'écran). 1 = posée ; `pic` = le plongeon, hors cadre ; `1/taille` = sa
    /// taille de pile, celle qu'elle avait en entrant dans le trou.
    @State private var zoom: CGFloat = 1.0
    /// Le rapport entre la taille finale et la taille de pile. Mesuré sur
    /// l'écran, jamais écrit en dur — il change avec le modèle.
    @State private var taille: CGFloat = 1.85
    /// La largeur de l'écran, d'où se déduit la course du travelling.
    @State private var largeur: CGFloat = 402
    /// L'instant du TOUCHER de la carte : elle expire une bouffée. C'est la
    /// DATE qui traverse jusqu'au shader, jamais la valeur — l'enveloppe se
    /// calcule sous l'horloge 30 Hz de l'aura, sinon on n'en verrait qu'une
    /// image sur dix.
    @State private var touche: Date = .distantPast
    /// Le travelling latéral, en points d'écran.
    @State private var pan: CGFloat = 0
    /// LE TOUR. La carte pivote sur son axe vertical pendant que la caméra
    /// plonge — c'est ce qui la fait exister comme un OBJET et pas comme une
    /// image qu'on agrandit.
    ///
    /// (L'interdit de rotation 3D de la PILE ne vaut pas ici, et il faut savoir
    /// pourquoi : là-bas elle faisait passer la carte derrière ses voisines,
    /// parce qu'une vue à transformation 3D est composée dans son propre plan
    /// de profondeur où le zIndex ne fait plus loi. Ici la carte est SEULE sur
    /// sa couche : il n'y a personne derrière qui puisse la doubler. Et
    /// l'autre grief — « elle enfle au lieu de reculer » — devient ici la
    /// qualité qu'on cherche : sous perspective, l'arête proche grossit, et
    /// c'est exactement ce que fait un objet qui se tourne sous un objectif.)
    @State private var tour: Double = 0
    /// L'ASSIETTE : l'inclinaison autour de l'axe horizontal. C'est elle qui
    /// porte le plan. La carte sort du trou presque à plat — on la voit de
    /// dessus, en fuite, son tube en raccourci — et elle se redresse
    /// lentement jusqu'à nous faire face.
    @State private var pente: Double = -74
    /// L'aura : la fumée et la poussière, une fois la carte posée.
    @State private var aura: Double = 0
    /// La montée verticale : elle part de la bouche du trou et vient à nous.
    @State private var monte: CGFloat = 0
    /// Le voile qui éteint la page : la cinématique se joue dans le noir.
    @State private var voile: Double = 0
    /// La carte existe.
    @State private var nee = false
    /// Le tube, et la lumière du bord : ils s'allument avec la naissance.
    @State private var allume: Float = 0
    /// La pose est faite : le chevron et le gain arrivent. Ils ne peuvent pas
    /// exister avant — un bouton qui attend dans un coin pendant un
    /// plan-séquence le désamorce (la leçon de la page du trésor).
    @State private var pose = false

    /// La carte finale fait 80 % de la largeur d'écran. Sur 402 pt ça donne
    /// 322, soit 1,85 fois sa taille de pile.
    private static let finale: CGFloat = 0.80
    /// LE ZOOM EST PETIT, ET C'EST LA CORRECTION DE FOND.
    ///
    /// À 2,9 la carte faisait 933 pt de large sur un écran de 402 : au sommet
    /// du plan il ne restait à l'écran que son APLAT intérieur, agrandi cinq
    /// fois — donc son lustre étiré, son grain gonflé, et pas un bord pour
    /// donner l'échelle. Un objet qu'on grossit jusqu'à ne plus voir sa forme
    /// n'impressionne pas, il devient une texture. Le spectaculaire ne vient
    /// pas de l'échelle : il vient de l'ASSIETTE — une carte vue presque à
    /// plat, qui se redresse.
    ///
    /// 1,16, c'est un souffle : la caméra respire, elle n'attaque pas.
    private static let pic: CGFloat = 1.16
    /// La dérive latérale, en fraction de la largeur d'écran. Petite, elle
    /// aussi : un travelling se sent, il ne se constate pas. À 0,86 la carte
    /// traversait le cadre — c'était une glissade, pas une caméra.
    private static let course: CGFloat = 0.13
    /// L'ASSIETTE DE DÉPART : la carte sort du trou presque À PLAT, vue de
    /// dessus. C'est elle qui porte tout le plan maintenant — une carte qui se
    /// redresse montre sa surface en fuite, son tube en raccourci, et la
    /// lumière qui court dessus. Aucune échelle ne raconte ça.
    private static let assiette: Double = -74

    /// `-wahouLab` ouvre la page directement sur la révélation : la juger
    /// suppose de la rejouer vingt fois, et retraverser tout le geste à chaque
    /// tour est le meilleur moyen de ne jamais la finir.
    static let bench = CommandLine.arguments.contains("-wahouLab")

    var body: some View {
        GeometryReader { geo in
            // La bouche du trou, dans le repère plein écran. Calculée à partir
            // des mêmes constantes que la fente — une cote recopiée ici
            // finirait par diverger, et la carte naîtrait à côté du trou.
            let bouche = geo.size.height - geo.safeAreaInsets.bottom
                       - HaloDeck.fentePied - GoldSlot.height / 2
            let depart = bouche - geo.size.height / 2
            let vraieTaille = geo.size.width * Self.finale / HaloDeckCard.width

            ZStack {
                // LE VOILE. Il ne va PAS au noir pur : la page garde une braise
                // à 8 %, sinon on change d'application au milieu d'un geste. Et
                // c'est cette braise qui donnera son ambiance à la vidéo.
                Color.black
                    .opacity(voile * 0.92)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                if nee {
                    ZStack {
                        // L'aura NE TOURNE PAS avec la carte : une fumée qui
                        // pivote avec l'objet qu'elle entoure devient un décor
                        // collé dessus. Elle suit l'échelle et la place, rien
                        // de plus — elle appartient à la scène, pas à l'objet.
                        WahouAura(vie: aura, devant: 0, touche: touche)
                        // LE DÉMON DE LA CARTE AVALÉE. Le lien est gratuit :
                        // les gains valent 100/200/300 dans cet ordre, donc
                        // l'indice se déduit du montant qui voyage déjà — rien
                        // de plus à faire traverser, et rien qui puisse
                        // diverger de ce que portait la carte dans la pile.
                        WahouCard(allume: allume)
                            // L'ASSIETTE D'ABORD, le tour ensuite : la carte
                            // se couche dans SON plan, puis tourne dans celui
                            // de la scène. L'ordre inverse ferait basculer
                            // l'axe de la pente avec le tour, et l'objet
                            // vrillerait au lieu de se redresser.
                            .rotation3DEffect(.degrees(pente),
                                              axis: (x: 1, y: 0, z: 0),
                                              perspective: 0.62)
                            .rotation3DEffect(.degrees(tour),
                                              axis: (x: 0, y: 1, z: 0),
                                              perspective: 0.46)
                        // Les quelques grains les plus proches passent DEVANT
                        // la carte. C'est ce croisement — deux ou trois devant,
                        // la nuée derrière — qui fait le volume ; sans lui
                        // l'aura est un décor peint.
                        WahouAura(vie: aura, devant: 1, touche: touche)
                    }
                    // LES BORNES AVANT LE GROUPE, ET C'EST OBLIGATOIRE.
                    //
                    // `drawingGroup` rend le sous-arbre dans une texture aux
                    // dimensions de ses BORNES, et rogne tout ce qui déborde.
                    // Sans ce cadre, les bornes valaient celles de la carte
                    // (174 × 224) : l'aura, qui ne dessine QUE dehors, était
                    // intégralement coupée — elle avait disparu — et le débord
                    // du néon de la carte était tranché net à son contour, ce
                    // qui posait autour d'elle un cadre clair à coins arrondis.
                    // Deux défauts qui n'avaient l'air de rien avoir en commun,
                    // une seule cause.
                    .frame(width: HaloDeckCard.width + WahouAura.marge * 2,
                           height: HaloDeckCard.height + WahouAura.marge * 2)
                    // LA FLUIDITÉ SE JOUE ICI, ET NULLE PART DANS LES COURBES.
                    //
                    // Sans `drawingGroup`, chaque image du plongeon redemande
                    // aux trois shaders de se rendre À LA TAILLE TRANSFORMÉE :
                    // au pic, l'aura couvre plus de 2000 pt de large, soit
                    // ~36 millions de pixels par image. Aucune courbe ne rattrape
                    // ça — le mouvement saccade parce qu'il n'y a pas d'images,
                    // pas parce que l'interpolation est mauvaise.
                    //
                    // Avec lui, la scène est rendue UNE fois à sa taille
                    // naturelle (394 × 444 pt) dans une texture, et la caméra
                    // ne fait plus que transformer cette texture. Le contenu
                    // vit à 30 Hz, le mouvement à la cadence de l'écran — c'est
                    // exactement le partage qu'on veut : la matière respire
                    // lentement, la caméra glisse.
                    .drawingGroup()
                    // LE DÉMON RESTE DEHORS, ET C'EST OBLIGATOIRE.
                    //
                    // `drawingGroup` rasterise son sous-arbre en Metal, et il
                    // ne sait pas rendre une vue UIKit : l'`AVPlayerLayer` y
                    // devient un carré jaune barré de rouge — le placeholder
                    // d'une couche qu'il ne peut pas dessiner. La vidéo est
                    // donc SŒUR du groupe, pas fille, et elle reçoit
                    // exactement la même caméra : mêmes rotations dans le même
                    // ordre, et l'échelle et le déplacement portés par le
                    // parent commun. Deux transformations recopiées finiraient
                    // par diverger ; celles-ci sont écrites une fois chacune.
                    .scaleEffect(zoom * taille)
                    .offset(x: pan, y: depart * (1 - monte))
                    .allowsHitTesting(false)

                    // LE DÉMON, SŒUR DU GROUPE ET PAS SA FILLE — deux fois
                    // pour la même raison, et les deux valent d'être dites.
                    //
                    // 1. `drawingGroup` rasterise en Metal et ne sait pas
                    //    rendre une couche UIKit : l'`AVPlayerLayer` y devient
                    //    un carré jaune barré de rouge, le placeholder d'une
                    //    vue qu'il ne peut pas dessiner.
                    // 2. Et `blendMode` posé en `.overlay` PAR-DESSUS ce
                    //    groupe ne fusionnait pas : le rectangle noir de la
                    //    vidéo se posait tel quel sur la carte, plus sombre
                    //    que sa propre matière. Un mode de fusion a besoin
                    //    d'un GROUPE DE COMPOSITION explicite pour savoir avec
                    //    quoi fusionner — sans `compositingGroup`, la vidéo et
                    //    la carte n'appartiennent pas au même calque et
                    //    `plusLighter` n'a rien à additionner.
                    //
                    // Elle reçoit exactement la même caméra : mêmes rotations
                    // dans le même ordre, même échelle, même déplacement.
                    DemonVideo(offre: max(gain / 100 - 1, 0))
                        .frame(width: HaloDeckCard.width
                                      * HaloDeckCard.filmTaille,
                               height: HaloDeckCard.height
                                       * HaloDeckCard.filmTaille)
                        .frame(width: HaloDeckCard.width,
                               height: HaloDeckCard.height)
                        .mask {
                            RoundedRectangle(cornerRadius: HaloDeckCard.radius,
                                             style: .continuous)
                        }
                        .rotation3DEffect(.degrees(pente),
                                          axis: (x: 1, y: 0, z: 0),
                                          perspective: 0.62)
                        .rotation3DEffect(.degrees(tour),
                                          axis: (x: 0, y: 1, z: 0),
                                          perspective: 0.46)
                        .scaleEffect(zoom * taille)
                        .offset(x: pan, y: depart * (1 - monte))
                        .opacity(Double(allume))
                        .blendMode(.plusLighter)
                        .allowsHitTesting(false)
                }

                // LA ZONE DE TOUCHE. Elle est posée à part, à la taille FINALE
                // de la carte et sans transformation : la cible d'un doigt ne
                // doit ni tourner ni voyager avec la caméra. Et elle n'existe
                // qu'une fois la carte posée — pendant le plan-séquence, il n'y
                // a rien à toucher.
                if pose {
                    RoundedRectangle(cornerRadius: HaloDeckCard.radius * taille,
                                     style: .continuous)
                        .fill(.clear)
                        .contentShape(RoundedRectangle(
                            cornerRadius: HaloDeckCard.radius * taille,
                            style: .continuous))
                        .frame(width: HaloDeckCard.width * taille,
                               height: HaloDeckCard.height * taille)
                        .onTapGesture { souffler() }
                }

                // Le gain, SOUS la carte, une fois posée.
                if pose {
                    VStack {
                        Spacer()
                        GainBadge(valeur: gain, echelle: 1.45)
                            .padding(.bottom, geo.size.height * 0.10)
                    }
                    .transition(.opacity)
                }
            }
            // LE GROUPE DE COMPOSITION : c'est lui qui donne au `plusLighter`
            // du démon un calque commun avec la carte. Sans lui, la vidéo se
            // compose sur la fenêtre et son fond noir recouvre l'obsidienne au
            // lieu de disparaître dedans.
            .compositingGroup()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .topTrailing) { chevron }
            .onAppear {
                taille = vraieTaille
                largeur = geo.size.width
                jouer()
            }
        }
        .ignoresSafeArea()
    }

    /// LE CHEVRON, à droite comme la maison le fait ailleurs — 44 pt, coin
    /// continu de 15, verre fumé, liseré blanc à 8 %. Il naît AVEC la pose :
    /// pendant la cinématique il n'y a rien à quitter.
    @ViewBuilder
    private var chevron: some View {
        if pose {
            Button(action: onClose) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background {
                        Color.clear.glassEffect(
                            .regular.tint(Color.black.opacity(0.5)).interactive(),
                            in: RoundedRectangle(cornerRadius: 15,
                                                 style: .continuous))
                    }
                    .overlay(RoundedRectangle(cornerRadius: 15,
                                              style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
                    .contentShape(RoundedRectangle(cornerRadius: 15,
                                                   style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.trailing, 20)
            .padding(.top, 16)
            .transition(.opacity)
            .accessibilityLabel("Fermer")
        }
    }

    // MARK: La partition
    //
    // Les temps sont écrits ici et NULLE PART AILLEURS. Une cinématique dont
    // les beats sont éparpillés dans cinq vues ne se règle jamais : on déplace
    // un temps et deux autres se décalent sans qu'on sache lesquels.

    private func jouer() {
        if Self.bench {
            // Au banc on rejoue en boucle : une cinématique se juge en la
            // regardant SE FAIRE, jamais sur des images figées.
            Timer.scheduledTimer(withTimeInterval: 9.5, repeats: true) { _ in
                remettre()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { partition() }
            }
        }
        partition()
    }

    /// LE TOUCHER : la carte expire. Tout le contour lâche une bouffée d'un
    /// coup — c'est la seule forme qui dise « c'est CETTE carte que tu viens
    /// de toucher », une source ponctuelle de plus se serait fondue dans les
    /// cinq qui tournent déjà.
    private func souffler() {
        touche = .now
        SwapFeedback.shared.ignite()
    }

    private func remettre() {
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) {
            zoom = 1 / taille; pan = 0; monte = 0; voile = 0; nee = false
            allume = 0; pose = false; tour = 0; aura = 0
            pente = Self.assiette
            touche = .distantPast
        }
    }

    private func partition() {
        // La carte part à sa taille de PILE — exactement celle qu'elle avait
        // en entrant dans le trou. C'est la seule valeur de départ qui rend la
        // continuité gratuite : rien à faire coïncider, c'est le même objet.
        var t0 = Transaction(); t0.disablesAnimations = true
        withTransaction(t0) { zoom = 1 / taille; pente = Self.assiette; tour = 0 }

        // 0,00 — LE NOIR TOMBE. Il précède la carte : la page doit s'éteindre
        // AVANT que quelque chose n'arrive, sinon la naissance se fait dans le
        // bruit de l'aurore et on ne la voit pas.
        withAnimation(.easeIn(duration: 0.62)) { voile = 1 }

        // 0,14 — LA NAISSANCE, à la bouche du trou et à sa taille de pile. Le
        // tube s'allume en même temps : c'est la lumière de la fente qui
        // devient celle de la carte, pas une seconde source.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            nee = true
            withAnimation(.easeOut(duration: 0.44)) { allume = 1 }
            // LE PLONGEON, ET SA RAMPE. `timingCurve(0.88, 0.01, 0.20, 1)` :
            // la première demi-seconde ne bouge presque pas, puis la caméra
            // s'élance d'un coup, puis elle s'installe très longuement. C'est
            // ça, « lent puis accéléré » — et c'est la seule façon d'avoir un
            // mouvement LONG qui ne soit pas MOU. Une courbe régulière étirée
            // sur une seconde donne un ascenseur.
            //
            // Le tour part avec le plongeon : l'objet se présente en même
            // temps qu'il s'approche.
            // 1) LA MONTÉE ET LE REDRESSEMENT. La carte sort du trou presque à
            // plat, vue de dessus, et se redresse en venant au centre. C'est
            // ÇA le plan — pas l'échelle. Une seule courbe très longue, qui
            // part à vitesse quasi nulle et met deux secondes à s'installer.
            withAnimation(.timingCurve(0.62, 0, 0.20, 1, duration: 2.05)) {
                zoom = 1.02
                monte = 1
                pente = -21
                tour = -11
                pan = largeur * Self.course * 0.55
            }
        }

        // 0,92 — LE TRAVELLING, pendant le pic. À droite d'abord, LENTEMENT et
        // sur un tiers de la course ; puis le grand balayage vers la gauche,
        // qui accélère. C'est l'asymétrie — durée, amplitude, vitesse — qui
        // fait un mouvement de caméra. Un aller-retour égal, c'est un
        // balancier.
        // LE RACCORD DE VITESSE, et c'est lui qui fait l'élégance. Les deux
        // courses sont à vitesse NULLE à leur jonction — la première finit sur
        // `(…, 0.58, 1)`, la seconde démarre sur `(0.20, 0, …)`, donc dérivée
        // nulle des deux côtés. Un renversement de direction à vitesse non
        // nulle fait un angle, et un angle se voit toujours comme un à-coup,
        // quelle que soit la durée.
        // 2) LE ZOOM « LIMITE FROZEN ». Presque rien bouge, et c'est le
        // morceau de bravoure : quatorze pour cent d'échelle, treize degrés
        // d'assiette et une dérive de vingt-cinq points, étalés sur deux
        // secondes. Une courbe symétrique et molle (0,42 / 0,58) — donc jamais
        // d'accélération franche : le plan RESPIRE, il ne va nulle part.
        // C'est la seule façon de rendre une image somptueuse sans l'agiter.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.19) {
            withAnimation(.timingCurve(0.42, 0, 0.58, 1, duration: 2.00)) {
                zoom = Self.pic
                pente = -8
                tour = 9
                pan = -largeur * Self.course
            }
        }

        // 2,16 — LE RECUL, et LE CHOC AVEC LUI. La vibration ne tombe pas à la
        // fin du mouvement : le corps doit sentir l'impact à l'instant où l'œil
        // voit la carte partir en arrière. Un choc qui arrive après coup se lit
        // comme un bug de synchro, jamais comme une masse.
        // 3) LE DÉZOOM, et LE CHOC AVEC LUI. PLUS DE RESSORT : un ressort sur
        // une caméra se lit comme un élastique, et sur un plan de cette lenteur
        // c'est le seul geste qui pourrait encore faire « cheap ». Une simple
        // décélération très longue, à vitesse nulle à l'arrivée.
        //
        // La carte finit à −4° d'assiette, pas à zéro : une carte parfaitement
        // de face est un ÉCRAN, une carte à quelques degrés reste un OBJET —
        // et c'est cette inclinaison qui donnera son volume à la vidéo.
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.19) {
            SwapFeedback.shared.slam()
            withAnimation(.timingCurve(0.30, 0, 0.12, 1, duration: 1.15)) {
                zoom = 1.0
                pan = 0
                tour = 0
                pente = -4
            }
        }

        // 4,45 — L'AURA. Elle naît AVANT que la carte ait fini de se poser :
        // la fumée est CHASSÉE par le recul, elle ne s'installe pas après coup.
        // Un effet qui démarre une fois l'objet immobile n'a plus de cause.
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.45) {
            withAnimation(.easeOut(duration: 1.10)) { aura = 1 }
        }

        // 5,30 — LA POSE : le chevron et le gain arrivent, une fois que la
        // carte a fini de bouger.
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.30) {
            withAnimation(.easeOut(duration: 0.40)) { pose = true }
        }
    }
}

// MARK: - La carte de la révélation

/// La carte de la pile, en NOIR PUR, tube allumé — et rien d'autre. Le tube
/// n'est pas un ornement ici : la vidéo qui viendra vivre au milieu est sur
/// fond NOIR, sur un voile noir. Sans lui, la carte n'aurait plus de bord du
/// tout et la personne flotterait dans le vide.
///
/// Elle est dessinée à la taille de la pile. C'est la caméra qui l'agrandit —
/// voir la note en tête de fichier.
struct WahouCard: View {
    /// Le tube et la lumière du bord, 0 → 1.
    var allume: Float = 1

    /// La marge du shader : sous le tube allumé, la nappe large porte à 75 pt.
    private static let pad: CGFloat = 62

    var body: some View {
        let w = HaloDeckCard.width + Self.pad * 2
        let h = HaloDeckCard.height + Self.pad * 2
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
            let t = Float(HaloClock.t(tl.date))
            Rectangle()
                .fill(.white)
                .frame(width: w, height: h)
                .colorEffect(ShaderLibrary.swapCard(
                    .float2(Float(w), Float(h)), .float(t),
                    .float(Float(Self.pad)),
                    .float(Float(HaloDeckCard.radius)),
                    .float(0),
                    // `charge` reste à ZÉRO. C'est le paramètre du GESTE : il
                    // épaissit la hairline et masse le foyer du côté où le
                    // doigt tire. Ici plus personne ne tire — la carte est
                    // posée, et une carte posée qui garde la lumière du geste
                    // se lit comme un bouton qu'on presse encore.
                    .float(0),
                    .float2(0, 1),
                    // `lit` porte le tube, seul.
                    .float(allume),
                    // NOIR PUR : la vidéo est sur fond noir, la carte doit
                    // l'être aussi, sinon on verra la dalle autour d'elle.
                    .float(1),
                    .float(Float(HaloDeckCard.horsFente)),
                    // NUE. Le tube reste, le cadre part : `lit` allumait aussi
                    // le liseré de l'arête, sa buée et les paillettes — soit
                    // une bande grise à coins arrondis autour d'un aplat noir,
                    // sur fond noir. Exactement la grammaire refusée huit fois
                    // sur la fente.
                    .float(1)))
        }
        .frame(width: HaloDeckCard.width, height: HaloDeckCard.height)
        // Le démon ne vit PAS ici mais dans `WahouReveal`, sœur du
        // `drawingGroup` : cette vue-ci est rasterisée, et une couche UIKit ne
        // survit pas à une rasterisation Metal.
        .allowsHitTesting(false)
    }
}

// MARK: - L'aura

/// Ce qui vit AUTOUR de la carte posée : les éclats de fumée noire et la
/// poussière de diamant. Tout est dans `wahouAura` (WahouAura.metal) — la vue
/// n'est que son hôte, avec la marge dont la nuée a besoin.
///
/// Elle est dessinée dans le repère de la carte à sa taille de PILE, et c'est
/// la caméra qui l'agrandit. Le shader rend donc moins d'un demi-écran même
/// quand l'aura couvre tout — et le grain de la poussière GROSSIT avec le
/// zoom, ce que fait un vrai objectif.
struct WahouAura: View {
    var vie: Double
    /// 0 : la nuée, derrière la carte. 1 : les quelques grains qui passent
    /// devant elle.
    var devant: Double
    /// L'instant du toucher. La DATE traverse, l'âge se calcule ici — sous
    /// l'horloge 30 Hz de l'aura. Calculé dehors, il ne serait rafraîchi qu'aux
    /// rares redessins de la scène et la bouffée avancerait par saccades.
    var touche: Date = .distantPast

    /// La marge, dans le repère de la pile. 110 pt ici valent plus de 200 pt à
    /// l'écran une fois la caméra posée : la fumée a de quoi mourir avant le
    /// bord de son rectangle. Une volute coupée net se lit comme une plaque.
    ///
    /// Non privée : c'est elle qui donne ses bornes au `drawingGroup` de la
    /// scène. Une texture plus petite que l'aura rognerait l'aura.
    static let marge: CGFloat = 110

    var body: some View {
        let w = HaloDeckCard.width + Self.marge * 2
        let h = HaloDeckCard.height + Self.marge * 2
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
            let t = Float(HaloClock.t(tl.date))
            let age = Float(tl.date.timeIntervalSince(touche))
            Rectangle()
                .fill(.white)
                .frame(width: w, height: h)
                .colorEffect(ShaderLibrary.wahouAura(
                    .float2(Float(w), Float(h)), .float(t),
                    .float2(Float(HaloDeckCard.width / 2),
                            Float(HaloDeckCard.height / 2)),
                    .float(Float(HaloDeckCard.radius)),
                    .float(Float(vie)), .float(Float(devant)),
                    .float(age > 3 ? -1 : age)))
        }
        .frame(width: HaloDeckCard.width, height: HaloDeckCard.height)
        .allowsHitTesting(false)
    }
}

// MARK: - Le jeton de gain

/// La pièce de lune de la maison et le montant, dans une capsule d'obsidienne.
/// Partagé par la pile et par la révélation : deux copies d'un même jeton
/// finissent toujours par diverger d'un point de rayon ou d'un demi-ton.
///
/// La pièce est FIGÉE (lacet imposé, vie au repos coupée) : à ce diamètre son
/// croissant ne vaut que quelques pixels, l'animer coûterait un shader de plus
/// pour du frémissement que personne ne verrait.
struct GainBadge: View {
    var valeur: Int
    /// 1 dans la pile ; plus grand sous la carte de la révélation, où le jeton
    /// est seul en scène et doit tenir l'échelle.
    var echelle: CGFloat = 1

    var body: some View {
        HStack(spacing: 6 * echelle) {
            // Le double cadre : le grand porte le bloom du shader, le petit
            // décide de la place que le jeton prend dans la capsule. Sans lui,
            // la marge du bloom (3,4 rayons) rendrait le badge deux fois trop
            // haut ; en clipant, on couperait le bloom net.
            MoonCoinView(coinR: 9 * echelle, draggable: false, yawOverride: 0,
                         idleLife: 0, fps: 6)
                .frame(width: 9 * echelle * MoonCoinView.hostScale,
                       height: 9 * echelle * MoonCoinView.hostScale)
                .frame(width: 21 * echelle, height: 21 * echelle)
            Text("\(valeur)")
                .font(.inter(13 * echelle, .semibold))
                .foregroundStyle(Color(red: 1.0, green: 0.93, blue: 0.80))
        }
        .padding(.leading, 4 * echelle)
        .padding(.trailing, 12 * echelle)
        .padding(.vertical, 5 * echelle)
        // Le jeton reprend la matière de la carte : un noir profond, posé sans
        // contour. Sur l'orange du fond, c'est le contraste qui le détache —
        // jamais un liseré.
        .background {
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.88))
        }
    }
}
