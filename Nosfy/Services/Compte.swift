import Foundation
import SwiftData
import Observation

// ════════════════════════════════════════════════════════════════════════
// LE COMPTE : SE DÉCONNECTER, SUPPRIMER, OUBLIER — 14-09 (plan compte, § 9)
//
// Son ordre : « fais le backend manquant et ajoute dans l'app ce qu'il manque, on
// va tester en vrai : … je peux me déconnecter et supprimer mon compte ; si je
// relance l'app j'arrive direct à la home, plus de porte ». Les chantiers C0, C2,
// C3-app et C4 de `tools/porte/PLAN-COMPTE-BACKEND.md`, tels qu'ils y sont
// écrits — le serveur, lui, ne manque de rien (§ 7).
//
//  · `Compte.deconnecter`  : pousser ce qui attend (hors ligne avec des séances
//    non envoyées → REFUS, § 4 (a)), `POST /auth/v1/logout`, effacer TOUT ce qui
//    est à elle, la porte.
//  · `Compte.supprimer`    : l'edge function `supprimer-compte` (révoque le jeton
//    Apple si la clé est là, efface auth.users → la cascade emporte tout), puis
//    effacer, la porte. Immédiat et définitif (§ 4 (b)).
//  · `Compte.effacerToutCeQuiEstAElle` : la liste, ici et nulle part ailleurs.
//  · `Compte.rangerJetonApple` : l'authorizationCode d'Apple → `apple-jeton`.
//  · `Compte.proposerWelcomeBack` : LA porte du Welcome Back — jamais sous la
//    porte, le film ou le splash ; jamais en première fois ; et le serveur dit
//    `retour_disponible` (faux tant qu'aucune séance n'est finie — S4).
// ════════════════════════════════════════════════════════════════════════

/// Ce que la racine écoute : la porte demandée (déconnexion, suppression,
/// session révoquée) et « la porte tient l'écran » (posé par la racine).
@Observable
@MainActor
final class CompteEtat {
    static let shared = CompteEtat()

    /// Vrai le temps que la racine rende la porte ; elle le remet à faux.
    var porteDemandee = false
    var raisonPorte: String?
    /// La porte, le film de Nosfy ou le splash tiennent l'écran — le Welcome
    /// Back (et tout ce qui parle à une personne entrée) attend. Vrai au
    /// lancement : c'est la racine qui dit quand la home est vraiment là.
    var enPorte = true
    /// Le travail en cours (« Déconnexion… ») et la dernière panne, pour le
    /// panneau Réglages — qui n'a rien d'autre à savoir.
    var travail: String?
    var panne: String?

    func demanderLaPorte(raison: String) {
        raisonPorte = raison
        porteDemandee = true
    }
}

enum Compte {
    enum Issue: Equatable {
        case faite
        /// Rien n'a été effacé ; le message se montre tel quel dans Réglages.
        case refusee(String)
    }

    // MARK: - C2 — Se déconnecter

    @MainActor
    static func deconnecter(contexte: ModelContext) async -> Issue {
        let etat = CompteEtat.shared
        etat.panne = nil
        etat.travail = "Déconnexion…"
        defer { etat.travail = nil }

        // 1. Pousser ce qui attend — les séances finies et les gains en file.
        //    Hors ligne avec quelque chose à envoyer : on REFUSE (§ 4 (a)),
        //    plutôt que d'effacer une séance que le serveur n'a jamais vue.
        let finies = ((try? contexte.fetch(FetchDescriptor<Workout>())) ?? [])
            .filter { $0.endedAt != nil }
        if !finies.isEmpty {
            do {
                try await SupabaseSync.shared.pousser(finies.map { $0.snapshot() })
                print("[compte] déconnexion : \(finies.count) séance(s) poussée(s) avant d'oublier")
            } catch {
                print("[compte] déconnexion REFUSÉE : \(finies.count) séance(s) non poussée(s) · \(error.localizedDescription)")
                let m = "Connecte-toi au réseau d'abord : des séances ne sont pas encore envoyées."
                etat.panne = m
                return .refusee(m)
            }
        }
        await OutboxGains.shared.vider()
        let gainsRestants = await OutboxGains.shared.enAttente
        if gainsRestants > 0 {
            print("[compte] déconnexion REFUSÉE : \(gainsRestants) gain(s) encore en file")
            let m = "Connecte-toi au réseau d'abord : des gains ne sont pas encore envoyés."
            etat.panne = m
            return .refusee(m)
        }

        // 2. Le serveur révoque le refresh (une panne s'imprime, n'empêche rien).
        await SupabaseSession.shared.deconnecterAuServeur()

        // 3. Tout ce qui est à elle, puis la porte.
        await effacerToutCeQuiEstAElle(contexte: contexte)
        print("[compte] déconnexion → la porte")
        etat.demanderLaPorte(raison: "deconnexion")
        return .faite
    }

    // MARK: - C3-app — Supprimer mon compte

    @MainActor
    static func supprimer(contexte: ModelContext) async -> Issue {
        let etat = CompteEtat.shared
        etat.panne = nil
        etat.travail = "Suppression…"
        defer { etat.travail = nil }

        do {
            let jwt = try await SupabaseSession.shared.token()
            let (data, rep) = try await URLSession.shared.data(for: requeteFonction("supprimer-compte", jwt: jwt))
            let code = (rep as? HTTPURLResponse)?.statusCode ?? 0
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
            let ok = json["ok"] as? Bool ?? false
            guard code == 200, ok else {
                let raison = json["raison"] as? String ?? "http_\(code)"
                throw Erreur.serveur(raison)
            }
            let revocation = json["revocation"] as? String ?? "?"
            print("[compte] supprimer-compte → ok · révocation Apple : \(revocation) · user \(json["user_id"] as? String ?? "?")")
        } catch {
            print("[compte] suppression REFUSÉE (rien n'est effacé) · \(error.localizedDescription)")
            let m = "La suppression n'a pas pu se faire. Vérifie le réseau et réessaie."
            etat.panne = m
            return .refusee(m)
        }

        // Le compte n'existe plus au serveur : le jeton local mourra à son
        // expiration, on n'attend pas — on oublie tout, la porte.
        await effacerToutCeQuiEstAElle(contexte: contexte)
        print("[compte] suppression → la porte")
        etat.demanderLaPorte(raison: "suppression")
        return .faite
    }

    // MARK: - Tout ce qui est à elle

    /// LA LISTE (plan § 9) : la session, le profil en cache, l'objectif, le pull,
    /// le chemin, la file des gains, les séances SwiftData, et ce qui est en
    /// mémoire. Ce qui est à l'APP reste : la porte vue, le tuto exos vu, l'onglet
    /// ouvert, les bancs. Un nouveau compte sur ce téléphone repart vierge —
    /// et revoit la pop-up et la visite, parce que `visite_home` vit au serveur.
    @MainActor
    static func effacerToutCeQuiEstAElle(contexte: ModelContext) async {
        await OutboxGains.shared.effacer()
        await SupabaseSession.shared.oublier()
        InscriptionCompte.oublier()

        let d = UserDefaults.standard
        let cles = [
            ProfilServeur.clePrenom, Langue.cle, ProfilServeur.clePhrases,
            PremiereArrivee.clePremiereFois, PremiereArrivee.cleVue, PremiereArrivee.cleVisite,
            "woop.onboarding.du",
            Goal.cleHebdo, "woop.chambre.objectif.attente",
            SupabaseSync.cleDepuis,
            "chemin.tirages", "chemin.revele", "chemin.reclamees",
            "woop.outbox.gains",
        ]
        cles.forEach { d.removeObject(forKey: $0) }

        // Les séances : les quatre modèles, du plus profond au plus haut (la
        // cascade des relations le ferait, on ne laisse rien au hasard).
        do {
            try contexte.delete(model: CardioPhase.self)
            try contexte.delete(model: StrengthSet.self)
            try contexte.delete(model: LoggedExercise.self)
            try contexte.delete(model: Workout.self)
            try contexte.save()
        } catch {
            print("[compte] effacement SwiftData en panne · \(error)")
        }

        // En mémoire.
        ChambreEtat.shared.oublier()
        EconomieWoop.shared.oublier()
        ProfilServeur.dernierAccueil = nil
        let depart = DepartEtat.shared
        depart.welcomeOuverte = false
        depart.welcomePremiereOuverte = false
        depart.visiteOuverte = false
        print("[compte] effacé : \(cles.count) clés, les séances, la chambre, l'économie")
    }

    // MARK: - C3-app — le code Apple → apple-jeton

    /// Juste après l'entrée Apple. Une panne n'empêche pas d'entrer : 503
    /// « cle_absente » tant que la clé .p8 n'est pas posée (`poser-cle-apple.sh`).
    static func rangerJetonApple(code: String) async {
        do {
            let jwt = try await SupabaseSession.shared.token()
            let (data, rep) = try await URLSession.shared.data(
                for: requeteFonction("apple-jeton", jwt: jwt, corps: ["code": code]))
            let statut = (rep as? HTTPURLResponse)?.statusCode ?? 0
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
            if statut == 200, json["ok"] as? Bool == true {
                print("[compte] apple-jeton → ok (le refresh Apple est rangé pour la suppression)")
            } else {
                print("[compte] apple-jeton → \(statut) \(json["raison"] as? String ?? "?") — on entre quand même")
            }
        } catch {
            print("[compte] apple-jeton en panne — on entre quand même · \(error.localizedDescription)")
        }
    }

    // MARK: - La porte du Welcome Back

    /// SA RÈGLE (14-09) : « pas de pop-up Welcome Back dans l'onboarding ni la
    /// création de compte — seulement quand le compte est créé, avec notre règle
    /// backend ». Deux verrous, un par côté : ici, jamais sous la porte, le film
    /// ou le splash, jamais le jour de la première arrivée (c'est Nosfy qui
    /// parle) ; au serveur, `retour_disponible` est FAUX tant qu'aucune séance
    /// n'est finie (migration 20260913230000, S4) et `claim_retour_quotidien`
    /// refuse (`premiere_seance_requise`). Jamais par-dessus une séance en cours
    /// ni un manège. Appelée au retour au premier plan et quand la porte tombe.
    @MainActor
    static func proposerWelcomeBack() {
        let etat = CompteEtat.shared
        let eco = EconomieWoop.shared
        let sacre = SacreEtat.shared
        let depart = DepartEtat.shared
        let retenue: String? =
            etat.enPorte ? "la porte, le film ou le splash tient l'écran"
            : PremiereArrivee.premiereFois ? "première arrivée (c'est Nosfy qui parle)"
            : !eco.serveur ? "le serveur n'a pas répondu"
            : !eco.retourDisponible ? "retour_disponible faux (rien à prendre, ou aucune séance finie — S4)"
            : (sacre.manegeOuvert || sacre.popupOuverte) ? "un manège ou une pop-up est ouvert"
            : (depart.welcomeOuverte || depart.welcomePremiereOuverte || depart.visiteOuverte) ? "déjà ouverte, ou la visite"
            : nil
        if let retenue {
            print("[welcome-back] retenue : \(retenue)")
            return
        }
        print("[welcome-back] ouverte (le serveur dit que le jour est à prendre)")
        depart.welcomeOuverte = true
        // BANC `-welcomeClaimAuto` (16-09) : le simulateur ne tape pas — on
        // rejoue EXACTEMENT le chemin du bouton Claim (`onClaim` = reclamerRetour,
        // `onClose`) et on mesure le +10 : le solde AVANT / APRÈS, et le toaster
        // (à l'écran). Bug (b) = pas de toaster ; bug (c) = solde inchangé.
        if CommandLine.arguments.contains("-welcomeClaimAuto") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                let avant = eco.or
                print("[welcome-back] banc AVANT claim → solde \(avant) · dispo \(eco.retourDisponible) · pieces \(eco.piecesRetourQuotidien)")
                eco.reclamerRetour()             // = onClaim : pousse la dalle +10 + Task claim
                depart.welcomeOuverte = false    // = onClose
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    print("[welcome-back] banc APRÈS claim → solde \(eco.or) (attendu \(avant + eco.piecesRetourQuotidien))")
                }
            }
        }
    }

    // MARK: - L'appel d'une edge function, avec la session

    enum Erreur: LocalizedError {
        case serveur(String)
        var errorDescription: String? {
            if case .serveur(let r) = self { return "le serveur répond « \(r) »" }
            return nil
        }
    }

    private static func requeteFonction(_ nom: String, jwt: String,
                                        corps: [String: Any] = [:]) -> URLRequest {
        var req = URLRequest(url: WoopConfig.supabaseURL.appending(path: "functions/v1/\(nom)"))
        req.httpMethod = "POST"
        req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        req.setValue(WoopConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = (try? JSONSerialization.data(withJSONObject: corps)) ?? Data("{}".utf8)
        req.timeoutInterval = 20
        return req
    }
}
