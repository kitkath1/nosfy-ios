import Foundation

// MARK: - LA COACH — la phrase par exercice, écrite par le serveur (16-09)
//
// Plan : tools/fiche/PLAN-COURBE-CHARGE-COACH.md §2. La fiche muscu demande UNE
// phrase à l'edge `conseil-exercice` (le motif de `bilan-periode` : JWT, langue
// du profil, l'historique relu au serveur avec le jeton de la personne, la
// règle de progression dans `reward_rules`, gpt-5 avec un résumé nommé, un
// cache par (personne, exercice) sur la fraîcheur du dernier passage). Le
// téléphone ne calcule jamais une cible : la règle vit au serveur.
//
// Jamais un throw, jamais un spinner : un `Conseil` avec sa `raison`, et la
// fiche retombe sur ce qu'elle sait dire seule (« Dernière fois 45 kg × 12. »).

enum CoachServeur {
    /// `-sansServeur` : le barreau commun aux lectures serveur (comme les
    /// chambres) — la fiche vit sans phrase IA.
    static let neutralise = CommandLine.arguments.contains("-sansServeur")

    struct Conseil {
        let phrase: String?
        /// La phrase de la règle, toujours là quand le serveur a répondu :
        /// c'est elle qui parle si le modèle est muet.
        let phraseRegle: String?
        /// `premier` · `monter` · `tenir`
        let regle: String?
        let cibleKg: Double?
        let cibleReps: Int?
        let deltaKg: Double?
        let recordKg: Double?
        let langue: String?
        /// Vrai = le stocké, sans rappeler le modèle.
        let cache: Bool
        let modele: String?
        /// `sans_serveur` · `sans_session` · `reseau` · `exercice_inconnu` ·
        /// `modele_muet` · `cle_absente` · `http_<code>` · nil si une phrase est là
        let raison: String?

        static func vide(_ raison: String) -> Conseil {
            Conseil(phrase: nil, phraseRegle: nil, regle: nil, cibleKg: nil, cibleReps: nil,
                    deltaKg: nil, recordKg: nil, langue: nil, cache: false, modele: nil, raison: raison)
        }
        /// Ce que la fiche affiche : la phrase du modèle, sinon celle de la règle.
        var texte: String? { phrase ?? phraseRegle }
    }

    /// La phrase pour cet exercice. Huit secondes au plus : au-delà, la fiche
    /// parle seule (le serveur, lui, finira d'écrire et gardera la phrase
    /// pour la prochaine ouverture).
    static func conseil(_ exerciceID: String) async -> Conseil {
        if neutralise { return .vide("sans_serveur") }
        guard let jwt = try? await SupabaseSession.shared.token() else { return .vide("sans_session") }
        var req = URLRequest(url: WoopConfig.supabaseURL.appending(path: "functions/v1/conseil-exercice"))
        req.httpMethod = "POST"
        req.timeoutInterval = 8
        req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        req.setValue(WoopConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["exercice": exerciceID])
        guard let (data, rep) = try? await URLSession.shared.data(for: req),
              let j = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return .vide("reseau")
        }
        let code = (rep as? HTTPURLResponse)?.statusCode ?? 0
        func txt(_ k: String) -> String? { (j[k] as? String).flatMap { $0.isEmpty ? nil : $0 } }
        func num(_ k: String) -> Double? { (j[k] as? NSNumber)?.doubleValue }
        let phrase = code == 200 ? txt("phrase") : nil
        let regle = txt("phrase_regle")
        return Conseil(phrase: phrase,
                       phraseRegle: regle,
                       regle: txt("regle"),
                       cibleKg: num("cible_kg"),
                       cibleReps: (j["cible_reps"] as? NSNumber)?.intValue,
                       deltaKg: num("delta_kg"),
                       recordKg: num("record_kg"),
                       langue: txt("langue"),
                       cache: j["cache"] as? Bool ?? false,
                       modele: txt("modele"),
                       raison: (phrase ?? regle) == nil ? (txt("raison") ?? "http_\(code)") : nil)
    }

    /// Le banc : `-coachBanc` — la réponse LUE et imprimée (journal `[coach]`),
    /// la preuve de la brique. Rejouée au second appel : `cache`.
    static let banc = CommandLine.arguments.contains("-coachBanc")
    static func journal(_ exerciceID: String, _ c: Conseil, ms: Int) {
        guard banc else { return }
        print("[coach] \(exerciceID) → " + (c.texte.map { "« \($0) »" } ?? "pas de phrase (\(c.raison ?? "?"))")
              + " · \(c.regle ?? "-") · cible \(c.cibleKg.map { ChambreFmt.poids($0) } ?? "-")"
              + " · record \(c.recordKg.map { ChambreFmt.poids($0) } ?? "-")"
              + " · \(c.langue ?? "-") · \(c.cache ? "cache" : (c.modele ?? "-")) · \(ms) ms")
    }
}
