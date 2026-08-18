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
                        docked: true)
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
                           basAir: safeBottom + 24)
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
    var reps: Int
    var kilos: Double
    var seconds: Int
    var done: Bool
}

struct SlateGroupe: Identifiable {
    let id: String
    var exercise: Exercise
    var rows: [SlateLigne]
    var done: Int { rows.filter(\.done).count }
    /// La clé bon marché de l'équatabilité — id, compte, faites : tout
    /// ce qui peut changer l'affichage.
    var cle: String { "\(id)-\(rows.count)-\(done)" }
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

    /// Les groupes dépliés — l'état vit ICI : le parent peut se
    /// réévaluer cent fois, le dépliement ne bronche pas.
    @State private var deplies: Set<String> = []
    @State private var seme = false

    static func == (l: Self, r: Self) -> Bool {
        l.courant == r.courant
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
        groupes.map { RangDonnee(groupe: $0,
                                 depliee: deplies.contains($0.id)) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 4) {
                ForEach(rangs) { r in
                    SlateRang(groupe: r.groupe,
                              depliee: r.depliee,
                              onTap: { bascule(r.groupe.id) })
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, basAir)
            .onGeometryChange(for: CGFloat.self) { $0.size.height }
                action: { onContentHeight($0) }
        }
        .scrollIndicators(.hidden)
        .onAppear {
            if !seme { seme = true; deplies = [courant] }
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
    var id: String { groupe.id }

    static func == (l: Self, r: Self) -> Bool {
        l.id == r.id && l.depliee == r.depliee
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
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            ExercisePhoto(exercise: groupe.exercise)
                .frame(width: 30, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 9,
                                            style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9,
                                     style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08),
                                      lineWidth: 1)
                )
            Text(groupe.exercise.name)
                .font(.inter(14, .semibold))
                .foregroundStyle(Color.white.opacity(0.92))
                .lineLimit(1)
            Spacer(minLength: 8)
            // Les flammes GELÉES : la pose de t = 0, pas d'horloge —
            // cinq exercices n'allument pas vingt-cinq animations.
            FlammesRow(done: groupe.done, total: groupe.rows.count,
                       t: 0, date: .distantPast, igniteAt: nil)
            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.30))
                .rotationEffect(.degrees(depliee ? 0 : -90))
        }
        .padding(.leading, 4)
        .padding(.trailing, 6)
        .padding(.top, 14)
        .padding(.bottom, 6)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)

        if depliee {
            // Les lignes FONDENT en place, d'un seul bloc : sans
            // transition, l'animation de layout PROJETAIT les glyphes à
            // travers l'écran — les « petites pièces qui sortent ».
            VStack(spacing: 4) {
                ForEach(groupe.rows.indices, id: \.self) { i in
                    SetHistoryRow(rank: i + 1,
                                  reps: groupe.rows[i].reps,
                                  kilos: groupe.rows[i].kilos,
                                  seconds: groupe.rows[i].seconds,
                                  done: groupe.rows[i].done)
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
