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
