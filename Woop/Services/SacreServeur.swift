import Foundation

// MARK: - Le client des RPC du Sacre (la réserve noire)

/// LE CÔTÉ APP DU BOOSTER NOIR. Deux appels, pas un de plus :
///
/// - `etatCoffre()` — tout le pied du coffre en un appel (les deux soldes, les
///   sachets ouvrables, le report vers le prochain booster, et les prix).
/// - `soldeArgent()` — combien de pièces d'argent, donc combien de boosters
///   légendaires ouvrables. **La réserve d'argent n'est PAS un stock de
///   sachets** (le sachet naît au claim) : la pill du profil compte des PIÈCES.
/// - `claimLegendaire()` — débite une pièce noire et réserve le sachet. Elle
///   rend son `id`, qui part ensuite à `ForgeServeur.tirer(boosterId:)`.
///
/// ⚠️ **CE COMMENTAIRE DISAIT LE CONTRAIRE JUSQU'AU 28-08 AU SOIR** — « les
/// tables n'existent pas en base, la migration est prête et NON APPLIQUÉE ».
/// **C'est faux depuis :** les trois migrations sont posées et vérifiées
/// (`20260828120000` · `20260828160000` · `20260828190000`), et chaque
/// fonction a été appelée en HTTP pour s'assurer qu'elle répond.
///
/// ⚠️ **CE QUI RESTE VRAI : RIEN DANS L'APP NE LES APPELLE ENCORE**, et c'est
/// l'étape 1 assumée du branchement (`docs/screens/coffre-rewards.md` §6.5) —
/// **écrire avant de lire**, parce qu'un branchement qui ne se voit pas est un
/// branchement qu'on peut défaire. Le drapeau `-sacreServeur` reste
/// l'interrupteur.
///
/// ⚠️ Et la règle de la maison ne change pas : rien ne part sur Supabase sans
/// Kathryn, **par la CLI, jamais par le MCP** (celui de la session pointe sur
/// un autre projet).
///
/// Ce fichier existe pour que le contrat soit ÉCRIT des deux côtés le jour où
/// elle pousse : le drapeau `-sacreServeur` sera l'interrupteur qui fait
/// passer `SacreEtat` de la maquette (compteur en mémoire) au vrai solde.
///
/// La garantie qui compte, et elle est côté serveur : `claim_booster_legendaire`
/// est IDEMPOTENTE — un double tap, un réseau qui coupe, un retour arrière
/// rendent la MÊME réserve. Deux appels simultanés ne peuvent pas dépenser
/// deux pièces : un index unique partiel n'autorise qu'une réserve noire non
/// scellée par utilisateur, et la fonction attrape la violation pour rendre
/// celle qui existe déjà.
enum SacreServeur {
    /// Le drapeau de bascule : tant qu'il est absent, l'app vit sur la
    /// maquette et n'appelle RIEN (aucun 404 dans les logs d'une app dont le
    /// backend n'est pas encore là).
    static let actif = CommandLine.arguments.contains("-sacreServeur")

    enum Erreur: LocalizedError {
        case http(Int, String), reponse
        var errorDescription: String? {
            switch self {
            case .http(let code, let m): return "serveur \(code) : \(m)"
            case .reponse: return "réponse illisible"
            }
        }
    }

    /// TOUT LE PIED DU COFFRE EN UN SEUL APPEL — et c'est la garantie que le
    /// coffre et le profil ne peuvent pas afficher deux vérités : un nombre
    /// montré à deux endroits n'a le droit d'exister qu'une fois.
    ///
    /// ⚠️ Les deux monnaies n'ont pas la même forme, et la réponse le dit :
    /// l'or ACCUMULE (solde + reste 0-99 + prix), l'argent TOMBE (un solde,
    /// et rien d'autre — pas de progression, donc jamais le *pity timer*,
    /// qui rendrait la rareté farmable). Sur la page argent, solde et
    /// sachets ouvrables sont LE MÊME NOMBRE : le sachet naît au claim.
    struct EtatCoffre {
        let soldeOr: Int
        let soldeArgent: Int
        let boostersOr: Int
        /// 0-99 : le report de la conversion 100 pièces = 1 booster.
        let reste: Int
        let prixBooster: Int
        let piecesParSerie: Int
    }

    static func etatCoffre(jwt: String) async throws -> EtatCoffre {
        let data = try await rpc("etat_coffre", jwt: jwt)
        guard let j = try JSONSerialization.jsonObject(with: data)
                as? [String: Any] else { throw Erreur.reponse }
        func n(_ k: String, _ defaut: Int) -> Int { (j[k] as? Int) ?? defaut }
        return EtatCoffre(soldeOr: n("solde_or", 0),
                          soldeArgent: n("solde_argent", 0),
                          boostersOr: n("boosters_or", 0),
                          reste: n("reste", 0),
                          prixBooster: n("prix_booster", 100),
                          piecesParSerie: n("pieces_par_serie", 20))
    }

    /// Le solde de pièces d'ARGENT (dérivé côté serveur, jamais une colonne).
    ///
    /// ⚠️ **ELLE S'APPELAIT `solde_noir` PENDANT UNE HEURE.** La 2ᵉ monnaie
    /// portait trois noms — `.argent` dans l'app, « noire » dans les plans,
    /// `black` en base. Verdict de Kathryn : « il faudrait le même nom ». Le
    /// dessin a tranché : la planche `piece-argent` mesure 186 · 170 · 153 sur
    /// ses hautes lumières, un métal PÂLE — une pièce qui ressemble à ça ne
    /// peut pas s'appeler noire. **La pièce d'argent ouvre le booster noir** :
    /// deux objets, deux noms.
    static func soldeArgent(jwt: String) async throws -> Int {
        let data = try await rpc("solde_argent", jwt: jwt)
        // La fonction rend un scalaire : PostgREST le sérialise nu.
        if let n = try? JSONSerialization.jsonObject(with: data) as? Int { return n }
        if let s = String(data: data, encoding: .utf8),
           let n = Int(s.trimmingCharacters(in: .whitespacesAndNewlines)) { return n }
        throw Erreur.reponse
    }

    /// Débite une pièce noire, réserve le sachet, rend son `id`.
    static func claimLegendaire(jwt: String) async throws -> String {
        let data = try await rpc("claim_booster_legendaire", jwt: jwt)
        let json = try JSONSerialization.jsonObject(with: data)
        // `returns public.user_boosters` : une ligne, seule ou dans un tableau
        // selon la version de PostgREST — les deux formes sont acceptées.
        let ligne = (json as? [String: Any])
            ?? (json as? [[String: Any]])?.first
        guard let id = ligne?["id"] as? String else { throw Erreur.reponse }
        return id
    }

    // MARK: - LES TROIS SOURCES QUI NE SONT PAS DES SÉRIES (28-08)
    //
    // ⚠️ Elles ont un point commun qui explique tout le reste : **aucune ne
    // passe par « séries × 20 »**. L'historique du coffre, qui RECONSTRUIT
    // ses lignes depuis les séances, les rate donc toutes les trois — et le
    // solde aussi. C'est ce qui fait de la bascule sur le journal une
    // condition, et non plus une amélioration.

    /// LE VERSEMENT DE CONNEXION — 10 pièces, **une fois par jour
    /// calendaire** (tranché par Kathryn le 28-08).
    ///
    /// ⚠️ **ELLE S'APPELLE SANS SAVOIR.** La pop-up Welcome Back n'a pas à
    /// vérifier si c'est déjà pris : elle appelle, et `credite` lui dit s'il
    /// y a quelque chose à annoncer. Toute la garantie est côté serveur, dans
    /// un index unique partiel sur (user, jour) — un compteur dans les
    /// préférences se remettrait à zéro à la réinstallation.
    struct RetourQuotidien {
        let credite: Bool
        let montant: Int
        let solde: Int
    }

    static func claimRetourQuotidien(jwt: String) async throws
        -> RetourQuotidien {
        let j = try await objet("claim_retour_quotidien", jwt: jwt)
        return RetourQuotidien(credite: (j["credite"] as? Bool) ?? false,
                               montant: (j["montant"] as? Int) ?? 0,
                               solde: (j["solde"] as? Int) ?? 0)
    }

    /// LA CLÔTURE D'UNE SÉANCE — les pièces **et** le sachet, en un appel.
    ///
    /// ⚠️⚠️ **LES DEUX NE COMPTENT PAS LA MÊME CHOSE** (sa précision du
    /// 28-08 : « peu importe le nombre de séries, c'est UN booster à la fin
    /// de la session complète ») : les **pièces** sont proportionnelles au
    /// travail (séries × 20), le **booster** est FORFAITAIRE — il paie le
    /// fait d'avoir fini, pas la quantité. Une séance de 3 séries et une de
    /// 15 donnent un sachet chacune.
    ///
    /// ⚠️ Idempotente : la rappeler sur la même séance ne crédite rien de
    /// plus et rend le sachet déjà gagné (`boosterNeuf == false`). C'est ce
    /// qui la rend sûre à appeler depuis un `onAppear` ou une reprise.
    struct ClotureSeance {
        let pieces: Int
        let piecesCreditees: Bool
        let boosterId: String?
        let boosterNeuf: Bool
        let solde: Int
    }

    static func cloturerSeance(_ workout: UUID, series: Int,
                               jwt: String) async throws -> ClotureSeance {
        let j = try await objet("cloturer_seance", jwt: jwt,
                                corps: ["p_workout": workout.uuidString
                                                            .lowercased(),
                                        "p_series": series])
        return ClotureSeance(pieces: (j["pieces"] as? Int) ?? 0,
                             piecesCreditees: (j["pieces_creditees"] as? Bool)
                                ?? false,
                             boosterId: j["booster_id"] as? String,
                             boosterNeuf: (j["booster_neuf"] as? Bool) ?? false,
                             solde: (j["solde"] as? Int) ?? 0)
    }

    /// ⚠️⚠️ **L'ÉTAPE 1 DU BRANCHEMENT, ET LA SEULE QUI NE RISQUE RIEN :
    /// L'APP ÉCRIT, PERSONNE NE LIT ENCORE.**
    ///
    /// Appelée à la clôture d'une séance. À l'écran, **rien ne change** : la
    /// notification « +240 » et la pop-up du sachet existent déjà en local et
    /// continuent de vivre leur vie. On remplit le journal AVANT de s'en
    /// servir — un branchement qui ne se voit pas est un branchement qu'on
    /// peut défaire.
    ///
    /// ⚠️ **ELLE NE PROPAGE JAMAIS SON ÉCHEC.** Elle vit dans une tâche de
    /// fond, derrière la synchro de la séance ; la chaîne de fin de séance
    /// (retour home, célébration, proposition du sachet) n'a pas le droit
    /// d'attendre le réseau, et encore moins de casser dessus.
    ///
    /// ⚠️ **ELLE PASSE PAR L'OUTBOX** (`OutboxGains`) : sans réseau ou sans
    /// session, l'écriture est MISE EN ATTENTE et rejouée au prochain retour
    /// au premier plan. Elle n'est plus perdue — et une écriture perdue
    /// serait un gain perdu le jour où le coffre lira le journal.
    ///
    /// ⚠️ Le rejeu n'est sûr **que parce que le serveur est idempotent** :
    /// deux index uniques partiels (un gain par séance, un sachet par
    /// séance). Sans cette garantie, une file d'attente DOUBLERAIT les gains
    /// au premier accident de réseau.
    ///
    /// Les gardes (`-demoData`, configuration, session) vivent maintenant
    /// dans l'outbox — un seul endroit pour toutes les écritures d'argent.
    static func reglerFinDeSeance(_ seance: UUID, series: Int) async {
        // Une séance sans une seule série ne paie rien — la même garde qu'à
        // l'écran (`terminerSeance` ne propose le sachet que si gain > 0) et
        // que côté serveur. Trois endroits, une seule règle.
        guard series > 0 else { return }
        await OutboxGains.shared.poster(.finDeSeance(seance: seance,
                                                     series: series))
    }

    /// LE VERSEMENT DE CONNEXION — appelé au retour au premier plan.
    ///
    /// ⚠️⚠️ **JUSQU'AU 29-08, PERSONNE NE POSTAIT CE CAS.** La fonction
    /// serveur était déployée et vérifiée le 28-08, le cas `.retourQuotidien`
    /// existait dans l'outbox et y était traité — mais aucune ligne de l'app
    /// ne l'y mettait. Du code mort des deux côtés d'un tuyau complet.
    ///
    /// ⚠️ **LE MARQUEUR LOCAL N'EST PAS L'IDEMPOTENCE.** Celle-ci est côté
    /// serveur, dans un index unique partiel sur (user, jour) — un marqueur de
    /// préférences se remet à zéro à la réinstallation, la loi est écrite. Il
    /// n'est ici que par POLITESSE : sans lui, on posterait un RPC à CHAQUE
    /// bascule d'application, et il y en a beaucoup.
    ///
    /// ⚠️ **ET IL COMPTE LE JOUR EN UTC**, comme la fonction serveur
    /// (`(now() at time zone 'UTC')::date`). Un marqueur en heure locale et un
    /// index en UTC ne changent pas de jour au même instant : à Paris, entre
    /// minuit et 1 h, le local dirait « nouveau jour » quand le serveur dirait
    /// « déjà pris » — ou l'inverse, et on sauterait un versement. Le jour où
    /// le fuseau du profil sera tranché, ces deux lignes-là changent ensemble.
    static func reglerRetourQuotidien() async {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let jour = utc.startOfDay(for: Date()).timeIntervalSince1970
        let cle = "woop.retour.dernierJourUTC"
        let vu = UserDefaults.standard.double(forKey: cle)
        guard vu != jour else { return }
        UserDefaults.standard.set(jour, forKey: cle)
        await OutboxGains.shared.poster(.retourQuotidien)
    }

    /// UN NŒUD DU CHEMIN RÉCLAMÉ — pièces et/ou boosters.
    ///
    /// ⚠️ Le TIRAGE reste au front (`RewardChemin.TirageRecompense`) et cet
    /// appel ENREGISTRE ce qu'il a donné. C'est une étape, pas la cible :
    /// tant que le tirage est au client il est falsifiable, comme la pitié
    /// (après 12 nœuds communs le taux rare double), qui devra remonter au
    /// serveur. **Ce qui est déjà garanti, c'est qu'un nœud ne paie qu'une
    /// fois** — un index, là où l'app tenait ça dans `UserDefaults`.
    @discardableResult
    static func reclamerNoeudChemin(_ noeud: Int, pieces: Int = 0,
                                    monnaie: String = "yellow",
                                    boosters: [String] = [],
                                    jwt: String) async throws -> Bool {
        let j = try await objet("reclamer_noeud_chemin", jwt: jwt,
                                corps: ["p_noeud": noeud,
                                        "p_pieces": pieces,
                                        "p_monnaie": monnaie,
                                        "p_boosters": boosters])
        return (j["deja_reclame"] as? Bool) == false
    }

    /// ACHETER UN SACHET ORANGE — le débit et la réserve dans la MÊME
    /// transaction : un réseau qui coupe entre les deux laisserait une pièce
    /// dépensée sans sachet, ou l'inverse.
    struct AchatBooster {
        let ouvert: Bool
        let boosterId: String?
        let solde: Int
        let prix: Int
    }

    static func claimBooster(jwt: String) async throws -> AchatBooster {
        let j = try await objet("claim_booster", jwt: jwt)
        return AchatBooster(ouvert: (j["ouvert"] as? Bool) ?? false,
                            boosterId: j["booster_id"] as? String,
                            solde: (j["solde"] as? Int) ?? 0,
                            prix: (j["prix"] as? Int) ?? 100)
    }

    /// L'HISTORIQUE — le JOURNAL, pas une reconstruction.
    ///
    /// ⚠️ La page des gains recalcule aujourd'hui `séries × 20` depuis les
    /// séances : une reconstruction ne peut montrer que ce qu'elle sait
    /// recalculer. Le versement quotidien, les boosters du chemin et le
    /// sachet de fin de séance n'y apparaissent jamais. C'est aussi ce qui
    /// donnera enfin des lignes AVEC UN SACHET (`GainCoffre.robe` est
    /// toujours `nil` aujourd'hui, donc chaque ligne montre la pièce d'or).
    struct LigneGain {
        let quand: Date
        /// `coins` ou `booster`.
        let genre: String
        /// La raison (`serie_faite`, `retour_quotidien`, `chemin`…) ou
        /// l'origine (`seance`, `achat`, `chemin`, `legendaire`).
        let motif: String
        let montant: Int
        let monnaie: String?
        /// `lune` · `noire` · nil pour une ligne de pièces.
        let robe: String?
    }

    static func historique(jwt: String, limite: Int = 60) async throws
        -> [LigneGain] {
        let data = try await rpc("historique_gains", jwt: jwt,
                                 corps: ["p_limite": limite])
        guard let lignes = try JSONSerialization.jsonObject(with: data)
                as? [[String: Any]] else { throw Erreur.reponse }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return lignes.map { l in
            let t = (l["quand"] as? String).flatMap { s in
                iso.date(from: s) ?? ISO8601DateFormatter().date(from: s)
            }
            return LigneGain(quand: t ?? Date(),
                             genre: (l["genre"] as? String) ?? "coins",
                             motif: (l["motif"] as? String) ?? "",
                             montant: (l["montant"] as? Int) ?? 0,
                             monnaie: l["monnaie"] as? String,
                             robe: l["robe"] as? String)
        }
    }

    // MARK: L'appel nu

    /// Le cas courant : une fonction qui rend un objet JSON.
    private static func objet(_ nom: String, jwt: String,
                              corps: [String: Any] = [:]) async throws
        -> [String: Any] {
        let data = try await rpc(nom, jwt: jwt, corps: corps)
        let json = try JSONSerialization.jsonObject(with: data)
        // ⚠️ PostgREST rend tantôt l'objet, tantôt un tableau d'une ligne
        // selon la forme de retour — les deux sont acceptées (la leçon est
        // déjà écrite sur `claimLegendaire`).
        if let o = json as? [String: Any] { return o }
        if let a = json as? [[String: Any]], let p = a.first { return p }
        throw Erreur.reponse
    }

    private static func rpc(_ nom: String, jwt: String,
                            corps: [String: Any] = [:]) async throws -> Data {
        var req = URLRequest(url: WoopConfig.supabaseURL
            .appending(path: "rest/v1/rpc/\(nom)"))
        req.httpMethod = "POST"
        req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        req.setValue(WoopConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = corps.isEmpty
            ? Data("{}".utf8)
            : try JSONSerialization.data(withJSONObject: corps)
        let (data, rep) = try await URLSession.shared.data(for: req)
        let code = (rep as? HTTPURLResponse)?.statusCode ?? 0
        guard (200 ..< 300).contains(code) else {
            let détail = (try? JSONSerialization.jsonObject(with: data))
                .flatMap { $0 as? [String: Any] }
                .flatMap { $0["message"] as? String } ?? ""
            throw Erreur.http(code, détail)
        }
        return data
    }
}
