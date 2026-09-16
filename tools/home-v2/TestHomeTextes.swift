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
        var lecture = HomeLecture()
        var tirages = 0
        func contexte(_ visible: Bool, _ signature: String) -> HomeLecture.Contexte {
            .init(visible: visible, signature: signature)
        }
        func choisir() -> HomeVariante? {
            tirages += 1
            return lots[0].variantes["seance"]![tirages % 3]
        }
        precondition(!lecture.actualiser(contexte(false, "fr:seance:0"), choisir: choisir))
        precondition(tirages == 0 && lecture.numero == 0)
        precondition(lecture.actualiser(contexte(true, "fr:seance:0"), choisir: choisir))
        let premiere = lecture.variante
        for _ in 0..<60 {
            precondition(!lecture.actualiser(contexte(true, "fr:seance:0"), choisir: choisir))
        }
        precondition(tirages == 1 && lecture.variante == premiere)
        for palier in 1...6 {
            precondition(!lecture.actualiser(contexte(false, "fr:seance:\(palier)"), choisir: choisir))
        }
        precondition(tirages == 1 && !lecture.presente)
        precondition(lecture.actualiser(contexte(true, "fr:seance:6"), choisir: choisir))
        precondition(tirages == 2 && lecture.variante != premiere) // un seul retour, aucun rattrapage
        precondition(lecture.actualiser(contexte(true, "fr:seance:7"), choisir: choisir))
        precondition(lecture.actualiser(contexte(true, "en:seance:7"), choisir: choisir))
        precondition(tirages == 4 && lecture.numero == 4)
        print("Visibilité : aucun tirage caché, retour unique, relecture au palier/langue, aucun rejeu par recalcul : PASS")
        print("Modèle Swift : FR/EN, vrais nombres/prénom, singuliers, 3 sacs complets sans répétition : PASS")
    }
}
