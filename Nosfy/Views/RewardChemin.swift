import SwiftUI
import UIKit

// LA RÉCOMPENSE DU CHEMIN — de « Claim » à la carte gagnée.
//
// Le flux, dicté le 28-08 :
//   galet disponible → halo → Claim → card lune → on GRATTE la lune →
//   révélation → Coins OU Boosters → créditée → claimed
//   (le rangement du sticker Nosfy est mort le 20-09 : il verrouillait le
//   grattage, payé sur TestFlight 81.)
//
// ⚠️ **LA RÈGLE QUI COMMANDE TOUT** : la récompense est TIRÉE AU CLAIM, pas
// par l'animation. Le grattage ne décide RIEN — il révèle une décision déjà
// prise et déjà créditée. C'est ce qui interdit un tirage au front, un rejeu
// qui redonne, et une divergence entre l'écran et le compte. Le jour du
// backend, `TirageRecompense.tirer` devient un appel réseau et RIEN d'autre
// ne bouge : tout le reste de ce fichier ne lit que le résultat.

// MARK: - Le contrat

/// Ce que le serveur enverra, et que le front ne doit pas inventer.
enum TypeRecompense: String, Codable { case coins, boosters }

/// La monnaie. `black` est la monnaie rare des légendaires — son asset est
/// `piece-argent`, la planche du coffre (cerclage chrome froid, 72 cases :
/// elle TOURNE, là où l'or reste posé).
enum TypePiece: String, Codable { case standard, black }

enum TypeBooster: String, Codable { case orange, legendaryBlack }

enum RareteRecompense: String, Codable { case common, rare, legendary }

extension RecompenseTiree {
    /// LE TIRAGE, TEL QUE LE SERVEUR L'A RENDU (`tirer_noeud_chemin`) : le
    /// front ne fait que le traduire — jamais le corriger.
    static func depuisServeur(_ j: [String: Any]) -> RecompenseTiree? {
        guard let type = j["type"] as? String else { return nil }
        let rarete = RareteRecompense(rawValue: (j["rarete"] as? String) ?? "")
            ?? .common
        // LE RÉCIT DE LA CONVERSION (plan du 20-09, § 3.2 option A). La
        // réponse porte déjà ce que la conversion automatique a fait à
        // l'instant du crédit : `sachets_convertis` (enveloppe du 30-08,
        // `20260830210000:357-382`, remis à 0 au rejeu) et le coffre relu
        // APRÈS le déclencheur (`coffre.solde_or`, net ; `solde` à la racine
        // est aussi post-conversion). On les garde dans le tirage pour que
        // la card puisse dire « 147 gagnées → 2 sachets, 27 restent ».
        // ⚠️ Payé sur TestFlight 81 (19-09) : la card disait « +147, Added to
        // your balance » pendant que le coffre lisait 27 — rien ne racontait
        // les −200 de la conversion au moment du gain.
        let sachets = (j["sachets_convertis"] as? Int) ?? 0
        let coffre = j["coffre"] as? [String: Any]
        let solde = (coffre?["solde_or"] as? Int) ?? (j["solde"] as? Int)
        if type == "coins" {
            let monnaie = (j["monnaie"] as? String) ?? "yellow"
            return RecompenseTiree(type: .coins,
                                   coinType: monnaie == "silver" ? .black : .standard,
                                   montant: (j["montant"] as? Int) ?? 0,
                                   rarete: rarete,
                                   sachetsConvertis: sachets,
                                   soldeApres: solde)
        }
        let robes = (j["robes"] as? [String]) ?? []
        return RecompenseTiree(type: .boosters,
                               boosters: robes.map {
                                   $0 == "noire" ? .legendaryBlack : .orange
                               },
                               rarete: rarete,
                               sachetsConvertis: sachets,
                               soldeApres: solde)
    }
}

/// LE PAYLOAD — exactement les champs du contrat backend.
struct RecompenseTiree: Codable, Equatable {
    var type: TypeRecompense
    var coinType: TypePiece = .standard
    var montant: Int = 0
    var boosters: [TypeBooster] = []
    var rarete: RareteRecompense = .common
    /// Ce que la conversion 100 pièces → 1 sachet a fait à l'instant du crédit
    /// (20-09). OPTIONNELS : le journal `chemin.tirages` des installations
    /// d'avant ne les porte pas, et un `Decodable` synthétisé refuse une clé
    /// absente sur un champ non optionnel — un ancien tirage serait devenu
    /// illisible, et la card ne se rouvrirait plus jamais dessus.
    var sachetsConvertis: Int? = nil
    /// Le solde d'or NET, relu par le serveur après la conversion.
    var soldeApres: Int? = nil
    var isLegendaryCurrency: Bool { coinType == .black }
}

/// LES QUATRE ÉTATS (28-08, sa demande de documentation).
/// `locked` : les séances d'avant ne sont pas toutes faites — pas de halo.
/// `available` : le halo respire, « Claim » est offert.
/// `claiming` : l'aller-retour serveur — le bouton attend, et un échec
///   REVIENT à `available` ; jamais un galet mort.
/// `claimed` : créditée. La card se rouvre sans se re-gratter — et depuis le
///   20-09, un nœud crédité mais jamais gratté (`nonReveles`) se rouvre par
///   `rouvrir(id)`, au lancement ou depuis le galet.
enum EtatRecompense: String, Codable { case locked, available, claiming, claimed }

// MARK: - Le tirage

/// LE TIRAGE — provisoirement au front, avec les MÊMES champs et la MÊME
/// pitié que le serveur devra tenir. Il est PERSISTÉ par nœud : sans ça une
/// lune se re-réclame à chaque lancement (boosters infinis, la leçon déjà
/// payée sur `chemin.reclamees`).
///
/// Les taux, et pourquoi ceux-là (deux récompenses par chapitre, donc cinq
/// nœuds de chaque sur les cinq chapitres) :
///   · pièce noire à 6 %      → une tous les ~17 nœuds, soit tous les trois
///     chapitres et demi : assez rare pour être un événement, assez fréquente
///     pour qu'une joueuse régulière en voie une ;
///   · légendaire à 12 % cumulé → un tous les ~8 nœuds ;
///   · double légendaire à 1 % → un pour cent. C'est celui qu'on raconte.
///
/// ⚠️ **LA PITIÉ EST CE QUI MOTIVE**, plus que le taux lui-même : après 12
/// nœuds communs d'affilée sur une piste, le taux rare DOUBLE à chaque nœud
/// suivant jusqu'à ce qu'il tombe, puis se remet à zéro. Sans elle une série
/// sèche ressemble à une punition ; avec elle, à une montée. Le compteur vit
/// par utilisateur ET par piste — et côté serveur le jour venu, sinon il est
/// falsifiable.
enum TirageRecompense {
    static let seuilPitie = 12

    static func tirer(pieces: Bool, secs: Int) -> RecompenseTiree {
        let mult = pow(2.0, Double(max(0, secs - seuilPitie + 1)))
        if pieces {
            let p = min(1.0, 0.06 * mult)
            if Double.random(in: 0 ..< 1) < p {
                return RecompenseTiree(type: .coins, coinType: .black,
                                       montant: 1, rarete: .legendary)
            }
            return RecompenseTiree(type: .coins, coinType: .standard,
                                   montant: Int.random(in: 100 ... 200),
                                   rarete: .common)
        }
        let d = min(1.0, 0.01 * mult)
        if Double.random(in: 0 ..< 1) < d {
            return RecompenseTiree(type: .boosters,
                                   boosters: [.legendaryBlack, .legendaryBlack],
                                   rarete: .legendary)
        }
        let r = min(1.0, 0.11 * mult)
        if Double.random(in: 0 ..< 1) < r {
            return RecompenseTiree(type: .boosters,
                                   boosters: [.orange, .legendaryBlack],
                                   rarete: .rare)
        }
        return RecompenseTiree(type: .boosters, boosters: [.orange, .orange],
                               rarete: .common)
    }
}

// MARK: - L'état partagé

/// L'ÉTAT DE LA CARD — à la racine, comme la route : une card montée dans un
/// `fullScreenCover` masquerait la route et la pop-up booster (la loi payée
/// au jalon 1).
@MainActor
@Observable final class RewardCheminEtat {
    static let shared = RewardCheminEtat()

    /// Le nœud dont la card est ouverte, ou nil.
    var ouverte: Int? = nil
    /// Ce qui a été TIRÉ pour ce nœud — le front ne fait que le révéler.
    var tirage: RecompenseTiree? = nil
    /// L'animation de révélation a-t-elle déjà été jouée ? Rouvrir une card
    /// déjà grattée ne redemande pas le travail — et ne laisse surtout pas
    /// croire à un second tirage.
    var revele = false

    func oublierCompte() {
        ouverte = nil
        tirage = nil
        revele = false
        generationJournal += 1
    }

    /// LA GÉNÉRATION DU JOURNAL — une propriété STOCKÉE, donc SUIVIE par
    /// `@Observable` (le macro ne suit que le stocké). `journal` et `vues`
    /// sont calculés sur les préférences, invisibles à l'observation : sans
    /// ce compteur, la racine qui lit `nonReveles` dans son corps ne se
    /// ré-évaluait jamais après un grattage, et le panneau du galet
    /// proposait encore « Scratch » sur une card déjà révélée (relecture
    /// d'interfaces du 20-09). Bumpé à chaque écriture du journal ou des
    /// vues, et au changement de compte.
    private var generationJournal = 0

    /// Les tirages persistés, par id de nœud (en attendant le serveur).
    private var journal: [Int: RecompenseTiree] {
        get {
            guard let d = UserDefaults.standard.data(forKey: "chemin.tirages"),
                  let j = try? JSONDecoder().decode([Int: RecompenseTiree].self,
                                                    from: d) else { return [:] }
            return j
        }
        set {
            UserDefaults.standard.set(try? JSONEncoder().encode(newValue),
                                      forKey: "chemin.tirages")
            generationJournal += 1
        }
    }
    /// Les révélations déjà jouées.
    private var vues: Set<Int> {
        get { Set(UserDefaults.standard.array(forKey: "chemin.revele") as? [Int] ?? []) }
        set {
            UserDefaults.standard.set(Array(newValue).sorted(), forKey: "chemin.revele")
            generationJournal += 1
        }
    }
    /// LES NŒUDS TIRÉS MAIS JAMAIS RÉVÉLÉS (20-09, plan § 5.5) : présents
    /// dans le journal (le serveur a crédité au Claim), absents des vues (le
    /// grattage n'a jamais fini). Calculé à la demande sur les préférences,
    /// donc toujours juste après une écriture du journal ou des vues.
    /// ⚠️ Payé sur TestFlight 81 (19-09) : Claim → card → app quittée →
    /// au retour le galet disait « Reward already claimed » sans bouton, et
    /// le résultat des 147 pièces n'a jamais été montré. C'est cet ensemble
    /// que la Route lit pour offrir « Scratch », et que l'hôte lit au
    /// lancement pour rouvrir la card tout seul.
    var nonReveles: Set<Int> {
        _ = generationJournal   // la dépendance observable, voir plus haut
        return Set(journal.keys).subtracting(vues)
    }

    /// Les compteurs de pitié, une piste par type.
    private func secs(pieces: Bool) -> Int {
        UserDefaults.standard.integer(forKey: pieces ? "chemin.secs.coins"
                                                     : "chemin.secs.boosters")
    }
    private func poserSecs(_ n: Int, pieces: Bool) {
        UserDefaults.standard.set(n, forKey: pieces ? "chemin.secs.coins"
                                                    : "chemin.secs.boosters")
    }

    /// LE CLAIM — tire (ou relit) et CRÉDITE, puis ouvre la card. Le crédit
    /// est ici, pas à la fin du grattage : tuer l'app en plein scratch ne doit
    /// pas coûter la récompense.
    ///
    /// ⚠️⚠️ **JUSQU'AU 29-08, « CRÉDITE » ÉTAIT FAUX.** Cette fonction
    /// n'écrivait que `UserDefaults` — aucun appel serveur — pendant que la
    /// card affichait « Added to your balance ». L'écran mentait : le solde ne
    /// bougeait pas, et une réinstallation rendait tous les nœuds
    /// re-réclamables. Le tuyau existait pourtant des DEUX côtés
    /// (`OutboxGains.noeudChemin`, `reclamer_noeud_chemin` déployée le 28-08) :
    /// il ne manquait que cet appel.
    /// ⚠️ **DEPUIS LE 30-08, LE TIRAGE VIT AU SERVEUR** (`tirer_noeud_chemin`)
    /// : le client dit le nœud et la piste, le serveur tire, dérive la pitié
    /// de SON journal, écrit, et rend le résultat — rejoué, il rend le même.
    /// L'appel est synchrone : la révélation a besoin du résultat, c'est le
    /// prix de l'anti-triche, et l'état machine le prévoyait (« un échec
    /// REVIENT à available, jamais un galet mort ») : `false` = rien n'est
    /// réclamé, la card ne s'ouvre pas, le galet reste disponible. Sans
    /// serveur (maquette, `-demoData`) : le tirage local d'hier, dit comme tel.
    @discardableResult
    func reclamer(_ id: Int, pieces: Bool) async -> Bool {
        let generation = CompteEtat.shared.generationDonnees
        if let deja = journal[id] {
            tirage = deja
            revele = vues.contains(id)
        } else if EconomieWoop.possible {
            guard let t = await tirerAuServeur(id, pieces: pieces) else {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                return false
            }
            guard generation == CompteEtat.shared.generationDonnees,
                  !Task.isCancelled else { return false }
            journal[id] = t
            tirage = t
            revele = false
        } else {
            let n = secs(pieces: pieces)
            let t = TirageRecompense.tirer(pieces: pieces, secs: n)
            journal[id] = t
            poserSecs(t.rarete == .common ? n + 1 : 0, pieces: pieces)
            tirage = t
            revele = false
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.easeOut(duration: 0.34)) { ouverte = id }
        // ⚠️ **LA MAQUETTE N'ÉCRIT RIEN, NULLE PART** (relecture adverse
        // 30-08). Elle postait son tirage local dans l'outbox « pour plus
        // tard » ; sous `-demoData` la file GARDAIT l'entrée, et un lancement
        // suivant sans `-demoData` sur la même installation la vidait vers le
        // serveur — un tirage fait au client, sur des données de démo, écrit
        // sur le compte réel. Le serveur tire lui-même quand il est là ;
        // sans lui, on montre, et c'est tout.
        return true
    }

    /// ROUVRIR LA CARD SUR UN TIRAGE DÉJÀ STOCKÉ — AUCUN appel serveur : le
    /// tirage a été fait et crédité au Claim, il ne reste qu'à le montrer.
    /// C'est la branche `journal[id]` de `reclamer`, enfin joignable depuis
    /// l'écran : le galet « Scratch » de la Route et la reprise au lancement
    /// passent par ici. `false` si le journal ne connaît pas le nœud — la
    /// Route retombe alors sur son « Claim » ordinaire.
    ///
    /// Les annonces sont RETENUES comme au Claim (`retenirPourGalet`) : la
    /// dalle « +N pièces » ne doit pas défiler pendant qu'on gratte ; `fermer`
    /// les libère. Si le serveur a déjà rendu et acquitté ces événements à un
    /// passage précédent (le toaster a défilé tout seul), il n'y a plus rien
    /// à retenir : la card se rouvre, et c'est tout.
    @discardableResult
    func rouvrir(_ id: Int) -> Bool {
        guard let deja = journal[id] else { return false }
        tirage = deja
        revele = vues.contains(id)
        EconomieWoop.shared.retenirPourGalet = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.easeOut(duration: 0.34)) { ouverte = id }
        return true
    }

    /// L'aller-retour : le tirage serveur, puis la relecture des soldes.
    private func tirerAuServeur(_ id: Int, pieces: Bool) async -> RecompenseTiree? {
        let generation = EconomieWoop.shared.generationCartes
        do {
            let jwt = try await SupabaseSession.shared.token()
            guard generation == EconomieWoop.shared.generationCartes else { return nil }
            EconomieWoop.shared.retenirPourGalet = true
            let j = try await SacreServeur.tirerNoeudChemin(id, pieces: pieces,
                                                            jwt: jwt)
            guard generation == EconomieWoop.shared.generationCartes else { return nil }
            if let recu = RecuRecompense(j) { EconomieWoop.shared.recevoir(recu) }
            await EconomieWoop.shared.rafraichir()
            return RecompenseTiree.depuisServeur(j)
        } catch {
            guard generation == EconomieWoop.shared.generationCartes else { return nil }
            EconomieWoop.shared.retenirPourGalet = false
            EconomieWoop.shared.libererEvenements()
            print("[chemin] tirage serveur échoué : \(error)")
            return nil
        }
    }

    // `poster(noeud:)` — l'enregistrement d'un tirage CLIENT par l'outbox —
    // est mort le 30-08 : plus aucun émetteur. `OutboxGains.noeudChemin`
    // reste pour vider les entrées déjà en file d'une version antérieure ;
    // au serveur, `reclamer_noeud_chemin` ne croit plus ses montants (elle
    // délègue à `tirer_noeud_chemin`).

    /// LE BANC — `-rewardChemin <cas>` ouvre la card sur un tirage FORCÉ.
    /// Sans lui, ces écrans ne se jugent qu'au doigt sur un galet disponible,
    /// c'est-à-dire jamais au simulateur.
    /// Cas : `coins` · `black` · `boosters` · `rare` · `legendary`.
    /// ⚠️ Un `R` suffixé (`boostersR`) ouvre la card **DÉJÀ GRATTÉE**. Sans lui
    /// on ne juge la composition qu'après avoir usé le doigt sur 55 % d'une
    /// grille 18 × 26 — donc jamais à la capture, qui ne gratte pas.
    func banc(_ cas: String) {
        let ouvert = cas.hasSuffix("R")
        let cas = ouvert ? String(cas.dropLast()) : cas
        switch cas {
        case "black":
            tirage = RecompenseTiree(type: .coins, coinType: .black,
                                     montant: 1, rarete: .legendary)
        case "boosters":
            tirage = RecompenseTiree(type: .boosters,
                                     boosters: [.orange, .orange])
        case "rare":
            tirage = RecompenseTiree(type: .boosters,
                                     boosters: [.orange, .legendaryBlack],
                                     rarete: .rare)
        case "legendary":
            tirage = RecompenseTiree(type: .boosters,
                                     boosters: [.legendaryBlack, .legendaryBlack],
                                     rarete: .legendary)
        default:
            // Le récit de la conversion, pour le voir au sim : 160 gagnées →
            // 1 sachet, 60 restent. Un banc, pas un fait.
            tirage = RecompenseTiree(type: .coins, montant: 160,
                                     sachetsConvertis: 1, soldeApres: 60)
        }
        revele = ouvert
        withAnimation(.easeOut(duration: 0.34)) { ouverte = -1 }
    }

    func marquerRevele() {
        guard let id = ouverte else { return }
        vues.insert(id)
        revele = true
    }

    func fermer() {
        // LA SECONDE QUITTANCE — la capsule de la maison redescend avec le
        // compte qui roule, au-dessus de la route. La pastille dans la card dit
        // « c'est porté au compte » ; celle-ci le REJOUE à l'endroit où le
        // solde vit, pour que le geste se termine là où il compte.
        // ⚠️ TRANCHÉ LE 30-08 : « la card à gratter ET une dalle après, robe
        // pièces ou booster ». Avant, un tirage en sachets ne posait RIEN (la
        // dalle n'avait qu'une robe). L'événement fait la robe : pièces, pièce
        // d'argent (piste pièces, monnaie silver), ou sachet(s).
        // ⚠️ 20-09 : la dalle de la MAQUETTE ne part qu'une card RÉVÉLÉE.
        // « Scratch later » rouvre la même card au prochain passage ; sans
        // ce garde, chaque fermeture sans grattage annonçait le gain une
        // fois de plus, et le racontait AVANT qu'il soit vu. Côté serveur,
        // les événements sont acquittés au premier affichage : ils ne
        // reviennent pas, le garde n'est pas nécessaire là.
        let annonce: Annonce? = {
            guard !EconomieWoop.possible, revele, let t = tirage else { return nil }
            switch t.type {
            case .coins:
                return t.isLegendaryCurrency ? .argent(t.montant) : .pieces(t.montant)
            case .boosters:
                return .sachet(max(t.boosters.count, 1))
            }
        }()
        withAnimation(.easeOut(duration: 0.28)) { ouverte = nil }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.tirage = nil
            EconomieWoop.shared.retenirPourGalet = false
            EconomieWoop.shared.libererEvenements()
            guard let annonce else { return }
            FileAnnonces.shared.pousser(annonce)
        }
    }
}

// MARK: - L'hôte

/// L'HÔTE À LA RACINE — le voile, la card, et rien d'autre.
struct RewardCheminHote: View {
    @Bindable var etat: RewardCheminEtat

    var body: some View {
        // ⚠️ Le déclencheur du banc vit sur une vue TOUJOURS montée : posé sur
        // `contenu`, qui est vide tant que la card est fermée, son `onAppear`
        // ne serait jamais appelé.
        ZStack {
            Color.clear.frame(width: 1, height: 1).allowsHitTesting(false)
            contenu
        }
        .onAppear {
            let a = CommandLine.arguments
            guard let i = a.firstIndex(of: "-rewardChemin") else { return }
            let cas = i + 1 < a.count ? a[i + 1] : "coins"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                etat.banc(cas)
            }
        }
        .task { await reprendreNonRevele() }
    }

    /// LA REPRISE (20-09, plan § 5.5) : ce qu'elle voit au lancement, si un
    /// tirage a été payé au Claim mais jamais gratté (app tuée, « Scratch
    /// later », réponse perdue) — la home se pose, puis la card se rouvre
    /// d'elle-même sur le tirage stocké, sans appel serveur. Le plus ancien
    /// nœud d'abord ; les suivants se retrouvent par le galet.
    ///
    /// ⚠️ Payé sur TestFlight 81 (19-09) : au retour, le toaster « +147 »
    /// défilait tout seul et le galet disait « already claimed » sans bouton.
    /// La rétention des annonces est posée AVANT la pause de 1,2 s : la
    /// relecture du coffre au lancement rend les événements non acquittés,
    /// et il faut qu'elle les trouve déjà retenus, pas la card déjà ouverte.
    /// Jamais pendant un banc (`-rewardChemin`, `-rewardAuto`) : ils posent
    /// leur propre card.
    @MainActor private func reprendreNonRevele() async {
        let a = CommandLine.arguments
        guard !a.contains("-rewardChemin"), !a.contains("-rewardAuto") else { return }
        guard etat.ouverte == nil, let id = etat.nonReveles.min() else { return }
        EconomieWoop.shared.retenirPourGalet = true
        try? await Task.sleep(for: .seconds(1.2))
        // Elle a touché un galet pendant la pause : `reclamer` tient la card,
        // et `fermer` libérera la rétention posée ici.
        guard etat.ouverte == nil else { return }
        // Le journal a pu être vidé pendant la pause (changement de compte) :
        // rien à rouvrir, et la rétention posée plus haut est rendue.
        guard !Task.isCancelled, etat.rouvrir(id) else {
            EconomieWoop.shared.retenirPourGalet = false
            EconomieWoop.shared.libererEvenements()
            return
        }
    }

    /// L'or du WIN sous la card — sa vraie vidéo, `story-macro-or`, en
    /// `plusLighter`, débordante et posée au pied de l'écran. Son fondu est
    /// CUIT dans le fichier (un scrim numpy) : jamais un masque par image sur
    /// une couche vidéo.
    /// En robe froide, une nappe d'argent PEINTE — désaturer une vidéo par
    /// image est un filtre, et un filtre par image se paie.
    @ViewBuilder private func lueurDeScene(froide: Bool) -> some View {
        GeometryReader { g in
            if froide {
                RadialGradient(
                    colors: [Color(red: 0.84, green: 0.92, blue: 1.0).opacity(0.22),
                             Color(red: 0.50, green: 0.60, blue: 0.78).opacity(0.07),
                             .clear],
                    center: .init(x: 0.5, y: 1.02),
                    startRadius: 0, endRadius: g.size.width * 0.95)
                    .blendMode(.plusLighter)
            } else {
                let mw = g.size.width * 1.15
                CalqueVideo(nom: "story-macro-or",
                            pose: "story-macro-or-poster", rate: 1)
                    .frame(width: mw, height: mw * 1352 / 1500)
                    .frame(width: g.size.width, height: g.size.height,
                           alignment: .bottom)
                    .offset(y: mw * 1352 / 1500 * 0.42)
                    .blendMode(.plusLighter)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    /// ⚠️ BANC DE COMPARAISON — `-rewardChemin refneon` monte le VRAI composant
    /// (`RewardPopup` robe `.neon`, celui de sa capture) au lieu du mien. C'est
    /// le seul instrument honnête : deux captures, même simulateur, même
    /// fenêtre de mesure. Sans lui je compare une capture à un souvenir.
    private var comparaison: Bool {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: "-rewardChemin"), i + 1 < a.count
        else { return false }
        return a[i + 1] == "refneon"
    }

    @ViewBuilder private var contenu: some View {
        if comparaison {
            RewardPopup(count: 4, title: "Congratulations",
                        subtitle: "you've completed your training!",
                        unit: "", style: .neon, onClose: {})
        } else if etat.ouverte != nil, let t = etat.tirage {
            ZStack {
                // ⚠️ 20-09, sa capture TestFlight : à 0,62 la Home restait
                // lisible derrière (« Bonjour Kathryn… », et la pilule « tire
                // pour commencer » juste sous « Fermer ») — la card semblait
                // posée sur un écran encore vivant. Le noir monte : la card et
                // sa lueur seules, la Home n'est plus qu'une ombre.
                Color.black.opacity(0.88)
                    .ignoresSafeArea()
                    .transition(.opacity)
                // ⚠️ **LA LUEUR VIT ICI, DERRIÈRE LA CARD, AU BAS DE L'ÉCRAN**
                // (28-08, sur sa capture de référence). Dans le WIN, `pillsOr`
                // est un élément de la SCÈNE : la card, elle, n'est qu'un
                // dégradé sobre. Je l'avais collée à l'intérieur de la card,
                // qui rendait riche-et-plate. La profondeur vient de ce que la
                // lumière est DERRIÈRE l'objet, pas dedans.
                lueurDeScene(froide: t.rarete == .legendary)
                CardRecompense(tirage: t, dejaRevele: etat.revele,
                               onRevele: { etat.marquerRevele() },
                               onFermer: { etat.fermer() })
                    .transition(.scale(scale: 0.88).combined(with: .opacity))
            }
        }
    }
}
