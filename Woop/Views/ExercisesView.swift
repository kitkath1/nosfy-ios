import SwiftUI
import SwiftData
import AVFoundation

// MARK: - La bibliothèque d'exercices — LA GRANDE CARD (22-08)
//
// La page reprend la grammaire de la home v2 : **toute la page est UNE card**
// posée sur une page NOIRE, qui suit le doigt et qui se RACCOURCIT par le bas
// pour découvrir la bande — le secret de la lune hors séance, le player
// pendant. Le halo braise est mort avec le fond nuit : le fond est une vidéo
// cuite (`exos-fond-loop` — le verre rouge couché qui entre par la droite, la
// flamme en nappe basse, cf. tools/exos-v2/recuit_fond_exos.sh).
//
// Les cartes : petites, rectangulaires, décalées en deux colonnes façon
// Pinterest, SANS bordure. Les DEUX bords fondent : le haut sous le bandeau du
// titre, le bas dans le lit de la molette — et taper une carte prise dans le
// voile du bas la fait remonter au lieu de l'ouvrir.
//
// Le titre « Exercice » vit À CÔTÉ DU CHEVRON, à la taille de la phrase de la
// home (30 semibold), sans sous-titre. La molette (le filtre) est COUCHÉE AU
// BAS DE LA CARD, ses noms de section à l'HORIZONTALE, tournée à la glisse
// horizontale.
//
// ⚠️ LA FLUIDITÉ EST UNE ARCHITECTURE, PAS UN RÉGLAGE (verdict 22-08 : « la
// molette pas très fluide », « le scroll ne fonctionne pas bien »). Tout était
// bâti EN LIGNE dans le corps de la page, et ce corps se ré-évaluait à chaque
// image de scroll comme de rotation. Les cinq lois qui en sortent :
//   1. ce qui se calcule par image se CACHE (le catalogue) ;
//   2. l'état vivant vit dans un `@Observable` — seule la vue qui LIT une
//      propriété s'invalide, et le corps de la page n'en lit AUCUNE ;
//   3. les enfants lourds sont des `struct View` aux entrées STABLES (une
//      closure en propriété suffit à les faire re-jouer à chaque passage du
//      parent : SwiftUI ne peut plus prouver l'égalité) ;
//   4. ce qui se redessine par image passe en `Canvas` — un dessin, pas 72
//      calques ;
//   5. **ce qui BOUGE par image passe par un `ViewModifier`** : son
//      `body(content:)` reçoit l'arbre DÉJÀ construit — le relire ne
//      reconstruit rien. C'est ainsi que la card entière peut suivre le doigt
//      sans que la grille, le bandeau ou la molette ne soient re-jouées.

// MARK: - Les bancs (le simulateur ne pose pas de doigt)

/// `-exosSeance` : la séance tourne (la card levée, le player dans la bande).
/// `-exosTirage <pt>` : la card tenue là — POSITIF elle descend, NÉGATIF elle
/// se lève et découvre la lune.
/// `-exosDial <n>` : la molette engagée sur le cran `n` (éventail + fumée).
/// `-exosVoile <p>` : la densité du bandeau de nuit figée.
/// `-exosScroll <pt>` : la grille défilée d'autant.
enum ExosBanc {
    static let seance = CommandLine.arguments.contains("-exosSeance")

    static let tirage: CGFloat? = valeur("-exosTirage").map { CGFloat($0) }
    static let voile: Double? = valeur("-exosVoile")
    static let dial: Int? = valeur("-exosDial").map { Int($0) }
    static let scroll: CGFloat? = valeur("-exosScroll").map { CGFloat($0) }
    /// `-exosSection <n>` : la section posée SANS engager la molette — le seul
    /// moyen de juger le titre qui prend le nom de la section (avec
    /// `-exosDial`, la scène est éteinte et floutée par le théâtre).
    static let section: Int? = valeur("-exosSection").map { Int($0) }
    /// `-exosCherche <mot>` : la recherche OUVERTE sur ce mot, et la lumière de
    /// la frappe rejouée en boucle. Une braise s'éteint en moins d'une seconde
    /// et le simulateur ne tape sur aucune touche : sans relance, toute capture
    /// arriverait sur une lumière déjà morte (l'école de la fumée de la
    /// molette, `-exosDial`).
    static let cherche: String? = mot("-exosCherche")
    /// `-exosFrappe <âge>` : la braise FIGÉE à cet âge en secondes (0 = l'éclat
    /// de la touche, 1 = presque éteinte). Une lumière qui vit une seconde ne
    /// se juge pas autrement : filmée elle ne se clôt pas toujours, et une
    /// capture prise au hasard tombe où elle veut.
    static let frappe: Double? = valeur("-exosFrappe")
    /// `-exosClavier <0|1>` : le clavier rangé ou sorti. Avec `-exosCherche` il
    /// sort tout seul — c'est pour juger la GRILLE filtrée qu'on le range.
    static let clavier: Double? = valeur("-exosClavier")
    /// `-exosTouche <n>` : la touche `n` du clavier tenue ALLUMÉE (avec
    /// `-exosFrappe` pour choisir l'âge de sa braise). Le simulateur ne se
    /// pilote pas au doigt : sans ce banc, la lumière des touches ne peut être
    /// jugée par personne.
    static let touche: Int? = valeur("-exosTouche").map { Int($0) }

    private static func valeur(_ cle: String) -> Double? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: cle), i + 1 < args.count,
              let v = Double(args[i + 1]) else { return nil }
        return v
    }

    private static func mot(_ cle: String) -> String? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: cle), i + 1 < args.count,
              !args[i + 1].hasPrefix("-") else { return nil }
        return args[i + 1]
    }
}

// MARK: - L'état vivant

/// CE QUI CHANGE PAR IMAGE, et rien d'autre. `@Observable` et pas des `@State`
/// sur la page : l'Observation ne réveille que les vues qui LISENT vraiment la
/// propriété touchée.
@Observable
final class EtatExos {
    /// L'offset du scroll (positif = on descend). Lu par le seul voile du
    /// bandeau.
    var scroll: CGFloat = 0
    /// La hauteur du viewport et la fin de course — lues UNIQUEMENT dans des
    /// closures de geste ou de tap, jamais dans un corps de vue.
    var viewportH: CGFloat = 700
    var finCourse: CGFloat = 0

    /// LE TIRAGE, SIGNÉ, comme la home : positif la card descend (elle se
    /// translate), négatif elle se lève (elle se RACCOURCIT par le bas, son
    /// bord haut ne bouge pas d'un pixel — et la molette remonte avec le bord
    /// bas, puisque le contenu est cadré dedans).
    ///
    /// ⚠️ IL N'EST LU QUE PAR DEUX `ViewModifier` ET LA BANDE. Le corps de la
    /// page ne le lit pas : sinon la grille entière serait reconstruite à
    /// chaque image de tirage.
    var tirage: CGFloat = 0
    /// La poignée du bandeau tient le doigt : le débord du scroll ne doit plus
    /// écrire le tirage (il le remettrait à zéro sous la main).
    var mainTient = false
    /// Le départ du geste de la poignée, et la course morte consommée par son
    /// seuil. ⚠️ Le départ sert de FILET : un geste annulé (l'app passe en
    /// arrière-plan, une transition démarre) ne reçoit jamais son `onEnded`, et
    /// `mainTient` resterait collé — la card figée hors position, que le rebond
    /// du scroll ne pourrait plus récupérer.
    var debutPoignee: CGPoint?
    var mortePoignee: CGFloat = 0
    /// Le verrou de l'haptique du secret : la braise ne se sent qu'UNE fois par
    /// découverte, pas à chaque image passée au-dessus du seuil.
    var luneSentie = false
    /// La séance tourne — recopiée ici pour que les gestes (qui vivent dans des
    /// closures) puissent freiner sans lire le `@Query`.
    var enSeance = false

    // Le tambour de la molette.
    var pos: Double = 0
    var engaged = false
    var detent = 0
    /// Les horodatages du toucher : la fumée et l'onde en sont des fonctions
    /// pures recalculées par image — aucune mutation par frame.
    var touchStart: Date?
    var touchEnd: Date?

    /// LE CLAVIER EST OUVERT. Il vit ICI et pas en `@State` sur la page parce
    /// que c'est le SCROLL qui le referme (« je regarde les résultats, je ne
    /// tape plus ») : la grille l'éteint depuis sa closure de sonde, sans que
    /// personne n'ait à lire l'offset dans un corps de vue.
    var clavier = false

    /// La pulsation tactile d'une carte rejointe — dans l'état et pas en
    /// `@Binding` : la grille la déclenche et l'écoute, la page n'a pas à
    /// s'en mêler.
    var pulse = 0
    /// LE FILTRE DEMANDÉ PAR L'ACCESSIBILITÉ (l'index du cran). VoiceOver ne
    /// sait pas glisser sur un tambour : c'est par là qu'il change de section.
    var filtreDemande: Int?

    // Le geste de la molette en cours.
    var prise: Prise = .aucune
    var base: Double = 0
    /// La course morte du seuil, retranchée à l'accrochage : sans elle,
    /// l'objet SAUTE d'un dixième de cran (ou la card de 8 pt) à la première
    /// image du geste.
    var morte: CGFloat = 0
    /// Le point de départ du geste : la seule marque qui distingue un NOUVEAU
    /// geste d'une suite du précédent. Un geste ANNULÉ (le scroll qui prend la
    /// main) ne reçoit jamais son `onEnded`.
    var debut: CGPoint?

    enum Prise { case aucune, molette, tirage, refus }

    /// LA LEVÉE, EN DEUX MORCEAUX — et la distinction est une affaire de
    /// FLUIDITÉ, pas de comptabilité.
    ///
    /// ⚠️ `leveeFixe` ne bouge qu'au début et à la fin d'une séance : elle peut
    /// donc se payer en TAILLE (un `frame`), et le voile des cartes la suit.
    /// `leveeDrag`, elle, change à chaque image du doigt : elle ne doit JAMAIS
    /// toucher à une taille. Un `padding`/`frame` animé par image redimensionne
    /// l'`AVPlayerLayer` de la vidéo ET re-layoute le ScrollView — donc
    /// re-calcule le flou de chaque carte visible — soixante fois par seconde.
    /// C'est ça qui « laggue quand on drag la card ». Elle passe donc par un
    /// MASQUE (`FormeCardExos`) et des `offset` : aucune de ces deux choses ne
    /// re-layoute quoi que ce soit.
    var leveeDrag: CGFloat { max(0, -tirage) }
    var leveeFixe: CGFloat { enSeance ? ExercisesView.leveeSeance : 0 }
    var levee: CGFloat { leveeDrag + leveeFixe }

    /// LA DÉCOUVERTE DU SECRET : la lune ne commence qu'à 62 pt de levée (elle
    /// est encore derrière la card avant : son sommet vit à 80 pt du bord bas)
    /// et culmine à 118. Un secret se mérite, mais il doit rester ATTEIGNABLE —
    /// c'est la loi de la home, calée sur la vraie place du croissant.
    var luneP: Double {
        guard !enSeance else { return 0 }
        return min(max((-Double(tirage) - 62) / 56, 0), 1)
    }

    /// …ET LA MÊME LUNE DANS LA NUIT DU HAUT. Quand on POUSSE la card vers le
    /// bas — le geste le plus naturel sur une page qui défile, et le seul qui
    /// soit à portée partout — c'est la nuit du HAUT qui s'ouvre. Le secret vit
    /// dans la nuit que la card découvre, quel que soit le côté : sinon il
    /// n'existe que pour qui a deviné le bon sens.
    /// Le croissant se pose à 74 pt du bord haut (sous la barre de statut) et
    /// fait 34 de haut : il n'est franchement dégagé qu'à 108 pt de course.
    var luneHautP: Double {
        guard !enSeance else { return 0 }
        return min(max((Double(tirage) - 74) / 50, 0), 1)
    }
}

/// L'ORDRE DE SCROLL que la page envoie à la grille. Un jeton, pas un
/// `Binding` : `scrollPosition(_:)` est un binding à DOUBLE SENS — SwiftUI y
/// écrit au poser et au lâcher du doigt (`isPositionedByUser`), donc un
/// `ScrollPosition` tenu par la PAGE invalidait tout son corps à l'instant
/// exact où le scroll démarre : le pire moment. La page n'a besoin que
/// d'ÉMETTRE ; la position, elle, reste chez la grille.
struct OrdreScroll: Equatable {
    var y: CGFloat = 0
    var jeton: Int = 0
}

/// La sonde du scroll, en UN seul relevé. ⚠️ Une seule sonde par ScrollView :
/// deux se volent les rappels, et celle qui renvoie une constante ne rappelle
/// plus jamais. Le champ vivant emporte les stables.
private struct SondeScroll: Equatable {
    var offset: CGFloat
    var viewport: CGFloat
    var fin: CGFloat
}

// MARK: - Les deux modificateurs qui font bouger la card

/// LA FORME DE LA CARD À UNE LEVÉE DONNÉE — un MASQUE, jamais une taille.
/// `haut` : la bande de nuit du dessus, que la card garde toujours.
///
/// ⚠️ `Animatable` sur la levée : sans ça le masque saute au lieu de suivre le
/// ressort du lâcher (la loi des rampes sous `withAnimation`).
struct FormeCardExos: Shape {
    var levee: CGFloat
    var haut: CGFloat = 0

    var animatableData: CGFloat {
        get { levee }
        set { levee = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let r = CGRect(x: rect.minX, y: rect.minY + haut,
                       width: rect.width,
                       height: max(0, rect.height - haut - levee))
        return UnevenRoundedRectangle(
            topLeadingRadius: GrandeCardExos.rayon,
            bottomLeadingRadius: GrandeCardExos.rayon,
            bottomTrailingRadius: GrandeCardExos.rayon,
            topTrailingRadius: GrandeCardExos.rayon,
            style: .continuous
        ).path(in: r)
    }
}

/// LE FOND DE LA CARD SUIT LE DOIGT. Un `ViewModifier` et pas un `.offset`
/// posé dans le corps de la page : `body(content:)` reçoit l'arbre DÉJÀ
/// construit, donc le relire soixante fois par seconde ne reconstruit rien.
///
/// ⚠️ ET IL DÉCOUPE, IL NE RÉDUIT PAS. Un `.padding(.bottom, levee)` animé par
/// image redimensionnait l'`AVPlayerLayer` à chaque frame — une couche vidéo
/// qu'on redimensionne soixante fois par seconde est le lag lui-même. Le
/// masque, lui, ne coûte qu'une passe de composition.
private struct CarteLevee: ViewModifier {
    let etat: EtatExos
    func body(content: Content) -> some View {
        content
            .clipShape(FormeCardExos(levee: etat.levee,
                                     haut: GrandeCardExos.margeHaut))
            .offset(y: max(etat.tirage, 0))
    }
}

/// CE QUI REMONTE AVEC LE BORD BAS DE LA CARD — la molette et sa prise. Un
/// simple `offset`, donc aucune taille ne change : c'est le pendant du masque
/// ci-dessus.
private struct MonteAvecLaCard: ViewModifier {
    let etat: EtatExos
    func body(content: Content) -> some View {
        content.offset(y: -etat.leveeDrag)
    }
}

/// LE THÉÂTRE DU TOUCHER : sous la molette, toute la scène s'éteint, se floute
/// et RECULE — c'est le recul qui fait le théâtre, pas le flou tout seul. En
/// `ViewModifier` pour la même raison que les deux ci-dessus : lu par la page,
/// `etat.engaged` faisait reconstruire la grille entière à chaque engagement.
private struct TheatreToucher: ViewModifier {
    let etat: EtatExos
    func body(content: Content) -> some View {
        content
            .blur(radius: etat.engaged ? 10 : 0)
            .scaleEffect(etat.engaged ? 0.975 : 1.0)
            .overlay {
                Color.black.opacity(etat.engaged ? 0.30 : 0)
                    .allowsHitTesting(false)
            }
            .animation(.spring(response: 0.42, dampingFraction: 0.85),
                       value: etat.engaged)
    }
}

/// LE CONTENU DE LA CARD : cadré à la card, découpé dans SA forme, et déplacé
/// avec elle. Même raison d'être un `ViewModifier` que ci-dessus — c'est LUI
/// qui permet à la grille, au bandeau et à la molette de ne pas être re-jouées
/// pendant que la page suit le doigt.
private struct CadreCarte: ViewModifier {
    let etat: EtatExos
    let hEcran: CGFloat
    let w: CGFloat

    func body(content: Content) -> some View {
        let c = GrandeCardExos.margeCote
        let h = GrandeCardExos.margeHaut
        return content
            // ⚠️ LA TAILLE NE SUIT QUE LA SÉANCE. Elle change deux fois dans
            // une vie de page — le voile des cartes peut donc la suivre. La
            // levée du DOIGT, elle, passe par le masque ci-dessous : sinon
            // chaque image du tirage re-layoute le ScrollView et recalcule le
            // flou de toutes les cartes visibles.
            .frame(width: w - 2 * c,
                   height: hEcran - etat.leveeFixe - h,
                   alignment: .top)
            .clipShape(FormeCardExos(levee: etat.leveeDrag))
            .padding(.top, h)
            .padding(.leading, c)
            .offset(y: max(etat.tirage, 0))
    }
}

// MARK: - La page

struct ExercisesView: View {
    /// Le chevron du header ramène à la home : la page connaît l'onglet.
    @Binding var selection: WoopTab

    @State private var etat = EtatExos()
    @State private var filter: ExerciseCategory?

    /// LA RECHERCHE — le mot tapé, et si le champ a pris la place du titre.
    /// Ils vivent ici (et pas dans l'`@Observable`) parce qu'ils ne changent
    /// qu'à la TOUCHE : la page a le droit de se ré-évaluer dix fois pour un
    /// mot, comme elle le fait déjà au changement de section. Ce qui bouge par
    /// IMAGE — la lumière — ne passe jamais par là.
    @State private var q = ""
    @State private var cherche = false

    /// LE CATALOGUE CACHÉ. Il était recalculé — `flatMap` sur les catégories —
    /// TROIS fois par évaluation de corps, donc trois fois par image de
    /// scroll. Il ne change qu'au filtre. Rempli DÈS L'INIT : le remplir à
    /// l'apparition ferait naître la page sur une grille vide.
    @State private var items: [Exercise] = ExosCatalogue.tout

    /// La séance en cours, s'il y en a une : c'est elle qui LÈVE la card et
    /// fait paraître le player dans la bande découverte.
    @Query(filter: #Predicate<Workout> { $0.endedAt == nil })
    private var seancesOuvertes: [Workout]

    /// Ouvre une fiche dès le lancement : `-openExercise woop-haute`. Même
    /// usage que `-openTab` et `-openActiveSheet` (captures d'écran
    /// automatisées uniquement) — sans ça, la fiche n'est atteignable qu'au
    /// doigt, et le simulateur ne se pilote pas en ligne de commande.
    @State private var deepLinked: Exercise?

    /// L'ORDRE DE SCROLL, en POINTS et jamais par identifiant.
    ///
    /// ⚠️ `scrollPosition(id:)` visait la CARTE : elle venait se coller au bord
    /// haut du viewport, c'est-à-dire SOUS le bandeau du titre — la page
    /// naissait déjà défilée, les deux premiers exercices hors champ (vu en
    /// capture). Depuis que la réserve du bandeau vit DANS le scroll, la seule
    /// cible juste est une ordonnée.
    @State private var ordre = OrdreScroll()

    /// La naissance de la page, 0 → 1 : la card s'allume en fondu. Jouée une
    /// seule fois — un retour d'onglet ne rejoue pas une arrivée.
    @State private var naissance: Double = 0
    @State private var deja = false

    /// LE TUTO À PROJECTEURS (armé par « Commencer » du panneau de départ, la
    /// première fois seulement) : la nuit tombe sur toute la page SAUF deux
    /// fenêtres — la première card et la molette.
    @State private var tutoActif = false
    /// La naissance du tuto — LA CASCADE s'écrit dessus : le voile tombe, PUIS
    /// la fenêtre de la card s'ouvre, PUIS la molette.
    @State private var tutoNe = Date()

    /// LE BANDEAU DU TITRE : sa hauteur est la réserve en tête de scroll.
    /// La rangée fait 56 (4 + chip 44 + 8) — les cotes de la maison, le
    /// chevron ne bouge JAMAIS d'une page à l'autre — plus 18 d'air avant les
    /// cartes.
    static let hBandeau: CGFloat = 74
    /// L'encart du contenu DANS la card — il porte à lui seul les 20 pt du
    /// bord physique depuis que la card touche les flancs. ⚠️ C'est LUI qui
    /// tient la place du chevron : elle ne bouge JAMAIS d'une page à l'autre,
    /// donc quand la marge de la card change, l'encart change de l'inverse.
    static let encart: CGFloat = 20
    /// LA PRISE DE LA MOLETTE : la bande basse où un geste horizontal tourne
    /// le tambour. Elle ne DESSINE rien — la molette a son propre cadre, plus
    /// haut, pour que la fumée ait de l'air.
    private static let prise: CGFloat = 156
    /// La hauteur à laquelle la card se tient pendant la séance — assez pour
    /// découvrir le player en entier, jamais plus (la cote de la home).
    static let leveeSeance: CGFloat = 106

    /// LA SÉANCE TOURNE. Tant qu'elle tourne, la card reste SOULEVÉE : le
    /// player n'est pas un tiroir qu'on range, c'est l'état de la page.
    private var enSeance: Bool { ExosBanc.seance || !seancesOuvertes.isEmpty }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                // ⚠️ LE `GeometryReader` RESPECTE LA SAFE AREA, c'est SON
                // CONTENU qui l'ignore (l'école du calendrier). Posé
                // l'inverse — `ignoresSafeArea` sur le GeometryReader
                // lui-même — il rend des insets NULS : le chevron remontait
                // se coller à l'heure, mesuré à 36 pt au lieu de 88.
                let safeT = geo.safeAreaInsets.top
                let hEcran = geo.size.height + safeT + geo.safeAreaInsets.bottom
                // LA RÉSERVE DU BANDEAU : la zone sûre (moins la marge que la
                // card a déjà prise en tête) plus la hauteur du bandeau. La
                // grille commence là, et les deux voiles se mesurent dessus.
                let reserve = max(safeT - GrandeCardExos.margeHaut, 0) + Self.hBandeau
                ZStack(alignment: .topLeading) {
                    // LA PAGE EST NOIRE (le halo braise est mort avec la page
                    // nuit : la lumière vient de la vidéo, maintenant).
                    Color.black

                    // LA BANDE DÉCOUVERTE, tout au fond : en séance le player,
                    // hors séance le secret de la lune.
                    BandeExos(etat: etat, seance: seancesOuvertes.first)

                    GrandeCardExos(naissance: naissance)
                        .modifier(CarteLevee(etat: etat))

                    contenuCard(safeT: safeT, w: geo.size.width,
                                safeB: geo.safeAreaInsets.bottom,
                                reserve: reserve)
                        .modifier(CadreCarte(etat: etat, hEcran: hEcran,
                                             w: geo.size.width))
                }
                // ⚠️ AUCUN `frame` EXPLICITE ICI : c'est `ignoresSafeArea` qui
                // propose l'écran entier au ZStack. Un cadre fixé à la hauteur
                // physique serait POSÉ à l'origine sûre et déborderait par le
                // bas — la card commencerait sous l'encoche.
                .ignoresSafeArea()
                // LE TUTO À PROJECTEURS — au-dessus de tout.
                .overlayPreferenceValue(SlotAnchorKey.self) { anchors in
                    tutoCouche(anchors)
                }
                // N'importe quel tap éteint le tuto — dans une fenêtre il fait
                // AUSSI l'action réelle : le geste appris est le geste fait.
                .simultaneousGesture(TapGesture().onEnded {
                    if tutoActif { eteindreTuto() }
                    // LE FILET DES GESTES ANNULÉS. Un geste qui meurt sans
                    // `onEnded` (l'app passe en arrière-plan, une transition
                    // démarre) laisse la molette engagée — la scène éteinte
                    // sous un tambour que plus personne ne tient — ou la
                    // poignée « en main », et alors le rebond du scroll ne
                    // récupère plus jamais la card.
                    if etat.engaged, etat.prise != .molette { relacher() }
                    if etat.mainTient { poigneeFin() }
                })
            }
            .onAppear { arrivee() }
            // ⚠️ DANS UN `withAnimation` : l'état de séance est renseigné APRÈS
            // la première image (le `@Query` n'existe pas avant), donc la card
            // naît pleine hauteur et se raccourcit d'un coup. Portée par la
            // transaction, la levée se joue au lieu de sauter.
            .onChange(of: enSeance, initial: true) { _, v in
                withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.62)) {
                    etat.enSeance = v
                }
            }
            // L'ACCESSIBILITÉ CHANGE DE SECTION : la molette est sourde au
            // doigt (son geste appartient à la page), VoiceOver passe donc par
            // l'état.
            .onChange(of: etat.filtreDemande) { _, d in
                guard let d, d >= 0, d < ArcDial.items.count else { return }
                etat.filtreDemande = nil
                withAnimation(.easeOut(duration: 0.28)) {
                    filter = ArcDial.items[d].1
                }
            }
            .onChange(of: DepartEtat.shared.tutoDemande) { _, d in
                if d { armerTutoSiDemande() }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $deepLinked) { ExerciseDetailView(exercise: $0) }
            // ⚠️ SANS `initial: true` : au lancement il n'y a rien à rejoindre,
            // et l'animation de retour en tête faisait naître la page déjà
            // défilée.
            .onChange(of: filter) { _, _ in
                // ⚠️ LE `withAnimation` EST LE PILOTE DE LA CASCADE. Une
                // `AnyTransition.animation(...)` choisit LAQUELLE jouer, elle
                // ne l'allume pas : sans transaction animée sur la mutation
                // des données, les cartes se TÉLÉPORTENT au changement de
                // section.
                withAnimation(.easeOut(duration: 0.28)) {
                    items = ExosCatalogue.liste(filter, q: q)
                }
                ordre = OrdreScroll(y: 0, jeton: ordre.jeton + 1)
            }
            // LE MOT CHANGE LA GRILLE — même cascade qu'un changement de
            // section : la transaction animée est ce qui redistribue les cartes
            // au lieu de les téléporter.
            .onChange(of: q) { _, v in
                withAnimation(.easeOut(duration: 0.28)) {
                    items = ExosCatalogue.liste(filter, q: v)
                }
                ordre = OrdreScroll(y: 0, jeton: ordre.jeton + 1)
            }
            .task {
                if let id = UserDefaults.standard.string(forKey: "openExercise") {
                    deepLinked = ExerciseCatalog.exercise(id: id)
                }
            }
        }
    }

    /// L'arrivée de la page, jouée UNE fois : la card s'allume en fondu, le
    /// tuto s'arme s'il a été demandé, et les bancs se servent.
    private func arrivee() {
        armerTutoSiDemande()
        guard !deja else { return }
        deja = true
        withAnimation(.easeOut(duration: 0.45)) { naissance = 1 }
        if let t = ExosBanc.tirage { etat.tirage = t }
        if let y = ExosBanc.scroll {
            // Le scroll n'existe pas encore à la première image : on le laisse
            // se poser avant de lui donner sa cible.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                ordre = OrdreScroll(y: y, jeton: ordre.jeton + 1)
            }
        }
        if let n = ExosBanc.section {
            let idx = min(max(n, 0), ArcDial.items.count - 1)
            etat.pos = Double(idx)
            etat.detent = idx
            filter = ArcDial.items[idx].1
        }
        if let m = ExosBanc.cherche {
            cherche = true
            q = m
            etat.clavier = (ExosBanc.clavier ?? 1) > 0.5
        }
        if let n = ExosBanc.dial {
            let idx = min(max(n, 0), ArcDial.items.count - 1)
            etat.pos = Double(idx)
            etat.detent = idx
            etat.touchStart = .now
            etat.engaged = true
            filter = ArcDial.items[idx].1
            // ⚠️ LA FUMÉE SE REJOUE EN BOUCLE. Elle est fonction de l'ÂGE du
            // toucher : figée à l'apparition, une capture prise vingt secondes
            // plus tard montre des volutes parties à l'infini — une fleur
            // d'artifice qu'aucun doigt ne verra jamais.
            Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
                etat.touchStart = .now
            }
        }
    }

    // MARK: - Le contenu de la card

    @ViewBuilder
    private func contenuCard(safeT: CGFloat, w: CGFloat, safeB: CGFloat,
                             reserve: CGFloat) -> some View {
        let cardW = w - 2 * GrandeCardExos.margeCote
        ZStack(alignment: .top) {
            GrilleExos(items: items, reserve: reserve, etat: etat,
                       ordre: ordre, tuto: tutoActif,
                       deepLinked: $deepLinked)
            // LE BANDEAU DE NUIT, par-dessus la grille : les cartes passent
            // DESSOUS, elles ne s'arrêtent pas à son bord. Et c'est LA POIGNÉE
            // de la card.
            BandeauExos(safeT: safeT, etat: etat,
                        // LE TITRE EST LE NOM DE CE QU'ON REGARDE : la page
                        // s'appelle « Exercices », mais dès qu'une section est
                        // choisie au tambour c'est ELLE qu'on lit. Le titre
                        // n'annonce pas l'écran, il annonce le contenu.
                        titre: filter?.rawValue ?? "Exercices",
                        q: $q, cherche: $cherche,
                        retour: {
                            withAnimation(.easeOut(duration: 0.3)) {
                                selection = .home
                            }
                        },
                        tirer: { poignee($0) },
                        reposer: { poigneeFin() })
            // RIEN TROUVÉ — une grille vide se lit comme une page cassée. La
            // ligne se pose sous le bandeau, jamais au centre de l'écran : le
            // bas appartient au lit de la molette.
            if items.isEmpty, !q.isEmpty {
                VideRecherche(q: q, reserve: reserve)
            }
        }
        // LE THÉÂTRE DU TOUCHER. ⚠️ Le noir est descendu de 0,55 à 0,30 et le
        // flou de 13 à 10 (verdict 22-08 : « trop sombre ») : les cartes
        // doivent continuer de VIVRE derrière l'éventail.
        .modifier(TheatreToucher(etat: etat))
        // ⚠️ LA PRISE DU BAS — LA ZONE DU POUCE, et c'est ELLE qui répond enfin
        // à « je veux drag toute la page ». La levée n'existait qu'au bandeau
        // du titre (74 pt tout en haut de l'écran) ou après 4 800 pt de scroll,
        // en fin de liste : autant dire nulle part où le doigt se pose.
        //
        // Ici, une vraie forme tactile, au bas de la card, là où le pouce vit.
        // Le doigt s'y arrête (le scroll ne le voit plus) et le geste
        // s'aiguille : horizontale → le tambour, verticale → la card. On y perd
        // le droit de LANCER un scroll depuis les 156 derniers points — c'est le
        // lit de la molette, les cartes y sont déjà éteintes.
        .overlay(alignment: .bottom) {
            Color.clear
                .frame(height: Self.prise)
                .contentShape(Rectangle())
                .gesture(priseBasse)
                .modifier(MonteAvecLaCard(etat: etat))
        }
        // LA MOLETTE, couchée au bas de la card. Son cadre est GÉNÉREUX
        // (300 pt) pour que la fumée ait de l'air au-dessus du disque : le
        // shader éteint tout à 16 pt du bord de son hôte.
        .overlay(alignment: .bottom) {
            ArcDial(etat: etat)
                .frame(width: cardW, height: 300)
                .modifier(MonteAvecLaCard(etat: etat))
                .anchorPreference(key: SlotAnchorKey.self, value: .bounds) {
                    ["tuto-dial": $0]
                }
        }
        // LE CLAVIER DE BRAISE — DERNIER, donc au-dessus de la molette et de la
        // prise du bouton : quand il est là, c'est lui qui prend le pouce. Il
        // ne MONTE PAS avec la card (pas de `MonteAvecLaCard`) : un clavier
        // n'est pas dans la page, il est posé sur l'écran, comme celui du
        // système.
        .overlay(alignment: .bottom) {
            if etat.clavier {
                ClavierBraise(q: $q, safeB: safeB, valider: {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.9)) {
                        etat.clavier = false
                    }
                })
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Les gestes

    /// LE TIRAGE AU DOIGT — l'élastique de la card, dans les DEUX sens : vers
    /// le haut elle se raccourcit et la lune se lève, vers le bas elle descend.
    /// Servi par les DEUX poignées, celle du bandeau et celle du bas.
    ///
    /// ⚠️ TROIS TENTATIVES POUR TROUVER OÙ LE METTRE, et les deux premières ont
    /// échoué pour la même raison : **on ne partage pas un doigt avec un
    /// ScrollView**. Posé sur le ZStack de la page en `simultaneousGesture`, le
    /// scroll gardait le geste ; le lui retirer en plein vol (`scrollDisabled`)
    /// annulait la séquence de touches. Posé sur le seul bandeau du titre, il
    /// marchait — mais 74 pt tout en haut de l'écran, ce n'est pas « toute la
    /// page » : le doigt ne s'y pose jamais. Il faut une vraie forme tactile,
    /// et elle doit être SOUS LE POUCE.
    ///
    /// La course : 160 pt max en `tanh`, la card suit presque le doigt au
    /// départ puis se retient. Assez pour que la lune (62 → 118) soit
    /// atteignable d'un seul geste.
    private func poignee(_ v: DragGesture.Value) {
        // NOUVEAU GESTE : on repart de zéro, et on note la course morte que le
        // seuil vient de manger — sans ça la card SAUTE à la première image.
        if etat.debutPoignee != v.startLocation {
            etat.debutPoignee = v.startLocation
            etat.mortePoignee = v.translation.height
            etat.mainTient = true
        }
        var t = v.translation.height - etat.mortePoignee
        // EN SÉANCE, LA CARD NE SE REFERME PAS : elle résiste au doigt qui la
        // pousse vers le bas (course divisée par 4), jamais bloquée net — un
        // objet qui ne bouge PAS DU TOUT se lit comme une panne, pas un refus.
        if etat.enSeance, t > 0 { t *= 0.25 }
        etat.tirage = 160 * CGFloat(tanh(Double(t) / 150))
        souffleDeLaLune()
    }

    private func poigneeFin() {
        etat.mainTient = false
        etat.debutPoignee = nil
        etat.luneSentie = false
        withAnimation(.spring(response: 0.50, dampingFraction: 0.86)) {
            etat.tirage = 0
        }
    }

    /// La braise du secret : une seule fois par découverte, dans les deux sens.
    private func souffleDeLaLune() {
        let p = max(etat.luneP, etat.luneHautP)
        if p >= 1, !etat.luneSentie {
            etat.luneSentie = true
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        } else if p < 0.15 {
            etat.luneSentie = false
        }
    }

    /// LA PRISE DU BAS — un seul geste, deux destinations, décidées au premier
    /// mouvement franc : **horizontale → le tambour, verticale → la card**.
    ///
    /// ⚠️ C'EST UNE VRAIE FORME TACTILE, ET C'EST TOUT LE SUJET. Portée par la
    /// page en `simultaneousGesture`, la verticale ne pouvait JAMAIS gagner :
    /// le ScrollView tient le même doigt, et le lui retirer en plein geste
    /// annule la séquence de touches. Ici le doigt s'arrête sur la zone — le
    /// scroll ne le voit pas — et la card suit, sans arbitrage.
    ///
    /// Le verrou d'axe se décide UNE fois : le tester à chaque image le ferait
    /// osciller (la leçon du tiroir de la home).
    private var priseBasse: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { v in
                if etat.debut != v.startLocation {
                    // Nouveau geste : on repart de zéro. Un geste ANNULÉ ne
                    // reçoit jamais son `onEnded` — sans cette remise à plat,
                    // la scène resterait éteinte et la fumée brûlerait en
                    // boucle sous un tambour que plus personne ne tient.
                    if etat.engaged { relacher() }
                    if etat.mainTient { poigneeFin() }
                    etat.debut = v.startLocation
                    etat.prise = .aucune
                }
                switch etat.prise {
                case .refus:
                    return
                case .aucune:
                    let dx = abs(v.translation.width)
                    let dy = abs(v.translation.height)
                    guard max(dx, dy) > 8 else { return }
                    if dx > dy {
                        etat.prise = .molette
                        etat.base = etat.pos
                        // La course morte du seuil : sans elle le tambour
                        // bondit d'un dixième de cran à l'accrochage.
                        etat.morte = v.translation.width
                        etat.touchStart = .now
                        etat.touchEnd = nil
                        etat.engaged = true
                        tourner(v)
                    } else {
                        etat.prise = .tirage
                        poignee(v)
                    }
                case .molette:
                    tourner(v)
                case .tirage:
                    poignee(v)
                }
            }
            .onEnded { _ in
                if etat.prise == .molette { relacher() }
                if etat.prise == .tirage { poigneeFin() }
                etat.prise = .aucune
                etat.debut = nil
            }
    }

    /// LE TAMBOUR SUIT LE DOIGT : ~100 pt de glisse par cran. Vers la GAUCHE,
    /// le suivant vient au centre — une roue couchée se pousse dans le sens où
    /// l'on veut faire venir la suite.
    private func tourner(_ v: DragGesture.Value) {
        let maxPos = Double(ArcDial.items.count - 1)
        var p = etat.base - Double(v.translation.width - etat.morte) / 100.0
        // Élastique aux extrémités : le tambour résiste, il ne bute pas.
        if p < 0 { p *= 0.30 }
        if p > maxPos { p = maxPos + (p - maxPos) * 0.30 }
        etat.pos = p
        let d = Int(min(max(p, 0), maxPos).rounded())
        if d != etat.detent {
            etat.detent = d
            ArcChime.shared.tick()
        }
    }

    private func relacher() {
        etat.engaged = false
        // ⚠️ LE NETTOYAGE PORTE SON JETON : deux gestes rapprochés, et le bloc
        // programmé par le PREMIER relâchement trouvait l'horodatage du SECOND
        // — il coupait sa fumée net en plein milieu de sa dissolution.
        let fin = Date.now
        etat.touchEnd = fin
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if etat.touchEnd == fin { etat.touchStart = nil; etat.touchEnd = nil }
        }
        let maxPos = Double(ArcDial.items.count - 1)
        let snapped = min(max(etat.pos.rounded(), 0), maxPos)
        withAnimation(.spring(response: 0.34, dampingFraction: 0.76)) {
            etat.pos = snapped
        }
        let idx = Int(snapped)
        if ArcDial.items[idx].1 != filter {
            withAnimation(.easeOut(duration: 0.28)) {
                filter = ArcDial.items[idx].1
            }
            ArcChime.shared.pose()
        }
    }

    // MARK: - Le tuto à projecteurs

    /// L'armement : demandé par « Commencer » (DepartEtat), servi UNE fois
    /// (UserDefaults) — `-tutoExos` le rejoue au banc à volonté.
    private func armerTutoSiDemande() {
        let banc = CommandLine.arguments.contains("-tutoExos")
        guard DepartEtat.shared.tutoDemande || banc else { return }
        DepartEtat.shared.tutoDemande = false
        // EN DEV LE TUTO REJOUE À CHAQUE DÉPART : sans ça, tester le flow en
        // boucle ne le montre qu'une fois dans une vie d'installation.
        #if DEBUG
        let deja = false
        #else
        let deja = UserDefaults.standard.bool(forKey: "tutoExosVu")
        #endif
        guard !deja || banc else { return }
        UserDefaults.standard.set(true, forKey: "tutoExosVu")
        // La page se pose d'abord, le voile tombe ensuite — et la CASCADE
        // (voile → card → molette) s'écrit sur tutoNe.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            tutoNe = Date()
            withAnimation(.easeInOut(duration: 0.3)) { tutoActif = true }
        }
    }

    private func eteindreTuto() {
        guard tutoActif else { return }
        withAnimation(.easeOut(duration: 0.3)) { tutoActif = false }
    }

    /// Le voile percé : la nuit sur toute la page, DEUX fenêtres de lumière (la
    /// card, la molette) aux liserés de braise qui respirent. Les taps des
    /// fenêtres passent au travers (`contentShape` evenOdd).
    @ViewBuilder
    private func tutoCouche(_ anchors: [String: Anchor<CGRect>]) -> some View {
        if tutoActif {
            GeometryReader { g in
                let cardRect = anchors["tuto-card"]
                    .map { g[$0].insetBy(dx: -8, dy: -8) }
                // La fenêtre SERRE la molette : le cadre de l'ArcDial fait
                // 300 pt de haut (la fumée a besoin d'air) et avalerait la
                // moitié de la grille.
                let dialRect = anchors["tuto-dial"].map { a -> CGRect in
                    let r = g[a]
                    return CGRect(x: r.midX - 108, y: r.maxY - 178,
                                  width: 216, height: 168)
                }
                let braise = Color(red: 1.0, green: 0.56, blue: 0.2)
                // LA CASCADE — jamais tout d'un coup : le voile tombe
                // (0 → 0,4), la fenêtre de la card S'OUVRE (0,45 → 0,85), puis
                // celle de la molette (1,05 → 1,45).
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                    let age = tl.date.timeIntervalSince(tutoNe)
                    let sstep: (Double, Double) -> Double = { a, b in
                        let u = min(max((age - a) / (b - a), 0), 1)
                        return u * u * (3 - 2 * u)
                    }
                    let k1 = sstep(0.45, 0.85)
                    let k2 = sstep(1.05, 1.45)
                    let trous = [
                        cardRect.flatMap { r in k1 > 0.01
                            ? r.insetBy(dx: r.width / 2 * (1 - k1),
                                        dy: r.height / 2 * (1 - k1)) : nil },
                        dialRect.flatMap { r in k2 > 0.01
                            ? r.insetBy(dx: r.width / 2 * (1 - k2),
                                        dy: r.height / 2 * (1 - k2)) : nil },
                    ].compactMap { $0 }
                    let vie = 0.55 + 0.35 * sin(age * 2 * .pi / 2.6)
                    ZStack {
                        // LE FLOU DEMANDÉ : le voile est une MATIÈRE — le reste
                        // de la page se floute sous elle, les fenêtres restent
                        // nettes (le trou evenOdd ne floute rien).
                        VoileTuto(trous: trous)
                            .fill(.ultraThinMaterial,
                                  style: FillStyle(eoFill: true))
                            .opacity(sstep(0, 0.4))
                            .ignoresSafeArea()
                        VoileTuto(trous: trous)
                            .fill(Color.black.opacity(0.5 * sstep(0, 0.4)),
                                  style: FillStyle(eoFill: true))
                            .ignoresSafeArea()
                        ForEach(Array(trous.enumerated()), id: \.offset) { _, r in
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(braise, lineWidth: 1.4)
                                .frame(width: r.width, height: r.height)
                                .position(x: r.midX, y: r.midY)
                                .opacity(0.95 * vie)
                                .allowsHitTesting(false)
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(braise, lineWidth: 5)
                                .blur(radius: 7)
                                .frame(width: r.width, height: r.height)
                                .position(x: r.midX, y: r.midY)
                                .opacity(0.55 * vie)
                                .blendMode(.screen)
                                .allowsHitTesting(false)
                        }
                        if let c = cardRect {
                            Text("Choisis ton premier exercice")
                                .font(.inter(13, .medium))
                                .foregroundStyle(Color.white.opacity(0.85))
                                .position(x: max(c.midX, 110), y: c.maxY + 24)
                                .opacity(k1)
                                .allowsHitTesting(false)
                        }
                        if let d = dialRect {
                            Text("La molette filtre")
                                .font(.inter(12, .medium))
                                .foregroundStyle(Color.white.opacity(0.7))
                                .position(x: d.midX, y: d.minY - 18)
                                .opacity(k2)
                                .allowsHitTesting(false)
                        }
                    }
                }
                // Le hit-test sur les fenêtres PLEINES (pas celles en cours
                // d'ouverture) : les taps y passent dès le début — un tuto
                // n'est jamais un mur.
                .contentShape(.interaction,
                              VoileTuto(trous: [cardRect, dialRect]
                                  .compactMap { $0 }),
                              eoFill: true)
                .onTapGesture { eteindreTuto() }
            }
            .ignoresSafeArea()
            .transition(.opacity)
        }
    }
}

// MARK: - Le catalogue

/// La liste des exercices d'une section. Sortie de la vue : elle y était
/// recalculée trois fois par image de scroll.
enum ExosCatalogue {
    /// La liste complète, mémorisée. ⚠️ L'expression par défaut d'un `@State`
    /// est évaluée à CHAQUE init de la vue — et la page est construite dans le
    /// corps du `TabView` racine, donc à chaque passage de celui-ci.
    static let tout: [Exercise] = liste(nil)

    /// ⚠️ UNE RECHERCHE EST GLOBALE. Dès qu'une lettre est tapée, la section
    /// n'a plus cours : chercher « squat » depuis Abdos doit trouver le squat,
    /// pas rendre une page vide à cause d'un filtre qu'on ne voit plus. La
    /// section reprend la main dès que le champ est vidé.
    static func liste(_ filtre: ExerciseCategory?, q: String = "") -> [Exercise] {
        let cle = clef(q)
        guard !cle.isEmpty else {
            let categories = filtre.map { [$0] } ?? ExerciseCategory.allCases
            return categories.flatMap { ExerciseCatalog.exercises(in: $0) }
        }
        return ExerciseCatalog.all.filter { e in
            clef(e.name).contains(cle) || clef(e.muscle).contains(cle)
                || clef(e.equipment.rawValue).contains(cle)
                || clef(e.category.rawValue).contains(cle)
        }
    }

    /// Sans accents ni casse : « élévations » se trouve en tapant
    /// « elevations », « Développé » en tapant « developpe ». Une recherche qui
    /// exige les accents d'un clavier de téléphone ne sert personne.
    static func clef(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive],
                  locale: Locale(identifier: "fr_FR"))
         .trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - La bande découverte

/// LA NAISSANCE DU CROISSANT — la seule chose qui change par image, et elle ne
/// coûte qu'une composition. Elle ne monte pas : elle S'APPROCHE (le couple
/// échelle + éclat, jamais un fondu nu — la loi de la mise au point).
private struct EclatLune: ViewModifier {
    let etat: EtatExos
    let haut: Bool
    func body(content: Content) -> some View {
        let p = haut ? etat.luneHautP : etat.luneP
        return content
            .opacity(p)
            .scaleEffect(0.82 + 0.18 * p)
    }
}

/// Un seul endroit, deux contenus : hors séance le secret de la lune
/// (`LuneSecrete`, la vue de la home réutilisée telle quelle), en séance le
/// player (`WorkoutPill(docked:)`). Exactement la home.
private struct BandeExos: View {
    let etat: EtatExos
    let seance: Workout?

    var body: some View {
        ZStack {
            if etat.enSeance {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    WorkoutPill(exercise: ExerciseCatalog.all[0],
                                startedAt: seance?.startedAt,
                                docked: true,
                                lisere: false,
                                doneSeries: seance?.setCount ?? 0,
                                exoCount: seance?.exerciseCount ?? 0)
                        // ⚠️ Le player ne touche PAS le bord : à ras, son
                        // bouton stop et le départ de la veine se collent à
                        // l'arête physique.
                        .padding(.bottom, 14)
                }
            } else {
                // LA LUNE SE LÈVE DANS LA NUIT QUE LA CARD DÉCOUVRE — en bas
                // quand on la SOULÈVE (la place de la home, celle que le player
                // prend en séance), en haut quand on la POUSSE. Un seul secret,
                // deux nuits possibles : il ne doit pas dépendre du sens qu'on
                // a deviné.
                // ⚠️ LE CROISSANT EST CONSTRUIT UNE FOIS, À PLEIN ÉCLAT, et
                // c'est sa NAISSANCE qu'on module par-dessus. `LuneSecrete`
                // porte TROIS ombres (cœur blanc, tube braise, halo) : lui
                // passer un `p` vivant, c'est trois passes hors écran par image
                // de tirage — pile pendant le geste où Kathryn a vu le lag.
                // À p = 1 elles sont rendues une fois et mises en cache ; le
                // modificateur ne fait plus qu'une opacité et une échelle.
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    LuneSecrete(p: 1)
                        .modifier(EclatLune(etat: etat, haut: false))
                        .padding(.bottom, 46)
                }
                VStack(spacing: 0) {
                    LuneSecrete(p: 1)
                        .modifier(EclatLune(etat: etat, haut: true))
                        .padding(.top, 74)
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Le bandeau du titre — ET LA POIGNÉE DE LA CARD

/// La rangée du chevron ET le titre, côte à côte (verdict 22-08 : « exercice
/// doit être à côté du chevron et de la même taille que la police de la home,
/// sans sous-titre ») — donc 30 semibold, tracking −0,4 : les cotes exactes de
/// `PhraseParams` de la home.
///
/// ⚠️ ET C'EST LA POIGNÉE. Sans `contentShape`, tout ce bandeau était SOURD :
/// ses enfants sont en `allowsHitTesting(false)` et la rangée du chevron n'a
/// qu'un bouton et un `Spacer` — le doigt traversait jusqu'au ScrollView, qui
/// prenait le geste. C'est ça, « je peux pas drag toute la page ».
private struct BandeauExos: View {
    let safeT: CGFloat
    let etat: EtatExos
    /// « Exercices » au repos, le nom de la SECTION dès qu'on en choisit une.
    let titre: String
    /// LE MOT CHERCHÉ, et si le champ a pris la place du titre.
    @Binding var q: String
    @Binding var cherche: Bool
    var retour: () -> Void
    var tirer: (DragGesture.Value) -> Void
    var reposer: () -> Void

    var body: some View {
        // Le haut du bandeau colle à la safe area — moins la marge que la card
        // a déjà prise en tête.
        let haut = max(safeT - GrandeCardExos.margeHaut, 0)
        ZStack(alignment: .topLeading) {
            VoileTitre(etat: etat, hauteur: haut + ExercisesView.hBandeau + 34)

            VStack(spacing: 0) {
                Color.clear.frame(height: haut)
                HStack(spacing: 14) {
                    // Le chevron : LE composant de la maison, aux cotes de la
                    // maison (20 du bord physique, 4 au-dessus, 8 en dessous).
                    ChipVerre(symbole: "chevron.left", label: "Retour",
                              action: retour)
                    if cherche {
                        // LE MOT TAPÉ EST LE TITRE : mêmes cotes, même encre.
                        // On n'ouvre pas une barre de recherche par-dessus la
                        // page — le titre DEVIENT le champ, et la braise prend
                        // au bout des lettres.
                        ChampRecherche(q: $q, reveiller: { etat.clavier = true })
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.opacity.combined(with: .offset(y: 8)))
                    } else {
                        // Le mot CHANGE avec la section : il ne se remplace pas
                        // d'un coup, il s'efface et le suivant monte à sa place —
                        // le `.id` force la transition, la transaction du filtre
                        // lui donne sa courbe.
                        Text(titre)
                            .font(.inter(30, .semibold))
                            .tracking(-0.4)
                            .foregroundStyle(WoopGradient.silverText)
                            .fixedSize()
                            .id(titre)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .offset(y: 10)),
                                removal: .opacity.combined(with: .offset(y: -8))))
                        Spacer(minLength: 0)
                    }
                    // LA LOUPE, au coin droit de la ligne du titre. Le même
                    // galet de verre que le chevron : à cette place, tout autre
                    // objet serait une pièce rapportée.
                    ChipVerre(symbole: cherche ? "xmark" : "magnifyingglass",
                              label: cherche ? "Fermer la recherche" : "Chercher",
                              action: basculer)
                }
                .padding(.horizontal, ExercisesView.encart)
                .padding(.top, 4)
                .padding(.bottom, 8)
            }
        }
        // La poignée s'arrête à la réserve : au-delà, c'est la grille, et le
        // scroll doit y garder le doigt.
        .frame(height: haut + ExercisesView.hBandeau, alignment: .top)
        // ⚠️ `contentShape` D'ABORD : c'est LUI qui fait que le doigt s'arrête
        // ici au lieu de traverser jusqu'au ScrollView. Sans forme tactile, le
        // scroll recevait le toucher et gardait le geste — et c'est ça, « je
        // peux pas drag toute la page ».
        .contentShape(Rectangle())
        // `highPriorityGesture` et pas `gesture` : le bandeau chevauche le
        // ScrollView, et on ne partage pas un doigt avec lui — il perd dès le
        // premier pixel.
        .highPriorityGesture(
            DragGesture(minimumDistance: 10)
                .onChanged { v in
                    // Le verrou d'axe : une horizontale dans le bandeau
                    // n'appartient à personne, elle ne doit pas soulever la
                    // page.
                    guard abs(v.translation.height)
                            > abs(v.translation.width) else { return }
                    tirer(v)
                }
                .onEnded { _ in reposer() }
        )
    }

    /// Ouvre le champ, ou le ferme EN VIDANT le mot : une recherche qu'on
    /// referme ne doit pas laisser la grille filtrée derrière un titre qui
    /// annonce une section.
    private func basculer() {
        let ouvrir = !cherche
        if !ouvrir { q = "" }
        withAnimation(.spring(response: 0.40, dampingFraction: 0.86)) {
            cherche = ouvrir
            etat.clavier = ouvrir
        }
    }
}

// MARK: - Le champ de recherche — ET LA BRAISE DE LA FRAPPE

/// Le titre DEVIENT le champ : 30 semibold, l'encre de la maison, le curseur en
/// braise. La lumière vit DERRIÈRE les lettres et son cœur est posé sur leur
/// ligne — des lettres blanches dans une braise, ça ne se lit pas « un halo
/// sous du texte », ça se lit « des lettres allumées ».
///
/// ⚠️ CE N'EST PAS UN `TextField`. Le clavier du système ne se dessine pas :
/// pour que la lumière prenne aussi DANS LES TOUCHES, le clavier est à nous
/// (`ClavierBraise`) — et un clavier à nous n'a rien à dire à un champ du
/// système. Le texte est donc du `Text`, et le curseur est peint par la braise.
/// On y perd le collage et la dictée ; on y gagne la seule chose qui comptait.
private struct ChampRecherche: View {
    @Binding var q: String
    /// Rouvrir le clavier en tapant sur le mot — une fois rangé (la coche), il
    /// n'y a plus que ça pour le rappeler.
    var reveiller: () -> Void

    /// L'instant de la dernière touche et le compte des touches : TOUTE la
    /// lumière s'écrit dessus. Ils ne changent qu'à la frappe — jamais par
    /// image.
    @State private var frappe = Date()
    @State private var coups = 0

    var body: some View {
        ZStack(alignment: .leading) {
            if q.isEmpty {
                Text("Chercher")
                    .font(.inter(30, .semibold))
                    .tracking(-0.4)
                    .foregroundStyle(Color.white.opacity(0.22))
            } else {
                Text(q)
                    .font(.inter(30, .semibold))
                    .tracking(-0.4)
                    .foregroundStyle(WoopGradient.silverText)
                    .lineLimit(1)
                    // Un mot plus long que la ligne se SERRE au lieu de pousser
                    // la loupe hors de l'écran.
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(height: 44, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        // LA LUMIÈRE, DERRIÈRE. Sa bande est plus haute que la ligne (68 contre
        // 44) : un `Canvas` DÉCOUPE à son cadre, et un souffle plus grand que
        // lui s'y coupe en deux traits horizontaux nets. Elle déborde donc de
        // 12 pt de part et d'autre — la réserve du bandeau les a.
        .background(alignment: .center) {
            GeometryReader { g in
                let m = Self.avance(q)
                BraiseEcriture(
                    x: min(max(m + 4, 7), max(g.size.width - 7, 8)),
                    mot: m, frappe: frappe, coups: coups, gel: ExosBanc.frappe)
            }
            .frame(height: 68)
            .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture { reveiller() }
        .onChange(of: q) { _, _ in
            coups += 1
            frappe = .now
        }
        .onAppear {
            if ExosBanc.cherche != nil, ExosBanc.frappe == nil {
                // LE BANC : la braise se rejoue en boucle, sinon toute capture
                // arrive sur une lumière morte (l'école de la fumée). Inutile
                // quand `-exosFrappe` la fige déjà.
                Timer.scheduledTimer(withTimeInterval: 1.1, repeats: true) { _ in
                    coups += 1
                    frappe = .now
                }
            }
        }
    }

    /// L'abscisse du curseur : la largeur du texte déjà tapé, dans la fonte du
    /// titre.
    ///
    /// ⚠️ MESURÉE À UIKit, pas par une sonde de géométrie. Une sonde qui rend
    /// une constante ne rappelle jamais (le piège payé au scroll), et surtout
    /// cette valeur ne doit changer qu'à la TOUCHE : la faire remonter par une
    /// préférence, c'est une passe de layout par image de frappe.
    static func avance(_ s: String) -> CGFloat {
        guard !s.isEmpty else { return 0 }
        let f = UIFont(name: "Inter-SemiBold", size: 30)
            ?? .systemFont(ofSize: 30, weight: .semibold)
        return (s as NSString)
            .size(withAttributes: [.font: f, .kern: -0.4]).width
    }
}

/// LA BRAISE DE L'ÉCRITURE — la lumière qui prend au bout du mot.
///
/// ⚠️ CE QUI FAISAIT « CHEAP » À LA PREMIÈRE PASSE, et qui est la leçon :
///
///   1. **une seule tache floue.** Un gros rond orange dégradé, c'est un halo
///      de retouche. Une lumière chère a de la STRUCTURE — ici un filament net
///      en travers, un curseur à l'arête franche, un lit d'un point d'épaisseur.
///      Le net contre le flou, c'est ça qui fait la matière ;
///   2. **le blanc étalé.** Le blanc chaud tient dans les 15 % du centre ;
///      au-delà il ne fait pas « chaud », il fait GRIS (mesuré B/R = 0,58 quand
///      la braise de la page est à 0,20) ;
///   3. **la courbe en flash.** Une lumière qui naît à son maximum et retombe,
///      c'est un flash d'appareil photo. Il faut une ATTAQUE (trois centièmes
///      pour monter) et une TRAÎNE longue et basse — un éclair contre une
///      braise ;
///   4. **trop d'aire, pas assez d'écart.** On a baissé les surfaces et monté
///      le contraste : moins de lumière, mais plus vive.
///
/// ⚠️ UN SEUL `Canvas`, la loi 4 de la page : ce qui bouge par image est un
/// DESSIN, jamais une pile de calques animés.
///
/// ⚠️ ET AUCUN `.blur`. Un flou SwiftUI pose un voile clair UNIFORME sur tout
/// le rectangle de son hôte (le piège payé au galet) — sur un bandeau noir, ça
/// se voit tout de suite. La douceur vient des dégradés RADIAUX, qui n'ont pas
/// de bord ; et les nappes larges sont des cercles ÉCRASÉS par le repère
/// (`scaleBy`), jamais des ellipses remplies d'un dégradé rond — une ellipse
/// coupe son dégradé en pleine lumière et laisse deux arêtes.
struct BraiseEcriture: View {
    /// L'abscisse du curseur — le bout du mot.
    let x: CGFloat
    /// La largeur du mot déjà écrit : le lit ne court QUE sous les lettres.
    let mot: CGFloat
    /// L'instant de la dernière touche : TOUT s'écrit dessus.
    let frappe: Date
    /// Le compte des touches. Il SÈME les cendres : deux touches de suite ne
    /// doivent pas donner la même dérive, et un tirage au sort par image les
    /// ferait grésiller au lieu de les faire monter.
    let coups: Int
    /// LE BANC (`-exosFrappe`) : l'âge imposé, et la respiration arrêtée avec
    /// lui. Deux captures du même âge doivent rendre la même image.
    let gel: Double?

    /// La braise de la page — celle des liserés du tuto, au trait près.
    static let braise = Color(red: 1.0, green: 0.56, blue: 0.20)
    /// Le blanc chaud du cœur. ⚠️ Il reste SATURÉ (0,86 de bleu, pas 1,0) :
    /// c'est la loi anti-brun de la page — on désature le vert, on ne remonte
    /// jamais le bleu, sinon la braise vire au rose sale.
    static let coeur = Color(red: 1.0, green: 0.94, blue: 0.86)
    /// La robe profonde, celle qui meurt dans le noir.
    static let profond = Color(red: 0.98, green: 0.26, blue: 0.06)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
            Canvas { ctx, size in
                let age = gel ?? max(0, tl.date.timeIntervalSince(frappe))
                // L'ATTAQUE ET LA TRAÎNE. `f` monte en trois centièmes puis
                // s'éteint lentement — c'est cette montée, invisible à l'œil
                // mais présente, qui distingue une braise d'un flash.
                let f = min(age / 0.03, 1) * exp(-max(0, age - 0.03) * 3.4)
                // Le repos n'est pas l'extinction : la braise RESPIRE tant que
                // le champ est ouvert, sinon un champ vide est un trou noir.
                let horloge = tl.date.timeIntervalSinceReferenceDate
                let respire = gel == nil
                    ? 0.5 + 0.5 * sin(horloge * 2 * .pi / 3.1) : 0.5
                // La ligne des lettres : le centre optique d'un 30 semibold est
                // un cheveu au-dessus du centre géométrique de sa bande.
                let y = size.height * 0.47

                // Une lueur = un cercle de dégradé radial. `ap` l'écrase
                // verticalement AUTOUR de son centre : les nappes larges
                // restent dans la bande au lieu de s'y couper.
                func lueur(_ c: CGPoint, _ r: CGFloat, _ ap: CGFloat,
                           _ stops: [Gradient.Stop]) {
                    guard r > 0.4 else { return }
                    ctx.drawLayer { l in
                        l.translateBy(x: c.x, y: c.y)
                        l.scaleBy(x: 1, y: ap)
                        l.fill(Path(ellipseIn: CGRect(x: -r, y: -r,
                                                      width: 2 * r, height: 2 * r)),
                               with: .radialGradient(Gradient(stops: stops),
                                                     center: .zero,
                                                     startRadius: 0, endRadius: r))
                    }
                }

                // 1. LE LIT — un TRAIT d'un point sous les lettres, qui refroidit
                // vers le début du mot. Il s'arrête EXACTEMENT au bout du mot :
                // une barre qui dépasse dans le noir n'est plus une braise sous
                // des lettres, c'est un soulignement.
                let g0 = max(3, x - mot)
                if x - g0 > 6 {
                    let lit = CGRect(x: g0, y: y + 18, width: x - g0, height: 1)
                    ctx.fill(
                        Path(lit),
                        with: .linearGradient(
                            Gradient(stops: [
                                .init(color: Self.profond.opacity(0), location: 0),
                                .init(color: Self.braise.opacity(0.16 + 0.30 * f),
                                      location: 0.62),
                                .init(color: Self.coeur.opacity(0.34 + 0.50 * f),
                                      location: 1)]),
                            startPoint: CGPoint(x: g0, y: 0),
                            endPoint: CGPoint(x: x, y: 0)))
                    // Sa vapeur : une nappe basse, très large, très faible.
                    let vr = min(x - g0, 150)
                    lueur(CGPoint(x: x - vr * 0.30, y: y + 18), vr, 0.15,
                          [.init(color: Self.braise.opacity(0.05 + 0.10 * f),
                                 location: 0),
                           .init(color: Self.braise.opacity(0), location: 1)])
                }

                // 2. LA ROBE — large, profonde, jamais claire. C'est elle qui
                // pose la chaleur ; elle ne doit jamais devenir le sujet, donc
                // elle SERRE la ligne (0,60) au lieu de faire un disque au-
                // dessus du mot.
                lueur(CGPoint(x: x, y: y), 24 + 24 * f, 0.60,
                      [.init(color: Self.braise.opacity(0.15 + 0.24 * f), location: 0),
                       .init(color: Self.profond.opacity(0.10 + 0.18 * f), location: 0.42),
                       .init(color: Self.profond.opacity(0), location: 1)])

                // 3. LE NOYAU — serré, blanc, et c'est le seul blanc du dessin.
                lueur(CGPoint(x: x, y: y), 8 + 7 * f, 0.92,
                      [.init(color: Self.coeur.opacity(0.50 + 0.45 * f), location: 0),
                       .init(color: Self.braise.opacity(0.34 + 0.40 * f), location: 0.46),
                       .init(color: Self.braise.opacity(0), location: 1)])

                // 4. LE FILAMENT — la signature. Une lame de lumière NETTE en
                // travers du noyau, comme un tungstène vu à travers du verre :
                // c'est le trait franc contre le flou qui fait lire du métal
                // chauffé plutôt qu'une tache.
                //
                // ⚠️ IL EST DÉCENTRÉ VERS LA GAUCHE. Symétrique, il partait
                // aussi loin dans le noir à droite que sur le mot à gauche —
                // et une lance de lumière posée sur du vide, ça redevient un
                // reflet d'objectif. Une traîne se laisse DERRIÈRE soi.
                let fl = 30 + 78 * f
                ctx.drawLayer { l in
                    l.translateBy(x: x - fl * 0.20, y: y)
                    l.scaleBy(x: 1, y: 0.028)
                    l.fill(Path(ellipseIn: CGRect(x: -fl, y: -fl,
                                                  width: 2 * fl, height: 2 * fl)),
                           with: .radialGradient(Gradient(stops: [
                            .init(color: Self.coeur.opacity(0.42 + 0.45 * f), location: 0),
                            .init(color: Self.braise.opacity(0.26 + 0.34 * f), location: 0.34),
                            .init(color: Self.braise.opacity(0), location: 1)]),
                                 center: .zero, startRadius: 0, endRadius: fl))
                }

                // 5. LE CURSEUR — une arête FRANCHE. Il ne clignote pas : un
                // clignotement de curseur est une convention de traitement de
                // texte, pas une braise. Il respire, et il blanchit à la touche.
                let ch = 30.0
                let cr = CGRect(x: x - 1.1, y: y - ch / 2, width: 2.2, height: ch)
                ctx.fill(Path(roundedRect: cr, cornerRadius: 1.1),
                         with: .linearGradient(
                            Gradient(stops: [
                                .init(color: Self.braise.opacity(0.30 + 0.30 * f),
                                      location: 0),
                                .init(color: Self.coeur.opacity(0.72 + 0.28 * f),
                                      location: 0.46),
                                .init(color: Self.braise.opacity(0.34 + 0.30 * f),
                                      location: 1)]),
                            startPoint: CGPoint(x: 0, y: y - ch / 2),
                            endPoint: CGPoint(x: 0, y: y + ch / 2)))
                // Le nimbe du curseur au repos : c'est lui qui respire quand
                // personne ne tape.
                lueur(CGPoint(x: x, y: y), 13 + 3 * CGFloat(respire), 0.90,
                      [.init(color: Self.braise.opacity(0.10 + 0.05 * respire),
                             location: 0),
                       .init(color: Self.braise.opacity(0), location: 1)])

                // 6. LE SOUFFLE — il part du curseur et RECULE SUR LE MOT
                // (écrasé à 0,24). Centré sur le curseur et bordé de clair, il
                // partait dans le noir à droite et s'y lisait comme un reflet
                // d'objectif sale : une auréole, pas un souffle.
                let s = 1 - exp(-age * 4.4)
                let sa = 0.17 * exp(-age * 3.6)
                if sa > 0.004 {
                    let sr = 18 + 78 * s
                    lueur(CGPoint(x: x - sr * 0.34, y: y), sr, 0.24,
                          [.init(color: Self.profond.opacity(0), location: 0),
                           .init(color: Self.braise.opacity(sa * 0.5), location: 0.58),
                           .init(color: Self.braise.opacity(sa), location: 0.80),
                           .init(color: Self.profond.opacity(0), location: 1)])
                }

                // 7. LES CENDRES — deux, minuscules, qui montent en dérivant.
                // Trois grosses étincelles, c'était le feu d'artifice ; deux
                // points d'un point et demi, c'est de la cendre chaude.
                if age < 1.4 {
                    let t = min(age / 1.4, 1)
                    for k in 0..<2 {
                        let g = Double((coups &* 53 &+ k &* 97) % 211) / 211.0
                        let ang = -Double.pi / 2 - 0.45 + 0.9 * g
                        let v = 30 + 40 * g
                        let px = x + CGFloat(cos(ang) * v * t)
                        let py = y + CGFloat(sin(ang) * v * t) + CGFloat(16 * t * t)
                        let a = 0.75 * exp(-age * 2.4) * (1 - t)
                        lueur(CGPoint(x: px, y: py), 1.8, 1,
                              [.init(color: Self.coeur.opacity(a), location: 0),
                               .init(color: Self.braise.opacity(a * 0.5), location: 0.5),
                               .init(color: Self.braise.opacity(0), location: 1)])
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// RIEN TROUVÉ. Une grille vide sur une page noire ne se lit pas « aucun
/// résultat », elle se lit « la page est cassée ». Une ligne suffit — et elle
/// se pose SOUS le bandeau, jamais au centre de l'écran : le bas de la card
/// appartient au lit de la molette.
private struct VideRecherche: View {
    let q: String
    let reserve: CGFloat

    var body: some View {
        VStack(spacing: 7) {
            Text("Rien pour « \(q) »")
                .font(.inter(15, .semibold))
                .foregroundStyle(Color.white.opacity(0.62))
            Text("Un muscle, une machine, une section — tout se cherche.")
                .font(.inter(12))
                .foregroundStyle(Color.white.opacity(0.28))
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 36)
        .padding(.top, reserve + 52)
        .allowsHitTesting(false)
        .transition(.opacity)
    }
}

/// LE FOND NOIR DU TITRE — un DÉGRADÉ NOIR PUR, jamais un matériau.
///
/// ⚠️ MESURÉ, ET C'EST LE PIÈGE DU CALQUE : un `.ultraThinMaterial` posé là
/// n'a que du noir à flouter, et il rend alors sa PROPRE matière — un
/// rectangle gris à 26 niveaux sur une page mesurée à 1,6, avec ses deux
/// arêtes verticales. Le « flou » n'est pas dans le bandeau : il est dans les
/// CARTES qui se floutent en passant dessous (voir le `visualEffect` de la
/// grille). Un vrai flou de contenu, pas un voile posé.
private struct VoileTitre: View {
    let etat: EtatExos
    let hauteur: CGFloat

    var body: some View {
        LinearGradient(stops: [
            .init(color: .black.opacity(0.98), location: 0.0),
            .init(color: .black.opacity(0.96), location: 0.50),
            .init(color: .black.opacity(0.58), location: 0.79),
            .init(color: .black.opacity(0.0), location: 1.0),
        ], startPoint: .top, endPoint: .bottom)
            .frame(height: hauteur)
            .opacity(0.62 + 0.38 * ExosPli.repli(etat.scroll))
            .allowsHitTesting(false)
    }
}

/// LA DENSITÉ DU BANDEAU au scroll : la rampe des 88 premiers points, adoucie
/// en smoothstep. Le titre, lui, ne bouge plus — il est à sa place, à côté du
/// chevron. `-exosVoile <p>` la fige.
enum ExosPli {
    static func repli(_ scroll: CGFloat) -> Double {
        if let f = ExosBanc.voile { return min(max(f, 0), 1) }
        let t = min(max(Double(scroll) / 88, 0), 1)
        return t * t * (3 - 2 * t)
    }
}

// MARK: - La grille

/// Le Pinterest : deux colonnes décalées, pleine largeur de card (la molette ne
/// mange plus le flanc droit — elle est couchée en bas).
///
/// ⚠️ SON CORPS NE LIT AUCUNE VALEUR VIVANTE. Il ÉCRIT le relevé du scroll dans
/// l'état, mais ne le relit jamais : c'est ce qui lui permet de ne pas se
/// reconstruire soixante fois par seconde pendant qu'on défile. Les deux voiles
/// (haut et bas) et le contre-décalage du débord sont calculés dans des
/// `visualEffect`, donc à partir de la GÉOMÉTRIE seule.
private struct GrilleExos: View {
    let items: [Exercise]
    let reserve: CGFloat
    let etat: EtatExos
    /// L'ordre venu de la page (retour en tête, banc). La POSITION, elle, vit
    /// ici : `scrollPosition(_:)` réécrit son binding au poser du doigt, et un
    /// binding tenu par la page invaliderait tout son corps à cet instant-là.
    let ordre: OrdreScroll
    /// Le tuto est armé : la première carte publie alors son ancre. Hors tuto
    /// elle ne publie RIEN — une ancre qui change à chaque image de scroll
    /// rappelle la couche de tuto par image, pour une couche éteinte.
    let tuto: Bool
    @Binding var deepLinked: Exercise?

    @State private var sp = ScrollPosition(edge: .top)

    /// La géométrie de la grille, en constantes : hauteur de carte, gouttière,
    /// décalage Pinterest de la seconde colonne, marge haute du contenu.
    static let cardHeight: CGFloat = 200
    static let gutter: CGFloat = 13
    static let stagger: CGFloat = 30
    static let topPad: CGFloat = 8
    /// Le lit de la molette : le contenu se termine 210 pt avant le bord, la
    /// distance exacte où le voile du bas laisse une carte NETTE. À 150, en
    /// fin de course le dernier rang tombait dans la rampe et restait à moitié
    /// éteint — illisible et intappable pour de bon.
    static let litMolette: CGFloat = 210

    /// LA LOI DU VOILE DU BAS, écrite UNE seule fois — le dessin ET le tap la
    /// lisent (les deux DOIVENT rester accordés ; c'était copié à deux
    /// endroits, donc condamné à diverger). `d` = distance du pied de la carte
    /// au bord bas du viewport : 0 à 210 pt (la carte est nette, c'est là que
    /// le dernier rang se pose en fin de course), 1 à 80 pt.
    ///
    /// ⚠️ ELLE ÉTEINT, ELLE NE TAMISE PAS — et c'est un correctif MESURÉ
    /// (verdict 22-08 : « un problème de blur dans les coins »). À 45 %
    /// d'opacité résiduelle, une carte n'est pas fondue : c'est une PLAQUE
    /// noire de 174 × 200 posée sur la braise, et **son coin de 20 pt lui
    /// survit** — un flou feutre un bord, il n'efface pas une silhouette. Le
    /// fantôme mesurait 12 à 16 de BLEU sur une braise qui n'en a que 0 à 4,
    /// et ses deux taches se décalaient de 90 px : les 30 pt du décalage
    /// Pinterest. La carte doit donc être ÉTEINTE avant d'entrer dans la
    /// braise, pas assombrie.
    static func voileBas(_ d: CGFloat) -> Double {
        Double(min(max((210 - d) / 130, 0), 1))
    }

    /// LA LOI DU VOILE DU HAUT, elle aussi écrite une seule fois. `d` =
    /// distance de la tête de la carte au bas du bandeau (positive quand la
    /// carte est passée dessous). Elle garde son résidu : le dégradé noir du
    /// titre le couvre, et une extinction totale tuerait le fondu des cartes
    /// qui glissent sous lui.
    static func voileHaut(_ d: CGFloat) -> Double {
        Double(min(max(d / 130, 0), 1))
    }

    /// Deux colonnes remplies en alternance — indices dans `items`, pour que le
    /// calcul du voile retrouve la position de chaque carte.
    private var columnsIdx: ([Int], [Int]) {
        var left: [Int] = [], right: [Int] = []
        for i in items.indices {
            if i.isMultiple(of: 2) { left.append(i) } else { right.append(i) }
        }
        return (left, right)
    }

    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: Self.gutter) {
                cardColumn(columnsIdx.0)
                cardColumn(columnsIdx.1)
                    .padding(.top, Self.stagger)
            }
            .scrollTargetLayout()
            // La réserve du bandeau : les cartes commencent SOUS lui et passent
            // DERRIÈRE lui au scroll.
            .padding(.top, reserve + Self.topPad)
            .padding(.horizontal, ExercisesView.encart)
            // Le lit de la molette : aucune carte ne s'y pose au repos.
            .padding(.bottom, Self.litMolette)
            // ⚠️ LE CONTRE-DÉCALAGE DU DÉBORD, EN PURE GÉOMÉTRIE. Aux deux
            // bouts, le rebond du scroll déplace déjà le contenu ; comme la
            // card suit ce même débord, sans ce contre-offset la grille
            // voyagerait DEUX fois. Et tout se lit dans le PROXY (position et
            // taille du contenu), jamais dans un `@State` : aucune dépendance,
            // aucune invalidation.
            .visualEffect { content, proxy in
                let h = proxy.size.height
                let vh = proxy.bounds(of: .scrollView)?.height ?? h
                let minY = proxy.frame(in: .scrollView).minY
                let fin = max(0, h - vh)
                let debordHaut = max(0, minY)
                let debordBas = max(0, -minY - fin)
                return content.offset(y: debordBas - debordHaut)
            }
        }
        .scrollPosition($sp)
        // L'ordre venu de la page : retour en tête au changement de section,
        // ou la cible du banc.
        .onChange(of: ordre) { _, o in
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                sp.scrollTo(y: o.y)
            }
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.9),
                         trigger: etat.pulse)
        // ⚠️ UNE SEULE SONDE (la loi payée) : offset + viewport + fin de course
        // dans un seul relevé. C'est elle AUSSI qui nourrit le tirage de la
        // card, par le DÉBORD : en tête on pousse la page vers le bas, en fin
        // de course on la SOULÈVE et la lune se lève. Aucun geste à arbitrer,
        // aucun `scrollDisabled` (le désarmer en plein geste annule la
        // séquence de touches — c'est ce qui tuait le tirage).
        .onScrollGeometryChange(for: SondeScroll.self, of: { g in
            SondeScroll(
                offset: g.contentOffset.y + g.contentInsets.top,
                viewport: g.containerSize.height,
                fin: max(0, g.contentSize.height + g.contentInsets.top
                            + g.contentInsets.bottom - g.containerSize.height))
        }) { _, s in
            if etat.scroll != s.offset { etat.scroll = s.offset }
            if etat.viewportH != s.viewport { etat.viewportH = s.viewport }
            if etat.finCourse != s.fin { etat.finCourse = s.fin }
            // La poignée du bandeau a la priorité : elle tient la card, le
            // débord n'a rien à dire. Et `-exosTirage` fige la card : sans
            // cette garde, le tout premier relevé de layout (débord nul)
            // écrasait la valeur du banc — la levée figée ne se voyait plus.
            guard !etat.mainTient, ExosBanc.tirage == nil else { return }
            // LE REBOND EST LE TIRAGE : en tête il pousse la card vers le bas,
            // en fin de course il la LÈVE et la lune se lève. Même élastique
            // que la poignée (150 · tanh) : la card répond exactement pareil,
            // qu'on la prenne par le bandeau ou qu'on pousse la liste au-delà
            // de son bout. Et au lâcher, le scroll revient tout seul — aucun
            // ressort à écrire.
            var sur: CGFloat = 0
            if s.offset < 0 {
                sur = -s.offset * (etat.enSeance ? 0.35 : 1)
            } else if s.offset > s.fin {
                sur = -(s.offset - s.fin)
            }
            // Le débord d'UIKit est DÉJÀ amorti (rubber band) : on l'assouplit
            // moins que le doigt nu, sinon la lune reste hors d'atteinte.
            let t = 160 * CGFloat(tanh(Double(sur) / 90))
            if etat.tirage != t { etat.tirage = t }
            // LA BRAISE DU SECRET vaut pour les DEUX chemins : découvrir la
            // lune en poussant la liste au-delà de son bout — le chemin normal
            // — ne se sentait pas.
            let p = max(etat.luneP, etat.luneHautP)
            if p >= 1, !etat.luneSentie {
                etat.luneSentie = true
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            } else if p < 0.15 {
                etat.luneSentie = false
            }
        }
        .scrollIndicators(.hidden)
        // ON NE TAPE PLUS QUAND ON REGARDE : le clavier se range dès que le
        // DOIGT pousse la liste.
        //
        // ⚠️ ET C'EST LA PHASE QU'ON ÉCOUTE, PAS LA GÉOMÉTRIE. Branché sur la
        // sonde de scroll, le clavier mourait à la première image : cette sonde
        // tombe une fois au tout premier layout, doigt ou pas — le clavier ne
        // s'est jamais montré une seule fois. Et le filtrer sur un déplacement
        // ne suffirait pas non plus : chaque lettre tapée renvoie la liste en
        // tête (`ordre`), donc chaque lettre refermerait le clavier.
        .onScrollPhaseChange { _, phase in
            guard phase == .interacting, etat.clavier else { return }
            withAnimation(.spring(response: 0.38, dampingFraction: 0.9)) {
                etat.clavier = false
            }
        }
    }

    /// La prise du voile pour la carte d'indice `i` : 0 = nette, 1 = fondue au
    /// bord bas. Même loi que le `visualEffect` — les deux DOIVENT rester
    /// accordées, c'est elle qui décide du geste au tap. Appelée dans l'action
    /// d'un bouton, jamais dans un corps de vue : elle peut lire l'état vivant
    /// sans rien invalider.
    /// ⚠️ ELLE LIT LES DEUX VOILES. Elle n'en lisait qu'un : taper une carte à
    /// moitié glissée SOUS le bandeau — floutée, éteinte de moitié, illisible —
    /// ouvrait sa fiche au lieu de la faire redescendre. On ouvrait un exercice
    /// qu'on n'avait pas pu lire.
    private func veilT(_ i: Int) -> Double {
        let minY = tete(i) - etat.scroll
        return max(Self.voileBas(etat.viewportH - minY - Self.cardHeight),
                   Self.voileHaut(reserve - minY))
    }

    /// Le haut de la carte `i` dans le contenu du scroll — l'arithmétique des
    /// hauteurs FIXES, aucune mesure.
    private func tete(_ i: Int) -> CGFloat {
        let col = CGFloat(i % 2), row = CGFloat(i / 2)
        return reserve + Self.topPad + col * Self.stagger
             + row * (Self.cardHeight + Self.gutter)
    }

    private func cardColumn(_ indices: [Int]) -> some View {
        let list = items
        let reserve = self.reserve
        return LazyVStack(spacing: Self.gutter) {
            ForEach(Array(indices.enumerated()), id: \.element) { row, i in
                let exercise = list[i]
                Button {
                    if veilT(i) < 0.35 {
                        deepLinked = exercise
                    } else {
                        // Une carte prise dans le voile se REJOINT d'abord : le
                        // scroll la remonte, avec le souffle et l'impact. Elle
                        // se pose 16 pt SOUS le bandeau — collée à son bord,
                        // elle arriverait dans le voile du haut, donc floutée.
                        etat.pulse += 1
                        ArcChime.shared.card()
                        withAnimation(.spring(response: 0.5,
                                              dampingFraction: 0.8)) {
                            sp.scrollTo(y: max(0, tete(i) - reserve - 16))
                        }
                    }
                } label: {
                    ExerciseCard(exercise: exercise)
                }
                .buttonStyle(CardPressStyle())
                .id(exercise.id)
                // L'ancre du tuto : la PREMIÈRE card publie son rect — le
                // projecteur se découpe dessus (l'école SlotAnchorKey).
                // ⚠️ SEULEMENT TUTO ARMÉ. Publiée en permanence, elle change à
                // chaque image de scroll et rappelle donc la couche de tuto par
                // image — une passe de préférences et de layout pour une couche
                // éteinte 99,9 % du temps.
                .overlay {
                    if tuto, i == 0 {
                        Color.clear
                            .anchorPreference(key: SlotAnchorKey.self,
                                              value: .bounds) {
                                ["tuto-card": $0]
                            }
                    }
                }
                // La cascade du changement de section : chaque carte arrive en
                // montant, avec un léger retard par rangée — on redistribue les
                // cartes, on ne les téléporte pas.
                .transition(.asymmetric(
                    insertion: AnyTransition.opacity
                        .combined(with: .offset(y: 26))
                        .animation(.spring(response: 0.5, dampingFraction: 0.82)
                            .delay(Double(row) * 0.04)),
                    removal: AnyTransition.opacity
                        .combined(with: .offset(y: 12))
                        .animation(.easeIn(duration: 0.16))
                ))
                // LES DEUX VOILES, tout en géométrie — et ils n'ont PAS la même
                // loi, parce qu'ils ne tombent pas sur le même fond.
                //
                // EN BAS, la carte s'ÉTEINT (`voileBas`) : elle se pose sur la
                // braise, et un résidu de 45 % y laisse une plaque grise à coin
                // arrondi dans les deux coins de la card (mesuré, 22-08).
                //
                // EN HAUT, elle garde son résidu : le dégradé noir du bandeau
                // (0,98) le couvre déjà, et une extinction totale tuerait le
                // fondu des cartes qui glissent sous le titre — c'est
                // exactement lui, le « fond noir blur ».
                .visualEffect { content, proxy in
                    let f = proxy.frame(in: .scrollView)
                    let vh = proxy.bounds(of: .scrollView)?.height ?? 780
                    let bas = GrilleExos.voileBas(vh - f.maxY)
                    let haut = GrilleExos.voileHaut(reserve - f.minY)
                    // Smoothstep : la rampe du bas ne doit pas avoir de coude.
                    let b = bas * bas * (3 - 2 * bas)
                    let h = haut * haut
                    return content
                        .blur(radius: max(14 * b, 9 * h))
                        .opacity(min(1 - b, 1 - 0.55 * h))
                }
            }
        }
    }
}

/// Le voile du tuto : la page entière MOINS les fenêtres (evenOdd).
private struct VoileTuto: Shape {
    var trous: [CGRect]
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addRect(rect)
        for t in trous {
            p.addRoundedRect(in: t,
                             cornerSize: CGSize(width: 20, height: 20),
                             style: .continuous)
        }
        return p
    }
}

// MARK: - La molette couchée (v6)

/// Le filtre de la page, COUCHÉ AU BAS DE LA CARD. AUCUNE surface, aucun rail :
/// un anneau de graduations fines dont le DÉGRADÉ DE LUMIÈRE fait la forme
/// (blanches au point focal — droit au-dessus du disque —, extinction cosinus
/// le long de l'arc), autour d'une petite couronne de verre liquide fumé posée
/// sur le bord bas. Les labels : casse naturelle, encre dégradé blanc, **à
/// l'horizontale** (ils étaient tournés le long de l'arc quand la molette était
/// debout : couchée, un nom vertical ne se lit plus).
///
/// ⚠️ ELLE NE PREND PAS LE DOIGT (`allowsHitTesting(false)` de bout en bout) :
/// son geste appartient à la page — une bande tactile au bas de la card
/// avalerait le scroll et les taps des cartes qui passent dessous.
///
/// ⚠️ ET ELLE EST DÉCOUPÉE EN TROIS. Son corps à elle ne lit rien de vivant :
/// le disque de verre (cher : `glassEffect` + un TimelineView) ne lit que
/// `engaged`, la fumée que les horodatages, et seul le TAMBOUR (graduations +
/// noms) se redessine par image de geste.
private struct ArcDial: View {
    let etat: EtatExos

    static let items: [(String, ExerciseCategory?)] = {
        var all: [(String, ExerciseCategory?)] = [("Tout", nil)]
        for category in ExerciseCategory.allCases {
            all.append((category.rawValue, category))
        }
        return all
    }()

    /// La géométrie : la couronne presque posée sur le bord bas de la card, les
    /// graduations serrées autour d'elle (pas de 5°, mesuré sur la référence),
    /// les labels en éventail SEULEMENT à l'engagement.
    static let knobR: CGFloat = 44
    static let ringR: CGFloat = 72
    /// La hauteur du disque au-dessus du bord bas de la card : 78, pour que le
    /// verre garde 34 pt d'air sous lui — l'indicateur du système passe là, et
    /// un geste qui part du tout dernier centimètre appartient à iOS.
    static let knobLift: CGFloat = 78
    static let labelSpacing: Double = 0.52
    /// LE FOCAL : droit au-dessus du disque. C'est là que les traits sont
    /// blancs et que le nom actif se pose.
    static let focal: Double = -.pi / 2

    var body: some View {
        GeometryReader { geo in
            let kx = geo.size.width / 2
            let ky = geo.size.height - Self.knobLift
            ZStack {
                ArcSmoke(etat: etat, kx: kx, ky: ky,
                         w: geo.size.width, h: geo.size.height)
                ArcKnob(etat: etat, kx: kx, ky: ky)
                ArcTambour(etat: etat, kx: kx, ky: ky)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .allowsHitTesting(false)
        // ⚠️ ELLE RESTE PILOTABLE AU LECTEUR D'ÉCRAN. Sourde au doigt (son
        // geste appartient à la page), la molette n'offrirait plus AUCUNE prise
        // à VoiceOver : le filtre de la bibliothèque deviendrait inatteignable.
        // L'action passe par l'état, jamais par une closure — les entrées de
        // cette vue doivent rester stables.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Filtre de catégorie")
        .accessibilityValue(Self.items[
            Int(min(max(etat.pos.rounded(), 0),
                    Double(Self.items.count - 1)))].0)
        .accessibilityAdjustableAction { direction in
            let maxPos = Double(Self.items.count - 1)
            let next = direction == .increment
                ? min(etat.pos.rounded() + 1, maxPos)
                : max(etat.pos.rounded() - 1, 0)
            withAnimation(.spring(response: 0.34, dampingFraction: 0.76)) {
                etat.pos = next
            }
            etat.detent = Int(next)
            etat.filtreDemande = Int(next)
        }
    }
}

/// La fumée : montée uniquement pendant et juste après le toucher — au repos ce
/// sous-arbre n'existe pas, coût nul.
private struct ArcSmoke: View {
    let etat: EtatExos
    let kx: CGFloat, ky: CGFloat, w: CGFloat, h: CGFloat

    var body: some View {
        if let start = etat.touchStart {
            let fin = etat.touchEnd
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let now = timeline.date
                let age = now.timeIntervalSince(start)
                let attack = min(age / 0.10, 1.0)
                let release = fin.map { now.timeIntervalSince($0) } ?? 0
                let puff = attack * exp(-max(release, 0) / 0.45)
                let t = now.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 900)
                Rectangle()
                    .fill(.white)
                    .colorEffect(ShaderLibrary.knobSmoke(
                        .float2(w, h),
                        .float(t),
                        .float4(kx, ky, ArcDial.knobR, ArcDial.ringR),
                        .float(puff),
                        .float(age)
                    ))
            }
            .allowsHitTesting(false)
        }
    }
}

/// La couronne : du VRAI verre liquide — un murmure de braise derrière le
/// disque (le verre a enfin quelque chose à réfracter), un dôme spéculaire
/// large et faible (la règle du piano black), un arc de reflet interne en bas,
/// un liseré hairline qui RESPIRE à deux sinus incommensurables.
///
/// ⚠️ LE CRAN D'INDEX N'EST PLUS ICI : il est dessiné par le tambour, dans son
/// `Canvas`. Sinon ce disque — verre natif + TimelineView — se reconstruisait à
/// chaque image de rotation.
private struct ArcKnob: View {
    let etat: EtatExos
    let kx: CGFloat, ky: CGFloat

    var body: some View {
        let engaged = etat.engaged
        let r = ArcDial.knobR
        return ZStack {
            // Le murmure de braise : quasi imperceptible en soi, il n'existe
            // que réfracté par le verre — c'est lui qui rend le disque LIQUIDE
            // au lieu de plat.
            RadialGradient(
                colors: [Color(red: 1.0, green: 0.72, blue: 0.38)
                             .opacity(engaged ? 0.22 : 0.13),
                         .clear],
                center: .center, startRadius: 2, endRadius: r * 1.45
            )
            .frame(width: r * 3, height: r * 3)

            Color.clear
                .frame(width: r * 2, height: r * 2)
                // ⚠️ LA TEINTE A DOUBLÉ (0,20 → 0,38). Le verre est passé du
                // couloir de NUIT du bord droit au lit de BRAISE du bas : à
                // 0,20 il buvait la flamme et rendait un galet blanc laiteux
                // (mesuré à la capture). Un verre fumé reste fumé, quelle que
                // soit la lumière qu'il a sous lui.
                .glassEffect(.regular.tint(Color.black.opacity(0.38))
                                 .interactive(),
                             in: .circle)
                .overlay {
                    // Dôme spéculaire : LARGE et FAIBLE — au-delà, le verre
                    // noir devient plastique.
                    Circle().fill(
                        RadialGradient(
                            colors: [.white.opacity(0.11), .clear],
                            center: UnitPoint(x: 0.42, y: 0.16),
                            startRadius: 1, endRadius: r * 1.35
                        )
                    )
                }
                .overlay {
                    // L'arc de reflet interne, couché contre le bord bas.
                    Circle()
                        .inset(by: 3.5)
                        .trim(from: 0.14, to: 0.36)
                        .stroke(Color.white.opacity(0.10),
                                style: StrokeStyle(lineWidth: 4,
                                                   lineCap: .round))
                        .blur(radius: 2.6)
                }
                .overlay {
                    // Le liseré vivant : la respiration des icônes de la nav.
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                        let clock = tl.date.timeIntervalSinceReferenceDate
                        let warm = 0.5 + 0.5 * sin(clock * 0.83)
                        let cool = 0.5 + 0.5 * sin(clock * 0.57 + 1.7)
                        Circle().strokeBorder(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(
                                        (engaged ? 0.55 : 0.30) + 0.12 * warm),
                                          location: 0.0),
                                    .init(color: .white.opacity(0.05 + 0.03 * cool),
                                          location: 0.55),
                                    .init(color: .white.opacity(0.0), location: 1.0)
                                ],
                                startPoint: .top, endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                    }
                }
        }
        .position(x: kx, y: ky)
        .animation(.spring(response: 0.38, dampingFraction: 0.82),
                   value: engaged)
    }
}

/// LE TAMBOUR : les graduations, le cran d'index et les noms. C'est la SEULE
/// partie qui se redessine par image de geste — et les 72 traits sont un
/// `Canvas`, un dessin unique, plus 72 vues avec chacune son dégradé et son
/// `.shadow` (le vrai prix de la molette « pas fluide »).
private struct ArcTambour: View {
    let etat: EtatExos
    let kx: CGFloat, ky: CGFloat

    var body: some View {
        let pos = etat.pos
        let engaged = etat.engaged
        ZStack {
            ArcTicks(pos: pos, boost: engaged ? 1.0 : 0.72,
                     index: engaged ? 0.85 : 0.50, kx: kx, ky: ky)
            restLabel(pos: pos, engaged: engaged)
            labels(pos: pos, engaged: engaged)
        }
        // Le tick des crans se sent ICI : c'est la seule vue qui suit le
        // tambour par image, et la page n'a plus à s'invalider pour ça.
        .sensoryFeedback(.selection, trigger: etat.detent)
    }

    /// Au repos : l'actif en PETIT, juste au-dessus des graduations — plus
    /// jamais un grand nom couché sur les cartes.
    private func restLabel(pos: Double, engaged: Bool) -> some View {
        let idx = Int(min(max(pos.rounded(), 0),
                          Double(ArcDial.items.count - 1)))
        return Text(ArcDial.items[idx].0)
            .font(.inter(12.5, .medium))
            .tracking(0.3)
            .foregroundStyle(WoopGradient.silverText)
            .fixedSize()
            .opacity(engaged ? 0.0 : 0.80)
            .blur(radius: engaged ? 4 : 0)
            .position(x: kx, y: ky - ArcDial.ringR - 22)
            .allowsHitTesting(false)
    }

    /// À l'engagement : le grand éventail se déploie AU-DESSUS du disque —
    /// casse naturelle, encre dégradé blanc, le flou pour seule profondeur, et
    /// les mots À PLAT (une roue couchée porte des noms horizontaux, sinon on
    /// incline la tête pour lire son filtre).
    private func labels(pos: Double, engaged: Bool) -> some View {
        let labelR: CGFloat = engaged ? 124 : 96
        return ForEach(0..<ArcDial.items.count, id: \.self) { i in
            let delta = (Double(i) - pos) * ArcDial.labelSpacing
            let n = abs(delta) / ArcDial.labelSpacing
            Text(ArcDial.items[i].0)
                .font(.inter(22, .semibold))
                .tracking(0.4)
                .foregroundStyle(WoopGradient.silverText)
                .fixedSize()
                .blur(radius: 2.6 * min(n, 2.0))
                .opacity(engaged ? (n < 0.5 ? 1.0 : max(0.16, 0.85 - 0.30 * n))
                                 : 0.0)
                .scaleEffect((engaged ? 1.0 : 0.55)
                             * max(0.5, 1.0 - 0.28 * min(n, 1.8)))
                .position(x: kx + labelR * CGFloat(sin(delta)),
                          y: ky - labelR * CGFloat(cos(delta)))
                .allowsHitTesting(false)
        }
    }
}

/// L'anneau de graduations — la référence copiée : RIEN que des traits, blancs
/// au focal (droit au-dessus du disque), extinction cosinus le long de l'arc.
/// Chaque trait est LUI-MÊME un dégradé (pied vif côté disque, pointe
/// évanescente), sa longueur suit la lumière, et les plus brillants portent un
/// bloom très doux — c'est la gravure de la référence.
///
/// ⚠️ `Animatable` SUR `pos` : un `Canvas` n'est pas animable tout seul — sans
/// ça, l'aimantation du cran au lâcher SAUTERAIT au lieu de glisser (la loi
/// déjà écrite pour les rampes sous `withAnimation`).
private struct ArcTicks: View, Animatable {
    var pos: Double
    var boost: Double
    var index: Double
    var kx: CGFloat
    var ky: CGFloat

    /// ⚠️ LES TROIS VALEURS SONT ANIMÉES, pas seulement la position. `boost` et
    /// `index` viennent de l'engagement ; consommés dans un `Canvas` — que
    /// SwiftUI ne sait pas interpoler tout seul — ils claquaient d'un état à
    /// l'autre, là où les 72 vues d'avant montaient en fondu avec le théâtre.
    var animatableData: AnimatablePair<Double, AnimatablePair<Double, Double>> {
        get { AnimatablePair(pos, AnimatablePair(boost, index)) }
        set {
            pos = newValue.first
            boost = newValue.second.first
            index = newValue.second.second
        }
    }

    private static let pitch: Double = .pi / 36

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: false) { ctx, _ in
            let drum = pos * ArcDial.labelSpacing
            for k in 0..<72 {
                let theta = Double(k) * Self.pitch - drum
                let delta = abs(atan2(sin(theta - ArcDial.focal),
                                      cos(theta - ArcDial.focal)))
                let fade = pow(max(0.0, cos(delta * 0.82)), 1.6) * boost
                if fade <= 0.02 { continue }
                let h = 9 + 5 * fade
                var c = ctx
                c.translateBy(x: kx + ArcDial.ringR * CGFloat(cos(theta)),
                              y: ky + ArcDial.ringR * CGFloat(sin(theta)))
                c.rotate(by: .radians(theta + .pi / 2))
                let rect = CGRect(x: -0.55, y: -h / 2, width: 1.1, height: h)
                let trait = Path(roundedRect: rect, cornerRadius: 0.55)
                c.fill(trait, with: .linearGradient(
                    Gradient(stops: [
                        .init(color: .white.opacity(fade), location: 0.0),
                        .init(color: .white.opacity(fade * 0.45), location: 0.62),
                        .init(color: .white.opacity(0.0), location: 1.0),
                    ]),
                    startPoint: CGPoint(x: 0, y: -h / 2),
                    endPoint: CGPoint(x: 0, y: h / 2)))
                // LE BLOOM des plus brillants — un second trait plus large et
                // très pâle, jamais un `.shadow` : une ombre par graduation,
                // c'est 72 calques hors écran par image.
                if fade > 0.78 {
                    let halo = Path(roundedRect:
                        rect.insetBy(dx: -1.5, dy: -1.0), cornerRadius: 1.6)
                    c.fill(halo, with: .color(
                        .white.opacity((fade - 0.78) * 1.1 * 0.55)))
                }
            }
            // LE CRAN D'INDEX, sur le disque : il tourne avec le tambour et
            // pointe le nom actif. Dessiné ici et pas dans le verre — le verre
            // ne doit pas se reconstruire par image.
            let a = ArcDial.focal - pos * ArcDial.labelSpacing
            let rr = ArcDial.knobR - 11
            let d = CGRect(x: kx + rr * CGFloat(cos(a)) - 1.75,
                           y: ky + rr * CGFloat(sin(a)) - 1.75,
                           width: 3.5, height: 3.5)
            ctx.fill(Path(ellipseIn: d), with: .color(.white.opacity(index)))
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Les sons de la couronne et de la grille

/// Les voix du cadran éclipse, reprises : le tick des crans, le souffle de la
/// pose, le tock d'une carte qui remonte du voile. `.ambient` +
/// `mixWithOthers` — jamais par-dessus la musique de la salle.
@MainActor
final class ArcChime {
    static let shared = ArcChime()

    private let tickPlayer: AVAudioPlayer?
    private let posePlayer: AVAudioPlayer?
    private let cardPlayer: AVAudioPlayer?

    private init() {
        try? AVAudioSession.sharedInstance()
            .setCategory(.ambient, options: [.mixWithOthers])
        func load(_ name: String) -> AVAudioPlayer? {
            guard let url = Bundle.main.url(forResource: name,
                                            withExtension: "wav") else {
                return nil
            }
            let player = try? AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            return player
        }
        tickPlayer = load("DialTick")
        posePlayer = load("DialTap")
        cardPlayer = load("DialTock")
    }

    func tick() { play(tickPlayer, volume: 0.38) }
    func pose() { play(posePlayer, volume: 0.55) }
    func card() { play(cardPlayer, volume: 0.50) }

    private func play(_ player: AVAudioPlayer?, volume: Float) {
        guard let player else { return }
        player.volume = volume
        player.currentTime = 0
        player.play()
    }
}

// MARK: - Carte d'exercice

/// Le zoom et la vibration du tap : la carte répond sous le doigt — un
/// tassement bref, un impact — avant de partir vers la fiche.
private struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.72),
                       value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .medium, intensity: 0.85),
                             trigger: configuration.isPressed) { _, pressed in
                pressed
            }
    }
}

struct ExerciseCard: View {
    let exercise: Exercise

    private static let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

    /// LA NUIT QUI SE DISSOUT — l'aplat noir qui porte la photo, et qui
    /// s'efface avant le bas de la carte.
    ///
    /// ⚠️ C'EST LUI, LE FONDU (verdict 22-08 : « ça fait pas fondu entre le
    /// haut avec l'image et le bas, c'est bizarre »). Le verre ne peut PAS se
    /// fondre par le bas : son arête est ce qui en fait du verre. Alors on
    /// retourne le problème — **le verre prend TOUTE la carte**, donc plus une
    /// seule couture à l'intérieur, et c'est la NUIT qu'on peint par-dessus et
    /// qu'on dissout. Le haut reste noir absolu (le contrat qui fond les
    /// photos sans couture), le bas devient fenêtre, et entre les deux il n'y a
    /// qu'un dégradé — rien à raccorder.
    ///
    /// ⚠️ ET AUCUNE TEINTE CHAUDE nulle part. Un dégradé de braise posé sur un
    /// gris sombre vire au BRUN — verdict immédiat : « c'est marron ». La
    /// chaleur doit venir de la VIDÉO à travers le verre, jamais d'un gris
    /// réchauffé.
    private static let nuitFondue = LinearGradient(
        stops: [
            .init(color: .black, location: 0.0),
            .init(color: .black, location: 0.46),
            .init(color: .black.opacity(0.72), location: 0.58),
            .init(color: .black.opacity(0.30), location: 0.68),
            .init(color: .black.opacity(0.0), location: 0.78)
        ],
        startPoint: .top, endPoint: .bottom
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // La vignette : réduite, centrée, FONDUE — les deux masques chaînés
            // du héros de la fiche (ils se multiplient : les quatre bords
            // s'évaporent dans le noir pur de la carte).
            ExercisePhoto(exercise: exercise)
                .frame(width: 88, height: 88)
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .white, location: 0.18),
                            .init(color: .white, location: 0.82),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                }
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .white, location: 0.18),
                            .init(color: .white, location: 0.82),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .leading, endPoint: .trailing
                    )
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 14)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name)
                    .font(.inter(11.5, .semibold))
                    .foregroundStyle(Color.inkPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(exercise.muscle)
                    .font(.inter(9.5))
                    .foregroundStyle(Color.white.opacity(0.46))
                    .lineLimit(1)

                Text(exercise.equipment.rawValue.uppercased())
                    .font(.inter(7.5, .bold))
                    .tracking(0.7)
                    .foregroundStyle(Color.white.opacity(0.32))
                    .padding(.horizontal, 5).padding(.vertical, 2.5)
                    .background(Capsule().fill(Color.white.opacity(0.05)))
                    .padding(.top, 2)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                // LA CARTE EST UNE SEULE DALLE DE VERRE — la recette de la
                // dalle du profil, verbatim, mais sur TOUTE la carte : la
                // forme remplie de clair, `glassEffect(.clear)` dedans. Pas de
                // liseré : un trait autour du bas redécoupait la carte en deux
                // étages et la faisait lire comme un panneau rapporté.
                Self.shape
                    .fill(Color.clear)
                    .glassEffect(.clear, in: Self.shape)
                // LA NUIT PAR-DESSUS, qui se dissout. Là où elle est pleine, le
                // verre n'existe pas ; là où elle s'efface, la vidéo remonte au
                // travers.
                Self.shape.fill(Self.nuitFondue)
            }
        }
        .clipShape(Self.shape)
    }
}
