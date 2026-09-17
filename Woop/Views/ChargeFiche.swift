import SwiftUI
import Charts

// MARK: - LA FICHE MUSCU — la courbe de charge et la ligne de coach (15/16-09)
//
// Plan : tools/fiche/PLAN-COURBE-CHARGE-COACH.md (§1 bis, la v3). À la place de
// la description, la fiche dit ce que TOI tu as fait, et ce que tu peux faire
// aujourd'hui.
//
// v3 (verdict « encore plus Apple + haptique ») : le graphe est SWIFT CHARTS — le
// cadre qui dessine ceux de Santé, Fitness et Bourse — habillé aux couleurs de
// la maison : une grille fine en pointillé, les kg à droite, les mois en bas,
// la ligne du record en pointillé chaleur, le lollipop sous le doigt, la pilule
// S · M · 6M, l'haptique des sélecteurs d'Apple. La phrase de coach arrive au
// shimmer. AUCUNE horloge : tout est valeur animable ou geste.

// MARK: Un passage

/// Un passage = un bloc de cet exercice dans une séance, avec ses séries FAITES.
/// Une valeur : construit hors du corps par `rafraichirPassages()`.
struct PassageCharge: Identifiable, Equatable {
    let id: UUID
    let date: Date
    /// La séance est encore ouverte.
    let enCours: Bool
    /// Les séries faites, dans l'ordre : (reps, kg).
    let series: [SerieFaite]
    var maxKg: Double { series.map(\.kg).max() ?? 0 }

    struct SerieFaite: Equatable {
        let reps: Int
        let kg: Double
    }

    /// LA SILHOUETTE DU VIDE — huit passages plausibles sur six mois, jamais
    /// deux pareils. En gris, sans chiffre : la loi du vide.
    static let silhouette: [PassageCharge] = {
        let kgs: [Double] = [40, 42.5, 42.5, 45, 47.5, 45, 50, 52.5]
        return kgs.enumerated().map { k, kg in
            PassageCharge(id: UUID(),
                          date: Date.now.addingTimeInterval(-Double(kgs.count - k) * 24 * 86_400),
                          enCours: false,
                          series: [SerieFaite(reps: 12, kg: kg), SerieFaite(reps: 10, kg: kg)])
        }
    }()
}

/// LA PÉRIODE — le sélecteur d'Apple Santé : la semaine, le mois, six mois.
enum PeriodeCharge: String, CaseIterable, Identifiable {
    case semaine = "S", mois = "M", sixMois = "6M"
    var id: String { rawValue }
    var jours: Double {
        switch self { case .semaine: 7; case .mois: 30; case .sixMois: 182 }
    }
    /// `-chargePeriode S|M|6M` : la période à l'arrivée (le banc).
    static let banc: PeriodeCharge? = {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: "-chargePeriode"), i + 1 < a.count else { return nil }
        return PeriodeCharge(rawValue: a[i + 1].uppercased())
    }()
}

// MARK: Le bloc de la fiche

/// Le slot sous le titre : l'étiquette, le nombre et la pilule ; la courbe ; la
/// coach. Tout arrive dans la vague du titre (`ArriveeDouce`).
struct CourbeChargeFiche: View {
    let passages: [PassageCharge]
    /// Le record tous temps (pas seulement les passages montrés).
    let recordKg: Double?
    var vide: Bool = false
    /// Le compte des records battus pendant ce passage : chaque hausse fait
    /// pulser le point et vibrer « succès ».
    var recordsBattus: Int = 0
    /// La ligne de coach : `nil` tant que personne n'a parlé (l'étoile respire).
    let phraseCoach: String?
    let coachAttend: Bool
    let vu: Bool

    @State private var periode: PeriodeCharge = PeriodeCharge.banc ?? .sixMois
    private let impactDoux = UIImpactFeedbackGenerator(style: .soft)

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            entete.modifier(ArriveeDouce(vu: vu, retard: 0.48))
            // 108 pt quand la page a la place, 60 au plancher : c'est la
            // courbe qui cède quand le galet remonte (iPhone 15, titre de
            // deux lignes) — jamais la ligne de coach.
            CourbeCharge(passages: vide ? PassageCharge.silhouette : passages,
                         recordKg: vide ? nil : recordKg,
                         periode: vide ? .sixMois : periode,
                         recordsBattus: recordsBattus,
                         vide: vide)
                .frame(minHeight: 60, idealHeight: 108, maxHeight: 108)
                .modifier(ArriveeDouce(vu: vu, retard: 0.58))
                .chambreVide(vide)
            LigneCoach(phrase: phraseCoach, attend: coachAttend)
                .padding(.top, 2)
                .modifier(ArriveeDouce(vu: vu, retard: 0.78))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { impactDoux.prepare() }
    }

    /// L'EN-TÊTE, à la façon de Santé : DERNIÈRE CHARGE en petites capitales,
    /// le nombre grand et léger, « kg » petit, l'écart en chaleur s'il monte ;
    /// à droite, la pilule S · M · 6M.
    private var entete: some View {
        let dernier = passages.last?.maxKg ?? 0
        let avant = passages.dropLast().last?.maxKg
        let delta = avant.map { dernier - $0 } ?? 0
        return HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(L("DERNIÈRE CHARGE", "LAST LOAD"))
                    .font(.inter(9.5, .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Color.white.opacity(0.38))
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    if vide {
                        Text("·").font(.inter(34, .light)).foregroundStyle(Color.white.opacity(0.25))
                    } else {
                        Text(ChambreFmt.poids(dernier))
                            .font(.inter(34, .light))
                            .tracking(-1)
                            .monospacedDigit()
                            .encreMetal()
                        Text("kg")
                            .font(.inter(13, .medium))
                            .foregroundStyle(Color.white.opacity(0.42))
                        if delta > 0.01 {
                            Text("+" + ChambreFmt.poids(delta))
                                .font(.inter(13, .semibold))
                                .monospacedDigit()
                                .foregroundStyle(CardTon.encreChaude)
                                .padding(.leading, 3)
                        }
                    }
                }
            }
            Spacer(minLength: 8)
            if !vide {
                PilulePeriode(choix: periode) { p in
                    guard p != periode else { return }
                    impactDoux.impactOccurred(intensity: 0.7)
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { periode = p }
                }
                .padding(.bottom, 4)
            }
        }
    }
}

// MARK: La pilule de période

/// S · M · 6M — la matière des chips du header (le verre fumé noir), un galet
/// de lumière qui glisse sous le segment choisi. Des taps prioritaires : la
/// fiche vit sous un drag d'ancêtre (loi §4, jamais un `Button`).
struct PilulePeriode: View {
    let choix: PeriodeCharge
    var onChoix: (PeriodeCharge) -> Void
    @Namespace private var galet

    var body: some View {
        HStack(spacing: 2) {
            ForEach(PeriodeCharge.allCases) { p in
                Text(p.rawValue)
                    .font(.inter(11, .semibold))
                    .foregroundStyle(p == choix ? Color.inkPrimary : Color.white.opacity(0.42))
                    .frame(width: 34, height: 26)
                    .background {
                        if p == choix {
                            Capsule().fill(Color.white.opacity(0.13))
                                .matchedGeometryEffect(id: "galet", in: galet)
                        }
                    }
                    .contentShape(Capsule())
                    .highPriorityGesture(TapGesture().onEnded { onChoix(p) })
            }
        }
        .padding(3)
        .background {
            Capsule()
                .fill(Color.clear)
                .glassEffect(.regular.tint(Color.black.opacity(0.5)), in: Capsule())
        }
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }
}

// MARK: La courbe (Swift Charts)

/// LE GRAPHE D'APPLE SANTÉ, aux couleurs de la maison. Aucune horloge : il ne
/// bouge qu'à l'arrivée (un masque qui révèle le fil), au changement de période
/// (le ressort de Swift Charts) et sous le doigt (le lollipop).
struct CourbeCharge: View {
    let passages: [PassageCharge]
    let recordKg: Double?
    let periode: PeriodeCharge
    var recordsBattus: Int = 0
    var vide = false

    /// La date sous le doigt (Swift Charts la donne), le passage le plus proche.
    @State private var doigt: Date?
    @State private var choisi: PassageCharge.ID?
    @State private var apparu = false
    /// Le point qui pulse au record battu.
    @State private var pulse = false

    private let tic = UISelectionFeedbackGenerator()
    private let bravo = UINotificationFeedbackGenerator()

    /// `-chargeChoisi <i>` : le i-ème point visible déjà sous le doigt.
    private static let choisiBanc: Int? = {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: "-chargeChoisi"), i + 1 < a.count else { return nil }
        return Int(a[i + 1])
    }()

    // MARK: le temps et l'échelle

    private var fin: Date { .now }
    private var debut: Date { fin.addingTimeInterval(-periode.jours * 86_400) }
    private var visibles: [PassageCharge] { passages.filter { $0.date >= debut } }

    private var lo: Double {
        let m = visibles.map(\.maxKg).min() ?? (recordKg ?? 40)
        return max((min(m, recordKg ?? m) - max(m * 0.15, 5)).rounded(.down), 0)
    }
    private var hi: Double {
        let m = visibles.map(\.maxKg).max() ?? (recordKg ?? 60)
        return (max(m, recordKg ?? m) + max(m * 0.10, 5)).rounded(.up)
    }
    private var selection: PassageCharge? {
        guard let id = choisi else { return nil }
        return visibles.first { $0.id == id }
    }

    var body: some View {
        graphe
            .chartXScale(domain: debut...fin)
            .chartYScale(domain: lo...hi)
            .chartXAxis { axeX }
            .chartYAxis { axeY }
            .chartLegend(.hidden)
            .chartPlotStyle { $0.background(Color.clear) }
            .chartXSelection(value: $doigt)
            // La capsule du lollipop, posée SUR le tracé (une annotation
            // au-dessus du tracé sortait du cadre et se faisait couper) :
            // en haut du plot, l'abscisse du point, bornée aux bords.
            .chartOverlay { proxy in
                GeometryReader { g in
                    if let s = selection, let x = proxy.position(forX: s.date) {
                        let plot = g[proxy.plotFrame!]
                        etiquette(s)
                            .position(x: min(max(plot.minX + x, plot.minX + 34), plot.maxX - 34),
                                      y: plot.minY + 14)
                            .transition(.opacity)
                            .allowsHitTesting(false)
                    }
                }
            }
            // Le fil se RÉVÈLE de gauche à droite à l'arrivée : un masque qui
            // s'ouvre (0,9 s), une seule fois, puis plus rien.
            .mask(alignment: .leading) {
                GeometryReader { g in
                    Rectangle().frame(width: apparu ? g.size.width : 0)
                }
            }
            .animation(.spring(response: 0.55, dampingFraction: 0.86), value: periode)
            .task {
                tic.prepare(); bravo.prepare()
                withAnimation(.easeOut(duration: 0.9)) { apparu = true }
            }
            .onChange(of: doigt) { _, d in
                guard !vide, let d else {
                    if Self.choisiBanc == nil { withAnimation(.easeOut(duration: 0.25)) { choisi = nil } }
                    return
                }
                let proche = visibles.min { abs($0.date.timeIntervalSince(d)) < abs($1.date.timeIntervalSince(d)) }
                if let proche, proche.id != choisi {
                    tic.selectionChanged()
                    withAnimation(.easeOut(duration: 0.12)) { choisi = proche.id }
                }
            }
            .onChange(of: passages.count, initial: true) { _, _ in
                if let c = Self.choisiBanc, visibles.indices.contains(c), !vide { choisi = visibles[c].id }
            }
            // LE RECORD BATTU, en séance : succès, et le dernier point pulse une fois.
            .onChange(of: recordsBattus) { _, n in
                guard n > 0 else { return }
                bravo.notificationOccurred(.success)
                pulse = true
                withAnimation(.spring(response: 0.5, dampingFraction: 0.45)) { pulse = false }
            }
    }

    // MARK: le dessin

    private var graphe: some View {
        Chart {
            // Le voile de chaleur, sous le fil.
            ForEach(visibles) { p in
                AreaMark(x: .value("date", p.date), y: .value("kg", p.maxKg))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(LinearGradient(
                        colors: [CardTon.chaleur(0.55).opacity(0.20), CardTon.chaleur(0.35).opacity(0.04), .clear],
                        startPoint: .top, endPoint: .bottom))
            }
            // Le fil : du graphite au chaud, le passé recule.
            ForEach(visibles) { p in
                LineMark(x: .value("date", p.date), y: .value("kg", p.maxKg))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(LinearGradient(
                        colors: [Color(white: 0.38), Color(white: 0.55), CardTon.chaleur(0.62), CardTon.chaleur(0.85)],
                        startPoint: .leading, endPoint: .trailing))
            }
            // Les points, fins ; le dernier allumé.
            ForEach(visibles) { p in
                let dernier = p.id == visibles.last?.id
                PointMark(x: .value("date", p.date), y: .value("kg", p.maxKg))
                    .symbolSize(dernier ? (pulse ? 160 : 60) : 14)
                    .foregroundStyle(dernier ? CardTon.chaleur(0.85) : Color(white: 0.6))
            }
            // LA LIGNE DU RECORD — la ligne d'objectif de Santé : pointillé
            // chaleur, SANS chiffre (17-09, « trop de texte ») : le record
            // se lit dans l'en-tête et sous le doigt, la ligne suffit.
            if let r = recordKg, !vide {
                RuleMark(y: .value("record", r))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    .foregroundStyle(CardTon.chaleur(0.7).opacity(0.75))
            }
            // LE LOLLIPOP : le fil vertical, le point qui grossit avec son
            // anneau, la capsule au-dessus.
            if let s = selection {
                RuleMark(x: .value("sel", s.date))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .foregroundStyle(Color.white.opacity(0.22))
                PointMark(x: .value("sel", s.date), y: .value("kg", s.maxKg))
                    .symbolSize(90)
                    .foregroundStyle(CardTon.chaleur(0.85))
                PointMark(x: .value("sel", s.date), y: .value("kg", s.maxKg))
                    .symbol { Circle().strokeBorder(Color.white.opacity(0.9), lineWidth: 1.5).frame(width: 13, height: 13) }
            }
        }
    }

    /// La capsule du lollipop : obsidienne à liseré (pas de verre sur du noir),
    /// le poids en clair, la date et les reps dessous.
    private func etiquette(_ p: PassageCharge) -> some View {
        let reps = p.series.map { "\($0.reps)" }.joined(separator: " ")
        return VStack(alignment: .leading, spacing: 1) {
            Text("\(ChambreFmt.poids(p.maxKg)) kg")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(CardTon.encre)
            Text("\(p.enCours ? L("auj.", "today") : ChambreFmt.jourCourt(p.date)) · \(reps)")
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.55))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color(white: 0.10)))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
        .fixedSize()
    }

    // MARK: les axes

    /// Les mois (ou les jours, en S) en bas, gris sourd, aucune ligne verticale.
    private var axeX: some AxisContent {
        AxisMarks(values: valeursX) { v in
            AxisValueLabel(anchor: .top) {
                if let d = v.as(Date.self) {
                    Text(libelleX(d))
                        .font(.system(size: 9.5, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.35))
                }
            }
        }
    }

    /// Les kg à DROITE, deux lignes en pointillé à 7 % de blanc (trois
    /// disaient trop, 17-09).
    private var axeY: some AxisContent {
        AxisMarks(position: .trailing, values: .automatic(desiredCount: 2)) { v in
            AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 4]))
                .foregroundStyle(Color.white.opacity(0.07))
            AxisValueLabel(anchor: .leading) {
                if let kg = v.as(Double.self) {
                    Text(ChambreFmt.poids(kg))
                        .font(.system(size: 9.5, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.35))
                        .padding(.leading, 4)
                }
            }
        }
    }

    private var valeursX: [Date] {
        let cal = Calendar.current
        switch periode {
        case .semaine:
            return (0...6).compactMap { cal.date(byAdding: .day, value: -6 + $0, to: cal.startOfDay(for: fin)) }
        case .mois:
            return stride(from: 0, through: 28, by: 7).compactMap { cal.date(byAdding: .day, value: -28 + $0, to: cal.startOfDay(for: fin)) }
        case .sixMois:
            var out: [Date] = []
            var d = cal.date(from: cal.dateComponents([.year, .month], from: debut)) ?? debut
            d = cal.date(byAdding: .month, value: 1, to: d) ?? d
            while d <= fin { out.append(d); d = cal.date(byAdding: .month, value: 1, to: d) ?? fin.addingTimeInterval(1) }
            return out
        }
    }

    private func libelleX(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "fr_FR")
        switch periode {
        case .semaine: f.dateFormat = "EEEEE"      // L M M J V S D
        case .mois:    f.dateFormat = "d"
        case .sixMois: f.dateFormat = "MMM"
        }
        return f.string(from: d).replacingOccurrences(of: ".", with: "").lowercased()
    }
}

// MARK: La ligne de coach

/// « Un dégradé blanc qui apparaît, avec une mini animation d'étoile pour
/// montrer que quelqu'un parle ». v3 : le texte arrive AU SHIMMER — une
/// lumière fine balaie les lettres une seule fois (le reveal des outils
/// d'écriture d'Apple), puis l'encre se pose en dégradé blanc. Un masque de
/// dégradé qui se déplace : une valeur animable, aucune horloge.
struct LigneCoach: View {
    let phrase: String?
    let attend: Bool

    @State private var arrivees = 0
    @State private var posee = false
    /// Le balayage : −1 (à gauche, hors texte) → 2 (à droite, sorti).
    @State private var balayage: CGFloat = -1

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            etoile.frame(width: 14, height: 14)
            if let phrase {
                Text(phrase)
                    .font(.inter(13, .medium))
                    .encreMetal()
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .overlay {
                        // La lumière qui passe : un dégradé étroit, masqué par
                        // les lettres, qui traverse une fois.
                        GeometryReader { g in
                            LinearGradient(colors: [.clear, .white.opacity(0.85), .clear],
                                           startPoint: .leading, endPoint: .trailing)
                                .frame(width: g.size.width * 0.45)
                                .offset(x: balayage * g.size.width)
                        }
                        .mask(Text(phrase).font(.inter(13, .medium)).lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true))
                        .allowsHitTesting(false)
                    }
                    .opacity(posee ? 1 : 0)
                    .animation(.easeOut(duration: 0.5), value: posee)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: phrase, initial: true) { _, p in
            guard p != nil else { posee = false; balayage = -1; return }
            posee = false
            balayage = -1
            arrivees += 1
            DispatchQueue.main.async {
                posee = true
                withAnimation(.easeInOut(duration: 0.85).delay(0.1)) { balayage = 2 }
            }
        }
    }

    /// L'étoile : respire quand il écrit, éclate quand la phrase arrive, se
    /// pose ensuite. Des valeurs animables seulement.
    private var etoile: some View {
        Image(systemName: "sparkle")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(LinearGradient(colors: [CardTon.chaleur(0.85), CardTon.chaleur(0.55)],
                                            startPoint: .top, endPoint: .bottom))
            .keyframeAnimator(initialValue: Eclat(), trigger: arrivees) { vue, v in
                vue.scaleEffect(v.echelle).rotationEffect(.degrees(v.angle)).opacity(v.opacite)
            } keyframes: { _ in
                KeyframeTrack(\.echelle) {
                    SpringKeyframe(1.22, duration: 0.28, spring: .bouncy)
                    SpringKeyframe(1.0, duration: 0.42, spring: .smooth)
                }
                KeyframeTrack(\.angle) {
                    CubicKeyframe(24, duration: 0.30)
                    CubicKeyframe(0, duration: 0.40)
                }
                KeyframeTrack(\.opacite) {
                    CubicKeyframe(1.0, duration: 0.20)
                    CubicKeyframe(0.95, duration: 0.50)
                }
            }
            .phaseAnimator([0.35, 0.95], trigger: attend) { vue, phase in
                vue.opacity(attend ? phase : 1)
            } animation: { _ in
                attend ? .easeInOut(duration: 1.1) : .easeOut(duration: 0.3)
            }
    }

    private struct Eclat {
        var echelle: Double = 1
        var angle: Double = 0
        var opacite: Double = 0.95
    }
}
