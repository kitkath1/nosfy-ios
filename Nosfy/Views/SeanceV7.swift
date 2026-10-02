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

    @Environment(\.modelContext) private var context
    @Query(sort: \Workout.startedAt, order: .reverse) private var seances: [Workout]
    /// Le départ de série du COMPTE (Réglages) : galet ou slider.
    @AppStorage(DepartSerie.cle) private var departBrut: String = DepartSerie.defaut.rawValue
    @State private var ajout = false
    @State private var tire: CGFloat = 0
    @State private var tirePris = false
    private var etat: SeanceV7Etat { .shared }

    private static let haut: CGFloat = 58
    /// (01-10, « le slider pas assez bas ») : la barre descend près du bord.
    private static let bas: CGFloat = 6

    /// La page est posée, immobile : ses horloges ont le droit de battre.
    private var pose: Bool { morph > 0.98 && tire < 0.5 && !ajout }
    private var departSlider: Bool { DepartSerie(rawValue: departBrut) != .galet }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                FondV7(fige: !pose)
                page
                    .scaleEffect(ajout ? 0.93 : 1, anchor: .top)
                    .offset(y: ajout ? 18 : 0)
                    .brightness(ajout ? -0.32 : 0)
                    .clipShape(RoundedRectangle(cornerRadius: ajout ? 40 : 0, style: .continuous))
                    .allowsHitTesting(!ajout)
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

    private var derniere: Workout? {
        seances.first { $0.endedAt != nil && !$0.orderedExercises.isEmpty
                        && $0.persistentModelID != seance.persistentModelID }
    }

    private var prochain: (exo: String, rang: Int)? { etat.prochain(dans: seance) }
    /// Tout le plan est fait.
    private var complete: Bool { !etat.plan.isEmpty && prochain == nil }

    /// CE QUE DIT LA TÊTE — l'état, jamais le sujet (sa règle du 24-09).
    private var titre: String {
        if complete { return L("Tout est fait", "All done") }
        return seance.seriesPayantes == 0 ? L("Séance", "Session") : L("En cours", "In progress")
    }

    // MARK: la page

    private var page: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 0) {
                    EnteteV7(seance: seance, titre: titre,
                             chaud: seance.seriesPayantes > 0, pose: pose)
                        .padding(.top, Self.haut + 58)
                    if etat.plan.isEmpty {
                        vide
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(etat.plan.enumerated()), id: \.element.id) { i, p in
                                carte(p, numero: i + 1)
                            }
                        }
                        .padding(.top, 22)
                    }
                    Color.clear.frame(height: 150)
                }
                .padding(.horizontal, 16)
            }
            .scrollIndicators(.hidden)
            barreHaut
            if !etat.plan.isEmpty {
                VStack { Spacer(); barreBas }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.55, dampingFraction: 0.84), value: etat.plan.isEmpty)
    }

    /// ‹ à gauche, « Terminer » en verre à droite — la barre de la v7.
    private var barreHaut: some View {
        HStack {
            MedaillonStop(symbol: "chevron.left", taille: 40) { fermer() }
            Spacer()
            Button(action: onStop) {
                Text(L("Terminer", "Finish"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(peutTerminer ? 1 : 0.34))
                    .padding(.horizontal, 17)
                    .frame(height: 40)
                    .background(VerreV7(rayon: 20))
            }
            .buttonStyle(.plain)
            .disabled(!peutTerminer)
            .opacity(complete ? 0 : 1)
            .allowsHitTesting(!complete)
            .animation(.easeOut(duration: 0.3), value: complete)
        }
        .padding(.horizontal, 18)
        .padding(.top, Self.haut)
        .frame(maxWidth: .infinity)
        .frame(height: Self.haut + 64, alignment: .top)
        .background(
            LinearGradient(colors: [.black.opacity(0.9), .black.opacity(0)],
                           startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false))
        .contentShape(Rectangle())
        .gesture(glisserPourFermer)
    }
    private var peutTerminer: Bool { !etat.plan.isEmpty || seance.seriesPayantes > 0 }

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
                                       L("\(seance.setsAffiches) séries", "\(seance.setsAffiches) sets")),
                             onConfirm: onStop)
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
        guard let n = prochain, let e = ExerciseCatalog.exercise(id: n.exo) else { onStop(); return }
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

    private func ouvrirAjout() {
        Haptique.leger()
        withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) { ajout = true }
    }
    private func fermerAjout() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) { ajout = false }
    }

    // MARK: la grosse carte

    private func carte(_ p: SeanceV7Etat.Prevu, numero: Int) -> some View {
        let exo = ExerciseCatalog.exercise(id: p.id) ?? ExerciseCatalog.all[0]
        let n = prochain
        let rangs = etat.rangs(p, exo: exo, dans: seance)
        return CarteExoV7(
            exo: exo, rangs: rangs, numero: numero,
            prochaine: n?.exo == p.id ? n?.rang : nil,
            neuves: rangs.filter { etat.neuve($0) }.map(\.id),
            onFiche: { Haptique.leger(); partir(exo, lancer: false) },
            // Une ligne À FAIRE lance la série dans le lecteur ; une ligne
            // faite ne mène nulle part (elle ouvrait l'ancienne fiche — « quand
            // je reclique sur une ligne, ça va pas », 01-10).
            onToucher: { r in
                guard !r.fait else { Haptique.leger(); return }
                partir(exo, lancer: true)
            },
            onMontree: { r in etat.montree(r) },
            onSupprimer: { r in
                withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                    etat.supprimer(r, dans: seance, context: context)
                }
            },
            onAjouterSerie: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { etat.ajouterSerie(p.id) }
            },
            onRetirer: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) {
                    etat.retirer(p.id, dans: seance, context: context)
                }
            })
            .draggable(p.id)
            .dropDestination(for: String.self) { ids, _ in
                guard let id = ids.first else { return false }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.84)) {
                    etat.deplacer(id, avant: p.id)
                }
                return true
            }
    }

    // MARK: la séance vide — celle de la v7

    /// L'ÉTAT VIDE, SIMPLE (01-10, Kathryn : « l'empty plus simple », « j'aime bien suggérer celle
    /// de la semaine ») : une phrase, ta séance de la semaine à reprendre en un geste, puis
    /// « Ajouter un exercice ». Rien d'autre.
    private var vide: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L("Compose ta séance.", "Build your session."))
                .font(.system(size: 25, weight: .bold))
                .padding(.top, 34)
            if let w = derniere {
                HStack(alignment: .firstTextBaseline) {
                    Text(L("TA SÉANCE DE LA SEMAINE", "YOUR SESSION THIS WEEK"))
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.5))
                    Spacer()
                    Text(Self.resumeDate(w))
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.top, 26)
                SeanceDeLaSemaine(seance: w) {
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) { etat.reprendre(w) }
                }
                .padding(.top, 9)
            }
            Button { ouvrirAjout() } label: {
                Text(L("Ajouter un exercice", "Add an exercise"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, derniere == nil ? 22 : 12)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// « mardi · 52 min » — le jour de la dernière séance finie, et sa durée.
    private static func resumeDate(_ w: Workout) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: Langue.en ? "en_US" : "fr_FR"); f.dateFormat = "EEEE"
        let jour = f.string(from: w.startedAt)
        guard let e = w.endedAt else { return jour }
        return "\(jour) · \(max(1, Int(e.timeIntervalSince(w.startedAt) / 60))) min"
    }

    // MARK: le banc

    nonisolated(unsafe) static var bancJoue = false

    private func jouerLeBanc() async {
        guard let banc = SeanceV7.banc else { return }
        try? await Task.sleep(for: .seconds(0.8))
        if banc == "vide" { return }
        if banc == "ajout" { ouvrirAjout(); return }
        let exos = ["woop-haute", "crunch-sol", "gainage"].compactMap { ExerciseCatalog.exercise(id: $0) }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) { etat.ajouter(exos, historique: historique) }
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

private struct FondV7: View {
    var fige: Bool
    var body: some View {
        ZStack {
            Color.black
            RadialGradient(colors: [Color(red: 0.75, green: 0.24, blue: 0.08).opacity(0.36), .clear],
                           center: .init(x: 0.12, y: 1.02), startRadius: 0, endRadius: 380)
            RadialGradient(colors: [Color(red: 0.47, green: 0.12, blue: 0.04).opacity(0.3), .clear],
                           center: .init(x: 0.96, y: 0.7), startRadius: 0, endRadius: 320)
            RadialGradient(colors: [.white.opacity(0.07), .clear],
                           center: .init(x: 0.5, y: -0.05), startRadius: 0, endRadius: 320)
            if !SeanceV7.sansBraises {
                // ⚠️ GELÉES HORS POSE, comme celles du lecteur : plein écran,
                // c'est la plus chère de la page.
                BraisesVague(force: 0.62, fige: fige, hz: 15)
                    .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
    }
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
                Text((faits.isEmpty ? L("\(rangs.count) séries", "\(rangs.count) sets")
                                    : String(valeur.dropFirst(3)))
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

    @State private var zone: ExerciseCategory = .abdos
    @State private var choisis: [Exercise] = []
    @State private var recherche = ""
    @State private var tire: CGFloat = 0

    private var exos: [Exercise] {
        let q = recherche.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return ExerciseCatalog.exercises(in: zone) }
        return ExerciseCatalog.all.filter { $0.nomLocalise.lowercased().contains(q) }
    }

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
            if recherche.isEmpty {
                // SES carrés de zones, ceux du lecteur : ils respirent, chacun
                // à sa période, pour inviter à choisir.
                HStack(spacing: 10) {
                    ForEach(ExerciseCategory.allCases) { z in
                        CarreZoneMini(zone: z, choisie: z == zone)
                            .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                            .onTapGesture {
                                if zone == z { Haptique.leger() } else { Haptique.moyen() }
                                withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) { zone = z }
                            }
                    }
                }
                .padding(.horizontal, 2)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
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
                .transition(.opacity.combined(with: .offset(y: 10)))
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
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

    private var barre: some View {
        HStack {
            Button(L("Annuler", "Cancel")) { onAnnuler() }
                .font(.system(size: 16))
                .foregroundStyle(.white)
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
