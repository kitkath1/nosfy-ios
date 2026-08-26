import SwiftUI

// MARK: - L'écran 2

/// La vidéo reprend tout l'écran, et les cinq séries se posent dessus.
///
/// LE CADRAGE TOMBE BIEN, et ce n'est pas un hasard : les deux tiers du haut
/// de `video_story_2` sont de la fumée sur du noir, les pièces sont au sol.
/// La liste se pose exactement dans ce vide, et les pièces restent visibles
/// sous la dernière ligne.
struct StoryTwo: View {
    let session: StorySession
    let t: Double
    let now: Date
    let size: CGSize
    var paused: Bool = false
    /// Le cadre de la partition, remonté au flux (repère « storyFlow ») :
    /// le chef d'orchestre y renonce à son verdict de tap.
    var onPartitionRect: (CGRect) -> Void = { _ in }

    /// La hauteur réelle du contenu de la partition — la frame lui
    /// colle (plafonnée), plus de zone morte sous la dernière ligne.
    @State private var contentH: CGFloat = 0

    var body: some View {
        // Le remplissage : la vidéo est plus large que l'écran à hauteur
        // égale, donc c'est la HAUTEUR qui commande et les flancs sortent.
        let vh = max(size.height, size.width / StoryFilm.aspectTwo)
        let vw = vh * StoryFilm.aspectTwo

        ZStack(alignment: .top) {
            Color.black
            StoryReel(master: "video_story_2",
                      videoSize: CGSize(width: vw, height: vh),
                      paused: paused)
                .frame(width: size.width, height: size.height)
                .clipped()

            // LE VOILE. Sans lui, le blanc du texte se bat contre la fumée.
            // Il ne monte qu'au tiers supérieur — le bas garde les pièces
            // intactes.
            LinearGradient(
                stops: [.init(color: .black.opacity(0.62), location: 0),
                        .init(color: .black.opacity(0.40), location: 0.42),
                        .init(color: .clear, location: 0.78)],
                startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                Text("RÉCAPITULATIF")
                    .font(.inter(10, .medium))
                    .tracking(2.6)
                    .foregroundStyle(Color.woopGold.opacity(0.72))
                    .opacity(StoryCine.sstep(0.10, 0.55, t))

                Text("Détails de la séance")
                    .font(.inter(26, .semibold))
                    .foregroundStyle(WoopGradient.titleFade)
                    .padding(.top, 8)
                    .opacity(StoryCine.sstep(0.18, 0.70, t))
                    .offset(y: (1 - CGFloat(StoryCine.sstep(0.18, 0.70, t))) * 10)

                if !session.groupes.isEmpty {
                    // LA PARTITION DE L'ARDOISE (18-08) : la liste
                    // dépliable par exercice — vignette, nom, petites
                    // flammes gelées — le même composant que le player.
                    // Le tap sur une rangée DÉPLIE (le geste de l'enfant
                    // gagne) ; le tap à côté passe à la story 3 (le chef
                    // d'orchestre du flux le ramasse).
                    SlateListe(groupes: session.groupes,
                               courant: session.groupes.first?.id ?? "",
                               basAir: 24,
                               onContentHeight: { contentH = $0 })
                        .equatable()
                        .frame(height: min(size.height * 0.52,
                                           contentH > 0 ? contentH
                                               : size.height * 0.52))
                        .opacity(StoryCine.sstep(0.40, 0.95, t))
                        .offset(y: (1 - CGFloat(
                            StoryCine.sstep(0.40, 1.0, t))) * 14)
                        .padding(.top, 14)
                        .onGeometryChange(for: CGRect.self) {
                            $0.frame(in: .named("storyFlow"))
                        } action: { onPartitionRect($0) }
                } else {
                    VStack(spacing: 7) {
                        ForEach(Array(session.sets.enumerated()),
                                id: \.element.id) { i, s in
                            let a = 0.40 + Double(i) * 0.075
                            StorySetRow(serie: s, now: now)
                                .opacity(StoryCine.sstep(a, a + 0.42, t))
                                .offset(y: (1 - CGFloat(
                                    StoryCine.sstep(a, a + 0.50, t))) * 14)
                        }
                    }
                    .padding(.top, 22)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 54)
        }
        .frame(width: size.width, height: size.height)
    }
}

// MARK: - La ligne d'une série

/// Une série = une ligne. Compacte : 58 points de haut, tout tient sur un
/// seul appui de l'œil.
///
/// PAS DE `swapCard` ICI, et c'est un choix. Le shader des cards swap est
/// taillé pour une DALLE : son hôte déborde de 54 points sur chaque côté, ce
/// qui ferait cinq hôtes de 166 points de haut empilés au-dessus d'une vidéo
/// en lecture. Sur une ligne de 58 points, sa poudre et son brossage ne se
/// lisent pas — on paierait le prix sans voir la matière. « Très compact,
/// pas une grosse liste de cards lourdes » : la ligne se dessine donc en
/// SwiftUI pur.
struct StorySetRow: View {
    let serie: StorySet
    let now: Date

    var body: some View {
        HStack(spacing: 12) {
            moon

            Text("Série \(serie.rank)")
                .font(.inter(15, .medium))
                .foregroundStyle(Color.white.opacity(0.94))

            Spacer(minLength: 6)

            HStack(spacing: 10) {
                metric("\(serie.reps)", "reps")
                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 1, height: 11)
                metric(kilos, "kg")
            }

            Spacer(minLength: 6)

            gain
        }
        .padding(.leading, 10)
        .padding(.trailing, 12)
        .frame(height: 58)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color.black.opacity(0.72),
                             Color.black.opacity(0.50)],
                    startPoint: .top, endPoint: .bottom))
        }
        .overlay {
            // Un filet qui n'est PAS un contour fermé d'épaisseur égale : il
            // est franc en haut à gauche et éteint en bas à droite, comme une
            // arête prise par une lumière rasante.
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(LinearGradient(
                    stops: [.init(color: .white.opacity(0.16), location: 0),
                            .init(color: .white.opacity(0.04), location: 0.38),
                            .init(color: .white.opacity(0.0), location: 1)],
                    startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.8)
        }
    }

    /// LA LUNE NOIRE. Un croissant plein, très sombre, posé sur son propre
    /// halo orange. Le glyphe est celui de la maison (`MoonShape`) — il n'y a
    /// qu'UNE lune dans cette app.
    private var moon: some View {
        ZStack {
            // « UN LÉGER GLOW ORANGE » — et léger veut dire léger. À 0,30 sur
            // un rayon plus grand que la pastille, le halo remplissait le
            // disque et la lune noire devenait une lune ORANGE : deux ronds
            // orange identiques dans la même ligne, avec la pièce d'en face.
            // Il commence maintenant APRÈS le croissant et meurt avant le
            // bord — c'est une lueur derrière l'objet, pas un fond.
            Circle()
                .fill(RadialGradient(
                    colors: [Color(red: 1.0, green: 0.46, blue: 0.09)
                        .opacity(0.15), .clear],
                    center: .center, startRadius: 5, endRadius: 15))
            MoonShape()
                .fill(LinearGradient(
                    colors: [Color(red: 0.085, green: 0.078, blue: 0.072),
                             Color(red: 0.022, green: 0.021, blue: 0.020)],
                    startPoint: .top, endPoint: .bottom))
                .overlay {
                    MoonShape()
                        .stroke(Color(red: 1.0, green: 0.56, blue: 0.18)
                            .opacity(0.40), lineWidth: 0.6)
                }
                .frame(width: 15, height: 15)
        }
        .frame(width: 32, height: 32)
    }

    /// Le gain et sa pièce. La pièce est GELÉE (`yawOverride: 0`,
    /// `idleLife: 0`, `fps: 6`) — la recette exacte de `GainBadge`, parce
    /// qu'une `TimelineView` par pièce ferait cinq horloges pour cette seule
    /// liste. Et `draggable: false` est OBLIGATOIRE : sans ça la pièce vole
    /// le doigt qui voulait passer à l'écran suivant.
    private var gain: some View {
        HStack(spacing: 5) {
            Text("+\(serie.coins)")
                .font(.inter(14, .semibold))
                .foregroundStyle(Color.woopGold.opacity(0.92))
                .monospacedDigit()
            // Le rayon est monté de 10 à 13 et le croissant descendu à 0,34 :
            // à 10 pt avec le néon plein, le tube (plancher de 0,85 pt) et son
            // bloom prémultiplié noyaient l'anneau, la tranche et le
            // moletage — la pièce ne se lisait plus comme un objet, juste
            // comme un second rond orange à côté de la lune. En baissant le
            // néon, c'est le MÉTAL qui reprend la main, et c'est lui qui porte
            // le relief.
            MoonCoinView(coinR: 13, draggable: false, yawOverride: 0.34,
                         idleLife: 0, fps: 6, reveal: 0.34, matte: 1,
                         figee: true)
                // LE DOUBLE CADRE est obligatoire : l'extérieur porte le bloom
                // du shader (3,4 rayons), l'intérieur décide de
                // l'encombrement. Rogner à la place couperait la lueur.
                .frame(width: 13 * MoonCoinView.hostScale,
                       height: 13 * MoonCoinView.hostScale)
                .frame(width: 28, height: 28)
        }
    }

    private func metric(_ value: String, _ unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value)
                .font(.inter(14, .medium))
                .foregroundStyle(Color.white.opacity(0.80))
                .monospacedDigit()
            Text(unit)
                .font(.inter(10.5))
                .foregroundStyle(Color.white.opacity(0.38))
        }
    }

    private var kilos: String {
        serie.kilos == serie.kilos.rounded()
            ? String(Int(serie.kilos)) : String(format: "%.1f", serie.kilos)
    }
}

// MARK: - L'écran 3

/// Le dernier plan. `video_story_3` en plein écran, rien d'autre — son ratio
/// (0,454) est à un cheveu de celui de l'écran, donc la découpe est nulle.
struct StoryThree: View {
    let size: CGSize
    var paused: Bool = false

    var body: some View {
        let vh = max(size.height, size.width / StoryFilm.aspectThree)
        let vw = vh * StoryFilm.aspectThree
        ZStack {
            Color.black
            StoryReel(master: "video_story_3",
                      videoSize: CGSize(width: vw, height: vh),
                      paused: paused)
                .frame(width: size.width, height: size.height)
                .clipped()
        }
        .frame(width: size.width, height: size.height)
    }
}
