import SwiftUI
import SwiftData
import CoreText
import SceneKit

@main
struct WoopApp: App {
    let container: ModelContainer

    init() {
        // Les Inter (Woop/Fonts) s'enregistrent ici : l'Info.plist est généré
        // par Xcode, il n'y a pas de clé UIAppFonts où les déclarer.
        for url in Bundle.main.urls(forResourcesWithExtension: "otf", subdirectory: nil) ?? [] {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        do {
            container = try ModelContainer(
                for: Workout.self, LoggedExercise.self, StrengthSet.self, CardioPhase.self
            )
        } catch {
            fatalError("Impossible d'initialiser la base : \(error)")
        }
        if CommandLine.arguments.contains("-demoData") {
            DemoData.seedIfEmpty(in: container)
        }
        if CommandLine.arguments.contains("-demoForce") {
            DemoData.seedDemo(in: container)
        }
        #if DEBUG
        // LA PILE DE LA HOME NE S'AFFICHE QU'AVEC DES SÉANCES TERMINÉES, et
        // `seedIfEmpty` refuse de semer dès qu'il existe UNE séance, fût-elle
        // en cours. Une base contenant une seule séance active restait donc
        // coincée sur l'état vide, sans aucun moyen d'en sortir — et sans
        // cartes, ni le swap ni les stories ne sont atteignables.
        //
        // En debug, on ne s'en remet plus à un argument de lancement (qui
        // n'atteint pas l'app selon la façon dont elle est lancée) : on
        // GARANTIT quelques séances terminées. Rien n'est effacé, et la
        // condition est « aucune terminée », pas « base vide ».
        DemoData.seedDemoIfNoneFinished(in: container)
        #endif
        if CommandLine.arguments.contains("-activeWorkout") {
            DemoData.seedActiveWorkout(in: container)
        }
        // La LUT du ciel se génère en tâche de fond pendant le splash — au
        // premier rendu de la home, elle est déjà prête. (NebulaStrip n'est
        // plus chauffée : la carte Objectif est redevenue pure lumière.)
        NebulaNoise.warmUp()
        // La SDF du croissant : le splash s'ouvre DESSUS, en gros plan — elle
        // est donc chauffée à chaque lancement, et non plus seulement pour le
        // banc du monolithe. C'est la toute première chose que l'app dessine.
        MoonSDF.warmUp()
        // La fumée de la pièce : le SEUL pipeline encore froid du parcours
        // d'une séance — il n'existe que si un doigt se pose. Sur la page
        // BRAVO, dont toute la cérémonie est une fonction du temps mural, une
        // cuisson au premier tap ne fait pas saccader : elle fait SAUTER le
        // plan. Elle se cuit donc ici, comme la SDF du croissant.
        CoinSmokeWarm.warmUp()
        // ⚠️ **LE FOURNEAU** (26-08) — 3 pipelines chauffés sur 66, et aucun
        // cache vidéo pour 16 lecteurs : c'est une part directe du verdict
        // « les pages mettent trop de temps à apparaître, on dirait un
        // chargement ». Les shaders du chemin chaud se cuisent ici, en fond
        // de cale pendant le splash, et les boucles des onglets aussi.
        Fourneau.chauffer()
    }

    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .tint(.woopViolet)
                // LA BOÎTE NOIRE (05-09) — elle se balade, la sonde
                // enregistre. Éteinte, elle ne coûte RIEN : ni vue, ni
                // display link. Voir `SondeVol.swift`.
                .overlay {
                    if SondeVolBanc.actif { SondeVolHUD() }
                }
                .task {
                    if SondeVolBanc.actif { SondeVol.shared.demarrer() }
                }
        }
        .modelContainer(container)
        // ⚠️ **LE VIDAGE DE L'OUTBOX SE FAIT AU RETOUR AU PREMIER PLAN, ET
        // NULLE PART AILLEURS.** C'est le seul instant où trois choses sont
        // vraies à la fois : l'app est vivante, le réseau a eu une chance de
        // revenir, et l'utilisatrice ne regarde encore rien de précis. Le
        // faire au lancement seulement raterait le cas le plus courant —
        // séance finie dans le métro, app revenue à la surface deux stations
        // plus loin sans jamais avoir été tuée.
        .onChange(of: phase) { _, nouvelle in
            guard nouvelle == .active else { return }
            Task {
                await OutboxGains.semer()          // banc `-outboxSemer`
                // ⚠️ LE +10 NE PART PLUS D'ICI (30-08 soir) : il part AU TAP
                // du bouton Claim de la card Welcome Back, qui s'ouvre plus
                // bas si le serveur dit que le jour est encore à prendre.
                await OutboxGains.shared.vider()
                // ⚠️ **APRÈS le vidage, jamais avant.** La file peut porter
                // une clôture de séance faite hors ligne : relire le solde
                // avant de la jouer, ce serait afficher l'ancien — et le
                // corriger sous les yeux de quelqu'un une seconde plus tard.
                await EconomieWoop.shared.rafraichir()
                // LA PORTE DU WELCOME BACK — la home, au premier plan, une fois
                // par jour de la maison : `retour_disponible` est LU sans payer
                // (M1), donc la card ne promet que ce qu'elle peut encaisser.
                // Jamais par-dessus une séance en cours ni un manège.
                let eco = EconomieWoop.shared
                if eco.serveur, eco.retourDisponible,
                   !SacreEtat.shared.manegeOuvert, !SacreEtat.shared.popupOuverte {
                    DepartEtat.shared.welcomeOuverte = true
                }
            }
        }
    }
}

// MARK: - Racine

enum WoopTab: String, Hashable {
    /// Le calendrier a fusionné dans Progression : il y vit sous les courbes.
    /// Profil prend sa place — à quatre onglets, deux de chaque côté, le bouton
    /// de séance tombe exactement au centre de la barre.
    ///
    /// ⚠️ **PROGRESSION EST ARCHIVÉE (04-09, Kathryn)** — trois onglets :
    /// Accueil · Exercices · Profil. La page, son calendrier et son iPod
    /// restent DANS LE CODE (rejouables par `-progressLab`) mais n'ont
    /// plus de porte, comme `HomeAuroraView` avant eux.
    ///
    /// Les rangs `calendar` ET `progress` ont DISPARU du jeu : une install
    /// qui les avait retenus dans `openTab` ne les retrouve plus, et
    /// `WoopTab(rawValue:)` rend `nil`. La migration les rattrape
    /// explicitement plutôt que de laisser le repli silencieux ramener
    /// l'utilisatrice à l'accueil sans raison.
    case home, exercises, profile
}

struct RootView: View {
    /// Banc d'essai de l'ANCIEN splash (bouteille et diablotin), gardé en
    /// archive : `-splashTest`. Il ne s'ouvre plus au lancement — la lune a
    /// pris sa place — mais la séquence reste rejouable telle quelle.
    private static let splashTest = CommandLine.arguments.contains("-splashTest")
    /// Banc du splash de la lune : `-moonSplashLab`, la cinématique en boucle
    /// avec un bouton « Rejouer ». `-moonSplashFreeze <t>` fige un instant.
    private static let moonSplashLab = CommandLine.arguments
        .contains("-moonSplashLab")
    /// Banc d'essai de la Live Activity : `-cometTest` affiche les composants
    /// de l'écran verrouillé (comète-progression, diablotin) dans l'app —
    /// le simulateur ne sait pas montrer l'écran verrouillé.
    private static let cometTest = CommandLine.arguments.contains("-cometTest")
    /// Banc d'essai du bouton CONNEXION : `-buttonLab`, page noire nue.
    private static let buttonLab = CommandLine.arguments.contains("-buttonLab")
    /// Banc du bouton primaire NOIR (30-08) : `-boutonLab` — repos, appui
    /// forcé, glyphe, et le diamant d'avant pour comparer.
    private static let boutonLab = CommandLine.arguments.contains("-boutonLab")
    /// Banc d'essai de la carte Objectif : `-cardLab`, page noire nue.
    private static let cardLab = CommandLine.arguments.contains("-cardLab")
    /// Banc d'essai du DOUBLON obsidienne de la carte Objectif :
    /// `-obsidianLab`, page noire nue.
    private static let obsidianLab = CommandLine.arguments.contains("-obsidianLab")
    /// Banc d'essai du bouton primary néon : `-neonLab`, page noire nue.
    private static let neonLab = CommandLine.arguments.contains("-neonLab")
    /// Banc d'essai du cadran éclipse : `-counterLab`, page noire nue.
    private static let counterLab = CommandLine.arguments.contains("-counterLab")
    /// La connexion aurore ouverte NUE, sans callback : `-loginLab`. Ce n'est
    /// plus un banc — c'est le vrai écran d'entrée, juste isolé pour le régler.
    private static let loginLab = CommandLine.arguments.contains("-loginLab")
    /// ARCHIVE de l'ancien écran d'authentification — la nébuleuse vivante,
    /// l'aura des sphères, les yeux du diablotin : `-authNebula`. Il ne fait
    /// plus partie du parcours (la connexion aurore l'a remplacé) mais il a
    /// coûté trop cher pour être supprimé, et il reste rejouable tel quel.
    private static let authNebula = CommandLine.arguments.contains("-authNebula")
    /// Banc de la flamme bijou : `-flameLab`, page noire nue — l'objet 3D
    /// qui danse, pivote au doigt, et fume au tap.
    private static let flameLab = CommandLine.arguments.contains("-flameLab")
    /// Banc de la flamme-jauge : `-jaugeLab`, page noire nue — la carte
    /// « Séries » au néon orange, cinq flammes qui s'allument en boucle.
    private static let jaugeLab = CommandLine.arguments.contains("-jaugeLab")
    /// Banc d'essai du monolithe logo : `-logoLab`, page noire nue.
    private static let logoLab = CommandLine.arguments.contains("-logoLab")
    /// Banc du calendrier à stickers : `-calLab` — la carte de verre qui
    /// se replie au scroll de la liste des sessions. `-calAuto` : boucle
    /// vidéo ; `-calTune` (ou double-tap) : la console du verre.
    private static let calLab = CommandLine.arguments.contains("-calLab")
    /// Banc de la page PROGRESS v2 : `-progressLab` — la page seule (le plan
    /// `tools/progress/PLAN-PROGRESS-V2.md`, ses drapeaux dans `ProgressBanc`).
    private static let progressLab = CommandLine.arguments.contains("-progressLab")
    /// Banc de la Duolinguo_page « LE CHEMIN DE FEU » : `-duoLab`, la colonne
    /// des cinq écrans seule. `-duoEcran <1-5>`, `-duoFreeze`, `-duoAuto`
    /// sont lus dans la vue (tools/duolingo/PLAN-DUOLINGUO.md).
    private static let duoLab = CommandLine.arguments.contains("-duoLab")
    /// Banc d'essai de la barre d'onglets bijou : `-navLab`, page nue. Double
    /// toucher pour cacher le panneau de fouettage.
    private static let navLab = CommandLine.arguments.contains("-navLab")
    /// Banc d'essai de la home aurora : `-homeLab` (+ `-demoData` pour les
    /// cartes). L'ancienne home noire reste la vraie.
    private static let homeLab = CommandLine.arguments.contains("-homeLab")
    /// Banc de la home v2 « chambre noire » : `-homeV2` — le noir et le rasant
    /// de gauche, SEULS (jalon 1 du plan `tools/home-v2/PLAN-HOME-V2.md`).
    /// `-rasantLab` ajoute la console de fouettage, `-rasantTemoin` pose la
    /// phrase en témoin, `-rasantFreeze <t>` fige l'horloge.
    /// ⚠️ TOUS les drapeaux de ce chantier ouvrent la page. `-phraseLab` seul
    /// ne le faisait pas : il lançait l'app normale (la home aurora), et on
    /// croyait le banc cassé alors qu'on regardait l'ancienne page.
    private static let homeV2 = ["-homeV2", "-rasantLab", "-phraseLab",
                                 "-isoRasant", "-galetOuvert", "-galetPur",
                                 "-galetFantome", "-galetNourri",
                                 "-galetCuisson", "-fondRasant",
                                 "-semaineMaterialise", "-semaineFaits",
                                 "-tirageFige", "-cardsLab",
                                 "-menuLab", "-menuRejoue",
                                 // le mode édition des widgets (la vitrine)
                                 "-editWidgets", "-editFige", "-editListe",
                                 "-editRefus", "-editSupprime",
                                 "-vitrineLab", "-vitrineAuto",
                                 "-vitrineChoisit", "-slots",
                                 "-widgetsVides"]
        .contains { CommandLine.arguments.contains($0) }
    /// Banc du fond aurora nu : `-bgLab` — noir, aurore basse, parallaxe 3D.
    private static let bgLab = CommandLine.arguments.contains("-bgLab")
    /// Banc de la fiche d'exercice : `-exoLab` ouvre la fiche du premier
    /// exercice du catalogue (+ `-activeWorkout` pour la pastille incrustée).
    private static let exoLab = CommandLine.arguments.contains("-exoLab")
    /// Banc du galet d'aube SEUL : `-galetLab` — la nuit, le dôme nacre au
    /// bord bas, rien d'autre (ni photo, ni titre, ni carte, ni flamme).
    /// `-galetFlood <u>` fige la course, `-galetT <s>` fige la respiration,
    /// `-galetMire` pose les graduations.
    private static let galetLab = CommandLine.arguments.contains("-galetLab")
    /// Banc de la lentille liquide : `-lensLab` — page papier, bulle de
    /// verre au bord bas, drag jusqu'à la cérémonie blanc → noir du cadran.
    /// `-lensFreeze <p>` fige la progression du drag (captures).
    private static let lensLab = CommandLine.arguments.contains("-lensLab")
    /// Banc de la flamme ember : `-emberLab`, page noire nue — la flamme
    /// emoji laquée, seule au centre. `-emberFreeze` fige le temps (captures).
    private static let emberLab = CommandLine.arguments.contains("-emberLab")
    /// Banc de la page BRAVO : `-bravoLab` — la pluie de pièces accélérée, le
    /// recul du cadrage, le gel, puis la saisie et les deux gestes.
    /// `-bravoAuto` rejoue en boucle, `-bravoFreeze` ouvre la page posée.
    private static let bravoLab = CommandLine.arguments.contains("-bravoLab")
    /// Banc de l'aube aux halos : `-haloLab` — page de lumière sans un
    /// pixel de noir, blanc du coin gauche, halos orange qui dérivent.
    private static let haloLab = CommandLine.arguments.contains("-haloLab")
    /// Banc de la page de succès : `-successLab` — le travelling rasant, la
    /// pose, le barillet des trois pastilles, la molette. `-successAuto`
    /// rejoue le cycle en boucle, `-successFreeze <t>` fige la partition,
    /// `-successFPS` loggue la cadence.
    private static let successLab = CommandLine.arguments
        .contains("-successLab")
    /// Banc de la page du trésor : `-coffreLab` — le gros plan du coffre qui
    /// vient se poser en haut, le titre, la pièce et le compte. Rejouable.
    private static let coffreLab = CommandLine.arguments.contains("-coffreLab")
    /// Banc de LA CHAMBRE AU TRÉSOR (coffre v2) : `-coffre2` — la page seule.
    /// `-coffreSansFilm` saute l'arrivée, `-coffreSkip` la passe toute seule à
    /// 2 s (le simulateur ne tape pas), `-coffreV1` rejoue l'ANCIENNE page.
    private static let coffre2 = CommandLine.arguments.contains("-coffre2")
    /// Banc de la pièce de lune : `-pieceLab` — l'anneau d'or, la laque et le
    /// croissant, tournables au doigt. `-pieceSmall` la montre aux tailles
    /// réelles du header, `-pieceFreeze <rad>` fige le lacet pour comparer
    /// deux tours de fouettage au MÊME angle.
    private static let pieceLab = CommandLine.arguments.contains("-pieceLab")
    /// Banc du RETOURNEMENT (chantier coffre v2, jalon C5) : `-coffreFlip` —
    /// une seule pièce, l'or d'un côté et la nuit de l'autre, qu'on retourne
    /// au pouce. `-coffreFlipAuto` la retourne toute seule (le sim ne pose pas
    /// de doigt), `-coffreFlipSol` la pose sur le sol de la chambre, et
    /// `-coffreFlipFige <deg>` impose le lacet pour des captures comparables.
    /// `-pieceCalibre` / `-pieceCalibreOr` posent la pièce SEULE au lacet de la
    /// référence : c'est la seule image que `tools/coffre-v2/compare_piece.py`
    /// sait noter.
    private static let coffreFlip = ["-coffreFlip", "-coffreFlipAuto",
                                     "-coffreFlipSol", "-pieceCalibre",
                                     "-pieceCalibreOr"]
        .contains(where: CommandLine.arguments.contains)
    /// Banc des stories : `-storyLab` — la carte noire qu'on tire vers le
    /// haut, le portail qui s'ouvre, puis les trois écrans. La carte revient
    /// à la fermeture, donc la cinématique se rejoue à volonté sans rien
    /// toucher — c'est la méthode maison pour juger un enchaînement.
    private static let storyLab = CommandLine.arguments.contains("-storyLab")
    /// Banc du sheet de saisie de série : `-setLab` — la molette fluide, les
    /// chips de repos et le slider à galet, au-dessus d'un faux cadran.
    private static let setLab = CommandLine.arguments.contains("-setLab")
    /// Banc de la carte-lune récompense : `-luneLab` — la carte-fenêtre
    /// (parallaxe de profondeur) sous son foil braise, inclinable au doigt,
    /// au gyroscope en main. `-luneTilt <tx,ty>` fige l'inclinaison,
    /// `-luneStill` coupe le balancement propre.
    private static let luneLab = CommandLine.arguments.contains("-luneLab")
    /// Banc de la page profil-collection : `-profilLab` — le halo versé de
    /// la droite, l'avatar-pastille, le trésor et les dos vides.
    private static let profilLab = CommandLine.arguments.contains("-profilLab")
    /// Banc du booster de récompense : `-boosterLab` — le sachet noir laqué
    /// au croissant, qu'on incline au doigt et qu'on ouvre en traçant la
    /// découpe braise sur la bande du haut ; la carte sort du sachet.
    /// `-boosterStill` fige le flottement, `-boosterTear <s>` fige une
    /// découpe entamée, `-boosterOpen` démarre carte présentée.
    private static let boosterLab = CommandLine.arguments.contains("-boosterLab")
    /// Banc du rideau PageCard : `-pageCardLab` — le player qui pousse la page
    /// (flou premium par snapshot, tranche 0, `tools/player/PLAN-PLAYER-CARD.md`).
    private static let pageCardLab = CommandLine.arguments
        .contains("-pageCardLab")
    /// Banc du carnet de cuir : `-carnetLab` — le carnet relié de la
    /// collection d'entraînements (chantier 18-08). `-carnetOuvert` montre
    /// la double page, `-carnetCote` le trois-quarts.
    private static let carnetLab = CommandLine.arguments.contains("-carnetLab")
    /// Banc de LA PORTE : `-porteLab` — l'entrée dans l'app (chantier 22-08,
    /// `tools/porte/PLAN-PORTE.md`). `-portePage <n>` fige une page,
    /// `-porteFlamme <v>` règle la descente de la flamme, `-porteAuto` balaie
    /// les quatre pages tout seul, `-porteArrivee` joue le film d'arrivée.
    private static let porteLab = CommandLine.arguments.contains("-porteLab")
    /// Banc de la LUNE DE SANG : `-luneSangLab` — les trois états tenus
    /// (3,40 s) en boucle à la demande ; `-luneSangFreeze <t>` fige un instant.
    private static let luneSangLab =
        CommandLine.arguments.contains("-luneSangLab")
    /// LA PORTE A-T-ELLE DÉJÀ ÉTÉ VUE ? Le film d'entrée (lune de sang +
    /// arrivée, 8,4 s) ne se paie qu'UNE fois : ensuite le carrousel s'ouvre
    /// directement sur sa boucle (l'arbitrage du 22-08, PLAN-PORTE.md § 8).
    /// ⚠️ LE REMÈDE `tutoExosVu` EST RECOPIÉ : en DEBUG la clé n'est jamais
    /// lue (sinon le film ne serait visible qu'une fois par installation —
    /// intestable) ; `-porteVue` force le raccourci en debug, `-porteNeuve`
    /// rejoue le premier lancement partout.
    private static let porteDejaVue: Bool = {
        if CommandLine.arguments.contains("-porteNeuve") {
            UserDefaults.standard.removeObject(forKey: "woop.porteVue")
            return false
        }
        #if DEBUG
        return CommandLine.arguments.contains("-porteVue")
        #else
        return UserDefaults.standard.bool(forKey: "woop.porteVue")
        #endif
    }()

    /// Le splash (la lune de sang) n'existe qu'au premier lancement : aux
    /// suivants la porte s'ouvre directement — on économise les 8,4 s
    /// (et les 13,95 s de l'ancien plan-séquence, passé en archive).
    @State private var showSplash = !RootView.porteDejaVue
    /// L'authentification suit le splash à CHAQUE lancement ; un toucher sur
    /// « Se connecter » fait entrer immédiatement. `-skipAuth` la court-circuite
    /// (captures d'écran automatisées uniquement).
    @State private var showAuth = !CommandLine.arguments.contains("-skipAuth")
    @State private var selection: WoopTab = {
        guard let raw = UserDefaults.standard.string(forKey: "openTab") else { return .home }
        // Le calendrier avait fusionné dans Progression ; Progression est
        // archivée à son tour (04-09) : les deux rangs morts retombent sur
        // l'ACCUEIL — explicitement, jamais par le repli silencieux.
        if raw == "calendar" || raw == "progress" { return .home }
        return WoopTab(rawValue: raw) ?? .home
    }()

    /// LE PARCOURS BOOSTER — l'état partagé, lu ici parce que le Manège
    /// se monte à la racine (voir `BoosterPopup.swift` : un onglet
    /// construit paresseusement n'entend aucune notification).
    private let sacre = SacreEtat.shared
    /// LE DÉPART DE SÉANCE — le panneau du galet play (même école).
    private let depart = DepartEtat.shared
    /// LES RÉCOMPENSES DU CHEMIN — la card à gratter, à la RACINE comme la
    /// route : montée dans un cover, elle masquerait la route et la pop-up
    /// booster (la loi payée au jalon 1).
    private let recompenses = RewardCheminEtat.shared
    /// Banc de mesure (jalon 1) : la home démontée sous la route.
    private static let cheminSeul = CommandLine.arguments.contains("-cheminSeul")
    /// LA HOME ÉCLIPSÉE sous le Sacre — EN DIFFÉRÉ : démonter le TabView
    /// dans la même transaction que le manège faisait tomber la
    /// désallocation de toute la home (~+0,7 s) EN PLEIN MILIEU de la
    /// cinématique de mise en place. L'éclipse attend que la roue soit
    /// posée (+2 s, sous le noir opaque) ; le remontage, lui, est
    /// SYNCHRONE à la fermeture — le profil doit exister avant l'arrivée
    /// de la carte (+0,45 s).
    @State private var homeEclipsee = false
    /// LA STORY DE FIN DE SÉANCE — posée 2 s après « Terminer », montée à la
    /// racine (`storyFinHote`) ; la notif des pièces et la card booster
    /// viennent à sa fermeture (`enchainerApresStory`).
    @State private var storyFin: StoryLaunch?

    /// L'entraînement ouvert, s'il y en a un.
    @Query(filter: #Predicate<Workout> { $0.endedAt == nil },
           sort: \Workout.startedAt, order: .reverse)
    private var activeWorkouts: [Workout]

    @Environment(\.modelContext) private var modelContext

    /// La feuille tient SA séance, pas « la séance ouverte » : à l'instant où on
    /// termine, il n'y a plus de séance ouverte — présentée sur un booléen, la
    /// feuille se viderait en plein récapitulatif.
    @State private var sheetWorkout: Workout?

    private var active: Workout? { activeWorkouts.first }

    /// L'ordre des onglets et leurs glyphes, tenus ici : la barre bijou parle
    /// en INDICE, le TabView en `WoopTab`, et ce pont est le seul endroit qui
    /// connaisse les deux.
    private static let order: [WoopTab] = [.home, .exercises, .profile]
    private static let tabItems: [(icon: String, label: String)] = [
        ("house.fill", "Accueil"),
        ("figure.strengthtraining.functional", "Entraînements"),
        ("chart.line.uptrend.xyaxis", "Progression"),
        ("person", "Profil"),
    ]
    private var tabIndex: Binding<Int> {
        Binding(get: { Self.order.firstIndex(of: selection) ?? 0 },
                set: { selection = Self.order[$0] })
    }

    /// L'horloge de la cinématique de connexion, ou `nil` hors cérémonie.
    @State private var cineStart: Date?
    /// La home arrive de trop près (1,28) et se pose en reculant.
    @State private var homeArriving = false
    /// La barre bijou monte du bas, en ressort, un temps après la page.
    @State private var barArriving = false
    /// La bouffée d'invite du galet, déclenchée à la pose de la barre.
    @State private var invitePulseAt: Date?

    @Environment(\.accessibilityReduceMotion) private var reduceMotionRoot

    /// CONNEXION touché : la lune se dissout en braises. L'aspiration part
    /// tout de suite (le fond draine, la caméra du shader se penche), le
    /// grondement aussi — son motif porte ses propres courbes, calées sur la
    /// même partition. La page bascule au CŒUR DE L'APNÉE, sans animation :
    /// plein noir derrière le nuage suspendu, qui ne bronche pas d'un pixel —
    /// la couture est introuvable. Puis la gravité reprend les braises et la
    /// home s'allume là où elles se posent.
    private func startConnexionCinematic() {
        guard cineStart == nil else { return }
        if reduceMotionRoot {
            // Ni caméra ni braises : un fondu sobre, et aucun grondement.
            withAnimation(.easeOut(duration: 0.5)) { showAuth = false }
            return
        }
        DiveRumble.shared.prepare()
        cineStart = .now
        DiveRumble.shared.play()
        DispatchQueue.main.asyncAfter(deadline: .now() + ConnexionCine.swapAt) {
            // L'horloge de l'aube se pose AVANT le montage : le `onAppear` de
            // la home la lit pendant le commit de la transaction — posée
            // après, il la manquait et le contenu naissait avec la nuit au
            // lieu d'attendre la lumière.
            HomeWelcome.start = .now
            var tx = Transaction()
            tx.disablesAnimations = true
            withTransaction(tx) {
                showAuth = false
                homeArriving = true
                barArriving = true
            }
        }
        // L'atterrissage se lance AVEC l'aube, pas à la coupe : pendant
        // l'apnée la home est une nuit immobile — rien ne doit y bouger.
        DispatchQueue.main.asyncAfter(deadline: .now() + ConnexionCine.barAt) {
            withAnimation(.easeOut(duration: 1.0)) { homeArriving = false }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                barArriving = false
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + ConnexionCine.breathAt) {
            invitePulseAt = .now
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + ConnexionCine.end + 0.2) {
            cineStart = nil
        }
    }

    /// Le galet play : il ouvre une séance. C'est lui qui a remplacé le bouton
    /// « Commencer un entraînement » de la home — et il démarre DIRECTEMENT,
    /// sans feuille de confirmation : une cérémonie qui demanderait ensuite
    /// « es-tu sûre ? » ne serait plus une cérémonie. Le geste reste
    /// réversible, « Annuler cette séance » vit dans l'overlay.
    /// La durée de la séance ouverte, en texte de bilan.
    private var dureeSeanceTexte: String {
        guard let a = active else { return "" }
        let m = max(1, Int(Date.now.timeIntervalSince(a.startedAt)) / 60)
        return "\(m) min"
    }

    /// LA CLÔTURE — le « Terminer » du panneau de pause. La séance se
    /// ferme, puis LA CHAÎNE DE FIN : la bascule home + le trophée
    /// (le onChange existant s'en charge via WoopCelebration), la notif
    /// des pièces (+20/série), et la pop-up booster qui propose le
    /// sachet gagné.
    private func terminerSeance() {
        guard let a = active else {
            // Jamais muet : la séance a disparu sous nos pieds (purge,
            // relance) — on referme ET on rend la home, plutôt qu'un
            // bouton qui ne fait rien.
            withAnimation(.easeOut(duration: 0.22)) {
                depart.pauseOuverte = false
            }
            withAnimation(.easeOut(duration: 0.3)) { selection = .home }
            return
        }
        // ⚠️⚠️ **`setCount` COMPTAIT LES SÉRIES PRÉVUES, ET LE COFFRE LES
        // FAITES.** Sur une séance à 5 séries dont 4 cochées, cette ligne
        // disait 100 et le solde comptait 80. La définition est tranchée dans
        // `Workout.seriesPayantes` — un seul endroit, une seule règle.
        // ⚠️ Et le taux vient du serveur : ce `20` était l'une des huit copies
        // de `reward_rules.pieces_par_serie`.
        let series = a.seriesPayantes
        let gain = series * EconomieWoop.shared.piecesParSerie
        print("[flow] terminerSeance : exos=\(a.exerciseCount) "
              + "séries=\(series) gain=\(gain)")
        withAnimation(.easeOut(duration: 0.22)) {
            depart.pauseOuverte = false
        }
        a.endedAt = .now
        try? modelContext.save()
        WorkoutActivityController.end()
        // LE TROPHÉE ET LE BOOSTER SE MÉRITENT : une séance sans une
        // seule série ne remplit rien et ne propose rien (l'économie
        // dit 20 pièces PAR SÉRIE — une séance vide vaut zéro).
        if gain > 0 { WoopCelebration.shared.workoutFinished() }
        // LA REDIRECTION EST EXPLICITE — jamais suspendue aux gardes
        // de la célébration (« il ne se passe rien » payé : Terminer
        // doit RAMENER À LA HOME, d'où qu'on vienne).
        withAnimation(.easeOut(duration: 0.3)) { selection = .home }
        // L'envoi part en fond — jamais le droit de bloquer la chaîne.
        let snapshot = a.snapshot()
        // ⚠️ **ÉTAPE 1 DU BRANCHEMENT DU COFFRE : ON ÉCRIT, PERSONNE NE LIT.**
        // `cloturer_seance` inscrit les pièces (séries × 20, le taux venant
        // du serveur) ET le sachet de fin de séance — forfaitaire, un par
        // session complète quel que soit le nombre de séries (28-08).
        //
        // ⚠️ **RIEN NE CHANGE À L'ÉCRAN**, et c'est le but : la notif « +240 »
        // et la proposition du sachet, juste en dessous, restent locales. On
        // remplit le journal avant de s'en servir — si c'est faux, rien ne
        // casse visiblement, et les écritures sont idempotentes.
        //
        // ⚠️ **APRÈS la synchro de la séance, dans la MÊME tâche** : l'ordre
        // n'est pas indifférent le jour où `workout_id` prendra une clé
        // étrangère. Deux `Task.detached` ne garantiraient aucun ordre.
        // ⚠️ **LE MÊME `series` QUE L'ANNONCE**, et c'est le fond du sujet :
        // le serveur ne doit pas recevoir une définition du gain que l'écran
        // n'a pas dite. Il lisait `setCount` (les prévues) pendant que le
        // solde comptait les faites.
        let seance = a.remoteID
        Task.detached {
            await SupabaseSync.shared.push([snapshot])
            await SacreServeur.reglerFinDeSeance(seance, series: series)
        }
        guard gain > 0 else { return }
        // LA PROMESSE LOCALE (PARCOURS-BOOSTER.md §7 : « promis localement et
        // réclamé au premier lancement connecté ») : le sachet de fin de
        // séance entre dans la réserve MAQUETTE tout de suite — sans compte,
        // hors ligne, la pill du profil et le coffre le montrent, « Later » ou
        // pas. Avec un compte, `boosters` lit le SERVEUR (`boostersServeur`,
        // + 1 quand `cloturer_seance` répond `booster_neuf`) et cette ligne
        // est invisible. Ce n'est PAS une écriture d'argent : un affichage.
        // ⚠️ Avant : `maquetteBoosters` naissait à 1 et n'était incrémenté
        // par PERSONNE — « Later » n'ajoutait rien (analyse 30-08, §3.6).
        EconomieWoop.shared.maquetteBoosters += 1
        // LA STORY DE FIN DE SÉANCE — « deux secondes après Terminer »
        // (tools/story/ANALYSE-VARIANTS-ET-FAITS.md §6 bis), le temps que la
        // home et le trophée (~+0,5 s) soient posés. La notif des pièces et
        // la card booster viennent APRÈS elle (`enchainerApresStory`) —
        // c'était +1,6 s et +5,2 s sur une home nue, avant qu'une story
        // existe dans la chaîne (verdict Kathryn 30-08 : « elle doit
        // apparaître après la story »).
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            storyGain = gain
            storyFin = StoryLaunch(workout: a, rect: .zero)
        }
    }

    /// Le gain à annoncer quand la story se ferme (posé avec elle).
    @State private var storyGain = 0

    /// APRÈS LA STORY : LA PILE (30-08 soir) — les pièces, puis le sachet
    /// forfaitaire, l'une sous l'autre (+0,3 s, puis +0,45 s d'écart), et la
    /// pièce d'argent / les sachets convertis quand `cloturer_seance` répond
    /// (`EconomieWoop.appliquer`) ; puis la card booster « Ouvrir » (+3,4 s).
    /// ⚠️ Le J3 du plan remplace ce chaînage par la page noire qui ATTEND la
    /// réponse, puis le chemin animé, puis « Ouvrir » — ici, l'empilement seul.
    private func enchainerApresStory() {
        let gain = storyGain
        storyGain = 0
        guard gain > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            FileAnnonces.shared.pousser([.pieces(gain), .sachet(1)])
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) {
            SacreEtat.shared.proposer()
        }
    }

    /// LA STORY DE FIN DE SÉANCE, montée à la racine — in-tree, comme le
    /// `MoisIpod` de l'onglet Progrès. Le portail s'ouvre depuis le centre
    /// (`rect: .zero` = le filet du portail : « une carte au centre ») et
    /// couvre tout. À sa fermeture — fin automatique, tap, ou tirage vers le
    /// bas — la chaîne continue. La fermeture se fait SANS animation SwiftUI
    /// (la grammaire de CalLab) : le portail a déjà joué la sienne.
    @ViewBuilder
    private var storyFinHote: some View {
        if let s = storyFin {
            StoryPortal(from: s.rect,
                        session: StorySession(workout: s.workout)) {
                var tx = Transaction()
                tx.disablesAnimations = true
                withTransaction(tx) { storyFin = nil }
                enchainerApresStory()
            }
            .zIndex(15)
        }
    }

    /// « COMMENCER » DEPUIS LE CHEMIN (jalon 1) — la séance s'ouvre en base
    /// (jamais un doublon : une seconde séance ouverte serait inaffichable),
    /// la route PART, puis l'onglet Exercices prend la scène (deux mouvements
    /// qui se suivent, jamais ensemble). ⚠️ Pas `startWorkout()` : il rouvre
    /// la vieille feuille noire si une séance existe déjà. La home, elle,
    /// lève sa card en voyant `enSeance` basculer.
    private func demarrerDepuisChemin() {
        if active == nil {
            let workout = Workout()
            modelContext.insert(workout)
            try? modelContext.save()
            WorkoutActivityController.ensure(workout)
        }
        depart.fermerChemin()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
            withAnimation(.easeOut(duration: 0.3)) { selection = .exercises }
        }
    }

    /// LE CHEMIN EN ARBRE (jalon 1) — la route quitte le `fullScreenCover` de
    /// la home pour vivre à la racine, zIndex 4 : sous la pause (5), la pop-up
    /// booster (6), le Manège (7) et la notif des pièces (9). Un cover cachait
    /// tout ce qui est monté ici — une lune qui appelait `proposer()` ouvrait
    /// la pop-up DERRIÈRE la route. Enveloppée dans `CheminHote` : le geste
    /// qui la tire vers la droite au doigt.
    @ViewBuilder private var cheminEnArbre: some View {
        if depart.cheminOuvert {
            // ⚠️ **LE NOIR ARRIVE AVANT LA ROUTE** (28-08, « on voit le fond
            // rouge de la home à l'arrivée sur le chapitre 1 »). La route
            // GLISSE depuis le bas : tant qu'elle n'a pas fini sa course, le
            // haut de l'écran montre encore la home — son aurore rouge. Ce
            // plan noir, lui, est monté SANS transition : il est là dès la
            // première image, et la route glisse sur du noir.
            Color.black
                .ignoresSafeArea()
                .allowsHitTesting(false)
                // ⚠️ `.identity`, SANS QUOI IL FOND LUI AUSSI. La transition
                // par défaut de SwiftUI est un fondu : ce plan serait arrivé
                // en fondu (donc translucide pendant que la route arrive) et
                // surtout il serait REPARTI en fondu — la home réapparaissant
                // au travers pendant que la route glisse. Il doit être opaque
                // dès la première image et jusqu'à la dernière.
                .transition(.identity)
                .zIndex(3.5)
            CheminHote(onSortie: { depart.fermerChemin(sansAnimation: true) }) {
                DuolinguoPage(etapeInitiale: depart.cheminEtape,
                              faits: depart.cheminFaits,
                              dates: depart.cheminDates,
                              reclamees: depart.reclamees,
                              onLune: cheminLune,
                              onPiece: cheminPiece,
                              onRetour: { depart.fermerChemin() },
                              onDemarrer: { demarrerDepuisChemin() })
                    .onAppear { print("[SONDE-CHEMIN] la page du chemin est MONTÉE") }
            }
            // ⚠️ **L'ARRIVÉE EST UN FONDU, LA SORTIE UN GLISSEMENT** (28-08,
            // « on voit encore un petit décalage qui vient du bas, l'animation
            // d'arrivée n'est pas assez fluide »).
            //
            // Le `.move(edge: .bottom)` translatait sur TOUTE la hauteur de
            // l'écran un sous-arbre qui porte 5 lecteurs vidéo et 45 galets à
            // lentille native : chaque image forçait la recomposition de tout
            // ça. Et le ressort qui le jouait (amortissement 0,88) DÉPASSE
            // puis revient — ce retour, c'était le « décalage ».
            //
            // Un fondu ne change AUCUNE géométrie : rien à remettre en page,
            // rien à ré-échantillonner. Il est légal ici depuis que le plan
            // noir opaque est posé dessous (c'est l'absence de ce plan, pas le
            // fondu, qui laissait fuir l'aurore rouge de la home).
            //
            // La SORTIE, elle, reste un glissement : opaque par construction,
            // elle ne peut jamais laisser transparaître la home.
            //
            // Et la beauté de l'arrivée ne vient pas du mouvement de la page —
            // elle vient de la CASCADE des galets, qui démarre à +0,5 s, juste
            // après la fin du fondu : noir, le décor se matérialise, les neuf
            // galets tombent.
            .transition(.asymmetric(insertion: .opacity,
                                    removal: .move(edge: .bottom)))
            .zIndex(4)
        }
    }

    /// Le nœud-lune s'est gravé dans la page ; la racine persiste, puis
    /// propose le booster — la pop-up existante, au-dessus de la route.
    // ⚠️ **LES DEUX RÉCOMPENSES PASSENT PAR LA MÊME CARD À GRATTER** (28-08,
    // jalon 7 bis enfin posé). Avant, la lune ouvrait la pop-up booster et la
    // pièce faisait descendre une capsule « +40 » — deux mises en scène
    // différentes, et un montant EN DUR.
    //
    // Maintenant les deux ouvrent la même card : on range Nosfy, on gratte la
    // lune, la récompense se révèle. Le montant, la monnaie et la combinaison
    // de boosters viennent du TIRAGE fait AU CLAIM — jamais de l'animation.
    // ⚠️ LE NŒUD N'EST MARQUÉ RÉCLAMÉ QU'APRÈS LE SERVEUR (30-08) : le tirage
    // vit chez lui, et un échec réseau doit laisser le galet DISPONIBLE, pas
    // un galet mort marqué réclamé pour rien. Elles RENDENT donc le verdict
    // à la page (relecture adverse) : la page grave le galet au tap pour la
    // sensation, et le DÉGRAVE sur `false` — sans ce retour, un échec
    // laissait un galet gravé, injoignable jusqu'au remontage de la route
    // (sa copie locale de `reclamees` ne se relit qu'à la naissance).
    private func cheminLune(_ id: Int) async -> Bool {
        let ok = await recompenses.reclamer(id, pieces: false)
        if ok { depart.reclamer(id) }
        return ok
    }

    private func cheminPiece(_ id: Int) async -> Bool {
        let ok = await recompenses.reclamer(id, pieces: true)
        if ok { depart.reclamer(id) }
        return ok
    }

    // ════════════════════════════════════════════════════════════════════
    // ⚠️ **CE QUI SUIT SORT DU `ViewBuilder`, ET C'EST VITAL** (27-08).
    //
    // `mainBody` était devenu une seule expression que le type-checker de
    // Swift n'arrivait plus à résoudre : **l'app ne compilait plus depuis un
    // état PROPRE** — ni sur l'appareil, ni au simulateur (« unable to
    // type-check this expression in reasonable time »). Les builds Xcode
    // quotidiens ne le voyaient pas : ils sont INCRÉMENTAUX et réutilisent le
    // cache. Concrètement, ni archive, ni TestFlight, ni un autre Mac ne
    // pouvaient construire Woop — c'est ce qui a bloqué le premier build
    // téléphone de la route.
    //
    // ⚠️ Le défaut est ANTÉRIEUR à la route : vérifié en reconstruisant
    // `WoopApp.swift` tel qu'il était avant (3f862a9) — même échec. Aucun
    // réglage du compilateur n'y fait (seuils de temps, de mémoire, de
    // portée ; mode fichier par fichier) : il faut DÉCOUPER.
    //
    // Rien ne change de comportement : le même code, sous un nom. La règle à
    // tenir désormais — **le corps d'une vue est une addition de vues
    // NOMMÉES, pas d'expressions imbriquées** : toute fermeture de plus de
    // deux lignes posée dans un appel du corps rapproche du mur.
    // ════════════════════════════════════════════════════════════════════

    /// La barre bijou est MORTE (la home v2 n'a plus de nav bar) : cette
    /// condition vaut toujours `false`, le code reste pour l'archive de la v1.
    private var barreBijouVisible: Bool {
        selection != .exercises && selection != .profile
            && selection != .home
    }

    /// Le menu de la home route vers un onglet.
    private func routerVers(_ dest: WoopTab) {
        withAnimation(.easeOut(duration: 0.3)) { selection = dest }
    }

    /// Le chevron d'une page immersive rend la main à la home.
    private func retourHome() {
        withAnimation(.easeOut(duration: 0.3)) { selection = .home }
    }

    /// Le galet play : séance ouverte, il RAMÈNE à la page exercices où vit
    /// le player (jamais la vieille feuille noire, morte au verdict) ; sinon
    /// il ouvre le panneau du départ.
    private func galetPlayTape() {
        if active != nil {
            withAnimation(.easeOut(duration: 0.3)) { selection = .exercises }
        } else {
            DepartEtat.shared.proposer()
        }
    }

    /// Le STOP universel : l'appui tenu sur le galet en séance ouvre
    /// « Terminer la séance ? ».
    private func galetPlayTenu() {
        guard active != nil else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
            depart.pauseOuverte = true
        }
    }

    /// La feuille de séance. « Annuler cette séance » la supprime pendant que
    /// la feuille se referme : on ne lit pas un objet déjà sorti de la base.
    @ViewBuilder private func feuilleSeance(_ workout: Workout) -> some View {
        if !workout.isDeleted {
            ActiveWorkoutSheet(workout: workout,
                               onAddExercise: {
                                   // On referme la feuille, PUIS — DÉFÉRÉ — on
                                   // ouvre la bibliothèque.
                                   //
                                   // ⚠️ NE JAMAIS changer `selection` au MÊME
                                   // tick que `sheetWorkout = nil`. Une `.sheet`
                                   // système met ~0,35 s à se refermer ; basculer
                                   // d'onglet pendant sa transition laisse son
                                   // conteneur de présentation ORPHELIN au sommet
                                   // de la fenêtre — invisible (fond verre
                                   // transparent d'ActiveWorkoutSheet), il mange
                                   // TOUS les touchers de la home (« je vois le
                                   // player, je peux plus rien faire »). Les deux
                                   // sœurs du fichier défèrent déjà leur second
                                   // mouvement (demarrerDepuisChemin, onStopViaPause) ;
                                   // celle-ci était la seule à ne pas le faire.
                                   sheetWorkout = nil
                                   DispatchQueue.main.asyncAfter(
                                       deadline: .now() + 0.35) {
                                       withAnimation(.easeOut(duration: 0.3)) {
                                           selection = .exercises
                                       }
                                   }
                               },
                               onStopViaPause: {
                                   // LE STOP DU PLAYER : la feuille se
                                   // retire, le panneau de pause monte —
                                   // « Terminer » y déclenche toute la
                                   // chaîne de fin (trophée, pièces,
                                   // booster).
                                   sheetWorkout = nil
                                   DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                       withAnimation(.spring(response: 0.42,
                                                             dampingFraction: 0.88)) {
                                           depart.pauseOuverte = true
                                       }
                                   }
                               })
        }
    }

    private func startWorkout() {
        guard active == nil else {
            // Une séance est déjà ouverte : le galet la RAMÈNE au lieu d'en
            // créer une seconde, que rien dans l'app ne saurait afficher.
            sheetWorkout = active
            return
        }
        let workout = Workout()
        modelContext.insert(workout)
        try? modelContext.save()
        WorkoutActivityController.ensure(workout)
        selection = .exercises
    }

    var body: some View {
        // LE BANC DES CARDS REWARD, EN TÊTE DE CHAÎNE : la card seule sur
        // du noir vrai, montée en deux secondes. Il passe avant tout le
        // reste parce qu'il ne veut RIEN dessous — ni splash, ni porte, ni
        // fiche exo (dont le halo orange traversait le scrim et polluait
        // le jugement, constaté sur capture le 27-08).
        if RewardBanc.actif {
            RewardLab()
        } else if NotifBanc.actif {
            // LE BANC DES NOTIFICATIONS — les deux dalles noires empilées
            // sur du noir vrai. Même raison que le banc reward : il ne veut
            // rien dessous.
            NotifLab()
        } else if Self.splashTest {
            splashBench
        } else if Self.moonSplashLab {
            moonSplashBench
        } else if Self.cometTest {
            cometBench
        } else if Self.storyLab {
            StoryLab()
        } else if Self.setLab {
            SetEntryLab()
        } else if Self.luneLab {
            CarteLuneLab()
        } else if Self.profilLab {
            ProfilLab()
        } else if Self.boosterLab {
            BoosterLab()
        } else if Self.carnetLab {
            CarnetLab()
        } else if Self.boutonLab {
            BoutonLab()
        } else if Self.buttonLab {
            ConnexionButtonLab()
        } else if Self.cardLab {
            ObjectiveCardLab()
        } else if Self.obsidianLab {
            ObsidianCardLab()
        } else if Self.neonLab {
            NeonPrimaryLab()
        } else if Self.counterLab {
            CounterLab()
        } else if Self.porteLab {
            PorteEntree()
        } else if Self.luneSangLab {
            LuneSangLab()
        } else if Self.loginLab {
            AuroraLoginView()
        } else if Self.authNebula {
            AuthView { _ in }
        } else if CommandLine.arguments.contains("-harmonie") {
            HarmonieLab()
        } else if CommandLine.arguments.contains("-menuLab")
                    || CommandLine.arguments.contains("-menuRejoue")
                    || CommandLine.arguments.contains("-couronneLab")
                    || CommandLine.arguments.contains("-couronneRejoue")
                    || CommandLine.arguments.contains("-couronneGrille") {
            MenuLab()
        } else if CommandLine.arguments.contains("-cardsLab") {
            CardsLab()
        } else if Self.homeV2 {
            HomeNuitLab()
        } else if Self.homeLab {
            HomeAuroraLab()
        } else if Self.bgLab {
            AuroraBgLab()
        } else if Self.galetLab {
            GaletLab()
        } else if Self.exoLab {
            NavigationStack {
                ExerciseDetailView(exercise: ExerciseCatalog.all[0])
            }
        } else if Self.lensLab {
            LiquidLensLab()
        } else if Self.haloLab {
            HaloDawnLab()
        } else if Self.successLab {
            SuccessLab()
        } else if Self.coffre2 {
            CoffreV2Lab()
        } else if Self.coffreLab {
            CoffreFortLab()
        } else if Self.coffreFlip {
            CoffreFlipLab()
        } else if Self.pieceLab {
            MoonCoinLab()
        } else if Self.bravoLab {
            BravoLab()
        } else if Self.emberLab {
            EmberFlameLab()
        } else if Self.jaugeLab {
            FlammeJaugeLab()
        } else if Self.flameLab {
            FlameLab()
        } else if Self.logoLab {
            LogoLab()
        } else if Self.navLab {
            NavLab()
        } else if Self.progressLab {
            ProgressLab()
        } else if Self.pageCardLab {
            PageCardLab()
        } else if Self.calLab {
            CalLab()
        } else if Self.duoLab {
            DuoLab()
        } else if StopBanc.actif {
            // Banc de la card STOP : `-stopLab`, la card SEULE sur du noir.
            // Ses prises vivent avec elle (`StopBanc`, dans StopCard.swift) —
            // pas de doublon de drapeau ici.
            StopLab()
        } else if TapisBanc.actif {
            // Banc du player tapis : `-tapisLab`, la scène SEULE sur du noir.
            // Ses prises vivent avec elle (`TapisBanc`, dans TapisLab.swift).
            TapisLab()
        } else if NavBanc.actif {
            // Banc de la nav d'encre : `-navEncre`, le rail SEUL sur du noir.
            // Son drapeau vit avec lui (`NavBanc`, dans NavEncre.swift).
            NavEncreLab()
        } else if PiluleBanc.actif {
            // Banc de la pilule vagabonde : `-piluleLab` (J1 du plan
            // NAV V2) — drag partout, pose bornée, tap/stop, doigt mort.
            PiluleLab()
        } else {
            mainBody
        }
    }

    /// Le banc d'essai de l'écran verrouillé : la comète démarrée il y a
    /// 12 minutes (traversée en 90), et le diablotin sous trois regards.
    private var cometBench: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 40) {
                ProgressComet(startedAt: .now.addingTimeInterval(-12 * 60))
                    .frame(height: 34)
                ProgressComet(startedAt: .now.addingTimeInterval(-45 * 60))
                    .frame(height: 34)
                HStack(spacing: 30) {
                    ImpGlyph(size: 26, gaze: .zero)
                    ImpGlyph(size: 26, gaze: CGSize(width: -1, height: 0.3))
                    ImpGlyph(size: 26, gaze: CGSize(width: 1, height: -0.5))
                    ImpGlyph(size: 17, gaze: CGSize(width: 0.6, height: 0))
                }
            }
            .padding(.horizontal, 24)
        }
    }

    /// Le banc du splash de la lune : la cinématique, PUIS l'écran sur lequel
    /// elle se pose — c'est le raccord entre les deux qui se juge, pas la
    /// séquence seule. Le monolithe reste tournable au doigt une fois posé.
    @ViewBuilder
    private var moonSplashBench: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // L'écran d'arrivée. Il n'est monté qu'à la fin : la cinématique
            // porte déjà sa propre aurore, et deux fonds plein écran vivants
            // en même temps ne serviraient qu'à manger le budget d'images.
            // Le raccord tient parce que les deux aurores lisent la MÊME
            // horloge (temps absolu modulo 900 s) : elles sont en phase, quoi
            // qu'il arrive.
            if !showSplash {
                AuroraLoginView()
            }

            if showSplash {
                MoonSplashView {
                    withAnimation(.easeOut(duration: 0.45)) { showSplash = false }
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .overlay(alignment: .topTrailing) {
            if !showSplash {
                Button {
                    showSplash = true
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.inkPrimary)
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .padding(.trailing, 16)
                .padding(.top, 56)
            }
        }
    }

    /// Le banc d'essai : rien que le splash, en boucle à la demande.
    @ViewBuilder
    private var splashBench: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if showSplash {
                SplashView {
                    withAnimation(.easeOut(duration: 0.4)) { showSplash = false }
                }
            } else {
                Button {
                    showSplash = true
                } label: {
                    Label("Rejouer", systemImage: "arrow.counterclockwise")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color.inkPrimary)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }
        }
    }

    /// L'OUVERTURE DU GRAND PLAYER — 0 fermé, 1 ouvert (la même valeur
    /// continue qu'au banc : il MONTE du bas, rien ne grandit).
    @State private var morphPlayer: CGFloat = 0

    private func ouvrirGrandPlayer() {
        Haptique.leger()
        // ⚠️ LA CORDE QUE PERSONNE NE TIRAIT (05-09, audit + lecture).
        // `PlayerEtat.couvre` a QUATRE lecteurs — les deux vidéos de
        // l'accueil, celle des exercices, la page Progression — et il
        // veut dire « un player me recouvre, taisez-vous ». L'ANCIEN
        // player l'armait (`PlayerMonde.swift:64`) ; le nôtre, jamais.
        // Résultat : player plein écran ouvert, les vidéos continuaient
        // de tourner DERRIÈRE lui. C'est la loi du rideau, à l'échelle
        // de l'app, et ça coûtait une ligne.
        PlayerEtat.shared.couvre = true
        withAnimation(.spring(response: 0.62, dampingFraction: 0.86)) {
            morphPlayer = 1
        }
    }

    /// LA PARTITION RÉELLE — l'exercice courant en tête, puis les autres
    /// (le même contrat que l'ancien player : elle n'est JAMAIS vide).
    private func groupesDeSeance(_ a: Workout) -> [SlateGroupe] {
        let lignes = a.orderedExercises
        guard !lignes.isEmpty else {
            return [SlateGroupe(id: "courant",
                                exercise: ExerciseCatalog.all[0],
                                rows: [SlateLigne(reps: 12, kilos: 20,
                                                  seconds: 60,
                                                  done: false)])]
        }
        return lignes.compactMap { le in
            guard let exo = le.exercise else { return nil }
            return SlateGroupe(id: le.exerciseID, exercise: exo,
                               rows: le.orderedSets.map {
                SlateLigne(reps: $0.reps, kilos: $0.weight,
                           seconds: $0.isDone ? $0.durationSeconds
                               : le.restSeconds,
                           done: $0.isDone)
            })
        }
    }

    /// LE CONTENU DE LA PILULE — les vraies données de la séance, dans
    /// la robe validée au banc : la mini-card du jour, le nom de
    /// l'exercice courant (ou l'invite animée), le chrono, le stop.
    @ViewBuilder
    private func contenuPilule(_ a: Workout) -> some View {
        let exo = a.orderedExercises.first?.exercise
        HStack(spacing: 10) {
            MiniCardJour(date: a.startedAt ?? .now,
                         sticker: WoopSticker.pour(a).asset)
                .scaleEffect(0.80)
                .frame(width: 68, height: 68)
                .frame(width: 74, height: 76)
            VStack(alignment: .leading, spacing: 3) {
                if let e = exo {
                    Text(e.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.95))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                } else {
                    // Elle se tait sous le doigt (cause n° 7) — la loi de
                    // la maison : rien ne s'anime pendant un geste.
                    InviteAnimee(taille: 17,
                                 fige: PiluleEtat.shared.enMouvement
                                     || morphPlayer > 0.98)
                        .minimumScaleFactor(0.8)
                }
                TimelineView(.periodic(from: a.startedAt ?? .now, by: 1)) { tl in
                    let s = max(0, Int(tl.date
                        .timeIntervalSince(a.startedAt ?? .now)))
                    Text("In session · \(s / 60):\(String(format: "%02d", s % 60))")
                        .font(.system(size: 13))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            MedaillonStop(lueur: true, action: {
                DepartEtat.shared.pauseOuverte = true
            })
                .scaleEffect(1.22)
                .frame(width: 60, height: 60)
        }
        .padding(.leading, 12)
        .padding(.trailing, 14)
    }

    private var mainBody: some View {
        ZStack {
            // « Un seul ciel » : horloge globale (temps absolu modulo 900 s)
            // + état partagé SkyState (scroll, révélation, gyro) — chaque
            // onglet rend EXACTEMENT les mêmes pixels, et changer d'onglet ne
            // change rien au ciel. Un onglet caché n'est pas rendu : le coût
            // GPU reste celui d'une seule instance.
            // L'ACCUEIL N'EST MONTÉ QUE QUAND IL PEUT ÊTRE VU. SwiftUI ne
            // supprime pas le rendu d'un frère occulté : pendant les treize
            // secondes du splash, tout le ciel de la home tournait DERRIÈRE —
            // nébuleuse plein écran, champ d'étoiles en `plusLighter` (une
            // passe hors écran), grain, shaders des cartes — en concurrence
            // directe avec le plan-séquence, et CoreMotion réveillait le fil
            // principal trente fois par seconde par-dessus. Le socle noir
            // ci-dessous prouvait déjà qu'aucun de ces pixels n'était visible.
            // Les `onAppear`/`task` du cycle de vie sont accrochés au ZStack,
            // pas au TabView : ils gardent leurs horaires.
            // MÊME LOI SOUS LE MANÈGE : le Sacre est un écran noir plein
            // cadre — la home qui continuait de rendre derrière (nébuleuse,
            // étoiles, shaders) volait le fil principal et le GPU du
            // carrousel, une contention que les bancs (montés seuls) ne
            // voyaient jamais. L'éclipse est DIFFÉRÉE (+2 s, cf.
            // `homeEclipsee`) pour laisser la cinématique de mise en
            // place se jouer sans la désallocation de la home dans les
            // pattes ; le remontage est SYNCHRONE à la fermeture : le
            // profil existe avant que l'arrivée (+0,45 s) soit posée.
            // `-cheminSeul` (banc de mesure, jalon 1) : la home DÉMONTÉE sous
            // la route — isole le coût du résidu de la home de celui de la
            // route dans la racine.
            // ⚠️ L'ÉCRAN NU — L'INSTRUMENT DE BISSECTION (05-09).
            // Sa balade dit : accueil IMMOBILE, 60 img/s, et pourtant
            // 27 à 29 % de processeur en continu et l'état thermique 2.
            // Une page statique devrait être à 2 %. Éteindre un moteur à
            // la fois sur un téléphone déjà bridé ne prouve RIEN (mesuré :
            // quatre barreaux, quatre résultats dans le bruit thermique).
            // `-ecranNu` remplace TOUT le contenu par du noir, la sonde
            // restant allumée : la mesure donne le PLANCHER du châssis.
            //   · plancher bas  → tout le coût est dans les pages ;
            //   · plancher haut → il est dans la racine (mondes montés,
            //     décodeurs, sonde elle-même) et les pages sont hors de
            //     cause. Une mesure, et la moitié des suspects tombe.
            if EcranNu.actif {
                Color.black.ignoresSafeArea()
            } else if !showSplash && !showAuth && !homeEclipsee
                && !(Self.cheminSeul && depart.cheminOuvert) {
            TabView(selection: $selection) {
                Tab("Accueil", systemImage: "house.fill", value: WoopTab.home) {
                    // §23 LE BRANCHEMENT — LA HOME V2 ROUGE prend l'onglet
                    // (la porte y atterrit après la connexion). Son menu
                    // route (onRoute), son slider ouvre LE CHEMIN, le
                    // chemin démarre la séance et route vers Exercices.
                    // L'ancienne home (HomeAuroraView) reste en archive.
                    HomeNuitPage(onRoute: routerVers, exoParRoute: true)
                        .toolbarVisibility(.hidden, for: .tabBar)
                        // LA PORTE D'ONGLET (chantier chauffe 03-09, item
                        // 4) : le TabView garde les onglets visités MONTÉS
                        // — chaque page sait désormais si elle est
                        // affichée, et ses moteurs (fonds vidéo, comète,
                        // horloges) se mettent en POSE sans se démonter.
                        .environment(\.ongletCache, selection != .home)
                }
                Tab("Exercices", systemImage: "figure.strengthtraining.functional",
                    value: WoopTab.exercises) {
                    // La page nuit immersive : elle reçoit la sélection pour
                    // que son chevron ramène à la home — la barre bijou se
                    // retire quand elle est à l'écran (cf. safeAreaInset).
                    ExercisesView(selection: $selection)
                        .toolbarVisibility(.hidden, for: .tabBar)
                        .environment(\.ongletCache,
                                     selection != .exercises)
                }
                // (L'onglet PROGRESSION est ARCHIVÉ le 04-09 — trois
                //  onglets désormais. `ProgressPage`, son calendrier et
                //  son iPod restent dans le code, rejouables par
                //  `-progressLab`, mais n'ont plus de porte.)
                Tab("Profil", systemImage: "person", value: WoopTab.profile) {
                    // La maison des cartes : le halo versé de la droite, le
                    // chevron ramène à la home (le pattern d'Exercices).
                    ProfilLuneView(selection: $selection)
                        .toolbarVisibility(.hidden, for: .tabBar)
                        .environment(\.ongletCache, selection != .profile)
                }
            }
            // (Le bouclier système a déménagé le 04-09 à la RACINE de
            //  mainBody — un « je quitte l'app » résiduel suggérait que
            //  l'émission au niveau du TabView ne remontait pas toujours
            //  au root VC. Toujours UN SEUL émetteur, jamais imbriqué.)
            // La barre native est MASQUÉE au profit de la barre bijou. Le verre
            // liquide d'Apple est translucide par nature : posé sur l'aurore il
            // en prend la couleur et la barre devient un reflet du sol.
            // L'obsidienne, elle, reste NOIRE sur le feu — c'est ce contraste
            // qui fait le bijou. Le TabView demeure pour ce qu'il fait bien :
            // l'état et les piles de navigation.
            //
            // `toolbarVisibility` se pose sur le CONTENU de chaque onglet :
            // appliqué au TabView, il ne masque rien.
            // LA HOME DORT SOUS LA ROUTE (jalon 1) : vidéos en pose, verre
            // démonté — voir `\.dort` (DepartSeance.swift).
            // ⚠️ `homeDort`, PAS `cheminOuvert` (28-08) : le sommeil arrive
            // APRÈS la course de la route, jamais pendant — voir DepartSeance.
            // COMPOSÉ (03-09, item 4) : les DEUX calques vidéo de
            // FondDeuxCalques passent aussi en pose quand la home n'est pas
            // l'onglet affiché — `\.dort` n'a que CE lecteur
            // (DepartCine.swift:602). Les horloges de la home, elles,
            // lisent `homeDort` en direct (HomeNuit) et ne reçoivent RIEN
            // d'ici : les endormir sous un onglet caché est l'item 7,
            // NON fait.
            .environment(\.dort, depart.homeDort || selection != .home)
            // NAV DU BAS (intégration §6) : le PONT nav ↔ onglet. Un tap sur
            // un glyphe écrit `NavEtat.page` ; ce pont le porte à la sélection
            // du TabView, et l'inverse allume le bon glyphe quand l'onglet
            // change par un autre chemin (route, chevron). Deux `onChange`,
            // aucun état nouveau — la sélection reste la vérité du châssis.
            .onChange(of: NavEtat.shared.page) { _, p in
                let cible = p.ongletWoop
                if selection != cible {
                    withAnimation(.easeOut(duration: 0.3)) { selection = cible }
                }
            }
            .onChange(of: selection, initial: true) { _, s in
                // Le contexte de la boîte noire — POSÉ, jamais deviné.
                SondeVol.shared.onglet = s.rawValue
                // ⚠️ ET LA PORTE DES HORLOGES (05-09) : le TabView garde
                // les trois pages MONTÉES, donc les trois animaient en
                // même temps — mesuré 18 + 14 + 10 battements/seconde sur
                // le seul accueil. Un onglet qu'on ne regarde pas se tait.
                // Deux écritures par bascule, jamais une par image.
                RythmeEcran.shared.ongletActif = s.rawValue
                if let d = NavDest(onglet: s), NavEtat.shared.page != d {
                    NavEtat.shared.page = d
                }
            }
            // ⚠️ ICI VIVAIT LA CAUSE N° 1 DU 04-09 (« la navigation
            // redevient des petits points alors qu'on avait dit non ») :
            // `if enSeance { NavEtat.shared.mini = true }` — le FIX 1 du
            // 03-09, écrit quand la mini nav existait encore. Le pivot a
            // tué le GESTE du repli sans tuer son ÉTAT : la nav se
            // repliait à chaque séance et plus RIEN ne pouvait la
            // relever. Mort et remplacé par son contraire utile.
            //
            // LA BULLE SORT DE L'ÎLE À CHAQUE SÉANCE (cause n° 3) :
            // `dansIle` vit dans un singleton et personne ne le remettait
            // jamais à faux — une fois la pastille aspirée dans l'île,
            // on y restait, séance suivante comprise, sans plus aucun
            // moyen d'ouvrir le player. Chaque séance repart propre.
            // ⚠️ ET `morphPlayer` MEURT AVEC SA SÉANCE (relecture adverse
            // 04-09, deux relecteurs indépendants). Il n'était écrit qu'à
            // l'ouverture (1) et par `fermer()` (0) — or on ne ferme PAS
            // le player pour arrêter la séance : on tape STOP, la StopCard
            // passe par-dessus, « Terminer » pose `endedAt`, et le player
            // se démonte avec `morphPlayer` resté à 1. À la séance
            // SUIVANTE, `morphPlayer > 0.001` était vrai d'emblée : le
            // grand player naissait PLEIN ÉCRAN, sans un geste, par-dessus
            // la nav et la pilule. Un état d'ouverture qui vit au châssis
            // doit mourir avec l'objet qui l'a ouvert — aux DEUX bords.
            // Le rideau se lève AVEC le player, dans les deux sens.
            .onChange(of: morphPlayer) { _, m in
                PlayerEtat.shared.couvre = m > 0.98
            }
            .onChange(of: active != nil, initial: true) { _, enSeance in
                SondeVol.shared.enSeance = enSeance
                PiluleEtat.shared.dansIle = false
                morphPlayer = 0
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                // Les pages Exercices et Profil sont IMMERSIVES : la barre
                // se retire quand on y entre — leur chevron fait la sortie,
                // c'est la même grammaire — et elle remonte en ressort au
                // retour ; le `if` rend aussi sa place à la page. Le profil
                // est une maison de cartes : la barre lui mangeait le bas
                // de sa collection pour une navigation que son chevron
                // assure déjà.
                // §23 : la home v2 n'a PLUS de nav bar (sa loi — le menu
                // route) : la barre bijou ne se montre plus nulle part,
                // le code reste pour l'archive de la v1.
                if barreBijouVisible {
                    JewelTabBar(items: Self.tabItems, selection: tabIndex,
                                play: PlayParams(),
                                onPlay: galetPlayTape,
                                onPlayHold: galetPlayTenu,
                                invitePulse: invitePulseAt,
                                // Une séance ouverte : le triangle du galet se
                                // referme en cercle de néon. Le même bouton la
                                // RAMÈNE alors au lieu d'en ouvrir une seconde
                                // (voir `startWorkout`).
                                running: active != nil)
                        .frame(height: 64)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)
                        // L'arrivée de la cinématique : la barre monte du bas en
                        // ressort, un temps APRÈS la page — les meubles entrent
                        // après les murs. `offset` et non un inset animé : la
                        // place est déjà réservée, rien ne re-layoute.
                        .offset(y: barArriving ? 90 : 0)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.85),
                       value: selection == .exercises
                           || selection == .profile)
            // L'accent suit le mood : le violet de l'app jure dans un écran
            // d'or. Ici la sélection est une lumière chaude.
            .tint(Color(red: 1.0, green: 0.80, blue: 0.48))
            // L'atterrissage : un tassement discret — la page se pose avec sa
            // lumière, elle n'arrive plus « de trop près » (le zoom appartient
            // à la lune, pas à la home). L'ancre au-dessus du centre fait lire
            // le recul comme une descente.
            .scaleEffect(homeArriving ? 1.05 : 1.0,
                         anchor: UnitPoint(x: 0.5, y: 0.42))
            // PLUS AUCUNE CARTE FLOTTANTE. La séance en cours se dit
            // désormais par le SEUL galet de la barre, qui referme son
            // triangle en cercle de néon — « seul le bouton central animé
            // suffit » (2026-08-05). Une pastille de lecteur en plus disait
            // la même chose une seconde fois, et mangeait le bas de chaque
            // page. Le galet ramène la séance, et c'est dans la feuille
            // qu'on la termine.
            .sheet(item: $sheetWorkout) { workout in
                // « Annuler cette séance » la supprime pendant que la feuille
                // se referme : on ne lit pas un objet déjà sorti de la base.
                feuilleSeance(workout)
            }
            }

            // ---- LE PARCOURS BOOSTER, MONTÉ À LA RACINE ----
            // La pop-up et le Manège vivent AU-DESSUS du TabView et de la
            // barre bijou : on ouvre un booster depuis la home SANS passer
            // par l'onglet profil (le flow reste celui d'où on vient), et
            // la barre ne peut plus voler un onglet en pleine cérémonie.
            // Le pourquoi de l'état partagé plutôt que d'une notification
            // est écrit en tête de `BoosterPopup.swift` : un onglet non
            // encore construit n'écoute personne.
            // Le conteneur du panneau reste MONTÉ (transparent, sourd au
            // doigt quand il est vide) : c'est lui qui joue la montée et
            // la descente — l'école du « Recommencer » de la fiche
            // d'exercice. Inséré et retiré d'un coup, le panneau
            // n'aurait jamais de sortie vers le bas.
            // LE PLAYER EST LA FEUILLE DE SÉANCE (le verdict de la
            // maison : « séance en cours = le galet néon SEUL » — la
            // carte flottante est morte deux fois, elle ne revient
            // pas). Le galet ramène la feuille ; son « Terminer
            // l'entraînement » ouvre le panneau ci-dessous.

            // LE CHEMIN — LA ROUTE EN ARBRE (27-08, jalon 1 de
            // tools/road/AUDIT-ROAD.md). Elle vivait dans un
            // `fullScreenCover` de la home : tout ce qui est monté ici (la
            // pop-up booster, la notif des pièces, la pause) passait DESSOUS —
            // une lune qui appelait `proposer()` ouvrait la pop-up derrière la
            // route, l'haptique jouait dans le vide. Montée / démontée
            // (`if ouvert`, l'école du Manège), zIndex 4 : sous la pause (5),
            // la pop-up (6), le Manège (7), la notif des pièces (9). La home
            // reste rendue dessous — c'est le PRIX de la sortie du cover, à
            // mesurer au banc `-homeChemin -fps` (étiquette « duo »).
            // LE CHEMIN — la route en arbre (jalon 1). ⚠️ EXTRAIT dans sa
            // propre vue : posé ici en entier, avec ses quatre fermetures,
            // il faisait basculer `mainBody` au-delà de ce que le
            // type-checker résout (« unable to type-check in reasonable
            // time ») — tout build DEVICE échouait, alors que
            // l'incrémental du simulateur passait. Le corps géant doit
            // rester une addition de vues NOMMÉES, pas d'expressions.
            cheminEnArbre
            // LA CARD À GRATTER — au-dessus de la route (elle en sort), sous
            // le Sacre. Elle se monte et se démonte seule sur son état.
            RewardCheminHote(etat: recompenses)
                .zIndex(12)

            // LA CARD STOP (le stop du player) : le slider clôt la séance —
            // le trophée, la notif des pièces et la pop-up booster
            // s'enchaînent derrière (terminerSeance). Elle a REMPLACÉ le
            // panneau qui montait du bas, à signature identique.
            //
            // zIndex 13 (et non plus 5) : un stop peut être demandé PENDANT
            // la card à gratter (12) ou la notif des pièces (9) — une
            // question modale se pose au-dessus. Elle reste sous MoonDust
            // (20). La chaîne de clôture n'est jamais recouverte : la card
            // a fini sa sortie AVANT que `onTerminer` ne parte.
            StopCardHote(
                ouverte: depart.pauseOuverte,
                duree: dureeSeanceTexte,
                // ⚠️⚠️ **ELLE ANNONÇAIT LE TRAVAIL PRÉVU, PAS LE TRAVAIL
                // FAIT.** `setCount` compte toutes les lignes de séries
                // existantes ; la pill de la fiche, à deux centimètres,
                // comptait les cochées. Deux composants du même écran, deux
                // définitions du même gain. Et le `20` était en dur : il vient
                // maintenant du serveur, comme partout ailleurs.
                series: active?.seriesPayantes ?? 0,
                gain: (active?.seriesPayantes ?? 0)
                    * EconomieWoop.shared.piecesParSerie,
                onTerminer: { terminerSeance() },
                onContinuer: {
                    // La card a DÉJÀ joué sa sortie avant d'appeler : on ne
                    // fait que baisser le drapeau. Pas de `withAnimation`
                    // ici — il n'animerait plus rien et ouvrirait une
                    // transaction sur de l'état voisin.
                    depart.pauseOuverte = false
                })
                .zIndex(13)

            // LA STORY DE FIN DE SÉANCE (zIndex 15) : au-dessus de la card
            // STOP — elle vient APRÈS elle — et sous MoonDust (20).
            storyFinHote

            // LES ANNONCES — la pile de dalles liquid glass (pièces, sachet,
            // argent, +10) qui descendent et s'empilent, le compte qui roule.
            // Une par événement ; la file vit dans Annonces.swift.
            PileAnnoncesHote()
                .zIndex(9)

            // LE PLAYER GLOBAL (§3, plan tools/player/PLAN-PLAYER-CARD.md) —
            // UNE instance, au-dessus des pages et des pop-ups de jeu
            // (5-8), SOUS les annonces (9) et la StopCard (13) : le stop
            // se pose SUR le player ouvert. La page derrière ne bouge
            // JAMAIS — le voile et le corps vivent ici, les dalles des
            // pages appellent PlayerEtat.shared.ouvrir().
            PlayerMondeHote(
                seance: active,
                onPageExercices: {
                    withAnimation { selection = .exercises }
                })
                .zIndex(8.5)

            // ⚠️ LA PILULE VAGABONDE — LE PLAYER EN SÉANCE (pivot 04-09).
            // Montée UNE fois au châssis, `if active != nil` seulement (la
            // loi du rideau : rien ne se monte caché). Elle flotte
            // AU-DESSUS des pages et SOUS le monde du player : on la
            // drague partout, un tap l'ouvre, son ticket se tire.
            // ⚠️ `.ignoresSafeArea()` — CAUSE N° 2 DU 04-09. Les cotes de
            // la pilule sont PHYSIQUES (elle vise la Dynamic Island : voir
            // `IleGeo`, qui le dit dans son propre en-tête). Montée dans la
            // zone sûre, TOUT tombait 59 pt plus bas : lâchée en bas elle
            // se posait SUR la nav et débordait de l'écran, et « l'île »
            // n'était pas la Dynamic Island mais une barre noire en
            // travers du haut de page, 60 pt sous la vraie.
            //
            // ⚠️ ET SES MOTEURS SE TAISENT SOUS LE GRAND PLAYER (loi du
            // rideau) : player ouvert, elle continuait de chanter derrière
            // lui — braises comprises — pour rien.
            // ⚠️ ON LA GÈLE, ON NE LA DÉMONTE PAS. `morphPlayer` SAUTE à 1
            // (avec `withAnimation`, c'est le RENDU que SwiftUI interpole,
            // pas la valeur) : la démonter sur ce seuil la ferait
            // disparaître D'UN COUP pendant que le player monte encore.
            if let a = active {
                PiluleVagabonde(
                    // ⚠️ LA BORNE BASSE TIENT COMPTE DE LA NAV ET DU
                    // TICKET (relecture adverse 04-09). À `H − 96`, le
                    // bord bas de la pilule tombait à `H − 48` alors que
                    // la rangée nav vit de `H − 60` à `H − 18` : posée au
                    // plus bas elle s'asseyait DESSUS, et son ticket —
                    // qui pend encore ~30 pt plus bas avec sa propre zone
                    // tactile — recouvrait le glyphe du milieu. L'onglet
                    // Exercices devenait intapable pour le reste de la
                    // séance (`yRatio` est persisté).
                    // La cote : haut de la nav (H − 60) − débord ticket
                    // (30) − demi-pilule (48) = H − 138.
                    utile: 130...(UIScreen.main.bounds.height - 138),
                    departSeance: a.startedAt ?? .now,
                    ticketTexte: "\(a.seriesPayantes) SETS",
                    figee: morphPlayer > 0.98,
                    onOuvrir: { ouvrirGrandPlayer() },
                    onStop: { DepartEtat.shared.pauseOuverte = true }) {
                    contenuPilule(a)
                }
                .ignoresSafeArea()
                .zIndex(6)
            }

            // ⚠️ LE GRAND PLAYER — CELUI QU'ON A CONSTRUIT AU BANC
            // (04-09 : « quand j'ai cliqué sur la pastille, ça a ouvert
            // l'ANCIEN overlay »). Il monte du bas d'un bloc, le fond
            // s'assombrit, on le ferme au drag. `PlayerMonde` (l'ancien)
            // n'est plus ouvert par la pastille — ZÉRO ligne touchée
            // chez lui, il reste pour ses autres chemins.
            if let a = active, morphPlayer > 0.001 {
                GrandPlayer(
                    morph: $morphPlayer,
                    ecranTaille: UIScreen.main.bounds.size,
                    depart: a.startedAt ?? .now,
                    exoChoisi: a.orderedExercises.first?.exercise?.name,
                    groupes: groupesDeSeance(a),
                    sticker: WoopSticker.pour(a).asset,
                    onStop: { DepartEtat.shared.pauseOuverte = true },
                    onExos: { withAnimation { selection = .exercises } })
                    // Même loi que la pilule : il reçoit `UIScreen.bounds`,
                    // une cote PHYSIQUE — sans ça il naissait 59 pt trop bas.
                    .ignoresSafeArea()
                    // ⚠️ IL EST PLEIN ÉCRAN DÈS 0,001 (cause n° 5) : il
                    // descend par un `.offset` et s'efface par l'`.opacity`
                    // — or un offset déplace les PIXELS, pas la zone
                    // tactile, et une vue à opacité 0 reste parfaitement
                    // tappable. Pendant toute la montée (0,62 s) et toute
                    // la descente, TOUT L'ÉCRAN appartenait à un player
                    // invisible : plus un seul tap ne passait.
                    .allowsHitTesting(morphPlayer > 0.98)
                    .zIndex(8.4)
            }

            // ⚠️ LA NAV DU BAS — UNE SEULE, AU CHÂSSIS, IMMOBILE
            // (04-09). Rendue dans chaque PageCard, elle VOYAGEAIT avec
            // la transition de page (« quand je passe d'exercices à la
            // fiche, la nav bouge »). Ici elle ne bouge plus jamais : le
            // contenu passe DESSOUS, elle reste. La page continue de
            // réserver sa hauteur, et de publier si la bande doit se
            // montrer (clavier, exercice en cours).
            // (Le pan de bande est mort avec le repli : plus aucun drag
            //  ne vit ici — seuls les glyphes répondent, et ils naviguent.)
            if NavEtat.shared.bandeVisiblePubliee {
                // ⚠️ CENTRÉE DANS LE NOIR (04-09 : « centre la nav au
                // milieu de l'espace noir » — collée au bas elle mordait
                // l'indicateur, posée sur la zone sûre elle était trop
                // haute). La zone noire vaut `navH + safeBottom` : la
                // rangée tombe au milieu si on la relève d'exactement la
                // MOITIÉ de la zone sûre.
                // ⚠️ LA COTE EST FIXE ET LUE HORS DU CONTENEUR (04-09,
                // ma faute : je lisais `safeAreaInsets` À L'INTÉRIEUR
                // d'une vue qui IGNORE la zone sûre — elle y vaut ZÉRO,
                // et la nav s'est collée au bord).
                //
                // LA GÉOMÉTRIE, au point près (iPhone 15, strip 34) :
                // la rangée de 42 pt se pose à 18 pt du bord physique
                // (18…60) ; la card réserve 44, donc le noir va de 0 à
                // 78 — 18 d'air EN DESSOUS, 18 d'air AU-DESSUS : elle
                // est CENTRÉE, et le CENTRE des glyphes tombe à ~39 pt,
                // au-dessus du strip d'iOS. Centrer parfaitement en
                // gardant la rangée toute entière hors du strip aurait
                // coûté 110 pt de noir : trop, elle l'a dit.
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    NavBande(hauteur: NavEtat.shared.navH)
                        .padding(.bottom, 18)
                }
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(true)
                .zIndex(4)
                .transition(.opacity)
            }

            // LE DÉPART DE SÉANCE — le panneau du galet play, monté à la
            // racine (l'école du parcours booster : l'état partagé, pas
            // une notification). « Commencer » = la séance du galet
            // d'avant + la bascule exercices + le tuto armé.
            DepartPanneauHote(
                ouverte: depart.panneauOuvert,
                onCommencer: {
                    depart.fermer()
                    depart.tutoDemande = true
                    startWorkout()
                },
                onFermer: { depart.fermer() })
                .zIndex(5)
            // LA CARD BOOSTER (variant B, « le sachet est le bouton ») —
            // elle a remplacé la feuille qui montait du bas.
            //
            // ⚠️ `robe:` ne descend PLUS : la card montre TOUJOURS le sachet
            // ORANGE (verdict Kathryn, 30-08), le noir a son propre manège.
            // `sacre.robeCourante` reste lu ailleurs dans le parcours.
            BoosterCardHote(
                ouverte: sacre.popupOuverte,
                // `morsure` : la profondeur déchirée par le GLISSEMENT (nil
                // sur un tap) — le manège reprend là. Et `popupOuverte` tombe
                // ICI : la card a déjà joué sa sortie, `ouvrirManege` n'a plus
                // à attendre 0,32 s qu'une feuille sorte (c'était un trou noir
                // de 0,32 s entre la card partie et le Sacre qui monte).
                onOuvrir: { morsure in
                    sacre.morsureCard = morsure
                    sacre.popupOuverte = false
                    sacre.ouvrirManege()
                },
                onFermer: {
                    // La card a DÉJÀ joué sa sortie avant d'appeler : on ne
                    // fait que baisser le drapeau (comme la card STOP).
                    sacre.popupOuverte = false
                })
                .zIndex(6)
                // La sonde de cadence (`-fps`) : elle dit l'état RÉEL de
                // l'écran, panneau ouvert comme fermé.
                .sondeCadence(sacre.popupOuverte ? "panneau" : "home")
            // LA CARD WELCOME BACK (30-08 soir) — sa porte de production : la
            // home, au premier plan, quand le serveur dit que le +10 du jour
            // est à prendre. Le Claim ENCAISSE (outbox → claim_retour_quotidien)
            // et la dalle « +10 » se dit au tap ; « Later » la range. Sous la
            // pile des annonces (9), au-dessus de la card booster (6).
            if depart.welcomeOuverte {
                RewardPopup(count: EconomieWoop.shared.piecesRetourQuotidien,
                            title: "Welcome back",
                            subtitle: "Your next session is waiting for you.",
                            unit: "Coins",
                            style: .welcome,
                            robe: .video,
                            onClose: { depart.welcomeOuverte = false },
                            onClaim: { EconomieWoop.shared.reclamerRetour() })
                    .zIndex(8)
                    .transition(.opacity)
            }
            if sacre.manegeOuvert {
                BoosterLab(appMode: true,
                           // LA MORSURE de la card (BoosterCard.swift) : si
                           // le sachet a été déchiré au GLISSEMENT, le manège
                           // reprend à cette profondeur ; nil pour toute
                           // autre porte (pills, coffre, tap) — intact.
                           dechirureDepart: sacre.morsureCard,
                           // La robe posée par la porte qu'on a prise (la
                           // proposition ou la pill) — deux manèges, jamais
                           // mélangés.
                           robe: sacre.robeCourante,
                           // Le chevron de la maison, aux deux escales du
                           // Sacre (le manège, le résultat) : il rend la
                           // main à la HOME, jamais à la page d'où l'on
                           // vient — c'est la sortie du parcours.
                           onRetourHome: {
                               sacre.fermerManege()
                               withAnimation(.easeOut(duration: 0.3)) {
                                   selection = .home
                               }
                           },
                           onCarteEnvolee: { carte in
                               // La morsure a servi : le prochain manège
                               // repart d'un sachet intact.
                               sacre.morsureCard = nil
                               // L'envol accompli : le noir du Sacre
                               // s'efface, l'onglet profil prend la main,
                               // PUIS la carte redescend chez elle — la
                               // page doit exister pour entendre l'arrivée
                               // (et son `onAppear` la relit en filet).
                               withAnimation(.easeOut(duration: 0.4)) {
                                   sacre.manegeOuvert = false
                               }
                               // ⚠️⚠️ **LE `max(1, …)` RENDAIT LE COMPTEUR
                               // INVARIANT.** Écrit comme un filet de démo
                               // (« jamais à sec, la boucle doit pouvoir se
                               // rejouer »), il était en fait le SEUL
                               // écrivain d'un compteur né à 1 : la réserve
                               // ne montait jamais, ne descendait jamais, et
                               // la pill du profil affichait « 1 » à vie.
                               //
                               // C'EST LA RÉSERVE OUVERTE QUI SE DÉCOMPTE,
                               // pas « la » réserve : un booster noir ouvert
                               // qui retirait un jaune aurait fait fondre la
                               // mauvaise pile sous les yeux de l'utilisateur.
                               // La règle survit — elle passe côté serveur,
                               // dans le `case` d'`ouvrir_booster`.
                               let noir = sacre.robeCourante == .noire
                               if noir {
                                   sacre.boostersNoirsEnAttente =
                                       max(0, sacre.boostersNoirsEnAttente - 1)
                               } else {
                                   sacre.boostersEnAttente =
                                       max(0, sacre.boostersEnAttente - 1)
                               }
                               // Le sachet a été consommé À L'ENGAGEMENT
                               // (BoosterLab.lancerForge : consommer, PUIS
                               // forger avec son id — c'est ce qui scelle
                               // « un sachet = une carte »). Ici on ne fait
                               // que RELIRE le serveur, en fond.
                               Task { await EconomieWoop.shared.rafraichir() }
                               selection = .profile
                               DispatchQueue.main.asyncAfter(
                                   deadline: .now() + 0.45) {
                                   sacre.arriveeDemandee = carte
                               }
                           })
                    .transition(.opacity)
                    .zIndex(7)
            }

            if showAuth {
                // Le socle noir reste en place pendant tout le tuilage
                // splash → auth : jamais un pixel de la home ne transparaît.
                Color.black.ignoresSafeArea()
                    .zIndex(8)
                    .transition(.opacity)
                if !showSplash {
                    // LA PORTE (22-08, PLAN-PORTE.md) : le carrousel des
                    // quatre pages remplace l'écran aurora — qui reste vivant,
                    // en archive, derrière `-loginLab`. Même contrat exact :
                    // `onConnect` + `cineStart` poussé par la racine.
                    PorteEntree(onConnect: { digits in
                        // Le parcours entre SANS CONDITION. On ne retient que
                        // ce qui est un numéro — la porte passe une chaîne
                        // vide, donc `woop.phone` (la clé de session Supabase)
                        // n'est jamais écrasé ; le jour où l'identité viendra
                        // d'Apple, cette clé changera de nature (§ 6 du plan).
                        if digits.count == 10 {
                            UserDefaults.standard.set(digits, forKey: "woop.phone")
                        }
                        startConnexionCinematic()
                    }, cineStart: cineStart,
                       arrivee: !Self.porteDejaVue)
                    .transition(.opacity)
                    .zIndex(9)
                }
            }

            // Le nuage de braises : au-dessus de TOUT. La page change
            // DERRIÈRE lui pendant l'apnée et il ne bronche pas d'un pixel —
            // le seul témoin de continuité entre les deux mondes. Il avale
            // aussi le doigt le temps de la cérémonie.
            if let cineStart {
                MoonDustOverlay(start: cineStart)
                    .zIndex(20)
            }

            if showSplash {
                // Le splash tient sa propre horloge : lui seul sait quand sa
                // séquence est finie, et il peut être passé d'un toucher.
                // C'est désormais LA LUNE DE SANG (22-08, la porte) : trois
                // états tenus, 3,40 s, qui meurent au noir — et le film
                // d'arrivée de la porte COMMENCE au noir, donc la couture est
                // introuvable. Le plan-séquence de 13,95 s reste en archive,
                // rejouable par `-moonSplashLab` ; la bouteille et le
                // diablotin par `-splashTest`.
                LuneDeSangView {
                    withAnimation(.easeOut(duration: 0.5)) { showSplash = false }
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        // ⚠️ LE BOUCLIER SYSTÈME — UNE SEULE ÉMISSION, À LA RACINE de
        // mainBody (04-09) : le contenu direct du hosting controller
        // racine, là où iOS lit la préférence à coup sûr (émise au niveau
        // du TabView, un « je quitte l'app » résiduel persistait au tel).
        // JAMAIS re-déclaré dans les pages ni PageCard : la même
        // préférence imbriquée à plusieurs niveaux est le motif « Bound
        // preference updated multiple times per frame » (suspect n°1 du
        // gel du 03-09). Les covers plein écran gardent LEUR paire (un VC
        // présenté n'hérite pas). Ça DIFFÈRE le geste Home (1er glissement
        // à l'app) ; ni le 2e ni Reachability — lois iOS.
        .defersSystemGestures(on: .bottom)
        .persistentSystemOverlays(.hidden)
        // Les bancs du parcours booster :
        //   `-boosterPopup` propose la pop-up au lancement (elle se juge
        //     seule, sans traverser l'app) ;
        //   `-boosterManege` ouvre directement le Manège à la racine.
        // La chaîne réelle se teste, elle, bouton par bouton depuis la
        // home (`tools/sacre/PARCOURS-BOOSTER.md`).
        // `id:` et non un `.task` nu : au premier passage le splash tient
        // encore l'écran — sans la clé, le banc ne se rejouerait jamais.
        .task(id: showSplash || showAuth) {
            guard !showSplash, !showAuth else { return }
            if CommandLine.arguments.contains("-clotureTest") {
                // La chaîne de fin de séance se joue toute seule (dock
                // visible → clôture → trophée → notif pièces → pop-up
                // booster) — le stop ne se tape pas en ligne de commande.
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                terminerSeance()
            } else if CommandLine.arguments.contains("-departPanneau") {
                // Le banc du panneau de départ (le galet ne se tape pas
                // en ligne de commande).
                try? await Task.sleep(nanoseconds: 800_000_000)
                depart.proposer()
            } else if CommandLine.arguments.contains("-cheminRetourAuto") {
                // Le banc du RETOUR de la route (jalon 1) : elle se replie
                // toute seule — le réveil de la home se mesure (`-fps`).
                try? await Task.sleep(nanoseconds: 11_000_000_000)
                depart.fermerChemin()
            } else if CommandLine.arguments.contains("-boosterPopup") {
                try? await Task.sleep(nanoseconds: 800_000_000)
                sacre.proposer()
            } else if CommandLine.arguments.contains("-boosterManege") {
                try? await Task.sleep(nanoseconds: 800_000_000)
                sacre.ouvrirManege()
                // `-boosterRetourAuto` rejoue le chevron tout seul : c'est
                // le banc du DÉMONTAGE (la nappe du manège survivait à la
                // sortie — un CADisplayLink retenait son coordinateur).
                if CommandLine.arguments.contains("-boosterRetourAuto") {
                    try? await Task.sleep(nanoseconds: 12_000_000_000)
                    sacre.fermerManege()
                    selection = .home
                }
            }
        }
        // L'ÉCLIPSE DE LA HOME SOUS LE SACRE (cf. `homeEclipsee`) : elle
        // attend LA ROUE POSÉE (le signal du coordinateur — jamais un
        // minuteur fixe : sur téléphone la compilation Metal décale la
        // roue et un « +2 s » faisait tomber la désallocation de la home
        // EN PLEIN dévissage). Un souffle après la pose, sous le noir
        // opaque ; à la fermeture la home revient DANS LA MÊME
        // transaction que la sortie du manège.
        // LE PLAYER DEMANDE LA CLÔTURE (son panneau stop a dit oui) :
        // la racine l'exécute — elle seule tient la séance et la chaîne.
        .onChange(of: depart.clotureDemandee) { _, demandee in
            guard demandee else { return }
            print("[flow] racine : clôture reçue")
            depart.clotureDemandee = false
            terminerSeance()
        }
        .onChange(of: sacre.manegePose) { _, pose in
            guard pose else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                guard sacre.manegeOuvert, sacre.manegePose else { return }
                var tx = Transaction()
                tx.disablesAnimations = true
                withTransaction(tx) { homeEclipsee = true }
            }
        }
        .onChange(of: sacre.manegeOuvert) { _, ouvert in
            if ouvert {
                // Le Manège est LA SORTIE DU PARCOURS : la route se replie
                // sous lui (sa sortie ramène à la home ou au profil, jamais à
                // la route — audit §4, accepté).
                if depart.cheminOuvert { depart.fermerChemin() }
                // Le FILET : si la mise en place ne publie jamais sa
                // pose (banc -boosterCine sans galerie, chemin
                // imprévu), la home s'éclipse quand même — tard, mais
                // jamais pendant la roue.
                DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
                    guard sacre.manegeOuvert, !homeEclipsee else { return }
                    var tx = Transaction()
                    tx.disablesAnimations = true
                    withTransaction(tx) { homeEclipsee = true }
                }
            } else {
                homeEclipsee = false
            }
        }
        // Live Activity : une séance restée ouverte retrouve son île au
        // lancement ; démarrage/fin ailleurs suivent le cycle réel.
        .onAppear { WorkoutActivityController.ensure(active) }
        .onChange(of: activeWorkouts.isEmpty) { _, _ in
            WorkoutActivityController.ensure(active)
            celebrateFinishedWorkout()
        }
        .onChange(of: sheetWorkout == nil) { _, _ in celebrateFinishedWorkout() }
        .task {
            // `-openActiveSheet` ouvre la feuille de séance dès le lancement
            // (captures d'écran automatisées uniquement).
            if CommandLine.arguments.contains("-openActiveSheet"), sheetWorkout == nil {
                sheetWorkout = active
            }
            // La cuisson du studio HDR du booster (1024×512 pixel par
            // pixel, CPU + écriture disque) se paie ICI, en fond de cale —
            // jamais sur le fil principal à l'instant où le manège se
            // monte (`static let` = dispatch_once : le premier toucheur
            // paie, les suivants lisent).
            DispatchQueue.global(qos: .utility).async {
                _ = BoosterScene.hdrStudio
            }
            // LE FOUR : les pipelines Metal du manège se compilent en début
            // de session — une scène jetable rendue quelques frames au fond
            // de la fenêtre, invisible. Sans lui, la première ouverture
            // payait ~1,5 s de NOIR entre le tap et le rideau.
            //
            // ⚠️ IL ATTEND LA FIN DU FILM D'ENTRÉE (22-08, la porte). À
            // +2,5 s fixes, il tombait en plein deuxième palier de la lune
            // de sang : 143-204 ms de trou MESURÉS à la sonde (l'ancien
            // splash de 13,95 s absorbait l'à-coup dans son travelling à
            // demi-résolution ; la lune, elle, est courte et plein cadre).
            // Le manège est à des minutes d'ici — le four peut cuire tard.
            // (Un Task à part : la purge et la poussée Supabase, plus bas,
            // n'ont pas à attendre le film.)
            Task { @MainActor in
                while showSplash {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                }
                // ⚠️ **LE FOUR NE CUIT PAS SI LA PORTE EST LÀ (26-08), ET
                // C'EST 129 ms RENDUS.** Mesuré à `-porteNeuve -fps` : le
                // journal imprimait DEUX fois `[booster-bench] lune`, et deux
                // trous derrière — 129 ms pour le four, 127 pour le manège.
                //
                // C'est du travail fait deux fois. `BoosterScene.init` décode
                // ~36 Mo de textures (booster-color et booster-emiss en
                // 2048², booster-normal en 1024²) SANS CACHE, à chaque
                // construction ; et quand la porte est à l'écran, elle monte
                // de toute façon un manège RÉEL qu'elle garde vivant toute la
                // session (`PorteDecors`). Le four réchauffait donc pour un
                // convive déjà servi.
                //
                // Hors porte (session déjà ouverte, `-skipAuth`), il reste
                // seul à chauffer et il garde tout son sens : sans lui, la
                // première ouverture du booster payait ~1,5 s de NOIR.
                guard !showAuth else { return }
                // ⚠️ **LE FOUR NE SE CALE PLUS SUR UNE HORLOGE MURALE**
                // (26-08). Il attendait « splash + 9,2 s » avec, en
                // commentaire, « L'arrivée V2 (8,23 s) » — un chiffre périmé :
                // le film d'arrivée dure 9,133 s depuis. Le four s'allumait
                // donc **67 ms après la fin du film**, c'est-à-dire PILE sur
                // l'habillage de la porte et la montée des flammes. Et ce
                // qu'il allume n'est pas rien : une `BoosterScene` complète et
                // un `SCNView` en `rendersContinuously` inséré dans la
                // fenêtre pendant 1,8 seconde.
                //
                // C'est la faute C9 de l'audit — « la partition par horloge
                // murale : 211 asyncAfter » — appliquée à elle-même. Il lit
                // maintenant LA constante du film (`PorteEntree.arriveeT`, la
                // seule source de cette durée) et prend une vraie marge
                // derrière : le manège est à des minutes d'ici, le four peut
                // cuire tard.
                try? await Task.sleep(nanoseconds:
                    UInt64((PorteEntree.arriveeT + 3.5) * 1_000_000_000))
                guard let stage = BoosterScene(still: true, mylar: false,
                                               gallery: true),
                      let fenetre = UIApplication.shared.connectedScenes
                          .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
                          .first else { return }
                let four = SCNView(frame: CGRect(x: 0, y: 0,
                                                 width: 2, height: 2))
                four.alpha = 0.001
                four.isUserInteractionEnabled = false
                four.scene = stage.scene
                four.pointOfView = stage.cameraNode
                four.isPlaying = true
                four.rendersContinuously = true
                fenetre.insertSubview(four, at: 0)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    four.isPlaying = false
                    four.rendersContinuously = false
                    four.removeFromSuperview()
                }
            }
            // Rattrapage : toutes les séances terminées repartent à chaque
            // lancement. Une séance finie hors ligne (salle en mode avion)
            // monte donc au premier lancement avec du réseau — l'upsert
            // merge-duplicates rend l'envoi répété inoffensif.
            let workouts = (try? modelContext.fetch(FetchDescriptor<Workout>())) ?? []
            // LES SÉANCES FANTÔMES : une séance restée OUVERTE tient le
            // galet en « en cours » pour toujours (le play rouvrait un
            // vieux écran au lieu du panneau de départ). Meurt au
            // lancement : ouverte depuis 12 h (personne ne s'entraîne
            // une nuit entière), ou VIDE et vieille de 30 min (le tap
            // abandonné). SUPPRIMÉE, jamais terminée — pas une ligne
            // d'historique ni une célébration pour un fantôme. Une
            // vraie séance en cours, elle, survit au relancement.
            // `-fermeSeances` (dev) : TOUTES les séances ouvertes
            // meurent — le remède des états de test qui tiennent le
            // galet en « en cours » (une séance testée AVEC séries
            // échappe à la règle des fantômes, par design).
            let purgeTout = CommandLine.arguments.contains("-fermeSeances")
            let fantomes = workouts.filter {
                $0.endedAt == nil && (purgeTout
                    || $0.startedAt < Date.now.addingTimeInterval(-12 * 3600)
                    // 3 h, pas 30 min : un rebuild au milieu d'un test
                    // effaçait la séance en cours et cassait le flow.
                    || ($0.setCount == 0 && $0.startedAt
                        < Date.now.addingTimeInterval(-3 * 3600)))
            }
            if !fantomes.isEmpty {
                fantomes.forEach { modelContext.delete($0) }
                try? modelContext.save()
            }
            // LES ABANDONNÉES : une séance AVEC contenu laissée ouverte
            // plus de 3 h s'ENREGISTRE en silence (une heure au compteur,
            // pas de célébration) — elle ne tient plus le galet en
            // « en cours » au retour du lendemain.
            let abandonnees = workouts.filter {
                $0.endedAt == nil && $0.setCount > 0
                    && $0.startedAt < Date.now.addingTimeInterval(-3 * 3600)
            }
            if !abandonnees.isEmpty {
                abandonnees.forEach {
                    $0.endedAt = $0.startedAt.addingTimeInterval(3600)
                }
                try? modelContext.save()
            }
            let snapshots = workouts.filter { $0.endedAt != nil }.map { $0.snapshot() }
            Task.detached { await SupabaseSync.shared.push(snapshots) }
            // `-cineTest` : la cinématique de connexion se déclenche seule,
            // 1,5 s après l'arrivée sur la page (captures automatisées — le
            // simulateur ne sait pas taper sur CONNEXION).
            if CommandLine.arguments.contains("-cineTest") {
                while showSplash {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                }
                // Le marqueur : l'app signale ELLE-MÊME l'arrivée sur la
                // connexion (un détecteur d'image se fait berner par le
                // splash, qui a lui aussi son bas lumineux). La capture lit
                // ce fichier via le conteneur et sait que le tap tombe
                // exactement six secondes plus tard.
                let marker = URL.documentsDirectory.appending(path: "cine-armed")
                try? Date.now.ISO8601Format().write(to: marker, atomically: true,
                                                    encoding: .utf8)
                // ⚠️ DOUZE secondes, plus six : depuis la porte (22-08), le
                // FILM D'ARRIVÉE joue APRÈS le splash — et la V2 l'a rallongé
                // à 8,23 s (+ la cascade). À six, la cérémonie partait en
                // plein film et posait `showAuth = false` derrière lui
                // (l'angle mort relevé par la contre-expertise du plan, § 8).
                try? await Task.sleep(nanoseconds: 12_000_000_000)
                startConnexionCinematic()
            }
        }
    }

    /// Un entraînement vient d'être terminé : la récompense doit être VUE. On
    /// attend que la feuille soit refermée, on ramène sur la home, et la carte
    /// Objectif remplit alors son rond. Appelé à chaque étape possible de ce
    /// retour — `deliver()` ne joue qu'une fois.
    private func celebrateFinishedWorkout() {
        guard WoopCelebration.shared.awaiting,
              sheetWorkout == nil, active == nil else { return }
        if selection != .home { selection = .home }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            WoopCelebration.shared.deliver()
        }
    }
}

// MARK: - Données de démonstration

/// Peuplées uniquement avec l'argument de lancement `-demoData`.
enum DemoData {
    /// Ouvre une séance en cours (argument `-activeWorkout`) : sert à vérifier
    /// visuellement l'overlay de séance sans passer par l'interface.
    @MainActor
    static func seedActiveWorkout(in container: ModelContainer) {
        let context = container.mainContext
        let open = (try? context.fetchCount(FetchDescriptor<Workout>(
            predicate: #Predicate { $0.endedAt == nil }))) ?? 0
        guard open == 0 else { return }

        let workout = Workout(startedAt: .now.addingTimeInterval(-8 * 60))
        context.insert(workout)
        let logged = LoggedExercise(exerciseID: "hip-thrust", order: 0)
        logged.workout = workout
        context.insert(logged)
        let set = StrengthSet(reps: 12, weight: 45, order: 0)
        // ⚠️ FAITE, pas seulement prévue : l'économie ne paie que les séries
        // faites (`seriesPayantes` = `completedSets`). Sans ce `isDone`, le
        // banc `-clotureTest` clôturait une séance à gain 0 — et la chaîne de
        // fin (story, notif, card) s'arrêtait net, par construction : un film
        // de 62 s de home nue (30-08).
        set.isDone = true
        set.loggedExercise = logged
        context.insert(set)
        // §3.4undecies B4 : `-activeWorkoutLong` = la séance de KATHRYN
        // (une partition qui DÉBORDE le cadre du player) — c'est ELLE qui
        // reproduit le vol du drag par le ScrollView ; le seed court
        // (1 exo) tombe dans le `scrollDisabled` et ne prouve rien.
        if CommandLine.arguments.contains("-activeWorkoutLong") {
            for (i, id) in ["woop-haute", "woop-basse", "flexion-laterale",
                            "developpe-couche", "papillon"].enumerated() {
                let le = LoggedExercise(exerciseID: id, order: i + 1)
                le.workout = workout
                context.insert(le)
                for j in 0..<4 {
                    let s = StrengthSet(reps: 10 + j, weight: 20, order: j)
                    s.isDone = j < 2
                    s.loggedExercise = le
                    context.insert(s)
                }
            }
        }
        try? context.save()
    }

    /// `-demoForce` : sème les séances de démo MÊME si la base en contient
    /// déjà. `seedIfEmpty` refuse dès qu'il existe UNE séance, quelle qu'elle
    /// soit — y compris une séance ACTIVE, qui est justement exclue de la pile
    /// de la home. Une base avec une seule séance en cours ne pouvait donc ni
    /// afficher de cartes ni être semée : elle restait coincée sur l'état
    /// vide. Rien n'est effacé, on ajoute.
    @MainActor
    static func seedDemo(in container: ModelContainer) {
        seed(in: container)
    }

    /// ⚠️ **SÈME DÈS QUE LES TROIS DERNIÈRES SEMAINES SONT CLAIRSEMÉES** —
    /// et c'est le correctif du 25-08 (« mets plein de données dans la home,
    /// elle est empty »).
    ///
    /// L'ancienne condition était « AUCUNE séance terminée dans toute la
    /// base ». Elle a l'air prudente et elle est en fait **presque toujours
    /// fausse** : il suffit d'UNE séance d'essai, faite six semaines plus tôt
    /// et depuis longtemps oubliée, pour que le seed refuse à jamais de
    /// tourner. Et comme la home ne lit QUE la semaine courante (`SemaineStats`
    /// borne à `dateInterval(of: .weekOfYear)`), on se retrouve avec une base
    /// qui n'est pas vide et une home qui, elle, l'est : widgets gris, phrase
    /// à zéro, card de semaine sans un seul sticker.
    ///
    /// La bonne question n'est donc pas « y a-t-il quelque chose quelque
    /// part ? » mais **« la fenêtre que les écrans regardent est-elle
    /// nourrie ? »**. On compte les séances terminées des 21 derniers jours ;
    /// sous dix, on complète. Rien n'est effacé — le seed n'ajoute jamais que
    /// des séances passées, et la condition redevient fausse aussitôt, donc il
    /// ne peut pas doubler.
    @MainActor
    static func seedDemoIfNoneFinished(in container: ModelContainer) {
        let context = container.mainContext
        let all = (try? context.fetch(FetchDescriptor<Workout>())) ?? []
        let depuis = Date.now.addingTimeInterval(-21 * 86400)
        let recentes = all.filter { $0.endedAt != nil && $0.startedAt >= depuis }
        guard recentes.count < 10 else { return }
        seed(in: container)
    }

    @MainActor
    static func seedIfEmpty(in container: ModelContainer) {
        let context = container.mainContext
        let existing = (try? context.fetchCount(FetchDescriptor<Workout>())) ?? 0
        guard existing == 0 else { return }
        seed(in: container)
    }

    @MainActor
    private static func seed(in container: ModelContainer) {
        let context = container.mainContext

        let calendar = Calendar.current
        func daysAgo(_ days: Int, hour: Int = 18) -> Date {
            let day = calendar.date(byAdding: .day, value: -days, to: .now) ?? .now
            return calendar.date(bySettingHour: hour, minute: 15, second: 0, of: day) ?? day
        }

        struct Plan {
            let days: Int
            let strength: [(String, [(Int, Double)])]
            let cardio: [(String, [(PhaseKind, Int, Double)])]
            // « pleins de données » (25-08) : l'heure de la séance — deux
            // séances le même jour ont besoin de deux heures.
            var hour: Int = 18
        }

        let plans: [Plan] = [
            // ⚠️ LA SEMAINE COURANTE DOIT REMPLIR LA CARD (verdict 25-08 :
            // « mets plein de données dans la home, elle est empty »). La card
            // « This week. » ouvre **`max(prevus, 1)` emplacements** — cinq,
            // l'objectif — et n'en pose de solides que `faits`. À trois
            // séances, deux cases restaient donc vides ET les deux widgets
            // n'avaient qu'un maigre échantillon à moyenner.
            //
            // ⚠️ ET LA FENÊTRE EST ÉTROITE : `SemaineStats` borne à
            // `dateInterval(of: .weekOfYear)` avec `firstWeekday = 2`. Compter
            // sur les jours 3, 4, 6 ne sert à RIEN — selon le jour où l'app
            // s'ouvre, ils tombent la semaine d'avant. Seuls les jours 0 et 1
            // sont dans la semaine courante à coup sûr : c'est là, et nulle
            // part ailleurs, qu'il faut mettre la matière.
            //
            // Cinq séances sur deux jours, de NATURES DIFFÉRENTES : la card
            // pose un sticker par nature, et cinq fois le même bras se lirait
            // comme un bug d'affichage.
            Plan(days: 0,
                 strength: [("woop-haute", [(12, 25), (12, 27.5), (10, 30)]),
                            ("hip-thrust", [(12, 55), (10, 60), (8, 65)])],
                 cardio: [], hour: 8),
            Plan(days: 0,
                 strength: [("squat-poulie", [(15, 27.5), (15, 30), (12, 32.5)]),
                            ("kickback", [(15, 15), (12, 17.5)])],
                 cardio: [], hour: 12),
            // La troisième d'aujourd'hui : du CARDIO, pour que la semaine ne
            // soit pas monochrome et que le volume ne soit pas la seule
            // histoire racontée.
            Plan(days: 0,
                 strength: [],
                 cardio: [("tapis-lent", [(.recuperation, 1500, 6.2)])],
                 hour: 19),
            // Et deux de plus HIER : on arrive à cinq dans la semaine, la card
            // est pleine et les widgets ont de quoi comparer.
            Plan(days: 1,
                 strength: [("abduction", [(15, 12.5), (15, 15), (12, 15)]),
                            ("crunch-machine", [(15, 35), (15, 37.5)])],
                 cardio: [], hour: 9),
            Plan(days: 3,
                 strength: [("pull-through", [(12, 30), (12, 32.5), (10, 35)]),
                            ("abduction", [(15, 10), (15, 12.5)])],
                 cardio: []),
            Plan(days: 6,
                 strength: [("crunch-machine", [(15, 32.5), (15, 35)]),
                            ("gainage-militaire", [(10, 10), (10, 12.5)])],
                 cardio: [("tapis-lent", [(.recuperation, 900, 5.8)])]),
            Plan(days: 10,
                 strength: [("hip-thrust", [(12, 47.5), (10, 52.5), (8, 57.5)])],
                 cardio: []),
            Plan(days: 26,
                 strength: [("woop-haute", [(12, 15), (12, 15), (10, 17.5)]),
                            ("hip-thrust", [(12, 40), (10, 45)])],
                 cardio: []),
            Plan(days: 24,
                 strength: [],
                 cardio: [("hiit-tapis", [(.repos, 60, 6), (.acceleration, 30, 13), (.recuperation, 90, 6), (.acceleration, 30, 13), (.recuperation, 90, 6), (.sprint, 30, 14)])]),
            Plan(days: 21,
                 strength: [("kickback", [(15, 10), (15, 10), (12, 12.5)]),
                            ("pull-through", [(12, 25), (12, 27.5)])],
                 cardio: []),
            Plan(days: 19,
                 strength: [("woop-haute", [(12, 17.5), (12, 17.5), (10, 20)]),
                            ("rotation-milieu", [(15, 12.5), (15, 12.5)])],
                 cardio: []),
            Plan(days: 16,
                 strength: [],
                 cardio: [("escalier", [(.recuperation, 600, 7), (.acceleration, 300, 9)])]),
            Plan(days: 14,
                 strength: [("hip-thrust", [(12, 45), (10, 50), (10, 50)]),
                            ("abduction", [(15, 7.5), (15, 7.5)])],
                 cardio: []),
            Plan(days: 12,
                 strength: [("woop-haute", [(12, 20), (10, 20), (10, 22.5)]),
                            ("gainage-militaire", [(10, 10), (10, 10)])],
                 cardio: []),
            Plan(days: 9,
                 strength: [],
                 cardio: [("hiit-tapis", [(.repos, 60, 6), (.acceleration, 30, 14), (.recuperation, 90, 6), (.acceleration, 30, 14), (.recuperation, 90, 6), (.sprint, 30, 15), (.repos, 120, 5)])]),
            // ⚠️ LES JOURS 7 ET 8 SONT LE TÉMOIN DE COMPARAISON, et il doit
            // être NOURRI. La card Volume compare la semaine courante à la
            // semaine d'avant **au même temps écoulé** (correctif du 25-08
            // dans `SemaineStats`) : un mardi soir, elle regarde donc le lundi
            // et le mardi précédents, et RIEN D'AUTRE. Avec une seule séance
            // dans cette fenêtre, le rapport partait à **+493 %** — un chiffre
            // juste et illisible. Deux séances par jour de part et d'autre, et
            // l'écart redevient une information (~+25 %) au lieu d'un cri.
            Plan(days: 7,
                 strength: [("abduction", [(15, 10), (15, 10), (12, 12.5)]),
                            ("squat-poulie", [(15, 25), (15, 25)])],
                 cardio: [], hour: 8),
            Plan(days: 7,
                 strength: [("hip-thrust", [(12, 50), (10, 55), (8, 55)]),
                            ("woop-haute", [(12, 22.5), (12, 25)])],
                 cardio: [], hour: 17),
            Plan(days: 8,
                 strength: [("squat-poulie", [(15, 30), (15, 30), (12, 32.5)]),
                            ("crunch-machine", [(15, 32.5), (15, 35)])],
                 cardio: [], hour: 10),
            Plan(days: 8,
                 strength: [("kickback", [(15, 15), (15, 15)])],
                 cardio: [("tapis-lent", [(.recuperation, 1200, 6.0)])],
                 hour: 18),
            Plan(days: 5,
                 strength: [("woop-haute", [(12, 22.5), (12, 22.5), (10, 25)]),
                            ("crunch-machine", [(15, 30), (15, 32.5)])],
                 cardio: []),
            Plan(days: 4,
                 strength: [("hip-thrust", [(12, 50), (10, 55), (8, 60)])],
                 cardio: [("tapis-lent", [(.recuperation, 1200, 5.5)])]),
            Plan(days: 2,
                 strength: [("kickback", [(15, 12.5), (15, 12.5), (12, 15)]),
                            ("pull-through", [(12, 27.5), (12, 30)])],
                 cardio: []),
            Plan(days: 1,
                 strength: [("woop-haute", [(12, 25), (12, 25), (10, 27.5)]),
                            ("gainage-militaire", [(8, 10), (8, 10)])],
                 // Un HIIT DANS LA SEMAINE COURANTE : sans lui le widget
                 // HIIT Peak n'a rien à montrer en démo. Le cycle est
                 // l'exemple du brief : sprint 17.0 km/h × 40 s, ×4 tours.
                 cardio: [("hiit-tapis", [(.acceleration, 30, 13.5),
                                          (.recuperation, 60, 6),
                                          (.sprint, 40, 17)])])
        ]

        for plan in plans {
            let workout = Workout(startedAt: daysAgo(plan.days, hour: plan.hour))
            workout.endedAt = daysAgo(plan.days, hour: plan.hour)
                .addingTimeInterval(60 * 52)
            context.insert(workout)
            var order = 0

            for (exerciseID, sets) in plan.strength {
                let logged = LoggedExercise(exerciseID: exerciseID, order: order)
                logged.workout = workout
                context.insert(logged)
                for (i, s) in sets.enumerated() {
                    let set = StrengthSet(reps: s.0, weight: s.1, order: i)
                    set.loggedExercise = logged
                    context.insert(set)
                }
                order += 1
            }

            for (exerciseID, cycle) in plan.cardio {
                let logged = LoggedExercise(exerciseID: exerciseID, order: order)
                logged.workout = workout
                context.insert(logged)
                // LE VRAI FLOW répète un cycle IDENTIQUE N fois
                // (`ExerciseDetailView` : `Array(repeating:count:)`) — la
                // démo fait pareil. L'ancien appariement `i/2` fabriquait
                // des paires arbitraires : les répétitions d'un segment
                // devenaient introuvables, et le HIIT peak des widgets ne
                // pouvait pas les inférer. Seuls les exercices à
                // intervalles se répètent (l'escalier et le tapis restent
                // un passage unique).
                let tours = ExerciseCatalog.exercise(id: exerciseID)?
                    .tracking == .intervals ? 4 : 1
                for tour in 0..<tours {
                    for (i, c) in cycle.enumerated() {
                        let phase = CardioPhase(kind: c.0, seconds: c.1,
                                                speed: c.2,
                                                cycleIndex: tour, order: i)
                        phase.loggedExercise = logged
                        context.insert(phase)
                    }
                }
                order += 1
            }
        }

        try? context.save()
    }
}


// MARK: - LE FOURNEAU

/// LES PIPELINES DU CHEMIN CHAUD, CUITS AVANT D'ÊTRE VUS.
///
/// ⚠️ **LA PREMIÈRE COMPILATION D'UN SHADER SE PAIE SUR LE FIL QUI DESSINE.**
/// Trois pipelines seulement étaient chauffés (le bruit du ciel, la SDF du
/// croissant, la fumée de la pièce) sur les soixante-six que porte l'app — et
/// aucun des trois n'est sur le chemin d'une séance. Résultat mesuré au
/// verdict : « je clique sur la pill, la fumée apparaît, puis il y a un délai,
/// puis le menu arrive trop tard ». Cette fumée-là (`knobSmoke`) se compilait
/// AU MOMENT DU TAP.
///
/// ⚠️ **L'ARITÉ EST RECOPIÉE VERBATIM DU SITE D'APPEL.** C'est la loi de
/// `CoinSmokeWarm`, et c'est un piège déjà payé dans ce dépôt : une signature
/// qui ne correspond pas chauffe une AUTRE variante — donc ne sert à rien — et
/// côté runtime, un stitchable dont l'arité change sans son appel Swift rend
/// une page BLANCHE, sans erreur. Toute modification d'un de ces shaders doit
/// repasser ici.
enum Fourneau {
    /// La fumée du galet — la maison, le menu, la molette de la page exo.
    /// (ExercisesView:1930 et MenuNappe:908.)
    private static var knobSmoke: Shader {
        ShaderLibrary.knobSmoke(.float2(100, 100), .float(0),
                                .float4(50, 50, 20, 24), .float(0), .float(0))
    }
    /// Le panache de l'invite « pull to start » — la home, en permanence.
    /// (HomeNuit:3898 et MenuNappe:868.)
    private static var panacheInvite: Shader {
        ShaderLibrary.panacheInvite(.float2(220, 220), .float(0),
                                    .float2(110, 214), .float(0), .float(1))
    }
    /// Le nuage de braises de la connexion — plein écran, et il tombe pile
    /// pendant la transition login → home. (ConnexionCinematic:167.)
    private static var moonDust: Shader {
        ShaderLibrary.moonDust(.float2(400, 800), .float(0), .float(0),
                               .float3(200, 400, 60), .float2(0, 0))
    }
    /// Le bouton primaire de la maison — il est sur douze écrans.
    /// (ConnexionButtonLab:213.)
    private static var diamondButton: Shader {
        ShaderLibrary.diamondButton(.float2(340, 58), .float(0),
                                    .float(24), .float(19),
                                    .float(0), .float(0), .float(0))
    }

    static func chauffer() {
        Task.detached(priority: .utility) {
            for s in [knobSmoke, panacheInvite, moonDust, diamondButton] {
                try? await s.compile(as: .colorEffect)
            }
        }
        AssetsVideo.chauffer()
        // La miniature des 25 dos du Profil : un PNG 1024×1536 décodé puis
        // re-rastérisé — il se payait sur le fil principal au premier montage
        // de la page.
        Task.detached(priority: .utility) { await DosVide.chauffer() }
    }
}
