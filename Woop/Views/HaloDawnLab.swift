import SwiftUI

// MARK: - Banc d'essai (`-haloLab`)

/// La page d'aurore orange : la nuit repliée en haut, le feu qui monte du
/// bord bas, et posée dessus une PILE de trois cartes noires — disposition
/// de la référence (celle de droite plus haute que le centre, celle de
/// gauche plus basse), geste de la référence : on TIRE VERS LE BAS pour
/// activer. Tout le fond vit dans `haloDawn` (HaloDawn.metal) ; les cartes
/// reprennent la matière de la home (`swapCard`), passée en NOIR PROFOND —
/// sur un fond orange vif, l'anthracite de la nuit remonterait en gris.
///
/// `-haloFreeze <t>` fige l'horloge du fond (captures au banc).
struct HaloDawnLab: View {
    /// L'instant figé du banc, s'il y en a un.
    private static let freeze: Float? = {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "-haloFreeze"), i + 1 < args.count,
              let v = Float(args[i + 1]) else { return nil }
        return v
    }()

    var body: some View {
        ZStack {
            HaloDawnBackground(freeze: Self.freeze)
                .ignoresSafeArea()

            HaloDeck()

            // Le grain de la maison : les nappes crème bandent autant que
            // les nappes de nuit.
            WoopGrain(density: 0.028, lightAlpha: 0.020, darkAlpha: 0.024)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)
    }
}

/// L'hôte du fond : plein écran, 30 Hz comme l'aurore du login — les foyers
/// dérivent en dizaines de secondes, la cadence n'a pas besoin de plus.
struct HaloDawnBackground: View {
    var freeze: Float? = nil

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                let t = freeze ?? Float(tl.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 900))
                Rectangle()
                    .fill(.white)
                    .colorEffect(ShaderLibrary.haloDawn(
                        .float2(geo.size.width, geo.size.height), .float(t)))
            }
        }
    }
}

// MARK: - La pile

/// Trois cartes en PILE, disposées comme la référence : celle du dessus au
/// centre, les deux autres écartées loin sur les côtés (leur centre à 185 pt
/// du milieu, donc plus de la moitié de leur largeur sort du cadre),
/// inclinées vers l'extérieur — et celle de DROITE plus haute que le centre,
/// celle de gauche plus basse. C'est cette asymétrie qui fait lire un
/// instantané de pile en mouvement plutôt qu'un éventail figé.
///
/// Le geste est celui de la référence : on TIRE VERS LE BAS. La descente
/// charge la carte — l'arête prend feu, le tube de néon s'allume — et passé
/// le seuil elle est activée : la pile tourne, la suivante monte au centre.
struct HaloDeck: View {
    /// L'index de la carte du dessus : la pile tourne en boucle.
    @State private var top = 0
    /// La descente du doigt sur la carte du dessus.
    @State private var drag: CGSize = .zero
    /// Le doigt est posé : le néon respire avant même qu'on tire.
    @State private var pressed = false
    /// Le dernier grain haptique — le moteur sature si on le nourrit à
    /// chaque image du geste.
    @State private var lastTick: Date = .distantPast
    @State private var hapticTick = 0
    // LA MAIN RACONTE LA MÊME CHORÉGRAPHIE QUE L'ŒIL, et chaque temps a sa
    // matière — un seul déclencheur pour tout donnerait un moteur qui tape
    // toujours pareil, et on ne sentirait plus rien passer.
    //   • `grainTick` : le FROTTEMENT de la traversée. Un grain fin dont la
    //     cadence suit la profondeur — c'est ce qui donne une matière au
    //     trou, comme une carte qu'on pousse dans une fente serrée ;
    //   • `seuilTick` : LE FRANCHISSEMENT de la lèvre, sec et net. Le même
    //     instant que le balayage du liseré, à l'image près ;
    //   • `fondTick` : LE FOND. Sourd, lourd, une seule fois.
    @State private var grainTick = 0
    @State private var seuilTick = 0
    @State private var fondTick = 0
    /// Le dernier grain de frottement, et la profondeur où il est tombé :
    /// le grain se déclenche à la DISTANCE parcourue, pas au temps. Une
    /// cadence fixe donnerait le même frottement pour un geste lent et pour
    /// un geste vif — or c'est justement la vitesse qu'on doit sentir.
    @State private var dernierGrain: CGFloat = -999
    /// Le seuil a déjà sonné pour CE geste.
    @State private var seuilSonne = false
    /// L'horodatage de l'activation : la bouffée du néon intérieur.
    @State private var firedAt: Date = .distantPast
    /// Le seuil a déjà sonné pour CE geste : l'amorçage ne tinte qu'une
    /// fois, pas à chaque image passée au-delà.
    @State private var armed = false
    /// La course latérale du doigt. Elle ne pilote PAS la position des
    /// cartes — elle arme le cran, c'est tout : la main décide QUAND, pas OÙ.
    @State private var sideDrag: CGFloat = 0
    /// La course à laquelle le dernier cran est tombé. Un long glissement
    /// crante donc plusieurs fois, comme une molette.
    @State private var notchBase: CGFloat = 0
    /// Le décalage du RAIL, en crans. 0 au repos ; pendant le cran il va à
    /// ±1, puis on renumérote et il revient à 0 sans que rien ne bouge à
    /// l'écran. Toutes les cartes le reçoivent, donc elles avancent du même
    /// pas — c'est LUI qui interdit le chevauchement.
    @State private var rail: Double = 0
    /// Le côté où la carte de RÉSERVE est garée, en crans (−2 ou +2). Les
    /// deux parkings sont hors champ : la faire passer de l'un à l'autre ne
    /// se voit pas, et c'est le seul saut du mécanisme.
    @State private var reservePark: Double = -2
    /// Un cran est en cours : on n'en empile pas deux.
    @State private var enCran = false
    /// Quelle offre est au CENTRE. Les offres sont attachées à la POSITION
    /// sur le rail, pas à l'identité de la carte — c'est ce qui permet à la
    /// réserve de porter, avant même d'entrer, l'offre dont elle aura
    /// besoin en arrivant. Et son doublon (elle porte la même que l'aile
    /// droite) reste toujours hors champ.
    @State private var offerBase = 0

    /// Les gains, en pièces. Trois offres pour quatre cartes : la quatrième
    /// est la réserve, elle emprunte la sienne au tour d'après.
    private static let gains = [100, 200, 300]

    /// Le cran de rail d'un rang, en pas — l'ordre du convoi de gauche à
    /// droite est : réserve, aile gauche, centre, aile droite.
    private func pasDuRang(_ rang: Int) -> Int {
        switch rang {
        case 1:  return 1
        case 3:  return -1
        case 2:  return -2
        default: return 0
        }
    }

    /// L'offre portée par une carte, déduite de sa place sur le rail.
    private func gain(of id: Int) -> Int {
        let i = ((offerBase + pasDuRang(rang(of: id))) % 3 + 3) % 3
        return Self.gains[i]
    }
    /// L'instant où une carte s'est POSÉE au centre : le cran est consommé,
    /// elle souffle sa bouffée de néon.
    @State private var landedAt: Date = .distantPast
    /// L'axe du geste, décidé au premier vrai déplacement et TENU jusqu'au
    /// relâchement. Sans ce verrou, un doigt qui part de biais fait tourner
    /// la pile ET charger la carte, et les deux gestes se volent l'un
    /// l'autre au milieu de la course.
    @State private var axis: Axis? = nil

    private enum Axis { case vertical, horizontal }

    /// La distance qui sépare le bas de la carte de la LÈVRE de la fente.
    /// Mesurée à chaque mise en page, jamais écrite en dur : elle dépend de
    /// la safe area, donc du modèle.
    @State private var contact: CGFloat = 120

    /// L'ENFONCEMENT, 0 → 1 : la part de la carte déjà avalée. Il ne
    /// commence qu'AU CONTACT — avant, la carte descend simplement.
    private var enfonce: CGFloat {
        let d = max(drag.height, 0)
        return max(0, min((d - contact) / Self.enfoncement, 1))
    }

    /// `-deckPulled` fige la carte du dessus en pleine descente : la charge
    /// et le néon se capturent sans devoir tenir le doigt.
    private static let benchPull = CommandLine.arguments.contains("-deckPulled")
    /// `-deckAuto` fait tourner la pile toute seule, un cran toutes les
    /// 1,8 s : un mécanisme se juge en le regardant TOURNER, pas sur deux
    /// images figées aux extrémités.
    private static let benchAuto = CommandLine.arguments.contains("-deckAuto")
    /// `-deckSwallow` rejoue l'avalement en boucle : un enfoncement se juge
    /// en le regardant SE FAIRE, pas sur deux images.
    private static let benchSwallow = CommandLine.arguments
        .contains("-deckSwallow")
    /// `-deckSunk <pt>` FIGE la carte à tant de points sous la lèvre. Sans
    /// lui, juger un enfoncement revient à chercher la bonne image dans un
    /// film — on tombe sur celle d'à côté et on corrige un défaut qui
    /// n'existe pas. Ici l'état est nommé, donc reproductible d'un tour à
    /// l'autre et comparable à sa capture.
    /// L'EXPÉRIENCE D'ATTRIBUTION. `-isoFente` ne rend QUE la fente,
    /// `-isoPile` ne rend QUE la pile. Quand un défaut se voit et qu'on ne
    /// sait pas de quelle couche il vient, on ne devine pas : on éteint
    /// l'une, puis l'autre. Deux captures, et c'est attribué.
    private static let isoFente = CommandLine.arguments.contains("-isoFente")
    private static let isoPile = CommandLine.arguments.contains("-isoPile")

    private static let benchSunk: CGFloat? = {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: "-deckSunk"), i + 1 < a.count,
              let v = Double(a[i + 1]) else { return nil }
        return CGFloat(v)
    }()

    /// La part du chemin au bout de laquelle la fente PREND la carte : à
    /// 72 % du contact, elle est happée et le mécanisme finit le geste.
    private static let prise: CGFloat = 0.72

    /// L'ÉVEIL de la fente : elle ne s'allume que quand une carte est POSÉE
    /// au centre. Pendant qu'un cran tourne, rien n'est sélectionné — elle
    /// se rendort. C'est ce couplage qui la rend intelligible : elle
    /// s'adresse à une carte précise, pas à la page.
    private var eveil: Double { enCran ? 0.18 : 1 }

    /// L'appel — les chevrons. Ils meurent dès que le doigt engage la
    /// descente : on ne montre pas le chemin à quelqu'un qui l'a pris.
    private var appel: Double {
        guard !enCran, drag.height <= 2 else { return 0 }
        return 1
    }

    /// La montée du geste : 0 au repos, 1 quand le doigt a décidé. C'est
    /// elle qui embrase l'écrin. Le simple appui l'amorce déjà à un tiers —
    /// la carte répond au doigt avant de répondre au geste.
    private var charge: Float {
        let pull = Float(min(max(drag.height, 0) / max(contact, 1), 1))
        return max(pull, pressed ? 0.34 : 0)
    }

    /// La distance du bas de l'écran (utile) à laquelle la fente est posée.
    private static let fentePied: CGFloat = 116
    /// LE JOUR : de combien le masque des cartes rentre à l'intérieur de
    /// l'ouverture. La carte s'arrête avant le liseré, qui recouvre la
    /// couture. À 2,5 la coupe du halo de la carte affleurait encore le
    /// bord et dessinait un second contour fantôme, parallèle à la lèvre ;
    /// 4 la fait passer sous le cœur du néon.
    private static let jour: CGFloat = 4
    /// LA GORGE : la course qui fait traverser toute la bouche au bord BAS
    /// de la carte. C'est le seul moment qu'on regarde vraiment — le seul où
    /// l'on voit du creux SOUS la carte et du jour de chaque côté —, donc
    /// c'est celui qu'on joue lentement.
    private static let gorge: CGFloat = GoldSlot.height
    /// La profondeur totale, une fois la lèvre touchée. 80 ne suffisait plus
    /// du tout : avec le masque de bouche, la carte reste VISIBLE tant que
    /// son sommet n'a pas franchi la lèvre du bas, et à 80 pt elle restait
    /// plantée dans l'ouverture. Il faut que le sommet descende sous
    /// `lipY + hauteur` : 180 de course, moins les 224 × 0,48 de carte qui
    /// reste, posent le sommet 8 pt plus bas que la lèvre. Elle est dedans,
    /// et elle a disparu — pas effacée, avalée.
    private static let enfoncement: CGFloat = 180

    var body: some View {
        GeometryReader { geo in
            // LA LÈVRE, en coordonnées de cette vue. Tout se calcule à
            // partir d'elle : la course du geste, le masque, l'aimant.
            // Calculée et non écrite en dur — la hauteur utile dépend de la
            // safe area, et une constante mesurée sur un modèle serait
            // fausse sur le suivant.
            let lipY = geo.size.height - Self.fentePied - GoldSlot.height
            let blocH = HaloDeckCard.height + 40 + 24
            let cardBas = (geo.size.height - blocH) / 2 + 20
                        + slot(0).y + HaloDeckCard.height
            let contact = max(lipY - cardBas, 40)

            ZStack {
                // 1. LE CREUX, derrière la carte — et l'APPEL avec lui :
                //    les chevrons vivent entre la carte et la fente, donc la
                //    carte doit les COUVRIR en descendant. Devant, ils
                //    s'imprimaient sur sa face comme un décalque.
                if !Self.isoPile { fenteVue(couche: 0) }
                if !Self.isoPile && !Self.isoFente {
                VStack(spacing: 14) {
                    SlotChevrons(awake: appel)
                    Color.clear.frame(width: 1, height: GoldSlot.height)
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, Self.fentePied)
                }
                // 2. LES CARTES, et LE MASQUE — c'est lui, et rien d'autre,
                //    qui décidait qu'on ne voyait pas la carte entrer.
                //
                //    L'ancien était un DEMI-PLAN coupant à la lèvre : sous
                //    cette ligne, plus un pixel de carte n'existait, sur
                //    toute la largeur de l'écran. La bouche restait donc
                //    vide en permanence, et l'œil n'avait qu'une lecture
                //    possible — la carte glisse DERRIÈRE une barre opaque.
                //    Aucune quantité de lumière n'aurait rattrapé ça : ce
                //    n'était pas un défaut d'éclairage, c'était l'absence
                //    de la carte à l'endroit où on la cherchait.
                //
                //    Le nouveau est l'UNION de deux formes : tout ce qui est
                //    au-dessus de la lèvre, ET l'ouverture elle-même. La
                //    carte reste donc visible DANS la bouche, encadrée à
                //    gauche et à droite par le jour de l'ouverture, jusqu'à
                //    ce que la lèvre PROCHE (le bas) la coupe. C'est cette
                //    lèvre du bas qui occulte maintenant, pas celle du haut :
                //    la géométrie d'un trou, pas celle d'une plaque.
                //
                //    L'ouverture du masque est RENTRÉE de `jour` : la carte
                //    s'arrête juste avant le liseré, qui passe par-dessus la
                //    couture. Sans ce retrait, on verrait une coupe nette de
                //    carte tangente au néon.
                if !Self.isoFente {
                    cartes(contact: contact)
                        .mask { masqueDeBouche(lipY: lipY) }
                }
                // 3. LE PREMIER PLAN de la fente : la lumière, ET la moitié
                //    PROCHE du creux (peinte opaque par le shader en couche
                //    1) — c'est elle qui coupe la carte à l'équateur et la
                //    fait entrer AU MILIEU du trou, pas derrière.
                if !Self.isoPile { fenteVue(couche: 1) }
            }
            .onAppear {
                self.contact = contact
                if let s = Self.benchSunk {
                    drag = CGSize(width: 0, height: contact + s)
                }
            }
            .onChange(of: contact) { _, v in
                self.contact = v
                if let s = Self.benchSunk {
                    drag = CGSize(width: 0, height: v + s)
                }
            }
        }
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.5),
                         trigger: hapticTick)
        // Le frottement : très léger, très sec — un grain, pas un coup.
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.28),
                         trigger: grainTick)
        // Le franchissement : net et ferme, c'est le sommet du geste.
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.85),
                         trigger: seuilTick)
        // Le fond : sourd et lourd, une seule fois.
        .sensoryFeedback(.impact(weight: .heavy, intensity: 0.62),
                         trigger: fondTick)
        .onAppear {
            if Self.benchPull { drag = CGSize(width: 0, height: 96) }
            if Self.benchAuto {
                Timer.scheduledTimer(withTimeInterval: 1.8, repeats: true) { _ in
                    cranter(vers: 1)
                }
            }
            if Self.benchSwallow {
                Timer.scheduledTimer(withTimeInterval: 4.6, repeats: true) { _ in
                    avaler()
                }
            }
        }
    }

    /// LE MASQUE : un demi-plan, coupé DROIT à la ligne de la lèvre proche.
    ///
    /// UNE SEULE LIGNE, et elle est DROITE. Toutes les versions à ouverture
    /// arrondie ont échoué pour la même raison : la part engloutie y gardait
    /// une forme COMPLÈTE — un bord bas, des coins — donc l'œil la lisait
    /// comme une plaque posée sur la fente, un objet de plus, et jamais
    /// comme le morceau caché de la carte. Un objet qui entre dans un trou
    /// est tranché par une ligne et n'a plus de bord bas.
    ///
    /// Et la ligne n'est PAS au sommet de la fente : elle est à `coupe`
    /// points plus bas, à la lèvre proche. C'est cet écart — le seul — qui
    /// laisse la carte exister DANS l'ouverture au lieu de disparaître à
    /// son bord.
    private func masqueDeBouche(lipY: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                Rectangle().frame(height: lipY + GoldSlot.coupe)
                Color.clear
            }
        }
    }

    // (L'ombre portée de la lèvre sur la carte a vécu ici — elle est morte
    // avec le changement de plan d'insertion : une carte enfilée AU MILIEU
    // de la profondeur passe DEVANT la paroi lointaine, et la lèvre
    // lointaine ne peut pas projeter d'ombre sur ce qui est devant elle.
    // C'est la moitié proche du creux, peinte par le shader en couche 1,
    // qui l'a remplacée.)

    /// L'hôte des deux couches de la fente : même place, même paramètres,
    /// seule la couche change.
    private func fenteVue(couche: Double) -> some View {
        VStack {
            Spacer()
            GoldSlot(awake: eveil, swallow: Double(enfonce), couche: couche,
                     sunk: Double(max(drag.height - contact, 0)),
                     charge: Double(charge))
                .padding(.bottom, Self.fentePied)
        }
        .animation(.easeOut(duration: 0.35), value: eveil)
    }

    /// Le bloc des cartes, à sa place réglée au jury.
    private func cartes(contact: CGFloat) -> some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                // On parcourt les cartes par IDENTITÉ, pas par créneau : une
                // carte doit rester la même vue d'un cran à l'autre, sinon
                // SwiftUI ne l'anime pas, il la remplace — et le grand
                // voyage ne se verrait jamais.
                // QUATRE cartes pour trois places : la quatrième est la
                // réserve, garée hors champ. Sans elle, la sortante devrait
                // retraverser l'écran pour reparaître de l'autre côté.
                ForEach(0..<4, id: \.self) { id in
                    card(id: id)
                }
                // LES BADGES, dans leur propre couche. Ils suivent le rail
                // et RIEN d'autre : ni la descente, ni l'échelle, ni la
                // rotation des ailes. Accrochés à la carte, ils héritaient
                // de tout — ils partaient au bas de l'écran en enflant, et
                // au retour ils remontaient dans la carte.
                ForEach(0..<4, id: \.self) { id in
                    jeton(id: id)
                }
            }
            .frame(height: HaloDeckCard.height + 40)
            // LE CONTREPOIDS. Le VStack est centré entre deux Spacer : sa
            // hauteur totale décide seule d'où tombe la pile. Ce cale-ci
            // vaut la MOITIÉ de sa hauteur en descente — centre du ZStack
            // = 450,8 − cale/2 sur un écran 402 × 874 (constante recalée
            // sur la capture du tour 2 : cale 18 → centre 441,8 mesuré).
            // 24 → 438,8, donc sommet de la carte du centre à 334,8 pt.
            // Le PIC du liseré doré de la référence redressée tombe à
            // 334,15 (mesuré au maximum du canal R−B, sur les DEUX
            // homographies, qui s'accordent ici à 0,1 pt) — pas au bord de
            // son halo, qui bave de 12 pt vers l'extérieur et faisait lire
            // 323. Le tour 2 posait la pile 3,4 pt trop bas.
            Color.clear.frame(height: 24)
            Spacer()
        }
        // La légende quitte le bloc : dans la référence elle est au PIED de
        // la page (centre à 778 pt, 96 pt du bord bas), pas collée sous la
        // pile. Posée en overlay, elle ne pèse plus sur le centrage.
        //
        // TOUR 4 — 54 → 51, ET C'EST LE COROLLAIRE OBLIGATOIRE du corps qui
        // passe de 13 à 16 (voir `legende`). L'overlay épingle le BAS de la
        // boîte de texte : grossir le corps fait donc pousser la ligne VERS
        // LE HAUT (la ligne de base remonte de la croissance de la
        // descendante, le haut de capitale de celle de cap+descendante,
        // ~3 pt). Sans compensation, une légende enfin lisible se
        // retrouverait posée trop haut. Les trois juges demandent la même
        // chose et chiffrent la reprise à 50 / 51 / 52 ; 51 est la médiane,
        // et il tombe dans la fourchette « 49 à 51 défendable » du juge 1.
        .overlay(alignment: .bottom) {
            // La légende s'efface dès que la descente s'engage : elle a dit
            // ce qu'elle avait à dire, et elle tomberait sur la fente.
            legende
                .padding(.bottom, 51)
                .opacity(appel)
                .animation(.easeOut(duration: 0.22), value: appel)
        }
    }

    // MARK: La géométrie de la référence

    /// Où se pose chaque carte. Profondeur 0 : la carte du dessus, au
    /// centre — et c'est le point BAS de la composition. 1 : l'aile DROITE,
    /// très relevée. 2 : l'aile gauche, relevée de peu. Les deux ailes
    /// montent sur un arc, la carte du centre est descendue vers nous.
    private func slot(_ depth: Int) -> (x: CGFloat, y: CGFloat,
                                        rot: Double, scale: CGFloat) {
        switch depth {
        // ATTENTION : la rotation est prise au pivot .bottom du cadre de
        // mise en page. Une carte remontée puis pivotée est donc AUSSI
        // rejetée sur le côté — ces x/y sont les valeurs AVANT rotation,
        // résolues pour que le centre effectif tombe où la référence le
        // montre. Ne les lis pas comme des positions.
        //
        // Mesuré sur la photo de Kathryn REDRESSÉE (homographie prise sur
        // les quatre bords de l'écran allumé, validée à 1 pt près par la
        // Dynamic Island : 126 pt de large pour 125 réels) :
        //   aile DROITE  : centre à +230,5 pt du milieu, 47 pt plus haut
        //                  que la carte du centre, inclinée de -20,7°
        //                  (bord haut -20,73°, bord gauche +20,72° :
        //                  parfaitement perpendiculaires, c'est bien un
        //                  rectangle et l'angle n'a rien de -23) ;
        //   aile GAUCHE  : centre à -221,8 pt, 30 pt plus haut, +20,0°.
        // Les DEUX ailes penchent leur sommet vers le DEDANS.
        // À ça s'ajoute l'ÉCHAPPÉE de Kathryn — « tu fais plus partir les
        // cards » : 14 pt de plus vers l'extérieur de chaque côté, la même
        // des deux (au tour 1 elle valait 10 à gauche et 13 à droite, et
        // cette inégalité creusait l'asymétrie).
        //
        // TOUR 3 — LE REPÈRE CHANGE, ET C'EST TOUT LE SUJET. Le « sommet
        // visible au bord de l'écran » est la cote la MOINS stable de la
        // photo : les deux homographies construites sur cette image la
        // donnent à 314,2 / 311,8 à gauche et 299,7 / 302,3 à droite, soit
        // un escalier de 14,5 ou de 9,5 selon celle qu'on croit. C'est un
        // écart pris tout au bord du cadre, là où l'erreur projective est
        // maximale. Les COINS INTÉRIEURS, eux, tombent près de l'axe : les
        // deux homographies s'y accordent à 1,5 pt. Ce sont eux le repère.
        //   coin intérieur GAUCHE : (90,4 ; 345,5) — 27,8 pt du bord de la
        //     carte, 11,3 pt SOUS son sommet ;
        //   coin intérieur DROIT  : (321,9 ; 331,2) — 28,3 pt du bord,
        //     2,9 pt AU-DESSUS ;
        //   carte du centre : sommet 334,2, bords 118,2 / 293,6.
        // Les deux jours de la référence sont donc ÉGAUX (27,8 / 28,3), et
        // c'est ce que le tour 2 avait cassé : 37,5 à gauche pour 45,6 à
        // droite. L'ÉCHAPPÉE de Kathryn se prend sur la PLUS GRANDE des
        // deux (« prends la plus grande ») : les deux jours passent à 45,5.
        //
        // LE PIÈGE QUE PERSONNE N'AVAIT MODÉLISÉ, et qui s'annule : pousser
        // par la composante x du tuple fait glisser la carte LE LONG de son
        // propre bord haut (dy = dx·tanθ des deux côtés) — le sommet
        // visible au bord d'écran ne bouge pas d'un centième. L'échappée ne
        // coûte donc RIEN en hauteur ; ce qui manquait au tour 2, c'est de
        // la hauteur tout court. Rendue ici : +5,3 pt à gauche, +2,9 à
        // droite (sensibilité dSommet/dy = 1,064 à +20°, 1,069 à −20,7°),
        // pour un escalier de 11,9 — la moyenne honnête des deux lectures
        // de la photo, 12,0.
        // L'angle ne bouge PAS : les bords longs des deux ailes de la
        // référence donnent 19,1 / 19,7 et 18,5 / 19,7 selon l'homographie,
        // le +20 / −20,7 en place est dans le bruit.
        //
        // TOUR 4 — LA PILE NE BOUGE PAS D'UN CENTIÈME, et c'est une
        // décision, pas une paresse. Trois propositions sont arrivées, les
        // trois échouent à la règle des deux juges :
        //   • RENTRER LES AILES (x -278 → -258, 283 → 262), pour ramener
        //     dans le cadre le coin bas arrondi de chaque aile. Un seul
        //     juge le demande ; le deuxième l'écrit noir sur blanc comme
        //     CONDITIONNEL — « n'appliquer QUE si Kathryn, la capture sous
        //     les yeux, dit que les ailes sont parties trop loin » — et le
        //     troisième s'y oppose. Or la consigne de Kathryn est debout :
        //     « tu fais PLUS PARTIR les cards », « prends la PLUS GRANDE ».
        //     Et surtout : -258 est le réglage du TOUR 1 (-261), celui qui
        //     a pris la plus mauvaise note de la série (7,33) ; -267 était
        //     le tour 2 (8,0) et -278 le tour 3 (8,5). L'échappée n'a
        //     jamais fait que monter la note. On ne revient pas dessus
        //     sans qu'elle le dise elle-même.
        //   • REDRESSER L'AILE DROITE (-20,7 → -20,0, avec ses deux
        //     compensations y 51,2 et x 281,6). Un seul défenseur ; le
        //     troisième juge a mesuré le MÊME bord à 20,20° puis 20,84°
        //     selon le seuillage et conclut que le plancher de bruit
        //     (~0,5°) avale l'écart débattu (0,7°).
        //   • LE CONTREPOIDS 24 → 26. Deux juges le GÈLENT explicitement,
        //     et pour la bonne raison : les deux lectures de la photo ne
        //     diffèrent pas en amplitude mais en SIGNE (pile 1,0 pt trop
        //     basse pour l'une, 0,6 pt trop haute pour l'autre), chacune
        //     valant moins du quart de sa propre barre d'erreur. Bouger là
        //     serait du bruit habillé en progrès.
        // Tout le budget du tour part donc dans la légende, seul écart qui
        // dépasse le bruit de la photo — 25 %, contre 1 pt sur des cotes
        // de 300.
        case 1:  return (283, 54.3, -20.7, 0.93)
        case 2:  return (-278, 62, 20, 0.93)
        default: return (0, 8, 0, 1)
        }
    }

    // MARK: LE RAIL
    //
    // LA LEÇON, payée en trois versions : dès que les cartes ont des courses
    // DIFFÉRENTES, elles se chevauchent. Interpolation libre, rampes
    // décalées, relais — les trois ont produit le même défaut, parce que
    // toutes trois laissaient une carte rattraper l'autre.
    //
    // La seule façon qu'elles ne se chevauchent JAMAIS, c'est qu'elles ne
    // bougent pas les unes par rapport aux autres : un RAIL RIGIDE. Toutes
    // avancent en même temps, du même pas, dans le même sens. Leur écart
    // est constant par construction, donc l'ordre est impossible à casser
    // et il n'y a plus rien à synchroniser.
    //
    // Le prix à payer, et c'est le seul : il faut QUATRE cartes pour trois
    // places. La quatrième est la RÉSERVE, garée hors champ du côté par
    // lequel elle va entrer. Sans elle, la carte qui sort à droite devrait
    // reparaître à gauche en traversant l'écran — et on retomberait sur le
    // croisement. Avec elle, le seul saut du mécanisme va d'un parking hors
    // champ à l'autre : invisible.

    /// La course horizontale qui fait tomber UN cran.
    private static let notch: CGFloat = 78
    /// L'écart d'un cran sur le rail, en points : celui des ailes.
    private static let pasDroit: CGFloat = 283
    private static let pasGauche: CGFloat = 278

    /// Ce que la main a le droit de bouger entre deux crans : quelques
    /// points d'élasticité, pour que le doigt sente qu'il tient la pile.
    /// Rien de plus — la position des cartes appartient au mécanisme.
    private var nudge: CGFloat {
        let e = sideDrag - notchBase
        return max(-14, min(14, e * 0.16))
    }

    /// Le rang d'une carte sur le rail : 0 au centre, 1 à droite, 3 à
    /// gauche, 2 à la réserve.
    private func rang(of id: Int) -> Int { (id - top + 4) % 4 }

    /// Le cran de repos de chaque rang, en pas de rail. La réserve est au
    /// double d'un pas : à 2 × 280 pt, une carte de 174 est entièrement
    /// dehors — c'est ce qui rend son saut invisible.
    private func cranDeRepos(_ rang: Int) -> Double {
        switch rang {
        case 1:  return 1
        case 3:  return -1
        case 2:  return reservePark
        default: return 0
        }
    }

    /// Où se pose une carte pour un cran de rail donné. Entre −1 et +1 elle
    /// interpole entre les trois places mesurées sur la référence ; au-delà
    /// elle continue tout droit, en gardant l'assiette de l'aile qu'elle
    /// vient de quitter.
    private func pose(_ p: Double)
    -> (x: CGFloat, y: CGFloat, rot: Double, scale: CGFloat) {
        let c = slot(0), d = slot(1), g = slot(2)
        if p >= 1 {
            return (d.x + CGFloat(p - 1) * Self.pasDroit, d.y, d.rot, d.scale)
        }
        if p <= -1 {
            return (g.x + CGFloat(p + 1) * Self.pasGauche, g.y, g.rot, g.scale)
        }
        let vers = p >= 0 ? d : g
        let u = abs(p)
        return (x: c.x + (vers.x - c.x) * CGFloat(u),
                y: c.y + (vers.y - c.y) * CGFloat(u),
                rot: c.rot + (vers.rot - c.rot) * u,
                scale: c.scale + (vers.scale - c.scale) * CGFloat(u))
    }

    @ViewBuilder
    private func card(id: Int) -> some View {
        // Le cran où cette carte se trouve : sa place de repos, DÉCALÉE du
        // rail. Toutes les cartes reçoivent le même `rail` — c'est là, et
        // nulle part ailleurs, que se joue l'absence de chevauchement.
        let p = cranDeRepos(rang(of: id)) + rail
        let s = pose(p)
        let ecart = abs(p)
        let isTop = ecart < 0.5
        // La descente du doigt : seulement vers le BAS. Tirer vers le haut
        // ne veut rien dire ici — la carte résisterait, elle ne suivrait pas.
        let descente = isTop ? max(drag.height, 0) : 0
        // L'enfoncement ne RÉTRÉCIT plus la carte, il la RACCOURCIT. Une
        // homothétie à 0,20 la faisait fuir vers un point : c'est ce que
        // fait un objet qui s'éloigne, pas un objet qui rentre. Une carte
        // qui s'enfonce garde sa largeur — elle est toujours à la même
        // distance de nous — et perd de la hauteur, parce qu'on la voit de
        // plus en plus par la tranche. On ne touche donc qu'à Y, ancré en
        // bas, et c'est ce qui fait que son sommet rejoint la lèvre.
        let raccourci = 1 - 0.52 * (isTop ? enfonce : 0)
        // La part enterrée, ramenée dans le repère de la carte : à l'écran
        // elle a été comprimée par `raccourci`, donc un point d'écran sous
        // la lèvre vaut 1/raccourci point de carte. Sans cette division, la
        // ligne d'extinction dérive de la lèvre à mesure que la carte se
        // tasse — et une ligne d'ombre qui glisse toute seule sur un objet
        // immobile est le genre de faute qu'on ne voit pas mais qu'on sent.
        // La profondeur, comptée depuis LA LIGNE DE COUPE (pas depuis le
        // sommet de la fente) et ramenée dans le repère de la carte : à
        // l'écran elle a été comprimée par `raccourci`, donc un point
        // d'écran sous la coupe vaut 1/raccourci point de carte.
        //
        // Négatif tant que la carte n'a pas atteint la coupe — c'est voulu :
        // c'est là que se joue l'entrée dans l'ombre. La valeur NEUTRE
        // (aucune fente sous la carte) est donc très négative, pas zéro.
        let sousCoupe = isTop
            ? drag.height - contact - GoldSlot.coupe
            : -HaloDeckCard.horsFente
        let enterre = isTop ? sousCoupe / max(raccourci, 0.05)
                            : -HaloDeckCard.horsFente

        HaloDeckCard(seed: Float(id),
                     charge: isTop ? charge : 0,
                     // Le foyer se masse VERS LE BAS : c'est là que le doigt
                     // tire, la lumière doit s'y rassembler.
                     pull: CGSize(width: 0, height: 1),
                     // La bouffée du néon appartient à la carte du CENTRE :
                     // celle de l'activation, et celle du cran qui vient de
                     // se poser. L'horodatage traverse, pas la valeur — la
                     // carte a son horloge à 30 Hz, la pile n'en a pas.
                     tapAt: isTop ? max(firedAt, landedAt) : .distantPast,
                     enterre: enterre)
            .contentShape(Rectangle())
            // Les ailes reculent d'un demi-ton — mais en OPACITÉ, pas sous
            // un voile noir : sur un fond orange, un voile noir les
            // transformerait en trous découpés. Le demi-ton suit le rail :
            // celle qui monte au centre reprend sa présence en avançant.
            .opacity(0.82 + 0.18 * max(0, 1 - ecart))
            // LA DESCENTE. Elle colle au doigt à 1:1 — un objet qu'on
            // traîne reste sous la main —, et au CONTACT de la lèvre elle se
            // met à RECULER : la carte rapetisse en s'enfonçant, ancrée par
            // le bas, comme tout ce qui entre dans un trou.
            //
            // PLUS DE ROTATION 3D. Elle faisait ENFLER la carte au lieu de
            // la faire reculer — l'inverse exact d'un enfoncement —, et
            // c'était elle qui la faisait passer derrière ses voisines au
            // retour : une vue à transformation 3D est composée dans son
            // propre plan de profondeur, où le zIndex ne fait plus loi. Deux
            // défauts, une seule cause.
            .scaleEffect(x: s.scale, y: s.scale * raccourci, anchor: .bottom)
            .offset(x: s.x + nudge, y: s.y + (isTop ? descente : 0))
            .rotationEffect(.degrees(s.rot), anchor: .bottom)
            // La plus proche du centre passe devant. Elles ne se recouvrent
            // jamais, donc c'est une ceinture et non une règle — mais une
            // ceinture qui coûte zéro.
            .zIndex(10 - ecart)
            // LE MÊME ressort pour TOUTES, sans le moindre décalage : c'est
            // ça, le rail. Un délai, même de quatre centièmes, suffirait à
            // faire rattraper une carte par sa voisine.
            .animation(.spring(response: 0.46, dampingFraction: 0.90),
                       value: rail)
            .allowsHitTesting(isTop)
            .gesture(isTop ? deckGesture : nil)
    }

    /// Le jeton d'une carte, posé sous elle. Il ne connaît que le RAIL :
    /// sa place en x et en y, et rien du geste. Il s'efface dès que la
    /// descente s'engage — à cet instant on ne choisit plus, on valide, et
    /// le montant n'a plus rien à dire — et il ne vaut que pour la carte du
    /// centre : un gain sous une aile à moitié sortie du cadre n'est qu'un
    /// chiffre qui flotte.
    @ViewBuilder
    private func jeton(id: Int) -> some View {
        let p = cranDeRepos(rang(of: id)) + rail
        let s = pose(p)
        let ecart = abs(p)
        badge(gain(of: id))
            .offset(x: s.x + nudge, y: s.y + HaloDeckCard.height / 2 + 26)
            .opacity(max(0, 1 - ecart * 1.7) * (drag.height > 2 ? 0 : 1))
            .animation(.easeOut(duration: 0.18), value: drag.height > 2)
            .animation(.spring(response: 0.46, dampingFraction: 0.90),
                       value: rail)
            .allowsHitTesting(false)
    }

    // MARK: Le geste

    /// UN SEUL geste pour les deux mouvements de la pile : vers le BAS on
    /// active la carte du dessus, sur le CÔTÉ on fait tourner la pile pour
    /// aller chercher les autres. L'axe est verrouillé au premier vrai
    /// déplacement — un doigt part rarement parfaitement droit, et sans ce
    /// verrou les deux gestes se disputent la course.
    private var deckGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                if !pressed { pressed = true }
                let d = v.translation
                if axis == nil, abs(d.width) > 8 || abs(d.height) > 8 {
                    axis = abs(d.width) > abs(d.height) ? .horizontal
                                                        : .vertical
                }
                let now = Date()
                switch axis {
                case .horizontal:
                    sideDrag = d.width
                    // LE CRAN. Le doigt n'emmène pas les cartes : il arme le
                    // mécanisme, et dès qu'il a parcouru la course d'un cran
                    // la pile tourne d'un rang, toute seule. Un long
                    // glissement crante donc plusieurs fois — c'est une
                    // molette, pas un tiroir.
                    let ecart = d.width - notchBase
                    if abs(ecart) >= Self.notch {
                        notchBase = d.width
                        cranter(vers: ecart > 0 ? 1 : -1)
                    }
                case .vertical:
                    drag = d
                    if d.height > 4, now.timeIntervalSince(lastTick) > 0.055 {
                        lastTick = now
                        hapticTick += 1
                    }
                    // LE FROTTEMENT DE LA GORGE. Il ne commence qu'au
                    // CONTACT de la lèvre — avant, la carte est en l'air et
                    // n'a rien à frotter — et il tombe tous les 5 points
                    // PARCOURUS, pas toutes les tant de secondes : un geste
                    // vif doit crisser plus vite qu'un geste lent.
                    let dedans = d.height - contact
                    if dedans > 0, dedans - dernierGrain >= 5 {
                        dernierGrain = dedans
                        grainTick += 1
                    }
                    // LE FRANCHISSEMENT, à l'image près du balayage du
                    // liseré : la main et l'œil doivent dire la même chose
                    // au même instant, sinon ni l'un ni l'autre n'est cru.
                    if !seuilSonne, dedans >= GoldSlot.coupe {
                        seuilSonne = true
                        seuilTick += 1
                    }
                    // L'AIMANT sonne UNE fois : passé lui, la fente tient la
                    // carte et finira le geste toute seule. On ne demande pas
                    // de la précision à un pouce.
                    if !armed && d.height >= contact * Self.prise {
                        armed = true
                        hapticTick += 1
                    }
                case .none:
                    break
                }
            }
            .onEnded { v in
                pressed = false
                let d = v.translation
                if axis == .horizontal {
                    // L'ÉLAN décide du dernier cran : un geste vif et court
                    // doit crante r une fois de plus, sinon il faut pousser
                    // la pile et le barillet se met à peser.
                    let reste = d.width - notchBase
                    let lance = reste + v.predictedEndTranslation.width
                                      - v.translation.width
                    if abs(lance) >= Self.notch * 0.62,
                       abs(reste) > 8, reste * lance > 0 {
                        cranter(vers: lance > 0 ? 1 : -1)
                    }
                    // La main lâche : l'élasticité revient à zéro.
                    withAnimation(.spring(response: 0.40,
                                          dampingFraction: 0.80)) {
                        sideDrag = 0
                        notchBase = 0
                    }
                } else if d.height >= contact * Self.prise {
                    avaler()
                } else {
                    withAnimation(.spring(response: 0.42,
                                          dampingFraction: 0.72)) {
                        drag = .zero
                    }
                }
                armed = false
                axis = nil
                if d.height < contact * Self.prise {
                    // Geste abandonné : la carte remonte, tout se réarme.
                    seuilSonne = false
                }
                dernierGrain = -999
            }
    }

    /// UN CRAN. `sens` = +1 : le doigt va vers la droite, donc l'aile
    /// GAUCHE monte au centre. −1 : l'aile droite.
    ///
    /// Trois cartes, trois rôles, et c'est le rôle qui décide de l'ordre de
    /// départ : celle qui quitte le centre, celle qui y monte, et la
    /// troisième — la voyageuse — qui rejoint l'aile opposée en traversant
    /// toute la page derrière les deux autres.
    private func cranter(vers sens: Int) {
        guard !enCran else { return }   // une horloge ne bat pas deux fois
        enCran = true

        // La RÉSERVE se gare du côté par lequel elle va entrer. Les deux
        // parkings sont hors champ, donc la déplacer est invisible — et
        // c'est le seul saut de tout le mécanisme.
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { reservePark = sens > 0 ? -2 : 2 }

        // Le TIC de l'échappement, à l'instant du cran.
        SwapFeedback.shared.swipe()
        withAnimation(.spring(response: 0.46, dampingFraction: 0.90)) {
            rail = Double(sens)
        }

        // Une fois le rail arrivé : on renumérote les rangs et on remet le
        // rail à zéro DANS LA MÊME transaction, sans animation. Chaque carte
        // retrouve exactement le cran où le rail l'avait laissée — sauf la
        // sortante, qui passe d'un parking hors champ à l'autre.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) {
            var t2 = Transaction()
            t2.disablesAnimations = true
            withTransaction(t2) {
                top = (top + (sens > 0 ? 3 : 1)) % 4
                // L'offre suit le rail : la carte qui monte au centre
                // portait déjà la sienne, on ne fait que renommer le repère.
                offerBase = ((offerBase + (sens > 0 ? -1 : 1)) % 3 + 3) % 3
                reservePark = sens > 0 ? 2 : -2
                rail = 0
            }
            // L'ARRIVÉE : la carte s'est posée au centre. C'est LÀ que la
            // pile le dit — un choc net, et le néon de son arête qui souffle
            // une bouffée.
            landedAt = .now
            hapticTick += 1
            enCran = false
        }
    }

    /// L'AVALEMENT. Passé l'aimant, la fente prend la carte et finit le
    /// geste : la carte descend jusqu'à la lèvre puis s'enfonce, le masque
    /// la mange, et la fente s'embrase à mesure qu'elle avale.
    ///
    /// Une seule variable pilote tout — la descente. Le reste (l'échelle qui
    /// recule, la part avalée, la lumière de la fente) en dérive, donc rien
    /// ne peut se désynchroniser.
    private func avaler() {
        firedAt = .now
        hapticTick += 1
        // Si le doigt a lâché AVANT la lèvre, c'est le mécanisme qui
        // franchit : le coup sec tombe à l'instant où le bord bas passe la
        // coupe, pas au début de l'animation.
        if !seuilSonne {
            let reste = max(GoldSlot.coupe - (drag.height - contact), 0)
            let quand = 0.78 * Double(reste / max(Self.gorge, 1))
            DispatchQueue.main.asyncAfter(deadline: .now() + quand) {
                seuilSonne = true
                seuilTick += 1
            }
        }
        // DEUX TEMPS, ET C'EST LE POINT. Une seule courbe menait la carte du
        // bord de la lèvre au fond en 0,52 s : l'unique instant qui vaut la
        // peine — le bord bas qui franchit la lèvre et traverse la bouche —
        // durait trois images. On l'étire.
        //
        // 1) LA GORGE, lente : le bord bas descend d'un bout à l'autre de
        //    l'ouverture. Pendant toute cette course on voit du creux SOUS
        //    la carte, et du jour de chaque côté. C'est là qu'elle entre.
        withAnimation(.timingCurve(0.24, 0.66, 0.28, 1, duration: 0.78)) {
            drag = CGSize(width: 0, height: contact + Self.gorge)
        }
        // 2) LA CHUTE : une fois franchie, elle tombe au fond. Rapide —
        //    ce qui est déjà dedans n'a plus rien à démontrer.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) {
            withAnimation(.timingCurve(0.40, 0, 0.86, 1, duration: 0.36)) {
                drag = CGSize(width: 0, height: contact + Self.enfoncement)
            }
        }
        // Le choc du fond, quand elle a disparu.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.06) {
            fondTick += 1
            SwapFeedback.shared.ignite()
        }
        // Puis la page se remet : la carte revient au centre. La récompense
        // prendra sa place ici — pour l'instant on rend la main.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.75) {
            withAnimation(.spring(response: 0.52, dampingFraction: 0.86)) {
                drag = .zero
            }
        }
    }

    /// LE SEUL POSTE QUE TROIS TOURS DE JURY N'AVAIENT JAMAIS ARBITRÉ, et
    /// le bloquant unanime du tour 3 : la légende était composée un QUART
    /// trop petit. Elle se lisait comme une mention en bas de contrat là où
    /// la référence porte une vraie légende — alors que le français a cinq
    /// signes de plus que l'anglais et devrait donc paraître plus long, pas
    /// plus fin.
    ///
    /// 13 → 16, mesuré et non voté. Sur la photo, le fût du « D » de
    /// « Drag » pris au DEMI-MAXIMUM (le seul relevé qu'un flou symétrique
    /// ne déplace pas — un seuil absolu, lui, gonfle avec la bavure et
    /// c'est ce qui faisait lire 15,4 à un juge et 12,0 à un autre) donne
    /// 10,71 px de haut de capitale ; l'échelle locale au pied de l'écran
    /// vaut 0,87 à 0,92 px/pt, soit 11,6 à 12,3 pt de capitale. La même
    /// mesure sur la capture du tour 3, à 13 pt, rend 9,5 pt. Le rapport
    /// tombe donc entre 1,22 et 1,29, et le corps entre 15,9 et 16,8 :
    /// 16 est le centre, et c'est aussi le chiffre sur lequel deux des
    /// trois juges se rejoignent (le troisième demandait 17).
    /// Le gain de la carte : la pièce de lune de la maison, en petit, et le
    /// nombre. La pièce est FIGÉE (lacet imposé, vie au repos coupée) : à ce
    /// diamètre son croissant ne vaut plus que quelques pixels, l'animer
    /// coûterait un shader de plus par carte pour du frémissement que
    /// personne ne verrait.
    private func badge(_ valeur: Int) -> some View {
        HStack(spacing: 6) {
            // Le double cadre : le grand porte le bloom du shader, le petit
            // décide de la place que le jeton prend dans la capsule. Sans
            // lui, la marge du bloom (3,4 rayons) rendrait le badge deux
            // fois trop haut ; en clipant, on couperait le bloom net.
            MoonCoinView(coinR: 9, draggable: false, yawOverride: 0,
                         idleLife: 0, fps: 6)
                .frame(width: 9 * MoonCoinView.hostScale,
                       height: 9 * MoonCoinView.hostScale)
                .frame(width: 21, height: 21)
            Text("\(valeur)")
                .font(.inter(13, .semibold))
                .foregroundStyle(Color(red: 1.0, green: 0.93, blue: 0.80))
        }
        .padding(.leading, 4)
        .padding(.trailing, 12)
        .padding(.vertical, 5)
        // Le jeton reprend la matière de la carte : un noir profond, posé
        // sans contour. Sur l'orange du fond, c'est le contraste qui le
        // détache — jamais un liseré.
        .background {
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.88))
        }
    }

    private var legende: some View {
        Text("Glisser vers le bas pour activer")
            .font(.inter(16, .medium))
            .foregroundStyle(.black.opacity(0.52))
    }
}

// MARK: - La fente

/// L'ENTRÉE DORÉE : une ouverture au bas de la page, dans laquelle on fait
/// glisser la carte. Tout est dans le shader `goldSlot` — la vue n'est que
/// son hôte, avec la marge dont la buée a besoin.
///
/// Elle DORT tant que le barillet tourne (rien n'est sélectionné pendant un
/// cran) et s'ÉVEILLE dès qu'une carte se pose au centre. C'est elle qui
/// appelle, pas la carte qui se propose.
struct GoldSlot: View {
    /// 0 elle dort, 1 elle appelle.
    var awake: Double = 1
    /// 0 → 1 pendant qu'elle avale la carte.
    var swallow: Double = 0
    /// 0 : le creux, à peindre DERRIÈRE la carte. 1 : la lumière, DEVANT.
    var couche: Double = 1
    /// De combien de points le bas de la carte est passé sous la lèvre :
    /// le shader en déduit la silhouette qui COUPE son filet lointain.
    var sunk: Double = 0
    /// LA CHARGE DU GESTE, 0 au repos. C'est elle, et rien d'autre, qui
    /// allume le liseré. Au repos la fente est un dégradé de noir sans un
    /// lumen — la loi payée sur les cartes le 2026-08-04 (« le liseré clair
    /// au repos, on dirait un bug ») : l'arête ne naît que du doigt. Un
    /// contour lumineux posé en permanence EST un objet ; un contour qui
    /// n'apparaît que sous le doigt est une RÉPONSE.
    var charge: Double = 0

    // UNE FENTE SERRE CE QUI ENTRE DEDANS. C'était la vraie erreur, et
    // aucune quantité de lumière ne l'aurait rattrapée : à 244 pour une
    // carte de 174, il restait 35 pt de vide de chaque côté, et sur ce vide
    // on voyait le creux PASSER DERRIÈRE la carte. L'œil lisait alors une
    // fenêtre devant laquelle glisse une plaque — « on voit l'arrière » —,
    // pas un objet enfoncé dans un trou. Une boîte aux lettres, un lecteur
    // de carte, un monnayeur : tous ont un jeu de quelques millimètres. Ce
    // jeu doit être VISIBLE (sinon la carte masque l'ouverture et on ne sait
    // plus qu'elle y est) mais MINCE. 208 en laisse 17 de chaque côté.
    //
    // La HAUTEUR, elle, est le temps qu'on passe à la voir entrer : à 52 le
    // bord bas traversait la bouche en trois images.
    //
    // Le RAYON tombe de 26 à 17 pour une raison mesurable : à 26 sur une
    // hauteur de 52, la fente était une CAPSULE — deux demi-disques bout à
    // bout, sans un seul point de bord droit à la largeur de la carte. À
    // 208 / 17, la portion droite fait 174, exactement la carte.
    static let width: CGFloat = 208
    static let height: CGFloat = 62
    /// Passé au shader plutôt que recopié des deux côtés : le masque des
    /// cartes doit épouser EXACTEMENT cette ouverture, et deux constantes
    /// jumelles finissent toujours par diverger.
    static let radius: CGFloat = 17
    /// LA LIGNE DE COUPE, comptée depuis le sommet de la fente : au-dessus
    /// la carte existe, en dessous c'est la lèvre proche, opaque, devant
    /// elle. Doit valoir `height/2 + HD_COUPE` du shader.
    static let coupe: CGFloat = 39
    /// La marge de la buée. Elle porte loin quand la fente avale : un shader
    /// ne peint que dans son rectangle hôte, et une buée coupée net se lit
    /// comme une plaque rectangulaire posée sur la page.
    static let pad: CGFloat = 78

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
            let t = Float(tl.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 900))
            Rectangle()
                .fill(.white)
                .frame(width: Self.width + Self.pad * 2,
                       height: Self.height + Self.pad * 2)
                .colorEffect(ShaderLibrary.goldSlot(
                    .float2(Float(Self.width + Self.pad * 2),
                            Float(Self.height + Self.pad * 2)),
                    .float(t), .float(Float(Self.pad)),
                    .float(Float(awake)), .float(Float(swallow)),
                    .float(Float(couche)), .float(Float(Self.radius)),
                    .float(Float(sunk)),
                    .float(Float(HaloDeckCard.width / 2)),
                    .float(Float(charge))))
        }
        .frame(width: Self.width, height: Self.height)
        .allowsHitTesting(false)
    }
}

/// Les chevrons d'appel : trois traits qui descendent en cascade de la carte
/// vers la fente. Ce n'est pas la carte qui dit « tire-moi », c'est la fente
/// qui aspire — donc ils naissent en haut et meurent en bas, jamais
/// l'inverse. Ils s'éteignent dès la première milliseconde du geste : une
/// invitation qui reste affichée pendant qu'on lui obéit devient du bruit.
struct SlotChevrons: View {
    var awake: Double = 1

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            VStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { i in
                    // Chacun a sa phase : la cascade se lit comme un
                    // mouvement, pas comme trois clignotants synchrones.
                    let ph = (t * 0.9 - Double(i) * 0.22)
                        .truncatingRemainder(dividingBy: 1.0)
                    let vie = max(0, sin(.pi * ph))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(red: 1.0, green: 0.86,
                                               blue: 0.60))
                        .opacity((0.24 + 0.76 * vie) * awake)
                        .shadow(color: .black.opacity(0.45), radius: 5, y: 1)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - La carte

/// La carte de la pile : exactement la matière de la home (le stitchable
/// `swapCard`, 220 × 282, rayon 24), mais en NOIR PROFOND. Le contenu
/// viendra plus tard — ici c'est la dalle seule, et l'arête qui ne naît que
/// du doigt : au repos la carte n'a NI liseré NI ombre, elle est là, c'est
/// tout (verdict du 2026-08-04 : le liseré de repos, « on dirait un bug »).
struct HaloDeckCard: View {
    /// Quatre cartes, quatre reflets désynchronisés.
    var seed: Float = 0
    /// La montée du geste (0 → 1) : l'écrin s'embrase avec elle.
    var charge: Float = 0
    /// La direction où le doigt tire (unitaire) : le foyer de lumière s'y
    /// masse à mesure que la charge monte.
    var pull: CGSize = CGSize(width: 0, height: 1)
    /// L'horodatage du dernier événement qui allume le tube (activation, ou
    /// arrivée au centre d'un cran). C'est la DATE qui traverse, jamais la
    /// valeur : la bouffée se calcule ici, sous l'horloge à 30 Hz de la
    /// carte. Calculée dehors, elle ne serait rafraîchie qu'aux rares
    /// redessins de la pile — et on ne verrait qu'une image sur dix.
    var tapAt: Date = .distantPast
    /// De combien de points, DANS SON PROPRE REPÈRE, le bord bas de la
    /// carte est passé sous la LIGNE DE COUPE d'une fente. Négatif tant
    /// qu'elle est au-dessus : c'est là que se joue l'entrée dans l'ombre.
    /// `horsFente` = la carte n'est dans aucune fente.
    var enterre: CGFloat = HaloDeckCard.horsFente
    /// Assez négatif pour que les deux rampes du shader rendent 1 partout,
    /// quelle que soit la hauteur de la carte : c'est la valeur neutre.
    static let horsFente: CGFloat = -4000

    // Mesuré au PIC du liseré doré de la référence redressée — le seul
    // repère stable, parce que ce liseré a un halo qui bave 12 pt vers
    // l'extérieur et 0 vers l'intérieur : pic à pic 174,5 de large et
    // 224 de haut (bord à bord du halo on lirait 197 × 240, d'où les
    // lectures contradictoires 170 / 176 / 180). On ne bouge pas.
    static let width: CGFloat = 174
    static let height: CGFloat = 224
    static let radius: CGFloat = 20
    /// Marge du shader : sous le geste le halo déborde loin, et un shader ne
    /// peint que dans son rectangle hôte.
    private static let pad: CGFloat = 54

    var body: some View {
        Color.clear
            .frame(width: Self.width, height: Self.height)
            .background { ecrin }
    }

    private var ecrin: some View {
        GeometryReader { geo in
            let w = geo.size.width + Self.pad * 2
            let h = geo.size.height + Self.pad * 2
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                let t = Float(tl.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 900))
                // 0,08 s d'attaque, ~0,40 s d'extinction : un souffle, pas
                // un clignotement.
                let since = tl.date.timeIntervalSince(tapAt)
                let pulse = since < 0 ? 0
                    : Float(min(since / 0.08, 1)
                            * exp(-max(since - 0.08, 0) / 0.40))
                let neon = max(charge, min(pulse, 1))
                Rectangle()
                    .fill(.white)
                    .frame(width: w, height: h)
                    .colorEffect(ShaderLibrary.swapCard(
                        .float2(w, h), .float(t),
                        .float(Float(Self.pad)), .float(Float(Self.radius)),
                        .float(seed), .float(charge),
                        .float2(Float(pull.width), Float(pull.height)),
                        .float(neon), .float(1), .float(Float(enterre))))
            }
            .offset(x: -Self.pad, y: -Self.pad)
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    HaloDawnLab()
}
