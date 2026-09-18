#if DEBUG
import SwiftUI

/// Banc isolé : session QA fournie dans Documents, jamais dans le binaire ni les logs.
struct CartesQABanc: View {
    @ObservedObject private var collection = CollectionLune.shared
    @State private var pret = false
    @State private var erreur = false
    var body: some View {
        Group {
            if pret { RootView() }
            else { Color.black.overlay(Text(erreur ? "QA indisponible" : "QA…").foregroundStyle(.white)) }
        }.overlay(alignment: .bottom) {
            Text("orange=\(EconomieWoop.shared.boosters);noir=\(EconomieWoop.shared.boostersNoirs);references=\(collection.registres.values.reduce(0) { $0 + $1.count });exemplaires=\(collection.registres.values.flatMap { $0 }.reduce(0) { $0 + $1.count })")
                .font(.system(size: 1)).foregroundStyle(.clear).accessibilityIdentifier("cartes-qa-collection")
        }.task {
            guard !pret else { return }
            do {
                let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let data = try Data(contentsOf: docs.appending(path: "cartes-qa-session.json"))
                let j = try JSONSerialization.jsonObject(with: data) as! [String: String]
                await SupabaseSession.shared.adopter(access: j["access"]!, refresh: j["refresh"]!, userID: j["user"]!)
                await EconomieWoop.shared.rafraichir()
                await CollectionLune.shared.relire()
                if CommandLine.arguments.contains("-cartesExporter") {
                    let entree = try Data(contentsOf: docs.appending(path: "cartes-qa-arts.json"))
                    let arts = try JSONSerialization.jsonObject(with: entree) as! [[String: String]]
                    let dossier = docs.appending(path: "cartes-qa-rendus")
                    try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
                    for a in arts {
                        let url = docs.appending(path: a["fichier"]!)
                        let nue = UIImage(contentsOfFile: url.path)!
                        let image = try LuneForge.habiller(illustration: nue, rarete: a["rarete"]!).art
                        try image.pngData()!.write(to: dossier.appending(path: a["cle"]!+".png"))
                    }
                    try Data("14 arts sous le cadre réel".utf8).write(to: dossier.appending(path: "termine.txt"))
                }
                pret = true
            } catch { erreur = true }
        }
    }
}
#endif
