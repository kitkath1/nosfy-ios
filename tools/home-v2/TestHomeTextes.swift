import Foundation

// Les tests compilent le vrai modèle, sans charger SwiftUI ni ouvrir un compte.
enum Langue { static var courante: String { "fr" } }
enum ProfilServeur { static var prenomLocal: String? { "Éléonore" } }
func L(_ fr: String, _ en: String) -> String { fr }

@main struct TestHomeTextes {
    static func main() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
        let lots = try JSONDecoder().decode([HomeLot].self, from: data)
        precondition(lots.count == 2 && Set(lots.map(\.langue)) == ["fr", "en"])
        for lot in lots {
            precondition(lot.valide)
            let variantes = lot.variantes["depart"]!
            var sac = HomeSac()
            var precedent: String?
            for _ in 0..<3 {
                var vus = Set<String>()
                for _ in variantes {
                    let v = sac.tirer(variantes, cle: lot.langue)!
                    precondition(v.id != precedent && vus.insert(v.id).inserted)
                    precedent = v.id
                }
                precondition(vus.count == 27)
            }
            let nombre = lot.variantes["active"]![0]
            for n in [0, 1, 2, 123] {
                let mots = nombre.mots(prenom: "Éléonore", nombre: n, langue: lot.langue)
                precondition(mots[0].contains("Éléonore") && mots[2].hasPrefix("\(n) "))
                precondition(!mots.joined().contains("{"))
                if n == 1 { precondition(mots[2] == (lot.langue == "fr" ? "1 séance" : "1 workout")) }
            }
            let sansNom = nombre.mots(prenom: nil, nombre: 1, langue: lot.langue)
            precondition(!sansNom.joined().contains("Kathryn") && !sansNom[0].contains("nil"))
        }
        print("Modèle Swift : FR/EN, vrais nombres/prénom, singuliers, 3 sacs complets sans répétition : PASS")
    }
}
