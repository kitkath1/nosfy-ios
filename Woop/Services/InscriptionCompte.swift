import Foundation

/// La session Apple peut exister avant que Nosfy ait enregistré le profil.
/// Ces marqueurs empêchent une relance de sauter cette étape.
enum InscriptionCompte {
    static let cleEnCours = "woop.onboarding.du"
    static let cleVerification = "woop.onboarding.verifier"
    static let cleBrouillon = "woop.onboarding.brouillon"

    struct Reponses: Codable {
        var langue: String = "fr"
        var prenom: String?
        var but: String?
        var jours: Set<Int> = []
        var objectifHebdo: Int? { jours.isEmpty ? nil : jours.count }
    }

    static var aReprendre: Bool { UserDefaults.standard.bool(forKey: cleEnCours) }
    static var aVerifier: Bool { UserDefaults.standard.bool(forKey: cleVerification) }

    static var brouillon: Reponses? {
        guard let data = UserDefaults.standard.data(forKey: cleBrouillon) else { return nil }
        return try? JSONDecoder().decode(Reponses.self, from: data)
    }

    static func verifierALaReprise() {
        UserDefaults.standard.set(true, forKey: cleVerification)
    }

    static func retenir(onboardingTermine: Bool) {
        UserDefaults.standard.set(!onboardingTermine, forKey: cleEnCours)
        UserDefaults.standard.removeObject(forKey: cleVerification)
        if onboardingTermine { UserDefaults.standard.removeObject(forKey: cleBrouillon) }
    }

    static func garder(_ reponses: Reponses) {
        UserDefaults.standard.set(true, forKey: cleEnCours)
        if let data = try? JSONEncoder().encode(reponses) {
            UserDefaults.standard.set(data, forKey: cleBrouillon)
        }
    }

    static func oublier() {
        [cleEnCours, cleVerification, cleBrouillon].forEach {
            UserDefaults.standard.removeObject(forKey: $0)
        }
    }
}
