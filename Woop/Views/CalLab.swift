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
    /// L'OUVERTURE (la cinématique Apple) : active quand on arrive par
    /// « Tout voir » (la demande est consommée à l'apparition) ou sur
    /// le banc `-cineLab`. `cineSortie` 0→1 = le voile se lève et la
    /// page arrive DU flou.
    @State private var cineActive = false
    @State private var cineSortie: CGFloat = 1
    /// LA PAGE DU MOIS (l'iPod) : ouverte par le tap d'une card de
    /// front. `-ipodLab` : ouverte d'office sur le premier mois.
    @State private var moisOuvert: MoisLaunch?
    private static let ipodBanc =
        CommandLine.arguments.contains("-ipodLab")

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
            // L'ARRIVÉE DU FLOU : pendant l'ouverture, la page vit
            // derrière le voile et s'affûte quand il se lève — en
            // ZOOM d'arrivée (la caméra se pose).
            .blur(radius: cineActive ? (1 - cineSortie) * 10 : 0)
            .scaleEffect(cineActive ? 1 + (1 - cineSortie) * 0.05 : 1)
            .overlay {
                if cineActive {
                    CineBilan(calendar: calendar, sortie: $cineSortie) {
                        cineActive = false
                        // Le banc boucle pour fouetter le tempo.
                        if CalCine.banc {
                            Task {
                                try? await Task.sleep(for: .seconds(1.2))
                                cineSortie = 0
                                cineActive = true
                            }
                        }
                    }
                }
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
            .onAppear {
                BacMotion.shared.start()
                // La demande d'ouverture (posée par « Tout voir ») se
                // CONSOMME — un passage d'onglet nu n'ouvre rien.
                if CalCine.demande || CalCine.banc {
                    CalCine.demande = false
                    cineSortie = 0
                    cineActive = true
                }
                // Le banc de l'iPod : direct dans la page du mois —
                // avec le mois précédent pour la phrase.
                if Self.ipodBanc, moisOuvert == nil {
                    let liste = DemoMonth.recent(calendar: calendar)
                    if let premier = liste.first {
                        let nom = liste.count > 1
                            ? liste[1].titre(calendar: calendar)
                                .lowercased() : nil
                        let compte = liste.count > 1
                            ? liste[1].sessions.count : nil
                        let reps = liste.count > 1
                            ? liste[1].sessions
                                .reduce(0) { $0 + $1.reps } : nil
                        moisOuvert = MoisLaunch(
                            month: premier, rect: .zero,
                            precedentNom: nom,
                            precedentCompte: compte,
                            precedentReps: reps)
                    }
                }
            }
            .onDisappear { BacMotion.shared.stop() }
            // LA PAGE DU MOIS — l'iPod de verre, né du rect de la
            // card (le fond du cover reste CLAIR : le bac vit derrière
            // pendant le portail).
            .fullScreenCover(item: $moisOuvert) { m in
                MoisIpod(month: m.month, calendar: calendar,
                         depuis: m.rect,
                         precedentNom: m.precedentNom,
                         precedentCompte: m.precedentCompte,
                         precedentReps: m.precedentReps) {
                    moisOuvert = nil
                }
                .presentationBackground(.clear)
            }
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

    /// Le tap sur une card mensuelle : le flash, puis LE PORTAIL — la
    /// page naît du RECT de la card (transaction sans animation : la
    /// cérémonie appartient à MoisIpod, jamais au système).
    private func monthTapped(_ m: DemoMonth, rect: CGRect) {
        flashRow = m.start
        // Le mois PRÉCÉDENT (la liste est du plus récent au plus
        // vieux : le suivant dans la liste) — pour la comparaison.
        let liste = DemoMonth.recent(calendar: calendar)
        var nom: String?
        var compte: Int?
        var reps: Int?
        if let i = liste.firstIndex(where: { $0.id == m.id }),
           i + 1 < liste.count {
            nom = liste[i + 1].titre(calendar: calendar).lowercased()
            compte = liste[i + 1].sessions.count
            reps = liste[i + 1].sessions.reduce(0) { $0 + $1.reps }
        }
        Task {
            try? await Task.sleep(for: .milliseconds(260))
            var tx = Transaction()
            tx.disablesAnimations = true
            withTransaction(tx) {
                moisOuvert = MoisLaunch(month: m, rect: rect,
                                        precedentNom: nom,
                                        precedentCompte: compte,
                                        precedentReps: reps)
            }
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

// MARK: - Le départ de la page du mois

/// Ce qu'il faut pour ouvrir l'iPod : le mois, le rectangle écran de
/// la card d'où le portail s'ouvre (.zero = banc, sans portail), et
/// le mois PRÉCÉDENT (nom + compte) pour la phrase de comparaison.
private struct MoisLaunch: Identifiable {
    let month: DemoMonth
    let rect: CGRect
    var precedentNom: String?
    var precedentCompte: Int?
    var precedentReps: Int?
    var id: Date { month.id }
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

// MARK: - L'ouverture (la cinématique Apple)

/// La demande d'ouverture : posée par « Tout voir » sur la home,
/// consommée à l'apparition de la page — un simple passage d'onglet
/// n'ouvre rien (arbitrage 19-08). `-cineLab` : le banc boucle.
enum CalCine {
    static var demande = false
    static let banc = CommandLine.arguments.contains("-cineLab")
}

/// Un mot de l'écriture : gris Apple ou BLANC (les chiffres), et
/// l'éventuel sticker qui se PLAQUE dessus (le chocolat sur le
/// paragraphe de la réf iPhone 17 Pro).
private struct MotCine: Identifiable {
    let id: Int
    let texte: String
    var blanc = false
    var sticker: WoopSticker?
}

/// UN ACTE de l'ouverture : le titre-choc et ses lignes.
private struct ActeCine {
    let titre: String
    let lignes: [[MotCine]]
    var total: Int { lignes.reduce(0) { $0 + $1.count } }
    var aSticker: Bool {
        lignes.contains { $0.contains { $0.sticker != nil } }
    }
}

/// LE RENDU D'UN ACTE — luxury Apple (19-08, v3). Le titre naît
/// immense et flou (zoom-travelling, ancré haut-gauche). Le paragraphe
/// est LÀ dès le départ, entier, en gris-nuit à peine lisible — et
/// L'ILLUMINATION le traverse : chaque mot s'allume dans l'ordre, les
/// chiffres finissent BLANCS. Rien ne vole, rien ne floute : la
/// lumière seule écrit (l'effet exact des pages produit Apple). Le
/// sticker est une PIÈCE : il se pose avec du poids, lévite à peine
/// (glaciale, ±2 pt), son ombre respire dessous, et sa seule brillance
/// répond au POIGNET (gyroscope) — le balayage de lumière est MORT,
/// deux fois jugé cheap. Tout vit sur UN progrès Animatable par acte
/// (la loi des rampes) ; la fuite vers le haut est le second canal.
private struct ActeVue: View, Animatable {
    var p: CGFloat
    var fuite: CGFloat
    let acte: ActeCine
    let grand: CGFloat
    var pench: CGSize = .zero

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(p, fuite) }
        set {
            p = newValue.first
            fuite = newValue.second
        }
    }

    private let gris = Color(red: 0.525, green: 0.525, blue: 0.545)
    private let nuit = Color(white: 0.17)

    var body: some View {
        let tw: CGFloat = max(0.0, min(1.0, p / 0.40))
        // ALIGNÉ HAUT-GAUCHE : la mise en page éditoriale Apple.
        VStack(alignment: .leading, spacing: 22) {
            Text(acte.titre)
                .font(.inter(44, .bold)).tracking(-0.8)
                .foregroundStyle(Color.white)
                .opacity(Double(tw))
                .blur(radius: (1.0 - tw) * 18.0)
                .scaleEffect(1.6 - 0.6 * tw, anchor: .topLeading)
            VStack(alignment: .leading, spacing: 9) {
                ForEach(0 ..< acte.lignes.count, id: \.self) { l in
                    HStack(spacing: 6) {
                        ForEach(acte.lignes[l]) { mot in
                            rendu(mot)
                        }
                    }
                }
            }
        }
        // LA FUITE : l'acte s'enfuit vers le HAUT dans le flou.
        .opacity(Double(1.0 - fuite))
        .blur(radius: fuite * 10.0)
        .offset(y: -fuite * 60.0)
    }

    /// La fenêtre du mot i : la vague de lumière, calée après le titre.
    private func fenetre(_ i: Int) -> CGFloat {
        let part = CGFloat(i) / CGFloat(max(1, acte.total))
        let debut = 0.34 + part * 0.50
        return max(0.0, min(1.0, (p - debut) / 0.12))
    }

    /// L'ILLUMINATION : le mot en gris-nuit, et sa version allumée qui
    /// monte dessus — aucune géométrie ne bouge.
    private func rendu(_ mot: MotCine) -> some View {
        let w = fenetre(mot.id)
        let fonte: Font = .inter(24, mot.blanc ? .bold : .semibold)
        return ZStack {
            Text(mot.texte).font(fonte).tracking(-0.2)
                .foregroundStyle(nuit)
            Text(mot.texte).font(fonte).tracking(-0.2)
                .foregroundStyle(mot.blanc ? Color.white : gris)
                .opacity(Double(w))
        }
        .overlay {
            if let st = mot.sticker {
                piece(st)
            }
        }
    }

    // MARK: La pièce

    /// La pose : du poids, UN rebond doux — jamais un cirque.
    private func poseEchelle(_ sw: CGFloat) -> CGFloat {
        if sw < 0.75 { return 1.12 - 0.18 * sw }
        return 0.985 + 0.015 * ((sw - 0.75) / 0.25)
    }

    private func piece(_ st: WoopSticker) -> some View {
        let sw: CGFloat = max(0.0, min(1.0, (p - 0.82) / 0.14))
        return ZStack {
            if p >= 0.999, fuite == 0 {
                // LA LÉVITATION GLACIALE : ±2 pt sur ~4 s, l'ombre
                // respire dessous — l'objet plane au-dessus du
                // paragraphe. L'horloge meurt avec l'acte.
                TimelineView(.animation(
                    minimumInterval: 1.0 / 30.0)) { tl in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    let lev = CGFloat(sin(t * 1.57)) * 2.0
                    ZStack {
                        ombre(portee: lev)
                        corps(st).offset(y: -lev)
                    }
                }
            } else {
                ZStack {
                    ombre(portee: 0).opacity(Double(sw))
                    corps(st)
                        .scaleEffect(poseEchelle(sw))
                        .opacity(Double(min(1.0, sw * 2.5)))
                }
            }
        }
        .rotationEffect(.degrees(8))
        // LA LUMIÈRE N'APPARTIENT QU'AU POIGNET : le vernis accroche
        // quand TOI tu bouges — jamais tout seul.
        .rotation3DEffect(.degrees(Double(pench.width) * 3.0),
                          axis: (x: 0, y: 1, z: 0))
        .rotation3DEffect(.degrees(Double(-pench.height) * 3.0),
                          axis: (x: 1, y: 0, z: 0))
        // Posé sur le texte, vers le BAS — jamais vers le titre (payé
        // deux fois : la flamme mangeait « semaine »).
        .offset(x: grand * 0.40, y: grand * 0.05)
        .allowsHitTesting(false)
    }

    /// L'ombre vraie : elle ne se lit que là où la pièce survole le
    /// texte — exactement là où la profondeur compte.
    private func ombre(portee: CGFloat) -> some View {
        Ellipse()
            .fill(Color.black.opacity(0.55 - Double(portee) * 0.05))
            .frame(width: grand * 0.5 + portee * 4.0,
                   height: grand * 0.13)
            .blur(radius: 9)
            .offset(y: grand * 0.30)
    }

    private func corps(_ st: WoopSticker) -> some View {
        Image(st.asset)
            .resizable()
            .scaledToFit()
            .frame(width: grand, height: grand)
    }
}

/// L'OUVERTURE — la séquence en TROIS ACTES (hardcore Apple, 19-08) :
/// « Ta semaine. » en zoom-travelling + le bilan + la flamme-bijou qui
/// slam et brille ; « Août. » + le bilan du mois + le second bijou ;
/// « Ton calendrier. » — puis la sortie caméra : le voile se lève et
/// la page arrive du flou en zoom. Tap n'importe où = skip. ~7 s.
private struct CineBilan: View {
    let calendar: Calendar
    @Binding var sortie: CGFloat
    var onFin: () -> Void

    @State private var actes: [ActeCine] = []
    @State private var acte = 0
    @State private var p: CGFloat = 0
    @State private var fuiteActe: CGFloat = 0
    @State private var fuite: CGFloat = 0
    @State private var fini = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Le poignet : la seule brillance de la pièce.
    @ObservedObject private var motion = BacMotion.shared

    var body: some View {
        ZStack {
            Color.black.opacity(Double(1 - sortie))
            if !actes.isEmpty, acte < actes.count {
                // 120 : le PNG des stickers porte de larges marges
                // transparentes — le glyphe visible fait ~45 % du
                // canevas (170 écrasait le texte, verdict).
                ActeVue(p: p, fuite: fuiteActe, acte: actes[acte],
                        grand: 120, pench: motion.pench)
                    .frame(maxWidth: .infinity, maxHeight: .infinity,
                           alignment: .topLeading)
                    .padding(.leading, 30)
                    .padding(.top, 140)
                    .opacity(Double(1 - fuite))
                    .blur(radius: fuite * 12)
                    .scaleEffect(1 + fuite * 0.05)
                    // Chaque acte REPART À NEUF (états, horloge de vie).
                    .id(acte)
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { finir(vite: true) }
        .task { await jouer() }
    }

    /// Le bilan, fabriqué UNE fois (le recalcul par frame pendant les
    /// animations serait un gâchis — DemoMonth balaie 90 jours).
    private func fabrique() -> [ActeCine] {
        var semaine = 0
        if let sem = calendar.dateInterval(of: .weekOfYear,
                                           for: Date()) {
            var d = sem.start
            while d < sem.end {
                if DemoSession.at(d, calendar: calendar) != nil {
                    semaine += 1
                }
                d = calendar.date(byAdding: .day, value: 1, to: d)
                    ?? sem.end
            }
        }
        let moisCourant = DemoMonth.recent(calendar: calendar).first
        let mois = moisCourant?.count ?? 0
        let series = moisCourant?.sessions
            .reduce(0) { $0 + $1.series } ?? 0
        let pieces = moisCourant?.sessions
            .reduce(0) { $0 + $1.coins } ?? 0
        let nomMois = Date().formatted(.dateTime.month(.wide))
            .capitalized
        let sSem = semaine == 1 ? "séance." : "séances."

        var mots: [MotCine] = []
        var i = 0
        func gris(_ t: String) {
            mots.append(MotCine(id: i, texte: t)); i += 1
        }
        func blanc(_ t: String, _ st: WoopSticker? = nil) {
            mots.append(MotCine(id: i, texte: t, blanc: true,
                                sticker: st)); i += 1
        }
        func ligne() -> [MotCine] {
            let l = mots
            mots = []
            return l
        }

        // ACTE 1 — la semaine : un vrai paragraphe.
        gris("Cette"); gris("semaine,"); gris("tu"); gris("as")
        let a1l1 = ligne()
        gris("enchaîné"); blanc("\(semaine)"); blanc(sSem, .flamme)
        let a1l2 = ligne()
        gris("La"); gris("flamme"); gris("ne"); gris("s'est")
        gris("pas")
        let a1l3 = ligne()
        gris("éteinte"); gris("une"); gris("seule"); gris("fois —")
        let a1l4 = ligne()
        gris("et"); gris("ça"); gris("se"); gris("voit.")
        let acte1 = ActeCine(titre: "Ta semaine.",
                             lignes: [a1l1, a1l2, a1l3, a1l4, ligne()])

        // ACTE 2 — le mois : les trois chiffres, sommés des données.
        i = 0
        gris("\(nomMois),"); gris("c'est"); gris("déjà")
        let a2l1 = ligne()
        blanc("\(mois)"); blanc("séances,")
        blanc("\(series)"); blanc("séries,")
        let a2l2 = ligne()
        gris("et"); blanc("+\(pieces)"); blanc("pièces")
        let a2l3 = ligne()
        gris("dans"); gris("le")
        gris("coffre.")
        mots[mots.count - 1] = MotCine(
            id: mots[mots.count - 1].id, texte: "coffre.",
            sticker: moisCourant?.sessions.first?.cat)
        let a2l4 = ligne()
        gris("La"); gris("régularité"); gris("paie.")
        let acte2 = ActeCine(titre: "\(nomMois).",
                             lignes: [a2l1, a2l2, a2l3, a2l4, ligne()])

        // ACTE 3 — l'annonce, seule.
        i = 0
        gris("Ton"); gris("calendrier"); gris("t'attend.")
        let acte3 = ActeCine(titre: "Ton calendrier.",
                             lignes: [ligne()])
        return [acte1, acte2, acte3]
    }

    private func jouer() async {
        if actes.isEmpty { actes = fabrique() }
        // Le temps de LIRE — une vraie page produit.
        let durees: [Double] = [3.2, 3.6, 1.4]
        let anims: [Double] = [2.6, 2.9, 1.0]
        for a in 0 ..< actes.count {
            guard !fini else { return }
            acte = a
            fuiteActe = 0
            p = 0
            withAnimation(reduceMotion
                ? .easeOut(duration: 0.5)
                : .easeOut(duration: anims[a])) { p = 1 }
            // L'haptique LOURDE du slam, calée sur sa fenêtre (0,80 de
            // l'easeOut ≈ 0,62 du temps).
            if !reduceMotion, actes[a].aSticker {
                Task {
                    try? await Task.sleep(for: .milliseconds(
                        Int(anims[a] * 620)))
                    guard !fini else { return }
                    UIImpactFeedbackGenerator(style: .heavy)
                        .impactOccurred(intensity: 1.0)
                }
            }
            try? await Task.sleep(for: .seconds(
                reduceMotion ? 1.0 : durees[a]))
            guard !fini else { return }
            if a < actes.count - 1 {
                // La fuite vers le haut + le souffle de transition.
                withAnimation(.easeIn(duration: 0.4)) { fuiteActe = 1 }
                if !reduceMotion {
                    UIImpactFeedbackGenerator(style: .soft)
                        .impactOccurred(intensity: 0.5)
                }
                try? await Task.sleep(for: .milliseconds(420))
            }
        }
        finir(vite: false)
    }

    /// La sortie caméra : le texte s'enfuit, le voile se lève, la page
    /// dessous arrive du flou en zoom. Le skip = la même sortie,
    /// pressée.
    private func finir(vite: Bool) {
        guard !fini else { return }
        fini = true
        withAnimation(.easeInOut(duration: vite ? 0.32 : 0.55)) {
            fuite = 1
            sortie = 1
        }
        Task {
            try? await Task.sleep(for: .milliseconds(vite ? 380 : 620))
            onFin()
        }
    }
}

// MARK: - La vitre vivante (l'iPod)

// MARK: - Le liquide de la molette (l'iPod)

/// LE LAIT NOIR ET BLANC (le verdict) : des MÉTABALLES sous le verre
/// natif — des gouttes qui dérivent, se soudent et suivent le doigt,
/// jamais de la brume. Animatable sur `vie` (la loi des rampes : un
/// uniforme nu popperait sec) ; le doigt et le remous en assignation
/// directe — le doigt EST l'animation. L'horloge tourne tant que la
/// page vit (le fluide EST le sujet), et dort sous Reduce Motion :
/// l'état sans le voyage.
private struct LiquideVue: View, Animatable {
    var vie: CGFloat
    var doigtX: CGFloat
    var doigtY: CGFloat
    var remous: CGFloat
    let largeur: CGFloat
    let hauteur: CGFloat
    /// Les prises de la console : le rayon des gouttes, leur vitesse
    /// de dérive, leur nombre — et LA RÈGLE (veille franche au repos,
    /// éveil plein sous le doigt).
    let goutte: CGFloat
    let vitesse: CGFloat
    let nombre: CGFloat
    let veille: CGFloat
    let eveil: CGFloat

    private static let t0 = Date()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var animatableData: CGFloat {
        get { vie }
        set { vie = newValue }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0,
                                paused: reduceMotion)) { tl in
            let t = tl.date.timeIntervalSince(Self.t0)
            Rectangle()
                .fill(Color.white)
                .colorEffect(ShaderLibrary.liquideMolette(
                    .float2(Float(largeur), Float(hauteur)),
                    .float2(Float(doigtX), Float(doigtY)),
                    .float2(Float(vie), Float(t)),
                    .float2(Float(goutte), Float(vitesse)),
                    .float2(Float(veille), Float(eveil)),
                    .float2(Float(nombre), Float(remous))))
        }
        .frame(width: largeur, height: hauteur)
        .allowsHitTesting(false)
    }
}

/// Une salve de poudre au cran : née au point du doigt, éjectée en
/// tangente (jalon 14 — la recette PoudreBac).
private struct SalveCran: Identifiable, Equatable {
    let id = UUID()
    let t0: Date
    let a0: CGFloat
    let dir: CGFloat
    let graine: Int
}

/// La gerbe : 16 grains par salve, tangente amortie, gravité, étoile-
/// facette verbatim. L'horloge DORT quand `salves` est vide.
private struct PoudreCran: View {
    let salves: [SalveCran]
    let centre: CGFloat

    private static let t0 = Date()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0,
                                paused: salves.isEmpty
                                    || reduceMotion)) { tl in
            Canvas { ctx, _ in
                ctx.blendMode = .plusLighter
                for salve in salves {
                    dessiner(salve, ctx: &ctx, quand: tl.date)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func dessiner(_ s: SalveCran, ctx: inout GraphicsContext,
                          quand: Date) {
        let age = quand.timeIntervalSince(s.t0)
        for i in 0 ..< 16 {
            let g = s.graine &+ i
            let vie: Double = 0.45 + 0.4 * Self.hachis(g, 2)
            let cyc: Double = age / vie
            guard cyc > 0, cyc < 1 else { continue }
            let r0: CGFloat = 104.0
                + 12.0 * CGFloat(Self.hachis(g, 1) - 0.5)
            let x0: CGFloat = centre + cos(s.a0) * r0
            let y0: CGFloat = centre + sin(s.a0) * r0
            // La tangente amortie + la dérive radiale + la gravité.
            let vT: CGFloat = s.dir
                * (60.0 + 70.0 * CGFloat(Self.hachis(g, 3)))
                * (1.0 - 0.5 * CGFloat(cyc))
            let vR: CGFloat = 8.0 + 26.0 * CGFloat(Self.hachis(g, 4))
            let tx: CGFloat = -sin(s.a0)
            let ty: CGFloat = cos(s.a0)
            let t = CGFloat(age)
            let x: CGFloat = x0 + tx * vT * t
                + cos(s.a0) * vR * t
            let y: CGFloat = y0 + ty * vT * t
                + sin(s.a0) * vR * t + 130.0 * t * t
            let tw: Double = 0.5 + 0.5
                * sin(age * (7.0 + 12.0 * Self.hachis(g, 5))
                      + Self.hachis(g, 6) * 6.28)
            let a: Double = sin(.pi * cyc) * sin(.pi * cyc)
                * (0.25 + 0.75 * tw * tw * tw)
            guard a > 0.02 else { continue }
            let r: CGFloat = CGFloat(0.8 + 1.4 * Self.hachis(g, 7))
            // Noir et blanc (le verdict) : blanc pur minoritaire, lune
            // majoritaire — plus une étincelle orange.
            let c: Color = Self.hachis(g, 8) < 0.34
                ? Color.white
                : Color(red: 0.96, green: 0.97, blue: 1.00)
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
            ctx.fill(etoile.applying(CGAffineTransform(
                translationX: x, y: y)),
                with: .color(c.opacity(a * 0.85)))
            ctx.fill(Path(ellipseIn: CGRect(
                x: x - 0.45, y: y - 0.45, width: 0.9, height: 0.9)),
                with: .color(Color.white.opacity(a * 0.9)))
        }
    }

    private static func hachis(_ i: Int, _ k: Int) -> Double {
        let s = sin(Double(i) * 12.9898 + Double(k) * 78.233)
            * 43758.5453
        return s - floor(s)
    }
}

// MARK: - La page du mois (l'iPod)

/// LA PAGE DU MOIS : l'écran feuillette les sessions (les grandes
/// `SessionVinyle` — elles ont survécu pour ça), et dessous LA MOLETTE
// MARK: - Le petit écran à points (l'iPod)

/// LA MATRICE DE POINTS (la réf du Camera Control) : un petit panneau
/// noir encastré où le mois s'écrit en LED ORANGE, police 5×7 dessinée
/// au point. Les points ÉTEINTS restent visibles à 4 % — c'est la
/// grille qui fait le vintage ; les allumés portent leur bloom. Aucune
/// horloge : le texte change au cran, rien ne clignote.
private struct MatricePoints: View {
    let texte: String
    /// La montée à l'allumage (0…1) : les colonnes s'allument de
    /// gauche à droite.
    var p: CGFloat = 1
    /// L'INTENSITÉ (le verdict : « AOÛT doit s'illuminer quand on drag
    /// la molette ») : endormie au repos, franche sous le doigt.
    var intensite: Double = 1
    /// MICRO 6 — L'ONDE DU CRAN : la position d'une vague de lumière
    /// qui traverse les colonnes (0 = à gauche, 1 = sortie).
    var onde: Double = 2

    /// La police 5×7, ligne par ligne.
    private static let font: [Character: [String]] = [
        "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
        "B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
        "C": ["01110", "10001", "10000", "10000", "10000", "10001", "01110"],
        "D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
        "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
        "F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
        "G": ["01110", "10001", "10000", "10111", "10001", "10001", "01110"],
        "H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
        "I": ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
        "J": ["00111", "00010", "00010", "00010", "00010", "10010", "01100"],
        "K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
        "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
        "M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
        "N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
        "O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
        "P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
        "Q": ["01110", "10001", "10001", "10001", "10101", "10011", "01101"],
        "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
        "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
        "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
        "U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
        "V": ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
        "W": ["10001", "10001", "10001", "10101", "10101", "11011", "10001"],
        "X": ["10001", "01010", "00100", "00100", "00100", "01010", "10001"],
        "Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
        "Z": ["11111", "00001", "00010", "00100", "01000", "10000", "11111"],
        " ": ["00000", "00000", "00000", "00000", "00000", "00000", "00000"],
    ]

    /// Un afficheur LED ne connaît pas les accents.
    private var lettres: [Character] {
        var brut = texte.uppercased()
        let paires: [(String, String)] = [
            ("\u{00C0}", "A"), ("\u{00C2}", "A"), ("\u{00C9}", "E"),
            ("\u{00C8}", "E"), ("\u{00CA}", "E"), ("\u{00CE}", "I"),
            ("\u{00CF}", "I"), ("\u{00D4}", "O"), ("\u{00DB}", "U"),
            ("\u{00D9}", "U"), ("\u{00C7}", "C"),
        ]
        for (a, b) in paires {
            brut = brut.replacingOccurrences(of: a, with: b)
        }
        return Array(brut)
    }

    private let pas: CGFloat = 3.0
    private let point: CGFloat = 1.8

    private let allumee = Color(red: 1.00, green: 0.52, blue: 0.10)
    private let bloom = Color(red: 1.00, green: 0.42, blue: 0.06)

    var body: some View {
        let cols = max(lettres.count * 6 - 1, 1)
        let large = CGFloat(cols) * pas + 26
        let haute = 7 * pas + 16
        return Canvas { ctx, size in
            let x0 = (size.width - CGFloat(cols) * pas) / 2
            let y0 = (size.height - 7 * pas) / 2
            for (li, ch) in lettres.enumerated() {
                let motif = Self.font[ch] ?? Self.font[" "]!
                for ligne in 0 ..< 7 {
                    let bits = Array(motif[ligne])
                    for col in 0 ..< 5 {
                        let ix = li * 6 + col
                        let cx = x0 + CGFloat(ix) * pas
                        let cy = y0 + CGFloat(ligne) * pas
                        let r = CGRect(x: cx, y: cy,
                                       width: point, height: point)
                        let seuil = CGFloat(ix) / CGFloat(cols)
                        let vu = bits[col] == "1" && seuil <= p
                        if vu {
                            let d = abs(seuil - CGFloat(onde))
                            let vague = exp(-Double(d * d) / 0.012)
                            let f = min(1.0, 0.26 + 0.74 * intensite
                                        + 0.55 * vague)
                            ctx.fill(Path(ellipseIn:
                                r.insetBy(dx: -1.7, dy: -1.7)),
                                with: .color(bloom
                                    .opacity(0.30 * intensite)))
                            ctx.fill(Path(ellipseIn: r),
                                     with: .color(allumee.opacity(f)))
                        } else {
                            ctx.fill(Path(ellipseIn: r),
                                     with: .color(.white.opacity(0.04)))
                        }
                    }
                }
            }
        }
        .frame(width: large, height: haute)
        .background {
            let forme = RoundedRectangle(cornerRadius: 7,
                                         style: .continuous)
            ZStack {
                forme.fill(Color.black)
                forme.fill(LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.55),
                              location: 0.0),
                        .init(color: .clear, location: 0.24),
                    ],
                    startPoint: .top, endPoint: .bottom))
                forme.strokeBorder(Color.white.opacity(0.05),
                                   lineWidth: 0.7)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - La carte de verre de la flamme (l'iPod)

/// LA CARTE DE TA CAPTURE, VERBATIM (le verdict : « cet effet glass,
/// autour de l'écran et derrière la molette ») : la matière de
/// `FlammeJauge.carte`, extraite au mot — le corps de verre à trois
/// arrêts (gris-nuit à peine violet, JAMAIS brun), la nappe chaude qui
/// respire, le grain, la vignette qui assoit, LE SERTISSAGE (la
/// tranche qui prend la lumière en haut) et LA VEINE : l'arc d'or qui
/// court sur l'arête.
///
/// UNE SEULE LIBERTÉ, et c'est une loi de la maison : la veine n'a pas
/// d'horloge — son angle vient du GESTE (la rotation cumulée de la
/// molette). La lumière tourne avec la main, elle ne défile pas.
private struct CarteVerreFlamme: View {
    /// Le rayon des coins de la coque.
    var coins: CGFloat = 26
    /// L'angle de la veine (radians) — le geste, jamais une horloge.
    var veine: CGFloat = 0
    /// La respiration de la nappe (0…1) — le foyer de la machine.
    var souffle: Double = 0
    /// MICRO 7 — l'ÉCLAT de la veine : elle brille avec la vitesse du
    /// doigt et retombe à l'arrêt.
    var eclat: Double = 0
    /// Où la nappe chaude s'ancre (x, y en unités).
    var foyerX: CGFloat = 0.115
    var foyerY: CGFloat = 0.5

    /// UNE COUCHE = UNE VARIABLE (la loi du type-checker : la version
    /// à overlays enchaînés a TUÉ le compilateur, payé une 4e fois).
    /// Le haut CARRÉ : la carte monte au bord de l'écran, Dynamic
    /// Island comprise (l'école de la réf : l'artwork touche le bord,
    /// le titre vit DEDANS) — l'appareil taille les coins hauts.
    var hautCarre: Bool = false

    /// Le bas CARRÉ : la carte sort par le bas de l'écran.
    var basCarre: Bool = false

    private var coque: AnyShape {
        if basCarre {
            return AnyShape(UnevenRoundedRectangle(
                cornerRadii: .init(topLeading: coins,
                                   bottomLeading: 0,
                                   bottomTrailing: 0,
                                   topTrailing: coins),
                style: .continuous))
        }
        return hautCarre
            ? AnyShape(UnevenRoundedRectangle(
                cornerRadii: .init(topLeading: 0,
                                   bottomLeading: coins,
                                   bottomTrailing: coins,
                                   topTrailing: 0),
                style: .continuous))
            : AnyShape(RoundedRectangle(cornerRadius: coins,
                                        style: .continuous))
    }

    /// LE VERRE NATIF sous le corps : c'est LUI qui bombe le fond
    /// (l'aurora est douce — le cas autorisé de la loi du verre). Sans
    /// réfraction, un rectangle reste plat : c'était le « cheap ».
    private var verreNatif: some View {
        coque.fill(Color.clear)
            .glassEffect(.clear, in: coque)
    }

    private var corps: some View {
        coque.fill(LinearGradient(
            stops: [
                .init(color: Color(red: 0.055, green: 0.053,
                                   blue: 0.058), location: 0.0),
                .init(color: Color(red: 0.032, green: 0.030,
                                   blue: 0.034), location: 0.55),
                .init(color: Color(red: 0.018, green: 0.017,
                                   blue: 0.020), location: 1.0),
            ],
            startPoint: .top, endPoint: .bottom))
    }

    private var nappe: some View {
        let s: Double = 0.72 + 0.28 * souffle
        let a1: Double = 0.055 * s
        let a2: Double = 0.022 * s
        return EllipticalGradient(
            stops: [
                .init(color: FlammePalette.coeur.opacity(a1),
                      location: 0.0),
                .init(color: FlammePalette.braise.opacity(a2),
                      location: 0.45),
                .init(color: .clear, location: 1.0),
            ],
            center: UnitPoint(x: foyerX, y: foyerY),
            startRadiusFraction: 0, endRadiusFraction: 0.62)
            .blendMode(.plusLighter)
    }

    private var grain: some View {
        GrainTexture.tuile
            .resizable(resizingMode: .tile)
            .opacity(0.045)
            .blendMode(.overlay)
            .allowsHitTesting(false)
    }

    private var vignette: some View {
        EllipticalGradient(
            stops: [
                .init(color: .clear, location: 0.60),
                .init(color: Color.black.opacity(0.15), location: 1.0),
            ],
            center: .center,
            startRadiusFraction: 0, endRadiusFraction: 0.82)
    }

    /// LE CHANFREIN (le verdict « pas de verre gonflé ») : une bande
    /// LARGE de lumière qui enveloppe l'arête haute et s'enroule dans
    /// les coins — un trait de 1 px n'a pas d'épaisseur, c'est ça qui
    /// rendait plat. Le verre a un bord, et un bord a une largeur.
    private var chanfrein: some View {
        coque.stroke(Color.white.opacity(0.30), lineWidth: 9)
            .blur(radius: 5)
            .mask(LinearGradient(
                stops: [
                    .init(color: .black, location: 0.0),
                    .init(color: .black.opacity(0.35), location: 0.18),
                    .init(color: .clear, location: 0.52),
                ],
                startPoint: .top, endPoint: .bottom))
            .blendMode(.plusLighter)
    }

    /// LE REBOND DU PIED : le bord bas renvoie la lumière — plus fin,
    /// plus vif, à peine chaud. C'est la deuxième arête du volume.
    private var rebond: some View {
        coque.stroke(Color.white.opacity(0.22), lineWidth: 5)
            .blur(radius: 3)
            .mask(LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.62),
                    .init(color: .black.opacity(0.5), location: 0.88),
                    .init(color: .black, location: 1.0),
                ],
                startPoint: .top, endPoint: .bottom))
            .blendMode(.plusLighter)
    }

    /// Le fil de tranche, gardé SOUS le chanfrein : il ne fait plus le
    /// volume, il en trace la crête.
    private var sertissage: some View {
        coque.stroke(LinearGradient(
            stops: [
                .init(color: Color.white.opacity(0.14), location: 0.0),
                .init(color: Color.white.opacity(0.04), location: 0.4),
                .init(color: Color.white.opacity(0.02), location: 1.0),
            ],
            startPoint: .top, endPoint: .bottom), lineWidth: 1)
    }

    private var veineVue: some View {
        let op: Double = 0.30 + 0.18 * souffle + 0.42 * eclat
        return coque.stroke(AngularGradient(
            stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .clear, location: 0.36),
                .init(color: FlammePalette.or.opacity(0.25),
                      location: 0.46),
                .init(color: FlammePalette.blanc.opacity(0.85),
                      location: 0.50),
                .init(color: FlammePalette.or.opacity(0.25),
                      location: 0.54),
                .init(color: .clear, location: 0.64),
                .init(color: .clear, location: 1.0),
            ],
            center: .center, angle: .radians(Double(veine))),
            lineWidth: 1)
            .blendMode(.plusLighter)
            .opacity(op)
    }

    var body: some View {
        ZStack {
            verreNatif
            // Le corps LAISSE PASSER la scène : c'est elle que le
            // verre de la molette réfracte (« on ne voit pas assez la
            // réflexion » — un socle noir mat n'a rien à refléter).
            corps.opacity(0.46)
            nappe
            grain
            vignette
            chanfrein
            rebond
            sertissage
            veineVue
        }
        .clipShape(coque)
        .allowsHitTesting(false)
    }
}

// MARK: - La cinématique de l'écran (l'iPod)

/// LA PHRASE DU MOIS (l'école « Tout voir ») : le gris-nuit traversé
/// par l'ILLUMINATION, mot après mot — rien ne vole, rien ne floute,
/// la lumière seule écrit. UN progrès Animatable (la loi des rampes).
/// Les stickers du mois se posent en dernier.
private struct CineEcran: View, Animatable {
    var p: CGFloat
    let ligne1: [String]
    let ligne2: [String]
    let ligne3: [String]
    let stickers: [String]

    var animatableData: CGFloat {
        get { p }
        set { p = newValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ligneVue(ligne1, debut: 0.04, fin: 0.42,
                     police: .inter(23, .bold), track: -0.4)
            if !ligne2.isEmpty {
                ligneVue(ligne2, debut: 0.40, fin: 0.64,
                         police: .inter(16, .medium), track: -0.2)
            }
            if !ligne3.isEmpty {
                ligneVue(ligne3, debut: 0.62, fin: 0.84,
                         police: .inter(16, .medium), track: -0.2)
            }
            HStack(spacing: 10) {
                ForEach(stickers, id: \.self) { a in
                    Image(a)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 34, height: 34)
                }
            }
            .padding(.top, 8)
            .opacity(Double(fenetre(0.82, 0.96)))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity,
               alignment: .topLeading)
        .padding(.horizontal, 26)
        .padding(.top, 36)
    }

    private func fenetre(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
        let t = (p - a) / max(b - a, 0.001)
        let c = min(max(t, 0), 1)
        return c * c * (3.0 - 2.0 * c)
    }

    /// Une ligne : chaque mot a sa fenêtre d'illumination — le gris
    /// 0,17 dessous, le blanc qui monte dessus, rien ne bouge.
    private func ligneVue(_ mots: [String], debut: CGFloat,
                          fin: CGFloat, police: Font,
                          track: CGFloat) -> some View {
        let n = max(mots.count, 1)
        let pas = (fin - debut) / CGFloat(n)
        return HStack(spacing: 5) {
            ForEach(Array(mots.enumerated()), id: \.offset) { i, mot in
                let a = debut + CGFloat(i) * pas
                let w = Double(fenetre(a, a + pas * 1.6))
                ZStack {
                    Text(mot).font(police).tracking(track)
                        .foregroundStyle(Color.white.opacity(0.17))
                    Text(mot).font(police).tracking(track)
                        .foregroundStyle(.white)
                        .opacity(w)
                }
            }
        }
    }
}

// MARK: - Le manège des séances (le vrai écran)

/// LE MANÈGE ROND (le verdict : « au scroll elles défilent en rond ») :
/// les pochettes mini sur un anneau en perspective, COUPLÉ à la
/// molette — p est la position continue (index + cran/pas), Animatable
/// pour que l'aimant du relâcher et les taps voyagent en ressort. La
/// profondeur se dit par la LUMIÈRE (nuit + alpha), jamais par le
/// flou. Sous la sélection : l'éditorial qui se réécrit.
private struct ManegeVue: View, Animatable {
    var p: CGFloat
    let sessions: [DemoSession]
    var zoom: CGFloat = 0
    var penchX: CGFloat = 0
    /// LE TICK DU CRAN (micro 10) : le flash blanc sur l'arête de la
    /// pochette qui vient de se poser, synchrone avec le clic.
    var tick: Double = 0
    var onTap: (() -> Void)?

    /// L'APPUI QUI A DU POIDS (micro 2) et L'ILLUMINATION de la date
    /// (micro 5) — deux états locaux, aucune horloge globale.
    @State private var presse = false
    @State private var illum: Double = 1
    @State private var selVu = 0

    private static let t0 = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var animatableData: CGFloat {
        get { p }
        set { p = newValue }
    }

    var body: some View {
        let n = max(sessions.count, 1)
        let borne = min(max(p, 0), CGFloat(n - 1))
        let sel = Int(borne.rounded())
        ZStack {
            // Le sol : l'ellipse de lumière sous la pochette de front
            // — l'assise, jamais un trait.
            Ellipse()
                .fill(Color.white.opacity(0.05))
                .frame(width: 186, height: 30)
                .blur(radius: 13)
                .offset(y: 88)
            TimelineView(.animation(minimumInterval: 1.0 / 20.0,
                                    paused: reduceMotion)) { tl in
                let t = tl.date.timeIntervalSince(Self.t0)
                // MICRO 1 — LA RESPIRATION : ±1 pt en 4 s. On ne le
                // voit pas, on le sent.
                let respire = sin(t * 1.57) * 1.0
                anneau
                    .offset(y: -18 + (reduceMotion ? 0 : respire))
                    // MICRO 2 — L'APPUI A DU POIDS.
                    .scaleEffect(presse ? 0.97 : 1.0)
                    .animation(.spring(response: 0.28,
                                       dampingFraction: 0.62),
                               value: presse)
            }
            editorial(sel, n: n)
            // Le tap de la FRONT : jouer la séance posée devant.
            Color.clear
                .frame(width: 156, height: 156)
                .contentShape(Rectangle())
                .onTapGesture { onTap?() }
                .onLongPressGesture(minimumDuration: 0.01,
                                    maximumDistance: 12,
                                    perform: {}) { on in
                    presse = on
                }
                .offset(y: -18)
        }
        .frame(width: 351)
        .frame(maxHeight: .infinity)
        .scaleEffect(1.0 + 0.35 * zoom)
        .opacity(Double(max(0, 1.0 - zoom * 1.15)))
        .clipped()
    }

    /// L'anneau : chaque pochette à son angle relatif — devant à
    /// θ = 0, les autres qui reculent et s'assombrissent.
    private var anneau: some View {
        let n = max(sessions.count, 1)
        let pasA: CGFloat = 2.0 * .pi / CGFloat(max(n, 8))
        // Le frame EXPLICITE avant drawingGroup : l'offscreen
        // rasterise dans les bounds de l'hôte — sans lui, les cards
        // aux offsets sont TRANCHÉES (le piège de la fente dorée,
        // repayé : « on voit plus les mini cards »).
        return ZStack {
            ForEach(Array(sessions.enumerated()),
                    id: \.element.id) { i, s in
                place(s, theta: (CGFloat(i) - p) * pasA)
            }
        }
        .frame(width: 351, height: 240)
        .drawingGroup()
    }

    /// Une pochette sur l'anneau : position, échelle, nuit, TILT 3D
    /// (la signature Cover Flow : les flancs tournent leur face vers
    /// le centre) et la RÉFLEXION-SOL à 8 % — le tout en transforms de
    /// rendu (le conteneur ne gonfle jamais).
    private func place(_ s: DemoSession,
                       theta: CGFloat) -> some View {
        let z = cos(theta)
        let prof = (z + 1.0) / 2.0
        // Le rayon se RESSERRE avec la profondeur : sin 60° = sin 120°
        // — à rayon constant, les pochettes ±1 et ±2 s'empilent au
        // même x (payé au premier tir). Le fond se range DEDANS.
        let x = sin(theta) * (96.0 + 66.0 * prof) + penchX * 4.0
        let y = -12.0 * (1.0 - prof)
        let echelle = 0.72 + 0.38 * prof
        // La profondeur par la NUIT seule — JAMAIS l'alpha (le verdict
        // « des fois transparentes » : on voyait à travers).
        let nuit = -0.40 * Double(1.0 - prof)
        let tilt = max(-38.0, min(38.0,
            -Double(sin(theta)) * 34.0))
        return MiniSeanceCard(session: s, noir: true)
            .scaleEffect(echelle)
            .rotation3DEffect(.degrees(tilt),
                              axis: (x: 0, y: 1, z: 0),
                              perspective: 0.55)
            .brightness(nuit)
            .offset(x: x, y: y)
            .zIndex(Double(z))
            .allowsHitTesting(false)
    }

    /// L'éditorial de la sélection + les POINTS-PAGINATION iPod : la
    /// date en blanc, les chiffres en nuit, le point du front allumé.
    private func editorial(_ sel: Int, n: Int) -> some View {
        let s = sessions[sel]
        return VStack(spacing: 3) {
            Spacer(minLength: 0)
            // MICRO 5 — LA DATE S'ÉCRIT PAR ILLUMINATION : le gris
            // dessous, le blanc qui monte dessus. Jamais un fondu.
            ZStack {
                Text(s.dateVinyle)
                    .font(.inter(19, .bold)).tracking(-0.4)
                    .foregroundStyle(.white.opacity(0.20))
                Text(s.dateVinyle)
                    .font(.inter(19, .bold)).tracking(-0.4)
                    .foregroundStyle(.white)
                    .opacity(illum)
            }
            // MICRO 4 — LES CHIFFRES ROULENT.
            Text("\(s.series) s\u{00E9}ries \u{00B7} \(s.reps) reps")
                .font(.inter(11, .medium)).tracking(0.8)
                .foregroundStyle(Color.inkMuted)
                .textCase(.uppercase)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.4,
                                   dampingFraction: 0.9), value: sel)
            // MICRO 3 — LA PAGINATION SUIT LE DOIGT : la capsule
            // active s'étire EN CONTINU avec p, pas au cran.
            paginationVue(n: n)
                .padding(.top, 10)
        }
        .padding(.bottom, 12)
        .allowsHitTesting(false)
        .onChange(of: sel) { _, neuf in
            selVu = neuf
            illum = 0
            withAnimation(.easeOut(duration: 0.34)) { illum = 1 }
        }
    }

    /// La pagination continue : la capsule vit à la position RÉELLE du
    /// manège (p), donc elle glisse avec le doigt et s'étire au repos.
    private func paginationVue(n: Int) -> some View {
        let pas: CGFloat = 7
        let borne = min(max(p, 0), CGFloat(n - 1))
        let reste = borne - borne.rounded(.down)
        let etire = 1.0 - abs(reste - 0.5) * 2.0
        return ZStack(alignment: .leading) {
            HStack(spacing: 4) {
                ForEach(0 ..< n, id: \.self) { _ in
                    Capsule().fill(Color.white.opacity(0.18))
                        .frame(width: 3, height: 3)
                }
            }
            Capsule()
                .fill(Color.white.opacity(0.90))
                .frame(width: 3 + 9 * (1 - etire), height: 3)
                .offset(x: borne * pas)
        }
        .frame(height: 3)
    }
}

// MARK: - L'onde noire du bouton central (l'iPod)

/// LE NOIR DU PUITS (la demande : « un effet noir à la tap ») :
/// l'inverse exact de toute la lumière de la page — une vague
/// d'OBSCURITÉ qui naît au bouton, traverse l'anneau et s'évanouit.
/// UN progrès Animatable (la loi des rampes).
private struct OndeNoire: View, Animatable {
    var p: CGFloat

    var animatableData: CGFloat {
        get { p }
        set { p = newValue }
    }

    var body: some View {
        let borne = min(max(Double(p), 0.0), 1.0)
        let souffle = sin(.pi * borne)
        ZStack {
            // Le verre s'assombrit d'un souffle…
            Circle()
                .fill(Color.black.opacity(souffle * 0.26))
                .frame(width: 244, height: 244)
            // …et la vague noire court du puits au bord.
            Circle()
                .stroke(Color.black.opacity((1.0 - borne) * 0.55),
                        lineWidth: 30)
                .frame(width: 92 + p * 190, height: 92 + p * 190)
                .blur(radius: 10)
        }
        .allowsHitTesting(false)
    }
}

/// DE VERRE : un iPod classic dont le corps est en Liquid Glass posé
/// sur la scène vidéo (le contour = le bourrelet de réfraction, la
/// signature liquide — jamais un trait). LE GESTE : le doigt tourne
/// sur la molette, chaque cran (~40°) passe une session avec le CLIC
/// du vrai iPod ; ⏮ ⏭ tapent aussi. Le bouton central : la story de
/// la session (plus tard).
private struct MoisIpod: View {
    let month: DemoMonth
    let calendar: Calendar
    /// Le rect de la card d'où la page NAÎT (.zero = pas de portail).
    var depuis: CGRect = .zero
    /// Le mois précédent (la phrase de comparaison de la cinématique).
    var precedentNom: String?
    var precedentCompte: Int?
    var precedentReps: Int?
    var onClose: () -> Void

    // L'ARRIVÉE (le wahou) : le portail, la pose de la pochette, le
    // header qui fond en dernier.
    @State private var entree: CGFloat = 0
    @State private var poseP: CGFloat = 0
    @State private var headerA: Double = 0
    // LA VRAIE STORY (le verdict) : au play, le portail de StoryFlow
    // (les 3 stories de la home) s'ouvre DEPUIS le rect du LCD — plus
    // rien de coupé, par construction. La pill ✕ vit sur la story.
    @State private var storyIpod: CalStoryLaunch?
    @State private var lcdRect: CGRect = .zero
    @State private var zoomAvant: CGFloat = 0
    /// Le souffle du play : l'écran s'agrandit d'un cran, la molette
    /// se retire — le temps que le portail prenne l'écran.
    @State private var grandEcran: CGFloat = 0
    // LA CINÉMATIQUE D'ARRIVÉE (l'école « Tout voir ») : la phrase du
    // mois écrite par ILLUMINATION avant le carrousel. Tap = skip.
    @State private var cineEcranP: CGFloat = 0
    @State private var montrerCine = true
    // LE SCROLL DANS L'ÉCRAN : le drag horizontal nourrit les crans —
    // même physique que la molette (clics, aimant, roue libre).
    @State private var dragEcranX: CGFloat?
    @State private var tempsEcran: Date?

    @State private var index = 0
    /// Le sens du dernier pas (±1) — l'écran glisse du bon côté.
    @State private var sens: CGFloat = 1
    /// L'angle du doigt au dernier évènement, et le cumul du cran.
    @State private var angleDoigt: CGFloat?
    @State private var cran: CGFloat = 0
    /// L'appui du bouton central — le puits s'enfonce.
    @State private var puitsAppui = false
    /// Le flash d'un glyphe tapé (2 = ⏮, 3 = ⏭).
    @State private var glypheFlash: Int?
    /// LA LAMPE DU DOIGT (jalon 8) : son angle (le dernier connu — la
    /// lueur s'éteint sur place), son allumage, et la vitesse angulaire
    /// lissée (elle force l'intensité).
    @State private var angleLampe: CGFloat = 0
    @State private var lampeVive: Double = 0
    @State private var omega: CGFloat = 0
    @State private var tempsDoigt: Date?
    /// Le BLOOM de l'écran au cran (jalon 9).
    @State private var lume: CGFloat = 0
    /// La BORNE refusée : la vignette de l'écran se creuse.
    @State private var refus: CGFloat = 0
    /// LE TOUCHER (jalons 12-13-15-17-18) : la rotation cumulée (le
    /// grain qui tourne), le clic PRÉPARÉ (la latence tue le
    /// crantage), le plancher entre deux clics, les crans du geste en
    /// cours, la butée toquée une seule fois, la roue libre.
    @State private var angleCumul: CGFloat = 0
    @State private var clic = UIImpactFeedbackGenerator(style: .rigid)
    @State private var dernierClic: Date?
    @State private var cransFaits = 0
    @State private var borneToquee = false
    @State private var inertie: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var motion = BacMotion.shared

    /// La lune maison — la SEULE couleur de la molette (le verdict :
    /// du liquid noir et blanc, zéro orange).
    private let lune = Color(red: 0.96, green: 0.97, blue: 1.00)
    /// Le cran : ~40° de molette par session.
    private let pasCran = CGFloat.pi / 4.5

    // LA LUMIÈRE (plan v2 + les quinze touches du peintre) :
    /// Le foyer — l'anneau d'or sous le rim : couve 0,10, s'embrase à
    /// la saisie, respire avec la vitesse, se rendort à la relâche.
    @State private var foyer: Double = 0
    /// La chaleur de la vitre : 0 = verre au repos (bourrelet seul),
    /// 1 = liquide sous le doigt (f0 qui plonge).
    @State private var vitreChaleur: CGFloat = 0
    /// La rosée du premier contact (Ø 40).
    @State private var rosee: CGFloat = 0
    /// Le glyphe que la lampe frôle (le pop) et la vrille du shuffle.
    @State private var glypheChaud: Int?
    @State private var vrille: Double = 0
    /// Le « presque » : la pochette tremble à un cheveu du cran.
    @State private var tremble: Double = 0
    @State private var presqueArme = false
    /// Les salves de poudre du cran (cap 3 — l'horloge dort à vide).
    @State private var salves: [SalveCran] = []
    /// L'allumage de la page : le rétroéclairage puis le foyer.
    @State private var allume: CGFloat = 0
    /// LE COUP LOURD (bouton central, play, butée) — préparé.
    @State private var lourd = UIImpactFeedbackGenerator(style: .heavy)
    /// La pulsation NOIRE du bouton central.
    @State private var nuitPuits: CGFloat = 0
    /// MICRO 6 — l'onde qui traverse la matrice LED au cran.
    @State private var ondeLED: Double = 2
    /// MICRO 8 — la cascade d'arrivée (manège puis matrice).
    @State private var manegeA: Double = 0
    @State private var matriceA: Double = 0

    // LA CONSOLE D'AJUSTAGE (la demande) : six curseurs vivants —
    // Kathryn trouve le beau, dicte les chiffres, on les grave en dur.
    /// La veille : le lait visible au repos (la règle).
    @State private var regVeille: Double = 0.22
    /// L'éveil sous le doigt : plein blanc.
    @State private var regEveil: Double = 1.0
    /// Le nombre de ronds blancs.
    @State private var regGouttes: Double = 4
    /// Le rayon des ronds blancs (px) — gros, mais DISTINCTS (les 62
    /// fusionnaient en une seule masse : effet yin-yang).
    @State private var regTaille: Double = 64
    /// La vitesse de dérive.
    @State private var regVitesse: Double = 0.35
    /// La clarté du verre (face + brillance). 0 = AUCUN voile (le
    /// témoin-carte a montré que la brillance noyait le verre natif).
    @State private var regClarte: Double = 0.15
    /// LE TÉMOIN DU VERRE (la demande : « une image de card random
    /// pour voir comment ça réfracte ») : la console pose une carte
    /// sous la dalle à la place des halos — le juge de paix.
    @State private var fondCarte = true

    // LES COTES MAÎTRESSES (jalon 1) — dérivation, gabarit 393×852 :
    // plaque = W − 32 ; donut = 0,676·plaque ; puits = 0,410·donut
    // (le ratio du vrai iPod 6G, 15,9/38,4) ; glyphes à r 86.
    private let plaqueL: CGFloat = 377
    private let ecranH: CGFloat = 392
    private let moletteH: CGFloat = 280
    private let donut: CGFloat = 244
    private let puits: CGFloat = 100
    private let rGlyphes: CGFloat = 86
    private let formePlaque = RoundedRectangle(cornerRadius: 26,
                                               style: .continuous)

    /// LES BANCS DE LA PREUVE (« prouve-moi que c'est liquid glass ») :
    /// `-ipodTemoin` remplace la matière du donut par une GRILLE + une
    /// photo — une lentille vraie PLIE les droites, un blur ne les plie
    /// pas. `-ipodSansVerre` éteint la dalle : l'A/B se mesure au pixel.
    private static let temoin =
        CommandLine.arguments.contains("-ipodTemoin")
    private static let sansVerre =
        CommandLine.arguments.contains("-ipodSansVerre")
    /// LES VARIANTES DU BLANC (« ce blanc je trouve ça moche ») : le
    /// givre du verre natif blanchit le disque (luma 57 contre 21 pour
    /// la plaque). B = le verre sur l'ANNEAU seul ; D = le verre puis
    /// la NUIT qui le ramène à la valeur de la plaque.
    private static let molAnneau =
        CommandLine.arguments.contains("-molAnneau")
    private static let molNoir =
        CommandLine.arguments.contains("-molNoir")

    var body: some View {
        // LE PORTAIL : la page entière naît du rect de la card — un
        // zoom ancré au point de la card (l'école StoryPortal), le
        // bac visible derrière qui s'éteint pendant la montée.
        GeometryReader { geo in
            let g = geo.frame(in: .global)
            let W = max(geo.size.width, 1)
            let H = max(geo.size.height, 1)
            let portail = depuis != .zero
            let s0: CGFloat = portail ? depuis.width / W : 1
            let s: CGFloat = s0 + (1 - s0) * entree
            let ax: CGFloat = portail
                ? (depuis.midX - g.minX) / W : 0.5
            let ay: CGFloat = portail
                ? (depuis.midY - g.minY) / H : 0.5
            ZStack {
                Color.black
                    .opacity(0.85 * Double(entree))
                    .ignoresSafeArea()
                pageContenu
                    .scaleEffect(s, anchor: UnitPoint(x: ax, y: ay))
                    .opacity(Double(min(1.0, 0.15 + entree * 1.7)))
                // LA VRAIE STORY, DANS L'ARBRE (le verdict : le cover
                // imbriqué ouvrait « une ancienne fenêtre en plus » et
                // décalait la story sous l'île — le titre de la
                // story 2 coupé). Ici : même géométrie que la page,
                // aucune fenêtre système, le portail s'ouvre du LCD.
                if let launch = storyIpod {
                    StoryPortal(from: launch.rect,
                                session: launch.session) {
                        fermerStory()
                    }
                    .overlay(alignment: .bottom) { pillStory }
                    .zIndex(10)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { arrivee() }
        .onDisappear { inertie?.cancel() }
    }

    /// La pill de verre sur la story : ✕ seul — la story garde ses
    /// gestes natifs (tap = passer), la pill n'est que la sortie.
    /// LE SOCLE DU BAS : la carte de verre bord à bord, coins hauts
    /// seuls (le bas sort de l'écran), l'arête haute FONDUE dans le
    /// noir — deux zones, pas trois cartes.
    private var socleBas: some View {
        CarteVerreFlamme(coins: 28,
                         veine: angleCumul * 0.5,
                         souffle: min(1.0, foyer * 3.0),
                         eclat: min(1.0, Double(abs(omega)) * 0.10),
                         foyerX: 0.5, foyerY: 0.5)
            // L'ÉTAGE : le socle est plus sombre que la carte du haut
            // (Apple étage toujours la profondeur).
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.black.opacity(0.22))
                    .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(0.62), radius: 26, y: 12)
    }

    private var pillStory: some View {
        Image(systemName: "xmark")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white.opacity(0.85))
            .frame(width: 92, height: 46)
            .contentShape(Capsule())
            .onTapGesture { fermerStory() }
            .background {
                Capsule().fill(Color.clear)
                    .glassEffect(.clear, in: Capsule())
            }
            .overlay {
                Capsule().strokeBorder(Color.white.opacity(0.10),
                                       lineWidth: 1)
            }
            .padding(.bottom, 24)
    }

    private var pageContenu: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            // La scène : le verre de la molette n'existe que par ce
            // qu'il réfracte.
            FondCalendrier()
                .opacity(0.85)
                .allowsHitTesting(false)
                .ignoresSafeArea()
            // LA FENÊTRE DE LUMIÈRE (jalon 6) : le voile s'OUVRE sous
            // la molette — STATIQUE, jamais animé (constant ≠ uniforme).
            Rectangle()
                .fill(RadialGradient(
                    stops: [
                        .init(color: .black.opacity(0.22), location: 0.0),
                        .init(color: .black.opacity(0.36), location: 0.5),
                        .init(color: .black.opacity(0.52), location: 1.0),
                    ],
                    center: UnitPoint(x: 0.5, y: 0.76),
                    startRadius: 60, endRadius: 460))
                .allowsHitTesting(false)
                .ignoresSafeArea()
            VStack(spacing: 18) {
                // LE VRAI ÉCRAN (le verdict : « un vrai écran d'iPod »)
                // — la dalle 4:3 posée dans le corps, le manège des
                // séances dedans. La console -liquideLab garde sa
                // place.
                if CommandLine.arguments.contains("-liquideLab") {
                    consoleLiquide
                        .padding(.top, 10)
                } else {
                    ecranIpod
                }
                Spacer(minLength: 0)
                // LE BLOC DU BAS PREND TOUT LE BAS (la réf Apple
                // Music) : bord à bord, coins hauts seuls, fondu dans
                // le noir — la MATRICE DE POINTS au-dessus de la roue.
                VStack(spacing: 16) {
                    MatricePoints(
                        texte: month.titre(calendar: calendar),
                        p: CGFloat(matriceA),
                        intensite: 0.22 + 0.78 * lampeVive,
                        onde: ondeLED)
                        .animation(.easeOut(duration: 0.25),
                                   value: lampeVive)
                        .opacity(matriceA)
                        .scaleEffect(0.98 + 0.02 * matriceA)
                    plaqueMolette
                        .scaleEffect(0.92)
                        .frame(height: 262)
                }
                .padding(.top, 22)
                .padding(.bottom, 18)
                .frame(maxWidth: .infinity)
                .background { socleBas }
                .scaleEffect(1.0 - 0.12 * grandEcran, anchor: .top)
                .opacity(Double(max(0, 1.0 - grandEcran * 0.65)))
                // MICRO 9 — LE REFUS PHYSIQUE : à la butée, le bloc
                // recule de 2 pt et revient. Le « non » de la main.
                .offset(y: Double(refus) * 2.0)
                .allowsHitTesting(grandEcran < 0.3)
            }
            // LE BOÎTIER FLOTTE (le verdict : « les borders trop
            // collés ça fait fake ») : des marges ÉGALES partout, rien
            // qui touche un bord, rien qui sort de l'écran.
            .frame(maxHeight: .infinity)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    /// L'ARRIVÉE (le wahou) : le portail (la card devient la page) →
    /// le rétroéclairage → la pochette qui SE POSE (toc + poudre) →
    /// le header qui fond → LE TOUR DE RÉVEIL. Reduce Motion : l'état
    /// sans le voyage. Le banc (.zero) garde une arrivée courte.
    private func arrivee() {
        clic.prepare()
        lourd.prepare()
        if reduceMotion {
            entree = 1
            poseP = 1
            headerA = 1
            allume = 1
            foyer = 0.10
            montrerCine = false
            cineEcranP = 1
            manegeA = 1
            matriceA = 1
        } else if depuis == .zero {
            entree = 1
            poseP = 1
            headerA = 1
            withAnimation(.easeOut(duration: 0.45)) { manegeA = 1 }
            withAnimation(.easeOut(duration: 0.6)) { matriceA = 1 }
            withAnimation(.easeOut(duration: 0.5)) { allume = 1 }
            Task {
                try? await Task.sleep(for: .milliseconds(200))
                withAnimation(.easeOut(duration: 0.4)) { foyer = 0.10 }
                lancerCine()
            }
        } else {
            UIImpactFeedbackGenerator(style: .soft)
                .impactOccurred(intensity: 0.4)
            withAnimation(.spring(response: 0.55,
                                  dampingFraction: 0.86)) {
                entree = 1
            }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(280))
                withAnimation(.easeOut(duration: 0.45)) { allume = 1 }
                try? await Task.sleep(for: .milliseconds(170))
                // La pochette SE POSE — le poids se sent.
                lourd.impactOccurred(intensity: 0.8)
                withAnimation(.spring(response: 0.38,
                                      dampingFraction: 0.66)) {
                    poseP = 1
                }
                if salves.count < 3 {
                    let salve = SalveCran(
                        t0: Date(), a0: -.pi / 2.0, dir: 1,
                        graine: Int.random(in: 0 ... 9999))
                    salves.append(salve)
                    Task {
                        try? await Task.sleep(for: .milliseconds(950))
                        salves.removeAll { $0.id == salve.id }
                    }
                }
                try? await Task.sleep(for: .milliseconds(120))
                // MICRO 8 — LA CASCADE : header, puis le manège, puis
                // la matrice — 60 ms d'écart, chacun de 0,98 à 1.
                withAnimation(.easeOut(duration: 0.35)) { headerA = 1 }
                try? await Task.sleep(for: .milliseconds(60))
                withAnimation(.easeOut(duration: 0.4)) { manegeA = 1 }
                try? await Task.sleep(for: .milliseconds(60))
                withAnimation(.easeOut(duration: 0.45)) { matriceA = 1 }
                withAnimation(.easeOut(duration: 0.4)) { foyer = 0.10 }
                lancerCine()
            }
        }
        // Le banc de la story : la preuve en capture — la story
        // s'ouvre toute seule (le titre de la story 2 se vérifie
        // AUX YEUX, plus jamais sur parole).
        if CommandLine.arguments.contains("-ipodStory") {
            montrerCine = false
            cineEcranP = 1
            Task {
                try? await Task.sleep(for: .milliseconds(1000))
                jouer()
            }
        }
        // Le banc de la chaleur : c = 1 FIGÉ, liquide ÉVEILLÉ — la
        // prise pixel (les volutes doivent transparaître tordues).
        if CommandLine.arguments.contains("-calVitreHeat") {
            vitreChaleur = 1
            foyer = 0.30
            lampeVive = 1
            montrerCine = false
            cineEcranP = 1
        }
    }

    /// LE TOUR DE RÉVEIL : un doigt FANTÔME fait un tour complet de
    /// l'anneau — la lampe voyage DANS le liquide (le halo du doigt du
    /// shader, jamais un balayage dessiné), les glyphes traversés
    /// s'illuminent avec leur micro-tick (passeGlyphes joue gratis),
    /// puis la lumière se fond dans la veille.
    private func tourDeReveil() {
        guard !reduceMotion,
              !CommandLine.arguments.contains("-calVitreHeat")
        else { return }
        withAnimation(.easeIn(duration: 0.12)) { lampeVive = 0.85 }
        Task { @MainActor in
            let duree = 0.72
            let depart: CGFloat = -.pi / 2.0
            let t0 = Date()
            while angleDoigt == nil {
                let dt = Date().timeIntervalSince(t0)
                let p = min(1.0, dt / duree)
                let e = 0.5 - 0.5 * cos(.pi * p)
                angleLampe = depart + CGFloat(e) * 2.0 * .pi
                passeGlyphes()
                if p >= 1.0 { break }
                try? await Task.sleep(for: .milliseconds(16))
            }
            guard angleDoigt == nil else { return }
            glypheChaud = nil
            withAnimation(.easeOut(duration: 0.55)) { lampeVive = 0 }
        }
    }

    // MARK: Le vrai écran (l'anatomie)

    /// LE VRAI ÉCRAN D'iPOD, anatomie complète : le PUITS
    /// d'encastrement (ombre + rebond + chanfrein), la BEZEL noire
    /// laquée, le LCD allumé (backlight bas, BLEED des coins, grain),
    /// l'OMBRE DU LIMBE double (la vitre a une épaisseur), la VITRE au
    /// reflet-fenêtre gyro. `grandEcran` interpole l'iPod → le cinéma.
    private var ecranIpod: some View {
        // PLUS DE HAUTEUR EN DUR (payé deux fois : 410 puis 400 se
        // faisaient COMPRESSER, l'un coupait le texte, l'autre laissait
        // 200 pt de noir mort). La carte prend CE QUI RESTE, le socle
        // garde sa hauteur naturelle : ça rentre sur tout gabarit.
        return ZStack {
            // LA CARTE DE VERRE (ta capture) autour de l'écran — la
            // matière de la carte flamme : verre, sertissage, veine
            // qui tourne avec le geste, nappe qui respire au foyer.
            CarteVerreFlamme(coins: 28,
                             veine: angleCumul * 0.5,
                             souffle: min(1.0, foyer * 3.0),
                             eclat: min(1.0, Double(abs(omega)) * 0.10),
                             foyerX: 0.5, foyerY: 0.94)
            ZStack {
                VStack(spacing: 0) {
                    statutIpod
                    ZStack {
                        if montrerCine {
                            CineEcran(p: cineEcranP,
                                      ligne1: cineLigne1,
                                      ligne2: cineLigne2,
                                      ligne3: cineLigne3,
                                      stickers: cineStickers)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    finirCine(vite: true)
                                }
                                .transition(.opacity)
                        } else {
                            ManegeVue(p: posManege,
                                      sessions: month.sessions,
                                      zoom: zoomAvant,
                                      penchX: motion.pench.width,
                                      tick: Double(lume),
                                      onTap: { jouer() })
                                .opacity(manegeA)
                                .scaleEffect(0.98 + 0.02 * manegeA)
                                .transition(.opacity)
                                .gesture(dragEcran)
                        }
                    }
                    .frame(maxHeight: .infinity)
                    .animation(.easeOut(duration: 0.45),
                               value: montrerCine)
                }
                .rotationEffect(.degrees(tremble))
                .offset(y: puitsAppui ? -1.5 : 0.0)
                .brightness(-0.25 * (1.0 - Double(allume)))
                .animation(.spring(response: 0.3,
                                   dampingFraction: 0.7),
                           value: puitsAppui)
            }
            .padding(.bottom, 14)
            // Le RECT du LCD : le portail de la story s'ouvre d'ici.
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .global)
            } action: { lcdRect = $0 }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scaleEffect(1.05 - 0.05 * poseP)
        .shadow(color: .black.opacity(0.62), radius: 26, y: 12)
    }

    // MARK: La cinématique de l'écran

    /// « 6 séances en août. » — les mots de la ligne 1.
    private var cineLigne1: [String] {
        let n = month.sessions.count
        let mois = month.titre(calendar: calendar).lowercased()
        return "\(n) s\u{00E9}ances en \(mois)."
            .split(separator: " ").map(String.init)
    }

    /// La comparaison au mois précédent — vide si pas de voisin.
    private var cineLigne2: [String] {
        guard let nom = precedentNom,
              let c = precedentCompte else { return [] }
        let d = month.sessions.count - c
        let texte: String
        if d > 0 {
            texte = "\(d) de plus qu'en \(nom)."
        } else if d < 0 {
            texte = "\(-d) de moins qu'en \(nom)."
        } else {
            texte = "Autant qu'en \(nom)."
        }
        return texte.split(separator: " ").map(String.init)
    }

    /// L'AMÉLIORATION (la demande) : le point qui monte — les reps du
    /// mois contre le précédent, seulement s'il y a du mieux.
    private var cineLigne3: [String] {
        guard let r = precedentReps else { return [] }
        let d = month.sessions.reduce(0) { $0 + $1.reps } - r
        guard d > 0 else { return [] }
        return "+\(d) reps au total."
            .split(separator: " ").map(String.init)
    }

    /// Les stickers du mois (uniques, 4 max), posés sous la phrase.
    private var cineStickers: [String] {
        var vus = Set<String>()
        let tous = month.sessions.compactMap { s in
            vus.insert(s.cat.asset).inserted ? s.cat.asset : nil
        }
        return Array(tous.prefix(4))
    }

    /// La cinématique se lance après l'allumage ; elle vit ~3 s puis
    /// cède au carrousel (tap = skip).
    private func lancerCine() {
        guard montrerCine else { return }
        withAnimation(.easeInOut(duration: 2.6)) { cineEcranP = 1 }
        Task {
            try? await Task.sleep(for: .milliseconds(3050))
            finirCine(vite: false)
        }
    }

    /// La sortie de la cinématique : le carrousel fond en place, puis
    /// le tour de réveil lance la machine.
    private func finirCine(vite: Bool) {
        guard montrerCine else { return }
        if vite {
            withAnimation(.easeOut(duration: 0.2)) { cineEcranP = 1 }
        }
        withAnimation(.easeOut(duration: 0.45)) { montrerCine = false }
        tourDeReveil()
    }

    /// LE SCROLL DANS L'ÉCRAN (la demande) : le drag horizontal
    /// alimente la MÊME mécanique de crans que la molette — vers la
    /// gauche = la suivante, l'aimant au relâcher, la roue libre à
    /// l'élan. Deux instruments, une seule physique.
    private var dragEcran: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { v in
                if inertie != nil {
                    inertie?.cancel()
                    inertie = nil
                }
                let x = v.translation.width
                if let dernier = dragEcranX {
                    let d = -(x - dernier) / 92.0 * pasCran
                    let dt = max(v.time.timeIntervalSince(
                        tempsEcran ?? v.time), 0.008)
                    cran += d
                    angleCumul += d * 0.5
                    omega += (d / CGFloat(dt) - omega) * 0.3
                    consommerCrans()
                } else {
                    saisie()
                }
                dragEcranX = x
                tempsEcran = v.time
            }
            .onEnded { _ in
                dragEcranX = nil
                tempsEcran = nil
                doigtLache()
            }
    }

    /// LE HEADER MODERNE (le verdict : « pas assez moderne ») : la
    /// bande grise de l'iPod rétro est MORTE — plus de fond, plus de
    /// séparateur, plus de pictos. De la typo posée sur le verre, de
    /// l'air, et rien d'autre : le mois en tête, le compte en regard.
    private var statutIpod: some View {
        HStack(spacing: 12) {
            ChipVerre(symbole: "chevron.left", label: "Retour",
                      action: onClose)
                .scaleEffect(0.78)
            VStack(alignment: .leading, spacing: 0) {
                Text(month.titre(calendar: calendar))
                    .font(.inter(22, .bold)).tracking(-0.5)
                    .foregroundStyle(.white)
                Text("\(month.sessions.count) s\u{00E9}ances")
                    .font(.inter(11, .medium)).tracking(0.8)
                    .foregroundStyle(Color.inkMuted)
                    .textCase(.uppercase)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 6)
        .opacity(headerA)
    }

    /// L'OMBRE DU LIMBE, DOUBLE : la bezel porte son ombre sur le haut
    /// du LCD (4 pt), et la VITRE en décale l'écho d'un pixel — c'est
    /// l'épaisseur du verre que montrent toutes les photos du vrai.
    private var limbeLCD: some View {
        VStack(spacing: 0) {
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.42), location: 0.0),
                    .init(color: .clear, location: 1.0),
                ],
                startPoint: .top, endPoint: .bottom)
                .frame(height: 5)
            Rectangle().fill(Color.black.opacity(0.16))
                .frame(height: 1)
            Spacer(minLength: 0)
        }
        .allowsHitTesting(false)
    }

    /// LE COUPLAGE MÉCANIQUE : la position continue du manège —
    /// l'index + le cran en cours (la continuité par construction :
    /// quand un cran se consomme, index saute et cran retombe du même
    /// pas). Aux bornes, le débord se fait élastique.
    private var posManege: CGFloat {
        var f: CGFloat = cran / pasCran
        let borneHaute = index >= month.sessions.count - 1 && f > 0
        let borneBasse = index <= 0 && f < 0
        if borneHaute || borneBasse { f *= 0.30 }
        return CGFloat(index) + f
    }

    /// La position et la borne que la molette pilote.
    private var posLecture: Int { index }
    private var maxLecture: Int { month.sessions.count - 1 }

    /// LA CONSOLE D'AJUSTAGE (la demande : « une console de debug
    /// POUR AJUSTER ») : le matériau complet — noir + lait + vitre +
    /// brillance — plein cadre, ET les six curseurs posés dessus. Un
    /// curseur bouge → la console ET la molette changent en direct ;
    /// Kathryn dicte les chiffres gagnants, on les grave en dur.
    private var consoleLiquide: some View {
        ZStack(alignment: .bottom) {
            Color.clear
                .frame(width: plaqueL, height: ecranH)
                .overlay {
                    ZStack {
                        if fondCarte {
                            // LA CARTE-TÉMOIN : du contenu riche sous
                            // la dalle — on VOIT si le verre réfracte.
                            SessionVinyle(
                                session: month.sessions[index])
                                .frame(width: 330, height: 330)
                                .scaleEffect(1.19)
                        } else {
                            Rectangle().fill(LinearGradient(
                                colors: [
                                    Color(white: 0.05
                                        + 0.09 * regClarte),
                                    Color(white: 0.028
                                        + 0.045 * regClarte),
                                ],
                                startPoint: .top, endPoint: .bottom))
                            LiquideVue(
                                vie: max(CGFloat(lampeVive), 0.6),
                                doigtX: 196.0
                                    + cos(angleLampe) * 150.0,
                                doigtY: 196.0
                                    + sin(angleLampe) * 150.0,
                                remous: min(1.0, abs(omega) * 0.12),
                                largeur: 392, hauteur: 392,
                                goutte: CGFloat(regTaille) * 1.5,
                                vitesse: CGFloat(regVitesse),
                                nombre: CGFloat(regGouttes),
                                veille: CGFloat(regVeille),
                                eveil: CGFloat(regEveil))
                                .blendMode(.plusLighter)
                                .compositingGroup()
                        }
                    }
                    .frame(width: 392, height: 392)
                }
                .clipShape(formePlaque)
                // LE VERRE NATIF plein cadre — la dalle .clear du
                // profil, posée en couvercle sur le lait.
                .overlay {
                    formePlaque
                        .fill(Color.clear)
                        .glassEffect(.clear, in: formePlaque)
                        .allowsHitTesting(false)
                }
                .overlay {
                    brillanceVerre
                        .opacity(regClarte)
                        .allowsHitTesting(false)
                }
                .allowsHitTesting(false)
            panneauReglages
        }
        .frame(width: plaqueL, height: ecranH)
    }

    /// Les six curseurs — un banc, pas un produit : Slider système,
    /// mono, valeurs chiffrées à dicter.
    private var panneauReglages: some View {
        VStack(spacing: 2) {
            HStack(spacing: 8) {
                Text("fond")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 66, alignment: .leading)
                Picker("fond", selection: $fondCarte) {
                    Text("halos").tag(false)
                    Text("carte").tag(true)
                }
                .pickerStyle(.segmented)
            }
            regRow("veille", $regVeille, 0 ... 1)
            regRow("éveil", $regEveil, 0 ... 1.4)
            regRow("halos", $regGouttes, 1 ... 14)
            regRow("taille", $regTaille, 20 ... 140)
            regRow("vitesse", $regVitesse, 0 ... 1)
            regRow("clarté", $regClarte, 0 ... 1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.55),
                    in: RoundedRectangle(cornerRadius: 14))
        .padding(10)
    }

    private func regRow(_ nom: String, _ v: Binding<Double>,
                        _ borne: ClosedRange<Double>) -> some View {
        HStack(spacing: 8) {
            Text(nom)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 66, alignment: .leading)
            Slider(value: v, in: borne)
            Text(String(format: "%.2f", v.wrappedValue))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: 48, alignment: .trailing)
        }
    }

    // MARK: La plaque molette (jalon 3)

    /// Même famille de gris — le dôme mangé par l'objet — et l'ASSISE
    /// du donut : l'ombre portée + le rebond de lumière. L'objet est
    /// posé, plus flottant.
    private var plaqueMolette: some View {
        ZStack {
            // LA COUCHE (jalon 1 du plan vitre) : TOUT le visuel de la
            // molette vit dans UN raster 384×384 débordant — c'est lui
            // que la calotte liquidLens lira (portée miroir 1,46·132 ≈
            // 193 → demi-192 minimum). Le clip du parent tranche le
            // débord APRÈS : le shader lit le raster entier.
            moletteScene
            // LA COQUILLE : le geste et ce qui reste AU-DESSUS de la
            // vitre (puits opaque, gerbe, taps).
            moletteCorps
        }
        .frame(width: plaqueL, height: moletteH)
    }

    /// La couche sous vitre : l'overlay-sur-Color.clear est la SEULE
    /// forme qui ne gonfle pas l'hôte (le piège detail-gonfle). Le
    /// centre du donut (180,5 ; 140) EST le centre de la plaque : le
    /// carré 384 centré est bon par construction.
    private var moletteScene: some View {
        Color.clear
            .frame(width: plaqueL, height: moletteH)
            .overlay {
                ZStack {
                    // UN SEUL FOND EN BAS : la plaque n'a plus sa
                    // carte — le SOCLE bord à bord est le seul fond
                    // (le double fond, reproché en haut, tué en bas).
                    assiseDonut
                        .frame(width: plaqueL, height: moletteH)
                    // Le corps visuel de la molette, centré.
                    moletteVisuel
                    // LE VERRE NATIF (la réponse de ProfilLune:524 —
                    // « c'est quand même le composant Apple natif » :
                    // OUI) : la variante .clear — la dalle transparente
                    // du profil, réfraction temps réel et arêtes
                    // spéculaires natives. Le .regular givré reste
                    // INTERDIT. Taille CONSTANTE (le piège des bounds
                    // vivants : redimensionné = blur plat définitif).
                    if !Self.sansVerre {
                        verreDonut
                    }
                    // LA BRILLANCE : le reflet de la SURFACE — au
                    // POIGNET seulement (l'école du sticker — jamais
                    // un balayage), affirmé à la chaleur (la règle du
                    // clic).
                    brillanceVerre
                        .mask(Circle()
                            .frame(width: donut, height: donut))
                        .opacity((0.45 + 0.55 * Double(vitreChaleur))
                            * regClarte * 1.2)
                        .allowsHitTesting(false)
                    // LE FIL SPÉCULAIRE DE L'ARÊTE : le détail qui
                    // fait lire « verre » en un dixième de seconde.
                    Circle()
                        .strokeBorder(LinearGradient(
                            colors: [Color.white.opacity(0.16),
                                     Color.white.opacity(0.03)],
                            startPoint: .top, endPoint: .bottom),
                            lineWidth: 1)
                        .frame(width: donut, height: donut)
                        .allowsHitTesting(false)
                    // LES GLYPHES AU-DESSUS DU VERRE — comme KD et la
                    // pastille vivent au-dessus de la dalle du profil.
                    ZStack { glyphes }
                        .frame(width: donut, height: donut)
                }
                .frame(width: 384, height: 384)
                // MICRO 12 — LA MACHINE S'ÉVEILLE : au contact, le
                // disque gagne 2 % — la main réveille l'objet.
                .scaleEffect(1.0 + 0.02 * lampeVive)
                .animation(.spring(response: 0.35,
                                   dampingFraction: 0.7),
                           value: lampeVive)
            }
            .allowsHitTesting(false)
    }

    /// LE VERRE DU DONUT — la ligne exacte de ProfilLune:524, avec
    /// les deux remèdes au blanc laiteux : le masque d'ANNEAU (le
    /// verre ne vit que sur la bande du doigt) et la NUIT posée
    /// dessus (le givre garde sa texture, perd sa clarté).
    @ViewBuilder private var verreDonut: some View {
        let masqueAnneau = Circle()
            .strokeBorder(Color.white, lineWidth: 72)
            .frame(width: donut, height: donut)
        let masquePlein = Circle()
            .frame(width: donut, height: donut)
        Circle()
            .fill(Color.clear)
            .glassEffect(.clear, in: Circle())
            .frame(width: donut, height: donut)
            .mask {
                if Self.molAnneau { masqueAnneau } else { masquePlein }
            }
            .allowsHitTesting(false)
        if Self.molNoir {
            Circle()
                .fill(Color.black.opacity(0.46))
                .frame(width: donut, height: donut)
                .allowsHitTesting(false)
        }
    }

    /// LE TÉMOIN : une photo et une GRILLE de droites sous la dalle.
    /// C'est la preuve demandée — si le verre réfracte, les lignes se
    /// COURBENT au bord du disque ; si ce n'était qu'un flou, elles
    /// resteraient droites (juste floues).
    private var temoinVue: some View {
        ZStack {
            Image("exo-hip-thrust")
                .resizable()
                .scaledToFill()
                .frame(width: 384, height: 384)
            Canvas { ctx, size in
                let pas: CGFloat = 16
                var x: CGFloat = 0
                while x <= size.width {
                    var p = Path()
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x, y: size.height))
                    ctx.stroke(p, with: .color(.white.opacity(0.55)),
                               lineWidth: 1)
                    x += pas
                }
                var y: CGFloat = 0
                while y <= size.height {
                    var p = Path()
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: size.width, y: y))
                    ctx.stroke(p, with: .color(.white.opacity(0.55)),
                               lineWidth: 1)
                    y += pas
                }
            }
            .frame(width: 384, height: 384)
        }
        .frame(width: 384, height: 384)
        .allowsHitTesting(false)
    }

    /// Le ciel doux que le verre reflète : une nappe elliptique large,
    /// blendée en plusLighter — la position suit le gyro (BacMotion,
    /// bande morte incluse), statique au simulateur.
    private var brillanceVerre: some View {
        EllipticalGradient(
            stops: [
                .init(color: .white.opacity(0.11), location: 0.0),
                .init(color: .white.opacity(0.04), location: 0.45),
                .init(color: .clear, location: 1.0),
            ],
            center: UnitPoint(x: 0.5 + motion.pench.width * 0.10,
                              y: 0.14 + motion.pench.height * 0.08),
            startRadiusFraction: 0, endRadiusFraction: 0.85)
            .blendMode(.plusLighter)
            .compositingGroup()
    }

    /// Le visuel du donut — le CONTENU sous le verre natif (les
    /// glyphes, eux, vivent AU-DESSUS de la dalle, comme au profil).
    private var moletteVisuel: some View {
        ZStack {
            if Self.temoin {
                temoinVue
            } else {
                donutAnatomie
            }
            liquideDonut
            grainTournant
            anisotropie
            roseeVue
                .blendMode(.plusLighter)
                .compositingGroup()
                .allowsHitTesting(false)
        }
        .frame(width: donut, height: donut)
    }

    /// LE LAIT DANS L'EMPREINTE : les gouttes noir et blanc SOUS le
    /// verre — la seule lumière de la molette. Le doigt (r 96, dans
    /// l'anneau) aspire les gouttes ; le remous force le tirage. Le
    /// masque tue tout au bord : rien ne déborde de l'objet, jamais.
    private var liquideDonut: some View {
        LiquideVue(vie: CGFloat(lampeVive),
                   doigtX: 122.0 + cos(angleLampe) * 96.0,
                   doigtY: 122.0 + sin(angleLampe) * 96.0,
                   remous: min(1.0, abs(omega) * 0.12),
                   largeur: donut, hauteur: donut,
                   goutte: CGFloat(regTaille),
                   vitesse: CGFloat(regVitesse),
                   nombre: CGFloat(regGouttes),
                   veille: CGFloat(regVeille),
                   eveil: CGFloat(regEveil))
            .mask(Circle().frame(width: donut, height: donut))
            .opacity(0.85)
            .compositingGroup()
            .allowsHitTesting(false)
    }

    /// L'assise : l'ombre sous le donut, et le liseré de lumière que
    /// l'objet renvoie sur sa plaque (masqué au tiers bas).
    private var assiseDonut: some View {
        ZStack {
            Circle()
                .fill(Color.black)
                .frame(width: donut, height: donut)
                .blur(radius: 18)
                .offset(y: 8)
                .opacity(0.45)
            Circle()
                .stroke(Color.white.opacity(0.05), lineWidth: 10)
                .frame(width: donut + 8, height: donut + 8)
                .blur(radius: 12)
                .mask(LinearGradient(
                    stops: [
                        .init(color: .black, location: 0.0),
                        .init(color: .black, location: 0.7),
                        .init(color: .clear, location: 1.0),
                    ],
                    startPoint: .top, endPoint: .bottom))
                .blendMode(.plusLighter)
                .compositingGroup()
        }
    }

    // MARK: La molette (jalons 4-5-6)

    /// Le corps : l'anatomie MATE sous le VERRE — l'anneau gagne son
    /// volume par les dégradés, le verre rajoute sa profondeur et son
    /// rim (le SEUL contour), le puits est creusé par-dessus.
    private var moletteCorps: some View {
        ZStack {
            // LA NUIT DU BOUTON : la vague d'obscurité du press — sous
            // le puits (le bouton reste net), au-dessus du verre.
            OndeNoire(p: nuitPuits)
            puitsVue
            // LA GERBE DU CRAN (touche 12) : au-dessus du verre, dans
            // son groupe — l'horloge dort quand il n'y a pas de salve.
            PoudreCran(salves: salves, centre: 122.0)
                .frame(width: donut + 80, height: donut + 80)
                .compositingGroup()
        }
        .frame(width: donut, height: donut)
        .contentShape(Circle())
        // LE GESTE DE L'iPOD : le doigt TOURNE, chaque cran clique —
        // et à la relâche, la ROUE LIBRE continue l'élan.
        .gesture(DragGesture(minimumDistance: 2)
            .onChanged { v in doigtBouge(v) }
            .onEnded { _ in doigtLache() })
        .overlay {
            // Les zones de tap : PETITES, sur les glyphes seuls — une
            // grande zone volait le départ du drag (le cousin du
            // voleur, soupçonné dans le « ça marche quasiment pas »).
            ZStack {
                Color.clear.frame(width: 56, height: 56)
                    .contentShape(Circle())
                    .onTapGesture { flanc(2, d: -1) }
                    .offset(x: -rGlyphes)
                Color.clear.frame(width: 56, height: 56)
                    .contentShape(Circle())
                    .onTapGesture { flanc(3, d: 1) }
                    .offset(x: rGlyphes)
                Color.clear.frame(width: 56, height: 56)
                    .contentShape(Circle())
                    .onTapGesture { melanger() }
                    .offset(y: -rGlyphes)
                // ▶︎⏸ : il LANCE la story de la séance posée devant.
                Color.clear.frame(width: 56, height: 56)
                    .contentShape(Circle())
                    .onTapGesture { jouer() }
                    .offset(y: rGlyphes)
            }
        }
    }

    /// L'anatomie du donut — la face de VERRE : un cran plus claire
    /// que la nuit (un verre accroche l'ambiance, le mat l'avale), et
    /// LA RÈGLE DU CLIC : au toucher le verre S'ÉCLAIRCIT d'un cran —
    /// les liquides se lisent pleinement. Les plusLighter dans LEUR
    /// groupe.
    private var donutAnatomie: some View {
        let haut: Double = 0.05 + 0.09 * regClarte
            + 0.05 * Double(vitreChaleur)
        let bas: Double = 0.028 + 0.045 * regClarte
            + 0.03 * Double(vitreChaleur)
        return ZStack {
            Circle().fill(LinearGradient(
                colors: [Color(white: haut), Color(white: bas)],
                startPoint: .top, endPoint: .bottom))
            Circle().fill(RadialGradient(
                stops: [
                    .init(color: .clear, location: 0.86),
                    .init(color: .black.opacity(0.11), location: 1.0),
                ],
                center: .center, startRadius: 0, endRadius: 122))
            // Le tombant vers le puits (Ø 100 = location 0,41).
            Circle().fill(RadialGradient(
                stops: [
                    .init(color: .black.opacity(0.13), location: 0.40),
                    .init(color: .black.opacity(0.03), location: 0.47),
                    .init(color: .clear, location: 0.56),
                ],
                center: .center, startRadius: 0, endRadius: 122))
            Circle()
                .stroke(Color.white.opacity(0.09), lineWidth: 1.5)
                .blur(radius: 1.2)
                .mask(LinearGradient(
                    stops: [
                        .init(color: .black, location: 0.0),
                        .init(color: .clear, location: 0.55),
                    ],
                    startPoint: .top, endPoint: .bottom))
                .blendMode(.plusLighter)
        }
        .frame(width: donut, height: donut)
        .compositingGroup()
    }

    /// La rosée du contact : le verre sent le doigt avant le geste.
    private var roseeVue: some View {
        let xR: CGFloat = 122.0 + cos(angleLampe) * 104.0
        let yR: CGFloat = 122.0 + sin(angleLampe) * 104.0
        return Circle()
            .fill(Color.white.opacity(0.28))
            .frame(width: 40, height: 40)
            .blur(radius: 10)
            .position(x: xR, y: yR)
            .opacity(Double(rosee))
            .frame(width: donut, height: donut)
    }

    /// Le grain : 90 points gravés une fois — le calque porte la
    /// rotation, le Canvas ne se redessine jamais.
    private var grainTournant: some View {
        Canvas { ctx, _ in
            for i in 0 ..< 120 {
                let rho: CGFloat = 52.0
                    + 66.0 * CGFloat(Self.hachis(i, 1))
                let th: CGFloat = CGFloat(Self.hachis(i, 2))
                    * 2.0 * .pi
                let x: CGFloat = 122.0 + rho * cos(th)
                let y: CGFloat = 122.0 + rho * sin(th)
                let r: CGFloat = 0.7 + 0.7 * CGFloat(Self.hachis(i, 3))
                let a: Double = 0.04 + 0.06 * Self.hachis(i, 4)
                ctx.fill(Path(ellipseIn: CGRect(
                    x: x - r, y: y - r,
                    width: r * 2.0, height: r * 2.0)),
                    with: .color(.white.opacity(a)))
            }
        }
        .frame(width: donut, height: donut)
        .rotationEffect(.radians(Double(angleCumul)))
        .mask(Circle().strokeBorder(Color.white, lineWidth: 72)
            .frame(width: donut, height: donut))
        .allowsHitTesting(false)
    }

    /// L'anisotropie : deux lobes doux qui tournent à MI-vitesse du
    /// doigt (le brossage circulaire) + le poignet — zéro horloge.
    private var anisotropie: some View {
        AngularGradient(
            stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .white.opacity(0.035), location: 0.20),
                .init(color: .clear, location: 0.28),
                .init(color: .white.opacity(0.028), location: 0.70),
                .init(color: .clear, location: 0.78),
                .init(color: .clear, location: 1.0),
            ],
            center: .center)
            .frame(width: donut, height: donut)
            .blur(radius: 7)
            .drawingGroup()
            .rotationEffect(.radians(Double(angleCumul) * 0.5
                + Double(motion.pench.width) * 0.35))
            .mask(Circle().strokeBorder(Color.white, lineWidth: 72)
                .frame(width: donut, height: donut))
            .blendMode(.plusLighter)
            .compositingGroup()
            .allowsHitTesting(false)
    }

    private static func hachis(_ i: Int, _ k: Int) -> Double {
        let s = sin(Double(i) * 12.9898 + Double(k) * 78.233)
            * 43758.5453
        return s - floor(s)
    }

    /// La proximité de la lampe : le glyphe frôlé s'allume (32°).
    private func proxGlyphe(_ angle: CGFloat) -> Double {
        let seuil = cos(CGFloat.pi * 32.0 / 180.0)
        let c = cos(angleLampe - angle)
        guard c > seuil else { return 0 }
        return Double((c - seuil) / (1.0 - seuil)) * lampeVive
    }

    /// La sérigraphie (jalon 6) : white 0,38 mesuré sur la réf — fixe
    /// hors évènements ; le flash répond au tap, la lampe du doigt
    /// allume les glyphes qu'elle frôle.
    private var glyphes: some View {
        let oS: Double = 0.38 + 0.62 * proxGlyphe(-.pi / 2.0)
        let oB: Double = min(1.0, 0.38 + 0.62 * proxGlyphe(.pi)
            + (glypheFlash == 2 ? 0.32 : 0.0))
        let oF: Double = min(1.0, 0.38 + 0.62 * proxGlyphe(0)
            + (glypheFlash == 3 ? 0.32 : 0.0))
        let oP: Double = min(1.0, 0.38 + 0.62 * proxGlyphe(.pi / 2.0)
            + (glypheFlash == 4 ? 0.32 : 0.0))
        // LE HALO BLANC (le verdict) : le glyphe traversé s'illumine
        // franc — blanc plein + halo qui bloom, pas un +30 % timide.
        let hS: Double = proxGlyphe(-.pi / 2.0)
        let hB: Double = proxGlyphe(.pi)
        let hF: Double = proxGlyphe(0)
        let hP: Double = proxGlyphe(.pi / 2.0)
        return Group {
            // Le shuffle : la seule vrille autorisée — un ÉVÉNEMENT au
            // tap (touche 8), jamais un décor.
            Image(systemName: "shuffle")
                .rotationEffect(.degrees(vrille))
                .scaleEffect(glypheChaud == 1 ? 1.12 : 1.0)
                .offset(y: -rGlyphes)
                .foregroundStyle(Color.white.opacity(oS))
                .shadow(color: .white.opacity(hS * 0.9),
                        radius: 9)
            Image(systemName: "backward.fill")
                .scaleEffect(glypheChaud == 2 ? 1.12 : 1.0)
                .offset(x: -rGlyphes, y: 0.5)
                .foregroundStyle(Color.white.opacity(oB))
                .shadow(color: .white.opacity(hB * 0.9),
                        radius: 9)
            Image(systemName: "forward.fill")
                .scaleEffect(glypheChaud == 3 ? 1.12 : 1.0)
                .offset(x: rGlyphes, y: 0.5)
                .foregroundStyle(Color.white.opacity(oF))
                .shadow(color: .white.opacity(hF * 0.9),
                        radius: 9)
            Image(systemName: "playpause.fill")
                .scaleEffect(glypheChaud == 4 ? 1.12 : 1.0)
                .offset(y: rGlyphes)
                .foregroundStyle(Color.white.opacity(oP))
                .shadow(color: .white.opacity(hP * 0.9),
                        radius: 9)
        }
        .font(.system(size: 13, weight: .semibold))
        .animation(.spring(response: 0.22, dampingFraction: 0.55),
                   value: glypheChaud)
    }

    /// Le passage de la lampe SUR un glyphe : le pop + le tick — on
    /// roule sur les boutons (touche 4).
    private func passeGlyphes() {
        let angles: [(Int, CGFloat)] = [
            (1, -.pi / 2.0), (2, .pi), (3, 0.0), (4, .pi / 2.0),
        ]
        var chaud: Int?
        for (id, a) in angles where cos(angleLampe - a) > 0.92 {
            chaud = id
        }
        if chaud != glypheChaud {
            glypheChaud = chaud
            if chaud != nil, lampeVive > 0.5 {
                UIImpactFeedbackGenerator(style: .light)
                    .impactOccurred(intensity: 0.3)
            }
        }
    }

    /// Le shuffle : session au hasard, la vrille du glyphe, deux temps
    /// d'haptique.
    private func melanger() {
        guard storyIpod == nil, month.sessions.count > 1 else { return }
        var cible = index
        while cible == index {
            cible = Int.random(in: 0 ..< month.sessions.count)
        }
        withAnimation(.spring(response: 0.35,
                              dampingFraction: 0.7)) {
            vrille += 180
        }
        sens = cible > index ? 1 : -1
        withAnimation(.spring(response: 0.4,
                              dampingFraction: 0.85)) {
            index = cible
        }
        UIImpactFeedbackGenerator(style: .rigid)
            .impactOccurred(intensity: 0.6)
        Task {
            try? await Task.sleep(for: .milliseconds(90))
            UIImpactFeedbackGenerator(style: .light)
                .impactOccurred(intensity: 0.4)
        }
    }

    /// Le double-tap du puits : retour à la plus récente, en cascade
    /// accélérée (3 intermédiaires max) — touche 6.
    private func retourRecent() {
        guard index > 0 else { return }
        UIImpactFeedbackGenerator(style: .rigid)
            .impactOccurred(intensity: 0.6)
        Task { @MainActor in
            var pas = 0
            while index > 0, pas < 3 {
                avancer(-1)
                pas += 1
                try? await Task.sleep(for: .milliseconds(90))
            }
            if index > 0 {
                sens = -1
                withAnimation(.spring(response: 0.4,
                                      dampingFraction: 0.85)) {
                    index = 0
                }
            }
        }
    }

    /// LE PUITS CREUSÉ (jalon 5) : le gradient INVERSÉ (le bas
    /// s'allume dans un creux — le signe de la concavité), le croissant
    /// d'ombre en haut, la lumière en bas. L'appui l'ENFONCE.
    private var puitsVue: some View {
        ZStack {
            Circle().fill(LinearGradient(
                colors: [Color(white: puitsAppui ? 0.008 : 0.012),
                         Color(white: puitsAppui ? 0.06 : 0.05)],
                startPoint: .top, endPoint: .bottom))
            Circle()
                .stroke(Color.black.opacity(0.55),
                        lineWidth: puitsAppui ? 8 : 6)
                .blur(radius: 5)
                .offset(y: 4)
                .mask(Circle())
            // Le puits BOIT la lumière du foyer (touche 5).
            Circle()
                .stroke(Color.white.opacity(0.07 + 0.10 * foyer),
                        lineWidth: 3)
                .blur(radius: 3)
                .offset(y: -2)
                .blendMode(.plusLighter)
                .compositingGroup()
            Ellipse()
                .fill(Color.white.opacity(0.03))
                .frame(width: 46, height: 18)
                .blur(radius: 6)
                .offset(y: 22)
            // LE LOGO LUNE NÉON (la demande) : LE croissant de la
            // marque (GlypheLune — les 18 cubiques du splash), qui
            // n'existe QUE sous l'appui — l'ambre du logo (la recette
            // NeonPrimaryButton : cœur blanc-chaud, tube ambre, halo
            // braise), jamais au repos.
            GlypheLune()
                .fill(Color(red: 1.00, green: 0.72, blue: 0.42))
                .frame(width: 32, height: 32)
                .shadow(color: Color(red: 1.00, green: 0.965,
                                     blue: 0.90).opacity(0.9),
                        radius: 2)
                .shadow(color: Color(red: 1.00, green: 0.42,
                                     blue: 0.13).opacity(0.85),
                        radius: 14)
                .shadow(color: Color(red: 1.00, green: 0.42,
                                     blue: 0.13).opacity(0.5),
                        radius: 26)
                .opacity(puitsAppui ? 1 : 0)
                .scaleEffect(puitsAppui ? 1.0 : 0.55)
                .animation(.spring(response: 0.26,
                                   dampingFraction: 0.6),
                           value: puitsAppui)
                .allowsHitTesting(false)
        }
        .frame(width: puits, height: puits)
        .contentShape(Circle())
        // Le double-tap : retour à la plus récente (touche 6) — posé
        // AVANT l'appui pour ne pas se faire voler.
        .onTapGesture(count: 2) { retourRecent() }
        // LE CLIC : la story — la carte s'éteint en télé et le récit
        // s'ouvre de son rect (le simple attend l'échec du double).
        .onTapGesture { jouer() }
        .onLongPressGesture(minimumDuration: 0.01, maximumDistance: 40,
                            perform: {}) { on in
            withAnimation(on
                ? .easeOut(duration: 0.09)
                : .spring(response: 0.25, dampingFraction: 0.7)) {
                puitsAppui = on
            }
            // Le bouton a un POIDS (la demande : « un effet noir à la
            // tap et gros haptique ») : le coup LOURD + la vague noire
            // à l'appui, net au retour.
            if on {
                pulseNoir()
            } else {
                UIImpactFeedbackGenerator(style: .rigid)
                    .impactOccurred(intensity: 0.5)
            }
        }
    }

    // MARK: Le toucher (jalons 12-13-17-18)

    /// Le doigt bouge : déroulé ±π, cran, vitesse lissée, grain qui
    /// tourne (et qui PATINE à la butée — l'embrayage glisse : le
    /// doigt tourne 4× plus vite que la matière).
    private func doigtBouge(_ v: DragGesture.Value) {
        // Rattraper la roue libre : capture nette.
        if inertie != nil {
            inertie?.cancel()
            inertie = nil
            UIImpactFeedbackGenerator(style: .soft)
                .impactOccurred(intensity: 0.30)
        }
        let dx = v.location.x - 122.0
        let dy = v.location.y - 122.0
        let a = atan2(dy, dx)
        if let dernier = angleDoigt {
            var d = a - dernier
            if d > .pi { d -= 2.0 * .pi }
            if d < -.pi { d += 2.0 * .pi }
            let dehors = (d > 0 && posLecture >= maxLecture)
                || (d < 0 && posLecture <= 0)
            cran += d
            angleCumul += dehors ? d * 0.25 : d
            let dt = max(
                v.time.timeIntervalSince(tempsDoigt ?? v.time), 0.008)
            omega += (d / CGFloat(dt) - omega) * 0.3
            consommerCrans()
        } else {
            saisie()
        }
        // ASSIGNATION DIRECTE : le doigt EST l'animation.
        angleLampe = a
        angleDoigt = a
        tempsDoigt = v.time
        // On roule sur les boutons (touche 4).
        passeGlyphes()
    }

    /// Les crans se consomment TANT QUE la borne le permet — sinon le
    /// cran s'accumule (borné) et la butée TOQUE une seule fois.
    private func consommerCrans() {
        while cran > pasCran, posLecture < maxLecture {
            cran -= pasCran
            avancer(1)
            borneToquee = false
        }
        while cran < -pasCran, posLecture > 0 {
            cran += pasCran
            avancer(-1)
            borneToquee = false
        }
        if abs(cran) > pasCran {
            cran = max(-pasCran * 2.2, min(pasCran * 2.2, cran))
            if !borneToquee {
                borneToquee = true
                toqueBorne()
            }
        }
        if abs(cran) < 0.3 * pasCran {
            borneToquee = false
        }
        // LE PRESQUE (touche 11) : à un cheveu du cran sans franchir,
        // la pochette tremble d'un demi-degré.
        let f = abs(cran) / pasCran
        if f > 0.85, f < 1.0, !presqueArme {
            presqueArme = true
            withAnimation(.spring(response: 0.15,
                                  dampingFraction: 0.4)) {
                tremble = 0.5
            }
            Task {
                try? await Task.sleep(for: .milliseconds(90))
                withAnimation(.spring(response: 0.25,
                                      dampingFraction: 0.5)) {
                    tremble = 0
                }
            }
        }
        if f < 0.6 { presqueArme = false }
    }

    /// La saisie : le générateur se PRÉPARE, la rosée perle, le
    /// liquide S'ÉVEILLE (lampeVive → vie, en rampe Animatable), le
    /// verre se liquéfie.
    private func saisie() {
        clic.prepare()
        cransFaits = 0
        UIImpactFeedbackGenerator(style: .soft)
            .impactOccurred(intensity: 0.35)
        withAnimation(.easeOut(duration: 0.25)) { lampeVive = 1 }
        // La rosée (touche 1) — bue par le liquide qui monte.
        rosee = 1
        withAnimation(.easeOut(duration: 0.25)) { rosee = 0 }
        // La vitre qui se fait LIQUIDE (Reduce Motion : l'état sans le
        // voyage).
        withAnimation(.easeOut(duration: 0.25)) { foyer = 0.30 }
        if reduceMotion {
            vitreChaleur = 1
        } else {
            withAnimation(.easeOut(duration: 0.22)) { vitreChaleur = 1 }
        }
    }

    /// La relâche : la lampe s'éteint sur place, le soft de dépose si
    /// le geste a servi — et si l'élan est là, LA ROUE LIBRE.
    private func doigtLache() {
        angleDoigt = nil
        tempsDoigt = nil
        if cransFaits >= 1 {
            UIImpactFeedbackGenerator(style: .soft)
                .impactOccurred(intensity: 0.25)
        }
        // Le liquide se rendort sur place, la vitre REFROIDIT — écrit
        // ICI, hors de toute branche : jamais un gel à chaud.
        withAnimation(.easeOut(duration: 0.6)) { foyer = 0.10 }
        if reduceMotion {
            vitreChaleur = 0
        } else {
            withAnimation(.easeOut(duration: 0.45)) { vitreChaleur = 0 }
        }
        if abs(omega) > 3.0, !reduceMotion {
            // La lampe FANTÔME (touche 10) : la roue libre se voit.
            withAnimation(.easeOut(duration: 0.2)) { lampeVive = 0.5 }
            rouleLibre()
        } else {
            omega = 0
            withAnimation(.easeOut(duration: 0.35)) { lampeVive = 0 }
            withAnimation(.spring(response: 0.32,
                                  dampingFraction: 0.7)) { cran = 0 }
        }
    }

    /// LA ROUE LIBRE (jalon 17) : l'élan s'égrène — la matière tourne,
    /// les crans passent (4 max, jamais un carrousel), l'arrêt est
    /// net à la borne. La tâche meurt au rattrapage et au démontage.
    private func rouleLibre() {
        var crans = 0
        inertie = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(16))
                if Task.isCancelled { return }
                omega *= CGFloat(exp(-0.016 / 0.38))
                let delta = omega * 0.016
                cran += delta
                angleCumul += delta
                // La lampe fantôme SUIT la rotation.
                angleLampe += delta
                while cran > pasCran,
                      posLecture < maxLecture, crans < 4 {
                    cran -= pasCran
                    crans += 1
                    avancer(1)
                }
                while cran < -pasCran, posLecture > 0, crans < 4 {
                    cran += pasCran
                    crans += 1
                    avancer(-1)
                }
                let borne = (omega > 0 && posLecture >= maxLecture)
                    || (omega < 0 && posLecture <= 0)
                if abs(omega) < 0.9 || crans >= 4 || borne {
                    omega = 0
                    withAnimation(.spring(response: 0.32,
                                          dampingFraction: 0.7)) {
                        cran = 0
                    }
                    withAnimation(.easeOut(duration: 0.4)) {
                        lampeVive = 0
                    }
                    inertie = nil
                    return
                }
            }
        }
    }

    /// LE PLAY : l'écran souffle un cran, la molette se retire, et LE
    /// PORTAIL DE LA VRAIE STORY (StoryFlow — les 3 stories de la
    /// home) s'ouvre DEPUIS le rect du LCD. La pill ✕ vit sur la
    /// story ; sa fin (ou ✕) referme le portail sur l'écran et le
    /// manège rattrape en morphisme.
    private func jouer() {
        guard storyIpod == nil else { return }
        lourd.impactOccurred(intensity: 0.85)
        let recit = month.sessions[index].storySession
        if reduceMotion {
            grandEcran = 1
        } else {
            withAnimation(.spring(response: 0.45,
                                  dampingFraction: 0.82)) {
                grandEcran = 1
                zoomAvant = 0.35
            }
        }
        storyIpod = CalStoryLaunch(rect: lcdRect, session: recit)
    }

    /// La fermeture : le portail se replie sur le LCD (StoryPortal
    /// fait son morph), l'écran et la molette reviennent au repos.
    private func fermerStory() {
        storyIpod = nil
        lourd.impactOccurred(intensity: 0.6)
        if reduceMotion {
            grandEcran = 0
            zoomAvant = 0
        } else {
            withAnimation(.spring(response: 0.5,
                                  dampingFraction: 0.82)) {
                grandEcran = 0
                zoomAvant = 0
            }
        }
    }

    /// LE NOIR DU PUITS : le coup lourd + la vague d'obscurité qui
    /// traverse l'anneau (Reduce Motion : le coup sans la vague).
    private func pulseNoir() {
        lourd.impactOccurred(intensity: 1.0)
        guard !reduceMotion else { return }
        nuitPuits = 0
        withAnimation(.easeOut(duration: 0.42)) { nuitPuits = 1 }
        Task {
            try? await Task.sleep(for: .milliseconds(460))
            nuitPuits = 0
        }
    }

    /// La butée : le double coup (TOC… toc) — lourd puis sourd (la
    /// demande : haptique FORT), l'écran qui refuse.
    private func toqueBorne() {
        lourd.impactOccurred(intensity: 0.9)
        withAnimation(.easeOut(duration: 0.18)) { refus = 1 }
        Task {
            try? await Task.sleep(for: .milliseconds(70))
            UIImpactFeedbackGenerator(style: .soft)
                .impactOccurred(intensity: 0.5)
            try? await Task.sleep(for: .milliseconds(110))
            withAnimation(.easeOut(duration: 0.3)) { refus = 0 }
        }
    }

    /// Le tap d'un flanc : le glyphe flash (120 ms), et le cran.
    private func flanc(_ glyphe: Int, d: Int) {
        withAnimation(.easeOut(duration: 0.12)) { glypheFlash = glyphe }
        avancer(d)
        Task {
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(.easeOut(duration: 0.3)) { glypheFlash = nil }
        }
    }

    /// Un cran : le CLIC de l'iPod, le BLOOM de l'écran, le flash du
    /// glyphe du sens, la gerbe. À la borne : l'écran REFUSE (la
    /// vignette se creuse), le coup est sourd.
    private func avancer(_ d: Int) {
        let cible = index + d
        guard cible >= 0, cible < month.sessions.count else {
            UIImpactFeedbackGenerator(style: .soft)
                .impactOccurred(intensity: 0.4)
            withAnimation(.easeOut(duration: 0.18)) { refus = 1 }
            Task {
                try? await Task.sleep(for: .milliseconds(180))
                withAnimation(.easeOut(duration: 0.3)) { refus = 0 }
            }
            return
        }
        sens = CGFloat(d)
        // LE COUPLAGE : sous le doigt (ou en roue libre), index saute
        // SEC — la continuité du manège vient de cran qui retombe du
        // même pas. Au tap (flancs, shuffle), le ressort porte le
        // voyage (le manège est Animatable sur p).
        if angleDoigt == nil, dragEcranX == nil, inertie == nil {
            withAnimation(.spring(response: 0.4,
                                  dampingFraction: 0.85)) {
                index = cible
            }
        } else {
            index = cible
        }
        // LE CLIC PRÉPARÉ (jalon 13) : FORT (la demande) — base 0,75,
        // la vitesse pousse au plafond, plancher 40 ms — on saute des
        // CLICS, jamais des crans.
        let maintenant = Date()
        let assezVieux = dernierClic
            .map { maintenant.timeIntervalSince($0) >= 0.04 } ?? true
        if assezVieux {
            clic.impactOccurred(intensity: 0.75
                + min(0.20, Double(abs(omega)) * 0.06))
            dernierClic = maintenant
        }
        cransFaits += 1
        // MICRO 6 — L'ONDE traverse la matrice LED à chaque cran.
        ondeLED = -0.1
        withAnimation(.easeOut(duration: 0.42)) { ondeLED = 1.1 }
        // Le BLOOM du dôme de l'écran ; le glyphe du sens qui flash —
        // toujours deux temps + Task (jamais une rampe échelonnée).
        withAnimation(.easeOut(duration: 0.06)) {
            lume = 1
        }
        glypheFlash = d > 0 ? 3 : 2
        // LA GERBE (touche 12) : née au point du doigt, tangente au
        // sens — cap 3 salves, chaque salve retire la sienne (salves
        // VIDE rend la pause à l'horloge).
        if !reduceMotion, salves.count < 3 {
            let salve = SalveCran(t0: Date(), a0: angleLampe,
                                  dir: CGFloat(d),
                                  graine: Int.random(in: 0 ... 9999))
            salves.append(salve)
            Task {
                try? await Task.sleep(for: .milliseconds(950))
                salves.removeAll { $0.id == salve.id }
            }
        }
        Task {
            try? await Task.sleep(for: .milliseconds(70))
            withAnimation(.easeOut(duration: 0.42)) { lume = 0 }
            withAnimation(.easeOut(duration: 0.22)) { glypheFlash = nil }
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
    /// LE NOIR ABSOLU (le verdict : « plus full noir même les mini
    /// cards ») : la variante du manège — noir, un seul cheveu blanc à
    /// 6 %, zéro gris moyen. Le bac garde ses cards d'origine.
    var noir: Bool = false

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
                colors: noir
                    ? [Color(white: 0.040), Color(white: 0.014)]
                    : [Color(white: 0.15), Color(white: 0.085)],
                startPoint: .top, endPoint: .bottom))
            if noir {
                forme.strokeBorder(Color.white.opacity(0.06),
                                   lineWidth: 1)
            }
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
