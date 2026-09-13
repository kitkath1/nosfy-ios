import Foundation

// ════════════════════════════════════════════════════════════════════════
// LES CHAMBRES ET LE SERVEUR — les sites d'appel (13-09)
//
// Cinq fonctions posées le 05-09 (`20260905090000_widgets_lecture`,
// `20260905110000_objectif_hebdo`) et mesurées depuis un script — mais
// personne dans l'app ne les appelait. Ici, enfin :
//
//  · `objectif_hebdo()` / `definir_objectif(n)` : l'objectif vit au serveur
//    (`user_prefs`), le téléphone n'en garde qu'un cache ;
//  · `widget_regularite | volume | hiit | peak(fenetre)` : la lecture d'une
//    fenêtre, traduite en `ChambreFenetre`.
//
// LA RÈGLE DE COHÉRENCE — une seule, écrite ici et dans la doc :
//  ① L'OBJECTIF : le serveur gagne. À l'ouverture de la chambre Regularity
//     on le lit ; au choix, on l'écrit et on adopte ce que le serveur rend.
//     Un choix fait sans session reste local, marqué « en attente », et
//     part à la prochaine ouverture connectée — jamais un objectif perdu.
//  ② LES CHIFFRES : le téléphone est la source tant qu'il a des séances sur
//     la fenêtre (il a TOUT, poussé ou non). Quand il n'en a AUCUNE et que
//     le serveur en a — nouveau téléphone, réinstallation — la chambre lit
//     le serveur. Jamais un mélange des deux sur une même fenêtre.
//
// Depuis `20260913211000_widgets_complets` le serveur rend TOUT ce que le
// téléphone calcule : le fantôme (`jours_precedent`), le défi du mois
// (`defi`), les quatre semaines du record de vitesse (`pics4`), la récup et
// le trou de la fenêtre précédente, et le nom / la catégorie de chaque
// exercice (table `exercices`, miroir du catalogue Swift — le catalogue de
// l'app reste le secours si le serveur ne connaît pas un id). Une clé
// absente laisse sa part grise, jamais un chiffre inventé.
//
// Barreaux : `-sansServeur` (aucun appel), `-chambreObjectif N` (le banc
// écrit N à l'ouverture, comme un tap), `-sessionBanc` (le compte de test).
// ════════════════════════════════════════════════════════════════════════

enum ChambreServeur {
    enum Erreur: Error, CustomStringConvertible {
        case http(Int, String), reponse, sansSession
        var description: String {
            switch self {
            case .http(let c, let m): return "HTTP \(c) \(m)"
            case .reponse: return "réponse illisible"
            case .sansSession: return "sans session"
            }
        }
    }

    /// Le barreau : `-sansServeur` — les chambres ne parlent qu'au téléphone.
    static let neutralise = CommandLine.arguments.contains("-sansServeur")

    /// Le banc : `-chambreObjectif 7` écrit 7 à l'ouverture, comme un tap.
    static var bancObjectif: Int? {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: "-chambreObjectif"), a.indices.contains(i + 1) else { return nil }
        return Int(a[i + 1])
    }

    // MARK: - L'objectif

    /// `objectif_hebdo()` — celui de `user_prefs`, ou le défaut du jeu.
    static func objectif() async throws -> Int {
        let data = try await rpc("objectif_hebdo")
        guard let n = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) as? Int
        else { throw Erreur.reponse }
        return n
    }

    /// `definir_objectif(n)` — rend l'objectif tel que le serveur le tient
    /// APRÈS l'écriture (le sien en cas de refus hors bornes) : l'appelante
    /// adopte ce qu'il rend, elle ne re-demande pas.
    static func definirObjectif(_ n: Int) async throws -> Int {
        let o = try await objet("definir_objectif", corps: ["p_objectif": n])
        if o["raison"] as? String == "sans_session" { throw Erreur.sansSession }
        guard let v = ent(o["objectif"]) else { throw Erreur.reponse }
        return v
    }

    // MARK: - Les fenêtres

    static func nomFonction(_ kind: WidgetKind) -> String {
        switch kind {
        case .regularite: return "widget_regularite"
        case .volume:     return "widget_volume"
        case .hiitPeak:   return "widget_hiit"
        case .peakEffort: return "widget_peak"
        }
    }

    /// Le JSON brut d'une fenêtre.
    static func fenetre(_ kind: WidgetKind, _ fen: ChambreEtat.Fenetre) async throws -> [String: Any] {
        let o = try await objet(nomFonction(kind), corps: ["p_fenetre": fen.rawValue])
        if o["erreur"] as? String == "sans_session" { throw Erreur.sansSession }
        return o
    }

    /// Traduit la réponse dans une fenêtre VIDE du téléphone (qui apporte ses
    /// dates, son libellé, la grille des jours). Rend le nombre de séances
    /// que le serveur connaît sur la fenêtre — 0 = rien à afficher de lui.
    @discardableResult
    static func traduire(_ kind: WidgetKind, json o: [String: Any], dans f: inout ChambreFenetre) -> Int {
        switch kind {
        case .regularite: return regularite(o, &f)
        case .volume:     return volume(o, &f)
        case .hiitPeak:   return hiit(o, &f)
        case .peakEffort: return peak(o, &f)
        }
    }

    private static func regularite(_ o: [String: Any], _ f: inout ChambreFenetre) -> Int {
        f.faites = ent(o["faites"]) ?? 0
        f.precedent = ent(o["precedent"]) ?? 0
        f.suite = ent(o["suite_semaines"]) ?? 0
        f.recordSuite = ent(o["record_suite"]) ?? 0
        let cal = Calendar.current
        for j in tableau(o["jours"]) {
            guard let d = jour(j["jour"]),
                  let i = f.jours.firstIndex(where: { cal.isDate($0.date, inSameDayAs: d) }) else { continue }
            f.jours[i].seances = ent(j["seances"]) ?? 1
            f.jours[i].intensite = ent(j["intensite"]) ?? 1
            // le serveur ne dit pas la catégorie : le sticker de la maison
            if f.jours[i].sticker == nil { f.jours[i].sticker = WoopSticker.pour(categorie: nil) }
        }
        // LE DÉFI (13-09 soir) : le serveur rend le meilleur mois passé et les
        // séances du mois courant ; la projection se calcule ici, comme dans
        // `ChambreDonnees` (même rythme = faites / jours écoulés).
        f.defi = nil
        if let d = o["defi"] as? [String: Any], let cible = ent(d["cible"]) {
            var defi = ChambreDefi(cible: cible, moisCible: nomMois(d["mois_cible"]),
                                   faitesMois: ent(d["faites_mois"]) ?? 0, projection: nil)
            defi.dates = (d["dates"] as? [String] ?? []).compactMap { instant($0) }
            let ecoules = max(ent(d["jours_ecoules"]) ?? 1, 1)
            if defi.faitesMois > 0 {
                let rythme = Double(defi.faitesMois) / Double(ecoules)
                defi.rythme = rythme
                if defi.reste > 0 {
                    let jours = Int((Double(defi.reste) / rythme).rounded(.up))
                    if let quand = cal.date(byAdding: .day, value: jours, to: .now) {
                        defi.projection = ChambreFmt.dateLongue(quand)
                    }
                }
            }
            f.defi = defi
        }
        f.vide = f.faites == 0
        return f.faites
    }

    private static func volume(_ o: [String: Any], _ f: inout ChambreFenetre) -> Int {
        let seances = ent(o["seances"]) ?? 0
        f.volume = num(o["volume"])
        f.volumePrec = num(o["precedent"])
        f.parSeance = num(o["par_seance"])
        f.recordSemaine = num(o["record_semaine"])
        let total = max(f.volume, 1)
        var catParExo: [String: ExerciseCategory] = [:]
        let exos: [ChambreExo] = tableau(o["exercices"]).compactMap { e in
            guard let id = e["exercice_id"] as? String else { return nil }
            let (nom, cat) = identite(id: id, nom: e["nom"], categorie: e["categorie"])
            catParExo[id] = cat
            let v = num(e["volume"])
            return ChambreExo(id: id, nom: nom,
                              sticker: WoopSticker.pour(categorie: cat),
                              volume: v, reps: ent(e["reps"]) ?? 0, charge: num(e["charge_max"]),
                              part: v / total)
        }
        f.exos = Array(exos.prefix(3))
        var parCat: [ExerciseCategory: Double] = [:]
        for c in ExerciseCategory.allCases where c != .cardio { parCat[c] = 0 }
        for e in exos {
            if let c = catParExo[e.id] { parCat[c, default: 0] += e.volume }
        }
        f.categories = parCat
            .map { ChambreCategorie(categorie: $0.key, sticker: WoopSticker.pour(categorie: $0.key),
                                    volume: $0.value, part: $0.value / total) }
            .sorted { $0.volume > $1.volume }
        // le cumul : les jours du serveur, posés sur les points du téléphone
        // (7 jours, ou 5 pas de six jours en Mois — la même règle que
        // `ChambreDonnees.volume`)
        let n = f.cumul.isEmpty ? 7 : f.cumul.count
        f.cumul = cumul(joursVolume(o["jours"]), debut: f.debut, fin: f.fin, n: n)
        // LE FANTÔME (13-09 soir) : la fenêtre précédente jour par jour, posée
        // sur les mêmes points, décalés d'une fenêtre (7 ou 30 jours) — la
        // règle de `ChambreDonnees.volume`.
        let decalage = Double(n == 5 ? 30 : 7) * 86400
        let debutPrec = instant(o["debut_precedent"]) ?? f.debut.addingTimeInterval(-decalage)
        f.fantome = o["jours_precedent"] == nil ? [] :
            cumul(joursVolume(o["jours_precedent"]), debut: debutPrec,
                  fin: f.fin.addingTimeInterval(-decalage), n: n)
        f.vide = seances == 0
        return seances
    }

    private static func joursVolume(_ v: Any?) -> [(Date, Double)] {
        tableau(v).compactMap { j in
            guard let d = jour(j["jour"]) else { return nil }
            return (d, num(j["volume"]))
        }
    }

    /// Le cumul point par point : 7 jours, ou 5 pas de six jours en Mois.
    private static func cumul(_ jours: [(Date, Double)], debut: Date, fin: Date, n: Int) -> [Double] {
        (0..<n).map { k in
            let borne: Date = n == 5
                ? (k == 4 ? fin : debut.addingTimeInterval(Double(k + 1) * 6 * 86400))
                : debut.addingTimeInterval(Double(k + 1) * 86400)
            return jours.filter { $0.0 < borne }.reduce(0) { $0 + $1.1 }
        }
    }

    /// Le nom et la catégorie d'un exercice : ce que le serveur dit (table
    /// `exercices`), sinon le catalogue de l'app, sinon l'id nu.
    private static func identite(id: String, nom: Any?, categorie: Any?) -> (String, ExerciseCategory?) {
        let ex = ExerciseCatalog.exercise(id: id)
        let n = (nom as? String).flatMap { $0.isEmpty ? nil : $0 } ?? ex?.name ?? id
        let c = (categorie as? String).flatMap(ExerciseCategory.init(rawValue:)) ?? ex?.category
        return (n, c)
    }

    private static let cal = Calendar.current

    /// « 2026-08 » → « août ».
    private static func nomMois(_ v: Any?) -> String {
        guard let s = v as? String else { return "" }
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM"; f.timeZone = .current
        guard let d = f.date(from: s) else { return s }
        let g = DateFormatter(); g.locale = Locale(identifier: "fr_FR"); g.dateFormat = "MMMM"
        return g.string(from: d)
    }

    private static func hiit(_ o: [String: Any], _ f: inout ChambreFenetre) -> Int {
        let seuil = num(o["seuil"]) > 0 ? num(o["seuil"]) : SemaineStats.seuilEffort
        f.picMax = num(o["pic"]); f.picPrec = num(o["pic_precedent"])
        f.efforts = ent(o["efforts"]) ?? 0; f.effortsPrec = ent(o["efforts_precedent"]) ?? 0
        f.tempsPics = ent(o["temps_pics"]) ?? 0; f.tempsPicsPrec = ent(o["temps_pics_precedent"]) ?? 0
        let fmt = DateFormatter(); fmt.locale = Locale(identifier: "fr_FR"); fmt.dateFormat = "EEEE dd.MM"
        let seances: [ChambreSeanceHiit] = tableau(o["seances"]).compactMap { s in
            guard let d = instant(s["debut"]) else { return nil }
            let segs = tableau(s["segments"]).map { g in
                SegmentHiit(secondes: ent(g["secondes"]) ?? 0, vitesse: num(g["vitesse"]),
                            effort: (g["effort"] as? Bool) ?? (num(g["vitesse"]) >= seuil))
            }
            return ChambreSeanceHiit(date: d, jour: fmt.string(from: d).capitalized,
                                     pic: num(s["pic"]), segments: segs)
        }.sorted { $0.date < $1.date }
        f.seancesHiit = seances
        let recups = seances.flatMap(\.segments).filter { !$0.effort }
        f.recupMoy = ent(o["recup_moy"])
            ?? (recups.isEmpty ? 0 : recups.reduce(0) { $0 + $1.secondes } / recups.count)
        let dates = seances.map(\.date)
        f.plusLongTrou = ent(o["plus_long_trou"]) ?? (dates.count > 1
            ? (zip(dates, dates.dropFirst()).map { Int($1.timeIntervalSince($0) / 86400) }.max() ?? 0) : 0)
        // La fenêtre précédente (13-09 soir) : rendue par le serveur ; si la
        // clé manque on ne pose pas un fait qu'on n'a pas (delta 0 = le bilan le tait).
        f.recupMoyPrec = ent(o["recup_moy_precedent"]) ?? f.recupMoy
        f.plusLongTrouPrec = ent(o["plus_long_trou_precedent"]) ?? f.plusLongTrou
        // Les quatre semaines du record, S-3 → cette semaine (le même ordre que
        // `ChambreDonnees.hiit`) ; absentes → quatre zéros, le record reste gris.
        let pics4 = (o["pics4"] as? [Any])?.map(num) ?? []
        f.pics4 = pics4.count == 4 ? pics4 : [0, 0, 0, 0]
        let cal = Calendar.current
        for s in seances {
            if let i = f.jours.firstIndex(where: { cal.isDate($0.date, inSameDayAs: s.date) }) {
                f.jours[i].picHiit = max(f.jours[i].picHiit ?? 0, s.pic)
            }
        }
        f.vide = seances.isEmpty
        return seances.count
    }

    private static func peak(_ o: [String: Any], _ f: inout ChambreFenetre) -> Int {
        struct Pic { var id: String; var nom: String; var cat: ExerciseCategory?
                     var charge: Double; var reps: Int; var delta: Double?; var e1rm: Double }
        let pics: [Pic] = tableau(o["pics"]).compactMap { p in
            guard let id = p["exercice_id"] as? String else { return nil }
            let (nom, cat) = identite(id: id, nom: p["nom"], categorie: p["categorie"])
            let premier = (p["premier"] as? Bool) ?? (p["delta"] == nil || p["delta"] is NSNull)
            return Pic(id: id, nom: nom, cat: cat,
                       charge: num(p["charge"]), reps: ent(p["reps"]) ?? 0,
                       delta: premier ? nil : num(p["delta"]), e1rm: num(p["e1rm"]))
        }
        guard !pics.isEmpty else { f.peak = nil; return 0 }
        let topID = o["meilleur_exercice"] as? String
        let top = pics.first(where: { $0.id == topID }) ?? pics[0]
        let poids = ChambreFmt.poids
        f.peak = PeakEffortInfo(
            titre: top.nom,
            valeur: "\(poids(top.charge)) kg",
            delta: (top.delta ?? 0) > 0 ? "+\(poids(top.delta!))" : nil,
            precedent: top.delta.map { poids(top.charge - $0) },
            chambreHaut: "\(poids(top.charge)) kg × \(top.reps)",
            chambreBas: top.delta.map { "previous best · \(poids(top.charge - $0)) kg" } ?? "first time",
            nouveau: (top.delta ?? 0) > 0)
        f.e1rm = top.e1rm > 0 ? top.e1rm : top.charge * (1 + Double(top.reps) / 30)
        f.recordsBattus = ent(o["records_battus"]) ?? 0
        f.autres = pics.filter { $0.id != top.id }.map {
            ChambreAutrePic(id: $0.id, nom: $0.nom, sticker: WoopSticker.pour(categorie: $0.cat),
                            charge: $0.charge, reps: $0.reps, delta: $0.delta)
        }
        f.ascension = tableau(o["ascension"]).compactMap { m in
            guard let d = jour(m["jour"]) else { return nil }
            return ChambreMarche(date: d, charge: num(m["charge"]))
        }
        // « Depuis le dernier record » : le serveur le compte (13-09 soir) ;
        // sinon, la dernière marche de l'ascension.
        f.depuisRecord = ent(o["depuis_record"])
        if f.depuisRecord == nil, let d = f.ascension.last?.date {
            f.depuisRecord = Calendar.current.dateComponents([.day], from: d, to: .now).day
        }
        f.vide = false
        return pics.count
    }

    /// Ce que la traduction a tiré des clés du 13-09 soir — pour le journal
    /// `[chambre-serveur]`, afin qu'une mesure LISE ce qui a été consommé.
    static func detail(_ kind: WidgetKind, _ f: ChambreFenetre) -> String {
        switch kind {
        case .regularite:
            guard let d = f.defi else { return "défi —" }
            return "défi \(d.faitesMois)/\(d.cible) (\(d.moisCible), \(d.dates.count) dates\(d.projection.map { ", → \($0)" } ?? ""))"
        case .volume:
            let exo = f.exos.first.map { "\($0.nom) · \($0.sticker)" } ?? "—"
            return "fantôme \(f.fantome.count) pts (\(Int(f.fantome.last ?? 0)) kg) · exo \(exo)"
        case .hiitPeak:
            return "pics4 \(f.pics4.map { String(format: "%.0f", $0) }.joined(separator: "/")) · récup \(f.recupMoy) s vs \(f.recupMoyPrec) · trou \(f.plusLongTrou) j vs \(f.plusLongTrouPrec)"
        case .peakEffort:
            let top = f.peak.map { "\($0.titre) \($0.valeur)" } ?? "—"
            return "\(top) · depuis \(f.depuisRecord.map(String.init) ?? "—") j · autres \(f.autres.map(\.nom).joined(separator: ", "))"
        }
    }

    // MARK: - Lire le JSON de PostgREST

    private static func tableau(_ v: Any?) -> [[String: Any]] { v as? [[String: Any]] ?? [] }

    private static func num(_ v: Any?) -> Double {
        if let d = v as? Double { return d }
        if let n = v as? NSNumber { return n.doubleValue }
        if let s = v as? String, let d = Double(s) { return d }
        return 0
    }

    private static func ent(_ v: Any?) -> Int? {
        if let i = v as? Int { return i }
        if let n = v as? NSNumber { return n.intValue }
        if let s = v as? String, let i = Int(s) { return i }
        return nil
    }

    /// « 2026-09-08 » (une `date` Postgres) → minuit local.
    private static func jour(_ v: Any?) -> Date? {
        guard let s = v as? String else { return nil }
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"; f.timeZone = .current
        return f.date(from: s)
    }

    /// « 2026-09-12T15:45:00+00:00 » (un `timestamptz`), avec ou sans fraction.
    private static func instant(_ v: Any?) -> Date? {
        guard let s = v as? String else { return nil }
        let a = ISO8601DateFormatter(); a.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = a.date(from: s) { return d }
        let b = ISO8601DateFormatter(); b.formatOptions = [.withInternetDateTime]
        return b.date(from: s)
    }

    // MARK: - L'appel nu (la forme de `SacreServeur.rpc`, avec la session courante)

    private static func objet(_ nom: String, corps: [String: Any] = [:]) async throws -> [String: Any] {
        let data = try await rpc(nom, corps: corps)
        let json = try JSONSerialization.jsonObject(with: data)
        // PostgREST rend tantôt l'objet, tantôt un tableau d'une ligne.
        if let o = json as? [String: Any] { return o }
        if let a = json as? [[String: Any]], let p = a.first { return p }
        throw Erreur.reponse
    }

    private static func rpc(_ nom: String, corps: [String: Any] = [:]) async throws -> Data {
        let jwt = try await SupabaseSession.shared.token()
        var req = URLRequest(url: WoopConfig.supabaseURL.appending(path: "rest/v1/rpc/\(nom)"))
        req.httpMethod = "POST"
        req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        req.setValue(WoopConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = corps.isEmpty ? Data("{}".utf8) : try JSONSerialization.data(withJSONObject: corps)
        let (data, rep) = try await URLSession.shared.data(for: req)
        let code = (rep as? HTTPURLResponse)?.statusCode ?? 0
        guard (200 ..< 300).contains(code) else {
            let detail = (try? JSONSerialization.jsonObject(with: data))
                .flatMap { $0 as? [String: Any] }
                .flatMap { $0["message"] as? String } ?? ""
            throw Erreur.http(code, detail)
        }
        return data
    }
}
