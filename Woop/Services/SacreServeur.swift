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
        /// Le noir déjà payé, ouvert, pas encore scellé (au plus un) — il
        /// tient la porte du manège ouverte jusqu'à la reprise. Absent des
        /// bases d'avant la migration 20260830160000 : 0.
        let noirsOuverts: Int
        /// 0-99 : le report de la conversion 100 pièces = 1 booster.
        let reste: Int
        let prixBooster: Int
        let piecesParSerie: Int
        // ── DEPUIS 20260830210000 (30-08 soir) — le jour de la maison, le
        //    Welcome Back et la flamme. ⚠️ OPTIONNELS, ET C'EST LA LOI DES
        //    DEUX DIALECTES (:120) : une clé absente (base d'avant la
        //    migration) vaut « je ne sais pas », JAMAIS un défaut — l'écran
        //    garde ce qu'il avait plutôt que d'afficher un faux.
        /// La date du jour dans le fuseau de la maison (`fuseau_jour`,
        /// Europe/Paris) — « minuit chez elle », jamais celui du téléphone.
        let jour: String?
        /// Le +10 est-il encore à prendre aujourd'hui (lu SANS payer : c'est
        /// ce qui permet au Claim de promettre avant d'encaisser).
        let retourDisponible: Bool?
        /// Le prochain minuit de la maison — l'horloge du +10 du coffre (§29).
        let retourProchain: Date?
        /// Le montant du retour (`pieces_retour_quotidien`), depuis
        /// 20260830220000 — avant, l'app le connaissait par cœur.
        let piecesRetourQuotidien: Int?
        /// La flamme : jours d'affilée avec une séance, dérivée au serveur,
        /// sans bonus — et « aujourd'hui est-il fait ».
        let flammeJours: Int?
        let flammeAujourdhui: Bool?
        // ── DEPUIS 20260915160000 (15-09, l'économie du cardio) — la piscine
        //    se paie 20 la longueur, plafond 300 (`pieces_par_longueur`,
        //    `cardio_piscine_max`). La fiche le DIT au « + » comme la série
        //    dit ses 20 : elle lit le prix ici, elle ne le connaît pas.
        //    Optionnels (la loi des deux dialectes) : rendus depuis
        //    20260915190000 ; une base d'avant garde les défauts de l'app.
        let piecesParLongueur: Int?
        let piscineMax: Int?
    }

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    private static let isoFractions: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    /// Postgres sérialise un `timestamptz` en `2026-08-30T22:00:00+00:00`,
    /// parfois avec des fractions — on lit les deux.
    static func date(_ s: String?) -> Date? {
        guard let s else { return nil }
        return iso.date(from: s) ?? isoFractions.date(from: s)
    }

    static func etatCoffre(jwt: String) async throws -> EtatCoffre {
        let data = try await rpc("etat_coffre", jwt: jwt)
        guard let j = try JSONSerialization.jsonObject(with: data)
                as? [String: Any] else { throw Erreur.reponse }
        func n(_ k: String, _ defaut: Int) -> Int { (j[k] as? Int) ?? defaut }
        let flamme = j["flamme"] as? [String: Any]
        return EtatCoffre(soldeOr: n("solde_or", 0),
                          soldeArgent: n("solde_argent", 0),
                          boostersOr: n("boosters_or", 0),
                          noirsOuverts: n("noirs_ouverts", 0),
                          reste: n("reste", 0),
                          prixBooster: n("prix_booster", 100),
                          piecesParSerie: n("pieces_par_serie", 20),
                          jour: j["jour"] as? String,
                          retourDisponible: j["retour_disponible"] as? Bool,
                          retourProchain: date(j["retour_prochain"] as? String),
                          piecesRetourQuotidien: j["pieces_retour_quotidien"] as? Int,
                          flammeJours: flamme?["jours"] as? Int,
                          flammeAujourdhui: flamme?["aujourdhui_fait"] as? Bool,
                          piecesParLongueur: j["pieces_par_longueur"] as? Int,
                          piscineMax: j["cardio_piscine_max"] as? Int)
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

    /// LA CONSOMMATION DU BOOSTER NOIR : débite une pièce d'argent, crée le
    /// sachet légendaire OUVERT (non scellé), rend son `id` — ou le sachet
    /// déjà ouvert non scellé s'il en existe un (idempotente : un quit entre
    /// la consommation et la forge ne coûte pas une seconde pièce).
    /// Depuis la migration 20260830160000 elle répond en jsonb, 200 avec un
    /// motif sur un refus (`argent_insuffisant`) — plus jamais un 500 pour
    /// « pas assez d'argent ». `nil` = refusé.
    ///
    /// ⚠️ **DEUX DIALECTES, PAR CONSTRUCTION.** L'app se déploie sur l'iPhone
    /// par un acte, la base par un autre : tant que la migration n'est pas
    /// posée, l'ANCIENNE fonction répond une ligne `user_boosters` (`{id,
    /// origine, …}`, sans `ouvert`) — et elle a DÉJÀ débité la pièce. Ne
    /// lire que la forme neuve rendait `nil` = « refusé » sur un sachet payé,
    /// et le rejeu rendait la même ligne : la pièce coincée jusqu'au push.
    /// Ici, seul un `ouvert: false` EXPLICITE est un refus.
    static func claimLegendaire(jwt: String) async throws -> String? {
        let j = try await objet("claim_booster_legendaire", jwt: jwt)
        if (j["ouvert"] as? Bool) == false {
            print("[sacre] booster noir refusé : "
                  + ((j["raison"] as? String) ?? "?"))
            return nil
        }
        return (j["booster_id"] as? String) ?? (j["id"] as? String)
    }

    /// LE TIRAGE DU CHEMIN, AU SERVEUR (30-08) : le client dit le NŒUD et la
    /// PISTE, le serveur tire, dérive la pitié de son journal, écrit, et rend
    /// `{deja_reclame, type, montant, monnaie, robes, rarete, solde,
    /// solde_argent}`. Rejoué : le même résultat, jamais un second tirage.
    static func tirerNoeudChemin(_ noeud: Int, pieces: Bool,
                                 jwt: String) async throws -> [String: Any] {
        try await objet("tirer_noeud_chemin", jwt: jwt,
                        corps: ["p_noeud": noeud, "p_pieces": pieces])
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
        /// Depuis 20260830210000 : le jour de la maison écrit dans le carnet,
        /// et ce que ce crédit a fait naître comme sachets (100 → 1).
        let jour: String?
        let sachetsConvertis: Int
    }

    static func claimRetourQuotidien(jwt: String) async throws
        -> RetourQuotidien {
        let j = try await objet("claim_retour_quotidien", jwt: jwt)
        return RetourQuotidien(credite: (j["credite"] as? Bool) ?? false,
                               montant: (j["montant"] as? Int) ?? 0,
                               solde: (j["solde"] as? Int) ?? 0,
                               jour: j["jour"] as? String,
                               sachetsConvertis: (j["sachets_convertis"] as? Int) ?? 0)
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
    /// ⚠️⚠️ **ELLE PORTE HUIT CHAMPS ET N'EN LISAIT QUE CINQ.** La migration
    /// des annonces (29-08) a élargi la réponse — `argent`, `reste`,
    /// `prix_booster` — précisément pour qu'« une seule annonce par
    /// événement » ait *une seule réponse* à lire. Le décodeur, lui, n'avait
    /// pas suivi : le serveur tendait de quoi composer la dalle entière et
    /// Swift le laissait tomber par terre.
    struct ClotureSeance {
        let pieces: Int
        let piecesCreditees: Bool
        let boosterId: String?
        let boosterNeuf: Bool
        let solde: Int
        /// La pièce d'argent est-elle tombée À CET APPEL (`roll_rare`,
        /// p = 1/30, pitié 45, cooldown 10 — tiré au RÈGLEMENT, jamais au
        /// client). ⚠️ Faux sur un rejeu — et depuis 20260830210000 c'est
        /// `argentSeance` qui dit si la séance l'a jamais fait tomber.
        let argent: Bool
        /// Où en est la jauge APRÈS ce gain (0…prix−1).
        let reste: Int
        /// Le prix du sachet, tel que la base le dit à cet instant.
        let prixBooster: Int
        // ── DEPUIS 20260830210000 (30-08 soir) ──
        /// Un REJEU (outbox, kill, double tap) : le serveur a rendu le STOCKÉ
        /// — les mêmes pièces, le même sachet — et n'a rien crédité.
        let rejeu: Bool
        /// Le solde d'argent APRÈS ce règlement — l'app le POSE, elle ne
        /// l'incrémente plus (un rejeu comptait la pièce deux fois).
        let soldeArgent: Int?
        /// La pièce d'argent est-elle tombée pour CETTE séance (rejeu compris).
        let argentSeance: Bool
        /// Les sachets nés de ce crédit (100 pièces → 1), dans la même
        /// transaction — de quoi empiler une dalle « +N sachets ».
        let sachetsConvertis: Int
        // ── DEPUIS 20260915120000 (15-09) ──
        /// CE QUE CETTE SÉANCE A ÉTÉ, calculé et rangé par le serveur à la
        /// clôture (`calculer_faits_seance`, les règles `top_*` du 30-08) :
        /// `top_muscu` / `top_cardio` (elle s'est dépassée sur la fenêtre de
        /// sept jours — mesure, valeur, précédent) et `double_jour` (la
        /// deuxième séance du jour — `detail.heures`, `detail.minutes`, la
        /// forme de `DoubleFait`). Vide tant que la séance n'est pas poussée
        /// (`faitsRaison` = « seance_inconnue ») : la story choisit alors
        /// sa page ordinaire. Un estampillage : rejouée, la même liste.
        let faits: [Fait]
        let faitsRaison: String?
        // ── DEPUIS 20260915160000 (15-09, l'économie du cardio) ──
        /// Ce que le CARDIO de la séance a rapporté — le barème calculé par le
        /// serveur (`pieces_cardio_seance`, tools/cardio/PLAN-ECONOMIE-CARDIO.md),
        /// bonus compris. 0 sans cardio, ou sur une base d'avant (clé absente).
        let piecesCardio: Int
        /// Séries × taux + cardio.
        let piecesTotal: Int
        /// Le sachet forfaitaire accordé PAR LE CARDIO (aucune série de muscu).
        let sachetCardio: Bool
        /// Le détail par exercice, tel que le serveur le rend (`exercices: [...]`).
        let cardioDetail: [String: Any]
        /// Le cardio de cette séance était DÉJÀ payé (le stocké relu) : rien
        /// de neuf à dire.
        let cardioRejeu: Bool
        /// Le bonus « tu t'es dépassée » (30) quand un fait `top_cardio` a été
        /// rangé — une règle, pas un avis (option A' du plan économie).
        let bonusProgres: Int
    }

    /// Un fait de séance, tel que le serveur le range (`workout_facts`).
    struct Fait {
        /// `top_muscu` · `top_cardio` · `double_jour`
        let kind: String
        /// `series` · `volume_kg` · `hiit_secondes` · `vitesse_duree` — nil pour le ×2
        let mesure: String?
        let valeur: Double?
        let precedent: Double?
        /// Le ×2 : `heures` (["07:12","19:40"]) et `minutes` (le total du jour).
        let detail: [String: Any]

        static func lire(_ j: [String: Any]) -> Fait? {
            guard let kind = j["kind"] as? String else { return nil }
            return Fait(kind: kind, mesure: j["mesure"] as? String,
                        valeur: (j["valeur"] as? NSNumber)?.doubleValue,
                        precedent: (j["precedent"] as? NSNumber)?.doubleValue,
                        detail: j["detail"] as? [String: Any] ?? [:])
        }
    }

    static func cloturerSeance(_ workout: UUID, series: Int,
                               jwt: String) async throws -> ClotureSeance {
        let j = try await objet("cloturer_seance", jwt: jwt,
                                corps: ["p_workout": workout.uuidString
                                                            .lowercased(),
                                        "p_series": series])
        let argent = (j["argent"] as? Bool) ?? false
        return ClotureSeance(pieces: (j["pieces"] as? Int) ?? 0,
                             piecesCreditees: (j["pieces_creditees"] as? Bool)
                                ?? false,
                             boosterId: j["booster_id"] as? String,
                             boosterNeuf: (j["booster_neuf"] as? Bool) ?? false,
                             solde: (j["solde"] as? Int) ?? 0,
                             argent: argent,
                             reste: (j["reste"] as? Int) ?? 0,
                             prixBooster: (j["prix_booster"] as? Int) ?? 100,
                             rejeu: (j["rejeu"] as? Bool) ?? false,
                             soldeArgent: j["solde_argent"] as? Int,
                             argentSeance: (j["argent_seance"] as? Bool) ?? argent,
                             sachetsConvertis: (j["sachets_convertis"] as? Int) ?? 0,
                             faits: ((j["faits"] as? [[String: Any]]) ?? [])
                                .compactMap(Fait.lire),
                             faitsRaison: j["faits_raison"] as? String,
                             piecesCardio: (j["pieces_cardio"] as? Int) ?? 0,
                             piecesTotal: (j["pieces_total"] as? Int)
                                ?? ((j["pieces"] as? Int) ?? 0),
                             sachetCardio: (j["sachet_cardio"] as? Bool) ?? false,
                             cardioDetail: j["cardio_detail"] as? [String: Any] ?? [:],
                             cardioRejeu: (j["cardio_rejeu"] as? Bool) ?? false,
                             bonusProgres: (j["bonus_progres"] as? Int) ?? 0)
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
    static func reglerFinDeSeance(_ seance: UUID, series: Int,
                                  cardio: Bool = false) async {
        // Une séance sans une seule série ni un intervalle ne paie rien — la
        // même garde qu'à l'écran (`terminerSeance` ne propose le sachet que
        // si gain > 0 ou cardio fait) et que côté serveur. Trois endroits,
        // une seule règle. Le cardio (15-09) : `p_series` reste les séries
        // de muscu (0, ici) — le serveur lit les phases poussées juste avant
        // et calcule le barème lui-même.
        guard series > 0 || cardio else { return }
        await OutboxGains.shared.poster(.finDeSeance(seance: seance,
                                                     series: series))
    }

    /// LE VERSEMENT DE CONNEXION — posté AU TAP du bouton Claim, et nulle
    /// part ailleurs (tranché par Kathryn le 30-08 : « je tiens au bouton
    /// Claim »).
    ///
    /// ⚠️⚠️ **JUSQU'AU 30-08 AU SOIR, IL PARTAIT TOUT SEUL** à chaque retour
    /// au premier plan, sans card ni bouton, avec un marqueur UserDefaults en
    /// UTC pour ne pas reposter dans la journée — le contraire de la doctrine
    /// (§4 duodecies : « l'encaissement, c'est le bouton Claim »). Le marqueur
    /// est mort avec lui : le serveur sait si le jour est pris
    /// (`etat_coffre().retour_disponible`, lu sans payer), et l'index
    /// `(user, jour)` reste la seule idempotence — un Claim rejoué ne crédite
    /// rien et ne lève rien.
    ///
    /// Elle passe par l'outbox : hors ligne, le tap n'est pas perdu, il est
    /// rejoué au prochain retour au premier plan.
    static func reclamerRetourQuotidien() async {
        await OutboxGains.shared.poster(.retourQuotidien)
    }

    /// L'ANCIENNE PORTE DU NŒUD — gardée pour vider une outbox d'avant.
    ///
    /// ⚠️ **CE COMMENTAIRE DISAIT « LE TIRAGE RESTE AU FRONT » JUSQU'AU
    /// 30-08.** Périmé depuis 9ef6da1 : le tirage et sa pitié vivent au
    /// serveur (`tirerNoeudChemin` ci-dessus, `tirer_noeud_chemin` dans
    /// `20260830160000_sachet_scelle_et_tirage.sql`), et l'app ne poste plus
    /// jamais ce cas (`RewardChemin.poster` est mort). Côté serveur,
    /// `reclamer_noeud_chemin` DÉLÈGUE à `tirer_noeud_chemin` et IGNORE
    /// `p_pieces`, `p_monnaie`, `p_boosters` — sauf pour lire la piste
    /// (`p_pieces > 0`) ; sondée le 30-08 : `(3, 1000000, 'silver', {})` →
    /// `{deja_reclame: true}`, solde d'argent inchangé.
    ///
    /// Son seul appelant restant est l'outbox (`OutboxGains.swift:212-214`),
    /// pour une entrée `.noeudChemin` mise en file par une version antérieure.
    /// Elle ne rend qu'un booléen — donc l'outbox RELIT le solde après.
    /// **Ce qui est garanti n'a pas changé : un nœud ne paie qu'une fois** —
    /// un index, là où l'app tenait ça dans `UserDefaults`.
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
    /// OUVRIR UN SACHET — la seule écriture d'`opened_at` de tout le système.
    ///
    /// ⚠️⚠️ **PERSONNE NE L'ÉCRIVAIT.** `grep "opened_at" supabase/` ne rend
    /// que sa déclaration, un index, des `select`, et deux `insert` qui la
    /// posent à la NAISSANCE d'une ligne légendaire. Aucun `update` nulle
    /// part : côté serveur, ouvrir un booster ne se voyait pas, la pile ne
    /// pouvait que croître, et `etat_coffre().boosters_or` aurait compté
    /// toutes les séances jamais faites sans jamais rien retirer.
    ///
    /// ⚠️ **ELLE REND L'ID DU SACHET CONSOMMÉ**, parce que c'est lui que la
    /// forge doit sceller : une carte tirée sans sachet, c'est une carte que
    /// rien ne relie à ce qu'on a ouvert.
    ///
    /// ✅ **MIGRATION `20260829150000_ouvrir_booster.sql` — DÉPLOYÉE ET
    /// VÉRIFIÉE le 30-08** sur le compte de test : `ouvrir_booster
    /// {p_legendaire: false}` → 200 `{ouvert: true, booster_id}`, et
    /// `etat_coffre().boosters_or` est passé de 47 à 46 (témoin inventé :
    /// 404). Le commentaire « NON DÉPLOYÉE » qui vivait ici depuis le 29-08
    /// était PÉRIMÉ — un état se vérifie, il ne se déduit pas d'un souvenir.
    static func ouvrirBooster(legendaire: Bool,
                              jwt: String) async throws -> String? {
        let data = try await rpc("ouvrir_booster", jwt: jwt,
                                 corps: ["p_legendaire": legendaire])
        guard let j = try JSONSerialization.jsonObject(with: data)
                as? [String: Any] else { throw Erreur.reponse }
        return j["booster_id"] as? String
    }

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

    /// LES NŒUDS DU CHEMIN DÉJÀ PAYÉS — la lecture qui manquait.
    ///
    /// ⚠️ Le serveur tenait déjà l'argent (deux index uniques sur `noeud_id`),
    /// mais il ne savait pas DIRE ce qu'il avait payé : l'app relisait son
    /// `UserDefaults`, qui se remet à zéro à la réinstallation. Le compte ne
    /// perdait rien ; l'écran, lui, reproposait un cadeau déjà reçu.
    ///
    /// Elle rend un ENSEMBLE : un nœud qui a payé des pièces ET un sachet n'y
    /// figure qu'une fois (le `union` de la fonction serveur).
    static func noeudsCheminReclames(jwt: String) async throws -> Set<Int> {
        let data = try await rpc("noeuds_chemin_reclames", jwt: jwt)
        guard let lignes = try JSONSerialization.jsonObject(with: data)
                as? [[String: Any]] else { throw Erreur.reponse }
        return Set(lignes.compactMap { $0["noeud_id"] as? Int })
    }

    /// UNE FAMILLE DE MA COLLECTION, telle que le mur du profil l'affiche :
    /// un slot par famille, la pastille ×N, la carte la plus récente pour la
    /// vignette. Le serveur rend le CHEMIN de l'illustration nue dans le
    /// bucket public `cards` — jamais une image ; l'app l'habille (cadre,
    /// lunes, depth) exactement comme après une forge.
    struct FamilleCollection {
        let famille: String
        let rarete: String
        let nombre: Int
        let cardId: String
        let artPath: String
        let derniere: Date?
        /// L'URL publique de l'illustration nue (le bucket est public en
        /// lecture : c'est le set commun, pas une donnée du compte).
        var artURL: URL {
            WoopConfig.supabaseURL
                .appending(path: "storage/v1/object/public/cards/\(artPath)")
        }
    }

    /// MA COLLECTION LUE AU SERVEUR (15-09) — `ma_collection()`.
    ///
    /// ⚠️ `user_cards` se remplissait à chaque forge depuis le 14-08 et
    /// AUCUNE ligne de l'app ne la lisait : le mur « Cartes collectées ·
    /// N / 4 » comptait en mémoire et repartait à zéro à chaque
    /// réinstallation. Le serveur groupe par famille (le slot) ; l'ordre
    /// est celui de la première obtention. [] sans carte, 401 sans session.
    static func maCollection(jwt: String) async throws -> [FamilleCollection] {
        let data = try await rpc("ma_collection", jwt: jwt)
        guard let lignes = try JSONSerialization.jsonObject(with: data)
                as? [[String: Any]] else { throw Erreur.reponse }
        return lignes.compactMap { l in
            guard let famille = l["famille"] as? String,
                  let rarete = l["rarete"] as? String,
                  let cardId = l["card_id"] as? String,
                  let artPath = l["art_path"] as? String else { return nil }
            return FamilleCollection(famille: famille, rarete: rarete,
                                     nombre: max(l["nombre"] as? Int ?? 1, 1),
                                     cardId: cardId, artPath: artPath,
                                     derniere: date(l["derniere"] as? String))
        }
    }

    /// LES RÈGLES DU RYTHME DES ANNONCES — `regles_annonces()` (15-09, étape 5).
    ///
    /// Tout `reward_rules` sauf les `rare_*` (les dés restent au serveur), en
    /// un appel : les rangs des pop-ups, le budget par séance, l'écart, les
    /// bonus. Lue à l'apparition de la home par `DecideurSerie.chargerRegles`
    /// ; jusqu'au 15-09, personne ne l'appelait et le décideur vivait sur
    /// trois chiffres en dur.
    static func reglesAnnonces(jwt: String) async throws -> [String: Any] {
        let data = try await rpc("regles_annonces", jwt: jwt)
        guard let j = try JSONSerialization.jsonObject(with: data)
                as? [String: Any] else { throw Erreur.reponse }
        return j
    }

    /// LA COMPOSITION D'UN CHAPITRE, LUE EN BASE.
    ///
    /// ⚠️ `reward_rules` est lisible directement par tout utilisateur
    /// authentifié (« les règles sont publiques en lecture ») : **aucune
    /// fonction à écrire, aucune à déployer** — un simple `select`. C'est la
    /// raison pour laquelle cette lecture-là ne coûte rien.
    ///
    /// ⚠️ Elle ne PILOTE rien : la table des nœuds est un `static let` calculé
    /// au chargement, et toute la géométrie du chemin en découle. Ce qu'on
    /// lit sert à COMPARER (voir `EcranSpec.verifierComposition`) — afficher
    /// « sur 10 » au-dessus d'un chapitre qui dessine 9 pierres serait
    /// précisément la double vérité qu'on veut tuer.
    static func reglesChemin(jwt: String) async throws -> [String: Int] {
        let cles = ["chemin_chapitres", "chemin_noeuds_par_chapitre",
                    "chemin_seances_par_chapitre",
                    "chemin_rang_recompense_milieu", "chemin_rang_tresor"]
        var url = WoopConfig.supabaseURL.appending(path: "rest/v1/reward_rules")
        url.append(queryItems: [
            .init(name: "select", value: "key,value"),
            .init(name: "key", value: "in.(\(cles.joined(separator: ",")))")
        ])
        var req = URLRequest(url: url)
        req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        req.setValue(WoopConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        let (data, rep) = try await URLSession.shared.data(for: req)
        let code = (rep as? HTTPURLResponse)?.statusCode ?? 0
        guard (200 ..< 300).contains(code) else {
            throw Erreur.http(code, String(data: data, encoding: .utf8) ?? "")
        }
        guard let lignes = try JSONSerialization.jsonObject(with: data)
                as? [[String: Any]] else { throw Erreur.reponse }
        var out: [String: Int] = [:]
        for l in lignes {
            guard let k = l["key"] as? String else { continue }
            // `value` est du jsonb : un nombre nu arrive en `Int`, mais une
            // règle saisie « 9 » entre guillemets arriverait en `String`. On
            // accepte les deux plutôt que de rendre la lecture fragile à une
            // saisie.
            if let v = l["value"] as? Int { out[k] = v }
            else if let s = l["value"] as? String, let v = Int(s) { out[k] = v }
        }
        return out
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
