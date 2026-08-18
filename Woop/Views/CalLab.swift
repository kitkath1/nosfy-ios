import SwiftUI

// MARK: - Banc du calendrier à stickers (`-calLab`)

/// Banc de la page calendrier : `-calLab` — la carte-semaine de verre
/// fondue dans l'îlot (réf. salut.png), dépliée au repos en calendrier
/// mensuel, et la liste des sessions d'entraînement qui scrolle dessous :
/// le scroll replie la carte en mini sticky, le retour en haut la
/// redéplie. `-calAuto` : boucle de scroll automatique (vidéo).
struct CalLab: View {
    private static let auto = CommandLine.arguments.contains("-calAuto")

    var body: some View {
        CalendarStickersPage(autoLoop: Self.auto)
    }
}

// MARK: - Le fouettage du verre

/// Les molettes de la console : persistées (`@AppStorage`) pour que la
/// bonne combinaison survive aux relances — Kathryn lit les valeurs sur
/// le panneau et on les grave ensuite en dur.
private struct GlassTuning {
    var clearGlass: Bool
    var tintWhite: Double
    var tintAlpha: Double
    var interactive: Bool
    var edgeAlpha: Double
    var glowOpacity: Double
    var corner: Double

    var teinte: Color { Color(white: tintWhite).opacity(tintAlpha) }
    var verre: Glass {
        let base: Glass = clearGlass ? .clear : .regular
        let teinte = base.tint(self.teinte)
        return interactive ? teinte.interactive() : teinte
    }
}

// MARK: - La page

/// La page calendrier : le noir nu, la carte de verre pincée en haut
/// (HORS du scroll — un scroll ne tient pas une carte), la liste des
/// sessions qui glisse dessous, la dalle-player au bord bas. UN SEUL
/// CURSEUR pilote le morph : l'offset du scroll ; le drag direct sur la
/// carte s'y raccorde en fin de geste. `onBack` : la sortie du chevron.
struct CalendarStickersPage: View {
    var autoLoop = false
    var onBack: () -> Void = {}

    @State private var monthAnchor = Date()
    @State private var pushEdge: Edge = .trailing
    /// Le tirage direct sur la carte, en points (0 hors geste).
    @State private var cardDrag: CGFloat = 0
    /// L'offset brut de la sonde. Le repos vaut EXACTEMENT `-inset`
    /// (l'inset, c'est nous qui le fixons) : rel = offset + inset. PIÈGE
    /// payé : capturer un « offset de repos » au premier passage de la
    /// sonde — il précède la négociation des marges et empoisonne le
    /// curseur (p ≈ 1,2 au repos, carte distendue en permanence).
    @State private var scrollY: CGFloat?
    @State private var scrollPos = ScrollPosition()

    // La story : le rect tapé devient l'écran (le portail de la home).
    @State private var story: CalStoryLaunch?
    /// La case/row qui s'illumine au tap, l'instant avant le portail.
    @State private var flashDay: Date?
    @State private var flashRow: Date?
    /// L'ardoise est en main : le drag de la carte se désarme (la loi
    /// payée sur la fiche exo — un doigt qui échappe fait respirer la
    /// page).
    @State private var slateBusy = false

    // La console du verre — double-tap pour l'afficher/cacher, valeurs
    // persistées entre relances.
    @State private var showTune = CommandLine.arguments.contains("-calTune")
    @AppStorage("calClear") private var tClear = false
    @AppStorage("calTintW") private var tTintW = 0.0
    @AppStorage("calTintA") private var tTintA = 0.5
    @AppStorage("calInter") private var tInter = false
    @AppStorage("calEdge") private var tEdge = 0.06
    @AppStorage("calGlow") private var tGlow = 1.0
    @AppStorage("calCorner") private var tCorner = 40.0

    private var tuning: GlassTuning {
        GlassTuning(clearGlass: tClear, tintWhite: tTintW,
                    tintAlpha: tTintA, interactive: tInter,
                    edgeAlpha: tEdge, glowOpacity: tGlow, corner: tCorner)
    }

    /// Démo du player : la séance a commencé il y a 23 minutes.
    private static let demoStart = Date().addingTimeInterval(-23 * 60)

    private var calendar: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2 // lundi
        return c
    }

    private var anchorIsCurrent: Bool {
        calendar.isDate(monthAnchor, equalTo: Date(), toGranularity: .month)
    }

    var body: some View {
        GeometryReader { host in
            let geo = CalGeo(safeTop: host.safeAreaInsets.top,
                             width: host.size.width)
            let slots = CalSlot.month(of: monthAnchor, calendar: calendar)
            let rowCount = (slots.last?.row ?? 4) + 1
            let expandedH = geo.expandedH(rows: rowCount)
            let course = max(1, expandedH - geo.collapsedH)
            let inset = expandedH + 14
            let rel = scrollY ?? 0
            let p = rubber(max(0, 1 - rel / course) + cardDrag / course)

            ZStack(alignment: .top) {
                Color.black
                sessionList(inset: inset, course: course)
                // LA SCÈNE : la source braise hors cadre du header exo,
                // DERRIÈRE le verre — sans lumière à réfracter, le liquid
                // glass n'est qu'une plaque grise. Posée au-dessus de la
                // liste : les cards s'éclairent en passant dessous.
                ExoHeaderGlow(height: 380)
                    .opacity(tuning.glowOpacity)
                // Les petits halos du coin droit — la respiration du
                // fond de la home, à l'échelle d'un coin, derrière le
                // verre qui les réfracte. PAS asservis à la molette
                // SCÈNE : demandés pour eux-mêmes, ils vivent toujours.
                CoinHalosDroit()
                    .frame(height: 320)
                card(geo: geo, slots: slots, rowCount: rowCount,
                     p: p, course: course, inset: inset)
                // L'ARDOISE de la fiche exo, entière : la dalle fondue au
                // bord physique, qu'on tire vers le haut pour la
                // partition de la séance.
                SessionSlate(exercise: ExerciseCatalog.all[0],
                             progress: 0.4,
                             startedAt: Self.demoStart,
                             drafts: Self.demoDrafts,
                             restSeconds: 60,
                             workout: nil,
                             safeBottom: host.safeAreaInsets.bottom,
                             busy: $slateBusy)
                if showTune { tunePanel }
            }
            .ignoresSafeArea()
            .onTapGesture(count: 2) {
                withAnimation(.easeOut(duration: 0.2)) {
                    showTune.toggle()
                }
            }
            .task { await autoScroll(inset: inset, course: course) }
            // La story couvre tout — la grammaire exacte de la home.
            .fullScreenCover(item: $story) { launch in
                let _ = print("SONDE cover: présentation id=\(launch.id)")
                StoryPortal(from: launch.rect, session: launch.session) {
                    var tx = Transaction()
                    tx.disablesAnimations = true
                    withTransaction(tx) { story = nil }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    /// Démo de l'ardoise : trois séries faites, deux à venir.
    private static let demoDrafts: [DraftSet] = [
        DraftSet(reps: 12, weight: 20, isDone: true, durationSeconds: 64),
        DraftSet(reps: 12, weight: 22, isDone: true, durationSeconds: 71),
        DraftSet(reps: 10, weight: 24, isDone: true, durationSeconds: 58),
        DraftSet(reps: 10, weight: 24),
        DraftSet(reps: 8, weight: 26),
    ]

    // MARK: Le départ de la story

    /// La case s'illumine, puis le rect tapé devient l'écran.
    private func openStory(day: Date, rect: CGRect) {
        guard let s = DemoSession.at(day, calendar: calendar) else { return }
        flashDay = day
        launchStory(session: s.storySession, rect: rect) { flashDay = nil }
    }

    private func openStory(row: DemoSession, rect: CGRect) {
        flashRow = row.date
        launchStory(session: row.storySession, rect: rect) { flashRow = nil }
    }

    private func launchStory(session: StorySession, rect: CGRect,
                             clear: @escaping () -> Void) {
        Task {
            try? await Task.sleep(for: .milliseconds(140))
            story = CalStoryLaunch(rect: rect, session: session)
            try? await Task.sleep(for: .milliseconds(500))
            withAnimation(.easeOut(duration: 0.4)) { clear() }
        }
    }

    /// La résistance hors bornes — la traction au-delà du haut étire un
    /// peu la carte (l'overshoot du ressort passe par là aussi).
    private func rubber(_ x: CGFloat) -> CGFloat {
        if x > 1 { return 1 + (x - 1) * 0.14 }
        if x < 0 { return x * 0.14 }
        return x
    }

    // MARK: La carte

    private func card(geo: CalGeo, slots: [CalSlot], rowCount: Int,
                      p: CGFloat, course: CGFloat,
                      inset: CGFloat) -> some View {
        CardMorph(p: p,
                  geo: geo,
                  slots: slots,
                  rowCount: rowCount,
                  weekRow: slots.first(
                      where: { calendar.isDateInToday($0.day) })?.row ?? 2,
                  anchorIsCurrent: anchorIsCurrent,
                  todayColumn: (calendar.component(.weekday, from: Date())
                      - calendar.firstWeekday + 7) % 7,
                  monthTitle: monthAnchor
                      .formatted(.dateTime.month(.wide).year()).capitalized,
                  calendar: calendar,
                  pushEdge: pushEdge,
                  onBack: onBack,
                  onMonthStep: monthStep,
                  tuning: tuning,
                  flashDay: flashDay,
                  onDayTap: openStory)
            // BORD À BORD : la moindre incrustation laisse la braise
            // passer sur les flancs et trahit le bord de la carte
            // (verdict du 18-08, réf. mini-player Apple Music).
            .contentShape(Rectangle())
            .gesture(cardGesture(course: course, inset: inset),
                     isEnabled: !slateBusy)
    }

    private func monthStep(_ dir: Int) {
        pushEdge = dir > 0 ? .trailing : .leading
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            monthAnchor = calendar.date(byAdding: .month, value: dir,
                                        to: monthAnchor) ?? monthAnchor
        }
    }

    /// Le drag direct sur la carte : il nourrit le même curseur, et la
    /// fin de geste se règle en scrollant la liste — la sonde re-synce
    /// tout, pas de guerre d'états.
    private func cardGesture(course: CGFloat, inset: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { v in
                // Un repli qui part d'un autre mois se recale sur le mois
                // courant : la rangée mini montre TOUJOURS la semaine
                // d'aujourd'hui.
                if cardDrag == 0, !anchorIsCurrent { monthAnchor = Date() }
                cardDrag = v.translation.height
            }
            .onEnded { v in
                let base = max(0, 1 - (scrollY ?? 0) / course)
                let projected = base
                    + v.predictedEndTranslation.height / course
                let deploy = projected > 0.5
                cardDrag = 0
                withAnimation(.spring(response: 0.46,
                                      dampingFraction: 0.85)) {
                    scrollPos.scrollTo(y: deploy ? 0 : course)
                }
            }
    }

    // MARK: La liste des sessions

    private func sessionList(inset: CGFloat, course: CGFloat) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                // L'ESPACEUR, pas une marge : le repos vaut offset 0 et
                // `scrollTo(y:)` parle le même repère que la sonde —
                // avec `contentMargins`, cible et mesure divergeaient et
                // le repli ne se jouait jamais.
                Color.clear.frame(height: inset - 10)
                Text("SESSIONS D'ENTRAÎNEMENT")
                    .font(.inter(11, .semibold)).tracking(1.6)
                    .foregroundStyle(Color.inkSecondary)
                    .padding(.leading, 6)
                    .padding(.bottom, 2)
                ForEach(DemoSession.recent(calendar: calendar)) { s in
                    SessionRow(session: s,
                               flashing: flashRow == s.date,
                               onTap: { rect in openStory(row: s, rect: rect) })
                }
            }
            .padding(.horizontal, 14)
        }
        .scrollIndicators(.hidden)
        // L'air du bas : la dalle-player (76) + la zone sûre + du souffle.
        .contentMargins(.bottom, 134, for: .scrollContent)
        .scrollPosition($scrollPos)
        // UNE sonde, un champ vivant — l'offset brut EST le curseur.
        .onScrollGeometryChange(for: CGFloat.self,
                                of: { $0.contentOffset.y }) { _, y in
            scrollY = y
        }
        // L'aimant : jamais un calendrier à moitié plié au repos.
        .scrollTargetBehavior(CalAimant(course: course))
    }

    // MARK: La console du verre

    /// Le panneau de fouettage : les molettes du liquid glass, en direct.
    /// Double-tap n'importe où pour l'afficher/cacher.
    private var tunePanel: some View {
        VStack(spacing: 7) {
            HStack(spacing: 14) {
                tuneToggle("CLAIR", $tClear)
                tuneToggle("INTERACTIF", $tInter)
                Spacer(minLength: 0)
            }
            tuneRow("TEINTE BLANC", $tTintW, 0...1)
            tuneRow("TEINTE ALPHA", $tTintA, 0...1)
            tuneRow("LISERÉ", $tEdge, 0...0.3)
            tuneRow("SCÈNE", $tGlow, 0...1.5)
            tuneRow("RAYON", $tCorner, 12...64, fmt: "%.0f")
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.black.opacity(0.84)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
        .frame(width: 336)
        .frame(maxWidth: .infinity, maxHeight: .infinity,
               alignment: .bottom)
        .padding(.bottom, 100)
    }

    private func tuneRow(_ label: String, _ value: Binding<Double>,
                         _ range: ClosedRange<Double>,
                         fmt: String = "%.2f") -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.inter(9.5, .semibold)).tracking(0.8)
                .foregroundStyle(Color.inkSecondary)
                .frame(width: 86, alignment: .leading)
            Slider(value: value, in: range)
            Text(String(format: fmt, value.wrappedValue))
                .font(.inter(10).monospacedDigit())
                .foregroundStyle(Color.inkPrimary)
                .frame(width: 32, alignment: .trailing)
        }
    }

    private func tuneToggle(_ label: String,
                            _ value: Binding<Bool>) -> some View {
        Toggle(isOn: value) {
            Text(label)
                .font(.inter(9.5, .semibold)).tracking(0.8)
                .foregroundStyle(Color.inkSecondary)
        }
        .toggleStyle(.button)
        .buttonStyle(.bordered)
    }

    // MARK: La boucle vidéo

    private func autoScroll(inset: CGFloat, course: CGFloat) async {
        guard autoLoop else { return }
        var folded = false
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            folded.toggle()
            if !folded, !anchorIsCurrent { monthAnchor = Date() }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.88)) {
                scrollPos.scrollTo(y: folded ? course + 180 : 0)
            }
        }
    }
}

// MARK: - Le départ d'une story

/// Ce qu'il faut pour ouvrir la story depuis la page : le récit, et le
/// rectangle écran d'où le portail s'ouvre.
private struct CalStoryLaunch: Identifiable {
    let id = UUID()
    let rect: CGRect
    let session: StorySession
}

// MARK: - Les petits halos du coin droit

/// Trois lueurs qui dérivent dans le coin haut-droit — l'esprit du fond
/// animé de la home, à l'échelle d'un coin : des sinus mêlés à
/// fréquences étrangères (jamais un métronome), la palette braise,
/// en `plusLighter` — c'est de la lumière, pas un fond.
private struct CoinHalosDroit: View {
    private struct Halo {
        var ax: CGFloat      // ancre x, fraction de largeur
        var ay: CGFloat      // ancre y, points
        var dx: CGFloat      // amplitudes de dérive
        var dy: CGFloat
        var vx: Double       // vitesses (rad/s), étrangères entre elles
        var vy: Double
        var vo: Double       // le souffle d'opacité
        var r: CGFloat       // rayon
        var c: Color
        var o: Double        // opacité de crête
        var phase: Double
    }

    private static let halos: [Halo] = [
        Halo(ax: 0.88, ay: 92, dx: 16, dy: 11, vx: 0.093, vy: 0.117,
             vo: 0.151, r: 96, c: FlammePalette.or, o: 0.18, phase: 0.0),
        Halo(ax: 0.73, ay: 168, dx: 24, dy: 15, vx: 0.127, vy: 0.083,
             vo: 0.109, r: 60, c: FlammePalette.flamme, o: 0.21,
             phase: 2.1),
        Halo(ax: 0.94, ay: 214, dx: 12, dy: 19, vx: 0.071, vy: 0.139,
             vo: 0.187, r: 38, c: FlammePalette.jaune, o: 0.24,
             phase: 4.4),
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 4096)
            Canvas { ctx, size in
                for h in Self.halos {
                    let x = size.width * h.ax
                        + h.dx * CGFloat(sin(t * h.vx + h.phase))
                    let y = h.ay
                        + h.dy * CGFloat(sin(t * h.vy + h.phase * 1.7))
                    let souffle = 0.68
                        + 0.32 * sin(t * h.vo + h.phase * 2.3)
                    let center = CGPoint(x: x, y: y)
                    let rect = CGRect(x: x - h.r, y: y - h.r,
                                      width: h.r * 2, height: h.r * 2)
                    ctx.fill(Path(ellipseIn: rect), with: .radialGradient(
                        Gradient(stops: [
                            .init(color: h.c.opacity(h.o * souffle),
                                  location: 0),
                            .init(color: h.c.opacity(0), location: 1),
                        ]),
                        center: center, startRadius: 0, endRadius: h.r))
                }
            }
        }
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }
}

// MARK: - L'aimant du scroll

/// La fin de geste ne laisse jamais la carte à mi-course : dans la bande
/// du morph, la cible file au haut (dépliée) ou juste après la course
/// (mini) — au-delà, la liste scrolle libre sous la mini sticky.
private struct CalAimant: ScrollTargetBehavior {
    var course: CGFloat

    func updateTarget(_ target: inout ScrollTarget,
                      context: TargetContext) {
        let rel = target.rect.origin.y
        guard rel > 0, rel < course else { return }
        target.rect.origin.y = rel < course / 2 ? 0 : course
    }
}

// MARK: - Les cotes de la carte

/// Toute la géométrie du dépliage, interpolée sur `p` ∈ [0,1] : les
/// colonnes glissent du rang replié (à droite du chevron) au rang plein
/// (toute la largeur), les rangées s'écartent de la ligne-pivot de la
/// semaine courante.
private struct CalGeo {
    let safeTop: CGFloat
    let width: CGFloat // largeur de la carte

    let padMini: CGFloat = 10
    let gapMini: CGFloat = 4
    /// Le couloir du chevron replié : 44 de chip + 8 d'air.
    let chevronSlot: CGFloat = 52
    let padFull: CGFloat = 14
    let gapFull: CGFloat = 6

    var sMini: CGFloat { (width - 2 * padMini - chevronSlot - 6 * gapMini) / 7 }
    var sFull: CGFloat { (width - 2 * padFull - 6 * gapFull) / 7 }

    // Replié : lettres, puis la rangée de cases.
    var lettersYc: CGFloat { safeTop + 13 }
    var cellsTopC: CGFloat { safeTop + 24 }
    var cellCenterYc: CGFloat { cellsTopC + sMini / 2 }

    // Déplié : en-tête (chevron + mois + ‹ ›), pastilles, grille — la
    // rangée LUN respire sous la ligne du chevron (verdict : trop collée).
    var headerYe: CGFloat { safeTop + 28 }
    var chipsYe: CGFloat { safeTop + 6 + 44 + 18 + 13 }
    var gridTopE: CGFloat { safeTop + 6 + 44 + 18 + 26 + 8 }

    var collapsedH: CGFloat { cellsTopC + sMini + 16 }
    func expandedH(rows: Int) -> CGFloat {
        gridTopE + CGFloat(rows) * sFull
            + CGFloat(max(0, rows - 1)) * gapFull + 22
    }

    func lerp(_ a: CGFloat, _ b: CGFloat, _ p: CGFloat) -> CGFloat {
        a + (b - a) * p
    }

    func cellSize(_ p: CGFloat) -> CGFloat { lerp(sMini, sFull, p) }

    func colCenter(_ col: Int, _ p: CGFloat) -> CGFloat {
        let xc = padMini + chevronSlot + CGFloat(col) * (sMini + gapMini)
            + sMini / 2
        let xe = padFull + CGFloat(col) * (sFull + gapFull) + sFull / 2
        return lerp(xc, xe, p)
    }

    /// Le centre de la ligne-pivot (la semaine courante) : de la rangée
    /// repliée à sa ligne dans le mois.
    func weekCenterY(_ p: CGFloat, weekRow: Int) -> CGFloat {
        let ye = gridTopE + CGFloat(weekRow) * (sFull + gapFull) + sFull / 2
        return lerp(cellCenterYc, ye, p)
    }

    /// Les autres rangées s'écartent du pivot au fil du tirage.
    func rowCenterY(_ row: Int, weekRow: Int, _ p: CGFloat) -> CGFloat {
        weekCenterY(p, weekRow: weekRow)
            + CGFloat(row - weekRow) * (sFull + gapFull) * p
    }

    func lettersY(_ p: CGFloat) -> CGFloat { lerp(lettersYc, chipsYe, p) }
}

// MARK: - Une case posée dans la grille du mois

private struct CalSlot: Identifiable {
    let day: Date
    let col: Int
    let row: Int
    var id: Date { day }

    static func month(of anchor: Date, calendar: Calendar) -> [CalSlot] {
        guard let interval = calendar.dateInterval(of: .month, for: anchor)
        else { return [] }
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        let count = calendar.range(of: .day, in: .month,
                                   for: anchor)?.count ?? 30
        return (0..<count).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset,
                                          to: interval.start)
            else { return nil }
            let i = leading + offset
            return CalSlot(day: day, col: i % 7, row: i / 7)
        }
    }
}

// MARK: - Le rendu de la carte, animable sur p

/// TOUT le dessin vit ici, fonction pure de `p` — et la struct est
/// `Animatable` sur `p` : un `withAnimation` (snap de fin de geste,
/// boucle `-calAuto`) TRAVERSE les valeurs intermédiaires et rejoue la
/// même chorégraphie que le doigt. Sans ça, chaque opacité filait en
/// parallèle vers sa cible et les deux faces se superposaient (le
/// « contenu trop différent » du premier montage).
private struct CardMorph: View, Animatable {
    var p: CGFloat
    var geo: CalGeo
    var slots: [CalSlot]
    var rowCount: Int
    var weekRow: Int
    var anchorIsCurrent: Bool
    var todayColumn: Int
    var monthTitle: String
    var calendar: Calendar
    var pushEdge: Edge
    var onBack: () -> Void
    var onMonthStep: (Int) -> Void
    /// Les molettes de la console (`tunePanel`) : variante de verre,
    /// teinte, liseré, rayon — réglées au doigt, gravées ensuite.
    var tuning: GlassTuning
    /// La case qui s'illumine (l'instant avant la story), et le tap.
    var flashDay: Date?
    var onDayTap: (Date, CGRect) -> Void

    var animatableData: CGFloat {
        get { p }
        set { p = newValue }
    }

    private var corner: CGFloat { CGFloat(tuning.corner) }

    private var weekdayHeads: [String] {
        let syms = calendar.shortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(syms[first...] + syms[..<first])
            .map { String($0.prefix(3)).uppercased() }
    }

    private var weekdayLetters: [String] {
        let syms = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(syms[first...] + syms[..<first])
            .map { $0.uppercased() }
    }

    var body: some View {
        // p sert la géométrie (l'overshoot du ressort étire un peu la
        // carte) ; pc borne les fondus.
        let pc = min(max(p, 0), 1)
        let full = geo.expandedH(rows: rowCount)
        let h = geo.collapsedH + (full - geo.collapsedH) * p
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)

        ZStack(alignment: .topLeading) {
            // LE VERRE : la carte est un liquid glass teinté — la liste
            // des sessions glisse dessous et le verre la réfracte.
            // TAILLE CONSTANTE, et c'est une LOI : un backdrop dont les
            // bounds changent à chaque frame retombe en rendu de secours
            // (le blur plat) et n'en revient pas — le bug « ça a marché
            // puis c'est redevenu blur ». Seule la FENÊTRE de clip
            // s'anime.
            Color.clear
                .glassEffect(tuning.verre, in: shape)
            // Les couches en `plusLighter` vivent dans LEUR groupe : un
            // blend qui remonte jusqu'au frère verre le force hors-écran
            // et le tue. Le chevron (son propre verre) reste DEHORS.
            ZStack(alignment: .topLeading) {
                todayGlow(pc: pc)
                lettersRow(pc: pc)
                cellsGrid(pc: pc)
            }
            .compositingGroup()
            header(pc: pc)
        }
        // `alignment: .top` — le contenu déplié est plus grand que le
        // cadre replié : sans lui, tout serait centré et sortirait du clip.
        .frame(width: geo.width, height: full, alignment: .top)
        .frame(height: h, alignment: .top)
        .clipShape(shape)
        // LE LISERÉ SANS HAUT : la carte est bord à bord, un trait qui
        // traverse le sommet de l'écran se lit comme un artefact
        // (verdict 18-08) — la grammaire de la dalle du player (liseré
        // sans bas), inversée.
        .overlay(shape.strokeBorder(
            LinearGradient(stops: [
                .init(color: .clear, location: 0.0),
                .init(color: Color.white.opacity(tuning.edgeAlpha * 0.6),
                      location: 0.22),
                .init(color: Color.white.opacity(tuning.edgeAlpha),
                      location: 0.6),
                .init(color: Color.white.opacity(tuning.edgeAlpha),
                      location: 1.0),
            ], startPoint: .top, endPoint: .bottom),
            lineWidth: 1))
        .overlay(alignment: .bottom) {
            Capsule()
                .fill(Color.white.opacity(0.32))
                .frame(width: 36, height: 4)
                .padding(.bottom, 7)
        }
    }

    // MARK: Le halo du jour — la lumière que le verre réfracte

    /// La lueur orangé/or posée sous la case d'aujourd'hui, qui voyage
    /// avec elle pendant le morph. En sourdine : la règle anti-brun,
    /// tenir la saturation, jamais l'opacité.
    @ViewBuilder
    private func todayGlow(pc: CGFloat) -> some View {
        if anchorIsCurrent,
           let slot = slots.first(where: { calendar.isDateInToday($0.day) }) {
            Circle()
                .fill(RadialGradient(
                    colors: [FlammePalette.flamme.opacity(0.07),
                             FlammePalette.or.opacity(0.02),
                             .clear],
                    center: .center, startRadius: 4, endRadius: 70))
                .frame(width: 140, height: 140)
                .position(x: geo.colCenter(slot.col, p),
                          y: geo.rowCenterY(slot.row,
                                            weekRow: weekRow, p))
                .blendMode(.plusLighter)
        }
    }

    // MARK: L'en-tête — le chevron ne disparaît JAMAIS

    private func header(pc: CGFloat) -> some View {
        let titleAlpha = Double(min(1, max(0, (pc - 0.55) / 0.35)))
        return ZStack(alignment: .topLeading) {
            // Le chevron de la maison : même x aux deux états, il glisse
            // juste de la rangée repliée vers la ligne d'en-tête.
            ChipVerre(symbole: "chevron.left", label: "Retour",
                      action: onBack)
                .position(x: geo.padMini + 22,
                          y: geo.lerp(geo.cellCenterYc, geo.headerYe, pc))

            // Le mois façon Apple + les ‹ › — n'existent que dépliés.
            HStack(spacing: 0) {
                Text(monthTitle)
                    .font(.inter(20, .bold)).tracking(-0.3)
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                navButton(symbol: "chevron.left", step: -1)
                navButton(symbol: "chevron.right", step: 1)
            }
            .padding(.leading, geo.padMini + geo.chevronSlot)
            .padding(.trailing, geo.padFull)
            .frame(width: geo.width, height: 44)
            .position(x: geo.width / 2, y: geo.headerYe)
            .opacity(titleAlpha)
            .allowsHitTesting(pc > 0.9)
        }
    }

    private func navButton(symbol: String, step: Int) -> some View {
        Button { onMonthStep(step) } label: {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.inkPrimary.opacity(0.9))
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: La rangée des jours — la même, qui s'étoffe

    private func lettersRow(pc: CGFloat) -> some View {
        let y = geo.lettersY(pc)
        return ZStack(alignment: .topLeading) {
            ForEach(0..<7, id: \.self) { i in
                let isToday = anchorIsCurrent && i == todayColumn
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.white.opacity(0.07))
                        .opacity(Double(pc))
                    // « L » replié, « LUN » déplié — la même pastille.
                    Text(weekdayLetters[i])
                        .opacity(Double(1 - min(1, pc * 2)))
                    Text(weekdayHeads[i])
                        .opacity(Double(max(0, pc * 2 - 1)))
                }
                .font(.inter(10.5, .semibold)).tracking(1.0)
                .foregroundStyle(Color.white.opacity(isToday ? 0.95 : 0.45))
                .frame(width: geo.cellSize(pc), height: geo.lerp(15, 26, pc))
                .position(x: geo.colCenter(i, pc), y: y)
            }
            // Le point rouge du jour courant, au-dessus de sa lettre.
            if anchorIsCurrent {
                Circle()
                    .fill(Color(red: 1.0, green: 0.23, blue: 0.19))
                    .frame(width: 5, height: 5)
                    .position(x: geo.colCenter(todayColumn, pc), y: y - 11)
            }
        }
    }

    // MARK: La grille — la semaine voyage, le mois s'éventaille

    private func cellsGrid(pc: CGFloat) -> some View {
        let s = geo.cellSize(p)
        // Fenêtre resserrée : en cours de pli, les semaines qui se
        // superposent doivent déjà être presque éteintes — sinon la pile
        // de stickers fait une soupe au milieu de la course.
        let othersAlpha = Double(min(1, max(0, (pc - 0.25) / 0.5)))
        return ZStack(alignment: .topLeading) {
            ForEach(slots) { slot in
                let pivot = anchorIsCurrent && slot.row == weekRow
                let entraine = WoopSticker.demoCategory(
                    for: slot.day, calendar: calendar) != nil
                StickerDayCell(day: slot.day, size: s,
                               isToday: calendar.isDateInToday(slot.day),
                               calendar: calendar,
                               flashing: flashDay == slot.day,
                               onTap: entraine
                                   ? { r in onDayTap(slot.day, r) }
                                   : nil)
                    .position(x: geo.colCenter(slot.col, p),
                              y: geo.rowCenterY(slot.row,
                                                weekRow: weekRow, p))
                    .opacity(pivot ? 1 : othersAlpha)
            }
        }
        .id(monthTitle)
        .transition(.push(from: pushEdge).combined(with: .opacity))
    }
}

// MARK: - La case d'un jour

/// LA case — la même aux deux états, seule sa taille s'interpole. Jour
/// entraîné : le sticker de catégorie au centre, et la PETITE FLAMME qui
/// chevauche son coin (la flamme dit « séance », toujours présente).
/// Aujourd'hui : le liseré angulaire des médaillons du player + la bague,
/// sur le halo chaud que le verre réfracte.
private struct StickerDayCell: View {
    var day: Date
    var size: CGFloat
    var isToday: Bool
    var calendar: Calendar
    /// Le flash au tap — la case s'illumine l'instant avant la story.
    var flashing = false
    /// Le tap (jours entraînés seulement) : rend le rect ÉCRAN de la
    /// case, le portail de la story s'ouvre depuis lui.
    var onTap: ((CGRect) -> Void)? = nil

    var body: some View {
        let s = size
        let forme = RoundedRectangle(cornerRadius: s * 0.28,
                                     style: .continuous)
        ZStack {
            forme.fill(Color.white.opacity(isToday ? 0.10 : 0.055))
            if isToday {
                // Le cœur chaud de la case, en sourdine.
                forme.fill(RadialGradient(
                    colors: [FlammePalette.or.opacity(0.08),
                             FlammePalette.flamme.opacity(0.025),
                             .clear],
                    center: UnitPoint(x: 0.5, y: 0.42),
                    startRadius: 2, endRadius: s * 0.62))
                    .blendMode(.plusLighter)
            }
            if let cat = WoopSticker.demoCategory(for: day,
                                                  calendar: calendar) {
                Image(cat.asset)
                    .resizable()
                    .scaledToFit()
                    .frame(width: s * 0.52, height: s * 0.52)
                    .position(x: s * 0.44, y: s * 0.38)
                Image(WoopSticker.flamme.asset)
                    .resizable()
                    .scaledToFit()
                    .frame(width: s * 0.34, height: s * 0.34)
                    .rotationEffect(.degrees(12))
                    .position(x: s * 0.70, y: s * 0.54)
            }
            Text("\(calendar.component(.day, from: day))")
                .font(.inter(s * 0.27, isToday ? .bold : .medium))
                .foregroundStyle(isToday ? Color.inkPrimary
                                         : Color.white.opacity(0.60))
                .position(x: s * 0.5, y: s * 0.82)
        }
        .frame(width: s, height: s)
        .overlay {
            if isToday {
                // Le liseré premium des médaillons pause/play, et sa
                // bague qui flare en haut-gauche, DEHORS du bord.
                forme.strokeBorder(
                    AngularGradient(stops: LisereMedaillon.crans,
                                    center: .center, angle: .zero),
                    lineWidth: 1)
                forme.stroke(
                    AngularGradient(stops: LisereMedaillon.bague,
                                    center: .center, angle: .zero),
                    lineWidth: 2)
                    .blur(radius: 1.0)
                    .blendMode(.plusLighter)
                    .opacity(0.8)
            }
        }
        .overlay {
            // LE FLASH : la case s'illumine — liseré plein + cœur chaud,
            // le langage du jour actif poussé une seconde.
            if flashing {
                forme.fill(RadialGradient(
                    colors: [FlammePalette.or.opacity(0.30),
                             FlammePalette.flamme.opacity(0.10),
                             .clear],
                    center: .center, startRadius: 2, endRadius: s * 0.7))
                    .blendMode(.plusLighter)
                forme.strokeBorder(
                    AngularGradient(stops: LisereMedaillon.crans,
                                    center: .center, angle: .zero),
                    lineWidth: 1.4)
                    .blendMode(.plusLighter)
                .transition(.opacity)
            }
        }
        .overlay {
            if onTap != nil {
                GeometryReader { g in
                    Color.clear
                        .contentShape(forme)
                        .onTapGesture { onTap?(g.frame(in: .global)) }
                }
            }
        }
    }
}

// MARK: - La carte d'une session

/// La rangée de la liste — l'obsidienne de la dalle : le badge-date de
/// verre au liseré premium, le nom, séries · reps (+ mini basket si
/// cardio), et les pièces gagnées à droite (20 par série faite).
private struct SessionRow: View {
    let session: DemoSession
    /// Le flash au tap — la row s'illumine l'instant avant la story.
    var flashing = false
    /// Le tap : rend le rect ÉCRAN de la row pour le portail.
    var onTap: ((CGRect) -> Void)? = nil

    private let forme = RoundedRectangle(cornerRadius: 22, style: .continuous)

    var body: some View {
        HStack(spacing: 14) {
            dateBadge
            VStack(alignment: .leading, spacing: 3) {
                Text(session.name)
                    .font(.inter(14, .semibold))
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                HStack(spacing: 5) {
                    Text("\(session.series) séries · \(session.reps) reps")
                        .font(.inter(11.5))
                        .foregroundStyle(Color.inkMuted)
                    if session.cardio {
                        Image(WoopSticker.basket.asset)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 13, height: 13)
                    }
                }
            }
            Spacer(minLength: 8)
            HStack(spacing: 6) {
                Text("+\(session.coins)")
                    .font(.inter(14, .semibold))
                    .foregroundStyle(Color.woopGold)
                Image("piece-woop")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 78)
        .background(forme.fill(Color(white: 0.045)))
        // Le liseré qui meurt vers le bas — la lumière vient d'en haut,
        // le bas de la carte reste dans la nuit (réf. Work session).
        .overlay(forme.strokeBorder(
            LinearGradient(stops: [
                .init(color: .white.opacity(0.10), location: 0),
                .init(color: .white.opacity(0.04), location: 0.5),
                .init(color: .white.opacity(0.01), location: 1),
            ], startPoint: .top, endPoint: .bottom),
            lineWidth: 1))
        .overlay {
            // LE FLASH : la row s'illumine avant que son rect ne
            // devienne l'écran.
            if flashing {
                forme.strokeBorder(Color.white.opacity(0.55), lineWidth: 1)
                    .blendMode(.plusLighter)
                forme.fill(Color.white.opacity(0.06))
                    .blendMode(.plusLighter)
                .transition(.opacity)
            }
        }
        .overlay {
            if onTap != nil {
                GeometryReader { g in
                    Color.clear
                        .contentShape(forme)
                        .onTapGesture { onTap?(g.frame(in: .global)) }
                }
            }
        }
    }

    /// Le badge-date : LA matière de la carte Séries, réutilisée — le
    /// verre gonflé (`VerreGonfle`, la photographie d'éclairage calibrée
    /// au pixel) fait la surface ET la tranche, la nappe de braise se
    /// couche dessus, et les CHEVEUX (0,5 pt, brillants en haut, éteints
    /// en bas) signent le bord de verre. On ne réécrit pas une matière
    /// validée, on la réutilise.
    private var dateBadge: some View {
        let tuile = RoundedRectangle(cornerRadius: 15, style: .continuous)
        return VStack(spacing: 1) {
            Text(session.weekdayLabel)
                .font(.inter(9.5, .semibold)).tracking(1.3)
                .foregroundStyle(Color.white.opacity(0.62))
            Text("\(session.dayNumber)")
                .font(.inter(21, .bold)).tracking(-0.3)
                .foregroundStyle(Color.inkPrimary)
        }
        .frame(width: 54, height: 54)
        .background {
            // La nappe chaude sur la surface du verre — la lumière
            // vient du bas-gauche, l'azimut de la maison.
            EllipticalGradient(
                stops: [
                    .init(color: FlammePalette.coeur.opacity(0.11),
                          location: 0.0),
                    .init(color: FlammePalette.braise.opacity(0.045),
                          location: 0.5),
                    .init(color: .clear, location: 1.0),
                ],
                center: UnitPoint(x: 0.25, y: 0.82),
                startRadiusFraction: 0, endRadiusFraction: 0.9)
                .blendMode(.plusLighter)
                .clipShape(tuile)
        }
        .background {
            // LE VERRE GONFLÉ : surface, épaule, blooms — la lumière
            // déborde de la tuile (pad 28), c'est voulu : de la lumière,
            // pas une boîte. La version CLAIRE, tranchée le 18-08 : le
            // verre garde ses brumes laiteuses, pas de cœur sombre
            // (« là c'est trop noir »).
            VerreGonfle(rayonHaut: 15, rayonBas: 15, allege: false)
        }
        .overlay {
            // LES CHEVEUX : le liseré de la garde en verre — 0,5 pt,
            // blanc plein en haut, quasi rien en bas (la recette exacte
            // du tube de la jauge).
            tuile.strokeBorder(LinearGradient(
                stops: [
                    .init(color: Color.white.opacity(1.00), location: 0.0),
                    .init(color: Color.white.opacity(0.62), location: 0.28),
                    .init(color: Color.white.opacity(0.16), location: 0.72),
                    .init(color: Color.white.opacity(0.10), location: 1.0),
                ], startPoint: .top, endPoint: .bottom),
                lineWidth: 0.5)
                .blendMode(.plusLighter)
                .opacity(0.9)
        }
        .overlay {
            // Le cheveu d'or : un court filament sur la tranche est.
            tuile.strokeBorder(
                AngularGradient(stops: [
                    .init(color: FlammePalette.or.opacity(0.55),
                          location: 0.0),
                    .init(color: .clear, location: 0.055),
                    .init(color: .clear, location: 0.945),
                    .init(color: FlammePalette.or.opacity(0.55),
                          location: 1.0),
                ], center: .center, angle: .zero),
                lineWidth: 1)
                .blur(radius: 0.6)
                .blendMode(.plusLighter)
        }
    }
}

// MARK: - Les sessions de démonstration

/// Dérivées du MÊME hash que les stickers de la grille : chaque jour
/// décoré du calendrier est une session de la liste — tout reste
/// cohérent. 20 pièces par série (la règle de l'économie).
struct DemoSession: Identifiable {
    let date: Date
    let cat: WoopSticker
    let series: Int
    let reps: Int
    let weekdayLabel: String
    let dayNumber: Int

    var coins: Int { series * 20 }
    var cardio: Bool { cat == .basket }
    var id: Date { date }

    /// « Session du mardi 2 avril » — la date, rien d'autre (pas d'heure).
    var name: String {
        "Session du \(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))"
    }

    /// La session d'un jour donné — nil si le jour n'est pas entraîné.
    static func at(_ day: Date, calendar: Calendar) -> DemoSession? {
        guard let cat = WoopSticker.demoCategory(for: day,
                                                 calendar: calendar)
        else { return nil }
        let n = calendar.component(.day, from: day)
        let series = 3 + n % 3
        let label = day.formatted(.dateTime.weekday(.abbreviated))
            .replacingOccurrences(of: ".", with: "")
            .prefix(3).uppercased()
        return DemoSession(date: day, cat: cat, series: series,
                           reps: series * (8 + n % 5),
                           weekdayLabel: String(label),
                           dayNumber: n)
    }

    static func recent(calendar: Calendar, days: Int = 90) -> [DemoSession] {
        let today = calendar.startOfDay(for: Date())
        return (0..<days).compactMap { back in
            calendar.date(byAdding: .day, value: -back, to: today)
                .flatMap { at($0, calendar: calendar) }
        }
    }

    /// La partition de démonstration : deux-trois exercices du catalogue,
    /// leurs séries faites — la matière de la story 2 et de l'ardoise.
    var groupes: [SlateGroupe] {
        let n = dayNumber
        let all = ExerciseCatalog.all
        return (0..<(2 + n % 2)).map { i in
            let exo = all[(n * 3 + i * 5) % all.count]
            let rows = (0..<(2 + (n + i) % 3)).map { r in
                SlateLigne(reps: 8 + (n + r) % 6,
                           kilos: Double(16 + ((n + i + r) % 5) * 4),
                           seconds: 45 + (n + r) % 40,
                           done: true)
            }
            return SlateGroupe(id: "\(i)-\(exo.id)", exercise: exo,
                               rows: rows)
        }
    }

    /// Le récit que la story raconte, fabriqué depuis la démo.
    var storySession: StorySession {
        let g = groupes
        let toutes = g.flatMap(\.rows)
        var s = StorySession(
            title: name,
            dateLabel: name.replacingOccurrences(of: "Session",
                                                 with: "Séance"),
            minutes: max(1, toutes.count * 4),
            exos: g.count,
            series: toutes.count,
            kcal: toutes.count * 28,
            sets: toutes.prefix(5).enumerated().map { i, l in
                StorySet(rank: i + 1, reps: l.reps, kilos: l.kilos,
                         coins: 20)
            })
        s.groupes = g
        return s
    }
}

// MARK: - Les stickers d'entraînement

/// La typologie des stickers : la FLAMME marque toute séance (toujours
/// présente sur un jour entraîné), la catégorie vient par-dessus —
/// basket = cardio, abricot = fessiers, chocolat = abdos, bras = le
/// reste de la muscu. Les PNG vivent dans le catalogue (`sticker-*`),
/// liseré blanc sur fond transparent.
enum WoopSticker: String, CaseIterable {
    case flamme, basket, abricot, chocolat, bras

    var asset: String { "sticker-\(rawValue)" }

    /// La catégorie de démonstration : déterministe (même mois, mêmes
    /// stickers), ~2 jours sur 7 entraînés — en attendant les vraies
    /// séances.
    static func demoCategory(for day: Date,
                             calendar: Calendar) -> WoopSticker? {
        let d = calendar.component(.day, from: day)
        let m = calendar.component(.month, from: day)
        let y = calendar.component(.year, from: day)
        let h = (d &* 2654435761 &+ m &* 40503 &+ y &* 69069) >> 4
        guard h % 7 < 2 else { return nil }
        return [WoopSticker.basket, .abricot, .chocolat,
                .bras][(h >> 3) % 4]
    }
}

#Preview { CalLab() }
