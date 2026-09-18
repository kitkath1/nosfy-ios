import SwiftUI

// ════════════════════════════════════════════════════════════════════════
// LA CHAMBRE REGULARITY — le design tranché les 05 → 07-09
//
//  · l'objectif se change au doigt depuis le héros (3 → 10) ;
//  · le calendrier à stickers, avec les halos d'intensité et sa légende ;
//  · « Résumé » : la régularité, rien d'autre — pas un kilo ;
//  · « Le défi » : le chiffre, une phrase, la piste, la projection.
// ════════════════════════════════════════════════════════════════════════

struct ChambreRegularite: View {
    let f: ChambreFenetre
    let fenetre: ChambreEtat.Fenetre
    /// Le cran tapé dans la piste du défi : sa date (faite ou projetée) se dit.
    @State private var cran: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 46) {
            calendrier
            resume
            defi
        }
    }

    private var calendrier: some View {
        VStack(alignment: .leading, spacing: 14) {
            BlocTitre(texte: fenetre == .semaine ? L("Cette semaine", "This week") : L("Cinq semaines", "Five weeks"), droite: f.libelle)
            ChambreGrille(jours: f.jours, montrerPic: false, stickers: true)
            LegendeHalo().padding(.top, 2)
        }
        .chambreVide(f.vide)
    }

    private var resume: some View {
        VStack(alignment: .leading, spacing: 4) {
            BlocTitre(texte: L("Résumé", "Summary"))
            ligne(valeur: "\(f.faites)",
                  nom: fenetre == .semaine ? L("Séances cette semaine", "Sessions this week") : L("Séances ce mois-ci", "Sessions this month"),
                  sous: f.precedent == 0
                      ? "Aucune \(fenetre == .semaine ? "la semaine passée" : "le mois passé")"
                      : L("Contre \(f.precedent) \(fenetre == .semaine ? "la semaine passée" : "le mois passé")", "Vs \(f.precedent) \(fenetre == .semaine ? "last week" : "last month")"),
                  delta: f.delta)
            ligne(valeur: "\(f.suite)", nom: L("Semaine\(f.suite > 1 ? "s" : "") d'affilée", "Week\(f.suite > 1 ? "s" : "") in a row"),
                  sous: L("Ton record : \(f.recordSuite) semaine\(f.recordSuite > 1 ? "s" : "")", "Your best: \(f.recordSuite) week\(f.recordSuite > 1 ? "s" : "")"), delta: nil)
        }
        .chambreVide(f.vide && f.suite == 0)
    }

    private func ligne(valeur: String, nom: String, sous: String, delta: Int?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(valeur).font(.inter(26, .semibold)).encreMetal().frame(minWidth: 52, alignment: .leading)
            VStack(alignment: .leading, spacing: 5) {
                Text(nom).font(.system(size: 13)).foregroundStyle(CardTon.encreDouce)
                Text(sous).font(.system(size: 10.5)).foregroundStyle(ChambreTon.encre4)
            }
            Spacer(minLength: 8)
            if let d = delta, d != 0 {
                HStack(spacing: 5) {
                    ChevronIndic(monte: d > 0)
                    Text("\(d > 0 ? "+" : "−")\(abs(d))")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(d > 0 ? ChambreTon.vert : ChambreTon.rouge)
                }
            }
        }
        .padding(.vertical, 11)
    }

    /// Le défi a trois états, et le design est le même pour les trois : le
    /// chiffre, la phrase, la piste, la ligne du rythme.
    ///  · pas d'historique → tirets, gris (la loi du vide) ;
    ///  · en cours → « 3 séances pour battre août » ;
    ///  · record tombé → « 8 séances ce mois-ci · août est battu ».
    private var defi: some View {
        let d = f.defi
        return VStack(alignment: .leading, spacing: 0) {
            BlocTitre(texte: L("Le défi", "The challenge"))
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text(defiChiffre(d)).font(.inter(40, .semibold)).encreMetal()
                VStack(alignment: .leading, spacing: 6) {
                    Text(defiPhrase(d)).font(.system(size: 13.5)).foregroundStyle(CardTon.encreDouce)
                    Text(defiSous(d)).font(.system(size: 10.5)).foregroundStyle(ChambreTon.encre4)
                }
            }
            .padding(.top, 16)
            PisteDefi(cible: d.map { max($0.cible + 1, $0.faitesMois) } ?? 14,
                      faits: d?.faitesMois ?? 0, choisi: cran) { i in
                guard d != nil else { return }
                UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.5)
                withAnimation(.easeOut(duration: 0.2)) { cran = cran == i ? nil : i }
            }
            .frame(height: 24)
            .padding(.top, 15)
            // La ligne sous la piste ne dit qu'une DATE : la projection du
            // record, ou le cran tapé. Jamais une phrase qui commente
            // (verdict du 13-09 : pas de mini-texte parasite).
            if let ligne = defiLigne(d) {
                Text(ligne)
                    .font(.system(size: 11.5))
                    .foregroundStyle(cran == nil ? ChambreTon.encre4 : CardTon.encreDouce)
                    .animation(.easeOut(duration: 0.2), value: cran)
                    .padding(.top, 11)
            }
        }
        .chambreVide(d == nil)
    }

    private func defiChiffre(_ d: ChambreDefi?) -> String {
        guard let d else { return "—" }
        return d.battu ? "\(d.faitesMois)" : "\(d.reste)"
    }

    private func defiPhrase(_ d: ChambreDefi?) -> String {
        guard let d else { return L("Séances pour battre ton meilleur mois", "Sessions to beat your best month") }
        if d.battu { return L("Séances ce mois-ci · \(d.moisCible.capitalized) est battu", "Sessions this month · \(d.moisCible.capitalized) beaten") }
        return "Séance\(d.reste > 1 ? "s" : "") pour battre \(d.moisCible)"
    }

    private func defiSous(_ d: ChambreDefi?) -> String {
        guard let d else { return L("Ton record : —", "Your best: —") }
        return d.battu ? L("Ton nouveau record · \(d.moisCible.capitalized) : \(d.cible)", "Your new best · \(d.moisCible.capitalized): \(d.cible)") : L("Ton record : \(d.cible)", "Your best: \(d.cible)")
    }

    /// La ligne sous la piste : une date — celle du record projeté, ou celle
    /// du cran tapé (faite, ou projetée au rythme du mois). Sinon rien.
    private func defiLigne(_ d: ChambreDefi?) -> String? {
        guard let d else { return nil }
        if let c = cran {
            if c < d.dates.count { return "Séance \(c + 1) · \(ChambreFmt.jourLong(d.dates[c]))" }
            if let r = d.rythme, r > 0 {
                let jours = Double(c + 1 - d.faitesMois) / r
                let quand = Date.now.addingTimeInterval(jours.rounded(.up) * 86400)
                return "Séance \(c + 1) · vers le \(ChambreFmt.dateLongue(quand))"
            }
            return nil
        }
        if let p = d.projection, !d.battu { return "À ce rythme, record battu le \(p)" }
        return nil
    }
}

/// La piste : un cran par séance à faire, ceux qui sont faits brûlent le
/// long de la rampe, le dernier à prendre porte un liseré. Un cran se tape :
/// il prend un liseré blanc et l'hôte dit sa date.
struct PisteDefi: View {
    var cible: Int
    var faits: Int
    var choisi: Int? = nil
    var onTap: (Int) -> Void = { _ in }
    @State private var apparu = false

    var body: some View {
        GeometryReader { g in
            let n = max(cible, 1)
            let gout: CGFloat = n > 16 ? 2 : 3
            let w = (g.size.width - gout * CGFloat(n - 1)) / CGFloat(n)
            HStack(spacing: gout) {
                ForEach(0..<n, id: \.self) { i in
                    cran(i, n: n, w: w)
                }
            }
        }
        .task { withAnimation { apparu = true } }
    }

    private func cran(_ i: Int, n: Int, w: CGFloat) -> some View {
        let fait = i < faits
        let dernier = i == n - 1
        let mien = choisi == i
        let t = Double(i) / Double(max(n - 1, 1))
        return Capsule()
            .fill(fait ? AnyShapeStyle(CardTon.chaleur(0.20 + 0.75 * t)) : AnyShapeStyle(Color(white: 0.35).opacity(0.45)))
            .frame(width: w, height: dernier || mien ? 13 : 10)
            .overlay {
                if mien {
                    Capsule().strokeBorder(Color.white.opacity(0.75), lineWidth: 1)
                } else if dernier, !fait {
                    Capsule().strokeBorder(CardTon.chaleur(0.78).opacity(0.35), lineWidth: 1)
                }
            }
            .shadow(color: fait && i == faits - 1 ? CardTon.chaleur(0.78).opacity(0.8) : .clear, radius: 6)
            .opacity(apparu ? 1 : 0)
            .animation(.easeOut(duration: 0.3).delay(Double(i) * 0.05), value: apparu)
            .frame(width: w, height: 24)
            .contentShape(Rectangle())
            .onTapGesture { onTap(i) }
    }
}
