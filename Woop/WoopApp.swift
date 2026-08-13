import SwiftUI
import SwiftData
import CoreText

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
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .tint(.woopViolet)
        }
        .modelContainer(container)
    }
}

// MARK: - Racine

enum WoopTab: String, Hashable {
    /// Le calendrier a fusionné dans Progression : il y vit sous les courbes.
    /// Profil prend sa place — à quatre onglets, deux de chaque côté, le bouton
    /// de séance tombe exactement au centre de la barre.
    ///
    /// Le rang `calendar` a DISPARU du jeu : une install qui l'avait retenu
    /// dans `openTab` ne le retrouve plus, et `WoopTab(rawValue:)` rend `nil`.
    /// La migration ci-dessous le rattrape explicitement plutôt que de laisser
    /// le repli silencieux ramener l'utilisatrice à l'accueil sans raison.
    case home, exercises, progress, profile
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
    /// Banc d'essai de la barre d'onglets bijou : `-navLab`, page nue. Double
    /// toucher pour cacher le panneau de fouettage.
    private static let navLab = CommandLine.arguments.contains("-navLab")
    /// Banc d'essai de la home aurora : `-homeLab` (+ `-demoData` pour les
    /// cartes). L'ancienne home noire reste la vraie.
    private static let homeLab = CommandLine.arguments.contains("-homeLab")
    /// Banc du fond aurora nu : `-bgLab` — noir, aurore basse, parallaxe 3D.
    private static let bgLab = CommandLine.arguments.contains("-bgLab")
    /// Banc de la fiche d'exercice : `-exoLab` ouvre la fiche du premier
    /// exercice du catalogue (+ `-activeWorkout` pour la pastille incrustée).
    private static let exoLab = CommandLine.arguments.contains("-exoLab")
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
    /// Banc de la pièce de lune : `-pieceLab` — l'anneau d'or, la laque et le
    /// croissant, tournables au doigt. `-pieceSmall` la montre aux tailles
    /// réelles du header, `-pieceFreeze <rad>` fige le lacet pour comparer
    /// deux tours de fouettage au MÊME angle.
    private static let pieceLab = CommandLine.arguments.contains("-pieceLab")
    /// Banc des stories : `-storyLab` — la carte noire qu'on tire vers le
    /// haut, le portail qui s'ouvre, puis les trois écrans. La carte revient
    /// à la fermeture, donc la cinématique se rejoue à volonté sans rien
    /// toucher — c'est la méthode maison pour juger un enchaînement.
    private static let storyLab = CommandLine.arguments.contains("-storyLab")
    /// Banc du sheet de saisie de série : `-setLab` — la molette fluide, les
    /// chips de repos et le slider à galet, au-dessus d'un faux cadran.
    private static let setLab = CommandLine.arguments.contains("-setLab")
    @State private var showSplash = true
    /// L'authentification suit le splash à CHAQUE lancement ; un toucher sur
    /// « Se connecter » fait entrer immédiatement. `-skipAuth` la court-circuite
    /// (captures d'écran automatisées uniquement).
    @State private var showAuth = !CommandLine.arguments.contains("-skipAuth")
    @State private var selection: WoopTab = {
        guard let raw = UserDefaults.standard.string(forKey: "openTab") else { return .home }
        // Le calendrier a fusionné dans Progression : qui demandait le
        // calendrier atterrit là où son contenu a déménagé, pas à l'accueil.
        if raw == "calendar" { return .progress }
        return WoopTab(rawValue: raw) ?? .home
    }()

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
    private static let order: [WoopTab] = [.home, .exercises, .progress, .profile]
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
        if Self.splashTest {
            splashBench
        } else if Self.moonSplashLab {
            moonSplashBench
        } else if Self.cometTest {
            cometBench
        } else if Self.storyLab {
            StoryLab()
        } else if Self.setLab {
            SetEntryLab()
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
        } else if Self.loginLab {
            AuroraLoginView()
        } else if Self.authNebula {
            AuthView { _ in }
        } else if Self.homeLab {
            HomeAuroraLab()
        } else if Self.bgLab {
            AuroraBgLab()
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
        } else if Self.coffreLab {
            CoffreFortLab()
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
            if !showSplash && !showAuth {
            TabView(selection: $selection) {
                Tab("Accueil", systemImage: "house.fill", value: WoopTab.home) {
                    HomeAuroraView(selection: $selection)
                        .toolbarVisibility(.hidden, for: .tabBar)
                }
                Tab("Exercices", systemImage: "figure.strengthtraining.functional",
                    value: WoopTab.exercises) {
                    // La page nuit immersive : elle reçoit la sélection pour
                    // que son chevron ramène à la home — la barre bijou se
                    // retire quand elle est à l'écran (cf. safeAreaInset).
                    ExercisesView(selection: $selection)
                        .toolbarVisibility(.hidden, for: .tabBar)
                }
                Tab("Progrès", systemImage: "chart.line.uptrend.xyaxis", value: WoopTab.progress) {
                    ProgressionView()
                        .toolbarVisibility(.hidden, for: .tabBar)
                }
                Tab("Profil", systemImage: "person", value: WoopTab.profile) {
                    ProfileView()
                        .toolbarVisibility(.hidden, for: .tabBar)
                }
            }
            // La barre native est MASQUÉE au profit de la barre bijou. Le verre
            // liquide d'Apple est translucide par nature : posé sur l'aurore il
            // en prend la couleur et la barre devient un reflet du sol.
            // L'obsidienne, elle, reste NOIRE sur le feu — c'est ce contraste
            // qui fait le bijou. Le TabView demeure pour ce qu'il fait bien :
            // l'état et les piles de navigation.
            //
            // `toolbarVisibility` se pose sur le CONTENU de chaque onglet :
            // appliqué au TabView, il ne masque rien.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                // La page Exercices est immersive : la barre se retire quand
                // on y entre (son chevron fait la sortie) et remonte en
                // ressort au retour — le `if` rend aussi sa place à la page.
                if selection != .exercises {
                    JewelTabBar(items: Self.tabItems, selection: tabIndex,
                                play: PlayParams(),
                                onPlay: { startWorkout() },
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
                       value: selection == .exercises)
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
                if !workout.isDeleted {
                    ActiveWorkoutSheet(workout: workout) {
                        // « Ajouter un exercice » : on referme la feuille et on
                        // ouvre la bibliothèque — c'est là qu'on loggue.
                        sheetWorkout = nil
                        selection = .exercises
                    }
                }
            }
            }

            if showAuth {
                // Le socle noir reste en place pendant tout le tuilage
                // splash → auth : jamais un pixel de la home ne transparaît.
                Color.black.ignoresSafeArea()
                    .zIndex(8)
                    .transition(.opacity)
                if !showSplash {
                    // Plus aucun conteneur zoomé : la caméra de la cérémonie
                    // vit DANS le shader de la lune (CineMonolith, côté
                    // AuroraLoginView) — le rendu reste vectoriel.
                    AuroraLoginView(onConnect: { digits in
                        // CONNEXION entre SANS CONDITION : le parcours se
                        // teste de bout en bout, champ vide compris. Mais
                        // on ne retient que ce qui est un numéro — une
                        // saisie vide écraserait `woop.phone`, et avec lui
                        // la session Supabase déjà ouverte (elle abandonne
                        // son jeton dès que l'identité change).
                        if digits.count == 10 {
                            UserDefaults.standard.set(digits, forKey: "woop.phone")
                        }
                        startConnexionCinematic()
                    }, cineStart: cineStart)
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
                // C'est désormais la LUNE : le plan-séquence de la bouteille
                // et du diablotin reste en archive, rejouable par
                // `-splashTest`, mais l'app ne s'ouvre plus dessus.
                // `landsOnAurora: false` : l'écran qui suit ici est
                // l'authentification, pas l'aurore orange du banc. Le
                // monolithe fait donc son vol sur du noir, et la page prend
                // le relais — découvrir un fond que personne n'affiche
                // ensuite ne ferait qu'un raccord qui ment.
                MoonSplashView(landsOnAurora: false) {
                    withAnimation(.easeOut(duration: 0.5)) { showSplash = false }
                }
                .transition(.opacity)
                .zIndex(10)
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
            // Rattrapage : toutes les séances terminées repartent à chaque
            // lancement. Une séance finie hors ligne (salle en mode avion)
            // monte donc au premier lancement avec du réseau — l'upsert
            // merge-duplicates rend l'envoi répété inoffensif.
            let workouts = (try? modelContext.fetch(FetchDescriptor<Workout>())) ?? []
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
                try? await Task.sleep(nanoseconds: 6_000_000_000)
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
        set.loggedExercise = logged
        context.insert(set)
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

    /// Sème si la base ne contient AUCUNE séance terminée — la seule condition
    /// qui compte pour la pile de la home, puisque c'est elle qu'elle affiche.
    /// Une base pleine de séances en cours est, pour la home, une base vide.
    @MainActor
    static func seedDemoIfNoneFinished(in container: ModelContainer) {
        let context = container.mainContext
        let all = (try? context.fetch(FetchDescriptor<Workout>())) ?? []
        guard all.allSatisfy({ $0.endedAt == nil }) else { return }
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
        }

        let plans: [Plan] = [
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
            Plan(days: 7,
                 strength: [("abduction", [(15, 10), (15, 10), (12, 12.5)]),
                            ("squat-poulie", [(15, 25), (15, 25)])],
                 cardio: []),
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
                 cardio: [])
        ]

        for plan in plans {
            let workout = Workout(startedAt: daysAgo(plan.days))
            workout.endedAt = daysAgo(plan.days).addingTimeInterval(60 * 52)
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

            for (exerciseID, cycles) in plan.cardio {
                let logged = LoggedExercise(exerciseID: exerciseID, order: order)
                logged.workout = workout
                context.insert(logged)
                for (i, c) in cycles.enumerated() {
                    let phase = CardioPhase(kind: c.0, seconds: c.1, speed: c.2,
                                            cycleIndex: i / 2, order: i % 2)
                    phase.loggedExercise = logged
                    context.insert(phase)
                }
                order += 1
            }
        }

        try? context.save()
    }
}
