import Foundation

/// Le serveur fournit des gabarits sans donnée personnelle. Les faits restent
/// ceux des widgets et de la séance du téléphone, même hors ligne.
struct HomeVariante: Codable, Equatable {
    let id: String
    let fragments: [String]
    let bouton: String?

    func mots(prenom: String?, nombre: Int, langue: String) -> [String] {
        let en = langue == "en"
        let nom = prenom?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let salut = en ? (nom.isEmpty ? "Hello there," : "Hello \(nom),")
                       : (nom.isEmpty ? "Salut," : "Salut \(nom),")
        let allez = en ? (nom.isEmpty ? "Alright," : "Alright \(nom),")
                       : (nom.isEmpty ? "Allez," : "Allez \(nom),")
        let n = max(0, nombre)
        let seances = en ? "\(n) \(n == 1 ? "workout" : "workouts")"
                         : "\(n) \(n > 1 ? "séances" : "séance")"
        let minutes = "\(n) \(n > 1 || (en && n == 0) ? "minutes" : "minute")"
        return fragments.map { ligne in
            ligne.replacingOccurrences(of: "{salut}", with: salut)
                .replacingOccurrences(of: "{allez}", with: allez)
                .replacingOccurrences(of: "{seances}", with: seances)
                .replacingOccurrences(of: "{minutes}", with: minutes)
        }
    }
}

struct HomeLot: Codable, Equatable {
    let schema: Int
    let langue: String
    let revision: String
    let variantes: [String: [HomeVariante]]

    var valide: Bool {
        guard schema == 1, ["fr", "en"].contains(langue), !revision.isEmpty else { return false }
        for etat in ["vide", "active_zero", "active", "seance_debut", "seance", "depart"] {
            guard let lignes = variantes[etat], !lignes.isEmpty, lignes.count <= 60,
                  Set(lignes.map(\.id)).count == lignes.count else { return false }
            for v in lignes {
                guard !v.id.isEmpty, v.fragments.count == (etat == "depart" ? 3 : 4),
                      v.fragments.allSatisfy({ !$0.isEmpty && $0.count <= 80 && !$0.contains("\n") }) else { return false }
                if etat == "depart", v.bouton?.isEmpty != false { return false }
                if etat == "active", v.fragments[2] != "{seances}" { return false }
                if etat == "seance", v.fragments[2] != "{minutes}" { return false }
            }
        }
        return true
    }
}

/// Un sac par langue/révision/surface. Aucun tirage dans le rendu SwiftUI.
struct HomeSac {
    private var restants: [HomeVariante] = []
    private var dernier: String?
    private var signature = ""

    mutating func tirer(_ variantes: [HomeVariante], cle: String) -> HomeVariante? {
        guard !variantes.isEmpty else { return nil }
        if signature != cle { restants = []; signature = cle }
        if restants.isEmpty {
            restants = variantes.shuffled()
            if restants.count > 1, restants[0].id == dernier { restants.swapAt(0, 1) }
        }
        let v = restants.removeFirst()
        dernier = v.id
        return v
    }
}

@MainActor
enum HomeTextes {
    static let cleRevision = "woop.homeTextes.revision"
    private static var charges: [String: HomeLot] = [:]
    private static var sac = HomeSac()
    private static let embarques: [String: HomeLot] = {
        guard let url = Bundle.main.url(forResource: "home-textes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let lots = try? JSONDecoder().decode([HomeLot].self, from: data) else { return [:] }
        return Dictionary(uniqueKeysWithValues: lots.filter(\.valide).map { ($0.langue, $0) })
    }()

    static func garder(_ lot: HomeLot?) {
        guard let lot, lot.valide, let data = try? JSONEncoder().encode(lot) else { return }
        charges[lot.langue] = lot
        UserDefaults.standard.set(data, forKey: "woop.homeTextes.\(lot.langue)")
        UserDefaults.standard.set("\(lot.langue):\(lot.revision)", forKey: cleRevision)
    }

    static func lot(_ langue: String = Langue.courante) -> HomeLot? {
        if let lot = charges[langue] { return lot }
        if let data = UserDefaults.standard.data(forKey: "woop.homeTextes.\(langue)"),
           let lot = try? JSONDecoder().decode(HomeLot.self, from: data), lot.valide, lot.langue == langue {
            charges[langue] = lot
            return lot
        }
        return embarques[langue]
    }

    /// Stable entre deux changements de faits ; une minute n'épuise pas le sac.
    static func phrase(_ etat: String, nombre: Int = 0) -> [String]? {
        guard let lot = lot(), let choix = lot.variantes[etat], !choix.isEmpty else { return nil }
        let index = etat == "seance" ? palier(nombre) : max(0, nombre)
        return choix[index % choix.count].mots(prenom: ProfilServeur.prenomLocal,
                                              nombre: nombre, langue: lot.langue)
    }

    static func depart() -> (fragments: [String], bouton: String) {
        guard let lot = lot(), let choix = lot.variantes["depart"],
              let v = sac.tirer(choix, cle: "\(lot.langue):\(lot.revision)") else {
            return ([L("Allez,", "Alright,"), L("glisse pour lancer", "slide to start"),
                     L("ta séance.", "your session.")], L("C'est parti", "Let's go"))
        }
        return (v.mots(prenom: ProfilServeur.prenomLocal, nombre: 0, langue: lot.langue),
                v.bouton ?? L("C'est parti", "Let's go"))
    }

    static func palier(_ minutes: Int) -> Int {
        minutes < 5 ? 0 : (minutes < 15 ? 1 : 1 + minutes / 15)
    }
}
