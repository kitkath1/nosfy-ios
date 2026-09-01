import SwiftUI
import SwiftData

// MARK: - PlayerMonde — LE player global, unique, à la racine (§3)

/// L'ÉTAT DU PLAYER — un singleton @Observable (§3.1) : la dalle de
/// chaque page appelle `ouvrir()`, les gestes du player appellent
/// `fermer()`. Deux springs uniques, JAMAIS un suivi à l'ouverture
/// (la doctrine anti-bugs : une transition est un état commis).
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

    func ouvrir() {
        guard !ouvert else { return }
        // FLUIDITÉ (S1' + §3.4quater, payé au juge du vol) : le CADRE est
        // toujours rendu, le contenu lourd NAÎT D'ABORD hors écran
        // (jamais pendant le film), le vol part au tick SUIVANT sur un
        // arbre déjà construit et des groupes déjà chargés.
        monte = true
        couvre = true
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: Self.tempo)) {
                self.ouvert = true
                self.p = 1
            }
        }
        armerPose()
    }

    /// Le verre revient quand le vol est FINI (jeton : toute nouvelle
    /// transition l'annule).
    private func armerPose() {
        poseComplet = false
        poseJeton += 1
        let jeton = poseJeton
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.tempo + 0.08) {
            if self.poseJeton == jeton, self.ouvert {
                self.poseComplet = true
            }
        }
    }

    private var poseJeton = 0

    func fermer() {
        guard ouvert || p > 0 else { return }
        poseComplet = false
        poseJeton += 1
        withAnimation(.easeInOut(duration: Self.tempo)) {
            ouvert = false
            p = 0
        }
        armerDemontage()
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

    /// La prise : le contenu naît immédiatement (pré-montage).
    func saisir() {
        origineOuverte = ouvert
        pAncre = p
        enSuivi = true
        monte = true
        couvre = true
        poseComplet = false
        poseJeton += 1
    }

    /// L'ancre du geste — le suivi est RELATIF (§3.4nonies : le suivi
    /// absolu faisait sauter p au premier événement).
    private var pAncre: CGFloat = 0

    /// Le doigt parle : p suit, SANS transaction animée. Le CHIEN DE
    /// GARDE est réarmé à chaque frame : un geste mort sans `onEnded`
    /// (pointeur perdu, présentation) COMMET au plus proche — jamais un
    /// player abandonné à mi-vol (la loi de la maison).
    /// Le doigt parle en DELTA (points d'écran, positif = vers le
    /// haut). L'écriture passe par un ressort INTERACTIF court : le
    /// raccord d'une reprise en vol est un rattrapage doux, jamais un
    /// claquement (§3.4nonies), et le suivi colle au doigt.
    func suivreDelta(_ delta: CGFloat) {
        if !enSuivi {
            saisir()
            armerChienSuivi()
        }
        let cible = min(max(pAncre + delta / hauteurCourse, 0), 1)
        withAnimation(.interactiveSpring(response: 0.15,
                                         dampingFraction: 0.86)) {
            p = cible
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
        enSuivi = false
        // L'ÉLAN d'abord (150 : l'effleurement compte), la POSITION
        // ensuite — ASYMÉTRIQUE : depuis ouvert, descendre de 20 % de
        // course suffit à fermer (le « j'ai du mal à le baisser »).
        let cible: CGFloat = velocite < -150 ? 1
            : velocite > 150 ? 0
            : origineOuverte ? (p < 0.8 ? 0 : 1)
            : (p > 0.2 ? 1 : 0)
        let duree = min(max(Double(abs(cible - p)) * Self.tempo, 0.22),
                        Self.tempo)
        withAnimation(.easeOut(duration: duree)) {
            ouvert = cible == 1
            p = cible
        }
        if cible == 0 { armerDemontage() } else { armerPose() }
    }

    private func armerDemontage() {
        // Le démontage APRÈS l'animation (jeton : un `ouvrir()` pendant
        // la descente l'annule) — et les lecteurs des pages REPARLENT.
        let jeton = jetonVie
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.tempo + 0.1) {
            if self.jetonVie == jeton, !self.ouvert {
                self.monte = false
                self.couvre = false
            }
        }
        jetonVie += 1
    }

    private var jetonVie = 0
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
                // §3.4quinquies : EN SUIVI le contenu est FIGÉ à l'état
                // posé (le ternaire ne LIT `p` que hors suivi — zéro
                // invalidation par frame pendant le doigt). Le flick de
                // la partition est MORT : il entrait en collision avec
                // le header suivi (le glitch) — un seul chemin de
                // fermeture au geste.
                ScenePlayer(levee: etat.enSuivi ? 1 : etat.p,
                            titre: titreCourant,
                            groupes: groupes, deplies: $deplies,
                            pose: etat.poseComplet)
                    .frame(maxWidth: .infinity, maxHeight: .infinity,
                           alignment: .top)
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
                .opacity(Double(etat.enSuivi ? 1 : etat.p))
                .allowsHitTesting(false)
                .ignoresSafeArea(edges: .top)
            }
            // LA PRISE PARTOUT (§3.4octies, verdict : « j'arrive pas à
            // bien drag ») — le geste suivi vit sur le CORPS ENTIER, en
            // SIMULTANÉ : la liste garde son scroll (le doigt sur elle
            // appartient au ScrollView — la loi), le stop et « Page
            // exercices » gardent leurs taps high-priority.
            .simultaneousGesture(
                DragGesture(minimumDistance: 3)
                    .onChanged { v in
                        etat.suivreDelta(-v.translation.height)
                    }
                    .onEnded { v in
                        etat.commettre(velocite: v.velocity.height)
                    })
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
                PiedPlayer(levee: etat.enSuivi ? 1 : etat.p,
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

/// Le voile : opacité = f(p), tap pour fermer.
private struct VoilePlayer: View {
    var onTap: () -> Void
    var actif: Bool
    private let etat = PlayerEtat.shared

    var body: some View {
        Color.black.opacity(0.55 * etat.p)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
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
