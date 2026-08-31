import SwiftUI

// MARK: - La pastille de séance en cours

/// La pastille de séance — le mini-player de la maison, revenu du décor :
/// la pierre obsidienne posée en dock SOUS le galet d'aube, façon lecteur
/// au bas de page. Vignette, titre, sous-titre, pause, STOP, filet de
/// progression : elle parle désormais entraînement, plus musique.
///
/// La pierre ne vit que par le noir remonté sous un cheveu de lumière :
/// jadis dans l'échancrure de la carte blanche, aujourd'hui sur la nacre
/// du galet — elle se lit CONTRE le clair, jamais sur la nuit nue.
///
/// v1 DESIGN : la pause reste un placeholder visuel et le stop est posé
/// mais INERTE — son panneau « Terminer la séance ? » est le prochain
/// chantier. Le filet et le chrono, eux, sont vrais.
/// LE MÉDAILLON DU STOP — extrait de WorkoutPill (30-08) pour VOYAGER : le
/// morph du player transporte le MÊME objet de la dalle au centre-bas
/// déployé, jamais un mime. `lueur` pilote la respiration des liserés
/// (l'hôte l'anime ; figée à `true` en vol).
struct MedaillonStop: View {
    var symbol: String = "stop.fill"
    var neon: Bool = false
    var lueur: Bool = true
    var action: () -> Void = {}

    var body: some View {
        ZStack {
            // Le disque laqué — la lumière prend en haut-gauche.
            Circle()
                .fill(RadialGradient(
                    colors: [Color(white: 0.105), Color(white: 0.035)],
                    center: UnitPoint(x: 0.38, y: 0.30),
                    startRadius: 2, endRadius: 24))
            // Le petit halo chaud — l'ambiance du médaillon, en sourdine.
            Circle()
                .fill(RadialGradient(
                    stops: [
                        .init(color: FlammePalette.flamme
                            .opacity(neon ? 0.11 : 0.06), location: 0),
                        .init(color: FlammePalette.or.opacity(0.025),
                              location: 0.55),
                        .init(color: .clear, location: 1),
                    ], center: .center, startRadius: 0, endRadius: 20))
                .blendMode(.plusLighter)
                .opacity(lueur ? 1.0 : 0.62)
            if neon {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(FlammePalette.neon)
                    .shadow(color: FlammePalette.coeur.opacity(0.45),
                            radius: 3)
            } else {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(FlammePalette.blanc.opacity(0.92))
            }
        }
        .frame(width: 34, height: 34)
        // Le liseré premium, aux crans du médaillon.
        .overlay {
            Circle()
                .stroke(AngularGradient(stops: LisereMedaillon.crans,
                                        center: .center, angle: .zero),
                        lineWidth: 0.8)
                .opacity(lueur ? 1.0 : 0.78)
        }
        // La bague : `stroke` centré, elle déborde DEHORS du disque.
        .overlay {
            Circle()
                .stroke(AngularGradient(stops: LisereMedaillon.bague,
                                        center: .center, angle: .zero),
                        lineWidth: 2.4)
                .frame(width: 36.5, height: 36.5)
                .blur(radius: 1.0)
                .blendMode(.plusLighter)
                .opacity(0.85)
        }
        .contentShape(Circle())
        // LA ZONE DE TAP passe le disque : 34 pt de médaillon, 44 pt de
        // doigt (le minimum d'Apple), posée AVANT le geste.
        .padding(8)
        .contentShape(Circle())
        .highPriorityGesture(TapGesture().onEnded { action() })
    }
}

/// LA VEINE D'OR — le filet de progression de la dalle, extrait (30-08) pour
/// VOYAGER : la même veine sous le héros du player déployé. Une barre nue
/// (2,5 pt) — les paddings restent chez l'hôte.
struct VeineOr: View {
    var progress: Double
    var lueur: Bool = true

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width * min(max(progress, 0.04), 1)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.10))
                Capsule()
                    .fill(LinearGradient(
                        colors: [FlammePalette.or.opacity(0.10),
                                 FlammePalette.or.opacity(0.75),
                                 FlammePalette.blanc],
                        startPoint: .leading, endPoint: .trailing))
                    .frame(width: w)
                // La perle de braise — jamais un point : une lumière.
                Circle()
                    .fill(RadialGradient(
                        colors: [FlammePalette.blanc,
                                 FlammePalette.braise.opacity(0.85),
                                 FlammePalette.coeur.opacity(0)],
                        center: .center, startRadius: 0, endRadius: 5))
                    .frame(width: 10, height: 10)
                    .blur(radius: 1.2)
                    .blendMode(.plusLighter)
                    .opacity(lueur ? 1.0 : 0.62)
                    .position(x: w, y: geo.size.height / 2)
                Circle()
                    .fill(FlammePalette.blanc)
                    .frame(width: 2.6, height: 2.6)
                    .position(x: w, y: geo.size.height / 2)
            }
        }
        .frame(height: 2.5)
    }
}

struct WorkoutPill: View {
    let exercise: Exercise
    /// Fraction de la séance accomplie, pour le filet de progression.
    var progress: Double = 0
    /// Le départ de la séance : le sous-titre devient chrono. `nil`,
    /// l'attente — le libellé seul.
    var startedAt: Date? = nil
    /// LA DALLE : `true`, la pierre s'INCRUSTE dans les bords de l'écran
    /// (verdict : « posée » ne suffit pas) — pleine largeur, coins bas
    /// morts au ras du bord physique, liseré qui meurt avant le bord
    /// (la loi du CADRE FANTÔME). `false`, la pierre flottante d'origine
    /// (l'échancrure de la carte blanche).
    var docked: Bool = false
    /// LE LISERÉ DE LA DALLE. Sur la home, la bande découverte n'est pas une
    /// carte posée sur une page : c'est le SOL sous la card. Un trait autour
    /// d'elle la redécoupe en objet et redonne un bord de plus à une page qui
    /// en a déjà deux (verdict 22-08 : « enlève tout le border de l'overlay »).
    var lisere: Bool = true
    /// Le bilan pour le panneau du stop — séries validées et exercices
    /// de la séance (l'hôte les connaît ; la vraie séance les nourrira).
    var doneSeries: Int = 0
    var exoCount: Int = 0
    /// LE MORPH DU STOP (PageCard, 30-08) : pendant la levée du player, le
    /// stop de la dalle s'ÉTEINT — son fantôme descend se poser au centre-bas.
    /// Un seul stop visible à tout instant. `true` partout ailleurs.
    var stopVisible: Bool = true
    /// LA DALLE v7 (héros-jour, 30-08) : `jour` affiche la MINI-CARD JOUR à
    /// la place de la lune (la date vit LÀ — le titre dit l'exercice en
    /// cours), `jourSticker` son sticker, `jourVisible` éteint la vignette
    /// pendant le VOL du héros (un seul objet en vol), `titreCourant`
    /// remplace « Session · date ». `nil`/`true` partout ailleurs : les
    /// montages home/exos/détail restent intacts.
    var jour: Date? = nil
    var jourSticker: String = ""
    var jourVisible: Bool = true
    var titreCourant: String? = nil
    /// LA HAUTEUR DE LA DALLE (30-08, « tout est trop collé ») : 76 partout
    /// (la home intacte), le player la monte à 86 — le contenu se centre,
    /// l'air revient entre le titre et la barre.
    var hauteurDock: CGFloat = 76

    /// `-stopSheet` ouvre le panneau de fin à la naissance (captures).
    /// ⚠️ Il passe désormais par l'état GLOBAL : le panneau vit à la racine.

    private let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
    private let dockShape = UnevenRoundedRectangle(
        topLeadingRadius: 22, bottomLeadingRadius: 0,
        bottomTrailingRadius: 0, topTrailingRadius: 22, style: .continuous)

    var body: some View {
        HStack(spacing: 12) {
            // LA VIGNETTE : en dock, le player parle de TOUTE la séance —
            // le glyphe de la maison remplace la photo d'exercice
            // (verdict 17-08 : « c'est toute la session »).
            if docked {
                if let jour {
                    // LA MINI-CARD JOUR (v7) — la date de la séance en
                    // vignette, éteinte pendant le vol du héros.
                    // ⚠️ À SA TAILLE NATIVE (70×78) puis RÉDUITE en scale :
                    // ses encres internes ne rétrécissent pas avec
                    // largeur/hauteur — à 40×48 la flamme mangeait « AOÛT ».
                    MiniCardJour(date: jour, sticker: jourSticker,
                                 stickerBasGauche: true)
                        .scaleEffect(0.58)
                        .frame(width: 42, height: 47)
                        // L'air entre l'image et le titre (verdicts v9.3 et
                        // T1 : encore trop collés à 6).
                        .padding(.trailing, 11)
                        .opacity(jourVisible ? 1 : 0)
                        .animation(.easeOut(duration: 0.15),
                                   value: jourVisible)
                } else {
                    sessionMoon
                }
            } else {
                ExercisePhoto(exercise: exercise)
                    .frame(width: 42, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 12,
                                                style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08),
                                          lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                // En dock, le player parle de la SÉANCE : « Session du
                // 17 août », jamais le nom d'un exercice (verdict 17-08).
                // LA LOCALE EST FORCÉE (22-08). `.formatted` suit celle du
                // TÉLÉPHONE : sur un appareil français il rendait « 22 août »
                // au milieu d'une UI passée en anglais — et l'ordre des
                // termes change aussi de langue (jour-mois vs mois-jour).
                // Une date n'est pas un libellé qu'on traduit, c'est un
                // format qu'on impose.
                Text(docked
                     ? (titreCourant
                        ?? "Session · \((startedAt ?? .now).formatted(.dateTime.month(.wide).day().locale(Locale(identifier: "en_US"))))")
                     : exercise.name)
                    .font(.inter(14, .semibold))
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)
                subtitle
            }

            Spacer(minLength: 8)

            // UN SEUL bouton, le stop (verdict 18-08 : « finalement il
            // n'y a que le stop ») — la pause-placeholder est morte.
            if docked {
                medallionButton("stop.fill") { demanderLaPause() }
                    .opacity(stopVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.15), value: stopVisible)
            } else {
                roundButton("stop.fill") { demanderLaPause() }
            }
            // ⚠️ Les deux boutons ci-dessus ne sont PLUS des `Button` : ils
            // portent un `highPriorityGesture(TapGesture())`. Le pourquoi est
            // écrit sur `medallionButton` — un `Button` posé sous un
            // `DragGesture` d'ancêtre se fait ANNULER dès que le drag
            // reconnaît, et le stop ne partait jamais.
        }
        .padding(.leading, docked ? 20 : 11)
        .padding(.trailing, docked ? 16 : 12)
        // En dock, la dalle grandit (64 → 76) et le contenu descend :
        // l'air vit ENTRE le trait-poignée et la ligne (« c'est trop
        // collé »), pas sous elle — le filet et l'indicateur gardent
        // leur bas.
        // Le contenu REMONTE dans la dalle haute (T1.2 : « pas d'espace
        // entre la progress bar et le contenu ») — l'air vit sous lui.
        .padding(.top, docked ? 6 : 0)
        .padding(.bottom, docked ? 16 : 0)
        .frame(maxWidth: .infinity)
        .frame(height: docked ? hauteurDock : 64)
        // ⚠️ **LE SOUFFLE N'EST PLUS ICI — ET C'ÉTAIT ÇA, LE PLAYER QUI
        // FLOTTE** (26-08). Verdict de Kathryn : « le logo Lune du player
        // flotte, le bouton Stop flotte, ils remontent et redescendent
        // légèrement — ils doivent être parfaitement fixes ».
        //
        // Le correctif du 25-08 avait bien SCOPÉ l'animation (`value: lueur`
        // au lieu d'un `withAnimation` à l'`onAppear`), mais il l'avait posée
        // TROP HAUT : ici, au-dessus des `.padding` et du `.frame(height:)`
        // du pill. Or `lueur` ne pilote QUE des opacités. Elle bascule dans un
        // `onAppear` qui tombe PENDANT l'insertion animée du pill (le
        // `withAnimation(0,62 s)` de l'entrée en séance) : la géométrie EN VOL
        // héritait donc de l'aller-retour infini de 2,6 s — 5,2 s le cycle,
        // exactement la période mesurée à la mitraille. Une animation ne doit
        // jamais couvrir plus que ce que sa valeur touche : elle descend sur
        // les DEUX vues qui lisent `lueur`, la lune et le médaillon.
        .background {
            // ⚠️ LA DALLE EST NOIRE, PAS GRISE — et c'est une loi du
            // composant, pas un réglage de page (verdict 22-08 :
            // « l'overlay session doit être noir pour se fondre »).
            //
            // Le dock n'est pas un objet posé SUR une page : c'est le SOL
            // que la card découvre en se levant. Un gris, même à 4,5 %,
            // se détache de la nuit et se lit comme un panneau rapporté ;
            // le noir FOND, et il ne reste que ce qui doit vivre — le
            // glyphe de la lune, l'encre, la veine d'or.
            //
            // La pilule FLOTTANTE, elle, garde son gris : elle est posée
            // sur une carte claire et doit exister COMME objet. La même
            // matière, deux rôles opposés.
            if docked { dockShape.fill(Color.black) }
            else { shape.fill(Color(white: 0.045)) }
        }
        .overlay {
            if docked, lisere {
                // Le liseré d'une dalle incrustée n'a pas de bas : il
                // meurt aux deux tiers — un trait au ras du bord physique
                // serait le CADRE FANTÔME.
                dockShape.strokeBorder(
                    LinearGradient(stops: [
                        .init(color: .white.opacity(0.10), location: 0),
                        .init(color: .white.opacity(0.03), location: 0.4),
                        .init(color: .clear, location: 0.65),
                    ], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1)
            } else if !docked, lisere {
                shape.strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
            }
        }
        // Le filet de progression, posé sur le bord bas comme dans la
        // référence : un cheveu, pas une barre. En dock : LA VEINE D'OR.
        .overlay(alignment: .bottom) {
            if docked {
                veine
            } else {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.14))
                        Capsule().fill(Color.white.opacity(0.85))
                            .frame(width: geo.size.width
                                   * min(max(progress, 0.04), 1))
                    }
                }
                .frame(height: 2.5)
                .padding(.horizontal, 14)
                .padding(.bottom, 7)
            }
        }
        .contentShape(docked ? AnyShape(dockShape) : AnyShape(shape))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Workout in progress — \(exercise.name)")
    }

        // ⚠️ **LE STOP EST UN ÉTAT GLOBAL, PLUS UN COVER LOCAL** (26-08,
        // verdict n° 1 : « le bouton Stop ne répond pas, je me retrouve
        // bloquée dans une session active sans moyen fiable de la fermer »).
        //
        // Le panneau était un `fullScreenCover` porté par LA PASTILLE
        // ELLE-MÊME. Trois conséquences, toutes vécues :
        //   · chaque instance du player avait SON état — trois pastilles dans
        //     l'app, trois `stopAsk` qui s'ignorent ;
        //   · la fiche détail n'en monte AUCUNE (mesuré : zéro occurrence),
        //     donc de là il n'existait littéralement aucun bouton pour finir ;
        //   · et depuis une page déjà présentée dans un cover, présenter un
        //     second cover depuis une vue enfouie ne mène nulle part.
        //
        // Or le panneau de fin EXISTE DÉJÀ à la racine (`PausePanneauHote`,
        // WoopApp), au-dessus du TabView, câblé sur `terminerSeance()` — donc
        // sur la vraie clôture, le trophée, les pièces et la pop-up booster.
        // Le player n'a rien à présenter : il DEMANDE. Un seul panneau, un
        // seul état, joignable de partout.
    private func demanderLaPause() {
        // SONDE (26-08 : « ça marche toujours pas le bouton stop ») — elle
        // tranche entre « le tap ne part jamais » et « le tap part, le
        // panneau ne monte pas ». À lire à la console de l'appareil, à
        // retirer une fois le verdict rendu.
        print("[SONDE-STOP] tap stop reçu (docked=\(docked)) — pauseOuverte ← true")
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            DepartEtat.shared.pauseOuverte = true
        }
    }

    /// LE SOUFFLE du halo de la lune — la grammaire du petit néon des
    /// lignes d'historique : UNE animation `repeatForever`, jamais une
    /// TimelineView de plus (le chrono en tient déjà une).
    /// Le souffle de la lune et de la braise. ⚠️ En DOCK il ne souffle pas :
    /// il naît DÉJÀ au maximum et n'en bouge plus (cf. `onAppear` plus bas).
    @State private var lueur = false

    /// LA LUNE DE LA SÉANCE : le glyphe de la maison (« il n'y a qu'UNE
    /// lune dans cette app ») sur son double halo — l'orange derrière,
    /// le blanc plus serré devant — qui PULSENT ensemble. La lueur reste
    /// une lueur : elle commence après le croissant et meurt avant le
    /// bord, jamais un fond (la leçon de la lune de la story).
    private var sessionMoon: some View {
        ZStack {
            // Léger veut dire léger : à 0,30 sur un grand rayon, le halo
            // remplissait le slot et virait au DISQUE BRUN sur
            // l'obsidienne — la lueur commence après le croissant et
            // meurt avant le bord.
            Circle()
                .fill(RadialGradient(
                    colors: [Color(red: 1.0, green: 0.46, blue: 0.09)
                        .opacity(lueur ? 0.22 : 0.08), .clear],
                    center: .center, startRadius: 6, endRadius: 18))
            Circle()
                .fill(RadialGradient(
                    colors: [Color.white.opacity(lueur ? 0.15 : 0.05),
                             .clear],
                    center: .center, startRadius: 2, endRadius: 12))
            MoonShape()
                .fill(LinearGradient(
                    colors: [Color(red: 0.200, green: 0.196, blue: 0.190),
                             Color(red: 0.062, green: 0.060, blue: 0.058)],
                    startPoint: .top, endPoint: .bottom))
                .overlay {
                    MoonShape()
                        .stroke(LinearGradient(
                            colors: [Color.white.opacity(lueur ? 1.00 : 0.78),
                                     Color.white.opacity(lueur ? 0.55 : 0.32)],
                            startPoint: .top, endPoint: .bottom),
                            lineWidth: 1.0)
                }
                .frame(width: 20, height: 20)
        }
        .frame(width: 42, height: 42)
        // ⚠️ JAMAIS un `withAnimation(.repeatForever)` à l'onAppear : la
        // transaction infinie FUIT dans le layout des ancêtres — la page
        // exo entière respirait à 5,2 s (mesuré à la mitraille, 25-08).
        // ⚠️ ET L'ANIMATION VIT ICI, PAS SUR LE BODY (26-08) : posée sur le
        // pill entier elle passait AU-DESSUS de ses paddings et de sa
        // hauteur, et capturait la géométrie en vol de l'insertion — le
        // player « flottait » à 5,2 s. Elle ne couvre plus que la lune,
        // c'est-à-dire exactement ce que `lueur` touche.
        .animation(docked ? nil
                   : .easeInOut(duration: 2.6)
                        .repeatForever(autoreverses: true),
                   value: lueur)
        // ⚠️ **EN DOCK, LA LUNE NE RESPIRE PLUS** (26-08, verdict n° 8 :
        // « le logo Lune du player flotte, le bouton Stop flotte, ils
        // remontent et redescendent légèrement — ils doivent être
        // PARFAITEMENT fixes »).
        //
        // MESURÉ, et ça corrige mon diagnostic du lot 3. Huit captures de la
        // page exercices, séance ouverte :
        //   · le BORD HAUT de la dalle : **794,67 pt sur les huit** — la
        //     géométrie ne bouge pas d'un pixel, mon correctif de scoping
        //     tient ;
        //   · mais le centroïde lumineux de la lune varie de 21 pt et celui du
        //     médaillon de 45 pt, sur une période de ~2,6 s — l'horloge de
        //     `lueur`.
        // Ce n'est donc PAS un offset parasite : c'est le SOUFFLE lui-même.
        // Un halo qui enfle et retombe sous un objet immobile se lit comme un
        // objet qui monte et redescend — l'œil ne fait pas la différence entre
        // une lumière qui bouge et une forme qui bouge.
        //
        // Le souffle a été dessiné pour la pastille FLOTTANTE, posée sur la
        // nuit. En DOCK — une dalle encastrée, bord à bord, sous la card — il
        // n'a plus de raison d'être : une dalle de sol ne respire pas. Elle
        // garde sa lumière, à son maximum, immobile.
        .onAppear { lueur = true }
    }

    /// Le sous-titre : l'état d'attente, ou le temps de séance en
    /// MINUTES (verdict : un player n'est pas un chronomètre — la
    /// seconde par seconde était un tic).
    @ViewBuilder private var subtitle: some View {
        if let startedAt {
            TimelineView(.periodic(from: startedAt, by: 60)) { tl in
                Text("In session · \(Self.duree(tl.date.timeIntervalSince(startedAt)))")
                    .font(.inter(11).monospacedDigit())
                    .foregroundStyle(Color.inkMuted)
            }
        } else {
            Text("Workout in progress")
                .font(.inter(11))
                .foregroundStyle(Color.inkMuted)
        }
    }

    private static func duree(_ s: TimeInterval) -> String {
        let m = max(0, Int(s) / 60)
        // Au-delà de l'heure, on parle en heures — une séance orpheline
        // de onze jours affichait « 16770:57 ».
        guard m >= 60 else { return "\(m) min" }
        return "\(m / 60) h \(String(format: "%02d", m % 60))"
    }

    /// LA VEINE D'OR (« oui la veine d'or ») : le filet devient une veine
    /// dégradée qui s'allume vers sa tête — et la tête est une perle de
    /// braise qui respire, sur le souffle déjà en place (`lueur`, aucune
    /// horloge de plus). Plancher 4 % conservé : la perle vit dès zéro.
    private var veine: some View {
        // LA MÊME BARRE que le player déployé (verdict 30-08 : une seule
        // matière de progression partout) — la blanche au dégradé qui
        // coulisse, en 3,5 pt pour la dalle. L'AIR du verdict v9.2
        // (« trop collé partout, au footer, sur les côtés ») : 22 pt de
        // marge latérale, 13 sous elle.
        BarreBlancheAnimee(progress: progress)
        .frame(height: 3.5)
        .padding(.horizontal, 22)
        .padding(.bottom, 13)
    }

    // Le liseré angulaire du médaillon à flamme et sa bague vivent dans
    // `LisereMedaillon` (FlammeJauge.swift) : les pastilles de repos du
    // sheet de saisie portent EXACTEMENT le même — deux tables recopiées
    // auraient fini par diverger d'un pouième, et l'œil l'attrape.

    /// LE BOUTON-MÉDAILLON : l'effet du médaillon à flamme de la carte,
    /// à l'échelle du player — le disque laqué, le liseré angulaire
    /// premium, la bague blanche, et le petit halo chaud qui respire sur
    /// le souffle de la lune. Play et stop en crème ; le pause en néon
    /// orange SOBRE (verdict : « orange plus sobre néon » — une seule
    /// ombre douce, plus les grandes lueurs).
    /// ⚠️ **CE N'EST PLUS UN `Button`, ET C'EST LA CAUSE DU STOP QUI NE
    /// RÉPONDAIT PAS** (26-08, deuxième verdict : « le bouton Stop ne répond
    /// pas correctement, je me retrouve bloquée dans une session active »).
    ///
    /// Le câblage était bon — l'état est global, le panneau est monté à la
    /// racine, il l'observe. Ce qui manquait, c'est que **le tap ne partait
    /// jamais**. Un `Button` SwiftUI posé sous un `DragGesture` d'ancêtre se
    /// fait annuler dès que le drag RECONNAÎT : exactement le bouton dans un
    /// ScrollView qui perd son highlight au premier millimètre de défilement.
    /// Or la home porte le tirage sur TOUTE la page (`HomeNuit`,
    /// `.simultaneousGesture(tirageGeste)`) et son seuil est descendu à 2 pt
    /// pour la fluidité du pull — deux points de tremblement de doigt
    /// suffisaient donc à tuer l'action. Le player en dock vit dessous.
    ///
    /// Un `highPriorityGesture` PASSE DEVANT les gestes d'ancêtre : le stop
    /// gagne, et la fluidité du tirage (mesurée 36,8 → 60,1 img/s sur
    /// l'appareil) n'est pas re-vendue pour la payer.
    private func medallionButton(_ symbol: String, neon: Bool = false,
                                 action: @escaping () -> Void) -> some View {
        MedaillonStop(symbol: symbol, neon: neon, lueur: lueur,
                      action: action)
        // La même respiration que la lune, et RIEN d'autre : le médaillon lit
        // `lueur` pour ses deux liserés, il n'a aucune géométrie animée.
        .animation(docked ? nil
                   : .easeInOut(duration: 2.6)
                        .repeatForever(autoreverses: true),
                   value: lueur)
    }

    /// Même loi que le médaillon : un tap PRIORITAIRE, jamais un `Button`
    /// qu'un drag d'ancêtre annule.
    private func roundButton(_ symbol: String,
                             action: @escaping () -> Void) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Color.inkPrimary)
            .frame(width: 34, height: 34)
            .background(Circle().fill(Color.white.opacity(0.10)))
            .overlay(Circle().strokeBorder(Color.white.opacity(0.08),
                                           lineWidth: 1))
            .padding(8)
            .contentShape(Circle())
            .highPriorityGesture(TapGesture().onEnded { action() })
    }
}
