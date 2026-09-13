import Foundation
import SwiftData

// MARK: - Catalogue

/// L'ordre des cas est celui de la molette et des sections de la page exos :
/// on descend le corps — le haut, les abdos, le bas — et le cardio ferme la
/// marche parce qu'il ne désigne pas une zone.
enum ExerciseCategory: String, Codable, CaseIterable, Identifiable {
    case haut = "Haut"
    case abdos = "Abdos"
    case bas = "Bas"
    case fessiers = "Fessiers"
    case cardio = "Cardio"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .haut: return "Dos, pectoraux, épaules, bras"
        case .abdos: return "Rotation, gainage, anti-rotation"
        case .bas: return "Jambes et chaîne postérieure"
        case .fessiers: return "Extension de hanche, abduction"
        case .cardio: return "Intervalles et endurance"
        }
    }
}

/// Matériel utilisé — affiché discrètement sur chaque carte.
enum Equipment: String, Codable {
    case poulie = "Poulie"
    case machine = "Machine"
    case barre = "Barre"
    case halteres = "Haltères"
    case poidsDuCorps = "Poids du corps"
}

/// Comment on saisit une performance pour cet exercice.
enum TrackingStyle: String, Codable {
    /// Séries de répétitions avec une charge.
    case setsRepsWeight
    /// Cycles composés de phases (durée + vitesse).
    case intervals
    /// Effort continu : une durée, une vitesse.
    case steady
}

struct Exercise: Identifiable, Hashable {
    let id: String
    let name: String
    let category: ExerciseCategory
    let equipment: Equipment
    let tracking: TrackingStyle
    /// Zone principalement travaillée.
    let muscle: String
    /// Consigne d'exécution.
    let cue: String
    /// L'erreur la plus fréquente sur ce mouvement.
    let mistake: String

    /// La photo de l'exercice — fond noir pur, corps en silhouette, muscle
    /// travaillé en lumière. Nommée d'après l'identifiant : un exercice sans
    /// image n'existe pas dans le catalogue, donc rien à replier.
    var image: String { "exo-\(id)" }

    static func == (lhs: Exercise, rhs: Exercise) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum ExerciseCatalog {
    /// ⚠️ L'ordre des sections À L'ÉCRAN vient de `ExerciseCategory.allCases`,
    /// pas de ce tableau (`ExosCatalogue.liste` filtre catégorie par
    /// catégorie) : ici seul l'ordre À L'INTÉRIEUR d'une catégorie compte, et
    /// `all[0]` sert de témoin dans plusieurs bancs — on n'y touche pas.
    static let all: [Exercise] = [
        // MARK: Abdos
        Exercise(
            id: "woop-haute", name: "Woodchopper poulie haute",
            category: .abdos, equipment: .poulie, tracking: .setsRepsWeight,
            muscle: "Obliques et transverse",
            cue: "Tu tires la poulie du haut vers la hanche opposée, le buste d'un bloc.",
            mistake: "Tirer avec les bras en laissant le bassin tourner avec le buste."),
        Exercise(
            id: "woop-basse", name: "Woodchopper poulie basse",
            category: .abdos, equipment: .poulie, tracking: .setsRepsWeight,
            muscle: "Obliques et chaîne antérieure",
            cue: "La même diagonale, mais de bas en haut, jusqu'au-dessus de l'épaule.",
            mistake: "Cambrer le bas du dos en fin de montée."),
        Exercise(
            id: "flexion-laterale", name: "Flexion latérale poulie basse",
            category: .abdos, equipment: .poulie, tracking: .setsRepsWeight,
            muscle: "Obliques",
            cue: "Tu inclines le buste sur le côté, puis tu te redresses lentement.",
            mistake: "Pencher le buste vers l'avant plutôt que strictement sur le côté."),
        Exercise(
            id: "rotation-milieu", name: "Rotation poulie médiane",
            category: .abdos, equipment: .poulie, tracking: .setsRepsWeight,
            muscle: "Obliques et transverse",
            cue: "Bras tendus devant la poitrine, tu fais pivoter le tronc.",
            mistake: "Plier les coudes, ce qui transforme l'exercice en tirage."),
        Exercise(
            id: "gainage-militaire", name: "Gainage militaire avec tirage",
            category: .abdos, equipment: .poulie, tracking: .setsRepsWeight,
            muscle: "Transverse et anti-rotation",
            cue: "En planche haute, tu tires d'une main sans que rien ne bouge.",
            mistake: "Laisser la hanche pivoter au moment du tirage."),
        Exercise(
            id: "crunch-machine", name: "Crunch à la machine assistée",
            category: .abdos, equipment: .machine, tracking: .setsRepsWeight,
            muscle: "Grand droit",
            cue: "Tu enroules le buste vertèbre par vertèbre, et tu souffles en bas.",
            mistake: "Tirer sur les poignées avec les bras au lieu d'enrouler le buste."),
        Exercise(
            id: "crunch-poulie", name: "Crunch à genoux à la poulie",
            category: .abdos, equipment: .poulie, tracking: .setsRepsWeight,
            muscle: "Grand droit",
            cue: "À genoux, tu enroules le buste vers les cuisses.",
            mistake: "Tirer avec les bras et pivoter des hanches au lieu d'enrouler le buste."),
        Exercise(
            id: "gainage", name: "Gainage",
            category: .abdos, equipment: .poidsDuCorps, tracking: .setsRepsWeight,
            muscle: "Transverse et gainage profond",
            cue: "Une ligne droite des talons à la tête, tenue sans creuser.",
            mistake: "Laisser le bassin s'affaisser, ou remonter les fesses pour souffler."),
        Exercise(
            id: "crunch-sol", name: "Crunch au sol",
            category: .abdos, equipment: .poidsDuCorps, tracking: .setsRepsWeight,
            muscle: "Grand droit",
            cue: "Tu décolles les omoplates en soufflant, le bas du dos au sol.",
            mistake: "Tirer sur la nuque avec les mains."),
        Exercise(
            id: "chevilles", name: "Toucher de chevilles",
            category: .abdos, equipment: .poidsDuCorps, tracking: .setsRepsWeight,
            muscle: "Obliques",
            cue: "Le buste relevé, tu touches une cheville puis l'autre.",
            mistake: "Tendre les bras vers les pieds sans fléchir le buste."),

        // MARK: Haut du corps
        Exercise(
            id: "developpe-couche", name: "Développé couché à la barre",
            category: .haut, equipment: .barre, tracking: .setsRepsWeight,
            muscle: "Pectoraux, triceps, épaules",
            cue: "Tu descends la barre au milieu de la poitrine, coudes à 45°.",
            mistake: "Faire rebondir la barre sur la poitrine pour relancer la montée."),
        Exercise(
            id: "papillon", name: "Papillon à la machine",
            category: .haut, equipment: .machine, tracking: .setsRepsWeight,
            muscle: "Pectoraux",
            cue: "Tu refermes les bras devant toi en serrant la poitrine.",
            mistake: "Tendre complètement les bras et tirer avec les épaules."),
        Exercise(
            id: "tirage-vertical", name: "Tirage vertical à la machine",
            category: .haut, equipment: .machine, tracking: .setsRepsWeight,
            muscle: "Grand dorsal",
            cue: "Tu tires la barre vers la poitrine, coudes le long du corps.",
            mistake: "Se balancer en arrière pour arracher la charge."),
        Exercise(
            id: "tirage-vers-soi", name: "Tirage vers soi à la poulie",
            category: .haut, equipment: .poulie, tracking: .setsRepsWeight,
            muscle: "Haut du dos et arrière d'épaule",
            cue: "Tu amènes les mains vers le visage, coudes hauts.",
            mistake: "Tirer des bras seuls en laissant les épaules monter vers les oreilles."),
        Exercise(
            id: "curl-machine", name: "Curl à la machine",
            category: .haut, equipment: .machine, tracking: .setsRepsWeight,
            muscle: "Biceps",
            cue: "Coudes calés, tu montes franchement et tu freines la descente.",
            mistake: "Lâcher la descente et laisser le bras retomber d'un coup."),
        Exercise(
            id: "elevations-laterales", name: "Élévations latérales aux haltères",
            category: .haut, equipment: .halteres, tracking: .setsRepsWeight,
            muscle: "Deltoïdes latéraux",
            cue: "Tu montes les bras jusqu'à l'horizontale, sans à-coup.",
            mistake: "Balancer le buste pour lancer les haltères plus haut."),

        // MARK: Bas du corps
        Exercise(
            id: "squat-barre", name: "Squat à la barre",
            category: .bas, equipment: .barre, tracking: .setsRepsWeight,
            muscle: "Quadriceps et fessiers",
            cue: "Les hanches partent en arrière jusqu'à la cuisse parallèle.",
            mistake: "Décoller les talons et laisser les genoux rentrer à la remontée."),
        Exercise(
            id: "presse-jambes", name: "Presse à jambes",
            category: .bas, equipment: .machine, tracking: .setsRepsWeight,
            muscle: "Quadriceps et fessiers",
            cue: "Tu descends jusqu'à l'angle droit, puis tu pousses sans verrouiller.",
            mistake: "Décoller le bas du dos du dossier pour aller chercher de l'amplitude."),
        Exercise(
            id: "souleve-de-terre", name: "Soulevé de terre",
            category: .bas, equipment: .barre, tracking: .setsRepsWeight,
            muscle: "Ischio-jambiers, fessiers et dos",
            cue: "Dos plat, tu pousses dans le sol et tu te redresses d'un bloc.",
            mistake: "Arrondir le bas du dos en démarrant par les épaules."),
        Exercise(
            id: "extension-lombaire", name: "Extension lombaire au banc",
            category: .bas, equipment: .machine, tracking: .setsRepsWeight,
            muscle: "Lombaires et ischio-jambiers",
            cue: "Charnière de hanche, tu remontes jusqu'à l'alignement — pas plus.",
            mistake: "Terminer en hyperextension, le dos cambré au-dessus de la ligne."),

        // MARK: Fessiers
        Exercise(
            id: "kickback", name: "Kickback à la poulie",
            category: .fessiers, equipment: .poulie, tracking: .setsRepsWeight,
            muscle: "Grand fessier",
            cue: "La jambe part en arrière, le buste ne bouge pas.",
            mistake: "Cambrer le bas du dos pour aller chercher de l'amplitude."),
        Exercise(
            id: "pull-through", name: "Pull-through à la poulie",
            category: .fessiers, equipment: .poulie, tracking: .setsRepsWeight,
            muscle: "Fessiers et ischio-jambiers",
            cue: "Les fesses partent en arrière, puis les hanches poussent en avant.",
            mistake: "Faire un squat au lieu d'une charnière de hanche."),
        Exercise(
            id: "abduction", name: "Abduction latérale à la poulie",
            category: .fessiers, equipment: .poulie, tracking: .setsRepsWeight,
            muscle: "Moyen fessier",
            cue: "Jambe tendue, tu l'ouvres sur le côté et tu la ramènes lentement.",
            mistake: "Se pencher du côté opposé pour lever la jambe plus haut."),
        Exercise(
            id: "squat-poulie", name: "Squat à la poulie",
            category: .fessiers, equipment: .poulie, tracking: .setsRepsWeight,
            muscle: "Quadriceps et fessiers",
            cue: "Tu t'assois vers l'arrière, genoux dans l'axe des pieds.",
            mistake: "Laisser les genoux rentrer vers l'intérieur à la remontée."),
        Exercise(
            id: "hip-thrust", name: "Hip thrust à la machine",
            category: .fessiers, equipment: .machine, tracking: .setsRepsWeight,
            muscle: "Grand fessier",
            cue: "Tu pousses par les hanches, et tu marques une pause en haut.",
            mistake: "Terminer en cambrant le dos plutôt qu'en serrant les fessiers."),

        // MARK: Cardio
        Exercise(
            id: "hiit-tapis", name: "HIIT sur tapis de course",
            category: .cardio, equipment: .machine, tracking: .intervals,
            muscle: "Cardio-respiratoire",
            cue: "Alterne phases rapides et récupérations. Un cycle regroupe plusieurs phases.",
            mistake: "Partir trop vite sur le premier cycle et s'écrouler sur les suivants."),
        Exercise(
            id: "escalier", name: "Escalier",
            category: .cardio, equipment: .machine, tracking: .steady,
            muscle: "Fessiers et cardio",
            cue: "Montée continue, buste droit, sans s'appuyer sur les barres.",
            mistake: "Se suspendre aux poignées, ce qui annule le travail des jambes."),
        Exercise(
            id: "tapis-lent", name: "Tapis à allure modérée",
            category: .cardio, equipment: .machine, tracking: .steady,
            muscle: "Endurance fondamentale",
            cue: "Allure conversationnelle, tenue longtemps.",
            mistake: "Monter l'allure jusqu'à sortir de la zone d'endurance."),
        Exercise(
            id: "piscine", name: "Piscine",
            category: .cardio, equipment: .poidsDuCorps, tracking: .steady,
            muscle: "Cardio-respiratoire et corps entier",
            cue: "Allure régulière, corps aligné à la surface, la respiration calée sur le cycle de bras.",
            mistake: "Lever la tête pour respirer : le bassin descend et les jambes se mettent à traîner.")
    ]

    static func exercises(in category: ExerciseCategory) -> [Exercise] {
        all.filter { $0.category == category }
    }

    static func exercise(id: String) -> Exercise? {
        all.first { $0.id == id }
    }
}

// MARK: - Phases de cardio

/// Une phase à l'intérieur d'un cycle. On les distingue par l'intensité, pas par
/// la couleur : dans la timeline, c'est la luminosité qui porte l'information.
enum PhaseKind: String, Codable, CaseIterable, Identifiable {
    case repos = "Repos"
    case recuperation = "Récupération"
    case acceleration = "Accélération"
    case sprint = "Sprint"

    var id: String { rawValue }

    /// 0 = repos, 1 = effort maximal. Pilote la hauteur et la luminosité dans la timeline.
    var intensity: Double {
        switch self {
        case .repos: return 0.20
        case .recuperation: return 0.42
        case .acceleration: return 0.75
        case .sprint: return 1.0
        }
    }

    var isEffort: Bool { self == .acceleration || self == .sprint }

    var defaultSeconds: Int {
        switch self {
        case .repos: return 30
        case .recuperation: return 45
        case .acceleration: return 30
        case .sprint: return 20
        }
    }

    var defaultSpeed: Double {
        switch self {
        case .repos: return 6
        case .recuperation: return 7
        case .acceleration: return 16
        case .sprint: return 19
        }
    }
}

// MARK: - Modèles persistés

@Model
final class Workout {
    /// Identifiant stable partagé avec Supabase. SwiftData n'expose pas d'ID
    /// utilisable côté serveur, donc on en génère un à la création.
    var remoteID: UUID = UUID()
    var startedAt: Date = Date.now
    var endedAt: Date?
    var notes: String = ""

    @Relationship(deleteRule: .cascade, inverse: \LoggedExercise.workout)
    var exercises: [LoggedExercise]? = []

    init(startedAt: Date = .now, endedAt: Date? = nil) {
        self.startedAt = startedAt
        self.endedAt = endedAt
    }

    var isActive: Bool { endedAt == nil }

    var orderedExercises: [LoggedExercise] {
        (exercises ?? []).sorted { $0.order < $1.order }
    }

    var exerciseCount: Int { exercises?.count ?? 0 }

    var setCount: Int {
        orderedExercises.reduce(0) { $0 + $1.orderedSets.count }
    }

    /// ⚠️⚠️ **CE QUE LA SÉANCE PAIE — ET C'EST LA DÉFINITION, PAS UN
    /// RACCOURCI.** L'audit du 29-08 a mesuré que le même gain se calculait
    /// de deux façons opposées : la card STOP et la clôture comptaient
    /// `setCount` (les séries PRÉVUES, toutes les lignes existantes), le
    /// solde du coffre comptait `completedSets` (les séries FAITES). Sur une
    /// séance à 5 séries dont 4 faites, l'un dit 100 et l'autre 80.
    ///
    /// Ce n'était pas une duplication de code — c'était un désaccord de
    /// DÉFINITION, qui aurait survécu à n'importe quelle factorisation. Il
    /// est tranché ici, en un seul endroit : **on paie ce qui a été FAIT.**
    /// Une série écrite mais jamais cochée ne vaut rien ; l'argent suit le
    /// travail, pas l'intention.
    ///
    /// ⚠️ C'est LA ligne à changer si la règle bouge — et il n'y en a qu'une.
    /// Les trois consommateurs (`gain` de fin de séance, la card STOP, le
    /// `p_series` envoyé à `cloturer_seance`) lisent tous celle-ci.
    var seriesPayantes: Int {
        orderedExercises.reduce(0) { $0 + $1.completedSets }
    }

    /// Volume total (charge × répétitions) de la séance.
    var totalVolume: Double {
        orderedExercises.reduce(0) { $0 + $1.volume }
    }

    /// Durée cumulée de cardio, en minutes.
    var cardioMinutes: Int {
        orderedExercises.reduce(0) { $0 + $1.totalSeconds } / 60
    }

    var duration: TimeInterval {
        (endedAt ?? .now).timeIntervalSince(startedAt)
    }

    var categories: [ExerciseCategory] {
        var seen: [ExerciseCategory] = []
        for logged in orderedExercises {
            if let category = logged.exercise?.category, !seen.contains(category) {
                seen.append(category)
            }
        }
        return seen
    }

    /// « Abdos et fessiers », « HIIT »…
    var categoriesLabel: String {
        let names = categories.map(\.rawValue)
        switch names.count {
        case 0: return "Séance"
        case 1: return names[0]
        case 2: return "\(names[0]) et \(names[1].lowercased())"
        default: return names.dropLast().joined(separator: ", ")
                + " et " + names[names.count - 1].lowercased()
        }
    }

    var title: String { categoriesLabel }

    /// « Aujourd'hui, 18:42 », « Samedi 25 juillet ».
    var relativeDateLabel: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(startedAt) {
            return "Aujourd'hui, \(startedAt.formatted(date: .omitted, time: .shortened))"
        }
        if calendar.isDateInYesterday(startedAt) {
            return "Hier, \(startedAt.formatted(date: .omitted, time: .shortened))"
        }
        return startedAt.formatted(.dateTime.weekday(.wide).day().month(.wide)).capitalized
    }

    /// « 7 exercices · Abdos et fessiers · 52 min »
    var rowSummary: String {
        var parts: [String] = []
        if exerciseCount > 0 {
            parts.append("\(exerciseCount) exercice\(exerciseCount > 1 ? "s" : "")")
        }
        if !categories.isEmpty { parts.append(categoriesLabel) }
        parts.append("\(Int(duration / 60)) min")
        // Insécable après le « · » : la césure tombe sur un mot, jamais après
        // le point médian (« Abdos · / 0 min » lisait sale sur deux lignes).
        return parts.joined(separator: " ·\u{00A0}")
    }
}

@Model
final class LoggedExercise {
    var remoteID: UUID = UUID()
    var exerciseID: String = ""
    var order: Int = 0
    /// Temps de récupération prévu entre les séries, en secondes. 0 = non renseigné.
    var restSeconds: Int = 0
    var workout: Workout?

    @Relationship(deleteRule: .cascade, inverse: \StrengthSet.loggedExercise)
    var sets: [StrengthSet]? = []

    @Relationship(deleteRule: .cascade, inverse: \CardioPhase.loggedExercise)
    var phases: [CardioPhase]? = []

    init(exerciseID: String, order: Int, restSeconds: Int = 0) {
        self.exerciseID = exerciseID
        self.order = order
        self.restSeconds = restSeconds
    }

    var exercise: Exercise? { ExerciseCatalog.exercise(id: exerciseID) }
    var name: String { exercise?.name ?? exerciseID }

    var orderedSets: [StrengthSet] { (sets ?? []).sorted { $0.order < $1.order } }
    var orderedPhases: [CardioPhase] {
        (phases ?? []).sorted { ($0.cycleIndex, $0.order) < ($1.cycleIndex, $1.order) }
    }

    /// Les phases regroupées par cycle, dans l'ordre.
    var cycles: [[CardioPhase]] {
        let grouped = Dictionary(grouping: orderedPhases, by: \.cycleIndex)
        return grouped.keys.sorted().map { grouped[$0]?.sorted { $0.order < $1.order } ?? [] }
    }

    var completedSets: Int { orderedSets.filter(\.isDone).count }

    var volume: Double {
        orderedSets.reduce(0) { $0 + $1.weight * Double($1.reps) }
    }

    var maxWeight: Double { orderedSets.map(\.weight).max() ?? 0 }

    var totalSeconds: Int { orderedPhases.reduce(0) { $0 + $1.seconds } }

    /// Temps cumulé sous tension : la somme des séries réellement chronométrées.
    /// 0 quand l'exercice a été saisi sans passer par le compteur.
    var timedSeconds: Int { orderedSets.reduce(0) { $0 + $1.durationSeconds } }

    /// Ligne de résumé affichée dans les listes.
    var summary: String {
        if exercise?.tracking == .setsRepsWeight || orderedPhases.isEmpty {
            let count = orderedSets.count
            guard count > 0 else { return "Aucune série" }
            let reps = orderedSets.map { "\($0.reps)" }.joined(separator: "/")
            var line = "\(count) séries · \(reps) reps · \(maxWeight.formatted(.number.precision(.fractionLength(0...1)))) kg"
            // Le temps sous tension n'apparaît que s'il a été mesuré : sur un
            // exercice simplement planifié, il n'existe pas.
            if timedSeconds > 0 { line += " · \(WoopDuration.label(timedSeconds))" }
            return line
        }
        let minutes = totalSeconds / 60
        let cycleCount = cycles.count
        let peak = orderedPhases.map(\.speed).max() ?? 0
        if cycleCount > 1 {
            return "\(minutes) min · \(cycleCount) cycles · pic \(peak.formatted(.number.precision(.fractionLength(0...1)))) km/h"
        }
        return "\(minutes) min · \(peak.formatted(.number.precision(.fractionLength(0...1)))) km/h"
    }
}

@Model
final class StrengthSet {
    var remoteID: UUID = UUID()
    var reps: Int = 10
    var weight: Double = 20
    var order: Int = 0
    /// Cochée pendant la séance. Le réalisé peut différer du prévu. Une série
    /// lancée au compteur arrive déjà cochée : elle a été faite, pas prévue.
    var isDone: Bool = false
    /// Temps réellement passé sous tension, en secondes. 0 = série cochée à la
    /// main, sans mesure.
    var durationSeconds: Int = 0
    var loggedExercise: LoggedExercise?

    init(reps: Int, weight: Double, order: Int,
         isDone: Bool = false, durationSeconds: Int = 0) {
        self.reps = reps
        self.weight = weight
        self.order = order
        self.isDone = isDone
        self.durationSeconds = durationSeconds
    }
}

@Model
final class CardioPhase {
    var remoteID: UUID = UUID()
    var kindRaw: String = PhaseKind.recuperation.rawValue
    var seconds: Int = 60
    /// Vitesse en km/h. Pour l'escalier, niveau de la machine.
    var speed: Double = 6
    /// Inclinaison, en pourcentage. 0 = non renseignée.
    var incline: Double = 0
    /// Numéro du cycle auquel appartient la phase.
    var cycleIndex: Int = 0
    var order: Int = 0
    var loggedExercise: LoggedExercise?

    init(kind: PhaseKind, seconds: Int, speed: Double,
         cycleIndex: Int = 0, order: Int = 0, incline: Double = 0) {
        self.kindRaw = kind.rawValue
        self.seconds = seconds
        self.speed = speed
        self.cycleIndex = cycleIndex
        self.order = order
        self.incline = incline
    }

    var kind: PhaseKind { PhaseKind(rawValue: kindRaw) ?? .recuperation }
    var isEffort: Bool { kind.isEffort }
}

// MARK: - Durées

/// Une durée en toutes lettres, partout pareil. Le nom est préfixé parce que
/// `Duration` est un type de la bibliothèque standard.
enum WoopDuration {
    /// « 48 s », « 4 min 12 s », « 12 min ».
    static func label(_ seconds: Int) -> String {
        let minutes = seconds / 60, rest = seconds % 60
        if minutes == 0 { return "\(rest) s" }
        return rest == 0 ? "\(minutes) min" : "\(minutes) min \(rest) s"
    }
}

// MARK: - Objectif

enum Goal {
    /// Objectif d'entraînements par semaine. La valeur d'usine — celle que
    /// lisent encore les pages d'avant la home v2.
    static let weeklyTarget = 5

    /// Depuis la home v2 (20-08) l'objectif est **réglable** : le chiffre de
    /// la phrase est un galet de verre, et son panneau propose de 3 à 7.
    /// La clé de stockage, partagée avec l'`@AppStorage` de la page.
    static let cleHebdo = "objectifHebdo"
    /// 3 → 10 depuis le 13-09 (la chambre Regularity propose 3 à 10, validé ;
    /// 3 → 7 avant). Le serveur accepte 1..14 (`user_prefs`, `definir_objectif`).
    /// UNE SEULE CLÉ pour la home, les cards, la chambre et le questionnaire de
    /// Nosfy : `ChambreEtat.shared.choisir(n)` l'écrit ici ET au serveur.
    static let hebdoChoix = [3, 4, 5, 6, 7, 8, 9, 10]

    /// L'objectif effectif. À lire ici, et plus `weeklyTarget`, à mesure que
    /// les autres pages migrent (carte objectif, calendrier, synthèse).
    static var hebdo: Int {
        let v = UserDefaults.standard.integer(forKey: cleHebdo)
        return hebdoChoix.contains(v) ? v : weeklyTarget
    }
}
