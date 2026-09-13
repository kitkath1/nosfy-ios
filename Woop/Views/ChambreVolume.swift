import SwiftUI

// ════════════════════════════════════════════════════════════════════════
// LA CHAMBRE VOLUME — validée le 04-09, verrouillée depuis
//
//  · « Le cumul » : la courbe NUE au repos, le fantôme de la période passée
//    en pointillé, le delta posé au bout dans l'axe du point final ; la
//    légende « Semaine précédente » est un BOUTON — tap, le fantôme passe
//    en dégradé de blanc ; les valeurs n'existent que sous le doigt (scrub) ;
//  · « Le compte » : deux valeurs, par séance et record ;
//  · « Trois exercices » : les rangs qui portent le total, avec leur jauge ;
//  · « Répartition » : LE PODIUM DE SOIE — quatre colonnes tissées de
//    capsules, on comprend en une seconde que Fessiers domine.
// ════════════════════════════════════════════════════════════════════════

struct ChambreVolume: View {
    let f: ChambreFenetre
    let fenetre: ChambreEtat.Fenetre

    @State private var fantomeAvant = false

    var body: some View {
        VStack(alignment: .leading, spacing: 46) {
            cumul
            compte
            exos
            repartition
        }
    }

    // ── LE CUMUL
    private var cumul: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                BlocTitre(texte: "Le cumul")
                Spacer(minLength: 8)
                legendeBouton
            }
            CourbeCumul(serie: f.cumul, fantome: f.fantome, axe: f.axe,
                        delta: f.volumeDeltaPct, fantomeAvant: fantomeAvant, vide: f.vide)
                .frame(height: 176)
        }
        .chambreVide(f.vide)
    }

    /// La légende est un vrai bouton : au tap le fantôme passe en avant.
    private var legendeBouton: some View {
        HStack(spacing: 6) {
            Line().stroke(fantomeAvant ? Color.white.opacity(0.9) : Color(white: 0.45),
                          style: StrokeStyle(lineWidth: 1, dash: [1.5, 2.5]))
                .frame(width: 18, height: 1)
            Text(fenetre == .semaine ? "Semaine précédente" : "Mois précédent")
                .font(.system(size: 11)).foregroundStyle(fantomeAvant ? CardTon.encre : CardTon.encreSourde)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6)
            withAnimation(.easeOut(duration: 0.3)) { fantomeAvant.toggle() }
        }
        .scaleEffect(fantomeAvant ? 0.985 : 1)
    }

    // ── LE COMPTE
    private var compte: some View {
        VStack(alignment: .leading, spacing: 10) {
            BlocTitre(texte: "Le compte")
            Portee(items: [
                PorteeItem(valeur: ChambreFmt.kg(f.parSeance), libelle: "Par séance"),
                PorteeItem(valeur: ChambreFmt.kg(f.recordSemaine),
                           libelle: fenetre == .semaine ? "Record de la semaine" : "Meilleure semaine du mois"),
            ])
        }
        .chambreVide(f.vide)
    }

    // ── TROIS EXERCICES
    private var exos: some View {
        let part = Int((f.exos.reduce(0) { $0 + $1.part } * 100).rounded())
        return VStack(alignment: .leading, spacing: 6) {
            BlocTitre(texte: "Trois exercices", droite: f.vide ? "— % du total" : "\(part) % du total")
            if f.exos.isEmpty {
                ForEach(0..<3, id: \.self) { _ in
                    RangExo(sticker: nil, nom: "—", sous: "0 rép. · 0 kg", valeur: "0 kg", part: 0, vide: true)
                }
            } else {
                ForEach(f.exos) { e in
                    RangExo(sticker: e.sticker, nom: e.nom,
                            sous: "\(e.reps) rép. · \(ChambreFmt.poids(e.charge)) kg",
                            valeur: ChambreFmt.kg(e.volume), part: e.part)
                }
            }
        }
        .chambreVide(f.vide)
    }

    // ── RÉPARTITION · le podium de soie
    private var repartition: some View {
        VStack(alignment: .leading, spacing: 12) {
            BlocTitre(texte: "Répartition")
            PodiumSoie(categories: f.categories, vide: f.vide)
                .frame(height: 226)
        }
        .chambreVide(f.vide)
    }

    struct Line: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path(); p.move(to: CGPoint(x: r.minX, y: r.midY)); p.addLine(to: CGPoint(x: r.maxX, y: r.midY)); return p
        }
    }
}

// MARK: - LA COURBE DU CUMUL

struct CourbeCumul: View {
    var serie: [Double]
    var fantome: [Double]
    var axe: [String]
    var delta: Int?
    var fantomeAvant: Bool
    var vide: Bool

    @State private var apparu = false
    @State private var doigt: CGFloat?
    @State private var respire = false

    private var maxi: Double { max((serie + fantome).max() ?? 1, 1) }

    var body: some View {
        GeometryReader { g in
            let W = g.size.width - 44, H = g.size.height - 34, top: CGFloat = 16
            let pts = points(serie, W: W, H: H, top: top)
            let ptsF = points(fantome, W: W, H: H, top: top)
            ZStack(alignment: .topLeading) {
                aire(pts, H: H, top: top)
                fantomeVue(ptsF)
                trait(pts)
                pointFinal(pts)
                scrubVue(pts, H: H, top: top)
                axeVue(W: W, H: H, top: top)
            }
            .contentShape(Rectangle())
            .gesture(scrub(W: W))
        }
        .task {
            withAnimation(.timingCurve(0.25, 0.8, 0.25, 1, duration: 1.1)) { apparu = true }
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { respire = true }
        }
    }

    private func points(_ s: [Double], W: CGFloat, H: CGFloat, top: CGFloat) -> [CGPoint] {
        guard s.count > 1 else { return [] }
        return s.enumerated().map { i, v in
            CGPoint(x: CGFloat(i) / CGFloat(s.count - 1) * W,
                    y: top + H - CGFloat(v / maxi) * H)
        }
    }

    private func lisse(_ pts: [CGPoint]) -> Path {
        var p = Path()
        guard let f0 = pts.first else { return p }
        p.move(to: f0)
        for i in 1..<pts.count {
            let a = pts[i - 1], b = pts[i]
            let m = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
            p.addQuadCurve(to: m, control: CGPoint(x: (a.x + m.x) / 2, y: a.y))
            p.addQuadCurve(to: b, control: CGPoint(x: (m.x + b.x) / 2, y: b.y))
        }
        return p
    }

    private func aire(_ pts: [CGPoint], H: CGFloat, top: CGFloat) -> some View {
        var p = lisse(pts)
        if let l = pts.last, let f0 = pts.first {
            p.addLine(to: CGPoint(x: l.x, y: top + H)); p.addLine(to: CGPoint(x: f0.x, y: top + H)); p.closeSubpath()
        }
        return p.fill(LinearGradient(stops: [
            .init(color: CardTon.chaleur(0.72).opacity(0.26), location: 0),
            .init(color: CardTon.chaleur(0.50).opacity(0.12), location: 0.52),
            .init(color: CardTon.chaleur(0.30).opacity(0), location: 1),
        ], startPoint: .top, endPoint: .bottom))
        .opacity(apparu ? (fantomeAvant ? 0.35 : 1) : 0)
    }

    private func trait(_ pts: [CGPoint]) -> some View {
        lisse(pts)
            .trim(from: 0, to: apparu ? 1 : 0)
            .stroke(LinearGradient(stops: [
                .init(color: CardTon.chaleur(0.34), location: 0),
                .init(color: CardTon.chaleur(0.50), location: 0.3),
                .init(color: CardTon.chaleur(0.75), location: 0.76),
                .init(color: CardTon.chaleur(0.88), location: 1),
            ], startPoint: .leading, endPoint: .trailing),
            style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
            .opacity(fantomeAvant ? 0.35 : 1)
    }

    private func fantomeVue(_ pts: [CGPoint]) -> some View {
        lisse(pts)
            .stroke(fantomeAvant
                    ? AnyShapeStyle(LinearGradient(colors: [Color.white, Color(white: 0.863)], startPoint: .top, endPoint: .bottom))
                    : AnyShapeStyle(Color(white: 0.42)),
                    style: StrokeStyle(lineWidth: fantomeAvant ? 1.6 : 1, dash: fantomeAvant ? [] : [1.5, 2.5]))
            .opacity(apparu ? (fantomeAvant ? 1 : 0.7) : 0)
            .animation(.easeOut(duration: 0.3), value: fantomeAvant)
    }

    @ViewBuilder
    private func pointFinal(_ pts: [CGPoint]) -> some View {
        if let l = pts.last, apparu {
            Circle().fill(CardTon.chaleur(1))
                .frame(width: 5, height: 5)
                .overlay(Circle().stroke(CardTon.chaleur(0.75).opacity(0.5), lineWidth: 1)
                    .scaleEffect(respire ? 2.6 : 1.4).opacity(respire ? 0 : 0.6))
                .position(l)
                .opacity(fantomeAvant ? 0.4 : 1)
            if let d = delta, doigt == nil {
                Text("\(d >= 0 ? "+" : "−")\(abs(d)) %")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(CardTon.encreChaude)
                    .fixedSize()
                    .position(x: l.x + 4, y: max(l.y - 14, 8))
                    .opacity(fantomeAvant ? 0.4 : 1)
            } else if vide, doigt == nil {
                Text("— %").font(.system(size: 11, design: .monospaced)).foregroundStyle(ChambreTon.encre4)
                    .fixedSize().position(x: l.x + 4, y: max(l.y - 14, 8))
            }
        }
    }

    // le scrub : une hairline, un point qui suit la courbe, la valeur du jour
    @ViewBuilder
    private func scrubVue(_ pts: [CGPoint], H: CGFloat, top: CGFloat) -> some View {
        if let x = doigt, !pts.isEmpty, !vide {
            let i = min(max(Int((x / max(pts.last!.x, 1) * CGFloat(pts.count - 1)).rounded()), 0), pts.count - 1)
            let p = pts[i]
            Rectangle().fill(Color.white.opacity(0.20)).frame(width: 0.5, height: H + top)
                .position(x: p.x, y: (H + top) / 2)
            Circle().fill(Color.white).frame(width: 3, height: 3).position(p)
            Text(ChambreFmt.kg(serie[i]))
                .font(.inter(11, .semibold)).encreMetal().fixedSize()
                .position(x: min(max(p.x, 24), pts.last!.x - 24), y: max(p.y - 16, 8))
        }
    }

    private func axeVue(W: CGFloat, H: CGFloat, top: CGFloat) -> some View {
        HStack {
            ForEach(Array(axe.enumerated()), id: \.offset) { i, a in
                Text(a).font(.system(size: 9.5, design: .monospaced)).foregroundStyle(ChambreTon.encre4)
                if i < axe.count - 1 { Spacer(minLength: 0) }
            }
        }
        .frame(width: W)
        .offset(y: top + H + 12)
    }

    private func scrub(W: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in doigt = min(max(v.location.x, 0), W) }
            .onEnded { _ in withAnimation(.easeOut(duration: 0.3)) { doigt = nil } }
    }
}

// MARK: - LE PODIUM DE SOIE

/// Quatre colonnes tissées de capsules — la matière des courbes de la
/// maison. Seule la dominante touche le blanc chauffé, scintille et pose sa
/// laque au sol ; les autres descendent la rampe, puis le graphite.
struct PodiumSoie: View {
    var categories: [ChambreCategorie]
    var vide: Bool
    @State private var choisie: Int?
    @State private var apparu = false

    private static let pas: CGFloat = 3.8
    private static let noms: [ExerciseCategory: String] = [.fessiers: "Fessiers", .bas: "Bas", .haut: "Haut", .abdos: "Abdos", .cardio: "Cardio"]

    private var cats: [ChambreCategorie] {
        vide ? [] : Array(categories.prefix(4))
    }

    var body: some View {
        GeometryReader { g in
            let n = max(cats.count, 4)
            let w = g.size.width / CGFloat(n)
            let sol = g.size.height - 62
            let hMax = sol - 34
            let partMax = cats.first?.part ?? 1
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(0..<n, id: \.self) { i in
                    let c: ChambreCategorie? = cats.indices.contains(i) ? cats[i] : nil
                    let part = c.map { $0.part / max(partMax, 0.0001) } ?? 0.12
                    let h = max(hMax * CGFloat(part), Self.pas * 3)
                    colonne(i, c, hauteur: apparu ? h : Self.pas * 2, largeur: w, sol: sol)
                        .frame(width: w)
                        .animation(.timingCurve(0.2, 0.9, 0.25, 1, duration: 0.7).delay(Double(i) * 0.08), value: apparu)
                        .onTapGesture {
                            guard c != nil else { return }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.5)
                            withAnimation(.easeOut(duration: 0.22)) { choisie = choisie == i ? nil : i }
                        }
                }
            }
        }
        .task { withAnimation { apparu = true } }
    }

    private func colonne(_ i: Int, _ c: ChambreCategorie?, hauteur h: CGFloat, largeur w: CGFloat, sol: CGFloat) -> some View {
        let n = Int(h / Self.pas)
        let dim: Double = choisie == nil ? 1 : (choisie == i ? 1 : 0.5)
        return VStack(spacing: 0) {
            Spacer(minLength: 0)
            if let c { Image(c.sticker.asset).resizable().scaledToFit().frame(width: 22, height: 22).padding(.bottom, 6) }
            else { Circle().fill(Color.white.opacity(0.07)).frame(width: 22, height: 22).padding(.bottom, 6) }
            VStack(spacing: Self.pas - 2.2) {
                ForEach(0..<max(n, 1), id: \.self) { k in
                    let t = Double(k) / Double(max(n - 1, 1))
                    Capsule().fill(teinte(rang: i, t: t)).frame(width: 42, height: 2.2)
                }
            }
            .frame(height: h)
            .overlay(alignment: .bottom) {
                if i == 0, c != nil {
                    // la laque au sol de la dominante
                    Rectangle().fill(LinearGradient(colors: [CardTon.chaleur(0.5).opacity(0.22), .clear], startPoint: .top, endPoint: .bottom))
                        .frame(width: 42, height: 14).offset(y: 16)
                }
            }
            Text(c.map { "\(Int(($0.part * 100).rounded())) %" } ?? "—")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(i == 0 && c != nil ? AnyShapeStyle(CardTon.encreChaude) : AnyShapeStyle(CardTon.encreDouce))
                .padding(.top, 18)
            Text(c.map { Self.noms[$0.categorie] ?? $0.categorie.rawValue } ?? "—")
                .font(.system(size: 10.5)).foregroundStyle(CardTon.encreSourde).padding(.top, 3)
            Text(c.map { ChambreFmt.kg($0.volume) } ?? "0 kg")
                .font(.system(size: 9.5, design: .monospaced)).foregroundStyle(ChambreTon.encre4).padding(.top, 2)
        }
        .opacity(dim)
    }

    /// La rampe par rang : la dominante monte jusqu'au blanc chauffé, la
    /// seconde s'arrête à l'or, la troisième à la flamme, la quatrième reste
    /// graphite — la hiérarchie par la matière, pas par des blocs.
    private func teinte(rang: Int, t: Double) -> Color {
        if vide { return Color(white: 0.30 + 0.1 * t) }
        switch rang {
        case 0: return CardTon.chaleur(0.30 + 0.62 * t)
        case 1: return CardTon.chaleur(0.30 + 0.30 * t)
        case 2: return CardTon.chaleur(0.25 + 0.17 * t).opacity(0.85)
        default: return Color(white: 0.36 + 0.14 * t)
        }
    }
}
