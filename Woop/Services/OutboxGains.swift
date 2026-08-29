import Foundation

// MARK: - L'OUTBOX DES GAINS
//
// ⚠️⚠️ **LE PRÉREQUIS DE L'ÉTAPE 2, ET LA RAISON EST SIMPLE : SANS ELLE, UNE
// ÉCRITURE PERDUE EST UN GAIN PERDU.**
//
// L'étape 1 (l'app écrit, personne ne lit) envoyait `cloturer_seance` dans
// une tâche de fond et se contentait de LOGGER l'échec. Ça ne coûtait rien
// tant que le coffre affichait des nombres locaux. Ça coûte tout dès que le
// coffre lit le serveur : un métro sans réseau à la fin d'une séance, et la
// séance n'a jamais rapporté.
//
// ⚠️⚠️ **CE QUI REND CETTE OUTBOX CORRECTE, C'EST L'IDEMPOTENCE DU SERVEUR,
// ET RIEN D'AUTRE.** Rejouer une file d'attente, c'est envoyer deux fois ce
// qui est parti une fois et demie. Si le serveur comptait naïvement, une
// coupure au mauvais moment DOUBLERAIT les gains. Il ne compte pas
// naïvement : chaque écriture est protégée par un index unique partiel
// (un gain par séance, un sachet par séance, un versement par jour, un nœud
// par chemin). **On ne met JAMAIS dans cette file une opération dont le
// serveur ne sait pas dire « déjà fait ».**
//
// ⚠️ **ET UNE FILE QUI NE JETTE RIEN EST UNE FILE QUI SE BOUCHE.** Un envoi
// malformé qui échouera toujours resterait en tête pour l'éternité et
// bloquerait tout ce qui suit. On distingue donc trois sorts :
//
//     · réussi ................. on retire
//     · refusé DÉFINITIVEMENT .. on retire, et on le dit fort
//     · échoué TEMPORAIREMENT .. on garde, on réessaiera
//
// La frontière est le code HTTP : 4xx (sauf 401/408/429) est un refus de
// fond — le rejouer ne changera rien. Tout le reste est un accident de
// réseau.

/// UNE ÉCRITURE EN ATTENTE — typée, jamais un dictionnaire.
///
/// ⚠️ Un `[String: Any]` n'est pas `Codable` et surtout n'est pas
/// VÉRIFIABLE : on ne saurait plus, en relisant la file après un mois, si
/// une entrée correspond encore à une fonction qui existe. Un `enum` casse
/// la compilation le jour où une signature change — c'est exactement ce
/// qu'on veut d'une file qui survit aux mises à jour.
enum GainEnAttente: Codable, Equatable {
    /// La fin d'une séance : les pièces (séries × taux) **et** le sachet
    /// forfaitaire.
    case finDeSeance(seance: UUID, series: Int)
    /// Le versement de connexion — 10 pièces, une fois par jour calendaire.
    case retourQuotidien
    /// Un nœud du chemin réclamé : des pièces et/ou des sachets.
    case noeudChemin(noeud: Int, pieces: Int, monnaie: String,
                     boosters: [String])
}

/// LA FILE, ET SON VIDAGE.
///
/// ⚠️ Un `actor` : la file est touchée depuis la fin de séance, depuis le
/// retour au premier plan et depuis le chemin — trois chemins d'appel qui
/// n'ont aucune raison d'être sur le même fil. Sans isolation, deux vidages
/// simultanés rejouent la même entrée deux fois (sans dommage, grâce à
/// l'idempotence — mais on ne s'appuie pas sur le filet de sécurité pour
/// écrire du code juste).
actor OutboxGains {
    static let shared = OutboxGains()

    /// ⚠️ **BORNÉE.** Hors ligne pendant trois semaines, une file non bornée
    /// grandit sans fin et finit par ne plus tenir dans les préférences. Au
    /// delà, on jette les PLUS ANCIENNES : un gain vieux de trois semaines
    /// vaut moins que celui d'hier, et une file pleine qui refuse les
    /// nouvelles entrées est le pire des deux mondes.
    private static let plafond = 200

    /// ⚠️ `UserDefaults` et pas SwiftData : la file doit survivre à un kill
    /// de l'app, pas à une réinstallation — et elle doit être lisible sans
    /// contexte de modèle, depuis n'importe quel fil. Elle reste petite (une
    /// poignée d'entrées, quelques centaines d'octets).
    private let cle = "woop.outbox.gains"
    private var vidageEnCours = false

    private var file: [GainEnAttente] {
        get {
            guard let d = UserDefaults.standard.data(forKey: cle),
                  let f = try? JSONDecoder().decode([GainEnAttente].self,
                                                    from: d)
            else { return [] }
            return f
        }
        set {
            let borne = newValue.suffix(Self.plafond)
            UserDefaults.standard.set(try? JSONEncoder().encode(Array(borne)),
                                      forKey: cle)
        }
    }

    var enAttente: Int { file.count }

    // MARK: Le banc
    //
    // ⚠️ Le simulateur n'a PAS de mode avion, et le chemin qui compte ici est
    // justement celui de la panne. Trois drapeaux le fabriquent :
    //
    //   `-outboxAvion` : tout envoi échoue en `.aRejouer` (le réseau coupé)
    //   `-outboxSemer` : une fin de séance factice est postée au lancement
    //   `-outboxBanc`  : on s'authentifie avec le compte de TEST de la forge
    //                    et pas avec la session de l'utilisatrice — ⚠️ sans
    //                    ça, le vidage écrirait de vrais gains sur un vrai
    //                    compte, et **un ledger ne se rembobine pas** : on
    //                    n'efface pas une ligne, on en écrit une inverse.
    static let avion = CommandLine.arguments.contains("-outboxAvion")
    static let banc = CommandLine.arguments.contains("-outboxBanc")

    /// Sème une fin de séance factice — l'entrée que le banc fera voyager.
    static func semer() async {
        guard CommandLine.arguments.contains("-outboxSemer") else { return }
        await shared.poster(.finDeSeance(seance: UUID(), series: 3))
    }

    /// POSTER — on tente tout de suite, et on met en attente si ça rate.
    ///
    /// ⚠️ L'ordre compte : **tenter d'abord**. Passer systématiquement par la
    /// file ajouterait un aller-retour de préférences et un délai à un
    /// chemin qui marche neuf fois sur dix.
    func poster(_ gain: GainEnAttente) async {
        switch await envoyer(gain) {
        case .reussi:
            return
        case .refuse(let pourquoi):
            // Refusé d'emblée et pour de bon : la file n'y changerait rien.
            print("[outbox] ⚠️ REFUSÉ D'EMBLÉE : \(gain) — \(pourquoi)")
            return
        case .aRejouer:
            break
        }
        var f = file
        // ⚠️ Pas de doublon dans la file : rejouer deux fois la même fin de
        // séance ne casse rien (le serveur le refuse), mais ça allonge la
        // file pour rien et brouille le journal de bord.
        if !f.contains(gain) { f.append(gain) }
        file = f
        print("[outbox] mis en attente (\(f.count) au total) : \(gain)")
    }

    /// VIDER — à rappeler au retour au premier plan, et après toute réussite.
    func vider() async {
        guard !vidageEnCours else { return }
        vidageEnCours = true
        defer { vidageEnCours = false }

        var restants: [GainEnAttente] = []
        for gain in file {
            switch await envoyer(gain) {
            case .reussi:
                print("[outbox] rejoué avec succès : \(gain)")
            case .refuse(let pourquoi):
                // ⚠️ ON LE JETTE, ET ON CRIE. Le garder boucherait la file
                // pour toujours. Le perdre en silence serait pire.
                print("[outbox] ⚠️ REFUSÉ DÉFINITIVEMENT, jeté : \(gain) — \(pourquoi)")
            case .aRejouer:
                restants.append(gain)
            }
        }
        file = restants
        if !restants.isEmpty {
            print("[outbox] \(restants.count) en attente du prochain réseau")
        }
    }

    // MARK: L'envoi

    private enum Sort {
        case reussi
        /// Définitif : le rejouer ne changera rien.
        case refuse(String)
        /// Accident : réseau, serveur indisponible, session expirée.
        case aRejouer
    }

    private func envoyer(_ gain: GainEnAttente) async -> Sort {
        // Les mêmes gardes que partout : les données de démonstration ne
        // touchent jamais un vrai compte, et sans configuration on ne tente
        // rien. ⚠️ `aRejouer` et pas `refuse` : le jour où l'app tourne sans
        // `-demoData`, ces entrées-là doivent partir.
        if CommandLine.arguments.contains("-demoData"),
           !CommandLine.arguments.contains("-syncNow") { return .aRejouer }
        guard WoopConfig.isConfigured else { return .aRejouer }
        // Le mode avion du banc : la panne, à la demande.
        if Self.avion { return .aRejouer }

        do {
            let jwt = Self.banc ? try await ForgeServeur.jwtBanc()
                                : try await SupabaseSession.shared.token()
            switch gain {
            case .finDeSeance(let seance, let series):
                let r = try await SacreServeur.cloturerSeance(seance,
                                                              series: series,
                                                              jwt: jwt)
                print("[coffre] séance réglée : +\(r.pieces) pièces "
                      + "(créditées \(r.piecesCreditees)) · sachet "
                      + (r.boosterNeuf ? "NEUF" : "déjà acquis")
                      + " · solde \(r.solde) · reste \(r.reste)"
                      + (r.argent ? " · PIÈCE D'ARGENT" : ""))
                // ⚠️ **LA RÉPONSE EST LA LECTURE.** `cloturer_seance` rend le
                // solde, le reste, la pièce d'argent et le prix : redemander
                // `etat_coffre()` juste après, ce serait payer un
                // aller-retour pour ce qu'on tient déjà — et recréer le
                // défaut que cette réponse a été élargie pour supprimer.
                await MainActor.run { EconomieWoop.shared.appliquer(r) }
            case .retourQuotidien:
                let r = try await SacreServeur.claimRetourQuotidien(jwt: jwt)
                print("[coffre] retour quotidien : "
                      + (r.credite ? "+\(r.montant)" : "déjà pris aujourd'hui")
                      + " · solde \(r.solde)")
                await MainActor.run { EconomieWoop.shared.appliquer(r) }
            case .noeudChemin(let n, let p, let m, let b):
                let neuf = try await SacreServeur.reclamerNoeudChemin(
                    n, pieces: p, monnaie: m, boosters: b, jwt: jwt)
                print("[coffre] nœud \(n) : "
                      + (neuf ? "réclamé" : "déjà réclamé"))
                // ⚠️ Celui-ci ne rend qu'un booléen — il faut donc RELIRE.
                // C'est le seul des trois qui paie un aller-retour, et c'est
                // la raison pour laquelle les deux autres n'en paient pas :
                // une réponse qui porte le solde s'applique, une réponse qui
                // ne le porte pas se relit.
                if neuf { await EconomieWoop.shared.rafraichir() }
            }
            return .reussi
        } catch let e as SacreServeur.Erreur {
            if case .http(let code, let détail) = e {
                // ⚠️ **LA FRONTIÈRE ENTRE « ACCIDENT » ET « REFUS DE FOND ».**
                // 401 : la session a expiré — elle se renouvellera, on rejoue.
                // 408 / 429 : trop tôt, pas trop faux.
                // Les autres 4xx disent que la DEMANDE est mauvaise : la
                // rejouer telle quelle échouera à l'identique, pour toujours.
                if code == 401 || code == 408 || code == 429 { return .aRejouer }
                if (400 ..< 500).contains(code) {
                    return .refuse("HTTP \(code) \(détail)")
                }
            }
            return .aRejouer
        } catch {
            // Réseau coupé, DNS, session absente : tout ça revient.
            return .aRejouer
        }
    }
}
