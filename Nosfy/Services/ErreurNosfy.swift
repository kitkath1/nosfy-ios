import Foundation
import Network
import Observation
import SwiftUI

// ════════════════════════════════════════════════════════════════════════
// L'ERREUR DE NOSFY — UN SEUL ÉCRAN POUR TOUT, LE MODE AVION COMPRIS (18-09)
//
// Son ordre : « il faut faire un UI d'erreur qui sera utilisé pour tout et mode
// avion : prends ce personnage (erreur.mp4) en boucle, en fr et en anglais ».
//
// Deux choses, ici :
//  · `Reseau`      : UNE oreille sur le réseau (NWPathMonitor). Elle ne décide
//                    rien ; elle dit si le téléphone a un chemin vers dehors.
//  · `ErreurNosfy` : la file d'attente de l'écran d'erreur. Un site d'appel qui
//                    a ÉCHOUÉ appelle `signaler(erreur, …)` avec ce qu'il faut
//                    rejouer ; la racine (NosfyApp) rend `EcranErreur` par-dessus
//                    tout. L'écran classe l'erreur en deux cas seulement :
//                    PAS DE RÉSEAU (le mode avion, le métro) ou LE SERVEUR N'A
//                    PAS RÉPONDU. Il n'y a pas de troisième message — un
//                    utilisateur n'a rien à faire d'un code HTTP.
//
// Le mode avion (19-09, son mot : « quand j'active le mode avion ça marche pas,
// c'est une règle Apple, donc t'affiches le message ») : dès que `Reseau` dit
// hors ligne, la racine (`EcranErreurHote`) MONTE l'écran, sans attendre qu'un
// appel échoue ; il tombe tout seul quand le réseau revient. Le bouton n'est là
// que pour la main impatiente.
// ════════════════════════════════════════════════════════════════════════

/// Le réseau, écouté une fois pour toute l'app.
@Observable
@MainActor
final class Reseau {
    static let shared = Reseau()

    /// Vrai tant que le moniteur n'a rien dit (on ne peint pas « hors ligne »
    /// à vue) ; puis la vérité du chemin.
    private(set) var enLigne = true
    /// Le moniteur a parlé au moins une fois.
    private(set) var mesure = false
    /// LE BARREAU (`-erreurHorsLigne`) : le simulateur n'a pas de mode avion —
    /// ce drapeau force « hors ligne » pour juger l'écran et son message.
    static let forceHorsLigne = CommandLine.arguments.contains("-erreurHorsLigne")

    @ObservationIgnored private let moniteur = NWPathMonitor()

    private init() {
        if Self.forceHorsLigne { enLigne = false; mesure = true; return }
        moniteur.pathUpdateHandler = { [weak self] chemin in
            let ok = chemin.status == .satisfied
            Task { @MainActor in
                guard let self else { return }
                if self.enLigne != ok || !self.mesure { print("[reseau] \(ok ? "en ligne" : "HORS LIGNE")") }
                // En fondu : l'écran d'erreur monte et tombe sur cette valeur.
                withAnimation(.easeOut(duration: 0.4)) {
                    self.enLigne = ok
                    self.mesure = true
                }
            }
        }
        moniteur.start(queue: DispatchQueue(label: "fr.kathryn.woop.reseau"))
    }
}

/// L'écran d'erreur, demandé depuis n'importe où ; rendu à la racine.
@Observable
@MainActor
final class ErreurNosfy {
    static let shared = ErreurNosfy()

    /// Les deux seuls cas que l'écran sait dire.
    enum Cas: Equatable {
        /// Pas de chemin vers dehors : mode avion, tunnel, Wi‑Fi sans internet.
        case horsLigne
        /// Le téléphone a le réseau, le serveur n'a pas répondu (ou a refusé).
        /// `detail` va au journal, jamais à l'écran.
        case serveur(detail: String?)
    }

    struct Demande: Identifiable {
        let id = UUID()
        let cas: Cas
        /// D'où ça vient — pour le journal `[erreur]` et pour la QA.
        let origine: String
        /// Rejouer ce qui a échoué. Vrai = c'est réglé, l'écran se ferme ;
        /// faux = toujours en panne, l'écran reste (et redit pourquoi).
        let reessayer: @MainActor () async -> Bool
        /// Renoncer sans réessayer (« Plus tard »). nil = l'écran bloque
        /// jusqu'au succès — c'est le cas des portes (profil, inscription).
        let fermer: (@MainActor () -> Void)?
    }

    private(set) var courante: Demande?
    var visible: Bool { courante != nil }

    private init() {}

    /// Classer une erreur : réseau ou serveur. Une annulation n'est pas une
    /// erreur (la tâche est partie, personne n'attend de réponse).
    static func cas(pour erreur: Error) -> Cas? {
        if erreur is CancellationError { return nil }
        if let u = erreur as? URLError {
            switch u.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed,
                 .internationalRoamingOff, .cannotFindHost, .cannotConnectToHost,
                 .dnsLookupFailed, .timedOut, .secureConnectionFailed:
                return .horsLigne
            case .cancelled:
                return nil
            default:
                break
            }
        }
        if !Reseau.shared.enLigne, Reseau.shared.mesure { return .horsLigne }
        return .serveur(detail: erreur.localizedDescription)
    }

    /// Le geste des sites d'appel : « ça a échoué, voilà comment rejouer ».
    /// `reessayer` relance l'appel ; s'il jette encore, l'écran reste.
    func signaler(_ erreur: Error, origine: String,
                  fermer: (@MainActor () -> Void)? = nil,
                  reessayer: @escaping @MainActor () async throws -> Void) {
        guard let cas = Self.cas(pour: erreur) else { return }
        montrer(cas, origine: origine, fermer: fermer) {
            do { try await reessayer(); return true }
            catch { print("[erreur] \(origine) : toujours en panne · \(error.localizedDescription)"); return false }
        }
    }

    func montrer(_ cas: Cas, origine: String,
                 fermer: (@MainActor () -> Void)? = nil,
                 reessayer: @escaping @MainActor () async -> Bool) {
        // Une seule à la fois : la première panne tient l'écran, les suivantes
        // (souvent la même cause) attendent qu'elle soit réglée.
        guard courante == nil else {
            print("[erreur] \(origine) : ignorée, l'écran est déjà pris par \(courante!.origine)")
            return
        }
        if case .serveur(let d) = cas { print("[erreur] \(origine) : serveur · \(d ?? "?")") }
        else { print("[erreur] \(origine) : hors ligne") }
        courante = Demande(cas: cas, origine: origine, reessayer: reessayer, fermer: fermer)
    }

    func fermer() { courante = nil }
}
