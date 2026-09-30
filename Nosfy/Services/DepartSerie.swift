import Foundation

// ════════════════════════════════════════════════════════════════════════
// LE DÉPART DE SÉRIE — la règle qui transforme l'app (30-09, session Réglages)
//
// Kathryn, 30-09 : « le user peut choisir le galet blanc ou le slider », puis
// « il faut ajouter la règle backend aussi, qui transforme l'app avec le
// slider ou le galet ». Le choix suit donc le COMPTE, comme la langue.
//
// UNE vérité : `user_prefs.depart_serie` au serveur (migration
// 20260930120000), `null` = jamais choisi → `reward_rules.depart_serie_defaut`
// (le slider, décision D1). ICI, son cache `woop.departSerie` : c'est lui que
// la fiche lit à son montage, sans attendre le réseau.
//
// Même contrat que l'objectif hebdo (`ChambreEtat.choisir`) : le cache TOUT
// DE SUITE (le choix se voit à l'instant), le serveur ensuite ; un appel raté
// laisse une marque « en attente » que la lecture suivante réécrit au lieu de
// l'écraser. Sinon le serveur, qui gagne toujours, défait le choix au
// prochain retour à l'accueil.
//
// Plan : tools/reglages/PLAN-REGLAGES-2026-09-30.md
// ════════════════════════════════════════════════════════════════════════

enum DepartSerie: String, CaseIterable {
    /// Le galet blanc : glissé vers le haut, le monde blanc, le sommet, le chrono.
    case galet
    /// Le slider obsidienne : glissé, et l'écran du chrono (3, 2, 1, GO).
    case slider

    static let cle = "woop.departSerie"
    static let cleAttente = "woop.departSerie.attente"

    /// Le défaut quand ni le serveur ni le téléphone n'ont encore parlé — le
    /// même que `reward_rules.depart_serie_defaut`, seulement pour le froid.
    static let defaut: DepartSerie = .slider

    /// Le format courant : le cache, sinon le défaut.
    static var courant: DepartSerie {
        UserDefaults.standard.string(forKey: cle).flatMap(DepartSerie.init) ?? defaut
    }

    /// Le mot de la tuile, dans la langue de l'app.
    var nom: String {
        switch self {
        case .galet: return L("Galet", "Pebble")
        case .slider: return "Slider"
        }
    }

    // MARK: - Le choix

    /// Ce que le serveur a fait du choix — le toaster de Réglages le dit.
    enum Ecriture { case faite, enAttente, locale }

    /// Le choix dans Réglages : le cache TOUT DE SUITE (l'app change à
    /// l'instant), puis le serveur, dont on rend le verdict.
    @MainActor
    static func choisir(_ d: DepartSerie) async -> Ecriture {
        UserDefaults.standard.set(d.rawValue, forKey: cle)
        guard serveurJoignable else { return .locale }
        return await ecrire(d) ? .faite : .enAttente
    }

    /// Le serveur est-il à portée ? En maquette ou sans configuration, le
    /// choix reste au téléphone et rien ne part.
    private static var serveurJoignable: Bool {
        WoopConfig.isConfigured && !AppleAuth.Maquette.active
    }

    @discardableResult
    private static func ecrire(_ d: DepartSerie) async -> Bool {
        guard serveurJoignable else { return false }
        do {
            let s = try await ProfilServeur.definirDepartSerie(d.rawValue)
            UserDefaults.standard.removeObject(forKey: cleAttente)
            // Le serveur a répondu avec l'état qu'il tient : c'est lui le cache.
            if let lu = DepartSerie(rawValue: s) {
                UserDefaults.standard.set(lu.rawValue, forKey: cle)
            }
            print("[depart-serie] definir_depart_serie(\(d.rawValue)) → \(s)")
            return true
        } catch {
            UserDefaults.standard.set(true, forKey: cleAttente)
            print("[depart-serie] definir_depart_serie(\(d.rawValue)) ✗ \(error) — en attente")
            return false
        }
    }

    /// La lecture, au retour de la home et à l'arrivée sur Réglages. Un choix
    /// resté en attente se RÉÉCRIT d'abord : le serveur ne l'a jamais reçu.
    static func rafraichir() async {
        guard serveurJoignable else { return }
        if UserDefaults.standard.bool(forKey: cleAttente) {
            await ecrire(courant)
            return
        }
        do {
            let s = try await ProfilServeur.departSerie()
            if let lu = DepartSerie(rawValue: s) {
                UserDefaults.standard.set(lu.rawValue, forKey: cle)
            }
            print("[depart-serie] depart_serie() → \(s)")
        } catch {
            print("[depart-serie] depart_serie() ✗ \(error)")
        }
    }
}
