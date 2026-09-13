import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

// MARK: - LA PORTE APPLE (06-09)

/// La seule identité de Woop : Sign in with Apple, et rien d'autre. Elle remplace
/// les deux numéros en dur de `WoopConfig.credentials` — dont le mot de passe se
/// déduisait du numéro (`Supabase.swift:27-35`).
///
/// ⚠️ **On ne demande RIEN à Apple.** `requestedScopes` reste vide : le nom n'est
/// rendu qu'à la TOUTE PREMIÈRE autorisation, et jamais ensuite — une app qui
/// s'appuie dessus a un bug qui ne se reproduit pas en test. C'est Nosfy qui
/// demande le prénom, à l'écran 02 (plan : `tools/porte/PLAN-COMPTE-ONBOARDING.html`).
///
/// Le nonce a DEUX visages : Apple reçoit son SHA-256, Supabase reçoit le brut.
/// C'est ce couple qui interdit de rejouer un jeton volé — et envoyer le même des
/// deux côtés donne un 401 illisible.
enum AppleAuth {

    /// Ce que la porte rend : qui elle est, et si on l'a déjà vue.
    enum Verdict: Equatable {
        /// Aucune ligne `user_prefs` : elle n'a jamais fini l'onboarding → le film de Nosfy.
        case nouvelle(userID: String, courriel: String?)
        /// Elle a déjà un profil → l'app, directement.
        case connue(userID: String, courriel: String?)

        var userID: String {
            switch self {
            case .nouvelle(let id, _), .connue(let id, _): return id
            }
        }
        var estNouvelle: Bool {
            if case .nouvelle = self { return true }
            return false
        }
    }

    enum Panne: LocalizedError, Equatable {
        case annulee
        case apple(String)
        /// Le provider Apple n'est pas (encore) armé côté Supabase — c'est un
        /// interrupteur du tableau de bord, pas une ligne de code.
        case providerAbsent(code: Int, corps: String)
        case reseau(String)

        var errorDescription: String? {
            switch self {
            case .annulee:
                return "Connexion annulée."
            case .apple(let quoi):
                return "Apple a refusé : \(quoi)"
            case .providerAbsent(let code, let corps):
                return "Le serveur a refusé le jeton Apple (\(code)) — \(corps)"
            case .reseau(let quoi):
                return "Réseau : \(quoi)"
            }
        }

        /// Vrai quand la panne vient de l'interrupteur Supabase, pas du téléphone.
        var estInterrupteurServeur: Bool {
            if case .providerAbsent = self { return true }
            return false
        }
    }

    // MARK: Le tour complet

    /// Feuille Apple → jeton d'identité → session Supabase → lecture du profil.
    /// LE MODE MAQUETTE (13-09, sa consigne : « pour les tests de parcours sur
    /// mon tel, en mode mockup »). Lancer UNE fois avec `-parcoursMaquette` (ou
    /// `-parcoursMaquetteConnue`) le rend DURABLE : ensuite l'icône suffit — la
    /// porte joue Apple sans Apple ; une nouvelle → le film de Nosfy, une connue
    /// → l'app. `-parcoursReel` l'éteint. En maquette, RIEN ne part au réseau :
    /// ni feuille, ni jeton, ni session — le compte de test officiel
    /// (kat44426@gmail.com, par Apple) ne sert qu'au vrai test.
    enum Maquette {
        private static let cle = "woop.parcours.maquette"

        static func verdict() -> Verdict? {
            let args = CommandLine.arguments
            if args.contains("-parcoursReel") {
                UserDefaults.standard.removeObject(forKey: cle)
            } else if args.contains("-parcoursMaquetteConnue") {
                UserDefaults.standard.set("connue", forKey: cle)
            } else if args.contains("-parcoursMaquette") {
                UserDefaults.standard.set("nouvelle", forKey: cle)
            }
            switch UserDefaults.standard.string(forKey: cle) {
            case "nouvelle": return .nouvelle(userID: "maquette-nouvelle", courriel: nil)
            case "connue":   return .connue(userID: "maquette-connue", courriel: nil)
            default:         return nil
            }
        }
    }

    @MainActor
    static func entrer() async throws -> Verdict {
        if let maquette = Maquette.verdict() {
            // Le temps d'une feuille : sans lui, le film saute au visage.
            try? await Task.sleep(for: .milliseconds(700))
            return maquette
        }
        let brut = nonceBrut()
        let reponse = try await Portier().demander(nonceHache: sha256(brut))
        let session = try await echanger(idToken: reponse.jeton, nonceBrut: brut)
        let connue = try await aDejaUnProfil(token: session.access)

        // La session sert tout de suite : c'est elle qui remplace le jeton dérivé
        // du numéro pour toute la synchro.
        await SupabaseSession.shared.adopter(access: session.access,
                                             refresh: session.refresh,
                                             userID: session.userID)

        return connue
            ? .connue(userID: session.userID, courriel: session.courriel)
            : .nouvelle(userID: session.userID, courriel: session.courriel)
    }

    // MARK: L'échange du jeton

    private struct Session {
        let access: String
        let refresh: String
        let userID: String
        let courriel: String?
    }

    private static func echanger(idToken: String, nonceBrut: String) async throws -> Session {
        var requete = URLRequest(url: WoopConfig.supabaseURL
            .appending(path: "auth/v1/token")
            .appending(queryItems: [URLQueryItem(name: "grant_type", value: "id_token")]))
        requete.httpMethod = "POST"
        requete.setValue(WoopConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        requete.setValue("application/json", forHTTPHeaderField: "Content-Type")
        requete.httpBody = try JSONEncoder().encode([
            "provider": "apple",
            "id_token": idToken,
            "nonce": nonceBrut
        ])

        let (data, reponse): (Data, URLResponse)
        do {
            (data, reponse) = try await URLSession.shared.data(for: requete)
        } catch {
            throw Panne.reseau(error.localizedDescription)
        }
        guard let http = reponse as? HTTPURLResponse else {
            throw Panne.reseau("réponse illisible")
        }
        guard (200..<300).contains(http.statusCode) else {
            let corps = String(data: data, encoding: .utf8) ?? ""
            throw Panne.providerAbsent(code: http.statusCode, corps: String(corps.prefix(220)))
        }

        struct Reponse: Decodable {
            let access_token: String
            let refresh_token: String
            let user: Utilisateur
            struct Utilisateur: Decodable { let id: String; let email: String? }
        }
        let decodee = try JSONDecoder().decode(Reponse.self, from: data)
        return Session(access: decodee.access_token,
                       refresh: decodee.refresh_token,
                       userID: decodee.user.id,
                       courriel: decodee.user.email)
    }

    // MARK: La détection

    /// ⚠️ Provisoire, et assumé : la vraie porte est `user_prefs.onboarding_fait_le`,
    /// une colonne qui n'existe pas encore (jalon 2 du plan). En attendant, on lit
    /// si la ligne `user_prefs` existe — le schéma déployé le 05-09 le permet SANS
    /// migration, et RLS « select own » garantit qu'on ne voit que la sienne.
    private static func aDejaUnProfil(token: String) async throws -> Bool {
        var requete = URLRequest(url: WoopConfig.supabaseURL
            .appending(path: "rest/v1/user_prefs")
            .appending(queryItems: [URLQueryItem(name: "select", value: "objectif_hebdo")]))
        requete.setValue(WoopConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        requete.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, reponse) = try await URLSession.shared.data(for: requete)
        guard let http = reponse as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            // Une lecture qui échoue ne doit PAS inventer un compte connu : dans le
            // doute, on joue le film. Mieux vaut le rejouer qu'escamoter l'entrée.
            return false
        }
        let lignes = (try? JSONSerialization.jsonObject(with: data)) as? [Any] ?? []
        return !lignes.isEmpty
    }

    // MARK: Le nonce

    private static func nonceBrut(_ taille: Int = 32) -> String {
        let alphabet = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var octets = [UInt8](repeating: 0, count: taille)
        _ = SecRandomCopyBytes(kSecRandomDefault, taille, &octets)
        return String(octets.map { alphabet[Int($0) % alphabet.count] })
    }

    private static func sha256(_ texte: String) -> String {
        SHA256.hash(data: Data(texte.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

// MARK: - Le portier : la feuille Apple, en async

/// `ASAuthorizationController` parle en délégué ; le reste de l'app parle en
/// `await`. Cette classe fait la couture — et se retient elle-même le temps de la
/// feuille (sans ça, elle meurt avant la réponse et le rappel n'arrive jamais).
@MainActor
private final class Portier: NSObject,
                             ASAuthorizationControllerDelegate,
                             ASAuthorizationControllerPresentationContextProviding {

    struct Reponse {
        let jeton: String
        let identifiantApple: String
    }

    private var suite: CheckedContinuation<Reponse, Error>?
    private var retenue: Portier?

    func demander(nonceHache: String) async throws -> Reponse {
        try await withCheckedThrowingContinuation { continuation in
            self.suite = continuation
            self.retenue = self

            let requete = ASAuthorizationAppleIDProvider().createRequest()
            // On ne demande NI le nom NI le courriel — voir l'en-tête d'AppleAuth.
            requete.requestedScopes = []
            requete.nonce = nonceHache

            let controleur = ASAuthorizationController(authorizationRequests: [requete])
            controleur.delegate = self
            controleur.presentationContextProvider = self
            controleur.performRequests()
        }
    }

    private func rendre(_ resultat: Result<Reponse, Error>) {
        let suite = self.suite
        self.suite = nil
        self.retenue = nil
        suite?.resume(with: resultat)
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let identite = authorization.credential as? ASAuthorizationAppleIDCredential,
              let brut = identite.identityToken,
              let jeton = String(data: brut, encoding: .utf8) else {
            rendre(.failure(AppleAuth.Panne.apple("aucun jeton d'identité")))
            return
        }
        rendre(.success(Reponse(jeton: jeton, identifiantApple: identite.user)))
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        if let erreur = error as? ASAuthorizationError, erreur.code == .canceled {
            rendre(.failure(AppleAuth.Panne.annulee))
        } else {
            rendre(.failure(AppleAuth.Panne.apple(error.localizedDescription)))
        }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let fenetres = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        return fenetres.first(where: \.isKeyWindow) ?? fenetres.first ?? ASPresentationAnchor()
    }
}
