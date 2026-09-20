import Foundation
import Observation

/// LA REVISITE DE NOSFY (20-09, `tools/profil/ANALYSE-REVISITE-NOSFY-2026-09-20.md`
/// § 6) : un tap sur le médaillon du profil rejoue le film de Nosfy en mode
/// « souvenir » — il récite ce qu'il sait (la langue, le prénom, le but), seul
/// le prénom se change, un chevron ramène au profil.
///
/// C'est la porte entre la page profil (qui DEMANDE) et la racine de l'app (qui
/// MONTE le film au-dessus de tout, comme le film d'inscription) : le même
/// dessin que `SacreEtat.arriveeDemandee`. Le film ne vit jamais dans l'onglet.
@Observable
final class RevisiteNosfy {
    static let shared = RevisiteNosfy()

    /// Vrai tant que le film est monté ; la racine l'observe.
    /// Banc : `-revisiteNosfy` l'ouvre au lancement (captures, mesures).
    var demandee = CommandLine.arguments.contains("-revisiteNosfy")

    /// Ce que le film récite — lu du cache du téléphone, jamais du réseau :
    /// le prénom (`woop.prenom`), la langue (`woop.langue`), le but (`woop.but`).
    /// Un but inconnu (compte réinstallé hors ligne) : la phrase du but se tait.
    struct Souvenir {
        var prenom: String
        var langue: String
        var but: String?
    }

    static func souvenir() -> Souvenir {
        Souvenir(prenom: ProfilServeur.prenomLocal ?? "",
                 langue: Langue.courante,
                 but: ProfilServeur.butLocal)
    }

    static func demander() { shared.demandee = true }
}
