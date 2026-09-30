import CryptoKit
import SwiftUI

// MARK: - La matière d'une légendaire (30-09-2026)

/// LE KIT DE LA QUATRE LUNES, cuit une fois par carte depuis son image
/// (`tools/carte-lune/cuire_matiere.py`) — aucune coordonnée écrite à la
/// main, la même recette pour les 50 cartes et les trois mondes :
///   relief   R, G la normale de la gravure · B son poids (matière, filigrane)
///   vie      R les sources du feu · G le ciel · B les éclats de la créature
///   souffle  R le sujet · G la lueur des sources · B la nacre
/// réunis dans UN atlas (2172×2172 : SwiftUI refuse plus de trois textures
/// par passage), et un json (monde, centre du sujet, noms). `carteLuneV6`
/// les lit.
///
/// OÙ IL VIT.
/// - DANS L'APP (manège, collection) : publié au serveur par
///   `tools/carte-lune/publier_matiere.py`, dans le bucket public `cards` —
///   `matiere/<card_id>.json` (le pointeur) et `matiere/<sha256>.png`
///   (l'atlas, par empreinte). `CarteVivante` le va chercher elle-même dès
///   qu'on lui donne l'identifiant d'une légendaire : toute légendaire
///   publiée le reçoit, celles déjà obtenues comprises (sa demande du
///   30-09 : « même celles déjà obtenues par Margaux »).
/// - AU BANC : Documents/matiere/<nom>/, posé au simulateur par
///   `tools/carte-lune/poser_matiere_sim.sh` (`-luneLab -luneCarte <nom>`).
struct LuneMatiere {
    let atlas: Image
    /// 0 Forêt des Veilles · 1 Cimes éteintes · 2 Bois sans lune.
    let monde: Float
    /// Le centre du sujet, en fractions de la carte (le souffle s'y ancre).
    let centre: CGPoint
    /// Le nom de la carte et de son monde, FR / EN (la cérémonie les grave).
    var noms: [String: String] = [:]
    var mondeNoms: [String: String] = [:]

    /// LES BARREAUX du passage légendaire (bits de `carteLuneV6`) : chaque
    /// moteur peut être accusé seul, au banc comme sur le téléphone.
    static let barreaux: Float = {
        let a = CommandLine.arguments
        var b = 0
        if a.contains("-sansRelief") { b |= 1 }
        if a.contains("-sansBraises") { b |= 2 }
        if a.contains("-sansNeige") { b |= 4 }
        if a.contains("-sansPaillettes") { b |= 8 }
        if a.contains("-sansSouffle") { b |= 16 }
        if a.contains("-sansLampe") { b |= 32 }
        // -luneSonde : la sonde de l'atlas (valeurs brutes ou linéarisées ?)
        if a.contains("-luneSonde") { b |= 64 }
        return Float(b)
    }()

    // MARK: L'interrupteur

    /// L'INTERRUPTEUR SERVEUR : `reward_rules.legendaire_matiere`, lu avec
    /// les règles des annonces à l'apparition de la home
    /// (`DecideurSerie.chargerRegles`). Faux : toutes les légendaires
    /// reviennent au rendu d'avant (V5), sans nouvelle version de l'app —
    /// la porte de secours si la chauffe mesurée sur son iPhone le demande.
    @MainActor static var interrupteur = true

    /// `-sansMatiere` : le BARREAU produit — la légendaire d'avant, pour
    /// mesurer le coût de la matière A/B sur le téléphone.
    static let sansMatiere = CommandLine.arguments.contains("-sansMatiere")

    @MainActor static var actif: Bool { interrupteur && !sansMatiere }

    // MARK: La matière publiée (le produit)

    /// Le cache mémoire : une carte ouverte deux fois ne relit rien.
    @MainActor private static var memoire: [String: LuneMatiere] = [:]
    /// Les cartes sans kit publié (une carte non légendaire, un 404) — on
    /// ne redemande pas pendant ce lancement.
    @MainActor private static var sansKit: Set<String> = []

    private static let racine = ForgeServeur.base
        .appending(path: "storage/v1/object/public/cards")

    private static var cache: URL {
        let d = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appending(path: "matiere")
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    /// LE KIT PUBLIÉ d'une carte, par son identifiant serveur : le pointeur
    /// `matiere/<card_id>.json` (relu au réseau, le cache disque en repli
    /// hors ligne), puis l'atlas qu'il nomme — téléchargé une fois, VÉRIFIÉ
    /// par son empreinte, gardé sur le disque. nil : pas de kit (carte non
    /// légendaire), interrupteur coupé, ou rien de lisible.
    @MainActor static func publiee(cardId: String) async -> LuneMatiere? {
        guard actif else { return nil }
        let id = cardId.lowercased()
        if let m = memoire[id] { return m }
        guard !sansKit.contains(id) else { return nil }
        let fichierPointeur = cache.appending(path: "\(id).json")

        var pointeur: Data?
        var req = URLRequest(url: racine.appending(path: "matiere/\(id).json"))
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.timeoutInterval = 8
        if let (data, rep) = try? await URLSession.shared.data(for: req),
           let code = (rep as? HTTPURLResponse)?.statusCode {
            if code == 200 {
                pointeur = data
                try? data.write(to: fichierPointeur, options: .atomic)
            } else if code == 400 || code == 404 {
                // Pas de kit publié pour cette carte : on n'insiste pas.
                sansKit.insert(id)
                try? FileManager.default.removeItem(at: fichierPointeur)
                return nil
            }
        }
        if pointeur == nil { pointeur = try? Data(contentsOf: fichierPointeur) }
        guard let pointeur,
              let m = (try? JSONSerialization.jsonObject(with: pointeur)) as? [String: Any],
              let chemin = m["atlas"] as? String,
              let empreinte = (m["sha256"] as? String)?.lowercased()
        else { return nil }

        let fichierAtlas = cache.appending(path: "\(empreinte).png")
        var atlas = try? Data(contentsOf: fichierAtlas)
        if atlas == nil {
            var r = URLRequest(url: racine.appending(path: chemin))
            r.timeoutInterval = 20
            guard let (data, rep) = try? await URLSession.shared.data(for: r),
                  (rep as? HTTPURLResponse)?.statusCode == 200,
                  SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == empreinte
            else {
                print("[matiere] \(id) : atlas illisible ou empreinte fausse — la carte reste en V5")
                return nil
            }
            try? data.write(to: fichierAtlas, options: .atomic)
            atlas = data
        }
        guard let atlas, let image = UIImage(data: atlas) else { return nil }
        let centre = (m["centre"] as? [Double]).flatMap { c in
            c.count == 2 ? CGPoint(x: c[0], y: c[1]) : nil
        } ?? CGPoint(x: 0.5, y: 0.5)
        let kit = LuneMatiere(atlas: Image(uiImage: image),
                              monde: Float((m["monde_code"] as? Int) ?? 0),
                              centre: centre,
                              noms: m["noms"] as? [String: String] ?? [:],
                              mondeNoms: m["monde_noms"] as? [String: String] ?? [:])
        memoire[id] = kit
        print("[matiere] \(id) : kit publié chargé (atlas \(empreinte.prefix(8)))")
        return kit
    }

    /// Le kit déjà chargé (le manège l'a pris pendant l'ouverture) — sans
    /// attendre : la cérémonie ne se joue que s'il est là.
    @MainActor static func enMemoire(cardId: String?) -> LuneMatiere? {
        guard actif, let cardId else { return nil }
        return memoire[cardId.lowercased()]
    }

    // MARK: Le banc (Documents/matiere/<nom>/)

    private static func dossier(_ nom: String) -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first?.appending(path: "matiere/\(nom)")
    }

    private static func meta(_ nom: String) -> [String: Any]? {
        guard let d = dossier(nom),
              let data = try? Data(contentsOf: d.appending(path: "\(nom)-matiere.json"))
        else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func png(_ nom: String, _ suffixe: String) -> UIImage? {
        guard let d = dossier(nom) else { return nil }
        return UIImage(contentsOfFile: d.appending(path: "\(nom)-\(suffixe).png").path)
    }

    /// L'illustration NUE de la référence (celle que le serveur publie).
    static func illustration(nom: String) -> UIImage? { png(nom, "illustration") }

    static func rarete(nom: String) -> String? { meta(nom)?["rarete"] as? String }

    /// Le kit complet, ou nil s'il manque une pièce (la carte reste en V5).
    static func charger(nom: String) -> LuneMatiere? {
        guard let m = meta(nom), let atlas = png(nom, "matiere") else { return nil }
        let centre = (m["centre"] as? [Double]).flatMap { c in
            c.count == 2 ? CGPoint(x: c[0], y: c[1]) : nil
        } ?? CGPoint(x: 0.5, y: 0.5)
        return LuneMatiere(atlas: Image(uiImage: atlas),
                           monde: Float((m["monde_code"] as? Int) ?? 0),
                           centre: centre,
                           noms: m["noms"] as? [String: String] ?? [:],
                           mondeNoms: m["monde_noms"] as? [String: String] ?? [:])
    }
}
