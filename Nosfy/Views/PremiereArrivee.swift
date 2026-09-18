import SwiftUI

// ════════════════════════════════════════════════════════════════════════
// LA PREMIÈRE ARRIVÉE SUR LA HOME (13-09, nuit — PLAN-PREMIERE-ARRIVEE.md)
//
// Ce que la Home fait la PREMIÈRE fois (onboarding terminé, aucune séance finie —
// c'est le serveur qui le dit : `home().premiere_fois`, mis en cache ici) :
//
//  ② la phrase « Hey Kathryn, / bienvenue. / Première séance / commence ici. »
//     (HomeNuit.fragmentsPremiereFois) ;
//  ④ la card ROUTE au chapitre 1, étape 1, rien de fait : « Commencer ici » et le
//     galet 1 qui respire (HomeNuit.majLectureChemin → CardRoute) ;
//  ⑤ LA POP-UP WELCOME « PREMIÈRE FOIS » — la card reward, robe welcome, une vidéo
//     en tête, « Bienvenue » et UNE capsule « Démarrer ». Pas de Claim, pas de
//     Later. DEUX ROBES (verdict : « garde bien l'ancienne version en mode un
//     variant de robe de pop-up ») :
//       · `.nosfyGaletOnboarding` — LA VRAIE POP-UP : Nosfy saute sur le chemin de galets
//         (`welcome-galet-premiere`, tools/porte/recuit_galet.sh : gel sur le galet
//         puis fondu, en boucle) ;
//       · `.popNosfyOnboardingTest` — « pop-nosfy_onboarding/test » (son nom) : la
//         vidéo de Nosfy de face (`welcome-nosfy-premiere`, recuit_welcome.sh), la
//         tête réduite. Banc `-welcomePremiere test`.
//     Sa porte (Kathryn : « 3 secondes après l'arrivée sur la Home ») : 3 s après
//     que la Home est là, si `premiere_fois` et que la visite n'est pas faite — une
//     fois par installation, jamais par-dessus un manège ou un panneau. Le Welcome
//     Back du jour ne la double pas : `retour_disponible` est faux sans séance.
//  ⑥ LA VISITE (VisiteHome.swift) — « Démarrer » l'ouvre : quatre temps sur la
//     Home, un élément net à la fois, tap = suivant ; le dernier tap la lève et
//     pose la mémoire : `woop.visite.faite` + `marquer_visite_home()` au serveur.
//
// Bancs (avec `-skipAuth`, sans serveur) :
//  · `-welcomePremiere [galet|test]` : la pop-up 3 s après la Home, dans la robe
//    demandée (galet par défaut ; `test` = pop-nosfy_onboarding/test) ; la phrase et
//    la card ROUTE de première fois ;
//  · `-visiteHome [1-4]` : la visite s'ouvre seule 2 s après la Home, à ce temps ;
//  · `-sansVisite` : le barreau — la visite ne se monte jamais.
// ════════════════════════════════════════════════════════════════════════

enum PremiereArrivee {
    // MARK: - Les bancs

    static let banc = CommandLine.arguments.contains("-welcomePremiere")
    static let bancVisite = CommandLine.arguments.contains("-visiteHome")
    static let sansVisite = CommandLine.arguments.contains("-sansVisite")

    /// Le mot qui suit un drapeau (`-welcomePremiere entree`, `-visiteHome 3`).
    private static func argument(apres drapeau: String) -> String? {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: drapeau), i + 1 < a.count,
              !a[i + 1].hasPrefix("-") else { return nil }
        return a[i + 1]
    }

    /// Le temps de la visite demandé au banc (1 à 4), 1 sinon.
    static let bancVisiteEtape: Int = {
        min(max(Int(argument(apres: "-visiteHome") ?? "1") ?? 1, 1), 4)
    }()

    // MARK: - Les robes de la pop-up

    enum PopRobe {
        /// « Nosfy_galet_onboarding » (son nom, 14-09) — LA VRAIE POP-UP (la robe
        /// posée) : Nosfy saute sur les galets, gel, boucle.
        case nosfyGaletOnboarding
        /// « pop-nosfy_onboarding/test » (son nom, 14-09) : Nosfy de face, la tête
        /// réduite — le variant gardé sur son ordre, pour comparer.
        case popNosfyOnboardingTest

        var videoNom: String {
            switch self {
            case .nosfyGaletOnboarding: "welcome-galet-premiere"
            case .popNosfyOnboardingTest: "welcome-nosfy-premiere"
            }
        }
    }

    /// La robe montrée — galet, sauf `-welcomePremiere test`.
    static let robe: PopRobe = argument(apres: "-welcomePremiere") == "test"
        ? .popNosfyOnboardingTest : .nosfyGaletOnboarding

    // MARK: - « Première fois » — le cache de `home().premiere_fois`

    /// Posé à VRAI par le film (`ecrireProfil`), rafraîchi par `ProfilServeur.
    /// accueil()` à chaque `home()` (le serveur gagne) : vrai tant qu'aucune
    /// séance n'est finie. La phrase et la card ROUTE le lisent sans attendre le
    /// réseau — la première Home après le film est déjà la bonne.
    static let clePremiereFois = "woop.premiere_fois"

    static var premiereFois: Bool {
        banc || bancVisite || UserDefaults.standard.bool(forKey: clePremiereFois)
    }

    /// Le prénom DU BANC quand le téléphone n'en connaît aucun (verdict 14-09 : « dans
    /// la Home à l'état vide tu as oublié le user name après Hey ») — au banc seulement ;
    /// en vrai, le prénom vient du profil (`woop.prenom`) ou des mots du serveur.
    static var prenomBanc: String? { (banc || bancVisite) ? "Kathryn" : nil }

    static func poserPremiereFois(_ vrai: Bool) {
        UserDefaults.standard.set(vrai, forKey: clePremiereFois)
    }

    // MARK: - La pop-up

    /// La pop-up a été vue sur cet appareil — on ne la rejoue pas à chaque
    /// lancement tant que la visite (qui pose `visite_home` au serveur) n'est pas
    /// faite.
    static let cleVue = "woop.welcome.premiere.vue"

    @MainActor
    static func ouvrirWelcomeSiDue() async {
        if bancVisite {
            // Le banc de la visite : pas de pop-up, la visite seule, 2 s après.
            try? await Task.sleep(for: .seconds(2))
            DepartEtat.shared.visiteEtape = bancVisiteEtape - 1
            DepartEtat.shared.visiteOuverte = true
            return
        }
        try? await Task.sleep(for: .seconds(3))
        if banc {
            DepartEtat.shared.welcomePremiereOuverte = true
            return
        }
        guard !UserDefaults.standard.bool(forKey: cleVue) else { return }
        var accueil = ProfilServeur.dernierAccueil
        if accueil == nil { accueil = try? await ProfilServeur.accueil() }
        guard let a = accueil, a.premiereFois, !a.visiteHome else { return }
        guard !SacreEtat.shared.manegeOuvert, !SacreEtat.shared.popupOuverte else { return }
        DepartEtat.shared.welcomePremiereOuverte = true
    }

    static func vue() {
        UserDefaults.standard.set(true, forKey: cleVue)
    }

    // MARK: - La visite

    static let cleVisite = "woop.visite.faite"

    static var visiteFaite: Bool { UserDefaults.standard.bool(forKey: cleVisite) }

    /// « Démarrer » : la visite monte à la racine (VisiteHome), au premier temps.
    @MainActor
    static func ouvrirVisite() {
        guard !sansVisite else { return }
        DepartEtat.shared.visiteEtape = 0
        DepartEtat.shared.visiteOuverte = true
    }

    /// Le dernier tap, « Passer », ou le doigt qui TRAVERSE la fenêtre : le voile
    /// est levé, la mémoire se pose des deux côtés — l'appareil
    /// (`woop.visite.faite`) et le serveur (`marquer_visite_home()`, mesuré par la
    /// session back-end ; ici l'appel part, la réponse est lue dans le journal).
    /// Jamais au banc ni en maquette.
    @MainActor
    static func finirVisite() {
        UserDefaults.standard.set(true, forKey: cleVisite)
        withAnimation(.easeOut(duration: 0.4)) {
            DepartEtat.shared.visiteOuverte = false
        }
        guard !banc, !bancVisite, !AppleAuth.Maquette.active else { return }
        Task {
            do {
                _ = try await ProfilServeur.marquerVisiteHome()
                print("[premiere-arrivee] marquer_visite_home() → répondu (la date est posée au serveur)")
            } catch {
                print("[premiere-arrivee] marquer_visite_home() a échoué : \(error)")
            }
        }
    }
}
