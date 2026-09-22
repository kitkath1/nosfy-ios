import Foundation
import SwiftData

// MARK: - Ce que Nosfy propose (22-09)
//
// LE LECTEUR NE S'OUVRE JAMAIS VIDE (verdict Kathryn 22-09 : « on arrive
// direct sur l'overlay et on peut choisir »). Une page blanche devant une
// débutante, c'est deux taps à faire avant de bouger ; ici, Nosfy a déjà
// posé quelques exercices et ses dernières charges.
//
// ⚠️ CE FICHIER NE DEVINE RIEN. Chaque proposition vient de l'HISTORIQUE
// réel (la loi du compte vide, 18-09 : « aucun fait, date ou gain inventé
// pour remplir l'écran »). Sans historique, il rend les exercices du
// catalogue sans aucune charge — et l'écran le dit.
//
// Il est PUR : des valeurs entrent, des valeurs sortent, aucune vue,
// aucun accès réseau. C'est ce qui le rend lisible et rejouable.

/// Un exercice proposé, avec ce qu'on en sait.
struct PropositionExo: Identifiable, Equatable {
    let exercise: Exercise
    /// La dernière charge connue sur CET exercice, s'il a déjà été fait.
    let reps: Int?
    let kilos: Double?
    /// Le jour de cette dernière fois, pour le dire à l'écran.
    let derniereFois: Date?

    var id: String { exercise.id }

    /// La ligne sous le nom : « 12 × 40 kg · comme lundi », ou le muscle
    /// quand l'exercice n'a jamais été fait. Jamais un chiffre inventé.
    func detail(calendrier: Calendar = .current, maintenant: Date = .now) -> String {
        guard let reps, let kilos else { return exercise.muscle }
        let charge = kilos.rounded() == kilos
            ? "\(Int(kilos))" : String(format: "%.1f", kilos)
        var texte = "\(reps) × \(charge) kg"
        if let d = derniereFois {
            let jours = calendrier.dateComponents([.day],
                                                  from: calendrier.startOfDay(for: d),
                                                  to: calendrier.startOfDay(for: maintenant)).day ?? 0
            if jours <= 0 { texte += " · aujourd'hui" }
            else if jours == 1 { texte += " · hier" }
            else if jours < 7 { texte += " · il y a \(jours) jours" }
        }
        return texte
    }
}

enum NosfyPropose {
    /// La fenêtre regardée pour décider de la zone du jour.
    static let fenetreJours = 14
    /// Combien d'exercices Nosfy pose dans le lecteur.
    static let combien = 4

    /// LA ZONE DU JOUR — la moins travaillée sur la fenêtre. Le cardio en
    /// est exclu : il ne désigne pas une zone du corps (Models.swift), et
    /// le proposer d'office ferait des séances qui ne se ressemblent pas.
    /// Sans aucune séance, c'est le haut du corps : le premier cas de la
    /// molette, celui que l'app montre déjà en premier.
    static func zoneDuJour(seances: [Workout],
                           maintenant: Date = .now,
                           calendrier: Calendar = .current) -> ExerciseCategory {
        let depuis = calendrier.date(byAdding: .day, value: -fenetreJours,
                                     to: maintenant) ?? maintenant
        var series: [ExerciseCategory: Int] = [:]
        for z in ExerciseCategory.allCases where z != .cardio { series[z] = 0 }
        for s in seances where s.startedAt >= depuis {
            for le in s.orderedExercises {
                guard let exo = le.exercise, exo.category != .cardio else { continue }
                let faites = (le.sets ?? []).filter(\.isDone).count
                series[exo.category, default: 0] += faites
            }
        }
        // À égalité, l'ordre du corps tranche (haut, abdos, bas, fessiers) :
        // un tirage au sort rendrait la proposition incompréhensible.
        return ExerciseCategory.allCases
            .filter { $0 != .cardio }
            .min { a, b in
                let (sa, sb) = (series[a] ?? 0, series[b] ?? 0)
                if sa != sb { return sa < sb }
                return (ExerciseCategory.allCases.firstIndex(of: a) ?? 0)
                     < (ExerciseCategory.allCases.firstIndex(of: b) ?? 0)
            } ?? .haut
    }

    /// LA DERNIÈRE CHARGE d'un exercice — la dernière série FAITE, dans la
    /// séance la plus récente qui en porte une. Rien d'autre : pas de
    /// moyenne, pas de record, pas de projection.
    static func derniereCharge(_ exo: Exercise,
                               seances: [Workout]) -> (reps: Int, kilos: Double, le: Date)? {
        for s in seances.sorted(by: { $0.startedAt > $1.startedAt }) {
            for le in s.orderedExercises where le.exerciseID == exo.id {
                if let derniere = (le.sets ?? []).filter(\.isDone).last {
                    return (derniere.reps, derniere.weight, s.startedAt)
                }
            }
        }
        return nil
    }

    /// LES PROPOSITIONS — les exercices de la zone du jour, les DÉJÀ FAITS
    /// d'abord (on reprend ce qu'on connaît, avec sa charge), les autres
    /// ensuite, dans l'ordre du catalogue.
    static func propositions(seances: [Workout],
                             zone: ExerciseCategory? = nil,
                             combien: Int? = nil,
                             maintenant: Date = .now) -> [PropositionExo] {
        let z = zone ?? zoneDuJour(seances: seances, maintenant: maintenant)
        let exos = ExerciseCatalog.exercises(in: z)
        let avec: [PropositionExo] = exos.map { exo in
            if let c = derniereCharge(exo, seances: seances) {
                return PropositionExo(exercise: exo, reps: c.reps,
                                      kilos: c.kilos, derniereFois: c.le)
            }
            return PropositionExo(exercise: exo, reps: nil, kilos: nil,
                                  derniereFois: nil)
        }
        let connus = avec.filter { $0.reps != nil }
            .sorted { ($0.derniereFois ?? .distantPast) > ($1.derniereFois ?? .distantPast) }
        let neufs = avec.filter { $0.reps == nil }
        return Array((connus + neufs).prefix(combien ?? Self.combien))
    }

    /// LE SUIVANT — la première proposition que la séance n'a pas encore
    /// touchée. `nil` quand tout est fait : le lecteur dit alors « séance
    /// terminée » au lieu d'inventer un exercice de plus.
    static func suivant(propositions: [PropositionExo],
                        dejaFaits: Set<String>) -> PropositionExo? {
        propositions.first { !dejaFaits.contains($0.exercise.id) }
    }
}
