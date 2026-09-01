import SwiftUI
import SwiftData

// MARK: - PlayerMonde — LE player global, unique, à la racine (§3)

/// L'ÉTAT DU PLAYER — un singleton @Observable (§3.1) : la dalle de
/// chaque page appelle `ouvrir()`, les gestes du player appellent
/// `fermer()`. `p` est POSSÉDÉ (§3.4decies F1) : les vols sont un
/// tween maison, le suivi une écriture sèche — un seul propriétaire,
/// jamais d'écart modèle/écran.
@Observable
final class PlayerEtat {
    static let shared = PlayerEtat()
    private init() {}

    /// 0 fermé → 1 ouvert. Les slots (scène, pied) en sont fonctions.
    var p: CGFloat = 0
    /// L'intention (le spring anime `p` vers elle).
    var ouvert = false
    /// Le corps reste MONTÉ tant que l'animation vit (jamais un
    /// `if` qui démonte en plein vol).
    var monte = false

    /// §3.4septies F2 : LE PLAYER COUVRE — les lecteurs vidéo des pages
    /// se taisent (le pattern rateFond : « les lecteurs se taisent quand
    /// la page ne se voit plus »). Un Bool séparé de `p` : deux flips
    /// par geste, jamais une écriture par frame.
    var couvre = false
    /// §3.4octies : POSÉ COMPLET — le verre natif et le mask des fondus
    /// ne vivent que là (la loi : un verre aux bounds vivants =
    /// 60 → 14 img/s) ; en vol/suivi, la doublure mate.
    var poseComplet = false
    /// La hauteur de course du vol (l'écran physique), posée par l'hôte.
    var hauteurCourse: CGFloat = 852
    /// LE TEMPO UNIQUE (§3.4quinquies, verdicts 01-09 : « l'animation va
    /// trop vite » · « la fermeture plus rapide ?? ») : ouverture ET
    /// fermeture au MÊME souffle.
    static let tempo: Double = 0.68

    // §3.4decies F1 : `p` est POSSÉDÉ. Plus AUCUN `withAnimation` sur
    // lui — les vols sont un tween maison (CADisplayLink) qui avance
    // le MODÈLE frame par frame : la valeur du modèle EST la valeur à
    // l'écran, à chaque instant. La saisie en plein vol lit donc un
    // `p` exact (l'ancre est juste), et le suivi s'écrit SEC, collé au
    // doigt — le spring de poursuite (~0,15 s de retard permanent) est
    // mort avec le claquement de reprise qu'il compensait.

    /// Le vol en cours (tween actif). Avec `enSuivi`, il fige le
    /// contenu en bloc.
    private(set) var enVol = false
    /// TOUT MOUVEMENT fige le contenu en BLOC (Apple Music : on tire,
    /// tout descend d'un bloc) : pendant lui, seuls le voile et
    /// l'offset relisent `p` par frame.
    var enMouvement: Bool { enSuivi || enVol }
    private let moteur = MoteurVol()

    func ouvrir() {
        guard !ouvert else { return }
        // FLUIDITÉ (S1' + §3.4quater, payé au juge du vol) : le CADRE est
        // toujours rendu, le contenu lourd NAÎT D'ABORD hors écran
        // (jamais pendant le film) — le premier pas du tween tombe au
        // tick d'écran SUIVANT, sur un arbre déjà construit.
        monte = true
        couvre = true
        ouvert = true
        poseComplet = false
        volVers(1, duree: Self.tempo, courbe: .doux) {
            self.poser()
        }
    }

    /// §3.4terdecies (verdict : « à la fin il bug un peu à
    /// s'afficher ») : la POSE se fait en FONDU court — le verre, le
    /// mask des fondus et le badge naissaient d'UN COUP à la fin du
    /// vol. Le DÉPART de geste, lui, reste SEC (la loi du verre aux
    /// bounds vivants : il se retire avant que ça bouge).
    private func poser() {
        withAnimation(.easeInOut(duration: 0.22)) {
            poseComplet = true
        }
    }

    func fermer() {
        guard ouvert || p > 0 else { return }
        poseComplet = false
        enSuivi = false
        ouvert = false
        volVers(0, duree: Self.tempo, courbe: .doux) {
            // Le démontage APRÈS le vol — un `ouvrir()` pendant la
            // descente REMPLACE le vol : cette fin ne tombe jamais.
            self.monte = false
            self.couvre = false
        }
    }

    /// LE TWEEN : un pas par frame d'écran, courbe à la main. La fin
    /// (`fini`) ne tombe QUE si le vol va au bout — toute nouvelle
    /// transition (vol ou saisie) l'écrase ; plus aucun jeton à
    /// compter.
    private func volVers(_ cible: CGFloat, duree: Double,
                         courbe: Courbe, fini: @escaping () -> Void) {
        let depart = p
        guard abs(cible - depart) > 0.0005 else {
            moteur.arreter()
            enVol = false
            p = cible
            fini()
            return
        }
        enVol = true
        let t0 = CACurrentMediaTime()
        moteur.demarrer { [weak self] maintenant in
            guard let self else { return }
            let t = min(max((maintenant - t0) / duree, 0), 1)
            let vise = depart
                + (cible - depart) * CGFloat(Self.easer(t, courbe))
            // §3.4decies : LE PAS BORNÉ. Sous famine (sim chargé), le
            // temps file plus vite que les frames rendues : un pas au
            // temps non borné TÉLÉPORTE (mesuré au film : 55 % de
            // l'amplitude en UNE frame). Borné, le vol s'ALLONGE au
            // lieu de sauter ; à cadence pleine la borne (0,08 de
            // course) reste au-dessus de la pente crête légitime
            // (easeOut ×3 sur 13 frames ≈ 0,074) : elle ne mord pas.
            let pas = vise - self.p
            if abs(pas) > 0.08 {
                self.p += pas > 0 ? 0.08 : -0.08
            } else {
                self.p = vise
            }
            if t >= 1, self.p == cible {
                self.moteur.arreter()
                self.enVol = false
                fini()
            }
        }
    }

    /// Les deux courbes de la maison — `doux` (easeInOut) pour les
    /// vols francs, `sortie` (easeOut) pour la fin d'un relâcher.
    enum Courbe { case doux, sortie }

    private static func easer(_ t: Double, _ c: Courbe) -> Double {
        switch c {
        case .doux: return t * t * (3 - 2 * t)
        case .sortie: return 1 - pow(1 - t, 3)
        }
    }

    // MARK: LE SUIVI AU DOIGT (§3.4quinquies : « l'overlay s'affiche
    // AVEC LA GESTUELLE ») — le doigt porte p, le relâcher COMMET avec
    // l'élan. La page derrière ne bouge toujours jamais.

    /// LE SUIVI EN COURS — pendant lui, le contenu du player est FIGÉ
    /// EN BLOC (Apple Music : on tire, tout descend d'un bloc, rien ne
    /// « dévole ») : seuls l'offset du corps et le voile écoutent p.
    var enSuivi = false
    /// L'état d'où le geste est parti — les seuils de commit sont
    /// ASYMÉTRIQUES (depuis ouvert, une descente modeste ferme).
    private var origineOuverte = false

    /// La prise : le contenu naît immédiatement (pré-montage), et tout
    /// vol en cours S'ARRÊTE LÀ OÙ IL EST — `p` étant possédé, la
    /// valeur saisie est EXACTEMENT celle de l'écran (le claquement de
    /// reprise est mort à la racine, §3.4decies F1).
    func saisir() {
        moteur.arreter()
        enVol = false
        origineOuverte = ouvert
        pAncre = p
        enSuivi = true
        monte = true
        couvre = true
        poseComplet = false
        #if DEBUG
        if CommandLine.arguments.contains("-gesteSonde") {
            print("GESTE-SONDE player SAISIR p=\(String(format: "%.3f", p))")
        }
        #endif
    }

    /// L'ancre du geste — le suivi est RELATIF (§3.4nonies : le suivi
    /// absolu faisait sauter p au premier événement).
    private var pAncre: CGFloat = 0

    /// Le doigt parle en DELTA (points d'écran, positif = vers le
    /// haut) : `p` s'écrit SEC — pas de spring, pas de retard, le
    /// player est collé au doigt (§3.4decies F1 : l'ancre étant
    /// exacte, il n'y a plus rien à rattraper). Le CHIEN DE GARDE est
    /// réarmé à chaque frame : un geste mort sans `onEnded` (pointeur
    /// perdu, présentation) COMMET au plus proche — jamais un player
    /// abandonné à mi-vol (la loi de la maison).
    func suivreDelta(_ delta: CGFloat) {
        if !enSuivi {
            saisir()
            armerChienSuivi()
        }
        let brut = pAncre + delta / hauteurCourse
        // §3.4duodecies : LES BUTÉES VIVENT — au-delà de [0, 1] la
        // sur-course est ÉLASTIQUE (tanh, ≤ 5 % de course) : le doigt
        // sent une butée qui répond, pas un mur mort ; le relâcher
        // revient à la borne par le vol de `commettre`.
        if brut > 1 {
            p = 1 + 0.05 * tanh((brut - 1) * 6)
        } else if brut < 0 {
            p = 0.05 * tanh(brut * 6)
        } else {
            p = brut
        }
        // §3.4octies : le chien lit une HORLOGE — plus aucun minuteur
        // posé/annulé par frame.
        derniereFrame = CACurrentMediaTime()
    }

    private var derniereFrame: Double = 0

    /// Le chien du suivi : UN minuteur périodique tant que le geste vit ;
    /// 0,4 s sans frame = le geste est mort, on COMMET.
    private func armerChienSuivi() {
        derniereFrame = CACurrentMediaTime()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            [weak self] in
            guard let self, self.enSuivi else { return }
            if CACurrentMediaTime() - self.derniereFrame > 0.4 {
                self.commettre(velocite: 0)
            } else {
                self.armerChienSuivi()
            }
        }
    }

    private var chienJeton = 0

    /// Le relâcher : l'intention se lit à l'ÉLAN puis à la position ; la
    /// fin de course est PROPORTIONNELLE au chemin restant (bornée) —
    /// jamais un claquement, jamais une traîne.
    func commettre(velocite: CGFloat) {
        #if DEBUG
        if CommandLine.arguments.contains("-gesteSonde") {
            print("GESTE-SONDE player COMMETTRE v=\(Int(velocite)) "
                + "p=\(String(format: "%.3f", p))")
        }
        #endif
        enSuivi = false
        // §3.4decies F3 : l'élan ne décide qu'à partir de 450 pt/s
        // (l'ordre de grandeur UIKit) — à 150, un drag même LENT
        // partait « à fond d'un coup » (le « quand j'effleure, bim »).
        // En dessous, c'est la POSITION qui décide, ASYMÉTRIQUE :
        // depuis ouvert, descendre de 20 % de course suffit à fermer
        // (le « j'ai du mal à le baisser »).
        let cible: CGFloat = velocite < -450 ? 1
            : velocite > 450 ? 0
            : origineOuverte ? (p < 0.8 ? 0 : 1)
            : (p > 0.2 ? 1 : 0)
        ouvert = cible == 1
        poseComplet = false
        // §3.4duodecies : LA FIN DE COURSE CONTINUE LA VITESSE DU
        // DOIGT. La pente initiale d'un easeOut cubique vaut
        // 3·distance/durée : durée = 3·distance/v PROLONGE exactement
        // la vitesse du relâcher — elle jette, ça file ; elle pose,
        // ça se pose. Sans élan aligné, le tempo proportionnel.
        let distance = Double(abs(cible - p))
        let vP = Double(abs(velocite)) / Double(max(hauteurCourse, 1))
        let aligne = (cible > p && velocite < 0)
            || (cible < p && velocite > 0)
        let duree: Double = (aligne && vP > 0.35)
            ? min(max(3 * distance / vP, 0.14), Self.tempo)
            : min(max(distance * Self.tempo, 0.22), Self.tempo)
        volVers(cible, duree: duree, courbe: .sortie) {
            if cible == 1 {
                self.poser()
            } else {
                self.monte = false
                self.couvre = false
            }
        }
    }
}

/// LE MOTEUR DU VOL (§3.4decies F1) — le CADisplayLink qui fait
/// avancer `p` d'un pas par frame d'écran. Un NSObject minuscule : le
/// lien RETIENT sa cible, `arreter()` invalide et libère tout. Mode
/// `.common` : le pas tombe aussi pendant un tracking.
private final class MoteurVol: NSObject {
    private var lien: CADisplayLink?
    private var pas: ((Double) -> Void)?

    func demarrer(_ pas: @escaping (Double) -> Void) {
        arreter()
        self.pas = pas
        let l = CADisplayLink(target: self, selector: #selector(tick(_:)))
        l.add(to: .main, forMode: .common)
        lien = l
    }

    @objc private func tick(_ l: CADisplayLink) {
        pas?(l.targetTimestamp)
    }

    func arreter() {
        lien?.invalidate()
        lien = nil
        pas = nil
    }
}

/// L'HÔTE — monté UNE fois dans le ZStack racine (`mainBody`),
/// zIndex 8,5 : au-dessus des pages et des pop-ups de jeu, sous les
/// annonces et la StopCard. La page derrière ne bouge JAMAIS : un
/// voile, un corps qui monte, rien d'autre.
struct PlayerMondeHote: View {
    /// La séance active (la racine la connaît déjà).
    var seance: Workout?
    /// « Page exercices » : la racine navigue (l'onglet), le player
    /// se ferme.
    var onPageExercices: () -> Void = {}

    @State private var etat = PlayerEtat.shared
    @State private var deplies: Set<String> = ["courant"]
    @State private var groupes: [SlateGroupe] = []
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GeometryReader { g in
            // §3.4septies F1 : le cadre ET le contenu vivent dès la
            // séance — INERTES (badge/comète ne respirent que posés) :
            // un arbre statique offscreen ne coûte rien, le « rideau »
            // ne brûlait que par ses animations continues. La naissance
            // SORT du geste : le drag ne paie plus rien.
            if seance != nil || etat.monte {
                let W = g.size.width
                let Hs = g.size.height
                let safeTop = g.safeAreaInsets.top
                let safeBottom = g.safeAreaInsets.bottom
                ZStack {
                    // LE VOILE — sa propre petite vue : elle SEULE
                    // s'invalide quand p bouge par frame (la loi n° 6).
                    // §3.4duodecies (rafale : « 20 fois d'affilée ça
                    // bug ») : le voile reste BOUCLIER dès le vol
                    // (rien ne traverse vers la page), mais il ne
                    // FERME qu'au POSÉ — en vol, un tap parasite de la
                    // rafale fermait le player par surprise.
                    VoilePlayer(onTap: { etat.fermer() },
                                actif: etat.ouvert)
                    // LE CORPS — l'offset vit dans un MODIFIER qui seul
                    // relit p : l'arbre du corps n'est pas ré-évalué
                    // par frame pendant le suivi.
                    corps(W: W, safeTop: safeTop)
                        .frame(width: W, height: Hs)
                        .modifier(OffsetVol(
                            course: Hs + safeTop + safeBottom))
                        .allowsHitTesting(etat.ouvert)
                }
            }
        }
        // La COURSE du vol (l'écran physique) — posée HORS render.
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height + proxy.safeAreaInsets.top
                + proxy.safeAreaInsets.bottom
        } action: { h in
            if h > 100 { etat.hauteurCourse = h }
        }
        // La séance meurt (stop validé) → le player se range seul.
        .onChange(of: seance == nil) { _, mort in
            if mort { etat.fermer() }
        }
        // Les groupes : UNE visite par MONTAGE (avant le vol — la
        // partition naît pleine, hors écran, jamais pendant le film).
        .onChange(of: etat.monte) { _, monte in
            if monte { groupes = groupesSeance() }
        }
        .task { await bancCycle() }
        .task { await bancDoigt() }
        .onAppear {
            if CommandLine.arguments.contains("-playerOuvert") {
                etat.monte = true
                etat.ouvert = true
                etat.p = 1
                etat.poseComplet = true
            }
        }
    }

    // MARK: le corps

    private func corps(W: CGFloat, safeTop: CGFloat) -> some View {
        ZStack(alignment: .top) {
            // Le fond : noir pur (D/F), coins hauts 30 qui ne se
            // voient qu'en vol (posé, il couvre tout le châssis).
            UnevenRoundedRectangle(
                topLeadingRadius: 30, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 30,
                style: .continuous)
                .fill(Color.black)
                .ignoresSafeArea()
                // §3.4duodecies : la JUPE — la sur-course élastique
                // (p > 1) monte le corps au-delà du châssis ; sans ce
                // débord noir de 80 pt, la page réapparaîtrait par le
                // bas pendant l'étirement.
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: 80)
                        .offset(y: 80)
                        .allowsHitTesting(false)
                }
            // LE CONTENU — pré-monté avec le cadre (F1), inerte hors
            // posé.
            if seance != nil || etat.monte {
            VStack(spacing: 0) {
                // Le cadre du corps est en zone sûre : le trait vit
                // déjà sous la status bar.
                Capsule()
                    .fill(Color.white.opacity(0.28))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)
                // §3.4quinquies + §3.4decies : EN MOUVEMENT (suivi OU
                // vol du tween) le contenu est FIGÉ à l'état posé (le
                // ternaire ne LIT `p` qu'à l'arrêt — zéro invalidation
                // par frame : seuls voile et offset suivent). Le flick de
                // la partition est MORT : il entrait en collision avec
                // le header suivi (le glitch) — un seul chemin de
                // fermeture au geste.
                ScenePlayer(levee: etat.enMouvement ? 1 : etat.p,
                            titre: titreCourant,
                            groupes: groupes, deplies: $deplies,
                            pose: etat.poseComplet)
                    .frame(maxWidth: .infinity, maxHeight: .infinity,
                           alignment: .top)
                    #if DEBUG
                    .background {
                        if CommandLine.arguments.contains("-gesteSonde") {
                            SondeGestePan()
                        }
                    }
                    #endif
            }
            // LE SPOTLIGHT — la lumière du sommet, jusqu'au châssis.
            .overlay(alignment: .top) {
                RadialGradient(
                    stops: [
                        .init(color: Color.white.opacity(0.12),
                              location: 0),
                        .init(color: Color.white.opacity(0.04),
                              location: 0.45),
                        .init(color: .clear, location: 1),
                    ],
                    center: UnitPoint(x: 0.5, y: 0.0),
                    startRadius: 0, endRadius: 460)
                .frame(height: 340 + safeTop)
                .blendMode(.plusLighter)
                .opacity(Double(etat.enMouvement ? 1 : etat.p))
                .allowsHitTesting(false)
                .ignoresSafeArea(edges: .top)
            }
            // §3.4undecies B1/B2 : LA PRISE DU CORPS N'EST PLUS UN
            // DragGesture SwiftUI (dix itérations : il perdait le
            // doigt quelque part entre le ScrollView et lui) — c'est
            // le PAN MAÎTRE UIKit, accroché à la FENÊTRE, qui possède
            // TOUT drag net vers le bas quand le player est ouvert
            // (voir `PanMaitre` en fin de fichier). Ici ne reste que
            // son point d'accrochage.
            .background { PanMaitre() }
            // LA SONDE (`-fps`) : les img/s RÉELLES pendant SES drags.
            .overlay(alignment: .topTrailing) {
                if CommandLine.arguments.contains("-fps") {
                    SondeCadence(quoi: "player")
                        .frame(width: 1, height: 1)
                        .allowsHitTesting(false)
                }
            }
            // LE PIED — le héros, le stop, « Page exercices ».
            .overlay(alignment: .bottom) {
                PiedPlayer(levee: etat.enMouvement ? 1 : etat.p,
                           pose: etat.poseComplet,
                           jour: seance?.startedAt ?? .now,
                           sticker: "sticker-flamme",
                           setsFaits: setsFaits,
                           stopActif: true,
                           onStop: {
                               withAnimation(.spring(response: 0.42,
                                                     dampingFraction:
                                                        0.86)) {
                                   DepartEtat.shared.pauseOuverte = true
                               }
                           },
                           pageExosActif: true,
                           onPageExercices: {
                               etat.fermer()
                               onPageExercices()
                           })
            }
            }
        }
    }

    // MARK: les données (LA SÉANCE, pas une fiche)

    /// L'exercice COURANT : le premier non terminé de la séance
    /// (v1 §3.1), sinon le dernier.
    private var exoCourant: (exo: Exercise, ligne: LoggedExercise)? {
        let lignes = seance?.orderedExercises ?? []
        for le in lignes where !le.orderedSets.allSatisfy(\.isDone) {
            if let exo = le.exercise { return (exo, le) }
        }
        if let le = lignes.last, let exo = le.exercise {
            return (exo, le)
        }
        return nil
    }

    private var titreCourant: String {
        exoCourant?.exo.name ?? "Session"
    }

    private var setsFaits: Int {
        (seance?.orderedExercises ?? [])
            .flatMap(\.orderedSets).filter(\.isDone).count
    }

    /// La partition : l'exo courant d'abord (id "courant"), puis les
    /// autres — le barème de l'ardoise (le pattern de la fiche).
    private func groupesSeance() -> [SlateGroupe] {
        var out: [SlateGroupe] = []
        let lignes = seance?.orderedExercises ?? []
        // §3.4quater : LA PARTITION N'EST JAMAIS VIDE (« on voit pas
        // les sessions ») — une séance née du galet n'a pas encore
        // d'exercices : le groupe courant naît en placeholder, le
        // pattern de la fiche.
        if lignes.isEmpty {
            return [SlateGroupe(
                id: "courant",
                exercise: ExerciseCatalog.all[0],
                rows: [SlateLigne(reps: 12, kilos: 20,
                                  seconds: 60, done: false)])]
        }
        let courant = exoCourant
        if let c = courant {
            out.append(SlateGroupe(
                id: "courant", exercise: c.exo,
                rows: c.ligne.orderedSets.map {
                    SlateLigne(reps: $0.reps, kilos: $0.weight,
                               seconds: $0.isDone ? $0.durationSeconds
                                   : c.ligne.restSeconds,
                               done: $0.isDone)
                }))
        }
        for le in lignes
        where le.exerciseID != courant?.ligne.exerciseID {
            guard let exo = le.exercise, !le.orderedSets.isEmpty
            else { continue }
            out.append(SlateGroupe(
                id: le.exerciseID, exercise: exo,
                rows: le.orderedSets.map {
                    SlateLigne(reps: $0.reps, kilos: $0.weight,
                               seconds: $0.isDone ? $0.durationSeconds
                                   : le.restSeconds,
                               done: $0.isDone)
                }))
        }
        return out
    }

    // MARK: le banc

    /// `-playerDoigt` (§3.4decies) : le DOIGT FANTÔME — il exerce le
    /// chemin du GESTE que `-playerCycle` ne touche pas : saisir /
    /// suivreDelta (écriture sèche) / commettre (élan 450), et la
    /// REPRISE EN PLEIN VOL (l'ancre exacte du tween possédé). Chaque
    /// tour : tap-vol · fermeture au doigt lent (la position décide) ·
    /// ouverture au doigt lent · rattrapage à mi-descente.
    private func bancDoigt() async {
        guard CommandLine.arguments.contains("-playerDoigt") else {
            return
        }
        try? await Task.sleep(for: .seconds(2.0))
        while !Task.isCancelled {
            // 1 · le vol du tap.
            etat.ouvrir()
            try? await Task.sleep(for: .seconds(1.4))
            // 2 · fermeture au doigt LENT — élan 120 < 450 : c'est la
            // POSITION qui doit décider (le « bim » est mort).
            await glisser(fraction: -0.85, duree: 0.8)
            etat.commettre(velocite: 120)
            try? await Task.sleep(for: .seconds(1.2))
            // 3 · ouverture au doigt lent, relâchée à mi-course.
            await glisser(fraction: 0.5, duree: 0.6)
            etat.commettre(velocite: -200)
            try? await Task.sleep(for: .seconds(1.2))
            // 4 · LA REPRISE EN PLEIN VOL : fermer, rattraper à
            // ~250 ms, remonter — zéro claquement attendu au juge.
            etat.fermer()
            try? await Task.sleep(for: .milliseconds(250))
            await glisser(fraction: 0.12, duree: 0.35)
            etat.commettre(velocite: -600)
            try? await Task.sleep(for: .seconds(1.3))
            etat.fermer()
            try? await Task.sleep(for: .seconds(1.4))
            SondeHit.rapporter()
        }
    }

    /// Le glissement fantôme : des deltas CUMULÉS à ~60 Hz, comme un
    /// doigt (la fraction est signée, + = vers le haut).
    private func glisser(fraction: CGFloat, duree: Double) async {
        let pas = max(Int(duree * 60), 1)
        let course = etat.hauteurCourse
        for i in 1...pas {
            etat.suivreDelta(course * fraction * CGFloat(i) / CGFloat(pas))
            try? await Task.sleep(for: .milliseconds(16))
        }
    }

    /// `-playerCycle` : ouvre/ferme en boucle — les films du
    /// FOUETTAGE ULTIME (§3.4bis) se tournent sans doigt.
    private func bancCycle() async {
        guard CommandLine.arguments.contains("-playerCycle") else {
            return
        }
        try? await Task.sleep(for: .seconds(2.0))
        while !Task.isCancelled {
            etat.ouvrir()
            try? await Task.sleep(for: .seconds(2.2))
            etat.fermer()
            try? await Task.sleep(for: .seconds(1.6))
            SondeHit.rapporter()
        }
    }
}

// MARK: - Le pan maître (§3.4undecies B1/B2)

/// LE PAN MAÎTRE — le drag DESCENDANT appartient au player, PARTOUT
/// sur le corps, sans zone morte. UIKit parce que SwiftUI ne sait pas
/// gagner contre le pan d'un `UIScrollView` : ce recognizer vit sur
/// la FENÊTRE (il reçoit les touches de toutes les vues), il est
/// SIMULTANÉ avec tout, et il ne se déclenche que :
///   · player OUVERT (fermé, il refuse la touche — la dalle garde son
///     geste SwiftUI d'ouverture) et panneau pause FERMÉ ;
///   · geste NET vers le bas (|dy| > |dx|, dy > 0) ;
///   · liste AU TOP — sinon elle rend d'abord son chemin, et le MÊME
///     geste bascule au player dès l'offset ≤ 0 (Apple Music). Pris,
///     il ÉPINGLE l'offset à 0 : la liste ne bouge plus sous le corps
///     qui descend.
/// Le relâcher commet avec l'élan ; le chien de `PlayerEtat` garde le
/// geste mort (la loi de la maison).
private struct PanMaitre: UIViewRepresentable {
    final class Coord: NSObject, UIGestureRecognizerDelegate {
        static weak var fenetrePosee: UIWindow?
        weak var sonde: UIView?
        weak var scroll: UIScrollView?
        // ⚠️ un recognizer ne RETIENT pas sa cible : au démontage du
        // corps, le pan doit QUITTER la fenêtre avec son coordinateur
        // (sinon : cible zombie, crash au prochain geste).
        weak var panPose: UIPanGestureRecognizer?
        weak var fenetre: UIWindow?

        func retirer() {
            if let p = panPose { fenetre?.removeGestureRecognizer(p) }
            if Coord.fenetrePosee === fenetre {
                Coord.fenetrePosee = nil
            }
        }
        var actif = false
        var mort = false
        var ancre: CGFloat = 0
        let crie = CommandLine.arguments.contains("-gesteSonde")

        @objc func pan(_ g: UIPanGestureRecognizer) {
            let etat = PlayerEtat.shared
            let ty = g.translation(in: g.view).y
            switch g.state {
            case .began:
                actif = false
                mort = false
                ancre = 0
                // le scroll de la branche du player, (re)trouvé au
                // début de chaque geste — jamais un scroll de page.
                if scroll == nil, let s = sonde {
                    scroll = Self.scrollDeLaBranche(depuis: s)
                }
                if crie { print("GESTE-SONDE maitre BEGAN") }
            case .changed:
                // §3.4duodecies (rafale) : une fois PRIS, le doigt
                // gagne jusqu'au relâcher — `ouvert` ne se re-lit que
                // pour PRENDRE, jamais pour lâcher en plein geste.
                guard !mort else { return }
                guard actif || etat.ouvert else { return }
                let tx = g.translation(in: g.view).x
                if !actif {
                    if abs(ty) < 6, abs(tx) < 6 { return }
                    if abs(tx) > abs(ty) || ty < 0 {
                        mort = true
                        if crie {
                            print("GESTE-SONDE maitre LAISSE "
                                + "(tx=\(Int(tx)) ty=\(Int(ty)))")
                        }
                        return
                    }
                    if let sv = scroll, sv.isScrollEnabled,
                       sv.contentOffset.y > 1 {
                        // la liste descend d'abord son chemin ; le
                        // même geste nous revient à l'offset 0.
                        return
                    }
                    actif = true
                    ancre = ty
                    if crie {
                        print("GESTE-SONDE maitre PREND ty=\(Int(ty))")
                    }
                }
                if let sv = scroll, sv.contentOffset.y > 0 {
                    sv.contentOffset.y = 0
                }
                etat.suivreDelta(-(ty - ancre))
            case .ended, .cancelled, .failed:
                if actif {
                    etat.commettre(velocite: g.velocity(in: g.view).y)
                    if crie {
                        print("GESTE-SONDE maitre COMMET "
                            + "v=\(Int(g.velocity(in: g.view).y))")
                    }
                }
                actif = false
                mort = false
            default:
                break
            }
        }

        func gestureRecognizer(
            _ g: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool { true }

        func gestureRecognizer(_ g: UIGestureRecognizer,
                               shouldReceive touch: UITouch) -> Bool {
            PlayerEtat.shared.ouvert
                && !DepartEtat.shared.pauseOuverte
        }

        static func scrollDeLaBranche(depuis v: UIView) -> UIScrollView? {
            var ancetre: UIView? = v.superview
            while let a = ancetre {
                var file = a.subviews
                while !file.isEmpty {
                    let u = file.removeFirst()
                    if u === v { continue }
                    if let sv = u as? UIScrollView { return sv }
                    file.append(contentsOf: u.subviews)
                }
                ancetre = a.superview
            }
            return nil
        }
    }

    func makeCoordinator() -> Coord { Coord() }

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.isUserInteractionEnabled = false
        context.coordinator.sonde = v
        return v
    }

    func updateUIView(_ v: UIView, context: Context) {
        DispatchQueue.main.async {
            guard let w = v.window, Coord.fenetrePosee !== w else {
                return
            }
            let pan = UIPanGestureRecognizer(
                target: context.coordinator,
                action: #selector(Coord.pan(_:)))
            pan.maximumNumberOfTouches = 1
            pan.delegate = context.coordinator
            w.addGestureRecognizer(pan)
            Coord.fenetrePosee = w
            context.coordinator.panPose = pan
            context.coordinator.fenetre = w
            if context.coordinator.crie {
                print("GESTE-SONDE maitre POSÉ sur la fenêtre")
            }
        }
    }

    static func dismantleUIView(_ v: UIView, coordinator: Coord) {
        coordinator.retirer()
    }
}

#if DEBUG
/// §3.4undecies B5 — LA SONDE DE POSSESSION (`-gesteSonde`) : QUI
/// reçoit le doigt ? Elle accroche un TARGET ADDITIONNEL au pan du
/// `UIScrollView` de la partition (trouvé en remontant depuis sa
/// propre branche — jamais un scroll d'une page derrière) : chaque
/// began/ended du SCROLL est crié à la console, à côté des logs du
/// player (SAISIR/COMMETTRE). Un drag descendant qui ne produit QUE
/// des lignes scroll = le vol prouvé, nommé.
struct SondeGestePan: UIViewRepresentable {
    final class Coordinateur: NSObject {
        var accroche = false
        @objc func pan(_ g: UIPanGestureRecognizer) {
            let sv = g.view as? UIScrollView
            let etat: String
            switch g.state {
            case .began: etat = "BEGAN"
            case .changed: etat = "changed"
            case .ended: etat = "ENDED"
            case .cancelled: etat = "CANCELLED"
            case .failed: etat = "FAILED"
            default: return
            }
            let ty = Int(g.translation(in: g.view).y)
            // le bruit des changed est décimé, les bords criés
            if g.state != .changed || ty % 60 == 0 {
                let off = sv.map { Int($0.contentOffset.y) } ?? -999
                print("GESTE-SONDE scroll \(etat) ty=\(ty) offset=\(off)")
            }
        }
    }

    func makeCoordinator() -> Coordinateur { Coordinateur() }

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.isUserInteractionEnabled = false
        return v
    }

    func updateUIView(_ v: UIView, context: Context) {
        guard !context.coordinator.accroche else { return }
        DispatchQueue.main.async {
            guard !context.coordinator.accroche else { return }
            // remonter niveau par niveau : le premier UIScrollView
            // DESCENDANT d'un ancêtre = le scroll de NOTRE branche.
            var ancetre: UIView? = v.superview
            while let a = ancetre {
                if let sv = Self.scrollDescendant(de: a, sauf: v) {
                    sv.panGestureRecognizer.addTarget(
                        context.coordinator,
                        action: #selector(Coordinateur.pan(_:)))
                    context.coordinator.accroche = true
                    print("GESTE-SONDE accrochée à \(type(of: sv)) "
                        + "h=\(Int(sv.bounds.height)) "
                        + "contenu=\(Int(sv.contentSize.height))")
                    return
                }
                ancetre = a.superview
            }
            print("GESTE-SONDE : AUCUN UIScrollView trouvé dans la branche")
        }
    }

    private static func scrollDescendant(de racine: UIView,
                                         sauf: UIView) -> UIScrollView? {
        var file = racine.subviews
        while !file.isEmpty {
            let u = file.removeFirst()
            if u === sauf { continue }
            if let sv = u as? UIScrollView { return sv }
            file.append(contentsOf: u.subviews)
        }
        return nil
    }
}
#endif

#if DEBUG
/// LA SONDE DE HIT-TEST (§3.4bis, « les retours FIABLES ») — après
/// chaque cycle, l'app dit QUI recevrait un toucher aux points
/// témoins : si un voile ou un conteneur orphelin traîne (le fantôme
/// d'e9521cf), c'est LUI qui répond, et la console le crie. Lue par
/// `simctl launch --console-pty`.
enum SondeHit {
    @MainActor
    static func rapporter() {
        guard CommandLine.arguments.contains("-hitSonde") else { return }
        guard let fen = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first else { return }
        let H = fen.bounds.height, W = fen.bounds.width
        // Trois témoins : le chevron (haut-gauche), le centre de page,
        // la dalle (bas-centre).
        for (nom, pt) in [("chevron", CGPoint(x: 40, y: 80)),
                          ("centre", CGPoint(x: W / 2, y: H * 0.45)),
                          ("dalle", CGPoint(x: W / 2, y: H - 60))] {
            let vue = fen.hitTest(pt, with: nil)
            let type = vue.map { String(describing: Swift.type(of: $0)) }
                ?? "nil"
            print("SONDE-HIT \(nom) @\(Int(pt.x)),\(Int(pt.y)) → \(type)")
        }
    }
}
#endif

// MARK: - Les suiveurs (§3.4quinquies) — les SEULES pièces qui relisent
// `p` par frame pendant le suivi au doigt (la loi n° 6 : tout le reste
// est un arbre déjà construit).

/// Le voile : opacité = f(p) ; BOUCLIER dès le vol (`actif`), mais le
/// tap ne FERME qu'au posé complet (§3.4duodecies — la rafale).
private struct VoilePlayer: View {
    var onTap: () -> Void
    var actif: Bool
    private let etat = PlayerEtat.shared

    var body: some View {
        Color.black.opacity(0.55 * min(max(etat.p, 0), 1))
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture {
                if PlayerEtat.shared.poseComplet { onTap() }
            }
            .allowsHitTesting(actif)
    }
}

/// L'offset du corps : y = (1 − p) · course.
private struct OffsetVol: ViewModifier {
    var course: CGFloat
    private let etat = PlayerEtat.shared

    func body(content: Content) -> some View {
        content.offset(y: (1 - etat.p) * course)
    }
}
