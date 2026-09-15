import SwiftUI

// ════════════════════════════════════════════════════════════════════════
// LA CHAMBRE HIIT — le design tranché les 05 → 07-09
//
//  · la synthèse sous le sélecteur (pic max · de pics · efforts) ;
//  · ÉTAGE 1 « La semaine » / « Le mois » : la grille du calendrier, les
//    jours de HIIT allumés avec leur pic, tap un jour → sa séance ;
//  · ÉTAGE 2 « La séance » : LES PALIERS — une barre par segment RÉEL,
//    largeur = durée, hauteur = vitesse, chaleur = intensité, les deux
//    bandes des fourchettes, le pic qui perce son plafond, la laque, la
//    légende ;
//  · le bilan (en progrès / en recul) ;
//  · « Ton record de vitesse », quatre marches cliquables.
//
// Aucune factorisation nulle part : une séance ne répète rien.
// ════════════════════════════════════════════════════════════════════════

struct ChambreHiit: View {
    let f: ChambreFenetre
    let fenetre: ChambreEtat.Fenetre

    @State private var selection: Date?

    private var seance: ChambreSeanceHiit? {
        if let s = selection, let x = f.seancesHiit.first(where: { $0.date == s }) { return x }
        return f.seancesHiit.max { $0.pic < $1.pic }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 46) {
            synthese
            etage1
            etage2
            bilan
            record
        }
        .onChange(of: fenetre) { _, _ in selection = nil }
    }

    // ── LA SYNTHÈSE DE LA FENÊTRE
    private var synthese: some View {
        Portee(items: [
            PorteeItem(valeur: f.vide ? "0,0" : ChambreFmt.kmh(f.picMax), libelle: L("Pic max", "Peak"), unite: "km/h"),
            PorteeItem(valeur: ChambreFmt.mmss(f.tempsPics), libelle: L("Temps de pics", "Peak time")),
            PorteeItem(valeur: "\(f.efforts)", libelle: L("Efforts · + de 15 km/h", "Efforts · over 15 km/h")),
        ], grand: true)
        .chambreVide(f.vide)
    }

    // ── ÉTAGE 1 · la vue globale
    private var etage1: some View {
        VStack(alignment: .leading, spacing: 14) {
            BlocTitre(texte: fenetre == .semaine ? L("La semaine", "This week") : L("Le mois", "This month"))
            ChambreGrille(jours: f.jours, selection: seance?.date,
                          montrerPic: true, stickers: false) { j in
                if let s = f.seancesHiit.first(where: { Calendar.current.isDate($0.date, inSameDayAs: j.date) }) {
                    withAnimation(.easeOut(duration: 0.28)) { selection = s.date }
                }
            }
            if fenetre == .mois {
                Text("\(f.seancesHiit.count) séance\(f.seancesHiit.count > 1 ? "s" : "") · Le plus long trou : \(f.plusLongTrou) jour\(f.plusLongTrou > 1 ? "s" : "")")
                    .font(.system(size: 11)).foregroundStyle(CardTon.encreSourde)
            }
        }
        .chambreVide(f.vide)
    }

    // ── ÉTAGE 2 · la séance
    private var etage2: some View {
        VStack(alignment: .leading, spacing: 0) {
            BlocTitre(texte: L("La séance", "The session"))
            Text(seance?.jour ?? "—").font(.inter(15, .medium)).foregroundStyle(CardTon.encre)
                .padding(.top, 7)
            Text(seance.map { "\(ChambreFmt.mmss($0.duree)) · \($0.segments.count) segments" } ?? "0:00 · 0 segment")
                .font(.system(size: 11.5, design: .monospaced)).tracking(0.2)
                .foregroundStyle(ChambreTon.encre4)
                .padding(.top, 6)
            PaliersVue(segments: seance?.segments ?? PaliersVue.silhouette, vide: seance == nil)
                .frame(height: 210)
                .padding(.top, 26)
            legende.padding(.top, 18)
        }
        .chambreVide(seance == nil)
    }

    private var legende: some View { LegendePaliers(echelle: .tapis) }

    // ── LE BILAN
    private var bilan: some View {
        var monte: [BilanFait] = [], recule: [BilanFait] = []
        let quand = fenetre == .semaine ? L("la semaine passée", "last week") : L("le mois passé", "last month")
        func pose(_ nom: String, _ cur: Double, _ prev: Double, _ fmt: (Double) -> String,
                  plusEstMieux: Bool, detail: String) {
            let d = cur - prev
            guard d != 0 else { return }
            let mieux = plusEstMieux ? d > 0 : d < 0
            let fait = BilanFait(nom: nom, delta: (d > 0 ? "+" : "−") + fmt(abs(d)), detail: detail)
            if mieux { monte.append(fait) } else { recule.append(fait) }
        }
        pose(L("Pic", "Peak"), f.picMax, f.picPrec, ChambreFmt.kmh, plusEstMieux: true,
             detail: "\(ChambreFmt.kmh(f.picMax)) km/h contre \(ChambreFmt.kmh(f.picPrec)) \(quand)")
        pose(L("Temps de pics", "Peak time"), Double(f.tempsPics), Double(f.tempsPicsPrec), { ChambreFmt.mmss(Int($0)) },
             plusEstMieux: true, detail: "\(ChambreFmt.mmss(f.tempsPics)) contre \(ChambreFmt.mmss(f.tempsPicsPrec))")
        pose(L("Efforts", "Efforts"), Double(f.efforts), Double(f.effortsPrec), { "\(Int($0))" }, plusEstMieux: true,
             detail: "\(f.efforts) contre \(f.effortsPrec) passages au-dessus de 15 km/h")
        pose(L("Récups", "Rests"), Double(f.recupMoy), Double(f.recupMoyPrec), { "\(Int($0)) s" }, plusEstMieux: false,
             detail: "\(ChambreFmt.mmss(f.recupMoy)) de moyenne contre \(ChambreFmt.mmss(f.recupMoyPrec))")
        pose(L("Plus long trou", "Longest gap"), Double(f.plusLongTrou), Double(f.plusLongTrouPrec), { "\(Int($0)) j" }, plusEstMieux: false,
             detail: "\(f.plusLongTrou) jours sans courir, contre \(f.plusLongTrouPrec)")
        // LA PREMIÈRE FENÊTRE NE SE COMPARE À RIEN. Sans intervalle sur la
        // fenêtre d'avant, chaque fait serait « +17,0 contre 0,0 » : des
        // chiffres vrais et incohérents (verdict du 13-09). Le bilan attend.
        let premiere = !f.vide && f.picPrec == 0 && f.effortsPrec == 0
        let phrase: String = f.vide ? ""
            : premiere ? (fenetre == .semaine
                          ? L("Première semaine d'intervalles : la prochaine se comparera à celle-ci.", "First week of intervals: the next one compares to this.")
                          : L("Premier mois d'intervalles : le prochain se comparera à celui-ci.", "First month of intervals: the next one compares to this."))
            : (f.picMax > f.picPrec && f.recupMoy > f.recupMoyPrec
               ? L("Tu montes plus haut, mais tu récupères plus lentement : le pic se paie.", "You go higher, but recover slower: the peak has a price.")
               : f.picMax > f.picPrec ? L("Tu montes plus haut que \(quand).", "You go higher than \(quand).")
               : f.efforts > f.effortsPrec ? L("Plus d'efforts, un pic qui tient : la base s'élargit.", "More efforts, a peak that holds: the base widens.")
               : L("Une fenêtre plus calme que la précédente.", "A quieter window than the previous one."))
        // LES MOTS VIENNENT DU SERVEUR quand il en a (15-09, `bilan-periode` :
        // la phrase de l'IA sur les chiffres des widget_*, dans la langue du
        // profil) ; la phrase à règles ci-dessus reste le repli hors ligne.
        let serveur = f.vide ? nil : ChambreEtat.shared.bilanServeur[fenetre.rawValue]
        return BilanVue(titre: fenetre == .semaine ? L("Le bilan de la semaine", "The week in review") : L("Le bilan du mois", "The month in review"),
                        monte: premiere ? [] : monte, recule: premiere ? [] : recule,
                        phrase: serveur ?? phrase, vide: f.vide)
    }

    // ── TON RECORD DE VITESSE
    private var record: some View {
        VStack(alignment: .leading, spacing: 6) {
            BlocTitre(texte: L("Ton record de vitesse", "Your speed record"))
            MarchesVitesse(pics: f.pics4, vide: f.pics4.allSatisfy { $0 == 0 })
                .frame(height: 150)
                .padding(.top, 14)
        }
        .chambreVide(f.pics4.allSatisfy { $0 == 0 })
    }
}

// MARK: - L'ÉCHELLE DES PALIERS (15-09, plan cardio §C)

/// UN composant, DEUX échelles. Le graphe de la chambre HIIT lit des km/h
/// (4 → 20, l'effort au-dessus du seuil de la maison) ; sur la fiche de
/// l'escalier il lit des NIVEAUX de machine (« en vitesse-niveau, comme un
/// tapis de salle », verdict 15-09) où tout ce qui monte est un effort. Le
/// défaut `.tapis` reproduit EXACTEMENT les nombres qui étaient en dur : la
/// chambre ne bouge pas d'un pixel.
/// ⚠️ Un `enum`, pas un struct de closures : une closure en propriété d'une
/// vue la rend inégalable, donc rejouée à chaque passage du parent (loi §2.3).
enum EchellePaliers: Equatable {
    /// La chambre HIIT et les fiches HIIT / tapis modéré : des km/h.
    case tapis
    /// L'escalier : niveaux 1-15, chaleur = niveau / 15, la récup en graphite
    /// sombre (elle est à l'arrêt ou au niveau 1).
    case escalier

    /// Les bornes de la hauteur des barres.
    var min: Double { self == .tapis ? 4 : 0 }
    var max: Double { self == .tapis ? 20 : 15 }
    /// Le mot des cotes et de la légende.
    var unite: String { self == .tapis ? "km/h" : "niveau" }
    /// La chaleur d'un EFFORT [0,1] selon sa vitesse.
    func chaleur(_ v: Double) -> Double {
        switch self {
        case .tapis: return Swift.min(Swift.max((v - SemaineStats.seuilEffort) / 4, 0), 1)
        case .escalier: return Swift.min(Swift.max(v / 15, 0), 1)
        }
    }
    /// L'éclaircissement du GRAPHITE d'une récup [0,1] selon sa vitesse.
    func graphite(_ v: Double) -> Double {
        switch self {
        case .tapis: return Swift.min(Swift.max((v - 5) / 4.5, 0), 1)
        case .escalier: return Swift.min(Swift.max(v / 15, 0), 1) * 0.5
        }
    }
    /// L'écriture d'une valeur.
    func fmt(_ v: Double) -> String {
        self == .tapis ? ChambreFmt.kmh(v) : "\(Int(v.rounded()))"
    }
    /// La légende du code couleur : « 15,0 → 19,0 km/h » / « niveau 1 → 15 ».
    var legendeChaleur: String {
        switch self {
        case .tapis: return "\(ChambreFmt.kmh(SemaineStats.seuilEffort)) → \(ChambreFmt.kmh(SemaineStats.seuilEffort + 4)) km/h"
        case .escalier: return "niveau 1 → 15"
        }
    }
}

/// La légende sous le graphe — partagée par la chambre et la fiche.
struct LegendePaliers: View {
    var echelle: EchellePaliers = .tapis

    var body: some View {
        HStack(spacing: 20) {
            HStack(spacing: 6) {
                Capsule().fill(ChambreTon.graphite).frame(width: 9, height: 5)
                Text(L("Repos", "Rest")).font(.system(size: 10)).foregroundStyle(ChambreTon.encre4)
            }
            HStack(spacing: 3) {
                ForEach(0..<4, id: \.self) { i in
                    Capsule().fill(CardTon.chaleur(0.25 * Double(i) + 0.12)).frame(width: 9, height: 5)
                }
                // La légende du code couleur suit la règle du seuil (jamais un 15 en dur).
                Text(echelle.legendeChaleur).font(.system(size: 10)).foregroundStyle(ChambreTon.encre4)
                    .padding(.leading, 3)
            }
        }
    }
}

// MARK: - LES PALIERS

/// Une barre par segment réel. Dessin PUR : aucune horloge — il ne bouge
/// que par son entrée en scène (des valeurs animables) et sous le doigt.
struct PaliersVue: View {
    var segments: [SegmentHiit]
    var vide = false
    /// L'échelle : km/h par défaut (la chambre), niveaux sur l'escalier.
    var echelle: EchellePaliers = .tapis

    @State private var choisi: Int?
    @State private var apparu = false

    private static let plancher: CGFloat = 7
    /// La silhouette du vide : un HIIT en gris — repos et efforts qui
    /// alternent, jamais deux pareils. La loi du vide veut le MÊME dessin
    /// (bandes, pic, cotes, rail), désaturé ; dix repos plats ne le donnaient
    /// pas (mesuré le 13-09). Les chiffres, eux, sont des tirets.
    static let silhouette: [SegmentHiit] = [
        (90, 6.0, false), (40, 16.0, true), (120, 5.5, false), (30, 17.5, true),
        (75, 6.5, false), (45, 16.5, true), (150, 5.0, false), (30, 18.0, true),
        (60, 6.0, false), (40, 17.0, true),
    ].map { SegmentHiit(secondes: $0.0, vitesse: $0.1, effort: $0.2) }

    private var efforts: [SegmentHiit] { segments.filter(\.effort) }
    private var recups: [SegmentHiit] { segments.filter { !$0.effort } }
    private var eMax: Double { efforts.map(\.vitesse).max() ?? 0 }
    private var eMin: Double { efforts.map(\.vitesse).min() ?? 0 }
    private var rMax: Double { recups.map(\.vitesse).max() ?? 0 }
    private var rMin: Double { recups.map(\.vitesse).min() ?? 0 }
    private var pic: Int? { efforts.isEmpty ? nil : segments.indices.max { segments[$0].vitesse < segments[$1].vitesse } }

    var body: some View {
        GeometryReader { g in
            let W = g.size.width
            let champ = W - 42                     // la gouttière des cotes
            let sol = g.size.height - 46           // le rail + la laque dessous
            let L = largeurs(dans: champ)
            ZStack(alignment: .topLeading) {
                bandes(sol: sol, champ: champ)
                lecture(sol: sol).padding(.top, 0)
                laque(L, sol: sol)
                barres(L, sol: sol)
                picVue(L, sol: sol)
                cotes(sol: sol, x: champ + 4)
                rail(L, sol: sol)
            }
            .onTapGesture { location in
                guard let i = L.x.lastIndex(where: { $0 <= location.x }), !vide else { return }
                let cible = max(L.l[i], 24)
                let cx = L.x[i] + L.l[i] / 2
                guard abs(location.x - cx) <= cible / 2 + 4 else { return }
                UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.5)
                withAnimation(.easeOut(duration: 0.18)) { choisi = choisi == i ? nil : i }
            }
        }
        .task { withAnimation(.timingCurve(0.2, 0.9, 0.25, 1, duration: 0.5)) { apparu = true } }
    }

    // les deux bandes — aplat SEUL, aucun trait
    @ViewBuilder
    private func bandes(sol: CGFloat, champ: CGFloat) -> some View {
        if !efforts.isEmpty {
            Rectangle().fill(CardTon.chaleur(0.35).opacity(0.06))
                .frame(width: champ, height: max(y(eMin, sol) - y(eMax, sol), 3))
                .offset(y: y(eMax, sol))
        }
        if !recups.isEmpty {
            Rectangle().fill(Color(white: 0.58).opacity(0.06))
                .frame(width: champ, height: max(y(rMin, sol) - y(rMax, sol), 3))
                .offset(y: y(rMax, sol))
        }
    }

    private func barres(_ L: Largeurs, sol: CGFloat) -> some View {
        ForEach(Array(segments.enumerated()), id: \.offset) { i, s in
            let h = hauteur(s.vitesse) * (apparu ? 1 : 0.001)
            let dim: Double = choisi == nil ? 1 : (choisi == i ? 1 : 0.62)
            barre(s, largeur: L.l[i], choisie: choisi == i, estPic: pic == i)
                .frame(width: L.l[i], height: max(h, 2))
                .offset(x: L.x[i], y: sol - h)
                .opacity(dim)
                .animation(.timingCurve(0.2, 0.9, 0.25, 1, duration: 0.5).delay(Double(i) * 0.04), value: apparu)
        }
    }

    @ViewBuilder
    private func barre(_ s: SegmentHiit, largeur: CGFloat, choisie: Bool, estPic: Bool) -> some View {
        let r: CGFloat = largeur < 9 ? 1.5 : 2
        if s.effort {
            let t = echelle.chaleur(s.vitesse)
            ZStack(alignment: .top) {
                UnevenRoundedRectangle(topLeadingRadius: r, bottomLeadingRadius: 0,
                                       bottomTrailingRadius: 0, topTrailingRadius: r, style: .continuous)
                    .fill(LinearGradient(colors: [CardTon.chaleur(min(t + 0.16, 1)), CardTon.chaleur(max(t - 0.12, 0))],
                                         startPoint: .top, endPoint: .bottom))
                // la coiffe de laque
                Rectangle().fill(CardTon.chaleur(1).opacity(choisie ? 0.85 : (estPic ? 0.55 : 0.30)))
                    .frame(height: 1)
            }
            .overlay {
                if choisie {
                    UnevenRoundedRectangle(topLeadingRadius: r, bottomLeadingRadius: 0,
                                           bottomTrailingRadius: 0, topTrailingRadius: r, style: .continuous)
                        .strokeBorder(CardTon.chaleur(1).opacity(0.35), lineWidth: 0.5)
                }
            }
        } else {
            // le graphite : il s'éclaircit quand la vitesse monte — 9,0 n'est
            // visiblement pas 6,5. Jamais de braise sous le seuil.
            let fct = echelle.graphite(s.vitesse)
            UnevenRoundedRectangle(topLeadingRadius: r, bottomLeadingRadius: 0,
                                   bottomTrailingRadius: 0, topTrailingRadius: r, style: .continuous)
                .fill(Color(white: 0.353 + 0.23 * fct).opacity(0.34 + 0.32 * fct))
        }
    }

    // LE PIC QUI CASSE SON PLAFOND : une pointe, une étiquette, un foyer
    @ViewBuilder
    private func picVue(_ L: Largeurs, sol: CGFloat) -> some View {
        if let p = pic, apparu {
            let x = L.x[p], w = L.l[p], cx = x + w / 2
            let top = y(segments[p].vitesse, sol)
            Pointe().fill(CardTon.chaleur(1))
                .frame(width: w, height: 7)
                .offset(x: x, y: top - 7)
            Text(vide ? "—" : echelle.fmt(segments[p].vitesse))
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(LinearGradient(colors: [CardTon.chaleur(1), CardTon.chaleur(0.75)],
                                                startPoint: .top, endPoint: .bottom))
                .fixedSize()
                .frame(width: 60)
                .offset(x: cx - 30, y: top - 22)
            RadialGradient(colors: [CardTon.chaleur(0.32).opacity(0.14), .clear],
                           center: .center, startRadius: 0, endRadius: 26)
                .frame(width: 52, height: 52)
                .offset(x: cx - 26, y: top - 26)
                .allowsHitTesting(false)
        }
    }

    // les cotes vivent dans la gouttière : zéro libellé posé dans une bande
    @ViewBuilder
    private func cotes(sol: CGFloat, x: CGFloat) -> some View {
        if !efforts.isEmpty {
            cote(eMax, sol: sol, x: x, couleur: CardTon.chaleur(0.75), op: 0.78)
            if y(eMin, sol) - y(eMax, sol) >= 9 {
                cote(eMin, sol: sol, x: x, couleur: CardTon.chaleur(0.75), op: 0.55)
            } else {
                Text(vide ? "→ —" : "→ \(echelle.fmt(eMin))").font(.system(size: 7.5, design: .monospaced))
                    .foregroundStyle(CardTon.chaleur(0.75).opacity(0.7))
                    .offset(x: x + 6, y: y(eMax, sol) + 6)
            }
            Text(echelle.unite).font(.system(size: 7.5, design: .monospaced)).foregroundStyle(ChambreTon.encre4)
                .offset(x: x + 6, y: y(eMax, sol) - 12)
        }
        if !recups.isEmpty {
            cote(rMax, sol: sol, x: x, couleur: Color(white: 0.58), op: 0.9)
            if y(rMin, sol) - y(rMax, sol) >= 9 {
                cote(rMin, sol: sol, x: x, couleur: Color(white: 0.5), op: 0.9)
            }
        }
    }

    private func cote(_ v: Double, sol: CGFloat, x: CGFloat, couleur: Color, op: Double) -> some View {
        HStack(spacing: 2) {
            Rectangle().fill(couleur).frame(width: 4, height: 0.5)
            Text(vide ? "—" : echelle.fmt(v)).font(.system(size: 8.5, design: .monospaced)).foregroundStyle(couleur)
        }
        .opacity(op)
        .offset(x: x, y: y(v, sol) - 5)
    }

    // la laque : chaque barre CHAUDE seule laisse un reflet sous le sol
    private func laque(_ L: Largeurs, sol: CGFloat) -> some View {
        ForEach(Array(segments.enumerated()), id: \.offset) { i, s in
            if s.effort {
                let t = echelle.chaleur(s.vitesse)
                let h = min(hauteur(s.vitesse) * 0.28, 22)
                Rectangle()
                    .fill(LinearGradient(colors: [CardTon.chaleur(max(t - 0.10, 0)).opacity(0.22), .clear],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: L.l[i], height: h)
                    .offset(x: L.x[i], y: sol + 2)
                    .opacity(apparu ? 1 : 0)
            }
        }
    }

    // le rail : les durées d'effort seules, sous leur barre
    private func rail(_ L: Largeurs, sol: CGFloat) -> some View {
        ForEach(Array(segments.enumerated()), id: \.offset) { i, s in
            if s.effort || choisi == i {
                Text(vide ? "—" : ChambreFmt.mmss(s.secondes))
                    .font(.system(size: 8.5, design: .monospaced))
                    .foregroundStyle(choisi == i ? CardTon.encreDouce : ChambreTon.encre4)
                    .fixedSize().frame(width: 40)
                    .offset(x: L.x[i] + L.l[i] / 2 - 20, y: sol + 30)
            }
        }
    }

    // la ligne de lecture : vide au repos, elle n'existe que sous le doigt
    @ViewBuilder
    private func lecture(sol: CGFloat) -> some View {
        if let i = choisi, segments.indices.contains(i) {
            let s = segments[i]
            let col: Color = s.effort ? CardTon.chaleur(echelle.chaleur(s.vitesse)) : ChambreTon.graphite
            HStack(spacing: 6) {
                Capsule().fill(col).frame(width: 20, height: 6)
                Text("\(ChambreFmt.mmss(s.secondes)) · \(echelle.fmt(s.vitesse)) \(echelle.unite)").foregroundStyle(CardTon.encre)
                Text("\(i + 1)/\(segments.count) · \(role(i))").foregroundStyle(CardTon.encreSourde)
            }
            .font(.system(size: 12, weight: .medium))
            .offset(y: -26)
            .transition(.opacity)
        }
    }

    private func role(_ i: Int) -> String {
        let s = segments[i]
        if s.effort {
            return pic == i ? "Le plus rapide" : "Effort"
        }
        let plusLongue = recups.map(\.secondes).max() == s.secondes
        return plusLongue ? "La plus longue récup" : "Récup"
    }

    /// 10 pt au plancher, 110 au plafond de l'échelle — pour l'échelle
    /// tapis (4 → 20) c'est exactement le `10 + (v − 4) × 6,25` d'avant.
    private func hauteur(_ v: Double) -> CGFloat {
        let etendue = max(echelle.max - echelle.min, 1)
        let u = (min(max(v, echelle.min), echelle.max) - echelle.min) / etendue
        return CGFloat(10 + u * 100)
    }
    private func y(_ v: Double, _ sol: CGFloat) -> CGFloat { sol - hauteur(v) }

    struct Largeurs { var l: [CGFloat]; var x: [CGFloat] }

    /// Largeurs = durées, avec plancher : le déficit est repris au prorata de
    /// l'excédent des barres larges, jamais des courtes.
    private func largeurs(dans champ: CGFloat) -> Largeurs {
        let n = segments.count
        guard n > 0 else { return Largeurs(l: [], x: []) }
        let gout: CGFloat = n <= 12 ? 2 : (n <= 16 ? 1.5 : 1)
        let utile = champ - gout * CGFloat(n - 1)
        let total = CGFloat(segments.reduce(0) { $0 + $1.secondes })
        guard total > 0, utile > 0 else { return Largeurs(l: [], x: []) }
        var l = segments.map { CGFloat($0.secondes) / total * utile }
        var deficit: CGFloat = 0
        for i in l.indices where l[i] < Self.plancher { deficit += Self.plancher - l[i]; l[i] = Self.plancher }
        if deficit > 0.01 {
            let exc = l.map { max($0 - 18, 0) }
            let somme = exc.reduce(0, +)
            if somme > 0 { for i in l.indices { l[i] -= deficit * exc[i] / somme } }
        }
        var x: [CGFloat] = []; var c: CGFloat = 0
        for w in l { x.append(c); c += w + gout }
        return Largeurs(l: l, x: x)
    }

    struct Pointe: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: r.minX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.midX - 1.25, y: r.minY))
            p.addLine(to: CGPoint(x: r.midX + 1.25, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
            p.closeSubpath(); return p
        }
    }
}

// MARK: - LES MARCHES DU RECORD DE VITESSE

/// Quatre marches : les pics de S-3 à cette semaine. Le passé recule par la
/// lumière (0,35 → 0,85), la dernière brûle ; tap une marche → elle passe
/// en avant par la chaleur et sa semaine se dit.
struct MarchesVitesse: View {
    var pics: [Double]
    var vide = false
    @State private var choisie: Int?
    @State private var apparu = false

    private static let noms = ["S-3", "S-2", "S-1", L("Cette sem.", "This wk")]
    private var vals: [Double] { vide ? [12, 13, 12.5, 14] : pics }

    var body: some View {
        GeometryReader { g in
            let n = vals.count
            let gout: CGFloat = 10
            let w = (g.size.width - gout * CGFloat(n - 1)) / CGFloat(n)
            let sol = g.size.height - 36
            let lo = max((vals.filter { $0 > 0 }.min() ?? 0) - 1.5, 0)
            let hi = max(vals.max() ?? 1, lo + 1)
            ZStack(alignment: .topLeading) {
                // Un rang = une fonction NOMMÉE : un corps de ForEach chargé
                // fait tomber le type-checker sur l'overload Binding (payé).
                ForEach(0..<n, id: \.self) { i in
                    rang(i, n: n, w: w, gout: gout, sol: sol, lo: lo, hi: hi)
                }
                if let c = choisie, c > 0, vals[c] > 0, vals[c - 1] > 0 {
                    let d = vals[c] - vals[c - 1]
                    Text("\(Self.noms[c]) · \(ChambreFmt.kmh(vals[c])) km/h · \(d >= 0 ? "+" : "−")\(ChambreFmt.kmh(abs(d))) vs \(Self.noms[c - 1])")
                        .font(.system(size: 11)).foregroundStyle(CardTon.encreSourde)
                        .offset(y: sol + 26)
                        .transition(.opacity)
                }
            }
        }
        .task { withAnimation { apparu = true } }
    }

    // swiftlint:disable:next function_parameter_count
    private func rang(_ i: Int, n: Int, w: CGFloat, gout: CGFloat,
                      sol: CGFloat, lo: Double, hi: Double) -> some View {
        let v = vals[i]
        let h: CGFloat = v > 0 ? 24 + CGFloat((v - lo) / (hi - lo)) * (sol - 44) : 6
        let derniere = i == n - 1
        let avant = choisie.map { $0 == i } ?? derniere
        let op: Double = avant ? 1 : 0.35 + 0.17 * Double(i)
        let hh: CGFloat = apparu ? h : 2
        let x = CGFloat(i) * (w + gout)
        return ZStack(alignment: .topLeading) {
            marche(v, chaude: avant && v > 0, largeur: w)
                .frame(width: w, height: hh)
                .offset(x: x, y: sol - hh)
                .opacity(op)
                .animation(.timingCurve(0.2, 0.9, 0.25, 1, duration: 0.6).delay(Double(i) * 0.09), value: apparu)
                .onTapGesture {
                    guard v > 0 else { return }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.5)
                    withAnimation(.easeOut(duration: 0.22)) { choisie = choisie == i ? nil : i }
                }
            Text(v > 0 && !vide ? ChambreFmt.kmh(v) : "—")
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(avant ? AnyShapeStyle(CardTon.encreChaude) : AnyShapeStyle(ChambreTon.encre4))
                .frame(width: w)
                .offset(x: x, y: sol - hh - 18)
            Text(Self.noms[i]).font(.system(size: 9.5))
                .foregroundStyle(avant ? CardTon.encreDouce : ChambreTon.encre4)
                .frame(width: w)
                .offset(x: x, y: sol + 10)
        }
    }

    private func marche(_ v: Double, chaude: Bool, largeur: CGFloat) -> some View {
        let t = min(max((v - 15) / 4, 0), 1)
        return UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 0,
                                      bottomTrailingRadius: 0, topTrailingRadius: 4, style: .continuous)
            .fill(chaude
                  ? AnyShapeStyle(LinearGradient(colors: [CardTon.chaleur(min(t + 0.2, 1)), CardTon.chaleur(max(t - 0.1, 0))],
                                                 startPoint: .top, endPoint: .bottom))
                  : AnyShapeStyle(Color(white: 0.32)))
            .overlay(alignment: .top) {
                Rectangle().fill(Color.white.opacity(chaude ? 0.5 : 0.10)).frame(height: 1)
            }
    }
}
