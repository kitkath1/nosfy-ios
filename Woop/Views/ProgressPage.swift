import SwiftUI
import SwiftData

// MARK: - PROGRESS v2 — la page où l'on atterrit (30-08)
//
// Le plan : tools/progress/PLAN-PROGRESS-V2.md. La page est une « grosse card »
// au patron exos (marge de nuit 10 en haut, coins 55, `FormeCardExos` qui se
// RACCOURCIT par le bas), posée sur la nuit. Dedans, de bas en haut : le feu
// (`home-fond-flamme`) et la pill de verre rouge (`story-pilule-droite`) en
// additif — la maquette, sans recuit —, puis le header « Progress » à la robe
// de Rewards, l'ardoise « This week » remontée de la home avec ses places
// VIDES, et la card calendrier (grille fixe à six rangées, ‹ › de mois, le
// bouton « Voir dans le lecteur »).
//
// CE QU'ELLE NE FAIT PAS — le partage du 30-08 : le player. La dalle, le geste
// qui pousse la page et la partition sont le composant PageCard de la session
// player ; la page DÉGAGE la zone (levée fixe en séance) et reçoit `levee`.
// Rien de SwiftData n'est rendu derrière la page (la loi du rideau).
//
// Les lois tenues ici (skill woop-architecture) : les données se calculent UNE
// fois (`calcule()`), jamais dans le corps ; le flou d'arrivée est transitoire
// et retombe à ZÉRO EXACT (`ArriveeFloue`), jamais sur le verre au-delà de
// l'opacité ; la couche vidéo est un `CalqueVideo` (pose DANS le representable,
// clip UIKit) sur un hôte NEUTRE `Color.clear` ; un seul `compositingGroup()`
// en dernier ; la story vit DANS L'ARBRE (jamais un cover imbriqué depuis une
// page qu'on drag).

/// Le banc : la page seule (`-progressLab`).
struct ProgressLab: View {
    var body: some View { ProgressPage(onBack: {}) }
}

/// Les drapeaux du banc de la page Progress.
enum ProgressBanc {
    private static func valeur(_ cle: String, _ rang: Int = 1) -> Double? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: cle), i + rang < args.count
        else { return nil }
        return Double(args[i + rang])
    }
    /// `-progressPill <dy> <dx>` : la pill décalée, en points.
    static let pillDy: CGFloat = CGFloat(valeur("-progressPill") ?? 0)
    static let pillDx: CGFloat = CGFloat(valeur("-progressPill", 2) ?? 0)
    /// `-progressPillBas` : l'option B du fond — la pill qui PART DU BAS
    /// (`progress-pill-bas.mp4`, recuit `tools/progress/recuit_pill_bas.sh`).
    static let pillBas = CommandLine.arguments.contains("-progressPillBas")
    /// `-progressFaits <k>` : k séances faites cette semaine (dates
    /// inventées, stickers du modulo — la matière au banc).
    static let faits: Int? = valeur("-progressFaits").map { Int($0) }
    /// `-progressPrevus <n>` : l'objectif hebdo forcé.
    static let prevus: Int? = valeur("-progressPrevus").map { Int($0) }
    /// `-progressMois <±n>` : le mois affiché, relatif au courant.
    static let mois: Int = Int(valeur("-progressMois") ?? 0)
    /// `-progressFige <p>` : l'arrivée figée à p (0 → 1).
    static let fige: Double? = valeur("-progressFige")
    /// `-progressStory <jour>` : la story du jour <jour> du mois affiché
    /// s'ouvre seule 1,6 s après l'arrivée (le sim ne pose pas de doigt).
    static let story: Int? = valeur("-progressStory").map { Int($0) }
    /// `-progressLecteur` : l'iPod du mois affiché s'ouvre seul à 1,6 s.
    static let lecteur = CommandLine.arguments.contains("-progressLecteur")
    /// `-progressLevee <pt>` : la card tenue raccourcie de <pt> (l'école
    /// `-exosTirage` — le seed ne laisse aucune séance ouverte).
    static let levee: CGFloat? = valeur("-progressLevee").map { CGFloat($0) }
    /// Les A/B de CADENCE (`-fps`) : attribuer un coût, pas le deviner.
    /// `-progressSansBouton` retire le primaire (shader 30 Hz),
    /// `-progressSansVerre` met les deux ardoises en plaque peinte.
    static let sansBouton = CommandLine.arguments.contains("-progressSansBouton")
    static let sansVerre = CommandLine.arguments.contains("-progressSansVerre")
}

// MARK: - La page

struct ProgressPage: View {
    var onBack: () -> Void

    @Query(sort: \Workout.startedAt, order: .reverse)
    private var workoutsBruts: [Workout]
    /// La séance en cours est DÉRIVÉE de la base, jamais un drapeau.
    @Query(filter: #Predicate<Workout> { $0.endedAt == nil })
    private var seancesOuvertes: [Workout]
    /// L'objectif hebdo : LA MÊME clé que la home (le galet de l'objectif).
    @AppStorage(Goal.cleHebdo) private var objectif: Int = Goal.weeklyTarget

    /// L'ARRIVÉE — une seule horloge, 0 → 1 ; chaque composant en dérive sa
    /// fenêtre (rang × 0,12).
    @State private var arrivee: Double = ProgressBanc.fige ?? 0
    /// LE MOIS AFFICHÉ par le calendrier (la bascule ‹ › le change).
    @State private var monthAnchor: Date
    @State private var pushEdge: Edge = .trailing
    /// LES DONNÉES — calculées une fois à l'apparition et quand la base
    /// change, jamais relues par le corps.
    @State private var parJour: [Date: [Workout]] = [:]
    @State private var semaine: [SemaineJour] = []
    @State private var semaineSeances: [Workout] = []
    /// LES PORTES.
    @State private var story: CalStoryLaunch?
    @State private var flashDay: Date?
    @State private var moisOuvert: MoisLaunch?
    /// LA LEVÉE — reçue. En séance : fixe (la zone du player, à PageCard).
    @State private var levee: CGFloat = 0

    /// Lundi d'abord — la semaine de `SemaineStats` et de la grille.
    private let calendar: Calendar = {
        var c = Calendar.current
        c.firstWeekday = 2
        return c
    }()

    /// La zone dégagée en séance : la référence HOME (6 d'air · 76 de dalle ·
    /// 14), en attendant la cote définitive de PageCard.
    static let leveeSeance: CGFloat = 96

    init(onBack: @escaping () -> Void) {
        self.onBack = onBack
        let ancre = Calendar.current.date(byAdding: .month,
                                          value: ProgressBanc.mois,
                                          to: Date()) ?? Date()
        _monthAnchor = State(initialValue: ancre)
    }

    // MARK: Le corps

    var body: some View {
        GeometryReader { geo in
            let safeT = geo.safeAreaInsets.top
            let W = geo.size.width
            let hEcran = geo.size.height + safeT + geo.safeAreaInsets.bottom
            ZStack(alignment: .top) {
                // LA NUIT — ce qui reste quand la card se raccourcit.
                Color.black
                // LA CARD : le fond (feu + pill) puis l'encre, tous deux
                // découpés par la MÊME forme, animable sur la levée.
                fondCard(W: W, H: hEcran)
                    .clipShape(FormeCardExos(levee: levee,
                                             haut: GrandeCardExos.margeHaut))
                contenu(safeT: safeT, W: W)
                    .frame(width: W, height: hEcran, alignment: .top)
                    .clipShape(FormeCardExos(levee: levee,
                                             haut: GrandeCardExos.margeHaut))
                // LA STORY, DANS L'ARBRE (la loi de l'iPod : le cover imbriqué
                // ouvrait une ancienne fenêtre et coupait le titre).
                if let launch = story {
                    storyVue(launch)
                }
                // LA SONDE DU LAG (`-fps`) : un CADisplayLink qui compte les
                // battements servis et publie chaque seconde. Rien hors banc.
                if CommandLine.arguments.contains("-fps") {
                    SondeCadence(quoi: "progress")
                        .frame(width: 1, height: 1)
                        .allowsHitTesting(false)
                }
            }
            .ignoresSafeArea()
        }
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
        .onAppear {
            calcule()
            lancerArrivee()
            jouerBanc()
        }
        .onChange(of: workoutsBruts.count) { _, _ in calcule() }
        .onChange(of: seancesOuvertes.isEmpty, initial: true) { _, vide in
            // La levée de séance se joue dans une transaction : le @Query
            // arrive après la première image.
            withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.62)) {
                levee = ProgressBanc.levee ?? (vide ? 0 : Self.leveeSeance)
            }
        }
    }

    // MARK: Le fond — le feu et la pill

    /// Les lecteurs se taisent quand la page ne se voit plus (story ou iPod
    /// ouverts) : `rate: 0` — jamais un démontage.
    private var rateFond: Float { (story == nil && moisOuvert == nil) ? 1 : 0 }

    /// L'école exacte de la home (`DepartCine`) : un hôte NEUTRE qui prend la
    /// proposition, deux calques en `overlay` alignés (le feu au pied, la pill
    /// à mi-hauteur), l'additif, et UN SEUL groupe, en dernier — posé sur une
    /// seule couche il fusionnerait contre le noir et la pill occulterait le
    /// feu au lieu de s'y fondre.
    private func fondCard(W: CGFloat, H: CGFloat) -> some View {
        Color.black
            .overlay(
                Color.clear
                    .overlay(alignment: .bottom) { feu(W: W) }
                    .overlay(alignment: .top) { pill(W: W, H: H) }
                    .compositingGroup()
                    .padding(.top, GrandeCardExos.margeHaut)
                    // LA NAISSANCE de la card (l'école GrandeCardExos) : elle
                    // s'allume en fondu avec une approche imperceptible — vu
                    // au film, la pill claquait à l'écran avant l'encre.
                    .opacity(q(0))
                    .scaleEffect(1.015 - 0.015 * q(0))
            )
            .ignoresSafeArea()
    }

    /// LE FEU — `home-fond-flamme` (604 × 642), la nappe orange du pied de la
    /// maquette, collée par son arête basse à l'arête de la card, dans la
    /// boîte de la home (largeur × 330 : la cuisson est faite pour être
    /// coupée par le bas).
    private func feu(W: CGFloat) -> some View {
        CalqueVideo(nom: "home-fond-flamme",
                    pose: "home-fond-flamme-poster",
                    rate: rateFond)
            .frame(width: W, height: 330)
            .blendMode(.plusLighter)
    }

    /// LA PILL — option A : `story-pilule-droite` (1206 × 964 = 3 × la
    /// largeur d'écran ; tête à gauche, corps qui SORT à droite), centrée à
    /// 0,50 H, réglable au banc (`-progressPill <dy> <dx>`). Option B
    /// (`-progressPillBas`) : `progress-pill-bas` (1206 × 2592 = la card à
    /// 3×), la pill verticale qui part du bas, plein cadre.
    private func pill(W: CGFloat, H: CGFloat) -> some View {
        let bas = ProgressBanc.pillBas
        let h: CGFloat = bas ? W * 2592 / 1206 : W * 964 / 1206
        let top: CGFloat = bas ? 0
            : max(0, H * 0.50 - h / 2 + ProgressBanc.pillDy)
        return CalqueVideo(nom: bas ? "progress-pill-bas" : "story-pilule-droite",
                           pose: bas ? "progress-pill-bas-poster"
                                     : "story-pilule-droite-poster",
                           rate: rateFond)
            .frame(width: W, height: h)
            .padding(.top, top)
            .offset(x: bas ? 0 : ProgressBanc.pillDx)
            .blendMode(.plusLighter)
    }

    // MARK: L'encre — header, semaine, calendrier

    private func contenu(safeT: CGFloat, W: CGFloat) -> some View {
        let marge = (W - CalendrierMois.L) / 2
        return VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.top, safeT + 4)
            SemaineStrip(faits: semaine.count,
                         prevus: prevusAffiche,
                         arrivee: 0.70 + 0.30 * q(1),
                         onTap: ouvrirStoryMini,
                         lisere: true,
                         verre: !ProgressBanc.sansVerre,
                         jours: semaine,
                         videsVisibles: true,
                         jouet: false,
                         flou: rang(1))
                .padding(.top, 16)
                .padding(.leading, marge)
            CalendrierMois(anchor: monthAnchor,
                           calendar: calendar,
                           parJour: parJour,
                           flashDay: flashDay,
                           pushEdge: pushEdge,
                           flou: rang(2),
                           onStep: monthStep,
                           onAujourdhui: aujourdhui,
                           onDayTap: ouvrirStory,
                           onLecteur: ouvrirLecteur)
                .opacity(q(2))
                .offset(y: 9 * (1 - q(2)))
                .padding(.top, 14)
                .padding(.leading, marge)
            Spacer(minLength: 0)
        }
    }

    /// LE HEADER — la robe de « Rewards » : le chevron `ChipVerre` et le
    /// titre Inter-Bold 30, tracking −0,4, `titleFade`, sur la MÊME ligne, à
    /// la cote de `RangeeChips` (20 / safeTop + 4 — « la position du chevron
    /// ne bouge JAMAIS d'une page à l'autre »). Le titre arrive dans le flou
    /// (de l'encre) ; le chevron en opacité seule (du verre natif).
    private var header: some View {
        HStack(spacing: 14) {
            ChipVerre(symbole: "chevron.left", label: "Retour", action: onBack)
                .opacity(q(0))
                .offset(y: 9 * (1 - q(0)))
            Text("Progress")
                .font(.inter(30, .bold)).tracking(-0.4)
                .foregroundStyle(WoopGradient.titleFade)
                .modifier(ArriveeFloue(p: rang(0), rang: 0))
                .allowsHitTesting(false)
            Spacer()
        }
        .padding(.horizontal, 20)
        // Sourd tant que l'arrivée n'a pas passé 0,6 (l'école enTeteBac).
        .allowsHitTesting(arrivee > 0.6)
    }

    // MARK: L'arrivée

    /// L'avancement du composant de rang `i` (le retard de la cascade).
    private func rang(_ i: Int) -> Double { arrivee - 0.12 * Double(i) }
    /// Le même, clampé sur la course d'`ArriveeFloue` (0,62).
    private func q(_ i: Int) -> Double { min(max(rang(i) / 0.62, 0), 1) }

    /// Le tempo de « Rewards » (linéaire, un retard court) — sa page, sa
    /// robe. Une fois : le retour d'onglet ne rejoue pas la cinématique.
    private func lancerArrivee() {
        guard ProgressBanc.fige == nil, arrivee < 1 else { return }
        withAnimation(.linear(duration: 1.0).delay(0.18)) { arrivee = 1 }
    }

    /// Les portes jouées seules, pour le banc : la story d'un jour
    /// (`-progressStory <jour>`, sans rect — le filet de StoryPortal), ou
    /// l'iPod du mois (`-progressLecteur`, sans portail).
    private func jouerBanc() {
        guard ProgressBanc.story != nil || ProgressBanc.lecteur else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(1600))
            // ⚠️ Pas `date(bySetting: .day, …)` : sur le 30 il AVANCE au 21
            // du mois suivant (payé au banc : story muette).
            if let j = ProgressBanc.story {
                var c = calendar.dateComponents([.year, .month], from: monthAnchor)
                c.day = j
                if let day = calendar.date(from: c) {
                    ouvrirStory(day: calendar.startOfDay(for: day), rect: .zero)
                }
            } else if ProgressBanc.lecteur {
                ouvrirLecteur(rect: .zero)
            }
        }
    }

    // MARK: Les données — une fois

    private var prevusAffiche: Int { ProgressBanc.prevus ?? objectif }

    /// Les séances FINIES, rangées au jour de `startedAt` (la définition du
    /// calendrier et de `SemaineStats`) ; la semaine courante lundi → dimanche,
    /// en ordre chronologique.
    private func calcule() {
        let finies = workoutsBruts.filter { !$0.isActive }
        parJour = Dictionary(grouping: finies) {
            calendar.startOfDay(for: $0.startedAt)
        }
        if let k = ProgressBanc.faits {
            semaineSeances = []
            semaine = (0..<k).map { i in
                SemaineJour(date: calendar.date(byAdding: .day,
                                                value: -(k - 1 - i),
                                                to: Date()) ?? Date(),
                            sticker: SemaineStrip.sticker(i))
            }
            return
        }
        guard let sem = calendar.dateInterval(of: .weekOfYear, for: Date())
        else { return }
        let cette = finies
            .filter { sem.contains($0.startedAt) }
            .sorted { $0.startedAt < $1.startedAt }
        // UNE MINI PAR JOUR — une semaine a sept places (mesuré au banc : la
        // démo sème neuf séances, et neuf minis à pas 30 ne se lisent plus).
        // Deux séances le même jour partagent la place : la première porte
        // la story, le calendrier dit le ×2.
        var vus: Set<Date> = []
        let parJourSemaine = cette.filter {
            vus.insert(calendar.startOfDay(for: $0.startedAt)).inserted
        }
        semaineSeances = parJourSemaine
        semaine = parJourSemaine.map {
            SemaineJour(date: $0.startedAt, sticker: WoopSticker.pour($0).asset)
        }
    }

    // MARK: Le mois

    private func monthStep(_ dir: Int) {
        pushEdge = dir > 0 ? .trailing : .leading
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            monthAnchor = calendar.date(byAdding: .month, value: dir,
                                        to: monthAnchor) ?? monthAnchor
        }
    }

    private func aujourdhui() {
        pushEdge = monthAnchor < Date() ? .trailing : .leading
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            monthAnchor = Date()
        }
    }

    // MARK: Les portes — la story

    /// Le tap d'un jour entraîné : flash 140 ms, puis le portail depuis le
    /// rect de la case, sur la VRAIE séance (`StorySession(workout:)`).
    private func ouvrirStory(day: Date, rect: CGRect) {
        guard story == nil,
              let w = parJour[calendar.startOfDay(for: day)]?.first
        else { return }
        lancerStory(w, rect: rect, flash: day)
    }

    /// Le tap d'une mini faite de « This week » : la même story, pour la
    /// séance de ce rang. (Le rect viendra avec la mini qui saura le dire ;
    /// sans lui, StoryPortal ouvre depuis sa carte centrale.)
    private func ouvrirStoryMini(_ i: Int) {
        guard story == nil, i < semaineSeances.count else { return }
        lancerStory(semaineSeances[i], rect: .zero, flash: nil)
    }

    private func lancerStory(_ w: Workout, rect: CGRect, flash: Date?) {
        flashDay = flash
        Task {
            try? await Task.sleep(for: .milliseconds(140))
            story = CalStoryLaunch(rect: rect, session: StorySession(workout: w))
            try? await Task.sleep(for: .milliseconds(500))
            withAnimation(.easeOut(duration: 0.4)) { flashDay = nil }
        }
    }

    private func storyVue(_ launch: CalStoryLaunch) -> some View {
        StoryPortal(from: launch.rect,
                    fromRadius: CalendrierMois.sFull * 0.28,
                    session: launch.session) {
            story = nil
        }
        .zIndex(10)
    }

    // MARK: Les portes — le lecteur

    /// « Voir dans le lecteur » : l'iPod sur le MOIS AFFICHÉ, portail depuis
    /// le bouton, le mois précédent pour sa phrase de comparaison. Jamais sur
    /// un mois vide (le bouton n'existe alors pas — et `jouer()` n'indexe
    /// plus un tableau vide).
    private func ouvrirLecteur(rect: CGRect) {
        guard moisOuvert == nil,
              let m = moisLecteur(anchor: monthAnchor),
              !m.sessions.isEmpty
        else { return }
        let prec = calendar.date(byAdding: .month, value: -1, to: monthAnchor)
            .flatMap { moisLecteur(anchor: $0) }
        var tx = Transaction()
        tx.disablesAnimations = true
        withTransaction(tx) {
            moisOuvert = MoisLaunch(
                month: m, rect: rect,
                precedentNom: prec?.titre(calendar: calendar),
                precedentCompte: prec?.count,
                precedentReps: prec.map { p in
                    p.sessions.reduce(0) { $0 + $1.reps }
                })
        }
    }

    /// Le mois du lecteur, bâti sur les vraies séances (récentes → anciennes,
    /// l'ordre que l'iPod suppose).
    private func moisLecteur(anchor: Date) -> DemoMonth? {
        guard let debut = calendar.dateInterval(of: .month, for: anchor)?.start
        else { return nil }
        let seances = parJour
            .filter { calendar.isDate($0.key, equalTo: debut,
                                      toGranularity: .month) }
            .values.flatMap { $0 }
            .sorted { $0.startedAt > $1.startedAt }
        return DemoMonth(start: debut,
                         sessions: seances.map {
                             DemoSession.depuis($0, calendar: calendar)
                         })
    }
}

// MARK: - La card calendrier

/// La grille du mois, FIXE et dépliée — l'état `p = 1` de `CardMorph` sans sa
/// mécanique (le morph semaine ↔ mois, le curseur de scroll, la console). Les
/// briques pures viennent de CalLab : `CalSlot.month(of:)` pour les cases,
/// `StickerDayCell` pour leur dessin, les cotes `padFull 14 / gapFull 6`.
/// SIX rangées toujours : la card ne change pas de taille d'un mois à l'autre
/// (rien ne saute au ‹ ›).
struct CalendrierMois: View {
    let anchor: Date
    let calendar: Calendar
    let parJour: [Date: [Workout]]
    let flashDay: Date?
    let pushEdge: Edge
    var flou: Double = 1
    var onStep: (Int) -> Void
    var onAujourdhui: () -> Void
    var onDayTap: (Date, CGRect) -> Void
    var onLecteur: (CGRect) -> Void

    /// Le rect ÉCRAN du bouton — le portail de l'iPod part de là.
    @State private var rectBouton: CGRect = .zero

    // LA CHAÎNE DE COTES (plan §9).
    static let L: CGFloat = 354
    static let padFull: CGFloat = 14
    static let gapFull: CGFloat = 6
    static var sFull: CGFloat { (L - 2 * padFull - 6 * gapFull) / 7 }
    static let yTitre: CGFloat = 16
    static let yChips: CGFloat = 16 + 44 + 12
    static let yGrille: CGFloat = 16 + 44 + 12 + 22 + 12
    static var hGrille: CGFloat { 6 * sFull + 5 * gapFull }
    static var yBouton: CGFloat { yGrille + hGrille + 16 }
    static var H: CGFloat { yBouton + 58 + 18 }

    private var slots: [CalSlot] { CalSlot.month(of: anchor, calendar: calendar) }
    private var estCourant: Bool {
        calendar.isDate(anchor, equalTo: Date(), toGranularity: .month)
    }
    /// « Août 2026 » — l'année toujours (la maquette).
    private var titre: String {
        anchor.formatted(.dateTime.month(.wide).year()).capitalized
    }
    private var seancesDuMois: Int {
        parJour.reduce(0) { acc, kv in
            calendar.isDate(kv.key, equalTo: anchor, toGranularity: .month)
                ? acc + kv.value.count : acc
        }
    }
    /// La colonne d'aujourd'hui (lundi = 0).
    private var colAujourdhui: Int {
        (calendar.component(.weekday, from: Date()) - calendar.firstWeekday + 7) % 7
    }
    /// LUN … DIM — les trois lettres des symboles courts, depuis lundi.
    private var tetes: [String] {
        let syms = calendar.shortStandaloneWeekdaySymbols
        let d = calendar.firstWeekday - 1
        return (0..<7).map {
            String(syms[($0 + d) % 7].prefix(3)).uppercased()
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // LA COQUILLE — la même matière que « This week » : une seule
            // ardoise pour deux cards. Le verre est NOURRI par la pill.
            ArdoiseFond(largeur: Self.L, hauteur: Self.H, rayon: 26,
                        verre: !ProgressBanc.sansVerre, lisere: true)
            encre
                .modifier(ArriveeFloue(p: flou, rang: 0))
        }
        .frame(width: Self.L, height: Self.H)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var encre: some View {
        ZStack(alignment: .topLeading) {
            rangeeTitre
                .frame(width: Self.L, height: 44)
                .offset(y: Self.yTitre)
            capsules
                .offset(y: Self.yChips)
            grille
                .offset(y: Self.yGrille)
            if seancesDuMois > 0, !ProgressBanc.sansBouton {
                bouton
                    .offset(y: Self.yBouton)
            }
        }
    }

    /// Le titre au registre de « This week. » (Inter 20 semibold) ; à droite,
    /// « Aujourd'hui » quand le mois n'est pas le courant, puis ‹ ›.
    private var rangeeTitre: some View {
        HStack(spacing: 6) {
            Text(titre)
                .font(.inter(20, .semibold))
                .foregroundStyle(.white.opacity(0.94))
            Spacer(minLength: 0)
            if !estCourant {
                chipAujourdhui
            }
            nav("chevron.left", step: -1)
            nav("chevron.right", step: 1)
        }
        .padding(.leading, 22)
        .padding(.trailing, 12)
    }

    private var chipAujourdhui: some View {
        Text("Aujourd'hui")
            .font(.inter(12, .semibold))
            .foregroundStyle(.white.opacity(0.90))
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(Capsule().fill(.white.opacity(0.10)))
            .contentShape(Capsule())
            .highPriorityGesture(TapGesture().onEnded { onAujourdhui() })
    }

    /// ‹ › — pas des `Button` : sous le drag d'un ancêtre ils seraient
    /// annulés à 2 pt. `contentShape` + tap en priorité haute.
    private func nav(_ symbole: String, step: Int) -> some View {
        Image(systemName: symbole)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white.opacity(0.90))
            .frame(width: 36, height: 36)
            .background(Circle().fill(.white.opacity(0.07)))
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .highPriorityGesture(TapGesture().onEnded { onStep(step) })
    }

    /// Les sept capsules LUN … DIM ; celle d'aujourd'hui allumée, le point
    /// rouge au-dessus (la grammaire de la grille d'origine).
    private var capsules: some View {
        HStack(spacing: Self.gapFull) {
            ForEach(0..<7, id: \.self) { i in
                capsule(i)
            }
        }
        .padding(.leading, Self.padFull)
    }

    private func capsule(_ i: Int) -> some View {
        let actif = estCourant && i == colAujourdhui
        return Text(tetes[i])
            .font(.system(size: 9, weight: .semibold))
            .tracking(1)
            .foregroundStyle(actif ? .white.opacity(0.94) : CardTon.encreDouce)
            .frame(width: Self.sFull, height: 22)
            .background(Capsule().fill(.white.opacity(actif ? 0.16 : 0.07)))
            .overlay(alignment: .top) {
                if actif {
                    Circle()
                        .fill(FlammePalette.flamme)
                        .frame(width: 4, height: 4)
                        .offset(y: -8)
                }
            }
    }

    /// La grille : les cases en `.position`, six rangées de haut ; le
    /// changement de mois est une transition `push` sur l'identité du titre.
    private var grille: some View {
        ZStack(alignment: .topLeading) {
            ForEach(slots) { slot in
                caseJour(slot)
            }
        }
        .frame(width: Self.L, height: Self.hGrille, alignment: .topLeading)
        .id(titre)
        .transition(.push(from: pushEdge).combined(with: .opacity))
    }

    private func caseJour(_ slot: CalSlot) -> some View {
        let s = Self.sFull
        let seances = parJour[calendar.startOfDay(for: slot.day)] ?? []
        let cat: WoopSticker? = seances.first.map { WoopSticker.pour($0) }
        let flash = flashDay.map { calendar.isDate($0, inSameDayAs: slot.day) }
            ?? false
        let tap: ((CGRect) -> Void)? = seances.isEmpty
            ? nil : { r in onDayTap(slot.day, r) }
        return StickerDayCell(day: slot.day, size: s,
                              isToday: calendar.isDateInToday(slot.day),
                              calendar: calendar,
                              flashing: flash,
                              onTap: tap,
                              jour: JourCase(categorie: cat,
                                             double: seances.count >= 2))
            .position(x: Self.padFull + CGFloat(slot.col) * (s + Self.gapFull)
                          + s / 2,
                      y: CGFloat(slot.row) * (s + Self.gapFull) + s / 2)
    }

    /// LE PRIMAIRE de la maison, 58 de haut, à 26 des bords de la card.
    private var bouton: some View {
        DiamondPrimaryButton(title: "Voir dans le lecteur",
                             smokeWarmth: 0.55) {
            onLecteur(rectBouton)
        }
        .padding(.horizontal, 26)
        .frame(width: Self.L)
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: { rectBouton = $0 }
    }
}

// MARK: - Le sticker d'une séance — UNE fonction pour les trois écrans

extension WoopSticker {
    /// La catégorie DOMINANTE (la première de `Workout.categories`) → le
    /// sticker, au mapping tranché le 26-08 : bras = haut, chocolat = abdos,
    /// jambes = bas, abricot = fessiers, basket = cardio. Sans catégorie : la
    /// flamme seule. (La nage n'existe pas dans le modèle — `piscine` reste
    /// à la story.)
    static func pour(_ w: Workout) -> WoopSticker {
        switch w.categories.first {
        case .haut: return .bras
        case .abdos: return .chocolat
        case .bas: return .jambes
        case .fessiers: return .abricot
        case .cardio: return .basket
        case nil: return .flamme
        }
    }
}

extension DemoSession {
    /// Une séance RÉELLE dans la robe de l'iPod : le sticker par la
    /// catégorie, les séries FAITES (la définition qui paie), les reps
    /// cochées, et le `Workout` gardé pour la story et la partition.
    static func depuis(_ w: Workout, calendar: Calendar) -> DemoSession {
        let jour = w.startedAt
        let n = calendar.component(.day, from: jour)
        let label = jour.formatted(.dateTime.weekday(.abbreviated))
            .replacingOccurrences(of: ".", with: "")
            .prefix(3).uppercased()
        let reps = w.orderedExercises
            .flatMap(\.orderedSets)
            .filter(\.isDone)
            .reduce(0) { $0 + $1.reps }
        return DemoSession(date: jour,
                           cat: WoopSticker.pour(w),
                           series: w.seriesPayantes,
                           reps: reps,
                           weekdayLabel: String(label),
                           dayNumber: n,
                           workout: w)
    }
}
