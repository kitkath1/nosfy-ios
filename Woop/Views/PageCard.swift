import SwiftUI
import UIKit

// MARK: - PageCard — LA ROBE de page + la bande du bas (§3 : la robe
// est par page, LE PLAYER est GLOBAL)

/// LA ROBE UNIVERSELLE (plan `tools/player/PLAN-PLAYER-CARD.md`, §2.15
/// → §2.18 → §3) : chaque page est une GROSSE CARD — le haut FOND dans
/// l'heure (aucune limite, verdict 31-08), marges fines de 8 pt, coins
/// BAS seulement, liseré des flancs fondu vers le haut — et sa bande du
/// bas DÉTACHÉE : la dalle player en séance, le trait + LA LUNE hors
/// séance, RIEN pendant l'exercice actif (§2.17).
///
/// DEPUIS LE §3 (le revirement overlay) : cette vue ne porte PLUS le
/// player déployé. La dalle est un BOUTON — tap ou drag-up franc →
/// `PlayerEtat.shared.ouvrir()` : LE player unique de la racine
/// (`PlayerMonde.swift`) monte PAR-DESSUS tout. La page ne bouge
/// JAMAIS (la doctrine anti-bugs) — seule la lune garde son élastique
/// minuscule (0,16 de course, le geste validé de la home).
struct PageCard<Page: View, Dalle: View>: View {
    private let page: Page
    private let dalle: Dalle
    private let dockH: CGFloat

    /// `true` = la dalle player dans la bande ; `false` = HORS SÉANCE :
    /// la page est PLEIN ÉCRAN (§3.4quater), le drag de la prise basse
    /// invisible soulève la card à l'élastique et révèle LA LUNE.
    private let enSeance: Bool
    /// §2.17 : `false` = AUCUNE bande (galet enclenché, chrono) — la
    /// card prend presque toute la hauteur.
    private let bandeVisible: Bool
    /// §3.4quater : la prise basse de la lune (hors séance). La home
    /// passe `false` — son tiroir possède déjà le geste du bas.
    private let luneAuDrag: Bool

    init(dockH: CGFloat = 76,
         enSeance: Bool = true,
         bandeVisible: Bool = true,
         luneAuDrag: Bool = true,
         @ViewBuilder page: () -> Page,
         @ViewBuilder dalle: () -> Dalle) {
        self.dockH = dockH
        self.enSeance = enSeance
        self.bandeVisible = bandeVisible
        self.luneAuDrag = luneAuDrag
        self.page = page()
        self.dalle = dalle()
    }

    /// La levée de L'ÉLASTIQUE LUNE (hors séance seulement) — 0…0,16.
    @State private var levee: CGFloat = 0
    @State private var dragFrom: CGFloat?
    /// LE CHIEN DE GARDE des tirages (§2.18, le piège : un DragGesture
    /// peut mourir SANS `onEnded` — payé : la lune restait ALLUMÉE).
    @State private var chienJeton = 0

    /// Le trait (grabber) + son air, au-dessus de la dalle.
    private var grabH: CGFloat { 18 }
    /// La descente de la dalle DANS la zone home-bar (§3.4sexies,
    /// verdict 01-09 : « un peu plus basse donc card un peu plus
    /// basse ») — la bande mord le bas physique, la card la suit.
    private var descente: CGFloat { 18 }
    /// La bande du bas au repos : trait + dalle + 2 pt d'air, MOINS la
    /// descente (la card gagne autant).
    private var bandeH: CGFloat { grabH + dockH + 2 - descente }

    var body: some View {
        GeometryReader { g in
            // ⚠️ LA RACINE VIT DANS LA ZONE SÛRE (verdict T1 : le
            // chevron coupé) — un `.ignoresSafeArea()` de racine VOLAIT
            // les insets de la page.
            let W = g.size.width
            let Hs = g.size.height
            // §3.4quinquies (« il y a un petit espace en bas ») : hors
            // séance le PLEIN ÉCRAN est PHYSIQUE — la page descend sous
            // la home bar.
            let safeBottom = g.safeAreaInsets.bottom
            let hPage = enSeance ? Hs : Hs + safeBottom
            // La course de l'élastique lune (la même échelle qu'avant).
            let repos = max(Hs - 14 - grabH - dockH, 1)
            ZStack(alignment: .bottom) {
                // -1) LE FOND DE L'APP — le noir sur lequel la card
                //     flotte (couche interne : n'affecte pas les insets
                //     du root).
                Color.black.ignoresSafeArea()
                // 0) HORS SÉANCE : LA LUNE que la card découvre
                //    (construite à p=1, modulée — la loi de la bande
                //    exo : jamais un `p` vivant).
                if !enSeance, bandeVisible {
                    luneFond
                }
                // 1) LA CARD-PAGE — soulevée SEULEMENT par l'élastique
                //    lune (≤ 0,16 de course) ; en séance elle est
                //    IMMOBILE (le player global passe par-dessus).
                pageEnCard
                    .frame(width: W, height: hPage)
                    .offset(y: -levee * repos
                        + (enSeance ? 0 : safeBottom))
                // 2) LA BANDE DU BAS — en séance seulement. Hors séance
                //    la page est PLEIN ÉCRAN (§3.4quater) : une PRISE
                //    INVISIBLE de 30 pt porte l'élastique lune (jamais
                //    un geste page-large).
                if enSeance, bandeVisible {
                    bande
                        .offset(y: descente)
                } else if bandeVisible, luneAuDrag {
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .contentShape(Rectangle())
                        .gesture(tirageLune(course: repos))
                }
            }
            .frame(width: W, height: Hs)
        }
    }

    // MARK: la bande (en séance) — la dalle est un BOUTON

    private var bande: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.white.opacity(0.28))
                .frame(width: 36, height: 4)
                .padding(.top, 8)
                .frame(height: grabH)
            dalle
                .frame(height: dockH)
                .contentShape(Rectangle())
                // LE TAP OUVRE (le stop, Button enfant, garde son
                // toucher). Le drag-up FRANC ouvre aussi — DÉCLENCHÉ à
                // la fin, jamais un suivi (§3.2).
                .onTapGesture { PlayerEtat.shared.ouvrir() }
                // §3.4quinquies : le drag SUIT LE DOIGT — la prise
                // pré-monte le contenu, p suit, le relâcher commet avec
                // l'élan (le chien de PlayerEtat garde le geste mort).
                .gesture(
                    DragGesture(minimumDistance: 3)
                        .onChanged { v in
                            PlayerEtat.shared.suivreDelta(
                                -v.translation.height)
                        }
                        .onEnded { v in
                            PlayerEtat.shared.commettre(
                                velocite: v.velocity.height)
                        })
        }
        .padding(.bottom, 2)
    }

    // MARK: la robe de card

    /// LA GROSSE CARD (§2.15→§2.18) : marges 8, coins BAS seulement, le
    /// HAUT FOND dans l'heure, le liseré meurt vers le haut. La card se
    /// TERMINE au-dessus de la bande (padding bas).
    private var pageEnCard: some View {
        page
            .clipShape(Self.robeCard)
            // §3.4quater (verdict 01-09) : MARGES 0, LISERÉ MORT
            // (« padding noir à supprimer comme leur border ») — la card
            // va BORD À BORD, elle ne se lit plus que par son BAS.
            // HORS SÉANCE : PLEIN ÉCRAN (padding bas 0) — seul
            // l'élastique lune la soulève.
            .padding(.bottom, bandeVisible && enSeance ? bandeH : 0)
            .animation(.easeInOut(duration: 0.25), value: bandeVisible)
            // ⚠️ le @Query des pages arrive APRÈS la première image :
            // sans cette ligne, la card CLAQUE à l'atterrissage.
            .animation(.easeInOut(duration: 0.25), value: enSeance)
    }

    /// Coins BAS seulement — le haut fond dans le châssis (§2.18).
    private static var robeCard: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 0, bottomLeadingRadius: 30,
            bottomTrailingRadius: 30, topTrailingRadius: 0,
            style: .continuous)
    }

    // MARK: la lune (hors séance)

    /// LE SECRET (§2.14) — construite à p = 1, seule sa NAISSANCE est
    /// modulée (opacité + échelle) par la levée.
    private var luneFond: some View {
        let n = min(1, levee * 7)
        return VStack(spacing: 0) {
            Spacer(minLength: 0)
            LuneSecrete(p: 1)
                .opacity(Double(n))
                .scaleEffect(0.82 + 0.18 * n)
                .padding(.bottom, 46)
        }
        .frame(maxWidth: .infinity)
    }

    /// L'ÉLASTIQUE (tanh, ~16 % de course max) ; au relâcher, toujours
    /// le retour — et le CHIEN commet si le geste meurt sans onEnded.
    private func tirageLune(course: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .onChanged { v in
                if dragFrom == nil { dragFrom = levee }
                let brut = max(0, -v.translation.height / course)
                levee = 0.16 * CGFloat(tanh(Double(brut) * 7))
                armerChien { ranger() }
            }
            .onEnded { _ in
                chienJeton += 1
                dragFrom = nil
                ranger()
            }
    }

    private func armerChien(_ commettre: @escaping () -> Void) {
        chienJeton += 1
        let jeton = chienJeton
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            guard jeton == chienJeton, dragFrom != nil else { return }
            dragFrom = nil
            commettre()
        }
    }

    private func ranger() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            levee = 0
        }
    }
}

// MARK: - Les petits objets du player déployé (consommés par
// PlayerMonde — vues PARTAGÉES, jamais deux copies qui divergent)

/// LA BARRE BLANCHE — la progression au déployé : son DÉGRADÉ COULISSE
/// le long du segment rempli, à l'horloge LOCALE (le pattern validé du
/// liseré de la molette — un `repeatForever` posé par `withAnimation`
/// se fait avaler quand le parent est ré-évalué).
struct BarreBlancheAnimee: View {
    var progress: Double
    /// §3.4quater fluidité : l'horloge se TAIT pendant le vol et au
    /// repos — elle ne tourne que le player POSÉ.
    var vivante: Bool = true

    var body: some View {
        GeometryReader { g in
            let w = g.size.width * min(max(progress, 0.04), 1)
            TimelineView(.animation(minimumInterval: 1.0 / 30.0,
                                    paused: !vivante)) { tl in
                let clock = tl.date.timeIntervalSinceReferenceDate
                let u = CGFloat(
                    clock.truncatingRemainder(dividingBy: 2.2) / 2.2)
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.14))
                    // ⚠️ LE CONTRASTE FAIT LA COMÈTE (payé v9.3) : une
                    // comète blanche sur un segment à 0,92 était
                    // INVISIBLE (255+n=255). Le segment tient à 0,62.
                    Capsule().fill(Color.white.opacity(0.62))
                        .frame(width: w)
                        .overlay(alignment: .leading) {
                            LinearGradient(
                                colors: [.clear, .white, .clear],
                                startPoint: .leading, endPoint: .trailing)
                                .frame(width: 88)
                                .offset(x: u * (w + 88) - 88)
                        }
                        .clipShape(Capsule())
                }
            }
        }
    }
}

/// LA FORME TICKET DE CINÉMA — coins doux, DEUX ENCOCHES
/// semi-circulaires au milieu des flancs.
struct TicketShape: Shape {
    var coin: CGFloat = 9
    var encoche: CGFloat = 5.5

    func path(in r: CGRect) -> Path {
        let base = Path(roundedRect: r, cornerRadius: coin)
        let gauche = Path(ellipseIn: CGRect(
            x: r.minX - encoche, y: r.midY - encoche,
            width: encoche * 2, height: encoche * 2))
        let droite = Path(ellipseIn: CGRect(
            x: r.maxX - encoche, y: r.midY - encoche,
            width: encoche * 2, height: encoche * 2))
        return base.subtracting(gauche).subtracting(droite)
    }
}

/// LE BADGE NÉON — la recette de la mini-card ×2 en format ticket :
/// il dit les sets FAITS (jamais un total — il n'existe pas).
struct BadgeSetsNeon: View {
    var texte: String
    /// §3.4septies F1 : la respiration ne vit que POSÉ — en boucle
    /// infinie permanente, elle invalidait le pied pendant le drag et
    /// chauffait l'arbre pré-monté.
    var vivant: Bool = true
    @State private var respire = false

    var body: some View {
        Text(texte)
            .font(.system(size: 9, weight: .bold))
            .monospacedDigit()
            .tracking(0.4)
            .foregroundStyle(Color(white: 0.98))
            .shadow(color: .white.opacity(respire ? 0.90 : 0.55), radius: 2)
            .shadow(color: .white.opacity(respire ? 0.38 : 0.18), radius: 7)
            .padding(.leading, 15)
            .padding(.trailing, 9)
            .padding(.vertical, 4)
            .background {
                TicketShape()
                    .fill(LinearGradient(colors: [Color(white: 0.13),
                                                  Color(white: 0.05)],
                                         startPoint: .top, endPoint: .bottom))
                TicketShape()
                    .stroke(
                        LinearGradient(
                            stops: [.init(color: .white.opacity(0.26),
                                          location: 0),
                                    .init(color: .white.opacity(0.04),
                                          location: 0.5),
                                    .init(color: .clear, location: 1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing),
                        lineWidth: 1)
            }
            .overlay(alignment: .leading) {
                GeometryReader { gg in
                    Path { p in
                        p.move(to: CGPoint(x: 0.5, y: 3))
                        p.addLine(to: CGPoint(x: 0.5,
                                              y: gg.size.height - 3))
                    }
                    .stroke(Color.white.opacity(0.28),
                            style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                }
                .frame(width: 1)
                .offset(x: 9)
            }
            .rotationEffect(.degrees(-7))
            .onChange(of: vivant, initial: true) { _, v in
                if v {
                    withAnimation(.easeInOut(duration: 1.7)
                        .repeatForever(autoreverses: true)) {
                        respire = true
                    }
                } else {
                    var t = Transaction()
                    t.disablesAnimations = true
                    withTransaction(t) { respire = false }
                }
            }
    }
}

/// LA SCÈNE — la zone d'atterrissage du héros, le titre de l'exercice
/// EN COURS, la barre-comète, la partition aux deux fondus.
struct ScenePlayer: View {
    var levee: CGFloat
    var titre: String
    var groupes: [SlateGroupe]
    @Binding var deplies: Set<String>
    /// §3.4octies : le MASK des fondus ne vit que POSÉ — une
    /// re-composition offscreen par frame pendant le vol, sinon.
    var pose: Bool = true
    /// §3.4decies (verdict : « j'arrive pas à drag vers le bas ») — la
    /// liste occupe tout le centre et son ScrollView possédait le
    /// geste MÊME SANS rien à scroller. Mesuré, jamais deviné.
    @State private var contenuH: CGFloat = 0
    @State private var cadreH: CGFloat = 1

    var body: some View {
        let t = min(max(levee, 0), 1)
        VStack(spacing: 0) {
            // §3.4quater (« l'image du jour est sur la progress bar ») :
            // le CD posé (centre 176, bas ~289) vivait SUR le titre —
            // la scène commence désormais SOUS lui.
            Spacer().frame(height: 305)
            Text(titre)
                .font(.inter(21, .semibold))
                .foregroundStyle(Color.white.opacity(0.94))
                .lineLimit(1)
            // Aucune fraction affichée (on ne sait jamais où s'arrête
            // le user) — la barre parle seule.
            BarreBlancheAnimee(progress: 0.6, vivante: t > 0.98)
                .frame(width: 220, height: 5)
                .padding(.top, 14)
            Spacer().frame(height: 22)
            SlateListe(groupes: groupes, courant: "courant",
                       basAir: 260,
                       onContentHeight: { contenuH = $0 },
                       deplies: $deplies)
                .equatable()
                // LA LISTE NE CAPTURE QUE SI ELLE SCROLLE : contenu ≤
                // cadre = le drag TRAVERSE au player (le centre de
                // l'écran redevient une prise). `scrollDisabled` agit
                // par environnement — l'EquatableView n'y peut rien.
                .scrollDisabled(contenuH <= cadreH + 1)
                .onGeometryChange(for: CGFloat.self) {
                    $0.size.height
                } action: { cadreH = $0 }
                .padding(.horizontal, 12)
                .mask {
                    if pose {
                        LinearGradient(stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.07),
                            .init(color: .black, location: 0.68),
                            .init(color: .clear, location: 0.87),
                        ], startPoint: .top, endPoint: .bottom)
                    } else {
                        Rectangle()
                    }
                }
        }
        .opacity(Double(max(0, (t - 0.45) * 2.2)))
    }
}

/// LE PIED — le héros en vol (mini-card jour + ticket), le médaillon
/// stop né en fondu, « Page exercices » en verre. Les boutons ne
/// s'arment que POSÉS (t > 0,95).
struct PiedPlayer: View {
    var levee: CGFloat
    /// §3.4octies : le verre natif ne vit que POSÉ (60 → 14 img/s
    /// sinon) — en vol, la doublure mate.
    var pose: Bool = true
    var jour: Date
    var sticker: String
    var setsFaits: Int
    var stopActif: Bool = false
    var onStop: () -> Void = {}
    var pageExosActif: Bool = false
    var onPageExercices: () -> Void = {}

    var body: some View {
        GeometryReader { gp in
            let t = min(max(levee, 0), 1)
            let x0: CGFloat = 41, y0: CGFloat = 18 + 38
            let x1 = gp.size.width / 2, y1: CGFloat = 176
            ZStack {
                MiniCardJour(date: jour, sticker: sticker,
                             stickerBasGauche: true)
                    .overlay(alignment: .trailing) {
                        BadgeSetsNeon(texte: "\(setsFaits) SETS",
                                      vivant: t > 0.98)
                            .offset(x: 26)
                            .opacity(Double(max(0, (t - 0.25) * 1.6)))
                    }
                    .scaleEffect(0.58 + 1.12 * t)
                    .position(x: x0 + (x1 - x0) * t, y: y0 + (y1 - y0) * t)
                    .opacity(t > 0.03 ? 1 : 0)
                    .allowsHitTesting(false)

                MedaillonStop(lueur: true, action: onStop)
                    .scaleEffect(1.35)
                    .position(x: x1, y: gp.size.height - 140)
                    .opacity(Double(max(0, (t - 0.55) * 2.2)))
                    .allowsHitTesting(stopActif && t > 0.95)

                Text("Page exercices")
                    .font(.inter(15, .semibold))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 13)
                    .modifier(VerreOuMat(pose: pose))
                    .contentShape(Capsule())
                    .highPriorityGesture(
                        TapGesture().onEnded { onPageExercices() })
                    .position(x: x1, y: gp.size.height - 80)
                    .opacity(Double(max(0, (t - 0.6) * 2.5)))
                    .allowsHitTesting(pageExosActif && t > 0.95)
            }
        }
    }
}

// MARK: - Le banc : `-pageCardLab`

/// Banc de LA ROBE (§3 : le player se teste au GLOBAL, via
/// `-playerOuvert` / `-playerCycle`) : la card, la bande, la dalle
/// bouton, la lune (`-pageCardLune`).
struct PageCardLab: View {
    private static let demoStart = Date().addingTimeInterval(-27 * 60)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            PageCard(
                     enSeance: !CommandLine.arguments
                         .contains("-pageCardLune"),
                     page: { demoPage },
                     dalle: { demoDalle })
        }
        .preferredColorScheme(.dark)
    }

    private var demoDalle: some View {
        WorkoutPill(exercise: ExerciseCatalog.all[0],
                    progress: 0.4,
                    startedAt: Self.demoStart,
                    docked: true,
                    lisere: false,
                    doneSeries: 2,
                    exoCount: 3,
                    jour: Self.demoStart,
                    jourSticker: "sticker-flamme",
                    titreCourant: ExerciseCatalog.all[0].name)
    }

    /// LA PAGE bidon : NOIRE plein cadre (la robe vient du moteur), du
    /// contenu RÉALISTE jusqu'en bas.
    private var demoPage: some View {
        ZStack(alignment: .top) {
            Color.black
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 66)
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 96, weight: .thin))
                    .foregroundStyle(.white.opacity(0.42))
                    .frame(maxWidth: .infinity)
                Spacer().frame(height: 30)
                Text("Développé couché à la barre")
                    .font(.inter(30, .bold))
                    .foregroundStyle(.white)
                Text("Haut · Pectoraux, triceps, épaules")
                    .font(.inter(15, .regular))
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.top, 6)
                Spacer().frame(height: 34)
                ForEach(1..<4) { i in
                    HStack(spacing: 0) {
                        Text("Set \(i)")
                            .font(.inter(16, .medium))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(width: 70, alignment: .leading)
                        Text("12 reps · 20 kg · 60 s")
                            .font(.inter(15, .regular))
                            .foregroundStyle(.white.opacity(0.5))
                        Spacer()
                        Text("Upcoming")
                            .font(.inter(13, .regular))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .padding(.vertical, 15)
                }
                Spacer(minLength: 0)
            }
            .padding(26)
        }
    }
}

/// §3.4octies — LE VERRE OU LA DOUBLURE : le verre natif ne vit que le
/// player POSÉ (la loi payée : un verre aux bounds vivants re-échantillonne
/// son fond à chaque frame, 60 → 14 img/s) ; en vol, une capsule mate.
struct VerreOuMat: ViewModifier {
    var pose: Bool

    func body(content: Content) -> some View {
        if pose {
            content
                .glassEffect(.regular.tint(Color.black.opacity(0.35))
                                 .interactive(),
                             in: .capsule)
        } else {
            content
                .background(
                    Capsule().fill(Color.black.opacity(0.45)))
                .overlay(
                    Capsule().strokeBorder(
                        Color.white.opacity(0.12), lineWidth: 1))
        }
    }
}
