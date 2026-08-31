import SwiftUI
import SwiftData

// MARK: - La fiche, qui est aussi l'éditeur

/// LA fiche d'un exercice — et son éditeur. Elle a absorbé l'ancienne feuille
/// modale `LogExerciseSheet` : il n'y a plus « consulter », puis « ouvrir pour
/// saisir ». Il y a un seul écran, où l'on règle et où l'on lance.
///
/// La page est NOIRE, et LA CARTE EST MORTE en musculation : plus de fond
/// posé, plus de découpe à grands coins — c'était cette arête franche à
/// 115 pt, avec le feu coupé net derrière, qui donnait la lecture « une
/// carte qui scrolle ». Le feu du header a désormais une QUEUE et s'éteint
/// tout seul dans la nuit de la page (voir `HeaderEmberCard`), la photo
/// monte dedans, et le titre passe SOUS elle, sur deux lignes. En plancher
/// le GALET D'AUBE — un galet de verre noir draggable où la lumière dort
/// (`LaunchPebble.swift`). Le cardio, lui, garde sa carte et son fond : sa
/// page défile, et un contenu qui défile a besoin d'un couteau.
/// L'ancien dôme blanc et son échancrure dorment, inutilisés, dans
/// `ExerciseSetupCard.swift` / `NotchedCard.swift`.
///
/// Le banc : `-exoLab` ouvre cette fiche seule (+ `-activeWorkout` pour voir
/// la pastille et son échancrure).
struct ExerciseDetailView: View {
    let exercise: Exercise

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]

    @State private var confirmation: String?

    /// LE BLOC DE CE PASSAGE — le `LoggedExercise` où s'ancrent les séries de
    /// cette visite. ⚠️ Il ne se retrouve PAS par recherche dans la séance :
    /// deux passages sur le même exercice sont deux blocs, et une recherche
    /// par `exerciseID` les fusionnerait sans rien dire.
    @State private var bloc: LoggedExercise?

    /// LA CARD REWARD au banc vivant : le « … » du header la déclenche
    /// (FAKE, pour l'entraîner à l'œil sur la vraie page) — les vraies
    /// portes (fin d'exo ? fin de séance ?) ne sont pas tranchées.
    @State private var rewardShow = false
    /// ⚠️ **LA CHAÎNE DE FIN DE SÉRIE** (26-08). Ce qui se montre après une
    /// série, et la série qui l'a déclenchée — le panneau « Recommencer ? »
    /// attend qu'elle se referme (verdict §12 : « une fois la pill ou la pop-up
    /// Reward fermée, on affiche l'overlay avec la flamme »).
    @State private var pillGain: (gain: Int, total: Int)?
    @State private var issueEnCours: IssueSerie?
    /// LE RANG de la série qui a produit l'issue en cours — mémorisé au
    /// moment de la décision, jamais relu dans `sets` (l'écriture est
    /// différée de 0,55 s : une relecture changerait de valeur sous la card).
    /// `nil` quand la pop-up est ouverte par l'ATELIER et non par le jeu.
    @State private var rangIssue: Int?
    @State private var serieAPoser: FinishedSeries?
    /// Le variant montré — TOURNE à chaque ouverture (« des fois fais un
    /// autre variant ») : galet (le vrai verre saisissable sur le
    /// chiffre), puis néon (réf WWDC), puis halo (réf Apple). Part à 2 :
    /// la première ouverture avance sur 0 — le galet, la nouveauté d'abord.
    @State private var rewardVariant = 3
    private static let rewardStyles: [RewardStyle] =
        [.galet, .neon, .halo, .spotlight, .fire, .welcome]
    /// Le tour des vidéos pièce au banc `-rewardVideo` — les 5 recuites
    /// de la famille défilent, une par ouverture.
    @State private var rewardVideoTour = 0
    private static let rewardVideos = [
        "reward-piece-1", "reward-piece-2", "reward-piece-3",
        "reward-piece-4", "reward-piece-5"
    ]
    /// LE DÉCLENCHEUR PROVISOIRE (`-rewardFlow`) — l'avant-goût du vrai
    /// moteur : chaque série RÉGLÉE sur la fiche (le chemin « Non » du
    /// panneau — relancer direct ne montre rien, la philosophie du plan)
    /// ouvre la robe suivante, une sur cinq porte une vidéo. JETABLE le
    /// jour où le flow end-to-end branche le vrai moteur.
    @State private var rewardFlowTour = -1
    @State private var rewardVideoNomCourant: String?

    /// LA DÉMO ENCHAÎNÉE (`-rewardDemo`) : chaque « Close » ouvre la
    /// card SUIVANTE — les 4 robes nues puis halo avec chacune des 8
    /// vidéos, en boucle. Pour montrer la famille entière en live.
    /// Part à 4 : la démo OUVRE sur la chauve-souris à la pièce
    /// (halo + reward-piece-1), puis Close déroule le reste.
    @State private var rewardDemoTour = 4
    /// (Le spotlight est SORTI du cycle — verdict « trop cheap » : sa
    /// refonte complète est un chantier à part, il reste au `-spotLab`.)
    private static let rewardDemoCombos: [(RewardStyle, String?)] = [
        (.galet, nil), (.neon, nil), (.halo, nil),
        (.halo, "reward-piece-1"), (.halo, "reward-piece-2"),
        (.halo, "reward-piece-3"), (.halo, "reward-piece-4"),
        (.halo, "reward-piece-5"), (.halo, "reward-fire"),
        (.halo, "reward-lune"), (.halo, "reward-rare"),
        // Le combo demandé le 26-08 : la robe spotlight (matrice) AVEC
        // une vidéo en header — pour juger le mariage.
        (.spotlight, "reward-piece-3")
    ]

    private func ouvrirComboDemo() {
        let c = Self.rewardDemoCombos[
            rewardDemoTour % Self.rewardDemoCombos.count]
        rewardVariant = Self.rewardStyles.firstIndex(of: c.0) ?? 2
        rewardVideoNomCourant = c.1
        rewardShow = true
    }

    private func declencherRewardFlow() {
        guard CommandLine.arguments.contains("-rewardFlow") else { return }
        rewardFlowTour += 1
        let tour = rewardFlowTour
        // Après la volée de pièces : la card arrive sur une fiche posée.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            if tour % 5 == 4 {
                rewardVariant = 2
                rewardVideoNomCourant = Self.rewardVideos[
                    (tour / 5) % Self.rewardVideos.count]
            } else {
                rewardVariant = tour % Self.rewardStyles.count
                rewardVideoNomCourant = nil
            }
            rewardShow = true
        }
    }

    // Le brouillon. Il vivait dans la feuille modale ; c'est désormais l'état de
    // la page elle-même. On part de ZÉRO série : la première naît du geste de
    // lancement, elle n'attend pas déjà là.
    @State private var sets: [DraftSet] = []
    @State private var restSeconds = 60
    @State private var phases: [DraftPhase] = [
        DraftPhase(kind: .repos, seconds: 30, speed: 6),
        DraftPhase(kind: .acceleration, seconds: 30, speed: 16)
    ]
    @State private var repeatCount = 1
    @State private var steadySeconds = 900
    @State private var steadySpeed: Double = 7
    @State private var incline: Double = 0

    /// Ce que la lumière du galet a déjà versé sur la page [0,1] — écrit
    /// par la fiche depuis la montée du doigt : le fond blanchit TRÈS
    /// vite, bien avant l'entrée de la bulle.
    @State private var flood: Double = 0

    /// LE GESTE UNIQUE : le doigt du galet, transmis vivant à la lentille
    /// (sa cinquième prise). Tant qu'il vit, c'est LUI qui porte la bulle
    /// du monde blanc — un seul geste, de la nuit au sommet.
    @State private var lensHandoff: LiquidLensLab.Handoff?
    /// Le battement du montage — l'haptique du dôme d'avant, au moment où
    /// la lentille entre.
    @State private var launchBeat = 0
    /// La taille plein écran, mémorisée pour le banc (les points de doigt
    /// synthétiques parlent l'espace de la lentille).
    @State private var pageFull = CGSize(width: 402, height: 874)

    /// La montée de la lentille (0 bord bas → 1 sommet) depuis un y plein
    /// écran — LE MÊME barème que `climbOf` du lab : les deux mondes
    /// mesurent le doigt avec la même règle. PIÈGE PAYÉ : h = 0 (une
    /// géométrie photographiée avant le premier layout) faisait un NaN
    /// qui empoisonnait `flood`, l'opacité du voile ET tous les uniforms
    /// du shader — le galet mourait pour toujours, sans un cri.
    private static func climbGlobal(y: CGFloat, h: CGFloat) -> Double {
        min(max(Double((h * 0.90 - y) / max(h * 0.72, 1)), 0), 1.06)
    }

    /// LES TROIS TEMPS du geste (verdict : « on doit voir le galet de la
    /// page exo monter ») : temps 1, la MONTÉE VISIBLE SUR LA NUIT —
    /// climb 0 → 0,14, le voile ne fait que se réchauffer (≤ 13 %) ;
    /// temps 2, l'AUBE — 0,14 → 0,22, le blanc verse sur ~50 pt de doigt,
    /// un battement qu'on VOIT ; temps 3, le RELAIS — la bulle, révélée
    /// en fondu papier-sur-papier, continue le galet sous le même doigt.
    ///
    /// La lentille est PRÉ-MONTÉE invisible à 0,10 : son shader chauffe
    /// sous la nuit, sa première frame ne coûte rien en plein geste —
    /// le hoquet du montage est mort.
    private static let mountClimb = 0.10
    private static let nightEnd = 0.14
    private static let dawnEnd = 0.22

    /// La montée courante du doigt, la révélation (en HYSTÉRÉSIS :
    /// montrée à 0,22, cachée sous 0,17 — la plongée est réversible sous
    /// le doigt), et le sommet (après lui, plus aucun retour ne s'arme).
    @State private var driveClimb: Double = 0
    @State private var lensShown = false
    @State private var summited = false
    /// Le drag de retour en cours : son point de départ (y global).
    @State private var returnFrom: CGFloat?

    // MARK: Le dépliement de la carte des séries

    /// LE CURSEUR DE LA CARTE (0 fermée → 1 ouverte) — et c'est LUI le
    /// moteur, pas le scroll. Trois essais ont échoué à faire TENIR la
    /// carte tant que le scroll la pilotait : son élastique, son inertie
    /// et son aimant reprennent toujours la main (« ça tient toujours
    /// pas »). La grammaire est désormais celle, éprouvée, de la carte
    /// dépliable du profil : un curseur à soi, un drag à soi, une butée
    /// et un aimant à soi. Rien d'autre ne peut y toucher.
    @State private var carteP: CGFloat = 0
    /// Le p au début du geste — la carte se tire depuis n'importe où.
    @State private var carteBase: CGFloat = 0
    /// La prise en main : l'haptique une fois, et le geste qui vit.
    @State private var carteSaisie = false
    /// LA CARTE EN COURSE — vrai du premier point du doigt jusqu'à la fin
    /// du ressort. Tout ce qui coûte cher et ne se voit pas en mouvement
    /// s'efface tant qu'il est vrai : la parure du bijou, la cadence de
    /// ses bruits, les écritures d'état par image. C'est LA réponse au
    /// « pas hyper fluide » — un mouvement n'a pas besoin de détail, il a
    /// besoin d'images.
    /// L'OUVERTURE RETARDÉE (17-08) — la parallaxe du verre. Elle suit
    /// `carteP` avec un ressort mou : pendant la course elle est EN RETARD
    /// sur la carte, et c'est cet écart qui décale les lumières
    /// intérieures. À l'arrêt les deux se rejoignent, l'écart tombe à zéro
    /// et l'image au repos est exactement celle d'avant.
    @State private var carteLag: CGFloat = 0

    @State private var carteBouge = false
    /// Le jeton du retour au calme : seule la dernière course éteint la
    /// lumière (deux gestes rapprochés ne se coupent pas l'herbe sous le
    /// pied).
    @State private var carteBougeJeton = 0
    /// LE CRANTAGE du geste : le cinquième de course franchi. La carte
    /// crante sous le doigt comme un tiroir — dans les deux sens.
    @State private var carteCran = 0
    /// Le point de bascule déjà franchi (là où lâcher installerait la
    /// carte) : on le SENT passer, c'est ce qui rend le geste sûr.
    @State private var carteFranchi = false
    /// Le rapport largeur/hauteur de la photo — lu UNE fois au montage :
    /// la loi du zoom interne en a besoin, jamais pendant le scroll.
    @State private var heroAspect: CGFloat = 0.8
    /// La photo au repos : 225 (« réduis encore les images », 13 août) —
    /// c'était 285.
    // §2.17 (le compactage de la card) : 225 était taillé pour la page
    // plein écran (759 pt) ; dans la GROSSE CARD (§2.15, ~640 pt), la
    // carte des séries frôlait le dôme (2 pt d'air mesurés au sim,
    // chevauchement au tel). La photo cède 50 pt, tout le header suit
    // (photo, titre, carte, PanneauMesures — ils lisent tous heroCap ou
    // expandedHeader).
    private static let heroCap: CGFloat = 175
    /// La course du geste, en points de scroll. 140 au temps de la
    /// vignette ; le DÉPLIEMENT de la carte des séries (15-08) mérite
    /// plus long — la croissance se savoure sous le doigt.
    private static let collapseSpan: CGFloat = 220
    /// La hauteur de la DALLE NOIRE fermée — mesurée au premier layout
    /// (la valeur de départ n'est qu'une estimation raisonnable) : c'est
    /// la base du lerp de croissance de la carte.
    @State private var carteFermeeH: CGFloat = 89
    /// Le liseré de lumière : l'aurora qui affleure autour de la dalle.
    /// FIN (1 pt) sur les côtés et en bas — c'est en HAUT que la lumière
    /// a le droit de prendre de la place (verdict du 15-08, réf. Linear).
    private static let liseré: CGFloat = 1
    /// LE BANDEAU d'aurora, carte fermée : plus un liseré, un vrai
    /// bandeau — il porte la poignée et l'inscription « Training ».
    /// 48 → 42 (16-08, Phase 1 restauration) : la référence mesure la
    /// carte fermée à ~127 pt (ratio 2,83:1) — le bandeau rend 6 pt,
    /// padV rend les 8 autres (FlammeJauge).
    private static let bande0: CGFloat = 40

    // MARK: - Le banc de RESTAURATION du verre (`-verreLab`, 16-08)
    //
    // La photo woodchopper meurt, remplacée par le HUD de réglage ; le
    // galet dort (sa lumière crème polluerait les modes OUTSIDE/×16) ;
    // le CALQUE — la référence de Kathryn recalée sur la géométrie de la
    // carte — se superpose en live. Trois commandes : M cycle les 5 modes
    // du shader, C l'opacité du calque (0→25→50→75→100→0), B le blink
    // 250 ms. `-verreMode <0-4>` et `-calque <0-1>` posent l'état initial.
    private static let verreLab = CommandLine.arguments.contains("-verreLab")
    private static let verreMode0: Int = {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: "-verreMode"), i + 1 < a.count,
              let v = Int(a[i + 1]) else { return 0 }
        return min(max(v, 0), 4)
    }()
    private static let calque0: Double = {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: "-calque"), i + 1 < a.count,
              let v = Double(a[i + 1]) else { return 0 }
        return min(max(v, 0), 1)
    }()
    /// La référence, lue depuis le dépôt (le simulateur lit le disque de
    /// l'hôte ; sur téléphone elle est simplement absente).
    private static let calqueImage = UIImage(contentsOfFile:
        "/Users/kathryn/Desktop/woochoper-ios/tools/verre/reference-card.png")
    private static let verreModeNoms = ["FINAL", "SDF", "IN", "OUT", "×16"]
    @State private var verreMode = ExerciseDetailView.verreMode0
    @State private var calqueOp = ExerciseDetailView.calque0
    @State private var calqueBlink = false

    /// LA NORME MENTIE (le piège du profil, payé une fois pour toutes) :
    /// le shader `banniereHalos` normalise TOUT par sa hauteur. L'écrin
    /// fermé ne fait qu'une centaine de points — à cette échelle les
    /// halos seraient gigantesques et le haut partirait en blanc soufflé.
    /// On lui donne donc une hauteur de RÉFÉRENCE (celle d'une bannière
    /// de profil) qui ne grandit qu'à 55 % de la course : la lumière
    /// reste en haut, le bas de la carte ouverte redevient braise.
    private static func normeEcrin(_ h: CGFloat) -> CGFloat {
        let base: CGFloat = 230
        return base + 0.55 * max(0, h - base)
    }
    /// La place réservée en tête du scroll (photo + titre étendus) : FIXE.
    /// Le header se dessine en OVERLAY au-dessus — un inset qui changerait
    /// de hauteur re-layouterait le scroll à chaque frame (la loi de la
    /// maison : on anime en offset, jamais la place réservée).
    /// 118 : le bloc titre en consomme ~96 — le reste est l'air entre le
    /// sous-titre et la flamme (« espace plus », 14 août).
    /// ⚠️ Plus `private` : `PanneauMesures.ancreCarteExo` la LIT pour ancrer
    /// la hauteur des panneaux-question sur le bord haut de la carte des
    /// séries. Un chiffre recopié là-bas et la couverture redeviendrait une
    /// coïncidence de modèle d'iPhone.
    static let expandedHeader: CGFloat = 12 + Self.heroCap + 8 + 118
    /// `-headerFreeze <y>` : fige la course vue par le header (le
    /// simulateur ne drague pas) — les poses du dépliement se capturent.
    private static let headerFreeze: CGFloat? = {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "-headerFreeze"),
              i + 1 < args.count,
              let v = Double(args[i + 1]) else { return nil }
        return CGFloat(v)
    }()
    /// La course en points — la partition du header et de la carte n'a pas
    /// changé de langue : elle lit toujours des points, le curseur les lui
    /// fournit.
    private var headerY: CGFloat {
        Self.headerFreeze ?? carteP * Self.collapseSpan
    }

    private static func lp(_ a: CGFloat, _ b: CGFloat,
                           _ u: Double) -> CGFloat {
        a + (b - a) * CGFloat(u)
    }
    /// Le point précédent du doigt — la poussière sonore se sème à la
    /// DISTANCE parcourue, jamais au temps.
    @State private var lastDrive: CGPoint?

    private static func sstep(_ a: Double, _ b: Double,
                              _ x: Double) -> Double {
        let u = min(max((x - a) / (b - a), 0), 1)
        return u * u * (3 - 2 * u)
    }

    /// L'avancement de l'aube, et la caméra qui en découle.
    private var dawn: Double {
        Self.sstep(Self.nightEnd, Self.dawnEnd, driveClimb)
    }
    /// `8^(u²)` : part lentement, accélère fort — la grammaire des deux
    /// plongées déjà validées (8^(u^1,8) connexion, 8^(u^2,05) sommet).
    private var dive: Double {
        lensShown ? 8.0 : pow(8.0, dawn * dawn)
    }
    /// Le battement de blanc qui cache la coupe : une cloche brève autour
    /// de la fin de plongée, au-dessus de tout — le marron y est
    /// impossible, et la couture aussi. Il n'existe que tant que le geste
    /// vit : le ressort du retour repasserait par la cloche, et un éclair
    /// fantôme signerait l'abandon.
    private var flashA: Double {
        guard running != nil, !lensShown else { return 0 }
        let bell = max(0.0, 1.0 - abs(dawn - 0.90) / 0.10)
        return 0.9 * bell * bell
    }


    /// La série en cours d'exécution au compteur, s'il y en a une. Un `item:`
    /// plutôt qu'un booléen : c'est l'indice qui porte l'information, et il ne
    /// peut pas se désynchroniser.
    @State private var running: RunningSeries?

    private struct RunningSeries: Identifiable {
        let id: Int
        /// La série a été CRÉÉE par ce lancement (et non reprise) : si le
        /// doigt abandonne avant la révélation de la bulle, on la défait.
        var appended = false
    }

    /// LA SÉRIE TERMINÉE, entre l'envol et le retour : ce que la pastille a
    /// remporté en partant. Tant qu'il est non-nil, la page BRAVO est posée ;
    /// son retour écrit ces chiffres dans la carte — pas avant : la carte
    /// s'actualise sous les yeux, à l'air libre, jamais sous une page.

    private struct FinishedSeries {
        let index: Int
        let reps: Int
        let kilos: Double
        let rest: Int
        let seconds: Int
    }

    /// LA QUESTION DU RETOUR. Après BRAVO, le panneau « Recommencer ? »
    /// porte la série vécue tant qu'il est à l'écran — l'écriture dans la
    /// carte attend sa SORTIE : c'est elle qu'on regarde (les pièces, le
    /// compte), et le panneau qui descend la découvre.
    @State private var restartAsk: FinishedSeries?
    /// La volée de pièces vers la carte Série : l'instant du départ.
    @State private var coinsAt: Date?
    /// La carte Série en repère global — la cible des pièces.
    @State private var seriesCardFrame: CGRect = .zero
    /// Le prochain montage du cadran naît POSÉ (le bouton du panneau) —
    /// pas de plongée, un 3-2-1 à la place.
    @State private var posedLaunch = false

    private var active: Workout? { workouts.first { $0.isActive } }
    private var isStrength: Bool { exercise.tracking == .setsRepsWeight }

    // MARK: Le banc de l'aube — le simulateur ne drague pas (l'école -cineTest)

    /// `-aubeAuto` rejoue en boucle la montée de lumière du galet, sans
    /// jamais déclencher ; `-aubeFire` joue UNE traversée complète (aube →
    /// pose de la lentille → retour à la nuit) ; `-aubeFreeze <u>` fige la
    /// course à u ∈ [0,1] pour les captures. Sans argument : inertes.
    /// `-carteAuto` rejoue la course de la carte EN BOUCLE, exactement
    /// comme un doigt : `carteP` écrit à chaque image, sans animation —
    /// c'est le seul régime où le corps de la page se réévalue à chaque
    /// frame (un `withAnimation`, lui, ne l'évalue qu'UNE fois et anime
    /// le rendu : il ne mesure rien). La cadence se compte au film.
    private static let carteAuto = CommandLine.arguments.contains("-carteAuto")
    /// `-serieFin <n>` — le banc de la chaîne de fin de série.
    private static let serieFinBanc: Int? = {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: "-serieFin"), i + 1 < a.count,
              let n = Int(a[i + 1]) else { return nil }
        return max(1, n)
    }()
    /// `-carteLourd` : la course SANS les allègements (parure et cadence
    /// pleines) — le témoin de l'A/B, la seule façon de prouver que les
    /// allègements servent à quelque chose sur une machine chargée.
    private static let carteLourd =
        CommandLine.arguments.contains("-carteLourd")

    private func runCarteBench() async {
        guard Self.carteAuto else { return }
        try? await Task.sleep(for: .seconds(2))
        carteBouge = true
        let t0 = Date()
        while !Task.isCancelled {
            let ph = Date().timeIntervalSince(t0)
                .truncatingRemainder(dividingBy: 3.6)
            let u: Double
            if ph < 1.5 { u = ph / 1.5 }
            else if ph < 1.9 { u = 1 }
            else if ph < 3.4 { u = 1 - (ph - 1.9) / 1.5 }
            else { u = 0 }
            carteP = CGFloat(u * u * (3 - 2 * u))
            suivreLeRetard(carteP)
            try? await Task.sleep(for: .milliseconds(8))
        }
    }

    private static let aubeAuto = CommandLine.arguments.contains("-aubeAuto")
    private static let aubeFire = CommandLine.arguments.contains("-aubeFire")
    private static let aubeFreeze: Double? = {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "-aubeFreeze"), i + 1 < args.count,
              let v = Double(args[i + 1]) else { return nil }
        return min(max(v, 0), 1)
    }()

    private func runAubeBench() async {
        // `-restartFire` : le panneau « Recommencer ? » se monte seul
        // (le simulateur ne revient pas de BRAVO au doigt) ;
        // `-restartAuto` le referme à 3 s (la volée de pièces se filme) ;
        // `-restartLaunch` appuie sur « Lancer » à 3 s (la porte posée).
        // `-series10` (banc, 16-08) : dix séries d'un coup, pour voir le
        // scroll de la carte dépliée avec une liste qui déborde vraiment.
        // La carte reste FERMÉE — c'est elle qui l'ouvre au doigt.
        if let i = CommandLine.arguments.firstIndex(of: "-series"),
           i + 1 < CommandLine.arguments.count,
           let n = Int(CommandLine.arguments[i + 1]), n > 0 {
            try? await Task.sleep(for: .seconds(0.4))
            if sets.isEmpty {
                for k in 0..<n {
                    sets.append(DraftSet(reps: 12, weight: 20,
                                         isDone: k < 3))
                }
            }
        }
        // ⚠️ LE BANC DE LA CHAÎNE DE FIN DE SÉRIE : `-serieFin <n>` rejoue
        // l'issue de la n-ième série — 1 la pill, 3 le Moment, 5 la pop-up,
        // 10 le cas rare avec sa vidéo. Le simulateur ne sait pas faire une
        // série ; sans ce banc, la chaîne n'est jugeable que sur l'appareil.
        if let n = Self.serieFinBanc {
            try? await Task.sleep(for: .seconds(1.4))
            if sets.isEmpty {
                for k in 0..<max(n, 1) {
                    sets.append(DraftSet(reps: 12, weight: 20, isDone: k < n - 1))
                }
            }
            let f = FinishedSeries(index: max(n - 1, 0), reps: 12, kilos: 20,
                                   rest: 60, seconds: 47)
            serieAPoser = f
            // ⚠️ **LE BANC DOIT PORTER LE RANG, LUI AUSSI.** Sans cette ligne
            // il retombait sur le plancher d'atelier (4) et n'aurait pas
            // montré le vrai compte — un banc qui ne reproduit pas le jeu ne
            // peut rien en révéler, et c'est exactement ce qui a laissé vivre
            // le décalage d'un rang (voir `finirSerie`).
            rangIssue = n
            jouerIssue(DecideurSerie.pour(serie: n, gain: gainParSerie,
                                          total: n * gainParSerie,
                                          reps: f.reps, kilos: f.kilos), f,
                       banc: true)
            return
        }
        if CommandLine.arguments.contains("-restartFire") {
            try? await Task.sleep(for: .seconds(1.4))
            if sets.isEmpty {
                sets.append(DraftSet(reps: 12, weight: 20))
            }
            let ask = FinishedSeries(index: 0, reps: 12, kilos: 20,
                                     rest: 60, seconds: 47)
            restartAsk = ask
            if CommandLine.arguments.contains("-restartAuto") {
                try? await Task.sleep(for: .seconds(3))
                exitRestart(ask, thenLaunch: false)
            } else if CommandLine.arguments.contains("-restartLaunch") {
                try? await Task.sleep(for: .seconds(3))
                exitRestart(ask, thenLaunch: true)
            }
            return
        }
        if let u = Self.aubeFreeze { flood = u; return }
        guard Self.aubeAuto || Self.aubeFire else { return }
        try? await Task.sleep(for: .seconds(2))
        // Le doigt synthétique parle l'espace plein écran, comme le vrai :
        // y depuis la montée voulue, par le MÊME barème (climbGlobal⁻¹).
        func point(at climb: Double) -> CGPoint {
            CGPoint(x: pageFull.width / 2
                        + 18 * sin(climb * 7.0),
                    y: pageFull.height * 0.90
                        - climb * pageFull.height * 0.72)
        }
        if Self.aubeFire {
            // LE GESTE UNIQUE, sans doigt : la montée traverse la nuit,
            // le blanc, l'entrée de la bulle et file au SOMMET — toute la
            // partition (coupe, descente, chrono) s'enchaîne d'elle-même.
            // Un vrai doigt ne bouge pas pendant un hoquet : le banc
            // marque le même temps d'arrêt après le seuil de montage.
            var t0 = Date()
            var held = false
            var c = 0.0
            while !Task.isCancelled {
                let u = Date().timeIntervalSince(t0) / 3.4
                if u >= 1 { break }
                let e = u * u * (3 - 2 * u)
                // Un doigt SAVOURE la plongée : dans la zone de l'aube,
                // la montée est plafonnée à ~0,10/s — le film montre ce
                // que la main vivra.
                let maxStep = (c > 0.11 && c < 0.25) ? 0.0017 : 0.03
                c = min(e, c + maxStep)
                driveMoved(point(at: c), -1400)
                if !held, running != nil {
                    held = true
                    try? await Task.sleep(for: .milliseconds(280))
                    t0 = t0.addingTimeInterval(0.28)
                }
                try? await Task.sleep(for: .milliseconds(16))
            }
            driveMoved(point(at: 1.0), -1400)
            // LE RELAIS PEUT RATER À LA RELANCE. Si la lentille s'est montée
            // trop tard (relance plus lente que le premier lancement — mesuré :
            // install fraîche OK, terminate+launch bloqué au monde blanc,
            // bulle au repos), le doigt synthétique a fini son œuvre avant
            // qu'elle ne l'entende : le `handoff` ne change plus, elle ne
            // saura jamais. Le banc rejoue donc la fin de la montée jusqu'à
            // ce que le sommet soit PRIS — un vrai doigt, lui, insisterait.
            var tries = 0
            while !summited, tries < 6, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(400))
                for k in 0...10 {
                    driveMoved(point(at: 0.5 + 0.05 * Double(k)), -1400)
                    try? await Task.sleep(for: .milliseconds(16))
                }
                tries += 1
            }
            driveEnded(point(at: 1.0), 0)
        } else {
            // La boucle de l'aube : montée SOUS le seuil de la bulle,
            // retombée, silence — le voile respire, rien ne se monte.
            let t0 = Date()
            while !Task.isCancelled {
                let ph = Date().timeIntervalSince(t0)
                    .truncatingRemainder(dividingBy: 5.6)
                let r = min(max((ph - 1.6) / 1.3, 0), 1)
                let f = min(max((ph - 3.4) / 0.7, 0), 1)
                // Sous le seuil de pré-montage : l'aube seule, jamais
                // la bulle.
                let c = 0.08 * (r * r * (3 - 2 * r))
                    * (1 - f * f * (3 - 2 * f))
                if ph < 4.4 {
                    driveMoved(point(at: c), -600)
                } else if flood > 0 {
                    driveEnded(point(at: 0), 0)
                }
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    /// La silhouette de la carte noire : coins hauts seulement — elle file
    /// bord à bord et jusqu'en bas d'écran, comme la référence.
    private static let pageShape = UnevenRoundedRectangle(
        cornerRadii: .init(topLeading: 40, bottomLeading: 0,
                           bottomTrailing: 0, topTrailing: 40),
        style: .continuous)

    var body: some View {
        // LE PLAYER EN CARD (T1, plan tools/player/PLAN-PLAYER-CARD.md) : en
        // séance, la fiche devient LA CARD que le player pousse — la dalle en
        // bas sous le galet, le fantôme du haut est mort. Sans séance, la
        // page nue. L'arbitrage avec le drag de la carte des séries est
        // STRUCTUREL : pendant la levée, la page devient un snapshot mort —
        // ses gestes n'existent plus.
        // LE LAYOUT UNIVERSEL (§2.14) : la fiche est TOUJOURS la card — en
        // séance le player dessous, hors séance le trait + LA LUNE.
        PageCard(dockH: 86,
                 // Le banc du DÉPLIÉ RÉEL (§2.16) : `-pageCardLevee` fige la
                 // levée de la vraie fiche pour les captures — le bandeau du
                 // bug B était INVISIBLE aux sondes sans doigt.
                 leveeInitiale: PageCardBanc.leveeFigee ?? 0,
                 enSeance: active != nil,
                 // §2.17 : LE PLAYER N'ARRIVE JAMAIS pendant la plongée du
                 // galet (`flood` monte dès le drive) ni pendant la série
                 // (`running`, la lentille et son chrono) — la bande
                 // disparaît, la card prend presque tout.
                 bandeVisible: running == nil && flood < 0.01,
                 page: { pageContenu },
                 dalle: { l in dallePlayer(l) },
                 detail: { l in scenePlayer(l) },
                 pied: { l in piedPlayer(l) })
        // §2.19 : LE MONDE FLOTTANT AU-DESSUS DE LA CARD — plein écran
        // physique (ses `ignoresSafeArea` internes redeviennent opérants
        // ici ; pas d'`ignoresSafeArea` global : le panneau ancré LIT ses
        // insets — l'école du calendrier).
        .overlay { mondeFlottant }
        // ⚠️ LA BARRE SYSTÈME SE CACHE ICI, SUR LE BODY (§2.16, bug B payé
        // au tel 31-08 : « toujours le bandeau noir quand je monte ») : ces
        // préférences vivaient DANS `pageContenu` — le slot que PageCard
        // DÉMONTE dès la prise (remplacé par le snapshot). Démontées, la
        // nav bar Liquid Glass revenait (le bandeau noir, son chevron) et
        // décalait le cadre en plein geste. Le body, lui, ne se démonte
        // jamais.
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: - Le player en card (T1)

    @Environment(\.dismiss) private var fermerFiche
    /// Le dépliage de la partition (la loi de SlateListe : chez l'hôte).
    @State private var playerDeplies: Set<String> = ["courant"]
    /// LES GROUPES FIGÉS — une visite SwiftData par OUVERTURE du player
    /// (l'onAppear de la scène), jamais par image.
    @State private var playerGroupes: [SlateGroupe] = []

    private func dallePlayer(_ levee: CGFloat) -> some View {
        WorkoutPill(exercise: exercise,
                    progress: sets.isEmpty ? 0
                        : Double(sets.filter(\.isDone).count)
                            / Double(sets.count),
                    startedAt: active?.startedAt,
                    docked: true,
                    lisere: false,
                    doneSeries: sets.filter(\.isDone).count,
                    exoCount: 1 + (active?.orderedExercises
                        .filter { $0.exerciseID != exercise.id }
                        .count ?? 0),
                    stopVisible: levee < 0.03,
                    jour: active?.startedAt ?? .now,
                    // TODO : le sticker RÉEL du jour (le moteur de faits).
                    jourSticker: "sticker-flamme",
                    jourVisible: levee < 0.03,
                    titreCourant: exercise.name,
                    hauteurDock: 86)
            // LA DALLE SE TAIT PENDANT LE VOL (verdict T1 : « on voit le
            // mini player dans le player déplié ») — son titre renaît dans
            // la scène. L'opacité n'éteint pas le hit : le geste reste.
            .opacity(Double(1 - min(1, levee * 2.2)))
    }

    private func scenePlayer(_ levee: CGFloat) -> some View {
        ScenePlayer(levee: levee, titre: exercise.name,
                    groupes: playerGroupes, deplies: $playerDeplies)
            .onAppear { playerGroupes = groupesSeance() }
    }

    private func piedPlayer(_ levee: CGFloat) -> some View {
        PiedPlayer(levee: levee,
                   jour: active?.startedAt ?? .now,
                   sticker: "sticker-flamme",
                   setsFaits: sets.filter(\.isDone).count,
                   stopActif: true,
                   onStop: {
                       // LE MÊME CHEMIN que le stop de la dalle : l'état
                       // global → StopCardHote (la pop-up stop, racine).
                       withAnimation(.spring(response: 0.42,
                                             dampingFraction: 0.86)) {
                           DepartEtat.shared.pauseOuverte = true
                       }
                   },
                   pageExosActif: true,
                   onPageExercices: { fermerFiche() })
    }

    /// La partition réelle : l'exercice courant (ses brouillons) d'abord,
    /// puis les autres exercices de la séance — le barème de l'ardoise.
    private func groupesSeance() -> [SlateGroupe] {
        var courant: [SlateLigne] = sets.map {
            SlateLigne(reps: $0.reps, kilos: $0.weight,
                       seconds: $0.isDone ? $0.durationSeconds : restSeconds,
                       done: $0.isDone)
        }
        if courant.isEmpty {
            courant.append(SlateLigne(reps: 12, kilos: 20,
                                      seconds: restSeconds, done: false))
        }
        var out = [SlateGroupe(id: "courant", exercise: exercise,
                               rows: courant)]
        for le in active?.orderedExercises ?? []
        where le.exerciseID != exercise.id {
            guard let exo = le.exercise, !le.orderedSets.isEmpty
            else { continue }
            out.append(SlateGroupe(
                id: le.exerciseID, exercise: exo,
                rows: le.orderedSets.map {
                    SlateLigne(reps: $0.reps, kilos: $0.weight,
                               seconds: $0.isDone ? $0.durationSeconds
                                                  : le.restSeconds,
                               done: $0.isDone)
                }))
        }
        return out
    }

    /// LE CONTENU DE LA PAGE — la fiche elle-même (l'ancien `body`).
    private var pageContenu: some View {
        GeometryReader { geo in
            // LA CARTE NOIRE, désormais RÉSERVÉE AU CARDIO : pleine largeur,
            // grands coins hauts, elle s'inscrit sur la braise et coupe le
            // scroll sur sa silhouette — jamais un pixel de contenu ne remonte
            // sur l'orange. La musculation ne défile pas : elle n'a rien à
            // couper, donc elle n'a plus de carte du tout. Le noir lui vient
            // du socle, en fond, comme à tout le monde.
            ZStack(alignment: .top) {
                if isStrength {
                    strengthPage
                } else {
                    cardioPage
                        .background(Self.pageShape.fill(Color.black))
                        .clipShape(Self.pageShape)
                }
            }
            // ⚠️ **LE PLAYER EST UN ÉTAT GLOBAL DE SÉANCE** (26-08, verdict
            // n° 1 : « lorsque je reviens sur la partie détail exercice sous
            // le galet, le player de session n'est plus visible —
            // conséquence directe : je n'ai plus aucun moyen de terminer la
            // session depuis cet écran »).
            //
            // Cette page n'en montait AUCUN (mesuré : zéro occurrence de
            // `WorkoutPill` dans le fichier, alors que la home, la page des
            // exercices, la card de réglage et l'ardoise en portent une).
            // Il est POSÉ EN OVERLAY, pas dans le flux : la page a déjà
            // deux `safeAreaInset` et une géométrie qu'on ne renégocie pas
            // pour un dock. Il descend sous les chips du header.
            //
            // Il porte la pilule FLOTTANTE (`docked: false`) et non la dalle :
            // ici il n'y a pas de bande découverte à habiter, et le verdict
            // « séance = le galet néon SEUL » vaut pour la HOME — la fiche
            // n'a pas de galet de séance à lui opposer.
            // (Le player-pilule du haut est MORT — T1, 30-08 : le player vit
            // désormais EN BAS, la dalle PageCard, comme partout. Le verdict
            // d'origine « aucun moyen de terminer la session depuis cet
            // écran » reste honoré : le stop vit dans la dalle.)
            // Le socle et la braise vivent en FOND, hors jeu de layout : la
            // carte-braise a déjà fait dérailler la largeur de la page une
            // fois — plus rien d'elle ne participe à la mise en page.
            .background {
                ZStack(alignment: .top) {
                    Color.black
                    // La braise se tait pendant la lentille : elle brûle à
                    // 30 Hz sous un plein écran qui, lui, tourne à 60.
                    // En muscu elle n'est plus ICI, en fond, mais AU-DESSUS,
                    // en lumière (l'overlay juste dessous) ; le cardio, qui
                    // garde sa carte noire, garde son feu derrière elle.
                    if !isStrength, running == nil { HeaderEmberCard() }
                }
                .ignoresSafeArea()
            }
            // LA LUMIÈRE DE LA PAGE — au-dessus du contenu, et c'est une
            // nécessité, pas une coquetterie. La photo est un fichier à fond
            // NOIR OPAQUE : posée par-dessus un feu de fond, elle y poinçonne
            // un rectangle noir de 240 pt de large, et le seul remède (fondre
            // son quart haut) effacerait la tête et les épaules du sujet. En
            // additif le problème n'existe pas : sur la nuit de la page le
            // noir du halo n'AJOUTE rien, et sur la photo la lumière se POSE
            // au lieu de masquer — le montant de la machine et l'épaule du
            // sujet prennent leur liseré chaud. Ce n'est plus un fond derrière
            // une image, c'est une source qui éclaire une scène.
            // Sous les chips et sous la carte Série : les deux `safeAreaInset`
            // sont appliqués après, leur verre fumé reste intact.
            // LE FOND DU HEADER — photo entière + grand titre, SOUS la
            // lumière : la photo est un fichier à fond noir opaque, elle
            // doit rester sous l'additif pour que la lumière se POSE sur
            // elle (au-dessus, elle poinçonne un rectangle noir dans
            // l'aurore — payé au premier retour de Kathryn).
            .overlay(alignment: .top) {
                // Au banc du verre, la photo meurt : sa place devient la
                // zone de réglage (le HUD), et rien ne pollue la nuit.
                if isStrength, !Self.verreLab { collapsingHeaderBack }
            }
            // (LES HALOS ORANGE DU HEADER SONT MORTS — 15-08, « ils font
            // cheap au-dessus de l'image ». La musculation n'a plus de
            // lumière posée sur sa photo : la seule source chaude de la
            // page est désormais l'ÉCRIN d'aurora de la carte des séries.
            // Le composant `ExoHeaderGlow` survit — le cardio et les
            // leçons de `GaletSlide` s'y réfèrent encore.)
            // LA CARTE DES SÉRIES — AU-DESSUS de la lumière (le sandwich
            // de la maison : glow < carte), sourde au doigt : le scroll
            // du dessous est le geste, le tap vit dans le flux.
            .overlay(alignment: .topLeading) {
                if isStrength { carteSeries }
            }
            // LA BANDE DE PRISE, posée APRÈS la carte pour gagner le doigt
            // sur elle : la carte ouverte rend son scroll à la liste des
            // séries, et sa tête reste l'endroit où on l'attrape.
            .overlay(alignment: .top) {
                if isStrength { priseCarteSeries }
            }
            // Le HUD du banc — AU-DESSUS de tout, et lui SEUL est
            // touchable (la carte des séries reste sourde au doigt).
            .overlay(alignment: .top) {
                if Self.verreLab { verreHud }
            }
            // La taille pour le banc — JAMAIS une géométrie d'avant le
            // premier layout (le zéro faisait le NaN ci-dessus).
            .onAppear {
                if geo.size.height > 100 {
                    pageFull = CGSize(
                        width: geo.size.width,
                        height: geo.size.height + geo.safeAreaInsets.top
                                + geo.safeAreaInsets.bottom)
                }
                // Les moteurs de la lentille chauffent ICI, à l'entrée de
                // la fiche : leur préparation au montage (session audio,
                // haptique) gelait l'app ~0,2 s en pleine plongée — le
                // hoquet mangeait l'aube. Des singletons : au montage,
                // leurs prepare() ne coûtent plus rien.
                RocketHaptics.shared.prepare()
                LensTheme.shared.prepare()
                LensChime.shared.prepare()
                Paillettes.shared.prepare()
                // Le rapport de la photo, UNE fois — la loi du zoom
                // interne du morphing le lit à chaque frame de scroll.
                if let img = UIImage(named: exercise.image) {
                    heroAspect = img.size.width / max(img.size.height, 1)
                }
            }
            .onChange(of: geo.size) { _, s in
                if s.height > 100 {
                    pageFull = CGSize(
                        width: s.width,
                        height: s.height + geo.safeAreaInsets.top
                                + geo.safeAreaInsets.bottom)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) { headerChips }
            // LE GALET DEVANT LA CARD (§2.14/§2.16 fix A) : un OVERLAY,
            // plus un `safeAreaInset` — il ne RÉSERVE plus ses 160 pt de
            // layout, il FLOTTE devant le contenu au bas de la card (son
            // drag gagne toujours : l'overlay est au-dessus au hit-test).
            // La carte des séries OUVERTE compense ses 160 pt elle-même
            // (voir `carteSeries`) pour garder le même bas qu'avant.
            .overlay(alignment: .bottom) {
                if isStrength {
                    VStack(spacing: 0) {
                        // LA BULLE DE LA LENTILLE, du côté de la nuit :
                        // même course, même écriture de `flood` que le
                        // dôme qu'elle remplace — mais le verre est le
                        // VRAI (le shader de la lentille, appelé avec les
                        // nombres de son repos). Bord à bord, elle déborde
                        // jusqu'au bord physique de l'écran.
                        // Au banc du verre : le galet dort — sa lumière
                        // crème inonderait les modes OUTSIDE et ×16.
                        if Self.verreLab {
                            Color.clear.frame(height: 10)
                        } else {
                            LaunchPebble(
                                label: "Start exercise",
                                flood: $flood,
                                // LE PANNEAU L'ENDORT AUSSI. Le sommeil du
                                // galet ne connaissait que `running` — or la
                                // fin de série met justement `running` à nil
                                // en rendant la fiche : le galet se RÉVEILLAIT à
                                // l'instant exact où la page lance ses trois
                                // lecteurs, et rejouait ses 4 s de renaissance
                                // (quatre passes hors écran sur 2,23 Mpx à
                                // 30 Hz) sous un plein écran NOIR OPAQUE. Du
                                // remplissage strictement invisible, pendant
                                // les 4 secondes les plus chargées de l'app.
                                // La leçon est déjà écrite dans la maison :
                                // le ciel de la home tournait derrière le
                                // splash, et le remède fut de ne pas monter,
                                // jamais de masquer.
                                // (`finished` est mort avec la page BRAVO :
                                // le panneau « Recommencer ? » ne couvre pas
                                // le fond, il se pose dessus.)
                                asleep: running != nil || restartAsk != nil,
                                onDrive: { p, vy in driveMoved(p, vy) },
                                onRelease: { p, vy in driveEnded(p, vy) },
                                onLaunch: launch
                            )
                        }
                    }
                }
            }
            // Le cardio, lui, garde sa RÉSERVATION : `primaryAction`
            // participe au layout de sa page — hors périmètre §2.16.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !isStrength { primaryAction }
            }
        }
        // LA PLONGÉE DANS LE GALET — la troisième caméra de la maison
        // (connexion → la lune ; sommet → la pastille ; ici → le galet).
        // Zoom exponentiel ancré sur son cœur, PILOTÉ PAR LE DOIGT : tu
        // recules, la caméra recule — réversible jusqu'à la coupe. Le
        // voile, le flash et la lentille vivent AU-DESSUS du sous-arbre
        // zoomé, nets pendant que la page plonge.
        .scaleEffect(dive, anchor: UnitPoint(x: 0.5, y: 0.84))
        .task { await runAubeBench() }
        .task { await runCarteBench() }
        // Le banc de la card reward : `-rewardAuto` l'ouvre seul après un
        // battement (le simulateur n'a pas de doigt pour le chip), et la
        // rejoue en boucle ouverte→fermée pour filmer l'aller-retour.
        .task {
            guard CommandLine.arguments.contains("-rewardAuto") else { return }
            // C'est le popup qui joue SA sortie (il s'auto-ferme sous le
            // même argument) — la démonter d'ici serait une coupe sèche.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.4))
                rewardVariant = (rewardVariant + 1) % Self.rewardStyles.count
                rewardShow = true
                try? await Task.sleep(for: .seconds(6.0))
            }
        }
        // Le banc du spotlight (jalon S1) : `-spotLab` ouvre la robe
        // spotlight SEULE, sans fermeture auto — l'atelier de la matrice
        // (comparaison `-spotAlea` sur captures).
        .task {
            guard CommandLine.arguments.contains("-spotLab") else { return }
            try? await Task.sleep(for: .seconds(1.0))
            rewardVariant = 3
            rewardShow = true
        }
        // Le banc de la VIDÉO reward : `-rewardVideo` ouvre la card à
        // header vidéo (corps halo compacté), sans fermeture auto.
        .task {
            guard CommandLine.arguments.contains("-rewardVideo")
            else { return }
            try? await Task.sleep(for: .seconds(1.0))
            rewardVariant = 2
            rewardShow = true
        }
        // La DÉMO ENCHAÎNÉE : `-rewardDemo` ouvre la première card, et
        // chaque « Close » appelle la suivante (voir onClose).
        .task {
            guard CommandLine.arguments.contains("-rewardDemo")
            else { return }
            try? await Task.sleep(for: .seconds(1.0))
            ouvrirComboDemo()
        }
        // L'atelier FIRE : `-fireLab` (+ `-fireAuto` tape la flamme).
        .task {
            guard CommandLine.arguments.contains("-fireLab") else { return }
            try? await Task.sleep(for: .seconds(1.0))
            rewardVariant = 4
            rewardShow = true
        }
        // L'atelier WELCOME BACK robe TEXTE : `-welcomeTexte`.
        .task {
            guard CommandLine.arguments.contains("-welcomeTexte")
            else { return }
            try? await Task.sleep(for: .seconds(1.0))
            rewardVariant = 5
            rewardShow = true
        }
        // L'atelier WELCOME BACK : `-welcomeLab`.
        .task {
            guard CommandLine.arguments.contains("-welcomeLab")
            else { return }
            try? await Task.sleep(for: .seconds(1.0))
            rewardVariant = 5
            rewardShow = true
        }
        // L'atelier « You Made It » (le variant 2 refait) : `-ymiLab`
        // ouvre cette robe seule, sans fermeture auto.
        .task {
            guard CommandLine.arguments.contains("-ymiLab") else { return }
            try? await Task.sleep(for: .seconds(1.0))
            rewardVariant = 1
            rewardShow = true
        }
        // (Les trois `.toolbar(.hidden)` ont DÉMÉNAGÉ sur le body — §2.16
        // bug B : posés ici, ils mouraient avec le démontage du slot.)
        // L'appareil confirme la série en même temps que les paillettes partent.
        .sensoryFeedback(.success, trigger: sets.filter(\.isDone).count)
        // Le battement du montage : la lentille vient d'entrer sous le doigt.
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.9),
                         trigger: launchBeat)
    }

    /// LE MONDE FLOTTANT (§2.19) — le voile, le flash, la lentille et son
    /// chrono, la question « Recommencer ? », la pill, les pièces, la card
    /// reward : TOUT vit en overlay DU BODY, au-dessus de PageCard, PLEIN
    /// ÉCRAN PHYSIQUE — jamais dans la card (« des bordures noires SURTOUT
    /// PAS »). C'était l'overlay final de `pageContenu` : habillé en card
    /// avec elle, il naissait à ses marges et ses coins.
    /// LE RACCORD. La lumière du galet inonde la page pendant le geste —
    /// le verre chauffe sur la MÊME rampe que ce voile ; quand la
    /// lentille se pose, elle ouvre sur CE papier-là. Aucune transition
    /// n'est jouée : il n'y a rien à traverser, c'est la même lumière
    /// qui continue.
    private var mondeFlottant: some View {
            ZStack {
                if flood > 0.001 {
                    Self.paper
                        .opacity(floodVeil)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
                // (Ici vivaient des « stries de vitesse ». Un trait à
                // largeur constante et bords francs sur du noir n'est pas
                // de la lumière, c'est de l'ENCRE — la lecture BD était
                // juste. Toute la matière de la maison est un CHAMP, sans
                // bord : braise, halo, bloom, fil. Le spectaculaire de la
                // plongée, c'est le zoom, le blanc qui verse et le flash —
                // jamais un objet posé par-dessus.)
                // Le flash de la coupe — au-dessus de tout.
                if flashA > 0.001 {
                    Color.white
                        .opacity(flashA)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
                if let series = running {
                    // PRÉ-MONTÉE INVISIBLE puis RÉVÉLÉE dans l'aube : son
                    // monde blanc est le même papier que le voile — le
                    // fondu est indétectable, seule la bulle se
                    // matérialise, déjà à hauteur, déjà sous le doigt.
                    LiquidLensLab(
                        headline: exercise.name,
                        faceLabel: "SET \(series.id + 1)",
                        seriesNumber: series.id + 1,
                        // ⚠️ **C'EST LE SEUL POINT OÙ L'ISSUE D'UNE SÉRIE
                        // PART, ET IL PART UNE FOIS.** Le décideur de la
                        // chaîne reward (pill / Moment / popup / vidéo) se
                        // branchera ICI, jamais sur une minuterie de plus.
                        onFinish: { outcome in
                            finirSerie(series.id, outcome)
                        },
                        onCancel: {
                            running = nil
                            lensHandoff = nil
                            driveClimb = 0
                            lensShown = false
                            summited = false
                            withAnimation(.easeOut(duration: 0.28)) {
                                flood = 0
                            }
                        },
                        handoff: lensHandoff,
                        onSummit: { summited = true },
                        posedStart: posedLaunch
                    )
                    .opacity(lensShown
                             ? 1
                             : Self.sstep(0.18, Self.dawnEnd, driveClimb))
                    // La porte POSÉE entre en fondu (launchPosed anime son
                    // montage) ; la porte du geste reste une coupe — son
                    // écriture d'état n'est pas animée, le fondu ne joue pas.
                    .transition(.opacity)
                    // L'atterrissage : la bulle se POSE dans le monde
                    // blanc au moment de sa révélation.
                    .scaleEffect(lensShown ? 1.0 : 1.04)
                    .animation(.spring(response: 0.45,
                                       dampingFraction: 0.55),
                               value: lensShown)
                    // LE DRAG DE RETOUR — partout dans le monde blanc,
                    // tant que le sommet n'est pas franchi : tirer vers
                    // le bas rejoue la plongée à l'envers, sous le doigt,
                    // réversible. Simultané : la lentille garde ses
                    // gestes (un drag bas, chez elle, ne fait rien).
                    .simultaneousGesture(returnDrag)
                }
                // ⚠️ **LA PAGE BRAVO EST SORTIE DU FLOW (26-08).** Verdict de
                // Kathryn : « elle doit être considérée comme archivée et
                // supprimée du flow actif ». Le nouveau parcours est
                // FIN DE SÉRIE → REPOS → RETOUR À LA FICHE : le repos vit
                // déjà DANS le cadran (l'envol de fin de repos, 7495c85),
                // donc la sortie de la lentille rend directement la fiche.
                // Ce qui vient ensuite — pill de pièces, Moment, pop-up
                // reward, vidéo rare — se branchera sur `finirSerie`.
                //
                // ⚠️ LE FICHIER `BravoLab.swift` RESTE : `BravoPillView` y
                // vit et `CoffreFortView` la consomme. Archiver n'est pas
                // supprimer — et son banc `-bravoLab` la rejoue intacte.
                // LE PANNEAU DU RETOUR — « Recommencer ? ». Le conteneur
                // reste monté (transparent, sourd au doigt quand vide) :
                // c'est lui qui joue l'entrée et la sortie du panneau.
                GeometryReader { g in
                    // ⚠️ **LA HAUTEUR EST ANCRÉE, PLUS PROPORTIONNELLE**
                    // (26-08). Verdict : « cet overlay est trop petit, le
                    // composant Training derrière dépasse encore, il doit
                    // recouvrir ENTIÈREMENT cette zone ». Une fraction ne peut
                    // pas recouvrir un objet posé à un offset FIXE : le bord
                    // haut de la carte est à `expandedHeader + 4` quel que soit
                    // l'écran, le panneau était proportionnel — il dépassait ou
                    // pas selon le modèle. Il monte maintenant JUSQU'À la carte,
                    // plus la marge du halo qui déborde son clip.
                    let plein = g.size.height
                        + g.safeAreaInsets.top + g.safeAreaInsets.bottom
                    // ⚠️ L'ANCRE EST MESURÉE, PAS DÉDUITE : la carte publie
                    // déjà son cadre en coordonnées globales (`seriesCardFrame`,
                    // posé pour la volée de pièces). On la lit — la couverture
                    // devient exacte quel que soit l'écran ET le contenu de la
                    // carte. Le repli ne sert qu'au tout premier layout.
                    let h = PanneauMesures.hauteurAncree(
                        hauteurPleine: plein,
                        ancre: seriesCardFrame.minY > 1
                            ? seriesCardFrame.minY
                            : PanneauMesures.ancreParDefaut(
                                insetHaut: g.safeAreaInsets.top))
                    ZStack(alignment: .bottom) {
                        Color.clear
                        if let ask = restartAsk {
                            // LE VOILE — il éteint ce qui dépasse encore. La
                            // lumière de la carte est peinte HORS de son clip
                            // (28 pt) : même un panneau qui affleure pile son
                            // bord laisse fuir ce halo. Un dégradé, jamais une
                            // arête : le voile ne doit pas se lire comme un
                            // second bord.
                            LinearGradient(
                                stops: [
                                    .init(color: .black.opacity(0), location: 0),
                                    .init(color: .black.opacity(0.86),
                                          location: 0.62),
                                    .init(color: .black.opacity(0.96),
                                          location: 1)
                                ],
                                startPoint: .top, endPoint: .bottom)
                                .frame(height: h + 96)
                                .allowsHitTesting(false)
                                .transition(.opacity)
                            RestartSheet(
                                onLaunch: {
                                    exitRestart(ask, thenLaunch: true)
                                },
                                onDismiss: {
                                    exitRestart(ask, thenLaunch: false)
                                })
                                .frame(height: h)
                                .transition(.move(edge: .bottom))
                        }
                    }
                    // ⚠️ SUR LE CONTENU, JAMAIS SUR LE `GeometryReader` —
                    // l'école du calendrier. Posé sur le lecteur lui-même, il
                    // rend des insets NULS et la hauteur ancrée perdrait
                    // l'encart du bas.
                    .ignoresSafeArea()
                    .animation(.spring(response: 0.45,
                                       dampingFraction: 0.86),
                               value: restartAsk == nil)
                }
                .allowsHitTesting(restartAsk != nil)
                // LES PIÈCES DE LA SÉRIE — au-dessus de tout : la carte
                // s'écrit en lumière pendant que le panneau descend.
                // LA PILL DE GAIN — au-dessus de tout, sourde au doigt : elle
                // n'interrompt rien, elle DIT. Elle descend du bord haut,
                // tient deux secondes et repart toute seule ; la question
                // « Recommencer ? » arrive derrière elle.
                if let pg = pillGain {
                    PillGain(gain: pg.gain, total: pg.total)
                        .padding(.top, 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity,
                               alignment: .top)
                        .transition(.move(edge: .top)
                            .combined(with: .opacity))
                        .allowsHitTesting(false)
                        .zIndex(30)
                }
                if let at = coinsAt {
                    GeometryReader { g in
                        let og = g.frame(in: .global).origin
                        let tgt = seriesCardFrame == .zero
                            ? CGPoint(x: g.size.width - 64,
                                      y: g.size.height - 210)
                            : CGPoint(x: seriesCardFrame.maxX - 44 - og.x,
                                      y: seriesCardFrame.midY - og.y)
                        SeriesCoinFlight(
                            start: at,
                            source: CGPoint(x: g.size.width / 2,
                                            y: g.size.height * 0.74),
                            target: tgt,
                            onDone: { coinsAt = nil })
                    }
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                }
                // LA CARD REWARD — au-dessus de tout : elle joue seule son
                // entrée (fondu noir) et sa sortie ; démontée une fois
                // refermée. Le chiffre est celui des séries faites — 4 en
                // plancher tant que le déclencheur est le fake du header
                // (un count-up 0 → 0 n'apprendrait rien à l'œil).
                if rewardShow {
                    // ⚠️ **L'ISSUE PARLE QUAND ELLE EXISTE** (26-08). Cette
                    // pop-up servait jusqu'ici l'ATELIER — le chip « … » qui
                    // fait défiler les robes, et les bancs. Branchée sur la fin
                    // de série, elle reçoit maintenant un vrai MOMENT (un fait
                    // de la séance en cours) ou une vraie RÉCOMPENSE. Les deux
                    // usages cohabitent : sans issue, l'atelier retrouve
                    // exactement son comportement d'avant, à la ligne près.
                    let iss = issueEnCours
                    let robeIssue: RewardStyle? = {
                        switch iss {
                        case .moment(_, _, let st): return st
                        case .reward(let st, _): return st
                        default: return nil
                        }
                    }()
                    let videoIssue: String? = {
                        if case .reward(_, let v) = iss { return v }
                        return nil
                    }()
                    let styleFinal = robeIssue ?? Self.rewardStyles[rewardVariant]
                    RewardPopup(
                        // ⚠️ **LE PLANCHER DE 4 EST UNE BÉQUILLE D'ATELIER**
                        // (« un count-up 0 → 0 n'apprendrait rien à l'œil ») et
                        // il n'avait rien à faire dans le jeu : aux séries 1, 2
                        // et 3, la card annonçait « 4 ». Il ne vaut plus que
                        // pour l'atelier, là où il a été écrit. Quand le jeu
                        // parle, `rangIssue` dit le vrai rang — et il est
                        // MÉMORISÉ, donc immunisé contre l'écriture différée.
                        // ⚠️ Le welcome annonce des PIÈCES, pas des séries
                        // (§4 duodecies : 10, une fois par jour calendaire) —
                        // sinon « Claim +4 » sur une card qui donne 10 pièces.
                        count: styleFinal == .welcome
                            ? EconomieWoop.shared.piecesRetourQuotidien
                            : (rangIssue ?? max(sets.filter(\.isDone).count, 4)),
                        title: {
                            if case .moment(let t, _, _) = iss { return t }
                            return styleFinal == .welcome
                                ? "Welcome back" : "Training"
                        }(),
                        subtitle: {
                            // LE FAIT DU MOMENT EST VRAI : il vient de la
                            // fiche (reps, charge, cumul), il n'est pas
                            // inventé. C'est la seule chose qu'on puisse
                            // honnêtement raconter sans backend.
                            if case .moment(_, let fait, _) = iss { return fait }
                            return styleFinal == .welcome
                                ? "Your next session is waiting for you."
                                : "Congratulations, you've completed your training!"
                        }(),
                        unit: styleFinal == .welcome ? "Coins" : "Sets",
                        style: styleFinal,
                        robe: CommandLine.arguments
                            .contains("-welcomeTexte") ? .texte : .video,
                        videoNom: videoIssue
                            ?? (styleFinal == .welcome
                                ? "reward-welcome"
                                : rewardVideoNomCourant
                                ?? (CommandLine.arguments
                                    .contains("-rewardVideo")
                                    ? Self.rewardVideos[
                                        rewardVideoTour
                                        % Self.rewardVideos.count]
                                    : nil)),
                        onClose: {
                            rewardShow = false
                            rewardVideoNomCourant = nil
                            // ⚠️ UN SEUL CHEMIN VERS LE PANNEAU : c'est la
                            // FERMETURE de ce qu'on montre qui pose la question
                            // « Recommencer ? » (verdict §12). Deux chemins, et
                            // on se retrouverait un jour avec la question
                            // par-dessus une pop-up.
                            if serieAPoser != nil {
                                DispatchQueue.main.asyncAfter(
                                    deadline: .now() + 0.26) {
                                    poserLaQuestion()
                                }
                                return
                            }
                            // La démo enchaînée : Close = la suivante.
                            if CommandLine.arguments
                                .contains("-rewardDemo") {
                                rewardDemoTour += 1
                                DispatchQueue.main.asyncAfter(
                                    deadline: .now() + 0.6) {
                                    ouvrirComboDemo()
                                }
                            }
                        })
                }
            }
    }

    /// Le papier arrive VITE — la page a basculé bien avant la fin du geste,
    /// pour que le dernier tiers de la course se fasse déjà dans le blanc.
    private var floodVeil: Double {
        let u = min(max((flood - 0.12) / 0.46, 0), 1)
        return u * u * (3 - 2 * u)
    }

    /// Le papier de la maison — celui du dôme, celui de la lentille.
    private static let paper = Color(red: 0.956, green: 0.952, blue: 0.942)

    // MARK: Les deux corps de page

    /// LA MUSCULATION NE DÉFILE PLUS — et c'est la réponse au « ça tient
    /// toujours pas ». Le ScrollView ne servait qu'à piloter la carte (son
    /// flux est vide : l'historique vit DANS la carte) et c'est lui qui la
    /// reprenait sans cesse — élastique, inertie, aimant d'ancres. La page
    /// est désormais POSÉE, et la carte a son geste à elle, celui de la
    /// bannière du profil : prise directe, butée douce, aimant au lâcher.
    /// Rien ne peut plus la déloger.
    ///
    /// La photo, le titre et la carte sont dessinés en OVERLAY au-dessus
    /// (tout est fonction pure de `carteP`) ; ici ne vit que la surface du
    /// geste et le relais du tap.
    private var strengthPage: some View {
        ZStack(alignment: .top) {
            // LA SURFACE DU GESTE — TOUT L'ÉCRAN, zone sûre comprise.
            // PIÈGE PAYÉ : posée dans la zone sûre, elle laissait une
            // BANDE MORTE de ~100 pt sous la barre de statut — or la
            // carte ouverte, elle, monte jusqu'au châssis : on posait le
            // doigt sur sa tête (l'endroit même où l'on attrape une
            // bannière pour la refermer) et rien ne se passait. Les chips
            // et le galet sont dessinés PAR-DESSUS (ce sont des
            // `safeAreaInset`) : leurs touchers gagnent, et le galet
            // garde son drag de lancement intact.
            Color.clear
                .contentShape(Rectangle())
                .gesture(carteDrag)
                .ignoresSafeArea()
            // Le RELAIS DU TAP, à la place fermée de la carte :
            // « Touchez pour voir le détail » ouvre — le même chemin
            // que le doigt.
            Color.clear
                .frame(height: carteFermeeH + 8)
                .contentShape(Rectangle())
                .offset(y: Self.expandedHeader + 4)
                .onTapGesture { dock(true) }
                .allowsHitTesting(carteP <= 0.02)
        }
    }

    /// LE GESTE DE LA CARTE — la grammaire de la bannière du profil,
    /// retournée (ici on TIRE VERS LE HAUT pour ouvrir) : la course en
    /// prise directe 1:1, la butée douce au-delà de l'ouvert, et l'aimant
    /// au lâcher sur l'intention prédite. L'haptique : prise medium au
    /// décollage, coup FERME au dock ouvert, medium au retour.
    private var carteDrag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { v in
                if !carteSaisie {
                    // Un geste LATÉRAL n'est pas le nôtre : sans ce
                    // filtre d'axe, un balayage horizontal (le réflexe du
                    // retour par le bord) armait la carte et rendait deux
                    // coups d'haptique pour rien.
                    if abs(v.translation.height)
                        <= abs(v.translation.width) { return }
                    // Un geste qui DESCEND sur la carte fermée n'a rien à
                    // ouvrir : il meurt (rien à tirer vers le bas ici).
                    if carteP < 0.5, v.translation.height > 0 { return }
                    carteSaisie = true
                    carteBase = carteP
                    // La course s'ouvre AVANT le premier déplacement : les
                    // lignes se montent ici, sur une carte immobile — le
                    // hoquet d'un montage en plein vol est évité.
                    carteBouge = true
                    carteBougeJeton += 1
                    carteCran = Int(min(max(carteP, 0), 1) * 5)
                    carteFranchi = carteP > (carteP < 0.5 ? 0.28 : 0.55)
                    UIImpactFeedbackGenerator(style: .medium)
                        .impactOccurred(intensity: 0.8)
                }
                // Vers le HAUT = ouvrir : la translation est négative.
                let brut = carteBase - v.translation.height
                    / Self.collapseSpan
                defer { suivreLeRetard(carteP) }
                carteP = brut <= 1 ? max(0, brut)
                                   : 1 + (brut - 1) * 0.12
                grainDuGeste()
            }
            .onEnded { v in
                guard carteSaisie else { return }
                carteSaisie = false
                // Le grondement s'éteint AVEC le doigt : la suite est un
                // ressort, elle a son propre coup.
                RocketHaptics.shared.dragEnd()
                let pred = carteBase - v.predictedEndTranslation.height
                    / Self.collapseSpan
                // GÉNÉREUX à l'ouverture (un élan suffit), FRANC à la
                // fermeture (la carte ne se referme pas par accident) —
                // la loi exacte du dépliement profil.
                dock(carteBase < 0.5 ? pred > 0.28 : pred > 0.55)
            }
    }

    /// LE GRAIN DU GESTE — ce qu'on sent en tirant la carte. Trois
    /// couches : le GRONDEMENT continu (le moteur maison, celui du galet
    /// — muet au simulateur, il ne vit qu'au téléphone) qui enfle avec la
    /// course ; les CRANS, un petit coup tous les cinquièmes, dans les
    /// deux sens, qui donnent à la carte le poids d'un tiroir ; et le
    /// POINT DE BASCULE — un coup plus ferme au moment précis où lâcher
    /// installerait la carte. C'est ce dernier qui rend le geste sûr :
    /// la main sait, avant de lâcher, ce qui va se passer.
    private func grainDuGeste() {
        let p = min(max(carteP, 0), 1)
        RocketHaptics.shared.dragLevel(Double(p) * 0.55)
        let seuil: CGFloat = carteBase < 0.5 ? 0.28 : 0.55
        let auDela = p > seuil
        if auDela != carteFranchi {
            carteFranchi = auDela
            UIImpactFeedbackGenerator(style: .rigid)
                .impactOccurred(intensity: 0.7)
        } else {
            let cran = Int(p * 5)
            if cran != carteCran {
                UIImpactFeedbackGenerator(style: .soft)
                    .impactOccurred(intensity: 0.32)
            }
        }
        carteCran = Int(p * 5)
    }

    /// LE DOCK : la carte s'installe, ouverte ou fermée. Les deux chemins
    /// (le drag, le tap) y passent — une seule loi d'installation, et une
    /// seule chose à écrire : le curseur. Il n'y a plus rien d'autre à
    /// tenir.
    private func dock(_ ouvre: Bool) {
        // LE COUP DE POSE, en DEUX temps — un objet qui a une masse ne
        // fait pas « tic », il fait « toc… toc ». Ouverte : le coup ferme
        // puis le petit verrou qui prend. RETRAIT : plus mat, et l'écho
        // arrive plus tard — c'est le tiroir qui retombe dans son
        // logement. Les deux ne se confondent jamais dans la main.
        RocketHaptics.shared.dragEnd()
        UIImpactFeedbackGenerator(style: ouvre ? .heavy : .medium)
            .impactOccurred(intensity: ouvre ? 0.9 : 0.8)
        DispatchQueue.main.asyncAfter(
            deadline: .now() + (ouvre ? 0.07 : 0.11)
        ) {
            UIImpactFeedbackGenerator(style: ouvre ? .rigid : .soft)
                .impactOccurred(intensity: ouvre ? 0.45 : 0.5)
        }
        // Le ressort fait encore partie de la COURSE : la parure ne
        // revient qu'une fois la carte posée (sinon le détail se rallume
        // en plein vol — le pire moment).
        carteBouge = true
        carteBougeJeton += 1
        let jeton = carteBougeJeton
        withAnimation(.spring(response: 0.5, dampingFraction: 0.84)) {
            carteP = ouvre ? 1 : 0
            poserLeRetard(carteP)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) {
            if carteBougeJeton == jeton, !carteSaisie { carteBouge = false }
        }
    }

    // (L'historique du flux est mort le 15-08 : les lignes vivent
    // désormais DANS la carte des séries — voir `listeSeries`.)

    /// Le cardio garde sa page qui défile et ses blocs sombres : le dôme blanc
    /// est le système de la musculation — il rejoindra le reste quand le
    /// composant sera généralisé.
    private var cardioPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                titleBlock(big: false)
                hero(maxHeight: 210)
                if let lastTime { LastTimeBanner(text: lastTime) }
                editor
                if let confirmation {
                    Label(confirmation, systemImage: "checkmark.circle.fill")
                        .font(.inter(13, .medium))
                        .foregroundStyle(Color.woopGold)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 26)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: Le header qui se rétrécit

    /// LE HEADER AU SCROLL — depuis le 15-08 : la photo et le grand titre
    /// vivent SOUS la lumière additive (le fond noir opaque de la photo
    /// doit recevoir la lumière, pas la poinçonner) et S'ÉTEIGNENT pendant
    /// que la carte des séries, AU-DESSUS de la lumière, prend l'écran.
    /// (La vignette-notification et son morphing fit→fills sont morts —
    /// « la vignette meurt » ; git les garde, cfe08e1/db029cd.)
    ///
    /// Tout est fonction pure de `headerY` — remonter rembobine pixel pour
    /// pixel, aucun withAnimation. La grammaire est celle de StoryPortal :
    /// UN scalaire interpole position, taille ET rayon. (Jamais de
    /// matchedGeometryEffect — la maison anime à la main.)

    /// Les nombres de la pose de la photo — la partition ne sert plus que
    /// le REPOS (y = 0) : le pipeline .fill au zoom fitZ, l'école « le
    /// fond de la photo est le noir de la page ».
    private struct HeaderPose {
        let u: Double
        let pw: CGFloat, ph: CGFloat, px: CGFloat, rad: CGFloat
        let swap: Double, cardIn: Double, bigOut: Double
        /// Le zoom INTERNE du contenu (l'école « le fond de la photo est
        /// le noir de la page ») : un SEUL rendu recadré dont le contenu
        /// se resserre — fit-équivalent au repos (l'image entière, zoom
        /// fitZ), recadrage plein dans la vignette (zoom 1). `hard`
        /// éteint les bords fondus sur la même course.
        let zoom: CGFloat, hard: Double
        init(W: CGFloat, y: CGFloat, aspect: CGFloat) {
            u = ExerciseDetailView.sstep(
                0, Double(ExerciseDetailView.collapseSpan), Double(y))
            pw = ExerciseDetailView.lp(W, 54, u)
            ph = ExerciseDetailView.lp(ExerciseDetailView.heroCap, 54, u)
            px = ExerciseDetailView.lp(0, 28, u)
            rad = ExerciseDetailView.lp(0, 14, u)
            // Le PASSAGE DE COUCHE (sous la lumière → sur la lumière) :
            // les deux copies sont désormais pixel-identiques, le fondu
            // ne croise plus deux images — il est invisible par nature.
            swap = ExerciseDetailView.sstep(0.45, 0.72, u)
            // La carte ne naît qu'une fois la photo presque posée.
            cardIn = ExerciseDetailView.sstep(0.58, 0.92, u)
            bigOut = 1 - ExerciseDetailView.sstep(0.28, 0.62, u)
            // fit et fill du MÊME pipeline : le rapport des deux échelles
            // ne dépend que des deux aspects (cadre, image).
            let fA = Double(pw / max(ph, 1))
            let r = fA / Double(max(aspect, 0.01))
            let fitZ = r < 1 ? r : 1 / r
            zoom = CGFloat(fitZ + (1 - fitZ)
                           * ExerciseDetailView.sstep(0.10, 0.90, u))
            hard = ExerciseDetailView.sstep(0.30, 0.78, u)
        }
    }

    /// LA PHOTO DU MORPHING — UN SEUL RENDU pour les deux couches, et
    /// c'est lui qui a tué la saccade. L'ancien fondu croisait la photo
    /// entière (.fit) et la vignette recadrée (.fill) : deux images
    /// différentes — un saut de taille du sujet au milieu — et des vues
    /// montées/démontées en plein geste (décodage d'image sous le doigt,
    /// le hoquet senti). Ici le cadre rétrécit pendant que le CONTENU se
    /// resserre en continu : le fond de la photo étant un noir opaque sur
    /// une page noire, « l'image entière » n'est qu'un recadrage dézoomé
    /// du même pipeline. Le clip et les masques viennent APRÈS le zoom :
    /// ils vivent dans le repère du cadre, pas du contenu.
    private func morphPhoto(_ p: HeaderPose) -> some View {
        Image(exercise.image)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fill)
            .frame(width: p.pw, height: p.ph)
            .scaleEffect(p.zoom)
            .clipShape(RoundedRectangle(cornerRadius: p.rad,
                                        style: .continuous))
            // Les bords fondus du héros (les masques de `hero`), qui se
            // referment avec `hard` : au repos la photo fond dans la
            // nuit, en vignette le recadrage net n'en a plus besoin.
            .mask {
                LinearGradient(stops: [
                    .init(color: .white.opacity(p.hard), location: 0.0),
                    .init(color: .white, location: 0.07),
                    .init(color: .white, location: 0.86),
                    .init(color: .white.opacity(p.hard), location: 1.0)
                ], startPoint: .top, endPoint: .bottom)
            }
            .mask {
                LinearGradient(stops: [
                    .init(color: .white.opacity(p.hard), location: 0.0),
                    .init(color: .white, location: 0.05),
                    .init(color: .white, location: 0.95),
                    .init(color: .white.opacity(p.hard), location: 1.0)
                ], startPoint: .leading, endPoint: .trailing)
            }
            .accessibilityHidden(true)
    }

    /// La couche ARRIÈRE : photo + grand titre, sous la lumière. TOUT
    /// reste monté en permanence — l'opacité seule joue (un montage à
    /// mi-course décode l'image sous le doigt : la saccade payée).
    ///
    /// LA VIGNETTE EST MORTE (verdict du 15-08 : « la vignette meurt ») :
    /// la photo ne morphe plus vers la carte-notification — elle garde sa
    /// pose du repos (`HeaderPose` à y = 0) et S'ÉTEINT tôt pendant que la
    /// carte des séries monte la recouvrir. Remonter la rallume, pixel
    /// pour pixel.
    private var collapsingHeaderBack: some View {
        GeometryReader { g in
            let u = Self.sstep(0, Double(Self.collapseSpan),
                               Double(headerY))
            let p = HeaderPose(W: g.size.width, y: 0, aspect: heroAspect)
            ZStack(alignment: .topLeading) {
                // Le titre meurt le premier : la carte passe sur sa zone
                // dès le début de la course.
                titleBlock(big: true)
                    .padding(.horizontal, 20)
                    .offset(y: Self.lp(12 + Self.heroCap + 8,
                                       12 + Self.heroCap - 22, u))
                    .opacity(1 - Self.sstep(0.03, 0.32, u))
                // La photo s'éteint en dérivant à peine vers le haut —
                // une sortie, pas un morphing.
                morphPhoto(p)
                    .offset(x: p.px, y: Self.lp(12, -8, u))
                    .opacity(1 - Self.sstep(0.06, 0.46, u))
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: La carte des séries qui prend l'écran

    /// LA CARTE DES SÉRIES (le geste du 15-08) : le scroll vers le haut la
    /// fait GROSSIR depuis sa place de bijou jusqu'à presque tout l'écran
    /// — bord haut juste sous le chevron (elle s'incruste dans la zone du
    /// header, dont la photo s'est éteinte), bord bas juste au-dessus du
    /// galet. Dedans : le médaillon s'ouvre en grossissant, et la liste
    /// des séries naît sous l'en-tête. Fonction pure de `headerY` — le
    /// scroll vers le bas rembobine tout, et l'aimant par ancres (déjà là)
    /// garantit tout ouvert ou tout fermé, jamais entre les deux.
    ///
    /// Sourde au doigt : le geste appartient au ScrollView du dessous, le
    /// tap au relais du flux — une carte qui prendrait le toucher tuerait
    /// le scroll qui la referme.
    private var carteSeries: some View {
        GeometryReader { g in
            let u = Self.sstep(0, Double(Self.collapseSpan),
                               Double(headerY))
            // La distance au bord PHYSIQUE de l'écran (l'overlay naît
            // sous les chips) — mesurée, jamais devinée.
            let cime = g.frame(in: .global).minY
            // Fermée : la place du bijou dans le flux (padding 20, sous
            // la réserve du header). Ouverte : la carte EMBARQUE le
            // header — bord physique moins le liseré de nuit de 5 pt (la
            // grammaire de la bannière profil), le chevron reste posé
            // dessus ; le bas s'arrête au-dessus du galet.
            let x = Self.lp(20, 5, u)
            let y = Self.lp(Self.expandedHeader + 4, 5 - cime, u)
            // LA HAUTEUR DE L'ÉCRIN — mesurée bandeau et liseré compris
            // (ils vivent DANS le composant). Ouvert : du châssis au galet —
            // le galet est un OVERLAY depuis §2.16 (il ne réduit plus
            // `g.size`), sa hauteur se soustrait ICI : le bas de la carte
            // ouverte ne bouge pas d'un pixel.
            let h = Self.lp(carteFermeeH,
                            g.size.height - 15 + cime
                                - LaunchPebble.height, u)
            // LE BANDEAU — le seul élément qui change vraiment de nature
            // pendant la course : un bandeau de lumière fermé, TOUT le
            // haut de l'écran ouvert (le chevron et le « … » s'y posent).
            // Ouvert, il descend BIEN SOUS les boutons : la dalle collait
            // à 2 pt sous eux, elle respire maintenant à ~21 pt.
            let bande = Self.lp(Self.bande0, max(Self.bande0, cime + 8), u)
            // L'ÉCRIN : coins RESSERRÉS FERMÉ (l'allure « carte d'app »
            // demandée le 15-08) — mais OUVERT, le haut redevient 55.
            // CONTRAINTE DURE, payée : collée au châssis derrière 5 pt de
            // nuit, la carte doit être CONCENTRIQUE à l'écran ; à 32 son
            // coin coupait à l'intérieur de celui du téléphone et
            // laissait un coin de nuit — le « problème de fondu » des
            // coins du haut. Le bas, lui, ne touche rien : il reste
            // serré.
            // Fermé 26 (Phase 1 restauration : la référence mesure son
            // rayon à 23-28 pt — 20 était trop serré, tranché au calque).
            let rH = Self.lp(26, 55, u), rB = Self.lp(26, 30, u)
            let ecrin = UnevenRoundedRectangle(
                topLeadingRadius: rH, bottomLeadingRadius: rB,
                bottomTrailingRadius: rB, topTrailingRadius: rH,
                style: .continuous)
            FlammeJauge(done: sets.filter(\.isDone).count,
                        // Le total réel : la rangée de flammes plafonne à
                        // cinq fentes et remplace la dernière par « +N »
                        // au-delà — encore faut-il qu'elle connaisse N.
                        // (Sa place dans l'appel suit l'ordre des
                        // propriétés de la struct : l'init mémoire n'est
                        // pas nommée au hasard.)
                        total: max(sets.count, 5),
                        // LA LIGNE DE CONTRAT (16-08) : « 5 séries ·
                        // 12 reps · 20 kg ». Vraie à tout instant, sans
                        // calcul d'état — et l'hôte est le seul à
                        // connaître répétitions et charges.
                        contrat: contratSeance,
                        ouverture: CGFloat(u),
                        // La garde est MORTE : c'est la bande d'aurora
                        // qui écarte désormais l'en-tête du chevron.
                        garde: 0,
                        // EN COURSE : le bijou allège sa parure (voir
                        // FlammeJauge) — la fluidité prime sur des
                        // détails que l'œil ne voit pas en mouvement.
                        bouge: carteBouge && !Self.carteLourd,
                        // POSÉE DANS L'ÉCRIN : rayons rentrés d'un
                        // liseré, et la veine d'or s'éteint — elle
                        // rivaliserait avec la lumière qui l'entoure.
                        dansEcrin: true,
                        // Le bandeau de lumière et le liseré vivent DANS
                        // le composant : lui seul sait où finit sa dalle
                        // et où commence l'aurora qui la cerne.
                        bandeau: bande,
                        liseré: Self.liseré) {
                // Les lignes sont posées à la largeur de la carte
                // OUVERTE, une fois pour toutes : sinon les cinq lignes
                // (et leurs textes) se REMESURENT à chaque image pendant
                // que la carte s'élargit — c'est la moitié du coût.
                listeSeries(u: u, largeur: g.size.width - 44)
            }
            // Au repos, la hauteur reste NATURELLE (le bijou au pixel
            // d'avant) et se MESURE — c'est la base du lerp ; imposée au
            // repos, la mesure se mordrait la queue.
            .frame(height: u > 0.0005 ? h : nil)
            .onGeometryChange(for: CGFloat.self) { $0.size.height }
                action: { nh in
                    if !carteBouge, headerY < 0.5,
                       abs(nh - carteFermeeH) > 0.5 {
                        carteFermeeH = nh
                    }
                }
            // L'ÉCRIN D'AURORA — le champ du profil, en fond (jamais dans
            // la pile de layout : il est GLOUTON, un GeometryReader sans
            // taille propre, et il ferait exploser la mesure de la dalle).
            // LA MATIÈRE : L'OBSIDIENNE (15-08, après le verdict « c'est
            // plat, 0/10, ce n'est même pas du liquid glass »). Mes
            // dégradés SwiftUI ne feront JAMAIS du verre : un verre, ce
            // n'est pas une couleur, c'est un ÉCLAIRAGE — une source
            // posée hors du cadre, de l'huile d'or qui coule le long des
            // arêtes, un faisceau froid oblique qui révèle la courbure,
            // et un biseau qui donne son épaisseur à la dalle. Tout cela
            // existe déjà, calé AU PIXEL sur une photo (l'or est mesuré
            // canal par canal dans `oIris`) : c'est `obsidianSurface`,
            // la carte obsidienne. On ne réécrit pas une matière validée,
            // on la RÉUTILISE.
            // La lampe s'approche quand la carte est en main (`lit`), et
            // la matière se fige pendant la course (la loi de fluidité).
            // LE VERRE COULANT — un SEUL `colorEffect` à la place de
            // quatre couches. L'obsidienne a servi de première marche
            // (sa loi de couleur est ici), mais sa lampe seule ne fait
            // pas les RUBANS : il fallait un champ filamenteux.
            // Toujours en `.background` : jamais dans la pile de layout,
            // clippé par l'écrin juste dessous — les rubans épousent les
            // coins gratuitement — et il couvre AUSSI le bandeau, donc un
            // filament passe derrière la poignée sans qu'on ait rien à
            // faire.
            // LE VERRE GONFLÉ (la référence du 15-08, MESURÉE au pixel) :
            // un seul shader fait tout — surface, épaule, trait angulaire,
            // brumes intérieures, blooms et rayons dans l'air. Posé APRÈS
            // le clip (un `.background` posé après n'est pas rogné) : la
            // lumière déborde, le contenu reste clippé par l'écrin.
            .clipShape(ecrin)
            // LE CALQUE (banc du verre) : la référence posée SUR la carte,
            // clippée par l'écrin — l'outil de superposition/blink.
            .overlay {
                if Self.verreLab { calqueOverlay(ecrin: ecrin) }
            }
            .background {
                VerreGonfle(rayonHaut: rH, rayonBas: rB,
                            allege: carteBouge && !Self.carteLourd,
                            essor: u, essorLag: Double(carteLag),
                            mode: Self.verreLab ? verreMode : 0)
            }
            .frame(width: g.size.width - 2 * x)
            // La cible des pièces : la carte se déclare en global, la
            // volée sait où se poser — ouverte comme fermée. JAMAIS
            // pendant la course : une écriture d'état par image
            // rejouerait tout le corps de la page une SECONDE fois par
            // frame (le double coût, invisible mais mortel).
            .background {
                GeometryReader { p in
                    Color.clear
                        .onAppear {
                            seriesCardFrame = p.frame(in: .global)
                        }
                        .onChange(of: p.frame(in: .global)) { _, f in
                            if !carteBouge { seriesCardFrame = f }
                        }
                }
            }
            .offset(x: x, y: y)
        }
        // ⚠️ **HIT-TEST CONDITIONNEL, PLUS JAMAIS CONSTANT** (26-08). Ce
        // `false` datait du 13-08 (cfe08e1), quand un ScrollView DE PAGE
        // pilotait encore la carte. Ce ScrollView de page est mort le 15-08
        // (bd848e7) et le ScrollView INTERNE des séries est arrivé le 16-08
        // (8abe0e0) — dans un sous-arbre déjà sourd. Un `allowsHitTesting`
        // faux sur un ancêtre ne se rouvre pas depuis un descendant : la
        // liste des séries n'a JAMAIS été atteignable, et chaque doigt
        // tombait sur le `Color.clear` plein écran de `carteDrag` — c'est
        // exactement le verdict « je peux faire défiler le composant
        // Training, mais pas les séries ». Le banc `-scrollBas` ne prouvait
        // que le débordement du contenu, pas la joignabilité.
        //
        // La carte ne prend le doigt qu'OUVERTE (≥ 0,90) et à l'arrêt : en
        // course, le geste appartient à la carte elle-même, sinon le scroll
        // volerait la fin de l'ouverture. La FERMETURE reste possible par la
        // bande de prise posée par-dessus (cf. `priseCarteSeries`).
        .allowsHitTesting(carteP > 0.90 && !carteSaisie)
    }

    /// LA BANDE DE PRISE DE LA CARTE OUVERTE — la contrepartie du hit-test
    /// rendu à la liste : sans elle, la carte ouverte n'aurait plus AUCUN
    /// endroit où l'attraper pour la refermer (le scroll mangerait tout).
    ///
    /// Elle couvre le bandeau du haut — poignée, en-tête, ligne de contrat —
    /// c'est-à-dire exactement l'endroit où l'on attrape une bannière. Elle
    /// n'existe QUE carte ouverte : fermée, la surface plein écran de
    /// `strengthPage` fait déjà tout le travail.
    @ViewBuilder private var priseCarteSeries: some View {
        if carteP > 0.02 {
            Color.clear
                .frame(height: Self.bande0 + carteFermeeH * 0.34 + 24)
                .contentShape(Rectangle())
                .gesture(carteDrag)
                .ignoresSafeArea(edges: .top)
        }
    }

    /// LE CALQUE de restauration : la référence de Kathryn étirée sur la
    /// géométrie exacte de la carte. En blink, elle bat à 250 ms — les
    /// erreurs sautent aux yeux (la loi du brief : superposition, jamais
    /// de mémoire visuelle).
    @ViewBuilder
    private func calqueOverlay(ecrin: UnevenRoundedRectangle) -> some View {
        if calqueOp > 0.001, let ui = Self.calqueImage {
            if calqueBlink {
                TimelineView(.periodic(from: .now, by: 0.25)) { tl in
                    let on = Int(tl.date.timeIntervalSinceReferenceDate
                                 / 0.25) % 2 == 0
                    Image(uiImage: ui)
                        .resizable()
                        .opacity(on ? calqueOp : 0)
                }
                .clipShape(ecrin)
                .allowsHitTesting(false)
            } else {
                Image(uiImage: ui)
                    .resizable()
                    .opacity(calqueOp)
                    .clipShape(ecrin)
                    .allowsHitTesting(false)
            }
        }
    }

    /// Le HUD du banc : trois commandes monospace sur la nuit — M (les
    /// 5 modes du shader), C (l'opacité du calque), B (le blink).
    private var verreHud: some View {
        HStack(spacing: 14) {
            Button {
                verreMode = (verreMode + 1) % 5
            } label: {
                Text("M·\(Self.verreModeNoms[verreMode])")
            }
            Button {
                let pas: [Double] = [0, 0.25, 0.5, 0.75, 1.0]
                calqueOp = pas.first(where: { $0 > calqueOp + 0.01 }) ?? 0
            } label: {
                Text("C·\(Int((calqueOp * 100).rounded()))%")
            }
            Button {
                calqueBlink.toggle()
            } label: {
                Text(calqueBlink ? "B·ON" : "B·off")
            }
        }
        .font(.system(size: 13, weight: .semibold, design: .monospaced))
        .foregroundStyle(.white)
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.white.opacity(0.10)))
        .padding(.top, 6)
    }

    /// La liste des séries, née DANS la carte ouverte : les faites en or
    /// et pièces, les cinq places restantes en encre éteinte (« à
    /// venir ») — les lignes de la story, celles de l'ancien historique.
    /// « 5 séries · 12 reps · 20 kg » — le contrat de la séance, tel
    /// qu'il s'affiche sous le compte. On prend les valeurs de la
    /// première série : elles sont les mêmes pour toutes tant que
    /// l'utilisateur n'a rien modifié, et le pluriel suit le nombre.
    /// LE RESSORT MOU DU RETARD : une seule écriture, branchée sur le
    /// curseur de la carte. `carteLag` court après `carteP` sans jamais le
    /// rattraper tant que le doigt bouge — l'écart entre les deux EST la
    /// parallaxe.
    private func suivreLeRetard(_ v: CGFloat) {
        // FILTRE, PAS ANIMATION (17-08). Première version : un
        // `withAnimation` à chaque appel — or cette fonction est appelée
        // À CHAQUE IMAGE pendant que le doigt bouge, et chaque appel
        // RELANCE l'animation depuis la valeur courante. La copie
        // « retardée » rattrapait donc la vraie presque instantanément,
        // l'écart tombait à zéro, et la parallaxe n'existait plus —
        // elle ne survivait que sur le ressort de fin de geste.
        // Un passe-bas manuel, lui, garde son retard tant que la source
        // bouge : chaque image ne comble qu'un quart de l'écart.
        let k: CGFloat = 0.22
        let neuf = carteLag + (v - carteLag) * k
        // On ne réécrit pas pour rien : sous le millième, l'écart est
        // invisible et une écriture d'état par image coûte cher.
        if abs(neuf - carteLag) > 0.001 { carteLag = neuf }
        else if carteLag != v { carteLag = v }
    }

    /// LE RETOUR AU CALME — appelé au RELÂCHÉ, une seule fois. Sans lui,
    /// le filtre ne comblerait que 22 % de l'écart au dernier appel et le
    /// retard resterait FIGÉ : les lumières intérieures seraient restées
    /// décalées au repos, ce qui viole la règle qui protège les deux
    /// états validés (l'effet doit valoir zéro à l'arrêt). Ici un
    /// `withAnimation` est légitime : il n'est pas rappelé à chaque image.
    private func poserLeRetard(_ v: CGFloat) {
        withAnimation(.easeOut(duration: 0.30)) { carteLag = v }
    }

    private var contratSeance: String {
        // MÊMES VALEURS DE REPLI QUE LA LISTE (12 reps, 20 kg, 5 séries) :
        // au banc et sur un exercice neuf, `sets` est vide — la liste
        // affiche déjà ses valeurs par défaut, la ligne de contrat doit
        // dire la même chose qu'elle. Payé : sans ce repli, la ligne
        // sortait VIDE et le sous-titre disparaissait de la carte.
        // 16-08 : « enlève le nombre de séries, on l'a au-dessus — laisse
        // le nombre de reps et les kilos, basta ».
        let reps = sets.last?.reps ?? 12
        let kg = sets.last?.weight ?? 20
        let kgText = kg == kg.rounded()
            ? String(format: "%.0f", kg) : String(format: "%.1f", kg)
        return "\(reps) reps · \(kgText) kg"
    }

    private func listeSeries(u: Double, largeur: CGFloat) -> some View {
        // La naissance : les lignes n'existent que dans la carte déjà
        // grande — elles montent d'un souffle en s'allumant.
        let naissance = Self.sstep(0.45, 0.92, u)
        // AU REPOS, LES LIGNES N'EXISTENT PAS : cinq lignes montées sous
        // une carte fermée coûtent leur mise en page à chaque image. Elles
        // naissent à la PRISE du doigt — avant le moindre mouvement, donc
        // sans le hoquet d'un montage en plein geste (la leçon payée).
        return VStack(spacing: 10) {
            if carteBouge || u > 0.001 {
                ForEach(0..<max(sets.count, 5), id: \.self) { i in
                    // L'APPARITION EN CASCADE (16-08) : « une animation
                    // plus belle quand les séries apparaissent au drag,
                    // très premium ». Chaque ligne a SON seuil, décalé de
                    // 3,5 % d'ouverture — elles ne naissent donc pas en
                    // chœur mais l'une après l'autre, du haut vers le bas,
                    // et la cascade suit LE DOIGT : si on tire lentement,
                    // elle se déroule lentement ; si on lâche, le ressort
                    // l'emporte. C'est la même loi que la carte elle-même
                    // (un curseur, pas une animation qui vit sa vie).
                    // Elles montent de 22 pt, s'ouvrent de 96 % à 100 %
                    // et arrivent légèrement en retard sur leur opacité —
                    // ce décalage est ce qui fait « posé » plutôt que
                    // « collé ».
                    // AMPLIFIÉE (16-08, « je ne vois pas la différence ») :
                    // le décalage entre lignes passe de 3,5 à 6 % et la
                    // course de chaque ligne de 22 à 40 pt, avec une
                    // dérive LATÉRALE de 18 pt — une ligne qui monte tout
                    // droit se lit comme un défilement ; une ligne qui
                    // arrive de biais se lit comme une carte qu'on pose.
                    let seuil = 0.26 + Double(i) * 0.060
                    let p = Self.sstep(seuil, min(seuil + 0.26, 0.995), u)
                    let q = Self.sstep(seuil, min(seuil + 0.40, 0.999), u)
                    Group {
                        if i < sets.count {
                            SetHistoryRow(rank: i + 1,
                                          reps: sets[i].reps,
                                          kilos: sets[i].weight,
                                          seconds: sets[i].isDone
                                              ? sets[i].durationSeconds
                                              : restSeconds,
                                          done: sets[i].isDone)
                        } else {
                            SetHistoryRow(rank: i + 1,
                                          reps: sets.last?.reps ?? 12,
                                          kilos: sets.last?.weight ?? 20,
                                          seconds: restSeconds,
                                          done: false)
                        }
                    }
                    .opacity(p)
                    .offset(x: -18 * (1 - q), y: 40 * (1 - q))
                    .scaleEffect(0.93 + 0.07 * q, anchor: .leading)
                    // Et elle finit d'ARRIVER : une inclinaison de 6°
                    // qui se redresse, prise sur l'axe horizontal — le
                    // geste d'une carte qu'on rabat à plat.
                    .rotation3DEffect(.degrees(6 * (1 - q)),
                                      axis: (x: 1, y: 0, z: 0),
                                      anchor: .top, perspective: 0.35)
                }
            }
        }
        // La largeur de la carte OUVERTE, gelée : les lignes ne se
        // remesurent plus pendant que la coque s'élargit (les 16 pt
        // rognés à droite en début de course sont sous l'opacité).
        .frame(width: largeur, alignment: .topLeading)
        .padding(.top, 18)
        // Le bloc entier n'a plus besoin de son propre fondu : chaque
        // ligne porte le sien, et deux fondus superposés écrasaient la
        // cascade (tout arrivait ensemble à travers l'opacité globale).
        .opacity(Self.sstep(0.16, 0.34, u))
    }

    // MARK: En-tête

    /// Le chevron dans son carré de verre, et son double « … » en face —
    /// celui-ci s'ouvrira plus tard en carte (date, heure) : il a déjà sa
    /// place, il n'a pas encore son geste.
    /// LE COMPOSANT PARTAGÉ, enfin (le doublon privé de la fiche est mort
    /// — `ChipVerre` porte la recette depuis le 14-08, la fiche en gardait
    /// une copie). Sa CLARTÉ suit la carte : posés sur la nuit ils sont de
    /// verre fumé et blancs ; quand l'écrin d'aurora monte sous eux, le
    /// verre devient transparent et le glyphe passe à l'encre sombre.
    /// (La CLARTÉ est retombée à zéro le 15-08 : la carte ouverte est
    /// redevenue du verre FUMÉ, donc le fond sous les chips est sombre —
    /// ils gardent leur verre de nuit et leur glyphe blanc. Le mécanisme
    /// de bascule reste dans `ChipVerre`, prêt pour un fond clair.)
    /// ⚠️⚠️ **LE « … » ÉTAIT EXPÉDIÉ EN PRODUCTION, ET IL MENTAIT.** Le geste
    /// est PRÊTÉ à la card reward le temps de l'atelier — son vrai rôle (date,
    /// heure) attend toujours — mais il était monté **sans aucun drapeau** :
    /// dans l'app livrée, deux taps ouvraient une récompense entièrement
    /// FAUSSE (robe tirée au tourniquet, « Training », « Congratulations,
    /// you've completed your training! », compte planché à 4), et **deux taps
    /// suffisaient à atteindre le Welcome Back** — une card de retour
    /// d'absence, au milieu d'une séance.
    ///
    /// ⚠️ Pire, il empruntait une conséquence du JEU : tapé pendant la pill,
    /// `serieAPoser` est encore posé, donc la fermeture de cette card
    /// d'atelier **ouvrait le panneau « Recommencer ? »**. L'atelier
    /// commandait une étape du parcours.
    ///
    /// Il vit désormais derrière `-rewardAtelier`. Le jour où le « … » prend
    /// son vrai rôle, c'est ici qu'il le reprend.
    private static let chipAtelier =
        CommandLine.arguments.contains("-rewardAtelier")

    private var headerChips: some View {
        RangeeChips(retour: { dismiss() }) {
            if Self.chipAtelier {
                ChipVerre(symbole: "ellipsis", label: "Options") {
                    rewardVariant =
                        (rewardVariant + 1) % Self.rewardStyles.count
                    rewardVideoTour += 1
                    rewardShow = true
                }
            }
        }
    }

    /// EXACTEMENT le titre de la home — même fonte, même graisse, même
    /// interlettrage négatif, même dégradé. Le sous-titre dit la zone
    /// travaillée, en retrait, comme la référence.
    ///
    /// `big` : la version de la fiche muscu, sur DEUX lignes. Le corps ne
    /// change pas (30, comme partout) — ce qui change, c'est qu'il n'est
    /// plus ÉCRASÉ : « Woodchopper poulie haute » demande ~450 pt sur une
    /// ligne pour 362 disponibles, donc le `minimumScaleFactor(0,62)` le
    /// rendait en réalité à 24. Deux lignes, et il retrouve sa taille
    /// pleine. La largeur est bornée à 300 pour que la coupure tombe après
    /// « Woodchopper » (le mouvement, puis la machine) et pas après
    /// « poulie » — sur les noms courts, la borne ne se voit jamais.
    ///
    /// `WoopGradient.titleFade` est déjà DIAGONAL, précisément pour ce cas :
    /// un dégradé horizontal rallume le début de chaque ligne et un titre
    /// sur deux lignes se met à clignoter. Rien à y toucher.
    private func titleBlock(big: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(exercise.name)
                .font(.inter(30, .semibold))
                .tracking(-0.3)
                .foregroundStyle(WoopGradient.titleFade)
                .lineLimit(big ? 2 : 1)
                .minimumScaleFactor(big ? 0.9 : 0.62)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: big ? 300 : nil, alignment: .leading)
            Text("\(exercise.category.rawValue) • \(exercise.muscle)")
                .font(.inter(13))
                .foregroundStyle(Color.inkMuted)
        }
    }

    /// La photo NUE, fondue dans le noir de la carte : ni liseré, ni lueur,
    /// ni angles — un cadre dessiné redonnerait « une image dans une boîte »,
    /// et c'est exactement ce qui rendait cheap. Le fond de l'image est déjà
    /// le noir de la page ; les masques n'éteignent que les bords, là où une
    /// jambe ou un montant de machine buterait net sur l'arête.
    private func hero(maxHeight: CGFloat) -> some View {
        ExercisePhoto(exercise: exercise, fills: false)
            .frame(maxWidth: .infinity, maxHeight: maxHeight)
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .white, location: 0.07),
                        .init(color: .white, location: 0.86),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            }
            // Deux masques chaînés se multiplient : les quatre bords
            // s'éteignent sans dégradé bidimensionnel.
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .white, location: 0.05),
                        .init(color: .white, location: 0.95),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .leading, endPoint: .trailing
                )
            }
    }

    // MARK: L'éditeur cardio

    @ViewBuilder
    private var editor: some View {
        switch exercise.tracking {
        case .setsRepsWeight:
            // La musculation vit dans la dalle : rien ici.
            EmptyView()
        case .intervals:
            IntervalBlock(phases: $phases, repeatCount: $repeatCount)
        case .steady:
            SteadyBlock(seconds: $steadySeconds, speed: $steadySpeed,
                        incline: $incline, isStairs: exercise.id == "escalier",
                        hasIncline: exercise.id != "piscine")
        }
    }

    // MARK: Le geste principal du cardio

    /// Le bas d'écran du cardio, inchangé : sa fiche ne fait qu'enregistrer.
    private var primaryAction: some View {
        VStack(spacing: 10) {
            DiamondPrimaryButton(title: "Enregistrer l'exercice") {
                save()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background {
            // Le contenu défile DERRIÈRE le bouton : sans ce fondu, un bloc
            // viendrait se couper net sur son arête.
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0), location: 0),
                    .init(color: .black.opacity(0.62), location: 0.42),
                    .init(color: .black.opacity(0.88), location: 1)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    /// Ce que la pastille affiche de la séance : la part des séries faites.
    private var doneFraction: Double {
        guard !sets.isEmpty else { return 0 }
        return Double(sets.filter(\.isDone).count) / Double(sets.count)
    }

    /// Le geste de lancement. La page part de zéro série : la première naît
    /// ici, et chaque relance en crée une nouvelle quand les précédentes sont
    /// faites — on ne règle plus AVANT, on fait, et la carte compte.
    /// LA CARTE SE RANGE — et c'est vital : ouverte, elle couvre l'écran,
    /// et rien ne la refermait quand une série partait. La plongée, la
    /// lentille et la page BRAVO se seraient jouées DERRIÈRE elle. Tout
    /// départ de série passe donc ici d'abord.
    private func rangeCarte() {
        carteSaisie = false
        carteBougeJeton += 1
        guard carteP > 0.001 else { carteBouge = false; return }
        let jeton = carteBougeJeton
        withAnimation(.spring(response: 0.42, dampingFraction: 0.9)) {
            carteP = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.54) {
            if carteBougeJeton == jeton { carteBouge = false }
        }
    }

    private func launch() {
        rangeCarte()
        let index: Int
        let appended: Bool
        if let pending = sets.firstIndex(where: { !$0.isDone }) {
            index = pending
            appended = false
        } else {
            sets.append(DraftSet(reps: sets.last?.reps ?? 12,
                                 weight: sets.last?.weight ?? 20))
            index = sets.count - 1
            appended = true
        }
        running = RunningSeries(id: index, appended: appended)
        launchBeat += 1
    }

    // MARK: Le geste unique

    /// Le doigt du galet, en points plein écran. La fiche blanchit la
    /// page sur les premiers centimètres (le voile sature avant la
    /// bulle), monte la lentille à `mountClimb` — DÉJÀ soulevée — puis
    /// lui transmet le doigt vivant : un seul geste, de la nuit de la
    /// fiche au sommet du monde blanc.
    private func driveMoved(_ p: CGPoint, _ vy: CGFloat) {
        let c = Self.climbGlobal(y: p.y, h: pageFull.height)
        driveClimb = c
        // Temps 1 : le voile se réchauffe à peine (13 % à la fin de la
        // montée nocturne) ; temps 2 : l'aube verse le reste.
        flood = 0.22 * Self.sstep(0, Self.nightEnd, c)
                + 0.78 * Self.sstep(Self.nightEnd, Self.dawnEnd, c)
        if running == nil, c >= Self.mountClimb { launch() }
        if running != nil {
            lensHandoff = .init(point: p, velocityY: vy, live: true)
            // L'hystérésis de la révélation : montrée à 0,22, cachée si
            // le doigt redescend sous 0,17 — on oscille librement.
            if c >= Self.dawnEnd { lensShown = true }
            else if c < 0.17 { lensShown = false }
        } else {
            // Le grondement vit dès le premier point — le MÊME moteur que
            // la lentille : au relais, il ne change pas de main.
            RocketHaptics.shared.dragLevel(c)
            // La poussière sonore de la nuit ; passé le relais, c'est la
            // lentille qui la sème (une seule source à la fois).
            if let prev = lastDrive {
                Paillettes.shared.travel(hypot(p.x - prev.x, p.y - prev.y),
                                         level: c)
            }
            lastDrive = p
        }
    }

    /// Le relâcher. Bulle révélée : la lentille possède le geste (sa
    /// retombée, son sommet). Avant la révélation : la nuit se referme,
    /// et la série créée par CE lancement se défait — rien n'a eu lieu.
    private func driveEnded(_ p: CGPoint, _ vy: CGFloat) {
        if lensShown, running != nil {
            lensHandoff = .init(point: p, velocityY: vy, live: false)
        } else {
            closeBack()
        }
    }

    /// La nuit se referme sur la fiche — l'abandon et le retour partagent
    /// le même geste de rangement.
    private func closeBack() {
        if let r = running, r.appended,
           let last = sets.last, !last.isDone {
            sets.removeLast()
        }
        running = nil
        lensHandoff = nil
        summited = false
        lensShown = false
        posedLaunch = false
        lastDrive = nil
        RocketHaptics.shared.dragEnd()
        Paillettes.shared.end()
        withAnimation(.spring(response: 0.40, dampingFraction: 0.80)) {
            driveClimb = 0
        }
        withAnimation(.easeOut(duration: 0.22)) { flood = 0 }
    }

    /// LE DRAG DE RETOUR : l'inverse exact de la plongée, piloté par le
    /// doigt via `driveClimb` — le zoom recule, le blanc se résorbe, la
    /// nuit revient. Ne s'arme que sur un doigt NEUF (le geste d'origine
    /// vit dans le handoff) et jamais après le sommet.
    private var returnDrag: some Gesture {
        DragGesture(minimumDistance: 14, coordinateSpace: .global)
            .onChanged { v in
                guard lensShown, !summited,
                      lensHandoff?.live != true,
                      v.translation.height > 0 else { return }
                if returnFrom == nil {
                    returnFrom = v.startLocation.y
                    lastDrive = v.location
                }
                // La poussière suit aussi le chemin du retour.
                if let prev = lastDrive {
                    Paillettes.shared.travel(
                        hypot(v.location.x - prev.x,
                              v.location.y - prev.y),
                        level: Self.climbGlobal(y: v.location.y,
                                                h: pageFull.height))
                }
                lastDrive = v.location
                // ~300 pt de descente pour défaire toute la plongée.
                let back = Double(v.translation.height) / 300.0
                let c = max(Self.dawnEnd * (1 - back), 0)
                driveClimb = c
                if c < 0.17 { lensShown = false }
                flood = 0.22 * Self.sstep(0, Self.nightEnd, c)
                        + 0.78 * Self.sstep(Self.nightEnd, Self.dawnEnd, c)
                RocketHaptics.shared.dragLevel(c)
            }
            .onEnded { v in
                guard returnFrom != nil else { return }
                returnFrom = nil
                lastDrive = nil
                RocketHaptics.shared.dragEnd()
                Paillettes.shared.end()
                if driveClimb < 0.11 {
                    // Revenue assez loin : la fiche reprend sa nuit.
                    closeBack()
                } else {
                    // Pas assez : la plongée se rejoue jusqu'au monde
                    // blanc, en ressort.
                    lensShown = true
                    withAnimation(.spring(response: 0.42,
                                          dampingFraction: 0.78)) {
                        driveClimb = Self.dawnEnd
                        flood = 1
                    }
                }
            }
    }

    private func target(for index: Int) -> String {
        guard sets.indices.contains(index) else { return "" }
        let set = sets[index]
        return "\(set.reps) reps · \(set.weight.formatted(.number.precision(.fractionLength(0...1)))) kg"
    }

    /// L'ENVOL S'ACHÈVE, ET LA FICHE REVIENT. Le cadran rend la main, le
    /// papier tombe avec lui — on passe d'une nuit à l'autre, le voile blanc
    /// n'a rien à faire entre les deux.
    ///
    /// ⚠️ **C'ÉTAIT `startBravo` : la page BRAVO est sortie du flow (26-08).**
    /// Le parcours est désormais FIN DE SÉRIE → REPOS (il vit dans le cadran)
    /// → RETOUR À LA FICHE, et c'est seulement ensuite que le contexte parle :
    /// pill de pièces au cas normal, Moment, pop-up reward, vidéo au cas rare.
    /// Ce point-ci est le SEUL endroit où l'issue d'une série est connue, et
    /// il ne passe qu'une fois : c'est là que le décideur se branchera.
    private func finirSerie(_ index: Int, _ o: LiquidLensLab.SeriesOutcome) {
        let f = FinishedSeries(index: index,
                               reps: o.reps,
                               kilos: o.kilos,
                               rest: o.restSeconds,
                               seconds: o.effortSeconds)
        flood = 0
        running = nil
        lensHandoff = nil
        driveClimb = 0
        lensShown = false
        summited = false
        posedLaunch = false
        // Le repos choisi devient celui de l'exercice.
        restSeconds = f.rest
        // LA SÉRIE S'ÉCRIT ET LES PIÈCES VOLENT — ici, à l'air libre, avant
        // que quoi que ce soit ne se pose dessus. (L'écriture attendait la
        // sortie du panneau ; mais c'est la PILL qui annonce les pièces
        // maintenant, et elle ne peut pas annoncer ce qui n'est pas écrit.)
        settleSeries(f, coins: true)
        serieAPoser = f
        // LE DÉCIDEUR — le seul endroit où l'on choisit quoi montrer. La
        // fiche se découvre d'abord (0,34 s) : sans ce souffle, tout naissait
        // par-dessus la lentille qui n'avait pas fini de tomber.
        //
        // ⚠️⚠️ **LE RANG NE PEUT PAS SE LIRE DANS `sets` À CET INSTANT.**
        // `settleSeries` juste au-dessus DIFFÈRE son écriture de 0,55 s (le
        // temps que les pièces volent) : la série qu'on vient de finir n'est
        // PAS encore `isDone`. Lu tel quel, le compteur donnait le rang de la
        // série PRÉCÉDENTE, et toute la table de rendez-vous glissait d'un
        // cran — le MOMENT tombait à la 4ᵉ série au lieu de la 3ᵉ, la pop-up
        // à la 6ᵉ, la vidéo rare à la 11ᵉ. Pire, la pill SOUS-COMPTAIT de 20
        // pièces : « 20 coins this session » sur la 2ᵉ série.
        //
        // ⚠️ Et aucun banc ne pouvait le révéler : `-serieFin` passe son rang
        // EN DUR, donc il ne reproduit pas le décalage. Un bug qu'aucun banc
        // ne voit est un bug qui vit longtemps — celui-ci a vécu.
        //
        // La série en cours compte pour elle-même, sauf si elle était déjà
        // écrite (auquel cas `settleSeries` est sorti par sa garde et le
        // compte l'inclut déjà).
        let ecrites = sets.filter(\.isDone).count
        let dejaEcrite = sets.indices.contains(f.index) && sets[f.index].isDone
        let rang = max(dejaEcrite ? ecrites : ecrites + 1, 1)
        // Le rang est MÉMORISÉ, pas relu : entre la naissance de la pop-up
        // (+0,34 s) et l'écriture (+0,55 s), une lecture de `sets` changerait
        // de valeur SOUS la card — le compteur sauterait en pleine montée.
        rangIssue = rang
        let issue = DecideurSerie.pour(serie: rang,
                                       gain: gainParSerie,
                                       total: rang * gainParSerie,
                                       reps: f.reps, kilos: f.kilos)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            jouerIssue(issue, f)
        }
    }

    /// CE QU'UNE SÉRIE RAPPORTE — **lu, plus deviné.**
    ///
    /// ⚠️ Il valait `20` en dur, et c'était l'une des HUIT copies de
    /// `reward_rules.pieces_par_serie` côté app. Il vient maintenant
    /// d'`etat_coffre()`, avec le même 20 en défaut tant que le serveur n'a
    /// pas parlé — la loi du back-end : l'app LIT les prix, elle ne les
    /// connaît pas.
    private var gainParSerie: Int { EconomieWoop.shared.piecesParSerie }

    /// Le versement de connexion (§4 duodecies : 10 pièces, une fois par jour
    /// calendaire).
    ///
    /// ⚠️ **UNE CONSTANTE SWIFT QUI DOUBLE UNE RÈGLE SERVEUR EST UNE BOMBE À
    /// RETARDEMENT** — la loi du back-end est « l'app LIT les prix, elle ne
    /// les connaît pas », et celui-ci vit déjà en base
    /// (`reward_rules.pieces_retour_quotidien`). ✅ Le 30-08 au soir la copie
    /// « 10 » est morte : `etat_coffre()` rend le montant (20260830220000) et
    /// `EconomieWoop.piecesRetourQuotidien` le porte — l'atelier lit le même
    /// nombre que la vraie card, montée à la racine (`WoopApp.swift`).

    /// Ce que l'issue montre, et ce qu'elle laisse derrière elle.
    ///
    /// ⚠️ **UN SEUL CHEMIN VERS LE PANNEAU** : quoi qu'on montre, c'est sa
    /// fermeture qui pose la question « Recommencer ? ». Deux chemins, et on
    /// se retrouverait un jour avec la question par-dessus une pop-up.
    private func jouerIssue(_ issue: IssueSerie, _ f: FinishedSeries,
                           banc: Bool = false) {
        issueEnCours = issue
        switch issue {
        case .pill(let g, let t):
            withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                pillGain = (gain: g, total: t)
            }
            // ⚠️ AU BANC, LA PILL NE PART PAS. Elle ne vit que deux secondes,
            // et cette page met plus longtemps que ça à peindre au simulateur
            // (shaders + trois lecteurs) : sans ce gel, elle n'est jamais
            // capturable, donc jamais jugeable autrement que sur l'appareil.
            guard !banc else { return }
            // Elle n'interrompt RIEN : elle tient deux secondes et s'efface,
            // et la question arrive derrière elle sans qu'on ait rien tapé.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeIn(duration: 0.30)) { pillGain = nil }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                    poserLaQuestion()
                }
            }
        case .moment, .reward:
            rewardShow = true
        }
    }

    /// La question de la fin de série — le panneau à la flamme.
    private func poserLaQuestion() {
        guard let f = serieAPoser else { return }
        serieAPoser = nil
        issueEnCours = nil
        // Le rang s'efface AVEC son issue : sans ça, la prochaine ouverture
        // d'atelier hériterait du compte de la dernière série jouée.
        rangIssue = nil
        restartAsk = f
    }

    /// La sortie du panneau — les trois chemins (drag, « Non », « Lancer »)
    /// passent ici.
    private func exitRestart(_ f: FinishedSeries, thenLaunch: Bool) {
        restartAsk = nil
        if thenLaunch {
            // Le cadran couvre la scène dans un instant : la carte s'écrit
            // sans cérémonie — les pièces n'ont de sens qu'à l'air libre.
            settleSeries(f, coins: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) {
                launchPosed()
            }
        } else {
            settleSeries(f, coins: true)
            declencherRewardFlow()
        }
    }

    /// L'écriture de la série, et sa lumière : la volée de pièces part
    /// d'abord, la carte s'allume quand elles se posent.
    ///
    /// ⚠️⚠️ **ELLE N'ÉCRIVAIT QUE DANS UN `@State`, ET C'ÉTAIT LA RACINE DE
    /// TOUTE L'ÉCONOMIE MORTE** (audit du 29-08). `sets` est un tableau de
    /// VALEURS (`[DraftSet]`, une `struct`) : une série finie vivait dans la
    /// vue et mourait avec elle. Les cinq seules écritures SwiftData de ce
    /// fichier sont dans `add(_:)`, atteignable par le seul `save()`, appelé
    /// par le seul `primaryAction` — **qui est le bas d'écran du CARDIO**
    /// (il vit dans le `else` de `if isStrength`). En musculation il n'y a
    /// pas de bouton « Enregistrer », il y a le galet : `save()` n'était
    /// jamais atteint.
    ///
    /// La cascade, mesurée : aucun `StrengthSet` créé → `Workout.setCount`
    /// vaut 0 → `gain = setCount × 20` vaut 0 → pas de notification, pas de
    /// trophée, pas de proposition de sachet (`guard gain > 0`), et
    /// `reglerFinDeSeance` sortait sur sa garde **sans jamais appeler
    /// `cloturer_seance`**. Le tuyau serveur était juste, et aucune séance
    /// réelle ne le déclenchait. Le solde du coffre, lui, comptait
    /// `completedSets` : zéro, à vie.
    ///
    /// ⚠️ **ET C'EST `-demoData` QUI L'A CACHÉ** : la démo sème des
    /// `StrengthSet` (WoopApp:1745). Le banc avait des séries, l'app n'en
    /// avait pas — le seul régime où le bug ne se voit pas est celui où on
    /// juge.
    private func settleSeries(_ f: FinishedSeries, coins: Bool) {
        guard sets.indices.contains(f.index), !sets[f.index].isDone
        else { return }
        let write = {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) {
                sets[f.index].reps = f.reps
                sets[f.index].weight = f.kilos
                sets[f.index].isDone = true
                sets[f.index].durationSeconds = f.seconds
            }
            // ⚠️ **APRÈS le brouillon, jamais avant** : c'est le brouillon qui
            // porte la garde d'unicité (`!sets[f.index].isDone` en tête de
            // cette fonction). Ancrer d'abord, ce serait ouvrir la porte à
            // deux séries pour un seul geste si l'écriture différée était
            // rejouée.
            ancrerSerie(f.index)
        }
        if coins {
            coinsAt = .now
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55,
                                          execute: write)
        } else {
            write()
        }
    }

    /// L'ANCRAGE — la série du brouillon devient une série de la SÉANCE.
    ///
    /// C'est le pont qui manquait entre `@State sets` et SwiftData. Il est
    /// INCRÉMENTAL, là où `add(_:)` est un dépôt en bloc : en musculation il
    /// n'y a pas de moment « j'enregistre l'exercice », il y a une suite de
    /// séries qui tombent une à une. Chacune s'écrit à l'instant où elle est
    /// faite — donc une app tuée en pleine séance ne perd que la série en
    /// cours, pas la séance.
    ///
    /// ⚠️ **UN PASSAGE DANS LA FICHE = UN BLOC**, et c'est exactement la
    /// règle d'`add(_:)` (qui crée toujours un `LoggedExercise` neuf). Le bloc
    /// est retenu dans `bloc` pour la durée de la vue : les séries suivantes
    /// s'y ajoutent. Ressortir et revenir sur le même exercice ouvre un
    /// second bloc — c'est voulu, deux passages sont deux passages.
    ///
    /// ⚠️ **LA SÉANCE PEUT NE PAS EXISTER**, et on la crée alors, exactement
    /// comme `add(_:)` : ouvrir une fiche et faire une série DÉMARRE une
    /// séance. Ne pas le faire, ce serait perdre le travail de quelqu'un qui
    /// s'est mis à sa barre sans passer par la home.
    ///
    /// ⚠️ **LA SÉRIE ARRIVE COCHÉE.** Elle a été faite au compteur, pas
    /// prévue — c'est la loi déjà écrite dans `StrengthSet.isDone` et dans
    /// `add(_:)`. C'est aussi ce qui réconcilie les deux définitions du gain :
    /// `setCount` (les prévues) et `completedSets` (les faites) ne peuvent
    /// plus diverger sur ce qui vient d'ici.
    private func ancrerSerie(_ index: Int) {
        guard isStrength, sets.indices.contains(index) else { return }
        let d = sets[index]

        let seance: Workout
        if let active {
            seance = active
        } else {
            seance = Workout()
            context.insert(seance)
        }

        let logged: LoggedExercise
        if let deja = bloc, deja.workout === seance {
            logged = deja
        } else {
            logged = LoggedExercise(exerciseID: exercise.id,
                                    order: seance.exerciseCount,
                                    restSeconds: restSeconds)
            logged.workout = seance
            context.insert(logged)
            bloc = logged
        }

        let entry = StrengthSet(reps: d.reps, weight: d.weight,
                                order: logged.orderedSets.count,
                                isDone: true,
                                durationSeconds: d.durationSeconds)
        entry.loggedExercise = logged
        context.insert(entry)
        try? context.save()
        // ⚠️ **CETTE TRACE EST LA PREUVE, ET ELLE RESTE.** Le défaut qu'elle
        // surveille est INVISIBLE à l'écran : la pill affichait « +20 » et la
        // séance restait vide. Un compte qui monte ici est la seule façon de
        // savoir que la série a touché le disque — et `-demoData` sème des
        // séries, donc le banc ne peut pas révéler l'absence tout seul.
        print("[flow] série ancrée : exo=\(exercise.id) "
              + "bloc=\(logged.orderedSets.count) "
              + "séance=\(seance.seriesPayantes) payantes "
              + "(\(seance.setCount) écrites)")

        // L'orbe de la Live Activity avance à chaque série — c'est le geste
        // que `ActiveWorkoutView` faisait, dans la vue qui n'est montée nulle
        // part.
        WorkoutActivityController.ensure(seance)
        WorkoutActivityController.sync(seance)
    }

    /// LA PORTE POSÉE : le cadran naît directement à demeure — pas de
    /// plongée, pas de sommet à gravir. Le panneau descend, le cadran
    /// s'éclaire en fondu, et c'est LUI qui compte 3-2-1 avant de lancer
    /// le temps (l'allumage du repos, rebranché sur l'effort).
    private func launchPosed() {
        rangeCarte()
        let index: Int
        let appended: Bool
        if let pending = sets.firstIndex(where: { !$0.isDone }) {
            index = pending
            appended = false
        } else {
            sets.append(DraftSet(reps: sets.last?.reps ?? 12,
                                 weight: sets.last?.weight ?? 20))
            index = sets.count - 1
            appended = true
        }
        posedLaunch = true
        summited = true
        lensShown = true
        withAnimation(.easeOut(duration: 0.40)) {
            running = RunningSeries(id: index, appended: appended)
        }
        launchBeat += 1
    }

    // MARK: Historique

    /// La dernière fois que cet exercice a été fait, séance en cours exclue.
    private var lastLogged: LoggedExercise? {
        for workout in workouts where !workout.isActive {
            if let logged = workout.orderedExercises.first(where: { $0.exerciseID == exercise.id }) {
                return logged
            }
        }
        return nil
    }

    /// Ce qui a été fait la dernière fois sur cet exercice.
    private var lastTime: String? {
        guard let logged = lastLogged else { return nil }
        guard !logged.orderedSets.isEmpty else { return logged.summary }
        let count = logged.orderedSets.count
        let reps = logged.orderedSets.first?.reps ?? 0
        let weight = logged.maxWeight
        return "\(count) × \(reps) à \(weight.formatted(.number.precision(.fractionLength(0...1)))) kg"
    }

    // MARK: Enregistrement

    /// Enregistrer ne quitte PAS la fiche. On confirme, on repart d'une série
    /// vierge réglée sur les derniers chiffres, et on reste là.
    private func save() {
        var draft = LoggedDraft()
        switch exercise.tracking {
        case .setsRepsWeight:
            draft.sets = sets
            draft.restSeconds = restSeconds
        case .intervals:
            // Le cycle est construit une fois puis répété autant de fois que demandé.
            draft.cycles = Array(repeating: phases, count: max(repeatCount, 1))
        case .steady:
            draft.cycles = [[DraftPhase(kind: .recuperation,
                                        seconds: steadySeconds, speed: steadySpeed)]]
            draft.incline = incline
        }
        add(draft)

        if isStrength {
            // On repart de zéro série : la carte redit « 0 série en cours »,
            // et le prochain geste en fera naître une.
            withAnimation(.easeOut(duration: 0.25)) { sets = [] }
        }
    }

    /// Ajoute l'exercice à la séance en cours, en la créant si besoin.
    private func add(_ draft: LoggedDraft) {
        let workout: Workout
        if let active {
            workout = active
        } else {
            workout = Workout()
            context.insert(workout)
        }

        let logged = LoggedExercise(exerciseID: exercise.id,
                                    order: workout.exerciseCount,
                                    restSeconds: draft.restSeconds)
        logged.workout = workout
        context.insert(logged)

        for (index, set) in draft.sets.enumerated() {
            // Une série lancée au compteur arrive déjà cochée, avec son temps
            // sous tension : elle a été faite, pas seulement prévue.
            let entry = StrengthSet(reps: set.reps, weight: set.weight, order: index,
                                    isDone: set.isDone,
                                    durationSeconds: set.durationSeconds)
            entry.loggedExercise = logged
            context.insert(entry)
        }

        for (cycleIndex, cycle) in draft.cycles.enumerated() {
            for (order, phase) in cycle.enumerated() {
                let entry = CardioPhase(kind: phase.kind, seconds: phase.seconds,
                                        speed: phase.speed, cycleIndex: cycleIndex,
                                        order: order, incline: draft.incline)
                entry.loggedExercise = logged
                context.insert(entry)
            }
        }

        try? context.save()
        WorkoutActivityController.ensure(workout)
        withAnimation(.easeOut(duration: 0.25)) {
            confirmation = "Ajouté à ta séance en cours"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation { confirmation = nil }
        }
    }
}

// MARK: - Le halo du header (musculation)

/// LA LUMIÈRE DU HAUT DE FICHE : une seule source, hors cadre, en haut à
/// droite. Elle remplace le cadrage de `bgAurora` le jour où la carte noire
/// est morte — voir `ExoHeaderGlow.metal`, qui raconte pourquoi aucun
/// recadrage de ce champ-là ne pouvait donner un dégradé.
///
/// La hauteur est celle de la LUMIÈRE, pas d'une bande : il n'y a pas de
/// bord bas à cacher, le champ arrive à zéro tout seul bien avant 340. Elle
/// est posée en `plusLighter` par la page — ce halo n'est pas un fond, il
/// ÉCLAIRE ce qui est déjà dessiné.
///
/// 30 Hz suffisent : la seule chose qui bouge est une respiration de 22 s.
struct ExoHeaderGlow: View {
    var height: CGFloat = 340

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                let t = Float(tl.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 4096))
                Rectangle()
                    .fill(.black)   // JAMAIS .clear : le `* color.a` avale tout
                    .colorEffect(ShaderLibrary.exoHeaderGlow(
                        .float2(geo.size.width, height),
                        .float(t)))
            }
        }
        .frame(height: height)
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }
}

// MARK: - La carte-braise du header

/// La bande embrasée du haut de page — et c'est une CARTE, pas un décor :
/// plus tard elle se DÉPLIERA (la référence todo-list : date, heure, Done).
/// D'où son nom et sa frontière nette ; l'ouverture viendra s'y brancher.
///
/// La matière n'est pas imitée, elle est REPRISE : `bgAurora`, le champ
/// embrasé de la connexion. L'aurore y vit dans le bas d'un écran entier —
/// on rend donc le champ à sa hauteur virtuelle (`fieldHeight`) et on n'en
/// CADRE que la tranche basse, la plus riche : les rideaux de feu remplissent
/// la bande, la crête brûle juste derrière les coins de la carte noire.
///
/// 30 Hz suffisent : c'est un fond, pas un geste sous le doigt.
struct HeaderEmberCard: View {
    /// Hauteur visible de la bande — à peine plus que le header : la carte
    /// noire commence vers 118 pt, ses coins mordent jusqu'à ~158. Une bande
    /// plus haute gaspille la crête derrière le noir, là où personne ne la
    /// voit (le premier cadrage brûlait ENTIÈREMENT sous la carte).
    var height: CGFloat = 150
    /// Hauteur virtuelle du champ dont on cadre le bas. Comprimé : la crête
    /// et ses rideaux remplissent la bande au lieu de s'étirer sur un écran.
    /// C'est la crête — le fil embrasé du bord bas du champ, PLEINE largeur —
    /// qui doit affleurer derrière les coins de la carte noire ; les rideaux,
    /// eux, sont capricieux et se massent d'un côté selon l'instant.
    var fieldHeight: CGFloat = 260

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                let t = Float(tl.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 4096))
                Rectangle()
                    .fill(.black)   // JAMAIS .clear : le `* color.a` avale tout
                    .frame(width: geo.size.width, height: fieldHeight)
                    .colorEffect(ShaderLibrary.bgAurora(
                        .float2(geo.size.width, fieldHeight),
                        .float(t),
                        .float2(0, 0)))
                    .frame(width: geo.size.width, height: height,
                           alignment: .bottom)
                    .clipped()
                    // LE LIT DE BRAISE : le champ respire sur de longues
                    // minutes et passe par des creux presque noirs — un
                    // header-carte doit brûler à CHAQUE instant. Trois nappes
                    // fixes en `plusLighter` garantissent le plancher de feu,
                    // centres enfouis sous la carte noire : seule leur épaule
                    // haute affleure, et l'aurore vivante module par-dessus.
                    // En overlay : jamais dans le jeu de layout.
                    .overlay(alignment: .bottom) {
                        ZStack(alignment: .bottom) {
                            Ellipse()
                                .fill(Color(red: 1.0, green: 0.52, blue: 0.14))
                                .frame(width: 520, height: 130)
                                .blur(radius: 50)
                                .opacity(0.42)
                                .offset(y: 60)
                            Ellipse()
                                .fill(Color(red: 0.95, green: 0.25, blue: 0.05))
                                .frame(width: 280, height: 95)
                                .blur(radius: 40)
                                .opacity(0.38)
                                .offset(x: -135, y: 48)
                            Ellipse()
                                .fill(Color(red: 1.0, green: 0.68, blue: 0.25))
                                .frame(width: 230, height: 80)
                                .blur(radius: 34)
                                .opacity(0.40)
                                .offset(x: 150, y: 44)
                        }
                        .blendMode(.plusLighter)
                    }
                    .clipped()
            }
        }
        .frame(height: height)
        .allowsHitTesting(false)
    }
}
