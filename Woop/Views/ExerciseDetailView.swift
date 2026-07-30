import SwiftUI
import SwiftData

// MARK: - La fiche, qui est aussi l'éditeur

/// LA fiche d'un exercice — et son éditeur. Elle a absorbé l'ancienne feuille
/// modale `LogExerciseSheet` : il n'y a plus « consulter », puis « ouvrir pour
/// saisir ». Il y a un seul écran, où l'on règle et où l'on lance. Un geste et
/// un écran de moins, pour la musculation comme pour le cardio.
///
/// La page est NOIRE, sans ciel : la photo occupe le haut et son fond doit se
/// perdre dans la page — une nébuleuse derrière elle redessinerait aussitôt son
/// rectangle. La tab bar s'efface pour la même raison de fond : la barre
/// d'action du bas est le seul plancher, et deux barres empilées ne feraient que
/// se disputer le geste.
struct ExerciseDetailView: View {
    let exercise: Exercise

    @Environment(\.modelContext) private var context
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

    /// La série en cours d'exécution au compteur, s'il y en a une. Un `item:`
    /// plutôt qu'un booléen : c'est l'indice qui porte l'information, et il ne
    /// peut pas se désynchroniser.
    @State private var running: RunningSeries?

    private struct RunningSeries: Identifiable {
        let id: Int
    }

    private var active: Workout? { workouts.first { $0.isActive } }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    hero
                    header

                    if let lastTime {
                        LastTimeBanner(text: lastTime)
                    }

                    editor

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
                .padding(.bottom, 26)
            }
        }
        // Le geste principal est ancré en bas d'écran, pas perdu dans un coin de
        // barre de navigation : c'est LE bouton de cette page.
        .safeAreaInset(edge: .bottom) { primaryAction }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
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

    /// La photo ENTIÈRE, sans cadre : ni liseré, ni angles arrondis, ni éclats
    /// semés sur le contour. Le fond de l'image est déjà le noir de la page —
    /// dès qu'on retire le sertissage, il n'y a plus une image dans une carte,
    /// il y a un corps qui flotte dans le noir. Le masque ne fait qu'éteindre
    /// les bords, là où une jambe ou un montant de machine viendrait buter net
    /// sur l'arête du cadre : c'est ce qui reste du rectangle, et c'est ce qu'on
    /// efface.
    ///
    /// 272 pt au lieu de 340 : la photo ne prend plus tout le haut de l'écran,
    /// et tout ce qui la suit remonte d'autant.
    private var hero: some View {
        ExercisePhoto(exercise: exercise, fills: false)
            .frame(height: 272)
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
            // Deux masques chaînés se multiplient : les quatre bords s'éteignent
            // sans avoir à composer un dégradé bidimensionnel.
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

    /// EXACTEMENT le titre de la home — même fonte, même graisse, même
    /// interlettrage négatif. Une fiche n'est pas un autre registre que
    /// l'accueil : c'est la même voix qui nomme la journée et le mouvement.
    ///
    /// Et sur UNE ligne, toujours. Un titre qui passe à la ligne pousse tout
    /// l'écran vers le bas et fait respirer la page différemment selon la
    /// longueur du nom ; les noms les plus longs se resserrent plutôt que de
    /// se casser en deux. Le sous-titre violet a disparu avec le reste des
    /// accents colorés de cette page.
    private var header: some View {
        Text(exercise.name)
            .font(.inter(30, .semibold))
            .tracking(-0.3)
            .foregroundStyle(WoopGradient.titleFade)
            .lineLimit(1)
            .minimumScaleFactor(0.62)
    }

    // MARK: L'éditeur

    @ViewBuilder
    private var editor: some View {
        switch exercise.tracking {
        case .setsRepsWeight:
            StrengthBlock(sets: $sets, restSeconds: $restSeconds)
        case .intervals:
            IntervalBlock(phases: $phases, repeatCount: $repeatCount)
        case .steady:
            SteadyBlock(seconds: $steadySeconds, speed: $steadySpeed,
                        incline: $incline, isStairs: exercise.id == "escalier")
        }
    }

    // MARK: Le geste principal

    /// Le bas de l'écran dit toujours l'étape suivante. Tant qu'une série
    /// attend, un seul geste : la lancer. Une fois tout fait, les deux suites
    /// possibles se présentent côte à côte — en refaire une, ou enregistrer.
    private var primaryAction: some View {
        VStack(spacing: 10) {
            if canAddSeries {
                Button {
                    withAnimation(.easeOut(duration: 0.25)) { addSeries() }
                } label: {
                    Label("Ajouter une série", systemImage: "plus")
                }
                .buttonStyle(WoopSecondaryButtonStyle())
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            DiamondPrimaryButton(title: primaryTitle) {
                if let index = pendingSeries {
                    running = RunningSeries(id: index)
                } else {
                    save()
                }
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

    private var primaryTitle: String {
        pendingSeries == nil ? "Enregistrer l'exercice" : "Lancer la série"
    }

    /// La première série pas encore faite. Nul pour le cardio, qui n'a pas de
    /// séries à lancer : sa fiche ne fait qu'enregistrer.
    private var pendingSeries: Int? {
        guard exercise.tracking == .setsRepsWeight else { return nil }
        return sets.firstIndex { !$0.isDone }
    }

    /// On ne propose d'en ajouter une qu'une fois les précédentes faites :
    /// sinon le bas de l'écran offrirait deux gestes concurrents.
    private var canAddSeries: Bool {
        exercise.tracking == .setsRepsWeight && pendingSeries == nil
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

    /// Enregistrer ne quitte PAS la fiche. La feuille modale se refermait, mais
    /// une page poussée qui se dépile renverrait à la bibliothèque — or on
    /// enchaîne souvent le même exercice deux fois. On confirme, on repart d'une
    /// série vierge réglée sur les derniers chiffres, et on reste là.
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

        if exercise.tracking == .setsRepsWeight {
            let last = sets.last
            withAnimation(.easeOut(duration: 0.25)) {
                sets = [DraftSet(reps: last?.reps ?? 12, weight: last?.weight ?? 20)]
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
