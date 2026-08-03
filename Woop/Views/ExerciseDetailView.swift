import SwiftUI
import SwiftData

// MARK: - La fiche, qui est aussi l'éditeur

/// LA fiche d'un exercice — et son éditeur. Elle a absorbé l'ancienne feuille
/// modale `LogExerciseSheet` : il n'y a plus « consulter », puis « ouvrir pour
/// saisir ». Il y a un seul écran, où l'on règle et où l'on lance.
///
/// La page est NOIRE, et s'organise comme la référence : le chevron dans son
/// chip de verre sous une nappe de braise, le titre, la photo fondue dans sa
/// carte sombre, et en plancher la DALLE — carte blanche draggable dont le
/// bord bas s'échancre autour de la pastille de séance (l'incrustation vit
/// dans `NotchedCard.swift`, la dalle dans `ExerciseSetupCard.swift`).
///
/// Le banc : `-exoLab` ouvre cette fiche seule (+ `-activeWorkout` pour voir
/// la pastille et son échancrure).
struct ExerciseDetailView: View {
    let exercise: Exercise

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]

    @State private var confirmation: String?

    // Le brouillon. Il vivait dans la feuille modale ; c'est désormais l'état de
    // la page elle-même.
    @State private var sets: [DraftSet] = [DraftSet()]
    @State private var restSeconds = 60
    @State private var phases: [DraftPhase] = [
        DraftPhase(kind: .repos, seconds: 30, speed: 6),
        DraftPhase(kind: .acceleration, seconds: 30, speed: 16)
    ]
    @State private var repeatCount = 1
    @State private var steadySeconds = 900
    @State private var steadySpeed: Double = 7
    @State private var incline: Double = 0

    /// La pastille de série que les rangées de la dalle éditent.
    @State private var selectedSet = 0

    /// La série en cours d'exécution au compteur, s'il y en a une. Un `item:`
    /// plutôt qu'un booléen : c'est l'indice qui porte l'information, et il ne
    /// peut pas se désynchroniser.
    @State private var running: RunningSeries?

    private struct RunningSeries: Identifiable {
        let id: Int
    }

    private var active: Workout? { workouts.first { $0.isActive } }
    private var isStrength: Bool { exercise.tracking == .setsRepsWeight }

    /// La silhouette de la carte noire : coins hauts seulement — elle file
    /// bord à bord et jusqu'en bas d'écran, comme la référence.
    private static let pageShape = UnevenRoundedRectangle(
        cornerRadii: .init(topLeading: 40, bottomLeading: 0,
                           bottomTrailing: 0, topTrailing: 40),
        style: .continuous)

    var body: some View {
        GeometryReader { geo in
            // LA CARTE NOIRE : pleine largeur bord à bord, grands coins hauts
            // arrondis — c'est elle qui s'inscrit sur la braise, et c'est dans
            // ses deux coins que l'orange apparaît en négatif. Tout le contenu
            // vit dedans, et le scroll se coupe sur sa silhouette : jamais un
            // pixel de contenu ne remonte sur l'orange.
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        titleBlock

                        // 40 % de l'écran, pas un point de plus : la photo est
                        // une présence, plus le sujet de la page.
                        hero(height: geo.size.height * 0.40)

                        if let lastTime {
                            LastTimeBanner(text: lastTime)
                        }

                        // Le cardio garde ses blocs sombres : la dalle blanche
                        // est le système de la musculation — il rejoindra le
                        // reste quand le composant sera généralisé.
                        if !isStrength {
                            editor
                        }

                        if let confirmation {
                            Label(confirmation, systemImage: "checkmark.circle.fill")
                                .font(.inter(13, .medium))
                                .foregroundStyle(Color.woopGold)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        if active == nil {
                            Text("Aucune séance en cours — elle sera créée automatiquement.")
                                .font(.inter(12))
                                .foregroundStyle(Color.inkMuted)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 26)
                }
                .scrollIndicators(.hidden)
                .background(Self.pageShape.fill(Color.black))
                .clipShape(Self.pageShape)
            }
            // Le socle et la braise vivent en FOND, hors jeu de layout : la
            // carte-braise a déjà fait dérailler la largeur de la page une
            // fois — plus rien d'elle ne participe à la mise en page.
            .background {
                ZStack(alignment: .top) {
                    Color.black
                    HeaderEmberCard()
                }
                .ignoresSafeArea()
            }
            .safeAreaInset(edge: .top, spacing: 0) { headerChips }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if isStrength {
                    ExerciseSetupSlab(
                        exercise: exercise,
                        sets: $sets,
                        restSeconds: $restSeconds,
                        selected: $selectedSet,
                        canAdd: canAddSeries,
                        onAdd: {
                            withAnimation(.spring(response: 0.35,
                                                  dampingFraction: 0.75)) {
                                addSeries()
                                selectedSet = sets.count - 1
                            }
                        },
                        sliderLabel: launchTarget == nil
                            ? "Glisser pour enregistrer"
                            : "Glisser pour lancer l'entraînement",
                        onSlide: {
                            if let index = launchTarget {
                                running = RunningSeries(id: index)
                            } else {
                                save()
                            }
                        }
                    )
                } else {
                    primaryAction
                }
            }
        }
        // Le chevron du chip a remplacé la barre système : deux flèches de
        // retour seraient une de trop.
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        // L'appareil confirme la série en même temps que les paillettes partent.
        .sensoryFeedback(.success, trigger: sets.filter(\.isDone).count)
        .fullScreenCover(item: $running) { series in
            LiveExerciseView(exercise: exercise,
                             seriesNumber: series.id + 1,
                             target: target(for: series.id)) { seconds in
                complete(series.id, seconds: seconds)
            } onCancel: {
                running = nil
            }
        }
    }

    // MARK: En-tête

    /// Le chevron dans son carré de verre, et son double « … » en face —
    /// celui-ci s'ouvrira plus tard en carte (date, heure) : il a déjà sa
    /// place, il n'a pas encore son geste.
    private var headerChips: some View {
        HStack {
            headerChip("chevron.left", label: "Retour") { dismiss() }
            Spacer()
            headerChip("ellipsis", label: "Options") {}
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    private func headerChip(_ symbol: String, label: String,
                            action: @escaping () -> Void) -> some View {
        let shape = RoundedRectangle(cornerRadius: 15, style: .continuous)
        return Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.inkPrimary)
                .frame(width: 44, height: 44)
                .background {
                    // Verre fumé FONCÉ, comme le chip « Done » de la référence :
                    // un objet sombre posé sur la braise, qu'elle traverse à
                    // peine — le halo vient de la nappe, pas d'une ombre.
                    Color.clear
                        .glassEffect(.regular.tint(Color.black.opacity(0.5))
                            .interactive(), in: shape)
                }
                .overlay(shape.strokeBorder(Color.white.opacity(0.08),
                                            lineWidth: 1))
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// EXACTEMENT le titre de la home — même fonte, même graisse, même
    /// interlettrage négatif — et sur UNE ligne, toujours. Le sous-titre dit
    /// la zone travaillée, en retrait, comme la référence.
    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(exercise.name)
                .font(.inter(30, .semibold))
                .tracking(-0.3)
                .foregroundStyle(WoopGradient.titleFade)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
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
    private func hero(height: CGFloat) -> some View {
        ExercisePhoto(exercise: exercise, fills: false)
            .frame(height: height)
            .frame(maxWidth: .infinity)
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
                        incline: $incline, isStairs: exercise.id == "escalier")
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

    /// La série que le slider lancera : celle qu'on regarde si elle reste à
    /// faire, sinon la première en attente. `nil` : tout est fait, le slider
    /// enregistre.
    private var launchTarget: Int? {
        guard isStrength else { return nil }
        if sets.indices.contains(selectedSet), !sets[selectedSet].isDone {
            return selectedSet
        }
        return pendingSeries
    }

    /// La première série pas encore faite.
    private var pendingSeries: Int? {
        guard isStrength else { return nil }
        return sets.firstIndex { !$0.isDone }
    }

    /// On ne propose d'en ajouter une qu'une fois les précédentes faites :
    /// sinon la rangée offrirait deux gestes concurrents.
    private var canAddSeries: Bool {
        isStrength && pendingSeries == nil
    }

    private func addSeries() {
        sets.append(DraftSet(reps: sets.last?.reps ?? 12,
                             weight: sets.last?.weight ?? 20))
    }

    private func target(for index: Int) -> String {
        guard sets.indices.contains(index) else { return "" }
        let set = sets[index]
        return "\(set.reps) reps · \(set.weight.formatted(.number.precision(.fractionLength(0...1)))) kg"
    }

    private func complete(_ index: Int, seconds: Int) {
        running = nil
        // Le plein écran met un peu moins d'une demi-seconde à se refermer.
        // Valider tout de suite ferait jouer les paillettes derrière lui, donc
        // pour personne — on attend que le bloc soit à l'air libre.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            guard sets.indices.contains(index) else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) {
                sets[index].isDone = true
                sets[index].durationSeconds = seconds
                // Le regard avance tout seul : la pastille suivante à faire
                // devient celle qu'on règle.
                selectedSet = sets.firstIndex { !$0.isDone } ?? index
            }
        }
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
            let last = sets.last
            withAnimation(.easeOut(duration: 0.25)) {
                sets = [DraftSet(reps: last?.reps ?? 12, weight: last?.weight ?? 20)]
                selectedSet = 0
            }
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
