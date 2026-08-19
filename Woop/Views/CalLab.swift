import SwiftUI
import AVFoundation
import CoreMotion

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
    var corner: Double
    /// Le DÉBORD du rim : 0 = le bourrelet de réfraction vit au bord
    /// haut (la signature « liquid »), 64 = poussé hors écran.
    var rim: Double
    /// Le voile noir sur la vidéo d'ambiance — le verre ne vit que de
    /// ce qu'il réfracte, la scène se dose.
    var veil: Double

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
    /// LE SCROLL EST LE CURSEUR, deux courses (refonte bac, 18-08) :
    /// repos = calendrier DÉPLIÉ ; course 1 = le morph grand → mini ;
    /// course 2 = la mini-barre s'efface, le titre « Calendrier » prend
    /// la page, le bac règne. L'offset vit dans le repère de
    /// l'ESPACEUR : repos = 0 (la leçon payée des marges).
    @State private var scrollPos = ScrollPosition()
    @State private var scrollY: CGFloat?
    /// La pochette au centre — l'haptique du feuilletage.
    @State private var centre = 0
    /// La vitesse du scroll (pt/évènement, bornée) : elle SECOUE les
    /// minis dans les cards et nourrit la poudre — morte à l'arrêt.
    @State private var remous: CGFloat = 0
    /// La SALVE d'atterrissage : l'instant où le scroll se pose sur un
    /// mois — gerbe de poudre pleine puissance (~0,8 s) et rebond
    /// marqué des minis. Remise à nil par sa propre tâche (l'horloge de
    /// la poudre doit pouvoir se remettre en PAUSE).
    @State private var salve: Date?
    /// La génération du remous : chaque évènement de sonde la bump et
    /// arme une remise à zéro à 260 ms — qui n'agit que si RIEN ne l'a
    /// supplantée. Sans elle, un tressaillement d'insets au lancement
    /// laisse `remous` coincé non-nul (aucun évènement de phase ne
    /// suit) et l'horloge de la poudre tourne au repos — vu au banc.
    @State private var remousGen = 0
    /// L'étirement au-delà du dernier mois (le rebond du bas) : il
    /// OUVRE l'éventail de la card de front — l'overscroll devient un
    /// jouet, plus un vide.
    @State private var etire: CGFloat = 0
    /// Le gyroscope (bande morte : poignet immobile = zéro rendu).
    @ObservedObject private var motion = BacMotion.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // La story : le rect tapé devient l'écran (le portail de la home).
    @State private var story: CalStoryLaunch?
    /// La case/row qui s'illumine au tap, l'instant avant le portail.
    @State private var flashDay: Date?
    @State private var flashRow: Date?
    /// L'ardoise est en main : le drag de la carte se désarme (la loi
    /// payée sur la fiche exo — un doigt qui échappe fait respirer la
    /// page).
    @State private var slateBusy = false


    // La console du verre — RÉSERVÉE au banc `-calTune` (double-tap
    // pour l'afficher/cacher là-bas), valeurs persistées entre relances.
    private static let tuneEnabled =
        CommandLine.arguments.contains("-calTune")
    @State private var showTune = CommandLine.arguments.contains("-calTune")
    @AppStorage("calClear") private var tClear = false
    @AppStorage("calTintW") private var tTintW = 0.0
    @AppStorage("calTintA") private var tTintA = 0.5
    @AppStorage("calInter") private var tInter = false
    @AppStorage("calEdge") private var tEdge = 0.06
    @AppStorage("calCorner") private var tCorner = 40.0
    @AppStorage("calRim") private var tRim = 0.0
    @AppStorage("calVeil") private var tVeil = 0.52

    private var tuning: GlassTuning {
        GlassTuning(clearGlass: tClear, tintWhite: tTintW,
                    tintAlpha: tTintA, interactive: tInter,
                    edgeAlpha: tEdge, corner: tCorner,
                    rim: tRim, veil: tVeil)
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
            let course1 = max(1, expandedH - geo.collapsedH)
            let course2: CGFloat = 96
            let rel = scrollY ?? 0
            let p = rubber(max(0, 1 - rel / course1) + cardDrag / course1)
            let p2 = min(1, max(0, (rel - course1) / course2))

            ZStack(alignment: .top) {
                Color.black
                // LA VIDÉO D'AMBIANCE : le palindrome pré-encodé (aller +
                // retour dans le fichier — la couture n'existe pas), en
                // boucle muette sous un voile réglable. Le verre de la
                // carte y gagne une scène.
                FondCalendrier()
                    .allowsHitTesting(false)
                Color.black.opacity(tuning.veil)
                    .allowsHitTesting(false)
                bac(geo: geo, inset: expandedH + 14,
                    course1: course1, course2: course2,
                    H: host.size.height,
                    // LE WIPE : le blur culmine à mi-course de la
                    // disparition et meurt aux deux poses.
                    wipe: CGFloat(sin(.pi * Double(p2))))
                // ÉTAT BAC : le grand titre prend la relève de la carte —
                // le chevron de sortie ne meurt jamais.
                enTeteBac(safeTop: geo.safeTop, p2: p2)
                card(geo: geo, slots: slots, rowCount: rowCount,
                     p: p, course: course1)
                    .opacity(1 - Double(min(1, p2 * 1.3)))
                    // La carte S'ENFUIT dans le flou du wipe.
                    .blur(radius: CGFloat(sin(.pi * Double(p2))) * 10)
                    .offset(y: -22 * p2)
                    .allowsHitTesting(p2 < 0.4)
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
            // La console ne s'ouvre QUE sur le banc `-calTune` : le
            // double-tap global VOLAIT le deuxième tap des séquences
            // rapides (le dépliage de l'ardoise mourait après une
            // bascule) et faisait surgir le panneau — dont les molettes
            // AppStorage se dérèglent durablement au moindre drag.
            .gesture(TapGesture(count: 2).onEnded {
                withAnimation(.easeOut(duration: 0.2)) {
                    showTune.toggle()
                }
            }, isEnabled: Self.tuneEnabled)
            // LE DEBUG DU VERRE revient partout, par un geste qui ne
            // peut voler AUCUN tap (la leçon du double-tap payée) :
            // l'appui long ouvre la console.
            .onLongPressGesture(minimumDuration: 0.6) {
                withAnimation(.easeOut(duration: 0.2)) {
                    showTune.toggle()
                }
            }
            .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.8),
                             trigger: centre)
            .task { await autoParcours(course1: course1,
                                       course2: course2) }
            // Le gyroscope vit avec la page — et MEURT avec elle (le
            // silence du poignet, payé au Manège : CoreMotion réveille
            // le fil 30×/s pour une scène que personne ne regarde).
            .onAppear { BacMotion.shared.start() }
            .onDisappear { BacMotion.shared.stop() }
            // La story couvre tout — la grammaire exacte de la home.
            .fullScreenCover(item: $story) { launch in
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

    /// Le tap sur une card mensuelle : le flash, et c'est tout pour
    /// l'instant. TODO jalon 2 : la page du mois s'ouvre d'ici (le rect
    /// tapé = le portail) — ne PAS brancher la story par réflexe.
    private func monthTapped(_ m: DemoMonth, rect: CGRect) {
        flashRow = m.start
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            withAnimation(.easeOut(duration: 0.3)) { flashRow = nil }
        }
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
                      p: CGFloat, course: CGFloat) -> some View {
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
            .gesture(cardGesture(course: course), isEnabled: !slateBusy)
    }

    private func monthStep(_ dir: Int) {
        pushEdge = dir > 0 ? .trailing : .leading
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            monthAnchor = calendar.date(byAdding: .month, value: dir,
                                        to: monthAnchor) ?? monthAnchor
        }
    }

    /// Le drag direct sur la carte nourrit le même curseur que le
    /// scroll : la fin de geste se règle en `scrollTo` (même repère,
    /// l'espaceur), l'aimant tranche.
    private func cardGesture(course: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { v in
                // Un repli qui part d'un autre mois se recale sur le
                // mois courant : la rangée mini montre TOUJOURS la
                // semaine d'aujourd'hui.
                if cardDrag == 0, (scrollY ?? 0) > course * 0.5,
                   !anchorIsCurrent {
                    monthAnchor = Date()
                }
                cardDrag = v.translation.height
            }
            .onEnded { v in
                let base = max(0, 1 - (scrollY ?? 0) / course)
                let projected = base
                    + v.predictedEndTranslation.height / course
                let deploy = projected > 0.5
                if !deploy, !anchorIsCurrent { monthAnchor = Date() }
                cardDrag = 0
                withAnimation(.spring(response: 0.46,
                                      dampingFraction: 0.85)) {
                    scrollPos.scrollTo(y: deploy ? 0 : course)
                }
            }
    }

    // MARK: Le bac à pochettes

    /// LA PILE (réf. Analytics, verdict 18-08) : les pochettes se
    /// CHEVAUCHENT — celles qui sont passées s'empilent en BANDEAUX
    /// au-dessus de la ligne de front (tirées vers elle, inclinées en
    /// avant, chacune ne montrant que sa date), la pochette de front
    /// est PLEIN FACE, entière. Le blur ne vit QUE dans le wipe de
    /// transition (fonction de p2 en vol : il culmine à mi-course et
    /// meurt à la pose — l'aimant interdit le repos entre deux états).
    private func bac(geo: CalGeo, inset: CGFloat,
                     course1: CGFloat, course2: CGFloat,
                     H: CGFloat, wipe: CGFloat) -> some View {
        let mois = DemoMonth.recent(calendar: calendar)
        // 360 : la taille AÉRÉE (verdict 19-08 : le 272 « ratio réf »
        // était trop court — l'air autour de l'éventail fait la
        // beauté, et les minis coupées en bas sont un choix, pas un
        // défaut).
        let cardH: CGFloat = 360
        let pas: CGFloat = 372 // la pochette + son souffle
        let bandeau: CGFloat = 64 // ce qu'une pochette passée laisse voir
        let focus = H * 0.50
        return ScrollView {
            LazyVStack(spacing: 12) {
                // L'ESPACEUR, pas une marge : repos = offset 0, le
                // repère que scrollTo et l'aimant partagent (leçon
                // payée). Le −16 : ~30 pt d'air sous le calendrier, et
                // la card 272 tient ENTIÈRE au-dessus du dock, éventail
                // compris — mesuré au pixel le 19-08.
                Color.clear.frame(height: inset - 16)
                ForEach(Array(mois.enumerated()),
                        id: \.element.id) { i, m in
                    MonthVinyle(month: m, calendar: calendar,
                                remous: remous, salve: salve,
                                devant: i == centre,
                                ecart: i == centre
                                    ? min(1, etire / 120) : 0,
                                pench: motion.pench,
                                flashing: flashRow == m.start,
                                onTap: { r in monthTapped(m, rect: r) })
                        .frame(height: cardH)
                        .visualEffect { content, proxy in
                            let f = proxy.frame(
                                in: .scrollView(axis: .vertical))
                            // d en unités de pochette : 0 = au front,
                            // négatif = déjà passée (elle s'empile).
                            let d = (f.midY - focus) / pas
                            // Les deux régimes ne diffèrent que par
                            // leurs PARAMÈTRES — une seule chaîne de
                            // retour, sinon le type-checker s'enlise.
                            let tilt: Double
                            let tire: CGFloat
                            let glisse: CGFloat
                            let taille: CGFloat
                            let flou: CGFloat
                            let alpha: Double
                            let nuit: Double
                            if d >= 0 {
                                // En approche : légère inclinaison qui
                                // meurt au front — la pochette se
                                // REDRESSE en arrivant.
                                let c: CGFloat = min(d, 1.4)
                                tilt = Double(c) * 9
                                tire = 0
                                glisse = 0
                                taille = 1 - min(c, 1) * 0.03
                                flou = wipe * 14
                                alpha = 1
                                nuit = 0
                            } else {
                                // Passée : TIRÉE vers l'étagère du haut,
                                // il ne reste que son bandeau — la pile
                                // de la référence. L'étagère a un
                                // PLAFOND : au-delà d'un bandeau la pile
                                // se compresse (pas de 10 pt) et
                                // s'éteint vite — sinon elle grimpe
                                // dans le titre. Et tout est CONTINU en
                                // n = 0 : pas de claquement au
                                // franchissement du front.
                                let n: CGFloat = -d
                                let prof: CGFloat = min(n, 4.0)
                                let surplus: CGFloat = max(0.0, n - 1.3)
                                let etage: CGFloat = min(n, 1.3)
                                let shelf: CGFloat =
                                    bandeau * etage + surplus * 10.0
                                let entree: Double = Double(min(n * 3.0, 1.0))
                                // LE SWING DE CLASSEMENT : sin(π·n) —
                                // nul au front, nul à l'étagère, il ne
                                // vit qu'EN VOL (les poses ne bougent
                                // pas, la continuité reste la loi) : la
                                // card bascule fort, glisse de côté,
                                // plonge un peu, une bouffée de flou.
                                let vol: Double =
                                    sin(Double.pi * Double(min(n, 1.0)))
                                // LE RANGEMENT EN PERSPECTIVE (verdict
                                // « trop fake ») : la card se COUCHE
                                // (−26° posée, ~−50° en vol), RECULE
                                // (échelle) et S'ASSOMBRIT — c'est la
                                // profondeur qui range, plus la
                                // transparence qui efface.
                                tilt = -26.0 * entree
                                    - Double(prof) * 2.0 - 24.0 * vol
                                tire = n * pas - shelf
                                glisse = CGFloat(vol) * -16.0
                                taille = 1.0 - prof * 0.05
                                    - CGFloat(vol) * 0.04
                                flou = wipe * 14.0 + prof * 0.4
                                    + CGFloat(vol) * 3.0
                                nuit = -0.15 * entree
                                    - 0.04 * Double(prof)
                                let fondu: CGFloat = max(0.0, n - 0.5)
                                let vie: CGFloat =
                                    1.0 - fondu * 0.06 - surplus * 0.5
                                alpha = Double(max(0.0, vie))
                            }
                            return content
                                .offset(x: glisse, y: tire)
                                .rotation3DEffect(
                                    .degrees(tilt),
                                    axis: (x: 1, y: 0, z: 0),
                                    perspective: 0.55)
                                .scaleEffect(taille)
                                .brightness(nuit)
                                .blur(radius: flou)
                                .opacity(alpha)
                        }
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
        .contentMargins(.bottom, 140, for: .scrollContent)
        // LE FONDU DU HAUT : la pile ne perce jamais la barre d'état.
        .mask {
            LinearGradient(stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .black, location: 0.055),
                .init(color: .black, location: 1.0),
            ], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        }
        .scrollPosition($scrollPos)
        // UNE sonde — l'offset brut EST le curseur ; elle nourrit aussi
        // l'haptique du feuilletage.
        // UNE sonde, un champ COMPOSÉ (le champ vivant emporte les
        // stables — jamais une deuxième sonde, la loi payée).
        .onScrollGeometryChange(for: SondeBac.self, of: {
            SondeBac(y: $0.contentOffset.y,
                     fin: $0.contentSize.height - $0.containerSize.height)
        }) { vieux, s in
            let y = s.y
            scrollY = y
            // Le rebond du bas ouvre l'éventail (jouet d'overscroll).
            etire = max(0, y - max(0, s.fin))
            // La vitesse vient GRATUITEMENT de la sonde (l'ancienne
            // valeur) — une seule sonde (la loi). GAIN ×3 : les deltas
            // font 3-12 pt par évènement, nus ils donnaient ~1° de
            // secousse — physiquement invisible (payé au banc).
            remous = max(-40, min(40, (y - vieux.y) * 3))
            remousGen += 1
            let gen = remousGen
            Task {
                try? await Task.sleep(for: .milliseconds(260))
                guard remousGen == gen, remous != 0 else { return }
                withAnimation(.spring(response: 0.5,
                                      dampingFraction: 0.5)) {
                    remous = 0
                }
            }
            let idx = max(0, Int(((y - course1 - course2) / pas)
                .rounded()))
            if idx != centre { centre = idx }
        }
        .scrollTargetBehavior(BacAimant(course1: course1,
                                        course2: course2, pas: pas,
                                        depart: { scrollY }))
        // LE RATTRAPAGE : un doigt qui arrête l'élan en touchant une
        // mini vole le toucher au scroll — la page se fige ENTRE deux
        // poses (la card en plein vol, floue, vue au banc). À l'arrêt,
        // si le bac est hors-pose, on re-snappe à la plus proche.
        .onScrollPhaseChange { _, phase in
            guard phase == .idle else { return }
            // L'ATTERRISSAGE (dans le bac seulement) : un coup de
            // secousse instantané que le ressort rattrape — le tas
            // encaisse la pose — et la salve de poudre.
            if let y = scrollY, y > course1 + course2 - 20 {
                if !reduceMotion {
                    let coup: CGFloat = remous >= 0 ? 26 : -26
                    remous = coup
                }
                let s = Date()
                salve = s
                Task {
                    try? await Task.sleep(for: .seconds(1))
                    if salve == s { salve = nil }
                }
                // L'HAPTIQUE COMPOSÉE : le « toc » de la card qui se
                // pose, puis deux micro-ticks quand les minis
                // retombent — la main et l'œil racontent la même
                // histoire.
                UIImpactFeedbackGenerator(style: .medium)
                    .impactOccurred(intensity: 0.9)
                Task {
                    try? await Task.sleep(for: .milliseconds(110))
                    UIImpactFeedbackGenerator(style: .light)
                        .impactOccurred(intensity: 0.55)
                    try? await Task.sleep(for: .milliseconds(100))
                    UIImpactFeedbackGenerator(style: .light)
                        .impactOccurred(intensity: 0.4)
                }
            }
            // Le remous meurt à l'arrêt : les minis se reposent EN
            // CASCADE (chacune son retard, son sens — le ressort
            // rebondit), la poudre s'éteint (et son horloge se met en
            // PAUSE — jamais de 30 Hz pour du statique).
            withAnimation(.spring(response: 0.55, dampingFraction: 0.38)) {
                remous = 0
            }
            guard let y = scrollY,
                  y > course1 + course2 + 2 else { return }
            let base = y - course1 - course2
            let cible = course1 + course2 + (base / pas).rounded() * pas
            guard abs(cible - y) > 2 else { return }
            withAnimation(.spring(response: 0.42,
                                  dampingFraction: 0.86)) {
                scrollPos.scrollTo(y: cible)
            }
        }
    }

    /// L'en-tête de l'état BAC : le titre « Calendrier » et le chevron
    /// de sortie — il ne meurt jamais. Le titre S'AFFÛTE en arrivant :
    /// flou pendant le wipe, net à la pose.
    private func enTeteBac(safeTop: CGFloat, p2: CGFloat) -> some View {
        HStack(spacing: 14) {
            ChipVerre(symbole: "chevron.left", label: "Retour",
                      action: onBack)
            Text("Calendrier")
                .font(.inter(30, .bold)).tracking(-0.4)
                .foregroundStyle(WoopGradient.titleFade)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, safeTop + 6)
        .opacity(Double(p2))
        .blur(radius: (1 - p2) * 6)
        .offset(y: (1 - p2) * 12)
        .allowsHitTesting(p2 > 0.6)
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
            tuneRow("RAYON", $tCorner, 12...64, fmt: "%.0f")
            tuneRow("RIM (débord)", $tRim, 0...64, fmt: "%.0f")
            tuneRow("VOILE VIDÉO", $tVeil, 0.2...0.9)
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

    private func autoParcours(course1: CGFloat,
                              course2: CGFloat) async {
        guard autoLoop else { return }
        // Les arrêts du bac se posent sur de VRAIES poses de l'aimant
        // (multiples du pas de pochette) : entre deux poses la carte de
        // front est translucide et penchée — c'est un état de VOL,
        // jamais un repos.
        let arrets: [CGFloat] = [0, course1,
                                 course1 + course2 + 372,
                                 course1 + course2 + 744,
                                 course1, 0]
        var i = 0
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            i = (i + 1) % arrets.count
            withAnimation(.spring(response: 0.6, dampingFraction: 0.9)) {
                scrollPos.scrollTo(y: arrets[i])
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


// MARK: - Le fond vidéo

/// Le palindrome d'ambiance : AVPlayerLooper sur le fichier aller +
/// retour de `Woop/Media` — ressource NUE du paquet (jamais le
/// catalogue), muette, plein cadre.
///
/// LE PLAYER NAÎT DANS LE REPRESENTABLE, et c'est une LOI : une couche
/// plateforme montée EN RETARD (un `if let player` rempli par un
/// `onAppear`) s'insère dans une transaction ultérieure et atterrit
/// parfois AU-DESSUS des frères SwiftUI — la page entière disparaissait
/// derrière la vidéo, une fois sur deux. Présente au premier commit,
/// la couche garde sa place pour toujours.
private struct FondCalendrier: UIViewRepresentable {
    final class Couche: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var player: AVQueuePlayer?
        var looper: AVPlayerLooper?
    }

    func makeUIView(context: Context) -> Couche {
        let v = Couche()
        let l = v.layer as! AVPlayerLayer
        l.videoGravity = .resizeAspectFill
        if let url = Bundle.main.url(
            forResource: "background-calendar-loop",
            withExtension: "mp4") {
            let p = AVQueuePlayer()
            p.isMuted = true
            v.looper = AVPlayerLooper(player: p,
                                      templateItem: AVPlayerItem(url: url))
            l.player = p
            p.play()
            v.player = p
        }
        return v
    }

    func updateUIView(_ v: Couche, context: Context) {}
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
            // ET LE DÉBORD DU BORD HAUT SE DOSE : le rim spéculaire du
            // verre système ne s'éteint par aucune API — mais ce
            // bourrelet EST la signature « liquid » (verdict 18-08 : le
            // pousser entièrement hors écran tue le verre). La molette
            // RIM règle le débord : 0 = bourrelet au bord, 64 = l'ancien
            // hors-écran intégral (coins compris), le clip coupe net.
            Color.clear
                .frame(height: full + CGFloat(tuning.rim))
                .glassEffect(tuning.verre, in: shape)
                .offset(y: -CGFloat(tuning.rim))
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

// MARK: - L'aimant du bac

/// Trois bandes : le morph grand→mini (0 / course1), l'effacement
/// mini→titre (course1 / course1+course2), puis le bac — la pochette
/// s'aligne à son pas. Jamais un repos à mi-course. Et dans le bac,
/// UNE PAGE PAR GESTE (verdict 19-08) : l'élan ne traverse jamais deux
/// mois — le bloc s'arrête à chaque mois, on peut jouer avec les minis
/// ou taper sans courir après le scroll. `depart` lit l'offset au
/// moment du geste (la sonde de la page) — le contexte de l'aimant ne
/// connaît que la cible, pas l'origine.
private struct BacAimant: ScrollTargetBehavior {
    var course1: CGFloat
    var course2: CGFloat
    var pas: CGFloat
    var depart: () -> CGFloat?

    func updateTarget(_ target: inout ScrollTarget,
                      context: TargetContext) {
        let rel = target.rect.origin.y
        if rel <= 0 { return }
        if rel < course1 {
            target.rect.origin.y = rel < course1 / 2 ? 0 : course1
        } else if rel < course1 + course2 {
            target.rect.origin.y = rel < course1 + course2 / 2
                ? course1 : course1 + course2
        } else {
            let base = rel - course1 - course2
            var page = (base / pas).rounded()
            let y = depart() ?? rel
            if y >= course1 + course2 - 1 {
                // Le geste part du bac : ±1 page, pas plus.
                let pageDepart =
                    ((y - course1 - course2) / pas).rounded()
                page = pageDepart
                    + max(-1.0, min(1.0, page - pageDepart))
            } else {
                // On ENTRE dans le bac : toujours sur la première pose.
                page = 0
            }
            target.rect.origin.y = course1 + course2
                + max(0.0, page) * pas
        }
    }
}

// MARK: - La pochette vinyle

/// UNE SESSION = UNE POCHETTE. Noir vinyle plein écran, ZÉRO bordure
/// (la hiérarchie par la lumière, pas par un trait) : la date
/// typographiée « 18. Août » en haut-gauche, séries · reps dessous, le
/// STICKER en artwork au bas, les pièces en face. Le grain fait la
/// matière, un sheen discret fait le sillon. Tap = la story.
private struct SessionVinyle: View {
    let session: DemoSession
    var flashing = false
    var onTap: ((CGRect) -> Void)? = nil

    private let forme = RoundedRectangle(cornerRadius: 26,
                                         style: .continuous)

    var body: some View {
        ZStack(alignment: .topLeading) {
            // JAMAIS noir pur sur le fond noir : la pochette est une
            // SURFACE élevée (la grammaire Apple du mode sombre) — un
            // gris d'ardoise en dégradé, la lumière fait la hiérarchie.
            forme.fill(LinearGradient(
                colors: [Color(white: 0.11), Color(white: 0.055)],
                startPoint: .top, endPoint: .bottom))
            // Le grain : sans lui, l'aplat se lit « rendu logiciel ».
            GrainTexture.tuile
                .resizable(resizingMode: .tile)
                .opacity(0.05)
                .blendMode(.overlay)
                .clipShape(forme)
            // Le sheen du sillon — une lueur d'angle, jamais un trait.
            forme.fill(EllipticalGradient(
                stops: [
                    .init(color: .white.opacity(0.06), location: 0.0),
                    .init(color: .white.opacity(0.015), location: 0.5),
                    .init(color: .clear, location: 1.0),
                ],
                center: UnitPoint(x: 0.18, y: 0.06),
                startRadiusFraction: 0, endRadiusFraction: 1.1))
                .blendMode(.plusLighter)
            VStack(alignment: .leading, spacing: 4) {
                Text(session.dateVinyle)
                    .font(.inter(17, .semibold)).tracking(0.2)
                    .foregroundStyle(Color.inkPrimary)
                Text("\(session.series) séries · \(session.reps) reps")
                    .font(.inter(12))
                    .foregroundStyle(Color.inkMuted)
                Spacer(minLength: 0)
                HStack(alignment: .bottom) {
                    Image(session.cat.asset)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 116, height: 116)
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
            }
            .padding(24)
        }
        .overlay {
            if flashing {
                forme.strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
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

// MARK: - La sonde composée du bac

/// Le champ vivant (l'offset) emporte les stables (la fin de course) —
/// UNE sonde, jamais deux (la loi de la sonde constante).
private struct SondeBac: Equatable {
    var y: CGFloat
    var fin: CGFloat
}

// MARK: - Le poignet du bac

/// Le gyroscope de l'éventail — l'école LuneMotion (neutre capturé à la
/// prise en main, filtre doux), plus une BANDE MORTE : poignet immobile
/// = zéro publication = zéro rendu (jamais d'horloge pour du statique,
/// même déguisée en capteur). Au simulateur, aucun échantillon : le
/// banc reste inerte. Et LE SILENCE DU POIGNET : stop() au démontage —
/// payé au Manège, où CoreMotion réveillait le fil pour une scène morte.
final class BacMotion: ObservableObject {
    static let shared = BacMotion()
    private let mgr = CMMotionManager()
    private var pitchRef: Double?
    private var rollRef: Double?
    private var lisse = CGSize.zero
    @Published private(set) var pench = CGSize.zero

    func start() {
        guard mgr.isDeviceMotionAvailable, !mgr.isDeviceMotionActive
        else { return }
        pitchRef = nil
        rollRef = nil
        mgr.deviceMotionUpdateInterval = 1.0 / 30.0
        mgr.startDeviceMotionUpdates(using: .xArbitraryZVertical,
                                     to: .main) { [weak self] m, _ in
            guard let self, let m else { return }
            if pitchRef == nil { pitchRef = m.attitude.pitch }
            if rollRef == nil { rollRef = m.attitude.roll }
            let cx = max(-1.0, min(1.0,
                (m.attitude.roll - (rollRef ?? 0)) * 1.6))
            let cy = max(-1.0, min(1.0,
                (m.attitude.pitch - (pitchRef ?? 0)) * 1.6))
            lisse.width += (CGFloat(cx) - lisse.width) * 0.18
            lisse.height += (CGFloat(cy) - lisse.height) * 0.18
            // LA BANDE MORTE.
            if abs(lisse.width - pench.width) > 0.02
                || abs(lisse.height - pench.height) > 0.02 {
                pench = lisse
            }
        }
    }

    func stop() {
        guard mgr.isDeviceMotionActive else { return }
        mgr.stopDeviceMotionUpdates()
        pench = .zero
        lisse = .zero
    }
}

// MARK: - Un mois du bac

/// UN MOIS = UNE POCHETTE. Regroupe les DemoSession du hash démo par
/// mois calendaire, mois courant d'abord — DemoSession.recent sort du
/// plus récent au plus ancien, l'ordre d'apparition des mois EST le
/// bon ordre (et l'éventail SUPPOSE cet ordre : si .recent changeait
/// de tri, la plus récente ne serait plus devant, EN SILENCE). `id`
/// stable (1er du mois) : ForEach ne rejoue une row que si SES données
/// changent.
private struct DemoMonth: Identifiable {
    /// Le 1er jour du mois — l'identité de la card (et du flash au tap).
    let start: Date
    /// Les séances du mois, récentes → anciennes (l'ordre de .recent).
    let sessions: [DemoSession]

    var id: Date { start }
    var count: Int { sessions.count }

    /// « Août » — « Décembre 2025 » si l'année n'est pas la courante.
    func titre(calendar: Calendar) -> String {
        let mois = start.formatted(.dateTime.month(.wide)).capitalized
        let annee = calendar.component(.year, from: start)
        guard annee != calendar.component(.year, from: Date())
        else { return mois }
        return "\(mois) \(annee)"
    }

    /// « 9 séances » — le sous-titre porte le compte exact (pas de +N :
    /// l'éventail est une évocation, l'inventaire = la page du mois).
    var sousTitre: String {
        count == 1 ? "1 séance" : "\(count) séances"
    }

    /// L'éventail : les 5 dernières séances du mois, la plus ANCIENNE
    /// à gauche (au fond), la plus RÉCENTE à droite (devant).
    var eventail: [DemoSession] { Array(sessions.prefix(5)).reversed() }

    /// Le regroupement — mêmes données, même hash, juste plié par mois.
    static func recent(calendar: Calendar,
                       days: Int = 90) -> [DemoMonth] {
        let all = DemoSession.recent(calendar: calendar, days: days)
        var ordre: [Date] = []
        var parMois: [Date: [DemoSession]] = [:]
        for s in all {
            guard let m = calendar.dateInterval(of: .month,
                                                for: s.date)?.start
            else { continue }
            if parMois[m] == nil { ordre.append(m) }
            parMois[m, default: []].append(s)
        }
        return ordre.map { DemoMonth(start: $0, sessions: parMois[$0]!) }
    }
}

// MARK: - Les slots de l'éventail

/// La géométrie d'un slot — des CHIFFRES gravés, pas de calcul au
/// runtime. zIndex = l'index (la droite DEVANT). L'éventail vit en
/// transforms de RENDU (rotationEffect + offset) dans un conteneur de
/// layout FIXE 132×132 — JAMAIS un HStack : une boîte tournée de 132 pt
/// à 18° fait 166 pt, un layout horizontal gonflerait et CENTRERAIT la
/// card hôte (le piège payé des encarts symétriques invisibles).
private struct FanSlot {
    let angle: Double   // degrés
    let dx: CGFloat     // depuis le centre de base de l'éventail
    let dy: CGFloat
    static let cinq: [FanSlot] = [
        FanSlot(angle: -18, dx: -92, dy: -26),
        FanSlot(angle: -10, dx: -46, dy: -18),
        FanSlot(angle: -2, dx: 0, dy: -10),
        FanSlot(angle: 6, dx: 46, dy: -2),
        FanSlot(angle: 14, dx: 92, dy: 6),
    ]
    /// n < 5 : les n DERNIERS slots (la plus récente garde +14°,
    /// devant), recentrés en x ; n == 1 : une mini seule, +8° au centre.
    static func pour(_ n: Int) -> [FanSlot] {
        guard n < 5 else { return cinq }
        guard n > 1 else { return [FanSlot(angle: 8, dx: 0, dy: -10)] }
        let derniers = Array(cinq.suffix(n))
        let moyenne = derniers.map(\.dx).reduce(0, +) / CGFloat(n)
        return derniers.map {
            FanSlot(angle: $0.angle,
                    dx: ($0.dx - moyenne).rounded(), dy: $0.dy)
        }
    }
}

// MARK: - La pochette mensuelle

/// UNE POCHETTE = UN MOIS (la référence Apple Music) : le nom du mois
/// et le compte centrés dans le bandeau 64 pt — EXACTEMENT ce que la
/// pile laisse voir d'un mois passé —, et l'ÉVENTAIL des 5 dernières
/// séances qui se chevauchent, tranchées net par le bord bas. ZÉRO
/// bordure : la hiérarchie par la lumière (le puits d'ombre creuse la
/// zone de l'éventail, les minis plus claires s'en détachent).
private struct MonthVinyle: View {
    let month: DemoMonth
    let calendar: Calendar
    /// La vitesse du scroll : elle secoue l'éventail et fait pleuvoir
    /// la poudre.
    var remous: CGFloat = 0
    /// L'instant d'atterrissage : la gerbe de poudre pleine puissance.
    var salve: Date? = nil
    /// La card au front du bac : elle seule salue à l'arrivée, ouvre
    /// son éventail à l'overscroll, et son tap ouvre le mois — les
    /// rangées font le COUCOU à la place.
    var devant = false
    /// L'ouverture de l'éventail au rebond du bas (0-1).
    var ecart: CGFloat = 0
    /// La pente du poignet (gyroscope, ±1) — l'éventail pivote à peine.
    var pench: CGSize = .zero
    var flashing = false
    var onTap: ((CGRect) -> Void)? = nil

    /// Le SALUT d'arrivée : la card dépasse sa pose d'un degré et demi
    /// puis se redresse — l'objet a du poids.
    @State private var salut: Double = 0
    /// Le COUCOU d'un mois rangé : tapé dans la pile, il s'avance et se
    /// rallume un instant avant de se ranger.
    @State private var coucou: CGFloat = 0

    private let forme = RoundedRectangle(cornerRadius: 26,
                                         style: .continuous)

    /// Le fond du puits qui respire avec l'agitation du tas.
    private var puitsFond: Double {
        0.32 + Double(min(abs(remous), 40)) * 0.002
    }

    var body: some View {
        ZStack(alignment: .top) {
            // L'ardoise élevée validée sur les pochettes-sessions.
            forme.fill(LinearGradient(
                colors: [Color(white: 0.11), Color(white: 0.055)],
                startPoint: .top, endPoint: .bottom))
            GrainTexture.tuile
                .resizable(resizingMode: .tile)
                .opacity(0.05)
                .blendMode(.overlay)
                .clipShape(forme)
            forme.fill(EllipticalGradient(
                stops: [
                    .init(color: .white.opacity(0.06), location: 0.0),
                    .init(color: .white.opacity(0.015), location: 0.5),
                    .init(color: .clear, location: 1.0),
                ],
                center: UnitPoint(x: 0.18, y: 0.06),
                startRadiusFraction: 0, endRadiusFraction: 1.1))
                .blendMode(.plusLighter)
            // LE PUITS : le halo noir qui creuse le bas — blend normal,
            // jamais un trait. Il RESPIRE avec le remous : l'ombre se
            // creuse quand le tas s'agite (la parallaxe de scène).
            forme.fill(EllipticalGradient(
                stops: [
                    .init(color: .black.opacity(puitsFond),
                          location: 0.0),
                    .init(color: .black.opacity(0.10), location: 0.55),
                    .init(color: .clear, location: 1.0),
                ],
                center: UnitPoint(x: 0.5, y: 1.08),
                startRadiusFraction: 0.05, endRadiusFraction: 0.85))
            // LE TAP DE LA CARD vit SOUS l'éventail : l'éventail est
            // une zone de JEU (les minis se saisissent au doigt), le
            // reste de la card ouvre le mois. En overlay au-dessus, il
            // volerait tous les touchers des minis (la couche du haut
            // mange tout — le cousin du double-tap voleur).
            if onTap != nil {
                GeometryReader { g in
                    Color.clear
                        .contentShape(forme)
                        .onTapGesture {
                            // Au front : le mois s'ouvre. Rangée dans
                            // la pile : le COUCOU — elle s'avance et
                            // se rallume un instant.
                            if devant {
                                onTap?(g.frame(in: .global))
                            } else {
                                faireCoucou()
                            }
                        }
                }
            }
            // Le bloc titre : 18 + 27 + 3 + 16 = 64 pt = le bandeau de
            // la pile, EXACT — le grossir décapite le sous-titre à la
            // coupe (remonter `bandeau` avec, le couple est la loi).
            VStack(spacing: 3) {
                Text(month.titre(calendar: calendar))
                    .font(.inter(22, .bold)).tracking(-0.3)
                    .foregroundStyle(Color.inkPrimary)
                Text(month.sousTitre)
                    .font(.inter(12.5, .medium)).tracking(0.2)
                    .foregroundStyle(Color.inkMuted)
                    // Le chiffre ROULE quand le compte change (fin de
                    // séance, vraies données) — le micro-détail 5.
                    .contentTransition(.numericText(
                        value: Double(month.count)))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 18)
            eventail
            // LA POUDRE : les micro-paillettes du booster (la recette
            // de PoudreBooster), déversées depuis l'éventail pendant
            // le scroll — et la GERBE d'atterrissage à la pose. Mortes
            // (et l'horloge en pause) au repos. Le VENT : les grains
            // traînent derrière le geste.
            PoudreBac(force: min(1, abs(remous) / 8), salve: salve,
                      vent: remous)
        }
        // Les plusLighter (sheen + micro-sheens des minis) vivent dans
        // LEUR groupe ; le clip racine tranche le débord bas des minis.
        .compositingGroup()
        .clipShape(forme)
        .overlay {
            if flashing {
                forme.strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
                    .blendMode(.plusLighter)
                    .transition(.opacity)
            }
        }
        // Le COUCOU rallume la card le temps de son avancée.
        .overlay(forme.fill(
            Color.white.opacity(Double(coucou) * 0.006))
            .allowsHitTesting(false))
        // LE SALUT d'arrivée (front seul) + l'avancée du coucou.
        .rotationEffect(.degrees(salut))
        .offset(y: coucou)
        .onChange(of: salve) { _, s in
            guard devant, s != nil else { return }
            withAnimation(.spring(response: 0.28,
                                  dampingFraction: 0.55)) {
                salut = 1.5
            }
            Task {
                try? await Task.sleep(for: .milliseconds(140))
                withAnimation(.spring(response: 0.4,
                                      dampingFraction: 0.6)) {
                    salut = 0
                }
            }
        }
    }

    /// Le coucou : 10 pt d'avancée + un souffle de lumière, puis la
    /// card se range — l'invitation discrète (le tap-portail du mois
    /// viendra au jalon 2).
    private func faireCoucou() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.6)) {
            coucou = 10
        }
        Task {
            try? await Task.sleep(for: .milliseconds(420))
            withAnimation(.spring(response: 0.45,
                                  dampingFraction: 0.7)) {
                coucou = 0
            }
        }
    }

    /// L'éventail : conteneur de layout FIXE 132×132 (le layout ne voit
    /// JAMAIS la largeur déployée — le remède au piège gonflement),
    /// minis en transforms de rendu, ancré bas, mordant le bord.
    private var eventail: some View {
        let fan = month.eventail
        let slots = FanSlot.pour(fan.count)
        return ZStack {
            Color.clear.frame(width: 132, height: 132)
            ForEach(Array(fan.enumerated()), id: \.element.id) { i, s in
                MiniJouet(session: s, slot: slots[i], z: Double(i),
                          remous: remous, ecart: ecart, salve: salve,
                          sauteur: devant && i == fan.count - 1)
            }
        }
        // LE POIGNET : pencher le téléphone fait à peine pivoter
        // l'éventail (la grammaire de la caresse foil du booster) —
        // bande morte dans BacMotion, zéro rendu poignet immobile.
        .rotationEffect(.degrees(Double(pench.width) * 2.4))
        .offset(x: pench.width * 3, y: pench.height * 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity,
               alignment: .bottom)
        // AU FOND de la card : les minis MORDENT le bord bas et se font
        // trancher net par le coin arrondi (le clip racine) — la coupe
        // à la Apple, tranchée le 19-08. Au repos, le bas glisse sous
        // le dock : la « petite partie cachée » est un choix.
        .offset(y: 4)
    }
}

// MARK: - La mini en main (le jouet)

/// La mini se SAISIT : elle suit le doigt (translation + un soupçon de
/// rotation portée par le geste), passe DEVANT tant qu'elle est tenue,
/// et revient claquer dans son slot au ressort. Pur jeu, zéro état qui
/// survive au lâcher. Le drag a un seuil (10 pt) : le scroll vertical
/// de la page garde sa priorité naturelle.
private struct MiniJouet: View {
    let session: DemoSession
    let slot: FanSlot
    let z: Double
    /// Le remous du scroll : chaque mini l'encaisse avec SON retard et
    /// SON sens (parité) — le tas se secoue, jamais à l'unisson.
    var remous: CGFloat = 0
    /// L'ouverture au rebond du bas (0-1) : l'éventail s'écarte.
    var ecart: CGFloat = 0
    /// L'instant d'atterrissage — le sticker de la mini SAUTEUSE
    /// tressaute 80 ms après sa card (l'objet posé dessus).
    var salve: Date? = nil
    var sauteur = false

    @State private var tirage: CGSize = .zero
    @State private var enMain = false
    @State private var saut: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Le dévers suit le geste, borné — la carte penche du côté où
        // on la tire, jamais en toupie.
        let devers: Double = max(-14.0,
            min(14.0, Double(tirage.width) * 0.12))
        let sens: Double = Int(z) % 2 == 0 ? 1.0 : -1.0
        // Reduce Motion : les secousses se taisent (la poudre le fait
        // déjà) — le détail invisible très Apple.
        let calme: CGFloat = reduceMotion ? 0.0 : 1.0
        let secousseR: Double = Double(remous * calme) * 0.22 * sens
        let secousseY: CGFloat =
            remous * calme * (0.70 - 0.09 * CGFloat(z))
        let secousseX: CGFloat = remous * calme * 0.10 * CGFloat(sens)
        // L'OUVERTURE d'overscroll : l'éventail s'écarte en bout de
        // bac — le vide devient un jouet.
        let ouvre: Double = 1.0 + Double(ecart) * 0.35
        let ouvreX: CGFloat = 1.0 + ecart * 0.28
        // LES OMBRES VIVANTES : l'ombre s'étire quand la mini vole,
        // pince quand elle se pose — la lumière raconte le poids.
        let poids: CGFloat = min(14.0, abs(secousseY) * 0.5)
        MiniSeanceCard(session: session, saut: saut)
            // LA LEVÉE : saisie = la carte se soulève (échelle) et son
            // ombre se creuse — elle quitte physiquement le tas.
            .scaleEffect(enMain ? 1.12 : 1.0)
            .shadow(color: .black.opacity(enMain
                        ? 0.65 : 0.5 - Double(poids) * 0.008),
                    radius: enMain ? 22 : 10 + poids,
                    y: enMain ? 16 : 4 + poids * 0.7)
            .rotationEffect(.degrees(
                slot.angle * ouvre + devers + secousseR))
            .offset(x: slot.dx * ouvreX + tirage.width + secousseX,
                    y: slot.dy + tirage.height + secousseY)
            .zIndex(enMain ? 100 : z)
            .onChange(of: salve) { _, s in
                guard sauteur, s != nil, !reduceMotion else { return }
                Task {
                    try? await Task.sleep(for: .milliseconds(80))
                    withAnimation(.spring(response: 0.25,
                                          dampingFraction: 0.5)) {
                        saut = -3
                    }
                    try? await Task.sleep(for: .milliseconds(130))
                    withAnimation(.spring(response: 0.35,
                                          dampingFraction: 0.6)) {
                        saut = 0
                    }
                }
            }
            // Le ressort du secouement : le remous change à chaque
            // évènement de scroll, la mini le rattrape en rebondissant.
            .animation(.spring(response: 0.42, dampingFraction: 0.42),
                       value: remous)
            .gesture(DragGesture(minimumDistance: 10)
                .onChanged { v in
                    // La levée s'anime ; le suivi du doigt, JAMAIS
                    // (il colle, c'est sa loi).
                    if !enMain {
                        withAnimation(.spring(response: 0.3,
                                              dampingFraction: 0.6)) {
                            enMain = true
                        }
                    }
                    tirage = v.translation
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.5,
                                          dampingFraction: 0.5)) {
                        tirage = .zero
                    }
                    // Elle reste devant et soulevée le temps de rentrer
                    // au slot — sinon elle plonge derrière ses voisines
                    // en plein vol de retour ; la repose (échelle,
                    // ombre) s'anime au moment où l'haptique
                    // d'atterrissage claque.
                    Task {
                        try? await Task.sleep(for: .milliseconds(420))
                        withAnimation(.spring(response: 0.35,
                                              dampingFraction: 0.7)) {
                            enMain = false
                        }
                    }
                })
            // L'haptique : un coup franc à la SAISIE, un petit claque
            // à l'ATTERRISSAGE (le retour au tas).
            .sensoryFeedback(.impact(weight: .medium, intensity: 0.9),
                             trigger: enMain) { _, new in new }
            .sensoryFeedback(.impact(weight: .light, intensity: 0.6),
                             trigger: enMain) { _, new in !new }
    }
}

// MARK: - La poudre du bac

/// Les micro-paillettes de la cérémonie booster (la recette de
/// `PoudreBooster` : étoile-facette à cœur blanc, deux tiers de braise
/// dorée, un tiers de lune, additif demandé AU CONTEXTE du Canvas —
/// jamais à la vue, le piège payé), DÉVERSÉES vers le bas depuis
/// l'éventail pendant le scroll. `force` (0-1) suit la vitesse : à
/// l'arrêt les grains meurent ET l'horloge se met en PAUSE — jamais de
/// 30 Hz pour du statique.
private struct PoudreBac: View {
    var force: CGFloat
    /// L'instant d'atterrissage : pendant ~0,8 s la gerbe joue à pleine
    /// puissance, quelle que soit la vitesse. La page remet `salve` à
    /// nil après coup — c'est CE nil qui rend la pause à l'horloge.
    var salve: Date? = nil
    /// Le VENT du geste : les grains traînent derrière le mouvement,
    /// comme de la vraie poussière.
    var vent: CGFloat = 0

    /// L'origine du temps, UNE pour le process : la vue se ré-init à
    /// chaque rendu, le temps des grains doit rester continu.
    private static let t0 = Date()
    private static let grains = 56

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0,
                                paused: (force < 0.03 && salve == nil)
                                    || reduceMotion)) { tl in
            let t = tl.date.timeIntervalSince(Self.t0)
            let age: Double = salve
                .map { tl.date.timeIntervalSince($0) } ?? 99.0
            let gerbe: Double = max(0.0, 1.0 - age / 0.8)
            let f = max(Double(min(1.0, force)), gerbe)
            Canvas { ctx, size in
                ctx.blendMode = .plusLighter
                let W = size.width
                let H = size.height
                for i in 0 ..< Self.grains {
                    let vie: Double = 1.5 + 1.8 * Self.hash(i, 2)
                    let cyc: Double = (t / vie + Self.hash(i, 5))
                        .truncatingRemainder(dividingBy: 1)
                    // Naît dans la bande de l'éventail, PLEUT en
                    // dérivant — le déversement, pas l'envol.
                    let cx: CGFloat = W * 0.5
                        + CGFloat(Self.hash(i, 1) - 0.5) * W * 0.74
                    let cy: CGFloat = H * (0.50 + 0.28
                        * CGFloat(Self.hash(i, 3)))
                    let x: CGFloat = cx + CGFloat(
                        sin(t * (0.4 + 0.5 * Self.hash(i, 8))
                            + Self.hash(i, 9) * 6.28)) * 7.0
                    let derive: CGFloat =
                        -vent * 0.45 * CGFloat(cyc)
                    let y: CGFloat = cy + CGFloat(cyc) * 52.0 + derive
                    let s: Double = sin(.pi * cyc)
                    let tw: Double = 0.5 + 0.5
                        * sin(t * (7.0 + 12.0 * Self.hash(i, 4))
                              + Self.hash(i, 6) * 6.28)
                    let a: Double = s * s
                        * (0.20 + 0.80 * tw * tw * tw) * f
                    guard a > 0.02 else { continue }
                    let r: CGFloat = CGFloat(0.8 + 1.6 * Self.hash(i, 7))
                    let c: Color = Self.hash(i, 10) < 0.34
                        ? Color(red: 0.96, green: 0.97, blue: 1.00)
                        : Color(red: 1.00, green: 0.62, blue: 0.26)
                    var etoile = Path()
                    etoile.move(to: CGPoint(x: -r, y: 0))
                    etoile.addLine(to: CGPoint(x: 0, y: -r * 0.22))
                    etoile.addLine(to: CGPoint(x: r, y: 0))
                    etoile.addLine(to: CGPoint(x: 0, y: r * 0.22))
                    etoile.closeSubpath()
                    etoile.move(to: CGPoint(x: 0, y: -r))
                    etoile.addLine(to: CGPoint(x: r * 0.22, y: 0))
                    etoile.addLine(to: CGPoint(x: 0, y: r))
                    etoile.addLine(to: CGPoint(x: -r * 0.22, y: 0))
                    etoile.closeSubpath()
                    ctx.fill(etoile.applying(
                        CGAffineTransform(translationX: x, y: y)
                            .rotated(by: (Self.hash(i, 11) - 0.5) * 0.9)),
                             with: .color(c.opacity(a * 0.85)))
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: x - 0.45, y: y - 0.45,
                                               width: 0.9, height: 0.9)),
                        with: .color(Color.white.opacity(a * 0.9)))
                }
            }
        }
        .allowsHitTesting(false)
    }

    private static func hash(_ i: Int, _ k: Int) -> Double {
        let s = sin(Double(i) * 12.9898 + Double(k) * 78.233) * 43758.5453
        return s - floor(s)
    }
}

// MARK: - La mini-card de séance (l'éventail)

/// 132×132, un cran plus claire que l'ardoise (le détachement par la
/// lumière, aidé par le puits). Le contenu vit sur la BANDE VISIBLE :
/// la date deux étages en haut-gauche (le voisin de droite couvre le
/// reste), le sticker décalé bas-droit — ENTIER sur la mini de front,
/// DEVINÉ sur les couvertes : l'effet pochette de la référence.
private struct MiniSeanceCard: View {
    let session: DemoSession
    /// Le tressaut du sticker à l'atterrissage (mini de front seule).
    var saut: CGFloat = 0

    private let forme = RoundedRectangle(cornerRadius: 18,
                                         style: .continuous)

    /// « AOÛT » — le mois court de la pochette, sans le jour.
    private var moisCourt: String {
        session.dateVinyle
            .split(separator: " ").dropFirst().joined(separator: " ")
            .uppercased()
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            forme.fill(LinearGradient(
                colors: [Color(white: 0.15), Color(white: 0.085)],
                startPoint: .top, endPoint: .bottom))
            GrainTexture.tuile
                .resizable(resizingMode: .tile)
                .opacity(0.05)
                .blendMode(.overlay)
                .clipShape(forme)
            forme.fill(EllipticalGradient(
                stops: [
                    .init(color: .white.opacity(0.07), location: 0.0),
                    .init(color: .clear, location: 1.0),
                ],
                center: UnitPoint(x: 0.25, y: 0.08),
                startRadiusFraction: 0, endRadiusFraction: 1.0))
                .blendMode(.plusLighter)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(session.dayNumber).")
                    .font(.inter(19, .bold))
                    .foregroundStyle(Color.inkPrimary)
                Text(moisCourt)
                    .font(.inter(10, .semibold)).tracking(0.8)
                    .foregroundStyle(Color(white: 1).opacity(0.45))
            }
            .padding(12)
            // Bas-GAUCHE : la bande que la voisine de droite ne couvre
            // jamais — le sticker se DEVINE sur les minis couvertes,
            // entier sur celle de front (l'effet pochette). Petit :
            // deux stickers voisins peuvent se chevaucher dans
            // l'éventail, la retenue évite la bouillie.
            Image(session.cat.asset)
                .resizable()
                .scaledToFit()
                .frame(width: 52, height: 52)
                .position(x: 40, y: 78)
                // L'objet POSÉ sur la card : il tressaute après elle.
                .offset(y: saut)
        }
        .frame(width: 132, height: 132)
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
    /// « 18. Août » — le label de la pochette.
    var dateVinyle: String {
        let mois = date.formatted(.dateTime.month(.abbreviated))
            .replacingOccurrences(of: ".", with: "").capitalized
        return "\(dayNumber). \(mois)"
    }
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
