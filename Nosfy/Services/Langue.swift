import Foundation

// ════════════════════════════════════════════════════════════════════════
// LA LANGUE — le socle (13-09, nuit ; le contrat : PLAN-PREMIERE-ARRIVEE.md § 9)
//
// UNE vérité : `profils.langue` au serveur (écrite par `definir_profil` à la fin du
// film, modifiable depuis le Profil par le même appel, rendue par `profil()` et
// `home()`). ICI, son cache : `woop.langue`, posé par le film avant même que le
// serveur réponde, rafraîchi depuis `home()` à chaque apparition de la Home — le
// serveur gagne, comme pour le prénom. À froid, sans rien : la langue de l'appareil.
//
// LES TEXTES DE L'APP passent par UN helper, celui que le film utilise déjà :
// `L("texte français", "english text")`. Pas de catalogues `.strings` : chaque texte
// vit à côté de son écran, dans les deux langues — et la règle de la maison est
// qu'un texte ne naît jamais dans une seule langue. Les textes du SERVEUR (phrases
// générées, annonces, stories, mots géants) naissent dans `profils.langue` : l'app ne
// traduit jamais un texte serveur.
// ════════════════════════════════════════════════════════════════════════

enum Langue {
    static let cle = "woop.langue"

    /// « fr » ou « en » — le cache, sinon l'appareil.
    static var courante: String {
        if let l = UserDefaults.standard.string(forKey: cle), l == "fr" || l == "en" { return l }
        return Locale.current.language.languageCode?.identifier == "fr" ? "fr" : "en"
    }

    static var en: Bool { courante == "en" }

    /// Poser le cache — le film à la fin, la Home quand `home()` répond.
    static func poser(_ langue: String?) {
        guard let langue, langue == "fr" || langue == "en" else { return }
        UserDefaults.standard.set(langue, forKey: cle)
    }
}

/// Le texte dans la langue courante — `L("Bienvenue", "Welcome")`.
func L(_ fr: String, _ en: String) -> String { Langue.en ? en : fr }

extension ExerciseCategory {
    var nomLocalise: String {
        switch self {
        case .haut: return L("Haut du corps", "Upper body")
        case .abdos: return L("Abdos", "Core")
        case .bas: return L("Jambes", "Legs")
        case .fessiers: return L("Fessiers", "Glutes")
        case .cardio: return "Cardio"
        }
    }
}

extension Exercise {
    /// Le catalogue conserve ses identifiants et ses noms sources. Seul
    /// l'affichage change de langue, y compris dans les faits des stories.
    var nomLocalise: String {
        guard Langue.en else { return name }
        return Self.nomsAnglais[id] ?? name
    }

    private static let nomsAnglais: [String: String] = [
        "woop-haute": "High cable woodchopper",
        "woop-basse": "Low cable woodchopper",
        "flexion-laterale": "Low cable side bend",
        "rotation-milieu": "Standing cable rotation",
        "gainage-militaire": "Plank with cable row",
        "crunch-machine": "Assisted machine crunch",
        "crunch-poulie": "Kneeling cable crunch",
        "gainage": "Plank",
        "crunch-sol": "Floor crunch",
        "chevilles": "Heel touches",
        "developpe-couche": "Barbell bench press",
        "papillon": "Machine chest fly",
        "tirage-vertical": "Lat pulldown",
        "tirage-vers-soi": "Seated cable row",
        "curl-machine": "Machine curl",
        "elevations-laterales": "Dumbbell lateral raise",
        "squat-barre": "Barbell squat",
        "presse-jambes": "Leg press",
        "souleve-de-terre": "Deadlift",
        "extension-lombaire": "Back extension",
        "kickback": "Cable kickback",
        "pull-through": "Cable pull-through",
        "abduction": "Cable hip abduction",
        "squat-poulie": "Cable squat",
        "hip-thrust": "Machine hip thrust",
        "hiit-tapis": "Treadmill HIIT",
        "escalier": "Stair climber",
        "tapis-lent": "Steady treadmill",
        "piscine": "Swimming"
    ]
}
