import SwiftUI
import SwiftData

// MARK: - LA SÉANCE V7 (30-09)
//
// La page de séance de la v7 (artefact 5UbBfJ33, sélecteur « v7 »), DANS
// l'app et AVEC l'app : elle prend la place du lecteur (même `morph`, même
// pastille, même « Terminer ») et elle ne remplace RIEN d'autre.
//
// ⚠️ LA LISTE CONTRE LAQUELLE CETTE PAGE EST ÉCRITE (validée le 30-09) :
// `tools/seance-v7/LISTE-APP-A-RESPECTER-2026-09-30.md`. Ce qui en découle :
//   - « tu as changé mon cadran » : une série se lance dans SON cadran
//     (`LiquidLensLab`), par SA fiche, avec SON départ (galet ou slider),
//     SA saisie, SON repos, SES toasters et « Encore une série ? ». Le HIIT
//     et le cardio gardent leur double cadran. Cette page ne dessine aucun
//     cadran.
//   - ⚠️ LA PAGE SE RANGE QUAND UNE FICHE S'OUVRE (`poserFerme`), comme le
//     lecteur : sans ça, toute la série et ses pop-ups se jouaient DESSOUS.
//   - « la page détail et mon graph » : la tête d'une carte ouvre SA fiche.
//   - SES composants, jamais des copies : `InviteAnimee`, `HaloCarte`,
//     `ChaleurTete`, `CarreZoneMini`, `SetHistoryRow`, `SliderObsidienne`,
//     `CeremonieFlamme`, `CoupeEtat`.
//   - la séance vide et la feuille Ajouter : celles de la v7.
//
// ⚠️ ALLUMÉE POUR TOUS DEPUIS LE TESTFLIGHT 86 (01-10, choix de Kathryn).
// L'ancienne séance reste joignable : `-ancienneSeance`, ou la clé
// `nosfy.seanceV7` posée à `false`.

enum SeanceV7 {
    static var actif: Bool {
        if CommandLine.arguments.contains("-ancienneSeance") { return false }
        if CommandLine.arguments.contains("-seanceV7") { return true }
        return UserDefaults.standard.object(forKey: "nosfy.seanceV7") as? Bool ?? true
    }
    /// Barreau : la page sans ses braises.
    static let sansBraises = CommandLine.arguments.contains("-sansBraisesV7")
    /// Barreau : la tête des cartes sans le vrai verre (la lumière seule).
    static let sansVerre = CommandLine.arguments.contains("-sansVerreV7")
    /// Barreau : pas de comètes au premier lancement d'un exercice, ni à la
    /// séance complète (la coupe sourde à la place).
    static let sansFeu = CommandLine.arguments.contains("-sansFeuV7")
    /// LE BANC (`-v7Banc <étape>`) : cartes, cote, glisse, ajout, vide, lancer.
    /// Captures d'écran automatisées uniquement.
    static let banc = UserDefaults.standard.string(forKey: "v7Banc")
}

// MARK: - L'état : le plan de la séance (en mémoire) et la série à lancer

@Observable @MainActor
final class SeanceV7Etat {
    static let shared = SeanceV7Etat()

    /// Un exercice de la séance : combien de séries prévues (faites
    /// comprises) et les valeurs proposées pour les suivantes.
    struct Prevu: Identifiable, Equatable, Codable {
        let id: String
        var nombre: Int
        var reps: Int
        var kilos: Double
        var secondes: Int
    }

    var seance: PersistentIdentifier?
    /// LE PLAN EST GARDÉ SUR LE TÉLÉPHONE (01-10, « pourquoi j'ai Terminer ? ») :
    /// il ne vivait qu'en mémoire — un relancement en pleine séance perdait
    /// les exercices prévus pas encore commencés, la page croyait tout fait
    /// et le slider proposait « Terminer la séance ». Une clé par séance.
    var plan: [Prevu] = [] { didSet { sauverPlan() } }
    @ObservationIgnored private var clePlan: String?

    private func sauverPlan() {
        guard let clePlan, let d = try? JSONEncoder().encode(plan) else { return }
        UserDefaults.standard.set(d, forKey: clePlan)
    }
    private static func planGarde(_ cle: String) -> [Prevu]? {
        guard let d = UserDefaults.standard.data(forKey: cle) else { return nil }
        return try? JSONDecoder().decode([Prevu].self, from: d)
    }
    /// La série demandée depuis la page : la fiche de CET exercice la lance
    /// dès qu'elle s'ouvre (la porte posée, ou le tapis), puis l'oublie
    /// (`ExerciseDetailView.lancerDepuisLaSeanceV7`).
    var lancerDirect: String?

    /// Les séries déjà montrées faites : une série qui n'y est pas vient de
    /// tomber — sa flamme PREND FEU à l'arrivée sur la page, une fois.
    @ObservationIgnored var vues: Set<PersistentIdentifier> = []
    @ObservationIgnored var cardiosVus: Set<String> = []
    /// Les exercices déjà lancés dans les comètes : une fois chacun.
    @ObservationIgnored var feuxJoues: Set<String> = []
    /// La fête de la séance complète : une fois, jusqu'à la prochaine série
    /// ajoutée.
    @ObservationIgnored var completeFetee = false
    /// Le dernier passage des comètes (le chevron de la fiche compris) :
    /// deux feux qui se chevauchent se figeraient l'un sur l'autre.
    @ObservationIgnored var dernierFeu: Date = .distantPast
    /// L'arrivée de la page : elle a pu arriver DANS des comètes (le départ
    /// de séance, le chevron) — tant qu'elles brûlent, pas de second feu.
    @ObservationIgnored var apparue: Date = .distantPast

    func logged(_ exo: String, dans a: Workout) -> LoggedExercise? {
        a.orderedExercises.first { $0.exerciseID == exo }
    }
    /// Ce qui est FAIT : les séries validées — ou, pour le cardio, un
    /// passage mesuré.
    /// TOUS les passages de l'exercice dans la séance : la fiche ouvre un
    /// bloc neuf à chaque passage (`ancrerSerie`), et la page n'en lisait que
    /// le premier — une 4ᵉ série faite plus tard restait invisible (01-10).
    func blocs(_ exo: String, dans a: Workout) -> [LoggedExercise] {
        a.orderedExercises.filter { $0.exerciseID == exo }
    }
    func faits(_ exo: String, dans a: Workout) -> [StrengthSet] {
        blocs(exo, dans: a).flatMap(\.orderedSets).filter(\.isDone)
    }
    func cardioFait(_ exo: String, dans a: Workout) -> Bool {
        blocs(exo, dans: a).contains { !$0.phasesFaites.isEmpty }
    }

    func accorder(_ a: Workout) {
        if seance != a.persistentModelID {
            seance = a.persistentModelID
            clePlan = nil
            let cle = "nosfy.seanceV7.plan.\(a.remoteID.uuidString)"
            plan = Self.planGarde(cle) ?? []
            clePlan = cle
            // Ce qui était fait AVANT que la page ne s'ouvre ne se rallume pas.
            // (Le banc `allume` ne marque rien : tout ce qui est fait prend feu.)
            let banc = SeanceV7.banc == "allume"
            vues = banc ? [] : Set(a.orderedExercises.flatMap(\.orderedSets)
                .filter(\.isDone).map(\.persistentModelID))
            cardiosVus = banc ? [] : Set(a.orderedExercises
                .filter { !$0.phasesFaites.isEmpty }.map(\.exerciseID))
            feuxJoues = []
            completeFetee = false
        }
        for le in a.orderedExercises where !plan.contains(where: { $0.id == le.exerciseID }) {
            let f = faits(le.exerciseID, dans: a), der = f.last
            let cardio = le.exercise?.tracking != .setsRepsWeight
            plan.append(Prevu(id: le.exerciseID, nombre: cardio ? 1 : max(3, f.count),
                              reps: der?.reps ?? 10, kilos: der?.weight ?? 20,
                              secondes: der?.durationSeconds ?? 45))
        }
    }

    func rangs(_ p: Prevu, exo: Exercise, dans a: Workout) -> [RangV7] {
        let le = logged(p.id, dans: a)
        if exo.tracking != .setsRepsWeight {
            // SES lignes de cardio, telles que la partition les lit.
            if let le, !le.phasesFaites.isEmpty {
                let l = SlateGroupe.lignes(de: le, restSeconds: le.restSeconds).filter(\.done)
                return l.enumerated().map { i, x -> RangV7 in
                    RangV7(exo: p.id, rang: i, fait: true, ligne: x, set: nil)
                }
            }
            return [RangV7(exo: p.id, rang: 0, fait: false, ligne: nil, set: nil)]
        }
        let repos = le?.restSeconds ?? 60
        let f = faits(p.id, dans: a)
        var r = f.enumerated().map { i, s -> RangV7 in
            var l = SlateLigne(reps: s.reps, kilos: s.weight, seconds: s.durationSeconds, done: true)
            l.saisie = exo.saisie
            return RangV7(exo: p.id, rang: i, fait: true, ligne: l, set: s.persistentModelID)
        }
        if p.nombre > f.count {
            for i in f.count..<p.nombre {
                var l = SlateLigne(reps: p.reps, kilos: p.kilos, seconds: repos, done: false)
                l.saisie = exo.saisie
                r.append(RangV7(exo: p.id, rang: i, fait: false, ligne: l, set: nil))
            }
        }
        return r
    }

    /// Une série faite que la page n'a pas encore montrée.
    func neuve(_ r: RangV7) -> Bool {
        guard r.fait else { return false }
        if let s = r.set { return !vues.contains(s) }
        return !cardiosVus.contains(r.exo)
    }
    func montree(_ r: RangV7) {
        if let s = r.set { vues.insert(s) } else { cardiosVus.insert(r.exo) }
    }

    /// Le prochain exercice à faire, dans l'ordre du plan.
    func prochain(dans a: Workout) -> (exo: String, rang: Int)? {
        for p in plan {
            guard let e = ExerciseCatalog.exercise(id: p.id) else { continue }
            if e.tracking != .setsRepsWeight {
                if !cardioFait(p.id, dans: a) { return (p.id, 0) }
                continue
            }
            let n = faits(p.id, dans: a).count
            if n < p.nombre { return (p.id, n) }
        }
        return nil
    }

    func ajouter(_ exos: [Exercise], historique: [String: PropositionExo]) {
        for e in exos where !plan.contains(where: { $0.id == e.id }) {
            let h = historique[e.id]
            plan.append(Prevu(id: e.id, nombre: e.tracking == .setsRepsWeight ? 3 : 1,
                              reps: h?.reps ?? 10, kilos: h?.kilos ?? 20, secondes: 45))
        }
        if !exos.isEmpty { completeFetee = false }
    }

    /// « Reprendre la dernière » : les exercices de la dernière séance
    /// finie, avec ce qui y avait été fait.
    func reprendre(_ w: Workout) {
        for le in w.orderedExercises where !plan.contains(where: { $0.id == le.exerciseID }) {
            let f = le.orderedSets.filter(\.isDone), der = f.last
            let cardio = le.exercise?.tracking != .setsRepsWeight
            plan.append(Prevu(id: le.exerciseID, nombre: cardio ? 1 : max(1, f.count),
                              reps: der?.reps ?? 10, kilos: der?.weight ?? 20,
                              secondes: der?.durationSeconds ?? 45))
        }
        completeFetee = false
    }

    func supprimer(_ r: RangV7, dans a: Workout, context: ModelContext) {
        if let id = r.set,
           let s = blocs(r.exo, dans: a).compactMap({ $0.sets?.first(where: { $0.persistentModelID == id }) }).first {
            context.delete(s)
            try? context.save()
            WorkoutActivityController.sync(a)
        }
        if let i = plan.firstIndex(where: { $0.id == r.exo }) {
            plan[i].nombre = max(faits(r.exo, dans: a).count, plan[i].nombre - 1)
        }
    }

    func ajouterSerie(_ exo: String) {
        if let i = plan.firstIndex(where: { $0.id == exo }) { plan[i].nombre += 1 }
        completeFetee = false
    }

    func retirer(_ exo: String, dans a: Workout, context: ModelContext) {
        let tous = blocs(exo, dans: a)
        if !tous.isEmpty {
            tous.forEach { context.delete($0) }
            try? context.save()
            WorkoutActivityController.sync(a)
        }
        plan.removeAll { $0.id == exo }
    }

    func deplacer(_ exo: String, avant cibleID: String) {
        guard exo != cibleID, let i = plan.firstIndex(where: { $0.id == exo }) else { return }
        let p = plan.remove(at: i)
        let j = plan.firstIndex(where: { $0.id == cibleID }) ?? plan.count
        plan.insert(p, at: j)
    }
}

/// Une rangée de la carte : faite (sa ligne, son `StrengthSet`) ou prévue.
/// `ligne == nil` : un cardio pas encore couru.
struct RangV7: Identifiable {
    let exo: String
    let rang: Int
    let fait: Bool
    let ligne: SlateLigne?
    let set: PersistentIdentifier?
    var id: String { "\(exo)-\(rang)-\(fait ? "f" : "p")" }
}

// MARK: - LA PAGE

struct SeanceV7Page: View {
    @Binding var morph: CGFloat
    let seance: Workout
    var onStop: () -> Void
    /// SA fiche : la courbe, le coach, son départ, son cadran. Appelée SOUS
    /// la coupe, et la page se range aussitôt (`poserFerme`).
    var onChoisirExo: (Exercise) -> Void
    /// LA CLÔTURE DIRECTE (03-10, TestFlight 86 : « pourquoi deux sliders ») :
    /// glissé jusqu'au bout, le slider de la page EST la confirmation — la
    /// séance se termine, sans la carte STOP et son second slider (comme
    /// « glisser pour éteindre »). La carte reste au ■ de la pastille.
    var onTerminer: () -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: \Workout.startedAt, order: .reverse) private var seances: [Workout]
    @State private var ajout = false
    @State private var tire: CGFloat = 0
    @State private var tirePris = false
    /// LA PLAYLIST D'UN EXERCICE (04-10, « quand je clique sur la ligne, ça
    /// ouvre la card avec le détail des séries faites ») : ouverte par la
    /// ligne ; la vignette ou le nom, dedans, ouvrent la fiche.
    @State private var playlist: String?
    private var etat: SeanceV7Etat { .shared }

    private static let haut: CGFloat = 58
    /// (01-10, « le slider pas assez bas ») : la barre descend près du bord.
    private static let bas: CGFloat = 6

    /// La page est posée, immobile : ses horloges ont le droit de battre.
    private var pose: Bool { morph > 0.98 && tire < 0.5 && !ajout }
    /// ⚠️ EN SÉANCE, TOUJOURS LE SLIDER (Kathryn, 02-10 : le choix galet ou
    /// slider du profil vaut sur la fiche d'un exercice HORS séance, « jamais
    /// pendant la session en cours »). La page ne lit plus le réglage : son
    /// slider lance la série directement, pour tous les comptes.
    private var departSlider: Bool { true }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                FondV7(fige: !pose, video: etat.plan.isEmpty)
                page
                    .scaleEffect(ajout || playlist != nil ? 0.93 : 1, anchor: .top)
                    .offset(y: ajout || playlist != nil ? 18 : 0)
                    .brightness(ajout || playlist != nil ? -0.32 : 0)
                    .clipShape(RoundedRectangle(cornerRadius: ajout || playlist != nil ? 40 : 0, style: .continuous))
                    .allowsHitTesting(!ajout && playlist == nil)
                if let id = playlist, let exo = ExerciseCatalog.exercise(id: id),
                   let p = etat.plan.first(where: { $0.id == id }) {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                        .onTapGesture { fermerPlaylist() }
                        .transition(.opacity)
                    PlaylistV7(exo: exo, rangs: etat.rangs(p, exo: exo, dans: seance),
                               prochaine: prochain?.exo == id ? prochain?.rang : nil,
                               hauteur: geo.size.height,
                               onFermer: { fermerPlaylist() },
                               onFiche: { fermerPlaylist(); partir(exo, lancer: false) },
                               onLancer: { fermerPlaylist(); partir(exo, lancer: true) },
                               onAjouterSerie: {
                                   withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { etat.ajouterSerie(id) }
                               },
                               onSupprimer: { r in
                                   withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                                       etat.supprimer(r, dans: seance, context: context)
                                   }
                               })
                    .transition(.move(edge: .bottom))
                    .zIndex(3)
                }
                if ajout {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                        .onTapGesture { fermerAjout() }
                        .transition(.opacity)
                    FeuilleAjoutV7(historique: historique, hauteur: geo.size.height,
                                   onAnnuler: { fermerAjout() }) { exos in
                        fermerAjout()
                        withAnimation(.spring(response: 0.55, dampingFraction: 0.82).delay(0.2)) {
                            etat.ajouter(exos, historique: historique)
                        }
                    }
                    .transition(.move(edge: .bottom))
                    .zIndex(3)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: tire > 1 ? 44 : 0, style: .continuous))
            .scaleEffect(1 - min(tire, 400) / 2400, anchor: .bottom)
            .offset(y: (1 - morph) * geo.size.height + tire)
            .opacity(Double(min(1, morph * 1.6)))
        }
        .onAppear {
            etat.accorder(seance)
            etat.apparue = .now
        }
        .onChange(of: seance.exerciseCount) { _, _ in etat.accorder(seance) }
        .onDisappear { CouvertureFoyer.shared.retirer() }
        .task { await jouerLeBanc() }
        .task(id: complete && pose) { await feterLaSeance() }
    }

    private var historique: [String: PropositionExo] {
        var h: [String: PropositionExo] = [:]
        for z in ExerciseCategory.allCases {
            for p in NosfyPropose.propositions(seances: seances, zone: z) { h[p.id] = p }
        }
        return h
    }

    /// LA DERNIÈRE SÉANCE D'UN AUTRE JOUR (03-10, TestFlight 86 : « des fois
    /// je vois un composant qui me redemande de rejouer la série faite ») :
    /// jamais celle qu'on vient de finir aujourd'hui.
    private var derniere: Workout? {
        seances.first { w in
            guard let fin = w.endedAt, !w.orderedExercises.isEmpty,
                  w.persistentModelID != seance.persistentModelID else { return false }
            return !Calendar.current.isDateInToday(fin)
        }
    }

    private var prochain: (exo: String, rang: Int)? { etat.prochain(dans: seance) }
    /// Tout le plan est fait.
    private var complete: Bool { !etat.plan.isEmpty && prochain == nil }

    // MARK: la page

    /// L'ARRIVÉE (04-10, « anime en mode magnifique, poli, de la partie
    /// empty à la partie séance ») : 0 = la page vide, 1 = la séance posée.
    /// Le « + » central glisse se ranger dans la barre du bas, la page vide
    /// s'efface, puis la séance monte en trois temps (le titre, le chiffre,
    /// les lignes). Des valeurs animées, jamais une horloge.
    @State private var arrivee: CGFloat = 0
    @State private var montee: Int = 0
    @Namespace private var plusNS

    private var page: some View {
        ZStack(alignment: .top) {
            if etat.plan.isEmpty {
                VideV7(derniere: derniere, plusNS: plusNS,
                       onRefaire: { w in arriver { etat.reprendre(w) } },
                       onAjouter: { ouvrirAjout() })
                    .transition(.opacity.animation(.easeOut(duration: 0.35)))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        TeteFineV7(titre: titreFin, nombre: chiffre.n, legende: chiffre.legende,
                                   t1: montee >= 1, t2: montee >= 2)
                            .padding(.top, Self.haut + 74)
                        VStack(spacing: 0) {
                            ForEach(etat.plan) { p in ligne(p) }
                        }
                        .padding(.top, 26)
                        .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.1)).frame(height: 1).padding(.top, 26) }
                        .monte(montee >= 3)
                        Color.clear.frame(height: 150)
                    }
                    .padding(.horizontal, 24)
                }
                .scrollIndicators(.hidden)
            }
            barreHaut
            if !etat.plan.isEmpty {
                VStack { Spacer(); barreBas.monte(montee >= 3) }
                    .transition(.opacity)
            }
        }
        .background { HaloDoigtV7().allowsHitTesting(false) }
        .simultaneousGesture(HaloDoigtEtat.geste)
        .animation(.spring(response: 0.55, dampingFraction: 0.84), value: etat.plan.isEmpty)
        .onChange(of: etat.plan.isEmpty, initial: true) { _, vide in
            if vide { montee = 0 } else if montee == 0 { Task { await monter() } }
        }
    }

    /// Le plan se remplit SOUS le geste de sortie de la page vide : le « + »
    /// part d'abord (le `matchedGeometryEffect` fait le trajet), la séance
    /// monte ensuite.
    private func arriver(_ remplir: @escaping () -> Void) {
        Haptique.moyen()
        withAnimation(.spring(response: 0.8, dampingFraction: 0.86)) { remplir() }
    }

    private func monter() async {
        try? await Task.sleep(for: .seconds(0.22))
        withAnimation(.spring(response: 0.55, dampingFraction: 0.88)) { montee = 1 }
        try? await Task.sleep(for: .seconds(0.14))
        withAnimation(.spring(response: 0.55, dampingFraction: 0.88)) { montee = 2 }
        try? await Task.sleep(for: .seconds(0.12))
        withAnimation(.spring(response: 0.55, dampingFraction: 0.88)) { montee = 3 }
    }

    /// LE TITRE DYNAMIQUE (04-10) : « Prête. » avant la première série,
    /// « En cours. » ensuite, « Tout est fait. » à la fin.
    private var titreFin: String {
        if complete { return L("Tout est fait.", "All done.") }
        return seance.seriesPayantes == 0 ? L("Prête.", "Ready.") : L("En cours.", "In progress.")
    }

    /// LE CHIFFRE ENTRE DEUX TRAITS — des faits, jamais une prévision de
    /// charge : « 3 exercices, 10 séries » → « 3 séries, 12 min » → « 10
    /// séries, 32 min ».
    private var chiffre: (n: Int, legende: String) {
        let faites = seance.seriesPayantes
        let minutes = max(1, Int(Date.now.timeIntervalSince(seance.startedAt ?? .now) / 60))
        if faites == 0 {
            let prevues = etat.plan.reduce(0) { $0 + $1.nombre }
            let exos = etat.plan.count
            return (exos, (exos > 1 ? L("exercices", "exercises") : L("exercice", "exercise")) + ", " + nombreDeSeries(prevues))
        }
        let mot = faites > 1 ? L("séries", "sets") : L("série", "set")
        return (faites, "\(mot), \(minutes) min")
    }

    /// Une ligne fine par exercice : la vignette, le nom, ce qui est fait
    /// (ou prévu), ses flammes, le chevron. Toucher : la fiche (lancer si
    /// c'est le prochain).
    private func ligne(_ p: SeanceV7Etat.Prevu) -> some View {
        let exo = ExerciseCatalog.exercise(id: p.id) ?? ExerciseCatalog.all[0]
        let n = prochain
        let rangs = etat.rangs(p, exo: exo, dans: seance)
        return LigneExoV7(exo: exo, rangs: rangs,
                          vient: n?.exo == p.id,
                          neuves: rangs.filter { etat.neuve($0) }.map(\.id),
                          onMontree: { r in etat.montree(r) },
                          onToucher: { ouvrirPlaylist(p.id) },
                          onFiche: { partir(exo, lancer: false) })
            .draggable(p.id)
            .dropDestination(for: String.self) { ids, _ in
                guard let id = ids.first else { return false }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.84)) { etat.deplacer(id, avant: p.id) }
                return true
            }
    }

    /// ‹ à gauche, rien d'autre. ⚠️ PLUS DE « TERMINER » EN HAUT (03-10,
    /// TestFlight 86 : « des fois le bouton terminé en haut, des fois en bas
    /// avec le slider, ça va pas ») : on termine à UN endroit, le slider du
    /// bas quand tout est fait ; avant, par le ■ de la pastille (la carte STOP).
    private var barreHaut: some View {
        HStack {
            MedaillonStop(symbol: "chevron.left", taille: 40) { fermer() }
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, Self.haut)
        .frame(maxWidth: .infinity)
        .frame(height: Self.haut + 64, alignment: .top)
        // Le voile ne sert qu'à la liste qui défile dessous : sur la séance
        // vide, il éteignait la lampe de l'île (vu au simulateur le 03-10).
        .background(
            LinearGradient(colors: [.black.opacity(etat.plan.isEmpty ? 0 : 0.86), .black.opacity(0)],
                           startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false))
        .contentShape(Rectangle())
        .gesture(glisserPourFermer)
    }

    /// Un effleurement vers le bas, comme Spotify : la page descend avec
    /// le doigt et se range dans la pastille.
    /// ⚠️ `.global` : le geste est posé sur la vue qu'il déplace — en local,
    /// la translation rétrécit à mesure que la page descend (la boucle payée
    /// par le lecteur le 04-09).
    private var glisserPourFermer: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { v in
                guard v.translation.height > 0 || tirePris else { return }
                if !tirePris {
                    tirePris = true
                    CouvertureFoyer.shared.commencerDeplacement()
                }
                tire = max(0, v.translation.height)
            }
            .onEnded { v in
                guard tirePris else { return }
                tirePris = false
                if v.translation.height > 120 || v.predictedEndTranslation.height > 260 {
                    fermer()
                    return
                }
                let couverture = CouvertureFoyer.shared
                let jeton = couverture.commencerDeplacement()
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8),
                              completionCriteria: .removed) {
                    tire = 0
                } completion: {
                    guard morph >= 0.98, !tirePris, tire == 0 else { return }
                    couverture.terminerDeplacement(jeton)
                }
            }
    }

    private func fermer() {
        Haptique.leger()
        CouvertureFoyer.shared.retirer()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.92)) {
            morph = 0
            tire = 0
        }
    }

    /// LA FERMETURE SANS MOUVEMENT — sous la coupe, la page n'est simplement
    /// plus là quand le noir se lève (la même que `GrandPlayer.poserFerme`).
    private func poserFerme() {
        CouvertureFoyer.shared.retirer()
        var tr = Transaction()
        tr.disablesAnimations = true
        withTransaction(tr) {
            morph = 0
            tire = 0
        }
    }

    /// LE BAS — SON départ, celui du compte (Réglages) : le slider lance la
    /// série droit dans le cadran ; au galet, « Allez, go » ouvre sa fiche,
    /// où le galet attend son doigt. Et « + » en médaillon.
    private var barreBas: some View {
        HStack(spacing: 12) {
            depart
            MedaillonStop(symbol: "plus", taille: 56) { ouvrirAjout() }
                .matchedGeometryEffect(id: "plus", in: plusNS)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, Self.bas)
        .padding(.top, 40)
        .background(
            LinearGradient(colors: [.black.opacity(0), .black.opacity(0.96)],
                           startPoint: .top, endPoint: .init(x: 0.5, y: 0.34))
                .allowsHitTesting(false))
    }

    @ViewBuilder
    private var depart: some View {
        if prochain == nil {
            // TOUT EST FAIT : SON slider reste (01-10, « pourquoi il n'y a
            // plus le slider en bas ») — c'est lui qui termine la séance, et le
            // « Terminer » du haut se retire pour ne pas le dire deux fois.
            SliderObsidienne(label: L("Terminer", "Finish"), height: 58,
                             legende: (L("Terminer la séance", "Finish the session"),
                                       nombreDeSeries(seance.setsAffiches)),
                             onConfirm: onTerminer)
                .environment(\.ongletCache, !pose)
        } else if departSlider {
            // ⚠️ SON HORLOGE DORT dès que la page n'est plus posée (geste,
            // feuille Ajouter, fermeture) : il tient 60 Hz tant qu'il vit.
            SliderObsidienne(label: libelleAction, height: 58, legende: legendeAction,
                             onConfirm: action)
                .environment(\.ongletCache, !pose)
                .id(libelleAction)
        } else {
            BoutonPrimaire(title: libelleAction, glyph: "play.fill",
                           respecteLaCasse: true) { action() }
        }
    }

    private var libelleAction: String {
        guard let n = prochain, let e = ExerciseCatalog.exercise(id: n.exo) else {
            return L("Terminer la séance", "Finish the session")
        }
        if e.tracking != .setsRepsWeight { return L("Allez, go · \(e.nomLocalise)", "Let's go · \(e.nomLocalise)") }
        return L("Allez, go · Série \(n.rang + 1)", "Let's go · Set \(n.rang + 1)")
    }

    /// LA PROCHAINE ÉTAPE ÉCRITE DANS LE SLIDER (01-10, Kathryn : « rajoute
    /// dans le slider la prochaine étape ») : « Série 4 · Woodchopper » et sa
    /// charge, au repos ; ils s'effacent dès que le pouce part.
    private var legendeAction: (titre: String, sous: String)? {
        guard let n = prochain, let e = ExerciseCatalog.exercise(id: n.exo) else { return nil }
        guard e.tracking == .setsRepsWeight else { return (e.nomLocalise, L("Cardio", "Cardio")) }
        // Le nom en titre, la série dessous — jamais de reps ni de poids
        // prévus : on ne les connaît pas à l'avance (02-10).
        return (e.nomLocalise, L("Série \(n.rang + 1)", "Set \(n.rang + 1)"))
    }

    private func action() {
        guard let n = prochain, let e = ExerciseCatalog.exercise(id: n.exo) else { onTerminer(); return }
        partir(e, lancer: true)
    }

    /// PARTIR VERS SA FICHE. Sous la coupe : la fiche s'ouvre, la page se
    /// range, et — au slider — la fiche lance aussitôt la série.
    /// LES COMÈTES (validé le 30-09) : au PREMIER lancement de chaque
    /// exercice ; sinon la coupe sourde, dont le noir tient le temps que le
    /// cadran se monte (le remède de `lancerAuSlider`).
    private func partir(_ e: Exercise, lancer: Bool) {
        Haptique.moyen()
        let direct = lancer && departSlider
        etat.lancerDirect = direct ? e.id : nil
        // ⚠️ LA PAGE RESTE POSÉE LE TEMPS QUE LA FICHE NAISSE DESSOUS (filmé
        // au sim le 30-09, 15 i/s) : rangée dans le même tour, elle laissait
        // voir l'ACCUEIL deux images sous le voile — l'onglet bascule au rendu
        // suivant, la fiche et son cadran se montent après.
        let bascule = {
            onChoisirExo(e)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { poserFerme() }
        }
        if direct, !SeanceV7.sansFeu, !etat.feuxJoues.contains(e.id),
           Date.now.timeIntervalSince(etat.dernierFeu) > 5,
           Date.now.timeIntervalSince(etat.apparue) > 4 {
            etat.feuxJoues.insert(e.id)
            etat.dernierFeu = .now
            CoupeEtat.shared.jouer(bascule)
        } else {
            CoupeEtat.shared.couper(tenue: direct ? 0.45 : 0.3, bascule)
        }
    }

    /// LA SÉANCE COMPLÈTE — tout le plan est fait, la page est posée : les
    /// comètes passent une fois sur la page elle-même. Jamais par-dessus un
    /// autre feu (le chevron de la fiche en joue un en rendant la page).
    private func feterLaSeance() async {
        guard complete, pose, !etat.completeFetee, !SeanceV7.sansFeu else { return }
        try? await Task.sleep(for: .seconds(1.1))
        guard !Task.isCancelled, complete, !etat.completeFetee else { return }
        etat.completeFetee = true
        guard Date.now.timeIntervalSince(etat.dernierFeu) > 5,
              Date.now.timeIntervalSince(etat.apparue) > 4 else { return }
        etat.dernierFeu = .now
        CoupeEtat.shared.jouer {}
    }

    private func ouvrirPlaylist(_ id: String) {
        Haptique.leger()
        withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) { playlist = id }
    }
    private func fermerPlaylist() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) { playlist = nil }
    }

    private func ouvrirAjout() {
        Haptique.leger()
        withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) { ajout = true }
    }
    private func fermerAjout() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) { ajout = false }
    }

    // MARK: la grosse carte — ARCHIVÉE le 04-10 (« pas assez Apple ») : la
    // page est en lignes fines (`LigneExoV7`). `CarteExoV7` et `RangeeV7`
    // restent ci-dessous, sans site d'appel.

    // MARK: la séance vide — celle de la v7

    // (L'état vide du 01-10 — « Compose ta séance. », la carte « TA SÉANCE DE
    //  LA SEMAINE », « Ajouter un exercice » — est remplacé le 03-10 par
    //  `VideV7`. `SeanceDeLaSemaine` reste ci-dessous, sans site d'appel.)

    // MARK: le banc

    nonisolated(unsafe) static var bancJoue = false

    private func jouerLeBanc() async {
        guard let banc = SeanceV7.banc else { return }
        try? await Task.sleep(for: .seconds(0.8))
        if banc == "vide" { return }
        if banc == "ajout" { ouvrirAjout(); return }
        let exos = ["woop-haute", "crunch-sol", "gainage"].compactMap { ExerciseCatalog.exercise(id: $0) }
        // `arrivee` (04-10) : la page vide tient 2 s, puis l'arrivée se joue
        // comme au doigt (le « + » qui part, la montée en trois temps).
        if banc == "arrivee" { try? await Task.sleep(for: .seconds(2)) }
        arriver { etat.ajouter(exos, historique: historique) }
        print("[v7banc] cartes posées : \(etat.plan.count)")
        // Un geste par lancement : la page se remonte à chaque retour, et le
        // banc relancerait sans fin.
        guard !SeanceV7Page.bancJoue else { return }
        // `serie` (01-10) : une série AJOUTÉE au premier exercice de muscu,
        // lancée aussitôt — pour voir le lecteur en série en cours sur une
        // séance déjà faite.
        if banc == "serie", let p = etat.plan.first(where: {
               ExerciseCatalog.exercise(id: $0.id)?.tracking == .setsRepsWeight }),
           let e = ExerciseCatalog.exercise(id: p.id) {
            SeanceV7Page.bancJoue = true
            try? await Task.sleep(for: .seconds(1.4))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { etat.ajouterSerie(p.id) }
            try? await Task.sleep(for: .seconds(0.8))
            print("[v7banc] série ajoutée et lancée : \(e.id)")
            partir(e, lancer: true)
        }
        if banc == "lancer" {
            SeanceV7Page.bancJoue = true
            try? await Task.sleep(for: .seconds(1.6))
            print("[v7banc] « Allez, go » : \(libelleAction)")
            action()
        }
        // `fiche` : la tête de la première carte, puis — 3,5 s plus tard — le
        // retour de « Choisir un autre exercice » (`rendreLaBibliotheque` :
        // la coupe sourde, `ouvrirLecteur`). Une tâche détachée : la page
        // est démontée pendant ce temps.
        if banc == "fiche", let p = etat.plan.first, let e = ExerciseCatalog.exercise(id: p.id) {
            SeanceV7Page.bancJoue = true
            try? await Task.sleep(for: .seconds(1.6))
            print("[v7banc] fiche de \(e.id)")
            partir(e, lancer: false)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3.5))
                print("[v7banc] retour à la page")
                CoupeEtat.shared.couper(tenue: 0.25) { PlayerEtat.shared.ouvrirLecteur = true }
            }
        }

    }
}

/// « 1 série », « 3 séries » — jamais « 1 séries » (03-10). Une fonction, pas
/// un ternaire dans une concaténation : le type-checker y cale (loi §1).
func nombreDeSeries(_ n: Int) -> String {
    n > 1 ? L("\(n) séries", "\(n) sets") : L("\(n) série", "\(n) set")
}

// MARK: - La séance vide (04-10 : « bien lui, avec la pilule noire discrète en fond »)

/// La v1 de l'artefact, validée le 04-10 : l'en-tête de la page, le « + » au
/// centre, « Compose ta séance », et en bas « Ta dernière séance » en verre,
/// avec « Refaire ». Compte neuf : pas de carte (aucun fait inventé). Le
/// galet noir de la maison en filigrane, dans le fond (`FondV7`).
/// (La version « Let's go » du 03-10 — grand titre, chiffre entre traits,
/// flamme — a été refusée : « hors sujet, je voulais un état empty ».)
private struct VideV7: View {
    let derniere: Workout?
    let plusNS: Namespace.ID
    var onRefaire: (Workout) -> Void
    var onAjouter: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            EnteteV7Vide()
                .padding(.horizontal, 20)
                .padding(.top, 110)
            Spacer(minLength: 0)
            VStack(spacing: 30) {
                MedaillonStop(symbol: "plus", taille: 96) { onAjouter() }
                    .matchedGeometryEffect(id: "plus", in: plusNS)
                Text(L("Compose ta séance", "Build your session"))
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 40)
            Spacer(minLength: 0)
            if let w = derniere { pied(w) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    private func pied(_ w: Workout) -> some View {
        let exos = w.orderedExercises.compactMap(\.exercise)
        let minutes = Int(((w.endedAt ?? .now).timeIntervalSince(w.startedAt ?? .now)) / 60)
        return VStack(alignment: .leading, spacing: 10) {
            Text(L("TA DERNIÈRE SÉANCE", "YOUR LAST SESSION"))
                .font(.inter(12.5, .medium))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.5))
                .padding(.horizontal, 8)
            Button(action: { Haptique.leger(); onRefaire(w) }) {
                HStack(spacing: 14) {
                    ZStack(alignment: .topLeading) {
                        ForEach(Array(exos.prefix(3).enumerated().reversed()), id: \.offset) { i, e in
                            ExercisePhoto(exercise: e)
                                .frame(width: 46 - CGFloat(i) * 3, height: 56 - CGFloat(i) * 6)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
                                .shadow(color: .black.opacity(0.7), radius: 6, x: 4)
                                .offset(x: CGFloat(i) * 14, y: CGFloat(i) * 3)
                        }
                    }
                    .frame(width: 74, height: 56, alignment: .topLeading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Self.quand(w))
                            .font(.system(size: 17, weight: .semibold))
                        Text(nombreDExercices(exos.count) + (minutes > 0 ? " · \(minutes) min" : ""))
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.58))
                    }
                    Spacer(minLength: 6)
                    Text(L("Refaire", "Redo"))
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.horizontal, 16).frame(height: 36)
                        .background(Capsule().fill(.white.opacity(0.16)))
                }
                .foregroundStyle(.white)
                .padding(12)
                .background(VerreV7(rayon: 26))
                .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 40)
    }

    /// « Vendredi » cette semaine ; « 12 sept. » au-delà de six jours.
    private static func quand(_ w: Workout) -> String {
        let d = w.endedAt ?? .now
        let f = DateFormatter()
        f.locale = Locale(identifier: Langue.en ? "en_US" : "fr_FR")
        let jours = Calendar.current.dateComponents([.day], from: d, to: .now).day ?? 99
        f.dateFormat = jours < 6 ? "EEEE" : "d MMM"
        let j = f.string(from: d)
        return j.prefix(1).uppercased() + j.dropFirst()
    }
}

func nombreDExercices(_ n: Int) -> String {
    n > 1 ? L("\(n) exercices", "\(n) exercises") : L("\(n) exercice", "\(n) exercise")
}

/// L'en-tête de la page vide : « Séance », le jour et le chrono, la pièce,
/// la tuile du jour — celui de la v1.
private struct EnteteV7Vide: View {
    private static let jourFR: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "fr_FR"); f.dateFormat = "EEEE d"; return f
    }()
    private static let jourEN: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US"); f.dateFormat = "EEEE d"; return f
    }()
    var body: some View {
        let s = (Langue.en ? Self.jourEN : Self.jourFR).string(from: .now)
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L("Séance", "Session"))
                    .font(.system(size: 34, weight: .bold))
                HStack(spacing: 10) {
                    Text(s.prefix(1).uppercased() + s.dropFirst())
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                    Bourse(pieces: 0)
                }
            }
            Spacer(minLength: 0)
            MiniCardJour(date: .now, sticker: "", faite: false, largeur: 58, hauteur: 66)
        }
        .foregroundStyle(.white)
    }
}

// MARK: - La tête de la séance en cours : TA SÉANCE, le titre, le chiffre (04-10)

/// La grammaire de « Terminer v1 » (« j'aimais bien les traits et le résumé »)
/// pour TOUTE la séance : les petites capitales, le titre au blanc dégradé,
/// le chiffre léger entre deux traits de 1 pt. `t1`, `t2` : les deux temps
/// de la montée.
private struct TeteFineV7: View {
    let titre: String
    let nombre: Int
    let legende: String
    let t1: Bool
    let t2: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L("TA SÉANCE", "YOUR SESSION"))
                .font(.inter(12.5, .medium))
                .tracking(3.6)
                .foregroundStyle(.white.opacity(0.46))
                .monte(t1)
            Text(titre)
                .font(.inter(44, .semibold))
                .tracking(-44 * 0.026)
                .foregroundStyle(MotsFlou.blancDegrade)
                .padding(.top, 16)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.35), value: titre)
                .monte(t1)
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("\(nombre)")
                    .font(.inter(50, .light))
                    .tracking(-1)
                    .foregroundStyle(MotsFlou.blancDegrade)
                    .contentTransition(t2 ? .numericText(value: Double(nombre)) : .identity)
                Text(legende)
                    .font(.inter(17))
                    .foregroundStyle(.white.opacity(0.55))
                    .contentTransition(.opacity)
            }
            .padding(.vertical, 13)
            .padding(.leading, 6)
            .padding(.trailing, 28)
            .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.22)).frame(height: 1) }
            .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.22)).frame(height: 1) }
            .fixedSize()
            .padding(.top, 20)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: nombre)
            .monte(t2)
        }
    }
}

/// La montée d'un bloc : opacité + 26 pt (jamais une taille).
private struct MonteV7: ViewModifier {
    let la: Bool
    func body(content: Content) -> some View {
        content
            .opacity(la ? 1 : 0)
            .offset(y: la ? 0 : 26)
    }
}
private extension View {
    func monte(_ la: Bool) -> some View { modifier(MonteV7(la: la)) }
}

// MARK: - Une ligne fine par exercice (04-10)

/// La vignette 40 × 44, le nom, le sous-titre (« 3 séries » / « 13 reps ·
/// 25 kg » une fois fait), les flammes blanches à droite — grises tant que
/// la série n'est pas faite —, le chevron. Celui qui vient en semibold, les
/// faits en retrait. Un filet d'un point à 0,1 sous chaque ligne.
private struct LigneExoV7: View {
    let exo: Exercise
    let rangs: [RangV7]
    let vient: Bool
    let neuves: [String]
    var onMontree: (RangV7) -> Void
    var onToucher: () -> Void
    var onFiche: () -> Void

    private var faits: [RangV7] { rangs.filter(\.fait) }
    private var fini: Bool { !rangs.isEmpty && faits.count == rangs.count }

    var body: some View {
        Button(action: { Haptique.leger(); onToucher() }) {
            HStack(spacing: 14) {
                // La vignette ouvre la FICHE (04-10) ; le reste de la ligne,
                // la playlist des séries.
                ExercisePhoto(exercise: exo)
                    .frame(width: 40, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.white.opacity(0.14), lineWidth: 0.5))
                    .opacity(fini ? 0.72 : 1)
                    .contentShape(Rectangle())
                    .highPriorityGesture(TapGesture().onEnded { Haptique.leger(); onFiche() })
                VStack(alignment: .leading, spacing: 2) {
                    Text(exo.nomLocalise)
                        .font(.system(size: 16, weight: vient ? .semibold : .regular))
                        .foregroundStyle(.white.opacity(fini ? 0.72 : 1))
                        .lineLimit(1)
                    Text(sous)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                // PAS DE FLAMME PAR DÉFAUT (04-10) : une flamme par série
                // FAITE, rien pour celles à venir.
                HStack(spacing: -5) {
                    ForEach(faits) { r in
                        FlammeBlancheV7(r: r, allumage: neuves.firstIndex(of: r.id), onMontree: { onMontree(r) })
                    }
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .frame(height: 64)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.1)).frame(height: 1) }
        }
        .buttonStyle(.plain)
    }

    /// Ce qui est fait, sinon ce qui est prévu. Jamais une prévision de charge.
    private var sous: String {
        if exo.tracking != .setsRepsWeight {
            guard let l = faits.last?.ligne else { return L("Effort et récup", "Effort and recovery") }
            let t = String(format: "%d:%02d", l.seconds / 60, l.seconds % 60)
            switch l.genre {
            case .intervalle(let v, let niv), .course(let v, let niv):
                return "\(t) · " + (niv ? L("niveau \(Int(v))", "level \(Int(v))") : "\(Exercise.Saisie.kg(v)) km/h")
            case .longueurs(let n, let m): return L("\(n) longueurs · \(m) m", "\(n) lengths · \(m) m")
            case .serie: return t
            }
        }
        guard let l = faits.last?.ligne, case .serie(let reps, let kilos) = l.genre else {
            return nombreDeSeries(rangs.count)
        }
        let v = exo.saisie.serie(reps: reps, kilos: kilos, secondes: l.done ? l.seconds : 0)
        let reste = rangs.count - faits.count
        return reste > 0 ? v + L(" · \(reste) à faire", " · \(reste) to go") : v
    }
}

/// La flamme blanche d'une série : grise à 0,2 tant qu'elle n'est pas faite ;
/// une série qui vient de tomber PREND FEU (`FlammeQuiPrend`, puis se pose
/// en blanc). Jamais de couleur hors le feu de l'allumage.
private struct FlammeBlancheV7: View {
    let r: RangV7
    let allumage: Int?
    var onMontree: () -> Void
    @State private var prise: Double

    init(r: RangV7, allumage: Int?, onMontree: @escaping () -> Void) {
        self.r = r; self.allumage = allumage; self.onMontree = onMontree
        _prise = State(initialValue: r.fait && allumage == nil ? 1 : 0)
    }

    var body: some View {
        ZStack {
            Image("sticker-flamme-serree")
                .renderingMode(.template)
                .resizable().scaledToFit()
                .frame(width: 15, height: 19)
                .foregroundStyle(.white)
                .shadow(color: .white.opacity(r.fait && prise >= 1 ? 0.45 : 0), radius: 3)
                .opacity(prise >= 1 ? 0.95 : 0)
            if r.fait, prise < 1 { FlammeQuiPrend(p: prise) }
        }
        .frame(width: 20, height: 24)
        .task(id: r.id) {
            guard r.fait, let i = allumage, prise < 1 else { return }
            onMontree()
            try? await Task.sleep(for: .seconds(0.75 + 0.34 * Double(i)))
            guard !Task.isCancelled else { prise = 1; return }
            withAnimation(.linear(duration: FlammeQuiPrend.duree)) { prise = 1 }
            try? await Task.sleep(for: .seconds(FlammeQuiPrend.duree * FlammeQuiPrend.naissance))
            Haptique.moyen()
        }
    }
}

// MARK: - La playlist d'un exercice (04-10)

/// « Quand je clique sur la ligne, ça ouvre la card avec le détail des séries
/// faites comme avant » : une feuille en verre, l'exercice en tête (sa
/// vignette et son nom ouvrent la FICHE), puis ses séries comme les pistes
/// d'un album — la faite avec sa flamme blanche et sa valeur (glisser pour
/// supprimer), la prochaine avec sa pastille ▶ en verre, les autres par leur
/// numéro — et « Ajouter une série » au bout. Rien d'autre : pas d'« À
/// suivre », les autres exercices sont sur la page.
private struct PlaylistV7: View {
    let exo: Exercise
    let rangs: [RangV7]
    let prochaine: Int?
    let hauteur: CGFloat
    var onFermer: () -> Void
    var onFiche: () -> Void
    var onLancer: () -> Void
    var onAjouterSerie: () -> Void
    var onSupprimer: (RangV7) -> Void

    @State private var tire: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(.white.opacity(0.34)).frame(width: 40, height: 5)
                .padding(.top, 8)
            tete
                .padding(.top, 14)
                .contentShape(Rectangle())
                .gesture(glisser)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(rangs) { r in
                        PisteV7(exo: exo, r: r, prochaine: prochaine == r.rang && !r.fait,
                                onLancer: onLancer, onSupprimer: { onSupprimer(r) })
                    }
                    if exo.tracking == .setsRepsWeight {
                        Button(action: { Haptique.leger(); onAjouterSerie() }) {
                            HStack(spacing: 16) {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .semibold))
                                    .frame(width: 22, height: 22)
                                Text(L("Ajouter une série", "Add a set"))
                                    .font(.system(size: 16, weight: .medium))
                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(height: 54)
                            .padding(.horizontal, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: min(hauteur * 0.62, 120 + CGFloat(rangs.count + 2) * 54 + 60))
        .background(fond)
        .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 44, style: .continuous)
            .strokeBorder(LinearGradient(colors: [.white.opacity(0.32), .white.opacity(0.06), .white.opacity(0.12)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .offset(y: tire)
    }

    private var tete: some View {
        Button(action: { Haptique.leger(); onFiche() }) {
            HStack(spacing: 14) {
                ExercisePhoto(exercise: exo)
                    .frame(width: 48, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.white.opacity(0.16), lineWidth: 0.5))
                VStack(alignment: .leading, spacing: 2) {
                    Text(exo.nomLocalise)
                        .font(.system(size: 18, weight: .semibold))
                        .lineLimit(1)
                    Text(exo.muscle)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(.horizontal, 22)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Le verre de la feuille : celui de la feuille d'ajout.
    private var fond: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            LinearGradient(colors: [Color(white: 0.24).opacity(0.6), Color(white: 0.08).opacity(0.86)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [.white.opacity(0.12), .clear], center: .init(x: 0.15, y: 0),
                           startRadius: 0, endRadius: 260)
        }
        .environment(\.colorScheme, .dark)
    }

    private var glisser: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { v in tire = max(0, v.translation.height) }
            .onEnded { v in
                if v.translation.height > 90 || v.predictedEndTranslation.height > 200 { onFermer() }
                else { withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) { tire = 0 } }
            }
    }
}

/// Une piste de la playlist.
private struct PisteV7: View {
    let exo: Exercise
    let r: RangV7
    let prochaine: Bool
    var onLancer: () -> Void
    var onSupprimer: () -> Void
    @State private var dx: CGFloat = 0
    @State private var ouvert = false
    private static let rouge: CGFloat = 92

    private var supprimable: Bool { r.set != nil }

    var body: some View {
        ZStack(alignment: .trailing) {
            if supprimable {
                Button(action: onSupprimer) {
                    Text(L("Supprimer", "Delete"))
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: Self.rouge).frame(maxHeight: .infinity)
                        .background(Color(red: 1, green: 0.27, blue: 0.23))
                }
                .buttonStyle(.plain)
                .opacity(ouvert || dx < -4 ? 1 : 0)
            }
            piste.offset(x: (ouvert ? -Self.rouge : 0) + dx)
        }
        .frame(height: 54)
        .clipped()
    }

    private var piste: some View {
        HStack(spacing: 16) {
            ZStack {
                if r.fait {
                    Image("sticker-flamme-serree")
                        .renderingMode(.template).resizable().scaledToFit()
                        .frame(width: 13, height: 16)
                        .foregroundStyle(.white)
                        .shadow(color: .white.opacity(0.4), radius: 3)
                } else if prochaine {
                    // LA PASTILLE ▶ EN VERRE (04-10) : la prochaine série.
                    Image(systemName: "play.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(.white.opacity(0.14)))
                        .overlay(Circle().strokeBorder(.white.opacity(0.4), lineWidth: 0.8))
                        .glassEffect(.clear, in: Circle())
                } else {
                    Text("\(r.rang + 1)")
                        .font(.system(size: 15))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .frame(width: 26, height: 26)
            Text(valeur)
                .font(.system(size: 17, weight: prochaine ? .semibold : .regular))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(prochaine ? 1 : (r.fait ? 0.6 : 0.4)))
                .lineLimit(1)
            Spacer(minLength: 0)
            if r.fait {
                Text(L("Série \(r.rang + 1)", "Set \(r.rang + 1)"))
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(.horizontal, 12)
        .frame(maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.white.opacity(prochaine ? 0.09 : 0)))
        .overlay(alignment: .bottom) {
            Rectangle().fill(.white.opacity(0.08)).frame(height: 0.5).padding(.leading, 54)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if ouvert { withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { ouvert = false }; return }
            if prochaine { onLancer() } else { Haptique.leger() }
        }
        .simultaneousGesture(glisser, isEnabled: supprimable)
    }

    private var valeur: String {
        guard r.fait, let l = r.ligne else { return L("Série \(r.rang + 1)", "Set \(r.rang + 1)") }
        let t = String(format: "%d:%02d", l.seconds / 60, l.seconds % 60)
        switch l.genre {
        case .serie(let reps, let kilos):
            return exo.saisie.serie(reps: reps, kilos: kilos, secondes: l.done ? l.seconds : 0)
        case .intervalle(let v, let niv), .course(let v, let niv):
            return "\(t) · " + (niv ? L("niveau \(Int(v))", "level \(Int(v))") : "\(Exercise.Saisie.kg(v)) km/h")
        case .longueurs(let n, let m): return L("\(n) longueurs · \(m) m", "\(n) lengths · \(m) m")
        }
    }

    private var glisser: some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { v in
                guard abs(v.translation.width) > abs(v.translation.height) else { return }
                dx = min(Self.rouge * 0.4, max(-Self.rouge * 1.3, v.translation.width))
            }
            .onEnded { v in
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                    if abs(v.translation.width) > abs(v.translation.height) {
                        ouvert = (ouvert ? -Self.rouge : 0) + v.translation.width < -Self.rouge / 2
                    }
                    dx = 0
                }
            }
    }
}

// MARK: - Le halo du doigt (04-10 : « quand je touche l'écran, le halo blanc dégradé »)

/// La loi de la maison : le pouce est la lampe. Un disque de lumière blanche
/// sans bord naît sous le doigt, le suit, et meurt au relâcher en s'élargissant.
/// Rien ne bouge tant que le doigt ne bouge pas ; jamais un balayage. L'état
/// vit dans un `@Observable` : seule la lampe se redessine, jamais la page.
@MainActor @Observable
final class HaloDoigtEtat {
    static let shared = HaloDoigtEtat()
    var point: CGPoint = .zero
    var pose = false
    static let sans = CommandLine.arguments.contains("-sansHaloDoigt")

    static var geste: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { v in
                let h = HaloDoigtEtat.shared
                h.point = v.location
                if !h.pose { withAnimation(.easeOut(duration: 0.28)) { h.pose = true } }
            }
            .onEnded { _ in withAnimation(.easeOut(duration: 0.9)) { HaloDoigtEtat.shared.pose = false } }
    }
}

private struct HaloDoigtV7: View {
    private var h: HaloDoigtEtat { .shared }
    var body: some View {
        GeometryReader { g in
            if !HaloDoigtEtat.sans {
                let o = g.frame(in: .global).origin
                Circle()
                    .fill(RadialGradient(stops: [.init(color: .white.opacity(0.22), location: 0),
                                                 .init(color: .white.opacity(0.09), location: 0.28),
                                                 .init(color: .white.opacity(0.025), location: 0.52),
                                                 .init(color: .clear, location: 0.7)],
                                         center: .center, startRadius: 0, endRadius: 180))
                    .frame(width: 360, height: 360)
                    .scaleEffect(h.pose ? 1 : 1.18)
                    .opacity(h.pose ? 1 : 0)
                    .position(x: h.point.x - o.x, y: h.point.y - o.y)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - La séance de la semaine : en une carte, à reprendre d'un geste

private struct SeanceDeLaSemaine: View {
    let seance: Workout
    var onReprendre: () -> Void

    var body: some View {
        let exos = seance.orderedExercises.compactMap(\.exercise)
        let series = seance.orderedExercises.reduce(0) { $0 + max($1.orderedSets.filter(\.isDone).count, $1.phasesFaites.isEmpty ? 0 : 1) }
        Button(action: { Haptique.leger(); onReprendre() }) {
            HStack(spacing: 13) {
                HStack(spacing: -14) {
                    ForEach(Array(exos.prefix(4).enumerated()), id: \.offset) { _, e in
                        ExercisePhoto(exercise: e)
                            .frame(width: 30, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color(white: 0.07), lineWidth: 2))
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(L("\(exos.count) exercices · \(series) séries", "\(exos.count) exercises · \(series) sets"))
                        .font(.system(size: 16, weight: .semibold))
                    Text(exos.map(\.nomLocalise).joined(separator: ", "))
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(.white))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(VerreV7(rayon: 22))
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Le fond : du noir, une braise, ses braises

struct FondV7: View {
    var fige: Bool
    /// LA VIDÉO DU GALET (04-10, « anime la vidéo glass, attention aux
    /// animations et à la chauffe au global ») : seulement sur la page VIDE
    /// — on y reste peu —, le fichier même de « Let's go » (mesuré sur son
    /// téléphone le 13-09, en `screen`, sans masque). Les pages de séance
    /// gardent le poster immobile. Barreau : `-sansGaletVideo`.
    var video: Bool = false
    /// Barreau : sans le galet en filigrane.
    static let sansGalet = CommandLine.arguments.contains("-sansGaletFond")
    static let sansVideo = CommandLine.arguments.contains("-sansGaletVideo")
    var body: some View {
        GeometryReader { g in
            ZStack {
                Color.black
                // LE GALET NOIR DE LA MAISON, en filigrane (04-10, « la pilule
                // noire discrète en fond ») : en `screen`, fondu vers le bas.
                if !Self.sansGalet {
                    let h = g.size.width * 1.42 * 1560 / 1206
                    let l = h * 1206 / 1560
                    Group {
                        if video, !Self.sansVideo, !fige {
                            NosfyReel(nom: "duo-galet-noir", boucle: true, muet: true)
                        } else {
                            Image("duo-galet-noir-poster").resizable().aspectRatio(contentMode: .fit)
                        }
                    }
                        .frame(width: l, height: h)
                        .position(x: g.size.width * 0.5 + l * 0.37, y: g.size.height * 0.62)
                        .blendMode(.screen)
                        .opacity(0.34)
                        .mask(LinearGradient(stops: [.init(color: .black, location: 0.55), .init(color: .clear, location: 0.92)],
                                             startPoint: .top, endPoint: .bottom))
                }
                // La braise, en bas à gauche (celle d'avant).
                RadialGradient(colors: [Color(red: 0.75, green: 0.24, blue: 0.08).opacity(0.36), .clear],
                               center: .init(x: 0.3, y: 1.08), startRadius: 0, endRadius: 380)
                // La lampe de l'île, en haut (celle de « Let's go »).
                EllipticalGradient(stops: [.init(color: .white.opacity(0.22), location: 0),
                                           .init(color: .white.opacity(0.05), location: 0.42),
                                           .init(color: .clear, location: 0.76)],
                                   center: .top, startRadiusFraction: 0, endRadiusFraction: 0.5)
                    .frame(width: g.size.width * 0.92, height: 516)
                    .position(x: g.size.width / 2, y: 258)
                if !SeanceV7.sansBraises {
                    // ⚠️ GELÉES HORS POSE, comme celles du lecteur : plein écran,
                    // c'est la plus chère de la page.
                    BraisesVague(force: 0.62, fige: fige, hz: 15)
                        .allowsHitTesting(false)
                }
            }
        }
        .ignoresSafeArea()
    }
}

/// Ce qui se découvre sous le cadran tiré vers le bas (04-10) : le fond de la
/// séance, figé (aucune braise ne bat sous un doigt).
struct FondSeanceSousCadran: View {
    var body: some View { FondV7(fige: true) }
}

/// Son galet de verre, qui flotte (la vidéo de la Route, sans masque).
private struct GaletVerreV7: View {
    @State private var flotte = false
    var body: some View {
        VideoBoucle(nom: "duo-galet-noir")
            .allowsHitTesting(false)
            .offset(y: flotte ? -7 : 5)
            .animation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true), value: flotte)
            .onAppear { flotte = true }
    }
}

// MARK: - L'en-tête : l'état qui s'anime, le jour et le chrono, ses pièces, son carré du jour

private struct EnteteV7: View {
    let seance: Workout
    let titre: String
    /// En séance, le mot est chaud : un blanc tiré vers la braise (celui du
    /// lecteur), jamais un orange.
    let chaud: Bool
    let pose: Bool

    private static let jourFR: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "fr_FR"); f.dateFormat = "EEEE d"; return f
    }()
    private static let jourEN: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US"); f.dateFormat = "EEEE d"; return f
    }()
    private var jour: String {
        let s = (Langue.en ? Self.jourEN : Self.jourFR).string(from: seance.startedAt ?? .now)
        return s.prefix(1).uppercased() + s.dropFirst()
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 7) {
                // SON titre qui s'anime (`InviteAnimee`, la tête du lecteur) :
                // il se tait sous le doigt et hors pose.
                InviteAnimee(taille: 34, poids: .bold, texte: titre,
                             teinte: chaud ? Color(red: 1.0, green: 0.88, blue: 0.78) : .white,
                             fige: !pose)
                HStack(spacing: 8) {
                    HStack(spacing: 0) {
                        Text(jour + " · ")
                        Text(timerInterval: (seance.startedAt ?? .now)...Date.distantFuture, countsDown: false)
                            .monospacedDigit()
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    Bourse(pieces: CoffreFortPurse.coins(doneSeries: seance.seriesPayantes))
                }
            }
            .layoutPriority(1)
            Spacer(minLength: 0)
            ZStack(alignment: .topLeading) {
                MiniCardJour(date: seance.startedAt ?? .now,
                             sticker: WoopSticker.pour(seance).asset,
                             largeur: 64, hauteur: 72, flotte: true)
                    // SON halo : la couronne qui respire derrière la carte.
                    .background { HaloCarte(cote: 72).allowsHitTesting(false) }
                if seance.seriesPayantes > 0 {
                    TicketSeries(texte: TicketSeries.sets(seance.seriesPayantes), echelle: 0.62)
                        .rotationEffect(.degrees(-5))
                        .offset(x: 30, y: 44)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .frame(width: 104, height: 96, alignment: .topLeading)
        }
        // SA chaleur de séance, derrière la tête — posée seulement, comme
        // dans le lecteur (rien ne vit caché, rien n'anime sous le doigt).
        .background {
            if pose, !ChaleurTete.sans {
                ChaleurTete()
                    .padding(-34)
                    .allowsHitTesting(false)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: seance.seriesPayantes)
    }
}

/// Ses pièces : la mini pièce d'or et le compte qui roule.
struct Bourse: View {
    let pieces: Int
    var body: some View {
        HStack(spacing: 5) {
            Image("piece-or-mini").resizable().scaledToFit().frame(width: 20, height: 20)
            Text("\(pieces)")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(pieces)))
        }
        .padding(.leading, 4).padding(.trailing, 10).frame(height: 28)
        .background(VerreV7(rayon: 14))
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: pieces)
    }
}

/// LA LUMIÈRE DU VERRE DE LA V7 : un dégradé blanc très bas, un reflet en
/// haut à gauche, un liseré qui prend la lumière. Aucun flou. Le vrai verre
/// (`glassEffect(.clear)`) ne se pose que sous la tête des cartes.
struct VerreV7: View {
    var rayon: CGFloat = 22
    var body: some View {
        let forme = RoundedRectangle(cornerRadius: rayon, style: .continuous)
        ZStack {
            forme.fill(LinearGradient(colors: [.white.opacity(0.16), .white.opacity(0.05),
                                               .white.opacity(0.03), .white.opacity(0.09)],
                                      startPoint: .topLeading, endPoint: .bottomTrailing))
            forme.fill(RadialGradient(colors: [.white.opacity(0.16), .clear],
                                      center: .init(x: 0.16, y: 0), startRadius: 0, endRadius: 170))
            forme.strokeBorder(LinearGradient(colors: [.white.opacity(0.46), .white.opacity(0.08),
                                                       .white.opacity(0.16)],
                                              startPoint: .topLeading, endPoint: .bottomTrailing),
                               lineWidth: 1)
        }
    }
}

// MARK: - La grosse carte d'un exercice, en verre

private struct CarteExoV7: View {
    let exo: Exercise
    let rangs: [RangV7]
    let numero: Int
    let prochaine: Int?
    /// Les séries qui viennent de tomber, dans l'ordre : elles prennent feu
    /// l'une après l'autre.
    let neuves: [String]
    var onFiche: () -> Void
    var onToucher: (RangV7) -> Void
    var onMontree: (RangV7) -> Void
    var onSupprimer: (RangV7) -> Void
    var onAjouterSerie: () -> Void
    var onRetirer: () -> Void

    @State private var ouvert = false
    @State private var dx: CGFloat = 0
    /// Plié ou déplié À SA MAIN ; `nil` : la règle de la page.
    @State private var plie: Bool?
    private static let cote: CGFloat = 70
    private static let rayon: CGFloat = 20

    /// DÉPLIER, REPLIER (01-10, « les cards trop grosses », « on peut pas
    /// déplier et replier ») : seule la carte de l'exercice EN COURS est
    /// dépliée d'elle-même (sa suivante y porte son ▶), et celle dont les
    /// flammes prennent feu le temps de les voir. Les autres tiennent en une
    /// ligne. Son chevron décide ensuite, autant de fois qu'elle veut. Le
    /// cardio n'a qu'une ligne : il ne se plie pas.
    private var depliee: Bool {
        guard exo.tracking == .setsRepsWeight else { return true }
        if let plie { return !plie }
        return prochaine != nil || !neuves.isEmpty
    }

    private func basculer() {
        Haptique.leger()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.9)) { plie = depliee }
    }

    var body: some View {
        // Les actions du glissement (déplacer, supprimer) vivent DERRIÈRE la
        // carte et ne lui donnent plus leur hauteur : une carte pliée (98 pt)
        // en prenait 118 — le trou sous elle (01-10).
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                tete
                if depliee {
                    rangees
                } else {
                    resume
                        .transition(.opacity)
                }
            }
            // La carte bouge D'UN BLOC quand elle se plie : ses lignes ne
            // glissent plus chacune de leur côté.
            .geometryGroup()
            // UNE SEULE PLAQUE DE VERRE, comme la maquette (`.lg`) : la tête
            // est posée sur le verre, les séries sont des bandes sombres
            // dedans. (La tête en verre À PART faisait un bloc gris collé sur
            // la carte — refusé le 30-09.) Barreau : `-sansVerreV7`.
            // ⚠️ À MESURER sur l'iPhone : les braises bougent dessous, le
            // verre ne peut rien mettre en cache.
            .background {
                ZStack {
                    if !SeanceV7.sansVerre {
                        Color.clear
                            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: Self.rayon,
                                                                      style: .continuous))
                    }
                    VerreV7(rayon: Self.rayon)
                }
                .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: Self.rayon, style: .continuous))
            .shadow(color: .black.opacity(0.45), radius: 16, y: 8)
            .offset(x: (ouvert ? -Self.cote : 0) + dx)
        }
        .background(alignment: .topTrailing) { actions }
        .task {
            guard SeanceV7.banc == "cote", numero == 1 else { return }
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation(.spring(response: 0.48, dampingFraction: 0.78)) { ouvert = true }
        }
    }

    private var tete: some View {
        HStack(spacing: 13) {
            ExercisePhoto(exercise: exo)
                .frame(width: 36, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1))
            // Moins de texte (01-10) : le nom seul, le muscle est dans la fiche.
            Text(exo.nomLocalise)
                .font(.system(size: 15.5, weight: .semibold))
                .lineLimit(1)
            Spacer(minLength: 4)
            // (Plus de flammes ici : les séries les portent déjà — deux fois,
            // c'était chargé.) Le chevron PLIE et DÉPLIE ; le reste de la
            // tête ouvre la fiche.
            if exo.tracking == .setsRepsWeight {
                Button(action: basculer) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .rotationEffect(.degrees(depliee ? 180 : 0))
                        .frame(width: 40, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(depliee ? L("Replier", "Collapse") : L("Déplier", "Expand"))
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .foregroundStyle(.white)
        .padding(.vertical, 7)
        .padding(.leading, 10)
        .padding(.trailing, 8)
        .contentShape(Rectangle())
        .simultaneousGesture(glisserCote)
        .onTapGesture {
            if ouvert { withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { ouvert = false }; return }
            onFiche()
        }
    }

    /// Les séries, toutes visibles (01-10 : repliées, « j'arrive plus à
    /// savoir les séries »), et « Ajouter une série ».
    @ViewBuilder private var rangees: some View {
        ForEach(rangs) { r in
            RangeeV7(exo: exo, r: r, prochaine: prochaine == r.rang && !r.fait,
                     allumage: neuves.firstIndex(of: r.id),
                     onToucher: { onToucher(r) },
                     onMontree: { onMontree(r) },
                     onSupprimer: { onSupprimer(r) })
                .transition(.opacity)
        }
        if exo.tracking == .setsRepsWeight {
            Button(action: onAjouterSerie) {
                HStack(spacing: 13) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 26, height: 26)
                    Text(L("Ajouter une série", "Add a set"))
                        .font(.system(size: 14, weight: .medium))
                    Spacer()
                }
                .foregroundStyle(.white.opacity(0.42))
                .padding(.horizontal, 14).frame(height: 42)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    /// La carte pliée : ses flammes, ce qu'elle a donné (ou ce qui est
    /// prévu) — une ligne. La toucher la déplie.
    private var resume: some View {
        let faits = rangs.filter(\.fait)
        let valeur: String = {
            guard let l = (faits.last ?? rangs.last)?.ligne,
                  case .serie(let reps, let kilos) = l.genre else { return "" }
            return " · " + exo.saisie.serie(reps: reps, kilos: kilos,
                                            secondes: l.done ? l.seconds : 0)
        }()
        let reste = rangs.count - faits.count
        return Button(action: basculer) {
            HStack(spacing: 12) {
                if !faits.isEmpty {
                    FlammesRow(done: faits.count, total: faits.count, t: 0, date: .now,
                               igniteAt: nil, corps: 13, ceremonie: false)
                }
                // Moins de mots : les flammes disent le nombre.
                // « 1 série », jamais « 1 séries » (vu au « Refaire » d'une
                // séance d'une série par exercice, 03-10).
                Text((faits.isEmpty ? nombreDeSeries(rangs.count) : String(valeur.dropFirst(3)))
                     + (reste > 0 && !faits.isEmpty ? L(" · \(reste) à faire", " · \(reste) to go") : ""))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.66))
                    .lineLimit(1)
                Spacer(minLength: 6)
            }
            .padding(.leading, 14).padding(.trailing, 18)
            .frame(height: 42)
            .background(Color(white: 0.055).opacity(0.94))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var glisserCote: some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { v in
                guard abs(v.translation.width) > abs(v.translation.height) else { return }
                dx = min(Self.cote, max(-Self.cote * 1.4, v.translation.width))
            }
            .onEnded { v in
                withAnimation(.spring(response: 0.48, dampingFraction: 0.78)) {
                    if abs(v.translation.width) > abs(v.translation.height) {
                        ouvert = (ouvert ? -Self.cote : 0) + v.translation.width < -Self.cote / 2
                    }
                    dx = 0
                }
            }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            MedaillonStop(symbol: "arrow.up.arrow.down", taille: 46) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { ouvert = false }
            }
            MedaillonStop(symbol: "trash", neon: true, taille: 46) {
                Haptique.leger()
                onRetirer()
            }
        }
        .padding(.top, 14).padding(.trailing, 6)
        .opacity(ouvert || dx < -8 ? 1 : 0)
        .scaleEffect(ouvert || dx < -8 ? 1 : 0.7)
        .animation(.spring(response: 0.45, dampingFraction: 0.7), value: ouvert)
    }
}

// MARK: - Une rangée : SA ligne de série, sa flamme qui prend feu, glisser pour supprimer

private struct RangeeV7: View {
    let exo: Exercise
    let r: RangV7
    let prochaine: Bool
    /// Le rang de la série parmi celles qui viennent de tomber : elle prend
    /// feu à son tour. `nil` = déjà montrée.
    let allumage: Int?
    var onToucher: () -> Void
    var onMontree: () -> Void
    var onSupprimer: () -> Void

    @State private var ouvert = false
    @State private var dx: CGFloat = 0
    /// 0 = l'anneau vide ; 1 = la flamme posée.
    @State private var prise: Double
    private static let rouge: CGFloat = 92

    init(exo: Exercise, r: RangV7, prochaine: Bool, allumage: Int?,
         onToucher: @escaping () -> Void, onMontree: @escaping () -> Void,
         onSupprimer: @escaping () -> Void) {
        self.exo = exo
        self.r = r
        self.prochaine = prochaine
        self.allumage = allumage
        self.onToucher = onToucher
        self.onMontree = onMontree
        self.onSupprimer = onSupprimer
        _prise = State(initialValue: r.fait && allumage == nil ? 1 : 0)
    }

    /// Un cardio couru ne se supprime pas ligne à ligne : c'est l'exercice
    /// qui se retire (la corbeille de la carte).
    private var supprimable: Bool { r.set != nil || (!r.fait && exo.tracking == .setsRepsWeight) }

    var body: some View {
        ZStack(alignment: .trailing) {
            if supprimable {
                Button(action: onSupprimer) {
                    Text(L("Supprimer", "Delete"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: Self.rouge)
                        .frame(maxHeight: .infinity)
                        .background(Color(red: 1, green: 0.27, blue: 0.23))
                }
                .buttonStyle(.plain)
                .opacity(ouvert || dx < -4 ? 1 : 0)
            }
            ligne
                .offset(x: (ouvert ? -Self.rouge : 0) + dx)
        }
        .frame(height: 42)
        .clipped()
        .task(id: r.id) { await prendreFeu() }
        .task {
            guard SeanceV7.banc == "glisse", r.rang == 1, exo.id == "woop-haute" else { return }
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { ouvert = true }
        }
    }

    /// LA FLAMME PREND FEU — une fois, à l'arrivée sur la page, quand la
    /// coupe s'est levée. L'haptique tombe avec la naissance de la flamme.
    private func prendreFeu() async {
        guard r.fait, let i = allumage, prise < 1 else { return }
        onMontree()
        try? await Task.sleep(for: .seconds(0.75 + 0.34 * Double(i)))
        guard !Task.isCancelled else { prise = 1; return }
        withAnimation(.linear(duration: FlammeQuiPrend.duree)) { prise = 1 }
        try? await Task.sleep(for: .seconds(FlammeQuiPrend.duree * FlammeQuiPrend.naissance))
        Haptique.moyen()
    }

    /// LA LIGNE DE LA MAQUETTE V7 (verdict Kathryn 30-09 : « c'est dégueu »
    /// sur `SetHistoryRow` posée dans la carte — « Set 1 · 10 reps | 20 kg |
    /// 0 s · +20 » et sa pièce, cinq choses par ligne). La v7 n'en dit que
    /// deux : la VALEUR, et « série 1 » à droite. Une bande sombre, un filet
    /// d'un point au-dessus, la suivante un ton plus claire.
    private var ligne: some View {
        HStack(spacing: 13) {
            sticker
                .frame(width: 26, height: 26)
            Text(valeur)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(r.fait || prochaine ? 1 : 0.36))
                .lineLimit(1)
            Spacer(minLength: 8)
            // Moins de mots : la série à venir dit déjà son numéro ; « série N »
            // ne reste qu'au cardio (« tour N »).
            Text(exo.tracking != .setsRepsWeight ? etiquette : "")
                .font(.system(size: 13.5))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(prochaine ? 0.72 : 0.42))
        }
        .padding(.leading, 14)
        .padding(.trailing, 16)
        .frame(maxHeight: .infinity)
        .background(prochaine ? Color(white: 0.15).opacity(0.94) : Color(white: 0.055).opacity(0.94))
        .overlay(alignment: .top) {
            Rectangle().fill(.white.opacity(0.045)).frame(height: 1).padding(.leading, 53)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if ouvert { withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { ouvert = false }; return }
            onToucher()
        }
        .simultaneousGesture(glisser, isEnabled: supprimable)
    }

    /// Ce que la série vaut — « 10 reps · 20 kg », « 0:45 » au gainage ; au
    /// cardio, l'intervalle couru. Jamais un « 0 s » : le temps ne se dit
    /// que là où il EST la mesure.
    private var valeur: String {
        // ON NE CONNAÎT PAS À L'AVANCE LES REPS NI LE POIDS (02-10, Kathryn) :
        // une série à venir dit son numéro, rien d'autre. Ses valeurs
        // naîtront dans la note, après le Stop.
        if !r.fait, exo.tracking == .setsRepsWeight {
            return L("Série \(r.rang + 1)", "Set \(r.rang + 1)")
        }
        guard let l = r.ligne else {
            return exo.tracking == .intervals ? L("Intervalles", "Intervals")
                                              : L("Allure continue", "Steady pace")
        }
        let t = String(format: "%d:%02d", l.seconds / 60, l.seconds % 60)
        switch l.genre {
        case .serie(let reps, let kilos):
            return exo.saisie.serie(reps: reps, kilos: kilos, secondes: l.done ? l.seconds : 0)
        case .intervalle(let v, let niveau), .course(let v, let niveau):
            let allure = niveau ? L("niveau \(Int(v))", "level \(Int(v))")
                                : "\(Exercise.Saisie.kg(v)) km/h"
            return "\(t) · \(allure)"
        case .longueurs(let n, let metres):
            return L("\(n) longueurs · \(metres) m", "\(n) lengths · \(metres) m")
        }
    }

    private var etiquette: String {
        guard exo.tracking == .setsRepsWeight else {
            return r.ligne == nil ? "cardio" : L("tour \(r.rang + 1)", "round \(r.rang + 1)")
        }
        return L("série \(r.rang + 1)", "set \(r.rang + 1)")
    }

    @ViewBuilder private var sticker: some View {
        if r.fait {
            FlammeQuiPrend(p: prise)
        } else if prochaine {
            Image(systemName: "play.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 26, height: 26)
                .background(Circle().fill(.white))
        } else {
            Circle()
                .strokeBorder(.white.opacity(0.24), lineWidth: 1.6)
                .frame(width: 26, height: 26)
        }
    }

    private var glisser: some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { v in
                guard abs(v.translation.width) > abs(v.translation.height) else { return }
                dx = min(Self.rouge * 0.4, max(-Self.rouge * 1.3, v.translation.width))
            }
            .onEnded { v in
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                    if abs(v.translation.width) > abs(v.translation.height) {
                        ouvert = (ouvert ? -Self.rouge : 0) + v.translation.width < -Self.rouge / 2
                    }
                    dx = 0
                }
            }
    }
}

// MARK: - LA FLAMME QUI PREND FEU (30-09, choix validé : « elle prend feu » + braises)
//
// Au lieu d'un sticker qui tombe du ciel (« ça fait cheap ») : l'anneau vide
// de la série PREND FEU. Un fil orange d'un point en fait le tour, la flamme
// naît dedans par le pied et se pose, SA cérémonie (`CeremonieFlamme` :
// l'onde et les six diamants) passe dessus, et cinq braises s'en échappent.
//
// ⚠️ UNE SEULE VALEUR ANIMÉE (`p`, 0 → 1 en 1,3 s) : le corps n'est relu que
// pendant l'allumage, puis la flamme repose — aucune horloge ne reste.
// Loi de la maison : la brillance vient de la blancheur, jamais de
// l'épaisseur — fil de 1 pt, blooms ≤ 5 px, aucune couleur hors braise.

struct FlammeQuiPrend: View, Animatable {
    var p: Double
    var animatableData: Double {
        get { p }
        set { p = newValue }
    }

    static let duree: Double = 1.3
    /// L'instant (en fraction) où la flamme naît dans l'anneau.
    static let naissance: Double = 0.31

    private static let braise = Color(red: 1.0, green: 0.42, blue: 0.13)
    private static let derives: [CGFloat] = [-0.8, 0.5, -0.2, 1.0, -1.1]

    private static func retour(_ q: Double) -> Double {
        // easeOutBack : elle dépasse sa taille et se pose.
        let c1 = 1.70158, c3 = c1 + 1
        return 1 + c3 * pow(q - 1, 3) + c1 * pow(q - 1, 2)
    }

    var body: some View {
        let s = p * Self.duree
        let trace = min(1, s / 0.42)
        let tour = 1 - pow(1 - trace, 2.2)
        let q = min(1, max(0, (s - Self.naissance * Self.duree) / 0.36))
        let naissance = p >= 1 ? 1 : Self.retour(q)
        let e = s - Self.naissance * Self.duree
        ZStack {
            if p < 1 {
                // L'anneau vide qui s'éteint quand la flamme arrive.
                Circle()
                    .strokeBorder(.white.opacity(0.24 * (1 - min(1, q * 1.6))), lineWidth: 1.6)
                    .frame(width: 26, height: 26)
                // Le fil de feu : il fait le tour, puis se retire dans la flamme.
                Circle()
                    .trim(from: 0, to: tour)
                    .stroke(Self.braise, style: StrokeStyle(lineWidth: 1, lineCap: .round))
                    .rotationEffect(.degrees(90))
                    .frame(width: 24, height: 24)
                    .shadow(color: Self.braise.opacity(0.8), radius: 2.5)
                    .opacity(1 - min(1, max(0, (s - 0.5) / 0.35)))
                // Les braises qui s'échappent.
                ForEach(0..<5, id: \.self) { k in
                    let s0 = 0.45 + 0.07 * Double(k)
                    let u = (s - s0) / 0.75
                    if u > 0, u < 1 {
                        Circle()
                            .fill(k % 2 == 0 ? Self.braise : Color(red: 1.0, green: 0.78, blue: 0.55))
                            .frame(width: 1.8 - 1.0 * u, height: 1.8 - 1.0 * u)
                            .shadow(color: Self.braise.opacity(0.9), radius: 2)
                            .offset(x: Self.derives[k] * 6 * u + CGFloat(k - 2) * 2,
                                    y: -6 - 16 * u)
                            .opacity(u < 0.2 ? u / 0.2 : 1 - (u - 0.2) / 0.8)
                    }
                }
            }
            if q > 0 {
                // ⚠️ PETITE (verdict 30-09 : « flamme trop grosse ») : 15 × 19,
                // elle tient DANS l'anneau de 26 au lieu de le déborder.
                Image("sticker-flamme-serree")
                    .resizable().scaledToFit()
                    .frame(width: 15, height: 19)
                    .shadow(color: .orange.opacity(0.45), radius: 3.5)
                    .scaleEffect(max(0.01, naissance), anchor: .bottom)
                    .opacity(min(1, q * 3))
            }
            if e >= 0, e < 0.8, p < 1 {
                CeremonieFlamme(e: e)
            }
        }
        .frame(width: 26, height: 26)
        .allowsHitTesting(false)
    }
}

// MARK: - LA FEUILLE AJOUTER — celle de la v7 : en verre, qui flotte

private struct FeuilleAjoutV7: View {
    let historique: [String: PropositionExo]
    let hauteur: CGFloat
    var onAnnuler: () -> Void
    var onAjouter: ([Exercise]) -> Void

    /// EN DEUX TEMPS (04-10, « dans Ajouter on a la page puis l'overlay, mais
    /// on choisit une catégorie ») : d'abord SES zones en grands carrés,
    /// puis les exercices de la zone touchée. `nil` = les zones. La recherche
    /// saute l'étape : elle liste tout de suite.
    @State private var zone: ExerciseCategory?
    @State private var choisis: [Exercise] = []
    @State private var recherche = ""
    @State private var tire: CGFloat = 0

    private var exos: [Exercise] {
        let q = recherche.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty { return ExerciseCatalog.all.filter { $0.nomLocalise.lowercased().contains(q) } }
        guard let zone else { return [] }
        return ExerciseCatalog.exercises(in: zone)
    }
    private var surLesZones: Bool { zone == nil && recherche.isEmpty }

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 12) {
                Capsule().fill(.white.opacity(0.34)).frame(width: 40, height: 5)
                barre
            }
            .padding(.top, 8)
            .contentShape(Rectangle())
            .gesture(glisser)
            champ
            ZStack(alignment: .top) {
                if surLesZones {
                    zones
                        .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity),
                                                removal: .offset(x: -110).combined(with: .opacity)))
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(exos.enumerated()), id: \.element.id) { i, e in
                                ligne(e)
                                if i < exos.count - 1 {
                                    Rectangle().fill(.white.opacity(0.09)).frame(height: 1).padding(.leading, 72)
                                }
                            }
                        }
                        .background(VerreV7(rayon: 26))
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .id(zone)
                        .padding(.bottom, 24)
                    }
                    .scrollIndicators(.hidden)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .trailing).combined(with: .opacity)))
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.86), value: surLesZones)
        }
        .padding(.horizontal, 14)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(fond)
        .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 44, style: .continuous)
            .strokeBorder(LinearGradient(colors: [.white.opacity(0.32), .white.opacity(0.06), .white.opacity(0.12)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
        .padding(.horizontal, 8)
        .padding(.top, hauteur * 0.09)
        .padding(.bottom, 8)
        .offset(y: tire)
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: recherche.isEmpty)
    }

    /// Le verre de la feuille : un flou sombre, une lumière en haut à gauche.
    private var fond: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            LinearGradient(colors: [Color(white: 0.24).opacity(0.6), Color(white: 0.08).opacity(0.86)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [.white.opacity(0.12), .clear], center: .init(x: 0.15, y: 0),
                           startRadius: 0, endRadius: 260)
        }
        .environment(\.colorScheme, .dark)
    }

    /// Le mot court de la zone, celui des petits carrés de la page Exercices
    /// (le sien y est `fileprivate`).
    private static func nom(_ z: ExerciseCategory) -> String {
        switch z {
        case .haut: return L("Haut", "Upper")
        case .abdos: return L("Abdos", "Core")
        case .bas: return L("Bas", "Legs")
        case .fessiers: return L("Fessiers", "Glutes")
        case .cardio: return "Cardio"
        }
    }

    /// Les cinq zones, en grands carrés sur trois colonnes.
    private var zones: some View {
        let cols = [GridItem(.fixed(108), spacing: 12), GridItem(.fixed(108), spacing: 12), GridItem(.fixed(108), spacing: 12)]
        return LazyVGrid(columns: cols, alignment: .leading, spacing: 12) {
            ForEach(ExerciseCategory.allCases) { z in
                CarreZoneMini(zone: z, choisie: false)
                    .frame(width: 108, height: 122)
                    .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .onTapGesture {
                        Haptique.moyen()
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) { zone = z }
                    }
            }
        }
        .padding(.top, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var barre: some View {
        HStack {
            if let zone, recherche.isEmpty {
                Button {
                    Haptique.leger()
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) { self.zone = nil }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                        Text(Self.nom(zone))
                    }
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            } else {
                Button(L("Annuler", "Cancel")) { onAnnuler() }
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
            }
            Spacer()
            Text(L("Ajouter", "Add")).font(.system(size: 17, weight: .semibold))
            Spacer()
            Button { onAjouter(choisis) } label: {
                Text(choisis.isEmpty ? L("Ajouter", "Add") : L("Ajouter (\(choisis.count))", "Add (\(choisis.count))"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black.opacity(choisis.isEmpty ? 0.35 : 1))
                    .padding(.horizontal, 15).frame(height: 34)
                    .background(Capsule().fill(LinearGradient(colors: [.white, Color(white: 0.9)],
                                                              startPoint: .top, endPoint: .bottom)))
                    .contentTransition(.numericText())
            }
            .buttonStyle(.plain)
            .disabled(choisis.isEmpty)
        }
    }

    private var champ: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.white.opacity(0.6))
            TextField("", text: $recherche, prompt: Text(L("Rechercher", "Search")).foregroundStyle(.white.opacity(0.55)))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(.white)
        }
        .font(.system(size: 17))
        .padding(.horizontal, 14).frame(height: 40)
        .background(VerreV7(rayon: 20))
    }

    private func sous(_ e: Exercise) -> String {
        if let h = historique[e.id], let r = h.reps {
            switch e.saisie {
            case .repsEtCharge:
                if let k = h.kilos {
                    let kg = k.rounded() == k ? "\(Int(k))" : String(format: "%.1f", k).replacingOccurrences(of: ".", with: ",")
                    return L("Dernière fois \(r) reps · \(kg) kg", "Last time \(r) reps · \(kg) kg")
                }
            case .repsSeules: return L("Dernière fois \(r) reps", "Last time \(r) reps")
            case .tempsSeul: break
            }
        }
        return e.muscle
    }

    private func ligne(_ e: Exercise) -> some View {
        let pris = choisis.contains(e)
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                if pris { choisis.removeAll { $0 == e } } else { choisis.append(e) }
            }
        } label: {
            HStack(spacing: 13) {
                ExercisePhoto(exercise: e)
                    .frame(width: 46, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(e.nomLocalise).font(.system(size: 16, weight: .semibold)).lineLimit(1)
                    Text(sous(e)).font(.system(size: 13)).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
                }
                Spacer()
                ZStack {
                    Circle().strokeBorder(.white.opacity(0.32), lineWidth: 1.6)
                    if pris {
                        Circle().fill(.white).shadow(color: .white.opacity(0.4), radius: 5)
                        Image(systemName: "checkmark").font(.system(size: 13, weight: .heavy)).foregroundStyle(.black)
                    }
                }
                .frame(width: 28, height: 28)
                .scaleEffect(pris ? 1.1 : 1)
            }
            .padding(.horizontal, 12)
            .frame(height: 70)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var glisser: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { v in tire = max(0, v.translation.height) }
            .onEnded { v in
                if v.translation.height > 110 || v.predictedEndTranslation.height > 240 {
                    onAnnuler()
                }
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { tire = 0 }
            }
    }
}
