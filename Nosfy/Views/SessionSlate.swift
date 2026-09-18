import SwiftUI

// MARK: - L'ardoise de séance — le panneau semi-sorti du player

/// UN SEUL OBJET, DEUX ÉTATS. La dalle du player n'est pas un bouton qui
/// « ouvre un overlay » : elle est le SOMMET d'un panneau dont seuls les
/// 76 pt dépassent du bord bas au repos. Le tirage vers le haut fait monter
/// tout le panneau — le player ne bouge pas de son sommet — et la PARTITION
/// de la séance se révèle dessous ; le tirage vers le bas le range.
/// Un curseur unique piloté au doigt : la loi de la carte des séries —
/// jamais un scroll pour tenir un panneau, il lui faut son curseur+drag.
///
/// LA FLUIDITÉ EST UNE LOI (le lag payé au premier montage) : pendant le
/// tirage, seuls l'offset et une opacité changent. Les groupes sont FIGÉS
/// dans un état (aucun accès SwiftData par image), et le corps de liste est
/// Équatable sur des clés bon marché — il n'est jamais réévalué tant que
/// les données ne changent pas.
struct SessionSlate: View {
    let exercise: Exercise
    var progress: Double = 0
    var startedAt: Date? = nil
    /// Les brouillons de l'exercice COURANT — la seule vérité de ses
    /// séries tant que le fil-de-l'eau (jalon 0) n'est pas passé.
    var drafts: [DraftSet] = []
    var restSeconds: Int = 60
    /// La séance persistée — les AUTRES exercices de la session.
    var workout: Workout? = nil
    /// La zone sûre basse de l'hôte : la dalle plonge dedans jusqu'au
    /// bord physique, l'indicateur home passe dessus.
    var safeBottom: CGFloat = 34
    /// L'ARDOISE EST EN MAIN (tirage en cours ou ouverte) : la fiche s'en
    /// sert pour DÉSARMER le drag plein écran de la carte des séries —
    /// sans ça, un doigt qui échappe à la dalle fait respirer toute la
    /// page (le gros beug payé).
    @Binding var busy: Bool

    /// La hauteur de la dalle-sommet (le player, trait aéré compris).
    static let dockH: CGFloat = 76

    /// Le curseur : 0 la dalle seule dépasse, 1 l'ardoise est ouverte.
    @State private var p: CGFloat = SessionSlate.openLab ? 1 : 0
    /// La base du tirage en cours — le doigt reprend là où il attrape.
    @State private var dragFrom: CGFloat?
    /// LES GROUPES FIGÉS : rafraîchis à l'apparition et à la PRISE du
    /// doigt (une fois par geste, panneau encore fermé) — jamais pendant
    /// le tirage.
    @State private var groupes: [SlateGroupe] = []
    /// LE DÉPLIAGE VIT CHEZ L'HÔTE — voir la note de `SlateListe`.
    @State private var deplies: Set<String> = []

    /// BANC : `-slateOpen` naît ouverte (le simulateur ne drague pas).
    private static let openLab = CommandLine.arguments.contains("-slateOpen")

    var body: some View {
        GeometryReader { g in
            // `g` couvre jusqu'au bord PHYSIQUE (ignoresSafeArea bas, sur
            // le GeometryReader). LE GROS BEUG payé ici : sans lui, la
            // moitié basse de la dalle (la bande de la zone sûre) vivait
            // HORS des bounds de l'overlay — morte au toucher — pendant
            // que la surface plein écran du drag de la carte, elle,
            // `ignoresSafeArea` et attrapait le doigt à sa place :
            // « toute la page respire sauf le galet ».
            let H = g.size.height
            let slateH = H * 0.86
            let course = slateH - Self.dockH

            ZStack(alignment: .bottom) {
                // Le voile : la page recule quand l'ardoise s'ouvre — et
                // un tap dessus la range. Léger : le verre du corps a
                // besoin d'une scène vivante à réfracter.
                Color.black.opacity(0.32 * p)
                    .ignoresSafeArea()
                    .allowsHitTesting(p > 0.6)
                    .onTapGesture { settle(to: 0) }

                panel(slateH: slateH, course: course,
                      pose: max(0, (p - 0.94) / 0.06))
                    .offset(y: (1 - p) * course)
            }
            .frame(width: g.size.width, height: g.size.height)
        }
        // La grammaire du panneau Recommencer : la géométrie s'étend au
        // bord physique DES DEUX CÔTÉS du contrat — le dessin ET
        // l'écoute. (Le `edges: .bottom` du montage d'avant n'étendait
        // que le dessin : le doigt sur la dalle partait au galet.)
        .ignoresSafeArea()
        .onAppear {
            groupes = buildGroupes()
            busy = p > 0.02
        }
    }

    // MARK: Le panneau

    private func panel(slateH: CGFloat, course: CGFloat,
                       pose: CGFloat) -> some View {
        VStack(spacing: 0) {
            WorkoutPill(exercise: exercise,
                        progress: progress,
                        startedAt: startedAt,
                        docked: true,
                        // Le bilan pour le panneau du stop : les
                        // brouillons faits + l'exercice courant et ceux
                        // de la séance persistée.
                        doneSeries: drafts.filter(\.isDone).count,
                        exoCount: 1 + (workout?.orderedExercises
                            .filter { $0.exerciseID != exercise.id }
                            .count ?? 0))
                // LE TRAIT : la poignée de la maison, posée sur la dalle —
                // l'invitation au tirage, présente aux deux états.
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(Color.white.opacity(0.28))
                        .frame(width: 36, height: 4)
                        .padding(.top, 8)
                }
                .contentShape(Rectangle())
                // minimumDistance 12 : les taps de pause/stop survivent
                // au geste (le piège des touchers, déjà payé sur le dôme).
                .gesture(tirage(course: course))

            // LA LISTE NE VIT QUE L'ARDOISE OUVERTE — et c'est une LOI,
            // pas une économie : un ScrollView monté HORS ÉCRAN (le
            // panneau fermé est offset sous le bord) dans un overlay
            // `ignoresSafeArea` re-négocie ses insets avec la scène à
            // chaque passe de layout — un PING-PONG qui poussait toute
            // la page de ~50 pt et la laissait se rétablir en ressort,
            // en boucle (« toute la page respire », prouvé par
            // bissection : sans cette liste, dérive zéro sur 7 s).
            if p > 0.02 {
                SlateListe(groupes: groupes, courant: "courant",
                           basAir: safeBottom + 24,
                           deplies: $deplies)
                    .equatable()
                    // Le contenu naît avec l'ouverture — fermé, l'ardoise
                    // n'est que sa dalle.
                    .opacity(Double(p))
            }
        }
        .frame(height: slateH, alignment: .top)
        .background { corps(pose: pose) }
    }

    /// Le verre-nuit du panneau Recommencer — mais LE VERRE NE S'ALLUME
    /// QU'À L'ARRIVÉE (pose 0 → 1 sur les 6 derniers % de la course) :
    /// en voyage, il réfractait la nacre du galet et TOUTE la page
    /// « respirait » sous le panneau (le verdict « c'est bizarre »). En
    /// route, l'ardoise est une nuit pleine ; posée, le verre respire.
    private func corps(pose: CGFloat) -> some View {
        let forme = UnevenRoundedRectangle(
            topLeadingRadius: 22, bottomLeadingRadius: 0,
            bottomTrailingRadius: 0, topTrailingRadius: 22,
            style: .continuous)
        return ZStack {
            Color.clear
                .glassEffect(.regular.tint(Color.black.opacity(0.30)),
                             in: forme)
                .opacity(Double(pose))
            LinearGradient(stops: [
                .init(color: .black.opacity(0.95), location: 0),
                .init(color: .black.opacity(0.88), location: 0.38),
                .init(color: .black.opacity(0.25), location: 1),
            ], startPoint: .top, endPoint: .bottom)
            .clipShape(forme)
            // La nuit pleine du voyage, en croisé avec le verre.
            LinearGradient(stops: [
                .init(color: .black.opacity(0.97), location: 0),
                .init(color: .black.opacity(0.95), location: 0.38),
                .init(color: .black.opacity(0.88), location: 1),
            ], startPoint: .top, endPoint: .bottom)
            .clipShape(forme)
            .opacity(1 - Double(pose))
        }
    }

    // MARK: Les groupes

    /// L'exercice courant d'abord — TOUJOURS présent, au barème de la
    /// carte des séries (max(brouillons, 5), les prévues en « à venir »,
    /// reps/kg du dernier brouillon) — puis les autres exercices de la
    /// séance persistée, dans l'ordre de la séance (le fil-de-l'eau du
    /// jalon 0 les remplira).
    private func buildGroupes() -> [SlateGroupe] {
        var out: [SlateGroupe] = []
        var courant: [SlateLigne] = []
        for i in 0..<max(drafts.count, 5) {
            if i < drafts.count {
                courant.append(SlateLigne(
                    reps: drafts[i].reps, kilos: drafts[i].weight,
                    seconds: drafts[i].isDone ? drafts[i].durationSeconds
                                              : restSeconds,
                    done: drafts[i].isDone))
            } else {
                courant.append(SlateLigne(
                    reps: drafts.last?.reps ?? 12,
                    kilos: drafts.last?.weight ?? 20,
                    seconds: restSeconds, done: false))
            }
        }
        out.append(SlateGroupe(id: "courant", exercise: exercise,
                               rows: courant))
        for le in workout?.orderedExercises ?? []
        where le.exerciseID != exercise.id {
            guard let exo = le.exercise else { continue }
            // Séries, intervalles faits ou longueurs — un exercice sans rien
            // de fait n'a pas de rangée (15-09 : le cardio entre ici).
            let rows = SlateGroupe.lignes(de: le, restSeconds: le.restSeconds)
            guard !rows.isEmpty else { continue }
            out.append(SlateGroupe(id: le.exerciseID, exercise: exo, rows: rows))
        }
        return out
    }

    // MARK: Le tirage

    private func tirage(course: CGFloat) -> some Gesture {
        // `.global` OBLIGATOIRE — la loi payée ici : un objet qui bouge
        // ne mesure JAMAIS son propre geste dans son propre repère. En
        // local, le panneau montait sous le doigt, le doigt « redescendait »
        // dans son repère, la translation se corrigeait d'elle-même :
        // sensibilité divisée par deux + oscillation frame à frame (le
        // « ça glitch »). Le galet mesure en global, la carte est sourde
        // au doigt — le tirage rejoint la règle.
        DragGesture(minimumDistance: 12, coordinateSpace: .global)
            .onChanged { v in
                if dragFrom == nil {
                    dragFrom = p
                    busy = true
                    // Les données se figent à la PRISE, panneau encore
                    // fermé — une seule visite à SwiftData par geste.
                    if p < 0.02 { groupes = buildGroupes() }
                }
                let d = -v.translation.height / max(course, 1)
                p = min(max((dragFrom ?? 0) + d, 0), 1)
            }
            .onEnded { v in
                dragFrom = nil
                // La vitesse tranche, la position départage — les seuils
                // du geste sûr.
                let vy = v.velocity.height
                let cible: CGFloat = vy < -260 ? 1
                    : vy > 260 ? 0
                    : (p > 0.5 ? 1 : 0)
                settle(to: cible)
            }
    }

    private func settle(to t: CGFloat) {
        busy = t > 0.02
        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
            p = t
        }
    }
}

// MARK: - Les données figées de l'ardoise

struct SlateLigne {
    /// LE GENRE (15-09, plan cardio §D) — « dans l'overlay on indique HIIT
    /// et en dessous les intervalles, pour garder la constance avec les
    /// exercices de base » : la même ligne, trois contenus.
    enum Genre: Equatable {
        /// La série de muscu : reps · kg.
        case serie(reps: Int, kilos: Double)
        /// Un intervalle cardio : sa vitesse (km/h, ou un niveau).
        case intervalle(vitesse: Double, niveau: Bool)
        /// La piscine : les longueurs, le bassin.
        case longueurs(n: Int, metres: Int)
    }
    var genre: Genre
    var seconds: Int
    var done: Bool

    /// Le constructeur d'avant — la série de muscu, telle quelle.
    init(reps: Int, kilos: Double, seconds: Int, done: Bool) {
        genre = .serie(reps: reps, kilos: kilos)
        self.seconds = seconds
        self.done = done
    }
    init(genre: Genre, seconds: Int, done: Bool) {
        self.genre = genre
        self.seconds = seconds
        self.done = done
    }

    var reps: Int { if case .serie(let r, _) = genre { return r }; return 0 }
    var kilos: Double { if case .serie(_, let k) = genre { return k }; return 0 }
    var estSerie: Bool { if case .serie = genre { return true }; return false }
}

struct SlateGroupe: Identifiable {
    let id: String
    var exercise: Exercise
    var rows: [SlateLigne]
    var done: Int { rows.filter(\.done).count }
    /// CARDIO : la rangée n'a pas de flammes (verdict 15-09 : « sans les
    /// flammes que les exos de base ont ») — une ligne de résumé à leur
    /// place. Vrai dès qu'une ligne n'est pas une série.
    var cardio: Bool { rows.contains { !$0.estSerie } }
    /// « 3 intervalles · 6:40 », « 20 longueurs · 500 m ».
    var resume: String {
        if let l = rows.first, case .longueurs(let n, let m) = l.genre {
            return "\(n) \(L("longueur", "length"))\(n > 1 ? "s" : "") · \(n * m) m"
        }
        let n = rows.filter(\.done).count
        let s = rows.filter(\.done).reduce(0) { $0 + $1.seconds }
        return "\(n) \(L("intervalle", "interval"))\(n > 1 ? "s" : "") · \(ChambreFmt.mmss(s))"
    }
    /// La clé bon marché de l'équatabilité — id, compte, faites, et le
    /// temps cardio (une longueur de plus change la ligne sans changer
    /// `done`) : tout ce qui peut changer l'affichage.
    var cle: String {
        "\(id)-\(rows.count)-\(done)-\(cardio ? resume : "")"
    }
}

extension SlateGroupe {
    /// LES LIGNES D'UN EXERCICE DE SÉANCE — muscu, cardio ou piscine — pour
    /// les deux constructeurs de groupes (l'ardoise et le grand player).
    /// Une série par ligne ; un INTERVALLE fait par ligne (les récups sont
    /// dans le graphe de la fiche, pas ici) ; une ligne pour la piscine.
    static func lignes(de le: LoggedExercise, restSeconds: Int) -> [SlateLigne] {
        if !le.orderedSets.isEmpty {
            return le.orderedSets.map {
                SlateLigne(reps: $0.reps, kilos: $0.weight,
                           seconds: $0.isDone ? $0.durationSeconds : restSeconds,
                           done: $0.isDone)
            }
        }
        if le.longueurs > 0 {
            return [SlateLigne(genre: .longueurs(n: le.longueurs, metres: le.metresParLongueur),
                               seconds: 0, done: true)]
        }
        let niveau = le.exerciseID == "escalier"
        return le.phasesFaites.filter(\.isEffort).map {
            SlateLigne(genre: .intervalle(vitesse: $0.speed, niveau: niveau),
                       seconds: $0.seconds, done: true)
        }
    }
}

// MARK: - La partition de séance

/// UNE RANGÉE COMPACTE PAR EXERCICE — vignette, nom, ses séries en
/// petites flammes (le langage de la carte Training, GELÉES : t constant,
/// aucune horloge) — et seul l'exercice déplié montre ses lignes
/// détaillées. Toute la session se lit d'un regard, et on ne monte
/// qu'une poignée de lignes vivantes (leurs petits néons compris).
///
/// Équatable sur les clés des groupes : pendant le tirage, ce corps
/// n'est JAMAIS réévalué.
///
/// PARTAGÉE (18-08) : la story 2 pose la même partition sur sa vidéo —
/// un seul composant pour l'ardoise et la story, jamais deux copies qui
/// divergent d'un pouième.
struct SlateListe: View, Equatable {
    let groupes: [SlateGroupe]
    /// L'id du groupe déplié à la naissance (l'exercice courant).
    let courant: String
    let basAir: CGFloat
    /// La hauteur RÉELLE du contenu, remontée à l'hôte : la story 2 y
    /// colle sa frame (et donc le rect d'exclusion du chef) — une frame
    /// fixe fabriquait des zones mortes qui avalaient les taps.
    var onContentHeight: (CGFloat) -> Void = { _ in }

    /// LES GROUPES DÉPLIÉS — ET L'ÉTAT VIT CHEZ L'HÔTE (26-08, la
    /// QUATRIÈME variante du piège du dépliage, celle-ci prouvée à la
    /// console).
    ///
    /// Il était `@State` ICI, et cette liste est montée en
    /// `.equatable()` : l'égalité ne compare que `courant` et les clés
    /// des groupes — donc RIEN qui bouge quand on déplie. Mesuré :
    /// l'état basculait bien quatre fois (`[] → [courant] → [] →
    /// [courant]`) pendant que le corps n'était réévalué que TROIS
    /// fois. `EquatableView` court-circuitait l'invalidation, la vue
    /// restait sur son image, et le tap « n'ouvrait plus rien ».
    ///
    /// En le remontant à l'hôte et en le COMPARANT dans `==`, les deux
    /// lois tiennent ensemble : pendant le tirage du panneau (60 images
    /// par seconde), `deplies` ne change pas → l'égalité coupe la
    /// réévaluation, la fluidité est sauve ; au tap, `deplies` change →
    /// l'égalité est fausse → le corps se rejoue. Ne JAMAIS le
    /// redescendre en `@State`.
    @Binding var deplies: Set<String>
    @State private var seme = false

    static func == (l: Self, r: Self) -> Bool {
        l.courant == r.courant
            && l.deplies == r.deplies
            && l.groupes.map(\.cle) == r.groupes.map(\.cle)
    }

    /// LE DÉPLIAGE VOYAGE DANS LES DONNÉES DU FOREACH — la leçon payée
    /// deux fois le 18-08 : un ForEach ne rejoue ses rangées que quand
    /// SES DONNÉES changent. Le passage « en valeur de vue » (SlateRang
    /// seul) tenait pour les taps mais PAS pour l'ensemencement de
    /// naissance de l'ardoise (rangées matérialisées avant le semis,
    /// figées repliées). Ici la donnée elle-même porte `depliee` : tout
    /// changement de dépliage EST un changement de données.
    private var rangs: [RangDonnee] {
        groupes.enumerated().map { i, g in
            RangDonnee(groupe: g, depliee: deplies.contains(g.id),
                       rang: i + 1)
        }
    }

    var body: some View {
        // ⚠️ L'HÔTE NE PREND JAMAIS LA LARGEUR DE SON CONTENU (le piège
        // payé de la fente qui gonfle sa carte, re-payé ici le 26-08) :
        // une ligne dépliée (`SetHistoryRow`) a une largeur MINIMALE
        // incompressible — lune + « Set N » + les métriques en
        // `fixedSize` + le gain ≈ 342 pt. Dans un hôte plus étroit (la
        // liste de la story : ~310 pt), elle élargissait le ScrollView,
        // donc la liste, donc la colonne de la page — que le parent
        // RECENTRAIT : « quand je clique sur une ligne, ça se décale ».
        // Le GeometryReader prend la largeur PROPOSÉE et ne la rend
        // jamais : la largeur est désormais imposée au contenu, dans la
        // story COMME dans l'ardoise du player.
        GeometryReader { g in
            ScrollView {
                VStack(spacing: 4) {
                    // ⚠️ `ForEach(rangs)` NU — jamais `id:` par chemin de
                    // clé : il remplacerait l'égalité de la donnée et
                    // regèlerait les rangées (voir `RangDonnee.rang`).
                    ForEach(rangs) { r in
                        SlateRang(groupe: r.groupe,
                                  depliee: r.depliee,
                                  rang: r.rang,
                                  onTap: { bascule(r.groupe.id) })
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, basAir)
                .frame(width: g.size.width)
                .onGeometryChange(for: CGFloat.self) { $0.size.height }
                    action: { onContentHeight($0) }
            }
            .frame(width: g.size.width, height: g.size.height)
            .clipped()
        }
        .scrollIndicators(.hidden)
        .onAppear {
            if !seme { seme = true; deplies = [courant] }
            // LA SONDE DE NON-RÉGRESSION : `-slateSonde` déplie tout
            // seul la 2e rangée à +2 s puis la replie à +4 s — le tap
            // ne s'injecte pas au simctl, et c'est elle qui a prouvé le
            // décalage (26-08) puis sa mort : titre et rangées mesurés
            // IMMOBILES au pixel pendant la bascule, dans la story
            // comme dans l'ardoise.
        }
        // LA SONDE VIT SUR L'ARRIVÉE DES DONNÉES, pas sur la naissance
        // de la vue (26-08, payé) : l'ardoise du player monte sa liste
        // AVANT que ses groupes soient construits, donc un `onAppear`
        // trouvait un tableau vide et la sonde se taisait — pile là où
        // le bug vivait. Elle bascule la PREMIÈRE rangée, quatre fois.
        .task(id: groupes.first?.id) {
            guard CommandLine.arguments.contains("-slateSonde"),
                  let id = groupes.first?.id else { return }
            for _ in 0..<4 {
                try? await Task.sleep(for: .seconds(2))
                if Task.isCancelled { return }
                bascule(id)
            }
        }
    }

    private func bascule(_ id: String) {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
            if deplies.contains(id) { deplies.remove(id) }
            else { deplies.insert(id) }
        }
    }

}

// MARK: - Une rangée de la partition

/// La DONNÉE d'une rangée : le groupe ET son dépliage — pour que le
/// ForEach voie chaque bascule comme un changement de données.
private struct RangDonnee: Identifiable, Equatable {
    let groupe: SlateGroupe
    let depliee: Bool
    /// LE RANG VIT DANS LA DONNÉE, LUI AUSSI (26-08, payé une fois de
    /// plus). Il avait été pris d'un `ForEach(Array(rangs.enumerated()),
    /// id: \.element.id)` — et ce `id:` par chemin de clé REMPLACE
    /// l'identité `Identifiable` ET l'égalité de la donnée : le ForEach
    /// ne voyait plus `depliee` changer, les rangées restaient gelées
    /// sur leur image de naissance et le tap ne dépliait plus rien.
    /// C'est LE piège du dépliage, dans sa troisième variante.
    /// La seule forme robuste reste `ForEach(rangs)` — la donnée porte
    /// TOUT ce qui peut changer l'affichage.
    let rang: Int
    var id: String { groupe.id }

    static func == (l: Self, r: Self) -> Bool {
        l.id == r.id && l.depliee == r.depliee && l.rang == r.rang
            && l.groupe.cle == r.groupe.cle
    }
}

/// UNE rangée + ses lignes dépliées — VUE-ENFANT, et c'est STRUCTUREL :
/// le dépliage arrive en VALEUR (`depliee`), que le diffing voit changer.
/// La leçon payée dix tours (18-08, au sondage) : un ForEach ne rejoue
/// ses rangées que quand SES DONNÉES changent — un `if` sur un @State
/// capturé dans sa closure est INVISIBLE au diffing, et les rangées
/// restent gelées à vie sur leur image de naissance.
///
/// Le tap est un `onTapGesture` d'ENFANT, pas un Button — sondé aussi :
/// sous le chef d'orchestre de la story (DragGesture simultané à
/// distance nulle, par-dessus le ScrollView), le press d'un Button est
/// affamé puis annulé ; le tap d'enfant, lui, gagne — dans la story
/// comme dans l'ardoise.
private struct SlateRang: View {
    let groupe: SlateGroupe
    let depliee: Bool
    /// Le rang dans la séance, à partir de 1 — « 01 », « 02 »…
    let rang: Int
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // LE TRAIT — la lame verticale à dégradé de la molette
            // (`SetEntrySheet`), en ARGENT. Il ne vit que sur la ligne
            // OUVERTE, mais sa place est TOUJOURS réservée : rien ne
            // doit glisser horizontalement quand l'actif change.
            Capsule(style: .continuous)
                .fill(LinearGradient(
                    colors: [Color.white.opacity(0.95),
                             Color.white.opacity(0.25)],
                    startPoint: .top, endPoint: .bottom))
                .frame(width: 2.4, height: 30)
                .opacity(depliee ? 1 : 0)

            // LE NUMÉRO — deux positions, chiffres MONOSPACÉS : le
            // layout ne respire pas entre 9 et 10.
            Text(String(format: "%02d", rang))
                .font(.inter(18, .medium))
                .monospacedDigit()
                .foregroundStyle(Color.white.opacity(depliee ? 0.92 : 0.34))

            Text(groupe.exercise.nomLocalise)
                .font(.inter(15, .semibold))
                .foregroundStyle(Color.white.opacity(depliee ? 0.94 : 0.52))
                .lineLimit(1)

            Spacer(minLength: 8)

            if groupe.cardio {
                // CARDIO, SANS LES FLAMMES (verdict 15-09 : « même UI, sans
                // les flammes ») — les flammes comptent des séries. À leur
                // place, la ligne de résumé : « 3 intervalles · 6:40 ».
                Text(groupe.resume)
                    .font(.inter(12, .medium))
                    .monospacedDigit()
                    .foregroundStyle(Color.white.opacity(depliee ? 0.62 : 0.36))
                    .lineLimit(1)
                    .fixedSize()
            } else {
                // Les flammes-stickers, GELÉES (t = 0, aucune horloge, aucune
                // cérémonie) : la partition est un replay, pas une séance.
                FlammesRow(done: groupe.done, total: groupe.rows.count,
                           t: 0, date: .distantPast, igniteAt: nil,
                           corps: 22, ceremonie: false)
            }
        }
        // Le chevron et la vignette sont MORTS (26-08) : « les chevrons
        // c'est pas fou », et la photo décodait 6,3 Mo pour 30 pt.
        .padding(.leading, 4)
        .padding(.trailing, 6)
        .padding(.top, 18)
        .padding(.bottom, 10)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)

        if depliee {
            // Les lignes FONDENT en place, d'un seul bloc : sans
            // transition, l'animation de layout PROJETAIT les glyphes à
            // travers l'écran — les « petites pièces qui sortent ».
            VStack(spacing: 4) {
                ForEach(groupe.rows.indices, id: \.self) { i in
                    SetHistoryRow(rank: i + 1,
                                  ligne: groupe.rows[i])
                }
            }
            .transition(.opacity)
            // Le détail se tape aussi : replier — sans ça, les lignes
            // dépliées étaient une zone morte (l'audit du 18-08).
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
        }
    }
}
