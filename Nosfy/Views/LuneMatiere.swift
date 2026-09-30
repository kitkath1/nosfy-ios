import SwiftUI

// MARK: - La matière d'une légendaire (30-09-2026)

/// LE KIT DE LA QUATRE LUNES, cuit une fois par carte depuis son image
/// (`tools/carte-lune/cuire_matiere.py`) — aucune coordonnée écrite à la
/// main, la même recette pour les 50 cartes et les trois mondes :
///   relief   R, G la normale de la gravure · B son poids (matière, filigrane)
///   vie      R les sources du feu · G le ciel · B les éclats de la créature
///   souffle  R le sujet · G la lueur des sources · B la nacre
/// réunis dans UN atlas (`<nom>-matiere.png`, 2172×2172 : SwiftUI refuse
/// plus de trois textures par passage), et un json (rareté, monde, centre
/// du sujet). `carteLuneV6` les lit.
///
/// OÙ IL VIT. Au banc seulement, pour l'instant : Documents/matiere/<nom>/,
/// posé au simulateur par `tools/carte-lune/poser_matiere_sim.sh`. Le
/// produit (manège, collection) ne le reçoit PAS encore : la livraison des
/// masques par le serveur, avec l'illustration, est une étape à venir
/// (décision D3 du 29-09).
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
