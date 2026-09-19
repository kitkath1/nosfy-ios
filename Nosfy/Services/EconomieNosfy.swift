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
    var boosters: Int { serveur ? boostersServeur : (Self.maquetteActive ? maquetteBoosters : 0) }
    private(set) var boostersServeur = 0
    /// `-sansSachet` : la maquette naît SANS sachet — le barreau du panneau
    /// du géant à vide (la jauge, « Verrouillé »), 15-09.
    var maquetteBoosters =
        EconomieWoop.maquetteActive && !CommandLine.arguments.contains("-sansSachet") ? 1 : 0

    /// Les sachets NOIRS ouvrables. ⚠️ Côté serveur, c'est le solde d'argent
    /// (le sachet noir naît au claim) PLUS le noir déjà payé, ouvert et pas
    /// encore scellé (`noirs_ouverts`, au plus un). Sans ce second terme
    /// (relecture adverse 30-08) : la pièce débitée, la forge qui ne scelle
    /// pas (app tuée pendant la peinture, 500, timeout), le compte à 0, la
    /// porte du manège FERMÉE — et la reprise que le serveur sait faire
    /// n'était plus jamais déclenchée. Le sachet payé restait dans le vide.
    var boostersNoirs: Int { serveur ? noirsPossedes + argent / max(prixNoir, 1) : (Self.maquetteActive ? maquetteNoirs : 0) }
    private(set) var noirsPossedes = 0
    private(set) var prixNoir = 1
    private var versionInventaire: Int64 = -1
    private(set) var generationCartes = UUID()
    private(set) var proprietaireCartes: String?
    var retenirPourGalet = false
    private var evenementsRetenus: [EvenementGain] = []
    private(set) var noirsOuverts = 0
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
    /// Ce qu'une LONGUEUR de piscine rapporte, et le plafond d'une séance
    /// (15-09, `reward_rules.pieces_par_longueur` · `cardio_piscine_max`).
    /// Les mêmes défauts que la base ; posés par `etat_coffre` dès qu'il les
    /// rend. La fiche les DIT au « + » — le serveur PAIE à la clôture.
    private(set) var piecesParLongueur = 20
    private(set) var piscineMax = 300
    /// Le journal, du plus récent au plus ancien.
    private(set) var journal: [GainCoffre] = []

    // ── LE VERSEMENT QUOTIDIEN, pour l'horloge du coffre (§29.7) ────────
    //
    // Trois lectures, DÉCODÉES du serveur, jamais calculées ici : le montant
    // (`pieces_retour_quotidien`, depuis 20260830220000), « il est dû »
    // (`retour_disponible`) et le prochain minuit de la maison
    // (`retour_prochain`) — M1 `20260830210000_conversion_jour_flamme.sql`,
    // POSÉE le 30-08 à 18:48 et branchée ici le soir même (§29.11 ⑧).
    //
    // ⚠️ Clé absente = valeur INCHANGÉE, jamais un défaut (deux dialectes,
    // `SacreServeur.swift:120`) : sur une base d'avant la migration,
    // `prochainRetour` reste nil et le coffre ne montre PAS d'horloge —
    // mieux qu'une heure inventée. Sans serveur, la maquette pose la sienne.
    private(set) var piecesRetourQuotidien = 10
    private(set) var retourDisponible = false
    private(set) var prochainRetour: Date?
    /// FIN DE SÉANCE (16-09, bug Kathryn : « pas de toaster final ni de pièces
    /// dans la story au HIIT »). Les dalles de la réponse de `cloturer_seance`
    /// (cardio, sachet, argent) partaient DÈS la réponse — donc SOUS la story de
    /// fin, invisibles. Quand une story de fin va s'ouvrir, `terminerSeance` lève
    /// ce drapeau : les dalles attendent, et `enchainerApresStory` les vide APRÈS
    /// la story (comme les pièces de muscu). Si la réponse arrive après la story,
    /// le drapeau est déjà retombé → elles partent tout de suite (home visible).
    var pousserApresStory = false
    private var pileFinSeance: [Annonce] = []
    /// Le gain cardio de la dernière clôture — la story le DIT (le workout ne le
    /// connaît pas : c'est le barème du serveur, pas des séries × 20).
    private(set) var dernierGainCardio = 0
    /// LA CLÔTURE A RÉPONDU (16-09) : passe à `true` dès qu'une réponse de
    /// `cloturer_seance` est appliquée — quel que soit le gain (0 pièce au tapis
    /// trop lent compte AUSSI comme « répondu »). La story de fin d'un cardio
    /// ATTEND ce drapeau avant de rouler ses pièces (sinon, sur un vrai réseau,
    /// elle s'ouvrait avant la réponse et affichait « 0 » — bug Kathryn 16-09,
    /// invisible au simulateur qui répond en millisecondes). Remis à `false` au
    /// début de chaque fin de séance (`debutFinSeance`).
    private(set) var clotureRepondue = false
    /// LES FAITS DE LA DERNIÈRE CLÔTURE (17-09, b-st-top) : ce que la séance A
    /// ÉTÉ, estampillé par le serveur (`calculer_faits_seance` : `top_muscu` /
    /// `top_cardio` = record battu sur 7 jours, `double_jour` = 2ᵉ séance du
    /// jour). La story de fin les LIT pour ouvrir la bonne page (TOP / ×2) au
    /// lieu d'un drapeau de banc. Vide au début de chaque fin de séance.
    private(set) var dernierFaits: [SacreServeur.Fait] = []
    /// Le jour de la maison (Europe/Paris), tel que le serveur le dit.
    private(set) var jour: String?

    // ── LA FLAMME 🔥 (30-08 : « jours d'affilée, comptée au serveur, SANS
    //    bonus ») — dérivée de `workouts.ended_at`, jamais stockée, rien à
    //    calculer ici : on l'affiche, c'est tout.
    private(set) var flammeJours = 0
    private(set) var flammeAujourdhui = false

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
        // ⚠️ La maquette a une HORLOGE : un minuit fictif à six heures, posé
        // UNE fois (chaque relecture de la home repasse ici — la remettre à
        // zéro ferait reculer la barre). Sans serveur possible seulement :
        // avec un compte, l'heure vient du serveur ou n'existe pas.
        if !Self.possible, prochainRetour == nil {
            prochainRetour = Date().addingTimeInterval(6 * 3600)
        }
    }

    // ── LA LECTURE ──────────────────────────────────────────────────────

    /// ⚠️ **LES MÊMES GARDES QUE L'OUTBOX, ET C'EST VOULU** : les données de
    /// démonstration ne touchent jamais un vrai compte, et sans configuration
    /// on ne tente rien (« aucun 404 dans les logs d'une app dont le backend
    /// n'est pas encore là »). Une seule règle d'accès au serveur, pas deux.
    private static var maquetteActive: Bool {
        CommandLine.arguments.contains { ["-demoData", "-boosterLab", "-coffreLab", "-sacreLab", "-sacreNoir"].contains($0) }
    }

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
        let generation = generationCartes
        defer { if generation == generationCartes { chargement = false } }
        do {
            let jwt = try await SupabaseSession.shared.token()
            let owner = try await SupabaseSession.shared.currentUserID()
            let e = try await SacreServeur.etatCoffre(jwt: jwt)
            guard generation == generationCartes else { return }
            proprietaireCartes = owner.lowercased()
            appliquer(e)
            if let events = try? await CartesServeur.evenements(jwt: jwt), generation == generationCartes {
                annoncer(events)
            }
            if avecJournal {
                let lignes = try await SacreServeur.historique(jwt: jwt)
                guard generation == generationCartes else { return }
                journal = lignes.map(Self.ligne)
            }
            derniereErreur = nil
        } catch {
            derniereErreur = error.localizedDescription
            print("[économie] lecture impossible : \(error)")
        }
    }

    /// OUBLIER LA PERSONNE (14-09, plan compte C2 — `Compte.effacerToutCeQuiEstAElle`) :
    /// tout ce que le serveur avait rendu retombe à zéro, `serveur` redevient
    /// faux — le prochain compte repart de la maquette, jamais des soldes de
    /// la précédente. Les constantes de la maison (prix, pièces par série)
    /// restent : elles ne sont à personne.
    func oublier() {
        generationCartes = UUID()
        proprietaireCartes = nil
        chargement = false
        versionInventaire = -1
        noirsPossedes = 0
        evenementsRetenus.removeAll()
        pileFinSeance.removeAll()
        pousserApresStory = false
        retenirPourGalet = false
        or = 0
        argent = 0
        boostersServeur = 0
        maquetteBoosters = 0
        maquetteNoirs = 0
        seanceStory = nil
        clotureRepondue = false
        dernierFaits = []
        dernierGainCardio = 0
        noirsOuverts = 0
        reste = 0
        journal = []
        retourDisponible = false
        prochainRetour = nil
        jour = nil
        flammeJours = 0
        flammeAujourdhui = false
        serveur = false
        derniereErreur = nil
    }

    func appliquer(_ e: SacreServeur.EtatCoffre) {
        if let v = e.version {
            guard v >= versionInventaire else { return }
            versionInventaire = v
        }
        noirsPossedes = e.boostersNoirs ?? e.noirsOuverts
        prixNoir = e.prixNoir
        or = e.soldeOr
        argent = e.soldeArgent
        // `boosters_or` compte AUSSI l'orange ouvert non scellé des six
        // dernières heures (la fenêtre de reprise d'`ouvrir_booster`) : la
        // porte reste ouverte, l'engagement suivant retombe sur le même id.
        boostersServeur = e.boostersOr
        noirsOuverts = e.noirsOuverts
        reste = e.reste
        prixBooster = e.prixBooster
        piecesParSerie = e.piecesParSerie
        // Les clés du 30-08 soir : POSÉES si présentes, INCHANGÉES sinon
        // (une base d'avant la migration ne les rend pas — deux dialectes).
        if let j = e.jour { jour = j }
        if let d = e.retourDisponible { retourDisponible = d }
        if let p = e.retourProchain { prochainRetour = p }
        if let m = e.piecesRetourQuotidien { piecesRetourQuotidien = m }
        if let f = e.flammeJours { flammeJours = f }
        if let a = e.flammeAujourdhui { flammeAujourdhui = a }
        if let l = e.piecesParLongueur { piecesParLongueur = l }
        if let m = e.piscineMax { piscineMax = m }
        serveur = true
    }

    /// LE RÈGLEMENT D'UNE SÉANCE RÉPOND DÉJÀ TOUT — ON NE REDEMANDE RIEN.
    ///
    /// ⚠️ `cloturer_seance` rend `solde`, `reste`, `argent` et `prix_booster`
    /// depuis le 29-08, précisément pour qu'une annonce n'ait pas besoin de
    /// plusieurs sources. Refaire un aller-retour ici, ce serait recréer le
    /// défaut que cette réponse a été élargie pour supprimer.
    func appliquer(_ c: SacreServeur.ClotureSeance) {
        if let recu = c.recu, let owner = proprietaireCartes,
           owner != recu.userId.lowercased() { return }
        ReglementSeance.shared.recevoir(c)
        if let recu = c.recu {
            recevoir(recu)
            if seanceStory == nil || seanceStory == c.workoutId {
                clotureRepondue = true
                dernierFaits = c.faits
                dernierGainCardio = c.piecesCardio
            }
            return
        }
        // La clôture a répondu (avant tout early return) : la story de fin d'un
        // cardio n'attend plus que ce signal pour rouler ses pièces.
        clotureRepondue = true
        // Les faits estampillés (top / ×2) — la story les lit pour sa page
        // d'ouverture. Ils valent même au rejeu (un estampillage, jamais recalculé).
        dernierFaits = c.faits
        or = c.solde
        reste = c.reste
        prixBooster = c.prixBooster
        // ⚠️ L'ARGENT SE POSE, IL NE S'INCRÉMENTE PLUS (relecture adverse du
        // 30-08 soir) : une réponse appliquée deux fois — reprise, rejeu de
        // l'outbox — comptait la pièce deux fois jusqu'au prochain
        // `etat_coffre`. Le serveur rend `solde_argent` depuis 20260830210000 ;
        // sur une base d'avant, on garde l'ancien geste, sans le rejeu.
        if let s = c.soldeArgent { argent = s }
        else if c.argent, !c.rejeu { argent += 1 }
        if c.boosterNeuf { boostersServeur += 1 }
        // Les sachets nés de ce crédit (100 pièces → 1) : ils comptent, et
        // ils se DISENT — une dalle par événement (plan §3).
        boostersServeur += c.sachetsConvertis
        serveur = true
        var pile: [Annonce] = []
        // LE CARDIO (15-09) : seul le serveur connaît son montant (le
        // barème). Il se dit ICI, à la réponse — jamais avant, et jamais
        // sur un rejeu (le stocké n'est pas un gain neuf). Le sachet que le
        // cardio seul a accordé (aucune série de muscu) se dit avec.
        // LA STORY AFFICHE TOUJOURS LE BARÈME (16-09) : le montant cardio que le
        // serveur renvoie (`pieces_cardio_seance`, recalculé depuis les phases)
        // vaut MÊME AU REJEU. Le poser hors de la garde `!rejeu` — sinon une
        // séance rejouée (outbox, kill, reprise) affichait 0 à la story alors que
        // le serveur connaît le montant. On ne RE-NOTIFIE (dalle + toaster) que si
        // c'est FRAIS (rien de neuf à annoncer sur un rejeu).
        if c.piecesCardio > 0 { dernierGainCardio = c.piecesCardio }
        if c.piecesCardio > 0, !c.rejeu, !c.cardioRejeu {
            pile.append(.cardio(c.piecesCardio))
            print("[flow] cardio payé : \(c.piecesCardio) pièces (bonus \(c.bonusProgres)) · total \(c.piecesTotal) · détail \(c.cardioDetail)")
        }
        // Le sachet du cardio seul : `_brut` ne l'a pas compté dans
        // `booster_neuf` (0 série) — il se compte et se dit ici, une fois.
        if c.sachetCardio, !c.rejeu, !c.cardioRejeu, !c.boosterNeuf {
            boostersServeur += 1
            pile.append(.sachet(1))
        }
        if c.sachetsConvertis > 0 { pile.append(.sachet(c.sachetsConvertis)) }
        if c.argent { pile.append(.argent(1)) }
        guard !pile.isEmpty else { return }
        // Sous une story de fin : on GARDE les dalles (elles passeraient sous la
        // story) ; enchainerApresStory les vide APRÈS. Sinon (rejeu tardif,
        // etat_coffre hors séance) : tout de suite.
        if pousserApresStory { pileFinSeance.append(contentsOf: pile) }
        else { FileAnnonces.shared.pousser(pile) }
    }

    /// AU DÉBUT D'UNE FIN DE SÉANCE (`terminerSeance`) : on garde les dalles de
    /// la réponse pour APRÈS la story, ET on repart d'un gain cardio à zéro —
    /// sinon la story d'une séance de MUSCU afficherait le cardio de la séance
    /// d'avant (`dernierGainCardio` persiste). La clôture le remettra si cardio.
    private var seanceStory: String?
    func debutFinSeance(workoutId: UUID? = nil) {
        seanceStory = workoutId?.uuidString.lowercased()
        pousserApresStory = true
        dernierGainCardio = 0
        clotureRepondue = false
        dernierFaits = []
        pileFinSeance.removeAll()
    }

    /// APRÈS LA STORY DE FIN — vide les dalles gardées (cardio, sachet, argent)
    /// pour qu'elles se voient sur la home. Retombe le drapeau : une réponse
    /// serveur plus tardive repartira alors tout de suite.
    func viderFinSeance() {
        pousserApresStory = false
        libererEvenements()
        guard !pileFinSeance.isEmpty else { return }
        FileAnnonces.shared.pousser(pileFinSeance)
        pileFinSeance.removeAll()
    }

    /// Un versement de connexion réglé : le solde est à jour sans relecture.
    func appliquer(_ r: SacreServeur.RetourQuotidien) {
        if let recu = r.recu { recevoir(recu); return }
        or = r.solde
        reste = max(or, 0) % max(prixBooster, 1)
        // Crédité OU « déjà pris » : dans les deux cas le jour est réglé.
        retourDisponible = false
        if let j = r.jour { jour = j }
        boostersServeur += r.sachetsConvertis
        if r.sachetsConvertis > 0 {
            FileAnnonces.shared.pousser(.sachet(r.sachetsConvertis))
        }
        serveur = true
    }

    /// LE CLAIM DU WELCOME BACK — tranché le 30-08 : les +10 partent AU TAP,
    /// et la dalle « +10 » se dit tout de suite (Q8 : le montant est local, le
    /// journal rattrape ; si le serveur dit « déjà pris » — un autre appareil —
    /// rien ne s'affiche de plus, et `etat_coffre` remet le solde d'aplomb au
    /// prochain premier plan).
    func reclamerRetour() {
        guard retourDisponible else { return }
        retourDisponible = false
        Task { await SacreServeur.reclamerRetourQuotidien() }
    }

    // ── LES DÉPENSES ────────────────────────────────────────────────────
    //
    // ⚠️⚠️ **L'ACHAT EST MORT LE 30-08 AU SOIR (Q9).** `acheterBooster()` —
    // le seul débit de pièces de l'app, `claim_booster` côté serveur — n'a
    // plus d'objet : la conversion automatique (20260830210000) fait naître
    // un sachet à chaque tranche de 100, et le solde jaune ne dépasse plus
    // jamais 99. Un achat ne pouvait plus que mentir « bought for 100 coins »,
    // et la fonction est RÉVOQUÉE au serveur (403). « Ouvrir » ouvre un sachet
    // qui existe déjà ; à 0 sachet, le pied dit « Locked » et ne fait rien.

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
        let generation = generationCartes
        do {
            let jwt = try await SupabaseSession.shared.token()
            // Deux stocks : noir offert d’abord, argent seulement sans noir possédé.
            let owner = try await SupabaseSession.shared.currentUserID()
            guard generation == generationCartes else { return nil }
            let operation = CartesServeur.operation(user: owner, noir: legendaire)
            let resultat = try await CartesServeur.objet("preparer_booster", jwt: jwt,
                corps: ["p_operation": operation.uuidString.lowercased(), "p_legendaire": legendaire])
            guard generation == generationCartes, let j = resultat as? [String: Any] else { return nil }
            proprietaireCartes = owner.lowercased()
            if let recu = RecuRecompense(j) { recevoir(recu) }
            return j["booster_id"] as? String
        } catch {
            print("[économie] ouverture non enregistrée : \(error)")
            return nil
        }
    }

    func recevoir(_ recu: RecuRecompense) {
        guard proprietaireCartes == nil || proprietaireCartes == recu.userId.lowercased() else { return }
        proprietaireCartes = recu.userId.lowercased()
        appliquer(recu.coffre)
        annoncer(recu.evenements)
    }

    private func annoncer(_ events: [EvenementGain]) {
        let connus = Set(evenementsRetenus.map(\.id))
        let nouveaux = events.filter { !connus.contains($0.id) && $0.userId.lowercased() == proprietaireCartes }
        if pousserApresStory || retenirPourGalet { evenementsRetenus.append(contentsOf: nouveaux) }
        else { FileAnnonces.shared.pousser(nouveaux) }
    }

    func libererEvenements() {
        guard !pousserApresStory, !retenirPourGalet else { return }
        FileAnnonces.shared.pousser(evenementsRetenus)
        evenementsRetenus.removeAll()
    }

    // ── LA TRADUCTION D'UNE LIGNE DE JOURNAL ────────────────────────────

    private static func ligne(_ l: SacreServeur.LigneGain) -> GainCoffre {
        GainCoffre(id: l.id ?? identite(l),
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
            case "conversion": return "100 pièces → un sachet"
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
