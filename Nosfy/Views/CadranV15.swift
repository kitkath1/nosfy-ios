import SwiftUI

// MARK: - La séance v15 autour de SON cadran (01-10, derrière `-seanceV7`)
//
// La maquette v15 (artefact 5UbBfJ33, « la v12 en plus beau ») : le cadran
// est le sien — `LiquidLensLab`, son dessin, ses braises, son repos au trait
// blanc — et rien ici ne le redessine. Ce fichier ne porte que ce qui
// l'ENTOURE : la tête de l'exercice, le bloc en lecture (le titre, sa ligne,
// la barre), son Stop pendant l'effort, la note sur place, et son slider qui
// lance la série suivante. Plus de feuille, plus de « Encore une série ? » :
// on enchaîne dans le même cadran (Kathryn : « ça parasite le cours du flow »).

/// Ce que la fiche confie au cadran pour la v15. Sa présence suffit à mettre
/// le cadran en mode v15 ; `nil`, le défaut, le laisse identique à hier.
struct CommandesV15 {
    var exercice: Exercise
    /// Le numéro de la série que porte le cadran, dans la séance.
    var rang: Int
    /// Les séries prévues de cet exercice (faites comprises).
    var total: Int
    /// Il reste une série de CET exercice après celle-ci. Sinon, après le
    /// repos, le slider lance l'exercice suivant (ou, s'il n'y en a plus,
    /// Valider rend la page de séance).
    var aSuivante: Bool
    /// La suite, en mots : « Série 3 · Woodchopper », ou l'exercice suivant.
    var ensuite: String?
    /// Quand la suite est un AUTRE exercice : son nom et sa charge proposée.
    var ensuiteNom: String? = nil
    var ensuiteCharge: String? = nil
    /// Les valeurs proposées (en gris tant qu'on n'y a pas touché).
    var reps: Int
    var kilos: Double
    var repos: Int
    /// Le temps de référence de l'effort, la droite de la barre.
    var reference: Int
    /// « Dernière fois 10 reps · 30 kg », s'il y a une dernière fois.
    var derniere: String?
    /// La séance comme un album : chaque exercice du plan, ses séries.
    var album: [AlbumExoV15] = []
    /// Le premier lancement depuis la page : la pastille ARRIVE dans sa
    /// fumée (la descente de la nuit), au lieu de naître posée.
    var arrivee: Bool = false
    var onReduire: () -> Void
    /// LE TIRAGE SPOTIFY (05-10, « ça saute un peu ») : UN SEUL doigt. Le
    /// cadran lit le geste (il sait seul si on a le droit de réduire — pas
    /// pendant l'effort ni la note) et la fiche déplace tout le lecteur.
    /// Avant, chacun tirait de son côté : deux décalages additionnés, puis
    /// deux retours qui se battaient.
    var onTirer: (CGFloat) -> Void = { _ in }
    /// Le doigt lâche : `true` si le seuil est franchi (la fiche se range).
    var onLacher: (Bool) -> Void = { _ in }
    /// La série est notée : la fiche l'écrit et joue ses toasters et pop-ups.
    var onNotee: (LiquidLensLab.SeriesOutcome) -> Void
    /// Le repos est fini (ou passé) : la fiche avance d'une série.
    var onPrete: () -> Void
    /// Le slider, quand la suite est un autre exercice : sa fiche le lance.
    var onExerciceSuivant: () -> Void = {}
    /// LA PLAYLIST (04-10) : « Ajouter une série » depuis l'onglet Séries,
    /// sans repasser par la page.
    var onAjouterSerie: () -> Void = {}
    /// (05-10, « supprimer une série, même dans la partie cadran ») : la
    /// piste k (de 1) glissée vers la gauche — une prévue, ou une faite.
    var onSupprimerSerie: (Int) -> Void = { _ in }

    /// Ce que le slider porte écrit : la PROCHAINE étape, quelle qu'elle soit.
    /// `versAutre` : la prochaine étape est l'exercice suivant. `prete` : la
    /// série prête est celle que le cadran porte déjà (sinon, la suivante).
    func legende(_ saisie: Exercise.Saisie, prete: Bool, versAutre: Bool)
        -> (titre: String, sous: String) {
        // Jamais de reps ni de poids prévus (02-10, « on ne sait pas à
        // l'avance ») : le titre et le nom, c'est tout.
        if versAutre, let e = ensuite {
            return (e, ensuiteCharge ?? "")
        }
        let n = prete ? rang : rang + 1
        return (L("Série \(n)", "Set \(n)"), nom)
    }

    var nom: String { exercice.nomLocalise }

    /// « 10 reps · 20 kg », « 15 reps », « Au chrono » : la série dans le
    /// slider, dite comme partout dans l'app (01-10 : « 10 × 20 kg » ne disait
    /// pas lequel était le poids).
    func charge(_ saisie: Exercise.Saisie) -> String {
        saisie.serie(reps: reps, kilos: kilos, secondes: 0)
    }
}

/// Un exercice de l'album : ce qui est fait, en mots, et ce qui reste.
struct AlbumExoV15: Identifiable, Equatable {
    let id: String
    let exercice: Exercise
    /// Les séries faites (« 12 × 22,5 kg », « 0:12 · 7 km/h »).
    let faites: [String]
    /// Les lignes à montrer : faites et prévues.
    let total: Int
    /// La valeur proposée des séries à venir.
    let propose: String
    let ici: Bool

    static func == (a: Self, b: Self) -> Bool {
        a.id == b.id && a.faites == b.faites && a.total == b.total
            && a.propose == b.propose && a.ici == b.ici
    }

    /// Une ligne de cardio, dite comme sur la page de séance.
    static func texte(_ l: SlateLigne, exo: Exercise) -> String {
        let t = String(format: "%d:%02d", l.seconds / 60, l.seconds % 60)
        switch l.genre {
        case .serie(let reps, let kilos):
            return exo.saisie.serie(reps: reps, kilos: kilos, secondes: l.done ? l.seconds : 0)
        case .intervalle(let v, let niveau), .course(let v, let niveau):
            let allure = niveau ? L("niveau \(Int(v))", "level \(Int(v))")
                                : "\(Exercise.Saisie.kg(v)) km/h"
            return "\(t) · \(allure)"
        case .longueurs(let n, let metres):
            return L("\(n) longueurs · \(metres) m", "\(n) lengths · \(metres) m")
        }
    }
}

/// Les repos qu'on choisit en segments, et le plus proche de celui proposé.
enum NoteRepos {
    static let choix = [45, 90, 120, 180]
    static func proche(_ r: Int) -> Int {
        choix.min { abs($0 - r) < abs($1 - r) } ?? 90
    }
}

/// Les moments de la série, tels que la tête et le bloc les disent.
enum PhaseV15: Equatable {
    case compte, effort, note, repos, prete, fin
}

// MARK: - L'habillage : la tête, le bloc en lecture, la commande

struct ChromeV15: View {
    let v: CommandesV15
    let saisie: Exercise.Saisie
    /// La nuit est tombée : avant, rien ne s'affiche (le geste du galet).
    let nuitDepuis: Date?
    /// L'instant où le chrono part (après le GO).
    let chronoDepuis: Date?
    let enNote: Bool
    let effortFige: Int
    let reposDepuis: Date?
    let reposDuree: Int
    let prete: Bool
    /// Ce qui est prêt est l'exercice suivant.
    let pretAutre: Bool
    let fin: Bool
    /// L'onglet Séries est ouvert.
    @Binding var vueSeries: Bool
    /// « Passer l'animation », tant que la pastille arrive (nil : posée).
    let passer: (() -> Void)?
    @Binding var reps: Int
    @Binding var kilos: Double
    @Binding var repos: Int
    @Binding var secondes: Int
    let stop: () -> Void
    let valider: () -> Void
    let lancer: () -> Void

    private func phase(_ now: Date) -> PhaseV15 {
        if fin { return .fin }
        if enNote { return .note }
        if reposDepuis != nil { return .repos }
        if prete { return .prete }
        if let c = chronoDepuis, now >= c { return .effort }
        return .compte
    }

    var body: some View {
        // DEUX FOIS PAR SECONDE, et seulement l'habillage : le cadran a sa
        // propre horloge, et ce texte ne change qu'à la seconde.
        TimelineView(.periodic(from: .now, by: 0.5)) { tl in
            let now = tl.date
            // À l'envol, l'habillage s'efface SANS changer de mots : il garde
            // ceux de la note qu'on vient de valider.
            let p = fin ? .note : phase(now)
            let visible = (nuitDepuis.map { now >= $0 } ?? false) && !fin
            // LA NOTE À LA APPLE (03-10, TestFlight 86 : « trop de texte, aère,
            // à la Apple ») : le lecteur se retire le temps de noter — le nom
            // seul en capitales, ni l'onglet, ni le bloc « Série 1 · à
            // noter » ; le cadran dit déjà la série. Il revient au repos.
            let enNote = p == .note
            VStack(spacing: 0) {
                TeteV15(v: v, reduire: p != .effort && !enNote, enNote: enNote)
                OngletV15(series: $vueSeries)
                    .padding(.top, 14)
                    .opacity(enNote ? 0 : 1)
                    .allowsHitTesting(!enNote)
                if vueSeries && !enNote {
                    AlbumV15(v: v, phase: p, rangCourant: rangCourant(p), onAjouterSerie: v.onAjouterSerie)
                        .padding(.top, 10)
                        .transition(.opacity)
                } else {
                    Spacer(minLength: 0)
                }
                if !enNote {
                    BlocV15(titre: titre(p), ligne: ligne(p), enCours: p == .effort,
                            barre: barre(p, now))
                        .padding(.horizontal, 26)
                        .transition(.opacity)
                }
                commande(p)
                    .padding(.top, p == .note ? 18 : 26)
            }
            // (01-10, « pas assez bas ») : la commande au ras de la zone sûre.
            .padding(.bottom, 0)
            // L'album flotte sur le cadran FLOUTÉ (flou posé dans la nuit, qui
            // ralentit dessous) ; un voile l'assourdit. `-sansFlouAlbum` : le
            // noir opaque d'avant.
            .background(Color.black.opacity(vueSeries ? (ChromeV15.sansFlou ? 1 : 0.42) : 0)
                .ignoresSafeArea())
            .animation(.easeInOut(duration: 0.3), value: vueSeries)
            .opacity(visible ? 1 : 0)
            .allowsHitTesting(visible)
            .animation(.easeOut(duration: 0.45), value: visible)
            .animation(.spring(response: 0.48, dampingFraction: 0.88), value: p)
        }
    }

    /// La série que l'album met en lumière, et ce qu'il dit à sa droite.
    private func rangCourant(_ p: PhaseV15) -> Int { p == .repos ? v.rang + 1 : v.rang }
    // MARK: Les mots

    private func titre(_ p: PhaseV15) -> String {
        switch p {
        case .repos: return L("Repos", "Rest")
        case .prete where pretAutre: return v.ensuiteNom ?? v.nom
        default: return L("Série \(v.rang)", "Set \(v.rang)")
        }
    }

    private func ligne(_ p: PhaseV15) -> String {
        // Moins de mots (01-10) : l'exercice est déjà dans la tête.
        let place = L("\(v.rang) sur \(v.total)", "\(v.rang) of \(v.total)")
        switch p {
        case .repos:
            return v.ensuite.map { L("Ensuite : ", "Next: ") + $0 } ?? ""
        case .effort: return L("en cours", "in progress") + " · \(place)"
        case .note: return L("à noter", "to log") + " · \(place)"
        case .prete where pretAutre: return L("exercice suivant", "next exercise")
        default: return L("prête", "ready") + " · \(place)"
        }
    }

    // MARK: La barre de lecture

    private func barre(_ p: PhaseV15, _ now: Date) -> BlocV15.Barre {
        switch p {
        case .repos:
            let e = reposDepuis.map { max(0, Int(now.timeIntervalSince($0))) } ?? 0
            let reste = max(0, reposDuree - min(e, reposDuree))
            return .init(fraction: Double(min(e, reposDuree)) / Double(max(reposDuree, 1)),
                         gauche: Self.mmss(min(e, reposDuree)),
                         droite: "−" + Self.mmss(reste))
        case .effort:
            let e = chronoDepuis.map { max(0, Int(now.timeIntervalSince($0))) } ?? 0
            return .init(fraction: min(1, Double(e) / Double(max(v.reference, 1))),
                         gauche: Self.mmss(e), droite: Self.mmss(v.reference))
        default:
            return .init(fraction: 0, gauche: "0:00", droite: Self.mmss(v.reference))
        }
    }

    /// Le relais d'une commande à l'autre : celle qui part s'efface d'abord,
    /// la suivante arrive ensuite — jamais deux commandes l'une sur l'autre.
    static let relais = AnyTransition.asymmetric(
        insertion: .opacity.animation(.easeOut(duration: 0.28).delay(0.18)),
        removal: .opacity.animation(.easeIn(duration: 0.16)))

    /// Barreau : l'album sur le noir opaque, sans le cadran flouté dessous.
    static let sansFlou = CommandLine.arguments.contains("-sansFlouAlbum")

    static func mmss(_ s: Int) -> String { String(format: "%d:%02d", s / 60, s % 60) }

    // MARK: La commande : son Stop, sa note, son slider

    @ViewBuilder
    private func commande(_ p: PhaseV15) -> some View {
        switch p {
        case .compte, .effort:
            // (05-10, « Passer l'animation est coupé ») : 100 + 4 + 16 + 4 + 26
            // = 150, le cadre — rien ne déborde plus sous la zone sûre.
            VStack(spacing: 4) {
                // (04-10, « le médaillon Stop plus gros ») : 88 pt.
                MedaillonStop(taille: 88, action: stop)
                    .opacity(p == .effort ? 1 : 0.35)
                    .allowsHitTesting(p == .effort)
                Text("Stop")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                if let passer, p == .compte {
                    Button(action: passer) {
                        Text(L("Passer l'animation", "Skip animation"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                            .frame(minHeight: 26)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(v.ensuite.map { L("Ensuite · ", "Next · ") + $0 } ?? " ")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.42))
                        .lineLimit(1)
                        .padding(.top, 6)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 150, alignment: .top)
            .transition(Self.relais)
        case .note:
            NoteV15(saisie: saisie, rang: v.rang, derniere: v.derniere,
                    avecRepos: v.aSuivante || v.ensuite != nil,
                    reps: $reps, kilos: $kilos, repos: $repos,
                    secondes: $secondes, valider: valider)
                .transition(Self.relais.combined(with: .offset(y: 24)))
        case .repos, .prete:
            // SON slider, avec la série écrite dedans : au repos, il lance la
            // suivante TOUT DE SUITE ; une fois prête, il la lance.
            SliderObsidienne(label: L("Lancer", "Start"), height: 62,
                             legende: v.legende(saisie, prete: p == .prete,
                                                versAutre: p == .prete ? pretAutre : !v.aSuivante),
                             onConfirm: lancer)
                .padding(.horizontal, 22)
                // (01-10, « le slider plus bas ») : posé au BAS de sa place.
                .frame(height: 150, alignment: .bottom)
                .transition(Self.relais)
        case .fin:
            Color.clear.frame(height: 150)
        }
    }
}

// MARK: - La tête

private struct TeteV15: View {
    let v: CommandesV15
    let reduire: Bool
    /// Pendant la note : le nom seul, en capitales espacées (la grammaire de
    /// l'écran « Let's go », qu'elle aime), centré.
    var enNote = false

    var body: some View {
        if enNote { nomSeul } else { tete }
    }

    private var nomSeul: some View {
        Text(v.nom.uppercased())
            .font(.inter(12.5, .medium))
            .tracking(3.6)
            .foregroundStyle(.white.opacity(0.46))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, 62)
            .padding(.top, 14)
            .transition(.opacity)
    }

    private var tete: some View {
        HStack(spacing: 12) {
            // ⚠️ PAS UN `Button` (01-10, « quand je clique sur le chevron pour
            // réduire ça marche pas ») : le toucher se perdait. Un toucher
            // PRIORITAIRE, sur une zone de 48 pt — le remède de son Stop.
            Image(systemName: "chevron.down")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 38, height: 38)
                .background(Circle().fill(.white.opacity(0.08)))
                .overlay(Circle().strokeBorder(.white.opacity(0.14), lineWidth: 1))
                .frame(width: 48, height: 48)
                .contentShape(Rectangle())
                .highPriorityGesture(TapGesture().onEnded {
                    Haptique.leger()
                    v.onReduire()
                })
                .accessibilityAddTraits(.isButton)
            .opacity(reduire ? 1 : 0.32)
            .allowsHitTesting(reduire)
            .accessibilityLabel(L("Revenir à la séance", "Back to the session"))
            ExercisePhoto(exercise: v.exercice)
                .frame(width: 40, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1))
            VStack(alignment: .leading, spacing: 2) {
                Text(v.nom)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Text(v.exercice.muscle)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.leading, 14)
        .padding(.trailing, 20)
        .padding(.top, 14)
    }
}

// MARK: - L'onglet Cadran | Séries

/// LE TOGGLE EN LIQUID GLASS INTERACTIF (01-10, « c'est pas liquid glass
/// interactif le toggle ») : la pastille est un VRAI verre — clair, teinté de
/// blanc, `.interactive()` : il répond sous le doigt — et elle MORPHE d'un
/// côté à l'autre (deux verres du même `glassEffectID` dans un
/// `GlassEffectContainer` : le natif d'iOS 26, aucun verre refait à la main).
/// On touche un côté, ou on glisse de l'un à l'autre, comme le contrôle
/// d'Apple.
/// ⚠️ Le piège payé le 04-09 : un verre interactif VOLE le toucher à un
/// `.gesture()` de l'hôte. Le geste du toggle est donc SIMULTANÉ : le verre
/// et la sélection reçoivent le doigt tous les deux.
private struct OngletV15: View {
    @Binding var series: Bool
    @Namespace private var ns
    private static let largeur: CGFloat = 214

    var body: some View {
        GlassEffectContainer(spacing: 0) {
            HStack(spacing: 0) {
                segment(L("Cadran", "Dial"), actif: !series)
                segment(L("Séries", "Sets"), actif: series)
            }
            .padding(4)
        }
        .frame(width: Self.largeur)
        .background(
            Capsule().fill(.white.opacity(0.07))
                .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1)))
        .contentShape(Capsule())
        .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { v in
            choisir(v.location.x > Self.largeur / 2)
        })
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(series ? L("Séries", "Sets") : L("Cadran", "Dial"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { choisir(!series) }
    }

    private func choisir(_ v: Bool) {
        guard v != series else { return }
        Haptique.leger()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) { series = v }
    }

    private func segment(_ t: String, actif: Bool) -> some View {
        Text(t)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white.opacity(actif ? 1 : 0.55))
            .frame(maxWidth: .infinity, minHeight: 34)
            // Le verre est posé SUR le mot (le mot passe devant, au lieu d'être
            // réfracté par un verre posé derrière lui — le « Cadran » dédoublé
            // du 01-10). L'autre côté a un verre `.identity`, et l'ID passe de
            // l'un à l'autre : la lentille glisse en se déformant.
            .glassEffect(actif ? .clear.tint(.white.opacity(0.16)).interactive() : .identity,
                         in: Capsule())
            .glassEffectID(actif ? "lentille" : "repos-\(t)", in: ns)
    }
}

// MARK: - L'album : la séance, exercice par exercice, série par série

/// LA SÉANCE COMME UNE FILE D'ATTENTE, À L'APPLE (01-10, deuxième passe :
/// « plus Apple, pas IA slop, trop de texte »). Le moins de mots possible :
/// l'exercice en cours a sa vignette et son nom, ses séries ne sont qu'un
/// numéro (ou sa flamme, ou ses barres) et leur valeur ; les autres exercices
/// tiennent en UNE ligne. Pas de cadre, pas de séparateur, pas de sous-titre —
/// le temps et l'état, le bloc en lecture les dit déjà dessous. La liste
/// flotte sur le cadran flouté et s'efface en fondu à ses bords.
private struct AlbumV15: View {
    let v: CommandesV15
    let phase: PhaseV15
    let rangCourant: Int
    var onAjouterSerie: () -> Void
    @State private var montre = false

    private var ici: AlbumExoV15? { v.album.first(where: \.ici) }

    /// LA PLAYLIST (04-10, « mets pas À suivre, rends-la encore plus jolie,
    /// limite d'ici on peut rajouter une série ») : SEUL l'exercice en cours,
    /// ses séries comme les morceaux d'un album — la faite avec sa flamme et
    /// sa valeur, celle qui se joue avec l'égaliseur, les prochaines par leur
    /// numéro — et « Ajouter une série » au bout. Rien d'autre.
    var body: some View {
        ScrollView(showsIndicators: false) {
            if let x = ici {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(1...max(1, x.total), id: \.self) { k in
                        GlisserPourSupprimerV15(actif: supprimable(x, k),
                                                onSupprimer: { v.onSupprimerSerie(k) }) { ligne(x, k) }
                            .opacity(montre ? 1 : 0)
                            .offset(y: montre ? 0 : 10)
                            .animation(.spring(response: 0.55, dampingFraction: 0.88)
                                .delay(0.045 * Double(k)), value: montre)
                    }
                    if x.exercice.tracking == .setsRepsWeight {
                        ajouter
                            .opacity(montre ? 1 : 0)
                            .animation(.spring(response: 0.55, dampingFraction: 0.88)
                                .delay(0.045 * Double(x.total + 1)), value: montre)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 18)
            }
        }
        .mask(
            LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.07),
                .init(color: .black, location: 0.88),
                .init(color: .clear, location: 1),
            ], startPoint: .top, endPoint: .bottom))
        .onAppear { montre = true }
    }

    private enum Etat { case fait, joue, prete, avenir }

    /// Une prévue qui n'est pas celle qui vient, ou une faite déjà écrite ;
    /// jamais celle qui se joue ni celle qui est prête.
    private func supprimable(_ x: AlbumExoV15, _ k: Int) -> Bool {
        guard x.exercice.tracking == .setsRepsWeight else { return false }
        switch etat(x, k) {
        case .avenir: return true
        case .fait: return k <= x.faites.count
        case .joue, .prete: return false
        }
    }

    private func etat(_ x: AlbumExoV15, _ k: Int) -> Etat {
        // La série qu'on vient de valider compte faite, même si son
        // écriture n'est pas encore tombée.
        if k <= x.faites.count || (phase == .repos && k <= v.rang) { return .fait }
        guard k == rangCourant else { return .avenir }
        return phase == .effort ? .joue : .prete
    }

    /// Une piste : le numéro (ou la flamme, ou l'égaliseur), la valeur, un
    /// filet. La piste qui se joue est un ton plus clair, comme Spotify.
    private func ligne(_ x: AlbumExoV15, _ k: Int) -> some View {
        let e = etat(x, k)
        let valeur = e == .fait && k <= x.faites.count ? x.faites[k - 1]
            : L("Série \(k)", "Set \(k)")
        let lumiere = e == .joue || e == .prete
        return HStack(spacing: 16) {
            ZStack {
                switch e {
                case .fait:
                    // Le vrai sticker (05-10, « c'est blanc là ? »).
                    Image("sticker-flamme-serree")
                        .resizable().scaledToFit()
                        .frame(width: 15, height: 19)
                case .joue: EgaliseurV15()
                case .prete, .avenir:
                    Text("\(k)")
                        .font(.system(size: 15, weight: lumiere ? .semibold : .regular))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(lumiere ? 0.95 : 0.3))
                }
            }
            .frame(width: 22, height: 22)
            Text(valeur)
                .font(.system(size: 17, weight: lumiere ? .semibold : .regular))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(lumiere ? 1 : (e == .fait ? 0.6 : 0.4)))
                .lineLimit(1)
            Spacer(minLength: 0)
            if e == .fait {
                Text(L("Série \(k)", "Set \(k)"))
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .frame(height: 54)
        .padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.white.opacity(e == .joue ? 0.09 : 0)))
        .overlay(alignment: .bottom) {
            Rectangle().fill(.white.opacity(0.08)).frame(height: 0.5).padding(.leading, 50)
        }
    }

    private var ajouter: some View {
        Button {
            Haptique.leger()
            onAjouterSerie()
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 22, height: 22)
                Text(L("Ajouter une série", "Add a set"))
                    .font(.system(size: 16, weight: .medium))
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white.opacity(0.5))
            .frame(height: 54)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Trois barres qui dansent : la série qui se joue, comme le morceau en cours.
private struct EgaliseurV15: View {
    static let braise = Color(red: 0.98, green: 0.36, blue: 0.20)

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                Barre(lent: [0.42, 0.31, 0.53][i], haut: [0.85, 1.0, 0.7][i])
            }
        }
        .frame(width: 14, height: 13)
    }

    private struct Barre: View {
        let lent: Double
        let haut: Double
        var body: some View {
            RoundedRectangle(cornerRadius: 1)
                .fill(EgaliseurV15.braise)
                .frame(width: 3)
                .phaseAnimator([0.3, haut]) { c, f in
                    c.scaleEffect(x: 1, y: f, anchor: .bottom)
                } animation: { _ in .easeInOut(duration: lent) }
        }
    }
}

// MARK: - Le bloc en lecture

private struct BlocV15: View, Equatable {
    struct Barre: Equatable {
        var fraction: Double
        var gauche: String
        var droite: String
    }
    let titre: String
    let ligne: String
    let enCours: Bool
    let barre: Barre?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(titre)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)
                .id(titre)
                .transition(.blurReplace)
            HStack(spacing: 7) {
                if enCours { PointEnCours() }
                Text(ligne)
                    .lineLimit(1)
                    .id(ligne)
                    .transition(.blurReplace)
            }
            .font(.system(size: 14))
            .foregroundStyle(.white.opacity(0.55))
            .padding(.top, 3)
            if let barre {
                VStack(spacing: 7) {
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.16))
                            Capsule().fill(.white)
                                .frame(width: max(3, g.size.width * barre.fraction))
                        }
                    }
                    .frame(height: 3)
                    .animation(.linear(duration: 0.5), value: barre.fraction)
                    HStack {
                        Text(barre.gauche).contentTransition(.numericText())
                        Spacer()
                        Text(barre.droite).contentTransition(.numericText())
                    }
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.top, 16)
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Le point rouge de braise qui bat : la série est en cours.
private struct PointEnCours: View {
    var body: some View {
        Circle()
            .fill(Color(red: 0.98, green: 0.30, blue: 0.20))
            .frame(width: 7, height: 7)
            .phaseAnimator([1.0, 0.35]) { c, o in c.opacity(o) } animation: { _ in
                .easeInOut(duration: 0.8)
            }
    }
}

// MARK: - La note sur place

/// Tes valeurs en grand (grises = proposées, blanches = touchées), une
/// molette comme le zoom de l'appareil photo, ton repos en segments, Valider.
/// La feuille d'avant a été refusée (« beaucoup trop gros ») : tout tient
/// sous le cadran, qui reste visible au-dessus.
private struct NoteV15: View {
    let saisie: Exercise.Saisie
    let rang: Int
    let derniere: String?
    let avecRepos: Bool
    @Binding var reps: Int
    @Binding var kilos: Double
    @Binding var repos: Int
    @Binding var secondes: Int
    let valider: () -> Void

    enum Champ: Hashable { case reps, kilos, temps }
    @State private var actif: Champ?

    private var champs: [Champ] {
        switch saisie {
        case .repsEtCharge: return [.reps, .kilos]
        case .repsSeules: return [.reps]
        case .tempsSeul: return [.temps]
        }
    }
    private var champActif: Champ { actif ?? champs[0] }

    // LA NOTE À LA APPLE (03-10, TestFlight 86 : « trop de texte, pas assez
    // aéré, à la Apple » — maquette `SaisieApple`, artefact CQEp5req). La
    // grammaire de l'écran « Let's go » : plus de « Série 1 · Dernière
    // fois… » au-dessus (le cadran dit la série) ; les valeurs entre deux
    // traits d'un point, en chiffres légers au blanc dégradé — celle que la
    // molette règle allumée, l'autre en retrait ; le repos en UNE ligne qui
    // ouvre le menu d'iOS ; le bouton noir de la maison, « Valider », seul.
    var body: some View {
        VStack(spacing: 0) {
            valeurs
            MoletteV15(valeur: liaison(champActif), pas: pas(champActif),
                       bornes: bornes(champActif)) {}
                .frame(height: 46)
                .padding(.top, 12)
                .id(champActif)
            if avecRepos { reposMenu.padding(.top, 6) }
            BoutonPrimaire(title: L("Valider", "Log"), respecteLaCasse: true) { valider() }
                .padding(.top, avecRepos ? 8 : 20)
        }
        .padding(.horizontal, 24)
    }

    private var valeurs: some View {
        HStack(alignment: .firstTextBaseline, spacing: 34) {
            ForEach(champs, id: \.self) { c in valeur(c) }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .overlay(alignment: .top) { Self.trait }
        .overlay(alignment: .bottom) { Self.trait }
        .padding(.horizontal, 6)
    }

    private static var trait: some View {
        Rectangle().fill(.white.opacity(0.22)).frame(height: 1)
    }

    private func valeur(_ c: Champ) -> some View {
        let allume = c == champActif || champs.count == 1
        return Button {
            Haptique.leger()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) { actif = c }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(texte(c))
                    .font(.inter(50, .light))
                    .tracking(-1)
                    .monospacedDigit()
                    .foregroundStyle(MotsFlou.blancDegrade)
                    .contentTransition(.numericText())
                if let u = unite(c) {
                    Text(u).font(.inter(17))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .opacity(allume ? 1 : 0.42)
        }
        .buttonStyle(.plain)
    }

    /// Le repos en une ligne : « Repos 1:30 ⌃⌄ », le menu d'iOS avec sa coche.
    private var reposMenu: some View {
        Menu {
            Picker(selection: $repos) {
                ForEach(NoteRepos.choix, id: \.self) { r in
                    Text(Self.lib(r)).tag(r)
                }
            } label: { EmptyView() }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: 8) {
                Text(L("Repos", "Rest"))
                    .foregroundStyle(.white.opacity(0.55))
                Text(Self.lib(repos))
                    .foregroundStyle(.white.opacity(0.88))
                    .contentTransition(.numericText())
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .font(.inter(16))
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .tint(.white)
        .onChange(of: repos) { Haptique.leger() }
    }

    static func lib(_ r: Int) -> String {
        if r < 60 { return "\(r) s" }
        if r % 60 == 0 { return "\(r / 60) min" }
        return ChromeV15.mmss(r)
    }

    private func texte(_ c: Champ) -> String {
        switch c {
        case .reps: return "\(reps)"
        case .kilos: return Exercise.Saisie.kg(kilos)
        case .temps: return ChromeV15.mmss(secondes)
        }
    }
    private func unite(_ c: Champ) -> String? {
        switch c {
        case .reps: return "reps"
        case .kilos: return "kg"
        case .temps: return nil
        }
    }
    private func pas(_ c: Champ) -> Double { c == .kilos ? 2.5 : 1 }
    private func bornes(_ c: Champ) -> ClosedRange<Double> {
        switch c {
        case .reps: return 0...100
        case .kilos: return 0...400
        case .temps: return 0...3600
        }
    }
    private func liaison(_ c: Champ) -> Binding<Double> {
        switch c {
        case .reps: return Binding(get: { Double(reps) }, set: { reps = Int($0) })
        case .kilos: return $kilos
        case .temps: return Binding(get: { Double(secondes) }, set: { secondes = Int($0) })
        }
    }
}

// MARK: - La molette

/// Une règle graduée qu'on glisse sous une aiguille fixe, comme le zoom de
/// l'appareil photo : le chiffre roule, un cran = un tic dans la main.
private struct MoletteV15: View {
    @Binding var valeur: Double
    let pas: Double
    let bornes: ClosedRange<Double>
    let onPas: () -> Void

    /// La prise en cours : son point de départ ET sa valeur d'origine. Un
    /// geste dont `onEnded` n'est jamais venu se reconnaît à son départ.
    @State private var prise: (debut: CGPoint, v0: Double)?
    @State private var glisse: Double?
    private static let ecart: CGFloat = 12
    private static let tic = UISelectionFeedbackGenerator()

    var body: some View {
        Canvas { ctx, size in
            let mid = size.width / 2
            let pos = (glisse ?? valeur) / pas
            let n = Int(mid / Self.ecart) + 2
            let k0 = Int(floor(pos))
            for k in (k0 - n)...(k0 + n) {
                let x = mid + CGFloat(Double(k) - pos) * Self.ecart
                guard x >= 0, x <= size.width else { continue }
                let majeur = k % 5 == 0
                let hh: CGFloat = majeur ? 18 : 10
                let bord = max(0, 1 - abs(x - mid) / mid)
                let a = (majeur ? 0.55 : 0.26) * Double(bord)
                ctx.fill(Path(CGRect(x: x - 0.5, y: (size.height - hh) / 2, width: 1, height: hh)),
                         with: .color(.white.opacity(a)))
            }
            ctx.fill(Path(roundedRect: CGRect(x: mid - 1, y: size.height / 2 - 15,
                                              width: 2, height: 30), cornerRadius: 1),
                     with: .color(.white))
        }
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 2)
            .onChanged { g in
                if prise == nil || prise?.debut != g.startLocation {
                    prise = (g.startLocation, valeur)
                    Self.tic.prepare()
                }
                guard let p = prise else { return }
                let brut = min(max(p.v0 - Double(g.translation.width / Self.ecart) * pas,
                                   bornes.lowerBound), bornes.upperBound)
                glisse = brut
                let v = (brut / pas).rounded() * pas
                if v != valeur {
                    valeur = v
                    Self.tic.selectionChanged()
                    onPas()
                }
            }
            .onEnded { _ in
                prise = nil
                glisse = nil
            })
        .accessibilityElement()
        .accessibilityValue(Exercise.Saisie.kg(valeur))
        .accessibilityAdjustableAction { d in
            let v = d == .increment ? valeur + pas : valeur - pas
            valeur = min(max(v, bornes.lowerBound), bornes.upperBound)
            onPas()
        }
    }
}


// MARK: - Glisser pour supprimer (05-10)

/// GLISSER POUR SUPPRIMER, à la iOS : le rouge se découvre sous la piste qui
/// part vers la gauche, sa largeur suit le doigt ; un tap la referme. Le
/// contenu garde ses propres gestes (simultané).
struct GlisserPourSupprimerV15<Content: View>: View {
    var actif: Bool
    var onSupprimer: () -> Void
    @ViewBuilder var content: () -> Content

    @State private var dx: CGFloat = 0
    @State private var ouvert = false
    private static var rouge: CGFloat { 92 }
    private var decalage: CGFloat { (ouvert ? -Self.rouge : 0) + dx }

    var body: some View {
        ZStack(alignment: .trailing) {
            if actif {
                Button(action: { Haptique.moyen(); ouvert = false; onSupprimer() }) {
                    Text(L("Supprimer", "Delete"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .fixedSize()
                        .frame(width: max(0, -decalage))
                        .frame(maxHeight: .infinity)
                        .background(Color(red: 1, green: 0.27, blue: 0.23))
                        .clipped()
                }
                .buttonStyle(.plain)
                .opacity(decalage < -2 ? 1 : 0)
            }
            content()
                .offset(x: decalage)
                .contentShape(Rectangle())
                .simultaneousGesture(TapGesture().onEnded {
                    if ouvert { withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) { ouvert = false } }
                })
                .simultaneousGesture(glisser, isEnabled: actif)
        }
        .clipped()
    }

    private var glisser: some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { v in
                guard abs(v.translation.width) > abs(v.translation.height) else { return }
                dx = min(Self.rouge * 0.4, max(-Self.rouge * 1.3, v.translation.width))
            }
            .onEnded { v in
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                    if abs(v.translation.width) > abs(v.translation.height) {
                        ouvert = (ouvert ? -Self.rouge : 0) + v.translation.width < -Self.rouge / 2
                    }
                    dx = 0
                }
            }
    }
}
