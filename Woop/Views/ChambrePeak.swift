import SwiftUI

// ════════════════════════════════════════════════════════════════════════
// LA CHAMBRE PEAK — « l'Ascension », validée le 03-09, verrouillée
//
//  · « L'ascension » : toutes les marches du record — chaque fois que la
//    charge a monté — le passé qui recule par la lumière, la dernière qui
//    brûle, un fil pointillé qui les relie ;
//  · « Le compte » : la charge, le 1RM estimé, depuis le dernier record ;
//  · « Autres pics » : les autres charges max de la fenêtre ;
//  · « Records » : ce qui a été battu dans la fenêtre.
// Aucun séparateur : l'air sépare.
// ════════════════════════════════════════════════════════════════════════

struct ChambrePeak: View {
    let f: ChambreFenetre
    let fenetre: ChambreEtat.Fenetre

    private var vide: Bool { f.peak == nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 46) {
            ascension
            compte
            autres
            records
        }
    }

    private var ascension: some View {
        VStack(alignment: .leading, spacing: 14) {
            BlocTitre(texte: "L'ascension",
                      droite: vide ? "—" : "\(f.ascension.count) marche\(f.ascension.count > 1 ? "s" : "")")
            AscensionVue(marches: f.ascension, vide: vide)
                .frame(height: 190)
        }
        .chambreVide(vide)
    }

    private var compte: some View {
        VStack(alignment: .leading, spacing: 10) {
            BlocTitre(texte: "Le compte")
            Portee(items: [
                PorteeItem(valeur: f.peak?.valeur ?? "0 kg",
                           libelle: f.peak.map { "La charge, × \(reps($0))" } ?? "La charge", chaud: !vide),
                PorteeItem(valeur: vide ? "0 kg" : "\(ChambreFmt.poids(f.e1rm)) kg", libelle: "1RM estimé"),
                PorteeItem(valeur: f.depuisRecord.map { "\($0) j" } ?? "— j", libelle: "Depuis le dernier record"),
            ])
        }
        .chambreVide(vide)
    }

    private func reps(_ p: PeakEffortInfo) -> String {
        p.chambreHaut.split(separator: "×").last.map { String($0).trimmingCharacters(in: .whitespaces) } ?? "—"
    }

    private var autres: some View {
        VStack(alignment: .leading, spacing: 6) {
            BlocTitre(texte: "Autres pics", droite: fenetre == .semaine ? "Cette semaine" : "Ce mois")
            if f.autres.isEmpty {
                ForEach(0..<2, id: \.self) { _ in
                    RangExo(sticker: nil, nom: "—", sous: "× — · —", valeur: "0 kg", part: 0, vide: true, barre: false)
                }
            } else {
                ForEach(f.autres.prefix(4)) { a in
                    RangExo(sticker: a.sticker, nom: a.nom,
                            sous: "× \(a.reps) · \(a.delta == nil ? "Premier" : (a.delta! > 0 ? "Record" : "Égalé"))",
                            valeur: "\(ChambreFmt.poids(a.charge)) kg",
                            part: 0,
                            delta: (a.delta ?? 0) > 0 ? "+\(ChambreFmt.poids(a.delta!))" : nil,
                            barre: false)
                }
            }
        }
        .chambreVide(vide)
    }

    /// Les records battus dans la fenêtre : un galet par record, chaud.
    private var records: some View {
        VStack(alignment: .leading, spacing: 12) {
            BlocTitre(texte: "Records", droite: vide ? "—" : "\(f.recordsBattus) battu\(f.recordsBattus > 1 ? "s" : "")")
            HStack(spacing: 8) {
                ForEach(0..<max(f.recordsBattus, 5), id: \.self) { i in
                    let on = i < f.recordsBattus
                    Capsule().fill(on ? AnyShapeStyle(LinearGradient(colors: [CardTon.chaleur(0.85), CardTon.chaleur(0.55)], startPoint: .top, endPoint: .bottom))
                                      : AnyShapeStyle(Color.white.opacity(0.07)))
                        .frame(width: 18, height: 6)
                        .shadow(color: on ? CardTon.chaleur(0.5).opacity(0.5) : .clear, radius: 5)
                }
                Spacer(minLength: 0)
            }
        }
        .chambreVide(vide)
    }
}

// MARK: - L'ASCENSION

/// Les marches d'un record. Le passé recule par la lumière (0,35 → 0,85),
/// la dernière brûle et pose sa laque ; le fil pointillé se trace pendant
/// la montée. Tap une marche : sa date se dit.
struct AscensionVue: View {
    var marches: [ChambreMarche]
    var vide: Bool
    @State private var apparu = false
    @State private var choisie: Int?

    private var vals: [ChambreMarche] {
        vide ? [40, 45, 50, 55, 60].map { ChambreMarche(date: .distantPast, charge: $0) } : marches
    }

    var body: some View {
        GeometryReader { g in
            let n = vals.count
            let gout: CGFloat = n > 6 ? 6 : 10
            let w = (g.size.width - gout * CGFloat(n - 1)) / CGFloat(n)
            let sol = g.size.height - 30
            let lo = max((vals.map(\.charge).min() ?? 0) * 0.6, 0)
            let hi = max(vals.map(\.charge).max() ?? 1, lo + 1)
            ZStack(alignment: .topLeading) {
                fil(w: w, gout: gout, sol: sol, lo: lo, hi: hi)
                // Un rang = une fonction NOMMÉE (le mur du type-checker).
                ForEach(0..<n, id: \.self) { i in
                    rang(i, n: n, w: w, gout: gout, sol: sol, lo: lo, hi: hi)
                }
                if let c = choisie, !vide, c > 0 {
                    Text("\(ChambreFmt.jourCourt(vals[c].date)) · \(ChambreFmt.poids(vals[c].charge)) kg · +\(ChambreFmt.poids(vals[c].charge - vals[c - 1].charge)) sur la marche d'avant")
                        .font(.system(size: 11)).foregroundStyle(CardTon.encreSourde)
                        .offset(y: sol + 24).transition(.opacity)
                }
            }
        }
        .task { withAnimation { apparu = true } }
    }

    // swiftlint:disable:next function_parameter_count
    private func rang(_ i: Int, n: Int, w: CGFloat, gout: CGFloat,
                      sol: CGFloat, lo: Double, hi: Double) -> some View {
        let m = vals[i]
        let h: CGFloat = 18 + CGFloat((m.charge - lo) / (hi - lo)) * (sol - 44)
        let derniere = i == n - 1
        let avant = choisie.map { $0 == i } ?? derniere
        let op: Double = (derniere || choisie == i) ? 1 : 0.35 + (0.5 * Double(i) / Double(max(n - 1, 1)))
        let hh: CGFloat = apparu ? h : 2
        let x = CGFloat(i) * (w + gout)
        return ZStack(alignment: .topLeading) {
            marche(avant: avant, chaude: derniere && !vide, largeur: w)
                .frame(width: w, height: hh)
                .offset(x: x, y: sol - hh)
                .opacity(op)
                .animation(.timingCurve(0.2, 0.9, 0.25, 1, duration: 0.7).delay(Double(i) * 0.09), value: apparu)
                .onTapGesture {
                    guard !vide else { return }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.5)
                    withAnimation(.easeOut(duration: 0.22)) { choisie = choisie == i ? nil : i }
                }
            Text(vide ? "—" : "\(ChambreFmt.poids(m.charge))")
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(derniere && !vide ? AnyShapeStyle(CardTon.encreChaude) : AnyShapeStyle(ChambreTon.encre4))
                .frame(width: w)
                .offset(x: x, y: sol - hh - 18)
            if n <= 7 {
                Text(vide ? "—" : ChambreFmt.jourCourt(m.date))
                    .font(.system(size: 8.5, design: .monospaced))
                    .foregroundStyle(choisie == i ? CardTon.encreDouce : ChambreTon.encre5)
                    .frame(width: w)
                    .offset(x: x, y: sol + 10)
            }
        }
    }

    private func fil(w: CGFloat, gout: CGFloat, sol: CGFloat, lo: Double, hi: Double) -> some View {
        var p = Path()
        for (i, m) in vals.enumerated() {
            let h = 18 + CGFloat((m.charge - lo) / (hi - lo)) * (sol - 44)
            let pt = CGPoint(x: CGFloat(i) * (w + gout) + w / 2, y: sol - h - 6)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        return p.trim(from: 0, to: apparu ? 1 : 0)
            .stroke(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 0.75, dash: [2, 3]))
            .animation(.easeOut(duration: 0.9).delay(0.4), value: apparu)
    }

    private func marche(avant: Bool, chaude: Bool, largeur: CGFloat) -> some View {
        UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 4, style: .continuous)
            .fill(chaude
                  ? AnyShapeStyle(LinearGradient(colors: [CardTon.chaleur(0.88), CardTon.chaleur(0.55), CardTon.chaleur(0.34)], startPoint: .top, endPoint: .bottom))
                  : AnyShapeStyle(Color(white: avant ? 0.42 : 0.32)))
            .overlay(alignment: .top) { Rectangle().fill(Color.white.opacity(chaude ? 0.5 : 0.10)).frame(height: 1) }
            .shadow(color: chaude ? CardTon.chaleur(0.45).opacity(0.45) : .clear, radius: 10, y: 4)
    }
}
