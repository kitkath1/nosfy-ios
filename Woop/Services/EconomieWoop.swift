import Foundation
import SwiftUI

// MARK: - L'ÉCONOMIE, EN UN SEUL ENDROIT
//
// ⚠️⚠️ **CE FICHIER EXISTE PARCE QUE LE MÊME NOMBRE VIVAIT À NEUF ENDROITS.**
// L'audit du 29-08, vérifié ligne à ligne :
//
//   · le taux de 20 pièces par série avait HUIT définitions côté app
//     (`CoffreFortPurse.perSeries`, `ExerciseDetailView.gainParSerie`, deux
//     littéraux nus dans `WoopApp`, `CoffreV2`, …) plus une neuvième en base ;
//   · le prix d'un booster valait **20 sur le profil** (`ProfilLune.prix`) et
//     **100 dans le coffre** (`CoffreV2.prixBooster`) — deux écrans enchaînés
//     depuis la même page, deux prix pour le même objet ;
//   · le solde s'affichait BRUT au profil et diminué d'une dépense SIMULÉE au
//     coffre, si bien que la même grandeur y perdait 100 pièces en une
//     transition, sans qu'aucune transaction ait eu lieu ;
//   · et le journal des gains était RECONSTRUIT depuis les séances, avec
//     `robe: nil` en dur — un booster ne pouvait pas y apparaître, alors que
//     `historique_gains()` les rend tous, chemin compris.
//
// La règle, tranchée : **l'app LIT les prix et les soldes, elle ne les connaît
// pas.** `etat_coffre()` rend déjà `prix_booster` et `pieces_par_serie`
// exactement pour ça — personne ne les lisait.
//
// ⚠️ **ET IL Y A UNE MAQUETTE, PARCE QU'IL LE FAUT.** Sans compte connecté,
// `auth.uid()` est nul et le serveur ne peut rien rendre : l'app doit
// continuer de tourner. La maquette locale (séries faites × 20 depuis
// SwiftData) reste donc le REPLI — mais elle est poussée ICI par les vues qui
// ont la requête, et c'est cet objet qui décide laquelle des deux sert. Un
// seul arbitre, pas cinq écrans qui choisissent chacun leur vérité.
//
// ⚠️ **LE REPLI NE REVIENT JAMAIS EN ARRIÈRE.** Une fois que le serveur a
// répondu une fois, `serveur` reste vrai : une coupure réseau plus tard rend
// des nombres PÉRIMÉS, jamais des nombres FAUX de 100. Basculer sur la
// maquette au premier timeout, ce serait faire sauter le solde sous les yeux
// de quelqu'un qui n'a rien fait.
//
// Écrans : `docs/screens/coffre-rewards.md` · Règles :
// `tools/coffre-v2/BACKEND-COFFRE.md` · `tools/rewards/PLAN-REWARDS-BACKEND.md`

/// UNE LIGNE DU JOURNAL — sortie de `CoffreFortView.swift` le 29-08.
///
/// Elle habitait le fichier d'une page, comme `CoffreFortPurse` avant elle, et
/// pour la même raison elle en sort : le journal n'appartient pas à l'écran
/// qui l'affiche. Il est maintenant servi par le serveur ou par la maquette,
/// et trois écrans le lisent.
struct GainCoffre: Identifiable {
    let id: UUID
    let date: Date
    let montant: Int
    /// Ce qu'on a gagné — l'image de la ligne le dit sans un mot.
    let robe: RobeBooster?
    let titre: String
}

@MainActor
@Observable
final class EconomieWoop {
    static let shared = EconomieWoop()
    private init() {}

    // ── CE QUE LES ÉCRANS LISENT ────────────────────────────────────────
    //
    // Ces six-là sont LA vérité affichable. Aucun écran n'a plus le droit de
    // recalculer l'un d'eux.

    /// Les pièces jaunes. C'est le nombre de la pastille de la home, du
    /// profil, et de la première page du coffre — le MÊME.
    private(set) var or = 0
    /// Les pièces d'argent. Elles ne s'accumulent pas, elles tombent
    /// (`roll_rare`, p = 1/30 au règlement d'une séance).
    private(set) var argent = 0
    /// Les sachets non ouverts, hors légendaires.
    ///
    /// ⚠️⚠️ **LA MAQUETTE DES SACHETS VIT ICI, ET PAS DANS `SacreEtat`.**
    /// Premier jet : `SacreEtat` gardait son compteur local et lisait le
    /// serveur par-dessus. Résultat mesuré au banc — hors ligne, le pied du
    /// coffre affichait « 0 booster » et « 100 COINS TO GO » avec 1 240
    /// pièces, parce que `EconomieWoop` n'avait pas de repli pour CE
    /// nombre-là. Deux replis, deux vérités : exactement le défaut qu'on
    /// répare. L'arbitre en tient UN, et `SacreEtat` lui délègue.
    var boosters: Int { serveur ? boostersServeur : maquetteBoosters }
    private(set) var boostersServeur = 0
    var maquetteBoosters = 1

    /// Les sachets NOIRS ouvrables. ⚠️ Côté serveur, solde d'argent et
    /// sachets noirs sont LE MÊME NOMBRE : le sachet noir naît au claim.
    var boostersNoirs: Int { serveur ? argent : maquetteNoirs }
    var maquetteNoirs = SacreEtat.bancNoir ? 1 : 0
    /// Où en est la jauge vers le prochain sachet, en pièces (0…prix−1).
    /// ⚠️ Dérivé côté serveur (`solde_or mod prix_booster`) depuis le 29-08 :
    /// il lisait avant une table que personne n'écrivait, et affichait donc
    /// 0/100 quel que soit le solde.
    private(set) var reste = 0
    /// Ce qu'un sachet coûte. ⚠️ **LE PROFIL DISAIT 20, LE COFFRE 100.**
    private(set) var prixBooster = 100
    /// Ce qu'une série rapporte. Lu, plus deviné.
    private(set) var piecesParSerie = 20
    /// Le journal, du plus récent au plus ancien.
    private(set) var journal: [GainCoffre] = []

    /// Vrai dès que le serveur a répondu UNE fois. Tant qu'il est faux, tout
    /// ce qui précède vient de la maquette.
    private(set) var serveur = false
    private(set) var chargement = false
    /// La dernière erreur, pour l'état d'erreur des écrans. Jamais montrée
    /// telle quelle : un écran de récompenses n'affiche pas un code HTTP.
    private(set) var derniereErreur: String?

    // ── LA MAQUETTE ─────────────────────────────────────────────────────

    private var maquetteOr = 0
    private var maquetteJournal: [GainCoffre] = []

    /// LE REPLI, POUSSÉ PAR LES VUES QUI ONT LA REQUÊTE SWIFTDATA.
    ///
    /// ⚠️ Elle ne fait rien quand le serveur a déjà parlé — sinon la maquette
    /// écraserait la vérité à chaque réévaluation de corps de la home.
    ///
    /// ⚠️ **`journal` EST OPTIONNEL, ET CE N'EST PAS UN CONFORT.** Le profil
    /// et la home connaissent le solde mais pas la liste ; leur faire passer
    /// `[]` viderait l'historique du coffre à chaque passage sur le profil.
    /// Ne rien passer veut dire « je ne sais pas », jamais « c'est vide ».
    func poserMaquette(or: Int, journal: [GainCoffre]? = nil) {
        maquetteOr = or
        if let journal { maquetteJournal = journal }
        guard !serveur else { return }
        self.or = or
        // ⚠️ **LE `reste` DOIT EXISTER HORS LIGNE AUSSI.** C'est la jauge du
        // pied ; laissée à 0, elle affiche « 100 COINS TO GO » sur un solde de
        // 1 240. La formule est celle du serveur, à la lettre
        // (`solde_or mod prix_booster`) : deux formules du même nombre, ce
        // serait rouvrir la porte qu'on vient de fermer.
        self.reste = max(or, 0) % max(prixBooster, 1)
        if let journal { self.journal = journal }
        // La maquette n'a pas de sachet : c'est `SacreEtat` qui les tenait, et
        // il vient les chercher ici (voir `BoosterPopup.swift`).
    }

    // ── LA LECTURE ──────────────────────────────────────────────────────

    /// ⚠️ **LES MÊMES GARDES QUE L'OUTBOX, ET C'EST VOULU** : les données de
    /// démonstration ne touchent jamais un vrai compte, et sans configuration
    /// on ne tente rien (« aucun 404 dans les logs d'une app dont le backend
    /// n'est pas encore là »). Une seule règle d'accès au serveur, pas deux.
    static var possible: Bool {
        if CommandLine.arguments.contains("-demoData"),
           !CommandLine.arguments.contains("-syncNow") { return false }
        return WoopConfig.isConfigured
    }

    /// LE PIED DU COFFRE ET LE JOURNAL, EN DEUX APPELS.
    ///
    /// ⚠️ **`etat_coffre()` D'ABORD, ET SEUL S'IL LE FAUT.** Le journal est
    /// long (60 lignes) et ne sert qu'à la page « Mes gains » ; les six
    /// nombres, eux, sont partout. Un écran qui n'ouvre pas l'historique
    /// n'a pas à le payer — d'où `avecJournal`.
    ///
    /// ⚠️ **ELLE NE PROPAGE JAMAIS SON ÉCHEC.** Un solde qu'on n'a pas pu
    /// relire n'est pas une erreur d'application : c'est un nombre périmé.
    func rafraichir(avecJournal: Bool = false) async {
        guard Self.possible, !chargement else { return }
        chargement = true
        defer { chargement = false }
        do {
            let jwt = try await SupabaseSession.shared.token()
            let e = try await SacreServeur.etatCoffre(jwt: jwt)
            appliquer(e)
            if avecJournal {
                let lignes = try await SacreServeur.historique(jwt: jwt)
                journal = lignes.map(Self.ligne)
            }
            derniereErreur = nil
        } catch {
            derniereErreur = error.localizedDescription
            print("[économie] lecture impossible : \(error)")
        }
    }

    private func appliquer(_ e: SacreServeur.EtatCoffre) {
        or = e.soldeOr
        argent = e.soldeArgent
        boostersServeur = e.boostersOr
        reste = e.reste
        prixBooster = e.prixBooster
        piecesParSerie = e.piecesParSerie
        serveur = true
    }

    /// LE RÈGLEMENT D'UNE SÉANCE RÉPOND DÉJÀ TOUT — ON NE REDEMANDE RIEN.
    ///
    /// ⚠️ `cloturer_seance` rend `solde`, `reste`, `argent` et `prix_booster`
    /// depuis le 29-08, précisément pour qu'une annonce n'ait pas besoin de
    /// plusieurs sources. Refaire un aller-retour ici, ce serait recréer le
    /// défaut que cette réponse a été élargie pour supprimer.
    func appliquer(_ c: SacreServeur.ClotureSeance) {
        or = c.solde
        reste = c.reste
        prixBooster = c.prixBooster
        if c.argent { argent += 1 }
        if c.boosterNeuf { boostersServeur += 1 }
        serveur = true
    }

    /// Un versement de connexion réglé : le solde est à jour sans relecture.
    func appliquer(_ r: SacreServeur.RetourQuotidien) {
        or = r.solde
        reste = max(or, 0) % max(prixBooster, 1)
        serveur = true
    }

    // ── LES DÉPENSES ────────────────────────────────────────────────────

    enum Achat {
        case obtenu
        case soldeInsuffisant(manque: Int)
        case impossible
    }

    /// ACHETER UN SACHET — **le seul débit de pièces de l'app.**
    ///
    /// ⚠️⚠️ **IL N'EN EXISTAIT AUCUN.** Les deux boutons qui promettaient un
    /// achat — le panneau du profil (« Utiliser N pièces pour ouvrir un
    /// booster ? ») et le pied du coffre (« bought for 100 coins ») —
    /// appelaient tous deux `SacreEtat.ouvrirManege()` et rien d'autre :
    /// aucun débit, aucune garde sur le solde. On pouvait ouvrir des sachets
    /// indéfiniment avec zéro pièce, et le ledger ne faisait que grossir. Le
    /// commentaire du profil l'assumait (« DÉMO : le verrou des pièces NE
    /// FERME JAMAIS la porte ») — il ne l'assume plus.
    ///
    /// ⚠️ **LE DÉBIT ET LA RÉSERVE SONT DANS LA MÊME TRANSACTION**, côté
    /// serveur (`claim_booster`) : sans ça, un réseau qui coupe entre les deux
    /// laisse une pièce dépensée sans sachet, ou l'inverse. C'est aussi
    /// pourquoi cet achat ne passe PAS par l'outbox : une file d'attente
    /// répond « peut-être, plus tard », et on n'ouvre pas une cérémonie sur un
    /// peut-être.
    ///
    /// ⚠️ **SANS SERVEUR, LA PORTE RESTE OUVERTE.** L'app doit tourner sans
    /// compte : la maquette laisse passer, comme avant. C'est un choix, pas un
    /// oubli — refuser l'achat hors ligne fermerait le manège à quiconque n'a
    /// pas encore de compte, et le manège est ce qu'on montre en premier.
    func acheterBooster() async -> Achat {
        guard Self.possible else { return .obtenu }
        do {
            let jwt = try await SupabaseSession.shared.token()
            let a = try await SacreServeur.claimBooster(jwt: jwt)
            or = a.solde
            prixBooster = a.prix
            reste = max(or, 0) % max(prixBooster, 1)
            serveur = true
            guard a.ouvert else {
                return .soldeInsuffisant(manque: max(a.prix - a.solde, 0))
            }
            boostersServeur += 1
            return .obtenu
        } catch {
            derniereErreur = error.localizedDescription
            print("[économie] achat impossible : \(error)")
            return .impossible
        }
    }

    /// CONSOMMER UN SACHET — l'ouverture, côté serveur.
    ///
    /// ⚠️⚠️ **RIEN NE CONSOMMAIT RIEN.** Aucune ligne du dépôt ne met à jour
    /// `opened_at` : le manège appelait `ForgeServeur.tirer(jwt:)` sans
    /// aucun identifiant de sachet, si bien que côté serveur ouvrir un
    /// booster ne se voyait PAS. La pile ne pouvait que croître, il n'y avait
    /// aucune idempotence d'ouverture, et la garantie « légendaire » du
    /// booster noir n'était jamais armée — le manège noir tirait exactement
    /// comme le jaune.
    ///
    /// ✅ **LA MIGRATION `20260829150000_ouvrir_booster.sql` EST DÉPLOYÉE**
    /// (vérifiée le 30-08 sur le compte de test : `ouvert: true`, la réserve
    /// `boosters_or` redescend de 47 à 46). L'appel FAIT descendre le compte
    /// de sachets ; un 404 ici ne serait plus « la migration manque » mais une
    /// vraie panne à lire dans le corps de l'erreur (skill woop-backend §6).
    /// Le commentaire « NON DÉPLOYÉE » qui vivait ici était périmé.
    @discardableResult
    func consommerBooster(legendaire: Bool) async -> String? {
        guard Self.possible else { return nil }
        do {
            let jwt = try await SupabaseSession.shared.token()
            let id = try await SacreServeur.ouvrirBooster(legendaire: legendaire,
                                                          jwt: jwt)
            await rafraichir()
            return id
        } catch {
            print("[économie] ouverture non enregistrée : \(error)")
            return nil
        }
    }

    // ── LA TRADUCTION D'UNE LIGNE DE JOURNAL ────────────────────────────

    private static func ligne(_ l: SacreServeur.LigneGain) -> GainCoffre {
        GainCoffre(id: identite(l),
                   date: l.quand,
                   montant: l.montant,
                   robe: l.genre == "booster"
                       ? (l.robe == "noire" ? .noire : .lune) : nil,
                   titre: titre(l))
    }

    private static func titre(_ l: SacreServeur.LigneGain) -> String {
        if l.genre == "booster" {
            switch l.motif {
            case "seance":     return "Booster de séance"
            case "chemin":     return "Booster du chemin"
            case "achat":      return "Booster acheté"
            case "legendaire": return "Booster légendaire"
            default:           return "Booster"
            }
        }
        switch l.motif {
        case "serie_faite":
            // ⚠️ On REMONTE aux séries depuis les pièces, avec le taux du
            // SERVEUR — pas avec une constante. C'est exactement la
            // duplication qu'on vient de tuer.
            let taux = max(EconomieWoop.shared.piecesParSerie, 1)
            let n = max(l.montant / taux, 1)
            return n == 1 ? "1 série" : "\(n) séries"
        case "retour_quotidien": return "Retour quotidien"
        case "chemin":           return "Récompense du chemin"
        case "piece_argent":     return "Pièce d'argent"
        default:                 return l.motif.isEmpty ? "Gain" : l.motif
        }
    }

    /// ⚠️ **UNE IDENTITÉ STABLE, ET C'EST UN BESOIN D'AFFICHAGE, PAS DE
    /// DONNÉES.** Le serveur ne rend pas d'identifiant de ligne. Un `UUID()`
    /// neuf à chaque relecture ferait rejouer l'apparition de TOUTE la liste à
    /// chaque rafraîchissement — la page « Mes gains » clignoterait. On la
    /// dérive donc du contenu, par FNV-1a : deux relectures de la même ligne
    /// rendent la même identité, et ça survit à un redémarrage (là où un
    /// `Hasher` de la bibliothèque standard est ressemé à chaque lancement).
    private static func identite(_ l: SacreServeur.LigneGain) -> UUID {
        let clef = "\(l.quand.timeIntervalSince1970)|\(l.genre)|\(l.motif)"
            + "|\(l.montant)|\(l.monnaie ?? "")|\(l.robe ?? "")"
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        var octets = [UInt8](repeating: 0, count: 16)
        for (i, b) in Array(clef.utf8).enumerated() {
            h = (h ^ UInt64(b)) &* 0x0000_0100_0000_01B3
            octets[i % 16] = octets[i % 16] ^ UInt8(truncatingIfNeeded: h >> 24)
        }
        for i in 0 ..< 8 {
            octets[i] = octets[i] ^ UInt8(truncatingIfNeeded: h >> (8 * UInt64(i)))
        }
        return UUID(uuid: (octets[0], octets[1], octets[2], octets[3],
                           octets[4], octets[5], octets[6], octets[7],
                           octets[8], octets[9], octets[10], octets[11],
                           octets[12], octets[13], octets[14], octets[15]))
    }
}
